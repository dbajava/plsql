#!/bin/bash
####################################################
#
#  Script: Daily Basis report for DBA
#   1 - Instance Status
#       2 - Alert log errors check
#       3 - RMAN backup report
#   4 - Log shipping process report
#  PARAMETER: 1 - ORACLE SID 2 - PRIMARY HOSTNAME 3 - PRIMARY LOG SHIPPING FILE 4 - STANDBY HOSTNAME 5 - STANDBY REFRESH LOG FILE
#  Example:  ./daily_check.sh ONDEMAND qsxsaas74 /home/oracle/scripts/ship_archive_logs.log 10.107.36.75 /home/oracle/scripts/refresh_standby.log
#  Version: 1.0
#  Version Control:
#  1.0 - creation - Igor Laguardia - 16/06/15
###################################################
. ~/.bash_profile
export PATH=$PATH:/home/oracle/scripts:/home/oracle/scripts/sendEmail
export ORACLE_SID=$1
#STARTING REPORT WITH DATABASE CHECKS
echo exit | sqlplus -s "/ as sysdba" @/home/oracle/scripts/daily.sql
PRIMARY=$2
#PRIMARY DATABASE LOG SHIPPING FILE
SHIPFILE=$3
#STANDBY DATABASE HOSTNAME
STANDBY=$4
#Refresh file path on Standby Server
REFRFILE=$5
REPORT=/tmp/rpt_day.html
head -n -2 /tmp/dailyrpt.log > $REPORT
SUBJ="DAILY REPORT $ORACLE_SID"
printf "<br><br><br><td style='padding:0in 0in 0in 0in'><h2 align=center style='text-align:center'>LOG SHIPPING REPORT<o:p></o:p></h2></td><br><br>" >> $REPORT
#printf "LOG SHIPPING REPORT\n  " >> $REPORT
touch /tmp/report_logship.log
#Checking if shipping log file was updated on last 20min
SHP=/tmp/report_logship.log
NOW="$(date +"%s")"
FMOD="$(stat --printf="%Y" $SHIPFILE)"
SECDIFF=$(( ${NOW} - ${FMOD} ))
MINDIFF=$(( ${SECDIFF} / 60 ))
printf "<BR><BR><hr><BR><BR>" >> $REPORT
printf "<br><br><br><td style='padding:0in 0in 0in 0in'><h2 align=center style='text-align:center'>ALERT LOG REPORT<o:p></o:p></h2></td><br>" >> $REPORT
rm -rf $SHP
#ALERT LOG CHECK
TMP_ALR=/tmp/alr.log
TMP_ERRORS=/tmp/eralr.log
MSG=/tmp/erro_alert.log
SUBJ="DAILY REPORT $ORACLE_SID"
adrci exec="set home diag/rdbms/ondemand/ONDEMAND; SHOW ALERT -P \\\"originating_timestamp > systimestamp-1\\\"" -term >$TMP_ALR
cat $TMP_ALR |grep -i "ora-">$TMP_ERRORS
if [ `ls -l $TMP_ERRORS | awk '{print $5}'` -eq 0 ]
then
#no errors found on alert.log
printf "<BR><BR><font color="green"><b>NO ERRORS ON ALERT_$ORACLE_SID.LOG FILE </b></font><font color="black"><BR><BR>SERVER: $HOSTNAME <BR> DATABASE:$ORACLE_SID <BR><BR><br></font>" > $MSG
cat $MSG >> $REPORT
printf "<tr></body></html>">> $REPORT
else
#errors found on alert.log
DPATH=`$ORACLE_HOME/bin/sqlplus -s "/ as sysdba" <<!EOF
set pages 0
set lines 160
set verify off
set feedback off
select replace(value,'?','$ORACLE_HOME')
from v\\\$parameter
where name = 'background_dump_dest';
!EOF
`
printf "<b><BR><font color="red"><b>ORA- ERROR ON ALERT_$ORACLE_SID.LOG <BR></b></font>" > $MSG
printf "<b><font color="blue"><b>Alert log and traces can be found on server $HOSTNAME under the path $DPATH</b></font><br><BR>" >> $MSG
printf "<b><font color="black"><b>Error Summary:</b></font><BR>" >> $MSG
printf "<font color="black">" >> $MSG
cat $MSG >> $REPORT
FORMAT_ERROR="$(awk '{print $0"<BR>"}' $TMP_ERRORS)"
echo $FORMAT_ERROR >> $REPORT
printf "<tr></font></body></html>">> $REPORT
$SUBJ="DAILY REPORT $ORACLE_SID - ALERT ERROR!!!"
fi
ATT_ALERT=/tmp/alert_"$ORACLE_SID".log
awk '{printf "%s\r\n", $0}' $TMP_ALR >$ATT_ALERT
#Listener check
TMP_LSNR=/tmp/lsnr.log
TMP_LSNRERRORS=/tmp/lsnrerr.log
TNS=/tmp/erro_tns.log
printf "<br><br><br><td style='padding:0in 0in 0in 0in'><h2 align=center style='text-align:center'>TNS LISTENER REPORT<o:p></o:p></h2></td><br>" >> $REPORT
adrci exec="set home diag/tnslsnr/10_18DB3/listener; SHOW ALERT -P \\\"originating_timestamp > systimestamp-1\\\"" -term >$TMP_LSNR
cat $TMP_LSNR |grep -i "tns-">$TMP_LSNRERRORS
if [ `ls -l $TMP_LSNRERRORS | awk '{print $5}'` -eq 0 ]
then
printf "<BR><BR><font color="green"><b>NO ERRORS ON TNS Listener file for Database $ORACLE_SID.</b></font>" > $TNS
cat $TNS >> $REPORT
printf "<tr></body></html>">> $REPORT
else
printf "<b><BR><font color="red"><b>ORA- ERROR ON TNS Listener file for Database $ORACLE_SID <BR></b></font>" > $TNS
printf "<b><font color="black"><b>Error Summary:</b></font><BR>" >> $TNS
printf "<font color="black">" >> $TNS
cat $TNS >> $REPORT
FORMAT_ERROR="$(awk '{print $0"<BR>"}' $TMP_LSNRERRORS)"
echo $FORMAT_ERROR >> $REPORT
printf "<tr></font></body></html>">> $REPORT
fi
sendEmail -f sender@boston.mail -t tomail@smille.com -m "Check attached report: rpt_day.html !" -u "$SUBJ" -a $REPORT $ATT_ALERT -s 22.33.44.24:25
rm $MSG
rm $REPORT
rm $TMP_ERRORS
rm $TMP_ALR
rm $ATT_ALERT
