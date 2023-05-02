param(
    [Parameter(Mandatory=$true)]
    [string]$GroupName,
    [Parameter(Mandatory=$true)]
    [ValidateSet("change", "remove")]
    [string]$Action
)

# Replace these with your app registration values
$clientId = "4c4f3db9-8e20-48c2-af4a-6628f38d9b78"
$clientSecret = "7kQ8Q~Cg6jnqxcwRYrpR2hypfcHdU3Ke2t_e.doc"
$tenantId = "bc76ba6d-d00d-4429-b87e-93898743b2e2"

$Logfile = "$PSScriptRoot\ChangePrimaryUser.log"
function WriteLog($LogText) { 
    Add-Content -path $LogFile -value "$((Get-Date).ToString()) $LogText" -Force -ErrorAction SilentlyContinue
    Write-Verbose $LogText
}
function Get-AccessToken {
    WriteLog 'Getting Access token'
    $tokenUrl = "https://login.microsoftonline.com/$tenantId/oauth2/v2.0/token"
    $body = @{
        grant_type = "client_credentials"
        client_id = $clientId
        client_secret = $clientSecret
        scope = "https://graph.microsoft.com/.default"
    }

    $response = Invoke-WebRequest -Method Post -Uri $tokenUrl -ContentType "application/x-www-form-urlencoded" -Body $body
    WriteLog 'Successfully obtained access token'
    return (ConvertFrom-Json $response.Content).access_token
}

function Get-AADGroupId ($accessToken, $groupName) {
    WriteLog "Getting Azure AD Group ID for group $groupName"
    $url = "https://graph.microsoft.com/beta/groups?`$filter=displayName eq '$groupName'"
    $response = Invoke-WebRequest -Method Get -Uri $url -ContentType "application/json" -Headers @{Authorization = "Bearer $accessToken"}
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

function Get-LastLoggedOnUser ($accessToken, $intuneDeviceId) {
    WriteLog "Getting last logged on user for device $($device.displayname) with Intune deviceID $intuneDeviceID"
    $url = "https://graph.microsoft.com/beta/deviceManagement/managedDevices/${intuneDeviceId}?`$select=usersLoggedOn"
    $response = Invoke-WebRequest -Method Get -Uri $url -ContentType "application/json" -Headers @{Authorization = "Bearer $accessToken"}
    $lastLoggedOnUserID = (ConvertFrom-Json $response.Content).usersLoggedOn[-1].userId
    WriteLog "Last logged on user for device $($device.displayName): $lastLoggedOnUserID"
    return $lastLoggedOnUserID
}

function Get-PrimaryUser ($accessToken, $intuneDeviceId) {
    WriteLog "Getting primary user for device $($device.displayname) with Intune deviceID $intuneDeviceID"
    $url = "https://graph.microsoft.com/beta/deviceManagement/managedDevices/$intuneDeviceId/users"
    $response = Invoke-WebRequest -Method Get -Uri $url -ContentType "application/json" -Headers @{Authorization = "Bearer $accessToken"}
    $primaryUserID = (ConvertFrom-Json $response.Content).value.id
    $primaryUserDisplayName = (ConvertFrom-Json $response.Content).value.displayName
    WriteLog "Primary user for device $($device.displayname): $primaryUserDisplayName (UserID: $primaryUserID)"
    return $primaryUserID
}

function Update-PrimaryUser ($accessToken, $deviceId, $userId) {
    WriteLog "Updating primary user for device $($device.displayname) with Intune deviceID $intuneDeviceID with userID $userID"
    $url = "https://graph.microsoft.com/beta/deviceManagement/managedDevices/$deviceId/users/`$ref"
    $userURI = "https://graph.microsoft.com/beta/users/$userId"
    $body = @{ '@odata.id'="$userURI" } | ConvertTo-Json -Compress
    Invoke-WebRequest -Method Post -Uri $url -Body $body -ContentType "application/json" -Headers @{Authorization = "Bearer $accessToken"}
    WriteLog "Update Complete"
}

function Remove-PrimaryUser ($accessToken, $deviceId) {
    WriteLog "Removing Primary User from device $($device.displayname) with Intune deviceID $intuneDeviceID"
    $url = "https://graph.microsoft.com/beta/deviceManagement/managedDevices/$deviceId/users/`$ref"
    Invoke-WebRequest -Method Delete -Uri $url -ContentType "application/json" -Headers @{Authorization = "Bearer $accessToken"}
    WriteLog "Removal Complete"
}

function Invoke-ThrottledRequest ($accessToken, $action, $deviceId, $userId) {
    if ($script:RequestCounter -eq 200) {
        WriteLog "Graph API limit of 200 requests hit. Sleeping for 20 seconds before resuming"
        Start-Sleep -Seconds 20
        $script:RequestCounter = 0
    }

    if ($action -eq "change") {
        Update-PrimaryUser -accessToken $accessToken -deviceId $deviceId -userId $userId
    } elseif ($action -eq "remove") {
        Remove-PrimaryUser -accessToken $accessToken -deviceId $deviceId
    }

    $script:RequestCounter++
    WriteLog "Incrementing API request count to: $script:RequestCounter"
}
function Get-IntuneDeviceId ($accessToken, $aadDeviceId) {
    WriteLog "Getting Intune deviceID for device $($device.displayname) with AzureAD deviceID $aadDeviceID"
    $url = "https://graph.microsoft.com/beta/deviceManagement/managedDevices?`$filter=azureADDeviceId eq '$aadDeviceId'"
    $response = Invoke-WebRequest -Method Get -Uri $url -ContentType "application/json" -Headers @{Authorization = "Bearer $accessToken"}
    $intuneDeviceId = (ConvertFrom-Json $response.Content).value[0].id
    WriteLog "Intune deviceID for device $($device.displayname): $intuneDeviceID"
    return $intuneDeviceId
}

# Main script execution
$script:RequestCounter = 0
try{
    if (Test-Path -Path $Logfile) {
        Remove-item -Path $LogFile -Force
    }
    Writelog 'Starting script'
    WriteLog "Script action set to: $action"
    $accessToken = Get-AccessToken
    $groupId = Get-AADGroupId -accessToken $accessToken -groupName $GroupName
    $deviceObjects = Get-DeviceObjects -accessToken $accessToken -groupId $groupId
    foreach ($device in $deviceObjects) {
        $intuneDeviceId = Get-IntuneDeviceId -accessToken $accessToken -aadDeviceId $device.deviceId
        $primaryUser = Get-PrimaryUser -accessToken $accessToken -intuneDeviceId $intuneDeviceId
        if ($Action -eq "change") {
            $lastLoggedOnUser = Get-LastLoggedOnUser -accessToken $accessToken -intuneDeviceId $intuneDeviceId
            if ($primaryUser -ne $lastLoggedOnUser) {
                WriteLog "Primary user and last logged on user do not match. Changing primary user to last logged on user."
                Invoke-ThrottledRequest -accessToken $accessToken -action $Action -deviceId $intuneDeviceId -userId $lastLoggedOnUser
            }
            else{
                WriteLog "Primary user and last logged on user the same. Skipping change"
            }
        } elseif ($Action -eq "remove") {
            if ($primaryUser){
                Invoke-ThrottledRequest -accessToken $accessToken -action $Action -deviceId $intuneDeviceId
            }
            else{
                WriteLog "No primary user. Skipping removal."
            }
            
        }
    }
}
catch{
    throw $_
}



