if [ -z $1 ] || \
	[ -z $2 ]; then
	echo 'Usage: '$0' [Directory] [Shortname]'
	exit 1;
fi

if [ ! -d $1 ] || \
	[ ! -d $1/logs ] || \
	[ ! -d $1/www ] || \
	[ ! -d $1/awstats ] || \
	[ ! -d $1/logs ] || \
	[ ! -e $1/awstats.conf ] || \
	[ ! -e $1/awstats-redirect.conf ] || \
	[ ! -e $1/awstats-cron ] || \
	[ ! -e $1/logrotate ] || \
	[ ! -e $1/vhost.conf ] || \
	[ ! -e $1/vhost-redirect.conf ] ; then
	echo 'Directory' $1 'does not appear to be a vhost dir made by makevhost.sh.'
	exit 1;
fi

# FQDN=$(cat $1/vhost.conf | grep ServerName | awk '{ print $2 }')

echo '
*****************************************************************************
  lnvhost
  This script helps links existing virtual host
*****************************************************************************
Your configration:
  + Directory: '$1'
  + Short name: '$2'

To remove generated site, run rmvhost.sh.

Press Ctrl+C to escape if incorrect.'
read -p 'Enter to continue. <Enter or Ctrl+C>
'

sudo ln -s $1/vhost.conf /etc/apache2/sites-available/$2
sudo ln -s $1/vhost-redirect.conf /etc/apache2/sites-available/$2-redirect
sudo ln -s $1/logrotate /etc/logrotate.d/apache2-$2
sudo ln -s $1/awstats.conf /etc/awstats/awstats.$2.conf
sudo ln -s $1/awstats.conf /etc/awstats/awstats.$2-redirect.conf
sudo ln -s $1/awstats-cron /etc/cron.d/awstats-$2

sudo a2ensite $2 > /dev/null

echo 'Done.
Please 
   sudo apache2ctl graceful
to load the config of the website gracefully.
'
