#Detect if Login Schedule created by enrollment client exists. This is necessary for machines that were imaged with Windows 2004 and are missing this scheduled task. Upgrades to Windows 20H2+ do not restore the task.
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
    $task = Get-ScheduledTask -TaskName 'Login Schedule created by enrollment client' -ErrorAction SilentlyContinue -TaskPath "\Microsoft\Windows\EnterpriseMgmt\$enrollment\"
    If ($null -eq $task) {
        Write-Host 'No task'
        exit 1
    }
    else {
        Write-Host 'Found task'
        exit 0
    }
}  
catch {
    $errMsg = $_.Exception.Message
    Write-Error $errMsg
    exit 1
}



