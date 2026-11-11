using Avalonia.Controls;
using Avalonia.Headless.XUnit;
using Avalonia.Interactivity;
using Avalonia.VisualTree;
using UToken.Desktop.App;
using UToken.Desktop.App.Views;
using Xunit;

namespace UToken.Desktop.Tests;

public class ConfigurationRecoveryTests
{
    [AvaloniaFact]
    public void Corrected_configuration_can_be_retried_without_resetting_files()
    {
        var folder = Directory.CreateTempSubdirectory("utoken-config-");
        try
        {
            File.WriteAllText(Path.Combine(folder.FullName, "appsettings.json"), "{}");
            var file = Path.Combine(folder.FullName, "appsettings.Local.json");
            File.WriteAllText(file, "{broken");
            Assert.Throws<InvalidDataException>(() => AppSettings.Load(folder.FullName));
            Assert.Equal("{broken", File.ReadAllText(file));
            File.WriteAllText(file, "{\"Sync\":{\"IntervalMinutes\":\"bad-value\"}}");
            Assert.Throws<InvalidOperationException>(() => AppSettings.Load(folder.FullName));
            AppSettings? restored = null;
            var window = new ConfigurationRecoveryWindow(() => restored = AppSettings.Load(folder.FullName));
            window.Show();
            try
            {
                const string valid = "{\"Sync\":{\"IntervalMinutes\":17}}";
                File.WriteAllText(file, valid);
                window.GetVisualDescendants().OfType<Button>().Single(b => b.Name == "RetryConfiguration")
                    .RaiseEvent(new RoutedEventArgs(Button.ClickEvent));
                Assert.Equal(17, restored!.Sync.IntervalMinutes);
                Assert.Equal(valid, File.ReadAllText(file));
            }
            finally { window.Close(); }
        }
        finally { folder.Delete(true); }
    }
}
