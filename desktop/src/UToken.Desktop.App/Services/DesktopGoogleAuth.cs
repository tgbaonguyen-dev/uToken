using System.Diagnostics;
using System.Net;
using System.Net.Http.Json;
using System.Net.Sockets;
using System.Security.Cryptography;
using System.Text;
using System.Text.Json;

namespace UToken.Desktop.App.Services;

public sealed record DesktopFirebaseConfig(string ProjectId, string ApiKey, string OAuthClientId,
    string OAuthClientSecret = "", bool UseEmulator = false)
{
    public static DesktopFirebaseConfig? Load(string? file = null)
    {
        var path = file ?? Path.Combine(AppContext.BaseDirectory, "firebase.desktop.json");
        if (!File.Exists(path)) return null;
        var config = JsonSerializer.Deserialize<DesktopFirebaseConfig>(File.ReadAllText(path),
            new JsonSerializerOptions { PropertyNameCaseInsensitive = true });
        if (config is null || string.IsNullOrWhiteSpace(config.ProjectId) ||
            string.IsNullOrWhiteSpace(config.ApiKey) || string.IsNullOrWhiteSpace(config.OAuthClientId))
            throw new InvalidDataException("Complete firebase.desktop.json before using real pairing.");
        if (config.UseEmulator) throw new InvalidDataException("Real pairing requires UseEmulator: false.");
        return config;
    }
}

public sealed class FirebaseSessionExpiredException() : InvalidOperationException("AUTH_INVALID: Session expired. Sign in with Google again.");

public interface IFirebaseSession
{
    string? Uid { get; }
    Task<string> TokenAsync(CancellationToken ct);
    void InvalidateIdToken(string? token = null) { }
}

public sealed class DesktopGoogleAuth(DesktopFirebaseConfig config, HttpClient http, string? sessionFile = null) : IFirebaseSession
{
    private string? _idToken;
    private string? _refreshToken;
    private DateTimeOffset _expires;
    public string? Uid { get; private set; }
    public string Account { get; private set; } = "Not signed in";
    private readonly SemaphoreSlim _gate = new(1);
    private readonly object _sessionLock = new();
    private int _sessionGeneration;
    private readonly string _sessionFile = sessionFile ?? Path.Combine(LocalSettingsStore.DefaultDirectory, "firebase-session.bin");
    public void InvalidateIdToken(string? token = null) { lock (_sessionLock) { if (token is null || token == _idToken) { _idToken = null; _expires = default; } } }

    public async Task<string> TokenAsync(CancellationToken ct)
    {
        await _gate.WaitAsync(ct);
        try
        {
            string refresh;
            int generation;
            lock (_sessionLock) {
            if (_idToken is not null && _expires > DateTimeOffset.UtcNow.AddMinutes(2)) return _idToken;
            if (_refreshToken is null && File.Exists(_sessionFile))
            {
                try { _refreshToken = WindowsSecretStore.Read(_sessionFile); }
                catch (CryptographicException) { File.Delete(_sessionFile); }
            }
            if (_refreshToken is null) throw new InvalidOperationException("Sign in with Google before pairing.");
            refresh = _refreshToken;
            generation = _sessionGeneration;
            }
            using var response = await http.PostAsync($"https://securetoken.googleapis.com/v1/token?key={Uri.EscapeDataString(config.ApiKey)}",
                new FormUrlEncodedContent(new Dictionary<string, string> { ["grant_type"] = "refresh_token", ["refresh_token"] = refresh }), ct);
            lock (_sessionLock) {
            if (generation != _sessionGeneration) throw new InvalidOperationException("The sign-in session changed. Sign in again.");
            if (response.StatusCode is HttpStatusCode.BadRequest or HttpStatusCode.Unauthorized)
            { SignOut(); throw new FirebaseSessionExpiredException(); }
            }
            response.EnsureSuccessStatusCode();
            using var json = JsonDocument.Parse(await response.Content.ReadAsStringAsync(ct));
            var root = json.RootElement;
            lock (_sessionLock) {
            if (generation != _sessionGeneration) throw new InvalidOperationException("The sign-in session changed. Sign in again.");
            _idToken = root.GetProperty("id_token").GetString()!;
            _refreshToken = root.GetProperty("refresh_token").GetString()!;
            Uid = root.GetProperty("user_id").GetString()!;
            _expires = DateTimeOffset.UtcNow.AddSeconds(int.Parse(root.GetProperty("expires_in").GetString()!));
            WindowsSecretStore.Write(_sessionFile, _refreshToken);
            Account = DisplayEmail(_idToken) ?? "Google account connected";
            return _idToken;
            }
        }
        finally { _gate.Release(); }
    }

    public void SignOut()
    {
        lock (_sessionLock) {
        _sessionGeneration++;
        _idToken = _refreshToken = Uid = null; Account = "Not signed in";
        if (File.Exists(_sessionFile)) File.Delete(_sessionFile);
        }
    }

