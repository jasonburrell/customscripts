#Requires -Version 3
function New-RubrikNASSharefromCSV
{
 <#  
      .SYNOPSIS
      This script will add NAS hosts and shares from a CSV
      
      .DESCRIPTION
      This is the general process:
      1. The script will enumerate a CSV that is in the following format: "Hostname","Path","SecurityStyle"
         if "host" does not exist then it will be added automatically
      .NOTES
      Written by Jason Burrell for community usage
      Twitter: @jasonburrell2
      GitHub: jasonburrell
            
      .LINK
      https://github.com/jasonburrell/customscripts
            
      .EXAMPLE
      New-RubrikNASSharefromCSV -rubrikCredPath '.\' -csvPath '.\sand1_nasshares.csv' -Server sand1-rbk01.rubrikdemo.com  -TemplateID (Get-RubrikFilesetTemplate -Name vol_jb_nfs_smb-nfs -shareType 'NFS').id -SLA 'Bronze' 
  #>


  [CmdletBinding()]
  Param(
    # Path to the Rubrik credential
    [string]$rubrikCredPath,
    # Path to CSV
    [string]$csvPath,
     #TemplateID
     [string]$TemplateID,
     #SLA
     [Parameter(Mandatory = $true)]
     [string]$SLA,
    # Rubrik server IP or FQDN
    [Parameter(Mandatory = $true)]
    [String]$Server
  )

    Begin {

    # The Begin section is used to perform one-time loads of data necessary to carry out the function's purpose
    # If a command needs to be run with each iteration or pipeline input, place it in the Process section

    #Load credentials 

    #Set rubrikCred path to \
    if ($rubrikCredPath -eq "" -and $rubrikCredPath -eq [String]::Empty)
    {
        $rubrikCredPath = '.\rubrikCred.xml'
        Write-Verbose "No shareCredPath found, setting to hard coded value of $rubrikCredPath"
    }

    #$rubrikCred = Import-Clixml -Path $rubrikCredPath

    #Connect to Rubrik
    Connect-Rubrik -Server $Server 

    }

Process {

#Counters 

[int]$numberofServersAdded = 0
[int]$numberofSharesAdded = 0
[int]$numberofServersSkipped = 0
[int]$numberofSharesSkipped = 0

#Set TemplateID if not specified or hard code
if ($TemplateID -eq "" -and $TemplateID -eq [String]::Empty)
{
$TemplateID = 'FilesetTemplate:::8754b56a-3221-4abb-88de-d9a672594139'
Write-Verbose "No TemplateID found, setting to hard coded value of $TemplateID"
}


#Add all shares to Rubrik

Import-Csv $csvPath | foreach-object {

 $nas = $_.Hostname
 $share = $_.Path
 $SecurityStyle = $_.SecurityStyle
    
    #Set shareType 
    if ($SecurityStyle -eq "unix")
    {
    $shareType = 'NFS'
    }

#Check to see if host already exists, if it does skip it

$exists = get-Rubrikhost -Name $nas

if ($exists.id -eq $null) {
    write-host "Server not found adding $nas to Rubrik cluster"
    #Add host
    #new-rubrikhost -Name $nas -HasAgent $false -Confirm:$false
    $numberofServersAdded = $numberofServersAdded + 1
} else {
    write-Verbose "$nas found, skipping"
    $numberofServersSkipped = $numberofServersSkipped + 1
}

#Check if share already exists, if it does not skip it

$exists = Get-RubrikNASShare -HostName $nas -exportPoint $share

if ($exists.id -eq $null) {
    Write-Host "Share not found adding $share to $nas"
    New-RubrikNASShare -HostID (Get-RubrikHost $nas).id -ShareType $shareType -ExportPoint $share -Confirm:$false
    $numberofSharesAdded = $numberofSharesAdded + 1
} else {
     
    Write-Verbose "$($nas) :/ $($share) already exists, skipping" 
    $numberofSharesSkipped = $numberofSharesSkipped +1 
}

#Check if it's already been assinged to an SLA, if not add to SLA.

$sharesla = Get-RubrikNASShare -HostName $nas -exportPoint $share | ForEach-Object {Get-RubrikFileset -ShareID $_.id}
$newshare = Get-RubrikNASShare -HostName $nas -exportPoint $share

if ($sharesla.configuredSlaDomainName -eq $null) {
    Write-Host "SLA not configured adding $SLA to $share on $nas"
    New-RubrikFileset -TemplateID $TemplateID -ShareID $newshare.id | Protect-RubrikFileset -SLA $SLA -Confirm:$false
    $numberofSharesToSLA = $numberofSharesToSLA + 1
} else {
    $sladomain = $newshare.configuredSlaDomainName 
    Write-Verbose "Share $share already assigned to $sladomain so doing nothing"
    $numberofSharesToSLASkipped = $numberofSharesToSLASkipped + 1
}


}

Write-Host "# of hosts added: $numberofServersAdded"
Write-Host "# of shares added: $numberofSharesAdded"
Write-Host "# of shares assigned to SLAs: $numberofSharesToSLA"
Write-host ""
Write-Host "# of hosts skipped: $numberofServersSkipped"
Write-Host "# of shares skipped: $numberofSharesSkipped"
Write-Host "# of shares already assigned to SLAs: $numberofSharesToSLASkipped"

}
}