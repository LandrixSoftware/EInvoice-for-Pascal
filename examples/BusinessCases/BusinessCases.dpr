{
  EInvoice-for-Pascal

  Copyright (C) 2026 Landrix Software GmbH & Co. KG

  This file is dual-licensed under:
  - GNU GPL version 3 or later; or
  - the Landrix Software Commercial License.

  See LICENSE and COMMERCIAL-LICENSE.md.

  SPDX-License-Identifier: GPL-3.0-or-later OR LicenseRef-Landrix-Commercial
}

{ Example: the business cases of XRechnung-for-Delphi (overall example,
  credit note, reverse charge, small business regulation, intra-community
  supply, direct debit, payment card, corrected invoice, title line groups
  and more), written for every target they fit: XRechnung UBL and CII,
  ZUGFeRD EN 16931 and EXTENDED, Peppol BIS. The cases are in
  LandrixEInvoiceExampleScenarios.pas; each Scenario... procedure fills one
  invoice.

  Usage: BusinessCases [output-folder] [attachment-folder]
         (defaults: business-cases, the folder attachments next to the
         program or in the current folder)

  Exit code 0 when all 111 files were written. }

program BusinessCases;

{$IFDEF FPC}
  {$MODE DELPHI}
{$ENDIF}
{$IFDEF MSWINDOWS}
  {$APPTYPE CONSOLE}
{$ENDIF}

uses
  {$IFDEF UNIX}
  cwstring,
  {$ENDIF}
  SysUtils,
  LandrixEInvoiceTypes,
  LandrixEInvoiceInvoice,
  LandrixEInvoice,
  LandrixEInvoiceExampleScenarios;

type
  PRun = ^TRun;
  TRun = record
    Folder: TLandrixEInvoiceString;
    Written: Integer;
    Failed: Integer;
  end;

{ Called once per output file. Writing checks the business rules of the
  target first. }
procedure SaveCase(AInvoice: TLandrixInvoice; const ATarget: TLandrixEInvoiceTarget;
  const AFileName: string; AData: Pointer);
var
  Run: PRun;
begin
  Run := PRun(AData);
  try
    TLandrixEInvoice.SaveToFile(AInvoice, Run^.Folder + TLandrixEInvoiceString(AFileName), ATarget);
    Inc(Run^.Written);
  except
    on E: ELandrixEInvoiceError do
    begin
      WriteLn(AFileName, ': ', E.Message);
      Inc(Run^.Failed);
    end;
  end;
end;

function AttachmentFolder: string;
begin
  if ParamCount > 1 then
    Result := IncludeTrailingPathDelimiter(ParamStr(2))
  else
  begin
    Result := ExtractFilePath(ParamStr(0)) + 'attachments' + PathDelim;
    if not DirectoryExists(Result) then
      Result := 'attachments' + PathDelim;
  end;
end;

var
  Run: TRun;
  Folder: string;
begin
  Folder := 'business-cases';
  if ParamCount > 0 then
    Folder := ParamStr(1);
  { Delphi 2009+ raises for a relative name without folder }
  Folder := ExpandFileName(Folder);
  if not ForceDirectories(Folder) then
  begin
    WriteLn('Cannot create ', Folder);
    ExitCode := 1;
    Exit;
  end;
  Run.Folder := TLandrixEInvoiceString(IncludeTrailingPathDelimiter(Folder));
  Run.Written := 0;
  Run.Failed := 0;
  RunAllScenarios(SaveCase, @Run, AttachmentFolder);
  WriteLn(Run.Written, ' files written to ', Folder, ', ', Run.Failed, ' refused');
  if (Run.Failed > 0) or (Run.Written <> 111) then
    ExitCode := 1;
end.
