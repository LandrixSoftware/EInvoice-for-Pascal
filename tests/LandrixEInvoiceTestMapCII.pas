{
  EInvoice-for-Pascal

  Copyright (C) 2026 Landrix Software GmbH & Co. KG

  This file is dual-licensed under:
  - GNU GPL version 3 or later; or
  - the Landrix Software Commercial License.

  See LICENSE and COMMERCIAL-LICENSE.md.

  SPDX-License-Identifier: GPL-3.0-or-later OR LicenseRef-Landrix-Commercial
}

{ Tests for LandrixEInvoiceMapCII against the golden files of
  XRechnung-for-Delphi (tests/data/local/golden/, git-ignored):
  - Golden write: every CII scenario of LandrixEInvoiceTestScenarios is
    mapped, written and compared with its golden file;
  - Golden read: every CII golden file is read, mapped to the invoice model,
    mapped back with the specification of its identifier, written and
    compared with itself; nothing may be reported as not mapped.
  Both are skipped when the local folders are missing. }

unit LandrixEInvoiceTestMapCII;

{$I LandrixEInvoice.inc}

interface

uses
  LandrixEInvoiceInvoice;

procedure Register;

{ Fills an invoice with every field added in Phase 2 (field comparison
  against the Factur-X 1.09.2 table); used by the CII and UBL tests. }
procedure FillPhase2(AInvoice: TLandrixInvoice);

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
  LandrixEInvoiceCII,
  LandrixEInvoiceCIIReader,
  LandrixEInvoiceCIIWriter,
  LandrixEInvoiceMapCII,
  LandrixEInvoiceTestFramework,
  LandrixEInvoiceTestXmlCompare,
  LandrixEInvoiceTestScenarios;

function LocalDir(const AName: string): string;
begin
  Result := RepositoryRoot + 'tests' + PathDelim + 'data' + PathDelim + 'local' + PathDelim +
    AName + PathDelim;
end;

function LoadFile(const FileName: string): TLandrixXmlUtf8;
var
  S: TFileStream;
begin
  Result := '';
  S := TFileStream.Create(FileName, fmOpenRead or fmShareDenyWrite);
  try
    SetLength(Result, Integer(S.Size));
    if S.Size > 0 then
      S.ReadBuffer(PAnsiChar(Result)^, Integer(S.Size));
  finally
    S.Free;
  end;
end;

function WriteCII(ACII: TLandrixCIIInvoice): TLandrixXmlUtf8;
var
  W: TLandrixXmlWriter;
begin
  W := TLandrixXmlWriter.Create;
  try
    W.Indent := True;
    LandrixEInvoiceWriteCII(ACII, W, nil);
    W.EndDocument;
    Result := W.AsUtf8;
  finally
    W.Free;
  end;
end;

function ReadCII(const AXml: TLandrixXmlUtf8; ADiagnostics: TLandrixEInvoiceDiagnostics): TLandrixCIIInvoice;
var
  R: TLandrixXmlReader;
begin
  R := TLandrixXmlReader.Create;
  try
    R.LoadFromUtf8(AXml);
    Result := LandrixEInvoiceReadCII(R, ADiagnostics);
  finally
    R.Free;
  end;
end;

{ Diagnostics of the given kinds, one per line. }
function DiagnosticsOf(D: TLandrixEInvoiceDiagnostics; AKinds: array of TLandrixEInvoiceDiagnosticKind): string;
var
  I: TLandrixEInvoiceListIndex;
  J: Integer;
begin
  Result := '';
  for I := 0 to D.Count - 1 do
    for J := 0 to Integer(High(AKinds)) do
      if D[I].Kind = AKinds[J] then
        Result := Result + '    ' + string(LandrixEInvoiceDiagnosticKindToStr(D[I].Kind)) + ' ' +
          string(D[I].Path) + ': ' + string(D[I].Message) + #13#10;
end;

type
  PGoldenState = ^TGoldenState;
  TGoldenState = record
    Dir: string;
    Files: Integer;
    Failed: Integer;
  end;

procedure GoldenSink(AInvoice: TLandrixInvoice; const ATarget: TLandrixEInvoiceTarget;
  const AFileName: string; AData: Pointer);
var
  State: PGoldenState;
  Spec: TLandrixEInvoiceSpec;
  CII: TLandrixCIIInvoice;
  D: TLandrixEInvoiceDiagnostics;
  Written: TLandrixXmlUtf8;
  Diff, Errors: string;
begin
  State := PGoldenState(AData);
  if not LandrixEInvoiceFindSpec(ATarget, Spec) or (Spec.Target.Syntax <> esy_CII) then
    Exit;
  Inc(State^.Files);
  D := TLandrixEInvoiceDiagnostics.Create;
  try
    CII := LandrixEInvoiceInvoiceToCII(AInvoice, Spec, D);
    try
      Written := WriteCII(CII);
    finally
      CII.Free;
    end;
    Errors := DiagnosticsOf(D, [edk_ConversionFailed, edk_MissingElement, edk_NotAllowed]);
    if not XmlEquivalent(LoadFile(State^.Dir + AFileName), GoldenView(AFileName, Written), Diff) then
    begin
      Inc(State^.Failed);
      WriteLn('  ', AFileName, ': ', Diff);
      if Errors <> '' then
        Write(Errors);
    end
    else if D.HasErrors then
    begin
      { the golden files are valid: an error means a rule is too strict }
      Inc(State^.Failed);
      WriteLn('  ', AFileName, ': errors reported');
      Write(Errors);
    end;
  finally
    D.Free;
  end;
end;

procedure TestGoldenWrite;
var
  State: TGoldenState;
begin
  State.Dir := LocalDir('golden');
  if not DirectoryExists(State.Dir) or not DirectoryExists(LocalDir('attachments')) then
  begin
    Skip('no local golden files or attachments');
    Exit;
  end;
  State.Files := 0;
  State.Failed := 0;
  RunAllScenarios(GoldenSink, @State, LocalDir('attachments'));
  CheckEquals(67, State.Files, 'CII outputs');
  CheckEquals(0, State.Failed, IntToStr(State.Files) + ' CII outputs, differences to the golden files');
end;

function IsCIIFile(const AName: string): Boolean;
begin
  Result := (Pos('-cii', AName) > 0);
end;

procedure TestGoldenRead;
var
  Dir: string;
  SR: TSearchRec;
  Xml, Written: TLandrixXmlUtf8;
  CII, Back: TLandrixCIIInvoice;
  Invoice: TLandrixInvoice;
  D: TLandrixEInvoiceDiagnostics;
  Spec: TLandrixEInvoiceSpec;
  UsesExtension: Boolean;
  Diff, Lost: string;
  Files, Failed: Integer;
begin
  Dir := LocalDir('golden');
  if not DirectoryExists(Dir) then
  begin
    Skip('no local golden files in ' + Dir);
    Exit;
  end;
  Files := 0;
  Failed := 0;
  if FindFirst(Dir + '*.xml', faAnyFile, SR) = 0 then
  try
    repeat
      if not IsCIIFile(SR.Name) then
        Continue;
      Inc(Files);
      Xml := LoadFile(Dir + SR.Name);
      D := TLandrixEInvoiceDiagnostics.Create;
      Invoice := TLandrixInvoice.Create;
      try
        CII := ReadCII(Xml, D);
        try
          LandrixEInvoiceCIIToInvoice(CII, Invoice, D);
          if not LandrixEInvoiceDetectSpec('CrossIndustryInvoice',
            CII.ExchangedDocumentContext.GuidelineSpecifiedDocumentContextParameter.ID.Value, Spec, UsesExtension) then
          begin
            Inc(Failed);
            WriteLn('  ', SR.Name, ': specification not detected');
            Continue;
          end;
        finally
          CII.Free;
        end;
        Back := LandrixEInvoiceInvoiceToCII(Invoice, Spec, D);
        try
          Written := WriteCII(Back);
        finally
          Back.Free;
        end;
        Lost := DiagnosticsOf(D, [edk_NotMapped, edk_ConversionFailed, edk_UnknownElement, edk_NotAllowed]);
        if not XmlEquivalent(Xml, Written, Diff) then
        begin
          Inc(Failed);
          WriteLn('  ', SR.Name, ': ', Diff);
        end
        else if Lost <> '' then
        begin
          Inc(Failed);
          WriteLn('  ', SR.Name, ':');
          Write(Lost);
        end;
      finally
        Invoice.Free;
        D.Free;
      end;
    until FindNext(SR) <> 0;
  finally
    FindClose(SR);
  end;
  CheckEquals(67, Files, 'CII golden files');
  CheckEquals(0, Failed, IntToStr(Files) + ' CII golden files, failed read round trips');
end;

