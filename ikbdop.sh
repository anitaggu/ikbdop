#
# USE: This simple shell program can be used to disable the internal keyboard of a laptop in case you want to use external keyboard. This can be done by
# $ ./ikbdop.sh detach
#
# To attach the internal keyboard again, use the command
# $ ./ikbdop.sh attach
# 
# USAGE: When the internal laptop keyboard goes defective, it usually results in continuous generation of some keyboard character, thereby making it impossible to do any commandline stuff. This shell program is an easy fix.
#
#
# Author: anitaggu@gmail.com
#

#!/bin/bash


#-----------------------------------------------------
# usage()
#
# ARGS: All commandline arguments passed to shell.
# 
# Checks if option is either status, detach or attach
# Exits program if improper usage
#
# RETURNS: Nothing
#-----------------------------------------------------
usage() 
{
	USAGE=`echo "$0 [status | detach | attach ]"`
	if [  $# -ne 1 ]
	then
		echo $USAGE
		exit 1
	fi
}

readonly mode_attached=2
readonly mode_detached=3
readonly attach_pattern='AT Translated Set 2 keyboard[[:space:]]*id=[[:digit:]]*[[:space:]]*\[slave  keyboard \([[:digit:]]*\)\]'
readonly detach_pattern='AT Translated Set 2 keyboard[[:space:]]*id=[[:digit:]]*[[:space:]]*\[floating slave\]'
readonly masterkbd_pattern='\[slave[[:space:]]*keyboard[[:space:]]*\([[:digit:]]*\)\]'


#-----------------------------------------------------------
# find_status()
#
# ARGS: None
#
# Uses the output of xinput list command to detect whether
# keyboard attached or detached
#
# RETURNS: 
# 2 if keyboard attached
# 3 if keyboard dettached
#-----------------------------------------------------------

find_status() {
xinput list | awk -v attach_pattern='$attach_pattern' \
		  -v detach_pattern='$detachpattern'  \
		  -v mode_attached='$mode_attached'   \
		  -v mode_detached='$mode_detached'   \
'
/'"$attach_pattern"'/ {
	#print "Internal Keyboard attached"
	mode='"$mode_attached"' #kbd attached
}
/'"$detach_pattern"'/ {
	#print "Internal Keyboard detached"
	mode='"$mode_detached"' #kbd dettached
}
END {
	exit mode
}'
return $?
}

#-------------------------------------------------------------
# find_attached_kbd_id()
#
# ARGS: None
# PRE-CONDITION: The internal keyboard must be attached.
# RETURNS: device id of the attached internal keyboard
#-------------------------------------------------------------

find_attached_kbd_id() 
{

	xinput list | awk -v attach_pattern='$attach_pattern' '
		/'"$attach_pattern"'/ {
			id=$7
			gsub("id=","", id)
			#print id
		}
		END {
			exit id
		}'
	return $?
}

#
# find_detached_kbd_id()
#
# ARGS: None
# PRE-CONDITION: The internal keyboard must be detached.
# 
# Function returns the device id
#

find_detached_kbd_id() 
{

	xinput list | awk -v detach_pattern='$attach_pattern' '
		/'"$detach_pattern"'/ {
			id=$7
			gsub("id=","", id)
			#print id
		}
		END {
			exit id
		}'
	return $?
}

find_master_kbd_id() 
{

	xinput list | awk -v masterkbd_pattern='$masterkbd_pattern' '
		BEGIN {
			masterid = -1 # impossible master id
		}
		/'"$masterkbd_pattern"'/ {
			id=$0 #save entire string to id first
			gsub(".*\[slave[[:space:]]*keyboard[[:space:]]*\(","", id) #remove preceding junk
			gsub("\)\]","", id) #remove trailing )]
			if (masterid == -1) { 
				masterid = id # initialize masterid 
				#printf("Initialized masterid to %d\n", masterid)
			} else {
				#check if new master keyboard IDs are different.
				if (masterid != id) {
					printf("ERROR: Stored master keyboard ID %d is different from new ID %d\n", masterid, id);
					exit -1 # More than one master keyboards found cannot safely reattach
				}
			}
		}
		END {
			exit masterid	
		}'
	#return $?
}

#----------------------------------------
# MAIN PROGRAM STARTS FROM HERE
#----------------------------------------

usage $*

case $1 in

status) 
	find_status
	stat=$?
	if [ $stat -eq $mode_detached ]
	then
		echo "$0: Internal keyboard detached"
	else
		echo "$0: Internal keyboard attached"
	fi
	exit 0
;;
detach)
	find_status
	stat=$?
	if [ $stat -eq $mode_detached ]
	then
		echo "$0: Internal keyboard already detached. No action taken."
		exit 0
	fi

	find_attached_kbd_id
	kbd_id=$?
	detach_cmd=`echo "xinput float $kbd_id"`
	echo "Executing command: $detach_cmd"
	$detach_cmd
	exit $?	
;;

attach)
	find_status
	stat=$?
	if [ $stat -eq $mode_attached ]
	then
		echo "$0: Internal keyboard already attached. No action taken."
		exit 0
	fi

	find_detached_kbd_id
	kbd_id=$?

	find_master_kbd_id
	masterid=$?

	attach_cmd=`echo "xinput reattach $kbd_id $masterid"`
	echo "Executing command: $attach_cmd"
	$attach_cmd
	exit $?

;;

*)
	usage $*
;;

esac

