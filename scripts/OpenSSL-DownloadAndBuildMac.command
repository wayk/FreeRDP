#!/bin/bash
# 
# Copyright 2013 Thincast Technologies GmbH
# 
# This Source Code Form is subject to the terms of the Mozilla Public License, v. 2.0. 
# If a copy of the MPL was not distributed with this file, You can obtain one at http://mozilla.org/MPL/2.0/.
#
# This script will download and build openssl for iOS (armv7, armv7s) and simulator (i386)

# Settings and definitions
USER_OS_SDK=""
USER_SIM_SDK=""

OPENSSLVERSION="1.0.2f"
MD5SUM="b3bf73f507172be9292ea2a8c28b659d"
INSTALLDIR="external"

MAKEOPTS="-j $CORES"
# disable parallell builds since openssl build
# fails sometimes
MAKEOPTS=""
CORES=`sysctl hw.ncpu | awk '{print $2}'`
SCRIPTDIR=$(dirname `cd ${0%/*} && echo $PWD/${0##*/}`)
OS_SDK=""
OS_SDK_PATH="/Applications/Xcode.app/Contents/Developer/Platforms/MacOSX.platform/Developer/SDKs"

# Functions
function buildArch(){
	ARCH=$1
	LOGFILE="BuildLog.darwin-${ARCH}.txt"
	echo "Building architecture ${ARCH}. Please wait ..."
	./Configure darwin-${ARCH}-cc > ${LOGFILE}
	make ${MAKEOPTS} >> ${LOGFILE} 2>&1
	echo "Done. Build log saved in ${LOGFILE}"
	cp libcrypto.a ../../lib/libcrypto.a
	cp libssl.a ../../lib/libssl.a
	make clean >/dev/null 2>&1
	echo
}

# main
if [ $# -gt 0 ];then
	INSTALLDIR=$1
	if [ ! -d $INSTALLDIR ];then
		echo "Install directory \"$INSTALLDIR\" does not exist"
		exit 1
	fi
fi

echo "Detecting SDKs..."
if [ "x${USER_OS_SDK}" == "x" ];then
	OS_SDK=`ls -1 ${OS_SDK_PATH} | sort -n | head -1`
	if [ "x${OS_SDK}" == "x" ];then
		echo "No MacOS SDK found"
		exit 1;
	fi
else
	OS_SDK=${USER_OS_SDK}
	if [ ! -d "${OS_SDK_PATH}/${OS_SDK}" ];then
		echo "User specified MacOS SDK not found"
		exit 1
	fi
fi
echo "Using MacOS SDK: ${OS_SDK}"
echo

cd $INSTALLDIR
if [ ! -d openssl ];then
	mkdir openssl
fi
cd openssl
CS=`md5 -q "openssl-$OPENSSLVERSION.tar.gz" 2>/dev/null`
if [ ! "$CS" = "$MD5SUM" ]; then
    echo "Downloading OpenSSL Version $OPENSSLVERSION ..."
    rm -f "openssl-$OPENSSLVERSION.tar.gz"
    curl -o "openssl-$OPENSSLVERSION.tar.gz" http://www.openssl.org/source/openssl-$OPENSSLVERSION.tar.gz

    CS=`md5 -q "openssl-$OPENSSLVERSION.tar.gz" 2>/dev/null`
    if [ ! "$CS" = "$MD5SUM" ]; then
	echo "Download failed or invalid checksum. Have a nice day."
	exit 1
    fi
fi

# remove old build dir
rm -rf openssltmp
mkdir openssltmp
cd openssltmp/

echo "Unpacking OpenSSL ..."
tar xfz "../openssl-$OPENSSLVERSION.tar.gz"
if [ ! $? = 0 ]; then
    echo "Unpacking failed."
    exit 1
fi
echo

cd openssl-$OPENSSLVERSION

# Cleanup old build artifacts
mkdir -p ../../include/openssl
rm -f ../../include/openssl/*.h

mkdir -p ../../lib
rm -f ../../lib/*.a

buildArch i386

echo "Copying header hiles ..."
cp -RL include/openssl/ ../../include/openssl/
echo

echo "Finished. Please verify the contens of the openssl folder in \"$INSTALLDIR\""
