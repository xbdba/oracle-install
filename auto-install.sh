#!/bin/bash
#=================================================================#
#   System Required: Linux 6,7,8                                  #
#   Description: One Click Install Oracle DB 11g|18c|19c          #
#   Author: Xiong Bin                                             #
#   If Any Question Contact Email: xbdba@qq.com                   #
#                                                                 #
#   Main change                                                   #
# 1.0  Initial Version                                            #
# 1.1  Use DBCA                                                   #
# 1.2  Support 18c,Linux 7                                        #
# 1.3  Add DG Install                                             #
# 1.4  Support 19c,Linux 8                                        #
# 2.0  Support Redhat,Centos                                      #
# 3.0  Add HugePage Configuration                                 #
#=================================================================#

script_version=v3.0

install_option()
{
#which type do you want to install?
    if [ -z ${install_select} ]; then
        install_select="1"
        echo -e "${warning}请确保在一个干净的环境中执行本脚本，否则可能对正在运行的服务产生影响！！！"
        echo ""
        Echo_Yellow "【提示】你有以下安装选项:"
        echo "1: 安装完整数据库，包含实例"
        echo "2: 只安装数据库软件，不安装实例"
        echo "3: 安装Dataguard"
        echo "4: 配置HugePage"
        echo "5: 安装Oracle For Linux客户端"
        read -p "Enter your choice (1, 2, 3, 4, 5): " install_select
    fi

    case "${install_select}" in
    1)
        install_db
        ;;
    2)
        install_softonly
        ;;
    3)
        dg_install
        ;;
    4)
        check_hugepage
        ;;
    5)
        install_client
        ;;
    *)
        Echo_Red "输入错误，退出安装！"
        exit 1
    esac
}

#define shell color
info='\033[0;32m【信息】\033[0m'
error='\033[0;31m【错误】\033[0m'
warning='\033[0;33m【警告】\033[0m'

Color_Text()
{
  echo -e " \e[0;$2m$1\e[0m"
}

Echo_Red()
{
  echo $(Color_Text "$1" "31")
}

Echo_Green()
{
  echo $(Color_Text "$1" "32")
}

Echo_Yellow()
{
  echo $(Color_Text "$1" "33")
}

Echo_Blue()
{
  echo $(Color_Text "$1" "34")
}

## Test and Prod environment yum server,include install software
testip="127.0.0.1"
prodip="127.0.0.1"

softdir="/home/soft"
mkdir -p ${softdir}

BASH_PROFILE="/home/oracle/.bash_profile"

install_db()
{
    pre-install
    install_db_soft
    patch
    glogin
    install_dbca
    set_param
    auto_start
    rlwrap
    delete_soft
    instance_info
    check_hugepage
}

install_softonly()
{
    pre-install
    install_db_soft
    patch
    glogin
    auto_start
    rlwrap
    delete_soft
    check_hugepage
}

install_client()
{
    config_yum
    gcc_version
    download_soft
    set_client
}

dg_install()
{
    dg_pre
    config_ssh_key
    install_dg
}

# Make sure only root can run script
[[ $EUID -ne 0 ]] && echo -e "${error}: This script must be run as root! " && exit 1

Get_Dist_Name()
{
    if grep -Eqi "CentOS" /etc/issue || grep -Eq "CentOS" /etc/*-release; then
        DISTRO='CentOS'
        if grep -Eq "CentOS Stream" /etc/*-release; then
            isCentosStream='y'
        fi
    elif grep -Eqi "Oracle Linux" /etc/issue || grep -Eq "Oracle Linux" /etc/*-release; then
        DISTRO='Oracle'
    elif grep -Eqi "Red Hat Enterprise Linux" /etc/issue || grep -Eq "Red Hat Enterprise Linux" /etc/*-release; then
        DISTRO='RHEL'
    else
        DISTRO='unknow'
    fi
}

Get_Version()
{
    Get_Dist_Name
    if [ "${DISTRO}" = "RHEL" ]; then
        yumdir='redhat'
        if grep -Eqi "release 5." /etc/redhat-release; then
            main_ver='5'
        elif grep -Eqi "release 6." /etc/redhat-release; then
            main_ver='6'
        elif grep -Eqi "release 7." /etc/redhat-release; then
            main_ver='7'
        elif grep -Eqi "release 8." /etc/redhat-release; then
            main_ver='8'
        fi
        version="$(cat /etc/redhat-release | sed 's/.*release\ //' | sed 's/\ .*//')"
        echo -e "${info}当前操作系统版本: RHEL Linux Version ${version}"
        echo -e ""
    elif [ "${DISTRO}" = "Oracle" ]; then
        yumdir='oel'
        if grep -Eqi "release 5." /etc/oracle-release; then
            main_ver='5'
        elif grep -Eqi "release 6." /etc/oracle-release; then
            main_ver='6'
        elif grep -Eqi "release 7." /etc/oracle-release; then
            main_ver='7'
        elif grep -Eqi "release 8." /etc/oracle-release; then
            main_ver='8'
        fi
        version="$(cat /etc/oracle-release | sed 's/.*release\ //' | sed 's/\ .*//')"
        echo -e "${info}当前操作系统版本: Oracle Linux Version ${version}"
        echo -e ""
    elif [ "${DISTRO}" = "CentOS" ]; then
        yumdir='centos'
        version="$(cat /etc/redhat-release | sed 's/.*release\ //' | sed 's/\ .*//'|awk -F '.' '{print $1}')"
        main_ver=${version}
        echo -e "${info}当前操作系统版本: CentOS Linux Version ${version}"
        echo -e ""
    fi
}

# check environment is Test or Prod
check_env()
{
        local line=""
            line=`ping $1 -c 1 -s 1 -W 1 | grep "100% packet loss" | wc -l`
        if [ $line != 0 ]; then
            return 1
        else
            return 0
        fi
}

check_url()
{
    local line=""
        line=`curl -s -o /dev/null --connect-timeout 1 -w "%{http_code}" $1`
    if [ $line -ne '200' ]; then
        return 1
    else
        return 0
    fi
}

# Disable selinux
disable_selinux(){
    if [ -s /etc/selinux/config ] && grep 'SELINUX=enforcing' /etc/selinux/config; then
        sed -i 's/SELINUX=enforcing/SELINUX=disabled/g' /etc/selinux/config
        setenforce 0
    fi
}

check_ip()
{
    if check_url ${prodip} 0;then
        url=http://$prodip
    elif check_url ${testip} 0;then
        url=http://$testip
    else
        echo -e "${error}请检查网络${url}是否正常！"
        exit 1
    fi 
}

