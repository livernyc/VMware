# If your session is setup to load the PowerCLI module already you do not need line 2.
add-PSSnapin VMware.VimAutomation.Core
# You will have to change the vcenter names to your vcenter(s) name(s).
$vcenters = "vcenter1.yourcompany1.com","vcenter2.yourcompany.com"
# $limit is the number of days old a snapshot has to be to create a report and email.
$limit = (Get-Date).AddDays(-5)
$CustomSnapObjects = @()
# You will have to update the filename path and if you want name for the CSV report file.
$filename = "E:\Scripts\ESX-Findsnapshots\Snapshots-violations.csv"
If (Test-Path $filename){
	Remove-Item $filename
}

function Sendmail ($body, $subject) {
# You will need to update with your own SMTP server.
$smtpServer = "servermail.yourcompany.com"
$msg = new-object Net.Mail.MailMessage
$smtp = new-object Net.Mail.SmtpClient($smtpServer) 
$att = new-object Net.Mail.Attachment($filename)
# You might want to change the From address for the email.
$msg.From = "ESXiReporter@yourcompany.com"
$msg.To.Add("Joe.admin1@yourcompany.com")
$msg.To.Add("Joe.admin2@yourcompany.com")
$msg.To.Add("ITWSGOffShoreConsultants@yourcompany.com")
$msg.Subject = $subject
$msg.Body = $body
$msg.Attachments.Add($att)
$smtp.Send($msg)
}

Foreach($vcenter in $vcenters){
connect-viserver $vcenter
$VMguests = get-vm 

Foreach ($VMGuest in $VMguests){

# Write-host "Processing $VMGuest."
$Checkforsnaps = $VMGuest | get-snapshot
IF ($Checkforsnaps -ne $Null){
Write-host "Found snapshots on $VMGuest!!!!"

	ForEach($Snapshot in $Checkforsnaps){
	[String] $VMguestName = $VMGuest.Name
	# In the clients environment I originally wrote this for if any snapshots were found on replicated datastores
	# there would be a report and email generated despite what $limit was set to.
	IF (($Snapshot.Created -lt $limit) -or ($VMGuest.harddisks.filename -like "*SRM*")){
	[INT] $FSizeGB = $Snapshot.SizeGB
	[DateTime] $Snaptime = $Snapshot.created
	IF ($VMGuest.harddisks.filename -like "*SRM*"){
	$SRMCheck = "Yes"
	}
	ELSE{
	$SRMCheck = "No"
	}
	


            $SnapProperties = @{

                Server = $VMguestName

                SnapshotSizeGB =  $FSizeGB

                SnapshotTime = $Snaptime

                vCenter = $vcenter
				
				SRMDataStore = $SRMCheck
				
            }
            $object = New-Object PSObject -Property $SnapProperties
			
			$object | select Server, SnapshotTime, SnapshotSizeGB, vCenter, SRMDataStore | FT
			
			$CustomSnapObjects += $object
	}
	ELSE{
	Write-host "Found snapshots on $VMguestName but they are not in violation."
	}
	
	}

}

}
disconnect-viserver -server $vcenter -confirm:$false
}

# If we have any objects we know we have to send the alert email with the report attached.
If ($CustomSnapObjects -ne $Null){
$CustomSnapObjects | sort-object Server | select Server, SnapshotTime, SnapshotSizeGB, vCenter, SRMDataStore | Export-csv -path $filename -NoTypeInformation
$maildate = get-date
$maildate = $maildate.ToShortDateString()
$messagesub = "Snapshots found that violate snapshot policy $maildate!!!"
$messagebody = "The Snapshot reporter script found violations for $maildate.`n"
$messagebody += "Below is a sumarry report of the findings.`n"
$messagebody += "The CSV report inculed has the timestamp and Size info on the snapshot(s).`n"
$messagebody += "`n"
$messagebody += "`_____________________________________________________________________________________`n"
$messagebody += $CustomSnapObjects | sort-object Server | select Server, vCenter, SRMDataStore | out-String
sendmail $messagebody $messagesub
} # Testing