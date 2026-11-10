using Avalonia.Headless.XUnit;
using Avalonia.Svg.Skia;
using UToken.Desktop.App.Views;
using Xunit;
namespace UToken.Desktop.Tests;
/// <summary>Logo nguồn phải hiện được kể cả khi đã parse sẵn trên thread nền (lỗi cũ: cache null → mất logo).</summary>
public class SvgLogoTests
{
    [AvaloniaFact]
    public async Task Logo_converts_after_background_warmup_and_is_shared()
    {
        await SvgLogo.WarmAsync("codex", "claude", "antigravity");
        foreach (var id in new[] { "codex", "claude", "antigravity" })
        {
            var a = SvgLogo.Instance.Convert($"/Assets/{id}.svg", typeof(object), null, System.Globalization.CultureInfo.InvariantCulture);
            var b = SvgLogo.Instance.Convert($"/Assets/{id}.svg", typeof(object), null, System.Globalization.CultureInfo.InvariantCulture);
            Assert.IsType<SvgImage>(a);
            Assert.Same(a, b);
        }
        Assert.Null(SvgLogo.Instance.Convert("/Assets/missing.svg", typeof(object), null, System.Globalization.CultureInfo.InvariantCulture));
    }
}
