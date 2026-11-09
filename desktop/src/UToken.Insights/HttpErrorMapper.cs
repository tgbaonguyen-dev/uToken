using System.Net;

namespace UToken.Insights;

/// <summary>Provider failure represented by the shared contract error code.</summary>
public sealed class JudgeModelException(string code) : Exception(code)
{
    public string Code { get; } = code;
}

/// <summary>Maps provider HTTP responses to the shared judge error codes.</summary>
public static class HttpErrorMapper
{
    public static string? Error(HttpStatusCode status, string body)
    {
        if (status is HttpStatusCode.Unauthorized or HttpStatusCode.Forbidden ||
            body.Contains("API_KEY_INVALID", StringComparison.OrdinalIgnoreCase))
            return "invalid_api_key";
        if ((int)status == 429) return "rate_limited";
        if ((int)status >= 500) return "provider_error";
        return status == HttpStatusCode.OK ? null : "provider_error";
    }
}