const
  Ns =
    'xmlns:rsm="urn:un:unece:uncefact:data:standard:CrossIndustryInvoice:100" ' +
    'xmlns:ram="urn:un:unece:uncefact:data:standard:ReusableAggregateBusinessInformationEntity:100" ' +
    'xmlns:udt="urn:un:unece:uncefact:data:standard:UnqualifiedDataType:100"';

  { an EN16931 invoice with content the invoice model cannot hold, an
    unknown unit, an invalid amount and an unknown type code }
  Unusual =
    '<rsm:CrossIndustryInvoice ' + Ns + '>' +
    '<rsm:ExchangedDocumentContext><ram:GuidelineSpecifiedDocumentContextParameter>' +
    '<ram:ID>urn:cen.eu:en16931:2017</ram:ID></ram:GuidelineSpecifiedDocumentContextParameter>' +
    '</rsm:ExchangedDocumentContext>' +
    '<rsm:ExchangedDocument><ram:ID>R-1</ram:ID><ram:Name>Doc name</ram:Name><ram:TypeCode>999</ram:TypeCode>' +
    '<ram:IssueDateTime><udt:DateTimeString format="102">20261018</udt:DateTimeString></ram:IssueDateTime>' +
    '</rsm:ExchangedDocument>' +
    '<rsm:SupplyChainTradeTransaction>' +
    '<ram:IncludedSupplyChainTradeLineItem>' +
    '<ram:AssociatedDocumentLineDocument><ram:LineID>1</ram:LineID></ram:AssociatedDocumentLineDocument>' +
    '<ram:SpecifiedTradeProduct><ram:SellerAssignedID schemeID="X">A1</ram:SellerAssignedID>' +
    '<ram:Name>Item</ram:Name><ram:BrandName>Brand</ram:BrandName></ram:SpecifiedTradeProduct>' +
    '<ram:SpecifiedLineTradeAgreement><ram:NetPriceProductTradePrice><ram:ChargeAmount>10</ram:ChargeAmount>' +
    '</ram:NetPriceProductTradePrice></ram:SpecifiedLineTradeAgreement>' +
    '<ram:SpecifiedLineTradeDelivery><ram:BilledQuantity unitCode="QQQ">1</ram:BilledQuantity>' +
    '</ram:SpecifiedLineTradeDelivery>' +
    '<ram:SpecifiedLineTradeSettlement><ram:SpecifiedTradeSettlementLineMonetarySummation>' +
    '<ram:LineTotalAmount>1,00</ram:LineTotalAmount></ram:SpecifiedTradeSettlementLineMonetarySummation>' +
    '</ram:SpecifiedLineTradeSettlement>' +
    '</ram:IncludedSupplyChainTradeLineItem>' +
    '<ram:ApplicableHeaderTradeAgreement><ram:SellerTradeParty><ram:Name>S</ram:Name></ram:SellerTradeParty>' +
    '<ram:BuyerTradeParty><ram:Name>B</ram:Name><ram:Description>buyer note</ram:Description></ram:BuyerTradeParty>' +
    '</ram:ApplicableHeaderTradeAgreement>' +
    '<ram:ApplicableHeaderTradeDelivery/>' +
    '<ram:ApplicableHeaderTradeSettlement><ram:InvoiceCurrencyCode>EUR</ram:InvoiceCurrencyCode>' +
    '<ram:SpecifiedTradeSettlementHeaderMonetarySummation><ram:DuePayableAmount>10.00</ram:DuePayableAmount>' +
    '</ram:SpecifiedTradeSettlementHeaderMonetarySummation></ram:ApplicableHeaderTradeSettlement>' +
    '</rsm:SupplyChainTradeTransaction></rsm:CrossIndustryInvoice>';

function CountKind(D: TLandrixEInvoiceDiagnostics; AKind: TLandrixEInvoiceDiagnosticKind;
  const APathEnd: string): Integer;
var
  I: TLandrixEInvoiceListIndex;
  Path: string;
begin
  Result := 0;
  for I := 0 to D.Count - 1 do
  begin
    Path := string(D[I].Path);
    if (D[I].Kind = AKind) and (Copy(Path, Length(Path) - Length(APathEnd) + 1, Length(APathEnd)) = APathEnd) then
      Inc(Result);
  end;
end;

procedure TestReadReports;
var
  CII: TLandrixCIIInvoice;
  Invoice: TLandrixInvoice;
  D: TLandrixEInvoiceDiagnostics;
begin
  D := TLandrixEInvoiceDiagnostics.Create;
  Invoice := TLandrixInvoice.Create;
  try
    CII := ReadCII(Unusual, D);
    try
      LandrixEInvoiceCIIToInvoice(CII, Invoice, D);
    finally
      CII.Free;
    end;
    CheckEquals(0, CountKind(D, edk_NotMapped, '/rsm:ExchangedDocument/ram:Name'), 'document name mapped');
    CheckEqualsInvoiceStr('Doc name', Invoice.DocumentName, 'document name (BT-X-2)');
    CheckEquals(1, CountKind(D, edk_NotMapped, '/ram:SpecifiedTradeProduct/ram:BrandName'), 'brand name not mapped');
    CheckEquals(1, CountKind(D, edk_NotMapped, '/ram:SellerAssignedID/@schemeID'), 'identifier scheme not mapped');
    CheckEquals(1, CountKind(D, edk_NotMapped, '/ram:BuyerTradeParty/ram:Description'), 'buyer description not mapped');
    CheckEquals(1, CountKind(D, edk_UnknownCode, '/ram:BilledQuantity/@unitCode'), 'unknown unit');
    CheckEquals(1, CountKind(D, edk_UnknownCode, '/ram:TypeCode'), 'unknown type code');
    CheckEquals(1, CountKind(D, edk_ConversionFailed, '/ram:LineTotalAmount'), 'invalid amount');
    Check(D.HasErrors, 'conversion failure is an error');
    CheckEqualsInvoiceStr('QQQ', Invoice.InvoiceLines[0].UnitCodeOther, 'unit kept in UnitCodeOther');
    Check(Invoice.InvoiceLines[0].UnitCode = iuc_None, 'unit enumeration not set');
    CheckEqualsInvoiceStr('999', Invoice.InvoiceTypeCodeOther, 'type code kept');
    Check(Invoice.InvoiceLines[0].LineAmount = 0, 'invalid amount gives 0');
    CheckEqualsInvoiceStr('A1', Invoice.InvoiceLines[0].SellersItemIdentification, 'value taken');
  finally
    Invoice.Free;
    D.Free;
  end;
end;

procedure TestWriteRules;
var
  Invoice: TLandrixInvoice;
  Line: TLandrixInvoiceLine;
  CII: TLandrixCIIInvoice;
  D: TLandrixEInvoiceDiagnostics;
  Spec: TLandrixEInvoiceSpec;
  Xml: string;
begin
  D := TLandrixEInvoiceDiagnostics.Create;
  Invoice := TLandrixInvoice.Create;
  try
    Invoice.InvoiceNumber := 'R-1';
    Invoice.InvoiceTypeCodeOther := '999';
    Line := Invoice.InvoiceLines.AddInvoiceLine;
    Line.ID := '1';
    Line.UnitCodeOther := 'QQQ';
    Line.DeliveryNoteNumber := 'LS-1';
    Line.SubInvoiceLines.AddInvoiceLine.ID := '1.1';
    Check(LandrixEInvoiceFindSpec(TLandrixEInvoiceTargets.FacturX('1.09', epr_EN16931), Spec), 'spec');
    CII := LandrixEInvoiceInvoiceToCII(Invoice, Spec, D);
    try
      Xml := LandrixXmlUtf8ToString(WriteCII(CII));
    finally
      CII.Free;
    end;
    CheckEquals(1, CountKind(D, edk_NotAllowed, '/ram:SpecifiedLineTradeDelivery'), 'line delivery not allowed');
    CheckEquals(1, CountKind(D, edk_NotAllowed, '/ram:IncludedSupplyChainTradeLineItem'), 'sub lines not allowed');
    Check(Pos('LS-1', Xml) = 0, 'delivery note left out');
    Check(Pos('<ram:LineID>1.1</ram:LineID>', Xml) = 0, 'sub line left out');
    Check(Pos('unitCode="QQQ"', Xml) > 0, 'other unit written');
    Check(Pos('<ram:TypeCode>999</ram:TypeCode>', Xml) > 0, 'other type code written');
    D.Clear;
    Check(LandrixEInvoiceFindSpec(TLandrixEInvoiceTargets.FacturX('1.09', epr_Extended), Spec), 'spec');
    CII := LandrixEInvoiceInvoiceToCII(Invoice, Spec, D);
    try
      Xml := LandrixXmlUtf8ToString(WriteCII(CII));
    finally
      CII.Free;
    end;
    CheckEquals(0, D.CountOf(edk_NotAllowed), 'EXTENDED allows both');
    Check(Pos('<ram:ParentLineID>1</ram:ParentLineID>', Xml) > 0, 'sub line with parent');
    Check(Pos('LS-1', Xml) > 0, 'delivery note written');
  finally
    Invoice.Free;
    D.Free;
  end;
end;

{ EXTENDED with one cash discount and nothing else: the single payment
  term carries discount terms and must not be read as the XRechnung form. }
