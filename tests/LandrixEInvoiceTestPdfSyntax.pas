{
  EInvoice-for-Pascal

  Copyright (C) 2026 Landrix Software GmbH & Co. KG

  This file is dual-licensed under:
  - GNU GPL version 3 or later; or
  - the Landrix Software Commercial License.

  See LICENSE and COMMERCIAL-LICENSE.md.

  SPDX-License-Identifier: GPL-3.0-or-later OR LicenseRef-Landrix-Commercial
}

{ Tests for the raw syntax facts of LandrixEInvoicePdfSyntax (the input of
  the PDF/A file structure checks): small PDFs written byte by byte here,
  one that follows the PDF/A syntax rules and ones that break them, a broken
  xref chain, a /Prev cycle, a file with an object stream and an xref
  stream, stream ends by /Length, an xref offset on white space, trailer
  tokens, a hybrid file, syntax the parser recovers from and misuse of
  Inspect. The rules themselves and the comparison with veraPDF come
  later. }

unit LandrixEInvoiceTestPdfSyntax;

{$I LandrixEInvoice.inc}

interface

procedure Register;

implementation

uses
  SysUtils,
  Classes,
  LandrixEInvoicePdfObjects,
  LandrixEInvoicePdfSyntax,
  LandrixEInvoiceTestFramework;

const
  LF = #10;
  CR = #13;

function IntToAnsi(V: Integer): AnsiString;
var
  S: string;
  I: Integer;
begin
  S := IntToStr(V);
  Result := '';
  SetLength(Result, Length(S));
  for I := 1 to Length(S) do
    Result[I] := AnsiChar(Ord(S[I]));
end;

function Pad(V, AWidth: Integer): AnsiString;
begin
  Result := IntToAnsi(V);
  while Length(Result) < AWidth do
    Result := '0' + Result;
end;

{ Position (0-based) of ASub in AText from AFrom (1-based), -1 if absent. }
function RawPos(const ASub, AText: AnsiString; AFrom: Integer): Integer;
var
  I, J: Integer;
  Ok: Boolean;
begin
  Result := -1;
  for I := AFrom to Length(AText) - Length(ASub) + 1 do
  begin
    Ok := True;
    for J := 1 to Length(ASub) do
      if AText[I + J - 1] <> ASub[J] then
      begin
        Ok := False;
        Break;
      end;
    if Ok then
    begin
      Result := I - 1;
      Exit;
    end;
  end;
end;

{ A PDF with a classic xref table: AHeader, the objects as written (each
  starts with its object number), "xref" + AXrefTail, one subsection over
  objects 0 to the highest number (missing numbers free), the trailer with
  ATrailerExtra ("@XREF@" stands for the offset of the table), startxref and
  %%EOF + ATail. }
function BuildPdf(const AHeader: AnsiString; const AObjects: array of AnsiString; const AXrefTail,
  ATrailerExtra, ATail: AnsiString): AnsiString;
var
  Offsets: array of Integer;
  I, Num, MaxNum, XrefPos: Integer;
  S, Trailer: AnsiString;
begin
  Result := AHeader;
  MaxNum := 0;
  Offsets := nil;
  for I := 0 to Integer(Length(AObjects)) - 1 do
  begin
    S := AObjects[I];
    Num := 0;
    while (Length(S) > 0) and (S[1] >= '0') and (S[1] <= '9') do
    begin
      Num := Num * 10 + Ord(S[1]) - Ord('0');
      Delete(S, 1, 1);
    end;
    if Num >= Length(Offsets) then
      SetLength(Offsets, Num + 1);
    Offsets[Num] := Length(Result);
    if Num > MaxNum then
      MaxNum := Num;
    Result := Result + AObjects[I];
  end;
  XrefPos := Length(Result);
  Result := Result + 'xref' + AXrefTail + '0 ' + IntToAnsi(MaxNum + 1) + LF;
  for I := 0 to MaxNum do
    if (I < Length(Offsets)) and (Offsets[I] > 0) then
      Result := Result + Pad(Offsets[I], 10) + ' 00000 n' + CR + LF
    else
      Result := Result + '0000000000 65535 f' + CR + LF;
  Trailer := ATrailerExtra;
  I := RawPos('@XREF@', Trailer, 1);
  if I >= 0 then
    Trailer := Copy(Trailer, 1, I) + IntToAnsi(XrefPos) + Copy(Trailer, I + 7, MaxInt);
  Result := Result + 'trailer' + LF + '<< /Size ' + IntToAnsi(MaxNum + 1) + ' /Root 1 0 R' + Trailer + ' >>' + LF +
    'startxref' + LF + IntToAnsi(XrefPos) + LF + '%%EOF' + ATail;
end;

