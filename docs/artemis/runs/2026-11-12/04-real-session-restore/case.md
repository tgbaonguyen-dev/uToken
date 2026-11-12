# SESSION-RESTORE-04 ? full process restart

Result: PASS for persistence of the existing session after Android force-stop. Flash trace 9738e542-e0bc-45be-a896-5fd49d923aa6, elapsed 55.1 seconds (not an app startup benchmark).

Host setup executed successfully: adb -s emulator-5554 shell am force-stop com.utoken_mobile. No clear-data, uninstall or sign-out. Artemis then launched the production app.

Initial Tokens screen had a loading indicator. Subsequent screenshot shows Tokens directly, Month selected, 701,521,151 tokens / $144.44, without visiting Welcome or requiring sign-in. Evidence: step-02-before_screenshot.jpg. Final hierarchy was independently read.

Automatic desktop sync was pending, later timed out, because desktop was not running; this is separate from session restoration. This test does not cover token revocation, sign-out, reinstall, account switching or a fresh Google login. Identity/UID was not collected.

Standalone daemon stderr/stdout paths were absent; retained tool summary/screenshots and daemon excerpt are the available diagnostics.
