# Frozen PDK candidate producer

The existing `nest::build::pdk` wrapper accepts optional `candidate`,
`from_image` and `repo_revisions` inputs. The existing `bin/ci-release-build`
adapter dispatches `nest/tools/pdk` members to that wrapper, not directly to
the generic tool publisher. Supported candidate CPUs are `haswell`,
`cortex-a53` and `sifive-u74`, each with variant `server` and explicit fresh
or refresh mode. This is a source contract, not a published PDK image receipt.

Candidate execution requires `build=true`, `init=true`, `deploy=true`, a
repository-qualified exact base digest, complete Gentoo/overlay/Haskell commit
pins, a remote registry and no tag override. The candidate token uses the same
bounded lowercase syntax as the other tool wrappers. Malformed or incomplete
inputs fail before container initialization. The caller must select/admit the
actual fresh Stage 1 server or refresh PDK base and resource requirements;
a syntactically valid digest does not prove compatibility.

The underlying tool plan isolates `/var/db/repos` and checks its exact source
before and after configuration. PDK retains its existing exact read-only mount
`/etc/gemrc:/etc/gemrc:ro` for build-time dependency acquisition. This is the only
extra mount accepted for frozen PDK; arbitrary mounts, writable alternatives
and the same exception for other tools refuse. Mount contents are not copied
by Podman commit. Runtime credential/cache hygiene still needs the existing
PDK image validation; mount admission alone is not proof of a secret-free image.

Before candidate publication the wrapper preserves the native PDK smoke:
generate a module, create class/task, resolve dependencies, run ordinary
`pdk validate` and the focused generated-class unit test. It also preserves the
merged offline-cache repair's committed Nest module capture and dependency
closure generation. After that capture it rechecks frozen repositories and
requires a successful final container stop. Any failure prevents candidate
commit/publication; it is not retried automatically.

Only `REGISTRY/nest/tools/pdk:candidate-TOKEN` is committed and published. The
runtime instructions remain `CMD=/bin/zsh`, `PDK_DISABLE_ANALYTICS=true`,
`NEST_PDK_OFFLINE=true` and `WORKDIR=/module`. The existing image publisher
returns a digest after remote readback. The wrapper refuses mutable or
wrong-repository results and returns exactly `image: REPOSITORY@sha256:DIGEST`.
It does not update ordinary CPU tags, an aggregate index or `latest`.

Without `candidate`, ordinary legacy CPU-tag publication remains unchanged.
The new base/pin inputs remain optional. Rollback stops selecting the new
candidate interface and preserves accepted digests and results; never replay
an interrupted build merely to reconstruct a missing receipt.

Fixtures exercise the actual Puppet plans with mocked container commands and
the actual adapter with local Git and fake Bolt/Podman. They cover supported
CPU/mode combinations, early refusal, smoke/cache failure, repository drift,
failed stop/commit/publication, wrong result references and attempt replay.
They do not acquire private dependencies, build/publish a real PDK image or
prove network-disabled workflows. The existing offline PDK repair owns that
runtime acceptance. The distinct PDK CI consumer, trusted cross-project artifact
acquisition, native release DAG and separately authorized real release builds
remain integration obligations. No host rollout is launched by this interface.
