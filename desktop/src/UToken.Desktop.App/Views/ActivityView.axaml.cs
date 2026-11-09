using System.Text;
using Avalonia.Controls;
using Avalonia.Interactivity;
using Avalonia.Platform.Storage;
using UToken.Desktop.App.ViewModels;

namespace UToken.Desktop.App.Views;

public partial class ActivityView : UserControl
{
    public ActivityView() => InitializeComponent();

    private async void ExportClicked(object? sender, RoutedEventArgs e)
    {
        if (DataContext is not MainViewModel vm || TopLevel.GetTopLevel(this) is not { } top) return;
        var csv = await vm.ExportActivityCsvAsync();
        if (csv is null) return;
        try
        {
            var file = await top.StorageProvider.SaveFilePickerAsync(new FilePickerSaveOptions
            {
                Title = "Export activity", SuggestedFileName = "utoken-activity.csv", DefaultExtension = "csv",
                FileTypeChoices = [new FilePickerFileType("CSV") { Patterns = ["*.csv"] }],
            });
            if (file is null) return;
            await using var stream = await file.OpenWriteAsync();
            if (stream.CanSeek) stream.SetLength(0);
            await using (var writer = new StreamWriter(stream, new UTF8Encoding(true))) await writer.WriteAsync(csv);
            vm.ReportExportResult(true);
        }
        catch (Exception ex) when (ex is IOException or UnauthorizedAccessException or NotSupportedException)
        { vm.ReportExportResult(false); }
    }
}
