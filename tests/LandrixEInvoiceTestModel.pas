{
  EInvoice-for-Pascal

  Copyright (C) 2026 Landrix Software GmbH & Co. KG

  This file is dual-licensed under:
  - GNU GPL version 3 or later; or
  - the Landrix Software Commercial License.

  See LICENSE and COMMERCIAL-LICENSE.md.

  SPDX-License-Identifier: GPL-3.0-or-later OR LicenseRef-Landrix-Commercial
}

{ Tests for LandrixEInvoiceCodes and LandrixEInvoiceInvoice: code lists,
  model classes and lists, unit of measure mapping, attachments. }

unit LandrixEInvoiceTestModel;

{$I LandrixEInvoice.inc}

interface

procedure Register;

implementation

uses
  SysUtils,
  Classes,
  LandrixXmlBase,
  LandrixEInvoiceTypes,
  LandrixEInvoiceCodes,
  LandrixEInvoiceInvoice,
  LandrixEInvoiceTestFramework;

{ --- code lists --------------------------------------------------------- }

{ Every list: the first member has code '', every other member a non-empty
  code that is unique and maps back to the member, also in lower case. }

procedure CheckCodeCommon(const ListName: string; Index: Integer;
  const Code: TLandrixEInvoiceString; Found: Boolean; FoundOrd: Integer);
begin
  if Index = 0 then
  begin
    CheckEquals(0, Length(Code), ListName + ': first member has no code');
    Exit;
  end;
  Check(Length(Code) > 0, ListName + ': member ' + IntToStr(Index) + ' has a code');
  Check(Found, ListName + ': code of member ' + IntToStr(Index) + ' found');
  CheckEquals(Index, FoundOrd, ListName + ': code of member ' + IntToStr(Index) + ' maps back');
end;

function LowerAscii(const S: TLandrixEInvoiceString): TLandrixEInvoiceString;
var
  I: Integer;
begin
  Result := S;
  for I := 1 to Length(Result) do
    if (Result[I] >= 'A') and (Result[I] <= 'Z') then
      Result[I] := WideChar(Ord(Result[I]) + 32);
end;

procedure TestTypeCodes;
var
  V, W: TLandrixInvoiceTypeCode;
  Found: Boolean;
begin
  for V := Low(V) to High(V) do
  begin
    Found := LandrixEInvoiceTypeCodeFromStr(LandrixEInvoiceTypeCodeToStr(V), W);
    CheckCodeCommon('TypeCode', Ord(V), LandrixEInvoiceTypeCodeToStr(V), Found, Ord(W));
  end;
  CheckEqualsInvoiceStr('380', LandrixEInvoiceTypeCodeToStr(itc_CommercialInvoice), '380');
  Check(not LandrixEInvoiceTypeCodeFromStr('999', W), 'unknown code');
  Check(W = itc_None, 'unknown code gives itc_None');
  Check(not LandrixEInvoiceTypeCodeFromStr('', W), 'empty code');
end;

procedure TestPaymentMeansCodes;
var
  V, W: TLandrixInvoicePaymentMeansCode;
  Found: Boolean;
begin
  for V := Low(V) to High(V) do
  begin
    Found := LandrixEInvoicePaymentMeansCodeFromStr(LowerAscii(LandrixEInvoicePaymentMeansCodeToStr(V)), W);
    CheckCodeCommon('PaymentMeansCode', Ord(V), LandrixEInvoicePaymentMeansCodeToStr(V), Found, Ord(W));
  end;
  CheckEqualsInvoiceStr('58', LandrixEInvoicePaymentMeansCodeToStr(ipmc_SEPACreditTransfer), 'SEPA credit transfer');
  CheckEqualsInvoiceStr('ZZZ', LandrixEInvoicePaymentMeansCodeToStr(ipmc_MutuallyDefined), 'mutually defined');
  Check(LandrixEInvoicePaymentMeansCodeFromStr('zzz', W) and (W = ipmc_MutuallyDefined), 'case-insensitive');
end;

procedure TestUnitCodes;
var
  V, W: TLandrixInvoiceUnitCode;
  Found: Boolean;
begin
  for V := Low(V) to High(V) do
  begin
    Found := LandrixEInvoiceUnitCodeFromStr(LowerAscii(LandrixEInvoiceUnitCodeToStr(V)), W);
    CheckCodeCommon('UnitCode', Ord(V), LandrixEInvoiceUnitCodeToStr(V), Found, Ord(W));
  end;
  CheckEqualsInvoiceStr('H87', LandrixEInvoiceUnitCodeToStr(iuc_piece), 'piece');
  CheckEqualsInvoiceStr('H18', LandrixEInvoiceUnitCodeToStr(iuc_hectare), 'hectare');
  Check(LandrixEInvoiceUnitCodeFromStr('har', W) and (W = iuc_hectare), 'HAR read as hectare');
end;

procedure TestOtherCodeLists;
var
  A, A2: TLandrixInvoiceAttachmentType;
  AC, AC2: TLandrixInvoiceAttachmentTypeCode;
  AL, AL2: TLandrixInvoiceAllowanceOrChargeIdentCode;
  CH, CH2: TLandrixInvoiceSpecialServiceDescriptionCode;
  TC, TC2: TLandrixInvoiceDutyTaxFeeCategoryCode;
  NS, NS2: TLandrixInvoiceNoteSubjectCode;
  LS, LS2: TLandrixInvoiceLineStatusReasonCode;
  Found: Boolean;
