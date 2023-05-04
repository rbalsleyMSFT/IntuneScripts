# Bulk Rename Large Numbers of Intune Devices
This script will bulk rename devices based on an Azure AD security group.

# Problem
By default, Intune's in-console bulk actions support 100 devices at a time and also requires you to individually select the devices you wish to rename. This makes it impossible to use this feature in a large organization where you might have devices that were enrolled with the wrong names.

# Authentication
You'll need an Azure AD Application Registration in order to securely run this script. It's not designed to use delegated permissions (e.g. your Azure AD account).

If you've never registered an application before to authenticate to Azure AD, this [Microsoft Quickstart Guide on App Registration](https://learn.microsoft.com/en-us/azure/active-directory/develop/quickstart-register-app) is a good starting point.

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

- Device.Read.All
- Group.Read.All
- GroupMember.Read.All
- DeviceManagementManagedDevices.PrivilegedOperations.All

Once you've selected the permissions, click **Grant admin consent for "your tenant name"**. Your permissions should look like this. 

![image](https://user-images.githubusercontent.com/53497092/236078199-d19c305b-22ea-4803-9231-07c53b73b75a.png)

Now you're ready to customize the script

# Customize the script

There are three variables you'll need to customize

- $clientId
- $clientSecret 
- $tenantId

$clientId and $tenantID are what you get from the app you just made (go to the Overview tab within the app in the Azure portal to get those values). The $clientSecret is the value you copied from the app when you made the client secret earlier (you did remember to copy that, right?)

# Run the script
There are 3 parameters you'll need to provide

- GroupName - This is the name of your Azure AD security group
- Prefix - This is the device name prefix you wish to use. Do not include a dash after the prefix. The script will add a dash to separate the prefix and suffix.
- Suffix - This is the suffix you wish to use. This can either be {{serialnumber}} or {{rand:x}} where x is the number of random digits you wish to have after the device prefix. 

By default, the script will not output anything. If you want console output, use the -verbose parameter. There is a log that gets created in the root folder of where the script is being run from. 

The script will throttle after 100 devices. The API docs don't indicate how many requests can be done within a specific amount of time. So the script will default to doing 100 devices every 20 seconds. 

Once the script has renamed a device, the device will need to be rebooted in order for the name to change to take. Intune can take a little while before it issues the command to the device. If you check a device object in the Intune console and it says the rename has completed, that means the rename command has made it to the device, not that the device's name has been changed. The device will still need to be rebooted. It's probably best to assume that after monthly patches have been installed that all of the devices should have their names changed (or ask your users to reboot).

## Examples
.\BulkRenameDevices.ps1 -GroupName 'MyGroup' -Prefix 'MSFT' -Suffix '{{rand:6}}'

.\BulkRenameDevices.ps1 -GroupName 'MyGroup' -Prefix 'MSFT' -Suffix '{{serialnumber}}'

And yes, you need those weird curly brackets.





















