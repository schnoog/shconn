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
# Functions
#
###############################################################################

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
      output+="${LABELARR[$col]}\t"
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
                SP=""
                if [ $IND -lt 10 ]
                then
                    SP=" "
                fi 
                LFTPIND=""
                if [ "$hlftp" != "" ]
                then
                    LFTPIND="(+lftp)"
                fi
                SERVERS+=( "$SP("$IND") $hname $LFTPIND" )
                SSTR="$SP("$IND") $hname $LFTPIND"
                SERVERARR[$NUMHEAD,$SCOUNT]="$SSTR"
                CURRLEN=${#SSTR}
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
    fi

    # ----------------------------------------
    # Ouput prompt
    # ----------------------------------------
    echo "Select server to connect to"
    print_tables
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
                        SSTR="$SP("$IND") $hname"
    # - # - # ---------------------------------------
    # - # - # if lftp is set, give the user the option to select it, with timeout to ssh default
    # - # - # --------------------------------------- 

                        if [ "$hlftp" != "" ]
                        then
                            echo "Connection type for $SSTR"
                            echo "(1) SSH [default - automatically selected in $INPWAIT seconds]"
                            echo "(2) LFTP"
                            read -t $INPWAIT b
                            if [ "$b" == "2" ]
                            then
                                echo "Connecting to: $SSTR - lftp"
                                CS="sftp://""$hip"
                                lftp -u "$hlftp", "$CS"
                            else
                                echo "Connecting to: $SSTR - ssh"
                                CS="$hssh""@""$hip"
                                ssh "$CS"
                            fi
                        else
                            echo "Connecting to: $SSTR - ssh"
                            CS="$hssh""@""$hip"
                            ssh "$CS"
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
        echo "-not a valid selection-"
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
    fi
    echo "Usage: ./"$0" [serverid]"
    echo "If no serverid is provided a menu with the available server will be displayed"
    echo "If provided this will be skipped and a connection prepared" 


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


if [[ ! $1 =~ ^[0-9]+$ ]]; then
    if [ "$1" == "" ]
    then
        MenuGenerator
        read ANSW
            if [ "$ANSW" == "" ]
            then
                echo "Not a valid selection (numbers only)"
                exit 0
            fi        
        SelectionWork        


    else
        ShowInfo "(yet) Unknown argument"

    fi





else
    #Numeric
    ANSW=$1
    SelectionWork

fi






#MenuGenerator
# ----------------------------------------
# Wait for answer
# ----------------------------------------

#read ANSW

#SelectionWork
# ----------------------------------------
# Drop out if answer is empty
# ----------------------------------------




