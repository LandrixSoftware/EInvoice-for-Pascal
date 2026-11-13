{
  EInvoice-for-Pascal

  Copyright (C) 2026 Landrix Software GmbH & Co. KG

  This file is dual-licensed under:
  - GNU GPL version 3 or later; or
  - the Landrix Software Commercial License.

  See LICENSE and COMMERCIAL-LICENSE.md.

  SPDX-License-Identifier: GPL-3.0-or-later OR LicenseRef-Landrix-Commercial
}

{ The walk through an invoice that every rendering shares, independent of
  the output format. The walk decides what appears where: every set field
  once, in the section LandrixEInvoiceRenderSection assigns to it; sections
  and groups without content are left out, list items are always shown; a
  scheme identifier appears only with its identifier; sub lines nested in
  their line; attachments with their facts, never with their data; nothing
  is computed. A format is a TLandrixEInvoiceRenderTarget: it receives the
  walk as calls (groups, list items, label/value pairs, tables) and writes
  them; a writer (TLandrixEInvoiceRenderWriter) runs the walk into it. The
  walk has no branch per format, so a test of one format proves what the
  walk passes for all.
  DE: Der Gang durch eine Rechnung, den jede Darstellung teilt, unabhaengig
  vom Ausgabeformat. Der Gang entscheidet, was wo erscheint: jedes gesetzte
  Feld einmal, in dem Abschnitt, den LandrixEInvoiceRenderSection ihm
  zuordnet; Abschnitte und Gruppen ohne Inhalt entfallen, Listeneintraege
  erscheinen immer; eine Schemakennung nur mit ihrer Kennung;
  Unterpositionen verschachtelt in ihrer Position; Anhaenge mit ihren
  Angaben, nie mit ihren Daten; nichts wird gerechnet. Ein Format ist ein
  TLandrixEInvoiceRenderTarget: es erhaelt den Gang als Aufrufe (Gruppen,
  Listeneintraege, Beschriftung/Wert-Paare, Tabellen) und schreibt sie; ein
  Writer (TLandrixEInvoiceRenderWriter) laesst den Gang hinein laufen. Der
  Gang hat keinen Zweig je Format, ein Test eines Formats belegt also, was
  der Gang fuer alle uebergibt. }

{ API: internal. May change in any release; use the facade LandrixEInvoice
  or the stable units instead.
  DE: API: intern. Kann sich in jeder Version aendern; stattdessen die
  Fassade LandrixEInvoice oder die stabilen Units verwenden. }

unit LandrixEInvoiceRenderWalk;

{$I LandrixEInvoice.inc}

interface

uses
  Classes,
  LandrixEInvoiceTypes,
  LandrixEInvoiceDiagnostics,
  LandrixEInvoiceReportHtml,
  LandrixEInvoiceCodeNames,
  LandrixEInvoiceRenderLabels,
  LandrixEInvoiceInvoice,
  LandrixEInvoice;

