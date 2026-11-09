using System.Collections;
using System.Globalization;
using System.Reflection;
using System.Text.Json.Nodes;
using System.Text.Json.Serialization;

namespace UToken.Sync;

/// <summary>
/// Đổi object C# (DailyDoc, EfficiencyDoc…) sang định dạng "fields" của Firestore REST.
/// Dựa vào kiểu C# chứ không dựa vào JSON: double luôn là doubleValue (kể cả 1.0), long/int là integerValue,
/// để app Flutter đọc đúng kiểu. Tên trường lấy từ [JsonPropertyName]; bỏ qua [JsonIgnore].
/// </summary>
public static class FirestoreValues
{
    public static JsonObject Fields(object doc)
    {
        var map = Value(doc)["mapValue"]!.AsObject();
        return map["fields"]!.DeepClone().AsObject();
    }

    public static JsonObject Value(object? value) => value switch
    {
        null => new JsonObject { ["nullValue"] = null },
        string s => new JsonObject { ["stringValue"] = s },
        bool b => new JsonObject { ["booleanValue"] = b },
        int or long or short or byte or uint => new JsonObject { ["integerValue"] = Convert.ToInt64(value, CultureInfo.InvariantCulture).ToString(CultureInfo.InvariantCulture) },
        double d => Double(d),
        float f => Double(f),
        decimal m => Double((double)m),
        DateTimeOffset t => new JsonObject { ["timestampValue"] = t.UtcDateTime.ToString("yyyy-MM-dd'T'HH:mm:ss.fff'Z'", CultureInfo.InvariantCulture) },
        IDictionary dict => Map(dict.Keys.Cast<object>().Select(k => (Convert.ToString(k, CultureInfo.InvariantCulture)!, dict[k]))),
        IEnumerable list => new JsonObject
        {
            ["arrayValue"] = new JsonObject { ["values"] = new JsonArray(list.Cast<object?>().Select(v => (JsonNode)Value(v)).ToArray()) },
        },
        _ => Map(Properties(value)),
    };

    private static JsonObject Double(double d) =>
        double.IsFinite(d) ? new JsonObject { ["doubleValue"] = d } : new JsonObject { ["nullValue"] = null };

    private static JsonObject Map(IEnumerable<(string Key, object? Value)> entries)
    {
        var fields = new JsonObject();
        foreach (var (k, v) in entries) fields[k] = Value(v);
        return new JsonObject { ["mapValue"] = new JsonObject { ["fields"] = fields } };
    }

    private static IEnumerable<(string, object?)> Properties(object obj)
    {
        foreach (var p in obj.GetType().GetProperties(BindingFlags.Public | BindingFlags.Instance))
        {
            if (p.GetIndexParameters().Length > 0 || p.GetCustomAttribute<JsonIgnoreAttribute>() is not null) continue;
            var name = p.GetCustomAttribute<JsonPropertyNameAttribute>()?.Name;
            if (name is null) continue; // chỉ đẩy trường có trong hợp đồng (có tên JSON tường minh)
            yield return (name, p.GetValue(obj));
        }
    }
}
