{
  EInvoice-for-Pascal

  Copyright (C) 2026 Landrix Software GmbH & Co. KG

  This file is dual-licensed under:
  - GNU GPL version 3 or later; or
  - the Landrix Software Commercial License.

  See LICENSE and COMMERCIAL-LICENSE.md.

  SPDX-License-Identifier: GPL-3.0-or-later OR LicenseRef-Landrix-Commercial
}

{ Runs TLandrixEInvoicePdfChecker on every PDF of a folder (or the files
  given), reads the extracted invoice through the facade for the second
  pass (CheckInvoiceFacts) and prints, per file, a line
  "file<TAB>status<TAB>kind<TAB>name<TAB>profile" and its findings indented
  below. Used by the PDF oracle. }

program PdfCheckProbe;

{$I LandrixEInvoice.inc}

{$IFDEF MSWINDOWS}
  {$APPTYPE CONSOLE}
{$ENDIF}

uses
  SysUtils,
  LandrixEInvoiceTypes,
  LandrixEInvoiceDiagnostics,
  LandrixEInvoice,
  LandrixEInvoicePdfCheck;

const
  StatusNames: array[TLandrixEInvoicePdfLevelStatus] of string = ('not-run', 'passed', 'failed', 'incomplete');
  KindNames: array[TLandrixEInvoicePdfHybridKind] of string = ('none', 'factur-x', 'xrechnung', 'zugferd-2.0',
    'zugferd-1.0');
  SeverityNames: array[TLandrixEInvoiceDiagnosticSeverity] of string = ('info', 'warning', 'error');
  ProfileNames: array[TLandrixEInvoiceProfile] of string = ('none', 'minimum', 'basic-wl', 'basic', 'en16931',
    'extended', 'xrechnung');

{ The second pass with the facts of the extracted invoice; an invoice the
  facade cannot read gets no facts. }
procedure CheckFacts(AChecker: TLandrixEInvoicePdfChecker; AResult: TLandrixEInvoicePdfCheckResult);
var
  Doc: TLandrixEInvoiceDocument;
  Facts: TLandrixEInvoicePdfInvoiceFacts;
begin
  if AResult.Invoice.Size = 0 then
    Exit;
  AResult.Invoice.Position := 0;
  try
    Doc := TLandrixEInvoice.LoadFromStream(AResult.Invoice, [eio_NoPdf, eio_NoRuleCheck, eio_InvoiceOnly]);
  except
    Exit;
  end;
  try
    Facts.Target := Doc.Info.Spec.Target;
    if not Doc.Info.SpecFound then
      Facts.Target.Syntax := Doc.Info.Syntax;
    Facts.SellerCountryCode := Doc.Invoice.AccountingSupplierParty.Address.CountryCode;
    Facts.BuyerCountryCode := Doc.Invoice.AccountingCustomerParty.Address.CountryCode;
    AChecker.CheckInvoiceFacts(AResult, Facts);
  finally
    Doc.Free;
  end;
end;

procedure CheckOne(AChecker: TLandrixEInvoicePdfChecker; AResult: TLandrixEInvoicePdfCheckResult;
  const AFileName: string);
var
  I: Integer;
  D: TLandrixEInvoiceDiagnostic;
begin
  AChecker.CheckFile(AFileName, AResult);
  CheckFacts(AChecker, AResult);
  WriteLn(ExtractFileName(AFileName), #9, StatusNames[AResult.Status[epl_Embedding]], #9,
    KindNames[AResult.HybridKind], #9, UTF8Encode(AResult.InvoiceFileName), #9, ProfileNames[AResult.Profile]);
  for I := 0 to Integer(AResult.Diagnostics.Count) - 1 do
  begin
    D := AResult.Diagnostics[I];
    WriteLn('  ', SeverityNames[D.Severity], #9, UTF8Encode(D.RuleID), #9, UTF8Encode(D.Path), #9,
      UTF8Encode(D.Message));
  end;
end;

var
  Checker: TLandrixEInvoicePdfChecker;
  Result: TLandrixEInvoicePdfCheckResult;
  SR: TSearchRec;
  Dir: string;
  I: Integer;
begin
  if ParamCount = 0 then
  begin
    WriteLn('usage: PdfCheckProbe <folder or PDF files>');
    ExitCode := 2;
    Exit;
  end;
  Checker := TLandrixEInvoicePdfChecker.Create;
  Result := TLandrixEInvoicePdfCheckResult.Create;
  try
    for I := 1 to ParamCount do
      if DirectoryExists(ParamStr(I)) then
      begin
        Dir := IncludeTrailingPathDelimiter(ParamStr(I));
        if FindFirst(Dir + '*.pdf', faAnyFile, SR) = 0 then
          try
            repeat
              CheckOne(Checker, Result, Dir + SR.Name);
            until FindNext(SR) <> 0;
          finally
            FindClose(SR);
          end;
      end
      else
        CheckOne(Checker, Result, ParamStr(I));
  finally
    Result.Free;
    Checker.Free;
  end;
end.
