#!/bin/bash

DIR=$1
SHORTNAME=$2
FQDN=$3

VHOSTPARM='*:80'
#VHOSTPARM='*'

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

sudo mkdir -p $DIR
sudo mkdir -p $DIR/www
sudo mkdir -p $DIR/var
sudo chown -R www-data:www-data $DIR/var
sudo mkdir -p $DIR/awstats
sudo mkdir -p $DIR/logs
sudo touch $DIR/logs/access.log
sudo touch $DIR/logs/access-redirect.log

echo '* vhost conf ...'

#site script
echo '<VirtualHost '$VHOSTPARM'>
	ServerName '$FQDN'
	#ServerAlias '$FQDN'
	ServerAdmin nobody@'$FQDN'

	DocumentRoot '$DIR'/www

	<Directory />
		Options FollowSymLinks
		AllowOverride None
	</Directory>
	<Directory '$DIR'/www/>
		Options FollowSymLinks ExecCGI
		# Remove ExecCGI if you do not need php
		AllowOverride All
		Order allow,deny
		allow from all
	</Directory>
	<Directorymatch "^/.*/.(hg|svn|git)/">
		Order deny,allow
		Deny from all
	</Directorymatch>

	ErrorLog '$DIR'/logs/error.log

	# Possible values include: debug, info, notice, warn, error, crit,
	# alert, emerg.
	LogLevel warn

	CustomLog '$DIR'/logs/access.log combined

</VirtualHost>' | sudo tee $DIR/vhost.conf > /dev/null
sudo ln -s $DIR/vhost.conf /etc/apache2/sites-available/$SHORTNAME

#redirection site script
echo '<VirtualHost '$VHOSTPARM'>

	# redirect vhost that issue 301 redirection to the real site.
	# Remember to edit awstats-redirect.conf
	
	#ServerName '$FQDN'
	#ServerAlias '$FQDN' 
	ServerAdmin nobody@'$FQDN'
	
	DocumentRoot '$DIR'/www

	<Directory />
		Options FollowSymLinks
		AllowOverride None
	</Directory>
	<Directory '$DIR'/www/>
		Options FollowSymLinks
		AllowOverride All
		Order allow,deny
		allow from all

		RedirectMatch permanent ^/(.*)$ http://'$FQDN'/$DIR
	</Directory>
	ErrorLog '$DIR'/logs/error-redirect.log

	# Possible values include: debug, info, notice, warn, error, crit,
	# alert, emerg.
	LogLevel warn

	CustomLog '$DIR'/logs/access-redirect.log combined

</VirtualHost>' | sudo tee $DIR/vhost-redirect.conf > /dev/null
sudo ln -s $DIR/vhost-redirect.conf /etc/apache2/sites-available/$SHORTNAME-redirect


echo '* logrotate ...'

echo $DIR'/logs/*.log {
	weekly
	missingok
	rotate 52
	compress
	delaycompress
	notifempty
	create 644 root root
	sharedscripts
	prerotate
		sudo -u root /usr/lib/cgi-bin/awstats.pl -update -config='$SHORTNAME'
		sudo -u root /usr/lib/cgi-bin/awstats.pl -update -config='$SHORTNAME'-redirect
	endscript
	postrotate
		if [ -f /var/run/apache2.pid ]; then
			/etc/init.d/apache2 restart > /dev/null
		fi
	endscript
}' | sudo tee $DIR/logrotate > /dev/null
sudo ln -s $DIR/logrotate /etc/logrotate.d/apache2-$SHORTNAME

echo '* awststs ...'

echo 'Include "/etc/awstats/awstats.conf"
SiteDomain="'$FQDN'"
LogFile="'$DIR'/logs/access.log"
LogFormat=1
DirData="'$DIR'/awstats"
HostAliases="'$FQDN' localhost 127.0.0.1"
' | sudo tee $DIR/awstats.conf > /dev/null
sudo ln -s $DIR/awstats.conf /etc/awstats/awstats.$SHORTNAME.conf

echo 'Include "/etc/awstats/awstats.conf"
SiteDomain="'$FQDN'"
LogFile="'$DIR'/logs/access-redirect.log"
LogFormat=1
DirData="'$DIR'/awstats"
HostAliases="'$FQDN' localhost 127.0.0.1"
' | sudo tee $DIR/awstats-redirect.conf > /dev/null
sudo ln -s $DIR/awstats-redirect.conf /etc/awstats/awstats.$SHORTNAME-redirect.conf

#awstats crontab
echo $(date +%S)' * * * * root [ -x /usr/lib/cgi-bin/awstats.pl -a -f /etc/awstats/awstats.'$SHORTNAME'.conf ] && /usr/lib/cgi-bin/awstats.pl -config='$SHORTNAME' -update >/dev/null
'$(date +%S)' * * * * root [ -x /usr/lib/cgi-bin/awstats.pl -a -f /etc/awstats/awstats.'$SHORTNAME'-redirect.conf ] && /usr/lib/cgi-bin/awstats.pl -config='$SHORTNAME'-redirect -update >/dev/null' | sudo tee $DIR/awstats-cron > /dev/null
sudo ln -s $DIR/awstats-cron /etc/cron.d/awstats-$SHORTNAME

#remove awstats nested include
cat /etc/awstats/awstats.conf | sudo sed -i -e 's/^Include/#Include/' /etc/awstats/awstats.conf

echo '* enable site ...'
sudo a2ensite $SHORTNAME > /dev/null

echo '

Done.
Please 
   sudo apache2ctl graceful
to load the config of the website gracefully.
You might want to edit '$DIR'/vhost.conf before doing that,
depends on your application configration.

Regards,

timdream'
