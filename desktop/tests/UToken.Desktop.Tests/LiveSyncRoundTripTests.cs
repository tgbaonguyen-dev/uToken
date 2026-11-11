using System.Net;
using System.Net.Http.Headers;
using System.Text;
using System.Text.Json;
using System.Text.Json.Nodes;
using UToken.Core.Aggregation;
using UToken.Desktop.App;
using UToken.Desktop.App.Services;
using UToken.Engine;
using UToken.Sync;
using Xunit;

namespace UToken.Desktop.Tests;

// Opt-in: uses the saved desktop session and real retained usage. Never run in normal CI.
public sealed class LiveSyncRoundTripTests
{
    [LiveSyncFact]
    public async Task Manual_sync_restores_a_controlled_cloud_edit()
    {
        var configDirectory = Environment.GetEnvironmentVariable("UTOKEN_LIVE_CONFIG_DIRECTORY")!;
        var evidenceDirectory = Environment.GetEnvironmentVariable("UTOKEN_LIVE_EVIDENCE_DIRECTORY")!;
        Directory.CreateDirectory(evidenceDirectory);
        var settings = AppSettings.Load(configDirectory);
        Assert.False(settings.Firebase.UseEmulator);
        Assert.Equal(Environment.GetEnvironmentVariable("UTOKEN_LIVE_PROJECT"), settings.Firebase.ProjectId);
        using var transport = new CaptureAuthentication();
        using var http = new HttpClient(transport) { Timeout = TimeSpan.FromSeconds(30) };
        var cloud = new FirebaseCloudSync(http, settings.Firebase, Path.Combine(AppSettings.DataDirectory, "auth.json"));
        Assert.NotNull(await cloud.RestoreAsync());
        var codex = AppSettings.ExpandHome(settings.Collectors.CodexHome);
        var claude = AppSettings.ExpandHome(settings.Collectors.ClaudeHome);
        var (engine, store) = EngineFactory.Create(settings.DatabasePath, settings.Collectors.Enabled, codex, claude);
        using var api = new RealDesktopApi(engine, store,
            RealDesktopApi.DefaultLocations(codex, claude, Environment.GetFolderPath(Environment.SpecialFolder.UserProfile), settings.Collectors.Enabled),
            settings.DatabasePath, new LocalSettingsStore(AppSettings.DataDirectory), Path.Combine(configDirectory, "UiContent"), cloud: cloud);
        // JudgeDirectory remains null: this verification must not call a paid AI model.
        var result = await api.SyncNowAsync(resendAll: true);
        Assert.Contains(result.State, new[] { "success", "no_new_usage" });
        var local = store.GetDailyJsonSince("0001-01-01")
            .Select(json => JsonSerializer.Deserialize<DailyDoc>(json)!).ToArray();
        Assert.NotEmpty(local);
        var root = settings.Firebase.FirestoreBaseUrl + "/users/" + Uri.EscapeDataString(cloud.Account!.Uid);
        var documents = await ReadAll();
        foreach (var daily in local)
        {
            var actual = documents.Single(doc => doc["name"]!.GetValue<string>().EndsWith("/" + daily.Date));
            Assert.True(JsonNode.DeepEquals(FirestoreValues.Fields(daily), actual["fields"]), "Retained daily mismatch: " + daily.Date);
        }
        var mismatches = documents.Count(doc => Counter(doc, "totals", "input") + Counter(doc, "totals", "output") !=
            doc["fields"]!["by_key"]!["mapValue"]!["fields"]!.AsObject().Sum(e => BucketTokens(e.Value!)));
        var target = documents.Where(doc => local.Any(d => doc["name"]!.GetValue<string>().EndsWith("/" + d.Date)))
            .OrderBy(doc => doc["name"]!.GetValue<string>()).Last();
        var originalFields = target["fields"]!.DeepClone();
        var originalTotal = documents.Sum(doc => Counter(doc, "totals", "input") + Counter(doc, "totals", "output"));
        var changed = originalFields.DeepClone();
        var bucket = changed["by_key"]!["mapValue"]!["fields"]!.AsObject().First().Value!;
        Increment(changed["totals"]!, 1000);
        Increment(bucket, 1000);
        var targetUrl = settings.Firebase.FirestoreBaseUrl + "/" + target["name"]!.GetValue<string>().Split("/documents/")[1];
        JsonObject? edited = null;
        try
        {
            edited = await Patch(changed, target["updateTime"]!.GetValue<string>());
            await Stage("edited", new { originalTotal, editedTotal = originalTotal + 1000, retainedDays = local.Length, inconsistentDays = mismatches });
            var editedDocs = await ReadAll();
            Assert.Equal(originalTotal + 1000, editedDocs.Sum(doc => Counter(doc, "totals", "input") + Counter(doc, "totals", "output")));
            var restored = await api.SyncNowAsync(resendAll: true);
            Assert.Contains(restored.State, new[] { "success", "no_new_usage" });
            var final = await Get(targetUrl);
            // Collectors may see new usage while the phone is being inspected.
            var regenerated = store.GetDailyJsonSince("0001-01-01")
                .Select(json => JsonSerializer.Deserialize<DailyDoc>(json)!)
                .Single(d => target["name"]!.GetValue<string>().EndsWith("/" + d.Date));
            Assert.True(JsonNode.DeepEquals(FirestoreValues.Fields(regenerated), final["fields"]), "Manual sync did not restore the current local daily.");
            edited = null;
            var after = await ReadAll();
            await Stage("restored", new { originalTotal, restoredTotal = after.Sum(doc => Counter(doc, "totals", "input") + Counter(doc, "totals", "output")), retainedDays = local.Length, inconsistentDays = mismatches });
        }
        finally
        {
            // Restore only our exact edit; never overwrite an intervening writer during cleanup.
            if (edited is not null)
            {
                var current = await Get(targetUrl);
                if (current["updateTime"]!.GetValue<string>() == edited["updateTime"]!.GetValue<string>())
                    await Patch(originalFields, edited["updateTime"]!.GetValue<string>());
            }
        }

        async Task Stage(string phase, object values)
        {
            await File.WriteAllTextAsync(Path.Combine(evidenceDirectory, phase + ".json"), JsonSerializer.Serialize(values));
            if (Environment.GetEnvironmentVariable("UTOKEN_LIVE_WAIT_FOR_MOBILE") != "1") return;
            for (var i = 0; i < 60 && !File.Exists(Path.Combine(evidenceDirectory, phase + ".ack")); i++)
                await Task.Delay(1000);
            Assert.True(File.Exists(Path.Combine(evidenceDirectory, phase + ".ack")), "Mobile inspection not acknowledged: " + phase);
        }
        async Task<List<JsonObject>> ReadAll()
        {
            var docs = new List<JsonObject>();
            string? token = null;
            do
            {
                var page = await Get(root + "/daily?pageSize=1000" + (token is null ? "" : "&pageToken=" + Uri.EscapeDataString(token)));
                docs.AddRange((page["documents"] as JsonArray ?? []).Select(d => d!.AsObject()));
                token = page["nextPageToken"]?.GetValue<string>();
            } while (!string.IsNullOrEmpty(token));
            return docs;
        }
        async Task<JsonObject> Get(string url)
        {
            using var req = new HttpRequestMessage(HttpMethod.Get, url);
            req.Headers.Authorization = new AuthenticationHeaderValue("Bearer", transport.Token!);
            using var response = await http.SendAsync(req);
            Assert.Equal(HttpStatusCode.OK, response.StatusCode);
            return JsonNode.Parse(await response.Content.ReadAsStringAsync())!.AsObject();
        }
        async Task<JsonObject> Patch(JsonNode fields, string updateTime)
        {
            using var req = new HttpRequestMessage(HttpMethod.Patch, targetUrl + "?currentDocument.updateTime=" + Uri.EscapeDataString(updateTime));
            req.Headers.Authorization = new AuthenticationHeaderValue("Bearer", transport.Token!);
            req.Content = new StringContent(new JsonObject { ["fields"] = fields.DeepClone() }.ToJsonString(), Encoding.UTF8, "application/json");
            using var response = await http.SendAsync(req);
            Assert.Equal(HttpStatusCode.OK, response.StatusCode);
            return JsonNode.Parse(await response.Content.ReadAsStringAsync())!.AsObject();
        }
    }

