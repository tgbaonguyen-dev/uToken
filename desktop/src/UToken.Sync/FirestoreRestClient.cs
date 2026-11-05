using System.Net.Http.Headers;
using System.Text;

namespace UToken.Sync;

/// <summary>
/// Gọi Firestore REST với Firebase ID token của người dùng để Security Rules được áp dụng (ADR-0003).
/// </summary>
public sealed class FirestoreRestClient(HttpClient http, FirebaseOptions options, Func<CancellationToken, Task<string>> getIdToken)
{
    private string DocumentsBase =>
        $"https://firestore.googleapis.com/v1/projects/{options.ProjectId}/databases/(default)/documents";

    /// <summary>Ghi nhiều document trong một lần commit. <paramref name="commitBodyJson"/> theo định dạng Firestore REST "writes".</summary>
    public async Task CommitAsync(string commitBodyJson, CancellationToken ct)
    {
        using var req = new HttpRequestMessage(HttpMethod.Post, $"{DocumentsBase}:commit")
        {
            Content = new StringContent(commitBodyJson, Encoding.UTF8, "application/json"),
        };
        req.Headers.Authorization = new AuthenticationHeaderValue("Bearer", await getIdToken(ct));
        using var res = await http.SendAsync(req, ct);
        res.EnsureSuccessStatusCode();
    }

    // TODO(ADR-0003): ListPendingSyncRequestsAsync — poll hoặc gRPC Listen sau khi có kết quả spike.
}
