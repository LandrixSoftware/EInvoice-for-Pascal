{
  EInvoice-for-Pascal

  Copyright (C) 2026 Landrix Software GmbH & Co. KG

  This file is dual-licensed under:
  - GNU GPL version 3 or later; or
  - the Landrix Software Commercial License.

  See LICENSE and COMMERCIAL-LICENSE.md.

  SPDX-License-Identifier: GPL-3.0-or-later OR LicenseRef-Landrix-Commercial
}

{ Tests for LandrixEInvoiceMapUBL against the golden files of
  XRechnung-for-Delphi (tests/data/local/golden/, git-ignored):
  - Golden write: every UBL scenario of LandrixEInvoiceTestScenarios is
    mapped with the root LandrixEInvoiceUBLRootFor chooses, written and
    compared with its golden file;
  - Golden read: every UBL golden file is read, mapped to the invoice model,
    mapped back with the specification of its identifier, written and
    compared with itself; nothing may be reported as not mapped.
  Both are skipped when the local folders are missing. }

unit LandrixEInvoiceTestMapUBL;

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
  LandrixEInvoiceUBL,
  LandrixEInvoiceUBLReader,
  LandrixEInvoiceUBLWriter,
  LandrixEInvoiceMapUBL,
  LandrixEInvoiceCII,
  LandrixEInvoiceCIIReader,
  LandrixEInvoiceCIIWriter,
  LandrixEInvoiceMapCII,
  LandrixEInvoiceTestFramework,
  LandrixEInvoiceTestMapCII,
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

{ Maps AInvoice with the root of LandrixEInvoiceUBLRootFor and writes it. }
function MapAndWrite(AInvoice: TLandrixInvoice; const ASpec: TLandrixEInvoiceSpec;
  D: TLandrixEInvoiceDiagnostics): TLandrixXmlUtf8;
var
  W: TLandrixXmlWriter;
  UBLInvoice: TLandrixUBLInvoice;
  UBLCreditNote: TLandrixUBLCreditNote;
begin
  W := TLandrixXmlWriter.Create;
  try
    W.Indent := True;
    if LandrixEInvoiceUBLRootFor(AInvoice, ASpec) = eur_CreditNote then
    begin
      UBLCreditNote := LandrixEInvoiceInvoiceToUBLCreditNote(AInvoice, ASpec, D);
      try
        LandrixEInvoiceWriteUBLCreditNote(UBLCreditNote, W, D);
      finally
        UBLCreditNote.Free;
      end;
    end
    else
    begin
      UBLInvoice := LandrixEInvoiceInvoiceToUBLInvoice(AInvoice, ASpec, D);
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

function IsCreditNote(const AXml: TLandrixXmlUtf8): Boolean;
var
  R: TLandrixXmlReader;
begin
  R := TLandrixXmlReader.Create;
  try
    R.LoadFromUtf8(AXml);
    while R.Read and (R.TokenType <> xttStartElement) do
      ;
    Result := LandrixXmlSpanEquals(R.LocalNameSpan, 'CreditNote');
  finally
    R.Free;
  end;
end;

{ Reads a UBL document of either root into AInvoice; returns its BT-24. }
function ReadAndMap(const AXml: TLandrixXmlUtf8; AInvoice: TLandrixInvoice; D: TLandrixEInvoiceDiagnostics;
  out ARoot: string): TLandrixEInvoiceString;
var
  R: TLandrixXmlReader;
  UBLInvoice: TLandrixUBLInvoice;
  UBLCreditNote: TLandrixUBLCreditNote;
begin
  R := TLandrixXmlReader.Create;
  try
    R.LoadFromUtf8(AXml);
    if IsCreditNote(AXml) then
    begin
      ARoot := 'CreditNote';
      UBLCreditNote := LandrixEInvoiceReadUBLCreditNote(R, D);
      try
        LandrixEInvoiceUBLCreditNoteToInvoice(UBLCreditNote, AInvoice, D);
        Result := UBLCreditNote.CustomizationID.Value;
      finally
        UBLCreditNote.Free;
      end;
    end
    else
    begin
      ARoot := 'Invoice';
      UBLInvoice := LandrixEInvoiceReadUBLInvoice(R, D);
      try
        LandrixEInvoiceUBLInvoiceToInvoice(UBLInvoice, AInvoice, D);
        Result := UBLInvoice.CustomizationID.Value;
      finally
        UBLInvoice.Free;
      end;
    end;
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

{ edk_NotAllowed reports of content that was left out (not of discouraged
  content that was written). }
function LeftOut(D: TLandrixEInvoiceDiagnostics): string;
var
  I: TLandrixEInvoiceListIndex;
begin
  Result := '';
  for I := 0 to D.Count - 1 do
    if (D[I].Kind = edk_NotAllowed) and (Pos('left out', string(D[I].Message)) > 0) then
      Result := Result + '    NotAllowed ' + string(D[I].Path) + ': ' + string(D[I].Message) + #13#10;
end;

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
  D: TLandrixEInvoiceDiagnostics;
  Written: TLandrixXmlUtf8;
  Diff, Errors: string;
begin
  State := PGoldenState(AData);
  if not LandrixEInvoiceFindSpec(ATarget, Spec) or (Spec.Target.Syntax <> esy_UBL) then
    Exit;
  Inc(State^.Files);
  D := TLandrixEInvoiceDiagnostics.Create;
  try
    Written := MapAndWrite(AInvoice, Spec, D);
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
  CheckEquals(44, State.Files, 'UBL outputs');
  CheckEquals(0, State.Failed, IntToStr(State.Files) + ' UBL outputs, differences to the golden files');
end;

