if (-not $mcxapiCreds) {$mcxapiCreds = Get-Credential -Username mcxapi -Message "mcxapi Credentials"}

$files = Get-ChildItem -Path . -Filter "*All.txt"
$index = 0
$fileList = @{}
foreach($file in $files)
{
    $index++
    $fileList.Add($index, $file.FullName)
    Write-Host "$index. $($file.Name)"
}
$selectedFileIndex = [int](Read-Host "Please select the file containing the servers list")
$servers = Get-Content $fileList.$selectedFileIndex

Write-Host ""

$groupedServers = @()
$serverCount = $servers.Count
$i = 0

foreach ($server in $servers) {
    $i++
    Write-Progress -Activity "Processing servers" -Status "$i / $serverCount" -PercentComplete (($i / $serverCount) * 100)
    try {
        $assignmentGroup = (Get-SnowServer $server -Credential $mcxapiCreds).AssignmentGroup.DisplayValue
        $groupedServers += New-Object PSObject -Property @{
            Server = $server
            AssignmentGroup = $assignmentGroup
        }
    }
    catch {
        Write-Error "Error occurred while processing server $($server): $_"
    }
}

$uniqueAssignmentGroups = $groupedServers | Select-Object -ExpandProperty "AssignmentGroup" -Unique
$groupCount = $uniqueAssignmentGroups.Count
$i = 0
foreach ($group in $uniqueAssignmentGroups) {
    $i++
    Write-Progress -Activity "Processing groups" -Status "$i / $groupCount" -PercentComplete (($i / $groupCount) * 100)
    $serversInGroup = $groupedServers | Where-Object {$_.AssignmentGroup -eq $group} | Select-Object -ExpandProperty "Server" | Sort-Object
    $members = Get-ADGroupMember -Identity $group -Server jomax.paholdings.com
    $memberEmails = @()
    foreach($member in $members) {
        $user = Get-ADUser -Identity $member -Properties EmailAddress -Server jomax.paholdings.com -ErrorAction SilentlyContinue 
        $memberEmails += $user.EmailAddress
    }
    $memberEmails = $memberEmails -join ','
    if (!$memberEmails) {
        Write-Error "Error: Email address not found for group $group members"
    }
    else {
        $templateSelection = Read-Host "Please select the template to use (1 PrePatch or 2 PostPatch)"

        if ($templateSelection -eq "1") {
            $emailBody = Get-Content .\prePatchingEmail.html -Raw
            $emailBody = $emailBody -replace '{group}', $group
            $emailBody = $emailBody -replace '{servers}', $serversInGroup
            $subject = "SRE-GPD Patching"
        }
        else {
            $emailBody = Get-Content .\postPatchingEmail.html -Raw
            $emailBody = $emailBody -replace '{group}', $group
            $emailBody = $emailBody -replace '{servers}', $serversInGroup
            $subject = "SRE-GPD Patching Complete"
        }
        Write-Host "Emails will be sent to: $memberEmails"
        Write-Host "Servers in group $($group):`n$serversInGroup"
        Write-Host ""
        Send-MailMessage -To #ctomford@godaddy.com -From sre_gpd@godaddy.com -Subject $subject -Body $emailBody -BodyAsHtml -SmtpServer p3plemlrelay-v01.prod.phx3.secureserver.net
    }
}