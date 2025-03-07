#!/usr/bin/bash

# ===========================================================
# Script Name: Server Connection Manager
# Description:
#   This Bash script facilitates connecting to multiple servers 
#   by providing a user-friendly menu interface. It reads server 
#   configurations from a YAML file and organizes them into 
#   tables for easy selection. Users can connect to their desired 
#   server via SSH or LFTP, with options for automatic selection 
#   based on server availability as defined in the YAML file.
#
# Usage:
# 1. Modify the configuration file located at 
#    ~/.shconfig.yml or /etc/.shconfig.yml to define 
#    server details.
#    If the file is available in both directories, thah in ~/ will be used
# 2. Execute the script to display a list of servers.
# 3. Select the desired server by entering the corresponding 
#    number.
# 4. Choose the connection type (SSH or LFTP) if prompted.
#
# Features:
# - Configurable number of columns for output tables
# - Debugging output for troubleshooting
# - Automatic determination of the number of columns based on terminal width
# - Support for SSH and LFTP connections
#
# Requirements:
# - Bash shell
# - `ssh` and `lftp` commands available on the system
# - YAML configuration file (.shconfig.yml) containing server details
#
# Configuration Variables:
# - NUM_COLS: Number of columns to display in the server list.
# - AUTO_COLS: Automatically calculate the number of columns 
#   based on terminal width.
# - DEBUGOUT: Enable or disable debug messages.
# - GSTEP: Server index group offset.
# - INPWAIT: Timeout for automatic connection type selection.
#
# Included Script:
# - This script includes a YAML parsing function sourced from:
#   https://github.com/mrbaseman/parse_yaml.git
#   This external script is also licensed under the GPL3.
#
# License:
#   This script is licensed under the GNU General Public License v3.0 (GPL3).
#   See <http://www.gnu.org/licenses/> for details.
# ===========================================================




# ===========================================================
# Basic settings
# ===========================================================
# Define number of columns per table
NUM_COLS=2          # Change this to your preferred number of columns
AUTO_COLS=true     # Calculating the number of columns based on the length 
                    # of the labels and terminal width overwriting NUM_COLS
DEBUGOUT=false      # Set to 'true' to enable debugging output, 'false' to disable
GSTEP=10           # Group offset for server index. 
                    # 10 = Group 1 starts with 1, Group 2 with 11, Group 3 with 21
                    # 100 = Group 1 starts with 1, Group 2 with 101, Group 3 with 201
INPWAIT=5           # if ssh and lftp are available for a server after this number of
                    # seconds it will automatically switch to ssh
COLORED=true        # set to false for uncolored output


# ===========================================================
# Initialization
# ===========================================================
IFS="
"
SCRIPTPATH=$(dirname "$(realpath $0)")

declare -A LABELARR
declare -A SERVERARR

# ===========================================================
# Select config yaml
# ===========================================================


CONFIG="$SCRIPTPATH""/.shconfig.yml"
FILE="$HOME/.shconfig.yml"
if [ -f $FILE ]; then
    CONFIG=$FILE
else

    FILE="/etc/.shconfig.yml"
    if [ -f $FILE ]; then
        CONFIG=$FILE
    fi


fi
###############################################################################
#
# Rights elevation settings for mount
#
###############################################################################
ELE=/usr/bin/sudo
if [ "$(echo $UID)" == "0" ]
then
    ELE=""
fi
###############################################################################
#
# We know we have the rights, let's get the newest version of this script
#
###############################################################################

if [ "$1" == "update" ]
then
        URL="https://raw.githubusercontent.com/schnoog/shconn/refs/heads/main/shconn.sh"
        $ELE wget -q -O /usr/bin/shconn.sh "$URL"
        $ELE chmod +x /usr/bin/shconn.sh
        echo "Script updated successfully."
	exit 0
fi



###############################################################################
#
# Mount directorry
#
###############################################################################

MNTDIR="/media/$USER/shmount"

