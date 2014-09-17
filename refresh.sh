#!/usr/bin/env bash
# Author: Victor J Roemer
# Email: vroemer@sourcefire.com
# Date: Feb 14, 2012
# Description: This is a watered down version of the update shell script

set -x

SERVER='192.168.1.1'

RAZORBACK_BRANCH="https://razorbacktm.svn.sourceforge.net/svnroot/razorbacktm/releases/branches/releng-0.4"
SOURCECODE="/var/tmp/`basename $RAZORBACK_BRANCH`"
PREFIX="/opt/razorback"

rebuild_block_dir()
{
    rm -rf /var/lib/razorback
    mkdir -p /var/lib/razorback/blocks
    chown snorty:snorty /var/lib/razorback/blocks
}

ui_database()
{
    cd $PREFIX/www/
    rake db:migrate
}

rebuild_db()
{
    echo 'DROP DATABASE razorback;' | mysql -h $SERVER  -u razorback -prazorback
    echo 'CREATE DATABASE razorback;' | mysql -h $SERVER  -u razorback -prazorback
    mysql -h $SERVER -u razorback -prazorback razorback < $SOURCECODE/dispatcher/share/razorback.sql
    mysql -h $SERVER -u razorback -prazorback razorback < $SOURCECODE/dispatcher/share/razorback-data.sql
}

restart_services()
{
    ssh root@$SERVER <<END 
service activemq restart
service memcached restart
service mysql restart
END
}

killall_dumbshit()
{
    killall dispatcher
    killall masterNugget
}

copy_configs()
{
    cd $PREFIX/etc/razorback

    for i in $(ls *.sample)
    do
        cp $i ${i%.sample}
    done
}

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

killall_dumbshit

rebuild_db

ui_database

restart_services

copy_configs

set_configs

set +x
