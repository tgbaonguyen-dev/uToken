namespace UToken.Sync;

/// <summary>
/// Cấu hình Firebase cho desktop. Đọc từ appsettings.json (commit, không bí mật)
/// rồi ghi đè bằng appsettings.Local.json (không commit) và biến môi trường UTOKEN_*.
/// </summary>
public sealed class FirebaseOptions
{
    public string ProjectId { get; init; } = "";
    public string ApiKey { get; init; } = "";
    public string OAuthClientId { get; init; } = "";
    public string OAuthClientSecret { get; init; } = "";

    /// <summary>true: gọi emulator trên máy, không đụng project thật.</summary>
    public bool UseEmulator { get; init; } = true;
    public string FirestoreEmulatorHost { get; init; } = "127.0.0.1:8080";
    public string AuthEmulatorHost { get; init; } = "127.0.0.1:9099";

    public string FirestoreBaseUrl => UseEmulator
        ? $"http://{FirestoreEmulatorHost}/v1/projects/{ProjectId}/databases/(default)/documents"
        : $"https://firestore.googleapis.com/v1/projects/{ProjectId}/databases/(default)/documents";

    public string IdentityToolkitBaseUrl => UseEmulator
        ? $"http://{AuthEmulatorHost}/identitytoolkit.googleapis.com/v1"
        : "https://identitytoolkit.googleapis.com/v1";

    public string SecureTokenBaseUrl => UseEmulator
        ? $"http://{AuthEmulatorHost}/securetoken.googleapis.com/v1"
        : "https://securetoken.googleapis.com/v1";

    // Separate credentials for each project and emulator/production environment.
    public string SessionKey => Convert.ToHexString(System.Security.Cryptography.SHA256.HashData(
        System.Text.Encoding.UTF8.GetBytes($"{ProjectId}|{(UseEmulator ? AuthEmulatorHost : "production")}")));

    public IReadOnlyList<string> ValidateGoogleSignIn()
    {
        var errors = Validate().ToList();
        if (IsPlaceholder(OAuthClientId)) errors.Add("Firebase:OAuthClientId chưa điền");
        if (IsPlaceholder(OAuthClientSecret)) errors.Add("Firebase:OAuthClientSecret chưa điền");
        return errors.Distinct().ToArray();
    }

    /// <summary>Thiếu giá trị bắt buộc thì trả danh sách lỗi để báo người dùng.</summary>
    public IReadOnlyList<string> Validate()
    {
        var errors = new List<string>();
        if (string.IsNullOrWhiteSpace(ProjectId)) errors.Add("Firebase:ProjectId trống");
        if (!UseEmulator)
        {
            if (IsPlaceholder(ApiKey)) errors.Add("Firebase:ApiKey chưa điền (appsettings.Local.json)");
            if (IsPlaceholder(OAuthClientId)) errors.Add("Firebase:OAuthClientId chưa điền");
            if (IsPlaceholder(OAuthClientSecret)) errors.Add("Firebase:OAuthClientSecret chưa điền");
        }
        return errors;
    }

    private static bool IsPlaceholder(string v) =>
        string.IsNullOrWhiteSpace(v) || v.StartsWith("your-") || v.StartsWith("DAN_");
}
