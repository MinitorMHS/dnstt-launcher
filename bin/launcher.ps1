Add-Type -AssemblyName System.Windows.Forms,System.Drawing
[System.Windows.Forms.Application]::EnableVisualStyles()

$apiDef = @"
[DllImport("user32.dll")] public static extern bool ShowWindow(IntPtr hWnd, int nCmdShow);
[DllImport("user32.dll")] public static extern bool SetForegroundWindow(IntPtr hWnd);
"@
$user32 = Add-Type -MemberDefinition $apiDef -Name "Win32Functions" -Namespace Win32Utils -PassThru

$mutexName = "Global\DNSTTLauncher_Unique_Lock"
$newlyCreated = $false
$mutex = New-Object System.Threading.Mutex($true, $mutexName, [ref]$newlyCreated)

if (-not $newlyCreated) {
    [System.Windows.Forms.MessageBox]::Show("DNSTT Launcher is currently running.`n`nPlease check your system tray (bottom right) to open it.", "Already Running", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Information)
    exit
}

$appDataDir = Join-Path $env:LOCALAPPDATA "DNSTTLauncher"
if (-not (Test-Path $appDataDir)) { 
    New-Item -ItemType Directory -Path $appDataDir -Force | Out-Null 
}

$jsonFile     = Join-Path $appDataDir "dns_list.json"
$settingsFile = Join-Path $appDataDir "settings.json"
$lastDnsFile  = Join-Path $appDataDir "last_dns.txt"

$iconFile     = "icon.ico"
$global:dnsttProcess = $null

$defaultDnsData = @(
    @{ Name = "Default Server"; Address = "195.208.4.1" },
    @{ Name = "Google DNS";     Address = "8.8.8.8" },
    @{ Name = "AliDNS";         Address = "223.6.6.6" }
)

$defaultSettings = @{
    Domain      = ""
    PubKey      = ""
    Port        = ""
    ListenAddr  = "127.0.0.1"
    AutoRestart = $false
    RestartInt  = "5"
    RestartUnit = "Minutes"
}

$script:dnsList = @()
$script:settings = $null

$restartTimer = New-Object System.Windows.Forms.Timer

function Load-Data {
    if (Test-Path $jsonFile) {
        try {
            $raw = Get-Content $jsonFile -Raw -ErrorAction Stop
            $script:dnsList = $raw | ConvertFrom-Json
        } catch {
            $script:dnsList = $defaultDnsData
            Save-DnsData
        }
    } else {
        $script:dnsList = $defaultDnsData
        Save-DnsData
    }

    if (Test-Path $settingsFile) {
        try {
            $rawSet = Get-Content $settingsFile -Raw -ErrorAction Stop
            $script:settings = $rawSet | ConvertFrom-Json
            
            if (-not $script:settings.PSObject.Properties['ListenAddr']) { $script:settings | Add-Member -MemberType NoteProperty -Name "ListenAddr" -Value "127.0.0.1" }
            if (-not $script:settings.PSObject.Properties['AutoRestart']) { $script:settings | Add-Member -MemberType NoteProperty -Name "AutoRestart" -Value $false }
            if (-not $script:settings.PSObject.Properties['RestartInt']) { $script:settings | Add-Member -MemberType NoteProperty -Name "RestartInt" -Value "5" }
            if (-not $script:settings.PSObject.Properties['RestartUnit']) { $script:settings | Add-Member -MemberType NoteProperty -Name "RestartUnit" -Value "Minutes" }
        } catch {
            Init-DefaultSettings
        }
    } else {
        Init-DefaultSettings
    }
}

function Init-DefaultSettings {
    $legacyKey = ""
    if (Test-Path "server.pub") { try { $legacyKey = (Get-Content "server.pub" -Raw).Trim() } catch {} }
    $script:settings = $defaultSettings.Clone()
    if ($legacyKey) { $script:settings.PubKey = $legacyKey }
    Save-Settings
}

function Save-DnsData {
    $json = $script:dnsList | ConvertTo-Json -Depth 2
    $json | Set-Content $jsonFile
}

function Save-Settings {
    $json = $script:settings | ConvertTo-Json -Depth 2
    $json | Set-Content $settingsFile
}

function Get-AddressByName($name) {
    $item = $script:dnsList | Where-Object { $_.Name -eq $name }
    if ($item) { return $item.Address }
    return $null
}

Load-Data

