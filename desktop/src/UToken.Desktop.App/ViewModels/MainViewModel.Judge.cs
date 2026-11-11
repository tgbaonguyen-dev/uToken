using CommunityToolkit.Mvvm.ComponentModel;
using CommunityToolkit.Mvvm.Input;
using UToken.Desktop.App.Models;
using UToken.Insights;

namespace UToken.Desktop.App.ViewModels;

/// <summary>Nhà cung cấp chọn được cho AI review.</summary>
public sealed record JudgeProviderOption(string Id, string Label, string KeyHint)
{
    public override string ToString() => Label;
}

/// <summary>Settings → AI review: nhà cung cấp, model, API key, thử kết nối, chạy ngay.</summary>
public partial class MainViewModel
{
    public static IReadOnlyList<JudgeProviderOption> JudgeProviderOptions { get; } =
    [
        new(JudgeProviders.Google, "Gemini · Antigravity",
            "Free Gemini API keys are available in Google AI Studio (aistudio.google.com)."),
        new(JudgeProviders.Anthropic, "Claude",
            "Create a key in the Anthropic Console. Each review is billed to that key."),
        new(JudgeProviders.OpenAi, "OpenAI · Codex",
            "Create a key in the OpenAI platform dashboard. Each review is billed to that key."),
    ];

    [ObservableProperty] private JudgeSettingsData? _judge;
    [ObservableProperty] private bool _judgeEnabled;
    [ObservableProperty] private string _judgeModel = "";
    [ObservableProperty, NotifyPropertyChangedFor(nameof(JudgeKeyState), nameof(JudgeKeyIsMasked))]
    private string _judgeApiKey = "";
    /// <summary>Hiện chữ trong ô key (nút Show key). Mặc định ẩn; tắt lại sau mỗi lần tải/lưu.</summary>
    [ObservableProperty] private bool _revealJudgeKey;
    [ObservableProperty, NotifyPropertyChangedFor(nameof(HasJudgeMessage))]
    private string? _judgeMessage;
    [ObservableProperty] private bool _judgeMessageIsError;

    [ObservableProperty]
    [NotifyPropertyChangedFor(nameof(JudgeModelOptions), nameof(JudgeKeyHint))]
    private JudgeProviderOption _selectedJudgeProvider = JudgeProviderOptions[0];

    public bool HasJudgeMessage => !string.IsNullOrEmpty(JudgeMessage);
    public string JudgeKeyHint => SelectedJudgeProvider.KeyHint;

    public IReadOnlyList<JudgeModelOption> JudgeModelOptions =>
        ModelsOf(SelectedJudgeProvider.Id).ToArray();

    /// <summary>Chọn từ danh sách gợi ý thì điền vào ô model; gõ tay thì bỏ chọn.</summary>
    public JudgeModelOption? SelectedJudgeModelOption
    {
        get => ModelsOf(SelectedJudgeProvider.Id).FirstOrDefault(m => m.Model == JudgeModel);
        set { if (value is not null) JudgeModel = value.Model; }
    }

    public string JudgeModelCost =>
        ModelsOf(SelectedJudgeProvider.Id).FirstOrDefault(m => m.Model == JudgeModel)?.CostLabel
        ?? "Price unknown: not in the models.dev catalog";

    /// <summary>
    /// Ô key khi đã lưu key: hiện chuỗi giả này (PasswordChar biến thành dấu chấm) để người dùng thấy
    /// là có key. Key thật không bao giờ được nạp lại vào giao diện; chuỗi giả không bao giờ được gửi đi hay lưu.
    /// </summary>
    public const string SavedJudgeKeyMask = "\u2022\u2022\u2022\u2022\u2022\u2022\u2022\u2022\u2022\u2022\u2022\u2022";

    /// <summary>Ô key đang hiện key đã lưu (dạng ẩn), chưa bị sửa.</summary>
    public bool JudgeKeyIsMasked => JudgeApiKey == SavedJudgeKeyMask;

    private bool HasSavedJudgeKey =>
        Judge is { HasKey: true } && Judge.Settings.Provider == SelectedJudgeProvider.Id;

    public string JudgeKeyState => Judge is null ? "" : (HasSavedJudgeKey, TypedJudgeKey() is not null) switch
    {
        (true, false) when JudgeKeyIsMasked => "A key is saved on this computer. Paste a new key to replace it.",
        (true, false) => "A key is saved on this computer. Leave the field empty to keep it.",
        (true, true) => "A key is saved on this computer. Save to replace it with the new key.",
        (false, true) => "The key is stored on this computer when you save.",
        _ => "No key saved for this provider.",
    };

    /// <summary>Key người dùng vừa nhập; null khi ô trống hoặc còn nguyên chuỗi giả (giữ key đã lưu).</summary>
    private string? TypedJudgeKey() =>
        string.IsNullOrWhiteSpace(JudgeApiKey) || JudgeApiKey.All(c => c == SavedJudgeKeyMask[0])
            ? null
            : JudgeApiKey;

