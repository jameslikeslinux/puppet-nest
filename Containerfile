FROM nest/tools/bolt

ARG BRANCH
ARG REPOSITORY
ARG SSH_PRIVATE_KEY

RUN git clone -b "$BRANCH" "$REPOSITORY" /modules/nest
WORKDIR /modules/nest
RUN zsh -c 'eval $(ssh-agent -s) && ssh-add =(echo $SSH_PRIVATE_KEY) && bolt module install'
