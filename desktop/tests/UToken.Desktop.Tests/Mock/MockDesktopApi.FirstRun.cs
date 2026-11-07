using UToken.Desktop.App.Models;
namespace UToken.Desktop.App.Services;

public sealed partial class MockDesktopApi
{
    private bool _setupComplete;
    public async Task<FirstRunData> GetFirstRunAsync(CancellationToken ct = default)
    {
        var data = await ReadAsync<FirstRunData>("first-run.json", ct);
        if (data.Steps.Length != 3) throw new InvalidDataException("Setup requires three steps.");
        return data;
    }
    public Task<bool> IsSetupCompleteAsync(CancellationToken ct = default)
    {
        ct.ThrowIfCancellationRequested();
        return Task.FromResult(_setupComplete || (localSettings is not null &&
            File.Exists(Path.Combine(localSettings.DirectoryPath, "setup-complete"))));
    }
    public async Task CompleteSetupAsync(CancellationToken ct = default)
    {
        if (localSettings is not null)
        {
            Directory.CreateDirectory(localSettings.DirectoryPath);
            await File.WriteAllTextAsync(Path.Combine(localSettings.DirectoryPath, "setup-complete"), "UI demo completed", ct);
            localSettings.Record("UI setup completed");
        }
        _setupComplete = true;
    }
}
