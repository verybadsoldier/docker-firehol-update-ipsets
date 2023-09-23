FROM alpine:3.18.3

ARG update-ipsets_commit=86b1729b37cf45250ef71b4c3fc2314a66de7d34

ARG USERNAME=firehol-update-ipsets
ARG USER_UID=6721
ARG USER_GID=$USER_UID

# Create the user
RUN addgroup -g $USER_GID $USERNAME \
    && adduser -u $USER_UID --disabled-password --uid $USER_UID -G $USERNAME --ingroup $USERNAME $USERNAME


MAINTAINER Yosuke Matsusaka <yosuke.matsusaka@gmail.com>

RUN apk add --no-cache tini bash ipset iproute2 curl unzip grep gawk lsof libcap

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

ENV FIREHOL_CHECKOUT eae10a45c358bf9a37a8528b03a0500b91db5e5b

RUN apk add --no-cache --virtual .firehol_builddep autoconf automake make && \
	wget https://github.com/firehol/firehol/archive/${FIREHOL_CHECKOUT}.zip -O /tmp/firehol.zip && unzip /tmp/firehol.zip -d /tmp && \
    cd /tmp/firehol-${FIREHOL_CHECKOUT} && ls -la && \
    ./autogen.sh && \
    ./configure --prefix= --disable-doc --disable-man && \
    make && \
    make install && \
    cp contrib/ipset-apply.sh /bin/ipset-apply && \
    cd && \
    rm -rf /tmp/firehol.zip && rm -rf /tmp/firehol-${FIREHOL_CHECKOUT} && \
    apk del .firehol_builddep

# set file capabilities so container can be used by non-root user
RUN for f in /usr/sbin/ipset /sbin/xtables-nft-multi /sbin/xtables-legacy-multi; do setcap cap_net_admin,cap_net_raw+eip "${f}"; done

# needed so non-root user can create xtables lock file
RUN chmod 777 /run

RUN chown -R $USERNAME:$USERNAME /etc/firehol && mkdir -p /home/firehol-update-ipsets/.update-ipsets && chown -R $USERNAME:$USERNAME /home/firehol-update-ipsets/.update-ipsets/


USER $USERNAME

ADD enable /bin/enable
ADD disable /bin/disable
ADD update-ipsets-periodic /bin/update-ipsets-periodic
ADD update-common.sh /bin

# Add config file that configure firehol pathes as we were running as root
ADD update-ipsets.conf /home/firehol-update-ipsets/.update-ipsets/update-ipsets.conf

# choose which iptables command to use
ENV IPTABLES_CMD iptables-legacy
# ENV IPTABLES_CMD iptables-nft

# a robust default set of lists (will only be enabled once at container creation)
ENV FIREHOL_LISTS_INIT firehol_level1 firehol_level2 firehol_level3

# skip fullbogons because they include local IPs 192.168.x.x
ENV FIREHOL_LISTS_SKIP fullbogons

# create basic directory structure
RUN update-ipsets -s

CMD ["/bin/update-ipsets-periodic"]
