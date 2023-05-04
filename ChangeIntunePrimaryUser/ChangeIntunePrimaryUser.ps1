param(
    [Parameter(Mandatory=$true)]
    [string]$GroupName,
    [Parameter(Mandatory=$true)]
    [ValidateSet("change", "remove")]
    [string]$Action
)
# Replace these with your app registration values
$clientId = '<Your Application clientID>'
$clientSecret ='<Your Application clientSecret>' 
$tenantId = '<Your tenantID>'

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
    $groupMembers = @()

    do {
        $response = Invoke-WebRequest -Method Get -Uri $url -ContentType "application/json" -Headers @{Authorization = "Bearer $accessToken" }
        $pagedResults = (ConvertFrom-Json $response.Content).value
        $groupMembers += $pagedResults
        $url = (ConvertFrom-Json $response.Content).'@odata.nextLink'
    } while ($null -ne $url)

    WriteLog "Getting members of $groupName successful. $groupName contains $($groupMembers.count) members"
    return $groupMembers
}

function Get-LastLoggedOnUser ($accessToken, $intuneDeviceId) {
    WriteLog "Getting last logged on user for device $deviceName with Intune deviceID $intuneDeviceID"
    $url = "https://graph.microsoft.com/beta/deviceManagement/managedDevices/${intuneDeviceId}?`$select=usersLoggedOn"
    $response = Invoke-WebRequest -Method Get -Uri $url -ContentType "application/json" -Headers @{Authorization = "Bearer $accessToken"}
    $lastLoggedOnUserID = (ConvertFrom-Json $response.Content).usersLoggedOn[-1].userId
    if ($null -eq $lastLoggedOnUserID){
        Writelog 'Last logged on userID not found. Skipping'
        return
    }
    WriteLog "Last logged on userID for device $deviceName`: $lastLoggedOnUserID"
    return $lastLoggedOnUserID
}

function Get-PrimaryUser ($accessToken, $intuneDeviceId) {
    WriteLog "Getting primary user for device $deviceName with Intune deviceID $intuneDeviceID"
    $url = "https://graph.microsoft.com/beta/deviceManagement/managedDevices/$intuneDeviceId/users"
    $response = Invoke-WebRequest -Method Get -Uri $url -ContentType "application/json" -Headers @{Authorization = "Bearer $accessToken" }
    $primaryUserID = (ConvertFrom-Json $response.Content).value.id
    if ($primaryUserID) {
        $primaryUserDisplayName = (ConvertFrom-Json $response.Content).value.displayName
        WriteLog "Primary user for device $deviceName`: $primaryUserDisplayName (UserID: $primaryUserID)"
        return $primaryUserID
    }
    else{
        WriteLog 'Primary user not found'
        return
    }
    
}
function Test-UserExists ($accessToken, $userId) {
    WriteLog "Checking if last logged on user exists in Azure AD"
    $url = "https://graph.microsoft.com/beta/users?`$filter=ID eq '$userID'"
    try {
        $response = Invoke-WebRequest -Method Get -Uri $url -ContentType "application/json" -Headers @{Authorization = "Bearer $accessToken" }
        $userDisplayName = (ConvertFrom-Json $response.Content).value.displayName
        WriteLog "User displayname for userID $userID is: $userDisplayName"
        return $true
    }
    catch {
        WriteLog "User not found in Azure AD. Will not change primary user on $deviceName"
        return
    }
    
}

function Update-PrimaryUser ($accessToken, $deviceId, $userId) {
    WriteLog "Updating primary user for device $deviceName with Intune deviceID $intuneDeviceID with userID $userID"
    $url = "https://graph.microsoft.com/beta/deviceManagement/managedDevices/$deviceId/users/`$ref"
    $userURI = "https://graph.microsoft.com/beta/users/$userId"
    $body = @{ '@odata.id'="$userURI" } | ConvertTo-Json -Compress
    Invoke-WebRequest -Method Post -Uri $url -Body $body -ContentType "application/json" -Headers @{Authorization = "Bearer $accessToken"} | Out-Null
    WriteLog "Update Complete"
}

function Remove-PrimaryUser ($accessToken, $deviceId) {
    WriteLog "Removing Primary User from device $deviceName with Intune deviceID $intuneDeviceID"
    $url = "https://graph.microsoft.com/beta/deviceManagement/managedDevices/$deviceId/users/`$ref"
    Invoke-WebRequest -Method Delete -Uri $url -ContentType "application/json" -Headers @{Authorization = "Bearer $accessToken"} | Out-Null
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
    WriteLog "Getting Intune deviceID for device $deviceName with AzureAD deviceID $aadDeviceID"
    $url = "https://graph.microsoft.com/beta/deviceManagement/managedDevices?`$filter=azureADDeviceId eq '$aadDeviceId'"
    $response = Invoke-WebRequest -Method Get -Uri $url -ContentType "application/json" -Headers @{Authorization = "Bearer $accessToken"}
    $intuneDeviceId = (ConvertFrom-Json $response.Content).value[0].id
    if ($null -eq $intuneDeviceID){
        Writelog "Intune deviceID for AAD device $deviceName not found. Skipping."
        return
    }
    WriteLog "Intune deviceID for device $deviceName`: $intuneDeviceID"
    return $intuneDeviceId
}

# Main script execution
$script:RequestCounter = 0
$counter = 0
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
        $deviceName = $device.displayName
        WriteLog "====="
        $counter++
        WriteLog "Processing device number $counter"
        $intuneDeviceId = Get-IntuneDeviceId -accessToken $accessToken -aadDeviceId $device.deviceId
        #If Intune Device ID isn't found, skip the device and move to the next one
        if($null -eq $intuneDeviceId){
            Continue
        }
        $primaryUser = Get-PrimaryUser -accessToken $accessToken -intuneDeviceId $intuneDeviceId       
        if ($Action -eq "change") {
            $lastLoggedOnUser = Get-LastLoggedOnUser -accessToken $accessToken -intuneDeviceId $intuneDeviceId
            if ($null -eq $lastLoggedOnUser){
                Continue
            }
            if (-not (Test-UserExists -accessToken $accessToken -userId $lastLoggedOnUser)){
                Continue
            }
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