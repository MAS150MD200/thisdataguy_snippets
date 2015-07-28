#!/bin/sh

# Start the carte server as a daemon, and helps managing it in a normal
# (service carte start/stop/status) way.

# Licence: FreeBSD, do what you want with it but do not hold me responsible.

### BEGIN INIT INFO
# Provides: pdi
# Required-Start: $network $syslog $remote_fs
# Required-Stop: $network $syslog
# Default-Start: 3 5
# Default-Stop: 0 1 2 4 6
# Short-Description: Pentaho Carte Server
# Description: Pentaho Carte Server
#
### END INIT INFO

## configuration directives
# Which user does carte run under?
PDIUSER=pentaho
# On which port should it listen?
CARTEPORT=80
# Where is pdi installed?
PDIROOT=/opt/pentaho_pdi
# Normal output log
LOGOUT=/var/log/pentaho_pdi.out.log
# Error output log
LOGERR=/var/log/pentaho_pdi.err.log

## script start here

# Note: The functions script is RH only. It is only used here for sexy (colored)
# output of [OK] or [FAILED] via echo_failure and echo_success.
#
# To make this script work under other flavors of linux, the 2 echo_ functions
# are first defined in a portable (but unsexy) way. If the RH functions script
# exists, its definition will override the portable way.
function echo_failure() { echo -en "\n[FAILED]"; }
function echo_success() { echo -en "\n[OK]"; }
[ -f /etc/rc.d/init.d/functions ] && source /etc/rc.d/init.d/functions

# Very useful for debugging
#set -x

# Find PID of the newest (-n) process owned by $PDIUSER (-u) with carte.sh on
# the full (-f) command, arguments included.
# =&gt; this should yield the pid of 'sh ./carte.sh' on STDOUT, with a status of 0
# if there is such a process, 1 otherwise
FINDPID="pgrep -u $PDIUSER -n -f carte.sh";
function _is_running() {
    $FINDPID 1&gt;/dev/null
    return $?
}

function stop_carte() {
    _is_running
    if [ $? -ne 0 ]; then
        echo -n "$0 is not running, cannot stop."
        echo_failure
        echo
        return 1
    else
        echo -n "Stoping $0..."
        # Finding the pid of carte.sh from $FINDPID. Killing it would leave its
        # child, the actual java process, running.
        # Find this java process via ps and kill it.
        $FINDPID | xargs ps h -o pid --ppid | xargs kill
        sleep 1
        _is_running
        if [ $? -eq 0 ]; then
            echo_failure
            echo
            return 1
        else
            echo_success
            echo
            return 0
        fi
    fi

}

function status() {
    _is_running
    if [ $? -eq 0 ]; then
        echo -n "$0 is running."
        echo_success
        echo
        return 0
    else
        echo -n "$0 does not run."
        echo_failure
        echo
        return 1
    fi
}

function start_carte() {
    _is_running
    if [ $? -eq 0 ]; then
        echo -n "$0 already running."
        echo_failure
        echo
        return 1
    else
        echo -n "Starting $0..."
        # Make sure log files exist and are writable by $PDIUSER first
        touch $LOGOUT $LOGERR
        chown $PDIUSER:$PDIUSER $LOGOUT $LOGERR
        su - $PDIUSER -c "cd $PDIROOT && (nohup sh ./carte.sh $(hostname -i) $CARTEPORT 0&lt;&- 1&gt;&gt;$LOGOUT 2&gt;&gt;$LOGERR &)"
        sleep 1
        _is_running
        if [ $? -eq 0 ]; then
            echo_success
            echo
            return 0
        else
            echo_failure
            echo
            return 1
        fi
    fi
}

case "$1" in
    start)
        start_carte
        exit $?
        ;;
    stop)
        stop_carte
        exit $?
        ;;
    reload|force-reload|restart|force-restart)
        stop_carte
        if [ $? -eq 0 ]; then
            start_carte
            exit $?
        else
            exit 1
        fi
        ;;
    status)
       status
       exit $?
       ;;
    *)
        echo "Usage: $0 {start|stop|restart|status}"
        exit 2
esac
exit 0