# Remediation Script

$registryPath = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\WindowsUpdate\Orchestrator"
$valueName = "ScanBeforeInitialLogonAllowed"
$valueData = 1

New-ItemProperty -Path $registryPath -Name $valueName -Value $valueData -PropertyType DWORD -Force
