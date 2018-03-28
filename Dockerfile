# Original credit: https://github.com/jpetazzo/dockvpn
# Additional credit: https://hub.docker.com/r/kylemanna/openvpn

# Smallest base image
FROM alpine:latest
MAINTAINER Unif.io, Inc. <support@unif.io>

ENV EASY_RSA_2_VERSION=2.2.2
ENV EASY_RSA_2_DIR=/usr/share/easy-rsa2

RUN set -ex && \
      apk add --update \
      bash \
      curl \
      easy-rsa \
      git \
      gnupg \
      groff \
      less \
      py2-pip \
      python \
      py-setuptools && \
    # pip
    pip install --upgrade pip && \
    pip install awscli && \
    pip install git+https://github.com/unifio/openvpn-cert-generator.git@dbi-easyrsa3-wip && \
    # grab specific version of easy-rsa
    mkdir -p /tmp/build && \
    cd /tmp/build && \
    curl -s -L --output EasyRSA-${EASY_RSA_2_VERSION}.tgz "https://github.com/OpenVPN/easy-rsa/releases/download/${EASY_RSA_2_VERSION}/EasyRSA-${EASY_RSA_2_VERSION}.tgz" && \
    curl -s -L --output EasyRSA-${EASY_RSA_2_VERSION}.tgz.sig "https://github.com/OpenVPN/easy-rsa/releases/download/${EASY_RSA_2_VERSION}/EasyRSA-${EASY_RSA_2_VERSION}.tgz.sig" && \
    # try a few different keyservers
    for server in $(shuf -e ipv4.pool.sks-keyservers.net \
                            keys.gpupg.net \
                            pgp.mit.edu) ; do \
      gpg --keyserver "$server" --recv-keys 6F4056821152F03B6B24F2FCF8489F839D7367F3 && break || : ; \
    done && \
    gpg --verify EasyRSA-${EASY_RSA_2_VERSION}.tgz.sig && \
    mkdir -p /usr/share/easy-rsa2 && \
    tar -xvzf EasyRSA-${EASY_RSA_2_VERSION}.tgz -C /tmp && \
    mv /tmp/EasyRSA-${EASY_RSA_2_VERSION}/* ${EASY_RSA_2_DIR} && \
    # Get easy-rsa2 to source in a CRL expire time period instead of using the default 30 days
    sed -i 's/default_crl_days=\ 30/default_crl_days=\ \$ENV::EASYRSA_CRL_DAYS/g' /usr/share/easy-rsa2/openssl-1.0.0.cnf && \
    # bad defaults in the openvpn-cert-generator pip package
    ln -s /usr/bin/aws /usr/local/bin/aws && \
    # cleanup
    apk --purge -v del \
      curl \
      git \
      gnupg \
      py2-pip && \
    rm -rf /tmp/* /var/tmp/* /var/cache/apk/* /var/cache/distfiles/*

# Needed by scripts
ENV OPENVPN /etc/openvpn
ENV EASYRSA /usr/share/easy-rsa
ENV EASYRSA_PKI $OPENVPN/pki
ENV EASYRSA_VARS_FILE $OPENVPN/vars

# Defaults for /generate_certs.sh
ENV S3_REGION us-east-1
ENV S3_CERT_ROOT_PATH ""
ENV KEY_SIZE 4096
ENV KEY_DIR /root/easy-rsa-keys
ENV S3_DIR_OVERRIDE ""

# Deal with CRL expiration issues:
ENV EASYRSA_CRL_DAYS 3650

VOLUME ["/root"]

CMD ["/bin/bash"]

ADD ./bin /usr/local/bin
RUN chmod a+x /usr/local/bin/*