procedure TestGoldenRead;
var
  Dir, Root: string;
  SR: TSearchRec;
  Xml, Written: TLandrixXmlUtf8;
  Invoice: TLandrixInvoice;
  D: TLandrixEInvoiceDiagnostics;
  Spec: TLandrixEInvoiceSpec;
  CustomizationID: TLandrixEInvoiceString;
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
      if Pos('-ubl', SR.Name) = 0 then
        Continue;
      Inc(Files);
      Xml := LoadFile(Dir + SR.Name);
      D := TLandrixEInvoiceDiagnostics.Create;
      Invoice := TLandrixInvoice.Create;
      try
        CustomizationID := ReadAndMap(Xml, Invoice, D, Root);
        if not LandrixEInvoiceDetectSpec(TLandrixEInvoiceString(Root), CustomizationID, Spec, UsesExtension) then
        begin
          Inc(Failed);
          WriteLn('  ', SR.Name, ': specification not detected');
          Continue;
        end;
        Written := MapAndWrite(Invoice, Spec, D);
        Lost := DiagnosticsOf(D, [edk_NotMapped, edk_ConversionFailed, edk_UnknownElement]) + LeftOut(D);
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
  CheckEquals(44, Files, 'UBL golden files');
  CheckEquals(0, Failed, IntToStr(Files) + ' UBL golden files, failed read round trips');
end;

{ Every local UBL example (valid and schema-invalid) is read, mapped to the
  invoice model, mapped back and written without an exception; only
  documents that are not well-formed may raise ELandrixXmlError. }
procedure TestLocalFiles;
var
  Dirs: array[0..1] of string;
  Dir, Root: string;
  K: Integer;
  SR: TSearchRec;
  Invoice: TLandrixInvoice;
  D: TLandrixEInvoiceDiagnostics;
  Spec: TLandrixEInvoiceSpec;
  CustomizationID: TLandrixEInvoiceString;
  UsesExtension: Boolean;
  Files, Failed: Integer;
begin
  Dirs[0] := LocalDir('ubl');
  Dirs[1] := LocalDir('ubl-invalid');
  if not DirectoryExists(Dirs[0]) then
  begin
    Skip('no local UBL files in ' + Dirs[0]);
    Exit;
  end;
  Files := 0;
  Failed := 0;
  for K := 0 to 1 do
  begin
    Dir := Dirs[K];
    if FindFirst(Dir + '*.xml', faAnyFile, SR) = 0 then
    try
      repeat
        Inc(Files);
        D := TLandrixEInvoiceDiagnostics.Create;
        Invoice := TLandrixInvoice.Create;
        try
          try
            CustomizationID := ReadAndMap(LoadFile(Dir + SR.Name), Invoice, D, Root);
            if not LandrixEInvoiceDetectSpec(TLandrixEInvoiceString(Root), CustomizationID, Spec, UsesExtension) or
               not Spec.CanWrite then
              LandrixEInvoiceFindSpec(TLandrixEInvoiceTargets.XRechnung('3.0', esy_UBL), Spec);
            MapAndWrite(Invoice, Spec, D);
          except
            on ELandrixXmlError do ;
            on E: Exception do
            begin
              Inc(Failed);
              WriteLn('  ', SR.Name, ': ', E.ClassName, ': ', E.Message);
            end;
          end;
        finally
          Invoice.Free;
          D.Free;
        end;
      until FindNext(SR) <> 0;
    finally
      FindClose(SR);
    end;
  end;
  Check(Files > 0, 'local UBL files found');
  CheckEquals(0, Failed, IntToStr(Files) + ' files, unexpected exceptions');
end;

function CIIToInvoice(const AXml: TLandrixXmlUtf8; AInvoice: TLandrixInvoice; D: TLandrixEInvoiceDiagnostics): Boolean;
var
  R: TLandrixXmlReader;
  CII: TLandrixCIIInvoice;
begin
  R := TLandrixXmlReader.Create;
  try
    R.LoadFromUtf8(AXml);
    CII := LandrixEInvoiceReadCII(R, D);
    try
      LandrixEInvoiceCIIToInvoice(CII, AInvoice, D);
      Result := True;
    finally
      CII.Free;
    end;
  finally
    R.Free;
  end;
end;

function InvoiceToCIIXml(AInvoice: TLandrixInvoice; const ASpec: TLandrixEInvoiceSpec;
  D: TLandrixEInvoiceDiagnostics): TLandrixXmlUtf8;
var
  W: TLandrixXmlWriter;
  CII: TLandrixCIIInvoice;
begin
  W := TLandrixXmlWriter.Create;
  try
    W.Indent := True;
    CII := LandrixEInvoiceInvoiceToCII(AInvoice, ASpec, D);
    try
      LandrixEInvoiceWriteCII(CII, W, D);
    finally
      CII.Free;
    end;
    W.EndDocument;
    Result := W.AsUtf8;
  finally
    W.Free;
  end;
end;

{ Cross test: the XRechnung golden files exist for the same invoice in UBL
  and CII. Each UBL file is read and written as CII and compared with the
  CII file of the same scenario, and the other way round. XRechnung CII
  carries one preceding invoice (BG-3): a scenario with more, reported as
  left out on the way to CII, cannot come back complete. }
procedure TestCrossSyntax;
var
  Dir, Base, Root, Diff: string;
  SR: TSearchRec;
  Invoice: TLandrixInvoice;
  D: TLandrixEInvoiceDiagnostics;
  UBLSpec, CIISpec: TLandrixEInvoiceSpec;
  Pairs, Failed: Integer;
  PrecedingLost: Boolean;
begin
  Dir := LocalDir('golden');
  if not DirectoryExists(Dir) then
  begin
    Skip('no local golden files in ' + Dir);
    Exit;
  end;
  Check(LandrixEInvoiceFindSpec(TLandrixEInvoiceTargets.XRechnung('3.0', esy_UBL), UBLSpec), 'UBL spec');
  Check(LandrixEInvoiceFindSpec(TLandrixEInvoiceTargets.XRechnung('3.0', esy_CII), CIISpec), 'CII spec');
  Pairs := 0;
  Failed := 0;
  if FindFirst(Dir + '*-ubl-30x.xml', faAnyFile, SR) = 0 then
  try
    repeat
      Base := Copy(SR.Name, 1, Length(SR.Name) - Length('-ubl-30x.xml'));
      if not FileExists(Dir + Base + '-cii-30x.xml') then
        Continue;
      Inc(Pairs);
      D := TLandrixEInvoiceDiagnostics.Create;
      Invoice := TLandrixInvoice.Create;
      try
        ReadAndMap(LoadFile(Dir + SR.Name), Invoice, D, Root);
        if not XmlEquivalent(LoadFile(Dir + Base + '-cii-30x.xml'), InvoiceToCIIXml(Invoice, CIISpec, D), Diff) then
        begin
          Inc(Failed);
          WriteLn('  ', Base, ' UBL -> CII: ', Diff);
        end;
        PrecedingLost := CountKind(D, edk_NotAllowed, '/ram:InvoiceReferencedDocument') > 0;
        CIIToInvoice(LoadFile(Dir + Base + '-cii-30x.xml'), Invoice, D);
        if not XmlEquivalent(LoadFile(Dir + SR.Name), MapAndWrite(Invoice, UBLSpec, D), Diff) and
           not (PrecedingLost and (Pos('BillingReference', Diff) > 0)) then
        begin
          Inc(Failed);
          WriteLn('  ', Base, ' CII -> UBL: ', Diff);
        end;
      finally
        Invoice.Free;
        D.Free;
      end;
    until FindNext(SR) <> 0;
  finally
    FindClose(SR);
  end;
  CheckEquals(21, Pairs, 'XRechnung scenarios in UBL and CII');
  CheckEquals(0, Failed, IntToStr(Pairs * 2) + ' cross conversions, differences');
