USE msdb;
GO

-- Добавляем новое задание
DECLARE @jobId BINARY(16);
EXEC sp_add_job
    @job_name = N'_Indexes_with_high_usage_costs', 
    @enabled = 1, 
    @notify_level_eventlog = 0, 
    @notify_level_email = 2, 
    @notify_level_netsend = 2, 
    @notify_level_page = 2, 
    @delete_level = 0, 
    @description = N'Задание для анализа индексов с высокими издержками при использовании.', 
    @category_name = N'[Uncategorized (Local)]', 
    @owner_login_name = N'sa', 
    @job_id = @jobId OUTPUT;

-- Добавляем шаг к заданию
EXEC sp_add_jobstep
    @job_id = @jobId, 
    @step_name = N'Step 1', 
    @subsystem = N'TSQL', 
    @command = N'IF OBJECT_ID(''tempdb..#TempMaintenanceCost'') IS NOT NULL DROP TABLE #TempMaintenanceCost;
TRUNCATE TABLE [zabbix_demo].[dbo].[Indexes_with_high_usage_costs];

SELECT TOP 1
       [Maintenance cost]  = (user_updates + system_updates),
       [Retrieval usage] = (user_seeks + user_scans + user_lookups),
       DatabaseName = DB_NAME(),
       TableName = OBJECT_NAME(s.[object_id]),
       IndexName = i.name
INTO #TempMaintenanceCost
FROM   sys.dm_db_index_usage_stats s
INNER JOIN sys.indexes i ON  s.[object_id] = i.[object_id]
   AND s.index_id = i.index_id
WHERE s.database_id = DB_ID()
   AND OBJECTPROPERTY(s.[object_id], ''IsMsShipped'') = 0
   AND (user_updates + system_updates) > 0
   AND s.[object_id] = -999;

EXEC sp_MSForEachDB    ''USE [?];
INSERT INTO #TempMaintenanceCost
SELECT TOP 10
       [Maintenance cost]  = (user_updates + system_updates),
       [Retrieval usage] = (user_seeks + user_scans + user_lookups),
       DatabaseName = DB_NAME(),
       TableName = OBJECT_NAME(s.[object_id]),
       IndexName = i.name
FROM   sys.dm_db_index_usage_stats s
INNER JOIN sys.indexes i ON  s.[object_id] = i.[object_id]
   AND s.index_id = i.index_id
WHERE s.database_id = DB_ID()
   AND i.name IS NOT NULL
   AND OBJECTPROPERTY(s.[object_id], ''''IsMsShipped'''') = 0
   AND (user_updates + system_updates) > 0
ORDER BY [Maintenance cost]  DESC;
'';

INSERT INTO [zabbix_demo].[dbo].[Indexes_with_high_usage_costs]
SELECT TOP 100 * FROM #TempMaintenanceCost
ORDER BY [Maintenance cost]  DESC;

DROP TABLE #TempMaintenanceCost;', 
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

