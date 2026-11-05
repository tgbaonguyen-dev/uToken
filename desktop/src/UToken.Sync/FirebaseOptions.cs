namespace UToken.Sync;

/// <summary>Đọc từ firebase.desktop.json (không commit). Xem docs/setup.md.</summary>
public sealed record FirebaseOptions(string ProjectId, string ApiKey, string OAuthClientId);
