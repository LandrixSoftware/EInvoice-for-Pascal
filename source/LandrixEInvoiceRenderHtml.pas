{
  EInvoice-for-Pascal

  Copyright (C) 2026 Landrix Software GmbH & Co. KG

  This file is dual-licensed under:
  - GNU GPL version 3 or later; or
  - the Landrix Software Commercial License.

  See LICENSE and COMMERCIAL-LICENSE.md.

  SPDX-License-Identifier: GPL-3.0-or-later OR LicenseRef-Landrix-Commercial
}

{ An invoice as an HTML page for people: one self-contained page (inline
  CSS, no script, nothing loaded, no links), HTML5 that is also well-formed
  XML, UTF-8, labels in English or German. The page shows what the invoice
  holds and computes nothing: every set field appears once, in the section
  LandrixEInvoiceRenderSection assigns to it, in an element marked with its
  model path (data-field) and business term (data-bt); sections and groups
  without content are left out, list items are always shown; a scheme
  identifier appears only with its identifier (the model presets some, and
  the writers write a scheme only as part of its identifier). Sub lines are
  nested in their line. Attachments are listed with their facts, never with
  their data. With a read document the page also shows where it came from
  and what reading did not take over into the model. No time stamp: the
  same invoice gives the same bytes. Characters XML does not allow become
  U+FFFD, and the page says so.
  DE: Eine Rechnung als HTML-Seite fuer Menschen: eine eigenstaendige Seite
  (CSS eingebettet, kein Skript, nichts nachgeladen, keine Links), HTML5,
  das zugleich wohlgeformtes XML ist, UTF-8, Beschriftungen englisch oder
  deutsch. Die Seite zeigt, was die Rechnung enthaelt, und rechnet nichts:
  jedes gesetzte Feld erscheint einmal, in dem Abschnitt, den
  LandrixEInvoiceRenderSection ihm zuordnet, in einem Element mit seinem
  Modellpfad (data-field) und Geschaeftsbegriff (data-bt); Abschnitte und
  Gruppen ohne Inhalt entfallen, Listeneintraege erscheinen immer; eine
  Schemakennung erscheint nur mit ihrer Kennung (das Modell belegt einige
  vor, und die Writer schreiben ein Schema nur als Teil seiner Kennung).
  Unterpositionen stehen verschachtelt in ihrer Position. Anhaenge erscheinen
  mit ihren Angaben, nie mit ihren Daten. Mit einem gelesenen Dokument zeigt
  die Seite auch, woher es kam und was das Lesen nicht in das Modell
  uebernommen hat. Kein Zeitstempel: dieselbe Rechnung ergibt dieselben
  Bytes. Zeichen, die XML nicht erlaubt, werden U+FFFD, und die Seite sagt
  es. }

{ API: internal. May change in any release; use the facade LandrixEInvoice
  or the stable units instead.
  DE: API: intern. Kann sich in jeder Version aendern; stattdessen die
  Fassade LandrixEInvoice oder die stabilen Units verwenden. }

unit LandrixEInvoiceRenderHtml;

{$I LandrixEInvoice.inc}

interface

uses
  Classes,
  LandrixEInvoiceTypes,
  LandrixEInvoiceReportHtml,
  LandrixEInvoiceInvoice,
  LandrixEInvoice;

type
  { Writes invoices as HTML pages.
    DE: Schreibt Rechnungen als HTML-Seiten. }
  TLandrixEInvoiceRenderHtmlWriter = class(TObject)
  private
    FDocumentName: TLandrixEInvoiceString;
    FLanguage: TLandrixEInvoiceReportLanguage;
    FShowBusinessTerms: Boolean;
    function Build(AInvoice: TLandrixInvoice; ADocument: TLandrixEInvoiceDocument): TMemoryStream;
  public
    { Writes the page of AInvoice to AStream at its position. The page is
      built in memory first: if it raises, nothing is written. AInvoice nil
      raises ELandrixEInvoiceError.
      DE: Schreibt die Seite zu AInvoice an der Position von AStream. Die
      Seite entsteht zuerst im Speicher: loest sie eine Ausnahme aus, wird
      nichts geschrieben. AInvoice nil loest ELandrixEInvoiceError aus. }
    procedure WriteToStream(AInvoice: TLandrixInvoice; AStream: TStream); overload;
    { The same for a read document: its invoice, plus where it came from and
      what reading did not take over (unknown or repeated content, skipped
      extensions, values that could not be converted, content without a
      place in the model). A document without invoice (DetachInvoice) or nil
      raises ELandrixEInvoiceError.
      DE: Dasselbe fuer ein gelesenes Dokument: seine Rechnung, dazu woher es
      kam und was das Lesen nicht uebernommen hat (unbekannter oder
      wiederholter Inhalt, uebersprungene Erweiterungen, nicht umwandelbare
      Werte, Inhalt ohne Platz im Modell). Ein Dokument ohne Rechnung
      (DetachInvoice) oder nil loest ELandrixEInvoiceError aus. }
    procedure WriteToStream(ADocument: TLandrixEInvoiceDocument; AStream: TStream); overload;
    { The page of AInvoice into a file (created or overwritten).
      DE: Die Seite zu AInvoice in eine Datei (angelegt oder
      ueberschrieben). }
    procedure SaveToFile(AInvoice: TLandrixInvoice; const AFileName: string); overload;
    { The page of a read document into a file (created or overwritten).
      DE: Die Seite zu einem gelesenen Dokument in eine Datei (angelegt
      oder ueberschrieben). }
    procedure SaveToFile(ADocument: TLandrixEInvoiceDocument; const AFileName: string); overload;
    { The name of the document as the page shows it, '' (the default) for
      none. The caller chooses it; the invoice does not know it.
      DE: Der Name des Dokuments, wie die Seite ihn zeigt, '' (Vorgabe) fuer
      keinen. Der Aufrufer waehlt ihn; die Rechnung kennt ihn nicht. }
    property DocumentName: TLandrixEInvoiceString read FDocumentName write FDocumentName;
    { The language of the labels (default eln_English).
      DE: Die Sprache der Beschriftungen (Vorgabe eln_English). }
    property Language: TLandrixEInvoiceReportLanguage read FLanguage write FLanguage;
    { Show the business term (BT-/BG-) next to each label (default False).
      The page marks the terms in data-bt either way.
      DE: Den Geschaeftsbegriff (BT-/BG-) neben jeder Beschriftung zeigen
      (Vorgabe False). Die Seite kennzeichnet die Begriffe in data-bt in
      jedem Fall. }
    property ShowBusinessTerms: Boolean read FShowBusinessTerms write FShowBusinessTerms;
  end;

implementation

uses
  SysUtils,
  LandrixEInvoiceDiagnostics,
  LandrixEInvoiceCodes,
  LandrixEInvoiceCodeNames,
  LandrixEInvoiceRender,
  LandrixEInvoiceRenderLabels;

type
  TLabel = (lbTitle, lbCreditNote, lbYes, lbNo, lbAllowance, lbCharge, lbBytes, lbDocument, lbSource, lbRootName,
    lbSyntax, lbCustomizationId, lbSpecification, lbPdfAttachment, lbNotTakenOver, lbNothingLeftOut, lbKind,
    lbPosition, lbPath, lbMessage, lbLine, lbColumn, lbSanitizedNote, lbGenerator);

const
  { HTML snippets, ASCII with character references; written as they are }
  Labels: array[TLandrixEInvoiceReportLanguage, TLabel] of AnsiString = (
    ('Invoice', 'Credit note', 'yes', 'no', 'Allowance', 'Charge', 'bytes', 'Document', 'Source', 'Root element',
     'Syntax', 'Specification identifier (BT-24)', 'Specification', 'Invoice file in the PDF',
     'Not taken over when reading', 'Reading took over everything.', 'Kind', 'Location', 'Path', 'Message', 'line',
     'column',
     'Characters that XML does not allow were replaced by U+FFFD.', 'Written by'),
    ('Rechnung', 'Gutschrift', 'ja', 'nein', 'Abschlag', 'Zuschlag', 'Bytes', 'Dokument', 'Herkunft', 'Wurzelelement',
     'Syntax', 'Spezifikationskennung (BT-24)', 'Spezifikation', 'Rechnungsdatei im PDF',
     'Beim Lesen nicht &#252;bernommen', 'Das Lesen hat alles &#252;bernommen.', 'Art', 'Fundstelle', 'Pfad',
     'Meldung', 'Zeile', 'Spalte',
     'Zeichen, die XML nicht erlaubt, wurden durch U+FFFD ersetzt.', 'Erstellt mit'));

  { the diagnostics of reading that mean content did not reach the model;
    '' for the others (unknown codes stay in ...Other, an invalid value
    keeps its text, missing content and rule violations are the business of
    the validation)
    DE: die Lesemeldungen, bei denen Inhalt nicht ins Modell gelangte; ''
    fuer die anderen (unbekannte Codes bleiben in ...Other, ein ungueltiger
    Wert behaelt seinen Text, fehlender Inhalt und Regelverstoesse sind
    Sache der Pruefung) }
  KindLabels: array[TLandrixEInvoiceReportLanguage, TLandrixEInvoiceDiagnosticKind] of AnsiString = (
    ('Unknown element', 'Repeated element', 'Unexpected text', 'Unknown attribute', '', '',
     'Skipped extension', 'Value not convertible', '', 'No place in the invoice model', '', ''),
    ('Unbekanntes Element', 'Wiederholtes Element', 'Unerwarteter Text', 'Unbekanntes Attribut', '', '',
     '&#220;bersprungene Erweiterung', 'Wert nicht umwandelbar', '', 'Kein Platz im Rechnungsmodell', '', ''));

  PaymentTermsLabels: array[TLandrixEInvoiceReportLanguage, TLandrixInvoicePaymentTermsType] of AnsiString = (
    ('', 'net', 'one cash discount', 'two cash discounts', 'three cash discounts'),
    ('', 'netto', 'ein Skonto', 'zwei Skonti', 'drei Skonti'));
  LineStatusCodes: array[TLandrixInvoiceLineStatusReasonCode] of AnsiString = ('', 'DETAIL', 'GROUP',
    'INFORMATION');
  LineStatusLabels: array[TLandrixEInvoiceReportLanguage, TLandrixInvoiceLineStatusReasonCode] of AnsiString = (
    ('', 'regular line', 'group', 'information only'),
    ('', 'regul&#228;re Position', 'Gruppe', 'nur zur Information'));
  SourceLabels: array[TLandrixEInvoiceReportLanguage, TLandrixEInvoiceSource] of AnsiString = (
    ('XML', 'PDF (hybrid invoice)'),
    ('XML', 'PDF (hybride Rechnung)'));
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
    'h3{font-size:1em;margin:0 0 .4em}h4{font-size:.95em;margin:.8em 0 .3em}' +
    '.document{font-size:1.1em;margin:0 0 .5em;word-break:break-all}' +
    'dl{display:grid;grid-template-columns:minmax(10em,18em) 1fr;gap:.2em 1em;margin:0 0 .6em}' +
    'dt{font-weight:600}dd{margin:0;white-space:pre-wrap;overflow-wrap:anywhere}' +
    '.bt{font-weight:400;font-size:.8em;color:#6b7280}' +
    '.parties{display:grid;grid-template-columns:repeat(auto-fit,minmax(22em,1fr));gap:1em}' +
    '.box,.item,.line{border:1px solid #e3e3e3;border-radius:.3em;padding:.6em .8em;margin:0 0 .8em}' +
    '.box dl,.item dl{grid-template-columns:minmax(8em,14em) 1fr}' +
    'dl.head{grid-template-columns:repeat(auto-fit,minmax(9em,1fr));grid-auto-flow:row;gap:.2em 1em}' +
    'dl.head dt{grid-row:1;font-size:.85em}dl.head dd{grid-row:2}' +
    '.sublines{margin:.6em 0 0 1.2em}' +
    'table{border-collapse:collapse;width:100%;margin:0 0 .6em}' +
    'th,td{text-align:left;vertical-align:top;padding:.3em .6em;border-bottom:1px solid #e3e3e3}' +
    'td{white-space:pre-wrap;overflow-wrap:anywhere}td span+span{margin-left:.5em}' +
    '.cur{color:#374151}' +
    'td.loc{font-family:ui-monospace,Consolas,monospace;font-size:.9em;word-break:break-all}' +
    '.note,footer{color:#6b7280;font-size:.9em}footer{margin-top:2em}' +
    '@media print{body{margin:0;max-width:none}.box,.item,.line{break-inside:avoid}}';

