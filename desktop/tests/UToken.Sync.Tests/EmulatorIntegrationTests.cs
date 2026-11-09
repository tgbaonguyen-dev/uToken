using System.Net.Http.Headers;
using System.Text;
using System.Text.Json.Nodes;
using UToken.Core.Aggregation;
using UToken.Core.Efficiency;
using UToken.Sync;
using UToken.Sync.Auth;
using Xunit;

namespace UToken.Sync.Tests;

/// <summary>
/// Chạy với Firebase Emulator thật (Auth + Firestore + firestore.rules của nhóm):
///   cd firebase &amp;&amp; npx firebase emulators:exec --only auth,firestore --project utoken-78191 \
///     "cd ../desktop &amp;&amp; UTOKEN_EMULATOR=1 dotnet test tests/UToken.Sync.Tests --filter Emulator"
/// Không đặt UTOKEN_EMULATOR thì test kết thúc ngay (không gọi mạng).
/// </summary>
public sealed class EmulatorIntegrationTests : IDisposable
{
    private readonly DirectoryInfo _dir = Directory.CreateTempSubdirectory("utoken-emu-");
    private static bool Enabled => Environment.GetEnvironmentVariable("UTOKEN_EMULATOR") == "1";
    private static readonly FirebaseOptions Options = new() { ProjectId = "utoken-78191", UseEmulator = true, OAuthClientId = "client" };

    /// <summary>Auth emulator chấp nhận Google ID token không ký (alg=none).</summary>
    private sealed class EmulatorGoogle(string email) : IGoogleSignIn
    {
        public Task<string> GetGoogleIdTokenAsync(CancellationToken ct)
        {
            static string B64(string s) => Convert.ToBase64String(Encoding.UTF8.GetBytes(s)).TrimEnd('=').Replace('+', '-').Replace('/', '_');
            var payload = $$"""{"sub":"{{email}}","email":"{{email}}","email_verified":true,"name":"Emulator User"}""";
            return Task.FromResult($"{B64("""{"alg":"none","typ":"JWT"}""")}.{B64(payload)}.");
        }
    }

    [Fact]
    public async Task Emulator_accepts_uploads_under_security_rules()
    {
        if (!Enabled) return;
        using var http = new HttpClient();
        var sync = new FirebaseCloudSync(http, Options, Path.Combine(_dir.FullName, "auth.json"), new EmulatorGoogle("ana@example.com"));
        var account = await sync.SignInAsync();

        var daily = new DailyDoc("2026-11-07",
            new UsageBucket(1, 2, 0, 1000, 400, 0, 100, 40, 5_000, 0, 0, 0, 2.0, 1, 0, null, null),
            new Dictionary<string, UsageBucket>
            {
                ["codex|gpt-5.6-sol|abc123def456"] = new(1, 2, 0, 1000, 400, 0, 100, 40, 5_000, 0, 0, 0, 2.0, 1, 0, 4000, 1),
            },
            new TasksByState(1, 0, 0, 0, 0), "models.dev@x", "2026-11-07T10:00:00Z");
        var eff = new EfficiencyDoc("2026-10-09", "2026-11-07", "2026-11-07T10:00:00Z", 0,
            [new ProcessMetric("cache_hit_rate", null, 1.0, "good")], [], "models.dev@x");
        Assert.True(await sync.UploadAsync([daily], eff) > 0);

        // Đọc lại bằng quyền quản trị của emulator ("Bearer owner").
        using var req = new HttpRequestMessage(HttpMethod.Get, $"{Options.FirestoreBaseUrl}/users/{account.Uid}/daily/2026-11-07");
        req.Headers.Authorization = new AuthenticationHeaderValue("Bearer", "owner");
        var doc = JsonNode.Parse(await (await http.SendAsync(req)).Content.ReadAsStringAsync())!;
        var byKey = doc["fields"]!["by_key"]!["mapValue"]!["fields"]!;
        Assert.NotNull(byKey["codex|gpt-5.6-sol|abc123def456"]); // khóa có '|' và '.' được giữ nguyên
        Assert.Equal(2.0, doc["fields"]!["totals"]!["mapValue"]!["fields"]!["context_growth_sum"]!["doubleValue"]!.GetValue<double>());

        // Người khác không ghi được vào users/{uid} của mình (Security Rules).
        var other = new FirebaseCloudSync(http, Options, Path.Combine(_dir.FullName, "other.json"), new EmulatorGoogle("bob@example.com"));
        await other.SignInAsync();
        var rest = new FirestoreRestClient(http, Options, _ => Task.FromResult(GetIdToken(other)));
        var body = Commit(Options.DocumentName($"users/{account.Uid}/daily/2026-11-08"), "2");
        var denied = await Assert.ThrowsAsync<HttpRequestException>(() => rest.CommitAsync(body, default));
        Assert.Equal(System.Net.HttpStatusCode.Forbidden, denied.StatusCode);

        // Rules chặn daily sai schema_version.
        var mine = new FirestoreRestClient(http, Options, _ => Task.FromResult(GetIdToken(sync)));
        var wrong = Commit(Options.DocumentName($"users/{account.Uid}/daily/2026-11-09"), "1");
        await Assert.ThrowsAsync<HttpRequestException>(() => mine.CommitAsync(wrong, default));
    }

    private static string Commit(string name, string schemaVersion) =>
        "{\"writes\":[{\"update\":{\"name\":\"" + name + "\",\"fields\":{\"schema_version\":{\"integerValue\":\"" + schemaVersion + "\"}}}}]}";

    /// <summary>Lấy ID token hiện tại qua reflection (chỉ dùng trong test tích hợp).</summary>
    private static string GetIdToken(FirebaseCloudSync sync)
    {
        var field = typeof(FirebaseCloudSync).GetField("_session", System.Reflection.BindingFlags.NonPublic | System.Reflection.BindingFlags.Instance)!;
        return ((FirebaseSession)field.GetValue(sync)!).IdToken;
    }

    public void Dispose() => _dir.Delete(true);
}
