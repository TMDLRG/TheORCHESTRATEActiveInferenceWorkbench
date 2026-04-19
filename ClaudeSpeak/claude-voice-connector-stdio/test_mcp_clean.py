"""Test MCP server startup like Claude Desktop does."""

import subprocess
import json
import time

def test_mcp():
    print("=" * 60)
    print("Testing Clean MCP Server")
    print("=" * 60)

    cmd = [
        r"C:\Users\mpolz\Documents\ClaudeSpeak\claude-voice-connector-stdio\venv\Scripts\python.exe",
        "-u", "-m", "claude_voice_connector.mcp_server"
    ]
    
    env = {
        "PYTHONPATH": r"C:\Users\mpolz\Documents\ClaudeSpeak\claude-voice-connector-stdio\src",
        "PATH": subprocess.os.environ.get("PATH", ""),
        "SYSTEMROOT": subprocess.os.environ.get("SYSTEMROOT", ""),
    }
    
    proc = subprocess.Popen(
        cmd, stdin=subprocess.PIPE, stdout=subprocess.PIPE, stderr=subprocess.PIPE,
        cwd=r"C:\Users\mpolz\Documents\ClaudeSpeak\claude-voice-connector-stdio",
        env=env, text=True,
    )
    
    def send(req):
        proc.stdin.write(json.dumps(req) + "\n")
        proc.stdin.flush()
        return json.loads(proc.stdout.readline())
    
    try:
        time.sleep(0.5)
        
        # Initialize
        print("\n1. Initialize...")
        resp = send({"jsonrpc": "2.0", "id": 1, "method": "initialize", "params": {}})
        print(f"   Server: {resp['result']['serverInfo']}")
        
        # Send initialized notification (no response expected)
        proc.stdin.write(json.dumps({"jsonrpc": "2.0", "method": "initialized"}) + "\n")
        proc.stdin.flush()
        
        # List voices
        print("\n2. List voices...")
        resp = send({"jsonrpc": "2.0", "id": 2, "method": "tools/call",
                     "params": {"name": "list_voices", "arguments": {}}})
        voices = json.loads(resp["result"]["content"][0]["text"])
        for v in voices["voices"]:
            print(f"   - {v['short_name']}")
        
        # Speak
        print("\n3. Speaking...")
        resp = send({"jsonrpc": "2.0", "id": 3, "method": "tools/call",
                     "params": {"name": "speak", "arguments": {
                         "text": "Hello! The clean Piper implementation is working perfectly.",
                         "voice": "en_GB-jenny_dioco-medium"
                     }}})
        result = json.loads(resp["result"]["content"][0]["text"])
        print(f"   Result: {result}")
        
        time.sleep(5)
        
    finally:
        proc.terminate()
        proc.wait(timeout=5)
        stderr = proc.stderr.read()
        if stderr:
            print(f"\nLogs:\n{stderr[:500]}")
    
    print("\n" + "=" * 60)
    print("Test Complete - Did you hear Jenny?")
    print("=" * 60)


if __name__ == "__main__":
    test_mcp()