end;

const
  Ns =
    'xmlns="urn:oasis:names:specification:ubl:schema:xsd:Invoice-2" ' +
    'xmlns:cac="urn:oasis:names:specification:ubl:schema:xsd:CommonAggregateComponents-2" ' +
    'xmlns:cbc="urn:oasis:names:specification:ubl:schema:xsd:CommonBasicComponents-2"';

  { an invoice with content the invoice model cannot hold, an unknown unit,
    an invalid amount and an unknown type code }
  Unusual =
    '<Invoice ' + Ns + '>' +
    '<cbc:UBLVersionID>2.1</cbc:UBLVersionID>' +
    '<cbc:CustomizationID>urn:cen.eu:en16931:2017#compliant#urn:fdc:peppol.eu:2017:poacc:billing:3.0</cbc:CustomizationID>' +
    '<cbc:ID>R-1</cbc:ID><cbc:IssueDate>2026-10-18</cbc:IssueDate><cbc:InvoiceTypeCode>999</cbc:InvoiceTypeCode>' +
    '<cbc:Note>#Q1Q#odd subject</cbc:Note>' +
    '<cbc:DocumentCurrencyCode>EUR</cbc:DocumentCurrencyCode>' +
    '<cac:OrderReference><cbc:ID>NA</cbc:ID><cbc:SalesOrderID>SO-1</cbc:SalesOrderID></cac:OrderReference>' +
    '<cac:AccountingSupplierParty><cac:Party>' +
    '<cac:PartyIdentification><cbc:ID schemeID="SEPA">DE98ZZZ09999999999</cbc:ID></cac:PartyIdentification>' +
    '<cac:PostalAddress><cac:Country><cbc:IdentificationCode>DE</cbc:IdentificationCode></cac:Country></cac:PostalAddress>' +
    '<cac:PartyLegalEntity><cbc:RegistrationName>S</cbc:RegistrationName></cac:PartyLegalEntity>' +
    '</cac:Party></cac:AccountingSupplierParty>' +
    '<cac:AccountingCustomerParty><cac:Party>' +
    '<cac:PostalAddress><cac:Country><cbc:IdentificationCode>DE</cbc:IdentificationCode></cac:Country></cac:PostalAddress>' +
    '<cac:PartyLegalEntity><cbc:RegistrationName>B</cbc:RegistrationName>' +
    '<cbc:CompanyLegalForm>GmbH</cbc:CompanyLegalForm></cac:PartyLegalEntity>' +
    '</cac:Party></cac:AccountingCustomerParty>' +
    '<cac:PayeeParty><cac:PartyName><cbc:Name>Payee</cbc:Name></cac:PartyName></cac:PayeeParty>' +
    '<cac:TaxTotal><cbc:TaxAmount currencyID="EUR">0.00</cbc:TaxAmount></cac:TaxTotal>' +
    '<cac:LegalMonetaryTotal><cbc:PayableAmount currencyID="EUR">10.00</cbc:PayableAmount></cac:LegalMonetaryTotal>' +
    '<cac:InvoiceLine><cbc:ID>1</cbc:ID>' +
    '<cbc:InvoicedQuantity unitCode="QQQ">1</cbc:InvoicedQuantity>' +
    '<cbc:LineExtensionAmount currencyID="EUR">1,00</cbc:LineExtensionAmount>' +
    '<cac:Item><cbc:Name>Item</cbc:Name><cac:SellersItemIdentification><cbc:ID schemeID="X">A1</cbc:ID>' +
    '</cac:SellersItemIdentification><cac:StandardItemIdentification><cbc:ID schemeID="0088">4000001000005</cbc:ID>' +
    '</cac:StandardItemIdentification></cac:Item>' +
    '<cac:Price><cbc:PriceAmount currencyID="EUR">10</cbc:PriceAmount></cac:Price>' +
    '</cac:InvoiceLine></Invoice>';

function ReadUBLInvoice(const AXml: TLandrixXmlUtf8; ADiagnostics: TLandrixEInvoiceDiagnostics): TLandrixUBLInvoice;
var
  R: TLandrixXmlReader;
begin
  R := TLandrixXmlReader.Create;
  try
    R.LoadFromUtf8(AXml);
    Result := LandrixEInvoiceReadUBLInvoice(R, ADiagnostics);
  finally
    R.Free;
  end;
end;

procedure TestReadReports;
var
  UBL: TLandrixUBLInvoice;
  Invoice: TLandrixInvoice;
  D: TLandrixEInvoiceDiagnostics;
