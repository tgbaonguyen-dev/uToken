# TOK-PERIODS-01 ? real Firebase app

Result: PASS for observed period selection/counters and Custom cancellation, with automation recovery. This is not a full backend data-correctness or fresh-login test.

Production main.dart APK; metadata.json records commit, dirty source files and APK SHA256. Device emulator-5554, Android 17. Existing Firebase session restored.

| Selected period | Total tokens | Estimated cost | Evidence of resulting state |
|---|---:|---:|---|
| Month baseline | 701,521,151 | $144.44 | step-01-before_screenshot.jpg |
| Day | 6,323,177 | $0.93 | step-02-before_screenshot.jpg |
| Week | 559,529,293 | $117.18 | step-03-before_screenshot.jpg |
| Month | 701,521,151 | $144.44 | step-04-before_screenshot.jpg |
| Total | 1,896,641,332 | $612.17 | step-05-before_screenshot.jpg |
| Return Month | 701,521,151 | $144.44 | step-06-before_screenshot.jpg |
| Custom ? Close | 701,521,151 | $144.44 | recovery-01-before_screenshot.jpg and recovery-01-after_screenshot.jpg |

Before screenshots show the state produced by the PREVIOUS action, not success of their own next action. Overlays identify the action target; an overlay alone is not a pass.

Verified visually: selected periods change; displayed values differ; Day ? Week ? Total and Day ? Month ? Total; closing Custom preserves Month and its counters. No crash observed in this path. No claim about response-time performance, every state, or exact reconciliation with raw desktop logs.

Automation incident: Pro trace 9bfc5fc8-4238-44de-9230-4c07552306ee completed six taps then failed on an LLM call timeout (180 seconds), leaving Custom open. This trace itself FAILED. Flash recovery 023406ea-c8a4-4dfc-8610-4280d617dd10 closed the picker and verified Month in 29.5 seconds. Do not present the first trace as a successful uninterrupted run. Partial agent notes are retained as historical, not the final result.

Environment: desktop did not respond to the app's automatic sync request within 30 seconds; app displayed last synchronized data with a clear banner. No UToken desktop process was found locally. Fresh desktop?Firebase?mobile sync remains unverified.

Privacy scope: aggregate usage screens only; Account/Settings/Google picker/private project or review text excluded. No real AI review API calls, deletes, sign-out or budget writes.

Flash daemon returned stderr/stdout file paths that do not exist on disk; its tool trace, before/after screenshots and local final hierarchy were inspected instead. Pro stderr was read and retained with the timeout.
