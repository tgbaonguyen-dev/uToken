# Login / pairing: production verification

Project: `utoken-78191`. Scope: Android + Windows pairing; no usage sync.
The automated checks recorded in `../PAIRING.md` are local checks, not proof of
production deployment. Every real-client case below is currently **NOT RUN**.

Local verification on 2026-11-09: 25 selected desktop auth/pairing/first-run tests
passed, including new-instance restoration from a rotated encrypted refresh token,
offline retry preserving that token, sign-out preventing restoration, and corrupt
DPAPI file recovery. The 17 mobile auth/recovery/pairing tests also passed.
Desktop DPAPI tests require the normal Windows user context; they failed inside
the restricted sandbox and passed when rerun outside it. Test credentials were
synthetic; no real user's session was modified. ADB reported no connected devices,
so Android process-exit/relaunch and real two-client checks remain NOT RUN.

## Deploy safely

From `firebase/`:

```powershell
.\node_modules\.bin\firebase.cmd login
.\node_modules\.bin\firebase.cmd projects:list
```

In Firebase Console, open the project's Firestore Rules and save the currently
published rules and publication time before changing them. Compare them with
`firebase/firestore.rules`. Preserve unrelated production rules. Include both
`pairing` and `connections` blocks, their helper functions, and their exclusions
from the owner catch-all; a permissive overlapping match can bypass validation.

Only after reconciling that comparison, deploy rules (not indexes or other services):

```powershell
.\node_modules\.bin\firebase.cmd deploy --only firestore:rules --project utoken-78191
```

Record the deployment result and publication time. Both clients must use version 2;
generate a fresh code instead of reusing a version 1 request.

## Real-client acceptance record

Use test accounts. Do not include tokens, passwords or raw session files in evidence.
Record app versions, device names, time, expected/actual result and screenshots
with personal details redacted. Check server documents in Firestore Console.

| Case | Expected result | Status |
| --- | --- | --- |
| Sign in on Android and Windows | Same account; no rejected state after completed Firebase sign-in | NOT RUN |
| Fully quit and reopen both apps | Session restores without another Google prompt while valid | NOT RUN |
| Pair a fresh mobile code | Mobile opens waiting-for-usage; Windows shows connection; current and history agree | NOT RUN |
| Repeat confirmation on the same desktop | Same connection UUID, no duplicate history | NOT RUN |
| Invalid or different code | Clear error; existing connection unchanged | NOT RUN |
| Different Google accounts | No connection; same-account guidance; no cross-account data access | NOT RUN |
| Wait more than ten minutes | Confirmation denied; a new code can be generated | NOT RUN |
| Cancel pending pairing | Old request cannot be confirmed | NOT RUN |
| Another desktop confirms a consumed code | Rejected; original association unchanged | NOT RUN |
| Disconnect from mobile | Current and history revoked; desktop updates on Sync/Pairing with network | NOT RUN |
| Disconnect from desktop | Current and history revoked; mobile shows disconnection | NOT RUN |
| Re-pair after revocation | New UUID; revoked history retained | NOT RUN |
| Lose network during confirmation | Recoverable unavailable/unknown result; retry reconciles server state | NOT RUN |
| Revoke/disable an authenticated test session | Sign-in recovery; no stale account data presented as current | NOT RUN |
| View demo while signed out | DEMO label; no pairing documents created or updated | NOT RUN |

For revocation timing, keep Windows Sync/Pairing visible and both clients online.
Measure from the server-confirmed revocation to the other client's visible update;
record the actual duration. The four-second polling interval alone does not prove
a five-second guarantee. Upload shutdown is outside this pairing-only scope.

## Decisions still required from the team

- SRS `ACCOUNT_MISMATCH`: own-UID lookup cannot distinguish another account's code
  from an absent request. Current behavior gives same-account guidance. A distinct
  verified error would require an approved discovery design and security review.
- Confirm the documented v2 schema/field naming and pairing-only delivery against
  the SRS baseline; update the team's source document through its change process.
- No DOCX was found in this repository. The original SRS PDF is unchanged.
- Decide whether any real version 1 associations need migration before removing
  legacy records; the current implementation does not import or delete them.
