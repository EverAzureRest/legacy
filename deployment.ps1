[cmdletbinding()]
param(
[Parameter(Mandatory=$True)]
$localadminUserName,
$storageRG = "LegacySG",
$storageName = "legacystandardsa",
$vnetName = "LegacyVnet",
$vnetRG = "LegacyVNETRG",
$vnetIPRange = "10.248.0.0/16",
$untrustSubnetName = "UntrustSubnet",
$untrustSubnetCIDR = "10.248.1.0/24",
$panUnTrustIP = "10.248.1.4",
$panPublicDNSName = "lhpanazpublicname",
$natSubnetName = "DmzSubnet",
$natSubnetCIDR = "10.248.4.0/22",
$mgmntSubnetName = "LhMgmtSubnet",
$mgmtSubnetCIDR = "10.248.36.0/22",
$panMgmtIP = "10.248.36.4",
$medTrustSubnetName = "MedTrustSubnet",
$medTrustSubnetCIDR = "10.248.16.0/22",
$highTrustSubnetName = "HiTrustSubnet",
$highTrustSubnetCIDR = "10.248.20.0/22",
$noTrustSubnetName = "NoTrustSubnet",
$noTrustSubnetCIDR = "10.248.12.0/22",
$panTrustIP = "10.248.12.4",
[Parameter(Mandatory=$True)]
$subscriptionName,
$panRGName = "PaloAltoRG",
$panVMName = "LHPanAz01",
$panVMLicense = "byol",
$vmRGName = "TestVMRG",
$natVMRg = "NATVMRG",
$natPublicIP = "lhNatVMPublicIP",
$natVMNamePrefix = "lhNATvm0",
$deploymentLocation = "WestUS2",
$baseuri = "https://raw.githubusercontent.com/lorax79/legacy/master",
#to use locally, clone the $baseuri using git and dot source from the cloned directory. Don't forget to change the $basuri to the local cloned repository
$vnetTemplateUri = "$baseuri/vnet.json",
$storageTemplateUri = "$baseuri/storageaccount.json",
$panVMTemplateUri = "$baseuri/panVM.json",
$natVMUri = "$baseuri/natVM.json",
$testVMTemplateUri = "$baseuri/testvms.json",
$testVM1Name = "TestVM0",
$testVM2Name = "TestVM1",
[switch]$cleanup
)

##Login to an Azure Account and focus on the defined subscription
Login-AzureRmAccount
Get-AzureRmSubscription -SubscriptionName $subscriptionName | Select-AzureRmSubscription

$rgs = $panRGName,$natVMRg,$vmRGName,$storageRG,$vnetRG

#If cleanup switch is used, it will remove the entire environment
if ($cleanup) {
    Write-Verbose "Cleanup Switch Used. Deleting all resources defined in the deployment."
    foreach ($rg in $rgs) {
        Write-Verbose "Deleting Resource Group $rg and all of its resources..."
        Remove-AzureRmResourceGroup -Name $rg -Force -Confirm:$false
        }
    }
