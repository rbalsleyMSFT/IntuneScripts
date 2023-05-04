param (
    [Parameter(Mandatory = $true)]
    [string]$GroupName,
    [Parameter(Mandatory = $true)]
    [string]$prefix,
    [Parameter(Mandatory = $true)]
    [string]$suffix
)

# Replace these with your app registration values
$clientId = '<Your Application clientID>'
$clientSecret ='<Your Application clientSecret>' 
$tenantId = '<Your tenantID>'

$Logfile = "$PSScriptRoot\BulkRenameDevices.log"
function WriteLog($LogText) { 
    Add-Content -path $LogFile -value "$((Get-Date).ToString()) $LogText" -Force -ErrorAction SilentlyContinue
    Write-Verbose $LogText
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
    WriteLog 'Successfully obtained access token'
    return (ConvertFrom-Json $response.Content).access_token
}

function Get-AADGroupId ($accessToken, $groupName) {
    WriteLog "Getting Azure AD Group ID for group $groupName"
    $url = "https://graph.microsoft.com/beta/groups?`$filter=displayName eq '$groupName'"
    $response = Invoke-WebRequest -Method Get -Uri $url -ContentType "application/json" -Headers @{Authorization = "Bearer $accessToken" }
    $groupID = (ConvertFrom-Json $response.Content).value[0].id
    Writelog "$groupName groupID is $groupID"
    return $groupID
}

function Get-DeviceObjects ($accessToken, $groupId) {
    WriteLog "Getting members of $groupName"
    $url = "https://graph.microsoft.com/beta/groups/$groupId/members"
    $response = Invoke-WebRequest -Method Get -Uri $url -ContentType "application/json" -Headers @{Authorization = "Bearer $accessToken" }
    $groupMembers = (ConvertFrom-Json $response.Content).value
    WriteLog "Getting members of $groupName successful. $groupName contains $($groupmembers.count) members"
    return $groupMembers
}

#setDeviceName requires DeviceManagementManagedDevices.PrivilegedOperations.All permission for the application
function Set-DeviceName($accessToken, $deviceID, $newDeviceName) {
    $uri = "https://graph.microsoft.com/beta/deviceManagement/managedDevices/$deviceID/setDeviceName"
    $headers = @{
        Authorization  = "Bearer $accessToken"
        "Content-Type" = "application/json"
    }
    $body = @{
        "deviceName" = $newDeviceName
    } | ConvertTo-Json
    Writelog "Renaming $oldDeviceName to $newDeviceName"
    Invoke-RestMethod -Uri $uri -Headers $headers -Method Post -Body $body
    WriteLog "Name changed successfully"
}

function Invoke-ThrottledRequest ($accessToken, $deviceID, $newDeviceName) {
    if ($script:RequestCounter -eq 100) {
        WriteLog "Graph API limit of 100 requests hit. Sleeping for 20 seconds before resuming"
        Start-Sleep -Seconds 20
        $script:RequestCounter = 0
    }

    Set-DeviceName $accessToken $deviceID $newDeviceName

    $script:RequestCounter++
    WriteLog "Incrementing API request count to: $script:RequestCounter"
}
function Get-IntuneDeviceId ($accessToken, $aadDeviceId) {
    WriteLog "Getting Intune deviceID for device $oldDeviceName with AzureAD deviceID $aadDeviceID"
    $url = "https://graph.microsoft.com/beta/deviceManagement/managedDevices?`$filter=azureADDeviceId eq '$aadDeviceId'"
    $response = Invoke-WebRequest -Method Get -Uri $url -ContentType "application/json" -Headers @{Authorization = "Bearer $accessToken" }
    $intuneDeviceId = (ConvertFrom-Json $response.Content).value[0].id
    WriteLog "Intune deviceID for device $oldDeviceName`: $intuneDeviceID"
    return $intuneDeviceId
}
try{
    $script:RequestCounter = 0
    if (Test-Path -Path $Logfile) {
        Remove-item -Path $LogFile -Force
    }
    
    if ($suffix -match "{{rand:\d+}}") {
        # Get the integer from {{rand:x}} and store this in $randLength. X is an integer that the user will pass in the $suffix parameter
        $randLength = [int]($suffix -replace "[^\d]")
        $prefixLength = $prefix.Length
        $nameLength = $prefixLength + $randLength + 1
        if ($nameLength -gt 15) {
            throw "Generated device name is too long. Name should be 15 characters or less. Please change the device name prefix or suffix."
        }
    }
    
    $accessToken = Get-AccessToken
    $groupID = Get-AADGroupID -accessToken $accessToken -groupName $groupName
    $deviceObjects = Get-DeviceObjects -accessToken $accessToken -groupId $groupID
    
    foreach ($device in $deviceObjects) {
        $intuneDeviceId = Get-IntuneDeviceId -accessToken $accessToken -aadDeviceId $device.deviceID
        $oldDeviceName = $device.displayName
        $newDeviceName = "$prefix-$suffix"
        Invoke-ThrottledRequest $accessToken $intuneDeviceId $newDeviceName 
    }
}
catch{
    throw $_
}

