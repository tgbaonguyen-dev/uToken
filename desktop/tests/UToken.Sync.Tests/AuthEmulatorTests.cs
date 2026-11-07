using System.Net;
using System.Net.Http.Headers;
using System.Net.Http.Json;
using System.Text.Json;
using UToken.Sync.Auth;
using Xunit;

namespace UToken.Sync.Tests;

// These tests are opt-in and never accept a production host/project. Mock Google
// credentials are recognized only by the local Firebase Authentication Emulator.
public sealed class AuthEmulatorTests
{
    [EmulatorFact]
    public async Task SameGoogleAccountRestoresTheSameFirebaseUidAcrossClients()
    {
        var options = Options();
        using var http = new HttpClient();
        var google = new MockGoogle(Guid.NewGuid().ToString("N"));
        var store = new Store();
        var first = new FirebaseAuthService(http, options, google, store);
        var second = new FirebaseAuthService(http, options, google, new Store());
        await first.SignInWithGoogleAsync();
        await second.SignInWithGoogleAsync();
        Assert.Equal(first.CurrentUser!.Uid, second.CurrentUser!.Uid);
        var restored = new FirebaseAuthService(http, options, google, store);
        await restored.RestoreSessionAsync();
        Assert.Equal(first.CurrentUser.Uid, restored.CurrentUser!.Uid);
        Assert.NotEmpty(await restored.GetIdTokenAsync());
    }

    [EmulatorFact]
    public async Task FirestoreAllowsOwnerButRejectsAnotherUidAndUnauthenticatedRequests()
    {
        var options = Options();
        using var http = new HttpClient();
        var owner = new FirebaseAuthService(http, options, new MockGoogle(Guid.NewGuid().ToString("N")), new Store());
        var other = new FirebaseAuthService(http, options, new MockGoogle(Guid.NewGuid().ToString("N")), new Store());
        await owner.SignInWithGoogleAsync();
        await other.SignInWithGoogleAsync();
        Assert.NotEqual(owner.CurrentUser!.Uid, other.CurrentUser!.Uid);
        var relativePath = $"users/{owner.CurrentUser.Uid}/auth_qa/record";
        var documentName = $"projects/{options.ProjectId}/databases/(default)/documents/{relativePath}";
        var body = JsonSerializer.Serialize(new { writes = new[] { new { update = new { name = documentName, fields = new { verified = new { booleanValue = true } } } } } });
        var ownerFirestore = new FirestoreRestClient(http, options, owner.GetIdTokenAsync);
        await ownerFirestore.CommitAsync(body, default);
        using var ownerRequest = new HttpRequestMessage(HttpMethod.Get, $"{options.FirestoreBaseUrl}/{relativePath}");
        ownerRequest.Headers.Authorization = new AuthenticationHeaderValue("Bearer", await owner.GetIdTokenAsync());
        using var ownerResponse = await http.SendAsync(ownerRequest);
        Assert.Equal(HttpStatusCode.OK, ownerResponse.StatusCode);
        using var otherRequest = new HttpRequestMessage(HttpMethod.Get, ownerRequest.RequestUri);
        otherRequest.Headers.Authorization = new AuthenticationHeaderValue("Bearer", await other.GetIdTokenAsync());
        using var otherResponse = await http.SendAsync(otherRequest);
        Assert.Equal(HttpStatusCode.Forbidden, otherResponse.StatusCode);
        var otherFirestore = new FirestoreRestClient(http, options, other.GetIdTokenAsync);
        Assert.Equal(HttpStatusCode.Forbidden, (await Assert.ThrowsAsync<HttpRequestException>(() => otherFirestore.CommitAsync(body, default))).StatusCode);
        using var anonymousResponse = await http.GetAsync(ownerRequest.RequestUri);
        Assert.Equal(HttpStatusCode.Forbidden, anonymousResponse.StatusCode);
        await owner.SignOutAsync();
        await Assert.ThrowsAsync<AuthException>(() => ownerFirestore.CommitAsync(body, default));
    }

    [EmulatorFact]
    public async Task DisabledUserCannotRestoreAndItsSavedCredentialIsCleared()
    {
        var options = Options();
        using var http = new HttpClient();
        var store = new Store();
        var google = new MockGoogle(Guid.NewGuid().ToString("N"));
        var auth = new FirebaseAuthService(http, options, google, store);
        await auth.SignInWithGoogleAsync();
        using var request = new HttpRequestMessage(HttpMethod.Post,
            $"{options.IdentityToolkitBaseUrl}/projects/{options.ProjectId}/accounts:update")
        {
            Content = JsonContent.Create(new { localId = auth.CurrentUser!.Uid, disableUser = true }),
        };
        request.Headers.Authorization = new AuthenticationHeaderValue("Bearer", "owner"); // Emulator admin only.
        using var response = await http.SendAsync(request);
        response.EnsureSuccessStatusCode();
        var restored = new FirebaseAuthService(http, options, google, store);
        Assert.Equal("AUTH_INVALID", (await Assert.ThrowsAsync<AuthException>(() => restored.RestoreSessionAsync())).Code);
        Assert.Null(restored.CurrentUser);
        Assert.Null(store.Saved);
    }

    private static FirebaseOptions Options()
    {
        var auth = Environment.GetEnvironmentVariable("UTOKEN_TEST_AUTH_HOST")!;
        var firestore = Environment.GetEnvironmentVariable("UTOKEN_TEST_FIRESTORE_HOST") ?? "127.0.0.1:18080";
        foreach (var host in new[] { auth, firestore })
            if (!Uri.TryCreate($"http://{host}", UriKind.Absolute, out var uri) || uri.Host != "127.0.0.1" || uri.Port < 1024)
                throw new InvalidOperationException("Integration tests require explicit IPv4 loopback emulator hosts.");
        return new FirebaseOptions { ProjectId = "demo-utoken", UseEmulator = true, AuthEmulatorHost = auth, FirestoreEmulatorHost = firestore };
    }

    private sealed class MockGoogle(string subject) : IGoogleOAuthClient
    {
        public Task<string> GetIdTokenAsync(CancellationToken ct) => Task.FromResult(JsonSerializer.Serialize(new
            { sub = subject, email = $"{subject}@example.test", email_verified = true, name = "Auth QA" }));
    }
    private sealed class Store : IRefreshTokenStore
    {
        public StoredSession? Saved;
        public Task<StoredSession?> LoadAsync(CancellationToken ct) => Task.FromResult(Saved);
        public Task SaveAsync(StoredSession session, CancellationToken ct) { Saved = session; return Task.CompletedTask; }
        public Task ClearAsync(CancellationToken ct) { Saved = null; return Task.CompletedTask; }
    }
}

public sealed class EmulatorFactAttribute : FactAttribute
{
    public EmulatorFactAttribute()
    {
        if (string.IsNullOrWhiteSpace(Environment.GetEnvironmentVariable("UTOKEN_TEST_AUTH_HOST")))
            Skip = "Requires local Firebase Auth + Firestore emulators; see docs/auth-verification.md.";
    }
}
