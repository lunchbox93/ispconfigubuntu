#
#                    ##        .
#              ## ## ##       ==
#           ## ## ## ##      ===
#       /""""""""""""""""\___/ ===
#  ~~~ {~~ ~~~~ ~~~ ~~~~ ~~ ~ /  ===- ~~~
#       \______ o          __/
#         \    \        __/
#          \____\______/
#
#          |          |
#       __ |  __   __ | _  __   _
#      /  \| /  \ /   |/  / _\ |
#      \__/| \__/ \__ |\_ \__  |
#
#
# Ubuntu 18.04, Apache, PHP, MySQL, PureFTPD, BIND, Postfix, Dovecot, Roundcube and ISPConfig 3.1
#
# Link Referência 
# https://www.howtoforge.com/tutorial/perfect-server-ubuntu-18.04-with-apache-php-myqsl-pureftpd-bind-postfix-doveot-and-ispconfig/3/
#

FROM ubuntu:18.04

MAINTAINER Starflux Solutions <admin@starfluxsolutions.com> version: 0.1

# --- 1 Prepare Server
RUN apt-get -y update && apt-get -y upgrade
ARG DEBIAN_FRONTEND=noninteractive
RUN apt-get -y update && apt-get -y upgrade && apt-get -y install apt-utils patch rsyslog patch logrotate supervisor screenfetch apt-utils

# --- 2 Install SSH server, rsync, and enable keys
RUN apt-get -qq update && apt-get -y -qq install ssh certbot openssh-server rsync && \
    mkdir /root/.ssh && touch /root/.ssh/authorized_keys
RUN sed -i 's/^#AuthorizedKeysFile/AuthorizedKeysFile/g' /etc/ssh/sshd_config

# --- 3 Fix dash shell
RUN echo "dash dash/sh boolean false" | debconf-set-selections
RUN dpkg-reconfigure dash

# --- 4 Disable Apparmor
#RUN service apparmor stop
#RUN update-rc.d -f apparmor remove 
#RUN apt-get remove apparmor apparmor-utils

# --- 5 Synchronize the System Clock
ENV TZ=America/Chicago
RUN ln -snf /usr/share/zoneinfo/$TZ /etc/localtime && echo $TZ > /etc/timezone

# --- 6 Remove sendmail
RUN echo -n "Removing Sendmail... "	service sendmail stop hide_output update-rc.d -f sendmail remove apt_remove sendmail

# --- 7 Install Postfix, Dovecot, MySQL, phpMyAdmin, rkhunter, binutils
RUN echo "mariadb-server  mariadb-server/root_password_again password pass" | debconf-set-selections
RUN echo "mariadb-server  mariadb-server/root_password password pass" | debconf-set-selections
RUN echo "mariadb-server-10.0 mysql-server/root_password password pass" | debconf-set-selections
RUN echo "mariadb-server-10.0 mysql-server/root_password_again password pass" | debconf-set-selections
RUN echo -n "Installing SMTP Mail server (Postfix)... " \
&& echo "postfix postfix/main_mailer_type select Internet Site" | debconf-set-selections \
&& echo "postfix postfix/mailname string control.starfluxsolutions.com" | debconf-set-selections
RUN apt-get -y install postfix postfix-mysql amavisd-new spamassassin unzip fail2ban ufw bzip2 arj nomarch lzop cabextract apt-listchanges libnet-ldap-perl libauthen-sasl-perl daemon libio-string-perl libio-socket-ssl-perl libnet-ident-perl zip libnet-dns-perl postgrey mariadb-client mariadb-server openssl getmail4 binutils dovecot-imapd dovecot-pop3d dovecot-mysql dovecot-sieve dovecot-lmtpd sudo
ADD ./etc/postfix/master.cf /etc/postfix/master.cf
RUN mv /etc/mysql/mariadb.conf.d/50-server.cnf /etc/mysql/mariadb.conf.d/50-server.cnf.backup
ADD ./etc/mysql/mariadb.conf.d/50-server.cnf /etc/mysql/mariadb.conf.d/50-server.cnf
RUN mv /etc/mysql/debian.cnf /etc/mysql/debian.cnf.backup
ADD ./etc/mysql/debian.cnf /etc/mysql/debian.cnf
ADD ./etc/security/limits.conf /etc/security/limits.conf
RUN mkdir -p /etc/systemd/system/mysql.service.d/
ADD ./etc/systemd/system/mysql.service.d/limits.conf /etc/systemd/system/mysql.service.d/limits.conf
RUN service spamassassin stop && systemctl disable spamassassin
RUN update-rc.d -f spamassassin remove

