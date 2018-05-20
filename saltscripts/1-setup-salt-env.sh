#!/bin/bash

# Salt default Master/Minion preconfiguration script for a single computer
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

# This script sets up default environment for basic Salt Master & Minion configuration
# for one computer

# Supported distributions: Ubuntu 18.04 LTS or variants

# Use alternative Saltstack official repository, not the one provided by default Ubuntu repositories?
# Usually Saltstack repository provides a newer Salt master/minion versions
#
# NOTE:Please make sure that Salt master & minion versions correspond each other!
#
USE_SALTREPO="true"

###########################################################
# Run package database updates?

function packageUpdateQ() {

    read -r -p "Refresh package databases before installation (recommended)? [y/N] " answer

    if [[ $(echo $answer | sed 's/ //g') =~ ^([yY][eE][sS]|[yY])$ ]]; then
        UPDATES=""
    fi

    unset answer

}

packageUpdateQ

###########################################################

if [[ -f /etc/os-release ]]; then

    DISTRO=$(grep ^PRETTY_NAME /etc/os-release | grep -oP '(?<=")[^\s]*')

    function installPackages() {

        case "${DISTRO}" in
            Ubuntu*)
                pkgmgr_cmd() {
                    if [[ -v UPDATES ]]; then

                        # Update Salt to the latest version - 2018.3
                        # Yes, we use 16.04 until 18.04 will officially be available

                        if [[ $USE_SALTREPO == "true" ]]; then
                            wget -O - https://repo.saltstack.com/py3/ubuntu/16.04/amd64/latest/SALTSTACK-GPG-KEY.pub | apt-key add -
                            echo "deb http://repo.saltstack.com/py3/ubuntu/16.04/amd64/latest xenial main" > /etc/apt/sources.list.d/saltstack.list
                        elif [[ $USE_ALTREPO != "true" ]] && [[ -f /etc/apt/sources.list.d/saltstack.list ]]; then
                            rm /etc/apt/sources.list.d/saltstack.list
                        fi

                        apt-get update

                    fi
                    apt-get -y install $1
                }

                PKGS=(salt-master salt-minion)
                ;;
            default)
                echo -e "Can't recognize your Linux distribution. Aborting.\n"
                exit 1
        esac

        pkgmgr_cmd "${PKGS[*]}"
        systemctl enable salt-master.service &> /dev/null
        systemctl restart salt-master.service &> /dev/null

    }

    installPackages
    unset UPDATES

else
    echo -e "Can't recognize your Linux distribution. Aborting.\n"
    exit 1
fi

###########################################################

function saltEnvironment() {

    function defaultMinionConf() {

        MINION_NAME="defaultMinion"

        if [[ -d /etc/salt ]]; then
            echo -e "\nWriting default Salt minion configuration '${MINION_NAME}' to /etc/salt/minion\n"
            echo -e "master: localhost\nid: ${MINION_NAME}" > /etc/salt/minion
            systemctl enable salt-minion.service &> /dev/null
            systemctl restart salt-minion.service &> /dev/null

            salt-key -y -a ${MINION_NAME} > /dev/null

            echo -e "Testing default Salt minion connection with the Salt master\n"

            if [[ $(echo $(salt "${MINION_NAME}" test.ping &> /dev/null)$?) -ne 0 ]]; then
                echo -e "Salt master can't connect to the default Salt minion. Aborting.\n"
                exit 1
            else
                echo -e "Connection OK!\n"
            fi

        else
            echo -e "Missing Salt configuration directory /etc/salt. Aborting.\n"
            exit 1
        fi

    }

    defaultMinionConf

}

if [ $? -eq 0 ]; then
    saltEnvironment
else
    echo -e "Unknown error. Aborting.\n"
    exit 1
fi
