$ErrorActionPreference = "SilentlyContinue"

function Format-Size($bytes) {
    $gb = $bytes / 1GB

    if ($gb -ge 900) {
        $tb = $gb / 1000
        $sizes = @(1, 2, 3, 4, 5, 6, 8, 10, 12, 14, 16, 18, 20, 22, 24)
        $best = $sizes | Sort-Object { [math]::Abs($_ - $tb) } | Select-Object -First 1
        return "$($best)T"
    }

    $sizes = @(32, 64, 80, 120, 128, 160, 240, 250, 256, 320, 480, 500, 512, 640, 750, 960, 1000)
    $best = $sizes | Sort-Object { [math]::Abs($_ - $gb) } | Select-Object -First 1
    return "$($best)G"
}

# ====================
# CPU
# ====================

$cpu = (Get-CimInstance Win32_Processor | Select-Object -First 1).Name.Trim()

$cpu = $cpu `
    -replace "Intel\(R\)", "" `
    -replace "Core\(TM\)", "" `
    -replace "AMD Ryzen", "Ryzen" `
    -replace "\s+CPU", "" `
    -replace "\s+@\s+.*$", "" `
    -replace "\s+", " "

$cpu = $cpu.Trim()


# ====================
# RAM
# ====================

$ram = Get-CimInstance Win32_PhysicalMemory

$ramGroups = $ram | Group-Object Manufacturer, Capacity, Speed, SMBIOSMemoryType

$ramOut = foreach ($group in $ramGroups) {
    $r = $group.Group[0]

    $maker = "$($r.Manufacturer)".Trim()

    if ($maker -match "Kingston") { $maker = "KINGSTON" }
    elseif ($maker -match "Samsung") { $maker = "SAMSUNG" }
    elseif ($maker -match "Micron") { $maker = "MICRON" }
    elseif ($maker -match "Hynix") { $maker = "SK HYNIX" }

    $capacity = [math]::Round($r.Capacity / 1GB)

    $type = switch ([int]$r.SMBIOSMemoryType) {
        20 { "DDR" }
        21 { "DDR2" }
        24 { "DDR3" }
        26 { "DDR4" }
        30 { "DDR5" }
        34 { "DDR5" }
        default { "DDR" }
    }

    $speed = $r.ConfiguredClockSpeed

    if (-not $speed) {
        $speed = $r.Speed
    }

    $text = "$maker ${capacity}G $type-$speed"

    if ($group.Count -gt 1) {
        $text += " * $($group.Count)"
    }

    $text
}


# ====================
# Storage
# ====================

$physicalDisks = Get-PhysicalDisk

$storageOut = foreach ($disk in Get-CimInstance Win32_DiskDrive) {

    $model = "$($disk.Model)".Trim()
    $model = $model `
        -replace "\s+ATA Device$", "" `
        -replace "\s+SCSI Disk Device$", "" `
        -replace "\s+", " "

    $physical = $physicalDisks | Where-Object {
        $_.FriendlyName -eq $disk.Model -or
        $disk.Model -like "*$($_.FriendlyName)*" -or
        $_.FriendlyName -like "*$model*"
    } | Select-Object -First 1

    $type = $null

    if ($physical -and $physical.MediaType -ne "Unspecified") {
        if ($physical.MediaType -eq "SSD") {
            $type = "SSD"
        }
        elseif ($physical.MediaType -eq "HDD") {
            $type = "HDD"
        }
    }

    # Get-PhysicalDisk 無法辨識時的備援判斷
    if (-not $type) {
        if (
            $model -match "SSD|NVMe|SX\d+|Samsung.*EVO|Samsung.*PRO|WD.*SN\d+|Crucial.*P\d+|ADATA"
        ) {
            $type = "SSD"
        }
        else {
            $type = "HDD"
        }
    }

    $size = Format-Size $disk.Size

    "$type $model $size"
}


# ====================
# GPU
# ====================

$gpu = Get-CimInstance Win32_VideoController |
    Where-Object {
        $_.Name -notmatch "Remote|Basic Display"
    } |
    Select-Object -ExpandProperty Name -Unique

if (-not $gpu) {
    $gpu = "X"
}


# ====================
# Motherboard
# ====================

$board = Get-CimInstance Win32_BaseBoard | Select-Object -First 1

$motherboard = "$($board.Manufacturer) $($board.Product)"
$motherboard = $motherboard.Trim()


# ====================
# Output
# ====================

Write-Host "CPU: $cpu"
Write-Host "RAM: $($ramOut -join ' + ')"
Write-Host "Storage: $($storageOut -join ' + ')"
Write-Host "GPU: $($gpu -join ' + ')"
Write-Host "Motherboard: $motherboard"

Write-Host ""
Read-Host "Press Enter to continue"