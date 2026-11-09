using System.Text.Json;

namespace UToken.Insights;

/// <summary>Runs the common insufficient-data, parsing and validation pipeline.</summary>
public sealed class JudgeService
{
    /// <summary>Runs one judge model and creates a contract-valid document.</summary>
    public async Task<InsightDoc> RunAsync(
        JudgeBrief brief,
        IJudgeModel model,
        CancellationToken cancellationToken)
    {
        if (brief.Chats < 5 || !brief.HasEvents)
            return Empty(brief, model, "insufficient_data", null);
        try
        {
            var text = await model.CompleteAsync(
                JudgePrompt.System,
                JsonSerializer.Serialize(brief),
                ProviderSchema.Create(),
                cancellationToken);
            var output = JsonSerializer.Deserialize<JudgeModelOutput>(text)
                ?? throw new JsonException("The judge returned an empty JSON document.");
            return JudgeOutputMapper.Map(
                output,
                brief,
                model.Provider,
                model.Model,
                DateTimeOffset.UtcNow);
        }
        catch (JudgeModelException exception)
        {
            return Empty(brief, model, "failed", exception.Code);
        }
        catch (JsonException)
        {
            return Empty(brief, model, "failed", "provider_error");
        }
        catch (OperationCanceledException) when (!cancellationToken.IsCancellationRequested)
        {
            return Empty(brief, model, "failed", "provider_error");
        }
    }

    private static InsightDoc Empty(
        JudgeBrief brief,
        IJudgeModel model,
        string status,
        string? errorCode) => new(
            status,
            DateTimeOffset.UtcNow.ToString("yyyy-MM-dd'T'HH:mm:ss'Z'"),
            brief.PeriodStart,
            brief.PeriodEnd,
            model.Provider,
            model.Model,
            brief.PricingVersion,
            null,
            null,
            "",
            [],
            [],
            errorCode);
}
