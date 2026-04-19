# Stop the locally-launched llama-server.
$ErrorActionPreference = "SilentlyContinue"
$root = Split-Path -Parent $PSScriptRoot
Set-Location $root

$pidFile = Join-Path $root ".qwen_pid"
if (Test-Path $pidFile) {
    $target = Get-Content $pidFile -Raw
    if ($target) {
        Write-Host "Stopping llama-server PID $target"
        Stop-Process -Id $target -Force
    }
    Remove-Item $pidFile -Force
}

# Sweep any orphan llama-server.exe we may have launched (defensive).
Get-Process llama-server -ErrorAction SilentlyContinue | ForEach-Object {
    Write-Host "Sweeping orphan llama-server PID $($_.Id)"
    Stop-Process -Id $_.Id -Force
}

Remove-Item (Join-Path $root ".qwen_port") -Force -ErrorAction SilentlyContinue
Write-Host "Stopped."
