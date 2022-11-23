-- In the logdb database, let's define a table that we will use for separately logging all successful logins:
CREATE DATABASE IF NOT EXISTS ftpserver;
USE ftpserver;
CREATE TABLE login_history (
    user VARCHAR NOT NULL,
    client_ip VARCHAR NOT NULL,
    server_ip VARCHAR NOT NULL,
    protocol VARCHAR NOT NULL,
    when DATETIME
  );
