#Detect if Login Schedule created by enrollment client exists. This is necessary for machines that were imaged with Windows 2004 and are missing this scheduled task. Upgrades to Windows 20H2+ do not restore the task.
try{
    #Find EnrollmentID
    $enrollment = Get-ChildItem -Path HKLM:\Software\Microsoft\Enrollments -Recurse -ErrorAction SilentlyContinue |
    ForEach-Object {
        if((Get-ItemProperty -Path $_.PsPath) -match "DeviceEnroller") { 
            $_.PsPath 
        }
    }
    $enrollment = $enrollment.Substring($enrollment.IndexOf('\DeviceEnroller')-36, 36)
    $task = Get-ScheduledTask -TaskName 'Login Schedule created by enrollment client' -ErrorAction SilentlyContinue -TaskPath "\Microsoft\Windows\EnterpriseMgmt\$enrollment\"
        If($null -eq $task){
            Write-Host 'No task'
            exit 1
        }
        else {
            Write-Host 'Found task'
            exit 0
        }
}  
catch{
    $errMsg = $_.Exception.Message
    Write-Error $errMsg
    exit 1
}