try {
    #Find EnrollmentID
    
    # Define the directory path
    $directoryPath = "C:\Windows\System32\Tasks\Microsoft\Windows\EnterpriseMgmt"

    # Get the list of subdirectories
    $subDirectories = Get-ChildItem -Path $directoryPath -Directory

    # Initialize the enrollment variable
    $enrollment = $null

    # Regex pattern to match a GUID
    $guidPattern = "^[{(]?[0-9A-Fa-f]{8}-([0-9A-Fa-f]{4}-){3}[0-9A-Fa-f]{12}[)}]?$"

    # Loop through each subdirectory
    foreach ($dir in $subDirectories) {
        if ($dir.Name -match $guidPattern) {
            $enrollment = $dir.Name
            break
        }
    }

    # Output the variable to the console
    if ($null -ne $enrollment) {
        Write-Output "Enrollment: $enrollment"
    }
    else {
        Write-Output "No GUID formatted directory found."
    }
    #21H1 builds have /c /lf switches - 2004 fails when using /lf. /c seems to work fine
    $ST_A = New-ScheduledTaskAction -Execute "%windir%\system32\deviceenroller.exe" -Argument "/o $enrollment /c"
    $ST_T = New-ScheduledTaskTrigger -AtLogOn
    $ST_S = New-ScheduledTaskSettingsSet -ExecutionTimeLimit 01:00:00 -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries -DontStopOnIdleEnd
    $ST_P = New-ScheduledTaskPrincipal -GroupId "BUILTIN\Users" -RunLevel Highest
    Register-ScheduledTask -TaskName "Login Schedule created by enrollment client" -Action $ST_A -Trigger $ST_T -Settings $ST_S -Principal $ST_P -TaskPath "\Microsoft\Windows\EnterpriseMgmt\$enrollment\"
    exit 0
}
catch {
    $errMsg = $_.Exception.Message
    Write-Error $errMsg
    exit 1
}
