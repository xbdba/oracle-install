#=================================================================#
#   System Required:  Redhat 6,7                                  #
#   Description: One click Install Oracle DB 11g|18c              #
#   Author: Xiong Bin                                             #
#   If any question contact email:xiongbin@tfzq.com               #
#=================================================================#

## list rpm to install
rpm6_11g=(
binutils-2*
compat-libcap1-1.10*
compat-libstdc++-33*
gcc-4*
gcc-c++-4*
glibc-2*
glibc-devel-2*
ksh
libaio-0.3*
libaio-devel-0.3*
libgcc-4*
libstdc++-4*
libstdc++-devel-4*
make-3*
sysstat-*
)

rpm7_11g=(
binutils-2*
compat-libcap1-1.10*
compat-libstdc++-33*
gcc-4*
gcc-c++-4*
glibc-2*
glibc-devel-2*
ksh
libaio-0.3*
libaio-devel-0.3*
libgcc-4*
libstdc++-4*
libstdc++-devel-4*
make-3*
sysstat-*
libXi-1*
libXtst-*
)

rpm6_18c=(
bc*
binutils-2*
compat-libcap1*
compat-libstdc++*
e2fsprogs-1*
e2fsprogs-libs-1*
glibc-2*
glibc-devel-2*
ksh
libaio-0*
libaio-devel-0*
libX11-1*
libXau-1*
libXi-1*
libXtst-1*
libXrender*
libgcc-4*
libstdc++-4*
libstdc++-devel-4*
libxcb-1*
make-3*
nfs-utils-1*
net-tools-2*
smartmontools-*
sysstat-*
)

rpm7_18c=(
bc*
binutils-2*
compat-libcap1*
compat-libstdc++*
glibc-2*
glibc-devel-2*
ksh
libaio-0*
libaio-devel-0*
libX11-1*
libXau-1*
libXi-1*
libXtst-1*
libXrender-0*
libgcc-4*
libstdc++-4*
libstdc++-devel-4*
libxcb-1*
make-3*
nfs-utils-1*
net-tools-2*
python-2*
python-configshell-1*
python-rtslib-2*
python-six-1*
smartmontools-6*
sysstat-10.*
targetcli-2.1*
)

#define shell color
red='\033[0;31m'
green='\033[0;32m'
yellow='\033[0;33m'
plain='\033[0m'

SYSCTL="/etc/sysctl.conf"
LIMITS="/etc/security/limits.conf"
PAM="/etc/pam.d/login"
PROFILE="/etc/profile"
BASH_PROFILE="/home/oracle/.bash_profile"

## Test and Real environment yum repo server,inclue install software
testip="192.168.146.104"
realip="172.19.16.205"

softdir="/home/soft"

mkdir -p /home/soft

# Make sure only root can run script
[[ $EUID -ne 0 ]] && echo -e "${red} Error: This script must be run as root! ${plain}" && exit 1


# Get version
getversion(){
    if [[ -s /etc/redhat-release ]]; then
        grep -oE  "[0-9.]+" /etc/redhat-release
    else
        grep -oE  "[0-9.]+" /etc/issue
    fi
}

redhatversion(){
    local code=$1
    local version="$(getversion)"
    local main_ver=${version%%.*}
    if [ "$main_ver" == "$code" ]; then
        return 0
    else
        return 1
    fi
}

# check environment is TEST or Real
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

# Disable selinux
disable_selinux(){
    if [ -s /etc/selinux/config ] && grep 'SELINUX=enforcing' /etc/selinux/config; then
        sed -i 's/SELINUX=enforcing/SELINUX=disabled/g' /etc/selinux/config
        setenforce 0
    fi
}

# set yum repo
config_yum()
{   
    if check_env ${testip} 0;then
        url=http://$testip
    elif check_env ${realip} 0;then
        url=http://$realip
    else
        echo "Please check network!"
        exit 1
    fi

    if redhatversion 6; then
        cat <<EOF > /etc/yum.repos.d/dvd.repo 
[redhat]
name=redhat
baseurl=$url/redhat/6/
enable=1
gpgcheck=0

[epel]
name=epel
baseurl=$url/epel/6/
enable=1
gpgcheck=0
EOF
    else 
        cat <<EOF > /etc/yum.repos.d/dvd.repo 
[redhat]
name=redhat
baseurl=$url/redhat/7/
enable=1
gpgcheck=0

[epel]
name=epel
baseurl=$url/epel/7/
enable=1
gpgcheck=0
EOF
    fi

}

