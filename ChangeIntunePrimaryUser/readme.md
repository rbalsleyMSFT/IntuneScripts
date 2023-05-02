# Change or Remove Intune Primary User
This script will either change the Intune primary user to the last logged on user, or remove the primary user altogether. If you're having issues with the Company Portal and non-primary users are unable to install applications, this script can help fix that.

# Authentication
You'll need an Azure AD Application Registration in other to securely run this script. It's not designed to use delegated permissions (e.g. your Azure AD account).

If you've never registered an application before to authenticate to Azure AD, this [Microsoft Quickstart Guide on App Registration](https://learn.microsoft.com/en-us/azure/active-directory/develop/quickstart-register-app) is a good starting point. 

image.png
