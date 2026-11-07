using System.Net;
using UToken.Sync;
using UToken.Sync.Auth;
using Xunit;

namespace UToken.Sync.Tests;

public sealed class GoogleOAuthTests
{
    [Fact]
    public void AuthorizationUsesRfc7636S256VectorWithoutExposingClientSecret()
    {
        var uri = GoogleOAuthClient.BuildAuthorizationUri("client", "http://127.0.0.1:1234/",
            "dBjftJeZ4CVP-mB92K27uhbUJU1p1r_wW1gFWFOEjXk", "random-state");
        Assert.Equal("accounts.google.com", uri.Host);
        Assert.Contains("code_challenge=E9Melhoa2OwvFrEMTJguCHaoeK1t8URWbuGJSstw-cM", uri.Query);
        Assert.Contains("code_challenge_method=S256", uri.Query);
        Assert.Contains("state=random-state", uri.Query);
        Assert.Contains("openid", uri.Query);
        Assert.DoesNotContain("client_secret", uri.Query);
        Assert.DoesNotContain("code_verifier", uri.Query);
    }

    [Fact]
    public async Task LoopbackRejectsWrongStateThenAcceptsValidCodeAndExchangesWithVerifier()
    {
        Task? browserTask = null;
        string? redirect = null;
        using var googleHttp = new HttpClient(new FirebaseAuthTests.Handler(async req =>
        {
            Assert.Equal("https://oauth2.googleapis.com/token", req.RequestUri!.ToString());
            var form = await req.Content!.ReadAsStringAsync();
            Assert.Contains("code=valid-code", form);
            Assert.Contains("code_verifier=", form);
            Assert.Contains(Uri.EscapeDataString(redirect!), form);
            return FirebaseAuthTests.Json("""{"id_token":"signed-google-token"}""");
        }));
        var client = new GoogleOAuthClient(googleHttp, Options(), uri =>
        {
            var query = Query(uri);
            redirect = query["redirect_uri"];
            Assert.Equal("127.0.0.1", new Uri(redirect).Host);
            browserTask = Task.Run(async () =>
            {
                using var browser = new HttpClient();
                var wrong = await browser.GetAsync(redirect + "?state=wrong&code=stolen");
                Assert.Equal(HttpStatusCode.BadRequest, wrong.StatusCode);
                var right = await browser.GetAsync(redirect + "?state=" + query["state"] + "&code=valid-code");
                Assert.Equal(HttpStatusCode.OK, right.StatusCode);
            });
        });
        using var timeout = new CancellationTokenSource(TimeSpan.FromSeconds(10));
        Assert.Equal("signed-google-token", await client.GetIdTokenAsync(timeout.Token));
        await browserTask!;
    }

    [Fact]
    public async Task DeniedConsentDoesNotCallTokenEndpoint()
    {
        Task? browserTask = null;
        using var http = new HttpClient(new FirebaseAuthTests.Handler(_ => throw new InvalidOperationException("Must not exchange")));
        var client = new GoogleOAuthClient(http, Options(), uri =>
        {
            var query = Query(uri);
            browserTask = Task.Run(async () =>
            {
                using var browser = new HttpClient();
                await browser.GetAsync(query["redirect_uri"] + "?state=" + query["state"] + "&error=access_denied");
            });
        });
        using var timeout = new CancellationTokenSource(TimeSpan.FromSeconds(10));
        Assert.Equal("AUTH_CANCELLED", (await Assert.ThrowsAsync<AuthException>(() => client.GetIdTokenAsync(timeout.Token))).Code);
        await browserTask!;
    }

    [Fact]
    public async Task CancellationStopsLoopbackListener()
    {
        using var cts = new CancellationTokenSource();
        using var http = new HttpClient();
        var client = new GoogleOAuthClient(http, Options(), _ => cts.Cancel());
        await Assert.ThrowsAnyAsync<OperationCanceledException>(() => client.GetIdTokenAsync(cts.Token));
    }

    [Theory]
    [InlineData("not-json", HttpStatusCode.OK, "AUTH_RESPONSE")]
    [InlineData("[]", HttpStatusCode.OK, "AUTH_RESPONSE")]
    [InlineData("{\"id_token\":123}", HttpStatusCode.OK, "AUTH_RESPONSE")]
    [InlineData("{\"id_token\":\"\"}", HttpStatusCode.OK, "AUTH_RESPONSE")]
    [InlineData("{}", HttpStatusCode.OK, "AUTH_RESPONSE")]
    [InlineData("unavailable", HttpStatusCode.ServiceUnavailable, "AUTH_NETWORK")]
    [InlineData("rate limit", HttpStatusCode.TooManyRequests, "AUTH_NETWORK")]
    [InlineData("{\"error\":\"invalid_grant\"}", HttpStatusCode.BadRequest, "AUTH_INVALID")]
    public async Task TokenEndpointFailuresAreRecoverableAndNeverExposeTheResponse(string body, HttpStatusCode status, string expected)
    {
        var error = await CallbackFailureAsync("code=valid-code", body, status);
        Assert.Equal(expected, error.Code);
        Assert.DoesNotContain(body, error.Message);
    }

    [Fact]
    public async Task ProviderServerErrorIsNotReportedAsUserCancellation()
    {
        var error = await CallbackFailureAsync("error=server_error", "must not be requested", HttpStatusCode.OK);
        Assert.Equal("AUTH_FAILED", error.Code);
    }

