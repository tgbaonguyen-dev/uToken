using System.Globalization;
using System.Text;
using UToken.Desktop.App.Models;

namespace UToken.Desktop.App.Services;

public sealed partial class MockDesktopApi
{
    private readonly TimeProvider _clock = timeProvider ?? TimeProvider.System;
    private SyncData? _sync;
    private PairingData? _pairing;
    private DateTimeOffset? _lastSuccessfulSync;

    public async Task<ActivityPageData> GetActivityAsync(ActivityQuery query, CancellationToken ct = default)
    {
        var page = await ReadAsync<ActivityPageData>("activity.json", ct);
        var cutoff = query.Period switch
        {
            "Last 24h" => page.ReferenceTime.AddDays(-1),
            "Last 7 days" => page.ReferenceTime.AddDays(-7),
            "All time" => DateTimeOffset.MinValue,
            _ => throw new InvalidDataException("Unknown activity period."),
        };
        var search = query.Search.Trim();
        return page with { Events = page.Events.Where(e =>
            e.OccurredAt >= cutoff && e.OccurredAt <= page.ReferenceTime &&
            (query.Provider == "All sources" || e.Provider == query.Provider) &&
            (query.Model == "All models" || e.Model == query.Model) &&
            (query.WarningsOnly ? e.Status != "OK" : e.Status == "OK") &&
            (search.Length == 0 || $"{e.Id} {e.Provider} {e.Model}".Contains(search, StringComparison.OrdinalIgnoreCase)))
            .OrderByDescending(e => e.OccurredAt).ToArray() };
    }

    public async Task<string> ExportActivityAsync(ActivityQuery query, CancellationToken ct = default)
    {
        var page = await GetActivityAsync(query, ct);
        var csv = new StringBuilder("Event ID,Timestamp,Source,Model,Input,Cached,Output,Total,Cost USD,Status\r\n");
        foreach (var e in page.Events)
        {
            string[] cells = [e.Id, e.OccurredAt.ToString("O"), e.Provider, e.Model,
                e.Input.ToString(CultureInfo.InvariantCulture), e.Cached.ToString(CultureInfo.InvariantCulture),
                e.Output.ToString(CultureInfo.InvariantCulture), e.TotalTokens.ToString(CultureInfo.InvariantCulture),
                e.Cost.ToString(CultureInfo.InvariantCulture), e.Status];
            csv.AppendLine(string.Join(",", cells.Select(CsvCell)));
        }
        return csv.ToString();
    }

    private static string CsvCell(string value)
    {
        if (value.TrimStart().StartsWith('=') || value.TrimStart().StartsWith('+') ||
            value.TrimStart().StartsWith('-') || value.TrimStart().StartsWith('@')) value = "'" + value;
        return "\"" + value.Replace("\"", "\"\"") + "\"";
    }

    public Task<SyncStateConfig> GetSyncStateConfigAsync(CancellationToken ct = default) => ReadAsync<SyncStateConfig>("sync-states.json", ct);

    public async Task<SyncData> GetSyncAsync(CancellationToken ct = default)
    {
        if (_sync is not null) return _sync;
        var data = await ReadAsync<SyncData>("sync.json", ct);
        return _sync = data with { Device = data.Device is null ? null : data.Device with { ReferenceTime = data.ReferenceTime } };
    }

    public async Task<SyncResult> SyncNowAsync(CancellationToken ct = default)
    {
        var current = await GetSyncAsync(ct);
        await Task.Delay(700, ct);
        if (current.Device is null) return new("not_paired", "Pair a mobile device before synchronizing.", current);
        if (!current.Device.IsOnline) return new("offline", "This device is paired but currently offline. Try again when it is online.", current);
        // Read the scenario on each action so demo outcomes can be changed without resetting the connection.
        var scenario = (await ReadAsync<SyncData>("sync.json", ct)).NextSync;
        if (scenario.State == "failed") return new("failed", scenario.Message, current);
        if (scenario.State == "no_new_usage") return new(scenario.State, scenario.Message, current);
        if (scenario.State != "success") throw new InvalidDataException("Unknown sync scenario.");
        if (scenario.Bytes < 0 || scenario.Events < 0) throw new InvalidDataException("Invalid sync counters.");
        var now = _clock.GetUtcNow();
        var row = new SyncHistoryData(now, current.Device.Name, scenario.Events, scenario.Bytes, "Success");
        _sync = current with
        {
            Device = current.Device with { LastSyncAt = now, ReferenceTime = now, TransferredBytes = checked(current.Device.TransferredBytes + scenario.Bytes) },
            ReferenceTime = now,
            History = new[] { row }.Concat(current.History).ToArray(),
        };
        _lastSuccessfulSync = now;
        return new("success", scenario.Message, _sync);
    }

    public async Task<SyncData> DisconnectAsync(CancellationToken ct = default)
    {
        var current = await GetSyncAsync(ct);
        await Task.Delay(300, ct);
        return _sync = current with { Device = null };
    }

    public Task<OverviewScenario[]> GetPairingScenariosAsync(CancellationToken ct = default) => ReadAsync<OverviewScenario[]>("pairing-states.json", ct);

    public async Task<PairingData> GetPairingInfoAsync(CancellationToken ct = default)
    {
        var config = await ReadAsync<PairingConfig>("pairing.json", ct);
        return new(_clock.GetUtcNow().AddMinutes(config.ExpiryMinutes), config.ExpiryMinutes,
            config.DemoHint, config.SecurityItems);
    }
    public async Task<PairingData> StartPairingAsync(CancellationToken ct = default) =>
        _pairing = await GetPairingInfoAsync(ct);

    public async Task<PairingResult> PairDeviceAsync(string code, CancellationToken ct = default)
    {
        if (code.Length != 6 || code.Any(c => c < '0' || c > '9'))
            return new("invalid", "Enter all six digits of the pairing code.");
        var config = await ReadAsync<PairingConfig>("pairing.json", ct);
        if (_pairing is null || _clock.GetUtcNow() >= _pairing.ExpiresAt || code == config.ExpiredCode)
            return new("expired", config.ExpiredMessage);
        if (code != config.ValidCode) return new("rejected", config.RejectedMessage);
        var current = await GetSyncAsync(ct);
        var now = _clock.GetUtcNow();
        _sync = current with { Device = config.Device with { ReferenceTime = now }, ReferenceTime = now };
        _pairing = null; // A successful code cannot be reused in the same session.
        return new("success", config.SuccessMessage, _sync);
    }
}