type
  TFieldList = array of TLandrixEInvoiceRenderField;
  TTermList = array of TLandrixEInvoiceString;

  { the page under construction; openers of sections and groups wait until
    the first value below them (Push, Pop, Flush), so groups without a value
    leave nothing }
  TPage = class(TLandrixEInvoiceHtmlBuilder)
  private
    FShowBT: Boolean;
    FOpen, FClose: array of AnsiString;
    FFlushed: array of Boolean;
    FDepth: Integer;
  public
    constructor Create(AOut: TStream; ALanguage: TLandrixEInvoiceReportLanguage; AShowBT: Boolean);
    procedure Lbl(ALabel: TLabel);
    { markup that waits until a value is written below it }
    procedure Push(const AOpen, AClose: AnsiString);
    procedure Pop;
    { writes every waiting opener }
    procedure Flush;
    { the business term after a label, when shown }
    procedure Term(const ABT: TLandrixEInvoiceString);
    { data-field and data-bt attributes }
    procedure Marks(AField: TLandrixEInvoiceRenderField; const ABT: TLandrixEInvoiceString);
    { a label/value pair of a dl; nothing when AValue is '' }
    procedure Pair(AField: TLandrixEInvoiceRenderField; const AValue, ABT: TLandrixEInvoiceString);
    procedure Value(AField: TLandrixEInvoiceRenderField; const AValue: TLandrixEInvoiceString);
    { an amount with its currency; the currency is marked data-ref, it
      repeats the field ACurrencyField; nothing for 0 unless AAlways }
    procedure Money(AField: TLandrixEInvoiceRenderField; AValue: Currency; AAlways: Boolean;
      ACurrencyField: TLandrixEInvoiceRenderField; const ACurrency: TLandrixEInvoiceString);
    { a section and its heading, waiting }
    procedure OpenSection(ASection: TLandrixEInvoiceRenderSection);
    { a box of a group (party, delivery), waiting }
    procedure OpenBox(AField: TLandrixEInvoiceRenderField);
    { a list item, written at once; CloseItem ends it }
    procedure OpenItem(AField: TLandrixEInvoiceRenderField; const AClass: AnsiString);
    procedure CloseItem;
    { the heading of a list, written at once }
    procedure ListHeading(AField: TLandrixEInvoiceRenderField);
    { a table with one column per field of AColumns, labelled with the
      field; ATerms (nil, or one entry per column, '' for the term of the
      field) gives the term of a column that holds several fields }
    procedure OpenTable(const AColumns: TFieldList; const ATerms: TTermList);
    procedure CloseTable;
    { a table cell with one value, or the start/end of a cell with spans }
    procedure Cell(AField: TLandrixEInvoiceRenderField; const AValue, ABT: TLandrixEInvoiceString);
    procedure Span(AField: TLandrixEInvoiceRenderField; const AValue, ABT: TLandrixEInvoiceString);
    { values as text }
    function Amount(AValue: Currency): TLandrixEInvoiceString;
    function AmountIf(AValue: Currency): TLandrixEInvoiceString;
    function Decimal(AValue: Double; AMinDecimals: Integer): TLandrixEInvoiceString;
    function DecimalIf(AValue: Double; AMinDecimals: Integer): TLandrixEInvoiceString;
    function Percent(AValue: Double): TLandrixEInvoiceString;
    function PercentIf(AValue: Double): TLandrixEInvoiceString;
    function Date(AValue: TDateTime): TLandrixEInvoiceString;
    function Code(AList: TLandrixEInvoiceCodeList; const ACode: TLandrixEInvoiceString): TLandrixEInvoiceString;
    function YesNo(AValue: Boolean): TLandrixEInvoiceString;
    function Snippet(const AHtml: AnsiString): TLandrixEInvoiceString;
  end;

{ the text of S as escaped UTF-8 markup, for openers that wait }
function Markup(const S: TLandrixEInvoiceString): AnsiString;
var
  M: TMemoryStream;
  B: TLandrixEInvoiceHtmlBuilder;
begin
  Result := '';
  B := nil;
  M := TMemoryStream.Create;
  try
    B := TLandrixEInvoiceHtmlBuilder.Create(M, eln_English);
    B.Text(S);
    SetLength(Result, Integer(M.Size));
    if M.Size > 0 then
      Move(M.Memory^, PAnsiChar(Result)^, Integer(M.Size));
  finally
    B.Free;
    M.Free;
  end;
end;

{ ABT ('A/B') reduced to A for an allowance and B for a charge; as it is
  when it has no two parts
  DE: ABT ('A/B') auf A fuer einen Abschlag und B fuer einen Zuschlag
  verkuerzt; unveraendert, wenn es nicht zwei Teile hat }
function AllowanceOrChargeTerm(const ABT: TLandrixEInvoiceString; ACharge: Boolean): TLandrixEInvoiceString;
var
  P: Integer;
begin
  Result := ABT;
  P := Pos('/', ABT);
  if (P = 0) or (Pos('/', Copy(ABT, P + 1, MaxInt)) > 0) then
    Exit;
  if ACharge then
    Result := Copy(ABT, P + 1, MaxInt)
  else
    Result := Copy(ABT, 1, P - 1);
end;

{ the member of a structure like ATemplate (a member below ATemplateBase)
  below ABase: parties, addresses and allowances share their layout }
function Like(ABase, ATemplateBase, ATemplate: TLandrixEInvoiceRenderField): TLandrixEInvoiceRenderField;
begin
  Result := TLandrixEInvoiceRenderField(Ord(ABase) + Ord(ATemplate) - Ord(ATemplateBase));
end;

{ --- TPage ---------------------------------------------------------------- }

constructor TPage.Create(AOut: TStream; ALanguage: TLandrixEInvoiceReportLanguage; AShowBT: Boolean);
begin
  inherited Create(AOut, ALanguage);
  FShowBT := AShowBT;
end;

procedure TPage.Lbl(ALabel: TLabel);
begin
  Raw(Labels[Language, ALabel]);
end;

procedure TPage.Push(const AOpen, AClose: AnsiString);
begin
  if FDepth >= Length(FOpen) then
  begin
    SetLength(FOpen, FDepth + 8);
    SetLength(FClose, FDepth + 8);
    SetLength(FFlushed, FDepth + 8);
  end;
  FOpen[FDepth] := AOpen;
  FClose[FDepth] := AClose;
  FFlushed[FDepth] := False;
  Inc(FDepth);
end;

procedure TPage.Pop;
begin
  Dec(FDepth);
  if FFlushed[FDepth] then
    Raw(FClose[FDepth]);
end;

procedure TPage.Flush;
var
  I: Integer;
begin
  for I := 0 to FDepth - 1 do
    if not FFlushed[I] then
    begin
      Raw(FOpen[I]);
      FFlushed[I] := True;
    end;
end;

procedure TPage.Term(const ABT: TLandrixEInvoiceString);
begin
  if FShowBT and (ABT <> '') then
  begin
    Raw(' <span class="bt">');
    Text(ABT);
    Raw('</span>');
  end;
end;

procedure TPage.Marks(AField: TLandrixEInvoiceRenderField; const ABT: TLandrixEInvoiceString);
begin
  Raw(' data-field="');
  Text(LandrixEInvoiceRenderFieldPath(AField));
  Raw('"');
  if ABT <> '' then
  begin
    Raw(' data-bt="');
    Text(ABT);
    Raw('"');
  end;
end;

