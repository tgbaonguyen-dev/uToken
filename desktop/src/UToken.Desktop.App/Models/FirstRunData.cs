namespace UToken.Desktop.App.Models;

public record SetupStep(string Number, string Title, string Description, string Action);
public record FirstRunData(string Title, string Subtitle, SetupStep[] Steps);
public record SetupRow(string Number, string Title, string Description, bool Completed)
{
    public string Color => Completed ? "#2EC790" : "#F26039";
    public string Status => Completed ? "Done (demo)" : "";
}