begin
  D := TLandrixEInvoiceDiagnostics.Create;
  Invoice := TLandrixInvoice.Create;
  try
    UBL := ReadUBLInvoice(Unusual, D);
    try
      LandrixEInvoiceUBLInvoiceToInvoice(UBL, Invoice, D);
    finally
      UBL.Free;
    end;
    CheckEquals(1, CountKind(D, edk_NotMapped, '/Invoice/cbc:UBLVersionID'), 'UBL version not mapped');
    CheckEquals(0, CountKind(D, edk_NotMapped, '/Invoice/cac:PayeeParty'), 'payee mapped');
    CheckEqualsInvoiceStr('Payee', Invoice.PayeeParty.Name, 'payee name (BT-59)');
    CheckEquals(1, CountKind(D, edk_NotMapped, '/cac:PartyLegalEntity/cbc:CompanyLegalForm'),
      'legal form of the buyer not mapped');
    CheckEquals(1, CountKind(D, edk_NotMapped, '/cac:SellersItemIdentification/cbc:ID/@schemeID'),
      'identifier scheme not mapped');
    CheckEquals(0, CountKind(D, edk_NotMapped, '/cac:Item/cac:StandardItemIdentification'),
      'standard identifier with any scheme mapped');
    CheckEqualsInvoiceStr('4000001000005', Invoice.InvoiceLines[0].StandardItemIdentifier, 'BT-157');
    CheckEqualsInvoiceStr('0088', Invoice.InvoiceLines[0].StandardItemIdentifierSchemeID, 'BT-157-1');
    CheckEqualsInvoiceStr('', Invoice.InvoiceLines[0].GlobalID_EAN_GTIN, 'no GTIN for scheme 0088');
    CheckEquals(1, CountKind(D, edk_UnknownCode, '/cbc:InvoicedQuantity/@unitCode'), 'unknown unit');
    CheckEquals(1, CountKind(D, edk_UnknownCode, '/cbc:InvoiceTypeCode'), 'unknown type code');
    CheckEquals(1, CountKind(D, edk_UnknownCode, '/cbc:Note'), 'unknown note subject');
    CheckEquals(1, CountKind(D, edk_ConversionFailed, '/cbc:LineExtensionAmount'), 'invalid amount');
    Check(D.HasErrors, 'conversion failure is an error');
    CheckEqualsInvoiceStr('QQQ', Invoice.InvoiceLines[0].UnitCodeOther, 'unit kept in UnitCodeOther');
    CheckEqualsInvoiceStr('999', Invoice.InvoiceTypeCodeOther, 'type code kept');
    CheckEqualsInvoiceStr('Q1Q', Invoice.Notes[0].SubjectCodeOther, 'note subject kept');
    CheckEqualsInvoiceStr('odd subject', Invoice.Notes[0].Content, 'note without subject prefix');
    CheckEqualsInvoiceStr('', Invoice.PurchaseOrderReference, 'NA is no purchase order');
    CheckEqualsInvoiceStr('SO-1', Invoice.SellerOrderReference, 'sales order');
    CheckEqualsInvoiceStr('DE98ZZZ09999999999', Invoice.AccountingSupplierParty.BankAssignedCreditorIdentifier,
      'creditor identifier');
    CheckEqualsInvoiceStr('', Invoice.TaxCurrencyCode, 'no BT-6 from a tax total in the invoice currency');
    Check(Invoice.InvoiceLines[0].LineAmount = 0, 'invalid amount gives 0');
    CheckEqualsInvoiceStr('A1', Invoice.InvoiceLines[0].SellersItemIdentification, 'value taken');
  finally
    Invoice.Free;
    D.Free;
  end;
end;

{ A minimal invoice for the write tests. }
procedure FillInvoice(Invoice: TLandrixInvoice);
var
  Line: TLandrixInvoiceLine;
begin
  Invoice.InvoiceNumber := 'R-1';
  Invoice.InvoiceIssueDate := EncodeDate(2026, 10, 18);
  Invoice.InvoiceCurrencyCode := 'EUR';
  Invoice.TaxCurrencyCode := 'EUR';
  Line := Invoice.InvoiceLines.AddInvoiceLine;
  Line.ID := '1';
  Line.UnitCode := iuc_piece;
  Line.Quantity := 1;
  Line.TaxCategory := idtfcc_S_StandardRate;
  Line.TaxPercent := 19;
end;

procedure TestWriteRules;
var
  Invoice: TLandrixInvoice;
  D: TLandrixEInvoiceDiagnostics;
  Spec: TLandrixEInvoiceSpec;
  Xml: string;
begin
  D := TLandrixEInvoiceDiagnostics.Create;
  Invoice := TLandrixInvoice.Create;
  try
    FillInvoice(Invoice);
    Invoice.InvoiceLines[0].OrderNumber := 'B-7';
    Invoice.InvoiceLines[0].SubInvoiceLines.AddInvoiceLine.ID := '1.1';
    Invoice.AccountingCustomerParty.IdentifierSellerBuyer := '20003';
    Invoice.AccountingCustomerParty.GlobalIdentifierSellerBuyer := '4260000000004';
    Invoice.PaymentID := 'RF18';
    Check(LandrixEInvoiceFindSpec(TLandrixEInvoiceTargets.XRechnung('3.0', esy_UBL), Spec), 'spec');
    Xml := LandrixXmlUtf8ToString(MapAndWrite(Invoice, Spec, D));
    CheckEquals(1, CountKind(D, edk_NotAllowed, '/cac:InvoiceLine/cac:OrderLineReference'), 'line order number');
    CheckEquals(1, CountKind(D, edk_NotAllowed, '/cac:AccountingCustomerParty/cac:Party/cac:PartyIdentification'),
      'one buyer identifier (UBL-SR-16)');
    CheckEquals(1, CountKind(D, edk_NotAllowed, '/cac:PaymentMeans/cbc:PaymentID'), 'remittance without means');
    Check(Pos('B-7', Xml) = 0, 'line order number left out');
    Check(Pos('<cac:SubInvoiceLine>', Xml) > 0, 'sub line written');
    Check(Pos('#conformant#urn:xeinkauf.de:kosit:extension:xrechnung_3.0', Xml) > 0,
      'sub lines declare the extension');
    Check(Pos('>20003<', Xml) = 0, 'buyer identifier left out');
    D.Clear;
    Invoice.InvoiceLines[0].SubInvoiceLines.Clear;
    Xml := LandrixXmlUtf8ToString(MapAndWrite(Invoice, Spec, D));
    Check(Pos('#conformant#', Xml) = 0, 'no extension without extension content');
    D.Clear;
    Check(LandrixEInvoiceFindSpec(TLandrixEInvoiceTargets.PeppolBIS('3.0'), Spec), 'spec');
    Invoice.InvoiceLines[0].SubInvoiceLines.AddInvoiceLine.ID := '1.1';
    Xml := LandrixXmlUtf8ToString(MapAndWrite(Invoice, Spec, D));
    CheckEquals(1, CountKind(D, edk_NotAllowed, '/cac:InvoiceLine/cac:SubInvoiceLine'), 'sub lines discouraged');
    Check(Pos('<cac:SubInvoiceLine>', Xml) > 0, 'discouraged sub line written');
  finally
    Invoice.Free;
    D.Free;
  end;
