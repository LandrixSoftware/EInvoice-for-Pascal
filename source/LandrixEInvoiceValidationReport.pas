{
  EInvoice-for-Pascal

  Copyright (C) 2026 Landrix Software GmbH & Co. KG

  This file is dual-licensed under:
  - GNU GPL version 3 or later; or
  - the Landrix Software Commercial License.

  See LICENSE and COMMERCIAL-LICENSE.md.

  SPDX-License-Identifier: GPL-3.0-or-later OR LicenseRef-Landrix-Commercial
}

{ Writes the result of a validation (LandrixEInvoiceValidation) as an XML
  report of format version 1.0, namespace
  urn:landrix:einvoice:validation-report:1, schema
  schemas/landrix-einvoice-validation-report-1.xsd: the document, the
  verdict, every part with its status, the PDF facts and the flat list of
  findings. No timestamp: the same result gives the same bytes. A character
  that XML does not allow (from a broken document, a PDF name) is replaced
  by U+FFFD (LandrixEInvoiceReportSanitize) and the element is marked
  sanitized, so the report never fails
  because of the document it describes.
  DE: Schreibt das Ergebnis einer Pruefung (LandrixEInvoiceValidation) als
  XML-Bericht im Format 1.0, Namespace
  urn:landrix:einvoice:validation-report:1, Schema
  schemas/landrix-einvoice-validation-report-1.xsd: das Dokument, das
  Urteil, jeden Teil mit seinem Status, die PDF-Fakten und die flache
  Befundliste. Kein Zeitstempel: dasselbe Ergebnis ergibt dieselben Bytes.
  Ein Zeichen, das XML nicht erlaubt (aus einem kaputten Dokument, einem
  PDF-Namen), wird durch U+FFFD ersetzt (LandrixEInvoiceReportSanitize) und
  das Element als sanitized markiert; der Bericht scheitert so nie an dem Dokument, das er
  beschreibt. }

{ API: internal. May change in any release; use the facade LandrixEInvoice
  or the stable units instead.
  DE: API: intern. Kann sich in jeder Version aendern; stattdessen die
  Fassade LandrixEInvoice oder die stabilen Units verwenden. }

unit LandrixEInvoiceValidationReport;

{$I LandrixEInvoice.inc}

interface

uses
  Classes,
  LandrixEInvoiceTypes,
  LandrixEInvoiceValidation;

type
  { Writes validation reports.
    DE: Schreibt Pruefberichte. }
  TLandrixEInvoiceValidationReportWriter = class(TObject)
  private
    FDocumentName: TLandrixEInvoiceString;
    function Build(AResult: TLandrixEInvoiceDocumentValidation): TObject;
  public
    { Writes the report of AResult to AStream at its position. The report is
      built in memory first: if it raises, nothing is written. AResult nil
      raises ELandrixEInvoiceError.
      DE: Schreibt den Bericht zu AResult an der Position von AStream. Der
      Bericht entsteht zuerst im Speicher: loest er eine Ausnahme aus, wird
      nichts geschrieben. AResult nil loest ELandrixEInvoiceError aus. }
    procedure WriteToStream(AResult: TLandrixEInvoiceDocumentValidation; AStream: TStream);
    { The same into a file (created or overwritten).
      DE: Dasselbe in eine Datei (angelegt oder ueberschrieben). }
    procedure SaveToFile(AResult: TLandrixEInvoiceDocumentValidation; const AFileName: string);
    { The name of the document as the report shows it (document/@name), ''
      (the default) for none. The caller chooses it, e.g. the file name
      without its folder; the result does not know it.
      DE: Der Name des Dokuments, wie der Bericht ihn zeigt
      (document/@name), '' (Vorgabe) fuer keinen. Der Aufrufer waehlt ihn,
      z. B. den Dateinamen ohne Ordner; das Ergebnis kennt ihn nicht. }
    property DocumentName: TLandrixEInvoiceString read FDocumentName write FDocumentName;
  end;

implementation

