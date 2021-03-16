#!/bin/bash

#
# Helper script to patch kernel source and prepare kernel rpms
# Aeon Computing
#


# General
HOME_PATH=$HOME
LOC=${LOC:-$HOME}
MIDPATH=staging01
PATCH_FILE=patch-3.10.0-lustre.patch
CONFIG_FILE=kernel-3.10.0-x86_64.config
SPEC_FILE=kernel.spec

# Centos 7.9 Specific
#SOURCE_PKG_LOC=https://vault.centos.org/7.9.2009/updates/Source/SPackages/kernel-3.10.0-1160.15.2.el7.src.rpm

# Centos 7.8 Specific
SOURCE_PKG_LOC=https://vault.centos.org/7.8.2003/updates/Source/SPackages/kernel-3.10.0-1127.13.1.el7.src.rpm

# Add local folder for rpmbuild
RPMBASE_NAME=${RPMBASE:-rpmmacros}
RPMBASE_PATH=${RPMBASE_PATH:-$MIDPATH/rpmbuild}
RPMBASE_FULL_PATH=${RPMBASE_FULL_PATH:-$LOC/$MIDPATH/rpmbuild}

logs()
{
	echo "$1:$2"
	exit 1
}

# All sanity checks before going full throttle...
# Package dependencies are handled by make itself..no need for it here.
prepare()
{
	# rpmbuild is present
	which rpmbuild 2>/dev/null || logs "error" "rpmbuild binary not found."
	# lustre patch is present.
	ls $LOC/$PATCH_FILE  >/dev/null 2>&1 || logs "error" "Please make sure patch file $PATCH_FILE is in the \$LOC folder"
	# kernel.spec is present.
	ls $LOC/$SPEC_FILE  >/dev/null 2>&1 || logs "error" "Please make sure kernel.spec file $SPEC_FILE is in the \$LOC folder"
	# kernel config is present
	ls $LOC/$CONFIG_FILE  >/dev/null 2>&1 || logs "error" "Please make sure kernel config file $CONFIG_FILE is in the \$LOC folder"

	echo "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~"
	echo "Starting Kernel RPM build:"
	echo "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~"
	echo "patch: $LOC/$PATCH_FILE"
	echo "config: $LOC/$CONFIG_FILE"
	echo "specs: $LOC/$SPEC_FILE"
	echo "kernel source: $SOURCE_PKG_LOC"
	echo "Final RPM's will be created under $RPMBASE_FULL_PATH/RPMS"
	echo "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~"
	echo "Press <enter> to continue or ^C to abort"
	read input
}


prepare_kernel_source_folder_path() 
{
	# prepare base folders required by rpmbuild
	echo '%_topdir %(echo $LOC)/staging01/rpmbuild' > ~/.$RPMBASE_NAME
}

prepare_kernel_source_folder() 
{
	cd $LOC
	mkdir -p $RPMBASE_PATH/{BUILD,RPMS,SOURCES,SPECS,SRPMS}
}

install_kernel_source()
{
	#
	# This will fill in 
	# 01. $RPMBASE_PATH/SOURCES
	# 02. $RPMBASE_PATH/SPECS
	#
	rpm -ivh "$SOURCE_PKG_LOC"
}

prepare_kernel_source()
{
	# This will further create two folders 
	# 01. $RPMBASE_PATH/BUILD/kernel-3.10.0-1160.15.2.el7/linux-3.10.0-1160.15.2.el7.x86_64/
	# 02. $RPMBASE_PATH/BUILDROOT (This will be empty for now)
	# 03. ./SPECS/kernel.spec - This is further edited by hand to handle lustre specific 
	# patches which are to be applied
	cd $RPMBASE_PATH
	rpmbuild -bp --target=`uname -m` ./SPECS/kernel.spec
}

prepare_patch()
{
	# copy specific lustre patch to be applied to this kernel version
	# This patch file has latest patchs that needs to be patch to the kernel source.
	# TODO: This has to be self generated.

	# cd ~/lustre-release/lustre/kernel_patches/series
	# for patch in $(<"3.10-rhel7.series"); do
	# patch_file="$HOME/lustre-release/lustre/kernel_patches/patches/${patch}";
	# cat "${patch_file}" >> "$HOME/lustre-kernel-x86_64-lustre.patch";
	# done

	# for patch in $(<"3.10-rhel7.8.series"); do patch_file="/root/rpmbuild/lustre-release/lustre/kernel_patches/patches/${patch}"; cat "${patch_file}" >> "/root/rpmbuild/lustre-kernel-x86_64-lustre.patch"; done
	cp -a $LOC/$PATCH_FILE $RPMBASE_FULL_PATH/SOURCES/$PATCH_FILE
}

prepare_specs()
{
	# overwrite specs with lustre specific specs file
	specs=$RPMBASE_FULL_PATH/SPECS/kernel.spec
	cp -a $LOC/$SPEC_FILE $specs
}


prepare_kernel_config()
{
	# copy lustre specific kernel config file.
	# Note: The config for specific dist/release could be found under:
	# lustre/kernel_patches/kernel_configs/kernel-3.10.0-3.10-rhel7.8-x86_64.config
	#
	# How to get config (eg for branch b12)...
	# $ git clone git://git.whamcloud.com/fs/lustre-release.git
	# $ cd lustre_release
	# $ git checkout -b b12 remotes/origin/b2_12
	# $ sh autogen.sh
	# cp -a lustre/kernel_patches/kernel_configs/kernel-3.10.0-3.10-rhel7.8-x86_64.config kernel-3.10.0-x86_64.config
	cp -a $LOC/$CONFIG_FILE $RPMBASE_FULL_PATH/SOURCES/$CONFIG_FILE
}

build_new_kernel_rpm()
{
	# build new kernel rpm - this will have centos kernel with lustre specific patchs under RPMS
	build_id="_lustre"
	specs=$RPMBASE_FULL_PATH/SPECS/kernel.spec
	echo "rpmbuild -vv -ba --without kabichk --with firmware --target x86_64 --with baseonly --define "buildid ${build_id}"  $specs"
	rpmbuild -vv -ba --without kabichk --with firmware --target x86_64 --with baseonly --define "buildid ${build_id}"  $specs
}

#
# Main
#
prepare
prepare_kernel_source_folder
prepare_kernel_source_folder_path
install_kernel_source
prepare_kernel_source
prepare_patch
prepare_specs
prepare_kernel_config
build_new_kernel_rpm

