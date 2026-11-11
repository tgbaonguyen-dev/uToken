using System.Text;
using System.Net;
using System.Security.Cryptography;
using System.Text.Json;
using System.Text.Json.Nodes;
using UToken.Core.Aggregation;
using UToken.Core.Efficiency;
using UToken.Sync.Auth;
using UToken.Insights;

namespace UToken.Sync;

public sealed class DesktopAlreadyLinkedException() : Exception("This account is linked to another desktop. Use that desktop to sync.");

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

    Task<long> UploadInsightsAsync(InsightDoc insights, CancellationToken ct = default);

    /// <summary>
    /// Lấy các yêu cầu sync mobile tạo (users/{uid}/sync_requests, state = pending) và chuyển chúng sang running.
    /// Trả về các yêu cầu đã nhận. Mặc định không có yêu cầu nào (bản giả lập/offline).
    /// </summary>
    Task<IReadOnlyList<MobileSyncRequest>> ClaimSyncRequestsAsync(CancellationToken ct = default) =>
        Task.FromResult<IReadOnlyList<MobileSyncRequest>>([]);

    /// <summary>Đánh dấu yêu cầu đã nhận là done hoặc failed (kèm error_code).</summary>
    Task FinishSyncRequestsAsync(IReadOnlyList<string> ids, string? errorCode, CancellationToken ct = default) =>
        Task.CompletedTask;
}

