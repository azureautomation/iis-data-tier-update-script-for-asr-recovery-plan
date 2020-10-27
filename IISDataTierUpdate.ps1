<#
.SYNOPSIS
    Runbook to run a custom script inside an Azure Virtual Machine. This script needs to be used along with recovery plans in Azure Site Recovery. 
    Runs this PowerShell script to update connection sring on IIS server.

.DESCRIPTION
    After Failover of data tier to Azure, this runbook runs powershell script which updates connection string on IIS server.This runbook requires
    Push-AzureVMCommand runbook to be imported from gallery in Azure automation account.
    

    Download IIS-Update-ConnectionString.ps1  script from https://aka.ms/asr-iis-update-connectionstring-script-classic  and store it locally. Use the local path in "ScriptLocalFilePath" variable.
    Now upload the script to your Azure storage account using following command. Command is given the the example value.
     Replace following items as per your account name and key and container name: 
    "ScriptScriptStorageAccountName", ScriptStorageAccountKey", "ContainerName"

    $context = New-AzureStorageContext -ScriptStorageAccountName "ScriptScriptStorageAccountName" -StorageAccountKey "ScriptStorageAccountKey"
    Set-AzureStorageBlobContent -Blob "IIS-Update-ConnectionString.ps1" -Container "ContainerName" -File "ScriptLocalFilePath" -context $context	

.ASSETS
    Add below Assets 
    'ScriptScriptStorageAccountName': Name of the storage account where the script is stored
    'ScriptStorageAccountKey': Key for the storage account where the script is stored
    'AzureSubscriptionName': Azure Subscription Name to use
    'ContainerName': Container in which script is uploaded
    'IIS-Update-ConnectionString': Name of script
    'SQLInstanceName': Name of SQL instance IIS pointing to. for default instance it will be SQL VM Name , for named instance it will be SQL VMName\SQLInstanceName
    in the azure automation account	
    You can choose to encrypt these assets

.PARAMETER RecoveryPlanContext
    RecoveryPlanContext is the only parameter you need to define.
    This parameter gets the failover context from the recovery plan.

.NOTE
    The script is to be run only on Azure classic resources. It is not supported for Azure Resource Manager resources.

     Author: sakulkar@microsoft.com
#>

workflow IISDataTierUpdate
{
    param
    (
        [Object]$RecoveryPlanContext
    )
    try
    {
        $AzureOrgIdCredential = Get-AutomationPSCredential -Name 'AzureOrgIdCredential' 
        $AzureAccount = Add-AzureAccount -Credential $AzureOrgIdCredential
        $AzureSubscriptionName = Get-AutomationVariable -Name 'AzureSubscriptionName'
        Select-AzureSubscription -SubscriptionName $AzureSubscriptionName

        $vmMap = $RecoveryPlanContext.VmMap.PsObject.Properties
        $RecoveryPlanName = $RecoveryPlanContext.RecoveryPlanName

        #Provide the storage account name and the storage account key information
        $ScriptStorageAccountName = Get-AutomationVariable -Name 'ScriptScriptStorageAccountName'

        #Script Details
        $ContainerName = Get-AutomationVariable -Name 'ContainerName'
        $ScriptName = "IIS-Update-ConnectionString.ps1"

        #Get SQL instance Details
        $SQLInstanceName = Get-AutomationVariable -Name 'SQLInstanceName'

        foreach($VMProperty in $vmMap)
        {
            $VM = $VMProperty.Value
            $VMName = $VMProperty.Value.RoleName
            $VMNames = "$VMNames,$VMName"
            $ServiceName = $VMProperty.Value.CloudServiceName
        }

        $VMNameList = $VMNames.split(",")
        
        foreach($VMName in VMNameList)
        { 
            if(($VMName -ne $null) -or ($VMName -ne ""))
            {        
                Push-AzureVMCommand `
                -AzureOrgIdCredential $AzureOrgIdCredential `
                -AzureSubscriptionName $AzureSubscriptionName `
                -Container $ContainerName `
                -ScriptName $ScriptName `
                -ScriptArguments $SQLInstanceName `
                -ServiceName $ServiceName `
                -ScriptStorageAccountName $ScriptStorageAccountName `
                -TimeoutLimitInSeconds 600 `
                -VMName $VMName `
                -WaitForCompletion $false

                Write-output "Updated Connection string on IIS VM"
            }
        }
    }
    catch
    {
        $ErrorMessage = $ErrorMessage+$_.Exception.Message
        Write-output $ErrorMessage
    }
}