{
  EInvoice-for-Pascal

  Copyright (C) 2026 Landrix Software GmbH & Co. KG

  This file is dual-licensed under:
  - GNU GPL version 3 or later; or
  - the Landrix Software Commercial License.

  See LICENSE and COMMERCIAL-LICENSE.md.

  SPDX-License-Identifier: GPL-3.0-or-later OR LicenseRef-Landrix-Commercial
}

{ Tests of the advisory checks (LandrixEInvoiceAdvisory): the walk reaches
  every text field of the model (against the generated DumpInvoice), and
  the character rules LX-ID-01 to LX-ID-05, also with surrogate pairs
  (WideString under Delphi 6). The part evp_Advisory of the document
  validation is tested in LandrixEInvoiceTestValidator. }

unit LandrixEInvoiceTestAdvisory;

{$I LandrixEInvoice.inc}

interface

procedure Register;

implementation

uses
  SysUtils,
  Classes,
  LandrixEInvoiceTypes,
  LandrixEInvoiceDiagnostics,
  LandrixEInvoiceInvoice,
  LandrixEInvoiceCodes,
  LandrixEInvoiceAdvisory,
  LandrixEInvoiceTestFramework,
  LandrixEInvoiceTestInvoiceCompare;

{ AText with the UTF-16 units AUnits appended }
function With_(const AText: string; const AUnits: array of Word): TLandrixEInvoiceString;
begin
  Result := TLandrixEInvoiceString(AText) + TLandrixEInvoiceString(Wide(AUnits));
end;

{ The hints of AInvoice, one line each: rule, path, terms, severity }
function Hints(AInvoice: TLandrixInvoice; D: TLandrixEInvoiceDiagnostics): string;
var
  I: Integer;
const
  Sev: array[TLandrixEInvoiceDiagnosticSeverity] of string = ('info', 'warning', 'error');
begin
  D.Clear;
  I := LandrixEInvoiceAdvise(AInvoice, LandrixEInvoiceAdvisoryTechnical, D);
  CheckEquals(D.Count, I, 'number of hints');
  Result := '';
  for I := 0 to D.Count - 1 do
  begin
    Check(D[I].Severity <> eds_Error, 'a hint is never an error');
    Check(D[I].Kind = edk_RuleViolation, 'kind');
    if Result <> '' then
      Result := Result + '; ';
    Result := Result + string(D[I].RuleID) + ':' + string(D[I].Path) + ':' + string(D[I].Terms) + ':' +
      Sev[D[I].Severity];
  end;
end;

{ Every text field of the model, and nothing else: the walk lists the same
  paths and values as the quoted lines of DumpInvoice (with two items per
  list, so indexes and sub lines count). }
procedure TestFields;
var
  Inv: TLandrixInvoice;
  Dump, Walk, Wanted: TStringList;
  I, P, Q: Integer;
  Line, Path: string;
begin
  Inv := TLandrixInvoice.Create;
  Dump := TStringList.Create;
  Walk := TStringList.Create;
  Wanted := TStringList.Create;
  try
    FillInvoiceAll(Inv, 2);
    DumpInvoice(Inv, Dump);
    for I := 0 to Dump.Count - 1 do
    begin
      Line := Dump[I];
      P := Pos(' = "', Line);
      if P = 0 then
        Continue;
      Path := Copy(Line, 1, P - 1);
      Q := Pos(' (', Path);
      if Q > 0 then
        Path := Copy(Path, 1, Q - 1);
      Wanted.Add(Path + Copy(Line, P, MaxInt));
    end;
    LandrixEInvoiceAdvisoryListFields(Inv, Walk);
    Check(Wanted.Count > 400, 'text fields in the dump: ' + IntToStr(Wanted.Count));
    Wanted.Sort;
    Walk.Sort;
    for I := 0 to Wanted.Count - 1 do
      Check(Walk.IndexOf(Wanted[I]) >= 0, 'not walked: ' + Wanted[I]);
    for I := 0 to Walk.Count - 1 do
      Check(Wanted.IndexOf(Walk[I]) >= 0, 'walked, but no text field: ' + Walk[I]);
    CheckEquals(Wanted.Count, Walk.Count, 'every field once');
  finally
    Wanted.Free;
    Walk.Free;
    Dump.Free;
    Inv.Free;
  end;
