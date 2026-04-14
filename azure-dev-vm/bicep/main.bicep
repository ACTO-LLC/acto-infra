// ---------------------------------------------------------------------------
// Ubuntu Dev VM — Bicep template
// Deploys a Trusted Launch Ubuntu Pro 24.04 VM with SSH key auth,
// a 512 GB Premium SSD data disk, AAD SSH login, and auto-shutdown.
// ---------------------------------------------------------------------------

@description('Location for all resources')
param location string = resourceGroup().location

@description('VM name (also used as prefix for related resources)')
param vmName string = 'ehalsey-dev01-vm'

@description('Admin username')
param adminUsername string = 'ehalsey'

@description('SSH public key for the admin user')
@secure()
param sshPublicKey string

@description('VM size')
param vmSize string = 'Standard_D16s_v5'

@description('OS disk size in GB')
param osDiskSizeGB int = 30

@description('Data disk size in GB')
param dataDiskSizeGB int = 512

@description('VNet address space')
param vnetAddressPrefix string = '10.0.0.0/16'

@description('Subnet address prefix')
param subnetAddressPrefix string = '10.0.0.0/24'

@description('DNS label for the public IP (results in <label>.<region>.cloudapp.azure.com)')
param dnsLabel string = 'ehalsey-dev01'

@description('Auto-shutdown time in 24h format (HHMM)')
param autoShutdownTime string = '1900'

@description('Auto-shutdown time zone (Windows time zone ID — e.g. "Pacific Standard Time" auto-handles DST)')
param autoShutdownTimeZone string = 'Pacific Standard Time'

@description('Allowed source IP addresses for SSH (CIDR or single IP)')
param allowedSshSources array = [
  '98.147.230.90'
]

@description('Resource tags')
param tags object = {
  client: 'acto'
  environment: 'production'
}

// ---------------------------------------------------------------------------
// Naming
// ---------------------------------------------------------------------------
var publicIpName = '${vmName}-ip'
var nicName = '${vmName}-nic'
var nsgName = '${vmName}-nsg'
var vnetName = '${vmName}-vnet'
var subnetName = 'default'
var dataDiskName = '${vmName}_DataDisk_0'

// ---------------------------------------------------------------------------
// Network Security Group — SSH only
// ---------------------------------------------------------------------------
resource nsg 'Microsoft.Network/networkSecurityGroups@2023-04-01' = {
  name: nsgName
  location: location
  tags: tags
  properties: {
    securityRules: [
      {
        name: 'SSH'
        properties: {
          priority: 300
          direction: 'Inbound'
          access: 'Allow'
          protocol: 'Tcp'
          sourceAddressPrefixes: allowedSshSources
          sourcePortRange: '*'
          destinationAddressPrefix: '*'
          destinationPortRange: '22'
        }
      }
    ]
  }
}

// ---------------------------------------------------------------------------
// Virtual Network + Subnet
// ---------------------------------------------------------------------------
resource vnet 'Microsoft.Network/virtualNetworks@2023-04-01' = {
  name: vnetName
  location: location
  tags: tags
  properties: {
    addressSpace: {
      addressPrefixes: [
        vnetAddressPrefix
      ]
    }
    subnets: [
      {
        name: subnetName
        properties: {
          addressPrefix: subnetAddressPrefix
        }
      }
    ]
  }
}

// ---------------------------------------------------------------------------
// Static Public IP (Standard SKU)
// ---------------------------------------------------------------------------
resource publicIp 'Microsoft.Network/publicIPAddresses@2023-04-01' = {
  name: publicIpName
  location: location
  tags: tags
  sku: {
    name: 'Standard'
    tier: 'Regional'
  }
  properties: {
    publicIPAllocationMethod: 'Static'
    publicIPAddressVersion: 'IPv4'
    dnsSettings: {
      domainNameLabel: dnsLabel
    }
  }
}

