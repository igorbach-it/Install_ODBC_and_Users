function ConvertTo-PlainText {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory=$true)]
        [Security.SecureString]$securePassword
    )
    $bstr = [Runtime.InteropServices.Marshal]::SecureStringToBSTR($securePassword)
    try {
        [Runtime.InteropServices.Marshal]::PtrToStringBSTR($bstr)
    }
    finally {
        [Runtime.InteropServices.Marshal]::ZeroFreeBSTR($bstr)
    }
}

# Определение основных переменных и создание подключения
$serverName = "localhost"
$login = Read-Host "Введите логин для подключения к SQL Server"
$password = Read-Host "Введите пароль для подключения к SQL Server" -AsSecureString
$plainPassword = ConvertTo-PlainText -securePassword $password
$masterConnectionString = "Server=$serverName;Database=master;User ID=$login;Password=$plainPassword;"

try {
    $masterConnection = New-Object System.Data.SqlClient.SqlConnection $masterConnectionString
    $masterConnection.Open()
    $createCommand = $masterConnection.CreateCommand()
    $createCommand.CommandText = "CREATE DATABASE zabbix_demo;"
    $createCommand.ExecuteNonQuery()
    $masterConnection.Close()

    # Переход к выполнению команд в созданной базе данных
    $dbConnectionString = "Server=$serverName;Database=zabbix_demo;User ID=$login;Password=$plainPassword;"
    $dbConnection = New-Object System.Data.SqlClient.SqlConnection $dbConnectionString
    $dbConnection.Open()

    $tableAndUserCommands = @(     
        "CREATE TABLE TOP_CPU_1 (
            id INT IDENTITY(1,1) PRIMARY KEY,
            period DATETIME,
            percent_elapsed_time FLOAT,
            percent_worker_time FLOAT,
            elapsed_time BIGINT,
            worker_time BIGINT,
            query_plan XML,
            text NVARCHAR(MAX),
            name NVARCHAR(MAX),
            creation_time DATETIME,
            execution_count BIGINT,
            total_worker_time BIGINT,
            total_physical_reads BIGINT,
            total_logical_reads BIGINT,
            total_elapsed_time BIGINT,
            total_rows BIGINT,
            dbid INT
        );",
        "CREATE TABLE Indexes_with_high_usage_costs (
            Maintenance_cost FLOAT,
            Retrieval_usage FLOAT,
            DatabaseName NVARCHAR(255),
            TableName NVARCHAR(255),
            IndexName NVARCHAR(255)
        );",
        "CREATE USER zbx_monitor FOR LOGIN zbx_monitor;",
        "ALTER ROLE db_owner ADD MEMBER zbx_monitor;"
    )

    foreach ($commandText in $tableAndUserCommands) {
        $dbCommand = $dbConnection.CreateCommand()
        $dbCommand.CommandText = $commandText
        $dbCommand.ExecuteNonQuery()
    }

# Интеграция выполнения SQL скриптов из файлов с разделением по GO
$sqlFiles = @("_query_TOP_CPU_.sql", "_Indexes_with_high_usage_costs.sql", "_CLEAN_WAITS.sql")
foreach ($file in $sqlFiles) {
    $filePath = Join-Path -Path $PSScriptRoot -ChildPath $file
    if (Test-Path $filePath) {
        $scriptContent = Get-Content -Path $filePath -Raw
        # Разделение содержимого файла по "GO", игнорируя строки, состоящие только из пробельных символов
        $scriptBlocks = [regex]::Split($scriptContent, '^\s*GO\s*$', [System.Text.RegularExpressions.RegexOptions]::IgnoreCase -bor [System.Text.RegularExpressions.RegexOptions]::Multiline)
        foreach ($scriptBlock in $scriptBlocks) {
            if (![string]::IsNullOrWhiteSpace($scriptBlock)) {
                try {
                    $command = $dbConnection.CreateCommand()
                    $command.CommandText = $scriptBlock
                    $command.ExecuteNonQuery()
                } catch {
                    Write-Error "Ошибка при выполнении блока SQL скрипта: $_"
                }
            }
        }
        Write-Host "SQL скрипт '$file' успешно выполнен."
    } else {
        Write-Warning "Файл '$file' не найден."
    }
}
   # Закрытие подключения к базе данных
} catch {
    Write-Error "Ошибка при выполнении операций в SQL Server: $_"
} finally {
    if ($dbConnection -and $dbConnection.State -eq 'Open') {
        $dbConnection.Close()
    }
    if ($masterConnection -and $masterConnection.State -eq 'Open') {
        $masterConnection.Close()
    }
}