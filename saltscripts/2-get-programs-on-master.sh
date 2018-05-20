#!/bin/bash

# Salt Master/Minion preconfiguration script
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

# Run on Ubuntu 18.04 LTS Salt master

# Compiles LAS tools and CloudCompare for GIS workstation (Ubuntu & Windows)
# Downloads necessary GIS tools

OSES=(windows ubuntu-1804)

# Required OS to run this script
REQUIRED_OS="Ubuntu"

# Compile CloudCompare for Ubuntu?
# TODO: support false option
CC_GET_UBUNTU=true

# Get this variable from the main script runme.sh
# The variable defined whether we should only run local Salt minion (which is running
# on Ubuntu 18.04 LTS) or not
#

if [[ $1 == "true" ]]; then
    local_only=""
fi

if [[ $2 == "true" ]]; then
    winminions_present=''
fi

########################

# INSTALL DEV PACKAGES

function devPackages() {

    if [[ -f /etc/os-release ]]; then
        DISTRO=$(grep ^PRETTY_NAME /etc/os-release | grep -oP '(?<=")[^\s]*')

        if [[ $DISTRO == ${REQUIRED_OS} ]]; then

            # for LAStools

            echo -e "Updating local package databases & installing necessary dev tools for LASTools & CloudCompare\n"
            apt-get update
            apt-get install -y make git build-essential

            if [[ $CC_GET_UBUNTU == "true" ]]; then

                # for CloudCompare

                apt-get install -y cmake libhpdf-dev debhelper fakeroot

                CC_DEVDEPENDS=(
                    libhpdf-dev
                    libqt5opengl5-dev
                    libcgal-dev
                    libdxflib-dev
                    libglew-dev
                    libfreenect-dev
                    libgdal-dev
                    liblas-c-dev
                    liblas-dev
                    libboost-all-dev
                    libjsoncpp-dev
                    libpdal-dev
                    libcurl4-gnutls-dev
                )

                function checkDevVersions() {

                    function generateDevVersions() {

                        if [[ ! -f compiled/cc_devpkg_versions ]]; then
                            touch compiled/cc_devpkg_versions
                        fi

                        for devpkg_version in ${CC_DEVDEPENDS[@]}; do
                            echo -e "$(dpkg -s $devpkg_version | grep -E '^Package:|^Version:' | awk '{print $2}' | tr '\n' ' ')" \
                            >> compiled/cc_devpkg_versions

                            if [[ $? -ne 0 ]]; then
                                exit 1
                            fi

                        done

                    }

                    # Check if we need to update our CloudCompare makedepend packages

                    if [[ -f compiled/cc_devpkg_versions ]]; then

                        local IFS=$'\n'

                        for devpackage in $(cat compiled/cc_devpkg_versions); do

                            if [[ $(apt-cache policy $(echo $devpackage | awk '{print $1}') | grep 'Candidate' | awk '{print $2}') != $(echo $devpackage | awk '{print $2}') ]]; then
                                LOCAL_DEVPKG_OLD_FLAG=""
                            fi

                        done

                        if [[ -v LOCAL_DEVPKG_OLD_FLAG ]]; then
                            apt-get install -y ${CC_DEVDEPENDS[*]}
                            rm compiled/cc_devpkg_versions
                        fi

                    else

                        touch compiled/cc_devpkg_versions
                        apt-get install -y ${CC_DEVDEPENDS[*]}

                        generateDevVersions

                    fi

                    if [[ ! -f compiled/cc_devpkg_versions ]]; then
                        generateDevVersions
                    fi

                }

                checkDevVersions

            fi

        else
            echo -e "This is not ${REQUIRED_OS} Linux distribution. Aborting.\n"
            exit 1
        fi
    else
        echo -e "Can't recognize your Linux distribution. Aborting.\n"
        exit 1
    fi

}

########################

# COMPILE LASTOOLS

# Compile open-source LAS tools

# Q: What is this?
# A: See descriptions of binaries below

# Main reason for this: Not available from software repositories but
# still an essential toolset for GIS workflow

# las2las: extracts last returns, clips, subsamples, translates, etc ...
# las2txt: turns LAS into human-readable and easy-to-parse ASCII
# lasdiff: compares the LIDAR data of two LAS/LAZ/ASCII files and reports whether they are identical or whether they are different.
# lasindex: creates a spatial index LAX file for fast spatial queries
# lasinfo: prints out a quick overview of the contents of a LAS file
# lasmerge: merges several LAS or LAZ files into a single LAS or LAZ file
# lasprecision: analyses the actual precision of the LIDAR points
# laszip: compresses the LAS files in a completely lossless manner
# txt2las: converts LIDAR data from ASCII text to binary LAS format

LASTOOLS=(
las2las
las2txt
lasdiff
lasindex
lasinfo
lasmerge
lasprecision
laszip
txt2las
)