    [Theory]
    [InlineData("?state=$STATE&state=$STATE&code=ignored")]
    [InlineData("?state=$STATE&code=first&code=second")]
    [InlineData("?state=wrong&error=access_denied")]
    [InlineData("favicon.ico")]
    public async Task MalformedCallbacksDoNotCompleteTheLogin(string invalidCallback)
    {
        Task? browserTask = null;
        using var http = new HttpClient(new FirebaseAuthTests.Handler(_ => Task.FromResult(FirebaseAuthTests.Json("""{"id_token":"google-token"}"""))));
        var client = new GoogleOAuthClient(http, Options(), uri =>
        {
            var query = Query(uri);
            browserTask = Task.Run(async () =>
            {
                using var browser = new HttpClient();
                using var wrong = await browser.GetAsync(query["redirect_uri"] + invalidCallback.Replace("$STATE", query["state"]));
                Assert.Equal(HttpStatusCode.BadRequest, wrong.StatusCode);
                using var right = await browser.GetAsync(query["redirect_uri"] + "?state=" + query["state"] + "&code=valid-code");
                Assert.Equal(HttpStatusCode.OK, right.StatusCode);
            });
        });
        using var timeout = new CancellationTokenSource(TimeSpan.FromSeconds(10));
        Assert.Equal("google-token", await client.GetIdTokenAsync(timeout.Token));
        await browserTask!;
    }

    private static async Task<AuthException> CallbackFailureAsync(string callback, string body, HttpStatusCode status)
    {
        Task? browserTask = null;
        using var http = new HttpClient(new FirebaseAuthTests.Handler(_ => Task.FromResult(FirebaseAuthTests.Json(body, status))));
        var client = new GoogleOAuthClient(http, Options(), uri =>
        {
            var query = Query(uri);
            browserTask = Task.Run(async () =>
            {
                using var browser = new HttpClient();
                using var response = await browser.GetAsync(query["redirect_uri"] + "?state=" + query["state"] + "&" + callback);
                Assert.Equal(HttpStatusCode.OK, response.StatusCode);
            });
        });
        using var timeout = new CancellationTokenSource(TimeSpan.FromSeconds(10));
        var error = await Assert.ThrowsAsync<AuthException>(() => client.GetIdTokenAsync(timeout.Token));
        await browserTask!;
        return error;
    }

    [Fact]
    public async Task WindowsVaultRoundTripsWithoutPlaintextAndClearsCredential()
    {
        if (!OperatingSystem.IsWindows()) return;
        var dir = Path.Combine(Path.GetTempPath(), "utoken-auth-test-" + Guid.NewGuid());
        var store = new SecureRefreshTokenStore(dir, "test");
        try
        {
            await store.SaveAsync(new StoredSession { Uid = "uid-a", RefreshToken = "private-refresh-value" }, default);
            Assert.DoesNotContain("private-refresh-value", await File.ReadAllTextAsync(Directory.GetFiles(dir).Single()));
            Assert.Equal("private-refresh-value", (await store.LoadAsync(default))!.RefreshToken);
            await store.ClearAsync(default);
            Assert.Null(await store.LoadAsync(default));
        }
        finally { await store.ClearAsync(default); if (Directory.Exists(dir)) Directory.Delete(dir); }
    }

    [Fact]
    public async Task WindowsVaultConcurrentWritersNeverShareATemporaryFile()
    {
        if (!OperatingSystem.IsWindows()) return;
        var dir = Path.Combine(Path.GetTempPath(), "utoken-auth-test-" + Guid.NewGuid());
        var first = new SecureRefreshTokenStore(dir, "test");
        var second = new SecureRefreshTokenStore(dir, "test");
        try
        {
            await Task.WhenAll(
                first.SaveAsync(new StoredSession { Uid = "a", RefreshToken = new string('a', 100000) }, default),
                second.SaveAsync(new StoredSession { Uid = "b", RefreshToken = new string('b', 100000) }, default));
            var saved = (await first.LoadAsync(default))!;
            Assert.Equal(new string(saved.Uid[0], 100000), saved.RefreshToken);
            Assert.Single(Directory.GetFiles(dir));
        }
        finally { await first.ClearAsync(default); if (Directory.Exists(dir)) Directory.Delete(dir); }
    }

    [Fact]
    public async Task WindowsVaultCancelledSavePreservesThePreviousCredential()
    {
        if (!OperatingSystem.IsWindows()) return;
        var dir = Path.Combine(Path.GetTempPath(), "utoken-auth-test-" + Guid.NewGuid());
        var store = new SecureRefreshTokenStore(dir, "test");
        try
        {
            await store.SaveAsync(new StoredSession { Uid = "a", RefreshToken = "previous" }, default);
            using var cancelled = new CancellationTokenSource();
            cancelled.Cancel();
            await Assert.ThrowsAnyAsync<OperationCanceledException>(() => store.SaveAsync(
                new StoredSession { Uid = "b", RefreshToken = "replacement" }, cancelled.Token));
            Assert.Equal("previous", (await store.LoadAsync(default))!.RefreshToken);
            Assert.Single(Directory.GetFiles(dir));
        }
        finally { await store.ClearAsync(default); if (Directory.Exists(dir)) Directory.Delete(dir); }
    }

    private static FirebaseOptions Options() => new() { ProjectId = "test", OAuthClientId = "client", OAuthClientSecret = "test-secret", UseEmulator = true };
    private static Dictionary<string, string> Query(Uri uri) => uri.Query.TrimStart('?').Split('&').Select(p => p.Split('=', 2))
        .ToDictionary(p => Uri.UnescapeDataString(p[0]), p => Uri.UnescapeDataString(p[1]));
}
