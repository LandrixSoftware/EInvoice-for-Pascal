{
  EInvoice-for-Pascal

  Copyright (C) 2026 Landrix Software GmbH & Co. KG

  This file is dual-licensed under:
  - GNU GPL version 3 or later; or
  - the Landrix Software Commercial License.

  See LICENSE and COMMERCIAL-LICENSE.md.

  SPDX-License-Identifier: GPL-3.0-or-later OR LicenseRef-Landrix-Commercial
}

{ Tests for LandrixEInvoiceCompatXRechnungAdapter (TXRechnungInvoiceAdapter):
  - every scenario of LandrixEInvoiceTestScenarios saved through the facade
    equals its golden file (tests/data/local/golden/, git-ignored);
  - every golden file is detected as its version, loaded and saved again
    unchanged;
  - ConsistencyCheck codes, due date correction, load errors, XML text and
    stream behaviour;
  - the PDF entries and the old names of intf.XRechnungPdfExtract;
  - cross test between compilers: Cross.Write saves every scenario to
    <program folder>/cross/, Cross.Read (only with -cross=<folder>) loads the
    files another compiler wrote and saves them again byte for byte
    (tools/build.ps1 runs it in a ring over the toolchains). }

unit LandrixEInvoiceTestCompatAdapter;

{$I LandrixEInvoice.inc}

interface

procedure Register;

implementation

uses
  SysUtils,
  Classes,
  LandrixXmlBase,
  LandrixEInvoiceTypes,
  LandrixEInvoiceDiagnostics,
  LandrixEInvoiceCodes,
  LandrixEInvoiceInvoice,
  LandrixEInvoiceSpecs,
  LandrixEInvoiceCompatXRechnungAdapter,
  LandrixEInvoiceCompatXRechnungPdf,
  LandrixEInvoiceTestFramework,
  LandrixEInvoiceTestPdf,
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

function SaveToBytes(AInvoice: TLandrixInvoice; AVersion: TXRechnungVersion;
  ADiagnostics: TLandrixEInvoiceDiagnostics): TLandrixXmlUtf8;
var
  M: TMemoryStream;
begin
  M := TMemoryStream.Create;
  try
    TXRechnungInvoiceAdapter.SaveToStream(AInvoice, AVersion, M, ADiagnostics);
    Result := '';
    SetLength(Result, Integer(M.Size));
    M.Position := 0;
    if M.Size > 0 then
      M.ReadBuffer(PAnsiChar(Result)^, Integer(M.Size));
  finally
    M.Free;
  end;
end;

{ The bytes of a TXRechnungString as the facade sees them. }
function TextBytes(const S: TXRechnungString): TLandrixXmlUtf8;
begin
  {$IFDEF FPC}
  Result := LandrixEInvoiceStringToUtf8(S);
  {$ELSE}
  {$IFDEF LANDRIXEINVOICE_UNICODE}
  Result := LandrixEInvoiceStringToUtf8(S);
  {$ELSE}
  Result := S;
  {$ENDIF}
  {$ENDIF}
end;

function VersionOfTarget(const ATarget: TLandrixEInvoiceTarget): TXRechnungVersion;
begin
  Result := XRechnungVersion_Unknown;
  case ATarget.Standard of
    est_XRechnung:
      if ATarget.Syntax = esy_UBL then
        Result := XRechnungVersion_30x_UBL
      else
        Result := XRechnungVersion_30x_UNCEFACT;
    est_FacturX:
      if ATarget.Profile = epr_Extended then
        Result := ZUGFeRDExtendedVersion_250
      else
        Result := ZUGFeRDEN16931Version_250;
    est_PeppolBIS:
      Result := PeppolBillingVersion_30;
  else
    ;
  end;
end;

