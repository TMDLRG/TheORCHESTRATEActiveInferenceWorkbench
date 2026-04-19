#!/usr/bin/env bash
# Reproduces the JSON-RPC id-echo bug against the Orchestrate MCP server.
# Exits 0 if the server echoes the request id back (fix landed); 2 if not (bug still present).
#
# Runs from the LibreChat container so it uses the same network path the app does,
# and pulls the API key from LibreChat's .env so the test mirrors production.
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

if ! docker ps --format '{{.Names}}' | grep -q '^LibreChat$'; then
    echo "LibreChat container is not running." >&2
    exit 1
fi

KEY="$(grep -E '^ORCHESTRATE_MCP_API_KEY=' "$ROOT/librechat/.env" | cut -d= -f2-)"
if [[ -z "$KEY" ]]; then
    echo "ORCHESTRATE_MCP_API_KEY not found in librechat/.env" >&2
    exit 1
fi

docker exec -e KEY="$KEY" LibreChat node -e '
const http = require("http");
const KEY = process.env.KEY;
const WANT_ID = 42;

function openSSE() {
  return new Promise((resolve, reject) => {
    const req = http.request({
      host: "host.docker.internal", port: 9001, path: "/sse", method: "GET",
      headers: { "Authorization": "Bearer " + KEY, "Accept": "text/event-stream" }
    }, res => {
      res.setEncoding("utf8");
      if (res.statusCode !== 200) { reject(new Error("SSE status " + res.statusCode)); return; }
      let buf = "";
      res.on("data", chunk => {
        buf += chunk;
        let idx;
        while ((idx = buf.indexOf("\r\n\r\n")) !== -1) {
          const ev = buf.slice(0, idx);
          buf = buf.slice(idx + 4);
          const eMatch = /^event: (.+)$/m.exec(ev);
          const dMatch = /^data: (.+)$/m.exec(ev);
          const event = eMatch ? eMatch[1] : "message";
          const data = dMatch ? dMatch[1] : "";
          if (event === "endpoint" && !res.resolved) { res.resolved = true; resolve({ endpoint: data, stream: res }); }
          else if (event === "message") {
            try {
              const msg = JSON.parse(data);
              if (res.onMessage) res.onMessage(msg);
            } catch (e) { console.error("Bad SSE JSON:", data); }
          }
        }
      });
    });
    req.on("error", reject);
    req.end();
  });
}

function post(endpoint, body) {
  return new Promise(resolve => {
    const req = http.request({
      host: "host.docker.internal", port: 9001, path: endpoint, method: "POST",
      headers: { "Authorization": "Bearer " + KEY, "Content-Type": "application/json" }
    }, res => {
      let buf = "";
      res.on("data", c => buf += c);
      res.on("end", () => resolve({status: res.statusCode, body: buf}));
    });
    req.on("error", e => resolve({error: e.message}));
    req.write(JSON.stringify(body));
    req.end();
  });
}

(async () => {
  const { endpoint, stream } = await openSSE();
  const gotResponse = new Promise(r => { stream.onMessage = r; });
  const postRes = await post(endpoint, {
    jsonrpc: "2.0", id: WANT_ID, method: "initialize",
    params: { protocolVersion: "2024-11-05", capabilities: {}, clientInfo: { name: "repro", version: "1.0" } }
  });
  if (postRes.status !== 202) {
    console.error("POST failed:", JSON.stringify(postRes));
    process.exit(1);
  }
  const resp = await Promise.race([
    gotResponse,
    new Promise((_, rej) => setTimeout(() => rej(new Error("no response within 10s")), 10000))
  ]);
  console.log("Response:", JSON.stringify(resp));
  if (!("id" in resp)) {
    console.log("\nFAIL: response is missing the JSON-RPC id (bug).");
    console.log("      expected id=" + WANT_ID + ", got none.");
    process.exit(2);
  }
  if (resp.id !== WANT_ID) {
    console.log("\nFAIL: response id does not match request id.");
    console.log("      expected=" + WANT_ID + " got=" + JSON.stringify(resp.id));
    process.exit(2);
  }
  if (!resp.result) {
    console.log("\nFAIL: response has id but no result.");
    process.exit(2);
  }
  console.log("\nPASS: response echoed id=" + resp.id + " with a valid result.");
  process.exit(0);
})().catch(e => { console.error("ERR:", e.message); process.exit(1); });
'
