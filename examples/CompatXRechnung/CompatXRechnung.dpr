{
  EInvoice-for-Pascal

  Copyright (C) 2026 Landrix Software GmbH & Co. KG

  This file is dual-licensed under:
  - GNU GPL version 3 or later; or
  - the Landrix Software Commercial License.

  See LICENSE and COMMERCIAL-LICENSE.md.

  SPDX-License-Identifier: GPL-3.0-or-later OR LicenseRef-Landrix-Commercial
}

{ Example: code written for XRechnung-for-Delphi, running on this library.
  Only the uses clause changes:
    intf.Invoice    -> LandrixEInvoiceCompatXRechnung
    intf.XRechnung  -> LandrixEInvoiceCompatXRechnungAdapter
  (Delphi 6 version: intfInvoice, intfXRechnung).

  Usage: CompatXRechnung [file]   (default: xrechnung-ubl.xml)

  Reads the file, detects its version, and writes it again as XRechnung CII
  (compat-cii.xml next to the input). Exit code 0 on success. }

program CompatXRechnung;

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
  LandrixEInvoiceCompatXRechnung,
  LandrixEInvoiceCompatXRechnungAdapter;

var
  Invoice: TInvoice;
  { string in XRechnung-for-Delphi; UnicodeString on Free Pascal }
  FileName, Error: TXRechnungString;
begin
  FileName := 'xrechnung-ubl.xml';
  if ParamCount > 0 then
    FileName := TXRechnungString(ParamStr(1));
  { as before, SaveToFile writes nothing for a file name without folder }
  FileName := TXRechnungString(ExpandFileName(string(FileName)));

  if TXRechnungValidationHelper.GetXRechnungVersion(FileName) <> XRechnungVersion_30x_UBL then
    WriteLn('Not an XRechnung 3.0 UBL file, reading it anyway');

  Invoice := TInvoice.Create;
  try
    if not TXRechnungInvoiceAdapter.LoadFromFile(Invoice, FileName, Error) then
    begin
      WriteLn('Not readable: ', string(Error));
      ExitCode := 1;
      Exit;
    end;
    WriteLn('Read invoice ', string(Invoice.InvoiceNumber));

    { the old pre-write check; the codes are unit constants (ccOK ...) }
    if not TXRechnungInvoiceAdapter.ConsistencyCheck(Invoice, XRechnungVersion_30x_UNCEFACT) then
      WriteLn('ConsistencyCheck failed');

    FileName := TXRechnungString(ExtractFilePath(string(FileName))) + 'compat-cii.xml';
    TXRechnungInvoiceAdapter.SaveToFile(Invoice, XRechnungVersion_30x_UNCEFACT, FileName);
    if FileExists(string(FileName)) then
      WriteLn('Written: ', string(FileName))
    else
    begin
      WriteLn('Not written: ', string(FileName));
      ExitCode := 1;
    end;
  finally
    Invoice.Free;
  end;
end.
