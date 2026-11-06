#!/usr/bin/env bash
# Verifies pods + public endpoint serve the expected version (git short SHA).
# Usage: scripts/verify.sh <expected-version>
set -euo pipefail

NS="${NAMESPACE:-javaapp}"
SVC="${SERVICE:-javaapp}"
EXPECTED="${1:?usage: verify.sh <expected-version>}"

echo "== Deployment / pods =="
kubectl get deployment javaapp -n "$NS"
kubectl get pods -n "$NS" -o wide

echo "== Waiting for LoadBalancer public IP =="
IP=""
for i in $(seq 1 40); do
  IP="$(kubectl get svc "$SVC" -n "$NS" -o jsonpath='{.status.loadBalancer.ingress[0].ip}' 2>/dev/null || true)"
  [ -n "$IP" ] && break
  echo "  attempt $i: no IP yet"; sleep 10
done
[ -n "$IP" ] || { echo "ERROR: no external IP assigned"; exit 1; }

echo "== Endpoint: http://$IP =="
for i in $(seq 1 30); do
  BODY="$(curl -fsS --max-time 5 "http://$IP/api/version" || true)"
  echo "  attempt $i: ${BODY:-<no response>}"
  if echo "$BODY" | grep -q "\"version\":\"$EXPECTED\""; then
    echo "SUCCESS: app is live and serving version $EXPECTED"
    if [ -n "${GITHUB_STEP_SUMMARY:-}" ]; then
      { echo "### Deployed"; echo "- URL: http://$IP"; echo "- Version: \`$EXPECTED\`"; } >> "$GITHUB_STEP_SUMMARY"
    fi
    exit 0
  fi
  sleep 10
done
echo "ERROR: endpoint never reported version $EXPECTED"
exit 1
