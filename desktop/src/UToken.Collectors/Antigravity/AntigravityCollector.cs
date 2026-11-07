using UToken.Core.Models;

namespace UToken.Collectors.Antigravity;

/// <summary>
/// Antigravity lưu SQLite + protobuf (SRS §10.4). Ngày 05/11 thư mục conversations/ rỗng → xem R-08, OQ-10.
/// Chưa triển khai cho đến khi spike OQ-10 có kết quả.
/// </summary>
public sealed class AntigravityCollector : ILogCollector
{
    public Provider Provider => Provider.Antigravity;
    public string ParserVersion => "antigravity-0";

    public IEnumerable<string> DiscoverFiles(string home)
    {
        foreach (var app in new[] { "antigravity", "antigravity-ide" })
        {
            var dir = Path.Combine(home, ".gemini", app, "conversations");
            if (!Directory.Exists(dir)) continue;
            foreach (var f in Directory.EnumerateFiles(dir, "*.db")) yield return f;
        }
    }

    public CollectResult ReadNew(SourceFileState state) => CollectResult.Empty(state); // TODO(OQ-10)
}
