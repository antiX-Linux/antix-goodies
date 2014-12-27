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

# Create a list of mountpoints used by the drives selected to be unplugged
mountpointlist=""
mountpointnow=""
for item in $selected;do
   mountpointnow=$(pmount|grep $item|cut -d " " -f 3)
   mountpointlist="$mountpointlist$mountpointnow "
done

# Create a list summarising what is about to be unmounted
summarylist=""
summarypoint=""
for item in $selected;do
   summarypoint=$(pmount|grep $item|cut -d " " -f 1,2,3|cut -c 6-)
   summarylist="$summarylist$summarypoint\n"
done

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
   for item in $mountpointlist;do
      $(pumount $item)
   done
fi

#  Collect details of each removable device that has at least one mounted partition
postunmount=$(pmount|grep /dev/|sort|cut -d _ -f 1,2,3)

# Collect details of each mountpoint that pumount failed to remove
mountpointerror=""
mountpointerrorlist=""
for item in $mountpointlist;do
   mountpointerror="$(echo $postunmount|grep -o $item)"
   if [ ! -z $mountpointerror ];then
      mountpointerrorlist="$mountpointerrorlist$mountpointerror\n"
   fi
done

# Display a message if unmount failed
if [ ! -z "$mountpointerrorlist" ];then
   yad--text=$"Mountpoint removal failed.\n\nA mountpoint remains present at:\n$mountpointerrorlist\nCheck each mountpoint listed before unpluging the drive(s)."
   exit 1
else
   # Display a message if unmount successful   
   yad --text=$"Unmounted:\n$summarylist\nIt is safe to unplug the drive(s)"
   exit 0
fi
