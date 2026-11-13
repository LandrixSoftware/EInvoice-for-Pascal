{
  EInvoice-for-Pascal

  Copyright (C) 2026 Landrix Software GmbH & Co. KG

  This file is dual-licensed under:
  - GNU GPL version 3 or later; or
  - the Landrix Software Commercial License.

  See LICENSE and COMMERCIAL-LICENSE.md.

  SPDX-License-Identifier: GPL-3.0-or-later OR LicenseRef-Landrix-Commercial
}

{ Tests of the rendering of invoices (LandrixEInvoiceRender,
  LandrixEInvoiceRenderHtml): the formatting of values, the writer (stream,
  file, nil, escaping, read context), the completeness test (one mutation
  per field of the generated FillInvoiceAll/MutateInvoiceLeaf, with one and
  with two items per list; the page must change exactly in the elements
  marked with that field, in the item of that index, and every marked
  element sits in the section of its field; exceptions with reasons in
  tools/render/render-exceptions.txt), hand-checked golden pages in
  tests/data/render/ and every local golden and sweep file in both
  languages, read back as XML. }

unit LandrixEInvoiceTestRender;

{$I LandrixEInvoice.inc}

interface

procedure Register;

implementation

uses
  SysUtils,
  Classes,
  Contnrs,
  LandrixXmlBase,
  LandrixXmlDom,
  LandrixEInvoiceTypes,
  LandrixEInvoiceDiagnostics,
  LandrixEInvoiceCodes,
  LandrixEInvoiceCodeNames,
  LandrixEInvoiceInvoice,
  LandrixEInvoice,
  LandrixEInvoiceReportHtml,
  LandrixEInvoiceRender,
  LandrixEInvoiceRenderLabels,
  LandrixEInvoiceRenderHtml,
  LandrixEInvoiceTestFramework,
  LandrixEInvoiceTestInvoiceCompare,
  LandrixEInvoiceTestValidationReport;

const
  HtmlNs = 'http://www.w3.org/1999/xhtml';

var
  { the paths of the fields, sorted (CompareStr), and their fields }
  IndexPaths: array of string;
  IndexFields: array of TLandrixEInvoiceRenderField;

{ --- helpers ---------------------------------------------------------------- }

{ A + the character AChar + B (Delphi 6 has no string literals with other
  characters) }
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

function PageOf(AInvoice: TLandrixInvoice; ALanguage: TLandrixEInvoiceReportLanguage;
  AShowTerms: Boolean): TLandrixXmlUtf8;
var
  W: TLandrixEInvoiceRenderHtmlWriter;
  S: TMemoryStream;
begin
  W := TLandrixEInvoiceRenderHtmlWriter.Create;
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

function DocumentPageOf(ADocument: TLandrixEInvoiceDocument; ALanguage: TLandrixEInvoiceReportLanguage): TLandrixXmlUtf8;
var
  W: TLandrixEInvoiceRenderHtmlWriter;
  S: TMemoryStream;
begin
  W := TLandrixEInvoiceRenderHtmlWriter.Create;
  S := TMemoryStream.Create;
  try
    W.Language := ALanguage;
    W.WriteToStream(ADocument, S);
    Result := StreamUtf8(S);
  finally
    S.Free;
    W.Free;
  end;
end;

function Attr(ANode: TLandrixXmlNode; const ALocal: TLandrixXmlUtf8): string;
begin
  if ANode.HasAttribute('', ALocal) then
    Result := ANode.AttributeValue('', ALocal)
  else
    Result := '';
end;

{ the field of a path, False for an unknown path }
function FieldOfPath(const APath: string; out AField: TLandrixEInvoiceRenderField): Boolean;
var
  F, G: TLandrixEInvoiceRenderField;
  I, J, Lo, Hi, C: Integer;
  S: string;
begin
  if Length(IndexPaths) = 0 then
  begin
    { insertion sort: 293 paths, once }
    SetLength(IndexPaths, Ord(High(TLandrixEInvoiceRenderField)) + 1);
    SetLength(IndexFields, Ord(High(TLandrixEInvoiceRenderField)) + 1);
    I := 0;
    for F := Low(TLandrixEInvoiceRenderField) to High(TLandrixEInvoiceRenderField) do
    begin
      S := string(LandrixEInvoiceRenderFieldPath(F));
      G := F;
      J := I;
      while (J > 0) and (CompareStr(IndexPaths[J - 1], S) > 0) do
      begin
        IndexPaths[J] := IndexPaths[J - 1];
        IndexFields[J] := IndexFields[J - 1];
        Dec(J);
      end;
      IndexPaths[J] := S;
      IndexFields[J] := G;
      Inc(I);
    end;
  end;
  Result := False;
  Lo := 0;
  Hi := Integer(Length(IndexPaths)) - 1;
  while Lo <= Hi do
  begin
    I := (Lo + Hi) div 2;
    C := CompareStr(IndexPaths[I], APath);
    if C = 0 then
    begin
      AField := IndexFields[I];
      Result := True;
      Exit;
    end;
    if C < 0 then
      Lo := I + 1
    else
      Hi := I - 1;
  end;
end;

{ the page as XML; fails (and returns nil) when it is not well-formed }
function ParsePage(const AHtml: TLandrixXmlUtf8; const AWhat: string): TLandrixXmlDocument;
begin
  Result := TLandrixXmlDocument.Create;
  try
    Result.LoadFromUtf8(AHtml);
  except
    on E: Exception do
    begin
      Fail(AWhat + ': not well-formed: ' + E.Message);
      Result.Free;
      Result := nil;
    end;
  end;
end;

