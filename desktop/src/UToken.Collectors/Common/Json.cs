using System.Text.Json;

namespace UToken.Collectors.Common;

/// <summary>Đọc trường JSON an toàn: thiếu trường hoặc sai kiểu thì trả mặc định, không ném lỗi.</summary>
internal static class Json
{
    public static string? Str(JsonElement e, string name) =>
        e.ValueKind == JsonValueKind.Object && e.TryGetProperty(name, out var v) && v.ValueKind == JsonValueKind.String
            ? v.GetString() : null;

    public static long? LongOrNull(JsonElement e, string name) =>
        e.ValueKind == JsonValueKind.Object && e.TryGetProperty(name, out var v) && v.ValueKind == JsonValueKind.Number && v.TryGetInt64(out var n)
            ? n : null;

    public static long Long(JsonElement e, string name) => LongOrNull(e, name) ?? 0;

    public static bool True(JsonElement e, string name) =>
        e.ValueKind == JsonValueKind.Object && e.TryGetProperty(name, out var v) && v.ValueKind == JsonValueKind.True;
}

/// <summary>Lưu/đọc ngữ cảnh parser vào cột source_files.ctx_json.</summary>
public static class ParserState
{
    private static readonly JsonSerializerOptions Options = new() { DefaultIgnoreCondition = System.Text.Json.Serialization.JsonIgnoreCondition.WhenWritingNull };

    public static T? Load<T>(string? json) where T : class
    {
        if (string.IsNullOrEmpty(json)) return null;
        try { return JsonSerializer.Deserialize<T>(json, Options); }
        catch (JsonException) { return null; }
    }

    public static string Save<T>(T ctx) => JsonSerializer.Serialize(ctx, Options);
}