# There are closed source LAS tools available for Windows platform

LASTOOLS_WIN=(
blast2dem
blast2iso
bytecopy
bytediff
e572las
las2dem
las2iso
las2shp
las2tin
lasboundary
lascanopy
lasclassify
lasclip
lascolor
lascontrol
lascopy
lasduplicate
lasgrid
lasground
lasground_new
lasheight
laslayers
lasnoise
lasoptimize
lasoverage
lasoverlap
lasplanes
laspublish
lasreturn
lassort
lassplit
lasthin
lastile
lastool
lastrack
lasvalidate
lasview
lasvoxel
shp2las
sonarnoiseblaster
)

function compileLAStools() {

    if [[ ! -d $1/files/lastools ]]; then
        mkdir -p $1/files/lastools
    fi

    if [[ $(ls $1/files/lastools | wc -l) -eq 0 ]]; then

        if [[ ! -d compiled/LAStools ]]; then
            git clone https://github.com/LAStools/LAStools
            cd LAStools/
            make -j$(nproc --ignore 1)

            if [[ $? -eq 0 ]]; then
                cd ..
                mv LAStools compiled/
            fi
        fi

        if [[ $? -eq 0 ]]; then

            if [[ $1 = *"ubuntu"* ]]; then

                for lastool in ${LASTOOLS[*]}; do
                    cp ./compiled/LAStools/src/$lastool \
                    $1/files/lastools/
                done

            elif [[ $1 = *"windows"* ]]; then 

                if [[ ! -v local_only ]] && [[ -v winminions_present ]]; then

                    for lastool_win1 in ${LASTOOLS[*]}; do
                        cp ./compiled/LAStools/bin/$lastool_win1.exe \
                        $1/files/lastools/
                    done

                    for lastool_win2 in ${LASTOOLS_WIN[*]}; do
                        cp ./compiled/LAStools/bin/$lastool_win2.exe \
                        $1/files/lastools/
                    done
                fi
            fi
        fi
    fi

}

########################

