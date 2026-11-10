using System.Runtime.CompilerServices;

namespace UToken.Desktop.Tests;

/// <summary>Tests assert English text regardless of the language picked on this machine.</summary>
internal static class EnglishCulture
{
    [ModuleInitializer]
    internal static void Init() => UToken.Desktop.App.Localization.Loc.UseForTesting("en");
}
