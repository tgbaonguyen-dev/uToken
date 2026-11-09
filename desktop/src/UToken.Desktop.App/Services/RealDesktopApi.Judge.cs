using System.Globalization;
using System.Text.Json;
using UToken.Core.Aggregation;
using UToken.Insights;

namespace UToken.Desktop.App.Services;

/// <summary>
/// Trạng thái AI review lưu trên máy: cấu hình, bản insights tốt gần nhất, lần chạy cuối.
/// </summary>
public sealed record JudgeState(
    JudgeProviderSettings Settings,
    InsightDoc? LastInsights,
    DateTimeOffset? LastRunAt,
    string? LastStatus,
    string? LastErrorCode);

/// <summary>Kết quả một lần chạy AI review hoặc thử kết nối.</summary>
public sealed record JudgeRunResult(string State, string Message, InsightDoc? Insights);

/// <summary>
/// AI review (LLM-as-a-judge). Chạy sau khi Sync đẩy dữ liệu thành công;
/// lỗi của judge không làm Sync thất bại. Chỉ gửi brief tổng hợp (số liệu, không có
/// nội dung prompt hay tên dự án) tới nhà cung cấp người dùng chọn.
/// </summary>
public sealed partial class RealDesktopApi
{
    private const int JudgePeriodDays = 30;
    private JudgeState? _judgeState;

    /// <summary>Thư mục lưu judge-state.json và judge-keys.bin. Null: tắt AI review.</summary>
    public string? JudgeDirectory { get; init; }

    /// <summary>Tạo adapter cho (provider, model, key). Test thay bằng model giả.</summary>
    public Func<string, string, string, IJudgeModel>? JudgeModelFactory { get; init; }

    /// <summary>HttpClient cho Gemini/OpenAI; mặc định dùng chung client của app.</summary>
    public HttpClient? JudgeHttpClient { get; init; }

    private static readonly JsonSerializerOptions JudgeJson = new() { WriteIndented = true };

    private string? JudgeStatePath =>
        JudgeDirectory is null ? null : Path.Combine(JudgeDirectory, "judge-state.json");

    private ApiKeyStore? JudgeKeys =>
        JudgeDirectory is null ? null : new ApiKeyStore(JudgeDirectory);

    public JudgeState GetJudgeState()
    {
        if (_judgeState is not null) return _judgeState;
        var fallback = new JudgeState(
            JudgeDefaults.For(JudgeProviders.Google), null, null, null, null);
        if (JudgeStatePath is not { } path || !File.Exists(path)) return _judgeState = fallback;
        try
        {
            return _judgeState = JsonSerializer.Deserialize<JudgeState>(File.ReadAllText(path))
                ?? fallback;
        }
        catch (Exception ex) when (ex is JsonException or IOException
            or UnauthorizedAccessException)
        {
            _localSettings?.Record("AI review state unreadable: " + ex.GetType().Name);
            return _judgeState = fallback;
        }
    }

    private void SaveJudgeState(JudgeState state)
    {
        _judgeState = state;
        if (JudgeStatePath is not { } path) return;
        Directory.CreateDirectory(Path.GetDirectoryName(path)!);
        var temporary = path + ".tmp";
        File.WriteAllText(temporary, JsonSerializer.Serialize(state, JudgeJson));
        File.Move(temporary, path, true);
    }

    public Task<JudgeState> SaveJudgeSettingsAsync(
        JudgeProviderSettings settings, string? apiKey, CancellationToken ct = default)
    {
        if (!JudgeProviders.All.Contains(settings.Provider))
            throw new ArgumentOutOfRangeException(
                nameof(settings), settings.Provider, "Unknown provider.");
        if (apiKey is not null && JudgeKeys is { } keys)
        {
            var all = new Dictionary<string, string>(keys.Load(), StringComparer.Ordinal);
            if (apiKey.Length == 0) all.Remove(settings.Provider);
            else all[settings.Provider] = apiKey.Trim();
            keys.Save(all);
        }
        var state = GetJudgeState() with { Settings = settings };
        SaveJudgeState(state);
        _localSettings?.Record($"AI review settings: {settings.Provider} · {settings.Model}");
        return Task.FromResult(state);
    }

