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
  LandrixEInvoiceIdentifiers,
  LandrixEInvoiceAdvisory,
  LandrixEInvoiceTestFramework,
  LandrixEInvoiceTestInvoiceCompare;

{ AText with the UTF-16 units AUnits appended }
function With_(const AText: string; const AUnits: array of Word): TLandrixEInvoiceString;
begin
  Result := TLandrixEInvoiceString(AText) + TLandrixEInvoiceString(Wide(AUnits));
end;

const
  { the target of nothing in particular }
  NoTarget: TLandrixEInvoiceTarget = (Standard: est_None; Syntax: esy_None; Profile: epr_None; Version: '');

{ The hints of the families AFamilies on AInvoice read as AStandard, the
  rule check having reported AReported (comma separated), one line each:
  rule, path, terms, severity }
function FamilyHints(AInvoice: TLandrixInvoice; D: TLandrixEInvoiceDiagnostics;
  AFamilies: TLandrixEInvoiceAdvisoryFamilies; AStandard: TLandrixEInvoiceStandard; const AReported: string): string;
var
  I: Integer;
  Target: TLandrixEInvoiceTarget;
  Reported: TStringList;
const
  Sev: array[TLandrixEInvoiceDiagnosticSeverity] of string = ('info', 'warning', 'error');
begin
  D.Clear;
  Target := NoTarget;
  Target.Standard := AStandard;
  Reported := TStringList.Create;
  try
    Reported.CommaText := AReported;
    I := LandrixEInvoiceAdvise(AInvoice, Target, AFamilies, D, Reported);
  finally
    Reported.Free;
  end;
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

{ the identifier family; AR040Reported: PEPPOL-COMMON-R040 was reported }
function HintsAs(AInvoice: TLandrixInvoice; D: TLandrixEInvoiceDiagnostics; AStandard: TLandrixEInvoiceStandard;
  AR040Reported: Boolean = False): string;
begin
  if AR040Reported then
    Result := FamilyHints(AInvoice, D, [eaf_Identifiers], AStandard, 'PEPPOL-COMMON-R040')
  else
    Result := FamilyHints(AInvoice, D, [eaf_Identifiers], AStandard, '');
end;

function Hints(AInvoice: TLandrixInvoice; D: TLandrixEInvoiceDiagnostics): string;
begin
  Result := HintsAs(AInvoice, D, est_None);
end;

function PlHints(AInvoice: TLandrixInvoice; D: TLandrixEInvoiceDiagnostics; const AReported: string): string;
begin
  Result := FamilyHints(AInvoice, D, [eaf_Plausibility], est_None, AReported);
end;

{ plausibility for a CII target }
function PlCiiHints(AInvoice: TLandrixInvoice; D: TLandrixEInvoiceDiagnostics): string;
var
  I: Integer;
  Target: TLandrixEInvoiceTarget;
const
  Sev: array[TLandrixEInvoiceDiagnosticSeverity] of string = ('info', 'warning', 'error');
begin
  D.Clear;
  Target := NoTarget;
  Target.Syntax := esy_CII;
  LandrixEInvoiceAdvise(AInvoice, Target, [eaf_Plausibility], D, nil);
  Result := '';
  for I := 0 to D.Count - 1 do
  begin
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
    CheckEquals(0, LandrixEInvoiceAdvise(Inv, NoTarget, [], D), 'no family');
    CheckEquals(0, D.Count, 'no family: no diagnostic');
    { without a list the hints are counted }
    CheckEquals(1, LandrixEInvoiceAdvise(Inv, NoTarget, [eaf_Identifiers], nil),
      'counted without a list');
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
    { a known code kept as other text is that code }
    Pay.PaymentMeansCode := ipmc_NotImplemented;
    Pay.PaymentMeansCodeOther := ' 59 ';
    CheckEqualsStr('LX-ID-05:PaymentMandateID:BT-89:warning', Hints(Inv, D), 'SEPA direct debit as other text');
    Pay.PaymentMeansCodeOther := '';
    Pay.PaymentMeansCode := ipmc_SEPADirectDebit;
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
    CheckEqualsStr('LX-ID-05:InvoiceLines[0].StandardItemIdentifier:BT-157:warning; ' +
      'LX-ID-07:InvoiceLines[0].StandardItemIdentifier:BT-157:warning', Hints(Inv, D), 'GTIN once');
    CheckEqualsInvoiceStr('400638133393<U+FF11>', D[1].Found, 'GTIN: fullwidth digit masked');
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

