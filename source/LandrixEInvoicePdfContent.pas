{
  EInvoice-for-Pascal

  Copyright (C) 2026 Landrix Software GmbH & Co. KG

  This file is dual-licensed under:
  - GNU GPL version 3 or later; or
  - the Landrix Software Commercial License.

  See LICENSE and COMMERCIAL-LICENSE.md.

  SPDX-License-Identifier: GPL-3.0-or-later OR LicenseRef-Landrix-Commercial
}

{ The content streams of a PDF read as the PDF/A-3b checks (ISO 19005-3,
  6.1.6, 6.1.10, 6.1.13 and 6.8) need them, the way veraPDF reads them:
  - the streams that are reached: the /Contents of every page (an array is
    one stream, a CR between its parts), form XObjects called with Do,
    tiling patterns selected with scn or SCN, all glyph procedures of a
    Type 3 font that shows text, and the normal, down and rollover
    appearances of every annotation of a page; resources are looked up in
    the stream's own resources and then in those of the page; a stream
    object is validated once, wherever veraPDF meets it first;
  - the operands an operator passes on to the checks (veraPDF checks only
    these, e.g. w checks its last operand only), the q nesting depth, the
    filters of inline images, file specifications inside inline
    dictionaries and the files that /AF /Name BDC associates;
  - what makes veraPDF see nothing: an unknown filter or DCTDecode gives no
    data, a syntax error inside an array or dictionary drops the whole
    stream, a stray ] ends it.
  A stream veraPDF might read differently (damaged or tolerated Flate data,
  other filters, encryption, a value too close to a limit, a stream reached
  in several ways with different results) makes the affected checks
  uncertain instead of failing them.

  DE: Die Content-Streams eines PDF, gelesen wie es die PDF/A-3b-Pruefungen
  (ISO 19005-3, 6.1.6, 6.1.10, 6.1.13 und 6.8) brauchen, so wie veraPDF sie
  liest:
  - die Streams, die erreicht werden: die /Contents jeder Seite (ein Array
    ist ein Stream, ein CR zwischen seinen Teilen), Form-XObjects, die Do
    aufruft, Kachelmuster, die scn oder SCN waehlt, alle Glyphenprozeduren
    einer Type-3-Schrift, die Text zeigt, und die normale, gedrueckte und
    Rollover-Erscheinung jeder Annotation einer Seite; Ressourcen werden in
    den eigenen Ressourcen des Streams und dann in denen der Seite gesucht;
    ein Stream-Objekt wird einmal geprueft, wo veraPDF es zuerst trifft;
  - die Operanden, die ein Operator an die Pruefungen weitergibt (veraPDF
    prueft nur diese, z. B. prueft w nur seinen letzten Operanden), die
    Schachtelungstiefe von q, die Filter von Inline-Bildern,
    Dateispezifikationen in Inline-Dictionaries und die Dateien, die /AF
    /Name BDC zuordnet;
  - was veraPDF nichts sehen laesst: ein unbekannter Filter oder DCTDecode
    liefert keine Daten, ein Syntaxfehler in einem Array oder Dictionary
    verwirft den ganzen Stream, ein einzelnes ] beendet ihn.
  Ein Stream, den veraPDF anders lesen koennte (beschaedigte oder nur
  nachsichtig lesbare Flate-Daten, andere Filter, Verschluesselung, ein Wert
  zu nah an einer Grenze, ein Stream, der auf mehreren Wegen mit
  verschiedenem Ergebnis erreicht wird), macht die betroffenen Pruefungen
  unsicher, statt sie scheitern zu lassen. }

{ API: internal. May change in any release; use the facade LandrixEInvoice
  or the stable units instead.
  DE: API: intern. Kann sich in jeder Version aendern; stattdessen die
  Fassade LandrixEInvoice oder die stabilen Units verwenden. }

unit LandrixEInvoicePdfContent;

{$I LandrixEInvoice.inc}

interface

uses
  Classes,
  Contnrs,
  LandrixEInvoicePdfObjects;

type
  { What a finding in a content stream is about: an integer, a real number
    out of range or too close to zero, a string too long, a hexadecimal
    string with an odd number of characters or with other characters than
    hex digits, a name too long, an inline image filter that is not
    allowed, q nested too deep, a file specification with /EF but without
    /F and /UF strings, without /AFRelationship, or direct (never
    associated).
    DE: Worum es bei einem Befund in einem Content-Stream geht: eine ganze
    Zahl, eine reelle Zahl ausserhalb des Bereichs oder zu nah an null, ein
    zu langer String, ein hexadezimaler String mit ungerader Zeichenzahl
    oder mit anderen Zeichen als Hex-Ziffern, ein zu langer Name, ein nicht
    erlaubter Filter eines Inline-Bilds, q zu tief verschachtelt, eine
    Dateispezifikation mit /EF ohne /F- und /UF-Strings, ohne
    /AFRelationship oder direkt (nie zugeordnet). }
  TLandrixEInvoicePdfContentCheck = (pcc_Integer, pcc_Real, pcc_SmallReal, pcc_StringLength, pcc_HexOdd,
    pcc_HexDigits, pcc_NameLength, pcc_InlineFilter, pcc_Nesting, pcc_SpecNames, pcc_SpecRelationship,
    pcc_SpecDirect);

  { A finding that veraPDF certainly reports: the content stream object
    (for the /Contents array of a page its first stream) and a short text.
    DE: Ein Befund, den veraPDF sicher meldet: das Content-Stream-Objekt
    (beim /Contents-Array einer Seite sein erster Stream) und ein kurzer
    Text. }
  TLandrixEInvoicePdfContentFinding = record
    Check: TLandrixEInvoicePdfContentCheck;
    ObjNum: Integer;
    ObjGen: Integer;
    Detail: string;
  end;

  { Walks the content streams of a document once (Run) and keeps what the
    checks need.
    DE: Durchlaeuft die Content-Streams eines Dokuments einmal (Run) und
    behaelt, was die Pruefungen brauchen. }
  TLandrixEInvoicePdfContentWalk = class(TObject)
  private
    FDoc: TLandrixEInvoicePdfDocument;
    FParses: TObjectList;
    FMemo: TStringList;
    FActive: TStringList;
    FType3Seen: TStringList;
    FReachDepth: Integer;
    FTotalBytes: Int64;
    FPageNodes: Integer;
    FPageCount: Integer;
    { values alive in all lexers of the walk (nested parses included) }
    FLive: Integer;
    FIncomplete: Boolean;
    FMaxReal: Double;
    FMinReal: Double;
    FMaxDouble: Double;
    FTiny: Double;
    FNearHigh: Double;
    FNearHighTop: Double;
    FNearLow: Double;
    FNearLowTop: Double;
    { all findings of all parses: parse index, check, maybe, text }
    FFParse: array of Integer;
    FFCheck: array of TLandrixEInvoicePdfContentCheck;
    FFMaybe: array of Boolean;
    FFDetail: array of string;
    FFCount: Integer;
    { the result }
    FFindings: array of TLandrixEInvoicePdfContentFinding;
    FFindingCount: Integer;
    FUncertain: array[TLandrixEInvoicePdfContentCheck] of Boolean;
    FAssocSure: array of Boolean;
    FAssocMaybe: array of Boolean;
    { some stream could not be read with certainty: what it reaches and
      associates is unknown }
    FAnyUncertain: Boolean;
    FAssocAll: Boolean;
    { the pages veraPDF sees may differ: no finding is certain }
    FPagesUnsure: Boolean;
    FLimitHit: Boolean;
    function ObjId(AObj: TLandrixEInvoicePdfObject): string;
    function ResolveRef(ARaw: TLandrixEInvoicePdfObject): TLandrixEInvoicePdfObject;
    function DGetRef(AObj: TLandrixEInvoicePdfObject; const AKey: AnsiString): TLandrixEInvoicePdfObject;
    function LastRefNum(ARaw: TLandrixEInvoicePdfObject): Integer;
    function StreamBytes(AStream: TLandrixEInvoicePdfObject; out AData: TLandrixEInvoicePdfBytes): Boolean;
    function WalkPages(ANode, AInherited: TLandrixEInvoicePdfObject; ADepth: Integer): Integer;
    procedure WalkPage(APage, AInherited: TLandrixEInvoicePdfObject);
    procedure Finish;
    procedure ScanTiling;
  public
    constructor Create(ADoc: TLandrixEInvoicePdfDocument);
    destructor Destroy; override;
    { Walks every page of the document. DE: Durchlaeuft jede Seite des
      Dokuments. }
    procedure Run;
    { The findings veraPDF certainly reports. DE: Die Befunde, die veraPDF
      sicher meldet. }
    function FindingCount: Integer;
    function Finding(AIndex: Integer): TLandrixEInvoicePdfContentFinding;
    { A check may have findings that are not certain (or content that could
      not be read the way veraPDF reads it): the rule stays undecided where
      no certain finding exists.
      DE: Eine Pruefung kann Befunde haben, die nicht sicher sind (oder
      Inhalt, der sich nicht so lesen liess, wie veraPDF ihn liest): die
      Regel bleibt offen, wo kein sicherer Befund existiert. }
    function Uncertain(ACheck: TLandrixEInvoicePdfContentCheck): Boolean;
    { Object ANum is certainly associated by /AF /Name BDC in a content
      stream veraPDF reads; or it may be.
      DE: Objekt ANum wird sicher durch /AF /Name BDC in einem Content-Stream
      zugeordnet, den veraPDF liest; oder es kann sein. }
    function AssociatedSure(ANum: Integer): Boolean;
    function AssociatedMaybe(ANum: Integer): Boolean;
  end;

implementation

uses
  SysUtils;