function VersionOfFileName(const AName: string): TXRechnungVersion;
begin
  if Pos('-ubl-30x', AName) > 0 then
    Result := XRechnungVersion_30x_UBL
  else if Pos('-ubl-peppol', AName) > 0 then
    Result := PeppolBillingVersion_30
  else if Pos('-cii-30x', AName) > 0 then
    Result := XRechnungVersion_30x_UNCEFACT
  else if Pos('-ciiEN16931-25', AName) > 0 then
    Result := ZUGFeRDEN16931Version_250
  else if Pos('-ciiextended-25', AName) > 0 then
    Result := ZUGFeRDExtendedVersion_250
  else
    Result := XRechnungVersion_Unknown;
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
  Diff: string;
  Xml: TXRechnungString;
begin
  State := PGoldenState(AData);
  Inc(State^.Files);
  if not XmlEquivalent(LoadFile(State^.Dir + AFileName), SaveToBytes(AInvoice, VersionOfTarget(ATarget), nil),
    Diff) then
  begin
    Inc(State^.Failed);
    WriteLn('  ', AFileName, ' (SaveToStream): ', Diff);
    Exit;
  end;
  TXRechnungInvoiceAdapter.SaveToXMLStr(AInvoice, VersionOfTarget(ATarget), Xml);
  if not XmlEquivalent(LoadFile(State^.Dir + AFileName), TextBytes(Xml), Diff) then
  begin
    Inc(State^.Failed);
    WriteLn('  ', AFileName, ' (SaveToXMLStr): ', Diff);
  end;
end;

procedure TestGoldenSave;
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
  CheckEquals(111, State.Files, 'outputs');
  CheckEquals(0, State.Failed, IntToStr(State.Files) + ' outputs, differences to the golden files');
end;

{ Each golden file: detected version, LoadFromFile, SaveToFile, same XML. }
procedure TestGoldenLoad;
var
  Dir, OutDir: string;
  SR: TSearchRec;
  Invoice: TLandrixInvoice;
  Version: TXRechnungVersion;
  Error: TXRechnungString;
  Diff: string;
  Files, Failed: Integer;
begin
  Dir := LocalDir('golden');
  if not DirectoryExists(Dir) then
  begin
    Skip('no local golden files in ' + Dir);
    Exit;
  end;
  OutDir := LocalDir('out');
  ForceDirectories(OutDir);
  Files := 0;
  Failed := 0;
  if FindFirst(Dir + '*.xml', faAnyFile, SR) = 0 then
  try
    repeat
      Inc(Files);
      Version := TXRechnungValidationHelper.GetXRechnungVersion(TXRechnungString(Dir + SR.Name));
      if Version <> VersionOfFileName(SR.Name) then
      begin
        Inc(Failed);
        WriteLn('  ', SR.Name, ': detected version ', Ord(Version));
        Continue;
      end;
      Invoice := TLandrixInvoice.Create;
      try
        if not TXRechnungInvoiceAdapter.LoadFromFile(Invoice, TXRechnungString(Dir + SR.Name), Error) then
        begin
          Inc(Failed);
          WriteLn('  ', SR.Name, ': ', string(Error));
          Continue;
        end;
        TXRechnungInvoiceAdapter.SaveToFile(Invoice, Version, TXRechnungString(OutDir + SR.Name));
        if not XmlEquivalent(LoadFile(Dir + SR.Name), LoadFile(OutDir + SR.Name), Diff) then
        begin
          Inc(Failed);
          WriteLn('  ', SR.Name, ': ', Diff);
        end;
      finally
        Invoice.Free;
      end;
    until FindNext(SR) <> 0;
  finally
    FindClose(SR);
  end;
  CheckEquals(111, Files, 'golden files');
  CheckEquals(0, Failed, IntToStr(Files) + ' golden files, failed load and save');
end;

{ An invoice that passes every check for XRechnung UBL. }
procedure FillValid(Invoice: TLandrixInvoice);
var
  Line: TLandrixInvoiceLine;
begin
  Invoice.InvoiceNumber := 'R-1';
  Invoice.InvoiceIssueDate := EncodeDate(2026, 10, 19);
  Invoice.InvoiceTypeCode := itc_CommercialInvoice;
  Invoice.InvoiceCurrencyCode := 'EUR';
  Invoice.AccountingSupplierParty.VATCompanyID := 'DE123456789';
  Invoice.PaymentTypes.AddPaymentType.PaymentMeansCode := ipmc_SEPACreditTransfer;
  Line := Invoice.InvoiceLines.AddInvoiceLine;
  Line.ID := '1';
