using System.Net;
using System.Net.Http.Headers;
using System.Net.Http.Json;
using System.Text.Json;
using UToken.Desktop.App.Models;

namespace UToken.Desktop.App.Services;

public static class PairingCodes
{
    public const string Alphabet = "ABCDEFGHJKLMNPQRSTUVWXYZ23456789";
    public static string Normalize(string code) => string.Concat(code.ToUpperInvariant().Where(c => !char.IsWhiteSpace(c) && c != '-' && c != '\u2014'));
    public static bool IsValid(string code) => code.Length == 6 && code.All(Alphabet.Contains);
}

public sealed class FirebasePairing(DesktopFirebaseConfig config, IFirebaseSession auth, HttpClient http, string? desktopId = null)
{
    private readonly string _desktopId = desktopId ?? LoadDesktopId();
    private DateTimeOffset _serverNow;
    private static string LoadDesktopId()
    {
        Directory.CreateDirectory(LocalSettingsStore.DefaultDirectory);
        var path = Path.Combine(LocalSettingsStore.DefaultDirectory, "desktop-id.txt");
        if (File.Exists(path) && Guid.TryParse(File.ReadAllText(path), out var existing)) return existing.ToString("N");
        var id = Guid.NewGuid().ToString("N"); File.WriteAllText(path, id); return id;
    }
    private string BaseName => $"projects/{config.ProjectId}/databases/(default)/documents";
    private string DocumentName => $"{BaseName}/users/{auth.Uid}/pairing/current";
    private string ConnectionName(string id) => $"{BaseName}/users/{auth.Uid}/connections/{id}";
    private async Task<HttpResponseMessage> SendAsync(HttpMethod method, string suffix, object? body, CancellationToken ct)
    {
        var token = await auth.TokenAsync(ct);
        using var request = new HttpRequestMessage(method, "https://firestore.googleapis.com/v1/" + suffix);
        request.Headers.Authorization = new AuthenticationHeaderValue("Bearer", token);
        if (body is not null) request.Content = JsonContent.Create(body);
        var response = await http.SendAsync(request, ct);
        if (response.StatusCode == HttpStatusCode.Unauthorized) {
            response.Dispose(); auth.InvalidateIdToken(token); throw new FirebaseSessionExpiredException();
        }
        return response;
    }
    private async Task<JsonDocument?> ReadAsync(CancellationToken ct)
    {
        await auth.TokenAsync(ct);
        using var response = await SendAsync(HttpMethod.Get, DocumentName, null, ct);
        if (response.StatusCode == HttpStatusCode.NotFound) return null;
        if (response.StatusCode == HttpStatusCode.Forbidden)
            throw new InvalidOperationException("RESOURCE_NOT_FOUND: Pairing access was denied. Check the published rules and Google account.");
        response.EnsureSuccessStatusCode();
        _serverNow = response.Headers.Date ?? DateTimeOffset.UtcNow;
        return JsonDocument.Parse(await response.Content.ReadAsStringAsync(ct));
    }
    public async Task<SyncData> GetSyncAsync(CancellationToken ct = default)
    {
        try { await auth.TokenAsync(ct); }
        catch (FirebaseSessionExpiredException) { throw; }
        catch (InvalidOperationException) { return Empty(null); }
        using var document = await ReadAsync(ct);
        if (document is null) return Empty(null);
        var fields = document.RootElement.GetProperty("fields");
        return IsOurs(fields) ? Connected(fields) : Empty(null);
    }
    private bool IsOurs(JsonElement fields) => Text(fields, "state") == "paired" && Text(fields, "desktopId") == _desktopId;
    private static string Text(JsonElement fields, string name) => fields.GetProperty(name).GetProperty("stringValue").GetString()!;
    private static SyncData Connected(JsonElement fields) => Empty(new MobileDevice(Text(fields, "mobileName"), "Android",
        "Paired; usage sync not enabled", "A", false, null, 0, DateTimeOffset.UtcNow, PairingOnly: true));
    private static SyncData Empty(MobileDevice? device) => new(device, "Pairing over TLS + Firebase",
        "Device association is saved to your Google account. Usage synchronization is not enabled.",
        [new("Usage sync", "Not enabled"), new("Prompt content", "Not uploaded", "#2EC790")], [],
        new("no_new_usage", "Usage synchronization is not implemented yet.", 0, 0), DateTimeOffset.UtcNow);
    private static PairingResult Failure(string state, string code, string message) => new(state, $"{code}: {message}", ErrorCode: code);
    private static PairingResult Success(JsonElement fields) => new("success", "Mobile device paired. Waiting for first usage; usage sync is not enabled yet.", Connected(fields));

