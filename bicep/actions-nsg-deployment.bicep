@description('NSG for outbound rules')
param location string
param nsgName string = 'actions_NSG'

resource actions_NSG 'Microsoft.Network/networkSecurityGroups@2017-06-01' = {
  name: nsgName
  location: location
  properties: {
    securityRules: [
      {
        name: 'AllowVnetOutBoundOverwrite'
        properties: {
          protocol: 'TCP'
          sourcePortRange: '*'
          destinationPortRange: '443'
          sourceAddressPrefix: '*'
          destinationAddressPrefix: 'VirtualNetwork'
          access: 'Allow'
          priority: 200
          direction: 'Outbound'
          destinationAddressPrefixes: []
        }
      }
      {
        name: 'AllowOutBoundActions'
        properties: {
          protocol: '*'
          sourcePortRange: '*'
          destinationPortRange: '443'
          sourceAddressPrefix: '*'
          access: 'Allow'
          priority: 210
          direction: 'Outbound'
          destinationAddressPrefixes: [
            '4.175.114.51/32'
            '20.102.35.120/32'
            '4.175.114.43/32'
            '20.72.125.48/32'
            '20.19.5.100/32'
            '20.7.92.46/32'
            '20.232.252.48/32'
            '52.186.44.51/32'
            '20.22.98.201/32'
            '20.246.184.240/32'
            '20.96.133.71/32'
            '20.253.2.203/32'
            '20.102.39.220/32'
            '20.81.127.181/32'
            '52.148.30.208/32'
            '20.14.42.190/32'
            '20.81.21.200/32'
            '20.66.121.71/32'
            '20.81.8.110/32'
            '20.65.207.130/32'
            '20.98.179.254/32'
            '20.231.112.196/32'
            '20.161.7.250/32'
            '20.236.57.184/32'
            '20.242.119.231/32'
          ]
          sourceAddressPrefixes: []
        }
      }
      {
        name: 'AllowOutBoundNotifications'
        properties: {
          protocol: '*'
          sourcePortRange: '*'
          destinationPortRange: '443'
          sourceAddressPrefix: '*'
          destinationAddressPrefix: 'EventHub'
          access: 'Allow'
          priority: 220
          direction: 'Outbound'
          destinationAddressPrefixes: []
        }
      }
      {
        name: 'AllowOutBoundGitHub'
        properties: {
          protocol: 'TCP'
          sourcePortRange: '*'
          destinationPortRange: '443'
          sourceAddressPrefix: '*'
          destinationAddressPrefix: 'Internet'
          access: 'Allow'
          priority: 230
          direction: 'Outbound'
          destinationAddressPrefixes: []
        }
      }
      {
        name: 'AllowOutBoundDns'
        properties: {
          protocol: '*'
          sourcePortRange: '*'
          destinationPortRange: '53'
          sourceAddressPrefix: '*'
          destinationAddressPrefix: 'Internet'
          access: 'Allow'
          priority: 240
          direction: 'Outbound'
          destinationAddressPrefixes: []
        }
      }
      {
        name: 'DenyOutBoundInternet'
        properties: {
          protocol: '*'
          sourcePortRange: '*'
          destinationPortRange: '*'
          sourceAddressPrefix: '*'
          destinationAddressPrefix: 'Internet'
          access: 'Deny'
          priority: 250
          direction: 'Outbound'
          destinationAddressPrefixes: []
        }
      }
    ]
  }
}

output nsgId string = actions_NSG.id
output nsgName string = actions_NSG.name
