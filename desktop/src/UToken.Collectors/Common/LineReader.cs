using System.Text;
using ZstdSharp;

namespace UToken.Collectors.Common;

/// <summary>Đọc từng dòng hoàn chỉnh theo luồng; không nạp cả file vào bộ nhớ.</summary>
public static class LineReader
{
    /// <summary>
    /// File thường: đọc từ <paramref name="offset"/> (byte), chỉ trả dòng đã kết thúc bằng '\n'.
    /// Trả về offset mới = byte ngay sau dòng hoàn chỉnh cuối cùng.
    /// </summary>
    public static IEnumerable<string> ReadCompleteLines(string path, long offset, Action<long> onNewOffset)
    {
        using var fs = new FileStream(path, FileMode.Open, FileAccess.Read, FileShare.ReadWrite | FileShare.Delete);
        fs.Seek(offset, SeekOrigin.Begin);
        var buffer = new byte[64 * 1024];
        var pending = new MemoryStream();
        long consumed = offset;
        int read;
        while ((read = fs.Read(buffer, 0, buffer.Length)) > 0)
        {
            int start = 0;
            for (int i = 0; i < read; i++)
            {
                if (buffer[i] != (byte)'\n') continue;
                pending.Write(buffer, start, i - start);
                consumed += pending.Length + 1;
                var line = Encoding.UTF8.GetString(pending.GetBuffer(), 0, (int)pending.Length);
                pending.SetLength(0);
                start = i + 1;
                onNewOffset(consumed);
                if (line.Length > 0) yield return line;
            }
            pending.Write(buffer, start, read - start);
        }
    }

    /// <summary>File .jsonl.zst (log cũ, không còn thay đổi): đọc một lần từ đầu.</summary>
    public static IEnumerable<string> ReadZstdLines(string path)
    {
        using var fs = File.OpenRead(path);
        using var zs = new DecompressionStream(fs);
        using var sr = new StreamReader(zs, Encoding.UTF8);
        string? line;
        while ((line = sr.ReadLine()) is not null)
            if (line.Length > 0) yield return line;
    }
}