end;

function CodeOf(Invoice: TLandrixInvoice; AVersion: TXRechnungVersion): Integer;
begin
  TXRechnungInvoiceAdapter.ConsistencyCheck(Invoice, AVersion, Result);
end;

procedure TestConsistencyCheck;
var
  Invoice: TLandrixInvoice;
  Line: TLandrixInvoiceLine;
begin
  Invoice := TLandrixInvoice.Create;
  try
    FillValid(Invoice);
    Check(TXRechnungInvoiceAdapter.ConsistencyCheck(Invoice, XRechnungVersion_30x_UBL), 'valid invoice');
    CheckEquals(ccOK, CodeOf(Invoice, PeppolBillingVersion_30), 'valid for Peppol');

    Invoice.PaymentTypes.Clear;
    CheckEquals(ccNoPaymentsCount, CodeOf(Invoice, XRechnungVersion_30x_UBL), 'no payment');
    CheckEquals(ccOK, CodeOf(Invoice, ZUGFeRDEN16931Version_250), 'no payment needed for EN16931');
    Invoice.PaymentTypes.AddPaymentType.PaymentMeansCode := ipmc_SEPACreditTransfer;

    Invoice.InvoiceTypeCode := itc_DebitNote;
    CheckEquals(ccInvoiceTypeNotSupported, CodeOf(Invoice, XRechnungVersion_30x_UNCEFACT), 'debit note XRechnung');
    CheckEquals(ccOK, CodeOf(Invoice, PeppolBillingVersion_30), 'debit note Peppol');
    Invoice.InvoiceTypeCode := itc_CommercialInvoice;

    Invoice.PrecedingInvoiceReferences.AddPrecedingInvoiceReference.ID := 'A';
    Invoice.PrecedingInvoiceReferences.AddPrecedingInvoiceReference.ID := 'B';
    CheckEquals(ccTooManyPrecedingInvoices, CodeOf(Invoice, XRechnungVersion_30x_UNCEFACT), 'two preceding CII');
    CheckEquals(ccOK, CodeOf(Invoice, XRechnungVersion_30x_UBL), 'two preceding UBL');
    Invoice.PrecedingInvoiceReferences.Clear;

    Invoice.PaymentTypes.AddPaymentType.PaymentMeansCode := ipmc_SEPADirectDebit;
    Invoice.PaymentTypes.AddPaymentType.PaymentMeansCode := ipmc_SEPADirectDebit;
    CheckEquals(ccTooManySEPADirectDebit, CodeOf(Invoice, XRechnungVersion_30x_UBL), 'two direct debits');
    Invoice.PaymentTypes.Clear;
    Invoice.PaymentTypes.AddPaymentType.PaymentMeansCode := ipmc_CreditCard;
    Invoice.PaymentTypes.AddPaymentType.PaymentMeansCode := ipmc_CreditCard;
    CheckEquals(ccTooManyCreditCard, CodeOf(Invoice, XRechnungVersion_30x_UBL), 'two credit cards');
    Invoice.PaymentTypes.Clear;
    Invoice.PaymentTypes.AddPaymentType.PaymentMeansCode := ipmc_SEPACreditTransfer;

    Invoice.AccountingSupplierParty.VATCompanyID := '';
    CheckEquals(ccNoBT31BT30, CodeOf(Invoice, XRechnungVersion_30x_UBL), 'no BT-31 and BT-30');
    Invoice.AccountingSupplierParty.CompanyID := 'HRB 1';
    CheckEquals(ccNoBT31BT32, CodeOf(Invoice, XRechnungVersion_30x_UBL), 'no BT-31 and BT-32');
    Invoice.AccountingSupplierParty.VATCompanyID := 'DE123456789';

    Invoice.PrepaidPayments.AddPrepaidPayment.ID := 'P';
    CheckEquals(ccOK, CodeOf(Invoice, XRechnungVersion_30x_UBL), 'third-party payment XRechnung UBL');
    CheckEquals(ccPrepaidPaymentNotSupported, CodeOf(Invoice, PeppolBillingVersion_30), 'third-party payment Peppol');
    Invoice.PrepaidPayments.Clear;

    Invoice.AccountingCustomerParty.ElectronicAddressSellerBuyer := 'a@b.de';
    CheckEquals(ccNoEMUnderPeppol, CodeOf(Invoice, PeppolBillingVersion_30), 'no scheme under Peppol');
    CheckEquals(ccOK, CodeOf(Invoice, XRechnungVersion_30x_UBL), 'default EM for XRechnung');
    Invoice.AccountingCustomerParty.ElectronicAddressSellerBuyerSchemeID := 'EM';
    CheckEquals(ccNoEMUnderPeppol, CodeOf(Invoice, PeppolBillingVersion_30), 'EM under Peppol');
    Invoice.AccountingCustomerParty.ElectronicAddressSellerBuyerSchemeID := '0204';
    CheckEquals(ccOK, CodeOf(Invoice, PeppolBillingVersion_30), 'EAS scheme under Peppol');

    Line := Invoice.InvoiceLines[0];
    Line.DeliveryNoteNumber := 'LS-1';
    CheckEquals(ccLineDeliveryOnlyExtended, CodeOf(Invoice, XRechnungVersion_30x_UBL), 'line delivery UBL');
    CheckEquals(ccOK, CodeOf(Invoice, ZUGFeRDExtendedVersion_250), 'line delivery EXTENDED');
    Line.DeliveryNoteNumber := '';

    Line.SubInvoiceLines.AddInvoiceLine.ID := '1.1';
    CheckEquals(ccSubInvoiceLinesNotSupported, CodeOf(Invoice, XRechnungVersion_30x_UNCEFACT), 'sub lines XRechnung CII');
    CheckEquals(ccSubInvoiceLinesNotSupported, CodeOf(Invoice, ZUGFeRDEN16931Version_250), 'sub lines EN16931');
    CheckEquals(ccOK, CodeOf(Invoice, XRechnungVersion_30x_UBL), 'sub lines XRechnung UBL');
    CheckEquals(ccOK, CodeOf(Invoice, PeppolBillingVersion_30), 'sub lines Peppol (discouraged)');
    Line.LineStatusReasonCode := ilsrc_Detail;
    CheckEquals(ccSubInvoiceLinesNotSupported, CodeOf(Invoice, XRechnungVersion_30x_UBL), 'DETAIL with sub lines UBL');
    Line.LineStatusReasonCode := ilsrc_None;

    Line.LineAmount := 10;
    Line.SubInvoiceLines[0].LineAmount := 9;
    CheckEquals(ccSubInvoiceLineAmountMismatch, CodeOf(Invoice, ZUGFeRDExtendedVersion_250), 'group sum');
    Line.SubInvoiceLines[0].LineAmount := 10;
    CheckEquals(ccOK, CodeOf(Invoice, ZUGFeRDExtendedVersion_250), 'group sum matches');

    { versions that cannot be written: as in XRechnung-for-Delphi }
    Invoice.PrepaidPayments.AddPrepaidPayment.ID := 'P';
    CheckEquals(ccPrepaidPaymentNotSupported, CodeOf(Invoice, XRechnungVersion_Unknown), 'third-party payment Unknown');
    Invoice.PrepaidPayments.Clear;
    Line.DeliveryNoteNumber := 'LS-1';
    CheckEquals(ccLineDeliveryOnlyExtended, CodeOf(Invoice, XRechnungVersion_2x_ReadingOnly), 'line delivery 2.x');
    Line.DeliveryNoteNumber := '';

    { the first failing code wins }
    Invoice.PaymentTypes.Clear;
    Invoice.AccountingSupplierParty.VATCompanyID := '';
    CheckEquals(ccNoPaymentsCount, CodeOf(Invoice, XRechnungVersion_30x_UBL), 'first code');
  finally
    Invoice.Free;
  end;
