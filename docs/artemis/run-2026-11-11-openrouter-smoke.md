# OpenRouter UI preview smoke — 2026-11-11

Historical run description. The canonical NAV-01 evidence now uses the latest successful trace, 30f96a78-69ac-4c2c-9c90-4eeafe7f7a91, in [01-preview-navigation](runs/2026-11-11/01-preview-navigation/case.md). Earlier duplicate run folders were removed at user request; see [run history](run-history.md).

Result: **PASS for this navigation case only**.

- Device: Pixel_10 / emulator-5554, Android 17.
- APK: debug UI preview built from workspace commit 9f92415 with lib/main_ui_preview.dart, installed using adb install -r.
- Model: openrouter / nvidia/nemotron-3.5-super-vl:free.
- Trace: 034ece09-4064-48c7-96d6-8bb08fc5439d.
- Duration reported by Artemis: 92.9 seconds.
- Source: mobile_inspect_trace(view_summary), task stdout and final independent device hierarchy observation.

## Observed actions and checks

1. Welcome showed View demo; click target 13 entered the mock Tokens dashboard.
2. Click target 43 opened Analytics. Next observation identified Analytics title and Token mix, models, and cost subtitle.
3. Click target 40 returned to Tokens. Next observation identified Tokens title.
4. Agent reported completed. Independent hierarchy read after completion showed Tokens, mock 6,830,736 tokens and $42.18 estimated.

Agent used UI hierarchy IDs. Three UI clicks and one report action were recorded. No login, sync, application AI review, settings change or deletion was requested.

## Configuration and evidence limits

- Original Artemis config backed up locally as config/artemis.before-openrouter-free.jsonc.
- All configured provider/model entries and fallbacks switched to the OpenRouter free endpoint. Optional Flash step summarizer disabled: it otherwise incorrectly instantiated a Google client for this model. No Artemis source code was changed.
- Earlier OpenRouter trace 02a3d679-7dd8-4e5c-a33f-f537b8ec9199 failed during that Google-client initialization, before UI testing.
- Successful run usage log reports all four model calls routed to openrouter:nvidia/nemotron-3.5-super-vl:free. Actual billed cost must be checked in OpenRouter Activity; no billing dashboard was inspected here.
- Raw task stdout: D:\IntelliJProjects\artemis\traces\034ece09-4064-48c7-96d6-8bb08fc5439d\stdout.log.
- Trace compiler logged zero images/steps in its separate recording folder even though MCP trace inspection returned four records. Export completeness still needs fixing; do not rely on an empty steps.json export.
- This is UI preview navigation, not verification of Firebase login, real data, persistence, filters, all states, or production behavior.
