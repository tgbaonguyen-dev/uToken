using System.Globalization;
using System.Reflection;
using System.Text.Json;
using System.Text.RegularExpressions;
using Avalonia.Data.Converters;
using Avalonia.Markup.Xaml;

namespace UToken.Desktop.App.Localization;

/// <summary>
/// UI language. English text is the key; Vietnamese comes from the embedded
/// vi.json. Keys may contain {name} holes, so dynamic messages such as
/// "Uploaded 3 daily summaries" are matched by pattern. The language is read
/// once at startup (language.txt in the data folder); changing it needs a restart.
/// </summary>
public static class Loc
{
    private static readonly Lazy<(Dictionary<string, string> Exact, List<(Regex Pattern, string[] Holes, string Target)> Templates)> Table =
        new(Load);

    public static string Language { get; private set; } = ReadLanguage();
    public static bool Vietnamese => Language == "vi";

    /// <summary>Name the AI review should write in.</summary>
    public static string AiLanguage => Vietnamese ? "Vietnamese" : "English";

    private static string LanguageFile => Path.Combine(AppSettings.DataDirectory, "language.txt");

    private static string ReadLanguage()
    {
        try { return File.Exists(LanguageFile) && File.ReadAllText(LanguageFile).Trim() == "vi" ? "vi" : "en"; }
        catch (IOException) { return "en"; }
        catch (UnauthorizedAccessException) { return "en"; }
    }

    /// <summary>Saves the choice; takes effect on next start.</summary>
    public static void Save(string language)
    {
        Directory.CreateDirectory(AppSettings.DataDirectory);
        File.WriteAllText(LanguageFile, language == "vi" ? "vi" : "en");
    }

    /// <summary>Tests and previews can switch language in-process.</summary>
    public static void UseForTesting(string language) => Language = language == "vi" ? "vi" : "en";

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

/// <summary>XAML: Text="{l:T 'Sync now'}".</summary>
public sealed class TExtension(string text) : MarkupExtension
{
    public string Text { get; } = text;
    public override object ProvideValue(IServiceProvider serviceProvider) => Loc.T(Text);
}

/// <summary>Translates bound strings: Text="{Binding Message, Converter={x:Static l:Tr.Converter}}".</summary>
public sealed class Tr : IValueConverter
{
    public static readonly Tr Converter = new();
    public object? Convert(object? value, Type targetType, object? parameter, CultureInfo culture) =>
        value is string s ? Loc.T(s) : value;
    public object? ConvertBack(object? value, Type targetType, object? parameter, CultureInfo culture) => value;
}