end;

procedure TestCorrectDueDate;
var
  Invoice: TLandrixInvoice;
begin
  Invoice := TLandrixInvoice.Create;
  try
    Invoice.InvoiceIssueDate := EncodeDate(2026, 10, 1);
    TXRechnungInvoiceAdapter.CorrectDueDateIfNotDefined(Invoice);
    Check(Invoice.InvoiceDueDate = EncodeDate(2026, 10, 31), '30 days');
    Invoice.InvoiceDueDate := 0;
    Invoice.PaymentTermsType := iptt_CashDiscount2;
    Invoice.PaymentTermCashDiscount2Days := 40;
    TXRechnungInvoiceAdapter.CorrectDueDateIfNotDefined(Invoice);
    Check(Invoice.InvoiceDueDate = EncodeDate(2026, 11, 11), 'one day after the longest discount');
    Invoice.InvoiceDueDate := EncodeDate(2027, 1, 1);
    TXRechnungInvoiceAdapter.CorrectDueDateIfNotDefined(Invoice);
    Check(Invoice.InvoiceDueDate = EncodeDate(2027, 1, 1), 'set due date kept');
  finally
    Invoice.Free;
  end;
end;

procedure TestLoadErrors;
var
  Invoice: TLandrixInvoice;
  Error: TXRechnungString;
