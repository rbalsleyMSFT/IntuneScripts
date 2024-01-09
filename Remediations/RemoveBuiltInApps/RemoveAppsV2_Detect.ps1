$LogFile = 'C:\Windows\temp\Apps.txt'
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
try {
    #If you need to add additional apps to this list, get the Provisioned App Display name by running (Get-AppXProvisionedPackage -Online).DisplayName via Powershell
    #Minecraft requires the XboxGame(ing)overlay apps in order to take screenshots. If removed, you will get an error when opening Minecraft. Minecraft still works, but the error might be annoying for end users.
    $ProvisionedAppPackageNames = @( 
        #MS Stuff
        "Microsoft.YourPhone"
        "Microsoft.SkypeApp"
        "Microsoft.XboxGameOverlay"
        "Microsoft.Messaging"
        "Microsoft.XboxGamingOverlay"
        "Microsoft.People"
        "Microsoft.MicrosoftOfficeHub"
        "Microsoft.BingWeather"
        "Microsoft.Microsoft3DViewer"
        "Microsoft.MicrosoftSolitaireCollection"
        "Microsoft.MixedReality.Portal"
        "microsoft.windowscommunicationsapps"
        "Microsoft.XboxApp"
        "MicrosoftTeams"
        "Microsoft.BingNews"
        "Microsoft.SurfaceHub"
        "Microsoft.GamingApp"
        "Microsoft.ZuneVideo"
	    "Microsoft.OutlookForWindows"
	    "Microsoft.549981C3F5F10"
	    "Microsoft.Windows.DevHome"
        )
    WriteLog "Checking for the following apps $ProvisionedAppPackageNames"

    $ProvisionedStoreApps = (Get-AppXProvisionedPackage -Online).DisplayName
    WriteLog "Provisioned apps: $ProvisionedStoreApps"
    
    foreach ($ProvisionedAppName in $ProvisionedAppPackageNames) {
        WriteLog "Checking for $ProvisionedAppName"
        If($ProvisionedAppName -in $ProvisionedStoreApps) {
           WriteLog "$ProvisionedAppName detected and should be removed. Exiting script."
           Write-Host "$ProvisionedAppName detected and should be removed. Exiting script."
           exit 1
        }
        else {
            WriteLog "$ProvisionedAppName not detected"
            Write-Host "$ProvisionedAppName not detected"
        }
    }
    WriteLog "No provisioned apps detected"
    exit 0
}
catch {
    $errMsg = $_.Exception.Message
    Write-Error $errMsg
    exit 1
}