begin
  for A := Low(A) to High(A) do
  begin
    Found := LandrixEInvoiceAttachmentTypeFromStr(LandrixEInvoiceAttachmentTypeToStr(A), A2);
    CheckCodeCommon('AttachmentType', Ord(A), LandrixEInvoiceAttachmentTypeToStr(A), Found, Ord(A2));
  end;
  for AC := Low(AC) to High(AC) do
  begin
    Found := LandrixEInvoiceAttachmentTypeCodeFromStr(LandrixEInvoiceAttachmentTypeCodeToStr(AC), AC2);
    CheckCodeCommon('AttachmentTypeCode', Ord(AC), LandrixEInvoiceAttachmentTypeCodeToStr(AC), Found, Ord(AC2));
  end;
  for AL := Low(AL) to High(AL) do
  begin
    Found := LandrixEInvoiceAllowanceOrChargeIdentCodeFromStr(LandrixEInvoiceAllowanceOrChargeIdentCodeToStr(AL), AL2);
    CheckCodeCommon('AllowanceOrChargeIdentCode', Ord(AL), LandrixEInvoiceAllowanceOrChargeIdentCodeToStr(AL), Found, Ord(AL2));
  end;
  for CH := Low(CH) to High(CH) do
  begin
    Found := LandrixEInvoiceSpecialServiceDescriptionCodeFromStr(LowerAscii(LandrixEInvoiceSpecialServiceDescriptionCodeToStr(CH)), CH2);
    CheckCodeCommon('SpecialServiceDescriptionCode', Ord(CH), LandrixEInvoiceSpecialServiceDescriptionCodeToStr(CH), Found, Ord(CH2));
  end;
  for TC := Low(TC) to High(TC) do
  begin
    Found := LandrixEInvoiceDutyTaxFeeCategoryCodeFromStr(LowerAscii(LandrixEInvoiceDutyTaxFeeCategoryCodeToStr(TC)), TC2);
    CheckCodeCommon('DutyTaxFeeCategoryCode', Ord(TC), LandrixEInvoiceDutyTaxFeeCategoryCodeToStr(TC), Found, Ord(TC2));
  end;
  for NS := Low(NS) to High(NS) do
  begin
    Found := LandrixEInvoiceNoteSubjectCodeFromStr(LandrixEInvoiceNoteSubjectCodeToStr(NS), NS2);
    CheckCodeCommon('NoteSubjectCode', Ord(NS), LandrixEInvoiceNoteSubjectCodeToStr(NS), Found, Ord(NS2));
  end;
  for LS := Low(LS) to High(LS) do
  begin
    Found := LandrixEInvoiceLineStatusReasonCodeFromStr(LowerAscii(LandrixEInvoiceLineStatusReasonCodeToStr(LS)), LS2);
    CheckCodeCommon('LineStatusReasonCode', Ord(LS), LandrixEInvoiceLineStatusReasonCodeToStr(LS), Found, Ord(LS2));
  end;
  CheckEqualsInvoiceStr('application/pdf', LandrixEInvoiceAttachmentTypeToStr(iat_application_pdf), 'pdf MIME type');
  CheckEqualsInvoiceStr('916', LandrixEInvoiceAttachmentTypeCodeToStr(iatc_916), '916');
  CheckEqualsInvoiceStr('95', LandrixEInvoiceAllowanceOrChargeIdentCodeToStr(iacic_Discount), 'discount');
  CheckEqualsInvoiceStr('S', LandrixEInvoiceDutyTaxFeeCategoryCodeToStr(idtfcc_S_StandardRate), 'standard rate');
  CheckEqualsInvoiceStr('BLP', LandrixEInvoiceNoteSubjectCodeToStr(insc_BLP), 'BLP');
  CheckEqualsInvoiceStr('GROUP', LandrixEInvoiceLineStatusReasonCodeToStr(ilsrc_Group), 'GROUP');
end;

procedure TestNewCodeLists;
var
  CC, CC2: TLandrixInvoiceCountryCode;
  CU, CU2: TLandrixInvoiceCurrencyCode;
  EA, EA2: TLandrixInvoiceElectronicAddressScheme;
  IC, IC2: TLandrixInvoiceIdentifierScheme;
  VX, VX2: TLandrixInvoiceVATExemptionReasonCode;
  RC, RC2: TLandrixInvoiceReferenceCodeQualifier;
  ICS, ICS2: TLandrixInvoiceItemClassificationScheme;
  Found: Boolean;
begin
  for CC := Low(CC) to High(CC) do
  begin
    Found := LandrixEInvoiceCountryCodeFromStr(LowerAscii(LandrixEInvoiceCountryCodeToStr(CC)), CC2);
    CheckCodeCommon('CountryCode', Ord(CC), LandrixEInvoiceCountryCodeToStr(CC), Found, Ord(CC2));
  end;
  for CU := Low(CU) to High(CU) do
  begin
    Found := LandrixEInvoiceCurrencyCodeFromStr(LandrixEInvoiceCurrencyCodeToStr(CU), CU2);
    CheckCodeCommon('CurrencyCode', Ord(CU), LandrixEInvoiceCurrencyCodeToStr(CU), Found, Ord(CU2));
  end;
  for EA := Low(EA) to High(EA) do
  begin
    Found := LandrixEInvoiceElectronicAddressSchemeFromStr(LandrixEInvoiceElectronicAddressSchemeToStr(EA), EA2);
    CheckCodeCommon('ElectronicAddressScheme', Ord(EA), LandrixEInvoiceElectronicAddressSchemeToStr(EA), Found, Ord(EA2));
  end;
  for IC := Low(IC) to High(IC) do
  begin
    Found := LandrixEInvoiceIdentifierSchemeFromStr(LandrixEInvoiceIdentifierSchemeToStr(IC), IC2);
    CheckCodeCommon('IdentifierScheme', Ord(IC), LandrixEInvoiceIdentifierSchemeToStr(IC), Found, Ord(IC2));
  end;
  for VX := Low(VX) to High(VX) do
  begin
    Found := LandrixEInvoiceVATExemptionReasonCodeFromStr(LowerAscii(LandrixEInvoiceVATExemptionReasonCodeToStr(VX)), VX2);
    CheckCodeCommon('VATExemptionReasonCode', Ord(VX), LandrixEInvoiceVATExemptionReasonCodeToStr(VX), Found, Ord(VX2));
  end;
  for RC := Low(RC) to High(RC) do
  begin
    Found := LandrixEInvoiceReferenceCodeQualifierFromStr(LandrixEInvoiceReferenceCodeQualifierToStr(RC), RC2);
    CheckCodeCommon('ReferenceCodeQualifier', Ord(RC), LandrixEInvoiceReferenceCodeQualifierToStr(RC), Found, Ord(RC2));
  end;
  for ICS := Low(ICS) to High(ICS) do
  begin
    Found := LandrixEInvoiceItemClassificationSchemeFromStr(LandrixEInvoiceItemClassificationSchemeToStr(ICS), ICS2);
    CheckCodeCommon('ItemClassificationScheme', Ord(ICS), LandrixEInvoiceItemClassificationSchemeToStr(ICS), Found, Ord(ICS2));
  end;
  CheckEqualsInvoiceStr('DE', LandrixEInvoiceCountryCodeToStr(icc_DE), 'country DE');
  CheckEqualsInvoiceStr('EUR', LandrixEInvoiceCurrencyCodeToStr(icur_EUR), 'currency EUR');
  CheckEqualsInvoiceStr('9930', LandrixEInvoiceElectronicAddressSchemeToStr(ieas_9930), 'EAS 9930');
  CheckEqualsInvoiceStr('EM', LandrixEInvoiceElectronicAddressSchemeToStr(ieas_EM), 'EAS EM');
  CheckEqualsInvoiceStr('0088', LandrixEInvoiceIdentifierSchemeToStr(iicd_0088), 'ICD 0088');
  CheckEqualsInvoiceStr('VATEX-EU-79-C', LandrixEInvoiceVATExemptionReasonCodeToStr(ivx_EU_79_C), 'VATEX prefix');
  CheckEqualsInvoiceStr('ON', LandrixEInvoiceReferenceCodeQualifierToStr(irc_ON), '1153 ON');
  CheckEqualsInvoiceStr('GB', LandrixEInvoiceItemClassificationSchemeToStr(iics_GB), '7143 GB');
  CheckEqualsInvoiceStr('XPK', LandrixEInvoiceUnitCodeToStr(iuc_packaging), 'Rec. 21 package code kept as alias');
  CheckEqualsInvoiceStr('XBX', LandrixEInvoiceUnitCodeToStr(iuc_XBX), 'generated Rec. 21 member');
  Check(not LandrixEInvoiceCountryCodeFromStr('XX', CC), 'unknown country');
  Check(CC = icc_None, 'unknown country gives icc_None');
end;

{ --- model -------------------------------------------------------------- }