end;

procedure TestCharacters;
var
  Inv: TLandrixInvoice;
  D: TLandrixEInvoiceDiagnostics;
  Line: TLandrixInvoiceLine;
  Pay: TLandrixInvoicePaymentType;
  S: string;
  I: Integer;
begin
  Inv := TLandrixInvoice.Create;
  D := TLandrixEInvoiceDiagnostics.Create;
  try
    CheckEqualsStr('', Hints(Inv, D), 'empty invoice');
    { a right-to-left override in the invoice number }
    Inv.InvoiceNumber := With_('R-1', [$202E]) + '42';
    CheckEqualsStr('LX-ID-01:InvoiceNumber:BT-1:warning', Hints(Inv, D), 'bidi in an identifier');
    CheckEqualsInvoiceStr('R-1<U+202E>42', D[0].Found, 'bidi: found masked');
    Check(Pos('U+202E at character 4;', string(D[0].Message)) > 0, 'bidi: message ' + string(D[0].Message));
    { not in the family set: nothing }
    D.Clear;
    CheckEquals(0, LandrixEInvoiceAdvise(Inv, [], D), 'no family');
    CheckEquals(0, D.Count, 'no family: no diagnostic');
    { without a list the hints are counted }
    CheckEquals(1, LandrixEInvoiceAdvise(Inv, LandrixEInvoiceAdvisoryTechnical, nil), 'counted without a list');
    { two zero width spaces and a C1 control character }
    Inv.InvoiceNumber := With_('A', [$200B]) + With_('B', [$200B, $0085]);
    CheckEqualsStr('LX-ID-03:InvoiceNumber:BT-1:warning; LX-ID-02:InvoiceNumber:BT-1:warning', Hints(Inv, D),
      'C1 and invisible');
    Check(Pos('U+200B at character 2 (2 in total);', string(D[1].Message)) > 0, 'count: ' + string(D[1].Message));
    CheckEqualsInvoiceStr('A<U+200B>B<U+200B><U+0085>', D[1].Found, 'all hidden characters masked');
    Inv.InvoiceNumber := '';
    { a tag character (surrogate pair) counts as one code point }
    Inv.BuyerReference := With_('AB', [$DB40, $DC41]) + 'C';
    CheckEqualsStr('LX-ID-02:BuyerReference:BT-10:warning', Hints(Inv, D), 'tag character');
    CheckEqualsInvoiceStr('AB<U+E0041>C', D[0].Found, 'tag character masked');
    Check(Pos('U+E0041 at character 3;', string(D[0].Message)) > 0, 'tag: ' + string(D[0].Message));
    { an emoji in an identifier, a lone surrogate: no hint, no exception }
    Inv.BuyerReference := With_('A', [$D83D, $DE00]) + With_('', [$D800]);
    CheckEqualsStr('', Hints(Inv, D), 'emoji and lone surrogate in an identifier');
    { a lone surrogate next to a hint is masked too }
    Inv.BuyerReference := With_('A', [$202E, $D800]);
    CheckEqualsStr('LX-ID-01:BuyerReference:BT-10:warning', Hints(Inv, D), 'lone surrogate next to a hint');
    CheckEqualsInvoiceStr('A<U+202E><U+D800>', D[0].Found, 'lone surrogate masked');
    { a lone low surrogate where the excerpt starts stays }
    S := '';
    for I := 1 to 29 do
      S := S + 'x';
    Inv.BuyerReference := With_('ab', [$DC00]) + TLandrixEInvoiceString(S) + With_('', [$202E]);
    CheckEqualsStr('LX-ID-01:BuyerReference:BT-10:warning', Hints(Inv, D), 'lone low surrogate at the start');
    CheckEqualsInvoiceStr(TLandrixEInvoiceString('...<U+DC00>' + S + '<U+202E>'), D[0].Found,
      'lone low surrogate kept');
    { invisible characters from the BMP and beyond, a no-break space }
    Inv.BuyerReference := With_('A', [$17B4]) + With_('B', [$D834, $DD73]) + With_('', [$D82F, $DCA0]);
    CheckEqualsStr('LX-ID-02:BuyerReference:BT-10:warning', Hints(Inv, D), 'Khmer vowel, musical and shorthand format');
    Check(Pos('U+17B4 at character 2 (3 in total);', string(D[0].Message)) > 0, 'invisible: ' + string(D[0].Message));
    CheckEqualsInvoiceStr('A<U+17B4>B<U+1D173><U+1BCA0>', D[0].Found, 'invisible masked');
    Inv.BuyerReference := With_('04011000', [$00A0]) + '1234';
    CheckEqualsStr('LX-ID-02:BuyerReference:BT-10:warning', Hints(Inv, D), 'no-break space in an identifier');
    CheckEqualsInvoiceStr('04011000<U+00A0>1234', D[0].Found, 'no-break space masked');
    Inv.AccountingSupplierParty.Name := With_('Dr.', [$00A0]) + 'Meier';
    CheckEqualsStr('LX-ID-02:BuyerReference:BT-10:warning', Hints(Inv, D), 'no-break space in a name: no hint');
    Inv.AccountingSupplierParty.Name := '';
    Inv.BuyerReference := '';
    { names and texts: an info; letters outside ASCII are fine }
    Inv.AccountingSupplierParty.Name := With_('M', [$00FC]) + 'ller';
    CheckEqualsStr('', Hints(Inv, D), 'umlaut in a name');
    Inv.AccountingSupplierParty.Name := With_('Shop ', [$D83D, $DE00, $FE0F, $200D]);
    CheckEqualsStr('LX-ID-04:AccountingSupplierParty.Name:BT-28:info', Hints(Inv, D), 'joiner in a name');
    Check(Pos('U+FE0F at character 7 (2 in total);', string(D[0].Message)) > 0, 'text: ' + string(D[0].Message));
    CheckEqualsInvoiceStr(With_('Shop ', [$D83D, $DE00]) + '<U+FE0F><U+200D>', D[0].Found, 'emoji kept');
    Inv.AccountingSupplierParty.Name := '';
    { C1 in a text: a warning }
    Inv.Notes.AddNote.Content := With_('a', [$0085]) + 'b';
    CheckEqualsStr('LX-ID-03:Notes[0].Content:BT-22:warning', Hints(Inv, D), 'C1 in a note');
    Inv.Notes.Clear;
    { an ASCII identifier: a Cyrillic letter in the VAT identifier }
    Inv.AccountingSupplierParty.VATCompanyID := With_('D', [$0415]) + '123456789';
    CheckEqualsStr('LX-ID-05:AccountingSupplierParty.VATCompanyID:BT-31:warning', Hints(Inv, D), 'homoglyph');
    CheckEqualsInvoiceStr('D<U+0415>123456789', D[0].Found, 'homoglyph masked');
    Inv.AccountingSupplierParty.VATCompanyID := With_('DE', [$202E]) + '1';
    CheckEqualsStr('LX-ID-01:AccountingSupplierParty.VATCompanyID:BT-31:warning', Hints(Inv, D),
      'bidi in an ASCII identifier: not LX-ID-05 too');
    Inv.AccountingSupplierParty.VATCompanyID := '';
    Inv.AccountingCustomerParty.VATCompanyID := With_('FR', [$FF11]);
    CheckEqualsStr('LX-ID-05:AccountingCustomerParty.VATCompanyID:BT-48:warning', Hints(Inv, D), 'buyer VAT');
    Inv.AccountingCustomerParty.VATCompanyID := '';
    { the account of a SEPA payment is ASCII, another account not }
    Pay := Inv.PaymentTypes.AddPaymentType;
    Pay.PaymentMeansCode := ipmc_SEPACreditTransfer;
    Pay.FinancialAccount := With_('DE89', [$FF13]) + '704';
    CheckEqualsStr('LX-ID-05:PaymentTypes[0].FinancialAccount:BT-84/BT-91/BT-87:warning', Hints(Inv, D), 'SEPA IBAN');
    { an account that starts like an IBAN is ASCII under any payment means }
    Pay.PaymentMeansCode := ipmc_Cheque;
    CheckEqualsStr('LX-ID-05:PaymentTypes[0].FinancialAccount:BT-84/BT-91/BT-87:warning', Hints(Inv, D),
      'IBAN of a cheque');
    Pay.FinancialAccount := With_('DE', [$FF18, $FF19]) + '3704';
    CheckEqualsStr('LX-ID-05:PaymentTypes[0].FinancialAccount:BT-84/BT-91/BT-87:warning', Hints(Inv, D),
      'IBAN with fullwidth check digits');
    Pay.FinancialAccount := With_('12', [$00E9]);
    CheckEqualsStr('', Hints(Inv, D), 'other account');
    Pay.FinancialAccount := '';
    { the mandate reference is ASCII for a SEPA direct debit only }
    Inv.PaymentMandateID := With_('M-', [$00C4]);
    CheckEqualsStr('', Hints(Inv, D), 'mandate without SEPA');
    Pay.PaymentMeansCode := ipmc_SEPADirectDebit;
    CheckEqualsStr('LX-ID-05:PaymentMandateID:BT-89:warning', Hints(Inv, D), 'mandate of a SEPA direct debit');
    Inv.PaymentTypes.AddPaymentType.PaymentMeansCode := ipmc_DirectDebit;
    CheckEqualsStr('', Hints(Inv, D), 'mandate with a general direct debit too');
    Inv.PaymentTypes.Delete(1);
    Inv.PaymentMandateID := '';
    { the remittance information is text }
    Inv.PaymentID := With_('Fatura ', [$200F]) + '12';
    CheckEqualsStr('LX-ID-04:PaymentID:BT-83:info', Hints(Inv, D), 'remittance information');
    Inv.PaymentID := '';
    { a currency code }
    Inv.InvoiceCurrencyCode := With_('EU', [$0280]);
    CheckEqualsStr('LX-ID-05:InvoiceCurrencyCode:BT-5:warning', Hints(Inv, D), 'currency code');
    Inv.InvoiceCurrencyCode := 'EUR';
    Pay.FinancialInstitutionBranch := With_('COBADEFF', [$00C9]);
    CheckEqualsStr('LX-ID-05:PaymentTypes[0].FinancialInstitutionBranch:BT-86:warning', Hints(Inv, D), 'BIC');
    Inv.PaymentTypes.Clear;
    { a sub line: the model path with both indexes, the terms of the line }
    Line := Inv.InvoiceLines.AddInvoiceLine;
    { a GTIN: ASCII, both fields with the same value checked once }
    Line.StandardItemIdentifierSchemeID := '0160';
    Line.StandardItemIdentifier := With_('400638133393', [$FF11]);
    Line.GlobalID_EAN_GTIN := Line.StandardItemIdentifier;
    CheckEqualsStr('LX-ID-05:InvoiceLines[0].StandardItemIdentifier:BT-157:warning', Hints(Inv, D), 'GTIN once');
    Line.StandardItemIdentifier := '';
    Line.GlobalID_EAN_GTIN := '';
    Line.SubInvoiceLines.AddInvoiceLine;
    Line := Line.SubInvoiceLines.AddInvoiceLine;
    Line.SellersItemIdentification := With_('A', [$2066]);
    CheckEqualsStr('LX-ID-01:InvoiceLines[0].SubInvoiceLines[1].SellersItemIdentification:BT-155:warning',
      Hints(Inv, D), 'sub line');
    Inv.InvoiceLines.Clear;
    { a long text is cut around the first character }
    S := '';
    for I := 1 to 100 do
      S := S + 'x';
    Inv.Notes.AddNote.Content := TLandrixEInvoiceString(S) + With_('', [$202E]) + TLandrixEInvoiceString(S);
    CheckEqualsStr('LX-ID-04:Notes[0].Content:BT-22:info', Hints(Inv, D), 'long note');
    CheckEqualsInvoiceStr(TLandrixEInvoiceString('...' + Copy(S, 1, 30) + '<U+202E>' + Copy(S, 1, 30) + '...'),
      D[0].Found, 'long note: excerpt');
  finally
    D.Free;
    Inv.Free;
  end;
end;

procedure Register;
begin
  RegisterTest('Advisory.Fields', TestFields);
  RegisterTest('Advisory.Characters', TestCharacters);
end;

end.
