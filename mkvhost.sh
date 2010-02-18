if [ `whoami` != root ]; then
	echo 'Error: root only.'
	exit 1;
fi
if [ -z $1 ] || \
	[ -z $2 ] || \
	[ -z $3 ]; then
	echo 'Usage: '$0' [Directory] [Shortname] [FQDN]'
	exit 1;
fi

if [ -e /etc/apache2/sites-available/$2 ] || \
	[ -e /etc/apache2/sites-available/$2-redirect ] || \
	[ -e /etc/logrotate.d/apache2-$2 ] || \
	[ -e /etc/awstats/awstats.$2.conf ] || \
	[ -e /etc/awstats/awstats.$2-redirect.conf ] || \
	[ -e /etc/cron.d/awstats-$2 ] ; then
	echo 'FQDN or shortname used. Please change another one.'
	exit 1;
fi

echo '
*****************************************************************************
  makevhost
  This script helps you build a virtual host fast
*****************************************************************************
Your configration:
  + Directory: '$1'
     * must be a fill path WITHOUT trailing slash.
     * Root dir to server will be '$1'/www
     * Logs will go to '$1'/logs, feel free to replace 
       it with a softlink dir.
     * Awstats log will go to '$1'/awstats, also can be softlinked.
  + Short name: '$2'

When complete, script will enable site '$2', 
another site conf called '$2'-redirect will also be created,
which will send 301 to the real site.

To remove generated site, run rmvhost.sh.

'
if [ -e $1/awstats.conf ] || \
	[ -e $1/awstats-cron ] || \
	[ -e $1/logrotate ] || \
	[ -e $1/vhost.conf ] || \
	[ -e $1/vhost-redirect.conf ] ; then
	echo '** WARNING **: There will be config file(s) being overwritten.

'
fi

echo 'Press Ctrl+C to escape if incorrect.'
read -p 'Enter to continue. <Enter or Ctrl+C>
'

echo '* mkdir dir ...'

sudo mkdir -p $1
sudo mkdir -p $1/www
sudo mkdir -p $1/awstats
sudo mkdir -p $1/logs
sudo touch $1/logs/access.log
sudo touch $1/logs/access-redirect.log

echo '* vhost conf ...'

#site script
echo '<VirtualHost *:80>
	ServerName '$3'
	#ServerAlias '$3'
	ServerAdmin nobody@'$3'

	DocumentRoot '$1'/www

	<Directory />
		Options FollowSymLinks
		AllowOverride None
	</Directory>
	<Directory '$1'/www/>
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

	ErrorLog '$1'/logs/error.log

	# Possible values include: debug, info, notice, warn, error, crit,
	# alert, emerg.
	LogLevel warn

	CustomLog '$1'/logs/access.log combined

</VirtualHost>' | sudo tee $1/vhost.conf > /dev/null
sudo ln -s $1/vhost.conf /etc/apache2/sites-available/$2

#redirection site script
echo '<VirtualHost *:80>

	# redirect vhost that issue 301 redirection to the real site.
	# Remember to edit awstats-redirect.conf
	
	#ServerName '$3'
	#ServerAlias '$3' 
	ServerAdmin nobody@'$3'
	
	DocumentRoot '$1'/www

	<Directory />
		Options FollowSymLinks
		AllowOverride None
	</Directory>
	<Directory '$1'/www/>
		Options FollowSymLinks
		AllowOverride All
		Order allow,deny
		allow from all

		RedirectMatch permanent ^/(.*)$ http://'$3'/$1
	</Directory>
	ErrorLog '$1'/logs/error-redirect.log

	# Possible values include: debug, info, notice, warn, error, crit,
	# alert, emerg.
	LogLevel warn

	CustomLog '$1'/logs/access-redirect.log combined

</VirtualHost>' | sudo tee $1/vhost-redirect.conf > /dev/null
sudo ln -s $1/vhost-redirect.conf /etc/apache2/sites-available/$2-redirect


echo '* logrotate ...'

echo $1'/logs/*.log {
	weekly
	missingok
	rotate 52
	compress
	delaycompress
	notifempty
	create 644 root root
	sharedscripts
	prerotate
		sudo -u root /usr/lib/cgi-bin/awstats.pl -update -config='$2'
		sudo -u root /usr/lib/cgi-bin/awstats.pl -update -config='$2'-redirect
	endscript
	postrotate
		if [ -f /var/run/apache2.pid ]; then
			/etc/init.d/apache2 restart > /dev/null
		fi
	endscript
}' | sudo tee $1/logrotate > /dev/null
sudo ln -s $1/logrotate /etc/logrotate.d/apache2-$2

echo '* awststs ...'

echo 'Include "/etc/awstats/awstats.conf"
SiteDomain="'$3'"
LogFile="'$1'/logs/access.log"
LogFormat=1
DirData="'$1'/awstats"
HostAliases="'$3' localhost 127.0.0.1"
' | sudo tee $1/awstats.conf > /dev/null
sudo ln -s $1/awstats.conf /etc/awstats/awstats.$2.conf

echo 'Include "/etc/awstats/awstats.conf"
SiteDomain="'$3'"
LogFile="'$1'/logs/access-redirect.log"
LogFormat=1
DirData="'$1'/awstats"
HostAliases="'$3' localhost 127.0.0.1"
' | sudo tee $1/awstats-redirect.conf > /dev/null
sudo ln -s $1/awstats-redirect.conf /etc/awstats/awstats.$2-redirect.conf

#awstats crontab
echo $(date +%S)' * * * * root [ -x /usr/lib/cgi-bin/awstats.pl -a -f /etc/awstats/awstats.'$2'.conf ] && /usr/lib/cgi-bin/awstats.pl -config='$2' -update >/dev/null
'$(date +%S)' * * * * root [ -x /usr/lib/cgi-bin/awstats.pl -a -f /etc/awstats/awstats.'$2'-redirect.conf ] && /usr/lib/cgi-bin/awstats.pl -config='$2'-redirect -update >/dev/null' | sudo tee $1/awstats-cron > /dev/null
sudo ln -s $1/awstats-cron /etc/cron.d/awstats-$2

#remove awstats nested include
cat /etc/awstats/awstats.conf | sudo sed -i -e 's/^Include/#Include/' /etc/awstats/awstats.conf

echo '* enable site ...'
sudo a2ensite $2 > /dev/null

echo '

Done.
Please 
   sudo apache2ctl graceful
to load the config of the website gracefully.
You might want to edit '$1'/vhost.conf before doing that,
depends on your application configration.

Regards,

timdream'
