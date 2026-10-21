{
  EInvoice-for-Pascal

  Copyright (C) 2026 Landrix Software GmbH & Co. KG

  This file is dual-licensed under:
  - GNU GPL version 3 or later; or
  - the Landrix Software Commercial License.

  See LICENSE and COMMERCIAL-LICENSE.md.

  SPDX-License-Identifier: GPL-3.0-or-later OR LicenseRef-Landrix-Commercial
}

{ Example: read an invoice (UBL or CII XML, or a ZUGFeRD / Factur-X PDF)
  and print what was found.

  Usage: ReadInvoice [file]   (default: xrechnung-ubl.xml)

  Exit code 0 when the file was read, 1 when it is no readable invoice. }

program ReadInvoice;

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
  LandrixEInvoiceInvoice,
  LandrixEInvoice;

function Money(AValue: Currency): string;
begin
  Result := FormatFloat('0.00', AValue);
end;

procedure PrintInvoice(Doc: TLandrixEInvoiceDocument);
var
  Invoice: TLandrixInvoice;
  Line: TLandrixInvoiceLine;
  I: Integer;
begin
  if Doc.Info.Source = eso_Pdf then
    WriteLn('PDF with embedded ', string(Doc.Info.PdfAttachmentName));
  WriteLn('Root element: ', string(Doc.Info.RootName));
  { The specification is decided by BT-24, never by the content. An unknown
    BT-24 is read anyway, with a warning. }
  if Doc.Info.SpecFound then
    WriteLn('Specification: ', string(LandrixEInvoiceTargetToStr(Doc.Info.Spec.Target)))
  else
    WriteLn('Unknown specification: ', string(Doc.Info.CustomizationID));

  Invoice := Doc.Invoice;
  WriteLn('Invoice ', string(Invoice.InvoiceNumber), ' of ', FormatDateTime('yyyy-mm-dd', Invoice.InvoiceIssueDate));
  WriteLn('Seller: ', string(Invoice.AccountingSupplierParty.RegistrationName));
  WriteLn('Buyer:  ', string(Invoice.AccountingCustomerParty.RegistrationName));
  for I := 0 to Integer(Invoice.InvoiceLines.Count) - 1 do
  begin
    Line := Invoice.InvoiceLines[I];
    WriteLn('  ', string(Line.ID), '  ', string(Line.Name), '  ', FormatFloat('0.###', Line.Quantity), ' x ',
      FormatFloat('0.00##', Line.NetPriceAmount), ' = ', Money(Line.LineAmount));
  end;
  WriteLn('Net:     ', Money(Invoice.TaxExclusiveAmount), ' ', string(Invoice.InvoiceCurrencyCode));
  WriteLn('VAT:     ', Money(Invoice.TaxAmountTotal));
  WriteLn('Payable: ', Money(Invoice.PayableAmount));

  { Content the model does not hold (e.g. Factur-X EXTENDED details) is
    reported here and kept in the syntax model Doc.CII / Doc.UBLInvoice. }
  if Doc.Diagnostics.Count > 0 then
  begin
    WriteLn('Messages:');
    WriteLn(string(Doc.Diagnostics.ToText));
  end;
end;

var
  FileName: TLandrixEInvoiceString;
  Doc: TLandrixEInvoiceDocument;
begin
  FileName := 'xrechnung-ubl.xml';
  if ParamCount > 0 then
    FileName := TLandrixEInvoiceString(ParamStr(1));
  try
    Doc := TLandrixEInvoice.LoadFromFile(FileName);
    try
      PrintInvoice(Doc);
    finally
      Doc.Free;
    end;
  except
    { not well-formed, no invoice root, PDF without an invoice; a missing
      file raises the usual file exception }
    on E: ELandrixEInvoiceError do
    begin
      WriteLn('Not readable: ', E.Message);
      ExitCode := 1;
    end;
  end;
end.
