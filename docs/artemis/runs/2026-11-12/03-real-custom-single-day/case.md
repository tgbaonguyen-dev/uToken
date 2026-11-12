# CUSTOM-RANGE-03 ? one-day range

Functional result: PASS, with a minor UI copy defect. Flash trace 8e491bf3-53d5-4540-9b36-dfc444373f47, 66.2 seconds, seven recorded steps.

1. Open Custom from Tokens Month (701,521,151 / $144.44).
2. Select November 12, 2026 twice to set start=end. Picker header visibly shows Nov 12 ? Nov 12 (step-05-before_screenshot.jpg).
3. Apply: Custom highlighted, chip 12 Nov, total 6,323,177 / $0.93 (step-06-before_screenshot.jpg). This matches the independently observed Day view in case 01.
4. Return Month: selected state and 701,521,151 / $144.44 restored (step-07-before_screenshot.jpg).

Agent passed invalid target index 636 once, then recovered using visible element index 17; the invalid tap did not execute. Count as a recovered automation error, not an app bug.

UI defect LOW: one-day chip says `12 Nov ? 1 days`; expected `12 Nov ? 1 day`. Evidence step-06-before_screenshot.jpg. Date filtering itself passed. No code fix was made during this run, preserving APK reproducibility.

Same production APK/source state as metadata. No Account/Google/private text screens or manual sync/AI calls. Flash standalone stderr/stdout paths were absent; tool trace and daemon excerpt retained instead.
