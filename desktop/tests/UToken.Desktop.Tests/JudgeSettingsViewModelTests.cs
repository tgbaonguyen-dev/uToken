using Avalonia.Controls;
using Avalonia.Headless.XUnit;
using Avalonia.Threading;
using Avalonia.VisualTree;
using UToken.Desktop.App.ViewModels;
using UToken.Desktop.App.Views;
using UToken.Insights;
using Xunit;

namespace UToken.Desktop.Tests;

/// <summary>Card Settings → AI review trên RealDesktopApi với model giả (không gọi mạng).</summary>
public sealed class JudgeSettingsViewModelTests : IDisposable
{
    private readonly RealHome _home = new();
    private readonly JudgeSyncTests.FakeJudge _judge = new();

    private RealDesktopApiScope Open()
    {
        var api = _home.Api(judgeDirectory: _home.DataDirectory,
            judgeFactory: (provider, model, key) => _judge.For(provider, model, key));
        return new(api, new MainViewModel(api));
    }

    [AvaloniaFact]
    public async Task Repeating_desktop_review_runs_the_30_day_review_again()
    {
        _home.Clock.Now = DateTimeOffset.Parse("2026-11-06T16:00:00Z");
        _home.AddClaudeUsage(6, distinctSessions: true);
        using var scope = Open();
        var vm = scope.Vm;
        await vm.ShowSettingsCommand.ExecuteAsync(null);
        vm.JudgeApiKey = "test-key";
        await vm.SaveSettingsCommand.ExecuteAsync(null);
        await vm.RunJudgeNowCommand.ExecuteAsync(null);
        Assert.False(vm.JudgeMessageIsError);
        var calls = _judge.Calls;
        await vm.RunJudgeNowCommand.ExecuteAsync(null);
        Assert.Contains("AI review score", vm.JudgeMessage);
        Assert.False(vm.JudgeMessageIsError);
        Assert.Equal(calls + 1, _judge.Calls);
    }

    [Fact]
    public async Task Defaults_to_gemini_without_key()
    {
        using var scope = Open();
        var vm = scope.Vm;
        await vm.ShowSettingsCommand.ExecuteAsync(null);
        Assert.Equal(JudgeProviders.Google, vm.SelectedJudgeProvider.Id);
        Assert.Equal("gemini-flash-latest", vm.JudgeModel);
        Assert.True(vm.JudgeEnabled);
        Assert.Contains("AI Studio", vm.JudgeKeyHint);
        Assert.Equal("No key saved for this provider.", vm.JudgeKeyState);
        Assert.Equal("Not run yet", vm.JudgeStatusLabel);
        Assert.All(vm.JudgeModelOptions, m => Assert.Equal(JudgeProviders.Google, m.Provider));
    }

    [Fact]
    public async Task Save_changes_also_saves_ai_review()
    {
        using var scope = Open();
        var vm = scope.Vm;
        await vm.ShowSettingsCommand.ExecuteAsync(null);
        vm.SelectedJudgeProvider = MainViewModel.JudgeProviderOptions.Single(o => o.Id == JudgeProviders.OpenAi);
        vm.JudgeApiKey = "sk-openai-secret";
        await vm.SaveSettingsCommand.ExecuteAsync(null);

        var saved = await scope.Api.GetJudgeSettingsAsync();
        Assert.Equal(JudgeProviders.OpenAi, saved.Settings.Provider);
        Assert.True(saved.HasKey);
        Assert.Equal(MainViewModel.SavedJudgeKeyMask, vm.JudgeApiKey); // key đã lưu hiện dạng ẩn, không phải key thật
        Assert.StartsWith("Settings saved.", vm.SettingsMessage);
    }

    [AvaloniaFact]
    public async Task Save_switches_provider_and_keeps_key_secret()
    {
        using var scope = Open();
        var vm = scope.Vm;
        await vm.ShowSettingsCommand.ExecuteAsync(null);
        vm.SelectedJudgeProvider = MainViewModel.JudgeProviderOptions
            .Single(o => o.Id == JudgeProviders.Anthropic);
        Assert.Equal("claude-sonnet-5-5", vm.JudgeModel); // model mặc định theo nhà cung cấp
        vm.JudgeModel = "my-custom-model"; // cho gõ tùy ý
        vm.JudgeApiKey = "sk-ant-secret";
        await vm.SaveJudgeCommand.ExecuteAsync(null);

        Assert.Equal(MainViewModel.SavedJudgeKeyMask, vm.JudgeApiKey); // ô key hiện key đã lưu dạng ẩn
        Assert.Equal("AI review settings saved.", vm.JudgeMessage);
        var saved = await scope.Api.GetJudgeSettingsAsync();
        Assert.Equal(JudgeProviders.Anthropic, saved.Settings.Provider);
        Assert.Equal("my-custom-model", saved.Settings.Model);
        Assert.True(saved.HasKey);
        Assert.Contains("key is saved", vm.JudgeKeyState);
        Assert.Contains("Price unknown", vm.JudgeModelCost);
        Assert.DoesNotContain("sk-ant-secret",
            File.ReadAllText(Path.Combine(_home.DataDirectory, "judge-state.json")));
    }

