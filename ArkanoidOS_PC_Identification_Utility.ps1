# ==============================================================================
# Herramienta de identificacion de PCs de ArkanoidOS, v2.0
# Utilidad oficial para recopilar especificaciones de hardware y exportar a JSON
# para recomendaciones personalizadas de ISOs en el portal de descargas de ArkanoidOS.
# Compatible con:
#   - Intel Core Ultra (Series 1, 2, 3...)
#   - Intel Core (Series 1, 2, 3 - sin 'i')
#   - Intel Processor N & U Series (N100, N150, U300, U303L...)
#   - Intel Processor Desktop (300, 300T)
#   - Intel Core tradicionales (1a a 14a generacion: i3, i5, i7, i9)
#   - Intel Core 2 Duo / Core 2 Quad / Pentium / Celeron / Xeon
#   - AMD Ryzen & Ryzen PRO (Series 1000 a 9000+, Zen a Zen 5)
#   - AMD Ryzen AI Series (Serie 300 / Zen 5)
#   - AMD Ryzen Threadripper & Threadripper PRO
#   - AMD A-Series & PRO A-Series (A4, A6, A8, A10, A12)
#   - AMD Athlon (Athlon Zen, Athlon X4, Athlon II, Athlon 64)
#   - AMD Phenom (Phenom II, Phenom)
#   - AMD FX Series (Series 4000, 6000, 8000, 9000)
#   - Qualcomm Snapdragon X Series (ARM64)
# ==============================================================================

[CmdletBinding()]
param(
    [switch]$NoWait
)

# Configurar codificacion de salida para la consola
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8

function Get-HardwareInstance {
    param([string]$ClassName)
    try {
        if (Get-Command Get-CimInstance -ErrorAction SilentlyContinue) {
            return Get-CimInstance -ClassName $ClassName -ErrorAction Stop
        }
    } catch {}
    return Get-WmiObject -Class $ClassName -ErrorAction SilentlyContinue
}

