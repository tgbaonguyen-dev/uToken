using System.Net;
using System.Net.Http.Json;
using System.Text.Json;

namespace UToken.Sync.Auth;

/// <summary>Phiên đăng nhập Firebase. IdToken hết hạn sau khoảng 1 giờ; RefreshToken dùng để lấy token mới.</summary>
public sealed record FirebaseSession(string Uid, string Email, string? DisplayName, string IdToken, string RefreshToken, DateTimeOffset ExpiresAt);

/// <summary>Phiên đăng nhập không còn hợp lệ (refresh token bị thu hồi, tài khoản bị khóa, 401): cần đăng nhập lại.</summary>
public sealed class CloudAuthException(string message, Exception? inner = null) : Exception(message, inner);

/// <summary>Identity Toolkit REST: đổi Google ID token lấy Firebase ID token và làm mới token (ADR-0003).</summary>
public sealed class FirebaseAuthClient(HttpClient http, FirebaseOptions options, TimeProvider? clock = null)
{
    private readonly TimeProvider _clock = clock ?? TimeProvider.System;

    public async Task<FirebaseSession> SignInWithGoogleIdTokenAsync(string googleIdToken, CancellationToken ct)
    {
        var url = $"{options.IdentityToolkitBaseUrl}/accounts:signInWithIdp?key={Uri.EscapeDataString(options.EffectiveApiKey)}";
        using var res = await http.PostAsJsonAsync(url, new
        {
            postBody = $"id_token={Uri.EscapeDataString(googleIdToken)}&providerId=google.com",
            requestUri = "http://localhost",
            returnIdpCredential = true,
            returnSecureToken = true,
        }, ct);
        var root = await ReadAsync(res, ct);
        return new FirebaseSession(
            Str(root, "localId"),
            Str(root, "email"),
            root.TryGetProperty("displayName", out var dn) ? dn.GetString() : null,
            Str(root, "idToken"),
            Str(root, "refreshToken"),
            _clock.GetUtcNow().AddSeconds(Seconds(root, "expiresIn")));
    }

    public async Task<FirebaseSession> RefreshAsync(FirebaseSession session, CancellationToken ct)
    {
        var url = $"{options.SecureTokenBaseUrl}/token?key={Uri.EscapeDataString(options.EffectiveApiKey)}";
        using var res = await http.PostAsync(url, new FormUrlEncodedContent(new Dictionary<string, string>
        {
            ["grant_type"] = "refresh_token",
            ["refresh_token"] = session.RefreshToken,
        }), ct);
        var root = await ReadAsync(res, ct);
        return session with
        {
            IdToken = Str(root, "id_token"),
            RefreshToken = Str(root, "refresh_token"),
            ExpiresAt = _clock.GetUtcNow().AddSeconds(Seconds(root, "expires_in")),
        };
    }

    private static async Task<JsonElement> ReadAsync(HttpResponseMessage res, CancellationToken ct)
    {
        var body = await res.Content.ReadAsStringAsync(ct);
        if (!res.IsSuccessStatusCode)
        {
            // 400 với TOKEN_EXPIRED, INVALID_REFRESH_TOKEN, USER_DISABLED… nghĩa là phải đăng nhập lại.
            string code = TryErrorCode(body) ?? res.StatusCode.ToString();
            if (res.StatusCode is HttpStatusCode.BadRequest or HttpStatusCode.Unauthorized or HttpStatusCode.Forbidden)
                throw new CloudAuthException($"Firebase sign-in rejected: {code}");
            throw new HttpRequestException($"Firebase auth request failed: {code}", null, res.StatusCode);
        }
        using var doc = JsonDocument.Parse(body);
        return doc.RootElement.Clone();
    }

    private static string? TryErrorCode(string body)
    {
        try
        {
            using var doc = JsonDocument.Parse(body);
            return doc.RootElement.TryGetProperty("error", out var e) && e.ValueKind == JsonValueKind.Object &&
                   e.TryGetProperty("message", out var m) ? m.GetString() : null;
        }
        catch (JsonException) { return null; }
    }

    private static string Str(JsonElement e, string name) =>
        e.TryGetProperty(name, out var v) && v.GetString() is { } s ? s : throw new InvalidDataException($"Thiếu trường {name} trong phản hồi Firebase.");

    private static double Seconds(JsonElement e, string name) =>
        e.TryGetProperty(name, out var v) && double.TryParse(v.ValueKind == JsonValueKind.String ? v.GetString() : v.GetRawText(),
            System.Globalization.CultureInfo.InvariantCulture, out var s) ? s : 3600;
}