# -- 10 Install XMPP Server
# RUN apt-get -qq update && apt-get -y -qq install git lua5.1 liblua5.1-0-dev lua-filesystem libidn11-dev libssl-dev lua-zlib lua-expat lua-event lua-bitop lua-socket lua-sec luarocks luarocks
# RUN luarocks install lpc
# RUN adduser --no-create-home --disabled-login --gecos 'Metronome' metronome
# RUN cd /opt && git clone https://github.com/maranda/metronome.git metronome
# RUN cd /opt/metronome && ./configure --ostype=debian --prefix=/usr && make && make install

# --- 11 Install Apache2, PHP5, phpMyAdmin, FCGI, suExec, Pear, And mcrypt
RUN echo $(grep $(hostname) /etc/hosts | cut -f1) localhost >> /etc/hosts && apt-get -y install apache2 vlogger webalizer awstats geoip-database libclass-dbi-mysql-perl php7.2-opcache php-apcu php7.2-fpm apache2-utils libapache2-mod-php php7.2 php7.2-common php7.2-gd php7.2-mysql php7.2-imap php7.2-cli php7.2-cgi libapache2-mod-fcgid apache2-suexec-pristine php-pear mcrypt  imagemagick libruby libapache2-mod-python php7.2-curl php7.2-intl php7.2-pspell php7.2-recode php7.2-sqlite3 php7.2-tidy php7.2-xmlrpc php7.2-xsl memcached php-memcache php-imagick php-gettext php7.2-zip php7.2-mbstring php-soap php7.2-soap
RUN echo "ServerName localhost" > /etc/apache2/conf-available/servername.conf && a2enconf servername
ADD ./etc/apache2/conf-available/httpoxy.conf /etc/apache2/conf-available/httpoxy.conf
RUN a2enmod actions proxy_fcgi alias suexec rewrite ssl actions include dav_fs dav auth_digest cgi headers && a2enconf httpoxy && a2dissite 000-default && service apache2 restart
RUN service apache2 restart

# --- 14 Install HHVM (HipHop Virtual Machine)
#RUN apt-get -y install hhv

#RUN apt-get -y install python-certbot-apache

# --- 16 Install Mailman
# RUN echo 'mailman mailman/default_server_language en' | debconf-set-selections
# RUN apt-get -y install mailman
# ADD ./etc/aliases /etc/aliases
# RUN newaliases
# RUN service postfix restart
# RUN ln -s /etc/mailman/apache.conf /etc/apache2/conf-enabled/mailman.conf
RUN service apache2 restart

# --- 17 Install PureFTPd and Quota
# RUN apt-get -y install pure-ftpd-common pure-ftpd-mysql quota quotatool
# RUN sed -i 's/VIRTUALCHROOT=false/VIRTUALCHROOT=true/g'  /etc/default/pure-ftpd-common
# RUN sed -i 's/STANDALONE_OR_INETD=inetd/STANDALONE_OR_INETD=standalone/g'  /etc/default/pure-ftpd-common
# RUN sed -i 's/UPLOADSCRIPT=/UPLOADSCRIPT=\/etc\/pure-ftpd\/clamav_check.sh/g'  /etc/default/pure-ftpd-common
# ADD ./etc/pure-ftpd/clamav_check.sh /etc/pure-ftpd/clamav_check.sh
# RUN echo 2 > /etc/pure-ftpd/conf/TLS
# RUN echo 1 > /etc/pure-ftpd/conf/CallUploadScript
# RUN mkdir -p /etc/ssl/private/
# RUN openssl req -x509 -nodes -days 7300 -newkey rsa:2048 -subj "/C=DE/ST=Karlsruhe/L=Baden-Wuerttemberg/O=IT/CN=$HOSTNAME" -keyout /etc/ssl/private/pure-ftpd.pem -out /etc/ssl/private/pure-ftpd.pem
# RUN chmod 600 /etc/ssl/private/pure-ftpd.pem

