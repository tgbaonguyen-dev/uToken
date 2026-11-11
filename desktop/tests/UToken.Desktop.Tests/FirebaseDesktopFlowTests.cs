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
    public async Task Upload_time_survives_restart_and_is_scoped_to_the_account()
    {
        var uploaded = _home.Clock.Now;
        using (var app = _home.Api(cloudSync: NewCloud()))
        {
            await app.SignInAsync();
            await app.SyncNowAsync();
            Assert.Equal(uploaded, (await app.GetSyncAsync()).Device!.LastSyncAt);
        }
        _home.Clock.Now += TimeSpan.FromHours(1);
        using var reopened = _home.Api(cloudSync: NewCloud());
        Assert.Equal(uploaded, (await reopened.GetOverviewAsync()).Collector.LastSyncAt);
        Assert.Equal(uploaded, (await reopened.GetSyncAsync()).Device!.LastSyncAt);
        await reopened.DisconnectAsync();
        Assert.Null((await reopened.GetOverviewAsync()).Collector.LastSyncAt);
        _server.SignInUid = "uid-2";
        await reopened.SignInAsync();
        Assert.Null((await reopened.GetSyncAsync()).Device!.LastSyncAt);
        await reopened.DisconnectAsync();
        _server.SignInUid = "uid-1";
        await reopened.SignInAsync();
        Assert.Equal(uploaded, (await reopened.GetSyncAsync()).Device!.LastSyncAt);
    }

    [Fact]
    public async Task Last_upload_does_not_leak_between_projects_or_environments()
    {
        using (var app = _home.Api(cloudSync: NewCloud()))
        {
            await app.SignInAsync();
            await app.SyncNowAsync();
        }
        foreach (var options in new[]
        {
            new FirebaseOptions { ProjectId = "other-project", UseEmulator = true, OAuthClientId = "test" },
            new FirebaseOptions { ProjectId = "utoken-test", UseEmulator = false, ApiKey = "test", OAuthClientId = "test" },
        })
        {
            var cloud = new FirebaseCloudSync(_http, options,
                Path.Combine(_home.DataDirectory, Guid.NewGuid() + ".json"), _google, _home.Clock);
            using var other = _home.Api(cloudSync: cloud);
            await other.SignInAsync();
            Assert.Null((await other.GetSyncAsync()).Device!.LastSyncAt);
        }
    }

    [Fact]
    public async Task Failed_upload_does_not_advance_the_saved_timestamp()
    {
        using (var app = _home.Api(cloudSync: NewCloud()))
        {
            await app.SignInAsync();
            await app.SyncNowAsync();
        }
        var uploaded = _home.Clock.Now;
        _home.Clock.Now += TimeSpan.FromHours(2);
        _server.CommitStatus = HttpStatusCode.ServiceUnavailable;
        using (var failing = _home.Api(cloudSync: NewCloud()))
        {
            Assert.Equal("failed", (await failing.SyncNowAsync()).State);
            Assert.Equal(uploaded, (await failing.GetSyncAsync()).Device!.LastSyncAt);
        }
        using var reopened = _home.Api(cloudSync: NewCloud());
        Assert.Equal(uploaded, (await reopened.GetSyncAsync()).Device!.LastSyncAt);
    }

    [Fact]
    public async Task Broken_status_file_does_not_block_session_restore_or_sync()
    {
        using (var app = _home.Api(cloudSync: NewCloud())) await app.SignInAsync();
        File.WriteAllText(Path.Combine(_home.DataDirectory, "sync-status.json"), "{bad");
        using var reopened = _home.Api(cloudSync: NewCloud());
        Assert.Null((await reopened.GetSyncAsync()).Device!.LastSyncAt);
        Assert.Equal("success", (await reopened.SyncNowAsync()).State);
        Assert.Equal(_home.Clock.Now, (await reopened.GetSyncAsync()).Device!.LastSyncAt);
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

    [Fact]
    public async Task Mobile_sync_request_runs_sync_and_marks_the_request_done()
    {
        using var app = _home.Api(cloudSync: NewCloud());
        await app.SignInAsync();
        Assert.Null(await app.ServeMobileSyncRequestsAsync());
        Assert.Contains("\"state\"", _server.Queries[^1].Body);
        Assert.EndsWith("/users/uid-1:runQuery", _server.Queries[^1].Path);
        Assert.Empty(_server.Commits);

        _server.PendingRequests.Add("req-1");
        var result = await app.ServeMobileSyncRequestsAsync();
        Assert.Equal("success", result!.State);
        Assert.Equal(3, _server.Commits.Count); // running, upload, done

        static IEnumerable<JsonNode> Writes(string body) => JsonNode.Parse(body)!["writes"]!.AsArray()!;
        var running = Assert.Single(Writes(_server.Commits[0].Body));
        Assert.EndsWith("users/uid-1/sync_requests/req-1", running["update"]!["name"]!.GetValue<string>());
        Assert.Equal("running", running["update"]!["fields"]!["state"]!["stringValue"]!.GetValue<string>());
        Assert.Contains(Writes(_server.Commits[1].Body), w => w["update"]!["name"]!.GetValue<string>().Contains("/daily/"));
        var profile = Writes(_server.Commits[1].Body).Last();
        Assert.Contains("desktop_name", profile["updateMask"]!["fieldPaths"]!.AsArray().Select(f => f!.GetValue<string>()));
        var done = Assert.Single(Writes(_server.Commits[2].Body));
        Assert.Equal("done", done["update"]!["fields"]!["state"]!["stringValue"]!.GetValue<string>());
        Assert.True(done["update"]!["fields"]!["error_code"]!.AsObject().ContainsKey("nullValue"));
    }

    [Fact]
    public async Task Mobile_sync_request_is_ignored_when_signed_out()
    {
        using var app = _home.Api(cloudSync: NewCloud());
        _server.PendingRequests.Add("req-1");
        Assert.Null(await app.ServeMobileSyncRequestsAsync());
        Assert.Empty(_server.Queries);
    }

    [Fact]
    public async Task Abandoned_running_request_is_reclaimed_after_lease_expires_including_after_restart()
    {
        var first = NewCloud();
        await first.SignInAsync();
        _server.RequestDocuments.Add(new JsonObject
        {
            ["name"] = "projects/utoken-test/databases/(default)/documents/users/uid-1/sync_requests/stuck",
            ["updateTime"] = "2026-11-06T00:00:00Z",
            ["fields"] = new JsonObject
            {
                ["state"] = new JsonObject { ["stringValue"] = "running" },
                ["started_at"] = new JsonObject { ["stringValue"] = _home.Clock.Now.ToString("O") },
                ["trigger"] = new JsonObject { ["stringValue"] = "ai_review" },
            },
        });
        Assert.Empty(await first.ClaimSyncRequestsAsync());
        Assert.Empty(_server.Commits);
        _home.Clock.Now += TimeSpan.FromMinutes(31);
        var reopened = NewCloud();
        await reopened.RestoreAsync();
        var reclaimed = Assert.Single(await reopened.ClaimSyncRequestsAsync());
        Assert.Equal("stuck", reclaimed.Id);
        Assert.True(reclaimed.WantsReview);
        var write = JsonNode.Parse(Assert.Single(_server.Commits).Body)!["writes"]![0]!;
        Assert.Equal("2026-11-06T00:00:00Z", write["currentDocument"]!["updateTime"]!.GetValue<string>());
        Assert.Equal(_home.Clock.Now.ToString("O"), write["update"]!["fields"]!["started_at"]!["stringValue"]!.GetValue<string>());
        await reopened.FinishSyncRequestsAsync(["stuck"], null);
        Assert.Equal("done", JsonNode.Parse(_server.Commits[^1].Body)!["writes"]![0]!["update"]!["fields"]!["state"]!["stringValue"]!.GetValue<string>());
    }

    [Fact]
    public async Task Legacy_running_request_without_lease_is_reclaimed()
    {
        var cloud = NewCloud();
        await cloud.SignInAsync();
        _server.RequestDocuments.Add(new JsonObject
        {
            ["name"] = "projects/utoken-test/databases/(default)/documents/users/uid-1/sync_requests/legacy",
            ["fields"] = new JsonObject { ["state"] = new JsonObject { ["stringValue"] = "running" } },
        });
        Assert.Equal(new[] { "legacy" }, (await cloud.ClaimSyncRequestsAsync()).Select(r => r.Id));
    }

    private sealed class FirebaseServer : HttpMessageHandler
    {
        public string SignInUid = "uid-1";
        public bool Offline;
        public int Refreshes;
        public HttpStatusCode CommitStatus = HttpStatusCode.OK;
        public Dictionary<string, JsonObject> Profiles { get; } = [];
        public List<string> Bindings { get; } = [];
        public string? ClaimWinner;
        private int _profileVersion;
        private HttpResponseMessage? ProfileRequest(HttpRequestMessage request, string? body)
        {
            var path = request.RequestUri!.AbsolutePath;
            if (request.Method == HttpMethod.Get && path.Contains("/documents/users/"))
            {
                var key = path.Split("/documents/")[1];
                return Profiles.TryGetValue(key, out var doc)
                    ? new(HttpStatusCode.OK) { Content = new StringContent(doc.ToJsonString()) }
                    : new(HttpStatusCode.NotFound);
            }
            if (!path.EndsWith(":commit") || body is null) return null;
            var writes = JsonNode.Parse(body)!["writes"]!.AsArray();
            foreach (var write in writes)
            {
                var name = write!["update"]!["name"]!.GetValue<string>().Split("/documents/")[1];
                if (ClaimWinner is { } winner && write["update"]!["fields"]?["collector_id"] is not null)
                {
                    ClaimWinner = null;
                    Profiles[name] = new JsonObject { ["fields"] = new JsonObject { ["collector_id"] = new JsonObject { ["stringValue"] = winner } }, ["updateTime"] = "2026-01-01T00:00:00Z" };
                }
                if (name.Split('/').Length != 2) continue;
                Profiles.TryGetValue(name, out var current);
                var condition = write["currentDocument"];
                if (condition?["exists"]?.GetValue<bool>() == false && current is not null ||
                    condition?["updateTime"] is { } stamp && stamp.GetValue<string>() != current?["updateTime"]?.GetValue<string>())
                    return new(HttpStatusCode.Conflict) { Content = new StringContent("{}") };
            }
            var binding = false;
            foreach (var write in writes)
            {
                var name = write!["update"]!["name"]!.GetValue<string>().Split("/documents/")[1];
                if (name.Split('/').Length != 2) continue;
                if (!Profiles.TryGetValue(name, out var doc)) doc = new JsonObject { ["fields"] = new JsonObject() };
                foreach (var field in write["update"]!["fields"]!.AsObject()) doc["fields"]![field.Key] = field.Value?.DeepClone();
                doc["updateTime"] = DateTimeOffset.UnixEpoch.AddTicks(++_profileVersion).ToString("O");
                Profiles[name] = doc;
                binding |= write["update"]!["fields"]?["collector_id"] is not null;
            }
            if (!binding) return null;
            Bindings.Add(body);
            return new(HttpStatusCode.OK) { Content = new StringContent("{\"writeResults\":[]}") };
        }

        public List<(string Auth, string Body)> Commits { get; } = [];
        public List<string> PendingRequests { get; } = [];
        public List<JsonObject> RequestDocuments { get; } = [];
        public List<(string Path, string Body)> Queries { get; } = [];

        protected override async Task<HttpResponseMessage> SendAsync(HttpRequestMessage request, CancellationToken ct)
        {
            if (Offline) throw new HttpRequestException("Offline test");
            string path = request.RequestUri!.AbsolutePath;
            if (request.Method == HttpMethod.Get && ProfileRequest(request, null) is { } get) return get;
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
            if (path.EndsWith(":runQuery"))
            {
                Queries.Add((path, await request.Content!.ReadAsStringAsync(ct)));
                var rows = PendingRequests.Select(id => new
                {
                    document = new { name = $"projects/utoken-test/databases/(default)/documents/users/{SignInUid}/sync_requests/{id}" },
                }).ToArray();
                PendingRequests.Clear();
                if (RequestDocuments.Count > 0) return Json(RequestDocuments.Select(d => new { document = d }).ToArray());
                return Json(rows.Length == 0 ? new object[] { new { readTime = "2026-11-10T00:00:00Z" } } : rows);
            }
            if (path.EndsWith(":commit"))
            {
                if (CommitStatus != HttpStatusCode.OK) return new(CommitStatus) { Content = new StringContent("{}") };
                var body = await request.Content!.ReadAsStringAsync(ct);
                if (ProfileRequest(request, body) is { } profile) return profile;
                Commits.Add((request.Headers.Authorization!.ToString(), body));
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
