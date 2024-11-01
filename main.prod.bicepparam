using 'main.bicep'

param resourceGroupName = 'AzureFiles-RG'
param resourceGroupLocation = 'japaneast'
// ---- for Firewall Rule ----
// your ip address for SSH (ex. xxx.xxx.xxx.xxx)
param myipaddress = '124.37.254.233'
// ---- param for Hub ----
param hubVNetName = 'Hub-VNet'
param hubVNetAddress = '10.0.0.0/16'
param hubSubnetName1 = 'Hub-PESubnet'
param hubSubnetAddress1 = '10.0.10.0/24'
param hubSubnetName2 = 'Hub-DNSSubnet'
param hubSubnetAddress2 = '10.0.20.0/24'
param hubSubnetName3 = 'GatewaySubnet'
param hubSubnetAddress3 = '10.0.200.0/27'
// for VPN Gateway
param hubVPNGWName = 'azure-vpngw'
param hubLngName = 'Azure-LNG'
// for Azure Files
param baseStorageAccountName = 'files'
param fileshareName = 'smb01'
// ---- param for Onpre ----
// VNet #1
param onpreVNetName = 'Onpre-VNet' 
param onpreVNetAddress = '172.16.0.0/16'
param onpreSubnetName1 = 'Onpre-VMSubnet'
param onpreSubnetAddress1 = '172.16.0.0/24'
param onpreSubnetName2 = 'GatewaySubnet'
param onpreSubnetAddress2 = '172.16.200.0/27'
param onprevmName1 = 'onpre-w2k22'
// VNet #2
param onpreVNet2Name = 'Onpre-ADVNet' 
param onpreVNet2Address = '172.20.0.0/16'
param onpreSubnet2Name1 = 'Onpre-ADSubnet'
param onpreSubnet2Address1 = '172.20.0.0/24'
param onprevmName2 = 'onpre-ad'
param onprevm2ip = '172.20.0.4'
// for VPN Gateway
param onpreVPNGWName = 'onpre-vpngw'
param onpreLngName = 'Onpre-LNG'
// ---- Common param for VM ----
param vmSizeWindows = 'Standard_B2ms'
param adminUserName = 'cloudadmin'
param adminPassword = 'msjapan1!msjapan1!'
// ---- Common param for VPNGW ----
param connectionsharedkey = 'msjapan1!msjapan1!'
