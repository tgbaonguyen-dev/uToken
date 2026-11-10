using UToken.Collectors.Antigravity;
using Xunit;

namespace UToken.Collectors.Tests;

public sealed class AntigravityDiscoveryTests : IDisposable
{
    private readonly string _home = Directory.CreateTempSubdirectory("utoken-ag-").FullName;

    private void Touch(string relative)
    {
        var path = Path.Combine(_home, relative);
        Directory.CreateDirectory(Path.GetDirectoryName(path)!);
        File.WriteAllBytes(path, []);
    }

    [Fact]
    public void Finds_cli_and_ide_conversations_but_not_index_or_wal_files()
    {
        Touch(".gemini/antigravity-cli/conversations/a.db");
        Touch(".gemini/antigravity-ide/conversations/b.db");
        Touch(".gemini/antigravity-ide/conversations/b.db-wal");
        Touch(".gemini/antigravity/conversation_summaries.db"); // chỉ mục, không phải hội thoại
        Directory.CreateDirectory(Path.Combine(_home, ".gemini/antigravity/conversations"));

        var files = new AntigravityCollector().DiscoverFiles(_home).Select(f => Path.GetFileName(f)!).Order().ToArray();

        Assert.Equal(["a.db", "b.db"], files);
    }

    public void Dispose() => Directory.Delete(_home, recursive: true);
}