    public bool HasJudgeKey(string provider) => JudgeKey(provider) is { Length: > 0 };

    private string? JudgeKey(string provider)
    {
        try { return JudgeKeys?.Load().GetValueOrDefault(provider); }
        catch (Exception ex) when (ex is IOException or UnauthorizedAccessException
            or JsonException or InvalidDataException
            or System.Security.Cryptography.CryptographicException)
        {
            _localSettings?.Record("AI review key unreadable: " + ex.GetType().Name);
            return null;
        }
    }

    private IJudgeModel CreateJudgeModel(string provider, string model, string key)
    {
        if (JudgeModelFactory is not null) return JudgeModelFactory(provider, model, key);
        var http = JudgeHttpClient ?? Http.Value;
        return provider switch
        {
            JudgeProviders.Google => new GeminiJudgeModel(http, key, model),
            JudgeProviders.OpenAi => new OpenAiJudgeModel(http, key, model),
            JudgeProviders.Anthropic => new AnthropicJudgeModel(key, model),
            _ => throw new ArgumentOutOfRangeException(
                nameof(provider), provider, "Unknown provider."),
        };
    }

    /// <summary>
    /// Gửi một brief nhỏ để kiểm tra key và model. State: success, missing_key, mã lỗi.
    /// </summary>
    public async Task<JudgeRunResult> TestJudgeConnectionAsync(
        string provider, string model, string? key, CancellationToken ct = default)
    {
        key = string.IsNullOrWhiteSpace(key) ? JudgeKey(provider) : key.Trim();
        if (string.IsNullOrEmpty(key))
            return new("missing_key", "Enter an API key first.", null);
        var probe = new JudgeBrief("2026-01-01", "2026-01-30", "probe",
            new Dictionary<string, MetricEntry> { ["usage.chats"] = new("Chats", "10", 10) },
            10, true);
        var judge = CreateJudgeModel(provider, model, key);
        var result = await new JudgeService().RunAsync(probe, judge, ct);
        _localSettings?.Record(
            $"AI review connection test: {provider} · {model} → {result.Status}");
        return result.Status == "ok"
            ? new("success", $"Connected to {provider} · {model}.", null)
            : new(result.ErrorCode ?? "provider_error", JudgeErrorMessage(result.ErrorCode), null);
    }

    /// <summary>
    /// Chạy AI review. <paramref name="force"/>: bỏ qua MinHoursBetweenRuns và Enabled.
    /// </summary>
    public async Task<JudgeRunResult> RunJudgeAsync(bool force, CancellationToken ct = default)
    {
        var state = GetJudgeState();
        var settings = state.Settings;
        if (!force && !settings.Enabled)
            return new("disabled", "AI review is turned off.", state.LastInsights);
        if (!force && state.LastRunAt is { } last
            && Now - last < TimeSpan.FromHours(settings.MinHoursBetweenRuns))
            return new("not_due", "AI review already ran recently.", state.LastInsights);
        var key = JudgeKey(settings.Provider);
        if (string.IsNullOrEmpty(key))
            return new("missing_key", "Add an API key in Settings → AI review.",
                state.LastInsights);

        InsightDoc result;
        try
        {
            var brief = await WithStoreAsync(BuildJudgeBrief, ct);
            var model = CreateJudgeModel(settings.Provider, settings.Model, key);
            result = await new JudgeService().RunAsync(brief, model, ct);
        }
        catch (Exception ex) when (
            ex is not OperationCanceledException || !ct.IsCancellationRequested)
        {
            _localSettings?.Record("AI review failed: " + ex.GetType().Name);
            result = FailedFrom(state.LastInsights, settings, "provider_error");
        }

        var good = result.Status == "failed" ? state.LastInsights : result;
        var toUpload = result.Status == "failed"
            ? FailedFrom(state.LastInsights, settings, result.ErrorCode ?? "provider_error")
            : result;
        SaveJudgeState(state with
        {
            LastInsights = good,
            LastRunAt = Now,
            LastStatus = result.Status,
            LastErrorCode = result.ErrorCode,
        });
        _localSettings?.Record($"AI review: {result.Status}" +
            (result.ErrorCode is null ? "" : " (" + result.ErrorCode + ")"));

        if (_cloud is not null && await AccountAsync(ct) is not null)
        {
            try { _bytesSent += await _cloud.UploadInsightsAsync(toUpload, ct); }
            catch (Exception ex) when (ex is HttpRequestException
                or UToken.Sync.Auth.CloudAuthException
                or TaskCanceledException { InnerException: TimeoutException })
            {
                _localSettings?.Record("AI review upload failed: " + ex.GetType().Name);
            }
        }
        return result.Status switch
        {
            "ok" => new("success", $"AI review score {result.Score}/100 ({result.Grade}).", result),
            "insufficient_data" => new("insufficient_data",
                "Not enough usage yet: AI review needs at least 5 chats.", result),
            _ => new(result.ErrorCode ?? "provider_error",
                JudgeErrorMessage(result.ErrorCode), toUpload),
        };
    }

