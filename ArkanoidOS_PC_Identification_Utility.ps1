function Get-SystemSpecifications {
    # Configurar codificación para UTF-8 al inicio
    [Console]::OutputEncoding = [System.Text.Encoding]::UTF8

    # Obtener información del procesador
    $script:CPUInfo = Get-WmiObject Win32_Processor | Select-Object Name, NumberOfCores, NumberOfLogicalProcessors, MaxClockSpeed
    $script:CPUName = $CPUInfo.Name
    $script:CPUCores = $CPUInfo.NumberOfCores
    $script:CPULogicalProcessors = $CPUInfo.NumberOfLogicalProcessors
    $script:CPUSpeed = [math]::Round($CPUInfo.MaxClockSpeed / 1000, 2)

    # Obtener información de la memoria RAM
    $script:RAMInfo = Get-WmiObject Win32_PhysicalMemory | Measure-Object -Property Capacity -Sum
    $script:RAMCapacity = [math]::Round($script:RAMInfo.Sum / 1GB, 2)
    $script:RAMSpeed = (Get-WmiObject Win32_PhysicalMemory | Select-Object -First 1).Speed
    $script:RAMType = switch ((Get-WmiObject Win32_PhysicalMemory | Select-Object -First 1).MemoryType) {
        0 { "Unknown" }
        1 { "Other" }
        2 { "DRAM" }
        3 { "Synchronous DRAM" }
        4 { "Cache DRAM" }
        5 { "EDO" }
        6 { "EDRAM" }
        7 { "VRAM" }
        8 { "SRAM" }
        9 { "RAM" }
        10 { "ROM" }
        11 { "Flash" }
        12 { "EEPROM" }
        13 { "FEPROM" }
        14 { "EPROM" }
        15 { "CDRAM" }
        16 { "3DRAM" }
        17 { "SDRAM" }
        18 { "SGRAM" }
        19 { "RDRAM" }
        20 { "DDR" }
        21 { "DDR2" }
        22 { "DDR2 FB-DIMM" }
        24 { "DDR3" }
        26 { "DDR4" }
        27 { "DDR5" }
        default { "Unknown" }
    }

    # Obtener información del disco duro
    $script:DiskInfo = Get-WmiObject Win32_DiskDrive | Measure-Object -Property Size -Sum
    $script:DiskCapacity = [math]::Round($script:DiskInfo.Sum / 1GB, 2)
    $script:DiskType = if ((Get-WmiObject Win32_DiskDrive | Select-Object -First 1).MediaType -like "*SSD*") { "SSD" } else { "HDD" }

    # Crear un objeto con toda la información
    $script:SystemSpecs = [PSCustomObject]@{
        CPU = @{
            Name = $CPUName
            Cores = $CPUCores
            LogicalProcessors = $CPULogicalProcessors
            Speed = "$CPUSpeed GHz"
        }
        RAM = @{
            Capacity = "$RAMCapacity GB"
            Speed = "$RAMSpeed MHz"
            Type = $RAMType
        }
        Disk = @{
            Capacity = "$DiskCapacity GB"
            Type = $DiskType
        }
    }

    # Mostrar la información
    Write-Host "`nEspecificaciones del Sistema:"
    Write-Host "------------------------"
    Write-Host "CPU: $CPUName"
    Write-Host "Nucleos: $CPUCores"
    Write-Host "Procesadores Lógicos: $CPULogicalProcessors"
    Write-Host "Velocidad: $CPUSpeed GHz"
    Write-Host "`nRAM:"
    Write-Host "Capacidad: $RAMCapacity GB"
    Write-Host "Velocidad: $RAMSpeed MHz"
    Write-Host "Tipo: $RAMType"
    Write-Host "`nDisco:"
    Write-Host "Capacidad: $DiskCapacity GB"
    Write-Host "Tipo: $DiskType"
    Write-Host "------------------------`n"
}

function Get-IntelProcessorModel {
    # Verificar si existe la información del CPU
    if (-not $script:CPUName) {
        Write-Host "Error: No se ha ejecutado Get-SystemSpecifications primero."
        return $null
    }

    # Patrón más amplio para extraer el número de modelo de procesadores Intel
    # Incluye Core i3, i5, i7, i9 con varios formatos
    $patterns = @(
        '(?:Core[^i]*i[3579])[^0-9]*(\d{3,5}[A-Z0-9]*)' # Core i3-2120, Core i7 4790K, 980X, etc.
        '(?:i[3579]-)(\d{3,5}[A-Z0-9]*)'                # i3-2120, i7-4790K, etc.
        '(?:i[3579])[^0-9]*(\d{3,5}[A-Z0-9]*)'          # i3 2120, i7 4790K, etc.
        '(\d{3}[A-Z0-9]*)'                              # Para capturar modelos antiguos como 980X
    )
    
    foreach ($pattern in $patterns) {
        $match = [regex]::Match($script:CPUName, $pattern)
        if ($match.Success) {
            $script:IntelProcessorModel = $match.Groups[1].Value
            Write-Host "`nModelo del procesador Intel extraído: $script:IntelProcessorModel"
            return $script:IntelProcessorModel
        }
    }
    
    Write-Host "`nNo se pudo encontrar un modelo de procesador Intel válido en: $script:CPUName"
    return $null
}

