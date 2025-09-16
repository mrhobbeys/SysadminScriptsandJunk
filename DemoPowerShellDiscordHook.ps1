# Star Spangled Banner Test Script - Sends each line to Discord

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

$anthem = @(
    "O say can you see, by the dawn's early light",
    "What so proudly we hailed at the twilight's last gleaming,",
    "Whose broad stripes and bright stars through the perilous fight,",
    "O'er the ramparts we watched, were so gallantly streaming?",
    "And the rocket's red glare, the bombs bursting in air,",
    "Gave proof through the night that our flag was still there;",
    "O say does that star-spangled banner yet wave",
    "O'er the land of the free and the home of the brave?"
)

foreach ($line in $anthem) {
    $payload = @{ content = "````$line````" } | ConvertTo-Json
    Invoke-RestMethod -Uri $webhookUrl -Method 'Post' -ContentType 'application/json' -Body $payload
    Start-Sleep -Seconds 2
}

$finalPayload = @{ content = ':musical_note: Test complete! :musical_note:' } | ConvertTo-Json
Invoke-RestMethod -Uri $webhookUrl -Method 'Post' -ContentType 'application/json' -Body $finalPayload