$form = New-Object System.Windows.Forms.Form
$form.Text = "DNSTT Launcher"
$form.ClientSize = New-Object System.Drawing.Size(380,210)
$form.StartPosition = "CenterScreen"
$form.FormBorderStyle = "FixedSingle"
$form.MaximizeBox = $false
$form.MinimizeBox = $true
$form.ShowInTaskbar = $true

if (Test-Path $iconFile) {
    try { $form.Icon = New-Object System.Drawing.Icon($iconFile) } catch { $form.Icon = [System.Drawing.SystemIcons]::Shield }
} else { $form.Icon = [System.Drawing.SystemIcons]::Shield }

$toolTip = New-Object System.Windows.Forms.ToolTip

$label = New-Object System.Windows.Forms.Label
$label.Text = "Select DNS Server:"
$label.Location = '20,20'
$label.AutoSize = $true
$form.Controls.Add($label)

$combo = New-Object System.Windows.Forms.ComboBox
$combo.Location = '20,45'
$combo.Size = '280,25'
$combo.DropDownStyle = 'DropDownList'
foreach ($item in $script:dnsList) { $combo.Items.Add($item.Name) }
$form.Controls.Add($combo)

if (Test-Path $lastDnsFile) {
    $lastIp = (Get-Content $lastDnsFile).Trim()
    $match = $script:dnsList | Where-Object { $_.Address -eq $lastIp } | Select-Object -First 1
    if ($match) {
        $combo.SelectedItem = $match.Name
    } elseif ($combo.Items.Count -gt 0) { $combo.SelectedIndex = 0 }
} elseif ($combo.Items.Count -gt 0) { $combo.SelectedIndex = 0 }

$addBtn = New-Object System.Windows.Forms.Button
$addBtn.Text = "+" 
$addBtn.Font = New-Object System.Drawing.Font("Verdana", 14, [System.Drawing.FontStyle]::Bold) 
$addBtn.Location = '305,43'
$addBtn.Size = '28,28'
$addBtn.ForeColor = [System.Drawing.Color]::White
$addBtn.BackColor = [System.Drawing.Color]::SeaGreen 
$addBtn.FlatStyle = [System.Windows.Forms.FlatStyle]::Flat
$addBtn.FlatAppearance.BorderSize = 0
$toolTip.SetToolTip($addBtn, "Add New DNS")
$form.Controls.Add($addBtn)

$delBtn = New-Object System.Windows.Forms.Button
$delBtn.Text = "x" 
$delBtn.Font = New-Object System.Drawing.Font("Verdana", 12, [System.Drawing.FontStyle]::Bold) 
$delBtn.Location = '335,43'
$delBtn.Size = '28,28'
$delBtn.ForeColor = [System.Drawing.Color]::White
$delBtn.BackColor = [System.Drawing.Color]::IndianRed 
$delBtn.FlatStyle = [System.Windows.Forms.FlatStyle]::Flat
$delBtn.FlatAppearance.BorderSize = 0
$toolTip.SetToolTip($delBtn, "Delete DNS")
$form.Controls.Add($delBtn)

$setBtn = New-Object System.Windows.Forms.Button
$setBtn.Text = "Settings"
$setBtn.Font = New-Object System.Drawing.Font("Segoe UI", 9, [System.Drawing.FontStyle]::Regular)
$setBtn.Location = '20,170' 
$setBtn.Size = '80,28'      
$setBtn.ForeColor = [System.Drawing.Color]::White
$setBtn.BackColor = [System.Drawing.Color]::SteelBlue
$setBtn.FlatStyle = [System.Windows.Forms.FlatStyle]::Flat
$setBtn.FlatAppearance.BorderSize = 0
$toolTip.SetToolTip($setBtn, "Configure Tunnel Settings")
$form.Controls.Add($setBtn)

$startBtn = New-Object System.Windows.Forms.Button
$startBtn.Text = "Start"
$startBtn.Location = '20,85'
$startBtn.Size = '75,32'
$form.Controls.Add($startBtn)

$stopBtn = New-Object System.Windows.Forms.Button
$stopBtn.Text = "Stop"
$stopBtn.Location = '105,85'
$stopBtn.Size = '75,32'
$stopBtn.Enabled = $false
$form.Controls.Add($stopBtn)

$restartBtn = New-Object System.Windows.Forms.Button
$restartBtn.Text = "Restart"
$restartBtn.Location = '190,85'
$restartBtn.Size = '75,32'
$restartBtn.Enabled = $false
$form.Controls.Add($restartBtn)

