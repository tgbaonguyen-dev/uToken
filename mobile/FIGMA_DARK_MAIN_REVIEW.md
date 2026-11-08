# M01-M13 Dark UI review

Reviewed against live Figma on 2026-11-08: Final UI Dark, file `ULjJf6asJEKslR4Y4yT4QI`, page `1:4`.

Scope: 16 main frames: M01-M13 plus M04B, M05B and M05C. Design contexts and reference renders were retrieved for every frame. The previous 23 reviewed M01-M04 states remain in place; the later 51 states were not reworked in this main-screen review.

## Changes

| Frames | Findings and changes |
| --- | --- |
| M01-M03 | Existing main layouts agree with the reference; login/pair/install preview navigation retained. |
| M04 | Restored the reference summary formatting (2.0M / 6.8M) and green/pink chart caps from mock series. Filters remain functional. |
| M04B | Model totals use consistent M units, and default activity/top-model presentation follows the reference again. Model totals still come from the shared selected-period fixtures. |
| M05 | Restored blue/orange cost bars and the reference bar spacing/width. The cost card deliberately describes the selected period instead of showing a fixed unrelated 7-day value. |
| M05B | Restored the default 30-day subtitle, monthly comparison copy and multiplication symbol. Other period choices remain dynamic. |
| M05C | Fixed the wrapped best-task label, kept ranking identities/colors together and restored source copy for task ranges and rework evidence. |
| M06 | Reference layout retained; the added sortable headers and Daily/Project interaction are intentional. |
| M07 | Restored middle-dot separators; dynamic recommendation source/savings are read from mock data. |
| M08 | Replaced the hard-coded widget contents with repository-loaded data and source-matched Dark layout. Corrected the impact cost to approx. $8.40/month, evidence casing, project name, privacy text encoding, section/button positions and SVG navigation icons. Back, Mark reviewed and bottom tabs work in preview. |
| M09-M13 | Preserved mock configuration interactions. Restored separators and default reached-threshold label; budget calculations, Save/discard, diagnostics and connection state still use the session mock. |

## Mock data and retained differences

- `assets/data/mocks/insight_detail_active.json` supplies M08 content. `lib/core/mock/data/figma_dark_13.json` supplies design geometry/styles and binding names. `InsightDetailScreen` is now a small wrapper.
- Existing business fixtures remain in `tokens_periods.json`, `usage_explorer.json` and `settings_session.json`, called through `FigmaMockRepository`.
- Windows device naming and the example.com account address are deliberate mock substitutions. Source totals/shares are kept internally consistent, so a few numbers/bar proportions differ from the illustrative Figma values.
- Interaction sheets, confirmations, sort indicators and preview navigation remain available. Real authentication, cloud operations, deletion and file export were not added.
- All five static M08 SVGs were downloaded from the exact design context and saved locally. The review checked 52 static SVG placements across the 16 main frame fixtures for non-empty files and recorded SVG root dimensions/slot geometry in the local audit artifact.

## Verification artifacts

`test/dark_main_review_test.dart` loads local fonts, renders the 16 Dark screens at 390 x 844 and writes screenshots. Run:

```powershell
flutter test --no-pub test/dark_main_review_test.dart --dart-define=CAPTURE_STAGE=after
```

Local outputs (ignored build artifacts): `build/dark-review/before/`, `build/dark-review/after/`, `build/dark-review/geometry-audit.json`. Original live contexts/metadata are stored only in that ignored review directory; no temporary Figma asset URLs are used at runtime.

Screenshots were visually compared with the live reference renders. This is a main-screen visual review, not an automated pixel-difference certification of all states or a device integration test.

Final checks: `flutter analyze --no-pub` reports no issues; `flutter test --no-pub --reporter compact --dart-define=CAPTURE_STAGE=after` passes all 106 tests. No APK/device run was performed for this review.

## Main-screen follow-up fixes

- Full Analytics hero totals no longer get a blanket 9px size. Long/full numeric text keeps the design size and fits down only as required by its own slot; regression checks cover all four periods.
- The recommendation mock is shared: context savings and caching savings are separate numeric fields. M07 calculates their total; M08 reads the Month context-savings field. Default Month amounts are $8.40 + $5.20 = $13.60. This calculated total deliberately replaces the inconsistent illustrative $5.20 total in Figma.
- No state-screen behavior or design was modified in this follow-up.

Follow-up validation: all 108 mobile tests pass; analyzer reports no issues.
