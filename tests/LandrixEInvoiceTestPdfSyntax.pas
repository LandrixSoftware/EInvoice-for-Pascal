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
  Inspect. PdfA.* checks the rules of LandrixEInvoicePdfARules: a
  clean file, one with a violation of every implemented rule, and
  PdfA.VeraPdf compares the rules with the veraPDF results in
  tests/data/verapdf-expected.txt over the local corpora (tests/data/local/pdf
  and tests/data/local/verapdf; skipped without them): no rule may fail that
  veraPDF passes, and no rule may pass (a full rule on complete facts) that
  veraPDF fails. PdfA.Limits: a cycle of form fields ends at the node budget
  and leaves its rule incomplete. PdfA.Interactive: annotations, forms and
  actions (6.3 to 6.5) with the details of veraPDF's reading. PdfA.Files:
  embedded files, optional content, alternate presentations and requirements
  (6.8 to 6.11). PdfA.Metadata: the XMP packets (6.6.2.1, 6.6.4); PdfA.XmpReader:
  the XMP reader's valid, rejected and undecided forms. Accepted
  differences are listed in
  tests/data/pdfa-exceptions.txt (path, rule, reason). }

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
  LandrixEInvoicePdfARules,
  LandrixEInvoicePdfXmp,
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
          Result := Result + ':' + IntToStr(T.HexChars);
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
      CheckEqualsStr('int:2147483648 hex:3! hex:3 name:3/3!', TokensOf(Facts, 4), 'tokens of object 4');
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

{ The numbers of the failed rules, separated by spaces. }
function FailedRules(ARules: TLandrixEInvoicePdfARuleCheck): string;
var
  R: TLandrixEInvoicePdfARule;
begin
  Result := '';
  for R := Low(TLandrixEInvoicePdfARule) to High(TLandrixEInvoicePdfARule) do
    if ARules.RuleResult(R).Outcome = pro_Failed then
    begin
      if Result <> '' then
        Result := Result + ' ';
      Result := Result + LandrixEInvoicePdfARuleNumber(R);
    end;
end;

function Repeated(C: AnsiChar; ACount: Integer): AnsiString;
var
  I: Integer;
begin
  Result := '';
  SetLength(Result, ACount);
  for I := 1 to ACount do
    Result[I] := C;
end;

{ A metadata stream object ANum with the XMP AXml. }
function MetaObj(ANum: Integer; const AXml: AnsiString): AnsiString;
begin
  Result := IntToAnsi(ANum) + ' 0 obj' + LF + '<< /Type /Metadata /Subtype /XML /Length ' +
    IntToAnsi(Length(AXml)) + ' >>' + LF + 'stream' + LF + AXml + LF + 'endstream' + LF + 'endobj' + LF;
end;

