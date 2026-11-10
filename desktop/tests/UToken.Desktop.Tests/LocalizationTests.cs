using UToken.Desktop.App.Localization;
using Xunit;

namespace UToken.Desktop.Tests;

public sealed class LocalizationTests
{
    [Fact]
    public void Exact_strings_and_dynamic_messages_are_translated()
    {
        Assert.Equal("Đồng bộ ngay", Loc.T("Sync now", "vi"));
        Assert.Equal("Đã tải lên 3 bản tóm tắt ngày và báo cáo hiệu suất.",
            Loc.T("Uploaded 3 daily summaries and the efficiency report.", "vi"));
        Assert.Equal("Đã đăng nhập với ana@example.com.", Loc.T("Signed in as ana@example.com.", "vi"));
    }

    [Fact]
    public void English_and_unknown_text_pass_through()
    {
        Assert.Equal("Sync now", Loc.T("Sync now", "en"));
        Assert.Equal("Something new", Loc.T("Something new", "vi"));
    }

    [Fact]
    public void Prompt_asks_for_the_selected_language()
    {
        Assert.Contains("concise Vietnamese", UToken.Insights.JudgePrompt.For("Vietnamese"));
        Assert.DoesNotContain("{LANGUAGE}", UToken.Insights.JudgePrompt.For("English"));
    }
}
