# Initialize section Starts
add-pssnapin VMware.VimAutomation.Core

# Set what vCenter servers the script will run against.
$vcenters = "vCenter1.mycompany.com","vCenter2.mycompany.com"

$CustomSnapObjects = @()

# Load Export-Excel module, needed to export report in XLSX format.
iex (new-object System.Net.WebClient).DownloadString('https://raw.github.com/dfinke/ImportExcel/master/Install.ps1')

# Set file name and location for Report output.
$filename = "E:\Scripts\vSphere-Inventory-Report\vSphere-Inventory-Report.xlsx"
If (Test-Path $filename){
	Remove-Item $filename
}

# Initialize section Ends

function Sendmail ($body, $subject) {
# Change $smtpServer variable to vaild SMTP server for your environment.
$smtpServer = "servermail.mycompany.com"
$msg = new-object Net.Mail.MailMessage
$smtp = new-object Net.Mail.SmtpClient($smtpServer) 
$att = new-object Net.Mail.Attachment($filename)
# Change the sned from address to something else.
$msg.From = "vSphereReporter@mycompany.com"
# Change the send to address(s) to valid email addresses for your environment.
$msg.To.Add("john.doe@mycompany.com")
$msg.To.Add("vSPhereMaintenance@mycompany.com")
$msg.Subject = $subject
$msg.Body = $body
$msg.Attachments.Add($att)
$smtp.Send($msg)
}

Foreach($vcenter in $vcenters){
connect-viserver $vcenter

$Clusters = get-cluster

$Clusters | Select name

Foreach ($Cluster in $Clusters){

Write-Host "__________________________________________________" -foreground "Green"
Write-host "Processing Cluater Group $Cluster on vCetner $vcenter :" -foreground "Magenta"
Write-Host "__________________________________________________" -foreground "Green"

$VMguests = $Cluster | get-vm | sort-object @{Expression={$_.Name}}

	Foreach ($VM in $VMguests){
  
	$GName = $VM.name
	$GMemoryMB = $VM.MemoryMB
	$GCpuNum = $VM.NumCpu
	$GVMhost = $VM.host.name
	$IPAddress = $VM.guest.IPAddress
	$GDNSName = $VM.guest.hostname
	$GPowerState = $VM.powerstate
	$GHWver = $VM.version
	$GOSFull = $VM.guest.osfullname
	$VMX = $VM.Extensiondata.Summary.Config.VMPathName
	Write-Host "__________________________________________________" -foreground "Yellow"
	Write-Host "Guest Name: $GName" -foreground "Green"
	Write-Host "vCenter Name: $vcenter" -foreground "Green"
    if ($IPAddress -ne $NULL){
		Write-Host "IP Address Info: $IPAddress" -foreground "cyan"
		foreach ($IP in $IPAddress){
			if($IP -like "*.*.*.*"){
			Write-Host "IP V4 Address detected: $IP" -foreground "DarkMagenta"
			$GIPAddress += "$IP" + ':'
			}
		}
	}
	
	
		Foreach ($HD in $VM.HardDisks){
		$TGHdiskSize += $HD.CapacityKB
		}
	
	$GToolsS = $VM | % {get-view $_.ID} | foreach-object {$_.guest.toolsstatus}
	
	$TGHdiskSize = $TGHdiskSize / 1024
	$TGHdiskSize = $TGHdiskSize / 1024
	$TGHdiskSize = [int] $TGHdiskSize
	Write-Host "Total Disk Size: $TGHdiskSize" -foreground "cyan"
	Write-Host "Hardware Version: $GHWver" -foreground "cyan"
	Write-Host "Operating System: $GOSFull" -foreground "cyan"
	Write-Host "Tools Status: $GToolsS" -foreground "cyan"
		
		IF ($TGHdiskSize -ne 0 -and $VM.PowerState -eq "PoweredOn"){  


            $SnapProperties = @{

                GuestName = $GName

                DNSName =  $GDNSName
				
				IPAddress = $GIPAddress
				
				GuestPowerState = $GPowerState

                vCenter = $vcenter
				
				Cluster = $Cluster

                HostName = $GVMhost
				
				DiskSizeGB = $TGHdiskSize
				
				TotalRamMB = $GMemoryMB
				
				CPUCount = $GCpuNum
				
				OS = $GOSFull
				
				HardWareVer = $GHWver
				
				ToolsStatus = $GToolsS
				
				VMXPath = $VMX
            }
            $object = New-Object PSObject -Property $SnapProperties
			
			$CustomSnapObjects += $object
		}
	
	$GIPAddress = $NULL
	
	}
	
Write-Host "__________________________________________________" -foreground "Green"	
Write-host "Finished  Cluater Group $Cluster on vCetner $vcenter :" -foreground "Magenta"
Write-Host "__________________________________________________" -foreground "Green"

}
disconnect-viserver -server $vcenter -confirm:$false
}

$CustomSnapObjects | sort-object GuestName | select GuestName, DNSName, IPAddress, GuestPowerState, vCenter, Cluster, HostName, DiskSizeGB, TotalRamMB, CPUCount, OS, HardWareVer, ToolsStatus, VMXPath |  Export-Excel -path $filename

$maildate = get-date
$maildate = $maildate.ToShortDateString()
$messagesub = "VMware Inventory Report for $maildate."
$messagebody = "Attached is VMware inventory report.`n"
$messagebody += "Below is a sumarry of the report.`n"
$messagebody += "`n"
$messagebody += "`_____________________________________________________________________________________`n"
$messagebody += $CustomSnapObjects | sort-object GuestName | select GuestName, vCenter | out-String
sendmail $messagebody $messagesub