#!/usr/bin/bash
IFS="
"


SCRIPTPATH=$(dirname "$(realpath $0)")

SCRIPTFN="$SCRIPTPATH""/shconn.sh"


DEFCONFIG="$SCRIPTPATH""/.shconfig.yml.dist"

FILE="$HOME/.shconfig.yml"
if [ ! -f $FILE ]; then
    cp "$DEFCONFIG" "$FILE"
    echo "inst to $USER home"
fi

SD=""
if [ "$UID" != "0" ]
then
    SD="sudo"
fi

FILE="/etc/.shconfig.yml"
if [ ! -f $FILE ]; then
    $SD cp "$DEFCONFIG" "$FILE"
    echo "inst to etc"
fi

$SD cp "$SCRIPTFN" /bin/

