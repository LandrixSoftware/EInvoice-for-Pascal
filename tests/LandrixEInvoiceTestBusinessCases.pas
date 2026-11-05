{
  EInvoice-for-Pascal

  Copyright (C) 2026 Landrix Software GmbH & Co. KG

  This file is dual-licensed under:
  - GNU GPL version 3 or later; or
  - the Landrix Software Commercial License.

  See LICENSE and COMMERCIAL-LICENSE.md.

  SPDX-License-Identifier: GPL-3.0-or-later OR LicenseRef-Landrix-Commercial
}

{ Business test cases per business group, written anew from EN 16931 and its
  syntax bindings (plan, Phase 2 step 3; no test case taken from other
  libraries). Each case changes one group of a valid base invoice and runs
  through five targets: XRechnung UBL and CII, Peppol BIS, Factur-X EN16931
  and EXTENDED. Per target the case writes the invoice, checks hand-written
  expectations on the XML (element path and value from the binding, compared
  without the indentation), reads it back and compares every field with the
  generated comparison; it fails on errors, on content left out and on
  differences unless the case allows them. The outputs go to
  <program folder>/cases/ under names that tools/validate.ps1 maps, so
  tools/build.ps1 -Validate lets the KoSIT validator check every case as an
  independent oracle.

  Expectations: 'all:', 'ubl:' (XRechnung UBL, Peppol), 'cii:' (XRechnung
  CII, Factur-X), 'xr:' (XRechnung UBL and CII), 'fx:' (Factur-X EN16931 and
  EXTENDED), 'ext:' (Factur-X EXTENDED) followed by the text; another prefix
  raises. Allowed findings: prefixes of '<target suffix> <stage> <finding>'.

  Amounts are given in cents and computed by hand in each case (no float
  literals: Delphi 13 Win64 W1066). }

unit LandrixEInvoiceTestBusinessCases;

{$I LandrixEInvoice.inc}

interface

procedure Register;

implementation

uses
  SysUtils,
  Classes,
  LandrixXmlBase,
  LandrixXmlReader,
  LandrixXmlWriter,
  LandrixEInvoiceTypes,
  LandrixEInvoiceDiagnostics,
  LandrixEInvoiceCodes,
  LandrixEInvoiceSpecs,
  LandrixEInvoiceInvoice,
  LandrixEInvoiceCII,
  LandrixEInvoiceCIIReader,
  LandrixEInvoiceCIIWriter,
  LandrixEInvoiceMapCII,
  LandrixEInvoiceUBL,
  LandrixEInvoiceUBLReader,
  LandrixEInvoiceUBLWriter,
  LandrixEInvoiceMapUBL,
  LandrixEInvoiceTestFramework,
  LandrixEInvoiceTestInvoiceCompare;

type
  TCaseTarget = (ct_XRechnungUBL, ct_XRechnungCII, ct_Peppol, ct_FacturXEN16931, ct_FacturXExtended);

const
  TargetSuffix: array[TCaseTarget] of string = ('-ubl-30x.xml', '-cii-30x.xml', '-ubl-peppol.xml',
    '-ciiEN16931-25.xml', '-ciiextended-25.xml');

function OutDir: string;
begin
  Result := ExtractFilePath(ParamStr(0)) + 'cases' + PathDelim;
end;

function Cents(ACents: Int64): Currency;
begin
  PInt64(@Result)^ := ACents * 100;
end;

function TargetOf(ATarget: TCaseTarget): TLandrixEInvoiceTarget;
begin
  case ATarget of
    ct_XRechnungUBL: Result := TLandrixEInvoiceTargets.XRechnung('3.0', esy_UBL);
    ct_XRechnungCII: Result := TLandrixEInvoiceTargets.XRechnung('3.0', esy_CII);
    ct_Peppol: Result := TLandrixEInvoiceTargets.PeppolBIS('3.0');
    ct_FacturXEN16931: Result := TLandrixEInvoiceTargets.FacturX('1.09', epr_EN16931);
  else
    Result := TLandrixEInvoiceTargets.FacturX('1.09', epr_Extended);
  end;
end;

{ True if the expectation kind applies to ATarget; raises for an unknown kind,
  so that a typo cannot switch an expectation off. }
function KindApplies(const AKind: string; ATarget: TCaseTarget): Boolean;
begin
  if AKind = 'all' then
    Result := True
  else if AKind = 'ubl' then
    Result := ATarget in [ct_XRechnungUBL, ct_Peppol]
  else if AKind = 'cii' then
    Result := ATarget in [ct_XRechnungCII, ct_FacturXEN16931, ct_FacturXExtended]
  else if AKind = 'xr' then
    Result := ATarget in [ct_XRechnungUBL, ct_XRechnungCII]
  else if AKind = 'fx' then
    Result := ATarget in [ct_FacturXEN16931, ct_FacturXExtended]
  else if AKind = 'ext' then
    Result := ATarget = ct_FacturXExtended
  else
    raise Exception.Create('unknown expectation kind ' + AKind);
end;

{ The XML without white space between tags, so that expectations can name
  nested elements. }
function Compact(const AText: string): string;
var
  I, J, Start: Integer;