# set yum repo
config_yum()
{   
    Get_Version
    cd /etc/yum.repos.d/
    check_ip
    rm -f *.repo
if [[ ${main_ver} -gt 7 ]];then    
    cat <<EOF > /etc/yum.repos.d/tfzq.repo 
[base]
name=base
baseurl=${url}/${yumdir}/${version}/BaseOS
enable=1
gpgcheck=0

[app]
name=app
baseurl=${url}/${yumdir}/${version}/AppStream
enable=1
gpgcheck=0

[epel]
name=epel
baseurl=${url}/epel/${main_ver}/
enable=1
gpgcheck=0
EOF
else
    cat <<EOF > /etc/yum.repos.d/tfzq.repo 
[base]
name=base
baseurl=${url}/${yumdir}/${version}/
enable=1
gpgcheck=0

[epel]
name=epel
baseurl=${url}/epel/${main_ver}/
enable=1
gpgcheck=0
EOF
fi

    oel_code=`cat /etc/yum.repos.d/tfzq.repo|grep baseurl|grep -E 'oel|centos|redhat' |awk -F '=' '{print $2}'|xargs curl -s -o /dev/null -w "%{http_code}"`
    epel_code=`cat /etc/yum.repos.d/tfzq.repo|grep baseurl|grep epel|awk -F '=' '{print $2}'|xargs curl -s -o /dev/null -w "%{http_code}"`

    if [[ $epel_code == '404' ]]; then
        echo -e "${error}: Epel源无法访问,请检查文件\"/etc/yum.repos.d/tfzq.repo\" !!! "
        exit 1 
    fi
    if [[ $oel_code == '404' ]]; then
        echo -e "${error}: ${DISTRO}源无法访问,请检查文件\"/etc/yum.repos.d/tfzq.repo\" !!! "
        exit 1 
    fi

    #define oracle version
    rpms=(
    wget
    lsof
    vim
    unzip
    dstat
    )
    for ((i=1;i<=${#rpms[@]};i++ )); do
        if ! type ${hint} >/dev/null 2>&1; then
            yum install ${hint} -y
        fi
    done

    if [ "${DISTRO}" != "Oracle" ] && [ "${install_select}" != "5" ]; then
        if ! type psmisc >/dev/null 2>&1; then
            yum install psmisc -y
        fi
    fi

    yum groupinstall "Development tools" -y
}

## Ctrl+c
Press_Start()
{
    clear
    echo -e "===========================Summary  Info================================="
    echo -e "Oracle Home Dir            : ${info}${oraclepath}/product/${dbhome_str}/dbhome_1"
    echo -e "OS Password                : ${info}oracle/${oraclepw}"
    echo -e "Oracle Base Dir            : ${info}${oraclepath}"
    echo -e "Oracle SID                 : ${info}${orasid}"
    echo -e "Oracle Version             : ${info}${oraversion}"
    echo -e "Oracle Charset             : ${info}${oracharacter}"
    if [[ ${oraversion} != '11g' ]];then
        echo -e "Pdb Name                   : ${info}${pdbsid}"
    fi
    echo -e "=========================================================================="
    echo  ""
    if [ "${install_select}" == "1" ]; then
        Echo_Yellow "现在准备安装完整数据库，包含实例！"
    else
        Echo_Yellow "现在仅安装数据库软件，不包含实例！"
    fi
    echo -e "${warning}按任意键开始运行...输入Ctrl+c退出脚本"
    OLDCONFIG=`stty -g`
    stty -icanon -echo min 1 time 0
    dd count=1 2>/dev/null
    stty ${OLDCONFIG}
}

init_para()
{  
    #Define oracle password
    oraclepw=oracle
    
    #define oracle install directory
    oraclepath=/u01/app/oracle
    
    #define oracle version
    versions=(
    11g
    18c
    19c
    )
    while true
    do
    echo -e "${info}选择要安装的Oracle数据库版本:"
    
    for ((i=1;i<=${#versions[@]};i++ )); do
        hint="${versions[$i-1]}"
        echo -e "${i}) ${hint}"
    done
    read -p "选择oracle版本(Default: ${versions[0]}):" pick
    [ -z "$pick" ] && pick=1
    expr ${pick} + 1 &>/dev/null
    if [ $? -ne 0 ]; then
        echo -e "${error}请输入数字："
        continue
    fi
    if [[ "$pick" -lt 1 || "$pick" -gt ${#versions[@]} ]]; then
        echo -e "${error}请输入介于1和${#versions[@]}的数字："
        continue
    fi
    oraversion=${versions[$pick-1]}
    echo
    echo "---------------------------"
    echo "version = ${oraversion}"
    echo "---------------------------"
    echo
    break
    done

    #character
    characters=(
    ZHS16GBK
    AL32UTF8
    )
    while true
    do
    echo -e "${warning}请选择oracle字符集:"
    
    for ((i=1;i<=${#characters[@]};i++ )); do
        hint="${characters[$i-1]}"
        echo -e "${i}) ${hint}"
    done
    read -p "请选择(Default: ${characters[0]}):" pick
    [ -z "$pick" ] && pick=1
    expr ${pick} + 1 &>/dev/null
    if [ $? -ne 0 ]; then
        echo -e "${error}请输入数字："
        continue
    fi
    if [[ "$pick" -lt 1 || "$pick" -gt ${#characters[@]} ]]; then
        echo -e "${error}请输入介于1和${#characters[@]}的数字："
        continue
    fi
    oracharacter=${characters[$pick-1]}
    echo
    echo "---------------------------"
    echo "字符集 = ${oracharacter}"
    echo "---------------------------"
    echo
    break
    done

    #set dbhome
    if [[ ${oraversion} == '11g' ]];then
        dbhome_str=11.2.0
    elif [[ ${oraversion} == '18c' ]];then
        dbhome_str=18.0.0
    elif [[ ${oraversion} == '19c' ]];then
        dbhome_str=19.0.0
    fi

    if [ "${install_select}" == "1" ]; then
        #define oracle_sid
        echo -e "${warning}请输入oracle_sid: "
        read -p "(Default oracle_sid: orcl):" orasid
        [ -z ${orasid} ] && orasid=orcl
        echo
        echo "---------------------------"
        echo "oracle_sid = ${orasid}"
        echo "---------------------------"
        echo

        if [[ ${oraversion} != '11g' ]];then
            echo -e "${warning}对于CDB数据库,需要指定一个pdbname: "
            read -p "(Default pdbname: pdb1):" pdbsid
            [ -z ${pdbsid} ] && pdbsid=pdb1
            echo
            echo "---------------------------"
            echo "pdb_name = ${pdbsid}"
            echo "---------------------------"
            echo
        fi
    fi
}


download_soft()
{
    cd ${softdir}
    echo
    echo "======================================="
    echo -e "${warning}正在下载oracle相关安装软件... "
    echo "======================================="
    echo
    rm -rf /home/soft/*
    if [ "${install_select}" == "5" ]; then
        wget -e robots=off -R "index.html*" -r -np -nd ${url}/oracle/client/${oraversion}/
    else
        wget -e robots=off -R "index.html*" -r -np -nd ${url}/oracle/${oraversion}/
    fi
}



#check oracle install software
unzip_soft()
{
    cd ${softdir}
    echo
    echo "======================================="
    echo -e "${warning}正在解压软件压缩包..."
    echo "======================================="
    echo

    for i in `ls p*.zip`;
    do 
        unzip -q $i
    done

    if [[ ${oraversion} != '11g' ]];then
        mkdir -p ${oraclepath}/product/${dbhome_str}/dbhome_1
        cd ${oraclepath}/product/${dbhome_str}/dbhome_1
        unzip -q ${softdir}/LINUX.X64_*_db_home.zip
        chown -R oracle:oinstall ${oraclepath}
    fi
}

# set kernel param
kernel()
{
    cd ${softdir}
    if [ "${DISTRO}" = "Oracle" ]; then
        if [[ ${main_ver} -eq 6 ]];then
            if [[ ${oraversion} == '11g' ]];then
                rpmurl='oracle-rdbms-server-11gR2-preinstall-1.0-15.el6.x86_64.rpm'
            elif [[ ${oraversion} == '18c' ]];then
                rpmurl='oracle-database-preinstall-18c-1.0-1.el6.x86_64.rpm'
            elif [[ ${oraversion} == '19c' ]];then
                echo -e "${error}: Oracle 19c不支持linux 6,请选择其他版本! "
                exit 1  
            fi
        elif [[ ${main_ver} -eq 7 ]];then
            if [[ ${oraversion} == '11g' ]];then
                rpmurl='oracle-rdbms-server-11gR2-preinstall-1.0-6.el7.x86_64.rpm'
            elif [[ ${oraversion} == '18c' ]];then
                rpmurl='oracle-database-preinstall-18c-1.0-1.el7.x86_64.rpm'
            elif [[ ${oraversion} == '19c' ]];then
                rpmurl='oracle-database-preinstall-19c-1.0-2.el7.x86_64.rpm'
            fi
        elif [[ ${main_ver} -eq 8 ]];then
            if [[ ${oraversion} == '19c' ]];then
                rpmurl='oracle-database-preinstall-19c-1.0-1.el8.x86_64.rpm'
            else 
                echo -e "${error}: Oracle Linux 8只支持19c自动化安装"
                exit 1  
            fi
        fi
        wget -O oracle-database-preinstall.rpm ${url}/oracle/rpm/${rpmurl}
        yum -y localinstall oracle-database-preinstall.rpm
    else
        if [[ ${main_ver} -eq 6 ]];then
            if [[ ${oraversion} == '19c' ]];then
                echo -e "${error}: Oracle 19c不支持linux 6，请更换其他版本！"
                exit 1
            else
                redhat6
            fi
        elif [[ ${main_ver} -eq 7 ]];then
            redhat7
        elif [[ ${main_ver} -eq 8 ]];then
            if [[ ${oraversion} == '19c' ]];then
                redhat8
            else 
                echo -e "${error}: Linux 8只支持19c自动化安装"
                exit 1  
            fi
        fi
    fi
    # set oracle passwd
    echo ${oraclepw}|passwd oracle --stdin
    sed -i '/export ORACLE_TERM=xterm/,+17d;:go;1,3!{P;$!N;D};N;bgo' $BASH_PROFILE

    cat <<EOF >> $BASH_PROFILE
export ORACLE_BASE=$1
export ORACLE_HOME=\$ORACLE_BASE/product/${dbhome_str}/dbhome_1
export ORACLE_SID=$2
export ORACLE_TERM=xterm
export NLS_DATA_FORMAT="DD-MON-YYYY HH24:MI:SS"
export NLS_LANG="AMERICAN_AMERICA.UTF8"
export TNS_ADMIN=\$ORACLE_HOME/network/admin
export ORA_NLS11=\$ORACLE_HOME/nls/data
export PATH=.:\${JAVA_HOME}/bin:\${PATH}:$HOME/bin:\$ORACLE_HOME/bin:\$ORACLE_HOME/OPatch
export PATH=\${PATH}:/usr/bin:/bin:/usr/bin/X11:/usr/local/bin
export LD_LIBRARY_PATH=\$ORACLE_HOME/lib
export LD_LIBRARY_PATH=\${LD_LIBRARY_PATH}:\$ORACLE_HOME/oracm/lib
export LD_LIBRARY_PATH=\${LD_LIBRARY_PATH}:/lib:/usr/lib:/usr/local/lib
export CLASSPATH=\$ORACLE_HOME/JRE
export CLASSPATH=\${CLASSPATH}:\$ORACLE_HOME/jlib
export CLASSPATH=\${CLASSPATH}:\$ORACLE_HOME/rdbms/jlib
export CLASSPATH=\${CLASSPATH}:\$ORACLE_HOME/network/jlib
export THREADS_FLAG=native
export TEMP=/tmp
export TMPDIR=/tmp
export LANG=en_US.UTF-8
umask 022
EOF

}

redhat6()
{
    yum -y install binutils compat-libstdc++* glibc ksh libaio libgcc libstdc++ make compat-libcap1 gcc gcc-c++ glibc-devel libaio-devel libstdc++-devel sysstat 
    sed -i '/fs.file-max = 6815744/,+13d' /etc/sysctl.conf
    cat >> /etc/sysctl.conf <<EOF
fs.file-max = 6815744
kernel.sem = 250 32000 100 128
kernel.shmmni = 4096
kernel.shmall = 1073741824
kernel.shmmax = 4398046511104
kernel.panic_on_oops = 1
net.core.rmem_default = 262144
net.core.rmem_max = 4194304
net.core.wmem_default = 262144
net.core.wmem_max = 1048576
net.ipv4.conf.all.rp_filter = 2
net.ipv4.conf.default.rp_filter = 2
fs.aio-max-nr = 1048576
net.ipv4.ip_local_port_range = 9000 65500
EOF
    sysctl -p
    sed -i '/oracle soft nproc 2047/,+4d' /etc/security/limits.conf
    cat >> /etc/security/limits.conf <<EOF
oracle soft nproc 2047
oracle hard nproc 16384
oracle soft nofile 1024
oracle hard nofile 65536
oracle soft stack 10240
EOF
    sed -i '/pam_limits.so/d' /etc/pam.d/login
    cat >> /etc/pam.d/login <<EOF
session required pam_limits.so
EOF
groupadd oinstall
groupadd dba
useradd -g oinstall -G dba oracle
}

redhat7()
{
    yum -y install compat-libstdc++* binutils compat-libcap1 gcc gcc-c++ glibc glibc-devel ksh libaio libaio-devel libgcc libstdc++ libstdc++-devel libXi libXtst make sysstat cpp glibc-headers mpfr
    sed -i '/fs.file-max = 6815744/,+13d' /etc/sysctl.conf
    cat >> /etc/sysctl.conf <<EOF
fs.file-max = 6815744
kernel.sem = 250 32000 100 128
kernel.shmmni = 4096
kernel.shmall = 1073741824
kernel.shmmax = 4398046511104
kernel.panic_on_oops = 1
net.core.rmem_default = 262144
net.core.rmem_max = 4194304
net.core.wmem_default = 262144
net.core.wmem_max = 1048576
net.ipv4.conf.all.rp_filter = 2
net.ipv4.conf.default.rp_filter = 2
fs.aio-max-nr = 1048576
net.ipv4.ip_local_port_range = 9000 65500
EOF
    sysctl -p
    sed -i '/oracle   soft   nofile    1024/,+7d' /etc/security/limits.conf
    cat >> /etc/security/limits.conf <<EOF
oracle   soft   nofile    1024
oracle   hard   nofile    65536
oracle   soft   nproc    16384
oracle   hard   nproc    16384
oracle   soft   stack    10240
oracle   hard   stack    32768
oracle   hard   memlock    134217728
oracle   soft   memlock    134217728
EOF
    sed -i '/pam_limits.so/d' /etc/pam.d/login
    cat >> /etc/pam.d/login <<EOF
session required pam_limits.so
EOF
groupadd oinstall
groupadd dba
useradd -g oinstall -G dba oracle
}

redhat8()
{
    yum -y install bc binutils elfutils-libelf elfutils-libelf-devel fontconfig-devel glibc glibc-devel ksh libaio libaio-devel libXrender libX11 libXau libXi libXtst libgcc libnsl librdmacm libstdc++ libstdc++-devel libxcb libibverbs make smartmontools sysstat libnsl2 libnsl2-devel
    sed -i '/fs.file-max = 6815744/,+13d' /etc/sysctl.conf
    cat >> /etc/sysctl.conf <<EOF
fs.file-max = 6815744
kernel.sem = 250 32000 100 128
kernel.shmmni = 4096
kernel.shmall = 1073741824
kernel.shmmax = 4398046511104
kernel.panic_on_oops = 1
net.core.rmem_default = 262144
net.core.rmem_max = 4194304
net.core.wmem_default = 262144
net.core.wmem_max = 1048576
net.ipv4.conf.all.rp_filter = 2
net.ipv4.conf.default.rp_filter = 2
fs.aio-max-nr = 1048576
net.ipv4.ip_local_port_range = 9000 65500
EOF
    sysctl -p
    sed -i '/oracle   soft   nofile    1024/,+7d' /etc/security/limits.conf
    cat >> /etc/security/limits.conf <<EOF
oracle   soft   nofile    1024
oracle   hard   nofile    65536
oracle   soft   nproc    16384
oracle   hard   nproc    16384
oracle   soft   stack    10240
oracle   hard   stack    32768
oracle   hard   memlock    134217728
oracle   soft   memlock    134217728
EOF
    sed -i '/pam_limits.so/d' /etc/pam.d/login
    cat >> /etc/pam.d/login <<EOF
session required pam_limits.so
EOF
groupadd oinstall
groupadd dba
groupadd oper
groupadd backupdba
groupadd dgdba
groupadd kmdba
groupadd racdba
useradd -g oinstall -G dba,oper,backupdba,dgdba,kmdba,racdba oracle
}

install_db_soft()
{
    cd ${softdir}
    if [ ! -f "install_db${oraversion}.rsp" ];then
        wget ${url}/oracle/${oraversion}/install_db${oraversion}.rsp
    fi
    echo
    echo "======================================="
    echo -e "${warning}正在安装数据库软件..."
    echo "======================================="
    echo
    if [[ ${oraversion} == '11g' ]];then
        su - oracle -c "cd ${softdir}/database/;./runInstaller -ignoreSysPrereqs -ignorePrereq -silent -waitforcompletion -responseFile ${softdir}/install_db${oraversion}.rsp"
        /u01/app/oraInventory/orainstRoot.sh
        ${oraclepath}/product/${dbhome_str}/dbhome_1/root.sh -silent
    else
        su - oracle -c "cd ${oraclepath}/product/${dbhome_str}/dbhome_1;./runInstaller  -ignorePrereq -silent -waitforcompletion -responseFile ${softdir}/install_db${oraversion}.rsp"
        ${oraclepath}/product/${dbhome_str}/dbhome_1/root.sh -silent
    fi


    if [ $? -eq 0 ];then
        echo "======================================="
        echo -e "${info}数据库软件安装成功！"
        echo "======================================="
    else 
        echo "======================================="
        echo -e "${error}数据库软件安装失败！"
        echo "======================================="
        exit 1
    fi
}

install_dbca()
{   
    echo
    echo "======================================="
    echo -e "${warning}正在创建数据库实例..."
    echo "======================================="
    echo
    if [[ ${oraversion} == '11g' ]];then
        su - oracle -c "source /home/oracle/.bash_profile;
            dbca -silent -createDatabase \
            -templateName General_Purpose.dbc -gdbname ${orasid} \
            -sid ${orasid} -sysPassword oracle -systemPassword oracle \
            -responseFile NO_VALUE -characterSet ${oracharacter} -memoryPercentage 60 \
            -datafileDestination "/u01/app/oracle/oradata/" \
            -emConfiguration none -redoLogFileSize 1024 "
            
    else
        su - oracle -c "source /home/oracle/.bash_profile;
            dbca -silent -createDatabase \
            -templateName General_Purpose.dbc -gdbname ${orasid} \
            -createAsContainerDatabase true -numberOfPDBs 1 -pdbName ${pdbsid} \
            -pdbAdminPassword oracle -databaseType MULTIPURPOSE \
            -sid ${orasid} -sysPassword oracle -systemPassword oracle \
            -responseFile NO_VALUE -characterSet AL32UTF8 -memoryPercentage 60 \
            -datafileDestination "/u01/app/oracle/oradata/" \
            -emConfiguration none -redoLogFileSize 1024 "
        if [[ ${oracharacter} == 'ZHS16GBK' ]]; then
            echo
            echo "======================================="
            echo -e "${warning}修改PDB字符集为ZHS16GBK..."
            echo "======================================="
            echo
            su - oracle -c "source /home/oracle/.bash_profile;sqlplus / as sysdba <<EOF
            alter pluggable database ${pdbsid} close immediate;
            alter pluggable database ${pdbsid} open read write restricted;
            alter session set container=${pdbsid};
            alter database character set internal_use zhs16gbk;
            alter pluggable database ${pdbsid} close immediate;
EOF"
        fi
    fi

    if [ $? -eq 0 ];then
        echo "======================================="
        echo -e "${info}数据库实例安装成功！"
        echo "======================================="
    else 
        echo "======================================="
        echo -e "${error}数据库实例安装失败！"
        echo "======================================="
        exit 1
    fi
    ### config expire time
    if [[ ${oraversion} == '11g' ]];then
        su - oracle -c "source /home/oracle/.bash_profile;echo SQLNET.EXPIRE_TIME=10 >> ${homepath}/network/admin/sqlnet.ora"
    else
        su - oracle -c "source /home/oracle/.bash_profile;cat >> ${homepath}/network/admin/sqlnet.ora <<EOF
SQLNET.ALLOWED_LOGON_VERSION_CLIENT=8
SQLNET.ALLOWED_LOGON_VERSION_SERVER=8
SQLNET.EXPIRE_TIME=10
EOF"
    fi
    echo -e "${warning}启动数据库监听..."
    su - oracle -c "source /home/oracle/.bash_profile;lsnrctl start"
}

set_client()
{
    echo
    echo "======================================="
    echo -e "${warning}正在安装oracle linux客户端..."
    echo "======================================="
    echo
    cd ${softdir}
    yum install oracle*.rpm -y
    if [ -d "/usr/lib/oracle/${clienturl}/client64/lib" ]; then
        cd /usr/lib/oracle/${clienturl}/client64/lib
        mkdir -p network/admin
        touch network/admin/tnsnames.ora
    fi
    sed -i '/CLIENT_HOME/,+2d' /etc/profile
    cat <<EOF >> /etc/profile
export CLIENT_HOME=/usr/lib/oracle/${clienturl}/client64
export LD_LIBRARY_PATH=$CLIENT_HOME/lib
export PATH=$CLIENT_HOME/bin:$PATH
EOF
    source /etc/profile
    clear
    echo -e "=============================Client  Info================================="
    echo -e "Oracle Home                : ${info}/usr/lib/oracle/${clienturl}/client64"
    echo -e "Oracle TNS                 : ${info}/usr/lib/oracle/${clienturl}/client64/lib/network/admin/tnsnames.ora"
    echo -e "=========================================================================="

}

version_gt() { test "$(echo "$@" | tr " " "\n" | sort -V | head -n 1)" != "$1"; }
version_le() { test "$(echo "$@" | tr " " "\n" | sort -V | head -n 1)" == "$1"; }
version_lt() { test "$(echo "$@" | tr " " "\n" | sort -rV | head -n 1)" != "$1"; }
version_ge() { test "$(echo "$@" | tr " " "\n" | sort -rV | head -n 1)" == "$1"; }

gcc_version()
{
    gcc_ver=$(ldd --version|grep ldd|awk '{print $4}')

    versions=(
    11g
    18c
    19c
    )
    while true
    do
    echo -e "${info}Please choose oracle client version to install:"
    
    for ((i=1;i<=${#versions[@]};i++ )); do
        hint="${versions[$i-1]}"
        echo -e "${i}) ${hint}"
    done
    read -p "选择oracle客户端版本(Default: ${versions[0]}):" pick
    [ -z "$pick" ] && pick=1
    expr ${pick} + 1 &>/dev/null
    if [ $? -ne 0 ]; then
        echo -e "${error}请输入数字："
        continue
    fi
    if [[ "$pick" -lt 1 || "$pick" -gt ${#versions[@]} ]]; then
        echo -e "${error}请输入介于1和${#versions[@]}的数字："
        continue
    fi
    oraversion=${versions[$pick-1]}
    if [ ${oraversion} == '19c' ];then
        if version_lt ${gcc_ver} '2.14';then
            echo -e "${error}gcc版本${gcc_ver}太低，不满足${oraversion}最低要求2.14"
            exit 1
        fi
    fi
    if [ ${oraversion} == '11g' ];then
        clienturl='11.2'
    elif [ ${oraversion} == '18c' ]; then
        clienturl='18.5'
    elif [ ${oraversion} == '19c' ]; then
        clienturl='19.16'
    fi
    echo
    echo "---------------------------"
    echo "version = ${oraversion}"
    echo "---------------------------"
    echo
    break
    done
}

set_param()
{
echo "======================================="    
echo -e "${warning}配置数据库参数..."
echo "======================================="

if [[ ${oraversion} = '11g' ]];then
    su - oracle -c "source /home/oracle/.bash_profile;sqlplus / as sysdba <<EOF
    alter system set open_cursors=2000 scope=spfile sid='*';
    alter system set session_cached_cursors=300 scope=spfile sid='*';
    alter system set OPTIMIZER_INDEX_COST_ADJ=10 scope=spfile sid='*';
    alter system set deferred_segment_creation=false scope=spfile sid='*';
    alter system set SEC_CASE_SENSITIVE_LOGON =FALSE scope=both sid='*';
    alter system set \"_use_adaptive_log_file_sync\"=false scope=spfile sid='*';
    alter system set optimizer_index_caching=90 scope=spfile sid='*';
    alter system set dispatchers='' scope=spfile sid='*';
    alter system set audit_trail=none scope=spfile sid='*';
    alter system set processes=1000 scope=spfile;
    alter system set db_files=500 scope=spfile;
    alter profile default limit PASSWORD_LIFE_TIME UNLIMITED;
    exec DBMS_AUTO_TASK_ADMIN.DISABLE(client_name => 'auto space advisor',operation => NULL,window_name => NULL);
    exec DBMS_AUTO_TASK_ADMIN.DISABLE(client_name => 'sql tuning advisor',operation => NULL,window_name => NULL);
    shutdown immediate;
    startup;
EOF"
else
    su - oracle -c "source /home/oracle/.bash_profile;sqlplus / as sysdba <<EOF
    alter system set open_cursors=2000 scope=spfile sid='*';
    alter system set session_cached_cursors=300 scope=spfile sid='*';
    alter system set OPTIMIZER_INDEX_COST_ADJ=10 scope=spfile sid='*';
    alter system set deferred_segment_creation=false scope=spfile sid='*';
    alter system set \"_use_adaptive_log_file_sync\"=false scope=spfile sid='*';
    alter system set optimizer_index_caching=90 scope=spfile sid='*';
    alter system set dispatchers='' scope=spfile sid='*';
    alter system set audit_trail=none scope=spfile sid='*';
    alter system set processes=1000 scope=spfile;
    alter system set db_files=500 scope=spfile;
    alter profile default limit PASSWORD_LIFE_TIME UNLIMITED;
    exec DBMS_AUTO_TASK_ADMIN.DISABLE(client_name => 'auto space advisor',operation => NULL,window_name => NULL);
    exec DBMS_AUTO_TASK_ADMIN.DISABLE(client_name => 'sql tuning advisor',operation => NULL,window_name => NULL);
    alter system set \"_allow_insert_with_update_check\"=true;
    alter system reset \"_optimizer_nlj_hj_adaptive_join\" scope=both sid='*'; 
    alter system reset \"_optimizer_strans_adaptive_pruning\"  scope=both sid='*';
    alter system reset \"_px_adaptive_dist_method\"  scope=both sid='*';
    alter system reset \"_sql_plan_directive_mgmt_control\"  scope=both sid='*';
    alter system reset \"_optimizer_dsdir_usage_control\"  scope=both sid='*';
    alter system reset \"_optimizer_use_feedback\"  scope=both sid='*';
    alter system reset \"_optimizer_gather_feedback\"  scope=both sid='*';
    alter system reset \"_optimizer_performance_feedback\"  scope=both sid='*';
    shutdown immediate;
    startup;
    alter pluggable database ${pdbsid} open;
    alter pluggable database ${pdbsid} save state;
    alter session set container=${pdbsid};
    alter profile default limit PASSWORD_LIFE_TIME UNLIMITED;
EOF"
fi
}

auto_start()
{
    ### config Oracle autostart
    if [[ `grep "/u01/app/oracle/product/11.2.0/dbhome_1" /etc/oratab` = "" ]];then
        echo "${orasid}:${homepath}:Y" >> /etc/oratab
    else
        sed -i 's/\:N$/:Y/g' /etc/oratab
    fi

    if [[ `grep "lsnrctl start" /etc/rc.local` = "" ]];then
        echo 'su - oracle -c "lsnrctl start"' >> /etc/rc.local
        echo 'su - oracle -c "dbstart"' >> /etc/rc.local
    fi
    chmod +x /etc/rc.d/rc.local
}

check_hugepage()
{
    check_ip
    HugePages_Total=`grep HugePages_Total /proc/meminfo | awk '{print $2}'`
    MemTotal=`grep MemTotal /proc/meminfo | awk '{print $2}'`
    if [ ${HugePages_Total} -eq 0 ];then
        # 内存大于40GB
        if [ ${MemTotal} -gt 41943040 ];then
            echo "======================================="
            echo -e "${info}当前环境建议配置HugePage，以提高性能！"
            echo "======================================="
            if [ "${install_select}" == "1" ] || [ "${install_select}" == "4" ]; then
                set_hugepage
            else
                echo "======================================="
                echo -e "${warning}请在数据库实例安装完毕后手动配置HugePage！"
                echo -e "${warning}重新执行本脚本，选择4：\n
bash <(curl -s -L ${url}/oracle/auto-install.sh)"
                echo "======================================="
            fi
        fi
    fi
}

set_hugepage()
{
    # Check for the kernel version
KERN=`uname -r | awk -F. '{ printf("%d.%d\n",$1,$2); }'`

# Find out the HugePage size
HPG_SZ=`grep Hugepagesize /proc/meminfo | awk '{print $2}'`
if [ -z "$HPG_SZ" ];then
    echo -e "${error}当前系统不支持hugepage！"
    exit 1
fi

MemTotal=`grep MemTotal /proc/meminfo | awk '{print $2}'`

# Initialize the counter
NUM_PG=0

# Cumulative number of pages required to handle the running shared memory segments
for SEG_BYTES in `ipcs -m | cut -c44-300 | awk '{print $1}' | grep "[0-9][0-9]*"`
do
    MIN_PG=`echo "$SEG_BYTES/($HPG_SZ*1024)" | bc -q`
    if [ $MIN_PG -gt 0 ]; then
        NUM_PG=`echo "$NUM_PG+$MIN_PG+1" | bc -q`
    fi
done

RES_BYTES=`echo "$NUM_PG * $HPG_SZ * 1024" | bc -q`

# An SGA less than 100MB does not make sense
# Bail out if that is the case
if [ $RES_BYTES -lt 100000000 ]; then
    echo -e "${error}没有足够的共享内存段分配给HugePages，HugePages只能用于命令列出的共享内存段:\n
# ipcs -m\n
请确认如下环境:\n
 1) Oracle数据库实例是正常运行的。\n
 2) Oracle数据库没有配置Automatic Memory Management (AMM)"
    exit 1
fi

# Finish with results
case $KERN in
    '2.4') HUGETLB_POOL=`echo "$NUM_PG*$HPG_SZ/1024" | bc -q`;
           echo "建议配置: vm.hugetlb_pool = $HUGETLB_POOL" ;;
    '2.6') echo "建议配置: vm.nr_hugepages = $NUM_PG" ;;
    '3.8') echo "建议配置: vm.nr_hugepages = $NUM_PG" ;;
    '3.10') echo "建议配置: vm.nr_hugepages = $NUM_PG" ;;
    '4.1') echo "建议配置: vm.nr_hugepages = $NUM_PG" ;;
    '4.14') echo "建议配置: vm.nr_hugepages = $NUM_PG" ;;
    '4.18') echo "建议配置: vm.nr_hugepages = $NUM_PG" ;;
    '5.4') echo "建议配置: vm.nr_hugepages = $NUM_PG" ;;
    *) echo -e "${error}内核版本$KERN目前还不支持，Exiting." 
       exit 1;;
esac

echo -e "${warning}根据脚本计算出的建议值，进行参数配置："
echo -e "${warning}按任意键开始运行...输入Ctrl+c退出脚本"
OLDCONFIG=`stty -g`
stty -icanon -echo min 1 time 0
dd count=1 2>/dev/null
stty ${OLDCONFIG}

if [ $KERN = '2.4' ];then
    sysctl -w vm.hugetlb_pool = $HUGETLB_POOL
    sed -i '/hugetlb_pool/d' /etc/sysctl.conf
    echo "vm.hugetlb_pool = $HUGETLB_POOL" >> /etc/sysctl.conf
else
    # 设置hugepage值
    sysctl -w vm.nr_hugepages=$NUM_PG
    # 永久生效则配置/etc/sysctl.conf文件
    sed -i '/nr_hugepages/d' /etc/sysctl.conf
    echo "vm.nr_hugepages=$NUM_PG" >> /etc/sysctl.conf
fi
sysctl -p
# 修改/etc/security/limits.conf文件
sed -i '/memlock/d' /etc/security/limits.conf
echo >> /etc/security/limits.conf <<EOF
*   soft   memlock    ${MemTotal}
*   hard   memlock    ${MemTotal}
EOF
Echo_Yellow "检查是否生效 (1 or 2 pages free) ，如不生效则需要重启实例或机器。"
Echo_Yellow "执行：grep Huge /proc/meminfo"

echo -e "${warning}如果SGA或者物理内存进行了调整，Hugepage需要重新设置，切记！！！"
}

patch()
{
    homepath=${oraclepath}/product/${dbhome_str}/dbhome_1
    cd ${homepath}
    if [ -d OPatch.bkp ];then
        rm -rf OPatch.bkp
        mv OPatch OPatch.bkp
    else
        mv OPatch OPatch.bkp
    fi
    cp -r ${softdir}/OPatch . && chown -R oracle:dba OPatch

    cd $softdir
    if [ ! -f "file.rsp" ];then
        wget ${url}/oracle/file.rsp
    fi
    echo
    echo "======================================="
    echo -e "${warning}正在安装数据库补丁..."
    echo "======================================="
    echo
    su - oracle -c "cd ${softdir}/[1-9]*;source /home/oracle/.bash_profile;opatch apply -silent -ocmrf ${softdir}/file.rsp" 
    if [ $? -eq 0 ];then
        echo "======================================="
        echo -e "${info}数据库补丁安装成功！"
        echo "======================================="
    else 
        echo "======================================="
        echo -e "${error}数据库补丁安装失败！"
        echo "======================================="
        exit 1
    fi
}

glogin()
{
    cd ${oraclepath}/product/${dbhome_str}/dbhome_1
    sed -i '/set linesize 999/,+22d' sqlplus/admin/glogin.sql
    cat <<EOF >> sqlplus/admin/glogin.sql
set linesize 999
set pagesize 999
col first_change# for 99999999999999999
col next_change# for 999999999999999999999
col checkpoint_change# for 99999999999999999
col resetlogs_change# for 99999999999999999
col plan_plus_exp for a100
col value_col_plus_show_param ON HEADING  'VALUE'  FORMAT a100
col name_col_plus_show_param ON HEADING 'PARAMETER_NAME' FORMAT a60
col owner           for a30 wrap
col object_name     for a30 wrap
col subobject_name  for a30 wrap
col segment_name    for a30 wrap
col partition_name  for a30 wrap
define _editor='vi'
set termout off
def _i_user="&_user"
def _i_conn="&_connect_identifier"
col _i_user noprint new_value _i_user
col _i_conn noprint new_value _i_conn
select lower('&_user') "_i_user",upper('&_connect_identifier') "_i_conn" from dual;
set termout on
set sqlprompt "&_i_user@&_i_conn> "
EOF
}

rlwrap()
{
    echo
    echo "======================================="
    echo -e "${warning}正在安装rlwrap工具..."
    echo "======================================="
    echo
    yum install readline* libtermcap-devel* -y > /dev/null 2>&1
    cd $softdir
    wget ${url}/soft/rlwrap-0.43.tar.gz
    tar -zxvf rlwrap-0.43.tar.gz
    cd rlwrap-0.43
    ./configure > /dev/null 2>&1
    make && make install > /dev/null 2>&1
    sed -i '/alias/d' /home/oracle/.bash_profile
    cat <<EOF >> /home/oracle/.bash_profile
alias sqlplus='rlwrap -D2 -irc -b'\''"@(){}[],+=&^%#;|\'\'' \${ORACLE_HOME}/bin/sqlplus'
alias rman='rlwrap -D2 -irc -b'\''"@(){}[],+=&^%#;|\'\'' \${ORACLE_HOME}/bin/rman'
alias asmcmd='rlwrap -D2 -irc -b'\''"@(){}[],+=&^%#;|\'\'' \${ORACLE_HOME}/bin/asmcmd'
alias dgmgrl='rlwrap -D2 -irc -b'\''"@(){}[],+=&^%#;|\'\'' \${ORACLE_HOME}/bin/dgmgrl'
alias ss='sqlplus / as sysdba'
alias dt='cd \${ORACLE_BASE}/diag/rdbms/\${ORACLE_SID}/\${ORACLE_SID}/trace'
EOF
}

instance_info()
{
    clear
    ips=(`ifconfig | grep inet | grep -v inet6 |grep -v 'inet 127' |sed 's/^[ \t]*//g' | cut -d ' ' -f2`)
    echo -e "${info}恭喜, 数据库全部安装成功！"
    echo -e "=========================================================================="
    echo -e "Oracle Home Dir            : ${info}${oraclepath}/product/${dbhome_str}/dbhome_1"
    echo -e "OS Password                : ${info}oracle/${oraclepw}"
    echo -e "Oracle Base Dir            : ${info}${oraclepath}"
    echo -e "Oracle SID                 : ${info}${orasid}"
    if [[ ${oraversion} != '11g' ]];then
        echo -e "Oracle PDB                 : ${info}${pdbsid}"
    fi
    echo -e "Oracle Version             : ${info}${oraversion}"
    echo -e "Oracle Charset             : ${info}${oracharacter}"
    echo -e "Oracle User/Password       : ${info}(sys|system)/oracle"
    echo  ""
    echo -e "===================================TNS===================================="
    if [[ ${oraversion} = '11g' ]];then
        echo -e "${orasid} ="
    else
        echo -e "${pdbsid} ="
    fi
    echo -e " (DESCRIPTION ="
    echo -e "   (ADDRESS_LIST ="
    echo -e "     (ADDRESS = (PROTOCOL = TCP)(HOST = ${ips})(PORT = 1521))"
    echo -e "   )"
    echo -e "   (CONNECT_DATA ="
    if [[ ${oraversion} = '11g' ]];then
        echo -e "     (SERVICE_NAME = ${orasid})"
    else
        echo -e "     (SERVICE_NAME = ${pdbsid})"
    fi
    echo -e "   )"
    echo -e " )"
    echo -e "=========================================================================="
    echo  ""

    if [[ ${oraversion} != '11g' ]];then
        cat > ${oraclepath}/product/${dbhome_str}/dbhome_1/network/admin/tnsnames.ora <<EOF
${pdbsid} =
 (DESCRIPTION =
   (ADDRESS_LIST =
     (ADDRESS = (PROTOCOL = TCP)(HOST = localhost)(PORT = 1521))
   )
   (CONNECT_DATA =
     (SERVICE_NAME = ${pdbsid})
   )
 )
EOF
        chown oracle:oinstall ${oraclepath}/product/${dbhome_str}/dbhome_1/network/admin/tnsnames.ora
    fi
}


delete_soft()
{
    if [ -d "/home/soft" ];then
        rm -rf /home/soft
    fi
}

#execute functions above
pre-install()
{   
    config_yum
    disable_selinux
    init_para
    Press_Start
    kernel ${oraclepath} ${orasid}
    mkdir -p ${oraclepath} && chown -R oracle:oinstall ${oraclepath} && chmod -R 755 ${oraclepath}
    download_soft
    unzip_soft
    if [ -d ${softdir}/database/ ];then
        chown -R oracle:oinstall ${softdir}/database/
    fi
    chown -R oracle:oinstall ${softdir}/[1-9]*/
    chown -R oracle:oinstall ${softdir}/OPatch/
    chown -R oracle:oinstall /u01
    chmod -R 777 /tmp
    echo "======================================="
    echo -e "${info}Oracle安装前配置完成! "
    echo "======================================="
}


# Begin Dataguard Configuration
config_ip()
{   
    echo -e "${warning}对于Dataguard自动化安装，脚本必须要在主库执行！！！"
    declare -a ips
    ips=(`ifconfig | grep inet | grep -v inet6 |grep -v 'inet 127' |sed 's/^[ \t]*//g' | cut -d ' ' -f2`)
    # primary ip
    while true
    do
    for ((i=1;i<=${#ips[@]};i++ )); do
        hint="${ips[$i-1]}"
        echo -e "${i}) ${hint}"
    done
    read -p "选择主库IP(Default: ${ips[0]}):" pick
    [ -z "$pick" ] && pick=1
    expr ${pick} + 1 &>/dev/null
    if [ $? -ne 0 ]; then
        echo -e "${error}选择数字："
        continue
    fi
    if [[ "$pick" -lt 1 || "$pick" -gt ${#ips[@]} ]]; then
        echo -e "${error}请选择介于1和${#ips[@]}之间的数字："
        continue
    fi
    source_ip=${ips[$pick-1]}
    echo
    echo "---------------------------"
    echo "primary ip = ${source_ip}"
    echo "---------------------------"
    echo
    break
    done

    # physical standby ip
    p4=`echo ${source_ip}|awk -F '.' '{print $4}'`
    p3=`echo ${source_ip} | grep -E -o "[0-9]+\.[0-9]+\.[0-9]+"`
    p=`expr ${p4} + 1`
    tip=${p3}.${p}
    echo -e "${info}请选择备库IP: "
    read -p "(Default standby ip: ${tip}):" target_ip
    [ -z ${target_ip} ] && target_ip=${tip}
    if check_env ${target_ip} 0;then
        echo -e "${info}备库IP: ${target_ip}"
    else
        echo -e "${error}IP格式错误或者网络错误！"
        exit 1
    fi
}

dg_pre()
{
    config_ip
    # get oracle sid
    orasid=`cat /home/oracle/.bash_profile|grep "^export ORACLE_SID"|cut -f 2 -d '='`

    # get oracle home path
    path=`cat /home/oracle/.bash_profile |grep dbhome_1|cut -f 2,3,4 -d '/'`
    homepath=/u01/app/oracle/$path

    oraclepw=oracle
    dg_info
}

dg_info()
{
    clear
    echo -e "================================DG  Info================================="
    echo -e "Primary IP                 : ${info}${source_ip}"
    echo -e "Standby IP                 : ${info}${target_ip}"
    echo -e "OS Password                : ${info}oracle/${oraclepw}"
    echo -e "Oracle Home                : ${info}${homepath}"
    echo -e "Oracle SID                 : ${info}${orasid}"
    echo -e "=========================================================================="
    echo  ""
    echo -e "${warning}主库需要开启归档，安装过程中需要重启主库！！！"
    echo -e ""
    echo -e "${warning}按任意键开始运行...输入Ctrl+c退出脚本"
    OLDCONFIG=`stty -g`
    stty -icanon -echo min 1 time 0
    dd count=1 2>/dev/null
    stty ${OLDCONFIG}
}

# set user ORACLE ssh key
config_ssh_key()
{
yum install expect openssh-clients -y
keyfile=/home/oracle/sshkey.sh
cat <<EOG > ${keyfile}
/usr/bin/expect <<EOF
set timeout 10 
spawn ssh-keygen -t rsa
expect {
        "*file in which to save the key*" {
            send "\n\r"
            send_user "/home/oracle/.ssh\r"
            exp_continue
        "*Overwrite (y/n)*"{
            send "n\n\r"
        }
        }
        "*Enter passphrase*" {
            send "\n\r"
            exp_continue
        }
        "*Enter same passphrase again*" {
            send "\n\r"
            exp_continue
        }
}
spawn ssh-copy-id -i /home/oracle/.ssh/id_rsa.pub oracle@${target_ip}
expect {
            #first connect, no public key in ~/.ssh/known_hosts
            "Are you sure you want to continue connecting (yes/no)?" {
            send "yes\r"
            expect "password:"
                send "${oraclepw}\r"
            }
            #already has public key in ~/.ssh/known_hosts
            "password:" {
                send "${oraclepw}\r"
            }
            "Now try logging into the machine" {
                #it has authorized, do nothing!
            }
        }
expect eof
EOF
EOG
chown oracle:oinstall ${keyfile}
chmod 777 ${keyfile}
su - oracle -c "sh ${keyfile}"  > /dev/null 2>&1
rm -f ${keyfile}
}

install_dg()
{
# set primary param
echo "======================================="
echo -e "${info}配置物理主库参数..."
echo "======================================="
    su - oracle -c "source /home/oracle/.bash_profile;sqlplus / as sysdba <<EOF
alter database force logging;
alter system set log_archive_config = 'DG_CONFIG=(${orasid},${orasid}_dg)' scope=spfile;
alter system set log_archive_dest_1 = 'LOCATION=/u01/arch VALID_FOR=(ALL_LOGFILES,ALL_ROLES) DB_UNIQUE_NAME=${orasid}' scope=spfile;
alter system set log_archive_dest_2 = 'SERVICE=${orasid}_dg ASYNC VALID_FOR=(ONLINE_LOGFILES,PRIMARY_ROLE) DB_UNIQUE_NAME=${orasid}_dg' scope=spfile;
alter system set log_archive_dest_state_1 = ENABLE;
alter system set log_archive_dest_state_2 = ENABLE;
alter system set fal_server=${orasid}_dg scope=spfile;
alter system set fal_client=${orasid} scope=spfile;
alter system set standby_file_management=AUTO scope=spfile;
alter system set dg_broker_start=true;
exit;
EOF" 

file=`su - oracle -c "source /home/oracle/.bash_profile;sqlplus -S / as sysdba <<EOF
set heading off
set feedback off
set pages 0
select file_name from dba_data_files where file_id=1;
exit;
EOF"`
url=`echo $file|awk -F '/system01.dbf' '{print $1}'`

su - oracle -c "source /home/oracle/.bash_profile;sqlplus / as sysdba <<EOF
alter system set log_file_name_convert='${url}','${url}' scope=spfile;
alter database add  standby logfile group 4 '${url}/stbredo04.log' size 1g;
alter database add  standby logfile group 5 '${url}/stbredo05.log' size 1g;
alter database add  standby logfile group 6 '${url}/stbredo06.log' size 1g;
alter database add  standby logfile group 7 '${url}/stbredo07.log' size 1g;
exit;
EOF" 


if [ $? -eq 0 ];then
    echo "======================================="
    echo -e "${info}主库参数设置成功！"
    echo "======================================="
else 
    echo "======================================="
    echo -e "${error}主库参数设置失败！"
    echo "======================================="
    exit 1
fi

# config listener.ora
cat <<EOF > ${homepath}/network/admin/listener.ora
SID_LIST_LISTENER =
  (SID_LIST =
    (SID_DESC =
      (SID_NAME = ${orasid})
      (GLOBAL_DBNAME=${orasid})
      (ORACLE_HOME = ${homepath})
    )
    (SID_DESC =
      (SID_NAME = ${orasid})
      (GLOBAL_DBNAME=${orasid}_DGMGRL)
      (ORACLE_HOME = ${homepath})
    )
  )
LISTENER =
  (DESCRIPTION_LIST =
    (DESCRIPTION =
      (ADDRESS = (PROTOCOL = TCP)(HOST = localhost)(PORT = 1521))
      (ADDRESS = (PROTOCOL = IPC)(KEY = EXTPROC1521))
    )
  )
ADR_BASE_LISTENER = /u01/app/oracle
EOF

chown oracle:oinstall ${homepath}/network/admin/listener.ora

# restart listener
echo -e "${info}停止listener..."
su - oracle -c "source /home/oracle/.bash_profile;lsnrctl stop"  

echo -e "${info}启动listener..."
su - oracle -c "source /home/oracle/.bash_profile;lsnrctl start"

# config tnsnames.ora
cat <<EOF >> ${homepath}/network/admin/tnsnames.ora
${orasid} =
  (DESCRIPTION =
    (ADDRESS_LIST =
      (ADDRESS = (PROTOCOL = TCP)(HOST = ${source_ip})(PORT = 1521))
    )
    (CONNECT_DATA =
      (SERVICE_NAME = ${orasid})
    )
  )

${orasid}_dg =
  (DESCRIPTION =
    (ADDRESS_LIST =
      (ADDRESS = (PROTOCOL = TCP)(HOST = ${target_ip})(PORT = 1521))
    )
    (CONNECT_DATA =
      (SERVICE_NAME = ${orasid})
    )
  )
EOF

chown oracle:oinstall ${homepath}/network/admin/tnsnames.ora

# set archivelog mode
mkdir -p /u01/arch
chown -R oracle:oinstall /u01/arch
if [[ -f /var/spool/cron/oracle ]]; then
    sed -i '/del_arch.sh/d' /var/spool/cron/oracle
fi    
echo "0  18  *  *  * /home/oracle/del_arch.sh >/dev/null" >> /var/spool/cron/oracle
cat <<EOFP > /home/oracle/del_arch.sh
#!/bin/bash
source ~/.bash_profile
rman <<EOF
connect target /
run {
delete noprompt archivelog all ;
}
exit;
EOF
exit
EOFP

chmod a+x /home/oracle/del_arch.sh
chown oracle:dba /home/oracle/del_arch.sh

su - oracle -c "source /home/oracle/.bash_profile;sqlplus / as sysdba <<EOF
shutdown immediate;
startup mount;
alter database archivelog;
alter database open;
exit;
EOF"

su - oracle -c "source /home/oracle/.bash_profile;sqlplus / as sysdba <<EOF
create pfile from spfile;
exit;
EOF"

# config scripts for create spfile of standby database 
cat <<EOFGG > /home/oracle/tgt.sh
cd /u01/app/oracle
mkdir -p {/u01/arch,admin/${orasid}/adump,oradata/${orasid},fast_recovery_area/${orasid}}
source /home/oracle/.bash_profile
export ORACLE_SID=${orasid}
sqlplus / as sysdba <<EOF
create spfile from pfile='${homepath}/dbs/init${orasid}.ora';
startup nomount
alter system set db_unique_name=${orasid}_dg scope=spfile;
alter system set log_archive_config='DG_CONFIG=(${orasid},${orasid}_dg)' scope=spfile;
alter system set log_archive_dest_1 = 'LOCATION=/u01/arch VALID_FOR=(ALL_LOGFILES,ALL_ROLES) DB_UNIQUE_NAME=${orasid}_dg' scope=spfile;
alter system set log_archive_dest_2 = 'SERVICE=${orasid} ASYNC VALID_FOR=(ONLINE_LOGFILES,PRIMARY_ROLE) DB_UNIQUE_NAME=${orasid}' scope=spfile;
alter system set fal_server=${orasid} scope=spfile;
alter system set fal_client=${orasid}_dg scope=spfile;
alter system set dg_broker_start=true;
shutdown abort
startup nomount
exit;
EOF

echo "0  18  *  *  * /home/oracle/del_arch.sh >/dev/null" | crontab -
cat <<EOFP > /home/oracle/del_arch.sh
#!/bin/sh
source /home/oracle/.bash_profile
sqlplus -silent "/ as sysdba">/home/oracle/delete_arch.sh <<EOF
set heading off;
set pagesize 0;
set term off;
set feedback off;
select 'rm -f '||name from v\\\$archived_log  where DELETED='NO' and APPLIED='YES';
exit;
EOF
sh /home/oracle/delete_arch.sh
rman target / <<EOF
crosscheck archivelog all;
delete noprompt expired archivelog all;
exit;
EOF
EOFP
chmod a+x /home/oracle/del_arch.sh
chown oracle:dba /home/oracle/del_arch.sh
lsnrctl stop
lsnrctl start
EOFGG

# config scripts for start recover
cat <<EOFGG > /home/oracle/tgt2.sh
source /home/oracle/.bash_profile
export ORACLE_SID=${orasid}
sqlplus / as sysdba <<EOF
alter database open;
alter database recover managed standby database using current logfile disconnect from session;
exit;
EOF
EOFGG

# scp files to standby
su - oracle -c "cd ${homepath}/dbs;scp -r init${orasid}.ora orapw${orasid} @${target_ip}:${homepath}/dbs"
su - oracle -c "cd ${homepath}/network/admin;scp -r listener.ora tnsnames.ora sqlnet.ora ${target_ip}:${homepath}/network/admin/"
su - oracle -c "ssh ${target_ip} sed -i \"s/${source_ip}/${target_ip}/g\" ${homepath}/network/admin/listener.ora"
su - oracle -c "ssh ${target_ip} sed -i \"s/${orasid}_DGMGRL/${orasid}_dg_DGMGRL/g\" ${homepath}/network/admin/listener.ora"
su - oracle -c "scp -r /home/oracle/.bash_profile @${target_ip}:/home/oracle/"
su - oracle -c "ssh ${target_ip} sed -i \"s#rdbms/\${ORACLE_SID}#rdbms/\${ORACLE_SID}_dg#g\" /home/oracle/.bash_profile"
su - oracle -c "cd /home/oracle/;scp -r tgt.sh tgt2.sh ${target_ip}:/home/oracle/;ssh ${target_ip} chmod a+x /home/oracle/tgt*.sh"

# execute script for set parameter of standby
echo "======================================="
echo -e "${info}配置备库Spfile参数..."
echo "======================================="
su - oracle -c "ssh ${target_ip} /home/oracle/tgt.sh" > /dev/null 2>&1

echo "======================================="
echo -e "${info}克隆目标库为物理备库..."
echo "======================================="
su - oracle -c "source /home/oracle/.bash_profile;rman target 'sys/oracle'@${orasid} auxiliary 'sys/oracle'@${orasid}_dg nocatalog <<EOF
duplicate target database for standby from active database nofilenamecheck dorecover;
quit;
EOF"

# execute duplicate database on standby database
echo "======================================="
echo -e "${info}开启备库同步..."
echo "======================================="
su - oracle -c "ssh ${target_ip} /home/oracle/tgt2.sh" > /dev/null 2>&1

su - oracle -c "cd ${homepath}/sqlplus/admin;scp -r glogin.sql ${target_ip}:${homepath}/sqlplus/admin/"

# set archivelog delete policy
su - oracle -c "source /home/oracle/.bash_profile;rman target / <<EOF
df glibc-headers
quit;
EOF"

# remove tmporary scripts
cd /home/oracle/
rm -f tgt2.sh  tgt.sh
su - oracle -c "ssh ${target_ip} rm -f /home/oracle/tgt*.sh"

# Configure DG broker
echo "======================================="
echo -e "${info}配置DG broker..."
echo "======================================="
su - oracle -c "source /home/oracle/.bash_profile;dgmgrl <<EOF
connect sys/oracle@${orasid}
create configuration '${orasid}cfg' as primary database is '${orasid}' connect identifier is '${orasid}';
add database '${orasid}_dg' as connect identifier is '${orasid}_dg';
ENABLE configuration;
enable database '${orasid}';
enable database '${orasid}_dg';
quit; 
EOF"
if [ $? -eq 0 ];then
    echo "======================================="
    echo -e "${info}DG broker配置成功！"
    echo "======================================="
else
    echo "======================================="
    echo -e "${error}DG broker配置失败！"
    echo "======================================="
fi
}

remove_oracle_files()
{
echo -e "${warning}接下来的操作会让Oracle变得不可用！"
echo -e "${warning}按任意键开始运行...输入Ctrl+c退出脚本"
OLDCONFIG=`stty -g`
stty -icanon -echo min 1 time 0
dd count=1 2>/dev/null
stty ${OLDCONFIG}
cd /usr/local/bin
rm -f coraenv oraenv dbhome
cd /etc
rm -f oraInst.loc oratab
cd /opt 
rm -rf ORCLfmap
cd /u01
rm -rf app
delete_soft
}

# Initialization step
action=$1
[ -z $1 ] && action=install_option
case "$action" in
    install_option)
        install_option
    ;;
    install_softonly)
        install_softonly
    ;;
    dg_install)
        dg_install
    ;;
    check_hugepage)
        check_hugepage
    ;;
    remove_oracle_files)
        remove_oracle_files
    ;;
    *)
        echo -e "${error}Usage: ./`basename $0` [install_db|install_db_soft|dg_install]"
    ;;
esac
