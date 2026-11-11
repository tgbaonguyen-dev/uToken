using System.Net;
using System.Security.Cryptography;
using System.Text;
using System.Text.Json;
using System.Text.Json.Nodes;
using UToken.Core.Aggregation;
using UToken.Core.Efficiency;
using UToken.Sync;
using UToken.Sync.Auth;
using Xunit;

namespace UToken.Sync.Tests;

public sealed class CloudSyncTests : IDisposable
{
    private readonly DirectoryInfo _dir = Directory.CreateTempSubdirectory("utoken-sync-");
    private readonly MutableClock _clock = new(DateTimeOffset.Parse("2026-11-07T10:00:00Z"));
    private readonly FakeFirebase _server = new();
    private static readonly FirebaseOptions Options = new() { ProjectId = "utoken-test", UseEmulator = true, OAuthClientId = "client" };

    private string SessionFile => Path.Combine(_dir.FullName, "auth.json");
    private FirebaseCloudSync NewSync() => new(new HttpClient(_server), Options, SessionFile, new FakeGoogle(), _clock);

    private static DailyDoc Daily(string date) => new(date,
        new UsageBucket(1, 2, 0, 1000, 400, 0, 100, null, 5_000, 0, 0, 0, 2.0, 1, 0, null, null),
        new Dictionary<string, UsageBucket>(), new TasksByState(1, 0, 0, 0, 0), "models.dev@x", "2026-11-07T10:00:00Z");

    private static EfficiencyDoc Efficiency() => new("2026-10-09", "2026-11-07", "2026-11-07T10:00:00Z", 0,
        [new ProcessMetric("cache_hit_rate", null, 1.0, "good")], [], "models.dev@x");

    [Fact] // double luôn là doubleValue (kể cả 2.0, 1.0), số nguyên là integerValue dạng chuỗi
    public void Firestore_values_follow_csharp_types()
    {
        var fields = FirestoreValues.Fields(Daily("2026-11-07"));
        Assert.Equal("2", fields["schema_version"]!["integerValue"]!.GetValue<string>());
        var totals = fields["totals"]!["mapValue"]!["fields"]!;
        Assert.Equal(2.0, totals["context_growth_sum"]!["doubleValue"]!.GetValue<double>());
        Assert.Equal("1000", totals["input"]!["integerValue"]!.GetValue<string>());
        Assert.True(totals.AsObject().ContainsKey("thinking") && totals["thinking"]!.AsObject().ContainsKey("nullValue"));
        Assert.False(totals.AsObject().ContainsKey("TotalTokens")); // [JsonIgnore]

        var eff = FirestoreValues.Fields(Efficiency());
        var metric = eff["process_metrics"]!["arrayValue"]!["values"]![0]!["mapValue"]!["fields"]!;
        Assert.Equal(1.0, metric["value"]!["doubleValue"]!.GetValue<double>());
        Assert.Equal("1", eff["schema_version"]!["integerValue"]!.GetValue<string>());
    }