const
  GoodHeader = '%PDF-1.7' + LF + '%' + #$E2#$E3#$CF#$D3 + LF;
  Catalog = '1 0 obj' + LF + '<< /Type /Catalog /Pages 2 0 R >>' + LF + 'endobj' + LF;
  Pages = '2 0 obj' + LF + '<< /Type /Pages /Kids [] /Count 0 >>' + LF + 'endobj' + LF;
  FileId = ' /ID [<0102030405060708090A0B0C0D0E0F10><0102030405060708090A0B0C0D0E0F10>]';

{ Loads APdf with AFacts as receiver and inspects it; the caller frees the
  document (the facts point into it). }
function LoadWithFacts(const APdf: AnsiString; AFacts: TLandrixEInvoicePdfSyntaxFacts): TLandrixEInvoicePdfDocument;
var
  M: TMemoryStream;
  Err: string;
begin
  Result := TLandrixEInvoicePdfDocument.Create;
  M := TMemoryStream.Create;
  try
    try
      if Length(APdf) > 0 then
        M.WriteBuffer(APdf[1], Length(APdf));
      M.Position := 0;
      Result.Syntax := AFacts;
      Check(Result.Load(M, Err), 'Load: ' + Err);
      AFacts.Inspect(Result);
    except
      Result.Free;
      raise;
    end;
  finally
    M.Free;
  end;
end;

function FindStream(AFacts: TLandrixEInvoicePdfSyntaxFacts; ANum: Integer; out AStream: TLandrixEInvoicePdfStreamFact): Boolean;
var
  I: Integer;
begin
  Result := False;
  for I := 0 to AFacts.StreamCount - 1 do
    if AFacts.Streams[I].ObjNum = ANum then
    begin
      AStream := AFacts.Streams[I];
      Result := True;
      Exit;
    end;
end;

function FindEnvelope(AFacts: TLandrixEInvoicePdfSyntaxFacts; ANum: Integer; out AEnv: TLandrixEInvoicePdfEnvelope): Boolean;
var
  I: Integer;
begin
  Result := False;
  for I := 0 to AFacts.EnvelopeCount - 1 do
    if AFacts.Envelopes[I].Num = ANum then
    begin
      AEnv := AFacts.Envelopes[I];
      Result := True;
      Exit;
    end;
end;

{ The tokens of object ANum as text: kind and details, in order. }
function TokensOf(AFacts: TLandrixEInvoicePdfSyntaxFacts; ANum: Integer): string;
const
  Kinds: array[TLandrixEInvoicePdfTokenKind] of string = ('int', 'real', 'str', 'hex', 'name');
var
  I: Integer;
  T: TLandrixEInvoicePdfTokenFact;
begin
  Result := '';
  for I := 0 to AFacts.TokenCount - 1 do
  begin
    T := AFacts.Tokens[I];
    if T.ObjNum <> ANum then
      Continue;
    if Result <> '' then
      Result := Result + ' ';
    Result := Result + Kinds[T.Kind];
    case T.Kind of
      ptk_Integer, ptk_Real:
        Result := Result + ':' + FloatToStr(T.Value);
      ptk_String:
        Result := Result + ':' + IntToStr(T.Length);
      ptk_HexString:
        begin
          Result := Result + ':' + IntToStr(T.HexDigits);
          if T.HexInvalid then
            Result := Result + '!';
        end;
      ptk_Name:
        begin
          Result := Result + ':' + IntToStr(T.RawLength) + '/' + IntToStr(T.Length);
          if T.BadEscape then
            Result := Result + '!';
        end;
    end;
  end;
end;

procedure TestFacts;
var
  Pdf: AnsiString;
  Facts: TLandrixEInvoicePdfSyntaxFacts;
  Doc: TLandrixEInvoicePdfDocument;
  Env: TLandrixEInvoicePdfEnvelope;
  St: TLandrixEInvoicePdfStreamFact;
  I: Integer;