    public async Task<PairingResult> PairAsync(string code, CancellationToken ct = default)
    {
        code = PairingCodes.Normalize(code);
        if (!PairingCodes.IsValid(code)) return Failure("invalid", "PAIRING_INVALID", "Enter six letters/digits from the phone, excluding 0, O, 1 and I.");
        using var document = await ReadAsync(ct);
        if (document is null) return Failure("rejected", "PAIRING_NOT_FOUND", "No pending request for this account. Use the same Google account on both devices and generate a new code. A code from another account cannot be looked up.");
        var root = document.RootElement;
        var fields = root.GetProperty("fields");
        if (Text(fields, "state") == "paired") {
            if (IsOurs(fields) && Text(fields, "code") == code) return Success(fields);
            return Failure("rejected", "PAIRING_USED", "A desktop is already connected. Disconnect it on the phone before pairing again.");
        }
        if (Text(fields, "state") != "pending") return Failure("rejected", "PAIRING_INVALID", "This request was cancelled or revoked. Generate a new code.");
        if (Text(fields, "code") != code) return Failure("rejected", "PAIRING_INVALID", "The code does not match this account's request. Check both the code and Google account.");
        if (DateTimeOffset.Parse(fields.GetProperty("createdAt").GetProperty("timestampValue").GetString()!).AddMinutes(10) <= _serverNow)
            return Failure("expired", "PAIRING_EXPIRED", "The code expired. Generate a new code on your phone.");
        var id = Text(fields, "connectionId");
        var confirmed = CopyFields(fields);
        confirmed["state"] = new { stringValue = "paired" };
        confirmed["desktopName"] = new { stringValue = Environment.MachineName };
        confirmed["desktopId"] = new { stringValue = _desktopId };
        var transforms = new[] { new { fieldPath = "pairedAt", setToServerValue = "REQUEST_TIME" } };
        var writes = new object[] {
            new { update = new { name = DocumentName, fields = confirmed }, updateTransforms = transforms,
                currentDocument = new { updateTime = root.GetProperty("updateTime").GetString() } },
            new { update = new { name = ConnectionName(id), fields = confirmed }, updateTransforms = transforms,
                currentDocument = new { exists = false } }
        };
        try {
            using var response = await SendAsync(HttpMethod.Post, BaseName + ":commit", new { writes }, ct);
            if (!response.IsSuccessStatusCode) {
                if (response.StatusCode is HttpStatusCode.Conflict or HttpStatusCode.BadRequest or HttpStatusCode.Forbidden) {
                    using var latest = await ReadAsync(ct);
                    if (latest is not null && IsOurs(latest.RootElement.GetProperty("fields")) && Text(latest.RootElement.GetProperty("fields"), "connectionId") == id)
                        return Success(latest.RootElement.GetProperty("fields"));
                    return Failure("rejected", "PAIRING_CHANGED", "The request changed, expired or was denied. Generate a new code and retry.");
                }
                response.EnsureSuccessStatusCode();
            }
            // A successful commit is authoritative; don't turn it into failure on a follow-up GET.
            using var result = JsonDocument.Parse(JsonSerializer.Serialize(confirmed));
            return Success(result.RootElement);
        }
        catch (Exception ex) when (ex is HttpRequestException || ex is OperationCanceledException && !ct.IsCancellationRequested) {
            try {
                using var latest = await ReadAsync(ct);
                if (latest is not null && IsOurs(latest.RootElement.GetProperty("fields")) && Text(latest.RootElement.GetProperty("fields"), "connectionId") == id)
                    return Success(latest.RootElement.GetProperty("fields"));
            } catch (HttpRequestException) { } catch (OperationCanceledException) when (!ct.IsCancellationRequested) { }
            return Failure("unknown", "PAIRING_STATUS_UNKNOWN", "Confirmation may have completed. Refresh the connection before retrying; no failure has been assumed.");
        }
    }
    private static Dictionary<string, object> CopyFields(JsonElement fields) => fields.EnumerateObject().ToDictionary(p => p.Name, p => (object)p.Value.Clone());
    public async Task<SyncData> DisconnectAsync(CancellationToken ct = default)
    {
        using var document = await ReadAsync(ct);
        if (document is null) return Empty(null);
        var root = document.RootElement;
        var fields = root.GetProperty("fields");
        if (Text(fields, "state") != "paired") return Empty(null);
        var revoked = CopyFields(fields);
        revoked["state"] = new { stringValue = "revoked" };
        var transforms = new[] { new { fieldPath = "revokedAt", setToServerValue = "REQUEST_TIME" } };
        var writes = new object[] {
            new { update = new { name = DocumentName, fields = revoked }, updateTransforms = transforms,
                currentDocument = new { updateTime = root.GetProperty("updateTime").GetString() } },
            new { update = new { name = ConnectionName(Text(fields, "connectionId")), fields = revoked }, updateTransforms = transforms,
                currentDocument = new { exists = true } }
        };
        using var response = await SendAsync(HttpMethod.Post, BaseName + ":commit", new { writes }, ct);
        response.EnsureSuccessStatusCode();
        return Empty(null);
    }
}
