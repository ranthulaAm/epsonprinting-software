; ============================================================================
; Print Helper — Classic Windows 10/11 (.exe) Installer Script (Inno Setup 6)
; 100% Offline-First Desktop App • Permissive Open-Source License (MIT)
;
; Includes selectable installation components so the base app stays fast & small
; while allowing offline installation of:
;   - Base Print Helper & PDF Toolkit (PDFium BSD-3-Clause + qpdf Apache-2.0 + Noto Sans Sinhala OFL-1.1)
;   - Optional Component: Tesseract 5 OCR Engine + Sinhala (sin.traineddata) & English (eng.traineddata) (Apache-2.0)
;   - Optional Component: LibreOffice Headless Offline Office Conversion Runtime (MPL-2.0)
;
; Build instructions on Windows:
;   1. flutter build windows --release
;   2. iscc windows\installer\print_helper_setup.iss
;   3. Output: build\installer\PrintHelper_Setup_1.0.0_x64.exe
; ============================================================================

#define MyAppName "Print Helper"
#define MyAppVersion "1.0.0"
#define MyAppPublisher "Print Helper Open Source Project"
#define MyAppExeName "print_helper.exe"
#define BuildReleaseDir "..\..\build\windows\x64\runner\Release"
#define OfflineComponentsDir "..\..\offline_components"

