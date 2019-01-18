#!/bin/bash
# install Oracle 11gR2 for linux 
# date 2017.07.05 by xb

#define shell color
red='\033[0;31m'
green='\033[0;32m'
yellow='\033[0;33m'
plain='\033[0m'

SYSCTL=/etc/sysctl.conf
LIMITS=/etc/security/limits.conf
PAM=/etc/pam.d/login
PROFILE=/etc/profile
BASH_PROFILE=/home/oracle/.bash_profile

[[ $EUID -ne 0 ]] && echo -e "${red} Error: This script must be run as root! ${plain}" && exit 1

check_rpm()
{
    count=0
    arr=( binutils-2* compat-libstdc++-33* elfutils-libelf-0.* elfutils-libelf-devel-0.* gcc-4.* gcc-c++-4* glibc-2.* glibc-common-2.* glibc-devel-2.* glibc-headers-2* kernel-headers-2.* ksh-* libaio-0.* libaio-devel-0.* libgcc-4.* libgomp-4.* libstdc++-4.* libstdc++-devel-* make-* sysstat-* )
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
        exit 1
        echo -e "${red}yum install completed,please restart install operation!${plain}"
    else
        echo -e "${green}++++++++++++++++CHECK PASS!+++++++++++++++++++++${plain}"
    fi
    count=0
}


## Ctrl+c
Press_Start()
{
    clear
    echo -e "###################################################"
    echo -e "#######           汇总信息              ###########"
    echo -e "软件安装目录: ${red}${softdir}${plain}"
    echo -e "Oracle用户密码: ${red}${oraclepw}${plain}"
    echo -e "Oracle Base目录: ${red}${oraclepath}${plain}"
    echo -e "Oracle SID: ${red}${orasid}${plain}"
    echo -e "###################################################"
    echo  ""
    echo -e "${green}Press any key to start...or Press Ctrl+c to cancel${plain}"
    OLDCONFIG=`stty -g`
    stty -icanon -echo min 1 time 0
    dd count=1 2>/dev/null
    stty ${OLDCONFIG}
}

init_para()
{
    sfdir=$(cd `dirname $0`; pwd)
    echo -e "${yellow}please input database software directory (default:${plain} ${red}${sfdir}${plain}${yellow}): ${plain}"
    read softdir
    if [ -z $softdir ];then
        softdir=$sfdir
    fi
    
    
    #Define oracle password
    echo -e "${yellow}please input oracle's user passwd (default:${plain} ${red}oracle${plain}${yellow}): ${plain}"
    read oraclepw
    if [ -z $oraclepw ];then
        oraclepw=oracle
    fi
    
    #define oracle install directory
    echo -e "${yellow}please input oracle install PATH(default:${plain} ${red}/u01/app/oracle${plain}${yellow}): ${plain}"
    read oraclepath
    if [ -z $oraclepath ];then
        oraclepath=/u01/app/oracle
    fi
    
    #define oracle_sid
    echo -e "${yellow}please input oracle_sid (default:${plain} ${red}orcl${plain}${yellow}): ${plain}"
    read orasid
    if [ -z $orasid ];then
        orasid=orcl
    fi
    
}

#check oracle install software
unzip_soft()
{
    sfdir=$(cd `dirname $0`; pwd)
    for file in "p13390677_112040_Linux-x86-64_1of7.zip" "p13390677_112040_Linux-x86-64_2of7.zip" "p27734982_112040_Linux-x86-64.zip" "p6880880_112000_Linux-x86-64.zip"
    do
        if [ ! -f ${softdir}/${file} ];then
            echo -e "${red} File ${plain} ${yellow}${file} ${plain} ${red}not exist,please put it under directory \"${softdir}\" . ${plain}" && exit 1
        fi
    done
    
    cd ${softdir}
    if [ ! -d ${softdir}/database ];then
        unzip p13390677_112040_Linux-x86-64_1of7.zip && unzip p13390677_112040_Linux-x86-64_2of7.zip
    fi
    if [ ! -d ${softdir}/OPatch ];then
        unzip p6880880_112000_Linux-x86-64.zip
    fi
    if [ ! -d ${softdir}/27734982 ];then
        unzip p27734982_112040_Linux-x86-64.zip
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
        echo -e "${green} oracle's password updated successfully  --- OK! ${plain}"
    else
        echo -e "${red} oracle's password set faild.   --- NO!${plain}"
    fi
}


