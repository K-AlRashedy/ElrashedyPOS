; Inno Setup script for the Al Rashedy desktop POS terminal.
; Build: ISCC.exe /DMyAppVersion=1.0.0 installer\pos.iss

#ifndef MyAppVersion
#define MyAppVersion "1.0.0"
#endif

#define MyAppName "Al Rashedy POS"
#define MyAppPublisher "Al Rashedy"
#define MyAppExeName "elrashedy_pos.exe"
#define BuildDir "..\build\windows\x64\runner\Release"

[Setup]
AppId={{7C3E9A52-4B8D-4E6F-9A21-3D5B8C1E7F04}
AppName={#MyAppName}
AppVersion={#MyAppVersion}
AppVerName={#MyAppName} {#MyAppVersion}
AppPublisher={#MyAppPublisher}
DefaultDirName={autopf}\AlRashedyPOS
DefaultGroupName={#MyAppName}
UninstallDisplayIcon={app}\{#MyAppExeName}
UninstallDisplayName={#MyAppName}
OutputDir=..\dist
OutputBaseFilename=ElrashedyPOS-Setup-{#MyAppVersion}
SetupIconFile=..\windows\runner\resources\app_icon.ico
Compression=lzma2/max
SolidCompression=yes
WizardStyle=modern
ArchitecturesAllowed=x64compatible
ArchitecturesInstallIn64BitMode=x64compatible
PrivilegesRequired=lowest
CloseApplications=yes
RestartApplications=no
DisableProgramGroupPage=yes
VersionInfoVersion={#MyAppVersion}.0
VersionInfoCompany={#MyAppPublisher}
VersionInfoDescription={#MyAppName} installer

[Languages]
Name: "english"; MessagesFile: "compiler:Default.isl"

[Tasks]
Name: "desktopicon"; Description: "Create a desktop shortcut"; GroupDescription: "Additional shortcuts:"

[Files]
Source: "{#BuildDir}\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs

[Icons]
Name: "{group}\{#MyAppName}"; Filename: "{app}\{#MyAppExeName}"
Name: "{group}\Uninstall {#MyAppName}"; Filename: "{uninstallexe}"
Name: "{autodesktop}\{#MyAppName}"; Filename: "{app}\{#MyAppExeName}"; Tasks: desktopicon

[Run]
Filename: "{app}\{#MyAppExeName}"; Description: "Launch {#MyAppName}"; Flags: nowait postinstall skipifsilent