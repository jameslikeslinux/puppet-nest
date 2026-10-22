#!/bin/bash
# Publish one candidate image and return only its verified registry digest ref.
set -euo pipefail

if [[ $# != 1 || ! "$1" =~ ^[a-z0-9][a-z0-9.:-]*(/[a-z0-9][a-z0-9._-]*)+:[A-Za-z0-9_][A-Za-z0-9_.-]{0,127}$ ]]; then
    printf '%s\n' 'A repository-qualified tagged image is required' >&2
    exit 2
fi
image=$1
work=$(mktemp -d "${TMPDIR:-/tmp}/nest-image-publication.XXXXXXXX")
probe="localhost/nest-image-publication:${work##*.}"
owned=false
cleanup() {
    if [[ "$owned" == true ]]; then
        podman manifest rm "$probe" >/dev/null 2>&1 || true
    fi
    rm -rf -- "$work"
}
trap cleanup EXIT

# Push logs are diagnostics, never part of the machine-readable result.
podman push --digestfile "$work/digest" "$image" >&2
[[ -f "$work/digest" ]]
# Native Podman writes this file without a trailing newline.
digest=$(<"$work/digest")
if [[ ! "$digest" =~ ^sha256:[0-9a-f]{64}$ ]]; then
    printf '%s\n' 'Registry push did not return a SHA256 digest' >&2
    exit 1
fi
reference="${image%:*}@${digest}"
# Explicit docker transport forces remote retrieval. Unlike manifest inspect,
# manifest add supports OCI single images as well as Docker schema 2 images.
# Only manifests/config metadata are read; no duplicate full-layer pull.
podman manifest create "$probe" >&2
owned=true
podman manifest add "$probe" "docker://$reference" >&2
podman manifest rm "$probe" >&2
owned=false
printf '%s\n' "$reference"