procedure TPage.Pair(AField: TLandrixEInvoiceRenderField; const AValue, ABT: TLandrixEInvoiceString);
begin
  if AValue = '' then
    Exit;
  Flush;
  Raw('<dt>');
  Text(LandrixEInvoiceRenderFieldLabel(AField, Language));
  Term(ABT);
  Raw('</dt><dd');
  Marks(AField, ABT);
  Raw('>');
  Text(AValue);
  Raw('</dd>'#10);
end;

procedure TPage.Value(AField: TLandrixEInvoiceRenderField; const AValue: TLandrixEInvoiceString);
begin
  Pair(AField, AValue, LandrixEInvoiceRenderFieldBT(AField));
end;

procedure TPage.Money(AField: TLandrixEInvoiceRenderField; AValue: Currency; AAlways: Boolean;
  ACurrencyField: TLandrixEInvoiceRenderField; const ACurrency: TLandrixEInvoiceString);
var
  BT: TLandrixEInvoiceString;
begin
  if (AValue = 0) and not AAlways then
    Exit;
  BT := LandrixEInvoiceRenderFieldBT(AField);
  Flush;
  Raw('<dt>');
  Text(LandrixEInvoiceRenderFieldLabel(AField, Language));
  Term(BT);
  Raw('</dt><dd');
  Marks(AField, BT);
  Raw('>');
  Text(Amount(AValue));
  if ACurrency <> '' then
  begin
    Raw(' <span class="cur" data-ref="');
    Text(LandrixEInvoiceRenderFieldPath(ACurrencyField));
    Raw('">');
    Text(ACurrency);
    Raw('</span>');
  end;
  Raw('</dd>'#10);
end;

procedure TPage.OpenSection(ASection: TLandrixEInvoiceRenderSection);
begin
  Push('<section data-section="' + Markup(LandrixEInvoiceRenderSectionKey(ASection)) + '"><h2>' +
    Markup(LandrixEInvoiceRenderSectionLabel(ASection, Language)) + '</h2>'#10, '</section>'#10);
end;

procedure TPage.OpenBox(AField: TLandrixEInvoiceRenderField);
var
  BT: TLandrixEInvoiceString;
  Open: AnsiString;
begin
  BT := LandrixEInvoiceRenderFieldBT(AField);
  Open := '<div class="box" data-field="' + Markup(LandrixEInvoiceRenderFieldPath(AField)) + '"';
  if BT <> '' then
    Open := Open + ' data-bt="' + Markup(BT) + '"';
  Open := Open + '><h3>' + Markup(LandrixEInvoiceRenderFieldLabel(AField, Language));
  if FShowBT and (BT <> '') then
    Open := Open + ' <span class="bt">' + Markup(BT) + '</span>';
  Push(Open + '</h3>'#10'<dl>'#10, '</dl></div>'#10);
end;

procedure TPage.OpenItem(AField: TLandrixEInvoiceRenderField; const AClass: AnsiString);
begin
  Flush;
  Raw('<div class="' + AClass + '"');
  Marks(AField, LandrixEInvoiceRenderFieldBT(AField));
  Raw('>'#10);
end;

procedure TPage.CloseItem;
begin
  Raw('</div>'#10);
end;

procedure TPage.ListHeading(AField: TLandrixEInvoiceRenderField);
begin
  Flush;
  Raw('<h4>');
  Text(LandrixEInvoiceRenderFieldLabel(AField, Language));
  Term(LandrixEInvoiceRenderFieldBT(AField));
  Raw('</h4>'#10);
end;

procedure TPage.OpenTable(const AColumns: TFieldList; const ATerms: TTermList);
var
  I: Integer;
begin
  Flush;
  Raw('<table><thead><tr>');
  for I := 0 to Integer(Length(AColumns)) - 1 do
  begin
    Raw('<th>');
    Text(LandrixEInvoiceRenderFieldLabel(AColumns[I], Language));
    if (I < Integer(Length(ATerms))) and (ATerms[I] <> '') then
      Term(ATerms[I])
    else
      Term(LandrixEInvoiceRenderFieldBT(AColumns[I]));
    Raw('</th>');
  end;
  Raw('</tr></thead><tbody>'#10);
end;

procedure TPage.CloseTable;
begin
  Raw('</tbody></table>'#10);
end;

procedure TPage.Cell(AField: TLandrixEInvoiceRenderField; const AValue, ABT: TLandrixEInvoiceString);
begin
  Raw('<td');
  Marks(AField, ABT);
  Raw('>');
  Text(AValue);
  Raw('</td>');
end;

procedure TPage.Span(AField: TLandrixEInvoiceRenderField; const AValue, ABT: TLandrixEInvoiceString);
begin
  if AValue = '' then
    Exit;
  Raw('<span');
  Marks(AField, ABT);
  Raw('>');
  Text(AValue);
  Raw('</span>');
end;

function TPage.Amount(AValue: Currency): TLandrixEInvoiceString;
begin
  Result := LandrixEInvoiceRenderAmount(AValue, Language);
end;

function TPage.AmountIf(AValue: Currency): TLandrixEInvoiceString;
begin
  if AValue = 0 then
    Result := ''
  else
    Result := Amount(AValue);
end;

function TPage.Decimal(AValue: Double; AMinDecimals: Integer): TLandrixEInvoiceString;
begin
  Result := LandrixEInvoiceRenderDecimal(AValue, AMinDecimals, Language);
end;

function TPage.DecimalIf(AValue: Double; AMinDecimals: Integer): TLandrixEInvoiceString;
begin
  if AValue = 0 then
    Result := ''
  else
    Result := Decimal(AValue, AMinDecimals);
end;

function TPage.Percent(AValue: Double): TLandrixEInvoiceString;
begin
  Result := LandrixEInvoiceRenderPercent(AValue, Language);
end;

function TPage.PercentIf(AValue: Double): TLandrixEInvoiceString;
begin
  if AValue = 0 then
    Result := ''
  else
    Result := Percent(AValue);
end;

function TPage.Date(AValue: TDateTime): TLandrixEInvoiceString;
begin
  if AValue = 0 then
    Result := ''
  else
    Result := LandrixEInvoiceRenderDate(AValue, Language);
end;

function TPage.Code(AList: TLandrixEInvoiceCodeList; const ACode: TLandrixEInvoiceString): TLandrixEInvoiceString;
begin
  Result := LandrixEInvoiceRenderCode(AList, ACode, Language);
end;

function TPage.YesNo(AValue: Boolean): TLandrixEInvoiceString;
begin
  if AValue then
    Result := Snippet(Labels[Language, lbYes])
  else
    Result := Snippet(Labels[Language, lbNo]);
end;

{ a label snippet as text: the character references of the tables decoded }
function TPage.Snippet(const AHtml: AnsiString): TLandrixEInvoiceString;
var
  I, J, N: Integer;
begin
  Result := '';
  I := 1;
  while I <= Length(AHtml) do
  begin
    if (AHtml[I] = '&') and (I < Length(AHtml)) and (AHtml[I + 1] = '#') then
    begin
      J := I + 2;
      N := 0;
      while (J <= Length(AHtml)) and (AHtml[J] >= '0') and (AHtml[J] <= '9') do
      begin
        N := N * 10 + Ord(AHtml[J]) - Ord('0');
        Inc(J);
      end;
      Result := Result + WideChar(N);
      I := J + 1;
    end
    else
    begin
      Result := Result + WideChar(Ord(AHtml[I]));
      Inc(I);
    end;
  end;
end;

{ --- invoice ---------------------------------------------------------------- }

function Terms(const ATerms: array of TLandrixEInvoiceString): TTermList;
var
  I: Integer;
begin
  Result := nil;
  SetLength(Result, Length(ATerms));
  for I := 0 to Integer(Length(ATerms)) - 1 do
    Result[I] := ATerms[I];
end;

function Columns(const AFields: array of TLandrixEInvoiceRenderField): TFieldList;
var
  I: Integer;
begin
  Result := nil;
  SetLength(Result, Length(AFields));
  for I := 0 to Integer(Length(AFields)) - 1 do
    Result[I] := AFields[I];
end;

procedure WriteHeader(P: TPage; AInvoice: TLandrixInvoice);
begin
  P.OpenSection(ers_Header);
  P.Push('<dl>'#10, '</dl>'#10);
  P.Value(erf_InvoiceNumber, AInvoice.InvoiceNumber);
  P.Value(erf_InvoiceIssueDate, P.Date(AInvoice.InvoiceIssueDate));
  P.Value(erf_InvoiceTypeCode, P.Code(ecl_TypeCode, LandrixEInvoiceTypeCodeToStr(AInvoice.InvoiceTypeCode)));
  P.Value(erf_InvoiceTypeCodeOther, AInvoice.InvoiceTypeCodeOther);
  P.Value(erf_InvoiceDueDate, P.Date(AInvoice.InvoiceDueDate));
  P.Value(erf_InvoicePeriodStartDate, P.Date(AInvoice.InvoicePeriodStartDate));
  P.Value(erf_InvoicePeriodEndDate, P.Date(AInvoice.InvoicePeriodEndDate));
  P.Value(erf_InvoiceCurrencyCode, P.Code(ecl_CurrencyCode, AInvoice.InvoiceCurrencyCode));
  P.Value(erf_TaxCurrencyCode, P.Code(ecl_CurrencyCode, AInvoice.TaxCurrencyCode));
  if AInvoice.TaxPointDate.HasValue then
    P.Value(erf_TaxPointDate, LandrixEInvoiceRenderDate(AInvoice.TaxPointDate.Value, P.Language));
  P.Value(erf_TaxPointDateCode, AInvoice.TaxPointDateCode);
  P.Value(erf_BuyerReference, AInvoice.BuyerReference);
  P.Value(erf_ProfileID, AInvoice.ProfileID);
  if AInvoice.TestIndicator.HasValue then
    P.Value(erf_TestIndicator, P.YesNo(AInvoice.TestIndicator.Value));
  P.Value(erf_DocumentName, AInvoice.DocumentName);
  P.Pop;
  P.Pop;
end;

procedure WriteAddress(P: TPage; AAddress: TLandrixInvoiceAddress; ABase: TLandrixEInvoiceRenderField);
const
  T = erf_AccountingSupplierParty_Address;
begin
  P.Value(Like(ABase, T, erf_AccountingSupplierParty_Address_StreetName), AAddress.StreetName);
  P.Value(Like(ABase, T, erf_AccountingSupplierParty_Address_AdditionalStreetName), AAddress.AdditionalStreetName);
  P.Value(Like(ABase, T, erf_AccountingSupplierParty_Address_AddressLine), AAddress.AddressLine);
  P.Value(Like(ABase, T, erf_AccountingSupplierParty_Address_PostalZone), AAddress.PostalZone);
  P.Value(Like(ABase, T, erf_AccountingSupplierParty_Address_City), AAddress.City);
  P.Value(Like(ABase, T, erf_AccountingSupplierParty_Address_CountrySubentity), AAddress.CountrySubentity);
  P.Value(Like(ABase, T, erf_AccountingSupplierParty_Address_CountryCode),
    P.Code(ecl_CountryCode, AAddress.CountryCode));
end;

{ seller or buyer; the creditor identifier of the seller is shown with the
  payment
  DE: Verkaeufer oder Kaeufer; die Glaeubiger-ID des Verkaeufers erscheint
  bei der Zahlung }
procedure WriteAccountingParty(P: TPage; AParty: TLandrixInvoiceAccountingParty; ABase: TLandrixEInvoiceRenderField);
const
  T = erf_AccountingSupplierParty;
begin
  P.OpenBox(ABase);
  P.Value(Like(ABase, T, erf_AccountingSupplierParty_RegistrationName), AParty.RegistrationName);
  P.Value(Like(ABase, T, erf_AccountingSupplierParty_Name), AParty.Name);
  WriteAddress(P, AParty.Address, Like(ABase, T, erf_AccountingSupplierParty_Address));
  P.Value(Like(ABase, T, erf_AccountingSupplierParty_IdentifierSellerBuyer), AParty.IdentifierSellerBuyer);
  P.Value(Like(ABase, T, erf_AccountingSupplierParty_GlobalIdentifierSellerBuyer),
    AParty.GlobalIdentifierSellerBuyer);
  if AParty.GlobalIdentifierSellerBuyer <> '' then
    P.Value(Like(ABase, T, erf_AccountingSupplierParty_GlobalIdentifierSellerBuyerSchemeID),
      P.Code(ecl_IdentifierScheme, AParty.GlobalIdentifierSellerBuyerSchemeID));
  P.Value(Like(ABase, T, erf_AccountingSupplierParty_CompanyID), AParty.CompanyID);
  if AParty.CompanyID <> '' then
    P.Value(Like(ABase, T, erf_AccountingSupplierParty_CompanyIDSchemeID),
      P.Code(ecl_IdentifierScheme, AParty.CompanyIDSchemeID));
  P.Value(Like(ABase, T, erf_AccountingSupplierParty_VATCompanyID), AParty.VATCompanyID);
  P.Value(Like(ABase, T, erf_AccountingSupplierParty_VATCompanyNumber), AParty.VATCompanyNumber);
  P.Value(Like(ABase, T, erf_AccountingSupplierParty_ElectronicAddressSellerBuyer),
    AParty.ElectronicAddressSellerBuyer);
  if AParty.ElectronicAddressSellerBuyer <> '' then
    P.Value(Like(ABase, T, erf_AccountingSupplierParty_ElectronicAddressSellerBuyerSchemeID),
      P.Code(ecl_ElectronicAddressScheme, AParty.ElectronicAddressSellerBuyerSchemeID));
  P.Value(Like(ABase, T, erf_AccountingSupplierParty_ContactName), AParty.ContactName);
  P.Value(Like(ABase, T, erf_AccountingSupplierParty_ContactDepartment), AParty.ContactDepartment);
  P.Value(Like(ABase, T, erf_AccountingSupplierParty_ContactTelephone), AParty.ContactTelephone);
  P.Value(Like(ABase, T, erf_AccountingSupplierParty_ContactElectronicMail), AParty.ContactElectronicMail);
  P.Value(Like(ABase, T, erf_AccountingSupplierParty_AdditionalLegalInformationSeller),
    AParty.AdditionalLegalInformationSeller);
  if ABase <> erf_AccountingSupplierParty then
    P.Value(Like(ABase, T, erf_AccountingSupplierParty_BankAssignedCreditorIdentifier),
      AParty.BankAssignedCreditorIdentifier);
  P.Pop;
end;

{ payee, tax representative, invoicee
  DE: Zahlungsempfaenger, Steuervertreter, Rechnungsempfaenger }
procedure WriteParty(P: TPage; AParty: TLandrixInvoiceParty; ABase: TLandrixEInvoiceRenderField);
const
  T = erf_PayeeParty;
begin
  P.OpenBox(ABase);
  P.Value(Like(ABase, T, erf_PayeeParty_Name), AParty.Name);
  WriteAddress(P, AParty.Address, Like(ABase, T, erf_PayeeParty_Address));
  P.Value(Like(ABase, T, erf_PayeeParty_Identifier), AParty.Identifier);
  if AParty.Identifier <> '' then
    P.Value(Like(ABase, T, erf_PayeeParty_IdentifierSchemeID), P.Code(ecl_IdentifierScheme,
      AParty.IdentifierSchemeID));
  P.Value(Like(ABase, T, erf_PayeeParty_CompanyID), AParty.CompanyID);
  if AParty.CompanyID <> '' then
    P.Value(Like(ABase, T, erf_PayeeParty_CompanyIDSchemeID), P.Code(ecl_IdentifierScheme,
      AParty.CompanyIDSchemeID));
  P.Value(Like(ABase, T, erf_PayeeParty_VATCompanyID), AParty.VATCompanyID);
  P.Value(Like(ABase, T, erf_PayeeParty_ContactName), AParty.ContactName);
  P.Value(Like(ABase, T, erf_PayeeParty_ContactDepartment), AParty.ContactDepartment);
  P.Value(Like(ABase, T, erf_PayeeParty_ContactTelephone), AParty.ContactTelephone);
  P.Value(Like(ABase, T, erf_PayeeParty_ContactElectronicMail), AParty.ContactElectronicMail);
  P.Pop;
end;

procedure WriteParties(P: TPage; AInvoice: TLandrixInvoice);
var
  D: TLandrixInvoiceDeliveryInformation;
begin
  P.OpenSection(ers_Parties);
  P.Push('<div class="parties">'#10, '</div>'#10);
  WriteAccountingParty(P, AInvoice.AccountingSupplierParty, erf_AccountingSupplierParty);
  WriteAccountingParty(P, AInvoice.AccountingCustomerParty, erf_AccountingCustomerParty);
  WriteParty(P, AInvoice.InvoiceeParty, erf_InvoiceeParty);
  WriteParty(P, AInvoice.PayeeParty, erf_PayeeParty);
  WriteParty(P, AInvoice.TaxRepresentativeParty, erf_TaxRepresentativeParty);
  D := AInvoice.DeliveryInformation;
  P.OpenBox(erf_DeliveryInformation);
  P.Value(erf_DeliveryInformation_Name, D.Name);
  WriteAddress(P, D.Address, erf_DeliveryInformation_Address);
  P.Value(erf_DeliveryInformation_LocationIdentifier, D.LocationIdentifier);
  if D.LocationIdentifier <> '' then
    P.Value(erf_DeliveryInformation_LocationIdentifierSchemeID, P.Code(ecl_IdentifierScheme,
      D.LocationIdentifierSchemeID));
  P.Value(erf_DeliveryInformation_ActualDeliveryDate, P.Date(D.ActualDeliveryDate));
  P.Value(erf_DeliveryInformation_ContactName, D.ContactName);
  P.Value(erf_DeliveryInformation_ContactTelephone, D.ContactTelephone);
  P.Value(erf_DeliveryInformation_ContactElectronicMail, D.ContactElectronicMail);
  P.Pop;
  P.Pop;
  P.Pop;
end;

procedure WriteReferences(P: TPage; AInvoice: TLandrixInvoice);
var
  I: Integer;
  R: TLandrixInvoicePrecedingInvoiceReference;
begin
  P.OpenSection(ers_References);
  P.Push('<dl>'#10, '</dl>'#10);
  P.Value(erf_SellerOrderReference, AInvoice.SellerOrderReference);
  if AInvoice.SellerOrderReferenceDate.HasValue then
    P.Value(erf_SellerOrderReferenceDate, LandrixEInvoiceRenderDate(AInvoice.SellerOrderReferenceDate.Value,
      P.Language));
  P.Value(erf_PurchaseOrderReference, AInvoice.PurchaseOrderReference);
  if AInvoice.PurchaseOrderReferenceDate.HasValue then
    P.Value(erf_PurchaseOrderReferenceDate, LandrixEInvoiceRenderDate(AInvoice.PurchaseOrderReferenceDate.Value,
      P.Language));
  P.Value(erf_ContractDocumentReference, AInvoice.ContractDocumentReference);
  P.Value(erf_ProjectReference, AInvoice.ProjectReference);
  P.Value(erf_ReceiptDocumentReference, AInvoice.ReceiptDocumentReference);
  P.Value(erf_DeliveryReceiptNumber, AInvoice.DeliveryReceiptNumber);
  P.Value(erf_DeliveryReceiptDate, P.Date(AInvoice.DeliveryReceiptDate));
  P.Value(erf_DeliveryReceiptNumberExtended, AInvoice.DeliveryReceiptNumberExtended);
  P.Value(erf_DeliveryReceiptDateExtended, P.Date(AInvoice.DeliveryReceiptDateExtended));
  P.Value(erf_BuyerAccountingReference, AInvoice.BuyerAccountingReference);
  P.Pop;
  if AInvoice.PrecedingInvoiceReferences.Count > 0 then
  begin
    P.ListHeading(erf_PrecedingInvoiceReferences);
    for I := 0 to Integer(AInvoice.PrecedingInvoiceReferences.Count) - 1 do
    begin
      R := AInvoice.PrecedingInvoiceReferences[I];
      P.OpenItem(erf_PrecedingInvoiceReferences, 'item');
      P.Push('<dl>'#10, '</dl>'#10);
      P.Value(erf_PrecedingInvoiceReferences_ID, R.ID);
      P.Value(erf_PrecedingInvoiceReferences_IssueDate, P.Date(R.IssueDate));
      P.Pop;
      P.CloseItem;
    end;
  end;
  P.Pop;
end;

{ document level (ABase erf_AllowanceCharges) or line level
  (erf_InvoiceLines_AllowanceCharges); the terms of a row follow its kind
  DE: Belegebene (ABase erf_AllowanceCharges) oder Positionsebene
  (erf_InvoiceLines_AllowanceCharges); die Begriffe einer Zeile folgen
  ihrer Art }
procedure WriteAllowanceCharges(P: TPage; AList: TLandrixInvoiceAllowanceCharges; ABase: TLandrixEInvoiceRenderField);
const
  T = erf_AllowanceCharges;
var
  I: Integer;
  A: TLandrixInvoiceAllowanceCharge;
  Kind, Category: TLandrixEInvoiceString;
  ShowRate, HasTax: Boolean;

  function F(ATemplate: TLandrixEInvoiceRenderField): TLandrixEInvoiceRenderField;
  begin
    Result := Like(ABase, T, ATemplate);
  end;

  function BT(ATemplate: TLandrixEInvoiceRenderField): TLandrixEInvoiceString;
  begin
    Result := AllowanceOrChargeTerm(LandrixEInvoiceRenderFieldBT(F(ATemplate)), A.ChargeIndicator);
  end;

begin
  if AList.Count = 0 then
    Exit;
  { the VAT columns on line level only when an item has a category or a
    rate (EN 16931 has no VAT there; the document level always shows them)
    DE: die Steuerspalten auf Positionsebene nur, wenn ein Eintrag eine
    Kategorie oder einen Satz hat (EN 16931 kennt dort keine Steuer; die
    Belegebene zeigt sie immer) }
  HasTax := ABase = erf_AllowanceCharges;
  for I := 0 to Integer(AList.Count) - 1 do
    if (AList[I].TaxCategory <> idtfcc_None) or (AList[I].TaxCategoryOther <> '') or (AList[I].TaxPercent <> 0) then
      HasTax := True;
  { the code column holds the codes of allowances and of charges
    DE: die Code-Spalte enthaelt die Codes von Abschlaegen und Zuschlaegen }
  Kind := LandrixEInvoiceRenderFieldBT(F(erf_AllowanceCharges_ReasonCodeAllowance)) + '/' +
    LandrixEInvoiceRenderFieldBT(F(erf_AllowanceCharges_ReasonCodeCharge));
  if HasTax then
    P.OpenTable(Columns([F(erf_AllowanceCharges_ChargeIndicator), F(erf_AllowanceCharges_ReasonCodeAllowance),
      F(erf_AllowanceCharges_Reason), F(erf_AllowanceCharges_BaseAmount),
      F(erf_AllowanceCharges_MultiplierFactorNumeric), F(erf_AllowanceCharges_Amount),
      F(erf_AllowanceCharges_TaxCategory), F(erf_AllowanceCharges_TaxPercent)]), Terms(['', Kind]))
  else
    P.OpenTable(Columns([F(erf_AllowanceCharges_ChargeIndicator), F(erf_AllowanceCharges_ReasonCodeAllowance),
      F(erf_AllowanceCharges_Reason), F(erf_AllowanceCharges_BaseAmount),
      F(erf_AllowanceCharges_MultiplierFactorNumeric), F(erf_AllowanceCharges_Amount)]), Terms(['', Kind]));
  for I := 0 to Integer(AList.Count) - 1 do
  begin
    A := AList[I];
    P.Raw('<tr');
    P.Marks(ABase, LandrixEInvoiceRenderFieldBT(ABase));
    P.Raw('>');
    if A.ChargeIndicator then
      Kind := P.Snippet(Labels[P.Language, lbCharge])
    else
      Kind := P.Snippet(Labels[P.Language, lbAllowance]);
    P.Cell(F(erf_AllowanceCharges_ChargeIndicator), Kind, BT(erf_AllowanceCharges_ChargeIndicator));
    P.Raw('<td>');
    P.Span(F(erf_AllowanceCharges_ReasonCodeAllowance), P.Code(ecl_AllowanceOrChargeIdentCode,
      LandrixEInvoiceAllowanceOrChargeIdentCodeToStr(A.ReasonCodeAllowance)),
      BT(erf_AllowanceCharges_ReasonCodeAllowance));
    P.Span(F(erf_AllowanceCharges_ReasonCodeAllowanceOther), A.ReasonCodeAllowanceOther,
      BT(erf_AllowanceCharges_ReasonCodeAllowanceOther));
    P.Span(F(erf_AllowanceCharges_ReasonCodeCharge), P.Code(ecl_SpecialServiceDescriptionCode,
      LandrixEInvoiceSpecialServiceDescriptionCodeToStr(A.ReasonCodeCharge)), BT(erf_AllowanceCharges_ReasonCodeCharge));
    P.Span(F(erf_AllowanceCharges_ReasonCodeChargeOther), A.ReasonCodeChargeOther,
      BT(erf_AllowanceCharges_ReasonCodeChargeOther));
    P.Raw('</td>');
    P.Cell(F(erf_AllowanceCharges_Reason), A.Reason, BT(erf_AllowanceCharges_Reason));
    { the base as the writers write it: with a percentage also when 0
      DE: die Basis, wie die Writer sie schreiben: mit Prozentsatz auch bei 0 }
    if (A.BaseAmount <> 0) or (A.MultiplierFactorNumeric <> 0) then
      P.Cell(F(erf_AllowanceCharges_BaseAmount), P.Amount(A.BaseAmount), BT(erf_AllowanceCharges_BaseAmount))
    else
      P.Cell(F(erf_AllowanceCharges_BaseAmount), '', BT(erf_AllowanceCharges_BaseAmount));
    P.Cell(F(erf_AllowanceCharges_MultiplierFactorNumeric), P.PercentIf(A.MultiplierFactorNumeric),
      BT(erf_AllowanceCharges_MultiplierFactorNumeric));
    P.Cell(F(erf_AllowanceCharges_Amount), P.Amount(A.Amount), BT(erf_AllowanceCharges_Amount));
    if not HasTax then
    begin
      P.Raw('</tr>'#10);
      Continue;
    end;
    P.Raw('<td>');
    P.Span(F(erf_AllowanceCharges_TaxCategory), P.Code(ecl_DutyTaxFeeCategoryCode,
      LandrixEInvoiceDutyTaxFeeCategoryCodeToStr(A.TaxCategory)), BT(erf_AllowanceCharges_TaxCategory));
    P.Span(F(erf_AllowanceCharges_TaxCategoryOther), A.TaxCategoryOther, BT(erf_AllowanceCharges_TaxCategoryOther));
    P.Raw('</td>');
    { the rate as the writers write it: on document level for every
      category but O (also an unknown one), on line level (no business
      term) when a category is set; always when it is not 0
      DE: der Satz, wie die Writer ihn schreiben: auf Belegebene fuer jede
      Kategorie ausser O (auch eine unbekannte), auf Positionsebene (ohne
      Geschaeftsbegriff), wenn eine Kategorie gesetzt ist; immer, wenn er
      nicht 0 ist }
    Category := LandrixEInvoiceDutyTaxFeeCategoryCodeToStr(A.TaxCategory);
    if Category = '' then
      Category := A.TaxCategoryOther;
    if ABase = erf_AllowanceCharges then
      ShowRate := Category <> 'O'
    else
      ShowRate := Category <> '';
    if ShowRate or (A.TaxPercent <> 0) then
      P.Cell(F(erf_AllowanceCharges_TaxPercent), P.Percent(A.TaxPercent), BT(erf_AllowanceCharges_TaxPercent))
    else
      P.Cell(F(erf_AllowanceCharges_TaxPercent), '', BT(erf_AllowanceCharges_TaxPercent));
    P.Raw('</tr>'#10);
  end;
  P.CloseTable;
end;

procedure WriteLine(P: TPage; ALine: TLandrixInvoiceLine; AContainer: TLandrixEInvoiceRenderField);
var
  I: Integer;
  C: TLandrixInvoiceLineItemClassification;
  A: TLandrixInvoiceLineItemAttribute;
begin
  P.OpenItem(AContainer, 'line');
  { the short row: what, how many, at which price, which VAT, how much
    DE: die Kurzzeile: was, wie viel, zu welchem Preis, welche Steuer,
    welcher Betrag }
  P.Raw('<dl class="head">'#10);
  P.Value(erf_InvoiceLines_ID, ALine.ID);
  P.Value(erf_InvoiceLines_Name, ALine.Name);
  P.Value(erf_InvoiceLines_Quantity, P.Decimal(ALine.Quantity, 0));
  P.Value(erf_InvoiceLines_UnitCode, P.Code(ecl_UnitCode, LandrixEInvoiceUnitCodeToStr(ALine.UnitCode)));
  P.Value(erf_InvoiceLines_UnitCodeOther, ALine.UnitCodeOther);
  P.Value(erf_InvoiceLines_NetPriceAmount, P.Decimal(ALine.NetPriceAmount, 2));
  P.Value(erf_InvoiceLines_TaxCategory, P.Code(ecl_DutyTaxFeeCategoryCode,
    LandrixEInvoiceDutyTaxFeeCategoryCodeToStr(ALine.TaxCategory)));
  P.Value(erf_InvoiceLines_TaxCategoryOther, ALine.TaxCategoryOther);
  P.Value(erf_InvoiceLines_TaxPercent, P.Percent(ALine.TaxPercent));
  P.Value(erf_InvoiceLines_LineAmount, P.Amount(ALine.LineAmount));
  P.Raw('</dl>'#10);
  P.Push('<dl>'#10, '</dl>'#10);
  P.Value(erf_InvoiceLines_Description, ALine.Description);
  P.Value(erf_InvoiceLines_Note, ALine.Note);
  if ALine.LineStatusReasonCode <> ilsrc_None then
    P.Value(erf_InvoiceLines_LineStatusReasonCode, P.Snippet(LineStatusLabels[P.Language,
      ALine.LineStatusReasonCode]) + ' (' + P.Snippet(LineStatusCodes[ALine.LineStatusReasonCode]) + ')');
  P.Value(erf_InvoiceLines_LineStatusReasonCodeOther, ALine.LineStatusReasonCodeOther);
  P.Value(erf_InvoiceLines_SellersItemIdentification, ALine.SellersItemIdentification);
  P.Value(erf_InvoiceLines_BuyersItemIdentification, ALine.BuyersItemIdentification);
  P.Value(erf_InvoiceLines_GlobalID_EAN_GTIN, ALine.GlobalID_EAN_GTIN);
  P.Value(erf_InvoiceLines_StandardItemIdentifier, ALine.StandardItemIdentifier);
  if ALine.StandardItemIdentifier <> '' then
    P.Value(erf_InvoiceLines_StandardItemIdentifierSchemeID, P.Code(ecl_IdentifierScheme,
      ALine.StandardItemIdentifierSchemeID));
  P.Value(erf_InvoiceLines_ObjectIdentifier, ALine.ObjectIdentifier);
  if ALine.ObjectIdentifier <> '' then
    P.Value(erf_InvoiceLines_ObjectIdentifierSchemeID, P.Code(ecl_ReferenceCodeQualifier,
      ALine.ObjectIdentifierSchemeID));
  P.Value(erf_InvoiceLines_OriginTradeCountry, P.Code(ecl_CountryCode, ALine.OriginTradeCountry));
  P.Value(erf_InvoiceLines_GrossPriceAmount, P.DecimalIf(ALine.GrossPriceAmount, 2));
  P.Value(erf_InvoiceLines_DiscountOnTheGrossPrice, P.DecimalIf(ALine.DiscountOnTheGrossPrice, 2));
  P.Value(erf_InvoiceLines_BaseQuantity, P.DecimalIf(ALine.BaseQuantity, 0));
  P.Value(erf_InvoiceLines_BaseQuantityUnitCode, P.Code(ecl_UnitCode,
    LandrixEInvoiceUnitCodeToStr(ALine.BaseQuantityUnitCode)));
  P.Value(erf_InvoiceLines_BaseQuantityUnitCodeOther, ALine.BaseQuantityUnitCodeOther);
  P.Value(erf_InvoiceLines_TaxExemptionReason, ALine.TaxExemptionReason);
  P.Value(erf_InvoiceLines_InvoiceLinePeriodStartDate, P.Date(ALine.InvoiceLinePeriodStartDate));
  P.Value(erf_InvoiceLines_InvoiceLinePeriodEndDate, P.Date(ALine.InvoiceLinePeriodEndDate));
  P.Value(erf_InvoiceLines_OrderNumber, ALine.OrderNumber);
  if ALine.OrderDate.HasValue then
    P.Value(erf_InvoiceLines_OrderDate, LandrixEInvoiceRenderDate(ALine.OrderDate.Value, P.Language));
  P.Value(erf_InvoiceLines_OrderLineReference, ALine.OrderLineReference);
  P.Value(erf_InvoiceLines_BuyerAccountingReference, ALine.BuyerAccountingReference);
  P.Value(erf_InvoiceLines_DeliveryNoteNumber, ALine.DeliveryNoteNumber);
  P.Value(erf_InvoiceLines_DeliveryNoteLineID, ALine.DeliveryNoteLineID);
  P.Value(erf_InvoiceLines_DeliveryNoteDate, P.Date(ALine.DeliveryNoteDate));
  P.Value(erf_InvoiceLines_ActualDeliveryDate, P.Date(ALine.ActualDeliveryDate));
  P.Pop;
  if ALine.AllowanceCharges.Count > 0 then
  begin
    P.ListHeading(erf_InvoiceLines_AllowanceCharges);
    WriteAllowanceCharges(P, ALine.AllowanceCharges, erf_InvoiceLines_AllowanceCharges);
  end;
  if ALine.ItemAttributes.Count > 0 then
  begin
    P.ListHeading(erf_InvoiceLines_ItemAttributes);
    P.OpenTable(Columns([erf_InvoiceLines_ItemAttributes_Name, erf_InvoiceLines_ItemAttributes_Value]), nil);
    for I := 0 to Integer(ALine.ItemAttributes.Count) - 1 do
    begin
      A := ALine.ItemAttributes[I];
      P.Raw('<tr');
      P.Marks(erf_InvoiceLines_ItemAttributes, LandrixEInvoiceRenderFieldBT(erf_InvoiceLines_ItemAttributes));
      P.Raw('>');
      P.Cell(erf_InvoiceLines_ItemAttributes_Name, A.Name, LandrixEInvoiceRenderFieldBT(
        erf_InvoiceLines_ItemAttributes_Name));
      P.Cell(erf_InvoiceLines_ItemAttributes_Value, A.Value, LandrixEInvoiceRenderFieldBT(
        erf_InvoiceLines_ItemAttributes_Value));
      P.Raw('</tr>'#10);
    end;
    P.CloseTable;
  end;
  if ALine.ItemClassifications.Count > 0 then
  begin
    P.ListHeading(erf_InvoiceLines_ItemClassifications);
    P.OpenTable(Columns([erf_InvoiceLines_ItemClassifications_ClassCode, erf_InvoiceLines_ItemClassifications_ListID,
      erf_InvoiceLines_ItemClassifications_ListVersionID, erf_InvoiceLines_ItemClassifications_ClassificationName]), nil);
    for I := 0 to Integer(ALine.ItemClassifications.Count) - 1 do
    begin
      C := ALine.ItemClassifications[I];
      P.Raw('<tr');
      P.Marks(erf_InvoiceLines_ItemClassifications, LandrixEInvoiceRenderFieldBT(
        erf_InvoiceLines_ItemClassifications));
      P.Raw('>');
      P.Cell(erf_InvoiceLines_ItemClassifications_ClassCode, C.ClassCode, LandrixEInvoiceRenderFieldBT(
        erf_InvoiceLines_ItemClassifications_ClassCode));
      P.Cell(erf_InvoiceLines_ItemClassifications_ListID, P.Code(ecl_ItemClassificationScheme, C.ListID),
        LandrixEInvoiceRenderFieldBT(erf_InvoiceLines_ItemClassifications_ListID));
      P.Cell(erf_InvoiceLines_ItemClassifications_ListVersionID, C.ListVersionID, LandrixEInvoiceRenderFieldBT(
        erf_InvoiceLines_ItemClassifications_ListVersionID));
      P.Cell(erf_InvoiceLines_ItemClassifications_ClassificationName, C.ClassificationName,
        LandrixEInvoiceRenderFieldBT(erf_InvoiceLines_ItemClassifications_ClassificationName));
      P.Raw('</tr>'#10);
    end;
    P.CloseTable;
  end;
  if ALine.SubInvoiceLines.Count > 0 then
  begin
    P.Raw('<div class="sublines">'#10);
    for I := 0 to Integer(ALine.SubInvoiceLines.Count) - 1 do
      WriteLine(P, ALine.SubInvoiceLines[I], erf_InvoiceLines_SubInvoiceLines);
    P.Raw('</div>'#10);
  end;
  P.CloseItem;
end;

procedure WriteLines(P: TPage; AInvoice: TLandrixInvoice);
var
  I: Integer;
begin
  P.OpenSection(ers_Lines);
  for I := 0 to Integer(AInvoice.InvoiceLines.Count) - 1 do
    WriteLine(P, AInvoice.InvoiceLines[I], erf_InvoiceLines);
  P.Pop;
end;

procedure WriteDocumentAllowanceCharges(P: TPage; AInvoice: TLandrixInvoice);
begin
  P.OpenSection(ers_Allowances);
  WriteAllowanceCharges(P, AInvoice.AllowanceCharges, erf_AllowanceCharges);
  P.Pop;
end;

procedure WriteVat(P: TPage; AInvoice: TLandrixInvoice);
var
  I: Integer;
  V: TLandrixInvoiceTaxAmount;

  function BT(AField: TLandrixEInvoiceRenderField): TLandrixEInvoiceString;
  begin
    Result := LandrixEInvoiceRenderFieldBT(AField);
  end;

begin
  if AInvoice.TaxAmountSubtotals.Count = 0 then
    Exit;
  P.OpenSection(ers_Vat);
  P.OpenTable(Columns([erf_TaxAmountSubtotals_TaxCategory, erf_TaxAmountSubtotals_TaxPercent,
    erf_TaxAmountSubtotals_TaxableAmount, erf_TaxAmountSubtotals_TaxAmount,
    erf_TaxAmountSubtotals_TaxExemptionReasonCode, erf_TaxAmountSubtotals_TaxExemptionReason]), nil);
  for I := 0 to Integer(AInvoice.TaxAmountSubtotals.Count) - 1 do
  begin
    V := AInvoice.TaxAmountSubtotals[I];
    P.Raw('<tr');
    P.Marks(erf_TaxAmountSubtotals, BT(erf_TaxAmountSubtotals));
    P.Raw('><td>');
    P.Span(erf_TaxAmountSubtotals_TaxCategory, P.Code(ecl_DutyTaxFeeCategoryCode,
      LandrixEInvoiceDutyTaxFeeCategoryCodeToStr(V.TaxCategory)), BT(erf_TaxAmountSubtotals_TaxCategory));
    P.Span(erf_TaxAmountSubtotals_TaxCategoryOther, V.TaxCategoryOther, BT(erf_TaxAmountSubtotals_TaxCategoryOther));
    P.Raw('</td>');
    P.Cell(erf_TaxAmountSubtotals_TaxPercent, P.Percent(V.TaxPercent), BT(erf_TaxAmountSubtotals_TaxPercent));
    P.Cell(erf_TaxAmountSubtotals_TaxableAmount, P.Amount(V.TaxableAmount), BT(erf_TaxAmountSubtotals_TaxableAmount));
    P.Cell(erf_TaxAmountSubtotals_TaxAmount, P.Amount(V.TaxAmount), BT(erf_TaxAmountSubtotals_TaxAmount));
    P.Cell(erf_TaxAmountSubtotals_TaxExemptionReasonCode, P.Code(ecl_VATExemptionReasonCode,
      V.TaxExemptionReasonCode), BT(erf_TaxAmountSubtotals_TaxExemptionReasonCode));
    P.Cell(erf_TaxAmountSubtotals_TaxExemptionReason, V.TaxExemptionReason,
      BT(erf_TaxAmountSubtotals_TaxExemptionReason));
    P.Raw('</tr>'#10);
  end;
  P.CloseTable;
  P.Pop;
end;

{ the totals EN 16931 requires are shown even when 0
  DE: die Summen, die EN 16931 verlangt, erscheinen auch bei 0 }
procedure WriteTotals(P: TPage; AInvoice: TLandrixInvoice);
var
  I: Integer;
  R: TLandrixInvoicePrepaidPayment;
  Cur: TLandrixEInvoiceString;

  function BT(AField: TLandrixEInvoiceRenderField): TLandrixEInvoiceString;
  begin
    Result := LandrixEInvoiceRenderFieldBT(AField);
  end;

begin
  P.OpenSection(ers_Totals);
  P.Push('<dl>'#10, '</dl>'#10);
  Cur := AInvoice.InvoiceCurrencyCode;
  P.Money(erf_LineAmount, AInvoice.LineAmount, True, erf_InvoiceCurrencyCode, Cur);
  P.Money(erf_AllowanceTotalAmount, AInvoice.AllowanceTotalAmount, False, erf_InvoiceCurrencyCode, Cur);
  P.Money(erf_ChargeTotalAmount, AInvoice.ChargeTotalAmount, False, erf_InvoiceCurrencyCode, Cur);
  P.Money(erf_TaxExclusiveAmount, AInvoice.TaxExclusiveAmount, True, erf_InvoiceCurrencyCode, Cur);
  P.Money(erf_TaxAmountTotal, AInvoice.TaxAmountTotal, True, erf_InvoiceCurrencyCode, Cur);
  if AInvoice.TaxAmountTotalInTaxCurrency.HasValue then
    P.Money(erf_TaxAmountTotalInTaxCurrency, AInvoice.TaxAmountTotalInTaxCurrency.Value, True,
      erf_TaxCurrencyCode, AInvoice.TaxCurrencyCode);
  P.Money(erf_TaxInclusiveAmount, AInvoice.TaxInclusiveAmount, True, erf_InvoiceCurrencyCode, Cur);
  P.Money(erf_PrepaidAmount, AInvoice.PrepaidAmount, False, erf_InvoiceCurrencyCode, Cur);
  P.Money(erf_PayableRoundingAmount, AInvoice.PayableRoundingAmount, False, erf_InvoiceCurrencyCode, Cur);
  P.Money(erf_PayableAmount, AInvoice.PayableAmount, True, erf_InvoiceCurrencyCode, Cur);
  P.Pop;
  if AInvoice.PrepaidPayments.Count > 0 then
  begin
    P.ListHeading(erf_PrepaidPayments);
    P.OpenTable(Columns([erf_PrepaidPayments_ID, erf_PrepaidPayments_PaidAmount,
      erf_PrepaidPayments_PaidAmountCurrencyID, erf_PrepaidPayments_InstructionID]), nil);
    for I := 0 to Integer(AInvoice.PrepaidPayments.Count) - 1 do
    begin
      R := AInvoice.PrepaidPayments[I];
      P.Raw('<tr');
      P.Marks(erf_PrepaidPayments, BT(erf_PrepaidPayments));
      P.Raw('>');
      P.Cell(erf_PrepaidPayments_ID, R.ID, BT(erf_PrepaidPayments_ID));
      P.Cell(erf_PrepaidPayments_PaidAmount, P.Amount(R.PaidAmount), BT(erf_PrepaidPayments_PaidAmount));
      P.Cell(erf_PrepaidPayments_PaidAmountCurrencyID, P.Code(ecl_CurrencyCode, R.PaidAmountCurrencyID),
        BT(erf_PrepaidPayments_PaidAmountCurrencyID));
      P.Cell(erf_PrepaidPayments_InstructionID, R.InstructionID, BT(erf_PrepaidPayments_InstructionID));
      P.Raw('</tr>'#10);
    end;
    P.CloseTable;
  end;
  P.Pop;
end;

procedure WriteCashDiscount(P: TPage; ADays: Integer; APercent: Double; ABase, AAmount: Currency;
  const ANote, ACurrency: TLandrixEInvoiceString; AFieldDays, AFieldPercent, AFieldBase, AFieldAmount,
  AFieldNote: TLandrixEInvoiceRenderField);
begin
  if ADays <> 0 then
    P.Value(AFieldDays, TLandrixEInvoiceString(IntToStr(ADays)));
  P.Value(AFieldPercent, P.PercentIf(APercent));
  P.Money(AFieldBase, ABase, False, erf_InvoiceCurrencyCode, ACurrency);
  P.Money(AFieldAmount, AAmount, False, erf_InvoiceCurrencyCode, ACurrency);
  P.Value(AFieldNote, ANote);
end;

procedure WritePayment(P: TPage; AInvoice: TLandrixInvoice);
var
  I: Integer;
  T: TLandrixInvoicePaymentType;
begin
  P.OpenSection(ers_Payment);
  P.Push('<dl>'#10, '</dl>'#10);
  P.Value(erf_PaymentID, AInvoice.PaymentID);
  P.Value(erf_PaymentMandateID, AInvoice.PaymentMandateID);
  P.Value(erf_AccountingSupplierParty_BankAssignedCreditorIdentifier,
    AInvoice.AccountingSupplierParty.BankAssignedCreditorIdentifier);
  P.Pop;
  if AInvoice.PaymentTypes.Count > 0 then
  begin
    P.ListHeading(erf_PaymentTypes);
    for I := 0 to Integer(AInvoice.PaymentTypes.Count) - 1 do
    begin
      T := AInvoice.PaymentTypes[I];
      P.OpenItem(erf_PaymentTypes, 'item');
      P.Push('<dl>'#10, '</dl>'#10);
      P.Value(erf_PaymentTypes_PaymentMeansCode, P.Code(ecl_PaymentMeansCode,
        LandrixEInvoicePaymentMeansCodeToStr(T.PaymentMeansCode)));
      P.Value(erf_PaymentTypes_PaymentMeansCodeOther, T.PaymentMeansCodeOther);
      P.Value(erf_PaymentTypes_PaymentMeansInformation, T.PaymentMeansInformation);
      P.Value(erf_PaymentTypes_FinancialAccount, T.FinancialAccount);
      P.Value(erf_PaymentTypes_FinancialAccountName, T.FinancialAccountName);
      P.Value(erf_PaymentTypes_FinancialInstitutionBranch, T.FinancialInstitutionBranch);
      P.Pop;
      P.CloseItem;
    end;
  end;
  P.Push('<dl>'#10, '</dl>'#10);
  P.Value(erf_PaymentTermsType, P.Snippet(PaymentTermsLabels[P.Language, AInvoice.PaymentTermsType]));
  P.Value(erf_PaymentTermNetNote, AInvoice.PaymentTermNetNote);
  WriteCashDiscount(P, AInvoice.PaymentTermCashDiscount1Days, AInvoice.PaymentTermCashDiscount1Percent,
    AInvoice.PaymentTermCashDiscount1Base, AInvoice.PaymentTermCashDiscount1ActualAmount,
    AInvoice.PaymentTermCashDiscount1Note, AInvoice.InvoiceCurrencyCode, erf_PaymentTermCashDiscount1Days, erf_PaymentTermCashDiscount1Percent,
    erf_PaymentTermCashDiscount1Base, erf_PaymentTermCashDiscount1ActualAmount, erf_PaymentTermCashDiscount1Note);
  WriteCashDiscount(P, AInvoice.PaymentTermCashDiscount2Days, AInvoice.PaymentTermCashDiscount2Percent,
    AInvoice.PaymentTermCashDiscount2Base, AInvoice.PaymentTermCashDiscount2ActualAmount,
    AInvoice.PaymentTermCashDiscount2Note, AInvoice.InvoiceCurrencyCode, erf_PaymentTermCashDiscount2Days, erf_PaymentTermCashDiscount2Percent,
    erf_PaymentTermCashDiscount2Base, erf_PaymentTermCashDiscount2ActualAmount, erf_PaymentTermCashDiscount2Note);
  WriteCashDiscount(P, AInvoice.PaymentTermCashDiscount3Days, AInvoice.PaymentTermCashDiscount3Percent,
    AInvoice.PaymentTermCashDiscount3Base, AInvoice.PaymentTermCashDiscount3ActualAmount,
    AInvoice.PaymentTermCashDiscount3Note, AInvoice.InvoiceCurrencyCode, erf_PaymentTermCashDiscount3Days, erf_PaymentTermCashDiscount3Percent,
    erf_PaymentTermCashDiscount3Base, erf_PaymentTermCashDiscount3ActualAmount, erf_PaymentTermCashDiscount3Note);
  P.Pop;
  P.Pop;
end;

procedure WriteNotes(P: TPage; AInvoice: TLandrixInvoice);
var
  I: Integer;
  N: TLandrixInvoiceNote;
begin
  if AInvoice.Notes.Count = 0 then
    Exit;
  P.OpenSection(ers_Notes);
  for I := 0 to Integer(AInvoice.Notes.Count) - 1 do
  begin
    N := AInvoice.Notes[I];
    P.OpenItem(erf_Notes, 'item');
    P.Push('<dl>'#10, '</dl>'#10);
    P.Value(erf_Notes_SubjectCode, P.Code(ecl_NoteSubjectCode, LandrixEInvoiceNoteSubjectCodeToStr(N.SubjectCode)));
    P.Value(erf_Notes_SubjectCodeOther, N.SubjectCodeOther);
    P.Value(erf_Notes_Content, N.Content);
    P.Pop;
    P.CloseItem;
  end;
  P.Pop;
end;

{ the facts of each attachment; the data only by its size, an external
  location as text, never as a link
  DE: die Angaben jedes Anhangs; die Daten nur mit ihrer Groesse, ein
  externer Ort als Text, nie als Link }
procedure WriteAttachments(P: TPage; AInvoice: TLandrixInvoice);
var
  I: Integer;
  A: TLandrixInvoiceAttachment;
  Size: Int64;
begin
  if AInvoice.Attachments.Count = 0 then
    Exit;
  P.OpenSection(ers_Attachments);
  for I := 0 to Integer(AInvoice.Attachments.Count) - 1 do
  begin
    A := AInvoice.Attachments[I];
    P.OpenItem(erf_Attachments, 'item');
    P.Push('<dl>'#10, '</dl>'#10);
    P.Value(erf_Attachments_ID, A.ID);
    if A.ID <> '' then
      P.Value(erf_Attachments_SchemeID, P.Code(ecl_ReferenceCodeQualifier, A.SchemeID));
    P.Value(erf_Attachments_TypeCode, P.Code(ecl_TypeCode, LandrixEInvoiceAttachmentTypeCodeToStr(A.TypeCode)));
    P.Value(erf_Attachments_TypeCodeOther, A.TypeCodeOther);
    P.Value(erf_Attachments_DocumentDescription, A.DocumentDescription);
    P.Value(erf_Attachments_Filename, A.Filename);
    P.Value(erf_Attachments_AttachmentType, LandrixEInvoiceAttachmentTypeToStr(A.AttachmentType));
    P.Value(erf_Attachments_AttachmentTypeOther, A.AttachmentTypeOther);
    Size := 0;
    if A.Data <> nil then
      Size := A.Data.Size;
    if Size > 0 then
      P.Value(erf_Attachments_Data, LandrixEInvoiceRenderDecimal(Size, 0, P.Language) + ' ' +
        P.Snippet(Labels[P.Language, lbBytes]));
    P.Value(erf_Attachments_ExternalReference, A.ExternalReference);
    P.Pop;
    P.CloseItem;
  end;
  P.Pop;
end;

{ --- document ---------------------------------------------------------------- }

procedure WriteDocument(P: TPage; ADocument: TLandrixEInvoiceDocument);
var
  Info: TLandrixEInvoiceDocumentInfo;
  D: TLandrixEInvoiceDiagnostic;
  I, Shown: Integer;

  procedure Fact(ALabel: TLabel; const AValue: TLandrixEInvoiceString);
  begin
    if AValue = '' then
      Exit;
    P.Raw('<dt>');
    P.Lbl(ALabel);
    P.Raw('</dt><dd>');
    P.Text(AValue);
    P.Raw('</dd>'#10);
  end;

begin
  Info := ADocument.Info;
  P.Raw('<section data-section="document"><h2>');
  P.Lbl(lbDocument);
  P.Raw('</h2>'#10'<dl>'#10);
  Fact(lbSource, P.Snippet(SourceLabels[P.Language, Info.Source]));
  Fact(lbPdfAttachment, Info.PdfAttachmentName);
  Fact(lbRootName, Info.RootName);
  Fact(lbSyntax, P.Snippet(SyntaxNames[Info.Syntax]));
  Fact(lbCustomizationId, Info.CustomizationID);
  { the specification the library assigns to BT-24
    DE: die Spezifikation, die die Bibliothek BT-24 zuordnet }
  if Info.SpecFound then
  begin
    P.Raw('<dt>');
    P.Lbl(lbSpecification);
    P.Raw('</dt><dd>' + StandardNames[Info.Spec.Target.Standard]);
    if Info.Spec.Target.Version <> '' then
    begin
      P.Raw(' ');
      P.Text(Info.Spec.Target.Version);
    end;
    if Info.Spec.Target.Profile <> epr_None then
      P.Raw(', ' + ProfileNames[Info.Spec.Target.Profile]);
    P.Raw(' (' + SyntaxNames[Info.Spec.Target.Syntax] + ')</dd>'#10);
  end;
  P.Raw('</dl>'#10'<h3>');
  P.Lbl(lbNotTakenOver);
  P.Raw('</h3>'#10);
  Shown := 0;
  for I := 0 to Integer(ADocument.Diagnostics.Count) - 1 do
  begin
    D := ADocument.Diagnostics[I];
    if KindLabels[P.Language, D.Kind] = '' then
      Continue;
    if Shown = 0 then
    begin
      P.Raw('<table class="read"><thead><tr><th>');
      P.Lbl(lbKind);
      P.Raw('</th><th>');
      P.Lbl(lbPosition);
      P.Raw('</th><th>');
      P.Lbl(lbPath);
      P.Raw('</th><th>');
      P.Lbl(lbMessage);
      P.Raw('</th></tr></thead><tbody>'#10);
    end;
    Inc(Shown);
    P.Raw('<tr><td>' + KindLabels[P.Language, D.Kind] + '</td><td>');
    if D.Line > 0 then
    begin
      P.Lbl(lbLine);
      P.Raw(' ');
      P.Int(D.Line);
      if D.Column > 0 then
      begin
        P.Raw(', ');
        P.Lbl(lbColumn);
        P.Raw(' ');
        P.Int(D.Column);
      end;
    end;
    P.Raw('</td><td class="loc">');
    P.Text(D.Path);
    P.Raw('</td><td>');
    P.Text(D.Message);
    P.Raw('</td></tr>'#10);
  end;
  if Shown > 0 then
    P.Raw('</tbody></table>'#10)
  else
  begin
    P.Raw('<p>');
    P.Lbl(lbNothingLeftOut);
    P.Raw('</p>'#10);
  end;
  P.Raw('</section>'#10);
end;

{ --- TLandrixEInvoiceRenderHtmlWriter ------------------------------------- }

function TLandrixEInvoiceRenderHtmlWriter.Build(AInvoice: TLandrixInvoice;
  ADocument: TLandrixEInvoiceDocument): TMemoryStream;
var
  P: TPage;
  Title: TLabel;
begin
  if AInvoice = nil then
    raise ELandrixEInvoiceError.Create('No invoice to render');
  Result := TMemoryStream.Create;
  P := nil;
  try
    P := TPage.Create(Result, FLanguage, FShowBusinessTerms);
    P.Raw('<!DOCTYPE html>'#10'<html xmlns="http://www.w3.org/1999/xhtml" lang="' + LanguageCodes[FLanguage] +
      '">'#10'<head>'#10'<meta charset="utf-8"/>'#10 +
      '<meta name="viewport" content="width=device-width, initial-scale=1"/>'#10'<title>');
    { a credit note (BT-3 = 381, as the UBL writer decides ubl:CreditNote)
      is titled so; every other type is an invoice
      DE: eine Gutschrift (BT-3 = 381, wie der UBL-Writer ubl:CreditNote
      waehlt) heisst so; jede andere Art ist eine Rechnung }
    if AInvoice.InvoiceTypeCode = itc_CreditNote then
      Title := lbCreditNote
    else
      Title := lbTitle;
    P.Lbl(Title);
    if FDocumentName <> '' then
    begin
      P.Raw(': ');
      P.Text(FDocumentName);
    end;
    P.Raw('</title>'#10'<style>' + Css + '</style>'#10'</head>'#10'<body>'#10'<header><h1>');
    P.Lbl(Title);
    P.Raw('</h1>'#10);
    if FDocumentName <> '' then
    begin
      P.Raw('<p class="document">');
      P.Text(FDocumentName);
      P.Raw('</p>'#10);
    end;
    P.Raw('</header>'#10);
    WriteHeader(P, AInvoice);
    WriteParties(P, AInvoice);
    WriteReferences(P, AInvoice);
    WriteLines(P, AInvoice);
    WriteDocumentAllowanceCharges(P, AInvoice);
    WriteVat(P, AInvoice);
    WriteTotals(P, AInvoice);
    WritePayment(P, AInvoice);
    WriteNotes(P, AInvoice);
    WriteAttachments(P, AInvoice);
    if ADocument <> nil then
      WriteDocument(P, ADocument);
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

procedure Emit(APage: TMemoryStream; AStream: TStream);
begin
  try
    if APage.Size > 0 then
      AStream.WriteBuffer(APage.Memory^, Integer(APage.Size));
  finally
    APage.Free;
  end;
end;

function InvoiceOf(ADocument: TLandrixEInvoiceDocument): TLandrixInvoice;
begin
  if ADocument = nil then
    raise ELandrixEInvoiceError.Create('No document to render');
  Result := ADocument.Invoice;
end;

procedure TLandrixEInvoiceRenderHtmlWriter.WriteToStream(AInvoice: TLandrixInvoice; AStream: TStream);
begin
  Emit(Build(AInvoice, nil), AStream);
end;

procedure TLandrixEInvoiceRenderHtmlWriter.WriteToStream(ADocument: TLandrixEInvoiceDocument; AStream: TStream);
begin
  Emit(Build(InvoiceOf(ADocument), ADocument), AStream);
end;

procedure TLandrixEInvoiceRenderHtmlWriter.SaveToFile(AInvoice: TLandrixInvoice; const AFileName: string);
var
  Page: TMemoryStream;
begin
  Page := Build(AInvoice, nil);
  try
    Page.SaveToFile(AFileName);
  finally
    Page.Free;
  end;
end;

procedure TLandrixEInvoiceRenderHtmlWriter.SaveToFile(ADocument: TLandrixEInvoiceDocument;
  const AFileName: string);
var
  Page: TMemoryStream;
begin
  Page := Build(InvoiceOf(ADocument), ADocument);
  try
    Page.SaveToFile(AFileName);
  finally
    Page.Free;
  end;
end;

end.
