#!/bin/bash

# Salt module: GIS workstation environment for multiple computers
# Copyright (C) 2018  Pekka Helenius
#
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program.  If not, see <https://www.gnu.org/licenses/>.

###########################################################

# Salt master requirement: Ubuntu 18.04 LTS or variants
# Salt minion requirement: Microsoft Windows and/or Ubuntu 18.04 LTS or variants

###########################################################

# Test connection to minion computers and ask for confirmation to continue. 
# May be useful in some situations but consider disabling the check 
# in large automated cluster environments.
#
# If accepted minion computer can't be reached and the value is true, 
# user is asked for input
#
# Default value: true
#
TEST_MINION_PING="true"

# Automatically accept all minion computers?
# If not true, user is asked for input for each unaccepted minion ID
#
# Default value: true
#
AUTOACCEPT_MINIONS="true"

# Use more verbose debug output for Salt master?
#
# Default value: true
#
SALT_DEBUG="true"

# Run salt only locally (I.E. test localhost minion)?
#
# Another implementation would be using 'salt-call' command
#
# Default value: true
#
SALT_LOCALONLY="false"

###########################################################
# Check root
function checkRoot() {
    if [ $(id -u) -ne 0 ]; then
        echo "Run the script with root permissions (sudo or root)."
        exit 1
    fi
}

checkRoot

###########################################################
# Check for command dependencies

function checkCommands() {
    if [[ $(which --help 2>/dev/null) ]] && [[ $(echo --help 2>/dev/null) ]]; then

        COMMANDS=(grep mkdir systemctl id wget cat tee awk sed tr chmod cp rm mv touch dpkg apt-cache apt-get)

        a=0
        for command in ${COMMANDS[@]}; do
            if [[ ! $(which $command 2>/dev/null) ]]; then
                COMMANDS_NOTFOUND[$a]=$command
                let a++
            fi
        done

        if [[ -n $COMMANDS_NOTFOUND ]]; then
            echo -e "\n${bash_red}Error:${bash_color_default} The following commands could not be found: ${COMMANDS_NOTFOUND[*]}\nAborting\n"
            exit 1
        fi
    else
        exit 1
    fi
}

checkCommands

###########################################################
# Check Salt master Linux distribution

if [[ -f /etc/os-release ]]; then

    MASTER_DISTRO=$(grep ^VERSION_ID /etc/os-release | grep -oP '(?<=")[^"]*')

    if [[ $MASTER_DISTRO != "18.04" ]]; then
        echo -e "This script is supported only on Ubuntu 18.04 LTS. Aborting.\n"
        exit 1
    fi

else

    echo -e "Can't recognize your Linux distribution. Aborting.\n"
    exit 1

fi

###########################################################
# Welcome message

function welcomeMessage() {

    echo -e "This script will install GIS workstation environment for multiple Ubuntu 18.04 LTS & MS Windows computers.\n\nSoftware:\n\n -QGIS\n -CloudCompare\n -LASTools\n -QuickRoute\n -Merkaartor\n -etc.\n"

    read -r -p "Continue? [y/N] " answer

    if [[ ! $(echo $answer | sed 's/ //g') =~ ^([yY][eE][sS]|[yY])$ ]]; then
        echo -e "Aborting.\n"
        exit 1
    fi

    unset answer

}

welcomeMessage

###########################################################
# Check network connection

function checkInternet() {
    if [[ $(echo $(wget --delete-after -q -T 5 github.com -o -)$?) -ne 0 ]]; then
        echo -e "\nInternet connection test failed (GitHub). Please check your connection and try again.\n"
        exit 1
    fi
}

###########################################################

if [[ ! -d /srv/{salt,pillar} ]]; then
    mkdir -p /srv/{pillar,salt/win/repo-ng/installers}
fi

cp -R srv_salt/* /srv/salt/
cp -R srv_salt_winrepo/* /srv/salt/win/repo-ng/
cp -R srv_pillar/* /srv/pillar

###########################################################

if [[ ! -d compiled ]]; then
    mkdir compiled
fi

###########################################################
# Run scripts

checkInternet

if [[ $(systemctl is-active salt-master) != "active" ]]; then
    bash ./saltscripts/1-setup-salt-env.sh
fi

function minionAcceptPolicy() {

    echo -e "\nApplying minion ID key policy\n"

    if [[ $AUTOACCEPT_MINIONS == "true" ]]; then
        salt-key -y -A | sed '/^The key glob/d'
    else

        for accept_minion in $(salt-key | sed '/Unaccepted Keys/,/Rejected Keys/!d;//d'); do
            salt-key -a $accept_minion
        done

    fi

    echo -e "Current policy:\n$(salt-key)"

}

if [[ $SALT_LOCALONLY != "true" ]]; then
    minionAcceptPolicy
else
    salt-key -y -D &> /dev/null
    systemctl restart salt-minion.service
    if [[ $? -eq 0 ]]; then
        sleep 5
        salt-key -y -a defaultMinion

        if [[ $(salt-key | sed '/Accepted Keys/,/Unaccepted Keys/!d;//d' | grep defaultMinion | wc -w) -eq 0 ]]; then
            exit 1
        fi

    fi
fi

function checkWinMinions() {

    local IFS=$'\n'

    WINMINIONS=""

    if [[ $SALT_LOCALONLY != "true" ]]; then

        echo -e "Checking for accepted Windows minions. Please wait.\n"

        for win_minion in $(salt-key | sed '/Accepted Keys/,/Unaccepted Keys/!d;//d'); do

            if [[ $(salt $win_minion grains.item os 2> /dev/null | sed '$!d; s/^\s*//; /^No minions/d') == "Windows" ]]; then
                WINMINIONS="true"
            fi

        done
    fi

}

