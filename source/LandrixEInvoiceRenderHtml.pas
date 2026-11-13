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
  LandrixEInvoiceRenderWalk;

type
  { Writes invoices as HTML pages (methods and properties: see
    TLandrixEInvoiceRenderWriter). The page marks the business terms in
    data-bt whether ShowBusinessTerms is set or not.
    DE: Schreibt Rechnungen als HTML-Seiten (Methoden und Eigenschaften:
    siehe TLandrixEInvoiceRenderWriter). Die Seite kennzeichnet die
    Geschaeftsbegriffe in data-bt, ob ShowBusinessTerms gesetzt ist oder
    nicht. }
  TLandrixEInvoiceRenderHtmlWriter = class(TLandrixEInvoiceRenderWriter)
  protected
    function CreateTarget(AOut: TStream): TLandrixEInvoiceRenderTarget; override;
  end;

implementation

uses
  LandrixEInvoiceTypes,
  LandrixEInvoiceDiagnostics,
  LandrixEInvoiceReportHtml,
  LandrixEInvoiceRenderLabels;

const
  LanguageCodes: array[TLandrixEInvoiceReportLanguage] of AnsiString = ('en', 'de');

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
  { the page: every call of the walk as HTML }
  THtmlTarget = class(TLandrixEInvoiceRenderTarget)
  private
    FB: TLandrixEInvoiceHtmlBuilder;
    procedure Raw(const S: AnsiString);
    procedure Text(const S: TLandrixEInvoiceString);
    procedure Lbl(ACaption: TLandrixEInvoiceRenderCaption);
    { the business term after a label, when shown }
    procedure Term(const ABT: TLandrixEInvoiceString);
    { data-field and data-bt attributes }
    procedure Marks(AField: TLandrixEInvoiceRenderField; const ABT: TLandrixEInvoiceString);
  protected
    procedure DoBeginPage(ATitle: TLandrixEInvoiceRenderCaption; const ADocumentName: TLandrixEInvoiceString);
      override;
    procedure DoEndPage; override;
    procedure DoOpenGroup(AGroup: TLandrixEInvoiceRenderGroup; ASection: TLandrixEInvoiceRenderSection;
      AField: TLandrixEInvoiceRenderField); override;
    procedure DoCloseGroup(AGroup: TLandrixEInvoiceRenderGroup); override;
    procedure DoListHeading(AField: TLandrixEInvoiceRenderField; const ABT: TLandrixEInvoiceString); override;
    procedure DoOpenItem(AField: TLandrixEInvoiceRenderField; const ABT: TLandrixEInvoiceString); override;
    procedure DoCloseItem; override;
    procedure DoPair(AField: TLandrixEInvoiceRenderField; const AValue, ABT: TLandrixEInvoiceString); override;
    procedure DoMoney(AField: TLandrixEInvoiceRenderField; const AAmount, ABT: TLandrixEInvoiceString;
      ACurrencyField: TLandrixEInvoiceRenderField; const ACurrency: TLandrixEInvoiceString); override;
    procedure DoOpenTable(const AColumns: array of TLandrixEInvoiceRenderField); override;
    procedure DoCloseTable; override;
    procedure DoOpenRow(AField: TLandrixEInvoiceRenderField; const ABT: TLandrixEInvoiceString); override;
    procedure DoCloseRow; override;
    procedure DoCell(AField: TLandrixEInvoiceRenderField; const AValue, ABT: TLandrixEInvoiceString); override;
    procedure DoOpenCell; override;
    procedure DoSpan(AField: TLandrixEInvoiceRenderField; const AValue, ABT: TLandrixEInvoiceString); override;
    procedure DoCloseCell; override;
    procedure DoBeginDocument; override;
    procedure DoFact(ACaption: TLandrixEInvoiceRenderCaption; const AValue: TLandrixEInvoiceString); override;
    procedure DoBeginDiagnostics; override;
    procedure DoDiagnostic(AIndex: Integer; AKind: TLandrixEInvoiceDiagnosticKind; ALine, AColumn: Integer;
      const APath, AMessage: TLandrixEInvoiceString); override;
    procedure DoEndDocument(ACount: Integer); override;
  public
    constructor Create(AOut: TStream; ALanguage: TLandrixEInvoiceReportLanguage; AShowBusinessTerms: Boolean);
    destructor Destroy; override;
  end;

constructor THtmlTarget.Create(AOut: TStream; ALanguage: TLandrixEInvoiceReportLanguage;
  AShowBusinessTerms: Boolean);
begin
  inherited Create(ALanguage, AShowBusinessTerms);
  FB := TLandrixEInvoiceHtmlBuilder.Create(AOut, ALanguage);
end;

destructor THtmlTarget.Destroy;
begin
  FB.Free;
  inherited Destroy;
end;

procedure THtmlTarget.Raw(const S: AnsiString);
begin
  FB.Raw(S);
end;