function Get-SystemSpecifications {
    # Configurar codificacion UTF-8
    [Console]::OutputEncoding = [System.Text.Encoding]::UTF8

    # Obtener informacion del procesador
    $cpuObj = Get-HardwareInstance "Win32_Processor" | Select-Object -First 1
    $script:CPUInfo = $cpuObj
    $script:CPUName = if ($cpuObj.Name) { $cpuObj.Name.Trim() } else { "Desconocido" }
    $script:CPUCores = $cpuObj.NumberOfCores
    $script:CPULogicalProcessors = $cpuObj.NumberOfLogicalProcessors
    $script:CPUSpeed = [math]::Round($cpuObj.MaxClockSpeed / 1000, 2)

    # Obtener informacion de la memoria RAM
    $memModules = @(Get-HardwareInstance "Win32_PhysicalMemory")
    $totalRamBytes = ($memModules | Measure-Object -Property Capacity -Sum).Sum
    $script:RAMCapacity = if ($totalRamBytes) { [math]::Round($totalRamBytes / 1GB, 2) } else { 0 }
    
    $firstRam = $memModules | Select-Object -First 1
    $script:RAMSpeed = if ($firstRam.Speed) { $firstRam.Speed } else { 0 }

    # Deteccion exhaustiva de tipo de RAM (SMBIOS + WMI MemoryType)
    $rawMemType = if ($firstRam.MemoryType) { [int]$firstRam.MemoryType } else { 0 }
    $smbiosType = if ($firstRam.SMBIOSMemoryType) { [int]$firstRam.SMBIOSMemoryType } else { 0 }

    $script:RAMType = switch ($smbiosType) {
        20 { "DDR" }
        21 { "DDR2" }
        22 { "DDR2 FB-DIMM" }
        24 { "DDR3" }
        26 { "DDR4" }
        27 { "FBD2" }
        28 { "DDR4E" }
        29 { "LPDDR3" }
        30 { "LPDDR4" }
        31 { "HBM" }
        32 { "HBM2" }
        34 { "DDR5" }
        35 { "LPDDR5" }
        default {
            switch ($rawMemType) {
                1  { "Other" }
                2  { "DRAM" }
                3  { "Synchronous DRAM" }
                17 { "SDRAM" }
                20 { "DDR" }
                21 { "DDR2" }
                22 { "DDR2 FB-DIMM" }
                24 { "DDR3" }
                26 { "DDR4" }
                27 { "DDR5" }
                default { "Unknown" }
            }
        }
    }

    # Obtener informacion del disco duro
    $diskDrives = @(Get-HardwareInstance "Win32_DiskDrive")
    $totalDiskBytes = ($diskDrives | Measure-Object -Property Size -Sum).Sum
    $script:DiskCapacity = if ($totalDiskBytes) { [math]::Round($totalDiskBytes / 1GB, 2) } else { 0 }

    # Deteccion precisa de tipo de medio (SSD / HDD / NVMe)
    $detectedDiskType = $null
    try {
        if (Get-Command Get-PhysicalDisk -ErrorAction SilentlyContinue) {
            $pDisks = @(Get-PhysicalDisk -ErrorAction SilentlyContinue)
            if ($pDisks.Count -gt 0) {
                if ($pDisks | Where-Object { $_.MediaType -eq 'SSD' -or $_.BusType -eq 'NVMe' }) {
                    $detectedDiskType = "SSD"
                } elseif ($pDisks | Where-Object { $_.MediaType -eq 'HDD' }) {
                    $detectedDiskType = "HDD"
                }
            }
        }
    } catch {}

    if (-not $detectedDiskType) {
        $firstDisk = $diskDrives | Select-Object -First 1
        $diskDesc = "$($firstDisk.Model) $($firstDisk.MediaType) $($firstDisk.InterfaceType)"
        if ($diskDesc -match 'SSD|NVMe|Solid State') {
            $detectedDiskType = "SSD"
        } else {
            $detectedDiskType = "HDD"
        }
    }
    $script:DiskType = $detectedDiskType

    # Crear objeto de especificaciones
    $script:SystemSpecs = [PSCustomObject]@{
        CPU = @{
            Name = $script:CPUName
            Cores = $script:CPUCores
            LogicalProcessors = $script:CPULogicalProcessors
            Speed = "$script:CPUSpeed GHz"
        }
        RAM = @{
            Capacity = "$script:RAMCapacity GB"
            Speed = "$script:RAMSpeed MHz"
            Type = $script:RAMType
        }
        Disk = @{
            Capacity = "$script:DiskCapacity GB"
            Type = $script:DiskType
        }
    }

    # Mostrar la informacion en consola
    Write-Host "`nEspecificaciones del Sistema:"
    Write-Host "------------------------"
    Write-Host "CPU: $script:CPUName"
    Write-Host "Nucleos: $script:CPUCores"
    Write-Host "Procesadores Logicos: $script:CPULogicalProcessors"
    Write-Host "Velocidad: $script:CPUSpeed GHz"
    Write-Host "`nRAM:"
    Write-Host "Capacidad: $script:RAMCapacity GB"
    Write-Host "Velocidad: $script:RAMSpeed MHz"
    Write-Host "Tipo: $script:RAMType"
    Write-Host "`nDisco:"
    Write-Host "Capacidad: $script:DiskCapacity GB"
    Write-Host "Tipo: $script:DiskType"
    Write-Host "------------------------`n"
}

