using System.Net;
using System.Net.Http.Headers;
using System.Security.Cryptography;
using System.Text;
using System.Text.Json;
using System.Text.Json.Nodes;
using UToken.Sync;
using UToken.Sync.Auth;
using Xunit;
using Xunit.Abstractions;

namespace UToken.Sync.Tests;

// Opt-in only: real Firebase requests, disposable probes, no Admin SDK bypass of Firestore Rules.
public sealed class LiveFirebaseTests(ITestOutputHelper output)
{
    [LiveFirebaseFact]
    public async Task Deployed_rules_enforce_owner_and_anonymous_isolation()
    {
        using var http = new HttpClient { Timeout = TimeSpan.FromSeconds(30) };
        var (options, session) = await SignInFromSavedSession(http);
        string root = options.FirestoreBaseUrl;
        string run = "utoken-check-" + Guid.NewGuid().ToString("N");
        string mine = $"{root}/users/{Uri.EscapeDataString(session.Uid)}/_rules_probe/{run}";
        string foreign = $"{root}/users/{run}/_rules_probe/{run}";
        var created = new Dictionary<string, string>();
        var failures = new List<string>();
        var fields = new JsonObject { ["probe"] = new JsonObject { ["stringValue"] = run } };
        try
        {
            await Check("Owner can create probe", HttpMethod.Patch, mine, session.IdToken, HttpStatusCode.OK, true);
            await Check("Owner can read own probe", HttpMethod.Get, mine, session.IdToken, HttpStatusCode.OK);
            await Check("Anonymous cannot read existing owner probe", HttpMethod.Get, mine, null, HttpStatusCode.Forbidden);
            await Check("Anonymous cannot create owner probe", HttpMethod.Patch, mine + "-anon", null, HttpStatusCode.Forbidden, true);
            await Check("Signed-in user cannot read another UID namespace", HttpMethod.Get, foreign, session.IdToken, HttpStatusCode.Forbidden);
            await Check("Signed-in user cannot write another UID namespace", HttpMethod.Patch, foreign, session.IdToken, HttpStatusCode.Forbidden, true);
        }
        finally
        {
            foreach (var (url, updateTime) in created)
            {
                using var request = Request(HttpMethod.Delete, url + "?currentDocument.updateTime=" + Uri.EscapeDataString(updateTime), session.IdToken);
                try
                {
                    using var response = await http.SendAsync(request);
                    if (!response.IsSuccessStatusCode)
                        failures.Add($"Cleanup failed (HTTP {(int)response.StatusCode}): {new Uri(url).AbsolutePath}");
                }
                catch (Exception ex) when (ex is HttpRequestException or OperationCanceledException)
                { failures.Add("Cleanup network failure: " + new Uri(url).AbsolutePath); }
            }
        }
        Assert.True(failures.Count == 0, string.Join(Environment.NewLine, failures));

        async Task Check(string label, HttpMethod method, string url, string? token, HttpStatusCode expected, bool create = false)
        {
            // A create precondition prevents accidental overwrite even in the event of a name collision.
            using var request = Request(method, url + (create ? "?currentDocument.exists=false" : ""), token);
            if (create) request.Content = new StringContent(new JsonObject { ["fields"] = fields.DeepClone() }.ToJsonString(), Encoding.UTF8, "application/json");
            using var response = await http.SendAsync(request);
            if (create && response.IsSuccessStatusCode)
            {
                using var doc = JsonDocument.Parse(await response.Content.ReadAsStringAsync());
                created[url] = doc.RootElement.GetProperty("updateTime").GetString()!;
            }
            output.WriteLine($"{label}: expected {(int)expected}, got {(int)response.StatusCode}");
            if (response.StatusCode != expected) failures.Add($"{label}: expected HTTP {(int)expected}, got {(int)response.StatusCode}");
        }
    }

    [LiveFirebaseFact]
    public async Task Real_sync_documents_exist_for_the_signed_in_account()
    {
        using var http = new HttpClient { Timeout = TimeSpan.FromSeconds(30) };
        var (options, session) = await SignInFromSavedSession(http);
        string owner = options.FirestoreBaseUrl + "/users/" + Uri.EscapeDataString(session.Uid);
        using var daily = await Get(owner + "/daily?pageSize=1");
        Assert.True(daily.RootElement.TryGetProperty("documents", out var docs) && docs.GetArrayLength() > 0,
            "No daily summaries found. Run Sync now in the app, then rerun this test.");
        Assert.Equal("2", docs[0].GetProperty("fields").GetProperty("schema_version").GetProperty("integerValue").GetString());
        using var efficiency = await Get(owner + "/efficiency/current");
        Assert.Equal("1", efficiency.RootElement.GetProperty("fields").GetProperty("schema_version").GetProperty("integerValue").GetString());
        using var profile = await Get(owner);
        Assert.True(profile.RootElement.GetProperty("fields").TryGetProperty("last_sync_at", out _), "Profile has no last_sync_at. Run Sync now first.");
        output.WriteLine("Verified daily schema v2, efficiency schema v1 and last_sync_at with the user's Firebase ID token. No usage values logged.");

        async Task<JsonDocument> Get(string url)
        {
            using var request = Request(HttpMethod.Get, url, session.IdToken);
            using var response = await http.SendAsync(request);
            Assert.True(response.IsSuccessStatusCode, $"Read failed with HTTP {(int)response.StatusCode}. Check database, sync result and deployed Rules.");
            return JsonDocument.Parse(await response.Content.ReadAsStringAsync());
        }
    }

