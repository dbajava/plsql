#!/bin/bash
####################################################
#
#  Script: Weekly Basis report for DBA
#   1 - System Health Check
#       1.1 - check spfile -> create a pfile and copy it to backup folder - not needed, we do that by RMAN daily
#               1.2 - copy control file to trace and send to backup folder - not needed, we do that by RMAN daily
#               1.3 - check if redo log files are on the filesystem
#               1.4 - Buffer check(sort_area_size,buffer_cache,hit ratio in general)
#               1.5 - Tablespace size
#               1.6 - Tablespace fragmentation
#               1.7 - report datafiles location and if they are on filesystem
#               1.8 - Object reports - Object size
#               1.9 - Undo tablespace report
#               1.10 - sqlnet log verification
#               1.11 - Check number of files and size of Oracle diag directory
#       2 - File system used
#       3 - Performance check
#   4 - Invalid Objects
#   5 - Disabled Constraints check
#       6 - Disabled Triggers check
#       7 - Security check
#       8 - Archive alert log for last week
#  PARAMETER: 1 - ORACLE SID 2 - ORACLE_HOME 3 - BACKUP DESTINATION PATH
#  Example:  ./weekly_check.sh ONDEMAND $ORACLE_HOME /u02/oracle/rmanbackups
#  Version: 1.0
#  Version Control:
#  1.0 - creation - Igor Laguardia - 17/06/15
###################################################
. ~/.bash_profile
export PATH=$PATH:/home/oracle/scripts:/home/oracle/scripts/sendEmail
export ORACLE_SID=$1
export ORACLE_HOME=$2
export BKP_PATH=$3
CTRL_FILE=$3/control_file_$ORACLE_SID.trc
PFILE=$3/pfile_$ORACLE_SID.ora
#HOSTNAME=$4
SQLNET_LOG=$ORACLE_HOME/network/log/sqlnet.log

REPORT=/tmp/rpt_week_$(date +"%d_%m_%y").html
echo exit | sqlplus -s "/ as sysdba" @/home/oracle/scripts/weekly.sql
head -n -2 /tmp/weeklyrpt.log > $REPORT
#1.3
printf "<tr><br><br><center><td style='padding:0in 0in 0in 0in'><h2 align=center style='text-align:center'>REDO LOG ONLINE REPORT<o:p></o:p></h2></td><br><br></center>" >> $REPORT
REDOLST=`$ORACLE_HOME/bin/sqlplus -s "/ as sysdba" <<!EOF
set pages 0
set lines 160
set verify off
set feedback off
select member from v\\\$logfile;
!EOF
`
CONTROL=0
TMP_RDLS=`$ORACLE_HOME/bin/sqlplus -s "/ as sysdba" <<!EOF
set pages 0
set lines 160
set verify off
set feedback off
select STATUS, member||'<br>' from v\\\$logfile;
!EOF
`
MISS_REDO=/tmp/miss_rdo.tmp
REDO_REP=/tmp/rpl_rd.tmp
for f in $REDOLST
do
        if [ ! -f "$f" ]
        then
                echo "$f <br>" >> $MISS_REDO
                CONTROL=1
        fi
done
if [ $CONTROL = 1 ]
then
        printf "<b><font color="red">REDO LOG ONLINE MISSED!</font></b><br>"  > $REDO_REP
        printf "<font color="black">MISSED REDO LOG ONLINE:</font><br>"  >> $REDO_REP
        cat $MISS_REDO >> $REDO_REP
else
        printf "<tr><b><font color="green">REDO LOG ONLINE IS OKAY! ALL REDO LOG FILES ARE AVAILABLE AND ONLINE!</font></b><br>"  > $REDO_REP
        printf "<font color="black">CURRENT REDO LOG ONLINE:</font><br>"  >> $REDO_REP
        echo $TMP_RDLS >> $REDO_REP