procedure TestDiscountOnlyRoundTrip;
var
  Invoice, Back: TLandrixInvoice;
  CII: TLandrixCIIInvoice;
  D: TLandrixEInvoiceDiagnostics;
  Spec: TLandrixEInvoiceSpec;
begin
  D := TLandrixEInvoiceDiagnostics.Create;
  Invoice := TLandrixInvoice.Create;
  Back := TLandrixInvoice.Create;
  try
    Invoice.InvoiceIssueDate := EncodeDate(2026, 10, 18);
    Invoice.PaymentTermsType := iptt_CashDiscount1;
    Invoice.PaymentTermCashDiscount1Days := 10;
    Invoice.PaymentTermCashDiscount1Percent := 2;
    Check(LandrixEInvoiceFindSpec(TLandrixEInvoiceTargets.FacturX('1.09', epr_Extended), Spec), 'spec');
    CII := LandrixEInvoiceInvoiceToCII(Invoice, Spec, D);
    try
      LandrixEInvoiceCIIToInvoice(CII, Back, D);
    finally
      CII.Free;
    end;
    Check(Back.PaymentTermsType = iptt_CashDiscount1, 'cash discount read back');
    CheckEquals(10, Back.PaymentTermCashDiscount1Days, 'days');
    Check(Back.PaymentTermCashDiscount1Percent = 2, 'percent');
    Check(Back.InvoiceDueDate = 0, 'no due date invented');
    CheckEquals(0, D.CountOf(edk_NotMapped), 'nothing lost: ' + string(D.ToText));
  finally
    Back.Free;
    Invoice.Free;
    D.Free;
  end;
end;

{ BT-110 is written in the invoice currency; a differing VAT accounting
  currency needs BT-111: an error without it, a second total with it. }
procedure TestTaxCurrency;
var
  Invoice: TLandrixInvoice;
  CII: TLandrixCIIInvoice;
  D: TLandrixEInvoiceDiagnostics;
  Spec: TLandrixEInvoiceSpec;
  Xml: string;
begin
  D := TLandrixEInvoiceDiagnostics.Create;
  Invoice := TLandrixInvoice.Create;
  try
    Invoice.InvoiceCurrencyCode := 'EUR';
    Invoice.TaxCurrencyCode := 'SEK';
    Check(LandrixEInvoiceFindSpec(TLandrixEInvoiceTargets.FacturX('1.09', epr_EN16931), Spec), 'spec');
    CII := LandrixEInvoiceInvoiceToCII(Invoice, Spec, D);
    try
      Xml := LandrixXmlUtf8ToString(WriteCII(CII));
    finally
      CII.Free;
    end;
    Check(Pos('<ram:TaxCurrencyCode>SEK', Xml) > 0, 'BT-6 written');
    Check(Pos('currencyID="EUR"', Xml) > 0, 'BT-110 in the invoice currency');
    CheckEquals(1, CountKind(D, edk_MissingElement, '/ram:TaxTotalAmount'), 'BT-111 missing');
    D.Clear;
    Invoice.TaxAmountTotalInTaxCurrency.SetValue(1.5);
    CII := LandrixEInvoiceInvoiceToCII(Invoice, Spec, D);
    try
      Xml := LandrixXmlUtf8ToString(WriteCII(CII));
    finally
      CII.Free;
    end;
    Check(Pos('<ram:TaxTotalAmount currencyID="SEK">1.50</ram:TaxTotalAmount>', Xml) > 0, 'BT-111 written');
    Check(not D.HasErrors, 'no error with BT-111: ' + string(D.ToText));
    D.Clear;
    Invoice.TaxCurrencyCode := 'EUR';
    CII := LandrixEInvoiceInvoiceToCII(Invoice, Spec, D);
    CII.Free;
    CheckEquals(1, CountKind(D, edk_NotAllowed, '/ram:TaxTotalAmount'), 'BT-111 without differing BT-6 left out');
  finally
    Invoice.Free;
    D.Free;
  end;
end;

procedure FillPhase2(AInvoice: TLandrixInvoice);
var
  Line: TLandrixInvoiceLine;
  Attachment: TLandrixInvoiceAttachment;
  Subtotal: TLandrixInvoiceTaxAmount;
begin
  AInvoice.InvoiceNumber := 'R-2';
  AInvoice.InvoiceTypeCode := itc_CommercialInvoice;
  AInvoice.InvoiceIssueDate := EncodeDate(2026, 10, 19);
  AInvoice.InvoiceCurrencyCode := 'EUR';
  AInvoice.TaxCurrencyCode := 'SEK';
  AInvoice.TaxAmountTotal := 19;
  AInvoice.TaxAmountTotalInTaxCurrency.SetValue(215.5);
  AInvoice.TestIndicator.SetValue(True);
  AInvoice.DocumentName := 'RECHNUNG';
  AInvoice.TaxPointDate.SetValue(EncodeDate(2026, 10, 1));
  AInvoice.SellerOrderReference := 'SO-1';
  AInvoice.SellerOrderReferenceDate.SetValue(EncodeDate(2026, 9, 1));
  AInvoice.PurchaseOrderReference := 'PO-1';
  AInvoice.PurchaseOrderReferenceDate.SetValue(EncodeDate(2026, 9, 2));
  AInvoice.AccountingSupplierParty.RegistrationName := 'Seller';
  AInvoice.AccountingSupplierParty.CompanyID := 'HRB 1';
  AInvoice.AccountingSupplierParty.CompanyIDSchemeID := '0002';
  AInvoice.AccountingSupplierParty.ContactName := 'Ms Seller';
  AInvoice.AccountingCustomerParty.RegistrationName := 'Buyer';
  AInvoice.AccountingCustomerParty.ContactDepartment := 'Purchasing';
  AInvoice.DeliveryInformation.LocationIdentifier := 'LOC-7';
  AInvoice.DeliveryInformation.LocationIdentifierSchemeID := '';
  AInvoice.DeliveryInformation.ContactName := 'Gate';
  AInvoice.DeliveryInformation.ContactTelephone := '+49 1';
  AInvoice.DeliveryInformation.ContactElectronicMail := 'gate@example.com';
  AInvoice.PayeeParty.Name := 'Payee';
  AInvoice.PayeeParty.Identifier := '4000001000005';
  AInvoice.PayeeParty.IdentifierSchemeID := '0088';
  AInvoice.PayeeParty.CompanyID := 'HRB 2';
  AInvoice.PayeeParty.CompanyIDSchemeID := '0002';
  AInvoice.PayeeParty.Address.City := 'Payee City';
  AInvoice.PayeeParty.Address.CountryCode := 'DE';
  AInvoice.TaxRepresentativeParty.Name := 'Representative';
  AInvoice.TaxRepresentativeParty.VATCompanyID := 'DE123456789';
  AInvoice.TaxRepresentativeParty.Address.City := 'Rep City';
  AInvoice.TaxRepresentativeParty.Address.CountryCode := 'DE';
  AInvoice.TaxRepresentativeParty.ContactName := 'Mr Rep';
  AInvoice.InvoiceeParty.Name := 'Invoicee';
  AInvoice.InvoiceeParty.Address.CountryCode := 'DE';
  AInvoice.PaymentTermsType := iptt_CashDiscount1;
  AInvoice.PaymentTermNetNote := 'Net 30 days';
  AInvoice.PaymentTermCashDiscount1Days := 10;
  AInvoice.PaymentTermCashDiscount1Percent := 2;
  AInvoice.PaymentTermCashDiscount1Note := '2 % within 10 days';
  Attachment := AInvoice.Attachments.AddAttachment(iat_application_None);
  Attachment.TypeCode := iatc_130;
  Attachment.ID := 'OBJ-1';
  Attachment.SchemeID := 'AAG';
  Subtotal := AInvoice.TaxAmountSubtotals.AddTaxAmount;
  Subtotal.TaxableAmount := 100;
  Subtotal.TaxAmount := 19;
  Subtotal.TaxPercent := 19;
  Subtotal.TaxCategory := idtfcc_S_StandardRate;
  Subtotal := AInvoice.TaxAmountSubtotals.AddTaxAmount;
  Subtotal.TaxableAmount := 0;
  Subtotal.TaxAmount := 0;
  Subtotal.TaxPercent := 7;
  Subtotal.TaxCategory := idtfcc_S_StandardRate;
  Line := AInvoice.InvoiceLines.AddInvoiceLine;
  Line.ID := '1';
  Line.Name := 'Item';
  Line.Quantity := 1;
  Line.UnitCode := iuc_piece;
  Line.NetPriceAmount := 100;
  Line.LineAmount := 100;
  Line.TaxPercent := 19;
  Line.TaxCategory := idtfcc_S_StandardRate;
  Line.StandardItemIdentifier := '123456789';
  Line.StandardItemIdentifierSchemeID := '0088';
  Line.OrderLineReference := '10';
  Line.OrderNumber := 'PO-1';
  Line.OrderDate.SetValue(EncodeDate(2026, 9, 2));
end;

function Occurrences(const APattern, AText: string): Integer;
var
  P: Integer;
  Remaining: string;
