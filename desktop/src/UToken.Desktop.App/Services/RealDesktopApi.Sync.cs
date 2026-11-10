using System.Text;
using System.Text.Json;
using UToken.Core.Aggregation;
using UToken.Desktop.App.Models;
using UToken.Engine;
using UToken.Sync;
using UToken.Sync.Auth;

namespace UToken.Desktop.App.Services;

/// <summary>
/// Đồng bộ lên Firestore và tài khoản Google. Desktop và mobile kết nối bằng cách đăng nhập cùng một tài khoản
/// (không dùng mã ghép đôi). "Sync now": quét log → tính daily/efficiency → đẩy các bản daily chưa đẩy + efficiency.
/// </summary>
public sealed partial class RealDesktopApi
{
    private DateTimeOffset? _lastAnalysisAt;
    private DateTimeOffset? _lastUploadAt;
    private long _bytesSent;
    private readonly List<SyncHistoryData> _history = [];
    private bool _cloudRestored;

    /// <summary>Snapshot của lần phân tích gần nhất.</summary>
    public AnalysisSnapshot? LastSnapshot { get; private set; }

    private async Task<CloudAccount?> AccountAsync(CancellationToken ct)
    {
        if (_cloud is null) return null;
        if (!_cloudRestored)
        {
            _cloudRestored = true;
            await _cloud.RestoreAsync(ct);
        }
        return _cloud.Account;
    }

    private string DeviceLabel(CloudAccount a) => a.Emulator ? "Firebase emulator" : $"Firebase · {a.ProjectId}";

    private MobileDevice? AccountDevice(CloudAccount? a) => a is null ? null : new MobileDevice(
        Name: a.Email,
        Platform: DeviceLabel(a),
        Version: a.DisplayName ?? "Google account",
        Initial: a.Email.Length > 0 ? a.Email[..1].ToUpperInvariant() : "?",
        IsOnline: true,
        LastSyncAt: _lastUploadAt,
        TransferredBytes: _bytesSent,
        ReferenceTime: Now);

    private (int Docs, long Bytes) PendingDocuments()
    {
        var dirty = _store.GetDirtyDaily();
        return (dirty.Count, dirty.Sum(d => (long)Encoding.UTF8.GetByteCount(d.Json)));
    }

    private SyncData BuildSync(CloudAccount? account)
    {
        var (docs, bytes) = PendingDocuments();
        return new SyncData(
            Device: AccountDevice(account),
            EncryptionTitle: "Encrypted sync (TLS + Firebase)",
            EncryptionDescription: account is null
                ? "Sign in with the Google account you use in uToken mobile. Only daily usage summaries are uploaded."
                : "Daily usage summaries are sent over TLS and stored encrypted by Firebase. Firestore Security Rules limit them to your account.",
            Privacy:
            [
                new("Usage metadata", "Yes", "#2EC790"),
                new("Prompt content", "No", "#2EC790"),
                new("Summaries waiting", docs.ToString(), docs == 0 ? "#2EC790" : "#FFAD38"),
            ],
            History: _history.ToArray(),
            NextSync: new SyncScenario(docs == 0 ? "no_new_usage" : "pending",
                docs == 0 ? "Everything is uploaded." : $"{docs} daily summaries are ready to upload.", docs, bytes),
            ReferenceTime: Now);
    }

    public async Task<SyncData> GetSyncAsync(CancellationToken ct = default)
    {
        var account = await AccountAsync(ct);
        return await WithStoreAsync(() => BuildSync(account), ct);
    }

    public async Task<SyncStateConfig> GetSyncStateConfigAsync(CancellationToken ct = default)
    {
        var config = await ReadContentAsync<SyncStateConfig>("sync-states.json", ct);
        // Hàng đợi thật: số event theo nguồn trong các ngày chưa đẩy lên cloud.
        var queue = await WithStoreAsync(() =>
        {
            var dirty = _store.GetDirtyDaily();
            if (dirty.Count == 0) return Array.Empty<SyncQueueItem>();
            var dates = dirty.Select(d => DateOnly.Parse(d.Date)).ToHashSet();
            var from = _engine.Now.AddDays(-(_engine.Today.DayNumber - dates.Min().DayNumber) - 1);
            var events = _store.GetEvents(from, _engine.Now.AddSeconds(1))
                .Where(e => dates.Contains(DailyAggregator.LocalDate(e.OccurredAt, _engine.TimeZone)))
                .ToList();
            long totalBytes = dirty.Sum(d => (long)Encoding.UTF8.GetByteCount(d.Json));
            return _locations.Select(l =>
            {
                int n = events.Count(e => e.Provider == l.Provider);
                return new SyncQueueItem(l.Id, l.Name, n, events.Count == 0 ? 0 : totalBytes * n / events.Count);
            }).Where(q => q.Events > 0).ToArray();
        }, ct);
        return config with { Queue = queue };
    }