{ every element marked data-field has a known path and sits in the section
  of its field; every data-ref names a known path; nothing active }
procedure CheckMarks(ANode: TLandrixXmlNode; const ASection, AWhat: string; var AErrors: Integer);
var
  N: TLandrixXmlNode;
  Section, Path: string;
  F: TLandrixEInvoiceRenderField;
begin
  N := ANode.FirstChildElement;
  while N <> nil do
  begin
    Section := ASection;
    if N.HasAttribute('', 'data-section') then
      Section := Attr(N, 'data-section');
    Path := Attr(N, 'data-field');
    if Path <> '' then
    begin
      if not FieldOfPath(Path, F) then
      begin
        Inc(AErrors);
        Check(False, AWhat + ': unknown data-field ' + Path);
      end
      else if string(LandrixEInvoiceRenderSectionKey(LandrixEInvoiceRenderFieldSection(F))) <> Section then
      begin
        Inc(AErrors);
        Check(False, AWhat + ': ' + Path + ' in section "' + Section + '"');
      end;
    end;
    Path := Attr(N, 'data-ref');
    if (Path <> '') and not FieldOfPath(Path, F) then
    begin
      Inc(AErrors);
      Check(False, AWhat + ': unknown data-ref ' + Path);
    end;
    if (N.LocalName = 'script') or (N.LocalName = 'a') or (N.LocalName = 'img') or (N.LocalName = 'link') then
    begin
      Inc(AErrors);
      Check(False, AWhat + ': active element ' + N.LocalName);
    end;
    if AErrors < 20 then
      CheckMarks(N, Section, AWhat, AErrors);
    N := N.NextSiblingElement;
  end;
end;

procedure CheckPage(const AHtml: TLandrixXmlUtf8; const AWhat: string);
var
  Doc: TLandrixXmlDocument;
  Errors: Integer;
begin
  Check(Pos(TLandrixXmlUtf8(' src='), AHtml) = 0, AWhat + ': nothing loaded');
  Check(Pos(TLandrixXmlUtf8(' href='), AHtml) = 0, AWhat + ': no links');
  Check(Pos(TLandrixXmlUtf8('url('), AHtml) = 0, AWhat + ': no CSS resources');
  Doc := ParsePage(AHtml, AWhat);
  if Doc = nil then
    Exit;
  try
    CheckEqualsStr(HtmlNs, Doc.Root.NamespaceUri, AWhat + ': XHTML namespace');
    Errors := 0;
    CheckMarks(Doc.Root, '', AWhat, Errors);
  finally
    Doc.Free;
  end;
end;

{ the text of ANode without the text of marked elements below it }
function OwnText(ANode: TLandrixXmlNode): string;
var
  N: TLandrixXmlNode;
begin
  Result := '';
  N := ANode.FirstChild;
  while N <> nil do
  begin
    if N.NodeType in [xntText, xntCData] then
      Result := Result + N.Value
    else if N.IsElement and not N.HasAttribute('', 'data-field') and not N.HasAttribute('', 'data-ref') then
      Result := Result + OwnText(N);
    N := N.NextSibling;
  end;
end;

{ True if an element marked data-field is below ANode }
function HasMarked(ANode: TLandrixXmlNode): Boolean;
var
  N: TLandrixXmlNode;
begin
  Result := False;
  N := ANode.FirstChildElement;
  while (N <> nil) and not Result do
  begin
    Result := N.HasAttribute('', 'data-field') or HasMarked(N);
    N := N.NextSiblingElement;
  end;
end;

{ the number of elements before AChild (a child of AParent) marked AField }
function MarkedBefore(AParent, AChild: TLandrixXmlNode; const AField: string): Integer;
var
  N: TLandrixXmlNode;
begin
  Result := 0;
  N := AParent.FirstChildElement;
  while (N <> nil) and (N <> AChild) do
  begin
    if Attr(N, 'data-field') = AField then
      Inc(Result);
    N := N.NextSiblingElement;
  end;
end;

{ one entry 'chain|text' per marked element: the chain of the marks from
  the outermost to the element (a data-ref as '@path'; a list item, marked
  'X[]', as 'X[n]' with n its position among the siblings of that mark),
  the text of a value (a container, i.e. an element with marked elements
  below it, counts by its presence; its labels are not values) }
procedure CollectEntries(ANode: TLandrixXmlNode; const AChain: string; AList: TStringList);
var
  N: TLandrixXmlNode;
  Mark, Chain: string;
begin
  N := ANode.FirstChildElement;
  while N <> nil do
  begin
    Mark := Attr(N, 'data-field');
    if Copy(Mark, Length(Mark) - 1, 2) = '[]' then
      Mark := Copy(Mark, 1, Length(Mark) - 1) + IntToStr(MarkedBefore(ANode, N, Mark)) + ']';
    if (Mark = '') and N.HasAttribute('', 'data-ref') then
      Mark := '@' + Attr(N, 'data-ref');
    Chain := AChain;
    if Mark <> '' then
    begin
      if Chain = '' then
        Chain := Mark
      else
        Chain := Chain + '/' + Mark;
      if HasMarked(N) then
        AList.Add(Chain + '|')
      else
        AList.Add(Chain + '|' + OwnText(N));
    end;
    CollectEntries(N, Chain, AList);
    N := N.NextSiblingElement;
  end;
end;

function CompareEntries(List: TStringList; Index1, Index2: Integer): Integer;
begin
  Result := CompareStr(List[Index1], List[Index2]);
end;

function EntriesOf(const AHtml: TLandrixXmlUtf8; const AWhat: string): TStringList;
var
  Doc: TLandrixXmlDocument;
