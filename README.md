# SysAdmin PowerShell Scripts

This repository contains PowerShell scripts designed for system administrators to automate tasks like monitoring user directories, folder contents, and browser history. All scripts send results to a Discord webhook for easy notification and logging.

## Setup

1. **Clone the repository:**
   ```bash
   git clone https://github.com/mrhobbeys/SysadminScriptsandJunk.git
   cd SysadminScriptsandJunk
   ```

   **Quick Setup (One-liner):** Alternatively, use this PowerShell one-liner to download the repo as a ZIP (no git required) and set up the webhook:
   ```powershell
   powershell -Command "$url = 'https://github.com/mrhobbeys/SysadminScriptsandJunk/archive/refs/heads/main.zip'; $zip = '$env:TEMP\repo.zip'; Invoke-WebRequest -Uri $url -OutFile $zip; Expand-Archive -Path $zip -DestinationPath '$env:TEMP'; $dir = Get-ChildItem '$env:TEMP' | Where-Object { $_.Name -like 'SysadminScriptsandJunk-*' } | Select-Object -First 1; cd $dir.FullName; $webhook = Read-Host 'Enter Discord Webhook URL'; 'WEBHOOK_URL=' + $webhook | Out-File .env"
   ```

2. **Create a `.env` file** in the repository root with your Discord webhook URL (if not using the one-liner):
   ```
   WEBHOOK_URL=https://discord.com/api/webhooks/YOUR_WEBHOOK_ID/YOUR_WEBHOOK_TOKEN
   ```
   - Get a webhook URL from your Discord server settings.
   - **Security Note:** Never commit `.env` files. The `.gitignore` is configured to block them.

3. **Ensure PowerShell execution policy allows scripts:**
   ```powershell
   Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser
   ```

4. **Run scripts** with `powershell.exe -ExecutionPolicy Bypass -File "script.ps1" [parameters]`.

## Scripts

### 1. DemoPowerShellDiscordHook.ps1
**Purpose:** Demonstrates sending messages to Discord by posting lines of the Star-Spangled Banner.

**Usage:**
```powershell
powershell.exe -ExecutionPolicy Bypass -File "DemoPowerShellDiscordHook.ps1"
```

**Output:** Sends each line of the anthem to Discord with a 2-second pause.

### 2. getFolderInfo.ps1
**Purpose:** Lists all user directories in `C:\Users` and sends details to Discord.

**Usage:**
```powershell
powershell.exe -ExecutionPolicy Bypass -File "getFolderInfo.ps1"
```

**Output:** Discord message with a text file attachment containing user directory names, creation dates, and run info.

### 3. getFolderContents.ps1
**Purpose:** Lists detailed contents of a specified folder and sends to Discord.

**Parameters:**
- `-FolderPath` (string, default: "C:\Users"): Path to the folder to scan.

**Usage:**
```powershell
powershell.exe -ExecutionPolicy Bypass -File "getFolderContents.ps1" -FolderPath "C:\Windows"
```

**Output:** Discord message with a text file attachment containing file/folder names, sizes, creation/modification dates, and types in a table format.

### 4. getWebHistory.ps1
**Purpose:** Extracts Microsoft Edge browsing history for all profiles of a specified user and sends to Discord. Useful for investigations.

**Parameters:**
- `-GetUser` (string, default: current user): Username (e.g., "user").
- `-DaysBack` (int, default: 7): Number of days of history to retrieve.

**Usage:**
```powershell
powershell.exe -ExecutionPolicy Bypass -File "getWebHistory.ps1" -GetUser "user" -DaysBack 3
```

**Requirements:** The script automatically downloads `sqlite3.exe` if not present to read the Edge history database.

**Output:** Separate CSV files for each Edge profile (e.g., Default, Profile 1), named `COMPUTERNAME-user-PROFILENAME.csv`, attached to Discord messages. Each CSV contains URLs, titles, and formatted visit times from the last N days.

## Security and Best Practices

- **Webhook Security:** Keep your Discord webhook URL private. Rotate it if compromised.
- **Execution Policy:** Use `Bypass` only for trusted scripts. Reset to `RemoteSigned` after use.
- **Permissions:** Run scripts with appropriate privileges (e.g., Administrator for system folders).
- **Data Handling:** These scripts access sensitive data (e.g., browsing history). Use ethically and legally.
- **Git:** `.gitignore` blocks sensitive files. Never commit `.env` or other secrets.

## Troubleshooting

- **Script won't run:** Check execution policy with `Get-ExecutionPolicy`.
- **Webhook errors:** Verify the URL in `.env` and ensure Discord permissions.
- **File access errors:** Run as Administrator for system paths.
- **SQLite issues:** The script handles downloading `sqlite3.exe` automatically.

## Contributing

Feel free to submit issues or pull requests for improvements.

## License

This project is for educational and administrative use. Ensure compliance with local laws and policies.