echo -e "\nSalt master - version: $(salt-call grains.item saltversion | sed -n '$p' | sed -e 's/\s//g')"
echo -e "Salt master - reported IP addresses: $(salt-call network.ip_addrs  | sed '1d; s/^.*\-\s//' | sed ':a;N;$!ba;s/\n/, /g')\n"

checkWinMinions

bash ./saltscripts/2-get-programs-on-master.sh ${SALT_LOCALONLY} ${WINMINIONS}

###########################################################
# Fix permissions

for dir in /srv/salt /srv/pillar; do
    find $dir -type d -exec chmod u=rwx,go=rx {} +
    find $dir -type f -exec chmod u=rw,go=r {} +
done

###########################################################
# Test minion connectivity

function testMinions() {

    local IFS=$'\n'

    MASTER_VERSION=$(dpkg -s salt-master | grep '^Version:' | awk '{print $2}')

    ACCEPTED_MINIONS=$(salt-key | sed '/Accepted Keys/,/Denied Keys/!d;//d')

    i=0
    m=1
    for check_minion in $ACCEPTED_MINIONS; do

        echo -e "Testing minion '$check_minion' ($m / $(echo $ACCEPTED_MINIONS | wc -w))"

        if [[ $(echo $(salt $check_minion test.ping) | awk '{print $NF}') != "True" ]]; then
            echo -e "Can't connect to Salt minion '\e[91m$check_minion\e[0m'. Make sure the minion computer is connected and\nSalt minion program version matches with the Salt master version ($MASTER_VERSION)\nIf they do match, delete old master public key from the minion computer, restart Salt minion service and try again."
            echo -e "\nThe master key is stored at the following locations:\n\n -Windows: C:\salt\\\\conf\pki\minion\minion_master.pub\n -Linux: /etc/salt/minion/minion_master.pub\n\nSystem administration rights are required to access it.\n"
            read -r -p "Continue? [y/N] " answer
            if [[ $(echo $answer | sed 's/ //g') =~ ^([nN][oO]|[nN])$ ]]; then
                echo -e "Aborting.\n"
                exit 1
            fi
        else
            echo -e "\tSalt minion '$check_minion' - version: $(salt $check_minion grains.item saltversion | sed -n '$p' | sed -e 's/\s//g')"
            OK_MINIONS[$i]=$check_minion
            let i++
        fi
        let m++
    done
}

if [[ $TEST_MINION_PING == "true" ]]; then
    echo -e "\nTesting connections to the accepted minion computers. This takes a while.\n"
    testMinions
fi

###########################################################
# Install & set up software

TIMEOUT="600" # 10 minutes

# Reason for increasing the timeout from 5 to 300:
# Installing CloudCompare & QGIS programs take very long time
# During the installation, Windows minions do not return anything
# to the master computer, thus the master computer
# thinks that the minions have timed out, although, in reality,
# they are likely installing the applications
#
# Extra long timeout especially required by Windows QGIS installation!!
#
# Proper fix for this would be needed
# but this behavior may be linked with options and output
# by Windows NSIS (Nullsoft) installers

# NOTE: Windows minions return "Failed" (retcode 2) status
# for installed programs, although they return
# alphabetical "install status: success" as well.
# This is likely a retcode bug in Saltstack.
# Salt is known to have these issues in the past.

# Failed minions (failed)
f=0

# Succeeded minions (succeeded)
s=0

# All minions (total)
t=0

for minion in ${OK_MINIONS[*]}; do

    minion_ips=$(salt $minion network.ip_addrs | sed '1d; s/^.*\-\s//' | sed ':a;N;$!ba;s/\n/, /g')

    echo -e "\n(Minion $(( $t + 1 )) / ${#OK_MINIONS[@]}) Refreshing Salt grains & pillars for minion computer '\e[95m$minion\e[0m' (IPs: $minion_ips).\n"
    salt $minion saltutil.refresh_grains
    salt $minion saltutil.refresh_pillar

    # Update Salt package databases, especially for Windows minions
    echo -e "\n(Minion $(( $t + 1 )) / ${#OK_MINIONS[@]}) Updating Salt minion package databases for minion computer '\e[95m$minion\e[0m' (IPs: $minion_ips).\n"
    salt $minion pkg.refresh_db

    if [[ $SALT_DEBUG == "true" ]]; then
        saltdbg='-l debug'
    else
        saltdbg=''
    fi

    echo -e "\n(Minion $(( $t + 1 )) / ${#OK_MINIONS[@]}) Applying Salt state updates to the minion computer '\e[95m$minion\e[0m' (IPs: $minion_ips).\n"
    salt $saltdbg -t $TIMEOUT $minion state.highstate --state-output terse

    if [[ $? -ne 0 ]]; then
        let f++
        FAILED_MINIONS[$f]=$(echo "$minion (IPs: $minion_ips)")
    else
        let s++
    fi

    let t++

done

echo -e "\nSucceeded minions: $s of $t\nFailed minions: $f of $t\n"

if [[ $f -ne 0 ]]; then
    echo -e "The following minions returned failed status:\n\n \e[91m$(echo ${FAILED_MINIONS[@]})\e[0m\n"
fi

unset OK_MINIONS
