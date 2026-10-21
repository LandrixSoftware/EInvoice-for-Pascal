{
  EInvoice-for-Pascal

  Copyright (C) 2026 Landrix Software GmbH & Co. KG

  This file is dual-licensed under:
  - GNU GPL version 3 or later; or
  - the Landrix Software Commercial License.

  See LICENSE and COMMERCIAL-LICENSE.md.

  SPDX-License-Identifier: GPL-3.0-or-later OR LicenseRef-Landrix-Commercial
}

{ Tests for the facade LandrixEInvoice: write, refuse, read, check. }

unit LandrixEInvoiceTestFacade;

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
  LandrixEInvoiceSpecs,
  LandrixEInvoiceInvoice,
  LandrixEInvoiceCII,
  LandrixEInvoiceUBL,
  LandrixEInvoiceFiles,
  LandrixEInvoice,
  LandrixEInvoiceTestFramework,
  LandrixEInvoiceTestCheck,
  LandrixEInvoiceTestPdf,
  LandrixEInvoiceTestScenarios;

function XRUBL: TLandrixEInvoiceTarget;
begin
  Result := TLandrixEInvoiceTargets.XRechnung('3.0', esy_UBL);
end;

function XRCII: TLandrixEInvoiceTarget;
begin
  Result := TLandrixEInvoiceTargets.XRechnung('3.0', esy_CII);
end;

function HasRule(D: TLandrixEInvoiceDiagnostics; const ARuleID: TLandrixEInvoiceString): Boolean;
var
  I: TLandrixEInvoiceListIndex;
begin
  Result := False;
  for I := 0 to D.Count - 1 do
    if D[I].RuleID = ARuleID then
      Result := True;
end;

procedure WriteText(const AFileName: TLandrixEInvoiceString; const AText: AnsiString);
var
  S: TStream;
begin
  S := LandrixEInvoiceOpenFile(AFileName, efm_Create);
  try
    S.WriteBuffer(PAnsiChar(AText)^, Length(AText));
  finally
    S.Free;
  end;
end;

function ReadText(const AFileName: TLandrixEInvoiceString): AnsiString;
var
  S: TStream;
begin
  Result := '';
  S := LandrixEInvoiceOpenFile(AFileName, efm_Read);
  try
    SetLength(Result, Integer(S.Size));
    if Result <> '' then
      S.ReadBuffer(PAnsiChar(Result)^, Length(Result));
  finally
    S.Free;
  end;
end;

type
  PScenarioState = ^TScenarioState;
  TScenarioState = record
    Files: Integer;
    Failures: TStringList;
  end;

{ Writes one scenario invoice through the facade and reads it back. }
procedure ScenarioSink(AInvoice: TLandrixInvoice; const ATarget: TLandrixEInvoiceTarget;
  const AFileName: string; AData: Pointer);
var
  State: PScenarioState;
  Xml: TLandrixXmlUtf8;
  Doc: TLandrixEInvoiceDocument;
begin
  State := PScenarioState(AData);
  Inc(State^.Files);
  try
    Xml := TLandrixEInvoice.SaveToUtf8(AInvoice, ATarget);
    Doc := TLandrixEInvoice.LoadFromUtf8(Xml);
    try
      if not Doc.Info.SpecFound or not LandrixEInvoiceSameTarget(Doc.Info.Spec.Target, ATarget) then
        State^.Failures.Add(AFileName + ': read back as ' + string(LandrixEInvoiceTargetToStr(Doc.Info.Spec.Target)));
      if Doc.Diagnostics.HasErrors then
        State^.Failures.Add(AFileName + ': ' + string(Doc.Diagnostics.ToText));
      if Doc.Invoice.InvoiceNumber <> AInvoice.InvoiceNumber then
        State^.Failures.Add(AFileName + ': invoice number');
    finally
      Doc.Free;
    end;
  except
    on E: ELandrixEInvoiceWriteError do
      State^.Failures.Add(AFileName + ': refused: ' + string(E.Diagnostics.ToText));
    on E: Exception do
      State^.Failures.Add(AFileName + ': ' + E.ClassName + ': ' + E.Message);
  end;
