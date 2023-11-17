#!/bin/bash
apt update -y && \
apt install -y \
 s3fs \
 libmariadb-dev \
 mariadb-client \
 libxml2 \
 fuse3 \
 curl \
 util-linux \
 sshfs \
 proftpd \
 proftpd-mod-mysql \
 proftpd-mod-crypto \
 tini \
 sudo
echo DO003CBTGZTVYCFACX9G:zJ7w5FtV2YPAF2Bdu0oNX6/U2Nx5/8OTXw/mwI5dMaM > /etc/passwd-s3fs
chmod 600 /etc/passwd-s3fs

cat << EOT > /etc/environment
S3_URL=https://nyc3.digitaloceanspaces.com
S3_BUCKET=kontext-files
S3FS_OPT="-o passwd_file=/etc/passwd-s3fs -o nonempty -o url=$S3_URL -o umask=0000,uid=$(cat /etc/passwd | grep proftpd | cut -d':' -f3),gid=$(cat /etc/passwd | grep proftpd | cut -d':' -f4) -o enable_content_md5 -o allow_other -o rw -o nosuid -o nodev -o use_rrs -o use_cache=/tmp"
FTP_DB_USER=proftpd
# FTP_DB_PASSWD=""
FTP_DB_NAME=ftpserver
FTP_DB_HOST=db-kontext-nyc3-80124-do-user-1806326-0.b.db.ondigitalocean.com
FTP_DB_PORT=25060
EOT

. /etc/environment
export S3_URL
export S3_BUCKET
export S3FS_OPT
export FTP_DB_USER
export FTP_DB_NAME
export FTP_DB_HOST
export FTP_DB_PORT

mkdir -p /data/ftp
chown proftpd:nogroup -R /data/ftp
echo "AVNS_jT0jbd_vun3Zy0MZbVP" > /etc/my-passwd
chmod 600 /etc/my-passwd 

cat << EOT >> /etc/fstab
s3fs#kontext-files /data/ftp fuse passwd_file=/etc/passwd-s3fs,nonempty,url=https://nyc3.digitaloceanspaces.com,allow_other,use_cache=/tmp,umask=0000,uid=$(cat /etc/passwd | grep proftpd | cut -d':' -f3),gid=$(cat /etc/passwd | grep proftpd | cut -d':' -f4),enable_content_md5,rw,nosuid,nodev,use_rrs 0 0
EOT

cat << EOT > /etc/proftpd/proftpd.conf 
#
# /etc/proftpd/proftpd.conf -- This is a basic ProFTPD configuration file.
# To really apply changes, reload proftpd after modifications, if
# it runs in daemon mode. It is not required in inetd/xinetd mode.
#

# Includes DSO modules
Include /etc/proftpd/modules.conf

# Set off to disable IPv6 support which is annoying on IPv4 only boxes.
UseIPv6 on
# If set on you can experience a longer connection delay in many cases.
<IfModule mod_ident.c>
  IdentLookups off
</IfModule>

ServerName "KontextFTP"
# Set to inetd only if you would run proftpd by inetd/xinetd/socket.
# Read README.Debian for more information on proper configuration.
ServerType standalone
DeferWelcome off

# Disable MultilineRFC2228 per https://github.com/proftpd/proftpd/issues/1085
# MultilineRFC2228on
DefaultServer on
ShowSymlinks on

TimeoutNoTransfer 600
TimeoutStalled 600
TimeoutIdle 1200

DisplayLogin welcome.msg
DisplayChdir .message true
ListOptions "-l"

DenyFilter \*.*/

# Use this to jail all users in their homes 
DefaultRoot ~


# This line will create the user directories of an FTP user if they successfully authenticate but do not have a user directory.
# See http://www.proftpd.org/docs/howto/CreateHome.html
# CreateHome off|on [<mode>] [skel <path>] [dirmode <mode>] [uid <uid>] [gid <gid>] [homegid <gid>] [NoRootPrivs]
CreateHome                      on dirmode 750


# Users require a valid shell listed in /etc/shells to login.
# Use this directive to release that constrain.
RequireValidShell  off

# Port 21 is the standard FTP port.
Port 2121

# In some cases you have to specify passive ports range to by-pass
# firewall limitations. Ephemeral ports can be used for that, but
# feel free to use a more narrow range.
# PassivePorts 49152 65534

# If your host was NATted, this option is useful in order to
# allow passive tranfers to work. You have to use your public
# address and opening the passive ports used on your firewall as well.
# MasqueradeAddress 1.2.3.4

# This is useful for masquerading address with dynamic IPs:
# refresh any configured MasqueradeAddress directives every 8 hours
<IfModule mod_dynmasq.c>
# DynMasqRefresh 28800
</IfModule>

