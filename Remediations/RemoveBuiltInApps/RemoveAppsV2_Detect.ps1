
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
        )

    $ProvisionedStoreApps = (Get-AppXProvisionedPackage -Online).DisplayName
    
    foreach ($ProvisionedAppName in $ProvisionedAppPackageNames) {
        If($ProvisionedAppName -in $ProvisionedStoreApps) {
           Write-Host "$ProvisionedAppName detected and should be removed. Exiting script."
           exit 1
        }
    }

    #Checks for Teams Machine Wide Installer and removes it. 
    #This is best used for provisioning new devices.
    #Once a user signs in and Teams is installed for that user, it must be uninstalled from that user's profile. 
    #if(Test-Path 'C:\Program Files (x86)\Teams Installer'){
    # Write-Host "Teams detected and should be removed. Exiting script."
    # exit 1
    #}
    exit 0
}
catch {
    $errMsg = $_.Exception.Message
    Write-Error $errMsg
    exit 1
}