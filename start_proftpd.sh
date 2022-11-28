#!/bin/sh

set_env_default() {
  if [ -z "${$1}" ]; then
    $1=$2
  fi
  sed -i -e "s/users.$2\s*=\s*$2/users.$2 = $1/g" /etc/pam_mysql.conf 
}

wait_for() {
  WAITFORIT_cmdname=$0
  WAITFORIT_HOST=$1
  WAITFORIT_PORT=$2
  WAITFORIT_start_ts=$(date +%s)
  WAITFORIT_ISBUSY=1
  WAITFORIT_maxcount=10
  while :
  do
      if [[ $WAITFORIT_ISBUSY -eq 1 ]]; then
          nc -z $WAITFORIT_HOST $WAITFORIT_PORT
          WAITFORIT_result=$?
      else
          (echo -n > /dev/tcp/$WAITFORIT_HOST/$WAITFORIT_PORT) >/dev/null 2>&1
          WAITFORIT_result=$?
      fi
      if [[ $WAITFORIT_result -eq 0 ]]; then
          WAITFORIT_end_ts=$(date +%s)
          echo "$WAITFORIT_cmdname: $WAITFORIT_HOST:$WAITFORIT_PORT is available after $((WAITFORIT_end_ts - WAITFORIT_start_ts)) seconds"
          break
      fi
      if [[ $WAITFORIT_maxcount -eq 0 ]]; then
        echo "$WAITFORIT_cmdname: $WAITFORIT_HOST:$WAITFORIT_PORT time out"
        break
      fi  
      sleep 1
      let WAITFORIT_maxcount=WAITFORIT_maxcount-1
  done
  return $WAITFORIT_result
}

create_passwd() {
  /bin/echo "{md5}"`/bin/echo -n "$1" | openssl dgst -binary -md5 | openssl enc -base64`
}

## Set Environment Variables for Database access
if [ -z "$DB_HOST" ]; then
  DB_HOST=database
fi
if [ -z "$DB_NAME" ]; then
  DB_NAME=ftp_users
fi
if [ -z "$DB_USER" ]; then
  DB_USER=db_username
fi
if [ -z "$DB_PASSWD" ]; then
  DB_PASSWD=db_password
fi
sed -i \
    -e "s:{{dbhost}}:$DB_HOST:" \
    -e "s:{{database}}:$DB_NAME:" \
    -e "s:{{3306}}:3306:" \
    -e "s:{{mysql_user}}:$DB_USER:" \
    -e "s:{{mysql_password}}:$DB_PASSWD:" \
    /etc/proftpd/conf.d/mod_sql.conf


SITE=${SITE:-ftp.greicodex.com}
S3_BUCKET=${S3_BUCKET:-fake_s3}
S3_ACCESS_KEY_ID=${S3_ACCESS_KEY_ID:-s3_accessid}
S3_SECRET_ACCESS_KEY=${S3_SECRET_ACCESS_KEY:-s3_accesskey}


function db_addgroup () {
  echo "Add Group $@"
#  echo "INSERT INTO `ftpgroup` (groupname) VALUES ('$1');" | mysql -u$DB_USER -p$DB_PASSWD -h$DB_HOST $DB_NAME
}

function db_adduser () {
  echo "Add User $@"
  $user_passw=$( create_passwd $2 ) 
#  echo "INSERT INTO `ftpuser` (groupname) VALUES ('$1');" | mysql -u$DB_USER -p$DB_PASSWD -h$DB_HOST $DB_NAME
}

function setup_folder () {
  FOLDER=$1
  NAME=$2
  GROUP=$3
  echo "mkdir -p $FOLDER"
  echo "chown $NAME:$GROUP $FOLDER"
}

#Remove all ftp users
grep '/data/' /etc/passwd | cut -d':' -f1 | xargs -r -n1 deluser


if [ -z "$MIN_PORT" ]; then
  MIN_PORT=21000
fi
export MIN_PORT

if [ -z "$MAX_PORT" ]; then
  MAX_PORT=21010
fi
export MAX_PORT

if [ ! -z "$ADDRESS" ]; then
  ADDR_OPT="-opasv_address=$ADDRESS"
fi
export ADDR_OPT

if [ ! -z "$TLS_CERT" ] || [ ! -z "$TLS_KEY" ]; then
  TLS_OPT="-orsa_cert_file=$TLS_CERT -orsa_private_key_file=$TLS_KEY -ossl_enable=YES -oallow_anon_ssl=NO -oforce_local_data_ssl=YES -oforce_local_logins_ssl=YES -ossl_tlsv1=YES -ossl_sslv2=NO -ossl_sslv3=NO -ossl_ciphers=HIGH"
fi
export TLS_OPT

#modprobe fuse

wait_for storage 4566
sleep 10


