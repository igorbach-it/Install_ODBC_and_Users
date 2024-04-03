USE msdb;
GO

-- Добавляем новое задание
DECLARE @jobId BINARY(16);
EXEC sp_add_job
    @job_name = N'_query_TOP_CPU_1', 
    @enabled = 1, 
    @notify_level_eventlog = 0, 
    @notify_level_email = 2, 
    @notify_level_netsend = 2, 
    @notify_level_page = 2, 
    @delete_level = 0, 
    @description = N'Задание для анализа TOP CPU запросов.', 
    @category_name = N'[Uncategorized (Local)]', 
    @owner_login_name = N'sa', 
    @job_id = @jobId OUTPUT;

-- Добавляем шаг к заданию
EXEC sp_add_jobstep
    @job_id = @jobId, 
    @step_name = N'Step 1', 
    @subsystem = N'TSQL', 
    @command = N'set transaction isolation level read uncommitted;

IF OBJECT_ID(''tempdb..#T1'') IS NOT NULL
	DROP TABLE #T1;
IF OBJECT_ID(''tempdb..#T2'') IS NOT NULL
	DROP TABLE #T2;
TRUNCATE TABLE [zabbix_demo].[dbo].[TOP_CPU_1];

SELECT
SUM(qs.max_elapsed_time) as elapsed_time,
SUM(qs.total_worker_time) as worker_time
into #T1 FROM (
       select top 100000
       *
       from
       sys.dm_exec_query_stats qs
       where qs.last_execution_time > (CURRENT_TIMESTAMP - ''01:00:00.000'')
       order by qs.last_execution_time desc
) as qs;
 

select top 10000
(qs.max_elapsed_time) as elapsed_time,
(qs.total_worker_time) as worker_time,
qp.query_plan,
st.text,
dtb.name,
qs.*,
st.dbid
INTO #T2
FROM
sys.dm_exec_query_stats qs
CROSS APPLY sys.dm_exec_query_plan(qs.plan_handle) qp
CROSS APPLY sys.dm_exec_sql_text(qs.sql_handle) st
left outer join sys.databases as dtb on st.dbid = dtb.database_id
where qs.last_execution_time > (CURRENT_TIMESTAMP - ''01:00:00.000'')
order by qs.last_execution_time desc;

INSERT INTO [zabbix_demo].[dbo].[TOP_CPU_1]
select top 100
	GETDATE() as period,
	(T2.elapsed_time*100/T1.elapsed_time) as percent_elapsed_time,
	(T2.worker_time*100/T1.worker_time) as percent_worker_time,
	T2.elapsed_time,
	T2.worker_time,
	T2.query_plan,
	T2.text,
	T2.name,
	T2.creation_time,
	T2.execution_count,
	T2.total_worker_time,
	T2.total_physical_reads,
	T2.total_logical_reads,
	T2.total_elapsed_time,
	T2.total_rows,
	T2.dbid
from
#T2 as T2
INNER JOIN #T1 as T1
ON 1=1
order by T2.worker_time desc;

SELECT 
        [id]
      ,[period]
      ,[percent_elapsed_time]
      ,[percent_worker_time]
      ,[elapsed_time]
      ,[worker_time]
      ,[query_plan]
      ,[text]
      ,[name]
      ,[creation_time]
      ,[execution_count]
      ,[total_worker_time]
      ,[total_physical_reads]
      ,[total_logical_reads]
      ,[total_elapsed_time]
      ,[total_rows]
      ,[dbid]
  FROM [zabbix_demo].[dbo].[TOP_CPU_1]', 
    @retry_attempts = 5, 
    @retry_interval = 5, 
    @on_success_action = 1, 
    @on_fail_action = 2, 
    @database_name = N'zabbix_demo';

-- Создаем расписание
DECLARE @scheduleId INT;
EXEC sp_add_jobschedule
    @job_id = @jobId, 
    @name = N'Daily Every 5 Minutes', 
    @enabled = 1, 
    @freq_type = 4, 
    @freq_interval = 1, 
    @freq_subday_type = 4, 
    @freq_subday_interval = 5, 
    @freq_relative_interval = 0, 
    @freq_recurrence_factor = 0, 
    @active_start_date = 20230101, 
    @active_end_date = 99991231, 
    @active_start_time = 0, 
    @active_end_time = 235959, 
    @schedule_id = @scheduleId OUTPUT;

-- Связываем задание с расписанием
EXEC sp_attach_schedule
   @job_id = @jobId, 
   @schedule_id = @scheduleId;

-- Привязываем задание к локальному серверу заданий (используется имя сервера по умолчанию)
EXEC sp_add_jobserver
    @job_id = @jobId, 
    @server_name = N'(local)';

-- Включаем задание
EXEC sp_update_job
    @job_id = @jobId, 
    @enabled = 1;

GO