function Resolve-ProcessorInformation {
    # Verificar si existe la informacion del CPU
    if (-not $script:CPUName) {
        Write-Host "Error: No se ha ejecutado Get-SystemSpecifications primero."
        return $null
    }

    # Normalizar espacios y remover marcas comerciales registradas (R, TM, simbolos unicode)
    $clean = $script:CPUName -replace '[\xAE\u2122]|\([Rr]\)|\([Tt][Mm]\)', ' '
    $clean = $clean -replace '\s+', ' '
    $clean = $clean.Trim()

    $manufacturer = "Desconocido"
    $family = "Desconocido"
    $model = "No disponible"
    $generation = "No disponible"
    $generationNumber = $null

    # ==============================================================================
    # 1. PROCESADORES INTEL
    # ==============================================================================
    if ($clean -match 'Intel') {
        $manufacturer = "Intel"

        # --------------------------------------------------------------------------
        # A) Intel Core Ultra Series (Series 1, 2, 3...)
        # Patrones: Core Ultra + [letra opcional] + nivel (3,5,7,9) + 3 digitos + sufijo(s) (H, U, V, K, KF, Plus)
        # Ejemplos: "Core Ultra 5 225U", "Core Ultra 7 155H", "Core Ultra 7 258V", "Core Ultra 7 265K Plus"
        # --------------------------------------------------------------------------
        if ($clean -match 'Core\s+Ultra\s+([A-Z]*[3579])\s+([0-9]{3}[A-Z0-9]*(?:\s+Plus)?)') {
            $tier = $matches[1]
            $sku = $matches[2]
            $family = "Intel Core Ultra"
            $model = "Ultra $tier $sku"

            # El primer digito del SKU numerico de 3 digitos define la serie
            if ($sku -match '^(\d)') {
                $serieNum = [int]$matches[1]
                $generationNumber = $serieNum
                $generation = "Core Ultra Serie $serieNum"
            } else {
                $generation = "Core Ultra"
            }
        }
        # --------------------------------------------------------------------------
        # B) Intel Core Serie 1, 2, 3 (sin 'i', ej: "Core 3 processor 304", "Core 5 processor 120U")
        # --------------------------------------------------------------------------
        elseif ($clean -match 'Core\s+([3579])\s+(?:processor\s+)?([0-9]{3}[A-Z0-9]*)') {
            $tier = $matches[1]
            $sku = $matches[2]
            $family = "Intel Core"
            $model = "Core $tier $sku"

            if ($sku -match '^(\d)') {
                $serieNum = [int]$matches[1]
                $generationNumber = $serieNum
                $generation = "Core Serie $serieNum"
            } else {
                $generation = "Core Serie Especial"
            }
        }
        # --------------------------------------------------------------------------
        # C) Intel Processor Desktop (300, 300T)
        # --------------------------------------------------------------------------
        elseif ($clean -match 'Processor\s+(300[A-Z]*)') {
            $sku = $matches[1]
            $family = "Intel Processor"
            $model = "Processor $sku"
            $generation = "Intel Processor Desktop"
            $generationNumber = 14
        }
        # --------------------------------------------------------------------------
        # D) Intel Processor N y U Series (N150, N100, N95, U300, U303L...)
        # --------------------------------------------------------------------------
        elseif ($clean -match 'Processor\s+([NU]\d{2,3}[A-Z]*)') {
            $sku = $matches[1]
            $seriesLetter = $sku.Substring(0, 1).ToUpper()
            $family = "Intel Processor"
            $model = "Processor $sku"
            $generation = "Intel Processor Serie $seriesLetter"
            $generationNumber = $null
        }
        # --------------------------------------------------------------------------
        # E) Intel Core tradicional (1a a 14a generacion: i3, i5, i7, i9)
        # --------------------------------------------------------------------------
        elseif (
            ($clean -match 'Core\s*(i[3579])[- ]*(\d{3,5}[A-Z0-9]*)') -or
            ($clean -match 'Core\s*(i[3579])\s*CPU\s*(\d{3,4}[A-Z0-9]*)') -or
            ($clean -match '(?:i[3579]-)(\d{3,5}[A-Z0-9]*)') -or
            ($clean -match '(?:i[3579])\s+(\d{3,5}[A-Z0-9]*)')
        ) {
            $tier = if ($matches.Count -ge 3) { $matches[1] } else { "" }
            $sku = if ($matches.Count -ge 3) { $matches[2] } else { $matches[1] }

            $family = "Intel Core"
            $model = if ($tier -ne "") { "$tier-$sku" } else { $sku }

            if ($sku -match '^(\d+)') {
                $numVal = [int]$matches[1]
                $len = $matches[1].Length

                if ($len -eq 3 -and $numVal -ge 300 -and $numVal -le 999) {
                    $generationNumber = 1
                }
                elseif ($numVal -ge 2000 -and $numVal -lt 3000) { $generationNumber = 2 }
                elseif ($numVal -ge 3000 -and $numVal -lt 4000) { $generationNumber = 3 }
                elseif ($numVal -ge 4000 -and $numVal -lt 5000) { $generationNumber = 4 }
                elseif ($numVal -ge 5000 -and $numVal -lt 6000) { $generationNumber = 5 }
                elseif ($numVal -ge 6000 -and $numVal -lt 7000) { $generationNumber = 6 }
                elseif ($numVal -ge 7000 -and $numVal -lt 8000) { $generationNumber = 7 }
                elseif ($numVal -ge 8000 -and $numVal -lt 9000) { $generationNumber = 8 }
                elseif ($numVal -ge 9000 -and $numVal -lt 10000) { $generationNumber = 9 }
                elseif ($numVal -ge 10000 -and $numVal -lt 11000) { $generationNumber = 10 }
                elseif ($numVal -ge 11000 -and $numVal -lt 12000) { $generationNumber = 11 }
                elseif ($numVal -ge 12000 -and $numVal -lt 13000) { $generationNumber = 12 }
                elseif ($numVal -ge 13000 -and $numVal -lt 14000) { $generationNumber = 13 }
                elseif ($numVal -ge 14000 -and $numVal -lt 15000) { $generationNumber = 14 }
            }

            $generation = if ($generationNumber) { "$($generationNumber)a generacion" } else { "No disponible" }
        }
        # --------------------------------------------------------------------------
        # F) Intel Core 2 Duo y Core 2 Quad
        # --------------------------------------------------------------------------
        elseif ($clean -match 'Core\s*2\s*Duo(?:\s+CPU)?\s+([A-Z0-9]+)') {
            $family = "Intel Core 2 Duo"
            $model = "Core 2 Duo $($matches[1])"
            $generation = "Core 2 Duo (Conroe/Penryn)"
            $generationNumber = 0
        }
        elseif ($clean -match 'Core\s*2\s*Quad(?:\s+CPU)?\s+([A-Z0-9]+)') {
            $family = "Intel Core 2 Quad"
            $model = "Core 2 Quad $($matches[1])"
            $generation = "Core 2 Quad (Kentsfield/Yorkfield)"
            $generationNumber = 0
        }
        # --------------------------------------------------------------------------
        # G) Intel Pentium / Celeron / Xeon
        # --------------------------------------------------------------------------
        elseif ($clean -match 'Pentium(?:\s+Gold)?\s+([A-Z0-9]+)') {
            $family = "Intel Pentium"
            $model = "Pentium $($matches[1])"
            $generation = "Intel Pentium"
        }
        elseif ($clean -match 'Celeron\s+([A-Z0-9]+)') {
            $family = "Intel Celeron"
            $model = "Celeron $($matches[1])"
            $generation = "Intel Celeron"
        }
        elseif ($clean -match 'Xeon\s+(?:CPU\s+)?([A-Z0-9\-]+(?:\s+v\d+)?)') {
            $family = "Intel Xeon"
            $model = "Xeon $($matches[1])"
            $generation = "Intel Xeon"
        }
        else {
            $family = "Intel Generico"
            $model = $clean
            $generation = "No disponible"
        }
    }
    # ==============================================================================
    # 2. PROCESADORES AMD
    # ==============================================================================
    elseif ($clean -match 'AMD') {
        $manufacturer = "AMD"

        # --------------------------------------------------------------------------
        # A) AMD Ryzen AI Series (Zen 5, ej: "AMD Ryzen AI 9 HX 370", "AMD Ryzen AI 9 365")
        # --------------------------------------------------------------------------
        if ($clean -match 'Ryzen\s+AI\s+([3579])\s+(?:(HX|HS|MAX)\s+)?(\d{3}[A-Z0-9]*)') {
            $tier = $matches[1]
            $prefix = if ($matches[2]) { "$($matches[2]) " } else { "" }
            $sku = $matches[3]
            $family = "AMD Ryzen AI"
            $model = "Ryzen AI $tier $prefix$sku"
            $generation = "Ryzen AI Serie 300 (Zen 5)"
            $generationNumber = 10
        }
        # --------------------------------------------------------------------------
        # B) AMD Ryzen Threadripper (ej: "AMD Ryzen Threadripper 3960X", "1950X", "5995WX")
        # --------------------------------------------------------------------------
        elseif ($clean -match 'Ryzen\s+(?:PRO\s+)?Threadripper(?:\s+PRO)?\s+(\d{4}[A-Z]*)') {
            $sku = $matches[1]
            $family = "AMD Ryzen Threadripper"
            $model = "Ryzen Threadripper $sku"

            if ($sku -match '^(\d)') {
                $genDigit = [int]$matches[1]
                $zenArch = switch ($genDigit) {
                    1 { "Zen" }
                    2 { "Zen+" }
                    3 { "Zen 2" }
                    5 { "Zen 3" }
                    7 { "Zen 4" }
                    9 { "Zen 5" }
                    default { "" }
                }
                $generation = "Ryzen Threadripper Serie $($genDigit)000 $(if ($zenArch) {"($zenArch)"})"
                $generationNumber = $genDigit
            }
        }
        # --------------------------------------------------------------------------
        # C) AMD Ryzen estandar & Ryzen PRO (Ryzen 3, 5, 7, 9 - Series 1000 a 9000)
        # --------------------------------------------------------------------------
        elseif ($clean -match 'Ryzen\s+(?:PRO\s+)?([3579])\s+(?:PRO\s+)?(\d{4}[A-Z0-9]*)') {
            $tier = $matches[1]
            $sku = $matches[2]
            $isPro = ($clean -match '\bPRO\b')
            $family = "AMD Ryzen"
            $model = if ($isPro) { "Ryzen PRO $tier $sku" } else { "Ryzen $tier $sku" }

            if ($sku -match '^(\d)') {
                $genDigit = [int]$matches[1]
                $zenArch = switch ($genDigit) {
                    1 { "Zen" }
                    2 { "Zen+" }
                    3 { "Zen 2" }
                    4 { "Zen 2" }
                    5 { "Zen 3" }
                    6 { "Zen 3+" }
                    7 { "Zen 4" }
                    8 { "Zen 4" }
                    9 { "Zen 5" }
                    default { "" }
                }
                $generation = "Ryzen Serie $($genDigit)000 $(if ($zenArch) {"($zenArch)"})"
                $generationNumber = $genDigit
            }
        }
        # --------------------------------------------------------------------------
        # D) AMD A-Series y PRO A-Series (A4, A6, A8, A10, A12)
        # --------------------------------------------------------------------------
        elseif ($clean -match '(?:(PRO)\s+)?(A(?:4|6|8|10|12))[- ](\d{4}[A-Z]*)') {
            $isPro = [bool]$matches[1]
            $seriesTier = $matches[2]
            $sku = $matches[3]
            $family = if ($isPro) { "AMD PRO A-Series" } else { "AMD A-Series" }
            $model = if ($isPro) { "PRO $seriesTier-$sku" } else { "$seriesTier-$sku" }

            if ($sku -match '^(\d)') {
                $leadDigit = [int]$matches[1]
                $genName = switch ($leadDigit) {
                    3 { "Serie 3000 (Llano / 1a Gen APU)" }
                    4 { "Serie 5000 (Trinity / 2a Gen APU)" }
                    5 { "Serie 5000 (Trinity / 2a Gen APU)" }
                    6 { "Serie 6000 (Richland / 3a Gen APU)" }
                    7 { "Serie 7000 (Kaveri / 4a Gen APU)" }
                    8 { "Serie 8000 (Carrizo / 6a Gen APU)" }
                    9 { "Serie 9000 (Bristol Ridge / 7a Gen APU)" }
                    default { "Serie $($leadDigit)000" }
                }
                $generation = "A-Series $genName"
                $generationNumber = $leadDigit
            }
        }
        # --------------------------------------------------------------------------
        # E) AMD FX Series
        # --------------------------------------------------------------------------
        elseif ($clean -match 'FX[- ]+(\d{4}[A-Z]*)') {
            $sku = $matches[1]
            $family = "AMD FX"
            $model = "FX-$sku"

            if ($sku -match '^(\d)') {
                $leadDigit = [int]$matches[1]
                $generation = "FX Serie $($leadDigit)000 (Bulldozer/Piledriver)"
                $generationNumber = $leadDigit
            }
        }
        # --------------------------------------------------------------------------
        # F) AMD Athlon
        # --------------------------------------------------------------------------
        elseif ($clean -match 'Athlon\s+(Silver|Gold)\s+(\d{4}[A-Z]*)') {
            $family = "AMD Athlon"
            $model = "Athlon $($matches[1]) $($matches[2])"
            $generation = "Athlon Zen"
        }
        elseif ($clean -match 'Athlon\s+(\d{3,4}[A-Z]*)') {
            $family = "AMD Athlon"
            $model = "Athlon $($matches[1])"
            $generation = "Athlon Zen"
        }
        elseif ($clean -match 'Athlon\s+X4\s+(\d{3}[A-Z]*)') {
            $family = "AMD Athlon"
            $model = "Athlon X4 $($matches[1])"
            $generation = "Athlon X4 (FM2+)"
        }
        elseif ($clean -match 'Athlon\s+II\s+(X[234])\s+(\d{3}[A-Z]*)') {
            $family = "AMD Athlon"
            $model = "Athlon II $($matches[1]) $($matches[2])"
            $generation = "Athlon II (K10.5)"
        }
        elseif ($clean -match 'Athlon\s+64(?:\s+X2)?(?:\s+Dual\s+Core)?(?:\s+Processor)?\s*(\d{4}\+?)') {
            $family = "AMD Athlon"
            $isX2 = ($clean -match 'X2')
            $model = if ($isX2) { "Athlon 64 X2 $($matches[1])" } else { "Athlon 64 $($matches[1])" }
            $generation = "Athlon 64 (K8)"
        }
        # --------------------------------------------------------------------------
        # G) AMD Phenom
        # --------------------------------------------------------------------------
        elseif ($clean -match 'Phenom\s+II\s+(X[2346])\s+(\d{3,4}[A-Z]*)') {
            $family = "AMD Phenom"
            $model = "Phenom II $($matches[1]) $($matches[2])"
            $generation = "Phenom II (K10.5)"
        }
        elseif ($clean -match 'Phenom\s+(?:(X[34])\s+)?(\d{4})') {
            $tier = if ($matches[1]) { "$($matches[1]) " } else { "" }
            $family = "AMD Phenom"
            $model = "Phenom $tier$($matches[2])"
            $generation = "Phenom (K10)"
        }
        # --------------------------------------------------------------------------
        # H) AMD E-Series / Sempron
        # --------------------------------------------------------------------------
        elseif ($clean -match '(E[12]|\bE-\d{3})\b[- ]*([A-Z0-9]*)') {
            $family = "AMD E-Series"
            $model = "$($matches[1]) $($matches[2])".Trim()
            $generation = "AMD APU Serie E"
        }
        elseif ($clean -match 'Sempron\s+([A-Z0-9]+)') {
            $family = "AMD Sempron"
            $model = "Sempron $($matches[1])"
            $generation = "AMD Sempron"
        }
        else {
            $family = "AMD Generico"
            $model = $clean
            $generation = "No disponible"
        }
    }
    # ==============================================================================
    # 3. OTROS (Qualcomm Snapdragon ARM64, etc.)
    # ==============================================================================
    elseif ($clean -match 'Snapdragon') {
        $manufacturer = "Qualcomm"
        $family = "Qualcomm Snapdragon"
        $model = if ($clean -match '(X\s+Elite|X\s+Plus)') { "Snapdragon $($matches[1])" } else { "Snapdragon" }
        $generation = "Qualcomm Oryon (ARM64)"
    }
    else {
        $manufacturer = "Desconocido"
        $family = "Generico"
        $model = $clean
        $generation = "No disponible"
    }

    # Guardar en variables de ambito script
    $script:CPUManufacturer = $manufacturer
    $script:CPUFamily = $family
    $script:ProcessorModel = $model
    $script:ProcessorGeneration = $generation
    $script:ProcessorGenerationNumber = $generationNumber

    # Mantener retrocompatibilidad con variables previas
    $script:IntelProcessorModel = $script:ProcessorModel
    $script:IntelProcessorGeneration = if ($generationNumber) { $generationNumber } else { $generation }

    Write-Host "`nInformacion del Procesador Identificada:"
    Write-Host "Fabricante: $script:CPUManufacturer"
    Write-Host "Familia:    $script:CPUFamily"
    Write-Host "Modelo:     $script:ProcessorModel"
    Write-Host "Generacion: $script:ProcessorGeneration"

    return $script:ProcessorModel
}

