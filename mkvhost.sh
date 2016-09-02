#!/bin/bash

DIR=$1
SHORTNAME=$2
FQDN=$3

if [ `whoami` != root ]; then
  echo 'Error: root only.'
  exit 1;
fi
if [ -z $DIR ] || \
  [ -z $SHORTNAME ] || \
  [ -z $FQDN ]; then
  echo 'Usage: '$0' [Directory] [Shortname] [FQDN]'
  exit 1;
fi

if [ -e /etc/apache2/sites-available/$SHORTNAME ] || \
  [ -e /etc/apache2/sites-available/$SHORTNAME-redirect ] || \
  [ -e /etc/logrotate.d/apache2-$SHORTNAME ] || \
  [ -e /etc/awstats/awstats.$SHORTNAME.conf ] || \
  [ -e /etc/awstats/awstats.$SHORTNAME-redirect.conf ] || \
  [ -e /etc/cron.d/awstats-$SHORTNAME ] ; then
  echo 'FQDN or shortname used. Please change another one.'
  exit 1;
fi

echo '
*****************************************************************************
  makevhost
  This script helps you build a virtual host fast
*****************************************************************************
Your configration:
  + Directory: '$DIR'
     * must be a full path WITHOUT trailing slash.
     * Root dir to server will be '$DIR'/www
     * Logs will go to '$DIR'/logs, feel free to replace
       it with a softlink dir.
     * Awstats log will go to '$DIR'/awstats, also can be softlinked.
  + Short name: '$SHORTNAME'

When complete, script will enable site '$SHORTNAME',
another site conf called '$SHORTNAME'-redirect will also be created,
which will send 301 to the real site.

To remove generated site, run rmvhost.sh.

'
if [ -e $DIR/awstats.conf ] || \
  [ -e $DIR/awstats-cron ] || \
  [ -e $DIR/logrotate ] || \
  [ -e $DIR/vhost.conf ] || \
  [ -e $DIR/vhost-redirect.conf ] ; then
  echo '** WARNING **: There will be config file(s) being overwritten.

'
fi

echo 'Press Ctrl+C to escape if incorrect.'
read -p 'Enter to continue. <Enter or Ctrl+C>'

echo '* mkdir dir ...'

mkdir -p $DIR
mkdir -p $DIR/www
mkdir -p $DIR/var
chown -R www-data:www-data $DIR/var
mkdir -p $DIR/awstats
mkdir -p $DIR/logs
touch $DIR/logs/access.log
touch $DIR/logs/access-redirect.log
chown root:root $DIR $DIR/awstats $DIR/logs $DIR/logs/access.log $DIR/logs/access-redirect.log

echo '* vhost conf ...'

#site script
echo '<VirtualHost *:80>
  ServerName '$FQDN'
  #ServerAlias '$FQDN'
  ServerAdmin webmaster@'$FQDN'

  DocumentRoot '$DIR'/www

  <Directory />
    Options FollowSymLinks
    AllowOverride None
  </Directory>
  <Directory '$DIR'/www/>
    Options FollowSymLinks
    AllowOverride All
    Require all granted
  </Directory>

  ErrorLog '$DIR'/logs/error.log
  # Possible values include: debug, info, notice, warn, error, crit,
  # alert, emerg.
  LogLevel warn
  CustomLog '$DIR'/logs/access.log combined

</VirtualHost>' | tee $DIR/vhost.conf > /dev/null
chown root:root $DIR/vhost.conf
ln -s $DIR/vhost.conf /etc/apache2/sites-available/$SHORTNAME.conf

#redirection site script
echo '<VirtualHost *:80>
  # redirect vhost that issue 301 redirection to the real site.
  # Remember to edit awstats-redirect.conf

  #ServerName www.'$FQDN'
  #ServerAlias '$FQDN'.
  ServerAdmin webmaster@'$FQDN'

  DocumentRoot '$DIR'/www

  <Directory />
    Options FollowSymLinks
    AllowOverride None
  </Directory>
  <Directory '$DIR'/www/>
    Options FollowSymLinks
    AllowOverride All
    Require all granted

    RedirectMatch permanent ^/(.*)$ http://'$FQDN'/$1
  </Directory>

  ErrorLog '$DIR'/logs/error-redirect.log
  # Possible values include: debug, info, notice, warn, error, crit,
  # alert, emerg.
  LogLevel warn
  CustomLog '$DIR'/logs/access-redirect.log combined

