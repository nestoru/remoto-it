Introduction
============
RemotoIT is a Plain Old Bash (POB) script to perform Server Management. Currently it has been tested in OSX/Ubuntu as a client and Ubuntu/Solaris as the target server.

	provisioning
	├── recipes
	│   ├── apache.sh
	│   ├── couch.sh
	│   ├── nodejs.sh
	│   ├── sample.com.sh
	│   └── svn.sh
	└── remoto-it
	    ├── common.sh
	    └── run.sh

Setup
=====
1. Create a directory where you will keep remoto-it and the recipes, for example 'provisioning'.
1. Clone this project into a 'remoto-it' subdirectory using either git or https as shown below

		git clone git@github.com:nestoru/remoto-it.git
		git clone https://github.com/nestoru/remoto-it.git
1. Checkout the needed scripts into a 'recipes' subdirectory.

Usage
=====
Scenario 1: By convention run recipes against a single domain
1. Create the Recipe out of real commands you issue to perform your task in recipes/myRecipe.sh. Here is a simple (idempotent as its intention is reinstall the package any time it is run) nodejs.sh recipe:

		#!/bin/bash
		echo "--- Setting up the NodeJS ---"
		set -e
		cd
		curl -O http://nodejs.org/dist/node-v0.4.10.tar.gz
		tar -zxvf node-v0.4.10.tar.gz
		cd node-v0.4.10
		make clean
		./configure
		make
		make install
		node --version
	
1. Add existing recipes to file recipes/${host}.sh where ${host} is the remote server to connect to. Here is sample.com.sh where some recipes are commented out to run only svn.sh and nodejs.sh
	
		#
		# Recipe line must start with number or letter, 
		# Anything else will be ignored
		#
		svn.sh
		#apache.sh
		#couch.sh
		nodejs.sh

1. Invoke run.sh with a valid user and ${host}:

	    ./run.sh remoteUser sample.com
	
Scenario 2: By convention run recipes against multiple domains

	    /run.sh remoteUser /tmp/hosts.txt

Scenario 3: By configuration run recipes against a single domain

	    /run.sh remoteUser sample.com /tmp/myRecipe.sh

Scenario 4: By configuration run recipes against multiple domains

		/run.sh remoteUser /tmp/hosts.txt /tmp/myRecipe.sh

How it works
============
There is not much to do in order to automate using bash scripts. Just authorize a public key in your remote servers so things like rsync are possible, make sure the sudoer user password is only provided from a user answer (as a double optin recognizing you know what you are doing), have a way to customize which of your recipes (POB scripts) will be run remotely and finally send your commands over the created SSH tunel.

The main script run.sh uses a couple of functions from common.sh and a recipes folder containing a file per server domain ($host.sh) with the list of recipes to run there (apache.sh, nodejs.sh, cowch.sh etc) You host your recipes directory wherever you want (hopefully here in github so those are completely reusable by others). Look at the other three scenarios above for alternative use.

Look at common.sh for some handy functionality like the use of "expect" to be able to run commands as root remotely without the need to type the user password more than once. The svn recipe example below shows how you can interactively ask for passwords in your scripts. It uses the powerful "expect" Unix tool. You can hardly automate or test Unix systems without this great piece of software.

Recipe samples
==============
The web is full of semiautomated and fully automated scripts to do anything you want. The possibilities are endless but you will need to change some of them to ensure idempotency. Here are some examples:

The recipes sometimes need resources that are not available publicly (like downloading Java needs user interaction or installing latest snapshot from a trunk in your svn repository). Whether it is source code pulled from an external server like revision control system and later compiled, parsed or interpreted, from an artifactory repository in terms of binary files, from a local CIF, a remote SFTP you will need to provide ways to automate file transfer. Here is a sample svn recipe which makes sure the server stays with a valid svn credential. This is handy because other recipes check for example configuration files from SVN and you do not want to keep inserting user and password to provision the server. To use it for your project you need to change the URL for svn of course:
	
	#!/bin/bash

	echo "--- Setting up SVN ---"

	set -e


	SVN_REPO=http://subversion.sample.com/

	echo -n "SVN User: "
	read svnuser
	echo -n "SVN Password: "
	read -s svnpassword
	echo

	apt-get -q -y install subversion
	sed -i 's/# store-passwords = no/store-passwords = yes/g' .subversion/servers
	sed -i 's/# store-plaintext-passwords = no/store-plaintext-passwords = yes/g' .subversion/servers
	echo $svnpassword | svn info $SVN_REPO --username $svnuser

