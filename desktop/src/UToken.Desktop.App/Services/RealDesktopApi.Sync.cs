using System.Text;
using UToken.Desktop.App.Models;
using UToken.Engine;

namespace UToken.Desktop.App.Services;

/// <summary>
/// Sync và ghép đôi. Bản này chưa có upload Firestore (phần việc của module sync, cần đăng nhập Google):
/// "Sync now" chạy phân tích thật trên máy (quét log, tính lại daily + efficiency, lưu vào daily_local)
/// và báo rõ là chưa có tài khoản đăng nhập. Không có thiết bị hay lịch sử giả.
/// </summary>
public sealed partial class RealDesktopApi
{
    private const string ThisComputer = "This computer";
    private DateTimeOffset? _lastAnalysisAt;
    private readonly List<SyncHistoryData> _history = [];

    /// <summary>
    /// Cho lớp sync gắn vào sau: nhận snapshot đã tính, đẩy lên Firestore, trả về số byte đã gửi.
    /// Null = chưa đăng nhập/chưa cấu hình, chỉ phân tích trên máy.
    /// </summary>
    public Func<AnalysisSnapshot, CancellationToken, Task<long>>? Uploader { get; set; }

    /// <summary>Snapshot của lần phân tích gần nhất (để lớp sync hoặc màn hình khác dùng lại).</summary>
    public AnalysisSnapshot? LastSnapshot { get; private set; }

    private (int Docs, long Bytes) PendingDocuments()
    {
        var dirty = _store.GetDirtyDaily();
        return (dirty.Count, dirty.Sum(d => (long)Encoding.UTF8.GetByteCount(d.Json)));
    }

    private SyncData BuildSync()
    {
        var (docs, bytes) = PendingDocuments();
        var now = Now;
        return new SyncData(
            Device: null,
            EncryptionTitle: "Encrypted sync",
            EncryptionDescription: "Daily summaries are sent over TLS and stored encrypted by Firebase. Cloud upload starts after Google sign-in.",
            Privacy:
            [
                new("Usage metadata", "Yes", "#2EC790"),
                new("Prompt content", "No", "#2EC790"),
                new("Daily summaries waiting", docs.ToString(), docs == 0 ? "#2EC790" : "#FFAD38"),
            ],
            History: _history.ToArray(),
            NextSync: new SyncScenario(docs == 0 ? "no_new_usage" : "pending",
                docs == 0 ? "Local summaries are up to date." : $"{docs} daily summaries are ready to upload.", docs, bytes),
            ReferenceTime: now);
    }

    public Task<SyncData> GetSyncAsync(CancellationToken ct = default) => WithStoreAsync(BuildSync, ct);

    public async Task<SyncStateConfig> GetSyncStateConfigAsync(CancellationToken ct = default)
    {
        var config = await ReadContentAsync<SyncStateConfig>("sync-states.json", ct);
        // Hàng đợi thật: số event theo nguồn trong các ngày chưa đẩy lên cloud.
        var queue = await WithStoreAsync(() =>
        {
            var dirty = _store.GetDirtyDaily();
            if (dirty.Count == 0) return Array.Empty<SyncQueueItem>();
            var dates = dirty.Select(d => DateOnly.Parse(d.Date)).ToList();
            var from = _engine.Now.AddDays(-(_engine.Today.DayNumber - dates.Min().DayNumber) - 1);
            var events = _store.GetEvents(from, _engine.Now.AddSeconds(1))
                .Where(e => dates.Contains(Core.Aggregation.DailyAggregator.LocalDate(e.OccurredAt, _engine.TimeZone)))
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

    public async Task<SyncResult> SyncNowAsync(CancellationToken ct = default)
    {
        await UpdatePricesAsync(ct); // chỉ tải khi giá đã cũ hơn ~1 ngày
        var snapshot = await WithStoreAsync(() => _engine.Run(ct), ct);
        LastSnapshot = snapshot;
        _lastScan = snapshot.Scan;
        _lastScanAt = _lastAnalysisAt = Now;
        _localSettings?.Record($"Analysis: {snapshot.Scan.NewEvents} new events, {snapshot.ChangedDaily.Count} daily summaries changed");

        if (Uploader is null)
        {
            var (docs, bytes) = await WithStoreAsync(PendingDocuments, ct);
            _history.Insert(0, new SyncHistoryData(Now, ThisComputer, snapshot.Scan.NewEvents, bytes, "Local only"));
            return new("not_paired",
                $"Analysis updated: {snapshot.Scan.NewEvents} new events, {docs} daily summaries ready. " +
                "Sign in with Google to upload them to your phone.",
                await GetSyncAsync(ct));
        }

        try
        {
            long sent = await Uploader(snapshot, ct);
            await WithStoreAsync(() => { foreach (var d in snapshot.ChangedDaily) _store.MarkDailySynced(d.Date); return 0; }, ct);
            _history.Insert(0, new SyncHistoryData(Now, ThisComputer, snapshot.Scan.NewEvents, sent, "Success"));
            var state = snapshot.Scan.NewEvents == 0 && snapshot.ChangedDaily.Count == 0 ? "no_new_usage" : "success";
            return new(state, state == "success" ? "Usage summaries uploaded." : "No new usage since the last sync.", await GetSyncAsync(ct));
        }
        catch (Exception ex) when (ex is HttpRequestException or IOException or TaskCanceledException)
        {
            _localSettings?.Record("Upload failed: " + ex.GetType().Name);
            _history.Insert(0, new SyncHistoryData(Now, ThisComputer, snapshot.Scan.NewEvents, 0, "Failed"));
            return new("failed", "Upload failed. Summaries stay queued on this computer and will be retried.", await GetSyncAsync(ct));
        }
    }

    public Task<SyncData> DisconnectAsync(CancellationToken ct = default) => GetSyncAsync(ct);

    // ───────────────────────── Ghép đôi ─────────────────────────
    // Đã chốt: không ghép đôi bằng mã; desktop và mobile đăng nhập cùng tài khoản Google.

    private const string PairingReplaced =
        "Pairing codes are not used. Sign in with the same Google account on desktop and mobile to connect them.";

    public Task<OverviewScenario[]> GetPairingScenariosAsync(CancellationToken ct = default) =>
        ReadContentAsync<OverviewScenario[]>("pairing-states.json", ct);

    public Task<PairingData> GetPairingInfoAsync(CancellationToken ct = default) =>
        Task.FromResult(new PairingData(Now.AddMinutes(10), 10, PairingReplaced,
            ["Usage metadata", "No prompt content", "Encrypted sync", "Revoke anytime"]));

    public Task<PairingData> StartPairingAsync(CancellationToken ct = default) => GetPairingInfoAsync(ct);

    public Task<PairingResult> PairDeviceAsync(string code, CancellationToken ct = default) =>
        Task.FromResult(new PairingResult("rejected", PairingReplaced));
}
