using System.Security.Cryptography;
using System.Text;

namespace UToken.Insights;

/// <summary>Stores provider keys separately from ordinary settings.</summary>
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
        var temporary = _path + "." + Guid.NewGuid().ToString("N") + ".tmp";
        try
        {
            var options = new FileStreamOptions
            {
                Mode = FileMode.CreateNew,
                Access = FileAccess.Write,
                Share = FileShare.None,
                Options = FileOptions.WriteThrough,
            };
            if (!OperatingSystem.IsWindows())
            {
                options.UnixCreateMode = UnixFileMode.UserRead | UnixFileMode.UserWrite;
            }
            using (var stream = new FileStream(temporary, options))
            {
                stream.Write(protectedPayload);
                stream.Flush(true);
            }
            File.Move(temporary, _path, true);
        }
        finally
        {
            if (File.Exists(temporary)) File.Delete(temporary);
            CryptographicOperations.ZeroMemory(payload);
            if (!ReferenceEquals(protectedPayload, payload))
            {
                CryptographicOperations.ZeroMemory(protectedPayload);
            }
        }
    }

    public IReadOnlyDictionary<string, string> Load()
    {
        if (!File.Exists(_path)) return new Dictionary<string, string>(StringComparer.Ordinal);
        var bytes = File.ReadAllBytes(_path);
        var payload = OperatingSystem.IsWindows()
            ? ProtectedData.Unprotect(bytes, null, DataProtectionScope.CurrentUser)
            : bytes;
        try
        {
            return System.Text.Json.JsonSerializer.Deserialize<Dictionary<string, string>>(payload)
                ?? throw new InvalidDataException("Judge key file is empty.");
        }
        finally
        {
            CryptographicOperations.ZeroMemory(bytes);
            if (!ReferenceEquals(payload, bytes))
            {
                CryptographicOperations.ZeroMemory(payload);
            }
        }
    }
}
