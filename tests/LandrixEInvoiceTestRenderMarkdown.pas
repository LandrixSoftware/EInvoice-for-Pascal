{
  EInvoice-for-Pascal

  Copyright (C) 2026 Landrix Software GmbH & Co. KG

  This file is dual-licensed under:
  - GNU GPL version 3 or later; or
  - the Landrix Software Commercial License.

  See LICENSE and COMMERCIAL-LICENSE.md.

  SPDX-License-Identifier: GPL-3.0-or-later OR LicenseRef-Landrix-Commercial
}

{ Tests of the Markdown rendering (LandrixEInvoiceRenderMarkdown). The walk
  is proven on the HTML page (Render.Mutations); here the structure of the
  Markdown is checked against what the walk passes (a recording target that
  states the layout independently of the writer): every title, heading,
  bold list line, list line, bare item bullet and value line, in order,
  with its nesting depth, section, label (with the business term when
  shown) and value after unescaping, the document section included. This
  runs on the filled invoice with one and two items per list, on every
  mutation of it (which must also change the text), on the golden and the
  hostile invoices and on every local corpus file. Further: the writer
  (stream, file, string, nil, read context), escaping, golden texts in
  tests/data/render/. tools/render/md-oracle.py checks the same with the
  CommonMark reference parser. }

unit LandrixEInvoiceTestRenderMarkdown;

{$I LandrixEInvoice.inc}

interface

uses
  LandrixEInvoiceTypes,
  LandrixEInvoiceInvoice,
  LandrixEInvoice,
  LandrixEInvoiceReportHtml;

type
  { a line of the expected or parsed Markdown: Kind 't' title, 'h' heading
    of level 3, 'p' bold line, 'l' list line without value, 'b' item
    bullet without value, 'v' value; Depth the number of list items it sits
    in (0 outside lists); Lbl the label or the text of a heading }
  TEvent = record
    Kind: Char;
    Depth: Integer;
    Section, Lbl, Value: TLandrixEInvoiceString;
  end;

  TEventList = class(TObject)
  public
    Items: array of TEvent;
    Count: Integer;
    procedure Add(AKind: Char; ADepth: Integer; const ASection, ALabel, AValue: TLandrixEInvoiceString);
  end;

{ The lines the walk calls for AInvoice or, when not nil, ADocument, as the
  Markdown should show them, appended to AEvents; also used by
  tools/render/MarkdownProbe.dpr. }
procedure RecordEvents(AInvoice: TLandrixInvoice; ADocument: TLandrixEInvoiceDocument;
  ALanguage: TLandrixEInvoiceReportLanguage; AShowTerms: Boolean; AEvents: TEventList;
  const ADocumentName: TLandrixEInvoiceString = '');

{ An invoice with text that would be Markdown, HTML or a link if it were not
  escaped, a control character and values with line breaks and backticks
  (also used by tools/render/MarkdownProbe.dpr). }
procedure BuildHostileInvoice(AInvoice: TLandrixInvoice);

const
  { a document name to go with it }
  HostileDocumentName = '*x* <y> [z](w) #1';

procedure Register;

implementation

uses
  SysUtils,
  Classes,
  LandrixXmlBase,
  LandrixEInvoiceDiagnostics,
  LandrixEInvoiceRenderLabels,
  LandrixEInvoiceRenderWalk,
  LandrixEInvoiceRenderMarkdown,
  LandrixEInvoiceTestFramework,
  LandrixEInvoiceTestInvoiceCompare,
  LandrixEInvoiceTestValidationReport,
  LandrixEInvoiceTestRender;

type
  { the layout, stated on its own: a value is a list item of its own below
    the innermost open item (or of the top level), except the first value
    of an item, which takes the item's bullet; an item without value shows
    a bare bullet; a list heading inside an item is a list line whose table
    rows sit one level deeper until the table closes or a value comes at
    its level; on the top level it is a bold line }
  TRecorder = class(TLandrixEInvoiceRenderTarget)
  private
    FEvents: TEventList;
    FSection: TLandrixEInvoiceString;
    FOpen: Integer;
    FPending: array of Boolean;
    FLabels: array of TLandrixEInvoiceString;
    FScope: Boolean;
    FScopeCount: Integer;
    procedure Emit(AKind: Char; ADepth: Integer; const ALabel, AValue: TLandrixEInvoiceString);
    function LabelOf(AField: TLandrixEInvoiceRenderField; const ABT: TLandrixEInvoiceString): TLandrixEInvoiceString;
    function Extra(ALevel: Integer): Integer;
    procedure Bullets;
    procedure Value(const ALabel, AValue: TLandrixEInvoiceString);
    procedure Push(const ALabel: TLandrixEInvoiceString);
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
    constructor Create(ALanguage: TLandrixEInvoiceReportLanguage; AShowBusinessTerms: Boolean;
      AEvents: TEventList);
  end;

  TRecordWriter = class(TLandrixEInvoiceRenderWriter)
  private
    FEvents: TEventList;
  protected
    function CreateTarget(AOut: TStream): TLandrixEInvoiceRenderTarget; override;
  public
    constructor Create(AEvents: TEventList);
  end;

