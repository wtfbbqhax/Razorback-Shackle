#!/usr/bin/env bash
# Author: Victor J Roemer
# Email: vroemer@sourcefire.com
# Date: Feb 14, 2012
# Description: This does everything that the user would need to do prior to
# starting they're testing

set -x

SERVER='192.168.1.1'

# Get our IPv4 address for ETH1
INETADDR=$(ifconfig eth1 | perl -ne '/inet addr:(\d+\.\d+\.\d+\.\d+)/ && print $1' 2> /dev/null)
if [[ ! $INETADDR ]]; then
  INETADDR=$(ifconfig em1 | perl -ne '/inet (\d+\.\d+\.\d+\.\d+)/ && print $1')
fi

RAZORBACK_BRANCH="https://razorbacktm.svn.sourceforge.net/svnroot/razorbacktm/releases/branches/releng-0.4"
SOURCECODE="/var/tmp/`basename $RAZORBACK_BRANCH`"

PREFIX="/opt/razorback"
CONFIG_FLAGS="--enable-dispatcher --enable-masterNugget --enable-archiveInflate --enable-clamavNugget --enable-fileInject --enable-fsWalk --enable-logNugget --enable-libemuNugget --enable-officeCat --enable-pdfFox --enable-scriptNugget --enable-swfScanner --enable-syslogNugget --enable-virusTotal --enable-yaraNugget --enable-snort --enable-fsMonitor --prefix=/opt/razorback --enable-debug --enable-assert --prefix $PREFIX"

uninstall()
{
    echo "----------- Uninstall ------------"
    rm -rf $PREFIX 
}

svn_update()
{
    local REPO_PATH=$1
    cd $REPO_PATH
    echo "----------- Subversion -----------"

    echo "svn update $REPOSITORY $REPO_PATH"
    svn update
}

svn_checkout()
{
    local REPOSITORY=$1
    local REPO_PATH=$2
    echo "----------- Subversion -----------"
    if [ ! -d $REPO_PATH ];
    then
        mkdir -p $REPO_PATH
    fi

    echo "svn checkout $REPOSITORY $REPO_PATH"
    svn checkout $REPOSITORY $REPO_PATH
}

build()
{
    local REPO_PATH=$1
    cd $REPO_PATH
    echo "------------- Build --------------"

    if [ -e Makefile ]; then
        make distclean
    fi

    if [ ! -e configure ]; then
        ./autojunk.sh
    fi

    echo "./configure $CONFIG_FLAGS"
    ./configure $CONFIG_FLAGS
    make install
}

rebuild_block_dir()
{
    echo "------- Rebuild Block Dir --------"

    rm -rf /var/lib/razorback
    mkdir -p /var/lib/razorback/blocks
    chown snorty:snorty /var/lib/razorback/blocks
}

install_rzb_ui()
{
    local REPO_PATH=$1

    echo "----------- Install UI -----------"

    # Move the UI to where apache/httpd will expect it
    cp -r $REPO_PATH/ui/rzb_ui/ $PREFIX/www

    # just fucking do this for me
    chown -R snorty:snorty $PREFIX

    # run the database migration, so the damn thing will work in the morning
    cd $PREFIX/www
    rake db:migrate

    # Start the monitoring daemons
#    $PREFIX/www/script/daemons start
}

# Rebuild the database
rebuild_db()
{
    echo 'DROP DATABASE razorback;' | mysql -h $SERVER  -u razorback -prazorback
    echo 'CREATE DATABASE razorback;' | mysql -h $SERVER  -u razorback -prazorback
    mysql -h $SERVER -u razorback -prazorback razorback < $SOURCECODE/dispatcher/share/razorback.sql
    mysql -h $SERVER -u razorback -prazorback razorback < $SOURCECODE/dispatcher/share/razorback-data.sql
}

# Restart the services on our server
restart_services()
{
    ssh root@$SERVER <<END 
service activemq restart
service memcached restart
service mysql restart
END
}

# Kill any running processes
killall_dumbshit()
{
    killall dispatcher
    killall masterNugget
}

# Remove this whenever razortwit gets installed by default
install_razortwit()
{
    cp $SOURCECODE/nuggets/razorTwit/twitter.pl $PREFIX
    cp $SOURCECODE/nuggets/razorTwit/twitter.conf $PREFIX
}

# Rebuild the configuration files
copy_configs()
{
    cd $PREFIX/etc/razorback

    for i in $(ls *.sample)
    do
        cp $i ${i%.sample}
    done
}

# Set the configurations
set_configs()
{
    cd $PREFIX/etc/razorback
    for i in $(ls *.conf); do
        perl -p -i -e "s/localhost/$SERVER/g" $i
        perl -p -i -e "s/Address=\"127.0.0.1\"/Address=\"::\"/g" $i
        perl -p -i -e "s/127.0.0.1/$INETADDR/g" $i
        perl -p -i -e "s/TMP_DIR=\".*\";/TMP_DIR=\"\/nfs\/razorback\/tmp\";/g" $i
    done
}

# Kill dispatcher processes
killall_dumbshit

# Rebuild the database
rebuild_db

# Restart services
restart_services

# Figure out if we need to checkout a fresh copy or just update
if [ -d $SOURCECODE/dispatcher ]; then
    echo "Existing checkout found, updating"
    svn_update $SOURCECODE
else
    svn_checkout $RAZORBACK_BRANCH $SOURCECODE
fi

# Build the source code
build $SOURCECODE

# Install the fucking UI
install_rzb_ui $SOURCECODE

# rebuild the block directory
rebuild_block_dir

# install razorTwit
install_razortwit

# Copy the config files over
copy_configs
set_configs

set +x
