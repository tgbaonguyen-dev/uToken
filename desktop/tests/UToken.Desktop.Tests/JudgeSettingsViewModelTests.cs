using Avalonia.Controls;
using Avalonia.Headless.XUnit;
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

        Assert.Equal("", vm.JudgeApiKey); // ô key được xóa sau khi lưu
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
