# Sample: Azure function accessing an Azure Storage Blob with a Private Endpoint

This sample uses bicep to deploy and includes a github action as a buildndeploy.yml

Instructions:
1. Create an Azure resource group
    `az group create -n yourRG -l canadacentral` 

2. Create a Service Prinicpal for your Github Action as per this [guide](https://learn.microsoft.com/en-us/azure/azure-resource-manager/bicep/deploy-github-actions?tabs=openid%2CCLI#generate-deployment-credentials).  

    If you already have an existing service principal for Github Actions and using the OIDC methood, then ensure the service principal has been added with the Contributor role, to the target resource group at a minimum.  
    ```
    az role assignment create --role contributor --subscription $subscriptionId --assignee-object-id  $assigneeObjectId --assignee-principal-type ServicePrincipal --scopes /subscriptions/$subscriptionId/resourceGroups/$resourceGroupName
    ```
    Where the `$assignee-object-id` is the objectId of the service principal (found in Enterprise Apps) , and the `$subscriptionId`, `$resourceGroupName` are the subscription id and the target resource group name respectively. 

3. Create a new Environment called `sample` in your Github for the worflow.  

4. Manually trigger the workflow in Github.