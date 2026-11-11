# Firebase test tooling

This folder contains CLI/emulator/rules tests, not the desktop or Android runtime.
Use Node >=24.12.0 for the current Firebase SDK engine requirement. The local
24.11.0 installation can emit engine warnings; installing an appropriate Node
version is a machine prerequisite, not a source-code patch.

```powershell
npm ci
npm test
npm audit
```

Tests use `demo-utoken`, synthetic accounts and Firestore Emulator. The collector
REST precondition test uses the emulator admin credential to verify atomic claim
semantics; it does not test production Rules or authorize production writes.

The gRPC override stays in major 1. Additional overrides select patched glob,
PubSub and gaxios's uuid dependency instead of downgrading Firebase CLI. The glob
and PubSub overrides cross upstream major ranges; remove them when Firebase CLI
accepts fixed versions itself. They apply to development tooling, not the APK or
.NET runtime.

`tests/tooling-compat.test.js` checks the CLI's glob APIs (including cancellation),
ZIP file expansion, gaxios multipart construction and PubSub client construction/
close. The Firestore emulator suite must also pass. These checks do not certify
production Functions/PubSub/Hosting deployment workflows, which this project does
not exercise. Never deploy merely to verify an override.

The follow-up audit on 2026-11-11 reports zero vulnerabilities. This is a dated
registry snapshot, not a guarantee that every dependency is free of defects.
