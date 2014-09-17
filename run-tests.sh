#!/bin/bash
# AUTHOR: Victor J Roemer (vroemer@sourcefire.com)
# 
# This script is provided to provide some sort of means for simplifying my life
# while, primarily running, config validation tests for razorback. The simple
# design makes it extendable and reusable for future use.
#
readonly NAME=`basename $0`
UPDATE=0
SHOW=0

# I Don't want these modifiable
readonly TESTPATH=testcases
readonly SOURCE_DIR=/var/tmp/razorback
readonly BUILD_DIR=/opt/razorback
readonly TEMP_DIR=/var/tmp
readonly RESULT_FILE="result-$(date +"%d-%m-%y")"

readonly DISPATCHER_CONFIG=1
readonly NUGGET_CONFIG=2
readonly CUSTOM=3
readonly DEFAULT='*'

ask()
{
    echo -n "$@" '[y/n] ' ; read ans
    case "$ans" in
        y*|Y*) return 0 ;;
        *) return 1 ;;
    esac
}

check_results()
{
    local TESTCASE=$1
    diff -u $TESTCASE/$EXPECTED $TEMP_DIR/razorback.out &> $TEMP_DIR/diff.out
    echo "$?"
}

show_results()
{
    local TESTCASE=$1
    cat $TEMP_DIR/diff.out
}

write_results()
{
    local TESTCASE=$1
    local TESTID=$2
    local TESTNAME=$3
    local RET=$(check_results $TESTCASE)

    if [[ $RET -eq "0" ]]; then
        echo "$TESTID - $TESTNAME ... PASSED" | tee $TESTCASE/result
    else
        echo "$TESTID - $TESTNAME ... FAILED"  | tee $TESTCASE/result
    fi

    if [[ $SHOW -eq "1" ]]; then
        cat $TEMP_DIR/razorback.out >> $TESTCASE/result
    fi
}

#####################################################################
# BUILTIN TESTING FUNCTIONS
#####################################################################
dispatcher_config_test()
{
    local TESTCASE=$1

    for i in $FILES; do
        cp $TESTCASE/$i $BUILD_DIR/etc/razorback/ &> /dev/null
    done

    $BUILD_DIR/bin/dispatcher &> $TEMP_DIR/razorback.out
}

custom_test()
{
    local TESTCASE=$1

    if [[ $SCRIPT ]]; then
        eval $SCRIPT &> $TEMP_DIR/razorback.out
    fi
}

prerun()
{
    local TESTCASE=$1
    local RET=0
    source "$TESTCASE/test.conf"

    if [[ $PRERUN ]]; then
        RET=$(eval $PRERUN)
    fi
}

postrun()
{
    local TESTCASE=$1
    local RET=0
    source "$TESTCASE/test.conf"

    if [[ $POSTRUN ]]; then
        RET=$(eval $POSTRUN)
    fi
}

run()
{
    local TESTCASE=$1
    source "$TESTCASE/test.conf"

    case $TYPE in
        $DISPATCHER_CONFIG)
        dispatcher_config_test $TESTCASE
        ;;

        $NUGGET_CONFIG)
        echo "Not Implemented"
        ;;

        $CUSTOM)
        custom_test $TESTCASE
        ;;

        $DEFAULT) 
        echo "UNKNOWN"
        ;;
    esac

    write_results $TESTCASE $TESTID "$TESTNAME"
}

update()
{
    local TESTCASE=$1
    local RET=1

    RET=$(check_results $TESTCASE)
    if [[ $RET -ne "0" ]]; then
        echo "Expected and actual outputs differ!"
        if ask "Show output? "; then
            show_results $TESTCASE
        fi

        if ask "Update output? "; then 
            cp $TEMP_DIR/razorback.out $TESTCASE/$EXPECTED 
        fi
    fi
}

# Add the junk to the report
report()
{
    local TESTCASE=$1
    
    cat $TESTCASE/result >> $RESULT_FILE
    if [[ "$SHOW" -eq "1" ]]; then
        printf "\n\n" >> $RESULT_FILE
    fi
}

# Tell a user how to use this tool
#
usage()
{
    echo "$NAME"
    echo ""
#    echo-n  "  --update        enable mid-run testcase update"
#    echo " ( NOT CURRENTLY WORKING )"
    echo "  -s|--show       show results"
    echo "  -h|--help       display this help"
    echo ""
    echo "Copyright (C) 2012 Victor Roemer"
}

# Parse the command line arguments
# 
for var in "$@"; do
    case "$var" in
#    --update)
#        UPDATE=1
#        ;;
    -s|--show)
        SHOW=1
        ;;
    -h|--help)
        usage
        exit 1
        ;;
    -*)
        echo "$NAME: invalid option - '$1'"
        exit 1
        ;;
    esac
done

# Remove prior executions for today
rm $RESULT_FILE

TESTS=$(find $TESTPATH -name "test.conf" -type f |
        sed 's#\(.*\)/.*#\1#' |
        sort -u)

# Run the test cases
for TESTCASE in $TESTS; do
    prerun $TESTCASE &
    wait

    run $TESTCASE &
    wait

    postrun $TESTCASE &
    wait
done

for TESTCASE in $TESTS; do
    report $TESTCASE
done