    [Fact]
    public async Task Saved_key_is_shown_masked_after_reopening_and_kept_on_save()
    {
        _home.AddClaudeUsage(6, distinctSessions: true);
        using (var first = Open())
        {
            await first.Vm.ShowSettingsCommand.ExecuteAsync(null);
            first.Vm.JudgeApiKey = "sk-real-secret";
            await first.Vm.SaveSettingsCommand.ExecuteAsync(null);
        }

        using var scope = Open(); // mở lại app: API và view-model mới trên cùng thư mục dữ liệu
        var vm = scope.Vm;
        await vm.ShowSettingsCommand.ExecuteAsync(null);
        Assert.Equal(MainViewModel.SavedJudgeKeyMask, vm.JudgeApiKey);
        Assert.True(vm.JudgeKeyIsMasked);
        Assert.Equal("A key is saved on this computer. Paste a new key to replace it.", vm.JudgeKeyState);

        // Lưu lại với ô còn nguyên dạng ẩn: chuỗi giả không được ghi đè key thật.
        await vm.SaveSettingsCommand.ExecuteAsync(null);
        await vm.SaveJudgeCommand.ExecuteAsync(null);
        await vm.TestJudgeConnectionCommand.ExecuteAsync(null);
        Assert.Equal("sk-real-secret", _judge.LastKey);
        await vm.RunJudgeNowCommand.ExecuteAsync(null);
        Assert.Equal("sk-real-secret", _judge.LastKey);
        Assert.Equal(MainViewModel.SavedJudgeKeyMask, vm.JudgeApiKey);
        Assert.DoesNotContain(MainViewModel.SavedJudgeKeyMask[0],
            File.ReadAllText(Path.Combine(_home.DataDirectory, "judge-state.json")));
    }

    [Fact]
    public async Task Typing_over_the_masked_key_replaces_it_and_clearing_keeps_it()
    {
        using var scope = Open();
        var vm = scope.Vm;
        await vm.ShowSettingsCommand.ExecuteAsync(null);
        vm.JudgeApiKey = "sk-old";
        await vm.SaveJudgeCommand.ExecuteAsync(null);
        Assert.True(vm.JudgeKeyIsMasked);

        // Gõ tiếp vào cuối ô đang hiện dấu chấm: chỉ giữ phần vừa gõ.
        vm.JudgeApiKey = MainViewModel.SavedJudgeKeyMask + "sk-new";
        Assert.Equal("sk-new", vm.JudgeApiKey);
        Assert.Equal("A key is saved on this computer. Save to replace it with the new key.", vm.JudgeKeyState);
        await vm.SaveJudgeCommand.ExecuteAsync(null);
        await vm.TestJudgeConnectionCommand.ExecuteAsync(null);
        Assert.Equal("sk-new", _judge.LastKey);

        // Xóa một dấu chấm = xóa hết ô; xóa trống rồi lưu thì giữ key đã lưu (như trước đây).
        vm.JudgeApiKey = MainViewModel.SavedJudgeKeyMask[1..];
        Assert.Equal("", vm.JudgeApiKey);
        Assert.Equal("A key is saved on this computer. Leave the field empty to keep it.", vm.JudgeKeyState);
        await vm.SaveJudgeCommand.ExecuteAsync(null);
        Assert.True((await scope.Api.GetJudgeSettingsAsync()).HasKey);
        Assert.Equal(MainViewModel.SavedJudgeKeyMask, vm.JudgeApiKey);
        await vm.TestJudgeConnectionCommand.ExecuteAsync(null);
        Assert.Equal("sk-new", _judge.LastKey);

        // Nhà cung cấp khác chưa có key: ô trống.
        vm.SelectedJudgeProvider = MainViewModel.JudgeProviderOptions.Single(o => o.Id == JudgeProviders.OpenAi);
        Assert.Equal("", vm.JudgeApiKey);
        Assert.Equal("No key saved for this provider.", vm.JudgeKeyState);
        vm.SelectedJudgeProvider = MainViewModel.JudgeProviderOptions.Single(o => o.Id == JudgeProviders.Google);
        Assert.True(vm.JudgeKeyIsMasked);
    }

