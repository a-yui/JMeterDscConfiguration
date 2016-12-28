 Param(
     [parameter(Mandatory=$true)]
     [string]$resourceGroupName,

     [parameter(Mandatory=$true)]
     [string]$vmssName,

     [string]$jmeterpropertiepath = "$env:SystemDrive\apache-jmeter-3.1\bin\jmeter.properties"
 )

 Write-Output "Resource Group Name : $resourceGroupName"
 Write-Output "VMSS Name : $vmssName"
 
 Install-Module -Name AzureRM

 Login-AzureRmAccount
 $Subscription = Get-AzureRmSubscription | Out-GridView -OutputMode Single
 Select-AzureRmSubscription -SubscriptionName $Subscription.SubscriptionName

 $privateIpAddress = Get-AzureRmNetworkInterface -ResourceGroupName $resourceGroupName -VirtualMachineScaleSetName $vmssName |
                         ForEach-Object -Process { $_.IpConfigurations.PrivateIpAddress + ":1099"}
 $privateIpAddress = $privateIpAddress -join ","
 $jmeterAgentIPs = "remote_hosts=" + $privateIpAddress

 $data = $(Get-Content $jmeterpropertiepath)
 $remoteHostsSetting = $data | Select-String -Pattern "^remote_hosts="

 $data -replace $remoteHostsSetting, $jmeterAgentIPs | 
     Out-File -Encoding ascii $jmeterpropertiepath



