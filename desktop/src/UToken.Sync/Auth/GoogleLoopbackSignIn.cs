using System.Diagnostics;
using System.Net;
using System.Net.Sockets;
using System.Security.Cryptography;
using System.Text;
using System.Text.Json;

namespace UToken.Sync.Auth;

/// <summary>Lấy Google ID token của người dùng. Tách interface để test không cần trình duyệt.</summary>
public sealed class GoogleSignInException(string message, Exception? inner = null) : Exception(message, inner);

public interface IGoogleSignIn
{
    Task<string> GetGoogleIdTokenAsync(CancellationToken ct);
}

/// <summary>
/// Đăng nhập Google cho ứng dụng desktop (ADR-0003): OAuth 2.0 authorization code + PKCE (S256),
/// redirect về loopback http://127.0.0.1:{port}/ trên máy, mở trình duyệt hệ thống.
/// OAuth client loại "Desktop app": Google coi client secret của loại này là không bí mật, PKCE mới là lớp bảo vệ.
/// </summary>
public sealed class GoogleLoopbackSignIn(HttpClient http, FirebaseOptions options, Action<string>? openBrowser = null) : IGoogleSignIn
{
    public static readonly TimeSpan Timeout = TimeSpan.FromMinutes(3);
    private const string AuthEndpoint = "https://accounts.google.com/o/oauth2/v2/auth";
    private const string TokenEndpoint = "https://oauth2.googleapis.com/token";

    public async Task<string> GetGoogleIdTokenAsync(CancellationToken ct)
    {
        if (string.IsNullOrWhiteSpace(options.OAuthClientId))
            throw new InvalidOperationException("Firebase:OAuthClientId is not set in appsettings.Local.json.");

        var verifier = Base64Url(RandomNumberGenerator.GetBytes(32));
        var challenge = Base64Url(SHA256.HashData(Encoding.ASCII.GetBytes(verifier)));
        var state = Base64Url(RandomNumberGenerator.GetBytes(16));
        int port = FreePort();
        var redirect = $"http://127.0.0.1:{port}/";

        using var listener = new HttpListener();
        listener.Prefixes.Add(redirect);
        listener.Start();

        var url = AuthEndpoint +
                  $"?client_id={Uri.EscapeDataString(options.OAuthClientId)}" +
                  $"&redirect_uri={Uri.EscapeDataString(redirect)}" +
                  "&response_type=code&scope=openid%20email%20profile" +
                  $"&code_challenge={challenge}&code_challenge_method=S256" +
                  $"&state={state}&prompt=select_account";
        (openBrowser ?? OpenSystemBrowser)(url);

        using var timeout = CancellationTokenSource.CreateLinkedTokenSource(ct);
        timeout.CancelAfter(Timeout);
        HttpListenerContext context;
        using (timeout.Token.Register(listener.Stop))
        {
            try { context = await listener.GetContextAsync(); }
            catch (Exception ex) when (ex is HttpListenerException or ObjectDisposedException)
            {
                ct.ThrowIfCancellationRequested();
                throw new TimeoutException("Google sign-in timed out. Try again.");
            }
        }

        var query = context.Request.QueryString;
        bool ok = query["state"] == state && query["code"] is { Length: > 0 } && query["error"] is null;
        await RespondAsync(context, ok
            ? "Google authorization received. Return to uToken to check whether sign-in completed. You can close this tab."
            : "Sign-in was cancelled or failed. Return to uToken and try again.");
        if (!ok) throw new GoogleSignInException(query["error"] == "access_denied"
            ? "Google sign-in was cancelled or access was denied. Try again and approve access."
            : "The Google callback could not be verified. Start sign-in again from uToken.");

        try
        {
            using var res = await http.PostAsync(TokenEndpoint, new FormUrlEncodedContent(new Dictionary<string, string>
            {
                ["code"] = query["code"]!,
                ["client_id"] = options.OAuthClientId,
                ["client_secret"] = options.OAuthClientSecret,
                ["redirect_uri"] = redirect,
                ["grant_type"] = "authorization_code",
                ["code_verifier"] = verifier,
            }), ct);
            if (!res.IsSuccessStatusCode)
                throw new GoogleSignInException(res.StatusCode is HttpStatusCode.BadRequest or HttpStatusCode.Unauthorized
                    ? "Google could not exchange the sign-in code. Check the Desktop OAuth client ID/secret and start sign-in again."
                    : "Google token exchange is temporarily unavailable. Try again later.");
            using var doc = JsonDocument.Parse(await res.Content.ReadAsStringAsync(ct));
            return doc.RootElement.TryGetProperty("id_token", out var idToken) && idToken.GetString() is { Length: > 0 } t
                ? t : throw new InvalidDataException("Google did not return an id_token.");
        }
        catch (HttpRequestException ex)
        {
            throw new GoogleSignInException("Cannot reach Google's token service. Check your connection and try again.", ex);
        }
        catch (OperationCanceledException ex) when (!ct.IsCancellationRequested)
        {
            throw new GoogleSignInException("Google token exchange timed out. Check your connection and try again.", ex);
        }
        catch (Exception ex) when (ex is JsonException or InvalidDataException)
        {
            throw new GoogleSignInException("Google returned an invalid sign-in response. Start sign-in again.", ex);
        }
    }

    private static async Task RespondAsync(HttpListenerContext context, string message)
    {
        var html = Encoding.UTF8.GetBytes(
            $"<!doctype html><meta charset=utf-8><title>uToken</title><body style=\"font-family:sans-serif;padding:40px\"><h2>uToken</h2><p>{WebUtility.HtmlEncode(message)}</p></body>");
        context.Response.ContentType = "text/html; charset=utf-8";
        context.Response.ContentLength64 = html.Length;
        await context.Response.OutputStream.WriteAsync(html);
        context.Response.Close();
    }

    private static void OpenSystemBrowser(string url)
    {
        if (OperatingSystem.IsWindows()) Process.Start(new ProcessStartInfo(url) { UseShellExecute = true });
        else if (OperatingSystem.IsMacOS()) Process.Start("open", url);
        else Process.Start("xdg-open", url);
    }

    private static int FreePort()
    {
        var l = new TcpListener(IPAddress.Loopback, 0);
        l.Start();
        int port = ((IPEndPoint)l.LocalEndpoint).Port;
        l.Stop();
        return port;
    }

    private static string Base64Url(byte[] bytes) =>
        Convert.ToBase64String(bytes).TrimEnd('=').Replace('+', '-').Replace('/', '_');
}
