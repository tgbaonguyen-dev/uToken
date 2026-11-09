using System.Security.Cryptography;
using System.Text;

namespace UToken.Insights;

/// <summary>Stores provider keys separately from ordinary settings; values are never logged.</summary>
public sealed class ApiKeyStore(string directory)
{
    private readonly string _path = Path.Combine(Path.GetFullPath(directory), "judge-keys.bin");

    public void Save(IReadOnlyDictionary<string, string> keys)
    {
        Directory.CreateDirectory(Path.GetDirectoryName(_path)!);
        var payload = Encoding.UTF8.GetBytes(System.Text.Json.JsonSerializer.Serialize(keys));
        byte[] protectedPayload = OperatingSystem.IsWindows()
            ? ProtectedData.Protect(payload, null, DataProtectionScope.CurrentUser)
            : payload;
        try
        {
            File.WriteAllBytes(_path, protectedPayload);
            if (!OperatingSystem.IsWindows()) File.SetUnixFileMode(_path, UnixFileMode.UserRead | UnixFileMode.UserWrite);
        }
        finally { CryptographicOperations.ZeroMemory(payload); if (!ReferenceEquals(protectedPayload, payload)) CryptographicOperations.ZeroMemory(protectedPayload); }
    }

    public IReadOnlyDictionary<string, string> Load()
    {
        if (!File.Exists(_path)) return new Dictionary<string, string>(StringComparer.Ordinal);
        var bytes = File.ReadAllBytes(_path);
        var payload = OperatingSystem.IsWindows() ? ProtectedData.Unprotect(bytes, null, DataProtectionScope.CurrentUser) : bytes;
        try { return System.Text.Json.JsonSerializer.Deserialize<Dictionary<string, string>>(payload) ?? throw new InvalidDataException("Judge key file is empty."); }
        finally { CryptographicOperations.ZeroMemory(bytes); if (!ReferenceEquals(payload, bytes)) CryptographicOperations.ZeroMemory(payload); }
    }
}
