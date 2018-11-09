<#
.SYNOPSIS
This PowerShell script will protect a VM based on it's attribute in vSphere and assign it to a similar named SLA

.DESCRIPTION

.EXAMPLE
.\Protect-RubrikvSphereAttribute.ps1 -vCenter sand1-vcsa.rubrikdemo.com -rubrikNode sand1-rbk01.rubrikdemo.com -creds .\rubrikCred.xml

.NOTES
Writen by Jason Burrell for community usage
Twitter: @jasonburrell2

To prepare to use this script complete the following steps:
1) Download the Rubrik Powershell module from Github or the Powershell Library.
  a) Install-Module Rubrik
  b) Import-Module Rubrik
  c) Install VMWare PowerCLI
2) Create a credentials file for connecting to Rubrik and vCenter (Typically a domain account).
  a) $cred = Get-Credential
    i) Enter the domain credentials to use for this script.
  b) $cred | Export-Clixml C:\temp\RubrikCred.xml -Force
3) Create a target SLA for each attribute with the format HR-Tier
.LINK
https://github.com/jburrell
https://github.com/rubrikinc/PowerShell-Module
#>

[CmdletBinding()]
param(
  # The Rubrik SLA Policy to take snapshots from
  [Parameter(Mandatory=$True,
  HelpMessage="Enter vCenter Server")]
  [string]$vCenter,
  # The IP address or hostname of a node in the Rubrik cluster.
  [Parameter(Mandatory=$True,
  HelpMessage="Enter the IP address or hostname of a node in the Rubrik Cluster.")]
  [string]$rubrikNode,
  # The credentials file for Rubrik
  [Parameter(Mandatory=$True,
  HelpMessage="Enter the credentials file name.")]
  [string]$creds

)

#Load Rubrik module and connect
Import-Module Rubrik

# Connect to Rubrik cluster
Connect-Rubrik -Server $rubrikNode -Credential (Import-Clixml $creds)
# Connect to vCenter
Connect-VIServer -Server $vCenter -Credential (Import-Clixml $creds)

# Assign VM to SLA
$arrViewPropertiesToGet = "Name","Summary.Config.Annotation","CustomValue","AvailableField"
foreach ($cluster in Get-Cluster) {
    $x = Get-View -ViewType VirtualMachine -Property $arrViewPropertiesToGet -SearchRoot $cluster.id | Select @{n="VMname"; e={$_.Name}},
        @{n="HA"; e={$viewThisVM = $_; ($viewThisVM.CustomValue | ?{$_.Key -eq ($viewThisVM.AvailableField | ?{$_.Name -eq "HA"}).Key}).Value}},
        @{n="Tier"; e={$viewThisVM = $_; ($viewThisVM.CustomValue | ?{$_.Key -eq ($viewThisVM.AvailableField | ?{$_.Name -eq "Tier"}).Key}).Value}},
        @{n="Option"; e={$viewThisVM = $_; ($viewThisVM.CustomValue | ?{$_.Key -eq ($viewThisVM.AvailableField | ?{$_.Name -eq "Option"}).Key}).Value}}

    foreach ($vm in $x) {
       if ($vm.HA) { #Check if there is a value for HA 
        if ($vm.Tier) { #Check if there is a value for Tier
            if (!$vm.Option) { #Check that nothing is in the Option field
                $SLA = $vm.HA + "-" + $vm.Tier
                if (Get-RubrikSLA -Name $SLA) {
                    Get-RubrikVM $vm.VMname | Protect-RubrikVM -SLA $SLA -Confirm:$false
                } else {
                    Write-Host "Cannot find SLA with name" $SLA
                }
            }
        }
       }
    }
}
