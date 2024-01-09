# Remediation Script
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

$registryPath = "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\WindowsUpdate\Orchestrator"
$valueName = "ScanBeforeInitialLogonAllowed"
$valueData = 1

try{
	Writelog "Running remediation script"
	Writelog "Processor Architecture is: $env:Processor_Architecture"
	Writelog "Setting $valueName to $valueData in $registryPath"
	#using reg instead of New-itemproperty because IME runs in 32 bit context 
	reg add $registryPath /v $valueName /t REG_DWORD /d $valueData /f /reg:64
	WriteLog "Checking $valueName in $registryPath"
	$regQuery = reg query $registryPath /v $valueName /reg:64
	if ($LASTEXITCODE -eq 0) {
		WriteLog "Value is set to $regQuery"
		Write-Host 'Registry value set'
		exit 0
	}
	else {
		Write-Host 'Registry value not set'
		exit 1	
	}


    WriteLog "Value is set to $regQuery"
	Write-Host 'Registry value set'
	exit 0
} catch {
	$errMsg = $_.Exception.Message
    	WriteLog $errMsg
		Write-Host $errMsg
    	exit 1
}
