param(
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
$vnetTemplateUri = "",
$storageTemplateUri = "",
$panVMTemplateUri = "",
$natScriptUri = "",
$natVMUri = "",
)

##Login to an Azure Account and focus on the defined subscription
Login-AzureRmAccount
Get-AzureRmSubscription -SubscriptionName $subscriptionName | Select-AzureRmSubscription

$rgs = $storageRG,$vnetRG,$panRGName,$natVMRg,$vmRGName

##Build the Resource Groups to hold the resources and perform the deployments
foreach ($rg in $rgs) {
    New-AzureRmResourceGroup -Name $rg -Location $deploymentLocation
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
#Deploy the Vnet
New-AzureRmResourceGroupDeployment -Name VNet -ResourceGroupName $vnetRG -Mode Incremental -TemplateUri $vnetTemplateUri -TemplateParameterObject $vnetParams

##Start Section - Build Storage Account
#Create the params hash
$storageParams = @{
    'storageAccountName' = $storageName;
}

#Deploy the Storage Account
New-AzureRmResourceGroupDeployment -Name Storage -ResourceGroupName $storageRG -Mode Incremental -TemplateUri $storageTemplateUri -TemplateParameterObject $storageParams

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

#Start resource deployment
New-AzureRmResourceGroupDeployment -Name PANVM -ResourceGroupName $panRGName -Mode Incremental -TemplateUri $panVMTemplateUri -TemplateParameterObject $panParams

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

#Start the resource deployment
New-AzureRmResourceGroupDeployment -Name NATVM -ResourceGroupName $natVMRg -Mode Incremental -TemplateUri $natVMUri -TemplateParameterObject $natVMParams

