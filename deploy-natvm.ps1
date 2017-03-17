$natVMParams = @{
    'adminUsername' = "";
    'vmNamePrefix' = "LHNATVM0";
    'virtualNetworkName' = "LH-INF-PD-VNET01";
    'virtualNetworkResourceGroup' = "LH-INF-PD-VNET01-RG";
    'subnetName' = "VdiSubnet";
    'storageAccountName' = "";
    'publicIpAddressName' = "public";
    'networkSecurityGroupName' = ""
}

Login-AzureRmAccount
Get-AzureRmSubscription -SubscriptionName "Legacy IS Subscription" | Select-AzureRmSubscription

$natVMRg = ""
$natVMUri = "https://github.com/lorax79/legacy/raw/master/natVM.json"

New-AzureRmResourceGroupDeployment -Name NATVM -ResourceGroupName $natVMRg -Mode Incremental -TemplateUri $natVMUri -TemplateParameterObject $natVMParams