    partial void OnJudgeApiKeyChanged(string? oldValue, string newValue)
    {
        // Gõ/dán vào ô đang hiện key giả: bỏ các dấu chấm giả, chỉ giữ phần người dùng nhập
        // (API key không chứa ký tự •). Xóa một dấu chấm cũng coi như xóa hết.
        if (oldValue == SavedJudgeKeyMask && newValue != SavedJudgeKeyMask && newValue.Contains(SavedJudgeKeyMask[0]))
            JudgeApiKey = newValue.Replace(SavedJudgeKeyMask[0].ToString(), "", StringComparison.Ordinal);
    }

    private string SavedJudgeKeyText() => HasSavedJudgeKey ? SavedJudgeKeyMask : "";

    public string JudgeStatusLabel => Judge switch
    {
        null or { LastRunAt: null } => "Not run yet",
        { LastStatus: "ok", LastInsights: { } doc } => $"Score {doc.Score}/100 · grade {doc.Grade}",
        { LastStatus: "insufficient_data" } => "Not enough usage yet (needs 5 chats)",
        { LastErrorCode: { } code } => "Last run failed: " + code.Replace('_', ' '),
        _ => "Last run failed",
    };

    public string JudgeLastRunLabel => Judge?.LastRunAt is { } at
        ? "Last run "
          + DisplayFormat.Relative(at, (timeProvider ?? TimeProvider.System).GetUtcNow())
        : "AI review runs after a successful sync, at most once per day.";

    public string? JudgeHeadline => Judge?.LastInsights?.Headline is { Length: > 0 } h ? h : null;

    private IEnumerable<JudgeModelOption> ModelsOf(string provider) =>
        Judge?.Models.Where(m => m.Provider == provider) ?? [];

    partial void OnJudgeModelChanged(string value)
    {
        OnPropertyChanged(nameof(JudgeModelCost));
        OnPropertyChanged(nameof(SelectedJudgeModelOption));
    }

    partial void OnSelectedJudgeProviderChanged(JudgeProviderOption value)
    {
        // Đổi nhà cung cấp: gợi ý model mặc định của nhà cung cấp đó.
        if (Judge is not null && Judge.Settings.Provider != value.Id)
            JudgeModel = JudgeDefaults.For(value.Id).Model;
        else if (Judge is not null)
            JudgeModel = Judge.Settings.Model;
        JudgeApiKey = SavedJudgeKeyText();
        RevealJudgeKey = false;
        OnPropertyChanged(nameof(JudgeModelCost));
        OnPropertyChanged(nameof(JudgeKeyState));
    }

    private void ApplyJudge(JudgeSettingsData data)
    {
        Judge = data;
        JudgeEnabled = data.Settings.Enabled;
        SelectedJudgeProvider = JudgeProviderOptions.First(o => o.Id == data.Settings.Provider);
        JudgeModel = data.Settings.Model;
        JudgeApiKey = SavedJudgeKeyText();
        RevealJudgeKey = false;
        foreach (var name in new[] { nameof(JudgeModelOptions), nameof(JudgeModelCost),
                     nameof(JudgeKeyState), nameof(JudgeStatusLabel), nameof(JudgeLastRunLabel),
                     nameof(JudgeHeadline) })
            OnPropertyChanged(name);
    }

    private JudgeProviderSettings CurrentJudgeSettings() =>
        (Judge?.Settings ?? JudgeDefaults.For(SelectedJudgeProvider.Id)) with
        {
            Provider = SelectedJudgeProvider.Id,
            Model = string.IsNullOrWhiteSpace(JudgeModel)
                ? JudgeDefaults.For(SelectedJudgeProvider.Id).Model
                : JudgeModel.Trim(),
            Enabled = JudgeEnabled,
        };

    private void ShowJudgeMessage(string message, bool error)
    {
        JudgeMessage = message;
        JudgeMessageIsError = error;
    }

    // Ô trống hoặc còn chuỗi giả → key null: giữ key đã lưu (không có thao tác xóa key từ giao diện).
    [RelayCommand] private Task SaveJudgeAsync() => RunAsync(async () =>
    {
        var key = TypedJudgeKey();
        ApplyJudge(await api.SaveJudgeSettingsAsync(CurrentJudgeSettings(), key));
        ShowJudgeMessage("AI review settings saved.", false);
    });

    [RelayCommand] private Task TestJudgeConnectionAsync() => RunAsync(async () =>
    {
        var settings = CurrentJudgeSettings();
        var result = await api.TestJudgeConnectionAsync(
            settings.Provider, settings.Model, TypedJudgeKey());
        ShowJudgeMessage(result.Message, result.State != "success");
    });

    [RelayCommand] private Task RunJudgeNowAsync() => RunAsync(async () =>
    {
        var key = TypedJudgeKey();
        await api.SaveJudgeSettingsAsync(CurrentJudgeSettings(), key);
        var result = await api.RunJudgeAsync(force: true);
        ApplyJudge(await api.GetJudgeSettingsAsync());
        ShowJudgeMessage(result.Message, result.State is not ("success" or "insufficient_data"));
    });
}
