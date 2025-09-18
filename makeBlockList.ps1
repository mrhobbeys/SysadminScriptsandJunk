# makeBlockList.ps1 - Block websites in hosts file and report to Discord

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

# Collect websites to block
$sites = @()
while ($true) {
    $site = Read-Host "Enter website to block (or press Enter to finish)"
    if ([string]::IsNullOrWhiteSpace($site)) {
        break
    }
    $sites += $site.Trim()
}

if ($sites.Count -eq 0) {
    Write-Host "No websites entered. Exiting."
    exit
}

# Path to hosts file
$hostsPath = "C:\Windows\System32\drivers\etc\hosts"

# Block each site
foreach ($site in $sites) {
    # Check if already blocked
    $content = Get-Content $hostsPath -Raw
    if ($content -notmatch "^127\.0\.0\.1\s+$site") {
        # Add to hosts
        Add-Content $hostsPath "127.0.0.1 $site"
        Write-Host "Blocked: $site"
    } else {
        Write-Host "Already blocked: $site"
    }
}

# Prepare Discord message (limit to 10 sites)
$messageSites = $sites | Select-Object -First 10
$message = "```\n"
foreach ($site in $messageSites) {
    $message += "$site = blocked on $env:COMPUTERNAME`n"
}
$message += "```"

# Send to Discord
try {
    Add-Type -AssemblyName System.Net.Http
    $client = New-Object System.Net.Http.HttpClient
    $content = New-Object System.Net.Http.MultipartFormDataContent
    $content.Add([System.Net.Http.StringContent]::new($message), "content")
    $response = $client.PostAsync($webhookUrl, $content).Result
    if (-not $response.IsSuccessStatusCode) {
        Write-Error "Failed to send to Discord: $($response.StatusCode) - $($response.ReasonPhrase)"
    }
} catch {
    Write-Error "Error sending to Discord: $_"
} finally {
    if ($client) { $client.Dispose() }
}