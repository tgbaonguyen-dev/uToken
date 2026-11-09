using System.Net;
using System.Text;
using UToken.Desktop.App.Services;
using Xunit;

namespace UToken.Desktop.Tests;

public class DesktopGoogleAuthTests
{
    [Fact]
    public void RestoredEmailIsDisplayOnlyAndMalformedTokensAreSafe()
    {
        var body = Convert.ToBase64String(Encoding.UTF8.GetBytes("{\"email\":\"user@example.test\"}")).TrimEnd('=').Replace('+','-').Replace('/','_');
        Assert.Equal("user@example.test", DesktopGoogleAuth.DisplayEmail("header." + body + ".signature"));
        Assert.Null(DesktopGoogleAuth.DisplayEmail("not-a-token"));
        Assert.Null(DesktopGoogleAuth.DisplayEmail("a.invalid.b"));
    }
    [Fact]
    public void InvalidConfigurationCanBeCorrectedAndRetried()
    {
        var file = Path.Combine(Path.GetTempPath(), "utoken-config-" + Guid.NewGuid() + ".json");
        try {
            File.WriteAllText(file, "{broken");
            Assert.Throws<System.Text.Json.JsonException>(() => DesktopFirebaseConfig.Load(file));
            File.WriteAllText(file, "{\"ProjectId\":\"test\"}");
            Assert.Throws<InvalidDataException>(() => DesktopFirebaseConfig.Load(file));
            File.WriteAllText(file, "{\"ProjectId\":\"test\",\"ApiKey\":\"key\",\"OAuthClientId\":\"client\"}");
            Assert.Equal("test", DesktopFirebaseConfig.Load(file)!.ProjectId);
        } finally { if (File.Exists(file)) File.Delete(file); }
    }
    private sealed class Handler(Func<HttpRequestMessage, HttpResponseMessage> send) : HttpMessageHandler
    {
        protected override Task<HttpResponseMessage> SendAsync(HttpRequestMessage request, CancellationToken ct) => Task.FromResult(send(request));
    }
    private sealed class DelayedHandler(TaskCompletionSource<HttpResponseMessage> result) : HttpMessageHandler
    {
        public readonly TaskCompletionSource Entered = new(TaskCreationOptions.RunContinuationsAsynchronously);
        protected override Task<HttpResponseMessage> SendAsync(HttpRequestMessage request, CancellationToken ct) { Entered.TrySetResult(); return result.Task; }
    }
    [Fact]
    public async Task SignOutDuringRefreshCannotRestoreTheOldSession()
    {
        if (!OperatingSystem.IsWindows()) return;
        var directory = Path.Combine(Path.GetTempPath(), "utoken-auth-" + Guid.NewGuid());
        var file = Path.Combine(directory, "session.bin");
        try {
            WindowsSecretStore.Write(file, "old-refresh");
            var result = new TaskCompletionSource<HttpResponseMessage>(TaskCreationOptions.RunContinuationsAsynchronously);
            using var handler = new DelayedHandler(result);
            using var http = new HttpClient(handler);
            var auth = new DesktopGoogleAuth(new("test", "key", "client"), http, file);
            var refresh = auth.TokenAsync(default);
            await handler.Entered.Task;
            auth.SignOut();
            result.SetResult(new HttpResponseMessage(HttpStatusCode.OK) {
                Content = new StringContent("{\"id_token\":\"old-id\",\"refresh_token\":\"old-refresh\",\"user_id\":\"old-owner\",\"expires_in\":\"3600\"}") });
            await Assert.ThrowsAsync<InvalidOperationException>(() => refresh);
            Assert.Null(auth.Uid); Assert.False(File.Exists(file));
        } finally { if (Directory.Exists(directory)) Directory.Delete(directory, true); }
    }
    [Fact]
    public async Task RestoresEncryptedSessionRefreshesOnceAndSignOutDeletesIt()
    {
        if (!OperatingSystem.IsWindows()) return;
        var directory = Path.Combine(Path.GetTempPath(), "utoken-auth-" + Guid.NewGuid());
        var file = Path.Combine(directory, "session.bin");
        try
        {
            WindowsSecretStore.Write(file, "test-refresh");
            Assert.DoesNotContain("test-refresh", Encoding.UTF8.GetString(File.ReadAllBytes(file)));
            var count = 0;
            using var http = new HttpClient(new Handler(request => {
                count++;
                Assert.Equal("securetoken.googleapis.com", request.RequestUri!.Host);
                return new HttpResponseMessage(HttpStatusCode.OK) {
                    Content = new StringContent("{\"id_token\":\"test-id\",\"refresh_token\":\"rotated-refresh\",\"user_id\":\"owner\",\"expires_in\":\"3600\"}") };
            }));
            var auth = new DesktopGoogleAuth(new("test", "key", "client"), http, file);
            Assert.Equal("test-id", await auth.TokenAsync(default));
            Assert.Equal("owner", auth.Uid);
            Assert.Equal("test-id", await auth.TokenAsync(default));
            Assert.Equal(1, count);
            Assert.Equal("rotated-refresh", WindowsSecretStore.Read(file));
            auth.SignOut();
            Assert.False(File.Exists(file));
            await Assert.ThrowsAsync<InvalidOperationException>(() => auth.TokenAsync(default));
        }
        finally { if (Directory.Exists(directory)) Directory.Delete(directory, true); }
    }
    [Fact]
    public async Task NewAuthInstanceRestoresRotatedSessionAndOfflineRetryKeepsIt()
    {
        if (!OperatingSystem.IsWindows()) return;
        var directory = Path.Combine(Path.GetTempPath(), "utoken-auth-" + Guid.NewGuid());
        var file = Path.Combine(directory, "session.bin");
        try {
            WindowsSecretStore.Write(file, "initial-refresh");
            using var firstHttp = new HttpClient(new Handler(_ => new(HttpStatusCode.OK) {
                Content = new StringContent("{\"id_token\":\"first-id\",\"refresh_token\":\"rotated-refresh\",\"user_id\":\"owner\",\"expires_in\":\"3600\"}") }));
            var first = new DesktopGoogleAuth(new("test", "key", "client"), firstHttp, file);
            await first.TokenAsync(default);
            var calls = 0;
            using var reopenedHttp = new HttpClient(new Handler(request => {
                calls++;
                Assert.Contains("refresh_token=rotated-refresh", request.Content!.ReadAsStringAsync().GetAwaiter().GetResult());
                if (calls == 1) throw new HttpRequestException("offline");
                return new(HttpStatusCode.OK) {
                    Content = new StringContent("{\"id_token\":\"restored-id\",\"refresh_token\":\"next-refresh\",\"user_id\":\"owner\",\"expires_in\":\"3600\"}") };
            }));
            var reopened = new DesktopGoogleAuth(new("test", "key", "client"), reopenedHttp, file);
            await Assert.ThrowsAsync<HttpRequestException>(() => reopened.TokenAsync(default));
            Assert.Equal("rotated-refresh", WindowsSecretStore.Read(file));
            Assert.Equal("restored-id", await reopened.TokenAsync(default));
            Assert.Equal("owner", reopened.Uid);
            Assert.Equal("next-refresh", WindowsSecretStore.Read(file));
            reopened.SignOut();
            var signedOut = new DesktopGoogleAuth(new("test", "key", "client"), reopenedHttp, file);
            await Assert.ThrowsAsync<InvalidOperationException>(() => signedOut.TokenAsync(default));
            Assert.Equal(2, calls);
        } finally { if (Directory.Exists(directory)) Directory.Delete(directory, true); }
    }

