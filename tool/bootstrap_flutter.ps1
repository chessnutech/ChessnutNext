$ErrorActionPreference = "Stop"

$root = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)
Set-Location $root

if (-not (Get-Command flutter -ErrorAction SilentlyContinue)) {
  throw "Flutter CLI was not found. Install Flutter SDK first, then rerun this script."
}

flutter create --platforms=android,ios,web,macos,windows,linux .
flutter pub get

Write-Host ""
Write-Host "Chessnut Flutter export is ready."
Write-Host "Run: flutter run"
