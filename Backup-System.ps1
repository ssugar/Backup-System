function Backup-System {

   <#
	.SYNOPSIS
	Powershell function to backup a windows server to a folder to be backed up via Azure Backup.  
	.DESCRIPTION
	Backup-System is able to backup system state, sql server, sharepoint, lync and exchange to a specific folder that will then be backed up by Azure Backup
	.PARAMETER destination
	The folder where the data will be stored
	.PARAMETER systemState
	Boolean that specifies if the system state backup should be taken or not
	.PARAMETER sqlServer
	Boolean that specifies if the SQL Server backup should be taken or not
	.PARAMETER sharepointServer
	Boolean that specifies if the SharePoint Server backup should be taken or not
	.PARAMETER lyncServer
	Boolean that specifies if the Lync Server backup should be taken or not
	.PARAMETER exchangeServer
	Boolean that specifies if the SQL Server backup should be taken or not
	.INPUTS
	Parameters above.
	.OUTPUTS
	Status of backup files
	.NOTES
	Version:        1.0
	Author:         Scott Sugar
	Change:         Initial function development
	#>

	[CmdletBinding()]
	param
	(
		[Parameter(Mandatory=$true)]
		[ValidateScript({If(Test-Path $_){$true}else{Throw "Destination folder does not exist: $_"}})]
		[string]$destination,
		[Parameter(Mandatory=$false)]
		[boolean]$systemState,
		[Parameter(Mandatory=$false)]
		[boolean]$sqlServer=$false,
		[Parameter(Mandatory=$false)]
		[boolean]$sharepointServer=$false,
		[Parameter(Mandatory=$false)]
		[boolean]$lyncServer=$false,
		[Parameter(Mandatory=$false)]
		[boolean]$exchangeServer=$false,
		[Parameter(Mandatory=$false)]
		[boolean]$bareMetal=$false
	)

	begin {

		Write-Host("Running Backup-System with the following parameters:")
		Write-Host("Destination: " + $destination)
		Write-Host("System State: " + $systemState)
		Write-Host("SQL Server: " + $sqlServer)
		Write-Host("SharePoint Server: " + $sharepointServer)
		Write-Host("Lync Server: " + $lyncServer)
		Write-Host("Exchange Server: " + $exchangeServer)
		Write-Host("Bare Metal: " + $bareMetal)
		   
	}

	process {
	
		#import the ServerManager module
        ipmo ServerManager
		
		#check to see if Windows-Server-Backup feature is installed
		$checkBackupFeature = Get-WindowsFeature Windows-Server-Backup
        if($checkBackupFeature.InstallState -eq "Installed")
        {
            Write-Host("Windows-Server-Backup Feature is installed")
        }
        else
        {
            Write-Error("Windows-Server-Backup Feature not found!")
            Break
        }

        $backupPolicies = Get-WBPolicy
        if($backupPolicies -eq $null)
        {
            Write-Host("No backup policies found")
        }
        else
        {
            $backupPolicies
        }
        $pol = New-WBPolicy
        $pol | Add-WBBareMetalRecovery
        $pol | Add-WBSystemState
        $vol = Get-WBDisk | Get-WBVolume | ?{$_.FileSystem -ne "NONE"}  
        Add-WBVolume -Policy $pol -Volume $vol
        
        $targetvol = Get-WBDisk | ?{$_.Properties -match "ValidTarget"} | Get-WBVolume
        if($targetvol -eq $null)
        {
            Write-Host("No valid targets found.  Need a new disk that has ValidTarget in its properties when running Get-WBDisk")
            Break
        }
        else
        {
            Write-Host("Target selected:")
            Add-WBBackupTarget -Policy $pol -Target (New-WBBackupTarget -Volume  $targetvol)
            Write-Host("Removing Target Volume from volumes to backup")
            Remove-WBVolume -Policy $pol -Volume $targetvol
        }
        
        $pol
	    Set-WBSchedule -Policy $pol -Schedule ([datetime]::Now.AddMinutes(10))
        Start-WBBackup -Policy $pol
	}

	end {

	}
	  
}