const
  XmpHead = '<?xpacket begin='''' id=''W5M0MpCehiHzreSzNTczkc9d''?>' + LF +
    '<x:xmpmeta xmlns:x="adobe:ns:meta/"><rdf:RDF xmlns:rdf="http://www.w3.org/1999/02/22-rdf-syntax-ns#">' + LF;
  XmpTail = '</rdf:RDF></x:xmpmeta>' + LF + '<?xpacket end=''w''?>';
  XmpPdfA3B = '<rdf:Description rdf:about="" xmlns:pdfaid="http://www.aiim.org/pdfa/ns/id/">' +
    '<pdfaid:part>3</pdfaid:part><pdfaid:conformance>B</pdfaid:conformance></rdf:Description>' + LF;

procedure TestPdfAClean;
var
  Pdf: AnsiString;
  Facts: TLandrixEInvoicePdfSyntaxFacts;
  Doc: TLandrixEInvoicePdfDocument;
  Rules: TLandrixEInvoicePdfARuleCheck;
  R: TLandrixEInvoicePdfARule;
  Res: TLandrixEInvoicePdfARuleResult;
begin
  Pdf := BuildPdf(GoodHeader, ['1 0 obj' + LF + '<< /Type /Catalog /Pages 2 0 R /Metadata 20 0 R >>' + LF + 'endobj' + LF,
    Pages,
    '3 0 obj' + LF + '<< /Length 5 /Filter /Crypt >>' + LF + 'stream' + CR + LF + 'hello' + CR + LF + 'endstream' + LF +
    'endobj' + LF,
    MetaObj(20, XmpHead + XmpPdfA3B + XmpTail),
    MetaObj(21, XmpHead + '<rdf:Description rdf:about="" xmlns:dc="http://purl.org/dc/elements/1.1/" ' +
      'dc:format="application/pdf"/>' + LF + XmpTail),
    '22 0 obj' + LF + '<< /Metadata 21 0 R >>' + LF + 'endobj' + LF], LF, FileId, LF);
  Facts := TLandrixEInvoicePdfSyntaxFacts.Create;
  Rules := TLandrixEInvoicePdfARuleCheck.Create;
  try
    Doc := LoadWithFacts(Pdf, Facts);
    try
      Rules.Check(Doc, Facts);
      CheckEqualsStr('', FailedRules(Rules), 'failed rules');
      for R := Low(TLandrixEInvoicePdfARule) to High(TLandrixEInvoicePdfARule) do
      begin
        Res := Rules.RuleResult(R);
        case LandrixEInvoicePdfARuleCoverage(R) of
          prc_Full:
            Check(Res.Outcome = pro_Passed, LandrixEInvoicePdfARuleId(R) + ' passed');
          prc_Partial:
            Check(Res.Outcome = pro_Incomplete, LandrixEInvoicePdfARuleId(R) + ' incomplete');
          prc_None:
            Check(Res.Outcome = pro_NotChecked, LandrixEInvoicePdfARuleId(R) + ' not checked');
        end;
      end;
      CheckEqualsStr('PDFA-6.1.7.1-1', LandrixEInvoicePdfARuleId(par_6_1_7_1_1), 'rule ID');
      Check(not Rules.AnyFailed, 'nothing failed');
    finally
      Doc.Free;
    end;
  finally
    Rules.Free;
    Facts.Free;
  end;
end;

procedure TestPdfAViolations;
var
  Pdf: AnsiString;
  Facts: TLandrixEInvoicePdfSyntaxFacts;
  Doc: TLandrixEInvoicePdfDocument;
  Rules: TLandrixEInvoicePdfARuleCheck;
  Res: TLandrixEInvoicePdfARuleResult;
begin
  { header %PDF-1.8 without binary comment; 1: /Perms with another key and
    DocMDP, whose signature 9 has a digest in a reference; 2/5: a page with
    a 2 x 2 CropBox; 3: CR after stream, wrong /Length, /F, LZWDecode; 4:
    numbers, strings and names beyond the limits; object 6: two spaces
    after its number; 7: Crypt without parameters and a CR that /Length
    counts to the data (both allowed); 8: Crypt with another filter than
    Identity; xref followed by a space, no /ID, bytes after %%EOF. Not
    here: 6.1.3-2 (/Encrypt, the corpus has a case) and 6.1.13-7 (more than
    8388607 objects) }
  Pdf := BuildPdf('%PDF-1.8' + LF + '%abcd' + LF, [
    '1 0 obj' + LF + '<< /Type /Catalog /Pages 2 0 R /Perms << /DocMDP 9 0 R /Foo 1 >> >>' + LF + 'endobj' + LF,
    '2 0 obj' + LF + '<< /Type /Pages /Kids [5 0 R] /Count 1 /MediaBox [0 0 612 792] >>' + LF + 'endobj' + LF,
    '3 0 obj' + LF + '<< /Length 9 /F (x) /Filter /LZWDecode >>' + LF + 'stream' + CR + 'data' + LF + 'endstream' + LF +
      'endobj' + LF,
    '4 0 obj' + LF + '[ 2147483648 <414> <4G> 0.' + Repeated('0', 40) + '1 4' + Repeated('0', 39) + '.0 /' +
      Repeated('A', 128) + ' (' + Repeated('a', 32768) + ') ]' + LF + 'endobj' + LF,
    '5 0 obj' + LF + '<< /Type /Page /Parent 2 0 R /CropBox [0 0 2 2] >>' + LF + 'endobj' + LF,
    '6  0 obj' + LF + '<< >>' + LF + 'endobj' + LF,
    '7 0 obj' + LF + '<< /Length 4 /Filter /Crypt >>' + LF + 'stream' + LF + 'abc' + CR + LF + 'endstream' + LF + 'endobj' + LF,
    '8 0 obj' + LF + '<< /Length 4 /Filter [/FlateDecode /Crypt] /DecodeParms [null << /Name /Std >>] >>' + LF + 'stream' +
      LF + 'abcd' + LF + 'endstream' + LF + 'endobj' + LF,
    '9 0 obj' + LF + '<< /Type /Sig /Reference [ << /Type /SigRef /DigestMethod /MD5 >> ] >>' + LF + 'endobj' + LF],
    ' ' + LF, '', LF + 'junk');
  Facts := TLandrixEInvoicePdfSyntaxFacts.Create;
  Rules := TLandrixEInvoicePdfARuleCheck.Create;
  try
    Doc := LoadWithFacts(Pdf, Facts);
    try
      Check(Facts.Complete, 'complete: ' + Facts.Problems.Text);
      Rules.Check(Doc, Facts);
      CheckEqualsStr('6.1.2-1 6.1.2-2 6.1.3-1 6.1.3-3 6.1.4-2 6.1.6-1 6.1.6-2 6.1.7.1-1 6.1.7.1-2 6.1.7.1-3 6.1.7.2-1 6.1.9-1 ' +
        '6.1.12-1 6.1.12-2 6.1.13-1 6.1.13-2 6.1.13-3 6.1.13-4 6.1.13-5 6.1.13-11 6.6.2.1-1', FailedRules(Rules),
        'failed rules');
      Res := Rules.RuleResult(par_6_1_7_2_1);
      CheckEquals(2, Res.Failures, 'LZWDecode and Crypt with Std');
      CheckEquals(3, Res.ObjNum, 'first filter violation in object 3');
      Res := Rules.RuleResult(par_6_1_7_1_1);
      CheckEquals(1, Res.Failures, 'only stream 3 has a wrong /Length');
      Res := Rules.RuleResult(par_6_1_9_1);
      CheckEquals(6, Res.ObjNum, 'envelope of object 6');
      Res := Rules.RuleResult(par_6_1_6_1);
      CheckEquals(4, Res.ObjNum, 'odd hex string in object 4');
      Check(Rules.AnyFailed, 'failed');
    finally
      Doc.Free;
    end;
  finally
    Rules.Free;
    Facts.Free;
  end;
end;

{ Rule numbers of a line "rule rule ..."; '' for none. }
function HasRule(const AList, ARule: string): Boolean;
begin
  Result := Pos(' ' + ARule + ' ', ' ' + AList + ' ') > 0;
end;

procedure TestPdfALimits;
var
  Pdf: AnsiString;
  Facts: TLandrixEInvoicePdfSyntaxFacts;
  Doc: TLandrixEInvoicePdfDocument;
  Rules: TLandrixEInvoicePdfARuleCheck;
begin
  { field 10 lists itself twice as its kid: without a node budget the walk
    would take about 2^64 steps }
  Pdf := BuildPdf(GoodHeader, [
    '1 0 obj' + LF + '<< /Type /Catalog /Pages 2 0 R /Perms << /DocMDP 9 0 R >> /AcroForm << /Fields [10 0 R] >> >>' +
      LF + 'endobj' + LF, Pages,
    '9 0 obj' + LF + '<< /Type /Sig >>' + LF + 'endobj' + LF,
    '10 0 obj' + LF + '<< /FT /Sig /Kids [10 0 R 10 0 R] >>' + LF + 'endobj' + LF], LF, FileId, LF);
  Facts := TLandrixEInvoicePdfSyntaxFacts.Create;
  Rules := TLandrixEInvoicePdfARuleCheck.Create;
  try
    Doc := LoadWithFacts(Pdf, Facts);
    try
      Rules.Check(Doc, Facts);
      CheckEqualsStr('6.6.2.1-1', FailedRules(Rules), 'failed rules');
      Check(Rules.RuleResult(par_6_1_12_2).Outcome = pro_Incomplete, '6.1.12-2 incomplete at the node budget');
      Check(Rules.RuleResult(par_6_1_12_1).Outcome = pro_Passed, '6.1.12-1 passed');
    finally
      Doc.Free;
    end;
  finally
    Rules.Free;
    Facts.Free;
  end;
end;

procedure TestPdfAInteractive;
const
  Empty = 'stream' + #10 + #10 + 'endstream';
var
  Pdf: AnsiString;
  Facts: TLandrixEInvoicePdfSyntaxFacts;
  Doc: TLandrixEInvoicePdfDocument;
  Rules: TLandrixEInvoicePdfARuleCheck;
  Res: TLandrixEInvoicePdfARuleResult;
begin
  { catalog: NeedAppearances true (6.4.1-3), NeedsRendering false (allowed),
    a JavaScript /OpenAction (6.5.1-1); page 3 with /AA (6.5.2-2);
    4: Link with /F 4.9 (read as 4) whose URI action chains a named action
    Print (6.5.1-2); 5: Square with /F 6, Hidden (6.3.2-2); 6: Text whose N
    appearance is a subdictionary (6.3.3-4); 7: widget of the button field
    20 (/FT inherited over /Parent) with an N stream (6.3.3-3); 8: Popup
    without /F and appearance (allowed); 9: Ink with an empty rectangle and
    no appearance (allowed); 10: Circle; widget 7 has /AA null (counts as
    absent); 20: field with /AA (6.4.1-2), its kid 7 has /AA null and no /T
    (no field), its kid 21 has /AA and no /T (no field either) }
  Pdf := BuildPdf(GoodHeader, [
    '1 0 obj' + LF + '<< /Type /Catalog /Pages 2 0 R /AcroForm << /Fields [20 0 R] /NeedAppearances true >> ' +
      '/NeedsRendering false /OpenAction << /S /JavaScript /JS (x) >> >>' + LF + 'endobj' + LF,
    '2 0 obj' + LF + '<< /Type /Pages /Kids [3 0 R] /Count 1 >>' + LF + 'endobj' + LF,
    '3 0 obj' + LF + '<< /Type /Page /Parent 2 0 R /MediaBox [0 0 612 792] /Annots [4 0 R 5 0 R 6 0 R 7 0 R 8 0 R ' +
      '9 0 R 10 0 R] /AA << /O << /S /GoTo /D [3 0 R /Fit] >> >> >>' + LF + 'endobj' + LF,
    '4 0 obj' + LF + '<< /Type /Annot /Subtype /Link /F 4.9 /Rect [0 0 10 10] /A << /S /URI /URI (x) ' +
      '/Next [ << /S /Named /N /Print >> ] >> >>' + LF + 'endobj' + LF,
    '5 0 obj' + LF + '<< /Type /Annot /Subtype /Square /F 6 /Rect [0 0 10 10] /AP << /N 13 0 R >> >>' + LF +
      'endobj' + LF,
    '6 0 obj' + LF + '<< /Type /Annot /Subtype /Text /F 4 /Rect [0 0 10 10] /AP << /N << /On 13 0 R >> >> >>' + LF +
      'endobj' + LF,
    '7 0 obj' + LF + '<< /Type /Annot /Subtype /Widget /F 4 /AA null /Parent 20 0 R /Rect [0 0 10 10] ' +
      '/AP << /N 13 0 R >> >>' + LF + 'endobj' + LF,
    '8 0 obj' + LF + '<< /Type /Annot /Subtype /Popup /Rect [0 0 10 10] >>' + LF + 'endobj' + LF,
    '9 0 obj' + LF + '<< /Type /Annot /Subtype /Ink /F 4 /Rect [10 10 10 10] >>' + LF + 'endobj' + LF,
    '10 0 obj' + LF + '<< /Type /Annot /Subtype /Circle /F 4 /Rect [0 0 10 10] /AP << /N 13 0 R >> >>' + LF +
      'endobj' + LF,
    '13 0 obj' + LF + '<< /Length 0 >>' + LF + Empty + LF + 'endobj' + LF,
    '20 0 obj' + LF + '<< /FT /Btn /T (f) /Kids [7 0 R 21 0 R] /AA << /K << /S /GoTo /D [3 0 R /Fit] >> >> >>' + LF +
      'endobj' + LF,
    '21 0 obj' + LF + '<< /AA << /K << /S /GoTo /D [3 0 R /Fit] >> >> >>' + LF + 'endobj' + LF], LF, FileId, LF);
  Facts := TLandrixEInvoicePdfSyntaxFacts.Create;
  Rules := TLandrixEInvoicePdfARuleCheck.Create;
  try
    Doc := LoadWithFacts(Pdf, Facts);
    try
      Check(Facts.Complete, 'complete: ' + Facts.Problems.Text);
      Rules.Check(Doc, Facts);
      CheckEqualsStr('6.3.2-2 6.3.3-3 6.3.3-4 6.4.1-2 6.4.1-3 6.5.1-1 6.5.1-2 6.5.2-2 6.6.2.1-1', FailedRules(Rules),
        'failed rules');
      Res := Rules.RuleResult(par_6_3_2_2);
      CheckEquals(5, Res.ObjNum, 'flags of object 5');
      Res := Rules.RuleResult(par_6_3_3_3);
      CheckEquals(7, Res.ObjNum, 'button widget 7');
      Res := Rules.RuleResult(par_6_5_1_2);
      CheckEquals(4, Res.ObjNum, 'named action in the chain of object 4');
      Check(Rules.RuleResult(par_6_3_2_1).Outcome = pro_Passed, '6.3.2-1 passed (Popup, /F 4.9)');
      Check(Rules.RuleResult(par_6_3_3_1).Outcome = pro_Passed, '6.3.3-1 passed (Link, Popup, empty rectangle)');
      Check(Rules.RuleResult(par_6_4_2_2).Outcome = pro_Passed, '6.4.2-2 passed (NeedsRendering false)');
      Check(Rules.RuleResult(par_6_4_1_1).Outcome = pro_Passed, '6.4.1-1 passed (/AA null of widget 7 is absent)');
      CheckEquals(1, Rules.RuleResult(par_6_4_1_2).Failures, '6.4.1-2 only for field 20, not for kids without /T');
      Check(Rules.RuleResult(par_6_4_3_1).Outcome = pro_NotChecked, '6.4.3-1 not checked');
    finally
      Doc.Free;
    end;
  finally
    Rules.Free;
    Facts.Free;
  end;
end;

procedure TestPdfAInteractive2;
var
  Pdf: AnsiString;
  Facts: TLandrixEInvoicePdfSyntaxFacts;
  Doc: TLandrixEInvoicePdfDocument;
  Rules: TLandrixEInvoicePdfARuleCheck;
begin
  { catalog: /AA with a JavaScript action under WC (6.5.2-1, 6.5.1-1),
    NeedsRendering true (6.4.2-2), /XFA (6.4.2-1), an outline item whose
    action is Launch with a /Next dictionary chaining a named action Quit
    (6.5.1-1, 6.5.1-2); 4: Movie (6.3.1-1); 5: Square without appearance
    (6.3.3-1); 6: Text whose /AP has N and D (6.3.3-2); 7: widget with /A
    (6.4.1-1); 8: Link whose /A is a stream, which is no action }
  Pdf := BuildPdf(GoodHeader, [
    '1 0 obj' + LF + '<< /Type /Catalog /Pages 2 0 R /NeedsRendering true /AcroForm << /Fields [] /XFA 9 0 R >> ' +
      '/AA << /WC << /S /JavaScript /JS (x) >> >> /Outlines 10 0 R >>' + LF + 'endobj' + LF,
    '2 0 obj' + LF + '<< /Type /Pages /Kids [3 0 R] /Count 1 >>' + LF + 'endobj' + LF,
    '3 0 obj' + LF + '<< /Type /Page /Parent 2 0 R /MediaBox [0 0 612 792] /Annots [4 0 R 5 0 R 6 0 R 7 0 R 8 0 R] >>' +
      LF + 'endobj' + LF,
    '4 0 obj' + LF + '<< /Type /Annot /Subtype /Movie /F 4 /Rect [0 0 10 10] /AP << /N 13 0 R >> >>' + LF + 'endobj' +
      LF,
    '5 0 obj' + LF + '<< /Type /Annot /Subtype /Square /F 4 /Rect [0 0 10 10] >>' + LF + 'endobj' + LF,
    '6 0 obj' + LF + '<< /Type /Annot /Subtype /Text /F 4 /Rect [0 0 10 10] /AP << /N 13 0 R /D 13 0 R >> >>' + LF +
      'endobj' + LF,
    '7 0 obj' + LF + '<< /Type /Annot /Subtype /Widget /FT /Tx /F 4 /Rect [0 0 10 10] /A << /S /URI /URI (x) >> ' +
      '/AP << /N 13 0 R >> >>' + LF + 'endobj' + LF,
    '8 0 obj' + LF + '<< /Type /Annot /Subtype /Link /F 4 /Rect [0 0 10 10] /A 14 0 R >>' + LF + 'endobj' + LF,
    '9 0 obj' + LF + '<< /Length 0 >>' + LF + 'stream' + LF + LF + 'endstream' + LF + 'endobj' + LF,
    '10 0 obj' + LF + '<< /Type /Outlines /First 11 0 R /Last 11 0 R /Count 1 >>' + LF + 'endobj' + LF,
    '11 0 obj' + LF + '<< /Title (a) /Parent 10 0 R /A << /S /Launch /F (x) /Next << /S /Named /N /Quit >> >> >>' +
      LF + 'endobj' + LF,
    '13 0 obj' + LF + '<< /Length 0 >>' + LF + 'stream' + LF + LF + 'endstream' + LF + 'endobj' + LF,
    '14 0 obj' + LF + '<< /S /JavaScript /JS (x) /Length 0 >>' + LF + 'stream' + LF + LF + 'endstream' + LF + 'endobj' +
      LF], LF, FileId, LF);
  Facts := TLandrixEInvoicePdfSyntaxFacts.Create;
  Rules := TLandrixEInvoicePdfARuleCheck.Create;
  try
    Doc := LoadWithFacts(Pdf, Facts);
    try
      Check(Facts.Complete, 'complete: ' + Facts.Problems.Text);
      Rules.Check(Doc, Facts);
      CheckEqualsStr('6.3.1-1 6.3.3-1 6.3.3-2 6.4.1-1 6.4.2-1 6.4.2-2 6.5.1-1 6.5.1-2 6.5.2-1 6.6.2.1-1',
        FailedRules(Rules),
        'failed rules');
      CheckEquals(2, Rules.RuleResult(par_6_5_1_1).Failures, 'JavaScript under WC and Launch in the outline only');
      CheckEquals(11, Rules.RuleResult(par_6_5_1_2).ObjNum, 'named action Quit in the /Next of outline item 11');
    finally
      Doc.Free;
    end;
  finally
    Rules.Free;
    Facts.Free;
  end;
end;

procedure TestPdfAFiles;
var
  Pdf: AnsiString;
  Facts: TLandrixEInvoicePdfSyntaxFacts;
  Doc: TLandrixEInvoicePdfDocument;
  Rules: TLandrixEInvoicePdfARuleCheck;
begin
  { catalog: /Requirements [] (6.11-1); /AlternatePresentations in the name
    dictionary (6.10-1); configurations: /D "cfg" whose /Order misses group
    21 (6.9-3), "cfg" again in UTF-16 with /AS (6.9-2, 6.9-4), an empty name
    (6.9-1); page 3 with /PresSteps (6.10-2) and a direct file specification
    (6.8-4); 10: associated file specification, fine; 11: name tree value
    without /Type, no /UF and /AFRelationship, in no /AF array (6.8-2, 6.8-3,
    6.8-4), its stream 13 under F and UF has /Subtype /text (6.8-1 twice) }
  Pdf := BuildPdf(GoodHeader, [
    '1 0 obj' + LF + '<< /Type /Catalog /Pages 2 0 R /AF [10 0 R] /Requirements [] /Names << /EmbeddedFiles << ' +
      '/Names [(a) 10 0 R (b) 11 0 R] >> /AlternatePresentations << >> >> /OCProperties << /OCGs [20 0 R 21 0 R] ' +
      '/D << /Name (cfg) /Order [20 0 R] >> /Configs [<< /Name <FEFF006300660067> /AS [] >> << /Name () >>] >> >>' + LF +
      'endobj' + LF,
    '2 0 obj' + LF + '<< /Type /Pages /Kids [3 0 R] /Count 1 >>' + LF + 'endobj' + LF,
    '3 0 obj' + LF + '<< /Type /Page /Parent 2 0 R /MediaBox [0 0 612 792] /PresSteps << >> ' +
      '/X << /Type /Filespec /F (c) /UF (c) /AFRelationship /Data >> >>' + LF + 'endobj' + LF,
    '10 0 obj' + LF + '<< /Type /Filespec /F (a.xml) /UF (a.xml) /AFRelationship /Data /EF << /F 12 0 R >> >>' + LF +
      'endobj' + LF,
    '11 0 obj' + LF + '<< /F (b) /EF << /F 13 0 R /UF 13 0 R >> >>' + LF + 'endobj' + LF,
    '12 0 obj' + LF + '<< /Type /EmbeddedFile /Subtype /application#2Fxml /Length 0 >>' + LF + 'stream' + LF + LF +
      'endstream' + LF + 'endobj' + LF,
    '13 0 obj' + LF + '<< /Type /EmbeddedFile /Subtype /text /Length 0 >>' + LF + 'stream' + LF + LF + 'endstream' + LF +
      'endobj' + LF,
    '20 0 obj' + LF + '<< /Type /OCG /Name (g1) >>' + LF + 'endobj' + LF,
    '21 0 obj' + LF + '<< /Type /OCG /Name (g2) >>' + LF + 'endobj' + LF], LF, FileId, LF);
  Facts := TLandrixEInvoicePdfSyntaxFacts.Create;
  Rules := TLandrixEInvoicePdfARuleCheck.Create;
  try
    Doc := LoadWithFacts(Pdf, Facts);
    try
      Check(Facts.Complete, 'complete: ' + Facts.Problems.Text);
      Rules.Check(Doc, Facts);
      CheckEqualsStr('6.6.2.1-1 6.8-1 6.8-2 6.8-3 6.8-4 6.9-1 6.9-2 6.9-3 6.9-4 6.10-1 6.10-2 6.11-1', FailedRules(Rules),
        'failed rules');
      CheckEquals(2, Rules.RuleResult(par_6_8_1).Failures, 'stream 13 under F and UF');
      CheckEquals(11, Rules.RuleResult(par_6_8_1).ObjNum, 'file specification 11');
      CheckEquals(1, Rules.RuleResult(par_6_8_3).Failures, 'only file specification 11 lacks /AFRelationship');
      CheckEquals(2, Rules.RuleResult(par_6_8_4).Failures, 'file specification 11 and the direct one');
      CheckEquals(1, Rules.RuleResult(par_6_9_2).Failures, '/D never fails, its UTF-16 twin does');
      CheckEquals(3, Rules.RuleResult(par_6_10_2).ObjNum, 'page 3');
    finally
      Doc.Free;
    end;
  finally
    Rules.Free;
    Facts.Free;
  end;

  { the same rules met: an /Order with a label and a nested array, /AS null,
    /Requirements without /S, /PresSteps null; file specification 11 is
    named only in a /Properties array, so marked content may associate it }
  Pdf := BuildPdf(GoodHeader, [
    '1 0 obj' + LF + '<< /Type /Catalog /Pages 2 0 R /AF [10 0 R] /Requirements << >> /Names << /EmbeddedFiles << ' +
      '/Names [(a) 10 0 R] >> >> /OCProperties << /OCGs [20 0 R] /D << /Name (cfg) /Order [(label) [20 0 R]] >> ' +
      '/Configs [<< /Name (other) /AS null >>] >> >>' + LF + 'endobj' + LF,
    '2 0 obj' + LF + '<< /Type /Pages /Kids [3 0 R] /Count 1 >>' + LF + 'endobj' + LF,
    '3 0 obj' + LF + '<< /Type /Page /Parent 2 0 R /MediaBox [0 0 612 792] /PresSteps null ' +
      '/Resources << /Properties << /MC0 [11 0 R] >> >> >>' + LF + 'endobj' + LF,
    '10 0 obj' + LF + '<< /Type /Filespec /F (a.xml) /UF (a.xml) /AFRelationship /Data /EF << /F 12 0 R /UF 12 0 R >> >>' +
      LF + 'endobj' + LF,
    '11 0 obj' + LF + '<< /Type /Filespec /F (m) /UF (m) /AFRelationship /Data >>' + LF + 'endobj' + LF,
    '12 0 obj' + LF + '<< /Type /EmbeddedFile /Subtype /application#2Fxml /Length 0 >>' + LF + 'stream' + LF + LF +
      'endstream' + LF + 'endobj' + LF,
    '20 0 obj' + LF + '<< /Type /OCG /Name (g1) >>' + LF + 'endobj' + LF], LF, FileId, LF);
  Facts := TLandrixEInvoicePdfSyntaxFacts.Create;
  Rules := TLandrixEInvoicePdfARuleCheck.Create;
  try
    Doc := LoadWithFacts(Pdf, Facts);
    try
      Check(Facts.Complete, 'complete: ' + Facts.Problems.Text);
      Rules.Check(Doc, Facts);
      CheckEqualsStr('6.6.2.1-1', FailedRules(Rules), 'failed rules');
      Check(Rules.RuleResult(par_6_8_1).Outcome = pro_Passed, '6.8-1 passed');
      Check(Rules.RuleResult(par_6_8_4).Outcome = pro_Incomplete, '6.8-4 incomplete (partial)');
      Check(Rules.RuleResult(par_6_9_3).Outcome = pro_Passed, '6.9-3 passed (label, nested array)');
      Check(Rules.RuleResult(par_6_9_4).Outcome = pro_Passed, '6.9-4 passed (/AS null)');
      Check(Rules.RuleResult(par_6_10_2).Outcome = pro_Passed, '6.10-2 passed (/PresSteps null)');
      Check(Rules.RuleResult(par_6_11_1).Outcome = pro_Passed, '6.11-1 passed (no /S)');
    finally
      Doc.Free;
    end;
  finally
    Rules.Free;
    Facts.Free;
  end;

  { limits and decoding: the EmbeddedFiles name tree 5 is its own kid, so
    the unassociated file specification 10 is no proven failure of 6.8-4;
    /D's /Order 30 contains itself (incomplete, no failure); group 20 has no
    name, and an /Order entry without a string name removes nothing (6.9-3
    once, in the first of /Configs); <FEFFD8000041> is a high surrogate
    without its low one, which Java decodes with the next unit as one U+FFFD,
    equal to <FEFFFFFD> (6.9-2) }
  Pdf := BuildPdf(GoodHeader, [
    '1 0 obj' + LF + '<< /Type /Catalog /Pages 2 0 R /Names << /EmbeddedFiles 5 0 R >> /OCProperties << ' +
      '/OCGs [20 0 R] /D << /Name (cfg) /Order 30 0 R >> /Configs [<< /Name <FEFFD8000041> /Order [20 0 R] >> ' +
      '<< /Name <FEFFFFFD> >>] >> >>' + LF + 'endobj' + LF,
    '2 0 obj' + LF + '<< /Type /Pages /Kids [3 0 R] /Count 1 >>' + LF + 'endobj' + LF,
    '3 0 obj' + LF + '<< /Type /Page /Parent 2 0 R /MediaBox [0 0 612 792] >>' + LF + 'endobj' + LF,
    '5 0 obj' + LF + '<< /Kids [5 0 R] >>' + LF + 'endobj' + LF,
    '10 0 obj' + LF + '<< /Type /Filespec /F (a) /UF (a) /AFRelationship /Data >>' + LF + 'endobj' + LF,
    '20 0 obj' + LF + '<< /Type /OCG >>' + LF + 'endobj' + LF,
    '30 0 obj' + LF + '[30 0 R]' + LF + 'endobj' + LF], LF, FileId, LF);
  Facts := TLandrixEInvoicePdfSyntaxFacts.Create;
  Rules := TLandrixEInvoicePdfARuleCheck.Create;
  try
    Doc := LoadWithFacts(Pdf, Facts);
    try
      Check(Facts.Complete, 'complete: ' + Facts.Problems.Text);
      Rules.Check(Doc, Facts);
      CheckEqualsStr('6.6.2.1-1 6.9-2 6.9-3', FailedRules(Rules), 'failed rules');
      Check(Rules.RuleResult(par_6_8_1).Outcome = pro_Incomplete, '6.8-1 incomplete (name tree cycle)');
      CheckEquals(1, Rules.RuleResult(par_6_9_3).Failures, 'the /Order cycle of /D is no failure');
    finally
      Doc.Free;
    end;
  finally
    Rules.Free;
    Facts.Free;
  end;
end;

{ AText as UTF-16LE with byte order mark (ASCII only). }
function Utf16Le(const AText: AnsiString): AnsiString;
var
  I: Integer;
begin
  Result := AnsiChar(255) + AnsiChar(254);
  for I := 1 to Length(AText) do
    Result := Result + AText[I] + AnsiChar(0);
end;

procedure TestPdfAMetadata;
var
  Pdf: AnsiString;
  Facts: TLandrixEInvoicePdfSyntaxFacts;
  Doc: TLandrixEInvoicePdfDocument;
  Rules: TLandrixEInvoicePdfARuleCheck;
begin
  { main packet 20: a header with bytes and encoding (6.6.2.1-2/-3);
    pdfaid:part "+03" (Java reads 3) under the prefix foo (6.6.4-4) in an
    attribute; conformance as rdf:Alt (6.6.4-3); further packet 21, named
    by the page, with dc:format twice (rejected: 6.6.2.1-4/-5) }
  Pdf := BuildPdf(GoodHeader, [
    '1 0 obj' + LF + '<< /Type /Catalog /Pages 2 0 R /Metadata 20 0 R >>' + LF + 'endobj' + LF,
    '2 0 obj' + LF + '<< /Type /Pages /Kids [3 0 R] /Count 1 >>' + LF + 'endobj' + LF,
    '3 0 obj' + LF + '<< /Type /Page /Parent 2 0 R /MediaBox [0 0 612 792] /Metadata 21 0 R >>' + LF + 'endobj' + LF,
    MetaObj(20, '<?xpacket begin='''' bytes=''10'' encoding="UTF-8"?>' + LF +
      '<x:xmpmeta xmlns:x="adobe:ns:meta/"><rdf:RDF xmlns:rdf="http://www.w3.org/1999/02/22-rdf-syntax-ns#">' + LF +
      '<rdf:Description rdf:about="" xmlns:foo="http://www.aiim.org/pdfa/ns/id/" foo:part="+03"/>' + LF +
      '<rdf:Description rdf:about="" xmlns:pdfaid="http://www.aiim.org/pdfa/ns/id/"><pdfaid:conformance><rdf:Alt>' +
      '<rdf:li xml:lang="x-default">B</rdf:li></rdf:Alt></pdfaid:conformance><pdfaid:amd>2005</pdfaid:amd>' +
      '</rdf:Description>' + LF + XmpTail),
    MetaObj(21, XmpHead + '<rdf:Description rdf:about="" xmlns:dc="http://purl.org/dc/elements/1.1/">' +
      '<dc:format>a</dc:format></rdf:Description><rdf:Description rdf:about="" ' +
      'xmlns:dc="http://purl.org/dc/elements/1.1/"><dc:format>a</dc:format></rdf:Description>' + LF + XmpTail)],
    LF, FileId, LF);
  Facts := TLandrixEInvoicePdfSyntaxFacts.Create;
  Rules := TLandrixEInvoicePdfARuleCheck.Create;
  try
    Doc := LoadWithFacts(Pdf, Facts);
    try
      Check(Facts.Complete, 'complete: ' + Facts.Problems.Text);
      Rules.Check(Doc, Facts);
      CheckEqualsStr('6.6.2.1-2 6.6.2.1-3 6.6.2.1-4 6.6.2.1-5 6.6.4-3 6.6.4-4', FailedRules(Rules), 'failed rules');
      CheckEquals(20, Rules.RuleResult(par_6_6_2_1_2).ObjNum, 'header of the main packet');
      CheckEquals(21, Rules.RuleResult(par_6_6_2_1_4).ObjNum, 'duplicate property in the further packet');
      Check(Rules.RuleResult(par_6_6_4_2).Outcome = pro_Passed, '6.6.4-2 passed (+03)');
      Check(Rules.RuleResult(par_6_6_4_6).Outcome = pro_Passed, '6.6.4-6 passed (pdfaid:amd)');
    finally
      Doc.Free;
    end;
  finally
    Rules.Free;
    Facts.Free;
  end;

  { main packet without rdf:RDF: valid, but no encoding and no
    identification (6.6.2.1-5, 6.6.4-1); further packet 21 in UTF-16LE
    (6.6.2.1-5), named by an unreferenced dictionary }
  Pdf := BuildPdf(GoodHeader, [
    '1 0 obj' + LF + '<< /Type /Catalog /Pages 2 0 R /Metadata 20 0 R >>' + LF + 'endobj' + LF, Pages,
    MetaObj(20, '<?xpacket begin='''' bytes=''1''?><foo/>'),
    MetaObj(21, Utf16Le(XmpHead + XmpPdfA3B + XmpTail)),
    '22 0 obj' + LF + '<< /Metadata 21 0 R >>' + LF + 'endobj' + LF], LF, FileId, LF);
  Facts := TLandrixEInvoicePdfSyntaxFacts.Create;
  Rules := TLandrixEInvoicePdfARuleCheck.Create;
  try
    Doc := LoadWithFacts(Pdf, Facts);
    try
      Check(Facts.Complete, 'complete: ' + Facts.Problems.Text);
      Rules.Check(Doc, Facts);
      CheckEqualsStr('6.6.2.1-5 6.6.4-1', FailedRules(Rules), 'failed rules');
      CheckEquals(2, Rules.RuleResult(par_6_6_2_1_5).Failures, 'no RDF and UTF-16LE');
      Check(Rules.RuleResult(par_6_6_2_1_2).Outcome = pro_Passed, '6.6.2.1-2 passed (no RDF, no header)');
    finally
      Doc.Free;
    end;
  finally
    Rules.Free;
    Facts.Free;
  end;

  { the catalog's metadata stream has the wrong /Subtype (6.6.2.1-1): the
    further packet is then not judged, and the main one not read }
  Pdf := BuildPdf(GoodHeader, [
    '1 0 obj' + LF + '<< /Type /Catalog /Pages 2 0 R /Metadata 20 0 R >>' + LF + 'endobj' + LF, Pages,
    '20 0 obj' + LF + '<< /Type /Metadata /Subtype /Foo /Length 0 >>' + LF + 'stream' + LF + LF + 'endstream' + LF +
      'endobj' + LF,
    MetaObj(21, '<?xpacket begin='''' bytes=''1'' id=''W5M0MpCehiHzreSzNTczkc9d''?>' + LF +
      '<x:xmpmeta xmlns:x="adobe:ns:meta/"><rdf:RDF xmlns:rdf="http://www.w3.org/1999/02/22-rdf-syntax-ns#">' + LF +
      XmpTail),
    '22 0 obj' + LF + '<< /Metadata 21 0 R >>' + LF + 'endobj' + LF], LF, FileId, LF);
  Facts := TLandrixEInvoicePdfSyntaxFacts.Create;
  Rules := TLandrixEInvoicePdfARuleCheck.Create;
  try
    Doc := LoadWithFacts(Pdf, Facts);
    try
      Check(Facts.Complete, 'complete: ' + Facts.Problems.Text);
      Rules.Check(Doc, Facts);
      CheckEqualsStr('6.6.2.1-1', FailedRules(Rules), 'failed rules');
      Check(Rules.RuleResult(par_6_6_2_1_2).Outcome = pro_Incomplete, '6.6.2.1-2 incomplete');
      Check(Rules.RuleResult(par_6_6_4_1).Outcome = pro_Passed, '6.6.4-1 not judged without a main packet');
    finally
      Doc.Free;
    end;
  finally
    Rules.Free;
    Facts.Free;
  end;
