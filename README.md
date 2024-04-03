
# Описание

#### Скрипты должны упростить [инструкцию](https://docs.google.com/document/d/14i4RxDirN8L6Sz24kEusVP3fASQ8_RGmT9DT-bExIoQ/edit#heading=h.6rs4g4jqpkg)
## Чтобы запустился мониторинг достаточно первой части
1. Запускаем файл Install_and_add_users.ps1 через PowerShell - этот скрипт:  
* скачивает и устанавливает ODBC для связи с Zabbix  
* добавляет в брандмауэр разрешенный входящий TCP 1433 чтобы zabbix мог подключиться  
* создает пользователя zbx_monitor с веденным вами паролем, с помощью этой учетной записи идет подключение

### После выполнения первого скрипта переходим в настройку zabbix по [инструкции](https://docs.google.com/document/d/14i4RxDirN8L6Sz24kEusVP3fASQ8_RGmT9DT-bExIoQ/edit?disco=AAABK5s5xYc) и не забыть переделать рег. операции по [инструкции](https://docs.google.com/document/d/14i4RxDirN8L6Sz24kEusVP3fASQ8_RGmT9DT-bExIoQ/edit?disco=AAABFkqMWFI) 

## Вторая часть для подключения SSP

2. Если требуется еще сборка SSP из [инструкции](https://docs.google.com/document/d/14i4RxDirN8L6Sz24kEusVP3fASQ8_RGmT9DT-bExIoQ/edit#heading=h.q6bk6ylpalfm) то запускаем второй файл Setting_SSP_For_Zabbix6.ps1 так же через PowerShell - этот скрипт:
* создает базу zabbix_demo
* создает таблицу TOP_CPU_1 в базе zabbix_demo с нужными колонками
* создает таблицу Indexes_with_high_usage_costs в базе zabbix_demo с нужными колонками
* добавляет пользователя zbx_monitor в разрешенные этой базы
* создает задачу _query_TOP_CPU_1 из файла _query_TOP_CPU_.sql
* создает задачу _Indexes_with_high_usage_costs из файла _Indexes_with_high_usage_costs.sql
* создает задачу _CLEAN_WAITS из файла _CLEAN_WAITS.sql

После выполнения второго скрипта переходим в настройку zabbix в [инструкции](https://docs.google.com/document/d/14i4RxDirN8L6Sz24kEusVP3fASQ8_RGmT9DT-bExIoQ/edit?disco=AAABK5s5xYY)