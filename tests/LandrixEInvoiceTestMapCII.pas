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
  LandrixEInvoiceInvoice,
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
    if not XmlEquivalent(LoadFile(State^.Dir + AFileName), Written, Diff) then
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
    CheckEquals(1, CountKind(D, edk_NotMapped, '/rsm:ExchangedDocument/ram:Name'), 'document name not mapped');
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
  currency needs BT-111, which the model does not hold: an error. }
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
  RegisterTest('MapCII.TaxCurrency', TestTaxCurrency);
  RegisterTest('MapCII.DiscountOnlyRoundTrip', TestDiscountOnlyRoundTrip);
end;

end.
