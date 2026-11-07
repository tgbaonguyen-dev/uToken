using System.Diagnostics;
using System.Net;
using System.Net.Sockets;
using System.Security.Cryptography;
using System.Text;
using System.Text.Json;

namespace UToken.Sync.Auth;

/// <summary>System browser + loopback callback, authorization code with S256 PKCE (ADR-0003).</summary>
public sealed class GoogleOAuthClient(HttpClient http, FirebaseOptions options,
    Action<Uri>? openBrowser = null) : IGoogleOAuthClient
{
    public async Task<string> GetIdTokenAsync(CancellationToken ct)
    {
        var errors = options.ValidateGoogleSignIn();
        if (errors.Count != 0) throw new AuthException("AUTH_CONFIG", string.Join("; ", errors));

        using var timeout = CancellationTokenSource.CreateLinkedTokenSource(ct);
        timeout.CancelAfter(TimeSpan.FromMinutes(2));
        try
        {
            return await AuthorizeAsync(timeout.Token);
        }
        catch (OperationCanceledException) when (!ct.IsCancellationRequested)
        {
            throw new AuthException("AUTH_TIMEOUT", "Hết thời gian đăng nhập. Vui lòng thử lại.");
        }
    }

    private async Task<string> AuthorizeAsync(CancellationToken ct)
    {
        var verifier = Base64Url(RandomNumberGenerator.GetBytes(32));
        var state = Base64Url(RandomNumberGenerator.GetBytes(32));
        using var listener = new TcpListener(IPAddress.Loopback, 0);
        listener.Start();
        var port = ((IPEndPoint)listener.LocalEndpoint).Port;
        var redirect = $"http://127.0.0.1:{port}/";
        var authorize = BuildAuthorizationUri(options.OAuthClientId, redirect, verifier, state);
        try
        {
            if (openBrowser is not null) openBrowser(authorize);
            else Process.Start(new ProcessStartInfo(authorize.AbsoluteUri) { UseShellExecute = true });
        }
        catch (Exception ex) when (ex is System.ComponentModel.Win32Exception or InvalidOperationException)
        {
            throw new AuthException("AUTH_BROWSER", "Không mở được trình duyệt hệ thống. Kiểm tra trình duyệt mặc định.");
        }

        string? code = null;
        while (code is null)
        {
            using var client = await listener.AcceptTcpClientAsync(ct);
            using var stream = client.GetStream();
            using var requestTimeout = CancellationTokenSource.CreateLinkedTokenSource(ct);
            requestTimeout.CancelAfter(TimeSpan.FromSeconds(5));
            string line;
            try { line = await ReadRequestLineAsync(stream, requestTimeout.Token); }
            catch (OperationCanceledException) when (!ct.IsCancellationRequested) { continue; }
            catch (IOException) { continue; }
            var parts = line.Split(' ');
            var validRequest = parts.Length == 3 && parts[0] == "GET" && parts[1].StartsWith("/?", StringComparison.Ordinal);
            var query = validRequest ? ParseQuery(parts[1][2..]) : new Dictionary<string, string>();
            var validState = query.TryGetValue("state", out var receivedState) &&
                CryptographicOperations.FixedTimeEquals(Encoding.UTF8.GetBytes(state), Encoding.UTF8.GetBytes(receivedState));
            var denied = validState && query.ContainsKey("error");
            if (validState && query.TryGetValue("code", out var receivedCode) && !string.IsNullOrWhiteSpace(receivedCode))
                code = receivedCode;
            var accepted = code is not null || denied;
            var body = accepted ? "You may close this window and return to uToken." : "Invalid callback. Return to uToken and try again.";
            var bytes = Encoding.UTF8.GetBytes(body);
            var headers = Encoding.ASCII.GetBytes($"HTTP/1.1 {(accepted ? "200 OK" : "400 Bad Request")}\r\nContent-Type: text/plain; charset=utf-8\r\nContent-Length: {bytes.Length}\r\nCache-Control: no-store\r\nConnection: close\r\n\r\n");
            try
            {
                await stream.WriteAsync(headers, ct);
                await stream.WriteAsync(bytes, ct);
            }
            catch (IOException) { /* Browser may close before reading the response. */ }
            if (denied) throw query["error"] == "access_denied"
                ? new AuthException("AUTH_CANCELLED", "Bạn đã hủy đăng nhập Google.")
                : new AuthException("AUTH_FAILED", "Google không hoàn tất đăng nhập. Vui lòng thử lại.");
        }

        using var content = new FormUrlEncodedContent(new Dictionary<string, string>
        {
            ["client_id"] = options.OAuthClientId,
            ["client_secret"] = options.OAuthClientSecret,
            ["code"] = code,
            ["code_verifier"] = verifier,
            ["redirect_uri"] = redirect,
            ["grant_type"] = "authorization_code",
        });
        using var response = await http.PostAsync("https://oauth2.googleapis.com/token", content, ct);
        if ((int)response.StatusCode >= 500 || response.StatusCode == HttpStatusCode.TooManyRequests)
            throw new AuthException("AUTH_NETWORK", "Google tạm thời không khả dụng. Vui lòng thử lại.");
        if (!response.IsSuccessStatusCode)
            throw new AuthException("AUTH_INVALID", "Google từ chối phiên đăng nhập. Vui lòng thử lại.");
        JsonDocument json;
        try { json = await JsonDocument.ParseAsync(await response.Content.ReadAsStreamAsync(ct), cancellationToken: ct); }
        catch (JsonException) { throw InvalidResponse(); }
        using (json)
        {
            if (json.RootElement.ValueKind != JsonValueKind.Object ||
                !json.RootElement.TryGetProperty("id_token", out var token) ||
                token.ValueKind != JsonValueKind.String || string.IsNullOrWhiteSpace(token.GetString()))
                throw InvalidResponse();
            // Firebase verifies the Google signature, issuer, audience and expiry during signInWithIdp.
            return token.GetString()!;
        }
    }

    private static AuthException InvalidResponse() => new("AUTH_RESPONSE", "Google trả về dữ liệu đăng nhập không hợp lệ. Vui lòng thử lại.");

    public static Uri BuildAuthorizationUri(string clientId, string redirect, string verifier, string state)
    {
        var challenge = Base64Url(SHA256.HashData(Encoding.ASCII.GetBytes(verifier)));
        var values = new Dictionary<string, string>
        {
            ["client_id"] = clientId, ["redirect_uri"] = redirect, ["response_type"] = "code",
            ["scope"] = "openid email profile", ["state"] = state,
            ["code_challenge"] = challenge, ["code_challenge_method"] = "S256", ["prompt"] = "select_account",
        };
        return new Uri("https://accounts.google.com/o/oauth2/v2/auth?" +
            string.Join("&", values.Select(p => $"{Uri.EscapeDataString(p.Key)}={Uri.EscapeDataString(p.Value)}")));
    }

    private static Dictionary<string, string> ParseQuery(string query) => query.Split('&')
        .Select(p => p.Split('=', 2)).Where(p => p.Length == 2)
        .GroupBy(p => Uri.UnescapeDataString(p[0]))
        .Where(g => g.Count() == 1)
        .ToDictionary(g => g.Key, g => Uri.UnescapeDataString(g.Single()[1].Replace('+', ' ')));

    private static async Task<string> ReadRequestLineAsync(Stream stream, CancellationToken ct)
    {
        var bytes = new List<byte>();
        var buffer = new byte[1];
        // Consume the bounded header block before closing: unread request bytes can cause
        // a TCP reset on Windows and discard the browser's success response.
        while (bytes.Count < 16384 && await stream.ReadAsync(buffer, ct) != 0)
        {
            bytes.Add(buffer[0]);
            if (bytes.Count >= 4 && bytes[^4] == '\r' && bytes[^3] == '\n' && bytes[^2] == '\r' && bytes[^1] == '\n')
                return Encoding.ASCII.GetString(bytes.ToArray()).Split("\r\n", 2)[0];
        }
        return "";
    }

    private static string Base64Url(byte[] bytes) => Convert.ToBase64String(bytes).TrimEnd('=').Replace('+', '-').Replace('/', '_');
}
