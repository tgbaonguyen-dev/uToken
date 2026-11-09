using System.Net;
using System.Text;
using System.Text.Json;
using UToken.Desktop.App.Services;
using Xunit;

namespace UToken.Desktop.Tests;

public class FirebasePairingTests
{
    private sealed class Session : IFirebaseSession
    {
        public string? Uid => "test-owner";
        public Task<string> TokenAsync(CancellationToken ct) => Task.FromResult("test-token");
    }
    private sealed class Handler(Func<HttpRequestMessage, Task<HttpResponseMessage>> send) : HttpMessageHandler
    {
        protected override Task<HttpResponseMessage> SendAsync(HttpRequestMessage request, CancellationToken ct) => send(request);
    }
    private static HttpResponseMessage Json(object body) => new(HttpStatusCode.OK) {
        Content = new StringContent(JsonSerializer.Serialize(body), Encoding.UTF8, "application/json") };
    private static object Document(string code = "AB2CD3", string state = "pending", bool expired = false, string? desktopId = null) => new {
        fields = new { code = new { stringValue = code }, state = new { stringValue = state },
            mobileName = new { stringValue = "Android phone" }, desktopId = new { stringValue = desktopId ?? new string('a', 32) },
            connectionId = new { stringValue = "11111111-2222-4333-8444-555555555555" }, createdAt = new { timestampValue = DateTimeOffset.UtcNow.AddMinutes(expired ? -11 : -1).ToString("O") } },
        updateTime = "2026-11-09T00:00:00Z"
    };
    private static FirebasePairing Client(HttpClient http) => new(new("test-project", "test-key", "test-client"), new Session(), http, new string('a', 32));

    [Theory]
    [InlineData("123", "pending", false, "invalid")]
    [InlineData("999999", "pending", false, "rejected")]
    [InlineData("AB2CD3", "pending", true, "expired")]
    [InlineData("ZZ2ZZ3", "paired", false, "rejected")]
    public async Task InvalidCodesNeverCommit(string code, string state, bool expired, string expected)
    {
        var writes = 0;
        using var http = new HttpClient(new Handler(request => {
            if (request.Method != HttpMethod.Get) writes++;
            Assert.Equal("Bearer", request.Headers.Authorization?.Scheme);
            Assert.EndsWith("users/test-owner/pairing/current", request.RequestUri!.AbsolutePath);
            return Task.FromResult(Json(Document(state: state, expired: expired)));
        }));
        Assert.Equal(expected, (await Client(http).PairAsync(code)).State);
        Assert.Equal(0, writes);
    }
    [Fact]
    public async Task ConfirmationUsesVersionPreconditionAndServerTimestamp()
    {
        var writes = 0;
        using var http = new HttpClient(new Handler(async request => {
            if (request.Method == HttpMethod.Get) return Json(Document());
            writes++;
            using var body = JsonDocument.Parse(await request.Content!.ReadAsStringAsync());
            var write = body.RootElement.GetProperty("writes")[0];
            Assert.Equal("2026-11-09T00:00:00Z", write.GetProperty("currentDocument").GetProperty("updateTime").GetString());
            Assert.Equal("REQUEST_TIME", write.GetProperty("updateTransforms")[0].GetProperty("setToServerValue").GetString());
            Assert.Equal("paired", write.GetProperty("update").GetProperty("fields").GetProperty("state").GetProperty("stringValue").GetString());
            return new HttpResponseMessage(HttpStatusCode.Conflict);
        }));
        Assert.Equal("rejected", (await Client(http).PairAsync("AB2CD3")).State);
        Assert.Equal(1, writes);
    }
    [Fact]
    public async Task MissingAndForbiddenRequestsNeverBecomeFakeSuccess()
    {
        using var missing = new HttpClient(new Handler(_ => Task.FromResult(new HttpResponseMessage(HttpStatusCode.NotFound))));
        Assert.Equal("rejected", (await Client(missing).PairAsync("AB2CD3")).State);
        using var denied = new HttpClient(new Handler(_ => Task.FromResult(new HttpResponseMessage(HttpStatusCode.Forbidden))));
        await Assert.ThrowsAsync<InvalidOperationException>(() => Client(denied).PairAsync("AB2CD3"));
    }
    [Fact]
    public async Task SuccessfulCommitReturnsRealAssociationWithoutMockHistory()
    {
        var paired = false;
        using var http = new HttpClient(new Handler(request => {
            if (request.Method == HttpMethod.Post) { paired = true; return Task.FromResult(Json(new { })); }
            return Task.FromResult(Json(Document(state: paired ? "paired" : "pending")));
        }));
        var result = await Client(http).PairAsync("AB2CD3");
        Assert.Equal("success", result.State);
        Assert.Equal("Android phone", result.Data!.Device!.Name);
        Assert.Equal("Paired", result.Data.Device.ConnectionLabel);
        Assert.Null(result.Data.Device.LastSyncAt);
        Assert.Empty(result.Data.History);
    }
    [Fact]
    public async Task OtherDesktopDoesNotInheritThisDesktopAssociation()
    {
        using var http = new HttpClient(new Handler(_ => Task.FromResult(Json(Document(state: "paired", desktopId: new string('b', 32))))));
        Assert.Null((await Client(http).GetSyncAsync()).Device);
    }
    [Theory]
    [InlineData("ab2 - cd3", "AB2CD3", true)]
    [InlineData("ABC0DE", "ABC0DE", false)]
    [InlineData("ABO2CD", "ABO2CD", false)]
    [InlineData("ABI2CD", "ABI2CD", false)]
    public void PairingAlphabetMatchesSrs(string input, string normalized, bool valid)
    {
        Assert.Equal(normalized, PairingCodes.Normalize(input));
        Assert.Equal(valid, PairingCodes.IsValid(normalized));
    }
    [Fact]
    public async Task SuccessfulCommitNeverNeedsFollowUpRead()
    {
        var reads = 0;
        using var http = new HttpClient(new Handler(request => {
            if (request.Method == HttpMethod.Get) {
                if (++reads > 1) throw new HttpRequestException("network lost after commit");
                return Task.FromResult(Json(Document()));
            }
            return Task.FromResult(Json(new { }));
        }));
        Assert.Equal("success", (await Client(http).PairAsync("AB2CD3")).State);
        Assert.Equal(1, reads);
    }
    [Fact]
    public async Task LostCommitResponseHasUnknownStatusInsteadOfFabricatedFailure()
    {
        var reads = 0;
        using var http = new HttpClient(new Handler(request => {
            if (request.Method == HttpMethod.Get && ++reads == 1) return Task.FromResult(Json(Document()));
            throw new HttpRequestException("offline");
        }));
        Assert.Equal("PAIRING_STATUS_UNKNOWN", (await Client(http).PairAsync("AB2CD3")).ErrorCode);
    }
    [Fact]
    public async Task RetryingCompletedRequestIsIdempotent()
    {
        using var http = new HttpClient(new Handler(request => {
            Assert.Equal(HttpMethod.Get, request.Method);
            return Task.FromResult(Json(Document(state: "paired")));
        }));
        Assert.Equal("success", (await Client(http).PairAsync("AB2CD3")).State);
    }
}