end;

{ Every scenario invoice is written without refusal (business rules on) and
  read back as its target. }
procedure TestScenarios;
var
  State: TScenarioState;
  I: Integer;
  Dir: string;
begin
  Dir := RepositoryRoot + 'tests' + PathDelim + 'data' + PathDelim + 'local' + PathDelim + 'attachments' + PathDelim;
  if not DirectoryExists(Dir) then
  begin
    Skip('no local attachments');
    Exit;
  end;
  State.Files := 0;
  State.Failures := TStringList.Create;
  try
    RunAllScenarios(ScenarioSink, @State, Dir);
    for I := 0 to State.Failures.Count - 1 do
      WriteLn('  ', State.Failures[I]);
    CheckEquals(111, State.Files, 'scenario files');
    CheckEquals(0, State.Failures.Count, 'scenarios through the facade');
  finally
    State.Failures.Free;
  end;
end;

{ A rule error refuses the write: no file, the exception carries the
  diagnostics; the options let it through. }
procedure TestRefuse;
var
  Invoice: TLandrixInvoice;
  D: TLandrixEInvoiceDiagnostics;
  FileName: TLandrixEInvoiceString;
  Dir: string;
begin
  D := TLandrixEInvoiceDiagnostics.Create;
  Invoice := TLandrixInvoice.Create;
  try
    FillComplete(Invoice);
    CheckEquals(0, TLandrixEInvoice.Check(Invoice, XRUBL, [], D), 'complete: ' + string(D.ToText));
    Invoice.BuyerReference := '';
    Dir := ExtractFilePath(ParamStr(0)) + 'files' + PathDelim;
    Check(ForceDirectories(Dir), 'files folder');
    FileName := TLandrixEInvoiceString(Dir + 'refused.xml');
    WriteText(FileName, 'old');
    D.Clear;
    try
      TLandrixEInvoice.SaveToFile(Invoice, FileName, XRUBL, [], D);
      FailNotRaised('ELandrixEInvoiceWriteError');
    except
      on E: ELandrixEInvoiceWriteError do
        Check(HasRule(E.Diagnostics, 'BR-DE-15'), 'BR-DE-15 in the exception');
    end;
    Check(HasRule(D, 'BR-DE-15'), 'BR-DE-15 in the caller''s list');
    CheckEqualsBytes('old', ReadText(FileName), 'nothing written, the old file is untouched');
    CheckEquals(1, TLandrixEInvoice.Check(Invoice, XRUBL), 'Check counts the error');
    TLandrixEInvoice.SaveToFile(Invoice, FileName, XRUBL, [eio_WriteDespiteErrors]);
    Check(Pos(AnsiString('CustomizationID'), ReadText(FileName)) > 0, 'written despite errors');
    Check(TLandrixEInvoice.SaveToUtf8(Invoice, XRUBL, [eio_NoRuleCheck]) <> '', 'no rule check');
  finally
    Invoice.Free;
    D.Free;
  end;
end;

{ Unknown and unwritable targets raise before anything is done; a syntax
  model needs a target of its syntax. }
procedure TestTargets;
var
  Invoice: TLandrixInvoice;
  CII: TLandrixCIIInvoice;
begin
  Invoice := TLandrixInvoice.Create;
  try
    FillComplete(Invoice);
    try
      TLandrixEInvoice.SaveToUtf8(Invoice, TLandrixEInvoiceTargets.PeppolBIS('9.9'));
      FailNotRaised('ELandrixEInvoiceTargetError');
    except
      on ELandrixEInvoiceTargetError do ;
    end;
    CII := TLandrixEInvoice.ToCII(Invoice, XRCII);
    try
      try
        TLandrixEInvoice.SaveToUtf8(CII, XRUBL);
        FailNotRaised('ELandrixEInvoiceTargetError for a CII model and a UBL target');
      except
        on ELandrixEInvoiceTargetError do ;
      end;
      try
        TLandrixEInvoice.ToUBLInvoice(Invoice, XRCII).Free;
        FailNotRaised('ELandrixEInvoiceTargetError for ToUBLInvoice and a CII target');
      except
        on ELandrixEInvoiceTargetError do ;
      end;
    finally
      CII.Free;
    end;
  finally
    Invoice.Free;
  end;