    [Fact]
    public async Task Sign_in_upload_and_restore_session()
    {
        var sync = NewSync();
        var account = await sync.SignInAsync();
        Assert.Equal("uid-1", account.Uid);
        Assert.Equal("ana@example.com", account.Email);
        Assert.Contains("google-id-token", _server.LastSignInBody);
        if (!OperatingSystem.IsWindows())
            Assert.Equal(UnixFileMode.UserRead | UnixFileMode.UserWrite, File.GetUnixFileMode(SessionFile));
        Assert.DoesNotContain("id-token-1", File.ReadAllText(SessionFile)); // chỉ lưu refresh token

        long bytes = await sync.UploadAsync([Daily("2026-11-06"), Daily("2026-11-07")], Efficiency());
        Assert.True(bytes > 0);
        var commit = Assert.Single(_server.Commits);
        Assert.Equal("Bearer id-token-1", commit.Auth);
        var writes = JsonNode.Parse(commit.Body)!["writes"]!.AsArray();
        Assert.Equal(4, writes.Count);
        Assert.Equal("projects/utoken-test/databases/(default)/documents/users/uid-1/daily/2026-11-06",
            writes[0]!["update"]!["name"]!.GetValue<string>());
        Assert.EndsWith("users/uid-1/efficiency/current", writes[2]!["update"]!["name"]!.GetValue<string>());
        Assert.Equal("last_sync_at", writes[3]!["updateMask"]!["fieldPaths"]![0]!.GetValue<string>());

        // Tên dự án: chỉ ghi khi được truyền, vào users/{uid}/meta/projects.
        await sync.UploadAsync([], Efficiency(), new Dictionary<string, string> { ["abc123def456"] = "uToken" });
        var named = JsonNode.Parse(_server.Commits[^1].Body)!["writes"]!.AsArray();
        var meta = named.Single(w => w!["update"]!["name"]!.GetValue<string>().EndsWith("users/uid-1/meta/projects"));
        Assert.Equal("uToken", meta!["update"]!["fields"]!["names"]!["mapValue"]!["fields"]!["abc123def456"]!["stringValue"]!.GetValue<string>());

        // Mở lại app: khôi phục phiên, token cũ không lưu nên lần ghi đầu phải làm mới.
        var reopened = NewSync();
        Assert.Equal("uid-1", (await reopened.RestoreAsync())!.Uid);
        await reopened.UploadAsync([], Efficiency());
        Assert.Equal(1, _server.Refreshes);
        Assert.Equal("Bearer id-token-2", _server.Commits[^1].Auth);
    }

    [Fact]
    public async Task Windows_session_is_dpapi_encrypted_and_can_be_restored()
    {
        if (!OperatingSystem.IsWindows()) return;
        await NewSync().SignInAsync();
        string text = File.ReadAllText(SessionFile);
        Assert.DoesNotContain("refresh-1", text);
        Assert.DoesNotContain("ana@example.com", text);
        using var envelope = JsonDocument.Parse(text);
        Assert.Equal("windows-dpapi-v1", envelope.RootElement.GetProperty("Protection").GetString());
        byte[] clear = ProtectedData.Unprotect(Convert.FromBase64String(envelope.RootElement.GetProperty("Data").GetString()!), null, DataProtectionScope.CurrentUser);
        try { Assert.Contains("refresh-1", Encoding.UTF8.GetString(clear)); }
        finally { CryptographicOperations.ZeroMemory(clear); }
        Assert.Equal("uid-1", (await NewSync().RestoreAsync())!.Uid);
    }

    [Fact]
    public async Task Windows_legacy_session_is_migrated_before_restore()
    {
        if (!OperatingSystem.IsWindows()) return;
        File.WriteAllText(SessionFile, """{"Uid":"uid-1","Email":"ana@example.com","DisplayName":"Ana","RefreshToken":"refresh-1","ProjectId":"utoken-test","Emulator":true}""");
        var sync = NewSync();
        Assert.Equal("uid-1", (await sync.RestoreAsync())!.Uid);
        Assert.DoesNotContain("refresh-1", File.ReadAllText(SessionFile));
        await sync.UploadAsync([], Efficiency());
        Assert.Equal(1, _server.Refreshes);
    }

    [Theory]
    [InlineData("not-base64")]
    [InlineData("AQIDBA==")]
    public async Task Corrupt_protected_session_requires_sign_in(string data)
    {
        File.WriteAllText(SessionFile, JsonSerializer.Serialize(new { Protection = "windows-dpapi-v1", Data = data, RefreshToken = "do-not-fall-back" }));
        Assert.Null(await NewSync().RestoreAsync());
    }

    [Fact]
    public async Task Expiring_token_is_refreshed_before_upload()
    {
        var sync = NewSync();
        await sync.SignInAsync();
        _clock.Now = _clock.Now.AddMinutes(58); // còn dưới 5 phút
        await sync.UploadAsync([], Efficiency());
        Assert.Equal(1, _server.Refreshes);
    }

