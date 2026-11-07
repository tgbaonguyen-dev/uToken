using System.Net;
using System.Text;
using UToken.Sync;
using UToken.Sync.Auth;
using Xunit;

namespace UToken.Sync.Tests;

public sealed class FirebaseAuthTests
{
    private static readonly FirebaseOptions Options = new() { ProjectId = "test", ApiKey = "test-key", UseEmulator = true };
    private const string SignInResponse = """{"localId":"uid-a","email":"a@example.test","displayName":"Test","idToken":"firebase-id","refreshToken":"refresh-a","expiresIn":"3600"}""";
    private const string RefreshResponse = """{"user_id":"uid-a","id_token":"firebase-new","refresh_token":"refresh-b","expires_in":"3600"}""";

    [Fact]
    public async Task GoogleCredentialIsExchangedForFirebaseSessionAndOnlyRefreshCredentialIsSaved()
    {
        var store = new MemoryStore();
        using var http = new HttpClient(new Handler(async req =>
        {
            Assert.Contains("/accounts:signInWithIdp?key=test-key", req.RequestUri!.ToString());
            var body = await req.Content!.ReadAsStringAsync();
            Assert.Contains("id_token=google-id", body);
            Assert.Contains("google.com", body);
            Assert.Contains("returnSecureToken", body);
            return Json(SignInResponse);
        }));
        var auth = new FirebaseAuthService(http, Options, new Google(), store);
        await auth.SignInWithGoogleAsync();
        Assert.Equal("uid-a", auth.CurrentUser!.Uid);
        Assert.Equal("a@example.test", auth.CurrentUser.Email);
        Assert.Equal("refresh-a", store.Saved!.RefreshToken);
        Assert.Equal("firebase-id", await auth.GetIdTokenAsync());
    }

    [Fact]
    public async Task ExpiryRefreshesOnceForConcurrentRequestsAndRotatesStoredCredential()
    {
        var store = new MemoryStore();
        var clock = new Clock();
        var refreshes = 0;
        using var http = new HttpClient(new Handler(req =>
        {
            if (req.RequestUri!.AbsolutePath.EndsWith("/token")) { Interlocked.Increment(ref refreshes); return Task.FromResult(Json(RefreshResponse)); }
            return Task.FromResult(Json(SignInResponse));
        }));
        var auth = new FirebaseAuthService(http, Options, new Google(), store, clock);
        await auth.SignInWithGoogleAsync();
        clock.Now = clock.Now.AddHours(1);
        var results = await Task.WhenAll(Enumerable.Range(0, 10).Select(_ => auth.GetIdTokenAsync()));
        Assert.All(results, token => Assert.Equal("firebase-new", token));
        Assert.Equal(1, refreshes);
        Assert.Equal("refresh-b", store.Saved!.RefreshToken);
    }

    [Theory]
    [InlineData("TOKEN_EXPIRED")]
    [InlineData("INVALID_REFRESH_TOKEN")]
    [InlineData("USER_DISABLED")]
    public async Task RevokedSessionIsClearedAndRequiresLogin(string error)
    {
        var store = new MemoryStore { Saved = Saved() };
        using var http = new HttpClient(new Handler(_ => Task.FromResult(Json(
            System.Text.Json.JsonSerializer.Serialize(new { error = new { message = error } }), HttpStatusCode.BadRequest))));
        var auth = new FirebaseAuthService(http, Options, new Google(), store);
        var ex = await Assert.ThrowsAsync<AuthException>(() => auth.RestoreSessionAsync());
        Assert.Equal("AUTH_INVALID", ex.Code);
        Assert.Null(auth.CurrentUser);
        Assert.Null(store.Saved);
    }

    [Fact]
    public async Task RefreshCannotSwitchToAnotherUid()
    {
        var store = new MemoryStore { Saved = Saved() };
        using var http = new HttpClient(new Handler(_ => Task.FromResult(Json(RefreshResponse.Replace("uid-a", "uid-b")))));
        var auth = new FirebaseAuthService(http, Options, new Google(), store);
        Assert.Equal("AUTH_INVALID", (await Assert.ThrowsAsync<AuthException>(() => auth.RestoreSessionAsync())).Code);
        Assert.Null(auth.CurrentUser);
        Assert.Null(store.Saved);
    }

    [Fact]
    public async Task NetworkFailureKeepsCredentialForRetryAndDoesNotInventAUser()
    {
        var store = new MemoryStore { Saved = Saved() };
        using var http = new HttpClient(new Handler(_ => throw new HttpRequestException("offline")));
        var auth = new FirebaseAuthService(http, Options, new Google(), store);
        await Assert.ThrowsAsync<HttpRequestException>(() => auth.RestoreSessionAsync());
        Assert.NotNull(store.Saved);
        Assert.Null(auth.CurrentUser);
    }

