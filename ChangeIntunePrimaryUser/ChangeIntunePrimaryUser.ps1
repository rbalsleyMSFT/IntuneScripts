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
    Add-Content -path $LogFile -value "$((Get-Date).ToString()) $LogText" -Force -ErrorAction SilentlyContinue -Encoding UTF8
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
    $accessToken = (ConvertFrom-Json $response.Content).access_token
    $expiresIn = (ConvertFrom-Json $response.Content).expires_in
    $expirationTime = (Get-Date).AddSeconds($expiresIn)
    WriteLog 'Successfully obtained access token'
    WriteLog "Access token expiration date and time: $expirationTime"
    return $accessToken, $expirationTime
}


function Get-AADGroupId ($accessToken, $groupName) {
    WriteLog "Getting Azure AD Group ID for group $groupName"
    $url = "https://graph.microsoft.com/beta/groups?`$filter=displayName eq '$groupName'"
    $response = Invoke-WebRequestWithRetry -Method Get -Uri $url -ContentType "application/json" -Headers @{Authorization = "Bearer $accessToken"}
    $groupID = (ConvertFrom-Json $response.Content).value[0].id
    Writelog "$groupName ID is $groupID"
    return $groupID
}

function Get-DeviceObjects ($accessToken, $groupId) {
    WriteLog "Getting members of $groupName"
    $url = "https://graph.microsoft.com/beta/groups/$groupId/members"
    $groupMembers = @()

    do {
        $response = Invoke-WebRequestWithRetry -Method Get -Uri $url -ContentType "application/json" -Headers @{Authorization = "Bearer $accessToken" }
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
    $response = Invoke-WebRequestWithRetry -Method Get -Uri $url -ContentType "application/json" -Headers @{Authorization = "Bearer $accessToken"}
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
    $response = Invoke-WebRequestWithRetry -Method Get -Uri $url -ContentType "application/json" -Headers @{Authorization = "Bearer $accessToken" }
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
        $response = Invoke-WebRequestWithRetry -Method Get -Uri $url -ContentType "application/json" -Headers @{Authorization = "Bearer $accessToken" }
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
    Invoke-WebRequestWithRetry -Method Post -Uri $url -ContentType "application/json" -Headers @{Authorization = "Bearer $accessToken"} -Body $body | Out-Null
    WriteLog "Update Complete"
}

function Remove-PrimaryUser ($accessToken, $deviceId) {
    WriteLog "Removing Primary User from device $deviceName with Intune deviceID $intuneDeviceID"
    $url = "https://graph.microsoft.com/beta/deviceManagement/managedDevices/$deviceId/users/`$ref"
    Invoke-WebRequestWithRetry -Method Delete -Uri $url -ContentType "application/json" -Headers @{Authorization = "Bearer $accessToken"} | Out-Null
    WriteLog "Removal Complete"
}

function Get-IntuneDeviceId ($accessToken, $aadDeviceId) {
    WriteLog "Getting Intune deviceID for device $deviceName with AzureAD deviceID $aadDeviceID"
    $url = "https://graph.microsoft.com/beta/deviceManagement/managedDevices?`$filter=azureADDeviceId eq '$aadDeviceId'"
    $response = Invoke-WebRequestWithRetry -Method Get -Uri $url -ContentType "application/json" -Headers @{Authorization = "Bearer $accessToken"}
    $intuneDeviceId = (ConvertFrom-Json $response.Content).value[0].id
    if ($null -eq $intuneDeviceID){
        Writelog "Intune deviceID for AAD device $deviceName not found. Skipping."
        return
    }
    WriteLog "Intune deviceID for device $deviceName`: $intuneDeviceID"
    return $intuneDeviceId
}

function Invoke-WebRequestWithRetry ($Method, $Uri, $ContentType, $Headers, $Body) {
    $maxRetries = 5
    $retryCount = 0
    $delay = 60 # Initial delay in seconds, used for exponential backoff

    do {
        try {
            
            if($Body){
                $response = Invoke-WebRequest -Method $Method -Uri $Uri -ContentType $ContentType -Headers $Headers -Body $Body
            }
            else{
                $response = Invoke-WebRequest -Method $Method -Uri $Uri -ContentType $ContentType -Headers $Headers
            }
            return $response
        }
        catch {
            
            $retryCount++
            $statusCode = $_.Exception.Response.StatusCode.Value__
            if ($statusCode -eq 429){
                $delay = $_.Exception.Response.Headers['Retry-After']
            }

            if ($statusCode -eq 404){
                WriteLog "Script returned 404 not found"
                break
            }
            
            WriteLog "Script failed with error $_"
            WriteLog "Retrying in $delay seconds. Retry attempt $retryCount of $maxRetries."
            Start-Sleep -Seconds $delay
            $delay = $delay * 2
        }
    } while ($retryCount -lt $maxRetries)
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
    $accessToken, $tokenExpirationTime = Get-AccessToken
    $groupId = Get-AADGroupId -accessToken $accessToken -groupName $GroupName
    $deviceObjects = Get-DeviceObjects -accessToken $accessToken -groupId $groupId
    foreach ($device in $deviceObjects) {
        if ((Get-Date) -ge $tokenExpirationTime.AddMinutes(-5)) {
            WriteLog 'Access token is about to expire. Refreshing token...'
            $accessToken, $tokenExpirationTime = Get-AccessToken
        }
        $deviceName = $device.displayName
        WriteLog "====="
        $counter++
        WriteLog "Processing device number $counter"
        $intuneDeviceId = Get-IntuneDeviceId -accessToken $accessToken -aadDeviceId $device.deviceId
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
                Update-PrimaryUser -accessToken $accessToken -deviceId $intuneDeviceId -userId $lastLoggedOnUser
            }
            else{
                WriteLog "Primary user and last logged on user the same. Skipping change"
            }
        } elseif ($Action -eq "remove") {
            if ($primaryUser){
                Remove-PrimaryUser -accessToken $accessToken -deviceId $intuneDeviceId
            }
            else{
                WriteLog "No primary user. Skipping removal."
            }
            
        }
    }
}
catch{
    throw $_
    WriteLog "Script failed with error $_"
}
