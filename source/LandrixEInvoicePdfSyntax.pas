{
  EInvoice-for-Pascal

  Copyright (C) 2026 Landrix Software GmbH & Co. KG

  This file is dual-licensed under:
  - GNU GPL version 3 or later; or
  - the Landrix Software Commercial License.

  See LICENSE and COMMERCIAL-LICENSE.md.

  SPDX-License-Identifier: GPL-3.0-or-later OR LicenseRef-Landrix-Commercial
}

{ The raw syntax of a PDF file, as the PDF/A file structure checks (ISO
  19005-2/-3, clause 6.1) need it: header and end of file, every section of
  the xref chain, the envelope of every indirect object, every stream and
  the numbers, strings and names in the objects. TLandrixEInvoicePdfSyntaxFacts
  is the receiver of the PDF object layer (LandrixEInvoicePdfObjects); set it
  as TLandrixEInvoicePdfDocument.Syntax before Load, then call Inspect, which
  loads every object in use, also those nothing refers to. The unit records,
  it does not judge: the rules are elsewhere. A fact that could not be
  observed (an object that does not load, a xref chain that ends early, a
  table rebuilt by a scan, a limit) is a problem in Problems, so that
  nothing passes for want of facts.

  DE: Die rohe Syntax einer PDF-Datei, wie sie die PDF/A-Pruefung der
  Dateistruktur (ISO 19005-2/-3, Abschnitt 6.1) braucht: Kopf und Dateiende,
  jeder Abschnitt der xref-Kette, die Huelle jedes indirekten Objekts, jeder
  Stream und die Zahlen, Strings und Namen in den Objekten.
  TLandrixEInvoicePdfSyntaxFacts ist der Empfaenger der PDF-Objektschicht
  (LandrixEInvoicePdfObjects); vor Load als TLandrixEInvoicePdfDocument.Syntax
  setzen, danach Inspect aufrufen, das jedes benutzte Objekt laedt, auch
  solche, auf die nichts verweist. Die Unit haelt fest, sie urteilt nicht:
  die Regeln stehen anderswo. Eine Tatsache, die sich nicht beobachten
  liess (ein Objekt, das nicht laedt, eine xref-Kette, die frueh endet, eine
  per Scan neu aufgebaute Tabelle, eine Grenze), ist ein Problem in
  Problems, damit nichts mangels Tatsachen besteht.

  Lifetime: Streams[].Stream and Sections[].Trailer point to objects of the
  document; they are valid only while the document lives. Tokens with
  ObjNum -1 belong to the trailer dictionary of a classic xref table; ObjGen
  is the generation of the object table. Strings are measured before
  decryption (PDF/A forbids encryption). Incomplete facts may also hold
  duplicates (a table rebuilt by a scan loads objects again); rules must
  not pass a file whose facts are incomplete.

  DE: Lebensdauer: Streams[].Stream und Sections[].Trailer zeigen auf
  Objekte des Dokuments; sie gelten nur, solange das Dokument lebt. Token
  mit ObjNum -1 gehoeren zum Trailer-Dictionary einer klassischen
  xref-Tabelle; ObjGen ist die Generation der Objekttabelle. Strings werden
  vor dem Entschluesseln gemessen (PDF/A verbietet Verschluesselung).
  Unvollstaendige Tatsachen koennen auch Doppelte enthalten (eine per Scan
  neu aufgebaute Tabelle laedt Objekte erneut); Regeln duerfen eine Datei
  mit unvollstaendigen Tatsachen nicht bestehen lassen. }

{ API: internal. May change in any release; use the facade LandrixEInvoice
  or the stable units instead.
  DE: API: intern. Kann sich in jeder Version aendern; stattdessen die
  Fassade LandrixEInvoice oder die stabilen Units verwenden. }

unit LandrixEInvoicePdfSyntax;

{$I LandrixEInvoice.inc}

interface

uses
  Classes,
  LandrixEInvoicePdfObjects;

