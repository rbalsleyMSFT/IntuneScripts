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



