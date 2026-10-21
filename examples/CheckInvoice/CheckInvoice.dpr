{
  EInvoice-for-Pascal

  Copyright (C) 2026 Landrix Software GmbH & Co. KG

  This file is dual-licensed under:
  - GNU GPL version 3 or later; or
  - the Landrix Software Commercial License.

  See LICENSE and COMMERCIAL-LICENSE.md.

  SPDX-License-Identifier: GPL-3.0-or-later OR LicenseRef-Landrix-Commercial
}

{ Example: check an invoice against the business rules of its
  specification, then break it and see the check and the writer refuse it.

  Usage: CheckInvoice [file]   (default: xrechnung-ubl.xml)

  Exit code 0 when the file was read and the check behaved as shown; step 2
  expects an error for XRechnung only (BR-DE-16). }

program CheckInvoice;

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
  LandrixXmlBase,
  LandrixEInvoiceTypes,
  LandrixEInvoiceDiagnostics,
  LandrixEInvoiceSpecs,
  LandrixEInvoiceInvoice,
  LandrixEInvoice;

{ Runs the checks of SaveTo* without writing and prints the result. }
function RunCheck(Invoice: TLandrixInvoice; const ATarget: TLandrixEInvoiceTarget;
  AOptions: TLandrixEInvoiceOptions): Integer;
var
  D: TLandrixEInvoiceDiagnostics;
  I: Integer;
begin
  D := TLandrixEInvoiceDiagnostics.Create;
  try
    Result := TLandrixEInvoice.Check(Invoice, ATarget, AOptions, D);
    WriteLn(string(LandrixEInvoiceTargetToStr(ATarget)), ': ', Result, ' error(s)');
    for I := 0 to Integer(D.Count) - 1 do
      if D[I].Severity = eds_Error then
        WriteLn('  ', string(D[I].RuleID), ' ', string(D[I].Message));
  finally
    D.Free;
  end;
end;

var
  FileName: TLandrixEInvoiceString;
  Doc: TLandrixEInvoiceDocument;
  Target: TLandrixEInvoiceTarget;
  Xml: TLandrixXmlUtf8;
  Ok: Boolean;
begin
  FileName := 'xrechnung-ubl.xml';
  if ParamCount > 0 then
    FileName := TLandrixEInvoiceString(ParamStr(1));
  Doc := TLandrixEInvoice.LoadFromFile(FileName);
  try
    if not Doc.Info.SpecFound then
    begin
      WriteLn('Unknown specification ', string(Doc.Info.CustomizationID), ': nothing to check against');
      ExitCode := 1;
      Exit;
    end;
    Target := Doc.Info.Spec.Target;

    { 1. the invoice as read; eio_Strict also counts content the target
      cannot hold as an error }
    Ok := RunCheck(Doc.Invoice, Target, []) = 0;
    RunCheck(Doc.Invoice, Target, [eio_Strict]);

    { 2. without the seller's VAT identifier a standard-rated XRechnung
      violates BR-DE-16 }
    Doc.Invoice.AccountingSupplierParty.VATCompanyID := '';
    if RunCheck(Doc.Invoice, Target, []) = 0 then
      Ok := Ok and (Target.Standard <> est_XRechnung);

    { 3. writing refuses an invoice with errors and writes nothing;
      eio_WriteDespiteErrors is the escape hatch }
    try
      TLandrixEInvoice.SaveToUtf8(Doc.Invoice, Target);
      WriteLn('Written: no error for this specification');
    except
      on E: ELandrixEInvoiceWriteError do
        WriteLn('Refused: ', E.Message);
    end;
    Xml := TLandrixEInvoice.SaveToUtf8(Doc.Invoice, Target, [eio_WriteDespiteErrors]);
    WriteLn('Written despite errors: ', Length(Xml), ' bytes');
  finally
    Doc.Free;
  end;
  if not Ok then
    ExitCode := 1;
end.
