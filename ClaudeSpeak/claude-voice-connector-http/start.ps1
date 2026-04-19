#Requires -Version 5.1
<#
.SYNOPSIS
  Start the ClaudeSpeak HTTP TTS wrapper on 127.0.0.1:7712.

.DESCRIPTION
  Reuses the sibling venv at
  `../claude-voice-connector-stdio/.venv` if present.  Otherwise falls
  back to the first `python` on PATH.  Run without arguments; set
  CLAUDE_SPEAK_PORT / CLAUDE_SPEAK_HOST to override.
#>

param(
    [string]$Port = $env:CLAUDE_SPEAK_PORT,
    [string]$Host = $env:CLAUDE_SPEAK_HOST
)

$ErrorActionPreference = "Stop"
$here = Split-Path -Parent $MyInvocation.MyCommand.Path
$venv = Join-Path (Split-Path -Parent $here) "claude-voice-connector-stdio\.venv"
$python = "python"

if (Test-Path "$venv\Scripts\python.exe") {
    $python = "$venv\Scripts\python.exe"
}

if ($Port) { $env:CLAUDE_SPEAK_PORT = $Port }
if ($Host) { $env:CLAUDE_SPEAK_HOST = $Host }

Write-Host "Starting ClaudeSpeak HTTP TTS on $(${env:CLAUDE_SPEAK_HOST} ?? '127.0.0.1'):$(${env:CLAUDE_SPEAK_PORT} ?? '7712')"
& $python "$here\server.py"
