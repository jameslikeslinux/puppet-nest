#!/bin/zsh
exec podman run --rm -it -e TERM -v /srv/gitlab-runner:/etc/gitlab-runner gitlab/gitlab-runner $@
