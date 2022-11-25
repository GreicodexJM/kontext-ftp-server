-- In the logdb database, let's define a table that we will use for separately logging all successful logins:
CREATE DATABASE IF NOT EXISTS ftpserver;
USE ftpserver;
CREATE TABLE `login_history` (
    `user` VARCHAR(32) NOT NULL,
    `client_ip` VARCHAR(20) NOT NULL,
    `server_ip` VARCHAR(20) NOT NULL,
    `protocol` VARCHAR(10) NOT NULL,
    `when` DATETIME
  );
