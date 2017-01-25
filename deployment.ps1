﻿param(
$localadminUserName = "LocalAdmin",
$storageRG = "LegacySG",
$storageName = "LegacyStandardSA",
$vnetName = "LegacyVnet",
$vnetRG = "LegacyVNETRG",
$vnetIPRange = "10.248.0.0/16",
$gatewaySubnetName = "GatewaySubnet",
$gatewaySubnetCIDR = "10.248.1.0/29",
$dmzSubnetName = "DmzSubnet",
$dmzSubnetCIDR = "10.248.4.0/22",
$mgmntSubnetName = "LhMgmtSubnet",
$mgmtSubnetCIDR = "10.248.36.0/22",
$medTrustSubnetName = "MedTrustSubnet",
$medTrustSubnetCIDR = "10.248.16.0/22",
$highTrustSubnetName = "HiTrustSubnet",
$highTrustSubnetCIDR = "10.248.20.0/22",
$noTrustSubnetName = "NoTrustSubnet",
$noTrustSubnetCIDR = "10.248.12.0/22",
$subscriptionName = "jorsmith-SCDEMO",
$panRGName = "PaloAltoRG",
$panVMName = "LHPanAz01",
$vmRGName = "TestVMRG",
$natVMRg = "NATVMRG",
$natVMNamePrefix = "lhNATvm0",
$deploymentLocation = "WestUS2",
$vnetTemplateUri = "https://raw.githubusercontent.com/lorax79/legacy/master/vnet.json",
$storageTemplateUri = "https://raw.githubusercontent.com/lorax79/legacy/master/storageaccount.json",
$panVMTemplateUri = "https://raw.githubusercontent.com/lorax79/legacy/master/panVM.json",
$natScriptUri = "https://raw.githubusercontent.com/lorax79/legacy/master/nat-iptables.sh",
$natVMUri = "https://raw.githubusercontent.com/lorax79/legacy/master/natVM.json",
$testVMTemplateUri = "https://raw.githubusercontent.com/lorax79/AzureTemplates/master/avm-base-bare.json",
$testVM1NamePrefix = "TestVM0",
$testVM2NamePrefix = "TestVM1"
)

##Login to an Azure Account and focus on the defined subscription
Login-AzureRmAccount
Get-AzureRmSubscription -SubscriptionName $subscriptionName | Select-AzureRmSubscription

$rgs = $storageRG,$vnetRG,$panRGName,$natVMRg,$vmRGName

##Build the Resource Groups to hold the resources if they do not exist
Write-Verbose "Checking Azure for Resource Groups and building them if necessary"
foreach ($rg in $rgs) {
    if(!(get-azurermresourcegroup -Name $rg))
    {
    New-AzureRmResourceGroup -Name $rg -Location $deploymentLocation
    }
}

##Start Section - Build VNET
#Create the params hash

$vnetParams = @{
    'vnetName' = $vnetName;
    'vnetAddressPrefix' = $vnetIPRange;
    'subnet1Prefix' = $gatewaySubnetCIDR;
    'subnet1Name' = $gatewaySubnetCIDR;
    'subnet2Prefix' = $dmzSubnetCIDR;
    'subnet2Name' = $dmzSubnetName;
    'subnet3Prefix' = $medTrustSubnetCIDR;
    'subnet3Name' = $medTrustSubnetCIDR;
    'subnet4Prefix' = $highTrustSubnetCIDR;
    'subnet4Name' = $highTrustSubnetName;
    'subnet5Prefix' = $mgmtSubnetCIDR;
    'subnet5Name' = $mgmntSubnetName;
    'subnet6Prefix' = $noTrustSubnetCIDR;
    'subnet6Name' = $noTrustSubnetName
}

#Check for and Deploy the Vnet if it doesn't exist

if (!(Get-AzureRmVirtualNetwork -Name $vnetName -ResourceGroupName $vnetRG)) {
Write-Verbose "Deploying the Vnet $vnetName"
try {
    New-AzureRmResourceGroupDeployment -Name VNet -ResourceGroupName $vnetRG -Mode Incremental -TemplateUri $vnetTemplateUri -TemplateParameterObject $vnetParams
    }
catch {
    throw "Error creating Vnet. Stopping deployment, check the error logs"
    }
}

##Start Section - Build Storage Account
#Create storage the params hash

$storageParams = @{
    'storageAccountName' = $storageName;
}

#Check for and Deploy the Storage Account if it doesn't exist

if (!(Get-AzureRmStorageAccount -Name $storageName -ResourceGroupName $storageRG)) {
Write-Verbose "Deploying the Storage Account $storageName"
try {
    New-AzureRmResourceGroupDeployment -Name Storage -ResourceGroupName $storageRG -Mode Incremental -TemplateUri $storageTemplateUri -TemplateParameterObject $storageParams
    }
catch {
    throw "Error Creating the Storage Account. Deployment Stopped, please check the logs"
    }
}

