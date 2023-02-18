# Jenkins variables
$servers = "$ENV:PATCH_GROUP"
$emailTemplate = "$ENV:EMAIL_TEMPLATE"
$patchDate = "$ENV:PATCH_DATE"
$SnowPassword = ConvertTo-SecureString "$($ENV:SnowPass)" -AsPlainText -Force
$SnowCredential = New-Object System.Management.Automation.PSCredential ("$ENV:SnowUser", $SnowPassword)


# if (-not $SnowCredential) {$SnowCredential = Get-Credential -Username mcxapi -Message "mcxapi Credentials"}

# $servers = Get-Content -Path .\MCX_GroupA.txt

# Get server assignment groups from SNOW
$groupedServers = $servers | ForEach-Object {
    $assignmentGroup = (Get-SnowServer $_ -Credential $SnowCredential).AssignmentGroup.DisplayValue
    [PSCustomObject]@{
        Server = $_
        AssignmentGroup = $assignmentGroup
    }
}

# Remove duplicate assignment groups
$uniqueAssignmentGroups = $groupedServers | Select-Object -ExpandProperty "AssignmentGroup" -Unique

# Hashtable to store member emails for each unique assignment group
$groupMembers = @{}
$uniqueAssignmentGroups | ForEach-Object {
    $group = $_
    $groupMemberEmails = Get-ADGroupMember $_ -Server jomax.paholdings.com -ErrorAction SilentlyContinue | 
                        Get-ADUser -Properties EmailAddress -Server jomax.paholdings.com -ErrorAction SilentlyContinue | 
                        Where-Object {$_.EmailAddress} | Select-Object -ExpandProperty EmailAddress
    $groupMembers.Add($group, $groupMemberEmails)
    $serversInGroup = $groupedServers | Where-Object {$_.AssignmentGroup -eq $group} | Select-Object -ExpandProperty Server | Sort-Object
}

# Print the group members and servers
foreach ($group in $groupMembers.Keys) {
    Write-Host "Group: $group"
    Write-Host "Members: $($groupMembers[$group] -join ',')"
    Write-Host "Servers: $($serversInGroup -join ',')"
    Write-Host ""
    $emailTemplate = Get-Content .\prePatchingEmail.html -Raw
    $emailTemplate = $emailTemplate -replace '{group}', $group
    $emailTemplate = $emailTemplate -replace '{servers}', $serversInGroup
    $emailTemplate = $emailTemplate -replace '{date}', $patchDate
    $subject = "SRE-GPD Patching"
    ##### Used for testing #####
    #Send-MailMessage -From sre_gpd@godaddy.com -To  -Subject $subject -Body $emailTemplate -BodyAsHtml -SmtpServer p3plemlrelay-v01.prod.phx3.secureserver.net
    Send-MailMessage -From sre_gpd@godaddy.com -To sre_gpd@godaddy.com -Bcc $($groupMembers[$group] -join ',') -Subject $subject -Body $emailTemplate -BodyAsHtml -SmtpServer p3plemlrelay-v01.prod.phx3.secureserver.net
}