end;

{ A credit note becomes ubl:CreditNote: no due date, no sub lines, no
  extension, the project reference as additional document reference. }
procedure TestCreditNote;
var
  Invoice, Back: TLandrixInvoice;
  D: TLandrixEInvoiceDiagnostics;
  Spec: TLandrixEInvoiceSpec;
  Xml: TLandrixXmlUtf8;
  Root: string;
begin
  D := TLandrixEInvoiceDiagnostics.Create;
  Invoice := TLandrixInvoice.Create;
  Back := TLandrixInvoice.Create;
  try
    FillInvoice(Invoice);
    Invoice.InvoiceTypeCode := itc_CreditNote;
    Invoice.InvoiceDueDate := EncodeDate(2026, 11, 18);
    Invoice.ProjectReference := 'P-1';
    Invoice.InvoiceLines[0].SubInvoiceLines.AddInvoiceLine.ID := '1.1';
    Check(LandrixEInvoiceFindSpec(TLandrixEInvoiceTargets.XRechnung('3.0', esy_UBL), Spec), 'spec');
    Check(LandrixEInvoiceUBLRootFor(Invoice, Spec) = eur_CreditNote, 'root');
    Xml := MapAndWrite(Invoice, Spec, D);
    Check(Pos('<CreditNote ', LandrixXmlUtf8ToString(Xml)) > 0, 'credit note root');
    Check(Pos('DueDate', LandrixXmlUtf8ToString(Xml)) = 0, 'no due date');
    Check(Pos('SubCreditNoteLine', LandrixXmlUtf8ToString(Xml)) = 0, 'no sub lines');
    Check(Pos('#conformant#', LandrixXmlUtf8ToString(Xml)) = 0, 'no extension');
    CheckEquals(1, CountKind(D, edk_NotAllowed, '/CreditNote'), 'due date reported');
    CheckEquals(1, CountKind(D, edk_NotAllowed, '/CreditNote/cac:CreditNoteLine'), 'sub lines reported');
    D.Clear;
    ReadAndMap(Xml, Back, D, Root);
    CheckEqualsStr('CreditNote', Root, 'read root');
    CheckEqualsInvoiceStr('P-1', Back.ProjectReference, 'project reference read back');
    Check(Back.InvoiceTypeCode = itc_CreditNote, 'type read back');
    Check(Back.Attachments.Count = 0, 'project reference is no attachment');
    CheckEquals(0, D.CountOf(edk_NotMapped), 'nothing lost: ' + string(D.ToText));
  finally
    Back.Free;
    Invoice.Free;
    D.Free;
  end;
end;

{ Third-party payments (BG-DEX-09) keep their currency, a base quantity
  without unit survives, a VAT accounting currency without BT-111 is an
  error; a third-party payment without type takes its description, one
  without both is an error. }
procedure TestRoundTripDetails;
var
  Invoice, Back: TLandrixInvoice;
  D: TLandrixEInvoiceDiagnostics;
  Spec: TLandrixEInvoiceSpec;
  Xml: TLandrixXmlUtf8;
  Root: string;
begin
  D := TLandrixEInvoiceDiagnostics.Create;
  Invoice := TLandrixInvoice.Create;
  Back := TLandrixInvoice.Create;
  try
    FillInvoice(Invoice);
    with Invoice.PrepaidPayments.AddPrepaidPayment do
    begin
      ID := 'PP-1';
      PaidAmount := 12.5;
      PaidAmountCurrencyID := 'USD';
      InstructionID := 'I-1';
    end;
    Invoice.InvoiceLines[0].BaseQuantity := 10;
    Check(LandrixEInvoiceFindSpec(TLandrixEInvoiceTargets.XRechnung('3.0', esy_UBL), Spec), 'spec');
    Xml := MapAndWrite(Invoice, Spec, D);
    Check(Pos('<cac:PrepaidPayment>', LandrixXmlUtf8ToString(Xml)) > 0, 'third-party payment written');
    Check(Pos('#conformant#', LandrixXmlUtf8ToString(Xml)) > 0, 'third-party payments declare the extension');
    Check(not D.HasErrors, 'no errors: ' + string(D.ToText));
    ReadAndMap(Xml, Back, D, Root);
    Check(Back.PrepaidPayments.Count = 1, 'third-party payment read back');
    CheckEqualsInvoiceStr('USD', Back.PrepaidPayments[0].PaidAmountCurrencyID, 'own currency');
    Check(Back.PrepaidPayments[0].PaidAmount = 12.5, 'paid amount');
    CheckEqualsInvoiceStr('I-1', Back.PrepaidPayments[0].InstructionID, 'instruction');
    Check(Back.InvoiceLines[0].BaseQuantity = 10, 'base quantity without unit');
    CheckEquals(0, D.CountOf(edk_NotMapped), 'nothing lost: ' + string(D.ToText));
    D.Clear;
    Invoice.TaxCurrencyCode := 'SEK';
    Xml := MapAndWrite(Invoice, Spec, D);
    Check(Pos('<cbc:TaxCurrencyCode>SEK', LandrixXmlUtf8ToString(Xml)) > 0, 'BT-6 written');
    Check(Pos('currencyID="SEK"', LandrixXmlUtf8ToString(Xml)) = 0, 'BT-110 in the invoice currency');
    CheckEquals(1, CountKind(D, edk_MissingElement, '/Invoice/cac:TaxTotal'), 'BT-111 missing');
    D.Clear;
    Invoice.TaxCurrencyCode := '';
    Invoice.PrepaidPayments[0].ID := '';
    Xml := MapAndWrite(Invoice, Spec, D);
    Check(Pos('<cbc:ID>I-1</cbc:ID>', LandrixXmlUtf8ToString(Xml)) > 0, 'description as type (BR-DEX-10)');
    CheckEquals(1, CountKind(D, edk_MissingElement, '/cac:PrepaidPayment/cbc:ID'), 'missing type reported');
    Check(not D.HasErrors, 'only a warning: ' + string(D.ToText));
    D.Clear;
    Invoice.PrepaidPayments[0].ID := 'PP-1';
    Invoice.PrepaidPayments[0].InstructionID := '';
    Xml := MapAndWrite(Invoice, Spec, D);
    Check(Pos('<cbc:InstructionID>PP-1</cbc:InstructionID>', LandrixXmlUtf8ToString(Xml)) > 0,
      'type as description (BR-DEX-12)');
    CheckEquals(1, CountKind(D, edk_MissingElement, '/cac:PrepaidPayment/cbc:InstructionID'),
      'missing description reported');
    D.Clear;
    Invoice.PrepaidPayments[0].ID := '';
    MapAndWrite(Invoice, Spec, D);
    CheckEquals(1, CountKind(D, edk_MissingElement, '/cac:PrepaidPayment'), 'neither type nor description');
    Check(D.HasErrors, 'an error');
  finally
    Back.Free;
    Invoice.Free;
    D.Free;
  end;