end;

{ Strict mode: content the target leaves out is an error. }
procedure TestStrict;
var
  Invoice: TLandrixInvoice;
  D: TLandrixEInvoiceDiagnostics;
begin
  D := TLandrixEInvoiceDiagnostics.Create;
  Invoice := TLandrixInvoice.Create;
  try
    FillComplete(Invoice);
    Invoice.InvoiceLines[0].OrderNumber := 'B-1'; { left out in UBL }
    CheckEquals(0, TLandrixEInvoice.Check(Invoice, XRUBL, [], D), 'normal: ' + string(D.ToText));
    Check(D.CountOf(edk_NotAllowed) > 0, 'reported as left out');
    D.Clear;
    Check(TLandrixEInvoice.Check(Invoice, XRUBL, [eio_Strict], D) > 0, 'strict: error');
    try
      TLandrixEInvoice.SaveToUtf8(Invoice, XRUBL, [eio_Strict]);
      FailNotRaised('ELandrixEInvoiceWriteError in strict mode');
    except
      on ELandrixEInvoiceWriteError do ;
    end;
  finally
    Invoice.Free;
    D.Free;
  end;
end;

procedure CheckFormatError(const AXml: TLandrixXmlUtf8; const AWhat: string);
begin
  try
    TLandrixEInvoice.LoadFromUtf8(AXml).Free;
    FailNotRaised('ELandrixEInvoiceFormatError: ' + AWhat);
  except
    on ELandrixEInvoiceFormatError do ;
  end;
end;

{ Reading: no document without an invoice; an unknown identifier is read
  with a warning; options and ownership. }
procedure TestRead;
var
  Invoice: TLandrixInvoice;
  Xml: TLandrixXmlUtf8;
  Doc: TLandrixEInvoiceDocument;
  Detached: TLandrixInvoice;
begin
  try
    TLandrixEInvoice.LoadFromUtf8('<Invoice xmlns="urn:oasis:names:specification:ubl:schema:xsd:Invoice-2">' +
      '<a></b></Invoice>').Free;
    FailNotRaised('ELandrixEInvoiceFormatError for XML that is not well-formed');
  except
    on E: ELandrixEInvoiceFormatError do
      Check(E.Line > 0, 'line of the XML error');
  end;
  CheckFormatError('<Order/>', 'unknown root');
  CheckFormatError('<rsm:CrossIndustryDocument xmlns:rsm="urn:x"/>', 'ZUGFeRD 1');
  CheckFormatError('<Invoice xmlns="urn:wrong"/>', 'wrong namespace');
  CheckFormatError('', 'empty');

  Invoice := TLandrixInvoice.Create;
  try
    FillComplete(Invoice);
    Xml := TLandrixEInvoice.SaveToUtf8(Invoice, XRCII);
  finally
    Invoice.Free;
  end;
  Doc := TLandrixEInvoice.LoadFromUtf8(Xml);
  try
    Check(Doc.Info.Source = eso_Xml, 'source XML');
    Check(Doc.Info.Syntax = esy_CII, 'syntax CII');
    CheckEqualsInvoiceStr('CrossIndustryInvoice', Doc.Info.RootName, 'root name');
    Check(Doc.Info.SpecFound and LandrixEInvoiceSameTarget(Doc.Info.Spec.Target, XRCII), 'XRechnung CII');
    Check(Doc.CII <> nil, 'syntax model kept');
    Check((Doc.UBLInvoice = nil) and (Doc.UBLCreditNote = nil), 'no UBL model');
    CheckEqualsInvoiceStr('R-1', Doc.Invoice.InvoiceNumber, 'invoice number');
    Detached := Doc.DetachInvoice;
    try
      Check(Doc.Invoice = nil, 'detached');
    finally
      Detached.Free;
    end;
  finally
    Doc.Free;
  end;
  Doc := TLandrixEInvoice.LoadFromUtf8(Xml, [eio_InvoiceOnly, eio_CheckOnRead]);
  try
    Check(Doc.CII = nil, 'syntax model freed');
    CheckEquals(0, Doc.Diagnostics.CountOf(edk_RuleViolation), 'checked on read: ' + string(Doc.Diagnostics.ToText));
  finally
    Doc.Free;
  end;
  Doc := TLandrixEInvoice.LoadFromUtf8(
    '<Invoice xmlns="urn:oasis:names:specification:ubl:schema:xsd:Invoice-2" ' +
    'xmlns:cbc="urn:oasis:names:specification:ubl:schema:xsd:CommonBasicComponents-2">' +
    '<cbc:CustomizationID>urn:cen.eu:en16931:2017</cbc:CustomizationID><cbc:ID>X-1</cbc:ID></Invoice>');
  try
    Check(not Doc.Info.SpecFound, 'plain EN 16931 has no entry');
    CheckEqualsInvoiceStr('urn:cen.eu:en16931:2017', Doc.Info.CustomizationID, 'BT-24 as read');
    CheckEquals(1, Doc.Diagnostics.CountOf(edk_UnknownCode), 'unknown identifier reported');
    CheckEqualsInvoiceStr('X-1', Doc.Invoice.InvoiceNumber, 'read anyway');
  finally
    Doc.Free;
  end;
