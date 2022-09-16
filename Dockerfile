FROM alpine

ARG update-ipsets_commit=86b1729b37cf45250ef71b4c3fc2314a66de7d34

MAINTAINER Yosuke Matsusaka <yosuke.matsusaka@gmail.com>

RUN apk add --no-cache tini bash ipset iproute2 curl unzip grep gawk lsof

ENV IPRANGE_VERSION 1.0.4

RUN apk add --no-cache --virtual .iprange_builddep autoconf automake make gcc musl-dev && \
    curl -L https://github.com/firehol/iprange/releases/download/v$IPRANGE_VERSION/iprange-$IPRANGE_VERSION.tar.gz | tar zvx -C /tmp && \
    cd /tmp/iprange-$IPRANGE_VERSION && \
    ./configure --prefix= --disable-man && \
    make && \
    make install && \
    cd && \
    rm -rf /tmp/iprange-$IPRANGE_VERSION && \
    apk del .iprange_builddep

ENV FIREHOL_VERSION 3.1.6

RUN apk add --no-cache --virtual .firehol_builddep autoconf automake make && \
     curl -L https://github.com/firehol/firehol/releases/download/v$FIREHOL_VERSION/firehol-$FIREHOL_VERSION.tar.gz | tar zvx -C /tmp && \
     cd /tmp/firehol-$FIREHOL_VERSION && \
     ./autogen.sh && \
     ./configure --prefix= --disable-doc --disable-man && \
     make && \
     make install && \
     cp contrib/ipset-apply.sh /bin/ipset-apply && \
     cd && \
     rm -rf /tmp/firehol-$FIREHOL_VERSION && \
     apk del .firehol_builddep && \
     curl -L https://raw.githubusercontent.com/firehol/firehol/86b1729b37cf45250ef71b4c3fc2314a66de7d34/sbin/update-ipsets -o /sbin/update-ipsets && \
     chmod a+x /sbin/update-ipsets

ADD enable /bin/enable
ADD disable /bin/disable
ADD update-ipsets-periodic /bin/update-ipsets-periodic
ADD update-common.sh /bin

# use nf tables by default (e.g.Ubuntu >= 20.04)
ENV IPTABLES_CMD iptables-nft

# a robust default set of lists (will only be enabled once at container creation)
ENV FIREHOL_LISTS_INIT firehol_level1 firehol_level2 firehol_level3

# skip fullbogons because they include local IPs 192.168.x.x
ENV SKIP_LISTS fullbogons

ENTRYPOINT ["/sbin/tini", "--"]

CMD ["/bin/update-ipsets-periodic"]