{ Builds an invoice with every owned sub-object and list filled, so that the
  destructors are exercised (a leak checker, e.g. FPC -gh, sees the rest). }
procedure TestCreateFullInvoice;
var
  Inv: TLandrixInvoice;
  Line: TLandrixInvoiceLine;
begin
  Inv := TLandrixInvoice.Create;
  try
    Check(Inv.InvoiceLines.First = nil, 'First of an empty list is nil');
    Check(Inv.InvoiceLines.Last = nil, 'Last of an empty list is nil');
    CheckEqualsInvoiceStr('urn:fdc:peppol.eu:2017:poacc:billing:01:1.0', Inv.ProfileID, 'default ProfileID');
    CheckEqualsInvoiceStr('0088', Inv.DeliveryInformation.LocationIdentifierSchemeID, 'default location scheme');
    Inv.InvoiceNumber := 'RE-1';
    Inv.InvoiceTypeCode := itc_CommercialInvoice;
    Inv.Notes.AddNote.Content := 'note';
    Inv.PaymentTypes.AddPaymentType.PaymentMeansCode := ipmc_SEPACreditTransfer;
    Inv.Attachments.AddAttachment(iat_application_pdf).EmbedDataFromText('xy');
    Inv.PrepaidPayments.AddPrepaidPayment.PaidAmount := 1;
    Inv.AllowanceCharges.AddAllowanceCharge.Amount := 2;
    Inv.PrecedingInvoiceReferences.AddPrecedingInvoiceReference.ID := 'RE-0';
    Inv.TaxAmountSubtotals.AddTaxAmount.TaxPercent := 19;
    Inv.AccountingSupplierParty.Address.City := 'Berlin';
    Line := Inv.InvoiceLines.AddInvoiceLine;
    Line.ID := '1';
    Line.AllowanceCharges.AddAllowanceCharge;
    Line.ItemAttributes.AddItemAttribute.Name := 'Farbe';
    Line.ItemClassifications.AddItemClassification.ClassCode := 'FRACHT';
    Line.SubInvoiceLines.AddInvoiceLine.ID := '1.1';
    Check(Inv.InvoiceLines.First = Line, 'First');
    Check(Inv.InvoiceLines.Last = Line, 'Last');
    Check(Inv.InvoiceLines[0] = Line, 'Items[0]');
    CheckEqualsInvoiceStr('1.1', Inv.InvoiceLines[0].SubInvoiceLines[0].ID, 'sub-line');
  finally
    Inv.Free;
  end;
end;

procedure TestListExtract;
var
  Lines: TLandrixInvoiceLines;
  A, B, X: TLandrixInvoiceLine;
begin
  Lines := TLandrixInvoiceLines.Create;
  try
    A := Lines.AddInvoiceLine;
    B := Lines.AddInvoiceLine;
    X := Lines.Extract(A);
    try
      Check(X = A, 'Extract returns the item');
      CheckEquals(1, Integer(Lines.Count), 'Extract removes the item');
      Check(Lines.First = B, 'remaining item');
    finally
      X.Free; { Extract does not free }
    end;
  finally
    Lines.Free;
  end;
end;

procedure TestNotes;
var
  Notes: TLandrixInvoiceNotes;
