param (
    [string]$SerialNumber,
    [string]$CsvFile,
    [switch]$RemoveFromIntune,
    [switch]$RemoveFromEntraID,
    [switch]$RemoveFromAutopilot
)

# Replace these with your app registration values
$clientId = 'YOUR CLIENT ID HERE'
$clientSecret ='YOUR CLIENT SECRET HERE'
$tenantId = 'YOUR TENANT ID HERE'

# Log files
$Logfile = "$PSScriptRoot\RemovedDevices.log"
$NotFoundFile = "$PSScriptRoot\NotFoundDevices.txt"

function WriteLog {
    param ([string]$LogText)
    Add-Content -Path $Logfile -Value "$((Get-Date).ToString()) $LogText" -Force -ErrorAction SilentlyContinue
    Write-Verbose $LogText
}

function Write-NotFoundLog {
    param ([string]$SerialNumber)
    Add-Content -Path $NotFoundFile -Value "$((Get-Date).ToString()) Device not found: $SerialNumber" -Force -ErrorAction SilentlyContinue
}

function Get-AccessToken {
    WriteLog 'Getting Access token'
    $tokenUrl = "https://login.microsoftonline.com/$tenantId/oauth2/v2.0/token"
    $body = @{
        grant_type    = "client_credentials"
        client_id     = $clientId
        client_secret = $clientSecret
        scope         = "https://graph.microsoft.com/.default"
    }

    $response = Invoke-WebRequest -Method Post -Uri $tokenUrl -ContentType "application/x-www-form-urlencoded" -Body $body
    $accessToken = (ConvertFrom-Json $response.Content).access_token
    $expiresIn = (ConvertFrom-Json $response.Content).expires_in
    $expirationTime = (Get-Date).AddSeconds($expiresIn)
    WriteLog 'Successfully obtained access token'
    WriteLog "Access token expiration date and time: $expirationTime"
    return $accessToken
}

function Get-DeviceId {
    param (
        [string]$SerialNumber,
        [string]$AccessToken
    )
    WriteLog "Getting Intune device ID for Serial Number: $SerialNumber"
    $url = "https://graph.microsoft.com/beta/deviceManagement/managedDevices?`$filter=serialNumber eq '$SerialNumber'"
    $headers = @{
        Authorization = "Bearer $AccessToken"
    }

    try {
        $response = Invoke-RestMethod -Method Get -Uri $url -Headers $headers
        if ($response.value.Count -gt 0) {
            $device = $response.value[0]
            $deviceId = $device.id
            $azureADDeviceId = $device.azureADDeviceId
            WriteLog "Found Intune device ID: $deviceId and Entra ID device ID: $azureADDeviceId for Serial Number: $SerialNumber"
            return @{
                "DeviceId" = $deviceId
                "AzureADDeviceId" = $azureADDeviceId
            }
        } else {
            WriteLog "Device not found for Serial Number: $SerialNumber"
            Write-NotFoundLog -SerialNumber $SerialNumber
            return $null
        }
    } catch {
        WriteLog "Error retrieving Intune device ID for Serial Number: $SerialNumber. Error: $_"
        return $null
    }
}

function Get-AutopilotDeviceId {
    param (
        [string]$SerialNumber,
        [string]$AccessToken
    )
    WriteLog "Getting Autopilot Device ID for Serial Number: $SerialNumber"
    $url = "https://graph.microsoft.com/beta/deviceManagement/windowsAutopilotDeviceIdentities?`$filter=contains(serialNumber,'$SerialNumber')"
    $headers = @{
        Authorization = "Bearer $AccessToken"
    }

    try {
        $response = Invoke-RestMethod -Method Get -Uri $url -Headers $headers
        if ($response.value.Count -gt 0) {
            $autopilotDeviceId = $response.value[0].id
            WriteLog "Found Autopilot Device ID: $autopilotDeviceId for Serial Number: $SerialNumber"
            return $autopilotDeviceId
        } else {
            WriteLog "Autopilot device not found for Serial Number: $SerialNumber"
            Write-NotFoundLog -SerialNumber $SerialNumber
            return $null
        }
    } catch {
        WriteLog "Error retrieving Autopilot Device ID for Serial Number: $SerialNumber. Error: $_"
        return $null
    }
}

