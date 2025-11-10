#!/usr/bin/bash
set -euo pipefail

# Ensure kubectl works in scripts (adjust if needed)
# export KUBECONFIG=${KUBECONFIG:-/etc/rancher/rke2/rke2.yaml}
# export PATH=/var/lib/rancher/rke2/bin:$PATH

read -rp "Namespace to force-delete: " NS
if [[ -z "${NS}" ]]; then
  echo "No namespace provided." >&2; exit 1
fi

# Safety guard
case "$NS" in
  kube-system|kube-public|kube-node-lease|default)
    echo "Refusing to delete protected namespace: $NS" >&2
    exit 1
  ;;
esac

# Must exist
if ! kubectl get ns "$NS" >/dev/null 2>&1; then
  echo "Namespace '$NS' not found (nothing to do)."
  exit 0
fi

echo "== Deleting namespaced resources in '$NS' (best effort)..."
# Delete everything we can (ignores kinds not present)
while read -r r; do
  echo "  - deleting all: ${r}"
  kubectl -n "$NS" delete "$r" --all --ignore-not-found --timeout=30s || true
done < <(kubectl api-resources --verbs=list --namespaced -o name | tr -d '\r')

echo "== Removing finalizers from any remaining objects..."
while read -r r; do
  # list remaining objects of this kind
  while read -r o; do
    [[ -z "$o" ]] && continue
    echo "  - patch finalizers: ${o}"
    kubectl -n "$NS" patch "$o" --type=json -p='[{"op":"remove","path":"/metadata/finalizers"}]' 2>/dev/null || true
  done < <(kubectl -n "$NS" get "$r" -o name 2>/dev/null || true)
done < <(kubectl api-resources --verbs=list --namespaced -o name | tr -d '\r')

echo "== Requesting namespace deletion..."
kubectl delete ns "$NS" --timeout=30s || true

# If it's stuck Terminating, force-finalize via the /finalize endpoint
if kubectl get ns "$NS" >/dev/null 2>&1; then
  echo "== Forcing namespace finalization (clearing finalizers)..."
  kubectl replace --raw "/api/v1/namespaces/${NS}/finalize" -f <(cat <<JSON
{"apiVersion":"v1","kind":"Namespace","metadata":{"name":"${NS}"},"spec":{"finalizers":[]}}
JSON
) >/dev/null || {
    # Fallback via proxy+curl if replace --raw fails
    kubectl proxy --port=8001 >/dev/null 2>&1 & PROXY_PID=$!
    sleep 1
    curl -s -X PUT -H 'Content-Type: application/json' \
      --data-binary "{\"apiVersion\":\"v1\",\"kind\":\"Namespace\",\"metadata\":{\"name\":\"${NS}\"},\"spec\":{\"finalizers\":[]}}" \
      "http://127.0.0.1:8001/api/v1/namespaces/${NS}/finalize" >/dev/null || true
    kill "$PROXY_PID" >/dev/null 2>&1 || true
  }
fi

echo "== Verifying..."
if kubectl get ns "$NS" >/dev/null 2>&1; then
  PHASE=$(kubectl get ns "$NS" -o jsonpath='{.status.phase}')
  echo "Namespace '$NS' still present (phase: $PHASE). Re-run the script if needed."
else
  echo "Namespace '$NS' deleted."
fi