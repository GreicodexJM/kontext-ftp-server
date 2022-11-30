ARG BASE_IMG=alpine:3.16

FROM $BASE_IMG AS pidproxy
RUN apk --no-cache add alpine-sdk \
 && git clone https://github.com/ZentriaMC/pidproxy.git \
 && cd pidproxy \
 && git checkout 193e5080e3e9b733a59e25d8f7ec84aee374b9bb \
 && sed -i 's/-mtune=generic/-mtune=native/g' Makefile \
 && make \
 && mv pidproxy /usr/bin/pidproxy \
 && cd .. \
 && rm -rf pidproxy \
 && apk del alpine-sdk

FROM ${BASE_IMG} as s3-fuse
RUN apk update && apk add git build-base automake autoconf libxml2-dev fuse-dev curl-dev \
    && git clone https://github.com/s3fs-fuse/s3fs-fuse.git \
    && cd s3fs-fuse \
    && ./autogen.sh \
    && ./configure \
    && make \
    && make install \
    && cd .. \
    && rm -rf s3fs-fuse \
    && apk del build-base

FROM $BASE_IMG
MAINTAINER Javier Munoz "info@greicodex.com"
ARG BUILD_DATE
ARG VCS_REF
LABEL org.label-schema.build-date=$BUILD_DATE \
    org.label-schema.license=GPL-2.0 \
    org.label-schema.name=proftpd \
    org.label-schema.vcs-ref=$VCS_REF \
    org.label-schema.vcs-url=https://github.com/greicodex/docker-tools

ARG PROFTPD_VERSION=1.3.7e-r0
ENV ALLOW_OVERWRITE=on \
    ANONYMOUS_DISABLE=off \
    ANON_UPLOAD_ENABLE=DenyAll \
    FTPUSER_PASSWORD_SECRET=ftp-user-password-secret \
    FTPUSER_NAME=ftpuser \
    FTPUSER_UID=1001 \
    LOCAL_UMASK=0277 \
    MAX_CLIENTS=10 \
    MAX_INSTANCES=30 \
    PASV_ADDRESS= \
    PASV_MAX_PORT=30100 \
    PASV_MIN_PORT=30091 \
    SERVER_NAME=ProFTPD \
    TIMES_GMT=off \
    TZ=UTC \
    WRITE_ENABLE=AllowAll

RUN apk update && apk add mariadb-connector-c mariadb-client libxml2 fuse curl libstdc++ util-linux sshfs
COPY --from=pidproxy /usr/bin/pidproxy /usr/bin/pidproxy
COPY --from=s3-fuse /usr/local/bin/s3fs /usr/bin/s3fs
RUN apk --no-cache add proftpd proftpd-mod_sql proftpd-mod_sftp_sql proftpd-mod_tls proftpd-mod_sql_mysql proftpd-mod_sql_passwd proftpd-mod_sftp_pam tini sudo

COPY proftpd.conf /etc/proftpd/proftpd.conf
RUN chmod 644 /etc/proftpd/proftpd.conf
COPY ftp_sql/mod_sql.conf /etc/proftpd/conf.d/mod_sql.conf
COPY ftp_sql/mod_sftpd.conf /etc/proftpd/conf.d/mod_sftpd.conf
RUN chmod 644 /etc/proftpd/conf.d/mod_sql.conf
RUN chmod 644 /etc/proftpd/conf.d/mod_sftpd.conf
COPY mime.types /etc/mime.types
#RUN adduser -h /ftp/ftp -g nogroup -s /bin/false vsftpd
RUN mkdir -p /data
RUN chown proftpd:nogroup /data
RUN ssh-keygen -q -N "" -t dsa -f /etc/ssh_host_dsa_key
RUN ssh-keygen -q -N "" -t rsa -b 4096 -f /etc/ssh_host_rsa_key
EXPOSE 21 $PASV_MIN_PORT-$PASV_MAX_PORT
VOLUME /data/ftp

COPY start_proftpd.sh /usr/local/bin/entrypoint.sh
COPY sync_ftpusers.sh /etc/periodic/15min/sync_ftpusers.sh
RUN chmod +x /etc/periodic/15min/sync_ftpusers.sh
ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]