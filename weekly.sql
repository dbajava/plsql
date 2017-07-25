@/home/oracle/scripts/set_markup.sql
SPOOL /tmp/weeklyrpt.log
SET FEEDBACK OFF
set pagesize 50000
set linesize 1200
REPHEADER PAGE CENTER '<h2>WEEKLY ORACLE REPORT</h2>' SKIP 2
select to_char(sysdate, 'dd/mm/yyyy') "DATE", INSTANCE_NAME,SUBSTR(HOST_NAME,1,INSTR(HOST_NAME,'.')-1) HOST_NAME,to_char(STARTUP_TIME, 'yyyy-mm-dd hh24:mi:ss') STARTUP_TIME, case when DATABASE_STATUS='ACTIVE' then '<span class="threshold-ok">'||DATABASE_STATUS||'</span>' when DATABASE_STATUS<>'ACTIVE' then '<span class="threshold-critical">'||DATABASE_STATUS||'</span>' end DATABASE_STATUS from  v$instance;


REPHEADER PAGE CENTER '<tr><br><br><center><h2>RMAN BACKUP WEEKLY REPORT</h2></center>' SKIP 2
select distinct DECODE(INCREMENTAL_LEVEL, 1, 'INCREMENTAL', 0,'FULL') "BACKUP_TYPE",b.OUTPUT_BYTES_DISPLAY,to_char(b.START_TIME, 'yyyy-mm-dd hh24:mi') start_time,to_char(b.end_time, 'yyyy-mm-dd hh24:mi') END_TIME, case when status='COMPLETED' then '<span class="threshold-ok">'||b.status||'</span>' when b.status<>'COMPLETED' then '<span class="threshold-critical">'||b.status||'</span>' end status from V$RMAN_BACKUP_JOB_DETAILS b,V$BACKUP_SET s where trunc(s.START_TIME)=trunc(b.START_TIME) and s.incremental_level is not null and b.input_type='DB INCR' and b.start_time > trunc(sysdate)-7 order by end_time;


REPHEADER PAGE CENTER '<tr><br><br><center><h2>TABLESPACE USAGE REPORT</h2></center>' SKIP 2
SELECT tablespace_name,to_char(max_m,'999999.99') AS "TOTAL SIZE(MB)",to_char(sum_free_m,'999999.99') AS "FREE SPACE(MB)", CASE WHEN (100 * sum_free_m / sum_m)<20 THEN '<span class="threshold-critical">'||TO_CHAR((100 * sum_free_m / sum_m),'90.99')||'% </span>' ELSE '<span class="threshold-ok">'||TO_CHAR((100 * sum_free_m / sum_m),'90.99')||'% </span>' END as pct_free FROM (SELECT tablespace_name, sum (bytes) /1024/1024 AS sum_m  FROM dba_data_files GROUP BY tablespace_name), (SELECT tablespace_name AS fs_ts_name,max (bytes) / 1024/1024 AS max_m,count (blocks) AS count_blocks,sum (bytes/1024/1024) AS sum_free_m FROM dba_free_space GROUP BY tablespace_name) WHERE tablespace_name = fs_ts_name AND tablespace_name<>'UNDOTBS1'  and (100 * sum_free_m / sum_m)<21 
union 
select '<font color="green"><b>NO TABLESPACE WITH LESS THAN 20% OF FREE SPACE</b></font>','<font color="green"><b>0</b></font>','<font color="green"><b>0</b></font>','<font color="green"><b>0</b></font>' FROM DUAL where not exists(SELECT tablespace_name,to_char(max_m,'999999.99') AS "TOTAL SIZE(MB)",to_char(sum_free_m,'999999.99') AS "FREE SPACE(MB)", CASE WHEN (100 * sum_free_m / sum_m)<20 THEN '<span class="threshold-critical">'||TO_CHAR((100 * sum_free_m / sum_m),'90.99')||'% </span>' ELSE '<span class="threshold-ok">'||TO_CHAR((100 * sum_free_m / sum_m),'90.99')||'% </span>' END as pct_free FROM (SELECT tablespace_name, sum (bytes) /1024/1024 AS sum_m  FROM dba_data_files GROUP BY tablespace_name), (SELECT tablespace_name AS fs_ts_name,max (bytes) / 1024/1024 AS max_m,count (blocks) AS count_blocks,sum (bytes/1024/1024) AS sum_free_m FROM dba_free_space GROUP BY tablespace_name) WHERE tablespace_name = fs_ts_name AND tablespace_name<>'UNDOTBS1'  and (100 * sum_free_m / sum_m)<21)
order by  4 asc;



REPHEADER PAGE CENTER '<tr><br><br><center><h2>TABLE FRAGMENTATION REPORT</h2></center>' SKIP 2
select owner,table_name,TO_CHAR(round((blocks*8)/1024,2),'9999990.99') "size (mb)" , 
                          TO_CHAR(round((num_rows*avg_row_len/1024)/1024,2),'9999990.99')   "actual_data (mb)",
                          TO_CHAR(round((round((blocks*8)/1024,2) - round((num_rows*avg_row_len/1024)/1024,2)),2),'9999990.99')   "wasted_space (mb)"
