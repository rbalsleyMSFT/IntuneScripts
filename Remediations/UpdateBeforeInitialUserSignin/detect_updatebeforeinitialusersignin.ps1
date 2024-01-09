# Detection Script
$LogFile = 'C:\Windows\temp\ScanBeforeInitialLogonAllowed.txt'
function WriteLog($LogText) {
    #Check if log file exists and if it does, check if the file size is larger than 1MB. If it is, delete it. 
    if (Test-Path $LogFile) {
        $FileSize = (Get-Item $LogFile).length
        if ($FileSize -gt 1MB) {
            Remove-Item $LogFile -Force
        }
    }
    Add-Content -path $LogFile -value "$((Get-Date).ToString()) $LogText" -Force -ErrorAction SilentlyContinue
    Write-Verbose $LogText
}
$registryPath = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\WindowsUpdate\Orchestrator"
$valueName = "ScanBeforeInitialLogonAllowed"
$expectedValue = 1

try {
    WriteLog "Running detection script"
    WriteLog "Processor Architecture is: $env:Processor_Architecture"
    WriteLog "Checking $valueName in $registryPath"
    $valueData = Get-ItemProperty -Path $registryPath -Name $valueName -ErrorAction SilentlyContinue
    WriteLog "Value is set to $valueData.$valueName"

    if ($valueData.$valueName -eq $expectedValue) {
        Write-Host "Registry value is set correctly."
        WriteLog "Registry value is set correctly."
        Exit 0
    } else {
        Write-Host "Registry value is not set correctly."
        WriteLog "Registry value is not set correctly."
        Exit 1
    }
} catch {
	$errMsg = $_.Exception.Message
    	Write-Host $errMsg
    	exit 1
}