begin
  Result := 0;
  Remaining := AText;
  P := Pos(APattern, Remaining);
  while P > 0 do
  begin
    Inc(Result);
    Remaining := Copy(Remaining, P + Length(APattern), Length(Remaining));
    P := Pos(APattern, Remaining);
  end;
end;

function MapToCIIXml(AInvoice: TLandrixInvoice; const ATarget: TLandrixEInvoiceTarget;
  ADiagnostics: TLandrixEInvoiceDiagnostics; ABack: TLandrixInvoice): string;
var
  Spec: TLandrixEInvoiceSpec;
  CII: TLandrixCIIInvoice;
  Xml: TLandrixXmlUtf8;
begin
  Check(LandrixEInvoiceFindSpec(ATarget, Spec), 'spec');
  CII := LandrixEInvoiceInvoiceToCII(AInvoice, Spec, ADiagnostics);
  try
    Xml := WriteCII(CII);
  finally
    CII.Free;
  end;
  Result := LandrixXmlUtf8ToString(Xml);
  if ABack <> nil then
  begin
    CII := ReadCII(Xml, ADiagnostics);
    try
      LandrixEInvoiceCIIToInvoice(CII, ABack, ADiagnostics);
    finally
      CII.Free;
    end;
  end;
end;

{ EXTENDED holds every Phase 2 field: write, read back, nothing lost. }
procedure TestPhase2Extended;
var
  Invoice, Back: TLandrixInvoice;
  D: TLandrixEInvoiceDiagnostics;
  Xml: string;
begin
  D := TLandrixEInvoiceDiagnostics.Create;
  Invoice := TLandrixInvoice.Create;
  Back := TLandrixInvoice.Create;
  try
    FillPhase2(Invoice);
    Xml := MapToCIIXml(Invoice, TLandrixEInvoiceTargets.FacturX('1.09', epr_Extended), D, Back);
    CheckEquals(0, D.CountOf(edk_NotAllowed), 'nothing left out: ' + string(D.ToText));
    CheckEquals(0, D.CountOf(edk_NotMapped), 'nothing lost: ' + string(D.ToText));
    Check(not D.HasErrors, 'no errors: ' + string(D.ToText));
    CheckEquals(1, Occurrences('<ram:TaxPointDate>', Xml), 'BT-7 once (CII-SR-461)');
    Check(Pos('<ram:ID>LOC-7</ram:ID>', Xml) > 0, 'BT-71 without scheme as ram:ID');
    Check(Pos('currencyID="SEK">215.50<', Xml) > 0, 'BT-111 in SEK');
    Check(Back.TestIndicator.HasValue and Back.TestIndicator.Value, 'BT-X-1');
    CheckEqualsInvoiceStr('RECHNUNG', Back.DocumentName, 'BT-X-2');
    Check(Back.TaxPointDate.HasValue and (Back.TaxPointDate.Value = EncodeDate(2026, 10, 1)), 'BT-7');
    Check(Back.TaxAmountTotalInTaxCurrency.HasValue and (Back.TaxAmountTotalInTaxCurrency.Value = 215.5), 'BT-111');
    Check(Back.SellerOrderReferenceDate.Value = EncodeDate(2026, 9, 1), 'BT-X-146');
    Check(Back.PurchaseOrderReferenceDate.Value = EncodeDate(2026, 9, 2), 'BT-X-147');
    CheckEqualsInvoiceStr('0002', Back.AccountingSupplierParty.CompanyIDSchemeID, 'BT-30-1');
    CheckEqualsInvoiceStr('Purchasing', Back.AccountingCustomerParty.ContactDepartment, 'BT-56-0');
    CheckEqualsInvoiceStr('LOC-7', Back.DeliveryInformation.LocationIdentifier, 'BT-71');
    CheckEqualsInvoiceStr('', Back.DeliveryInformation.LocationIdentifierSchemeID, 'BT-71 without scheme');
    CheckEqualsInvoiceStr('Gate', Back.DeliveryInformation.ContactName, 'deliver to contact');
    CheckEqualsInvoiceStr('gate@example.com', Back.DeliveryInformation.ContactElectronicMail, 'deliver to email');
    CheckEqualsInvoiceStr('Payee', Back.PayeeParty.Name, 'BT-59');
    CheckEqualsInvoiceStr('4000001000005', Back.PayeeParty.Identifier, 'BT-60');
    CheckEqualsInvoiceStr('0088', Back.PayeeParty.IdentifierSchemeID, 'BT-60-1');
    CheckEqualsInvoiceStr('HRB 2', Back.PayeeParty.CompanyID, 'BT-61');
    CheckEqualsInvoiceStr('Payee City', Back.PayeeParty.Address.City, 'payee address (EXTENDED)');
    CheckEqualsInvoiceStr('DE123456789', Back.TaxRepresentativeParty.VATCompanyID, 'BT-63');
    CheckEqualsInvoiceStr('Rep City', Back.TaxRepresentativeParty.Address.City, 'BG-12');
    CheckEqualsInvoiceStr('Mr Rep', Back.TaxRepresentativeParty.ContactName, 'tax representative contact');
    CheckEqualsInvoiceStr('Invoicee', Back.InvoiceeParty.Name, 'invoicee');
    Check(Back.PaymentTermsType = iptt_CashDiscount1, 'cash discount');
    CheckEqualsInvoiceStr('2 % within 10 days', Back.PaymentTermCashDiscount1Note, 'text of the discount level');
    CheckEqualsInvoiceStr('Net 30 days', Back.PaymentTermNetNote, 'net note');
    CheckEqualsInvoiceStr('AAG', Back.Attachments[0].SchemeID, 'BT-18-1');
    CheckEqualsInvoiceStr('123456789', Back.InvoiceLines[0].StandardItemIdentifier, 'BT-157');
    CheckEqualsInvoiceStr('0088', Back.InvoiceLines[0].StandardItemIdentifierSchemeID, 'BT-157-1');
    CheckEqualsInvoiceStr('', Back.InvoiceLines[0].GlobalID_EAN_GTIN, 'no GTIN for scheme 0088');
    Check(Back.InvoiceLines[0].OrderDate.Value = EncodeDate(2026, 9, 2), 'BT-X-22');
  finally
    Back.Free;
    Invoice.Free;
    D.Free;
  end;
end;

{ EN 16931 writes the EN 16931 part and reports every EXTENDED-only field. }
procedure TestPhase2EN16931;
var
  Invoice: TLandrixInvoice;
  D: TLandrixEInvoiceDiagnostics;
  Xml: string;
begin
  D := TLandrixEInvoiceDiagnostics.Create;
  Invoice := TLandrixInvoice.Create;
  try
    FillPhase2(Invoice);
    Xml := MapToCIIXml(Invoice, TLandrixEInvoiceTargets.FacturX('1.09', epr_EN16931), D, nil);
    CheckEquals(1, CountKind(D, edk_NotAllowed, '/ram:TestIndicator'), 'BT-X-1 left out');
    CheckEquals(1, CountKind(D, edk_NotAllowed, '/rsm:ExchangedDocument/ram:Name'), 'BT-X-2 left out');
    CheckEquals(1, CountKind(D, edk_NotAllowed, '/ram:ApplicableHeaderTradeAgreement'), 'order dates left out');
    CheckEquals(1, CountKind(D, edk_NotAllowed, '/ram:BuyerOrderReferencedDocument/ram:FormattedIssueDateTime'),
      'line order date left out');
    CheckEquals(1, CountKind(D, edk_NotAllowed, '/ram:ShipToTradeParty/ram:DefinedTradeContact'),
      'deliver to contact left out');
    CheckEquals(1, CountKind(D, edk_NotAllowed, '/ram:InvoiceeTradeParty'), 'invoicee left out');
    CheckEquals(1, CountKind(D, edk_NotAllowed, '/ram:PayeeTradeParty'), 'payee address left out');
    CheckEquals(1, CountKind(D, edk_NotAllowed, '/ram:SellerTaxRepresentativeTradeParty'),
      'tax representative contact left out');
    CheckEquals(1, CountKind(D, edk_NotAllowed, '/ram:SpecifiedTradePaymentTerms/ram:Description'),
      'text of the discount level left out');
    Check(Pos('RECHNUNG', Xml) = 0, 'no document name');
    Check(Pos('Invoicee', Xml) = 0, 'no invoicee');
    Check(Pos('Payee City', Xml) = 0, 'no payee address');
    Check(Pos('<ram:Name>Payee</ram:Name>', Xml) > 0, 'payee name written');
    Check(Pos('<ram:GlobalID schemeID="0088">4000001000005</ram:GlobalID>', Xml) > 0, 'payee identifier written');
    Check(Pos('Rep City', Xml) > 0, 'tax representative address written');
    Check(Pos('DE123456789', Xml) > 0, 'tax representative VAT identifier written');
    Check(Pos('Mr Rep', Xml) = 0, 'no tax representative contact');
    Check(Pos('<ram:DepartmentName>Purchasing</ram:DepartmentName>', Xml) > 0, 'BT-56-0 written');
    Check(Pos('<ram:ID schemeID="0002">HRB 1</ram:ID>', Xml) > 0, 'BT-30-1 written');
    Check(Pos('<ram:ReferenceTypeCode>AAG</ram:ReferenceTypeCode>', Xml) > 0, 'BT-18-1 written');
    Check(Pos('<udt:DateString format="102">20261001</udt:DateString>', Xml) > 0, 'BT-7 written');
    Check(Pos('<ram:GlobalID schemeID="0088">123456789</ram:GlobalID>', Xml) > 0, 'BT-157 written');
    Check(not D.HasErrors, 'no errors: ' + string(D.ToText));
    D.Clear;
    Invoice.AccountingSupplierParty.ContactDepartment := 'Accounts';
    Xml := MapToCIIXml(Invoice, TLandrixEInvoiceTargets.FacturX('1.09', epr_EN16931), D, nil);
    CheckEquals(1, CountKind(D, edk_NotAllowed, '/ram:SellerTradeParty/ram:DefinedTradeContact/ram:DepartmentName'),
      'department besides a person name left out (CII-SR-465)');
    Check(Pos('Accounts', Xml) = 0, 'department not written');
  finally
    Invoice.Free;
    D.Free;
  end;