$status = New-Object System.Windows.Forms.Label
$status.Text = "Ready"
$status.ForeColor = [System.Drawing.Color]::Gray
$status.Location = '20,135'
$status.AutoSize = $true
$form.Controls.Add($status)

$linkLabel = New-Object System.Windows.Forms.LinkLabel
$linkLabel.Text = "By Minitor"
$linkLabel.AutoSize = $true
$linkLabel.Location = New-Object System.Drawing.Point(($form.ClientSize.Width - 75), ($form.ClientSize.Height - 25))
$linkLabel.LinkColor = [System.Drawing.Color]::Blue
$linkLabel.Add_LinkClicked({ try { Start-Process "https://github.com/MinitorMHS/dnstt-launcher" } catch {} })
$form.Controls.Add($linkLabel)

$notifyIcon = New-Object System.Windows.Forms.NotifyIcon
$notifyIcon.Icon = $form.Icon
$notifyIcon.Text = "DNSTT Launcher"
$notifyIcon.Visible = $false

$contextMenu = New-Object System.Windows.Forms.ContextMenu

$menuItemShow = $contextMenu.MenuItems.Add("Show")
$menuItemShow.Add_Click({
    $form.Show()
    $user32::ShowWindow($form.Handle, 9)
    $user32::SetForegroundWindow($form.Handle)
    $form.WindowState = 'Normal'
    $form.ShowInTaskbar = $true
    $notifyIcon.Visible = $false
})

$contextMenu.MenuItems.Add("-")

$menuItemExit = $contextMenu.MenuItems.Add("Exit")
$menuItemExit.Add_Click({ 
    $form.Close() 
})
$notifyIcon.ContextMenu = $contextMenu

$notifyIcon.Add_MouseClick({ 
    if ($_.Button -eq 'Left') { 
        $form.Show()
        $user32::ShowWindow($form.Handle, 9)
        $user32::SetForegroundWindow($form.Handle)
        $form.WindowState = 'Normal'
        $form.ShowInTaskbar = $true
        $notifyIcon.Visible = $false
    }
})

function Show-AddWindow {
    $addForm = New-Object System.Windows.Forms.Form
    $addForm.Text = "Add DNS"
    $addForm.Size = New-Object System.Drawing.Size(300, 240)
    $addForm.StartPosition = "CenterParent"
    $addForm.FormBorderStyle = "FixedDialog"
    $addForm.MaximizeBox = $false
    $addForm.MinimizeBox = $false

    $lbl1 = New-Object System.Windows.Forms.Label; $lbl1.Text = "Name:"; $lbl1.Location = '20,20'; $lbl1.AutoSize=$true
    $txtName = New-Object System.Windows.Forms.TextBox; $txtName.Location = '20,40'; $txtName.Size = '240,25'
    $lblHelp1 = New-Object System.Windows.Forms.Label; $lblHelp1.Text = "Ex: My Private Server"; $lblHelp1.ForeColor = 'Gray'; $lblHelp1.Font = New-Object System.Drawing.Font("Segoe UI", 8); $lblHelp1.Location = '20,66'; $lblHelp1.AutoSize = $true
    
    $lbl2 = New-Object System.Windows.Forms.Label; $lbl2.Text = "Address (IP):"; $lbl2.Location = '20,90'; $lbl2.AutoSize=$true
    $txtAddr = New-Object System.Windows.Forms.TextBox; $txtAddr.Location = '20,110'; $txtAddr.Size = '240,25'
    $lblHelp2 = New-Object System.Windows.Forms.Label; $lblHelp2.Text = "Ex: 1.1.1.1 (Port will be removed)"; $lblHelp2.ForeColor = 'Gray'; $lblHelp2.Font = New-Object System.Drawing.Font("Segoe UI", 8); $lblHelp2.Location = '20,136'; $lblHelp2.AutoSize = $true

    $btnSave = New-Object System.Windows.Forms.Button; $btnSave.Text = "Save"; $btnSave.Location = '185,160'
    $addForm.Controls.AddRange(@($lbl1, $txtName, $lblHelp1, $lbl2, $txtAddr, $lblHelp2, $btnSave))
    $addForm.AcceptButton = $btnSave

    $btnSave.Add_Click({
        $newName = $txtName.Text.Trim()
        $rawIp = $txtAddr.Text.Trim()

        if (-not $newName -or -not $rawIp) { [System.Windows.Forms.MessageBox]::Show("Please fill in both fields.", "Error"); return }
        if ($rawIp.Contains(':')) { $cleanIp = $rawIp.Split(':')[0] } else { $cleanIp = $rawIp }
        if (-not [System.Net.IPAddress]::TryParse($cleanIp, [ref]$null)) { [System.Windows.Forms.MessageBox]::Show("Invalid IPv4 address.", "Error"); return }
        
        if ($script:dnsList | Where-Object { $_.Name -eq $newName }) { [System.Windows.Forms.MessageBox]::Show("Name already exists.", "Error"); return }
        if ($script:dnsList | Where-Object { $_.Address -eq $cleanIp }) { [System.Windows.Forms.MessageBox]::Show("IP already exists.", "Error"); return }

        $newItem = @{ Name = $newName; Address = $cleanIp }
        $script:dnsList += $newItem
        Save-DnsData
        $combo.Items.Add($newItem.Name); $combo.SelectedItem = $newItem.Name
        $addForm.DialogResult = "OK"; $addForm.Close()
    })
    $addForm.ShowDialog() | Out-Null; $addForm.Dispose()
}

