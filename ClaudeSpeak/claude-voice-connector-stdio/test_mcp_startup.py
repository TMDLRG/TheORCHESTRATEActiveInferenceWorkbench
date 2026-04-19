"""Test MCP startup exactly as Claude Desktop runs it."""

import subprocess
import sys
import json
import time

def test_mcp_startup():
    """Test the MCP server startup and first speak command."""
    
    print("=" * 60)
    print("Testing MCP Server Startup (as Claude Desktop runs it)")
    print("=" * 60)
    
    # Start the MCP server exactly as Claude Desktop config specifies
    cmd = [
        r"C:\Users\mpolz\Documents\ClaudeSpeak\claude-voice-connector-stdio\venv\Scripts\python.exe",
        "-u",
        "-m",
        "claude_voice_connector.mcp_server"
    ]
    
    env = {
        "PYTHONPATH": r"C:\Users\mpolz\Documents\ClaudeSpeak\claude-voice-connector-stdio\src",
        "PATH": subprocess.os.environ.get("PATH", ""),
        "SYSTEMROOT": subprocess.os.environ.get("SYSTEMROOT", ""),
    }
    
    print(f"\nCommand: {' '.join(cmd)}")
    print(f"CWD: {r'C:\Users\mpolz\Documents\ClaudeSpeak\claude-voice-connector-stdio'}")
    print(f"PYTHONPATH: {env['PYTHONPATH']}")
    
    proc = subprocess.Popen(
        cmd,
        stdin=subprocess.PIPE,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        cwd=r"C:\Users\mpolz\Documents\ClaudeSpeak\claude-voice-connector-stdio",
        env=env,
        text=True,
    )
    
    def send_request(req):
        """Send a request and get response."""
        req_str = json.dumps(req) + "\n"
        proc.stdin.write(req_str)
        proc.stdin.flush()
        
        # Read response
        response_line = proc.stdout.readline()
        if response_line:
            return json.loads(response_line)
        return None
    
    try:
        # Give it a moment to start
        time.sleep(1)
        
        # Check stderr for errors
        import select
        # On Windows, just try to read what's available
        
        # 1. Initialize
        print("\n1. Sending initialize request...")
        resp = send_request({"jsonrpc": "2.0", "id": 1, "method": "initialize", "params": {}})
        print(f"   Response: {json.dumps(resp, indent=2)[:200]}...")
        
        # 2. List voices
        print("\n2. Sending list_voices request...")
        resp = send_request({
            "jsonrpc": "2.0", 
            "id": 2, 
            "method": "tools/call",
            "params": {"name": "list_voices", "arguments": {}}
        })
        if resp and "result" in resp:
            voices = json.loads(resp["result"]["content"][0]["text"])
            print(f"   Voices: {json.dumps(voices, indent=2)}")
        
        # 3. Speak test
        print("\n3. Sending speak request...")
        resp = send_request({
            "jsonrpc": "2.0",
            "id": 3,
            "method": "tools/call", 
            "params": {
                "name": "speak",
                "arguments": {
                    "text": "Hello Michael, this is the MCP startup test using Piper and the Jenny voice.",
                    "voice": "en_GB-jenny_dioco-medium",
                    "rate": "-5%"
                }
            }
        })
        if resp and "result" in resp:
            result = json.loads(resp["result"]["content"][0]["text"])
            print(f"   Result: {json.dumps(result, indent=2)}")
        
        # Wait for audio to finish
        print("\n4. Waiting for audio playback...")
        time.sleep(8)
        
    finally:
        proc.terminate()
        proc.wait(timeout=5)
        
        # Get any stderr output
        stderr = proc.stderr.read()
        if stderr:
            print(f"\nSTDERR output:\n{stderr}")
    
    print("\n" + "=" * 60)
    print("MCP Startup Test Complete - Did you hear Jenny?")
    print("=" * 60)


if __name__ == "__main__":
    test_mcp_startup()