end;

{ Factur-X terms in the order discount, then net: the net term keeps the
  discount, the discount keeps its text. }
procedure TestPaymentTermsOrder;
const
  Xml =
    '<rsm:CrossIndustryInvoice ' + Ns + '>' +
    '<rsm:ExchangedDocumentContext><ram:GuidelineSpecifiedDocumentContextParameter>' +
    '<ram:ID>urn:cen.eu:en16931:2017#conformant#urn:factur-x.eu:1p0:extended</ram:ID>' +
    '</ram:GuidelineSpecifiedDocumentContextParameter></rsm:ExchangedDocumentContext>' +
    '<rsm:ExchangedDocument><ram:ID>R-1</ram:ID><ram:TypeCode>380</ram:TypeCode>' +
    '<ram:IssueDateTime><udt:DateTimeString format="102">20261019</udt:DateTimeString></ram:IssueDateTime>' +
    '</rsm:ExchangedDocument>' +
    '<rsm:SupplyChainTradeTransaction>' +
    '<ram:ApplicableHeaderTradeAgreement/><ram:ApplicableHeaderTradeDelivery/>' +
    '<ram:ApplicableHeaderTradeSettlement><ram:InvoiceCurrencyCode>EUR</ram:InvoiceCurrencyCode>' +
    '<ram:SpecifiedTradePaymentTerms><ram:Description>2 % until 29.10.</ram:Description>' +
    '<ram:ApplicableTradePaymentDiscountTerms><ram:BasisPeriodMeasure unitCode="DAY">10</ram:BasisPeriodMeasure>' +
    '<ram:CalculationPercent>2.00</ram:CalculationPercent></ram:ApplicableTradePaymentDiscountTerms>' +
    '</ram:SpecifiedTradePaymentTerms>' +
    '<ram:SpecifiedTradePaymentTerms><ram:Description>Net until 18.11.</ram:Description>' +
    '<ram:DueDateDateTime><udt:DateTimeString format="102">20261118</udt:DateTimeString></ram:DueDateDateTime>' +
    '</ram:SpecifiedTradePaymentTerms>' +
    '<ram:SpecifiedTradeSettlementHeaderMonetarySummation><ram:DuePayableAmount>0.00</ram:DuePayableAmount>' +
    '</ram:SpecifiedTradeSettlementHeaderMonetarySummation></ram:ApplicableHeaderTradeSettlement>' +
    '</rsm:SupplyChainTradeTransaction></rsm:CrossIndustryInvoice>';
var
  CII: TLandrixCIIInvoice;
  Invoice: TLandrixInvoice;
  D: TLandrixEInvoiceDiagnostics;
begin
  D := TLandrixEInvoiceDiagnostics.Create;
  Invoice := TLandrixInvoice.Create;
  try
    CII := ReadCII(Xml, D);
    try
      LandrixEInvoiceCIIToInvoice(CII, Invoice, D);
    finally
      CII.Free;
    end;
    Check(Invoice.PaymentTermsType = iptt_CashDiscount1, 'the net term keeps the discount');
    CheckEquals(10, Invoice.PaymentTermCashDiscount1Days, 'days');
    CheckEqualsInvoiceStr('2 % until 29.10.', Invoice.PaymentTermCashDiscount1Note, 'text of the discount level');
    CheckEqualsInvoiceStr('Net until 18.11.', Invoice.PaymentTermNetNote, 'net note');
    Check(Invoice.InvoiceDueDate = EncodeDate(2026, 11, 18), 'due date');
    CheckEquals(0, D.CountOf(edk_NotMapped), 'nothing lost: ' + string(D.ToText));
  finally
    Invoice.Free;
    D.Free;
  end;
end;

{ BT-7 and BT-8 when writing: BT-8 once in UNTDID 2475, an unknown code
  unchanged, BT-8 left out next to BT-7 (BR-CO-3), both left out without a
  VAT breakdown. }
procedure TestTaxPointDateWrite;
var
  Invoice, Back: TLandrixInvoice;
  D: TLandrixEInvoiceDiagnostics;
  Subtotal: TLandrixInvoiceTaxAmount;
  Target: TLandrixEInvoiceTarget;
  Xml: string;
begin
  Target := TLandrixEInvoiceTargets.FacturX('1.09', epr_EN16931);
  D := TLandrixEInvoiceDiagnostics.Create;
  Invoice := TLandrixInvoice.Create;
  Back := TLandrixInvoice.Create;
  try
    Invoice.InvoiceCurrencyCode := 'EUR';
    Invoice.TaxPointDateCode := '432';
    Xml := MapToCIIXml(Invoice, Target, D, nil);
    CheckEquals(1, CountKind(D, edk_NotAllowed, '/ram:ApplicableTradeTax'), 'BT-8 without breakdown left out');
    CheckEquals(0, Occurrences('<ram:DueDateTypeCode>', Xml), 'no BT-8 without breakdown');
    D.Clear;
    Subtotal := Invoice.TaxAmountSubtotals.AddTaxAmount;
    Subtotal.TaxCategory := idtfcc_S_StandardRate;
    Subtotal.TaxPercent := 19;
    Subtotal := Invoice.TaxAmountSubtotals.AddTaxAmount;
    Subtotal.TaxCategory := idtfcc_S_StandardRate;
    Subtotal.TaxPercent := 7;
    Xml := MapToCIIXml(Invoice, Target, D, Back);
    CheckEquals(1, Occurrences('<ram:DueDateTypeCode>72</ram:DueDateTypeCode>', Xml), 'BT-8 432 once as 72');
    CheckEqualsInvoiceStr('432', Back.TaxPointDateCode, 'BT-8 read back as 432');
    CheckEquals(0, CountKind(D, edk_UnknownCode, '/ram:ApplicableTradeTax/ram:DueDateTypeCode'), 'known code');
    D.Clear;
    Back.Clear;
    Invoice.TaxPointDateCode := 'X9';
    Xml := MapToCIIXml(Invoice, Target, D, Back);
    CheckEquals(2, CountKind(D, edk_UnknownCode, '/ram:ApplicableTradeTax/ram:DueDateTypeCode'),
      'unknown code reported when writing and reading');
    Check(Pos('<ram:DueDateTypeCode>X9</ram:DueDateTypeCode>', Xml) > 0, 'unknown code written unchanged');
    CheckEqualsInvoiceStr('X9', Back.TaxPointDateCode, 'unknown code read back unchanged');
    D.Clear;
    Invoice.TaxPointDateCode := '3';
    Invoice.TaxPointDate.SetValue(EncodeDate(2026, 10, 1));
    Xml := MapToCIIXml(Invoice, Target, D, nil);
    CheckEquals(1, CountKind(D, edk_NotAllowed, '/ram:ApplicableTradeTax/ram:DueDateTypeCode'),
      'BT-8 next to BT-7 left out (BR-CO-3)');
    CheckEquals(0, Occurrences('<ram:DueDateTypeCode>', Xml), 'no BT-8 next to BT-7');
    CheckEquals(1, Occurrences('<ram:TaxPointDate>', Xml), 'BT-7 written once');
    D.Clear;
    Invoice.TaxAmountSubtotals.Clear;
    Invoice.TaxPointDateCode := '';
    Xml := MapToCIIXml(Invoice, Target, D, nil);
    CheckEquals(1, CountKind(D, edk_NotAllowed, '/ram:ApplicableTradeTax'), 'BT-7 without breakdown left out');
    CheckEquals(0, Occurrences('<ram:TaxPointDate>', Xml), 'no BT-7 without breakdown');
  finally
    Back.Free;
    Invoice.Free;
    D.Free;
  end;
end;

{ Reading: the first VAT point date and code count, differing ones are
  reported; a contact with person name and department keeps both. }
