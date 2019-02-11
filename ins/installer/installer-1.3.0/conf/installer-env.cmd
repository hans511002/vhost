@echo off
REM  
REM  Author hans
REM 

set "CURRENT_DIR=%cd%"
if not "%INSTALLER_HOME%" == "" goto gotHome
set "INSTALLER_HOME=%CURRENT_DIR%"
if exist "%INSTALLER_HOME%\conf\installer-env.cmd" goto okHome
cd ..
set "INSTALLER_HOME=%cd%"
cd "%CURRENT_DIR%"
:gotHome
if exist "%INSTALLER_HOME%\conf\installer-env.cmd" goto okHome
echo The INSTALLER_HOME environment variable is not defined correctly
echo This environment variable is needed to run this program
goto end
:okHome

set INSCFGDIR=%INSTALLER_HOME%\conf

REM add the conf dir to classpath
set CLASSPATH=%INSCFGDIR%

REM make it work in the release
SET CLASSPATH=%INSTALLER_HOME%\*;%INSTALLER_HOME%\lib\*;%INSTALLER_HOME%\lib\common\*;%INSTALLER_HOME%\lib\rdbms\*;%INSTALLER_HOME%\lib\jetty\*;%INSTALLER_HOME%\lib\jetty\websocket\*;%CLASSPATH%

REM make it work for developers
REM SET CLASSPATH=%CLASSPATH%;%INSTALLER_HOME%\ebin
set DEBUG="-Xdebug -Xrunjdwp:transport=dt_socket,server=y,suspend=n,address=8000"
set DEBUG="-Da=a"
