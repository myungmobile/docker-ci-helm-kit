FROM jenkins/jnlp-slave
MAINTAINER Myung Kim <myungmobile@gmail.com>

ARG VCS_REF
ARG BUILD_DATE

ENV KUBECTL_VERSION v1.10.3
ENV HEPTIO_AWS_AUTHENTICATOR_VERSION 1.10.3/2018-06-05
ENV AWS_IAM_AUTHENTICATOR 1.10.3/2018-07-26
ENV HELM_VERSION v2.9.1
ENV HELM_PLUGIN_S3_VERSION v0.5.2
ENV TERRAFORM_VERSION=0.11.8

# Metadata
LABEL org.label-schema.vcs-ref=$VCS_REF \
      org.label-schema.vcs-url="https://github.com/lachie83/croc-hunter" \
      org.label-schema.build-date=$BUILD_DATE \
      org.label-schema.docker.dockerfile="/Dockerfile"

ENV CLOUDSDK_CORE_DISABLE_PROMPTS 1
ENV PATH /opt/google-cloud-sdk/bin:$PATH
ENV HELM_HOME /home/cicd/.helm

USER root

RUN apt-get update && apt-get install -y --no-install-recommends \
		g++ \
		gcc \
		libc6-dev \
		make \
        jq \
		awscli \
		git \
		bash \
	&& rm -rf /var/lib/apt/lists/*

# kubectl
RUN set -ex \
    && curl -sSL https://storage.googleapis.com/kubernetes-release/release/${KUBECTL_VERSION}/bin/linux/amd64/kubectl -o /usr/local/bin/kubectl \
    && chmod +x /usr/local/bin/kubectl

# heptio-authenticator-aws
RUN set -ex \
    && curl -sSL https://amazon-eks.s3-us-west-2.amazonaws.com/${HEPTIO_AWS_AUTHENTICATOR_VERSION}/bin/linux/amd64/heptio-authenticator-aws -o /usr/local/bin/heptio-authenticator-aws \
    && chmod +x /usr/local/bin/heptio-authenticator-aws

# aws-iam-authenticator
RUN set -ex \
    && curl -sSL https://amazon-eks.s3-us-west-2.amazonaws.com/${AWS_IAM_AUTHENTICATOR}/bin/linux/amd64/aws-iam-authenticator -o /usr/local/bin/aws-iam-authenticator \
    && chmod +x /usr/local/bin/aws-iam-authenticator

# docker
RUN wget -O /usr/bin/docker --no-check-certificate https://get.docker.com/builds/Linux/x86_64/docker-1.10.3
RUN chmod a+x /usr/bin/docker

# helm
RUN curl -fsSL https://storage.googleapis.com/kubernetes-helm/helm-$HELM_VERSION-linux-amd64.tar.gz -o helm.tar.gz \
	&& tar -C /usr/local/ -xzf helm.tar.gz \
	&& cp /usr/local/linux-amd64/helm /usr/local/bin/ \
	&& rm helm.tar.gz && helm init --client-only

# helm s3 plugin
RUN mkdir -p $HELM_HOME/plugins && \
    helm plugin install https://github.com/hypnoglow/helm-s3.git --version ${HELM_PLUGIN_S3_VERSION} 

# go
ENV GOLANG_VERSION 1.10
ENV GOLANG_DOWNLOAD_URL https://golang.org/dl/go$GOLANG_VERSION.linux-amd64.tar.gz
ENV GOLANG_DOWNLOAD_SHA256 b5a64335f1490277b585832d1f6c7f8c6c11206cba5cd3f771dcb87b98ad1a33

RUN curl -fsSL "$GOLANG_DOWNLOAD_URL" -o golang.tar.gz \
	&& echo "$GOLANG_DOWNLOAD_SHA256  golang.tar.gz" | sha256sum -c - \
	&& tar -C /usr/local -xzf golang.tar.gz \
	&& rm golang.tar.gz

ENV GOPATH /go
ENV PATH $GOPATH/bin:/usr/local/go/bin:$PATH

RUN mkdir -p "$GOPATH/src" "$GOPATH/bin" && chmod -R 777 "$GOPATH"
WORKDIR $GOPATH

# glide
RUN go get -u github.com/Masterminds/glide

# yq
RUN go get -u github.com/mikefarah/yq

# terraform 
ENV TF_DEV=true
ENV TF_RELEASE=true

WORKDIR $GOPATH/src/github.com/hashicorp/terraform
RUN git clone https://github.com/hashicorp/terraform.git ./ && \
    git checkout v${TERRAFORM_VERSION} && \
    /bin/bash scripts/build.sh

