#require version 3.0

function Jira-QueryApi
{
    Param (
        [Uri]$Query,
        [string]$Username,
        [string]$Password
    );

    Write-Host "Querying JIRA API $($Query.AbsoluteUri)"

    # Prepare the Basic Authorization header - PSCredential doesn't seem to work
    $base64AuthInfo = [Convert]::ToBase64String([Text.Encoding]::ASCII.GetBytes(("{0}:{1}" -f $Username,$Password)))
    $headers = @{Authorization=("Basic {0}" -f $base64AuthInfo)}

    # Execute the query
    Invoke-RestMethod -Uri $Query -Headers $headers
}

function Jira-ExecuteApi
{
    Param (
        [Uri]$Query,
        [string]$Body,
        [string]$Username,
        [string]$Password
    );

    Write-Host "Posting JIRA API $($Query.AbsoluteUri)"

    $base64AuthInfo = [Convert]::ToBase64String([Text.Encoding]::ASCII.GetBytes(("{0}:{1}" -f $Username,$Password)))
    $headers = @{Authorization=("Basic {0}" -f $base64AuthInfo)}

    $results = Invoke-RestMethod -Uri $Query -Headers $headers -UseBasicParsing -Body $Body -Method Post -ContentType "application/json"

    $json = ConvertFrom-Json -InputObject $results

    $sr.Dispose()

    $json
}

function Jira-GetTransitions
{
    Param (
        [Uri]$TransitionsUri,
        [string]$Username,
        [string]$Password
    );

    $transitions = Jira-QueryApi -Query $TransitionsUri -Username $Username -Password $Password
    $transitions.transitions
}

function Jira-PostTransition
{
    Param (
        [Uri]$TransitionsUri,
        [string]$Username,
        [string]$Password,
        [string]$Body
    );

    Jira-ExecuteApi -Query $TransitionsUri -Body $body -Username $Username -Password $Password
}

function Jira-TransitionTicket
{
    Param (
        [Uri]$IssueUri,
        [string]$Username,
        [string]$Password,
        [string]$Transition
    );

    $query = $IssueUri.AbsoluteUri + "/transitions"
    $uri = [System.Uri] $query

    $transitions = Jira-GetTransitions -TransitionsUri $uri -Username $Username -Password $Password
    $match = $transitions | Where name -eq $Transition | Select -First 1
    If ($match -ne $null)
    {
        $transitionId = $match.id
        $body = "{ ""update"": { ""comment"": [ { ""add"" : { ""body"" : ""Status automatically updated via Octopus Deploy"" } } ] }, ""transition"": { ""id"": ""$transitionId"" } }"

        Jira-PostTransition -TransitionsUri $uri -Body $body -Username $Username -Password $Password
    }
}

function Jira-TransitionTickets
{
    Param (
        [Uri]$BaseUri,
        [string]$Username,
        [string]$Password,
        [string]$Jql,
        [string]$Transition
    );

    $api = New-Object -TypeName System.Uri -ArgumentList $BaseUri, ("/rest/api/2/search?jql=" + $Jql)
    $json = Jira-QueryApi -Query $api -Username $Username -Password $Password

    If ($json.total -eq 0)
    {
        Write-Output "No issues were found that matched your query : $Jql"
    }
    Else
    {
        ForEach ($issue in $json.issues)
        {
            Jira-TransitionTicket -IssueUri $issue.self -Transition $Transition -Username $Username -Password $Password
        }
    }
}

$uri = "http://tempuri.org"
$jql = "fixVersion = 11.3.1 AND status = Completed"
$transition = "Deploy"
$user = "admin"
$pass = "admin"

Jira-TransitionTickets -BaseUri $uri -Jql $jql -Status $status -Transition $transition -Username $user -Password $pass