function Get-IntelProcessorGeneration {
    # Verificar si existe el modelo del procesador
    if (-not $script:IntelProcessorModel) {
        Write-Host "Error: No se ha ejecutado Get-IntelProcessorModel primero."
        return $null
    }

    # Eliminar cualquier carácter que no sea número del inicio del modelo
    $modelNumber = [regex]::Match($script:IntelProcessorModel, '^\d+').Value
    
    # Asegurarse de que tenemos un valor numérico
    if ([string]::IsNullOrEmpty($modelNumber)) {
        Write-Host "`nNo se pudo extraer un valor numérico del modelo: $script:IntelProcessorModel"
        return $null
    }
    
    $numericValue = [int]$modelNumber
    $digitCount = $modelNumber.Length

    # Identificación mejorada para procesadores de primera generación
    if ($digitCount -eq 3 -and $numericValue -ge 300 -and $numericValue -le 999) {
        # Primera generación (Nehalem/Westmere): formato de 3 dígitos (como 750, 860, 980X)
        $script:IntelProcessorGeneration = 1
        Write-Host "`nProcesador Intel de 1° generación (Nehalem/Westmere)"
        return 1
    }
    # Lógica para las demás generaciones
    elseif ($numericValue -ge 2000 -and $numericValue -lt 3000) {
        # Segunda generación (Sandy Bridge): 2xxx
        $script:IntelProcessorGeneration = 2
        Write-Host "`nProcesador Intel de 2° generación (Sandy Bridge)"
        return 2
    }
    elseif ($numericValue -ge 3000 -and $numericValue -lt 4000) {
        # Tercera generación (Ivy Bridge): 3xxx
        $script:IntelProcessorGeneration = 3
        Write-Host "`nProcesador Intel de 3° generación (Ivy Bridge)"
        return 3
    }
    elseif ($numericValue -ge 4000 -and $numericValue -lt 5000) {
        # Cuarta generación (Haswell): 4xxx
        $script:IntelProcessorGeneration = 4
        Write-Host "`nProcesador Intel de 4° generación (Haswell)"
        return 4
    }
    elseif ($numericValue -ge 5000 -and $numericValue -lt 6000) {
        # Quinta generación (Broadwell): 5xxx
        $script:IntelProcessorGeneration = 5
        Write-Host "`nProcesador Intel de 5° generación (Broadwell)"
        return 5
    }
    elseif ($numericValue -ge 6000 -and $numericValue -lt 7000) {
        # Sexta generación (Skylake): 6xxx
        $script:IntelProcessorGeneration = 6
        Write-Host "`nProcesador Intel de 6° generación (Skylake)"
        return 6
    }
    elseif ($numericValue -ge 7000 -and $numericValue -lt 8000) {
        # Séptima generación (Kaby Lake): 7xxx
        $script:IntelProcessorGeneration = 7
        Write-Host "`nProcesador Intel de 7° generación (Kaby Lake)"
        return 7
    }
    elseif ($numericValue -ge 8000 -and $numericValue -lt 9000) {
        # Octava generación (Coffee Lake): 8xxx
        $script:IntelProcessorGeneration = 8
        Write-Host "`nProcesador Intel de 8° generación (Coffee Lake)"
        return 8
    }
    elseif ($numericValue -ge 9000 -and $numericValue -lt 10000) {
        # Novena generación (Coffee Lake Refresh): 9xxx
        $script:IntelProcessorGeneration = 9
        Write-Host "`nProcesador Intel de 9° generación (Coffee Lake Refresh)"
        return 9
    }
    elseif ($numericValue -ge 10000 -and $numericValue -lt 11000) {
        # Décima generación (Ice Lake/Comet Lake): 10xxx
        $script:IntelProcessorGeneration = 10
        Write-Host "`nProcesador Intel de 10° generación (Ice Lake/Comet Lake)"
        return 10
    }
    elseif ($numericValue -ge 11000 -and $numericValue -lt 12000) {
        # 11ª generación (Tiger Lake): 11xxx
        $script:IntelProcessorGeneration = 11
        Write-Host "`nProcesador Intel de 11° generación (Tiger Lake)"
        return 11
    }
    elseif ($numericValue -ge 12000 -and $numericValue -lt 13000) {
        # 12ª generación (Alder Lake): 12xxx
        $script:IntelProcessorGeneration = 12
        Write-Host "`nProcesador Intel de 12° generación (Alder Lake)"
        return 12
    }
    elseif ($numericValue -ge 13000 -and $numericValue -lt 14000) {
        # 13ª generación (Raptor Lake): 13xxx
        $script:IntelProcessorGeneration = 13
        Write-Host "`nProcesador Intel de 13° generación (Raptor Lake)"
        return 13
    }
    elseif ($numericValue -ge 14000 -and $numericValue -lt 15000) {
        # 14ª generación (Meteor Lake): 14xxx
        $script:IntelProcessorGeneration = 14
        Write-Host "`nProcesador Intel de 14° generación (Meteor Lake)"
        return 14
    }
    else {
        Write-Host "`nNo se pudo determinar la generación del procesador Intel con el modelo: $script:IntelProcessorModel (valor numérico: $numericValue)"
        return $null
    }
}

