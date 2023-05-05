# Change or Remove Intune Primary User
This script will either change the Intune primary user to the last logged on user, or remove the primary user altogether to devices in a specified Azure AD security group.

### Updates
5/4/2023 - Updated pagination handling so it'll now grab all devices if the group is larger than 100 devices. Also fixed an issue where the script would fail if no Intune deviceId was found. 

# Problem
Users are unable to use the Company Portal application to self-service install applications on their own. Users can install apps via the Company Portal in one of two ways:

1. User is the primary user as indicated in the device object in Intune
2. There is no primary user assigned to the device object in Intune. The primary user in the Intune console on the device object will show up as None. This type of configuration is considered a shared device configuration. A device is typically in this state if it's enrolled via a Provisioning Package or an Autopilot Self Deploying profile.

# Primary User benefits
Having a primary user has the following benefits
1. Admins can identify who the primary user is. This can make it easy to know who to contact in the event of an issue with the device (lost/stolen, etc)
2. Primary users can self-service Bitlocker recovery keys using the myaccount.microsoft.com portal. 

If these benefits don't matter to you, removing the primary user will allow for any user to be able to self-service install applications that have been made available to users. Just know that if a user needs their bitlocker recovery key for any reason, they will need to contact the help desk and have someone get it for them.

# Authentication
You'll need an Azure AD Application Registration in other to securely run this script. It's not designed to use delegated permissions (e.g. your Azure AD account).

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
- DeviceManagementConfiguration.Read.All
- DeviceManagementManagedDevices.ReadWrite.All
- Group.Read.All
- GroupMember.Read.All
- User.Read.All

Once you've selected the permissions, click **Grant admin consent for "your tenant name"**. Your permissions should look like this. 

![image](https://user-images.githubusercontent.com/53497092/235557304-5afd507b-01cd-4a85-b9f9-8ad48eeed1b8.png)

Now you're ready to customize the script

# Customize the script

There are three variables you'll need to customize

- $clientId
- $clientSecret 
- $tenantId

$clientId and $tenantID are what you get from the app you just made (go to the Overview tab within the app in the Azure portal to get those values). The $clientSecret is the value you copied from the app when you made the client secret earlier (you did remember to copy that, right?)

# Run the script
The script has an action variable that accepts two commands:

- Remove: remove will remove the primary user. The device will show up with a primary user of None
- Change: change will change the primary user to the last logged on user of the device

There is also a variable named GroupName which is the display name of the Azure AD security group that contains the devices you want to change the primary user of.

By default, the script will not output anything. If you want console output, use the -verbose parameter. There is a log that gets created in the root folder of where the script is being run from. 

## Examples
.\ChangeIntunePrimaryUser.ps1 -GroupName 'MyGroup' -action remove

.\ChangeIntunePrimaryUser.ps1 -GroupName 'MyGroup' -action change





