# To prevent DoS attacks, set the maximum number of child processes
# to 30.  If you need to allow more than 30 concurrent connections
# at once, simply increase this value.  Note that this ONLY works
# in standalone mode, in inetd mode you should use an inetd server
# that allows you to limit maximum number of processes per service
# (such as xinetd)
MaxInstances 50

# Set the user and group that the server normally runs at.
User proftpd
Group nogroup

# Umask 022 is a good standard umask to prevent new files and dirs
# (second parm) from being group and world writable.
Umask 022 022
# Normally, we want files to be overwriteable.
AllowOverwrite on

# Uncomment this if you are using NIS or LDAP via NSS to retrieve passwords:
# PersistentPasswd off

# This is required to use both PAM-based authentication and local passwords
# AuthOrder mod_auth_pam.c* mod_auth_unix.c

# Be warned: use of this directive impacts CPU average load!
# Uncomment this if you like to see progress and transfer rate with ftpwho
# in downloads. That is not needed for uploads rates.
#
# UseSendFile off

TransferLog /var/log/proftpd/xferlog
SystemLog /var/log/proftpd/proftpd.log

# Logging onto /var/log/lastlog is enabled but set to off by default
#UseLastlog on

# In order to keep log file dates consistent after chroot, use timezone info
# from /etc/localtime.  If this is not set, and proftpd is configured to
# chroot (e.g. DefaultRoot or <Anonymous>), it will use the non-daylight
# savings timezone regardless of whether DST is in effect.
#SetEnv TZ :/etc/localtime

<IfModule mod_quotatab.c>
QuotaEngine off
</IfModule>

<IfModule mod_ratio.c>
Ratios off
</IfModule>


# Delay engine reduces impact of the so-called Timing Attack described in
# http://www.securityfocus.com/bid/11430/discuss
# It is on by default. 
<IfModule mod_delay.c>
DelayEngine on
</IfModule>

<IfModule mod_ctrls.c>
ControlsEngine off
ControlsMaxClients 2
ControlsLog /var/log/proftpd/controls.log
ControlsInterval 5
ControlsSocket /var/run/proftpd/proftpd.sock
</IfModule>

<IfModule mod_ctrls_admin.c>
AdminControlsEngine off
</IfModule>

#
# Alternative authentication frameworks
#
#Include /etc/proftpd/ldap.conf
Include /etc/proftpd/sql.conf

#
# This is used for FTPS connections
#
#Include /etc/proftpd/tls.conf

#
# This is used for SFTP connections
#
#Include /etc/proftpd/sftp.conf

#
# This is used for other add-on modules
#
#Include /etc/proftpd/dnsbl.conf
#Include /etc/proftpd/geoip.conf
#Include /etc/proftpd/snmp.conf

#
# Useful to keep VirtualHost/VirtualRoot directives separated
#
#Include /etc/proftpd/virtuals.conf

# A basic anonymous configuration, no upload directories.

# <Anonymous ~ftp>
#   User ftp
#   Group nogroup
#   # We want clients to be able to login with "anonymous" as well as "ftp"
#   UserAlias anonymous ftp
#   # Cosmetic changes, all files belongs to ftp user
#   DirFakeUser on ftp
#   DirFakeGroup on ftp
# 
#   RequireValidShell off
# 
#   # Limit the maximum number of anonymous logins
#   MaxClients 10
# 
#   # We want 'welcome.msg' displayed at login, and '.message' displayed
#   # in each newly chdired directory.
#   DisplayLogin welcome.msg
#   DisplayChdir .message
# 
#   # Limit WRITE everywhere in the anonymous chroot
#   <Directory *>
#     <Limit WRITE>
#       DenyAll
#     </Limit>
#   </Directory>
# 
#   # Uncomment this if you're brave.
#   # <Directory incoming>
#   #   # Umask 022 is a good standard umask to prevent new files and dirs
#   #   # (second parm) from being group and world writable.
#   #   Umask022  022
#   #   <Limit READ WRITE>
#   #     DenyAll
#   #     </Limit>
#   #       <Limit STOR>
#   #         AllowAll
#   #     </Limit>
#   # </Directory>
# 
# </Anonymous>

# Include other custom configuration files
# !! Please note, that this statement will read /all/ file from this subdir,
# i.e. backup files created by your editor, too !!!
# Eventually create file patterns like this: /etc/proftpd/conf.d/*.conf
# 
Include /etc/proftpd/conf.d/

