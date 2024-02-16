# Скачивание и установка файла
$url = "https://go.microsoft.com/fwlink/?linkid=2249006"
$destinationFolder = "C:\distrib"
$destinationPath = Join-Path -Path $destinationFolder -ChildPath "msodbcsql.msi"

if (-not (Test-Path -Path $destinationFolder)) {
    New-Item -ItemType Directory -Path $destinationFolder | Out-Null
}

Invoke-WebRequest -Uri $url -OutFile $destinationPath
Write-Host "Файл msodbcsql.msi успешно скачан в $destinationPath"

Start-Process "msiexec.exe" -ArgumentList "/i `"$destinationPath`" /quiet" -Wait
Write-Host "Установка msodbcsql.msi завершена"

# Создание правила в брандмауэре
New-NetFirewallRule -DisplayName "MSSQL Zabbix" -Direction Inbound -Protocol TCP -LocalPort 1433 -Action Allow -Enabled True
Write-Host "Правило брандмауэра 'MSSQL Zabbix' для порта TCP 1433 создано успешно."

# Подключение к SQL Server
$serverName = "localhost" # Или ваше значение
$login = Read-Host "Введите логин для подключения к SQL Server"
$password = Read-Host "Введите пароль для подключения к SQL Server" -AsSecureString

function ConvertTo-PlainText {
    param ([Security.SecureString]$securePassword)
    $bstr = [Runtime.InteropServices.Marshal]::SecureStringToBSTR($securePassword)
    try {
        return [Runtime.InteropServices.Marshal]::PtrToStringBSTR($bstr)
    } finally {
        [Runtime.InteropServices.Marshal]::ZeroFreeBSTR($bstr)
    }
}

$plainPassword = ConvertTo-PlainText -securePassword $password

$sqlConnectionString = "Server=$serverName;Database=master;User ID=$login;Password=$plainPassword;"

try {
    $sqlConnection = New-Object System.Data.SqlClient.SqlConnection $sqlConnectionString
    $sqlConnection.Open()

    # Создание пользователя и настройка прав
    $zbxMonitorPassword = Read-Host "Введите пароль для нового пользователя zbx_monitor" -AsSecureString
    $zbxMonitorPasswordPlainText = ConvertTo-PlainText -securePassword $zbxMonitorPassword

    $sqlCommands = @"
USE [master];
CREATE LOGIN zbx_monitor WITH PASSWORD = N'$zbxMonitorPasswordPlainText', CHECK_EXPIRATION=OFF, CHECK_POLICY=OFF;
GRANT VIEW SERVER STATE TO zbx_monitor;
USE [msdb];
CREATE USER zbx_monitor FOR LOGIN zbx_monitor;
ALTER USER zbx_monitor WITH DEFAULT_SCHEMA=[dbo];
GRANT SELECT ON OBJECT::msdb.dbo.sysjobs TO zbx_monitor;
GRANT SELECT ON OBJECT::msdb.dbo.sysjobservers TO zbx_monitor;
GRANT SELECT ON OBJECT::msdb.dbo.sysjobactivity TO zbx_monitor;
GRANT EXECUTE ON OBJECT::msdb.dbo.agent_datetime TO zbx_monitor;
"@

    $command = $sqlConnection.CreateCommand()
    $command.CommandText = $sqlCommands
    $command.ExecuteNonQuery()

    Write-Host "Пользователь zbx_monitor создан, права и разрешение на просмотр состояния сервера назначены успешно."
} catch {
    Write-Error "Ошибка при выполнении операций в SQL Server: $_"
} finally {
    if ($sqlConnection -and $sqlConnection.State -eq 'Open') {
        $sqlConnection.Close()
    }
}
