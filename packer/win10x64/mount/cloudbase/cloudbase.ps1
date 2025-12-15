# Define paths and URLs
$cloudbaseInstallerUrl = "https://cloudbase.it/downloads/CloudbaseInitSetup_Stable_x64.msi"
$cloudbaseInstallerPath = "E:\CloudbaseInitSetup_x64.msi"
$cloudbaseConfigSourcePath = "E:\cloudbase-init.conf"
$cloudbaseConfigDestinationPath = "C:\Program Files\Cloudbase Solutions\Cloudbase-Init\conf\cloudbase-init.conf"
$logDirectory = "C:\Windows\Temp\"
$logFile = "$logDirectory\cloudbase-init-install.log"

# Ensure the log directory exists
if (-not (Test-Path -Path $logDirectory)) {
    New-Item -ItemType Directory -Path $logDirectory -Force
}

# Function to download the MSI file if not present
function Download-File {
    param (
        [string]$url,
        [string]$destinationPath
    )

    if (-not (Test-Path -Path $destinationPath)) {
        Write-Host "Downloading $url to $destinationPath"
        Invoke-WebRequest -Uri $url -OutFile $destinationPath
        if (Test-Path -Path $destinationPath) {
            Write-Host "Download completed."
        } else {
            Write-Host "Failed to download $url."
            exit 1
        }
    } else {
        Write-Host "File already exists at $destinationPath, skipping download."
    }
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

# Function to copy the config file after installation
function Copy-ConfigFile {
    param (
        [string]$sourcePath,
        [string]$destinationPath
    )

    if (Test-Path -Path $sourcePath) {
        # Ensure destination directory exists
        $destinationDir = Split-Path $destinationPath -Parent
        if (-not (Test-Path -Path $destinationDir)) {
            New-Item -ItemType Directory -Path $destinationDir -Force
        }

        # Copy the file
        Copy-Item -Path $sourcePath -Destination $destinationPath -Force
        if ($LASTEXITCODE -eq 0) {
            Write-Host "Config file copied successfully to $destinationPath"
        } else {
            Write-Host "Failed to copy the config file."
        }
    } else {
        Write-Host "Config file $sourcePath not found."
    }
}

# Download Cloudbase-Init MSI installer
Download-File -url $cloudbaseInstallerUrl -destinationPath $cloudbaseInstallerPath

# Install Cloudbase-Init
Install-MSI -msiPath $cloudbaseInstallerPath -logFile $logFile

# Copy the Cloudbase-Init config file
Copy-ConfigFile -sourcePath $cloudbaseConfigSourcePath -destinationPath $cloudbaseConfigDestinationPath
