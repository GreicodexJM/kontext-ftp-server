/**
User Information Table

Column 	Type 	Required? 	Duplicates? 	Null? 	Purpose
userid 	text 	yes 	no 	no 	user's login
passwd 	text 	yes 	yes 	no 	user's password
uid 	number 	yes 	no2 	yes 	user's UID
gid 	number 	no 	yes 	yes 	user's GID
home3 	text 	no 	yes 	yes 	user's home
shell4 	text 	no 	yes 	yes 	user's shell

 The following illustrates how SQLNamedConnectInfo can be used. We have two databases, a "userdb" 
 containing the tables with our user data, and a "logdb" database containing various logging tables. 
 
 First, in the users table schema in the userdb database, let's include a users.last_accessed column, 
 indicating when that user last logged in successfully: 
**/
CREATE DATABASE IF NOT EXISTS ftpserver;
USE ftpserver;
CREATE TABLE IF NOT EXISTS `ftpuser` (
    `id` INT(10) UNSIGNED NOT NULL AUTO_INCREMENT,
    `userid` VARCHAR(32) COLLATE UTF8_GENERAL_CI NOT NULL DEFAULT '',
    `passwd` VARCHAR(32) COLLATE UTF8_GENERAL_CI NOT NULL DEFAULT '',
    `user_key` VARCHAR(8192) NOT NULL DEFAULT '',
    `uid` SMALLINT(6) NOT NULL DEFAULT '5500',
    `gid` SMALLINT(6) NOT NULL DEFAULT '5500',
    `homedir` VARCHAR(255) COLLATE UTF8_GENERAL_CI NOT NULL DEFAULT '',
    `shell` VARCHAR(16) COLLATE UTF8_GENERAL_CI NOT NULL DEFAULT '/sbin/nologin',
    `count` INT(11) NOT NULL DEFAULT '0',
    `accessed` DATETIME NOT NULL DEFAULT '0000-00-00 00:00:00',
    `modified` DATETIME NOT NULL DEFAULT '0000-00-00 00:00:00',
    PRIMARY KEY (`id`),
    UNIQUE KEY `userid` (`userid`))
  ENGINE=InnoDB DEFAULT CHARSET=UTF8 COLLATE = UTF8_GENERAL_CI 
   COMMENT='ProFTP user table';
CREATE INDEX ftpusers_userid_idx ON ftpuser (userid);

/**s
Group Information Table

Column 	Type 	Required? 	Null? 	Purpose
groupname 	text 	yes 	no 	group's name
gid 	number 	yes 	no 	group's GID
members2 	text 	yes 	yes 	group's members

(Note: if you plan to reuse the same UID for multiple users, then you will need to remove the UNIQUE 
from the uid column description). To create a group table:
*/
CREATE TABLE IF NOT EXISTS `ftpgroup` ( 
     `groupname` varchar(16) COLLATE utf8_general_ci NOT NULL,
     `gid` smallint(6) NOT NULL DEFAULT '5500', 
     `members` varchar(16) COLLATE utf8_general_ci NOT NULL, 
     KEY `groupname` (`groupname`) ) 
    ENGINE=InnoDB DEFAULT CHARSET=utf8 COLLATE=utf8_general_ci 
    COMMENT='ProFTP group table'; 
CREATE INDEX ftpgroups_gid_idx ON ftpgroup (gid);


CREATE TABLE sftphostkeys (
  host VARCHAR(256) NOT NULL,
  host_key VARCHAR(8192) NOT NULL
);
CREATE INDEX sftphostkeys_idx ON sftphostkeys (host);