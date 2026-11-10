using System.Diagnostics;
using System.Runtime.InteropServices;

namespace UToken.Desktop.App.Services;

/// <summary>
/// Tiếng "tick" ngắn khi bấm nút. Âm được sinh sẵn trong bộ nhớ (WAV 40ms, không cần file hay thư viện):
/// Windows phát qua winmm PlaySound (bất đồng bộ); Linux qua pw-play / paplay / aplay; macOS qua afplay.
/// Mặc định tắt; App bật khi chạy app thật (không phát trong test headless). Lỗi phát âm thanh bị bỏ qua.
/// </summary>
public static class ClickSound
{
    public static bool Enabled { get; set; }

    private static readonly byte[] Wave = BuildTick();
    private static GCHandle _pinned;
    private static string? _file;
    private static string? _player;
    private static string _playerArgs = "";
    private static bool _resolved;
    private static long _lastTicks;

    public static void Play()
    {
        if (!Enabled) return;
        long now = Stopwatch.GetTimestamp();
        if (Stopwatch.GetElapsedTime(Interlocked.Exchange(ref _lastTicks, now), now) < TimeSpan.FromMilliseconds(45)) return;
        try
        {
            if (OperatingSystem.IsWindows()) { PlayWindows(); return; }
            PlayExternal();
        }
        catch (Exception ex) when (ex is IOException or UnauthorizedAccessException or System.ComponentModel.Win32Exception or InvalidOperationException or DllNotFoundException or EntryPointNotFoundException) { }
    }

    // ── Windows ──
    private const uint SndAsync = 0x0001, SndNoDefault = 0x0002, SndMemory = 0x0004;

    [DllImport("winmm.dll", EntryPoint = "PlaySoundW")]
    private static extern bool PlaySound(IntPtr sound, IntPtr module, uint flags);

    private static void PlayWindows()
    {
        // SND_ASYNC + SND_MEMORY đọc buffer trong lúc phát nên phải ghim cố định.
        if (!_pinned.IsAllocated) _pinned = GCHandle.Alloc(Wave, GCHandleType.Pinned);
        PlaySound(_pinned.AddrOfPinnedObject(), IntPtr.Zero, SndAsync | SndMemory | SndNoDefault);
    }

    // ── Linux / macOS ──
    private static void PlayExternal()
    {
        if (!_resolved)
        {
            _resolved = true;
            (_player, _playerArgs) = OperatingSystem.IsMacOS() ? (Find("afplay"), "")
                : Find("pw-play") is { } pw ? (pw, "")
                : Find("paplay") is { } pa ? (pa, "")
                : (Find("aplay"), "-q ");
            if (_player is null) return;
            var dir = Environment.GetEnvironmentVariable("XDG_RUNTIME_DIR") is { Length: > 0 } run && Directory.Exists(run) ? run : Path.GetTempPath();
            _file = Path.Combine(dir, "utoken-click.wav");
            File.WriteAllBytes(_file, Wave);
        }
        if (_player is null || _file is null) return;
        using var _ = Process.Start(new ProcessStartInfo(_player, _playerArgs + "\"" + _file + "\"")
        {
            UseShellExecute = false, CreateNoWindow = true, // không chuyển hướng output: không ai đọc thì pipe có thể tắc
        });
    }

    private static string? Find(string name) =>
        (Environment.GetEnvironmentVariable("PATH") ?? "").Split(Path.PathSeparator)
            .Select(dir => Path.Combine(dir, name)).FirstOrDefault(File.Exists);

    /// <summary>WAV PCM 16-bit mono 44.1kHz: tiếng gõ nhẹ 40ms (sine 1.6kHz + 3.2kHz, tắt dần nhanh).</summary>
    public static byte[] BuildTick()
    {
        const int rate = 44_100;
        int samples = rate * 40 / 1000;
        var data = new byte[samples * 2];
        for (int i = 0; i < samples; i++)
        {
            double t = (double)i / rate;
            double envelope = Math.Exp(-t * 140) * Math.Min(1, i / 40.0); // tấn công 1ms, tắt ~10ms
            double v = envelope * (0.75 * Math.Sin(2 * Math.PI * 1600 * t) + 0.25 * Math.Sin(2 * Math.PI * 3200 * t));
            short s = (short)Math.Clamp(v * 0.22 * short.MaxValue, short.MinValue, short.MaxValue);
            data[i * 2] = (byte)s; data[i * 2 + 1] = (byte)(s >> 8);
        }
        using var ms = new MemoryStream();
        using var w = new BinaryWriter(ms);
        w.Write("RIFF"u8); w.Write(36 + data.Length); w.Write("WAVE"u8);
        w.Write("fmt "u8); w.Write(16); w.Write((short)1); w.Write((short)1); w.Write(rate); w.Write(rate * 2); w.Write((short)2); w.Write((short)16);
        w.Write("data"u8); w.Write(data.Length); w.Write(data);
        w.Flush();
        return ms.ToArray();
    }
}
