using System.Net;
using System.Net.Http.Headers;
using System.Text;
using UToken.Sync.Auth;

namespace UToken.Sync;

/// <summary>
/// Gọi Firestore REST với Firebase ID token của người dùng để Security Rules được áp dụng (ADR-0003).
/// </summary>
public sealed class FirestoreRestClient(HttpClient http, FirebaseOptions options, Func<CancellationToken, Task<string>> getIdToken)
{
    // Emulator hay project thật do appsettings quyết định (Firebase:UseEmulator).
    private string DocumentsBase => options.FirestoreBaseUrl;

    /// <summary>
    /// Ghi nhiều document trong một lần commit. <paramref name="commitBodyJson"/> theo định dạng Firestore REST "writes".
    /// 401 → <see cref="CloudAuthException"/> (cần đăng nhập lại); lỗi khác → <see cref="HttpRequestException"/> kèm mã lỗi.
    /// </summary>
    public async Task CommitAsync(string commitBodyJson, CancellationToken ct)
    {
        using var req = new HttpRequestMessage(HttpMethod.Post, $"{DocumentsBase}:commit")
        {
            Content = new StringContent(commitBodyJson, Encoding.UTF8, "application/json"),
        };
        req.Headers.Authorization = new AuthenticationHeaderValue("Bearer", await getIdToken(ct));
        using var res = await http.SendAsync(req, ct);
        if (res.IsSuccessStatusCode) return;
        if (res.StatusCode == HttpStatusCode.Unauthorized)
            throw new CloudAuthException("Firestore rejected the session (401).");
        var detail = res.StatusCode == HttpStatusCode.Forbidden ? "permission denied by Security Rules" : res.StatusCode.ToString();
        throw new HttpRequestException($"Firestore commit failed: {detail}", null, res.StatusCode);
    }

    // TODO(ADR-0003): ListPendingSyncRequestsAsync — poll hoặc gRPC Listen sau khi có kết quả spike.
}
