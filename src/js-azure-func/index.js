const { BlobServiceClient, ContainerClient } = require("@azure/storage-blob");
const { DefaultAzureCredential } = require("@azure/identity");

module.exports = async function (context, req) {
    context.log('JavaScript HTTP trigger function processed a request.');

    let responseMessage; 
        
    const account = process.env.ACCOUNT_NAME || "";
    const containerName = process.env.CONTAINER || "";

    console.log(`account: ${process.env.ACCOUNT_NAME}`);    
    console.log(`client_id: ${process.env.AZURE_CLIENT_ID}`);

    try {
        
        // authenticate to storage account; first if  service principal provided (for local dev), then by managed user identity 
        const defaultAzureCredential = new DefaultAzureCredential();
        const blobServiceClient = new BlobServiceClient(`https://${account}.blob.core.windows.net`,defaultAzureCredential);
        const containerClient = blobServiceClient.getContainerClient(`${containerName}`);
        
        // list the blobs and output as arrays of object values  
        let iter = containerClient.listBlobsFlat();
        let blobItem = await iter.next();

        let blobListObj = {};  //empty object
        blobListObj['blobList'] = []; // object property of array type to hold an array of blob objects

        i = 1;
        while (!blobItem.done) {
            console.log(`Blob ${i++}: ${JSON.stringify(blobItem.value)}`);
            
            blobListObj['blobList'].push({
                name: blobItem.value.name,
                contentType: blobItem.value.properties.contentType,
                lastModified: blobItem.value.properties.lastModified.toLocaleDateString("en-CA", {hour: '2-digit', minute:'2-digit'}), 
                createdOn: blobItem.value.properties.createdOn,
                tier: blobItem.value.properties.accessTier    
            });
            blobItem = await iter.next();
        }
        responseMessage = blobListObj;


    } catch (error) {
        responseMessage = error.message;  
        //console.log(error);
    }

    context.res = {
        // status: 200, /* Defaults to 200 */
        body: responseMessage
    };
}