/// <summary>
/// ICloudSync qua REST với Firebase ID token của người dùng (ADR-0003), nên Security Rules luôn được áp dụng.
/// Refresh token lưu trong <paramref name="sessionFile"/> (chỉ chủ tài khoản máy đọc được trên Linux/macOS).
/// Windows sessions use DPAPI CurrentUser; legacy JSON sessions are migrated on restore.
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
    private string? _desktopId;

    public FirebaseCloudSync(HttpClient http, FirebaseOptions options, string sessionFile, IGoogleSignIn? google = null, TimeProvider? clock = null, string? desktopId = null)
    {
        _desktopId = desktopId;
        _http = http;
        _options = options;
        _sessionFile = sessionFile;
        _clock = clock ?? TimeProvider.System;
        _google = google ?? new GoogleLoopbackSignIn(http, options);
        _auth = new FirebaseAuthClient(http, options, _clock);
        _firestore = new FirestoreRestClient(http, options, GetIdTokenAsync);
    }

    public CloudAccount? Account => _session is { } s ? new(s.Uid, s.Email, s.DisplayName, _options.ProjectId, _options.UseEmulator) : null;

    public async Task<CloudAccount?> RestoreAsync(CancellationToken ct = default)
    {
        await _tokenLock.WaitAsync(ct);
        try { _session = LoadSession(); return Account; }
        finally { _tokenLock.Release(); }
    }

    public async Task<CloudAccount> SignInAsync(CancellationToken ct = default)
    {
        await _tokenLock.WaitAsync(ct);
        try
        {
            var googleIdToken = await _google.GetGoogleIdTokenAsync(ct);
            var session = await _auth.SignInWithGoogleIdTokenAsync(googleIdToken, ct);
            SaveSession(session);
            _session = session;
            return Account!;
        }
        finally { _tokenLock.Release(); }
    }

    public async Task SignOutAsync(CancellationToken ct = default)
    {
        await _tokenLock.WaitAsync(ct);
        try { ClearSession(); }
        finally { _tokenLock.Release(); }
    }

    private string SignOutMarker => _sessionFile + ".signed-out";

    private void ClearSession()
    {
        _session = null;
        try { File.Delete(_sessionFile); }
        catch (DirectoryNotFoundException) { }
        catch (Exception ex) when (ex is IOException or UnauthorizedAccessException)
        {
            // A locked token file must never restore an account after a successful sign-out.
            try { File.WriteAllText(SignOutMarker, "signed-out"); }
            catch (Exception markerError) when (markerError is IOException or UnauthorizedAccessException)
            {
                throw new IOException("Could not persist sign-out. Close applications using the session file and retry.", markerError);
            }
        }
    }

    public async Task<long> UploadAsync(IReadOnlyList<DailyDoc> daily, EfficiencyDoc efficiency, CancellationToken ct = default)
    {
        await _tokenLock.WaitAsync(ct);
        try
        {
            if (_session is not { } session) throw new CloudAuthException("Not signed in.");
            await EnsureCollectorAsync(session.Uid, ct);
            string uid = session.Uid;

            var writes = new List<JsonObject>();
            foreach (var d in daily)
                writes.Add(Update($"users/{uid}/daily/{d.Date}", FirestoreValues.Fields(d)));
            writes.Add(Update($"users/{uid}/efficiency/current", FirestoreValues.Fields(efficiency)));
            // Chỉ cập nhật đúng một trường ở users/{uid}, không ghi đè dữ liệu mobile đặt ở đó.
            var profile = Update($"users/{uid}", new JsonObject
            {
                ["last_sync_at"] = FirestoreValues.Value(_clock.GetUtcNow()),
                ["desktop_name"] = FirestoreValues.Value(Environment.MachineName),
            });
            profile["updateMask"] = new JsonObject { ["fieldPaths"] = new JsonArray("last_sync_at", "desktop_name") };
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
        catch (CloudAuthException)
        {
            ClearSession();
            throw;
        }
        finally { _tokenLock.Release(); }
    }

    public async Task<long> UploadInsightsAsync(InsightDoc insights, CancellationToken ct = default)
    {
        await _tokenLock.WaitAsync(ct);
        try
        {
            if (_session is not { } session) throw new CloudAuthException("Not signed in.");
            await EnsureCollectorAsync(session.Uid, ct);
            var body = new JsonObject { ["writes"] = new JsonArray(Update($"users/{session.Uid}/insights/current", FirestoreValues.Fields(insights))) }.ToJsonString();
            await _firestore.CommitAsync(body, ct);
            return Encoding.UTF8.GetByteCount(body);
        }
        catch (CloudAuthException) { ClearSession(); throw; }
        finally { _tokenLock.Release(); }
    }

    private string DesktopId()
    {
        if (_desktopId is not null) return _desktopId;
        var folder = Path.GetDirectoryName(Path.GetFullPath(_sessionFile))!;
        Directory.CreateDirectory(folder);
        var path = Path.Combine(folder, "desktop-id.txt");
        if (!File.Exists(path))
        {
            try
            {
                using var stream = new FileStream(path, FileMode.CreateNew, FileAccess.Write, FileShare.Read);
                using var writer = new StreamWriter(stream);
                writer.Write(Guid.NewGuid().ToString("N"));
            }
            catch (IOException) when (File.Exists(path)) { }
        }
        var id = File.ReadAllText(path).Trim();
        if (!Guid.TryParseExact(id, "N", out _)) throw new InvalidDataException("Invalid desktop installation identity.");
        return _desktopId = id;
    }

    private async Task EnsureCollectorAsync(string uid, CancellationToken ct)
    {
        var id = DesktopId();
        for (var attempt = 0; attempt < 2; attempt++)
        {
            var profile = await _firestore.GetDocumentAsync($"users/{uid}", ct);
            var owner = profile?["fields"]?["collector_id"]?["stringValue"]?.GetValue<string>();
            if (owner == id) return;
            if (!string.IsNullOrEmpty(owner)) throw new DesktopAlreadyLinkedException();
            var write = Update($"users/{uid}", new JsonObject
            {
                ["collector_id"] = FirestoreValues.Value(id),
                ["desktop_name"] = FirestoreValues.Value(Environment.MachineName),
            });
            write["updateMask"] = new JsonObject { ["fieldPaths"] = new JsonArray("collector_id", "desktop_name") };
            write["currentDocument"] = profile is null
                ? new JsonObject { ["exists"] = false }
                : new JsonObject { ["updateTime"] = profile["updateTime"]!.GetValue<string>() };
            try
            {
                await _firestore.CommitAsync(new JsonObject { ["writes"] = new JsonArray(write) }.ToJsonString(), ct);
                return;
            }
            catch (HttpRequestException ex) when (attempt == 0 && ex.StatusCode is HttpStatusCode.Conflict or HttpStatusCode.PreconditionFailed or HttpStatusCode.BadRequest)
            { /* Another desktop or profile update may have won; read before retrying. */ }
        }
    }

    public async Task<IReadOnlyList<MobileSyncRequest>> ClaimSyncRequestsAsync(CancellationToken ct = default)
    {
        await _tokenLock.WaitAsync(ct);
        try
        {
            if (_session is not { } session) return [];
            var profile = await _firestore.GetDocumentAsync($"users/{session.Uid}", ct);
            var owner = profile?["fields"]?["collector_id"]?["stringValue"]?.GetValue<string>();
            if (!string.IsNullOrEmpty(owner) && owner != DesktopId()) return [];
            var query = new JsonObject
            {
                ["from"] = new JsonArray(new JsonObject { ["collectionId"] = "sync_requests" }),
                ["where"] = new JsonObject
                {
                    ["fieldFilter"] = new JsonObject
                    {
                        ["field"] = new JsonObject { ["fieldPath"] = "state" },
                        ["op"] = "IN",
                        ["value"] = new JsonObject { ["arrayValue"] = new JsonObject { ["values"] = new JsonArray(FirestoreValues.Value("pending"), FirestoreValues.Value("running")) } },
                    },
                },
                ["limit"] = 20,
            };
            var docs = await _firestore.RunQueryAsync($"users/{session.Uid}", query, ct);
            // shortcut: leases expire after 30 minutes; add renewal if syncs can exceed that duration.
            var cutoff = _clock.GetUtcNow().AddMinutes(-30);
            var claimable = docs.Where(d =>
            {
                var fields = d["fields"];
                if (fields?["state"]?["stringValue"]?.GetValue<string>() != "running") return true;
                var started = fields?["started_at"]?["stringValue"]?.GetValue<string>();
                return !DateTimeOffset.TryParse(started, out var at) || at <= cutoff;
            }).ToList();
            var ids = claimable.Select(d => d["name"]!.GetValue<string>().Split('/')[^1]).ToList();
            var versions = claimable.Where(d => d["updateTime"] is not null).ToDictionary(
                d => d["name"]!.GetValue<string>().Split('/')[^1], d => d["updateTime"]!.GetValue<string>());
            if (ids.Count > 0) await SetRequestStateAsync(session.Uid, ids, "running", null, finished: false, ct, versions);
            return claimable.Select(d => new MobileSyncRequest(
                d["name"]!.GetValue<string>().Split('/')[^1],
                d["fields"]?["trigger"]?["stringValue"]?.GetValue<string>() ?? "manual_refresh")).ToList();
        }
        catch (CloudAuthException) { ClearSession(); throw; }
        finally { _tokenLock.Release(); }
    }

    public async Task FinishSyncRequestsAsync(IReadOnlyList<string> ids, string? errorCode, CancellationToken ct = default)
    {
        if (ids.Count == 0) return;
        await _tokenLock.WaitAsync(ct);
        try
        {
            if (_session is not { } session) return;
            await SetRequestStateAsync(session.Uid, ids, errorCode is null ? "done" : "failed", errorCode, finished: true, ct);
        }
        catch (CloudAuthException) { ClearSession(); throw; }
        finally { _tokenLock.Release(); }
    }

    private async Task SetRequestStateAsync(string uid, IReadOnlyList<string> ids, string state, string? errorCode, bool finished, CancellationToken ct, IReadOnlyDictionary<string, string>? versions = null)
    {
        var writes = new JsonArray();
        foreach (var id in ids)
        {
            var fields = new JsonObject { ["state"] = FirestoreValues.Value(state) };
            var mask = new JsonArray("state");
            if (finished)
            {
                fields["finished_at"] = FirestoreValues.Value(_clock.GetUtcNow().ToString("O"));
                fields["error_code"] = FirestoreValues.Value(errorCode);
                mask.Add("finished_at");
                mask.Add("error_code");
            }
            else
            {
                fields["started_at"] = FirestoreValues.Value(_clock.GetUtcNow().ToString("O"));
                mask.Add("started_at");
            }
            var write = Update($"users/{uid}/sync_requests/{id}", fields);
            write["updateMask"] = new JsonObject { ["fieldPaths"] = mask };
            write["currentDocument"] = versions is not null && versions.TryGetValue(id, out var version)
                ? new JsonObject { ["updateTime"] = version }
                : new JsonObject { ["exists"] = true };
            writes.Add(write);
        }
        await _firestore.CommitAsync(new JsonObject { ["writes"] = writes }.ToJsonString(), ct);
    }

    private JsonObject Update(string path, JsonObject fields) => new()
    {
        ["update"] = new JsonObject { ["name"] = _options.DocumentName(path), ["fields"] = fields },
    };

    /// <summary>ID token còn hạn; còn dưới 5 phút thì làm mới trước.</summary>
    private async Task<string> GetIdTokenAsync(CancellationToken ct)
    {
        if (_session is not { } s) throw new CloudAuthException("Not signed in.");
        if (s.ExpiresAt - _clock.GetUtcNow() > TimeSpan.FromMinutes(5)) return s.IdToken;
        var refreshed = await _auth.RefreshAsync(s, ct);
        SaveSession(refreshed);
        _session = refreshed;
        return refreshed.IdToken;
    }

    // ───────────── Lưu phiên trên máy ─────────────

    private sealed record StoredSession(string Uid, string Email, string? DisplayName, string RefreshToken, string ProjectId, bool Emulator);

    private void SaveSession(FirebaseSession s)
    {
        Directory.CreateDirectory(Path.GetDirectoryName(Path.GetFullPath(_sessionFile))!);
        var tmp = _sessionFile + "." + Guid.NewGuid().ToString("N") + ".tmp";
        byte[] payload = JsonSerializer.SerializeToUtf8Bytes(new StoredSession(s.Uid, s.Email, s.DisplayName, s.RefreshToken, _options.ProjectId, _options.UseEmulator));
        try
        {
            if (OperatingSystem.IsWindows())
            {
                var encrypted = ProtectedData.Protect(payload, null, DataProtectionScope.CurrentUser);
                File.WriteAllText(tmp, JsonSerializer.Serialize(new { Protection = "windows-dpapi-v1", Data = Convert.ToBase64String(encrypted) }));
            }
            else
            {
                File.WriteAllBytes(tmp, payload);
                File.SetUnixFileMode(tmp, UnixFileMode.UserRead | UnixFileMode.UserWrite);
            }
            File.Move(tmp, _sessionFile, overwrite: true);
            File.Delete(SignOutMarker);
        }
        finally
        {
            CryptographicOperations.ZeroMemory(payload);
            if (File.Exists(tmp)) File.Delete(tmp);
        }
    }

    private FirebaseSession? LoadSession()
    {
        try
        {
            if (File.Exists(SignOutMarker))
            {
                try { File.Delete(_sessionFile); }
                catch (Exception ex) when (ex is IOException or UnauthorizedAccessException) { }
                return null;
            }
            if (!File.Exists(_sessionFile)) return null;
            using var document = JsonDocument.Parse(File.ReadAllBytes(_sessionFile));
            bool protectedSession = document.RootElement.TryGetProperty("Protection", out var protection);
            StoredSession? stored;
            if (protectedSession)
            {
                if (!OperatingSystem.IsWindows() || protection.GetString() != "windows-dpapi-v1") return null;
                byte[] payload = ProtectedData.Unprotect(Convert.FromBase64String(document.RootElement.GetProperty("Data").GetString()!), null, DataProtectionScope.CurrentUser);
                try { stored = JsonSerializer.Deserialize<StoredSession>(payload); }
                finally { CryptographicOperations.ZeroMemory(payload); }
            }
            else stored = document.RootElement.Deserialize<StoredSession>();
            // Phiên của project khác hoặc của emulator/thật khác cấu hình hiện tại thì bỏ.
            if (stored is null || stored.ProjectId != _options.ProjectId || stored.Emulator != _options.UseEmulator) return null;
            // ID token chưa có: để hết hạn ngay, lần gọi đầu sẽ làm mới bằng refresh token.
            if (string.IsNullOrWhiteSpace(stored.Uid) || string.IsNullOrWhiteSpace(stored.RefreshToken)) return null;
            var session = new FirebaseSession(stored.Uid, stored.Email, stored.DisplayName, "", stored.RefreshToken, DateTimeOffset.MinValue);
            if (OperatingSystem.IsWindows() && !protectedSession) SaveSession(session);
            return session;
        }
        catch (Exception ex) when (ex is IOException or JsonException or UnauthorizedAccessException or CryptographicException or FormatException or KeyNotFoundException or InvalidOperationException or ArgumentException)
        {
            return null;
        }
    }
}

/// <summary>Yêu cầu từ mobile: trigger = screen_open, manual_refresh hoặc ai_review (sync rồi chạy AI review ngay).</summary>
public sealed record MobileSyncRequest(string Id, string Trigger)
{
    public bool WantsReview => Trigger == "ai_review";
}
