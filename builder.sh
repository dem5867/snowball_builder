#!/bin/sh

# AUTHORS : ARTHUR LAMBERT
# DATE : 06/07/2012
# DESCRIPTION : BUILD KERNEL AND ROOTS FOR SNOWBALL

HERE=`pwd`
BIN_ARM=$HERE/arm-none-linux-gnueabi/bin/arm-none-linux-gnueabi-
CROSS_PARAMS="ARCH=arm CROSS_COMPILE=$BIN_ARM"
JOBS=4

# reset error log

echo >/tmp/log_error_snowball

###############################################################################
# print error message and return error code 1 when $? is different than 0
check_error()
{
    if [ $2 -ne 0 ]; then
	echo; echo;
	echo "############################################################"
	cat /tmp/log_error_snowball
	echo "############################################################"
	echo
	echo "Error (code : $2) : $1"
	exit $2;
    fi
}
###############################################################################




###############################################################################
# print usage for this script
print_usage()
{
    echo
    echo "Usage: ${0##*/} [OPTION]... <project_name> <config file>"
    echo "shell script to build snowball system with rootfs and kernel from sources"
    echo
    cat <<EOF
      -h,--help                      display this help and exit
      -c,--config <file>             specify which config file to use (MANDATORY)
      -p,--project <project name>    provide a project name (DEFAULT value is : Snowball)
EOF
    echo
}
###############################################################################


# Handle arguments through getopt command

options=$(getopt -o hc:p: -l help,config:,project: -- "$@")
if [ $? -ne  0 ] || [ $# -ne 4 ]; then
    print_usage
    exit 1
fi


eval set -- "$options"

while true; do
    case "$1" in
        -h|--help)              print_usage && exit 0;;
        -c|--config)            CONFIG=$2; shift 2;;
        -p|--project)           PROJECT=$2; shift 2;;
	*)                      break;;
    esac
done


# check dependancy

echo -n "Checking for multistrap package..."
dpkg -l | grep -w multistrap > /dev/null 2>>/tmp/log_error_snowball
check_error " You must install multistrap package." $?
echo "Yes."

echo -n "Checking for uboot-mkimage package..."
dpkg -l | grep -w uboot-mkimage >/dev/null 2>>/tmp/log_error_snowball
check_error " You must install uboot-mkimage package." $?
echo "Yes."

echo -n "Checking for git package..."
dpkg -l | grep -w git >/dev/null 2>>/tmp/log_error_snowball
check_error " You must install git package." $?
echo "Yes."


# check arguments

echo -n "Checking arguments..."
if [ ! -z "$CONFIG" ]; then
    if [ ! -f $CONFIG ]; then
        check_error "Configure file: $CONFIG not found." 42
    fi;
else
    check_error "You must provide a valid configure file." $? 42
fi;

if [ -z "$PROJECT" ]; then
    PROJECT=snowball
fi;
echo "Done."


# if system directory is not yet create, do it

if [ ! -d $HERE/system ]; then
    mkdir $HERE/system 2>>/tmp/log_error_snowball
fi;

# if output directory is not yet create, do it

if [ ! -d $HERE/output ]; then
    mkdir $HERE/output 2>>/tmp/log_error_snowball
fi;

# clean old project and create new one

echo -n "Cleaning exiting project with the same name..."
rm -rf $HERE/system/$PROJECT
rm -rf $HERE/output/$PROJECT
mkdir $HERE/system/$PROJECT 2>>/tmp/log_error_snowball
mkdir $HERE/output/$PROJECT 2>>/tmp/log_error_snowball
echo "Done."

# check that kernel and cross compiler is up

echo -n "Check kernel dir..."
if [ ! -d $HERE/kernel ]; then
    git clone https://github.com/Evanok/igloo_kernel_android_linux3.3.git $HERE/kernel 2>>/tmp/log_error_snowball 1>/dev/null
    check_error "Unable to git clone igloo kernel from github" $?
fi
echo "Done."

echo -n "Check cross arm dir..."
if [ ! -d $HERE/arm-none-linux-gnueabi ]; then
    git clone https://github.com/Evanok/arm-none-linux-gnueabi.git arm-none-linux-gnueabi >/dev/null 2>>/tmp/log_error_snowball
    check_error "Unable to git clone cross arm from github" $?
fi
echo " Done."

echo -n "Check bluez patch dir..."
if [ ! -d $HERE/bluez_patch ]; then
    git clone /home/arthur/git/bluez_debian_snowball.git bluez_patch >/dev/null 2>>/tmp/log_error_snowball
    check_error "Unable to git clone bluez patch from github" $?
fi
echo " Done."

# build uImage from kernel source


# clean kernel source

echo -n "Cleaning kernel source...."
cd $HERE/kernel && make $CROSS_PARAMS clean 1>/dev/null 2>>/tmp/log_error_snowball
check_error "Unable run make clean in kernel source" $?
cd $HERE/kernel && make $CROSS_PARAMS distclean 1>/dev/null 2>>/tmp/log_error_snowball
check_error "Unable run make distclean in kernel source" $?
echo "Done."

# get configure file and build uImage

echo -n "Get configure file...."
cp $HERE/$CONFIG $HERE/kernel/.config 2>>/tmp/log_error_snowball
check_error "Unable to get your configure file : $CONFIG" $?
echo "Done."

echo -n "Bulding uImage..."
cd $HERE/kernel && make $CROSS_PARAMS -j $JOBS uImage 1>/dev/null 2>>/tmp/log_error_snowball
check_error "Unable to run make uImage" $?
echo "Done."

echo -n "Installing modules...."
cd $HERE/kernel && make $CROSS_PARAMS INSTALL_MOD_PATH=$HERE/system/$PROJECT/rootfs_config/modules/ -j$JOBS modules 1>/dev/null 2>>/tmp/log_error_snowball
check_error "Unable to run make modules" $?
cd $HERE/kernel && make $CROSS_PARAMS INSTALL_MOD_PATH=$HERE/system/$PROJECT/rootfs_config/modules/ -j$JOBS modules_install 1>/dev/null 2>>/tmp/log_error_snowball
check_error "Unable to run make modules_install" $?
echo "Done."

# creating rootfs and system for snowball


mkdir $HERE/system/$PROJECT/configs
mkdir -p $HERE/system/$PROJECT/rootfs_config/scripts
mkdir -p $HERE/system/$PROJECT/rootfs_config/config
mkdir -p $HERE/system/$PROJECT/rootfs_config/boot
cd $HERE

echo -n "Running config_creator....";
$HERE/config_creator $PROJECT 1>/dev/null 2>>/tmp/log_error_snowball
check_error "Unable to run config_creator" $?
echo "Done."

echo "Multistrap...."
sudo multistrap -f $HERE/system/$PROJECT/rootfs_config/config/snowball_multistrap_configuration 2>>/tmp/log_error_snowball
check_error "Unable to run multistrap" $?
rm -rf modules/lib

cp $HERE/kernel//arch/arm/boot/uImage $HERE/output/$PROJECT/uImage
rm -rf $HERE/system/$PROJECT
sudo rm -rf $HERE/rootfs

echo
echo
echo "uImage and rootfs for project : DONE"
echo "Result is under $HERE/output/$PROJECT"
exit 0
