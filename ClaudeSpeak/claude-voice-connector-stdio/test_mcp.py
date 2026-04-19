"""Test the full MCP server with Piper TTS."""

import asyncio
import json
import sys
from pathlib import Path

# Add src to path
src_path = Path(__file__).parent / "src"
sys.path.insert(0, str(src_path))

from claude_voice_connector.mcp_server import MCPServer


async def test_mcp_server():
    """Test MCP server with speak tool."""
    print("Creating MCP server...")
    server = MCPServer()
    
    # Initialize
    print("Initializing...")
    init_req = {"jsonrpc": "2.0", "id": 1, "method": "initialize", "params": {}}
    init_resp = await server.handle_request(init_req)
    print(f"Init response: {json.dumps(init_resp, indent=2)}")
    
    # List tools
    print("\nListing tools...")
    tools_req = {"jsonrpc": "2.0", "id": 2, "method": "tools/list", "params": {}}
    tools_resp = await server.handle_request(tools_req)
    print(f"Tools: {[t['name'] for t in tools_resp['result']['tools']]}")
    
    # List voices
    print("\nListing voices...")
    voices_req = {
        "jsonrpc": "2.0", 
        "id": 3, 
        "method": "tools/call",
        "params": {"name": "list_voices", "arguments": {}}
    }
    voices_resp = await server.handle_request(voices_req)
    voices_data = json.loads(voices_resp['result']['content'][0]['text'])
    print(f"Available voices: {json.dumps(voices_data, indent=2)}")
    
    # Speak test
    print("\nSpeaking test message...")
    speak_req = {
        "jsonrpc": "2.0",
        "id": 4,
        "method": "tools/call",
        "params": {
            "name": "speak",
            "arguments": {
                "text": "Hello Michael! The Piper text to speech integration is now complete. This voice is Jenny from the United Kingdom. The audio should be smooth and natural sounding.",
                "voice": "en_GB-jenny_dioco-medium",
                "rate": "-5%"
            }
        }
    }
    speak_resp = await server.handle_request(speak_req)
    speak_result = json.loads(speak_resp['result']['content'][0]['text'])
    print(f"Speak result: {json.dumps(speak_result, indent=2)}")
    
    # Shutdown
    await server.orchestrator.shutdown()
    print("\nMCP server test completed!")


if __name__ == "__main__":
    asyncio.run(test_mcp_server())