from dba_tables
where (round((blocks*8),2) > round((num_rows*avg_row_len/1024),2)) and ((round((blocks*8)/1024,2) - round((num_rows*avg_row_len/1024)/1024,2)))>30
union 
select '<font color="green"><b>NO TABLE WITH MORE THAN 30MB OF WASTED SPACE</b></font>','<font color="green"><b>0</b></font>','<font color="green"><b>0</b></font>','<font color="green"><b>0</b></font>','<font color="green"><b>0</b></font>' FROM DUAL where not exists(select owner,table_name,round((blocks*8)/1024,2) "size (mb)" , 
                            round((num_rows*avg_row_len/1024)/1024,2) "actual_data (mb)",
                            (round((blocks*8)/1024,2) - round((num_rows*avg_row_len/1024)/1024,2)) "wasted_space (mb)"
from dba_tables
where (round((blocks*8),2) > round((num_rows*avg_row_len/1024),2)) and ((round((blocks*8)/1024,2) - round((num_rows*avg_row_len/1024)/1024,2)))>30)
order by 5 desc;



REPHEADER PAGE CENTER '<tr><br><br><center><h2>DATAFILES REPORT</h2></center>' SKIP 2
SELECT  Substr(df.tablespace_name,1,20) "Tablespace Name",
        Substr(df.file_name,1,80) "File Name",
        Round(df.bytes/1024/1024,0) "Size (M)",
        decode(e.used_bytes,NULL,0,Round(e.used_bytes/1024/1024,0)) "Used (M)",
        decode(f.free_bytes,NULL,0,Round(f.free_bytes/1024/1024,0)) "Free (M)",
        decode(e.used_bytes,NULL,0,Round((e.used_bytes/df.bytes)*100,0)) "% Used",
                DECODE(DF.ONLINE_STATUS,'OFFLINE','<font color="red"><b>'||DF.ONLINE_STATUS||'</b></font>','RECOVER','<font color="red"><b>'||DF.ONLINE_STATUS||'</b></font>','<font color="green"><b>'||DF.ONLINE_STATUS||'</b></font>')				
FROM    DBA_DATA_FILES DF,
       (SELECT file_id,
               sum(bytes) used_bytes
        FROM dba_extents
        GROUP by file_id) E,
       (SELECT Max(bytes) free_bytes,
               file_id
        FROM dba_free_space
        GROUP BY file_id) f
WHERE    e.file_id (+) = df.file_id
AND      df.file_id  = f.file_id (+)
ORDER BY df.tablespace_name;




REPHEADER PAGE CENTER '<tr><br><br><center><h2>UNDO TABLESPACE REPORT</h2></center>' SKIP 2
select
( select sum(bytes)/1024/1024 from dba_data_files
where tablespace_name like 'UND%' ) allocated,
( select sum(bytes)/1024/1024 from dba_free_space
where tablespace_name like 'UND%') free,
( select sum(bytes)/1024/1024 from dba_undo_extents
where tablespace_name like 'UND%') USed
from dual;


REPHEADER PAGE CENTER '<tr><br><br><center><h2>BUFFER CACHE REPORT</h2></center>' SKIP 2
COLUMN size_for_estimate          FORMAT 999,999,999,999 heading 'Cache Size (MB)'
COLUMN buffers_for_estimate       FORMAT 999,999,999 heading 'Buffers'
COLUMN estd_physical_read_factor  FORMAT 990.90 heading 'Estd Phys|Read Factor'
COLUMN estd_physical_reads        FORMAT 999,999,999,999 heading 'Estd Phys| Reads'
SELECT size_for_estimate, buffers_for_estimate, estd_physical_read_factor,estd_physical_reads FROM V$DB_CACHE_ADVICE WHERE name = 'DEFAULT'   AND block_size = (SELECT value FROM V$PARAMETER WHERE name = 'db_block_size') AND advice_status = 'ON';

REPHEADER PAGE CENTER '<tr><br><br><center><h2>INVALID OBJECTS REPORT</h2></center>' SKIP 2
SELECT owner,
       object_type,
       object_name,
       '<font color="red">'||status||'</font>'
FROM   dba_objects
WHERE  status = 'INVALID'
ORDER BY owner, object_type, object_name;

REPHEADER PAGE CENTER '<tr><br><br><center><h2>DISABLED CONSTRAINTS REPORT</h2></center>' SKIP 2
 SELECT    cons.owner, cons.CONSTRAINT_NAME,
             DECODE(cons.CONSTRAINT_TYPE,'C','CHECK','P','PRIMARY KEY','R','FOREIGN KEY') CONSTRAINT_TYPE,  '<font color="red">'||cons.status||'</font>'
      FROM dba_cons_columns conscol,
           dba_CONSTRAINTS cons
      WHERE cons.constraint_name = conscol.constraint_name
      and cons.STATUS ='DISABLED'
          AND CONS.OWNER NOT IN ('SYSTEM','SYS','SYSMAN','SCOTT','DBSMNP','CTXSYS','MDSYS','XDB','WMSYS','EXFSYS','OLAPSYS')
      order by cons.CONSTRAINT_name,conscol.position;
REPHEADER PAGE CENTER '<tr><br><br><center><h2>DISABLED TRIGGERS REPORT</h2>' SKIP 2
SELECT OWNER,TRIGGER_NAME,TABLE_NAME,STATUS FROM DBA_TRIGGERS WHERE STATUS='DISABLED' AND OWNER NOT IN ('SYSTEM','SYS','SYSMAN','SCOTT','DBSMNP','CTXSYS','MDSYS','XDB','WMSYS','EXFSYS','OLAPSYS');

REPHEADER PAGE CENTER '<tr><br><br><center><h2>AUDIT REPORT</h2></center>' SKIP 2
select * from dba_role_privs where granted_role='DBA';
SPOOL OFF