#Start Section - Build PAN VM
#Create the params hash
$panParams = @{
    'location' = $deploymentLocation;
    'vmName' = $panVMName;
    'virtualNetworkName' = $vnetName;
    'virtualNetworkAddressPrefix' = $vnetIPRange;
    'virtualNetworkExistingRGName' = $vnetRG;
    'subnet0Name' = $mgmntSubnetName;
    'subnet1Name' = $dmzSubnetName;
    'subnet2Name' = $noTrustSubnetName;
    'subnet0Prefix' = $mgmtSubnetCIDR;
    'subnet1Prefix' = $dmzSubnetCIDR;
    'subnet2Prefix' = $noTrustSubnetCIDR;
    'subnet0StartAddress' = "10.248.36.4";
    'subnet1StartAddress' = "10.248.4.4";
    'subnet2StartAddress' = "10.248.12.4";
    'adminUsername' = $localadminUserName;
    'PublicIPRGName' = $vnetRG;
    'PublicIPAddressName' = "lhPANPublicIP";
    'storageAccountName' = $storageName;
    'storageAccountExistingRG' = $storageRG;
}

#Check for Palo Alto VM and deploy if it doesn't exist

if (!(Get-AzureRmVM -Name $panVMName -ResourceGroupName $panRGName)) {
Write-Verbose "Deploying Palo Alto VM"
try {
    New-AzureRmResourceGroupDeployment -Name PANVM -ResourceGroupName $panRGName -Mode Incremental -TemplateUri $panVMTemplateUri -TemplateParameterObject $panParams
    }
catch {
    throw "Error Deploying the Palo Alto VM.  Check the error logs for details"
    }
}

#Start Section - Build NAT VM
#Build the Params Object
$natVMParams = @{
    'adminUsername' = $localadminUserName;
    'vmNamePrefix' = $natVMNamePrefix;
    'virtualNetworkName' = $vnetName;
    'virtualNetworkResouceGroup' = $vnetRG;
    'subnetName' = $dmzSubnetName;
    'storageAccountName' = $storageName;
    'fileUris' = $natScriptUri;
    'commandToExecute' = "sh nat-iptables.sh";
    'publicIpAddressName' = "lhNatVMPublicIP";
    'networkSecurityGroupName' = "lhNatNSG"
}

#Check for the NAT VM and deploy if it doesn't exist

if (!(Get-AzureRmVM -Name ($natvmname + '0') -ResourceGroupName $natVMRg)) {
Write-Verbose "Deploying NAT VM"
try {
    New-AzureRmResourceGroupDeployment -Name NATVM -ResourceGroupName $natVMRg -Mode Incremental -TemplateUri $natVMUri -TemplateParameterObject $natVMParams
    }
catch {
    throw "Error creating NAT VM. Check the error logs"
    }
}
else {
    Write-Verbose "NAT VM Exists. Continuing"
    }

#Build the params for the test VMs
$testvm1parmas = @{
    'adminUsername' = $localadminUserName;
    'vmNamePrefix' = $testVM1NamePrefix;
    'virtualNetworkName' = $vnetName;
    'virtualNetworkResourceGroup' = $vnetRG;
    'subnetName' = $noTrustSubnetName;
    'storageAccountName' = $storageName
}

$testvm2params = @{
    'adminUsername' = $localadminUserName;
    'vmNamePrefix' = $testVM2NamePrefix;
    'virtualNetworkName' = $vnetName;
    'virtualNetworkResourceGroup' = $vnetRG;
    'subnetName' = $medTrustSubnetName;
    'storageAccountName' = $storageName
}

#Check for test VM 1 and deploy if it doesn't Exist

if (!(Get-AzureRmVM -Name ($testVM1NamePrefix + '0') -ResourceGroupName $vmRGName)) {
Write-Verbose "Deploying 1st TestVM to subnet $($testvm1params).subnetname.value"
try {
    New-AzureRmResourceGroupDeployment -Name TestVM1 -ResourceGroupName $vmRGName -Mode Incremental -TemplateUri $testVMTemplateUri -TemplateParameterObject $testvm1parmas
    }
catch {
    throw "Error creating TestVM1. See Error Logs"
    }
}
else {
    Write-Verbose "The TestVM1 Exists already. Continuing"
    }

#Check for test VM2 and deploy if it doesn't Exist

if (!(Get-AzureRmVM -Name ($testVM2NamePrefix + '0') -ResourceGroupName $vmRGName)) {
Write-Verbose "Deploying 2nd TestVM to subnet $($testvm2params).subnetname.value"
try {
    New-AzureRmResourceGroupDeployment -Name TestVM1 -ResourceGroupName $vmRGName -Mode Incremental -TemplateUri $testVMTemplateUri -TemplateParameterObject $testvm2parmas
    }
catch {
    throw "Error creating TestVM2. See Error Logs"
    }
}
else {
    Write-Verbose "The TestVM2 Exists already. Continuing"
    }