const
  { Most tokens recorded; beyond it the facts are incomplete.
    DE: Hoechstzahl festgehaltener Token; darueber sind die Tatsachen
    unvollstaendig. }
  LandrixEInvoicePdfSyntaxMaxTokens = 2000000;

  { Most problems listed; one more line says that there are more.
    DE: Hoechstzahl aufgefuehrter Probleme; eine weitere Zeile sagt, dass es
    mehr gibt. }
  LandrixEInvoicePdfSyntaxMaxProblems = 100;

type
  { Kind of a recorded token. DE: Art eines festgehaltenen Tokens. }
  TLandrixEInvoicePdfTokenKind = (ptk_Integer, ptk_Real, ptk_String, ptk_HexString, ptk_Name);

  { A number, string or name in an indirect object.
    DE: Eine Zahl, ein String oder ein Name in einem indirekten Objekt. }
  TLandrixEInvoicePdfTokenFact = record
    Kind: TLandrixEInvoicePdfTokenKind;
    { The indirect object it belongs to and where it was read.
      DE: Das indirekte Objekt, zu dem es gehoert, und wo es gelesen wurde. }
    ObjNum: Integer;
    ObjGen: Integer;
    Source: TLandrixEInvoicePdfSyntaxSource;
    { Position of the token (of the slash, the bracket or the first
      character). DE: Position des Tokens (des Schraegstrichs, der Klammer
      oder des ersten Zeichens). }
    Pos: Integer;
    { Numbers: the value. DE: Zahlen: der Wert. }
    Value: Double;
    { Strings and names: bytes after decoding. DE: Strings und Namen: Bytes
      nach dem Dekodieren. }
    Length: Integer;
    { Names: bytes as written after the slash. DE: Namen: Bytes wie
      geschrieben nach dem Schraegstrich. }
    RawLength: Integer;
    { Hexadecimal strings: characters other than white space (hex digits or
      not) and whether other characters than hex digits and white space
      occur.
      DE: Hexadezimale Strings: Zeichen ausser Leerraum (Hex-Ziffern oder
      nicht) und ob andere Zeichen als Hex-Ziffern und Leerraum vorkommen. }
    HexChars: Integer;
    HexInvalid: Boolean;
    { Names: a # not followed by two hex digits. DE: Namen: ein #, dem keine
      zwei Hex-Ziffern folgen. }
    BadEscape: Boolean;
  end;

  { A stream as written. DE: Ein Stream, wie er geschrieben ist. }
  TLandrixEInvoicePdfStreamFact = record
    ObjNum: Integer;
    ObjGen: Integer;
    Source: TLandrixEInvoicePdfSyntaxSource;
    { The stream object (its dictionary gives /Length). DE: Das
      Stream-Objekt (sein Dictionary gibt /Length an). }
    Stream: TLandrixEInvoicePdfObject;
    { The keyword stream and the line end after it. DE: Das Schluesselwort
      stream und das Zeilenende danach. }
    KeywordPos: Integer;
    KeywordEol: TLandrixEInvoicePdfEol;
    { Start of the data. DE: Beginn der Daten. }
    DataStart: Integer;
    { The endstream that ends the data (-1 if none) and the line end
      right before it: where /Length says if endstream follows
      there (LengthEnd), else the first endstream after the data (also
      when /Length is missing or cannot be resolved).
      DE: Das endstream, das die Daten beendet (-1, wenn keines), und das
      Zeilenende direkt davor: dort, wo /Length es sagt, wenn
      dort endstream folgt (LengthEnd), sonst das erste endstream nach den
      Daten (auch, wenn /Length fehlt oder sich nicht aufloesen laesst). }
    EndstreamPos: Integer;
    EndstreamEol: TLandrixEInvoicePdfEol;
    LengthEnd: Boolean;
  end;

  { The raw syntax facts of one PDF file. DE: Die rohen Syntax-Tatsachen
    einer PDF-Datei. }
  TLandrixEInvoicePdfSyntaxFacts = class(TLandrixEInvoicePdfSyntaxSink)
  private
    FCtxNum: array of Integer;
    FCtxGen: array of Integer;
    FCtxSource: array of TLandrixEInvoicePdfSyntaxSource;
    FDepth: Integer;
    FTokens: array of TLandrixEInvoicePdfTokenFact;
    FTokenCount: Integer;
    FStreams: array of TLandrixEInvoicePdfStreamFact;
    FStreamCount: Integer;
    FEnvelopes: array of TLandrixEInvoicePdfEnvelope;
    FEnvelopeCount: Integer;
    FSections: array of TLandrixEInvoicePdfXrefSection;
    FSectionCount: Integer;
    FProblems: TStringList;
    FTruncated: Boolean;
    FInspected: Boolean;
    FHeaderOffset: Integer;
    FHeaderLine: AnsiString;
    FHeaderEol: TLandrixEInvoicePdfEol;
    FCommentBytes: AnsiString;
    FPostEofSize: Integer;
    FPostEofSingleEol: Boolean;
    FInUseCount: Integer;
    procedure AddProblem(const AText: string);
    function NewToken(AKind: TLandrixEInvoicePdfTokenKind; APos: Integer): Integer;
    procedure ReadDocumentFacts(const ABuf: TLandrixEInvoicePdfBytes; AHeaderPos: Integer);
    function GetToken(AIndex: Integer): TLandrixEInvoicePdfTokenFact;
    function GetStream(AIndex: Integer): TLandrixEInvoicePdfStreamFact;
    function GetEnvelope(AIndex: Integer): TLandrixEInvoicePdfEnvelope;
    function GetSection(AIndex: Integer): TLandrixEInvoicePdfXrefSection;
  public
    { Empty facts; set them as TLandrixEInvoicePdfDocument.Syntax before
      Load. DE: Leere Tatsachen; vor Load als
      TLandrixEInvoicePdfDocument.Syntax setzen. }
    constructor Create;
    destructor Destroy; override;
    { The receiver methods, see TLandrixEInvoicePdfSyntaxSink.
      DE: Die Empfaengermethoden, siehe TLandrixEInvoicePdfSyntaxSink. }
    procedure BeginObject(ANum, AGen: Integer; ASource: TLandrixEInvoicePdfSyntaxSource); override;
    procedure EndObject; override;
    procedure NumberToken(APos: Integer; AIsInteger: Boolean; AValue: Double); override;
    procedure StringToken(APos, ALength: Integer; AHex: Boolean; AHexChars: Integer; AHexInvalid: Boolean); override;
    procedure NameToken(APos, ARawLength, ALength: Integer; ABadEscape: Boolean); override;
    procedure StreamToken(AStream: TLandrixEInvoicePdfObject; AKeywordPos: Integer; AKeywordEol: TLandrixEInvoicePdfEol;
      ADataStart, AEndstreamPos: Integer; AEndstreamEol: TLandrixEInvoicePdfEol); override;
    procedure ObjectEnvelope(const AEnvelope: TLandrixEInvoicePdfEnvelope); override;
    procedure XrefSection(const ASection: TLandrixEInvoicePdfXrefSection); override;
    procedure ChainProblem(const AText: string); override;
    procedure Unobserved(APos: Integer; const AText: string); override;
    procedure StreamEndByLength(AStream: TLandrixEInvoicePdfObject; AEndstreamPos: Integer;
      AEndstreamEol: TLandrixEInvoicePdfEol); override;
    { After ADoc.Load (with Syntax = Self): loads every object in use and
      reads header and end of file. Call it once; a document loaded without
      these facts as receiver, one that did not load or a second call give
      a problem.
      DE: Nach ADoc.Load (mit Syntax = Self): laedt jedes benutzte Objekt
      und liest Kopf und Dateiende. Einmal aufrufen; ein Dokument, das ohne
      diese Tatsachen als Empfaenger geladen wurde, eines, das nicht lud,
      oder ein zweiter Aufruf ergeben ein Problem. }
    procedure Inspect(ADoc: TLandrixEInvoicePdfDocument);
    { Inspect ran and every fact could be observed (no problem).
      DE: Inspect lief und jede Tatsache liess sich beobachten (kein
      Problem). }
    function Complete: Boolean;
    { What could not be observed. DE: Was sich nicht beobachten liess. }
    property Problems: TStringList read FProblems;
    { Position of %PDF-, the header line (up to its line end, at most 32
      bytes), its line end and the four bytes after the % of the next line
      ('' if that line does not start with %).
      DE: Position von %PDF-, die Kopfzeile (bis zu ihrem Zeilenende,
      hoechstens 32 Bytes), ihr Zeilenende und die vier Bytes nach dem % der
      naechsten Zeile ('', wenn diese Zeile nicht mit % beginnt). }
    property HeaderOffset: Integer read FHeaderOffset;
    property HeaderLine: AnsiString read FHeaderLine;
    property HeaderEol: TLandrixEInvoicePdfEol read FHeaderEol;
    property CommentBytes: AnsiString read FCommentBytes;
    { Bytes after the last %%EOF (-1 without %%EOF) and whether they are
      exactly one line end.
      DE: Bytes nach dem letzten %%EOF (-1 ohne %%EOF) und ob sie genau ein
      Zeilenende sind. }
    property PostEofSize: Integer read FPostEofSize;
    property PostEofSingleEol: Boolean read FPostEofSingleEol;
    { Entries of the object table in use (not free). DE: Benutzte Eintraege
      der Objekttabelle (nicht frei). }
    property InUseCount: Integer read FInUseCount;
    { The numbers, strings and names in the order read.
      DE: Die Zahlen, Strings und Namen in der Reihenfolge des Lesens. }
    property TokenCount: Integer read FTokenCount;
    property Tokens[AIndex: Integer]: TLandrixEInvoicePdfTokenFact read GetToken;
    { The streams in the order read. DE: Die Streams in der Reihenfolge des
      Lesens. }
    property StreamCount: Integer read FStreamCount;
    property Streams[AIndex: Integer]: TLandrixEInvoicePdfStreamFact read GetStream;
    { The envelopes of the objects read from the file.
      DE: Die Huellen der aus der Datei gelesenen Objekte. }
    property EnvelopeCount: Integer read FEnvelopeCount;
    property Envelopes[AIndex: Integer]: TLandrixEInvoicePdfEnvelope read GetEnvelope;
    { The sections of the xref chain, newest first. DE: Die Abschnitte der
      xref-Kette, der neueste zuerst. }
    property SectionCount: Integer read FSectionCount;
    property Sections[AIndex: Integer]: TLandrixEInvoicePdfXrefSection read GetSection;
  end;