procedure TEventList.Add(AKind: Char; ADepth: Integer; const ASection, ALabel, AValue: TLandrixEInvoiceString);
begin
  if Count >= Integer(Length(Items)) then
    SetLength(Items, Count * 2 + 16);
  Items[Count].Kind := AKind;
  Items[Count].Depth := ADepth;
  Items[Count].Section := ASection;
  Items[Count].Lbl := ALabel;
  Items[Count].Value := AValue;
  Inc(Count);
end;

{ --- TRecorder ------------------------------------------------------------- }

constructor TRecorder.Create(ALanguage: TLandrixEInvoiceReportLanguage; AShowBusinessTerms: Boolean;
  AEvents: TEventList);
begin
  inherited Create(ALanguage, AShowBusinessTerms);
  FEvents := AEvents;
end;

procedure TRecorder.Emit(AKind: Char; ADepth: Integer; const ALabel, AValue: TLandrixEInvoiceString);
begin
  FEvents.Add(AKind, ADepth, FSection, ALabel, AValue);
end;

function TRecorder.LabelOf(AField: TLandrixEInvoiceRenderField;
  const ABT: TLandrixEInvoiceString): TLandrixEInvoiceString;
begin
  Result := LandrixEInvoiceRenderFieldLabel(AField, Language);
  if ShowBusinessTerms and (ABT <> '') then
    Result := Result + ' (' + ABT + ')';
end;

{ the extra level of an item ALevel deep below an open list line }
function TRecorder.Extra(ALevel: Integer): Integer;
begin
  if FScope and (ALevel > FScopeCount) then
    Result := 1
  else
    Result := 0;
end;

procedure TRecorder.Bullets;
var
  I: Integer;
begin
  for I := 0 to FOpen - 1 do
    if FPending[I] then
    begin
      Emit('b', I + 1 + Extra(I + 1), FLabels[I], '');
      FPending[I] := False;
    end;
end;

procedure TRecorder.Value(const ALabel, AValue: TLandrixEInvoiceString);
begin
  if FScope and (FOpen = FScopeCount) then
    FScope := False;
  if (FOpen > 0) and FPending[FOpen - 1] then
  begin
    FPending[FOpen - 1] := False;
    Bullets;
    Emit('v', FOpen + Extra(FOpen), ALabel, AValue);
  end
  else
  begin
    Bullets;
    Emit('v', FOpen + 1 + Extra(FOpen), ALabel, AValue);
  end;
end;

procedure TRecorder.Push(const ALabel: TLandrixEInvoiceString);
begin
  if FOpen >= Integer(Length(FPending)) then
  begin
    SetLength(FPending, FOpen + 8);
    SetLength(FLabels, FOpen + 8);
  end;
  FPending[FOpen] := True;
  FLabels[FOpen] := ALabel;
  Inc(FOpen);
end;

procedure TRecorder.Pop;
begin
  Bullets;
  Dec(FOpen);
  if FScope and (FOpen < FScopeCount) then
    FScope := False;
end;

{ line breaks of the title become spaces }
procedure TRecorder.DoBeginPage(ATitle: TLandrixEInvoiceRenderCaption; const ADocumentName: TLandrixEInvoiceString);
var
  T: TLandrixEInvoiceString;
  I: Integer;