else {

##Build the Resource Groups to hold the resources if they do not exist
Write-Verbose "Checking Azure for Resource Groups and building them if necessary"
foreach ($rg in $rgs) {
    if(!(get-azurermresourcegroup -Name $rg -ErrorAction SilentlyContinue))
    {
    Write-Verbose "Building Resource Group $rg"
    New-AzureRmResourceGroup -Name $rg -Location $deploymentLocation
    }
}

##Start Section - Build VNET
#Create the params hash

$vnetParams = @{
    'vnetName' = $vnetName;
    'vnetAddressPrefix' = $vnetIPRange;
    'subnet1Prefix' = $untrustSubnetCIDR;
    'subnet1Name' = $untrustSubnetName
    'subnet2Prefix' = $natSubnetCIDR;
    'subnet2Name' = $natSubnetName;
    'subnet3Prefix' = $medTrustSubnetCIDR;
    'subnet3Name' = $medTrustSubnetName;
    'subnet4Prefix' = $highTrustSubnetCIDR;
    'subnet4Name' = $highTrustSubnetName;
    'subnet5Prefix' = $mgmtSubnetCIDR;
    'subnet5Name' = $mgmntSubnetName;
    'subnet6Prefix' = $noTrustSubnetCIDR;
    'subnet6Name' = $noTrustSubnetName
}

#Check for and Deploy the Vnet if it doesn't exist
Write-Verbose "Checking for VNET $vnetname"
if (!(Get-AzureRmVirtualNetwork -Name $vnetName -ResourceGroupName $vnetRG -ea SilentlyContinue)) {
Write-Verbose "Deploying the Vnet $vnetName"
try {
    New-AzureRmResourceGroupDeployment -Name VNet -ResourceGroupName $vnetRG -Mode Incremental -TemplateUri $vnetTemplateUri -TemplateParameterObject $vnetParams
    }
catch {
    throw "Error creating Vnet. Stopping deployment, check the error logs"
    }
}
else {
    Write-Verbose "VNET Exists. Continuing"
}

##Start Section - Build Storage Account
#Create storage the params hash

$storageParams = @{
    'storageAccountName' = $storageName;
}

#Check for and Deploy the Storage Account if it doesn't exist
Write-Verbose "Checking for Storage Account $storagename"
if (!(Get-AzureRmStorageAccount -Name $storageName -ResourceGroupName $storageRG -ea SilentlyContinue)) {
Write-Verbose "Deploying the Storage Account $storageName"
try {
    New-AzureRmResourceGroupDeployment -Name Storage -ResourceGroupName $storageRG -Mode Incremental -TemplateUri $storageTemplateUri -TemplateParameterObject $storageParams
    }
catch {
    throw "Error Creating the Storage Account. Deployment Stopped, please check the logs"
    }
}
else {
    Write-Verbose "Storage Account Exists. Continuing"
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
    'subnet1Name' = $untrustSubnetName;
    'subnet2Name' = $noTrustSubnetName;
    'subnet0Prefix' = $mgmtSubnetCIDR;
    'subnet1Prefix' = $untrustSubnetCIDR;
    'subnet2Prefix' = $noTrustSubnetCIDR;
    'subnet0StartAddress' = $panMgmtIP;
    'subnet1StartAddress' = $panUnTrustIP;
    'subnet2StartAddress' = $panTrustIP;
    'adminUsername' = $localadminUserName;
    'PublicIPRGName' = $vnetRG;
    'PublicIPAddressName' = $panPublicDNSName;
    'storageAccountName' = $storageName;
    'storageAccountExistingRG' = $storageRG;
    'licenseType' = $panVMLicense
}

#Check for Palo Alto VM and deploy if it doesn't exist
Write-Verbose "Checking for Palo Alto VM $panVMName"
if (!(Get-AzureRmVM -Name $panVMName -ResourceGroupName $panRGName -ea SilentlyContinue)) {
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
    'virtualNetworkResourceGroup' = $vnetRG;
    'subnetName' = $natSubnetName;
    'storageAccountName' = $storageName;
    'commandToExecute' = "sh nat-iptables.sh";
    'publicIpAddressName' = $natPublicIP;
    'networkSecurityGroupName' = "lhNatNSG"
}

#Check for the NAT VM and deploy if it doesn't exist
Write-Verbose "Checking for NAT VM"
if (!(Get-AzureRmVM -Name ($natVMNamePrefix + '0') -ResourceGroupName $natVMRg -ea SilentlyContinue)) {
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
$testvmsparmas = @{
    'adminUsername' = $localadminUserName;
    'vm1Name' = $testVM1Name;
    'vm2Name' = $testVM2Name;
    'virtualNetworkName' = $vnetName;
    'virtualNetworkResourceGroup' = $vnetRG;
    'subnet1Name' = $highTrustSubnetName;
    'subnet2Name' = $medTrustSubnetName;
    'storageAccountName' = $storageName;
    'publicIPAddressName' = "TestVMPublicIP";
    'networkSecurityGroupName' = "testvm1nsg"
}

#Check for test VMs and deploy if it doesn't Exist
Write-Verbose "Checking for TestVMs..."
if (!(Get-AzureRmVM -Name $testvm2Name -ResourceGroupName $vmRGName -ea SilentlyContinue) -or !(Get-AzureRmVM -Name $testVM1Name -ResourceGroupName $vmRGName -ErrorAction SilentlyContinue)) {
Write-Verbose "Deploying 1st TestVM to subnet $($testvm1params.subnetname)"
try {
    New-AzureRmResourceGroupDeployment -Name TestVMs -ResourceGroupName $vmRGName -Mode Incremental -TemplateUri $testVMTemplateUri -TemplateParameterObject $testvmsparmas
    }
catch {
    throw "Error creating TestVMs. See Error Logs"
    }
}
else {
    Write-Verbose "The TestVMs Exists already. Continuing"
    }


#Create Route Table and routes

Write-Verbose "Creating User Defined Routes"
$route1 = New-AzureRmRouteConfig -Name "medTrustToHighTrust" -AddressPrefix $highTrustSubnetCIDR -NextHopType VirtualAppliance -NextHopIpAddress $panTrustIP
$route2 = New-AzureRmRouteConfig -Name "highTrustToMedTrust" -AddressPrefix $medTrustSubnetCIDR -NextHopType VirtualAppliance -NextHopIpAddress $panTrustIP
$defaultroute = New-AzureRmRouteConfig -Name "DefaultOut"  -AddressPrefix "0.0.0.0/0" -NextHopType VirtualAppliance -NextHopIpAddress $panTrustIP
$routeToNat = New-AzureRmRouteConfig -Name "unTrustToNAT" -AddressPrefix "0.0.0.0/0" -NextHopType VnetLocal -NextHopIpAddress "10.248.4.4"
$routeToInternet = New-AzureRmRouteConfig -Name "DefaultToInternet" -AddressPrefix "0.0.0.0/0" -NextHopType Internet
$routeToPanUntrust = New-AzureRmRouteConfig -Name "toUnTrust" -AddressPrefix "10.248.0.0/16" -NextHopType VirtualAppliance -NextHopIpAddress $panUnTrustIP


$table1 = New-AzureRmRouteTable -ResourceGroupName $vnetRG -Name "medTrustSubnetRT" -Location $deploymentLocation -Route $route1, $defaultroute
$table2 = New-AzureRmRouteTable -ResourceGroupName $vnetRG -Name "highTrustSubnetRT" -Location $deploymentLocation -Route $route2
$table3 = New-AzureRMRouteTable -ResourceGroupName $vnetRG -Name "UntrustsubnetRT" -Location $deploymentLocation -Route $routeToNat
$table4 = New-AzureRMRouteTable -ResourceGroupName $vnetRG -Name "NatSubnetRT" -Location $deploymentLocation -Route $routeToInternet, $routeToPanUntrust

$vnet = Get-AzureRmVirtualNetwork -Name $vnetName -ResourceGroupName $vnetrg

Set-AzureRmVirtualNetworkSubnetConfig -VirtualNetwork $vnet -Name $medTrustSubnetName -AddressPrefix $medTrustSubnetCIDR -RouteTable $table1
Set-AzureRmVirtualNetworkSubnetConfig -VirtualNetwork $vnet -Name $highTrustSubnetName -AddressPrefix $highTrustSubnetCIDR -RouteTable $table2
Set-AzureRmVirtualNetworkSubnetConfig -VirtualNetwork $vnet -Name $untrustSubnetName -AddressPrefix $untrustSubnetCIDR -RouteTable $table3
Set-AzureRMVirtualNetworkSubnetConfig -VirtualNetwork $vnet -Name $natSubnetName -AddressPrefix $natSubnetCIDR -RouteTable $table4

Set-AzureRmVirtualNetwork -VirtualNetwork $vnet
}