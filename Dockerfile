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


FROM $BASE_IMG as pam-mysql
#
#RUN apk --no-cache add linux-pam-dev  nss-dev mariadb-dev python3 py3-pip cmake clang lld make autoconf automake libtool which diffutils file git \
RUN apk --no-cache add linux-pam-dev nss-dev mariadb-dev make autoconf automake libtool which diffutils file git autoconf alpine-sdk \
    && git clone https://github.com/NigelCunningham/pam-MySQL.git \
    && cd pam-MySQL \
    && git checkout v0.8.x \
    && autoreconf -i \
    && ./configure \
    && ( make || echo "Failed Make" ) \
    && strip .libs/pam_mysql.so \
    && ( make install || echo "Failed Install" )\
    && cd .. \
    && rm -rf pam-MySQL \
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
RUN apk update && apk add mariadb-connector-c libxml2 fuse curl libstdc++ util-linux sshfs
COPY --from=pidproxy /usr/bin/pidproxy /usr/bin/pidproxy
COPY --from=s3-fuse /usr/local/bin/s3fs /usr/bin/s3fs
COPY --from=pam-mysql /lib/security/pam_mysql.so /lib/security/pam_mysql.so
COPY --from=pam-mysql /lib/security/pam_mysql.la /lib/security/pam_mysql.la
RUN apk --no-cache add vsftpd tini 

COPY start_vsftpd.sh /bin/start_vsftpd.sh
COPY vsftpd.conf /etc/vsftpd/vsftpd.conf
COPY pam-mysql/pam_mysql.conf /etc/pam_mysql.conf
COPY pam-mysql/pamd.conf /tmp/pamd.conf
COPY mime.types /etc/mime.types
RUN cat /tmp/pamd.conf >> /etc/pam.d/vsftpd
#password-auth
#RUN cat /tmp/pamd.conf >> /etc/pam.d/system-auth
RUN rm /tmp/pamd.conf
#RUN adduser -h /ftp/ftp -g nogroup -s /bin/false vsftpd
#RUN mkdir -p /ftp/ftp/user1
#RUN chown vsftpd:nogroup /ftp/ftp/user1
EXPOSE 21 21000-21010
VOLUME /ftp/ftp

ENTRYPOINT ["/sbin/tini", "--", "/bin/start_vsftpd.sh"]