function getOtherGIS() {

    if [[ $CC_GET_UBUNTU == "true" ]]; then

        if [[ $1 = *"ubuntu"* ]]; then

            # Compile CloudCompare for Ubuntu
            #
            # Main reason for this: Not yet available as a binary download for Ubuntu 18.04 LTS
            # BREAKS EASILY!
            # Issues: compatibility with other Linux distros may not be stable.
            # Currently available only for Ubuntu

            if [[ ! -f compiled/cloudcompare_${CC_VERSION_UBUNTU}-1_amd64.deb ]] || [[ -v LOCAL_DEVPKG_OLD_FLAG ]] ; then

                # Get CloudCompare source files & Debian control files
                wget http://http.debian.net/debian/pool/main/c/cloudcompare/cloudcompare_${CC_VERSION_UBUNTU}.orig.tar.gz
                wget http://http.debian.net/debian/pool/main/c/cloudcompare/cloudcompare_${CC_VERSION_UBUNTU}-1.debian.tar.xz

                # Extract CloudCompare source files
                tar xf cloudcompare_${CC_VERSION_UBUNTU}.orig.tar.gz

                # Make CloudCompare source root directory compatible with dpkg-buildpackage command
                mv CloudCompare-master cloudcompare-${CC_SHORT_UBUNTU}

                # Extract Debian control files
                tar xf cloudcompare_${CC_VERSION_UBUNTU}-1.debian.tar.xz --directory cloudcompare-${CC_SHORT_UBUNTU}/

                # Compile CloudCompare
                cd cloudcompare-${CC_SHORT_UBUNTU}
                dpkg-buildpackage -rfakeroot -b -us -uc -j$(nproc --ignore 1)

                if [[ $? -eq 0 ]]; then
                    cd ..
                    mv ./{*.tar.*,*.buildinfo,*.changes,*.deb} compiled/
                    rm -Rf cloudcompare-${CC_SHORT_UBUNTU}
                fi
            fi

            if [[ ! -f $1/files/cloudcompare_${CC_VERSION_UBUNTU}-1_amd64.deb ]]; then
                cp compiled/cloudcompare_${CC_VERSION_UBUNTU}-1_amd64.deb $1/files/
            fi

        fi
    fi

    if [[ $1 == *"windows"* ]]; then

        if [[ ! -v local_only ]] && [[ -v winminions_present ]]; then

            if [[ ! -d compiled/windows ]]; then
                mkdir -p compiled/windows
            fi

            # Download Visual C++ Redistributable Packages for Visual Studio 2013 for Windows
            # Required by CloudCompare

            if [[ ! -f compiled/windows/vcrun2013_64.exe ]]; then
                wget https://download.microsoft.com/download/2/E/6/2E61CFA4-993B-4DD4-91DA-3737CD5CD6E3/vcredist_x64.exe -O \
                compiled/windows/vcrun2013_64.exe
            fi

            # Download CloudCompare for Windows

            if [[ ! -f compiled/windows/CloudCompare_${CC_VERSION_WIN}_setup_x64.exe ]]; then
               wget http://cloudcompare.org/release/CloudCompare_${CC_VERSION_WIN}_setup_x64.exe -O \
                compiled/windows/CloudCompare_${CC_VERSION_WIN}_setup_x64.exe
            fi

            # Download QGIS for Windows

            if [[ ! -f compiled/windows/QGIS-OSGeo4W-${QGIS_VERSION_WIN}-Setup-x86_64.exe ]]; then
                wget http://qgis.org/downloads/QGIS-OSGeo4W-${QGIS_VERSION_WIN}-Setup-x86_64.exe -O \
                compiled/windows/QGIS-OSGeo4W-${QGIS_VERSION_WIN}-Setup-x86_64.exe
            fi

            # Download gpx2shp. NOTE: Outdated version, but only out-of-the-box binary for Windows available

            GPX2SHP_WIN_1="gpx2shp-0.69_win_notest"
            GPX2SHP_WIN_2="gpx2shp-0.69_wintest"

            if [[ ! -f compiled/windows/gpx2shp.exe ]]; then
                wget https://dotsrc.dl.osdn.net/osdn/gpx2shp/13458/${GPX2SHP_WIN_1}.zip -O \
                compiled/windows/${GPX2SHP_WIN_1}.zip
                unzip -j compiled/windows/${GPX2SHP_WIN_1}.zip ${GPX2SHP_WIN_2}/gpx2shp.exe -d compiled/windows/ &> /dev/null
                rm compiled/windows/${GPX2SHP_WIN_1}.zip
            fi

            # Download Merkaartor

            if [[ ! -f compiled/windows/merkaartor-${MERK_VERSION_WIN}-64bit.exe ]]; then
                wget http://merkaartor.be/files/merkaartor-${MERK_VERSION_WIN}-64bit.exe -O \
                compiled/windows/merkaartor-${MERK_VERSION_WIN}-64bit.exe
            fi

            # Download Quickroute GPS

            # NOTE: Get MSI GUID for 32-bit uninstaller (for sls) by running the following in Windows Powershell:
            # get-wmiobject Win32_Product | Format-Table IdentifyingNumber, Name

            if [[ ! -f compiled/windows/QuickRoute_${QR_VERSION_WIN}_Setup.msi ]]; then
                wget http://www.matstroeng.se/quickroute/download/QuickRoute_${QR_VERSION_WIN}_Setup.msi -O \
                compiled/windows/QuickRoute_${QR_VERSION_WIN}_Setup.msi
            fi

            # Download GPS Daemon

            # NOTE: Deprecated version. Newer version is available for Unix platforms

            if [[ ! -f compiled/windows/GPSd-4-win_${GPSD_VERSION_WIN}.exe ]]; then
                wget https://storage.googleapis.com/google-code-archive-downloads/v2/code.google.com/gpsd-4-win/GPSd-4-win_${GPSD_VERSION_WIN}.exe -O \
                compiled/windows/GPSd-4-win_${GPSD_VERSION_WIN}.exe
            fi

            ## GPSBabel
            #
            #wget https://www.gpsbabel.org/plan9.php
            #
            #GPSBabel-1.5.4-Setup.exe

            for win_installer in compiled/windows/*; do
                cp $win_installer /srv/salt/win/repo-ng/installers/
            done

            cp compiled/windows/gpx2shp.exe /srv/salt/gis_windows/files/
            rm /srv/salt/win/repo-ng/installers/gpx2shp.exe
        fi
    fi
}

########################

devPackages

# Create directory for compiled programs
if [[ ! -d compiled ]]; then 
    mkdir compiled
fi

for OS in ${OSES[*]}; do

    if [[ $OS = *"ubuntu"* ]]; then

        CC_VERSION_UBUNTU="2.9.1+git20180223"
        CC_SHORT_UBUNTU="2.9.1"

    elif [[ $OS == *"windows"* ]] && [[ ! -v $skip_windows ]]; then

        CC_VERSION_WIN="v2.10.alpha"
        CC_SHORT_WIN="2.10"
        MERK_VERSION_WIN="0.18.3"
        QGIS_VERSION_WIN="2.18.19-1"
        QR_VERSION_WIN="2.4"
        GPSD_VERSION_WIN="0.2.0.0"

    fi

    OS_SALT_PATH="/srv/salt/gis_${OS}"

    compileLAStools ${OS_SALT_PATH}

    getOtherGIS ${OS_SALT_PATH}

done

unset LOCAL_DEVPKG_OLD_FLAG
unset local_only
unset winminions_present