# set kernel param
kernel()
{
    if [[ `grep "net.core.wmem_max" $SYSCTL` = "" ]];then
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
        if [ $? -eq 0 ];then
            echo -e "${green} kernel parameters updated successfully --- OK! ${plain}"
        fi
    fi
    sysctl -p
    
    if [[ `grep "oracle soft nofile" $LIMITS` = "" ]];then
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
        if [ $? -eq 0 ];then
            echo  -e "${green} $LIMITS updated successfully ... OK! ${plain}"
        fi
    fi
    if [[ `grep "pam_limits.so" $PAM` = "" ]];then
    cat <<EOF >>$PAM
session    required     /lib/security/pam_limits.so
session    required     pam_limits.so
EOF
        if [ $? -eq 0 ];then
            echo -e "${green}  $PAM updated successfully ... OK! ${plain}"
        fi
    fi
    if [[ `grep "ulimit -n 65536" $PROFILE` = "" ]];then
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
        if [ $? -eq 0 ];then
            echo -e "${green}  $PROFILE updated successfully ... OK! ${plain}"
        fi
    fi
    if [[ `grep "export ORACLE_SID" $BASH_PROFILE` = "" ]];then
    cat <<EOF >> $BASH_PROFILE
export ORACLE_BASE=$1
export ORACLE_HOME=\$ORACLE_BASE/product/11.2.0/dbhome_1
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
        if [ $? -eq 0 ];then
            echo -e "${green} $BASH_PROFILE updated successfully ... OK! ${plain}"
        fi
        . $BASH_PROFILE
    fi
}

install_db_softonly()
{
    file=${softdir}/install_db11g_softonly.rsp
    if [ ! -f ${file} ];then
        echo -e "${red} File ${plain} ${yellow}${file} ${plain} ${red}not exist,please put it under directory \"${softdir}\" . ${plain}" && exit 1
    fi
    su - oracle -c "cd ${softdir}/database/;./runInstaller -silent -waitforcompletion -responseFile ${file}"
    $oraclepath/../oraInventory/orainstRoot.sh
    $oraclepath/product/11.2.0/dbhome_1/root.sh -silent
    if [ $? -eq 0 ];then
        echo -e "${green} database software only installed successfully ... OK! ${plain}"
    fi
}

install_db()
{
    file=${softdir}/install_db11g.rsp
    if [ ! -f ${file} ];then
        echo -e "${red} File ${plain} ${yellow}${file} ${plain} ${red}not exist,please put it under directory \"${softdir}\" . ${plain}" && exit 1
    fi
    export path=$1
    export homepath=$1/product/11.2.0/dbhome_1
    export sid=$2
    total_mem=`free -m|grep Mem|awk '{print $2}'`
    sga_mem=`echo "$total_mem*0.45"|bc|awk -F . '{print $1}'`
    cd ${softdir}
    if [ -f ${file}.bak ];then
        rm -f ${file} && cp ${file}.bak ${file}
    else
        cp ${file} ${file}.bak
    fi
    sed -i "s:\${ORACLE_HOME}:$homepath:g" ${file}
    sed -i "s:\${ORACLE_BASE}:$path:g" ${file}
    sed -i 's/\${ORACLE_SID}/'$sid'/g' ${file}
    sed -i 's/\${MEMORY_SIEZ}/'$sga_mem'/g' ${file}
    su - oracle -c "cd ${softdir}/database/;./runInstaller -silent -waitforcompletion -responseFile ${file}"
    $oraclepath/../oraInventory/orainstRoot.sh
    $oraclepath/product/11.2.0/dbhome_1/root.sh -silent
    if [ $? -eq 0 ];then
        echo -e "${green} database  installed successfully ... OK! ${plain}"
    fi
    rm -f ${file} && mv ${file}.bak ${file}
}

set_param()
{
    sqlfile=${softdir}/redo.sql
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
@$sqlfile
EOF"
    ### config Oracle autostart
    sed -i 's/\:N$/:Y/g' /etc/oratab
    if [[ `grep "lsnrctl start" /etc/rc.local` = "" ]];then
        echo 'su - oracle -c "lsnrctl start"' >> /etc/rc.local
        echo 'su - oracle -c "dbstart"' >> /etc/rc.local
    fi
}

