{
  EInvoice-for-Pascal

  Copyright (C) 2026 Landrix Software GmbH & Co. KG

  This file is dual-licensed under:
  - GNU GPL version 3 or later; or
  - the Landrix Software Commercial License.

  See LICENSE and COMMERCIAL-LICENSE.md.

  SPDX-License-Identifier: GPL-3.0-or-later OR LicenseRef-Landrix-Commercial
}

{ Example: convert an XRechnung from CII to UBL. Reading fills the semantic
  model; writing maps it to the other syntax. Content that only one syntax
  can hold is reported.

  Usage: ConvertCIIToUBL [input] [output]
         (defaults: xrechnung-cii.xml, converted-ubl.xml)

  Exit code 0 when the UBL file was written. }

program ConvertCIIToUBL;

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
  LandrixEInvoiceDiagnostics,
  LandrixEInvoiceSpecs,
  LandrixEInvoice;

var
  Input, Output: TLandrixEInvoiceString;
  Doc: TLandrixEInvoiceDocument;
  Target: TLandrixEInvoiceTarget;
  D: TLandrixEInvoiceDiagnostics;
begin
  Input := 'xrechnung-cii.xml';
  Output := 'converted-ubl.xml';
  if ParamCount > 0 then
    Input := TLandrixEInvoiceString(ParamStr(1));
  if ParamCount > 1 then
    Output := TLandrixEInvoiceString(ParamStr(2));
  Doc := TLandrixEInvoice.LoadFromFile(Input);
  D := TLandrixEInvoiceDiagnostics.Create;
  try
    if (Doc.Info.Syntax <> esy_CII) or not Doc.Info.SpecFound then
    begin
      WriteLn(string(Input), ' is no CII invoice of a known specification');
      ExitCode := 1;
      Exit;
    end;
    { same standard and version, other syntax; Factur-X / ZUGFeRD exist in
      CII only and raise ELandrixEInvoiceTargetError here }
    Target := Doc.Info.Spec.Target;
    Target.Syntax := esy_UBL;
    try
      TLandrixEInvoice.SaveToFile(Doc.Invoice, Output, Target, [], D);
      WriteLn('Written: ', string(Output), ' (', string(LandrixEInvoiceTargetToStr(Target)), ')');
    except
      on E: ELandrixEInvoiceError do
      begin
        WriteLn('Not converted: ', E.Message);
        ExitCode := 1;
      end;
    end;
    { what reading found and what the UBL side could not hold }
    if Doc.Diagnostics.Count + D.Count > 0 then
    begin
      WriteLn(string(Doc.Diagnostics.ToText));
      WriteLn(string(D.ToText));
    end;
  finally
    Doc.Free;
    D.Free;
  end;
end.
