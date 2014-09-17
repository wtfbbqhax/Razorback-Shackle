#!/bin/bash
# Tool to build test.conf files for the run-tests script
TESTPATH=tests

readonly DISPATCHER_CONFIG=1
readonly NUGGET_CONFIG=2
readonly DEFAULT=*

# Prompt user to take an action
ask()
{
    echo -n "$@" '[y/n] ' ; read ans
    case "$ans" in
        y*|Y*) return 0 ;;
        *) return 1 ;;
    esac
}

# Build a conf given a test directory
builder()
{
    local TESTCASE=$1
    source "$TESTCASE/test.conf"

    # Save off values already in the test case, use these as values as
    # defaults
    local _TESTNAME=$TESTNAME
    local _TESTID=$TESTID
    if [ ! "$TESTID" ]; then
        _TESTID=`basename $TESTCASE`
    fi
    local _TYPE=$TYPE
    local _FILES=$FILES
    local _EXPECTED=$EXPECTED

    local TEST="$_TESTID - $TESTNAME"
    if [ ! "$TEST" ]; then
        TEST="$TESTCASE"
    fi

    # Prompt user to modify testcase and the values in the testcase
    if ask "Modify $TEST? "; then
        echo -n "TESTID ($_TESTID): "; read TESTNAME
        echo -n "TESTNAME ($_TESTNAME): "; read TESTNAME
        echo -n "TYPE ($_TYPE): "; read TYPE
        echo -n "FILES ($_FILES): "; read FILES
        echo -n "EXPECTED ($_EXPECTED): "; read EXPECTED
    fi

    # Find the values that the user decided to leave default, substitute
    # with these
    if [ ! "$TESTID" ]; then
        TESTID=$_TESTID
    fi
    if [ ! "$TESTNAME" ]; then
        TESTNAME="$_TESTNAME"
    fi
    if [ ! "$TYPE" ]; then
        TYPE=$_TYPE
    fi
    if [ ! "$FILES" ]; then
        FILES="$_FILES"
    fi
    if [ ! "$EXPECTED" ]; then
        EXPECTED="$_EXPECTED"
    fi

    # Write the new test.conf file
    cat >"$TESTCASE/test.conf" <<END
TESTID=$TESTID
TESTNAME="$TESTNAME"
TYPE=$TYPE
FILES="$FILES"
EXPECTED="$EXPECTED"
END

}

# find only the directories containing a test.conf
for i in $(find $TESTPATH -name "test.conf" -type f | sed 's#\(.*\)/.*#\1#' | sort); do
    builder $i
done