procedure TestTaxPointDateRead;
const
  Tax1 =
    '<ram:ApplicableTradeTax><ram:CalculatedAmount>19.00</ram:CalculatedAmount><ram:TypeCode>VAT</ram:TypeCode>' +
    '<ram:BasisAmount>100.00</ram:BasisAmount><ram:CategoryCode>S</ram:CategoryCode>' +
    '<ram:TaxPointDate><udt:DateString format="102">20261001</udt:DateString></ram:TaxPointDate>' +
    '<ram:DueDateTypeCode>5</ram:DueDateTypeCode>' +
    '<ram:RateApplicablePercent>19</ram:RateApplicablePercent></ram:ApplicableTradeTax>';
  Tax2 =
    '<ram:ApplicableTradeTax><ram:CalculatedAmount>7.00</ram:CalculatedAmount><ram:TypeCode>VAT</ram:TypeCode>' +
    '<ram:BasisAmount>100.00</ram:BasisAmount><ram:CategoryCode>S</ram:CategoryCode>' +
    '<ram:TaxPointDate><udt:DateString format="102">20261002</udt:DateString></ram:TaxPointDate>' +
    '<ram:DueDateTypeCode>29</ram:DueDateTypeCode>' +
    '<ram:RateApplicablePercent>7</ram:RateApplicablePercent></ram:ApplicableTradeTax>';
  Xml =
    '<rsm:CrossIndustryInvoice ' + Ns + '>' +
    '<rsm:ExchangedDocumentContext><ram:GuidelineSpecifiedDocumentContextParameter>' +
    '<ram:ID>urn:cen.eu:en16931:2017</ram:ID>' +
    '</ram:GuidelineSpecifiedDocumentContextParameter></rsm:ExchangedDocumentContext>' +
    '<rsm:ExchangedDocument><ram:ID>R-1</ram:ID><ram:TypeCode>380</ram:TypeCode>' +
    '<ram:IssueDateTime><udt:DateTimeString format="102">20261019</udt:DateTimeString></ram:IssueDateTime>' +
    '</rsm:ExchangedDocument>' +
    '<rsm:SupplyChainTradeTransaction>' +
    '<ram:ApplicableHeaderTradeAgreement><ram:SellerTradeParty><ram:Name>Seller</ram:Name>' +
    '<ram:DefinedTradeContact><ram:PersonName>Ms Seller</ram:PersonName>' +
    '<ram:DepartmentName>Accounts</ram:DepartmentName></ram:DefinedTradeContact>' +
    '</ram:SellerTradeParty></ram:ApplicableHeaderTradeAgreement><ram:ApplicableHeaderTradeDelivery/>' +
    '<ram:ApplicableHeaderTradeSettlement><ram:InvoiceCurrencyCode>EUR</ram:InvoiceCurrencyCode>' +
    Tax1 + Tax2 +
    '<ram:SpecifiedTradeSettlementHeaderMonetarySummation><ram:DuePayableAmount>0.00</ram:DuePayableAmount>' +
    '</ram:SpecifiedTradeSettlementHeaderMonetarySummation></ram:ApplicableHeaderTradeSettlement>' +
    '</rsm:SupplyChainTradeTransaction></rsm:CrossIndustryInvoice>';
var
  CII: TLandrixCIIInvoice;
  Invoice: TLandrixInvoice;
  D: TLandrixEInvoiceDiagnostics;
begin
  D := TLandrixEInvoiceDiagnostics.Create;
  Invoice := TLandrixInvoice.Create;
  try
    CII := ReadCII(Xml, D);
    try
      LandrixEInvoiceCIIToInvoice(CII, Invoice, D);
    finally
      CII.Free;
    end;
    Check(Invoice.TaxPointDate.HasValue and (Invoice.TaxPointDate.Value = EncodeDate(2026, 10, 1)), 'first BT-7');
    CheckEqualsInvoiceStr('3', Invoice.TaxPointDateCode, 'first BT-8');
    CheckEquals(1, CountKind(D, edk_NotMapped, '/ram:ApplicableTradeTax/ram:TaxPointDate'), 'differing BT-7');
    CheckEquals(1, CountKind(D, edk_NotMapped, '/ram:ApplicableTradeTax/ram:DueDateTypeCode'), 'differing BT-8');
    CheckEqualsInvoiceStr('Ms Seller', Invoice.AccountingSupplierParty.ContactName, 'person name');
    CheckEqualsInvoiceStr('Accounts', Invoice.AccountingSupplierParty.ContactDepartment, 'department');
    CheckEquals(0, CountKind(D, edk_NotMapped, '/ram:DefinedTradeContact'), 'contact complete');
  finally
    Invoice.Free;
    D.Free;
  end;
end;

{ XRechnung CII declares the extension (BT-24) only with extension content:
  an XR01 to XR03 scheme or an embedded XML attachment; Factur-X never. }
procedure TestExtensionIdentifier;
const
  Extension = '#conformant#urn:xeinkauf.de:kosit:extension:xrechnung_3.0';
var
  Invoice, Back: TLandrixInvoice;
  D: TLandrixEInvoiceDiagnostics;
  Target: TLandrixEInvoiceTarget;
  Attachment: TLandrixInvoiceAttachment;
  Xml: string;
begin
  Target := TLandrixEInvoiceTargets.XRechnung('3.0', esy_CII);
  D := TLandrixEInvoiceDiagnostics.Create;
  Invoice := TLandrixInvoice.Create;
  Back := TLandrixInvoice.Create;
  try
    Invoice.InvoiceCurrencyCode := 'EUR';
    Invoice.AccountingSupplierParty.ElectronicAddressSellerBuyer := 'seller@example.com';
    Invoice.AccountingSupplierParty.ElectronicAddressSellerBuyerSchemeID := 'EM';
    Xml := MapToCIIXml(Invoice, Target, D, nil);
    CheckEquals(0, Occurrences(Extension, Xml), 'no extension without extension content');
    Invoice.DeliveryInformation.LocationIdentifier := 'L-1';
    Invoice.DeliveryInformation.LocationIdentifierSchemeID := 'XR02';
    Xml := MapToCIIXml(Invoice, Target, D, Back);
    CheckEquals(1, Occurrences(Extension, Xml), 'XR02 scheme declares the extension');
    CheckEqualsInvoiceStr('XR02', Back.DeliveryInformation.LocationIdentifierSchemeID, 'scheme read back');
    Invoice.DeliveryInformation.LocationIdentifierSchemeID := '0088';
    Attachment := Invoice.Attachments.AddAttachment(iat_application_xml);
    Attachment.ID := 'A-1';
    Attachment.Filename := 'a.xml';
    Attachment.EmbedDataFromText(TLandrixEInvoiceString('<a/>'));
    Xml := MapToCIIXml(Invoice, Target, D, nil);
    CheckEquals(1, Occurrences(Extension, Xml), 'XML attachment declares the extension');
    Xml := MapToCIIXml(Invoice, TLandrixEInvoiceTargets.FacturX('1.09', epr_Extended), D, nil);
    CheckEquals(0, Occurrences('extension', Xml), 'Factur-X has no XRechnung extension');
  finally
    Back.Free;
    Invoice.Free;
    D.Free;
  end;
end;

{ ACents / 100 as Currency without a float division. }
function Cents(ACents: Int64): Currency;
begin
  PInt64(@Result)^ := ACents * 100;
end;

{ The XML without the white space between tags (the writer indents). }
function StripIndent(const AText: string): string;
var
  I, J: Integer;
