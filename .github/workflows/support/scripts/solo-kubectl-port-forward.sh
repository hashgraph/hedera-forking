#!/usr/bin/env bash
# SPDX-License-Identifier: Apache-2.0
#
# Starts background kubectl port-forward processes so localhost matches the
# expectations of `@hashgraph/sdk` local-node consumers (127.0.0.1:50211 →
# consensus via HAProxy) and the mirror Web3 endpoint (127.0.0.1:8545 →
# svc/mirror-1-web3), consistent with hiero-sdk-js solo-lib.js.
#
# Required environment:
#   SOLO_NAMESPACE — Kubernetes namespace from the Solo deploy step
#                    (e.g. steps.<id>.outputs.namespace).

set -euo pipefail

NS="${SOLO_NAMESPACE:?SOLO_NAMESPACE is required}"

kubectl get svc haproxy-node1-svc -n "${NS}"
kubectl port-forward -n "${NS}" svc/haproxy-node1-svc 50211:50211 &
echo "Forwarding svc/haproxy-node1-svc -> localhost:50211 (consensus gRPC for local-node)"

if kubectl get svc mirror-1-web3 -n "${NS}" &>/dev/null; then
  kubectl port-forward -n "${NS}" svc/mirror-1-web3 8545:80 &
  echo "Forwarding svc/mirror-1-web3 -> localhost:8545 (mirror Web3)"
else
  echo "::warning::svc/mirror-1-web3 not found in ${NS}; skipping 8545 forward"
fi

sleep 3
