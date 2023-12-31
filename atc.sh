#!/bin/sh
 export DEBIAN_FRONTEND="noninteractive"
 
 set -x
  
 LOG_PIPE=/tmp/log.pipe.$$                                                                                                                                                                                                                   
 mkfifo ${LOG_PIPE}
 LOG_FILE=/root/freepbx.log
 touch ${LOG_FILE}
 chmod 600 ${LOG_FILE}
  
 tee < ${LOG_PIPE} ${LOG_FILE} &
  
 exec > ${LOG_PIPE}
 exec 2> ${LOG_PIPE}
  
 echo deb http://ftp.us.debian.org/debian/ buster-backports main > /etc/apt/sources.list.d/backports.list
 echo deb-src http://ftp.us.debian.org/debian/ buster-backports main >> /etc/apt/sources.list.d/backports.list
  
 apt-get update -y
 apt-get upgrade -y
  
 #Install all the necessary packages
  
 apt-get install -y build-essential openssh-server apache2 mariadb-server mariadb-client bison flex php php-curl php-cli php-pdo php-mysql php-pear php-gd php-mbstring php-intl php-bcmath curl sox libncurses5-dev libssl-dev mpg123 libxml2-dev libnewt-dev sqlite3 libsqlite3-dev pkg-config automake libtool autoconf git unixodbc-dev uuid uuid-dev libasound2-dev libogg-dev libvorbis-dev libicu-dev libcurl4-openssl-dev libical-dev libneon27-dev libsrtp2-dev libspandsp-dev subversion libtool-bin python-dev unixodbc dirmngr sendmail-bin sendmail asterisk debhelper-compat cmake libmariadb-dev odbc-mariadb php-ldap
  
 #Install Node.js
  
 curl -sL https://deb.nodesource.com/setup_11.x | bash -
 apt-get install -y nodejs
  
 #Install this required Pear module
  
 pear install Console_Getopt
 
 #Prepare Asterisk
  
 systemctl stop asterisk
 systemctl disable asterisk
 mkdir /etc/asterisk/DIST
 mv /etc/asterisk/* /etc/asterisk/DIST
 cp /etc/asterisk/DIST/asterisk.conf /media/
 sed -i 's/(!)//' /etc/asterisk/DIST/asterisk.conf
 touch /etc/asterisk/modules.conf
 touch /etc/asterisk/cdr.conf
  
 #Configure Apache web server
  
 sed -i 's/\(^upload_max_filesize = \).*/\120M/' /etc/php/7.3/apache2/php.ini
 sed -i 's/\(^memory_limit = \).*/\1256M/' /etc/php/7.3/apache2/php.ini
 sed -i 's/^\(User\|Group\).*/\1 asterisk/' /etc/apache2/apache2.conf
 sed -i 's/AllowOverride None/AllowOverride All/' /etc/apache2/apache2.conf
 systemctl restart apache2
 rm /var/www/html/index.html
  
 #Configure ODBC
  
 cat > /etc/odbcinst.ini << EOF
 [MySQL]
 Description = ODBC for MySQL (MariaDB)
 Driver = /usr/lib/x86_64-linux-gnu/odbc/libmaodbc.so
 FileUsage = 1
 EOF
   
 cat > /etc/odbc.ini << EOF
 [MySQL-asteriskcdrdb]
 Description = MySQL connection to 'asteriskcdrdb' database
 Driver = MySQL
 Server = localhost
 Database = asteriskcdrdb
 Port = 3306
 Socket = /var/run/mysqld/mysqld.sock
 Option = 3
 EOF
  
 #Download FFMPEG static build for sound file manipulation
 wget --directory-prefix=/usr/local/src https://johnvansickle.com/ffmpeg/releases/ffmpeg-release-amd64-static.tar.xz
 tar -C /usr/local/src/ -xvf /usr/local/src/ffmpeg-release-amd64-static.tar.xz
 mv /usr/local/src/ffmpeg-4.4-amd64-static/ffmpeg /usr/local/bin
 #Install FreePBX
 cd /usr/local/src
 wget http://mirror.freepbx.org/modules/packages/freepbx/freepbx-15.0-latest.tgz
 tar zxvf freepbx-15.0-latest.tgz
 cd /usr/local/src/freepbx/
 ./start_asterisk start
 ./install -n
 fwconsole ma installall
 fwconsole reload
 cd /usr/share/asterisk
 mv sounds sounds-DIST
 ln -s /var/lib/asterisk/sounds sounds
 fwconsole restart
  
 cat >/etc/systemd/system/freepbx.service<< EOF
 [Unit]
 Description=FreePBX VoIP Server
 After=mariadb.service
 [Service]
 Type=oneshot
 RemainAfterExit=yes
 ExecStart=/usr/sbin/fwconsole start -q
 ExecStop=/usr/sbin/fwconsole stop -q
 [Install]
 WantedBy=multi-user.target
 EOF
  
 systemctl daemon-reload
  
 ps -aux | grep /usr/sbin/asterisk | grep -v grep| awk '{print $2}' | xargs kill
 systemctl enable asterisk.service
 systemctl start asterisk
  
 a2enmod rewrite
 
 service apache2 restart
