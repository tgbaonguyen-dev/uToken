using UToken.Core.Models;

namespace UToken.Collectors;

/// <summary>
/// Vị trí đã đọc của một file log (bảng source_files). <see cref="ContextJson"/> giữ ngữ cảnh parser
/// (phiên, model, turn đang mở) để đọc tiếp từ offset mà không phải đọc lại từ đầu.
/// </summary>
public sealed record SourceFileState(string Path, long ReadOffset, bool Completed, string? ContextJson = null);

/// <summary>Kết quả một lần đọc phần mới của file.</summary>
public sealed record CollectResult(
    IReadOnlyList<UsageEvent> Events,
    IReadOnlyList<TurnRecord> Turns,
    IReadOnlyDictionary<string, string> Projects,
    int MalformedLines,
    SourceFileState NewState)
{
    public static CollectResult Empty(SourceFileState s) => new([], [], new Dictionary<string, string>(), 0, s);
}

public interface ILogCollector
{
    Provider Provider { get; }

    /// <summary>Đổi version thì file được đọc lại từ đầu.</summary>
    string ParserVersion { get; }

    /// <summary>Liệt kê file trong allowlist (SRS §7.3). Không được trả về file ngoài allowlist.</summary>
    IEnumerable<string> DiscoverFiles(string homeDirectory);

    /// <summary>Đọc phần mới của một file; trả về event, turn đã thay đổi và vị trí đọc mới.</summary>
    CollectResult ReadNew(SourceFileState state);
}
