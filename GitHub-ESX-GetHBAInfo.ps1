# Get WWN in vSphere cluster

Get-Cluster Your-Cluster-Name | Get-VMhost | Get-VMHostHBA -Type FibreChannel | Select VMHost,Device,@{N="WWN";E={"{0:X}" -f $_.PortWorldWideName}} | Sort VMhost,Device | out-string | export-csv Cluster_HBA_Info.csv