function Show-DeleteWindow {
    $delForm = New-Object System.Windows.Forms.Form
    $delForm.Text = "Delete DNS"
    $delForm.Size = New-Object System.Drawing.Size(300, 300)
    $delForm.StartPosition = "CenterParent"
    $delForm.FormBorderStyle = "FixedDialog"
    $delForm.MaximizeBox = $false
    $delForm.MinimizeBox = $false

    $checkList = New-Object System.Windows.Forms.CheckedListBox
    $checkList.Location = '20,20'; $checkList.Size = '240,180'; $checkList.CheckOnClick = $false
    foreach ($item in $script:dnsList) { $checkList.Items.Add("$($item.Name) ($($item.Address))") }
    
    $checkList.Add_MouseClick({
        $index = $checkList.IndexFromPoint($_.Location)
        if ($index -ne -1) { $checkList.SetItemChecked($index, -not $checkList.GetItemChecked($index)); $checkList.ClearSelected() }
    })

    $btnDel = New-Object System.Windows.Forms.Button; $btnDel.Text = "Delete Selected"; $btnDel.Location = '140,220'; $btnDel.Size = '120,30'; $btnDel.DialogResult = "OK"
    $delForm.Controls.AddRange(@($checkList, $btnDel))

    if ($delForm.ShowDialog() -eq "OK") {
        $indexes = $checkList.CheckedIndices
        if ($indexes.Count -gt 0) {
            ($indexes | Sort-Object -Descending) | ForEach-Object { 
                [System.Collections.ArrayList]$list = $script:dnsList; $list.RemoveAt($_); $script:dnsList = $list
                $combo.Items.RemoveAt($_)
            }
            Save-DnsData
            if ($combo.Items.Count -gt 0) { $combo.SelectedIndex = 0 } else { $combo.Text = "" }
        }
    }
    $delForm.Dispose()
}

