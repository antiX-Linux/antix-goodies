#!/bin/bash

# unplugdrive.sh
#
# Enables unmounting prior to unplugging removable storage
# Allows simultaneous selection of multiple drives
# Unmounts all mounted partitions on nominated drive(s)
# Removes mountpoints
#
# Requires yad and pmount to be installed.
# Requires /etc/udev/rules.d/99-usbstorage.unused to be renamed 99-usbstorage

TEXTDOMAINDIR=/usr/share/locale
TEXTDOMAIN=unplugdrive.sh

# Collect details of each removable device that has at least one mounted partition
discovered=$(pmount|grep /dev/|sort|tr ' ' '_'|cut -d _ -f 1,2,3)

# Create a list of removable devices excluding CD/DVD
for item in $discovered;do
   if [[ ! $item = /dev/sr* ]];then
     detectedlist="$detectedlist$item "
   fi
done

# Create a list of each removable drive, mounted partition and mountpoint
removablelist=""
removablenow=""
for item in $detectedlist;do
   removablenow=$(echo $item|cut -c 6-|tr '_' ' ')
   removablelist="$removablelist$removablenow\n"
done

# Create a list of each unplugable drive
drivelist=""
drivenow=""
driveprevious=""
position=0
for item in $detectedlist;do
   drivenow=$(echo $item|cut -d _ -f 1|cut -c 6-8)
   if [ "$drivenow" != "$driveprevious" ];then
      drivelist="$drivelist $position $drivenow"
      driveprevious=$drivenow
   fi
   position=$(expr $position + 1)
done

# Display a message that no candidate for unmounting was discovered
if [ -z "$drivelist" ];then
   yad --text $"A removable drive with a mounted partition was not found.\nIt is safe to unplug the drive(s)"
   exit 0
fi

# Display a list from which the drives to be unplugged may be selected
selected=$(yad --list --width="300" --height="350"  --text=$"The following are currently mounted:\n$removablelist\nChoose the drive(s) to be unplugged\n" --checklist --column="Select" --column="Drives" --separator=" " $drivelist)
   if [ -z "$selected" ];then
      yad --text=$"Nothing selected.\nAborting without unmounting."
      exit 1
   fi
echo selected is $selected

# Create a list of mountpoints used by the drives selected to be unplugged
declare -a mountpointlist
mountpointnow=""

TEMPFILE=/tmp/unpluglist
for item in $selected;do
   if [ "$item" = "TRUE" ] ||[ "$item" = "FALSE" ]; then
	echo "nothing"
   else
   #mountpointnow=$(df |grep $item|awk -F "% " '{print $2}')
   df |grep $item|awk -F "% " '{print $2}'| tee -a $TEMPFILE  
   fi
done
OLDIFS=$IFS
IFS=$'\n'
mountpointlist=(`cat $TEMPFILE`)
   echo mountlist0 is ${mountpointlist[0]}
   echo mountlist1 is ${mountpointlist[1]}
   echo mountlist2 is ${mountpointlist[2]}
   rm -f $TEMPFILE


# Create a list summarising what is about to be unmounted
IFS=$OLDIFS
summarylist=""
summarypoint=""
for item in $selected;do
   if [ "$item" = "TRUE" ] ||[ "$item" = "FALSE" ]; then
	echo "nothing"
   else
   echo item is $item
   summarypoint=$(df --output=source,target |grep $item)
   echo summarypoint is $summarypoint
   summarylist="$summarylist$summarypoint\n"
   fi
done
echo summary list is $summarylist

# Obtain confirmation to proceed with unmounting
yad --text=$"About to unmount:\n$summarylist\nPlease confirm you wish to proceed."
if [ $? = "1" ];then
   yad --text=$"Nothing has been unmounted.\nAborting as requested with no action taken."
   exit 1
else
# Ensure everything is written to storage then unmount
   yad --text=$"Data is being written to devices.\nPlease wait..." & pid1="$!"
   sync
   kill $pid1
   count=${#mountpointlist[@]}
   echo count is $count
   i=0
   while [ "$i" -lt "$count" ]
   do
    #$(pumount $item)
	echo item $i is ${mountpointlist[i]}
	pumount "${mountpointlist[i]}"
	i=$[$i+1]
   done
fi

#  Collect details of each removable device that has at least one mounted partition
postunmount=$(pmount|grep /dev/|sort|cut -d _ -f 1,2,3)

# Collect details of each mountpoint that pumount failed to remove

mountpointerrorlist=""
   i=0
   while [ "$i" -lt "$count" ]
   do
   echo error check mount point ${mountpointlist[i]}
 	mountpointerror=$(pmount|grep /dev/|sort|cut -d _ -f 1,2,3|grep -o "${mountpointlist[i]}")
 	echo mountpointerror is $mountpointerror
	if [ ! -z "$mountpointerror" ];then
      mountpointerrorlist="$mountpointerrorlist$mountpointerror\n"
   fi
   i=$[$i+1]
   done

# Display a message if unmount failed
if [ ! -z "$mountpointerrorlist" ];then
   yad --text=$"Mountpoint removal failed.\n\nA mountpoint remains present at:\n$mountpointerrorlist\nCheck each mountpoint listed before unpluging the drive(s)."
   exit 1
else
   # Display a message if unmount successful   
   yad --text=$"Unmounted:\n$summarylist\nIt is safe to unplug the drive(s)"
   exit 0
fi
