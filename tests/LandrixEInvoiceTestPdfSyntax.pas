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
  the XMP reader's valid, rejected and undecided forms; PdfA.Extension: the
  extension schemas (6.6.2.3.2, 6.6.2.3.3); PdfA.Properties: the XMP
  properties and their value types (6.6.2.3.1); PdfA.Content: the content
  streams (operands, q nesting, inline images, file specifications). Accepted
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
  LandrixEInvoiceTypes,
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
  ExtNs = 'xmlns:pdfaExtension="http://www.aiim.org/pdfa/ns/extension/" ' +
    'xmlns:pdfaSchema="http://www.aiim.org/pdfa/ns/schema#" xmlns:pdfaProperty="http://www.aiim.org/pdfa/ns/property#" ' +
    'xmlns:pdfaType="http://www.aiim.org/pdfa/ns/type#" xmlns:pdfaField="http://www.aiim.org/pdfa/ns/field#"';
  { a value type MyType with one field of type Bag Text }
  ExtMyType = '<pdfaSchema:valueType><rdf:Seq><rdf:li rdf:parseType="Resource"><pdfaType:type>MyType</pdfaType:type>' +
    '<pdfaType:namespaceURI>urn:my#t</pdfaType:namespaceURI><pdfaType:prefix>t</pdfaType:prefix>' +
    '<pdfaType:description>d</pdfaType:description><pdfaType:field><rdf:Seq><rdf:li rdf:parseType="Resource">' +
    '<pdfaField:name>f</pdfaField:name><pdfaField:valueType>Bag Text</pdfaField:valueType>' +
    '<pdfaField:description>d</pdfaField:description></rdf:li></rdf:Seq></pdfaType:field></rdf:li></rdf:Seq>' +
    '</pdfaSchema:valueType>';

{ A complete extension property AName of the type AType. }
function ExtProp(const AName, AType: AnsiString): AnsiString;
begin
  Result := '<rdf:li rdf:parseType="Resource"><pdfaProperty:name>' + AName + '</pdfaProperty:name>' +
    '<pdfaProperty:valueType>' + AType + '</pdfaProperty:valueType><pdfaProperty:category>external' +
    '</pdfaProperty:category><pdfaProperty:description>d</pdfaProperty:description></rdf:li>';
end;

{ A complete extension schema for the namespace AUri with the properties
  AProps and the value types ATypes (a pdfaSchema:valueType or ''). }
function ExtSchema(const AUri, AProps, ATypes: AnsiString): AnsiString;
begin
  Result := '<rdf:li rdf:parseType="Resource"><pdfaSchema:schema>S</pdfaSchema:schema><pdfaSchema:namespaceURI>' +
    AUri + '</pdfaSchema:namespaceURI><pdfaSchema:prefix>p</pdfaSchema:prefix><pdfaSchema:property><rdf:Seq>' +
    AProps + '</rdf:Seq></pdfaSchema:property>' + ATypes + '</rdf:li>';
end;

{ An rdf:Description with the extension schemas ASchemas. }
function ExtDesc(const ASchemas: AnsiString): AnsiString;
begin
  Result := '<rdf:Description rdf:about="" ' + ExtNs + '><pdfaExtension:schemas><rdf:Bag>' + ASchemas +
    '</rdf:Bag></pdfaExtension:schemas></rdf:Description>' + LF;