patch()
{
su - oracle -c "source /home/oracle/.bash_profile;sqlplus / as sysdba <<EOF
shutdown immediate;
exit;
EOF"
    su - oracle -c "source /home/oracle/.bash_profile;lsnrctl stop;emctl stop dbconsole"
    export path=$1
    export homepath=$1/product/11.2.0/dbhome_1
    export softdir=$2
    cd $homepath
    if [ -d OPatch.bkp ];then
        rm -rf OPatch.bkp
        mv OPatch OPatch.bkp
    else
        mv OPatch OPatch.bkp
    fi
    cp -r ${softdir}/OPatch . && chown -R oracle:dba OPatch
cat <<EOF >> sqlplus/admin/glogin.sql
set linesize 300
set pagesize 999
define _editor='vi'
set sqlprompt "_user'@'_connect_identifier> "
EOF
    su - oracle -c "cd ${softdir}/27734982;source /home/oracle/.bash_profile;opatch apply -silent -ocmrf ${softdir}/file.rsp"
    su - oracle -c "source /home/oracle/.bash_profile;lsnrctl start"
}

patch_pri()
{
su - oracle -c "source /home/oracle/.bash_profile;sqlplus / as sysdba <<EOF
startup;
@?/rdbms/admin/catbundle.sql psu apply
@?/rdbms/admin/utlrp.sql
exit;
EOF"
}

rlwrap()
{
    export softdir=$1
    cd $softdir
    tar -zxvf rlwrap-0.42.tar.gz
    cd rlwrap*
    yum install readline* libtermcap-devel* -y
    ./configure
    make && make install
    cp ${softdir}/wordfile_11gR2.txt /home/oracle/
    chown oracle:dba /home/oracle/wordfile_11gR2.txt
    if [[ `grep "alias sqlplus" $BASH_PROFILE` = "" ]];then
cat <<EOF >> /home/oracle/.bash_profile
alias sqlplus='rlwrap -D2 -irc -b'\''"@(){}[],+=&^%#;|\'\'' -f /home/oracle/wordfile_11gR2.txt ${ORACLE_HOME}/bin/sqlplus'
alias rman='rlwrap -D2 -irc -b'\''"@(){}[],+=&^%#;|\'\'' ${ORACLE_HOME}/bin/rman'
alias asmcmd='rlwrap -D2 -irc -b'\''"@(){}[],+=&^%#;|\'\'' ${ORACLE_HOME}/bin/asmcmd'
alias dgmgrl='rlwrap -D2 -irc -b'\''"@(){}[],+=&^%#;|\'\'' ${ORACLE_HOME}/bin/dgmgrl'
alias ss='sqlplus / as sysdba'
EOF
    fi
}

uninstall()
{
su - oracle -c "source /home/oracle/.bash_profile;sqlplus / as sysdba <<EOF
shutdown immediate;
exit;
EOF"
    ORADIR=`su - oracle -c "source /home/oracle/.bash_profile;echo $ORACLE_BASE"`
    su - oracle -c "source /home/oracle/.bash_profile;lsnrctl stop"
    su - oracle -c "cd $ORADIR/../..;rm -rf app/"
    su - oracle -c "cd /usr/local/bin;rm -f coraenv dbhome oraenv;rm -f /etc/oratab /etc/oraInst.loc"
    sfdir=$(cd `dirname $0`; pwd)
    rm -rf ${softdir}/database ${sfdir}/27734982 ${sfdir}/PatchSearch.xml ${sfdir}/OPatch
    userdel oracle
    groupdel dba
    groupdel oinstall
    rm -rf /home/oracle
}


#execute functions above
pre-install()
{
    check_rpm
    init_para
    Press_Start
    adduser $oraclepw
    kernel $oraclepath $orasid
    mkdir -p $oraclepath && chown -R oracle:oinstall $oraclepath && chmod -R 755 $oraclepath
    unzip_soft
    chown -R oracle:oinstall ${softdir}/database/
    chown -R oracle:oinstall ${softdir}/27734982/
    chown -R oracle:oinstall ${softdir}/OPatch/
    chown -R oracle:oinstall /u01
    chmod -R 777 /tmp
    echo -e "${green} Oracle install pre-setting finish! ${plain}"
}


# Initialization step
action=$1
[ -z $1 ] && action=install
case "$action" in
    install_db)
        pre-install
        install_db $oraclepath $orasid
        patch $oraclepath $softdir
        patch_pri
        set_param
        rlwrap $softdir
    ;;
    install_db_softonly)
        pre-install
        install_db_softonly
        patch $oraclepath $softdir
        rlwrap $softdir
    ;;
    uninstall)
        uninstall
    ;;
    unzip_soft)
        unzip_soft
    ;;
    check_rpm)
        check_rpm
    ;;
    patch)
        patch $oraclepath $softdir
    ;;
    *)
        echo -e "${red}Usage: ./`basename $0` [install_db|install_db_softonly|uninstall]${plain}"
    ;;
esac
