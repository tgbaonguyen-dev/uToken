param(
    [Parameter(Mandatory = $true)]
    [ValidatePattern('^[a-z][a-z0-9-]+$')]
    [string]$ProjectId
)

$ErrorActionPreference = 'Stop'
$repoRoot = Split-Path -Parent $PSScriptRoot
$configPath = Join-Path $repoRoot 'desktop/src/UToken.Desktop.App/appsettings.Local.json'
$testProject = Join-Path $repoRoot 'desktop/tests/UToken.Sync.Tests/UToken.Sync.Tests.csproj'
if (-not (Test-Path -LiteralPath $configPath)) { throw 'Run/build the desktop app and configure appsettings.Local.json first.' }
$config = Get-Content -LiteralPath $configPath -Raw | ConvertFrom-Json
if ($config.Firebase.UseEmulator -ne $false -or $config.Firebase.ProjectId -ne $ProjectId) {
    throw 'Project ID must match appsettings.Local.json and UseEmulator must be false.'
}

$values = @{
    UTOKEN_LIVE_FIREBASE = '1'
    UTOKEN_LIVE_PROJECT = $ProjectId
    UTOKEN_LIVE_CONFIG = $configPath
    UTOKEN_LIVE_RULES = (Join-Path $repoRoot 'firebase/firestore.rules')
}
$previous = @{}
foreach ($name in $values.Keys) {
    $previous[$name] = [Environment]::GetEnvironmentVariable($name, 'Process')
    [Environment]::SetEnvironmentVariable($name, $values[$name], 'Process')
}
try {
    Write-Host "Checking real Firebase project: $ProjectId. Only random disposable probe documents are written."
    Write-Host 'Sign in and run Sync now in the desktop app before this check. No Rules will be deployed.'
    & dotnet test $testProject --no-restore '-p:OutputPath=bin/FirebaseLive/' --filter 'FullyQualifiedName~LiveFirebaseTests' --logger 'console;verbosity=normal' --verbosity minimal
    $result = $LASTEXITCODE
}
finally {
    foreach ($name in $values.Keys) { [Environment]::SetEnvironmentVariable($name, $previous[$name], 'Process') }
}
exit $result
