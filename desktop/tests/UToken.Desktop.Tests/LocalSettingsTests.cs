using System.Text.Json;
using UToken.Desktop.App.Models;
using UToken.Desktop.App.Services;
using Xunit;

namespace UToken.Desktop.Tests;

public sealed class LocalSettingsTests : IDisposable
{
    private readonly string _directory = Path.Combine(AppContext.BaseDirectory, "LocalSettings-" + Guid.NewGuid().ToString("N"));
    private MockDesktopApi CreateApi() => new(localSettings: new LocalSettingsStore(_directory));

    [Fact]
    public async Task Save_survives_new_service_and_reset_is_persisted_without_touching_mock_files()
    {
        var fixturePath = Path.Combine(AppContext.BaseDirectory, "MockData", "settings.json");
        var fixture = await File.ReadAllTextAsync(fixturePath);
        var api = CreateApi();
        var defaults = await api.GetSettingsAsync();
        Assert.True(defaults.IsPersistent);
        Assert.Equal(Path.GetFullPath(_directory), defaults.DataPath);
        Assert.Equal(typeof(MockDesktopApi).Assembly.GetName().Version!.Major.ToString(), defaults.AppVersion.Split('.')[0]);
        var changed = defaults.Values with { RetentionDays = 7, LaunchAtStartup = false, UsageNotifications = true };
        await api.SaveSettingsAsync(changed);
        Assert.Equal(changed, (await CreateApi().GetSettingsAsync()).Values);
        await CreateApi().ResetSettingsAsync();
        Assert.Equal(defaults.Values, (await CreateApi().GetSettingsAsync()).Values);
        Assert.Equal(fixture, await File.ReadAllTextAsync(fixturePath));
        Assert.Empty(Directory.GetFiles(_directory, "*.tmp"));
        var diagnostics = await CreateApi().GetDiagnosticsAsync();
        Assert.Contains("Runtime:", diagnostics);
        Assert.Contains("settings.json: OK", diagnostics);
        Assert.Contains("Local settings saved", diagnostics);
    }

    [Fact]
    public async Task Corrupt_settings_are_preserved_until_explicit_reset()
    {
        Directory.CreateDirectory(_directory);
        var path = Path.Combine(_directory, "settings.json");
        await File.WriteAllTextAsync(path, "{invalid");
        var api = CreateApi();
        await Assert.ThrowsAsync<JsonException>(() => api.GetSettingsAsync());
        Assert.Equal("{invalid", await File.ReadAllTextAsync(path));
        Assert.Contains("JsonException", await api.GetDiagnosticsAsync());
        var reset = await api.ResetSettingsAsync();
        Assert.Equal(reset.Values, (await CreateApi().GetSettingsAsync()).Values);
        await Assert.ThrowsAsync<InvalidDataException>(() =>
            api.SaveSettingsAsync(reset.Values with { RetentionDays = -1 }));
        Assert.Equal(reset.Values, (await CreateApi().GetSettingsAsync()).Values);
    }

    [Fact]
    public async Task Failed_write_does_not_replace_existing_configuration()
    {
        var api = CreateApi();
        var defaults = await api.GetSettingsAsync();
        await api.SaveSettingsAsync(defaults.Values);
        using var cancellation = new CancellationTokenSource();
        cancellation.Cancel();
        await Assert.ThrowsAnyAsync<OperationCanceledException>(() =>
            api.SaveSettingsAsync(defaults.Values with { RetentionDays = 7 }, cancellation.Token));
        Assert.Equal(defaults.Values, (await CreateApi().GetSettingsAsync()).Values);
    }

    public void Dispose()
    {
        if (!Directory.Exists(_directory)) return;
        foreach (var file in Directory.GetFiles(_directory)) File.Delete(file);
        Directory.Delete(_directory);
    }
}
