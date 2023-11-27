# Detection Script

$registryPath = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\WindowsUpdate\Orchestrator"
$valueName = "ScanBeforeInitialLogonAllowed"
$expectedValue = 1

try {
    $valueData = Get-ItemProperty -Path $registryPath -Name $valueName

    if ($valueData.$valueName -eq $expectedValue) {
        Write-Host "Registry value is set correctly."
        Exit 0 # Correct value is set, no action needed
    } else {
        Write-Host "Registry value is not set correctly."
        Exit 1 # Incorrect value is set, remediation needed
    }
} catch {
    Write-Host "Registry key or value not found."
    Exit 1 # Key or value not found, remediation needed
}
