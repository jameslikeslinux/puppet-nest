ARG BOLT_IMAGE=nest/tools/bolt
FROM ${BOLT_IMAGE}

ARG BRANCH
ARG REPOSITORY
ARG SOURCE_URL

ENV BOLT_PROJECT=/opt/nest
RUN git clone -b "$BRANCH" "$REPOSITORY" "$BOLT_PROJECT" && git -C "$BOLT_PROJECT" remote set-url origin "$SOURCE_URL"
RUN --mount=type=secret,id=ssh_private_key "$BOLT_PROJECT/bin/ci-bolt-module-install"
RUN ln -s "${BOLT_PROJECT}/bin/build" /usr/local/bin/build
