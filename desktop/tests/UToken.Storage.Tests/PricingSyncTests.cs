using System.Net;
using System.Text;
using UToken.Storage;
using Xunit;

namespace UToken.Storage.Tests;

public class PricingSyncTests
{
    private const string Catalog = """
        { "openai": { "models": { "gpt-test": { "cost": { "input": 1, "output": 2 } } } } }
        """;

    [Fact]
    public void VersionFor_preserves_subsecond_precision()
    {
        var first = new DateTimeOffset(2026, 11, 7, 8, 30, 15, 100, TimeSpan.FromHours(7));
        var second = first.AddMilliseconds(800);

        Assert.NotEqual(PricingSync.VersionFor(first), PricingSync.VersionFor(second));
    }

    [Fact]
    public async Task RunAsync_retries_twice_then_succeeds()
    {
        var handler = new SequenceHandler([
            new ResponseSpec(HttpStatusCode.ServiceUnavailable, "first"),
            new ResponseSpec(HttpStatusCode.ServiceUnavailable, "second"),
            new ResponseSpec(HttpStatusCode.OK, Catalog),
        ]);
        using var http = new HttpClient(handler);
        using var store = new SqliteStore(":memory:");
        var delays = new List<TimeSpan>();

        var written = await PricingSync.RunAsync(http, store, DateTimeOffset.UnixEpoch, CancellationToken.None, Delay);

        Assert.Equal(1, written);
        Assert.Equal(3, handler.Calls);
        Assert.Equal([TimeSpan.FromSeconds(1), TimeSpan.FromSeconds(3)], delays);
        return;

        Task Delay(TimeSpan duration, CancellationToken ct)
        {
            ct.ThrowIfCancellationRequested();
            delays.Add(duration);
            return Task.CompletedTask;
        }
    }

    [Fact]
    public async Task RunAsync_throws_last_http_error_after_three_attempts()
    {
        var handler = new SequenceHandler([
            new ResponseSpec(HttpStatusCode.ServiceUnavailable, "first"),
            new ResponseSpec(HttpStatusCode.ServiceUnavailable, "second"),
            new ResponseSpec(HttpStatusCode.ServiceUnavailable, "third"),
        ]);
        using var http = new HttpClient(handler);
        using var store = new SqliteStore(":memory:");

        await Assert.ThrowsAsync<HttpRequestException>(() =>
            PricingSync.RunAsync(http, store, DateTimeOffset.UnixEpoch, CancellationToken.None, NoDelay));
        Assert.Equal(3, handler.Calls);
    }

    [Fact]
    public async Task RunAsync_rejects_an_empty_catalog()
    {
        var handler = new SequenceHandler([new ResponseSpec(HttpStatusCode.OK, "{}")]);
        using var http = new HttpClient(handler);
        using var store = new SqliteStore(":memory:");

        var error = await Assert.ThrowsAsync<InvalidDataException>(() =>
            PricingSync.RunAsync(http, store, DateTimeOffset.UnixEpoch, CancellationToken.None, NoDelay));
        Assert.Equal("models.dev trả về bảng giá rỗng", error.Message);
        Assert.Equal(1, handler.Calls);
    }

    private static Task NoDelay(TimeSpan duration, CancellationToken ct)
    {
        ct.ThrowIfCancellationRequested();
        return Task.CompletedTask;
    }

    private sealed record ResponseSpec(HttpStatusCode StatusCode, string Body);

    private sealed class SequenceHandler : HttpMessageHandler
    {
        private readonly ResponseSpec[] _responses;

        public SequenceHandler(IReadOnlyList<ResponseSpec> responses) => _responses = responses.ToArray();

        public int Calls { get; private set; }

        protected override Task<HttpResponseMessage> SendAsync(HttpRequestMessage request, CancellationToken ct)
        {
            ct.ThrowIfCancellationRequested();
            if (Calls >= _responses.Length)
                throw new InvalidOperationException($"Không còn phản hồi giả lập cho request {request.RequestUri}.");

            var spec = _responses[Calls++];
            var response = new HttpResponseMessage(spec.StatusCode)
            {
                Content = new StringContent(spec.Body, Encoding.UTF8, "application/json"),
                RequestMessage = request,
            };
            return Task.FromResult(response);
        }
    }
}