begin
  Pdf := BuildPdf(GoodHeader, [Catalog, Pages,
    '3 0 obj' + LF + '<< /Length 5 >>' + LF + 'stream' + LF + 'hello' + LF + 'endstream' + LF + 'endobj' + LF,
    '4 0 obj' + LF + '[ 1 -2 3.5 (abc) <4142> /N#41me ]' + LF + 'endobj' + LF], LF, FileId, LF);
  Facts := TLandrixEInvoicePdfSyntaxFacts.Create;
  try
    Doc := LoadWithFacts(Pdf, Facts);
    try
      Check(Facts.Complete, 'complete: ' + Facts.Problems.Text);
      CheckEquals(0, Facts.HeaderOffset, 'header offset');
      CheckEqualsBytes('%PDF-1.7', Facts.HeaderLine, 'header line');
      CheckEquals(Ord(peo_LF), Ord(Facts.HeaderEol), 'header line end');
      CheckEqualsBytes(#$E2#$E3#$CF#$D3, Facts.CommentBytes, 'comment bytes');
      CheckEquals(1, Facts.PostEofSize, 'bytes after %%EOF');
      Check(Facts.PostEofSingleEol, 'one line end after %%EOF');
      CheckEquals(4, Facts.InUseCount, 'objects in use');
      CheckEquals(4, Facts.EnvelopeCount, 'envelopes, also of the unreferenced objects');
      for I := 1 to 4 do
      begin
        Check(FindEnvelope(Facts, I, Env), 'envelope ' + IntToStr(I));
        CheckEquals(Ord(peo_LF), Ord(Env.EolBefore), 'line end before object ' + IntToStr(I));
        CheckEquals(1, Env.SpacesNumGen, 'one space after the number ' + IntToStr(I));
        CheckEquals(1, Env.SpacesGenObj, 'one space after the generation ' + IntToStr(I));
        CheckEquals(Ord(peo_LF), Ord(Env.ObjEol), 'line end after obj ' + IntToStr(I));
        Check(Env.EndobjPos > 0, 'endobj ' + IntToStr(I));
        CheckEquals(Ord(peo_LF), Ord(Env.EndobjEolBefore), 'line end before endobj ' + IntToStr(I));
        CheckEquals(Ord(peo_LF), Ord(Env.EndobjEolAfter), 'line end after endobj ' + IntToStr(I));
      end;
      CheckEquals(1, Facts.SectionCount, 'xref sections');
      Check(not Facts.Sections[0].IsStream, 'a table');
      CheckEquals(Ord(peo_LF), Ord(Facts.Sections[0].KeywordEol), 'line end after xref');
      Check(Facts.Sections[0].HeaderAfterEol, 'subsection header after the line end');
      Check(Facts.Sections[0].Trailer <> nil, 'trailer');
      Check(Facts.Sections[0].Trailer.RawGet('ID') <> nil, 'trailer /ID');
      CheckEquals(1, Facts.StreamCount, 'streams');
      St := Facts.Streams[0];
      CheckEquals(3, St.ObjNum, 'stream object');
      CheckEquals(Ord(peo_LF), Ord(St.KeywordEol), 'line end after stream');
      CheckEquals(RawPos('hello', Pdf, 1), St.DataStart, 'data start');
      CheckEquals(RawPos('endstream', Pdf, 1), St.EndstreamPos, 'endstream');
      CheckEquals(Ord(peo_LF), Ord(St.EndstreamEol), 'line end before endstream');
      CheckEquals(5, St.EndstreamPos - 1 - St.DataStart, 'real length = /Length');
      CheckEqualsStr('int:1 int:-2 real:' + FloatToStr(3.5) + ' str:3 hex:4 name:6/4', TokensOf(Facts, 4),
        'tokens of object 4');
      CheckEqualsStr('name:4/4 name:7/7 name:5/5', TokensOf(Facts, 1), 'references are no integers');
    finally
      Doc.Free;
    end;
  finally
    Facts.Free;
  end;
end;

procedure TestViolations;
var
  Pdf: AnsiString;
  Facts: TLandrixEInvoicePdfSyntaxFacts;
  Doc: TLandrixEInvoicePdfDocument;
  Env: TLandrixEInvoicePdfEnvelope;
  St: TLandrixEInvoicePdfStreamFact;
begin
  Pdf := BuildPdf('%PDF-1.7' + CR + LF + '%abcd' + CR + LF, [Catalog,
    '2  0 obj <<' + LF + '/Type /Pages /Kids [] /Count 0 >> endobj ' + LF,
    '3 0 obj' + LF + '<< /Length 4 >>' + LF + 'stream' + CR + 'data endstream' + LF + 'endobj' + LF,
    '4 0 obj' + LF + '[ 2147483648 <41G> <414> /A#4 ]' + LF + 'endobj' + LF], ' ' + LF, FileId,
    LF + LF + 'garbage');
  Facts := TLandrixEInvoicePdfSyntaxFacts.Create;
  try
    Doc := LoadWithFacts(Pdf, Facts);
    try
      Check(Facts.Complete, 'complete: ' + Facts.Problems.Text);
      CheckEquals(Ord(peo_CRLF), Ord(Facts.HeaderEol), 'header line end');
      CheckEqualsBytes('abcd', Facts.CommentBytes, 'comment bytes');
      CheckEquals(9, Facts.PostEofSize, 'bytes after %%EOF');
      Check(not Facts.PostEofSingleEol, 'more than one line end after %%EOF');
      Check(FindEnvelope(Facts, 2, Env), 'envelope 2');
      CheckEquals(2, Env.SpacesNumGen, 'two spaces after the number');
      CheckEquals(Ord(peo_None), Ord(Env.ObjEol), 'no line end after obj');
      CheckEquals(Ord(peo_None), Ord(Env.EndobjEolBefore), 'no line end before endobj');
      CheckEquals(Ord(peo_None), Ord(Env.EndobjEolAfter), 'a space after endobj');
      St := Facts.Streams[0];
      CheckEquals(Ord(peo_CR), Ord(St.KeywordEol), 'CR alone after stream');
      CheckEquals(Ord(peo_None), Ord(St.EndstreamEol), 'no line end before endstream');
      CheckEqualsStr('int:2147483648 hex:2! hex:3 name:3/3!', TokensOf(Facts, 4), 'tokens of object 4');
      CheckEquals(Ord(peo_None), Ord(Facts.Sections[0].KeywordEol), 'a space after xref');
      Check(not Facts.Sections[0].HeaderAfterEol, 'subsection header not right after a line end');
    finally
      Doc.Free;
    end;
  finally
    Facts.Free;
  end;
end;

procedure TestChain;
var
  Pdf: AnsiString;
  Facts: TLandrixEInvoicePdfSyntaxFacts;
  Doc: TLandrixEInvoicePdfDocument;
  P: Integer;
begin
  { startxref points behind the end of the file: the table is rebuilt }
  Pdf := BuildPdf(GoodHeader, [Catalog, Pages], LF, FileId, LF);
  P := RawPos('startxref' + LF, Pdf, 1);
  Pdf := Copy(Pdf, 1, P + 10) + '99999999' + LF + '%%EOF' + LF;
  Facts := TLandrixEInvoicePdfSyntaxFacts.Create;
  try
    Doc := LoadWithFacts(Pdf, Facts);
    try
      Check(not Facts.Complete, 'not complete');
      Check(Facts.Problems.Count >= 2, 'problems: ' + Facts.Problems.Text);
      Check(Pos('rebuilt', Facts.Problems.Text) > 0, 'rebuilt table: ' + Facts.Problems.Text);
      Check(Pos('outside the file', Facts.Problems.Text) > 0, 'offset outside: ' + Facts.Problems.Text);
    finally
      Doc.Free;
    end;
  finally
    Facts.Free;
  end;

  { /Prev points to the table itself }
  Pdf := BuildPdf(GoodHeader, [Catalog, Pages], LF, FileId + ' /Prev @XREF@', LF);
  Facts := TLandrixEInvoicePdfSyntaxFacts.Create;
  try
    Doc := LoadWithFacts(Pdf, Facts);
    try
      Check(not Facts.Complete, 'cycle: not complete');
      Check(Pos('cycle', Facts.Problems.Text) > 0, 'cycle: ' + Facts.Problems.Text);
      CheckEquals(1, Facts.SectionCount, 'cycle: one section');
    finally
      Doc.Free;
    end;
  finally
    Facts.Free;
  end;
end;

function Row(AType, AField2, AField3: Integer): AnsiString;
begin
  Result := AnsiChar(AType) + AnsiChar((AField2 shr 24) and $FF) + AnsiChar((AField2 shr 16) and $FF) +
    AnsiChar((AField2 shr 8) and $FF) + AnsiChar(AField2 and $FF) + AnsiChar((AField3 shr 8) and $FF) +
    AnsiChar(AField3 and $FF);
end;

{ Objects 1, 2, an object stream 5 (/N AN, /First AFirst, data AStmData)
  holding object 6 and, with AObj8, object 8, and the xref stream 7 (eight
  rows, nine with AObj8; /Size ASize). }
function BuildObjStmPdf(ASize, AN, AFirst: Integer; const AStmData: AnsiString; AObj8: Boolean): AnsiString;
var
  Pdf, Rows: AnsiString;
  Ofs1, Ofs2, Ofs5, Ofs7: Integer;
begin
  Pdf := GoodHeader;
  Ofs1 := Length(Pdf);
  Pdf := Pdf + Catalog;
  Ofs2 := Length(Pdf);
  Pdf := Pdf + Pages;
  Ofs5 := Length(Pdf);
  Pdf := Pdf + '5 0 obj' + LF + '<< /Type /ObjStm /N ' + IntToAnsi(AN) + ' /First ' + IntToAnsi(AFirst) + ' /Length ' +
    IntToAnsi(Length(AStmData)) + ' >>' + LF + 'stream' + LF + AStmData + LF + 'endstream' + LF + 'endobj' + LF;
  Ofs7 := Length(Pdf);
  Rows := Row(0, 0, 65535) + Row(1, Ofs1, 0) + Row(1, Ofs2, 0) + Row(0, 0, 0) + Row(0, 0, 0) + Row(1, Ofs5, 0) +
    Row(2, 5, 0) + Row(1, Ofs7, 0);
  if AObj8 then
    Rows := Rows + Row(2, 5, 1);
  Result := Pdf + '7 0 obj' + LF + '<< /Type /XRef /Size ' + IntToAnsi(ASize) + ' /W [1 4 2] /Root 1 0 R' + FileId +
    ' /Length ' + IntToAnsi(Length(Rows)) + ' >>' + LF + 'stream' + LF + Rows + LF + 'endstream' + LF + 'endobj' + LF +
    'startxref' + LF + IntToAnsi(Ofs7) + LF + '%%EOF' + LF;
end;

procedure TestObjectStream;
var
  Facts: TLandrixEInvoicePdfSyntaxFacts;
  Doc: TLandrixEInvoicePdfDocument;
  I: Integer;
  T: TLandrixEInvoicePdfTokenFact;
  Seen: Integer;
  Env: TLandrixEInvoicePdfEnvelope;
begin
  Facts := TLandrixEInvoicePdfSyntaxFacts.Create;
  try
    Doc := LoadWithFacts(BuildObjStmPdf(8, 1, 4, '6 0 [7 8.5]', False), Facts);
    try
      Check(Facts.Complete, 'complete: ' + Facts.Problems.Text);
      CheckEquals(5, Facts.InUseCount, 'objects in use');
      CheckEquals(1, Facts.SectionCount, 'xref sections');
      Check(Facts.Sections[0].IsStream, 'an xref stream');
      Seen := 0;
      for I := 0 to Facts.TokenCount - 1 do
      begin
        T := Facts.Tokens[I];
        if T.ObjNum <> 6 then
          Continue;
        Inc(Seen);
        Check(T.Source = pss_ObjectStream, 'object 6 comes from the object stream');
      end;
      CheckEquals(2, Seen, 'tokens of object 6');
      Check(not FindEnvelope(Facts, 6, Env), 'no envelope for an object of an object stream');
      Check(FindEnvelope(Facts, 5, Env), 'envelope of the object stream');
      Check(FindEnvelope(Facts, 7, Env), 'envelope of the xref stream');
      CheckEquals(2, Facts.StreamCount, 'object stream and xref stream, the latter once');
      CheckEquals(4, Facts.EnvelopeCount, 'envelopes 1, 2, 5 and 7, each once');
    finally
      Doc.Free;
    end;
  finally
    Facts.Free;
  end;

  { /Size 9 with eight rows: the stream ends before its last entry }
  Facts := TLandrixEInvoicePdfSyntaxFacts.Create;
  try
    Doc := LoadWithFacts(BuildObjStmPdf(9, 1, 4, '6 0 [7 8.5]', False), Facts);
    try
      Check(not Facts.Complete, 'short xref stream: not complete');
      Check(Pos('ends before its last entry', Facts.Problems.Text) > 0, 'short: ' + Facts.Problems.Text);
    finally
      Doc.Free;
    end;
  finally
    Facts.Free;
  end;

  { object 6 is read across the start of object 8 }
  Facts := TLandrixEInvoicePdfSyntaxFacts.Create;
  try
    Doc := LoadWithFacts(BuildObjStmPdf(9, 2, 8, '6 0 8 3 [1 2]', True), Facts);
    try
      Check(not Facts.Complete, 'overrun: not complete');
      Check(Pos('object 6 (object stream): object reaches into the next object', Facts.Problems.Text) > 0,
        'overrun: ' + Facts.Problems.Text);
    finally
      Doc.Free;
    end;
  finally
    Facts.Free;
  end;

  { offsets not ascending }
  Facts := TLandrixEInvoicePdfSyntaxFacts.Create;
  try
    Doc := LoadWithFacts(BuildObjStmPdf(9, 2, 8, '6 3 8 0 [1 2]', True), Facts);
    try
      Check(Pos('member offsets not ascending', Facts.Problems.Text) > 0, 'descending: ' + Facts.Problems.Text);
    finally
      Doc.Free;
    end;
  finally
    Facts.Free;
  end;

  { bytes left after the only object }
  Facts := TLandrixEInvoicePdfSyntaxFacts.Create;
  try
    Doc := LoadWithFacts(BuildObjStmPdf(8, 1, 4, '6 0 7 8', False), Facts);
    try
      Check(Pos('object 6 (object stream): bytes after the object', Facts.Problems.Text) > 0,
        'left over: ' + Facts.Problems.Text);
    finally
      Doc.Free;
    end;
  finally
    Facts.Free;
  end;
end;

procedure TestStreamEnds;
var
  Pdf: AnsiString;
  Facts: TLandrixEInvoicePdfSyntaxFacts;
  Doc: TLandrixEInvoicePdfDocument;
  Env: TLandrixEInvoicePdfEnvelope;
  St: TLandrixEInvoicePdfStreamFact;
begin
  { 3: endstream inside the data, direct /Length; 4: the same with an
    indirect /Length; 6: a wrong /Length; 7: an empty stream }
  Pdf := BuildPdf(GoodHeader, [Catalog, Pages,
    '3 0 obj' + LF + '<< /Length 15 >>' + LF + 'stream' + LF + 'a endstream b c' + LF + 'endstream' + LF + 'endobj' + LF,
    '4 0 obj' + LF + '<< /Length 5 0 R >>' + LF + 'stream' + LF + '(endstream)' + LF + 'endstream' + LF + 'endobj' + LF,
    '5 0 obj' + LF + '11' + LF + 'endobj' + LF,
    '6 0 obj' + LF + '<< /Length 2 >>' + LF + 'stream' + LF + 'hello' + LF + 'endstream' + LF + 'endobj' + LF,
    '7 0 obj' + LF + '<< /Length 0 >>' + LF + 'stream' + LF + 'endstream' + LF + 'endobj' + LF], LF, FileId, LF);
  Facts := TLandrixEInvoicePdfSyntaxFacts.Create;
  try
    Doc := LoadWithFacts(Pdf, Facts);
    try
      Check(Facts.Complete, 'complete: ' + Facts.Problems.Text);
      Check(FindStream(Facts, 3, St), 'stream 3');
      Check(St.LengthEnd, 'stream 3 ends by /Length');
      CheckEquals(RawPos('c' + LF + 'endstream', Pdf, 1) + 2, St.EndstreamPos, 'stream 3 endstream');
      CheckEquals(Ord(peo_LF), Ord(St.EndstreamEol), 'stream 3 line end');
      Check(FindEnvelope(Facts, 3, Env) and (Env.EndobjPos > 0), 'endobj of object 3');
      Check(FindStream(Facts, 4, St), 'stream 4');
      Check(St.LengthEnd, 'stream 4 ends by the indirect /Length');
      CheckEquals(RawPos(')' + LF + 'endstream', Pdf, 1) + 2, St.EndstreamPos, 'stream 4 endstream');
      Check(FindEnvelope(Facts, 4, Env) and (Env.EndobjPos > 0), 'endobj of object 4');
      Check(FindEnvelope(Facts, 5, Env), 'envelope of the length object');
      Check(FindStream(Facts, 6, St), 'stream 6');
      Check(not St.LengthEnd, 'stream 6: /Length does not end the data');
      CheckEquals(RawPos('hello' + LF + 'endstream', Pdf, 1) + 6, St.EndstreamPos, 'stream 6 endstream');
      Check(FindStream(Facts, 7, St), 'stream 7');
      Check(St.LengthEnd, 'stream 7 ends by /Length');
      CheckEquals(St.DataStart, St.EndstreamPos, 'stream 7 is empty');
      CheckEquals(Ord(peo_None), Ord(St.EndstreamEol), 'stream 7: the keyword line end is not the one before endstream');
    finally
      Doc.Free;
    end;
  finally
    Facts.Free;
  end;
end;

procedure TestEnvelopeOffset;
var
  Pdf: AnsiString;
  Facts: TLandrixEInvoicePdfSyntaxFacts;
  Doc: TLandrixEInvoicePdfDocument;
  Env: TLandrixEInvoicePdfEnvelope;
  P, I: Integer;
begin
  { the xref entry of object 2 points at the line end before it }
  Pdf := BuildPdf(GoodHeader, [Catalog, Pages], LF, FileId, LF);
  P := RawPos('2 0 obj', Pdf, 1);
  I := RawPos(Pad(P, 10) + ' 00000 n', Pdf, 1);
  Check(I > 0, 'xref entry of object 2');
  Pdf := Copy(Pdf, 1, I) + Pad(P - 1, 10) + Copy(Pdf, I + 11, MaxInt);
  Facts := TLandrixEInvoicePdfSyntaxFacts.Create;
  try
    Doc := LoadWithFacts(Pdf, Facts);
    try
      Check(Facts.Complete, 'complete: ' + Facts.Problems.Text);
      Check(FindEnvelope(Facts, 2, Env), 'envelope 2');
      CheckEquals(P, Env.Offset, 'offset of the object number');
      CheckEquals(Ord(peo_LF), Ord(Env.EolBefore), 'line end before the number');
      CheckEquals(1, Env.SpacesNumGen, 'one space after the number');
      CheckEquals(1, Env.SpacesGenObj, 'one space after the generation');
    finally
      Doc.Free;
    end;
  finally
    Facts.Free;
  end;
end;

procedure TestTrailerAndStrings;
var
  Pdf: AnsiString;
  Facts: TLandrixEInvoicePdfSyntaxFacts;
  Doc: TLandrixEInvoicePdfDocument;
begin
  Pdf := BuildPdf(GoodHeader, [Catalog, Pages,
    '3 0 obj' + LF + '[ (a' + CR + LF + 'b) (c\' + CR + LF + 'd) ]' + LF + 'endobj' + LF], LF, ' /ID [<0><0102>]', LF);
  Facts := TLandrixEInvoicePdfSyntaxFacts.Create;
  try
    Doc := LoadWithFacts(Pdf, Facts);
    try
      Check(Facts.Complete, 'complete: ' + Facts.Problems.Text);
      CheckEqualsStr('str:3 str:2', TokensOf(Facts, 3), 'CR LF in a string counts once, an escaped one not at all');
      CheckEqualsStr('name:4/4 int:4 name:4/4 name:2/2 hex:1 hex:4', TokensOf(Facts, -1), 'trailer tokens');
    finally
      Doc.Free;
    end;
  finally
    Facts.Free;
  end;
end;

procedure TestHybrid;
var
  Pdf, Stm: AnsiString;
  Facts: TLandrixEInvoicePdfSyntaxFacts;
  Doc: TLandrixEInvoicePdfDocument;
  Env: TLandrixEInvoicePdfEnvelope;
  St: TLandrixEInvoicePdfStreamFact;
begin
  { an xref stream without rows that only /XRefStm names }
  Stm := '9 0 obj' + LF + '<< /Type /XRef /Size 3 /W [1 4 2] /Index [0 0] /Length 0 >>' + LF + 'stream' + LF +
    'endstream' + LF + 'endobj' + LF;
  Pdf := BuildPdf(GoodHeader + Stm, [Catalog, Pages], LF, FileId + ' /XRefStm ' + IntToAnsi(Length(GoodHeader)), LF);
  Facts := TLandrixEInvoicePdfSyntaxFacts.Create;
  try
    Doc := LoadWithFacts(Pdf, Facts);
    try
      Check(Facts.Complete, 'complete: ' + Facts.Problems.Text);
      CheckEquals(2, Facts.SectionCount, 'table and xref stream');
      Check(Facts.Sections[1].IsStream, 'second section is the stream');
      CheckEquals(Length(GoodHeader), Facts.Sections[1].Offset, 'offset of the xref stream');
      Check(FindEnvelope(Facts, 9, Env), 'envelope of the xref stream');
      Check(FindStream(Facts, 9, St), 'stream of the xref stream');
    finally
      Doc.Free;
    end;
  finally
    Facts.Free;
  end;

  Pdf := BuildPdf(GoodHeader, [Catalog, Pages], LF, FileId + ' /XRefStm 99999999', LF);
  Facts := TLandrixEInvoicePdfSyntaxFacts.Create;
  try
    Doc := LoadWithFacts(Pdf, Facts);
    try
      Check(not Facts.Complete, '/XRefStm outside: not complete');
      Check(Pos('unusable /XRefStm', Facts.Problems.Text) > 0, '/XRefStm: ' + Facts.Problems.Text);
    finally
      Doc.Free;
    end;
  finally
    Facts.Free;
  end;

  Pdf := BuildPdf(GoodHeader, [Catalog, Pages], LF, FileId + ' /Prev /Foo', LF);
  Facts := TLandrixEInvoicePdfSyntaxFacts.Create;
  try
    Doc := LoadWithFacts(Pdf, Facts);
    try
      Check(not Facts.Complete, '/Prev name: not complete');
      Check(Pos('unusable /Prev', Facts.Problems.Text) > 0, '/Prev: ' + Facts.Problems.Text);
    finally
      Doc.Free;
    end;
  finally
    Facts.Free;
  end;
end;

procedure TestRecovery;
var
  Pdf: AnsiString;
  Facts: TLandrixEInvoicePdfSyntaxFacts;
  Doc: TLandrixEInvoicePdfDocument;
begin
  Pdf := BuildPdf(GoodHeader, [Catalog, Pages, '3 0 obj' + LF + '[ 1e5 ]' + LF + 'endobj' + LF,
    '4 0 obj' + LF + '[ 1 2' + LF + 'endobj' + LF, '5 0 obj' + LF + '<< /A >>' + LF + 'endobj' + LF,
    '6 0 obj' + LF + '[ 1 0.0 R ]' + LF + 'endobj' + LF, '7 0.0 obj' + LF + 'null' + LF + 'endobj' + LF,
    '8 0 %c' + LF + 'obj' + LF + 'null' + LF + 'endobj' + LF], LF, FileId, LF);
  Facts := TLandrixEInvoicePdfSyntaxFacts.Create;
  try
    Doc := LoadWithFacts(Pdf, Facts);
    try
      Check(not Facts.Complete, 'not complete');
      Check(Pos('object 3: malformed number', Facts.Problems.Text) > 0, 'number: ' + Facts.Problems.Text);
      Check(Pos('object 4: array not closed', Facts.Problems.Text) > 0, 'array: ' + Facts.Problems.Text);
      Check(Pos('object 5: dictionary value missing', Facts.Problems.Text) > 0, 'dictionary: ' + Facts.Problems.Text);
      Check(Pos('object 6: malformed reference', Facts.Problems.Text) > 0, 'reference: ' + Facts.Problems.Text);
      Check(Pos('object 7: malformed object or generation number', Facts.Problems.Text) > 0,
        'generation: ' + Facts.Problems.Text);
      Check(Pos('object 8: comment in the object header', Facts.Problems.Text) > 0, 'comment: ' + Facts.Problems.Text);
    finally
      Doc.Free;
    end;
  finally
    Facts.Free;
  end;
end;

procedure TestInspectMisuse;
var
  Pdf: AnsiString;
  Facts, Other: TLandrixEInvoicePdfSyntaxFacts;
  Doc: TLandrixEInvoicePdfDocument;
  M: TMemoryStream;
  Err: string;
begin
  Pdf := BuildPdf(GoodHeader, [Catalog, Pages], LF, FileId, LF);
  { the receiver set only after Load }
  Facts := TLandrixEInvoicePdfSyntaxFacts.Create;
  try
    Doc := TLandrixEInvoicePdfDocument.Create;
    try
      M := TMemoryStream.Create;
      try
        M.WriteBuffer(Pdf[1], Length(Pdf));
        M.Position := 0;
        Check(Doc.Load(M, Err), 'Load: ' + Err);
      finally
        M.Free;
      end;
      Doc.Syntax := Facts;
      Facts.Inspect(Doc);
      Check(not Facts.Complete, 'set after Load: not complete');
      Check(Pos('not the receiver', Facts.Problems.Text) > 0, 'after Load: ' + Facts.Problems.Text);
    finally
      Doc.Free;
    end;
  finally
    Facts.Free;
  end;

  { Inspect twice }
  Facts := TLandrixEInvoicePdfSyntaxFacts.Create;
  try
    Doc := LoadWithFacts(Pdf, Facts);
    try
      Check(Facts.Complete, 'first Inspect: ' + Facts.Problems.Text);
      Facts.Inspect(Doc);
      Check(not Facts.Complete, 'second Inspect: not complete');
      Check(Pos('twice', Facts.Problems.Text) > 0, 'twice: ' + Facts.Problems.Text);
    finally
      Doc.Free;
    end;
  finally
    Facts.Free;
  end;

  { loaded with one receiver, inspected by another }
  Facts := TLandrixEInvoicePdfSyntaxFacts.Create;
  try
    Doc := LoadWithFacts(Pdf, Facts);
    try
      Other := TLandrixEInvoicePdfSyntaxFacts.Create;
      try
        Doc.Syntax := Other;
        Other.Inspect(Doc);
        Check(not Other.Complete, 'other receiver: not complete');
        Check(Pos('not the receiver', Other.Problems.Text) > 0, 'other: ' + Other.Problems.Text);
      finally
        Doc.Syntax := Facts;
        Other.Free;
      end;
    finally
      Doc.Free;
    end;
  finally
    Facts.Free;
  end;

  { receiver taken away while an unreferenced object is read }
  Pdf := BuildPdf(GoodHeader, [Catalog, Pages, '3 0 obj' + LF + '[ 1 ]' + LF + 'endobj' + LF], LF, FileId, LF);
  Facts := TLandrixEInvoicePdfSyntaxFacts.Create;
  try
    Doc := TLandrixEInvoicePdfDocument.Create;
    try
      M := TMemoryStream.Create;
      try
        M.WriteBuffer(Pdf[1], Length(Pdf));
        M.Position := 0;
        Doc.Syntax := Facts;
        Check(Doc.Load(M, Err), 'Load: ' + Err);
      finally
        M.Free;
      end;
      Doc.Syntax := nil;
      Check(Doc.GetObject(3) <> nil, 'object 3 without receiver');
      Doc.Syntax := Facts;
      Facts.Inspect(Doc);
      Check(not Facts.Complete, 'detached: not complete');
      Check(Pos('not the receiver', Facts.Problems.Text) > 0, 'detached: ' + Facts.Problems.Text);
    finally
      Doc.Free;
    end;
  finally
    Facts.Free;
  end;
end;

procedure Register;
begin
  RegisterTest('PdfSyntax.Facts', TestFacts);
  RegisterTest('PdfSyntax.Violations', TestViolations);
  RegisterTest('PdfSyntax.Chain', TestChain);
  RegisterTest('PdfSyntax.ObjectStream', TestObjectStream);
  RegisterTest('PdfSyntax.StreamEnds', TestStreamEnds);
  RegisterTest('PdfSyntax.EnvelopeOffset', TestEnvelopeOffset);
  RegisterTest('PdfSyntax.TrailerAndStrings', TestTrailerAndStrings);
  RegisterTest('PdfSyntax.Hybrid', TestHybrid);
  RegisterTest('PdfSyntax.Recovery', TestRecovery);
  RegisterTest('PdfSyntax.InspectMisuse', TestInspectMisuse);
end;

end.
