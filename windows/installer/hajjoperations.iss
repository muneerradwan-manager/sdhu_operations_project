; ============================================================
;  Hajj Operations — Windows Installer (Inno Setup 6.3+)
;
;  Build:
;    powershell -ExecutionPolicy Bypass -File windows\installer\build_installer.ps1
;
;  Or manually, after `flutter build windows --release`:
;    "C:\Program Files (x86)\Inno Setup 6\ISCC.exe" windows\installer\hajjoperations.iss
; ============================================================

#ifndef MyAppVersion
  #define MyAppVersion "0.1.0"
#endif

#define MyAppName        "Hajj Operations"
#define MyAppNameAr      "عمليات الحج"
#define MyAppPublisher   "Syrian Hajj Mission"
#define MyAppExeName     "hajjoperations.exe"
#define BuildDir         "..\..\build\windows\x64\runner\Release"
#define IconFile         "..\runner\resources\app_icon.ico"

[Setup]
; A stable, unique identity. NEVER change this value — Windows uses it to
; recognise an existing installation and to perform in-place upgrades.
AppId={{8F3C1A72-5D4E-4B96-9E1F-2C7A0B6D33A1}
AppName={#MyAppName}
AppVersion={#MyAppVersion}
AppVerName={#MyAppName} {#MyAppVersion}
VersionInfoVersion={#MyAppVersion}
AppPublisher={#MyAppPublisher}
AppCopyright=Copyright (C) 2026 {#MyAppPublisher}. All rights reserved.

DefaultDirName={autopf}\{#MyAppName}
DefaultGroupName={#MyAppName}
UninstallDisplayName={#MyAppName}
UninstallDisplayIcon={app}\{#MyAppExeName}

; 64-bit only — Flutter's Windows target produces an x64 binary.
ArchitecturesAllowed=x64compatible
ArchitecturesInstallIn64BitMode=x64compatible
MinVersion=10.0

; Writing to Program Files (and installing the VC++ runtime) needs elevation.
PrivilegesRequired=admin

; Shut the app down cleanly if the user is upgrading over a running copy.
CloseApplications=yes
RestartApplications=no

Compression=lzma2/max
SolidCompression=yes
WizardStyle=modern
SetupIconFile={#IconFile}
DisableProgramGroupPage=yes
OutputDir=..\..\build\windows\installer
OutputBaseFilename=HajjOperations-{#MyAppVersion}-x64-setup

[Languages]
Name: "en"; MessagesFile: "compiler:Default.isl"
; Arabic ships with Inno Setup 6.7+ (Languages\Arabic.isl) and lays the wizard
; out right-to-left. The user picks the language on the first page of setup.
Name: "ar"; MessagesFile: "compiler:Languages\Arabic.isl"

[CustomMessages]
en.CreateDesktopIcon=Create a &desktop shortcut
en.LaunchApp=Launch {#MyAppName}
en.InstallingRuntime=Installing the Microsoft Visual C++ runtime...
en.DownloadingRuntime=Downloading the Microsoft Visual C++ runtime...
ar.CreateDesktopIcon=إنشاء اختصار على سطح المكتب
ar.LaunchApp=تشغيل {#MyAppNameAr}
ar.InstallingRuntime=جارٍ تثبيت مكتبات Microsoft Visual C++ ...
ar.DownloadingRuntime=جارٍ تنزيل مكتبات Microsoft Visual C++ ...

[Tasks]
Name: "desktopicon"; Description: "{cm:CreateDesktopIcon}"; GroupDescription: "{cm:AdditionalIcons}"; Flags: unchecked

[Files]
; The whole Release folder: the exe, flutter_windows.dll, every plugin DLL and
; the data\ bundle (flutter_assets, icudtl.dat, app.so). The app will not start
; if any of these are missing, so they ship together.
; .lib / .exp / .pdb are link-time and debug artefacts — not needed at runtime.
Source: "{#BuildDir}\*"; DestDir: "{app}"; \
    Excludes: "*.lib,*.exp,*.pdb"; \
    Flags: recursesubdirs createallsubdirs ignoreversion

[Icons]
Name: "{group}\{#MyAppName}";        Filename: "{app}\{#MyAppExeName}"
Name: "{group}\{cm:UninstallProgram,{#MyAppName}}"; Filename: "{uninstallexe}"
Name: "{autodesktop}\{#MyAppName}";  Filename: "{app}\{#MyAppExeName}"; Tasks: desktopicon

[Run]
; Install the VC++ redistributable first (only reached if it is missing).
Filename: "{tmp}\vc_redist.x64.exe"; Parameters: "/install /quiet /norestart"; \
    StatusMsg: "{cm:InstallingRuntime}"; Check: VCRedistNeeded; Flags: waituntilterminated
Filename: "{app}\{#MyAppExeName}"; Description: "{cm:LaunchApp}"; \
    Flags: nowait postinstall skipifsilent

[Code]
const
  VCRedistUrl = 'https://aka.ms/vs/17/release/vc_redist.x64.exe';

var
  NeedsVCRedist: Boolean;
  DownloadPage: TDownloadWizardPage;

{ The Flutter runner and its plugin DLLs are built with MSVC, so they depend on
  the VC++ 2015-2022 redistributable. It is present on most machines but NOT
  guaranteed - a clean Windows install will fail to start the app without it. }
function VCRedistInstalled: Boolean;
var
  Installed: Cardinal;
begin
  Result := RegQueryDWordValue(HKLM,
    'SOFTWARE\Microsoft\VisualStudio\14.0\VC\Runtimes\x64', 'Installed', Installed)
    and (Installed = 1);
end;

function VCRedistNeeded: Boolean;
begin
  Result := NeedsVCRedist;
end;

function OnDownloadProgress(const Url, FileName: String; const Progress, ProgressMax: Int64): Boolean;
begin
  Result := True;
end;

procedure InitializeWizard;
begin
  NeedsVCRedist := not VCRedistInstalled;
  DownloadPage := CreateDownloadPage(
    SetupMessage(msgWizardPreparing), ExpandConstant('{cm:DownloadingRuntime}'), @OnDownloadProgress);
end;

{ Fetch the redistributable just before files are copied, using Inno's built-in
  downloader (6.1+) - no third-party plugin and nothing extra to bundle. }
function NextButtonClick(CurPageID: Integer): Boolean;
begin
  Result := True;
  if (CurPageID = wpReady) and NeedsVCRedist then
  begin
    DownloadPage.Clear;
    DownloadPage.Add(VCRedistUrl, 'vc_redist.x64.exe', '');
    DownloadPage.Show;
    try
      try
        DownloadPage.Download;
      except
        { Offline or blocked: warn, but let the install continue - the runtime
          may still be supplied by the machine's own update channel. }
        SuppressibleMsgBox(AddPeriod(GetExceptionMessage), mbError, MB_OK, IDOK);
        NeedsVCRedist := False;
      end;
    finally
      DownloadPage.Hide;
    end;
  end;
end;
