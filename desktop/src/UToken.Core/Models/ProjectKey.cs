using System.Security.Cryptography;
using System.Text;

namespace UToken.Core.Models;

/// <summary>project_key là mã băm của đường dẫn project (SRS §6.3). Tên hiển thị chỉ giữ trên máy.</summary>
public static class ProjectKey
{
    public static string? FromPath(string? path)
    {
        if (string.IsNullOrWhiteSpace(path)) return null;
        var normalized = path.Replace('\\', '/').TrimEnd('/');
        if (OperatingSystem.IsWindows()) normalized = normalized.ToLowerInvariant();
        var hash = SHA256.HashData(Encoding.UTF8.GetBytes(normalized));
        return Convert.ToHexStringLower(hash)[..12];
    }

    /// <summary>Tên thư mục cuối, dùng làm tên hiển thị trên máy.</summary>
    public static string DisplayName(string path)
    {
        var trimmed = path.Replace('\\', '/').TrimEnd('/');
        var i = trimmed.LastIndexOf('/');
        return i >= 0 ? trimmed[(i + 1)..] : trimmed;
    }
}