end;

{ SaveToText is SaveToUtf8 as text; LoadFromText does not consult the
  encoding declaration and refuses an unpaired surrogate. }
procedure TestText;
const
  Utf8Decl = '<?xml version="1.0" encoding="UTF-8"?>';
var
  Invoice: TLandrixInvoice;
  UBL: TLandrixUBLInvoice;
  Doc: TLandrixEInvoiceDocument;
  Name, Text, Latin: TLandrixEInvoiceString;
begin
  Invoice := TLandrixInvoice.Create;
  try
    FillComplete(Invoice);
    Name := 'M';
    Name := Name + WideChar($00FC) + 'ller ' + WideChar($20AC);
    Invoice.AccountingCustomerParty.Name := Name;
    Text := TLandrixEInvoice.SaveToText(Invoice, XRCII);
    Check(Text = LandrixEInvoiceUtf8ToString(TLandrixEInvoice.SaveToUtf8(Invoice, XRCII)), 'invoice as text');
    UBL := TLandrixEInvoice.ToUBLInvoice(Invoice, XRUBL);
    try
      Check(TLandrixEInvoice.SaveToText(UBL, XRUBL) = LandrixEInvoiceUtf8ToString(TLandrixEInvoice.SaveToUtf8(UBL,
        XRUBL)), 'syntax model as text');
    finally
      UBL.Free;
    end;
  finally
    Invoice.Free;
  end;
  CheckEqualsInvoiceStr(Utf8Decl, Copy(Text, 1, Length(Utf8Decl)), 'declaration of the text');
  Latin := '<?xml version="1.0" encoding="ISO-8859-1"?>';
  Latin := Latin + Copy(Text, Length(Utf8Decl) + 1, Length(Text));
  Doc := TLandrixEInvoice.LoadFromText(Latin);
  try
    CheckEqualsInvoiceStr(Name, Doc.Invoice.AccountingCustomerParty.Name, 'declaration not consulted');
    Check(Doc.Info.Source = eso_Xml, 'source XML');
  finally
    Doc.Free;
  end;
  try
    TLandrixEInvoice.LoadFromText(Copy(Text, 1, 100) + WideChar($D800) + Copy(Text, 101, Length(Text))).Free;
    FailNotRaised('ELandrixEInvoiceFormatError for an unpaired surrogate');
  except
    on ELandrixEInvoiceFormatError do ;
  end;
end;

{ A syntax model with content its profile does not contain is refused; its
  BT-24 must belong to the target. }
procedure TestSyntaxModel;
var
  Invoice: TLandrixInvoice;
  CII: TLandrixCIIInvoice;
  D: TLandrixEInvoiceDiagnostics;
  Basic: TLandrixEInvoiceTarget;
