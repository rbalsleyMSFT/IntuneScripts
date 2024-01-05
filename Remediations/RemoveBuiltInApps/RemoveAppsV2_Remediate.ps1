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

    $ProvisionedStoreApps = (Get-AppXProvisionedPackage -Online).DisplayName
    
    foreach ($ProvisionedAppName in $ProvisionedAppPackageNames) {
        If($ProvisionedAppName -in $ProvisionedStoreApps) {
            Get-AppxPackage -Name $ProvisionedAppName -AllUsers | Remove-AppxPackage
            Get-AppXProvisionedPackage -Online | where DisplayName -EQ $ProvisionedAppName | Remove-AppxProvisionedPackage -Online -AllUsers
            "$ProvisionedAppName removed" | out-file c:\windows\temp\AppsRemoved.txt -Append
        }
    }
    exit 0
}
catch {
    $errMsg = $_.Exception.Message
    Write-Error $errMsg
    exit 1
}