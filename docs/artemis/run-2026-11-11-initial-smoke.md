# Initial Artemis smoke run — 2026-11-11

Result: **BLOCKED by automation provider**, not an application test failure.

- Workspace commit: `9f92415`.
- Device: Pixel_10, `emulator-5554`, Android 17.
- Mode: Artemis Flash, read-only navigation and Tokens period filters.
- Trace: `7bb37ee1-c7f6-46bb-a86c-1bf07a19dc0b`.
- Target: preexisting installed `com.utoken_mobile`; its build provenance was not verified against this commit.
- Fresh UI preview APK built successfully from this workspace using `flutter build apk --debug -t lib/main_ui_preview.dart`; it was not installed during the running task.
- Device hierarchy observation succeeded. Accessibility helper was provisioned and subsequently reachable.
- Run failed with `TimeoutError: LLM call timed out after 180 seconds`.
- Diagnosis verified the Gemini credential, and logs reported provider HTTP 504 and repeated HTTP 503 high-demand errors.
- Trace inspection returned no recorded action steps. No navigation/filter checkpoint is counted as PASS; agent turn counters do not establish successful interactions.
- No settings changes, sync, sign-out, data deletion or application AI review was requested.

Local raw evidence directory:
`D:\IntelliJProjects\artemis\traces\7bb37ee1-c7f6-46bb-a86c-1bf07a19dc0b`

Raw logs remain outside this repository; review/redact account information before exporting artifacts. Retry after provider recovery or after configuring another available model and reloading Artemis. Test the fresh preview APK separately from production Firebase flows.

## Retry with the running web daemon

- Trace: `928c385f-5b74-4a50-81bd-60a19885fcd3`.
- Environment diagnosis: ready, daemon on port 8000 reachable, only emulator-5554 attached.
- Narrowed case to Tokens -> Analytics -> Tokens on the existing APK, without data-changing actions.
- Provider again returned HTTP 503 high demand and HTTP 504. A stop was requested to avoid repeated API retries, but the task had already reached failed status. No further run was started.
- Trace summary exposed no recorded action steps. Agent reported turns but these are not proof of executed UI actions. Result remains **BLOCKED**, with zero verified PASS checkpoints.
- Daemon mode did not create the advertised per-task stderr.log; provider errors were observed in the task stdout.log and MCP diagnosis logs instead.

## Retry after user reported replacing the API key

- Trace: `d84bef94-fe2e-46b7-867d-d3cd5adfedeb`.
- Live credential verification succeeded for the credential loaded by MCP; this does not prove a previously running daemon reloaded the changed file.
- Same short read-only Analytics -> Tokens case, existing installed APK.
- Task stdout again reported provider HTTP 503 high demand. Trace summary returned no recorded actions; no UI checkpoint is counted as PASS.
- Requested task cancellation rather than leaving provider retries running. Result: **BLOCKED by provider**.