[Setup]
AppId={{8E9A7410-5B3C-4D2E-9F1A-7C8B9E0D1F2A}
AppName={#MyAppName}
AppVersion={#MyAppVersion}
AppPublisher={#MyAppPublisher}
DefaultDirName={autopf}\{#MyAppName}
DefaultGroupName={#MyAppName}
DisableProgramGroupPage=yes
ArchitecturesAllowed=x64compatible
ArchitecturesInstallIn64BitMode=x64compatible
PrivilegesRequired=lowest
PrivilegesRequiredOverridesAllowed=dialog
OutputDir=..\..\build\installer
OutputBaseFilename=PrintHelper_Setup_{#MyAppVersion}_x64
Compression=lzma2/ultra64
SolidCompression=yes
WizardStyle=modern
UninstallDisplayIcon={app}\{#MyAppExeName}

[Languages]
Name: "english"; MessagesFile: "compiler:Default.isl"

[Types]
Name: "compact"; Description: "Compact Installation (Print Manager, PDF Viewer, 13 Page Tools, Annotate, Sign, Security & Native Convert — ~28 MB)"
Name: "ocr_sinhala"; Description: "Recommended with Sinhala & English OCR (Includes Tesseract 5 + sin.traineddata + eng.traineddata — ~66 MB)"
Name: "full"; Description: "Full Offline Suite (Includes Tesseract sin+eng OCR + LibreOffice Headless Office Converter — ~256 MB)"
Name: "custom"; Description: "Custom Component Selection"; Flags: iscustom

[Components]
Name: "core"; Description: "Print Helper Core, PDFium Viewer, qpdf Engine & Bundled Noto Sans Sinhala Fonts"; Types: compact ocr_sinhala full custom; Flags: fixed
Name: "ocr"; Description: "Tesseract 5 OCR Engine (Apache-2.0)"; Types: ocr_sinhala full custom
Name: "ocr\sin"; Description: "Sinhala OCR Language Pack (sin.traineddata — 14.2 MB)"; Types: ocr_sinhala full custom
Name: "ocr\eng"; Description: "English OCR Language Pack (eng.traineddata — 22.8 MB)"; Types: ocr_sinhala full custom
Name: "libreoffice"; Description: "LibreOffice Headless Conversion Engine (MPL-2.0 — Offline .docx/.xlsx/.pptx/.odt to PDF)"; Types: full

[Tasks]
Name: "desktopicon"; Description: "{cm:CreateDesktopIcon}"; GroupDescription: "{cm:AdditionalIcons}"
Name: "explorercontext"; Description: "Add 'Open with Print Helper' to Windows Explorer right-click menu"; GroupDescription: "Windows Explorer Integration:"

[Files]
; 1. Base Application & Bundled Noto Sans Sinhala Assets
Source: "{#BuildReleaseDir}\{#MyAppExeName}"; DestDir: "{app}"; Components: core; Flags: ignoreversion
Source: "{#BuildReleaseDir}\*.dll"; DestDir: "{app}"; Components: core; Flags: ignoreversion
Source: "{#BuildReleaseDir}\data\*"; DestDir: "{app}\data"; Components: core; Flags: ignoreversion recursesubdirs createallsubdirs
Source: "{#OfflineComponentsDir}\qpdf\bin\*"; DestDir: "{app}\tools\qpdf\bin"; Components: core; Flags: ignoreversion recursesubdirs createallsubdirs skipifsourcedoesntexist

; 2. Optional Component: Tesseract 5 OCR + Sinhala (sin) & English (eng) Language Packs
Source: "{#OfflineComponentsDir}\tesseract\tesseract.exe"; DestDir: "{app}\tools\tesseract"; Components: ocr; Flags: ignoreversion skipifsourcedoesntexist
Source: "{#OfflineComponentsDir}\tesseract\*.dll"; DestDir: "{app}\tools\tesseract"; Components: ocr; Flags: ignoreversion skipifsourcedoesntexist
Source: "{#OfflineComponentsDir}\tesseract\tessdata\sin.traineddata"; DestDir: "{app}\tools\tesseract\tessdata"; Components: ocr\sin; Flags: ignoreversion skipifsourcedoesntexist
Source: "{#OfflineComponentsDir}\tesseract\tessdata\eng.traineddata"; DestDir: "{app}\tools\tesseract\tessdata"; Components: ocr\eng; Flags: ignoreversion skipifsourcedoesntexist
Source: "{#OfflineComponentsDir}\tesseract\tessdata\osd.traineddata"; DestDir: "{app}\tools\tesseract\tessdata"; Components: ocr; Flags: ignoreversion skipifsourcedoesntexist

; 3. Optional Component: LibreOffice Headless Offline Conversion Runtime
Source: "{#OfflineComponentsDir}\libreoffice\*"; DestDir: "{app}\tools\libreoffice"; Components: libreoffice; Flags: ignoreversion recursesubdirs createallsubdirs skipifsourcedoesntexist

[Icons]
Name: "{autoprograms}\{#MyAppName}"; Filename: "{app}\{#MyAppExeName}"
Name: "{autodesktop}\{#MyAppName}"; Filename: "{app}\{#MyAppExeName}"; Tasks: desktopicon

[Registry]
; Windows Explorer "Open with Print Helper" right-click verb for supported PDF, Office, Image & Text formats
Root: HKA; Subkey: "Software\Classes\SystemFileAssociations\.pdf\shell\PrintHelper"; ValueType: string; ValueName: ""; ValueData: "Open with Print Helper"; Flags: uninsdeletekey; Tasks: explorercontext
Root: HKA; Subkey: "Software\Classes\SystemFileAssociations\.pdf\shell\PrintHelper\command"; ValueType: string; ValueName: ""; ValueData: """{app}\{#MyAppExeName}"" ""%1"""; Tasks: explorercontext

Root: HKA; Subkey: "Software\Classes\SystemFileAssociations\.docx\shell\PrintHelper"; ValueType: string; ValueName: ""; ValueData: "Convert or Print with Print Helper"; Flags: uninsdeletekey; Tasks: explorercontext
Root: HKA; Subkey: "Software\Classes\SystemFileAssociations\.docx\shell\PrintHelper\command"; ValueType: string; ValueName: ""; ValueData: """{app}\{#MyAppExeName}"" ""%1"""; Tasks: explorercontext

Root: HKA; Subkey: "Software\Classes\SystemFileAssociations\.xlsx\shell\PrintHelper"; ValueType: string; ValueName: ""; ValueData: "Convert or Print with Print Helper"; Flags: uninsdeletekey; Tasks: explorercontext
Root: HKA; Subkey: "Software\Classes\SystemFileAssociations\.xlsx\shell\PrintHelper\command"; ValueType: string; ValueName: ""; ValueData: """{app}\{#MyAppExeName}"" ""%1"""; Tasks: explorercontext

Root: HKA; Subkey: "Software\Classes\SystemFileAssociations\.pptx\shell\PrintHelper"; ValueType: string; ValueName: ""; ValueData: "Convert or Print with Print Helper"; Flags: uninsdeletekey; Tasks: explorercontext
Root: HKA; Subkey: "Software\Classes\SystemFileAssociations\.pptx\shell\PrintHelper\command"; ValueType: string; ValueName: ""; ValueData: """{app}\{#MyAppExeName}"" ""%1"""; Tasks: explorercontext

Root: HKA; Subkey: "Software\Classes\SystemFileAssociations\.png\shell\PrintHelper"; ValueType: string; ValueName: ""; ValueData: "Open with Print Helper"; Flags: uninsdeletekey; Tasks: explorercontext
Root: HKA; Subkey: "Software\Classes\SystemFileAssociations\.png\shell\PrintHelper\command"; ValueType: string; ValueName: ""; ValueData: """{app}\{#MyAppExeName}"" ""%1"""; Tasks: explorercontext

Root: HKA; Subkey: "Software\Classes\SystemFileAssociations\.jpg\shell\PrintHelper"; ValueType: string; ValueName: ""; ValueData: "Open with Print Helper"; Flags: uninsdeletekey; Tasks: explorercontext
Root: HKA; Subkey: "Software\Classes\SystemFileAssociations\.jpg\shell\PrintHelper\command"; ValueType: string; ValueName: ""; ValueData: """{app}\{#MyAppExeName}"" ""%1"""; Tasks: explorercontext

Root: HKA; Subkey: "Software\Classes\SystemFileAssociations\.txt\shell\PrintHelper"; ValueType: string; ValueName: ""; ValueData: "Open with Print Helper"; Flags: uninsdeletekey; Tasks: explorercontext
Root: HKA; Subkey: "Software\Classes\SystemFileAssociations\.txt\shell\PrintHelper\command"; ValueType: string; ValueName: ""; ValueData: """{app}\{#MyAppExeName}"" ""%1"""; Tasks: explorercontext

Root: HKA; Subkey: "Software\Classes\SystemFileAssociations\.md\shell\PrintHelper"; ValueType: string; ValueName: ""; ValueData: "Open with Print Helper"; Flags: uninsdeletekey; Tasks: explorercontext
Root: HKA; Subkey: "Software\Classes\SystemFileAssociations\.md\shell\PrintHelper\command"; ValueType: string; ValueName: ""; ValueData: """{app}\{#MyAppExeName}"" ""%1"""; Tasks: explorercontext

[Run]
Filename: "{app}\{#MyAppExeName}"; Description: "{cm:LaunchProgram,{#StringChange(MyAppName, '&', '&&')}}"; Flags: nowait postinstall skipifsilent