    private static long Counter(JsonNode doc, string bucket, string key) => long.Parse(doc["fields"]![bucket]!["mapValue"]!["fields"]![key]!["integerValue"]!.GetValue<string>(), System.Globalization.CultureInfo.InvariantCulture);
    private static long BucketTokens(JsonNode bucket) => long.Parse(bucket["mapValue"]!["fields"]!["input"]!["integerValue"]!.GetValue<string>()) + long.Parse(bucket["mapValue"]!["fields"]!["output"]!["integerValue"]!.GetValue<string>());
    private static void Increment(JsonNode bucket, long delta)
    {
        var input = bucket["mapValue"]!["fields"]!["input"]!;
        input["integerValue"] = (long.Parse(input["integerValue"]!.GetValue<string>()) + delta).ToString(System.Globalization.CultureInfo.InvariantCulture);
    }
    private sealed class CaptureAuthentication : DelegatingHandler
    {
        public CaptureAuthentication() : base(new HttpClientHandler()) { }
        public string? Token { get; private set; }
        protected override Task<HttpResponseMessage> SendAsync(HttpRequestMessage request, CancellationToken cancellationToken)
        {
            if (request.RequestUri!.Host == "firestore.googleapis.com" && request.Headers.Authorization?.Scheme == "Bearer")
                Token = request.Headers.Authorization.Parameter;
            return base.SendAsync(request, cancellationToken);
        }
    }
}

public sealed class LiveSyncFactAttribute : FactAttribute
{
    public LiveSyncFactAttribute()
    {
        if (Environment.GetEnvironmentVariable("UTOKEN_LIVE_SYNC") != "1")
            Skip = "Opt-in production sync/controlled-edit check; requires explicit local configuration and saved session.";
    }
}