    /// <summary>
    /// Phân tích log rồi đẩy lên Firestore. State: success, no_new_usage, not_paired (chưa đăng nhập),
    /// revoked (phiên hết hiệu lực, cần đăng nhập lại), network (không tới được Firebase), failed.
    /// </summary>
    public async Task<SyncResult> SyncNowAsync(CancellationToken ct = default)
    {
        await UpdatePricesAsync(ct); // chỉ tải khi giá đã cũ hơn ~1 ngày
        var retention = (await GetSettingsAsync(ct)).Values.RetentionDays;
        var snapshot = await WithStoreAsync(() =>
        {
            var s = _engine.Run(ct);
            DataChanged();
            _store.PruneBefore(Now.AddDays(-retention));
            return s;
        }, ct);
        LastSnapshot = snapshot;
        _lastScan = snapshot.Scan;
        _lastScanAt = _lastAnalysisAt = Now;
        _localSettings?.Record($"Analysis: {snapshot.Scan.NewEvents} new events, {snapshot.ChangedDaily.Count} daily summaries changed");

        var account = await AccountAsync(ct);
        if (account is null)
        {
            var (docs, _) = await WithStoreAsync(PendingDocuments, ct);
            return new("not_paired",
                $"Analysis updated ({snapshot.Scan.NewEvents} new events). Sign in with Google to upload {docs} daily summaries.",
                await GetSyncAsync(ct));
        }

        var (dirty, efficiency) = await WithStoreAsync(() => (_store.GetDirtyDaily(), snapshot.Efficiency), ct);
        try
        {
            var docs = dirty.Select(d => JsonSerializer.Deserialize<DailyDoc>(d.Json)!).ToList();
            long sent = await _cloud!.UploadAsync(docs, efficiency, ct);
            await WithStoreAsync(() => { foreach (var d in dirty) _store.MarkDailySynced(d.Date); return 0; }, ct);
            _lastUploadAt = Now;
            _bytesSent += sent;
            // Cột EVENTS: số lần gọi model nằm trong các bản daily vừa đẩy lên.
            _history.Insert(0, new SyncHistoryData(Now, account.Email, docs.Sum(d => d.Totals.Requests), sent, "Success"));
            var state = dirty.Count == 0 && snapshot.Scan.NewEvents == 0 ? "no_new_usage" : "success";
            await RunJudgeAfterSyncAsync(ct);
            return new(state,
                state == "success" ? $"Uploaded {dirty.Count} daily summaries and the efficiency report." : "No new usage since the last sync.",
                await GetSyncAsync(ct));
        }
        catch (CloudAuthException)
        {
            _localSettings?.Record("Sync: session revoked");
            _history.Insert(0, new SyncHistoryData(Now, account.Email, snapshot.Scan.NewEvents, 0, "Failed"));
            return new("revoked", "Your Google session has expired or was revoked. Sign in again to resume sync.", await GetSyncAsync(ct));
        }
        catch (Exception ex) when (ex is HttpRequestException { StatusCode: null } or TaskCanceledException { InnerException: TimeoutException })
        {
            _localSettings?.Record("Sync: network error " + ex.GetType().Name);
            _history.Insert(0, new SyncHistoryData(Now, account.Email, snapshot.Scan.NewEvents, 0, "Failed"));
            return new("network", "Cannot reach Firebase. Summaries stay queued on this computer.", await GetSyncAsync(ct));
        }
        catch (HttpRequestException ex)
        {
            _localSettings?.Record($"Sync failed: {(int?)ex.StatusCode}");
            _history.Insert(0, new SyncHistoryData(Now, account.Email, snapshot.Scan.NewEvents, 0, "Failed"));
            return new("failed", $"Upload failed ({(int?)ex.StatusCode}). Summaries stay queued and will be retried.", await GetSyncAsync(ct));
        }
    }

    public async Task<SyncData> DisconnectAsync(CancellationToken ct = default)
    {
        if (_cloud is not null) await _cloud.SignOutAsync(ct);
        _localSettings?.Record("Signed out");
        return await GetSyncAsync(ct);
    }

    // ───────────────────────── Tài khoản Google ─────────────────────────

