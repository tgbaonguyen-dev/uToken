using UToken.Desktop.App.Services;
using Xunit;

namespace UToken.Desktop.Tests;

public sealed class ClickSoundTests
{
    [Fact]
    public void Tick_is_a_short_valid_pcm_wave()
    {
        var wav = ClickSound.BuildTick();
        Assert.Equal("RIFF"u8.ToArray(), wav[..4]);
        Assert.Equal("WAVE"u8.ToArray(), wav[8..12]);
        Assert.Equal(44_100, BitConverter.ToInt32(wav, 24));       // sample rate
        Assert.Equal((short)16, BitConverter.ToInt16(wav, 34));    // bit depth
        int dataBytes = BitConverter.ToInt32(wav, 40);
        Assert.Equal(wav.Length - 44, dataBytes);
        Assert.InRange(dataBytes / 2 / 44_100.0, 0.03, 0.06);     // ~40ms
        // Không quá to: biên độ đỉnh dưới 30% thang đo.
        var peak = Enumerable.Range(0, dataBytes / 2).Max(i => Math.Abs((int)BitConverter.ToInt16(wav, 44 + i * 2)));
        Assert.InRange(peak, 1000, short.MaxValue * 3 / 10);
    }

    [Fact]
    public void Disabled_by_default_so_tests_stay_silent() => Assert.False(ClickSound.Enabled);
}
