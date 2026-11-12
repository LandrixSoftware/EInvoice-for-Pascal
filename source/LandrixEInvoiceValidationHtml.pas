{
  EInvoice-for-Pascal

  Copyright (C) 2026 Landrix Software GmbH & Co. KG

  This file is dual-licensed under:
  - GNU GPL version 3 or later; or
  - the Landrix Software Commercial License.

  See LICENSE and COMMERCIAL-LICENSE.md.

  SPDX-License-Identifier: GPL-3.0-or-later OR LicenseRef-Landrix-Commercial
}

{ Writes the result of a validation (LandrixEInvoiceValidation) as one HTML
  page to read and print: the verdict, the document, every part with its
  status, the PDF facts and the findings in the order of the result. The
  page is self-contained (CSS inline, no script, nothing loaded from
  elsewhere) and also well-formed XML (polyglot HTML5, UTF-8). Labels in
  English or German; the texts of the findings stay as the rule sets
  write them. No timestamp: the same result gives the same bytes.
  Characters XML does not allow are replaced by U+FFFD
  (LandrixEInvoiceReportSanitize, LandrixEInvoiceReportHtml) and the page
  says so.
  DE: Schreibt das Ergebnis einer Pruefung (LandrixEInvoiceValidation) als
  eine HTML-Seite zum Lesen und Drucken: das Urteil, das Dokument, jeden
  Teil mit seinem Status, die PDF-Fakten und die Befunde in der
  Reihenfolge des Ergebnisses. Die Seite steht fuer sich (CSS eingebettet,
  kein Skript, nichts wird nachgeladen) und ist zugleich wohlgeformtes XML
  (polyglottes HTML5, UTF-8). Beschriftungen englisch oder deutsch; die
  Texte der Befunde bleiben, wie die Regelwerke sie schreiben. Kein
  Zeitstempel: dasselbe Ergebnis ergibt dieselben Bytes. Zeichen, die XML
  nicht erlaubt, werden durch U+FFFD ersetzt
  (LandrixEInvoiceReportSanitize, LandrixEInvoiceReportHtml), und die Seite
  sagt es. }

{ API: internal. May change in any release; use the facade LandrixEInvoice
  or the stable units instead.
  DE: API: intern. Kann sich in jeder Version aendern; stattdessen die
  Fassade LandrixEInvoice oder die stabilen Units verwenden. }

unit LandrixEInvoiceValidationHtml;

{$I LandrixEInvoice.inc}

interface

uses
  Classes,
  LandrixEInvoiceTypes,
  LandrixEInvoiceReportHtml,
  LandrixEInvoiceValidation;

type
  { Writes validation reports as HTML.
    DE: Schreibt Pruefberichte als HTML. }
  TLandrixEInvoiceValidationHtmlWriter = class(TObject)
  private
    FDocumentName: TLandrixEInvoiceString;
    FLanguage: TLandrixEInvoiceReportLanguage;
    function Build(AResult: TLandrixEInvoiceDocumentValidation): TMemoryStream;
  public
    { Writes the page of AResult to AStream at its position. The page is
      built in memory first: if it raises, nothing is written. AResult nil
      raises ELandrixEInvoiceError.
      DE: Schreibt die Seite zu AResult an der Position von AStream. Die
      Seite entsteht zuerst im Speicher: loest sie eine Ausnahme aus, wird
      nichts geschrieben. AResult nil loest ELandrixEInvoiceError aus. }
    procedure WriteToStream(AResult: TLandrixEInvoiceDocumentValidation; AStream: TStream);
    { The same into a file (created or overwritten).
      DE: Dasselbe in eine Datei (angelegt oder ueberschrieben). }
    procedure SaveToFile(AResult: TLandrixEInvoiceDocumentValidation; const AFileName: string);
    { The name of the document as the page shows it, '' (the default) for
      none. The caller chooses it; the result does not know it.
      DE: Der Name des Dokuments, wie die Seite ihn zeigt, '' (Vorgabe) fuer
      keinen. Der Aufrufer waehlt ihn; das Ergebnis kennt ihn nicht. }
    property DocumentName: TLandrixEInvoiceString read FDocumentName write FDocumentName;
    { The language of the labels (default eln_English).
      DE: Die Sprache der Beschriftungen (Vorgabe eln_English). }
    property Language: TLandrixEInvoiceReportLanguage read FLanguage write FLanguage;
  end;

implementation

