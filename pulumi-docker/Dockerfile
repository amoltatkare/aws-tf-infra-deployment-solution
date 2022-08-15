FROM alpine:3.14

LABEL author="Amol Tatkare <amoltatkare@gmail.com>"

COPY . /mnt

USER root

RUN apk add --no-cache bash \
      ca-certificates \
      curl \
      git \
      openssl \
      openssh-client \
      openssl-dev \
      rsync \
      wget \
      httpie \
      jq \
  && rm -rf /var/cache/apk/* 
  #&& curl -fsSL https://get.pulumi.com | sh 


#USER worker

# Install the Pulumi SDK, including the CLI and language runtimes.
RUN curl -fsSL https://get.pulumi.com/ | bash -s -- && \
  mv ~/.pulumi/bin/* /usr/bin

WORKDIR /mnt

CMD ["/mnt/task.sh"]