Here is apache.sh which configures and harden an Apache Server thanks to configuration files stored in SVN. This recipe clearly will not run in you do not update the URLs:
	
	#!/bin/bash
	
	echo "--- Setting up Apache ---"

	set -e

	rm -fR /var/log/apache2/
	apt-get -q -y install apache2
	apt-get -q -y install libapache2-mod-jk
	a2dismod status
	cd /etc/apache2/mods-enabled/
	rm -f rewrite.load
	ln -s ../mods-available/rewrite.load rewrite.load
	cd /etc/apache2/
	svn export http://subversion.sample.com/environment/settings/bhub/local/apache/apache2.conf
	a2enmod ssl
	svn export http://subversion.sample.com/environment/settings/bhub/local/apache/ports.conf
	svn export http://subversion.sample.com/environment/settings/bhub/local/apache/workers.properties
	svn export http://subversion.sample.com/environment/settings/bhub/local/apache/mod-jk.conf 
	cd /etc/apache2/sites-available
	svn export http://subversion.sample.com/environment/settings/bhub/local/apache/sites-available/bhub
	svn export http://subversion.sample.com/environment/settings/bhub/local/apache/sites-available/bhub-ssl
	mkdir -p /etc/apache2/certs/
	cd /etc/apache2/certs/
	svn export http://subversion.sample.com/environment/resources/bhub/local/apache/bhubdev.sample.com.crt
	svn export http://subversion.sample.com/environment/resources/bhub/local/apache/bhubdev.sample.com.key
	cd /etc/apache2/sites-enabled/
	rm -f 000-bhub
	ln -s ../sites-available/bhub 000-bhub
	rm -f 001-bhub-ssl
	ln -s ../sites-available/bhub-ssl 001-bhub-ssl
	rm -f 000-default
	mkdir -p /var/sample-app
	/etc/init.d/apache2 restart

Finally here is an idempotent recipe to install couchdb. It can be run again and again and it will always finish with the installed package or an error but the error will not make you start from a given intermediate point. I have tested it in Ubuntu 10.10 and Ubuntu 12.4 with great results. In fact this is one of the tasks I have done that made me write this package. I saw a lot of back and forth in the couchdb WIKI and I figured I rather have a script that did all for me. This script can take up to two hours in a Ubuntu 12.4 running with 512MB in my Snow Leopard OSX. I have run it after networking errors, package reconfigurations, Ubuntu upgrades and what not. In fact our plan is to have our whole dev environment created from scripts like this run from Remoto-IT.
	
	#!/bin/bash
	
	echo "--- Setting up CouchDB ---"
	
	set -e
	USER=admin
	couchpid=`ps -ef|grep couch | grep -v grep | awk '{print $2}'`
	if [ $couchpid ]; then kill -9 $couchpid; fi
	apt-get -q -y update
	apt-get -q -y autoremove
	apt-get -q -y remove couchdb*
	apt-get -q -y purge couchdb*
	apt-get -q -y build-dep couchdb
	apt-get -q -y install libtool zip
	cd
	rm -fr js-1.8.5
	curl -O http://ftp.mozilla.org/pub/mozilla.org/js/js185-1.0.0.tar.gz
	tar xvzf js185-1.0.0.tar.gz 
	cd js-1.8.5/js/src
	./configure
	make
	make install
	cd
	rm -fr otp_src_R14B0
	curl -O http://www.erlang.org/download/otp_src_R14B04.tar.gz
	tar xvzf otp_src_R14B04.tar.gz 
	cd otp_src_R14B04
	./configure --enable-smp-support --enable-dynamic-ssl-lib --enable-kernel-poll
	make
	make install
	cd
	rm -fr apache-couchdb-1.1.1
	curl -O http://mirror.candidhosting.com/pub/apache/couchdb/1.1.1/apache-couchdb-1.1.1.tar.gz
	tar xvzf apache-couchdb-1.1.1.tar.gz
	cd apache-couchdb-1.1.1
	prefix='/usr/local'
	./configure --prefix=${prefix} 
	make
	make install
	grep couchdb /etc/passwd || useradd -d /var/lib/couchdb couchdb
	chown -R couchdb:${USER} ${prefix}/var/{lib,log,run}/couchdb ${prefix}/etc/couchdb
	for dir in `whereis couchdb | sed 's/couchdb: //'`; do echo $dir | xargs chown couchdb; done
	export xulrunnerversion=`xulrunner -v 2>&1 >  /dev/null | egrep -o "([0-9]{1,2})(\.[0-9]{1,2})+"`
	echo $xulrunnerversion
	echo "/usr/lib/xulrunner-$xulrunnerversion" > /etc/ld.so.conf.d/xulrunner.conf
	echo "/usr/lib/xulrunner-devel-$xulrunnerversion" >> /etc/ld.so.conf.d/xulrunner.conf
	/sbin/ldconfig
	ln -s /usr/local/etc/init.d/couchdb /etc/init.d/couchdb
	update-rc.d couchdb defaults
	/etc/init.d/couchdb start
	curl -X GET http://localhost:5984

Provisioning is not just about continuous software delivery. It is about continuous software maintenance. Software to be maintained needs healthy environments. The Infrastructure needs software upgrades, updates, patches. You can automate and should automate all that especially if you maintain farms of similar servers.

Recipe Resources
=================
As mentioned before CIFS/NFS can be used to host packages that are only available for download after double-optins, license agreements and other manual procedures. For those we simply need to create a repository and mount it via CIFS/NFS. It is good to have a convention and the one we use is /mnt/pob-resource-repository. The POB recipes can then point to the right resource in a standard way that will work for any server. For a full example visit http://thinkinginsoftware.blogspot.com/2012/07/patching-or-installing-java-in-ubuntu.html.

FAQ
===
Why this and not Chef or Puppet? Options. Just pick the one that works for you. Will I use Puppet or Chef? Yes, why not? Will I use them for everything? Not really. POB or POS are mandatory even if you are working with Chef or Puppet so let us learn the shell well enough first.
	
TODO
====
1. Other OS client support. Currently tested from OSX and Ubuntu.
1. Other OS Server support. Currently tested to provision Ubuntu and Solaris.
1. You name it ...