uses
  SysUtils,
  LandrixEInvoiceDiagnostics,
  LandrixEInvoice,
  LandrixEInvoicePdfCheck;

type
  TLabel = (lbTitle, lbVerdict, lbDocument, lbName, lbSource, lbRootName, lbSyntax, lbCustomizationId,
    lbProfileId, lbSpecification, lbLibraryRelease, lbUsesExtension, lbYes, lbNo, lbParts, lbPart, lbStatus,
    lbDetails, lbConfiguration, lbScenario, lbChoice, lbPdf, lbHybridKind, lbFactsChecked, lbProfile, lbPdfVersion,
    lbCatalogVersion, lbInvoiceFile, lbInvoicePath, lbRelationship, lbXmpDocumentType, lbXmpDocumentFileName,
    lbXmpVersion, lbXmpConformanceLevel, lbXmpPdfA, lbFindings, lbSeverity, lbRule, lbStep, lbPosition,
    lbLocation, lbText, lbNoFindings, lbErrors, lbWarnings, lbInfos, lbError1, lbWarning1, lbInfo1,
    lbPredictedCount, lbPredicted,
    lbPredictedNote, lbLine, lbColumn, lbInInvoice, lbInXmp, lbSanitizedNote, lbGenerator);

const
  { HTML snippets, ASCII with character references; written as they are }
  Labels: array[TLandrixEInvoiceReportLanguage, TLabel] of AnsiString = (
    ('Validation report', 'Verdict', 'Document', 'Name', 'Source', 'Root element', 'Syntax',
     'Specification identifier (BT-24)', 'Business process (BT-23)', 'Specification', 'Library release',
     'Uses the extension', 'yes', 'no', 'Parts', 'Part', 'Status', 'Details', 'Configuration', 'Scenario',
     'Chosen', 'PDF', 'Hybrid kind', 'Facts checked', 'Profile', 'PDF version', 'Catalog version', 'Invoice file',
     'Place in the PDF', 'Relationship (/AFRelationship)', 'XMP document type', 'XMP file name', 'XMP version',
     'XMP conformance level', 'PDF/A claimed by the XMP', 'Findings', 'Severity', 'Rule', 'Step', 'Position',
     'Location', 'Text', 'No findings.', 'errors', 'warnings', 'infos', 'error', 'warning', 'info', 'predicted',
     'predicted',
     'Predicted: the library''s own rule check predicts what KoSIT would report. It does not decide the ' +
     'verdict and is not counted with the errors, warnings and infos.', 'line', 'column', 'in the invoice',
     'in the XMP metadata', 'Characters that XML does not allow were replaced by U+FFFD.', 'Written by'),
    ('Pr&#252;fbericht', 'Urteil', 'Dokument', 'Name', 'Herkunft', 'Wurzelelement', 'Syntax',
     'Spezifikationskennung (BT-24)', 'Gesch&#228;ftsprozess (BT-23)', 'Spezifikation', 'Stand der Bibliothek',
     'Nutzt die Extension', 'ja', 'nein', 'Teile', 'Teil', 'Status', 'Einzelheiten', 'Konfiguration', 'Szenario',
     'Gew&#228;hlt', 'PDF', 'Hybridart', 'Fakten gepr&#252;ft', 'Profil', 'PDF-Version', 'Katalog-Version', 'Rechnungsdatei',
     'Ort im PDF', 'Beziehung (/AFRelationship)', 'XMP-Dokumentart', 'XMP-Dateiname', 'XMP-Version',
     'XMP-Konformit&#228;tsstufe', 'PDF/A laut XMP', 'Befunde', 'Schweregrad', 'Regel', 'Schritt', 'Position',
     'Ort', 'Text', 'Keine Befunde.', 'Fehler', 'Warnungen', 'Hinweise', 'Fehler', 'Warnung', 'Hinweis',
     'vorhergesagt', 'vorhergesagt',
     'Vorhergesagt: Die eigene Regelpr&#252;fung der Bibliothek sagt voraus, was KoSIT melden w&#252;rde. ' +
     'Sie entscheidet nicht &#252;ber das Urteil und z&#228;hlt nicht zu Fehlern, Warnungen und Hinweisen.',
     'Zeile', 'Spalte', 'in der Rechnung', 'in den XMP-Metadaten',
     'Zeichen, die XML nicht erlaubt, wurden durch U+FFFD ersetzt.', 'Erstellt mit'));

  VerdictLabels: array[TLandrixEInvoiceReportLanguage, TLandrixEInvoiceVerdict] of AnsiString = (
    ('Accepted', 'Rejected', 'Incomplete'),
    ('Angenommen', 'Abgelehnt', 'Unvollst&#228;ndig'));
  PartLabels: array[TLandrixEInvoiceReportLanguage, TLandrixEInvoiceValidationPart] of AnsiString = (
    ('Reading', 'KoSIT', 'Rule check (prediction)', 'PDF embedding (level 2)', 'PDF metadata, XMP (level 3)',
     'PDF/A (level 1)'),
    ('Lesen', 'KoSIT', 'Regelpr&#252;fung (Vorhersage)', 'PDF-Einbettung (Ebene 2)',
     'PDF-Metadaten, XMP (Ebene 3)', 'PDF/A (Ebene 1)'));
  { How the configuration was chosen; precedence: text, number of
    candidates, ChoiceTail.
    DE: Wie die Konfiguration gewaehlt wurde; Vorrang: Text, Zahl der
    Kandidaten, ChoiceTail. }
  ChoiceLabels: array[TLandrixEInvoiceReportLanguage, TLandrixEInvoiceConfigurationChoice] of AnsiString = (
    ('', 'given by the caller', 'automatically, the only matching configuration',
     'automatically, by precedence among ', 'no registered configuration has exactly one matching scenario'),
    ('', 'vom Aufrufer vorgegeben', 'automatisch, die einzige passende Konfiguration',
     'automatisch, nach Vorrang unter ', 'keine registrierte Konfiguration hat genau ein passendes Szenario'));
  ChoiceTail: array[TLandrixEInvoiceReportLanguage] of AnsiString = (' matching configurations',
    ' passenden Konfigurationen');
  KindLabels: array[TLandrixEInvoiceReportLanguage, TLandrixEInvoiceConfigurationKind] of AnsiString = (
    ('other', 'XRechnung', 'ZUGFeRD', 'Peppol BIS'),
    ('andere', 'XRechnung', 'ZUGFeRD', 'Peppol BIS'));
  StatusLabels: array[TLandrixEInvoiceReportLanguage, TLandrixEInvoicePartStatus] of AnsiString = (
    ('not run', 'passed', 'failed', 'incomplete'),
    ('nicht gelaufen', 'bestanden', 'fehlgeschlagen', 'unvollst&#228;ndig'));
  SeverityLabels: array[TLandrixEInvoiceReportLanguage, TLandrixEInvoiceDiagnosticSeverity] of AnsiString = (
    ('info', 'warning', 'error'),
    ('Hinweis', 'Warnung', 'Fehler'));
  StepLabels: array[TLandrixEInvoiceReportLanguage, TLandrixEInvoiceFindingStep] of AnsiString = (
    ('', 'well-formedness', 'XML schema', 'Schematron'),
    ('', 'Wohlgeformtheit', 'XML-Schema', 'Schematron'));
  SourceLabels: array[TLandrixEInvoiceReportLanguage, TLandrixEInvoiceSource] of AnsiString = (
    ('XML', 'PDF (hybrid invoice)'),
    ('XML', 'PDF (hybride Rechnung)'));
  HybridKindLabels: array[TLandrixEInvoiceReportLanguage, TLandrixEInvoicePdfHybridKind] of AnsiString = (
    ('no invoice found', 'Factur-X / ZUGFeRD 2.1 or later', 'XRechnung', 'ZUGFeRD 2.0', 'ZUGFeRD 1.0'),
    ('keine Rechnung gefunden', 'Factur-X / ZUGFeRD ab 2.1', 'XRechnung', 'ZUGFeRD 2.0', 'ZUGFeRD 1.0'));
  VerdictClasses: array[TLandrixEInvoiceVerdict] of AnsiString = ('accepted', 'rejected', 'incomplete');
  StatusClasses: array[TLandrixEInvoicePartStatus] of AnsiString = ('notrun', 'passed', 'failed', 'incomplete');
  SeverityClasses: array[TLandrixEInvoiceDiagnosticSeverity] of AnsiString = ('info', 'warning', 'error');
  LanguageCodes: array[TLandrixEInvoiceReportLanguage] of AnsiString = ('en', 'de');
  SyntaxNames: array[TLandrixEInvoiceSyntax] of AnsiString = ('', 'UBL', 'CII');
  StandardNames: array[TLandrixEInvoiceStandard] of AnsiString = ('', 'XRechnung', 'Factur-X / ZUGFeRD',
    'Peppol BIS');
  ProfileNames: array[TLandrixEInvoiceProfile] of AnsiString = ('', 'MINIMUM', 'BASIC WL', 'BASIC', 'EN 16931',
    'EXTENDED', 'XRECHNUNG');

  Css =
    'body{font-family:system-ui,-apple-system,"Segoe UI",Roboto,Arial,sans-serif;margin:2em auto;' +
    'max-width:72em;padding:0 1em;color:#1a1a1a;background:#fff;line-height:1.4}' +
    'h1{font-size:1.6em;margin:0 0 .3em}' +
    'h2{font-size:1.2em;margin:1.6em 0 .5em;border-bottom:1px solid #ccc}' +
    'table{border-collapse:collapse;width:100%}' +
    'th,td{text-align:left;vertical-align:top;padding:.3em .6em;border-bottom:1px solid #e3e3e3}' +
    'table.facts th{width:18em;font-weight:600}' +
    '.document{font-size:1.1em;margin:0 0 .5em;word-break:break-all}' +
    '.verdict{display:inline-block;padding:.3em .8em;border-radius:.3em;font-weight:700}' +
    '.v-accepted{background:#dff3e2;color:#14532d}' +
    '.v-rejected{background:#fde2e1;color:#7f1d1d}' +
    '.v-incomplete{background:#fff3cd;color:#713f12}' +
    '.s-passed{color:#15803d}.s-failed{color:#b91c1c;font-weight:600}' +
    '.s-incomplete{color:#a16207;font-weight:600}.s-notrun{color:#6b7280}' +
    'td.sev-error{color:#b91c1c;font-weight:600}td.sev-warning{color:#a16207}td.sev-info{color:#374151}' +
    'tr.predicted td{font-style:italic;color:#4b5563}' +
    'td.text{white-space:pre-wrap}' +
    'td.loc{font-family:ui-monospace,Consolas,monospace;font-size:.9em;word-break:break-all}' +
    '.note,footer{color:#6b7280;font-size:.9em}' +
    'footer{margin-top:2em}' +
    '@media print{body{margin:0;max-width:none}.verdict{border:1px solid #888}}';

