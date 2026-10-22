ARG BOLT_IMAGE=nest/tools/bolt
FROM ${BOLT_IMAGE}

ARG BRANCH
ARG REPOSITORY
ARG SOURCE_URL
ARG SOURCE_SHA

ENV BOLT_PROJECT=/opt/nest
RUN test "${#SOURCE_SHA}" -eq 40 && case "$SOURCE_SHA" in *[!0-9a-f]*) exit 1;; esac && git clone -b "$BRANCH" "$REPOSITORY" "$BOLT_PROJECT" && git -C "$BOLT_PROJECT" remote set-url origin "$SOURCE_URL" && git -C "$BOLT_PROJECT" checkout -B "$BRANCH" "$SOURCE_SHA" && test "$(git -C "$BOLT_PROJECT" rev-parse HEAD)" = "$SOURCE_SHA"
LABEL org.opencontainers.image.revision=$SOURCE_SHA
RUN --mount=type=secret,id=ssh_private_key "$BOLT_PROJECT/bin/ci-bolt-module-install"
RUN ln -s "${BOLT_PROJECT}/bin/build" /usr/local/bin/build