implementation

uses
  SysUtils;

function EolAtPos(const ABuf: TLandrixEInvoicePdfBytes; APos: Integer): TLandrixEInvoicePdfEol;
begin
  Result := peo_None;
  if (APos < 0) or (APos >= Length(ABuf)) then
    Exit;
  if ABuf[APos] = 13 then
  begin
    if (APos + 1 < Length(ABuf)) and (ABuf[APos + 1] = 10) then
      Result := peo_CRLF
    else
      Result := peo_CR;
  end
  else if ABuf[APos] = 10 then
    Result := peo_LF;
end;

function EolSize(AEol: TLandrixEInvoicePdfEol): Integer;
begin
  case AEol of
    peo_CR, peo_LF: Result := 1;
    peo_CRLF: Result := 2;
  else
    Result := 0;
  end;
end;

constructor TLandrixEInvoicePdfSyntaxFacts.Create;
begin
  inherited Create;
  FProblems := TStringList.Create;
  FHeaderOffset := -1;
  FPostEofSize := -1;
end;

destructor TLandrixEInvoicePdfSyntaxFacts.Destroy;
begin
  FProblems.Free;
  inherited Destroy;
end;

procedure TLandrixEInvoicePdfSyntaxFacts.BeginObject(ANum, AGen: Integer; ASource: TLandrixEInvoicePdfSyntaxSource);
begin
  if FDepth >= Length(FCtxNum) then
  begin
    SetLength(FCtxNum, FDepth + 8);
    SetLength(FCtxGen, FDepth + 8);
    SetLength(FCtxSource, FDepth + 8);
  end;
  FCtxNum[FDepth] := ANum;
  FCtxGen[FDepth] := AGen;
  FCtxSource[FDepth] := ASource;
  Inc(FDepth);