</VirtualHost>' | tee $DIR/vhost-redirect.conf > /dev/null
chown root:root $DIR/vhost-redirect.conf
ln -s $DIR/vhost-redirect.conf /etc/apache2/sites-available/$SHORTNAME-redirect.conf


echo '* logrotate ...'

echo $DIR'/logs/*.log {
  weekly
  missingok
  rotate 52
  compress
  delaycompress
  compresscmd     /bin/bzip2
  compressoptions --best
  uncompresscmd   /bin/bunzip2
  compressext     .bz2
  notifempty
  create 644 root root
  sharedscripts
  prerotate
    [ ! -d /etc/awstats ] || /usr/lib/cgi-bin/awstats.pl -update -config='$SHORTNAME'
    [ ! -d /etc/awstats ] || /usr/lib/cgi-bin/awstats.pl -update -config='$SHORTNAME'-redirect
  endscript
  postrotate
    if [ -f /var/run/apache2/apache2.pid ]; then
      /etc/init.d/apache2 restart > /dev/null
    fi
  endscript
}' | tee $DIR/logrotate > /dev/null
chown root:root $DIR/logrotate
ln -s $DIR/logrotate /etc/logrotate.d/apache2-$SHORTNAME

echo '* awststs ...'

echo 'Include "/etc/awstats/awstats.conf"
SiteDomain="'$FQDN'"
LogFile="'$DIR'/logs/access.log"
LogFormat=1
DirData="'$DIR'/awstats"
HostAliases="'$FQDN' localhost 127.0.0.1"
' | tee $DIR/awstats.conf > /dev/null
chown root:root $DIR/awstats.conf

echo 'Include "/etc/awstats/awstats.conf"
SiteDomain="'$FQDN'"
LogFile="'$DIR'/logs/access-redirect.log"
LogFormat=1
DirData="'$DIR'/awstats"
HostAliases="'$FQDN' localhost 127.0.0.1"
' | tee $DIR/awstats-redirect.conf > /dev/null
chown root:root $DIR/awstats-redirect.conf

#awstats crontab
echo $(date +%S)' * * * * root [ -x /usr/lib/cgi-bin/awstats.pl -a -f /etc/awstats/awstats.'$SHORTNAME'.conf ] && /usr/lib/cgi-bin/awstats.pl -config='$SHORTNAME' -update >/dev/null
'$(date +%S)' * * * * root [ -x /usr/lib/cgi-bin/awstats.pl -a -f /etc/awstats/awstats.'$SHORTNAME'-redirect.conf ] && /usr/lib/cgi-bin/awstats.pl -config='$SHORTNAME'-redirect -update >/dev/null' | tee $DIR/awstats-cron > /dev/null
chown root:root $DIR/awstats-cron

if [ ! -d /etc/awstats ] ; then
  echo 'Warning: awstats not installed. conf files will be created but not linked.'
else
  ln -s $DIR/awstats.conf /etc/awstats/awstats.$SHORTNAME.conf
  ln -s $DIR/awstats-redirect.conf /etc/awstats/awstats.$SHORTNAME-redirect.conf
  ln -s $DIR/awstats-cron /etc/cron.d/awstats-$SHORTNAME

  #remove awstats nested include
  cat /etc/awstats/awstats.conf | sed -i -e 's/^Include/#Include/' /etc/awstats/awstats.conf
fi

echo '* enable site ...'
a2ensite $SHORTNAME > /dev/null

echo '

Done.
Please
   apache2ctl graceful
to load the config of the website gracefully.
You might want to edit '$DIR'/vhost.conf before doing that,
depends on your application configration.
'