begin
  Invoice := TLandrixInvoice.Create;
  try
    Check(not TXRechnungInvoiceAdapter.LoadFromXMLStr(Invoice,
      '<Invoice xmlns="urn:oasis:names:specification:ubl:schema:xsd:Invoice-2"><a></b></Invoice>', Error),
      'not well-formed');
    Check(Pos('Not valid XML', string(Error)) > 0, 'error text for not well-formed XML: ' + string(Error));
    Check(not TXRechnungInvoiceAdapter.LoadFromXMLStr(Invoice, '<Order/>', Error), 'unknown root');
    Check(Pos('Unsupported', string(Error)) > 0, 'unsupported format: ' + string(Error));
    Check(not TXRechnungInvoiceAdapter.LoadFromXMLStr(Invoice,
      '<rsm:CrossIndustryDocument xmlns:rsm="urn:x"/>', Error), 'ZUGFeRD 1');
    Check(Pos('ZUGFeRD 1', string(Error)) > 0, 'ZUGFeRD 1 message');
    Check(not TXRechnungInvoiceAdapter.LoadFromXMLStr(Invoice, '<Invoice xmlns="urn:wrong"/>', Error),
      'wrong namespace');
    Check(not TXRechnungInvoiceAdapter.LoadFromFile(Invoice, 'no-such-file.xml', Error), 'missing file');
    Check(Pos('not found', string(Error)) > 0, 'missing file message');
    Check(TXRechnungValidationHelper.GetXRechnungVersionFromString('<Order/>') = XRechnungVersion_Unknown,
      'unknown version');
    Check(TXRechnungValidationHelper.GetXRechnungVersionFromString('<rsm:CrossIndustryDocument xmlns:rsm="urn:x"/>') =
      ZUGFeRDExtendedVersion_1_NotSupported, 'ZUGFeRD 1 detected');
  finally
    Invoice.Free;
  end;
end;

{ Non-ASCII text survives SaveToXMLStr and LoadFromXMLStr on every compiler;
  the stream keeps its position during detection; an unwritable version
  raises; a missing folder writes nothing. }
procedure TestTextAndStream;
var
  Invoice, Back: TLandrixInvoice;
  Xml, Error: TXRechnungString;
  M: TMemoryStream;
  Name: TLandrixEInvoiceString;
  D: TLandrixEInvoiceDiagnostics;
