using System.ComponentModel;
using System.Globalization;
using System.Reflection;
using System.Text.Json;
using System.Text.RegularExpressions;
using Avalonia;
using Avalonia.Data;
using Avalonia.Data.Converters;
using Avalonia.LogicalTree;
using Avalonia.Markup.Xaml;
using Avalonia.VisualTree;

namespace UToken.Desktop.App.Localization;

/// <summary>
/// UI language. English text is the key; Vietnamese comes from the embedded
/// vi.json. Keys may contain {name} holes, so dynamic messages such as
/// "Uploaded 3 daily summaries" are matched by pattern. The language is read
/// at startup from language.txt in the data folder; <see cref="Use"/> switches it
/// while the app runs and <see cref="LanguageChanged"/> lets open windows re-translate.
/// </summary>
public static class Loc
{
    private static readonly Lazy<(Dictionary<string, string> Exact, List<(Regex Pattern, string[] Holes, string Target)> Templates)> Table =
        new(Load);

    /// <summary>language.txt in the data folder. Tests point it at a temporary folder.</summary>
    public static string LanguageFile { get; set; } = Path.Combine(AppSettings.DataDirectory, "language.txt");

    // Khai báo sau LanguageFile: khởi tạo tĩnh chạy theo thứ tự trong file.
    public static string Language { get; private set; } = ReadLanguage();
    public static bool Vietnamese => Language == "vi";

    /// <summary>Name the AI review should write in.</summary>
    public static string AiLanguage => Vietnamese ? "Vietnamese" : "English";

    /// <summary>Raised on the calling thread after <see cref="Use"/> changes the language.</summary>
    public static event Action? LanguageChanged;

    /// <summary>Observable source for {l:T} bindings: raises Language when it changes.</summary>
    public static LanguageSource Source { get; } = new();

    private static string ReadLanguage()
    {
        try { return File.Exists(LanguageFile) && File.ReadAllText(LanguageFile).Trim() == "vi" ? "vi" : "en"; }
        catch (IOException) { return "en"; }
        catch (UnauthorizedAccessException) { return "en"; }
    }

    /// <summary>Persists the choice for the next start (does not switch the running UI; see <see cref="Use"/>).</summary>
    public static void Save(string language)
    {
        Directory.CreateDirectory(Path.GetDirectoryName(LanguageFile)!);
        File.WriteAllText(LanguageFile, language == "vi" ? "vi" : "en");
    }

    /// <summary>Switches the running UI language: {l:T} texts update by binding, then listeners re-translate bound text.</summary>
    public static void Use(string language)
    {
        var next = language == "vi" ? "vi" : "en";
        if (next == Language) return;
        Language = next;
        Source.Changed();
        LanguageChanged?.Invoke();
    }

    /// <summary>Tests and previews can switch language in-process.</summary>
    public static void UseForTesting(string language) => Use(language);

    /// <summary>
    /// Đọc lại mọi binding chữ (string/object) trong cây của <paramref name="root"/> để converter
    /// <see cref="Tr"/> dịch lại theo ngôn ngữ mới. View được dựng sau đó tự dịch đúng nên không cần đi qua.
    /// </summary>
    public static void RefreshBindings(Visual root)
    {
        var seen = new HashSet<AvaloniaObject>();
        var pending = new Stack<AvaloniaObject>();
        pending.Push(root);
        while (pending.Count > 0)
        {
            var node = pending.Pop();
            if (!seen.Add(node)) continue;
            RefreshProperties(node);
            if (node is Visual visual)
                foreach (var child in visual.GetVisualChildren()) pending.Push(child);
            // Cây logic có thêm nội dung popup (ComboBox, ToolTip) không nằm trong cây hiển thị.
            if (node is ILogical logical)
                foreach (var child in logical.LogicalChildren)
                    if (child is AvaloniaObject o) pending.Push(o);
        }
    }

    private static void RefreshProperties(AvaloniaObject target)
    {
        var registry = AvaloniaPropertyRegistry.Instance;
        foreach (var property in registry.GetRegistered(target).Concat(registry.GetRegisteredAttached(target.GetType())))
        {
            if (property.PropertyType != typeof(string) && property.PropertyType != typeof(object)) continue;
            BindingOperations.GetBindingExpressionBase(target, property)?.UpdateTarget();
        }
    }

    public static string T(string? english) => T(english, Language);

    /// <summary>Translates into an explicit language (used by tests).</summary>
    public static string T(string? english, string language)
    {
        if (string.IsNullOrEmpty(english) || language != "vi") return english ?? "";
        var (exact, templates) = Table.Value;
        if (exact.TryGetValue(english, out var hit)) return hit;
        foreach (var (pattern, holes, target) in templates)
        {
            var m = pattern.Match(english);
            if (!m.Success) continue;
            var result = target;
            for (var i = 0; i < holes.Length; i++)
                result = result.Replace("{" + holes[i] + "}", m.Groups[i + 1].Value);
            return result;
        }
        return english;
    }

    private static (Dictionary<string, string>, List<(Regex, string[], string)>) Load()
    {
        var exact = new Dictionary<string, string>(StringComparer.Ordinal);
        var templates = new List<(Regex, string[], string)>();
        using var stream = Assembly.GetExecutingAssembly()
            .GetManifestResourceStream("UToken.Desktop.App.Localization.vi.json");
        if (stream is null) return (exact, templates);
        var map = JsonSerializer.Deserialize<Dictionary<string, string>>(stream) ?? [];
        var hole = new Regex(@"\{(\w+)\}");
        foreach (var (en, vi) in map)
        {
            if (!hole.IsMatch(en)) { exact[en] = vi; continue; }
            var holes = hole.Matches(en).Select(m => m.Groups[1].Value).ToArray();
            var pattern = "^" + hole.Replace(Regex.Escape(en).Replace(@"\{", "{"), "(.+?)") + "$";
            templates.Add((new Regex(pattern, RegexOptions.Singleline), holes, vi));
        }
        // Longest templates first so the most specific one wins.
        templates.Sort((a, b) => b.Item1.ToString().Length.CompareTo(a.Item1.ToString().Length));
        return (exact, templates);
    }
}

/// <summary>Raises PropertyChanged(Language) so {l:T} bindings re-translate when the language switches.</summary>
public sealed class LanguageSource : INotifyPropertyChanged
{
    public event PropertyChangedEventHandler? PropertyChanged;
    public string Language => Loc.Language;
    internal void Changed() => PropertyChanged?.Invoke(this, new PropertyChangedEventArgs(nameof(Language)));
}

/// <summary>XAML: Text="{l:T 'Sync now'}". A binding to <see cref="Loc.Source"/>, so the text follows language switches.</summary>
public sealed class TExtension(string text) : MarkupExtension
{
    private static readonly FuncValueConverter<string, string, string> Translate =
        new((language, english) => Loc.T(english, language ?? Loc.Language));

    public string Text { get; } = text;
    public override object ProvideValue(IServiceProvider serviceProvider) => new Binding(nameof(LanguageSource.Language))
    {
        Source = Loc.Source,
        Mode = BindingMode.OneWay,
        Converter = Translate,
        ConverterParameter = Text,
    };
}

/// <summary>Translates bound strings: Text="{Binding Message, Converter={x:Static l:Tr.Converter}}".</summary>
public sealed class Tr : IValueConverter
{
    public static readonly Tr Converter = new();
    public object? Convert(object? value, Type targetType, object? parameter, CultureInfo culture) =>
        value is string s ? Loc.T(s) : value;
    public object? ConvertBack(object? value, Type targetType, object? parameter, CultureInfo culture) => value;
}