    public async Task SignInAsync(CancellationToken ct = default)
    {
        int generation;
        lock (_sessionLock) { generation = ++_sessionGeneration; }
        using var timeout = CancellationTokenSource.CreateLinkedTokenSource(ct);
        timeout.CancelAfter(TimeSpan.FromMinutes(3));
        ct = timeout.Token;
        var probe = new TcpListener(IPAddress.Loopback, 0);
        probe.Start(); var port = ((IPEndPoint)probe.LocalEndpoint).Port; probe.Stop();
        var redirect = $"http://127.0.0.1:{port}/";
        using var listener = new HttpListener(); listener.Prefixes.Add(redirect); listener.Start();
        var verifier = Base64(RandomNumberGenerator.GetBytes(32));
        var challenge = Base64(SHA256.HashData(Encoding.ASCII.GetBytes(verifier)));
        var state = Base64(RandomNumberGenerator.GetBytes(32));
        var query = new Dictionary<string, string> {
            ["client_id"] = config.OAuthClientId, ["redirect_uri"] = redirect, ["response_type"] = "code",
            ["scope"] = "openid email profile", ["state"] = state, ["code_challenge"] = challenge,
            ["code_challenge_method"] = "S256", ["prompt"] = "select_account" };
        Process.Start(new ProcessStartInfo("https://accounts.google.com/o/oauth2/v2/auth?" +
            string.Join("&", query.Select(p => $"{p.Key}={Uri.EscapeDataString(p.Value)}"))) { UseShellExecute = true });
        HttpListenerContext callback;
        while (true)
        {
            callback = await listener.GetContextAsync().WaitAsync(ct);
            if (callback.Request.Url?.AbsolutePath == "/" && callback.Request.QueryString["state"] == state) break;
            callback.Response.StatusCode = 400; callback.Response.Close();
        }
        var code = callback.Request.QueryString["code"];
        // The callback only confirms receipt; Firebase exchange can still fail.
        var page = Encoding.UTF8.GetBytes("<!doctype html><title>uToken</title><p>Return to uToken to check sign-in status.</p>");
        callback.Response.ContentType = "text/html; charset=utf-8";
        await callback.Response.OutputStream.WriteAsync(page, ct); callback.Response.Close();
        if (string.IsNullOrEmpty(code)) throw new InvalidOperationException("Google sign-in was cancelled.");
        using var google = await http.PostAsync("https://oauth2.googleapis.com/token", new FormUrlEncodedContent(new Dictionary<string, string> {
            ["client_id"] = config.OAuthClientId, ["client_secret"] = config.OAuthClientSecret,
            ["code"] = code, ["code_verifier"] = verifier, ["redirect_uri"] = redirect, ["grant_type"] = "authorization_code" }), ct);
        google.EnsureSuccessStatusCode();
        using var googleJson = JsonDocument.Parse(await google.Content.ReadAsStringAsync(ct));
        var googleToken = googleJson.RootElement.GetProperty("id_token").GetString()!;
        using var firebase = await http.PostAsJsonAsync($"https://identitytoolkit.googleapis.com/v1/accounts:signInWithIdp?key={Uri.EscapeDataString(config.ApiKey)}",
            new { postBody = $"id_token={Uri.EscapeDataString(googleToken)}&providerId=google.com", requestUri = redirect, returnSecureToken = true }, ct);
        firebase.EnsureSuccessStatusCode();
        using var result = JsonDocument.Parse(await firebase.Content.ReadAsStringAsync(ct));
        var root = result.RootElement;
        lock (_sessionLock) {
        if (generation != _sessionGeneration) throw new InvalidOperationException("Sign-in was cancelled because the session changed.");
        _idToken = root.GetProperty("idToken").GetString()!;
        _refreshToken = root.GetProperty("refreshToken").GetString()!;
        Uid = root.GetProperty("localId").GetString()!;
        Account = root.TryGetProperty("email", out var email) ? email.GetString()! : "Google account connected";
        _expires = DateTimeOffset.UtcNow.AddSeconds(int.Parse(root.GetProperty("expiresIn").GetString()!));
        WindowsSecretStore.Write(_sessionFile, _refreshToken);
        }
    }

    private static string Base64(byte[] data) => Convert.ToBase64String(data).TrimEnd('=').Replace('+', '-').Replace('/', '_');
    // Display only. Authorization always uses Firebase's authenticated response/ID token.
    internal static string? DisplayEmail(string token)
    {
        try {
            var part = token.Split('.')[1].Replace('-', '+').Replace('_', '/');
            part = part.PadRight((part.Length + 3) / 4 * 4, '=');
            using var json = JsonDocument.Parse(Convert.FromBase64String(part));
            return json.RootElement.TryGetProperty("email", out var email) && email.ValueKind == JsonValueKind.String ? email.GetString() : null;
        } catch (Exception ex) when (ex is IndexOutOfRangeException or FormatException or JsonException) { return null; }
    }
}
