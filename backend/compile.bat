@echo off
setlocal enabledelayedexpansion

set "CLASSPATH_FILE=%~dp0cp.txt"
set "SRC=%~dp0src\main\java\com\example\evstation\api\ev_user_mobile\dto\SwapVerifyRequestDTO.java"
set "OUT=%~dp0build\classes\java\main"

set "CP="
for /f "usebackq delims=" %%f in ("%~dp0cp.txt") do (
    if "%%f" neq "" (
        if exist "%%f" (
            set "CP=!CP!;%%f"
        )
    )
)

echo Compiling %SRC%
echo Classpath entries: !CP:~1!

"C:\Program Files\Java\jdk-25\bin\javac.exe" -version

echo.
echo Compiling...
"C:\Program Files\Java\jdk-25\bin\javac.exe" -cp "%~dp0build\classes\java\main" -d "%~dp0build\classes\java\main" "%SRC%"
if errorlevel 1 (
    echo FAILED
) else (
    echo SUCCESS
)