    [Fact]
    public async Task Catalog_models_show_cost_per_review()
    {
        using (var store = new UToken.Storage.SqliteStore(_home.DatabasePath))
            store.SavePrices(
            [
                new("google", "gemini-flash-latest",
                    new UToken.Core.Pricing.PriceSchedule(new(0.5m, 0.05m, null, 3m), [])),
                new("anthropic", "claude-sonnet-5-5",
                    new UToken.Core.Pricing.PriceSchedule(new(3m, 0.3m, 3.75m, 15m), [])),
            ], "test", DateTimeOffset.Parse("2026-11-01T00:00:00Z"));
        using var scope = Open();
        var vm = scope.Vm;
        await vm.ShowSettingsCommand.ExecuteAsync(null);
        var gemini = Assert.Single(vm.JudgeModelOptions);
        Assert.Equal(0.009m, gemini.CostPerRunUsd); // 6k vào × $0.5/M + 2k ra × $3/M
        Assert.Same(gemini, vm.SelectedJudgeModelOption);
        Assert.Equal("≈ $0.0090 per review", vm.JudgeModelCost);

        vm.SelectedJudgeProvider = MainViewModel.JudgeProviderOptions
            .Single(o => o.Id == JudgeProviders.Anthropic);
        vm.SelectedJudgeModelOption = Assert.Single(vm.JudgeModelOptions);
        Assert.Equal("claude-sonnet-5-5", vm.JudgeModel);
        Assert.Equal("≈ $0.048 per review", vm.JudgeModelCost);
    }

    [Fact]
    public async Task Test_connection_reports_errors()
    {
        using var scope = Open();
        var vm = scope.Vm;
        await vm.ShowSettingsCommand.ExecuteAsync(null);
        await vm.TestJudgeConnectionCommand.ExecuteAsync(null);
        Assert.True(vm.JudgeMessageIsError);
        Assert.Contains("API key", vm.JudgeMessage);

        vm.JudgeApiKey = "k";
        await vm.TestJudgeConnectionCommand.ExecuteAsync(null);
        Assert.False(vm.JudgeMessageIsError);

        _judge.Error = "invalid_api_key";
        await vm.TestJudgeConnectionCommand.ExecuteAsync(null);
        Assert.True(vm.JudgeMessageIsError);
        Assert.Contains("rejected", vm.JudgeMessage);
    }

    [Fact]
    public async Task Run_now_shows_status_and_last_run()
    {
        using var scope = Open();
        var vm = scope.Vm;
        await vm.ShowSettingsCommand.ExecuteAsync(null);
        vm.JudgeApiKey = "k";
        await vm.RunJudgeNowCommand.ExecuteAsync(null);
        Assert.NotNull(scope.Api.GetJudgeState().LastRunAt);
        Assert.NotEqual("Not run yet", vm.JudgeStatusLabel);
        Assert.StartsWith("Last run", vm.JudgeLastRunLabel);
    }

    [AvaloniaFact]
    public async Task Card_renders_with_password_key_box()
    {
        using var scope = Open();
        var vm = scope.Vm;
        var window = new MainWindow { DataContext = vm };
        window.Show();
        try
        {
            await TestApp.WaitIdle(vm);
            await vm.ShowSettingsCommand.ExecuteAsync(null);
            // Trang Settings vừa hiện lần đầu: ép một lượt layout để template của nó được dựng.
            window.UpdateLayout();
            var keyBox = window.GetVisualDescendants().OfType<TextBox>().Single(t =>
                Avalonia.Automation.AutomationProperties.GetName(t) == "AI review API key");
            Assert.NotEqual('\0', keyBox.PasswordChar);
            Assert.Equal("", keyBox.Text);

            vm.JudgeApiKey = "sk-ui-secret";
            await vm.SaveJudgeCommand.ExecuteAsync(null);
            Assert.Equal(MainViewModel.SavedJudgeKeyMask, keyBox.Text); // có key: hiện các dấu chấm
            Assert.False(keyBox.RevealPassword);
            var reveal = window.GetVisualDescendants().OfType<Avalonia.Controls.Primitives.ToggleButton>().Single(t =>
                Avalonia.Automation.AutomationProperties.GetName(t) == "Show API key");
            Assert.False(reveal.IsEnabled); // key đã lưu không bao giờ hiện chữ thật

            keyBox.Text = MainViewModel.SavedJudgeKeyMask + "x"; // người dùng gõ thêm vào cuối
            Dispatcher.UIThread.RunJobs();
            Assert.Equal("x", vm.JudgeApiKey);
            Assert.Equal("x", keyBox.Text);
            Assert.True(reveal.IsEnabled);
            reveal.IsChecked = true;
            Assert.True(keyBox.RevealPassword);
            Assert.Contains(window.GetVisualDescendants().OfType<Button>(),
                b => b.Content as string == "Run AI review now");
            var modelBox = window.GetVisualDescendants().OfType<TextBox>().Single(t =>
                Avalonia.Automation.AutomationProperties.GetName(t) == "AI review model");
            Assert.Equal("gemini-flash-latest", modelBox.Text);
            keyBox.BringIntoView();
            TestApp.Render(window, "real-settings-ai-review");
        }
        finally { window.Close(); }
    }

    public void Dispose() => _home.Dispose();

    private sealed record RealDesktopApiScope(App.Services.RealDesktopApi Api, MainViewModel Vm)
        : IDisposable
    {
        public void Dispose() => Api.Dispose();
    }
}
