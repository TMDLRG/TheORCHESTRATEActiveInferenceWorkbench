#!/usr/bin/env bash
# Claude Voice Connector - Unix Start Script
# Launches the connector reading from STDIN, writing to STDOUT

set -e

# Get script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Add src to PYTHONPATH
export PYTHONPATH="${SCRIPT_DIR}/src:${PYTHONPATH:-}"

# Check for virtual environment
if [ -d "${SCRIPT_DIR}/venv" ]; then
    source "${SCRIPT_DIR}/venv/bin/activate"
elif [ -d "${SCRIPT_DIR}/.venv" ]; then
    source "${SCRIPT_DIR}/.venv/bin/activate"
fi

# Check Python version
python_version=$(python3 -c 'import sys; print(f"{sys.version_info.major}.{sys.version_info.minor}")')
required_version="3.10"

if [ "$(printf '%s\n' "$required_version" "$python_version" | sort -V | head -n1)" != "$required_version" ]; then
    echo "Error: Python $required_version+ required, found $python_version" >&2
    exit 1
fi

# Run with unbuffered output (-u)
cd "${SCRIPT_DIR}"
exec python3 -u -m claude_voice_connector.stdio_main "$@"
