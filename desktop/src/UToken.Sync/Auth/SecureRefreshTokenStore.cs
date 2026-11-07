using System.Diagnostics;
using System.Security.Cryptography;
using System.Text;
using System.Text.Json;

namespace UToken.Sync.Auth;

/// <summary>DPAPI CurrentUser on Windows; Secret Service (libsecret's secret-tool) on Linux.</summary>
public sealed class SecureRefreshTokenStore(string dataDirectory, string sessionKey) : IRefreshTokenStore
{
    private string TokenPath => Path.Combine(dataDirectory, $"auth-{sessionKey}.dpapi");
    private static readonly byte[] Entropy = Encoding.UTF8.GetBytes("uToken.Firebase.RefreshToken.v1");

    public async Task<StoredSession?> LoadAsync(CancellationToken ct)
    {
        string? json;
        if (OperatingSystem.IsWindows())
        {
            if (!File.Exists(TokenPath)) return null;
            var bytes = await File.ReadAllBytesAsync(TokenPath, ct);
            try { json = Encoding.UTF8.GetString(ProtectedData.Unprotect(bytes, Entropy, DataProtectionScope.CurrentUser)); }
            catch (CryptographicException) { throw new AuthException("AUTH_STORAGE", "Không đọc được phiên đã lưu. Hãy đăng nhập lại."); }
        }
        else if (OperatingSystem.IsLinux()) json = await RunSecretToolAsync("lookup", null, ct);
        else throw Unsupported();
        if (string.IsNullOrWhiteSpace(json)) return null;
        try
        {
            var saved = JsonSerializer.Deserialize<StoredSession>(json);
            if (saved is null || string.IsNullOrWhiteSpace(saved.Uid) || string.IsNullOrWhiteSpace(saved.RefreshToken))
                throw new JsonException();
            return saved;
        }
        catch (JsonException) { throw new AuthException("AUTH_STORAGE", "Phiên đã lưu không hợp lệ. Hãy đăng nhập lại."); }
    }

    public async Task SaveAsync(StoredSession session, CancellationToken ct)
    {
        var json = JsonSerializer.Serialize(session);
        if (OperatingSystem.IsWindows())
        {
            Directory.CreateDirectory(dataDirectory);
            var bytes = ProtectedData.Protect(Encoding.UTF8.GetBytes(json), Entropy, DataProtectionScope.CurrentUser);
            var temporary = TokenPath + "." + Guid.NewGuid().ToString("N") + ".tmp";
            try
            {
                await File.WriteAllBytesAsync(temporary, bytes, ct);
                File.Move(temporary, TokenPath, overwrite: true);
            }
            finally { if (File.Exists(temporary)) File.Delete(temporary); }
        }
        else if (OperatingSystem.IsLinux()) await RunSecretToolAsync("store", json, ct);
        else throw Unsupported();
    }

    public async Task ClearAsync(CancellationToken ct)
    {
        ct.ThrowIfCancellationRequested();
        if (OperatingSystem.IsWindows()) File.Delete(TokenPath);
        else if (OperatingSystem.IsLinux()) await RunSecretToolAsync("clear", null, ct);
        else throw Unsupported();
    }

    private async Task<string> RunSecretToolAsync(string action, string? input, CancellationToken ct)
    {
        var start = new ProcessStartInfo("secret-tool")
        {
            UseShellExecute = false, RedirectStandardInput = true,
            RedirectStandardOutput = true, RedirectStandardError = true, CreateNoWindow = true,
        };
        start.ArgumentList.Add(action);
        if (action == "store") start.ArgumentList.Add("--label=uToken Firebase session");
        foreach (var value in new[] { "application", "utoken", "session", sessionKey }) start.ArgumentList.Add(value);
        using var process = new Process { StartInfo = start };
        try { process.Start(); }
        catch (System.ComponentModel.Win32Exception) { throw Unsupported(); }
        using var timeout = CancellationTokenSource.CreateLinkedTokenSource(ct);
        timeout.CancelAfter(TimeSpan.FromSeconds(30));
        using var registration = timeout.Token.Register(() => { try { process.Kill(); } catch (InvalidOperationException) { } });
        var output = process.StandardOutput.ReadToEndAsync(timeout.Token);
        var error = process.StandardError.ReadToEndAsync(timeout.Token);
        if (input is not null) await process.StandardInput.WriteLineAsync(input.AsMemory(), timeout.Token);
        process.StandardInput.Close();
        await process.WaitForExitAsync(timeout.Token);
        var result = await output;
        var stderr = await error;
        // secret-tool uses exit 1 with no diagnostic when lookup/clear finds no entry.
        if (process.ExitCode != 0 && !(process.ExitCode == 1 && action != "store" && string.IsNullOrWhiteSpace(stderr)))
            throw new AuthException("AUTH_STORAGE", "Không truy cập được kho khóa hệ thống. Hãy mở khóa keyring và thử lại.");
        return result.Trim();
    }

    private static AuthException Unsupported() => new("AUTH_STORAGE",
        "Cần kho khóa hệ thống: DPAPI trên Windows hoặc secret-tool/libsecret trên Linux (gói libsecret-tools).");
}
