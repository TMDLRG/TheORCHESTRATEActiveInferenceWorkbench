#!/usr/bin/env bash
# Proves the LibreChat MCP allowlist is live in the running container by calling
# the same isMCPDomainAllowed function LibreChat itself uses when an MCP server
# tries to connect. Reads the allowlist straight out of the mounted librechat.yaml.
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

if ! docker ps --format '{{.Names}}' | grep -q '^LibreChat$'; then
    echo "LibreChat container is not running. Start it first." >&2
    exit 1
fi

# Extract the allowlist from the container's copy of librechat.yaml.
ALLOW_JSON="$(docker exec LibreChat sh -c "
python3 -c 'import yaml,json,sys
with open(\"/app/librechat.yaml\") as f:
    cfg = yaml.safe_load(f)
print(json.dumps(cfg.get(\"mcpSettings\", {}).get(\"allowedDomains\", [])))
' 2>/dev/null || node -e '
const fs = require(\"fs\");
const yaml = require(\"js-yaml\");
const cfg = yaml.load(fs.readFileSync(\"/app/librechat.yaml\", \"utf8\"));
console.log(JSON.stringify((cfg.mcpSettings || {}).allowedDomains || []));
'
")"

if [[ -z "$ALLOW_JSON" || "$ALLOW_JSON" == "[]" ]]; then
    echo "No mcpSettings.allowedDomains found in the container's /app/librechat.yaml." >&2
    exit 2
fi
echo "Allowlist loaded in the container: $ALLOW_JSON"

docker exec LibreChat node -e "
const { isMCPDomainAllowed } = require('@librechat/api');
const allow = $ALLOW_JSON;
(async () => {
  const tests = [
    ['http://localhost:9001', true],
    ['http://host.docker.internal:3100/sse', true],
    ['http://127.0.0.1:5000', true],
    ['http://my-box.local:9000', true],
    ['http://tools.internal', true],
    ['http://router.lan', true],
    ['http://evil.com', false],
    ['http://169.254.169.254', false],
    ['http://192.168.1.50', false]
  ];
  let pass = 0, fail = 0;
  for (const [url, expect] of tests) {
    const got = await isMCPDomainAllowed({ url, type: 'sse' }, allow);
    const ok = got === expect;
    console.log((ok ? 'PASS' : 'FAIL') + ' ' + url + ' expected=' + expect + ' got=' + got);
    ok ? pass++ : fail++;
  }
  console.log('\\nTotal: ' + pass + ' pass, ' + fail + ' fail');
  process.exit(fail ? 1 : 0);
})();
"
