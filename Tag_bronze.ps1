#Connect to vCenter
Connect-VIServer -Server sand1-vcsa.rubrikdemo.com

#Connect to Rubrik
$Credential = Import-Clixml -Path ("rubrikCred.xml")
Connect-Rubrik -Server sand1-rbk01.rubrikdemo.com -Credential $Credential

Protect-RubrikTag -Category Rubrik -Tag Bronze -SLA Bronze -Confirm:$false