begin
  Invoice := TLandrixInvoice.Create;
  Back := TLandrixInvoice.Create;
  D := TLandrixEInvoiceDiagnostics.Create;
  M := TMemoryStream.Create;
  try
    FillValid(Invoice);
    Name := 'M';
    Name := Name + WideChar($00FC) + 'ller ' + WideChar($20AC);
    Invoice.AccountingCustomerParty.Name := Name;
    Invoice.InvoiceLines[0].OrderNumber := 'B-1'; { left out in UBL: one diagnostic }
    TXRechnungInvoiceAdapter.SaveToXMLStr(Invoice, XRechnungVersion_30x_UBL, Xml, D);
    Check(D.Count > 0, 'diagnostics passed through');
    Check(TXRechnungInvoiceAdapter.LoadFromXMLStr(Back, Xml, Error), 'load text: ' + string(Error));
    CheckEqualsInvoiceStr(Name, Back.AccountingCustomerParty.Name, 'non-ASCII name');
    Check(TXRechnungValidationHelper.GetXRechnungVersionFromString(Xml) = XRechnungVersion_30x_UBL, 'version of text');

    TXRechnungInvoiceAdapter.SaveToStream(Invoice, ZUGFeRDExtendedVersion_250, M);
    M.Position := 5;
    Check(TXRechnungValidationHelper.GetXRechnungVersion(M) = XRechnungVersion_Unknown, 'from position 5');
    CheckEquals(5, Integer(M.Position), 'position kept');
    M.Position := 0;
    Check(TXRechnungValidationHelper.GetXRechnungVersion(M) = ZUGFeRDExtendedVersion_250, 'EXTENDED detected');
    CheckEquals(0, Integer(M.Position), 'position kept at 0');
    Check(TXRechnungInvoiceAdapter.LoadFromStream(Back, M, Error), 'load stream: ' + string(Error));

    try
      TXRechnungInvoiceAdapter.SaveToXMLStr(Invoice, XRechnungVersion_2x_ReadingOnly, Xml);
      FailNotRaised('ELandrixEInvoiceError for a version that cannot be written');
    except
      on ELandrixEInvoiceError do ;
    end;
    TXRechnungInvoiceAdapter.SaveToFile(Invoice, XRechnungVersion_30x_UBL,
      TXRechnungString(LocalDir('no-such-folder') + 'x.xml'));
    Check(not FileExists(LocalDir('no-such-folder') + 'x.xml'), 'missing folder: nothing written');
  finally
    M.Free;
    D.Free;
    Back.Free;
    Invoice.Free;
  end;
end;

function BytesStream(const S: AnsiString): TMemoryStream;
begin
  Result := TMemoryStream.Create;
  if S <> '' then
    Result.WriteBuffer(PAnsiChar(S)^, Length(S));
  Result.Position := 0;
end;

{ An invoice saved through the facade, embedded in a PDF, is read back
  through LoadFromPdfStream/File and through LoadFromStream/File with
  _ProcessPdfFiles, detected by GetXRechnungVersion, and extracted through
  the old names of intf.XRechnungPdfExtract. }
procedure TestPdf;
var
  Invoice, Back: TLandrixInvoice;
  Xml: TLandrixXmlUtf8;
  Pdf: AnsiString;
  M: TMemoryStream;
  Error, Name: TXRechnungString;
  FileName: string;
  F: TFileStream;
  Bytes: TXRechnungPdfBytes;
  Info: TXRechnungPdfExtractInfo;
  List: TXRechnungPdfAttachmentList;
  I: Integer;
