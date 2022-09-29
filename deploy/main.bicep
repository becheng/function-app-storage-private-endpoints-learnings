param location string = 'canadacentral'

var resource_prefix = 'bc'
var unique_str = uniqueString(subscription().subscriptionId)

// storage/blob info
var target_storage_acct_name = '${resource_prefix}${unique_str}sa'
var target_blob_privendpt_name = '${resource_prefix}${unique_str}-blob-privendpt'
var target_blob_privendpt_nic_name = '${resource_prefix}${unique_str}-blob-privendpt-nic'
var target_blob_container_name = 'default'

// vnet info
var vnet_name = '${resource_prefix}-${unique_str}-vnet'
var functionSubnetName = 'snet-func'
var privateEndpointSubnetName = 'snet-pe'


//var pdnszone_privatelink_blob_core_windows_net_name = 'privatelink.blob.core.windows.net'
var pdnszone_privatelink_blob_core_windows_net_name = 'privatelink.blob.${environment().suffixes.storage}'

// azure function info
var func_name = '${resource_prefix}-${unique_str}-fa'
var func_asp_name = '${resource_prefix}-${unique_str}-asp'
var func_attached_storage_name = '${resource_prefix}${unique_str}funcsa'
var func_app_insights_name = '${resource_prefix}-${unique_str}-ai'

// target storage account that will have a private endpoint blob
resource target_storage_acct_name_resource 'Microsoft.Storage/storageAccounts@2021-09-01' = {
  sku: {
    name: 'Standard_LRS'
  }
  kind: 'StorageV2'
  name: target_storage_acct_name
  location: location
  properties: {
    publicNetworkAccess: 'Disabled'
  }
}

// create a blobservices in the target storage acct - fyi, 'name' must be 'default'
resource target_blob_resource 'Microsoft.Storage/storageAccounts/blobServices@2021-09-01' = {
  parent: target_storage_acct_name_resource
  name: 'default'
  properties: {
    cors: {
      corsRules: []
    }
    deleteRetentionPolicy: {
      allowPermanentDelete: false
      enabled: false
    }
  }
}

// create a 'default' blob container 
resource target_blob_default_resource 'Microsoft.Storage/storageAccounts/blobServices/containers@2021-09-01' = {
  parent: target_blob_resource
  name: target_blob_container_name
  properties: {
    defaultEncryptionScope: '$account-encryption-key'
    denyEncryptionScopeOverride: false
    publicAccess: 'Container'
    immutableStorageWithVersioning: {
      enabled: false
    }
  }
}

// create the vnet with two subnets, one for storage endpoint and the other for the function app vnet integration
resource vnet_resource 'Microsoft.Network/virtualNetworks@2022-01-01' = {
  name: vnet_name
  location: location
  properties: {
    addressSpace: {
      addressPrefixes: [
        '10.100.0.0/16'
      ]
    }
    subnets: [
      {
        name: privateEndpointSubnetName
        //id: '${resourceGroup().id}/providers/Microsoft.Network/virtualNetworks/${vnet_name}/subnets/snet-pe'
        properties: {
          addressPrefix: '10.100.1.0/24'
          //delegations: []
          privateEndpointNetworkPolicies: 'Disabled'
          privateLinkServiceNetworkPolicies: 'Enabled'
        }
        //type: 'Microsoft.Network/virtualNetworks/subnets'
      }
      {
        name: functionSubnetName
        //id: '${resourceGroup().id}/providers/Microsoft.Network/virtualNetworks/${vnet_name}/subnets/snet-func'
        properties: {
          addressPrefix: '10.100.0.0/24'
          //serviceEndpoints: []
          delegations: [
            {
              name: 'webapp'
              properties: {
                serviceName: 'Microsoft.Web/serverFarms'
              }
            }
          ]
          privateEndpointNetworkPolicies: 'Enabled'
          privateLinkServiceNetworkPolicies: 'Enabled'
        }
        //type: 'Microsoft.Network/virtualNetworks/subnets'
      }
    ]
    //virtualNetworkPeerings: []
    //enableDdosProtection: false
  }

  resource functionSubnet 'subnets' existing = {
    name: functionSubnetName
  }

  resource privateEndpointSubnet 'subnets' existing = {
    name: privateEndpointSubnetName
  }
}

// create private dns zone for the nat of the storage dns to its private ip
resource pdnszone_privatelink_blob_resource 'Microsoft.Network/privateDnsZones@2018-09-01' = {
  name: pdnszone_privatelink_blob_core_windows_net_name
  location: 'global'
  properties: {}
}

// create the A record within the private dns zone
resource pdnszone_privatelink_blob_resource_Arecord_resource 'Microsoft.Network/privateDnsZones/A@2018-09-01' = {
  parent: pdnszone_privatelink_blob_resource
  name: target_storage_acct_name
  properties: {
    ttl: 10
    aRecords: [
      {
        ipv4Address: '10.100.1.4'
      }
    ]
  }
}

// create the soa record within the private dns zone
resource pdnszone_privatelink_blob_resource_SOARecord_resource 'Microsoft.Network/privateDnsZones/SOA@2018-09-01' = {
  parent: pdnszone_privatelink_blob_resource
  name: '@'
  properties: {
    ttl: 3600
    soaRecord: {
      email: 'azureprivatedns-host.microsoft.com'
      expireTime: 2419200
      host: 'azureprivatedns.net'
      minimumTtl: 10
      refreshTime: 3600
      retryTime: 300
      serialNumber: 1
    }
  }
}

