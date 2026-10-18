{
  EInvoice-for-Pascal

  Copyright (C) 2026 Landrix Software GmbH & Co. KG

  This file is dual-licensed under:
  - GNU GPL version 3 or later; or
  - the Landrix Software Commercial License.

  See LICENSE and COMMERCIAL-LICENSE.md.

  SPDX-License-Identifier: GPL-3.0-or-later OR LicenseRef-Landrix-Commercial
}

{ Tests for the generated CII syntax model, reader and writer, including the
  round trip of local example files (tests/data/local/cii/*.xml) and the
  reading of local schema-invalid files (tests/data/local/cii-invalid/*.xml);
  both are skipped when the folder does not exist. }

unit LandrixEInvoiceTestCII;

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
  LandrixEInvoiceCII,
  LandrixEInvoiceCIIReader,
  LandrixEInvoiceCIIWriter,
  LandrixEInvoiceTestFramework,
  LandrixEInvoiceTestXmlCompare;

const
  NsDecl =
    'xmlns:rsm="urn:un:unece:uncefact:data:standard:CrossIndustryInvoice:100" ' +
    'xmlns:ram="urn:un:unece:uncefact:data:standard:ReusableAggregateBusinessInformationEntity:100" ' +
    'xmlns:qdt="urn:un:unece:uncefact:data:standard:QualifiedDataType:100" ' +
    'xmlns:udt="urn:un:unece:uncefact:data:standard:UnqualifiedDataType:100"';

  Sample =
    '<?xml version="1.0" encoding="UTF-8"?>' +
    '<rsm:CrossIndustryInvoice ' + NsDecl + '>' +
    '<rsm:ExchangedDocumentContext>' +
    '<ram:GuidelineSpecifiedDocumentContextParameter><ram:ID>urn:cen.eu:en16931:2017</ram:ID>' +
    '</ram:GuidelineSpecifiedDocumentContextParameter>' +
    '</rsm:ExchangedDocumentContext>' +
    '<rsm:ExchangedDocument>' +
    '<ram:ID>R-1</ram:ID><ram:TypeCode>380</ram:TypeCode>' +
    '<ram:IssueDateTime><udt:DateTimeString format="102">20261016</udt:DateTimeString></ram:IssueDateTime>' +
    '<ram:IncludedNote><ram:Content>a</ram:Content></ram:IncludedNote>' +
    '<ram:IncludedNote><ram:Content>b</ram:Content><ram:SubjectCode>AAI</ram:SubjectCode></ram:IncludedNote>' +
    '</rsm:ExchangedDocument>' +
    '<rsm:SupplyChainTradeTransaction>' +
    '<ram:ApplicableHeaderTradeAgreement>' +
    '<ram:SellerTradeParty><ram:Name>S</ram:Name></ram:SellerTradeParty>' +
    '<ram:BuyerTradeParty><ram:Name>B</ram:Name></ram:BuyerTradeParty>' +
    '</ram:ApplicableHeaderTradeAgreement>' +
    '<ram:ApplicableHeaderTradeDelivery><ram:ActualDeliverySupplyChainEvent><ram:OccurrenceDateTime>' +
    '<udt:DateTimeString format="102">20261015</udt:DateTimeString>' +
    '</ram:OccurrenceDateTime></ram:ActualDeliverySupplyChainEvent></ram:ApplicableHeaderTradeDelivery>' +
    '<ram:ApplicableHeaderTradeSettlement>' +
    '<ram:InvoiceCurrencyCode>EUR</ram:InvoiceCurrencyCode>' +
    '<ram:SpecifiedTradeSettlementHeaderMonetarySummation>' +
    '<ram:LineTotalAmount>100.00</ram:LineTotalAmount>' +
    '<ram:TaxBasisTotalAmount>100.00</ram:TaxBasisTotalAmount>' +
    '<ram:TaxTotalAmount currencyID="EUR">19.00</ram:TaxTotalAmount>' +
    '<ram:GrandTotalAmount>119.00</ram:GrandTotalAmount>' +
    '<ram:DuePayableAmount>119.00</ram:DuePayableAmount>' +
    '</ram:SpecifiedTradeSettlementHeaderMonetarySummation>' +
    '</ram:ApplicableHeaderTradeSettlement>' +
    '</rsm:SupplyChainTradeTransaction>' +
    '</rsm:CrossIndustryInvoice>';

function ReadCII(const Xml: TLandrixXmlUtf8; Diagnostics: TLandrixEInvoiceDiagnostics): TLandrixCIIInvoice;
var
  R: TLandrixXmlReader;
begin
  R := TLandrixXmlReader.Create;
  try
    R.LoadFromUtf8(Xml);
    Result := LandrixEInvoiceReadCII(R, Diagnostics);
  finally
    R.Free;
  end;
end;

function WriteCII(Inv: TLandrixCIIInvoice; Diagnostics: TLandrixEInvoiceDiagnostics): TLandrixXmlUtf8;
var
  W: TLandrixXmlWriter;
begin
  W := TLandrixXmlWriter.Create;
  try
    W.Indent := True;
    LandrixEInvoiceWriteCII(Inv, W, Diagnostics);
    W.EndDocument;
    Result := W.AsUtf8;
  finally
    W.Free;
  end;
end;

procedure TestModelLazyAndEmpty;
var
  Inv: TLandrixCIIInvoice;
begin
  Inv := TLandrixCIIInvoice.Create;
  try
    Check(Inv.IsEmpty, 'new invoice is empty');
    Check(Inv.ExchangedDocument <> nil, 'child created on access');
    Check(Inv.IsEmpty, 'access alone does not make it present');
    Inv.ExchangedDocument.ID.Value := 'R-1';
    Check(not Inv.IsEmpty, 'set value makes it present');
    Inv.ExchangedDocument.IncludedNote.Add.Content := 'x';
    CheckEquals(1, Integer(Inv.ExchangedDocument.IncludedNote.Count), 'list item');
    Inv.Clear;
    Check(Inv.IsEmpty, 'empty after Clear');
  finally
    Inv.Free;
  end;
end;

procedure TestReadSample;
var
  Inv: TLandrixCIIInvoice;
  D: TLandrixEInvoiceDiagnostics;
begin
  D := TLandrixEInvoiceDiagnostics.Create;
  try
    Inv := ReadCII(Sample, D);
    try
      CheckEquals(0, Integer(D.Count), 'no diagnostics: ' + string(D.ToText));
      CheckEqualsInvoiceStr('R-1', Inv.ExchangedDocument.ID.Value, 'ID');
      CheckEqualsInvoiceStr('380', Inv.ExchangedDocument.TypeCode, 'TypeCode');
      CheckEqualsInvoiceStr('20261016', Inv.ExchangedDocument.IssueDateTime.Value, 'date');
      CheckEqualsInvoiceStr('102', Inv.ExchangedDocument.IssueDateTime.Format, 'date format');
      CheckEquals(2, Integer(Inv.ExchangedDocument.IncludedNote.Count), 'two notes');
      CheckEqualsInvoiceStr('AAI', Inv.ExchangedDocument.IncludedNote[1].SubjectCode.Value, 'note subject');
      CheckEqualsInvoiceStr('100.00',
        Inv.SupplyChainTradeTransaction.ApplicableHeaderTradeSettlement.SpecifiedTradeSettlementHeaderMonetarySummation.LineTotalAmount.Value,
        'amount kept as text');
      CheckEqualsInvoiceStr('EUR',
        Inv.SupplyChainTradeTransaction.ApplicableHeaderTradeSettlement.SpecifiedTradeSettlementHeaderMonetarySummation.TaxTotalAmount[0].CurrencyID,
        'repeated amount with currency');
    finally
      Inv.Free;
    end;
  finally
    D.Free;
  end;
end;

procedure TestRoundTripSample;
var
  Inv: TLandrixCIIInvoice;
  DR, DW: TLandrixEInvoiceDiagnostics;
  Written: TLandrixXmlUtf8;
  Diff: string;
begin
  DR := TLandrixEInvoiceDiagnostics.Create;
  DW := TLandrixEInvoiceDiagnostics.Create;
  try
    Inv := ReadCII(Sample, DR);
    try
      Written := WriteCII(Inv, DW);
    finally
      Inv.Free;
    end;
    CheckEquals(0, Integer(DR.Count), 'no read diagnostics: ' + string(DR.ToText));
    { the sample has no line item and no tax breakdown, both required }
    CheckEquals(2, DW.CountOf(edk_MissingElement), 'missing required elements: ' + string(DW.ToText));
    Check(Pos('IncludedSupplyChainTradeLineItem', DW[0].Path + DW[1].Path) > 0, 'missing line item reported');
    Check(XmlEquivalent(Sample, Written, Diff), 'round trip: ' + Diff);
  finally
    DW.Free;
    DR.Free;
  end;
end;

{ A required element without content is written as an empty element: the
  schema allows it when its type has no required content, and the reader
  needs it in profiles such as MINIMUM (ApplicableHeaderTradeDelivery). }
procedure TestWriteEmptyRequired;
var
  Inv: TLandrixCIIInvoice;
  D: TLandrixEInvoiceDiagnostics;
  Written: string;
begin
  D := TLandrixEInvoiceDiagnostics.Create;
  Inv := TLandrixCIIInvoice.Create;
  try
    Written := LandrixXmlUtf8ToString(WriteCII(Inv, D));
    Check(Pos('<ram:ApplicableHeaderTradeDelivery', Written) > 0, 'empty delivery written');
    Check(Pos('<rsm:ExchangedDocumentContext', Written) > 0, 'empty context written');
    Check(D.CountOf(edk_MissingElement) > 0, 'missing content reported');
    Check(D.HasErrors, 'missing content is an error');
    Check(D[0].Severity = eds_Error, 'severity set from the kind');
    Check(LandrixEInvoiceDiagnosticDefaultSeverity(edk_UnknownCode) = eds_Info, 'unknown code is information');
    Check(LandrixEInvoiceDiagnosticDefaultSeverity(edk_NotAllowed) = eds_Warning, 'left out content is a warning');
  finally
    Inv.Free;
    D.Free;
  end;
end;

procedure TestDiagnostics;
const
  Bad =
    '<rsm:CrossIndustryInvoice ' + NsDecl + ' foo="1">' +
    '<rsm:ExchangedDocument>' +
    '<ram:ID>R-1</ram:ID><ram:ID>R-2</ram:ID>' +
    '<ram:Unknown>x</ram:Unknown>' +
    'stray' +
    '</rsm:ExchangedDocument>' +
    '<rsm:SupplyChainTradeTransaction><ram:ApplicableHeaderTradeSettlement>' +
    '<ram:SpecifiedTradeSettlementHeaderMonetarySummation>' +
    '<ram:LineTotalAmount>1,00</ram:LineTotalAmount>' +
    '</ram:SpecifiedTradeSettlementHeaderMonetarySummation>' +
    '</ram:ApplicableHeaderTradeSettlement></rsm:SupplyChainTradeTransaction>' +
    '</rsm:CrossIndustryInvoice>';
var
  Inv: TLandrixCIIInvoice;
  D: TLandrixEInvoiceDiagnostics;
begin
  D := TLandrixEInvoiceDiagnostics.Create;
  try
    Inv := ReadCII(Bad, D);
    try
      CheckEquals(1, D.CountOf(edk_UnknownAttribute), 'unknown attribute');
      CheckEquals(1, D.CountOf(edk_DuplicateElement), 'duplicate ID');
      CheckEquals(1, D.CountOf(edk_UnknownElement), 'unknown element');
      CheckEquals(1, D.CountOf(edk_UnexpectedText), 'stray text');
      CheckEquals(1, D.CountOf(edk_InvalidValue), 'invalid decimal');
      CheckEqualsInvoiceStr('R-1', Inv.ExchangedDocument.ID.Value, 'first ID kept');
      CheckEqualsInvoiceStr('1,00',
        Inv.SupplyChainTradeTransaction.ApplicableHeaderTradeSettlement.SpecifiedTradeSettlementHeaderMonetarySummation.LineTotalAmount.Value,
        'invalid value kept as text');
      Check(D[0].Line > 0, 'diagnostic has a position');
    finally
      Inv.Free;
    end;
  finally
    D.Free;
  end;
end;

procedure TestTrailingGarbage;
begin
  try
    ReadCII(Sample + '<junk', nil).Free;
    FailNotRaised('ELandrixXmlError for content after the root element');
  except
    on ELandrixXmlError do ;
  end;
end;

procedure TestWrongRoot;
begin
  try
    ReadCII('<Invoice xmlns="urn:oasis:names:specification:ubl:schema:xsd:Invoice-2"/>', nil).Free;
    FailNotRaised('ELandrixEInvoiceError for a UBL root');
  except
    on E: ELandrixEInvoiceError do ;
  end;
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

function LocalDir(const AName: string): string;
begin
  Result := RepositoryRoot + 'tests' + PathDelim + 'data' + PathDelim + 'local' + PathDelim +
    AName + PathDelim;
end;

procedure TestRoundTripLocalFiles;
var
  Dir: string;
  SR: TSearchRec;
  Xml, Written: TLandrixXmlUtf8;
  Inv: TLandrixCIIInvoice;
  D: TLandrixEInvoiceDiagnostics;
  Diff: string;
  Files, Failed: Integer;
begin
  Dir := LocalDir('cii');
  if not DirectoryExists(Dir) then
  begin
    Skip('no local CII files in ' + Dir);
    Exit;
  end;
  Files := 0;
  Failed := 0;
  if FindFirst(Dir + '*.xml', faAnyFile, SR) = 0 then
  try
    repeat
      Inc(Files);
      D := TLandrixEInvoiceDiagnostics.Create;
      try
        try
          Xml := LoadFile(Dir + SR.Name);
          Inv := ReadCII(Xml, D);
          try
            Written := WriteCII(Inv, nil);
          finally
            Inv.Free;
          end;
          if D.CountOf(edk_UnknownElement) + D.CountOf(edk_DuplicateElement) > 0 then
          begin
            Inc(Failed);
            WriteLn('  ', SR.Name, ': ', string(D.ToText));
          end
          else if not XmlEquivalent(Xml, Written, Diff) then
          begin
            Inc(Failed);
            WriteLn('  ', SR.Name, ': ', Diff);
          end;
        except
          on E: Exception do
          begin
            Inc(Failed);
            WriteLn('  ', SR.Name, ': ', E.ClassName, ': ', E.Message);
          end;
        end;
      finally
        D.Free;
      end;
    until FindNext(SR) <> 0;
  finally
    FindClose(SR);
  end;
  Check(Files > 0, 'local CII files found');
  CheckEquals(0, Failed, IntToStr(Files) + ' files, failed round trips');
end;

{ Schema-invalid documents (wrong order, missing or repeated elements) are
  read with diagnostics; only documents that are not well-formed raise
  ELandrixXmlError. }
procedure TestReadLocalInvalidFiles;
var
  Dir: string;
  SR: TSearchRec;
  Files, Failed: Integer;
begin
  Dir := LocalDir('cii-invalid');
  if not DirectoryExists(Dir) then
  begin
    Skip('no local invalid CII files in ' + Dir);
    Exit;
  end;
  Files := 0;
  Failed := 0;
  if FindFirst(Dir + '*.xml', faAnyFile, SR) = 0 then
  try
    repeat
      Inc(Files);
      try
        ReadCII(LoadFile(Dir + SR.Name), nil).Free;
      except
        on ELandrixXmlError do ;
        on E: Exception do
        begin
          Inc(Failed);
          WriteLn('  ', SR.Name, ': ', E.ClassName, ': ', E.Message);
        end;
      end;
    until FindNext(SR) <> 0;
  finally
    FindClose(SR);
  end;
  Check(Files > 0, 'local invalid CII files found');
  CheckEquals(0, Failed, IntToStr(Files) + ' files, unexpected exceptions');
end;

procedure Register;
begin
  RegisterTest('CII.ModelLazyAndEmpty', TestModelLazyAndEmpty);
  RegisterTest('CII.ReadSample', TestReadSample);
  RegisterTest('CII.RoundTripSample', TestRoundTripSample);
  RegisterTest('CII.WriteEmptyRequired', TestWriteEmptyRequired);
  RegisterTest('CII.Diagnostics', TestDiagnostics);
  RegisterTest('CII.WrongRoot', TestWrongRoot);
  RegisterTest('CII.TrailingGarbage', TestTrailingGarbage);
  RegisterTest('CII.RoundTripLocalFiles', TestRoundTripLocalFiles);
  RegisterTest('CII.ReadLocalInvalidFiles', TestReadLocalInvalidFiles);
end;

end.