begin
  Invoice := TLandrixInvoice.Create;
  Back := TLandrixInvoice.Create;
  try
    FillValid(Invoice);
    Xml := SaveToBytes(Invoice, ZUGFeRDEN16931Version_250, nil);
    Pdf := '';
    SetLength(Pdf, Length(Xml));
    for I := 1 to Length(Xml) do
      Pdf[I] := Xml[I];
    Pdf := BuildInvoicePdf(Pdf);

    M := BytesStream(Pdf);
    try
      Check(TXRechnungInvoiceAdapter.LoadFromPdfStream(Back, M, Error, Name), 'from PDF stream: ' + string(Error));
      Check(Name = 'factur-x.xml', 'attachment name');
      CheckEqualsUtf8(Xml, SaveToBytes(Back, ZUGFeRDEN16931Version_250, nil), 'saved again unchanged');

      M.Position := 0;
      Check(not TXRechnungInvoiceAdapter.LoadFromStream(Back, M, Error), 'PDF without _ProcessPdfFiles');
      M.Position := 0;
      Check(TXRechnungInvoiceAdapter.LoadFromStream(Back, M, Error, True), 'PDF with _ProcessPdfFiles: ' + string(Error));

      M.Position := 0;
      Check(TXRechnungValidationHelper.GetXRechnungVersion(M) = XRechnungVersion_Unknown, 'version without flag');
      Check(TXRechnungValidationHelper.GetXRechnungVersion(M, True) = ZUGFeRDEN16931Version_250, 'version of the PDF');
      CheckEquals(0, Integer(M.Position), 'position kept');

      M.Position := 0;
      Check(TXRechnungPdfExtractor.ExtractInvoiceFromStream(M, Bytes, Name, Info), 'old names: ' + string(Info.Error));
      CheckEquals(Length(Xml), Integer(Length(Bytes)), 'old names: length');
      for I := 0 to Integer(Length(Bytes)) - 1 do
        if Bytes[I] <> Ord(Xml[I + 1]) then
        begin
          Fail('old names: byte ' + IntToStr(I));
          Break;
        end;
      M.Position := 0;
      List := TXRechnungPdfAttachmentList.Create;
      try
        Check(TXRechnungPdfExtractor.ExtractAllFromStream(M, List, Info), 'old names: all');
        Check((List.Count = 1) and (List[0].Kind = pakInvoice), 'old names: kind');
        CheckEquals(0, TXRechnungPdfExtractor.FindInvoiceIndex(List), 'old names: index');
      finally
        List.Free;
      end;
    finally
      M.Free;
    end;

    FileName := ExtractFilePath(ParamStr(0)) + 'compat-pdf-test.pdf';
    F := TFileStream.Create(FileName, fmCreate);
    try
      F.WriteBuffer(PAnsiChar(Pdf)^, Length(Pdf));
    finally
      F.Free;
    end;
    { the file stays in the build folder and is overwritten by the next run }
    begin
      Check(TXRechnungInvoiceAdapter.LoadFromPdfFile(Back, TXRechnungString(FileName), Error, Name),
        'from PDF file: ' + string(Error));
      Check(TXRechnungInvoiceAdapter.LoadFromFile(Back, TXRechnungString(FileName), Error, True),
        'file with _ProcessPdfFiles: ' + string(Error));
      Check(not TXRechnungInvoiceAdapter.LoadFromFile(Back, TXRechnungString(FileName), Error),
        'file without _ProcessPdfFiles');
      Check(TXRechnungValidationHelper.GetXRechnungVersion(TXRechnungString(FileName), True) =
        ZUGFeRDEN16931Version_250, 'version of the PDF file');
      Check(TXRechnungPdfExtractor.IsPdfFile(TXRechnungString(FileName)), 'old names: PDF file');
      Check(TXRechnungPdfExtractor.ExtractInvoiceFromFile(TXRechnungString(FileName), Bytes, Name, Info),
        'old names: from file');
    end;
    Check(not TXRechnungInvoiceAdapter.LoadFromPdfFile(Back, 'no-such-file.pdf', Error, Name), 'missing PDF');
    Check(Pos('not found', string(Error)) > 0, 'missing PDF message');

    M := BytesStream(BuildInvoicePdf('<Order/>'));
    try
      Check(not TXRechnungInvoiceAdapter.LoadFromPdfStream(Back, M, Error, Name), 'PDF without invoice');
      Check(Pos('No embedded invoice', string(Error)) > 0, 'message: ' + string(Error));
    finally
      M.Free;
    end;
    M := BytesStream(BuildInvoicePdf('<rsm:CrossIndustryInvoice xmlns:rsm="urn:wrong"/>'));
    try
      Check(not TXRechnungInvoiceAdapter.LoadFromPdfStream(Back, M, Error, Name), 'unreadable embedded invoice');
      Check(Pos('Embedded file factur-x.xml', string(Error)) > 0, 'message: ' + string(Error));
    finally
      M.Free;
    end;
  finally
    Back.Free;
    Invoice.Free;
  end;