{ Identifiers by their scheme: GLN, GTIN, a scheme in the wrong place,
  Leitweg-ID (format specification 2.0.2, example 04011000-1234512345-06),
  BT-10 against the buyer's Leitweg-ID. }
procedure TestSchemes;
var
  Inv: TLandrixInvoice;
  D: TLandrixEInvoiceDiagnostics;
  Line: TLandrixInvoiceLine;
  Expected: TLandrixEInvoiceString;
begin
  Inv := TLandrixInvoice.Create;
  D := TLandrixEInvoiceDiagnostics.Create;
  try
    { the Leitweg-ID building block }
    Check(LandrixEInvoiceLeitwegIDProblem('04011000-1234512345-06', Expected) = elp_None, 'Leitweg example');
    CheckEqualsInvoiceStr('06', Expected, 'Leitweg example: check digits');
    Check(LandrixEInvoiceLeitwegIDProblem('991-33333test-33', Expected) = elp_None, 'Leitweg, lower case');
    Check(LandrixEInvoiceLeitwegIDProblem('99-92', Expected) = elp_None, 'Leitweg, two digits');
    Check(LandrixEInvoiceLeitwegIDProblem('04011000-1234512345-35', Expected) = elp_CheckDigits, 'check digits');
    CheckEqualsInvoiceStr('06', Expected, 'check digits: expected');
    Check(LandrixEInvoiceLeitwegIDProblem('0401100-12-06', Expected) = elp_CoarseLength, 'coarse length');
    Check(LandrixEInvoiceLeitwegIDProblem('17011000-X-76', Expected) = elp_State, 'state');
    Check(LandrixEInvoiceLeitwegIDProblem('04011000--06', Expected) = elp_Form, 'empty fine address');
    Check(LandrixEInvoiceLeitwegIDProblem('04011000-12_45-06', Expected) = elp_Form, 'fine address character');
    Check(LandrixEInvoiceLeitwegIDProblem('04011000-1234512345-6', Expected) = elp_Form, 'one check digit');
    Check(LandrixEInvoiceLeitwegIDProblem('0401100012345-06', Expected) = elp_Form, 'coarse of 13 digits');
    Check(LandrixEInvoiceLeitwegIDProblem('-06', Expected) = elp_Form, 'no coarse address');
    CheckEquals(7, LandrixEInvoiceGS1CheckDigit('5901234123457'), 'GS1 check digit');
    CheckEquals(-1, LandrixEInvoiceGS1CheckDigit('5'), 'GS1: one digit');
    { GLN }
    Inv.AccountingSupplierParty.GlobalIdentifierSellerBuyerSchemeID := '0088';
    Inv.AccountingSupplierParty.GlobalIdentifierSellerBuyer := '4000001000005';
    CheckEqualsStr('', Hints(Inv, D), 'valid GLN');
    Inv.AccountingSupplierParty.GlobalIdentifierSellerBuyer := '4000001000006';
    CheckEqualsStr('LX-ID-06:AccountingSupplierParty.GlobalIdentifierSellerBuyer:BT-29-0:warning', Hints(Inv, D),
      'GLN check digit');
    CheckEqualsInvoiceStr('5', D[0].Expected, 'GLN: expected');
    CheckEqualsInvoiceStr('6', D[0].Found, 'GLN: found');
    { Peppol: PEPPOL-COMMON-R040 reported the check digit, the length is
      ours }
    CheckEqualsStr('', HintsAs(Inv, D, est_PeppolBIS, True), 'GLN check digit with Peppol');
    CheckEqualsStr('LX-ID-06:AccountingSupplierParty.GlobalIdentifierSellerBuyer:BT-29-0:warning',
      HintsAs(Inv, D, est_PeppolBIS), 'GLN check digit with Peppol, R040 not reported');
    { 13 characters, one no digit: R040 reports it }
    Inv.AccountingSupplierParty.GlobalIdentifierSellerBuyer := '400000100000X';
    CheckEqualsStr('', HintsAs(Inv, D, est_PeppolBIS, True), 'GLN with a letter, R040 reported');
    Inv.AccountingSupplierParty.GlobalIdentifierSellerBuyer := With_('400000100000', [$D835, $DFCF]);
    CheckEqualsStr('', HintsAs(Inv, D, est_PeppolBIS, True), 'GLN with a supplementary digit, R040 reported');
    Inv.AccountingSupplierParty.GlobalIdentifierSellerBuyer := '00012345600013';
    CheckEqualsStr('LX-ID-06:AccountingSupplierParty.GlobalIdentifierSellerBuyer:BT-29-0:warning',
      HintsAs(Inv, D, est_PeppolBIS, True), 'GLN of 14 digits with Peppol');
    Check(Pos('not 13 digits', string(D[0].Message)) > 0, 'GLN length: ' + string(D[0].Message));
    { a padded scheme: R040 compares the scheme as written, so ours stays }
    Inv.AccountingSupplierParty.GlobalIdentifierSellerBuyerSchemeID := ' 0088';
    Inv.AccountingSupplierParty.GlobalIdentifierSellerBuyer := '4000001000006';
    CheckEqualsStr('LX-ID-06:AccountingSupplierParty.GlobalIdentifierSellerBuyer:BT-29-0:warning',
      HintsAs(Inv, D, est_PeppolBIS, True), 'GLN with a padded scheme');
    { without scheme the global identifier is a GLN }
    Inv.AccountingSupplierParty.GlobalIdentifierSellerBuyerSchemeID := '';
    Inv.AccountingSupplierParty.GlobalIdentifierSellerBuyer := '00012345600012';
    CheckEqualsStr('LX-ID-06:AccountingSupplierParty.GlobalIdentifierSellerBuyer:BT-29-0:warning', Hints(Inv, D),
      'global identifier without scheme');
    Inv.AccountingSupplierParty.GlobalIdentifierSellerBuyer := '';
    { the delivery location is no PEPPOL-COMMON place }
    Inv.DeliveryInformation.LocationIdentifierSchemeID := '0088';
    Inv.DeliveryInformation.LocationIdentifier := '4000001000006';
    CheckEqualsStr('LX-ID-06:DeliveryInformation.LocationIdentifier:BT-71:warning', HintsAs(Inv, D, est_PeppolBIS),
      'delivery GLN with Peppol');
    { a GTIN for a location }
    Inv.DeliveryInformation.LocationIdentifierSchemeID := '0160';
    Inv.DeliveryInformation.LocationIdentifier := '96385074';
    CheckEqualsStr('LX-ID-08:DeliveryInformation.LocationIdentifier:BT-71:warning', Hints(Inv, D), 'GTIN for a place');
    Inv.DeliveryInformation.LocationIdentifier := '';
    { GTIN }
    Line := Inv.InvoiceLines.AddInvoiceLine;
    Line.StandardItemIdentifierSchemeID := '0160';
    Line.StandardItemIdentifier := '96385074';
    Line.GlobalID_EAN_GTIN := '96385074';
    CheckEqualsStr('', Hints(Inv, D), 'valid GTIN-8');
    Line.StandardItemIdentifier := '00012345600012';
    Line.GlobalID_EAN_GTIN := Line.StandardItemIdentifier;
    CheckEqualsStr('', Hints(Inv, D), 'valid GTIN-14');
    Line.StandardItemIdentifier := '5901234123458';
    Line.GlobalID_EAN_GTIN := Line.StandardItemIdentifier;
    CheckEqualsStr('LX-ID-07:InvoiceLines[0].StandardItemIdentifier:BT-157:warning', Hints(Inv, D), 'GTIN once');
    { the GTIN field is written only without BT-157 }
    Line.GlobalID_EAN_GTIN := '123456789';
    CheckEqualsStr('LX-ID-07:InvoiceLines[0].StandardItemIdentifier:BT-157:warning', Hints(Inv, D),
      'GTIN field not written');
    Line.StandardItemIdentifier := '';
    CheckEqualsStr('LX-ID-07:InvoiceLines[0].GlobalID_EAN_GTIN:BT-157:warning', Hints(Inv, D), 'GTIN field');
    Check(Pos('not 8, 12, 13 or 14 digits', string(D[0].Message)) > 0, 'GTIN length: ' + string(D[0].Message));
    { a value with a hidden character is shown masked }
    Line.GlobalID_EAN_GTIN := With_('9638', [$202E]) + '5074';
    CheckEqualsStr('LX-ID-01:InvoiceLines[0].GlobalID_EAN_GTIN:BT-157:warning; ' +
      'LX-ID-07:InvoiceLines[0].GlobalID_EAN_GTIN:BT-157:warning', Hints(Inv, D), 'GTIN with bidi');
    CheckEqualsInvoiceStr('9638<U+202E>5074', D[1].Found, 'GTIN shown masked');
    Line.GlobalID_EAN_GTIN := '';
    { a Leitweg-ID as item identifier }
    Line.StandardItemIdentifierSchemeID := '0204';
    Line.StandardItemIdentifier := '04011000-1234512345-35';
    CheckEqualsStr('LX-ID-09:InvoiceLines[0].StandardItemIdentifier:BT-157:warning', Hints(Inv, D),
      'Leitweg-ID as item identifier');
    CheckEqualsInvoiceStr('06', D[0].Expected, 'item Leitweg-ID: expected');
    Line.StandardItemIdentifierSchemeID := '0088';
    Line.StandardItemIdentifier := '4000001000005';
    CheckEqualsStr('LX-ID-08:InvoiceLines[0].StandardItemIdentifier:BT-157:warning', Hints(Inv, D), 'GLN for an item');
    Inv.InvoiceLines.Clear;
    { Leitweg-ID as electronic address }
    Inv.AccountingCustomerParty.ElectronicAddressSellerBuyerSchemeID := '0204';
    Inv.AccountingCustomerParty.ElectronicAddressSellerBuyer := '04011000-1234512345-06';
    CheckEqualsStr('', Hints(Inv, D), 'valid Leitweg-ID');
    Inv.AccountingCustomerParty.ElectronicAddressSellerBuyer := '04011000-1234512345-35';
    CheckEqualsStr('LX-ID-09:AccountingCustomerParty.ElectronicAddressSellerBuyer:BT-49:warning', Hints(Inv, D),
      'Leitweg-ID check digits');
    CheckEqualsInvoiceStr('06', D[0].Expected, 'Leitweg: expected');
    CheckEqualsInvoiceStr('35', D[0].Found, 'Leitweg: found');
    Inv.AccountingCustomerParty.ElectronicAddressSellerBuyer := ' 99-92 ';
    CheckEqualsStr('LX-ID-09:AccountingCustomerParty.ElectronicAddressSellerBuyer:BT-49:warning', Hints(Inv, D),
      'Leitweg-ID with blanks');
    Inv.AccountingCustomerParty.ElectronicAddressSellerBuyer := '17011000-X-76';
    CheckEqualsStr('LX-ID-09:AccountingCustomerParty.ElectronicAddressSellerBuyer:BT-49:warning', Hints(Inv, D),
      'Leitweg-ID state');
    Check(Pos('starts with 17', string(D[0].Message)) > 0, 'state: ' + string(D[0].Message));
    { BT-10: only when it looks like a Leitweg-ID }
    Inv.AccountingCustomerParty.ElectronicAddressSellerBuyer := '991-33333TEST-33';
    Inv.BuyerReference := 'PO-4711';
    CheckEqualsStr('', Hints(Inv, D), 'other buyer reference');
    Inv.BuyerReference := '17011000-X-76';
    CheckEqualsStr('', Hints(Inv, D), 'buyer reference of another form');
    Inv.BuyerReference := '01-12-23';
    CheckEqualsStr('', Hints(Inv, D), 'a date as buyer reference');
    Inv.BuyerReference := '05-2024-12';
    CheckEqualsStr('', Hints(Inv, D), 'an order number as buyer reference');
    Inv.BuyerReference := '991-33333TEST-34';
    CheckEqualsStr('LX-ID-09:BuyerReference:BT-10:info', Hints(Inv, D), 'federation Leitweg-ID as BT-10');
    Inv.BuyerReference := '04011000-1234512345-35';
    CheckEqualsStr('LX-ID-09:BuyerReference:BT-10:warning', HintsAs(Inv, D, est_XRechnung), 'BT-10 for XRechnung');
    CheckEqualsStr('LX-ID-09:BuyerReference:BT-10:info', Hints(Inv, D), 'BT-10 otherwise');
    { BT-10 and BT-49 different Leitweg-IDs: an info; the same in other case:
      none }
    Inv.BuyerReference := '04011000-1234512345-06';
    CheckEqualsStr('LX-ID-10:BuyerReference:BT-10:info', Hints(Inv, D), 'different Leitweg-IDs');
    Inv.BuyerReference := '991-33333test-33';
    CheckEqualsStr('', Hints(Inv, D), 'same Leitweg-ID');
    { a valid Leitweg-ID of the federation without fine address differs too }
    Inv.BuyerReference := '99-92';
    CheckEqualsStr('LX-ID-10:BuyerReference:BT-10:info', Hints(Inv, D), 'different short Leitweg-ID');
    Inv.BuyerReference := ' 99-92 ';
    CheckEqualsStr('', Hints(Inv, D), 'BT-10 with blanks is no Leitweg-ID to compare');
  finally
    D.Free;
    Inv.Free;
  end;
end;

{ Dates and payment (LX-PL): due date, IBAN, BIC, account holder, SEPA
  direct debit; what the rule check reported is not repeated. }
procedure TestPlausibility;
var
  Inv: TLandrixInvoice;
  D: TLandrixEInvoiceDiagnostics;
  Pay, Pay2: TLandrixInvoicePaymentType;
begin
  Inv := TLandrixInvoice.Create;
  D := TLandrixEInvoiceDiagnostics.Create;
  try
    Check(eaf_Plausibility in LandrixEInvoiceAdvisoryTechnical, 'plausibility is technical');
    CheckEqualsStr('', PlHints(Inv, D, ''), 'empty invoice');
    CheckEqualsInvoiceStr('89', LandrixEInvoiceIBANCheckDigits('DE00370400440532013000'), 'IBAN check digits');
    CheckEqualsInvoiceStr('', LandrixEInvoiceIBANCheckDigits('D1893704'), 'IBAN form');
    CheckEqualsInvoiceStr('', LandrixEInvoiceIBANCheckDigits('DE36'), 'IBAN without BBAN');
    { due date }
    Inv.InvoiceIssueDate := EncodeDate(2026, 11, 19);
    Inv.InvoiceDueDate := EncodeDate(2026, 11, 18);
    CheckEqualsStr('LX-PL-01:InvoiceDueDate:BT-9:warning', PlHints(Inv, D, ''), 'due date before');
    CheckEqualsInvoiceStr('2026-11-19', D[0].Expected, 'due date: expected');
    CheckEqualsInvoiceStr('2026-11-18', D[0].Found, 'due date: found');
    Inv.InvoiceTypeCode := itc_CreditNote;
    CheckEqualsStr('', PlHints(Inv, D, ''), 'credit note');
    Inv.InvoiceTypeCode := itc_None;
    Inv.InvoiceTypeCodeOther := '381';
    CheckEqualsStr('', PlHints(Inv, D, ''), 'credit note as other code');
    Inv.InvoiceTypeCodeOther := '503';
    CheckEqualsStr('', PlHints(Inv, D, ''), 'credit note 503');
    Inv.InvoiceTypeCodeOther := '';
    Inv.InvoiceTypeCode := itc_CommercialInvoice;
    Inv.TaxInclusiveAmount := -10;
    CheckEqualsStr('', PlHints(Inv, D, ''), 'negative total');
    Inv.TaxInclusiveAmount := 119;
    Inv.PrepaidAmount := 119;
    CheckEqualsStr('', PlHints(Inv, D, ''), 'paid in advance');
    Inv.PrepaidAmount := 0;
    Inv.InvoiceDueDate := EncodeDate(2026, 11, 19) + 0.5;
    CheckEqualsStr('', PlHints(Inv, D, ''), 'due on the invoice date');
    Inv.InvoiceDueDate := 0;
    { IBAN }
    Pay := Inv.PaymentTypes.AddPaymentType;
    Pay.PaymentMeansCode := ipmc_SEPACreditTransfer;
    Pay.FinancialAccount := 'DE89 3704 0044 0532 0130 00';
    CheckEqualsStr('', PlHints(Inv, D, ''), 'valid IBAN with blanks');
    Pay.FinancialAccount := 'DE88370400440532013000';
    CheckEqualsStr('LX-PL-02:PaymentTypes[0].FinancialAccount:BT-84/BT-91/BT-87:warning', PlHints(Inv, D, ''),
      'IBAN check digits');
    CheckEqualsInvoiceStr('89', D[0].Expected, 'IBAN: expected');
    CheckEqualsInvoiceStr('88', D[0].Found, 'IBAN: found');
    CheckEqualsStr('', PlHints(Inv, D, 'BR-DE-19'), 'IBAN reported by BR-DE-19');
    CheckEqualsStr('', PlHints(Inv, D, 'DE-R-019'), 'IBAN reported by DE-R-019');
    Pay.FinancialAccount := 'de89370400440532013000';
    CheckEqualsStr('LX-PL-02:PaymentTypes[0].FinancialAccount:BT-84/BT-91/BT-87:warning', PlHints(Inv, D, ''),
      'IBAN in small letters');
    Check(Pos('small letters', string(D[0].Message)) > 0, 'small letters: ' + string(D[0].Message));
    Pay.FinancialAccount := 'DE99370400440532013000';
    CheckEqualsStr('LX-PL-02:PaymentTypes[0].FinancialAccount:BT-84/BT-91/BT-87:warning', PlHints(Inv, D, ''),
      'IBAN with 99 as check digits');
    Pay.FinancialAccount := 'QQ33370400440532013000';
    CheckEqualsStr('LX-PL-02:PaymentTypes[0].FinancialAccount:BT-84/BT-91/BT-87:warning', PlHints(Inv, D, ''),
      'IBAN of no country');
    Check(Pos('starts with QQ', string(D[0].Message)) > 0, 'IBAN country: ' + string(D[0].Message));
    Pay.FinancialAccount := 'XK051212012345678906';
    CheckEqualsStr('', PlHints(Inv, D, ''), 'IBAN of Kosovo');
    Pay.FinancialAccount := 'DE36';
    CheckEqualsStr('LX-PL-02:PaymentTypes[0].FinancialAccount:BT-84/BT-91/BT-87:warning', PlHints(Inv, D, ''),
      'IBAN without BBAN');
    { two SEPA credit transfers: BR-DE-19 may mean the other one }
    Pay2 := Inv.PaymentTypes.AddPaymentType;
    Pay2.PaymentMeansCode := ipmc_SEPACreditTransfer;
    Pay2.FinancialAccount := 'DE89370400440532013000';
    Pay.FinancialAccount := 'DE88370400440532013000';
    CheckEqualsStr('', PlHints(Inv, D, 'BR-DE-19'), 'BR-DE-19 with two transfers: it means the bad one');
    Pay2.FinancialAccount := 'DE88370400440532013000';
    CheckEqualsStr('', PlHints(Inv, D, 'BR-DE-19'), 'BR-DE-19 with two bad transfers');
    { the other code ' 58 ' is not BR-DE-19's: it stays }
    Pay2.PaymentMeansCode := ipmc_NotImplemented;
    Pay2.PaymentMeansCodeOther := ' 58 ';
    CheckEqualsStr('LX-PL-02:PaymentTypes[1].FinancialAccount:BT-84/BT-91/BT-87:warning', PlHints(Inv, D, 'BR-DE-19'),
      'BR-DE-19 and a transfer as other code');
    Pay2.PaymentMeansCodeOther := '';
    Pay2.PaymentMeansCode := ipmc_SEPACreditTransfer;
    Pay2.FinancialAccount := 'de89370400440532013000';
    Pay2.PaymentMeansCode := ipmc_CreditTransfer;
    CheckEqualsStr('LX-PL-02:PaymentTypes[0].FinancialAccount:BT-84/BT-91/BT-87:warning; ' +
      'LX-PL-02:PaymentTypes[1].FinancialAccount:BT-84/BT-91/BT-87:warning', PlHints(Inv, D, ''),
      'small letters on a credit transfer 30');
    Inv.PaymentTypes.Delete(1);
    Pay.FinancialAccount := 'KONTO-4711';
    CheckEqualsStr('LX-PL-02:PaymentTypes[0].FinancialAccount:BT-84/BT-91/BT-87:warning', PlHints(Inv, D, ''),
      'SEPA account of no IBAN form');
    Pay.PaymentMeansCode := ipmc_CreditTransfer;
    CheckEqualsStr('', PlHints(Inv, D, ''), 'other account of a credit transfer');
    Pay.FinancialAccount := 'DE88370400440532013000';
    CheckEqualsStr('LX-PL-02:PaymentTypes[0].FinancialAccount:BT-84/BT-91/BT-87:warning', PlHints(Inv, D, ''),
      'IBAN of a credit transfer');
    Pay.FinancialAccount := 'DE89370400440532013000';
    { BIC }
    Pay.FinancialInstitutionBranch := 'COBADEFFXXX';
    CheckEqualsStr('', PlHints(Inv, D, ''), 'valid BIC');
    Pay.FinancialInstitutionBranch := '37040044';
    CheckEqualsStr('', PlHints(Inv, D, ''), 'national bank code');
    Pay.FinancialInstitutionBranch := 'COBADEF';
    CheckEqualsStr('LX-PL-03:PaymentTypes[0].FinancialInstitutionBranch:BT-86:warning', PlHints(Inv, D, ''),
      'BIC of seven characters');
    Pay.FinancialInstitutionBranch := 'cobadeff';
    CheckEqualsStr('LX-PL-03:PaymentTypes[0].FinancialInstitutionBranch:BT-86:warning', PlHints(Inv, D, ''),
      'BIC in small letters');
    Pay.FinancialInstitutionBranch := 'COBAQQFF';
    CheckEqualsStr('LX-PL-03:PaymentTypes[0].FinancialInstitutionBranch:BT-86:warning', PlHints(Inv, D, ''),
      'BIC with an unknown country');
    Pay.FinancialInstitutionBranch := 'BANKXKPR';
    CheckEqualsStr('', PlHints(Inv, D, ''), 'BIC of Kosovo');
    Pay.FinancialInstitutionBranch := 'A1BCDEFF';
    CheckEqualsStr('', PlHints(Inv, D, ''), 'BIC with a digit in the prefix');
    Pay.FinancialInstitutionBranch := 'BANKXI22';
    CheckEqualsStr('LX-PL-03:PaymentTypes[0].FinancialInstitutionBranch:BT-86:warning', PlHints(Inv, D, ''),
      'BIC of XI');
    Pay.FinancialInstitutionBranch := 'SE:BANKGIRO';
    CheckEqualsStr('', PlHints(Inv, D, ''), 'Swedish clearing identifier');
    Pay.FinancialInstitutionBranch := 'RBIS0NEFTHY';
    CheckEqualsStr('', PlHints(Inv, D, ''), 'Indian IFSC');
    Pay.FinancialInstitutionBranch := 'A1BC0DE1234';
    CheckEqualsStr('LX-PL-03:PaymentTypes[0].FinancialInstitutionBranch:BT-86:warning', PlHints(Inv, D, ''),
      'no IFSC: a digit in the bank prefix');
    Pay.FinancialInstitutionBranch := 'RBIS0NEFThY';
    CheckEqualsStr('LX-PL-03:PaymentTypes[0].FinancialInstitutionBranch:BT-86:warning', PlHints(Inv, D, ''),
      'no IFSC: a small letter in the branch');
    Pay.FinancialInstitutionBranch := '';
    { account holder }
    Inv.AccountingSupplierParty.RegistrationName := 'Muster GmbH & Co. KG';
    Pay.FinancialAccountName := 'MUSTER GMBH';
    CheckEqualsStr('', PlHints(Inv, D, ''), 'holder is the seller');
    Pay.FinancialAccountName := 'Anders AG';
    CheckEqualsStr('LX-PL-04:PaymentTypes[0].FinancialAccountName:BT-85/BT-88:info', PlHints(Inv, D, ''),
      'holder is someone else');
    CheckEqualsInvoiceStr('Muster GmbH & Co. KG', D[0].Expected, 'holder: expected');
    Inv.PayeeParty.Name := 'Anders AG';
    CheckEqualsStr('', PlHints(Inv, D, ''), 'with a payee');
    Inv.PayeeParty.Name := '';
    Inv.PayeeParty.CompanyID := 'HRB 1';
    CheckEqualsStr('', PlHints(Inv, D, ''), 'with a payee by legal registration');
    Inv.PayeeParty.CompanyID := '';
    Inv.AccountingSupplierParty.RegistrationName := With_('Stra', [$00DF]) + 'e GmbH';
    Pay.FinancialAccountName := 'STRASSE GMBH';
    CheckEqualsStr('', PlHints(Inv, D, ''), 'sharp s');
    Pay.FinancialAccountName := With_('', [$041E, $041E, $041E]);
    CheckEqualsStr('', PlHints(Inv, D, ''), 'Cyrillic holder: inconclusive');
    Pay.FinancialAccountName := With_('Anders', [$0085]) + ' AG';
    CheckEqualsStr('LX-PL-04:PaymentTypes[0].FinancialAccountName:BT-85/BT-88:info', PlHints(Inv, D, ''),
      'holder with a C1 control');
    CheckEqualsInvoiceStr('Anders<U+0085> AG', D[0].Found, 'holder masked');
    Pay.FinancialAccountName := TLandrixEInvoiceString(StringOfChar('A', 2000));
    CheckEqualsStr('', PlHints(Inv, D, ''), 'a very long holder: inconclusive');
    Pay.FinancialAccountName := '';
    { SEPA direct debit }
    Pay.PaymentMeansCode := ipmc_SEPADirectDebit;
    Pay.FinancialAccount := '';
    CheckEqualsStr('LX-PL-05:PaymentMandateID:BT-89:warning; ' +
      'LX-PL-05:AccountingSupplierParty.BankAssignedCreditorIdentifier:BT-90:warning; ' +
      'LX-PL-05:PaymentTypes[0].FinancialAccount:BT-84/BT-91/BT-87:warning', PlHints(Inv, D, ''), 'direct debit');
    CheckEqualsStr('LX-PL-05:PaymentMandateID:BT-89:warning', PlHints(Inv, D, 'BR-DE-30,BR-DE-31'),
      'direct debit with BR-DE-30 and BR-DE-31');
    CheckEqualsStr('LX-PL-05:AccountingSupplierParty.BankAssignedCreditorIdentifier:BT-90:warning',
      PlHints(Inv, D, 'BR-DE-25-a'), 'direct debit with BR-DE-25-a');
    CheckEqualsStr('', PlHints(Inv, D, 'DE-R-025-1,DE-R-030'), 'direct debit with DE-R-025-1 and DE-R-030');
    CheckEqualsStr('LX-PL-05:AccountingSupplierParty.BankAssignedCreditorIdentifier:BT-90:warning; ' +
      'LX-PL-05:PaymentTypes[0].FinancialAccount:BT-84/BT-91/BT-87:warning', PlHints(Inv, D, 'PEPPOL-EN16931-R061'),
      'direct debit with R061');
    { the creditor identifier as payee identifier with scheme SEPA (UBL,
      not CII) }
    Inv.PayeeParty.IdentifierSchemeID := 'SEPA';
    Inv.PayeeParty.Identifier := 'DE98ZZZ09999999999';
    CheckEqualsStr('LX-PL-05:PaymentMandateID:BT-89:warning; ' +
      'LX-PL-05:PaymentTypes[0].FinancialAccount:BT-84/BT-91/BT-87:warning', PlHints(Inv, D, ''),
      'creditor identifier of the payee');
    CheckEqualsStr('LX-PL-05:PaymentMandateID:BT-89:warning; ' +
      'LX-PL-05:AccountingSupplierParty.BankAssignedCreditorIdentifier:BT-90:warning; ' +
      'LX-PL-05:PaymentTypes[0].FinancialAccount:BT-84/BT-91/BT-87:warning', PlCiiHints(Inv, D),
      'creditor identifier of the payee in CII');
    { BR-DE-25-a in UBL does not cover the creditor }
    Inv.PayeeParty.Identifier := '';
    CheckEqualsStr('LX-PL-05:AccountingSupplierParty.BankAssignedCreditorIdentifier:BT-90:warning',
      PlHints(Inv, D, 'BR-DE-25-a'), 'BR-DE-25-a without the creditor');
    { a payment means code with blanks as other text }
    Pay.PaymentMeansCode := ipmc_NotImplemented;
    Pay.PaymentMeansCodeOther := ' 59 ';
    CheckEqualsStr('LX-PL-05:PaymentMandateID:BT-89:warning; ' +
      'LX-PL-05:AccountingSupplierParty.BankAssignedCreditorIdentifier:BT-90:warning; ' +
      'LX-PL-05:PaymentTypes[0].FinancialAccount:BT-84/BT-91/BT-87:warning', PlHints(Inv, D, ''),
      'direct debit as other code');
    Pay.PaymentMeansCodeOther := '';
    Pay.PaymentMeansCode := ipmc_SEPADirectDebit;
    Inv.PayeeParty.Identifier := '';
    Inv.PayeeParty.IdentifierSchemeID := '';
    Inv.PaymentMandateID := 'M-1';
    Inv.AccountingSupplierParty.BankAssignedCreditorIdentifier := 'DE98ZZZ09999999999';
    Pay.FinancialAccount := 'DE89370400440532013000';
    CheckEqualsStr('', PlHints(Inv, D, ''), 'complete direct debit');
    { a second direct debit: only its own account }
    Pay2 := Inv.PaymentTypes.AddPaymentType;
    Pay2.PaymentMeansCode := ipmc_SEPADirectDebit;
    Inv.PaymentMandateID := '';
    CheckEqualsStr('LX-PL-05:PaymentMandateID:BT-89:warning; ' +
      'LX-PL-05:PaymentTypes[1].FinancialAccount:BT-84/BT-91/BT-87:warning', PlHints(Inv, D, ''),
      'second direct debit');
  finally
    D.Free;
    Inv.Free;
  end;
end;

{ German tax law (LX-DE), only on request: MINIMUM and BASIC WL between
  German parties. }
procedure TestGerman;
var
  Inv: TLandrixInvoice;
  D: TLandrixEInvoiceDiagnostics;
  Target: TLandrixEInvoiceTarget;
  Reported: TStringList;
begin
  Inv := TLandrixInvoice.Create;
  D := TLandrixEInvoiceDiagnostics.Create;
  Reported := TStringList.Create;
  try
    Check(not (eaf_German in LandrixEInvoiceAdvisoryTechnical), 'German tax law is not technical');
    Target := NoTarget;
    Target.Standard := est_FacturX;
    Target.Profile := epr_Minimum;
    Inv.AccountingSupplierParty.Address.CountryCode := 'DE';
    Inv.AccountingCustomerParty.Address.CountryCode := 'DE';
    CheckEquals(1, LandrixEInvoiceAdvise(Inv, Target, [eaf_German], D), 'MINIMUM');
    CheckEqualsInvoiceStr('LX-DE-01', D[0].RuleID, 'MINIMUM: rule');
    CheckEqualsInvoiceStr('BT-24', D[0].Terms, 'MINIMUM: terms');
    Check(D[0].Severity = eds_Warning, 'MINIMUM: warning');
    Check(Pos('MINIMUM is no permitted', string(D[0].Message)) > 0, 'MINIMUM: ' + string(D[0].Message));
    D.Clear;
    CheckEquals(0, LandrixEInvoiceAdvise(Inv, Target, LandrixEInvoiceAdvisoryTechnical, D), 'not by default');
    Target.Profile := epr_BasicWL;
    CheckEquals(1, LandrixEInvoiceAdvise(Inv, Target, [eaf_German], D), 'BASIC WL');
    Check(Pos('BASIC WL is no permitted', string(D[0].Message)) > 0, 'BASIC WL: ' + string(D[0].Message));
    Reported.Add('BR-HYBRID-DE-02');
    CheckEquals(0, LandrixEInvoiceAdvise(Inv, Target, [eaf_German], nil, Reported), 'after BR-HYBRID-DE-02');
    Reported.Clear;
    Reported.Add('BR-HYBRID-DE-01');
    Target.Profile := epr_Minimum;
    CheckEquals(0, LandrixEInvoiceAdvise(Inv, Target, [eaf_German], nil, Reported), 'after BR-HYBRID-DE-01');
    Target.Profile := epr_Basic;
    CheckEquals(0, LandrixEInvoiceAdvise(Inv, Target, [eaf_German], nil), 'BASIC');
    Target.Profile := epr_Minimum;
    Inv.AccountingCustomerParty.Address.CountryCode := 'AT';
    CheckEquals(0, LandrixEInvoiceAdvise(Inv, Target, [eaf_German], nil), 'buyer in Austria');
  finally
    Reported.Free;
    D.Free;
    Inv.Free;
  end;
end;

procedure Register;
begin
  RegisterTest('Advisory.German', TestGerman);
  RegisterTest('Advisory.Fields', TestFields);
  RegisterTest('Advisory.Plausibility', TestPlausibility);
  RegisterTest('Advisory.Characters', TestCharacters);
  RegisterTest('Advisory.Schemes', TestSchemes);
end;

end.