begin
  Result := '';
  I := 1;
  while I <= Length(AText) do
  begin
    if AText[I] = '>' then
    begin
      J := I + 1;
      while (J <= Length(AText)) and ((AText[J] = ' ') or (AText[J] = #9) or (AText[J] = #10) or
        (AText[J] = #13)) do
        Inc(J);
      if (J <= Length(AText)) and (AText[J] = '<') then
      begin
        Result := Result + '>';
        I := J;
        Continue;
      end;
    end;
    Result := Result + AText[I];
    Inc(I);
  end;
end;

{ Factur-X EXTENDED logistics service charge: read as document level charge
  (BG-21) with an information, written back as such a charge. }
procedure TestLogisticsCharge;
const
  Xml =
    '<rsm:CrossIndustryInvoice ' + Ns + '>' +
    '<rsm:ExchangedDocumentContext><ram:GuidelineSpecifiedDocumentContextParameter>' +
    '<ram:ID>urn:cen.eu:en16931:2017#conformant#urn:factur-x.eu:1p0:extended</ram:ID>' +
    '</ram:GuidelineSpecifiedDocumentContextParameter></rsm:ExchangedDocumentContext>' +
    '<rsm:ExchangedDocument><ram:ID>R-1</ram:ID><ram:TypeCode>380</ram:TypeCode>' +
    '<ram:IssueDateTime><udt:DateTimeString format="102">20261019</udt:DateTimeString></ram:IssueDateTime>' +
    '</rsm:ExchangedDocument>' +
    '<rsm:SupplyChainTradeTransaction>' +
    '<ram:ApplicableHeaderTradeAgreement/><ram:ApplicableHeaderTradeDelivery/>' +
    '<ram:ApplicableHeaderTradeSettlement><ram:InvoiceCurrencyCode>EUR</ram:InvoiceCurrencyCode>' +
    '<ram:SpecifiedLogisticsServiceCharge><ram:Description>Freight</ram:Description>' +
    '<ram:AppliedAmount>15.00</ram:AppliedAmount><ram:AppliedTradeTax><ram:TypeCode>VAT</ram:TypeCode>' +
    '<ram:CategoryCode>S</ram:CategoryCode><ram:RateApplicablePercent>19.00</ram:RateApplicablePercent>' +
    '</ram:AppliedTradeTax></ram:SpecifiedLogisticsServiceCharge>' +
    '<ram:SpecifiedTradeSettlementHeaderMonetarySummation><ram:ChargeTotalAmount>15.00</ram:ChargeTotalAmount>' +
    '<ram:DuePayableAmount>17.85</ram:DuePayableAmount>' +
    '</ram:SpecifiedTradeSettlementHeaderMonetarySummation></ram:ApplicableHeaderTradeSettlement>' +
    '</rsm:SupplyChainTradeTransaction></rsm:CrossIndustryInvoice>';
var
  CII: TLandrixCIIInvoice;
  Invoice: TLandrixInvoice;
  D: TLandrixEInvoiceDiagnostics;
  Charge: TLandrixInvoiceAllowanceCharge;
  Back: string;
begin
  D := TLandrixEInvoiceDiagnostics.Create;
  Invoice := TLandrixInvoice.Create;
  try
    CII := ReadCII(Xml, D);
    try
      LandrixEInvoiceCIIToInvoice(CII, Invoice, D);
    finally
      CII.Free;
    end;
    CheckEquals(1, Integer(Invoice.AllowanceCharges.Count), 'one document level charge');
    Charge := Invoice.AllowanceCharges[0];
    Check(Charge.ChargeIndicator, 'charge');
    CheckEqualsInvoiceStr('Freight', Charge.Reason, 'description as reason');
    Check(Charge.Amount = 15, 'amount');
    Check(Charge.TaxCategory = idtfcc_S_StandardRate, 'category');
    Check(Charge.TaxPercent = 19, 'rate');
    CheckEquals(1, CountKind(D, edk_NotMapped, '/ram:SpecifiedLogisticsServiceCharge'), 'conversion reported');
    CheckEquals(1, Integer(D.Count), 'nothing else reported: ' + string(D.ToText));
    Check(D[0].Severity = eds_Info, 'as information');
    D.Clear;
    Back := StripIndent(MapToCIIXml(Invoice, TLandrixEInvoiceTargets.FacturX('1.09', epr_Extended), D, nil));
    Check(Pos('<ram:SpecifiedTradeAllowanceCharge><ram:ChargeIndicator><udt:Indicator>true</udt:Indicator>' +
      '</ram:ChargeIndicator><ram:ActualAmount>15.00</ram:ActualAmount><ram:Reason>Freight</ram:Reason>', Back) > 0,
      'written back as document level charge');
    CheckEquals(0, Occurrences('LogisticsServiceCharge', Back), 'no logistics charge written');
  finally
    Invoice.Free;
    D.Free;
  end;
end;

{ BG-DEX-09 third-party payments: Factur-X EXTENDED writes and reads them as
  financial adjustments; XRechnung CII leaves them out with an error, since
  the amount due includes them (BR-CO-16). }
procedure TestThirdPartyPayments;
var
  Invoice, Back: TLandrixInvoice;
  D: TLandrixEInvoiceDiagnostics;
  Payment: TLandrixInvoicePrepaidPayment;
  Xml: string;
begin
  D := TLandrixEInvoiceDiagnostics.Create;
  Invoice := TLandrixInvoice.Create;
  Back := TLandrixInvoice.Create;
  try
    Invoice.InvoiceCurrencyCode := 'EUR';
    Payment := Invoice.PrepaidPayments.AddPrepaidPayment;
    Payment.ID := 'Deposit';
    Payment.PaidAmount := Cents(1996);
    Payment.InstructionID := 'Claim of provider A';
    Payment := Invoice.PrepaidPayments.AddPrepaidPayment;
    Payment.ID := 'Fee';
    Payment.PaidAmount := 10;
    Xml := StripIndent(MapToCIIXml(Invoice, TLandrixEInvoiceTargets.FacturX('1.09', epr_Extended), D, Back));
    Check(Pos('<ram:SpecifiedFinancialAdjustment><ram:Reason>Claim of provider A</ram:Reason>' +
      '<ram:ActualAmount>19.96</ram:ActualAmount></ram:SpecifiedFinancialAdjustment>', Xml) > 0,
      'description as reason');
    Check(Pos('<ram:SpecifiedFinancialAdjustment><ram:Reason>Fee</ram:Reason>' +
      '<ram:ActualAmount>10.00</ram:ActualAmount></ram:SpecifiedFinancialAdjustment>', Xml) > 0,
      'type as reason without description');
    CheckEquals(1, CountKind(D, edk_NotAllowed, '/ram:SpecifiedFinancialAdjustment'), 'type next to description lost');
    CheckEquals(2, Integer(Back.PrepaidPayments.Count), 'read back');
    CheckEqualsInvoiceStr('Claim of provider A', Back.PrepaidPayments[0].InstructionID, 'reason read back');
    Check(Back.PrepaidPayments[1].PaidAmount = 10, 'amount read back');
    D.Clear;
    Xml := MapToCIIXml(Invoice, TLandrixEInvoiceTargets.XRechnung('3.0', esy_CII), D, nil);
    CheckEquals(0, Occurrences('FinancialAdjustment', Xml), 'XRechnung CII has no financial adjustment');
    CheckEquals(1, CountKind(D, edk_NotAllowed, '/ram:DuePayableAmount'), 'amount due reported');
    Check(D.HasErrors, 'as error');
  finally
    Back.Free;
    Invoice.Free;
    D.Free;
  end;
end;

{ Factur-X EXTENDED takes several invoiced object identifiers (BT-18);
  elsewhere only the first is written (CII-SR-458). }
procedure TestObjectIdentifiers;
var
  Invoice, Back: TLandrixInvoice;
  D: TLandrixEInvoiceDiagnostics;
  Xml: string;
begin
  D := TLandrixEInvoiceDiagnostics.Create;
  Invoice := TLandrixInvoice.Create;
  Back := TLandrixInvoice.Create;
  try
    Invoice.InvoiceCurrencyCode := 'EUR';
    with Invoice.Attachments.AddAttachment(iat_application_None) do
    begin
      ID := 'OBJ-1';
      TypeCode := iatc_130;
    end;
    with Invoice.Attachments.AddAttachment(iat_application_None) do
    begin
      ID := 'OBJ-2';
      TypeCode := iatc_130;
    end;
    Xml := StripIndent(MapToCIIXml(Invoice, TLandrixEInvoiceTargets.FacturX('1.09', epr_Extended), D, Back));
    Check(Pos('<ram:IssuerAssignedID>OBJ-2</ram:IssuerAssignedID>', Xml) > 0, 'second identifier in EXTENDED');
    CheckEquals(0, CountKind(D, edk_NotAllowed, '/ram:AdditionalReferencedDocument'), 'EXTENDED: no report');
    CheckEquals(2, Back.Attachments.Count, 'both read back');
    D.Clear;
    Xml := StripIndent(MapToCIIXml(Invoice, TLandrixEInvoiceTargets.XRechnung('3.0', esy_CII), D, nil));
    Check(Pos('<ram:IssuerAssignedID>OBJ-1</ram:IssuerAssignedID>', Xml) > 0, 'first identifier in XRechnung');
    CheckEquals(0, Occurrences('OBJ-2', Xml), 'second identifier left out in XRechnung');
    CheckEquals(1, CountKind(D, edk_NotAllowed, '/ram:AdditionalReferencedDocument'), 'XRechnung: reported');
  finally
    Back.Free;
    Invoice.Free;
    D.Free;
  end;
end;

{ A credit transfer account (BG-17) next to a direct debit is reported and
  not read as the debited account (BT-91). }
procedure TestDirectDebitPayeeAccount;
var
  Invoice, Back: TLandrixInvoice;
  D: TLandrixEInvoiceDiagnostics;
  Spec: TLandrixEInvoiceSpec;
  CII: TLandrixCIIInvoice;
  Payment: TLandrixInvoicePaymentType;
begin
  D := TLandrixEInvoiceDiagnostics.Create;
  Invoice := TLandrixInvoice.Create;
  Back := TLandrixInvoice.Create;
  CII := nil;
  try
    Invoice.InvoiceCurrencyCode := 'EUR';
    Payment := Invoice.PaymentTypes.AddPaymentType;
    Payment.PaymentMeansCode := ipmc_DirectDebit;
    Check(LandrixEInvoiceFindSpec(TLandrixEInvoiceTargets.XRechnung('3.0', esy_CII), Spec), 'spec');
    CII := LandrixEInvoiceInvoiceToCII(Invoice, Spec, D);
    CII.SupplyChainTradeTransaction.ApplicableHeaderTradeSettlement.SpecifiedTradeSettlementPaymentMeans[0].
      PayeePartyCreditorFinancialAccount.IBANID.Value := 'DE21860000000086001055';
    D.Clear;
    LandrixEInvoiceCIIToInvoice(CII, Back, D);
    Check(Back.PaymentTypes[0].PaymentMeansCode = ipmc_DirectDebit, 'code read back');
    CheckEqualsInvoiceStr('', Back.PaymentTypes[0].FinancialAccount, 'not the debited account');
    CheckEquals(1, CountKind(D, edk_NotMapped, '/ram:PayeePartyCreditorFinancialAccount'), 'reported');
  finally
    CII.Free;
    Back.Free;
    Invoice.Free;
    D.Free;
  end;
end;

{ Code 49 is a direct debit like 59: the account is the debited account
  (BT-91), the BIC is written without a payee account. }
procedure TestDirectDebit49;
var
  Invoice, Back: TLandrixInvoice;
  D: TLandrixEInvoiceDiagnostics;
  Payment: TLandrixInvoicePaymentType;
  Xml: string;
begin
  D := TLandrixEInvoiceDiagnostics.Create;
  Invoice := TLandrixInvoice.Create;
  Back := TLandrixInvoice.Create;
  try
    Invoice.InvoiceCurrencyCode := 'EUR';
    Invoice.PaymentMandateID := 'M-49';
    Payment := Invoice.PaymentTypes.AddPaymentType;
    Payment.PaymentMeansCode := ipmc_DirectDebit;
    Payment.FinancialAccount := 'DE21860000000086001055';
    Payment.FinancialInstitutionBranch := 'MARKDEF1860';
    Xml := StripIndent(MapToCIIXml(Invoice, TLandrixEInvoiceTargets.XRechnung('3.0', esy_CII), D, Back));
    Check(Pos('<ram:PayerPartyDebtorFinancialAccount><ram:IBANID>DE21860000000086001055</ram:IBANID>', Xml) > 0,
      'debited account');
    CheckEquals(0, Occurrences('PayeePartyCreditorFinancialAccount', Xml), 'no payee account');
    Check(Pos('<ram:BICID>MARKDEF1860</ram:BICID>', Xml) > 0, 'BIC');
    Check(Pos('<ram:DirectDebitMandateID>M-49</ram:DirectDebitMandateID>', Xml) > 0, 'mandate');
    CheckEquals(0, CountKind(D, edk_NotAllowed, '/ram:PayerPartyDebtorFinancialAccount'), 'no name, no report');
    Check(Back.PaymentTypes[0].PaymentMeansCode = ipmc_DirectDebit, 'code read back');
    CheckEqualsInvoiceStr('DE21860000000086001055', Back.PaymentTypes[0].FinancialAccount, 'account read back');
    CheckEqualsInvoiceStr('M-49', Back.PaymentMandateID, 'mandate read back');
    Payment.FinancialAccountName := 'Buyer';
    D.Clear;
    MapToCIIXml(Invoice, TLandrixEInvoiceTargets.XRechnung('3.0', esy_CII), D, nil);
    CheckEquals(1, CountKind(D, edk_NotAllowed, '/ram:PayerPartyDebtorFinancialAccount/ram:AccountName'),
      'account name reported');
  finally
    Back.Free;
    Invoice.Free;
    D.Free;
  end;
end;

{ Periods are compared as dates (BR-29, BR-30): a later start time on the
  end day is written, an end date before the start date is left out and
  reported. }
procedure TestPeriods;
var
  Invoice: TLandrixInvoice;
  D: TLandrixEInvoiceDiagnostics;
  Line: TLandrixInvoiceLine;
  Xml: string;
begin
  D := TLandrixEInvoiceDiagnostics.Create;
  Invoice := TLandrixInvoice.Create;
  try
    Invoice.InvoiceCurrencyCode := 'EUR';
    Line := Invoice.InvoiceLines.AddInvoiceLine;
    Line.ID := '1';
    Invoice.InvoicePeriodStartDate := EncodeDate(2026, 10, 1) + EncodeTime(18, 0, 0, 0);
    Invoice.InvoicePeriodEndDate := EncodeDate(2026, 10, 1) + EncodeTime(8, 0, 0, 0);
    Line.InvoiceLinePeriodStartDate := EncodeDate(2026, 10, 2);
    Line.InvoiceLinePeriodEndDate := EncodeDate(2026, 10, 1);
    Xml := MapToCIIXml(Invoice, TLandrixEInvoiceTargets.XRechnung('3.0', esy_CII), D, nil);
    CheckEquals(2, Occurrences('>20261001</udt:DateTimeString>', Xml), 'same day written');
    CheckEquals(0, Occurrences('20261002', Xml), 'reversed line period left out');
    CheckEquals(1, CountKind(D, edk_NotAllowed, '/ram:SpecifiedLineTradeSettlement/ram:BillingSpecifiedPeriod'),
      'line period reported');
    CheckEquals(0, CountKind(D, edk_NotAllowed, '/ram:ApplicableHeaderTradeSettlement/ram:BillingSpecifiedPeriod'),
      'invoice period kept');
    Invoice.InvoicePeriodEndDate := EncodeDate(2026, 9, 30);
    D.Clear;
    Xml := MapToCIIXml(Invoice, TLandrixEInvoiceTargets.XRechnung('3.0', esy_CII), D, nil);
    CheckEquals(0, Occurrences('BillingSpecifiedPeriod', Xml), 'no period');
    CheckEquals(1, CountKind(D, edk_NotAllowed, '/ram:ApplicableHeaderTradeSettlement/ram:BillingSpecifiedPeriod'),
      'invoice period reported');
  finally
    Invoice.Free;
    D.Free;
  end;
end;

{ A payee of blank text and a scheme only is no payee. }
procedure TestBlankPayee;
var
  Invoice: TLandrixInvoice;
  D: TLandrixEInvoiceDiagnostics;
  Xml: string;
begin
  D := TLandrixEInvoiceDiagnostics.Create;
  Invoice := TLandrixInvoice.Create;
  try
    Invoice.InvoiceCurrencyCode := 'EUR';
    Invoice.PayeeParty.Name := ' ';
    Invoice.PayeeParty.IdentifierSchemeID := '0088';
    Xml := MapToCIIXml(Invoice, TLandrixEInvoiceTargets.XRechnung('3.0', esy_CII), D, nil);
    CheckEquals(0, Occurrences('PayeeTradeParty', Xml), 'no payee');
    CheckEquals(0, CountKind(D, edk_MissingElement, '/ram:PayeeTradeParty/ram:Name'), 'no missing name reported');
  finally
    Invoice.Free;
    D.Free;
  end;
end;

procedure TestWrongSpec;
var
  Invoice: TLandrixInvoice;
  Spec: TLandrixEInvoiceSpec;
begin
  Invoice := TLandrixInvoice.Create;
  try
    Check(LandrixEInvoiceFindSpec(TLandrixEInvoiceTargets.PeppolBIS('3.0'), Spec), 'spec');
    try
      LandrixEInvoiceInvoiceToCII(Invoice, Spec, nil).Free;
      FailNotRaised('ELandrixEInvoiceError for a UBL specification');
    except
      on ELandrixEInvoiceError do ;
    end;
  finally
    Invoice.Free;
  end;
end;

procedure Register;
begin
  RegisterTest('MapCII.GoldenWrite', TestGoldenWrite);
  RegisterTest('MapCII.GoldenRead', TestGoldenRead);
  RegisterTest('MapCII.ReadReports', TestReadReports);
  RegisterTest('MapCII.WriteRules', TestWriteRules);
  RegisterTest('MapCII.WrongSpec', TestWrongSpec);
  RegisterTest('MapCII.ExtensionIdentifier', TestExtensionIdentifier);
  RegisterTest('MapCII.LogisticsCharge', TestLogisticsCharge);
  RegisterTest('MapCII.ThirdPartyPayments', TestThirdPartyPayments);
  RegisterTest('MapCII.DirectDebit49', TestDirectDebit49);
  RegisterTest('MapCII.DirectDebitPayeeAccount', TestDirectDebitPayeeAccount);
  RegisterTest('MapCII.ObjectIdentifiers', TestObjectIdentifiers);
  RegisterTest('MapCII.Periods', TestPeriods);
  RegisterTest('MapCII.BlankPayee', TestBlankPayee);
  RegisterTest('MapCII.TaxCurrency', TestTaxCurrency);
  RegisterTest('MapCII.DiscountOnlyRoundTrip', TestDiscountOnlyRoundTrip);
  RegisterTest('MapCII.Phase2Extended', TestPhase2Extended);
  RegisterTest('MapCII.Phase2EN16931', TestPhase2EN16931);
  RegisterTest('MapCII.PaymentTermsOrder', TestPaymentTermsOrder);
  RegisterTest('MapCII.TaxPointDateWrite', TestTaxPointDateWrite);
  RegisterTest('MapCII.TaxPointDateRead', TestTaxPointDateRead);
end;

end.
