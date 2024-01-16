#!/bin/sh
#
# kustomize
#
# Patch Helm charts using Kustomize as a post-render command
# See: https://trstringer.com/helm-kustomize/
#

if [ ! -f "$1/kustomization.yaml" ]; then
    echo "Usage: $0 KUSTOMIZE_DIR" >&2
    exit 1
fi

cd "$1"

cat > resources.yaml
kubectl kustomize; rc=$?
rm -f resources.yaml

exit $rc