end;

procedure TLandrixEInvoicePdfSyntaxFacts.EndObject;
begin
  if FDepth > 0 then
    Dec(FDepth);
end;

{ A new token of the current object, -1 outside an object or beyond the
  limit. }
function TLandrixEInvoicePdfSyntaxFacts.NewToken(AKind: TLandrixEInvoicePdfTokenKind; APos: Integer): Integer;
begin
  Result := -1;
  if FDepth = 0 then
    Exit;
  if FTokenCount >= LandrixEInvoicePdfSyntaxMaxTokens then
  begin
    FTruncated := True;
    Exit;
  end;
  if FTokenCount >= Length(FTokens) then
    SetLength(FTokens, FTokenCount + FTokenCount div 2 + 256);
  Result := FTokenCount;
  Inc(FTokenCount);
  FTokens[Result].Kind := AKind;
  FTokens[Result].ObjNum := FCtxNum[FDepth - 1];
  FTokens[Result].ObjGen := FCtxGen[FDepth - 1];
  FTokens[Result].Source := FCtxSource[FDepth - 1];
  FTokens[Result].Pos := APos;
  FTokens[Result].Value := 0;
  FTokens[Result].Length := 0;
  FTokens[Result].RawLength := 0;
  FTokens[Result].HexChars := 0;
  FTokens[Result].HexInvalid := False;
  FTokens[Result].BadEscape := False;
