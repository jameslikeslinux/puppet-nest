ARG BOLT_TAG
FROM nest/tools/bolt:${BOLT_TAG}

ARG SSH_AUTH_SOCK

RUN git clone https://gitlab.james.tl/nest/puppet.git /modules/nest
WORKDIR /modules/nest
RUN bolt module install