    [Fact] // Refresh token bị thu hồi → đăng xuất, cần đăng nhập lại
    public async Task Revoked_refresh_token_signs_out()
    {
        var sync = NewSync();
        await sync.SignInAsync();
        _server.RefreshFails = true;
        _clock.Now = _clock.Now.AddHours(2);
        await Assert.ThrowsAsync<CloudAuthException>(() => sync.UploadAsync([], Efficiency()));
        Assert.Null(sync.Account);
        Assert.False(File.Exists(SessionFile));
    }

    [Fact]
    public async Task Unauthorized_commit_is_an_auth_error_and_other_errors_are_http_errors()
    {
        var sync = NewSync();
        await sync.SignInAsync();
        _server.CommitStatus = HttpStatusCode.Unauthorized;
        await Assert.ThrowsAsync<CloudAuthException>(() => sync.UploadAsync([], Efficiency()));
        Assert.Null(sync.Account);
        Assert.Null(await NewSync().RestoreAsync());
        await sync.SignInAsync();
        _server.CommitStatus = HttpStatusCode.ServiceUnavailable;
        var ex = await Assert.ThrowsAsync<HttpRequestException>(() => sync.UploadAsync([], Efficiency()));
        Assert.Equal(HttpStatusCode.ServiceUnavailable, ex.StatusCode);
        Assert.NotNull(sync.Account);
    }

    [Fact]
    public async Task Sign_out_of_a_locked_session_cannot_restore_the_old_account()
    {
        var sync = NewSync();
        await sync.SignInAsync();
        using (var locked = new FileStream(SessionFile, FileMode.Open, FileAccess.Read, FileShare.None))
        {
            await sync.SignOutAsync();
            Assert.Null(sync.Account);
            Assert.Null(await NewSync().RestoreAsync());
        }
        var reopened = NewSync();
        Assert.Null(await reopened.RestoreAsync());
        Assert.False(File.Exists(SessionFile));
        await reopened.SignInAsync();
        Assert.NotNull(await NewSync().RestoreAsync());
    }

    [Fact]
    public async Task Sign_out_reports_failure_if_neither_session_nor_sign_out_marker_can_be_written()
    {
        var sync = NewSync();
        await sync.SignInAsync();
        Directory.CreateDirectory(SessionFile + ".signed-out");
        if (OperatingSystem.IsWindows())
        {
            // Windows: file đang mở với FileShare.None thì không xóa được.
            using var locked = new FileStream(SessionFile, FileMode.Open, FileAccess.Read, FileShare.None);
            await Assert.ThrowsAsync<IOException>(() => sync.SignOutAsync());
        }
        else
        {
            // Linux/macOS cho xóa file đang mở; thư mục chỉ-đọc thì không xóa và không tạo được file nào.
            if (Environment.UserName == "root") return; // root bỏ qua quyền thư mục
            var dir = Path.GetDirectoryName(SessionFile)!;
            var mode = File.GetUnixFileMode(dir);
            File.SetUnixFileMode(dir, UnixFileMode.UserRead | UnixFileMode.UserExecute);
            try { await Assert.ThrowsAnyAsync<Exception>(() => sync.SignOutAsync()); }
            finally { File.SetUnixFileMode(dir, mode); }
        }
        Assert.Null(sync.Account);
    }

    [Fact] // Phiên của project/emulator khác cấu hình hiện tại thì bỏ
    public async Task Session_for_another_project_is_ignored()
    {
        await NewSync().SignInAsync();
        var other = new FirebaseCloudSync(new HttpClient(_server), new FirebaseOptions { ProjectId = "other", UseEmulator = true }, SessionFile, new FakeGoogle(), _clock);
        Assert.Null(await other.RestoreAsync());
    }

    [Fact]
    public async Task Upload_requires_sign_in() =>
        await Assert.ThrowsAsync<CloudAuthException>(() => NewSync().UploadAsync([], Efficiency()));

