param (
    [Parameter(Mandatory = $true)]
    [string]$GroupName,
    [Parameter(Mandatory = $true)]
    [string]$prefix,
    [Parameter(Mandatory = $true)]
    [string]$suffix,
    [Parameter(Mandatory = $false)]
    [string]$ipPrefix

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
    $tokenuri = "https://login.microsoftonline.com/$tenantId/oauth2/v2.0/token"
    $body = @{
        grant_type = "client_credentials"
        client_id = $clientId
        client_secret = $clientSecret
        scope = "https://graph.microsoft.com/.default"
    }

    $response = Invoke-WebRequest -Method Post -Uri $tokenuri -ContentType "application/x-www-form-urlencoded" -Body $body
    $accessToken = (ConvertFrom-Json $response.Content).access_token
    $expiresIn = (ConvertFrom-Json $response.Content).expires_in
    $expirationTime = (Get-Date).AddSeconds($expiresIn)
    WriteLog 'Successfully obtained access token'
    WriteLog "Access token expiration date and time: $expirationTime"
    return $accessToken, $expirationTime
}

function Get-AADGroupId ($accessToken, $groupName) {
    WriteLog "Getting Azure AD Group ID for group $groupName"
    $uri = "https://graph.microsoft.com/beta/groups?`$filter=displayName eq '$groupName'"
    $response = Invoke-WebRequestWithRetry -Method Get -Uri $uri -ContentType "application/json" -Headers @{Authorization = "Bearer $accessToken" }
    $groupID = (ConvertFrom-Json $response.Content).value[0].id
    Writelog "$groupName groupID is $groupID"
    return $groupID
}

function Get-DeviceObjects ($accessToken, $groupId) {
    WriteLog "Getting members of $groupName"
    $uri = "https://graph.microsoft.com/beta/groups/$groupId/members"
    $groupMembers = @()

    do {
        $response = Invoke-WebRequestWithRetry -Method Get -Uri $uri -ContentType "application/json" -Headers @{Authorization = "Bearer $accessToken" }
        $pagedResults = (ConvertFrom-Json $response.Content).value
        $groupMembers += $pagedResults
        $uri = (ConvertFrom-Json $response.Content).'@odata.nextLink'
    } while ($null -ne $uri)

    WriteLog "Getting members of $groupName successful. $groupName contains $($groupMembers.count) members"
    return $groupMembers
}

#setDeviceName requires DeviceManagementManagedDevices.PrivilegedOperations.All permission for the application
function Set-DeviceName($accessToken, $intuneDeviceID, $newDeviceName) {
    $uri = "https://graph.microsoft.com/beta/deviceManagement/managedDevices/$intuneDeviceID/setDeviceName"
    $headers = @{
        Authorization  = "Bearer $accessToken"
    }
    $body = @{
        "deviceName" = $newDeviceName
    } | ConvertTo-Json
    Writelog "Renaming $oldDeviceName to $newDeviceName"
    $response = Invoke-WebRequestWithRetry -Method Post -Uri $uri -ContentType "application/json" -Headers $headers -Body $body 
    WriteLog "Name changed successfully"
}
function Get-IntuneDeviceId ($accessToken, $aadDeviceId) {
    WriteLog "Getting Intune deviceID for device $oldDeviceName with AzureAD deviceID $aadDeviceID"
    $uri = "https://graph.microsoft.com/beta/deviceManagement/managedDevices?`$filter=azureADDeviceId eq '$aadDeviceId'"
    $response = Invoke-WebRequestWithRetry -Method Get -Uri $uri -ContentType "application/json" -Headers @{Authorization = "Bearer $accessToken" }
    $intuneDeviceId = (ConvertFrom-Json $response.Content).value[0].id
    WriteLog "Intune deviceID for device $oldDeviceName`: $intuneDeviceID"
    return $intuneDeviceId
}

function Get-DeviceHardwareInformation ($accessToken, $intuneDeviceID) {
    WriteLog "Getting Intune hardware information for device with ID $intuneDeviceID"
    $uri = "https://graph.microsoft.com/beta/deviceManagement/managedDevices/$($intuneDeviceID)?`$select=id,deviceName,hardwareInformation"
    $response = Invoke-WebRequestWithRetry -Method Get -Uri $uri -ContentType "application/json" -Headers @{Authorization = "Bearer $accessToken" }
    $deviceHardwareInformation = (ConvertFrom-Json $response.Content)
    WriteLog "Successfully retrieved hardware information for $($deviceHardwareInformation.deviceName)"
    return $deviceHardwareInformation
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
    
    $accessToken, $tokenExpirationTime = Get-AccessToken
    $groupID = Get-AADGroupID -accessToken $accessToken -groupName $groupName
    $deviceObjects = Get-DeviceObjects -accessToken $accessToken -groupId $groupID
    
    foreach ($device in $deviceObjects) {
        if ((Get-Date) -ge $tokenExpirationTime.AddMinutes(-5)) {
            WriteLog 'Access token is about to expire. Refreshing token...'
            $accessToken, $tokenExpirationTime = Get-AccessToken
        }
        $oldDeviceName = $device.displayName
        $intuneDeviceId = Get-IntuneDeviceId -accessToken $accessToken -aadDeviceId $device.deviceID
        #If $intuneDeviceID is null, skip this device and continue with the next device
        if (!$intuneDeviceId) {
            WriteLog "Intune deviceID for device $oldDeviceName is null. Skipping this device and continuing with the next device"
            continue
        }
        $deviceHardwareInformation = Get-DeviceHardwareInformation -accessToken $accessToken -intuneDeviceID $intuneDeviceId
        #If IP address starts with $ipPrefix rename to A-{{serialnumber}}. If IP address starts with anything else, rename to S-{{serialnumber}}. 
        if ($ipPrefix) {
            if ($deviceHardwareInformation.hardwareInformation.ipAddressV4 -like $ipPrefix -or $deviceHardwareInformation.hardwareInformation.wiredIPv4Address -like $ipPrefix) {
                $prefix = 'A'
            }
            else {
                $prefix = 'S'
            }
        }
        $newDeviceName = "$prefix-$suffix"
        Set-DeviceName $accessToken $intuneDeviceID $newDeviceName
    }
}
catch{
    throw $_
}