end;

{ BT-110 and BG-23 come from the tax total with the breakdown, even when the
  BT-111 total comes first; the other total is BT-111. }
procedure TestTaxTotalOrder;
const
  Xml =
    '<Invoice ' + Ns + '>' +
    '<cbc:CustomizationID>urn:cen.eu:en16931:2017</cbc:CustomizationID>' +
    '<cbc:DocumentCurrencyCode>EUR</cbc:DocumentCurrencyCode><cbc:TaxCurrencyCode>SEK</cbc:TaxCurrencyCode>' +
    '<cac:TaxTotal><cbc:TaxAmount currencyID="SEK">100.00</cbc:TaxAmount></cac:TaxTotal>' +
    '<cac:TaxTotal><cbc:TaxAmount currencyID="EUR">9.50</cbc:TaxAmount><cac:TaxSubtotal>' +
    '<cbc:TaxableAmount currencyID="EUR">50.00</cbc:TaxableAmount><cbc:TaxAmount currencyID="EUR">9.50</cbc:TaxAmount>' +
    '<cac:TaxCategory><cbc:ID>S</cbc:ID><cbc:Percent>19</cbc:Percent><cac:TaxScheme><cbc:ID>VAT</cbc:ID></cac:TaxScheme>' +
    '</cac:TaxCategory></cac:TaxSubtotal></cac:TaxTotal></Invoice>';
var
  UBL: TLandrixUBLInvoice;
  Invoice: TLandrixInvoice;
  D: TLandrixEInvoiceDiagnostics;
begin
  D := TLandrixEInvoiceDiagnostics.Create;
  Invoice := TLandrixInvoice.Create;
  try
    UBL := ReadUBLInvoice(Xml, D);
    try
      LandrixEInvoiceUBLInvoiceToInvoice(UBL, Invoice, D);
    finally
      UBL.Free;
    end;
    Check(Invoice.TaxAmountTotal = 9.5, 'BT-110 from the total with the breakdown');
    Check(Invoice.TaxAmountSubtotals.Count = 1, 'breakdown read');
    CheckEqualsInvoiceStr('SEK', Invoice.TaxCurrencyCode, 'BT-6');
    CheckEquals(0, CountKind(D, edk_NotMapped, '/Invoice/cac:TaxTotal'), 'BT-111 mapped');
    Check(Invoice.TaxAmountTotalInTaxCurrency.HasValue and (Invoice.TaxAmountTotalInTaxCurrency.Value = 100),
      'BT-111 read');
    CheckEquals(0, CountKind(D, edk_NotMapped, '/@currencyID'), 'no currency report');
  finally
    Invoice.Free;
    D.Free;
  end;
end;

{ XRechnung UBL writes the EN 16931 part of the Phase 2 fields, reads it
  back without loss and reports every Factur-X EXTENDED field. }
procedure TestPhase2Fields;
var
  Invoice, Back: TLandrixInvoice;
  D: TLandrixEInvoiceDiagnostics;
  Spec: TLandrixEInvoiceSpec;
  Xml: TLandrixXmlUtf8;
  Text, Root: string;