type
  { the page under construction, with the labels of this report }
  TPage = class(TLandrixEInvoiceHtmlBuilder)
  public
    { a label in the page's language }
    procedure Lbl(ALabel: TLabel);
    { "1 error", "2 errors" }
    procedure Count(AValue: Integer; AOne, AMany: TLabel);
    { a row of a facts table; omitted when AValue is empty }
    procedure Fact(ALabel: TLabel; const AValue: TLandrixEInvoiceString);
    procedure FactRaw(ALabel: TLabel; const AHtml: AnsiString);
  end;

procedure TPage.Lbl(ALabel: TLabel);
begin
  Raw(Labels[Language, ALabel]);
end;

procedure TPage.Count(AValue: Integer; AOne, AMany: TLabel);
begin
  Int(AValue);
  Raw(' ');
  if AValue = 1 then
    Lbl(AOne)
  else
    Lbl(AMany);
end;

procedure TPage.Fact(ALabel: TLabel; const AValue: TLandrixEInvoiceString);
begin
  if AValue = '' then
    Exit;
  Raw('<tr><th>');
  Lbl(ALabel);
  Raw('</th><td>');
  Text(AValue);
  Raw('</td></tr>'#10);
end;

procedure TPage.FactRaw(ALabel: TLabel; const AHtml: AnsiString);
begin
  if AHtml = '' then
    Exit;
  Raw('<tr><th>');
  Lbl(ALabel);
  Raw('</th><td>');
  Raw(AHtml);
  Raw('</td></tr>'#10);
end;

procedure WriteDocument(P: TPage; AResult: TLandrixEInvoiceDocumentValidation);
var
  Info: TLandrixEInvoiceDocumentInfo;
begin
  Info := AResult.Info;
  P.Raw('<section><h2>');
  P.Lbl(lbDocument);
  P.Raw('</h2>'#10'<table class="facts">'#10);
  P.FactRaw(lbSource, SourceLabels[P.Language, Info.Source]);
  P.Fact(lbRootName, Info.RootName);
  P.FactRaw(lbSyntax, SyntaxNames[Info.Syntax]);
  P.Fact(lbCustomizationId, Info.CustomizationID);
  P.Fact(lbProfileId, Info.ProfileID);
  { the specification the library assigns to BT-24; ExactVersion is the
    release the library is built for, not the one of the sender
    DE: die Spezifikation, die die Bibliothek BT-24 zuordnet; ExactVersion
    ist der Stand, fuer den die Bibliothek gebaut ist, nicht der des
    Absenders }
  if Info.SpecFound then
  begin
    P.Raw('<tr><th>');
    P.Lbl(lbSpecification);
    P.Raw('</th><td>' + StandardNames[Info.Spec.Target.Standard]);
    if Info.Spec.Target.Version <> '' then
    begin
      P.Raw(' ');
      P.Text(Info.Spec.Target.Version);
    end;
    if Info.Spec.Target.Profile <> epr_None then
      P.Raw(', ' + ProfileNames[Info.Spec.Target.Profile]);
    P.Raw(' (' + SyntaxNames[Info.Spec.Target.Syntax] + ')</td></tr>'#10);
    P.Fact(lbLibraryRelease, Info.Spec.ExactVersion);
    if Info.UsesExtension then
      P.FactRaw(lbUsesExtension, Labels[P.Language, lbYes]);
  end;
  P.Raw('</table></section>'#10);
end;

procedure WriteParts(P: TPage; AResult: TLandrixEInvoiceDocumentValidation);
var
  Part: TLandrixEInvoiceValidationPart;
  Status: TLandrixEInvoicePartStatus;
begin
  P.Raw('<section><h2>');
  P.Lbl(lbParts);
  P.Raw('</h2>'#10'<table class="parts"><thead><tr><th>');
  P.Lbl(lbPart);
  P.Raw('</th><th>');
  P.Lbl(lbStatus);
  P.Raw('</th><th>');
  P.Lbl(lbDetails);
  P.Raw('</th></tr></thead><tbody>'#10);
  for Part := Low(TLandrixEInvoiceValidationPart) to High(TLandrixEInvoiceValidationPart) do
  begin
    Status := AResult.Status[Part];
    P.Raw('<tr><td>');
    P.Raw(PartLabels[P.Language, Part]);
    P.Raw('</td><td class="s-' + StatusClasses[Status] + '">');
    P.Raw(StatusLabels[P.Language, Status]);
    P.Raw('</td><td>');
    if Part = evp_KoSIT then
    begin
      if AResult.ConfigurationName <> '' then
      begin
        P.Lbl(lbConfiguration);
        P.Raw(': ');
        P.Text(AResult.ConfigurationName);
        if AResult.ScenarioName <> '' then
          P.Raw('<br/>');
      end;
      if AResult.ScenarioName <> '' then
      begin
        P.Lbl(lbScenario);
        P.Raw(': ');
        P.Text(AResult.ScenarioName);
      end;
      { an automatic choice; a configuration given by the caller is not
        mentioned (the page stays as before) }
      if AResult.ConfigurationChoice in [ecc_OnlyMatch, ecc_Precedence, ecc_NoMatch] then
      begin
        if (AResult.ConfigurationName <> '') or (AResult.ScenarioName <> '') then
          P.Raw('<br/>');
        P.Lbl(lbChoice);
        P.Raw(': ');
        P.Raw(ChoiceLabels[P.Language, AResult.ConfigurationChoice]);
        if AResult.ConfigurationChoice = ecc_Precedence then
        begin
          P.Int(AResult.CandidateCount);
          P.Raw(ChoiceTail[P.Language]);
        end;
        if AResult.ConfigurationChoice <> ecc_NoMatch then
          P.Raw(' (' + KindLabels[P.Language, AResult.ConfigurationKind] + ')');
      end;
    end;
    P.Raw('</td></tr>'#10);
  end;
  P.Raw('</tbody></table></section>'#10);
end;

procedure WritePdf(P: TPage; APdf: TLandrixEInvoicePdfCheckResult);
begin
  P.Raw('<section><h2>');
  P.Lbl(lbPdf);
  P.Raw('</h2>'#10'<table class="facts">'#10);
  P.FactRaw(lbHybridKind, HybridKindLabels[P.Language, APdf.HybridKind]);
  if APdf.FactsChecked then
  begin
    P.FactRaw(lbFactsChecked, Labels[P.Language, lbYes]);
    P.FactRaw(lbProfile, ProfileNames[APdf.Profile]);
  end
  else
    P.FactRaw(lbFactsChecked, Labels[P.Language, lbNo]);
  P.Fact(lbPdfVersion, APdf.PdfVersion);
  P.Fact(lbCatalogVersion, APdf.CatalogVersion);
  P.Fact(lbInvoiceFile, APdf.InvoiceFileName);
  P.Fact(lbInvoicePath, APdf.InvoicePath);
  P.Fact(lbRelationship, APdf.InvoiceRelationship);
  P.Fact(lbXmpDocumentType, APdf.XmpDocumentType);
  P.Fact(lbXmpDocumentFileName, APdf.XmpDocumentFileName);
  P.Fact(lbXmpVersion, APdf.XmpVersion);
  P.Fact(lbXmpConformanceLevel, APdf.XmpConformanceLevel);
  { the two XMP values as written, not a PDF/A check
    DE: die beiden XMP-Werte wie geschrieben, keine PDF/A-Pruefung }
  if (APdf.PdfAPart <> '') or (APdf.PdfAConformance <> '') then
  begin
    P.Raw('<tr><th>');
    P.Lbl(lbXmpPdfA);
    P.Raw('</th><td>');
    if APdf.PdfAPart <> '' then
    begin
      P.Raw('pdfaid:part ');
      P.Text(APdf.PdfAPart);
    end;
    if APdf.PdfAConformance <> '' then
    begin
      if APdf.PdfAPart <> '' then
        P.Raw(', ');
      P.Raw('pdfaid:conformance ');
      P.Text(APdf.PdfAConformance);
    end;
    P.Raw('</td></tr>'#10);
  end;
  P.Raw('</table></section>'#10);
end;

procedure WriteFindings(P: TPage; AResult: TLandrixEInvoiceDocumentValidation);
var
  I, Predicted: Integer;
  F: TLandrixEInvoiceFinding;
  Counts: array[TLandrixEInvoiceDiagnosticSeverity] of Integer;
  S: TLandrixEInvoiceDiagnosticSeverity;
begin
  for S := Low(TLandrixEInvoiceDiagnosticSeverity) to High(TLandrixEInvoiceDiagnosticSeverity) do
    Counts[S] := 0;
  Predicted := 0;
  for I := 0 to AResult.FindingCount - 1 do
    if AResult[I].Predicted then
      Inc(Predicted)
    else
      Inc(Counts[AResult[I].Severity]);
  P.Raw('<section><h2>');
  P.Lbl(lbFindings);
  P.Raw('</h2>'#10);
  if AResult.FindingCount = 0 then
  begin
    P.Raw('<p>');
    P.Lbl(lbNoFindings);
    P.Raw('</p></section>'#10);
    Exit;
  end;
  P.Raw('<p class="counts">');
  P.Count(Counts[eds_Error], lbError1, lbErrors);
  P.Raw(', ');
  P.Count(Counts[eds_Warning], lbWarning1, lbWarnings);
  P.Raw(', ');
  P.Count(Counts[eds_Info], lbInfo1, lbInfos);
  P.Raw(', ');
  P.Int(Predicted);
  P.Raw(' ');
  P.Lbl(lbPredictedCount);
  P.Raw('</p>'#10'<table class="findings"><thead><tr><th>');
  P.Lbl(lbPart);
  P.Raw('</th><th>');
  P.Lbl(lbSeverity);
  P.Raw('</th><th>');
  P.Lbl(lbRule);
  P.Raw('</th><th>');
  P.Lbl(lbPosition);
  P.Raw('</th><th>');
  P.Lbl(lbLocation);
  P.Raw('</th><th>');
  P.Lbl(lbText);
  P.Raw('</th></tr></thead><tbody>'#10);
  for I := 0 to AResult.FindingCount - 1 do
  begin
    F := AResult[I];
    if F.Predicted then
      P.Raw('<tr class="predicted"><td>')
    else
      P.Raw('<tr><td>');
    P.Raw(PartLabels[P.Language, F.Part]);
    if F.Step <> efs_None then
    begin
      P.Raw('<br/>');
      P.Lbl(lbStep);
      P.Raw(': ');
      P.Raw(StepLabels[P.Language, F.Step]);
    end;
    P.Raw('</td><td class="sev-' + SeverityClasses[F.Severity] + '">');
    P.Raw(SeverityLabels[P.Language, F.Severity]);
    if F.Predicted then
    begin
      P.Raw(' (');
      P.Lbl(lbPredicted);
      P.Raw(')');
    end;
    P.Raw('</td><td>');
    P.Text(F.RuleID);
    P.Raw('</td><td>');
    if F.Line > 0 then
    begin
      P.Lbl(lbLine);
      P.Raw(' ');
      P.Int(F.Line);
      if F.Column > 0 then
      begin
        P.Raw(', ');
        P.Lbl(lbColumn);
        P.Raw(' ');
        P.Int(F.Column);
      end;
      P.Raw('<br/>');
      { level 3 counts in the XMP packet, everything else in the invoice
        XML
        DE: Ebene 3 zaehlt im XMP-Paket, alles andere in der
        Rechnungs-XML }
      if F.Part = evp_PdfMetadata then
        P.Lbl(lbInXmp)
      else
        P.Lbl(lbInInvoice);
    end;
    P.Raw('</td><td class="loc">');
    P.Text(F.Location);
    P.Raw('</td><td class="text">');
    P.Text(F.Text);
    P.Raw('</td></tr>'#10);
  end;
  P.Raw('</tbody></table>'#10);
  if Predicted > 0 then
  begin
    P.Raw('<p class="note">');
    P.Lbl(lbPredictedNote);
    P.Raw('</p>'#10);
  end;
  P.Raw('</section>'#10);
end;

{ --- TLandrixEInvoiceValidationHtmlWriter -------------------------------- }

function TLandrixEInvoiceValidationHtmlWriter.Build(AResult: TLandrixEInvoiceDocumentValidation): TMemoryStream;
var
  P: TPage;
begin
  if AResult = nil then
    raise ELandrixEInvoiceError.Create('No validation result to report');
  Result := TMemoryStream.Create;
  P := nil;
  try
    P := TPage.Create(Result, FLanguage);
    P.Raw('<!DOCTYPE html>'#10'<html xmlns="http://www.w3.org/1999/xhtml" lang="' + LanguageCodes[FLanguage] +
      '">'#10'<head>'#10'<meta charset="utf-8"/>'#10 +
      '<meta name="viewport" content="width=device-width, initial-scale=1"/>'#10'<title>');
    P.Lbl(lbTitle);
    if FDocumentName <> '' then
    begin
      P.Raw(': ');
      P.Text(FDocumentName);
    end;
    P.Raw('</title>'#10'<style>' + Css + '</style>'#10'</head>'#10'<body>'#10'<header><h1>');
    P.Lbl(lbTitle);
    P.Raw('</h1>'#10);
    if FDocumentName <> '' then
    begin
      P.Raw('<p class="document">');
      P.Text(FDocumentName);
      P.Raw('</p>'#10);
    end;
    P.Raw('<p class="verdict v-' + VerdictClasses[AResult.Verdict] + '">');
    P.Lbl(lbVerdict);
    P.Raw(': ');
    P.Raw(VerdictLabels[FLanguage, AResult.Verdict]);
    P.Raw('</p></header>'#10);
    WriteDocument(P, AResult);
    WriteParts(P, AResult);
    if AResult.Pdf <> nil then
      WritePdf(P, AResult.Pdf);
    WriteFindings(P, AResult);
    P.Raw('<footer>');
    if P.Sanitized then
    begin
      P.Raw('<p class="note">');
      P.Lbl(lbSanitizedNote);
      P.Raw('</p>');
    end;
    P.Raw('<p>');
    P.Lbl(lbGenerator);
    P.Raw(' EInvoice-for-Pascal ' + LandrixEInvoiceVersion + '</p></footer>'#10'</body>'#10'</html>'#10);
  except
    P.Free;
    Result.Free;
    raise;
  end;
  P.Free;
  Result.Position := 0;
end;

procedure TLandrixEInvoiceValidationHtmlWriter.WriteToStream(AResult: TLandrixEInvoiceDocumentValidation;
  AStream: TStream);
var
  Page: TMemoryStream;
begin
  Page := Build(AResult);
  try
    if Page.Size > 0 then
      AStream.WriteBuffer(Page.Memory^, Integer(Page.Size));
  finally
    Page.Free;
  end;
end;

procedure TLandrixEInvoiceValidationHtmlWriter.SaveToFile(AResult: TLandrixEInvoiceDocumentValidation;
  const AFileName: string);
var
  Page: TMemoryStream;
begin
  Page := Build(AResult);
  try
    Page.SaveToFile(AFileName);
  finally
    Page.Free;
  end;
end;

end.
