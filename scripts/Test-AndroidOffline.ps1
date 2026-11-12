param(
    [string]$Serial = 'emulator-5554',
    [string]$Adb = 'D:\Android\Sdk\platform-tools\adb.exe'
)

$ErrorActionPreference = 'Stop'
$scratch = Join-Path ([System.IO.Path]::GetTempPath()) ('utoken-offline-' + [guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $scratch | Out-Null
function Invoke-Adb([string[]]$Arguments) {
    $previousPreference = $ErrorActionPreference
    try {
        $ErrorActionPreference = 'Continue' # adb writes successful pull progress to stderr.
        $result = & $Adb -s $Serial @Arguments 2>&1
        $commandExit = $LASTEXITCODE
    }
    finally { $ErrorActionPreference = $previousPreference }
    if ($commandExit -ne 0) { throw "ADB failed: $($Arguments[0])" }
    return $result
}
function Read-Ui {
    Invoke-Adb @('shell', 'uiautomator', 'dump', '/data/local/tmp/utoken-offline.xml') | Out-Null
    Invoke-Adb @('pull', '/data/local/tmp/utoken-offline.xml', (Join-Path $scratch 'ui.xml')) | Out-Null
    [xml]$tree = Get-Content -Encoding UTF8 -LiteralPath (Join-Path $scratch 'ui.xml')
    return $tree.SelectNodes('//node')
}
function Tap-Label([string]$Pattern) {
    $node = Read-Ui | Where-Object { ($_.text + ' ' + $_.'content-desc') -match $Pattern } | Select-Object -First 1
    if (-not $node) { throw "UI label not found: $Pattern" }
    $numbers = [regex]::Matches($node.bounds, '\d+') | ForEach-Object { [int]$_.Value }
    Invoke-Adb @('shell', 'input', 'tap', [string][int](($numbers[0] + $numbers[2]) / 2), [string][int](($numbers[1] + $numbers[3]) / 2)) | Out-Null
}
function Labels { return ((Read-Ui | ForEach-Object { $_.text; $_.'content-desc' }) -join "`n") }

$wifi = (Invoke-Adb @('shell', 'settings', 'get', 'global', 'wifi_on')).Trim()
$data = (Invoke-Adb @('shell', 'settings', 'get', 'global', 'mobile_data')).Trim()
$originalFormat = $null
$checks = [ordered]@{}
try {
    Invoke-Adb @('shell', 'am', 'start', '-W', '-n', 'com.utoken_mobile/.MainActivity') | Out-Null
    Tap-Label '^\s*Settings\s*$'
    $originalFormat = if ((Labels) -match 'Token numbers\s+Full') { 'Full' } else { 'Compact' }
    $targetFormat = if ($originalFormat -eq 'Compact') { 'Full' } else { 'Compact' }
    Invoke-Adb @('shell', 'svc', 'wifi', 'disable') | Out-Null
    Invoke-Adb @('shell', 'svc', 'data', 'disable') | Out-Null
    Tap-Label 'Token numbers'
    Tap-Label "^\s*$targetFormat\s*\u00b7"
    $checks.preferenceChangedOffline = (Labels) -match "Token numbers\s+$targetFormat"
    Invoke-Adb @('shell', 'am', 'force-stop', 'com.utoken_mobile') | Out-Null
    Invoke-Adb @('shell', 'am', 'start', '-W', '-n', 'com.utoken_mobile/.MainActivity') | Out-Null
    Tap-Label '^\s*Settings\s*$'
    $afterRestart = Labels
    $checks.preferenceSurvivesOfflineRestart = $afterRestart -match "Token numbers\s+$targetFormat"
    $checks.pendingSaveVisible = $afterRestart -match 'Retry saving|kept here|not been saved'
    Tap-Label '^\s*Tokens\s*$'
    Tap-Label '^\s*Refresh from Firebase\s*$'
    $offlineLabels = Labels
    $checks.cachedUsageVisibleOffline = $offlineLabels -match 'Total tokens'
    $checks.offlineRefreshErrorVisible = $offlineLabels -match 'network|connection|offline|k\u1ebft n\u1ed1i|Kh\u00f4ng \u0111\u1ecdc'
}
finally {
    Invoke-Adb @('shell', 'svc', 'wifi', $(if ($wifi -eq '1') { 'enable' } else { 'disable' })) | Out-Null
    Invoke-Adb @('shell', 'svc', 'data', $(if ($data -eq '1') { 'enable' } else { 'disable' })) | Out-Null
    if ($originalFormat) {
        Tap-Label '^\s*Settings\s*$'
        Tap-Label 'Token numbers'
        Tap-Label "^\s*$originalFormat\s*\u00b7"
    }
}
$checks | ConvertTo-Json | Tee-Object -FilePath (Join-Path $scratch 'result.json')
Write-Output "Evidence: $scratch"
if ($checks.Values -contains $false) { throw 'At least one offline UI check was not confirmed; inspect the result.' }