begin
  Basic := TLandrixEInvoiceTargets.FacturX('1.09', epr_Basic);
  D := TLandrixEInvoiceDiagnostics.Create;
  Invoice := TLandrixInvoice.Create;
  try
    FillComplete(Invoice);
    CII := TLandrixEInvoice.ToCII(Invoice, Basic);
    try
      CheckEquals(0, TLandrixEInvoice.Check(CII, Basic, [], D), 'mapped model: ' + string(D.ToText));
      CII.ExchangedDocument.Name := 'EXTENDED only';
      D.Clear;
      CheckEquals(1, TLandrixEInvoice.Check(CII, Basic, [], D), 'name not in BASIC: ' + string(D.ToText));
      try
        TLandrixEInvoice.SaveToUtf8(CII, Basic);
        FailNotRaised('ELandrixEInvoiceWriteError for content outside the profile');
      except
        on ELandrixEInvoiceWriteError do ;
      end;
      CII.ExchangedDocument.Name := '';
      Check(TLandrixEInvoice.SaveToUtf8(CII, Basic) <> '', 'written without the name');
      D.Clear;
      CheckEquals(1, TLandrixEInvoice.Check(CII, TLandrixEInvoiceTargets.FacturX('1.09', epr_EN16931), [], D),
        'BT-24 of BASIC for EN16931: ' + string(D.ToText));
      CheckEquals(1, D.CountOf(edk_InvalidValue), 'BT-24 reported');
    finally
      CII.Free;
    end;
  finally
    Invoice.Free;
    D.Free;
  end;
end;

{ BT-24 of the mapped models belongs to their target: the XRechnung
  extension, a credit note, Peppol; files and streams. }
procedure TestModelsAndFiles;
var
  Invoice: TLandrixInvoice;
  D: TLandrixEInvoiceDiagnostics;
  UBL: TLandrixUBLInvoice;
  CreditNote: TLandrixUBLCreditNote;
  M: TMemoryStream;
  Doc: TLandrixEInvoiceDocument;
  FileName: TLandrixEInvoiceString;
  Peppol: TLandrixEInvoiceTarget;
begin
  Peppol := TLandrixEInvoiceTargets.PeppolBIS('3.0');
  D := TLandrixEInvoiceDiagnostics.Create;
  Invoice := TLandrixInvoice.Create;
  try
    FillComplete(Invoice);
    { XRechnung UBL with sub lines uses the extension identifier }
    with Invoice.InvoiceLines[0].SubInvoiceLines.AddInvoiceLine do
    begin
      ID := '1.1';
      Name := 'Part';
      Quantity := 1;
      UnitCode := iuc_piece;
    end;
    UBL := TLandrixEInvoice.ToUBLInvoice(Invoice, XRUBL, D);
    try
      Check(Pos('extension', string(UBL.CustomizationID.Value)) > 0, 'extension identifier');
      D.Clear;
      TLandrixEInvoice.Check(UBL, XRUBL, [], D);
      CheckEquals(0, D.CountOf(edk_InvalidValue), 'extension identifier belongs to XRechnung UBL: ' + string(D.ToText));
    finally
      UBL.Free;
    end;
    Invoice.InvoiceLines[0].SubInvoiceLines.Clear;
    Invoice.InvoiceTypeCode := itc_CreditNote;
    CreditNote := TLandrixEInvoice.ToUBLCreditNote(Invoice, Peppol);
    try
      D.Clear;
      CheckEquals(0, TLandrixEInvoice.Check(CreditNote, Peppol, [], D), 'Peppol credit note: ' + string(D.ToText));
      Check(TLandrixEInvoice.SaveToUtf8(CreditNote, Peppol) <> '', 'credit note written');
    finally
      CreditNote.Free;
    end;
    Invoice.InvoiceTypeCode := itc_CommercialInvoice;
    M := TMemoryStream.Create;
    try
      TLandrixEInvoice.SaveToStream(Invoice, M, Peppol);
      Check(M.Size > 0, 'stream written');
      M.Position := 0;
      Doc := TLandrixEInvoice.LoadFromStream(M);
      try
        Check(Doc.Info.SpecFound and LandrixEInvoiceSameTarget(Doc.Info.Spec.Target, Peppol), 'Peppol from stream');
      finally
        Doc.Free;
      end;
    finally
      M.Free;
    end;
    FileName := TLandrixEInvoiceString(ExtractFilePath(ParamStr(0)) + 'files' + PathDelim) +
      'facade-' + WideChar($00FC) + '.xml';
    Check(ForceDirectories(ExtractFilePath(ParamStr(0)) + 'files'), 'files folder');
    TLandrixEInvoice.SaveToFile(Invoice, FileName, XRUBL);
    Doc := TLandrixEInvoice.LoadFromFile(FileName);
    try
      Check(Doc.Info.SpecFound and LandrixEInvoiceSameTarget(Doc.Info.Spec.Target, XRUBL), 'XRechnung UBL from file');
      Check(Doc.UBLInvoice <> nil, 'UBL model');
    finally
      Doc.Free;
    end;
  finally
    Invoice.Free;
    D.Free;
  end;
