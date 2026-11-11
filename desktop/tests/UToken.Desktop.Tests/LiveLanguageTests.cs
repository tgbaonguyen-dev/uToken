using Avalonia.Controls;
using Avalonia.Headless.XUnit;
using Avalonia.Threading;
using Avalonia.VisualTree;
using UToken.Desktop.App.Localization;
using UToken.Desktop.App.ViewModels;
using UToken.Desktop.App.Views;
using Xunit;

namespace UToken.Desktop.Tests;

/// <summary>Đổi ngôn ngữ là trạng thái tĩnh của cả tiến trình: chạy riêng, không song song với test khác.</summary>
[CollectionDefinition(Name, DisableParallelization = true)]
public sealed class LanguageCollection
{
    public const string Name = "Language switching";
}

/// <summary>Settings → Language áp dụng ngay cho cửa sổ đang mở, không cần mở lại app.</summary>
[Collection(LanguageCollection.Name)]
public sealed class LiveLanguageTests : IDisposable
{
    private readonly RealHome _home = new();
    private readonly JudgeSyncTests.FakeJudge _judge = new();
    private readonly string _languageFile = Loc.LanguageFile;

    public LiveLanguageTests() => Loc.LanguageFile = Path.Combine(_home.DataDirectory, "language.txt");

    private (App.Services.RealDesktopApi Api, MainViewModel Vm) Open()
    {
        var api = _home.Api(judgeDirectory: _home.DataDirectory,
            judgeFactory: (provider, model, key) => _judge.For(provider, model, key));
        return (api, new MainViewModel(api));
    }

    private static TextBlock Text(Window window, string text) =>
        window.GetVisualDescendants().OfType<TextBlock>().First(t => t.Text == text && t.IsEffectivelyVisible);

    [AvaloniaFact]
    public async Task Switching_language_retranslates_the_open_window_and_keeps_the_page()
    {
        var (api, vm) = Open();
        using var _ = api;
        var window = new MainWindow { DataContext = vm };
        window.Show();
        try
        {
            await TestApp.WaitIdle(vm);
            await vm.ShowSettingsCommand.ExecuteAsync(null);
            window.UpdateLayout();
            vm.JudgeModel = "my-unsaved-model"; // chỉnh dở chưa lưu
            var label = Text(window, "Language"); // {l:T}
            var keyState = Text(window, "No key saved for this provider."); // binding qua Tr.Converter
            var sync = window.GetVisualDescendants().OfType<Button>().First(b => b.Content as string == "Sync now");
            var refresh = window.GetVisualDescendants().OfType<Button>()
                .First(b => ToolTip.GetTip(b) as string == "Refresh this page (F5)");

            vm.UseVietnamese = true;
            Dispatcher.UIThread.RunJobs();

            Assert.Equal("vi", Loc.Language);
            Assert.Equal("vi", File.ReadAllText(Loc.LanguageFile));
            Assert.True(vm.UseVietnamese);
            Assert.Equal("Ngôn ngữ", label.Text);
            Assert.Equal("Chưa lưu key cho nhà cung cấp này.", keyState.Text);
            Assert.Equal("Đồng bộ ngay", sync.Content);
            Assert.Equal(Loc.T("Refresh this page (F5)", "vi"), ToolTip.GetTip(refresh));
            Assert.Equal(Loc.T("μToken — Desktop Companion", "vi"), window.Title);
            Assert.Equal("Đã chuyển giao diện sang tiếng Việt.", Text(window, "Đã chuyển giao diện sang tiếng Việt.").Text);
            Assert.DoesNotContain(window.GetVisualDescendants().OfType<TextBlock>(),
                t => t.Text?.Contains("Khởi động lại uToken", StringComparison.Ordinal) == true);
            // Trang và dữ liệu đang sửa giữ nguyên, view không bị dựng lại.
            Assert.Equal("settings", vm.Page);
            Assert.Equal("my-unsaved-model", vm.JudgeModel);
            Assert.Same(label, Text(window, "Ngôn ngữ"));

            // Trang khác vẫn dịch đúng; quay lại Settings rồi đổi về tiếng Anh.
            vm.ShowOverviewCommand.Execute(null);
            window.UpdateLayout();
            Assert.Contains(window.GetVisualDescendants().OfType<TextBlock>(), t => t.Text == "Tổng quan");
            await vm.ShowSettingsCommand.ExecuteAsync(null);
            vm.UseVietnamese = false;
            Dispatcher.UIThread.RunJobs();
            Assert.Equal("en", File.ReadAllText(Loc.LanguageFile));
            Assert.Equal("Language", label.Text);
            Assert.Equal("Sync now", sync.Content);
            Assert.Equal("μToken — Desktop Companion", window.Title);
            TestApp.Render(window, "real-settings-language-switched");
        }
        finally
        {
            window.Close();
            Loc.UseForTesting("en");
        }
    }

    [AvaloniaFact]
    public async Task Next_ai_review_uses_the_newly_selected_language()
    {
        _home.Clock.Now = DateTimeOffset.Parse("2026-11-06T16:00:00Z");
        _home.AddClaudeUsage(6, distinctSessions: true);
        var (api, vm) = Open();
        using var _ = api;
        try
        {
            await vm.ShowSettingsCommand.ExecuteAsync(null);
            vm.JudgeApiKey = "k";
            await vm.RunJudgeNowCommand.ExecuteAsync(null);
            Assert.Contains("concise English", _judge.LastSystemPrompt);

            vm.UseVietnamese = true;
            await vm.RunJudgeNowCommand.ExecuteAsync(null);
            Assert.Contains("concise Vietnamese", _judge.LastSystemPrompt);
        }
        finally { Loc.UseForTesting("en"); }
    }

    public void Dispose()
    {
        Loc.UseForTesting("en");
        Loc.LanguageFile = _languageFile;
        _home.Dispose();
    }
}
