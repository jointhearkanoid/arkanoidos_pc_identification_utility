# ArkanoidOS PC Identification Utility

Herramienta oficial en PowerShell del proyecto **ArkanoidOS** diseñada para analizar y recopilar las especificaciones de hardware de un PC y generar un archivo JSON estructurado. Dicho archivo se carga en el portal de descargas de ArkanoidOS para recomendar automáticamente la mejor edición de Windows modificado según las capacidades del equipo (**ArkanoidOS Lite**, **ArkanoidOS+**, **ArkanoidOS Pro** o **ArkanoidOS VIP**).

---

## Novedades de la versión 2.0

- **Soporte extendido de procesadores Intel:**
  - **Intel Core Ultra (Series 1, 2 y 3):** Meteor Lake, Lunar Lake, Arrow Lake, Panther Lake (ej. Ultra 5 125H, Ultra 5 225U, Ultra 7 258V, Ultra 9 285K).
  - **Intel Core Serie 1, 2 y 3 (nueva nomenclatura sin 'i'):** Core 3, 5 y 7 processor 1xx/2xx/3xx (ej. Core 3 processor 304, Core 5 processor 120U).
  - **Intel Processor N & U Series:** Gama de entrada y bajo consumo (ej. Processor N95, N100, N150, N200, U300, U303L).
  - **Intel Processor for Desktop:** Procesadores de escritorio Serie 300 (Processor 300, Processor 300T).
  - **Intel Core tradicional (1ª a 14ª generación):** Cobertura completa de Core i3, i5, i7 e i9 (Nehalem hasta Raptor Lake Refresh).
  - **Intel Vintage / Legacy & Server:** Intel Core 2 Duo, Core 2 Quad, Pentium (Gold / Clásicos), Celeron y Xeon.

- **Soporte completo de procesadores AMD:**
  - **AMD Ryzen & Ryzen PRO:** Series 1000 a 9000+ (arquitecturas Zen, Zen+, Zen 2, Zen 3, Zen 3+, Zen 4 y Zen 5).
  - **AMD Ryzen AI Series:** Serie Ryzen AI 300 (Zen 5 / Strix Point, ej. Ryzen AI 9 HX 370).
  - **AMD Ryzen Threadripper & Threadripper PRO:** Series 1000 a 7000.
  - **AMD A-Series & PRO A-Series (APUs):** A4, A6, A8, A10, A12 (Llano, Trinity, Richland, Kaveri, Carrizo, Bristol Ridge).
  - **AMD Athlon:** Athlon Zen (Silver/Gold, 200GE, 3000G), Athlon X4 (FM2+), Athlon II (K10.5) y Athlon 64 / X2 (K8).
  - **AMD Phenom:** Phenom II (K10.5) y Phenom (K10).
  - **AMD FX Series:** Series 4000, 6000, 8000 y 9000 (Bulldozer / Piledriver).
  - **AMD E-Series & Sempron:** Gama de entrada legacy.

- **Soporte para arquitecturas ARM64:**
  - Qualcomm Snapdragon X Elite y Snapdragon X Plus.

- **Detección de Hardware Mejorada:**
  - **RAM:** Soporte para detección precisa de DDR4, DDR5, LPDDR4, LPDDR5, DDR3 y DDR2 mediante SMBIOSMemoryType.
  - **Disco:** Detección precisa de SSD, NVMe y HDD mediante `Get-PhysicalDisk` con fallback inteligente a `Win32_DiskDrive`.
  - **Compatibilidad total:** Compatible con PowerShell 5.1 (Windows 7/8.1/10/11) y PowerShell 7+.

---

## Estructura del Archivo JSON Exportado

El archivo generado (`Especificaciones_Sistema_YYYYMMDD_HHMMSS.json`) mantiene compatibilidad total con el portal de descargas, e incluye campos enriquecidos:

```json
{
  "FechaHora": "2026-10-05 20:39:17",
  "Sistema": {
    "CPU": {
      "Nombre": "Intel(R) Core(TM) Ultra 5 225U",
      "Fabricante": "Intel",
      "Familia": "Intel Core Ultra",
      "Modelo": "Ultra 5 225U",
      "Generacion": "Core Ultra Serie 2",
      "GeneracionNumero": 2,
      "Nucleos": 12,
      "ProcesadoresLogicos": 14,
      "Velocidad": "1.5 GHz"
    },
    "RAM": {
      "Capacidad": "8 GB",
      "Velocidad": "5600 MHz",
      "Tipo": "DDR5"
    },
    "Disco": {
      "Capacidad": "476.94 GB",
      "Tipo": "SSD"
    }
  }
}
```

---

## Uso

1. Ejecutar el script haciendo clic derecho y seleccionando **"Ejecutar con PowerShell"**, o desde una terminal:
   ```powershell
   powershell -ExecutionPolicy Bypass -File .\ArkanoidOS_PC_Identification_Utility.ps1
   ```

2. Para ejecución desatendida o automatizada:
   ```powershell
   powershell -ExecutionPolicy Bypass -File .\ArkanoidOS_PC_Identification_Utility.ps1 -NoWait
   ```

3. El archivo JSON resultante se guardará en la misma carpeta del script. Carga su contenido en el **Centro de Descargas de ArkanoidOS** para recibir la recomendación óptima.
# arkanoidos_pc_identification_utility
Source code for the official ArkanoidOS PC Identification Utility tool, necessary to provide custom Downloads recommendations inside the ArkanoidOS Download Center page.
