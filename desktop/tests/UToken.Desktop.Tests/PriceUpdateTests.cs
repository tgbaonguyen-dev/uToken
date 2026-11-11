using System.Net;
using System.Text;
using Xunit;

namespace UToken.Desktop.Tests;

/// <summary>Cập nhật giá trong app đi qua PricingSync nên được thử lại khi models.dev lỗi tạm thời.</summary>
public sealed class PriceUpdateTests : IDisposable
{
    private readonly RealHome _home = new();

    [Fact]
    public async Task Update_retries_a_transient_failure()
    {
        var handler = new FlakyHandler(failures: 1);
        using var api = _home.Api(priceHandler: handler);

        Assert.True(await api.UpdatePricesAsync());
        Assert.Equal(2, handler.Calls);
        var pricing = await api.GetPricingAsync(CancellationToken.None);
        Assert.Contains(pricing.Rows, row => row.Model == "gpt-test");
    }

    [Fact]
    public async Task Update_gives_up_after_three_attempts_and_keeps_old_prices()
    {
        var handler = new FlakyHandler(failures: 5);
        using var api = _home.Api(priceHandler: handler);

        Assert.False(await api.UpdatePricesAsync());
        Assert.Equal(3, handler.Calls);
    }

    [Fact]
    public async Task Update_without_retry_tries_once()
    {
        var handler = new FlakyHandler(failures: 1);
        using var api = _home.Api(priceHandler: handler);

        Assert.False(await api.UpdatePricesAsync(retry: false));
        Assert.Equal(1, handler.Calls);
    }

    [Fact]
    public async Task Client_errors_are_not_retried()
    {
        var handler = new FlakyHandler(failures: 5, status: HttpStatusCode.NotFound);
        using var api = _home.Api(priceHandler: handler);

        Assert.False(await api.UpdatePricesAsync());
        Assert.Equal(1, handler.Calls);
    }

    public void Dispose() => _home.Dispose();

    private sealed class FlakyHandler(int failures, HttpStatusCode status = HttpStatusCode.ServiceUnavailable) : HttpMessageHandler
    {
        public int Calls { get; private set; }

        protected override Task<HttpResponseMessage> SendAsync(HttpRequestMessage request, CancellationToken ct)
        {
            Calls++;
            if (Calls <= failures) return Task.FromResult(new HttpResponseMessage(status));
            const string body = """{ "openai": { "models": { "gpt-test": { "cost": { "input": 1, "output": 2 } } } } }""";
            return Task.FromResult(new HttpResponseMessage(HttpStatusCode.OK)
            {
                Content = new StringContent(body, Encoding.UTF8, "application/json"),
            });
        }
    }
}
