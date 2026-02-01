[Setup]
AppName=DNSTT Launcher
AppVersion=1.0
DefaultDirName={autopf}\DNSTT-Launcher
DefaultGroupName=DNSTT Launcher
OutputBaseFilename=DNSTT_Launcher_Setup
Compression=lzma
SolidCompression=yes
SetupIconFile=bin\icon.ico
ArchitecturesAllowed=x86 x64 arm64
ArchitecturesInstallIn64BitMode=x64 arm64

[Files]
Source: "bin\launcher.ps1"; DestDir: "{app}\bin"; Flags: ignoreversion
Source: "bin\dns_list.json"; DestDir: "{app}\bin"; Flags: ignoreversion
Source: "bin\icon.ico"; DestDir: "{app}\bin"; Flags: ignoreversion
Source: "run.vbs"; DestDir: "{app}"; Flags: ignoreversion

Source: "bin\dnstt-client-arm64.exe"; DestDir: "{app}\bin"; DestName: "dnstt-client-windows.exe"; Check: IsArm64; Flags: ignoreversion
Source: "bin\dnstt-client-x64.exe";   DestDir: "{app}\bin"; DestName: "dnstt-client-windows.exe"; Check: Is64BitInstallMode and not IsArm64; Flags: ignoreversion
Source: "bin\dnstt-client-x32.exe";   DestDir: "{app}\bin"; DestName: "dnstt-client-windows.exe"; Check: not Is64BitInstallMode; Flags: ignoreversion

[Icons]
Name: "{group}\DNSTT Launcher"; Filename: "{app}\run.vbs"; IconFilename: "{app}\bin\icon.ico"
Name: "{commondesktop}\DNSTT Launcher"; Filename: "{app}\run.vbs"; IconFilename: "{app}\bin\icon.ico"

[Run]
Description: "Launch DNSTT Launcher Now"; Flags: postinstall shellexec skipifsilent; Filename: "{app}\run.vbs"
