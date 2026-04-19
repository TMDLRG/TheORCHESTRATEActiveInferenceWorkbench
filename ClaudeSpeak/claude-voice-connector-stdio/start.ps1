# Claude Voice Connector - Windows PowerShell Start Script
# Launches the connector reading from STDIN, writing to STDOUT

$ErrorActionPreference = "Stop"

# Get script directory
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path

# Add src to PYTHONPATH
$env:PYTHONPATH = "$ScriptDir\src;$env:PYTHONPATH"

# Check for virtual environment
$VenvPaths = @(
    "$ScriptDir\venv\Scripts\Activate.ps1",
    "$ScriptDir\.venv\Scripts\Activate.ps1"
)

foreach ($VenvPath in $VenvPaths) {
    if (Test-Path $VenvPath) {
        . $VenvPath
        break
    }
}

# Check Python version
try {
    $PythonVersion = python -c "import sys; print(f'{sys.version_info.major}.{sys.version_info.minor}')" 2>$null
    $RequiredVersion = [version]"3.10"
    $CurrentVersion = [version]$PythonVersion

    if ($CurrentVersion -lt $RequiredVersion) {
        Write-Error "Python $RequiredVersion+ required, found $PythonVersion"
        exit 1
    }
} catch {
    Write-Error "Python not found or version check failed"
    exit 1
}

# Change to script directory
Set-Location $ScriptDir

# Run with unbuffered output (-u)
# Pass through all arguments
python -u -m claude_voice_connector.stdio_main @args
