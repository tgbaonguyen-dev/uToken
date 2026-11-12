using System.Text.RegularExpressions;
using UToken.Core.Models;

namespace UToken.Core.Pricing;

/// <summary>Chuyển tên model trong log sang (vendor, model id) của models.dev.</summary>
public static partial class ModelIdNormalizer
{
    /// <summary>
    /// Đoán hãng từ tiền tố tên model trước, rồi mới theo collector,
    /// vì Claude Code/Codex có thể gọi model hãng khác qua proxy (vd. 9router).
    /// </summary>
    public static string? VendorOf(Provider provider, string model)
    {
        var m = Clean(model);
        if (m.StartsWith("claude")) return "anthropic";
        if (m.StartsWith("gemini")) return "google";
        if (m.StartsWith("gpt") || m.StartsWith("codex") || OpenAiReasoning().IsMatch(m)) return "openai";
        return provider switch
        {
            Provider.ClaudeCode => "anthropic",
            Provider.Codex => "openai",
            Provider.Antigravity => "google",
            _ => null,
        };
    }

    /// <summary>Các id để tra, theo thứ tự ưu tiên: nguyên bản, rồi bỏ hậu tố ngày.</summary>
    public static IReadOnlyList<string> Candidates(string model)
    {
        var m = Clean(model);
        var undated = DateSuffix().Replace(m, "");
        return undated == m ? [m] : [m, undated];
    }

    /// <summary>Hạ chữ thường, bỏ tiền tố "vendor/" và hậu tố kiểu "[1m]".</summary>
    private static string Clean(string model)
    {
        var m = model.Trim().ToLowerInvariant();
        var slash = m.LastIndexOf('/');
        if (slash >= 0) m = m[(slash + 1)..];
        var bracket = m.IndexOf('[');
        if (bracket > 0) m = m[..bracket];
        return m;
    }

    [GeneratedRegex(@"[-@]\d{8}$")]
    private static partial Regex DateSuffix();

    [GeneratedRegex(@"^o\d")]
    private static partial Regex OpenAiReasoning();
}
