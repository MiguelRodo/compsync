#!/usr/bin/env pwsh
# compsync.ps1 — compsync CLI wrapper for Windows (runs via Git Bash)

$Usage = @"
Usage: compsync <command> [options]

Commands:
  update    Clone MiguelRodo/comp and interactively apply configurations

Run 'compsync <command> --help' for more information on a command.
"@

$ScriptRoot = Split-Path -Parent $PSCommandPath
$ScriptsDir = Join-Path (Split-Path -Parent $ScriptRoot) "scripts"

$SubcommandScripts = @{
    "update" = "compsync.sh"
}

if ($args.Count -eq 0 -or $args[0] -eq "--help" -or $args[0] -eq "-h") {
    Write-Output $Usage
    if ($args.Count -eq 0) { exit 1 } else { exit 0 }
}

$Subcommand = $args[0]
$Remaining = $args[1..($args.Count - 1)]

if (-not $SubcommandScripts.ContainsKey($Subcommand)) {
    Write-Error "Error: unknown command '$Subcommand'"
    Write-Output ""
    Write-Output $Usage
    exit 1
}

$TargetScript = Join-Path $ScriptsDir $SubcommandScripts[$Subcommand]

if (-not (Test-Path $TargetScript)) {
    Write-Error "Error: $($SubcommandScripts[$Subcommand]) not found at $TargetScript"
    Write-Error "The compsync package may not be installed correctly."
    exit 1
}

# Locate bash.exe from Git for Windows
$BashPath = $null
$PossiblePaths = @(
    "${env:ProgramFiles}\Git\bin\bash.exe",
    "${env:ProgramFiles(x86)}\Git\bin\bash.exe",
    "${env:LOCALAPPDATA}\Programs\Git\bin\bash.exe"
)

foreach ($Path in $PossiblePaths) {
    if (Test-Path $Path) {
        $BashPath = $Path
        break
    }
}

if (-not $BashPath) {
    $BashPath = (Get-Command bash.exe -ErrorAction SilentlyContinue).Source
}

if (-not $BashPath) {
    Write-Error "Error: bash.exe (Git Bash) not found."
    Write-Error "Please install Git for Windows from https://git-scm.com/download/win"
    exit 1
}

# Convert Windows path to Unix-style path for Git Bash
$TargetScriptUnix = $TargetScript -replace '\\', '/'
if ($TargetScriptUnix -match '^([A-Za-z]):(.*)$') {
    $Drive = $matches[1].ToLower()
    $Rest  = $matches[2]
    $TargetScriptUnix = "/$Drive$Rest"
}

& $BashPath -c "$TargetScriptUnix $Subcommand $Remaining"
exit $LASTEXITCODE