uses
  SysUtils,
  LandrixXmlBase,
  LandrixXmlWriter,
  LandrixEInvoiceDiagnostics,
  LandrixEInvoice,
  LandrixEInvoicePdfCheck,
  LandrixEInvoiceReportHtml;

const
  ReportNamespace = 'urn:landrix:einvoice:validation-report:1';
  ReportVersion = '1.0';
  GeneratorName = 'EInvoice-for-Pascal';

  VerdictNames: array[TLandrixEInvoiceVerdict] of TLandrixXmlUtf8 = ('accepted', 'rejected', 'incomplete');
  PartNames: array[TLandrixEInvoiceValidationPart] of TLandrixXmlUtf8 = ('read', 'kosit', 'modelCheck',
    'pdfEmbedding', 'pdfMetadata', 'pdfA');
  StatusNames: array[TLandrixEInvoicePartStatus] of TLandrixXmlUtf8 = ('notRun', 'passed', 'failed',
    'incomplete');
  SeverityNames: array[TLandrixEInvoiceDiagnosticSeverity] of TLandrixXmlUtf8 = ('info', 'warning', 'error');
  StepNames: array[TLandrixEInvoiceFindingStep] of TLandrixXmlUtf8 = ('', 'wellformedness', 'xmlSchema',
    'schematron');
  SourceNames: array[TLandrixEInvoiceSource] of TLandrixXmlUtf8 = ('xml', 'pdf');
  SyntaxNames: array[TLandrixEInvoiceSyntax] of TLandrixXmlUtf8 = ('', 'ubl', 'cii');
  StandardNames: array[TLandrixEInvoiceStandard] of TLandrixXmlUtf8 = ('', 'xrechnung', 'facturX', 'peppolBis');
  ProfileNames: array[TLandrixEInvoiceProfile] of TLandrixXmlUtf8 = ('', 'minimum', 'basicWL', 'basic',
    'en16931', 'extended', 'xrechnung');
  HybridKindNames: array[TLandrixEInvoicePdfHybridKind] of TLandrixXmlUtf8 = ('none', 'facturX', 'xrechnung',
    'zugferd20', 'zugferd10');

{ An attribute with a value from outside (cleaned); omitted when empty. }
procedure TextAttribute(W: TLandrixXmlWriter; const AName: TLandrixXmlUtf8; const AValue: TLandrixEInvoiceString;
  var ASanitized: Boolean);
begin
  if AValue <> '' then
    W.AttributeUtf8(AName, LandrixEInvoiceStringToUtf8(LandrixEInvoiceReportSanitize(AValue, ASanitized)));
end;

{ An attribute with one of the fixed tokens; omitted when empty. }
procedure TokenAttribute(W: TLandrixXmlWriter; const AName, AValue: TLandrixXmlUtf8);
begin
  if AValue <> '' then
    W.AttributeUtf8(AName, AValue);
end;

procedure SanitizedAttribute(W: TLandrixXmlWriter; ASanitized: Boolean);
begin
  if ASanitized then
    W.AttributeUtf8('sanitized', 'true');
end;

procedure WriteDocument(W: TLandrixXmlWriter; AResult: TLandrixEInvoiceDocumentValidation;
  const ADocumentName: TLandrixEInvoiceString);
var
  Info: TLandrixEInvoiceDocumentInfo;
  Sanitized: Boolean;
begin
  Info := AResult.Info;
  Sanitized := False;
  W.StartElement('document');
  TextAttribute(W, 'name', ADocumentName, Sanitized);
  TokenAttribute(W, 'source', SourceNames[Info.Source]);
  TextAttribute(W, 'rootName', Info.RootName, Sanitized);
  TokenAttribute(W, 'syntax', SyntaxNames[Info.Syntax]);
  TextAttribute(W, 'customizationId', Info.CustomizationID, Sanitized);
  TextAttribute(W, 'profileId', Info.ProfileID, Sanitized);
  SanitizedAttribute(W, Sanitized);
  { the specification the library assigns to BT-24; ExactVersion is the
    release the library is built for, not the one of the sender
    DE: die Spezifikation, die die Bibliothek BT-24 zuordnet; ExactVersion
    ist der Stand, fuer den die Bibliothek gebaut ist, nicht der des
    Absenders }
  if Info.SpecFound then
  begin
    W.StartElement('specification');
    TokenAttribute(W, 'standard', StandardNames[Info.Spec.Target.Standard]);
    TokenAttribute(W, 'syntax', SyntaxNames[Info.Spec.Target.Syntax]);
    TokenAttribute(W, 'profile', ProfileNames[Info.Spec.Target.Profile]);
    TokenAttribute(W, 'version', LandrixEInvoiceStringToUtf8(Info.Spec.Target.Version));
    TokenAttribute(W, 'libraryRelease', LandrixEInvoiceStringToUtf8(Info.Spec.ExactVersion));
    if Info.UsesExtension then
      W.AttributeUtf8('usesExtension', 'true');
    W.EndElement;
  end;
  W.EndElement;