// ---------------------------------------------------------------------------
// Network Interface
// ---------------------------------------------------------------------------
resource nic 'Microsoft.Network/networkInterfaces@2023-04-01' = {
  name: nicName
  location: location
  tags: tags
  properties: {
    ipConfigurations: [
      {
        name: 'ipconfig1'
        properties: {
          privateIPAllocationMethod: 'Dynamic'
          publicIPAddress: {
            id: publicIp.id
          }
          subnet: {
            id: vnet.properties.subnets[0].id
          }
        }
      }
    ]
    networkSecurityGroup: {
      id: nsg.id
    }
  }
}

// ---------------------------------------------------------------------------
// Virtual Machine — Ubuntu Pro 24.04 LTS, Trusted Launch, SSH key auth
// ---------------------------------------------------------------------------
resource vm 'Microsoft.Compute/virtualMachines@2023-09-01' = {
  name: vmName
  location: location
  tags: tags
  identity: {
    type: 'SystemAssigned'
  }
  properties: {
    hardwareProfile: {
      vmSize: vmSize
    }
    osProfile: {
      computerName: vmName
      adminUsername: adminUsername
      linuxConfiguration: {
        disablePasswordAuthentication: true
        provisionVMAgent: true
        ssh: {
          publicKeys: [
            {
              path: '/home/${adminUsername}/.ssh/authorized_keys'
              keyData: sshPublicKey
            }
          ]
        }
        patchSettings: {
          assessmentMode: 'AutomaticByPlatform'
          patchMode: 'ImageDefault'
        }
      }
    }
    securityProfile: {
      securityType: 'TrustedLaunch'
      uefiSettings: {
        secureBootEnabled: true
        vTpmEnabled: true
      }
    }
    storageProfile: {
      imageReference: {
        publisher: 'canonical'
        offer: 'ubuntu-24_04-lts'
        sku: 'ubuntu-pro'
        version: 'latest'
      }
      osDisk: {
        createOption: 'FromImage'
        diskSizeGB: osDiskSizeGB
        deleteOption: 'Delete'
        managedDisk: {
          storageAccountType: 'Premium_LRS'
        }
      }
      dataDisks: [
        {
          lun: 0
          name: dataDiskName
          createOption: 'Empty'
          diskSizeGB: dataDiskSizeGB
          caching: 'ReadOnly'
          deleteOption: 'Delete'
          managedDisk: {
            storageAccountType: 'Premium_LRS'
          }
        }
      ]
    }
    networkProfile: {
      networkInterfaces: [
        {
          id: nic.id
          properties: {
            deleteOption: 'Detach'
          }
        }
      ]
    }
    diagnosticsProfile: {
      bootDiagnostics: {
        enabled: true
      }
    }
  }
}

// ---------------------------------------------------------------------------
// AAD SSH Login Extension
// ---------------------------------------------------------------------------
resource aadSshExtension 'Microsoft.Compute/virtualMachines/extensions@2023-09-01' = {
  parent: vm
  name: 'AADSSHLoginForLinux'
  location: location
  tags: tags
  properties: {
    publisher: 'Microsoft.Azure.ActiveDirectory'
    type: 'AADSSHLoginForLinux'
    typeHandlerVersion: '1.0'
    autoUpgradeMinorVersion: true
  }
}

// ---------------------------------------------------------------------------
// Auto-shutdown schedule
// ---------------------------------------------------------------------------
resource autoShutdown 'Microsoft.DevTestLab/schedules@2018-09-15' = {
  name: 'shutdown-computevm-${vmName}'
  location: location
  properties: {
    status: 'Enabled'
    taskType: 'ComputeVmShutdownTask'
    dailyRecurrence: {
      time: autoShutdownTime
    }
    timeZoneId: autoShutdownTimeZone
    targetResourceId: vm.id
  }
}

// ---------------------------------------------------------------------------
// Outputs
// ---------------------------------------------------------------------------
output vmPublicIp string = publicIp.properties.ipAddress
output vmFqdn string = publicIp.properties.dnsSettings.fqdn
output vmName string = vm.name
output adminUsername string = adminUsername
output sshCommand string = 'ssh -i ~/.ssh/${vmName}_key.pem ${adminUsername}@${publicIp.properties.dnsSettings.fqdn}'