end;

{ The state of an XMP packet read from AText. }
function XmpState(APacket: TLandrixEInvoiceXmpPacket; const AText: AnsiString): TLandrixEInvoiceXmpState;
var
  B: TLandrixEInvoicePdfBytes;
  I: Integer;
begin
  B := nil;
  SetLength(B, Length(AText));
  for I := 1 to Length(AText) do
    B[I - 1] := Ord(AText[I]);
  APacket.Parse(B);
  Result := APacket.State;
end;

{ An XMP packet with ABody in its rdf:RDF. }
function XmpOf(const ABody: AnsiString): AnsiString;
begin
  Result := '<x:xmpmeta xmlns:x="adobe:ns:meta/"><rdf:RDF xmlns:rdf="http://www.w3.org/1999/02/22-rdf-syntax-ns#">' +
    ABody + '</rdf:RDF></x:xmpmeta>';
end;

{ An rdf:Description with the namespace q (urn:q) holding ABody. }
function XmpDesc(const ABody: AnsiString): AnsiString;
begin
  Result := XmpOf('<rdf:Description rdf:about="" xmlns:q="urn:q" xmlns:a="urn:q">' + ABody + '</rdf:Description>');
end;

{ AText as UTF-16BE with byte order mark (ASCII only). }
function Utf16Be(const AText: AnsiString): AnsiString;
var
  I: Integer;