###############################################################################
#
# Colors, who doesn't love colors?
#
###############################################################################




COLOR_NC='\e[0m' # No Color
COLOR_BLACK='\e[0;30m'
COLOR_GRAY='\e[1;30m'
COLOR_RED='\e[0;31m'
COLOR_LIGHT_RED='\e[1;31m'
COLOR_GREEN='\e[0;32m'
COLOR_LIGHT_GREEN='\e[1;32m'
COLOR_BROWN='\e[0;33m'
COLOR_YELLOW='\e[1;33m'
COLOR_BLUE='\e[0;34m'
COLOR_LIGHT_BLUE='\e[1;34m'
COLOR_PURPLE='\e[0;35m'
COLOR_LIGHT_PURPLE='\e[1;35m'
COLOR_CYAN='\e[0;36m'
COLOR_LIGHT_CYAN='\e[1;36m'
COLOR_LIGHT_GRAY='\e[0;37m'
COLOR_WHITE='\e[1;37m'


if [ "$COLORED" = false ]
then
    COLOR_NC=''
    COLOR_BLACK=''
    COLOR_GRAY=''
    COLOR_RED=''
    COLOR_LIGHT_RED=''
    COLOR_GREEN=''
    COLOR_LIGHT_GREEN=''
    COLOR_BROWN=''
    COLOR_YELLOW=''
    COLOR_BLUE=''
    COLOR_LIGHT_BLUE=''
    COLOR_PURPLE=''
    COLOR_LIGHT_PURPLE=''
    COLOR_CYAN=''
    COLOR_LIGHT_CYAN=''
    COLOR_LIGHT_GRAY=''
    COLOR_WHITE=''

fi

CRS=$COLOR_LIGHT_GREEN
CRE=$COLOR_NC
CRW=$COLOR_LIGHT_RED
CRH=$COLOR_YELLOW
CRN=$COLOR_LIGHT_BLUE

###############################################################################
#
# Functions
#
###############################################################################
print_r() {
    local -n xxarr=$1
    local xxprefix=${2:-}
    for xxkey in "${!xxarr[@]}"; do
        if [[ ${xxarr[$xxkey]} =~ ^declare\ -A ]]; then
            echo "${xxprefix}[$xxkey] => (xxarray)"
            local -n sub_xxarr=${xxarr[$xxkey]}
            print_r sub_xxarr "  $xxprefix[$xxkey]"
        else
            echo "${xxprefix}[$xxkey] => ${xxarr[$xxkey]}"
        fi
    done
}
### ----------------------------------------
### ----------------------------------------
### Function to Print Debug Messages
### ----------------------------------------
### ----------------------------------------

debug() {
  if [ "$DEBUGOUT" = true ]; then
    echo "DEBUG: $1"
  fi
}

### ----------------------------------------
### ----------------------------------------
### Function to Print Tables
### ----------------------------------------
### ----------------------------------------