begin
  D := TLandrixEInvoiceDiagnostics.Create;
  Invoice := TLandrixInvoice.Create;
  Back := TLandrixInvoice.Create;
  try
    FillPhase2(Invoice);
    Check(LandrixEInvoiceFindSpec(TLandrixEInvoiceTargets.XRechnung('3.0', esy_UBL), Spec), 'spec');
    Xml := MapAndWrite(Invoice, Spec, D);
    Text := LandrixXmlUtf8ToString(Xml);
    CheckEquals(3, CountKind(D, edk_NotAllowed, '/Invoice'), 'BT-X-1, BT-X-2 and the invoicee left out: ' +
      LeftOut(D));
    CheckEquals(1, CountKind(D, edk_NotAllowed, '/cac:OrderReference'), 'order dates left out');
    CheckEquals(2, CountKind(D, edk_NotAllowed, '/cac:InvoiceLine/cac:OrderLineReference'),
      'line order number and date left out');
    CheckEquals(1, CountKind(D, edk_NotAllowed, '/cac:Delivery'), 'deliver to contact left out');
    CheckEquals(1, CountKind(D, edk_NotAllowed, '/cac:PayeeParty'), 'payee address left out');
    CheckEquals(1, CountKind(D, edk_NotAllowed, '/cac:TaxRepresentativeParty'), 'tax representative contact left out');
    CheckEquals(0, CountKind(D, edk_NotAllowed, '/cac:AccountingCustomerParty/cac:Party/cac:Contact'),
      'department without person name is the contact point');
    CheckEquals(1, CountKind(D, edk_NotAllowed, '/cac:PaymentTerms/cbc:Note'), 'text of the discount level left out');
    Check(Pos('<cbc:TaxPointDate>2026-10-01</cbc:TaxPointDate>', Text) > 0, 'BT-7 written');
    Check(Pos('<cbc:ID>LOC-7</cbc:ID>', Text) > 0, 'BT-71 without scheme');
    Check(Pos('<cbc:TaxAmount currencyID="SEK">215.50</cbc:TaxAmount>', Text) > 0, 'BT-111 written');
    Check(Pos('Payee City', Text) = 0, 'no payee address');
    Check(Pos('Invoicee', Text) = 0, 'no invoicee');
    Check(Pos('<cbc:Name>Purchasing</cbc:Name>', Text) > 0, 'department as contact point (BT-56)');
    Check(not D.HasErrors, 'no errors: ' + string(D.ToText));
    D.Clear;
    ReadAndMap(Xml, Back, D, Root);
    CheckEquals(0, D.CountOf(edk_NotMapped), 'nothing lost: ' + string(D.ToText));
    Check(Back.TaxPointDate.HasValue and (Back.TaxPointDate.Value = EncodeDate(2026, 10, 1)), 'BT-7');
    Check(Back.TaxAmountTotalInTaxCurrency.HasValue and (Back.TaxAmountTotalInTaxCurrency.Value = 215.5), 'BT-111');
    CheckEqualsInvoiceStr('0002', Back.AccountingSupplierParty.CompanyIDSchemeID, 'BT-30-1');
    CheckEqualsInvoiceStr('LOC-7', Back.DeliveryInformation.LocationIdentifier, 'BT-71');
    CheckEqualsInvoiceStr('', Back.DeliveryInformation.LocationIdentifierSchemeID, 'BT-71 without scheme');
    CheckEqualsInvoiceStr('Payee', Back.PayeeParty.Name, 'BT-59');
    CheckEqualsInvoiceStr('4000001000005', Back.PayeeParty.Identifier, 'BT-60');
    CheckEqualsInvoiceStr('0088', Back.PayeeParty.IdentifierSchemeID, 'BT-60-1');
    CheckEqualsInvoiceStr('HRB 2', Back.PayeeParty.CompanyID, 'BT-61');
    CheckEqualsInvoiceStr('0002', Back.PayeeParty.CompanyIDSchemeID, 'BT-61-1');
    CheckEqualsInvoiceStr('Representative', Back.TaxRepresentativeParty.Name, 'BT-62');
    CheckEqualsInvoiceStr('DE123456789', Back.TaxRepresentativeParty.VATCompanyID, 'BT-63');
    CheckEqualsInvoiceStr('Rep City', Back.TaxRepresentativeParty.Address.City, 'BG-12');
    CheckEqualsInvoiceStr('AAG', Back.Attachments[0].SchemeID, 'BT-18-1');
    CheckEqualsInvoiceStr('123456789', Back.InvoiceLines[0].StandardItemIdentifier, 'BT-157');
    CheckEqualsInvoiceStr('0088', Back.InvoiceLines[0].StandardItemIdentifierSchemeID, 'BT-157-1');
  finally
    Back.Free;
    Invoice.Free;
    D.Free;
  end;
end;

{ BT-8 alone goes into the invoice period; next to BT-7 it is left out
  (BR-CO-3). A credit note carries BT-7 and BT-111 like an invoice. }
procedure TestTaxPointDate;
var
  Invoice, Back: TLandrixInvoice;
  D: TLandrixEInvoiceDiagnostics;
  Spec: TLandrixEInvoiceSpec;
  Xml: TLandrixXmlUtf8;
  Text, Root: string;
begin
  D := TLandrixEInvoiceDiagnostics.Create;
  Invoice := TLandrixInvoice.Create;
  Back := TLandrixInvoice.Create;
  try
    FillPhase2(Invoice);
    Check(LandrixEInvoiceFindSpec(TLandrixEInvoiceTargets.XRechnung('3.0', esy_UBL), Spec), 'spec');
    Invoice.TaxPointDate.Clear;
    Invoice.TaxPointDateCode := '35';
    Xml := MapAndWrite(Invoice, Spec, D);
    Text := LandrixXmlUtf8ToString(Xml);
    Check(Pos('<cbc:DescriptionCode>35</cbc:DescriptionCode>', Text) > 0, 'BT-8 written');
    Check(Pos('<cbc:TaxPointDate>', Text) = 0, 'no BT-7');
    ReadAndMap(Xml, Back, D, Root);
    CheckEqualsInvoiceStr('35', Back.TaxPointDateCode, 'BT-8 read back');
    D.Clear;
    Invoice.TaxPointDate.SetValue(EncodeDate(2026, 10, 1));
    Text := LandrixXmlUtf8ToString(MapAndWrite(Invoice, Spec, D));
    CheckEquals(1, CountKind(D, edk_NotAllowed, '/cac:InvoicePeriod/cbc:DescriptionCode'),
      'BT-8 next to BT-7 left out (BR-CO-3)');
    Check(Pos('<cbc:DescriptionCode>', Text) = 0, 'no BT-8 next to BT-7');
    Check(Pos('<cbc:TaxPointDate>2026-10-01</cbc:TaxPointDate>', Text) > 0, 'BT-7 written');
    D.Clear;
    Invoice.TaxPointDateCode := '';
    Invoice.InvoiceTypeCode := itc_CreditNote;
    Xml := MapAndWrite(Invoice, Spec, D);
    Text := LandrixXmlUtf8ToString(Xml);
    Check(Pos('<CreditNote', Text) > 0, 'credit note root');
    Check(Pos('<cbc:TaxPointDate>2026-10-01</cbc:TaxPointDate>', Text) > 0, 'BT-7 in the credit note');
    Check(Pos('<cbc:TaxAmount currencyID="SEK">215.50</cbc:TaxAmount>', Text) > 0, 'BT-111 in the credit note');
    Check(not D.HasErrors, 'no errors: ' + string(D.ToText));
    D.Clear;
    Back.Clear;
    ReadAndMap(Xml, Back, D, Root);
    CheckEqualsStr('CreditNote', Root, 'read as credit note');
    Check(Back.TaxPointDate.HasValue and (Back.TaxPointDate.Value = EncodeDate(2026, 10, 1)), 'BT-7 read back');
    Check(Back.TaxAmountTotalInTaxCurrency.HasValue and (Back.TaxAmountTotalInTaxCurrency.Value = 215.5),
      'BT-111 read back');
    CheckEquals(0, D.CountOf(edk_NotMapped), 'nothing lost: ' + string(D.ToText));
  finally
    Back.Free;
    Invoice.Free;
    D.Free;
  end;
end;