type
  { The texts of a rendering that are not labels of a field.
    DE: Die Texte einer Darstellung, die keine Beschriftung eines Felds
    sind. }
  TLandrixEInvoiceRenderCaption = (erc_Invoice, erc_CreditNote, erc_Yes, erc_No, erc_Allowance, erc_Charge,
    erc_Bytes, erc_Document, erc_Source, erc_RootName, erc_Syntax, erc_CustomizationID, erc_Specification,
    erc_PdfAttachment, erc_NotTakenOver, erc_NothingLeftOut, erc_Kind, erc_Location, erc_Path, erc_Message,
    erc_Line, erc_Column, erc_SanitizedNote, erc_GeneratedBy);

  { A group of the walk that waits for its first value: a section, a group
    of label/value pairs, the short row of a line (its head), the parties,
    the box of one party or of the delivery, the sub lines of a line.
    DE: Eine Gruppe des Gangs, die auf ihren ersten Wert wartet: ein
    Abschnitt, eine Gruppe von Beschriftung/Wert-Paaren, die Kurzzeile einer
    Position (ihr Kopf), die Beteiligten, der Kasten eines Beteiligten oder
    der Lieferung, die Unterpositionen einer Position. }
  TLandrixEInvoiceRenderGroup = (erg_Section, erg_Pairs, erg_LineHead, erg_Parties, erg_Box, erg_SubLines);

  { The receiver of the walk: one subclass per output format. The walk
    calls the Do... methods in document order; a group is opened only when
    the first value below it arrives, and closed only when it was opened.
    Values arrive formatted for Language and are never '' unless a method
    says so; text from the invoice arrives as it is (the target sanitizes
    and escapes it). Order: DoBeginPage, the groups, items, pairs and
    tables of the invoice, for a read document DoBeginDocument, DoFact...,
    DoBeginDiagnostics, DoDiagnostic..., DoEndDocument, then DoEndPage.
    A target writes only to the output its writer gave it.
    DE: Der Empfaenger des Gangs: eine Unterklasse je Ausgabeformat. Der
    Gang ruft die Do...-Methoden in Dokumentreihenfolge; eine Gruppe wird
    erst geoeffnet, wenn der erste Wert darunter ankommt, und nur
    geschlossen, wenn sie geoeffnet wurde. Werte kommen fuer Language
    formatiert an und sind nie '', ausser eine Methode sagt es; Text aus der
    Rechnung kommt, wie er ist (das Ziel bereinigt und maskiert ihn).
    Reihenfolge: DoBeginPage, die Gruppen, Eintraege, Paare und Tabellen der
    Rechnung, bei einem gelesenen Dokument DoBeginDocument, DoFact...,
    DoBeginDiagnostics, DoDiagnostic..., DoEndDocument, dann DoEndPage. Ein
    Ziel schreibt nur in die Ausgabe, die sein Writer ihm gab. }
  TLandrixEInvoiceRenderTarget = class(TObject)
  private
    FLanguage: TLandrixEInvoiceReportLanguage;
    FShowBusinessTerms: Boolean;
    FGroups: array of TLandrixEInvoiceRenderGroup;
    FSections: array of TLandrixEInvoiceRenderSection;
    FFields: array of TLandrixEInvoiceRenderField;
    FOpened: array of Boolean;
    FDepth: Integer;
    FColumnTerms: array of TLandrixEInvoiceString;
    procedure Push(AGroup: TLandrixEInvoiceRenderGroup; ASection: TLandrixEInvoiceRenderSection;
      AField: TLandrixEInvoiceRenderField);
    procedure Flush;
    procedure OpenSection(ASection: TLandrixEInvoiceRenderSection);
    procedure OpenGroup(AGroup: TLandrixEInvoiceRenderGroup; AField: TLandrixEInvoiceRenderField);
    procedure Close;
    procedure Pair(AField: TLandrixEInvoiceRenderField; const AValue, ABT: TLandrixEInvoiceString);
    procedure Value(AField: TLandrixEInvoiceRenderField; const AValue: TLandrixEInvoiceString);
    procedure Money(AField: TLandrixEInvoiceRenderField; AValue: Currency; AAlways: Boolean;
      ACurrencyField: TLandrixEInvoiceRenderField; const ACurrency: TLandrixEInvoiceString);
    procedure ListHeading(AField: TLandrixEInvoiceRenderField);
    procedure OpenItem(AField: TLandrixEInvoiceRenderField);
    procedure CloseItem;
    procedure OpenTable(const AColumns: array of TLandrixEInvoiceRenderField;
      const ATerms: array of TLandrixEInvoiceString);
    function Amount(AValue: Currency): TLandrixEInvoiceString;
    function Decimal(AValue: Double; AMinDecimals: Integer): TLandrixEInvoiceString;
    function DecimalIf(AValue: Double; AMinDecimals: Integer): TLandrixEInvoiceString;
    function Percent(AValue: Double): TLandrixEInvoiceString;
    function PercentIf(AValue: Double): TLandrixEInvoiceString;
    function Date(AValue: TDateTime): TLandrixEInvoiceString;
    function Code(AList: TLandrixEInvoiceCodeList; const ACode: TLandrixEInvoiceString): TLandrixEInvoiceString;
    function YesNo(AValue: Boolean): TLandrixEInvoiceString;
    function ShowsDiagnostic(AKind: TLandrixEInvoiceDiagnosticKind): Boolean;
  protected
    { The page begins: its title (erc_Invoice or erc_CreditNote) and the
      name of the document the caller gave ('' for none).
      DE: Die Seite beginnt: ihr Titel (erc_Invoice oder erc_CreditNote)
      und der Name des Dokuments, den der Aufrufer angab ('' fuer keinen). }
    procedure DoBeginPage(ATitle: TLandrixEInvoiceRenderCaption; const ADocumentName: TLandrixEInvoiceString);
      virtual; abstract;
    { The page ends (after the last section).
      DE: Die Seite endet (nach dem letzten Abschnitt). }
    procedure DoEndPage; virtual; abstract;
    { A group opens (DoOpenGroup) or closes (DoCloseGroup, in reverse order
      of opening). ASection is the section for erg_Section, else the first
      value of its type. AField is the party or the delivery for erg_Box,
      the list of the line for erg_LineHead (erf_InvoiceLines or
      erf_InvoiceLines_SubInvoiceLines), the sub lines for erg_SubLines; for
      erg_Pairs and erg_Parties a field of the group, for orientation only.
      DE: Eine Gruppe beginnt (DoOpenGroup) oder endet (DoCloseGroup, in
      umgekehrter Reihenfolge des Oeffnens). ASection ist der Abschnitt bei
      erg_Section, sonst der erste Wert seines Typs. AField ist der
      Beteiligte oder die Lieferung bei erg_Box, die Liste der Position bei
      erg_LineHead (erf_InvoiceLines oder erf_InvoiceLines_SubInvoiceLines),
      die Unterpositionen bei erg_SubLines; bei erg_Pairs und erg_Parties
      ein Feld der Gruppe, nur zur Orientierung. }
    procedure DoOpenGroup(AGroup: TLandrixEInvoiceRenderGroup; ASection: TLandrixEInvoiceRenderSection;
      AField: TLandrixEInvoiceRenderField); virtual; abstract;
    procedure DoCloseGroup(AGroup: TLandrixEInvoiceRenderGroup); virtual; abstract;
    { The heading of a list (AField the list, ABT its business term).
      DE: Die Ueberschrift einer Liste (AField die Liste, ABT ihr
      Geschaeftsbegriff). }
    procedure DoListHeading(AField: TLandrixEInvoiceRenderField; const ABT: TLandrixEInvoiceString); virtual; abstract;
    { An item of a list opens or closes (AField the list: lines, sub lines,
      preceding invoices, payment means, notes, attachments); items nest
      (sub lines in their line).
      DE: Ein Eintrag einer Liste beginnt oder endet (AField die Liste:
      Positionen, Unterpositionen, Vorgaengerrechnungen, Zahlungsmittel,
      Bemerkungen, Anhaenge); Eintraege sind verschachtelt (Unterpositionen
      in ihrer Position). }
    procedure DoOpenItem(AField: TLandrixEInvoiceRenderField; const ABT: TLandrixEInvoiceString); virtual; abstract;
    procedure DoCloseItem; virtual; abstract;
    { A label/value pair; ABT the business term of this occurrence (''
      for none).
      DE: Ein Paar aus Beschriftung und Wert; ABT der Geschaeftsbegriff
      dieses Vorkommens ('' fuer keinen). }
    procedure DoPair(AField: TLandrixEInvoiceRenderField; const AValue, ABT: TLandrixEInvoiceString); virtual; abstract;
    { An amount with its currency ('' for none); the currency repeats the
      field ACurrencyField, it is not a value of its own.
      DE: Ein Betrag mit seiner Waehrung ('' fuer keine); die Waehrung
      wiederholt das Feld ACurrencyField, sie ist kein eigener Wert. }
    procedure DoMoney(AField: TLandrixEInvoiceRenderField; const AAmount, ABT: TLandrixEInvoiceString;
      ACurrencyField: TLandrixEInvoiceRenderField; const ACurrency: TLandrixEInvoiceString); virtual; abstract;
    { A table with one column per field of AColumns (the business term of a
      column: ColumnTerm), then its rows until DoCloseTable; a table has at
      least one row.
      DE: Eine Tabelle mit einer Spalte je Feld von AColumns (der
      Geschaeftsbegriff einer Spalte: ColumnTerm), dann ihre Zeilen bis
      DoCloseTable; eine Tabelle hat mindestens eine Zeile. }
    procedure DoOpenTable(const AColumns: array of TLandrixEInvoiceRenderField); virtual; abstract;
    procedure DoCloseTable; virtual; abstract;
    { A row of a table (AField the list it shows), with one cell (DoCell,
      or DoOpenCell ... DoCloseCell) per column.
      DE: Eine Zeile einer Tabelle (AField die Liste, die sie zeigt), mit
      einer Zelle (DoCell oder DoOpenCell ... DoCloseCell) je Spalte. }
    procedure DoOpenRow(AField: TLandrixEInvoiceRenderField; const ABT: TLandrixEInvoiceString); virtual; abstract;
    procedure DoCloseRow; virtual; abstract;
    { A cell with one value ('' for an empty cell).
      DE: Eine Zelle mit einem Wert ('' fuer eine leere Zelle). }
    procedure DoCell(AField: TLandrixEInvoiceRenderField; const AValue, ABT: TLandrixEInvoiceString); virtual; abstract;
    { A cell with several values (DoSpan, never ''; no call when all are
      empty), e.g. a code and its free text.
      DE: Eine Zelle mit mehreren Werten (DoSpan, nie ''; kein Aufruf, wenn
      alle leer sind), z. B. ein Code und sein Freitext. }
    procedure DoOpenCell; virtual; abstract;
    procedure DoSpan(AField: TLandrixEInvoiceRenderField; const AValue, ABT: TLandrixEInvoiceString); virtual; abstract;
    procedure DoCloseCell; virtual; abstract;
    { The section of a read document: DoBeginDocument, its facts (DoFact,
      never ''), DoBeginDiagnostics (the facts end), what reading did not
      take over (DoDiagnostic, numbered from 0 in AIndex; no call when
      reading took over everything), DoEndDocument with their number.
      ALine and AColumn are 0 when unknown.
      DE: Der Abschnitt eines gelesenen Dokuments: DoBeginDocument, seine
      Angaben (DoFact, nie ''), DoBeginDiagnostics (die Angaben enden), was
      das Lesen nicht uebernommen hat (DoDiagnostic, ab 0 gezaehlt in AIndex;
      kein Aufruf, wenn das Lesen alles uebernommen hat), DoEndDocument mit
      ihrer Anzahl. ALine und AColumn sind 0, wenn unbekannt. }
    procedure DoBeginDocument; virtual; abstract;
    procedure DoFact(ACaption: TLandrixEInvoiceRenderCaption; const AValue: TLandrixEInvoiceString); virtual; abstract;
    procedure DoBeginDiagnostics; virtual; abstract;
    procedure DoDiagnostic(AIndex: Integer; AKind: TLandrixEInvoiceDiagnosticKind; ALine, AColumn: Integer;
      const APath, AMessage: TLandrixEInvoiceString); virtual; abstract;
    procedure DoEndDocument(ACount: Integer); virtual; abstract;
    { The business term of column AIndex of the table DoOpenTable opens.
      DE: Der Geschaeftsbegriff der Spalte AIndex der Tabelle, die
      DoOpenTable oeffnet. }
    function ColumnTerm(AIndex: Integer): TLandrixEInvoiceString;
    { A caption as text, or as an HTML snippet (ASCII, other characters as
      character references) for targets that write HTML.
      DE: Ein Text als Text oder, fuer Ziele, die HTML schreiben, als
      HTML-Schnipsel (ASCII, andere Zeichen als Zeichenreferenzen). }
    function CaptionSnippet(ACaption: TLandrixEInvoiceRenderCaption): AnsiString;
    function CaptionText(ACaption: TLandrixEInvoiceRenderCaption): TLandrixEInvoiceString;
    { The name of a kind of diagnostic, as HTML snippet or as text.
      DE: Der Name einer Art von Meldung, als HTML-Schnipsel oder als
      Text. }
    function KindSnippet(AKind: TLandrixEInvoiceDiagnosticKind): AnsiString;
    function KindText(AKind: TLandrixEInvoiceDiagnosticKind): TLandrixEInvoiceString;
  public
    constructor Create(ALanguage: TLandrixEInvoiceReportLanguage; AShowBusinessTerms: Boolean);
    { The language of labels and values.
      DE: Die Sprache der Beschriftungen und Werte. }
    property Language: TLandrixEInvoiceReportLanguage read FLanguage;
    { Show the business term (BT-/BG-) next to each label.
      DE: Den Geschaeftsbegriff (BT-/BG-) neben jeder Beschriftung zeigen. }
    property ShowBusinessTerms: Boolean read FShowBusinessTerms;
  end;

  { Renders invoices in the format of its target (CreateTarget). The output
    is built in memory first: if it raises, nothing is written. No time
    stamp: the same invoice gives the same bytes.
    DE: Stellt Rechnungen im Format seines Ziels dar (CreateTarget). Die
    Ausgabe entsteht zuerst im Speicher: loest sie eine Ausnahme aus, wird
    nichts geschrieben. Kein Zeitstempel: dieselbe Rechnung ergibt dieselben
    Bytes. }
  TLandrixEInvoiceRenderWriter = class(TObject)
  private
    FDocumentName: TLandrixEInvoiceString;
    FLanguage: TLandrixEInvoiceReportLanguage;
    FShowBusinessTerms: Boolean;
    function Build(AInvoice: TLandrixInvoice; ADocument: TLandrixEInvoiceDocument): TMemoryStream;
  protected
    { A new target that writes to AOut (not owned) and nowhere else, with
      Language and ShowBusinessTerms.
      DE: Ein neues Ziel, das nach AOut schreibt (gehoert dem Aufrufer) und
      sonst nirgends hin, mit Language und ShowBusinessTerms. }
    function CreateTarget(AOut: TStream): TLandrixEInvoiceRenderTarget; virtual; abstract;
  public
    { Writes the rendering of AInvoice to AStream at its position. AInvoice
      nil raises ELandrixEInvoiceError.
      DE: Schreibt die Darstellung von AInvoice an der Position von AStream.
      AInvoice nil loest ELandrixEInvoiceError aus. }
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
    { The rendering of AInvoice into a file (created or overwritten).
      DE: Die Darstellung von AInvoice in eine Datei (angelegt oder
      ueberschrieben). }
    procedure SaveToFile(AInvoice: TLandrixInvoice; const AFileName: string); overload;
    { The rendering of a read document into a file (created or overwritten).
      DE: Die Darstellung eines gelesenen Dokuments in eine Datei (angelegt
      oder ueberschrieben). }
    procedure SaveToFile(ADocument: TLandrixEInvoiceDocument; const AFileName: string); overload;
    { The rendering of AInvoice as a string: the characters the stream gets
      as UTF-8.
      DE: Die Darstellung von AInvoice als String: die Zeichen, die der
      Stream als UTF-8 erhaelt. }
    function WriteToString(AInvoice: TLandrixInvoice): TLandrixEInvoiceString; overload;
    { The rendering of a read document as a string.
      DE: Die Darstellung eines gelesenen Dokuments als String. }
    function WriteToString(ADocument: TLandrixEInvoiceDocument): TLandrixEInvoiceString; overload;
    { The name of the document as the rendering shows it, '' (the default)
      for none. The caller chooses it; the invoice does not know it.
      DE: Der Name des Dokuments, wie die Darstellung ihn zeigt, ''
      (Vorgabe) fuer keinen. Der Aufrufer waehlt ihn; die Rechnung kennt ihn
      nicht. }
    property DocumentName: TLandrixEInvoiceString read FDocumentName write FDocumentName;
    { The language of the labels (default eln_English).
      DE: Die Sprache der Beschriftungen (Vorgabe eln_English). }
    property Language: TLandrixEInvoiceReportLanguage read FLanguage write FLanguage;
    { Show the business term (BT-/BG-) next to each label (default False).
      DE: Den Geschaeftsbegriff (BT-/BG-) neben jeder Beschriftung zeigen
      (Vorgabe False). }
    property ShowBusinessTerms: Boolean read FShowBusinessTerms write FShowBusinessTerms;
  end;

