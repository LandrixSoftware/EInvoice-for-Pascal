{
  EInvoice-for-Pascal

  Copyright (C) 2026 Landrix Software GmbH & Co. KG

  This file is dual-licensed under:
  - GNU GPL version 3 or later; or
  - the Landrix Software Commercial License.

  See LICENSE and COMMERCIAL-LICENSE.md.

  SPDX-License-Identifier: GPL-3.0-or-later OR LicenseRef-Landrix-Commercial
}

{ Files with UTF-16 names on every compiler. TFileStream takes the native
  string, which is AnsiString on Delphi 6-2007 and on Free Pascal: a name
  outside the ANSI code page would be lost there (on Free Pascal without a
  wide string manager). These functions use the
  Unicode way of each compiler instead: Delphi 2009+ TFileStream (its
  string is UTF-16), Delphi 6-2007 CreateFileW (Windows), Free Pascal on
  Windows the UnicodeString overloads of SysUtils, Free Pascal elsewhere the
  name as UTF-8 (the file system encoding of Linux and macOS, also without a
  wide string manager).

  DE: Dateien mit UTF-16-Namen unter jedem Compiler. TFileStream nimmt den
  nativen string, unter Delphi 6 bis 2007 und Free Pascal ein AnsiString:
  ein Name ausserhalb der ANSI-Codepage ginge dort verloren (unter Free
  Pascal ohne Wide-String-Manager). Diese
  Funktionen nehmen stattdessen den Unicode-Weg des jeweiligen Compilers:
  Delphi 2009+ TFileStream (dessen string ist UTF-16), Delphi 6 bis 2007
  CreateFileW (Windows), Free Pascal unter Windows die
  UnicodeString-Ueberladungen von SysUtils, Free Pascal sonst den Namen als
  UTF-8 (die Dateisystem-Kodierung von Linux und macOS, auch ohne
  Wide-String-Manager). }

{ API: internal. May change in any release; use the facade LandrixEInvoice
  or the stable units instead.
  DE: API: intern. Kann sich in jeder Version aendern; stattdessen die
  Fassade LandrixEInvoice oder die stabilen Units verwenden. }

unit LandrixEInvoiceFiles;

{$I LandrixEInvoice.inc}

interface

uses
  Classes,
  LandrixEInvoiceTypes;

type
  { How LandrixEInvoiceOpenFile opens a file: efm_Read reads an existing file
    (others may read it at the same time), efm_Create creates the file or
    empties an existing one and writes it.
    DE: Wie LandrixEInvoiceOpenFile eine Datei oeffnet: efm_Read liest eine
    vorhandene Datei (andere duerfen gleichzeitig lesen), efm_Create legt die
    Datei an oder leert eine vorhandene und schreibt sie. }
  TLandrixEInvoiceFileMode = (efm_Read, efm_Create);

{ Opens AFileName as a stream; the caller frees it, which closes the file.
  Raises EFOpenError (efm_Read) or EFCreateError (efm_Create) from Classes
  when the file cannot be opened.
  DE: Oeffnet AFileName als Stream; der Aufrufer gibt ihn frei, das schliesst
  die Datei. Loest EFOpenError (efm_Read) oder EFCreateError (efm_Create)
  aus Classes aus, wenn die Datei nicht geoeffnet werden kann. }
function LandrixEInvoiceOpenFile(const AFileName: TLandrixEInvoiceString;
  AMode: TLandrixEInvoiceFileMode): TStream;

{ True if AFileName is an existing file (not a directory).
  DE: True, wenn AFileName eine vorhandene Datei ist (kein Verzeichnis). }
function LandrixEInvoiceFileExists(const AFileName: TLandrixEInvoiceString): Boolean;

{ True if ADirectory is an existing directory.
  DE: True, wenn ADirectory ein vorhandenes Verzeichnis ist. }
function LandrixEInvoiceDirectoryExists(const ADirectory: TLandrixEInvoiceString): Boolean;

implementation

uses
  SysUtils;

{$IFDEF LANDRIXEINVOICE_WIN32W}
{ Delphi 6-2007: the W functions of kernel32, declared here because the
  library uses no Windows unit. }
const
  GENERIC_READ = LongWord($80000000);
  GENERIC_WRITE = LongWord($40000000);
  FILE_SHARE_READ = 1;
  OPEN_EXISTING = 3;
  CREATE_ALWAYS = 2;
  FILE_ATTRIBUTE_NORMAL = $80;
  FILE_ATTRIBUTE_DIRECTORY = $10;
  INVALID_FILE_ATTRIBUTES = LongWord($FFFFFFFF);

function CreateFileW(lpFileName: PWideChar; dwDesiredAccess, dwShareMode: LongWord;
  lpSecurityAttributes: Pointer; dwCreationDisposition, dwFlagsAndAttributes: LongWord;
  hTemplateFile: LongWord): LongWord; stdcall; external 'kernel32.dll' name 'CreateFileW';