check_rpm()
{
    count=0
    if redhatversion 6;then
        if [[ $oraversion == '11g' ]];then
            arr=(${rpm6_11g[@]})
        else
            arr=(${rpm6_18c[@]})
        fi
    else 
        if [[ $oraversion == '11g' ]];then
            arr=(${rpm7_11g[@]})
        else
            arr=(${rpm7_18c[@]})
        fi
    fi
    echo
    echo "======================================="
    echo -e "${yellow}Now checking rpm,please wait...${plain} "
    echo "======================================="
    echo
    len=${#arr[@]}
    for((i=0;i<len;i++));
    do
        char=${arr[$i]}
        rpm -qa | grep "^$char"
        if [ $? != 0 ] ; then
            error[$count]=${arr[$i]}
            count=$(( $count + 1 ))
            echo -e "${red}++++++++the ${arr[$i]}^is not installed+++++++++++${plain}"
        fi
    done
    if [ $count -gt 0 ];then
        echo -e "${red}You have $count rpm are not installed.${plain}"
        echo -e "${red}the not installed rpm is:${plain}"
        len1=${#error[@]}
        for((ii=0;ii<len1;ii++));
        do
            echo -e "${red}${error[$ii]}^${plain}"
            yum install -y ${error[$ii]}
        done
        echo
        echo "======================================="
        echo -e "${red}Yum install completed,please restart install operation!${plain} "
        echo "======================================="
        echo
        exit 1
    else
        echo
        echo "======================================="
        echo -e "${green}++++++++++++++++CHECK PASS!+++++++++++++++++++++${plain} "
        echo "======================================="
        echo
    fi
    count=0
}


## Ctrl+c
Press_Start()
{
    clear
    echo -e "#########################################################"
    echo -e "########           Summary Info              ############"
    echo -e "Oracle Home Dir            : ${red}${oraclepath}/product/${dbhome_str}/dbhome_1${plain}"
    echo -e "Oracle User Password       : ${red}${oraclepw}${plain}"
    echo -e "Oracle Base Dir            : ${red}${oraclepath}${plain}"
    echo -e "Oracle SID                 : ${red}${orasid}${plain}"
    echo -e "Oracle Version             : ${red}${oraversion}${plain}"
    echo -e "#########################################################"
    echo  ""
    echo -e "${green}Press any key to start...or Press Ctrl+c to cancel${plain}"
    OLDCONFIG=`stty -g`
    stty -icanon -echo min 1 time 0
    dd count=1 2>/dev/null
    stty ${OLDCONFIG}
}

init_para()
{  
    #Define oracle password
    echo -e "${yellow}Please input oracle's user password: ${plain}"
    read -p "(Default password: oracle):" oraclepw
    if [ -z $oraclepw ];then
        oraclepw=oracle
    fi
    
    #define oracle install directory
    echo -e "${yellow}Please input oracle install PATH: ${plain}"
    read -p "(Default path: /u01/app/oracle):" oraclepath
    if [ -z $oraclepath ];then
        oraclepath=/u01/app/oracle
    fi
    
    #define oracle version
    echo -e "${yellow}Please input oracle version to install [${red}11g${plain} or ${red}18c${plain}]: ${plain}"
    read -p "(Default version: 11g):" oraversion
    if [ -z $oraversion ];then
        oraversion=11g
    fi


    #define oracle_sid
    echo -e "${yellow}Please input oracle_sid: ${plain}"
    read -p "(Default oracle_sid: orcl):" orasid
    if [ -z $orasid ];then
        orasid=orcl
    fi
    
    #set dbhome
    if [[ $oraversion == '11g' ]];then
        dbhome_str=11.2.0
    else
        dbhome_str=18.0.0
        echo -e "${yellow}Because you choose 18c,so input pdbname: ${plain}"
        read -p "(Default pdbname: pdb1):" pdbsid
        if [ -z $pdbsid ];then
            pdbsid=pdb1
        fi
    fi


}


download_soft()
{
    cd ${softdir}
    echo
    echo "======================================="
    echo -e "${yellow}Now downloading software,please wait...${plain} "
    echo "======================================="
    echo
    wget -e robots=off -R "index.html*" -r -np -nd $url/soft/${oraversion}/
}



#check oracle install software
unzip_soft()
{
    cd ${softdir}
    echo
    echo "======================================="
    echo -e "${yellow}Now unziping zip files,please wait...${plain}"
    echo "======================================="
    echo

    for i in `ls p*.zip`;
    do 
        unzip -q $i
    done

    if [[ $oraversion == '18c' ]];then
        mkdir -p $oraclepath/product/${dbhome_str}/dbhome_1
        cd $oraclepath/product/${dbhome_str}/dbhome_1
        unzip -q ${softdir}/LINUX.X64_180000_db_home.zip
        chown -R oracle:oinstall $oraclepath
    fi
}

#add oracle user and oracle group
adduser()
{
    if [[ `grep "oracle" /etc/passwd` != "" ]];then
        userdel -r oracle
    fi
    if [[ `grep "oinstall" /etc/group` = "" ]];then
        groupadd oinstall
    fi
    if [[ `grep "dba" /etc/group` = "" ]];then
        groupadd dba
    fi
    useradd oracle -g oinstall -G dba && echo $1 |passwd oracle --stdin
    if [ $? -eq 0 ];then
        echo -e "${green}oracle's password updated successfully  --- OK! ${plain}"
    else
        echo -e "${red}oracle's password set faild.   --- NO!${plain}"
    fi
}


# set kernel param
kernel()
{
    # /etc/sysctl.conf
    if [[ $oraversion == '11g' ]];then

        sed -i '/kernel.shmall = 4294967296/,+9d' $SYSCTL

        cat <<EOF >>$SYSCTL
kernel.shmall = 4294967296
kernel.shmmni = 4096
kernel.sem = 250 32000 100 128
fs.file-max = 6815744
net.ipv4.ip_local_port_range = 9000 65500
net.core.rmem_default = 262144
net.core.wmem_default = 262144
net.core.rmem_max = 4194304
net.core.wmem_max = 1048576
fs.aio-max-nr = 1048576
EOF
    else
        sed -i '/fs.file-max = 6815744/,+13d' $SYSCTL

        cat <<EOF >>$SYSCTL
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
    fi
    sysctl -p
    
    # /etc/security/limits.conf
    if [[ $oraversion == '11g' ]];then

        sed -i '/* soft nproc 4096/,+7d' $LIMITS

        cat <<EOF >> $LIMITS
* soft nproc 4096
* hard nproc 16384
* soft nofile 16384
* hard nofile 65536
oracle soft nproc 16384
oracle hard nproc 16384
oracle soft nofile 65536
oracle hard nofile 65536
EOF
    else
        sed -i '/* soft nproc 4096/,+11d' $LIMITS

        cat <<EOF >> $LIMITS
* soft nproc 4096
* hard nproc 16384
* soft nofile 16384
* hard nofile 65536
oracle soft nofile 1024
oracle hard nofile 65536
oracle soft nproc 16384
oracle hard nproc 16384
oracle soft stack 10240
oracle hard stack 32768
oracle hard memlock 134217728
oracle soft memlock 134217728
EOF
    fi

    #/etc/pam.d/login
    sed -i '/session    required     \/lib\/security\/pam_limits.so/d' $PAM
    sed -i '/session    required     pam_limits.so/d' $PAM

    cat <<EOF >>$PAM
session    required     /lib/security/pam_limits.so
session    required     pam_limits.so
EOF
    
    #/etc/profile
    sed -i '/if \[ $USER = "oracle" \];then/,+7d' $PROFILE
    
    cat <<EOF >>$PROFILE
if [ \$USER = "oracle" ];then
    if [ \$SHELL = "/bin/ksh" ];then
        ulimit -p 16384
        ulimit -n 65536
    else
        ulimit -u 16384 -n 65536
    fi
fi
EOF
    
    sed -i '/export ORACLE_TERM=xterm/,+17d;:go;1,3!{P;$!N;D};N;bgo' $BASH_PROFILE

    cat <<EOF >> $BASH_PROFILE
export ORACLE_BASE=$1
export ORACLE_HOME=\$ORACLE_BASE/product/${dbhome_str}/dbhome_1
export ORACLE_SID=$2
export ORACLE_TERM=xterm
export NLS_DATA_FORMAT="DD-MON-YYYY HH24:MI:SS"
export NLS_LANG="SIMPLIFIED CHINESE_CHINA.ZHS16GBK"
export TNS_ADMIN=\$ORACLE_HOME/network/admin
export ORA_NLS11=\$ORACLE_HOME/nls/data
export PATH=.:\${JAVA_HOME}/bin:\${PATH}:$HOME/bin:\$ORACLE_HOME/bin:\$ORACLE_HOME/OPatch
export PATH=\${PATH}:/usr/bin:/bin:/usr/bin/X11:usr/local/bin
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
umask 022
EOF
}

install_db_soft()
{
    cd ${softdir}
    if [ ! -f "install_db${oraversion}.rsp" ];then
        wget $url/soft/${oraversion}/install_db${oraversion}.rsp
    fi
    echo
    echo "======================================="
    echo -e "${yellow}Now installing db software,please wait...${plain}"
    echo "======================================="
    echo
    if [[ $oraversion == '11g' ]];then
        su - oracle -c "cd ${softdir}/database/;./runInstaller -ignoreSysPrereqs -ignorePrereq -silent -waitforcompletion -responseFile ${softdir}/install_db${oraversion}.rsp"
        $oraclepath/../oraInventory/orainstRoot.sh
        $oraclepath/product/${dbhome_str}/dbhome_1/root.sh -silent
    else
        su - oracle -c "cd $oraclepath/product/${dbhome_str}/dbhome_1;./runInstaller  -ignorePrereq -silent -waitforcompletion -responseFile ${softdir}/install_db${oraversion}.rsp"
        $oraclepath/../oraInventory/orainstRoot.sh
        $oraclepath/product/${dbhome_str}/dbhome_1/root.sh -silent
    fi

    if [ $? -eq 0 ];then
        echo
        echo "======================================="
        echo -e "${green}Database software installed successfully ... OK! ${plain}"
        echo "======================================="
        echo
    fi
}

install_dbca()
{   
    echo
    echo "======================================="
    echo -e "${yellow}Now installing db instance,please wait...${plain}"
    echo "======================================="
    echo
    if [[ $oraversion == '11g' ]];then
        su - oracle -c "source /home/oracle/.bash_profile;
            dbca -silent -createDatabase \
            -templateName General_Purpose.dbc -gdbname $orasid \
            -sid $orasid -sysPassword oracle -systemPassword oracle \
            -responseFile NO_VALUE -characterSet ZHS16GBK -memoryPercentage 45 \
            -datafileDestination "/u01/app/oracle/oradata/" \
            -emConfiguration none -redoLogFileSize 1024 "
            
    else
        su - oracle -c "source /home/oracle/.bash_profile;
            dbca -silent -createDatabase \
            -templateName General_Purpose.dbc -gdbname $orasid \
            -createAsContainerDatabase true -numberOfPDBs 1 -pdbName $pdbsid \
            -pdbAdminPassword oracle -databaseType MULTIPURPOSE \
            -sid $orasid -sysPassword oracle -systemPassword oracle \
            -responseFile NO_VALUE -characterSet ZHS16GBK -memoryPercentage 45 \
            -datafileDestination "/u01/app/oracle/oradata/" \
            -emConfiguration none -redoLogFileSize 1024 "
    fi
    su - oracle -c "source /home/oracle/.bash_profile;lsnrctl start"
}


set_param()
{
su - oracle -c "source /home/oracle/.bash_profile;sqlplus / as sysdba <<EOF
alter system set open_cursors=2000 scope=spfile sid='*';
alter system set session_cached_cursors=300 scope=spfile sid='*';
alter system set OPTIMIZER_INDEX_COST_ADJ=10 scope=spfile sid='*';
alter system set deferred_segment_creation=false scope=spfile sid='*';
alter system set SEC_CASE_SENSITIVE_LOGON =FALSE scope=both sid='*';
alter system set \"_use_adaptive_log_file_sync\"=false scope=spfile sid='*';
alter system set optimizer_index_caching=90 scope=spfile sid='*';
alter system set event='20481 trace name context forever, level 1:10949 trace name context forever,level 1' scope=spfile sid='*';
alter system set dispatchers='' scope=spfile sid='*';
alter system set audit_trail=none scope=spfile sid='*';
alter system set processes=1000 scope=spfile;
alter profile default limit PASSWORD_LIFE_TIME UNLIMITED;
exec DBMS_AUTO_TASK_ADMIN.DISABLE(client_name => 'auto space advisor',operation => NULL,window_name => NULL);
exec DBMS_AUTO_TASK_ADMIN.DISABLE(client_name => 'sql tuning advisor',operation => NULL,window_name => NULL);
shutdown immediate;
startup;
EOF"
    ### config Oracle autostart
    sed -i 's/\:N$/:Y/g' /etc/oratab
    if [[ `grep "lsnrctl start" /etc/rc.local` = "" ]];then
        echo 'su - oracle -c "lsnrctl start"' >> /etc/rc.local
        echo 'su - oracle -c "dbstart"' >> /etc/rc.local
    fi

if [[ $oraversion == '18c' ]];then
    su - oracle -c "source /home/oracle/.bash_profile;sqlplus / as sysdba <<EOF
    alter pluggable database \$pdbname open;
    alter pluggable database \$pdbname save state;
    EOF"
fi
}

patch()
{
    export path=$1
    export homepath=$1/product/${dbhome_str}/dbhome_1
    cd $homepath
    if [ -d OPatch.bkp ];then
        rm -rf OPatch.bkp
        mv OPatch OPatch.bkp
    else
        mv OPatch OPatch.bkp
    fi
    cp -r ${softdir}/OPatch . && chown -R oracle:dba OPatch

sed -i '/set linesize 300/,+10d' sqlplus/admin/glogin.sql

cat <<EOF >> sqlplus/admin/glogin.sql
set linesize 300
set pagesize 999
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
    cd $softdir
    if [ ! -f "file.rsp" ];then
        wget $url/soft/file.rsp
    fi
    echo
    echo "======================================="
    echo -e "${yellow}Now installing soft patchs,please wait...${plain}"
    echo "======================================="
    echo
    su - oracle -c "cd ${softdir}/2*;source /home/oracle/.bash_profile;opatch apply -silent -ocmrf ${softdir}/file.rsp"
}

rlwrap()
{
    cd $softdir
    if [ ! -f "rlwrap-0.42.tar.gz" ];then
        wget $url/soft/rlwrap-0.42.tar.gz
    fi
    tar -zxvf rlwrap-0.42.tar.gz
    cd rlwrap*
    echo
    echo "======================================="
    echo -e "${yellow}Now installing rlwrap,please wait...${plain}"
    echo "======================================="
    echo
    yum install readline* libtermcap-devel* -y
    ./configure
    make && make install
    if [[ `grep "alias sqlplus" $BASH_PROFILE` = "" ]];then
cat <<EOF >> /home/oracle/.bash_profile
alias sqlplus='rlwrap -D2 -irc -b'\''"@(){}[],+=&^%#;|\'\'' \${ORACLE_HOME}/bin/sqlplus'
alias rman='rlwrap -D2 -irc -b'\''"@(){}[],+=&^%#;|\'\'' \${ORACLE_HOME}/bin/rman'
alias asmcmd='rlwrap -D2 -irc -b'\''"@(){}[],+=&^%#;|\'\'' \${ORACLE_HOME}/bin/asmcmd'
alias dgmgrl='rlwrap -D2 -irc -b'\''"@(){}[],+=&^%#;|\'\'' \${ORACLE_HOME}/bin/dgmgrl'
alias ss='sqlplus / as sysdba'
EOF
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
    check_rpm
    Press_Start
    adduser $oraclepw
    kernel $oraclepath $orasid
    mkdir -p $oraclepath && chown -R oracle:oinstall $oraclepath && chmod -R 755 $oraclepath
    download_soft
    unzip_soft
    if [ -d ${softdir}/database/ ];then
        chown -R oracle:oinstall ${softdir}/database/
    fi
    chown -R oracle:oinstall ${softdir}/2*/
    chown -R oracle:oinstall ${softdir}/OPatch/
    chown -R oracle:oinstall /u01
    chmod -R 777 /tmp
    echo -e "${green}Oracle install pre-setting finish! ${plain}"
}


# Initialization step
action=$1
[ -z $1 ] && action=install
case "$action" in
    install_db)
        pre-install
        install_db_soft
        patch $oraclepath $softdir
        install_dbca
        set_param
        rlwrap $softdir
        delete_soft
    ;;
    install_db_soft)
        pre-install
        install_db_soft
        patch $oraclepath $softdir
        rlwrap $softdir
        delete_soft
    ;;
    *)
        echo -e "${red}Usage: ./`basename $0` [install_db|install_db_soft]${plain}"
    ;;
esac