end;

procedure TLandrixEInvoicePdfSyntaxFacts.NumberToken(APos: Integer; AIsInteger: Boolean; AValue: Double);
var
  I: Integer;
begin
  if AIsInteger then
    I := NewToken(ptk_Integer, APos)
  else
    I := NewToken(ptk_Real, APos);
  if I >= 0 then
    FTokens[I].Value := AValue;
end;

procedure TLandrixEInvoicePdfSyntaxFacts.StringToken(APos, ALength: Integer; AHex: Boolean; AHexChars: Integer;
  AHexInvalid: Boolean);
var
  I: Integer;
begin
  if AHex then
    I := NewToken(ptk_HexString, APos)
  else
    I := NewToken(ptk_String, APos);
  if I < 0 then
    Exit;
  FTokens[I].Length := ALength;
  FTokens[I].HexChars := AHexChars;
  FTokens[I].HexInvalid := AHexInvalid;
end;

procedure TLandrixEInvoicePdfSyntaxFacts.NameToken(APos, ARawLength, ALength: Integer; ABadEscape: Boolean);
var
  I: Integer;
begin
  I := NewToken(ptk_Name, APos);
  if I < 0 then
    Exit;
  FTokens[I].Length := ALength;
  FTokens[I].RawLength := ARawLength;
  FTokens[I].BadEscape := ABadEscape;
end;

procedure TLandrixEInvoicePdfSyntaxFacts.StreamToken(AStream: TLandrixEInvoicePdfObject; AKeywordPos: Integer;
  AKeywordEol: TLandrixEInvoicePdfEol; ADataStart, AEndstreamPos: Integer; AEndstreamEol: TLandrixEInvoicePdfEol);
begin
  if FDepth = 0 then
    Exit;
  if FStreamCount >= Length(FStreams) then
    SetLength(FStreams, FStreamCount + FStreamCount div 2 + 16);
  FStreams[FStreamCount].ObjNum := FCtxNum[FDepth - 1];
  FStreams[FStreamCount].ObjGen := FCtxGen[FDepth - 1];
  FStreams[FStreamCount].Source := FCtxSource[FDepth - 1];
  FStreams[FStreamCount].Stream := AStream;
  FStreams[FStreamCount].KeywordPos := AKeywordPos;
  FStreams[FStreamCount].KeywordEol := AKeywordEol;
  FStreams[FStreamCount].DataStart := ADataStart;
  FStreams[FStreamCount].EndstreamPos := AEndstreamPos;
  FStreams[FStreamCount].EndstreamEol := AEndstreamEol;
  FStreams[FStreamCount].LengthEnd := False;
  Inc(FStreamCount);