begin
  Result := AnsiChar(254) + AnsiChar(255);
  for I := 1 to Length(AText) do
    Result := Result + AnsiChar(0) + AText[I];
end;

procedure TestPdfAXmpReader;
var
  P: TLandrixEInvoiceXmpPacket;
  N: TLandrixEInvoiceXmpNode;
begin
  P := TLandrixEInvoiceXmpPacket.Create;
  try
    { a qualified value: rdf:value is the value, the other field a qualifier }
    Check(XmpState(P, XmpDesc('<q:prop rdf:parseType="Resource"><rdf:value>hi</rdf:value><q:qual>two</q:qual>' +
      '</q:prop>')) = xms_Valid, 'qualified value: ' + P.Reason);
    N := P.Find('urn:q', 'prop');
    Check((N <> nil) and (N.Kind = xmk_Simple) and (N.Value = 'hi') and (N.QualifierCount = 1), 'qualified value read');
    { a qualifier attribute keeps its written name, a field moved to a
      qualifier gets the registry's prefix: attribute and field of the same
      name are not decided; the same written attribute twice is rejected }
    Check(XmpState(P, XmpDesc('<q:prop rdf:parseType="Resource"><rdf:value rdf:value="hi" a:qual="one"/>' +
      '<a:qual>two</a:qual></q:prop>')) = xms_Unknown, 'attribute and field qualifier');
    Check(XmpState(P, XmpDesc('<q:prop rdf:parseType="Resource"><rdf:value rdf:value="hi" q:qual="one"/>' +
      '<q:qual>two</q:qual></q:prop>')) = xms_Unknown, 'attribute and field of the same written name');
    Check(XmpState(P, XmpDesc('<q:prop rdf:parseType="Resource"><rdf:value xmlns:q="urn:other" rdf:value="hi" ' +
      'q:qual="one"/><a:qual>two</a:qual></q:prop>')) = xms_Unknown, 'field named by the registry prefix');
    Check(XmpState(P, XmpDesc('<q:prop><q:Thing><rdf:value rdf:parseType="Resource"><rdf:value>hi</rdf:value>' +
      '<rdf:type xmlns:rdf="urn:q">x</rdf:type></rdf:value></q:Thing></q:prop>')) = xms_Unknown,
      'field moved up through a nested value');
    { the same two with other local names }
    Check(XmpState(P, XmpDesc('<q:prop rdf:parseType="Resource"><rdf:value xmlns:q="urn:other" rdf:value="hi" ' +
      'q:qual="one"/><a:other>two</a:other></q:prop>')) = xms_Valid, 'other local name: ' + P.Reason);
    Check(XmpState(P, XmpDesc('<q:prop><q:Thing><rdf:value rdf:parseType="Resource"><rdf:value>hi</rdf:value>' +
      '<rdf:other xmlns:rdf="urn:q">x</rdf:other></rdf:value></q:Thing></q:prop>')) = xms_Valid,
      'other local name, nested: ' + P.Reason);
    Check(XmpState(P, XmpDesc('<q:prop rdf:parseType="Resource"><rdf:value rdf:value="hi" xml:lang="de"/>' +
      '<q:qual>two</q:qual></q:prop>')) = xms_Valid, 'attribute and field qualifiers: ' + P.Reason);
    Check(XmpState(P, XmpDesc('<q:prop rdf:parseType="Resource" xml:lang="de"><rdf:value xml:lang="de">x</rdf:value>' +
      '</q:prop>')) = xms_Invalid, 'xml:lang on a qualified property and its value');
    { an array and a structure }
    Check(XmpState(P, XmpDesc('<q:arr><rdf:Seq><rdf:li>a</rdf:li><rdf:li>b</rdf:li></rdf:Seq></q:arr>' +
      '<q:st><rdf:Description><q:f>1</q:f></rdf:Description></q:st>')) = xms_Valid, 'array and structure');
    N := P.Find('urn:q', 'arr');
    Check((N <> nil) and (N.Kind = xmk_Array) and (N.ArrayForm = xma_Seq) and (N.ChildCount = 2), 'Seq of two');
    N := P.Find('urn:q', 'st');
    Check((N <> nil) and (N.Kind = xmk_Struct) and (N.ChildCount = 1), 'structure of one field');
    { forms the parser rejects }
    Check(XmpState(P, XmpDesc('<q:p rdf:parseType="Literal">x</q:p>')) = xms_Invalid, 'parseType Literal');
    Check(XmpState(P, XmpDesc('<rdf:li>x</rdf:li>')) = xms_Invalid, 'top-level rdf:li');
    Check(XmpState(P, XmpDesc('<q:p><![CDATA[3]]></q:p>')) = xms_Invalid, 'CDATA');
    Check(XmpState(P, XmpDesc('<q:p rdf:resource="x"> </q:p>')) = xms_Invalid, 'rdf:resource with content');
    Check(XmpState(P, XmpOf('<q:Thing xmlns:q="urn:q"/>')) = xms_Invalid, 'top-level typed node');
    Check(XmpState(P, XmpOf('<rdf:Description rdf:about="a"/><rdf:Description rdf:about="b"/>')) = xms_Invalid,
      'different rdf:about');
    { not decided here }
    Check(XmpState(P, XmpOf('<rdf:Description rdf:about="a"/><rdf:Description rdf:about=""/>')) = xms_Unknown,
      'empty rdf:about after a non-empty one');
    Check(XmpState(P, '<!DOCTYPE x>' + XmpDesc('')) = xms_Unknown, 'document type');
    Check(XmpState(P, '<x:xmpmeta xmlns:x="adobe:ns:meta/" xmlns:rdf="http://www.w3.org/1999/02/22-rdf-syntax-ns#">' +
      '<rdf:RDF><rdf:Description/></rdf:RDF></x:xmpmeta>') = xms_Unknown, 'rdf:RDF without attributes');
    Check(XmpState(P, XmpDesc('<q:p>' + AnsiChar($C3) + '</q:p>')) = xms_Unknown, 'bytes that are no UTF-8');
    { encodings }
    Check(XmpState(P, '<?xml version="1.0" encoding="ISO-8859-1"?>' + XmpDesc('<q:p>x</q:p>')) = xms_Valid,
      'ISO-8859-1 declaration: ' + P.Reason);
    CheckEqualsStr('UTF-8', P.Encoding, 'reported as UTF-8');
    Check(XmpState(P, Utf16Be(XmpDesc('<q:p>x</q:p>'))) = xms_Valid, 'UTF-16BE: ' + P.Reason);
    CheckEqualsStr('UTF-16BE', P.Encoding, 'UTF-16BE');
    { the root search: an x:xmpmeta without RDF ends it; the last xpacket wins }
    Check(XmpState(P, '<o><x:xmpmeta xmlns:x="adobe:ns:meta/"/>' + XmpDesc('') + '</o>') = xms_Valid, 'wrapper first');
    Check(not P.HasRoot, 'no RDF behind an empty x:xmpmeta');
    Check(XmpState(P, '<?xpacket a?><?xpacket b?>' + XmpDesc('')) = xms_Valid, 'two headers');
    CheckEqualsStr('b', string(P.Header), 'the last header');
  finally
    P.Free;
  end;