implementation

uses
  SysUtils,
  LandrixXmlBase,
  LandrixEInvoiceCodes,
  LandrixEInvoiceRender;

const
  { HTML snippets, ASCII with character references }
  Captions: array[TLandrixEInvoiceReportLanguage, TLandrixEInvoiceRenderCaption] of AnsiString = (
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
  SyntaxNames: array[TLandrixEInvoiceSyntax] of AnsiString = ('', 'UBL', 'CII');
  StandardNames: array[TLandrixEInvoiceStandard] of AnsiString = ('', 'XRechnung', 'Factur-X / ZUGFeRD',
    'Peppol BIS');
  ProfileNames: array[TLandrixEInvoiceProfile] of AnsiString = ('', 'MINIMUM', 'BASIC WL', 'BASIC', 'EN 16931',
    'EXTENDED', 'XRECHNUNG');

type
  TFieldList = array of TLandrixEInvoiceRenderField;

{ a snippet as text: its character references decoded }
function SnippetText(const AHtml: AnsiString): TLandrixEInvoiceString;
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

function BTOf(AField: TLandrixEInvoiceRenderField): TLandrixEInvoiceString;
begin
  Result := LandrixEInvoiceRenderFieldBT(AField);
end;

{ --- TLandrixEInvoiceRenderTarget ------------------------------------------ }

constructor TLandrixEInvoiceRenderTarget.Create(ALanguage: TLandrixEInvoiceReportLanguage;
  AShowBusinessTerms: Boolean);
begin
  inherited Create;
  FLanguage := ALanguage;
  FShowBusinessTerms := AShowBusinessTerms;
end;

procedure TLandrixEInvoiceRenderTarget.Push(AGroup: TLandrixEInvoiceRenderGroup;
  ASection: TLandrixEInvoiceRenderSection; AField: TLandrixEInvoiceRenderField);
begin
  if FDepth >= Integer(Length(FGroups)) then
  begin
    SetLength(FGroups, FDepth + 8);
    SetLength(FSections, FDepth + 8);
    SetLength(FFields, FDepth + 8);
    SetLength(FOpened, FDepth + 8);
  end;
  FGroups[FDepth] := AGroup;
  FSections[FDepth] := ASection;
  FFields[FDepth] := AField;
  FOpened[FDepth] := False;
  Inc(FDepth);
end;

{ opens every waiting group }
procedure TLandrixEInvoiceRenderTarget.Flush;
var
  I: Integer;
begin
  for I := 0 to FDepth - 1 do
    if not FOpened[I] then
    begin
      DoOpenGroup(FGroups[I], FSections[I], FFields[I]);
      FOpened[I] := True;
    end;
end;

procedure TLandrixEInvoiceRenderTarget.OpenSection(ASection: TLandrixEInvoiceRenderSection);
begin
  Push(erg_Section, ASection, Low(TLandrixEInvoiceRenderField));
end;

procedure TLandrixEInvoiceRenderTarget.OpenGroup(AGroup: TLandrixEInvoiceRenderGroup;
  AField: TLandrixEInvoiceRenderField);
begin
  Push(AGroup, Low(TLandrixEInvoiceRenderSection), AField);
end;

procedure TLandrixEInvoiceRenderTarget.Close;
begin
  Dec(FDepth);
  if FOpened[FDepth] then
    DoCloseGroup(FGroups[FDepth]);
end;

procedure TLandrixEInvoiceRenderTarget.Pair(AField: TLandrixEInvoiceRenderField;
  const AValue, ABT: TLandrixEInvoiceString);
begin
  if AValue = '' then
    Exit;
  Flush;
  DoPair(AField, AValue, ABT);
end;

procedure TLandrixEInvoiceRenderTarget.Value(AField: TLandrixEInvoiceRenderField; const AValue: TLandrixEInvoiceString);
begin
  Pair(AField, AValue, BTOf(AField));
end;

{ nothing for 0 unless AAlways }
procedure TLandrixEInvoiceRenderTarget.Money(AField: TLandrixEInvoiceRenderField; AValue: Currency; AAlways: Boolean;
  ACurrencyField: TLandrixEInvoiceRenderField; const ACurrency: TLandrixEInvoiceString);
begin
  if (AValue = 0) and not AAlways then
    Exit;
  Flush;
  DoMoney(AField, Amount(AValue), BTOf(AField), ACurrencyField, ACurrency);
end;

procedure TLandrixEInvoiceRenderTarget.ListHeading(AField: TLandrixEInvoiceRenderField);
begin
  Flush;
  DoListHeading(AField, BTOf(AField));
end;

procedure TLandrixEInvoiceRenderTarget.OpenItem(AField: TLandrixEInvoiceRenderField);
begin
  Flush;
  DoOpenItem(AField, BTOf(AField));
end;

procedure TLandrixEInvoiceRenderTarget.CloseItem;
begin
  DoCloseItem;
end;

{ ATerms (empty, or one entry per column, '' for the term of the field)
  gives the term of a column that holds several fields }
procedure TLandrixEInvoiceRenderTarget.OpenTable(const AColumns: array of TLandrixEInvoiceRenderField;
  const ATerms: array of TLandrixEInvoiceString);
var
  I: Integer;
begin
  FColumnTerms := nil;
  SetLength(FColumnTerms, Length(AColumns));
  for I := 0 to Integer(Length(AColumns)) - 1 do
    if (I < Integer(Length(ATerms))) and (ATerms[I] <> '') then
      FColumnTerms[I] := ATerms[I]
    else
      FColumnTerms[I] := BTOf(AColumns[I]);
  Flush;
  DoOpenTable(AColumns);
end;

function TLandrixEInvoiceRenderTarget.ColumnTerm(AIndex: Integer): TLandrixEInvoiceString;
begin
  Result := FColumnTerms[AIndex];
end;

function TLandrixEInvoiceRenderTarget.Amount(AValue: Currency): TLandrixEInvoiceString;
begin
  Result := LandrixEInvoiceRenderAmount(AValue, FLanguage);
end;

function TLandrixEInvoiceRenderTarget.Decimal(AValue: Double; AMinDecimals: Integer): TLandrixEInvoiceString;
begin
  Result := LandrixEInvoiceRenderDecimal(AValue, AMinDecimals, FLanguage);
end;

function TLandrixEInvoiceRenderTarget.DecimalIf(AValue: Double; AMinDecimals: Integer): TLandrixEInvoiceString;
begin
  if AValue = 0 then
    Result := ''
  else
    Result := Decimal(AValue, AMinDecimals);
end;

function TLandrixEInvoiceRenderTarget.Percent(AValue: Double): TLandrixEInvoiceString;
begin
  Result := LandrixEInvoiceRenderPercent(AValue, FLanguage);
end;

function TLandrixEInvoiceRenderTarget.PercentIf(AValue: Double): TLandrixEInvoiceString;
begin
  if AValue = 0 then
    Result := ''
  else
    Result := Percent(AValue);
end;

function TLandrixEInvoiceRenderTarget.Date(AValue: TDateTime): TLandrixEInvoiceString;
begin
  if AValue = 0 then
    Result := ''
  else
    Result := LandrixEInvoiceRenderDate(AValue, FLanguage);
end;

function TLandrixEInvoiceRenderTarget.Code(AList: TLandrixEInvoiceCodeList;
  const ACode: TLandrixEInvoiceString): TLandrixEInvoiceString;
begin
  Result := LandrixEInvoiceRenderCode(AList, ACode, FLanguage);
end;

function TLandrixEInvoiceRenderTarget.YesNo(AValue: Boolean): TLandrixEInvoiceString;
begin
  if AValue then
    Result := CaptionText(erc_Yes)
  else
    Result := CaptionText(erc_No);
end;

{ the diagnostics of reading that mean content did not reach the model }
function TLandrixEInvoiceRenderTarget.ShowsDiagnostic(AKind: TLandrixEInvoiceDiagnosticKind): Boolean;
begin
  Result := KindLabels[FLanguage, AKind] <> '';
end;

function TLandrixEInvoiceRenderTarget.CaptionSnippet(ACaption: TLandrixEInvoiceRenderCaption): AnsiString;
begin
  Result := Captions[FLanguage, ACaption];
end;

function TLandrixEInvoiceRenderTarget.CaptionText(ACaption: TLandrixEInvoiceRenderCaption): TLandrixEInvoiceString;
begin
  Result := SnippetText(Captions[FLanguage, ACaption]);
end;

function TLandrixEInvoiceRenderTarget.KindSnippet(AKind: TLandrixEInvoiceDiagnosticKind): AnsiString;
begin
  Result := KindLabels[FLanguage, AKind];
end;

function TLandrixEInvoiceRenderTarget.KindText(AKind: TLandrixEInvoiceDiagnosticKind): TLandrixEInvoiceString;
begin
  Result := SnippetText(KindLabels[FLanguage, AKind]);
end;

{ --- the walk ------------------------------------------------------------------ }

function Columns(const AFields: array of TLandrixEInvoiceRenderField): TFieldList;
var
  I: Integer;
begin
  Result := nil;
  SetLength(Result, Length(AFields));
  for I := 0 to Integer(Length(AFields)) - 1 do
    Result[I] := AFields[I];
end;

procedure WriteHeader(T: TLandrixEInvoiceRenderTarget; AInvoice: TLandrixInvoice);
begin
  T.OpenSection(ers_Header);
  T.OpenGroup(erg_Pairs, erf_InvoiceNumber);
  T.Value(erf_InvoiceNumber, AInvoice.InvoiceNumber);
  T.Value(erf_InvoiceIssueDate, T.Date(AInvoice.InvoiceIssueDate));
  T.Value(erf_InvoiceTypeCode, T.Code(ecl_TypeCode, LandrixEInvoiceTypeCodeToStr(AInvoice.InvoiceTypeCode)));
  T.Value(erf_InvoiceTypeCodeOther, AInvoice.InvoiceTypeCodeOther);
  T.Value(erf_InvoiceDueDate, T.Date(AInvoice.InvoiceDueDate));
  T.Value(erf_InvoicePeriodStartDate, T.Date(AInvoice.InvoicePeriodStartDate));
  T.Value(erf_InvoicePeriodEndDate, T.Date(AInvoice.InvoicePeriodEndDate));
  T.Value(erf_InvoiceCurrencyCode, T.Code(ecl_CurrencyCode, AInvoice.InvoiceCurrencyCode));
  T.Value(erf_TaxCurrencyCode, T.Code(ecl_CurrencyCode, AInvoice.TaxCurrencyCode));
  if AInvoice.TaxPointDate.HasValue then
    T.Value(erf_TaxPointDate, LandrixEInvoiceRenderDate(AInvoice.TaxPointDate.Value, T.Language));
  T.Value(erf_TaxPointDateCode, AInvoice.TaxPointDateCode);
  T.Value(erf_BuyerReference, AInvoice.BuyerReference);
  T.Value(erf_ProfileID, AInvoice.ProfileID);
  if AInvoice.TestIndicator.HasValue then
    T.Value(erf_TestIndicator, T.YesNo(AInvoice.TestIndicator.Value));
  T.Value(erf_DocumentName, AInvoice.DocumentName);
  T.Close;
  T.Close;
end;

procedure WriteAddress(T: TLandrixEInvoiceRenderTarget; AAddress: TLandrixInvoiceAddress;
  ABase: TLandrixEInvoiceRenderField);
const
  B = erf_AccountingSupplierParty_Address;
begin
  T.Value(Like(ABase, B, erf_AccountingSupplierParty_Address_StreetName), AAddress.StreetName);
  T.Value(Like(ABase, B, erf_AccountingSupplierParty_Address_AdditionalStreetName), AAddress.AdditionalStreetName);
  T.Value(Like(ABase, B, erf_AccountingSupplierParty_Address_AddressLine), AAddress.AddressLine);
  T.Value(Like(ABase, B, erf_AccountingSupplierParty_Address_PostalZone), AAddress.PostalZone);
  T.Value(Like(ABase, B, erf_AccountingSupplierParty_Address_City), AAddress.City);
  T.Value(Like(ABase, B, erf_AccountingSupplierParty_Address_CountrySubentity), AAddress.CountrySubentity);
  T.Value(Like(ABase, B, erf_AccountingSupplierParty_Address_CountryCode),
    T.Code(ecl_CountryCode, AAddress.CountryCode));
end;

{ seller or buyer; the creditor identifier of the seller is shown with the
  payment
  DE: Verkaeufer oder Kaeufer; die Glaeubiger-ID des Verkaeufers erscheint
  bei der Zahlung }
procedure WriteAccountingParty(T: TLandrixEInvoiceRenderTarget; AParty: TLandrixInvoiceAccountingParty;
  ABase: TLandrixEInvoiceRenderField);
const
  B = erf_AccountingSupplierParty;
begin
  T.OpenGroup(erg_Box, ABase);
  T.Value(Like(ABase, B, erf_AccountingSupplierParty_RegistrationName), AParty.RegistrationName);
  T.Value(Like(ABase, B, erf_AccountingSupplierParty_Name), AParty.Name);
  WriteAddress(T, AParty.Address, Like(ABase, B, erf_AccountingSupplierParty_Address));
  T.Value(Like(ABase, B, erf_AccountingSupplierParty_IdentifierSellerBuyer), AParty.IdentifierSellerBuyer);
  T.Value(Like(ABase, B, erf_AccountingSupplierParty_GlobalIdentifierSellerBuyer),
    AParty.GlobalIdentifierSellerBuyer);
  if AParty.GlobalIdentifierSellerBuyer <> '' then
    T.Value(Like(ABase, B, erf_AccountingSupplierParty_GlobalIdentifierSellerBuyerSchemeID),
      T.Code(ecl_IdentifierScheme, AParty.GlobalIdentifierSellerBuyerSchemeID));
  T.Value(Like(ABase, B, erf_AccountingSupplierParty_CompanyID), AParty.CompanyID);
  if AParty.CompanyID <> '' then
    T.Value(Like(ABase, B, erf_AccountingSupplierParty_CompanyIDSchemeID),
      T.Code(ecl_IdentifierScheme, AParty.CompanyIDSchemeID));
  T.Value(Like(ABase, B, erf_AccountingSupplierParty_VATCompanyID), AParty.VATCompanyID);
  T.Value(Like(ABase, B, erf_AccountingSupplierParty_VATCompanyNumber), AParty.VATCompanyNumber);
  T.Value(Like(ABase, B, erf_AccountingSupplierParty_ElectronicAddressSellerBuyer),
    AParty.ElectronicAddressSellerBuyer);
  if AParty.ElectronicAddressSellerBuyer <> '' then
    T.Value(Like(ABase, B, erf_AccountingSupplierParty_ElectronicAddressSellerBuyerSchemeID),
      T.Code(ecl_ElectronicAddressScheme, AParty.ElectronicAddressSellerBuyerSchemeID));
  T.Value(Like(ABase, B, erf_AccountingSupplierParty_ContactName), AParty.ContactName);
  T.Value(Like(ABase, B, erf_AccountingSupplierParty_ContactDepartment), AParty.ContactDepartment);
  T.Value(Like(ABase, B, erf_AccountingSupplierParty_ContactTelephone), AParty.ContactTelephone);
  T.Value(Like(ABase, B, erf_AccountingSupplierParty_ContactElectronicMail), AParty.ContactElectronicMail);
  T.Value(Like(ABase, B, erf_AccountingSupplierParty_AdditionalLegalInformationSeller),
    AParty.AdditionalLegalInformationSeller);
  if ABase <> erf_AccountingSupplierParty then
    T.Value(Like(ABase, B, erf_AccountingSupplierParty_BankAssignedCreditorIdentifier),
      AParty.BankAssignedCreditorIdentifier);
  T.Close;
end;

{ payee, tax representative, invoicee
  DE: Zahlungsempfaenger, Steuervertreter, Rechnungsempfaenger }
procedure WriteParty(T: TLandrixEInvoiceRenderTarget; AParty: TLandrixInvoiceParty; ABase: TLandrixEInvoiceRenderField);
const
  B = erf_PayeeParty;
begin
  T.OpenGroup(erg_Box, ABase);
  T.Value(Like(ABase, B, erf_PayeeParty_Name), AParty.Name);
  WriteAddress(T, AParty.Address, Like(ABase, B, erf_PayeeParty_Address));
  T.Value(Like(ABase, B, erf_PayeeParty_Identifier), AParty.Identifier);
  if AParty.Identifier <> '' then
    T.Value(Like(ABase, B, erf_PayeeParty_IdentifierSchemeID), T.Code(ecl_IdentifierScheme,
      AParty.IdentifierSchemeID));
  T.Value(Like(ABase, B, erf_PayeeParty_CompanyID), AParty.CompanyID);
  if AParty.CompanyID <> '' then
    T.Value(Like(ABase, B, erf_PayeeParty_CompanyIDSchemeID), T.Code(ecl_IdentifierScheme,
      AParty.CompanyIDSchemeID));
  T.Value(Like(ABase, B, erf_PayeeParty_VATCompanyID), AParty.VATCompanyID);
  T.Value(Like(ABase, B, erf_PayeeParty_ContactName), AParty.ContactName);
  T.Value(Like(ABase, B, erf_PayeeParty_ContactDepartment), AParty.ContactDepartment);
  T.Value(Like(ABase, B, erf_PayeeParty_ContactTelephone), AParty.ContactTelephone);
  T.Value(Like(ABase, B, erf_PayeeParty_ContactElectronicMail), AParty.ContactElectronicMail);
  T.Close;
end;

procedure WriteParties(T: TLandrixEInvoiceRenderTarget; AInvoice: TLandrixInvoice);
var
  D: TLandrixInvoiceDeliveryInformation;
begin
  T.OpenSection(ers_Parties);
  T.OpenGroup(erg_Parties, erf_AccountingSupplierParty);
  WriteAccountingParty(T, AInvoice.AccountingSupplierParty, erf_AccountingSupplierParty);
  WriteAccountingParty(T, AInvoice.AccountingCustomerParty, erf_AccountingCustomerParty);
  WriteParty(T, AInvoice.InvoiceeParty, erf_InvoiceeParty);
  WriteParty(T, AInvoice.PayeeParty, erf_PayeeParty);
  WriteParty(T, AInvoice.TaxRepresentativeParty, erf_TaxRepresentativeParty);
  D := AInvoice.DeliveryInformation;
  T.OpenGroup(erg_Box, erf_DeliveryInformation);
  T.Value(erf_DeliveryInformation_Name, D.Name);
  WriteAddress(T, D.Address, erf_DeliveryInformation_Address);
  T.Value(erf_DeliveryInformation_LocationIdentifier, D.LocationIdentifier);
  if D.LocationIdentifier <> '' then
    T.Value(erf_DeliveryInformation_LocationIdentifierSchemeID, T.Code(ecl_IdentifierScheme,
      D.LocationIdentifierSchemeID));
  T.Value(erf_DeliveryInformation_ActualDeliveryDate, T.Date(D.ActualDeliveryDate));
  T.Value(erf_DeliveryInformation_ContactName, D.ContactName);
  T.Value(erf_DeliveryInformation_ContactTelephone, D.ContactTelephone);
  T.Value(erf_DeliveryInformation_ContactElectronicMail, D.ContactElectronicMail);
  T.Close;
  T.Close;
  T.Close;
end;

procedure WriteReferences(T: TLandrixEInvoiceRenderTarget; AInvoice: TLandrixInvoice);
var
  I: Integer;
  R: TLandrixInvoicePrecedingInvoiceReference;
begin
  T.OpenSection(ers_References);
  T.OpenGroup(erg_Pairs, erf_SellerOrderReference);
  T.Value(erf_SellerOrderReference, AInvoice.SellerOrderReference);
  if AInvoice.SellerOrderReferenceDate.HasValue then
    T.Value(erf_SellerOrderReferenceDate, LandrixEInvoiceRenderDate(AInvoice.SellerOrderReferenceDate.Value,
      T.Language));
  T.Value(erf_PurchaseOrderReference, AInvoice.PurchaseOrderReference);
  if AInvoice.PurchaseOrderReferenceDate.HasValue then
    T.Value(erf_PurchaseOrderReferenceDate, LandrixEInvoiceRenderDate(AInvoice.PurchaseOrderReferenceDate.Value,
      T.Language));
  T.Value(erf_ContractDocumentReference, AInvoice.ContractDocumentReference);
  T.Value(erf_ProjectReference, AInvoice.ProjectReference);
  T.Value(erf_ReceiptDocumentReference, AInvoice.ReceiptDocumentReference);
  T.Value(erf_DeliveryReceiptNumber, AInvoice.DeliveryReceiptNumber);
  T.Value(erf_DeliveryReceiptDate, T.Date(AInvoice.DeliveryReceiptDate));
  T.Value(erf_DeliveryReceiptNumberExtended, AInvoice.DeliveryReceiptNumberExtended);
  T.Value(erf_DeliveryReceiptDateExtended, T.Date(AInvoice.DeliveryReceiptDateExtended));
  T.Value(erf_BuyerAccountingReference, AInvoice.BuyerAccountingReference);
  T.Close;
  if AInvoice.PrecedingInvoiceReferences.Count > 0 then
  begin
    T.ListHeading(erf_PrecedingInvoiceReferences);
    for I := 0 to Integer(AInvoice.PrecedingInvoiceReferences.Count) - 1 do
    begin
      R := AInvoice.PrecedingInvoiceReferences[I];
      T.OpenItem(erf_PrecedingInvoiceReferences);
      T.OpenGroup(erg_Pairs, erf_PrecedingInvoiceReferences);
      T.Value(erf_PrecedingInvoiceReferences_ID, R.ID);
      T.Value(erf_PrecedingInvoiceReferences_IssueDate, T.Date(R.IssueDate));
      T.Close;
      T.CloseItem;
    end;
  end;
  T.Close;
end;

{ the VAT cells (category, rate) of the row of A
  DE: die Steuerzellen (Kategorie, Satz) der Zeile von A }
procedure WriteAllowanceTax(T: TLandrixEInvoiceRenderTarget; A: TLandrixInvoiceAllowanceCharge;
  ABase: TLandrixEInvoiceRenderField);
const
  B = erf_AllowanceCharges;
var
  Category: TLandrixEInvoiceString;
  ShowRate: Boolean;

  function F(ATemplate: TLandrixEInvoiceRenderField): TLandrixEInvoiceRenderField;
  begin
    Result := Like(ABase, B, ATemplate);
  end;

  function BT(ATemplate: TLandrixEInvoiceRenderField): TLandrixEInvoiceString;
  begin
    Result := AllowanceOrChargeTerm(BTOf(F(ATemplate)), A.ChargeIndicator);
  end;

  procedure Span(ATemplate: TLandrixEInvoiceRenderField; const AValue: TLandrixEInvoiceString);
  begin
    if AValue <> '' then
      T.DoSpan(F(ATemplate), AValue, BT(ATemplate));
  end;

begin
  T.DoOpenCell;
  Span(erf_AllowanceCharges_TaxCategory, T.Code(ecl_DutyTaxFeeCategoryCode,
    LandrixEInvoiceDutyTaxFeeCategoryCodeToStr(A.TaxCategory)));
  Span(erf_AllowanceCharges_TaxCategoryOther, A.TaxCategoryOther);
  T.DoCloseCell;
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
    T.DoCell(F(erf_AllowanceCharges_TaxPercent), T.Percent(A.TaxPercent), BT(erf_AllowanceCharges_TaxPercent))
  else
    T.DoCell(F(erf_AllowanceCharges_TaxPercent), '', BT(erf_AllowanceCharges_TaxPercent));
end;

{ document level (ABase erf_AllowanceCharges) or line level
  (erf_InvoiceLines_AllowanceCharges); the terms of a row follow its kind
  DE: Belegebene (ABase erf_AllowanceCharges) oder Positionsebene
  (erf_InvoiceLines_AllowanceCharges); die Begriffe einer Zeile folgen
  ihrer Art }
procedure WriteAllowanceCharges(T: TLandrixEInvoiceRenderTarget; AList: TLandrixInvoiceAllowanceCharges;
  ABase: TLandrixEInvoiceRenderField);
const
  B = erf_AllowanceCharges;
var
  I: Integer;
  A: TLandrixInvoiceAllowanceCharge;
  Kind: TLandrixEInvoiceString;
  HasTax, HasExemption: Boolean;

  function F(ATemplate: TLandrixEInvoiceRenderField): TLandrixEInvoiceRenderField;
  begin
    Result := Like(ABase, B, ATemplate);
  end;

  { the columns: the VAT columns with HasTax, the exemption columns with
    HasExemption }
  function TableColumns: TFieldList;
  var
    N: Integer;
  begin
    Result := Columns([F(erf_AllowanceCharges_ChargeIndicator), F(erf_AllowanceCharges_ReasonCodeAllowance),
      F(erf_AllowanceCharges_Reason), F(erf_AllowanceCharges_BaseAmount),
      F(erf_AllowanceCharges_MultiplierFactorNumeric), F(erf_AllowanceCharges_Amount)]);
    N := Integer(Length(Result));
    if HasTax then
    begin
      SetLength(Result, N + 2);
      Result[N] := F(erf_AllowanceCharges_TaxCategory);
      Result[N + 1] := F(erf_AllowanceCharges_TaxPercent);
      N := N + 2;
    end;
    if HasExemption then
    begin
      SetLength(Result, N + 2);
      Result[N] := F(erf_AllowanceCharges_TaxExemptionReasonCode);
      Result[N + 1] := F(erf_AllowanceCharges_TaxExemptionReason);
    end;
  end;

  function BT(ATemplate: TLandrixEInvoiceRenderField): TLandrixEInvoiceString;
  begin
    Result := AllowanceOrChargeTerm(BTOf(F(ATemplate)), A.ChargeIndicator);
  end;

  procedure Cell(ATemplate: TLandrixEInvoiceRenderField; const AValue: TLandrixEInvoiceString);
  begin
    T.DoCell(F(ATemplate), AValue, BT(ATemplate));
  end;

  procedure Span(ATemplate: TLandrixEInvoiceRenderField; const AValue: TLandrixEInvoiceString);
  begin
    if AValue <> '' then
      T.DoSpan(F(ATemplate), AValue, BT(ATemplate));
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
  { the exemption columns (BT-173, BT-174, Factur-X EXTENDED) only when an
    item has a reason or a code
    DE: die Befreiungsspalten (BT-173, BT-174, Factur-X EXTENDED) nur, wenn
    ein Eintrag einen Grund oder Code hat }
  HasExemption := False;
  for I := 0 to Integer(AList.Count) - 1 do
    if (AList[I].TaxExemptionReason <> '') or (AList[I].TaxExemptionReasonCode <> '') then
      HasExemption := True;
  { the code column holds the codes of allowances and of charges
    DE: die Code-Spalte enthaelt die Codes von Abschlaegen und Zuschlaegen }
  Kind := BTOf(F(erf_AllowanceCharges_ReasonCodeAllowance)) + '/' + BTOf(F(erf_AllowanceCharges_ReasonCodeCharge));
  T.OpenTable(TableColumns, ['', Kind]);
  for I := 0 to Integer(AList.Count) - 1 do
  begin
    A := AList[I];
    T.DoOpenRow(ABase, BTOf(ABase));
    if A.ChargeIndicator then
      Kind := T.CaptionText(erc_Charge)
    else
      Kind := T.CaptionText(erc_Allowance);
    Cell(erf_AllowanceCharges_ChargeIndicator, Kind);
    T.DoOpenCell;
    Span(erf_AllowanceCharges_ReasonCodeAllowance, T.Code(ecl_AllowanceOrChargeIdentCode,
      LandrixEInvoiceAllowanceOrChargeIdentCodeToStr(A.ReasonCodeAllowance)));
    Span(erf_AllowanceCharges_ReasonCodeAllowanceOther, A.ReasonCodeAllowanceOther);
    Span(erf_AllowanceCharges_ReasonCodeCharge, T.Code(ecl_SpecialServiceDescriptionCode,
      LandrixEInvoiceSpecialServiceDescriptionCodeToStr(A.ReasonCodeCharge)));
    Span(erf_AllowanceCharges_ReasonCodeChargeOther, A.ReasonCodeChargeOther);
    T.DoCloseCell;
    Cell(erf_AllowanceCharges_Reason, A.Reason);
    { the base as the writers write it: with a percentage also when 0
      DE: die Basis, wie die Writer sie schreiben: mit Prozentsatz auch bei 0 }
    if (A.BaseAmount <> 0) or (A.MultiplierFactorNumeric <> 0) then
      Cell(erf_AllowanceCharges_BaseAmount, T.Amount(A.BaseAmount))
    else
      Cell(erf_AllowanceCharges_BaseAmount, '');
    Cell(erf_AllowanceCharges_MultiplierFactorNumeric, T.PercentIf(A.MultiplierFactorNumeric));
    Cell(erf_AllowanceCharges_Amount, T.Amount(A.Amount));
    if HasTax then
      WriteAllowanceTax(T, A, ABase);
    if HasExemption then
    begin
      Cell(erf_AllowanceCharges_TaxExemptionReasonCode, T.Code(ecl_VATExemptionReasonCode,
        A.TaxExemptionReasonCode));
      Cell(erf_AllowanceCharges_TaxExemptionReason, A.TaxExemptionReason);
    end;
    T.DoCloseRow;
  end;
  T.DoCloseTable;
end;

procedure WriteLine(T: TLandrixEInvoiceRenderTarget; ALine: TLandrixInvoiceLine; AContainer: TLandrixEInvoiceRenderField);
var
  I: Integer;
  C: TLandrixInvoiceLineItemClassification;
  A: TLandrixInvoiceLineItemAttribute;

  procedure Cell(AField: TLandrixEInvoiceRenderField; const AValue: TLandrixEInvoiceString);
  begin
    T.DoCell(AField, AValue, BTOf(AField));
  end;

begin
  T.OpenItem(AContainer);
  { the short row: what, how many, at which price, which VAT, how much
    DE: die Kurzzeile: was, wie viel, zu welchem Preis, welche Steuer,
    welcher Betrag }
  T.OpenGroup(erg_LineHead, AContainer);
  T.Value(erf_InvoiceLines_ID, ALine.ID);
  T.Value(erf_InvoiceLines_Name, ALine.Name);
  T.Value(erf_InvoiceLines_Quantity, T.Decimal(ALine.Quantity, 0));
  T.Value(erf_InvoiceLines_UnitCode, T.Code(ecl_UnitCode, LandrixEInvoiceUnitCodeToStr(ALine.UnitCode)));
  T.Value(erf_InvoiceLines_UnitCodeOther, ALine.UnitCodeOther);
  T.Value(erf_InvoiceLines_NetPriceAmount, T.Decimal(ALine.NetPriceAmount, 2));
  T.Value(erf_InvoiceLines_TaxCategory, T.Code(ecl_DutyTaxFeeCategoryCode,
    LandrixEInvoiceDutyTaxFeeCategoryCodeToStr(ALine.TaxCategory)));
  T.Value(erf_InvoiceLines_TaxCategoryOther, ALine.TaxCategoryOther);
  T.Value(erf_InvoiceLines_TaxPercent, T.Percent(ALine.TaxPercent));
  T.Value(erf_InvoiceLines_LineAmount, T.Amount(ALine.LineAmount));
  T.Close;
  T.OpenGroup(erg_Pairs, AContainer);
  T.Value(erf_InvoiceLines_Description, ALine.Description);
  T.Value(erf_InvoiceLines_Note, ALine.Note);
  if ALine.LineStatusReasonCode <> ilsrc_None then
    T.Value(erf_InvoiceLines_LineStatusReasonCode, SnippetText(LineStatusLabels[T.Language,
      ALine.LineStatusReasonCode]) + ' (' + SnippetText(LineStatusCodes[ALine.LineStatusReasonCode]) + ')');
  T.Value(erf_InvoiceLines_LineStatusReasonCodeOther, ALine.LineStatusReasonCodeOther);
  T.Value(erf_InvoiceLines_SellersItemIdentification, ALine.SellersItemIdentification);
  T.Value(erf_InvoiceLines_BuyersItemIdentification, ALine.BuyersItemIdentification);
  T.Value(erf_InvoiceLines_GlobalID_EAN_GTIN, ALine.GlobalID_EAN_GTIN);
  T.Value(erf_InvoiceLines_StandardItemIdentifier, ALine.StandardItemIdentifier);
  if ALine.StandardItemIdentifier <> '' then
    T.Value(erf_InvoiceLines_StandardItemIdentifierSchemeID, T.Code(ecl_IdentifierScheme,
      ALine.StandardItemIdentifierSchemeID));
  T.Value(erf_InvoiceLines_ObjectIdentifier, ALine.ObjectIdentifier);
  if ALine.ObjectIdentifier <> '' then
    T.Value(erf_InvoiceLines_ObjectIdentifierSchemeID, T.Code(ecl_ReferenceCodeQualifier,
      ALine.ObjectIdentifierSchemeID));
  T.Value(erf_InvoiceLines_OriginTradeCountry, T.Code(ecl_CountryCode, ALine.OriginTradeCountry));
  T.Value(erf_InvoiceLines_GrossPriceAmount, T.DecimalIf(ALine.GrossPriceAmount, 2));
  T.Value(erf_InvoiceLines_DiscountOnTheGrossPrice, T.DecimalIf(ALine.DiscountOnTheGrossPrice, 2));
  T.Value(erf_InvoiceLines_BaseQuantity, T.DecimalIf(ALine.BaseQuantity, 0));
  T.Value(erf_InvoiceLines_BaseQuantityUnitCode, T.Code(ecl_UnitCode,
    LandrixEInvoiceUnitCodeToStr(ALine.BaseQuantityUnitCode)));
  T.Value(erf_InvoiceLines_BaseQuantityUnitCodeOther, ALine.BaseQuantityUnitCodeOther);
  T.Value(erf_InvoiceLines_TaxExemptionReason, ALine.TaxExemptionReason);
  T.Value(erf_InvoiceLines_InvoiceLinePeriodStartDate, T.Date(ALine.InvoiceLinePeriodStartDate));
  T.Value(erf_InvoiceLines_InvoiceLinePeriodEndDate, T.Date(ALine.InvoiceLinePeriodEndDate));
  T.Value(erf_InvoiceLines_OrderNumber, ALine.OrderNumber);
  if ALine.OrderDate.HasValue then
    T.Value(erf_InvoiceLines_OrderDate, LandrixEInvoiceRenderDate(ALine.OrderDate.Value, T.Language));
  T.Value(erf_InvoiceLines_OrderLineReference, ALine.OrderLineReference);
  T.Value(erf_InvoiceLines_BuyerAccountingReference, ALine.BuyerAccountingReference);
  T.Value(erf_InvoiceLines_DeliveryNoteNumber, ALine.DeliveryNoteNumber);
  T.Value(erf_InvoiceLines_DeliveryNoteLineID, ALine.DeliveryNoteLineID);
  T.Value(erf_InvoiceLines_DeliveryNoteDate, T.Date(ALine.DeliveryNoteDate));
  T.Value(erf_InvoiceLines_ActualDeliveryDate, T.Date(ALine.ActualDeliveryDate));
  T.Close;
  if ALine.AllowanceCharges.Count > 0 then
  begin
    T.ListHeading(erf_InvoiceLines_AllowanceCharges);
    WriteAllowanceCharges(T, ALine.AllowanceCharges, erf_InvoiceLines_AllowanceCharges);
  end;
  if ALine.ItemAttributes.Count > 0 then
  begin
    T.ListHeading(erf_InvoiceLines_ItemAttributes);
    T.OpenTable([erf_InvoiceLines_ItemAttributes_Name, erf_InvoiceLines_ItemAttributes_Value], ['']);
    for I := 0 to Integer(ALine.ItemAttributes.Count) - 1 do
    begin
      A := ALine.ItemAttributes[I];
      T.DoOpenRow(erf_InvoiceLines_ItemAttributes, BTOf(erf_InvoiceLines_ItemAttributes));
      Cell(erf_InvoiceLines_ItemAttributes_Name, A.Name);
      Cell(erf_InvoiceLines_ItemAttributes_Value, A.Value);
      T.DoCloseRow;
    end;
    T.DoCloseTable;
  end;
  if ALine.ItemClassifications.Count > 0 then
  begin
    T.ListHeading(erf_InvoiceLines_ItemClassifications);
    T.OpenTable([erf_InvoiceLines_ItemClassifications_ClassCode, erf_InvoiceLines_ItemClassifications_ListID,
      erf_InvoiceLines_ItemClassifications_ListVersionID, erf_InvoiceLines_ItemClassifications_ClassificationName],
      ['']);
    for I := 0 to Integer(ALine.ItemClassifications.Count) - 1 do
    begin
      C := ALine.ItemClassifications[I];
      T.DoOpenRow(erf_InvoiceLines_ItemClassifications, BTOf(erf_InvoiceLines_ItemClassifications));
      Cell(erf_InvoiceLines_ItemClassifications_ClassCode, C.ClassCode);
      Cell(erf_InvoiceLines_ItemClassifications_ListID, T.Code(ecl_ItemClassificationScheme, C.ListID));
      Cell(erf_InvoiceLines_ItemClassifications_ListVersionID, C.ListVersionID);
      Cell(erf_InvoiceLines_ItemClassifications_ClassificationName, C.ClassificationName);
      T.DoCloseRow;
    end;
    T.DoCloseTable;
  end;
  if ALine.SubInvoiceLines.Count > 0 then
  begin
    T.OpenGroup(erg_SubLines, erf_InvoiceLines_SubInvoiceLines);
    for I := 0 to Integer(ALine.SubInvoiceLines.Count) - 1 do
      WriteLine(T, ALine.SubInvoiceLines[I], erf_InvoiceLines_SubInvoiceLines);
    T.Close;
  end;
  T.CloseItem;
end;

procedure WriteLines(T: TLandrixEInvoiceRenderTarget; AInvoice: TLandrixInvoice);
var
  I: Integer;
begin
  T.OpenSection(ers_Lines);
  for I := 0 to Integer(AInvoice.InvoiceLines.Count) - 1 do
    WriteLine(T, AInvoice.InvoiceLines[I], erf_InvoiceLines);
  T.Close;
end;

procedure WriteDocumentAllowanceCharges(T: TLandrixEInvoiceRenderTarget; AInvoice: TLandrixInvoice);
begin
  T.OpenSection(ers_Allowances);
  WriteAllowanceCharges(T, AInvoice.AllowanceCharges, erf_AllowanceCharges);
  T.Close;
end;

procedure WriteVat(T: TLandrixEInvoiceRenderTarget; AInvoice: TLandrixInvoice);
var
  I: Integer;
  V: TLandrixInvoiceTaxAmount;

  procedure Cell(AField: TLandrixEInvoiceRenderField; const AValue: TLandrixEInvoiceString);
  begin
    T.DoCell(AField, AValue, BTOf(AField));
  end;

  procedure Span(AField: TLandrixEInvoiceRenderField; const AValue: TLandrixEInvoiceString);
  begin
    if AValue <> '' then
      T.DoSpan(AField, AValue, BTOf(AField));
  end;

begin
  if AInvoice.TaxAmountSubtotals.Count = 0 then
    Exit;
  T.OpenSection(ers_Vat);
  T.OpenTable([erf_TaxAmountSubtotals_TaxCategory, erf_TaxAmountSubtotals_TaxPercent,
    erf_TaxAmountSubtotals_TaxableAmount, erf_TaxAmountSubtotals_TaxAmount,
    erf_TaxAmountSubtotals_TaxExemptionReasonCode, erf_TaxAmountSubtotals_TaxExemptionReason], ['']);
  for I := 0 to Integer(AInvoice.TaxAmountSubtotals.Count) - 1 do
  begin
    V := AInvoice.TaxAmountSubtotals[I];
    T.DoOpenRow(erf_TaxAmountSubtotals, BTOf(erf_TaxAmountSubtotals));
    T.DoOpenCell;
    Span(erf_TaxAmountSubtotals_TaxCategory, T.Code(ecl_DutyTaxFeeCategoryCode,
      LandrixEInvoiceDutyTaxFeeCategoryCodeToStr(V.TaxCategory)));
    Span(erf_TaxAmountSubtotals_TaxCategoryOther, V.TaxCategoryOther);
    T.DoCloseCell;
    Cell(erf_TaxAmountSubtotals_TaxPercent, T.Percent(V.TaxPercent));
    Cell(erf_TaxAmountSubtotals_TaxableAmount, T.Amount(V.TaxableAmount));
    Cell(erf_TaxAmountSubtotals_TaxAmount, T.Amount(V.TaxAmount));
    Cell(erf_TaxAmountSubtotals_TaxExemptionReasonCode, T.Code(ecl_VATExemptionReasonCode,
      V.TaxExemptionReasonCode));
    Cell(erf_TaxAmountSubtotals_TaxExemptionReason, V.TaxExemptionReason);
    T.DoCloseRow;
  end;
  T.DoCloseTable;
  T.Close;
end;

{ the totals EN 16931 requires are shown even when 0
  DE: die Summen, die EN 16931 verlangt, erscheinen auch bei 0 }
procedure WriteTotals(T: TLandrixEInvoiceRenderTarget; AInvoice: TLandrixInvoice);
var
  I: Integer;
  R: TLandrixInvoicePrepaidPayment;
  Cur: TLandrixEInvoiceString;

  procedure Cell(AField: TLandrixEInvoiceRenderField; const AValue: TLandrixEInvoiceString);
  begin
    T.DoCell(AField, AValue, BTOf(AField));
  end;

begin
  T.OpenSection(ers_Totals);
  T.OpenGroup(erg_Pairs, erf_LineAmount);
  Cur := AInvoice.InvoiceCurrencyCode;
  T.Money(erf_LineAmount, AInvoice.LineAmount, True, erf_InvoiceCurrencyCode, Cur);
  T.Money(erf_AllowanceTotalAmount, AInvoice.AllowanceTotalAmount, False, erf_InvoiceCurrencyCode, Cur);
  T.Money(erf_ChargeTotalAmount, AInvoice.ChargeTotalAmount, False, erf_InvoiceCurrencyCode, Cur);
  T.Money(erf_TaxExclusiveAmount, AInvoice.TaxExclusiveAmount, True, erf_InvoiceCurrencyCode, Cur);
  T.Money(erf_TaxAmountTotal, AInvoice.TaxAmountTotal, True, erf_InvoiceCurrencyCode, Cur);
  if AInvoice.TaxAmountTotalInTaxCurrency.HasValue then
    T.Money(erf_TaxAmountTotalInTaxCurrency, AInvoice.TaxAmountTotalInTaxCurrency.Value, True,
      erf_TaxCurrencyCode, AInvoice.TaxCurrencyCode);
  T.Money(erf_TaxInclusiveAmount, AInvoice.TaxInclusiveAmount, True, erf_InvoiceCurrencyCode, Cur);
  T.Money(erf_PrepaidAmount, AInvoice.PrepaidAmount, False, erf_InvoiceCurrencyCode, Cur);
  T.Money(erf_PayableRoundingAmount, AInvoice.PayableRoundingAmount, False, erf_InvoiceCurrencyCode, Cur);
  T.Money(erf_PayableAmount, AInvoice.PayableAmount, True, erf_InvoiceCurrencyCode, Cur);
  T.Close;
  if AInvoice.PrepaidPayments.Count > 0 then
  begin
    T.ListHeading(erf_PrepaidPayments);
    T.OpenTable([erf_PrepaidPayments_ID, erf_PrepaidPayments_PaidAmount, erf_PrepaidPayments_PaidAmountCurrencyID,
      erf_PrepaidPayments_InstructionID], ['']);
    for I := 0 to Integer(AInvoice.PrepaidPayments.Count) - 1 do
    begin
      R := AInvoice.PrepaidPayments[I];
      T.DoOpenRow(erf_PrepaidPayments, BTOf(erf_PrepaidPayments));
      Cell(erf_PrepaidPayments_ID, R.ID);
      Cell(erf_PrepaidPayments_PaidAmount, T.Amount(R.PaidAmount));
      Cell(erf_PrepaidPayments_PaidAmountCurrencyID, T.Code(ecl_CurrencyCode, R.PaidAmountCurrencyID));
      Cell(erf_PrepaidPayments_InstructionID, R.InstructionID);
      T.DoCloseRow;
    end;
    T.DoCloseTable;
  end;
  T.Close;
end;

procedure WriteCashDiscount(T: TLandrixEInvoiceRenderTarget; ADays: Integer; APercent: Double;
  ABase, AAmount: Currency; const ANote, ACurrency: TLandrixEInvoiceString; AFieldDays, AFieldPercent, AFieldBase,
  AFieldAmount, AFieldNote: TLandrixEInvoiceRenderField);
begin
  if ADays <> 0 then
    T.Value(AFieldDays, TLandrixEInvoiceString(IntToStr(ADays)));
  T.Value(AFieldPercent, T.PercentIf(APercent));
  T.Money(AFieldBase, ABase, False, erf_InvoiceCurrencyCode, ACurrency);
  T.Money(AFieldAmount, AAmount, False, erf_InvoiceCurrencyCode, ACurrency);
  T.Value(AFieldNote, ANote);
end;

procedure WritePayment(T: TLandrixEInvoiceRenderTarget; AInvoice: TLandrixInvoice);
var
  I: Integer;
  P: TLandrixInvoicePaymentType;
begin
  T.OpenSection(ers_Payment);
  T.OpenGroup(erg_Pairs, erf_PaymentID);
  T.Value(erf_PaymentID, AInvoice.PaymentID);
  T.Value(erf_PaymentMandateID, AInvoice.PaymentMandateID);
  T.Value(erf_AccountingSupplierParty_BankAssignedCreditorIdentifier,
    AInvoice.AccountingSupplierParty.BankAssignedCreditorIdentifier);
  T.Close;
  if AInvoice.PaymentTypes.Count > 0 then
  begin
    T.ListHeading(erf_PaymentTypes);
    for I := 0 to Integer(AInvoice.PaymentTypes.Count) - 1 do
    begin
      P := AInvoice.PaymentTypes[I];
      T.OpenItem(erf_PaymentTypes);
      T.OpenGroup(erg_Pairs, erf_PaymentTypes);
      T.Value(erf_PaymentTypes_PaymentMeansCode, T.Code(ecl_PaymentMeansCode,
        LandrixEInvoicePaymentMeansCodeToStr(P.PaymentMeansCode)));
      T.Value(erf_PaymentTypes_PaymentMeansCodeOther, P.PaymentMeansCodeOther);
      T.Value(erf_PaymentTypes_PaymentMeansInformation, P.PaymentMeansInformation);
      T.Value(erf_PaymentTypes_FinancialAccount, P.FinancialAccount);
      T.Value(erf_PaymentTypes_FinancialAccountName, P.FinancialAccountName);
      T.Value(erf_PaymentTypes_FinancialInstitutionBranch, P.FinancialInstitutionBranch);
      T.Close;
      T.CloseItem;
    end;
  end;
  T.OpenGroup(erg_Pairs, erf_PaymentTermsType);
  T.Value(erf_PaymentTermsType, SnippetText(PaymentTermsLabels[T.Language, AInvoice.PaymentTermsType]));
  T.Value(erf_PaymentTermNetNote, AInvoice.PaymentTermNetNote);
  WriteCashDiscount(T, AInvoice.PaymentTermCashDiscount1Days, AInvoice.PaymentTermCashDiscount1Percent,
    AInvoice.PaymentTermCashDiscount1Base, AInvoice.PaymentTermCashDiscount1ActualAmount,
    AInvoice.PaymentTermCashDiscount1Note, AInvoice.InvoiceCurrencyCode, erf_PaymentTermCashDiscount1Days,
    erf_PaymentTermCashDiscount1Percent, erf_PaymentTermCashDiscount1Base, erf_PaymentTermCashDiscount1ActualAmount,
    erf_PaymentTermCashDiscount1Note);
  WriteCashDiscount(T, AInvoice.PaymentTermCashDiscount2Days, AInvoice.PaymentTermCashDiscount2Percent,
    AInvoice.PaymentTermCashDiscount2Base, AInvoice.PaymentTermCashDiscount2ActualAmount,
    AInvoice.PaymentTermCashDiscount2Note, AInvoice.InvoiceCurrencyCode, erf_PaymentTermCashDiscount2Days,
    erf_PaymentTermCashDiscount2Percent, erf_PaymentTermCashDiscount2Base, erf_PaymentTermCashDiscount2ActualAmount,
    erf_PaymentTermCashDiscount2Note);
  WriteCashDiscount(T, AInvoice.PaymentTermCashDiscount3Days, AInvoice.PaymentTermCashDiscount3Percent,
    AInvoice.PaymentTermCashDiscount3Base, AInvoice.PaymentTermCashDiscount3ActualAmount,
    AInvoice.PaymentTermCashDiscount3Note, AInvoice.InvoiceCurrencyCode, erf_PaymentTermCashDiscount3Days,
    erf_PaymentTermCashDiscount3Percent, erf_PaymentTermCashDiscount3Base, erf_PaymentTermCashDiscount3ActualAmount,
    erf_PaymentTermCashDiscount3Note);
  T.Close;
  T.Close;
end;

procedure WriteNotes(T: TLandrixEInvoiceRenderTarget; AInvoice: TLandrixInvoice);
var
  I: Integer;
  N: TLandrixInvoiceNote;
begin
  if AInvoice.Notes.Count = 0 then
    Exit;
  T.OpenSection(ers_Notes);
  for I := 0 to Integer(AInvoice.Notes.Count) - 1 do
  begin
    N := AInvoice.Notes[I];
    T.OpenItem(erf_Notes);
    T.OpenGroup(erg_Pairs, erf_Notes);
    T.Value(erf_Notes_SubjectCode, T.Code(ecl_NoteSubjectCode, LandrixEInvoiceNoteSubjectCodeToStr(N.SubjectCode)));
    T.Value(erf_Notes_SubjectCodeOther, N.SubjectCodeOther);
    T.Value(erf_Notes_Content, N.Content);
    T.Close;
    T.CloseItem;
  end;
  T.Close;
end;

{ the facts of each attachment; the data only by its size, an external
  location as text, never as a link
  DE: die Angaben jedes Anhangs; die Daten nur mit ihrer Groesse, ein
  externer Ort als Text, nie als Link }
procedure WriteAttachments(T: TLandrixEInvoiceRenderTarget; AInvoice: TLandrixInvoice);
var
  I: Integer;
  A: TLandrixInvoiceAttachment;
  Size: Int64;
begin
  if AInvoice.Attachments.Count = 0 then
    Exit;
  T.OpenSection(ers_Attachments);
  for I := 0 to Integer(AInvoice.Attachments.Count) - 1 do
  begin
    A := AInvoice.Attachments[I];
    T.OpenItem(erf_Attachments);
    T.OpenGroup(erg_Pairs, erf_Attachments);
    T.Value(erf_Attachments_ID, A.ID);
    if A.ID <> '' then
      T.Value(erf_Attachments_SchemeID, T.Code(ecl_ReferenceCodeQualifier, A.SchemeID));
    T.Value(erf_Attachments_TypeCode, T.Code(ecl_TypeCode, LandrixEInvoiceAttachmentTypeCodeToStr(A.TypeCode)));
    T.Value(erf_Attachments_TypeCodeOther, A.TypeCodeOther);
    T.Value(erf_Attachments_DocumentDescription, A.DocumentDescription);
    T.Value(erf_Attachments_Filename, A.Filename);
    T.Value(erf_Attachments_AttachmentType, LandrixEInvoiceAttachmentTypeToStr(A.AttachmentType));
    T.Value(erf_Attachments_AttachmentTypeOther, A.AttachmentTypeOther);
    Size := 0;
    if A.Data <> nil then
      Size := A.Data.Size;
    if Size > 0 then
      T.Value(erf_Attachments_Data, LandrixEInvoiceRenderDecimal(Size, 0, T.Language) + ' ' +
        T.CaptionText(erc_Bytes));
    T.Value(erf_Attachments_ExternalReference, A.ExternalReference);
    T.Close;
    T.CloseItem;
  end;
  T.Close;
end;

{ where a read document came from and what reading did not take over
  DE: woher ein gelesenes Dokument kam und was das Lesen nicht uebernommen
  hat }
procedure WriteDocument(T: TLandrixEInvoiceRenderTarget; ADocument: TLandrixEInvoiceDocument);
var
  Info: TLandrixEInvoiceDocumentInfo;
  D: TLandrixEInvoiceDiagnostic;
  I, Shown: Integer;
  Spec: TLandrixEInvoiceString;

  procedure Fact(ACaption: TLandrixEInvoiceRenderCaption; const AValue: TLandrixEInvoiceString);
  begin
    if AValue <> '' then
      T.DoFact(ACaption, AValue);
  end;

begin
  Info := ADocument.Info;
  T.DoBeginDocument;
  Fact(erc_Source, SnippetText(SourceLabels[T.Language, Info.Source]));
  Fact(erc_PdfAttachment, Info.PdfAttachmentName);
  Fact(erc_RootName, Info.RootName);
  Fact(erc_Syntax, SnippetText(SyntaxNames[Info.Syntax]));
  Fact(erc_CustomizationID, Info.CustomizationID);
  { the specification the library assigns to BT-24
    DE: die Spezifikation, die die Bibliothek BT-24 zuordnet }
  if Info.SpecFound then
  begin
    Spec := SnippetText(StandardNames[Info.Spec.Target.Standard]);
    if Info.Spec.Target.Version <> '' then
      Spec := Spec + ' ' + Info.Spec.Target.Version;
    if Info.Spec.Target.Profile <> epr_None then
      Spec := Spec + ', ' + SnippetText(ProfileNames[Info.Spec.Target.Profile]);
    Spec := Spec + ' (' + SnippetText(SyntaxNames[Info.Spec.Target.Syntax]) + ')';
    T.DoFact(erc_Specification, Spec);
  end;
  T.DoBeginDiagnostics;
  Shown := 0;
  for I := 0 to Integer(ADocument.Diagnostics.Count) - 1 do
  begin
    D := ADocument.Diagnostics[I];
    if not T.ShowsDiagnostic(D.Kind) then
      Continue;
    T.DoDiagnostic(Shown, D.Kind, D.Line, D.Column, D.Path, D.Message);
    Inc(Shown);
  end;
  T.DoEndDocument(Shown);
end;

procedure WalkInvoice(T: TLandrixEInvoiceRenderTarget; AInvoice: TLandrixInvoice;
  ADocument: TLandrixEInvoiceDocument; const ADocumentName: TLandrixEInvoiceString);
begin
  { a credit note (BT-3 = 381, as the UBL writer decides ubl:CreditNote)
    is titled so; every other type is an invoice
    DE: eine Gutschrift (BT-3 = 381, wie der UBL-Writer ubl:CreditNote
    waehlt) heisst so; jede andere Art ist eine Rechnung }
  if AInvoice.InvoiceTypeCode = itc_CreditNote then
    T.DoBeginPage(erc_CreditNote, ADocumentName)
  else
    T.DoBeginPage(erc_Invoice, ADocumentName);
  WriteHeader(T, AInvoice);
  WriteParties(T, AInvoice);
  WriteReferences(T, AInvoice);
  WriteLines(T, AInvoice);
  WriteDocumentAllowanceCharges(T, AInvoice);
  WriteVat(T, AInvoice);
  WriteTotals(T, AInvoice);
  WritePayment(T, AInvoice);
  WriteNotes(T, AInvoice);
  WriteAttachments(T, AInvoice);
  if ADocument <> nil then
    WriteDocument(T, ADocument);
  T.DoEndPage;
end;

{ --- TLandrixEInvoiceRenderWriter ------------------------------------------ }

function TLandrixEInvoiceRenderWriter.Build(AInvoice: TLandrixInvoice;
  ADocument: TLandrixEInvoiceDocument): TMemoryStream;
var
  T: TLandrixEInvoiceRenderTarget;
begin
  if AInvoice = nil then
    raise ELandrixEInvoiceError.Create('No invoice to render');
  Result := TMemoryStream.Create;
  T := nil;
  try
    T := CreateTarget(Result);
    WalkInvoice(T, AInvoice, ADocument, FDocumentName);
  except
    T.Free;
    Result.Free;
    raise;
  end;
  T.Free;
  Result.Position := 0;
end;

procedure Emit(AOutput: TMemoryStream; AStream: TStream);
begin
  try
    if AOutput.Size > 0 then
      AStream.WriteBuffer(AOutput.Memory^, Integer(AOutput.Size));
  finally
    AOutput.Free;
  end;
end;

function InvoiceOf(ADocument: TLandrixEInvoiceDocument): TLandrixInvoice;
begin
  if ADocument = nil then
    raise ELandrixEInvoiceError.Create('No document to render');
  Result := ADocument.Invoice;
end;

procedure SaveOutput(AOutput: TMemoryStream; const AFileName: string);
begin
  try
    AOutput.SaveToFile(AFileName);
  finally
    AOutput.Free;
  end;
end;

function OutputString(AOutput: TMemoryStream): TLandrixEInvoiceString;
var
  S: TLandrixXmlUtf8;
begin
  try
    S := '';
    SetLength(S, Integer(AOutput.Size));
    if AOutput.Size > 0 then
      Move(AOutput.Memory^, PAnsiChar(S)^, Integer(AOutput.Size));
    Result := LandrixEInvoiceUtf8ToString(S);
  finally
    AOutput.Free;
  end;
end;

procedure TLandrixEInvoiceRenderWriter.WriteToStream(AInvoice: TLandrixInvoice; AStream: TStream);
begin
  Emit(Build(AInvoice, nil), AStream);
end;

procedure TLandrixEInvoiceRenderWriter.WriteToStream(ADocument: TLandrixEInvoiceDocument; AStream: TStream);
begin
  Emit(Build(InvoiceOf(ADocument), ADocument), AStream);
end;

procedure TLandrixEInvoiceRenderWriter.SaveToFile(AInvoice: TLandrixInvoice; const AFileName: string);
begin
  SaveOutput(Build(AInvoice, nil), AFileName);
end;

procedure TLandrixEInvoiceRenderWriter.SaveToFile(ADocument: TLandrixEInvoiceDocument; const AFileName: string);
begin
  SaveOutput(Build(InvoiceOf(ADocument), ADocument), AFileName);
end;

function TLandrixEInvoiceRenderWriter.WriteToString(AInvoice: TLandrixInvoice): TLandrixEInvoiceString;
begin
  Result := OutputString(Build(AInvoice, nil));
end;

function TLandrixEInvoiceRenderWriter.WriteToString(ADocument: TLandrixEInvoiceDocument): TLandrixEInvoiceString;
begin
  Result := OutputString(Build(InvoiceOf(ADocument), ADocument));
end;

end.
