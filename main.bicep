targetScope = 'subscription'

/*
------------------
param section
------------------
*/

// ---- param for Common ----
param resourceGroupName string
param resourceGroupLocation string
param myipaddress string

// ---- param for Hub ----
param hubVNetName string
param hubVNetAddress string
// VM Subnet
param hubSubnetName1 string 
param hubSubnetAddress1 string
// Firewall Subnet
param hubSubnetName2 string 
param hubSubnetAddress2 string
// VPN Gateway Subnet
param hubSubnetName3 string
param hubSubnetAddress3 string
// Azure Files
param baseStorageAccountName string
param fileshareName string

// ---- param for Onpre ----
// VNet #1
param onpreVNetName string
param onpreVNetAddress string
// VM Subnet
param onpreSubnetName1 string 
param onpreSubnetAddress1 string
// VPN Gateway Subnet
param onpreSubnetName2 string
param onpreSubnetAddress2 string
// VNet #2
param onpreVNet2Name string
param onpreVNet2Address string
// AD Subnet
param onpreSubnet2Name1 string 
param onpreSubnet2Address1 string

// ---- param for VM ----
param vmSizeWindows string
param onprevmName1 string
param onprevmName2 string
param onprevm2ip string
@secure()
param adminUserName string
@secure()
param adminPassword string

// ---- param for VPN Gateway ----
// Azure VPN Gateway
param hubVPNGWName string
param hubLngName string
// Onpre VPN Gateway
param onpreVPNGWName string
param onpreLngName string
// VPN Connection shared key (PSK)
@secure()
param connectionsharedkey string

/*
------------------
resource section
------------------
*/

resource newRG 'Microsoft.Resources/resourceGroups@2021-04-01' = { 
  name: resourceGroupName 
  location: resourceGroupLocation 
} 

/*
---------------
module section
---------------
*/

// Create Hub Environment (VM-Linux VNet, Subnet, NSG, VNet Peering, VPN Gateway, Local Network Gateway)
module HubModule './modules/hubEnv.bicep' = { 
  scope: newRG 
  name: 'CreateHubEnv' 
  params: { 
    location: resourceGroupLocation
    hubVNetName: hubVNetName
    hubVNetAddress: hubVNetAddress
    hubSubnetName1: hubSubnetName1
    hubSubnetAddress1: hubSubnetAddress1
    hubSubnetName2: hubSubnetName2
    hubSubnetAddress2: hubSubnetAddress2
    hubSubnetName3: hubSubnetName3
    hubSubnetAddress3: hubSubnetAddress3
    hubVPNGWName: hubVPNGWName
    hubLngName: hubLngName
    baseStorageAccountName: baseStorageAccountName
    fileshareName: fileshareName
  } 
}

// Create Onpre Environment (VM-Linux VNet, Subnet, NSG, Vnet Peering, VPN Gateway, Local Network Gateway)
module OnpreModule './modules/onpreEnv.bicep' = { 
  scope: newRG 
  name: 'CreateOnpreEnv' 
  params: { 
    location: resourceGroupLocation
    myipaddress: myipaddress
    onpreVNetName: onpreVNetName
    onpreVNetAddress: onpreVNetAddress
    onpreSubnetName1: onpreSubnetName1
    onpreSubnetAddress1: onpreSubnetAddress1
    onpreSubnetName2: onpreSubnetName2
    onpreSubnetAddress2: onpreSubnetAddress2
    onpreVNet2Name: onpreVNet2Name
    onpreVNet2Address: onpreVNet2Address
    onpreSubnet2Name1: onpreSubnet2Name1
    onpreSubnet2Address1: onpreSubnet2Address1
    onprevmName1: onprevmName1
    onprevmName2: onprevmName2
    onprevm2ip: onprevm2ip
    vmSizeWindows: vmSizeWindows
    adminUserName: adminUserName
    adminPassword: adminPassword
    onpreVPNGWName: onpreVPNGWName
    onpreLngName: onpreLngName
  } 
}

// Create Connection for Onpre VPN Gateway and Azure VPN Gateway
module VPNConnectionModule './modules/vpnConnection.bicep' = { 
  scope: newRG 
  name: 'CreateVPNConnection' 
  params: { 
    location: resourceGroupLocation
    hubVPNGWID: HubModule.outputs.hubVPNGWId
    hubLngID: HubModule.outputs.hubLngId
    onpreVPNGWID: OnpreModule.outputs.onpreVPNGWId
    onpreLngID: OnpreModule.outputs.onpreLngId
    connectionsharedkey: connectionsharedkey
  } 
  dependsOn: [
    HubModule
    OnpreModule
  ]
}
