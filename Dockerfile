# Original credit: https://github.com/jpetazzo/dockvpn
# Additional credit: https://hub.docker.com/r/kylemanna/openvpn

# Smallest base image
FROM alpine:latest
MAINTAINER Unif.io, Inc. <support@unif.io>

ENV EASY_RSA_2_VERSION=2.2.2
ENV EASY_RSA_2_DIR=/usr/share/easy-rsa2
ENV EASY_RSA_GPG_KEY=6F4056821152F03B6B24F2FCF8489F839D7367F3
RUN set -ex && \
      apk add --no-cache --update \
      bash \
      curl \
      easy-rsa \
      git \
      gnupg \
      groff \
      less \
      python3 && \
    # pip
    if [ ! -e /usr/bin/python ]; then ln -sf python3 /usr/bin/python ; fi && \
    \
    echo "**** install pip ****" && \
    python3 -m ensurepip && \
    rm -r /usr/lib/python*/ensurepip && \
    pip3 install --no-cache --upgrade pip setuptools wheel && \
    if [ ! -e /usr/bin/pip ]; then ln -s pip3 /usr/bin/pip ; fi && \
    pip install awscli && \
    pip install git+https://github.com/unifio/openvpn-cert-generator.git && \
    # grab specific version of easy-rsa
    mkdir -p /tmp/build && \
    cd /tmp/build && \
    curl -s -L --output EasyRSA-${EASY_RSA_2_VERSION}.tgz "https://github.com/OpenVPN/easy-rsa/releases/download/${EASY_RSA_2_VERSION}/EasyRSA-${EASY_RSA_2_VERSION}.tgz" && \
    curl -s -L --output EasyRSA-${EASY_RSA_2_VERSION}.tgz.sig "https://github.com/OpenVPN/easy-rsa/releases/download/${EASY_RSA_2_VERSION}/EasyRSA-${EASY_RSA_2_VERSION}.tgz.sig" && \
    # try a few different keyservers
    ( gpg --keyserver ipv4.pool.sks-keyservers.net --receive-keys "$EASY_RSA_GPG_KEY" \
      || gpg --keyserver ha.pool.sks-keyservers.net --receive-keys "$EASY_RSA_GPG_KEY" ); \
    gpg --verify EasyRSA-${EASY_RSA_2_VERSION}.tgz.sig && \
    mkdir -p /usr/share/easy-rsa2 && \
    tar -xvzf EasyRSA-${EASY_RSA_2_VERSION}.tgz -C /tmp && \
    mv /tmp/EasyRSA-${EASY_RSA_2_VERSION}/* ${EASY_RSA_2_DIR} && \
    # Get easy-rsa2 to source in a CRL expire time period instead of using the default 30 days
    sed -i 's/default_crl_days=\ 30/default_crl_days=\ \$ENV::EASYRSA_CRL_DAYS/g' /usr/share/easy-rsa2/openssl-1.0.0.cnf && \
    # Remove deprecated RANDFILE to avoid error
    # https://github.com/openssl/openssl/commit/0f58220973a02248ca5c69db59e615378467b9c8#diff-8ce6aaad88b10ed2b3b4592fd5c8e03aL13
    sed -i 's/^\(RANDFILE.*\)$/#\1/g' /usr/share/easy-rsa2/openssl-1.0.0.cnf && \
    # bad defaults in the openvpn-cert-generator pip package
    ln -s /usr/bin/aws /usr/local/bin/aws && \
    # cleanup
    apk --purge -v del \
      curl \
      git \
      gnupg && \
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
