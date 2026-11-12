using Avalonia.Controls;
using Avalonia.Layout;

namespace UToken.Desktop.App.Views;

public sealed class ConfigurationRecoveryWindow : Window
{
    public ConfigurationRecoveryWindow(Action retry)
    {
        Title = "uToken configuration";
        Width = 620; Height = 310;
        var retryButton = new Button { Name = "RetryConfiguration", Content = "Retry", HorizontalAlignment = HorizontalAlignment.Left };
        retryButton.Click += (_, _) => retry();
        Content = new StackPanel
        {
            Margin = new Avalonia.Thickness(28), Spacing = 16,
            Children =
            {
                new TextBlock { Text = "Configuration could not be loaded", FontSize = 22 },
                new TextBlock { Text = "Check appsettings.json, appsettings.Local.json and UTOKEN_ environment overrides. Fix invalid JSON or setting types, then retry. Your files have not been reset.", TextWrapping = Avalonia.Media.TextWrapping.Wrap },
                new TextBlock { Text = AppContext.BaseDirectory, TextWrapping = Avalonia.Media.TextWrapping.Wrap },
                retryButton,
            },
        };
    }
}
