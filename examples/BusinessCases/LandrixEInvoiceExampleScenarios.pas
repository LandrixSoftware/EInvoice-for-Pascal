{
  EInvoice-for-Pascal

  Copyright (C) 2026 Landrix Software GmbH & Co. KG

  This file is dual-licensed under:
  - GNU GPL version 3 or later; or
  - the Landrix Software Commercial License.

  See LICENSE and COMMERCIAL-LICENSE.md.

  SPDX-License-Identifier: GPL-3.0-or-later OR LicenseRef-Landrix-Commercial
}

{ Example scenarios: procedures that fill a TLandrixInvoice with typical
  business cases (overall example, credit note, reverse charge, small
  business regulation, direct debit, payment card, corrected invoice, title
  line groups and more), and RunAllScenarios, which writes every case for
  the targets it fits (111 output files). BusinessCases.dpr writes them
  through the facade; the test runner compares them with the golden files
  of XRechnung-for-Delphi (one call of ASave per output file, same order,
  same file names, same per-target changes).
  The scenarios are adapted from XRechnung-for-Delphi
  (Samples/XRechnungUnit2TestCases.pas, Tests/FreePascal/XRechnungGenerateExamples.pas).

  Text that ends up in the invoice is kept byte-identical to the original, so
  the output can be compared with the golden files. Non-ASCII characters are
  built at run time from their code points (AUml, UUml, SzLig), amounts from
  scaled integers (Cents, Cur) and fractional Doubles as quotients (Quot):
  no float literals (Delphi 13 Win64 W1066). }

unit LandrixEInvoiceExampleScenarios;

{$I LandrixEInvoice.inc}

interface

uses
  LandrixEInvoiceTypes,
  LandrixEInvoiceInvoice;

type
  { Receives one invoice per output file of the golden file sequence. }
  TScenarioSave = procedure(AInvoice: TLandrixInvoice; const ATarget: TLandrixEInvoiceTarget;
    const AFileName: string; AData: Pointer);

{ Replays the golden file sequence and calls ASave once per output file
  (111 calls). AAttachmentDir is the folder with attachment.pdf/.png/.jpg/.csv
  and ends with a path delimiter. }
procedure RunAllScenarios(ASave: TScenarioSave; AData: Pointer; const AAttachmentDir: string);

{ The single cases, each filling an empty invoice (used one by one by
  examples/Workbench); see the comments at the implementations. }
procedure ScenarioExchangePartTax(AInvoice: TLandrixInvoice);
procedure ScenarioMarginScheme(AInvoice: TLandrixInvoice);
procedure ScenarioOverallExample(AInvoice: TLandrixInvoice; APaymentTerms: Integer;
  AUseAllowancesCharges, ADeductPrepayments, AUseAttachments, AWithDeliveryAddress,
  ACIIRestrictions: Boolean; const AAttachmentDir: string);
procedure ScenarioCreditNote(AInvoice: TLandrixInvoice);
procedure ScenarioIntraCommunitySupplyWithoutVAT(AInvoice: TLandrixInvoice);
procedure ScenarioSmallBusinessRegulation(AInvoice: TLandrixInvoice);
procedure ScenarioCreditCard(AInvoice: TLandrixInvoice);
procedure ScenarioDirectDebit(AInvoice: TLandrixInvoice);
procedure ScenarioLinePeriods(AInvoice: TLandrixInvoice);
procedure ScenarioCollectiveInvoiceDeliveryNotes(AInvoice: TLandrixInvoice);
procedure ScenarioMinimalB2BWithoutLeitwegID(AInvoice: TLandrixInvoice);
procedure ScenarioReverseCharge13b(AInvoice: TLandrixInvoice);
procedure ScenarioOnlinePaymentService(AInvoice: TLandrixInvoice);
procedure ScenarioPriceBaseQuantityAbove1(AInvoice: TLandrixInvoice);
procedure ScenarioCorrectedInvoice(AInvoice: TLandrixInvoice);
procedure ScenarioThirdPartyPaymentBGDEX09(AInvoice: TLandrixInvoice; AUseCharges: Boolean);
procedure ScenarioTitleLineGroups(AInvoice: TLandrixInvoice);
procedure ScenarioTitleLineGroupsExtended(AInvoice: TLandrixInvoice);
procedure ScenarioFourDecimalPlaces(AInvoice: TLandrixInvoice);
procedure ScenarioBaseQuantityDecimals(AInvoice: TLandrixInvoice);
procedure ScenarioPeppolEndpointSchemeID(AInvoice: TLandrixInvoice;
  const ASellerSchemeID, ABuyerSchemeID: TLandrixEInvoiceString);
procedure ScenarioPartyIdentifierGLN(AInvoice: TLandrixInvoice;
  AUseIdentifier, AUseGLN, AUseCreditorID: Boolean);

implementation

uses
  SysUtils,
  LandrixEInvoiceCodes,
  LandrixEInvoiceSpecs;

{ Helpers }

{ Currency from its scaled value (1/10000). }
function Cur(AScaled: Int64): Currency;
begin
  PInt64(@Result)^ := AScaled;
end;

{ Currency from cents. }
function Cents(ACents: Int64): Currency;
begin
  Result := Cur(ACents * 100);
end;

function Quot(A, B: Integer): Double;
begin
  Result := A;
  Result := Result / B;
end;

function AUml: TLandrixEInvoiceString;
begin
  Result := WideChar($00E4);
end;

function UUml: TLandrixEInvoiceString;
begin
  Result := WideChar($00FC);
end;

function SzLig: TLandrixEInvoiceString;
begin
  Result := WideChar($00DF);
end;

function UnitOf(const AUnitOfMeasure: TLandrixEInvoiceString): TLandrixInvoiceUnitCode;
var
  Success: Boolean;
begin
  Result := LandrixEInvoiceUnitCodeFromUnitOfMeasure(AUnitOfMeasure, Success);
end;

{ dd.mm.yyyy, independent of the locale. }
function GermanDate(ADate: TDateTime): TLandrixEInvoiceString;
var
  Y, M, D: Word;
begin
  DecodeDate(ADate, Y, M, D);
  Result := TLandrixEInvoiceString(Format('%.2d.%.2d.%.4d', [D, M, Y]));
end;

{ Rounds a positive amount given in cents to whole cents, half up (as
  SimpleRoundTo to two decimals did in the original). }
function RoundCents(AValueInCents: Double): Currency;
begin
  Result := Cents(Trunc(AValueInCents + 0.5));
end;

{ Fixed dates of the examples. }

function IssueDate: TDateTime;
begin
  Result := EncodeDate(2026, 8, 30);
end;

function DueDate: TDateTime;
begin
  Result := IssueDate + 30;
end;

function PeriodStartDate: TDateTime;
begin
  Result := IssueDate - 30;
end;

function PeriodEndDate: TDateTime;
begin
  Result := IssueDate - 1;
end;

{ Header used by most scenarios: number, fixed dates, commercial invoice, EUR. }
procedure FillHeader(AInvoice: TLandrixInvoice; const ABuyerReference: TLandrixEInvoiceString);
begin
  AInvoice.InvoiceNumber := 'R2020-0815';
  AInvoice.InvoiceIssueDate := IssueDate;
  AInvoice.InvoiceDueDate := DueDate;
  AInvoice.InvoicePeriodStartDate := PeriodStartDate;
  AInvoice.InvoicePeriodEndDate := PeriodEndDate;
  AInvoice.InvoiceTypeCode := itc_CommercialInvoice;
  AInvoice.InvoiceCurrencyCode := 'EUR';
  AInvoice.TaxCurrencyCode := 'EUR';
  AInvoice.BuyerReference := ABuyerReference;
end;

procedure AddNote(AInvoice: TLandrixInvoice; const AContent: TLandrixEInvoiceString;
  ASubjectCode: TLandrixInvoiceNoteSubjectCode);
begin
  with AInvoice.Notes.AddNote do
  begin
    Content := AContent;
    SubjectCode := ASubjectCode;
  end;
end;

procedure AddManagerNote(AInvoice: TLandrixInvoice);
begin
  AddNote(AInvoice, 'Geschaeftsfuehrer Herr Meier - HRB 789', insc_REG);
end;

{ Standard seller (BT-27 ff.), electronic address with scheme EM. }
procedure FillSeller(AInvoice: TLandrixInvoice);
var
  Party: TLandrixInvoiceAccountingParty;
begin
  Party := AInvoice.AccountingSupplierParty;
  Party.Name := '';
  Party.RegistrationName := 'Verkaeufername';
  Party.CompanyID := '';
  Party.Address.StreetName := 'Verkaeuferstrasse 1';
  Party.Address.City := 'Verkaeuferstadt';
  Party.Address.PostalZone := '01234';
  Party.Address.CountryCode := 'DE';
  Party.VATCompanyID := 'DE123456788';
  Party.VATCompanyNumber := '222/111/4444';
  Party.ContactName := 'Meier';
  Party.ContactTelephone := '030 0815';
  Party.ContactElectronicMail := 'meier@company.com';
  Party.ElectronicAddressSellerBuyer := 'antwortaufrechnung@company.com';
  Party.ElectronicAddressSellerBuyerSchemeID := 'EM';
end;

{ Standard buyer (BT-44 ff.); only the VAT ID (EN 16931 allows no tax number
  for the buyer). }
procedure FillBuyer(AInvoice: TLandrixInvoice; AWithContact: Boolean);
var
  Party: TLandrixInvoiceAccountingParty;
begin
  Party := AInvoice.AccountingCustomerParty;
  Party.Name := '';
  Party.RegistrationName := 'Kaeufername';
  Party.CompanyID := 'HRB 456';
  Party.Address.StreetName := 'Kaeuferstrasse 1';
  Party.Address.City := 'Kaeuferstadt';
  Party.Address.PostalZone := '05678';
  Party.Address.CountryCode := 'DE';
  Party.VATCompanyID := 'DE123456788';
  if AWithContact then
  begin
    Party.ContactName := 'Mueller';
    Party.ContactTelephone := '030 1508';
    Party.ContactElectronicMail := 'mueller@kunde.de';
  end;
  Party.ElectronicAddressSellerBuyer := 'antwortaufrechnung@kunde.de';
  Party.ElectronicAddressSellerBuyerSchemeID := 'EM';
