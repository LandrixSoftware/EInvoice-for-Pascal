{
  EInvoice-for-Pascal

  Copyright (C) 2026 Landrix Software GmbH & Co. KG

  This file is dual-licensed under:
  - GNU GPL version 3 or later; or
  - the Landrix Software Commercial License.

  See LICENSE and COMMERCIAL-LICENSE.md.

  SPDX-License-Identifier: GPL-3.0-or-later OR LicenseRef-Landrix-Commercial
}

{ Tests for LandrixEInvoiceFiles: file names outside the ANSI code page. }

unit LandrixEInvoiceTestFiles;

{$I LandrixEInvoice.inc}

interface

procedure Register;

implementation

uses
  SysUtils,
  Classes,
{$IFDEF FPC}
  {$IFNDEF MSWINDOWS}
  LandrixXmlBase,
  {$ENDIF}
{$ENDIF}
  LandrixEInvoiceTypes,
  LandrixEInvoiceFiles,
  LandrixEInvoiceTestFramework;

function FilesDir: TLandrixEInvoiceString;
var
  Dir: string;
begin
  Dir := ExtractFilePath(ParamStr(0)) + 'files' + PathDelim;
  Check(ForceDirectories(Dir), 'files folder');
  Result := TLandrixEInvoiceString(Dir);
end;

procedure WriteText(const AFileName: TLandrixEInvoiceString; const AText: AnsiString);
var
  S: TStream;
begin
  S := LandrixEInvoiceOpenFile(AFileName, efm_Create);
  try
    if AText <> '' then
      S.WriteBuffer(PAnsiChar(AText)^, Length(AText));
  finally
    S.Free;
  end;
end;

function ReadText(const AFileName: TLandrixEInvoiceString): AnsiString;
var
  S: TStream;
begin
  Result := '';
  S := LandrixEInvoiceOpenFile(AFileName, efm_Read);
  try
    SetLength(Result, Integer(S.Size));
    if Result <> '' then
      S.ReadBuffer(PAnsiChar(Result)^, Length(Result));
  finally
    S.Free;
  end;
end;

{$IFDEF FPC}
  {$IFNDEF MSWINDOWS}
{ The directory lists the name as UTF-8 bytes. }
procedure CheckNameOnDisk(const AName: TLandrixEInvoiceString);
var
  SR: TSearchRec;
  Expected: TLandrixXmlUtf8;
  Found: Boolean;
begin
  Expected := LandrixEInvoiceStringToUtf8(AName);
  Found := False;
  if FindFirst(ExtractFilePath(ParamStr(0)) + 'files' + PathDelim + '*.txt', faAnyFile, SR) = 0 then
  begin
    repeat
      if (Length(SR.Name) = Length(Expected)) and CompareMem(Pointer(SR.Name), Pointer(Expected), Length(Expected)) then
        Found := True;
    until FindNext(SR) <> 0;
    FindClose(SR);
  end;
  Check(Found, 'UTF-8 name in the directory listing');
end;
  {$ENDIF}
{$ENDIF}

{ A name with u-umlaut and a CJK character survives create, exists, read and
  overwrite; the lossy ANSI form of the name is not created. }
procedure TestUnicodeName;
var
  Dir, Name: TLandrixEInvoiceString;
begin
  Dir := FilesDir;
  Name := Dir + Wide([Ord('R'), $00FC, $4E2D, Ord('.'), Ord('t'), Ord('x'), Ord('t')]);
  WriteText(Name, 'abc');
  Check(LandrixEInvoiceFileExists(Name), 'exists');
  CheckEqualsBytes('abc', ReadText(Name), 'read back');
  WriteText(Name, 'x');
  CheckEqualsBytes('x', ReadText(Name), 'overwritten');
  Check(not LandrixEInvoiceFileExists(Dir + 'R??.txt'), 'no lossy name R??.txt');
  Check(not LandrixEInvoiceFileExists(Dir + 'R?.txt'), 'no lossy name R?.txt');
{$IFDEF FPC}
  {$IFNDEF MSWINDOWS}
  CheckNameOnDisk(Copy(Name, Length(Dir) + 1, Length(Name)));
  {$ENDIF}
{$ENDIF}
end;

{ A directory is no file; a missing file raises EFOpenError, a file in a
  missing folder EFCreateError. }
procedure TestErrors;
var
  Dir: TLandrixEInvoiceString;
begin
  Dir := FilesDir;
  Check(not LandrixEInvoiceFileExists(Copy(Dir, 1, Length(Dir) - 1)), 'directory is no file');
  Check(not LandrixEInvoiceFileExists(Dir + 'missing.txt'), 'missing file');
  try
    LandrixEInvoiceOpenFile(Dir + 'missing.txt', efm_Read).Free;
    FailNotRaised('EFOpenError');
  except
    on EFOpenError do ;
  end;
  try
    LandrixEInvoiceOpenFile(Dir + 'missing' + TLandrixEInvoiceString(PathDelim) + 'x.txt', efm_Create).Free;
    FailNotRaised('EFCreateError');
  except
    on EFCreateError do ;
  end;
end;

procedure Register;
begin
  RegisterTest('Files.UnicodeName', TestUnicodeName);
  RegisterTest('Files.Errors', TestErrors);
end;

end.
