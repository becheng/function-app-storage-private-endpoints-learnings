# Sample: Azure function accessing an Azure Storage Blob with a Private Endpoint

This sample uses bicep to deploy and includes a github action as a buildndeploy.yml

Instructions:
1. Fork this repo.
2. Create an Azure resource group
    `az group create -n yourRG -l canadacentral` 
3. Create a Service Prinicpal for your Github Action as per this [guide](https://learn.microsoft.com/en-us/azure/azure-resource-manager/bicep/deploy-github-actions?tabs=openid%2CCLI#generate-deployment-credentials).  

    If you already have an existing service principal for Github Actions and you're using the OIDC method, then ensure the service principal the Contributor role with a minimun scope of the target resource group.  
    ```
    az role assignment create --role contributor --subscription $subscriptionId --assignee-object-id  $assigneeObjectId --assignee-principal-type ServicePrincipal --scopes /subscriptions/$subscriptionId/resourceGroups/$resourceGroupName
    ```
    Where the `$assignee-object-id` is the objectId of the service principal (found in Enterprise Apps) , and the `$subscriptionId`, `$resourceGroupName` are the subscription id and the target resource group name respectively. 
4. Create a new Environment called `sample` within your forked repo in GitHub.  
5. Manually trigger in Github to run the workflow. 