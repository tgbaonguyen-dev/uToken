using Avalonia.Controls;
using Avalonia.Input;
using Avalonia.Interactivity;
namespace UToken.Desktop.App.Views;
public partial class DiagnosticsWindow : Window
{
    public DiagnosticsWindow(string report, string heading = "Collector diagnostics",
        string subtitle = "Application environment and recent log entries") : this()
    {
        DataContext = report; Title = heading; HeadingText.Text = heading; SubtitleText.Text = subtitle;
    }
    public DiagnosticsWindow()
    {
        InitializeComponent();
        KeyDown += (_, e) => { if (e.Key == Key.Escape) { Close(); e.Handled = true; } };
    }
    private void CloseClicked(object? sender, RoutedEventArgs e) => Close();
}