end;

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
    MetaObj(20, XmpHead + XmpPdfA3B + ExtDesc(ExtSchema('urn:my', ExtProp('a', 'MyType') +
      ExtProp('b', 'Closed Choice of Integer'), ExtMyType)) + XmpTail),
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
    named in a /Properties array that /AF /MC0 BDC in the page's content
    uses, so it is associated }
  Pdf := BuildPdf(GoodHeader, [
    '1 0 obj' + LF + '<< /Type /Catalog /Pages 2 0 R /AF [10 0 R] /Requirements << >> /Names << /EmbeddedFiles << ' +
      '/Names [(a) 10 0 R] >> >> /OCProperties << /OCGs [20 0 R] /D << /Name (cfg) /Order [(label) [20 0 R]] >> ' +
      '/Configs [<< /Name (other) /AS null >>] >> >>' + LF + 'endobj' + LF,
    '2 0 obj' + LF + '<< /Type /Pages /Kids [3 0 R] /Count 1 >>' + LF + 'endobj' + LF,
    '3 0 obj' + LF + '<< /Type /Page /Parent 2 0 R /MediaBox [0 0 612 792] /PresSteps null ' +
      '/Resources << /Properties << /MC0 [11 0 R] >> >> /Contents 4 0 R >>' + LF + 'endobj' + LF,
    '4 0 obj' + LF + '<< /Length 16 >>' + LF + 'stream' + LF + '/AF /MC0 BDC EMC' + LF + 'endstream' + LF + 'endobj' +
      LF,
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
      Check(Rules.RuleResult(par_6_8_4).Outcome = pro_Passed, '6.8-4 passed (/AF /MC0 BDC)');
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
      CheckEqualsStr('6.6.2.1-2 6.6.2.1-3 6.6.2.1-4 6.6.2.1-5 6.6.2.3.1-2 6.6.4-3 6.6.4-4', FailedRules(Rules),
        'failed rules');
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

procedure TestPdfAExtension;
var
  Pdf: AnsiString;
  Facts: TLandrixEInvoicePdfSyntaxFacts;
  Doc: TLandrixEInvoicePdfDocument;
  Rules: TLandrixEInvoicePdfARuleCheck;
  R: TLandrixEInvoicePdfARule;
begin
  { every extension schema rule fails once: the container a Seq under the
    prefix ext; schema 1 with s:schema, no prefix, a foreign field, the
    properties in a Bag (property a: category External, no description;
    b: name a structure; c: Dimensions, known to a schema with an entry;
    d: an unknown type), value type MyType with a field under f:name of
    type Nope and without description, and a value type with nothing but a
    Bag of fields; schema 2 without namespace URI, valueType a text;
    schema 3 complete with an empty rdf:Alt of properties }
  Pdf := BuildPdf(GoodHeader, [
    '1 0 obj' + LF + '<< /Type /Catalog /Pages 2 0 R /Metadata 20 0 R >>' + LF + 'endobj' + LF, Pages,
    MetaObj(20, XmpHead + XmpPdfA3B + '<rdf:Description rdf:about="" ' + ExtNs +
      ' xmlns:ext="http://www.aiim.org/pdfa/ns/extension/" xmlns:s="http://www.aiim.org/pdfa/ns/schema#"' +
      ' xmlns:f="http://www.aiim.org/pdfa/ns/field#"><ext:schemas><rdf:Seq>' +
      '<rdf:li rdf:parseType="Resource"><s:schema>S</s:schema><pdfaSchema:namespaceURI>urn:my' +
      '</pdfaSchema:namespaceURI><pdfaSchema:extra>x</pdfaSchema:extra><pdfaSchema:property><rdf:Bag>' +
      '<rdf:li rdf:parseType="Resource"><pdfaProperty:name>a</pdfaProperty:name><pdfaProperty:valueType>' +
      'Closed Choice of Integer</pdfaProperty:valueType><pdfaProperty:category>External</pdfaProperty:category>' +
      '</rdf:li>' +
      '<rdf:li rdf:parseType="Resource"><pdfaProperty:name rdf:parseType="Resource"><pdfaProperty:x>1' +
      '</pdfaProperty:x></pdfaProperty:name><pdfaProperty:valueType>MyType</pdfaProperty:valueType>' +
      '<pdfaProperty:category>internal</pdfaProperty:category><pdfaProperty:description>d' +
      '</pdfaProperty:description></rdf:li>' +
      ExtProp('c', 'Dimensions') + ExtProp('d', 'Unknown Thing') + '</rdf:Bag></pdfaSchema:property>' +
      '<pdfaSchema:valueType><rdf:Seq><rdf:li rdf:parseType="Resource"><pdfaType:type>MyType</pdfaType:type>' +
      '<pdfaType:namespaceURI>urn:my#t</pdfaType:namespaceURI><pdfaType:prefix>t</pdfaType:prefix>' +
      '<pdfaType:description>d</pdfaType:description><pdfaType:field><rdf:Seq><rdf:li rdf:parseType="Resource">' +
      '<pdfaField:name>f</pdfaField:name><pdfaField:valueType>Bag Text</pdfaField:valueType>' +
      '<pdfaField:description>d</pdfaField:description></rdf:li><rdf:li rdf:parseType="Resource">' +
      '<f:name>g</f:name><pdfaField:valueType>Nope</pdfaField:valueType></rdf:li></rdf:Seq></pdfaType:field>' +
      '</rdf:li><rdf:li rdf:parseType="Resource"><pdfaType:field><rdf:Bag/></pdfaType:field></rdf:li></rdf:Seq>' +
      '</pdfaSchema:valueType></rdf:li>' +
      '<rdf:li rdf:parseType="Resource"><pdfaSchema:schema>S</pdfaSchema:schema><pdfaSchema:prefix>q' +
      '</pdfaSchema:prefix><pdfaSchema:valueType>none</pdfaSchema:valueType></rdf:li>' +
      '<rdf:li rdf:parseType="Resource"><pdfaSchema:schema>S</pdfaSchema:schema><pdfaSchema:namespaceURI>urn:z' +
      '</pdfaSchema:namespaceURI><pdfaSchema:prefix>z</pdfaSchema:prefix><pdfaSchema:property><rdf:Alt/>' +
      '</pdfaSchema:property></rdf:li>' +
      '</rdf:Seq></ext:schemas></rdf:Description>' + LF + XmpTail)], LF, FileId, LF);
  Facts := TLandrixEInvoicePdfSyntaxFacts.Create;
  Rules := TLandrixEInvoicePdfARuleCheck.Create;
  try
    Doc := LoadWithFacts(Pdf, Facts);
    try
      Check(Facts.Complete, 'complete: ' + Facts.Problems.Text);
      Rules.Check(Doc, Facts);
      CheckEqualsStr('6.6.2.3.2-1 6.6.2.3.3-1 6.6.2.3.3-2 6.6.2.3.3-3 6.6.2.3.3-4 6.6.2.3.3-5 6.6.2.3.3-6 ' +
        '6.6.2.3.3-7 6.6.2.3.3-8 6.6.2.3.3-9 6.6.2.3.3-10 6.6.2.3.3-11 6.6.2.3.3-12 6.6.2.3.3-13 6.6.2.3.3-14 ' +
        '6.6.2.3.3-15 6.6.2.3.3-16 6.6.2.3.3-17 6.6.2.3.3-18', FailedRules(Rules), 'failed rules');
      for R := par_6_6_2_3_2_1 to par_6_6_2_3_3_18 do
        CheckEquals(1, Rules.RuleResult(R).Failures, LandrixEInvoicePdfARuleId(R) + ' fails once: ' +
          Rules.RuleResult(R).Detail);
      CheckEquals(20, Rules.RuleResult(par_6_6_2_3_3_8).ObjNum, 'in the main packet');
    finally
      Doc.Free;
    end;
  finally
    Rules.Free;
    Facts.Free;
  end;

  { a further packet: schema urn:my knows MyType from the main packet;
    urn:x, which the main packet does not define, starts from all built-in
    types (Dimensions) }
  Pdf := BuildPdf(GoodHeader, [
    '1 0 obj' + LF + '<< /Type /Catalog /Pages 2 0 R /Metadata 20 0 R >>' + LF + 'endobj' + LF,
    '2 0 obj' + LF + '<< /Type /Pages /Kids [3 0 R] /Count 1 >>' + LF + 'endobj' + LF,
    '3 0 obj' + LF + '<< /Type /Page /Parent 2 0 R /MediaBox [0 0 612 792] /Metadata 21 0 R >>' + LF + 'endobj' + LF,
    MetaObj(20, XmpHead + XmpPdfA3B + ExtDesc(ExtSchema('urn:my', ExtProp('a', 'Text'), ExtMyType)) + XmpTail),
    MetaObj(21, XmpHead + ExtDesc(ExtSchema('urn:my', ExtProp('b', 'MyType'), '') +
      ExtSchema('urn:x', ExtProp('c', 'Dimensions'), '')) + XmpTail)], LF, FileId, LF);
  Facts := TLandrixEInvoicePdfSyntaxFacts.Create;
  Rules := TLandrixEInvoicePdfARuleCheck.Create;
  try
    Doc := LoadWithFacts(Pdf, Facts);
    try
      Check(Facts.Complete, 'complete: ' + Facts.Problems.Text);
      Rules.Check(Doc, Facts);
      CheckEqualsStr('', FailedRules(Rules), 'failed rules');
      Check(Rules.RuleResult(par_6_6_2_3_3_8).Outcome = pro_Passed, '6.6.2.3.3-8 passed');
      Check(Rules.RuleResult(par_6_6_2_3_3_17).Outcome = pro_Passed, '6.6.2.3.3-17 passed');
    finally
      Doc.Free;
    end;
  finally
    Rules.Free;
    Facts.Free;
  end;
end;

{ A stream object with the data AData and more dictionary entries ADict. }
function StreamObj(ANum: Integer; const AData, ADict: AnsiString): AnsiString;
begin
  Result := IntToAnsi(ANum) + ' 0 obj' + LF + '<< /Length ' + IntToAnsi(Length(AData)) + ADict + ' >>' + LF + 'stream' +
    LF + AData + LF + 'endstream' + LF + 'endobj' + LF;
end;

{ A one-page document: more catalog entries ACatalog, the page's content
  AContent (stream 4 with the dictionary entries AContentDict), more page
  entries APage, the resources ARes and further objects AExtra (numbers from
  10 on). }
function CatalogPdf(const ACatalog, AContent, AContentDict, APage, ARes: AnsiString;
  const AExtra: array of AnsiString): AnsiString;
var
  Objs: array of AnsiString;
  I: Integer;
begin
  Objs := nil;
  SetLength(Objs, 4);
  Objs[0] := '1 0 obj' + LF + '<< /Type /Catalog /Pages 2 0 R ' + ACatalog + ' >>' + LF + 'endobj' + LF;
  Objs[1] := '2 0 obj' + LF + '<< /Type /Pages /Kids [3 0 R] /Count 1 >>' + LF + 'endobj' + LF;
  Objs[2] := '3 0 obj' + LF + '<< /Type /Page /Parent 2 0 R /MediaBox [0 0 612 792] /Contents 4 0 R ' + APage +
    ' /Resources << ' + ARes + ' >> >>' + LF + 'endobj' + LF;
  Objs[3] := StreamObj(4, AContent, AContentDict);
  for I := 0 to Integer(High(AExtra)) do
    if AExtra[I] <> '' then
    begin
      SetLength(Objs, Length(Objs) + 1);
      Objs[High(Objs)] := AExtra[I];
    end;
  Result := BuildPdf(GoodHeader, Objs, LF, FileId, LF);
end;

{ CatalogPdf without more catalog entries. }
function ContentPdf(const AContent, AContentDict, APage, ARes: AnsiString; const AExtra: array of AnsiString): AnsiString;
begin
  Result := CatalogPdf('', AContent, AContentDict, APage, ARes, AExtra);
end;

function OutcomeOf(const APdf: AnsiString; ARule: TLandrixEInvoicePdfARule): TLandrixEInvoicePdfARuleOutcome;
var
  Facts: TLandrixEInvoicePdfSyntaxFacts;
  Doc: TLandrixEInvoicePdfDocument;
  Rules: TLandrixEInvoicePdfARuleCheck;
begin
  Facts := TLandrixEInvoicePdfSyntaxFacts.Create;
  Rules := TLandrixEInvoicePdfARuleCheck.Create;
  try
    Doc := LoadWithFacts(APdf, Facts);
    try
      Rules.Check(Doc, Facts);
      Result := Rules.RuleResult(ARule).Outcome;
    finally
      Doc.Free;
    end;
  finally
    Rules.Free;
    Facts.Free;
  end;
end;

function OutcomeText(AOutcome: TLandrixEInvoicePdfARuleOutcome): string;
const
  Names: array[TLandrixEInvoicePdfARuleOutcome] of string = ('not checked', 'passed', 'failed', 'incomplete');
begin
  Result := Names[AOutcome];
end;

procedure CheckOutcome(const APdf: AnsiString; ARule: TLandrixEInvoicePdfARule;
  AExpected: TLandrixEInvoicePdfARuleOutcome; const AMessage: string);
begin
  CheckEqualsStr(OutcomeText(AExpected), OutcomeText(OutcomeOf(APdf, ARule)), AMessage);
end;

function Saves(ACount: Integer): AnsiString;
var
  I: Integer;
begin
  Result := '';
  for I := 1 to ACount do
    Result := Result + 'q ';
end;

function Bytes3(ACount: Integer; A, B, C: AnsiChar): AnsiString;
var
  I: Integer;
begin
  Result := '';
  SetLength(Result, 3 * ACount);
  for I := 0 to ACount - 1 do
  begin
    Result[3 * I + 1] := A;
    Result[3 * I + 2] := B;
    Result[3 * I + 3] := C;
  end;
end;

function Bytes2(ACount: Integer; A, B: AnsiChar): AnsiString;
var
  I: Integer;
begin
  Result := '';
  SetLength(Result, 2 * ACount);
  for I := 0 to ACount - 1 do
  begin
    Result[2 * I + 1] := A;
    Result[2 * I + 2] := B;
  end;
end;

{ The content streams as veraPDF reads them: only the operands an operator
  passes on count, q nests per stream, inline image filters, the streams
  that are reached (forms with Do, patterns with scn, Type 3 glyphs with a
  text show, appearances), what makes a stream unread or not decided, file
  specifications in inline dictionaries and /AF /Name BDC. }
procedure TestPdfAContent;
const
  NoExtra: array[0..0] of AnsiString = ('');
var
  Form, Glyph, Pat: AnsiString;
begin
  { operands: w checks its last operand only }
  CheckOutcome(ContentPdf('2147483648 w', '', '', '', NoExtra), par_6_1_13_1, pro_Failed, 'w 2147483648');
  CheckOutcome(ContentPdf('2147483648 1 w', '', '', '', NoExtra), par_6_1_13_1, pro_Passed, 'w takes the last operand');
  CheckOutcome(ContentPdf('1 2147483648 Td', '', '', '', NoExtra), par_6_1_13_1, pro_Failed, 'Td vertical offset');
  CheckOutcome(ContentPdf('[1 2147483648] 0 d', '', '', '', NoExtra), par_6_1_13_1, pro_Failed, 'd dash array');
  CheckOutcome(ContentPdf('2147483648 0 0 RG', '', '', '', NoExtra), par_6_1_13_1, pro_Failed, 'RG colour values');
  CheckOutcome(ContentPdf('0 0 d1 2147483648 0 0 RG', '', '', '', NoExtra), par_6_1_13_1, pro_Passed,
    'colour operators off after d1');
  CheckOutcome(ContentPdf('- w', '', '', '', NoExtra), par_6_1_13_1, pro_Failed, '"-" is the smallest integer');
  CheckOutcome(ContentPdf('. w', '', '', '', NoExtra), par_6_1_13_2, pro_Failed, '"." is the largest real');
  CheckOutcome(ContentPdf('340400000000000000000000000000000000000.0 w', '', '', '', NoExtra), par_6_1_13_2,
    pro_Failed, 'real above the limit');
  CheckOutcome(ContentPdf('340300000000000000000000000000000000000.0 w', '', '', '', NoExtra), par_6_1_13_2,
    pro_Incomplete, 'real on the limit');
  CheckOutcome(ContentPdf('0.00000000000000000000000000000000000000001 w', '', '', '', NoExtra), par_6_1_13_5,
    pro_Failed, 'real too close to zero');
  CheckOutcome(ContentPdf('<A Z 3> Tj', '', '', '', NoExtra), par_6_1_6_1, pro_Failed, 'hex count 3');
  CheckOutcome(ContentPdf('<A Z 3> Tj', '', '', '', NoExtra), par_6_1_6_2, pro_Failed, 'hex Z');
  CheckOutcome(ContentPdf('<A Z 3> 1 w', '', '', '', NoExtra), par_6_1_6_2, pro_Passed, 'a hex string w drops');
  CheckOutcome(ContentPdf('/' + Repeated('n', 128) + ' BMC EMC', '', '', '', NoExtra), par_6_1_13_4, pro_Failed,
    'tag name of 128 bytes');
  CheckOutcome(ContentPdf('(' + Repeated('a', 32768) + ') Tj', '', '', '', NoExtra), par_6_1_13_3, pro_Failed,
    '32768 characters');
  CheckOutcome(ContentPdf('(' + Bytes2(16384, AnsiChar($C3), AnsiChar($A9)) + ') Tj', '', '', '', NoExtra),
    par_6_1_13_3, pro_Passed, '32768 bytes of 16384 characters');
  { q nesting: 29 saves fail; a form starts its own stack }
  CheckOutcome(ContentPdf(Saves(29), '', '', '', NoExtra), par_6_1_13_8, pro_Failed, '29 saves');
  CheckOutcome(ContentPdf(Saves(28) + 'Q ' + Saves(1), '', '', '', NoExtra), par_6_1_13_8, pro_Passed, '28 saves');
  Form := StreamObj(10, Saves(2), ' /Type /XObject /Subtype /Form /BBox [0 0 1 1]');
  CheckOutcome(ContentPdf(Saves(27) + '/X1 Do', '', '', '/XObject << /X1 10 0 R >>', [Form]), par_6_1_13_8,
    pro_Passed, '27 saves and a form with 2');
  Form := StreamObj(10, Saves(29), ' /Type /XObject /Subtype /Form /BBox [0 0 1 1]');
  CheckOutcome(ContentPdf('/X1 Do', '', '', '/XObject << /X1 10 0 R >>', [Form]), par_6_1_13_8, pro_Failed,
    'a form with 29 saves');
  CheckOutcome(ContentPdf('', '', '', '/XObject << /X1 10 0 R >>', [Form]), par_6_1_13_8, pro_Passed, 'an unused form');
  { tiling pattern selected with scn; Type 3 glyphs once text is shown;
    appearances of annotations }
  Pat := StreamObj(10, Saves(29), ' /PatternType 1 /PaintType 1 /TilingType 1 /BBox [0 0 1 1] /XStep 1 /YStep 1 ' +
    '/Resources << >>');
  CheckOutcome(ContentPdf('/Pattern cs /P1 scn', '', '', '/Pattern << /P1 10 0 R >>', [Pat]), par_6_1_13_8,
    pro_Failed, 'a pattern selected');
  CheckOutcome(ContentPdf('', '', '', '/Pattern << /P1 10 0 R >>', [Pat]), par_6_1_13_8, pro_Passed,
    'a pattern not selected');
  Glyph := StreamObj(11, '0 0 d0 ' + Saves(29), '');
  CheckOutcome(ContentPdf('BT /F1 1 Tf ET', '', '', '/Font << /F1 10 0 R >>',
    ['10 0 obj' + LF + '<< /Type /Font /Subtype /Type3 /CharProcs << /a 11 0 R >> /FontBBox [0 0 1 1] ' +
    '/FontMatrix [1 0 0 1 0 0] /FirstChar 0 /LastChar 0 /Widths [1] >>' + LF + 'endobj' + LF, Glyph]), par_6_1_13_8,
    pro_Passed, 'a Type 3 font selected only');
  CheckOutcome(ContentPdf('BT /F1 1 Tf () Tj ET', '', '', '/Font << /F1 10 0 R >>',
    ['10 0 obj' + LF + '<< /Type /Font /Subtype /Type3 /CharProcs << /a 11 0 R >> /FontBBox [0 0 1 1] ' +
    '/FontMatrix [1 0 0 1 0 0] /FirstChar 0 /LastChar 0 /Widths [1] >>' + LF + 'endobj' + LF, Glyph]), par_6_1_13_8,
    pro_Failed, 'a Type 3 font showing text');
  CheckOutcome(ContentPdf('', '', '/Annots [10 0 R]', '',
    ['10 0 obj' + LF + '<< /Type /Annot /Subtype /Square /Rect [0 0 1 1] /F 4 /AP << /N 11 0 R /D << /Off 12 0 R >> >> >>' +
    LF + 'endobj' + LF, StreamObj(11, '', ''), StreamObj(12, Saves(29), '')]), par_6_1_13_8, pro_Failed,
    'a down appearance in a state dictionary');
  { inline images }
  CheckOutcome(ContentPdf('BI /W 1 /H 1 /CS /G /BPC 8 /F /LZW ID x EI', '', '', '', NoExtra), par_6_1_10_1, pro_Failed,
    'inline image with LZW');
  CheckOutcome(ContentPdf('BI /W 1 /H 1 /CS /G /BPC 8 /F [/LZW 7] ID x EI', '', '', '', NoExtra), par_6_1_10_1,
    pro_Passed, 'a filter array with a number has no filters');
  CheckOutcome(ContentPdf('BI /W 1 /H 1 /CS /G /BPC 8 /F /AHx ID 78> EI', '', '', '', NoExtra), par_6_1_10_1,
    pro_Passed, 'ASCIIHex abbreviated');
  CheckOutcome(ContentPdf('0 0 d1 BI /W 1 /H 1 /BPC 1 /F /LZW ID x EI', '', '', '', NoExtra), par_6_1_10_1,
    pro_Passed, 'colour operators off: the image is not read');
  CheckOutcome(ContentPdf('0 0 d1 BI /W 1 /H 1 /BPC 1 /IM true /F /LZW ID x EI', '', '', '', NoExtra), par_6_1_10_1,
    pro_Failed, 'an image mask is read');
  CheckOutcome(ContentPdf('BI /W 1 /H 1 /CS /G /BPC 8 ID xEI EIx EI 2147483648 w', '', '', '', NoExtra), par_6_1_13_1,
    pro_Failed, 'EI only before white space and a known operator');
  { what veraPDF does not read }
  CheckOutcome(ContentPdf('2147483648 w [1 2', '', '', '', NoExtra), par_6_1_13_1, pro_Passed,
    'an unclosed array drops the stream');
  CheckOutcome(ContentPdf('2147483648 w ] 2147483648 w', '', '', '', NoExtra), par_6_1_13_1, pro_Failed,
    'a stray ] keeps what came before');
  CheckOutcome(ContentPdf('2147483648 w', ' /Filter /Foo', '', '', NoExtra), par_6_1_13_1, pro_Passed,
    'an unknown filter gives no data');
  CheckOutcome(ContentPdf('2147483648 w', ' /Filter /ASCIIHexDecode', '', '', NoExtra), par_6_1_13_1,
    pro_Incomplete, 'another filter: not decided');
  CheckOutcome(ContentPdf('2147483648 w', ' /Filter /FlateDecode', '', '', NoExtra), par_6_1_13_1, pro_Incomplete,
    'damaged Flate data: not decided');
  { file specifications in inline dictionaries: not the outer one }
  CheckOutcome(ContentPdf('/Span << /X << /Type /Filespec /EF << >> >> >> BDC EMC', '', '', '', NoExtra), par_6_8_2,
    pro_Failed, 'nested file specification without /F and /UF');
  CheckOutcome(ContentPdf('/Span << /X << /Type /Filespec /EF << >> >> >> BDC EMC', '', '', '', NoExtra), par_6_8_4,
    pro_Failed, 'nested file specification is direct');
  CheckOutcome(ContentPdf('/Span << /Type /Filespec /EF << >> >> BDC EMC', '', '', '', NoExtra), par_6_8_3, pro_Passed,
    'the outer dictionary is no file specification');
  { /AF /Name BDC associates, DP does not }
  CheckOutcome(ContentPdf('/AF /MC0 BDC EMC', '', '', '/Properties << /MC0 [10 0 R] >>',
    ['10 0 obj' + LF + '<< /Type /Filespec /F (m) /UF (m) /AFRelationship /Data >>' + LF + 'endobj' + LF]), par_6_8_4,
    pro_Passed, '/AF /MC0 BDC');
  CheckOutcome(ContentPdf('/AF /MC0 DP', '', '', '/Properties << /MC0 [10 0 R] >>',
    ['10 0 obj' + LF + '<< /Type /Filespec /F (m) /UF (m) /AFRelationship /Data >>' + LF + 'endobj' + LF]), par_6_8_4,
    pro_Failed, '/AF /MC0 DP');
  CheckOutcome(ContentPdf('/AF /MC0 BDC EMC', ' /Filter /ASCIIHexDecode', '', '/Properties << /MC0 [10 0 R] >>',
    ['10 0 obj' + LF + '<< /Type /Filespec /F (m) /UF (m) /AFRelationship /Data >>' + LF + 'endobj' + LF]), par_6_8_4,
    pro_Incomplete, 'a stream not read may associate');
  CheckOutcome(ContentPdf('', '', '/X << /AF [10 0 R] >>', '',
    ['10 0 obj' + LF + '<< /Type /Filespec /F (m) /UF (m) /AFRelationship /Data >>' + LF + 'endobj' + LF]), par_6_8_4,
    pro_Failed, 'the /AF of an arbitrary dictionary does not associate');
  CheckOutcome(ContentPdf('', '', '/AF [10 0 R]', '',
    ['10 0 obj' + LF + '<< /Type /Filespec /F (m) /UF (m) /AFRelationship /Data >>' + LF + 'endobj' + LF]), par_6_8_4,
    pro_Passed, 'the /AF of a page associates');
  CheckOutcome(ContentPdf('', '', '', '/XObject << /I 11 0 R >>',
    ['10 0 obj' + LF + '<< /Type /Filespec /F (m) /UF (m) /AFRelationship /Data >>' + LF + 'endobj' + LF,
    StreamObj(11, 'x', ' /Type /XObject /Subtype /Image /Width 1 /Height 1 /ColorSpace /DeviceGray ' +
    '/BitsPerComponent 8 /AF [10 0 R]')]), par_6_8_4, pro_Passed, 'the /AF of an unused image XObject associates');
  CheckOutcome(ContentPdf('', '', '/AF [10 1 R]', '',
    ['10 0 obj' + LF + '<< /Type /Filespec /F (m) /UF (m) /AFRelationship /Data >>' + LF + 'endobj' + LF]), par_6_8_4,
    pro_Failed, 'a reference with another generation does not associate');
end;

function ObjText(ANum: Integer; const ABody: AnsiString): AnsiString;
begin
  Result := IntToAnsi(ANum) + ' 0 obj' + LF + ABody + LF + 'endobj' + LF;
end;

{ A document whose pages object is APages (object 2) with the page APage
  (object 3) and further objects AExtra. }
function PagesPdf(const APages, APage: AnsiString; const AExtra: array of AnsiString): AnsiString;
var
  Objs: array of AnsiString;
  I: Integer;
begin
  Objs := nil;
  SetLength(Objs, 3);
  Objs[0] := ObjText(1, '<< /Type /Catalog /Pages 2 0 R >>');
  Objs[1] := ObjText(2, APages);
  Objs[2] := ObjText(3, APage);
  for I := 0 to Integer(High(AExtra)) do
  begin
    SetLength(Objs, Length(Objs) + 1);
    Objs[High(Objs)] := AExtra[I];
  end;
  Result := BuildPdf(GoodHeader, Objs, LF, FileId, LF);
end;

{ Review cases of the PDF/A rules as veraPDF 1.30.4 reads them: an empty
  Crypt parameter dictionary, dangling references in /PresSteps and
  /AlternatePresentations, a stream in /Annots, /F as a string, a fifth
  /Rect entry, boxes read by their first four entries, a /Count that does
  not match, a kid without /Type, a stale action generation, a duplicate
  name of an embedded file and a large appearance dictionary. }
procedure TestPdfAReview;
const
  Annot = '<< /Type /Annot /Subtype /Text /Rect [0 0 10 10] /AP << /N 11 0 R >>';
var
  Ap: AnsiString;
  I: Integer;
begin
  CheckOutcome(ContentPdf('', ' /Filter /Crypt /DecodeParms << >>', '', '', []), par_6_1_7_2_1, pro_Failed,
    'Crypt with an empty parameter dictionary');
  CheckOutcome(ContentPdf('', ' /Filter /Crypt /DecodeParms << /Name /Identity >>', '', '', []), par_6_1_7_2_1,
    pro_Passed, 'Crypt Identity');
  CheckOutcome(ContentPdf('', '', '/PresSteps 99 0 R', '', []), par_6_10_2, pro_Failed,
    '/PresSteps to no object');
  CheckOutcome(ContentPdf('', '', '/PresSteps 10 0 R', '', [ObjText(10, 'null')]), par_6_10_2, pro_Passed,
    '/PresSteps to a null object');
  CheckOutcome(CatalogPdf('/Names << /AlternatePresentations 99 0 R >>', '', '', '', '', []), par_6_10_1, pro_Failed,
    '/AlternatePresentations to no object');
  CheckOutcome(ContentPdf('', '', '/Annots [10 0 R]', '',
    [StreamObj(10, '', ' /Type /XObject /Subtype /Form /BBox [0 0 1 1]')]), par_6_3_1_1, pro_Passed,
    'a stream in /Annots is no annotation');
  CheckOutcome(ContentPdf('', '', '/Annots [10 0 R]', '', [ObjText(10, Annot + ' /F (abcd) >>'),
    StreamObj(11, '', ' /BBox [0 0 1 1]')]), par_6_3_2_1, pro_Passed, '/F (abcd) is 4');
  CheckOutcome(ContentPdf('', '', '/Annots [10 0 R]', '', [ObjText(10, Annot + ' /F (abcd) >>'),
    StreamObj(11, '', ' /BBox [0 0 1 1]')]), par_6_3_2_2, pro_Passed, '/F (abcd) is Print');
  CheckOutcome(ContentPdf('', '', '/Annots [10 0 R]', '',
    [ObjText(10, '<< /Type /Annot /Subtype /Text /Rect [0 0 0 0 (a)] /F 4 >>')]), par_6_3_3_1, pro_Passed,
    'a fifth /Rect entry that is a string');
  CheckOutcome(ContentPdf('', '', '/Annots [10 0 R]', '',
    [ObjText(10, '<< /Type /Annot /Subtype /Text /Rect [0 0 (a) 0] /F 4 >>')]), par_6_3_3_1, pro_Failed,
    'a string in /Rect counts its length: (a) is 1 wide');
  CheckOutcome(ContentPdf('', '', '/Annots [10 0 R]', '',
    [ObjText(10, '<< /Type /Annot /Subtype /Text /Rect [0 0 0 0 ()] /F 4 >>')]), par_6_3_3_1, pro_Passed,
    'an empty string in /Rect is 0');
  CheckOutcome(ContentPdf('', '', '/Annots [10 0 R]', '',
    [ObjText(10, '<< /Type /Annot /Subtype /Text /Rect [0 0 0 0 /Bad] /F 4 >>')]), par_6_3_3_1, pro_Failed,
    'a name in /Rect makes it no rectangle');
  CheckOutcome(ContentPdf('', '', '/CropBox [0 0 2]', '', []), par_6_1_13_11, pro_Failed,
    'a box of three entries');
  CheckOutcome(ContentPdf('', '', '/CropBox [0 0 612 792 (a)]', '', []), par_6_1_13_11, pro_Passed,
    'a fifth box entry is not read');
  CheckOutcome(ContentPdf('', '', '/CropBox [0 0 612 /Foo]', '', []), par_6_1_13_11, pro_Failed,
    'a box entry that is no number is 0');
  CheckOutcome(ContentPdf('', '', '/CropBox [10 0 R 0 11 100]', '', [ObjText(10, '10')]), par_6_1_13_11, pro_Passed,
    'a reference in a box is 0');
  CheckOutcome(ContentPdf('', ' /Filter /Crypt /DecodeParms 10 0 R', '', '', [ObjText(10, '<< >>')]), par_6_1_7_2_1,
    pro_Passed, 'an indirect Crypt parameter dictionary is none');
  CheckOutcome(ContentPdf('', ' /Filter [/Crypt] /DecodeParms << >>', '', '', []), par_6_1_7_2_1, pro_Failed,
    'one filter in an array with a direct parameter dictionary');

  { veraPDF finds pages through /Count: a page it may not see leaves the
    page rules undecided }
  CheckOutcome(PagesPdf('<< /Type /Pages /Kids [3 0 R] /Count 0 >>',
    '<< /Type /Page /Parent 2 0 R /MediaBox [0 0 612 792] /Annots [10 0 R] >>',
    [ObjText(10, Annot + ' >>'), StreamObj(11, '', ' /BBox [0 0 1 1]')]), par_6_3_2_1, pro_Incomplete,
    '/Count 0');
  CheckOutcome(PagesPdf('<< /Type /Pages /Kids [3 0 R] /Count 1 >>',
    '<< /Type /Page /Parent 2 0 R /MediaBox [0 0 612 792] /Annots [10 0 R] >>',
    [ObjText(10, Annot + ' >>'), StreamObj(11, '', ' /BBox [0 0 1 1]')]), par_6_3_2_1, pro_Failed,
    '/Count 1');
  CheckOutcome(PagesPdf('<< /Type /Pages /Kids [3 0 R] /Count 1 >>', '<< /Parent 2 0 R /MediaBox [0 0 2 2] >>', []),
    par_6_1_13_11, pro_Incomplete, 'a kid without /Type is not judged');

  { an action whose object header carries another generation is no action
    veraPDF reads }
  CheckOutcome(CatalogPdf('/OpenAction 10 0 R', '', '', '', '',
    ['10 1 obj' + LF + '<< /S /Named /N /Print >>' + LF + 'endobj' + LF]), par_6_5_1_2, pro_Passed,
    'stale generation');
  CheckOutcome(CatalogPdf('/OpenAction 10 0 R', '', '', '', '', [ObjText(10, '<< /S /Named /N /Print >>')]),
    par_6_5_1_2, pro_Failed, 'named action Print');

  { of two values of one name the last counts }
  CheckOutcome(CatalogPdf('/Names << /EmbeddedFiles << /Names [(a) 10 0 R (a) 11 0 R] >> >> /AF [11 0 R]', '', '',
    '', '', [ObjText(10, '<< /F (a) /EF << /F 12 0 R >> >>'),
    ObjText(11, '<< /Type /Filespec /F (a) /UF (a) /AFRelationship /Data /EF << /F 12 0 R >> >>'),
    StreamObj(12, 'x', ' /Type /EmbeddedFile /Subtype /text#2Fxml')]), par_6_8_3, pro_Passed,
    'the superseded file specification is not judged');
  CheckOutcome(CatalogPdf('/Names << /EmbeddedFiles << /Names [(a) 11 0 R (a) 10 0 R] >> >> /AF [11 0 R]', '', '',
    '', '', [ObjText(10, '<< /F (a) /EF << /F 12 0 R >> >>'),
    ObjText(11, '<< /Type /Filespec /F (a) /UF (a) /AFRelationship /Data /EF << /F 12 0 R >> >>'),
    StreamObj(12, 'x', ' /Type /EmbeddedFile /Subtype /text#2Fxml')]), par_6_8_3, pro_Failed,
    'the last value of a name is judged');
  CheckOutcome(CatalogPdf('/Names << /EmbeddedFiles << /Names [(a) 10 0 R <FEFF0061> 11 0 R] >> >> /AF [11 0 R]',
    '', '', '', '', [ObjText(10, '<< /F (a) /EF << /F 12 0 R >> >>'),
    ObjText(11, '<< /Type /Filespec /F (a) /UF (a) /AFRelationship /Data /EF << /F 12 0 R >> >>'),
    StreamObj(12, 'x', ' /Type /EmbeddedFile /Subtype /text#2Fxml')]), par_6_8_3, pro_Passed,
    'names compared as text');
  CheckOutcome(CatalogPdf('/Names << /EmbeddedFiles << /Names [(a) 10 0 R (a)] >> >>', '', '', '', '',
    [ObjText(10, '<< /F (a) /EF << /F 12 0 R >> >>'),
    StreamObj(12, 'x', ' /Type /EmbeddedFile /Subtype /text#2Fxml')]), par_6_8_3, pro_Passed,
    'a last key without a value replaces the earlier one');

  { a large appearance dictionary is not read key by key }
  Ap := '';
  for I := 1 to 100 do
    Ap := Ap + '/K' + IntToAnsi(I) + ' 11 0 R ';
  CheckOutcome(ContentPdf('', '', '/Annots [10 0 R]', '',
    [ObjText(10, '<< /Type /Annot /Subtype /Text /F 4 /Rect [0 0 10 10] /AP << ' + Ap + '>> >>'),
    StreamObj(11, '', ' /BBox [0 0 1 1]')]), par_6_3_3_2, pro_Incomplete, '100 appearance keys');
end;

{ Rounds 60 and 61 of the reviews: B tokens, ExtGState streams, default
  spaces of forms, named device spaces, one-element arrays, generations on
  every hop, the tree parent's resources, /AF visits, repeated keys in
  resources, large dictionaries, page tree types and integer keys. }
procedure TestPdfAContent4;
const
  NoExtra: array[0..0] of AnsiString = ('');
var
  Pat, Glyph, Font, Spec, Form29, Img, Pdf, Keys: AnsiString;
  I: Integer;
begin
  Spec := ObjText(10, '<< /Type /Filespec /F (m) /UF (m) /AFRelationship /Data >>');
  Form29 := StreamObj(13, Saves(29), ' /Type /XObject /Subtype /Form /BBox [0 0 1 1]');
  Img := ObjText(12, '<< /Type /XObject /Subtype /Image /AF [10 0 R] >>');
  CheckOutcome(ContentPdf('B2147483648 w', '', '', '', NoExtra), par_6_1_13_1, pro_Passed,
    'a token starting with B is one operator');
  CheckOutcome(ContentPdf('BI /W 1 /H 1 /CS /G /BPC 8 ID x EI BX1 2147483648 w EI', '', '', '', NoExtra),
    par_6_1_13_1, pro_Passed, 'BX1 after EI rejects that EI');
  Glyph := StreamObj(11, '0 0 d0 ' + Saves(29), '');
  Font := ObjText(10, '<< /Type /Font /Subtype /Type3 /CharProcs << /a 11 0 R >> /FontBBox [0 0 1 1] ' +
    '/FontMatrix [1 0 0 1 0 0] /FirstChar 0 /LastChar 0 /Widths [1] >>');
  CheckOutcome(ContentPdf('BT /G gs () Tj ET', '', '', '/ExtGState << /G 12 0 R >>',
    [Font, Glyph, StreamObj(12, 'x', ' /Font [10 0 R 1]')]), par_6_1_13_8, pro_Failed, 'an ExtGState stream');
  Pat := StreamObj(10, Saves(29), ' /PatternType 1 /PaintType 1 /TilingType 1 /BBox [0 0 1 1] /XStep 1 /YStep 1 ' +
    '/Resources << >>');
  CheckOutcome(ContentPdf('/F Do', '', '', '/ColorSpace << /DefaultGray /Pattern >> /Pattern << /P1 10 0 R >> ' +
    '/XObject << /F 12 0 R >>', [Pat, StreamObj(12, '/P1 scn', ' /Type /XObject /Subtype /Form /BBox [0 0 1 1]')]),
    par_6_1_13_8, pro_Failed, 'a form inherits the initial pattern space');
  CheckOutcome(ContentPdf('/F Do', '', '', '/ColorSpace << /DefaultGray /Pattern >> /Pattern << /P1 10 0 R >> ' +
    '/XObject << /F 12 0 R >>', [Pat, StreamObj(12, '0 g /P1 scn', ' /Type /XObject /Subtype /Form /BBox [0 0 1 1]')]),
    par_6_1_13_8, pro_Passed, 'g in a form without resources has no default');
  CheckOutcome(ContentPdf('/C cs /P1 scn', '', '', '/ColorSpace << /C /DeviceGray /DefaultGray /Pattern >> ' +
    '/Pattern << /P1 10 0 R >>', [Pat]), par_6_1_13_8, pro_Failed, 'a named device space has its default');
  CheckOutcome(ContentPdf('/F Do', '', '', '/ColorSpace << /C /Pattern >> /Pattern << /P1 10 0 R >> ' +
    '/XObject << /F 12 0 R >>', [Pat, StreamObj(12, '/C cs /P1 scn', ' /Type /XObject /Subtype /Form /BBox [0 0 1 1] ' +
    '/Resources << /ColorSpace << /C [/CalGray] >> >>')]), par_6_1_13_8, pro_Failed,
    '[/CalGray] gives no space: the page''s counts');
  CheckOutcome(ContentPdf('/F Do', '', '', '/XObject 12 0 R', [ObjText(12, '14 1 R'), ObjText(14, '<< /F 13 0 R >>'),
    Form29]), par_6_1_13_8, pro_Passed, 'the generation of a second hop');
  { resources come from the parent in the tree, not from /Parent }
  Pdf := BuildPdf(GoodHeader, [
    ObjText(1, '<< /Type /Catalog /Pages 2 0 R >>'),
    ObjText(2, '<< /Type /Pages /Kids [3 0 R] /Count 1 /Resources << /XObject << /I 12 0 R >> >> >>'),
    ObjText(3, '<< /Type /Page /Parent 4 0 R /MediaBox [0 0 612 792] >>'),
    ObjText(4, '<< /Type /Pages /Kids [] /Count 0 >>'), Spec, Img], LF, FileId, LF);
  CheckOutcome(Pdf, par_6_8_4, pro_Passed, 'resources of the tree parent');
  CheckOutcome(ContentPdf('', '', '', '/XObject << /A 12 1 R /B 12 0 R >>', [Spec, Img]), par_6_8_4, pro_Passed,
    'a stale reference does not hide the object');
  CheckOutcome(ContentPdf('', '', '', '/XObject << /I 12 0 R /I null >>', [Spec, Img]), par_6_8_4, pro_Failed,
    'an XObject entry removed by null');
  Keys := '';
  for I := 1 to 1001 do
    Keys := Keys + '/K' + IntToAnsi(I) + ' 0 ';
  CheckOutcome(ContentPdf('', '', '/X << ' + Keys + '/Z 2147483648 /Z 0 >>', '', NoExtra), par_6_1_13_1, pro_Passed,
    'a replaced value in a large dictionary');
  { a /Pages node without /Kids is no page }
  Pdf := BuildPdf(GoodHeader, [
    ObjText(1, '<< /Type /Catalog /Pages 2 0 R >>'),
    ObjText(2, '<< /Type /Pages /Kids [3 0 R 4 0 R] /Count 1 >>'),
    ObjText(3, '<< /Type /Pages /Parent 2 0 R /Count 0 /Contents 7 0 R >>'),
    ObjText(4, '<< /Type /Pages /Parent 2 0 R /Kids [5 0 R] /Count 1 >>'),
    ObjText(5, '<< /Type /Page /Parent 4 0 R /MediaBox [0 0 612 792] >>'),
    StreamObj(7, '2147483648 w', '')], LF, FileId, LF);
  CheckOutcome(Pdf, par_6_1_13_1, pro_Passed, 'a /Pages node without /Kids');
  { /Count read as veraPDF reads an integer }
  Pdf := BuildPdf(GoodHeader, [
    ObjText(1, '<< /Type /Catalog /Pages 2 0 R >>'),
    ObjText(2, '<< /Type /Pages /Kids [4 0 R] /Count 2 >>'),
    ObjText(4, '<< /Type /Pages /Parent 2 0 R /Kids [5 0 R 6 0 R] /Count 2.9 >>'),
    ObjText(5, '<< /Type /Page /Parent 4 0 R /MediaBox [0 0 612 792] >>'),
    ObjText(6, '<< /Type /Page /Parent 4 0 R /MediaBox [0 0 612 792] /Contents 7 0 R >>'),
    StreamObj(7, '2147483648 w', '')], LF, FileId, LF);
  CheckOutcome(Pdf, par_6_1_13_1, pro_Failed, '/Count 2.9 counts 2');
  CheckOutcome(ContentPdf('', '', '', '/Pattern << /P 14 0 R >>', [Spec, Img,
    ObjText(14, '<< /PatternType (x) /Resources << /XObject << /I 12 0 R >> >> >>')]), par_6_8_4, pro_Passed,
    'a pattern type (x) is 1');
end;

{ Round 61 of the reviews: a null at the growth of a dictionary, colour
  space names through the resources, defaults where the name was found,
  one-element pattern arrays, Java's int narrowing, the page tree root,
  pages beyond /Count, a missing /Count of an empty node. }
procedure TestPdfAContent5;
var
  Pat, Spec, Form29, Pdf: AnsiString;
begin
  Spec := ObjText(10, '<< /Type /Filespec /F (m) /UF (m) /AFRelationship /Data >>');
  Form29 := StreamObj(13, Saves(29), ' /Type /XObject /Subtype /Form /BBox [0 0 1 1]');
  CheckOutcome(ContentPdf('/Z Do', '', '', '/XObject << /A 0 /B 0 /C 0 /D 0 /E 0 /F 0 /G 0 /Z null /Z 13 0 R >>',
    [Form29]), par_6_1_13_8, pro_Failed, 'a key again after null at the growth of the table');
  CheckOutcome(ContentPdf('/Z Do', '', '', '/XObject << /A 0 /B 0 /C 0 /D 0 /E 0 /F 0 /G 0 /Z null /C 13 0 R ' +
    '/C null /Z 13 0 R >>', [Form29]), par_6_1_13_8, pro_Failed, 'tombstones and the table');
  Pat := StreamObj(11, Saves(29), ' /PatternType 1 /PaintType 1 /TilingType 1 /BBox [0 0 1 1] /XStep 1 /YStep 1 ' +
    '/Resources << >>');
  CheckOutcome(ContentPdf('/F Do', '', '', '/ColorSpace << /C /DeviceGray /DefaultGray /Pattern >> ' +
    '/Pattern << /P1 11 0 R >> /XObject << /F 12 0 R >>', [Pat, StreamObj(12, '/C cs /P1 scn',
    ' /Type /XObject /Subtype /Form /BBox [0 0 1 1]')]), par_6_1_13_8, pro_Failed,
    'the default of the resources the name was found in');
  CheckOutcome(ContentPdf('0 g /P1 scn', '', '', '/ColorSpace << /DeviceGray /Pattern >> /Pattern << /P1 11 0 R >>',
    [Pat]), par_6_1_13_8, pro_Failed, 'g looks up /DeviceGray in the resources');
  CheckOutcome(ContentPdf('/Pattern cs /P1 scn', '', '', '/ColorSpace << /Pattern /DeviceRGB >> ' +
    '/Pattern << /P1 11 0 R >>', [Pat]), par_6_1_13_8, pro_Passed, 'a resource named /Pattern');
  CheckOutcome(ContentPdf('/Pattern cs /P1 scn', '', '', '/ColorSpace << /DefaultGray /Alias /Alias /Pattern >> ' +
    '/Pattern << /P1 11 0 R >>', [Pat]), par_6_1_13_8, pro_Failed, 'an alias');
  CheckOutcome(ContentPdf('/P1 scn', '', '', '/ColorSpace << /DefaultGray /Alias /Alias /Pattern >> ' +
    '/Pattern << /P1 11 0 R >>', [Pat]), par_6_1_13_8, pro_Failed, 'a default through an alias');
  CheckOutcome(ContentPdf('/Pattern cs /P1 scn', '', '', '/Pattern << /P1 [11 0 R] >>', [Pat]), par_6_1_13_8,
    pro_Failed, 'a one-element pattern array');
  CheckOutcome(ContentPdf('/Pattern cs /P1 scn', '', '', '/Pattern << /P1 11 0 R >>',
    [StreamObj(11, Saves(29), ' /PatternType 4294967297 /PaintType 1 /TilingType 1 /BBox [0 0 1 1] /XStep 1 ' +
    '/YStep 1 /Resources << >>')]), par_6_1_13_8, pro_Failed, 'the pattern type as an int');
  { the root is a node whatever its /Type }
  Pdf := BuildPdf(GoodHeader, [
    ObjText(1, '<< /Type /Catalog /Pages 2 0 R >>'),
    ObjText(2, '<< /Type /Page /Kids [3 0 R] /Count 1 >>'),
    ObjText(3, '<< /Type /Page /Parent 2 0 R /MediaBox [0 0 612 792] /Contents 7 0 R >>'),
    StreamObj(7, '2147483648 w', '')], LF, FileId, LF);
  CheckOutcome(Pdf, par_6_1_13_1, pro_Failed, 'a root with /Type /Page');
  { a page beyond /Count may be no page for veraPDF }
  Pdf := BuildPdf(GoodHeader, [
    ObjText(1, '<< /Type /Catalog /Pages 2 0 R >>'),
    ObjText(2, '<< /Type /Pages /Kids [3 0 R 4 0 R] /Count 1 >>'),
    ObjText(3, '<< /Type /Page /Parent 2 0 R /MediaBox [0 0 612 792] >>'),
    ObjText(4, '<< /Type /Page /Parent 2 0 R /MediaBox [0 0 612 792] /AF [10 0 R] >>'), Spec], LF, FileId, LF);
  CheckOutcome(Pdf, par_6_8_4, pro_Incomplete, 'an association beyond /Count');
  { an empty node without /Count counts 0 }
  Pdf := BuildPdf(GoodHeader, [
    ObjText(1, '<< /Type /Catalog /Pages 2 0 R >>'),
    ObjText(2, '<< /Type /Pages /Kids [3 0 R 4 0 R] /Count 1 >>'),
    ObjText(3, '<< /Type /Pages /Parent 2 0 R /Kids [] >>'),
    ObjText(4, '<< /Type /Page /Parent 2 0 R /MediaBox [0 0 612 792] /Contents 7 0 R >>'),
    StreamObj(7, '2147483648 w', '')], LF, FileId, LF);
  CheckOutcome(Pdf, par_6_1_13_1, pro_Failed, 'an empty node without /Count');
end;

{ The limits against hostile content: q beyond the kept levels still
  counts, a dictionary operand with too many keys leaves the stream
  undecided. }
procedure TestPdfAContent10;
const
  NoExtra: array[0..0] of AnsiString = ('');
var
  Keys: AnsiString;
  I: Integer;
begin
  CheckOutcome(ContentPdf(Saves(1001), '', '', '', NoExtra), par_6_1_13_8, pro_Failed, '1001 saves');
  CheckOutcome(ContentPdf(Saves(1001) + 'Q ', '', '', '', NoExtra), par_6_1_13_8, pro_Incomplete,
    'a Q back from beyond the kept levels');
  Keys := '';
  for I := 1 to 100 do
    Keys := Keys + '/K' + IntToAnsi(I) + ' 0 ';
  CheckOutcome(ContentPdf('/Span << ' + Keys + '>> BDC EMC 2147483648 w', '', '', '', NoExtra), par_6_1_13_1,
    pro_Failed, '100 keys');
  CheckOutcome(ContentPdf('/Span << ' + Keys + '/K0 0 >> BDC EMC 2147483648 w', '', '', '', NoExtra), par_6_1_13_1,
    pro_Incomplete, '101 keys: not decided');
end;

{ Round 65 of the reviews: uncoloured tiling patterns, tiling patterns in
  colour space positions, a pattern resource with an underlying space. }
procedure TestPdfAContent9;
var
  Pat, P1: AnsiString;
begin
  Pat := StreamObj(11, Saves(29), ' /PatternType 1 /PaintType 1 /TilingType 1 /BBox [0 0 1 1] /XStep 1 /YStep 1 ' +
    '/Resources << >>');
  CheckOutcome(ContentPdf('/Pattern cs /PU scn /PC scn', '', '', '/Pattern << /PU 12 0 R /PC 13 0 R >>',
    [StreamObj(12, 'q Q', ' /PatternType 1 /PaintType 2 /TilingType 1 /BBox [0 0 1 1] /XStep 1 /YStep 1'),
    StreamObj(13, '99999999999 g', ' /PatternType 1 /PaintType 1 /TilingType 1 /BBox [0 0 1 1] /XStep 1 /YStep 1')]),
    par_6_1_13_1, pro_Incomplete, 'an uncoloured pattern turns colour off for all');
  CheckOutcome(ContentPdf('/CS1 cs', '', '', '/ColorSpace << /CS1 11 0 R >>', [Pat]), par_6_1_13_8, pro_Incomplete,
    'a tiling pattern as a colour space');
  P1 := StreamObj(12, '/P2 scn', ' /PatternType 1 /PaintType 1 /TilingType 1 /BBox [0 0 1 1] /XStep 1 /YStep 1 ' +
    '/Resources << >>');
  CheckOutcome(ContentPdf('/Pattern cs /PA scn /P1 scn', '', '', '/ColorSpace << /DefaultGray /Pattern >> ' +
    '/Pattern << /PA [/Pattern /DeviceRGB] /P1 12 0 R /P2 11 0 R >>', [Pat, P1]), par_6_1_13_8, pro_Incomplete,
    'a pattern resource with an underlying space');
  CheckOutcome(ContentPdf('/Pattern cs /P1 scn', '', '', '/Pattern << /P1 11 0 R >>', [Pat]), par_6_1_13_8,
    pro_Failed, 'a tiling pattern only as a pattern');
end;

{ Stage D1 of 6.2: undefined operators, graphics states, halftones,
  rendering intents, images, masks, forms, PostScript XObjects and blend
  modes, on the objects veraPDF builds from the content it reads. }
procedure TestPdfAGraphics;
const
  NoExtra: array[0..0] of AnsiString = ('');
var
  Ht1, Img, Form, Annot: AnsiString;
begin
  { 6.2.2-1 }
  CheckOutcome(ContentPdf('q Unknown Q', '', '', '', NoExtra), par_6_2_2_1, pro_Failed, 'an undefined operator');
  CheckOutcome(ContentPdf('BX Unknown EX', '', '', '', NoExtra), par_6_2_2_1, pro_Failed, 'BX does not excuse it');
  CheckOutcome(ContentPdf('true false null q Q', '', '', '', NoExtra), par_6_2_2_1, pro_Passed,
    'true, false and null are operands');
  CheckOutcome(ContentPdf('BI /W 1 /H 1 /CS /G /BPC 8 ID x EI EI Q', '', '', '', NoExtra), par_6_2_2_1, pro_Failed,
    'EI before EI ends the image, the second is undefined');
  CheckOutcome(ContentPdf('BI /W 1 /H 1 /CS /G /BPC 8 /L 11.0 ID xEI /Bad ri EI Q', '', '', '', NoExtra),
    par_6_2_6_1, pro_Passed, 'an inline /L 11.0 counts as 11');
  CheckOutcome(ContentPdf('/F Do', '', '', '/XObject << /F 10 0 R >>',
    [StreamObj(10, 'Unknown', ' /Type /XObject /Subtype /Form /BBox [0 0 1 1]')]), par_6_2_2_1, pro_Failed,
    'an undefined operator in a form');
  CheckOutcome(ContentPdf('q Q', '', '', '', [StreamObj(10, 'Unknown', '')]), par_6_2_2_1, pro_Passed,
    'a stream nothing reaches');

  { 6.2.5-1 to -3 }
  CheckOutcome(ContentPdf('/G gs', '', '', '/ExtGState << /G << /TR 10 0 R >> >>', [ObjText(10, 'null')]),
    par_6_2_5_1, pro_Failed, '/TR referring to null is there');
  CheckOutcome(ContentPdf('q Q', '', '', '/ExtGState << /G << /TR /Identity >> >>', NoExtra), par_6_2_5_1,
    pro_Passed, 'an ExtGState no gs selects');
  CheckOutcome(ContentPdf('/G gs', '', '', '/ExtGState << /G << /TR null >> >>', NoExtra), par_6_2_5_1, pro_Passed,
    'a direct null is no key');
  CheckOutcome(ContentPdf('/G gs', '', '', '/ExtGState << /G << /TR2 /Default >> >>', NoExtra), par_6_2_5_2,
    pro_Passed, '/TR2 /Default');
  CheckOutcome(ContentPdf('/G gs', '', '', '/ExtGState << /G << /TR2 (Default) >> >>', NoExtra), par_6_2_5_2,
    pro_Failed, '/TR2 as a string');
  CheckOutcome(ContentPdf('/G gs', '', '', '/ExtGState << /G << /HTP [0 1] >> >>', NoExtra), par_6_2_5_3, pro_Failed,
    '/HTP');

  { 6.2.5-4 to -6 }
  CheckOutcome(ContentPdf('/G gs', '', '', '/ExtGState << /G << /HT /Default >> >>', NoExtra), par_6_2_5_4,
    pro_Passed, '/HT /Default');
  CheckOutcome(ContentPdf('/G gs', '', '', '/ExtGState << /G << /HT /Bogus >> >>', NoExtra), par_6_2_5_4, pro_Failed,
    'a halftone name has no type');
  CheckOutcome(ContentPdf('/G gs', '', '', '/ExtGState << /G << /HT /Bogus >> >>', NoExtra), par_6_2_5_5, pro_Failed,
    'a halftone name is its name');
  CheckOutcome(ContentPdf('/G gs', '', '', '/ExtGState << /G << /HT << /HalftoneType 1.9 >> >> >>', NoExtra),
    par_6_2_5_4, pro_Passed, 'HalftoneType 1.9 reads as 1');
  CheckOutcome(ContentPdf('/G gs', '', '', '/ExtGState << /G << /HT << /HalftoneType 6 >> >> >>', NoExtra),
    par_6_2_5_4, pro_Failed, 'HalftoneType 6');
  CheckOutcome(ContentPdf('/G gs', '', '', '/ExtGState << /G << /HT << /HalftoneType 1 /HalftoneName /N >> >> >>',
    NoExtra), par_6_2_5_5, pro_Passed, 'a /HalftoneName name is none');
  CheckOutcome(ContentPdf('/G gs', '', '', '/ExtGState << /G << /HT << /HalftoneType 1 /HalftoneName () >> >> >>',
    NoExtra), par_6_2_5_5, pro_Failed, 'an empty /HalftoneName string');
  CheckOutcome(ContentPdf('/G gs', '', '', '/ExtGState << /G << /HT << /HalftoneType 1 /TransferFunction /Identity ' +
    '>> >> >>', NoExtra), par_6_2_5_6, pro_Failed, 'a transfer function at the top level');
  CheckOutcome(ContentPdf('/G gs', '', '', '/ExtGState << /G << /HT << /HalftoneType 1 /TransferFunction () >> >> >>',
    NoExtra), par_6_2_5_6, pro_Failed, 'an empty transfer function is one');
  CheckOutcome(ContentPdf('/G gs', '', '', '/ExtGState << /G << /HT << /HalftoneType 5 /Default << /HalftoneType 1 ' +
    '/TransferFunction /Identity >> /Cyan << /HalftoneType 1 >> /Spot << /HalftoneType 1 /TransferFunction /Identity ' +
    '>> >> >> >>', NoExtra), par_6_2_5_6, pro_Passed, 'Type 5 with the colorants as required');
  CheckOutcome(ContentPdf('/G gs', '', '', '/ExtGState << /G << /HT << /HalftoneType 5 /Red << /HalftoneType 1 >> ' +
    '>> >> >>', NoExtra), par_6_2_5_6, pro_Failed, 'a spot colorant without transfer function');
  Ht1 := ObjText(10, '<< /HalftoneType 1 >>');
  CheckOutcome(ContentPdf('/G gs', '', '', '/ExtGState << /G << /HT << /HalftoneType 5 /Spot 10 0 R >> >> >>', [Ht1]),
    par_6_2_5_6, pro_Failed, 'an indirect halftone met only as a spot colorant');
  CheckOutcome(ContentPdf('/G gs', '', '', '/ExtGState << /G << /HT << /HalftoneType 5 /Default 10 0 R /Spot 10 0 R ' +
    '>> >> >>', [Ht1]), par_6_2_5_6, pro_Incomplete, 'veraPDF checks a shared halftone once');
  CheckOutcome(ContentPdf('/G gs', '', '', '/ExtGState << /G << /HT << /HalftoneType 5 /Spot 10 0 R >> >> >>',
    [Ht1, ObjText(11, '<< /HT 10 0 R >>')]), par_6_2_5_6, pro_Incomplete, 'the same halftone at the top level');

  { 6.2.6-1 }
  CheckOutcome(ContentPdf('/Custom ri', '', '', '', NoExtra), par_6_2_6_1, pro_Failed, 'ri /Custom');
  CheckOutcome(ContentPdf('/Perceptual ri', '', '', '', NoExtra), par_6_2_6_1, pro_Passed, 'ri /Perceptual');
  CheckOutcome(ContentPdf('/Bad# ri', '', '', '', NoExtra), par_6_2_6_1, pro_Incomplete,
    'veraPDF reads a name ending in # past its end');
  CheckOutcome(ContentPdf('0 0 0 0 1 1 d1 /Custom ri', '', '', '', NoExtra), par_6_2_6_1, pro_Passed,
    'ri after d1 is not built');
  CheckOutcome(ContentPdf('0 0 0 0 1 1 d1 /G gs', '', '', '/ExtGState << /G << /RI /Custom >> >>', NoExtra),
    par_6_2_6_1, pro_Failed, 'an ExtGState /RI after d1');
  CheckOutcome(ContentPdf('/G gs', '', '', '/ExtGState << /G << /RI (Custom) >> >>', NoExtra), par_6_2_6_1,
    pro_Passed, 'a string /RI is no intent');
  CheckOutcome(ContentPdf('BI /W 1 /H 1 /CS /G /BPC 8 /Intent /Custom ID x EI', '', '', '', NoExtra), par_6_2_6_1,
    pro_Failed, 'an inline image intent');

  { 6.2.10-1 }
  CheckOutcome(ContentPdf('/G gs', '', '', '/ExtGState << /G << /BM /Custom >> >>', NoExtra), par_6_2_10_1,
    pro_Failed, '/BM /Custom');
  CheckOutcome(ContentPdf('/G gs', '', '', '/ExtGState << /G << /BM [27 /Normal /Foo] >> >>', NoExtra),
    par_6_2_10_1, pro_Passed, 'the first name of an array counts');
  CheckOutcome(ContentPdf('/G gs', '', '', '/ExtGState << /G << /BM [27 /Foo /Normal] >> >>', NoExtra),
    par_6_2_10_1, pro_Failed, 'the first name of an array fails');

  { 6.2.8 }
  Img := ' /Type /XObject /Subtype /Image /Width 1 /Height 1 /ColorSpace /DeviceGray /BitsPerComponent 8';
  CheckOutcome(ContentPdf('/I Do', '', '', '/XObject << /I 10 0 R >>', [StreamObj(10, 'x', Img +
    ' /Alternates []')]), par_6_2_8_1, pro_Failed, '/Alternates');
  CheckOutcome(ContentPdf('/I Do', '', '', '/XObject << /I 10 0 R >>', [StreamObj(10, 'x', Img + ' /OPI 11 0 R')]),
    par_6_2_8_2, pro_Failed, '/OPI');
  CheckOutcome(ContentPdf('/I Do', '', '', '/XObject << /I << /Subtype /Image /Interpolate true >> >>', NoExtra),
    par_6_2_8_3, pro_Failed, 'an image dictionary that is no stream');
  CheckOutcome(ContentPdf('q Q', '', '', '/XObject << /I 10 0 R >>', [StreamObj(10, 'x', Img +
    ' /Interpolate true')]), par_6_2_8_3, pro_Passed, 'an image no Do uses');
  CheckOutcome(ContentPdf('/I Do', '', '', '/XObject << /I 10 0 R >>', [StreamObj(10, 'x',
    ' /Subtype /Image /Width 1 /Height 1 /ImageMask true /BitsPerComponent 3')]), par_6_2_8_4, pro_Failed,
    '/ImageMask true is no image mask for the rule');
  CheckOutcome(ContentPdf('/I Do', '', '', '/XObject << /I 10 0 R >>', [StreamObj(10, 'x', Img + ' /Mask 11 0 R'),
    StreamObj(11, 'x', ' /Subtype /Image /Width 1 /Height 1 /BitsPerComponent 8')]), par_6_2_8_5, pro_Failed,
    'a /Mask stream is an image mask');
  CheckOutcome(ContentPdf('/I Do', '', '', '/XObject << /I 10 0 R >>', [StreamObj(10, 'x', Img + ' /Mask 11 0 R'),
    StreamObj(11, 'x', ' /Subtype /Image /Width 1 /Height 1 /BitsPerComponent 3')]), par_6_2_8_4, pro_Passed,
    'an image mask is exempt from 6.2.8-4');
  CheckOutcome(ContentPdf('/I Do', '', '', '/XObject << /I 10 0 R >>', [StreamObj(10, 'x', Img + ' /SMask 11 0 R'),
    StreamObj(11, 'x', ' /Subtype /Image /Width 1 /Height 1 /BitsPerComponent 3')]), par_6_2_8_4, pro_Failed,
    'a soft mask is an image');
  CheckOutcome(ContentPdf('/I Do', '', '', '/XObject << /I 10 0 R >>', [StreamObj(10, 'x', Img +
    ' /BitsPerComponent (123)')]), par_6_2_8_4, pro_Failed, 'a string counts its bytes');
  CheckOutcome(ContentPdf('/I Do', '', '', '/XObject << /I 10 0 R >>', [StreamObj(10, 'x', Img +
    ' /Alternates [<< /Image 11 0 R >>]'), StreamObj(11, 'x', ' /Subtype /Image /Interpolate true')]), par_6_2_8_3,
    pro_Failed, 'an alternate image');
  CheckOutcome(ContentPdf('/I Do', '', '', '/XObject << /I 10 0 R >>', [StreamObj(10, 'x', Img +
    ' /Alternates [<< /DefaultForPrinting true >>]')]), par_6_2_8_3, pro_Incomplete,
    'an alternate without an image makes veraPDF throw');
  CheckOutcome(ContentPdf('/Custom ri', '', '', '', [StreamObj(10, 'x', Img + ' /Alternates [<< >>]')]), par_6_2_6_1,
    pro_Incomplete, 'veraPDF may meet the throwing alternate anywhere');
  CheckOutcome(ContentPdf('/I Do', '', '', '/XObject << /I 10 0 R >>', [StreamObj(10, 'x', Img +
    ' /Alternates [<< >>]')]), par_6_2_8_1, pro_Incomplete, 'veraPDF throws and reports no /Alternates');
  CheckOutcome(ContentPdf('/I Do', '', '', '/XObject << /I 10 0 R >>', [StreamObj(10, 'x', Img +
    ' /Alternates [11 0 R]'), StreamObj(11, 'x', ' /Image 12 0 R')]), par_6_2_8_1, pro_Failed,
    'a stream in /Alternates is skipped');
  CheckOutcome(ContentPdf('BI /W 1 /H 1 /CS /G /BPC (123) ID x EI', '', '', '', NoExtra), par_6_2_8_4, pro_Failed,
    'an inline /BPC string of three bytes');
  CheckOutcome(ContentPdf('BI /W 1 /H 1 /CS /G /BPC (12345678) ID x EI', '', '', '', NoExtra), par_6_2_8_4,
    pro_Passed, 'an inline /BPC string of eight bytes');
  CheckOutcome(ContentPdf('BI /W 1 /H 1 /CS /G /BPC <~z~> ID x EI', '', '', '', NoExtra), par_6_2_8_4,
    pro_Incomplete, 'veraPDF decodes an ASCII85 string');
  CheckOutcome(ContentPdf('BI /W 1 /H 1 /CS /G /BPC 8 /I false /Interpolate true ID x EI', '', '', '', NoExtra),
    par_6_2_8_3, pro_Passed, '/I comes first');
  CheckOutcome(ContentPdf('BI /W 1 /H 1 /CS /G /BPC 3 ID x EI', '', '', '', NoExtra), par_6_2_8_4, pro_Failed,
    'an inline image with BPC 3');
  CheckOutcome(ContentPdf('0 0 0 0 1 1 d1 BI /W 1 /H 1 /CS /G /BPC 3 ID x EI', '', '', '', NoExtra), par_6_2_8_4,
    pro_Passed, 'no inline image after d1');
  CheckOutcome(ContentPdf('0 0 0 0 1 1 d1 BI /W 1 /H 1 /IM true /BPC 3 ID x EI', '', '', '', NoExtra), par_6_2_8_4,
    pro_Failed, 'an inline image mask after d1');
  CheckOutcome(ContentPdf('BI /W 1 /H 1 /CS /G /BPC 8 /Subtype /PS ID x EI', '', '', '', NoExtra), par_6_2_9_3,
    pro_Passed, 'an inline image has no subtype for veraPDF');

  { 6.2.9 }
  Form := ' /Type /XObject /Subtype /Form /BBox [0 0 1 1]';
  CheckOutcome(ContentPdf('/F Do', '', '', '/XObject << /F 10 0 R >>', [StreamObj(10, '', Form + ' /Subtype2 /PS')]),
    par_6_2_9_1, pro_Failed, '/Subtype2 /PS');
  CheckOutcome(ContentPdf('/F Do', '', '', '/XObject << /F 10 0 R >>', [StreamObj(10, '', Form + ' /Subtype2 (PS)')]),
    par_6_2_9_1, pro_Passed, '/Subtype2 as a string');
  CheckOutcome(ContentPdf('/F Do', '', '', '/XObject << /F 10 0 R >>', [StreamObj(10, '', Form + ' /PS 11 0 R')]),
    par_6_2_9_1, pro_Failed, '/PS');
  CheckOutcome(ContentPdf('/F Do', '', '', '/XObject << /F 10 0 R >>', [StreamObj(10, '', Form +
    ' /Ref << /F (x) /Page 0 >>')]), par_6_2_9_2, pro_Failed, 'a reference XObject');
  CheckOutcome(ContentPdf('/P Do', '', '', '/XObject << /P 10 0 R >>', [StreamObj(10, 'x',
    ' /Type /XObject /Subtype /PS')]), par_6_2_9_3, pro_Failed, 'a PostScript XObject');
  CheckOutcome(ContentPdf('q Q', '', '', '/XObject << /P 10 0 R >>', [StreamObj(10, 'x',
    ' /Type /XObject /Subtype /PS')]), par_6_2_9_3, pro_Passed, 'a PostScript XObject no Do uses');
  Annot := ObjText(10, '<< /Type /Annot /Subtype /Square /Rect [0 0 1 1] /F 4 /AP << /N 11 0 R >> >>');
  CheckOutcome(ContentPdf('', '', '/Annots [10 0 R]', '', [Annot, StreamObj(11, '', ' /Subtype /PS /Ref 12 0 R')]),
    par_6_2_9_3, pro_Failed, 'an appearance stream is a form, whatever its /Subtype');
  CheckOutcome(ContentPdf('', '', '/Annots [10 0 R]', '', [Annot, StreamObj(11, '', ' /Subtype /PS /Ref 12 0 R')]),
    par_6_2_9_2, pro_Failed, 'an appearance stream with /Ref');
  CheckOutcome(ContentPdf('', '', '/Annots [10 0 R]', '', [ObjText(10, '<< /Type /Annot /Subtype /Square ' +
    '/Rect [0 0 1 1] /F 4 /AP 12 0 R >>'), StreamObj(11, 'Unknown', ' /Subtype /Form /Ref 13 0 R'),
    StreamObj(12, '', ' /N 11 0 R')]), par_6_2_9_2, pro_Passed, 'an /AP that is a stream has no appearances');
end;

{ 128 bytes of an ICC profile header: the major version AMajor (byte 8), the
  device class AClass (bytes 12 to 15), the colour space ASpace (bytes 16 to
  19) and the signature acsp. }
function IccHead(const AClass, ASpace: AnsiString; AMajor: Integer): AnsiString;
var
  I: Integer;
begin
  Result := '';
  SetLength(Result, 128);
  for I := 1 to 128 do
    Result[I] := #0;
  Result[9] := AnsiChar(AMajor);
  for I := 1 to 4 do
  begin
    Result[12 + I] := AClass[I];
    Result[16 + I] := ASpace[I];
    Result[36 + I] := AnsiString('acsp')[I];
  end;
end;

{ AData as a zlib stream of one stored block; with ABreak the last byte of
  the Adler-32 check value is wrong. }
function ZlibStored(const AData: AnsiString; ABreak: Boolean): AnsiString;
var
  A, B: Cardinal;
  I, N: Integer;
begin
  N := Length(AData);
  A := 1;
  B := 0;
  for I := 1 to N do
  begin
    A := (A + Ord(AData[I])) mod 65521;
    B := (B + A) mod 65521;
  end;
  if ABreak then
    A := A xor 1;
  Result := AnsiString(#$78#$01#$01);
  Result := Result + AnsiChar(N and $FF);
  Result := Result + AnsiChar(N shr 8);
  Result := Result + AnsiChar((not N) and $FF);
  Result := Result + AnsiChar(((not N) shr 8) and $FF);
  Result := Result + AData;
  Result := Result + AnsiChar(B shr 8);
  Result := Result + AnsiChar(B and $FF);
  Result := Result + AnsiChar(A shr 8);
  Result := Result + AnsiChar(A and $FF);
end;

{ 6.2.3: output intents and their profiles. }
procedure TestPdfAOutputIntents;
const
  NoExtra: array[0..0] of AnsiString = ('');
var
  Rgb, Cmyk, Bad: AnsiString;
  Chain: array of AnsiString;
  I: Integer;
begin
  Bad := StreamObj(10, IccHead('scnr', 'RGB ', 4), ' /N 3');
  Rgb := StreamObj(10, IccHead('mntr', 'RGB ', 4), ' /N 3');
  Cmyk := StreamObj(11, IccHead('prtr', 'CMYK', 2), ' /N 4');
  CheckOutcome(ContentPdf('', '', '', '', NoExtra), par_6_2_3_1, pro_Passed, 'no output intents');
  CheckOutcome(CatalogPdf('/OutputIntents [<< /S /GTS_PDFA1 /DestOutputProfile 10 0 R >>]', '', '', '', '', [Rgb]),
    par_6_2_3_1, pro_Passed, 'a monitor RGB profile');
  CheckOutcome(CatalogPdf('/OutputIntents [<< /S /GTS_PDFA1 /DestOutputProfile 11 0 R >>]', '', '', '', '', [Cmyk]),
    par_6_2_3_1, pro_Passed, 'a printer CMYK profile');
  CheckOutcome(CatalogPdf('/OutputIntents [<< /S /GTS_PDFA1 /DestOutputProfile 10 0 R >>]', '', '', '', '',
    [StreamObj(10, IccHead('scnr', 'RGB ', 4), ' /N 3')]), par_6_2_3_1, pro_Failed, 'an input profile');
  CheckOutcome(CatalogPdf('/OutputIntents [<< /S /GTS_PDFA1 /DestOutputProfile 10 0 R >>]', '', '', '', '',
    [StreamObj(10, IccHead('mntr', 'Lab ', 4), ' /N 3')]), par_6_2_3_1, pro_Failed, 'a Lab profile');
  CheckOutcome(CatalogPdf('/OutputIntents [<< /S /GTS_PDFA1 /DestOutputProfile 10 0 R >>]', '', '', '', '',
    [StreamObj(10, IccHead('mntr', 'RGB ', 5), ' /N 3')]), par_6_2_3_1, pro_Failed, 'ICC version 5');
  CheckOutcome(CatalogPdf('/OutputIntents [<< /S /GTS_PDFA1 /DestOutputProfile 10 0 R >>]', '', '', '', '',
    [StreamObj(10, Copy(IccHead('mntr', 'RGB ', 4), 1, 19), ' /N 3')]), par_6_2_3_1, pro_Incomplete,
    'a short unfiltered header: a stale /Length may cut it');
  CheckOutcome(CatalogPdf('/OutputIntents [<< /S /GTS_PDFA1 /DestOutputProfile 10 0 R >>]', '', '', '', '',
    [StreamObj(10, ZlibStored(Copy(IccHead('mntr', 'RGB ', 4), 1, 19), False), ' /N 3 /Filter /FlateDecode')]),
    par_6_2_3_1, pro_Failed, 'a header too short for the colour space');
  CheckOutcome(CatalogPdf('/OutputIntents [<< /S /GTS_PDFA1 /DestOutputProfile 10 0 R >>]', '', '', '', '',
    [StreamObj(10, IccHead('scnr', 'RGB ', 4), ' /N 3 /Filter [null]')]), par_6_2_3_1, pro_Incomplete,
    'a filter array with null');
  CheckOutcome(CatalogPdf('/OutputIntents [<< /S /GTS_PDFA1 /DestOutputProfile 10 0 R >>]', '', '', '', '',
    ['10 0 obj' + LF + '<< /Length (12345678901234567890123456789012345678901234567890123456789012345678901234' +
    '5678901234567890123456789012345678901234567890123456) /N 3 >>' + LF + 'stream' + LF +
    IccHead('scnr', 'RGB ', 4) + LF + 'endstream' + LF + 'endobj' + LF]), par_6_2_3_1, pro_Incomplete,
    'a /Length that is a string');
  CheckOutcome(CatalogPdf('/OutputIntents [<< /S /GTS_PDFA1 /DestOutputProfile 10 0 R >>]', '', '', '', '',
    [StreamObj(10, Copy(IccHead('mntr', 'RGB ', 4), 1, 20), ' /N 4')]), par_6_2_3_1, pro_Passed,
    'only the header fields count, not /N');
  CheckOutcome(CatalogPdf('/OutputIntents [<< /S /Custom /DestOutputProfile 10 0 R >>]', '', '', '', '',
    [StreamObj(10, IccHead('abst', 'RGB ', 4), ' /N 3')]), par_6_2_3_1, pro_Failed, 'any intent type is checked');
  CheckOutcome(CatalogPdf('/OutputIntents [<< /S /GTS_PDFA1 /DestOutputProfile 10 0 R >>]', '', '', '', '',
    [StreamObj(10, '00', ' /N 3 /Filter /ASCIIHexDecode')]), par_6_2_3_1, pro_Incomplete,
    'a filter veraPDF may read differently');
  CheckOutcome(CatalogPdf('/OutputIntents [<< /S /GTS_PDFA1 /DestOutputProfile 10 0 R >>]', '', '', '', '',
    [ObjText(10, '42')]), par_6_2_3_1, pro_Passed, 'a profile that is no stream is no profile');
  { 6.2.3-2 }
  CheckOutcome(CatalogPdf('/OutputIntents [<< /S /GTS_PDFA1 /DestOutputProfile 10 0 R >> ' +
    '<< /S /GTS_PDFX /DestOutputProfile 10 0 R >>]', '', '', '', '', [Rgb]), par_6_2_3_2, pro_Passed,
    'the same profile');
  CheckOutcome(CatalogPdf('/OutputIntents [<< /S /GTS_PDFA1 /DestOutputProfile 10 0 R >> ' +
    '<< /S /GTS_PDFX /DestOutputProfile 11 0 R >>]', '', '', '', '', [Rgb, Cmyk]), par_6_2_3_2, pro_Failed,
    'two profiles');
  CheckOutcome(CatalogPdf('/OutputIntents [<< /S /GTS_PDFA1 /DestOutputProfile 10 0 R >> ' +
    '<< /S /GTS_PDFX /DestOutputProfile 10 0 R >> << /S /Custom /DestOutputProfile 99 0 R >>]', '', '', '', '',
    [Rgb]), par_6_2_3_2, pro_Failed, 'a reference to a missing object counts');
  CheckOutcome(CatalogPdf('/OutputIntents [<< /S /GTS_PDFA1 /DestOutputProfile 10 0 R >> ' +
    '<< /S /GTS_PDFX /DestOutputProfile 42 >>]', '', '', '', '', [Rgb]), par_6_2_3_2, pro_Passed,
    'a direct value does not count');
  { 6.2.3-3 }
  CheckOutcome(CatalogPdf('/OutputIntents [<< /S /GTS_PDFX /DestOutputProfileRef << >> >>]', '', '', '', '',
    NoExtra), par_6_2_3_3, pro_Failed, 'a PDF/X intent with /DestOutputProfileRef');
  CheckOutcome(CatalogPdf('/OutputIntents [<< /S /GTS_PDFX /DestOutputProfileRef null >>]', '', '', '', '',
    NoExtra), par_6_2_3_3, pro_Passed, 'a direct null is no entry');
  CheckOutcome(CatalogPdf('/OutputIntents [<< /S /GTS_PDFX /DestOutputProfileRef 12 0 R >>]', '', '', '', '',
    [ObjText(12, 'null')]), par_6_2_3_3, pro_Failed, 'a reference to null is an entry');
  CheckOutcome(CatalogPdf('/OutputIntents [<< /S /GTS_PDFA1 /DestOutputProfileRef << >> >>]', '', '', '', '',
    NoExtra), par_6_2_3_3, pro_Passed, 'only PDF/X intents');
  CheckOutcome(CatalogPdf('/OutputIntents [<< /S (GTS_PDFX) /DestOutputProfileRef << >> >>]', '', '', '', '',
    NoExtra), par_6_2_3_3, pro_Passed, 'a string /S is no PDF/X intent');
  { references to another generation lead to null }
  CheckOutcome(CatalogPdf('/OutputIntents [<< /S /GTS_PDFA1 /DestOutputProfile 10 1 R >>]', '', '', '', '', [Bad]),
    par_6_2_3_1, pro_Passed, 'a profile reference of another generation');
  CheckOutcome(CatalogPdf('/OutputIntents [12 1 R]', '', '', '', '',
    [ObjText(12, '<< /S /GTS_PDFX /DestOutputProfileRef true >>')]), par_6_2_3_3, pro_Passed,
    'an intent reference of another generation');
  { the bytes veraPDF reads }
  CheckOutcome(CatalogPdf('/OutputIntents [<< /S /GTS_PDFA1 /DestOutputProfile 10 0 R >>]', '', '', '', '',
    [StreamObj(10, ZlibStored(IccHead('scnr', 'RGB ', 4), False), ' /N 3 /Filter /FlateDecode')]), par_6_2_3_1,
    pro_Failed, 'a FlateDecode profile is read');
  CheckOutcome(CatalogPdf('/OutputIntents [<< /S /GTS_PDFA1 /DestOutputProfile 10 0 R >>]', '', '', '', '',
    [StreamObj(10, ZlibStored(IccHead('mntr', 'RGB ', 4), False), ' /N 3 /Filter [/FlateDecode]')]), par_6_2_3_1,
    pro_Passed, 'a filter array of one FlateDecode');
  CheckOutcome(CatalogPdf('/OutputIntents [<< /S /GTS_PDFA1 /DestOutputProfile 10 0 R >>]', '', '', '', '',
    [StreamObj(10, ZlibStored(IccHead('mntr', 'RGB ', 4), True), ' /N 3 /Filter /FlateDecode')]), par_6_2_3_1,
    pro_Incomplete, 'a damaged check value');
  CheckOutcome(CatalogPdf('/OutputIntents [<< /S /GTS_PDFA1 /DestOutputProfile 10 0 R >>]', '', '', '', '',
    [StreamObj(10, ZlibStored(IccHead('mntr', 'RGB ', 4), False), ' /N 3 /Filter /FlateDecode ' +
    '/DecodeParms << /Predictor 2 /Columns 20 >>')]), par_6_2_3_1, pro_Incomplete, 'a predictor');
  CheckOutcome(CatalogPdf('/OutputIntents [<< /S /GTS_PDFA1 /DestOutputProfile 10 0 R >>]', '', '', '', '',
    [StreamObj(10, ZlibStored(IccHead('mntr', 'RGB ', 4), False), ' /N 3 /Filter /FlateDecode ' +
    '/DP << /Predictor 2 /Columns 20 >>')]), par_6_2_3_1, pro_Incomplete, 'a /DP entry veraPDF ignores');
  CheckOutcome(CatalogPdf('/OutputIntents [<< /S /GTS_PDFA1 /DestOutputProfile 10 0 R >>]', '', '', '', '',
    [StreamObj(10, IccHead('scnr', 'RGB ', 4), ' /N 3 /F (profile.icc)')]), par_6_2_3_1, pro_Incomplete,
    'an external file');
  CheckOutcome(CatalogPdf('/OutputIntents [<< /S /GTS_PDFA1 /DestOutputProfile 10 0 R >>]', '', '', '', '',
    [StreamObj(10, ZlibStored(IccHead('mntr', 'RGB ', 4), False), ' /N 3 /Filter 12 1 R'),
    ObjText(12, '/FlateDecode')]), par_6_2_3_1, pro_Incomplete, 'a filter reference of another generation');
  CheckOutcome(CatalogPdf('/OutputIntents [<< /S /GTS_PDFA1 /DestOutputProfile 10 0 R >>]', '', '', '', '',
    ['10 0 obj' + LF + '<< /Length 12 1 R /N 3 >>' + LF + 'stream' + LF + IccHead('mntr', 'RGB ', 4) + LF +
    'endstream' + LF + 'endobj' + LF, ObjText(12, '19')]), par_6_2_3_1, pro_Incomplete,
    'a length reference of another generation');
  { a chain of 40 references: veraPDF follows it }
  Chain := nil;
  SetLength(Chain, 41);
  for I := 0 to 39 do
    Chain[I] := ObjText(10 + I, IntToAnsi(11 + I) + ' 0 R');
  Chain[40] := StreamObj(50, IccHead('scnr', 'RGB ', 4), ' /N 3');
  CheckOutcome(CatalogPdf('/OutputIntents [<< /S /GTS_PDFA1 /DestOutputProfile 10 0 R >>]', '', '', '', '', Chain),
    par_6_2_3_1, pro_Incomplete, 'a reference chain too long to follow');
end;

{ 6.2.4.2-2 and 6.2.4.4-2: overprint with ICCBased CMYK, Separation
  consistency. }
procedure TestPdfAColour2;
const
  NoExtra: array[0..0] of AnsiString = ('');
  Cs0 = '/ColorSpace << /CS0 [/ICCBased 11 0 R] >>';
  Fn = '<< /FunctionType 2 /Domain [0 1] /C0 [0 0 0 0] /C1 [1 1 1 1] /N 1 >>';
var
  Cmyk: AnsiString;
begin
  Cmyk := StreamObj(11, IccHead('prtr', 'CMYK', 2), ' /N 4');
  { overprint }
  CheckOutcome(ContentPdf('/GS1 gs /CS0 CS 1 1 1 1 SCN 0 0 10 10 re S', '', '',
    Cs0 + ' /ExtGState << /GS1 << /OP true /OPM 1 >> >>', [Cmyk]), par_6_2_4_2_2, pro_Failed,
    'stroking with overprint and OPM 1');
  CheckOutcome(ContentPdf('/GS1 gs /CS0 cs 1 1 1 1 scn 0 0 10 10 re f', '', '',
    Cs0 + ' /ExtGState << /GS1 << /OP true /OPM 1 >> >>', [Cmyk]), par_6_2_4_2_2, pro_Failed,
    'filling takes /OP without /op');
  CheckOutcome(ContentPdf('/GS1 gs /CS0 cs 1 1 1 1 scn 0 0 10 10 re f', '', '',
    Cs0 + ' /ExtGState << /GS1 << /OP true /op false /OPM 1 >> >>', [Cmyk]), par_6_2_4_2_2, pro_Passed,
    '/op false for filling');
  CheckOutcome(ContentPdf('/GS1 gs /CS0 cs 1 1 1 1 scn 0 0 10 10 re f', '', '',
    Cs0 + ' /ExtGState << /GS1 << /OP true /OPM 0 >> >>', [Cmyk]), par_6_2_4_2_2, pro_Passed, 'OPM 0');
  CheckOutcome(ContentPdf('/GS1 gs /CS0 cs 1 1 1 1 scn', '', '',
    Cs0 + ' /ExtGState << /GS1 << /OP true /OPM 1 >> >>', [Cmyk]), par_6_2_4_2_2, pro_Passed,
    'selecting the space paints nothing');
  CheckOutcome(ContentPdf('q /GS1 gs Q /CS0 cs 1 1 1 1 scn 0 0 10 10 re f', '', '',
    Cs0 + ' /ExtGState << /GS1 << /OP true /OPM 1 >> >>', [Cmyk]), par_6_2_4_2_2, pro_Passed, 'Q restores');
  CheckOutcome(ContentPdf('/GS1 gs /CS0 cs 1 1 1 1 scn 0 0 10 10 re f', '', '',
    Cs0 + ' /ExtGState << /GS1 << /OP true /OPM (x) >> >>', [Cmyk]), par_6_2_4_2_2, pro_Incomplete,
    'a string OPM is not decided');
  CheckOutcome(ContentPdf('/GS1 gs /CS1 cs 0 scn 0 0 10 10 re f', '', '',
    '/ColorSpace << /CS1 [/Indexed [/ICCBased 11 0 R] 0 <00000000>] >> /ExtGState << /GS1 << /OP true /OPM 1 >> >>',
    [Cmyk]), par_6_2_4_2_2, pro_Passed, 'a nested CMYK space carries no overprint');
  CheckOutcome(ContentPdf('/GS1 gs /CS0 cs /Fm1 Do', '', '',
    Cs0 + ' /ExtGState << /GS1 << /OP true /OPM 1 >> >> /XObject << /Fm1 12 0 R >>',
    [Cmyk, StreamObj(12, '0 0 1 1 re f', ' /Type /XObject /Subtype /Form /BBox [0 0 1 1]')]), par_6_2_4_2_2,
    pro_Failed, 'a form inherits the overprint state');
  CheckOutcome(ContentPdf('/GS1 gs /CS0 cs 1 1 1 1 scn BT (a) Tj ET', '', '',
    Cs0 + ' /ExtGState << /GS1 << /op true /OPM 1 >> >>', [Cmyk]), par_6_2_4_2_2, pro_Failed, 'filled text');
  { Separation consistency }
  CheckOutcome(ContentPdf('/A cs /B cs', '', '',
    '/ColorSpace << /A [/Separation /Spot /DeviceCMYK 13 0 R] /B [/Separation /Spot /DeviceRGB 13 0 R] >>',
    [ObjText(13, Fn)]), par_6_2_4_4_2, pro_Failed, 'another alternate space');
  CheckOutcome(ContentPdf('/A cs /B cs', '', '',
    '/ColorSpace << /A [/Separation /Spot /DeviceCMYK 13 0 R] /B [/Separation /Spot /DeviceCMYK 13 0 R] >>',
    [ObjText(13, Fn)]), par_6_2_4_4_2, pro_Passed, 'the same alternate and tint transform');
  CheckOutcome(ContentPdf('/A cs /B cs', '', '',
    '/ColorSpace << /A [/Separation /Spot /DeviceCMYK 13 0 R] /B [/Separation /Spot /DeviceCMYK 14 0 R] >>',
    [ObjText(13, Fn), ObjText(14, Fn)]), par_6_2_4_4_2, pro_Passed, 'equal tint transforms in two objects');
  CheckOutcome(ContentPdf('/A cs /B cs', '', '',
    '/ColorSpace << /A [/Separation /Spot /DeviceCMYK 13 0 R] /B [/Separation /Spot /DeviceCMYK 14 0 R] >>',
    [ObjText(13, Fn), ObjText(14, '<< /FunctionType 2 /Domain [0 1] /C0 [0 0 0 0] /C1 [1 0 1 1] /N 1 >>')]),
    par_6_2_4_4_2, pro_Failed, 'different tint transforms');
  CheckOutcome(ContentPdf('/A cs /B cs', '', '',
    '/ColorSpace << /A [/Separation /Spot /DeviceCMYK 13 0 R] /B [/Separation /Spot /DeviceCMYK ' + Fn + '] >>',
    [ObjText(13, Fn)]), par_6_2_4_4_2, pro_Failed, 'a direct tint transform against a reference');
  CheckOutcome(ContentPdf('/A cs /B cs', '', '',
    '/ColorSpace << /A [/Separation /Spot /DeviceCMYK 13 0 R] /B [/Separation /Other /DeviceRGB 13 0 R] >>',
    [ObjText(13, Fn)]), par_6_2_4_4_2, pro_Passed, 'different colourant names');
  CheckOutcome(ContentPdf('/A cs /B cs', '', '',
    '/ColorSpace << /A [/Separation /Spot /DeviceCMYK 13 0 R] /B [/Separation /Spot /Missing 13 0 R] >>',
    [ObjText(13, Fn)]), par_6_2_4_4_2, pro_Incomplete, 'an alternate not built: veraPDF throws');
  CheckOutcome(ContentPdf('/A cs', '', '',
    '/ColorSpace << /A [/Separation /Spot /DeviceCMYK 13 0 R] /B [/Separation /Spot /DeviceRGB 13 0 R] >>',
    [ObjText(13, Fn)]), par_6_2_4_4_2, pro_Passed, 'a Separation not used is not compared');
  { veraPDF may throw: no rule is decided }
  CheckOutcome(ContentPdf('/A cs xyz', '', '', '/ColorSpace << /A [/Separation /Spot /Missing 13 0 R] >>',
    [ObjText(13, Fn)]), par_6_2_2_1, pro_Incomplete, 'a Separation without its alternate leaves every rule open');
  CheckOutcome(ContentPdf('/GS1 gs /CS0 cs 1 1 1 1 scn 0 0 10 10 re f', '', '',
    Cs0 + ' /ExtGState << /GS1 << /OP true /OPM 9151314442816847872.0 >> >>', [Cmyk]), par_6_2_4_2_2, pro_Incomplete,
    'a real overprint mode beyond 2^31 is not decided');
  CheckOutcome(ContentPdf('/GS1 gs /CS0 cs 1 1 1 1 scn 0 0 10 10 re f', '', '',
    Cs0 + ' /ExtGState << /GS1 << /OP true /OPM 0.7 >> >>', [Cmyk]), par_6_2_4_2_2, pro_Passed,
    'a real overprint mode truncates toward zero');
  CheckOutcome(ContentPdf('/GS1 gs /CS0 cs 1 1 1 1 scn 0 0 10 10 re f', '', '',
    Cs0 + ' /ExtGState << /GS1 << /OP true /OPM 4294967296 >> >>', [Cmyk]), par_6_2_4_2_2, pro_Passed,
    'an integer overprint mode keeps its low 32 bits');
  CheckOutcome(ContentPdf('/A cs /B cs', '', '',
    '/ColorSpace << /A [/Separation /Spot /DeviceCMYK << /FunctionType 2 /Domain [0 1] /C0 [0] /C1 [1] /N 1 ' +
    '/Note (A) >>] /B [/Separation /Spot /DeviceCMYK << /FunctionType 2 /Domain [0 1] /C0 [0] /C1 [1] /N 1 ' +
    '/Note <41> >>] >>', NoExtra), par_6_2_4_4_2, pro_Incomplete, 'strings with the same bytes written otherwise');
end;

{ 6.2.4: colour spaces used in content. }
procedure TestPdfAColour;
const
  NoExtra: array[0..0] of AnsiString = ('');
  Intent = '/OutputIntents [<< /S /GTS_PDFA1 /DestOutputProfile 10 0 R >>]';
  ImageDict = ' /Type /XObject /Subtype /Image /Width 1 /Height 1';
var
  Rgb, Cmyk, Good, Bad, Fn, Stencil, Names: AnsiString;
  I: Integer;
begin
  Rgb := StreamObj(10, IccHead('mntr', 'RGB ', 2), ' /N 3');
  Cmyk := StreamObj(10, IccHead('prtr', 'CMYK', 2), ' /N 4');
  Good := StreamObj(11, IccHead('mntr', 'RGB ', 2), ' /N 3');
  Bad := StreamObj(12, IccHead('abst', 'RGB ', 2), ' /N 3');
  Fn := ObjText(13, '<< /FunctionType 2 /Domain [0 1] /C0 [0 0 0 0] /C1 [1 1 1 1] /N 1 >>');
  Stencil := StreamObj(14, 'a', ImageDict + ' /ImageMask true');

  { the operators }
  CheckOutcome(ContentPdf('0 0 1 rg 0 0 10 10 re f', '', '', '', NoExtra), par_6_2_4_3_2, pro_Failed,
    'rg without an output intent');
  CheckOutcome(CatalogPdf(Intent, '0 0 1 rg 0 0 10 10 re f', '', '', '', [Rgb]), par_6_2_4_3_2, pro_Passed,
    'rg with an RGB output intent');
  CheckOutcome(CatalogPdf(Intent, '0 0 1 rg', '', '', '', [Cmyk]), par_6_2_4_3_2, pro_Failed,
    'rg with a CMYK output intent');
  CheckOutcome(CatalogPdf(Intent, '0 0 0 1 k', '', '', '', [Cmyk]), par_6_2_4_3_3, pro_Passed,
    'k with a CMYK output intent');
  CheckOutcome(ContentPdf('0 0 10 10 re f', '', '', '', NoExtra), par_6_2_4_3_4, pro_Failed,
    'painting in the initial DeviceGray');
  CheckOutcome(CatalogPdf(Intent, '0 0 10 10 re f', '', '', '', [Rgb]), par_6_2_4_3_4, pro_Passed,
    'DeviceGray with any output intent');
  CheckOutcome(ContentPdf('0 0 10 10 re n', '', '', '', NoExtra), par_6_2_4_3_4, pro_Passed, 'n paints nothing');
  CheckOutcome(ContentPdf('0.5 SC', '', '', '', NoExtra), par_6_2_4_3_4, pro_Passed, 'SC links no space');
  CheckOutcome(ContentPdf('0.5 SCN', '', '', '', NoExtra), par_6_2_4_3_4, pro_Failed, 'SCN links the stroke space');
  CheckOutcome(ContentPdf('/Bad cs', '', '', '', NoExtra), par_6_2_4_3_4, pro_Failed,
    'cs with an unknown name links the empty space');
  CheckOutcome(ContentPdf('0 0 0 0 0 0 d1 1 0 0 rg', '', '', '', NoExtra), par_6_2_4_3_2, pro_Passed,
    'no colour after d1');
  CheckOutcome(ContentPdf('BT 3 Tr (a) Tj ET', '', '', '', NoExtra), par_6_2_4_3_4, pro_Passed, 'invisible text');
  CheckOutcome(ContentPdf('BT (a) Tj ET', '', '', '', NoExtra), par_6_2_4_3_4, pro_Failed, 'filled text');
  CheckOutcome(ContentPdf('/Pattern cs /P0 scn', '', '', '', NoExtra), par_6_2_4_3_4, pro_Failed,
    'a pattern name that selects nothing');

  { defaults and ICC profiles }
  CheckOutcome(ContentPdf('1 0 0 rg 0 0 10 10 re f', '', '', '/ColorSpace << /DefaultRGB [/ICCBased 11 0 R] >>',
    [Good]), par_6_2_4_3_2, pro_Passed, '/DefaultRGB replaces DeviceRGB');
  CheckOutcome(ContentPdf('1 0 0 rg', '', '', '/ColorSpace << /DefaultRGB [/ICCBased 11 0 R] >>', [Good]),
    par_6_2_4_2_1, pro_Passed, 'a monitor input profile');
  CheckOutcome(ContentPdf('1 0 0 rg', '', '', '/ColorSpace << /DefaultRGB [/ICCBased 12 0 R] >>', [Bad]),
    par_6_2_4_2_1, pro_Failed, 'an abstract profile');
  CheckOutcome(ContentPdf('1 0 0 rg', '', '', '/ColorSpace << /DefaultRGB /DeviceCMYK /DefaultCMYK /DeviceGray >>',
    NoExtra), par_6_2_4_3_3, pro_Incomplete, 'a default reached from a default');
  CheckOutcome(ContentPdf('/A cs /B cs', '', '', '/ColorSpace << /A [/ICCBased 11 0 R] /B [/ICCBased 12 0 R] >>',
    [Good, Bad]), par_6_2_4_2_1, pro_Failed, 'two direct RGB profiles');
  CheckOutcome(ContentPdf('/A cs /B cs', '', '', '/ColorSpace << /A [/ICCBased 11 0 R] /B [/ICCBased 12 0 R] >>',
    [StreamObj(11, IccHead('prtr', 'CMYK', 2), ' /N 4'), StreamObj(12, IccHead('abst', 'CMYK', 2), ' /N 4')]),
    par_6_2_4_2_1, pro_Incomplete, 'direct CMYK profiles share one identity');

  { nested spaces }
  CheckOutcome(ContentPdf('/CS0 cs 1 scn 0 0 10 10 re f', '', '',
    '/ColorSpace << /CS0 [/Separation /Spot /DeviceCMYK 13 0 R] >>', [Fn]), par_6_2_4_3_3, pro_Failed,
    'the alternate of a Separation space');
  CheckOutcome(CatalogPdf(Intent, '/CS0 cs 1 scn 0 0 10 10 re f', '', '',
    '/ColorSpace << /CS0 [/Separation /Spot /DeviceCMYK 13 0 R] >>', [Cmyk, Fn]), par_6_2_4_3_3, pro_Passed,
    'a CMYK alternate with a CMYK output intent');
  CheckOutcome(ContentPdf('/CS0 cs', '', '', '/ColorSpace << /CS0 [/Indexed /DeviceRGB 1 <000000FFFFFF>] >>',
    NoExtra), par_6_2_4_3_2, pro_Failed, 'the base of an Indexed space');
  CheckOutcome(ContentPdf('/CS0 cs', '', '', '/ColorSpace << /CS0 [/Indexed /Missing 1 <0000>] >>', NoExtra),
    par_6_2_4_3_4, pro_Failed, 'an Indexed base that is not built');

  { DeviceN }
  Names := '';
  for I := 1 to 33 do
    Names := Names + ' /None';
  CheckOutcome(ContentPdf('/CS0 cs', '', '', '/ColorSpace << /CS0 [/DeviceN [' + Names + '] /DeviceCMYK 13 0 R] >>',
    [Fn]), par_6_1_13_9, pro_Failed, '33 colourants');
  CheckOutcome(ContentPdf('/CS0 cs', '', '', '/ColorSpace << /CS0 [/DeviceN [' + Copy(Names, 7, MaxInt) +
    '] /DeviceCMYK 13 0 R] >>', [Fn]), par_6_1_13_9, pro_Passed, '32 colourants');
  CheckOutcome(ContentPdf('/CS0 cs', '', '', '/ColorSpace << /CS0 [/DeviceN [/Spot] /DeviceCMYK 13 0 R] >>', [Fn]),
    par_6_2_4_4_1, pro_Failed, 'a spot colourant without /Colorants');
  CheckOutcome(ContentPdf('/CS0 cs', '', '', '/ColorSpace << /CS0 [/DeviceN [/Spot] /DeviceCMYK 13 0 R ' +
    '<< /Colorants << /Spot [/Separation /Spot /DeviceCMYK 13 0 R] >> >>] >>', [Fn]), par_6_2_4_4_1, pro_Passed,
    'a spot colourant in /Colorants');
  CheckOutcome(ContentPdf('/CS0 cs', '', '', '/ColorSpace << /CS0 [/DeviceN [/Spot] /DeviceCMYK 13 0 R ' +
    '<< /Process << /ColorSpace /DeviceCMYK /Components [/Spot] >> >>] >>', [Fn]), par_6_2_4_4_1, pro_Passed,
    'a process component');
  CheckOutcome(ContentPdf('/CS0 cs', '', '', '/ColorSpace << /CS0 [/DeviceN [/Cyan /None] /DeviceCMYK 13 0 R] >>',
    [Fn]), par_6_2_4_4_1, pro_Passed, 'process and None colourants');

  { images, shadings, groups }
  CheckOutcome(ContentPdf('/Im1 Do', '', '', '/XObject << /Im1 14 0 R >>',
    [StreamObj(14, 'abc', ImageDict + ' /ColorSpace /DeviceRGB /BitsPerComponent 8')]), par_6_2_4_3_2, pro_Failed,
    'an RGB image');
  CheckOutcome(ContentPdf('/Im1 Do', '', '', '/XObject << /Im1 14 0 R >>',
    [StreamObj(14, 'abc', ImageDict + ' /BitsPerComponent 8')]), par_6_2_4_3_4, pro_Passed,
    'an image without a colour space links none');
  CheckOutcome(ContentPdf('/Im1 Do', '', '', '/XObject << /Im1 14 0 R >>',
    [StreamObj(14, 'abc', ImageDict + ' /ColorSpace /DeviceRGB /BitsPerComponent 8 /Filter /JPXDecode')]),
    par_6_2_4_3_2, pro_Incomplete, 'a JPEG 2000 image');
  CheckOutcome(ContentPdf('0 0 0 0 0 0 d1 /Im1 Do', '', '', '/XObject << /Im1 14 0 R >>', [Stencil]),
    par_6_2_4_3_4, pro_Failed, 'a stencil mask takes the fill space, also after d1');
  CheckOutcome(ContentPdf('/Im1 Do /CS0 cs /Im1 Do', '', '',
    '/XObject << /Im1 14 0 R >> /ColorSpace << /CS0 [/ICCBased 11 0 R] >>', [Stencil, Good]), par_6_2_4_3_4,
    pro_Incomplete, 'a shared stencil mask is validated in its first context');
  CheckOutcome(ContentPdf('BI /W 1 /H 1 /CS /RGB /BPC 8 ID abc EI', '', '', '', NoExtra), par_6_2_4_3_2, pro_Failed,
    'an RGB inline image');
  CheckOutcome(ContentPdf('BI /W 1 /H 1 /BPC 8 ID a EI', '', '', '', NoExtra), par_6_2_4_3_4, pro_Failed,
    'an inline image without a colour space');
  CheckOutcome(ContentPdf('/Sh1 sh', '', '',
    '/Shading << /Sh1 << /ShadingType 2 /ColorSpace /DeviceCMYK /Coords [0 0 1 0] /Function 13 0 R >> >>', [Fn]),
    par_6_2_4_3_3, pro_Failed, 'a CMYK shading');
  CheckOutcome(ContentPdf('', '', '/Group << /S /Transparency /CS /DeviceRGB >>', '', NoExtra), par_6_2_4_3_2,
    pro_Failed, 'a page group');
  CheckOutcome(ContentPdf('', '', '/Group << /CS /DeviceRGB >>', '', NoExtra), par_6_2_4_3_2, pro_Failed,
    'a page group without /S');
  CheckOutcome(ContentPdf('/Fm1 Do', '', '', '/XObject << /Fm1 14 0 R >>',
    [StreamObj(14, '', ' /Type /XObject /Subtype /Form /BBox [0 0 1 1] /Group << /S /Transparency /CS /DeviceCMYK >>')]),
    par_6_2_4_3_3, pro_Failed, 'a form group');
  CheckOutcome(ContentPdf('/CS0 cs /Fm1 Do', '', '', '/XObject << /Fm1 14 0 R >> /ColorSpace << /CS0 [/ICCBased 11 0 R] >>',
    [Good, StreamObj(14, '0 0 1 1 re f', ' /Type /XObject /Subtype /Form /BBox [0 0 1 1]')]), par_6_2_4_3_4, pro_Passed,
    'a form keeps the caller''s fill space');
  CheckOutcome(ContentPdf('/Fm1 Do', '', '', '/XObject << /Fm1 14 0 R >> /ColorSpace << /DefaultGray /DeviceRGB >>',
    [StreamObj(14, '0 0 1 1 re f', ' /Type /XObject /Subtype /Form /BBox [0 0 1 1]')]), par_6_2_4_3_2, pro_Failed,
    'a form paints in the page''s initial space');
  CheckOutcome(ContentPdf('BT 3 0 Tr (a) Tj ET', '', '', '', NoExtra), par_6_2_4_3_4, pro_Passed,
    'Tr takes its first operand');
  CheckOutcome(ContentPdf('BT 9 Tr (a) Tj ET', '', '', '', NoExtra), par_6_2_4_3_4, pro_Failed,
    'an invalid rendering mode fills');
  CheckOutcome(ContentPdf('/DeviceRGB cs', '', '', '/ColorSpace << /DefaultRGB 20 0 R >>', NoExtra), par_6_2_4_3_4,
    pro_Failed, 'a default that leads to no object gives the empty space');
  CheckOutcome(ContentPdf('BI /W 1 /H 1 /CS [/Indexed /RGB 0 <000000>] /BPC 8 ID a EI', '', '', '', NoExtra),
    par_6_2_4_3_4, pro_Failed, 'an abbreviation inside an inline array is no device space');
  CheckOutcome(ContentPdf('BI /W 1 /H 1 /CS [/Indexed /RGB 0 <000000>] /BPC 8 ID a EI', '', '', '', NoExtra),
    par_6_2_4_3_2, pro_Passed, 'an abbreviation inside an inline array is not DeviceRGB');
  CheckOutcome(ContentPdf('/Fm1 Do /Fm2 Do', '', '', '/XObject << /Fm1 14 0 R /Fm2 15 0 R >>',
    [StreamObj(14, '', ' /Type /XObject /Subtype /Form /BBox [0 0 1 1] /Group 16 0 R ' +
    '/Resources << /ColorSpace << /C [/CalRGB << /WhitePoint [1 1 1] >>] >> >>'),
    StreamObj(15, '', ' /Type /XObject /Subtype /Form /BBox [0 0 1 1] /Group 16 0 R ' +
    '/Resources << /ColorSpace << /C /DeviceRGB >> >>'), ObjText(16, '<< /S /Transparency /CS /C >>')]),
    par_6_2_4_3_2, pro_Incomplete, 'a shared group is validated in its first context');
  CheckOutcome(ContentPdf('/A Do', '', '', '/XObject << /A << /Subtype /Form /Group << /CS /DeviceRGB >> >> >>',
    NoExtra), par_6_2_4_3_2, pro_Failed, 'the group of a form that is no stream');
  CheckOutcome(ContentPdf('/CS0 cs', '', '', '/ColorSpace << /CS0 [/DeviceN [/Spot] /DeviceCMYK 13 0 R ' +
    '<< /Process 17 0 R >>] >>', [Fn, StreamObj(17, '', ' /Components [/Spot]')]), par_6_2_4_4_1, pro_Passed,
    'process components of a /Process stream');
  CheckOutcome(ContentPdf('/Im1 Do', '', '', '/XObject << /Im1 14 0 R >> /ColorSpace << /DeviceRGB /DeviceCMYK >>',
    [StreamObj(14, 'abc', ImageDict + ' /ColorSpace [/DeviceRGB] /BitsPerComponent 8')]), par_6_2_4_3_2,
    pro_Incomplete, 'a one-name image array the resources may change');
  CheckOutcome(ContentPdf('BI /W 1 /H 1 /CS /RGB /BPC 8 ID abc EI', '', '', '/ColorSpace << /DeviceRGB /DeviceCMYK >>',
    NoExtra), par_6_2_4_3_3, pro_Incomplete, 'an inline name the resources may change');
  CheckOutcome(ContentPdf('BI /W 1 /H 1 /CS [/X] /BPC 8 ID a EI /X cs', '', '',
    '/ColorSpace << /X [/Indexed /DeviceRGB 0 <000000>] >>', NoExtra), par_6_2_4_3_2, pro_Incomplete,
    'an inline array not modelled leaves the colour rules open');
  CheckOutcome(ContentPdf('/CS0 cs', '', '', '/ColorSpace << /CS0 [/Separation /Spot] >>', NoExtra), par_6_2_4_3_4,
    pro_Incomplete, 'a Separation space without an alternate');
  CheckOutcome(ContentPdf('BT 3.0 Tr (a) Tj ET', '', '', '', NoExtra), par_6_2_4_3_4, pro_Incomplete,
    'a real rendering mode');
  CheckOutcome(ContentPdf('BT 1 0 0 rg 1 Tr (a) Tj ET', '', '', '', NoExtra), par_6_2_4_3_4, pro_Failed,
    'stroked text uses the stroke space');
  CheckOutcome(ContentPdf('BT 1 0 0 RG 1 Tr (a) Tj ET', '', '', '', NoExtra), par_6_2_4_3_4, pro_Passed,
    'stroked text does not use the fill space');
  CheckOutcome(ContentPdf('BI /W 1 /H 1 /CS /Fl /BPC 8 ID a EI', '', '',
    '/ColorSpace << /Fl /DeviceCMYK /FlateDecode /DeviceRGB >>', NoExtra), par_6_2_4_3_3, pro_Passed,
    'inline names are expanded like filter names');
  CheckOutcome(ContentPdf('BT 7 Tr (a) Tj ET', '', '', '', NoExtra), par_6_2_4_3_4, pro_Passed, 'clipping text');
  CheckOutcome(CatalogPdf(Intent, '1 0 0 rg 0 0 0 1 k 0 g', '', '', '', [Cmyk]), par_6_2_4_3_4, pro_Passed,
    'DeviceGray with a CMYK output intent');
end;

{ Round 64 of the reviews: a tiling pattern starts with the state its
  calling stream started with, a Type 3 glyph with the current state, an
  underlying pattern space is not followed, exponents are no numbers. }
procedure TestPdfAContent8;
var
  Pat, P1, Font: AnsiString;
begin
  Pat := StreamObj(11, Saves(29), ' /PatternType 1 /PaintType 1 /TilingType 1 /BBox [0 0 1 1] /XStep 1 /YStep 1 ' +
    '/Resources << >>');
  P1 := StreamObj(12, '/P2 scn', ' /PatternType 1 /PaintType 1 /TilingType 1 /BBox [0 0 1 1] /XStep 1 /YStep 1 ' +
    '/Resources << >>');
  CheckOutcome(ContentPdf('/Pattern cs /X Do', '', '', '/Pattern << /P1 12 0 R /P2 11 0 R >> /XObject << /X 13 0 R >>',
    [Pat, P1, StreamObj(13, '/P1 scn', ' /Type /XObject /Subtype /Form /BBox [0 0 1 1]')]), par_6_1_13_8, pro_Failed,
    'a pattern starts with the state its form started with');
  Font := ObjText(14, '<< /Type /Font /Subtype /Type3 /FontBBox [0 0 1 1] /FontMatrix [1 0 0 1 0 0] ' +
    '/CharProcs << /a 15 0 R >> /Encoding << /Type /Encoding /Differences [97 /a] >> /FirstChar 97 /LastChar 97 ' +
    '/Widths [1] >>');
  CheckOutcome(ContentPdf('/Pattern cs BT /F1 1 Tf (a) Tj ET', '', '', '/Font << /F1 14 0 R >> ' +
    '/Pattern << /P2 11 0 R >>', [Pat, Font, StreamObj(15, '/P2 scn', '')]), par_6_1_13_8, pro_Failed,
    'a glyph starts with the current state');
  CheckOutcome(ContentPdf('/PCS cs /P1 scn', '', '', '/ColorSpace << /PCS [/Pattern /DeviceRGB] >> ' +
    '/Pattern << /P1 12 0 R /P2 11 0 R >>', [Pat, P1]), par_6_1_13_8, pro_Incomplete,
    'an underlying pattern space');
  CheckOutcome(ContentPdf('/Pattern cs /P1 scn', '', '', '/Pattern << /P1 11 0 R >>',
    [StreamObj(11, Saves(29), ' /PatternType 1e0 /PaintType 1 /TilingType 1 /BBox [0 0 1 1] ' +
    '/XStep 1 /YStep 1 /Resources << >>')]), par_6_1_13_8, pro_Incomplete, 'an exponent is no number');
end;

{ Round 63 of the reviews: exact large integers, the initial colour space of
  patterns and Type 3 glyphs, aliases only where they were found, deep
  pattern arrays, name tree values through a chain, header generations. }
procedure TestPdfAContent7;
var
  Pat, P1, Pdf, Deep: AnsiString;
  I: Integer;
begin
  Pat := StreamObj(11, Saves(29), ' /PatternType 1 /PaintType 1 /TilingType 1 /BBox [0 0 1 1] /XStep 1 /YStep 1 ' +
    '/Resources << >>');
  CheckOutcome(ContentPdf('/Pattern cs /P1 scn', '', '', '/Pattern << /P1 11 0 R >>',
    [StreamObj(11, Saves(29), ' /PatternType 9007199254740993 /PaintType 1 /TilingType 1 /BBox [0 0 1 1] ' +
    '/XStep 1 /YStep 1 /Resources << >>')]), par_6_1_13_8, pro_Failed, 'a pattern type above 2^53');
  { the pattern's own default does not set its initial space }
  P1 := StreamObj(12, '/P scn', ' /PatternType 1 /PaintType 1 /TilingType 1 /BBox [0 0 1 1] /XStep 1 /YStep 1 ' +
    '/Resources << /ColorSpace << /DefaultGray /Pattern >> /Pattern << /P 11 0 R >> >>');
  CheckOutcome(ContentPdf('/Pattern cs /P1 scn', '', '', '/Pattern << /P1 12 0 R >>', [Pat, P1]), par_6_1_13_8,
    pro_Passed, 'a pattern starts with the top-level space');
  { the page's default does }
  P1 := StreamObj(12, '/P scn', ' /PatternType 1 /PaintType 1 /TilingType 1 /BBox [0 0 1 1] /XStep 1 /YStep 1 ' +
    '/Resources << >>');
  CheckOutcome(ContentPdf('/Pattern cs /P1 scn', '', '', '/ColorSpace << /DefaultGray /Pattern >> ' +
    '/Pattern << /P1 12 0 R /P 11 0 R >>', [Pat, P1]), par_6_1_13_8, pro_Failed,
    'a pattern starts with the page''s default');
  { an alias of a form is not looked up in the page's resources }
  CheckOutcome(ContentPdf('/F Do', '', '', '/ColorSpace << /Alias /Pattern >> /Pattern << /P 11 0 R >> ' +
    '/XObject << /F 12 0 R >>', [Pat, StreamObj(12, '/CS1 cs /P scn', ' /Type /XObject /Subtype /Form ' +
    '/BBox [0 0 1 1] /Resources << /ColorSpace << /CS1 /Alias >> >>')]), par_6_1_13_8, pro_Passed,
    'an alias only where it was found');
  Deep := '11 0 R';
  for I := 1 to 33 do
    Deep := '[' + Deep + ']';
  CheckOutcome(ContentPdf('/Pattern cs /P1 scn', '', '', '/Pattern << /P1 ' + Deep + ' >>', [Pat]), par_6_1_13_8,
    pro_Incomplete, 'thirty-three one-element arrays');
  { a name tree value through an object holding a reference }
  Pdf := BuildPdf(GoodHeader, [
    ObjText(1, '<< /Type /Catalog /Pages 2 0 R /AF [5 0 R] /Names << /EmbeddedFiles << /Names [(a) 7 0 R] >> >> >>'),
    ObjText(2, '<< /Type /Pages /Kids [3 0 R] /Count 1 >>'),
    ObjText(3, '<< /Type /Page /Parent 2 0 R /MediaBox [0 0 612 792] >>'),
    ObjText(5, '<< /F (m) /UF (m) /AFRelationship /Data >>'),
    ObjText(7, '5 0 R')], LF, FileId, LF);
  CheckOutcome(Pdf, par_6_8_4, pro_Passed, 'a name tree value through a chain');
  { a real number as the generation of an object header: not the object }
  CheckOutcome(ContentPdf('/F Do', '', '', '/XObject << /F 13 0 R >>',
    ['13 0.0 obj' + LF + '<< /Length ' + IntToAnsi(Length(Saves(29))) + ' /Type /XObject /Subtype /Form ' +
    '/BBox [0 0 1 1] >>' + LF + 'stream' + LF + Saves(29) + LF + 'endstream' + LF + 'endobj' + LF]), par_6_1_13_8,
    pro_Incomplete, 'a real number as a header generation');
end;

{ Round 62 of the reviews: many tombstones, aliases resolved where they
  were found, defaults before entries, built-in spaces before the page's,
  unusable defaults, deep pattern arrays, /AF through an object holding a
  reference, object headers, large integers, the root in the page check. }
procedure TestPdfAContent6;
const
  NoExtra: array[0..0] of AnsiString = ('');
var
  Pat, Spec, Pdf, Pairs: AnsiString;
  I: Integer;
begin
  Spec := ObjText(10, '<< /Type /Filespec /F (m) /UF (m) /AFRelationship /Data >>');
  Pairs := '';
  for I := 1 to 20000 do
    Pairs := Pairs + '/K 1 /K null ';
  CheckOutcome(ContentPdf('', '', '/X << ' + Pairs + '/K 2147483648 >>', '', NoExtra), par_6_1_13_1, pro_Failed,
    'many tombstones of one key');
  Pat := StreamObj(11, Saves(29), ' /PatternType 1 /PaintType 1 /TilingType 1 /BBox [0 0 1 1] /XStep 1 /YStep 1 ' +
    '/Resources << >>');
  CheckOutcome(ContentPdf('/F Do', '', '', '/ColorSpace << /C /Alias /Alias /Pattern >> /Pattern << /P1 11 0 R >> ' +
    '/XObject << /F 12 0 R >>', [Pat, StreamObj(12, '/C cs /P1 scn', ' /Type /XObject /Subtype /Form ' +
    '/BBox [0 0 1 1] /Resources << /ColorSpace << /Alias /DeviceRGB >> >>')]), par_6_1_13_8, pro_Failed,
    'an alias is resolved where it was found');
  CheckOutcome(ContentPdf('/F Do', '', '', '/ColorSpace << /DeviceRGB /Pattern >> /Pattern << /P1 11 0 R >> ' +
    '/XObject << /F 12 0 R >>', [Pat, StreamObj(12, '0 0 0 rg /P1 scn', ' /Type /XObject /Subtype /Form ' +
    '/BBox [0 0 1 1] /Resources << /ColorSpace << >> >>')]), par_6_1_13_8, pro_Passed,
    'the built-in space before the page''s entry');
  CheckOutcome(ContentPdf('0 g /P1 scn', '', '', '/ColorSpace << /DeviceGray /Pattern /DefaultGray /DeviceRGB >> ' +
    '/Pattern << /P1 11 0 R >>', [Pat]), par_6_1_13_8, pro_Passed, 'the default before the entry');
  CheckOutcome(ContentPdf('/Pattern cs /P1 scn', '', '', '/ColorSpace << /Pattern 7 >> /Pattern << /P1 11 0 R >>',
    [Pat]), par_6_1_13_8, pro_Passed, 'an unusable /Pattern entry');
  CheckOutcome(ContentPdf(Saves(29), '', '', '/ColorSpace << /DefaultGray 9 >>', NoExtra), par_6_1_13_8, pro_Failed,
    'an unusable default leaves the device space');
  CheckOutcome(ContentPdf('/Pattern cs /P1 scn', '', '', '/Pattern << /P1 [[[[[[[[[11 0 R]]]]]]]]] >>', [Pat]),
    par_6_1_13_8, pro_Failed, 'nine one-element arrays');
  CheckOutcome(ContentPdf('', '', '/AF [14 0 R]', '', [Spec, ObjText(14, '10 0 R')]), par_6_8_4, pro_Passed,
    '/AF through an object holding a reference');
  CheckOutcome(ContentPdf('/F Do', '', '', '/XObject << /F 13 0 R >>',
    ['13 1 obj' + LF + '<< /Length 1 /Type /XObject /Subtype /Form /BBox [0 0 1 1] >>' + LF + 'stream' + LF + 'q' + LF +
    'endstream' + LF + 'endobj' + LF]), par_6_1_13_8, pro_Passed, 'an object header of another generation');
  CheckOutcome(ContentPdf('/F Do', '', '', '/XObject << /F 13 0 R >>',
    ['13 x obj' + LF + '<< /Length ' + IntToAnsi(Length(Saves(29))) + ' /Type /XObject /Subtype /Form ' +
    '/BBox [0 0 1 1] >>' + LF + 'stream' + LF + Saves(29) + LF + 'endstream' + LF + 'endobj' + LF]), par_6_1_13_8,
    pro_Incomplete, 'an object header without a generation');
  CheckOutcome(ContentPdf('/Pattern cs /P1 scn', '', '', '/Pattern << /P1 11 0 R >>',
    [StreamObj(11, Saves(29), ' /PatternType 1125899906842625 /PaintType 1 /TilingType 1 /BBox [0 0 1 1] ' +
    '/XStep 1 /YStep 1 /Resources << >>')]), par_6_1_13_8, pro_Failed, 'a large pattern type as an int');
  { the page check: the root is a node }
  Pdf := BuildPdf(GoodHeader, [
    ObjText(1, '<< /Type /Catalog /Pages 2 0 R >>'),
    ObjText(2, '<< /Type /Page /Kids [3 0 R] /Count 1 >>'),
    ObjText(3, '<< /Type /Page /Parent 2 0 R /MediaBox [0 0 612 792] /PresSteps << >> >>')], LF, FileId, LF);
  CheckOutcome(Pdf, par_6_10_2, pro_Failed, 'the page check walks below a root with /Type /Page');
end;

{ Round 59 of the reviews: f/t/n tokens and d0/d1, fonts of Tf and gs, the
  initial pattern space, resource fallback per category, generations on the
  way, /AF owners, intermediate /Count, array identity, null keys, the last
  of repeated keys, BI after EI, unread callers, the live token limit. }
procedure TestPdfAContent3;
const
  NoExtra: array[0..0] of AnsiString = ('');
var
  Pat, Glyph, Font, Spec, Form29, Pdf, K: AnsiString;
begin
  Spec := '10 0 obj' + LF + '<< /Type /Filespec /F (m) /UF (m) /AFRelationship /Data >>' + LF + 'endobj' + LF;
  Form29 := StreamObj(13, Saves(29), ' /Type /XObject /Subtype /Form /BBox [0 0 1 1]');
  CheckOutcome(ContentPdf('f2147483648 w', '', '', '', NoExtra), par_6_1_13_1, pro_Passed,
    'a token starting with f is one operator');
  CheckOutcome(ContentPdf('d1q 2147483648 g', '', '', '', NoExtra), par_6_1_13_1, pro_Failed,
    'd1q is one undefined operator');
  Glyph := StreamObj(11, '0 0 d0 ' + Saves(29), '');
  Font := '10 0 obj' + LF + '<< /Type /Font /Subtype /Type3 /CharProcs << /a 11 0 R >> /FontBBox [0 0 1 1] ' +
    '/FontMatrix [1 0 0 1 0 0] /FirstChar 0 /LastChar 0 /Widths [1] >>' + LF + 'endobj' + LF;
  CheckOutcome(ContentPdf('BT /F1 1 Tf /GS gs () Tj ET', '', '',
    '/Font << /F1 10 0 R >> /ExtGState << /GS << /Font [<< >> 1] >> >>', [Font, Glyph]), par_6_1_13_8, pro_Failed,
    'gs keeps the font where it has none to build');
  CheckOutcome(ContentPdf('BT /F1 1 Tf /F2 1 Tf () Tj ET', '', '', '/Font << /F1 10 0 R >>', [Font, Glyph]),
    par_6_1_13_8, pro_Passed, 'Tf without a font clears it');
  Pat := StreamObj(10, Saves(29), ' /PatternType 1 /PaintType 1 /TilingType 1 /BBox [0 0 1 1] /XStep 1 /YStep 1 ' +
    '/Resources << >>');
  CheckOutcome(ContentPdf('/P1 scn', '', '', '/ColorSpace << /DefaultGray /Pattern >> /Pattern << /P1 10 0 R >>',
    [Pat]), par_6_1_13_8, pro_Failed, 'the initial space is DefaultGray');
  CheckOutcome(ContentPdf('/Pattern cs 0 scn /P1 scn', '', '', '/Pattern << /P1 10 0 R >>', [Pat]), par_6_1_13_8,
    pro_Passed, 'scn without a name leaves the pattern space');
  { a local XObject veraPDF does not build falls back to the page's }
  CheckOutcome(ContentPdf('/F Do', '', '', '/XObject << /F 11 0 R /G 13 0 R >>',
    [StreamObj(11, '/G Do', ' /Type /XObject /Subtype /Form /BBox [0 0 1 1] /Resources << /XObject << /G 12 0 R >> >>'),
    StreamObj(12, 'x', ' /Type /XObject /Subtype /Foo'), Form29]), par_6_1_13_8, pro_Failed,
    'an XObject of unknown subtype falls back');
  { any local /Properties entry hides the page's }
  CheckOutcome(ContentPdf('/F Do', '', '', '/XObject << /F 11 0 R >> /Properties << /MC0 [10 0 R] >>',
    [Spec, StreamObj(11, '/AF /MC0 BDC EMC', ' /Type /XObject /Subtype /Form /BBox [0 0 1 1] ' +
    '/Resources << /Properties << /MC0 7 >> >>')]), par_6_8_4, pro_Failed, 'a local property hides the page''s');
  { generations on the way to an object }
  CheckOutcome(ContentPdf('/F Do', '', '', '/XObject 12 1 R',
    ['12 0 obj' + LF + '<< /F 13 0 R >>' + LF + 'endobj' + LF, Form29]), par_6_1_13_8, pro_Passed,
    'a category dictionary of another generation');
  CheckOutcome(ContentPdf('', '', '/Annots [12 1 R]', '',
    [Spec, '12 0 obj' + LF + '<< /Type /Annot /Subtype /Square /Rect [0 0 1 1] /AF [10 0 R] >>' + LF + 'endobj' + LF]),
    par_6_8_4, pro_Failed, 'an annotation of another generation');
  { /AF owners }
  CheckOutcome(ContentPdf('', '', '/Annots [12 0 R]', '',
    [Spec, StreamObj(12, 'x', ' /Type /Annot /Subtype /Square /Rect [0 0 1 1] /AF [10 0 R]')]), par_6_8_4, pro_Failed,
    'an annotation stream is no annotation');
  CheckOutcome(ContentPdf('', '', '', '/XObject << /I 12 0 R >>',
    [Spec, '12 0 obj' + LF + '<< /Type /XObject /Subtype /Image /AF [10 0 R] >>' + LF + 'endobj' + LF]), par_6_8_4,
    pro_Passed, 'an image XObject dictionary associates');
  { an intermediate /Count hides a page from veraPDF }
  Pdf := BuildPdf(GoodHeader, [
    '1 0 obj' + LF + '<< /Type /Catalog /Pages 2 0 R >>' + LF + 'endobj' + LF,
    '2 0 obj' + LF + '<< /Type /Pages /Kids [3 0 R 4 0 R] /Count 3 >>' + LF + 'endobj' + LF,
    '3 0 obj' + LF + '<< /Type /Page /Parent 2 0 R /MediaBox [0 0 612 792] >>' + LF + 'endobj' + LF,
    '4 0 obj' + LF + '<< /Type /Pages /Parent 2 0 R /Kids [5 0 R 6 0 R] /Count 1 >>' + LF + 'endobj' + LF,
    '5 0 obj' + LF + '<< /Type /Page /Parent 4 0 R /MediaBox [0 0 612 792] >>' + LF + 'endobj' + LF,
    '6 0 obj' + LF + '<< /Type /Page /Parent 4 0 R /MediaBox [0 0 612 792] /Contents 7 0 R >>' + LF + 'endobj' + LF,
    StreamObj(7, '2147483648 w', '')], LF, FileId, LF);
  CheckOutcome(Pdf, par_6_1_13_1, pro_Incomplete, 'an intermediate /Count does not match');
  { two array objects with the same member are two identities }
  Pdf := BuildPdf(GoodHeader, [
    '1 0 obj' + LF + '<< /Type /Catalog /Pages 2 0 R >>' + LF + 'endobj' + LF,
    '2 0 obj' + LF + '<< /Type /Pages /Kids [3 0 R 4 0 R] /Count 2 >>' + LF + 'endobj' + LF,
    '3 0 obj' + LF + '<< /Type /Page /Parent 2 0 R /MediaBox [0 0 612 792] /Contents 20 0 R ' +
    '/Resources << /XObject << /F 13 0 R >> >> >>' + LF + 'endobj' + LF,
    '4 0 obj' + LF + '<< /Type /Page /Parent 2 0 R /MediaBox [0 0 612 792] /Contents 21 0 R >>' + LF + 'endobj' + LF,
    StreamObj(5, '/F Do', ''), Form29,
    '20 0 obj' + LF + '[5 0 R]' + LF + 'endobj' + LF,
    '21 0 obj' + LF + '[5 0 R]' + LF + 'endobj' + LF], LF, FileId, LF);
  CheckOutcome(Pdf, par_6_1_13_8, pro_Failed, 'two arrays with the same member');
  { null removes a key; the last of repeated keys counts }
  K := '/' + Repeated('k', 128);
  CheckOutcome(ContentPdf('', '', '/K << ' + K + ' null >>', '', NoExtra), par_6_1_13_4, pro_Passed,
    'a key with null is removed');
  CheckOutcome(ContentPdf('', '', '/K << ' + K + ' 1 ' + K + ' null >>', '', NoExtra), par_6_1_13_4, pro_Passed,
    'a key replaced by null is removed');
  CheckOutcome(ContentPdf('', '', '/K << ' + K + ' null ' + K + ' 2 >>', '', NoExtra), par_6_1_13_4, pro_Failed,
    'a key set again after null');
  CheckOutcome(ContentPdf('2147483648 w', '', '/Contents 12 0 R', '', [StreamObj(12, '1 w', '')]), par_6_1_13_1,
    pro_Passed, 'the last /Contents counts');
  CheckOutcome(ContentPdf('BI /W 1 /H 1 /CS /G /BPC 8 ID x EI BI /W 1 /H 1 /CS /G /BPC 8 ID y EI 2147483648 w', '', '',
    '', NoExtra), par_6_1_13_1, pro_Incomplete, 'BI after EI is not decided');
  { an unread page may reach the appearance's form first, in another state }
  CheckOutcome(ContentPdf('>', ' /Filter /ASCIIHexDecode', '/Annots [12 0 R]', '',
    [StreamObj(11, '2147483648 g', ' /Type /XObject /Subtype /Form /BBox [0 0 1 1]'),
    '12 0 obj' + LF + '<< /Type /Annot /Subtype /Square /Rect [0 0 1 1] /AP << /N 11 0 R >> >>' + LF + 'endobj' + LF]),
    par_6_1_13_1, pro_Incomplete, 'an appearance behind an unread page');
  CheckOutcome(ContentPdf('[' + Bytes2(500001, '1', ' ') + '] pop 2147483648 w', '', '', '', NoExtra), par_6_1_13_1,
    pro_Incomplete, 'too many values alive');
end;

{ Round 58 of the reviews: operator boundaries, tokens starting with I, the
  inline image length, null values, pattern and default colour spaces,
  generations, the font of a graphics state, the page count, repeated keys,
  long reals, Java's UTF-8 decoding. }
procedure TestPdfAContent2;
const
  NoExtra: array[0..0] of AnsiString = ('');
var
  Pat, Glyph, Font, Pdf: AnsiString;
begin
  CheckOutcome(ContentPdf('2147483648 w%c' + LF + '1 w', '', '', '', NoExtra), par_6_1_13_1, pro_Passed,
    'w%c is one undefined operator');
  CheckOutcome(ContentPdf('q2147483648 w', '', '', '', NoExtra), par_6_1_13_1, pro_Failed, 'q ends at a digit');
  CheckOutcome(ContentPdf('2147483648 w Ix', '', '', '', NoExtra), par_6_1_13_1, pro_Incomplete,
    'a token starting with I is not decided');
  CheckOutcome(ContentPdf('BI /W 1 /H 1 /CS /G /BPC 8 /L 3 ID xEI 2147483648 w', '', '', '', NoExtra), par_6_1_13_1,
    pro_Failed, '/L counts EI');
  CheckOutcome(ContentPdf('/Span << /' + Repeated('k', 128) + ' null >> BDC EMC', '', '', '', NoExtra), par_6_1_13_4,
    pro_Passed, 'a key with null is removed');
  CheckOutcome(ContentPdf('BI /W 1 /H 1 /CS /G /BPC 8 /F null /Filter /LZW ID x EI', '', '', '', NoExtra),
    par_6_1_10_1, pro_Failed, '/F null leaves /Filter');
  Pat := StreamObj(10, Saves(29), ' /PatternType 1 /PaintType 1 /TilingType 1 /BBox [0 0 1 1] /XStep 1 /YStep 1 ' +
    '/Resources << >>');
  CheckOutcome(ContentPdf('/Pattern cs /Missing scn /P1 scn', '', '', '/Pattern << /P1 10 0 R >>', [Pat]),
    par_6_1_13_8, pro_Passed, 'a missing pattern ends the pattern space');
  CheckOutcome(ContentPdf('0 g /P1 scn', '', '', '/ColorSpace << /DefaultGray /Pattern >> /Pattern << /P1 10 0 R >>',
    [Pat]), par_6_1_13_8, pro_Failed, 'DefaultGray is a pattern space');
  CheckOutcome(ContentPdf('/X1 Do', '', '', '/XObject << /X1 10 1 R >>',
    [StreamObj(10, Saves(29), ' /Type /XObject /Subtype /Form /BBox [0 0 1 1]')]), par_6_1_13_8, pro_Passed,
    'a reference with another generation');
  Glyph := StreamObj(11, '0 0 d0 ' + Saves(29), '');
  Font := '10 0 obj' + LF + '<< /Type /Font /Subtype /Type3 /CharProcs << /a 11 0 R >> /FontBBox [0 0 1 1] ' +
    '/FontMatrix [1 0 0 1 0 0] /FirstChar 0 /LastChar 0 /Widths [1] >>' + LF + 'endobj' + LF;
  CheckOutcome(ContentPdf('BT /GS gs () Tj ET', '', '', '/ExtGState << /GS << /Font [10 0 R 1] >> >>', [Font, Glyph]),
    par_6_1_13_8, pro_Failed, 'the font of a graphics state');
  CheckOutcome(ContentPdf(Repeated('0', 405) + Repeated('9', 39) + '.0 w', '', '', '', NoExtra), par_6_1_13_2,
    pro_Failed, 'leading zeros are not cut');
  CheckOutcome(ContentPdf('0.' + Repeated('0', 405) + Repeated('9', 39) + ' w', '', '', '', NoExtra), par_6_1_13_5,
    pro_Incomplete, 'a real that may underflow to zero');
  CheckOutcome(ContentPdf('(' + Bytes3(11000, AnsiChar($ED), AnsiChar($A0), AnsiChar($80)) + ') Tj', '', '', '',
    NoExtra), par_6_1_13_3, pro_Incomplete, 'Java may take three bytes as one malformed sequence');
  { /Count 1 with two pages: veraPDF may see only the first }
  Pdf := BuildPdf(GoodHeader, [
    '1 0 obj' + LF + '<< /Type /Catalog /Pages 2 0 R >>' + LF + 'endobj' + LF,
    '2 0 obj' + LF + '<< /Type /Pages /Kids [3 0 R 4 0 R] /Count 1 >>' + LF + 'endobj' + LF,
    '3 0 obj' + LF + '<< /Type /Page /Parent 2 0 R /MediaBox [0 0 612 792] >>' + LF + 'endobj' + LF,
    '4 0 obj' + LF + '<< /Type /Page /Parent 2 0 R /MediaBox [0 0 612 792] /Contents 5 0 R >>' + LF + 'endobj' + LF,
    StreamObj(5, '2147483648 w', '')], LF, FileId, LF);
  CheckOutcome(Pdf, par_6_1_13_1, pro_Incomplete, '/Count does not match the pages');
  { a repeated key: the dictionary keeps the last value }
  Pdf := BuildPdf(GoodHeader, [
    '1 0 obj' + LF + '<< /Type /Catalog /Pages 2 0 R /K << /X 2147483648 /X 0 >> >>' + LF + 'endobj' + LF,
    '2 0 obj' + LF + '<< /Type /Pages /Kids [3 0 R] /Count 1 >>' + LF + 'endobj' + LF,
    '3 0 obj' + LF + '<< /Type /Page /Parent 2 0 R /MediaBox [0 0 612 792] >>' + LF + 'endobj' + LF], LF, FileId, LF);
  CheckOutcome(Pdf, par_6_1_13_1, pro_Passed, 'a replaced value does not count');
  Pdf := BuildPdf(GoodHeader, [
    '1 0 obj' + LF + '<< /Type /Catalog /Pages 2 0 R /K << /X 0 /X 2147483648 >> >>' + LF + 'endobj' + LF,
    '2 0 obj' + LF + '<< /Type /Pages /Kids [3 0 R] /Count 1 >>' + LF + 'endobj' + LF,
    '3 0 obj' + LF + '<< /Type /Page /Parent 2 0 R /MediaBox [0 0 612 792] >>' + LF + 'endobj' + LF], LF, FileId, LF);
  CheckOutcome(Pdf, par_6_1_13_1, pro_Failed, 'the last value counts');
end;

procedure TestPdfAProperties;
var
  Pdf: AnsiString;
  Facts: TLandrixEInvoicePdfSyntaxFacts;
  Doc: TLandrixEInvoicePdfDocument;
  Rules: TLandrixEInvoicePdfARuleCheck;
begin
  { xmp:CreateDate no date (-2); xmp:Rating .5 (veraPDF reads Real: not
    decided); foo:undefined defined nowhere (-1, -2); urn:my defines size
    (Dimensions, here with a foreign field: -2), pt (MyType, valid) and n
    (Integer, valid) }
  Pdf := BuildPdf(GoodHeader, [
    '1 0 obj' + LF + '<< /Type /Catalog /Pages 2 0 R /Metadata 20 0 R >>' + LF + 'endobj' + LF, Pages,
    MetaObj(20, XmpHead + XmpPdfA3B +
      ExtDesc(ExtSchema('urn:my', ExtProp('size', 'Dimensions') + ExtProp('pt', 'MyType') + ExtProp('n', 'Integer'),
      ExtMyType)) +
      '<rdf:Description rdf:about="" xmlns:xmp="http://ns.adobe.com/xap/1.0/" xmlns:foo="urn:foo" ' +
      'xmp:CreateDate="yesterday" xmp:Rating=".5" foo:undefined="x"/>' + LF +
      '<rdf:Description rdf:about="" xmlns:my="urn:my" xmlns:t="urn:my#t" ' +
      'xmlns:stDim="http://ns.adobe.com/xap/1.0/sType/Dimensions#"><my:size rdf:parseType="Resource">' +
      '<stDim:w>1</stDim:w><stDim:depth>2</stDim:depth></my:size><my:pt rdf:parseType="Resource"><t:f><rdf:Bag>' +
      '<rdf:li>a</rdf:li></rdf:Bag></t:f></my:pt><my:n>7</my:n></rdf:Description>' + LF + XmpTail)], LF, FileId, LF);
  Facts := TLandrixEInvoicePdfSyntaxFacts.Create;
  Rules := TLandrixEInvoicePdfARuleCheck.Create;
  try
    Doc := LoadWithFacts(Pdf, Facts);
    try
      Check(Facts.Complete, 'complete: ' + Facts.Problems.Text);
      Rules.Check(Doc, Facts);
      CheckEqualsStr('6.6.2.3.1-1 6.6.2.3.1-2', FailedRules(Rules), 'failed rules');
      CheckEquals(1, Rules.RuleResult(par_6_6_2_3_1_1).Failures, 'only foo:undefined is undefined: ' +
        Rules.RuleResult(par_6_6_2_3_1_1).Detail);
      CheckEquals(3, Rules.RuleResult(par_6_6_2_3_1_2).Failures, 'CreateDate, foo:undefined and my:size');
    finally
      Doc.Free;
    end;
  finally
    Rules.Free;
    Facts.Free;
  end;

  { the same property in two packets with different answers: veraPDF judges
    it once, which occurrence is not established }
  Pdf := BuildPdf(GoodHeader, [
    '1 0 obj' + LF + '<< /Type /Catalog /Pages 2 0 R /Metadata 20 0 R >>' + LF + 'endobj' + LF,
    '2 0 obj' + LF + '<< /Type /Pages /Kids [3 0 R] /Count 1 >>' + LF + 'endobj' + LF,
    '3 0 obj' + LF + '<< /Type /Page /Parent 2 0 R /MediaBox [0 0 612 792] /Metadata 21 0 R >>' + LF + 'endobj' + LF,
    MetaObj(20, XmpHead + XmpPdfA3B + '<rdf:Description rdf:about="" xmlns:xmp="http://ns.adobe.com/xap/1.0/" ' +
      'xmp:CreateDate="2020-01-01"/>' + LF + XmpTail),
    MetaObj(21, XmpHead + '<rdf:Description rdf:about="" xmlns:xmp="http://ns.adobe.com/xap/1.0/" ' +
      'xmp:CreateDate="never"/>' + LF + XmpTail)], LF, FileId, LF);
  Facts := TLandrixEInvoicePdfSyntaxFacts.Create;
  Rules := TLandrixEInvoicePdfARuleCheck.Create;
  try
    Doc := LoadWithFacts(Pdf, Facts);
    try
      Check(Facts.Complete, 'complete: ' + Facts.Problems.Text);
      Rules.Check(Doc, Facts);
      CheckEqualsStr('', FailedRules(Rules), 'failed rules');
      Check(Rules.RuleResult(par_6_6_2_3_1_2).Outcome = pro_Incomplete, '6.6.2.3.1-2 incomplete');
      Check(Rules.RuleResult(par_6_6_2_3_1_1).Outcome = pro_Passed, '6.6.2.3.1-1 passed');
    finally
      Doc.Free;
    end;
  finally
    Rules.Free;
    Facts.Free;
  end;

  { a wrong date in one page packet, while another page packet is not
    decided (an empty rdf:about after a non-empty one) and may hold the occurrence
    veraPDF judges: not decided }
  Pdf := BuildPdf(GoodHeader, [
    '1 0 obj' + LF + '<< /Type /Catalog /Pages 2 0 R /Metadata 20 0 R >>' + LF + 'endobj' + LF,
    '2 0 obj' + LF + '<< /Type /Pages /Kids [3 0 R 4 0 R] /Count 2 >>' + LF + 'endobj' + LF,
    '3 0 obj' + LF + '<< /Type /Page /Parent 2 0 R /MediaBox [0 0 612 792] /Metadata 21 0 R >>' + LF + 'endobj' + LF,
    '4 0 obj' + LF + '<< /Type /Page /Parent 2 0 R /MediaBox [0 0 612 792] /Metadata 22 0 R >>' + LF + 'endobj' + LF,
    MetaObj(20, XmpHead + XmpPdfA3B + XmpTail),
    MetaObj(21, XmpHead + '<rdf:Description rdf:about="" xmlns:xmp="http://ns.adobe.com/xap/1.0/" ' +
      'xmp:CreateDate="never"/>' + LF + XmpTail),
    MetaObj(22, '<x:xmpmeta xmlns:x="adobe:ns:meta/"><rdf:RDF xmlns:rdf="http://www.w3.org/1999/02/22-rdf-syntax-ns#">' +
      '<rdf:Description rdf:about="a"/>' +
      '<rdf:Description rdf:about="" xmlns:xmp="http://ns.adobe.com/xap/1.0/" xmp:CreateDate="2020"/>' +
      '</rdf:RDF></x:xmpmeta>')], LF, FileId, LF);
  Facts := TLandrixEInvoicePdfSyntaxFacts.Create;
  Rules := TLandrixEInvoicePdfARuleCheck.Create;
  try
    Doc := LoadWithFacts(Pdf, Facts);
    try
      Check(Facts.Complete, 'complete: ' + Facts.Problems.Text);
      Rules.Check(Doc, Facts);
      Check(Rules.RuleResult(par_6_6_2_3_1_2).Outcome = pro_Incomplete, '6.6.2.3.1-2 incomplete: ' +
        Rules.RuleResult(par_6_6_2_3_1_2).Detail);
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

{ Whether the property q:v (urn:q) written as AElement is a value of AType
  among the built-in types. }
function XmpValue(APacket: TLandrixEInvoiceXmpPacket; ATypes: TLandrixEInvoiceXmpSchemaTypes;
  const AElement: AnsiString; const AType: TLandrixEInvoiceString): TLandrixEInvoiceXmpTruth;
begin
  Result := xmt_Unknown;
  if XmpState(APacket, XmpDesc(AElement)) = xms_Valid then
    Result := ATypes.Validate(APacket.Find('urn:q', 'v'), AType, LandrixEInvoiceXmpPredefinedEntry);
end;

procedure TestPdfAXmpReader;
var
  P: TLandrixEInvoiceXmpPacket;
  N: TLandrixEInvoiceXmpNode;
  T: TLandrixEInvoiceXmpSchemaTypes;
begin
  P := TLandrixEInvoiceXmpPacket.Create;
  T := TLandrixEInvoiceXmpSchemaTypes.Create;
  try
    { type names as veraPDF simplifies them, for a schema without an entry
      (the 14 basic types) }
    Check(XmpState(P, XmpDesc('')) = xms_Valid, 'empty description');
    T.Build(P, nil, False);
    Check(T.IsKnown(-1, 'Closed Choice of Text') = xmt_Yes, 'Closed Choice of Text');
    Check(T.IsKnown(-1, 'choice of integer') = xmt_Yes, 'choice of integer');
    Check(T.IsKnown(-1, 'Open Choice') = xmt_Yes, 'Open Choice (text)');
    Check(T.IsKnown(-1, 'Seq Lang Alt') = xmt_Yes, 'Seq Lang Alt');
    Check(T.IsKnown(-1, 'Bag') = xmt_Yes, 'Bag (Bag Text)');
    Check(T.IsKnown(-1, ' URI ') = xmt_Yes, 'URI with spaces');
    Check(T.IsKnown(-1, 'Bag  Text') = xmt_No, 'Bag with two spaces');
    Check(T.IsKnown(-1, 'MIME Type') = xmt_No, 'MIME Type');
    Check(T.IsKnown(-1, 'Dimensions') = xmt_No, 'Dimensions without a schema entry');
    Check(T.IsKnown(-1, WideChar(228)) = xmt_Unknown, 'beyond ASCII');
    { schemas as veraPDF registers them: an array as namespace URI counts as
      ''; a type without namespace URI whose field has a structure as name
      is not registered; a text as pdfaSchema:valueType defines nothing; a
      text as pdfaType:field leaves the type without fields (Text) }
    Check(XmpState(P, XmpOf(ExtDesc('<rdf:li rdf:parseType="Resource"><pdfaSchema:namespaceURI><rdf:Bag/>' +
      '</pdfaSchema:namespaceURI><pdfaSchema:property><rdf:Seq/></pdfaSchema:property></rdf:li>' +
      ExtSchema('urn:a', '', '<pdfaSchema:valueType><rdf:Seq><rdf:li rdf:parseType="Resource"><pdfaType:type>W' +
      '</pdfaType:type><pdfaType:field><rdf:Seq><rdf:li rdf:parseType="Resource"><pdfaField:name><rdf:Bag/>' +
      '</pdfaField:name><pdfaField:valueType>Text</pdfaField:valueType></rdf:li></rdf:Seq></pdfaType:field>' +
      '</rdf:li><rdf:li rdf:parseType="Resource"><pdfaType:type>V</pdfaType:type><pdfaType:field>x' +
      '</pdfaType:field></rdf:li></rdf:Seq></pdfaSchema:valueType>') +
      ExtSchema('urn:b', '', '<pdfaSchema:valueType>x</pdfaSchema:valueType>')))) = xms_Valid,
      'extension schemas: ' + P.Reason);
    T.Build(P, nil, False);
    Check(T.Entry('', True) >= 0, 'an entry under the empty URI');
    Check(T.IsKnown(T.Entry('', True), 'Dimensions') = xmt_Yes, 'Dimensions under the empty URI');
    Check(T.IsKnown(T.Entry('urn:a', True), 'W') = xmt_No, 'W not registered');
    Check(T.IsKnown(T.Entry('urn:a', True), 'V') = xmt_Yes, 'V registered as text');
    Check(T.IsKnown(T.Entry('urn:b', True), 'Nope') = xmt_No, 'no types from a text');
    { values as veraPDF checks them }
    Check(XmpValue(P, T, '<q:v></q:v>', 'Date') = xmt_Yes, 'empty date');
    Check(XmpValue(P, T, '<q:v>2020-01-02T10:11:12.5+01:00</q:v>', 'Date') = xmt_Yes, 'full date');
    Check(XmpValue(P, T, '<q:v>1-99-99T1+0130</q:v>', 'Date') = xmt_Yes, 'loose date');
    Check(XmpValue(P, T, '<q:v>2020-01-02t10</q:v>', 'Date') = xmt_No, 'lower-case t');
    Check(XmpValue(P, T, '<q:v>2020-01-</q:v>', 'Date') = xmt_No, 'separator without digits');
    Check(XmpValue(P, T, '<q:v>2020-01-02T10:11:12Zx</q:v>', 'Date') = xmt_No, 'trailing characters');
    Check(XmpValue(P, T, '<q:v>+007</q:v>', 'Integer') = xmt_Yes, 'integer with sign');
    Check(XmpValue(P, T, '<q:v>1.5</q:v>', 'Integer') = xmt_No, 'no integer');
    Check(XmpValue(P, T, '<q:v>.5</q:v>', 'Real') = xmt_Yes, 'real .5');
    Check(XmpValue(P, T, '<q:v>1.</q:v>', 'Real') = xmt_Yes, 'real 1.');
    Check(XmpValue(P, T, '<q:v>1e5</q:v>', 'Real') = xmt_No, 'no exponent');
    Check(XmpValue(P, T, '<q:v>true</q:v>', 'Boolean') = xmt_No, 'boolean true');
    Check(XmpValue(P, T, '<q:v>application/pdf</q:v>', 'MIMEType') = xmt_Yes, 'MIME type');
    Check(XmpValue(P, T, '<q:v>text/plain; charset=x</q:v>', 'MIMEType') = xmt_No, 'MIME type with parameter');
    Check(XmpValue(P, T, '<q:v>52,30.5N</q:v>', 'GPSCoordinate') = xmt_Yes, 'GPS coordinate');
    Check(XmpValue(P, T, '<q:v>52,30N</q:v>', 'GPSCoordinate') = xmt_No, 'GPS coordinate without seconds');
    Check(XmpValue(P, T, '<q:v>/a</q:v>', 'XPath') = xmt_Unknown, 'XPath not decided');
    Check(XmpValue(P, T, '<q:v><rdf:Alt><rdf:li xml:lang="de">a</rdf:li><rdf:li>b</rdf:li></rdf:Alt></q:v>',
      'Lang Alt') = xmt_Yes, 'Lang Alt with one language');
    Check(XmpValue(P, T, '<q:v><rdf:Alt><rdf:li>b</rdf:li></rdf:Alt></q:v>', 'Lang Alt') = xmt_No,
      'Lang Alt without language');
    Check(XmpValue(P, T, '<q:v><rdf:Seq><rdf:li>1</rdf:li><rdf:li>x</rdf:li></rdf:Seq></q:v>', 'seq Integer') =
      xmt_No, 'seq Integer with text');
    Check(XmpValue(P, T, '<q:v><rdf:Seq/></q:v>', 'bag Text') = xmt_No, 'a Seq is no bag');
    Check(XmpValue(P, T, '<q:v rdf:parseType="Resource" xmlns:stDim="http://ns.adobe.com/xap/1.0/sType/Dimensions#">' +
      '<stDim:w>1.5</stDim:w></q:v>', 'Dimensions') = xmt_Yes, 'Dimensions with one field');
    Check(XmpValue(P, T, '<q:v rdf:parseType="Resource" xmlns:stDim="http://ns.adobe.com/xap/1.0/sType/Dimensions#">' +
      '<stDim:w>wide</stDim:w></q:v>', 'Dimensions') = xmt_No, 'Dimensions with a text width');
    Check(XmpValue(P, T, '<q:v>x</q:v>', 'Dimensions') = xmt_No, 'Dimensions as text');
    Check(XmpValue(P, T, '<q:v>2026T</q:v>', 'Date') = xmt_No, 'T after a year');
    Check(XmpValue(P, T, '<q:v>99999999999-01-02T10:00</q:v>', 'Date') = xmt_Unknown, 'long year with a time');
    Check(XmpValue(P, T, '<q:v>0000002026-01-01T12</q:v>', 'Date') = xmt_Unknown, 'long year, full date and T');
    Check(XmpValue(P, T, '<q:v rdf:parseType="Resource" xmlns:exif="http://ns.adobe.com/exif/1.0/">' +
      '<exif:Mode>auto</exif:Mode></q:v>', 'Flash') = xmt_Yes, 'Flash Mode is a closed choice of text');
    Check(XmpValue(P, T, '<q:v rdf:parseType="Resource" xmlns:xapG="http://ns.adobe.com/xap/1.0/g/">' +
      '<xapG:A>1.5</xapG:A></q:v>', 'Colorant') = xmt_Unknown, 'Colorant A 1.5: veraPDF reads Real');
    { types of an extension schema: a field of type Any takes any value, an
      array item type is simplified again, a type named Lang Alt is not
      decided }
    Check(XmpState(P, XmpOf(ExtDesc(ExtSchema('urn:c', ExtProp('w', 'Wrapper'), '<pdfaSchema:valueType><rdf:Seq>' +
      '<rdf:li rdf:parseType="Resource"><pdfaType:type>Wrapper</pdfaType:type><pdfaType:namespaceURI>urn:c#w' +
      '</pdfaType:namespaceURI><pdfaType:field><rdf:Seq><rdf:li rdf:parseType="Resource"><pdfaField:name>x' +
      '</pdfaField:name><pdfaField:valueType>Any</pdfaField:valueType></rdf:li><rdf:li rdf:parseType="Resource">' +
      '<pdfaField:name>y</pdfaField:name><pdfaField:valueType>Bag  Text</pdfaField:valueType></rdf:li></rdf:Seq>' +
      '</pdfaType:field></rdf:li><rdf:li rdf:parseType="Resource"><pdfaType:type>Lang Alt</pdfaType:type></rdf:li>' +
      '</rdf:Seq></pdfaSchema:valueType>')) + '<rdf:Description rdf:about="" xmlns:c="urn:c" xmlns:w="urn:c#w">' +
      '<c:w rdf:parseType="Resource"><w:x rdf:parseType="Resource"><w:z>1</w:z></w:x><w:y><rdf:Bag><rdf:li>ok' +
      '</rdf:li></rdf:Bag></w:y></c:w><c:l>hello</c:l></rdf:Description>')) = xms_Valid, 'custom types: ' + P.Reason);
    T.Build(P, nil, False);
    Check(T.Validate(P.Find('urn:c', 'w'), 'Wrapper', T.Entry('urn:c', True)) = xmt_Yes, 'Any and Bag  Text');
    Check(T.Validate(P.Find('urn:c', 'l'), 'Lang Alt', T.Entry('urn:c', True)) = xmt_Unknown, 'own Lang Alt');
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
      '<rdf:RDF><rdf:Description/></rdf:RDF></x:xmpmeta>') = xms_Valid, 'rdf:RDF without attributes (veraPDF reads it)');
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
    T.Free;
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
  I, J, Files, Missing, Incomplete, Agree: Integer;
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
    Missing := 0;
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
      begin
        Inc(Missing);
        Continue;
      end;
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
    if Missing > 0 then
      Skip(IntToStr(Missing) + ' files of tests/data/verapdf-expected.txt not found locally (tools/testdata/sync-local.py)');
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
  RegisterTest('PdfA.Extension', TestPdfAExtension);
  RegisterTest('PdfA.Properties', TestPdfAProperties);
  RegisterTest('PdfA.Content', TestPdfAContent);
  RegisterTest('PdfA.Content2', TestPdfAContent2);
  RegisterTest('PdfA.Content3', TestPdfAContent3);
  RegisterTest('PdfA.Content4', TestPdfAContent4);
  RegisterTest('PdfA.Content5', TestPdfAContent5);
  RegisterTest('PdfA.Content6', TestPdfAContent6);
  RegisterTest('PdfA.Content7', TestPdfAContent7);
  RegisterTest('PdfA.Content8', TestPdfAContent8);
  RegisterTest('PdfA.Content9', TestPdfAContent9);
  RegisterTest('PdfA.Content10', TestPdfAContent10);
  RegisterTest('PdfA.Graphics', TestPdfAGraphics);
  RegisterTest('PdfA.OutputIntents', TestPdfAOutputIntents);
  RegisterTest('PdfA.Colour', TestPdfAColour);
  RegisterTest('PdfA.Colour2', TestPdfAColour2);
  RegisterTest('PdfA.Review', TestPdfAReview);
  RegisterTest('PdfA.VeraPdf', TestPdfAVeraPdf);
end;

end.
