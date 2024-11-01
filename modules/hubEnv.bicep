/*
------------------
param section
------------------
*/
// Common
param location string
param hubVNetName string 
// VNet
param hubVNetAddress string
// PE Subnet
param hubSubnetName1 string
param hubSubnetAddress1 string
// DNS Subnet
param hubSubnetName2 string
param hubSubnetAddress2 string
// VPN Gateway Subnet
param hubSubnetName3 string
param hubSubnetAddress3 string
// for VPN Gateway
param hubVPNGWName string
param hubLngName string
// for Azure Files
param baseStorageAccountName string
param fileshareName string

/*
------------------
var section
------------------
*/
// PE Subnet
var hubSubnet1 = { 
  name: hubSubnetName1 
  properties: { 
    addressPrefix: hubSubnetAddress1
    networkSecurityGroup: {
      id: nsgDefault.id
    }
  }
}
// DNS Subnet
var hubSubnet2 = { 
  name: hubSubnetName2 
  properties: { 
    addressPrefix: hubSubnetAddress2
  }
} 
// VPN Gateway Subnet
var hubSubnet3 = { 
  name: hubSubnetName3 
  properties: { 
    addressPrefix: hubSubnetAddress3
  } 
} 
// Storage Account Name
// uniqueStringの最初の5文字を取得
var uniquePart = substring(uniqueString(resourceGroup().id), 0, 5)
var storageAccountName = '${baseStorageAccountName}${uniquePart}'

// Azure環境のストレージDNSゾーンを取得
var storageDnsZone = 'privatelink.file.${environment().suffixes.storage}'

/*
------------------
resource section
------------------
*/

// create network security group for hub vnet
resource nsgDefault 'Microsoft.Network/networkSecurityGroups@2023-04-01' = {
  name: '${hubVNetName}-nsg'
  location: location
  properties: {
    // securityRulesなどの設定
  }
}

// create hubVNet & hubSubnet
resource hubVNet 'Microsoft.Network/virtualNetworks@2021-05-01' = { 
  name: hubVNetName 
  location: location 
  properties: { 
    addressSpace: { 
      addressPrefixes: [ 
        hubVNetAddress 
      ] 
    } 
    subnets: [ 
      hubSubnet1
      hubSubnet2
      hubSubnet3
    ]
  }

  // Get subnet information where Private Endpoint is connected.
  resource hubPESubnet 'subnets' existing = {
    name: hubSubnetName1
  }

  // Get subnet information where VPN Gateway is connected.
  resource hubGatewaySubnet 'subnets' existing = {
    name: hubSubnetName3
  }
}

// create public ip address for VPN Gateway
resource hubVPNGWpip 'Microsoft.Network/publicIPAddresses@2022-05-01' = {
  name: '${hubVPNGWName}-pip'
  location: location
  sku: {
    name: 'Standard'
  }
  properties: {
    publicIPAllocationMethod: 'Static'
    publicIPAddressVersion: 'IPv4'
  }
}

// create VPN Gateway for hub (RouteBased)
resource hubVPNGW 'Microsoft.Network/virtualNetworkGateways@2023-06-01' = {
  name: hubVPNGWName
  location: location
  properties: {
    enablePrivateIpAddress: false
    ipConfigurations: [
      {
        name: '${hubVPNGWName}-ipconfig'
        properties: {
          privateIPAllocationMethod: 'Dynamic'
          publicIPAddress: {
            id: hubVPNGWpip.id
          }
          subnet: {
            id: hubVNet::hubGatewaySubnet.id
          }
        }
      }
    ]
    enableBgpRouteTranslationForNat: false
    disableIPSecReplayProtection: false
    sku: {
      name: 'Vpngw1'
      tier: 'Vpngw1'
    }
    gatewayType: 'Vpn'
    vpnType: 'RouteBased'
    enableBgp: false
    activeActive: false
    vpnGatewayGeneration: 'Generation1'
    allowRemoteVnetTraffic: false
    allowVirtualWanTraffic: false
  }
}

// create local network gateway for azure vpn connection
resource hubLng 'Microsoft.Network/localNetworkGateways@2023-06-01' = {
  name: hubLngName
  location: location
  properties: {
    localNetworkAddressSpace: {
      addressPrefixes: ['${hubVNetAddress}']
    }
    gatewayIpAddress: hubVPNGWpip.properties.ipAddress
  }
}

// create Storage Account for Azure Files
resource storageAccount 'Microsoft.Storage/storageAccounts@2022-09-01' = {
  name: storageAccountName
  location: location
  sku: {
    name: 'Standard_LRS'
  }
  kind: 'StorageV2'
  properties: {
    accessTier: 'Hot'
  }
}

// ファイル共有の作成
resource fileShare 'Microsoft.Storage/storageAccounts/fileServices/shares@2022-09-01' = {
  name: '${storageAccountName}/default/${fileshareName}'
  properties: {
    shareQuota: 102400  // 100 TiB
  }
  dependsOn: [
    storageAccount
  ]
}

// プライベートDNSゾーンの作成
resource privateDnsZone 'Microsoft.Network/privateDnsZones@2020-06-01' = {
  name: storageDnsZone
  location: 'global'
}

// プライベートDNSゾーンと仮想ネットワークのリンク
resource privateDnsZoneVnetLink 'Microsoft.Network/privateDnsZones/virtualNetworkLinks@2020-06-01' = {
  name: '${storageAccountName}-vnetLink'
  parent: privateDnsZone
  location: 'global'
  properties: {
    virtualNetwork: {
      id: hubVNet.id
    }
    registrationEnabled: false
  }
}

// プライベートエンドポイントのリソース定義
resource privateEndpoint 'Microsoft.Network/privateEndpoints@2023-05-01' = {
  name: '${storageAccountName}-PE'
  location: location
  properties: {
    subnet: {
      id: hubVNet::hubPESubnet.id
    }
    privateLinkServiceConnections: [
      {
        name: 'myPrivateLinkServiceConnection'
        properties: {
          privateLinkServiceId: storageAccount.id
          groupIds: [
            'file'
          ]
        }
      }
    ]
  }
  dependsOn: [
    privateDnsZone
  ]
}

// プライベートエンドポイントとプライベートDNSゾーンの関連付け
resource privateDnsZoneGroup 'Microsoft.Network/privateEndpoints/privateDnsZoneGroups@2021-02-01' = {
  name: 'default'
  parent: privateEndpoint
  properties: {
    privateDnsZoneConfigs: [
      {
        name: 'config'
        properties: {
          privateDnsZoneId: privateDnsZone.id
        }
      }
    ]
  }
  dependsOn: [
    privateDnsZoneVnetLink
  ]
}

/*
------------------
output section
------------------
*/
// return the vpn gateway ID and LNG ID to use from parent template
output hubVPNGWId string = hubVPNGW.id
output hubLngId string = hubLng.id