    [Fact]
    public async Task CorruptEncryptedSessionAllowsSignInRecoveryWithoutNetworkRequest()
    {
        if (!OperatingSystem.IsWindows()) return;
        var directory = Path.Combine(Path.GetTempPath(), "utoken-auth-" + Guid.NewGuid());
        var file = Path.Combine(directory, "session.bin");
        try {
            Directory.CreateDirectory(directory);
            File.WriteAllText(file, "not-a-dpapi-session");
            using var http = new HttpClient(new Handler(_ => throw new Xunit.Sdk.XunitException("Corrupt session must not be sent")));
            var auth = new DesktopGoogleAuth(new("test", "key", "client"), http, file);
            await Assert.ThrowsAsync<InvalidOperationException>(() => auth.TokenAsync(default));
            Assert.Null(auth.Uid);
            Assert.False(File.Exists(file));
        } finally { if (Directory.Exists(directory)) Directory.Delete(directory, true); }
    }

    [Fact]
    public async Task RejectedRefreshClearsLocalSession()
    {
        if (!OperatingSystem.IsWindows()) return;
        var directory = Path.Combine(Path.GetTempPath(), "utoken-auth-" + Guid.NewGuid());
        var file = Path.Combine(directory, "session.bin");
        try
        {
            WindowsSecretStore.Write(file, "revoked-refresh");
            using var http = new HttpClient(new Handler(_ => new(HttpStatusCode.BadRequest)));
            var auth = new DesktopGoogleAuth(new("test", "key", "client"), http, file);
            await Assert.ThrowsAsync<FirebaseSessionExpiredException>(() => auth.TokenAsync(default));
            Assert.Null(auth.Uid); Assert.False(File.Exists(file));
        }
        finally { if (Directory.Exists(directory)) Directory.Delete(directory, true); }
    }
}