print_tables() {
  local current_label=1
  local num_labels=${#LABELARR[@]}
  
  debug "Number of labels: $num_labels"
  
  while [ "$current_label" -le "$num_labels" ]; do
    local end_label=$((current_label + NUM_COLS - 1))
    
    # Adjust if end_label exceeds num_labels
    if [ "$end_label" -gt "$num_labels" ]; then
      end_label="$num_labels"
    fi
    
    debug "Processing columns $current_label to $end_label"
    
    # Prepare the output for column command
    output=""
    # Add headers
    for col in $(seq "$current_label" "$end_label"); do
      output+="$CRH${LABELARR[$col]}$CRE\t"
    done
    output+="\n"  # Newline after headers
    
    # Get the maximum number of rows for the current table
    local max_row=0
    for col in $(seq "$current_label" "$end_label"); do
      for key in "${!SERVERARR[@]}"; do
        IFS=',' read -r key_col key_row <<< "$key"
        if [ "$key_col" -eq "$col" ]; then
          if [ "$key_row" -gt "$max_row" ]; then
            max_row="$key_row"
          fi
        fi
      done
    done

    debug "Maximum row count for columns $current_label to $end_label is $max_row"

    # Print each row
    for row in $(seq 1 "$max_row"); do
      for col in $(seq "$current_label" "$end_label"); do
        local entry="${SERVERARR[$col,$row]}"
        output+="${entry:- }\t"  # Add entry or empty space
      done
      output+="\n"  # Newline after each row
    done

    # Print the table using column
    echo -e "$output" | column -s $'\t' -t

    printf "\n"  # Add an empty line between tables
    current_label=$((end_label + 1))
  done
}

### ----------------------------------------
### ----------------------------------------
### Function to get chunks out of the config
### ----------------------------------------
### ----------------------------------------


GetParts(){
    GET="$1"
    PART="-""$2"
    echo "$GET" | cut -d "_" -f "$PART" | grep -v "=" | sort -u 
}


### ----------------------------------------
### ----------------------------------------
### Function to generate the displayed menu
### ----------------------------------------
### ----------------------------------------

function MenuGenerator(){
    # ----------------------------------------
    # Going through groups
    # ----------------------------------------
    PARTS=$(GetParts "$SETTINGS" "3")
    for PART in $PARTS
    do
        let NUMHEAD=$NUMHEAD+1
        SECOUT=$(echo "$PART" | cut -d "_" -f 3)
        HEADERS+=( "${SECOUT:2}" )
        HLABEL="${SECOUT:2}"
        LABELARR[$NUMHEAD]="${SECOUT:2}"
            SCOUNT=0    
            SECS=$(GetParts "$SETTINGS" 4 | grep "^$PART" | uniq)
    # - # ---------------------------------------
    # - # Going though the servers and adding those of the group to the array
    # - # ---------------------------------------

            for SEC in $SECS
            do
                let SCOUNT=$SCOUNT+1
                let IND=$SCOUNT+$GCOUNT
                HOSTDATA=$(echo "$SETTINGS" | grep "^$SEC""_" | grep -v '_=' )
                    hname=$(echo "$HOSTDATA" | grep '_name=' | cut -d "'" -f 2)
                    hip=$(echo "$HOSTDATA" | grep '_ip=' | cut -d "'" -f 2)
                    hssh=$(echo "$HOSTDATA" | grep '_ssh='| cut -d "'" -f 2)
                    hlftp=$(echo "$HOSTDATA" | grep '_lftp=' | cut -d "'" -f 2)
                    hmnt=$(echo "$HOSTDATA" | grep '_mount=' | cut -d "'" -f 2)
                SP=""
                #echo $HOSTDATA
                #echo "---------------------------------------------------"
                if [ $IND -lt 10 ]
                then
                    SP=" "
                fi 
                LFTPIND=""
                MNTPIND=""
                ALBL=""
                if [ "$hlftp" != "" ]
                then
                    ALBL="lftp"
                fi
                if [ "$hmnt" != "" ]
                then
                    if [ "$ALBL" == "" ]
                    then
                       ALBL="mount"
                    else
                       ALBL="$ALBL"",mount"
                    fi
                fi 
                if [ "$ALBL" != "" ]
                then
                    ALBL="(""$ALBL"")"
                fi

                if [ "$hlftp" != "" ]
                then
                    LFTPIND="+lftp"
                fi
                if [ "$hmnt" != "" ]
                then
                        MNTPIND="+mount"
                fi            
                #
#"$CRN" "$CRE"
                SERVERS+=( "$SP("$IND") $hname $ALBL" )
                SSTR="$SP("$CRS""$IND""$CRE") "$CRN"$hname"$CRE" $ALBL"
                SERVERARR[$NUMHEAD,$SCOUNT]="$SSTR"
                CURRLEN=${#SSTR}
                let CURRLEN=$CURRLEN-${#CRS}
                let CURRLEN=$CURRLEN-${#CRE}
                let CURRLEN=$CURRLEN-${#CRN}
                let CURRLEN=$CURRLEN-${#CRE}
                if [ $CURRLEN -gt $MLEN ]; then MLEN=$CURRLEN; fi
            done
    # - # ---------------------------------------
        let GCOUNT=$GCOUNT+$GSTEP
    done
    # ----------------------------------------


    # ----------------------------------------
    # Applying AUTO_COLS if true
    # ----------------------------------------

    if [ "$AUTO_COLS" = true ]
    then
        terminal_width=$(tput cols)
        NUM_COLS=$((terminal_width / MLEN))
        #let NUM_COLS=$NUM_COLS+1
    fi

    # ----------------------------------------
    # Ouput prompt
    # ----------------------------------------
    echo "Select server to connect to"
    print_tables
}

### ----------------------------------------
### ----------------------------------------
### Functions finally called
### ----------------------------------------
### ----------------------------------------
function TMIsMounted {
    ret=1
    mount | grep "$MNTDIR" >/dev/null && ret=0
    return $ret
}


function TMUnmount {
    ret=1
    $ELE umount "$MNTDIR" && ret=0
    return $ret
}
#$MNTDIR


function call_ssh(){
    echo "Calling ssh $@"
    ssh "$@"
}

function call_lftp(){
    echo "Calling lftp -u $1, $2"
    lftp -u "$1", "$2"
}

function call_mount(){
    if [ "$1" == "" ]
    then
        echo "Invalid selection"
        return 1
    fi

    TM_MOPTS="PubkeyAcceptedKeyTypes=+ssh-rsa,allow_other,default_permissions,uid=$(id -u),gid=$(id -g)"
    mntuser=$(echo "$1" | cut -d ":" -f 1)
    mnttype=$(echo "$1" | cut -d ":" -f 2)
    mntdir=$(echo "$1" | cut -d ":" -f 3)
    mhost="$2"
    domount=0
    IsMounted=0
    TMIsMounted && IsMounted=1
    if [ "$IsMounted" == "1" ]
    then
        echo "There's already something mounted to $MNTDIR"
        echo "Should it be unmounted in order to proceed?"
        echo "Unmounting? (y/n)"
        read ShouldUnmount
        if [ "$ShouldUnmount" == "y" ]
        then
            TMUnmount && domount=1
        else
            echo "Ok, aborting without mounting"
        fi        
    else
        domount=1
    fi
    
    if [ "$domount" == "1" ]
    then
        if [[ $mhost =~ : ]]; then
            mhost="[$mhost]"
        fi    
        #echo "$ELE $mnttype -o $TM_MOPTS $mntuser@$mhost:$mntdir $MNTDIR" 
        $ELE $mnttype -v -o $TM_MOPTS "$mntuser""@""$mhost"":""$mntdir" "$MNTDIR" && echo "mounted to $MNTDIR"
    fi

}













### ----------------------------------------
### ----------------------------------------
### Function to work on numeric input
### ----------------------------------------
### ----------------------------------------

function SelectionWork(){
    GCOUNT=0
    SCOUNT=0
    FOUND=0
    # ----------------------------------------
    # Going through groups
    # ----------------------------------------
    PARTS=$(GetParts "$SETTINGS" "3")
    for PART in $PARTS
    do
            SCOUNT=0
    # - # ---------------------------------------
    # - # Going though the servers and find the one matching to answ
    # - # ---------------------------------------            
            SECS=$(GetParts "$SETTINGS" 4 | grep "^$PART" )
            for SEC in $SECS
            do
                let SCOUNT=$SCOUNT+1
                let IND=$SCOUNT+$GCOUNT
    # - # - # ---------------------------------------
    # - # - # We found it
    # - # - # ---------------------------------------
                if [ "$IND" == "$ANSW" ]
                then
                    FOUND=1
                    HOSTDATA=$(echo "$SETTINGS" | grep "^$SEC""_" | grep -v '_=' )
                        hname=$(echo "$HOSTDATA" | grep '_name=' | cut -d "'" -f 2)
                        hip=$(echo "$HOSTDATA" | grep '_ip=' | cut -d "'" -f 2)
                        hssh=$(echo "$HOSTDATA" | grep '_ssh='| cut -d "'" -f 2)
                        hlftp=$(echo "$HOSTDATA" | grep '_lftp=' | cut -d "'" -f 2)
                        hmnt=$(echo "$HOSTDATA" | grep '_mount=' | cut -d "'" -f 2)                        
                        SSTR="$SP("$IND") $hname"
    # - # - # ---------------------------------------
    # - # - # if lftp is set, give the user the option to select it, with timeout to ssh default
    # - # - # --------------------------------------- 
                    AddSvc=0;
                    if [ "$hlftp" != "" ]
                    then
                        let AddSvc=$AddSvc+1
                    fi
                    if [ "$hmnt" != "" ]
                    then
                        let AddSvc=$AddSvc+1
                    fi                          

                    if [ $AddSvc -gt 0 ]
                    then
                        if [ "$SSEL" != "" ]
                        then
                            b=$SSEL
                        else
                            echo "Connection type for $SSTR"
                            echo "(1) SSH [default - automatically selected in $INPWAIT seconds]"
                            svcnt=1

                            if [ "$hlftp" != "" ]
                            then
                                let svcnt=$svcnt+1
                                echo "($svcnt) LFTP"
                            fi
                            if [ "$hmnt" != "" ]
                            then
                                let svcnt=$svcnt+1
                                echo "($svcnt) Mount"                            

                            fi    


                            read -t $INPWAIT b
                        fi
                            if [ "$b" == "1" ]
                            then
                                #echo "Connecting to: $SSTR - ssh"
                                call_ssh "$hssh""@""$hip"

                            else
                                if [ "$b" == "2" ]
                                then

                                    if [ "$hlftp" != "" ]
                                    then
  #                                      echo "calling lftp"
                                        #                                CS="sftp://""$hip"
                                        #lftp -u "$hlftp", "$CS"
                                        call_lftp "$hlftp" "sftp://""$hip"
                                    else
 #                                       echo "calling mount"
                                        call_mount "$hmnt" "$hip"
                                    fi
                                else
                                    if [ "$b" == "3" ]
                                    then
#                                        echo "calling mount"
                                        call_mount "$hmnt" "$hip"

                                    else
                                        if [ "$b" == "" ]
                                        then
                                            call_ssh "$hssh""@""$hip"
                                        else
                                            echo -e "$CRW Invalid service selection $CRE"
                                        fi
                                    fi


                                fi
        
        
        
        
        
                            fi                            









                    else

                            #echo "Connecting to: $SSTR - ssh"
#                            CS="$hssh""@""$hip"
                            call_ssh "$hssh""@""$hip"
#                            ssh "$CS"



                    fi





    # - # - # ---------------------------------------                     
                fi
    # - # - # ---------------------------------------             
            done
    # - # ---------------------------------------         
        let GCOUNT=$GCOUNT+$GSTEP
    done
    # ----------------------------------------


    # ----------------------------------------
    # Server not found? Let the user know about it
    # ----------------------------------------
    if [ "$FOUND" != "1" ]
    then
        echo -e "$CRW -not a valid server selection- $CRE"
    fi

}

### ----------------------------------------
### ----------------------------------------
### Display a little info
### ----------------------------------------
### ----------------------------------------
function ShowInfo(){
    if [ "$1" != "" ]
    then
        echo "Error: $1"
        echo ""
    fi
    echo "Usage: "$(basename $0)" [serverid] [serviceid]"
    echo ""
    echo "If no serverid is provided a menu with the available server will be displayed"
    echo "If provided this will be skipped and a" 
    echo " - if only ssh is configured for the selected host create the ssh connection "
    echo " - if other services are defined a selection for the service to use is shown"
    echo "If a serviceid is provided (1=ssh, 2=lftp, 3=mount....) the connection will be established immediately"
    echo ""

    echo "Used configuration file "$(realpath "$CONFIG")

}

### ----------------------------------------
### ----------------------------------------
### External function. Copied in to have only one file
### ----------------------------------------
### ----------------------------------------

###############################################################################
#
# source: https://github.com/mrbaseman/parse_yaml.git
#
###############################################################################
# Parses a YAML file ('-' means standard input), or standard input if file is
# not given, and outputs variable assigments.  Can optionally accept a variable
# name prefix and a variable name separator if file is given.
#
# Usage:
#   parse_yaml
#   parse_yaml file|- [prefix] [separator]
###############################################################################

function parse_yaml {
    unset i
    unset fs
    local prefix=$2
    local separator=${3:-_}

    local indexfix=-1
    # Detect awk flavor
    if awk --version 2>&1 | grep -q "GNU Awk" ; then
        # GNU Awk detected
        indexfix=-1
    elif awk -Wv 2>&1 | grep -q "mawk" ; then
        # mawk detected
        indexfix=0
    fi

    local s='[[:space:]]*' sm='[ \t]*' w='[a-zA-Z0-9_.]*' fs=${fs:-$(echo @|tr @ '\034')} i=${i:-  }

    ###############################################################################
    # cat:   read the yaml file (or stdin) into the stream
    # awk 1: process multi-line text
    # sed 1: remove comments and empty lines
    # sed 2: process lists
    # sed 3: process dictionaries
    # sed 4: rearrange anchors
    # sed 5: remove '---'/'...'/quotes, add file separator to create fields for awk 2
    # awk 2: convert the formatted data to variable assignments
    ###############################################################################

    echo | cat ${1:--} - | \
    awk -F$fs "{multi=0;
        if(match(\$0,/$sm\|$sm$/)){multi=1; sub(/$sm\|$sm$/,\"\");}
        if(match(\$0,/$sm>$sm$/)){multi=2; sub(/$sm>$sm$/,\"\");}
        while(multi>0){
            str=\$0; gsub(/^$sm/,\"\", str);
            indent=index(\$0,str);
            indentstr=substr(\$0, 0, indent+$indexfix) \"$i\";
            obuf=\$0;
            getline;
            while(index(\$0,indentstr)){
                obuf=obuf substr(\$0, length(indentstr)+1);
                if (multi==1){obuf=obuf \"\\\\n\";}
                if (multi==2){
                    if(match(\$0,/^$sm$/))
                        obuf=obuf \"\\\\n\";
                        else obuf=obuf \" \";
                }
                getline;
            }
            sub(/$sm$/,\"\",obuf);
            print obuf;
            multi=0;
            if(match(\$0,/$sm\|$sm$/)){multi=1; sub(/$sm\|$sm$/,\"\");}
            if(match(\$0,/$sm>$sm$/)){multi=2; sub(/$sm>$sm$/,\"\");}
        }
    print}" | \
    sed -e "s|^\($s\)?|\1-|" \
        -ne "s|^\($s\)-$s\($w\)$s:$s\(.*\)|\1-\n\1 \2: \3|" \
        -ne "s|^$s#.*||;s|$s#[^\"']*$||;s|^\([^\"'#]*\)#.*|\1|;t 1" \
        -ne "t" \
        -ne ":1" \
        -ne "s|^$s\$||;t 2" \
        -ne "p" \
        -ne ":2" \
        -ne "d" | \
    sed -ne "s|,$s\]|]|g" \
        -e ":1" \
        -e "s|^\($s\)\($w\)$s:$s\(&$w\)$s\[$s\(.*\)$s,$s\(.*\)$s\]|\1\2: \3[\4]\n\1$i- \5|;t 1" \
        -e "s|^\($s\)\($w\)$s:$s\(&$w\)$s\[$s\(.*\)$s\]|\1\2: \3\n\1$i- \4|;" \
        -e ":2" \
        -e "s|^\($s\)\($w\)$s:$s\[$s\(.*\)$s,$s\(.*\)$s\]|\1\2: [\3]\n\1$i- \4|;t 2" \
        -e "s|^\($s\)\($w\)$s:$s\[$s\(.*\)$s\]|\1\2:\n\1$i- \3|;" \
        -e ":3" \
        -e "s|^\($s\)-$s\[$s\(.*\)$s,$s\(.*\)$s\]|\1- [\2]\n\1$i- \3|;t 3" \
        -e "s|^\($s\)-$s\[$s\(.*\)$s\]|\1-\n\1$i- \2|;p" | \
    sed -ne "s|,$s}|}|g" \
        -e ":1" \
        -e "s|^\($s\)-$s{$s\(.*\)$s,$s\($w\)$s:$s\(.*\)$s}|\1- {\2}\n\1$i\3: \4|;t 1" \
        -e "s|^\($s\)-$s{$s\(.*\)$s}|\1-\n\1$i\2|;" \
        -e ":2" \
        -e "s|^\($s\)\($w\)$s:$s\(&$w\)$s{$s\(.*\)$s,$s\($w\)$s:$s\(.*\)$s}|\1\2: \3 {\4}\n\1$i\5: \6|;t 2" \
        -e "s|^\($s\)\($w\)$s:$s\(&$w\)$s{$s\(.*\)$s}|\1\2: \3\n\1$i\4|;" \
        -e ":3" \
        -e "s|^\($s\)\($w\)$s:$s{$s\(.*\)$s,$s\($w\)$s:$s\(.*\)$s}|\1\2: {\3}\n\1$i\4: \5|;t 3" \
        -e "s|^\($s\)\($w\)$s:$s{$s\(.*\)$s}|\1\2:\n\1$i\3|;p" | \
    sed -e "s|^\($s\)\($w\)$s:$s\(&$w\)\(.*\)|\1\2:\4\n\3|" \
        -e "s|^\($s\)-$s\(&$w\)\(.*\)|\1- \3\n\2|" | \
    sed -ne "s|^\($s\):|\1|" \
        -e "s|^\($s\)\(---\)\($s\)||" \
        -e "s|^\($s\)\(\.\.\.\)\($s\)||" \
        -e "s|^\($s\)-${s}[\"']\(.*\)[\"']$s\$|\1$fs$fs\2|p;t" \
        -e "s|^\($s\)\($w\)$s:${s}[\"']\(.*\)[\"']$s\$|\1$fs\2$fs\3|p;t" \
        -e "s|^\($s\)-$s\(.*\)$s\$|\1$fs$fs\2|" \
        -e "s|^\($s\)\($w\)$s:${s}[\"']\?\(.*\)$s\$|\1$fs\2$fs\3|" \
        -e "s|^\($s\)[\"']\?\([^&][^$fs]\+\)[\"']$s\$|\1$fs$fs$fs\2|" \
        -e "s|^\($s\)[\"']\?\([^&][^$fs]\+\)$s\$|\1$fs$fs$fs\2|" \
        -e "s|^\($s\)\($w\)$s:${s}[\"']\(.*\)$s\$|\1$fs\2$fs\3|" \
        -e "s|^\($s\)[\"']\([^&][^$fs]*\)[\"']$s\$|\1$fs$fs$fs\2|" \
        -e "s|^\($s\)[\"']\([^&][^$fs]*\)$s\$|\1$fs$fs$fs\2|" \
        -e "s|^\($s\)\($w\)$s:$s\(.*\)$s\$|\1$fs\2$fs\3|" \
        -e "s|^\($s\)\([^&][^$fs]*\)[\"']$s\$|\1$fs$fs$fs\2|" \
        -e "s|^\($s\)\([^&][^$fs]*\)$s\$|\1$fs$fs$fs\2|" \
        -e "s|$s\$||p" | \
    awk -F$fs "{
        gsub(/\t/,\"        \",\$1);
        if(NF>3){if(value!=\"\"){value = value \" \";}value = value  \$4;}
        else {
            if(match(\$1,/^&/)){anchor[substr(\$1,2)]=full_vn;getline};
            indent = length(\$1)/length(\"$i\");
            vname[indent] = \$2;
            value= \$3;
            for (i in vname) {if (i > indent) {delete vname[i]; idx[i]=0}}
            if(length(\$2)== 0){  vname[indent]= ++idx[indent] };
            vn=\"\"; for (i=0; i<indent; i++) { vn=(vn)(vname[i])(\"$separator\")}
            vn=\"$prefix\" vn;
            full_vn=vn vname[indent];
            if(vn==\"$prefix\")vn=\"$prefix$separator\";
            if(vn==\"_\")vn=\"__\";
        }
        gsub(/\./,\"$separator\",full_vn);
	gsub(/\\\\\"/,\"\\\"\",value);
	gsub(/'/,\"'\\\"'\\\"'\",value);
        assignment[full_vn]=value;
        if(!match(assignment[vn], full_vn))assignment[vn]=assignment[vn] \" \" full_vn;
        if(match(value,/^\*/)){
            ref=anchor[substr(value,2)];
            if(length(ref)==0){
                printf(\"%s='%s'\n\", full_vn, value);
            } else {
                for(val in assignment){
                    if((length(ref)>0)&&index(val, ref)==1){
                        tmpval=assignment[val];
                        sub(ref,full_vn,val);
                        if(match(val,\"$separator\$\")){
                            gsub(ref,full_vn,tmpval);
                        } else if (length(tmpval) > 0) {
                            printf(\"%s='%s'\n\", val, tmpval);
                        }
                        assignment[val]=tmpval;
                    }
                }
            }
        } else if (length(value) > 0) {
            printf(\"%s='%s'\n\", full_vn, value);
        }
    }END{
        for(val in assignment){
            if(match(val,\"$separator\$\"))
                printf(\"%s='%s'\n\", val, assignment[val]);
        }
    }"
}


# ----------------------------------------
# Here ends the external function. 
# ----------------------------------------

### ----------------------------------------
### ----------------------------------------
### ----------------------------------------
### End of functions
### ----------------------------------------
### ----------------------------------------
### ----------------------------------------



###############################################################################
#
# Script execution
#
###############################################################################

# ----------------------------------------
# 
# ----------------------------------------

# ----------------------------------------
# Reading yaml file
# ----------------------------------------
SETTINGS=$(parse_yaml "$CONFIG")
# ----------------------------------------
# Set some variables
# ----------------------------------------
GCOUNT=0
MLEN=0
MAXINROW=3
NUMHEAD=0
HL=""


# ----------------------------------------
# Work on script arguments
# ----------------------------------------

case "$1" in
    ''|*[!0-9]*) # Non-numeric input or empty
        if [[ "$1" =~ ^-?[uU]$ ]]; then
            TMIsMounted && TMUnmount && echo "Unmounted $MNTDIR" && exit 0
        elif [[ "$1" =~ ^-?[hH]$ ]]; then
            ShowInfo
        else

            MenuGenerator
            TMIsMounted && echo "There's already something mounted to $MNTDIR" && echo "Enter u to unmount and exit"
            
            read ANSW_ARRAY # Read input as an array
            ANSW=$(echo "$ANSW_ARRAY" | awk '{print $1}' ) 
            #read ANSW
                if [ "$ANSW" == "u" ]
                then
                    TMUnmount
                    exit 0
                fi

                if [ "$ANSW" == "" ]
                then
                    echo "Not a valid selection (numbers only)"
                    exit 0
                fi 
            SPART=$(echo "$ANSW_ARRAY" | awk '{print $2}' )
            if [ "$SPART" != "" ]
            then
                SSEL=$SPART
            fi                        
            SelectionWork    

        fi
        ;;
    *) # Numeric input
        ANSW=$1
        if [[ "$2" =~ ^[1-9]$ ]]
        then
            SSEL=$2
        fi
        SelectionWork
        ;;
esac



