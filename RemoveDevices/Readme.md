# Remove devices from Intune, Entra ID and Autopilot

The RemoveManagedDevices.ps1 script is designed to remove devices from Microsoft Intune, Entra ID, and Autopilot based on provided serial numbers. This script can process single serial numbers or bulk removal from a CSV file. The script utilizes Microsoft Graph API to perform these operations.This script will either change the Intune primary user to the last logged on user, or remove the primary user altogether to devices in a specified Entra ID security group

# Problem

This script addresses the need to efficiently remove managed devices from Intune, Entra ID, and Autopilot in an automated and scalable manner, either individually or in bulk.

# Authentication

You'll need an Entra ID Application Registration in order to securely run this script. It's not designed to use delegated permissions (e.g. your Entra ID account).

If you've never registered an application before to authenticate to Entra ID, this [Microsoft Quickstart Guide on App Registration](https://learn.microsoft.com/en-us/azure/active-directory/develop/quickstart-register-app) is a good starting point.

Below are some screenshots on how your application should be configured

![A picture of the register an application wizard in Azure AD](https://user-images.githubusercontent.com/53497092/235554545-a66fd398-63b2-4352-98db-56ec8afc4e24.png)

Once registered, select **Certificates & secrets**

![image](https://user-images.githubusercontent.com/53497092/235555804-9884172b-090b-4843-a0a6-3a112dba6d74.png)

Select either **Certificates** to upload a certificate (most secure) or click **New client secret** (in this guide will use a new client secret since it's easier)

![image](https://user-images.githubusercontent.com/53497092/235555971-21e867f7-79b6-433e-8926-1fdf71fedbfc.png)

Either keep the defaults, or change the **Expires** value to a value you're comfortable with. **Microsoft recommends a value of 12 months or less.**

![image](https://user-images.githubusercontent.com/53497092/235556069-b6c34f65-5346-49cd-9fd3-426d691c1ca7.png)

After you click **Add**, ***copy the value of the secret***. It's important to copy this value now as when you leave this screen, the value column will not show the full value when you return. This value is what you'll use in the script to authenticate. Also make sure to note when this application expires. You'll need to generate a new client secret on or before that date.

Click on **API permissions**. You'll need the following permissions and Admin consent is required for them.

To add the permissions, click **Add a permission** and select **Microsoft Graph** in the fly out, then select **Application permissions**. In the select permissions area, search for the below permissions and add them.

* DeviceManagementManagedDevices.ReadWrite.All
* Directory.ReadWrite.All
* DeviceManagementServiceConfig.ReadWrite.All
* Device.ReadWrite.Al

Once you've selected the permissions, click **Grant admin consent for "your tenant name"**. Your permissions should look like this.

![image](https://github.com/rbalsleyMSFT/IntuneScripts/blob/main/RemoveDevices/image/Readme/Permissions.png)

Now you're ready to customize the script.

# Customize the script

There are three variables you'll need to customize

- $clientId
- $clientSecret
- $tenantId

$clientId and $tenantID are what you get from the app you just made (go to the Overview tab within the app in the Azure portal to get those values). The $clientSecret is the value you copied from the app when you made the client secret earlier (you did remember to copy that, right?)

# Run the script

The script has an action variable that accepts five commands:

- **SerialNumber** : The serial number of the device to be removed.
- **CsvFile** : The path to the CSV file containing a list of serial numbers for bulk removal.
- **RemoveFromIntune** : Switch to remove the device from Intune.
- **RemoveFromEntraID** : Switch to remove the device from Entra ID.
- **RemoveFromAutopilot** : Switch to remove the device from Autopilot.

**Single Device Removal**:

* Provide the serial number of the device.
* Specify the platforms from which the device should be removed using the appropriate switches.

**Bulk Device Removal**:

* Provide the path to the CSV file containing the list of serial numbers.
* Specify the platforms from which the devices should be removed using the appropriate switches.

## Examples

.\RemoveManagedDevices.ps1 -SerialNumber "ABC123456" -RemoveFromIntune -RemoveFromEntraID

.\RemoveManagedDevices.ps1 -CsvFile "devices.csv" -RemoveFromIntune -RemoveFromAutopilot

## **Expected Outcomes**

**Log Files** : The script generates log files to track the removal process:

* RemovedDevices.log: Logs of successfully removed devices.
* NotFoundDevices.txt: Logs of devices not found.

**Device Removal** : Devices specified by the serial number or in the CSV file will be removed from the selected platforms (Intune, Entra ID, Autopilot).

## **Additional Notes**

* **CSV File Format**: Ensure the CSV file contains a column named SerialNumber.
* **Error Handling**: The script logs errors and devices not found for troubleshooting.
* **Entra ID Object deletion**: The Intune object of the associated Entra ID   object must be present in order to successfully delete the Entra ID object. This is because we gather the Entra ID object from the associated Intune object, since the Entra ID object does not contain the serial number property. If the Intune object is missing, and the -RemovefromEntraID parameter is included, the script reports that no Entra object is found which may not be the case.
