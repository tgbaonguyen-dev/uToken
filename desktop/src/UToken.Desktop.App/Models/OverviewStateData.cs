namespace UToken.Desktop.App.Models;

public record OverviewScenario(string Id, string Name, string Title, string Subtitle, string Status,
    string Headline, string Description, string Accent, string Code, string PrimaryLabel, string PrimaryAction,
    string SecondaryLabel, string SecondaryAction, string CollectorState, bool EmptyUsage,
    HealthData[] Details, SetupStep[] Guide)
{
    public override string ToString() => Name;
}
public record OverviewPreview(OverviewScenario Scenario, OverviewData Data)
{
    public ActivityData[] RecentActivity => Data.Activity.Take(3).ToArray();
    public string LastCollected => Data.Activity.FirstOrDefault() is { } activity
        ? "Last collected: " + activity.TimeLabel : "No activity collected yet";
}
