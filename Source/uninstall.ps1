$App = Get-CimInstance Win32_Product | Where-Object { $_.Name -like "*RustDesk*" } | Select-Object -First 1

if ($App) {
    Start-Process -FilePath "msiexec.exe" -ArgumentList "/x $($App.IdentifyingNumber) /qn /norestart" -Wait
}

exit 0