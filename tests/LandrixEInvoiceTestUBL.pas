{
  EInvoice-for-Pascal

  Copyright (C) 2026 Landrix Software GmbH & Co. KG

  This file is dual-licensed under:
  - GNU GPL version 3 or later; or
  - the Landrix Software Commercial License.

  See LICENSE and COMMERCIAL-LICENSE.md.

  SPDX-License-Identifier: GPL-3.0-or-later OR LicenseRef-Landrix-Commercial
}

{ Tests for the generated UBL syntax model, reader and writer, including the
  round trip of local example files (tests/data/local/ubl/*.xml) and the
  reading of local schema-invalid files (tests/data/local/ubl-invalid/*.xml);
  both are skipped when the folder does not exist. }

unit LandrixEInvoiceTestUBL;

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
  LandrixEInvoiceUBL,
  LandrixEInvoiceUBLReader,
  LandrixEInvoiceUBLWriter,
  LandrixEInvoiceTestFramework,
  LandrixEInvoiceTestXmlCompare;

const
  NsDecl =
    'xmlns:cac="urn:oasis:names:specification:ubl:schema:xsd:CommonAggregateComponents-2" ' +
    'xmlns:cbc="urn:oasis:names:specification:ubl:schema:xsd:CommonBasicComponents-2"';

  Parties =
    '<cac:AccountingSupplierParty><cac:Party><cbc:EndpointID schemeID="EM">s@example.com</cbc:EndpointID>' +
    '<cac:PartyName><cbc:Name>S</cbc:Name></cac:PartyName></cac:Party></cac:AccountingSupplierParty>' +
    '<cac:AccountingCustomerParty><cac:Party><cac:PartyName><cbc:Name>B</cbc:Name></cac:PartyName>' +
    '</cac:Party></cac:AccountingCustomerParty>';

  Sample =
    '<?xml version="1.0" encoding="UTF-8"?>' +
    '<Invoice xmlns="urn:oasis:names:specification:ubl:schema:xsd:Invoice-2" ' + NsDecl + '>' +
    '<cbc:CustomizationID>urn:cen.eu:en16931:2017</cbc:CustomizationID>' +
    '<cbc:ID>R-1</cbc:ID>' +
    '<cbc:IssueDate>2026-10-18</cbc:IssueDate>' +
    '<cbc:InvoiceTypeCode>380</cbc:InvoiceTypeCode>' +
    '<cbc:Note>a</cbc:Note><cbc:Note>b</cbc:Note>' +
    '<cbc:DocumentCurrencyCode>EUR</cbc:DocumentCurrencyCode>' +
    Parties +
    '<cac:TaxTotal><cbc:TaxAmount currencyID="EUR">19.00</cbc:TaxAmount></cac:TaxTotal>' +
    '<cac:LegalMonetaryTotal><cbc:PayableAmount currencyID="EUR">119.00</cbc:PayableAmount>' +
    '</cac:LegalMonetaryTotal>' +
    '<cac:InvoiceLine><cbc:ID>1</cbc:ID>' +
    '<cbc:InvoicedQuantity unitCode="H87">1</cbc:InvoicedQuantity>' +
    '<cbc:LineExtensionAmount currencyID="EUR">100.00</cbc:LineExtensionAmount>' +
    '<cac:Item><cbc:Name>Item</cbc:Name></cac:Item>' +
    '<cac:Price><cbc:PriceAmount currencyID="EUR">100.00</cbc:PriceAmount></cac:Price>' +
    '</cac:InvoiceLine>' +
    '</Invoice>';

  CreditNoteSample =
    '<CreditNote xmlns="urn:oasis:names:specification:ubl:schema:xsd:CreditNote-2" ' + NsDecl + '>' +
    '<cbc:ID>G-1</cbc:ID>' +
    '<cbc:IssueDate>2026-10-18</cbc:IssueDate>' +
    '<cbc:CreditNoteTypeCode>381</cbc:CreditNoteTypeCode>' +
    Parties +
    '<cac:LegalMonetaryTotal><cbc:PayableAmount currencyID="EUR">-10.00</cbc:PayableAmount>' +
    '</cac:LegalMonetaryTotal>' +
    '<cac:CreditNoteLine><cbc:ID>1</cbc:ID>' +
    '<cbc:CreditedQuantity unitCode="H87">1</cbc:CreditedQuantity>' +
    '<cac:Item><cbc:Name>Item</cbc:Name></cac:Item>' +
    '<cac:Price><cbc:PriceAmount currencyID="EUR">10.00</cbc:PriceAmount></cac:Price>' +
    '</cac:CreditNoteLine>' +
    '</CreditNote>';

function LoadReader(const Xml: TLandrixXmlUtf8): TLandrixXmlReader;
begin
  Result := TLandrixXmlReader.Create;
  try
    Result.LoadFromUtf8(Xml);
  except
    Result.Free;
    raise;
  end;
end;

function ReadInvoice(const Xml: TLandrixXmlUtf8; Diagnostics: TLandrixEInvoiceDiagnostics): TLandrixUBLInvoice;
var
  R: TLandrixXmlReader;
begin
  R := LoadReader(Xml);
  try
    Result := LandrixEInvoiceReadUBLInvoice(R, Diagnostics);
  finally
    R.Free;
  end;
end;

function ReadCreditNote(const Xml: TLandrixXmlUtf8; Diagnostics: TLandrixEInvoiceDiagnostics): TLandrixUBLCreditNote;
var
  R: TLandrixXmlReader;
begin
  R := LoadReader(Xml);
  try
    Result := LandrixEInvoiceReadUBLCreditNote(R, Diagnostics);
  finally
    R.Free;
  end;
end;

function WriteInvoice(Inv: TLandrixUBLInvoice; Diagnostics: TLandrixEInvoiceDiagnostics): TLandrixXmlUtf8;
var
  W: TLandrixXmlWriter;
begin
  W := TLandrixXmlWriter.Create;
  try
    W.Indent := True;
    LandrixEInvoiceWriteUBLInvoice(Inv, W, Diagnostics);
    W.EndDocument;
    Result := W.AsUtf8;
  finally
    W.Free;
  end;
end;

function WriteCreditNote(Cn: TLandrixUBLCreditNote; Diagnostics: TLandrixEInvoiceDiagnostics): TLandrixXmlUtf8;
var
  W: TLandrixXmlWriter;
begin
  W := TLandrixXmlWriter.Create;
  try
    W.Indent := True;
    LandrixEInvoiceWriteUBLCreditNote(Cn, W, Diagnostics);
    W.EndDocument;
    Result := W.AsUtf8;
  finally
    W.Free;
  end;
end;

procedure TestModelLazyAndEmpty;
var
  Inv: TLandrixUBLInvoice;
begin
  Inv := TLandrixUBLInvoice.Create;
  try
    Check(Inv.IsEmpty, 'new invoice is empty');
    Check(Inv.AccountingSupplierParty.Party <> nil, 'child created on access');
    Check(Inv.Note.Count = 0, 'text list created on access');
    Check(Inv.IsEmpty, 'access alone does not make it present');
    Inv.Note.Add('x');
    Check(not Inv.IsEmpty, 'a note makes it present');
    Inv.Clear;
    Check(Inv.IsEmpty, 'empty after Clear');
    Inv.ID.Value := 'R-1';
    Check(not Inv.IsEmpty, 'set value makes it present');
  finally
    Inv.Free;
  end;
end;

procedure TestReadSample;
var
  Inv: TLandrixUBLInvoice;
  D: TLandrixEInvoiceDiagnostics;
begin
  D := TLandrixEInvoiceDiagnostics.Create;
  try
    Inv := ReadInvoice(Sample, D);
    try
      CheckEquals(0, Integer(D.Count), 'no diagnostics: ' + string(D.ToText));
      CheckEqualsInvoiceStr('R-1', Inv.ID.Value, 'ID');
      CheckEqualsInvoiceStr('2026-10-18', Inv.IssueDate, 'date');
      CheckEqualsInvoiceStr('380', Inv.InvoiceTypeCode.Value, 'type code');
      CheckEquals(2, Integer(Inv.Note.Count), 'two notes');
      CheckEqualsInvoiceStr('b', Inv.Note[1], 'second note');
      CheckEqualsInvoiceStr('EM', Inv.AccountingSupplierParty.Party.EndpointID.SchemeID, 'scheme');
      CheckEqualsInvoiceStr('119.00', Inv.LegalMonetaryTotal.PayableAmount.Value, 'amount as text');
      CheckEqualsInvoiceStr('EUR', Inv.LegalMonetaryTotal.PayableAmount.CurrencyID, 'currency');
      CheckEquals(1, Integer(Inv.InvoiceLine.Count), 'one line');
      CheckEqualsInvoiceStr('H87', Inv.InvoiceLine[0].InvoicedQuantity.UnitCode, 'unit');
    finally
      Inv.Free;
    end;
  finally
    D.Free;
  end;
end;

procedure TestRoundTripSample;
var
  Inv: TLandrixUBLInvoice;
  DR, DW: TLandrixEInvoiceDiagnostics;
  Written: TLandrixXmlUtf8;
  Diff: string;
begin
  DR := TLandrixEInvoiceDiagnostics.Create;
  DW := TLandrixEInvoiceDiagnostics.Create;
  try
    Inv := ReadInvoice(Sample, DR);
    try
      Written := WriteInvoice(Inv, DW);
    finally
      Inv.Free;
    end;
    CheckEquals(0, Integer(DR.Count), 'no read diagnostics: ' + string(DR.ToText));
    CheckEquals(0, Integer(DW.Count), 'no write diagnostics: ' + string(DW.ToText));
    Check(XmlEquivalent(Sample, Written, Diff), 'round trip: ' + Diff);
    Check(Pos('<Invoice xmlns="urn:oasis:names:specification:ubl:schema:xsd:Invoice-2"',
      LandrixXmlUtf8ToString(Written)) > 0, 'root in its default namespace');
  finally
    DW.Free;
    DR.Free;
  end;
end;

procedure TestCreditNote;
var
  Cn: TLandrixUBLCreditNote;
  D: TLandrixEInvoiceDiagnostics;
  Diff: string;
begin
  D := TLandrixEInvoiceDiagnostics.Create;
  try
    Cn := ReadCreditNote(CreditNoteSample, D);
    try
      CheckEquals(0, Integer(D.Count), 'no diagnostics: ' + string(D.ToText));
      CheckEqualsInvoiceStr('381', Cn.CreditNoteTypeCode.Value, 'type code');
      CheckEqualsInvoiceStr('1', Cn.CreditNoteLine[0].CreditedQuantity.Value, 'credited quantity');
      Check(XmlEquivalent(CreditNoteSample, WriteCreditNote(Cn, D), Diff), 'round trip: ' + Diff);
      CheckEquals(0, Integer(D.Count), 'no write diagnostics: ' + string(D.ToText));
    finally
      Cn.Free;
    end;
  finally
    D.Free;
  end;
end;

{ ext:UBLExtensions is skipped as a whole with its own diagnostic; a
  cbc:CustomizationID inside it must not reach the model. }
procedure TestSkippedExtension;
const
  WithExtension =
    '<Invoice xmlns="urn:oasis:names:specification:ubl:schema:xsd:Invoice-2" ' + NsDecl + ' ' +
    'xmlns:ext="urn:oasis:names:specification:ubl:schema:xsd:CommonExtensionComponents-2">' +
    '<ext:UBLExtensions><ext:UBLExtension><ext:ExtensionContent>' +
    '<cbc:CustomizationID>inner</cbc:CustomizationID>' +
    '</ext:ExtensionContent></ext:UBLExtension></ext:UBLExtensions>' +
    '<cbc:CustomizationID>outer</cbc:CustomizationID>' +
    '<cbc:ID>R-1</cbc:ID>' +
    '</Invoice>';
var
  Inv: TLandrixUBLInvoice;
  D: TLandrixEInvoiceDiagnostics;
begin
  D := TLandrixEInvoiceDiagnostics.Create;
  try
    Inv := ReadInvoice(WithExtension, D);
    try
      CheckEquals(1, D.CountOf(edk_SkippedExtension), 'extension reported');
      CheckEquals(0, D.CountOf(edk_UnknownElement), 'not reported as unknown');
      CheckEquals(0, D.CountOf(edk_DuplicateElement), 'inner element never read');
      CheckEqualsInvoiceStr('outer', Inv.CustomizationID.Value, 'outer CustomizationID');
    finally
      Inv.Free;
    end;
  finally
    D.Free;
  end;
end;

procedure TestDiagnostics;
const
  Bad =
    '<Invoice xmlns="urn:oasis:names:specification:ubl:schema:xsd:Invoice-2" ' + NsDecl + '>' +
    '<cbc:ID>R-1</cbc:ID><cbc:ID>R-2</cbc:ID>' +
    '<cbc:IssueDate>18.10.2026</cbc:IssueDate>' +
    '<cbc:Note languageID="de">x</cbc:Note>' +
    '<cbc:UnknownThing>x</cbc:UnknownThing>' +
    '</Invoice>';
var
  Inv: TLandrixUBLInvoice;
  D: TLandrixEInvoiceDiagnostics;
begin
  D := TLandrixEInvoiceDiagnostics.Create;
  try
    Inv := ReadInvoice(Bad, D);
    try
      CheckEquals(1, D.CountOf(edk_DuplicateElement), 'duplicate ID');
      CheckEquals(1, D.CountOf(edk_InvalidValue), 'invalid date');
      CheckEquals(1, D.CountOf(edk_UnknownAttribute), 'languageID on text');
      CheckEquals(1, D.CountOf(edk_UnknownElement), 'unknown element');
      CheckEqualsInvoiceStr('18.10.2026', Inv.IssueDate, 'invalid value kept as text');
      CheckEqualsInvoiceStr('x', Inv.Note[0], 'text kept without the attribute');
    finally
      Inv.Free;
    end;
  finally
    D.Free;
  end;
end;

procedure TestWrongRoot;
begin
  try
    ReadInvoice(CreditNoteSample, nil).Free;
    FailNotRaised('ELandrixEInvoiceError for a credit note read as invoice');
  except
    on ELandrixEInvoiceError do ;
  end;
  try
    ReadCreditNote('<rsm:CrossIndustryInvoice ' +
      'xmlns:rsm="urn:un:unece:uncefact:data:standard:CrossIndustryInvoice:100"/>', nil).Free;
    FailNotRaised('ELandrixEInvoiceError for a CII root');
  except
    on ELandrixEInvoiceError do ;
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

function IsCreditNote(const Xml: TLandrixXmlUtf8): Boolean;
var
  R: TLandrixXmlReader;
begin
  R := LoadReader(Xml);
  try
    while R.Read and (R.TokenType <> xttStartElement) do
      ;
    Result := LandrixXmlSpanEquals(R.LocalNameSpan, 'CreditNote');
  finally
    R.Free;
  end;
end;

{ Reads and writes one file; Written is '' if the reader raised. }
function RoundTrip(const Xml: TLandrixXmlUtf8; D: TLandrixEInvoiceDiagnostics): TLandrixXmlUtf8;
var
  Inv: TLandrixUBLInvoice;
  Cn: TLandrixUBLCreditNote;
begin
  if IsCreditNote(Xml) then
  begin
    Cn := ReadCreditNote(Xml, D);
    try
      Result := WriteCreditNote(Cn, nil);
    finally
      Cn.Free;
    end;
  end
  else
  begin
    Inv := ReadInvoice(Xml, D);
    try
      Result := WriteInvoice(Inv, nil);
    finally
      Inv.Free;
    end;
  end;
end;

procedure TestRoundTripLocalFiles;
var
  Dir: string;
  SR: TSearchRec;
  Xml, Written: TLandrixXmlUtf8;
  D: TLandrixEInvoiceDiagnostics;
  Diff: string;
  Files, Failed: Integer;
begin
  Dir := LocalDir('ubl');
  if not DirectoryExists(Dir) then
  begin
    Skip('no local UBL files in ' + Dir);
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
          Written := RoundTrip(Xml, D);
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
  Check(Files > 0, 'local UBL files found');
  CheckEquals(0, Failed, IntToStr(Files) + ' files, failed round trips');
end;

{ Schema-invalid documents are read with diagnostics; only documents that
  are not well-formed raise ELandrixXmlError. }
procedure TestReadLocalInvalidFiles;
var
  Dir: string;
  SR: TSearchRec;
  Files, Failed: Integer;
begin
  Dir := LocalDir('ubl-invalid');
  if not DirectoryExists(Dir) then
  begin
    Skip('no local invalid UBL files in ' + Dir);
    Exit;
  end;
  Files := 0;
  Failed := 0;
  if FindFirst(Dir + '*.xml', faAnyFile, SR) = 0 then
  try
    repeat
      Inc(Files);
      try
        RoundTrip(LoadFile(Dir + SR.Name), nil);
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
  Check(Files > 0, 'local invalid UBL files found');
  CheckEquals(0, Failed, IntToStr(Files) + ' files, unexpected exceptions');
end;

{ Rules of the round-trip comparison (tests/LandrixEInvoiceTestXmlCompare). }
procedure TestCompareRules;
var
  Diff: string;
begin
  Check(XmlEquivalent('<a:r xmlns:a="u"><a:x>1</a:x></a:r>', '<r xmlns="u"><x>1</x></r>', Diff),
    'prefixes are ignored: ' + Diff);
  Check(XmlEquivalent('<r><x b="2" a="1"/></r>', '<r><x a="1" b="2"/></r>', Diff),
    'attribute order is ignored: ' + Diff);
  Check(XmlEquivalent('<r><x/><y><z></z></y>t</r>', '<r>t</r>', Diff),
    'empty elements count as absent: ' + Diff);
  Check(XmlEquivalent('<r><x a="">1</x></r>', '<r><x>1</x></r>', Diff),
    'empty attributes count as absent: ' + Diff);
  Check(not XmlEquivalent('<r><x a="1">1</x></r>', '<r><x>1</x></r>', Diff), 'attribute value differs');
  Check(not XmlEquivalent('<r><x>1</x></r>', '<r><x>1 </x></r>', Diff), 'text is compared exactly');
  Check(not XmlEquivalent('<r><x/><y>1</y></r>', '<r><y>1</y><x>2</x></r>', Diff), 'order matters');
end;

procedure Register;
begin
  RegisterTest('UBL.ModelLazyAndEmpty', TestModelLazyAndEmpty);
  RegisterTest('UBL.ReadSample', TestReadSample);
  RegisterTest('UBL.RoundTripSample', TestRoundTripSample);
  RegisterTest('UBL.CreditNote', TestCreditNote);
  RegisterTest('UBL.SkippedExtension', TestSkippedExtension);
  RegisterTest('UBL.Diagnostics', TestDiagnostics);
  RegisterTest('UBL.WrongRoot', TestWrongRoot);
  RegisterTest('UBL.RoundTripLocalFiles', TestRoundTripLocalFiles);
  RegisterTest('UBL.ReadLocalInvalidFiles', TestReadLocalInvalidFiles);
  RegisterTest('UBL.CompareRules', TestCompareRules);
end;

end.
