# Change or Remove Intune Primary User
This script will either change the Intune primary user to the last logged on user, or remove the primary user altogether. 

# Problem
Users are unable to use the Company Portal application to self-service install applications on their own. This is due to the current user not being the primary user of the device. Users can install apps via the Company Portal in one of two ways:

1. User is the primary user as indicated in the device object in Intune
2. There is no primary user assigned to the device object in Intune. The primary user in the Intune console on the device object will show up as None

# Authentication
You'll need an Azure AD Application Registration in other to securely run this script. It's not designed to use delegated permissions (e.g. your Azure AD account).

If you've never registered an application before to authenticate to Azure AD, this [Microsoft Quickstart Guide on App Registration](https://learn.microsoft.com/en-us/azure/active-directory/develop/quickstart-register-app) is a good starting point.

Below are some screenshots on how your application should be configured

![A picture of the register an application wizard in Azure AD](https://user-images.githubusercontent.com/53497092/235554545-a66fd398-63b2-4352-98db-56ec8afc4e24.png)

Once registered, select **Certificates & secrets**

![image](https://user-images.githubusercontent.com/53497092/235555804-9884172b-090b-4843-a0a6-3a112dba6d74.png)

Select either Certificates to upload a certificate (most secure) or click New client secret (in this guide will use a new client secret since it's easier)

![image](https://user-images.githubusercontent.com/53497092/235555971-21e867f7-79b6-433e-8926-1fdf71fedbfc.png)

Either keep the defaults, or change the Expires value to a value you're comfortable with. Microsoft recommends a value of 12 months or less.

![image](https://user-images.githubusercontent.com/53497092/235556069-b6c34f65-5346-49cd-9fd3-426d691c1ca7.png)

After you click Add, copy the value of the secret. It's important to copy this value now as when you leave this screen, the value column will not show the full value when you return. This value is what you'll use in the script to authenticate. Also make sure to note when this application expires. You'll need to generate a new client secret on or before that date. 

Click on API permissions. You'll need the following permissions and Admin consent will need to be required for them.

To add the permissions, click Add a permission and select Microsoft Graph in the fly out, then select Application permissions. In the select permissions area, search for the below permissions and add them.

- Device.Read.All
- DeviceManagementConfiguration.Read.All
- DeviceManagementManagedDevices.ReadWrite.All
- Group.Read.All
- GroupMember.Read.All
- User.Read.All

Once you've selected all of the permissions, click Grand admin consent for <your tenant name>. Your permissions should look something like this. 

![image](https://user-images.githubusercontent.com/53497092/235557304-5afd507b-01cd-4a85-b9f9-8ad48eeed1b8.png)