fi
cat $REDO_REP >> $REPORT
printf "<tr><br><br><center><td style='padding:0in 0in 0in 0in'><h2 align=center style='text-align:center'>LOGS PURGE PROCESS REPORT<o:p></o:p></h2></td><br><br></center>" >> $REPORT
ALERT_REP=/tmp/alrt_rd.tmp
FOLD_TMP=/tmp/fold.tmp
# Purge ADR contents (adr_purge.sh)
printf "<font color="black">ADR DIAG FOLDERS TO BE ANALIZED:</font><br>"  > $ALERT_REP
printf "<font color="black"><b><br>"  >> $ALERT_REP
adrci exec="show homes"|grep diag >> $FOLD_TMP
sed -e 's/$/<br>/' "$FOLD_TMP" >> $ALERT_REP
printf "</b><br>"  >> $ALERT_REP
adrci exec="show homes"|grep -v : | while read file_line
do
        printf "<font color="black">INFO: adrci purging diagnostic destination: $file_line</font><br>"  >> $ALERT_REP
        printf "<font color="black">INFO: purging ALERT older than 42 days<br></font>"  >> $ALERT_REP
        adrci exec="set homepath $file_line;purge -age 60480 -type ALERT"
        printf "<font color="black">INFO: purging INCIDENT older than 42 days<br></font>"  >> $ALERT_REP
        adrci exec="set homepath $file_line;purge -age 60480 -type INCIDENT"
        printf "<font color="black">INFO: purging TRACE older than 42 days<br></font>"  >> $ALERT_REP
        adrci exec="set homepath $file_line;purge -age 60480 -type TRACE"
        printf "<font color="black">INFO: purging CDUMP older than 42 day<br></font>"  >> $ALERT_REP
        adrci exec="set homepath $file_line;purge -age 60480 -type CDUMP"
        printf "<font color="black">INFO: purging HM older than 42 days<br></font>"  >> $ALERT_REP
        adrci exec="set homepath $file_line;purge -age 60480 -type HM"
done
printf "<br><br><b><center><font color="green">ADR PURGE PROCESS SUCCESSFUL</font></center><br></b>" >> $ALERT_REP
cat $ALERT_REP >> $REPORT
printf "<tr><br><br><center><td style='padding:0in 0in 0in 0in'><h2 align=center style='text-align:center'>SQLNET LOG REPORT<o:p></o:p></h2></td><br><br></center>" >> $REPORT
SQLNET_REP=/tmp/sqlnet_rd.tmp
NOW="$(date +"%s")"
FMOD="$(stat --printf="%Y" $SQLNET_LOG)"
SECDIFF=$(( ${NOW} - ${FMOD} ))
DAYDIFF=$(( ${SECDIFF} / 60 / 60 / 24 +1))
#IF THERE IS NO UPDATE ON FILE ON LASTS 7 DAYS, JUST PRINT THAT THERE IS NO ERRORS
if [ $DAYDIFF -gt 7 ]
then
        printf "<font color="green"><b>NO ERRORS FOUND ON SQLNET.LOG ON LASTS 7 DAYS<br></font></b>"  > $SQLNET_REP
        LAST_DT=$(stat $SQLNET_LOG |grep -i modify: | cut -c9-18)
        printf "<font color="black">LAST UPDATE DATE ON SQLNET.LOG: $LAST_DT<br></font>"  >> $SQLNET_REP
else
        printf "<b><font color="red">ERRORS FOUND ON SQLNET.LOG:<br></font>"  > $SQLNET_REP
        printf "<b><font color="red">PLEASE CHECK THE FILE $SQLNET_LOG ON SERVER $HOSTNAME:<br></font>"  > $SQLNET_REP
        printf "<font color="black">LASTS LINES OF SQLNET.LOG <br></b>"  >> $SQLNET_REP
        TMP_SQLN=/tmp/sql_net_error.tmp
        tail -18 $SQLNET_LOG > $TMP_SQLN
        sed -e 's/$/<br>/' "$TMP_SQLN" >> $SQLNET_REP
fi
cat $SQLNET_REP >> $REPORT
printf "<tr><br><br><center><td style='padding:0in 0in 0in 0in'><h2 align=center style='text-align:center'>DISK SPACE REPORT<o:p></o:p></h2></td><br><br></center>" >> $REPORT

DF_RPL=/tmp/df_rpl.tmp
echo "<center><table><tr>    <th>Filesystem</th>    <th>Type</th>    <th>Size</th>    <th>Used</th>    <th>Avail</th>    <th>Use%</th>    <th>Mounted on</th>    </tr>" >$DF_RPL
df -PTh | \
sed '1d' | \
sort -n -k6 | \
awk '
{
    printf "\n\t<tr>";
    for (n = 1; n < 7; ++n)
            printf("\n\t<td>%s</td>",$n);
    printf "\n\t<td>";
    for(;n <= NF; ++n)
            printf("%s ",$n);
    printf "</td>\n\t</tr>"
}
'>>$DF_RPL
printf "</table></center>">>$DF_RPL
printf "<b><font color="black"><br>"  >> $REPORT
cat $DF_RPL >> $REPORT
printf "</font><br>"  >> $REPORT
printf "<tr></body></html>">> $REPORT

rm -rf $MISS_REDO
rm -rf $REDO_REP
rm -rf $TMP_RDLS
rm -rf $ALERT_REP
rm -rf $DF_RPL
rm -rf $SQLNET_REP
rm -rf $FOLD_TMP
rm -rf $TMP_SQLN

sendEmail -f sender@boston.mail -t tomail@smille.com -m "Check attached report!" -u "WEEKLY REPORT $ORACLE_SID" -s 10.22.22.24:25 -a $REPORT