    public Task<OverviewScenario[]> GetPairingScenariosAsync(CancellationToken ct = default) =>
        ReadContentAsync<OverviewScenario[]>("pairing-states.json", ct);

    public Task<PairingData> GetPairingInfoAsync(CancellationToken ct = default) =>
        Task.FromResult(new PairingData(Now.Add(GoogleLoopbackSignIn.Timeout), (int)GoogleLoopbackSignIn.Timeout.TotalMinutes,
            _cloud is null
                ? "Google sign-in is not configured. Add Firebase:OAuthClientId to appsettings.Local.json."
                : "A browser window opens for Google sign-in. Use the same account as uToken mobile.",
            ["Usage metadata only", "No prompt content", "Encrypted sync", "Sign out anytime"]));

    public async Task<PairingResult> SignInAsync(CancellationToken ct = default)
    {
        if (_cloud is null)
            return new("unavailable", "Google sign-in is not configured. Add Firebase:OAuthClientId and ApiKey to appsettings.Local.json.");
        try
        {
            var previous = (await AccountAsync(ct))?.Uid;
            var account = await _cloud.SignInAsync(ct);
            // Tài khoản khác (hoặc lần đầu): đẩy lại toàn bộ lịch sử daily cho tài khoản này.
            if (previous != account.Uid) await WithStoreAsync(() => { _store.MarkAllDailyDirty(); return 0; }, ct);
            _localSettings?.Record("Signed in with Google");
            return new("success", $"Signed in as {account.Email}. Open Sync to upload your usage.", await GetSyncAsync(ct));
        }
        catch (TimeoutException)
        {
            return new("expired", "Sign-in timed out. Start again and finish signing in within 3 minutes.");
        }
        catch (GoogleSignInException ex)
        {
            _localSettings?.Record("Sign-in failed: Google authorization/token exchange");
            return new("rejected", ex.Message);
        }
        catch (CloudAuthException ex)
        {
            _localSettings?.Record("Sign-in failed: Firebase authentication rejected");
            return new("rejected", ex.ErrorCode switch
            {
                "OPERATION_NOT_ALLOWED" => "Google sign-in is disabled in Firebase. Enable the Google provider in Firebase Authentication.",
                "INVALID_API_KEY" or "API_KEY_INVALID" => "Firebase API key is invalid. Check Firebase:ApiKey and the selected project.",
                "PROJECT_NOT_FOUND" or "CONFIGURATION_NOT_FOUND" => "Firebase authentication configuration was not found. Check the project and enable Authentication.",
                "INVALID_IDP_RESPONSE" or "INVALID_CREDENTIAL" or "INVALID_ID_TOKEN" => "Firebase rejected the Google credential. Check that the Desktop OAuth client belongs to the Firebase project, then sign in again.",
                "USER_DISABLED" => "This Firebase account is disabled. Contact the project administrator.",
                "TOO_MANY_ATTEMPTS_TRY_LATER" => "Firebase temporarily blocked sign-in after too many attempts. Try again later.",
                _ => "Firebase rejected the Google credential. Check the Google provider, OAuth client and Firebase project configuration."
            });
        }
        catch (HttpRequestException ex)
        {
            _localSettings?.Record("Sign-in failed: Firebase connection/HTTP " + (int?)ex.StatusCode);
            return new("rejected", ex.StatusCode is null
                ? "Cannot reach Firebase Authentication. Check your connection. If UseEmulator is true, start the Auth Emulator and check its host/port."
                : $"Firebase Authentication request failed (HTTP {(int)ex.StatusCode}). Check API key restrictions or try again later.");
        }
        catch (OperationCanceledException) when (!ct.IsCancellationRequested)
        {
            return new("expired", "Firebase sign-in timed out. Check your connection and try again.");
        }
        catch (Exception ex) when (ex is System.IO.IOException or UnauthorizedAccessException or System.Security.Cryptography.CryptographicException)
        {
            _localSettings?.Record("Sign-in failed: local session storage");
            return new("rejected", "Could not securely save the sign-in session. Check local folder permissions and your Windows user profile, then try again.");
        }
        catch (Exception ex) when (ex is InvalidOperationException or InvalidDataException or System.Text.Json.JsonException or System.Net.HttpListenerException)
        {
            _localSettings?.Record("Sign-in failed: invalid configuration, response or local callback");
            return new("rejected", "Sign-in configuration, server response or local browser callback is invalid. Check the Desktop OAuth settings and try again.");
        }
    }
}
