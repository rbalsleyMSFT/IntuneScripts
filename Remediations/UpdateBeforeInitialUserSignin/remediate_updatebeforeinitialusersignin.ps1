# Remediation Script

$registryPath = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\WindowsUpdate\Orchestrator"
$valueName = "ScanBeforeInitialLogonAllowed"
$valueData = 1

try{
	New-ItemProperty -Path $registryPath -Name $valueName -Value $valueData -PropertyType DWORD -Force
	Write-Host 'Registry value set'
	exit 0
} catch {
	$errMsg = $_.Exception.Message
    	Write-Host $errMsg
    	exit 1
}
