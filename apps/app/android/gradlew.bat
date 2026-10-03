@echo off
setlocal EnableExtensions
set "GRADLE_VERSION=8.13"
set "GRADLE_SHA256=20f1b1176237254a6fc204d8434196fa11a4cfb387567519c61556e8710aed78"
if not defined GRADLE_USER_HOME set "GRADLE_USER_HOME=%USERPROFILE%\.gradle"
set "DIST_ROOT=%GRADLE_USER_HOME%\wrapper\dists\tshk-gradle-%GRADLE_VERSION%"
set "GRADLE_BIN=%DIST_ROOT%\gradle-%GRADLE_VERSION%\bin\gradle.bat"
if exist "%GRADLE_BIN%" goto run_gradle

if not exist "%DIST_ROOT%" mkdir "%DIST_ROOT%"
set "TEMP_DIR=%DIST_ROOT%\.install-%RANDOM%"
mkdir "%TEMP_DIR%"
set "ZIP_FILE=%TEMP_DIR%\gradle-%GRADLE_VERSION%-bin.zip"
set "URL=https://services.gradle.org/distributions/gradle-%GRADLE_VERSION%-bin.zip"
powershell -NoProfile -ExecutionPolicy Bypass -Command "$ProgressPreference='SilentlyContinue'; Invoke-WebRequest -Uri '%URL%' -OutFile '%ZIP_FILE%'"
if errorlevel 1 goto download_failed
for /f %%H in ('powershell -NoProfile -Command "(Get-FileHash -Algorithm SHA256 '%ZIP_FILE%').Hash.ToLower()"') do set "ACTUAL_SHA256=%%H"
if /I not "%ACTUAL_SHA256%"=="%GRADLE_SHA256%" goto checksum_failed
powershell -NoProfile -ExecutionPolicy Bypass -Command "Expand-Archive -LiteralPath '%ZIP_FILE%' -DestinationPath '%TEMP_DIR%' -Force"
if errorlevel 1 goto download_failed
if exist "%DIST_ROOT%\gradle-%GRADLE_VERSION%" rmdir /s /q "%DIST_ROOT%\gradle-%GRADLE_VERSION%"
move "%TEMP_DIR%\gradle-%GRADLE_VERSION%" "%DIST_ROOT%\gradle-%GRADLE_VERSION%" >nul
if errorlevel 1 goto download_failed
rmdir /s /q "%TEMP_DIR%"

:run_gradle
cd /d "%~dp0"
call "%GRADLE_BIN%" %*
exit /b %ERRORLEVEL%

:download_failed
echo Failed to download or install pinned Gradle %GRADLE_VERSION%. 1>&2
exit /b 1

:checksum_failed
echo Pinned Gradle distribution checksum mismatch; refusing to execute it. 1>&2
rmdir /s /q "%TEMP_DIR%"
exit /b 1
