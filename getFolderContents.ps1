# Folder Contents Info Script - Sends detailed folder contents as a text file to Discord

param(
    [string]$FolderPath = "C:\Users"
)

# Load environment variables from .env file
$envFile = Join-Path $PSScriptRoot ".env"
if (Test-Path $envFile) {
    Get-Content $envFile | ForEach-Object {
        if ($_ -match '^([^=]+)=(.*)$') {
            $key = $matches[1].Trim()
            $value = $matches[2].Trim()
            [Environment]::SetEnvironmentVariable($key, $value)
        }
    }
}

$webhookUrl = $env:WEBHOOK_URL
if (-not $webhookUrl) {
    Write-Error "Webhook URL not found. Ensure .env file exists in the script's directory with WEBHOOK_URL."
    exit
}

# Check if folder path exists
if (-not (Test-Path $FolderPath)) {
    Write-Error "Folder path '$FolderPath' does not exist."
    exit
}

# Get folder contents
$contents = Get-ChildItem -Path $FolderPath

# Create a temporary text file named after the computer
$tempFile = [System.IO.Path]::Combine([System.IO.Path]::GetTempPath(), "$env:COMPUTERNAME.txt")

# Write header and details to the file
$runTime = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
"Script run on: $runTime" | Out-File -FilePath $tempFile
"Scanned directory: $FolderPath" | Out-File -FilePath $tempFile -Append
"" | Out-File -FilePath $tempFile -Append
"Folder contents:" | Out-File -FilePath $tempFile -Append
"----------------------------------------------------------------------------------------------------------------" | Out-File -FilePath $tempFile -Append
"Name                          | Modified                  | Created                   | Type          | Size (KB)" | Out-File -FilePath $tempFile -Append
"----------------------------------------------------------------------------------------------------------------" | Out-File -FilePath $tempFile -Append

foreach ($item in $contents) {
    $name = $item.Name.PadRight(30).Substring(0,30)
    $modified = $item.LastWriteTime.ToString("yyyy-MM-dd HH:mm:ss").PadRight(25)
    $created = $item.CreationTime.ToString("yyyy-MM-dd HH:mm:ss").PadRight(25)
    $type = if ($item.PSIsContainer) { "Directory" } else { $item.Extension.ToUpper().TrimStart('.') + " File" }
    $type = $type.PadRight(14)
    $size = if ($item.PSIsContainer) { "" } else { [math]::Round($item.Length / 1KB, 2).ToString().PadLeft(10) }
    "$name| $modified| $created| $type| $size" | Out-File -FilePath $tempFile -Append
}

# Send the file to Discord using HttpClient for multipart
try {
    Add-Type -AssemblyName System.Net.Http
    $client = New-Object System.Net.Http.HttpClient
    $content = New-Object System.Net.Http.MultipartFormDataContent
    $content.Add([System.Net.Http.StringContent]::new(":file_folder: Folder contents list attached."), "content")
    $fileStream = [System.IO.File]::OpenRead($tempFile)
    $fileContent = New-Object System.Net.Http.StreamContent($fileStream)
    $content.Add($fileContent, "file", [System.IO.Path]::GetFileName($tempFile))
    $response = $client.PostAsync($webhookUrl, $content).Result
    if (-not $response.IsSuccessStatusCode) {
        Write-Error "Failed to send to Discord: $($response.StatusCode) - $($response.ReasonPhrase)"
    }
} catch {
    Write-Error "Error sending to Discord: $_"
} finally {
    if ($fileStream) { $fileStream.Close() }
    if ($client) { $client.Dispose() }
}

# Clean up the temporary file
Remove-Item $tempFile
