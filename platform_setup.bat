@echo off
setlocal
where flutter >nul 2>nul
if errorlevel 1 (
  echo Flutter was not found in PATH.
  echo Install Flutter first, then run this file again.
  exit /b 1
)
flutter create --platforms=android,ios,web --org com.cmx .
flutter pub get
echo.
echo Platform files are ready.
endlocal