# Funciones retrocompatibles para consumidores existentes
function Get-ProcessorModel {
    if (-not $script:ProcessorModel) {
        Resolve-ProcessorInformation | Out-Null
    }
    return $script:ProcessorModel
}

function Get-IntelProcessorModel {
    return Get-ProcessorModel
}

function Get-ProcessorGeneration {
    if (-not $script:ProcessorGeneration) {
        Resolve-ProcessorInformation | Out-Null
    }
    return $script:ProcessorGeneration
}

function Get-IntelProcessorGeneration {
    return Get-ProcessorGeneration
}

function Export-SystemSpecificationsToJSON {
    # Verificar si existe la informacion del sistema
    if (-not $script:SystemSpecs) {
        Write-Host "Error: No se ha ejecutado Get-SystemSpecifications primero."
        return $false
    }

    # Crear un objeto con toda la informacion recopilada
    $exportData = [PSCustomObject]@{
        FechaHora = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
        Sistema = [ordered]@{
            CPU = [ordered]@{
                Nombre = $script:CPUName
                Fabricante = if ($script:CPUManufacturer) { $script:CPUManufacturer } else { "Desconocido" }
                Familia = if ($script:CPUFamily) { $script:CPUFamily } else { "Desconocido" }
                Modelo = if ($script:ProcessorModel) { $script:ProcessorModel } else { "No disponible" }
                Generacion = if ($script:ProcessorGeneration) { $script:ProcessorGeneration } else { "No disponible" }
                GeneracionNumero = $script:ProcessorGenerationNumber
                Nucleos = $script:CPUCores
                ProcesadoresLogicos = $script:CPULogicalProcessors
                Velocidad = "$script:CPUSpeed GHz"
            }
            RAM = [ordered]@{
                Capacidad = "$script:RAMCapacity GB"
                Velocidad = "$script:RAMSpeed MHz"
                Tipo = $script:RAMType
            }
            Disco = [ordered]@{
                Capacidad = "$script:DiskCapacity GB"
                Tipo = $script:DiskType
            }
        }
    }

    # Crear el nombre del archivo con la fecha actual
    $fileName = "Especificaciones_Sistema_$(Get-Date -Format 'yyyyMMdd_HHmmss').json"
    
    # Convertir el objeto a JSON con formato legible
    $jsonContent = $exportData | ConvertTo-Json -Depth 10

    try {
        # Guardar el archivo JSON con codificacion UTF-8
        $jsonContent | Out-File -FilePath $fileName -Encoding UTF8
        Write-Host "`nInformacion del sistema exportada exitosamente a: $fileName"
        return $true
    }
    catch {
        Write-Host "`nError al exportar la informacion: $_"
        return $false
    }
}

