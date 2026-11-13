{
  EInvoice-for-Pascal

  Copyright (C) 2026 Landrix Software GmbH & Co. KG

  This file is dual-licensed under:
  - GNU GPL version 3 or later; or
  - the Landrix Software Commercial License.

  See LICENSE and COMMERCIAL-LICENSE.md.

  SPDX-License-Identifier: GPL-3.0-or-later OR LicenseRef-Landrix-Commercial
}

{ An invoice as Markdown for people: text for a log, a ticket, a mail or a
  terminal, readable as it is and as rendered CommonMark. The content is the
  walk of LandrixEInvoiceRenderWalk, the same as on the HTML page. Form:
  '#' title, '##' per section, '###' per party, a bold line before a list
  on the top level; every value on a line of its own as '- **Label:**
  value'; list
  items (lines, payment means, rows of a table, ...) as '* ' items that
  carry their first value, their further values indented below them; sub
  lines nested in their line. Only CommonMark core: no tables, no HTML.
  Text from the invoice is escaped (a backslash before \ ` * _ [ ] < > & #
  | ~), so it never becomes markup, a link or HTML; a value with line
  breaks is shown verbatim in a fenced code block below its label. White
  space at the start or end of a one-line value, and lines of only white
  space in a longer one, stay in the text, but rendered CommonMark does not
  show them. Some renderers add their own extensions to text: GitHub makes
  links of bare web and mail addresses, commit hashes and GH-123, mentions
  of @name, emoji of :name: and formulas of $...$; the output itself loads
  nothing. Characters XML does not allow
  become U+FFFD, and the output says so. UTF-8 without BOM, LF line ends,
  no time stamp: the same invoice gives the same bytes.
  DE: Eine Rechnung als Markdown fuer Menschen: Text fuer ein Protokoll,
  ein Ticket, eine Mail oder ein Terminal, lesbar, wie er ist, und als
  dargestelltes CommonMark. Der Inhalt ist der Gang aus
  LandrixEInvoiceRenderWalk, derselbe wie auf der HTML-Seite. Form: '#'
  Titel, '##' je Abschnitt, '###' je Beteiligtem, eine fette Zeile vor einer
  Liste auf oberster Ebene; jeder Wert in einer eigenen Zeile als '- **Beschriftung:** Wert';
  Listeneintraege (Positionen, Zahlungsmittel, Zeilen einer Tabelle, ...)
  als '* '-Eintraege, die ihren ersten Wert tragen, die weiteren Werte
  eingerueckt darunter; Unterpositionen verschachtelt in ihrer Position. Nur
  der Kern von CommonMark: keine Tabellen, kein HTML. Text aus der Rechnung
  wird maskiert (ein Backslash vor \ ` * _ [ ] < > & # | ~), damit er nie
  Markup, Link oder HTML wird; ein Wert mit Zeilenumbruechen erscheint
  unveraendert in einem Codeblock unter seiner Beschriftung. Leerraum am
  Anfang oder Ende eines einzeiligen Werts und Zeilen nur aus Leerraum in
  einem laengeren bleiben im Text, dargestelltes CommonMark zeigt sie aber
  nicht. Manche Darstellungen ergaenzen Text um eigene Erweiterungen: GitHub
  macht Links aus nackten Web- und Mailadressen, Commit-Kennungen und
  GH-123, Erwaehnungen aus @Name, Emoji aus :Name: und Formeln aus $...$;
  die Ausgabe selbst laedt nichts. Zeichen, die XML nicht erlaubt,
  werden U+FFFD, und die Ausgabe sagt es. UTF-8 ohne BOM, LF als
  Zeilenende, kein Zeitstempel: dieselbe Rechnung ergibt dieselben Bytes. }

{ API: internal. May change in any release; use the facade LandrixEInvoice
  or the stable units instead.
  DE: API: intern. Kann sich in jeder Version aendern; stattdessen die
  Fassade LandrixEInvoice oder die stabilen Units verwenden. }

unit LandrixEInvoiceRenderMarkdown;

{$I LandrixEInvoice.inc}

interface

uses
  Classes,
  LandrixEInvoiceRenderWalk;

type
  { Writes invoices as Markdown (methods and properties: see
    TLandrixEInvoiceRenderWriter).
    DE: Schreibt Rechnungen als Markdown (Methoden und Eigenschaften: siehe
    TLandrixEInvoiceRenderWriter). }
  TLandrixEInvoiceRenderMarkdownWriter = class(TLandrixEInvoiceRenderWriter)
  protected
    function CreateTarget(AOut: TStream): TLandrixEInvoiceRenderTarget; override;
  end;

implementation

uses
  SysUtils,
  LandrixXmlBase,
  LandrixEInvoiceTypes,
  LandrixEInvoiceDiagnostics,
  LandrixEInvoiceReportHtml,
  LandrixEInvoiceRenderLabels;

type
  { the text: every call of the walk as Markdown lines }
  TMarkdownTarget = class(TLandrixEInvoiceRenderTarget)
  private
    FOut: TStream;
    FSanitized: Boolean;
    FWritten: Boolean;
    FBlank: Boolean;
    { the bullet of the last line on the top level, #0 after a heading }
    FTop: TLandrixEInvoiceChar;
    { the open list items and table rows: indent of their bullet, whether
      the bullet still waits for a value, their list }
    FIndents: array of Integer;
    FPending: array of Boolean;
    FFields: array of TLandrixEInvoiceRenderField;
    FBTs: array of TLandrixEInvoiceString;
    FCount: Integer;
    { a list heading inside an item: its rows are indented below it until
      the table closes }
    FScope: Boolean;
    FScopeCount, FScopeIndent: Integer;
    procedure Line(const S: TLandrixEInvoiceString);
    procedure BulletLine(AIndent: Integer; ABullet: TLandrixEInvoiceChar; const AText: TLandrixEInvoiceString);
    procedure BlankLine;
    procedure Heading(const AMarks, AText: TLandrixEInvoiceString);
    function Clean(const S: TLandrixEInvoiceString): TLandrixEInvoiceString;
    function Escape(const S: TLandrixEInvoiceString): TLandrixEInvoiceString;
    function LabelOf(AField: TLandrixEInvoiceRenderField; const ABT: TLandrixEInvoiceString): TLandrixEInvoiceString;
    function ContentIndent: Integer;
    procedure WriteBullets;
    procedure Value(const ALabel, AValue: TLandrixEInvoiceString);
    procedure Push(AField: TLandrixEInvoiceRenderField; const ABT: TLandrixEInvoiceString);
    procedure Pop;
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
  end;

function Spaces(N: Integer): TLandrixEInvoiceString;
var
  I: Integer;
begin
  Result := '';
  for I := 1 to N do
    Result := Result + ' ';
end;

function HasLineBreak(const S: TLandrixEInvoiceString): Boolean;
var
  I: Integer;
begin
  Result := False;
  for I := 1 to Length(S) do
    if (S[I] = #10) or (S[I] = #13) then
    begin
      Result := True;
      Exit;
    end;
end;

{ CR LF and CR as LF }
function NormalizeBreaks(const S: TLandrixEInvoiceString): TLandrixEInvoiceString;
var
  I: Integer;
begin
  Result := '';
  I := 1;
  while I <= Length(S) do
  begin
    if S[I] = #13 then
    begin
      Result := Result + #10;
      if (I < Length(S)) and (S[I + 1] = #10) then
        Inc(I);
    end
    else
      Result := Result + S[I];
    Inc(I);
  end;
end;

{ a fence of backticks longer than any run of backticks in S, at least
  three }
function Fence(const S: TLandrixEInvoiceString): TLandrixEInvoiceString;
var
  I, Run, Longest: Integer;
begin
  Longest := 0;
  Run := 0;
  for I := 1 to Length(S) do
    if S[I] = '`' then
    begin
      Inc(Run);
      if Run > Longest then
        Longest := Run;
    end
    else
      Run := 0;
  if Longest < 3 then
    Longest := 2;
  Result := '';
  for I := 0 to Longest do
    Result := Result + '`';
end;

constructor TMarkdownTarget.Create(AOut: TStream; ALanguage: TLandrixEInvoiceReportLanguage;
  AShowBusinessTerms: Boolean);
begin
  inherited Create(ALanguage, AShowBusinessTerms);
  FOut := AOut;
end;

procedure TMarkdownTarget.Line(const S: TLandrixEInvoiceString);
var
  U: TLandrixXmlUtf8;
begin
  U := LandrixEInvoiceStringToUtf8(S) + #10;
  FOut.WriteBuffer(PAnsiChar(U)^, Length(U));
  FWritten := True;
  FBlank := S = '';
end;

{ a list line; on the top level an empty line between a list of values
  ('-') and a list of items ('*'), which CommonMark keeps apart anyway }
procedure TMarkdownTarget.BulletLine(AIndent: Integer; ABullet: TLandrixEInvoiceChar;
  const AText: TLandrixEInvoiceString);
begin
  if AIndent = 0 then
  begin
    if (FTop <> #0) and (FTop <> ABullet) then
      BlankLine;
    FTop := ABullet;
  end;
  Line(Spaces(AIndent) + ABullet + ' ' + AText);
end;

{ one empty line, never two, none at the start }
procedure TMarkdownTarget.BlankLine;
begin
  if FWritten and not FBlank then
    Line('');
end;

procedure TMarkdownTarget.Heading(const AMarks, AText: TLandrixEInvoiceString);
begin
  BlankLine;
  Line(AMarks + ' ' + AText);
  Line('');
  FTop := #0;
end;

function TMarkdownTarget.Clean(const S: TLandrixEInvoiceString): TLandrixEInvoiceString;
begin
  Result := LandrixEInvoiceReportSanitize(S, FSanitized);
end;

{ S sanitized, with a backslash before every character that could start
  markup inline; line breaks become spaces (for headings) }
function TMarkdownTarget.Escape(const S: TLandrixEInvoiceString): TLandrixEInvoiceString;
var
  I: Integer;
  T: TLandrixEInvoiceString;
  C: TLandrixEInvoiceChar;
begin
  T := Clean(S);
  Result := '';
  for I := 1 to Length(T) do
  begin
    C := T[I];
    case C of
      '\', '`', '*', '_', '[', ']', '<', '>', '&', '#', '|', '~':
        Result := Result + '\' + C;
      #10, #13:
        Result := Result + ' ';
    else
      Result := Result + C;
    end;
  end;
end;

function TMarkdownTarget.LabelOf(AField: TLandrixEInvoiceRenderField;
  const ABT: TLandrixEInvoiceString): TLandrixEInvoiceString;
begin
  Result := LandrixEInvoiceRenderFieldLabel(AField, Language);
  if ShowBusinessTerms and (ABT <> '') then
    Result := Result + ' (' + ABT + ')';
end;

{ the indent of a value line below the innermost open item }
function TMarkdownTarget.ContentIndent: Integer;
begin
  if FScope and (FCount = FScopeCount) then
    Result := FScopeIndent
  else if FCount = 0 then
    Result := 0
  else
    Result := FIndents[FCount - 1] + 2;
end;

{ the bullets of open items that still wait, with the label of their list }
procedure TMarkdownTarget.WriteBullets;
var
  I: Integer;
begin
  for I := 0 to FCount - 1 do
    if FPending[I] then
    begin
      BulletLine(FIndents[I], '*', '**' + Escape(LabelOf(FFields[I], FBTs[I])) + '**');
      FPending[I] := False;
    end;
end;

{ a value on its own line; the first value of a waiting item takes its
  bullet; a value with line breaks goes into a fenced code block }
procedure TMarkdownTarget.Value(const ALabel, AValue: TLandrixEInvoiceString);
var
  Indent, I, Start: Integer;
  Bullet: TLandrixEInvoiceChar;
  Text, F: TLandrixEInvoiceString;
begin
  if FScope and (FCount = FScopeCount) then
    FScope := False;
  Bullet := '-';
  if (FCount > 0) and FPending[FCount - 1] then
  begin
    FPending[FCount - 1] := False;
    WriteBullets;
    Indent := FIndents[FCount - 1];
    Bullet := '*';
  end
  else
  begin
    WriteBullets;
    Indent := ContentIndent;
  end;
  if not HasLineBreak(AValue) then
  begin
    BulletLine(Indent, Bullet, '**' + Escape(ALabel) + ':** ' + Escape(AValue));
    Exit;
  end;
  BulletLine(Indent, Bullet, '**' + Escape(ALabel) + ':**');
  Text := NormalizeBreaks(Clean(AValue));
  F := Fence(Text);
  Line(Spaces(Indent + 2) + F);
  Start := 1;
  for I := 1 to Length(Text) + 1 do
    if (I > Length(Text)) or (Text[I] = #10) then
    begin
      if I > Start then
        Line(Spaces(Indent + 2) + Copy(Text, Start, I - Start))
      else
        Line('');
      Start := I + 1;
    end;
  Line(Spaces(Indent + 2) + F);
end;

procedure TMarkdownTarget.Push(AField: TLandrixEInvoiceRenderField; const ABT: TLandrixEInvoiceString);
var
  Indent: Integer;
begin
  Indent := ContentIndent;
  if FCount >= Integer(Length(FIndents)) then
  begin
    SetLength(FIndents, FCount + 8);
    SetLength(FPending, FCount + 8);
    SetLength(FFields, FCount + 8);
    SetLength(FBTs, FCount + 8);
  end;
  FIndents[FCount] := Indent;
  FPending[FCount] := True;
  FFields[FCount] := AField;
  FBTs[FCount] := ABT;
  Inc(FCount);
end;

{ an item without values still shows its bullet; the scope of a list
  heading ends with the item that holds it }
procedure TMarkdownTarget.Pop;
begin
  WriteBullets;
  Dec(FCount);
  if FScope and (FCount < FScopeCount) then
    FScope := False;
end;

procedure TMarkdownTarget.DoBeginPage(ATitle: TLandrixEInvoiceRenderCaption;
  const ADocumentName: TLandrixEInvoiceString);
begin
  if ADocumentName <> '' then
    Line('# ' + Escape(CaptionText(ATitle)) + ': ' + Escape(ADocumentName))
  else
    Line('# ' + Escape(CaptionText(ATitle)));
end;

procedure TMarkdownTarget.DoEndPage;
begin
  BlankLine;
  Line('---');
  Line('');
  if FSanitized then
  begin
    Line(Escape(CaptionText(erc_SanitizedNote)));
    Line('');
  end;
  Line(Escape(CaptionText(erc_GeneratedBy)) + ' EInvoice-for-Pascal ' + LandrixEInvoiceVersion);
end;

procedure TMarkdownTarget.DoOpenGroup(AGroup: TLandrixEInvoiceRenderGroup; ASection: TLandrixEInvoiceRenderSection;
  AField: TLandrixEInvoiceRenderField);
begin
  case AGroup of
    erg_Section:
      Heading('##', Escape(LandrixEInvoiceRenderSectionLabel(ASection, Language)));
    erg_Box:
      Heading('###', Escape(LabelOf(AField, LandrixEInvoiceRenderFieldBT(AField))));
  else
    { the other groups write nothing when they open (FPC 3.3.1 warns about
      a case without else) }
  end;
end;

{ on the top level a bold line (a heading would also hold what follows
  the list); inside an item a list line with the rows of its table below
  it, until the table closes or a value arrives at its level }
procedure TMarkdownTarget.DoListHeading(AField: TLandrixEInvoiceRenderField; const ABT: TLandrixEInvoiceString);
var
  Indent: Integer;
begin
  if FCount = 0 then
  begin
    BlankLine;
    Line('**' + Escape(LabelOf(AField, ABT)) + '**');
    Line('');
    FTop := #0;
    Exit;
  end;
  if FScope and (FCount = FScopeCount) then
    FScope := False;
  WriteBullets;
  Indent := ContentIndent;
  BulletLine(Indent, '-', '**' + Escape(LabelOf(AField, ABT)) + '**');
  FScope := True;
  FScopeCount := FCount;
  FScopeIndent := Indent + 2;
end;

procedure TMarkdownTarget.DoCloseItem;
begin
  Pop;
end;

procedure TMarkdownTarget.DoPair(AField: TLandrixEInvoiceRenderField; const AValue, ABT: TLandrixEInvoiceString);
begin
  Value(LabelOf(AField, ABT), AValue);
end;

procedure TMarkdownTarget.DoCloseTable;
begin
  FScope := False;
end;

procedure TMarkdownTarget.DoCloseRow;
begin
  Pop;
end;

{ an empty cell leaves nothing }
procedure TMarkdownTarget.DoCell(AField: TLandrixEInvoiceRenderField; const AValue, ABT: TLandrixEInvoiceString);
begin
  if AValue <> '' then
    Value(LabelOf(AField, ABT), AValue);
end;

procedure TMarkdownTarget.DoOpenCell;
begin
end;

procedure TMarkdownTarget.DoSpan(AField: TLandrixEInvoiceRenderField; const AValue, ABT: TLandrixEInvoiceString);
begin
  Value(LabelOf(AField, ABT), AValue);
end;

procedure TMarkdownTarget.DoCloseCell;
begin
end;

procedure TMarkdownTarget.DoBeginDocument;
begin
  Heading('##', Escape(CaptionText(erc_Document)));
end;

procedure TMarkdownTarget.DoFact(ACaption: TLandrixEInvoiceRenderCaption; const AValue: TLandrixEInvoiceString);
begin
  Value(CaptionText(ACaption), AValue);
end;

procedure TMarkdownTarget.DoBeginDiagnostics;
begin
  Heading('###', Escape(CaptionText(erc_NotTakenOver)));
end;

procedure TMarkdownTarget.DoEndDocument(ACount: Integer);
begin
  if ACount = 0 then
    Line(Escape(CaptionText(erc_NothingLeftOut)));
end;

{ the calls whose parameters the text does not need in full }
{$IFDEF FPC}
  {$PUSH}
  {$WARN 5024 OFF}
{$ENDIF}

procedure TMarkdownTarget.DoCloseGroup(AGroup: TLandrixEInvoiceRenderGroup);
begin
end;

procedure TMarkdownTarget.DoOpenItem(AField: TLandrixEInvoiceRenderField; const ABT: TLandrixEInvoiceString);
begin
  Push(AField, ABT);
end;

procedure TMarkdownTarget.DoMoney(AField: TLandrixEInvoiceRenderField; const AAmount, ABT: TLandrixEInvoiceString;
  ACurrencyField: TLandrixEInvoiceRenderField; const ACurrency: TLandrixEInvoiceString);
begin
  if ACurrency <> '' then
    Value(LabelOf(AField, ABT), AAmount + ' ' + ACurrency)
  else
    Value(LabelOf(AField, ABT), AAmount);
end;

procedure TMarkdownTarget.DoOpenTable(const AColumns: array of TLandrixEInvoiceRenderField);
begin
end;

procedure TMarkdownTarget.DoOpenRow(AField: TLandrixEInvoiceRenderField; const ABT: TLandrixEInvoiceString);
begin
  Push(AField, ABT);
end;

procedure TMarkdownTarget.DoDiagnostic(AIndex: Integer; AKind: TLandrixEInvoiceDiagnosticKind; ALine,
  AColumn: Integer; const APath, AMessage: TLandrixEInvoiceString);
var
  Location: TLandrixEInvoiceString;
begin
  Push(Low(TLandrixEInvoiceRenderField), '');
  Value(CaptionText(erc_Kind), KindText(AKind));
  if ALine > 0 then
  begin
    Location := CaptionText(erc_Line) + ' ' + TLandrixEInvoiceString(IntToStr(ALine));
    if AColumn > 0 then
      Location := Location + ', ' + CaptionText(erc_Column) + ' ' + TLandrixEInvoiceString(IntToStr(AColumn));
    Value(CaptionText(erc_Location), Location);
  end;
  if APath <> '' then
    Value(CaptionText(erc_Path), APath);
  if AMessage <> '' then
    Value(CaptionText(erc_Message), AMessage);
  Pop;
end;

{$IFDEF FPC}
  {$POP}
{$ENDIF}

{ --- TLandrixEInvoiceRenderMarkdownWriter --------------------------------- }

function TLandrixEInvoiceRenderMarkdownWriter.CreateTarget(AOut: TStream): TLandrixEInvoiceRenderTarget;
begin
  Result := TMarkdownTarget.Create(AOut, Language, ShowBusinessTerms);
end;

end.
