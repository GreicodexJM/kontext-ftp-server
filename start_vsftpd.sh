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
      sleep 1
  done
  return $WAITFORIT_result
}

## Set Environment Variables for Database access
if [ -z "$DB_HOST" ]; then
  DB_HOST=database
fi
sed -i -e "s/users.host\s*=\s*database/users.host = $DB_HOST/g" /etc/pam_mysql.conf 

if [ -z "$DB_NAME" ]; then
  DB_NAME=ftp_users
fi
sed -i -e "s/users.database\s*=\s*database/users.database = $DB_NAME/g" /etc/pam_mysql.conf 

if [ -z "$DB_USER" ]; then
  DB_USER=db_username
fi
sed -i -e "s/users.db_user\s*=\s*database/users.db_user = $DB_USER/g" /etc/pam_mysql.conf 

if [ -z "$DB_PASSWD" ]; then
  DB_PASSWD=db_password
fi
sed -i -e "s/users.db_passwd\s*=\s*database/users.db_passwd = $DB_PASSWD/g" /etc/pam_mysql.conf 

SITE=${SITE:-ftp.greicodex.com}
S3_BUCKET=${S3_BUCKET:-fake_s3}
S3_ACCESS_KEY_ID=${S3_ACCESS_KEY_ID:-s3_accessid}
S3_SECRET_ACCESS_KEY=${S3_SECRET_ACCESS_KEY:-s3_accesskey}


function db_addgroup () {
  echo "Add Group $@"
}

function db_adduser () {
  echo "Add User $@"
}

function setup_folder () {
  FOLDER=$1
  NAME=$2
  GROUP=$3
  echo "mkdir -p $FOLDER"
  echo "chown $NAME:$GROUP $FOLDER"
}

#Remove all ftp users
grep '/ftp/' /etc/passwd | cut -d':' -f1 | xargs -r -n1 deluser

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
    FOLDER="/ftp/ftp/$NAME"
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
$( s3fs $S3_BUCKET /ftp/ftp -o passwd_file=/etc/passwd-s3fs -o dbglevel=info -o curldbg -o nonempty -o url=$S3_URL -o use_path_request_style )

# Used to run custom commands inside container
if [ ! -z "$1" ]; then
  exec "$@"
else
  echo "Starting VSFTPD..."
  vsftpd -opasv_min_port=$MIN_PORT -opasv_max_port=$MAX_PORT $ADDR_OPT $TLS_OPT /etc/vsftpd/vsftpd.conf
  [ -d /var/run/vsftpd ] || mkdir /var/run/vsftpd
  pgrep vsftpd | tail -n 1 > /var/run/vsftpd/vsftpd.pid
  exec pidproxy /var/run/vsftpd/vsftpd.pid true
fi