function Show-SettingsWindow {
    $setForm = New-Object System.Windows.Forms.Form
    $setForm.Text = "Global Settings"
    $setForm.Size = New-Object System.Drawing.Size(340, 420) 
    $setForm.StartPosition = "CenterParent"
    $setForm.FormBorderStyle = "FixedDialog"
    $setForm.MaximizeBox = $false
    $setForm.MinimizeBox = $false

    $lblDom = New-Object System.Windows.Forms.Label; $lblDom.Text = "Tunnel Domain:"; $lblDom.Location = '20,20'; $lblDom.AutoSize=$true
    $txtDom = New-Object System.Windows.Forms.TextBox; $txtDom.Location = '20,40'; $txtDom.Size = '280,25'; $txtDom.Text = $script:settings.Domain

    $lblKey = New-Object System.Windows.Forms.Label; $lblKey.Text = "Public Key (Hex):"; $lblKey.Location = '20,80'; $lblKey.AutoSize=$true
    $txtKey = New-Object System.Windows.Forms.TextBox; $txtKey.Location = '20,100'; $txtKey.Size = '280,25'; $txtKey.Text = $script:settings.PubKey

    $lblHost = New-Object System.Windows.Forms.Label; $lblHost.Text = "Listen Host:"; $lblHost.Location = '20,140'; $lblHost.AutoSize=$true
    $cmbHost = New-Object System.Windows.Forms.ComboBox; $cmbHost.Location = '20,160'; $cmbHost.Size = '140,25'; $cmbHost.DropDownStyle = 'DropDownList'
    $cmbHost.Items.AddRange(@("127.0.0.1", "0.0.0.0"))
    if ($cmbHost.Items.Contains($script:settings.ListenAddr)) { $cmbHost.SelectedItem = $script:settings.ListenAddr } else { $cmbHost.SelectedItem = "127.0.0.1" }

    $lblPort = New-Object System.Windows.Forms.Label; $lblPort.Text = "Local Port:"; $lblPort.Location = '180,140'; $lblPort.AutoSize=$true
    $txtPort = New-Object System.Windows.Forms.TextBox; $txtPort.Location = '180,160'; $txtPort.Size = '120,25'; $txtPort.Text = $script:settings.Port

    $chkRestart = New-Object System.Windows.Forms.CheckBox
    $chkRestart.Text = "Enable Auto-Restart"
    $chkRestart.Location = '20,220'
    $chkRestart.AutoSize = $true
    $chkRestart.Checked = $script:settings.AutoRestart

    $lblInt = New-Object System.Windows.Forms.Label
    $lblInt.Text = "Interval:"
    $lblInt.Location = '40,250'
    $lblInt.AutoSize = $true

    $txtInt = New-Object System.Windows.Forms.TextBox
    $txtInt.Location = '95,247'
    $txtInt.Size = '40,25'
    $txtInt.Text = $script:settings.RestartInt

    $cmbUnit = New-Object System.Windows.Forms.ComboBox
    $cmbUnit.Location = '145,247'
    $cmbUnit.Size = '80,25'
    $cmbUnit.DropDownStyle = 'DropDownList'
    $cmbUnit.Items.AddRange(@("Seconds", "Minutes", "Hours"))
    if ($cmbUnit.Items.Contains($script:settings.RestartUnit)) {
        $cmbUnit.SelectedItem = $script:settings.RestartUnit
    } else {
        $cmbUnit.SelectedItem = "Minutes"
    }

    $btnSave = New-Object System.Windows.Forms.Button; $btnSave.Text = "Save Settings"; $btnSave.Location = '200,320'; $btnSave.Size = '100,30'
    $setForm.Controls.AddRange(@($lblDom, $txtDom, $lblKey, $txtKey, $lblHost, $cmbHost, $lblPort, $txtPort, $chkRestart, $lblInt, $txtInt, $cmbUnit, $btnSave))
    $setForm.AcceptButton = $btnSave

    $chkRestart.Add_CheckedChanged({
        $txtInt.Enabled = $chkRestart.Checked
        $lblInt.Enabled = $chkRestart.Checked
        $cmbUnit.Enabled = $chkRestart.Checked
    })
    $txtInt.Enabled = $chkRestart.Checked; $lblInt.Enabled = $chkRestart.Checked; $cmbUnit.Enabled = $chkRestart.Checked

    $btnSave.Add_Click({
        $d = $txtDom.Text.Trim(); $k = $txtKey.Text.Trim(); $p = $txtPort.Text.Trim(); $i = $txtInt.Text.Trim()
        if (-not $d -or -not $k -or -not $p) { [System.Windows.Forms.MessageBox]::Show("Domain, Key, and Port are required.", "Error"); return }
        if (-not ($p -match '^\d+$')) { [System.Windows.Forms.MessageBox]::Show("Port must be a number.", "Error"); return }
        
        if ($chkRestart.Checked) {
            if (-not ($i -match '^\d+$') -or [int]$i -lt 1) { [System.Windows.Forms.MessageBox]::Show("Interval must be a positive number.", "Error"); return }
        }

        $script:settings.Domain = $d; $script:settings.PubKey = $k; $script:settings.Port = $p
        $script:settings.ListenAddr = $cmbHost.SelectedItem
        $script:settings.AutoRestart = $chkRestart.Checked
        $script:settings.RestartInt  = $i
        $script:settings.RestartUnit = $cmbUnit.SelectedItem
        Save-Settings
        $setForm.DialogResult = "OK"; $setForm.Close()
    })
    $setForm.ShowDialog() | Out-Null; $setForm.Dispose()
}

$restartTimer.Add_Tick({
    Stop-Tunnel
    Start-Tunnel
})