end;

procedure TestPdfAVeraPdf;
var
  Expected, Exceptions, Used: TStringList;
  Local, Line, Path, ExpectedRules, FileName, Key: string;
  M: TMemoryStream;
  Facts: TLandrixEInvoicePdfSyntaxFacts;
  Doc: TLandrixEInvoicePdfDocument;
  Rules: TLandrixEInvoicePdfARuleCheck;
  R: TLandrixEInvoicePdfARule;
  Failed: Boolean;
  I, J, Files, Incomplete, Agree: Integer;
  Err: string;
begin
  Local := RepositoryRoot + 'tests' + PathDelim + 'data' + PathDelim + 'local' + PathDelim;
  if not DirectoryExists(Local + 'pdf') and not DirectoryExists(Local + 'verapdf') then
  begin
    Skip('no local PDF corpora (tools/testdata/sync-local.py)');
    Exit;
  end;
  Expected := TStringList.Create;
  Exceptions := TStringList.Create;
  Used := TStringList.Create;
  Rules := TLandrixEInvoicePdfARuleCheck.Create;
  try
    Expected.LoadFromFile(RepositoryRoot + 'tests' + PathDelim + 'data' + PathDelim + 'verapdf-expected.txt');
    Exceptions.LoadFromFile(RepositoryRoot + 'tests' + PathDelim + 'data' + PathDelim + 'pdfa-exceptions.txt');
    { an exception: path<TAB>rule<TAB>reason; the key is path<TAB>rule }
    for I := Exceptions.Count - 1 downto 0 do
      if (Exceptions[I] = '') or (Exceptions[I][1] = '#') then
        Exceptions.Delete(I)
      else
      begin
        J := Pos(#9, Exceptions[I]);
        J := J + Pos(#9, Copy(Exceptions[I], J + 1, MaxInt));
        Exceptions[I] := Copy(Exceptions[I], 1, J - 1);
      end;
    Files := 0;
    Incomplete := 0;
    Agree := 0;
    for I := 0 to Expected.Count - 1 do
    begin
      Line := Expected[I];
      if (Line = '') or (Line[1] = '#') then
        Continue;
      J := Pos(#9, Line);
      Path := Copy(Line, 1, J - 1);
      { the failed rules are the fifth column }
      ExpectedRules := Line;
      for J := 1 to 4 do
        ExpectedRules := Copy(ExpectedRules, Pos(#9, ExpectedRules) + 1, MaxInt);
      if Pos(#9, ExpectedRules) > 0 then
        ExpectedRules := '';
      FileName := Local + StringReplace(Path, '/', PathDelim, [rfReplaceAll]);
      if not FileExists(FileName) then
        Continue;
      Inc(Files);
      Facts := TLandrixEInvoicePdfSyntaxFacts.Create;
      Doc := TLandrixEInvoicePdfDocument.Create;
      M := TMemoryStream.Create;
      try
        M.LoadFromFile(FileName);
        Doc.Syntax := Facts;
        if not Doc.Load(M, Err) then
        begin
          Inc(Incomplete);
          Continue;
        end;
        Facts.Inspect(Doc);
        Rules.Check(Doc, Facts);
        if not Facts.Complete then
          Inc(Incomplete);
        Failed := False;
        for R := Low(TLandrixEInvoicePdfARule) to High(TLandrixEInvoicePdfARule) do
        begin
          Key := Path + #9 + LandrixEInvoicePdfARuleNumber(R);
          if (Rules.RuleResult(R).Outcome = pro_Failed) and not HasRule(ExpectedRules, LandrixEInvoicePdfARuleNumber(R)) then
          begin
            if Exceptions.IndexOf(Key) >= 0 then
              Used.Add(Key)
            else
            begin
              Failed := True;
              Fail(Path + ': ' + LandrixEInvoicePdfARuleId(R) + ' fails, veraPDF passes it: ' +
                Rules.RuleResult(R).Detail);
            end;
          end;
          if (Rules.RuleResult(R).Outcome = pro_Passed) and HasRule(ExpectedRules, LandrixEInvoicePdfARuleNumber(R)) then
          begin
            if Exceptions.IndexOf(Key) >= 0 then
              Used.Add(Key)
            else
            begin
              Failed := True;
              Fail(Path + ': ' + LandrixEInvoicePdfARuleId(R) + ' passes, veraPDF fails it');
            end;
          end;
        end;
        if not Failed then
          Inc(Agree);
      finally
        M.Free;
        Doc.Free;
        Facts.Free;
      end;
    end;
    for I := 0 to Exceptions.Count - 1 do
      Check(Used.IndexOf(Exceptions[I]) >= 0, 'unused exception ' + Exceptions[I]);
    Check(Files > 0, 'files of tests/data/verapdf-expected.txt found locally');
    CheckEquals(Files, Agree, 'files that agree with veraPDF');
    WriteLn('  PDF/A against veraPDF: ', Files, ' files, ', Incomplete, ' with incomplete facts');
  finally
    Rules.Free;
    Used.Free;
    Exceptions.Free;
    Expected.Free;
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
  RegisterTest('PdfA.Clean', TestPdfAClean);
  RegisterTest('PdfA.Violations', TestPdfAViolations);
  RegisterTest('PdfA.Limits', TestPdfALimits);
  RegisterTest('PdfA.Interactive', TestPdfAInteractive);
  RegisterTest('PdfA.Interactive2', TestPdfAInteractive2);
  RegisterTest('PdfA.Files', TestPdfAFiles);
  RegisterTest('PdfA.Metadata', TestPdfAMetadata);
  RegisterTest('PdfA.XmpReader', TestPdfAXmpReader);
  RegisterTest('PdfA.VeraPdf', TestPdfAVeraPdf);
end;

end.