{ BT-157: the identifier with scheme wins over the GTIN, a differing GTIN
  is reported; the GTIN alone is written with scheme 0160. }
procedure TestStandardItemIdentifier;
var
  Invoice: TLandrixInvoice;
  Line: TLandrixInvoiceLine;
  D: TLandrixEInvoiceDiagnostics;
  Spec: TLandrixEInvoiceSpec;
  Text: string;
begin
  D := TLandrixEInvoiceDiagnostics.Create;
  Invoice := TLandrixInvoice.Create;
  try
    Line := Invoice.InvoiceLines.AddInvoiceLine;
    Line.ID := '1';
    Line.GlobalID_EAN_GTIN := '4006381333931';
    Check(LandrixEInvoiceFindSpec(TLandrixEInvoiceTargets.PeppolBIS('3.0'), Spec), 'spec');
    Text := LandrixXmlUtf8ToString(MapAndWrite(Invoice, Spec, D));
    Check(Pos('<cbc:ID schemeID="0160">4006381333931</cbc:ID>', Text) > 0, 'GTIN with scheme 0160');
    CheckEquals(0, CountKind(D, edk_NotAllowed, '/cac:StandardItemIdentification'), 'no conflict');
    D.Clear;
    Line.StandardItemIdentifier := '123';
    Line.StandardItemIdentifierSchemeID := '0088';
    Text := LandrixXmlUtf8ToString(MapAndWrite(Invoice, Spec, D));
    Check(Pos('<cbc:ID schemeID="0088">123</cbc:ID>', Text) > 0, 'standard identifier wins');
    Check(Pos('4006381333931', Text) = 0, 'GTIN not written');
    CheckEquals(1, CountKind(D, edk_NotAllowed, '/cac:StandardItemIdentification'), 'conflict reported');
    D.Clear;
    Line.StandardItemIdentifierSchemeID := '';
    MapAndWrite(Invoice, Spec, D);
    CheckEquals(1, CountKind(D, edk_MissingElement, '/cac:StandardItemIdentification/cbc:ID/@schemeID'),
      'missing scheme is an error (BR-64)');
  finally
    Invoice.Free;
    D.Free;
  end;
end;

{ BT-90 may sit in the payee (EN 16931 UBL binding, XRechnung example
  direct-debit-bt-90-payee): it goes to the seller, the other identifier is
  BT-60, nothing is lost. }
procedure TestPayeeCreditorIdentifier;
const
  Xml =
    '<Invoice ' + Ns + '>' +
    '<cbc:CustomizationID>urn:cen.eu:en16931:2017</cbc:CustomizationID>' +
    '<cbc:DocumentCurrencyCode>EUR</cbc:DocumentCurrencyCode>' +
    '<cac:PayeeParty>' +
    '<cac:PartyIdentification><cbc:ID schemeID="SEPA">DE98ZZZ09999999999</cbc:ID></cac:PartyIdentification>' +
    '<cac:PartyIdentification><cbc:ID>601234567</cbc:ID></cac:PartyIdentification>' +
    '<cac:PartyName><cbc:Name>Payee</cbc:Name></cac:PartyName></cac:PayeeParty>' +
    '</Invoice>';
var
  UBL: TLandrixUBLInvoice;
  Invoice: TLandrixInvoice;
  D: TLandrixEInvoiceDiagnostics;
begin
  D := TLandrixEInvoiceDiagnostics.Create;
  Invoice := TLandrixInvoice.Create;
  try
    UBL := ReadUBLInvoice(Xml, D);
    try
      LandrixEInvoiceUBLInvoiceToInvoice(UBL, Invoice, D);
    finally
      UBL.Free;
    end;
    CheckEqualsInvoiceStr('DE98ZZZ09999999999', Invoice.AccountingSupplierParty.BankAssignedCreditorIdentifier,
      'BT-90 from the payee');
    CheckEqualsInvoiceStr('601234567', Invoice.PayeeParty.Identifier, 'BT-60');
    CheckEqualsInvoiceStr('', Invoice.PayeeParty.IdentifierSchemeID, 'BT-60 without scheme');
    CheckEquals(0, D.CountOf(edk_NotMapped), 'nothing lost: ' + string(D.ToText));
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
    Check(LandrixEInvoiceFindSpec(TLandrixEInvoiceTargets.FacturX('1.09', epr_EN16931), Spec), 'spec');
    try
      LandrixEInvoiceInvoiceToUBLInvoice(Invoice, Spec, nil).Free;
      FailNotRaised('ELandrixEInvoiceError for a CII specification');
    except
      on ELandrixEInvoiceError do ;
    end;
    try
      LandrixEInvoiceInvoiceToUBLCreditNote(Invoice, Spec, nil).Free;
      FailNotRaised('ELandrixEInvoiceError for a CII specification');
    except
      on ELandrixEInvoiceError do ;
    end;
    try
      LandrixEInvoiceUBLRootFor(Invoice, Spec);
      FailNotRaised('ELandrixEInvoiceError for a CII specification');
    except
      on ELandrixEInvoiceError do ;
    end;
  finally
    Invoice.Free;
  end;
end;

procedure Register;
begin
  RegisterTest('MapUBL.GoldenWrite', TestGoldenWrite);
  RegisterTest('MapUBL.GoldenRead', TestGoldenRead);
  RegisterTest('MapUBL.LocalFiles', TestLocalFiles);
  RegisterTest('MapUBL.CrossSyntax', TestCrossSyntax);
  RegisterTest('MapUBL.ReadReports', TestReadReports);
  RegisterTest('MapUBL.WriteRules', TestWriteRules);
  RegisterTest('MapUBL.CreditNote', TestCreditNote);
  RegisterTest('MapUBL.RoundTripDetails', TestRoundTripDetails);
  RegisterTest('MapUBL.TaxTotalOrder', TestTaxTotalOrder);
  RegisterTest('MapUBL.Phase2Fields', TestPhase2Fields);
  RegisterTest('MapUBL.StandardItemIdentifier', TestStandardItemIdentifier);
  RegisterTest('MapUBL.TaxPointDate', TestTaxPointDate);
  RegisterTest('MapUBL.PayeeCreditorIdentifier', TestPayeeCreditorIdentifier);
  RegisterTest('MapUBL.WrongSpec', TestWrongSpec);
end;

end.
