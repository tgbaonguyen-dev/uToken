using System.Text;
using Avalonia;
using Avalonia.Controls;
using Avalonia.Interactivity;
using Avalonia.Media;
using Avalonia.Platform.Storage;

namespace UToken.Desktop.App.Views;

public partial class ReportActions : UserControl
{
    public static readonly StyledProperty<string?> ReportProperty = AvaloniaProperty.Register<ReportActions, string?>(nameof(Report));
    public string? Report { get => GetValue(ReportProperty); set => SetValue(ReportProperty, value); }
    public ReportActions() => InitializeComponent();
    protected override void OnPropertyChanged(AvaloniaPropertyChangedEventArgs change)
    {
        base.OnPropertyChanged(change);
        if (change.Property == ReportProperty && this.FindControl<TextBlock>("ReportActionStatus") is { } status) status.Text = "";
    }
    private void Status(string text, bool error = false) { ReportActionStatus.Text = text; ReportActionStatus.Foreground = Brush.Parse(error ? "#F04D57" : "#2EC790"); }
    private async void CopyClicked(object? sender, RoutedEventArgs e) => await CopyReportAsync();
    public async Task CopyReportAsync()
    {
        if (!IsEnabled || string.IsNullOrEmpty(Report)) return;
        if (TopLevel.GetTopLevel(this)?.Clipboard is not { } clipboard) { Status("Clipboard is unavailable.", true); return; }
        IsEnabled = false;
        try { await clipboard.SetTextAsync(Report); Status("Report copied."); }
        catch (Exception ex) when (IsTransferError(ex)) { Status("Could not copy the report. Please try again.", true); }
        finally { IsEnabled = true; }
    }
    private async void SaveClicked(object? sender, RoutedEventArgs e)
    {
        if (!IsEnabled || string.IsNullOrEmpty(Report) || TopLevel.GetTopLevel(this) is not { } top) return;
        var report = Report;
        IsEnabled = false;
        try
        {
            var file = await top.StorageProvider.SaveFilePickerAsync(new FilePickerSaveOptions
            {
                Title = "Save report", SuggestedFileName = "utoken-report.txt", DefaultExtension = "txt",
                FileTypeChoices = [new FilePickerFileType("Text report") { Patterns = ["*.txt"] }],
            });
            if (file is null) { Status("Save canceled."); return; }
            await using var stream = await file.OpenWriteAsync();
            await WriteReportAsync(stream, report);
            Status("Report saved.");
        }
        catch (Exception ex) when (IsTransferError(ex)) { Status("Could not save the report. Choose another location and try again.", true); }
        finally { IsEnabled = true; }
    }
    public static async Task WriteReportAsync(Stream stream, string report)
    {
        if (stream.CanSeek) { stream.Position = 0; stream.SetLength(0); }
        await using var writer = new StreamWriter(stream, new UTF8Encoding(true), leaveOpen: true);
        await writer.WriteAsync(report);
    }
    private static bool IsTransferError(Exception ex) => ex is IOException or UnauthorizedAccessException or NotSupportedException
        or InvalidOperationException or System.Runtime.InteropServices.COMException;
}