end;

procedure TLandrixEInvoicePdfSyntaxFacts.StreamEndByLength(AStream: TLandrixEInvoicePdfObject; AEndstreamPos: Integer;
  AEndstreamEol: TLandrixEInvoicePdfEol);
var
  I: Integer;
begin
  for I := FStreamCount - 1 downto 0 do
    if FStreams[I].Stream = AStream then
    begin
      FStreams[I].EndstreamPos := AEndstreamPos;
      FStreams[I].EndstreamEol := AEndstreamEol;
      FStreams[I].LengthEnd := True;
      Exit;
    end;
end;

procedure TLandrixEInvoicePdfSyntaxFacts.ObjectEnvelope(const AEnvelope: TLandrixEInvoicePdfEnvelope);
begin
  if FEnvelopeCount >= Length(FEnvelopes) then
    SetLength(FEnvelopes, FEnvelopeCount + FEnvelopeCount div 2 + 16);
  FEnvelopes[FEnvelopeCount] := AEnvelope;
  Inc(FEnvelopeCount);
end;

procedure TLandrixEInvoicePdfSyntaxFacts.XrefSection(const ASection: TLandrixEInvoicePdfXrefSection);
begin
  if FSectionCount >= Length(FSections) then
    SetLength(FSections, FSectionCount + 4);
  FSections[FSectionCount] := ASection;
  Inc(FSectionCount);
end;

procedure TLandrixEInvoicePdfSyntaxFacts.AddProblem(const AText: string);
begin
  if FProblems.Count < LandrixEInvoicePdfSyntaxMaxProblems then
    FProblems.Add(AText)
  else if FProblems.Count = LandrixEInvoicePdfSyntaxMaxProblems then
    FProblems.Add('more problems');
end;

procedure TLandrixEInvoicePdfSyntaxFacts.ChainProblem(const AText: string);
begin
  AddProblem(AText);
end;

procedure TLandrixEInvoicePdfSyntaxFacts.Unobserved(APos: Integer; const AText: string);
var
  Where: string;
begin
  if FDepth = 0 then
    Where := ''
  else if FCtxNum[FDepth - 1] < 0 then
    Where := 'trailer: '
  else if FCtxSource[FDepth - 1] = pss_ObjectStream then
    Where := 'object ' + IntToStr(FCtxNum[FDepth - 1]) + ' (object stream): '
  else
    Where := 'object ' + IntToStr(FCtxNum[FDepth - 1]) + ': ';
  AddProblem(Where + AText + ' at ' + IntToStr(APos));
end;

{ Header line, comment bytes and the bytes after the last %%EOF. }
procedure TLandrixEInvoicePdfSyntaxFacts.ReadDocumentFacts(const ABuf: TLandrixEInvoicePdfBytes; AHeaderPos: Integer);
var
  P, N, Last: Integer;
