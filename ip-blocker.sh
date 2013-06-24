#!/bin/bash

### DEBUGGING ###

#set -x
#set -n

_dbg(){

 if [ "$DEBUG" = "1" ]; then
   echo $*
 fi

}

### USER SETTINGS ###

# ON: 1, OFF: 0
DEBUG="1"

# FQDN of Source Server
SERVER="lanixx.com"
LOCAL_FILE="/etc/ip-blocker.list"
REMOTE_FILE="liste.txt"

### COMMON SETTINGS ###

WHICH=$(which which)
IPTAB=$($WHICH iptables)
WGET=$($WHICH wget)
GREP=$($WHICH grep)
WC=$($WHICH wc)
TR=$($WHICH tr)
TEST=$($WHICH test)
SORT=$($WHICH sort)
CAT=$($WHICH cat)
DIFF=$($WHICH diff)
RM=$($WHICH rm)

_dbg
_dbg $WHICH $IPTAB $WGET $GREP $WC $TR $TEST $SORT $CAT $DIFF $RM
_dbg

### TESTS ###

test -f $LOCAL_FILE || _exit "0"; 

### FUNCTIONS ###

_exit(){

  _dbg "Syntax: $0"
  _dbg "Exit Code :: $1"
  exit $1;

}

_status(){

 _status_=$(echo $?)
 if [ "$_status_" = "0" ]; then
   _dbg " ... ok"
 else
   _dbg " ... fail"
   _exit 1;
 fi
 _dbg

}

_break(){

  _dbg " ### Break"
  _dbg 
  continue;

}


db_update(){

 _dbg "=> update"
 TMP_FILE=$(mktemp)
 TMP_FILE_2=$(mktemp)
 $WGET http://$SERVER/$REMOTE_FILE -O $TMP_FILE > /dev/null 2>&1
 $CAT $TMP_FILE | $SORT -u | tr '[a-z]' '[A-Z]' > $TMP_FILE_2

 FILE_DIFF=$($DIFF $TMP_FILE_2 $LOCAL_FILE)

 if [ "$FILE_DIFF" = "" ]; then
   _dbg " --- diff ist leer"
   _exit 0;
 else
   $CAT $TMP_FILE_2 > $LOCAL_FILE
  _status;
fi

$RM $TMP_FILE $TMP_FILE_2

}

check_ip_double(){

 _dbg "=> double"
 _dbg $1 :: $2 :: $3
 DOUBLE=$($GREP $1 $LOCAL_FILE | $WC -l)
 _status;
 _dbg $DOUBLE;
 if [ $DOUBLE -gt 1 ]; then
  _dbg " --- double ip";
  _break;
 fi
 _dbg

}

check_ip_avail(){

 _dbg "=> avail"
 _dbg $1 :: $2 :: $3
 
 # checken ob die Regel richtig geschrieben ist
 if ( ! $TEST "$2" = "ACCEPT" -o "$2" = "DROP" -o "$2" = "REJECT" )
 then
  _dbg " --- IPTABLES falsch";
  _break;
 fi

 AVAIL=$($IPTAB -L $3 -n | $GREP $1)
 _dbg "$AVAIL :: $IPTAB -L $3 -n | grep $1"
 if [ "$AVAIL" != "" ]; then
  _dbg " --- avail ip";
  _break;
 fi
 _dbg

}

run_rule(){

 _dbg "=> run rule"
 _dbg $1 :: $2 :: $3
 $IPTAB -I $3 -s $1 -j $2
 _status;

}

### MAIN ###

# mache update der rule Datei
db_update;

while read -r IP ACTION CHAIN
do

  _dbg " ### start while loop"
  _dbg

  # Teste ob die Variablen nicht leer sind
  test "$IP" = "" && echo "IP nicht angegeben" && _break;
  test "$ACTION" = "" && echo "ACTION nicht angegeben" && _break;
  test "$CHAIN" = "" && echo "CHAIN nicht angegeben" && _break;

  # fuehre aktionen durch
  check_ip_double "$IP" "$ACTION" "$CHAIN";
  check_ip_avail "$IP" "$ACTION" "$CHAIN";
  run_rule "$IP" "$ACTION" "$CHAIN";

  _dbg " ### stop while loop"
  _dbg

done < $LOCAL_FILE
