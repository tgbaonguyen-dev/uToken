using UToken.Storage;
using Xunit;

namespace UToken.Storage.Tests;

public class RetentionTests
{
    [Fact]
    public void Pending_daily_survives_retention_until_acknowledged()
    {
        using var store = new SqliteStore(":memory:");
        store.SaveDailyLocal("2026-10-01", "{\"input\":100}", "2026-10-01T12:00:00Z");
        store.SaveDailyLocal("2026-10-02", "{\"input\":200}", "2026-10-02T12:00:00Z");
        store.MarkDailySynced("2026-10-02");
        store.PruneBefore(DateTimeOffset.Parse("2026-11-01T12:00:00Z"));
        Assert.Equal("2026-10-01", Assert.Single(store.GetDirtyDaily()).Date);
        Assert.Single(store.GetDailyJsonSince("2026-01-01"));
        store.MarkDailySynced("2026-10-01");
        store.PruneBefore(DateTimeOffset.Parse("2026-11-01T12:00:00Z"));
        Assert.Empty(store.GetDailyJsonSince("2026-01-01"));
    }

    [Fact]
    public void Retention_uses_the_local_calendar_day()
    {
        using var store = new SqliteStore(":memory:");
        store.SaveDailyLocal("2026-11-01", "{}", "2026-11-01T00:00:00Z");
        store.MarkDailySynced("2026-11-01");
        var zone = TimeZoneInfo.CreateCustomTimeZone("test+7", TimeSpan.FromHours(7), "test", "test");
        store.PruneBefore(DateTimeOffset.Parse("2026-11-01T18:00:00Z"), zone);
        Assert.Empty(store.GetDailyJsonSince("2026-01-01"));
    }
}
