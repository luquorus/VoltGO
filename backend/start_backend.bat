@echo off
REM Build classpath from compiled classes + gradle cache jars
setlocal

set "BACKEND_DIR=%~dp0"
set "BUILD_DIR=%BACKEND_DIR%build\classes\java\main"
set "GC=%USERPROFILE%\.gradle\caches\modules-2\files-2.1"

REM Build classpath by scanning all JARs in gradle cache
set "CP=%BUILD_DIR%"
for /r "%GC%" %%f in (*.jar) do (
    set "CP=!CP!;%%f"
)

REM Write classpath to a file (to avoid command line length issues)
echo !CP! > "%BACKEND_DIR%cp_env.txt"

REM Find main class
set "MAIN=com.example.evstation.EvStationApplication"

echo Starting backend...
echo Main class: %MAIN%
echo Classpath entries: ~

REM Start Spring Boot using the Gradle daemon approach
REM The backend was likely running via Gradle's continuous build (--continuous)
REM Let's try running with the spring boot loader from gradle cache

"C:\Program Files\Java\jdk-25\bin\java.exe" -version