// link the private dns zone to the vnet
resource pdnszone_privatelink_blob_resource_vnetlink_resource 'Microsoft.Network/privateDnsZones/virtualNetworkLinks@2018-09-01' = {
  parent: pdnszone_privatelink_blob_resource
  name: '${pdnszone_privatelink_blob_core_windows_net_name}-link'
  location: 'global'
  properties: {
    registrationEnabled: false
    virtualNetwork: {
      id: vnet_resource.id
    }
  }
}

// create the storage private endpoint - note: its associated nic will be auto created 
resource storage_blob_privendpt 'Microsoft.Network/privateEndpoints@2022-01-01' = {
  name: target_blob_privendpt_name
  location: location
  properties: {
    privateLinkServiceConnections: [
      {
        name: target_blob_privendpt_name
        properties: {
          privateLinkServiceId: target_storage_acct_name_resource.id
          groupIds: [
            'blob'
          ]
          privateLinkServiceConnectionState: {
            status: 'Approved'
            description: 'Auto-Approved'
            actionsRequired: 'None'
          }
        }
      }
    ]
    manualPrivateLinkServiceConnections: []
    customNetworkInterfaceName: target_blob_privendpt_nic_name
    subnet: {
      id: '${resourceGroup().id}/providers/Microsoft.Network/virtualNetworks/${vnet_name}/subnets/snet-pe'
    }
    ipConfigurations: []
    customDnsConfigs: []
  }
}

// assocate the private blob dns zone to the storage private endpoint
resource storage_blob_privendpt_name_resource 'Microsoft.Network/privateEndpoints/privateDnsZoneGroups@2020-11-01' = {
  parent: storage_blob_privendpt
  name: 'default'
  properties: {
    privateDnsZoneConfigs: [
      {
        name: pdnszone_privatelink_blob_core_windows_net_name
        properties: {
          privateDnsZoneId: pdnszone_privatelink_blob_resource.id
        }
      }
    ]
  }
}

// create the function attached storage account
resource func_attached_storage_resource 'Microsoft.Storage/storageAccounts@2021-09-01' = {
  name: func_attached_storage_name
  location: location
  sku: {
    name: 'Standard_LRS'
  }
  kind: 'StorageV2'
}

// create the funcation app service plan
resource func_asp_resource 'Microsoft.Web/serverfarms@2022-03-01' = {
  name: func_asp_name
  location: location
  sku: {
    name: 'S1'
    tier: 'Standard'
  }
  properties: {
    reserved: true
  }
  kind: 'linux'
}

// create the funcation app
resource functionApp 'Microsoft.Web/sites@2022-03-01' = {
  name: func_name
  location: location
  kind: 'functionapp,linux'
  identity: {
    type: 'SystemAssigned'
  }
  properties: {
    serverFarmId: func_asp_resource.id
    virtualNetworkSubnetId: '${resourceGroup().id}/providers/Microsoft.Network/virtualNetworks/${vnet_name}/subnets/snet-func'
    vnetRouteAllEnabled: true
    siteConfig: {
      appSettings: [
        {
          name: 'AzureWebJobsStorage'
          value: 'DefaultEndpointsProtocol=https;AccountName=${func_attached_storage_name};EndpointSuffix=${environment().suffixes.storage};AccountKey=${func_attached_storage_resource.listKeys().keys[0].value}'
        }
        {
          name: 'FUNCTIONS_EXTENSION_VERSION'
          value: '~4'
        }
        {
          name: 'FUNCTIONS_WORKER_RUNTIME'
          value: 'node'
        }
        {
          name: 'APPINSIGHTS_INSTRUMENTATIONKEY'
          value: applicationInsights.properties.InstrumentationKey
        }

        // demo specific settings for the function to access the storage blob
        {
          name: 'ACCOUNT_NAME'
          value: target_storage_acct_name
        }
        {
          name: 'CONTAINER'
          value: target_blob_container_name
        }

      ]
      linuxFxVersion: 'NODE|16'
      ftpsState: 'FtpsOnly'
      minTlsVersion: '1.2'
    }
    httpsOnly: true
  }
}

// func applicaiton insights 
resource applicationInsights 'Microsoft.Insights/components@2020-02-02' = {
  name: func_app_insights_name
  location: location
  kind: 'web'
  properties: {
    Application_Type: 'web'
    Request_Source: 'rest'
  }
}

// Note: the Storage Blob Contributor roleDefinitionId located in https://docs.microsoft.com/en-us/azure/role-based-access-control/built-in-roles
resource storage_blob_contributor_role_definition 'Microsoft.Authorization/roleDefinitions@2022-04-01' existing = {
  scope: subscription()
  name: 'ba92f5b4-2d11-453d-a403-e96b0029c9fe'
}

// assign func's system identity with a storage blob contributor role to the target storage account
resource func_storage_role_assignment_resource 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(subscription().id, func_name, storage_blob_contributor_role_definition.id)
  scope: target_storage_acct_name_resource
  properties: {
    principalType: 'ServicePrincipal'
    principalId: functionApp.identity.principalId
    roleDefinitionId: storage_blob_contributor_role_definition.id
  }
}

