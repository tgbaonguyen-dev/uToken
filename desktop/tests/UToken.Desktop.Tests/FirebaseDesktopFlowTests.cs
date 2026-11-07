using System.Net;
using System.Text.Json;
using System.Text.Json.Nodes;
using UToken.Sync;
using UToken.Sync.Auth;
using Xunit;

namespace UToken.Desktop.Tests;

// Real API, SQLite and encrypted session storage; only Google/browser and Firebase HTTP are faked.
public sealed class FirebaseDesktopFlowTests : IDisposable
{
    private readonly RealHome _home = new();
    private readonly FirebaseServer _server = new();
    private readonly GoogleSignIn _google = new();
    private readonly HttpClient _http;
    private string SessionFile => Path.Combine(_home.DataDirectory, "auth.json");

    public FirebaseDesktopFlowTests() => _http = new HttpClient(_server);

    private FirebaseCloudSync NewCloud() => new(_http,
        new FirebaseOptions { ProjectId = "utoken-test", UseEmulator = true, OAuthClientId = "test-desktop" },
        SessionFile, _google, _home.Clock);

    [Fact]
    public async Task Reopen_restores_saved_account_and_refreshes_without_opening_google()
    {
        using (var app = _home.Api(cloudSync: NewCloud()))
            Assert.Equal("success", (await app.SignInAsync()).State);

        _home.Clock.Now = _home.Clock.Now.AddHours(2);
        // All session/API objects are new, as after a complete app exit; only persisted files remain.
        using var reopened = _home.Api(cloudSync: NewCloud());
        Assert.Equal("uid-1@example.com", (await reopened.GetSyncAsync()).Device!.Name);
        Assert.Equal("success", (await reopened.SyncNowAsync()).State);
        Assert.Equal(1, _google.Calls);
        Assert.Equal(1, _server.Refreshes);
    }

    [Fact]
    public async Task Sign_out_then_reopen_does_not_restore_or_upload_an_account()
    {
        using (var app = _home.Api(cloudSync: NewCloud()))
        {
            await app.SignInAsync();
            Assert.Null((await app.DisconnectAsync()).Device);
        }

        using var reopened = _home.Api(cloudSync: NewCloud());
        Assert.Null((await reopened.GetSyncAsync()).Device);
        Assert.Equal("not_paired", (await reopened.SyncNowAsync()).State);
        Assert.Empty(_server.Commits);
        Assert.Equal(1, _google.Calls);
        Assert.False(File.Exists(SessionFile));
    }

    [Fact]
    public async Task Switching_accounts_resends_all_days_only_to_the_new_uid()
    {
        using var app = _home.Api(cloudSync: NewCloud());
        await app.SignInAsync();
        Assert.Equal("success", (await app.SyncNowAsync()).State);
        AssertOwnedWrites(Assert.Single(_server.Commits), "uid-1", 2);
        Assert.Equal(0, (await app.GetSyncAsync()).NextSync.Events);

        await app.DisconnectAsync();
        _server.SignInUid = "uid-2";
        Assert.Equal("uid-2@example.com", (await app.SignInAsync()).Data!.Device!.Name);
        Assert.Equal("success", (await app.SyncNowAsync()).State);
        Assert.Equal(2, _server.Commits.Count);
        AssertOwnedWrites(_server.Commits[1], "uid-2", 2);
        Assert.Equal(0, (await app.GetSyncAsync()).NextSync.Events);
        Assert.Equal("no_new_usage", (await app.SyncNowAsync()).State);
        AssertOwnedWrites(_server.Commits[2], "uid-2", 0);

        using var reopened = _home.Api(cloudSync: NewCloud());
        Assert.Equal("uid-2@example.com", (await reopened.GetSyncAsync()).Device!.Name);
    }

    [Fact]
    public async Task Offline_restart_keeps_account_local_data_and_queue_until_retry_succeeds()
    {
        using (var app = _home.Api(cloudSync: NewCloud())) await app.SignInAsync();
        _server.Offline = true;
        using var reopened = _home.Api(cloudSync: NewCloud());
        Assert.NotNull((await reopened.GetSyncAsync()).Device);
        long tokens = (await reopened.GetOverviewAsync()).TotalTokens;
        Assert.True(tokens > 0);
        var failed = await reopened.SyncNowAsync();
        Assert.Equal("network", failed.State);
        Assert.NotNull(failed.Data.Device);
        Assert.True(failed.Data.NextSync.Events > 0);
        Assert.Equal(tokens, (await reopened.GetOverviewAsync()).TotalTokens);
        Assert.Empty(_server.Commits);

        _server.Offline = false;
        var retried = await reopened.SyncNowAsync();
        Assert.Equal("success", retried.State);
        Assert.Equal(0, retried.Data.NextSync.Events);
        AssertOwnedWrites(Assert.Single(_server.Commits), "uid-1", 2);
        Assert.Equal(1, _google.Calls);
    }