end;

{ --- cross test between compilers --------------------------------------------- }

function CrossOutDir: string;
begin
  Result := ExtractFilePath(ParamStr(0)) + 'cross' + PathDelim;
end;

{ The folder given with -cross=<folder>, '' if none. }
function CrossInDir: string;
var
  I: Integer;
begin
  Result := '';
  for I := 1 to ParamCount do
    if Copy(ParamStr(I), 1, 7) = '-cross=' then
      Result := IncludeTrailingPathDelimiter(Copy(ParamStr(I), 8, MaxInt));
end;

procedure CrossSink(AInvoice: TLandrixInvoice; const ATarget: TLandrixEInvoiceTarget;
  const AFileName: string; AData: Pointer);
begin
  TXRechnungInvoiceAdapter.SaveToFile(AInvoice, VersionOfTarget(ATarget), TXRechnungString(CrossOutDir + AFileName));
  Inc(PInteger(AData)^);
end;

{ Writes every scenario as the toolchain under test produces it. }
procedure TestCrossWrite;
var
  Files: Integer;
begin
  if not DirectoryExists(LocalDir('attachments')) then
  begin
    Skip('no local attachments');
    Exit;
  end;
  { tools/build.ps1 clears the folder before each run }
  Check(ForceDirectories(CrossOutDir), 'cross folder');
  Files := 0;
  RunAllScenarios(CrossSink, @Files, LocalDir('attachments'));
  CheckEquals(111, Files, 'scenario outputs');
end;

{ Reads what another compiler wrote: detected version, LoadFromFile, saved
  again it must give the same bytes. }
procedure TestCrossRead;
var
  Dir: string;
  SR: TSearchRec;
  Invoice: TLandrixInvoice;
  Version: TXRechnungVersion;
  Error: TXRechnungString;
  Files, Failed: Integer;
  Original: TLandrixXmlUtf8;
begin
  Dir := CrossInDir;
  Files := 0;
  Failed := 0;
  if FindFirst(Dir + '*.xml', faAnyFile, SR) = 0 then
    try
      repeat
        Inc(Files);
        Version := VersionOfFileName(SR.Name);
        if TXRechnungValidationHelper.GetXRechnungVersion(TXRechnungString(Dir + SR.Name)) <> Version then
        begin
          Inc(Failed);
          WriteLn('  ', SR.Name, ': version not detected');
          Continue;
        end;
        Invoice := TLandrixInvoice.Create;
        try
          if not TXRechnungInvoiceAdapter.LoadFromFile(Invoice, TXRechnungString(Dir + SR.Name), Error) then
          begin
            Inc(Failed);
            WriteLn('  ', SR.Name, ': ', string(Error));
            Continue;
          end;
          Original := LoadFile(Dir + SR.Name);
          if SaveToBytes(Invoice, Version, nil) <> Original then
          begin
            Inc(Failed);
            WriteLn('  ', SR.Name, ': saved again with different bytes');
          end;
        finally
          Invoice.Free;
        end;
      until FindNext(SR) <> 0;
    finally
      FindClose(SR);
    end;
  CheckEquals(111, Files, 'files in ' + Dir);
  CheckEquals(0, Failed, IntToStr(Files) + ' files of another compiler, failed');
end;

procedure Register;
begin
  RegisterTest('CompatAdapter.GoldenSave', TestGoldenSave);
  RegisterTest('CompatAdapter.GoldenLoad', TestGoldenLoad);
  RegisterTest('CompatAdapter.ConsistencyCheck', TestConsistencyCheck);
  RegisterTest('CompatAdapter.CorrectDueDate', TestCorrectDueDate);
  RegisterTest('CompatAdapter.LoadErrors', TestLoadErrors);
  RegisterTest('CompatAdapter.TextAndStream', TestTextAndStream);
  RegisterTest('CompatAdapter.Pdf', TestPdf);
  RegisterTest('Cross.Write', TestCrossWrite);
  if CrossInDir <> '' then
    RegisterTest('Cross.Read', TestCrossRead);
end;

end.
