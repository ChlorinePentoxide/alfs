#!/bin/bash

set -e

LFS_WGETLIST_LINK="https://www.linuxfromscratch.org/lfs/downloads/stable/wget-list"

setvars()
{
    echo "Setting variables ..."
    export LFS=/mnt/lfs
    export LFS_AUTOSCRIPTS=$LFS/automation
    export LFS_LOCKS=$LFS_AUTOSCRIPTS/locks
    export LFS_DEBUG=$LFS_AUTOSCRIPTS/LFS_DEBUG
}

check_root()
{
    if [ "$EUID" -ne 0 ]
    then 
        echo "Please execute this script as root. Now exiting."
        exit
    fi
}

check_host()
{

# Write the version check script

    cat > version-check.sh << "EOF"
    #!/bin/bash
    # Simple script to list version numbers of critical development tools
    export LC_ALL=C
    bash --version | head -n1 | cut -d" " -f2-4
    MYSH=$(readlink -f /bin/sh)
    echo "/bin/sh -> $MYSH"
    echo $MYSH | grep -q bash || echo "ERROR: /bin/sh does not point to bash"
    unset MYSH

    echo -n "Binutils: "; ld --version | head -n1 | cut -d" " -f3-
    bison --version | head -n1

    if [ -h /usr/bin/yacc ]; then
    echo "/usr/bin/yacc -> `readlink -f /usr/bin/yacc`";
    elif [ -x /usr/bin/yacc ]; then
    echo yacc is `/usr/bin/yacc --version | head -n1`
    else
    echo "yacc not found"
    fi

    echo -n "Coreutils: "; chown --version | head -n1 | cut -d")" -f2
    diff --version | head -n1
    find --version | head -n1
    gawk --version | head -n1

    if [ -h /usr/bin/awk ]; then
    echo "/usr/bin/awk -> `readlink -f /usr/bin/awk`";
    elif [ -x /usr/bin/awk ]; then
    echo awk is `/usr/bin/awk --version | head -n1`
    else
    echo "awk not found"
    fi

    gcc --version | head -n1
    g++ --version | head -n1
    grep --version | head -n1
    gzip --version | head -n1
    cat /proc/version
    m4 --version | head -n1
    make --version | head -n1
    patch --version | head -n1
    echo Perl `perl -V:version`
    python3 --version
    sed --version | head -n1
    tar --version | head -n1
    makeinfo --version | head -n1  # texinfo version
    xz --version | head -n1

    echo 'int main(){}' > dummy.c && g++ -o dummy dummy.c
    if [ -x dummy ]
    then echo "g++ compilation OK";
    else echo "g++ compilation failed"; fi
    rm -f dummy.c dummy
EOF

    bash version-check.sh 2>&1 | tee $LFS_DEBUG/host_system_libs.log

    while true; do
        read -p "Please confirm that the above output is compliant (y/n) ? " yn
        case $yn in
            [Yy]* ) build_all; break;;
            [Nn]* ) exit;;
            * ) echo "Please answer yes or no.";;
        esac
    done

    echo "Host System Requirements Check Passed."

    rm version-check.sh
    touch $LFS_LOCKS/checkpoint1.lock
}

fetch_sources()
{
    mkdir -v $LFS/sources
    chmod -v a+wt $LFS/sources

    wget $LFS_WGETLIST_LINK
    wget --input-file=wget-list --continue --directory-prefix=$LFS/sources

    touch $LFS_LOCKS/checkpoint2.lock
}

prepare_lfs_fs()
{
    touch $LFS_DEBUG/prepare_lfs_fs.log

    mkdir -pv $LFS/{etc,var} $LFS/usr/{bin,lib,sbin} 2>&1 >> $LFS_DEBUG.prepare_lfs_fs.log

    for i in bin lib sbin; do
        ln -sv usr/$i $LFS/$i 2>&1 >> $LFS_DEBUG.prepare_lfs_fs.log
    done

    case $(uname -m) in
        x86_64) mkdir -pv $LFS/lib64 2>&1 >> $LFS_DEBUG.prepare_lfs_fs.log ;;
    esac

    mkdir -pv $LFS/tools

    groupadd lfs 2>&1 >> $LFS_DEBUG.prepare_lfs_fs.log
    useradd -s /bin/bash -g lfs -m -k /dev/null lfs 2>&1 >> $LFS_DEBUG.prepare_lfs_fs.log

    passwd lfs

    chown -v lfs $LFS/{usr{,/*},lib,var,etc,bin,sbin,tools} 2>&1 >> $LFS_DEBUG.prepare_lfs_fs.log
    case $(uname -m) in
        x86_64) chown -v lfs $LFS/lib64 2>&1 >> $LFS_DEBUG.prepare_lfs_fs.log ;;
    esac

    [ ! -e /etc/bash.bashrc ] || mv -v /etc/bash.bashrc /etc/bash.bashrc.NOUSE 2>&1 >> $LFS_DEBUG.prepare_lfs_fs.log

    touch $LFS_LOCKS/checkpoint3.lock
}

build_all() 
{
    setvars

    if [ -e $LFS_LOCKS/checkpoint1.lock ]
    then
        echo "Skipping host system check ... "
    else
        check_root
        check_host
    fi

    if [ -e $LFS_LOCKS/checkpoint2.lock ]
    then
        echo "Skipping fetching sources ... "
    else
        check_root
        fetch_sources 2>&1 > $LFS_DEBUG/fetching_sources.log
    fi

    if [ -e $LFS_LOCKS/checkpoint3.lock ]
    then
        echo "Skipping LFS filesystem preparation ... "
    else
        check_root
        prepare_lfs_fs 2>&1 > $LFS_DEBUG/prepare_lfs_fs.log
    fi

}

skip()
{
}


# Entry Point

echo "Automated LFS Build System"
echo "LFS Version 11.2, Script Version 1.2"
echo "Copyright(C) ChlorineLabs, 2022, Internal Use Only"
echo

echo "Please ensure this script is running in the target partition(/mnt/lfs)."
echo

while true; do
    read -p "Are you sure you want to procede (y/n) ? " yn
    case $yn in
        [Yy]* ) build_all; break;;
        [Nn]* ) exit;;
        * ) echo "Please answer yes or no.";;
    esac
done