echo $S3_ACCESS_KEY_ID:$S3_SECRET_ACCESS_KEY > /etc/passwd-s3fs
chmod 600 /etc/passwd-s3fs
S3FS_OPT="-o passwd_file=/etc/passwd-s3fs -o nonempty -o url=$S3_URL -o umask=0000,uid=100,gid=65533 -o enable_content_md5 -o allow_other -o rw -o nosuid -o nodev -o use_rrs -o use_cache=/tmp"
#S3FS_OPT="-o passwd_file=/etc/passwd-s3fs -o nonempty -o url=$S3_URL -o umask=0000,uid=0,gid=0 -o enable_content_md5 -o allow_other -o rw -o nosuid -o nodev -o use_rrs -o use_cache=/tmp"
if [ ! -z "$S3FS_DEBUG" ]; then
  S3FS_OPT+=" -o dbglevel=info -o curldbg "
fi
if [ ! -z "$S3FS_LEGACY" ]; then
  S3FS_OPT+=" -o compat_dir -o use_path_request_style "
fi
s3fs $S3_BUCKET /data/ftp -d $S3FS_OPT
# chown proftpd:proftpd -R /data

#Create users
#USERS='name1|password1|[folder1][|uid1][|gid1] name2|password2|[folder2][|uid2][|gid2]'
#may be:
# user|password foo|bar|/home/foo
#OR
# user|password|/home/user/dir|10000
#OR
# user|password|/home/user/dir|10000|10000
#OR
# user|password||10000|82

#Default user 'ftp' with password 'alpineftp'

if [ -z "$USERS" ]; then
  USERS="alpineftp|alpineftp"
fi

for i in $USERS ; do
  NAME=$(echo $i | cut -d'|' -f1)
  GROUP=$NAME
  PASS=$(echo $i | cut -d'|' -f2)
  FOLDER=$(echo $i | cut -d'|' -f3)
  UID=$(echo $i | cut -d'|' -f4)
  # Add group handling
  GID=$(echo $i | cut -d'|' -f5)

  if [ -z "$FOLDER" ]; then
    FOLDER="/data/ftp/$NAME"
  fi

  if [ ! -z "$UID" ]; then
    UID_OPT="-u $UID"
    if [ -z "$GID" ]; then
      GID=$UID
    fi
    #Check if the group with the same ID already exists
    GROUP=$(getent group $GID | cut -d: -f1)
    if [ ! -z "$GROUP" ]; then
      GROUP_OPT="-G $GROUP"
    elif [ ! -z "$GID" ]; then
      # Group don't exist but GID supplied
      db_addgroup -g $GID $NAME
      
      GROUP_OPT="-G $NAME"
    fi
  fi

  echo -e "$PASS\n$PASS" | db_adduser -h $FOLDER -s /sbin/nologin $UID_OPT $GROUP_OPT $NAME
  setup_folder $FOLDER $NAME $GROUP
  unset NAME PASS FOLDER UID GID
done



if [ ! -f /etc/timezone ] && [ ! -z "$TZ" ]; then
  # At first startup, set timezone
  cp /usr/share/zoneinfo/$TZ /etc/localtime
  echo $TZ >/etc/timezone
fi

if [ -z "$PASV_ADDRESS" ]; then
  echo "** This container will not run without setting for PASV_ADDRESS **"
  sleep 10
  exit 1
fi

# if [ -e /run/secrets/$FTPUSER_PASSWORD_SECRET ] && ! id -u "$FTPUSER_NAME"; then
#  adduser -u $FTPUSER_UID -s /bin/sh -g "ftp user" -D $FTPUSER_NAME
#  echo "$FTPUSER_NAME:$(cat /run/secrets/$FTPUSER_PASSWORD_SECRET)" \
#    | chpasswd -e
#fi

mkdir -p /run/proftpd && chown proftpd /run/proftpd/

sed -i \
    -e "s:{{ ALLOW_OVERWRITE }}:$ALLOW_OVERWRITE:" \
    -e "s:{{ ANONYMOUS_DISABLE }}:$ANONYMOUS_DISABLE:" \
    -e "s:{{ ANON_UPLOAD_ENABLE }}:$ANON_UPLOAD_ENABLE:" \
    -e "s:{{ LOCAL_UMASK }}:$LOCAL_UMASK:" \
    -e "s:{{ MAX_CLIENTS }}:$MAX_CLIENTS:" \
    -e "s:{{ MAX_INSTANCES }}:$MAX_INSTANCES:" \
    -e "s:{{ PASV_ADDRESS }}:$PASV_ADDRESS:" \
    -e "s:{{ PASV_MAX_PORT }}:$PASV_MAX_PORT:" \
    -e "s:{{ PASV_MIN_PORT }}:$PASV_MIN_PORT:" \
    -e "s+{{ SERVER_NAME }}+$SERVER_NAME+" \
    -e "s:{{ TIMES_GMT }}:$TIMES_GMT:" \
    -e "s:{{ WRITE_ENABLE }}:$WRITE_ENABLE:" \
    /etc/proftpd/proftpd.conf

exec proftpd --nodaemon -c /etc/proftpd/proftpd.conf


# Used to run custom commands inside container
if [ ! -z "$1" ]; then
  exec "$@"
else
  echo "Starting ProFTPD..."
  proftpd -n -c /etc/proftpd/proftpd.conf
  [ -d /var/run/proftpd ] || mkdir /var/run/proftpd
  pgrep proftpd | tail -n 1 > /var/run/proftpd/proftpd.pid
  exec pidproxy /var/run/proftpd/proftpd.pid true
fi
