#Requires -Version 3
function Add-DFSSharesRubrik
{
 <#  
      .SYNOPSIS
      This script will leverage dfs tools and a 3rd party script to pull in DFS shares and add them to Rubrik
      
      .DESCRIPTION
      This is the general process:
      1. The script will enumerate all shares and split the host from the share path, for example \\s1234\share\share1
      will pull out s1234 as the server name check if it has been added to rubrik, and if not add it. 
      2. The script will check if the share has been added, in this case \share\share1 to the host s1234, 
      if it has not been added it will be added, this requires credentials.
      3. The script will check if the share has an SLA set on it, and if not apply the SLA
       
      .NOTES

      1. DFS tools must be installed
      2. This expects encrypted credentials to create credentials run generateCreds.ps1
      3. This relies on a community file called List-Dfsn,ps1

      .NOTES

      Written by Jason Burrell for community usage
      Twitter: @jasonburrell2
      GitHub: jasonburrell
            
      .LINK
      https://github.com/jasonburrell/customscripts
            
      .EXAMPLE
      Add-DFSSharesRubrik -rubrikCredPath '.\' -shareCredPath '.\' -shareType 'SMB' -TemplateID (Get-RubrikFilesetTemplate -Name Everything -shareType 'SMB').id -SLA 'Bronze' 
  #>


  [CmdletBinding()]
  Param(
     # Path to list-dfsn.ps1
    [string]$listdfsnPath,
    # Path to the Rubrik credential
    [string]$rubrikCredPath,
    # Path to the Share credential
    [string]$shareCredPath,
    # ShareType
    [string]$shareType,
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

    #Load list-dfsn module
    if ($listdfsnPath -eq "" -and $listdfsnPath -eq [String]::Empty)
    {
        $listdfsnPath = 'C:\Program Files\WindowsPowerShell\Modules\Rubrik\Scripts\List-Dfsn.ps1'
        Write-Verbose "No listdfsnPath found, setting to hard coded value of $listdfsnPath"
    }
    
    . $listdfsnPath

    #Load credentials 

    #Set rubrikCred path to \
    if ($rubrikCredPath -eq "" -and $rubrikCredPath -eq [String]::Empty)
    {
        $rubrikCredPath = '.\rubrikCred.xml'
        Write-Verbose "No shareCredPath found, setting to hard coded value of $ruvrikCredPath"
    }

    #Set shareCred path to \
    if ($shareCredPath -eq "" -and $shareCredPath -eq [String]::Empty)
    {
        $shareCredPath = '.\shareCred.xml'
        Write-Verbose "No shareCredPath found, setting to hard coded value of $shareCredPath"
    }

    $rubrikCred = Import-Clixml -Path $rubrikCredPath
    $shareCred = Import-Clixml -Path $shareCredPath

    #Connect to Rubrik
    Connect-Rubrik -Server $Server -Credential $rubrikCred

    }

Process {

###Modify Defaults###

#Set shareType to SMB if not specified
if ($shareType -eq "" -and $shareType -eq [String]::Empty)
{
$shareType = 'SMB'
Write-Verbose "No shareType found, setting to hard coded value of $shareType"
}

#Set TemplateID if not specified or hard code
if ($TemplateID -eq "" -and $TemplateID -eq [String]::Empty)
{
$TemplateID = 'FilesetTemplate:::8754b56a-3221-4abb-88de-d9a672594139'
Write-Verbose "No TemplateID found, setting to hard coded value of $TemplateID"
}

###Modify Defaults###


#Get list of paths
$Filepath = list-dfsn | select TargetPath

#Get server path
$Serverpath = $Filepath | select-string -pattern "\\\\(.*?)\\" -AllMatches | ForEach {$_.Matches} | ForEach {$_.Groups} | Select-Object -skip 1 -first 1


#Counters 

[int]$numberofServersAdded = 0
[int]$numberofSharesAdded = 0
[int]$numberofSharesToSLA = 0
[int]$numberofServersSkipped = 0
[int]$numberofSharesSkipped = 0
[int]$numberofSharesToSLASkipped = 0

#Add all shares to Rubrik

ForEach ($path in $Filepath.TargetPath) {

$nas = $path -split "\\" | Where {  $_ -ne ""  } | Select -first 1
$share = $path -split "\\" | Where {  $_ -ne ""  } | Select -last 1

#Check to see if host already exists, if it does skip it

$exists = get-Rubrikhost -Name $nas

if ($exists.id -eq $null) {
    write-host "Server not found adding $nas to Rubrik cluster"
    #Add host
    new-rubrikhost -Name $nas -HasAgent $false -Confirm:$false
    $numberofServersAdded = $numberofServersAdded + 1
} else {
    write-Verbose "$nas found, skipping"
    $numberofServersSkipped = $numberofServersSkipped + 1
}

#Check if share already exists, if it does not skip it

$exists = Get-RubrikNASShare -HostName $nas -exportPoint $share

if ($exists.id -eq $null) {
    Write-Host "Share not found adding $share to $nas"
    New-RubrikNASShare -HostID (Get-RubrikHost $nas).id -ShareType $shareType -ExportPoint $share -Confirm:$false -Credential $shareCred
    $numberofSharesAdded = $numberofSharesAdded + 1
} else {
    Write-Verbose "$nas\$share already exists, skipping" 
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