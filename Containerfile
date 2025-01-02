FROM nest/tools/bolt

ARG BRANCH
ARG REPOSITORY
ARG SSH_PRIVATE_KEY

ENV BOLT_PROJECT=/opt/nest
RUN git clone -b "$BRANCH" "$REPOSITORY" "$BOLT_PROJECT"
RUN zsh -c 'eval $(ssh-agent -s) && ssh-add =(echo $SSH_PRIVATE_KEY) && bolt module install'
RUN ln -s "${BOLT_PROJECT}/bin/build" /usr/local/bin/build