    [LiveFirebaseFact(RequiresRulesAccess = true)]
    public async Task Deployed_rules_source_matches_repository()
    {
        string project = Required("UTOKEN_LIVE_PROJECT");
        using var http = new HttpClient { Timeout = TimeSpan.FromSeconds(30) };
        using var release = await Get($"https://firebaserules.googleapis.com/v1/projects/{Uri.EscapeDataString(project)}/releases/cloud.firestore");
        string ruleset = release.RootElement.GetProperty("rulesetName").GetString()!;
        Assert.StartsWith($"projects/{project}/rulesets/", ruleset);
        using var source = await Get("https://firebaserules.googleapis.com/v1/" + ruleset);
        string local = Normalize(await File.ReadAllTextAsync(Required("UTOKEN_LIVE_RULES")));
        var files = source.RootElement.GetProperty("source").GetProperty("files").EnumerateArray().ToArray();
        Assert.Contains(files, file => Normalize(file.GetProperty("content").GetString()!) == local);
        output.WriteLine("Deployed Rules source matches the repository (line endings and trailing whitespace normalized). No deployment performed.");

        async Task<JsonDocument> Get(string url)
        {
            using var request = Request(HttpMethod.Get, url, Required("UTOKEN_RULES_ACCESS_TOKEN"));
            using var response = await http.SendAsync(request);
            Assert.True(response.IsSuccessStatusCode, $"Rules management read failed: HTTP {(int)response.StatusCode}. Requires a Google access token with Firebase Rules read permissions, not a Firebase ID token.");
            return JsonDocument.Parse(await response.Content.ReadAsStringAsync());
        }
    }

    private static string Normalize(string source) => string.Join("\n", source.Replace("\r\n", "\n").Split('\n').Select(line => line.TrimEnd())).Trim();
    private static string Required(string key) => Environment.GetEnvironmentVariable(key) is { Length: > 0 } value ? value : throw new InvalidOperationException("Missing " + key);
    private static HttpRequestMessage Request(HttpMethod method, string url, string? token)
    {
        var request = new HttpRequestMessage(method, url);
        if (token is not null) request.Headers.Authorization = new AuthenticationHeaderValue("Bearer", token);
        return request;
    }

    private static async Task<(FirebaseOptions, FirebaseSession)> SignInFromSavedSession(HttpClient http)
    {
        if (!OperatingSystem.IsWindows()) throw new PlatformNotSupportedException("Saved-session live checks currently require Windows DPAPI.");
        string project = Required("UTOKEN_LIVE_PROJECT");
        using var config = JsonDocument.Parse(await File.ReadAllTextAsync(Required("UTOKEN_LIVE_CONFIG")));
        var firebase = config.RootElement.GetProperty("Firebase");
        var options = new FirebaseOptions
        {
            ProjectId = firebase.GetProperty("ProjectId").GetString()!,
            ApiKey = firebase.GetProperty("ApiKey").GetString()!,
            UseEmulator = firebase.GetProperty("UseEmulator").GetBoolean()
        };
        Assert.False(options.UseEmulator, "Live checks require UseEmulator=false.");
        Assert.Equal(project, options.ProjectId);
        string file = Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData), "uToken", "auth.json");
        Assert.False(File.Exists(file + ".signed-out"), "App session is signed out. Sign in from the app first.");
        using var envelope = JsonDocument.Parse(await File.ReadAllBytesAsync(file));
        byte[] clear;
        if (envelope.RootElement.TryGetProperty("Protection", out var protection))
        {
            Assert.Equal("windows-dpapi-v1", protection.GetString());
            clear = ProtectedData.Unprotect(Convert.FromBase64String(envelope.RootElement.GetProperty("Data").GetString()!), null, DataProtectionScope.CurrentUser);
        }
        else
        {
            // Support a session from the previously running app without altering its persisted file.
            clear = Encoding.UTF8.GetBytes(envelope.RootElement.GetRawText());
        }
        FirebaseSession saved;
        try
        {
            using var payload = JsonDocument.Parse(clear);
            var root = payload.RootElement;
            Assert.Equal(project, root.GetProperty("ProjectId").GetString());
            Assert.False(root.GetProperty("Emulator").GetBoolean());
            saved = new FirebaseSession(root.GetProperty("Uid").GetString()!, root.GetProperty("Email").GetString()!, null, "", root.GetProperty("RefreshToken").GetString()!, DateTimeOffset.MinValue);
        }
        finally { CryptographicOperations.ZeroMemory(clear); }
        // Refresh in memory only; never replace, sign out or print the app's persisted session.
        return (options, await new FirebaseAuthClient(http, options).RefreshAsync(saved, default));
    }
}

public sealed class LiveFirebaseFactAttribute : FactAttribute
{
    private bool _requiresRulesAccess;
    public bool RequiresRulesAccess
    {
        get => _requiresRulesAccess;
        set
        {
            _requiresRulesAccess = value;
            if (Skip is null && value && string.IsNullOrWhiteSpace(Environment.GetEnvironmentVariable("UTOKEN_RULES_ACCESS_TOKEN")))
                Skip = "No Google management access token: deployed Rules source comparison was not run.";
        }
    }
    public LiveFirebaseFactAttribute()
    {
        if (Environment.GetEnvironmentVariable("UTOKEN_LIVE_FIREBASE") != "1")
            Skip = "Real Firebase checks are opt-in. Use scripts/Test-FirebaseLive.ps1.";
    }
}
