#Requires -Version 3
function Get-PolarisToken {
    <#
    .SYNOPSIS
​
    Returns an API access token for a given Polaris instance.
​
    .DESCRIPTION
​
    Returns an API access token for a given Polaris instance, taking the URL, username and password.
​
    .PARAMETER Username
    Polaris username.
​
    .PARAMETER Password
    Polaris password.
​
    .PARAMETER PolarisURL
    The URL for the Polaris instance in the form 'https://myurl'
​
    .INPUTS
​
    None. You cannot pipe objects to Get-PolarisToken.
​
    .OUTPUTS
​
    System.String. Get-PolarisToken returns a string containing the access token.
​
    .EXAMPLE
​
    PS> $token = Get-PolarisToken -Username $username -Password $password -PolarisURL $url
    #>

    param(
        [Parameter(Mandatory=$True)]
        [String]$Username,
        [Parameter(Mandatory=$True)]
        [String]$Password,
        [Parameter(Mandatory=$True)]
        [String]$PolarisURL
    )
    $headers = @{
        'Content-Type' = 'application/json';
        'Accept' = 'application/json';
    }
    $payload = @{
        "username" = $Username;
        "password" = $Password;
    }
    $endpoint = $PolarisURL + '/api/session'
    $response = Invoke-RestMethod -Method POST -Uri $endpoint -Body $($payload | ConvertTo-JSON -Depth 100) -Headers $headers
    return $response.access_token
}
function Get-PolarisReportCSV {

<#
    .SYNOPSIS
​
    Returns a csv link to a report built in Polaris

    .DESCRIPTION
​
    Returns a csv link to a report, the report can be used for futher automation.
​
    .PARAMETER Token
    Polaris access token, get this using the 'Get-PolarisToken' command.
​
    .PARAMETER PolarisURL
    The URL for the Polaris instance in the form 'https://myurl'
​
    .PARAMETER ReportID
    The report ID, you can get to the report ID by looking at the URL when you navigate to the report in Polaris. 
    For example https://rubrik-se.my.rubrik.com/reports/179 = ReportID 179
​
    .INPUTS
​
    None. 
​
    .OUTPUTS
​
    System.String. Get-PolarisReportCSV returns a url to the report as a string 
​
    .EXAMPLE
​
    PS> Get-PolarisReportCSV

    #>
    param(
        [Parameter(Mandatory=$True)]
        [String]$Token,
        [Parameter(Mandatory=$True)]
        [String]$PolarisURL,
        [Parameter(Mandatory=$True)]
        [String]$ReportID
    )

    $headers = @{
        'Content-Type' = 'application/json';
        'Accept' = 'application/json';
        'Authorization' = $('Bearer '+$Token);
    }

    $payload = '{"operationName":"ReportDownloadCSV","variables":{"id":' + $ReportID + '},"query":"query ReportDownloadCSV($id: Int!, $config: CustomReportCreate) {\n  downloadReportLink(id: $id, config: $config) {\n    link\n    __typename\n  }\n}\n"}'
   
    $endpoint = $PolarisURL + '/api/graphql'


    $result = Invoke-WebRequest -Method Post -Headers $headers -Body $payload  -uri  $endpoint
    
    if ($result) {
        $result = $result | ConvertFrom-Json 
    
        $link = $result.data.downloadReportLink.link
        $pos = $link.IndexOf("?")
        #$link = $link.Substring(0, $pos)
        return $link
    }

}

###Variables##
#Example: user@rubrik.com
$username = ''
#Example: abc123
$password = ''
#example: https://myurl
$url = ''


$token = Get-PolarisToken -Username $username -Password $password -PolarisURL $url

$reportlink = Get-PolarisReportCSV -Token $token -PolarisURL $url -ReportID '179'
    
Write-Output $reportlink

Invoke-WebRequest -Uri $reportlink -OutFile 'report.csv'