begin
  T := CaptionText(ATitle);
  if ADocumentName <> '' then
    T := T + ': ' + ADocumentName;
  for I := 1 to Length(T) do
    if (T[I] = #10) or (T[I] = #13) then
      T[I] := ' ';
  Emit('t', 0, T, '');
end;

procedure TRecorder.DoListHeading(AField: TLandrixEInvoiceRenderField; const ABT: TLandrixEInvoiceString);
begin
  if FOpen = 0 then
  begin
    Emit('p', 0, LabelOf(AField, ABT), '');
    Exit;
  end;
  if FScope and (FOpen = FScopeCount) then
    FScope := False;
  Bullets;
  Emit('l', FOpen + 1 + Extra(FOpen), LabelOf(AField, ABT), '');
  FScope := True;
  FScopeCount := FOpen;
end;

procedure TRecorder.DoOpenItem(AField: TLandrixEInvoiceRenderField; const ABT: TLandrixEInvoiceString);
begin
  Push(LabelOf(AField, ABT));
end;

procedure TRecorder.DoCloseItem;
begin
  Pop;
end;

procedure TRecorder.DoPair(AField: TLandrixEInvoiceRenderField; const AValue, ABT: TLandrixEInvoiceString);
begin
  Value(LabelOf(AField, ABT), AValue);
end;

procedure TRecorder.DoCloseTable;
begin
  FScope := False;
end;

procedure TRecorder.DoOpenRow(AField: TLandrixEInvoiceRenderField; const ABT: TLandrixEInvoiceString);
begin
  Push(LabelOf(AField, ABT));
end;

procedure TRecorder.DoCloseRow;
begin
  Pop;
end;

procedure TRecorder.DoCell(AField: TLandrixEInvoiceRenderField; const AValue, ABT: TLandrixEInvoiceString);
begin
  if AValue <> '' then
    Value(LabelOf(AField, ABT), AValue);
end;

procedure TRecorder.DoSpan(AField: TLandrixEInvoiceRenderField; const AValue, ABT: TLandrixEInvoiceString);
begin
  Value(LabelOf(AField, ABT), AValue);
end;

procedure TRecorder.DoBeginDocument;
begin
  FSection := CaptionText(erc_Document);
end;

procedure TRecorder.DoFact(ACaption: TLandrixEInvoiceRenderCaption; const AValue: TLandrixEInvoiceString);
begin
  Value(CaptionText(ACaption), AValue);
end;

procedure TRecorder.DoBeginDiagnostics;
begin
  Emit('h', 0, CaptionText(erc_NotTakenOver), '');
end;

{ the calls the recorder ignores (in full or in part) }
{$IFDEF FPC}
  {$PUSH}
  {$WARN 5024 OFF}
{$ENDIF}

procedure TRecorder.DoEndPage;
begin
end;

procedure TRecorder.DoOpenGroup(AGroup: TLandrixEInvoiceRenderGroup; ASection: TLandrixEInvoiceRenderSection;
  AField: TLandrixEInvoiceRenderField);
begin
  case AGroup of
    erg_Section:
      FSection := LandrixEInvoiceRenderSectionLabel(ASection, Language);
    erg_Box:
      Emit('h', 0, LabelOf(AField, LandrixEInvoiceRenderFieldBT(AField)), '');
  end;
end;

procedure TRecorder.DoCloseGroup(AGroup: TLandrixEInvoiceRenderGroup);
begin
end;

procedure TRecorder.DoMoney(AField: TLandrixEInvoiceRenderField; const AAmount, ABT: TLandrixEInvoiceString;
  ACurrencyField: TLandrixEInvoiceRenderField; const ACurrency: TLandrixEInvoiceString);
begin
  if ACurrency <> '' then
    Value(LabelOf(AField, ABT), AAmount + ' ' + ACurrency)
  else
    Value(LabelOf(AField, ABT), AAmount);
end;

procedure TRecorder.DoOpenTable(const AColumns: array of TLandrixEInvoiceRenderField);
begin
end;

procedure TRecorder.DoOpenCell;
begin
end;

procedure TRecorder.DoCloseCell;
begin
end;

procedure TRecorder.DoDiagnostic(AIndex: Integer; AKind: TLandrixEInvoiceDiagnosticKind; ALine, AColumn: Integer;
  const APath, AMessage: TLandrixEInvoiceString);
var
  Location: TLandrixEInvoiceString;
begin
  Push('');
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

procedure TRecorder.DoEndDocument(ACount: Integer);
begin
end;

function TRecordWriter.CreateTarget(AOut: TStream): TLandrixEInvoiceRenderTarget;
begin
  Result := TRecorder.Create(Language, ShowBusinessTerms, FEvents);
end;

{$IFDEF FPC}
  {$POP}
{$ENDIF}

constructor TRecordWriter.Create(AEvents: TEventList);
begin
  inherited Create;
  FEvents := AEvents;
end;

{ --- helpers ---------------------------------------------------------------- }

function WithChar(const A: TLandrixEInvoiceString; AChar: Word; const B: TLandrixEInvoiceString): TLandrixEInvoiceString;
begin
  Result := A + WideChar(AChar) + B;
end;

function StreamUtf8(S: TMemoryStream): TLandrixXmlUtf8;
begin
  Result := '';
  SetLength(Result, Integer(S.Size));
  if S.Size > 0 then
    Move(S.Memory^, PAnsiChar(Result)^, Integer(S.Size));
end;

function MarkdownOf(AInvoice: TLandrixInvoice; ALanguage: TLandrixEInvoiceReportLanguage;
  AShowTerms: Boolean): TLandrixXmlUtf8;
var
  W: TLandrixEInvoiceRenderMarkdownWriter;
  S: TMemoryStream;
begin
  W := TLandrixEInvoiceRenderMarkdownWriter.Create;
  S := TMemoryStream.Create;
  try
    W.Language := ALanguage;
    W.ShowBusinessTerms := AShowTerms;
    W.WriteToStream(AInvoice, S);
    Result := StreamUtf8(S);
  finally
    S.Free;
    W.Free;
  end;
end;

procedure RecordEvents(AInvoice: TLandrixInvoice; ADocument: TLandrixEInvoiceDocument;
  ALanguage: TLandrixEInvoiceReportLanguage; AShowTerms: Boolean; AEvents: TEventList;
  const ADocumentName: TLandrixEInvoiceString);
var
  W: TRecordWriter;
  S: TMemoryStream;
begin
  W := TRecordWriter.Create(AEvents);
  S := TMemoryStream.Create;
  try
    W.Language := ALanguage;
    W.ShowBusinessTerms := AShowTerms;
    W.DocumentName := ADocumentName;
    if ADocument <> nil then
      W.WriteToStream(ADocument, S)
    else
      W.WriteToStream(AInvoice, S);
  finally
    S.Free;
    W.Free;
  end;
end;

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

{ a backslash before ASCII punctuation dropped }
function Unescape(const S: TLandrixEInvoiceString): TLandrixEInvoiceString;
var
  I: Integer;
begin
  Result := '';
  I := 1;
  while I <= Length(S) do
  begin
    if (S[I] = '\') and (I < Length(S)) and (Ord(S[I + 1]) < 128) and
       (AnsiChar(Ord(S[I + 1])) in ['!'..'/', ':'..'@', '['..'`', '{'..'~']) then
      Inc(I);
    Result := Result + S[I];
    Inc(I);
  end;
end;

function LeadingSpaces(const S: TLandrixEInvoiceString): Integer;
begin
  Result := 0;
  while (Result < Length(S)) and (S[Result + 1] = ' ') do
    Inc(Result);
end;

function EndsWithStars(const S: TLandrixEInvoiceString): Boolean;
begin
  Result := (Length(S) >= 2) and (Copy(S, Length(S) - 1, 2) = '**');
end;

{ the lines of a Markdown text as events; AProblem is set for a line the
  writer should not write }
procedure ParseMarkdown(const AText: TLandrixEInvoiceString; AEvents: TEventList; var AProblem: string);
var
  Lines: array of TLandrixEInvoiceString;
  N, I, J, Start, Indent, Depth, P: Integer;
  Section, L, Rest, Lbl, Value, Fence: TLandrixEInvoiceString;
  Kind: Char;
begin
  Lines := nil;
  N := 0;
  Start := 1;
  for I := 1 to Length(AText) + 1 do
    if (I > Length(AText)) or (AText[I] = #10) then
    begin
      if N >= Integer(Length(Lines)) then
        SetLength(Lines, N * 2 + 64);
      Lines[N] := Copy(AText, Start, I - Start);
      Inc(N);
      Start := I + 1;
    end;
  Section := '';
  I := 0;
  while I < N do
  begin
    L := Lines[I];
    Inc(I);
    if Copy(L, 1, 2) = '# ' then
    begin
      AEvents.Add('t', 0, Section, Unescape(Copy(L, 3, MaxInt)), '');
      Continue;
    end;
    if Copy(L, 1, 3) = '## ' then
    begin
      Section := Unescape(Copy(L, 4, MaxInt));
      Continue;
    end;
    if Copy(L, 1, 4) = '### ' then
    begin
      AEvents.Add('h', 0, Section, Unescape(Copy(L, 5, MaxInt)), '');
      Continue;
    end;
    if (Copy(L, 1, 2) = '**') and (Length(L) > 4) and EndsWithStars(L) then
    begin
      AEvents.Add('p', 0, Section, Unescape(Copy(L, 3, Length(L) - 4)), '');
      Continue;
    end;
    Indent := LeadingSpaces(L);
    Rest := Copy(L, Indent + 1, MaxInt);
    if (Copy(Rest, 1, 4) <> '- **') and (Copy(Rest, 1, 4) <> '* **') then
      Continue;
    if Indent mod 2 <> 0 then
    begin
      AProblem := 'odd indent: ' + string(L);
      Exit;
    end;
    Depth := Indent div 2 + 1;
    Kind := Char(Ord(Rest[1]));
    Rest := Copy(Rest, 5, MaxInt);
    P := Pos(':**', Rest);
    if P = 0 then
    begin
      if not EndsWithStars(Rest) then
      begin
        AProblem := 'bullet without label: ' + string(L);
        Exit;
      end;
      if Kind = '-' then
        AEvents.Add('l', Depth, Section, Unescape(Copy(Rest, 1, Length(Rest) - 2)), '')
      else
        AEvents.Add('b', Depth, Section, Unescape(Copy(Rest, 1, Length(Rest) - 2)), '');
      Continue;
    end;
    Lbl := Unescape(Copy(Rest, 1, P - 1));
    Rest := Copy(Rest, P + 3, MaxInt);
    if Rest <> '' then
    begin
      if Rest[1] <> ' ' then
      begin
        AProblem := 'no space after the label: ' + string(L);
        Exit;
      end;
      AEvents.Add('v', Depth, Section, Lbl, Unescape(Copy(Rest, 2, MaxInt)));
      Continue;
    end;
    { a fenced block indented below the label }
    if (I >= N) or (LeadingSpaces(Lines[I]) <> Indent + 2) or (Copy(Lines[I], Indent + 3, 3) <> '```') then
    begin
      AProblem := 'label without value: ' + string(L);
      Exit;
    end;
    Fence := Copy(Lines[I], Indent + 3, MaxInt);
    Inc(I);
    Value := '';
    J := 0;
    while (I < N) and (Lines[I] <> TLandrixEInvoiceString(StringOfChar(' ', Indent + 2)) + Fence) do
    begin
      if J > 0 then
        Value := Value + #10;
      Value := Value + Copy(Lines[I], Indent + 3, MaxInt);
      Inc(J);
      Inc(I);
    end;
    if I >= N then
    begin
      AProblem := 'fenced block not closed: ' + string(L);
      Exit;
    end;
    Inc(I);
    AEvents.Add('v', Depth, Section, Lbl, Value);
  end;
end;

function Shown(const S: TLandrixEInvoiceString): string;
begin
  Result := string(S);
end;

function Describe(const E: TEvent): string;
begin
  Result := E.Kind + IntToStr(E.Depth) + ' ' + Shown(E.Section) + ' / ' + Shown(E.Lbl);
  if E.Kind = 'v' then
    Result := Result + ' = ' + Shown(E.Value);
end;

{ the lines of the Markdown of AInvoice (or ADocument) against the lines the
  walk calls for; returns '' or the first difference }
function CompareEvents(AInvoice: TLandrixInvoice; ADocument: TLandrixEInvoiceDocument;
  ALanguage: TLandrixEInvoiceReportLanguage; AShowTerms: Boolean;
  const ADocumentName: TLandrixEInvoiceString = ''): string;
var
  Expected, Actual: TEventList;
  W: TLandrixEInvoiceRenderMarkdownWriter;
  Text: TLandrixEInvoiceString;
  E: TEvent;
  I: Integer;
  Sanitized: Boolean;
begin
  Result := '';
  Expected := TEventList.Create;
  Actual := TEventList.Create;
  W := TLandrixEInvoiceRenderMarkdownWriter.Create;
  try
    RecordEvents(AInvoice, ADocument, ALanguage, AShowTerms, Expected, ADocumentName);
    W.Language := ALanguage;
    W.ShowBusinessTerms := AShowTerms;
    W.DocumentName := ADocumentName;
    if ADocument <> nil then
      Text := W.WriteToString(ADocument)
    else
      Text := W.WriteToString(AInvoice);
    ParseMarkdown(Text, Actual, Result);
    if Result <> '' then
      Exit;
    for I := 0 to Expected.Count - 1 do
    begin
      if I >= Actual.Count then
      begin
        Result := 'line missing: ' + Describe(Expected.Items[I]);
        Exit;
      end;
      E := Expected.Items[I];
      Sanitized := False;
      E.Lbl := LandrixEInvoiceReportSanitize(E.Lbl, Sanitized);
      E.Value := NormalizeBreaks(LandrixEInvoiceReportSanitize(E.Value, Sanitized));
      if (E.Kind <> Actual.Items[I].Kind) or (E.Depth <> Actual.Items[I].Depth) or
         (E.Section <> Actual.Items[I].Section) or (E.Lbl <> Actual.Items[I].Lbl) or
         (E.Value <> Actual.Items[I].Value) then
      begin
        Result := 'line ' + IntToStr(I + 1) + ': expected ' + Describe(E) + ', found ' + Describe(Actual.Items[I]);
        Exit;
      end;
    end;
    if Actual.Count > Expected.Count then
      Result := 'line too many: ' + Describe(Actual.Items[Expected.Count]);
  finally
    W.Free;
    Actual.Free;
    Expected.Free;
  end;
end;

procedure CheckEvents(AInvoice: TLandrixInvoice; ALanguage: TLandrixEInvoiceReportLanguage; AShowTerms: Boolean;
  const AWhat: string);
var
  Problem: string;
begin
  Problem := CompareEvents(AInvoice, nil, ALanguage, AShowTerms);
  Check(Problem = '', AWhat + ': ' + Problem);
end;

function Contains(const AText: TLandrixXmlUtf8; const APart: TLandrixEInvoiceString): Boolean;
begin
  Result := Pos(LandrixEInvoiceStringToUtf8(APart), AText) > 0;
end;

function HasCR(const AText: TLandrixXmlUtf8): Boolean;
begin
  Result := Pos(TLandrixXmlUtf8(#13), AText) > 0;
end;

{ --- Markdown.Writer ---------------------------------------------------------- }

procedure TestWriter;
var
  Inv: TLandrixInvoice;
  W: TLandrixEInvoiceRenderMarkdownWriter;
  S: TMemoryStream;
  Md, FileMd: TLandrixXmlUtf8;
  Document: TLandrixEInvoiceDocument;
  FileName: string;
  F: TFileStream;
  Raised: Boolean;
begin
  W := TLandrixEInvoiceRenderMarkdownWriter.Create;
  S := TMemoryStream.Create;
  Inv := TLandrixInvoice.Create;
  try
    Raised := False;
    try
      W.WriteToStream(TLandrixInvoice(nil), S);
    except
      on ELandrixEInvoiceError do
        Raised := True;
    end;
    Check(Raised, 'nil invoice raises');
    Raised := False;
    try
      W.WriteToString(TLandrixEInvoiceDocument(nil));
    except
      on ELandrixEInvoiceError do
        Raised := True;
    end;
    Check(Raised, 'nil document raises');
    CheckEquals(0, Integer(S.Size), 'nothing written on error');

    { a new invoice: title (no BOM before it), the totals EN 16931
      requires, the footer }
    Md := MarkdownOf(Inv, eln_English, False);
    Check(Copy(Md, 1, 10) = TLandrixXmlUtf8('# Invoice' + #10), 'empty: title');
    Check(Contains(Md, '## Totals'), 'empty: totals');
    Check(not Contains(Md, '## Parties'), 'empty: no parties');
    Check(Md[Length(Md)] = #10, 'ends with LF');
    Check(not HasCR(Md), 'no CR');
    CheckEvents(Inv, eln_English, False, 'empty');

    { stream at its position, file, string, document name }
    S.Clear;
    S.WriteBuffer(PAnsiChar(AnsiString('abc'))^, 3);
    W.Language := eln_German;
    W.WriteToStream(Inv, S);
    Check(Copy(StreamUtf8(S), 1, 3) = 'abc', 'stream: kept');
    CheckEqualsUtf8(MarkdownOf(Inv, eln_German, False), Copy(StreamUtf8(S), 4, MaxInt), 'stream: text');
    FileName := ExtractFilePath(ParamStr(0)) + 'render-test.md';
    W.SaveToFile(Inv, FileName);
    F := TFileStream.Create(FileName, fmOpenRead or fmShareDenyWrite);
    try
      FileMd := '';
      SetLength(FileMd, Integer(F.Size));
      if F.Size > 0 then
        F.ReadBuffer(PAnsiChar(FileMd)^, Integer(F.Size));
    finally
      F.Free;
    end;
    DeleteFile(FileName);
    CheckEqualsUtf8(MarkdownOf(Inv, eln_German, False), FileMd, 'file');
    CheckEqualsUtf8(MarkdownOf(Inv, eln_German, False), LandrixEInvoiceStringToUtf8(W.WriteToString(Inv)), 'string');
    W.DocumentName := 'a*b.xml';
    Check(Copy(LandrixEInvoiceStringToUtf8(W.WriteToString(Inv)), 1, 23) =
      TLandrixXmlUtf8('# Rechnung: a\*b.xml' + #10 + #10 + '#'), 'document name in the title');
  finally
    Inv.Free;
    S.Free;
    W.Free;
  end;

  { a read document: info and what reading did not take over, a message with
    a line break in a fenced block }
  Document := TLandrixEInvoice.LoadFromUtf8(
    '<Invoice xmlns="urn:oasis:names:specification:ubl:schema:xsd:Invoice-2" ' +
    'xmlns:cbc="urn:oasis:names:specification:ubl:schema:xsd:CommonBasicComponents-2">' +
    '<cbc:CustomizationID>urn:cen.eu:en16931:2017#compliant#urn:xeinkauf.de:kosit:xrechnung_3.0</cbc:CustomizationID>' +
    '<cbc:ID>R-1</cbc:ID><cbc:Foo>x</cbc:Foo></Invoice>');
  W := TLandrixEInvoiceRenderMarkdownWriter.Create;
  try
    Document.Diagnostics.AddDiagnostic(edk_UnknownCode, '/Invoice/Bar', 5, 6, 0, 'unknown code shown elsewhere');
    Document.Diagnostics.AddDiagnostic(edk_ConversionFailed, '/Invoice/Baz', 0, 0, 0, 'value 12'#10'34');
    W.Language := eln_German;
    Md := LandrixEInvoiceStringToUtf8(W.WriteToString(Document));
    Check(Contains(Md, '## Dokument'), 'document section');
    Check(Contains(Md, 'XRechnung 3.0'), 'specification');
    Check(Contains(Md, '### Beim Lesen nicht ' + WideChar($FC) + 'bernommen'), 'not taken over: heading');
    Check(Contains(Md, '* **Art:** Unbekanntes Element'), 'unknown element listed');
    Check(Contains(Md, 'cbc:Foo'), 'path listed');
    Check(not Contains(Md, 'unknown code shown elsewhere'), 'unknown code not listed');
    Check(Contains(Md, '  - **Meldung:**' + #10 + '    ```' + #10 + '    value 12' + #10 + '    34' + #10 +
      '    ```' + #10), 'message with a line break');
    Check(CompareEvents(Document.Invoice, Document, eln_German, False) = '', 'document: events');
    Check(CompareEvents(Document.Invoice, Document, eln_English, True, HostileDocumentName) = '',
      'document: events with a document name');
  finally
    W.Free;
    Document.Free;
  end;
end;

{ --- Markdown.Escaping -------------------------------------------------------- }

procedure BuildHostileInvoice(AInvoice: TLandrixInvoice);
var
  N: TLandrixInvoiceNote;
  L: TLandrixInvoiceLine;
  A: TLandrixInvoiceLineItemAttribute;
begin
  AInvoice.InvoiceNumber := '*a_b* [x](y) <b>&amp; #1 |c| ~d~ `e` \f !g 1. -h';
  AInvoice.BuyerReference := WithChar('ctl', 1, 'x');
  AInvoice.AccountingSupplierParty.Name := '#Firma ## GmbH #';
  AInvoice.PaymentTermNetNote := '  - like a list'#10'# like a heading'#10#10'    indented'#10'---';
  N := AInvoice.Notes.AddNote;
  N.Content := 'first'#13#10'``` not a fence'#13'#third'#10;
  N := AInvoice.Notes.AddNote;
  N.Content := '<script>alert(1)</script> &copy; ![i](x.png) <http://e.com> <a@b.de> **bold** _em_ \';
  L := AInvoice.InvoiceLines.AddInvoiceLine;
  L.ID := '1.';
  L.Name := '> quote';
  A := L.ItemAttributes.AddItemAttribute;
  A.Name := '| a | b |';
  A.Value := '````';
end;

procedure TestEscaping;
var
  Inv: TLandrixInvoice;
  W: TLandrixEInvoiceRenderMarkdownWriter;
  Md: TLandrixXmlUtf8;
  Problem: string;
begin
  Inv := TLandrixInvoice.Create;
  W := TLandrixEInvoiceRenderMarkdownWriter.Create;
  try
    BuildHostileInvoice(Inv);
    Md := MarkdownOf(Inv, eln_English, False);
    Check(Contains(Md, '- **Invoice number:** \*a\_b\* \[x\](y) \<b\>\&amp; \#1 \|c\| \~d\~ \`e\` \\f !g 1. -h' +
      #10), 'inline escaping');
    Check(Contains(Md, WithChar('- **Buyer reference:** ctl', $FFFD, 'x')), 'control character replaced');
    Check(Contains(Md, 'U+FFFD'), 'sanitized: note');
    Check(Contains(Md, '* **Note:**' + #10 + '  ````' + #10 + '  first' + #10 + '  ``` not a fence' + #10 +
      '  #third' + #10 + #10 + '  ````' + #10), 'multi-line value in a longer fence');
    Check(Contains(Md, '- **Trading name:** \#Firma \#\# GmbH \#' + #10), 'hash escaped');
    Check(Contains(Md, '\<script\>alert(1)\</script\> \&copy; !\[i\](x.png) \<http://e.com\> \<a@b.de\> ' +
      '\*\*bold\*\* \_em\_ \\' + #10), 'HTML, entity, image, autolinks and emphasis escaped');
    Check(Contains(Md, '  ```' + #10 + '    - like a list' + #10), 'value with line breaks keeps its spaces');
    Check(not HasCR(Md), 'no CR');
    W.DocumentName := HostileDocumentName;
    Check(Copy(LandrixEInvoiceStringToUtf8(W.WriteToString(Inv)), 1, 36) =
      TLandrixXmlUtf8('# Invoice: \*x\* \<y\> \[z\](w) \#1' + #10), 'document name escaped');
    CheckEvents(Inv, eln_English, False, 'hostile');
    CheckEvents(Inv, eln_German, True, 'hostile de');
    Problem := CompareEvents(Inv, nil, eln_English, False, HostileDocumentName);
    Check(Problem = '', 'hostile with document name: ' + Problem);
  finally
    W.Free;
    Inv.Free;
  end;
end;

{ --- Markdown.Events ---------------------------------------------------------- }

procedure TestEvents;
var
  Inv: TLandrixInvoice;
  Items: Integer;
begin
  for Items := 1 to 2 do
  begin
    Inv := TLandrixInvoice.Create;
    try
      FillInvoiceAll(Inv, Items);
      CheckEvents(Inv, eln_English, False, IntToStr(Items) + ' en');
      CheckEvents(Inv, eln_English, True, IntToStr(Items) + ' en bt');
      CheckEvents(Inv, eln_German, False, IntToStr(Items) + ' de');
      CheckEvents(Inv, eln_German, True, IntToStr(Items) + ' de bt');
    finally
      Inv.Free;
    end;
  end;
  Inv := TLandrixInvoice.Create;
  try
    BuildFullInvoice(Inv);
    CheckEvents(Inv, eln_English, False, 'full en');
    CheckEvents(Inv, eln_German, True, 'full de');
  finally
    Inv.Free;
  end;
end;

{ --- Markdown.Mutations ------------------------------------------------------- }

procedure TestMutations;
var
  Base, Inv: TLandrixInvoice;
  Md0, Md: TLandrixXmlUtf8;
  Items, I, Failed: Integer;
  Path, Problem: string;
begin
  Failed := 0;
  for Items := 1 to 2 do
  begin
    Base := TLandrixInvoice.Create;
    try
      FillInvoiceAll(Base, Items);
      Md0 := MarkdownOf(Base, eln_English, True);
    finally
      Base.Free;
    end;
    for I := 0 to InvoiceLeafCount(Items) - 1 do
    begin
      Inv := TLandrixInvoice.Create;
      try
        FillInvoiceAll(Inv, Items);
        MutateInvoiceLeaf(Inv, I, Path, Items);
        Md := MarkdownOf(Inv, eln_English, True);
        if Md = Md0 then
          Problem := 'text unchanged'
        else
          Problem := CompareEvents(Inv, nil, eln_English, True);
      finally
        Inv.Free;
      end;
      if Problem <> '' then
      begin
        Inc(Failed);
        if Failed <= 40 then
          WriteLn('  ', Items, ' item(s): ', Path, ': ', Problem);
      end;
    end;
  end;
  CheckEquals(0, Failed, IntToStr(InvoiceLeafCount(1)) + ' + ' + IntToStr(InvoiceLeafCount(2)) +
    ' mutations, with findings');
end;

{ --- Markdown.Golden ---------------------------------------------------------- }

procedure TestGolden;
var
  Inv: TLandrixInvoice;
begin
  Inv := TLandrixInvoice.Create;
  try
    BuildFullInvoice(Inv);
    CheckGoldenFile(MarkdownOf(Inv, eln_English, False), 'render', 'full-en.md');
    CheckGoldenFile(MarkdownOf(Inv, eln_German, True), 'render', 'full-de-bt.md');
  finally
    Inv.Free;
  end;
  Inv := TLandrixInvoice.Create;
  try
    BuildCreditNote(Inv);
    CheckGoldenFile(MarkdownOf(Inv, eln_English, False), 'render', 'credit-en.md');
    CheckGoldenFile(MarkdownOf(Inv, eln_German, False), 'render', 'credit-de.md');
  finally
    Inv.Free;
  end;
end;

{ --- Markdown.Corpus ---------------------------------------------------------- }

procedure RenderFolder(const ADir: string; var AFiles, AFailed: Integer);
var
  SR: TSearchRec;
  Document: TLandrixEInvoiceDocument;
  Name, Problem: string;
begin
  if FindFirst(ADir + '*', faAnyFile, SR) = 0 then
    try
      repeat
        if (SR.Name = '.') or (SR.Name = '..') then
          Continue;
        Name := ADir + SR.Name;
        if (SR.Attr and faDirectory) <> 0 then
          RenderFolder(Name + PathDelim, AFiles, AFailed)
        else if LowerCase(ExtractFileExt(SR.Name)) = '.xml' then
        begin
          Inc(AFiles);
          try
            Document := TLandrixEInvoice.LoadFromFile(TLandrixEInvoiceString(Name));
          except
            { not readable as an invoice: the business of the reading tests }
            Document := nil;
          end;
          if Document = nil then
            Continue;
          try
            try
              Problem := CompareEvents(Document.Invoice, Document, eln_English, False);
              if Problem = '' then
                Problem := CompareEvents(Document.Invoice, Document, eln_German, True);
            except
              on E: Exception do
                Problem := E.ClassName + ': ' + E.Message;
            end;
            if Problem <> '' then
            begin
              Inc(AFailed);
              if AFailed <= 20 then
                WriteLn('  ', Name, ': ', Problem);
            end;
          finally
            Document.Free;
          end;
        end;
      until FindNext(SR) <> 0;
    finally
      FindClose(SR);
    end;
end;

procedure TestCorpus;
const
  Folders: array[0..3] of string = ('golden', 'cii', 'ubl', 'sweep');
var
  Local: string;
  I, Files, Failed: Integer;
begin
  Local := RepositoryRoot + 'tests' + PathDelim + 'data' + PathDelim + 'local' + PathDelim;
  if not DirectoryExists(Local) then
  begin
    Skip('no local test data in ' + Local);
    Exit;
  end;
  Files := 0;
  Failed := 0;
  for I := Low(Folders) to High(Folders) do
    if DirectoryExists(Local + Folders[I]) then
      RenderFolder(Local + Folders[I] + PathDelim, Files, Failed);
  WriteLn('  rendered: ', Files, ' files in two languages');
  Check(Files > 0, 'local files');
  CheckEquals(0, Failed, 'files whose text does not match the walk');
end;

procedure Register;
begin
  RegisterTest('Markdown.Writer', TestWriter);
  RegisterTest('Markdown.Escaping', TestEscaping);
  RegisterTest('Markdown.Events', TestEvents);
  RegisterTest('Markdown.Mutations', TestMutations);
  RegisterTest('Markdown.Golden', TestGolden);
  RegisterTest('Markdown.Corpus', TestCorpus);
end;

end.
