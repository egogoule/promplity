; Inno Setup Script for Promplity Client
; Generated for Flutter Windows Application

#define MyAppName "Promplity Client"
#define MyAppVersion "0.0.1"
#define MyAppPublisher "Promplity"
#define MyAppExeName "ssh_client.exe"
#define BuildPath "build\windows\x64\runner\Release"

[Setup]
; NOTE: The value of AppId uniquely identifies this application.
; Do not use the same AppId value in installers for other applications.
AppId={{D3F7A1B2-C4E5-4D6F-BD7A-E8C9A0B1C2D3}
AppName={#MyAppName}
AppVersion={#MyAppVersion}
AppPublisher={#MyAppPublisher}
DefaultDirName={localappdata}\{#MyAppName}
DisableProgramGroupPage=yes
; Remove the following line to run in administrative install mode (install for all users).
PrivilegesRequired=lowest
OutputDir=dist
OutputBaseFilename=PromplityClientSetup
SetupIconFile=windows\runner\resources\app_icon.ico
Compression=lzma
SolidCompression=yes
WizardStyle=modern

[Languages]
Name: "english"; MessagesFile: "compiler:Default.isl"
Name: "russian"; MessagesFile: "compiler:Languages\Russian.isl"

[Tasks]
Name: "desktopicon"; Description: "{cm:CreateDesktopIcon}"; GroupDescription: "{cm:AdditionalIcons}"; Flags: unchecked

[Files]
Source: "{#BuildPath}\{#MyAppExeName}"; DestDir: "{app}"; Flags: ignoreversion
Source: "{#BuildPath}\*.dll"; DestDir: "{app}"; Flags: ignoreversion
Source: "{#BuildPath}\data\*"; DestDir: "{app}\data"; Flags: ignoreversion recursesubdirs createallsubdirs
Source: "windows\runner\resources\app_icon.ico"; DestDir: "{app}"; Flags: ignoreversion

[Icons]
Name: "{autoprograms}\{#MyAppName}"; Filename: "{app}\{#MyAppExeName}"; IconFilename: "{app}\app_icon.ico"
Name: "{autodesktop}\{#MyAppName}"; Filename: "{app}\{#MyAppExeName}"; Tasks: desktopicon; IconFilename: "{app}\app_icon.ico"

[Run]
Filename: "{app}\{#MyAppExeName}"; Description: "{cm:LaunchProgram,{#StringChange(MyAppName, '&', '&&')}}"; Flags: nowait postinstall skipifsilent
