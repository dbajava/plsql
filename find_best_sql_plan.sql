set serveroutput on
DECLARE
    p_sql_id VARCHAR2 (30) := '0g5mspcxshaf3'; -- ADD THE SQL_ID HERE
    sql_id varchar(30);
    plan_has varchar(40);
    times date;
    cpu number(15);
    io number(15);
    cost number(15);
    points number(1):=0;
    winner_cpu number(15);
    winner_io number(15);
    winner_cost number(15);
    winner_plan_has varchar(40);
    winner_points number(1):=0;
    CURSOR C1 IS select DISTINCT SQL_ID,PLAN_HASH_VALUE,TIMESTAMP,SUM(COST) cost,SUM(CPU_COST) cpu_cost,SUM(IO_COST) io_cost
    from dba_hist_sql_plan where sql_id=p_sql_id GROUP BY SQL_ID,PLAN_HASH_VALUE,TIMESTAMP ORDER BY 1; 
    prim number(1):=1;
BEGIN
  DBMS_OUTPUT.put_line ('LOOKING FOR BEST EXECUTION PLAN FOR QUERY:'||p_sql_id);
  FOR I IN C1 LOOP 
	points:=0;
    if prim=1 then
        winner_cpu:=i.cpu_cost;
        winner_cost:=i.cost;
        winner_io:=i.io_cost;
        winner_plan_has:=i.PLAN_HASH_VALUE;
        prim:=2;
    else    
    if i.cpu_cost<winner_cpu then
        winner_cpu:=i.cpu_cost;
        points:=points+1;
     end if;
    if i.io_cost<winner_io then
        winner_io:=i.io_cost;
         points:=points+1;
    end if;
    if i.cost<winner_cost then
        winner_cost:=i.cost;
        points:=points+1;
    end if;
    if points>winner_points then
        winner_plan_has:=i.PLAN_HASH_VALUE;
        winner_points:=points;
    end if;     
    end if;
  END LOOP;
  DBMS_OUTPUT.put_line('BEST EXECUTION PLAN IS: '||winner_plan_has||' COST: '||winner_cost||' IO: '||winner_io||' CPU: '||winner_cpu);
END;