begin
  Result := '';
  SetLength(Result, Length(AText));
  J := 0;
  I := 1;
  while I <= Length(AText) do
  begin
    if AText[I] = '>' then
    begin
      Inc(J);
      Result[J] := '>';
      Start := I + 1;
      I := Start;
      while (I <= Length(AText)) and ((AText[I] = ' ') or (AText[I] = #9) or (AText[I] = #10) or
        (AText[I] = #13)) do
        Inc(I);
      if (I <= Length(AText)) and (AText[I] <> '<') then
        I := Start;
      Continue;
    end;
    Inc(J);
    Result[J] := AText[I];
    Inc(I);
  end;
  SetLength(Result, J);
end;

{ --- base invoice ------------------------------------------------------------ }

{ A valid invoice for all five targets: Peppol-capable electronic addresses
  (EAS 0088), the XRechnung seller contact (BR-DE-2), buyer reference
  (BR-DE-15, PEPPOL-EN16931-R003), a SEPA credit transfer (BR-DE-1, BR-DE-23)
  and one line of 2 x 50.00 EUR at 19 %. }
procedure FillBase(AInvoice: TLandrixInvoice);
var
  Party: TLandrixInvoiceAccountingParty;
  Line: TLandrixInvoiceLine;
  Payment: TLandrixInvoicePaymentType;
  Subtotal: TLandrixInvoiceTaxAmount;
begin
  AInvoice.InvoiceNumber := 'BC-2026-001';
  AInvoice.InvoiceIssueDate := EncodeDate(2026, 10, 19);
  AInvoice.InvoiceDueDate := EncodeDate(2026, 11, 18);
  AInvoice.InvoiceTypeCode := itc_CommercialInvoice;
  AInvoice.InvoiceCurrencyCode := 'EUR';
  AInvoice.BuyerReference := '04011000-12345-03';
  AInvoice.PaymentTermsType := iptt_Net;
  AInvoice.PaymentTermNetNote := 'Zahlbar bis 18.11.2026 ohne Abzug.';
  Party := AInvoice.AccountingSupplierParty;
  Party.RegistrationName := 'Seller GmbH';
  Party.Address.StreetName := 'Sellerstrasse 1';
  Party.Address.City := 'Berlin';
  Party.Address.PostalZone := '10115';
  Party.Address.CountryCode := 'DE';
  Party.VATCompanyID := 'DE123456788';
  Party.ContactName := 'Anna Seller';
  Party.ContactTelephone := '+49 30 123456';
  Party.ContactElectronicMail := 'anna@seller.example';
  Party.ElectronicAddressSellerBuyer := '4000001123452';
  Party.ElectronicAddressSellerBuyerSchemeID := '0088';
  Party := AInvoice.AccountingCustomerParty;
  Party.RegistrationName := 'Buyer AG';
  Party.Address.StreetName := 'Buyerweg 2';
  Party.Address.City := 'Hamburg';
  Party.Address.PostalZone := '20095';
  Party.Address.CountryCode := 'DE';
  Party.ElectronicAddressSellerBuyer := '4000001987658';
  Party.ElectronicAddressSellerBuyerSchemeID := '0088';
  Payment := AInvoice.PaymentTypes.AddPaymentType;
  Payment.PaymentMeansCode := ipmc_SEPACreditTransfer;
  Payment.FinancialAccount := 'DE75512108001245126199';
  Payment.FinancialAccountName := 'Seller GmbH';
  Line := AInvoice.InvoiceLines.AddInvoiceLine;
  Line.ID := '1';
  Line.Name := 'Item';
  Line.Quantity := 2;
  Line.UnitCode := iuc_piece;
  Line.NetPriceAmount := 50;
  Line.LineAmount := Cents(10000);
  Line.TaxCategory := idtfcc_S_StandardRate;
  Line.TaxPercent := 19;
  Subtotal := AInvoice.TaxAmountSubtotals.AddTaxAmount;
  Subtotal.TaxCategory := idtfcc_S_StandardRate;
  Subtotal.TaxPercent := 19;
  Subtotal.TaxableAmount := Cents(10000);
  Subtotal.TaxAmount := Cents(1900);
  AInvoice.LineAmount := Cents(10000);
  AInvoice.TaxExclusiveAmount := Cents(10000);
  AInvoice.TaxAmountTotal := Cents(1900);
  AInvoice.TaxInclusiveAmount := Cents(11900);
  AInvoice.PayableAmount := Cents(11900);
end;

{ Replaces the single breakdown and the totals for one line category. }
procedure SetSingleCategory(AInvoice: TLandrixInvoice; ACategory: TLandrixInvoiceDutyTaxFeeCategoryCode;
  APercent: Integer; const AReason, AReasonCode: TLandrixEInvoiceString);
var
  Subtotal: TLandrixInvoiceTaxAmount;
begin
  AInvoice.InvoiceLines[0].TaxCategory := ACategory;
  AInvoice.InvoiceLines[0].TaxPercent := APercent;
  Subtotal := AInvoice.TaxAmountSubtotals[0];
  Subtotal.TaxCategory := ACategory;
  Subtotal.TaxPercent := APercent;
  Subtotal.TaxExemptionReason := AReason;
  Subtotal.TaxExemptionReasonCode := AReasonCode;
  Subtotal.TaxAmount := 0;
  AInvoice.TaxAmountTotal := 0;
  AInvoice.TaxInclusiveAmount := AInvoice.TaxExclusiveAmount;
  AInvoice.PayableAmount := AInvoice.TaxExclusiveAmount;
end;

{ --- running a case ---------------------------------------------------------- }

function WriteTarget(AInvoice: TLandrixInvoice; ATarget: TCaseTarget; D: TLandrixEInvoiceDiagnostics): TLandrixXmlUtf8;
var
  Spec: TLandrixEInvoiceSpec;
  W: TLandrixXmlWriter;
  CII: TLandrixCIIInvoice;
  UBLInvoice: TLandrixUBLInvoice;
  UBLCreditNote: TLandrixUBLCreditNote;
begin
  Check(LandrixEInvoiceFindSpec(TargetOf(ATarget), Spec), 'spec');
  W := TLandrixXmlWriter.Create;
  try
    W.Indent := True;
    if Spec.Target.Syntax = esy_CII then
    begin
      CII := LandrixEInvoiceInvoiceToCII(AInvoice, Spec, D);
      try
        LandrixEInvoiceWriteCII(CII, W, D, Spec.Target.Profile);
      finally
        CII.Free;
      end;
    end
    else if LandrixEInvoiceUBLRootFor(AInvoice, Spec) = eur_CreditNote then
    begin
      UBLCreditNote := LandrixEInvoiceInvoiceToUBLCreditNote(AInvoice, Spec, D);
      try
        LandrixEInvoiceWriteUBLCreditNote(UBLCreditNote, W, D);
      finally
        UBLCreditNote.Free;
      end;
    end
    else
    begin
      UBLInvoice := LandrixEInvoiceInvoiceToUBLInvoice(AInvoice, Spec, D);
      try
        LandrixEInvoiceWriteUBLInvoice(UBLInvoice, W, D);
      finally
        UBLInvoice.Free;
      end;
    end;
    W.EndDocument;
    Result := W.AsUtf8;
  finally
    W.Free;
  end;
end;

procedure ReadBack(const AXml: TLandrixXmlUtf8; AInvoice: TLandrixInvoice; D: TLandrixEInvoiceDiagnostics);
var
  R: TLandrixXmlReader;
  Root: string;
  CII: TLandrixCIIInvoice;
  UBLInvoice: TLandrixUBLInvoice;
  UBLCreditNote: TLandrixUBLCreditNote;
begin
  R := TLandrixXmlReader.Create;
  try
    R.LoadFromUtf8(AXml);
    Root := '';
    while (Root = '') and R.Read do
      if R.TokenType = xttStartElement then
        Root := R.LocalName;
  finally
    R.Free;
  end;
  R := TLandrixXmlReader.Create;
  try
    R.LoadFromUtf8(AXml);
    if Root = 'CrossIndustryInvoice' then
    begin
      CII := LandrixEInvoiceReadCII(R, D);
      try
        LandrixEInvoiceCIIToInvoice(CII, AInvoice, D);
      finally
        CII.Free;
      end;
    end
    else if Root = 'CreditNote' then
    begin
      UBLCreditNote := LandrixEInvoiceReadUBLCreditNote(R, D);
      try
        LandrixEInvoiceUBLCreditNoteToInvoice(UBLCreditNote, AInvoice, D);
      finally
        UBLCreditNote.Free;
      end;
    end
    else
    begin
      UBLInvoice := LandrixEInvoiceReadUBLInvoice(R, D);
      try
        LandrixEInvoiceUBLInvoiceToInvoice(UBLInvoice, AInvoice, D);
      finally
        UBLInvoice.Free;
      end;
    end;
  finally
    R.Free;
  end;
end;

procedure SaveFile(const AFileName: string; const AData: TLandrixXmlUtf8);
var
  S: TFileStream;
begin
  S := TFileStream.Create(AFileName, fmCreate);
  try
    if Length(AData) > 0 then
      S.WriteBuffer(PAnsiChar(AData)^, Length(AData));
  finally
    S.Free;
  end;
end;

function Allowed(const AText: string; const AAllowed: array of string): Boolean;
var
  I: Integer;
begin
  Result := False;
  for I := 0 to Integer(High(AAllowed)) do
    if Pos(AAllowed[I], AText) = 1 then
    begin
      Result := True;
      Exit;
    end;
end;

procedure RunCase(const AName: string; AInvoice: TLandrixInvoice; const AExpect, AAllowed: array of string);
var
  T: TCaseTarget;
  D: TLandrixEInvoiceDiagnostics;
  Back: TLandrixInvoice;
  Xml: TLandrixXmlUtf8;
  Text, Kind, Wanted, Finding: string;
  Diffs: TStringList;
  I, P: Integer;
  K: TLandrixEInvoiceListIndex;
  Failed: Integer;
begin
  Check(ForceDirectories(OutDir), 'cases folder');
  Failed := 0;
  Diffs := TStringList.Create;
  try
    for T := Low(TCaseTarget) to High(TCaseTarget) do
    begin
      D := TLandrixEInvoiceDiagnostics.Create;
      Back := TLandrixInvoice.Create;
      try
        Xml := WriteTarget(AInvoice, T, D);
        SaveFile(OutDir + 'case-' + AName + TargetSuffix[T], Xml);
        Text := Compact(LandrixXmlUtf8ToString(Xml));
        for K := 0 to D.Count - 1 do
          if (D[K].Severity = eds_Error) or (D[K].Kind = edk_NotAllowed) then
          begin
            Finding := TargetSuffix[T] + ' write ' + string(LandrixEInvoiceDiagnosticKindToStr(D[K].Kind)) + ' ' +
              string(D[K].Path) + ': ' + string(D[K].Message);
            if not Allowed(Finding, AAllowed) then
            begin
              Inc(Failed);
              WriteLn('  ', AName, ' ', Finding);
            end;
          end;
        for I := 0 to Integer(High(AExpect)) do
        begin
          P := Pos(':', AExpect[I]);
          Kind := Copy(AExpect[I], 1, P - 1);
          Wanted := Copy(AExpect[I], P + 1, MaxInt);
          if KindApplies(Kind, T) and (Pos(Wanted, Text) = 0) then
          begin
            Inc(Failed);
            WriteLn('  ', AName, ' ', TargetSuffix[T], ' expected in the XML: ', Wanted);
          end;
        end;
        D.Clear;
        ReadBack(Xml, Back, D);
        for K := 0 to D.Count - 1 do
          if (D[K].Severity = eds_Error) or (D[K].Kind in [edk_NotMapped, edk_ConversionFailed]) then
          begin
            Finding := TargetSuffix[T] + ' read ' + string(LandrixEInvoiceDiagnosticKindToStr(D[K].Kind)) + ' ' +
              string(D[K].Path);
            if not Allowed(Finding, AAllowed) then
            begin
              Inc(Failed);
              WriteLn('  ', AName, ' ', Finding);
            end;
          end;
        Diffs.Clear;
        CompareInvoices(AInvoice, Back, Diffs);
        for I := 0 to Diffs.Count - 1 do
        begin
          Finding := TargetSuffix[T] + ' compare ' + Diffs[I];
          if not Allowed(Finding, AAllowed) then
          begin
            Inc(Failed);
            WriteLn('  ', AName, ' ', Finding);
          end;
        end;
      finally
        Back.Free;
        D.Free;
      end;
    end;
  finally
    Diffs.Free;
  end;
  CheckEquals(0, Failed, AName + ': findings');
end;

{ --- cases: VAT -------------------------------------------------------------- }

{ BG-23 / BR-Z: zero rated goods, rate 0, no exemption reason. }
procedure TestVatZeroRated;
var
  Inv: TLandrixInvoice;
begin
  Inv := TLandrixInvoice.Create;
  try
    FillBase(Inv);
    SetSingleCategory(Inv, idtfcc_Z_ZeroRatedGoods, 0, '', '');
    RunCase('vat-z', Inv, ['ubl:<cac:ClassifiedTaxCategory><cbc:ID>Z</cbc:ID>',
      'ubl:<cac:TaxSubtotal><cbc:TaxableAmount currencyID="EUR">100.00</cbc:TaxableAmount>',
      'cii:<ram:CategoryCode>Z</ram:CategoryCode>'], []);
  finally
    Inv.Free;
  end;
end;

{ BG-23 / BR-E: exempt, rate 0, exemption reason text and code (BT-120,
  BT-121; BR-E-10). }
procedure TestVatExempt;
var
  Inv: TLandrixInvoice;
begin
  Inv := TLandrixInvoice.Create;
  try
    FillBase(Inv);
    SetSingleCategory(Inv, idtfcc_E_ExemptFromTax, 0, 'Steuerfreie Heilbehandlung', 'VATEX-EU-132');
    RunCase('vat-e', Inv, ['ubl:<cbc:TaxExemptionReasonCode>VATEX-EU-132</cbc:TaxExemptionReasonCode>',
      'ubl:<cbc:TaxExemptionReason>Steuerfreie Heilbehandlung</cbc:TaxExemptionReason>',
      'cii:<ram:ExemptionReasonCode>VATEX-EU-132</ram:ExemptionReasonCode>',
      'cii:<ram:ExemptionReason>Steuerfreie Heilbehandlung</ram:ExemptionReason>'], []);
  finally
    Inv.Free;
  end;
end;

{ BG-23 / BR-G: export outside the EU, buyer in Switzerland, rate 0,
  exemption reason (BR-G-10). }
procedure TestVatExport;
var
  Inv: TLandrixInvoice;
begin
  Inv := TLandrixInvoice.Create;
  try
    FillBase(Inv);
    Inv.AccountingCustomerParty.Address.City := 'Zuerich';
    Inv.AccountingCustomerParty.Address.PostalZone := '8001';
    Inv.AccountingCustomerParty.Address.CountryCode := 'CH';
    SetSingleCategory(Inv, idtfcc_G_FreeExportItemTaxNotCharged, 0, 'Ausfuhrlieferung', 'VATEX-EU-G');
    RunCase('vat-g', Inv, ['ubl:<cbc:ID>G</cbc:ID>', 'cii:<ram:CategoryCode>G</ram:CategoryCode>',
      'ubl:<cbc:TaxExemptionReasonCode>VATEX-EU-G</cbc:TaxExemptionReasonCode>',
      'cii:<ram:ExemptionReasonCode>VATEX-EU-G</ram:ExemptionReasonCode>',
      'ubl:<cac:Country><cbc:IdentificationCode>CH</cbc:IdentificationCode></cac:Country>',
      'cii:<ram:CountryID>CH</ram:CountryID>'], []);
  finally
    Inv.Free;
  end;
end;

{ BG-23 / BR-AE: reverse charge, seller and buyer VAT identifier (BR-AE-02),
  rate 0, exemption reason (BR-AE-10). }
procedure TestVatReverseCharge;
var
  Inv: TLandrixInvoice;
begin
  Inv := TLandrixInvoice.Create;
  try
    FillBase(Inv);
    Inv.AccountingCustomerParty.VATCompanyID := 'DE987654320';
    SetSingleCategory(Inv, idtfcc_AE_VATReverseCharge, 0, 'Steuerschuldnerschaft des Leistungsempfaengers',
      'VATEX-EU-AE');
    RunCase('vat-ae', Inv, ['ubl:<cac:ClassifiedTaxCategory><cbc:ID>AE</cbc:ID>',
      'ubl:<cbc:TaxExemptionReasonCode>VATEX-EU-AE</cbc:TaxExemptionReasonCode>',
      'ubl:<cac:PartyTaxScheme><cbc:CompanyID>DE987654320</cbc:CompanyID>',
      'cii:<ram:CategoryCode>AE</ram:CategoryCode>',
      'cii:<ram:ExemptionReasonCode>VATEX-EU-AE</ram:ExemptionReasonCode>',
      'cii:<ram:SpecifiedTaxRegistration><ram:ID schemeID="VA">DE987654320</ram:ID>'], []);
  finally
    Inv.Free;
  end;
end;

{ BG-23 / BR-IC: intra-community supply to France, buyer VAT identifier,
  delivery date (BR-IC-11), deliver-to country (BT-80, BR-IC-12; XRechnung
  then needs city and post code, BR-DE-10/11), rate 0, exemption reason. }
procedure TestVatIntraCommunity;
var
  Inv: TLandrixInvoice;
begin
  Inv := TLandrixInvoice.Create;
  try
    FillBase(Inv);
    Inv.AccountingCustomerParty.Address.City := 'Paris';
    Inv.AccountingCustomerParty.Address.PostalZone := '75001';
    Inv.AccountingCustomerParty.Address.CountryCode := 'FR';
    Inv.AccountingCustomerParty.VATCompanyID := 'FR12345678901';
    Inv.DeliveryInformation.ActualDeliveryDate := EncodeDate(2026, 10, 15);
    Inv.DeliveryInformation.Address.City := 'Paris';
    Inv.DeliveryInformation.Address.PostalZone := '75001';
    Inv.DeliveryInformation.Address.CountryCode := 'FR';
    SetSingleCategory(Inv, idtfcc_K_VATExemptForEEAIntracommunitySupplyOfGoodsAndServices, 0,
      'Innergemeinschaftliche Lieferung', 'VATEX-EU-IC');
    RunCase('vat-k', Inv, ['ubl:<cbc:ID>K</cbc:ID>', 'cii:<ram:CategoryCode>K</ram:CategoryCode>',
      'ubl:<cbc:ActualDeliveryDate>2026-10-15</cbc:ActualDeliveryDate>',
      'ubl:<cac:DeliveryLocation><cac:Address><cbc:CityName>Paris</cbc:CityName><cbc:PostalZone>75001</cbc:PostalZone>' +
      '<cac:Country><cbc:IdentificationCode>FR</cbc:IdentificationCode>',
      'cii:<ram:ShipToTradeParty><ram:PostalTradeAddress><ram:PostcodeCode>75001</ram:PostcodeCode>' +
      '<ram:CityName>Paris</ram:CityName><ram:CountryID>FR</ram:CountryID>',
      'cii:<ram:ExemptionReasonCode>VATEX-EU-IC</ram:ExemptionReasonCode>',
      'cii:<ram:ID schemeID="VA">FR12345678901</ram:ID>'], []);
  finally
    Inv.Free;
  end;
end;

{ BG-23 / BR-O: not subject to VAT: no VAT identifier of seller or buyer
  (BR-O-02), the seller identified by legal registration and tax number,
  exemption reason (BR-O-10), a document charge of 5.00 without VAT rate
  (BR-O-07). Net and gross 105.00. }
procedure TestVatNotSubject;
var
  Inv: TLandrixInvoice;
  Charge: TLandrixInvoiceAllowanceCharge;
begin
  Inv := TLandrixInvoice.Create;
  try
    FillBase(Inv);
    Inv.AccountingSupplierParty.VATCompanyID := '';
    Inv.AccountingSupplierParty.VATCompanyNumber := '123/456/78901';
    Inv.AccountingSupplierParty.CompanyID := 'HRB 12345';
    SetSingleCategory(Inv, idtfcc_O_ServicesOutsideScopeOfTax, 0, 'Nicht steuerbar', 'VATEX-EU-O');
    Charge := Inv.AllowanceCharges.AddAllowanceCharge;
    Charge.ChargeIndicator := True;
    Charge.ReasonCodeCharge := issdc_FC_FreightService;
    Charge.Reason := 'Fracht';
    Charge.Amount := Cents(500);
    Charge.TaxCategory := idtfcc_O_ServicesOutsideScopeOfTax;
    Inv.ChargeTotalAmount := Cents(500);
    Inv.TaxExclusiveAmount := Cents(10500);
    Inv.TaxAmountSubtotals[0].TaxableAmount := Cents(10500);
    Inv.TaxInclusiveAmount := Cents(10500);
    Inv.PayableAmount := Cents(10500);
    RunCase('vat-o', Inv, ['ubl:<cbc:ID>O</cbc:ID>', 'cii:<ram:CategoryCode>O</ram:CategoryCode>',
      'ubl:<cbc:Amount currencyID="EUR">5.00</cbc:Amount><cac:TaxCategory><cbc:ID>O</cbc:ID><cac:TaxScheme>',
      'cii:<ram:CategoryTradeTax><ram:TypeCode>VAT</ram:TypeCode><ram:CategoryCode>O</ram:CategoryCode>' +
      '</ram:CategoryTradeTax>',
      'ubl:<cbc:CompanyID>123/456/78901</cbc:CompanyID>', 'cii:<ram:ID schemeID="FC">123/456/78901</ram:ID>',
      'cii:<ram:ExemptionReasonCode>VATEX-EU-O</ram:ExemptionReasonCode>'], []);
  finally
    Inv.Free;
  end;
end;

{ BG-23 with two rates and a line allowance (BG-27): line 1 2 x 50.00 less
  10.00 = 90.00 at 19 % (VAT 17.10), line 2 1 x 50.00 at 7 % (VAT 3.50);
  net 140.00, VAT 20.60, gross 160.60 (BR-CO-10, BR-S-08, BR-S-09). }
procedure TestMixedRatesWithLineAllowance;
var
  Inv: TLandrixInvoice;
  Line: TLandrixInvoiceLine;
  Charge: TLandrixInvoiceAllowanceCharge;
  Subtotal: TLandrixInvoiceTaxAmount;
begin
  Inv := TLandrixInvoice.Create;
  try
    FillBase(Inv);
    Line := Inv.InvoiceLines[0];
    Line.LineAmount := Cents(9000);
    Charge := Line.AllowanceCharges.AddAllowanceCharge;
    Charge.ChargeIndicator := False;
    Charge.ReasonCodeAllowance := iacic_Discount;
    Charge.Reason := 'Positionsrabatt';
    Charge.Amount := Cents(1000);
    Line := Inv.InvoiceLines.AddInvoiceLine;
    Line.ID := '2';
    Line.Name := 'Book';
    Line.Quantity := 1;
    Line.UnitCode := iuc_piece;
    Line.NetPriceAmount := 50;
    Line.LineAmount := Cents(5000);
    Line.TaxCategory := idtfcc_S_StandardRate;
    Line.TaxPercent := 7;
    Inv.TaxAmountSubtotals[0].TaxableAmount := Cents(9000);
    Inv.TaxAmountSubtotals[0].TaxAmount := Cents(1710);
    Subtotal := Inv.TaxAmountSubtotals.AddTaxAmount;
    Subtotal.TaxCategory := idtfcc_S_StandardRate;
    Subtotal.TaxPercent := 7;
    Subtotal.TaxableAmount := Cents(5000);
    Subtotal.TaxAmount := Cents(350);
    Inv.LineAmount := Cents(14000);
    Inv.TaxExclusiveAmount := Cents(14000);
    Inv.TaxAmountTotal := Cents(2060);
    Inv.TaxInclusiveAmount := Cents(16060);
    Inv.PayableAmount := Cents(16060);
    RunCase('vat-mixed', Inv, ['ubl:<cbc:TaxAmount currencyID="EUR">17.10</cbc:TaxAmount>',
      'ubl:<cbc:TaxAmount currencyID="EUR">3.50</cbc:TaxAmount>',
      'ubl:<cbc:LineExtensionAmount currencyID="EUR">90.00</cbc:LineExtensionAmount>',
      'cii:<ram:CalculatedAmount>17.10</ram:CalculatedAmount>', 'cii:<ram:CalculatedAmount>3.50</ram:CalculatedAmount>',
      'cii:<ram:LineTotalAmount>90.00</ram:LineTotalAmount>', 'all:Positionsrabatt'], []);
  finally
    Inv.Free;
  end;
end;

{ --- cases: totals, allowances and charges ------------------------------------ }

{ BG-20 / BG-21: document allowance of 10 % of 100.00 (reason code 95) and a
  freight charge of 5.00 (FC), both at 19 %. Totals: lines 100.00,
  allowances 10.00, charges 5.00, net 95.00, VAT 18.05, gross 113.05. }
procedure TestDocumentAllowanceCharge;
var
  Inv: TLandrixInvoice;
  Charge: TLandrixInvoiceAllowanceCharge;
begin
  Inv := TLandrixInvoice.Create;
  try
    FillBase(Inv);
    Charge := Inv.AllowanceCharges.AddAllowanceCharge;
    Charge.ChargeIndicator := False;
    Charge.ReasonCodeAllowance := iacic_Discount;
    Charge.Reason := 'Rabatt';
    Charge.BaseAmount := Cents(10000);
    Charge.MultiplierFactorNumeric := 10;
    Charge.Amount := Cents(1000);
    Charge.TaxCategory := idtfcc_S_StandardRate;
    Charge.TaxPercent := 19;
    Charge := Inv.AllowanceCharges.AddAllowanceCharge;
    Charge.ChargeIndicator := True;
    Charge.ReasonCodeCharge := issdc_FC_FreightService;
    Charge.Reason := 'Fracht';
    Charge.Amount := Cents(500);
    Charge.TaxCategory := idtfcc_S_StandardRate;
    Charge.TaxPercent := 19;
    Inv.AllowanceTotalAmount := Cents(1000);
    Inv.ChargeTotalAmount := Cents(500);
    Inv.TaxExclusiveAmount := Cents(9500);
    Inv.TaxAmountSubtotals[0].TaxableAmount := Cents(9500);
    Inv.TaxAmountSubtotals[0].TaxAmount := Cents(1805);
    Inv.TaxAmountTotal := Cents(1805);
    Inv.TaxInclusiveAmount := Cents(11305);
    Inv.PayableAmount := Cents(11305);
    RunCase('allowance-charge', Inv, ['ubl:<cbc:ChargeIndicator>false</cbc:ChargeIndicator>' +
      '<cbc:AllowanceChargeReasonCode>95</cbc:AllowanceChargeReasonCode>',
      'ubl:<cbc:ChargeIndicator>true</cbc:ChargeIndicator><cbc:AllowanceChargeReasonCode>FC</cbc:AllowanceChargeReasonCode>',
      'ubl:<cbc:BaseAmount currencyID="EUR">100.00</cbc:BaseAmount>',
      'ubl:<cbc:AllowanceTotalAmount currencyID="EUR">10.00</cbc:AllowanceTotalAmount>',
      'ubl:<cbc:ChargeTotalAmount currencyID="EUR">5.00</cbc:ChargeTotalAmount>',
      'ubl:<cbc:TaxExclusiveAmount currencyID="EUR">95.00</cbc:TaxExclusiveAmount>',
      'cii:<ram:ReasonCode>95</ram:ReasonCode>', 'cii:<ram:ReasonCode>FC</ram:ReasonCode>',
      'cii:<ram:CalculationPercent>10', 'cii:<ram:BasisAmount>100.00</ram:BasisAmount>',
      'cii:<ram:AllowanceTotalAmount>10.00</ram:AllowanceTotalAmount>',
      'cii:<ram:ChargeTotalAmount>5.00</ram:ChargeTotalAmount>',
      'cii:<ram:TaxBasisTotalAmount>95.00</ram:TaxBasisTotalAmount>'], []);
  finally
    Inv.Free;
  end;
end;

{ BG-22: paid amount 50.00 (BT-113) and rounding 0.01 (BT-114); amount due
  119.00 - 50.00 + 0.01 = 69.01 (BR-CO-16). A paid amount of 0 is not
  written. }
procedure TestPrepaidAndRounding;
var
  Inv: TLandrixInvoice;
  T: TCaseTarget;
  D: TLandrixEInvoiceDiagnostics;
begin
  Inv := TLandrixInvoice.Create;
  try
    FillBase(Inv);
    Inv.PrepaidAmount := Cents(5000);
    Inv.PayableRoundingAmount := Cents(1);
    Inv.PayableAmount := Cents(6901);
    RunCase('prepaid-rounding', Inv, ['ubl:<cbc:PrepaidAmount currencyID="EUR">50.00</cbc:PrepaidAmount>',
      'ubl:<cbc:PayableRoundingAmount currencyID="EUR">0.01</cbc:PayableRoundingAmount>',
      'ubl:<cbc:PayableAmount currencyID="EUR">69.01</cbc:PayableAmount>',
      'cii:<ram:TotalPrepaidAmount>50.00</ram:TotalPrepaidAmount>',
      'cii:<ram:RoundingAmount>0.01</ram:RoundingAmount>',
      'cii:<ram:DuePayableAmount>69.01</ram:DuePayableAmount>'], []);
    Inv.PrepaidAmount := 0;
    Inv.PayableAmount := Cents(11901);
    for T := Low(TCaseTarget) to High(TCaseTarget) do
    begin
      D := TLandrixEInvoiceDiagnostics.Create;
      try
        Check(Pos('PrepaidAmount', LandrixXmlUtf8ToString(WriteTarget(Inv, T, D))) = 0,
          TargetSuffix[T] + ': no BT-113 at 0');
      finally
        D.Free;
      end;
    end;
  finally
    Inv.Free;
  end;
end;

{ BT-6 / BT-111: VAT accounting currency USD with the VAT total in it
  (BR-53). }
procedure TestTaxCurrency;
var
  Inv: TLandrixInvoice;
begin
  Inv := TLandrixInvoice.Create;
  try
    FillBase(Inv);
    Inv.TaxCurrencyCode := 'USD';
    Inv.TaxAmountTotalInTaxCurrency.SetValue(Cents(2210));
    RunCase('tax-currency', Inv, ['ubl:<cbc:TaxCurrencyCode>USD</cbc:TaxCurrencyCode>',
      'ubl:<cac:TaxTotal><cbc:TaxAmount currencyID="USD">22.10</cbc:TaxAmount></cac:TaxTotal>',
      'cii:<ram:TaxCurrencyCode>USD</ram:TaxCurrencyCode>',
      'cii:<ram:TaxTotalAmount currencyID="USD">22.10</ram:TaxTotalAmount>'], []);
  finally
    Inv.Free;
  end;
end;

{ --- cases: payment ----------------------------------------------------------- }

{ BG-16 / BT-81: payment means codes beside SEPA. }
procedure RunPaymentMeans(ACode: TLandrixInvoicePaymentMeansCode; const AName, ACodeText,
  AAccount: string; const AExtra: array of string);
var
  Inv: TLandrixInvoice;
  Expect: array of string;
  I: Integer;
begin
  Expect := nil;
  Inv := TLandrixInvoice.Create;
  try
    FillBase(Inv);
    Inv.PaymentTypes[0].PaymentMeansCode := ACode;
    Inv.PaymentTypes[0].FinancialAccount := TLandrixEInvoiceString(AAccount);
    if AAccount = '' then
      Inv.PaymentTypes[0].FinancialAccountName := '';
    SetLength(Expect, 2 + Integer(High(AExtra)) + 1);
    Expect[0] := 'ubl:<cbc:PaymentMeansCode>' + ACodeText + '</cbc:PaymentMeansCode>';
    Expect[1] := 'cii:<ram:TypeCode>' + ACodeText + '</ram:TypeCode>';
    for I := 0 to Integer(High(AExtra)) do
      Expect[2 + I] := AExtra[I];
    RunCase(AName, Inv, Expect, []);
  finally
    Inv.Free;
  end;
end;

{ Credit transfer 30 with an account that is no IBAN: BT-84 is
  ram:ProprietaryID in CII and cbc:ID in UBL. }
procedure TestPaymentMeans;
begin
  RunPaymentMeans(ipmc_InCash, 'payment-10', '10', '', []);
  RunPaymentMeans(ipmc_CreditTransfer, 'payment-30', '30', '12345678',
    ['cii:<ram:AccountName>Seller GmbH</ram:AccountName><ram:ProprietaryID>12345678</ram:ProprietaryID>',
     'ubl:<cac:PayeeFinancialAccount><cbc:ID>12345678</cbc:ID>']);
  RunPaymentMeans(ipmc_PaymentToBankAccount, 'payment-42', '42', 'DE75512108001245126199',
    ['cii:<ram:IBANID>DE75512108001245126199</ram:IBANID>']);
  RunPaymentMeans(ipmc_StandingAgreement, 'payment-57', '57', '', []);
  RunPaymentMeans(ipmc_ClearingBetweenPartners, 'payment-97', '97', '', []);
  RunPaymentMeans(ipmc_MutuallyDefined, 'payment-zzz', 'ZZZ', '', []);
end;

{ BG-19 SEPA direct debit (59): mandate (BT-89), creditor identifier
  (BT-90, seller), debited account (BT-91); BR-DE-29 to BR-DE-31. }
procedure TestDirectDebit;
var
  Inv: TLandrixInvoice;
begin
  Inv := TLandrixInvoice.Create;
  try
    FillBase(Inv);
    Inv.PaymentTypes[0].PaymentMeansCode := ipmc_SEPADirectDebit;
    Inv.PaymentTypes[0].FinancialAccount := 'DE02120300000000202051';
    Inv.PaymentTypes[0].FinancialAccountName := '';
    Inv.PaymentMandateID := 'MANDAT-1';
    Inv.AccountingSupplierParty.BankAssignedCreditorIdentifier := 'DE98ZZZ09999999999';
    RunCase('direct-debit', Inv, ['ubl:<cbc:PaymentMeansCode>59</cbc:PaymentMeansCode>',
      'ubl:<cac:PaymentMandate><cbc:ID>MANDAT-1</cbc:ID><cac:PayerFinancialAccount><cbc:ID>DE02120300000000202051</cbc:ID>',
      'ubl:<cac:PartyIdentification><cbc:ID schemeID="SEPA">DE98ZZZ09999999999</cbc:ID>',
      'cii:<ram:CreditorReferenceID>DE98ZZZ09999999999</ram:CreditorReferenceID>',
      'cii:<ram:DirectDebitMandateID>MANDAT-1</ram:DirectDebitMandateID>',
      'cii:<ram:PayerPartyDebtorFinancialAccount><ram:IBANID>DE02120300000000202051</ram:IBANID>'], []);
  finally
    Inv.Free;
  end;
end;

{ BG-18 payment card (54): primary account number (BT-87, only the last
  digits) and holder (BT-88); BR-DE-24. }
procedure TestPaymentCard;
var
  Inv: TLandrixInvoice;
begin
  Inv := TLandrixInvoice.Create;
  try
    FillBase(Inv);
    Inv.PaymentTypes[0].PaymentMeansCode := ipmc_CreditCard;
    Inv.PaymentTypes[0].FinancialAccount := '1234';
    Inv.PaymentTypes[0].FinancialAccountName := 'Anna Buyer';
    RunCase('payment-card', Inv, ['ubl:<cac:CardAccount><cbc:PrimaryAccountNumberID>1234</cbc:PrimaryAccountNumberID>',
      'ubl:<cbc:HolderName>Anna Buyer</cbc:HolderName>',
      'cii:<ram:ApplicableTradeSettlementFinancialCard><ram:ID>1234</ram:ID>' +
      '<ram:CardholderName>Anna Buyer</ram:CardholderName>'], []);
  finally
    Inv.Free;
  end;
end;

{ BT-20 cash discount of 2 % within 10 days next to the net note:
  XRechnung as '#SKONTO#' line followed by the net note (BR-DE-18),
  Factur-X EXTENDED as structured discount terms besides the net term. }
procedure TestCashDiscount;
var
  Inv: TLandrixInvoice;
begin
  Inv := TLandrixInvoice.Create;
  try
    FillBase(Inv);
    Inv.PaymentTermsType := iptt_CashDiscount1;
    Inv.PaymentTermCashDiscount1Days := 10;
    Inv.PaymentTermCashDiscount1Percent := 2;
    RunCase('cash-discount', Inv, ['xr:#SKONTO#TAGE=10#PROZENT=2.00#' + #10 + 'Zahlbar bis 18.11.2026 ohne Abzug.',
      'ext:<ram:BasisPeriodMeasure unitCode="DAY">10</ram:BasisPeriodMeasure>'], []);
  finally
    Inv.Free;
  end;
end;

{ --- cases: parties ----------------------------------------------------------- }

{ BG-6 seller contact with a department instead of a person name: CII
  ram:DepartmentName, UBL the contact point cbc:Name (BT-41; BR-DE-5).
  Reading UBL gives the department as contact name. }
procedure TestContactDepartment;
var
  Inv: TLandrixInvoice;
begin
  Inv := TLandrixInvoice.Create;
  try
    FillBase(Inv);
    Inv.AccountingSupplierParty.ContactName := '';
    Inv.AccountingSupplierParty.ContactDepartment := 'Buchhaltung';
    RunCase('contact-department', Inv, ['ubl:<cac:Contact><cbc:Name>Buchhaltung</cbc:Name>',
      'cii:<ram:DefinedTradeContact><ram:DepartmentName>Buchhaltung</ram:DepartmentName>'],
      ['-ubl-30x.xml compare AccountingSupplierParty.Contact', '-ubl-peppol.xml compare AccountingSupplierParty.Contact']);
  finally
    Inv.Free;
  end;
end;

{ BG-10 payee (BT-59, BT-60 with scheme) and BG-11 tax representative
  (BT-62, BT-63, BG-12; BR-56, BR-57). }
procedure TestPayeeAndTaxRepresentative;
var
  Inv: TLandrixInvoice;
begin
  Inv := TLandrixInvoice.Create;
  try
    FillBase(Inv);
    Inv.PayeeParty.Name := 'Factoring AG';
    Inv.PayeeParty.Identifier := '4000001000005';
    Inv.PayeeParty.IdentifierSchemeID := '0088';
    Inv.TaxRepresentativeParty.Name := 'Fiskalvertreter GmbH';
    Inv.TaxRepresentativeParty.VATCompanyID := 'DE111111125';
    Inv.TaxRepresentativeParty.Address.StreetName := 'Vertreterweg 3';
    Inv.TaxRepresentativeParty.Address.City := 'Koeln';
    Inv.TaxRepresentativeParty.Address.PostalZone := '50667';
    Inv.TaxRepresentativeParty.Address.CountryCode := 'DE';
    RunCase('payee-taxrep', Inv, ['ubl:<cac:PayeeParty><cac:PartyIdentification><cbc:ID schemeID="0088">4000001000005</cbc:ID>',
      'ubl:<cac:PartyName><cbc:Name>Factoring AG</cbc:Name>',
      'ubl:<cac:TaxRepresentativeParty><cac:PartyName><cbc:Name>Fiskalvertreter GmbH</cbc:Name>',
      'cii:<ram:PayeeTradeParty><ram:GlobalID schemeID="0088">4000001000005</ram:GlobalID><ram:Name>Factoring AG</ram:Name>',
      'cii:<ram:SellerTaxRepresentativeTradeParty><ram:Name>Fiskalvertreter GmbH</ram:Name>',
      'cii:<ram:ID schemeID="VA">DE111111125</ram:ID>'], []);
  finally
    Inv.Free;
  end;
end;

{ BG-13 / BG-15: deliver-to party with name (BT-70), location (BT-71 with
  scheme 0088), address and delivery date (BT-72). }
procedure TestDelivery;
var
  Inv: TLandrixInvoice;
  Delivery: TLandrixInvoiceDeliveryInformation;
begin
  Inv := TLandrixInvoice.Create;
  try
    FillBase(Inv);
    Delivery := Inv.DeliveryInformation;
    Delivery.Name := 'Lager Nord';
    Delivery.LocationIdentifier := '4000001000005';
    Delivery.LocationIdentifierSchemeID := '0088';
    Delivery.Address.StreetName := 'Lagerstrasse 9';
    Delivery.Address.City := 'Kiel';
    Delivery.Address.PostalZone := '24103';
    Delivery.Address.CountryCode := 'DE';
    Delivery.ActualDeliveryDate := EncodeDate(2026, 10, 15);
    RunCase('delivery', Inv, ['ubl:<cac:Delivery><cbc:ActualDeliveryDate>2026-10-15</cbc:ActualDeliveryDate>' +
      '<cac:DeliveryLocation><cbc:ID schemeID="0088">4000001000005</cbc:ID>',
      'ubl:<cac:DeliveryParty><cac:PartyName><cbc:Name>Lager Nord</cbc:Name>',
      'ubl:<cbc:CityName>Kiel</cbc:CityName>',
      'cii:<ram:ShipToTradeParty><ram:GlobalID schemeID="0088">4000001000005</ram:GlobalID><ram:Name>Lager Nord</ram:Name>',
      'cii:<ram:ActualDeliverySupplyChainEvent><ram:OccurrenceDateTime><udt:DateTimeString format="102">20261015<',
      'cii:<ram:CityName>Kiel</ram:CityName>'], []);
  finally
    Inv.Free;
  end;
end;

{ --- cases: document --------------------------------------------------------- }

{ BT-3 = 381 credit note with a preceding invoice reference (BG-3, BT-25,
  BT-26); UBL root CreditNote, no due date (XRechnung). }
procedure TestCreditNote;
var
  Inv: TLandrixInvoice;
  Reference: TLandrixInvoicePrecedingInvoiceReference;
begin
  Inv := TLandrixInvoice.Create;
  try
    FillBase(Inv);
    Inv.InvoiceTypeCode := itc_CreditNote;
    Inv.InvoiceDueDate := 0;
    Inv.PaymentTermNetNote := 'Gutschrift wird ueberwiesen.';
    Reference := Inv.PrecedingInvoiceReferences.AddPrecedingInvoiceReference;
    Reference.ID := 'R-2026-0815';
    Reference.IssueDate := EncodeDate(2026, 9, 1);
    RunCase('credit-note', Inv, ['ubl:<cbc:CreditNoteTypeCode>381</cbc:CreditNoteTypeCode>',
      'ubl:<cac:BillingReference><cac:InvoiceDocumentReference><cbc:ID>R-2026-0815</cbc:ID>' +
      '<cbc:IssueDate>2026-09-01</cbc:IssueDate>',
      'ubl:<cac:CreditNoteLine>',
      'cii:<ram:TypeCode>381</ram:TypeCode>',
      'cii:<ram:InvoiceReferencedDocument><ram:IssuerAssignedID>R-2026-0815</ram:IssuerAssignedID>' +
      '<ram:FormattedIssueDateTime><qdt:DateTimeString format="102">20260901<'], []);
  finally
    Inv.Free;
  end;
end;

{ BG-1: notes with subject codes (BT-21, BT-22; UNTDID 4451). }
procedure TestNotes;
var
  Inv: TLandrixInvoice;
  Note: TLandrixInvoiceNote;
begin
  Inv := TLandrixInvoice.Create;
  try
    FillBase(Inv);
    Note := Inv.Notes.AddNote;
    Note.Content := 'Allgemeine Information';
    Note.SubjectCode := insc_AAI;
    Note := Inv.Notes.AddNote;
    Note.Content := 'Geschaeftsfuehrer: Anna Seller';
    Note.SubjectCode := insc_REG;
    RunCase('notes', Inv, ['ubl:<cbc:Note>#AAI#Allgemeine Information</cbc:Note>',
      'ubl:<cbc:Note>#REG#Geschaeftsfuehrer: Anna Seller</cbc:Note>',
      'cii:<ram:IncludedNote><ram:Content>Allgemeine Information</ram:Content><ram:SubjectCode>AAI</ram:SubjectCode>',
      'cii:<ram:IncludedNote><ram:Content>Geschaeftsfuehrer: Anna Seller</ram:Content><ram:SubjectCode>REG</ram:SubjectCode>'],
      []);
  finally
    Inv.Free;
  end;
end;

{ BG-24: an external document reference (BT-122, BT-123, BT-124). }
procedure TestAttachmentReference;
var
  Inv: TLandrixInvoice;
  Attachment: TLandrixInvoiceAttachment;
begin
  Inv := TLandrixInvoice.Create;
  try
    FillBase(Inv);
    Attachment := Inv.Attachments.AddAttachment(iat_application_None);
    Attachment.ID := 'DOC-1';
    Attachment.DocumentDescription := 'Leistungsnachweis';
    Attachment.ExternalReference := 'https://example.com/doc.pdf';
    RunCase('attachment-reference', Inv, ['ubl:<cac:AdditionalDocumentReference><cbc:ID>DOC-1</cbc:ID>',
      'ubl:<cbc:DocumentDescription>Leistungsnachweis</cbc:DocumentDescription>',
      'ubl:<cac:ExternalReference><cbc:URI>https://example.com/doc.pdf</cbc:URI>',
      'cii:<ram:AdditionalReferencedDocument><ram:IssuerAssignedID>DOC-1</ram:IssuerAssignedID>' +
      '<ram:URIID>https://example.com/doc.pdf</ram:URIID><ram:TypeCode>916</ram:TypeCode>' +
      '<ram:Name>Leistungsnachweis</ram:Name>'], []);
  finally
    Inv.Free;
  end;
end;

{ BG-24: an embedded PDF (BT-125 with mime code and file name). }
procedure TestAttachmentEmbedded;
var
  Inv: TLandrixInvoice;
  Attachment: TLandrixInvoiceAttachment;
begin
  Inv := TLandrixInvoice.Create;
  try
    FillBase(Inv);
    Attachment := Inv.Attachments.AddAttachment(iat_application_pdf);
    Attachment.ID := 'ANL-1';
    Attachment.DocumentDescription := 'Stundennachweis';
    Attachment.Filename := 'stunden.pdf';
    Attachment.EmbedDataFromText(TLandrixEInvoiceString('%PDF-1.4 test'));
    RunCase('attachment-embedded', Inv, ['all:mimeCode="application/pdf"', 'all:filename="stunden.pdf"',
      'ubl:<cac:AdditionalDocumentReference><cbc:ID>ANL-1</cbc:ID>',
      'ubl:<cac:Attachment><cbc:EmbeddedDocumentBinaryObject ',
      'cii:<ram:AdditionalReferencedDocument><ram:IssuerAssignedID>ANL-1</ram:IssuerAssignedID>' +
      '<ram:TypeCode>916</ram:TypeCode><ram:Name>Stundennachweis</ram:Name><ram:AttachmentBinaryObject '], []);
  finally
    Inv.Free;
  end;
end;

{ --- cases: lines ------------------------------------------------------------- }

{ BG-25: line details BT-127 note, BT-128 object identifier with scheme,
  BT-133 accounting reference, BT-155/BT-156 item identifiers, BT-158
  classification with list, BT-159 country of origin, BG-32 item attribute,
  BG-26 line period. }
procedure TestLineDetails;
var
  Inv: TLandrixInvoice;
  Line: TLandrixInvoiceLine;
  Classification: TLandrixInvoiceLineItemClassification;
  Attribute: TLandrixInvoiceLineItemAttribute;
begin
  Inv := TLandrixInvoice.Create;
  try
    FillBase(Inv);
    Line := Inv.InvoiceLines[0];
    Line.Note := 'Positionshinweis';
    Line.ObjectIdentifier := 'OBJ-4711';
    Line.ObjectIdentifierSchemeID := 'ABZ';
    Line.BuyerAccountingReference := 'KST-100';
    Line.SellersItemIdentification := 'S-100';
    Line.BuyersItemIdentification := 'B-200';
    Line.Description := 'Beschreibung';
    Line.OriginTradeCountry := 'FR';
    Classification := Line.ItemClassifications.AddItemClassification;
    Classification.ClassCode := '0123';
    Classification.ListID := 'TST';
    Attribute := Line.ItemAttributes.AddItemAttribute;
    Attribute.Name := 'Farbe';
    Attribute.Value := 'Rot';
    Line.InvoiceLinePeriodStartDate := EncodeDate(2026, 9, 1);
    Line.InvoiceLinePeriodEndDate := EncodeDate(2026, 9, 30);
    RunCase('line-details', Inv, ['ubl:<cbc:Note>Positionshinweis</cbc:Note>',
      'ubl:<cac:DocumentReference><cbc:ID schemeID="ABZ">OBJ-4711</cbc:ID><cbc:DocumentTypeCode>130</cbc:DocumentTypeCode>',
      'ubl:<cbc:AccountingCost>KST-100</cbc:AccountingCost>',
      'ubl:<cac:InvoicePeriod><cbc:StartDate>2026-09-01</cbc:StartDate><cbc:EndDate>2026-09-30</cbc:EndDate>',
      'ubl:<cac:BuyersItemIdentification><cbc:ID>B-200</cbc:ID>',
      'ubl:<cac:SellersItemIdentification><cbc:ID>S-100</cbc:ID>',
      'ubl:<cac:OriginCountry><cbc:IdentificationCode>FR</cbc:IdentificationCode>',
      'ubl:<cac:CommodityClassification><cbc:ItemClassificationCode listID="TST">0123</cbc:ItemClassificationCode>',
      'ubl:<cac:AdditionalItemProperty><cbc:Name>Farbe</cbc:Name><cbc:Value>Rot</cbc:Value>',
      'cii:<ram:IncludedNote><ram:Content>Positionshinweis</ram:Content>',
      'cii:<ram:SellerAssignedID>S-100</ram:SellerAssignedID><ram:BuyerAssignedID>B-200</ram:BuyerAssignedID>',
      'cii:<ram:ApplicableProductCharacteristic><ram:Description>Farbe</ram:Description><ram:Value>Rot</ram:Value>',
      'cii:<ram:DesignatedProductClassification><ram:ClassCode listID="TST">0123</ram:ClassCode>',
      'cii:<ram:OriginTradeCountry><ram:ID>FR</ram:ID>',
      'cii:<ram:BillingSpecifiedPeriod><ram:StartDateTime><udt:DateTimeString format="102">20260901<',
      'cii:<ram:AdditionalReferencedDocument><ram:IssuerAssignedID>OBJ-4711</ram:IssuerAssignedID>' +
      '<ram:TypeCode>130</ram:TypeCode><ram:ReferenceTypeCode>ABZ</ram:ReferenceTypeCode>',
      'cii:<ram:ReceivableSpecifiedTradeAccountingAccount><ram:ID>KST-100</ram:ID>'], []);
  finally
    Inv.Free;
  end;
end;

{ BG-29: gross price 60.00 less a price discount of 10.00 (BT-147, BT-148)
  gives the net price 50.00 per 1 piece (BT-149, BT-150). }
procedure TestGrossPrice;
var
  Inv: TLandrixInvoice;
  Line: TLandrixInvoiceLine;
begin
  Inv := TLandrixInvoice.Create;
  try
    FillBase(Inv);
    Line := Inv.InvoiceLines[0];
    Line.GrossPriceAmount := 60;
    Line.DiscountOnTheGrossPrice := 10;
    Line.BaseQuantity := 1;
    Line.BaseQuantityUnitCode := iuc_piece;
    RunCase('gross-price', Inv, ['ubl:<cac:Price><cbc:PriceAmount currencyID="EUR">50.00</cbc:PriceAmount>' +
      '<cbc:BaseQuantity unitCode="H87">1',
      'ubl:<cbc:ChargeIndicator>false</cbc:ChargeIndicator><cbc:Amount currencyID="EUR">10.00</cbc:Amount>' +
      '<cbc:BaseAmount currencyID="EUR">60.00</cbc:BaseAmount>',
      'cii:<ram:GrossPriceProductTradePrice><ram:ChargeAmount>60.00</ram:ChargeAmount>',
      'cii:<ram:ActualAmount>10.00</ram:ActualAmount>',
      'cii:<ram:NetPriceProductTradePrice><ram:ChargeAmount>50.00</ram:ChargeAmount>' +
      '<ram:BasisQuantity unitCode="H87">1'], []);
  finally
    Inv.Free;
  end;
end;

{ BG-25: a negative line (quantity -1, BT-129/BT-131 negative) next to a
  line of 3 x 100.00; lines 200.00, VAT 38.00. }
procedure TestNegativeLine;
var
  Inv: TLandrixInvoice;
  Line: TLandrixInvoiceLine;
begin
  Inv := TLandrixInvoice.Create;
  try
    FillBase(Inv);
    Inv.InvoiceLines[0].Quantity := 3;
    Inv.InvoiceLines[0].NetPriceAmount := 100;
    Inv.InvoiceLines[0].LineAmount := Cents(30000);
    Line := Inv.InvoiceLines.AddInvoiceLine;
    Line.ID := '2';
    Line.Name := 'Return';
    Line.Quantity := -1;
    Line.UnitCode := iuc_piece;
    Line.NetPriceAmount := 100;
    Line.LineAmount := Cents(-10000);
    Line.TaxCategory := idtfcc_S_StandardRate;
    Line.TaxPercent := 19;
    Inv.LineAmount := Cents(20000);
    Inv.TaxExclusiveAmount := Cents(20000);
    Inv.TaxAmountSubtotals[0].TaxableAmount := Cents(20000);
    Inv.TaxAmountSubtotals[0].TaxAmount := Cents(3800);
    Inv.TaxAmountTotal := Cents(3800);
    Inv.TaxInclusiveAmount := Cents(23800);
    Inv.PayableAmount := Cents(23800);
    RunCase('negative-line', Inv, ['ubl:<cbc:InvoicedQuantity unitCode="H87">-1',
      'ubl:<cbc:LineExtensionAmount currencyID="EUR">-100.00</cbc:LineExtensionAmount>',
      'cii:<ram:BilledQuantity unitCode="H87">-1', 'cii:<ram:LineTotalAmount>-100.00</ram:LineTotalAmount>'], []);
  finally
    Inv.Free;
  end;
end;

procedure Register;
begin
  RegisterTest('Cases.VatZeroRated', TestVatZeroRated);
  RegisterTest('Cases.VatExempt', TestVatExempt);
  RegisterTest('Cases.VatExport', TestVatExport);
  RegisterTest('Cases.VatReverseCharge', TestVatReverseCharge);
  RegisterTest('Cases.VatIntraCommunity', TestVatIntraCommunity);
  RegisterTest('Cases.VatNotSubject', TestVatNotSubject);
  RegisterTest('Cases.MixedRatesWithLineAllowance', TestMixedRatesWithLineAllowance);
  RegisterTest('Cases.DocumentAllowanceCharge', TestDocumentAllowanceCharge);
  RegisterTest('Cases.PrepaidAndRounding', TestPrepaidAndRounding);
  RegisterTest('Cases.TaxCurrency', TestTaxCurrency);
  RegisterTest('Cases.PaymentMeans', TestPaymentMeans);
  RegisterTest('Cases.DirectDebit', TestDirectDebit);
  RegisterTest('Cases.PaymentCard', TestPaymentCard);
  RegisterTest('Cases.CashDiscount', TestCashDiscount);
  RegisterTest('Cases.ContactDepartment', TestContactDepartment);
  RegisterTest('Cases.PayeeAndTaxRepresentative', TestPayeeAndTaxRepresentative);
  RegisterTest('Cases.Delivery', TestDelivery);
  RegisterTest('Cases.CreditNote', TestCreditNote);
  RegisterTest('Cases.Notes', TestNotes);
  RegisterTest('Cases.AttachmentReference', TestAttachmentReference);
  RegisterTest('Cases.AttachmentEmbedded', TestAttachmentEmbedded);
  RegisterTest('Cases.LineDetails', TestLineDetails);
  RegisterTest('Cases.GrossPrice', TestGrossPrice);
  RegisterTest('Cases.NegativeLine', TestNegativeLine);
end;

end.