end;

procedure WriteParts(W: TLandrixXmlWriter; AResult: TLandrixEInvoiceDocumentValidation);
var
  P: TLandrixEInvoiceValidationPart;
  Sanitized: Boolean;
begin
  W.StartElement('parts');
  for P := Low(TLandrixEInvoiceValidationPart) to High(TLandrixEInvoiceValidationPart) do
  begin
    Sanitized := False;
    W.StartElement('part');
    W.AttributeUtf8('name', PartNames[P]);
    W.AttributeUtf8('status', StatusNames[AResult.Status[P]]);
    if P = evp_KoSIT then
    begin
      TextAttribute(W, 'configuration', AResult.ConfigurationName, Sanitized);
      TextAttribute(W, 'scenario', AResult.ScenarioName, Sanitized);
    end;
    SanitizedAttribute(W, Sanitized);
    W.EndElement;
  end;
  W.EndElement;
end;

procedure WritePdf(W: TLandrixXmlWriter; APdf: TLandrixEInvoicePdfCheckResult);
var
  Sanitized: Boolean;
begin
  Sanitized := False;
  W.StartElement('pdf');
  W.AttributeUtf8('hybridKind', HybridKindNames[APdf.HybridKind]);
  if APdf.FactsChecked then
  begin
    W.AttributeUtf8('factsChecked', 'true');
    TokenAttribute(W, 'profile', ProfileNames[APdf.Profile]);
  end
  else
    W.AttributeUtf8('factsChecked', 'false');
  TextAttribute(W, 'pdfVersion', APdf.PdfVersion, Sanitized);
  TextAttribute(W, 'catalogVersion', APdf.CatalogVersion, Sanitized);
  TextAttribute(W, 'invoiceFileName', APdf.InvoiceFileName, Sanitized);
  TextAttribute(W, 'invoicePath', APdf.InvoicePath, Sanitized);
  TextAttribute(W, 'relationship', APdf.InvoiceRelationship, Sanitized);
  TextAttribute(W, 'xmpDocumentType', APdf.XmpDocumentType, Sanitized);
  TextAttribute(W, 'xmpDocumentFileName', APdf.XmpDocumentFileName, Sanitized);
  TextAttribute(W, 'xmpVersion', APdf.XmpVersion, Sanitized);
  TextAttribute(W, 'xmpConformanceLevel', APdf.XmpConformanceLevel, Sanitized);
  TextAttribute(W, 'xmpPdfaPart', APdf.PdfAPart, Sanitized);
  TextAttribute(W, 'xmpPdfaConformance', APdf.PdfAConformance, Sanitized);
  SanitizedAttribute(W, Sanitized);
  W.EndElement;
end;

procedure WriteFindings(W: TLandrixXmlWriter; AResult: TLandrixEInvoiceDocumentValidation);
var
  I: Integer;
  F: TLandrixEInvoiceFinding;
  Counts: array[TLandrixEInvoiceDiagnosticSeverity] of Integer;
  Predicted: Integer;
  S: TLandrixEInvoiceDiagnosticSeverity;
  Location, Text: TLandrixEInvoiceString;
  Sanitized: Boolean;
