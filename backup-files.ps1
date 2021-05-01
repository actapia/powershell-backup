<# .SYNOPSIS #>

param (
    [Parameter(Mandatory=$true)][String]$Configuration, # JSON configuration file
    [Parameter(Mandatory=$false)][String]$BackupType = "daily"
    
)

Import-Module BitsTransfer

# Rotates files to clear destination.
Function Rotate-Files {
    param (
            [Parameter(Mandatory=$true)][String]$Destination,
            [Parameter(Mandatory=$true)][int]$Count,
            [Parameter(Mandatory=$true)][int]$MaxCount
    )
    if ($Count -eq ($MaxCount-1)) {
        rm "$Destination.$Count"
    }
    else {
        $next = ("$Destination" + "." + ($Count + 1))
        if (Test-Path $next) {
            Rotate-Files -Destination "$Destination" -Count ($Count + 1) -MaxCount $MaxCount
        }
        if ($Count -eq 0) {
            if (Test-Path "$Destination") {
                mv "$Destination" "$next"
            }
        }
        else {
            mv "$Destination.$Count" "$next"
        }
    }
}

$conf = Get-Content $Configuration | ConvertFrom-Json
foreach ($drive in (Get-CimInstance Win32_LogicalDisk | ?{ $_.DriveType -eq 3} | select DeviceID)) {
    echo $drive.DeviceID
    foreach ($backup_drive in $conf.drives) {
        if (Test-Path -PathType Leaf (Join-Path $drive.DeviceID (Join-Path $backup_drive.directory "backup-id.txt"))) {
            foreach ($file in $conf.backups) {
                if ((Get-Member -InputObject $file -name "destination" -MemberType Properties)) {
                    $destination = (Join-Path $drive.DeviceID (Join-Path $backup_drive.directory (Join-Path $BackupType $file.destination)))
                }
                else {
                    $destination = (Join-Path $drive.DeviceID (Join-Path $backup_drive.directory (Join-Path $BackupType ([System.IO.FileInfo]$file.source).Name)))
                }
                echo $backup_drive.rotation_schedule.$BackupType
                Rotate-Files -Destination $destination -Count 0 -MaxCount $backup_drive.rotation_schedule.$BackupType
                Start-BitsTransfer -Source $file.source -Destination $destination -Description "Backup" -DisplayName "Backup"
            }
        }
    }

}