begin
  FHeaderOffset := AHeaderPos;
  FHeaderLine := '';
  FHeaderEol := peo_None;
  FCommentBytes := '';
  if (AHeaderPos >= 0) and (AHeaderPos < Length(ABuf)) then
  begin
    P := AHeaderPos;
    while (P < Length(ABuf)) and (P - AHeaderPos < 32) and (ABuf[P] <> 10) and (ABuf[P] <> 13) do
    begin
      FHeaderLine := FHeaderLine + AnsiChar(ABuf[P]);
      Inc(P);
    end;
    FHeaderEol := EolAtPos(ABuf, P);
    if FHeaderEol <> peo_None then
    begin
      Inc(P, EolSize(FHeaderEol));
      if (P < Length(ABuf)) and (ABuf[P] = Ord('%')) then
      begin
        Inc(P);
        N := 0;
        while (P < Length(ABuf)) and (N < 4) do
        begin
          FCommentBytes := FCommentBytes + AnsiChar(ABuf[P]);
          Inc(P);
          Inc(N);
        end;
      end;
    end;
  end;

  { the last %%EOF of the file }
  FPostEofSize := -1;
  FPostEofSingleEol := False;
  Last := -1;
  P := Integer(Length(ABuf)) - 5;
  while P >= 0 do
  begin
    if (ABuf[P] = Ord('%')) and (ABuf[P + 1] = Ord('%')) and (ABuf[P + 2] = Ord('E')) and
      (ABuf[P + 3] = Ord('O')) and (ABuf[P + 4] = Ord('F')) then
    begin
      Last := P;
      Break;
    end;
    Dec(P);
  end;
  if Last >= 0 then
  begin
    FPostEofSize := Integer(Length(ABuf)) - (Last + 5);
    FPostEofSingleEol := (FPostEofSize > 0) and (EolSize(EolAtPos(ABuf, Last + 5)) = FPostEofSize);
  end;
end;

procedure TLandrixEInvoicePdfSyntaxFacts.Inspect(ADoc: TLandrixEInvoicePdfDocument);
var
  I: Integer;
  E: TLandrixEInvoicePdfXrefEntry;
begin
  if FInspected then
  begin
    AddProblem('Inspect called twice');
    Exit;
  end;
  FInspected := True;
  if (ADoc.Syntax <> Self) or (ADoc.LoadSyntax <> Self) then
    AddProblem('the facts were not the receiver while the document loaded');
  if ADoc.HeaderPos < 0 then
    AddProblem('document not loaded (no %PDF- header)');
  ReadDocumentFacts(ADoc.Buf, ADoc.HeaderPos);
  if ADoc.Reconstructed then
    AddProblem('object table rebuilt by a scan');
  FInUseCount := 0;
  for I := 0 to ADoc.XrefCount - 1 do
  begin
    E := ADoc.XrefEntry(I);
    if not E.Known or (E.Kind = pxk_Free) then
      Continue;
    Inc(FInUseCount);
    try
      if ADoc.GetObject(I) = nil then
        AddProblem('object ' + IntToStr(I) + ' not readable');
    except
      on EOutOfMemory do
        raise;
      on Ex: Exception do
        AddProblem('object ' + IntToStr(I) + ': ' + Ex.Message);
    end;
  end;
  if FTruncated then
    AddProblem('more than ' + IntToStr(LandrixEInvoicePdfSyntaxMaxTokens) + ' tokens');
end;

function TLandrixEInvoicePdfSyntaxFacts.Complete: Boolean;
begin
  Result := FInspected and (FProblems.Count = 0);
end;

function TLandrixEInvoicePdfSyntaxFacts.GetToken(AIndex: Integer): TLandrixEInvoicePdfTokenFact;
begin
  if (AIndex < 0) or (AIndex >= FTokenCount) then
    raise EListError.Create('token index out of range');
  Result := FTokens[AIndex];
end;

function TLandrixEInvoicePdfSyntaxFacts.GetStream(AIndex: Integer): TLandrixEInvoicePdfStreamFact;
begin
  if (AIndex < 0) or (AIndex >= FStreamCount) then
    raise EListError.Create('stream index out of range');
  Result := FStreams[AIndex];
end;

function TLandrixEInvoicePdfSyntaxFacts.GetEnvelope(AIndex: Integer): TLandrixEInvoicePdfEnvelope;
begin
  if (AIndex < 0) or (AIndex >= FEnvelopeCount) then
    raise EListError.Create('envelope index out of range');
  Result := FEnvelopes[AIndex];
end;

function TLandrixEInvoicePdfSyntaxFacts.GetSection(AIndex: Integer): TLandrixEInvoicePdfXrefSection;
begin
  if (AIndex < 0) or (AIndex >= FSectionCount) then
    raise EListError.Create('section index out of range');
  Result := FSections[AIndex];
end;

end.
