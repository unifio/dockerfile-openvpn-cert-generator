# Original credit: https://github.com/jpetazzo/dockvpn
# Additional credit: https://hub.docker.com/r/kylemanna/openvpn

# Smallest base image
FROM alpine:3.5
MAINTAINER Unif.io, Inc. <support@unif.io>

# Needed for hashicorp tool install 
ENV ENVCONSUL_VERSION=0.6.1
ENV CONSULTEMPLATE_VERSION=0.16.0
ENV EASY_RSA_2_VERSION=2.2.2
ENV EASY_RSA_2_DIR=/usr/share/easy-rsa2

RUN echo "http://dl-4.alpinelinux.org/alpine/edge/community/" >> /etc/apk/repositories && \
    echo "http://dl-4.alpinelinux.org/alpine/edge/testing/" >> /etc/apk/repositories && \
    apk add --update iptables bash easy-rsa groff less python \
    gnupg py2-pip git curl unzip && \
    pip install awscli && \
    pip install git+https://github.com/unifio/openvpn-cert-generator.git@dbi-easyrsa3-wip && \
    mkdir -p /tmp/build && \
    cd /tmp/build && \
    curl -s --output envconsul_${ENVCONSUL_VERSION}_linux_amd64.zip https://releases.hashicorp.com/envconsul/${ENVCONSUL_VERSION}/envconsul_${ENVCONSUL_VERSION}_linux_amd64.zip && \
    curl -s --output envconsul_${ENVCONSUL_VERSION}_SHA256SUMS https://releases.hashicorp.com/envconsul/${ENVCONSUL_VERSION}/envconsul_${ENVCONSUL_VERSION}_SHA256SUMS && \
    curl -s --output envconsul_${ENVCONSUL_VERSION}_SHA256SUMS.sig https://releases.hashicorp.com/envconsul/${ENVCONSUL_VERSION}/envconsul_${ENVCONSUL_VERSION}_SHA256SUMS.sig && \
    curl -s --output consul-template_${CONSULTEMPLATE_VERSION}_linux_amd64.zip https://releases.hashicorp.com/consul-template/${CONSULTEMPLATE_VERSION}/consul-template_${CONSULTEMPLATE_VERSION}_linux_amd64.zip && \
    curl -s --output consul-template_${CONSULTEMPLATE_VERSION}_SHA256SUMS https://releases.hashicorp.com/consul-template/${CONSULTEMPLATE_VERSION}/consul-template_${CONSULTEMPLATE_VERSION}_SHA256SUMS && \
    curl -s --output consul-template_${CONSULTEMPLATE_VERSION}_SHA256SUMS.sig https://releases.hashicorp.com/consul-template/${CONSULTEMPLATE_VERSION}/consul-template_${CONSULTEMPLATE_VERSION}_SHA256SUMS.sig && \
    gpg --keyserver keys.gnupg.net --recv-keys 91A6E7F85D05C65630BEF18951852D87348FFC4C && \
    gpg --batch --verify envconsul_${ENVCONSUL_VERSION}_SHA256SUMS.sig envconsul_${ENVCONSUL_VERSION}_SHA256SUMS && \
    gpg --batch --verify consul-template_${CONSULTEMPLATE_VERSION}_SHA256SUMS.sig consul-template_${CONSULTEMPLATE_VERSION}_SHA256SUMS && \
    grep envconsul_${ENVCONSUL_VERSION}_linux_amd64.zip envconsul_${ENVCONSUL_VERSION}_SHA256SUMS | sha256sum -c && \
    grep consul-template_${CONSULTEMPLATE_VERSION}_linux_amd64.zip consul-template_${CONSULTEMPLATE_VERSION}_SHA256SUMS | sha256sum -c && \
    unzip -d /usr/local/bin envconsul_${ENVCONSUL_VERSION}_linux_amd64.zip && \
    unzip -d /usr/local/bin consul-template_${CONSULTEMPLATE_VERSION}_linux_amd64.zip && \
    curl -s -L --output EasyRSA-${EASY_RSA_2_VERSION}.tgz https://github.com/OpenVPN/easy-rsa/releases/download/2.2.2/EasyRSA-2.2.2.tgz && \
    curl -s -L --output EasyRSA-${EASY_RSA_2_VERSION}.tgz.sig https://github.com/OpenVPN/easy-rsa/releases/download/2.2.2/EasyRSA-2.2.2.tgz.sig && \
    gpg --keyserver keys.gnupg.net --recv-keys 6F4056821152F03B6B24F2FCF8489F839D7367F3 && \
    gpg --verify EasyRSA-${EASY_RSA_2_VERSION}.tgz.sig && \
    mkdir -p /usr/share/easy-rsa2 && \
    tar -xvzf EasyRSA-${EASY_RSA_2_VERSION}.tgz -C /tmp && \
    mv /tmp/EasyRSA-${EASY_RSA_2_VERSION}/* ${EASY_RSA_2_DIR} && \
    apk --purge -v del git py2-pip gnupg unzip curl && \
    rm -rf /tmp/* /var/tmp/* /var/cache/apk/* /var/cache/distfiles/*

# Needed by scripts
ENV OPENVPN /etc/openvpn
ENV EASYRSA /usr/share/easy-rsa
ENV EASYRSA_PKI $OPENVPN/pki
ENV EASYRSA_VARS_FILE $OPENVPN/vars

VOLUME ["/etc/openvpn"]

CMD ["ovpn_run"]

ADD ./bin /usr/local/bin
RUN chmod a+x /usr/local/bin/*
