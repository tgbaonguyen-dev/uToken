namespace UToken.Desktop.App.Models;

public record SourceScanConfig(string Heading, string Description, string PrivacyNote, int StepDelayMs);
public record SourceScanItem(string Name, string Logo, string State)
{
    public string Label => State switch
    {
        "scanning" => "Scanning", "complete" => "Checked", "permission" => "Permission missing",
        "not-found" => "Not found", _ => "Waiting",
    };
    public string Color => State switch
    {
        "scanning" => "#4089EF", "complete" => "#2EC790", "permission" => "#FFAD38",
        "not-found" => "#F26039", _ => "#9096A1",
    };
}
public record SourceScanProgress(SourceScanConfig Config, int Completed, int Total, string CurrentSource,
    SourceScanItem[] Providers)
{
    public string CountLabel => $"{Completed} of {Total}";
    public double Percent => Total == 0 ? 0 : 100d * Completed / Total;
}
