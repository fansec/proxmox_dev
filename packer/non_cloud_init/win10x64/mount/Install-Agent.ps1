# Define paths to the installers
$virtioDriverPath = "F:\virtio-win-gt-x64.msi"
$qemuGuestAgentPath = "F:\guest-agent\qemu-ga-x86_64.msi"
$logDirectory = "C:\Windows\Temp\"

# Ensure the log directory exists
if (-not (Test-Path -Path $logDirectory)) {
    New-Item -ItemType Directory -Path $logDirectory -Force
}

# Function to install MSI packages
function Install-MSI {
    param (
        [string]$msiPath,
        [string]$logFile
    )

    if (Test-Path -Path $msiPath) {
        Write-Host "Installing $msiPath"
        Start-Process msiexec -Wait -ArgumentList @('/i', $msiPath, '/log', $logFile, '/qn', '/passive', '/norestart', 'ADDLOCAL=ALL')
        if ($LASTEXITCODE -eq 0) {
            Write-Host "$msiPath installed successfully."
        } else {
            Write-Host "Failed to install $msiPath. Check log file: $logFile"
        }
    } else {
        Write-Host "MSI path $msiPath not found."
    }
}

# Install Virtio Drivers
Install-MSI -msiPath $virtioDriverPath -logFile "$logDirectory\qemu-drivers.log"

# Install QEMU Guest Agent
Install-MSI -msiPath $qemuGuestAgentPath -logFile "$logDirectory\qemu-guest-agent.log"