end;

{ Minimal parties: no street, no seller VAT ID; the seller then needs a
  registration ID (CompanyID) to give a valid invoice. }
procedure MakeMinimalParties(AInvoice: TLandrixInvoice);
begin
  AInvoice.AccountingSupplierParty.Address.StreetName := '';
  AInvoice.AccountingSupplierParty.VATCompanyID := '';
  if (AInvoice.AccountingSupplierParty.VATCompanyID = '') and
     (AInvoice.AccountingSupplierParty.CompanyID = '') then
    AInvoice.AccountingSupplierParty.CompanyID := LandrixEInvoiceLeitwegIDNonExistent;
  AInvoice.AccountingCustomerParty.Address.StreetName := '';
end;

procedure AddSepaCreditTransfer(AInvoice: TLandrixInvoice; const AIBAN: TLandrixEInvoiceString);
begin
  with AInvoice.PaymentTypes.AddPaymentType do
  begin
    PaymentMeansCode := ipmc_SEPACreditTransfer;
    FinancialAccount := AIBAN; { valid but not existing IBAN }
    FinancialAccountName := 'Fa. XY';
  end;
end;

procedure SetNetPaymentTerms(AInvoice: TLandrixInvoice);
begin
  AInvoice.PaymentTermsType := iptt_Net;
  AInvoice.PaymentTermNetNote := 'Zahlbar bis zum ' + GermanDate(AInvoice.InvoiceDueDate) +
    ' ohne Abzug.';
end;

function AddTaxSubtotal(AInvoice: TLandrixInvoice; ATaxPercent: Double;
  ACategory: TLandrixInvoiceDutyTaxFeeCategoryCode;
  ATaxableAmount, ATaxAmount: Currency): TLandrixInvoiceTaxAmount;
begin
  Result := AInvoice.TaxAmountSubtotals.AddTaxAmount;
  Result.TaxPercent := ATaxPercent;
  Result.TaxCategory := ACategory;
  Result.TaxableAmount := ATaxableAmount;
  Result.TaxAmount := ATaxAmount;
end;

{ Document totals (BG-22) without allowances, charges and prepaid amounts. }
procedure SetTotals(AInvoice: TLandrixInvoice; ATaxAmountTotal, ALineAmount, ATaxExclusiveAmount,
  ATaxInclusiveAmount, APayableAmount: Currency);
begin
  AInvoice.TaxAmountTotal := ATaxAmountTotal;
  AInvoice.LineAmount := ALineAmount;
  AInvoice.TaxExclusiveAmount := ATaxExclusiveAmount;
  AInvoice.TaxInclusiveAmount := ATaxInclusiveAmount;
  AInvoice.AllowanceTotalAmount := 0;
  AInvoice.ChargeTotalAmount := 0;
  AInvoice.PrepaidAmount := 0;
  AInvoice.PayableAmount := APayableAmount;
end;

const
  SmallBusinessReason = 'Keine Ausweisung der Umsatzsteuer, da Kleinunternehmer gemaess Paragraph 19 UStG';
  ReverseChargeReason = 'Hiermit erlaube ich mir folgende Rechnung fuer Bauleistungen zu stellen. ' +
    'Die Umsatzsteuer fuer diese Leistung schuldet nach Paragraph 13b UStG der Leistungsempfaenger.';
  IntraCommunityReason = 'Keine Ausweisung der Umsatzsteuer - innergemeinschaftliche Lieferung EU';
  DefaultIBAN = 'DE75512108001245126199';
  DefaultPaymentID = 'Verwendungszweck der Ueberweisung...R2020-0815';
  LongText3 = 'Langtext Artikel'#13#10'Zeile 2'#13#10'Zeile 3';

{ Scenarios }

{ Exchange part tax (Altteilsteuer): tax on the returned old part. }
procedure ScenarioExchangePartTax(AInvoice: TLandrixInvoice);
begin
  FillHeader(AInvoice, '991-01484-64');
  AddManagerNote(AInvoice);
  AddNote(AInvoice, 'Rechnung enthaelt 100 EUR (Umsatz)Steuer auf Altteile gem. Abschn. 10.5 Abs. 3 UStAE', insc_TXD);
  FillSeller(AInvoice);
  FillBuyer(AInvoice, True);
  AInvoice.DeliveryInformation.ActualDeliveryDate := PeriodEndDate;
  AInvoice.PaymentID := DefaultPaymentID;
  AddSepaCreditTransfer(AInvoice, DefaultIBAN);
  SetNetPaymentTerms(AInvoice);

  with AInvoice.InvoiceLines.AddInvoiceLine do
  begin
    ID := '01';
    Name := 'Austauschteil';
    Description := 'Langtext Austauschteil'#13#10'Zeile 2'#13#10'Zeile 3';
    Quantity := 1;
    UnitCode := UnitOf('Stk');
    SellersItemIdentification := 'A0815';
    TaxPercent := 19;
    TaxCategory := idtfcc_S_StandardRate;
    GrossPriceAmount := 1000;
    NetPriceAmount := 1000;
    LineAmount := 1000;
  end;
  { 10 % tax on the exchange part }
  with AInvoice.InvoiceLines.AddInvoiceLine do
  begin
    ID := '02';
    Name := 'Bemessungsgrundlage und Umsatzsteuer auf Altteil';
    Description := 'Bemessungsgrundlage und Umsatzsteuer auf Altteil';
    Quantity := 1;
    UnitCode := UnitOf('Stk');
    TaxPercent := 19;
    TaxCategory := idtfcc_S_StandardRate;
    GrossPriceAmount := 100;
    NetPriceAmount := 100;
    LineAmount := 100;
  end;
  with AInvoice.InvoiceLines.AddInvoiceLine do
  begin
    ID := '03';
    Name := 'Korrektur/Stornierung Bemessungsgrundlage der Umsatzsteuer auf Altteil';
    Description := 'Korrektur/Stornierung Bemessungsgrundlage der Umsatzsteuer auf Altteil';
    Quantity := -1;
    UnitCode := UnitOf('Stk');
    TaxPercent := 0;
    TaxCategory := idtfcc_Z_ZeroRatedGoods;
    GrossPriceAmount := 100;
    NetPriceAmount := 100;
    LineAmount := -100;
  end;
  with AInvoice.InvoiceLines.AddInvoiceLine do
  begin
    ID := '04';
    Name := 'Montage';
    Description := 'Montage';
    Quantity := 1;
    UnitCode := UnitOf('Std');
    TaxPercent := 19;
    TaxCategory := idtfcc_S_StandardRate;
    GrossPriceAmount := 500;
    NetPriceAmount := 500;
    LineAmount := 500;
  end;

  AddTaxSubtotal(AInvoice, 19, idtfcc_S_StandardRate, 1000 + 100 + 500, 190 + 19 + 95);
  AddTaxSubtotal(AInvoice, 0, idtfcc_Z_ZeroRatedGoods, -100, 0);
  SetTotals(AInvoice, 304, 1000 + 100 - 100 + 500, 1000 + 100 - 100 + 500,
    1000 + 100 - 100 + 500 + 190 + 19 + 95, 1804);
end;

{ Margin scheme (Differenzbesteuerung, section 25a UStG); a proposal, not
  officially validated. }
