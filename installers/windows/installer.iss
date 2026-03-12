; Inno Setup script for Ancient Anguish Client
; Build: iscc /DMyAppVersion="1.0.0" installer.iss

#define MyAppName "Ancient Anguish Client"
#define MyAppExeName "ancient_anguish_client.exe"
#define MyAppPublisher "Ancient Anguish"
#define MyAppURL "https://github.com/samilton/ancient-anguish-client"

#ifndef MyAppVersion
  #define MyAppVersion "0.1.0"
#endif

[Setup]
AppId={{C6A38677-133C-4877-9EC8-BFB1C6CB839A}
AppName={#MyAppName}
AppVersion={#MyAppVersion}
AppPublisher={#MyAppPublisher}
AppPublisherURL={#MyAppURL}
AppSupportURL={#MyAppURL}
DefaultDirName={autopf}\AncientAnguishClient
DefaultGroupName={#MyAppName}
DisableProgramGroupPage=yes
OutputDir=..\..\releases
OutputBaseFilename=ancient-anguish-client-windows-x64-setup-{#MyAppVersion}
SetupIconFile=..\..\windows\runner\resources\app_icon.ico
UninstallDisplayIcon={app}\{#MyAppExeName}
Compression=lzma2/ultra64
SolidCompression=yes
WizardStyle=modern
ArchitecturesAllowed=x64compatible
ArchitecturesInstallIn64BitMode=x64compatible
PrivilegesRequired=lowest
PrivilegesRequiredOverridesAllowed=dialog

[Languages]
Name: "english"; MessagesFile: "compiler:Default.isl"

[Tasks]
Name: "desktopicon"; Description: "{cm:CreateDesktopIcon}"; GroupDescription: "{cm:AdditionalIcons}"; Flags: unchecked

[Files]
; Application files from Flutter build output
Source: "..\..\build\windows\x64\runner\Release\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs
; MSVC Redistributable (only extracted if needed)
Source: "..\..\build\vc_redist.x64.exe"; DestDir: "{tmp}"; Flags: deleteafterinstall; Check: VCRedistNeedsInstall

[Icons]
Name: "{group}\{#MyAppName}"; Filename: "{app}\{#MyAppExeName}"
Name: "{group}\Uninstall {#MyAppName}"; Filename: "{uninstallexe}"
Name: "{autodesktop}\{#MyAppName}"; Filename: "{app}\{#MyAppExeName}"; Tasks: desktopicon

[Run]
; Install VC++ Redistributable silently if needed
Filename: "{tmp}\vc_redist.x64.exe"; Parameters: "/install /quiet /norestart"; StatusMsg: "Installing Visual C++ Redistributable..."; Check: VCRedistNeedsInstall; Flags: waituntilterminated
; Launch app after install
Filename: "{app}\{#MyAppExeName}"; Description: "{cm:LaunchProgram,{#StringChange(MyAppName, '&', '&&')}}"; Flags: nowait postinstall skipifsilent

[Code]
function VCRedistNeedsInstall: Boolean;
var
  RegKey: String;
begin
  // Check for VC++ 2015-2022 Redistributable (x64)
  RegKey := 'SOFTWARE\Microsoft\VisualStudio\14.0\VC\Runtimes\x64';
  Result := not RegKeyExists(HKLM, RegKey);
  if Result then
  begin
    // Also check WOW6432Node
    RegKey := 'SOFTWARE\WOW6432Node\Microsoft\VisualStudio\14.0\VC\Runtimes\x64';
    Result := not RegKeyExists(HKLM, RegKey);
  end;
end;
