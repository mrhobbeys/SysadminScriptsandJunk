# Windows User Directories Info Script - Sends user directory list as a text file to Discord

# Load environment variables from .env file
$envFile = ".env"
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

# Get list of user directories with details
$userDirs = Get-ChildItem -Path "C:\Users" -Directory

# Create a temporary text file named after the computer
$tempFile = [System.IO.Path]::Combine([System.IO.Path]::GetTempPath(), "$env:COMPUTERNAME.txt")

# Write header and details to the file
$runTime = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
"Script run on: $runTime" | Out-File -FilePath $tempFile
"Scanned directory: C:\Users" | Out-File -FilePath $tempFile -Append
"" | Out-File -FilePath $tempFile -Append
"User directories:" | Out-File -FilePath $tempFile -Append
foreach ($dir in $userDirs) {
    $createTime = $dir.CreationTime.ToString("yyyy-MM-dd HH:mm:ss")
    "- Folder: $($dir.Name), Created: $createTime" | Out-File -FilePath $tempFile -Append
}

# Send the file to Discord using HttpClient for multipart
Add-Type -AssemblyName System.Net.Http
$client = New-Object System.Net.Http.HttpClient
$content = New-Object System.Net.Http.MultipartFormDataContent
$content.Add([System.Net.Http.StringContent]::new(":file_folder: User directories list attached."), "content")
$fileStream = [System.IO.File]::OpenRead($tempFile)
$fileContent = New-Object System.Net.Http.StreamContent($fileStream)
$content.Add($fileContent, "file", [System.IO.Path]::GetFileName($tempFile))
$response = $client.PostAsync($webhookUrl, $content).Result
$fileStream.Close()
$client.Dispose()

# Clean up the temporary file
Remove-Item $tempFile