    [Fact]
    public async Task SignOutClearsMemoryAndVaultAndBlocksFurtherRequests()
    {
        var store = new MemoryStore();
        using var http = new HttpClient(new Handler(_ => Task.FromResult(Json(SignInResponse))));
        var auth = new FirebaseAuthService(http, Options, new Google(), store);
        await auth.SignInWithGoogleAsync();
        await auth.SignOutAsync();
        Assert.Null(auth.CurrentUser);
        Assert.Null(store.Saved);
        Assert.Equal("AUTH_INVALID", (await Assert.ThrowsAsync<AuthException>(() => auth.GetIdTokenAsync())).Code);
    }

    [Fact]
    public async Task RestoreRefreshesCredentialAndRestoresProfile()
    {
        var store = new MemoryStore { Saved = Saved() };
        using var http = new HttpClient(new Handler(async req =>
        {
            Assert.Contains("/securetoken.googleapis.com/v1/token", req.RequestUri!.ToString());
            Assert.Contains("grant_type=refresh_token", await req.Content!.ReadAsStringAsync());
            return Json(RefreshResponse);
        }));
        var auth = new FirebaseAuthService(http, Options, new Google(), store);
        await auth.RestoreSessionAsync();
        Assert.Equal("uid-a", auth.CurrentUser!.Uid);
        Assert.Equal("a@example.test", auth.CurrentUser.Email);
        Assert.Equal("firebase-new", await auth.GetIdTokenAsync());
    }

    [Fact]
    public async Task ServerOutageDoesNotDeleteSavedSession()
    {
        var store = new MemoryStore { Saved = Saved() };
        using var http = new HttpClient(new Handler(_ => Task.FromResult(Json("unavailable", HttpStatusCode.ServiceUnavailable))));
        var auth = new FirebaseAuthService(http, Options, new Google(), store);
        Assert.Equal("AUTH_NETWORK", (await Assert.ThrowsAsync<AuthException>(() => auth.RestoreSessionAsync())).Code);
        Assert.NotNull(store.Saved);
    }

    [Theory]
    [InlineData("null")]
    [InlineData("[]")]
    [InlineData("{\"localId\":123}")]
    [InlineData("not-json")]
    public async Task MalformedSuccessfulResponseIsARecoverableAuthError(string response)
    {
        using var http = new HttpClient(new Handler(_ => Task.FromResult(Json(response))));
        var auth = new FirebaseAuthService(http, Options, new Google(), new MemoryStore());
        Assert.Equal("AUTH_RESPONSE", (await Assert.ThrowsAsync<AuthException>(() => auth.SignInWithGoogleAsync())).Code);
        Assert.Null(auth.CurrentUser);
    }

    [Fact]
    public async Task FailedVaultDeletionStillLocksTheInMemorySession()
    {
        var store = new MemoryStore();
        using var http = new HttpClient(new Handler(_ => Task.FromResult(Json(SignInResponse))));
        var auth = new FirebaseAuthService(http, Options, new Google(), store);
        await auth.SignInWithGoogleAsync();
        store.FailClear = true;
        await Assert.ThrowsAsync<IOException>(() => auth.SignOutAsync());
        Assert.Null(auth.CurrentUser);
        await Assert.ThrowsAsync<AuthException>(() => auth.GetIdTokenAsync());
    }

    [Fact]
    public void SessionStorageIsSeparatedByProjectAndEnvironment()
    {
        var production = new FirebaseOptions { ProjectId = "test", UseEmulator = false };
        Assert.NotEqual(Options.SessionKey, production.SessionKey);
        Assert.NotEqual(Options.SessionKey, new FirebaseOptions { ProjectId = "other" }.SessionKey);
        Assert.NotEmpty(Options.ValidateGoogleSignIn());
    }

    private static StoredSession Saved() => new() { Uid = "uid-a", RefreshToken = "refresh-a", Email = "a@example.test" };
    internal static HttpResponseMessage Json(string body, HttpStatusCode status = HttpStatusCode.OK) => new(status)
        { Content = new StringContent(body, Encoding.UTF8, "application/json") };
    internal sealed class Handler(Func<HttpRequestMessage, Task<HttpResponseMessage>> send) : HttpMessageHandler
    {
        protected override Task<HttpResponseMessage> SendAsync(HttpRequestMessage request, CancellationToken ct) => send(request);
    }
    private sealed class Google : IGoogleOAuthClient { public Task<string> GetIdTokenAsync(CancellationToken ct) => Task.FromResult("google-id"); }
    private sealed class Clock : TimeProvider
    {
        public DateTimeOffset Now = new(2026, 11, 7, 0, 0, 0, TimeSpan.Zero);
        public override DateTimeOffset GetUtcNow() => Now;
    }
    private sealed class MemoryStore : IRefreshTokenStore
    {
        public StoredSession? Saved;
        public bool FailClear;
        public Task<StoredSession?> LoadAsync(CancellationToken ct) => Task.FromResult(Saved);
        public Task SaveAsync(StoredSession session, CancellationToken ct) { Saved = session; return Task.CompletedTask; }
        public Task ClearAsync(CancellationToken ct) { if (FailClear) throw new IOException("unavailable"); Saved = null; return Task.CompletedTask; }
    }
}
