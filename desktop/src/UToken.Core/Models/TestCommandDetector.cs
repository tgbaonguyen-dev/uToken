using System.Text.RegularExpressions;

namespace UToken.Core.Models;

/// <summary>
/// Nhận diện lệnh test/build từ tên lệnh, chạy hoàn toàn trên máy (FR-ANLY-003 mục B, OQ-11).
/// Chuỗi lệnh chỉ được dùng trong bộ nhớ để trả về đúng/sai; không lưu, không upload.
/// </summary>
public static partial class TestCommandDetector
{
    // Danh sách giả định, cần nhóm duyệt (OQ-03 điểm 2).
    [GeneratedRegex(
        @"(^|[\s;&|(/""'])(" +
        @"pytest|py\.test|tox|nox|jest|vitest|mocha|karma|phpunit|rspec|ctest|playwright\s+test|" +
        @"python3?\s+-m\s+(pytest|unittest)|" +
        @"(npm|pnpm|yarn|bun)\s+(run\s+)?(test|build|typecheck|lint)\b|" +
        @"flutter\s+(test|build|analyze)|dart\s+(test|analyze)|" +
        @"cargo\s+(test|build|check|nextest)|dotnet\s+(test|build)|go\s+(test|build|vet)|" +
        @"mvnw?\s|gradlew?\s+\S*(test|build|check)|" +
        @"make(\s+(test|check|build|all))?\s*($|[;&|])|tsc(\s|$)" +
        @")",
        RegexOptions.IgnoreCase | RegexOptions.CultureInvariant)]
    private static partial Regex Pattern();

    public static bool IsTestOrBuild(string? command) =>
        !string.IsNullOrWhiteSpace(command) && Pattern().IsMatch(command);
}