function GetFileAttributesW(lpFileName: PWideChar): LongWord; stdcall;
  external 'kernel32.dll' name 'GetFileAttributesW';
{$ENDIF}

{$IFNDEF LANDRIXEINVOICE_UNICODE}
type
  { A handle stream that closes its handle (always a valid one). }
  TOwnedHandleStream = class(THandleStream)
  public
    destructor Destroy; override;
  end;

destructor TOwnedHandleStream.Destroy;
begin
  FileClose(Handle);
  inherited;
end;

{$IFDEF FPC}
  {$IFNDEF MSWINDOWS}
{ The name in the file system encoding of Unix-like systems. }
function NativeName(const AFileName: TLandrixEInvoiceString): UTF8String;
begin
  Result := LandrixEInvoiceStringToUtf8(AFileName);
end;
  {$ENDIF}
{$ENDIF}

function OpenHandle(const AFileName: TLandrixEInvoiceString; AMode: TLandrixEInvoiceFileMode): THandle;
begin
{$IFDEF LANDRIXEINVOICE_WIN32W}
  if AMode = efm_Read then
    Result := CreateFileW(PWideChar(AFileName), GENERIC_READ, FILE_SHARE_READ, nil, OPEN_EXISTING,
      FILE_ATTRIBUTE_NORMAL, 0)
  else
    Result := CreateFileW(PWideChar(AFileName), GENERIC_READ or GENERIC_WRITE, 0, nil, CREATE_ALWAYS,
      FILE_ATTRIBUTE_NORMAL, 0);
{$ELSE}
  {$IFDEF FPC}
    {$IFDEF MSWINDOWS}
  if AMode = efm_Read then
    Result := FileOpen(UnicodeString(AFileName), fmOpenRead or fmShareDenyWrite)
  else
    Result := FileCreate(UnicodeString(AFileName));
    {$ELSE}
  if AMode = efm_Read then
    Result := FileOpen(NativeName(AFileName), fmOpenRead or fmShareDenyWrite)
  else
    Result := FileCreate(NativeName(AFileName));
    {$ENDIF}
  {$ENDIF}
{$ENDIF}
end;
{$ENDIF}

function LandrixEInvoiceOpenFile(const AFileName: TLandrixEInvoiceString;
  AMode: TLandrixEInvoiceFileMode): TStream;
{$IFDEF LANDRIXEINVOICE_UNICODE}
begin
  if AMode = efm_Read then
    Result := TFileStream.Create(AFileName, fmOpenRead or fmShareDenyWrite)
  else
    Result := TFileStream.Create(AFileName, fmCreate);
end;
{$ELSE}
var
  H: THandle;
begin
  H := OpenHandle(AFileName, AMode);
  if H = THandle(-1) then
  begin
    if AMode = efm_Read then
      raise EFOpenError.CreateFmt('Cannot open file "%s"', [string(AFileName)])
    else
      raise EFCreateError.CreateFmt('Cannot create file "%s"', [string(AFileName)]);
  end;
  Result := TOwnedHandleStream.Create(H);
end;
{$ENDIF}

function LandrixEInvoiceFileExists(const AFileName: TLandrixEInvoiceString): Boolean;
{$IFDEF LANDRIXEINVOICE_WIN32W}
var
  Attributes: LongWord;
{$ENDIF}
begin
{$IFDEF LANDRIXEINVOICE_WIN32W}
  Attributes := GetFileAttributesW(PWideChar(AFileName));
  Result := (Attributes <> INVALID_FILE_ATTRIBUTES) and (Attributes and FILE_ATTRIBUTE_DIRECTORY = 0);
{$ELSE}
  {$IFDEF FPC}
    {$IFDEF MSWINDOWS}
  Result := FileExists(UnicodeString(AFileName));
    {$ELSE}
  Result := FileExists(NativeName(AFileName));
    {$ENDIF}
  {$ELSE}
  Result := FileExists(AFileName);
  {$ENDIF}
{$ENDIF}
end;

function LandrixEInvoiceDirectoryExists(const ADirectory: TLandrixEInvoiceString): Boolean;
{$IFDEF LANDRIXEINVOICE_WIN32W}
var
  Attributes: LongWord;
{$ENDIF}
begin
{$IFDEF LANDRIXEINVOICE_WIN32W}
  Attributes := GetFileAttributesW(PWideChar(ADirectory));
  Result := (Attributes <> INVALID_FILE_ATTRIBUTES) and (Attributes and FILE_ATTRIBUTE_DIRECTORY <> 0);
{$ELSE}
  {$IFDEF FPC}
    {$IFDEF MSWINDOWS}
  Result := DirectoryExists(UnicodeString(ADirectory));
    {$ELSE}
  Result := DirectoryExists(NativeName(ADirectory));
    {$ENDIF}
  {$ELSE}
  Result := DirectoryExists(ADirectory);
  {$ENDIF}
{$ENDIF}
end;

end.
