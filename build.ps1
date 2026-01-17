# PowerShell Script to build the connector
$ErrorActionPreference = "Stop"

# Define directories
$outputDir = "bin\Debug"
$tempDir = "temp"

# Create output dir
if (-not (Test-Path $outputDir)) { New-Item -ItemType Directory -Path $outputDir -Force }

# Prepare temp dir for zipping
if (Test-Path $tempDir) { Remove-Item -Path $tempDir -Recurse -Force }
New-Item -ItemType Directory -Path "$tempDir\WolaiConnector" -Force

# Copy files to temp/WolaiConnector
Copy-Item "WolaiConnector.pq" -Destination "$tempDir\WolaiConnector\" -Force
Copy-Item "resources.resx" -Destination "$tempDir\WolaiConnector\" -Force

# Copy icons to temp/WolaiConnector root
if (Test-Path "icons") { Copy-Item "icons\*" -Destination "$tempDir\WolaiConnector\" -Force }

# Create Zip
$zipPath = "$outputDir\WolaiConnector.zip"
$mezPath = "$outputDir\WolaiConnector.mez"

if (Test-Path $zipPath) { Remove-Item $zipPath -Force }
Compress-Archive -Path "$tempDir\WolaiConnector\*" -DestinationPath $zipPath -Force

# Rename to .mez
if (Test-Path $mezPath) { Remove-Item $mezPath -Force }
Rename-Item -Path $zipPath -NewName "WolaiConnector.mez" -Force

# Deploy paths
$pbiConnectorPaths = @(
    "$env:USERPROFILE\Documents\Power BI Desktop\Custom Connectors",
    "$env:USERPROFILE\Documents\Microsoft Power BI Desktop\Custom Connectors",
    "$env:USERPROFILE\OneDrive\Documents\Power BI Desktop\Custom Connectors",
    "$env:USERPROFILE\OneDrive - NXP\Documents\Power BI Desktop\Custom Connectors"
)

# Deploy
foreach ($path in $pbiConnectorPaths) {
    if (-not (Test-Path $path)) {
        try {
            New-Item -ItemType Directory -Path $path -Force | Out-Null
            Write-Host "Created dir: $path" -ForegroundColor Yellow
        } catch {
            continue
        }
    }
    
    try {
        Copy-Item $mezPath -Destination $path -Force
        Write-Host "Deployed to: $path" -ForegroundColor Green
    } catch {
        Write-Host "Failed to deploy to: $path" -ForegroundColor Red
    }
}

# Cleanup
Remove-Item -Path $tempDir -Recurse -Force

Write-Host "Build Success!" -ForegroundColor Cyan
Write-Host "File: $mezPath" -ForegroundColor White