function Update-Buttons($isRunning) {
    if ($isRunning) {
        $startBtn.Enabled = $false; $stopBtn.Enabled = $true; $restartBtn.Enabled = $true
        $addBtn.Enabled = $false; $delBtn.Enabled = $false; $setBtn.Enabled = $false; $combo.Enabled = $false
        
        $msg = "Running: $($combo.Text)"
        if ($script:settings.AutoRestart) { 
            $msg += " (Auto-Restart: $($script:settings.RestartInt) $($script:settings.RestartUnit))" 
        }
        $status.Text = $msg
        $status.ForeColor = 'Green'
    } else {
        $startBtn.Enabled = $true; $stopBtn.Enabled = $false; $restartBtn.Enabled = $false
        $addBtn.Enabled = $true; $delBtn.Enabled = $true; $setBtn.Enabled = $true; $combo.Enabled = $true
        $status.Text = "Stopped"; $status.ForeColor = 'Gray'
    }
}

function Start-Tunnel {
    $name = $combo.Text
    $ip = Get-AddressByName $name
    
    if (-not $ip) { [System.Windows.Forms.MessageBox]::Show("Please select a valid DNS server.", "Error"); return }
    
    if (-not $script:settings.Domain -or -not $script:settings.PubKey -or -not $script:settings.Port) {
        [System.Windows.Forms.MessageBox]::Show("Connection settings are missing.`n`nPlease click 'Settings' to configure Domain, Public Key, and Port.", "Configuration Missing", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Warning)
        Show-SettingsWindow
        return 
    }
    
    Set-Content -Path $lastDnsFile -Value $ip
    if ($ip.Contains(':')) { $ip = $ip.Split(':')[0] }
    
    $domain = $script:settings.Domain
    $pubKey = $script:settings.PubKey
    $port   = $script:settings.Port
    $listen = $script:settings.ListenAddr
    if (-not $listen) { $listen = "127.0.0.1" }

    $args = @("-udp", "$ip`:53", "-utls", "iOS_14", "-pubkey", "$pubKey", "$domain", "$listen`:$port")
    
    try {
        $global:dnsttProcess = Start-Process -FilePath "dnstt-client-windows.exe" -ArgumentList $args -NoNewWindow -PassThru
        Update-Buttons $true
        
        if ($script:settings.AutoRestart) {
            $val = [int]$script:settings.RestartInt
            $unit = $script:settings.RestartUnit
            $ms = 0
            
            switch ($unit) {
                "Seconds" { $ms = $val * 1000 }
                "Minutes" { $ms = $val * 60 * 1000 }
                "Hours"   { $ms = $val * 3600 * 1000 }
            }

            if ($ms -gt 0) {
                $restartTimer.Interval = $ms
                $restartTimer.Start()
            }
        }
    } catch {
        [System.Windows.Forms.MessageBox]::Show("Failed to start dnstt: $_", "Error")
    }
}

function Stop-Tunnel {
    $restartTimer.Stop()

    if ($global:dnsttProcess -and -not $global:dnsttProcess.HasExited) {
        Stop-Process -Id $global:dnsttProcess.Id -Force -ErrorAction SilentlyContinue
    }
    $global:dnsttProcess = $null
    Update-Buttons $false
}

$addBtn.Add_Click({ Show-AddWindow })
$delBtn.Add_Click({ Show-DeleteWindow })
$setBtn.Add_Click({ Show-SettingsWindow })
$startBtn.Add_Click({ Start-Tunnel })
$stopBtn.Add_Click({ Stop-Tunnel })
$restartBtn.Add_Click({ Stop-Tunnel; Start-Tunnel })

$form.Add_Load({ $user32::ShowWindow($form.Handle, 9); $form.Activate() })
$form.Add_Resize({ if ($form.WindowState -eq 'Minimized') { $form.ShowInTaskbar = $false; $form.Hide(); $notifyIcon.Visible = $true } })

$form.Add_FormClosing({
    if ($global:dnsttProcess -and -not $global:dnsttProcess.HasExited) {
        if ([System.Windows.Forms.MessageBox]::Show("Stop connection and exit?", "Confirm Exit", "YesNo", "Warning") -eq "No") { 
            $_.Cancel = $true
            return 
        }
    }
    Stop-Tunnel
    $notifyIcon.Visible = $false
})

[System.Windows.Forms.Application]::Run($form)
