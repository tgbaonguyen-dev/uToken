namespace UToken.Sync.Auth;

public sealed record AuthUser(string Uid, string? Email, string? DisplayName);

// Tokens deliberately have no generated ToString() representation.
public sealed class StoredSession
{
    public string Uid { get; init; } = "";
    public string RefreshToken { get; init; } = "";
    public string? Email { get; init; }
    public string? DisplayName { get; init; }
}

public interface IRefreshTokenStore
{
    Task<StoredSession?> LoadAsync(CancellationToken ct);
    Task SaveAsync(StoredSession session, CancellationToken ct);
    Task ClearAsync(CancellationToken ct);
}

public interface IGoogleOAuthClient
{
    Task<string> GetIdTokenAsync(CancellationToken ct);
}

public sealed class AuthException(string code, string message) : Exception(message)
{
    public string Code { get; } = code;
    public bool IsSessionExpired => Code == "AUTH_INVALID";
}

public interface IAuthService
{
    AuthUser? CurrentUser { get; }
    event EventHandler? UserChanged;
    Task RestoreSessionAsync(CancellationToken ct = default);
    Task SignInWithGoogleAsync(CancellationToken ct = default);
    Task<string> GetIdTokenAsync(CancellationToken ct = default);
    Task SignOutAsync(CancellationToken ct = default);
}