function Start-PCIdentification {
    param(
        [switch]$NoWait
    )
    # Configurar codificacion para UTF-8
    [Console]::OutputEncoding = [System.Text.Encoding]::UTF8
    
    # Mostrar encabezado
    Write-Host "================================================================"
    Write-Host "  Herramienta de identificacion de PCs de ArkanoidOS, v2.0      "
    Write-Host "================================================================"
    
    # Obtener informacion del sistema
    Write-Host "[+] Recopilando informacion del sistema operativo...`n"
    Get-SystemSpecifications

    # Obtener informacion del sistema operativo
    $osInfo = Get-HardwareInstance "Win32_OperatingSystem" | Select-Object -First 1
    Write-Host "Sistema operativo: $($osInfo.Caption)"
    Write-Host "Arquitectura: $($osInfo.OSArchitecture)"

    # Mostrar informacion de memoria y almacenamiento
    Write-Host "Tamano de memoria: $script:RAMCapacity GB"
    Write-Host "Almacenamiento total: $script:DiskCapacity GB"

    # Mostrar informacion del CPU
    Write-Host "CPU: $script:CPUName, numero total de nucleos: $script:CPUCores, arquitectura: $($osInfo.OSArchitecture)"

    # Obtener modelo y generacion del procesador
    Write-Host "`n[+] Analizando procesador..."
    Resolve-ProcessorInformation

    # Exportar informacion a JSON
    Write-Host "`n[+] Exportando especificaciones a archivo JSON..."
    $exportSuccess = Export-SystemSpecificationsToJSON

    if ($exportSuccess) {
        Write-Host "`n[OK] Especificaciones recopiladas y exportadas exitosamente a un archivo JSON!"
        Write-Host "Por favor, abre el archivo, copia y pega los resultados en la pagina de Descargas para obtener tu descarga personalizada.`n"
    } else {
        Write-Host "`n[ERROR] Error al exportar las especificaciones. Por favor, intenta nuevamente.`n"
    }

    # Esperar entrada del usuario si es una consola interactiva y no se especifico -NoWait
    if (-not $NoWait -and [Environment]::UserInteractive -and -not [Console]::IsInputRedirected) {
        Write-Host "Presiona ENTER o RETURN para cerrar esta aplicacion"
        Read-Host
    }
}

# Iniciar el proceso si se ejecuta directamente
Start-PCIdentification -NoWait:$NoWait