begin
  Result := TStringList.Create;
  Doc := ParsePage(AHtml, AWhat);
  if Doc = nil then
    Exit;
  try
    CollectEntries(Doc.Root, '', Result);
  finally
    Doc.Free;
  end;
  Result.CustomSort(CompareEntries);
end;

{ the entries of A and B that the other has not (as multisets) }
procedure DiffEntries(A, B, ADiffs: TStringList);
var
  I, J, C: Integer;
begin
  I := 0;
  J := 0;
  while (I < A.Count) or (J < B.Count) do
  begin
    if I >= A.Count then
      C := 1
    else if J >= B.Count then
      C := -1
    else
      C := CompareStr(A[I], B[J]);
    if C = 0 then
    begin
      Inc(I);
      Inc(J);
    end
    else if C < 0 then
    begin
      ADiffs.Add(A[I]);
      Inc(I);
    end
    else
    begin
      ADiffs.Add(B[J]);
      Inc(J);
    end;
  end;
end;

{ a path of MutateInvoiceLeaf ('InvoiceLines[1].SubInvoiceLines[0].Name
  (BT-153)', 'Notes (BG-1/BT-21/BT-22).Count') as the chain of marks it must
  appear under: the list items on the way with their indexes, then the field
  (or the new list item for .Count: index AItems, after the filled ones; 0
  for the sub lines of a sub line, which FillInvoiceAll leaves empty); ALeaf
  is the field without indexes; sub lines use the paths of a line }
procedure ExpectedChain(const APath: string; AItems: Integer; AChain: TStringList; out ALeaf: string;
  out ACount: Boolean);
var
  S, Seg, Cur, Index: string;
  I, P, N: Integer;
  InBracket, InParen: Boolean;
  Indexes: TStringList;
begin
  Indexes := TStringList.Create;
  try
    { drop ' (terms)' and the indexes, keep the indexes apart }
    S := '';
    Index := '';
    InBracket := False;
    InParen := False;
    I := 1;
    while I <= Length(APath) do
    begin
      if InParen then
      begin
        if APath[I] = ')' then
          InParen := False;
      end
      else if (APath[I] = ' ') and (I < Length(APath)) and (APath[I + 1] = '(') then
      begin
        InParen := True;
        Inc(I);
      end
      else if APath[I] = '[' then
      begin
        S := S + '[]';
        Index := '';
        InBracket := True;
      end
      else if APath[I] = ']' then
      begin
        InBracket := False;
        Indexes.Add(Index);
      end
      else if InBracket then
        Index := Index + APath[I]
      else
        S := S + APath[I];
      Inc(I);
    end;
    ACount := (Length(S) > 6) and (Copy(S, Length(S) - 5, 6) = '.Count');
    if ACount then
    begin
      S := Copy(S, 1, Length(S) - 6) + '[]';
      P := Pos('SubInvoiceLines[]', S);
      if (P > 0) and (Pos('SubInvoiceLines[]', Copy(S, P + 1, MaxInt)) > 0) then
        Indexes.Add('0')
      else
        Indexes.Add(IntToStr(AItems));
    end;
    AChain.Clear;
    Cur := '';
    ALeaf := '';
    N := 0;
    while S <> '' do
    begin
      P := Pos('.', S);
      if P = 0 then
      begin
        Seg := S;
        S := '';
      end
      else
      begin
        Seg := Copy(S, 1, P - 1);
        S := Copy(S, P + 1, MaxInt);
      end;
      if Seg = 'SubInvoiceLines[]' then
        ALeaf := Cur + '.' + Seg
      else
      begin
        if Cur = '' then
          Cur := Seg
        else
          Cur := Cur + '.' + Seg;
        ALeaf := Cur;
      end;
      if Copy(Seg, Length(Seg) - 1, 2) = '[]' then
      begin
        AChain.Add(Copy(ALeaf, 1, Length(ALeaf) - 1) + Indexes[N] + ']');
        Inc(N);
      end;
    end;
    if not ACount then
      AChain.Add(ALeaf);
  finally
    Indexes.Free;
  end;
end;

{ the marks of the chain of AEntry ('@' of a data-ref dropped) that matter
  for a mutation: the list items ('X[n]'), ALeaf (the mutated field), the
  last mark }
function ListChain(const AEntry, ALeaf: string): string;
var
  Chain, Seg: string;
  P: Integer;
begin
  Result := '';
  Chain := Copy(AEntry, 1, Pos('|', AEntry) - 1);
  while Chain <> '' do
  begin
    P := Pos('/', Chain);
    if P = 0 then
    begin
      Seg := Chain;
      Chain := '';
    end
    else
    begin
      Seg := Copy(Chain, 1, P - 1);
      Chain := Copy(Chain, P + 1, MaxInt);
    end;
    if (Seg <> '') and (Seg[1] = '@') then
      Delete(Seg, 1, 1);
    if (Chain = '') or (Seg = ALeaf) or ((Seg <> '') and (Seg[Length(Seg)] = ']')) then
    begin
      if Result <> '' then
        Result := Result + '/';
      Result := Result + Seg;
    end;
  end;
end;

{ True if a difference in AEntry belongs to the mutation: the list items
  and the field exactly as expected (not in another item or a sub line), or
  something below that field (a currency inside an amount) or below a new
  list item }
function ChainMatches(const AEntry: string; AExpected: TStringList): Boolean;
var
  Want, Have: string;
  I: Integer;
begin
  Want := '';
  for I := 0 to AExpected.Count - 1 do
  begin
    if Want <> '' then
      Want := Want + '/';
    Want := Want + AExpected[I];
  end;
  Have := ListChain(AEntry, AExpected[AExpected.Count - 1]);
  Result := (Have = Want) or (Copy(Have, 1, Length(Want) + 1) = Want + '/');
end;

function LastOfChain(const AEntry: string): string;
var
  P: Integer;
begin
  Result := Copy(AEntry, 1, Pos('|', AEntry) - 1);
  P := Pos('/', Result);
  while P > 0 do
  begin
    Result := Copy(Result, P + 1, MaxInt);
    P := Pos('/', Result);
  end;
end;

{ --- Render.Format ------------------------------------------------------------ }

procedure TestFormat;
var
  Big: Double;
  I: Integer;
begin
  CheckEqualsInvoiceStr('1.234,50', LandrixEInvoiceRenderAmount(1234.5, eln_German), 'amount de');
  CheckEqualsInvoiceStr('1,234.50', LandrixEInvoiceRenderAmount(1234.5, eln_English), 'amount en');
  CheckEqualsInvoiceStr('-0,1234', LandrixEInvoiceRenderAmount(-0.1234, eln_German), 'amount 4 decimals');
  CheckEqualsInvoiceStr('1,000,000.00', LandrixEInvoiceRenderAmount(1000000, eln_English), 'amount groups');
  CheckEqualsInvoiceStr('-100.00', LandrixEInvoiceRenderAmount(-100, eln_English), 'amount sign');
  CheckEqualsInvoiceStr('0,00', LandrixEInvoiceRenderAmount(0, eln_German), 'amount 0');
  CheckEqualsInvoiceStr('12,5', LandrixEInvoiceRenderDecimal(12.5, 0, eln_German), 'decimal de');
  CheckEqualsInvoiceStr('3', LandrixEInvoiceRenderDecimal(3, 0, eln_English), 'decimal integer');
  CheckEqualsInvoiceStr('3.00', LandrixEInvoiceRenderDecimal(3, 2, eln_English), 'decimal min 2');
  CheckEqualsInvoiceStr('0.01146', LandrixEInvoiceRenderDecimal(1146 / 100000, 2, eln_English), 'decimal as stored');
  CheckEqualsInvoiceStr('12.345,678', LandrixEInvoiceRenderDecimal(12345.678, 0, eln_German), 'decimal groups');
  CheckEqualsInvoiceStr('0.00000000001', LandrixEInvoiceRenderDecimal(1 / 100000000000.0, 0, eln_English),
    'decimal small');
  Big := 1;
  for I := 1 to 20 do
    Big := Big / 10;
  CheckEqualsInvoiceStr('?', LandrixEInvoiceRenderDecimal(Big, 2, eln_English), 'decimal too small, never 0');
  Big := 1;
  for I := 1 to 30 do
    Big := Big * 10;
  CheckEqualsInvoiceStr('?', LandrixEInvoiceRenderDecimal(Big, 0, eln_English), 'decimal too large');
  CheckEqualsInvoiceStr('19 %', LandrixEInvoiceRenderPercent(19, eln_German), 'percent de');
  CheckEqualsInvoiceStr('7.5%', LandrixEInvoiceRenderPercent(7.5, eln_English), 'percent en');
  CheckEqualsInvoiceStr('31.12.2026', LandrixEInvoiceRenderDate(EncodeDate(2026, 12, 31), eln_German), 'date de');
  CheckEqualsInvoiceStr('2026-01-05', LandrixEInvoiceRenderDate(EncodeDate(2026, 1, 5), eln_English), 'date en');
  CheckEqualsInvoiceStr('?', LandrixEInvoiceRenderDate(3000000, eln_English), 'date out of range');
  CheckEqualsInvoiceStr('Germany (DE)', LandrixEInvoiceRenderCode(ecl_CountryCode, 'DE', eln_English), 'code');
  CheckEqualsInvoiceStr('XX', LandrixEInvoiceRenderCode(ecl_CountryCode, 'XX', eln_German), 'unknown code');
  CheckEqualsInvoiceStr('', LandrixEInvoiceRenderCode(ecl_CountryCode, '', eln_German), 'no code');
end;

{ --- Render.Html ------------------------------------------------------------ }

procedure TestHtml;
var
  Inv: TLandrixInvoice;
  W: TLandrixEInvoiceRenderHtmlWriter;
  S: TMemoryStream;
  Html, FileHtml: TLandrixXmlUtf8;
  Doc: TLandrixXmlDocument;
  Document: TLandrixEInvoiceDocument;
  FileName: string;
  F: TFileStream;
  Raised: Boolean;
begin
  W := TLandrixEInvoiceRenderHtmlWriter.Create;
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
      W.WriteToStream(TLandrixEInvoiceDocument(nil), S);
    except
      on ELandrixEInvoiceError do
        Raised := True;
    end;
    Check(Raised, 'nil document raises');
    CheckEquals(0, Integer(S.Size), 'nothing written on error');

    { a new invoice: its preset business process, the totals EN 16931
      requires; the preset scheme of the delivery location stays hidden
      without a location }
    Html := PageOf(Inv, eln_English, False);
    CheckPage(Html, 'empty');
    Check(Pos(TLandrixXmlUtf8('data-section="totals"'), Html) > 0, 'empty: totals');
    Check(Pos(TLandrixXmlUtf8('data-field="ProfileID"'), Html) > 0, 'empty: preset business process');
    Check(Pos(TLandrixXmlUtf8('data-section="parties"'), Html) = 0, 'empty: no parties');
    Check(Pos(TLandrixXmlUtf8('data-section="lines"'), Html) = 0, 'empty: no lines');

    { escaping and sanitizing }
    Inv.InvoiceNumber := WithChar('<a&b>"', 1, #13'x');
    Inv.InvoiceCurrencyCode := 'EUR';
    Inv.PayableAmount := 12.5;
    Html := PageOf(Inv, eln_German, False);
    CheckPage(Html, 'escaped');
    Check(Pos(TLandrixXmlUtf8('&lt;a&amp;b&gt;&quot;'), Html) > 0, 'escaped: markup');
    Check(Pos(TLandrixXmlUtf8('&#13;x'), Html) > 0, 'escaped: CR');
    Check(Pos(TLandrixXmlUtf8('U+FFFD'), Html) > 0, 'sanitized: note');
    Check(Pos(TLandrixXmlUtf8('12,50 <span class="cur" data-ref="InvoiceCurrencyCode">EUR</span>'), Html) > 0,
      'amount with currency');
    Doc := ParsePage(Html, 'escaped');
    if Doc <> nil then
      try
        Check(Pos(TLandrixXmlUtf8('<a&b>"') + Utf8Bytes([$EF, $BF, $BD, 13, Ord('x')]), Doc.Root.TextUtf8) > 0,
          'escaped: read back');
      finally
        Doc.Free;
      end;

    { business terms }
    Check(Pos(TLandrixXmlUtf8('class="bt"'), Html) = 0, 'no terms by default');
    Check(Pos(TLandrixXmlUtf8('data-bt="BT-1"'), Html) > 0, 'data-bt always');
    Html := PageOf(Inv, eln_English, True);
    Check(Pos(TLandrixXmlUtf8('<span class="bt">BT-1</span>'), Html) > 0, 'terms shown');

    { stream at its position, file }
    S.Clear;
    S.WriteBuffer(PAnsiChar(AnsiString('abc'))^, 3);
    W.Language := eln_English;
    W.WriteToStream(Inv, S);
    Check(Copy(StreamUtf8(S), 1, 3) = 'abc', 'stream: kept');
    CheckEqualsUtf8(PageOf(Inv, eln_English, False), Copy(StreamUtf8(S), 4, MaxInt), 'stream: page');
    FileName := ExtractFilePath(ParamStr(0)) + 'render-test.html';
    W.SaveToFile(Inv, FileName);
    F := TFileStream.Create(FileName, fmOpenRead or fmShareDenyWrite);
    try
      FileHtml := '';
      SetLength(FileHtml, Integer(F.Size));
      if F.Size > 0 then
        F.ReadBuffer(PAnsiChar(FileHtml)^, Integer(F.Size));
    finally
      F.Free;
    end;
    DeleteFile(FileName);
    CheckEqualsUtf8(PageOf(Inv, eln_English, False), FileHtml, 'file');
  finally
    Inv.Free;
    S.Free;
    W.Free;
  end;

  { a read document: info and what reading did not take over }
  Document := TLandrixEInvoice.LoadFromUtf8(
    '<Invoice xmlns="urn:oasis:names:specification:ubl:schema:xsd:Invoice-2" ' +
    'xmlns:cbc="urn:oasis:names:specification:ubl:schema:xsd:CommonBasicComponents-2">' +
    '<cbc:CustomizationID>urn:cen.eu:en16931:2017#compliant#urn:xeinkauf.de:kosit:xrechnung_3.0</cbc:CustomizationID>' +
    '<cbc:ID>R-1</cbc:ID><cbc:Foo>x</cbc:Foo></Invoice>');
  try
    Document.Diagnostics.AddDiagnostic(edk_UnknownCode, '/Invoice/Bar', 5, 6, 0, 'unknown code shown elsewhere');
    Html := DocumentPageOf(Document, eln_German);
    CheckPage(Html, 'document');
    Check(Pos(TLandrixXmlUtf8('data-section="document"'), Html) > 0, 'document section');
    Check(Pos(TLandrixXmlUtf8('XRechnung 3.0'), Html) > 0, 'specification');
    Check(Pos(TLandrixXmlUtf8('<td>Unbekanntes Element</td>'), Html) > 0, 'unknown element listed');
    Check(Pos(TLandrixXmlUtf8('cbc:Foo'), Html) > 0, 'path listed');
    Check(Pos(TLandrixXmlUtf8('unknown code shown elsewhere'), Html) = 0, 'unknown code not listed');
    Html := PageOf(Document.Invoice, eln_German, False);
    Check(Pos(TLandrixXmlUtf8('data-section="document"'), Html) = 0, 'invoice only: no document section');
    Document.DetachInvoice.Free;
    Raised := False;
    try
      DocumentPageOf(Document, eln_German);
    except
      on ELandrixEInvoiceError do
        Raised := True;
    end;
    Check(Raised, 'document without invoice raises');
  finally
    Document.Free;
  end;
end;

{ --- Render.Mutations --------------------------------------------------------- }

type
  TRenderException = class(TObject)
  public
    Path: string;
    Used: Boolean;
  end;

procedure LoadRenderExceptions(AList: TObjectList);
var
  Lines: TStringList;
  I, P: Integer;
  Line: string;
  E: TRenderException;
begin
  Lines := TStringList.Create;
  try
    Lines.LoadFromFile(RepositoryRoot + 'tools' + PathDelim + 'render' + PathDelim + 'render-exceptions.txt');
    for I := 0 to Lines.Count - 1 do
    begin
      Line := Trim(Lines[I]);
      if (Line = '') or (Line[1] = '#') then
        Continue;
      P := Pos(' ', Line);
      Check(P > 0, 'render-exceptions.txt: a reason is required: ' + Line);
      if P = 0 then
        Continue;
      E := TRenderException.Create;
      E.Path := Copy(Line, 1, P - 1);
      AList.Add(E);
    end;
  finally
    Lines.Free;
  end;
end;

function FindException(AList: TObjectList; const APath: string): TRenderException;
var
  I: Integer;
begin
  Result := nil;
  for I := 0 to Integer(AList.Count) - 1 do
    if TRenderException(AList[I]).Path = APath then
    begin
      Result := TRenderException(AList[I]);
      Exit;
    end;
end;

{ The mutations of an invoice filled with AItems items per list; adds the
  findings to AFailed. }
procedure RunMutations(AItems: Integer; AExceptions: TObjectList; var AFailed: Integer);
var
  Base, Inv: TLandrixInvoice;
  Html0, Html: TLandrixXmlUtf8;
  Entries0, Entries, Diffs, Expected: TStringList;
  E: TRenderException;
  I, J: Integer;
  Path, Leaf, Problem, What: string;
  IsCount, LeafSeen: Boolean;
begin
  What := IntToStr(AItems) + ' item(s): ';
  Expected := TStringList.Create;
  Diffs := TStringList.Create;
  Base := TLandrixInvoice.Create;
  Entries0 := nil;
  try
    FillInvoiceAll(Base, AItems);
    Html0 := PageOf(Base, eln_English, True);
    CheckPage(Html0, What + 'filled en');
    CheckPage(PageOf(Base, eln_German, False), What + 'filled de');
    Entries0 := EntriesOf(Html0, 'filled');
    { every field once per item: no two values with the same chain (the
      chain holds the position of each item) }
    for I := 1 to Entries0.Count - 1 do
      if (Copy(Entries0[I], 1, Pos('|', Entries0[I])) = Copy(Entries0[I - 1], 1, Pos('|', Entries0[I - 1]))) and
         (Pos('@', Entries0[I]) = 0) then
      begin
        Inc(AFailed);
        WriteLn('  ', What, 'shown twice: ', Entries0[I]);
      end;
    for I := 0 to InvoiceLeafCount(AItems) - 1 do
    begin
      Inv := TLandrixInvoice.Create;
      try
        FillInvoiceAll(Inv, AItems);
        MutateInvoiceLeaf(Inv, I, Path, AItems);
        Html := PageOf(Inv, eln_English, True);
      finally
        Inv.Free;
      end;
      ExpectedChain(Path, AItems, Expected, Leaf, IsCount);
      if IsCount then
        E := FindException(AExceptions, Leaf + '.Count')
      else
        E := FindException(AExceptions, Leaf);
      if E <> nil then
      begin
        E.Used := True;
        Continue;
      end;
      Problem := '';
      if Html = Html0 then
        Problem := 'page unchanged'
      else
      begin
        Entries := EntriesOf(Html, Path);
        try
          Diffs.Clear;
          DiffEntries(Entries0, Entries, Diffs);
          if Diffs.Count = 0 then
            Problem := 'change outside the marked elements';
          LeafSeen := IsCount;
          for J := 0 to Diffs.Count - 1 do
          begin
            if not ChainMatches(Diffs[J], Expected) then
              Problem := 'changed elsewhere: ' + Diffs[J]
            else if LastOfChain(Diffs[J]) = Leaf then
              LeafSeen := True;
          end;
          if (Problem = '') and not LeafSeen then
            Problem := 'no element marked ' + Leaf + ' changed';
        finally
          Entries.Free;
        end;
      end;
      if Problem <> '' then
      begin
        Inc(AFailed);
        if AFailed <= 40 then
          WriteLn('  ', What, Path, ': ', Problem);
      end;
    end;
  finally
    Expected.Free;
    Diffs.Free;
    Entries0.Free;
    Base.Free;
  end;
end;

procedure TestMutations;
var
  Exceptions: TObjectList;
  I, Failed: Integer;
begin
  Exceptions := TObjectList.Create;
  try
    LoadRenderExceptions(Exceptions);
    Failed := 0;
    RunMutations(1, Exceptions, Failed);
    { two items per list: a mix-up between the items of one list shows }
    RunMutations(2, Exceptions, Failed);
    for I := 0 to Integer(Exceptions.Count) - 1 do
      if not TRenderException(Exceptions[I]).Used then
      begin
        Inc(Failed);
        WriteLn('  unused exception: ', TRenderException(Exceptions[I]).Path);
      end;
    CheckEquals(0, Failed, IntToStr(InvoiceLeafCount(1)) + ' + ' + IntToStr(InvoiceLeafCount(2)) +
      ' mutations, with findings');
  finally
    Exceptions.Free;
  end;
end;

{ --- Render.Golden ---------------------------------------------------------- }

{ an invoice with something in every section: two lines, one with sub
  lines, allowances and charges, two VAT rates, a payee, an attachment }
procedure BuildFullInvoice(AInvoice: TLandrixInvoice);
var
  L, S: TLandrixInvoiceLine;
  A: TLandrixInvoiceAllowanceCharge;
  V: TLandrixInvoiceTaxAmount;
  P: TLandrixInvoicePaymentType;
  N: TLandrixInvoiceNote;
  Att: TLandrixInvoiceAttachment;
  Party: TLandrixInvoiceAccountingParty;
  Attribute: TLandrixInvoiceLineItemAttribute;
  Data: AnsiString;
begin
  AInvoice.InvoiceNumber := 'R-2026-0815';
  AInvoice.InvoiceIssueDate := EncodeDate(2026, 11, 12);
  AInvoice.InvoiceDueDate := EncodeDate(2026, 12, 12);
  AInvoice.InvoiceTypeCode := itc_CommercialInvoice;
  AInvoice.InvoiceCurrencyCode := 'EUR';
  AInvoice.BuyerReference := '04011000-12345-34';
  AInvoice.InvoicePeriodStartDate := EncodeDate(2026, 10, 1);
  AInvoice.InvoicePeriodEndDate := EncodeDate(2026, 10, 31);
  AInvoice.PurchaseOrderReference := 'B-4711';
  AInvoice.ContractDocumentReference := 'V-2025-17';
  Party := AInvoice.AccountingSupplierParty;
  Party.RegistrationName := WithChar('Muster & S', $F6, 'hne GmbH');
  Party.Address.StreetName := WithChar('Hauptstra', $DF, 'e 1');
  Party.Address.PostalZone := '10115';
  Party.Address.City := 'Berlin';
  Party.Address.CountryCode := 'DE';
  Party.VATCompanyID := 'DE123456789';
  Party.ElectronicAddressSellerBuyer := 'rechnung@example.com';
  Party.ElectronicAddressSellerBuyerSchemeID := 'EM';
  Party.ContactName := 'Erika Muster';
  Party.ContactTelephone := '+49 30 123456';
  Party.BankAssignedCreditorIdentifier := 'DE98ZZZ09999999999';
  Party := AInvoice.AccountingCustomerParty;
  Party.RegistrationName := 'Beispiel AG';
  Party.Address.StreetName := 'Ringweg 7';
  Party.Address.PostalZone := '80331';
  Party.Address.City := WithChar('M', $FC, 'nchen');
  Party.Address.CountryCode := 'DE';
  Party.ElectronicAddressSellerBuyer := 'einkauf@example.org';
  Party.ElectronicAddressSellerBuyerSchemeID := 'EM';
  AInvoice.PayeeParty.Name := 'Factoring Bank';
  AInvoice.DeliveryInformation.ActualDeliveryDate := EncodeDate(2026, 10, 20);
  AInvoice.DeliveryInformation.Address.City := 'Hamburg';
  AInvoice.DeliveryInformation.Address.CountryCode := 'DE';

  L := AInvoice.InvoiceLines.AddInvoiceLine;
  L.ID := '1';
  L.Name := 'Beratung';
  L.Description := 'Workshop vor Ort,'#10'zwei Tage';
  L.Quantity := 16;
  L.UnitCode := iuc_hour;
  L.NetPriceAmount := 95;
  L.TaxCategory := idtfcc_S_StandardRate;
  L.TaxPercent := 19;
  L.LineAmount := 1368;
  L.SellersItemIdentification := 'SRV-01';
  A := L.AllowanceCharges.AddAllowanceCharge;
  A.ChargeIndicator := False;
  A.ReasonCodeAllowance := iacic_Discount;
  A.Reason := 'Rabatt';
  A.BaseAmount := 1520;
  A.MultiplierFactorNumeric := 10;
  A.Amount := 152;
  Attribute := L.ItemAttributes.AddItemAttribute;
  Attribute.Name := 'Ort';
  Attribute.Value := 'Berlin';

  L := AInvoice.InvoiceLines.AddInvoiceLine;
  L.ID := '2';
  L.Name := 'Material';
  L.Quantity := 1;
  L.UnitCode := iuc_one;
  L.NetPriceAmount := 200;
  L.TaxCategory := idtfcc_S_StandardRate;
  L.TaxPercent := 7;
  L.LineAmount := 200;
  S := L.SubInvoiceLines.AddInvoiceLine;
  S.ID := '2.1';
  S.Name := 'Kabel';
  S.Quantity := 12.5;
  S.UnitCode := iuc_piece;
  S.NetPriceAmount := 8;
  S.TaxCategory := idtfcc_S_StandardRate;
  S.TaxPercent := 7;
  S.LineAmount := 100;
  S := L.SubInvoiceLines.AddInvoiceLine;
  S.ID := '2.2';
  S.Name := 'Stecker';
  S.Quantity := 50;
  S.UnitCode := iuc_piece;
  S.NetPriceAmount := 2;
  S.TaxCategory := idtfcc_S_StandardRate;
  S.TaxPercent := 7;
  S.LineAmount := 100;

  A := AInvoice.AllowanceCharges.AddAllowanceCharge;
  A.ChargeIndicator := True;
  A.ReasonCodeCharge := issdc_FC_FreightService;
  A.Reason := 'Versand';
  A.Amount := 10;
  A.TaxCategory := idtfcc_S_StandardRate;
  A.TaxPercent := 19;

  V := AInvoice.TaxAmountSubtotals.AddTaxAmount;
  V.TaxCategory := idtfcc_S_StandardRate;
  V.TaxPercent := 19;
  V.TaxableAmount := 1378;
  V.TaxAmount := 261.82;
  V := AInvoice.TaxAmountSubtotals.AddTaxAmount;
  V.TaxCategory := idtfcc_S_StandardRate;
  V.TaxPercent := 7;
  V.TaxableAmount := 200;
  V.TaxAmount := 14;

  AInvoice.LineAmount := 1568;
  AInvoice.ChargeTotalAmount := 10;
  AInvoice.TaxExclusiveAmount := 1578;
  AInvoice.TaxAmountTotal := 275.82;
  AInvoice.TaxInclusiveAmount := 1853.82;
  AInvoice.PrepaidAmount := 53.82;
  AInvoice.PayableAmount := 1800;

  P := AInvoice.PaymentTypes.AddPaymentType;
  P.PaymentMeansCode := ipmc_SEPACreditTransfer;
  P.FinancialAccount := 'DE02120300000000202051';
  P.FinancialAccountName := WithChar('Muster & S', $F6, 'hne GmbH');
  P.FinancialInstitutionBranch := 'BYLADEM1001';
  AInvoice.PaymentID := 'R-2026-0815';
  AInvoice.PaymentTermsType := iptt_CashDiscount1;
  AInvoice.PaymentTermCashDiscount1Days := 10;
  AInvoice.PaymentTermCashDiscount1Percent := 2;
  AInvoice.PaymentTermCashDiscount1Base := 1853.82;

  N := AInvoice.Notes.AddNote;
  N.SubjectCode := insc_AAI;
  N.Content := WithChar('Vielen Dank f', $FC, 'r Ihren Auftrag.');

  Att := AInvoice.Attachments.AddAttachment(iat_application_pdf);
  Att.ID := 'Stundenzettel';
  Att.TypeCode := iatc_916;
  Att.Filename := 'stunden.pdf';
  Att.DocumentDescription := 'Stundennachweis Oktober';
  Data := '%PDF-1.4 test';
  Att.Data.WriteBuffer(PAnsiChar(Data)^, Length(Data));
end;

{ a short credit note referring to its invoice }
procedure BuildCreditNote(AInvoice: TLandrixInvoice);
var
  L: TLandrixInvoiceLine;
  V: TLandrixInvoiceTaxAmount;
  R: TLandrixInvoicePrecedingInvoiceReference;
begin
  AInvoice.InvoiceNumber := 'G-2026-0007';
  AInvoice.InvoiceIssueDate := EncodeDate(2026, 11, 20);
  AInvoice.InvoiceTypeCode := itc_CreditNote;
  AInvoice.InvoiceCurrencyCode := 'EUR';
  AInvoice.BuyerReference := 'leitweg-1';
  R := AInvoice.PrecedingInvoiceReferences.AddPrecedingInvoiceReference;
  R.ID := 'R-2026-0815';
  R.IssueDate := EncodeDate(2026, 11, 12);
  AInvoice.AccountingSupplierParty.RegistrationName := 'Muster GmbH';
  AInvoice.AccountingSupplierParty.Address.City := 'Berlin';
  AInvoice.AccountingSupplierParty.Address.CountryCode := 'DE';
  AInvoice.AccountingCustomerParty.RegistrationName := 'Beispiel AG';
  AInvoice.AccountingCustomerParty.Address.City := 'Wien';
  AInvoice.AccountingCustomerParty.Address.CountryCode := 'AT';
  L := AInvoice.InvoiceLines.AddInvoiceLine;
  L.ID := '1';
  L.Name := WithChar('R', $FC, 'cknahme');
  L.Quantity := 2;
  L.UnitCode := iuc_piece;
  L.NetPriceAmount := 49.995;
  L.TaxCategory := idtfcc_AE_VATReverseCharge;
  L.TaxPercent := 0;
  L.LineAmount := 99.99;
  V := AInvoice.TaxAmountSubtotals.AddTaxAmount;
  V.TaxCategory := idtfcc_AE_VATReverseCharge;
  V.TaxableAmount := 99.99;
  V.TaxExemptionReasonCode := 'VATEX-EU-AE';
  V.TaxExemptionReason := WithChar('Steuerschuldnerschaft des Leistungsempf', $E4, 'ngers');
  AInvoice.LineAmount := 99.99;
  AInvoice.TaxExclusiveAmount := 99.99;
  AInvoice.TaxInclusiveAmount := 99.99;
  AInvoice.PayableAmount := 99.99;
end;

procedure TestGolden;
var
  Inv: TLandrixInvoice;
  Html: TLandrixXmlUtf8;
begin
  Inv := TLandrixInvoice.Create;
  try
    BuildFullInvoice(Inv);
    Html := PageOf(Inv, eln_English, False);
    CheckPage(Html, 'full en');
    CheckGoldenFile(Html, 'render', 'full-en.html');
    Html := PageOf(Inv, eln_German, True);
    CheckPage(Html, 'full de');
    CheckGoldenFile(Html, 'render', 'full-de-bt.html');
  finally
    Inv.Free;
  end;
  Inv := TLandrixInvoice.Create;
  try
    BuildCreditNote(Inv);
    Html := PageOf(Inv, eln_English, False);
    CheckPage(Html, 'credit en');
    CheckGoldenFile(Html, 'render', 'credit-en.html');
    Html := PageOf(Inv, eln_German, False);
    CheckPage(Html, 'credit de');
    CheckGoldenFile(Html, 'render', 'credit-de.html');
  finally
    Inv.Free;
  end;
end;

{ --- Render.Corpus ------------------------------------------------------------ }

procedure RenderFolder(const ADir: string; var AFiles, AFailed: Integer);
var
  SR: TSearchRec;
  Document: TLandrixEInvoiceDocument;
  Name: string;
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
              CheckPage(DocumentPageOf(Document, eln_English), Name + ' en');
              CheckPage(DocumentPageOf(Document, eln_German), Name + ' de');
            except
              on E: Exception do
              begin
                Inc(AFailed);
                WriteLn('  ', Name, ': ', E.ClassName, ': ', E.Message);
              end;
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
  CheckEquals(0, Failed, 'files that could not be rendered');
end;

procedure Register;
begin
  RegisterTest('Render.Format', TestFormat);
  RegisterTest('Render.Html', TestHtml);
  RegisterTest('Render.Mutations', TestMutations);
  RegisterTest('Render.Golden', TestGolden);
  RegisterTest('Render.Corpus', TestCorpus);
end;

end.