function Export-SystemSpecificationsToJSON {
    # Verificar si existe la información del sistema
    if (-not $script:SystemSpecs) {
        Write-Host "Error: No se ha ejecutado Get-SystemSpecifications primero."
        return $false
    }

    # Crear un objeto con toda la información recopilada
    $exportData = [PSCustomObject]@{
        FechaHora = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
        Sistema = @{
            CPU = @{
                Nombre = $script:CPUName
                Modelo = if ($script:IntelProcessorModel) { $script:IntelProcessorModel } else { "No disponible" }
                Generacion = if ($script:IntelProcessorGeneration) { 
                    "$($script:IntelProcessorGeneration)° generación" 
                } else { "No disponible" }
                Nucleos = $script:CPUCores
                ProcesadoresLogicos = $script:CPULogicalProcessors
                Velocidad = "$script:CPUSpeed GHz"
            }
            RAM = @{
                Capacidad = "$script:RAMCapacity GB"
                Velocidad = "$script:RAMSpeed MHz"
                Tipo = $script:RAMType
            }
            Disco = @{
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
        # Guardar el archivo JSON con codificación UTF-8
        $jsonContent | Out-File -FilePath $fileName -Encoding UTF8
        Write-Host "`nInformación del sistema exportada exitosamente a: $fileName"
        return $true
    }
    catch {
        Write-Host "`nError al exportar la información: $_"
        return $false
    }
}

function Start-PCIdentification {
    # Configurar codificación para UTF-8
    [Console]::OutputEncoding = [System.Text.Encoding]::UTF8
    
    # Mostrar encabezado con caracteres Unicode
    Write-Host "╔════════════════════════════════════════════════════════════╗"
    Write-Host "║  Herramienta de identificación de PCs de ArkanoidOS, v1.0  ║"
    Write-Host "╚════════════════════════════════════════════════════════════╝"
    
    # Obtener información del sistema
    Write-Host "✓ Recopilando información del sistema operativo...`n"
    Get-SystemSpecifications

    # Obtener información del sistema operativo
    $osInfo = Get-WmiObject Win32_OperatingSystem
    Write-Host "Sistema operativo: $($osInfo.Caption)"
    Write-Host "Arquitectura: $($osInfo.OSArchitecture)"

    # Mostrar información de memoria y almacenamiento
    Write-Host "Tamaño de memoria: $script:RAMCapacity GB"
    Write-Host "Almacenamiento total: $script:DiskCapacity GB"

    # Mostrar información del CPU
    Write-Host "CPU: $script:CPUName, número total de núcleos: $script:CPUCores, arquitectura: $($osInfo.OSArchitecture)"

    # Obtener modelo y generación del procesador Intel
    Write-Host "✓ Analizando modelo del procesador Intel..."
    Get-IntelProcessorModel
    Get-IntelProcessorGeneration

    # Exportar información a JSON
    Write-Host "`n✓ Exportando especificaciones a archivo JSON..."
    $exportSuccess = Export-SystemSpecificationsToJSON

    if ($exportSuccess) {
        Write-Host "`n✅ ¡Especificaciones recopiladas y exportadas exitosamente a un archivo JSON!"
        Write-Host "Por favor, abre el archivo, copia y pega los resultados en la página de Descargas para obtener tu descarga personalizada.`n"
    } else {
        Write-Host "`n❌ Error al exportar las especificaciones. Por favor, intenta nuevamente.`n"
    }

    # Esperar entrada del usuario
    Write-Host "Presiona ENTER o RETURN para cerrar esta aplicación"
    Read-Host
}

# Iniciar el proceso
Start-PCIdentification
