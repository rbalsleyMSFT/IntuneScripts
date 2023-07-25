try{
    #Find EnrollmentID
    $enrollment = Get-ChildItem -Path HKLM:\Software\Microsoft\Enrollments -Recurse -ErrorAction SilentlyContinue |
    ForEach-Object {
        if((Get-ItemProperty -Path $_.PsPath) -match "DeviceEnroller") { 
            $_.PsPath 
        }
    }
    $enrollment = $enrollment.Substring($enrollment.IndexOf('\DeviceEnroller')-36, 36)
    #21H1 builds have /c /lf switches - 2004 fails when using /lf. /c seems to work fine
    $ST_A = New-ScheduledTaskAction -Execute "%windir%\system32\deviceenroller.exe" -Argument "/o $enrollment /c"
    $ST_T = New-ScheduledTaskTrigger -AtLogOn
    $ST_S = New-ScheduledTaskSettingsSet -ExecutionTimeLimit 01:00:00 -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries -DontStopOnIdleEnd
    $ST_P = New-ScheduledTaskPrincipal -GroupId "BUILTIN\Users" -RunLevel Highest
    Register-ScheduledTask -TaskName "Login Schedule created by enrollment client" -Action $ST_A -Trigger $ST_T -Settings $ST_S -Principal $ST_P -TaskPath "\Microsoft\Windows\EnterpriseMgmt\$enrollment\"
    exit 0
}
catch{
    $errMsg = $_.Exception.Message
    Write-Error $errMsg
    exit 1
}
