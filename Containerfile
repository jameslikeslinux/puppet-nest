ARG BOLT_TAG
FROM nest/tools/bolt:${BOLT_TAG}

ARG SSH_PRIVATE_KEY

RUN echo "$SSH_PRIVATE_KEY" > /root/.ssh/id_rsa && chmod 600 /root/.ssh/id_rsa
RUN git clone https://gitlab.james.tl/nest/puppet.git /modules/nest
WORKDIR /modules/nest
RUN bolt module install
RUN rm /root/.ssh/id_rsa