    [Fact]
    public async Task Firestore_permission_denied_keeps_session_and_pending_data_for_retry()
    {
        using var app = _home.Api(cloudSync: NewCloud());
        await app.SignInAsync();
        _server.CommitStatus = HttpStatusCode.Forbidden;
        var failed = await app.SyncNowAsync();
        Assert.Equal("failed", failed.State);
        Assert.NotNull(failed.Data.Device);
        Assert.True(failed.Data.NextSync.Events > 0);
        Assert.Empty(_server.Commits);

        _server.CommitStatus = HttpStatusCode.OK;
        Assert.Equal("success", (await app.SyncNowAsync()).State);
        AssertOwnedWrites(Assert.Single(_server.Commits), "uid-1", 2);
        Assert.Equal(1, _google.Calls);
    }

    private static void AssertOwnedWrites((string Auth, string Body) commit, string uid, int dailyCount)
    {
        Assert.Equal($"Bearer token-{uid}", commit.Auth);
        var writes = JsonNode.Parse(commit.Body)!["writes"]!.AsArray();
        var names = writes.Select(w => w!["update"]!["name"]!.GetValue<string>()).ToArray();
        string owner = $"projects/utoken-test/databases/(default)/documents/users/{uid}";
        Assert.All(names, name => Assert.True(name == owner || name.StartsWith(owner + "/", StringComparison.Ordinal)));
        Assert.Equal(dailyCount, names.Count(n => n.StartsWith(owner + "/daily/", StringComparison.Ordinal)));
        Assert.Contains(owner + "/efficiency/current", names);
        Assert.Contains(owner, names);
        if (dailyCount > 0)
            Assert.All(writes.Where(w => w!["update"]!["name"]!.GetValue<string>().Contains("/daily/")),
                w => Assert.Equal("2", w!["update"]!["fields"]!["schema_version"]!["integerValue"]!.GetValue<string>()));
    }

    private sealed class GoogleSignIn : IGoogleSignIn
    {
        public int Calls;
        public Task<string> GetGoogleIdTokenAsync(CancellationToken ct)
        {
            Calls++;
            return Task.FromResult("fake-google-token");
        }
    }

    private sealed class FirebaseServer : HttpMessageHandler
    {
        public string SignInUid = "uid-1";
        public bool Offline;
        public int Refreshes;
        public HttpStatusCode CommitStatus = HttpStatusCode.OK;
        public List<(string Auth, string Body)> Commits { get; } = [];

        protected override async Task<HttpResponseMessage> SendAsync(HttpRequestMessage request, CancellationToken ct)
        {
            if (Offline) throw new HttpRequestException("Offline test");
            string path = request.RequestUri!.AbsolutePath;
            if (path.EndsWith("accounts:signInWithIdp"))
                return Json(new { localId = SignInUid, email = SignInUid + "@example.com", displayName = "Test", idToken = "token-" + SignInUid, refreshToken = "refresh-" + SignInUid, expiresIn = "3600" });
            if (path.EndsWith("/token"))
            {
                string body = await request.Content!.ReadAsStringAsync(ct);
                string token = Uri.UnescapeDataString(body.Split('&').Single(p => p.StartsWith("refresh_token=")).Split('=', 2)[1]);
                string uid = token["refresh-".Length..];
                Refreshes++;
                return Json(new { id_token = "token-" + uid, refresh_token = token, expires_in = "3600", user_id = uid });
            }
            if (path.EndsWith(":commit"))
            {
                if (CommitStatus != HttpStatusCode.OK) return new(CommitStatus) { Content = new StringContent("{}") };
                Commits.Add((request.Headers.Authorization!.ToString(), await request.Content!.ReadAsStringAsync(ct)));
                return Json(new { writeResults = Array.Empty<object>() });
            }
            throw new InvalidOperationException("Unexpected Firebase request in test");
        }

        private static HttpResponseMessage Json(object value) => new(HttpStatusCode.OK)
        {
            Content = new StringContent(JsonSerializer.Serialize(value), System.Text.Encoding.UTF8, "application/json")
        };
    }

    public void Dispose() { _http.Dispose(); _home.Dispose(); }
}