#
# Proftpd sample configuration for SFTP connections.
#
# Once enabled, you can even disable the sftpserver support of OpenSSH on port 22.
# To do that, comment out the Subsystem sftp /usr/lib/openssh/sftp-server
# line in /etc/ssh/sshd_config and restart the service.
#

<IfModule mod_sftp.c>
  <VirtualHost 0.0.0.0>
    SFTPEngine                      on
    Port                            2222
    SFTPAuthMethods                 password
    RequireValidShell               off
    SFTPLog /var/log/proftpd/sftp.log
    Include /etc/proftpd/sql.conf
    #
    # Configure all host keys, using the same host key
    # files that OpenSSH uses.
    #
    SFTPHostKey /etc/ssh/ssh_host_rsa_key
    SFTPHostKey /etc/ssh/ssh_host_dsa_key
    #SFTPHostKey /etc/ssh/ssh_host_rsa_key
    #SFTPHostKey /etc/ssh/ssh_host_ecdsa_key
    #SFTPHostKey /etc/ssh/ssh_host_ed25519_key
    #
    # Preferred authentication method is by keys
    #
    SFTPAuthMethods publickey password
    #
    # This is available only if mod_sftp_pam is used
    # 
    #SFTPAuthMethods keyboard-interactive
    #
    # Use either
    #    ssh-keygen -e -f ~user/.ssh/id_rsa.pub >/etc/proftpd/authorized_keys/user
    # or
    #    ssh-keygen -e -f ~user/.ssh/authorized_keys >/etc/proftpd/authorized_keys/user
    # to convert users public keys in RFC4716 format.
    #
    SFTPAuthorizedUserKeys file:/etc/proftpd/authorized_keys/%u
    #
    # Enable compression
    #
    SFTPCompression                 delayed
    DefaultRoot                     ~
  </VirtualHost>
</IfModule>

# Time stamp - IP Address - Protocol - User Name - UID - Filename - File Sizeo - Response Time in Milliseconds - Transfer Time in Seconds - Transfer Status - Reason for failure if applicable
#  http://www.proftpd.org/docs/modules/mod_log.html#LogFormat
LogFormat custom "%{iso8601} %a %{protocol} %u %{uid} %f %{file-size} %R %T %{transfer-status} %{transfer-failure}"
ExtendedLog /var/log/proftpd/custom.log READ,WRITE custom
EOT

cat << EOT >  /etc/proftpd/modules.conf
#
# This file is used to manage DSO modules and features.
#

# This is the directory where DSO modules reside

ModulePath /usr/lib/proftpd

# Allow only user root to load and unload modules, but allow everyone
# to see which modules have been loaded

ModuleControlsACLs insmod,rmmod allow user root
ModuleControlsACLs lsmod allow user *

#This is required only if you need to set IdentLookups on
#LoadModule mod_ident.c

LoadModule mod_ctrls_admin.c

# Install proftpd-mod-crypto to use this module for TLS/SSL support.
LoadModule mod_tls.c
# Even these modules depend on the previous one
#LoadModule mod_tls_fscache.c
#LoadModule mod_tls_shmcache.c

# Install one of proftpd-mod-mysql, proftpd-mod-pgsql or any other
# SQL backend engine to use this module and the required backend.
# This module must be mandatory loaded before anyone of
# the existent SQL backeds.
LoadModule mod_sql.c

# Install proftpd-mod-ldap to use this for LDAP support.
#LoadModule mod_ldap.c

#
# 'SQLBackend mysql' or 'SQLBackend postgres' (or any other valid backend) directives 
# are required to have SQL authorization working. You can also comment out the
# unused module here, in alternative.
#

# Install proftpd-mod-mysql and decomment the previous
# mod_sql.c module to use this.
LoadModule mod_sql_mysql.c

# Install proftpd-mod-pgsql and decomment the previous 
# mod_sql.c module to use this.
#LoadModule mod_sql_postgres.c

# Install proftpd-mod-sqlite and decomment the previous
# mod_sql.c module to use this
#LoadModule mod_sql_sqlite.c

# Install proftpd-mod-odbc and decomment the previous
# mod_sql.c module to use this
#LoadModule mod_sql_odbc.c

# Install one of the previous SQL backends and decomment 
# the previous mod_sql.c module to use this
#LoadModule mod_sql_passwd.c

LoadModule mod_radius.c
LoadModule mod_quotatab.c
LoadModule mod_quotatab_file.c

# Install proftpd-mod-ldap to use this
#LoadModule mod_quotatab_ldap.c