end;

{ A PDF with an embedded invoice is detected by content. }
procedure TestPdf;
var
  Invoice: TLandrixInvoice;
  Xml: TLandrixXmlUtf8;
  Pdf: AnsiString;
  M: TMemoryStream;
  Doc: TLandrixEInvoiceDocument;
  I: Integer;
  Target: TLandrixEInvoiceTarget;
begin
  Target := TLandrixEInvoiceTargets.FacturX('1.09', epr_EN16931);
  Invoice := TLandrixInvoice.Create;
  try
    FillComplete(Invoice);
    Xml := TLandrixEInvoice.SaveToUtf8(Invoice, Target);
  finally
    Invoice.Free;
  end;
  Pdf := '';
  SetLength(Pdf, Length(Xml));
  for I := 1 to Length(Xml) do
    Pdf[I] := Xml[I];
  Pdf := BuildInvoicePdf(Pdf);
  M := TMemoryStream.Create;
  try
    M.WriteBuffer(PAnsiChar(Pdf)^, Length(Pdf));
    M.Position := 0;
    Doc := TLandrixEInvoice.LoadFromStream(M);
    try
      Check(Doc.Info.Source = eso_Pdf, 'source PDF');
      CheckEqualsInvoiceStr('factur-x.xml', Doc.Info.PdfAttachmentName, 'attachment name');
      Check(Doc.Info.SpecFound and LandrixEInvoiceSameTarget(Doc.Info.Spec.Target, Target), 'Factur-X EN16931');
    finally
      Doc.Free;
    end;
    M.Position := 0;
    try
      TLandrixEInvoice.LoadFromStream(M, [eio_NoPdf]).Free;
      FailNotRaised('ELandrixEInvoiceFormatError for a PDF read as XML');
    except
      on ELandrixEInvoiceFormatError do ;
    end;
  finally
    M.Free;
  end;
  M := TMemoryStream.Create;
  try
    Pdf := '%PDF-1.7' + #10 + 'garbage';
    M.WriteBuffer(PAnsiChar(Pdf)^, Length(Pdf));
    M.Position := 0;
    try
      TLandrixEInvoice.LoadFromStream(M).Free;
      FailNotRaised('ELandrixEInvoicePdfError');
    except
      on ELandrixEInvoicePdfError do ;
    end;
  finally
    M.Free;
  end;
end;

procedure Register;
begin
  RegisterTest('Facade.Scenarios', TestScenarios);
  RegisterTest('Facade.Refuse', TestRefuse);
  RegisterTest('Facade.Targets', TestTargets);
  RegisterTest('Facade.Strict', TestStrict);
  RegisterTest('Facade.Read', TestRead);
  RegisterTest('Facade.Text', TestText);
  RegisterTest('Facade.SyntaxModel', TestSyntaxModel);
  RegisterTest('Facade.ModelsAndFiles', TestModelsAndFiles);
  RegisterTest('Facade.Pdf', TestPdf);
end;

end.
