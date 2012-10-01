#!/bin/bash

if [ `whoami` != root ]; then
  echo 'Error: root only.'
  exit 1;
fi

if [ -z $1 ] || \
  [ -z $2 ]; then
  echo 'Usage: '$0' [Directory] [Shortname]'
  exit 1;
fi

# if [ ! -d $1 ] || \
  # [ ! -d $1/logs ] || \
  # [ ! -d $1/www ] || \
  # [ ! -d $1/awstats ] || \
  # [ ! -d $1/logs ] || \
  # [ ! -e $1/awstats.conf ] || \
  # [ ! -e $1/awstats-redirect.conf ] || \
  # [ ! -e $1/awstats-cron ] || \
  # [ ! -e $1/logrotate ] || \
  # [ ! -e $1/vhost.conf ] || \
  # [ ! -e $1/vhost-redirect.conf ] ; then
  # echo 'Directory' $1 'does not appear to be a vhost dir made by makevhost.sh.'
  # exit 1;
# fi

# if [ ! -h /etc/apache2/sites-available/$2 ] || \
  # [ ! -h /etc/apache2/sites-available/$2-redirect ] || \
  # [ ! -h /etc/logrotate.d/apache2-$2 ] || \
  # [ ! -h /etc/awstats/awstats.$2.conf ] || \
  # [ ! -h /etc/awstats/awstats.$2-redirect.conf ] || \
  # [ ! -h /etc/cron.d/awstats-$2 ] || ; then
  # echo 'One of the symbolic link is missing, you must clean up yourself.'
  # exit 1;
# fi

#FQDN=$(cat $1/vhost.conf | grep ServerName | awk '{ print $2 }')

echo '
*****************************************************************************
  rmvhost
  This script break links of existing virtual host to config dirs
*****************************************************************************
Your configration:
  + Directory: '$1'
  + Short name: '$2'

To link vhost again, run lnvhost.sh.
To remove the site completely, rm -R '$1'
after running this script.

Press Ctrl+C to escape if incorrect.'
read -p 'Enter to continue. <Enter or Ctrl+C>'

a2dissite $2 > /dev/null
a2dissite $2-redirect > /dev/null

[ -h /etc/apache2/sites-available/$2 ] && rm /etc/apache2/sites-available/$2
[ -h /etc/apache2/sites-available/$2-redirect ] && rm /etc/apache2/sites-available/$2-redirect
[ -h /etc/logrotate.d/apache2-$2 ] && rm /etc/logrotate.d/apache2-$2
[ -h /etc/awstats/awstats.$2.conf ] && rm /etc/awstats/awstats.$2.conf
[ -h /etc/awstats/awstats.$2-redirect.conf ] && rm /etc/awstats/awstats.$2-redirect.conf
[ -h /etc/cron.d/awstats-$2 ] && rm /etc/cron.d/awstats-$2

echo 'Done.
Please
   apache2ctl graceful
to load the config of the website gracefully.
'
