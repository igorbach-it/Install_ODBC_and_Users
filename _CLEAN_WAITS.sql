USE msdb;
GO

-- Добавляем новое задание
DECLARE @jobId BINARY(16);
EXEC sp_add_job
    @job_name = N'_CLEAN_WAITS', 
    @enabled = 1, 
    @notify_level_eventlog = 0, 
    @notify_level_email = 2, 
    @notify_level_netsend = 2, 
    @notify_level_page = 2, 
    @delete_level = 0, 
    @description = N'Задание для очистки статистики ожиданий.', 
    @category_name = N'[Uncategorized (Local)]', 
    @owner_login_name = N'sa', 
    @job_id = @jobId OUTPUT;

-- Добавляем шаг к заданию
EXEC sp_add_jobstep
    @job_id = @jobId, 
    @step_name = N'Step 1', 
    @subsystem = N'TSQL', 
    @command = N'DBCC SQLPERF (N''sys.dm_os_wait_stats'', CLEAR);', 
    @retry_attempts = 0, 
    @retry_interval = 0, 
    @on_success_action = 1, 
    @on_fail_action = 2, 
    @database_name = N'master';

-- Создаем расписание
DECLARE @scheduleId INT;
EXEC sp_add_jobschedule
    @job_id = @jobId, 
    @name = N'Every 30 Minutes Daily', 
    @enabled = 1, 
    @freq_type = 4, -- Daily
    @freq_interval = 1, -- Every day
    @freq_subday_type = 4, -- Minute
    @freq_subday_interval = 30, -- Every 30 minutes
    @freq_relative_interval = 0, 
    @freq_recurrence_factor = 0, 
    @active_start_date = 20230101, -- Adjust the start date as necessary
    @active_end_date = 99991231, 
    @active_start_time = 0, 
    @active_end_time = 235959, 
    @schedule_id = @scheduleId OUTPUT;

-- Связываем задание с расписанием
EXEC sp_attach_schedule
   @job_id = @jobId, 
   @schedule_id = @scheduleId;

-- Привязываем задание к локальному серверу заданий
EXEC sp_add_jobserver
    @job_id = @jobId,
    @server_name = N'(local)';

-- Включаем задание
EXEC sp_update_job
    @job_id = @jobId,
    @enabled = 1;

GO