# --- 18 Install BIND DNS Server
# RUN apt-get -y install bind9 dnsutils haveged
# RUN systemctl enable haveged


# --- 19 Install Vlogger, Webalizer, and AWStats
ADD etc/cron.d/awstats /etc/cron.d/

# --- 20 Install Jailkit
# RUN apt-get -y install build-essential autoconf automake libtool flex bison debhelper binutils
# RUN cd /tmp \
# && wget http://olivier.sessink.nl/jailkit/jailkit-2.19.tar.gz \
# && tar xvfz jailkit-2.19.tar.gz \
# && cd jailkit-2.19 \
# && echo 5 > debian/compat \
# && ./debian/rules binary \
# && cd /tmp \
# && rm -rf jailkit-2.19*

# --- 21 Install fail2ban
ADD ./etc/fail2ban/jail.local /etc/fail2ban/jail.local
ADD ./etc/fail2ban/filter.d/pureftpd.conf /etc/fail2ban/filter.d/pureftpd.conf
ADD ./etc/fail2ban/filter.d/dovecot-pop3imap.conf /etc/fail2ban/filter.d/dovecot-pop3imap.conf
RUN echo "ignoreregex =" >> /etc/fail2ban/filter.d/postfix-sasl.conf
#RUN service fail2ban restart


# --- 23 Install RoundCube
# RUN service mysql start && apt-get -y install roundcube roundcube-core roundcube-mysql roundcube-plugins
# ADD ./etc/apache2/conf-enabled/roundcube.conf /etc/apache2/conf-enabled/roundcube.conf
# ADD ./etc/roundcube/config.inc.php /etc/roundcube/config.inc.php
# RUN service apache2 restart

# --- 24 Install ISPConfig 3
RUN cd /root && wget http://www.ispconfig.org/downloads/ISPConfig-3-stable.tar.gz && tar xfz ISPConfig-3-stable.tar.gz


# Install ISPConfig
ADD ./autoinstall.ini /root/ispconfig3_install/install/autoinstall.ini
RUN service mysql restart && php -q /root/ispconfig3_install/install/install.php --autoinstall=/root/ispconfig3_install/install/autoinstall.ini
#ADD ./etc/apache2/ispconfig.vhost 
RUN sed -i 's/^NameVirtualHost/#NameVirtualHost/g' /etc/apache2/sites-enabled/ispconfig.vhost && sed -i 's/^NameVirtualHost/#NameVirtualHost/g' /etc/apache2/sites-enabled/ispconfig.conf
RUN service apache2 restart
ADD ./etc/postfix/master.cf /etc/postfix/master.cf

EXPOSE 20/tcp 21/tcp 22/tcp 53 80/tcp 443/tcp 953/tcp 8080/tcp 30000 30001 30002 30003 30004 30005 30006 30007 30008 30009 3306

# ISPCONFIG Initialization and Startup Script
ADD ./start.sh /start.sh
ADD ./supervisord.conf /etc/supervisor/supervisord.conf
ADD ./etc/cron.daily/sql_backup.sh /etc/cron.daily/sql_backup.sh
#ADD ./autoinstall.ini /tmp/ispconfig3_install/install/autoinstall.ini
RUN chmod 755 /start.sh
RUN mkdir -p /var/run/sshd
RUN mkdir -p /var/log/supervisor
RUN mv /bin/systemctl /bin/systemctloriginal
ADD ./bin/systemctl /bin/systemctl
RUN mkdir -p /var/backup/sql

RUN service mysql start \
&& echo "FLUSH PRIVILEGES;" | mysql -u root


RUN apt-get autoremove -y && apt-get clean

VOLUME ["/var/www/","/var/mail/","/var/backup/","/var/lib/mysql","/var/log/"]

# Must use double quotes for json formatting.
CMD ["/usr/bin/supervisord", "--configuration=/etc/supervisor/supervisord.conf"]

#CMD ["/bin/bash", "/start.sh"]
