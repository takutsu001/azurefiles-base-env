/*
------------------
param section
------------------
*/
// Common
param location string
param myipaddress string
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
// VM Subnet
param onpreSubnet2Name1 string
param onpreSubnet2Address1 string
// for VM
param onprevmName1 string
param onprevmName2 string
param onprevm2ip string
param vmSizeWindows string
@secure()
param adminUserName string
@secure()
param adminPassword string
// for VPN Gateway
param onpreVPNGWName string
param onpreLngName string

/*
------------------
var section
------------------
*/
// VNet1 VM Subnet
var onpreSubnet1 = { 
  name: onpreSubnetName1 
  properties: { 
    addressPrefix: onpreSubnetAddress1
    networkSecurityGroup: {
    id: nsgDefault.id
    }
  }
}
// VNet1 VPN Gateway Subnet
var onpreSubnet2 = { 
  name: onpreSubnetName2 
  properties: { 
    addressPrefix: onpreSubnetAddress2
  }
} 
// VNet2 VM Subnet
var onpreSubnet3 = { 
  name: onpreSubnet2Name1 
  properties: { 
    addressPrefix: onpreSubnet2Address1
    networkSecurityGroup: {
    id: nsgDefault2.id
    }
  }
}

/*
------------------
resource section
------------------
*/

// create network security group for onpre vnet1
resource nsgDefault 'Microsoft.Network/networkSecurityGroups@2023-04-01' = {
  name: '${onpreVNetName}-nsg'
  location: location
  properties: {
  //  securityRules: [
  //    {
  //     name: 'Allow-SSH'
  //      properties: {
  //      description: 'description'
  //      protocol: 'TCP'
  //      sourcePortRange: '*'
  //      destinationPortRange: '22'
  //      sourceAddressPrefix: myipaddress
  //      destinationAddressPrefix: '*'
  //      access: 'Allow'
  //      priority: 1000
  //      direction: 'Inbound'
  //    }
  //  }
  //]
  }
}

// create network security group for onpre vnet2
resource nsgDefault2 'Microsoft.Network/networkSecurityGroups@2023-04-01' = {
  name: '${onpreVNet2Name}-nsg'
  location: location
  properties: {
    securityRules: [
      {
       name: 'Allow-RDP'
        properties: {
        description: 'description'
        protocol: 'TCP'
        sourcePortRange: '*'
        destinationPortRange: '3389'
        sourceAddressPrefix: myipaddress
        destinationAddressPrefix: '*'
        access: 'Allow'
        priority: 1000
        direction: 'Inbound'
        }
      }
    ]
  }
}

// create onpreVNet & onpreSubnet (VNet1)
resource onpreVNet 'Microsoft.Network/virtualNetworks@2021-05-01' = { 
  name: onpreVNetName 
  location: location 
  properties: { 
    addressSpace: { 
      addressPrefixes: [ 
        onpreVNetAddress 
      ] 
    } 
    subnets: [ 
      onpreSubnet1
      onpreSubnet2
    ]
  }
  // Get subnet information where VMs are connected.
  resource onpreVMSubnet 'subnets' existing = {
    name: onpreSubnetName1
  }
  // Get subnet information where VPN Gateway is connected.
  resource onpreGatewaySubnet 'subnets' existing = {
    name: onpreSubnetName2
  }
}

// create onpre-ADVNet & onpreADSubnet (VNet2)
resource onpreVNet2 'Microsoft.Network/virtualNetworks@2021-05-01' = { 
  name: onpreVNet2Name 
  location: location 
  properties: { 
    addressSpace: { 
      addressPrefixes: [ 
        onpreVNet2Address 
      ] 
    } 
    subnets: [ 
      onpreSubnet3
    ]
  }
  // Get subnet information where VMs are connected.
  resource onpreADSubnet 'subnets' existing = {
    name: onpreSubnet2Name1 
  }
}

// Virtual network peering between Onpre-VNet to Onpre-ADVNet
resource peeringOnpre2OnpreAD 'Microsoft.Network/virtualNetworks/virtualNetworkPeerings@2023-04-01' = {
  name: 'Onpre-to-OnpreAD-peering'
  parent: onpreVNet
  properties: {
    remoteVirtualNetwork: {
      id: onpreVNet2.id
    }
    allowVirtualNetworkAccess: true
    allowForwardedTraffic: true
    allowGatewayTransit: true
    useRemoteGateways: false
    remoteAddressSpace: {
      addressPrefixes: ['${onpreVNet2}']
    }
    remoteVirtualNetworkAddressSpace: {
      addressPrefixes: ['${onpreVNet2}']
    }
  }
  dependsOn: [
    onpreVPNGW
  ]
}

// Virtual network peering between Onpre-ADVNet to Onpre-VNet
resource peeringOnpreAD2Onpre 'Microsoft.Network/virtualNetworks/virtualNetworkPeerings@2023-04-01' = {
  name: 'OnpreAD-to-Onpre-peering'
  parent: onpreVNet2
  properties: {
    remoteVirtualNetwork: {
      id: onpreVNet.id
    }
    allowVirtualNetworkAccess: true
    allowForwardedTraffic: true
    allowGatewayTransit: false
    useRemoteGateways: true
    remoteAddressSpace: {
      addressPrefixes: ['${onpreVNet}']
    }
    remoteVirtualNetworkAddressSpace: {
      addressPrefixes: ['${onpreVNet}']
    }
  }
  dependsOn: [
    onpreVPNGW
  ]
}