begin
  for S := Low(TLandrixEInvoiceDiagnosticSeverity) to High(TLandrixEInvoiceDiagnosticSeverity) do
    Counts[S] := 0;
  Predicted := 0;
  for I := 0 to AResult.FindingCount - 1 do
    if AResult[I].Predicted then
      Inc(Predicted)
    else
      Inc(Counts[AResult[I].Severity]);
  W.StartElement('findings');
  W.Attribute('errors', IntToStr(Counts[eds_Error]));
  W.Attribute('warnings', IntToStr(Counts[eds_Warning]));
  W.Attribute('infos', IntToStr(Counts[eds_Info]));
  W.Attribute('predicted', IntToStr(Predicted));
  for I := 0 to AResult.FindingCount - 1 do
  begin
    F := AResult[I];
    Sanitized := False;
    W.StartElement('finding');
    W.AttributeUtf8('part', PartNames[F.Part]);
    TextAttribute(W, 'rule', F.RuleID, Sanitized);
    W.AttributeUtf8('severity', SeverityNames[F.Severity]);
    TokenAttribute(W, 'step', StepNames[F.Step]);
    if F.Predicted then
      W.AttributeUtf8('predicted', 'true');
    if F.Line > 0 then
    begin
      W.Attribute('line', IntToStr(F.Line));
      if F.Column > 0 then
        W.Attribute('column', IntToStr(F.Column));
      { level 3 counts in the XMP packet, everything else in the invoice
        XML (also BR-HYBRID-12 of level 2)
        DE: Ebene 3 zaehlt im XMP-Paket, alles andere in der
        Rechnungs-XML (auch BR-HYBRID-12 der Ebene 2) }
      if F.Part = evp_PdfMetadata then
        W.AttributeUtf8('positionIn', 'xmp')
      else
        W.AttributeUtf8('positionIn', 'invoice');
    end;
    Location := LandrixEInvoiceReportSanitize(F.Location, Sanitized);
    Text := LandrixEInvoiceReportSanitize(F.Text, Sanitized);
    SanitizedAttribute(W, Sanitized);
    if Location <> '' then
      W.ElementUtf8('location', LandrixEInvoiceStringToUtf8(Location));
    W.ElementUtf8('text', LandrixEInvoiceStringToUtf8(Text));
    W.EndElement;
  end;
  W.EndElement;
end;

{ --- TLandrixEInvoiceValidationReportWriter ------------------------------ }

function TLandrixEInvoiceValidationReportWriter.Build(AResult: TLandrixEInvoiceDocumentValidation): TObject;
var
  W: TLandrixXmlWriter;
begin
  if AResult = nil then
    raise ELandrixEInvoiceError.Create('No validation result to report');
  W := TLandrixXmlWriter.Create;
  try
    W.Indent := True;
    W.LineBreak := xlbLF;
    W.StartElementNs(ReportNamespace, '', 'validationReport');
    W.AttributeUtf8('version', ReportVersion);
    W.StartElement('generator');
    W.AttributeUtf8('name', GeneratorName);
    W.AttributeUtf8('version', LandrixEInvoiceVersion);
    W.EndElement;
    WriteDocument(W, AResult, FDocumentName);
    W.ElementUtf8('verdict', VerdictNames[AResult.Verdict]);
    WriteParts(W, AResult);
    if AResult.Pdf <> nil then
      WritePdf(W, AResult.Pdf);
    WriteFindings(W, AResult);
    W.EndElement;
    W.EndDocument;
  except
    W.Free;
    raise;
  end;
  Result := W;
end;

procedure TLandrixEInvoiceValidationReportWriter.WriteToStream(AResult: TLandrixEInvoiceDocumentValidation;
  AStream: TStream);
var
  W: TObject;
begin
  W := Build(AResult);
  try
    TLandrixXmlWriter(W).SaveToStream(AStream);
  finally
    W.Free;
  end;
end;

procedure TLandrixEInvoiceValidationReportWriter.SaveToFile(AResult: TLandrixEInvoiceDocumentValidation;
  const AFileName: string);
var
  W: TObject;
begin
  W := Build(AResult);
  try
    TLandrixXmlWriter(W).SaveToFile(AFileName);
  finally
    W.Free;
  end;
end;

end.
