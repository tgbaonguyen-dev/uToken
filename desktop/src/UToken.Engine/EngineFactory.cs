using UToken.Collectors;
using UToken.Collectors.Antigravity;
using UToken.Collectors.ClaudeCode;
using UToken.Collectors.Codex;
using UToken.Storage;

namespace UToken.Engine;

public static class EngineFactory
{
    /// <summary>
    /// Tạo collector theo danh sách nguồn đang bật ("codex", "claude_code", "antigravity").
    /// Danh sách rỗng thì bật Codex và Claude Code.
    /// </summary>
    public static IReadOnlyList<ILogCollector> Collectors(IReadOnlyCollection<string> enabled, string? codexHome = null, string? claudeHome = null)
    {
        bool On(string name) => enabled.Count == 0 || enabled.Contains(name, StringComparer.OrdinalIgnoreCase);
        var list = new List<ILogCollector>();
        if (On("codex")) list.Add(new CodexCollector(codexHome));
        if (On("claude_code")) list.Add(new ClaudeCodeCollector(claudeHome));
        if (On("antigravity")) list.Add(new AntigravityCollector());
        return list;
    }

    /// <summary>Mở (hoặc tạo) SQLite tại <paramref name="dbPath"/> và dựng engine. Nhớ Dispose store khi tắt app.</summary>
    public static (UsageEngine Engine, SqliteStore Store) Create(
        string dbPath, IReadOnlyCollection<string> enabled, string? codexHome = null, string? claudeHome = null, TimeZoneInfo? tz = null)
    {
        Directory.CreateDirectory(Path.GetDirectoryName(Path.GetFullPath(dbPath))!);
        var store = new SqliteStore(dbPath);
        var home = Environment.GetFolderPath(Environment.SpecialFolder.UserProfile);
        return (new UsageEngine(store, Collectors(enabled, codexHome, claudeHome), home, tz), store);
    }
}
