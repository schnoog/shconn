#!/usr/bin/bash

IFS="
"

export case_sensitive_sections=false
export case_sensitive_keys=false
export default_to_uppercase=true

SCRIPTPATH=$(dirname "$(realpath $0)")
INIFILE="$SCRIPTPATH""/_shconn.conf"

cd "$SCRIPTPATH"

source ini-file-parser.sh

process_ini_file "$INIFILE"

echo "Select server to connect to"
TMP=$(display_config | grep '\[' | grep ']' | grep -v '\[DEFAULT]')
CNT=0

for SEC in $TMP
do
let CNT=$CNT+1
echo "$CNT $SEC"
done

read a
if [ "$a" == "" ]
then
    exit 0
fi

CNT=0
for SEC in $TMP
do
let CNT=$CNT+1
if [ "$CNT" == "$a" ]
then
    MSEC=$(echo "$SEC" | cut -d '[' -f 2 | cut -d ']' -f 1)
    display_config_by_section "$MSEC"
    IPN=$(get_value "$MSEC" 'ip')

    SSHUSER=$(get_value "$MSEC" 'ssh')
    LFTPUSER=$(get_value "$MSEC" 'lftp')

    if [ "$LFTPUSER" != "" ]
    then
        echo "Connection type"
        echo "(1) SSH [default]"
        echo "(2) LFTP"
        read b
        if [ "$b" == "2" ]
        then
            CS="sftp://""$IPN"
            lftp -u "$LFTPUSER", "$CS"
        else
            CS="$SSHUSER""@""$IPN"
            ssh "$CS"
        fi


    else
        CS="$SSHUSER""@""$IPN"
        ssh "$CS"
    fi
fi
done