procedure ScenarioMarginScheme(AInvoice: TLandrixInvoice);
begin
  FillHeader(AInvoice, '991-01484-64');
  AddManagerNote(AInvoice);
  AddNote(AInvoice, 'Das Fahrzeug/der Artikel ist differenzbesteuert nach Paragraph 25a UStG ' +
    'Sonderregelung fuer Gebrauchtgegenstaende', insc_TXD);
  FillSeller(AInvoice);
  FillBuyer(AInvoice, True);
  AInvoice.DeliveryInformation.ActualDeliveryDate := PeriodEndDate;
  AInvoice.PaymentID := DefaultPaymentID;
  AddSepaCreditTransfer(AInvoice, DefaultIBAN);
  SetNetPaymentTerms(AInvoice);

  with AInvoice.InvoiceLines.AddInvoiceLine do
  begin
    ID := '01';
    Name := 'Fahrzeug mit Differenzbesteuerung';
    Description := 'Fahrzeug mit Differenzbesteuerung'#13#10'Einkauf 4000,00 EUR'#13#10 +
      'Marge 840,34 EUR'#13#10 +
      'Verkauf Brutto 5000,00 EUR'#13#10 +
      'Enthaltene MwSt. 159,66';
    Quantity := 1;
    UnitCode := UnitOf('Stk');
    TaxPercent := 0;
    TaxCategory := idtfcc_E_ExemptFromTax;
    TaxExemptionReason := 'Differenzbesteuerung'; { must equal the subtotal's reason in ZUGFeRD Extended }
    GrossPriceAmount := 5000;
    NetPriceAmount := 5000;
    LineAmount := 5000;
  end;

  AddTaxSubtotal(AInvoice, 0, idtfcc_E_ExemptFromTax, 5000, 0).TaxExemptionReason := 'Differenzbesteuerung';
  SetTotals(AInvoice, 0, 5000, 5000, 5000, 5000);
end;

{ Overall example with all common elements.
  APaymentTerms: 0 none, 1 net, 2/3/4 one to three cash discounts.
  ACIIRestrictions is True for all CII outputs (XRechnung CII and ZUGFeRD):
  the EN 16931 binding to CII D16B has restrictions that UBL does not have. }
procedure ScenarioOverallExample(AInvoice: TLandrixInvoice; APaymentTerms: Integer;
  AUseAllowancesCharges, ADeductPrepayments, AUseAttachments, AWithDeliveryAddress,
  ACIIRestrictions: Boolean; const AAttachmentDir: string);
var
  Party: TLandrixInvoiceAccountingParty;
begin
  AInvoice.InvoiceNumber := 'R2020-0815';
  AInvoice.InvoiceIssueDate := IssueDate;
  AInvoice.InvoiceDueDate := DueDate;
  AInvoice.InvoicePeriodStartDate := PeriodStartDate;
  AInvoice.InvoicePeriodEndDate := PeriodEndDate;
  AInvoice.InvoiceTypeCode := itc_CommercialInvoice;
  AInvoice.InvoiceCurrencyCode := 'EUR';
  AInvoice.TaxCurrencyCode := 'EUR';
  AInvoice.BuyerReference := '991-01484-64';
  AddNote(AInvoice, 'Gesch' + AUml + 'ftsf' + UUml + 'hrer Herr Meier - HRB 789', insc_REG);
  AInvoice.PurchaseOrderReference := 'B0815';
  AInvoice.SellerOrderReference := 'A0815';
  AInvoice.ProjectReference := 'PR456789';
  AInvoice.ReceiptDocumentReference := 'RDR456789';
  AInvoice.ContractDocumentReference := 'V876543210';
  AInvoice.DeliveryReceiptNumber := 'Versandanzeige123'; { BT-16 is the despatch advice, not the delivery note }
  AInvoice.DeliveryReceiptDate := AInvoice.InvoiceIssueDate - 5;
  AInvoice.DeliveryReceiptNumberExtended := 'Lieferschein123'; { ZUGFeRD Extended only }
  AInvoice.DeliveryReceiptDateExtended := AInvoice.InvoiceIssueDate - 5;
  AInvoice.BuyerAccountingReference := '1234';

  Party := AInvoice.AccountingSupplierParty;
  Party.Name := 'Verk' + AUml + 'ufername'; { if different from RegistrationName }
  Party.RegistrationName := 'Verk' + AUml + 'uferRegistrationName';
  Party.CompanyID := '';
  Party.Address.StreetName := 'Verk' + AUml + 'ufer' + 'stra' + SzLig + 'e 1';
  Party.Address.AdditionalStreetName := 'Hinterhaus';
  Party.Address.City := 'Verk' + AUml + 'uferstadt';
  Party.Address.PostalZone := '01234';
  Party.Address.CountrySubentity := 'Sachsen';
  Party.Address.AddressLine := 'Gate 64';
  Party.Address.CountryCode := 'DE';
  Party.VATCompanyID := 'DE123456788';
  Party.VATCompanyNumber := '222/111/4444';
  Party.ContactName := 'Meier';
  Party.ContactTelephone := '030 0815';
  Party.ContactElectronicMail := 'meier@company.com';
  Party.ElectronicAddressSellerBuyer := 'antwortaufrechnung@company.com';
  Party.ElectronicAddressSellerBuyerSchemeID := 'EM';

  Party := AInvoice.AccountingCustomerParty;
  Party.Name := '';
  Party.RegistrationName := 'K' + AUml + 'ufername';
  Party.CompanyID := 'HRB 456';
  Party.Address.StreetName := 'K' + AUml + 'ufer' + 'stra' + SzLig + 'e 1';
  Party.Address.City := 'K' + AUml + 'uferstadt';
  Party.Address.PostalZone := '05678';
  Party.Address.CountryCode := 'DE';
  Party.VATCompanyID := 'DE123456788';
  Party.ContactName := 'M' + UUml + 'ller';
  Party.ContactTelephone := '030 1508';
  Party.ContactElectronicMail := 'mueller@kunde.de';
  Party.ElectronicAddressSellerBuyer := 'antwortaufrechnung@kunde.de';
  Party.ElectronicAddressSellerBuyerSchemeID := 'EM';

  { BG-13 delivery address, only when different from the buyer address }
  if AWithDeliveryAddress then
  begin
    AInvoice.DeliveryInformation.Name := 'Firma die es bekommt';
    AInvoice.DeliveryInformation.LocationIdentifier := '4005998000007';
    AInvoice.DeliveryInformation.Address.StreetName := 'Liefer' + 'stra' + SzLig + 'e 1';
    AInvoice.DeliveryInformation.Address.City := 'Lieferstadt';
    AInvoice.DeliveryInformation.Address.PostalZone := '05678';
    AInvoice.DeliveryInformation.Address.CountryCode := 'DE';
  end;

  AInvoice.DeliveryInformation.ActualDeliveryDate := PeriodEndDate;

  { two payment means }
  AInvoice.PaymentID := 'Verwendungszweck R2020-0815';
  AddSepaCreditTransfer(AInvoice, DefaultIBAN);
  AddSepaCreditTransfer(AInvoice, 'DE02100500000054540402');

  case APaymentTerms of
    1:
      SetNetPaymentTerms(AInvoice);
    2:
      begin
        AInvoice.PaymentTermsType := iptt_CashDiscount1;
        AInvoice.PaymentTermCashDiscount1Days := 7;
        AInvoice.PaymentTermCashDiscount1Percent := Quot(425, 100);
        AInvoice.PaymentTermCashDiscount1Base := 226; { required in ZUGFeRD/Factur-X }
        { ZUGFeRD/Factur-X only: must equal base * percent / 100; base *
          percent is the amount in cents }
        AInvoice.PaymentTermCashDiscount1ActualAmount := RoundCents(
          AInvoice.PaymentTermCashDiscount1Base * AInvoice.PaymentTermCashDiscount1Percent);
      end;
    3:
      begin
        AInvoice.PaymentTermsType := iptt_CashDiscount2;
        AInvoice.PaymentTermCashDiscount1Days := 7;
        AInvoice.PaymentTermCashDiscount1Percent := Quot(425, 100);
        AInvoice.PaymentTermCashDiscount1Base := 0;
        AInvoice.PaymentTermCashDiscount2Days := 14;
        AInvoice.PaymentTermCashDiscount2Percent := 3;
        AInvoice.PaymentTermCashDiscount2Base := 0;
      end;
    4:
      begin
        AInvoice.PaymentTermsType := iptt_CashDiscount3;
        AInvoice.PaymentTermCashDiscount1Days := 7;
        AInvoice.PaymentTermCashDiscount1Percent := Quot(425, 100);
        AInvoice.PaymentTermCashDiscount1Base := 0;
        AInvoice.PaymentTermCashDiscount2Days := 14;
        AInvoice.PaymentTermCashDiscount2Percent := 3;
        AInvoice.PaymentTermCashDiscount2Base := 0;
        AInvoice.PaymentTermCashDiscount3Days := 15;
        AInvoice.PaymentTermCashDiscount3Percent := 2;
        AInvoice.PaymentTermCashDiscount3Base := 0;
      end;
  else
    AInvoice.PaymentTermsType := iptt_None;
  end;

  { Counter-example for BT-17: an entry without ID is skipped when writing,
    the first entry with ID is written, every further one is dropped (BT-17
    is allowed once: UBL cac:OriginatorDocumentReference 0..1, CII-SR-457). }
  with AInvoice.Attachments.AddAttachment(iat_application_None) do
  begin
    ID := '';
    TypeCode := iatc_50;
  end;
  with AInvoice.Attachments.AddAttachment(iat_application_None) do
  begin
    ID := 'BT-17 12345';
    TypeCode := iatc_50; { tender or lot reference }
  end;
  with AInvoice.Attachments.AddAttachment(iat_application_None) do
  begin
    ID := 'BT-17 67890';
    TypeCode := iatc_50;
  end;
  { Same for BT-18: only the first entry with ID is written (UBL-SR-04, CII-SR-458);
    Factur-X EXTENDED writes both. }
  with AInvoice.Attachments.AddAttachment(iat_application_None) do
  begin
    ID := 'BT-18 12345';
    TypeCode := iatc_130; { invoiced object identifier }
  end;
  with AInvoice.Attachments.AddAttachment(iat_application_None) do
  begin
    ID := 'BT-18 67890';
    TypeCode := iatc_130;
  end;

  { File names of attached documents must be unique within the invoice (case
    insensitive, including the extension). }
  if AUseAttachments then
  begin
    with AInvoice.Attachments.AddAttachment(iat_application_pdf) do
    begin
      ID := 'attachment.pdf';
      DocumentDescription := 'Eine PDF';
      Filename := 'attachment.pdf';
      EmbedDataFromFile(AAttachmentDir + 'attachment.pdf');
    end;
    with AInvoice.Attachments.AddAttachment(iat_image_png) do
    begin
      ID := 'attachment.png';
      Filename := 'attachment.png';
      EmbedDataFromFile(AAttachmentDir + 'attachment.png');
    end;
    with AInvoice.Attachments.AddAttachment(iat_image_jpeg) do
    begin
      ID := 'attachment.jpg';
      Filename := 'attachment.jpg';
      EmbedDataFromFile(AAttachmentDir + 'attachment.jpg');
    end;
    with AInvoice.Attachments.AddAttachment(iat_text_csv) do
    begin
      ID := 'attachment.csv';
      Filename := 'attachment.csv';
      EmbedDataFromFile(AAttachmentDir + 'attachment.csv');
    end;
  end;

  with AInvoice.InvoiceLines.AddInvoiceLine do
  begin
    ID := '001';
    GlobalID_EAN_GTIN := '4006381333931';
    ObjectIdentifier := '4500123456'; { BT-128 }
    ObjectIdentifierSchemeID := 'ON'; { BT-128-1, UNTDID 1153: buyer's order number }
    Name := 'Kurzinfo Artikel 1';
    Description := LongText3;
    Quantity := 2;
    UnitCode := UnitOf('Stk');
    SellersItemIdentification := 'A0815';
    BuyersItemIdentification := 'B0815';
    BuyerAccountingReference := '6171175.1';
    OrderNumber := '0815'; { BT-X-21, ZUGFeRD/Factur-X only }
    OrderLineReference := '6171175.1';
    TaxPercent := 7;
    TaxCategory := idtfcc_S_StandardRate;
    GrossPriceAmount := 50;
    NetPriceAmount := 50;
    LineAmount := 100;

    with ItemAttributes.AddItemAttribute do
    begin
      Name := 'Key1';
      Value := 'xyz';
    end;
    with ItemAttributes.AddItemAttribute do
    begin
      Name := 'Key2';
      Value := '123';
    end;
    { BT-158 item classification, e.g. freight item }
    with ItemClassifications.AddItemClassification do
    begin
      ClassCode := 'FRACHT';
      ListID := 'GB'; { BT-158-1, required }
    end;
    OriginTradeCountry := 'DE';
  end;
  with AInvoice.InvoiceLines.AddInvoiceLine do
  begin
    ID := '002';
    Name := 'Kurzinfo Artikel 2';
    Description := 'Langtext Artikel 2'#13#10'Zeile 2'#13#10'Zeile 3';
    Quantity := 1;
    UnitCode := UnitOf('Stk');
    SellersItemIdentification := 'A0816';
    TaxPercent := 19;
    TaxCategory := idtfcc_S_StandardRate;

    { discount on the gross price }
    if AUseAllowancesCharges then
    begin
      GrossPriceAmount := 150;
      DiscountOnTheGrossPrice := 50;
    end else
    begin
      GrossPriceAmount := 100;
      DiscountOnTheGrossPrice := 0;
    end;
    NetPriceAmount := 100;
    LineAmount := 100;
    { BT-158 with scheme version; ClassificationName is written in
      ZUGFeRD/Factur-X EXTENDED only }
    with ItemClassifications.AddItemClassification do
    begin
      ClassCode := '23456789123';
      ListID := 'HS'; { BT-158-1 Harmonized System }
      ListVersionID := '2022'; { BT-158-2 }
      ClassificationName := 'Zolltarifnummer';
    end;
    OriginTradeCountry := 'DE';

    { line allowances }
    if AUseAllowancesCharges then
    begin
      with AllowanceCharges.AddAllowanceCharge do
      begin
        ChargeIndicator := False;
        ReasonCodeAllowance := iacic_Discount;
        BaseAmount := 50;
        MultiplierFactorNumeric := 5; { 5 percent of 50 EUR }
        Amount := Cents(250);
        LineAmount := LineAmount - Amount;
      end;
      with AllowanceCharges.AddAllowanceCharge do
      begin
        ChargeIndicator := False;
        ReasonCodeAllowance := iacic_Discount;
        BaseAmount := 0;
        MultiplierFactorNumeric := 0;
        Amount := Cents(250);
        LineAmount := LineAmount - Amount;
      end;
    end;
  end;

  { document level allowances and charges }
  if AUseAllowancesCharges then
  begin
    with AInvoice.AllowanceCharges.AddAllowanceCharge do
    begin
      ChargeIndicator := False;
      ReasonCodeAllowance := iacic_Discount;
      Reason := 'Nachlass 1';
      BaseAmount := 50;
      MultiplierFactorNumeric := 10; { 10 percent of 50 EUR }
      Amount := 5;
      TaxPercent := 19;
      TaxCategory := idtfcc_S_StandardRate;
    end;
    with AInvoice.AllowanceCharges.AddAllowanceCharge do
    begin
      ChargeIndicator := False;
      ReasonCodeAllowance := iacic_Discount;
      Reason := 'Nachlass 2 ohne Angabe von Basisbetrag und Nachlassprozente.';
      BaseAmount := 0;
      MultiplierFactorNumeric := 0;
      Amount := 5;
      TaxPercent := 19;
      TaxCategory := idtfcc_S_StandardRate;
    end;
    with AInvoice.AllowanceCharges.AddAllowanceCharge do
    begin
      ChargeIndicator := True;
      ReasonCodeCharge := issdc_AAA_Telecommunication;
      Reason := 'Zuschlag f' + UUml + 'r Kommunikation';
      BaseAmount := 10;
      MultiplierFactorNumeric := 10; { 10 percent of 10 EUR }
      Amount := 1;
      TaxPercent := 19;
      TaxCategory := idtfcc_S_StandardRate;
    end;
    with AInvoice.AllowanceCharges.AddAllowanceCharge do
    begin
      ChargeIndicator := False;
      ReasonCodeAllowance := iacic_Discount;
      Reason := 'Nachlass mit Nachlassprozente 4 Nachkommastellen.';
      BaseAmount := Cents(417445);
      MultiplierFactorNumeric := Quot(3255, 10000);
      Amount := Cents(1359);
      TaxPercent := 19;
      TaxCategory := idtfcc_S_StandardRate;
    end;
  end;

  AddTaxSubtotal(AInvoice, 7, idtfcc_S_StandardRate, 100, 7);
  AddTaxSubtotal(AInvoice, 19, idtfcc_S_StandardRate, 100, 19);
  SetTotals(AInvoice, 26, 200, 200, 226, 226);

  { adjust the totals for the allowances and charges }
  if AUseAllowancesCharges then
  begin
    AInvoice.LineAmount := AInvoice.LineAmount - 5; { line allowances }
    AInvoice.AllowanceTotalAmount := 5 + 5 + Cents(1359);
    AInvoice.ChargeTotalAmount := 1;
    AInvoice.TaxAmountSubtotals[1].TaxableAmount := AInvoice.TaxAmountSubtotals[1].TaxableAmount -
      5 - 5 - 5 + 1 - Cents(1359);
    AInvoice.TaxAmountSubtotals[1].TaxAmount := AInvoice.TaxAmountSubtotals[1].TaxAmount -
      Cents(95) - Cents(95) - Cents(95) + Cents(19) - Cents(258);
    AInvoice.TaxAmountTotal := AInvoice.TaxAmountTotal -
      Cents(95) - Cents(95) - Cents(95) + Cents(19) - Cents(258);
    AInvoice.TaxExclusiveAmount := AInvoice.TaxExclusiveAmount - AInvoice.AllowanceTotalAmount +
      AInvoice.ChargeTotalAmount - 5;
    AInvoice.TaxInclusiveAmount := AInvoice.TaxInclusiveAmount - 5 - Cents(95) - 5 - Cents(95) -
      5 - Cents(95) + 1 + Cents(19) - Cents(1359) - Cents(258);
    AInvoice.PayableAmount := AInvoice.TaxInclusiveAmount;
  end;

  { deduct prepayment invoices }
  if ADeductPrepayments then
  begin
    { CII (ZUGFeRD) allows at most one reference here }
    with AInvoice.PrecedingInvoiceReferences.AddPrecedingInvoiceReference do
    begin
      ID := 'R2020-0001';
      IssueDate := EncodeDate(2024, 8, 27);
    end;
    if not ACIIRestrictions then
      with AInvoice.PrecedingInvoiceReferences.AddPrecedingInvoiceReference do
      begin
        ID := 'R2020-0002';
        IssueDate := EncodeDate(2024, 10, 16);
      end;
    AInvoice.PrepaidAmount := 100;
    AInvoice.PayableAmount := AInvoice.PayableAmount - AInvoice.PrepaidAmount;
  end;
end;

{ Credit note without due date. }
procedure ScenarioCreditNote(AInvoice: TLandrixInvoice);
begin
  AInvoice.InvoiceNumber := 'R2020-0815';
  AInvoice.InvoiceIssueDate := IssueDate;
  AInvoice.InvoiceDueDate := 0; { no due date }
  AInvoice.InvoicePeriodStartDate := PeriodStartDate;
  AInvoice.InvoicePeriodEndDate := PeriodEndDate;
  AInvoice.InvoiceTypeCode := itc_CreditNote;
  { BT-11 is written as cac:AdditionalDocumentReference with DocumentTypeCode 50 in the credit note }
  AInvoice.ProjectReference := 'PR-123';
  with AInvoice.Attachments.AddAttachment(iat_application_None) do
  begin
    ID := 'BT-17 12345';
    TypeCode := iatc_50; { follows cac:AdditionalDocumentReference in the credit note }
  end;
  AInvoice.InvoiceCurrencyCode := 'EUR';
  AInvoice.Notes.AddNote.Content := 'Notiz zur Gutschrift';
  AInvoice.TaxCurrencyCode := 'EUR';
  AInvoice.BuyerReference := '991-01484-64';
  AddManagerNote(AInvoice);

  FillSeller(AInvoice);
  AInvoice.AccountingSupplierParty.AdditionalLegalInformationSeller := SmallBusinessReason;
  FillBuyer(AInvoice, True);
  AInvoice.DeliveryInformation.ActualDeliveryDate := PeriodEndDate;
  AInvoice.PaymentID := DefaultPaymentID;
  AddSepaCreditTransfer(AInvoice, DefaultIBAN);
  SetNetPaymentTerms(AInvoice);

  with AInvoice.InvoiceLines.AddInvoiceLine do
  begin
    ID := '01';
    ObjectIdentifier := 'OBJ-4711'; { BT-128 without scheme }
    Name := 'Provision';
    Description := 'Provision';
    Quantity := 1;
    UnitCode := UnitOf('Stk');
    TaxPercent := 0;
    TaxCategory := idtfcc_E_ExemptFromTax;
    TaxExemptionReason := SmallBusinessReason;
    GrossPriceAmount := 500;
    NetPriceAmount := 500;
    LineAmount := 500;
  end;

  AddTaxSubtotal(AInvoice, 0, idtfcc_E_ExemptFromTax, 500, 0).TaxExemptionReason := SmallBusinessReason;
  SetTotals(AInvoice, 0, 500, 500, 500, 500);
end;

{ Intra-community supply within the EU without VAT (category K). }
procedure ScenarioIntraCommunitySupplyWithoutVAT(AInvoice: TLandrixInvoice);
var
  Party: TLandrixInvoiceAccountingParty;
begin
  FillHeader(AInvoice, LandrixEInvoiceLeitwegIDNonExistent);
  AddManagerNote(AInvoice);
  FillSeller(AInvoice);
  AInvoice.AccountingSupplierParty.AdditionalLegalInformationSeller := SmallBusinessReason;

  Party := AInvoice.AccountingCustomerParty;
  Party.Name := '';
  Party.RegistrationName := 'Kaeufername';
  Party.CompanyID := 'HRB 456';
  Party.Address.StreetName := 'Kaeuferstrasse 1';
  Party.Address.City := 'Kaeuferstadt';
  Party.Address.PostalZone := '05678';
  Party.Address.CountryCode := 'AT';
  Party.VATCompanyID := 'ATU12345675';
  Party.ContactName := 'Mueller';
  Party.ContactTelephone := '030 1508';
  Party.ContactElectronicMail := 'mueller@kunde.at';
  Party.ElectronicAddressSellerBuyer := 'antwortaufrechnung@kunde.at';
  Party.ElectronicAddressSellerBuyerSchemeID := 'EM';

  AInvoice.DeliveryInformation.Name := 'Firma die es bekommt';
  AInvoice.DeliveryInformation.Address.StreetName := 'Lieferstrasse 1';
  AInvoice.DeliveryInformation.Address.City := 'Lieferstadt';
  AInvoice.DeliveryInformation.Address.PostalZone := '05678';
  AInvoice.DeliveryInformation.Address.CountryCode := 'AT';
  AInvoice.DeliveryInformation.ActualDeliveryDate := PeriodEndDate;

  AInvoice.PaymentID := DefaultPaymentID;
  AddSepaCreditTransfer(AInvoice, DefaultIBAN);
  SetNetPaymentTerms(AInvoice);

  with AInvoice.InvoiceLines.AddInvoiceLine do
  begin
    ID := '01';
    Name := 'Homepage erstellt';
    Description := 'Homepage erstellt';
    Quantity := 1;
    UnitCode := UnitOf('Stk');
    TaxPercent := 0;
    TaxCategory := idtfcc_K_VATExemptForEEAIntracommunitySupplyOfGoodsAndServices;
    TaxExemptionReason := IntraCommunityReason;
    GrossPriceAmount := 5000;
    NetPriceAmount := 5000;
    LineAmount := 5000;
  end;

  with AddTaxSubtotal(AInvoice, 0, idtfcc_K_VATExemptForEEAIntracommunitySupplyOfGoodsAndServices, 5000, 0) do
  begin
    TaxExemptionReason := IntraCommunityReason;
    TaxExemptionReasonCode := 'VATEX-EU-IC'; { BT-121, optional besides the text (BR-IC-10) }
  end;
  SetTotals(AInvoice, 0, 5000, 5000, 5000, 5000);
end;

{ Small business regulation (section 19 UStG). }
procedure ScenarioSmallBusinessRegulation(AInvoice: TLandrixInvoice);
begin
  FillHeader(AInvoice, '991-01484-64');
  AddNote(AInvoice, 'Kleinunternehmer Herr Meier', insc_REG);
  FillSeller(AInvoice);
  AInvoice.AccountingSupplierParty.CompanyID := 'non-existent';
  AInvoice.AccountingSupplierParty.VATCompanyID := '';
  AInvoice.AccountingSupplierParty.AdditionalLegalInformationSeller := SmallBusinessReason;
  FillBuyer(AInvoice, True);
  AInvoice.DeliveryInformation.ActualDeliveryDate := PeriodEndDate;
  AInvoice.PaymentID := DefaultPaymentID;
  AddSepaCreditTransfer(AInvoice, DefaultIBAN);
  SetNetPaymentTerms(AInvoice);

  with AInvoice.InvoiceLines.AddInvoiceLine do
  begin
    ID := '01';
    Name := 'Homepage erstellt';
    Description := 'Homepage erstellt';
    Quantity := 1;
    UnitCode := UnitOf('Stk');
    TaxPercent := 0;
    TaxCategory := idtfcc_E_ExemptFromTax;
    TaxExemptionReason := SmallBusinessReason; { must equal the subtotal's reason in ZUGFeRD Extended }
    GrossPriceAmount := 5000;
    NetPriceAmount := 5000;
    LineAmount := 5000;
  end;

  AddTaxSubtotal(AInvoice, 0, idtfcc_E_ExemptFromTax, 5000, 0).TaxExemptionReason := SmallBusinessReason;
  SetTotals(AInvoice, 0, 5000, 5000, 5000, 5000);
end;

{ Single line of 360 EUR at 19 %, used by several payment scenarios. }
procedure AddStandardLine(AInvoice: TLandrixInvoice);
begin
  with AInvoice.InvoiceLines.AddInvoiceLine do
  begin
    ID := '01';
    Name := 'Kurzinfo Artikel 1';
    Description := LongText3;
    Quantity := 1;
    UnitCode := UnitOf('Stk');
    TaxPercent := 19;
    TaxCategory := idtfcc_S_StandardRate;
    GrossPriceAmount := 360;
    NetPriceAmount := 360;
    LineAmount := 360;
  end;
end;

procedure SetStandardTotals(AInvoice: TLandrixInvoice);
begin
  AddTaxSubtotal(AInvoice, 19, idtfcc_S_StandardRate, 360, Cents(6840));
  SetTotals(AInvoice, Cents(6840), 360, 360, Cents(42840), Cents(42840));
end;

{ Payment by credit card. }
procedure ScenarioCreditCard(AInvoice: TLandrixInvoice);
begin
  FillHeader(AInvoice, LandrixEInvoiceLeitwegIDNonExistent);
  AddManagerNote(AInvoice);
  FillSeller(AInvoice);
  FillBuyer(AInvoice, False);
  AInvoice.DeliveryInformation.ActualDeliveryDate := PeriodEndDate;

  AInvoice.PaymentID := 'Verwendungszweck ...R2020-0815';
  with AInvoice.PaymentTypes.AddPaymentType do
  begin
    PaymentMeansCode := ipmc_CreditCard;
    { Card security standards: never the full card number (BT-87), at most
      the last 6 digits. }
    FinancialAccount := '454556';
    FinancialAccountName := 'Robert Mustermann'; { card holder }
  end;
  AInvoice.PaymentTermsType := iptt_None;

  AddStandardLine(AInvoice);
  SetStandardTotals(AInvoice);
end;

{ SEPA direct debit with mandate and creditor ID. }
procedure ScenarioDirectDebit(AInvoice: TLandrixInvoice);
begin
  FillHeader(AInvoice, LandrixEInvoiceLeitwegIDNonExistent);
  AddManagerNote(AInvoice);
  FillSeller(AInvoice);
  FillBuyer(AInvoice, False);
  AInvoice.DeliveryInformation.ActualDeliveryDate := PeriodEndDate;

  AInvoice.PaymentID := DefaultPaymentID;
  with AInvoice.PaymentTypes.AddPaymentType do
  begin
    PaymentMeansCode := ipmc_SEPADirectDebit;
    FinancialAccount := DefaultIBAN;
  end;
  AInvoice.PaymentMandateID := 'MANDATID';
  AInvoice.AccountingSupplierParty.BankAssignedCreditorIdentifier := '111111';
  AInvoice.PaymentTermsType := iptt_None;

  AddStandardLine(AInvoice);
  SetStandardTotals(AInvoice);
end;

{ Invoice period per line; the document period must cover all line periods. }
procedure ScenarioLinePeriods(AInvoice: TLandrixInvoice);
begin
  FillHeader(AInvoice, LandrixEInvoiceLeitwegIDNonExistent);
  AInvoice.InvoiceIssueDate := EncodeDate(2024, 10, 1);
  AInvoice.InvoiceDueDate := EncodeDate(2024, 11, 1);
  AInvoice.InvoicePeriodStartDate := EncodeDate(2024, 10, 1);
  AInvoice.InvoicePeriodEndDate := EncodeDate(2025, 9, 30);
  AddManagerNote(AInvoice);
  FillSeller(AInvoice);
  FillBuyer(AInvoice, False);
  AInvoice.DeliveryInformation.ActualDeliveryDate := AInvoice.InvoicePeriodEndDate;
  AInvoice.PaymentTypes.AddPaymentType.PaymentMeansCode := ipmc_InstrumentNotDefined;
  AInvoice.PaymentTermsType := iptt_None;

  with AInvoice.InvoiceLines.AddInvoiceLine do
  begin
    ID := '01';
    Name := 'Kurzinfo Artikel 1';
    Quantity := 1;
    UnitCode := UnitOf('Stk');
    TaxPercent := 19;
    TaxCategory := idtfcc_S_StandardRate;
    GrossPriceAmount := 360;
    NetPriceAmount := 360;
    LineAmount := 360;
    InvoiceLinePeriodStartDate := EncodeDate(2024, 10, 2);
    InvoiceLinePeriodEndDate := EncodeDate(2025, 9, 29);
  end;
  with AInvoice.InvoiceLines.AddInvoiceLine do
  begin
    ID := '02';
    Name := 'Kurzinfo Artikel 2';
    Quantity := 1;
    UnitCode := UnitOf('Stk');
    TaxPercent := 19;
    TaxCategory := idtfcc_S_StandardRate;
    GrossPriceAmount := 360;
    NetPriceAmount := 360;
    LineAmount := 360;
    InvoiceLinePeriodStartDate := EncodeDate(2024, 10, 2);
    InvoiceLinePeriodEndDate := EncodeDate(2024, 12, 30);
  end;

  AddTaxSubtotal(AInvoice, 19, idtfcc_S_StandardRate, 720, Cents(13680));
  SetTotals(AInvoice, Cents(13680), 720, 720, Cents(85680), Cents(85680));
end;

{ Collective invoice over several delivery notes: delivery note number and
  date and the delivery date per line. ZUGFeRD/Factur-X EXTENDED only; the
  other profiles ignore these line fields when writing. }
procedure ScenarioCollectiveInvoiceDeliveryNotes(AInvoice: TLandrixInvoice);
begin
  FillHeader(AInvoice, LandrixEInvoiceLeitwegIDNonExistent);
  AInvoice.InvoiceNumber := 'R2026-0930';
  AInvoice.InvoiceIssueDate := EncodeDate(2026, 9, 30);
  AInvoice.InvoiceDueDate := EncodeDate(2026, 10, 30);
  AInvoice.InvoicePeriodStartDate := EncodeDate(2026, 9, 1);
  AInvoice.InvoicePeriodEndDate := EncodeDate(2026, 9, 30);
  AddManagerNote(AInvoice);
  FillSeller(AInvoice);
  FillBuyer(AInvoice, False);

  { document level delivery address (BG-13); without a delivery date
    (BT-72) BR-FX-EN-04 requires at least the country (BT-80) }
  AInvoice.DeliveryInformation.Name := 'Kaeufername Werk 2';
  AInvoice.DeliveryInformation.Address.StreetName := 'Werkstrasse 5';
  AInvoice.DeliveryInformation.Address.City := 'Kaeuferstadt';
  AInvoice.DeliveryInformation.Address.PostalZone := '05679';
  AInvoice.DeliveryInformation.Address.CountryCode := 'DE';

  AInvoice.PaymentTypes.AddPaymentType.PaymentMeansCode := ipmc_InstrumentNotDefined;
  AInvoice.PaymentTermsType := iptt_None;

  with AInvoice.InvoiceLines.AddInvoiceLine do
  begin
    ID := '1';
    Name := 'Hydraulikoel HLP 46';
    Quantity := 200;
    UnitCode := iuc_litre;
    TaxPercent := 19;
    TaxCategory := idtfcc_S_StandardRate;
    GrossPriceAmount := Cents(1550);
    NetPriceAmount := Cents(1550);
    LineAmount := 3100;
    DeliveryNoteNumber := 'LS-2026-88741'; { BT-X-92 }
    DeliveryNoteLineID := '1'; { BT-X-93 }
    DeliveryNoteDate := EncodeDate(2026, 9, 12); { BT-X-94 }
    ActualDeliveryDate := EncodeDate(2026, 9, 12);
  end;
  with AInvoice.InvoiceLines.AddInvoiceLine do
  begin
    ID := '2';
    Name := 'Schmierfett 400 g';
    Quantity := 10;
    UnitCode := UnitOf('Stk');
    TaxPercent := 19;
    TaxCategory := idtfcc_S_StandardRate;
    GrossPriceAmount := Cents(2490);
    NetPriceAmount := Cents(2490);
    LineAmount := 249;
    { second delivery note, delivered later }
    DeliveryNoteNumber := 'LS-2026-88902';
    DeliveryNoteLineID := '1';
    DeliveryNoteDate := EncodeDate(2026, 9, 19);
    ActualDeliveryDate := EncodeDate(2026, 9, 22);
  end;
  with AInvoice.InvoiceLines.AddInvoiceLine do
  begin
    ID := '3';
    Name := 'Oelfilter';
    Quantity := 5;
    UnitCode := UnitOf('Stk');
    TaxPercent := 19;
    TaxCategory := idtfcc_S_StandardRate;
    GrossPriceAmount := 12;
    NetPriceAmount := 12;
    LineAmount := 60;
    { same delivery note as line 2 }
    DeliveryNoteNumber := 'LS-2026-88902';
    DeliveryNoteLineID := '2';
    DeliveryNoteDate := EncodeDate(2026, 9, 19);
    ActualDeliveryDate := EncodeDate(2026, 9, 22);
  end;

  AddTaxSubtotal(AInvoice, 19, idtfcc_S_StandardRate, 3409, Cents(64771));
  SetTotals(AInvoice, Cents(64771), 3409, 3409, Cents(405671), Cents(405671));
end;

{ Minimal B2B example without Leitweg-ID. }
procedure ScenarioMinimalB2BWithoutLeitwegID(AInvoice: TLandrixInvoice);
begin
  FillHeader(AInvoice, LandrixEInvoiceLeitwegIDNonExistent);
  AddManagerNote(AInvoice);
  FillSeller(AInvoice);
  FillBuyer(AInvoice, False);
  MakeMinimalParties(AInvoice);
  AInvoice.DeliveryInformation.ActualDeliveryDate := PeriodEndDate;
  AInvoice.PaymentTypes.AddPaymentType.PaymentMeansCode := ipmc_InstrumentNotDefined;
  AInvoice.PaymentTermsType := iptt_None;

  AddStandardLine(AInvoice);
  SetStandardTotals(AInvoice);
end;

{ Reverse charge for construction services (section 13b UStG). }
procedure ScenarioReverseCharge13b(AInvoice: TLandrixInvoice);
begin
  FillHeader(AInvoice, LandrixEInvoiceLeitwegIDNonExistent);
  AddManagerNote(AInvoice);
  FillSeller(AInvoice);
  AInvoice.AccountingSupplierParty.CompanyID := LandrixEInvoiceLeitwegIDNonExistent;
  AInvoice.AccountingSupplierParty.VATCompanyID := '';
  { the buyer needs the VAT ID here }
  FillBuyer(AInvoice, True);
  AInvoice.DeliveryInformation.ActualDeliveryDate := PeriodEndDate;
  AInvoice.PaymentID := DefaultPaymentID;
  AddSepaCreditTransfer(AInvoice, DefaultIBAN);
  SetNetPaymentTerms(AInvoice);

  with AInvoice.InvoiceLines.AddInvoiceLine do
  begin
    ID := '01.01';
    Name := 'Kurzinfo Artikel 1';
    Description := LongText3;
    Quantity := 4;
    UnitCode := UnitOf('Stk');
    SellersItemIdentification := 'A0815';
    TaxPercent := 0;
    TaxCategory := idtfcc_AE_VATReverseCharge;
    TaxExemptionReason := ReverseChargeReason; { must equal the subtotal's reason in ZUGFeRD Extended }
    GrossPriceAmount := 50;
    NetPriceAmount := 50;
    LineAmount := 200;
  end;

  with AddTaxSubtotal(AInvoice, 0, idtfcc_AE_VATReverseCharge, 200, 0) do
  begin
    TaxExemptionReason := ReverseChargeReason;
    TaxExemptionReasonCode := 'VATEX-EU-AE'; { BT-121, optional besides the text (BR-AE-10) }
  end;
  SetTotals(AInvoice, 0, 200, 200, 200, 200);
end;

{ PayPal or another online payment service. }
procedure ScenarioOnlinePaymentService(AInvoice: TLandrixInvoice);
begin
  FillHeader(AInvoice, LandrixEInvoiceLeitwegIDNonExistent);
  AddManagerNote(AInvoice);
  FillSeller(AInvoice);
  FillBuyer(AInvoice, False);
  AInvoice.DeliveryInformation.ActualDeliveryDate := PeriodEndDate;

  AInvoice.PaymentID := 'Verwendungszweck ...R2020-0815';
  with AInvoice.PaymentTypes.AddPaymentType do
  begin
    { ipmc_CreditTransfer or ipmc_MutuallyDefined are possible too }
    PaymentMeansCode := ipmc_OnlinePaymentService;
    PaymentMeansInformation := 'https://mypaymentgateway.example.com/resource meine@paypaladresse.de';
  end;
  AInvoice.PaymentTermsType := iptt_None;

  AddStandardLine(AInvoice);
  SetStandardTotals(AInvoice);
end;

{ Price base quantity greater than 1 (BT-149). }
procedure ScenarioPriceBaseQuantityAbove1(AInvoice: TLandrixInvoice);
begin
  FillHeader(AInvoice, LandrixEInvoiceLeitwegIDNonExistent);
  AddManagerNote(AInvoice);
  FillSeller(AInvoice);
  FillBuyer(AInvoice, False);
  AInvoice.DeliveryInformation.ActualDeliveryDate := PeriodEndDate;
  AInvoice.PaymentTypes.AddPaymentType.PaymentMeansCode := ipmc_InstrumentNotDefined;
  AInvoice.PaymentTermsType := iptt_None;

  with AInvoice.InvoiceLines.AddInvoiceLine do
  begin
    ID := '01';
    Name := 'Kurzinfo Artikel 1';
    Description := LongText3;
    Quantity := 1;
    UnitCode := UnitOf('Stk');
    TaxPercent := 19;
    TaxCategory := idtfcc_S_StandardRate;
    GrossPriceAmount := 360;
    NetPriceAmount := 360;
    BaseQuantity := 10;
    BaseQuantityUnitCode := UnitCode;
    LineAmount := 36;
  end;

  AddTaxSubtotal(AInvoice, 19, idtfcc_S_StandardRate, 36, Cents(684));
  SetTotals(AInvoice, Cents(684), 36, 36, Cents(4284), Cents(4284));
end;

{ Corrected invoice referring to the original invoice. }
procedure ScenarioCorrectedInvoice(AInvoice: TLandrixInvoice);
begin
  FillHeader(AInvoice, LandrixEInvoiceLeitwegIDNonExistent);
  with AInvoice.PrecedingInvoiceReferences.AddPrecedingInvoiceReference do
  begin
    ID := 'R2020-0814';
    IssueDate := LandrixEInvoiceExampleScenarios.IssueDate - 40;
  end;
  AInvoice.InvoiceTypeCode := itc_CorrectedInvoice;
  AddManagerNote(AInvoice);
  FillSeller(AInvoice);
  FillBuyer(AInvoice, False);
  AInvoice.DeliveryInformation.ActualDeliveryDate := PeriodEndDate;
  AInvoice.PaymentTypes.AddPaymentType.PaymentMeansCode := ipmc_InstrumentNotDefined;
  AInvoice.PaymentTermsType := iptt_None;

  with AInvoice.InvoiceLines.AddInvoiceLine do
  begin
    ID := '01';
    Name := 'Kurzinfo Artikel 1';
    Description := LongText3;
    Quantity := -1;
    UnitCode := UnitOf('Stk');
    TaxPercent := 19;
    TaxCategory := idtfcc_S_StandardRate;
    GrossPriceAmount := 360;
    NetPriceAmount := 360;
    LineAmount := -360;
  end;

  AddTaxSubtotal(AInvoice, 19, idtfcc_S_StandardRate, -360, Cents(-6840));
  SetTotals(AInvoice, Cents(-6840), -360, -360, Cents(-42840), Cents(-42840));
end;

{ BG-DEX-09 third party payment (pass-through item). All values are
  required; the sum of the prepaid payments is added to the payable amount.
  Not part of the golden file sequence (validation issues). }
procedure ScenarioThirdPartyPaymentBGDEX09(AInvoice: TLandrixInvoice; AUseCharges: Boolean);
begin
  FillHeader(AInvoice, LandrixEInvoiceLeitwegIDNonExistent);
  AddManagerNote(AInvoice);
  FillSeller(AInvoice);
  FillBuyer(AInvoice, False);
  MakeMinimalParties(AInvoice);
  AInvoice.DeliveryInformation.ActualDeliveryDate := PeriodEndDate;
  AInvoice.PaymentTypes.AddPaymentType.PaymentMeansCode := ipmc_InstrumentNotDefined;
  AInvoice.PaymentTermsType := iptt_None;

  AddStandardLine(AInvoice);

  if AUseCharges then
    with AInvoice.AllowanceCharges.AddAllowanceCharge do
    begin
      ChargeIndicator := True;
      ReasonCodeCharge := issdc_AAA_Telecommunication;
      Reason := 'Zuschlag fuer Kommunikation';
      BaseAmount := 10;
      MultiplierFactorNumeric := 10; { 10 percent of 10 EUR }
      Amount := 1;
      TaxPercent := 19;
      TaxCategory := idtfcc_S_StandardRate;
    end;

  with AInvoice.PrepaidPayments.AddPrepaidPayment do
  begin
    ID := 'MobilesBezahlen'; { BT-DEX-001 }
    PaidAmount := Cents(1996); { BT-DEX-002 }
    PaidAmountCurrencyID := 'EUR';
    InstructionID := 'Mobiles Bezahlen (Brutto-Forderung f' + UUml + 'r Fremdleistungen)'; { BT-DEX-003 }
  end;

  SetStandardTotals(AInvoice);
  AInvoice.PayableAmount := Cents(42840) + Cents(1996); { plus the prepaid payments }

  if AUseCharges then
  begin
    AInvoice.ChargeTotalAmount := 1;
    AInvoice.TaxAmountSubtotals[0].TaxableAmount := AInvoice.TaxAmountSubtotals[0].TaxableAmount + 1;
    AInvoice.TaxAmountSubtotals[0].TaxAmount := AInvoice.TaxAmountSubtotals[0].TaxAmount + Cents(19);
    AInvoice.TaxAmountTotal := AInvoice.TaxAmountTotal + Cents(19);
    AInvoice.TaxExclusiveAmount := AInvoice.TaxExclusiveAmount - AInvoice.AllowanceTotalAmount +
      AInvoice.ChargeTotalAmount;
    AInvoice.TaxInclusiveAmount := AInvoice.TaxInclusiveAmount + 1 + Cents(19);
    AInvoice.PayableAmount := AInvoice.PayableAmount + 1 + Cents(19);
  end;
end;

{ Title with line groups (sub invoice lines). The validation warning
  UBL-CR-646 (SubInvoiceLine) is expected for XRechnung UBL; Peppol BIS
  writes the groups flat. }
procedure ScenarioTitleLineGroups(AInvoice: TLandrixInvoice);
begin
  FillHeader(AInvoice, '991-01484-64');
  AddManagerNote(AInvoice);
  FillSeller(AInvoice);
  FillBuyer(AInvoice, True);
  AInvoice.DeliveryInformation.ActualDeliveryDate := PeriodEndDate;
  AInvoice.PaymentID := DefaultPaymentID;
  AddSepaCreditTransfer(AInvoice, DefaultIBAN);
  SetNetPaymentTerms(AInvoice);

  with AInvoice.InvoiceLines.AddInvoiceLine do
  begin
    ID := '01';
    Name := 'Kurzinfo Titel';
    Quantity := 1;
    UnitCode := UnitOf('Stk');
    TaxPercent := 19;
    TaxCategory := idtfcc_S_StandardRate;
    GrossPriceAmount := 400;
    NetPriceAmount := 400;
    LineAmount := 400;

    with SubInvoiceLines.AddInvoiceLine do
    begin
      ID := '01.01';
      Name := 'Kurzinfo Artikel 1';
      Description := LongText3;
      Quantity := 4;
      UnitCode := UnitOf('Stk');
      SellersItemIdentification := 'A0815';
      TaxPercent := 19;
      TaxCategory := idtfcc_S_StandardRate;
      GrossPriceAmount := 50;
      NetPriceAmount := 50;
      LineAmount := 200;
    end;
    with SubInvoiceLines.AddInvoiceLine do
    begin
      ID := '01.02';
      Name := 'Kurzinfo Artikel 2';
      Description := LongText3;
      Quantity := 4;
      UnitCode := UnitOf('Stk');
      SellersItemIdentification := 'A0816';
      TaxPercent := 19;
      TaxCategory := idtfcc_S_StandardRate;
      GrossPriceAmount := 50;
      NetPriceAmount := 50;
      LineAmount := 200;
    end;
  end;

  AddTaxSubtotal(AInvoice, 19, idtfcc_S_StandardRate, 400, 76);
  SetTotals(AInvoice, 76, 400, 400, 476, 476);
end;

{ As ScenarioTitleLineGroups, plus the sub types of ZUGFeRD/Factur-X
  EXTENDED (BT-X-8): the title is a pure subtotal without tax category, an
  additional sub line is information only and does not count in the totals. }
procedure ScenarioTitleLineGroupsExtended(AInvoice: TLandrixInvoice);
begin
  ScenarioTitleLineGroups(AInvoice);
  AInvoice.InvoiceLines[0].TaxCategory := idtfcc_None;
  AInvoice.InvoiceLines[0].TaxPercent := 0;
  with AInvoice.InvoiceLines[0].SubInvoiceLines.AddInvoiceLine do
  begin
    ID := '01.03';
    LineStatusReasonCode := ilsrc_Information; { counts neither in BT-106 nor in the title amount }
    Name := 'Montage (im Preis enthalten)';
    Quantity := 1;
    UnitCode := UnitOf('Stk');
    TaxPercent := 19;
    TaxCategory := idtfcc_S_StandardRate;
    GrossPriceAmount := 50;
    NetPriceAmount := 50;
    LineAmount := 50;
  end;
end;

{ Net price with four decimal places. }
procedure ScenarioFourDecimalPlaces(AInvoice: TLandrixInvoice);
begin
  FillHeader(AInvoice, LandrixEInvoiceLeitwegIDNonExistent);
  AddManagerNote(AInvoice);
  FillSeller(AInvoice);
  FillBuyer(AInvoice, False);
  MakeMinimalParties(AInvoice);
  AInvoice.DeliveryInformation.ActualDeliveryDate := PeriodEndDate;
  AInvoice.PaymentTypes.AddPaymentType.PaymentMeansCode := ipmc_InstrumentNotDefined;
  AInvoice.PaymentTermsType := iptt_None;

  with AInvoice.InvoiceLines.AddInvoiceLine do
  begin
    ID := '01';
    Name := 'Kurzinfo Artikel 1';
    Description := LongText3;
    Quantity := 2;
    UnitCode := UnitOf('Stk');
    TaxPercent := 19;
    TaxCategory := idtfcc_S_StandardRate;
    GrossPriceAmount := Cur(41235);
    NetPriceAmount := Cur(41235);
    LineAmount := Cents(825);
  end;

  AddTaxSubtotal(AInvoice, 19, idtfcc_S_StandardRate, Cents(825), Cents(157));
  SetTotals(AInvoice, Cents(157), Cents(825), Cents(825), Cents(982), Cents(982));
end;

{ Price base quantity (BT-149) with more than 2 decimal places (0.001 m3),
  formerly rounded to 0.00. }
procedure ScenarioBaseQuantityDecimals(AInvoice: TLandrixInvoice);
begin
  FillHeader(AInvoice, LandrixEInvoiceLeitwegIDNonExistent);
  AddManagerNote(AInvoice);
  FillSeller(AInvoice);
  FillBuyer(AInvoice, False);
  MakeMinimalParties(AInvoice);
  AInvoice.DeliveryInformation.ActualDeliveryDate := PeriodEndDate;
  AInvoice.PaymentTypes.AddPaymentType.PaymentMeansCode := ipmc_InstrumentNotDefined;
  AInvoice.PaymentTermsType := iptt_None;

  with AInvoice.InvoiceLines.AddInvoiceLine do
  begin
    ID := '01';
    Name := 'Kurzinfo Artikel 1';
    Description := LongText3;
    Quantity := 4; { cubic metres }
    UnitCode := iuc_cubic_metre;
    TaxPercent := 19;
    TaxCategory := idtfcc_S_StandardRate;
    GrossPriceAmount := Cents(5); { per 0.001 m3 }
    NetPriceAmount := Cents(5);
    BaseQuantity := Quot(1, 1000);
    BaseQuantityUnitCode := iuc_cubic_metre; { as UnitCode (PEPPOL-EN16931-R130) }
    LineAmount := 200; { 4 * 0.05 / 0.001 (PEPPOL-EN16931-R120) }
  end;

  AddTaxSubtotal(AInvoice, 19, idtfcc_S_StandardRate, 200, 38);
  SetTotals(AInvoice, 38, 200, 200, 238, 238);
end;

{ Electronic addresses BT-34/BT-49 with a chosen scheme: Peppol allows
  neither 'EM' nor an empty scheme, the XRechnung profiles still replace an
  empty scheme by 'EM'. Not part of the golden file sequence. }
procedure ScenarioPeppolEndpointSchemeID(AInvoice: TLandrixInvoice;
  const ASellerSchemeID, ABuyerSchemeID: TLandrixEInvoiceString);
begin
  ScenarioMinimalB2BWithoutLeitwegID(AInvoice);
  if ASellerSchemeID = '0088' then
    AInvoice.AccountingSupplierParty.ElectronicAddressSellerBuyer := '9482348239847239874'
  else
    AInvoice.AccountingSupplierParty.ElectronicAddressSellerBuyer := 'rechnung@example.org';
  AInvoice.AccountingSupplierParty.ElectronicAddressSellerBuyerSchemeID := ASellerSchemeID;
  if ABuyerSchemeID = '0002' then
    AInvoice.AccountingCustomerParty.ElectronicAddressSellerBuyer := 'FR23342'
  else
    AInvoice.AccountingCustomerParty.ElectronicAddressSellerBuyer := 'einkauf@example.org';
  AInvoice.AccountingCustomerParty.ElectronicAddressSellerBuyerSchemeID := ABuyerSchemeID;
end;

{ Identifiers BT-29/BT-46: written in UBL without schemeID; a GLN belongs
  in GlobalIdentifierSellerBuyer. UBL allows one identifier per party
  (UBL-SR-16, VD-Valitool-23), CII one for the buyer (CII-SR-450), where the
  GLN wins except in ZUGFeRD Extended. The creditor ID (BT-90) also takes a
  cac:PartyIdentification of the seller in UBL (schemeID SEPA), so the direct
  debit is the base then. Not part of the golden file sequence. }
procedure ScenarioPartyIdentifierGLN(AInvoice: TLandrixInvoice;
  AUseIdentifier, AUseGLN, AUseCreditorID: Boolean);
begin
  if AUseCreditorID then
    ScenarioDirectDebit(AInvoice)
  else
    ScenarioMinimalB2BWithoutLeitwegID(AInvoice);

  if AUseIdentifier then
  begin
    { supplier and customer numbers, no GLN, hence without schemeID }
    AInvoice.AccountingSupplierParty.IdentifierSellerBuyer := 'KRED-10001';
    AInvoice.AccountingCustomerParty.IdentifierSellerBuyer := '20003';
  end;
  if AUseGLN then
  begin
    { Peppol checks the GLN check digit (PEPPOL-COMMON-R040) }
    AInvoice.AccountingSupplierParty.GlobalIdentifierSellerBuyer := '4123450000027';
    AInvoice.AccountingSupplierParty.GlobalIdentifierSellerBuyerSchemeID := '0088';
    AInvoice.AccountingCustomerParty.GlobalIdentifierSellerBuyer := '4260000000004';
    AInvoice.AccountingCustomerParty.GlobalIdentifierSellerBuyerSchemeID := '0088';
  end;
end;

{ Golden file sequence }

procedure RunAllScenarios(ASave: TScenarioSave; AData: Pointer; const AAttachmentDir: string);
var
  Inv: TLandrixInvoice;
  XRechnungUBL, XRechnungCII, ZUGFeRDEN16931, ZUGFeRDExtended, Peppol: TLandrixEInvoiceTarget;

  procedure Renew;
  begin
    Inv.Free;
    Inv := nil;
    Inv := TLandrixInvoice.Create;
  end;

  procedure Save(const ATarget: TLandrixEInvoiceTarget; const AFileName: string);
  begin
    ASave(Inv, ATarget, AFileName, AData);
  end;

  { Peppol requires electronic addresses with a Peppol scheme (not EM);
    set before every Peppol output. }
  procedure PeppolAddresses;
  begin
    Inv.AccountingSupplierParty.ElectronicAddressSellerBuyer := '9482348239847239874';
    Inv.AccountingSupplierParty.ElectronicAddressSellerBuyerSchemeID := '0088';
    Inv.AccountingCustomerParty.ElectronicAddressSellerBuyer := 'FR23342';
    Inv.AccountingCustomerParty.ElectronicAddressSellerBuyerSchemeID := '0002';
  end;

  { The usual five outputs: XRechnung UBL, ZUGFeRD EN16931 and Extended,
    XRechnung CII, Peppol. }
  procedure SaveAllFive(const ABaseName: string);
  begin
    Save(XRechnungUBL, ABaseName + '-ubl-30x.xml');
    Save(ZUGFeRDEN16931, ABaseName + '-ciiEN16931-25.xml');
    Save(ZUGFeRDExtended, ABaseName + '-ciiextended-25.xml');
    Save(XRechnungCII, ABaseName + '-cii-30x.xml');
    PeppolAddresses;
    Save(Peppol, ABaseName + '-ubl-peppol.xml');
  end;

  { Overall example: UBL outputs, then the CII outputs from a new invoice
    with the restrictions of the CII binding. }
  procedure OverallExample(const ABaseName: string; APaymentTerms: Integer; AAll: Boolean);
  begin
    Renew;
    ScenarioOverallExample(Inv, APaymentTerms, AAll, AAll, AAll, AAll, False, AAttachmentDir);
    Save(XRechnungUBL, ABaseName + '-ubl-30x.xml');
    PeppolAddresses;
    Save(Peppol, ABaseName + '-ubl-peppol.xml');
    Renew;
    ScenarioOverallExample(Inv, APaymentTerms, AAll, AAll, AAll, AAll, True, AAttachmentDir);
    Save(ZUGFeRDEN16931, ABaseName + '-ciiEN16931-25.xml');
    Save(ZUGFeRDExtended, ABaseName + '-ciiextended-25.xml');
    Save(XRechnungCII, ABaseName + '-cii-30x.xml');
  end;

begin
  XRechnungUBL := TLandrixEInvoiceTargets.XRechnung('3.0', esy_UBL);
  XRechnungCII := TLandrixEInvoiceTargets.XRechnung('3.0', esy_CII);
  ZUGFeRDEN16931 := TLandrixEInvoiceTargets.ZUGFeRD('2.5', epr_EN16931);
  ZUGFeRDExtended := TLandrixEInvoiceTargets.ZUGFeRD('2.5', epr_Extended);
  Peppol := TLandrixEInvoiceTargets.PeppolBIS('3.0');

  Inv := nil;
  try
    Renew;
    ScenarioSmallBusinessRegulation(Inv);
    SaveAllFive('Kleinunternehmerregelung');

    Renew;
    ScenarioReverseCharge13b(Inv);
    SaveAllFive('Paragr13b');

    Renew;
    ScenarioExchangePartTax(Inv);
    SaveAllFive('Austauschteilesteuer');

    Renew;
    ScenarioMarginScheme(Inv);
    SaveAllFive('Differenzbesteuerung');

    Renew;
    ScenarioTitleLineGroups(Inv);
    Save(XRechnungUBL, 'TitelPositionsgruppen-ubl-30x.xml');
    Save(ZUGFeRDExtended, 'TitelPositionsgruppen-ciiextended-25.xml');
    PeppolAddresses;
    Save(Peppol, 'TitelPositionsgruppen-ubl-peppol.xml');

    Renew;
    ScenarioCreditNote(Inv);
    SaveAllFive('Gutschrift');

    Renew;
    ScenarioCorrectedInvoice(Inv);
    SaveAllFive('Rechnungskorrektur');

    Renew;
    ScenarioMinimalB2BWithoutLeitwegID(Inv);
    SaveAllFive('MinimalbeispielB2BOhneLeitwegID');

    Renew;
    ScenarioPriceBaseQuantityAbove1(Inv);
    SaveAllFive('PreiseinheitGroesser1');

    Renew;
    ScenarioDirectDebit(Inv);
    SaveAllFive('Lastschrift');

    Renew;
    ScenarioIntraCommunitySupplyWithoutVAT(Inv);
    SaveAllFive('LieferungEUohneMehrwertsteuer');

    Renew;
    ScenarioOnlinePaymentService(Inv);
    SaveAllFive('PayPal');

    Renew;
    ScenarioCreditCard(Inv);
    SaveAllFive('Kreditkarte');

    Renew;
    ScenarioLinePeriods(Inv);
    SaveAllFive('LeistungszeitraumJePosition');

    OverallExample('Gesamtbeispiel', 0, False);
    OverallExample('Gesamtbeispiel-Nettoziel', 1, False);
    OverallExample('Gesamtbeispiel-Skonto1', 2, False);
    OverallExample('Gesamtbeispiel-Skonto2', 3, False);
    OverallExample('Gesamtbeispiel-Alles', 0, True);
    OverallExample('Gesamtbeispiel-Alles-Skonto2', 3, True);

    { the XRechnung CII output comes from a fresh invoice (Peppol changed the
      electronic addresses) }
    Renew;
    ScenarioFourDecimalPlaces(Inv);
    Save(XRechnungUBL, 'Vier-Nachkommastellen-ubl-30x.xml');
    Save(ZUGFeRDEN16931, 'Vier-Nachkommastellen-ciiEN16931-25.xml');
    Save(ZUGFeRDExtended, 'Vier-Nachkommastellen-ciiextended-25.xml');
    PeppolAddresses;
    Save(Peppol, 'Vier-Nachkommastellen-ubl-peppol.xml');
    Renew;
    ScenarioFourDecimalPlaces(Inv);
    Save(XRechnungCII, 'Vier-Nachkommastellen-cii-30x.xml');

    Renew;
    ScenarioBaseQuantityDecimals(Inv);
    SaveAllFive('Basismenge-Nachkommastellen');

    Renew;
    ScenarioCollectiveInvoiceDeliveryNotes(Inv);
    Save(ZUGFeRDExtended, 'SammelrechnungLieferscheine-ciiextended-25.xml');
    Save(ZUGFeRDEN16931, 'SammelrechnungLieferscheine-ciiEN16931-25.xml');

    Renew;
    ScenarioTitleLineGroupsExtended(Inv);
    Save(ZUGFeRDExtended, 'TitelPositionsgruppenExtended-ciiextended-25.xml');
  finally
    Inv.Free;
  end;
end;

end.