// create VM in VNet1
// create network interface for Windows VM
resource networkInterface1 'Microsoft.Network/networkInterfaces@2023-04-01' = {
  name: '${onprevmName1}-nic'
  location: location
  properties: {
    ipConfigurations: [
      {
        name: 'ipconfig1'
        properties: {
          privateIPAllocationMethod: 'Dynamic'
          subnet: {
            id: onpreVNet::onpreVMSubnet.id
          }
        }
      }
    ]
  }
}

// create Windows vm in VNet1
resource winVM1 'Microsoft.Compute/virtualMachines@2023-03-01' = {
  name: onprevmName1
  location: location
  properties: {
    hardwareProfile: {
      vmSize: vmSizeWindows
    }
    osProfile: {
      computerName: onprevmName1
      adminUsername: adminUserName
      adminPassword: adminPassword
    }
    storageProfile: {
      imageReference: {
        publisher: 'MicrosoftWindowsServer'
        offer: 'WindowsServer'
        sku: '2022-datacenter-smalldisk-g2'
        version: 'latest'
      }
      osDisk: {
        name: '${onprevmName1}-disk'
        caching: 'ReadWrite'
        createOption: 'FromImage'
        managedDisk: {
          storageAccountType: 'Standard_LRS'
        }
      }
    }
    networkProfile: {
      networkInterfaces: [
        {
          id: networkInterface1.id
        }
      ]
    }
    diagnosticsProfile: {
      bootDiagnostics: {
        enabled: false
      }
    }
  }
}

// create VM in VNet2
// create public ip address for Windows VM
resource publicIp 'Microsoft.Network/publicIPAddresses@2022-05-01' = {
  name: '${onprevmName2}-pip'
  location: location
  sku: {
    name: 'Standard'
  }
  properties: {
    publicIPAllocationMethod: 'Static'
    publicIPAddressVersion: 'IPv4'
  }
}

// create network interface for Windows VM in VNet2
resource networkInterface2 'Microsoft.Network/networkInterfaces@2023-04-01' = {
  name: '${onprevmName2}-nic'
  location: location
  properties: {
    ipConfigurations: [
      {
        name: 'ipconfig1'
        properties: {
          privateIPAllocationMethod: 'Static'
          privateIPAddress: onprevm2ip
          publicIPAddress: {
            id: publicIp.id
          }
          subnet: {
            id: onpreVNet2::onpreADSubnet.id
          }
        }
      }
    ]
  }
}

// create Windows vm in VNet2
resource winVM2 'Microsoft.Compute/virtualMachines@2023-03-01' = {
  name: onprevmName2
  location: location
  properties: {
    hardwareProfile: {
      vmSize: vmSizeWindows
    }
    osProfile: {
      computerName: onprevmName2
      adminUsername: adminUserName
      adminPassword: adminPassword
    }
    storageProfile: {
      imageReference: {
        publisher: 'MicrosoftWindowsServer'
        offer: 'WindowsServer'
        sku: '2022-datacenter-smalldisk-g2'
        version: 'latest'
      }
      osDisk: {
        name: '${onprevmName2}-disk'
        caching: 'ReadWrite'
        createOption: 'FromImage'
        managedDisk: {
          storageAccountType: 'Standard_LRS'
        }
      }
    }
    networkProfile: {
      networkInterfaces: [
        {
          id: networkInterface2.id
        }
      ]
    }
    diagnosticsProfile: {
      bootDiagnostics: {
        enabled: false
      }
    }
  }
}

// create public ip address for VPN Gateway
resource onpreVPNGWpip 'Microsoft.Network/publicIPAddresses@2022-05-01' = {
  name: '${onpreVPNGWName}-pip'
  location: location
  sku: {
    name: 'Standard'
  }
  properties: {
    publicIPAllocationMethod: 'Static'
    publicIPAddressVersion: 'IPv4'
  }
}

// create VPN Gateway for Onpre (RouteBased)
resource onpreVPNGW 'Microsoft.Network/virtualNetworkGateways@2023-06-01' = {
  name: onpreVPNGWName
  location: location
  properties: {
    enablePrivateIpAddress: false
    ipConfigurations: [
      {
        name: '${onpreVPNGWName}-ipconfig'
        properties: {
          privateIPAllocationMethod: 'Dynamic'
          publicIPAddress: {
            id: onpreVPNGWpip.id
          }
          subnet: {
            id: onpreVNet::onpreGatewaySubnet.id
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
resource onpreLng 'Microsoft.Network/localNetworkGateways@2023-06-01' = {
  name: onpreLngName
  location: location
  properties: {
    localNetworkAddressSpace: {
      addressPrefixes: ['${onpreVNetAddress}','${onpreVNet2Address}']
    }
    gatewayIpAddress: onpreVPNGWpip.properties.ipAddress
  }
}


/*
------------------
output section
------------------
*/
// return the private ip address of the vm to use from parent template
@description('return the private ip address of the vm to use from parent template')
output vmPrivateIp1 string = networkInterface1.properties.ipConfigurations[0].properties.privateIPAddress
output vmPrivateIp2 string = networkInterface2.properties.ipConfigurations[0].properties.privateIPAddress

// return the vpn gateway ID and LNG ID to use from parent template
output onpreVPNGWId string = onpreVPNGW.id
output onpreLngId string = onpreLng.id