const
  { q may nest 28 levels deep (ISO 19005-2, 6.1.13) }
  MaxNesting = 28;
  { limits of the walk; beyond them every check is uncertain }
  MaxReachDepth = 48;
  MaxParses = 20000;
  MaxTotalBytes = 256 * 1024 * 1024;
  MaxParts = 10000;
  { tokens of one stream (nested values included), values alive at once in
    all streams being parsed (the operands waiting for an operator and their
    items), operands waiting for an operator }
  MaxTokens = 50000000;
  MaxLive = 500000;
  MaxPending = 1000000;
  MaxCompoundDepth = 200;
  MaxPageDepth = 64;
  MaxPageNodes = 200000;
  { veraPDF looks one token ahead after EI and reads it back from a buffer
    of 2048 bytes that keeps at least 1024 bytes behind its position }
  MaxLookahead = 1000;
  { findings kept per parse and check (the level counts all of them) }
  MaxFindingsPerCheck = 20;

  { what an operator passes on (see TInterpreter.Operate) }
  oc_None = 0;
  oc_Number = 1;
  oc_Integer = 2;
  oc_Dash = 3;
  oc_Intent = 4;
  oc_Push = 5;
  oc_Pop = 6;
  oc_NumberList = 7;
  oc_Glyph = 8;
  oc_TwoNumbers = 9;
  oc_Font = 10;
  oc_Show = 11;
  oc_ShowSpaced = 12;
  oc_ShowArray = 13;
  oc_Color = 14;
  oc_SpaceStroke = 15;
  oc_SpaceFill = 16;
  oc_ColorNStroke = 17;
  oc_ColorNFill = 18;
  oc_DeviceStroke = 19;
  oc_DeviceFill = 20;
  oc_Shading = 21;
  oc_Do = 22;
  oc_Tag = 23;
  oc_TagProps = 24;
  oc_TagPropsBegin = 25;
  oc_Inline = 26;
  oc_Other = 27;
  oc_ExtGState = 28;

  OpCount = 71;
  OpNames: array[0..OpCount - 1] of AnsiString = (
    'w', 'M', 'i', 'Tc', 'Tw', 'Tz', 'TL', 'Ts',
    'J', 'j',
    'd',
    'ri',
    'q', 'Q',
    'cm', 'm', 'l', 'c', 'v', 'y', 're', 'Tm',
    'd1',
    'Td', 'TD', 'd0',
    'Tf',
    'Tj', '''',
    '"',
    'TJ',
    'SC', 'sc',
    'CS', 'cs',
    'SCN', 'scn',
    'G', 'RG', 'K', 'g', 'rg', 'k',
    'sh',
    'Do',
    'MP', 'BMC',
    'DP', 'BDC',
    'BI',
    'gs', 'Tr', 'h', 'W', 'W*', 'n', 'S', 's', 'f', 'F', 'f*', 'B', 'B*', 'b', 'b*', 'BT', 'ET', 'T*', 'EMC',
    'BX', 'EX');
  OpCodes: array[0..OpCount - 1] of Integer = (
    oc_Number, oc_Number, oc_Number, oc_Number, oc_Number, oc_Number, oc_Number, oc_Number,
    oc_Integer, oc_Integer,
    oc_Dash,
    oc_Intent,
    oc_Push, oc_Pop,
    oc_NumberList, oc_NumberList, oc_NumberList, oc_NumberList, oc_NumberList, oc_NumberList, oc_NumberList,
    oc_NumberList,
    oc_Glyph,
    oc_TwoNumbers, oc_TwoNumbers, oc_TwoNumbers,
    oc_Font,
    oc_Show, oc_Show,
    oc_ShowSpaced,
    oc_ShowArray,
    oc_Color, oc_Color,
    oc_SpaceStroke, oc_SpaceFill,
    oc_ColorNStroke, oc_ColorNFill,
    oc_DeviceStroke, oc_DeviceStroke, oc_DeviceStroke, oc_DeviceFill, oc_DeviceFill, oc_DeviceFill,
    oc_Shading,
    oc_Do,
    oc_Tag, oc_Tag,
    oc_TagProps, oc_TagPropsBegin,
    oc_Inline,
    oc_ExtGState, oc_Other, oc_Other, oc_Other, oc_Other, oc_Other, oc_Other, oc_Other, oc_Other, oc_Other, oc_Other,
    oc_Other, oc_Other, oc_Other, oc_Other, oc_Other, oc_Other, oc_Other, oc_Other, oc_Other, oc_Other);

  { the filters 6.1.10-1 allows for inline images }
  InlineFilters: array[0..11] of AnsiString = ('ASCIIHexDecode', 'ASCII85Decode', 'FlateDecode', 'RunLengthDecode',
    'CCITTFaxDecode', 'DCTDecode', 'AHx', 'A85', 'Fl', 'RL', 'CCF', 'DCT');
  { stream filters veraPDF may decode; any other name (also the abbreviation
    Fl, which veraPDF does not register for streams) gives no data }
  KnownFilters: array[0..15] of AnsiString = ('ASCIIHexDecode', 'AHx', 'ASCII85Decode', 'A85', 'LZWDecode', 'LZW',
    'FlateDecode', 'RunLengthDecode', 'RL', 'CCITTFaxDecode', 'CCF', 'JBIG2Decode', 'DCTDecode', 'DCT',
    'JPXDecode', 'Crypt');

function OpCode(const AName: AnsiString): Integer;
var
  I: Integer;
begin
  for I := 0 to OpCount - 1 do
    if OpNames[I] = AName then
    begin
      Result := OpCodes[I];
      Exit;
    end;
  Result := oc_None;
end;

function InList(const AName: AnsiString; const AList: array of AnsiString): Boolean;
var
  I: Integer;
begin
  Result := True;
  for I := 0 to Integer(High(AList)) do
    if AList[I] = AName then
      Exit;
  Result := False;
end;

function IsWhite(B: Byte): Boolean;
begin
  Result := (B = 0) or (B = 9) or (B = 10) or (B = 12) or (B = 13) or (B = 32);
end;

function IsDelim(B: Byte): Boolean;
begin
  Result := (B = Ord('(')) or (B = Ord(')')) or (B = Ord('<')) or (B = Ord('>')) or (B = Ord('[')) or
    (B = Ord(']')) or (B = Ord('{')) or (B = Ord('}')) or (B = Ord('/')) or (B = Ord('%'));
end;

function IsRegular(B: Byte): Boolean;
begin
  Result := not IsWhite(B) and not IsDelim(B);
end;

function IsNumberStart(B: Byte): Boolean;
begin
  Result := ((B >= Ord('0')) and (B <= Ord('9'))) or (B = Ord('+')) or (B = Ord('-')) or (B = Ord('.'));
end;

function HexDigit(B: Byte): Integer;
begin
  if (B >= Ord('0')) and (B <= Ord('9')) then
    Result := B - Ord('0')
  else if (B >= Ord('a')) and (B <= Ord('f')) then
    Result := B - Ord('a') + 10
  else if (B >= Ord('A')) and (B <= Ord('F')) then
    Result := B - Ord('A') + 10
  else
    Result := -1;
end;

{ ASCII bytes as a string, byte by byte. }
function AsciiOf(const A: AnsiString): string;
var
  I: Integer;
begin
  Result := '';
  SetLength(Result, Length(A));
  for I := 1 to Length(A) do
    Result[I] := Char(A[I]);
end;

function HasByte(const A: AnsiString; C: AnsiChar): Boolean;
var
  I: Integer;
begin
  Result := False;
  for I := 1 to Length(A) do
    if A[I] = C then
    begin
      Result := True;
      Exit;
    end;
end;

function TextOf(const AName: AnsiString): string;
var
  I: Integer;
begin
  Result := '';
  for I := 1 to Length(AName) do
    if (Ord(AName[I]) >= 32) and (Ord(AName[I]) < 127) then
      Result := Result + Char(AName[I])
    else
      Result := Result + '#' + IntToHex(Ord(AName[I]), 2);
  if Length(Result) > 40 then
    Result := Copy(Result, 1, 40) + '...';
end;

function FloatOf(const AText: string): Double;
var
  Code: Integer;
begin
  Val(AText, Result, Code);
  if Code <> 0 then
    Result := 0;
end;

//==============================================================================
// Values of a content stream
//==============================================================================

type
  TCvKind = (cvk_Int, cvk_Real, cvk_Bool, cvk_Null, cvk_Str, cvk_Name, cvk_Arr, cvk_Dict, cvk_Op);

  { A token of a content stream: an operand (number, string, name, array,
    dictionary) or an operator. }
  TCv = class(TObject)
  public
    Kind: TCvKind;
    IntVal: Int64;
    RealVal: Double;
    { the real number is too close to a limit to decide }
    RealNear: Boolean;
    { a name, a keyword }
    Text: AnsiString;
    { strings: the length range as veraPDF measures it, hex facts }
    LenLo: Integer;
    LenHi: Integer;
    Hex: Boolean;
    HexChars: Integer;
    HexInvalid: Boolean;
    { array items or dictionary values (owned by the pool) }
    Items: TObjectList;
    Keys: array of AnsiString;
    { BI: the image dictionary }
    ImageDict: TCv;
    constructor Create(AKind: TCvKind);
    destructor Destroy; override;
    function Get(const AKey: AnsiString): TCv;
    procedure Put(const AKey: AnsiString; AValue: TCv);
  end;

constructor TCv.Create(AKind: TCvKind);
begin
  inherited Create;
  Kind := AKind;
  if (AKind = cvk_Arr) or (AKind = cvk_Dict) then
    Items := TObjectList.Create(False);
end;

destructor TCv.Destroy;
begin
  Items.Free;
  inherited Destroy;
end;

function TCv.Get(const AKey: AnsiString): TCv;
var
  I: Integer;
begin
  Result := nil;
  if Kind <> cvk_Dict then
    Exit;
  for I := 0 to Integer(Length(Keys)) - 1 do
    if Keys[I] = AKey then
    begin
      Result := TCv(Items[I]);
      Exit;
    end;
end;

{ a later key replaces an earlier one, as in a map }
procedure TCv.Put(const AKey: AnsiString; AValue: TCv);
var
  I, K: Integer;
begin
  for I := 0 to Integer(Length(Keys)) - 1 do
    if Keys[I] = AKey then
    begin
      if AValue.Kind = cvk_Null then
      begin
        { a null value removes the key, as in veraPDF's dictionaries }
        for K := I to Integer(Length(Keys)) - 2 do
          Keys[K] := Keys[K + 1];
        SetLength(Keys, Length(Keys) - 1);
        Items.Delete(I);
      end
      else
        Items[I] := AValue;
      Exit;
    end;
  if AValue.Kind = cvk_Null then
    Exit;
  SetLength(Keys, Length(Keys) + 1);
  Keys[High(Keys)] := AKey;
  Items.Add(AValue);
end;

//==============================================================================
// Lexer
//==============================================================================

type
  { ok; failed: veraPDF throws and sees no operator of the stream; unknown:
    veraPDF might read it differently }
  TLexStatus = (lxs_Ok, lxs_Failed, lxs_Unknown);

  TLookahead = (lka_Accept, lka_Reject, lka_Unknown);

  { Splits a content stream into tokens as veraPDF's stream parser does, one
    token at a time (Next); Release frees the tokens read so far. }
  TContentLexer = class(TObject)
  private
    FBuf: TLandrixEInvoicePdfBytes;
    FLen: Integer;
    FPos: Integer;
    FPool: TObjectList;
    FStatus: TLexStatus;
    FWalk: TLandrixEInvoicePdfContentWalk;
    FPending: Integer;
    FCount: Integer;
    FDone: Boolean;
    function NewCv(AKind: TCvKind): TCv;
    function AtEnd: Boolean;
    procedure SkipWhite;
    function ReadKeyword: AnsiString;
    function ReadOperator: AnsiString;
    function ParseNumber: TCv;
    function ParseLiteral: TCv;
    function ParseHex: TCv;
    function ParseName: TCv;
    function ParseValue(ADepth: Integer): TCv;
    function ParseArray(ADepth: Integer): TCv;
    function ParseDict(ADepth: Integer): TCv;
    function ParseInline: TCv;
    function Lookahead(APos: Integer): TLookahead;
  public
    constructor Create(AWalk: TLandrixEInvoicePdfContentWalk; const ABuf: TLandrixEInvoicePdfBytes);
    destructor Destroy; override;
    { The next token, nil at the end (also after a stray ]) or when the
      status is no longer lxs_Ok. }
    function Next: TCv;
    procedure Release;
    property Status: TLexStatus read FStatus;
  end;

constructor TContentLexer.Create(AWalk: TLandrixEInvoicePdfContentWalk; const ABuf: TLandrixEInvoicePdfBytes);
begin
  inherited Create;
  FWalk := AWalk;
  FBuf := ABuf;
  FLen := Integer(Length(ABuf));
  FPool := TObjectList.Create(True);
  FStatus := lxs_Ok;
end;

destructor TContentLexer.Destroy;
begin
  Dec(FWalk.FLive, FPool.Count);
  FPool.Free;
  inherited Destroy;
end;

procedure TContentLexer.Release;
begin
  Dec(FWalk.FLive, FPool.Count);
  FPool.Clear;
end;

function TContentLexer.NewCv(AKind: TCvKind): TCv;
begin
  Result := TCv.Create(AKind);
  FPool.Add(Result);
  Inc(FCount);
  Inc(FWalk.FLive);
  if (FCount > MaxTokens) or (FWalk.FLive > MaxLive) then
    FStatus := lxs_Unknown;
end;

function TContentLexer.AtEnd: Boolean;
begin
  Result := FPos >= FLen;
end;

procedure TContentLexer.SkipWhite;
begin
  while FPos < FLen do
  begin
    if IsWhite(FBuf[FPos]) then
      Inc(FPos)
    else if FBuf[FPos] = Ord('%') then
    begin
      while (FPos < FLen) and (FBuf[FPos] <> 10) and (FBuf[FPos] <> 13) do
        Inc(FPos);
    end
    else
      Break;
  end;
end;

function TContentLexer.ReadKeyword: AnsiString;
var
  Start: Integer;
begin
  Start := FPos;
  while (FPos < FLen) and IsRegular(FBuf[FPos]) do
    Inc(FPos);
  Result := LandrixEInvoicePdfBytesToAnsi(FBuf, Start, FPos - Start);
end;

{ The end of an operator as veraPDF's stream parser reads it from APos: up
  to white space, [, ], <, (, / or a digit, where a 0 or 1 right after a d
  belongs to it (d0, d1, also d1q); other delimiters such as % or > belong
  to it. }
function OperatorEnd(const ABuf: TLandrixEInvoicePdfBytes; ALen, APos: Integer): Integer;
var
  B: Byte;
begin
  Result := APos + 1;
  while Result < ALen do
  begin
    B := ABuf[Result];
    if IsWhite(B) or (B = Ord('[')) or (B = Ord(']')) or (B = Ord('<')) or (B = Ord('(')) or (B = Ord('/')) then
      Break;
    if (B >= Ord('0')) and (B <= Ord('9')) then
    begin
      if ((B = Ord('0')) or (B = Ord('1'))) and (ABuf[Result - 1] = Ord('d')) then
      begin
        Inc(Result);
        Continue;
      end;
      Break;
    end;
    Inc(Result);
  end;
end;

{ A token starting with f, t, n or B goes another path in veraPDF: up to
  the next white space or delimiter (digits included); true, false and null
  are operands, BI starts an inline image, anything else is an operator. }
function KeywordEnd(const ABuf: TLandrixEInvoicePdfBytes; ALen, APos: Integer): Integer;
begin
  Result := APos + 1;
  while (Result < ALen) and IsRegular(ABuf[Result]) do
    Inc(Result);
end;

function IsKeywordStart(B: Byte): Boolean;
begin
  Result := (B = Ord('f')) or (B = Ord('t')) or (B = Ord('n')) or (B = Ord('B'));
end;

function TContentLexer.ReadOperator: AnsiString;
var
  Start: Integer;
begin
  Start := FPos;
  if IsKeywordStart(FBuf[FPos]) then
    FPos := KeywordEnd(FBuf, FLen, FPos)
  else
    FPos := OperatorEnd(FBuf, FLen, FPos);
  Result := LandrixEInvoicePdfBytesToAnsi(FBuf, Start, FPos - Start);
end;

function TContentLexer.ParseNumber: TCv;
var
  Neg, Valid: Boolean;
  Start, Dots, I, Dot, IntDigits, LeadZeros: Integer;
  Digits, IntPart, FracPart: AnsiString;
  V: Int64;
  D: Double;
  S: string;
  W: TLandrixEInvoicePdfContentWalk;
begin
  Neg := False;
  if FBuf[FPos] = Ord('-') then
  begin
    Neg := True;
    Inc(FPos);
  end
  else if FBuf[FPos] = Ord('+') then
    Inc(FPos);
  Start := FPos;
  Dots := 0;
  while (FPos < FLen) and (((FBuf[FPos] >= Ord('0')) and (FBuf[FPos] <= Ord('9'))) or (FBuf[FPos] = Ord('.'))) do
  begin
    if FBuf[FPos] = Ord('.') then
      Inc(Dots);
    Inc(FPos);
  end;
  Digits := LandrixEInvoicePdfBytesToAnsi(FBuf, Start, FPos - Start);
  if Dots = 0 then
  begin
    Result := NewCv(cvk_Int);
    Valid := Digits <> '';
    V := 0;
    I := 1;
    while Valid and (I <= Length(Digits)) do
    begin
      if V > (High(Int64) - (Ord(Digits[I]) - Ord('0'))) div 10 then
        Valid := False
      else
        V := V * 10 + (Ord(Digits[I]) - Ord('0'));
      Inc(I);
    end;
    if not Valid then
      V := High(Int64);
    if Neg then
      V := -V;
    Result.IntVal := V;
    Exit;
  end;
  Result := NewCv(cvk_Real);
  W := FWalk;
  { one dot and at least one digit, else Double.MAX_VALUE }
  if (Dots <> 1) or (Length(Digits) < 2) then
  begin
    D := W.FMaxDouble;
    if Neg then
      D := -D;
    Result.RealVal := D;
    Exit;
  end;
  Dot := Pos('.', AsciiOf(Digits));
  IntPart := Copy(Digits, 1, Dot - 1);
  FracPart := Copy(Digits, Dot + 1, MaxInt);
  I := 1;
  while (I <= Length(IntPart)) and (IntPart[I] = '0') do
    Inc(I);
  IntPart := Copy(IntPart, I, MaxInt);
  IntDigits := Length(IntPart);
  LeadZeros := 0;
  while (LeadZeros < Length(FracPart)) and (FracPart[LeadZeros + 1] = '0') do
    Inc(LeadZeros);
  if IntDigits > 39 then
    D := W.FMaxDouble
  else if (IntDigits = 0) and (LeadZeros = Length(FracPart)) then
    D := 0
  else if (IntDigits = 0) and (LeadZeros > 320) then
  begin
    { may underflow to zero in binary64 }
    D := 0;
    Result.RealNear := True;
  end
  else if (IntDigits = 0) and (LeadZeros >= 39) then
    D := W.FTiny
  else
  begin
    { the significant digits, enough of them for binary64 }
    if IntDigits = 0 then
      S := '0.' + AsciiOf(Copy(FracPart, 1, LeadZeros + 60))
    else if FracPart = '' then
      S := AsciiOf(IntPart) + '.0'
    else
      S := AsciiOf(IntPart) + '.' + AsciiOf(Copy(FracPart, 1, 60));
    D := FloatOf(S);
  end;
  if (Abs(D) >= W.FNearHigh) and (Abs(D) <= W.FNearHighTop) then
    Result.RealNear := True;
  if (Abs(D) >= W.FNearLow) and (Abs(D) <= W.FNearLowTop) then
    Result.RealNear := True;
  if Neg then
    D := -D;
  Result.RealVal := D;
end;

function TContentLexer.ParseLiteral: TCv;
var
  Depth, Oct, K, CrLf, N: Integer;
  B: Byte;
  Bytes: TLandrixEInvoicePdfBytes;

  procedure Add(AByte: Byte);
  begin
    if N >= Length(Bytes) then
      SetLength(Bytes, 64 + 2 * N);
    Bytes[N] := AByte;
    Inc(N);
  end;

begin
  Result := NewCv(cvk_Str);
  Bytes := nil;
  N := 0;
  Inc(FPos);
  Depth := 1;
  CrLf := 0;
  while FPos < FLen do
  begin
    B := FBuf[FPos];
    Inc(FPos);
    if B = Ord('\') then
    begin
      if FPos >= FLen then
        Break;
      B := FBuf[FPos];
      Inc(FPos);
      case B of
        Ord('n'): B := 10;
        Ord('r'): B := 13;
        Ord('t'): B := 9;
        Ord('b'): B := 8;
        Ord('f'): B := 12;
        10: Continue;
        13:
          begin
            if (FPos < FLen) and (FBuf[FPos] = 10) then
              Inc(FPos);
            Continue;
          end;
        48..55:
          begin
            Oct := B - 48;
            K := 1;
            while (K < 3) and (FPos < FLen) and (FBuf[FPos] >= 48) and (FBuf[FPos] <= 55) do
            begin
              Oct := Oct * 8 + (FBuf[FPos] - 48);
              Inc(FPos);
              Inc(K);
            end;
            B := Byte(Oct and $FF);
          end;
      else
        { the character itself }
      end;
      Add(B);
      Continue;
    end;
    if (B = 13) and (FPos < FLen) and (FBuf[FPos] = 10) then
      Inc(CrLf);
    if B = Ord('(') then
      Inc(Depth)
    else if B = Ord(')') then
    begin
      Dec(Depth);
      if Depth = 0 then
        Break;
    end;
    Add(B);
  end;
  SetLength(Bytes, N);
  LandrixEInvoicePdfJavaStringLength(Bytes, CrLf, Result.LenLo, Result.LenHi);
end;

{ A hexadecimal string: every character other than white space counts
  (hex digit or not); one that is no hex digit adds nothing; a last single
  digit is padded with 0 when > closes the string. }
function TContentLexer.ParseHex: TCv;
var
  Hi, V, N: Integer;
  B: Byte;
  Bytes: TLandrixEInvoicePdfBytes;
  Closed: Boolean;
begin
  Result := NewCv(cvk_Str);
  Result.Hex := True;
  Bytes := nil;
  N := 0;
  Hi := -1;
  Closed := False;
  Inc(FPos);
  while FPos < FLen do
  begin
    B := FBuf[FPos];
    Inc(FPos);
    if B = Ord('>') then
    begin
      Closed := True;
      Break;
    end;
    if IsWhite(B) then
      Continue;
    Inc(Result.HexChars);
    V := HexDigit(B);
    if V < 0 then
    begin
      Result.HexInvalid := True;
      Continue;
    end;
    if Hi < 0 then
      Hi := V
    else
    begin
      if N >= Length(Bytes) then
        SetLength(Bytes, 64 + 2 * N);
      Bytes[N] := Byte((Hi shl 4) or V);
      Inc(N);
      Hi := -1;
    end;
  end;
  if Closed and (Hi >= 0) then
  begin
    if N >= Length(Bytes) then
      SetLength(Bytes, N + 1);
    Bytes[N] := Byte(Hi shl 4);
    Inc(N);
  end;
  SetLength(Bytes, N);
  LandrixEInvoicePdfJavaStringLength(Bytes, 0, Result.LenLo, Result.LenHi);
end;

{ A name: #xx with two hex digits stands for one byte, any other # stays. }
function TContentLexer.ParseName: TCv;
var
  Start, Stop, I, V1, V2: Integer;
  S: AnsiString;
begin
  Result := NewCv(cvk_Name);
  Inc(FPos);
  Start := FPos;
  while (FPos < FLen) and IsRegular(FBuf[FPos]) do
    Inc(FPos);
  Stop := FPos;
  S := '';
  I := Start;
  while I < Stop do
  begin
    if (FBuf[I] = Ord('#')) and (I + 2 < Stop) then
    begin
      V1 := HexDigit(FBuf[I + 1]);
      V2 := HexDigit(FBuf[I + 2]);
      if (V1 >= 0) and (V2 >= 0) then
      begin
        S := S + AnsiChar((V1 shl 4) or V2);
        Inc(I, 3);
        Continue;
      end;
    end;
    S := S + AnsiChar(FBuf[I]);
    Inc(I);
  end;
  Result.Text := S;
end;

{ A value inside an array or dictionary. A keyword other than true, false
  and null (a reference R, an operator) or a stray delimiter is read by
  another parser path in veraPDF: not decided. }
function TContentLexer.ParseValue(ADepth: Integer): TCv;
var
  B: Byte;
  K: AnsiString;
begin
  Result := nil;
  if ADepth > MaxCompoundDepth then
  begin
    FStatus := lxs_Unknown;
    Exit;
  end;
  SkipWhite;
  if AtEnd then
  begin
    FStatus := lxs_Failed;
    Exit;
  end;
  B := FBuf[FPos];
  if B = Ord('[') then
    Result := ParseArray(ADepth + 1)
  else if B = Ord('<') then
  begin
    if (FPos + 1 < FLen) and (FBuf[FPos + 1] = Ord('<')) then
      Result := ParseDict(ADepth + 1)
    else
      Result := ParseHex;
  end
  else if B = Ord('(') then
    Result := ParseLiteral
  else if B = Ord('/') then
    Result := ParseName
  else if IsNumberStart(B) then
    Result := ParseNumber
  else if IsRegular(B) then
  begin
    K := ReadKeyword;
    if (K = 'true') or (K = 'false') then
    begin
      Result := NewCv(cvk_Bool);
      Result.IntVal := Ord(K = 'true');
    end
    else if K = 'null' then
      Result := NewCv(cvk_Null)
    else
      FStatus := lxs_Unknown;
  end
  else
    FStatus := lxs_Unknown;
end;

function TContentLexer.ParseArray(ADepth: Integer): TCv;
var
  V: TCv;
begin
  Result := NewCv(cvk_Arr);
  Inc(FPos);
  while FStatus = lxs_Ok do
  begin
    SkipWhite;
    if AtEnd then
    begin
      { the array is not closed: veraPDF throws }
      FStatus := lxs_Failed;
      Exit;
    end;
    if FBuf[FPos] = Ord(']') then
    begin
      Inc(FPos);
      Exit;
    end;
    V := ParseValue(ADepth);
    if FStatus <> lxs_Ok then
      Exit;
    Result.Items.Add(V);
  end;
end;

function TContentLexer.ParseDict(ADepth: Integer): TCv;
var
  K: AnsiString;
  V: TCv;
begin
  Result := NewCv(cvk_Dict);
  Inc(FPos, 2);
  while FStatus = lxs_Ok do
  begin
    SkipWhite;
    if AtEnd then
    begin
      FStatus := lxs_Failed;
      Exit;
    end;
    if (FBuf[FPos] = Ord('>')) and (FPos + 1 < FLen) and (FBuf[FPos + 1] = Ord('>')) then
    begin
      Inc(FPos, 2);
      Exit;
    end;
    if FBuf[FPos] <> Ord('/') then
    begin
      { a key that is no name }
      FStatus := lxs_Unknown;
      Exit;
    end;
    K := ParseName.Text;
    SkipWhite;
    if AtEnd then
    begin
      FStatus := lxs_Failed;
      Exit;
    end;
    if FBuf[FPos] = Ord('>') then
    begin
      { a key without value }
      FStatus := lxs_Unknown;
      Exit;
    end;
    V := ParseValue(ADepth);
    if FStatus <> lxs_Ok then
      Exit;
    Result.Put(K, V);
  end;
end;

{ After EI and white space veraPDF reads one token: an operator it knows (or
  an operand) accepts this EI as the end of the image, an unknown keyword
  rejects it. }
function TContentLexer.Lookahead(APos: Integer): TLookahead;
var
  Q, Start, Code: Integer;
  B: Byte;
  K: AnsiString;
begin
  Result := lka_Unknown;
  Q := APos;
  while (Q < FLen) and IsWhite(FBuf[Q]) do
    Inc(Q);
  if Q - APos > MaxLookahead then
    Exit;
  if Q >= FLen then
  begin
    Result := lka_Accept;
    Exit;
  end;
  B := FBuf[Q];
  Start := Q;
  if IsNumberStart(B) or (B = Ord('/')) then
  begin
    { an operand: it must fit into veraPDF's buffer to be read back }
    Inc(Q);
    while (Q < FLen) and IsRegular(FBuf[Q]) do
      Inc(Q);
    if Q - APos <= MaxLookahead then
      Result := lka_Accept;
    Exit;
  end;
  if not IsRegular(B) or (B = Ord('I')) then
    Exit;
  if IsKeywordStart(B) then
    Q := KeywordEnd(FBuf, FLen, Q)
  else
    Q := OperatorEnd(FBuf, FLen, Q);
  if Q - APos > MaxLookahead then
    Exit;
  K := LandrixEInvoicePdfBytesToAnsi(FBuf, Start, Q - Start);
  { BI: veraPDF reads the whole next image and its own lookahead, and
    loses its read-back position on the way: not decided }
  if K = 'BI' then
    Exit;
  Code := OpCode(K);
  if (Code <> oc_None) or (K = 'true') or (K = 'false') or (K = 'null') then
    Result := lka_Accept
  else
    Result := lka_Reject;
end;

function TContentLexer.ParseInline: TCv;
var
  D, V: TCv;
  K: AnsiString;
  DataStart, I: Integer;
  L: Int64;
  Found: Boolean;
begin
  Result := nil;
  if FPending > 0 then
  begin
    { operands before BI: veraPDF takes the image from another argument }
    FStatus := lxs_Unknown;
    Exit;
  end;
  D := NewCv(cvk_Dict);
  while True do
  begin
    SkipWhite;
    if AtEnd then
    begin
      FStatus := lxs_Failed;
      Exit;
    end;
    if (FBuf[FPos] = Ord('I')) and (FPos + 1 < FLen) and (FBuf[FPos + 1] = Ord('D')) and
      ((FPos + 2 >= FLen) or not IsRegular(FBuf[FPos + 2])) then
    begin
      Inc(FPos, 2);
      Break;
    end;
    if FBuf[FPos] <> Ord('/') then
    begin
      FStatus := lxs_Unknown;
      Exit;
    end;
    K := ParseName.Text;
    SkipWhite;
    if AtEnd then
    begin
      FStatus := lxs_Failed;
      Exit;
    end;
    V := ParseValue(1);
    if FStatus <> lxs_Ok then
      Exit;
    D.Put(K, V);
  end;
  if (FPos < FLen) and IsWhite(FBuf[FPos]) then
    Inc(FPos);
  DataStart := FPos;
  L := -1;
  V := D.Get('L');
  if V = nil then
    V := D.Get('Length');
  if (V <> nil) and (V.Kind = cvk_Int) and (V.IntVal >= 0) then
    L := V.IntVal;
  Found := False;
  I := DataStart;
  while I + 1 < FLen do
  begin
    { veraPDF's counter has read EI too when it compares with /L }
    if (FBuf[I] = Ord('E')) and (FBuf[I + 1] = Ord('I')) and ((L < 0) or (I + 2 - DataStart >= L)) then
    begin
      if I + 2 >= FLen then
      begin
        Found := True;
        Break;
      end;
      if IsWhite(FBuf[I + 2]) then
        case Lookahead(I + 2) of
          lka_Accept:
            begin
              Found := True;
              Break;
            end;
          lka_Unknown:
            begin
              FStatus := lxs_Unknown;
              Exit;
            end;
        else
          { rejected: search on }
        end;
    end;
    Inc(I);
  end;
  if Found then
    FPos := I + 2
  else
    FPos := FLen;
  Result := NewCv(cvk_Op);
  Result.Text := 'BI';
  Result.ImageDict := D;
end;

function TContentLexer.Next: TCv;
var
  B: Byte;
  K: AnsiString;
begin
  Result := nil;
  if (FStatus <> lxs_Ok) or FDone then
    Exit;
  SkipWhite;
  if AtEnd then
  begin
    FDone := True;
    Exit;
  end;
  B := FBuf[FPos];
  if B = Ord('[') then
    Result := ParseArray(1)
  else if B = Ord('<') then
  begin
    if (FPos + 1 < FLen) and (FBuf[FPos + 1] = Ord('<')) then
      Result := ParseDict(1)
    else
      Result := ParseHex;
  end
  else if B = Ord('(') then
    Result := ParseLiteral
  else if B = Ord('/') then
    Result := ParseName
  else if B = Ord(']') then
  begin
    { a stray ] ends the stream quietly }
    FDone := True;
    Exit;
  end
  else if IsNumberStart(B) then
    Result := ParseNumber
  else if B = Ord('I') then
    { veraPDF reads a token starting with I as ID and its image data or
      throws: not decided }
    FStatus := lxs_Unknown
  else
  begin
    K := ReadOperator;
    if not IsKeywordStart(B) and (HasByte(K, '+') or HasByte(K, '-') or HasByte(K, '.')) then
      FStatus := lxs_Unknown
    else if (K = 'true') or (K = 'false') then
    begin
      Result := NewCv(cvk_Bool);
      Result.IntVal := Ord(K = 'true');
    end
    else if K = 'null' then
      Result := NewCv(cvk_Null)
    else if K = 'BI' then
      Result := ParseInline
    else
    begin
      Result := NewCv(cvk_Op);
      Result.Text := K;
    end;
  end;
  if FStatus <> lxs_Ok then
  begin
    Result := nil;
    Exit;
  end;
  if Result.Kind = cvk_Op then
    FPending := 0
  else
    Inc(FPending);
end;

//==============================================================================
// The walk
//==============================================================================

type
  { The lookup of named resources: the stream's own, then the page's. }
  TRes = record
    Local: TLandrixEInvoicePdfObject;
    Page: TLandrixEInvoicePdfObject;
  end;

  { The parts of the graphics state the checks need. }
  TGState = record
    ColorOn: Boolean;
    FillPattern: Boolean;
    StrokePattern: Boolean;
    Font: TLandrixEInvoicePdfObject;
    { the initial colour space was not decided }
    Unsure: Boolean;
    { a pattern space with an underlying space was selected: veraPDF then
      changes the start state of later tiling patterns }
    Under: Boolean;
  end;

  TGStack = array of TGState;

  { One parse of a content stream in one context. }
  TContentParse = class(TObject)
  public
    Key: string;
    Num: Integer;
    Root: Boolean;
    Uncertain: Boolean;
    Level: array[TLandrixEInvoicePdfContentCheck] of Integer;
    KeptSure: array[TLandrixEInvoicePdfContentCheck] of Integer;
    KeptMaybe: array[TLandrixEInvoicePdfContentCheck] of Integer;
    Children: array of Integer;
    Assoc: array of Integer;
    Group: Integer;
    Index: Integer;
    procedure AddChild(AIndex: Integer);
    procedure AddAssoc(ANum: Integer);
  end;

procedure TContentParse.AddChild(AIndex: Integer);
var
  I: Integer;
begin
  if AIndex < 0 then
    Exit;
  for I := 0 to Integer(Length(Children)) - 1 do
    if Children[I] = AIndex then
      Exit;
  SetLength(Children, Length(Children) + 1);
  Children[High(Children)] := AIndex;
end;

procedure TContentParse.AddAssoc(ANum: Integer);
var
  I: Integer;
begin
  for I := 0 to Integer(Length(Assoc)) - 1 do
    if Assoc[I] = ANum then
      Exit;
  SetLength(Assoc, Length(Assoc) + 1);
  Assoc[High(Assoc)] := ANum;
end;

type
  { The interpretation of one parse (operators, state, reaching further
    streams). }
  TInterpreter = class(TObject)
  private
    FWalk: TLandrixEInvoicePdfContentWalk;
    FDoc: TLandrixEInvoicePdfDocument;
    FParse: TContentParse;
    FParseIndex: Integer;
    FRes: TRes;
    FState: TGState;
    { the state the stream started with: veraPDF starts a tiling pattern
      reached from this stream with it }
    FInit: TGState;
    FStack: TGStack;
    FOp: string;
    procedure Mark(ACheck: TLandrixEInvoicePdfContentCheck; AMaybe: Boolean; const AWhat: string);
    procedure ExposeNumber(V: TCv);
    procedure ExposeString(V: TCv);
    procedure ExposeName(V: TCv);
    procedure ExposeCos(V: TCv; AOuter: Boolean);
    procedure CheckSpec(D: TCv);
    procedure NumberList(AOps: TObjectList);
    procedure TopNumbers(AOps: TObjectList);
    function Lookup(const ACategory, AName: AnsiString; out ARaw: TLandrixEInvoicePdfObject):
      TLandrixEInvoicePdfObject;
    function IsPatternSpace(const AName: AnsiString): Boolean;
    procedure SetExtGState(const AName: AnsiString);
    procedure SelectFont(AOps: TObjectList);
    procedure ShowText;
    procedure ReachForm(const AName: AnsiString);
    procedure ReachPattern(const AName: AnsiString; AFill: Boolean);
    procedure RegisterAF(const AName: AnsiString);
    procedure InlineImage(D: TCv);
    procedure Operate(AOp: TCv; AOps: TObjectList);
  public
    procedure Run(ALex: TContentLexer);
  end;

{ The parse of AStreams (one stream, or the parts of a page's /Contents) in
  the context ARes/AState; the index of the parse, -1 if the stream is being
  parsed already (a cycle: veraPDF reads nothing) or a limit was reached. }
function ParseStreams(AWalk: TLandrixEInvoicePdfContentWalk; const AKey: string; ANum: Integer;
  const AStreams: array of TLandrixEInvoicePdfObject; const ARes: TRes; const AState: TGState;
  ARoot: Boolean): Integer;
var
  Ctx, MemoKey: string;
  I, Idx, N, At: Integer;
  P: TContentParse;
  Data: TLandrixEInvoicePdfBytes;
  Parts: array of TLandrixEInvoicePdfBytes;
  Total: Int64;
  Unc: Boolean;
  Lex: TContentLexer;
  Interp: TInterpreter;
begin
  Result := -1;
  if AWalk.FActive.IndexOf(AKey) >= 0 then
    Exit;
  Ctx := AWalk.ObjId(ARes.Local) + '/' + AWalk.ObjId(ARes.Page) + '/' +
    IntToStr(Ord(AState.ColorOn)) + IntToStr(Ord(AState.FillPattern)) + IntToStr(Ord(AState.StrokePattern)) +
    IntToStr(Ord(AState.Unsure)) + IntToStr(Ord(AState.Under)) + '/' +
    AWalk.ObjId(AState.Font);
  MemoKey := AKey + '#' + Ctx;
  Idx := AWalk.FMemo.IndexOf(MemoKey);
  if Idx >= 0 then
  begin
    Result := TContentParse(AWalk.FMemo.Objects[Idx]).Index;
    if ARoot then
      TContentParse(AWalk.FParses[Result]).Root := True;
    Exit;
  end;
  if (Integer(AWalk.FParses.Count) >= MaxParses) or (AWalk.FReachDepth >= MaxReachDepth) then
  begin
    { veraPDF may validate the stream here first, in this context }
    AWalk.FIncomplete := True;
    AWalk.FLimitHit := True;
    Exit;
  end;
  P := TContentParse.Create;
  P.Key := AKey;
  P.Num := ANum;
  P.Root := ARoot;
  P.Uncertain := AState.Unsure;
  Result := Integer(AWalk.FParses.Add(P));
  P.Index := Result;
  AWalk.FMemo.AddObject(MemoKey, P);

  { the data: the parts one after the other, a CR between two; the budget
    is checked before anything is joined }
  Unc := False;
  Parts := nil;
  SetLength(Parts, Length(AStreams));
  Total := 0;
  for I := 0 to Integer(High(AStreams)) do
  begin
    if not AWalk.StreamBytes(AStreams[I], Parts[I]) then
    begin
      Unc := True;
      Break;
    end;
    Inc(Total, Int64(Length(Parts[I])) + 1);
    if AWalk.FTotalBytes + Total > MaxTotalBytes then
    begin
      AWalk.FIncomplete := True;
      Unc := True;
      Break;
    end;
  end;
  if Unc then
  begin
    P.Uncertain := True;
    Exit;
  end;
  Inc(AWalk.FTotalBytes, Total);
  N := 0;
  for I := 0 to Integer(High(Parts)) do
    Inc(N, Length(Parts[I]));
  if Length(Parts) > 1 then
    Inc(N, Length(Parts) - 1);
  Data := nil;
  SetLength(Data, N);
  At := 0;
  for I := 0 to Integer(High(Parts)) do
  begin
    if I > 0 then
    begin
      Data[At] := 13;
      Inc(At);
    end;
    if Length(Parts[I]) > 0 then
    begin
      Move(Parts[I][0], Data[At], Length(Parts[I]));
      Inc(At, Length(Parts[I]));
    end;
    Parts[I] := nil;
  end;

  AWalk.FActive.Add(AKey);
  Inc(AWalk.FReachDepth);
  try
    { first the whole stream: an exception in veraPDF drops every operator
      of it; then the operators one by one }
    Lex := TContentLexer.Create(AWalk, Data);
    try
      while Lex.Next <> nil do
        Lex.Release;
      Lex.Release;
      case Lex.Status of
        lxs_Unknown:
          P.Uncertain := True;
        lxs_Failed:
          Exit;
      end;
    finally
      Lex.Free;
    end;
    if P.Uncertain then
      Exit;
    Lex := TContentLexer.Create(AWalk, Data);
    try
      Interp := TInterpreter.Create;
      try
        Interp.FWalk := AWalk;
        Interp.FDoc := AWalk.FDoc;
        Interp.FParse := P;
        Interp.FParseIndex := Result;
        Interp.FRes := ARes;
        Interp.FState := AState;
        Interp.FState.Unsure := False;
        Interp.FInit := AState;
        Interp.FStack := nil;
        Interp.Run(Lex);
      finally
        Interp.Free;
      end;
    finally
      Lex.Free;
    end;
  finally
    AWalk.FActive.Delete(AWalk.FActive.Count - 1);
    Dec(AWalk.FReachDepth);
  end;
end;

{ An integer as veraPDF's getIntegerKey reads it: a number truncated
  toward zero, a string its byte length; False for anything else. }
function IntegerOf(V: TLandrixEInvoicePdfObject; out AValue: Int64): Boolean;
begin
  Result := False;
  AValue := 0;
  if V = nil then
    Exit;
  if V.Kind = pok_Num then
  begin
    { an integer token as Java's long; else Java's (long) cast, which
      saturates beyond about 9e18 }
    if V.NumExact then
      AValue := V.NumInt
    else if V.NumVal >= 9.0E18 then
      AValue := High(Int64)
    else if V.NumVal <= -9.0E18 then
      AValue := Low(Int64)
    else
      AValue := Trunc(V.NumVal);
    Result := True;
  end
  else if V.Kind = pok_Str then
  begin
    AValue := Length(V.StrVal);
    Result := True;
  end;
end;

{ The low 32 bits as a signed value (Java's Long.intValue). }
function Narrow32(N: Int64): Int64;
begin
  Result := N and $FFFFFFFF;
  if Result > $7FFFFFFF then
    Result := Result - $100000000;
end;

{ A pattern type: 1 tiling, 2 shading, 0 none (read as an int). }
function PatternTypeOf(AWalk: TLandrixEInvoicePdfContentWalk; V: TLandrixEInvoicePdfObject): Integer;
var
  N: Int64;
begin
  Result := 0;
  if (V = nil) or not V.IsDictLike then
    Exit;
  if IntegerOf(AWalk.DGetRef(V, 'PatternType'), N) then
  begin
    N := Narrow32(N);
    if (N = 1) or (N = 2) then
      Result := Integer(N);
  end;
end;

type
  { What veraPDF's colour space factory builds: nothing, another space, a
    pattern space, or not decided (too deep). }
  TCsClass = (csc_None, csc_Other, csc_Pattern, csc_PatternUnder, csc_Unknown);

const
  { nesting of aliases, arrays and defaults followed }
  MaxCsDepth = 32;

function ResolveCsName(AWalk: TLandrixEInvoicePdfContentWalk; const ARes: TRes; const AName: AnsiString;
  AStart, ADepth: Integer): TCsClass; forward;

function CsEntry(AWalk: TLandrixEInvoicePdfContentWalk; R: TLandrixEInvoicePdfObject;
  const AName: AnsiString): TLandrixEInvoicePdfObject;
begin
  Result := AWalk.DGetRef(AWalk.DGetRef(R, 'ColorSpace'), AName);
end;

function ClassifyIn(AWalk: TLandrixEInvoicePdfContentWalk; const ARes: TRes; R, V: TLandrixEInvoicePdfObject;
  AStart, ADepth: Integer; ANoDefault, ANoAlias: Boolean): TCsClass; forward;

{ A device space met as a value in the resources R (AStart: 0 the stream's,
  1 the page's): the /DefaultGray, /DefaultRGB or /DefaultCMYK of R
  replaces it; a default that gives no space gives none. }
function DeviceIn(AWalk: TLandrixEInvoicePdfContentWalk; const ARes: TRes; R: TLandrixEInvoicePdfObject;
  const AFamily: AnsiString; AStart, ADepth: Integer): TCsClass;
var
  D: TLandrixEInvoicePdfObject;
begin
  D := CsEntry(AWalk, R, 'Default' + AFamily);
  if D = nil then
    Result := csc_Other
  else
    Result := ClassifyIn(AWalk, ARes, R, D, AStart, ADepth + 1, True, False);
end;

{ The space veraPDF's factory builds from a value V met in the resources R
  (AStart where R is, -1 none): device names with the default of R (not
  inside a default: ANoDefault), /Pattern, another name as an alias looked
  up in R only (not without resources: ANoAlias), a one-element array as its
  element, arrays by their first name, pattern dictionaries and streams. }
function ClassifyIn(AWalk: TLandrixEInvoicePdfContentWalk; const ARes: TRes; R, V: TLandrixEInvoicePdfObject;
  AStart, ADepth: Integer; ANoDefault, ANoAlias: Boolean): TCsClass;
var
  F: TLandrixEInvoicePdfObject;
  N: AnsiString;
begin
  Result := csc_None;
  if V = nil then
    Exit;
  if ADepth > MaxCsDepth then
  begin
    Result := csc_Unknown;
    Exit;
  end;
  case V.Kind of
    pok_Name:
      begin
        N := V.NameVal;
        if (N = 'DeviceGray') or (N = 'DeviceRGB') or (N = 'DeviceCMYK') then
        begin
          if ANoDefault then
            Result := csc_Other
          else
            Result := DeviceIn(AWalk, ARes, R, Copy(N, 7, MaxInt), AStart, ADepth);
        end
        else if N = 'Pattern' then
          Result := csc_Pattern
        else if not ANoAlias and (AStart >= 0) then
        begin
          { an alias is looked up only in the resources where it was found }
          F := CsEntry(AWalk, R, N);
          if F <> nil then
            Result := ClassifyIn(AWalk, ARes, R, F, AStart, ADepth + 1, False, False);
        end;
      end;
    pok_Arr:
      if V.ArrCount = 1 then
        { one element: the element itself }
        Result := ClassifyIn(AWalk, ARes, R, AWalk.ResolveRef(V.ArrItem(0)), AStart, ADepth + 1, ANoDefault, ANoAlias)
      else if V.ArrCount >= 2 then
      begin
        F := AWalk.ResolveRef(V.ArrItem(0));
        if (F <> nil) and (F.Kind = pok_Name) then
        begin
          N := F.NameVal;
          if N = 'Pattern' then
            Result := csc_PatternUnder
          else if N = 'CalCMYK' then
          begin
            if ANoDefault then
              Result := csc_Other
            else
              Result := DeviceIn(AWalk, ARes, R, 'CMYK', AStart, ADepth);
          end
          else if (N = 'CalGray') or (N = 'CalRGB') or (N = 'Lab') or (N = 'ICCBased') or (N = 'Separation') or
            (N = 'DeviceN') or (N = 'Indexed') then
            Result := csc_Other;
        end;
      end;
    pok_Dict, pok_Stream:
      if PatternTypeOf(AWalk, V) <> 0 then
        Result := csc_Pattern;
  else
    { numbers, strings, booleans: nothing }
  end;
end;

{ The colour space a name selects, as veraPDF's resource handler finds it
  (from AStart on: 0 the stream's resources, 1 the page's). A device name
  first takes the /Default* of the stream's own resources. Then each
  resources in turn (a stream without resources counts as empty ones): an entry of the
  name gives what the factory builds from it (nothing: the next
  resources); no entry gives the built-in space of the name (device spaces
  and /Pattern; nothing for other names: the next resources). }
function ResolveCsName(AWalk: TLandrixEInvoicePdfContentWalk; const ARes: TRes; const AName: AnsiString;
  AStart, ADepth: Integer): TCsClass;
var
  K: Integer;
  R, V, D: TLandrixEInvoicePdfObject;
  Device: Boolean;
begin
  Result := csc_Unknown;
  if ADepth > MaxCsDepth then
    Exit;
  Device := (AName = 'DeviceGray') or (AName = 'DeviceRGB') or (AName = 'DeviceCMYK');
  if Device and (AStart = 0) then
  begin
    { the stream's own resources (a form without resources has none) }
    R := ARes.Local;
    D := CsEntry(AWalk, R, 'Default' + Copy(AName, 7, MaxInt));
    if D <> nil then
    begin
      Result := ClassifyIn(AWalk, ARes, R, D, 0, ADepth + 1, True, False);
      { a default that gives no space leaves the device space }
      if Result = csc_None then
        Result := csc_Other;
      Exit;
    end;
  end;
  for K := AStart to 1 do
  begin
    if K = 0 then
      R := ARes.Local
    else
      R := ARes.Page;
    if (K = 1) and ((R = nil) or ((AStart = 0) and (R = ARes.Local))) then
      Continue;
    V := CsEntry(AWalk, R, AName);
    if V <> nil then
      Result := ClassifyIn(AWalk, ARes, R, V, K, ADepth + 1, False, False)
    else if Device then
      Result := csc_Other
    else if AName = 'Pattern' then
      Result := csc_Pattern
    else
      Result := csc_None;
    if Result <> csc_None then
      Exit;
  end;
  Result := csc_None;
end;

{ A value a pattern resource lookup accepts: veraPDF builds it without
  resources and keeps a pattern space. }
function IsPatternValue(AWalk: TLandrixEInvoicePdfContentWalk; const ARes: TRes; V: TLandrixEInvoicePdfObject): Boolean;
begin
  Result := ClassifyIn(AWalk, ARes, nil, V, -1, 0, True, True) in [csc_Pattern, csc_PatternUnder];
end;

{ A new graphics state: colour on, no font, both colour spaces DeviceGray
  (resolved when the state is made, against the resources of the stream);
  Unsure where that is not decided. }
function FreshState(AWalk: TLandrixEInvoicePdfContentWalk; const ARes: TRes): TGState;
var
  C: TCsClass;
begin
  Result.ColorOn := True;
  C := ResolveCsName(AWalk, ARes, 'DeviceGray', 0, 0);
  Result.FillPattern := C in [csc_Pattern, csc_PatternUnder];
  Result.StrokePattern := Result.FillPattern;
  Result.Under := C = csc_PatternUnder;
  Result.Font := nil;
  Result.Unsure := C = csc_Unknown;
end;

procedure TInterpreter.Mark(ACheck: TLandrixEInvoicePdfContentCheck; AMaybe: Boolean; const AWhat: string);
var
  Lvl, N: Integer;
  W: TLandrixEInvoicePdfContentWalk;
begin
  if AMaybe then
    Lvl := 1
  else
    Lvl := 2;
  if Lvl > FParse.Level[ACheck] then
    FParse.Level[ACheck] := Lvl;
  { certain and uncertain findings are kept separately, so that uncertain
    ones never crowd out a certain one }
  if AMaybe then
  begin
    if FParse.KeptMaybe[ACheck] >= MaxFindingsPerCheck then
      Exit;
    Inc(FParse.KeptMaybe[ACheck]);
  end
  else
  begin
    if FParse.KeptSure[ACheck] >= MaxFindingsPerCheck then
      Exit;
    Inc(FParse.KeptSure[ACheck]);
  end;
  W := FWalk;
  N := W.FFCount;
  if N >= Length(W.FFParse) then
  begin
    SetLength(W.FFParse, 64 + 2 * N);
    SetLength(W.FFCheck, 64 + 2 * N);
    SetLength(W.FFMaybe, 64 + 2 * N);
    SetLength(W.FFDetail, 64 + 2 * N);
  end;
  W.FFParse[N] := FParseIndex;
  W.FFCheck[N] := ACheck;
  W.FFMaybe[N] := AMaybe;
  W.FFDetail[N] := AWhat + ' (operator ' + FOp + ')';
  Inc(W.FFCount);
end;

procedure TInterpreter.ExposeNumber(V: TCv);
var
  A: Double;
begin
  if V.Kind = cvk_Int then
  begin
    if (V.IntVal > 2147483647) or (V.IntVal < -2147483648) then
      Mark(pcc_Integer, False, 'integer ' + IntToStr(V.IntVal) + ' out of range');
    Exit;
  end;
  if V.Kind <> cvk_Real then
    Exit;
  A := Abs(V.RealVal);
  if V.RealNear then
  begin
    if A > 1 then
      Mark(pcc_Real, True, 'real number near the limit')
    else
      Mark(pcc_SmallReal, True, 'real number near the limit');
    Exit;
  end;
  if A > FWalk.FMaxReal then
    Mark(pcc_Real, False, 'real number out of range');
  if (A <> 0) and (A < FWalk.FMinReal) then
    Mark(pcc_SmallReal, False, 'real number too close to zero');
end;

procedure TInterpreter.ExposeString(V: TCv);
begin
  if V.LenLo > 32767 then
    Mark(pcc_StringLength, False, 'string of ' + IntToStr(V.LenLo) + ' characters')
  else if V.LenHi > 32767 then
    Mark(pcc_StringLength, True, 'string of up to ' + IntToStr(V.LenHi) + ' characters');
  if V.Hex then
  begin
    if Odd(V.HexChars) then
      Mark(pcc_HexOdd, False, 'odd number of hexadecimal characters');
    if V.HexInvalid then
      Mark(pcc_HexDigits, False, 'character that is no hexadecimal digit');
  end;
end;

procedure TInterpreter.ExposeName(V: TCv);
begin
  if Length(V.Text) > 127 then
    Mark(pcc_NameLength, False, 'name of ' + IntToStr(Length(V.Text)) + ' bytes');
end;

{ A value passed on as a whole: numbers, strings, names, the items of an
  array, the keys and values of a dictionary; a dictionary inside it with
  /Type /Filespec is a file specification (not the outer one itself). }
procedure TInterpreter.ExposeCos(V: TCv; AOuter: Boolean);
var
  I: Integer;
  T: TCv;
begin
  if V = nil then
    Exit;
  case V.Kind of
    cvk_Int, cvk_Real:
      ExposeNumber(V);
    cvk_Str:
      ExposeString(V);
    cvk_Name:
      ExposeName(V);
    cvk_Arr:
      for I := 0 to Integer(V.Items.Count) - 1 do
        ExposeCos(TCv(V.Items[I]), False);
    cvk_Dict:
      begin
        for I := 0 to Integer(Length(V.Keys)) - 1 do
          if Length(V.Keys[I]) > 127 then
            Mark(pcc_NameLength, False, 'name of ' + IntToStr(Length(V.Keys[I])) + ' bytes');
        for I := 0 to Integer(V.Items.Count) - 1 do
          ExposeCos(TCv(V.Items[I]), False);
        if not AOuter then
        begin
          T := V.Get('Type');
          if (T <> nil) and (T.Kind = cvk_Name) and (T.Text = 'Filespec') then
            CheckSpec(V);
        end;
      end;
  else
    { booleans and null }
  end;
end;

{ 6.8-2 to 6.8-4 on a file specification inside content: a direct object,
  so it is never associated. }
procedure TInterpreter.CheckSpec(D: TCv);
var
  EF, F, UF, R: TCv;
begin
  EF := D.Get('EF');
  if (EF <> nil) and (EF.Kind <> cvk_Null) then
  begin
    F := D.Get('F');
    UF := D.Get('UF');
    if not ((F <> nil) and (F.Kind = cvk_Str) and (UF <> nil) and (UF.Kind = cvk_Str)) then
      Mark(pcc_SpecNames, False, 'file specification with /EF without /F and /UF');
  end;
  R := D.Get('AFRelationship');
  if (R = nil) or (R.Kind <> cvk_Name) then
    Mark(pcc_SpecRelationship, False, 'file specification without /AFRelationship');
  Mark(pcc_SpecDirect, False, 'direct file specification, not associated');
end;

{ cm m l c v y re Tm d1: every number, and the items of an array (an item
  that is no number gives veraPDF a link it cannot validate). }
procedure TInterpreter.NumberList(AOps: TObjectList);
var
  I, K: Integer;
  V, Item: TCv;
begin
  for I := 0 to Integer(AOps.Count) - 1 do
  begin
    V := TCv(AOps[I]);
    if (V.Kind = cvk_Int) or (V.Kind = cvk_Real) then
      ExposeNumber(V)
    else if V.Kind = cvk_Arr then
      for K := 0 to Integer(V.Items.Count) - 1 do
      begin
        Item := TCv(V.Items[K]);
        if (Item.Kind = cvk_Int) or (Item.Kind = cvk_Real) then
          ExposeNumber(Item)
        else
          FParse.Uncertain := True;
      end;
  end;
end;

{ colour operators: every number at the top level }
procedure TInterpreter.TopNumbers(AOps: TObjectList);
var
  I: Integer;
  V: TCv;
begin
  for I := 0 to Integer(AOps.Count) - 1 do
  begin
    V := TCv(AOps[I]);
    if (V.Kind = cvk_Int) or (V.Kind = cvk_Real) then
      ExposeNumber(V);
  end;
end;

{ A named resource: in the stream's own resources, then in the page's; an
  entry that does not give an object of the kinds asked for (or a reference
  to no object in use) makes veraPDF look in the page's resources. }
{ A font veraPDF's font factory builds: a dictionary with one of five
  subtypes. }
function IsFontObject(AWalk: TLandrixEInvoicePdfContentWalk; V: TLandrixEInvoicePdfObject): Boolean;
var
  Sub: TLandrixEInvoicePdfObject;
begin
  Result := False;
  if (V = nil) or (V.Kind <> pok_Dict) then
    Exit;
  Sub := AWalk.DGetRef(V, 'Subtype');
  Result := (Sub <> nil) and (Sub.Kind = pok_Name) and ((Sub.NameVal = 'Type1') or (Sub.NameVal = 'MMType1') or
    (Sub.NameVal = 'TrueType') or (Sub.NameVal = 'Type3') or (Sub.NameVal = 'Type0'));
end;

{ Whether veraPDF's lookup of a resource of ACategory gives an object for
  the entry ARaw (resolved V); if not, it looks in the page's resources.
  ExtGState, Shading and Properties: any entry. XObject: /Subtype Image,
  Form or PS. Font: see IsFontObject. Pattern: a pattern dictionary or
  stream or a pattern colour space. ColorSpace: a space its colour space
  factory builds. }
function ResourceAccepted(AWalk: TLandrixEInvoicePdfContentWalk; const ARes: TRes; const ACategory: AnsiString;
  ARaw, V: TLandrixEInvoicePdfObject): Boolean;
var
  Sub: TLandrixEInvoicePdfObject;
begin
  Result := False;
  if (ARaw = nil) or (ARaw.Kind = pok_Null) then
    Exit;
  if (ACategory = 'ExtGState') or (ACategory = 'Shading') or (ACategory = 'Properties') then
    Result := True
  else if V = nil then
    Result := False
  else if ACategory = 'XObject' then
  begin
    Sub := AWalk.DGetRef(V, 'Subtype');
    Result := (Sub <> nil) and (Sub.Kind = pok_Name) and ((Sub.NameVal = 'Image') or (Sub.NameVal = 'Form') or
      (Sub.NameVal = 'PS'));
  end
  else if ACategory = 'Font' then
    Result := IsFontObject(AWalk, V)
  else if ACategory = 'Pattern' then
    Result := IsPatternValue(AWalk, ARes, V)
  else if ACategory = 'ColorSpace' then
    Result := ClassifyIn(AWalk, ARes, nil, V, -1, 0, False, False) <> csc_None;
end;

{ A named resource: in the stream's own resources, then in the page's when
  veraPDF's lookup there gives nothing (ResourceAccepted); the entry ARaw
  and its object (nil for a reference to no object in use). }
function TInterpreter.Lookup(const ACategory, AName: AnsiString; out ARaw: TLandrixEInvoicePdfObject):
  TLandrixEInvoicePdfObject;
var
  K: Integer;
  R, C: TLandrixEInvoicePdfObject;
begin
  Result := nil;
  ARaw := nil;
  for K := 0 to 1 do
  begin
    if K = 0 then
      R := FRes.Local
    else
      R := FRes.Page;
    if (R = nil) or not R.IsDictLike then
      Continue;
    C := FWalk.DGetRef(R, ACategory);
    if (C = nil) or not C.IsDictLike then
      Continue;
    ARaw := C.RawGet(AName);
    Result := FWalk.ResolveRef(ARaw);
    { a pattern value nested beyond the depth limit: not decided }
    if (ACategory = 'Pattern') and (Result <> nil) and
      (ClassifyIn(FWalk, FRes, nil, Result, -1, 0, True, True) = csc_Unknown) then
      FParse.Uncertain := True;
    if ResourceAccepted(FWalk, FRes, ACategory, ARaw, Result) then
      Exit;
    Result := nil;
    ARaw := nil;
  end;
end;

{ The colour space a name selects is a pattern space: /Pattern itself, a
  device space replaced by its default space, or a named space of the
  resources. }
function TInterpreter.IsPatternSpace(const AName: AnsiString): Boolean;
begin
  case ResolveCsName(FWalk, FRes, AName, 0, 0) of
    csc_Pattern:
      Result := True;
    csc_PatternUnder:
      begin
        FState.Under := True;
        Result := True;
      end;
    csc_Unknown:
      begin
        FParse.Uncertain := True;
        Result := False;
      end;
  else
    Result := False;
  end;
end;

{ gs: an ExtGState with /Font [font size] selects that font where the font
  factory builds it; otherwise the font stays. }
procedure TInterpreter.SetExtGState(const AName: AnsiString);
var
  G, F, Font, Raw: TLandrixEInvoicePdfObject;
begin
  G := Lookup('ExtGState', AName, Raw);
  if (G = nil) or not G.IsDictLike then
    Exit;
  F := FWalk.DGetRef(G, 'Font');
  if (F = nil) or (F.Kind <> pok_Arr) or (F.ArrCount = 0) then
    Exit;
  Font := FWalk.ResolveRef(F.ArrItem(0));
  if IsFontObject(FWalk, Font) then
    FState.Font := Font;
end;

{ Tf: the font of the name (none if there is no font to build). }
procedure TInterpreter.SelectFont(AOps: TObjectList);
var
  V: TCv;
  Raw: TLandrixEInvoicePdfObject;
begin
  FState.Font := nil;
  if AOps.Count = 0 then
    Exit;
  V := TCv(AOps[0]);
  if V.Kind <> cvk_Name then
    Exit;
  FState.Font := Lookup('Font', V.Text, Raw);
end;

procedure TInterpreter.ShowText;
var
  F, Sub, CP, S, Raw, FontRes, Local: TLandrixEInvoicePdfObject;
  I, Num: Integer;
  Entry: TContentParse;
  Key: string;
  Res: TRes;
begin
  F := FState.Font;
  if F = nil then
    Exit;
  Sub := FWalk.DGetRef(F, 'Subtype');
  if (Sub = nil) or (Sub.Kind <> pok_Name) or (Sub.NameVal <> 'Type3') then
    Exit;
  Key := FWalk.ObjId(F) + '/' + FWalk.ObjId(FRes.Page) + '/' + IntToStr(Ord(FState.ColorOn)) +
    IntToStr(Ord(FState.FillPattern)) + IntToStr(Ord(FState.StrokePattern)) + IntToStr(Ord(FState.Unsure)) +
    IntToStr(Ord(FState.Under));
  Num := FWalk.FType3Seen.IndexOf(Key);
  if Num >= 0 then
  begin
    { reached before from this page: the same glyph parses }
    for I := 0 to Integer(Length(TContentParse(FWalk.FType3Seen.Objects[Num]).Children)) - 1 do
      FParse.AddChild(TContentParse(FWalk.FType3Seen.Objects[Num]).Children[I]);
    Exit;
  end;
  { the entry itself: glyphs may add entries before it in the sorted list }
  Entry := TContentParse.Create;
  FWalk.FType3Seen.AddObject(Key, Entry);
  CP := FWalk.DGetRef(F, 'CharProcs');
  if (CP = nil) or not CP.IsDictLike then
    Exit;
  FontRes := FWalk.DGetRef(F, 'Resources');
  if (FontRes <> nil) and not FontRes.IsDictLike then
    FontRes := nil;
  for I := 0 to Integer(CP.DVals.Count) - 1 do
  begin
    Raw := TLandrixEInvoicePdfObject(CP.DVals[I]);
    S := FWalk.ResolveRef(Raw);
    if (S = nil) or (S.Kind <> pok_Stream) or (Raw.Kind <> pok_Ref) then
      Continue;
    Local := FWalk.DGetRef(S, 'Resources');
    if (Local = nil) or not Local.IsDictLike then
      Local := FontRes;
    Res.Local := Local;
    Res.Page := FRes.Page;
    Entry.AddChild(
      ParseStreams(FWalk, 'S' + IntToStr(Raw.RefNum), Raw.RefNum, [S], Res, FState, False));
  end;
  for I := 0 to Integer(Length(Entry.Children)) - 1 do
    FParse.AddChild(Entry.Children[I]);
end;

{ Do with a form XObject: its content with its own resources (none if
  missing) and the page's; the graphics state passes on, the q stack does
  not. }
procedure TInterpreter.ReachForm(const AName: AnsiString);
var
  Raw, X, Sub, Local: TLandrixEInvoicePdfObject;
  Res: TRes;
begin
  X := Lookup('XObject', AName, Raw);
  if (X = nil) or (X.Kind <> pok_Stream) or (Raw = nil) or (Raw.Kind <> pok_Ref) then
    Exit;
  Sub := FWalk.DGetRef(X, 'Subtype');
  if (Sub = nil) or (Sub.Kind <> pok_Name) or (Sub.NameVal <> 'Form') then
    Exit;
  Local := FWalk.DGetRef(X, 'Resources');
  if (Local <> nil) and not Local.IsDictLike then
    Local := nil;
  Res.Local := Local;
  Res.Page := FRes.Page;
  FParse.AddChild(ParseStreams(FWalk, 'S' + IntToStr(Raw.RefNum), Raw.RefNum, [X], Res, FState, False));
end;

{ scn or SCN with a pattern colour space: a tiling pattern's content with
  its own resources and the page's, starting with the state the calling
  stream started with; an uncoloured one with colour operators off. A name that selects no pattern leaves no pattern space
  active (AFill: the fill space, else the stroke space). }
procedure TInterpreter.ReachPattern(const AName: AnsiString; AFill: Boolean);
var
  Raw, P, Local: TLandrixEInvoicePdfObject;
  Res: TRes;
  St: TGState;
  PaintType: Int64;
  K: Integer;
  Uncoloured: Boolean;
begin
  P := Lookup('Pattern', AName, Raw);
  K := 0;
  while (P <> nil) and (P.Kind = pok_Arr) and (P.ArrCount = 1) do
  begin
    Inc(K);
    if K > MaxCsDepth then
    begin
      FParse.Uncertain := True;
      Exit;
    end;
    Raw := P.ArrItem(0);
    P := FWalk.ResolveRef(Raw);
  end;
  if P = nil then
  begin
    if AFill then
      FState.FillPattern := False
    else
      FState.StrokePattern := False;
    Exit;
  end;
  { a pattern space with an underlying space as the pattern: veraPDF keeps
    the underlying space for the next tiling pattern }
  if (P.Kind = pok_Arr) and (ClassifyIn(FWalk, FRes, nil, P, -1, 0, True, True) = csc_PatternUnder) then
  begin
    FState.Under := True;
    Exit;
  end;
  if not P.IsDictLike or (PatternTypeOf(FWalk, P) <> 1) then
    Exit;
  { veraPDF builds every tiling pattern of a stream (also one without a
    stream) on the stream's shared start state, after the stream's last
    operator: an underlying space changes it, an uncoloured pattern turns
    colour off for all of them. Not followed: not decided. }
  if FState.Under or FInit.Under then
    FParse.Uncertain := True;
  Uncoloured := IntegerOf(FWalk.DGetRef(P, 'PaintType'), PaintType) and (PaintType = 2);
  if Uncoloured and FInit.ColorOn then
    FParse.Uncertain := True;
  if (P.Kind <> pok_Stream) or (Raw = nil) or (Raw.Kind <> pok_Ref) then
    Exit;
  Local := FWalk.DGetRef(P, 'Resources');
  if (Local <> nil) and not Local.IsDictLike then
    Local := nil;
  Res.Local := Local;
  Res.Page := FRes.Page;
  St := FInit;
  if Uncoloured then
    St.ColorOn := False;
  FParse.AddChild(ParseStreams(FWalk, 'S' + IntToStr(Raw.RefNum), Raw.RefNum, [P], Res, St, False));
end;

procedure TInterpreter.RegisterAF(const AName: AnsiString);
var
  A, Item, Raw: TLandrixEInvoicePdfObject;
  I: Integer;
begin
  A := Lookup('Properties', AName, Raw);
  if (A = nil) or (A.Kind <> pok_Arr) then
    Exit;
  for I := 0 to A.ArrCount - 1 do
  begin
    Item := A.ArrItem(I);
    { the key of the object in use: number and generation }
    if (Item <> nil) and (Item.Kind = pok_Ref) and (FWalk.ResolveRef(Item) <> nil) then
      FParse.AddAssoc(FWalk.LastRefNum(Item));
  end;
end;

procedure TInterpreter.InlineImage(D: TCv);
var
  F, IM, Item: TCv;
  I: Integer;
  AllNames: Boolean;
begin
  IM := D.Get('IM');
  if not FState.ColorOn and not ((IM <> nil) and (IM.Kind = cvk_Bool) and (IM.IntVal = 1)) then
    Exit;
  ExposeCos(D, True);
  F := D.Get('F');
  if F = nil then
    F := D.Get('Filter');
  if F = nil then
    Exit;
  if F.Kind = cvk_Name then
  begin
    if not InList(F.Text, InlineFilters) then
      Mark(pcc_InlineFilter, False, 'inline image filter /' + TextOf(F.Text));
  end
  else if F.Kind = cvk_Arr then
  begin
    AllNames := True;
    for I := 0 to Integer(F.Items.Count) - 1 do
      if TCv(F.Items[I]).Kind <> cvk_Name then
        AllNames := False;
    if AllNames then
      for I := 0 to Integer(F.Items.Count) - 1 do
      begin
        Item := TCv(F.Items[I]);
        if not InList(Item.Text, InlineFilters) then
          Mark(pcc_InlineFilter, False, 'inline image filter /' + TextOf(Item.Text));
      end;
  end;
end;

function IsNum(V: TCv): Boolean;
begin
  Result := (V <> nil) and ((V.Kind = cvk_Int) or (V.Kind = cvk_Real));
end;

function IsKind(V: TCv; AKind: TCvKind): Boolean;
begin
  Result := (V <> nil) and (V.Kind = AKind);
end;

{ The operands an operator passes on to the checks, as veraPDF's operator
  model does: positions count from the end (-1 the last operand), and a
  position with the wrong type passes nothing. }
procedure TInterpreter.Operate(AOp: TCv; AOps: TObjectList);
var
  L1, L2, L3: TCv;
  N: Integer;
  Pat: Boolean;
begin
  FOp := TextOf(AOp.Text);
  N := Integer(AOps.Count);
  L1 := nil;
  L2 := nil;
  L3 := nil;
  if N >= 1 then
    L1 := TCv(AOps[N - 1]);
  if N >= 2 then
    L2 := TCv(AOps[N - 2]);
  if N >= 3 then
    L3 := TCv(AOps[N - 3]);
  case OpCode(AOp.Text) of
    oc_Number:
      if IsNum(L1) then
        ExposeNumber(L1);
    oc_Integer:
      if IsKind(L1, cvk_Int) then
        ExposeNumber(L1);
    oc_Dash:
      begin
        if IsKind(L2, cvk_Arr) then
          ExposeCos(L2, False);
        if IsNum(L1) then
          ExposeNumber(L1);
      end;
    oc_Intent:
      if FState.ColorOn and IsKind(L1, cvk_Name) then
        ExposeName(L1);
    oc_Push:
      begin
        SetLength(FStack, Length(FStack) + 1);
        FStack[High(FStack)] := FState;
        if Length(FStack) > MaxNesting then
          Mark(pcc_Nesting, False, 'q nested ' + IntToStr(Length(FStack)) + ' levels deep');
      end;
    oc_Pop:
      if Length(FStack) > 0 then
      begin
        FState := FStack[High(FStack)];
        SetLength(FStack, Length(FStack) - 1);
      end;
    oc_NumberList:
      NumberList(AOps);
    oc_Glyph:
      begin
        NumberList(AOps);
        FState.ColorOn := False;
      end;
    oc_TwoNumbers:
      begin
        if IsNum(L2) then
          ExposeNumber(L2);
        if IsNum(L1) then
          ExposeNumber(L1);
      end;
    oc_Font:
      begin
        if IsKind(L2, cvk_Name) then
          ExposeName(L2);
        if IsNum(L1) then
          ExposeNumber(L1);
        SelectFont(AOps);
      end;
    oc_Show:
      begin
        if IsKind(L1, cvk_Str) then
          ExposeString(L1);
        ShowText;
      end;
    oc_ShowSpaced:
      begin
        if IsKind(L1, cvk_Str) then
          ExposeString(L1);
        if N >= 3 then
        begin
          if IsNum(L3) then
            ExposeNumber(L3);
          if IsNum(L2) then
            ExposeNumber(L2);
        end;
        ShowText;
      end;
    oc_ShowArray:
      begin
        if IsKind(L1, cvk_Arr) then
          ExposeCos(L1, False);
        ShowText;
      end;
    oc_Color:
      if FState.ColorOn then
        TopNumbers(AOps);
    oc_SpaceStroke, oc_SpaceFill:
      if FState.ColorOn then
      begin
        TopNumbers(AOps);
        if IsKind(L1, cvk_Name) then
        begin
          ExposeName(L1);
          if OpCode(AOp.Text) = oc_SpaceStroke then
            FState.StrokePattern := IsPatternSpace(L1.Text)
          else
            FState.FillPattern := IsPatternSpace(L1.Text);
        end
        else if OpCode(AOp.Text) = oc_SpaceStroke then
          FState.StrokePattern := False
        else
          FState.FillPattern := False;
      end;
    oc_ColorNStroke, oc_ColorNFill:
      if FState.ColorOn then
      begin
        TopNumbers(AOps);
        if IsKind(L1, cvk_Name) then
        begin
          ExposeName(L1);
          if (OpCode(AOp.Text) = oc_ColorNStroke) and FState.StrokePattern then
            ReachPattern(L1.Text, False)
          else if (OpCode(AOp.Text) = oc_ColorNFill) and FState.FillPattern then
            ReachPattern(L1.Text, True);
        end
        { without a pattern name veraPDF leaves the pattern space }
        else if OpCode(AOp.Text) = oc_ColorNStroke then
          FState.StrokePattern := False
        else
          FState.FillPattern := False;
      end;
    oc_DeviceStroke, oc_DeviceFill:
      if FState.ColorOn then
      begin
        TopNumbers(AOps);
        if IsKind(L1, cvk_Name) then
          ExposeName(L1);
        { the device space, or the default space of the resources }
        if (AOp.Text = 'G') or (AOp.Text = 'g') then
          Pat := IsPatternSpace('DeviceGray')
        else if (AOp.Text = 'RG') or (AOp.Text = 'rg') then
          Pat := IsPatternSpace('DeviceRGB')
        else
          Pat := IsPatternSpace('DeviceCMYK');
        if OpCode(AOp.Text) = oc_DeviceStroke then
          FState.StrokePattern := Pat
        else
          FState.FillPattern := Pat;
      end;
    oc_ExtGState:
      if IsKind(L1, cvk_Name) then
        SetExtGState(L1.Text);
    oc_Do:
      if IsKind(L1, cvk_Name) then
        ReachForm(L1.Text);
    oc_Tag:
      if IsKind(L1, cvk_Name) then
        ExposeName(L1);
    oc_TagProps, oc_TagPropsBegin:
      begin
        if IsKind(L2, cvk_Name) then
          ExposeName(L2);
        if IsKind(L1, cvk_Dict) then
          ExposeCos(L1, True);
        if (OpCode(AOp.Text) = oc_TagPropsBegin) and IsKind(L2, cvk_Name) and (L2.Text = 'AF') and
          IsKind(L1, cvk_Name) then
          RegisterAF(L1.Text);
      end;
    oc_Inline:
      if AOp.ImageDict <> nil then
        InlineImage(AOp.ImageDict);
  else
    { sh, gs, Tr, painting, text objects, marked content end, BX/EX and
      unknown operators pass nothing on }
  end;
end;

procedure TInterpreter.Run(ALex: TContentLexer);
var
  T: TCv;
  Ops: TObjectList;
begin
  Ops := TObjectList.Create(False);
  try
    while True do
    begin
      T := ALex.Next;
      if T = nil then
        Break;
      if T.Kind <> cvk_Op then
      begin
        Ops.Add(T);
        if Ops.Count > MaxPending then
        begin
          FParse.Uncertain := True;
          Break;
        end;
        Continue;
      end;
      Operate(T, Ops);
      Ops.Clear;
      ALex.Release;
    end;
    { the operands kept for an operator may reach a limit the first pass
      did not }
    if ALex.Status <> lxs_Ok then
      FParse.Uncertain := True;
  finally
    Ops.Free;
  end;
end;

//==============================================================================
// TLandrixEInvoicePdfContentWalk
//==============================================================================

constructor TLandrixEInvoicePdfContentWalk.Create(ADoc: TLandrixEInvoicePdfDocument);
begin
  inherited Create;
  FDoc := ADoc;
  FParses := TObjectList.Create(True);
  FMemo := TStringList.Create;
  FMemo.Sorted := True;
  FMemo.Duplicates := dupIgnore;
  FActive := TStringList.Create;
  FType3Seen := TStringList.Create;
  FType3Seen.Sorted := True;
  FType3Seen.Duplicates := dupIgnore;
  { built at run time: literals of this size lose precision as Extended }
  FMaxReal := FloatOf('3.403e38');
  FMinReal := FloatOf('1.175e-38');
  FMaxDouble := FloatOf('1.7976931348623157e308');
  FTiny := FloatOf('1e-300');
  { a decimal this close to a limit may round to either side of it }
  FNearHigh := FloatOf('3.4029e38');
  FNearHighTop := FloatOf('3.4031e38');
  FNearLow := FloatOf('1.1749e-38');
  FNearLowTop := FloatOf('1.1751e-38');
end;

destructor TLandrixEInvoicePdfContentWalk.Destroy;
var
  I: Integer;
begin
  for I := 0 to FType3Seen.Count - 1 do
    FType3Seen.Objects[I].Free;
  FType3Seen.Free;
  FActive.Free;
  FMemo.Free;
  FParses.Free;
  inherited Destroy;
end;

{ A reference to the object in use with that number and generation; nil if
  there is none (veraPDF reads null); a direct object as it is. }
function TLandrixEInvoicePdfContentWalk.ResolveRef(ARaw: TLandrixEInvoicePdfObject): TLandrixEInvoicePdfObject;
var
  E: TLandrixEInvoicePdfXrefEntry;
  Depth, Num, Gen: Integer;
begin
  Result := ARaw;
  Depth := 0;
  while (Result <> nil) and (Result.Kind = pok_Ref) do
  begin
    Inc(Depth);
    E := FDoc.XrefEntry(Result.RefNum);
    if Depth > 32 then
    begin
      { veraPDF may follow it further }
      FIncomplete := True;
      FLimitHit := True;
      Result := nil;
      Exit;
    end;
    if not E.Known or (E.Kind = pxk_Free) or (E.Gen <> Result.RefGen) then
    begin
      Result := nil;
      Exit;
    end;
    Gen := Result.RefGen;
    Num := Result.RefNum;
    Result := FDoc.GetObject(Num);
    { the object header must carry the generation too }
    if (Result <> nil) and (Result.OwnerNum = Num) and ((Result.OwnerGen <> Gen) or Result.HeaderGenBad) then
    begin
      Result := nil;
      Exit;
    end;
  end;
end;

{ The number of the object at the end of a reference chain (an object that
  holds a reference stands for the object it names). }
function TLandrixEInvoicePdfContentWalk.LastRefNum(ARaw: TLandrixEInvoicePdfObject): Integer;
var
  O: TLandrixEInvoicePdfObject;
  Depth: Integer;
begin
  Result := -1;
  O := ARaw;
  Depth := 0;
  while (O <> nil) and (O.Kind = pok_Ref) and (Depth <= 32) do
  begin
    Result := O.RefNum;
    O := FDoc.GetObject(O.RefNum);
    Inc(Depth);
  end;
end;

{ The entry AKey of a dictionary or stream, resolved as ResolveRef does. }
function TLandrixEInvoicePdfContentWalk.DGetRef(AObj: TLandrixEInvoicePdfObject;
  const AKey: AnsiString): TLandrixEInvoicePdfObject;
begin
  Result := nil;
  if (AObj = nil) or not AObj.IsDictLike then
    Exit;
  Result := ResolveRef(AObj.RawGet(AKey));
end;

{ A key of a parsed object for the memo: its serial number. }
function TLandrixEInvoicePdfContentWalk.ObjId(AObj: TLandrixEInvoicePdfObject): string;
begin
  if AObj = nil then
    Result := '-'
  else
    Result := IntToStr(AObj.Serial);
end;

{ The data veraPDF reads from a stream: none for an unknown filter or
  DCTDecode; False (not decided) for an encrypted document, a /Length that
  does not hold, decode parameters, other filters and Flate data that is not
  a clean zlib stream. }
function TLandrixEInvoicePdfContentWalk.StreamBytes(AStream: TLandrixEInvoicePdfObject;
  out AData: TLandrixEInvoicePdfBytes): Boolean;
var
  Raw, Cur, Next: TLandrixEInvoicePdfBytes;
  F, Item, L, Parms: TLandrixEInvoicePdfObject;
  Names: array of AnsiString;
  I: Integer;
begin
  Result := False;
  AData := nil;
  Cur := nil;
  Next := nil;
  if FDoc.Encrypted then
    Exit;
  if not FDoc.GetStreamRaw(AStream, Raw) then
    Exit;
  L := DGetRef(AStream, 'Length');
  if (L = nil) or (L.Kind <> pok_Num) or (L.AsInt <> Length(Raw)) then
    Exit;
  F := DGetRef(AStream, 'Filter');
  if (F = nil) or (F.Kind = pok_Null) then
  begin
    AData := Raw;
    Result := True;
    Exit;
  end;
  Names := nil;
  if F.Kind = pok_Name then
  begin
    SetLength(Names, 1);
    Names[0] := F.NameVal;
  end
  else if F.Kind = pok_Arr then
  begin
    SetLength(Names, F.ArrCount);
    for I := 0 to F.ArrCount - 1 do
    begin
      Item := ResolveRef(F.ArrItem(I));
      if (Item = nil) or (Item.Kind <> pok_Name) then
        Exit;
      Names[I] := Item.NameVal;
    end;
  end
  else
    Exit;
  for I := 0 to Integer(Length(Names)) - 1 do
    if (Names[I] = 'DCTDecode') or (Names[I] = 'DCT') or not InList(Names[I], KnownFilters) then
    begin
      { veraPDF has no decoder here: the stream reads as empty }
      Result := True;
      Exit;
    end;
  for I := 0 to Integer(Length(Names)) - 1 do
    if Names[I] <> 'FlateDecode' then
      Exit;
  Parms := DGetRef(AStream, 'DecodeParms');
  if (Parms <> nil) and (Parms.Kind <> pok_Null) then
    Exit;
  Cur := Raw;
  for I := 0 to Integer(Length(Names)) - 1 do
  begin
    if not LandrixEInvoicePdfInflateStrict(Cur, Next) then
      Exit;
    Cur := Next;
  end;
  AData := Cur;
  Result := True;
end;

procedure TLandrixEInvoicePdfContentWalk.Run;
var
  Pages: TLandrixEInvoicePdfObject;
begin
  if FDoc.Catalog = nil then
    FIncomplete := True
  else
  begin
    { the catalog as veraPDF reaches it, generations checked }
    if (FDoc.RootRef = nil) or (FDoc.RootRef.Kind <> pok_Ref) or (ResolveRef(FDoc.RootRef) <> FDoc.Catalog) then
    begin
      FIncomplete := True;
      FPagesUnsure := True;
    end;
    Pages := DGetRef(FDoc.Catalog, 'Pages');
    WalkPages(Pages, nil, 0);
  end;
  ScanTiling;
  Finish;
end;

{ veraPDF also reads a tiling pattern that stands where a colour space is
  expected (a /ColorSpace entry or default, an Indexed base, a Separation or
  DeviceN alternate, the colour space of a shading, of a group or of an
  inline image). The walk reaches tiling patterns through scn only, so one
  referenced from anywhere but a /Pattern resource leaves the content rules
  incomplete. }
procedure TLandrixEInvoicePdfContentWalk.ScanTiling;
const
  MaxScanNodes = 2000000;
  MaxScanDepth = 200;
var
  N, Count, Nodes: Integer;
  Tiling, PatDict: array of Boolean;
  O: TLandrixEInvoicePdfObject;
  Found, Bad, Collect: Boolean;
  X: TLandrixEInvoicePdfXrefEntry;
  Pass: Integer;

  { AAllowed: V stands where a tiling pattern may; APatterns: V is a
    /Pattern resource dictionary (its values may be tiling patterns) }
  procedure Visit(V: TLandrixEInvoicePdfObject; AAllowed, APatterns: Boolean; ADepth: Integer);
  var
    I, M, Hops: Integer;
    K, T: TLandrixEInvoicePdfObject;
  begin
    if (V = nil) or Bad then
      Exit;
    Inc(Nodes);
    if (Nodes > MaxScanNodes) or (ADepth > MaxScanDepth) then
    begin
      Bad := True;
      Exit;
    end;
    case V.Kind of
      pok_Ref:
        if not Collect and not AAllowed then
        begin
          { the object at the end of a reference chain }
          M := V.RefNum;
          T := FDoc.GetObject(M);
          Hops := 0;
          while (T <> nil) and (T.Kind = pok_Ref) and (Hops < 32) do
          begin
            M := T.RefNum;
            T := FDoc.GetObject(M);
            Inc(Hops);
          end;
          if (M >= 0) and (M < Count) and Tiling[M] then
            Bad := True;
        end;
      pok_Arr:
        if V.ArrCount = 1 then
          Visit(V.ArrItem(0), AAllowed, False, ADepth + 1)
        else
          for I := 0 to V.ArrCount - 1 do
            Visit(V.ArrItem(I), False, False, ADepth + 1);
      pok_Dict, pok_Stream:
        for I := 0 to Integer(V.DVals.Count) - 1 do
        begin
          K := TLandrixEInvoicePdfObject(V.DVals[I]);
          if not APatterns and (V.DKeys[I] = 'Pattern') and (K <> nil) and (K.Kind = pok_Ref) then
          begin
            if Collect and (K.RefNum >= 0) and (K.RefNum < Count) then
              PatDict[K.RefNum] := True;
          end
          else if APatterns then
            Visit(K, True, False, ADepth + 1)
          else
            Visit(K, False, (V.DKeys[I] = 'Pattern') and (K <> nil) and (K.Kind = pok_Dict), ADepth + 1);
        end;
    else
      { numbers, strings, names: nothing }
    end;
  end;

begin
  Count := FDoc.XrefCount;
  Tiling := nil;
  PatDict := nil;
  SetLength(Tiling, Count);
  SetLength(PatDict, Count);
  Found := False;
  for N := 0 to Count - 1 do
  begin
    Tiling[N] := False;
    PatDict[N] := False;
    X := FDoc.XrefEntry(N);
    if not X.Known or (X.Kind = pxk_Free) then
      Continue;
    O := FDoc.GetObject(N);
    if (O <> nil) and (O.Kind = pok_Stream) and (PatternTypeOf(Self, O) = 1) then
    begin
      Tiling[N] := True;
      Found := True;
    end;
  end;
  if not Found then
    Exit;
  Bad := False;
  { first the indirect /Pattern dictionaries, then every reference }
  for Pass := 0 to 1 do
  begin
    Collect := Pass = 0;
    Nodes := 0;
    for N := 0 to Count - 1 do
    begin
      if Bad then
        Break;
      X := FDoc.XrefEntry(N);
      if not X.Known or (X.Kind = pxk_Free) then
        Continue;
      O := FDoc.GetObject(N);
      if O = nil then
        Continue;
      Visit(O, False, not Collect and PatDict[N] and (O.Kind = pok_Dict), 0);
    end;
  end;
  if Bad then
  begin
    FIncomplete := True;
    FLimitHit := True;
  end;
end;

{ The pages below ANode; the number of leaves walked. veraPDF finds a page
  by its index through the /Count of the nodes: where a node's /Count does
  not match its leaves, it may see fewer or other pages. }
{ The resources of a page tree node: its own /Resources where it has the
  entry (nil if that is no dictionary), else AInherited from the node above
  in the walk (not from /Parent). }
function NodeResources(AWalk: TLandrixEInvoicePdfContentWalk; ANode, AInherited: TLandrixEInvoicePdfObject):
  TLandrixEInvoicePdfObject;
var
  R: TLandrixEInvoicePdfObject;
begin
  Result := AInherited;
  R := ANode.RawGet('Resources');
  if R = nil then
    Exit;
  Result := AWalk.ResolveRef(R);
  if (Result <> nil) and not Result.IsDictLike then
    Result := nil;
end;

function TLandrixEInvoicePdfContentWalk.WalkPages(ANode, AInherited: TLandrixEInvoicePdfObject; ADepth: Integer): Integer;
var
  Kids, T, Inh: TLandrixEInvoicePdfObject;
  Count: Int64;
  I: Integer;
begin
  Result := 0;
  if (ANode = nil) or not ANode.IsDictLike then
  begin
    FIncomplete := True;
    FPagesUnsure := True;
    Exit;
  end;
  Inc(FPageNodes);
  if (ADepth > MaxPageDepth) or (FPageNodes > MaxPageNodes) then
  begin
    FIncomplete := True;
    FPagesUnsure := True;
    Exit;
  end;
  { the root's /Type is not read; a page's /Kids neither }
  T := nil;
  if ADepth > 0 then
    T := DGetRef(ANode, 'Type');
  Kids := nil;
  if not ((T <> nil) and (T.Kind = pok_Name) and (T.NameVal = 'Page')) then
    Kids := DGetRef(ANode, 'Kids');
  Inh := NodeResources(Self, ANode, AInherited);
  { veraPDF makes the root a node and tells the kids by /Type; another type
    stops its walk }
  if (ADepth > 0) and ((T = nil) or (T.Kind <> pok_Name) or ((T.NameVal <> 'Page') and (T.NameVal <> 'Pages'))) then
  begin
    FIncomplete := True;
    FPagesUnsure := True;
  end;
  if (ADepth = 0) or ((T <> nil) and (T.Kind = pok_Name) and (T.NameVal = 'Pages')) or
    ((Kids <> nil) and (Kids.Kind = pok_Arr) and not ((T <> nil) and (T.Kind = pok_Name) and (T.NameVal = 'Page'))) then
  begin
    if (Kids <> nil) and (Kids.Kind = pok_Arr) then
      for I := 0 to Kids.ArrCount - 1 do
        Inc(Result, WalkPages(ResolveRef(Kids.ArrItem(I)), Inh, ADepth + 1));
    { a /Count that is no integer counts 0 }
    if not IntegerOf(DGetRef(ANode, 'Count'), Count) then
      Count := 0;
    if Narrow32(Count) <> Result then
    begin
      FIncomplete := True;
      FPagesUnsure := True;
    end;
    Exit;
  end;
  Result := 1;
  WalkPage(ANode, Inh);
end;

{ A page: its /Contents (a stream or the streams of an array) and the
  appearances /N, /D and /R (a stream or the streams of a state dictionary)
  of its annotations; resources from the page or up the /Parent chain. }
procedure TLandrixEInvoicePdfContentWalk.WalkPage(APage, AInherited: TLandrixEInvoicePdfObject);
const
  ApKeys: array[0..2] of AnsiString = ('N', 'D', 'R');
var
  PageRes, C, Raw, S, Annots, A, AP, V, Raw2, S2, Local: TLandrixEInvoicePdfObject;
  Streams: array of TLandrixEInvoicePdfObject;
  Key: string;
  I, K, J, First: Integer;
  Res, ApRes: TRes;
begin
  Inc(FPageCount);
  { the page's resources: own or inherited in the walk }
  PageRes := AInherited;
  Res.Local := PageRes;
  Res.Page := PageRes;

  Streams := nil;
  Key := 'C';
  First := -1;
  Raw := APage.RawGet('Contents');
  C := ResolveRef(Raw);
  if (C <> nil) and (C.Kind = pok_Stream) and (Raw.Kind = pok_Ref) then
  begin
    { one stream: the same object as a form or appearance elsewhere }
    SetLength(Streams, 1);
    Streams[0] := C;
    Key := 'S' + IntToStr(Raw.RefNum);
    First := Raw.RefNum;
  end
  else if (C <> nil) and (C.Kind = pok_Arr) then
  begin
    { an array object is one identity (shared by pages or not); a direct
      array belongs to its page }
    if Raw.Kind = pok_Ref then
      Key := 'A' + IntToStr(Raw.RefNum)
    else
      Key := 'D' + IntToStr(FPageCount);
    if C.ArrCount > MaxParts then
    begin
      { not read: it may reach anything first }
      FIncomplete := True;
      FLimitHit := True;
      Exit;
    end;
    SetLength(Streams, C.ArrCount);
    K := 0;
    for I := 0 to C.ArrCount - 1 do
    begin
      Raw := C.ArrItem(I);
      S := ResolveRef(Raw);
      if (S = nil) or (S.Kind <> pok_Stream) or (Raw.Kind <> pok_Ref) then
        Continue;
      Streams[K] := S;
      Inc(K);
      Key := Key + ',' + IntToStr(Raw.RefNum);
      if First < 0 then
        First := Raw.RefNum;
    end;
    SetLength(Streams, K);
  end;
  if Length(Streams) > 0 then
    ParseStreams(Self, Key, First, Streams, Res, FreshState(Self, Res), True);

  Annots := DGetRef(APage, 'Annots');
  if (Annots = nil) or (Annots.Kind <> pok_Arr) then
    Exit;
  for I := 0 to Annots.ArrCount - 1 do
  begin
    { veraPDF builds annotations from dictionaries only }
    A := ResolveRef(Annots.ArrItem(I));
    if (A = nil) or (A.Kind <> pok_Dict) then
      Continue;
    AP := DGetRef(A, 'AP');
    if (AP = nil) or not AP.IsDictLike then
      Continue;
    for K := 0 to High(ApKeys) do
    begin
      Raw := AP.RawGet(ApKeys[K]);
      V := ResolveRef(Raw);
      if V = nil then
        Continue;
      if V.Kind = pok_Stream then
      begin
        if Raw.Kind <> pok_Ref then
          Continue;
        Local := DGetRef(V, 'Resources');
        if (Local <> nil) and not Local.IsDictLike then
          Local := nil;
        ApRes.Local := Local;
        ApRes.Page := PageRes;
        ParseStreams(Self, 'S' + IntToStr(Raw.RefNum), Raw.RefNum, [V], ApRes, FreshState(Self, ApRes), True);
      end
      else if V.Kind = pok_Dict then
        for J := 0 to Integer(V.DVals.Count) - 1 do
        begin
          Raw2 := TLandrixEInvoicePdfObject(V.DVals[J]);
          S2 := ResolveRef(Raw2);
          if (S2 = nil) or (S2.Kind <> pok_Stream) or (Raw2.Kind <> pok_Ref) then
            Continue;
          Local := DGetRef(S2, 'Resources');
          if (Local <> nil) and not Local.IsDictLike then
            Local := nil;
          ApRes.Local := Local;
          ApRes.Page := PageRes;
          ParseStreams(Self, 'S' + IntToStr(Raw2.RefNum), Raw2.RefNum, [S2], ApRes, FreshState(Self, ApRes),
            True);
        end;
    end;
  end;
end;

{ veraPDF validates a content stream once, in whichever context it meets it
  first. A check fails for certain where every parse of a stream (all
  contexts) fails it and the stream is certainly reached; a stream is
  certainly reached from a page, or as a child that every parse of a
  certainly reached stream reaches. Anything else is uncertain. }
procedure TLandrixEInvoicePdfContentWalk.Finish;
var
  Sorted: TStringList;
  GroupStart: array of Integer;
  Members: array of Integer;
  Reach: array of Boolean;
  Head, Link: array of Integer;
  G, NG, I, J, K, M, C, CG, P0: Integer;
  P, Q: TContentParse;
  Changed, InAll, Found, AnyUnc, AllDef, AnyLvl, Emitted: Boolean;
  Chk: TLandrixEInvoicePdfContentCheck;
  Num, MaxNum: Integer;
begin
  Members := nil;
  GroupStart := nil;
  Reach := nil;
  Head := nil;
  Link := nil;
  SetLength(Head, Integer(FParses.Count));
  for I := 0 to Integer(FParses.Count) - 1 do
    Head[I] := -1;
  SetLength(Link, FFCount);
  for J := FFCount - 1 downto 0 do
  begin
    Link[J] := Head[FFParse[J]];
    Head[FFParse[J]] := J;
  end;
  Sorted := TStringList.Create;
  try
    for I := 0 to Integer(FParses.Count) - 1 do
      Sorted.AddObject(TContentParse(FParses[I]).Key, FParses[I]);
    Sorted.Sort;
    SetLength(Members, Sorted.Count);
    SetLength(GroupStart, Sorted.Count + 1);
    NG := 0;
    for I := 0 to Sorted.Count - 1 do
    begin
      Members[I] := TContentParse(Sorted.Objects[I]).Index;
      if (I = 0) or (Sorted[I] <> Sorted[I - 1]) then
      begin
        GroupStart[NG] := I;
        Inc(NG);
      end;
      TContentParse(FParses[Members[I]]).Group := NG - 1;
    end;
    GroupStart[NG] := Sorted.Count;
  finally
    Sorted.Free;
  end;

  SetLength(Reach, NG);
  for G := 0 to NG - 1 do
  begin
    Reach[G] := False;
    for M := GroupStart[G] to GroupStart[G + 1] - 1 do
      if TContentParse(FParses[Members[M]]).Root then
        Reach[G] := True;
  end;
  Changed := True;
  while Changed do
  begin
    Changed := False;
    for G := 0 to NG - 1 do
    begin
      if not Reach[G] then
        Continue;
      P := TContentParse(FParses[Members[GroupStart[G]]]);
      for C := 0 to Integer(Length(P.Children)) - 1 do
      begin
        CG := TContentParse(FParses[P.Children[C]]).Group;
        if Reach[CG] then
          Continue;
        InAll := True;
        for M := GroupStart[G] + 1 to GroupStart[G + 1] - 1 do
        begin
          Q := TContentParse(FParses[Members[M]]);
          Found := False;
          for K := 0 to Integer(Length(Q.Children)) - 1 do
            if TContentParse(FParses[Q.Children[K]]).Group = CG then
              Found := True;
          if not Found then
            InAll := False;
        end;
        if InAll then
        begin
          Reach[CG] := True;
          Changed := True;
        end;
      end;
    end;
  end;

  { a stream not read with certainty may reach any form, pattern or glyph
    in another context first, and may associate anything }
  FAnyUncertain := False;
  for I := 0 to Integer(FParses.Count) - 1 do
    if TContentParse(FParses[I]).Uncertain then
      FAnyUncertain := True;
  FAssocAll := FIncomplete or FAnyUncertain;
  { a stream not read with certainty, or not parsed at a limit, may reach
    any stream (also page contents and appearances) in another context
    first }
  if FPagesUnsure or FAnyUncertain or FLimitHit then
    for G := 0 to NG - 1 do
      Reach[G] := False;
  for Chk := Low(TLandrixEInvoicePdfContentCheck) to High(TLandrixEInvoicePdfContentCheck) do
    FUncertain[Chk] := FIncomplete;
  MaxNum := FDoc.XrefCount;
  SetLength(FAssocSure, MaxNum);
  SetLength(FAssocMaybe, MaxNum);
  for I := 0 to MaxNum - 1 do
  begin
    FAssocSure[I] := False;
    FAssocMaybe[I] := False;
  end;
  FFindingCount := 0;

  for G := 0 to NG - 1 do
  begin
    P0 := Members[GroupStart[G]];
    AnyUnc := False;
    for M := GroupStart[G] to GroupStart[G + 1] - 1 do
      if TContentParse(FParses[Members[M]]).Uncertain then
        AnyUnc := True;
    if AnyUnc then
    begin
      for Chk := Low(TLandrixEInvoicePdfContentCheck) to High(TLandrixEInvoicePdfContentCheck) do
        FUncertain[Chk] := True;
    end
    else
      for Chk := Low(TLandrixEInvoicePdfContentCheck) to High(TLandrixEInvoicePdfContentCheck) do
      begin
        AllDef := True;
        AnyLvl := False;
        for M := GroupStart[G] to GroupStart[G + 1] - 1 do
        begin
          P := TContentParse(FParses[Members[M]]);
          if P.Level[Chk] < 2 then
            AllDef := False;
          if P.Level[Chk] > 0 then
            AnyLvl := True;
        end;
        if AllDef and Reach[G] then
        begin
          Emitted := False;
          J := Head[P0];
          while J >= 0 do
          begin
            if (FFCheck[J] = Chk) and not FFMaybe[J] then
            begin
              if FFindingCount >= Length(FFindings) then
                SetLength(FFindings, 16 + 2 * FFindingCount);
              Num := TContentParse(FParses[P0]).Num;
              FFindings[FFindingCount].Check := Chk;
              FFindings[FFindingCount].ObjNum := Num;
              FFindings[FFindingCount].ObjGen := FDoc.XrefEntry(Num).Gen;
              FFindings[FFindingCount].Detail := 'content of object ' + IntToStr(Num) + ': ' + FFDetail[J];
              Inc(FFindingCount);
              Emitted := True;
            end;
            J := Link[J];
          end;
          if not Emitted then
            FUncertain[Chk] := True;
        end
        else if AnyLvl then
          FUncertain[Chk] := True;
      end;

    { associations: sure where every parse of a certainly reached stream
      makes them }
    for M := GroupStart[G] to GroupStart[G + 1] - 1 do
    begin
      P := TContentParse(FParses[Members[M]]);
      for K := 0 to Integer(Length(P.Assoc)) - 1 do
      begin
        Num := P.Assoc[K];
        if (Num < 0) or (Num >= MaxNum) then
          Continue;
        FAssocMaybe[Num] := True;
        if not Reach[G] or AnyUnc then
          Continue;
        InAll := True;
        for J := GroupStart[G] to GroupStart[G + 1] - 1 do
        begin
          Q := TContentParse(FParses[Members[J]]);
          Found := False;
          for I := 0 to Integer(Length(Q.Assoc)) - 1 do
            if Q.Assoc[I] = Num then
              Found := True;
          if not Found then
            InAll := False;
        end;
        if InAll then
          FAssocSure[Num] := True;
      end;
    end;
  end;
end;

function TLandrixEInvoicePdfContentWalk.FindingCount: Integer;
begin
  Result := FFindingCount;
end;

function TLandrixEInvoicePdfContentWalk.Finding(AIndex: Integer): TLandrixEInvoicePdfContentFinding;
begin
  Result := FFindings[AIndex];
end;

function TLandrixEInvoicePdfContentWalk.Uncertain(ACheck: TLandrixEInvoicePdfContentCheck): Boolean;
begin
  Result := FUncertain[ACheck];
end;

function TLandrixEInvoicePdfContentWalk.AssociatedSure(ANum: Integer): Boolean;
begin
  Result := (ANum >= 0) and (ANum < Integer(Length(FAssocSure))) and FAssocSure[ANum];
end;

function TLandrixEInvoicePdfContentWalk.AssociatedMaybe(ANum: Integer): Boolean;
begin
  Result := FAssocAll or ((ANum >= 0) and (ANum < Integer(Length(FAssocMaybe))) and FAssocMaybe[ANum]);
end;

end.
