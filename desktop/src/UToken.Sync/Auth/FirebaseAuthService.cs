using System.Net;
using System.Net.Http.Json;
using System.Text.Json;

namespace UToken.Sync.Auth;

/// <summary>Firebase end-user Auth REST. ID tokens stay in memory; only refresh credentials enter the OS vault.</summary>
public sealed class FirebaseAuthService(HttpClient http, FirebaseOptions options,
    IGoogleOAuthClient google, IRefreshTokenStore store, TimeProvider? timeProvider = null) : IAuthService
{
    private readonly SemaphoreSlim _gate = new(1, 1);
    private readonly TimeProvider _time = timeProvider ?? TimeProvider.System;
    private string? _idToken;
    private string? _refreshToken;
    private DateTimeOffset _expiresAt;
    public AuthUser? CurrentUser { get; private set; }
    public event EventHandler? UserChanged;
    private string ApiKey => Uri.EscapeDataString(string.IsNullOrWhiteSpace(options.ApiKey) && options.UseEmulator ? "emulator-key" : options.ApiKey);

    public async Task SignInWithGoogleAsync(CancellationToken ct = default)
    {
        await _gate.WaitAsync(ct);
        try
        {
            var googleIdToken = await google.GetIdTokenAsync(ct);
            using var encoded = new FormUrlEncodedContent(new Dictionary<string, string>
                { ["id_token"] = googleIdToken, ["providerId"] = "google.com" });
            using var response = await http.PostAsJsonAsync($"{options.IdentityToolkitBaseUrl}/accounts:signInWithIdp?key={ApiKey}", new
            {
                postBody = await encoded.ReadAsStringAsync(ct), requestUri = "http://localhost",
                returnSecureToken = true,
            }, ct);
            using var json = await ReadResponseAsync(response, ct);
            var root = json.RootElement;
            var user = new AuthUser(Required(root, "localId"), Optional(root, "email"), Optional(root, "displayName"));
            await SetSessionAsync(user, Required(root, "idToken"), Required(root, "refreshToken"), Lifetime(root, "expiresIn"), ct);
        }
        finally { _gate.Release(); }
    }

    public async Task RestoreSessionAsync(CancellationToken ct = default)
    {
        await _gate.WaitAsync(ct);
        try
        {
            var saved = await store.LoadAsync(ct);
            if (saved is not null)
                await RefreshAsync(new AuthUser(saved.Uid, saved.Email, saved.DisplayName), saved.RefreshToken, ct);
        }
        finally { _gate.Release(); }
    }

    public async Task<string> GetIdTokenAsync(CancellationToken ct = default)
    {
        await _gate.WaitAsync(ct);
        try
        {
            if (CurrentUser is null || _refreshToken is null)
                throw new AuthException("AUTH_INVALID", "Session expired. Vui lòng đăng nhập lại.");
            if (_idToken is null || _expiresAt <= _time.GetUtcNow().AddMinutes(1))
                await RefreshAsync(CurrentUser, _refreshToken, ct);
            return _idToken!;
        }
        finally { _gate.Release(); }
    }

    private async Task RefreshAsync(AuthUser user, string refreshToken, CancellationToken ct)
    {
        using var content = new FormUrlEncodedContent(new Dictionary<string, string>
            { ["grant_type"] = "refresh_token", ["refresh_token"] = refreshToken });
        try
        {
            using var response = await http.PostAsync($"{options.SecureTokenBaseUrl}/token?key={ApiKey}", content, ct);
            using var json = await ReadResponseAsync(response, ct);
            var root = json.RootElement;
            if (Required(root, "user_id") != user.Uid)
                throw new AuthException("AUTH_INVALID", "Session expired. Vui lòng đăng nhập lại.");
            await SetSessionAsync(user, Required(root, "id_token"), Required(root, "refresh_token"), Lifetime(root, "expires_in"), ct);
        }
        catch (AuthException ex) when (ex.IsSessionExpired)
        {
            ResetSession();
            await store.ClearAsync(CancellationToken.None);
            throw;
        }
    }

    private async Task SetSessionAsync(AuthUser user, string idToken, string refreshToken, int lifetime, CancellationToken ct)
    {
        await store.SaveAsync(new StoredSession
            { Uid = user.Uid, RefreshToken = refreshToken, Email = user.Email, DisplayName = user.DisplayName }, ct);
        _idToken = idToken;
        _refreshToken = refreshToken;
        _expiresAt = _time.GetUtcNow().AddSeconds(lifetime);
        CurrentUser = user;
        UserChanged?.Invoke(this, EventArgs.Empty);
    }

    public async Task SignOutAsync(CancellationToken ct = default)
    {
        await _gate.WaitAsync(ct);
        try
        {
            // Do not report successful sign-out until the persisted credential has been removed.
            await store.ClearAsync(ct);
            ResetSession();
        }
        finally { _gate.Release(); }
    }

    private void ResetSession()
    {
        _idToken = _refreshToken = null;
        _expiresAt = default;
        CurrentUser = null;
        UserChanged?.Invoke(this, EventArgs.Empty);
    }

    private static async Task<JsonDocument> ReadResponseAsync(HttpResponseMessage response, CancellationToken ct)
    {
        if ((int)response.StatusCode >= 500 || response.StatusCode == HttpStatusCode.TooManyRequests)
            throw new AuthException("AUTH_NETWORK", "Dịch vụ đăng nhập tạm thời không khả dụng. Hãy thử lại.");
        using var body = await response.Content.ReadAsStreamAsync(ct);
        JsonDocument json;
        try { json = await JsonDocument.ParseAsync(body, cancellationToken: ct); }
        catch (JsonException) { throw new AuthException("AUTH_RESPONSE", "Phản hồi đăng nhập không hợp lệ. Hãy thử lại."); }
        if (response.IsSuccessStatusCode) return json;
        using (json)
        {
            var code = json.RootElement.TryGetProperty("error", out var error) && error.ValueKind == JsonValueKind.Object
                ? Optional(error, "message") : null;
            code = code?.Split([' ', ':'], StringSplitOptions.RemoveEmptyEntries).FirstOrDefault();
            var invalid = code is "TOKEN_EXPIRED" or "INVALID_REFRESH_TOKEN" or "USER_DISABLED" or "USER_NOT_FOUND" or "INVALID_IDP_RESPONSE" or "INVALID_ID_TOKEN";
            throw new AuthException(invalid ? "AUTH_INVALID" : "AUTH_CONFIG", invalid
                ? "Session expired. Vui lòng đăng nhập lại."
                : "Không đăng nhập được. Kiểm tra cấu hình Firebase, Google provider và OAuth client.");
        }
    }

    private static string Required(JsonElement root, string name) => Optional(root, name) is { Length: > 0 } value
        ? value : throw new AuthException("AUTH_RESPONSE", "Phản hồi đăng nhập thiếu thông tin cần thiết.");
    private static string? Optional(JsonElement root, string name) => root.TryGetProperty(name, out var value) && value.ValueKind == JsonValueKind.String ? value.GetString() : null;
    private static int Lifetime(JsonElement root, string name) => int.TryParse(Required(root, name), out var seconds) && seconds > 0
        ? seconds : throw new AuthException("AUTH_RESPONSE", "Thời hạn phiên đăng nhập không hợp lệ.");
}