begin
  Notes := TLandrixInvoiceNotes.Create;
  try
    Notes.AddNote.Content := 'a';
    Notes.AddNote.Content := 'b';
    CheckEqualsInvoiceStr('a'#13#10'b', Notes.NodeContentsAsText, 'NodeContentsAsText');
    Notes.ReplaceContentWith('c');
    CheckEquals(1, Integer(Notes.Count), 'ReplaceContentWith leaves one note');
    CheckEqualsInvoiceStr('c', Notes[0].Content, 'replaced content');
    Notes.ReplaceContentWith('');
    CheckEquals(0, Integer(Notes.Count), 'ReplaceContentWith with empty text');
  finally
    Notes.Free;
  end;
end;

procedure TestPrecedingInvoiceReferences;
var
  Refs: TLandrixInvoicePrecedingInvoiceReferences;
begin
  Refs := TLandrixInvoicePrecedingInvoiceReferences.Create;
  try
    Refs.AddPrecedingInvoiceReference.ID := 'RE-1';
    Refs.AddPrecedingInvoiceReference.ID := 'Ab-2';
    Check(Refs.IndexOfPrecedingInvoiceReference('ab-2') = 1, 'case-insensitive search');
    Check(Refs.IndexOfPrecedingInvoiceReference('RE-3') = -1, 'not found');
  finally
    Refs.Free;
  end;
end;

procedure TestTaxAmounts;
var
  Taxes: TLandrixInvoiceTaxAmounts;
begin
  Taxes := TLandrixInvoiceTaxAmounts.Create;
  try
    Check(not Taxes.AddTaxAmountIfTaxExists(19, 100, 19), 'no entry yet');
    Taxes.AddTaxAmount.TaxPercent := 19;
    Check(Taxes.AddTaxAmountIfTaxExists(19, 100, 19), 'existing rate');
    Check(Taxes[0].TaxableAmount = 100, 'taxable amount added');
    Check(Taxes[0].TaxAmount = 19, 'tax amount added');
  finally
    Taxes.Free;
  end;
end;

{ --- unit of measure ---------------------------------------------------- }

procedure CheckUnit(const Input: TLandrixEInvoiceString; Expected: TLandrixInvoiceUnitCode;
  const Msg: string);
var
  Success: Boolean;
  Actual: TLandrixInvoiceUnitCode;
begin
  Actual := LandrixEInvoiceUnitCodeFromUnitOfMeasure(Input, Success);
  Check(Success, Msg + ': success');
  CheckEquals(Ord(Expected), Ord(Actual), Msg);
end;

procedure TestUnitOfMeasure;
var
  Success: Boolean;
begin
  CheckUnit('Stk', iuc_piece, 'Stk');
  CheckUnit('  STK.  ', iuc_piece, 'trimmed and upper case');
  CheckUnit('Std', iuc_hour, 'Std');
  CheckUnit('Pauschale', iuc_flaterate, 'Pauschale');
  CheckUnit('C62', iuc_one, 'C62');
  CheckUnit('', iuc_one, 'empty text');
  CheckUnit('Kart.', iuc_packaging, 'Kart.');
  CheckUnit('qm', iuc_square_metre, 'qm');
  { STUECK with U+00DC, built from code units }
  CheckUnit(Wide([$53, $54, $DC, $43, $4B]), iuc_piece, 'STUECK with umlaut');
  CheckUnit(Wide([$6B, $F6, $70, $66, $65]), iuc_person, 'koepfe with umlaut');
  CheckUnit(Wide([$46, $55, $1E9E]), iuc_foot, 'FUSS with capital sharp s');
  CheckUnit(Wide([$66, $75, $DF]), iuc_foot, 'fuss with sharp s');
  CheckUnit(Wide([$6D, $B2]), iuc_square_metre, 'm with superscript two');
  CheckUnit(Wide([$63, $6D, $B3]), iuc_cubic_centimetre, 'cm with superscript three');
  CheckEquals(Ord(iuc_piece), Ord(LandrixEInvoiceUnitCodeFromUnitOfMeasure('xyz', Success)), 'unknown: default');
  Check(not Success, 'unknown: no success');
  CheckEquals(Ord(iuc_one), Ord(LandrixEInvoiceUnitCodeFromUnitOfMeasure('xyz', Success, iuc_one)), 'unknown: given default');
  CheckEquals(Ord(iuc_piece), Ord(LandrixEInvoiceUnitCodeFromUnitOfMeasure(Wide([$53, $20AC]), Success)), 'other non-ASCII: default');
  Check(not Success, 'other non-ASCII: no success');
end;

procedure TestAttachmentTypeFromFilename;
begin
  Check(LandrixEInvoiceAttachmentTypeFromFilename('a.PDF') = iat_application_pdf, 'PDF');
  Check(LandrixEInvoiceAttachmentTypeFromFilename('dir.x' + PathDelim + 'b.jpeg') = iat_image_jpeg, 'jpeg');
  Check(LandrixEInvoiceAttachmentTypeFromFilename('c.Xlsx') = iat_application_vnd_openxmlformats_officedocument_spreadsheetml_sheet, 'xlsx');
  Check(LandrixEInvoiceAttachmentTypeFromFilename('noext') = iat_application_None, 'no extension');
  Check(LandrixEInvoiceAttachmentTypeFromFilename('d.docx') = iat_application_None, 'unsupported');
end;

{ --- attachments -------------------------------------------------------- }

function StreamBytes(Stream: TMemoryStream): AnsiString;
begin
  Result := '';
  SetLength(Result, Integer(Stream.Size));
  Stream.Position := 0;
  if Stream.Size > 0 then
    Stream.ReadBuffer(Result[1], Integer(Stream.Size));
  Stream.Position := 0;
end;

procedure TestBase64RoundTrip;
const
  Expected: array[0..5] of string = ('', 'AA==', 'AAE=', 'AAEC', 'AAECAw==', 'AAECAwQ=');
var
  Att: TLandrixInvoiceAttachment;
  I, J: Integer;
  Raw: AnsiString;
  Encoded: TLandrixEInvoiceString;
begin
  Att := TLandrixInvoiceAttachment.Create(iat_application_pdf);
  try
    for I := 0 to 5 do
    begin
      Raw := '';
      for J := 0 to I - 1 do
        Raw := Raw + AnsiChar(J);
      Att.Data.Clear;
      if Raw <> '' then
        Att.Data.WriteBuffer(PAnsiChar(Raw)^, Length(Raw));
      Encoded := Att.GetDataAsBase64;
      CheckEqualsInvoiceStr(TLandrixEInvoiceString(Expected[I]), Encoded, IntToStr(I) + ' bytes encoded');
      Att.SetDataFromBase64(Encoded);
      CheckEquals(I, Integer(Att.Data.Size), IntToStr(I) + ' bytes decoded');
      Check(Att.ContainsBinaryObject = (I > 0), 'ContainsBinaryObject');
    end;
    Att.SetDataFromBase64('TW' + #13#10 + ' Fu');
    CheckEqualsBytes('Man', StreamBytes(Att.Data), 'white space in Base64');
    Check(Att.Data.Position = 0, 'position after decoding');
  finally
    Att.Free;
  end;
end;

procedure TestBase64Invalid;
var
  Att: TLandrixInvoiceAttachment;
begin
  Att := TLandrixInvoiceAttachment.Create(iat_application_pdf);
  try
    Att.EmbedDataFromText('old');
    try
      Att.SetDataFromBase64('TWF');
      FailNotRaised('ELandrixXmlError for truncated Base64');
    except
      on E: ELandrixXmlError do ;
    end;
    CheckEquals(0, Integer(Att.Data.Size), 'Data empty after invalid Base64');
  finally
    Att.Free;
  end;
end;

procedure TestEmbedText;
var
  Att: TLandrixInvoiceAttachment;
  Lines: TStringList;
begin
  Att := TLandrixInvoiceAttachment.Create(iat_text_csv);
  Lines := TStringList.Create;
  try
    { "Lodz" with Polish letters as UTF-8 without BOM }
    Att.EmbedDataFromText(Wide([$0141, $00F3, $0064, $017A]));
    CheckEqualsBytes(Bytes([$C5, $81, $C3, $B3, $64, $C5, $BA]), StreamBytes(Att.Data), 'UTF-8 text');
    Lines.Add('a;b');
    Att.EmbedDataFromText(Lines);
    CheckEqualsBytes('a;b' + sLineBreak, StreamBytes(Att.Data), 'TStrings as UTF-8');
  finally
    Lines.Free;
    Att.Free;
  end;
end;

procedure TestTryAddAttachmentByExtension;
var
  List: TLandrixInvoiceAttachmentList;
  Att: TLandrixInvoiceAttachment;
begin
  List := TLandrixInvoiceAttachmentList.Create;
  try
    Att := TLandrixInvoiceAttachment(Pointer(1)); { must be reset }
    Check(not List.TryAddAttachmentByExtension(RepositoryRoot + 'does-not-exist.pdf', Att), 'missing file');
    Check(Att = nil, 'missing file: nil');
    Check(List.TryAddAttachmentByExtension(RepositoryRoot + 'tests' + PathDelim + 'LandrixEInvoiceTests.dpr', Att) = False,
      'unsupported extension');
    Check(Att = nil, 'unsupported extension: nil');
    CheckEquals(0, Integer(List.Count), 'nothing added');
  finally
    List.Free;
  end;
end;

{ tests/data/attachment.xml contains exactly the 4 bytes <a/> }
procedure TestAttachmentFromFile;
var
  List: TLandrixInvoiceAttachmentList;
  Att: TLandrixInvoiceAttachment;
  FileName: string;
  Stream: TFileStream;
begin
  FileName := RepositoryRoot + 'tests' + PathDelim + 'data' + PathDelim + 'attachment.xml';
  List := TLandrixInvoiceAttachmentList.Create;
  try
    Check(List.TryAddAttachmentByExtension(FileName, Att), 'supported file added');
    CheckEquals(1, Integer(List.Count), 'one attachment');
    Check(Att = List[0], 'returned attachment is in the list');
    Check(Att.AttachmentType = iat_application_xml, 'type from the extension');
    CheckEquals(0, Integer(Att.Data.Size), 'data not loaded by TryAdd');
    Att.EmbedDataFromFile(FileName);
    CheckEqualsBytes('<a/>', StreamBytes(Att.Data), 'EmbedDataFromFile');
    Att.EmbedDataFromFile(FileName + '.missing');
    CheckEqualsBytes('<a/>', StreamBytes(Att.Data), 'missing file leaves Data unchanged');
    Stream := TFileStream.Create(FileName, fmOpenRead or fmShareDenyNone);
    try
      Stream.Position := 2;
      Att.Data.Clear;
      Att.EmbedDataFromStream(Stream);
      CheckEqualsBytes('<a/>', StreamBytes(Att.Data), 'EmbedDataFromStream takes the whole stream');
    finally
      Stream.Free;
    end;
  finally
    List.Free;
  end;
end;

{ --- Clear --------------------------------------------------------------- }

procedure CheckEmpty(const S: TLandrixEInvoiceString; const Msg: string);
begin
  CheckEquals(0, Length(S), Msg + ' is empty');
end;

procedure CheckZero(Value: Double; const Msg: string);
begin
  Check(Value = 0, Msg + ' is 0');
end;

procedure FillAddress(A: TLandrixInvoiceAddress);
begin
  A.StreetName := 'a';
  A.AdditionalStreetName := 'a';
  A.City := 'a';
  A.PostalZone := 'a';
  A.CountrySubentity := 'a';
  A.AddressLine := 'a';
  A.CountryCode := 'a';
end;

procedure CheckAddressDefault(A: TLandrixInvoiceAddress; const Msg: string);
begin
  CheckEmpty(A.StreetName, Msg + '.StreetName');
  CheckEmpty(A.AdditionalStreetName, Msg + '.AdditionalStreetName');
  CheckEmpty(A.City, Msg + '.City');
  CheckEmpty(A.PostalZone, Msg + '.PostalZone');
  CheckEmpty(A.CountrySubentity, Msg + '.CountrySubentity');
  CheckEmpty(A.AddressLine, Msg + '.AddressLine');
  CheckEmpty(A.CountryCode, Msg + '.CountryCode');
end;

procedure FillParty(P: TLandrixInvoiceAccountingParty);
begin
  P.Name := 'a';
  P.RegistrationName := 'a';
  P.CompanyID := 'a';
  P.CompanyIDSchemeID := 'a';
  FillAddress(P.Address);
  P.IdentifierSellerBuyer := 'a';
  P.GlobalIdentifierSellerBuyer := 'a';
  P.GlobalIdentifierSellerBuyerSchemeID := 'a';
  P.BankAssignedCreditorIdentifier := 'a';
  P.VATCompanyID := 'a';
  P.VATCompanyNumber := 'a';
  P.ContactName := 'a';
  P.ContactDepartment := 'a';
  P.ContactTelephone := 'a';
  P.ContactElectronicMail := 'a';
  P.AdditionalLegalInformationSeller := 'a';
  P.ElectronicAddressSellerBuyer := 'a';
  P.ElectronicAddressSellerBuyerSchemeID := 'a';
end;

procedure CheckPartyDefault(P: TLandrixInvoiceAccountingParty; const Msg: string);
begin
  CheckEmpty(P.Name, Msg + '.Name');
  CheckEmpty(P.RegistrationName, Msg + '.RegistrationName');
  CheckEmpty(P.CompanyID, Msg + '.CompanyID');
  CheckEmpty(P.CompanyIDSchemeID, Msg + '.CompanyIDSchemeID');
  CheckAddressDefault(P.Address, Msg + '.Address');
  CheckEmpty(P.IdentifierSellerBuyer, Msg + '.IdentifierSellerBuyer');
  CheckEmpty(P.GlobalIdentifierSellerBuyer, Msg + '.GlobalIdentifierSellerBuyer');
  CheckEmpty(P.GlobalIdentifierSellerBuyerSchemeID, Msg + '.GlobalIdentifierSellerBuyerSchemeID');
  CheckEmpty(P.BankAssignedCreditorIdentifier, Msg + '.BankAssignedCreditorIdentifier');
  CheckEmpty(P.VATCompanyID, Msg + '.VATCompanyID');
  CheckEmpty(P.VATCompanyNumber, Msg + '.VATCompanyNumber');
  CheckEmpty(P.ContactName, Msg + '.ContactName');
  CheckEmpty(P.ContactDepartment, Msg + '.ContactDepartment');
  CheckEmpty(P.ContactTelephone, Msg + '.ContactTelephone');
  CheckEmpty(P.ContactElectronicMail, Msg + '.ContactElectronicMail');
  CheckEmpty(P.AdditionalLegalInformationSeller, Msg + '.AdditionalLegalInformationSeller');
  CheckEmpty(P.ElectronicAddressSellerBuyer, Msg + '.ElectronicAddressSellerBuyer');
  CheckEmpty(P.ElectronicAddressSellerBuyerSchemeID, Msg + '.ElectronicAddressSellerBuyerSchemeID');
end;

procedure FillFurtherParty(P: TLandrixInvoiceParty);
begin
  P.Name := 'a';
  P.Identifier := 'a';
  P.IdentifierSchemeID := 'a';
  P.CompanyID := 'a';
  P.CompanyIDSchemeID := 'a';
  P.VATCompanyID := 'a';
  FillAddress(P.Address);
  P.ContactName := 'a';
  P.ContactDepartment := 'a';
  P.ContactTelephone := 'a';
  P.ContactElectronicMail := 'a';
end;

procedure CheckFurtherPartyDefault(P: TLandrixInvoiceParty; const Msg: string);
begin
  CheckEmpty(P.Name, Msg + '.Name');
  CheckEmpty(P.Identifier, Msg + '.Identifier');
  CheckEmpty(P.IdentifierSchemeID, Msg + '.IdentifierSchemeID');
  CheckEmpty(P.CompanyID, Msg + '.CompanyID');
  CheckEmpty(P.CompanyIDSchemeID, Msg + '.CompanyIDSchemeID');
  CheckEmpty(P.VATCompanyID, Msg + '.VATCompanyID');
  CheckAddressDefault(P.Address, Msg + '.Address');
  CheckEmpty(P.ContactName, Msg + '.ContactName');
  CheckEmpty(P.ContactDepartment, Msg + '.ContactDepartment');
  CheckEmpty(P.ContactTelephone, Msg + '.ContactTelephone');
  CheckEmpty(P.ContactElectronicMail, Msg + '.ContactElectronicMail');
  Check(P.IsEmpty, Msg + ' is empty');
end;

procedure FillLine(L: TLandrixInvoiceLine);
begin
  L.ID := 'a';
  L.GlobalID_EAN_GTIN := 'a';
  L.StandardItemIdentifier := 'a';
  L.StandardItemIdentifierSchemeID := 'a';
  L.Note := 'a';
  L.ObjectIdentifier := 'a';
  L.ObjectIdentifierSchemeID := 'a';
  L.Name := 'a';
  L.Description := 'a';
  L.Quantity := 1;
  L.UnitCode := iuc_piece;
  L.UnitCodeOther := 'a';
  L.SellersItemIdentification := 'a';
  L.BuyersItemIdentification := 'a';
  L.OrderNumber := 'a';
  L.OrderDate.SetValue(1);
  L.OrderLineReference := 'a';
  L.BuyerAccountingReference := 'a';
  L.TaxPercent := 19;
  L.TaxCategory := idtfcc_S_StandardRate;
  L.TaxCategoryOther := 'a';
  L.TaxExemptionReason := 'a';
  L.GrossPriceAmount := 1;
  L.DiscountOnTheGrossPrice := 1;
  L.NetPriceAmount := 1;
  L.BaseQuantity := 1;
  L.BaseQuantityUnitCode := iuc_piece;
  L.BaseQuantityUnitCodeOther := 'a';
  L.LineAmount := 1;
  L.AllowanceCharges.AddAllowanceCharge;
  L.InvoiceLinePeriodStartDate := 1;
  L.InvoiceLinePeriodEndDate := 1;
  L.ItemClassifications.AddItemClassification;
  L.OriginTradeCountry := 'a';
  L.ItemAttributes.AddItemAttribute;
  L.DeliveryNoteNumber := 'a';
  L.DeliveryNoteLineID := 'a';
  L.DeliveryNoteDate := 1;
  L.ActualDeliveryDate := 1;
  L.SubInvoiceLines.AddInvoiceLine;
  L.LineStatusReasonCode := ilsrc_Group;
  L.LineStatusReasonCodeOther := 'a';
end;

procedure CheckLineDefault(L: TLandrixInvoiceLine; const Msg: string);
begin
  CheckEmpty(L.ID, Msg + '.ID');
  CheckEmpty(L.GlobalID_EAN_GTIN, Msg + '.GlobalID_EAN_GTIN');
  CheckEmpty(L.StandardItemIdentifier, Msg + '.StandardItemIdentifier');
  CheckEmpty(L.StandardItemIdentifierSchemeID, Msg + '.StandardItemIdentifierSchemeID');
  CheckEmpty(L.Note, Msg + '.Note');
  CheckEmpty(L.ObjectIdentifier, Msg + '.ObjectIdentifier');
  CheckEmpty(L.ObjectIdentifierSchemeID, Msg + '.ObjectIdentifierSchemeID');
  CheckEmpty(L.Name, Msg + '.Name');
  CheckEmpty(L.Description, Msg + '.Description');
  CheckZero(L.Quantity, Msg + '.Quantity');
  Check(L.UnitCode = iuc_None, Msg + '.UnitCode is iuc_None');
  CheckEmpty(L.UnitCodeOther, Msg + '.UnitCodeOther');
  CheckEmpty(L.SellersItemIdentification, Msg + '.SellersItemIdentification');
  CheckEmpty(L.BuyersItemIdentification, Msg + '.BuyersItemIdentification');
  CheckEmpty(L.OrderNumber, Msg + '.OrderNumber');
  Check(not L.OrderDate.HasValue, Msg + '.OrderDate not set');
  CheckEmpty(L.OrderLineReference, Msg + '.OrderLineReference');
  CheckEmpty(L.BuyerAccountingReference, Msg + '.BuyerAccountingReference');
  CheckZero(L.TaxPercent, Msg + '.TaxPercent');
  Check(L.TaxCategory = idtfcc_None, Msg + '.TaxCategory is idtfcc_None');
  CheckEmpty(L.TaxCategoryOther, Msg + '.TaxCategoryOther');
  CheckEmpty(L.TaxExemptionReason, Msg + '.TaxExemptionReason');
  CheckZero(L.GrossPriceAmount, Msg + '.GrossPriceAmount');
  CheckZero(L.DiscountOnTheGrossPrice, Msg + '.DiscountOnTheGrossPrice');
  CheckZero(L.NetPriceAmount, Msg + '.NetPriceAmount');
  CheckZero(L.BaseQuantity, Msg + '.BaseQuantity');
  Check(L.BaseQuantityUnitCode = iuc_None, Msg + '.BaseQuantityUnitCode is iuc_None');
  CheckEmpty(L.BaseQuantityUnitCodeOther, Msg + '.BaseQuantityUnitCodeOther');
  CheckZero(L.LineAmount, Msg + '.LineAmount');
  CheckEquals(0, Integer(L.AllowanceCharges.Count), Msg + '.AllowanceCharges');
  CheckZero(L.InvoiceLinePeriodStartDate, Msg + '.InvoiceLinePeriodStartDate');
  CheckZero(L.InvoiceLinePeriodEndDate, Msg + '.InvoiceLinePeriodEndDate');
  CheckEquals(0, Integer(L.ItemClassifications.Count), Msg + '.ItemClassifications');
  CheckEmpty(L.OriginTradeCountry, Msg + '.OriginTradeCountry');
  CheckEquals(0, Integer(L.ItemAttributes.Count), Msg + '.ItemAttributes');
  CheckEmpty(L.DeliveryNoteNumber, Msg + '.DeliveryNoteNumber');
  CheckEmpty(L.DeliveryNoteLineID, Msg + '.DeliveryNoteLineID');
  CheckZero(L.DeliveryNoteDate, Msg + '.DeliveryNoteDate');
  CheckZero(L.ActualDeliveryDate, Msg + '.ActualDeliveryDate');
  CheckEquals(0, Integer(L.SubInvoiceLines.Count), Msg + '.SubInvoiceLines');
  Check(L.LineStatusReasonCode = ilsrc_None, Msg + '.LineStatusReasonCode is ilsrc_None');
  CheckEmpty(L.LineStatusReasonCodeOther, Msg + '.LineStatusReasonCodeOther');
end;

procedure FillInvoice(Inv: TLandrixInvoice);
begin
  Inv.ProfileID := 'a';
  Inv.TestIndicator.SetValue(True);
  Inv.InvoiceNumber := 'a';
  Inv.DocumentName := 'a';
  Inv.InvoiceIssueDate := 1;
  Inv.InvoiceDueDate := 1;
  Inv.InvoicePeriodStartDate := 1;
  Inv.InvoicePeriodEndDate := 1;
  Inv.InvoiceTypeCode := itc_CommercialInvoice;
  Inv.InvoiceTypeCodeOther := 'a';
  Inv.InvoiceCurrencyCode := 'a';
  Inv.TaxCurrencyCode := 'a';
  Inv.TaxPointDate.SetValue(1);
  Inv.TaxPointDateCode := 'a';
  Inv.BuyerReference := 'a';
  Inv.Notes.AddNote;
  Inv.SellerOrderReference := 'a';
  Inv.SellerOrderReferenceDate.SetValue(1);
  Inv.PurchaseOrderReference := 'a';
  Inv.PurchaseOrderReferenceDate.SetValue(1);
  Inv.ProjectReference := 'a';
  Inv.ReceiptDocumentReference := 'a';
  Inv.ContractDocumentReference := 'a';
  Inv.DeliveryReceiptNumber := 'a';
  Inv.DeliveryReceiptDate := 1;
  Inv.DeliveryReceiptNumberExtended := 'a';
  Inv.DeliveryReceiptDateExtended := 1;
  Inv.BuyerAccountingReference := 'a';
  FillParty(Inv.AccountingSupplierParty);
  FillParty(Inv.AccountingCustomerParty);
  Inv.DeliveryInformation.Name := 'a';
  Inv.DeliveryInformation.LocationIdentifier := 'a';
  Inv.DeliveryInformation.LocationIdentifierSchemeID := 'a';
  FillAddress(Inv.DeliveryInformation.Address);
  Inv.DeliveryInformation.ActualDeliveryDate := 1;
  Inv.DeliveryInformation.ContactName := 'a';
  Inv.DeliveryInformation.ContactTelephone := 'a';
  Inv.DeliveryInformation.ContactElectronicMail := 'a';
  FillFurtherParty(Inv.PayeeParty);
  FillFurtherParty(Inv.TaxRepresentativeParty);
  FillFurtherParty(Inv.InvoiceeParty);
  Inv.PaymentID := 'a';
  Inv.PaymentTypes.AddPaymentType;
  Inv.PaymentMandateID := 'a';
  Inv.PaymentTermsType := iptt_CashDiscount3;
  Inv.PaymentTermNetNote := 'a';
  Inv.PaymentTermCashDiscount1Days := 1;
  Inv.PaymentTermCashDiscount1Percent := 1;
  Inv.PaymentTermCashDiscount1Base := 1;
  Inv.PaymentTermCashDiscount1ActualAmount := 1;
  Inv.PaymentTermCashDiscount2Days := 1;
  Inv.PaymentTermCashDiscount2Percent := 1;
  Inv.PaymentTermCashDiscount2Base := 1;
  Inv.PaymentTermCashDiscount2ActualAmount := 1;
  Inv.PaymentTermCashDiscount3Days := 1;
  Inv.PaymentTermCashDiscount3Percent := 1;
  Inv.PaymentTermCashDiscount3Base := 1;
  Inv.PaymentTermCashDiscount3ActualAmount := 1;
  Inv.PaymentTermCashDiscount1Note := 'a';
  Inv.PaymentTermCashDiscount2Note := 'a';
  Inv.PaymentTermCashDiscount3Note := 'a';
  FillLine(Inv.InvoiceLines.AddInvoiceLine);
  Inv.Attachments.AddAttachment(iat_application_pdf);
  Inv.PrepaidPayments.AddPrepaidPayment;
  Inv.AllowanceCharges.AddAllowanceCharge;
  Inv.PrecedingInvoiceReferences.AddPrecedingInvoiceReference;
  Inv.TaxAmountTotal := 1;
  Inv.TaxAmountTotalInTaxCurrency.SetValue(1);
  Inv.TaxAmountSubtotals.AddTaxAmount;
  Inv.LineAmount := 1;
  Inv.TaxExclusiveAmount := 1;
  Inv.TaxInclusiveAmount := 1;
  Inv.AllowanceTotalAmount := 1;
  Inv.ChargeTotalAmount := 1;
  Inv.PrepaidAmount := 1;
  Inv.PayableRoundingAmount := 1;
  Inv.PayableAmount := 1;
end;

procedure CheckInvoiceDefault(Inv: TLandrixInvoice; const Msg: string);
begin
  CheckEqualsInvoiceStr('urn:fdc:peppol.eu:2017:poacc:billing:01:1.0', Inv.ProfileID, Msg + '.ProfileID');
  Check(not Inv.TestIndicator.HasValue, Msg + '.TestIndicator not set');
  CheckEmpty(Inv.InvoiceNumber, Msg + '.InvoiceNumber');
  CheckEmpty(Inv.DocumentName, Msg + '.DocumentName');
  CheckZero(Inv.InvoiceIssueDate, Msg + '.InvoiceIssueDate');
  CheckZero(Inv.InvoiceDueDate, Msg + '.InvoiceDueDate');
  CheckZero(Inv.InvoicePeriodStartDate, Msg + '.InvoicePeriodStartDate');
  CheckZero(Inv.InvoicePeriodEndDate, Msg + '.InvoicePeriodEndDate');
  Check(Inv.InvoiceTypeCode = itc_None, Msg + '.InvoiceTypeCode is itc_None');
  CheckEmpty(Inv.InvoiceTypeCodeOther, Msg + '.InvoiceTypeCodeOther');
  CheckEmpty(Inv.InvoiceCurrencyCode, Msg + '.InvoiceCurrencyCode');
  CheckEmpty(Inv.TaxCurrencyCode, Msg + '.TaxCurrencyCode');
  Check(not Inv.TaxPointDate.HasValue, Msg + '.TaxPointDate not set');
  CheckEmpty(Inv.TaxPointDateCode, Msg + '.TaxPointDateCode');
  CheckEmpty(Inv.BuyerReference, Msg + '.BuyerReference');
  CheckEquals(0, Integer(Inv.Notes.Count), Msg + '.Notes');
  CheckEmpty(Inv.SellerOrderReference, Msg + '.SellerOrderReference');
  Check(not Inv.SellerOrderReferenceDate.HasValue, Msg + '.SellerOrderReferenceDate not set');
  CheckEmpty(Inv.PurchaseOrderReference, Msg + '.PurchaseOrderReference');
  Check(not Inv.PurchaseOrderReferenceDate.HasValue, Msg + '.PurchaseOrderReferenceDate not set');
  CheckEmpty(Inv.ProjectReference, Msg + '.ProjectReference');
  CheckEmpty(Inv.ReceiptDocumentReference, Msg + '.ReceiptDocumentReference');
  CheckEmpty(Inv.ContractDocumentReference, Msg + '.ContractDocumentReference');
  CheckEmpty(Inv.DeliveryReceiptNumber, Msg + '.DeliveryReceiptNumber');
  CheckZero(Inv.DeliveryReceiptDate, Msg + '.DeliveryReceiptDate');
  CheckEmpty(Inv.DeliveryReceiptNumberExtended, Msg + '.DeliveryReceiptNumberExtended');
  CheckZero(Inv.DeliveryReceiptDateExtended, Msg + '.DeliveryReceiptDateExtended');
  CheckEmpty(Inv.BuyerAccountingReference, Msg + '.BuyerAccountingReference');
  CheckPartyDefault(Inv.AccountingSupplierParty, Msg + '.AccountingSupplierParty');
  CheckPartyDefault(Inv.AccountingCustomerParty, Msg + '.AccountingCustomerParty');
  CheckEmpty(Inv.DeliveryInformation.Name, Msg + '.DeliveryInformation.Name');
  CheckEmpty(Inv.DeliveryInformation.LocationIdentifier, Msg + '.DeliveryInformation.LocationIdentifier');
  CheckEqualsInvoiceStr('0088', Inv.DeliveryInformation.LocationIdentifierSchemeID, Msg + '.DeliveryInformation.LocationIdentifierSchemeID');
  CheckAddressDefault(Inv.DeliveryInformation.Address, Msg + '.DeliveryInformation.Address');
  CheckZero(Inv.DeliveryInformation.ActualDeliveryDate, Msg + '.DeliveryInformation.ActualDeliveryDate');
  CheckEmpty(Inv.DeliveryInformation.ContactName, Msg + '.DeliveryInformation.ContactName');
  CheckEmpty(Inv.DeliveryInformation.ContactTelephone, Msg + '.DeliveryInformation.ContactTelephone');
  CheckEmpty(Inv.DeliveryInformation.ContactElectronicMail, Msg + '.DeliveryInformation.ContactElectronicMail');
  CheckFurtherPartyDefault(Inv.PayeeParty, Msg + '.PayeeParty');
  CheckFurtherPartyDefault(Inv.TaxRepresentativeParty, Msg + '.TaxRepresentativeParty');
  CheckFurtherPartyDefault(Inv.InvoiceeParty, Msg + '.InvoiceeParty');
  CheckEmpty(Inv.PaymentID, Msg + '.PaymentID');
  CheckEquals(0, Integer(Inv.PaymentTypes.Count), Msg + '.PaymentTypes');
  CheckEmpty(Inv.PaymentMandateID, Msg + '.PaymentMandateID');
  Check(Inv.PaymentTermsType = iptt_None, Msg + '.PaymentTermsType is iptt_None');
  CheckEmpty(Inv.PaymentTermNetNote, Msg + '.PaymentTermNetNote');
  CheckEquals(0, Inv.PaymentTermCashDiscount1Days, Msg + '.PaymentTermCashDiscount1Days');
  CheckZero(Inv.PaymentTermCashDiscount1Percent, Msg + '.PaymentTermCashDiscount1Percent');
  CheckZero(Inv.PaymentTermCashDiscount1Base, Msg + '.PaymentTermCashDiscount1Base');
  CheckZero(Inv.PaymentTermCashDiscount1ActualAmount, Msg + '.PaymentTermCashDiscount1ActualAmount');
  CheckEquals(0, Inv.PaymentTermCashDiscount2Days, Msg + '.PaymentTermCashDiscount2Days');
  CheckZero(Inv.PaymentTermCashDiscount2Percent, Msg + '.PaymentTermCashDiscount2Percent');
  CheckZero(Inv.PaymentTermCashDiscount2Base, Msg + '.PaymentTermCashDiscount2Base');
  CheckZero(Inv.PaymentTermCashDiscount2ActualAmount, Msg + '.PaymentTermCashDiscount2ActualAmount');
  CheckEquals(0, Inv.PaymentTermCashDiscount3Days, Msg + '.PaymentTermCashDiscount3Days');
  CheckZero(Inv.PaymentTermCashDiscount3Percent, Msg + '.PaymentTermCashDiscount3Percent');
  CheckZero(Inv.PaymentTermCashDiscount3Base, Msg + '.PaymentTermCashDiscount3Base');
  CheckZero(Inv.PaymentTermCashDiscount3ActualAmount, Msg + '.PaymentTermCashDiscount3ActualAmount');
  CheckEmpty(Inv.PaymentTermCashDiscount1Note, Msg + '.PaymentTermCashDiscount1Note');
  CheckEmpty(Inv.PaymentTermCashDiscount2Note, Msg + '.PaymentTermCashDiscount2Note');
  CheckEmpty(Inv.PaymentTermCashDiscount3Note, Msg + '.PaymentTermCashDiscount3Note');
  CheckEquals(0, Integer(Inv.InvoiceLines.Count), Msg + '.InvoiceLines');
  CheckEquals(0, Integer(Inv.Attachments.Count), Msg + '.Attachments');
  CheckEquals(0, Integer(Inv.PrepaidPayments.Count), Msg + '.PrepaidPayments');
  CheckEquals(0, Integer(Inv.AllowanceCharges.Count), Msg + '.AllowanceCharges');
  CheckEquals(0, Integer(Inv.PrecedingInvoiceReferences.Count), Msg + '.PrecedingInvoiceReferences');
  CheckZero(Inv.TaxAmountTotal, Msg + '.TaxAmountTotal');
  Check(not Inv.TaxAmountTotalInTaxCurrency.HasValue, Msg + '.TaxAmountTotalInTaxCurrency not set');
  CheckEquals(0, Integer(Inv.TaxAmountSubtotals.Count), Msg + '.TaxAmountSubtotals');
  CheckZero(Inv.LineAmount, Msg + '.LineAmount');
  CheckZero(Inv.TaxExclusiveAmount, Msg + '.TaxExclusiveAmount');
  CheckZero(Inv.TaxInclusiveAmount, Msg + '.TaxInclusiveAmount');
  CheckZero(Inv.AllowanceTotalAmount, Msg + '.AllowanceTotalAmount');
  CheckZero(Inv.ChargeTotalAmount, Msg + '.ChargeTotalAmount');
  CheckZero(Inv.PrepaidAmount, Msg + '.PrepaidAmount');
  CheckZero(Inv.PayableRoundingAmount, Msg + '.PayableRoundingAmount');
  CheckZero(Inv.PayableAmount, Msg + '.PayableAmount');
end;

procedure TestInvoiceClear;
var
  Inv: TLandrixInvoice;
  Supplier: TLandrixInvoiceAccountingParty;
begin
  Inv := TLandrixInvoice.Create;
  try
    CheckInvoiceDefault(Inv, 'fresh invoice');
    Supplier := Inv.AccountingSupplierParty;
    FillInvoice(Inv);
    Inv.Clear;
    CheckInvoiceDefault(Inv, 'cleared invoice');
    Check(Inv.AccountingSupplierParty = Supplier, 'owned objects are kept, not replaced');
    Check(Inv.PayeeParty <> nil, 'payee kept');
    FillInvoice(Inv);
    Inv.Clear;
    CheckInvoiceDefault(Inv, 'cleared twice');
  finally
    Inv.Free;
  end;
end;

{ IsEmpty looks at every field, including the address. }
procedure TestFurtherPartyIsEmpty;
var
  P: TLandrixInvoiceParty;
begin
  P := TLandrixInvoiceParty.Create;
  try
    Check(P.IsEmpty, 'fresh party is empty');
    P.Address.CountryCode := 'DE';
    Check(not P.IsEmpty, 'address alone counts');
    P.Clear;
    Check(P.IsEmpty, 'cleared');
    P.ContactDepartment := 'x';
    Check(not P.IsEmpty, 'contact department alone counts');
    P.Clear;
    P.IdentifierSchemeID := '0088';
    Check(not P.IsEmpty, 'scheme alone counts');
  finally
    P.Free;
  end;
end;

procedure TestLineClear;
var
  Line: TLandrixInvoiceLine;
begin
  Line := TLandrixInvoiceLine.Create;
  try
    CheckLineDefault(Line, 'fresh line');
    FillLine(Line);
    Line.Clear;
    CheckLineDefault(Line, 'cleared line');
  finally
    Line.Free;
  end;
end;

procedure Register;
begin
  RegisterTest('Codes.TypeCode', TestTypeCodes);
  RegisterTest('Codes.PaymentMeansCode', TestPaymentMeansCodes);
  RegisterTest('Codes.UnitCode', TestUnitCodes);
  RegisterTest('Codes.OtherLists', TestOtherCodeLists);
  RegisterTest('Codes.NewLists', TestNewCodeLists);
  RegisterTest('Model.CreateFullInvoice', TestCreateFullInvoice);
  RegisterTest('Model.ListExtract', TestListExtract);
  RegisterTest('Model.Notes', TestNotes);
  RegisterTest('Model.PrecedingInvoiceReferences', TestPrecedingInvoiceReferences);
  RegisterTest('Model.TaxAmounts', TestTaxAmounts);
  RegisterTest('Model.UnitOfMeasure', TestUnitOfMeasure);
  RegisterTest('Model.AttachmentTypeFromFilename', TestAttachmentTypeFromFilename);
  RegisterTest('Model.Base64RoundTrip', TestBase64RoundTrip);
  RegisterTest('Model.Base64Invalid', TestBase64Invalid);
  RegisterTest('Model.EmbedText', TestEmbedText);
  RegisterTest('Model.TryAddAttachmentByExtension', TestTryAddAttachmentByExtension);
  RegisterTest('Model.AttachmentFromFile', TestAttachmentFromFile);
  RegisterTest('Model.InvoiceClear', TestInvoiceClear);
  RegisterTest('Model.FurtherPartyIsEmpty', TestFurtherPartyIsEmpty);
  RegisterTest('Model.LineClear', TestLineClear);
end;

end.
