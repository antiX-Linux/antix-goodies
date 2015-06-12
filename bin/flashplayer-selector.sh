#!/bin/bash


# --------------------
# Help and Information
# --------------------

# Test for a help request or an invalid command
if [ "$1" != '' ] ; then
cat << end-of-messageblock

Usage: $(basename "$0") 
The script does not use command line parameters.

Information:
   This script is used to select which version of Flash Player the system uses.

   Via a menu it performs either of two main tasks:
   1. Download and install the latest version,
   2. Revert to an older version by re-installing a previously installed one.

   $(basename "$0") should be available in the path; located in either /usr/sbin 
   or /usr/local/sbin.  It must be run with root privileges as the installation 
   proceses requires access to areas owned by root.

Requires: 
   basename, bash, grep, select, tar, update-flashplugin-nonfree

end-of-messageblock
   exit 0
fi



# -------------------------------------------
# Find out what action the user wants to take
# -------------------------------------------

# Display options
clear
echo ''
echo 'Flash Player Selector'
echo 'Options:'
echo 'Cancel   - Exit without making any changes'
echo 'Download - Obtain and install the latest version'
echo 'Revert   - Re-install a previously installed version'
echo ''


# Obtain user input
echo 'What do you want to do?'
PS3='Enter the number of your selection: '
select ACTION in "Cancel" "Download" "Revert" 
do
   break
done



# ----------------------------
# Conduct the requested action
# ----------------------------

# Exit without making any changes
if [ "$ACTION" != Download -a "$ACTION" != Revert ]; then
   echo ''
   echo ''
   echo "Exiting" 
   exit 0
fi


# Install newest version
if [ "$ACTION" = Download ]; then

   # Display the version installed currently
   echo ''
   echo ''
   echo "$(update-flashplugin-nonfree --status | grep LNX) is currently installed"
   sleep 2

   # Obtain and install the newest version
   update-flashplugin-nonfree --install

   # Display the version installed now
   echo ''
   echo "$(update-flashplugin-nonfree --status | grep LNX) is installed" 
fi


# Install a previous version
if [ "$ACTION" = Revert ]; then

   # Display the version installed currently
   echo ''
   echo ''
   echo "$(update-flashplugin-nonfree --status | grep installed) is currently installed"
   sleep 2

   # Obtain user input
   echo ''
   echo 'Which of the previously installed versions do you want to re-install?'
   PS3='Enter the number of your selection: '
      select FILENAME in /var/cache/flashplugin-nonfree/*
      do
         break
      done

   # Re-install the selected version
   tar --directory=/usr/lib/flashplugin-nonfree --extract --file=$FILENAME libflashplayer.so

   # Display the version installed now
   echo ''
   echo "$(update-flashplugin-nonfree --status | grep installed) is installed"
fi 



# -----
# Close
# -----

# Add blank lines before returning to the command prompt
echo ''
echo ''
exit 0