function Remove-Device {
    param (
        [string]$DeviceId,
        [string]$Platform,
        [string]$AccessToken
    )
    $url = switch ($Platform) {
        "Intune" { "https://graph.microsoft.com/beta/deviceManagement/managedDevices/$DeviceId" }
        "EntraID" { "https://graph.microsoft.com/beta/devices?`$filter=deviceId eq '$DeviceId'" }
        "Autopilot" { "https://graph.microsoft.com/beta/deviceManagement/windowsAutopilotDeviceIdentities/$autopilotDeviceId" }
        default { $null }
    }

    if ($url -ne $null) {
        WriteLog "Removing Device ID: $DeviceId from $Platform"
        $headers = @{
            Authorization = "Bearer $AccessToken"
        }
        try {
            Invoke-RestMethod -Method Delete -Uri $url -Headers $headers
            WriteLog "Successfully removed Device ID: $DeviceId from $Platform"
        } catch {
            WriteLog "Failed to remove Device ID: $DeviceId from $Platform. Error: $_"
        }
    } else {
        WriteLog "Invalid platform specified: $Platform"
    }
}

function Invoke-SingleDeviceRemoval {
    param (
        [string]$SerialNumber
    )
    WriteLog "Processing single device removal for Serial Number: $SerialNumber"
    $AccessToken = Get-AccessToken
    $deviceIds = Get-DeviceId -SerialNumber $SerialNumber -AccessToken $AccessToken
    if ($deviceIds -ne $null) {
        if ($RemoveFromIntune) {
            Remove-Device -DeviceId $deviceIds.DeviceId -Platform "Intune" -AccessToken $AccessToken
        }
        if ($RemoveFromEntraID) {
            Remove-Device -DeviceId $deviceIds.AzureADDeviceId -Platform "EntraID" -AccessToken $AccessToken
        }
    }

    if ($RemoveFromAutopilot) {
        $autopilotDeviceId = Get-AutopilotDeviceId -SerialNumber $SerialNumber -AccessToken $AccessToken
        if ($autopilotDeviceId -ne $null) {
            Remove-Device -DeviceId $autopilotDeviceId -Platform "Autopilot" -AccessToken $AccessToken
        }
    }
}

function Invoke-BulkDeviceRemoval {
    param (
        [string]$CsvFile
    )
    WriteLog "Processing bulk device removal from CSV file: $CsvFile"
    $AccessToken = Get-AccessToken
    $devices = Import-Csv -Path $CsvFile
    foreach ($device in $devices) {
        $SerialNumber = $device.SerialNumber
        WriteLog "Processing device with Serial Number: $SerialNumber"
        $deviceIds = Get-DeviceId -SerialNumber $SerialNumber -AccessToken $AccessToken
        if ($deviceIds -ne $null) {
            if ($RemoveFromIntune) {
                Remove-Device -DeviceId $deviceIds.DeviceId -Platform "Intune" -AccessToken $AccessToken
            }
            if ($RemoveFromEntraID) {
                Remove-Device -DeviceId $deviceIds.AzureADDeviceId -Platform "EntraID" -AccessToken $AccessToken
            }
        }

        if ($RemoveFromAutopilot) {
            $autopilotDeviceId = Get-AutopilotDeviceId -SerialNumber $SerialNumber -AccessToken $AccessToken
            if ($autopilotDeviceId -ne $null) {
                Remove-Device -DeviceId $autopilotDeviceId -Platform "Autopilot" -AccessToken $AccessToken
            }
        }
    }
}

# Main script logic

WriteLog "Begin Script"
if ($CsvFile) {
    WriteLog "CSV File Found: $CsvFile"
    Invoke-BulkDeviceRemoval -CsvFile $CsvFile
} elseif ($SerialNumber) {
    WriteLog "Single serial number found: $SerialNumber"
    Invoke-SingleDeviceRemoval -SerialNumber $SerialNumber
} else {
    Write-Host "Please provide either a SerialNumber or a CsvFile."
    WriteLog "No SerialNumber or CsvFile provided. Exiting script."
}
WriteLog "End Script"