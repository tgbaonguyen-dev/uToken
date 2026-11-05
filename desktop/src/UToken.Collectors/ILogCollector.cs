using UToken.Core.Models;

namespace UToken.Collectors;

/// <summary>Vị trí đã đọc của một file log (bảng source_files).</summary>
public sealed record SourceFileState(string Path, long ReadOffset, bool Completed);

public interface ILogCollector
{
    Provider Provider { get; }

    /// <summary>Liệt kê file trong allowlist (SRS §7.3). Không được trả về file ngoài allowlist.</summary>
    IEnumerable<string> DiscoverFiles(string homeDirectory);

    /// <summary>Đọc phần mới của một file; trả về event và vị trí đọc mới.</summary>
    (IReadOnlyList<UsageEvent> Events, SourceFileState NewState) ReadNew(SourceFileState state);
}
