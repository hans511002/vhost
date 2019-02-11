@echo off
REM  
REM  Author hans
REM 

setlocal
chcp 65001
   
rem ----- Execute The Requested Command ---------------------------------------
         
rem Guess INSTALLER_HOME if not defined
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
call "%INSTALLER_HOME%\conf\installer-env.cmd"

if not "%JAVA_HOME%" == "" goto okJDKHome
if exist "%JAVA_HOME%\bin\java" goto okJDKHome
rem if not /i "%PROCESSOR_ARCHITECTURE%"=="AMD64" goto JDK32
set JAVA_HOME=%INSTALLER_HOME%\bin\jdk\win\jre
rem :JDK32
rem set JAVA_HOME=%INSTALLER_HOME%\bin\jdk\win\jre32
:okJDKHome
:execCmd
set _EXECJAVA=%JAVA_HOME%\bin\java

set JAVAMAIN=com.sobey.jcg.sobeyhive.install.Installer 


set CMD=%1
if "%CMD%" == "" set CMD=start

:execInsCmd
shift /1
echo on
"%_EXECJAVA%" -Xmx512m "%DEBUG%" -Dfile.encoding=UTF-8 -cp "%CLASSPATH%" %JAVAMAIN% -%CMD%  %1 %2 %3 %4 %5 %6 %7 
set RES_VAL=%errorlevel%
goto end


endlocal

:end
exit %RES_VAL%