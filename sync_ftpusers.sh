#!/bin/sh
echo 'SELECT homedir,uid,gid FROM `ftpuser`;'  | \
mysql -u$DB_USER -p$DB_PASSWD -h$DB_HOST $DB_NAME --batch --skip-column-names  | \
while read FTP_PATH FTP_UID FTP_GID; do 
    mkdir -p $FTP_PATH; 
    chown $FTP_UID:$FTP_GID $FTP_PATH;     
    find $FTP_PATH -type d -exec chmod 700 {} \;
    find $FTP_PATH -type f -exec chmod 100 {} \;
done;
