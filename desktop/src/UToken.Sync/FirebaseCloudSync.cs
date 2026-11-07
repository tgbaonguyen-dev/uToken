using System.Text;
using System.Text.Json;
using System.Text.Json.Nodes;
using UToken.Core.Aggregation;
using UToken.Core.Efficiency;
using UToken.Sync.Auth;

namespace UToken.Sync;

/// <summary>Tài khoản đã đăng nhập (không chứa token).</summary>
public sealed record CloudAccount(string Uid, string Email, string? DisplayName, string ProjectId, bool Emulator);

/// <summary>Đăng nhập Google và đẩy số liệu tổng hợp lên Firestore. Không bao giờ gửi prompt, câu trả lời hay code.</summary>
public interface ICloudSync
{
    CloudAccount? Account { get; }

    /// <summary>Khôi phục phiên đã lưu khi mở app (không mở trình duyệt). Null nếu chưa đăng nhập.</summary>
    Task<CloudAccount?> RestoreAsync(CancellationToken ct = default);

    /// <summary>Mở trình duyệt đăng nhập Google, đổi sang phiên Firebase và lưu lại.</summary>
    Task<CloudAccount> SignInAsync(CancellationToken ct = default);

    Task SignOutAsync(CancellationToken ct = default);

    /// <summary>Ghi users/{uid}/daily/{date}, users/{uid}/efficiency/current và users/{uid}.last_sync_at. Trả về số byte đã gửi.</summary>
    Task<long> UploadAsync(IReadOnlyList<DailyDoc> daily, EfficiencyDoc efficiency, CancellationToken ct = default);
}

/// <summary>
/// ICloudSync qua REST với Firebase ID token của người dùng (ADR-0003), nên Security Rules luôn được áp dụng.
/// Refresh token lưu trong <paramref name="sessionFile"/> (chỉ chủ tài khoản máy đọc được trên Linux/macOS).
/// Chưa mã hóa bằng DPAPI/libsecret (đã cắt khỏi MVP).
/// </summary>
public sealed class FirebaseCloudSync : ICloudSync
{
    private const int MaxWritesPerCommit = 400; // Firestore cho tối đa 500 write mỗi commit
    private readonly HttpClient _http;
    private readonly FirebaseOptions _options;
    private readonly string _sessionFile;
    private readonly IGoogleSignIn _google;
    private readonly FirebaseAuthClient _auth;
    private readonly FirestoreRestClient _firestore;
    private readonly TimeProvider _clock;
    private readonly SemaphoreSlim _tokenLock = new(1, 1);
    private FirebaseSession? _session;

    public FirebaseCloudSync(HttpClient http, FirebaseOptions options, string sessionFile, IGoogleSignIn? google = null, TimeProvider? clock = null)
    {
        _http = http;
        _options = options;
        _sessionFile = sessionFile;
        _clock = clock ?? TimeProvider.System;
        _google = google ?? new GoogleLoopbackSignIn(http, options);
        _auth = new FirebaseAuthClient(http, options, _clock);
        _firestore = new FirestoreRestClient(http, options, GetIdTokenAsync);
    }

    public CloudAccount? Account => _session is { } s ? new(s.Uid, s.Email, s.DisplayName, _options.ProjectId, _options.UseEmulator) : null;

    public Task<CloudAccount?> RestoreAsync(CancellationToken ct = default)
    {
        _session = LoadSession();
        return Task.FromResult(Account);
    }

    public async Task<CloudAccount> SignInAsync(CancellationToken ct = default)
    {
        var googleIdToken = await _google.GetGoogleIdTokenAsync(ct);
        _session = await _auth.SignInWithGoogleIdTokenAsync(googleIdToken, ct);
        SaveSession(_session);
        return Account!;
    }

    public Task SignOutAsync(CancellationToken ct = default)
    {
        _session = null;
        try { if (File.Exists(_sessionFile)) File.Delete(_sessionFile); }
        catch (IOException) { }
        return Task.CompletedTask;
    }