    /// <summary>Gọi sau khi upload thành công: mọi lỗi của judge chỉ ghi log.</summary>
    private async Task RunJudgeAfterSyncAsync(CancellationToken ct)
    {
        if (JudgeDirectory is null) return;
        try { await RunJudgeAsync(force: false, ct); }
        catch (Exception ex) when (
            ex is not OperationCanceledException || !ct.IsCancellationRequested)
        {
            _localSettings?.Record("AI review after sync failed: " + ex.GetType().Name);
        }
    }

    private JudgeBrief BuildJudgeBrief()
    {
        // Chưa phân tích lần nào (chạy tay trước Sync): tính daily/efficiency trước.
        LastSnapshot ??= _engine.Run();
        var from = _engine.Today.AddDays(-(JudgePeriodDays - 1))
            .ToString("yyyy-MM-dd", CultureInfo.InvariantCulture);
        var daily = _store.GetDailyJsonSince(from)
            .Select(json => JsonSerializer.Deserialize<DailyDoc>(json)!)
            .ToList();
        return JudgeBriefBuilder.Build(LastSnapshot.Efficiency, daily);
    }

    /// <summary>
    /// Bản failed: giữ điểm và insights cũ (nếu có) để mobile vẫn hiển thị kết quả trước.
    /// </summary>
    private InsightDoc FailedFrom(InsightDoc? previous, JudgeProviderSettings settings, string code)
    {
        var at = Now.UtcDateTime.ToString("yyyy-MM-dd'T'HH:mm:ss'Z'", CultureInfo.InvariantCulture);
        if (previous is not null)
            return previous with { Status = "failed", ErrorCode = code, GeneratedAt = at };
        var today = _engine.Today.ToString("yyyy-MM-dd", CultureInfo.InvariantCulture);
        return new("failed", at, today, today, settings.Provider, settings.Model,
            Prices.Version, null, null, "", [], [], code);
    }

    private static string JudgeErrorMessage(string? code) => code switch
    {
        "invalid_api_key" => "The API key was rejected. Check it in Settings → AI review.",
        "rate_limited" => "The provider is rate limiting requests. Try again later.",
        "refused" => "The model refused to review this summary. Try another model.",
        "truncated" => "The model reply was cut off. Try a model with a larger output limit.",
        _ => "The AI provider returned an error. Previous insights are kept.",
    };

    private void AppendJudgeDiagnostics(System.Text.StringBuilder report)
    {
        var state = GetJudgeState();
        var s = state.Settings;
        report.AppendLine($"AI review: {(s.Enabled ? "on" : "off")} · {s.Provider} · {s.Model} · " +
            $"key {(HasJudgeKey(s.Provider) ? "set" : "missing")} · last run " +
            (state.LastRunAt is { } at
                ? $"{at:u} ({state.LastStatus}{(state.LastErrorCode is { } c ? ", " + c : "")})"
                : "never"));
    }
}