    [Fact]
    public async Task Another_desktop_cannot_overwrite_the_bound_collector()
    {
        var first = NewSync();
        await first.SignInAsync();
        await first.UploadAsync([Daily("2026-11-07")], Efficiency());
        var before = _server.Commits.Count;
        var other = new FirebaseCloudSync(new HttpClient(_server), Options,
            Path.Combine(_dir.FullName, "other", "auth.json"), new FakeGoogle(), _clock, desktopId: "other-desktop");
        await other.SignInAsync();
        await Assert.ThrowsAsync<DesktopAlreadyLinkedException>(() => other.UploadAsync([Daily("2026-11-07")], Efficiency()));
        Assert.Equal(before, _server.Commits.Count);
        Assert.Empty(await other.ClaimSyncRequestsAsync());
        Assert.Single(_server.Bindings);
        var reopened = NewSync();
        await reopened.RestoreAsync();
        await reopened.UploadAsync([], Efficiency());
        Assert.Equal(before + 1, _server.Commits.Count);
        Assert.Single(_server.Bindings);
    }

    [Fact]
    public async Task Racing_collector_claim_reads_the_winner_before_uploading_usage()
    {
        var sync = NewSync();
        await sync.SignInAsync();
        _server.ClaimWinner = "other-desktop";
        await Assert.ThrowsAsync<DesktopAlreadyLinkedException>(() => sync.UploadAsync([Daily("2026-11-07")], Efficiency()));
        Assert.Empty(_server.Commits);
        Assert.Equal("other-desktop", _server.Profiles["users/uid-1"]["fields"]!["collector_id"]!["stringValue"]!.GetValue<string>());
    }

    public void Dispose() => _dir.Delete(true);

    private sealed class FakeGoogle : IGoogleSignIn
    {
        public Task<string> GetGoogleIdTokenAsync(CancellationToken ct) => Task.FromResult("google-id-token");
    }

    private sealed class MutableClock(DateTimeOffset now) : TimeProvider
    {
        public DateTimeOffset Now { get; set; } = now;
        public override DateTimeOffset GetUtcNow() => Now;
    }

    /// <summary>Giả lập Identity Toolkit, Secure Token và Firestore :commit.</summary>
    private sealed class FakeFirebase : HttpMessageHandler
    {
        public string LastSignInBody = "";
        public int Refreshes;
        public bool RefreshFails;
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

        public List<(string Auth, string Body)> Commits = [];

        protected override async Task<HttpResponseMessage> SendAsync(HttpRequestMessage req, CancellationToken ct)
        {
            var url = req.RequestUri!.ToString();
            var body = req.Content is null ? "" : await req.Content.ReadAsStringAsync(ct);
            if (req.Method == HttpMethod.Get && ProfileRequest(req, null) is { } get) return get;
            if (url.Contains("accounts:signInWithIdp"))
            {
                LastSignInBody = body;
                return Json("""{"localId":"uid-1","email":"ana@example.com","displayName":"Ana","idToken":"id-token-1","refreshToken":"refresh-1","expiresIn":"3600"}""");
            }
            if (url.Contains("securetoken.googleapis.com/v1/token"))
            {
                if (RefreshFails) return Json("""{"error":{"message":"TOKEN_EXPIRED"}}""", HttpStatusCode.BadRequest);
                Refreshes++;
                return Json($$"""{"id_token":"id-token-{{Refreshes + 1}}","refresh_token":"refresh-{{Refreshes + 1}}","expires_in":"3600","user_id":"uid-1"}""");
            }
            if (url.EndsWith(":commit"))
            {
                if (CommitStatus != HttpStatusCode.OK) return Json("{}", CommitStatus);
                if (ProfileRequest(req, body) is { } profile) return profile;
                Commits.Add((req.Headers.Authorization!.ToString(), body));
                return Json("""{"writeResults":[]}""");
            }
            return new HttpResponseMessage(HttpStatusCode.NotFound);
        }

        private static HttpResponseMessage Json(string body, HttpStatusCode code = HttpStatusCode.OK) =>
            new(code) { Content = new StringContent(body, System.Text.Encoding.UTF8, "application/json") };
    }
}