# Install one of the previous SQL backends and decomment 
# the previous mod_sql.c module to use this
#LoadModule mod_quotatab_sql.c
LoadModule mod_quotatab_radius.c
# Install proftpd-mod-wrap module to use this
#LoadModule mod_wrap.c
LoadModule mod_rewrite.c
LoadModule mod_load.c
LoadModule mod_ban.c
LoadModule mod_wrap2.c
LoadModule mod_wrap2_file.c
# Install one of the previous SQL backends and decomment 
# the previous mod_sql.c module to use this
#LoadModule mod_wrap2_sql.c
LoadModule mod_dynmasq.c
LoadModule mod_exec.c
LoadModule mod_shaper.c
LoadModule mod_ratio.c
LoadModule mod_site_misc.c

# Install proftpd-mod-crypto to use this module for SFTP support.
LoadModule mod_sftp.c
#LoadModule mod_sftp_pam.c

# Install one of the previous SQL backends and decomment 
# the previous mod_sql.c module to use this
#LoadModule mod_sftp_sql.c

LoadModule mod_facl.c
LoadModule mod_unique_id.c
LoadModule mod_copy.c
LoadModule mod_deflate.c
LoadModule mod_ifversion.c
LoadModule mod_memcache.c
# Install proftpd-mod-crypto to use this module for TLS/SSL support.
#LoadModule mod_tls_memcache.c

#LoadModule mod_redis.c
# Install proftpd-mod-crypto to use this module for TLS/SSL support.
#LoadModule mod_tls_redis.c
#LoadModule mod_wrap2_redis.c

#LoadModule mod_auth_otp.c

LoadModule mod_readme.c

# Install proftpd-mod-geoip to use the GeoIP feature
#LoadModule mod_geoip.c

# Install proftpd-mod-snmp to use the SNMP feature
#LoadModule mod_snmp.c

# keep this module the last one
LoadModule mod_ifsession.c
EOT

cat << EOT >  /etc/proftpd/sql.conf
#
# Proftpd sample configuration for SQL-based authentication.
#
# (This is not to be used if you prefer a PAM-based SQL authentication)
#

<IfModule mod_sql.c>
    AuthOrder mod_sql.c
    #
    # Choose a SQL backend among MySQL or PostgreSQL.
    # Both modules are loaded in default configuration, so you have to specify the backend 
    # or comment out the unused module in /etc/proftpd/modules.conf.
    # Use 'mysql' or 'postgres' as possible values.
    #
    SQLBackend	mysql
    #
    SQLEngine on
    SQLAuthenticate on
    #
    # Use both a crypted or plaintext password 
    SQLAuthTypes OpenSSL Crypt
    #
    # Use a backend-crypted or a crypted password
    #SQLAuthTypes Backend Crypt 
    #
    # Connection 
    SQLConnectInfo ${FTP_DB_NAME}@${FTP_DB_HOST}:${FTP_DB_PORT} ${FTP_DB_USER} $(cat /etc/my-passwd)
    #
    # Describes both users/groups tables
    #
    #SQLUserInfo users userid passwd uid gid homedir shell
    SQLUserInfo     ftpuser userid passwd uid gid homedir shell
    #SQLGroupInfo groups groupname gid members
    SQLGroupInfo    ftpgroup groupname gid members
    #
    # set min UID and GID - otherwise these are 999 each
    SQLMinID        500

    # Now that we have a default connection, we can create another connection, named "logdb" and using the "mysql" backend, to the logdb database
    SQLNamedConnectInfo logdb mysql ${FTP_DB_NAME}@${FTP_DB_HOST}:${FTP_DB_PORT} ${FTP_DB_USER} $(cat /etc/my-passwd)

    # Add a row to the login_history table on successful login in the logdb
    SQLNamedQuery log_sess FREEFORM "INSERT INTO \`login_history\` (\`user\`, \`client_ip\`, \`server_ip\`, \`protocol\`, \`when\`) VALUES ('%u', '%a', '%V', '%{protocol}', NOW())" logdb


    # Update count every time user logs in
    SQLLog PASS updatecount
    SQLNamedQuery updatecount UPDATE "count=count+1, accessed=now() WHERE userid='%u'" ftpuser

    # Update modified everytime user uploads or deletes a file
    SQLLog  STOR,DELE modified
    SQLNamedQuery modified UPDATE "modified=now() WHERE userid='%u'" ftpuser
    SqlLogFile /var/log/proftpd/sql.log

    # Update the users.last_accessed column on successful login in the userdb
    SQLNamedQuery last_accessed UPDATE "accessed = NOW() WHERE userid='%u'" ftpuser

    SQLLog PASS last_accessed

    SQLLog PASS log_sess IGNORE_ERRORS
</IfModule>
EOT
systemctl enable proftpd
systemctl restart proftpd