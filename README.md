# apache2-vhost-config

A set of scripts to do one-stroke virtual host setup with apache2 package
in Debian/Ubuntu.

**Author:** Timothy Chien [:timdream] <<timdream@gmail.com>>

**License:** GPLv2.

## Usage

### mkvhost.sh

Make a virtual host. Upon execution, `mkvhost.sh` will:

   * create vhost directories and all configration files.
   * Set up two virtual hosts config named `shortname` and `shortname-redirect`
   (where `shortname` is the name you specified).
   The later one is good for blind redirection, e.g.
   `www.domain.tld` -> `domain.tld`.
   * Set up logrotate, awstat and their corntab.

All configration files are contained in the specified directory
and symbolic linked to proper places.

### rmvhost.sh

Remove symbolic links of the vhost configration files created by `mkvhost.sh`.
To permentently delete the entire virtual host, do `rm -R ./your-vhost/`.

### lnvhost.sh

Recreate symbolic links.

### config

**Experimental**: Setup LAMP enviroment on a bare Ubuntu system.

## Known issues

  * The Debian `apache2` package changed default virtual host setting
  from `<VirtualHost *>` to `<VirtualHost *:80>` after version 2.2.9-8.
  Do modify `mkvhost.sh` accordingly *BEFORE* creating virtual hosts.