    public async Task<long> UploadAsync(IReadOnlyList<DailyDoc> daily, EfficiencyDoc efficiency, CancellationToken ct = default)
    {
        if (_session is not { } session) throw new CloudAuthException("Not signed in.");
        string uid = session.Uid;

        var writes = new List<JsonObject>();
        foreach (var d in daily)
            writes.Add(Update($"users/{uid}/daily/{d.Date}", FirestoreValues.Fields(d)));
        writes.Add(Update($"users/{uid}/efficiency/current", FirestoreValues.Fields(efficiency)));
        // Chỉ cập nhật đúng một trường ở users/{uid}, không ghi đè dữ liệu mobile đặt ở đó.
        var profile = Update($"users/{uid}", new JsonObject { ["last_sync_at"] = FirestoreValues.Value(_clock.GetUtcNow()) });
        profile["updateMask"] = new JsonObject { ["fieldPaths"] = new JsonArray("last_sync_at") };
        writes.Add(profile);

        long bytes = 0;
        foreach (var chunk in writes.Chunk(MaxWritesPerCommit))
        {
            var body = new JsonObject { ["writes"] = new JsonArray(chunk.Select(w => (JsonNode)w).ToArray()) }.ToJsonString();
            bytes += Encoding.UTF8.GetByteCount(body);
            await _firestore.CommitAsync(body, ct);
        }
        return bytes;
    }

    private JsonObject Update(string path, JsonObject fields) => new()
    {
        ["update"] = new JsonObject { ["name"] = _options.DocumentName(path), ["fields"] = fields },
    };

    /// <summary>ID token còn hạn; còn dưới 5 phút thì làm mới trước.</summary>
    private async Task<string> GetIdTokenAsync(CancellationToken ct)
    {
        await _tokenLock.WaitAsync(ct);
        try
        {
            if (_session is not { } s) throw new CloudAuthException("Not signed in.");
            if (s.ExpiresAt - _clock.GetUtcNow() > TimeSpan.FromMinutes(5)) return s.IdToken;
            try
            {
                _session = await _auth.RefreshAsync(s, ct);
                SaveSession(_session);
                return _session.IdToken;
            }
            catch (CloudAuthException)
            {
                await SignOutAsync(ct); // refresh token đã bị thu hồi → phải đăng nhập lại
                throw;
            }
        }
        finally { _tokenLock.Release(); }
    }

    // ───────────── Lưu phiên trên máy ─────────────

    private sealed record StoredSession(string Uid, string Email, string? DisplayName, string RefreshToken, string ProjectId, bool Emulator);

    private void SaveSession(FirebaseSession s)
    {
        Directory.CreateDirectory(Path.GetDirectoryName(Path.GetFullPath(_sessionFile))!);
        var tmp = _sessionFile + ".tmp";
        File.WriteAllText(tmp, JsonSerializer.Serialize(new StoredSession(s.Uid, s.Email, s.DisplayName, s.RefreshToken, _options.ProjectId, _options.UseEmulator)));
        if (!OperatingSystem.IsWindows()) File.SetUnixFileMode(tmp, UnixFileMode.UserRead | UnixFileMode.UserWrite);
        File.Move(tmp, _sessionFile, overwrite: true);
    }

    private FirebaseSession? LoadSession()
    {
        try
        {
            if (!File.Exists(_sessionFile)) return null;
            var stored = JsonSerializer.Deserialize<StoredSession>(File.ReadAllText(_sessionFile));
            // Phiên của project khác hoặc của emulator/thật khác cấu hình hiện tại thì bỏ.
            if (stored is null || stored.ProjectId != _options.ProjectId || stored.Emulator != _options.UseEmulator) return null;
            // ID token chưa có: để hết hạn ngay, lần gọi đầu sẽ làm mới bằng refresh token.
            return new FirebaseSession(stored.Uid, stored.Email, stored.DisplayName, "", stored.RefreshToken, DateTimeOffset.MinValue);
        }
        catch (Exception ex) when (ex is IOException or JsonException or UnauthorizedAccessException)
        {
            return null;
        }
    }
}
