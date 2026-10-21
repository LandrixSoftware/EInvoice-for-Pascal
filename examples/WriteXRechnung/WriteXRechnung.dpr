{
  EInvoice-for-Pascal

  Copyright (C) 2026 Landrix Software GmbH & Co. KG

  This file is dual-licensed under:
  - GNU GPL version 3 or later; or
  - the Landrix Software Commercial License.

  See LICENSE and COMMERCIAL-LICENSE.md.

  SPDX-License-Identifier: GPL-3.0-or-later OR LicenseRef-Landrix-Commercial
}

{ Example: fill an invoice in the semantic model and write it as XRechnung
  3.0 in both syntaxes (UBL and CII).

  Usage: WriteXRechnung [output-folder]

  Writes xrechnung-ubl.xml and xrechnung-cii.xml. Exit code 0 when both
  files were written. }

program WriteXRechnung;

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
  LandrixEInvoiceCodes,
  LandrixEInvoiceDiagnostics,
  LandrixEInvoiceSpecs,
  LandrixEInvoiceInvoice,
  LandrixEInvoice;

{ The invoice: seller, buyer, two lines with 19 % VAT, SEPA credit transfer.
  Line amounts, VAT breakdown and totals are calculated afterwards. }
procedure FillInvoice(Invoice: TLandrixInvoice);
var
  Party: TLandrixInvoiceAccountingParty;
  Line: TLandrixInvoiceLine;
  Payment: TLandrixInvoicePaymentType;
begin
  Invoice.InvoiceNumber := 'RE-2026-0001';
  Invoice.InvoiceIssueDate := EncodeDate(2026, 10, 21);
  Invoice.InvoiceDueDate := EncodeDate(2026, 11, 20);
  Invoice.InvoiceTypeCode := itc_CommercialInvoice;
  Invoice.InvoiceCurrencyCode := 'EUR';
  { BT-10, mandatory in XRechnung (the Leitweg-ID for public buyers) }
  Invoice.BuyerReference := '04011000-12345-67';
  Invoice.PaymentTermNetNote := 'Payable within 30 days without deduction.';

  Party := Invoice.AccountingSupplierParty;
  Party.RegistrationName := 'Example Seller GmbH';
  Party.Address.StreetName := 'Market Street 1';
  Party.Address.City := 'Berlin';
  Party.Address.PostalZone := '10115';
  Party.Address.CountryCode := 'DE';
  Party.VATCompanyID := 'DE123456789';
  Party.ContactName := 'Accounts receivable';
  Party.ContactTelephone := '+49 30 1234567';
  Party.ContactElectronicMail := 'billing@seller.example';
  Party.ElectronicAddressSellerBuyer := 'billing@seller.example';
  Party.ElectronicAddressSellerBuyerSchemeID := 'EM';

  Party := Invoice.AccountingCustomerParty;
  Party.RegistrationName := 'Example Buyer AG';
  Party.Address.StreetName := 'Harbour Road 5';
  Party.Address.City := 'Hamburg';
  Party.Address.PostalZone := '20095';
  Party.Address.CountryCode := 'DE';
  Party.ElectronicAddressSellerBuyer := 'invoices@buyer.example';
  Party.ElectronicAddressSellerBuyerSchemeID := 'EM';

  Line := Invoice.InvoiceLines.AddInvoiceLine;
  Line.ID := '1';
  Line.Name := 'Consulting';
  Line.Quantity := 8;
  Line.UnitCode := iuc_hour;
  Line.NetPriceAmount := 120;
  Line.TaxCategory := idtfcc_S_StandardRate;
  Line.TaxPercent := 19;

  Line := Invoice.InvoiceLines.AddInvoiceLine;
  Line.ID := '2';
  Line.Name := 'Travel expenses';
  Line.Quantity := 1;
  Line.UnitCode := iuc_piece;
  Line.NetPriceAmount := 40;
  Line.TaxCategory := idtfcc_S_StandardRate;
  Line.TaxPercent := 19;

  Payment := Invoice.PaymentTypes.AddPaymentType;
  Payment.PaymentMeansCode := ipmc_SEPACreditTransfer;
  Payment.FinancialAccount := 'DE02120300000000202051';
end;

{ Writes the invoice for one target. Writing checks the business rules
  first and refuses an invoice with errors: nothing is written then. }
function Save(Invoice: TLandrixInvoice; const ATarget: TLandrixEInvoiceTarget;
  const AFileName: TLandrixEInvoiceString): Boolean;
var
  D: TLandrixEInvoiceDiagnostics;
begin
  D := TLandrixEInvoiceDiagnostics.Create;
  try
    try
      TLandrixEInvoice.SaveToFile(Invoice, AFileName, ATarget, [], D);
      WriteLn('Written: ', string(AFileName), ' (', string(LandrixEInvoiceTargetToStr(ATarget)), ')');
      { warnings, e.g. content the target cannot hold }
      if D.Count > 0 then
        WriteLn(string(D.ToText));
      Result := True;
    except
      on E: ELandrixEInvoiceWriteError do
      begin
        WriteLn('Refused: ', E.Message);
        WriteLn(string(E.Diagnostics.ToText));
        Result := False;
      end;
    end;
  finally
    D.Free;
  end;
end;

var
  Invoice: TLandrixInvoice;
  D: TLandrixEInvoiceDiagnostics;
  Folder: TLandrixEInvoiceString;
  Ok: Boolean;
begin
  Folder := '';
  if ParamCount > 0 then
    Folder := TLandrixEInvoiceString(IncludeTrailingPathDelimiter(ParamStr(1)));
  Invoice := TLandrixInvoice.Create;
  try
    FillInvoice(Invoice);
    { BT-131 from quantity and price, then the VAT breakdown (BG-23) and the
      totals (BG-22): 960 + 40 = 1000 net, 190 VAT, 1190 payable }
    D := TLandrixEInvoiceDiagnostics.Create;
    try
      if (TLandrixEInvoice.CalculateLineAmounts(Invoice, D) > 0) or
         (TLandrixEInvoice.CalculateTotals(Invoice, D) > 0) then
      begin
        WriteLn('Not calculated: ', string(D.ToText));
        ExitCode := 1;
        Exit;
      end;
    finally
      D.Free;
    end;
    Ok := Save(Invoice, TLandrixEInvoiceTargets.XRechnung('3.0', esy_UBL), Folder + 'xrechnung-ubl.xml');
    Ok := Save(Invoice, TLandrixEInvoiceTargets.XRechnung('3.0', esy_CII), Folder + 'xrechnung-cii.xml') and Ok;
  finally
    Invoice.Free;
  end;
  if not Ok then
    ExitCode := 1;
end.