procedure THtmlTarget.Text(const S: TLandrixEInvoiceString);
begin
  FB.Text(S);
end;

procedure THtmlTarget.Lbl(ACaption: TLandrixEInvoiceRenderCaption);
begin
  Raw(CaptionSnippet(ACaption));
end;

procedure THtmlTarget.Term(const ABT: TLandrixEInvoiceString);
begin
  if ShowBusinessTerms and (ABT <> '') then
  begin
    Raw(' <span class="bt">');
    Text(ABT);
    Raw('</span>');
  end;
end;

procedure THtmlTarget.Marks(AField: TLandrixEInvoiceRenderField; const ABT: TLandrixEInvoiceString);
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

procedure THtmlTarget.DoBeginPage(ATitle: TLandrixEInvoiceRenderCaption; const ADocumentName: TLandrixEInvoiceString);
begin
  Raw('<!DOCTYPE html>'#10'<html xmlns="http://www.w3.org/1999/xhtml" lang="' + LanguageCodes[Language] +
    '">'#10'<head>'#10'<meta charset="utf-8"/>'#10 +
    '<meta name="viewport" content="width=device-width, initial-scale=1"/>'#10'<title>');
  Lbl(ATitle);
  if ADocumentName <> '' then
  begin
    Raw(': ');
    Text(ADocumentName);
  end;
  Raw('</title>'#10'<style>' + Css + '</style>'#10'</head>'#10'<body>'#10'<header><h1>');
  Lbl(ATitle);
  Raw('</h1>'#10);
  if ADocumentName <> '' then
  begin
    Raw('<p class="document">');
    Text(ADocumentName);
    Raw('</p>'#10);
  end;
  Raw('</header>'#10);
end;

procedure THtmlTarget.DoEndPage;
begin
  Raw('<footer>');
  if FB.Sanitized then
  begin
    Raw('<p class="note">');
    Lbl(erc_SanitizedNote);
    Raw('</p>');
  end;
  Raw('<p>');
  Lbl(erc_GeneratedBy);
  Raw(' EInvoice-for-Pascal ' + LandrixEInvoiceVersion + '</p></footer>'#10'</body>'#10'</html>'#10);
end;

procedure THtmlTarget.DoOpenGroup(AGroup: TLandrixEInvoiceRenderGroup; ASection: TLandrixEInvoiceRenderSection;
  AField: TLandrixEInvoiceRenderField);
var
  BT: TLandrixEInvoiceString;
begin
  case AGroup of
    erg_Section:
      begin
        Raw('<section data-section="');
        Text(LandrixEInvoiceRenderSectionKey(ASection));
        Raw('"><h2>');
        Text(LandrixEInvoiceRenderSectionLabel(ASection, Language));
        Raw('</h2>'#10);
      end;
    erg_Pairs:
      Raw('<dl>'#10);
    erg_LineHead:
      Raw('<dl class="head">'#10);
    erg_Parties:
      Raw('<div class="parties">'#10);
    erg_Box:
      begin
        BT := LandrixEInvoiceRenderFieldBT(AField);
        Raw('<div class="box"');
        Marks(AField, BT);
        Raw('><h3>');
        Text(LandrixEInvoiceRenderFieldLabel(AField, Language));
        Term(BT);
        Raw('</h3>'#10'<dl>'#10);
      end;
    erg_SubLines:
      Raw('<div class="sublines">'#10);
  end;
end;

procedure THtmlTarget.DoCloseGroup(AGroup: TLandrixEInvoiceRenderGroup);
begin
  case AGroup of
    erg_Section:
      Raw('</section>'#10);
    erg_Pairs, erg_LineHead:
      Raw('</dl>'#10);
    erg_Parties, erg_SubLines:
      Raw('</div>'#10);
    erg_Box:
      Raw('</dl></div>'#10);
  end;
end;

procedure THtmlTarget.DoListHeading(AField: TLandrixEInvoiceRenderField; const ABT: TLandrixEInvoiceString);
begin
  Raw('<h4>');
  Text(LandrixEInvoiceRenderFieldLabel(AField, Language));
  Term(ABT);
  Raw('</h4>'#10);
end;

procedure THtmlTarget.DoOpenItem(AField: TLandrixEInvoiceRenderField; const ABT: TLandrixEInvoiceString);
begin
  if (AField = erf_InvoiceLines) or (AField = erf_InvoiceLines_SubInvoiceLines) then
    Raw('<div class="line"')
  else
    Raw('<div class="item"');
  Marks(AField, ABT);
  Raw('>'#10);
end;

procedure THtmlTarget.DoCloseItem;
begin
  Raw('</div>'#10);
end;

procedure THtmlTarget.DoPair(AField: TLandrixEInvoiceRenderField; const AValue, ABT: TLandrixEInvoiceString);
begin
  Raw('<dt>');
  Text(LandrixEInvoiceRenderFieldLabel(AField, Language));
  Term(ABT);
  Raw('</dt><dd');
  Marks(AField, ABT);
  Raw('>');
  Text(AValue);
  Raw('</dd>'#10);
end;

{ the currency is marked data-ref: it repeats ACurrencyField }
procedure THtmlTarget.DoMoney(AField: TLandrixEInvoiceRenderField; const AAmount, ABT: TLandrixEInvoiceString;
  ACurrencyField: TLandrixEInvoiceRenderField; const ACurrency: TLandrixEInvoiceString);
begin
  Raw('<dt>');
  Text(LandrixEInvoiceRenderFieldLabel(AField, Language));
  Term(ABT);
  Raw('</dt><dd');
  Marks(AField, ABT);
  Raw('>');
  Text(AAmount);
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

procedure THtmlTarget.DoOpenTable(const AColumns: array of TLandrixEInvoiceRenderField);
var
  I: Integer;
begin
  Raw('<table><thead><tr>');
  for I := 0 to Integer(Length(AColumns)) - 1 do
  begin
    Raw('<th>');
    Text(LandrixEInvoiceRenderFieldLabel(AColumns[I], Language));
    Term(ColumnTerm(I));
    Raw('</th>');
  end;
  Raw('</tr></thead><tbody>'#10);
end;

procedure THtmlTarget.DoCloseTable;
begin
  Raw('</tbody></table>'#10);
end;

procedure THtmlTarget.DoOpenRow(AField: TLandrixEInvoiceRenderField; const ABT: TLandrixEInvoiceString);
begin
  Raw('<tr');
  Marks(AField, ABT);
  Raw('>');
end;

procedure THtmlTarget.DoCloseRow;
begin
  Raw('</tr>'#10);
end;

procedure THtmlTarget.DoCell(AField: TLandrixEInvoiceRenderField; const AValue, ABT: TLandrixEInvoiceString);
begin
  Raw('<td');
  Marks(AField, ABT);
  Raw('>');
  Text(AValue);
  Raw('</td>');
end;

procedure THtmlTarget.DoOpenCell;
begin
  Raw('<td>');
end;

procedure THtmlTarget.DoSpan(AField: TLandrixEInvoiceRenderField; const AValue, ABT: TLandrixEInvoiceString);
begin
  Raw('<span');
  Marks(AField, ABT);
  Raw('>');
  Text(AValue);
  Raw('</span>');
end;

procedure THtmlTarget.DoCloseCell;
begin
  Raw('</td>');
end;

procedure THtmlTarget.DoBeginDocument;
begin
  Raw('<section data-section="document"><h2>');
  Lbl(erc_Document);
  Raw('</h2>'#10'<dl>'#10);
end;

procedure THtmlTarget.DoFact(ACaption: TLandrixEInvoiceRenderCaption; const AValue: TLandrixEInvoiceString);
begin
  Raw('<dt>');
  Lbl(ACaption);
  Raw('</dt><dd>');
  Text(AValue);
  Raw('</dd>'#10);
end;

procedure THtmlTarget.DoBeginDiagnostics;
begin
  Raw('</dl>'#10'<h3>');
  Lbl(erc_NotTakenOver);
  Raw('</h3>'#10);
end;

procedure THtmlTarget.DoDiagnostic(AIndex: Integer; AKind: TLandrixEInvoiceDiagnosticKind; ALine, AColumn: Integer;
  const APath, AMessage: TLandrixEInvoiceString);
begin
  if AIndex = 0 then
  begin
    Raw('<table class="read"><thead><tr><th>');
    Lbl(erc_Kind);
    Raw('</th><th>');
    Lbl(erc_Location);
    Raw('</th><th>');
    Lbl(erc_Path);
    Raw('</th><th>');
    Lbl(erc_Message);
    Raw('</th></tr></thead><tbody>'#10);
  end;
  Raw('<tr><td>' + KindSnippet(AKind) + '</td><td>');
  if ALine > 0 then
  begin
    Lbl(erc_Line);
    Raw(' ');
    FB.Int(ALine);
    if AColumn > 0 then
    begin
      Raw(', ');
      Lbl(erc_Column);
      Raw(' ');
      FB.Int(AColumn);
    end;
  end;
  Raw('</td><td class="loc">');
  Text(APath);
  Raw('</td><td>');
  Text(AMessage);
  Raw('</td></tr>'#10);
end;

procedure THtmlTarget.DoEndDocument(ACount: Integer);
begin
  if ACount > 0 then
    Raw('</tbody></table>'#10)
  else
  begin
    Raw('<p>');
    Lbl(erc_NothingLeftOut);
    Raw('</p>'#10);
  end;
  Raw('</section>'#10);
end;

{ --- TLandrixEInvoiceRenderHtmlWriter ------------------------------------- }

function TLandrixEInvoiceRenderHtmlWriter.CreateTarget(AOut: TStream): TLandrixEInvoiceRenderTarget;
begin
  Result := THtmlTarget.Create(AOut, Language, ShowBusinessTerms);
end;

end.
