{
  EInvoice-for-Pascal

  Copyright (C) 2026 Landrix Software GmbH & Co. KG

  This file is dual-licensed under:
  - GNU GPL version 3 or later; or
  - the Landrix Software Commercial License.

  See LICENSE and COMMERCIAL-LICENSE.md.

  SPDX-License-Identifier: GPL-3.0-or-later OR LicenseRef-Landrix-Commercial
}

{ The PDF/A-3b rules of clause 6.1 (file structure) of ISO 19005-3, checked
  on the raw syntax facts of LandrixEInvoicePdfSyntax and the objects of the
  document. The rules carry the numbers of the veraPDF validation profile
  ("6.1.2-1": clause and test number; the finding ID is "PDFA-6.1.2-1"), so
  that results compare with veraPDF rule by rule. A registry states for every
  rule how far it is implemented: prc_Full rules are checked in their whole
  scope; prc_Partial rules miss part of it (numbers, strings and names in
  content streams are not read yet), so a failure is evidence but no failure
  proves nothing; prc_None rules are not checked. The checked population is
  the live object set of the object table (also unreferenced and compressed
  objects), the newest trailer and every section of the xref chain; older
  revisions of objects are not judged.

  DE: Die PDF/A-3b-Regeln von Abschnitt 6.1 (Dateistruktur) der ISO 19005-3,
  geprueft auf den rohen Syntax-Tatsachen von LandrixEInvoicePdfSyntax und
  den Objekten des Dokuments. Die Regeln tragen die Nummern des
  veraPDF-Pruefprofils ("6.1.2-1": Abschnitt und Testnummer; die Befund-ID ist
  "PDFA-6.1.2-1"), damit sich Ergebnisse Regel fuer Regel mit veraPDF
  vergleichen lassen. Ein Register sagt fuer jede Regel, wie weit sie umgesetzt
  ist: prc_Full-Regeln werden in ihrem ganzen Umfang geprueft; prc_Partial-
  Regeln fehlt ein Teil davon (Zahlen, Strings und Namen in Content-Streams
  werden noch nicht gelesen), ein Verstoss ist also ein Beleg, kein Verstoss
  beweist nichts; prc_None-Regeln werden nicht geprueft. Geprueft wird die
  lebende Objektmenge der Objekttabelle (auch Objekte ohne Verweis und
  komprimierte), der neueste Trailer und jeder Abschnitt der xref-Kette;
  aeltere Fassungen von Objekten werden nicht beurteilt. }

{ API: internal. May change in any release; use the facade LandrixEInvoice
  or the stable units instead.
  DE: API: intern. Kann sich in jeder Version aendern; stattdessen die
  Fassade LandrixEInvoice oder die stabilen Units verwenden. }

unit LandrixEInvoicePdfARules;

{$I LandrixEInvoice.inc}

interface

uses
  LandrixEInvoicePdfObjects,
  LandrixEInvoicePdfSyntax;

type
  { The rules of clause 6.1 in the veraPDF profile PDF/A-3B, named after
    clause and test number.
    DE: Die Regeln von Abschnitt 6.1 im veraPDF-Profil PDF/A-3B, benannt nach
    Abschnitt und Testnummer. }
  TLandrixEInvoicePdfARule = (
    par_6_1_2_1, par_6_1_2_2, par_6_1_3_1, par_6_1_3_2, par_6_1_3_3, par_6_1_4_2, par_6_1_6_1, par_6_1_6_2,
    par_6_1_7_1_1, par_6_1_7_1_2, par_6_1_7_1_3, par_6_1_7_2_1, par_6_1_8_1, par_6_1_9_1, par_6_1_10_1,
    par_6_1_12_1, par_6_1_12_2, par_6_1_13_1, par_6_1_13_2, par_6_1_13_3, par_6_1_13_4, par_6_1_13_5,
    par_6_1_13_7, par_6_1_13_8, par_6_1_13_9, par_6_1_13_10, par_6_1_13_11);

  { How far a rule is implemented: in its whole scope, in part of it, not
    at all.
    DE: Wie weit eine Regel umgesetzt ist: im ganzen Umfang, in einem Teil
    davon, gar nicht. }
  TLandrixEInvoicePdfARuleCoverage = (prc_Full, prc_Partial, prc_None);

  { The outcome of one rule for one document: not checked (prc_None),
    passed, failed (at least one violation found), incomplete (no violation
    found, but the rule is partial or the facts are incomplete).
    DE: Das Ergebnis einer Regel fuer ein Dokument: nicht geprueft
    (prc_None), bestanden, verletzt (mindestens ein Verstoss gefunden),
    unvollstaendig (kein Verstoss gefunden, aber die Regel ist teilweise
    umgesetzt oder die Tatsachen sind unvollstaendig). }
  TLandrixEInvoicePdfARuleOutcome = (pro_NotChecked, pro_Passed, pro_Failed, pro_Incomplete);

  { The result of one rule: outcome, number of violations and where the
    first one is (object number and generation, -1 for the file or the
    trailer; position in the file or, with pss_ObjectStream, in the decoded
    object stream; -1 if none) with a short English text.
    DE: Das Ergebnis einer Regel: Ausgang, Anzahl der Verstoesse und wo der
    erste liegt (Objektnummer und Generation, -1 fuer die Datei oder den
    Trailer; Position in der Datei oder, bei pss_ObjectStream, im
    dekodierten Objekt-Stream; -1, wenn keine) mit einem kurzen englischen
    Text. }
  TLandrixEInvoicePdfARuleResult = record
    Outcome: TLandrixEInvoicePdfARuleOutcome;
    Failures: Integer;
    ObjNum: Integer;
    ObjGen: Integer;
    Source: TLandrixEInvoicePdfSyntaxSource;
    Pos: Integer;
    Detail: string;
  end;

  { Checks the rules of clause 6.1 on a document and its facts.
    DE: Prueft die Regeln von Abschnitt 6.1 an einem Dokument und seinen
    Tatsachen. }
  TLandrixEInvoicePdfARuleCheck = class(TObject)
  private
    FResults: array[TLandrixEInvoicePdfARule] of TLandrixEInvoicePdfARuleResult;
    FDoc: TLandrixEInvoicePdfDocument;
    FFacts: TLandrixEInvoicePdfSyntaxFacts;
    FLive: array of Integer;
    FLiveCount: Integer;
    { per object number the index of its live envelope, -1 if none }
    FLiveByNum: array of Integer;
    FTrailerFrom: Integer;
    FTrailerTo: Integer;
    FMaxReal: Double;
    FMinReal: Double;
    { rules whose scope could not be walked to the end (a limit, no
      catalog, objects without envelope) }
    FIncomplete: array[TLandrixEInvoicePdfARule] of Boolean;
    { pages and form fields walked }
    FNodes: Integer;
    procedure Reset;
    procedure Fail(ARule: TLandrixEInvoicePdfARule; AObjNum, AObjGen: Integer; ASource: TLandrixEInvoicePdfSyntaxSource;
      APos: Integer; const ADetail: string);
    function NormalOffset(AOffset: Int64): Integer;
    procedure FindLive;
    function LiveAt(ANum, APos: Integer): Integer;
    function TokenLive(const AToken: TLandrixEInvoicePdfTokenFact): Boolean;
    function StreamLive(const AStream: TLandrixEInvoicePdfStreamFact): Boolean;
    procedure CheckHeader;
    procedure CheckTrailer;
    procedure CheckXref;
    procedure CheckStreams;
    procedure CheckFilters(const AStream: TLandrixEInvoicePdfStreamFact);
    procedure CheckEnvelopes;
    procedure CheckTokens;
    procedure CheckPerms;
    procedure CheckSignature(ASig: TLandrixEInvoicePdfObject);
    procedure CheckFields(AField: TLandrixEInvoicePdfObject; const AInheritedType: AnsiString; ADepth: Integer);
    procedure CheckPages(ANode, AMediaBox, ACropBox: TLandrixEInvoicePdfObject; ADepth: Integer);
    procedure CheckBox(ABox: TLandrixEInvoicePdfObject; const AName: string);
  public
    constructor Create;
    { Checks every implemented rule. ADoc was loaded with AFacts as receiver
      and AFacts.Inspect ran; both must live while the results are read.
      DE: Prueft jede umgesetzte Regel. ADoc wurde mit AFacts als
      Empfaenger geladen und AFacts.Inspect lief; beide muessen leben,
      solange die Ergebnisse gelesen werden. }
    procedure Check(ADoc: TLandrixEInvoicePdfDocument; AFacts: TLandrixEInvoicePdfSyntaxFacts);
    { The result of a rule after Check. DE: Das Ergebnis einer Regel nach
      Check. }
    function RuleResult(ARule: TLandrixEInvoicePdfARule): TLandrixEInvoicePdfARuleResult;
    { At least one rule failed. DE: Mindestens eine Regel ist verletzt. }
    function AnyFailed: Boolean;
  end;

{ "6.1.2-1": clause and test number as veraPDF writes them.
  DE: "6.1.2-1": Abschnitt und Testnummer, wie veraPDF sie schreibt. }
function LandrixEInvoicePdfARuleNumber(ARule: TLandrixEInvoicePdfARule): string;

{ "PDFA-6.1.2-1": the ID of a finding of the rule.
  DE: "PDFA-6.1.2-1": die ID eines Befunds der Regel. }
function LandrixEInvoicePdfARuleId(ARule: TLandrixEInvoicePdfARule): string;

{ What the rule demands, in short English. DE: Was die Regel verlangt, kurz
  auf Englisch. }
function LandrixEInvoicePdfARuleText(ARule: TLandrixEInvoicePdfARule): string;

{ How far the rule is implemented. DE: Wie weit die Regel umgesetzt ist. }
function LandrixEInvoicePdfARuleCoverage(ARule: TLandrixEInvoicePdfARule): TLandrixEInvoicePdfARuleCoverage;

implementation

uses
  SysUtils;

type
  TRuleInfo = record
    Number: string;
    Coverage: TLandrixEInvoicePdfARuleCoverage;
    Text: string;
  end;

const
  Rules: array[TLandrixEInvoicePdfARule] of TRuleInfo = (
    (Number: '6.1.2-1'; Coverage: prc_Full; Text: 'The file starts at byte 0 with the header %PDF-1.n (n 0 to 7)'),
    (Number: '6.1.2-2'; Coverage: prc_Full;
      Text: 'The header line is followed by a comment of at least four bytes above 127'),
    (Number: '6.1.3-1'; Coverage: prc_Full; Text: 'The trailer has a file identifier /ID'),
    (Number: '6.1.3-2'; Coverage: prc_Full; Text: 'The trailer has no /Encrypt'),
    (Number: '6.1.3-3'; Coverage: prc_Full; Text: 'Nothing but one end of line follows the last %%EOF'),
    (Number: '6.1.4-2'; Coverage: prc_Full;
      Text: 'The keyword xref and the first subsection header are separated by one end of line'),
    (Number: '6.1.6-1'; Coverage: prc_Partial; Text: 'A hexadecimal string has an even number of characters'),
    (Number: '6.1.6-2'; Coverage: prc_Partial; Text: 'A hexadecimal string holds only hexadecimal digits'),
    (Number: '6.1.7.1-1'; Coverage: prc_Full; Text: 'The /Length of a stream matches its data'),
    (Number: '6.1.7.1-2'; Coverage: prc_Full;
      Text: 'stream is followed by CR LF or LF, endstream is preceded by an end of line'),
    (Number: '6.1.7.1-3'; Coverage: prc_Full; Text: 'A stream dictionary has no /F, /FFilter or /FDecodeParms'),
    (Number: '6.1.7.2-1'; Coverage: prc_Full;
      Text: 'Only standard stream filters except LZWDecode; Crypt only with the Identity filter'),
    (Number: '6.1.8-1'; Coverage: prc_None; Text: 'Font, colourant and structure type names are valid UTF-8'),
    (Number: '6.1.9-1'; Coverage: prc_Full;
      Text: 'One white-space character between object number, generation and obj; end of line around obj and endobj'),
    (Number: '6.1.10-1'; Coverage: prc_None; Text: 'Inline images use only permitted filters'),
    (Number: '6.1.12-1'; Coverage: prc_Full; Text: 'A permissions dictionary holds only UR3 and DocMDP'),
    (Number: '6.1.12-2'; Coverage: prc_Full;
      Text: 'With DocMDP, signature references have no DigestLocation, DigestMethod or DigestValue'),
    (Number: '6.1.13-1'; Coverage: prc_Partial; Text: 'Integers lie between -2147483648 and 2147483647'),
    (Number: '6.1.13-2'; Coverage: prc_Partial; Text: 'Real numbers lie within +/-3.403E38'),
    (Number: '6.1.13-3'; Coverage: prc_Partial; Text: 'Strings are at most 32767 bytes long'),
    (Number: '6.1.13-4'; Coverage: prc_Partial; Text: 'Names are at most 127 bytes long'),
    (Number: '6.1.13-5'; Coverage: prc_Partial; Text: 'Real numbers are zero or at least 1.175E-38 away from it'),
    (Number: '6.1.13-7'; Coverage: prc_Full; Text: 'At most 8388607 indirect objects'),
    (Number: '6.1.13-8'; Coverage: prc_None; Text: 'q/Q pairs are nested at most 28 levels deep'),
    (Number: '6.1.13-9'; Coverage: prc_None; Text: 'A DeviceN colour space has at most 32 colourants'),
    (Number: '6.1.13-10'; Coverage: prc_None; Text: 'CID values are at most 65535'),
    (Number: '6.1.13-11'; Coverage: prc_Full; Text: 'Page boundaries are between 3 and 14400 units in each direction'));

  { most pages and AcroForm fields walked together }
  MaxNodes = 200000;
  MaxTreeDepth = 64;

function LandrixEInvoicePdfARuleNumber(ARule: TLandrixEInvoicePdfARule): string;
begin
  Result := Rules[ARule].Number;
end;

function LandrixEInvoicePdfARuleId(ARule: TLandrixEInvoicePdfARule): string;
begin
  Result := 'PDFA-' + Rules[ARule].Number;
end;

function LandrixEInvoicePdfARuleText(ARule: TLandrixEInvoicePdfARule): string;
begin
  Result := Rules[ARule].Text;
end;

function LandrixEInvoicePdfARuleCoverage(ARule: TLandrixEInvoicePdfARule): TLandrixEInvoicePdfARuleCoverage;
begin
  Result := Rules[ARule].Coverage;
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

{ Bytes of the file as text: printable ASCII, '?' for anything else. }
function AsciiText(const S: AnsiString): string;
var
  I: Integer;
begin
  Result := '';
  SetLength(Result, Length(S));
  for I := 1 to Length(S) do
    if (Ord(S[I]) >= 32) and (Ord(S[I]) < 127) then
      Result[I] := Chr(Ord(S[I]))
    else
      Result[I] := '?';
end;

{ A floating point value from its text, independent of the locale. }
function FloatOf(const AText: string): Double;
var
  Code: Integer;
begin
  Val(AText, Result, Code);
  if Code <> 0 then
    Result := 0;
end;

constructor TLandrixEInvoicePdfARuleCheck.Create;
begin
  inherited Create;
  { built at run time: literals of this size lose precision as Extended }
  FMaxReal := FloatOf('3.403e38');
  FMinReal := FloatOf('1.175e-38');
  Reset;
end;

procedure TLandrixEInvoicePdfARuleCheck.Reset;
var
  R: TLandrixEInvoicePdfARule;
begin
  for R := Low(TLandrixEInvoicePdfARule) to High(TLandrixEInvoicePdfARule) do
  begin
    FResults[R].Outcome := pro_NotChecked;
    FResults[R].Failures := 0;
    FResults[R].ObjNum := -1;
    FResults[R].ObjGen := -1;
    FResults[R].Source := pss_File;
    FResults[R].Pos := -1;
    FResults[R].Detail := '';
    FIncomplete[R] := False;
  end;
  FNodes := 0;
  FLive := nil;
  FLiveCount := 0;
  FLiveByNum := nil;
end;

procedure TLandrixEInvoicePdfARuleCheck.Fail(ARule: TLandrixEInvoicePdfARule; AObjNum, AObjGen: Integer;
  ASource: TLandrixEInvoicePdfSyntaxSource; APos: Integer; const ADetail: string);
begin
  Inc(FResults[ARule].Failures);
  if FResults[ARule].Failures = 1 then
  begin
    FResults[ARule].ObjNum := AObjNum;
    FResults[ARule].ObjGen := AObjGen;
    FResults[ARule].Source := ASource;
    FResults[ARule].Pos := APos;
    FResults[ARule].Detail := ADetail;
  end;
end;

{ An offset of the object table moved past white space, as the facts record
  the envelope. }
function TLandrixEInvoicePdfARuleCheck.NormalOffset(AOffset: Int64): Integer;
var
  P: Integer;
  B: Byte;
begin
  Result := -1;
  if (AOffset < 0) or (AOffset >= Length(FDoc.Buf)) then
    Exit;
  P := Integer(AOffset);
  while P < Length(FDoc.Buf) do
  begin
    B := FDoc.Buf[P];
    if (B <> 0) and (B <> 9) and (B <> 10) and (B <> 12) and (B <> 13) and (B <> 32) then
      Break;
    Inc(P);
  end;
  Result := P;
end;

{ The envelopes of the live objects: those where the object table points. }
procedure TLandrixEInvoicePdfARuleCheck.FindLive;
var
  I, InFile: Integer;
  E: TLandrixEInvoicePdfEnvelope;
  X: TLandrixEInvoicePdfXrefEntry;
begin
  SetLength(FLive, FFacts.EnvelopeCount);
  FLiveCount := 0;
  SetLength(FLiveByNum, FDoc.XrefCount);
  for I := 0 to Integer(Length(FLiveByNum)) - 1 do
    FLiveByNum[I] := -1;
  for I := 0 to FFacts.EnvelopeCount - 1 do
  begin
    E := FFacts.Envelopes[I];
    X := FDoc.XrefEntry(E.Num);
    if not X.Known or (X.Kind <> pxk_Normal) then
      Continue;
    if NormalOffset(X.Offset) <> E.Offset then
      Continue;
    if FLiveByNum[E.Num] >= 0 then
      Continue;
    FLiveByNum[E.Num] := I;
    FLive[FLiveCount] := I;
    Inc(FLiveCount);
  end;
  { an object of the file without a live envelope was not observed }
  InFile := 0;
  for I := 0 to FDoc.XrefCount - 1 do
  begin
    X := FDoc.XrefEntry(I);
    if X.Known and (X.Kind = pxk_Normal) then
      Inc(InFile);
  end;
  if InFile > FLiveCount then
  begin
    FIncomplete[par_6_1_7_1_1] := True;
    FIncomplete[par_6_1_7_1_2] := True;
    FIncomplete[par_6_1_7_1_3] := True;
    FIncomplete[par_6_1_7_2_1] := True;
    FIncomplete[par_6_1_9_1] := True;
  end;
end;

{ Index of the live envelope of object ANum that holds position APos, -1 if
  none. }
function TLandrixEInvoicePdfARuleCheck.LiveAt(ANum, APos: Integer): Integer;
var
  E: TLandrixEInvoicePdfEnvelope;
begin
  Result := -1;
  if (ANum < 0) or (ANum >= Length(FLiveByNum)) or (FLiveByNum[ANum] < 0) then
    Exit;
  E := FFacts.Envelopes[FLiveByNum[ANum]];
  if (APos >= E.Offset) and ((E.EndobjPos < 0) or (APos < E.EndobjPos)) then
    Result := FLiveByNum[ANum];
end;

function TLandrixEInvoicePdfARuleCheck.TokenLive(const AToken: TLandrixEInvoicePdfTokenFact): Boolean;
var
  X: TLandrixEInvoicePdfXrefEntry;
begin
  if AToken.Source = pss_ObjectStream then
  begin
    X := FDoc.XrefEntry(AToken.ObjNum);
    Result := X.Known and (X.Kind = pxk_Compressed);
  end
  else if AToken.ObjNum < 0 then
    Result := (AToken.Pos >= FTrailerFrom) and (AToken.Pos < FTrailerTo)
  else
    Result := LiveAt(AToken.ObjNum, AToken.Pos) >= 0;
end;

function TLandrixEInvoicePdfARuleCheck.StreamLive(const AStream: TLandrixEInvoicePdfStreamFact): Boolean;
begin
  Result := (AStream.Source = pss_File) and (LiveAt(AStream.ObjNum, AStream.KeywordPos) >= 0);
end;

procedure TLandrixEInvoicePdfARuleCheck.Check(ADoc: TLandrixEInvoicePdfDocument; AFacts: TLandrixEInvoicePdfSyntaxFacts);
var
  R: TLandrixEInvoicePdfARule;
  I: Integer;
begin
  Reset;
  FDoc := ADoc;
  FFacts := AFacts;
  FindLive;
  { the trailer tokens of the newest classic section }
  FTrailerFrom := MaxInt;
  FTrailerTo := MaxInt;
  if (FFacts.SectionCount > 0) and not FFacts.Sections[0].IsStream then
  begin
    FTrailerFrom := FFacts.Sections[0].Offset;
    FTrailerTo := Integer(Length(FDoc.Buf));
    for I := 1 to FFacts.SectionCount - 1 do
      if (FFacts.Sections[I].Offset > FTrailerFrom) and (FFacts.Sections[I].Offset < FTrailerTo) then
        FTrailerTo := FFacts.Sections[I].Offset;
  end;

  CheckHeader;
  CheckTrailer;
  CheckXref;
  CheckStreams;
  CheckEnvelopes;
  CheckTokens;
  CheckPerms;
  if FFacts.InUseCount > 8388607 then
    Fail(par_6_1_13_7, -1, -1, pss_File, -1, IntToStr(FFacts.InUseCount) + ' indirect objects');
  if FDoc.Catalog <> nil then
    CheckPages(FDoc.DGet(FDoc.Catalog, 'Pages'), nil, nil, 0)
  else
  begin
    FIncomplete[par_6_1_12_1] := True;
    FIncomplete[par_6_1_12_2] := True;
    FIncomplete[par_6_1_13_11] := True;
  end;

  for R := Low(TLandrixEInvoicePdfARule) to High(TLandrixEInvoicePdfARule) do
    if Rules[R].Coverage = prc_None then
      FResults[R].Outcome := pro_NotChecked
    else if FResults[R].Failures > 0 then
      FResults[R].Outcome := pro_Failed
    else if (Rules[R].Coverage = prc_Partial) or not FFacts.Complete or FIncomplete[R] then
      FResults[R].Outcome := pro_Incomplete
    else
      FResults[R].Outcome := pro_Passed;
end;

function TLandrixEInvoicePdfARuleCheck.RuleResult(ARule: TLandrixEInvoicePdfARule): TLandrixEInvoicePdfARuleResult;
begin
  Result := FResults[ARule];
end;

function TLandrixEInvoicePdfARuleCheck.AnyFailed: Boolean;
var
  R: TLandrixEInvoicePdfARule;
begin
  Result := False;
  for R := Low(TLandrixEInvoicePdfARule) to High(TLandrixEInvoicePdfARule) do
    if FResults[R].Outcome = pro_Failed then
    begin
      Result := True;
      Exit;
    end;
end;

{ 6.1.2: header line at byte 0 and the binary comment after it; 6.1.3-3:
  nothing but one end of line after the last %%EOF (no %%EOF fails).
  DE: 6.1.2: Kopfzeile an Byte 0 und der Binaerkommentar danach; 6.1.3-3:
  nach dem letzten %%EOF nichts ausser einem Zeilenende (ohne %%EOF
  verletzt). }
procedure TLandrixEInvoicePdfARuleCheck.CheckHeader;
var
  H: AnsiString;
  C: AnsiString;
  I: Integer;
  Ok: Boolean;
begin
  H := FFacts.HeaderLine;
  Ok := (FFacts.HeaderOffset = 0) and (Length(H) = 8) and (Copy(H, 1, 7) = '%PDF-1.') and (H[8] >= '0') and
    (H[8] <= '7');
  if not Ok then
    Fail(par_6_1_2_1, -1, -1, pss_File, FFacts.HeaderOffset, 'header ' + AsciiText(H) + ' at offset ' +
      IntToStr(FFacts.HeaderOffset));
  C := FFacts.CommentBytes;
  Ok := Length(C) = 4;
  for I := 1 to Length(C) do
    if Ord(C[I]) <= 127 then
      Ok := False;
  if not Ok then
    Fail(par_6_1_2_2, -1, -1, pss_File, -1, 'no comment with four bytes above 127 after the header');

  { 6.1.3-3: one optional end of line after the last %%EOF }
  if FFacts.PostEofSize < 0 then
    Fail(par_6_1_3_3, -1, -1, pss_File, -1, 'no %%EOF')
  else if (FFacts.PostEofSize > 0) and not FFacts.PostEofSingleEol then
    Fail(par_6_1_3_3, -1, -1, pss_File, Integer(Length(FDoc.Buf)) - FFacts.PostEofSize,
      IntToStr(FFacts.PostEofSize) + ' bytes after %%EOF');
end;

{ 6.1.3-1 and -2 on the newest trailer (of a linearized file: the one of the
  first page, which the startxref at the end names); the identifier counts
  the bytes of all strings of /ID, as veraPDF joins them.
  DE: 6.1.3-1 und -2 am neuesten Trailer (bei einer linearisierten Datei
  dem der ersten Seite, den das startxref am Ende nennt); die Kennung
  zaehlt die Bytes aller Strings von /ID, wie veraPDF sie verbindet. }
procedure TLandrixEInvoicePdfARuleCheck.CheckTrailer;
var
  Trailer, Id, Item, Enc: TLandrixEInvoicePdfObject;
  I, IdLength: Integer;
begin
  if FFacts.SectionCount = 0 then
    Exit;
  Trailer := FFacts.Sections[0].Trailer;
  if (Trailer = nil) or not Trailer.IsDictLike then
    Exit;
  IdLength := 0;
  Id := FDoc.Resolve(Trailer.RawGet('ID'));
  if (Id <> nil) and (Id.Kind = pok_Arr) then
    for I := 0 to Id.ArrCount - 1 do
    begin
      Item := FDoc.Resolve(Id.ArrItem(I));
      if (Item <> nil) and (Item.Kind = pok_Str) then
        Inc(IdLength, Length(Item.StrVal));
    end;
  if IdLength = 0 then
    Fail(par_6_1_3_1, -1, -1, pss_File, FFacts.Sections[0].Offset, 'no file identifier in the trailer');
  Enc := FDoc.Resolve(Trailer.RawGet('Encrypt'));
  if (Trailer.RawGet('Encrypt') <> nil) and ((Enc = nil) or (Enc.Kind <> pok_Null)) then
    Fail(par_6_1_3_2, -1, -1, pss_File, FFacts.Sections[0].Offset, '/Encrypt in the trailer');
end;

{ 6.1.4-2 on every classic section of the chain. }
procedure TLandrixEInvoicePdfARuleCheck.CheckXref;
var
  I: Integer;
  S: TLandrixEInvoicePdfXrefSection;
begin
  for I := 0 to FFacts.SectionCount - 1 do
  begin
    S := FFacts.Sections[I];
    if S.IsStream then
      Continue;
    if (S.KeywordEol = peo_None) or not S.HeaderAfterEol then
      Fail(par_6_1_4_2, -1, -1, pss_File, S.Offset, 'xref at offset ' + IntToStr(S.Offset));
  end;
end;

{ 6.1.7.1 and 6.1.7.2 on the streams of live objects.
  DE: 6.1.7.1 und 6.1.7.2 an den Streams lebender Objekte. }
procedure TLandrixEInvoicePdfARuleCheck.CheckStreams;
const
  ExternalKeys: array[0..2] of AnsiString = ('F', 'FFilter', 'FDecodeParms');
var
  I, K, RealLength: Integer;
  St: TLandrixEInvoicePdfStreamFact;
  LenObj, V: TLandrixEInvoicePdfObject;
  Where: string;
begin
  for I := 0 to FFacts.StreamCount - 1 do
  begin
    St := FFacts.Streams[I];
    if not StreamLive(St) then
      Continue;
    Where := 'stream of object ' + IntToStr(St.ObjNum);
    { -1: the length of the data as written }
    if St.EndstreamPos < 0 then
      RealLength := -1
    else
      RealLength := St.EndstreamPos - EolSize(St.EndstreamEol) - St.DataStart;
    LenObj := FDoc.DGet(St.Stream, 'Length');
    { before CR LF endstream the CR may belong to the data: then LF alone is
      the end of line (veraPDF accepts it)
      DE: vor CR LF endstream kann das CR zu den Daten gehoeren: dann ist LF
      allein das Zeilenende (veraPDF akzeptiert das) }
    { compared as numbers: AsInt gives 0 for values beyond its range }
    if (LenObj <> nil) and (LenObj.Kind = pok_Num) and (St.EndstreamEol = peo_CRLF) and (RealLength >= 0) and
      (LenObj.NumVal = RealLength + 1) then
      RealLength := RealLength + 1;
    if (LenObj = nil) or (LenObj.Kind <> pok_Num) or (RealLength < 0) or (LenObj.NumVal <> RealLength) then
    begin
      if (LenObj <> nil) and (LenObj.Kind = pok_Num) and (Abs(LenObj.NumVal) < 1000000000.0) and
        (Frac(LenObj.NumVal) = 0) then
        Fail(par_6_1_7_1_1, St.ObjNum, St.ObjGen, St.Source, St.KeywordPos, Where + ': /Length ' +
          IntToStr(LenObj.AsInt) + ', data ' + IntToStr(RealLength) + ' bytes')
      else if (LenObj <> nil) and (LenObj.Kind = pok_Num) then
        Fail(par_6_1_7_1_1, St.ObjNum, St.ObjGen, St.Source, St.KeywordPos, Where + ': /Length out of range, data ' +
          IntToStr(RealLength) + ' bytes')
      else
        Fail(par_6_1_7_1_1, St.ObjNum, St.ObjGen, St.Source, St.KeywordPos, Where + ': no /Length');
    end;
    if not (St.KeywordEol in [peo_LF, peo_CRLF]) then
      Fail(par_6_1_7_1_2, St.ObjNum, St.ObjGen, St.Source, St.KeywordPos, Where + ': stream not followed by CR LF or LF')
    else if (St.EndstreamPos < 0) or (St.EndstreamEol = peo_None) then
      Fail(par_6_1_7_1_2, St.ObjNum, St.ObjGen, St.Source, St.EndstreamPos, Where +
        ': endstream not preceded by an end of line');
    for K := 0 to High(ExternalKeys) do
      if St.Stream.RawGet(ExternalKeys[K]) <> nil then
      begin
        V := FDoc.DGet(St.Stream, ExternalKeys[K]);
        if (V <> nil) and (V.Kind <> pok_Null) then
          Fail(par_6_1_7_1_3, St.ObjNum, St.ObjGen, St.Source, St.KeywordPos, Where + ': /' +
            AsciiText(ExternalKeys[K]));
      end;
    CheckFilters(St);
  end;
end;

procedure TLandrixEInvoicePdfARuleCheck.CheckFilters(const AStream: TLandrixEInvoicePdfStreamFact);
const
  Allowed: array[0..7] of AnsiString = ('ASCIIHexDecode', 'ASCII85Decode', 'FlateDecode', 'RunLengthDecode',
    'CCITTFaxDecode', 'JBIG2Decode', 'DCTDecode', 'JPXDecode');
var
  Filter, Parms, F, P, N: TLandrixEInvoicePdfObject;
  I, K, Count: Integer;
  Ok: Boolean;
  Name: AnsiString;
begin
  Filter := FDoc.DGet(AStream.Stream, 'Filter');
  if (Filter = nil) or (Filter.Kind = pok_Null) then
    Exit;
  Parms := FDoc.DGet(AStream.Stream, 'DecodeParms');
  if Filter.Kind = pok_Arr then
    Count := Filter.ArrCount
  else
    Count := 1;
  for I := 0 to Count - 1 do
  begin
    if Filter.Kind = pok_Arr then
      F := FDoc.Resolve(Filter.ArrItem(I))
    else
      F := Filter;
    if (F = nil) or (F.Kind <> pok_Name) then
    begin
      Fail(par_6_1_7_2_1, AStream.ObjNum, AStream.ObjGen, AStream.Source, AStream.KeywordPos,
        'stream of object ' + IntToStr(AStream.ObjNum) + ': a filter that is no name');
      Continue;
    end;
    Name := F.NameVal;
    Ok := False;
    for K := 0 to High(Allowed) do
      if Name = Allowed[K] then
        Ok := True;
    if Name = 'Crypt' then
    begin
      { the decode parameters of this filter; without them the Identity
        filter applies }
      P := nil;
      if (Parms <> nil) and (Parms.Kind = pok_Arr) then
      begin
        if I < Parms.ArrCount then
          P := FDoc.Resolve(Parms.ArrItem(I));
      end
      else if Filter.Kind <> pok_Arr then
        P := Parms;
      Ok := True;
      if (P <> nil) and P.IsDictLike then
      begin
        N := FDoc.DGet(P, 'Name');
        if (N <> nil) and ((N.Kind <> pok_Name) or (N.NameVal <> 'Identity')) then
          Ok := False;
      end;
    end;
    if not Ok then
      Fail(par_6_1_7_2_1, AStream.ObjNum, AStream.ObjGen, AStream.Source, AStream.KeywordPos,
        'stream of object ' + IntToStr(AStream.ObjNum) + ': filter ' + AsciiText(Name));
  end;
end;

{ 6.1.9-1 on the envelopes of live objects.
  DE: 6.1.9-1 an den Huellen lebender Objekte. }
procedure TLandrixEInvoicePdfARuleCheck.CheckEnvelopes;
var
  I: Integer;
  E: TLandrixEInvoicePdfEnvelope;
  Why: string;
begin
  for I := 0 to FLiveCount - 1 do
  begin
    E := FFacts.Envelopes[FLive[I]];
    Why := '';
    if E.SpacesNumGen <> 1 then
      Why := 'not one white-space character after the object number'
    else if E.SpacesGenObj <> 1 then
      Why := 'not one white-space character after the generation'
    else if E.EolBefore = peo_None then
      Why := 'no end of line before the object number'
    else if E.ObjEol = peo_None then
      Why := 'no end of line after obj'
    else if E.EndobjPos < 0 then
      Why := 'no endobj'
    else if E.EndobjEolBefore = peo_None then
      Why := 'no end of line before endobj'
    else if E.EndobjEolAfter = peo_None then
      Why := 'no end of line after endobj';
    if Why <> '' then
      Fail(par_6_1_9_1, E.Num, E.Gen, pss_File, E.Offset, 'object ' + IntToStr(E.Num) + ': ' + Why);
  end;
end;

{ 6.1.6 and 6.1.13-1 to -5 on the numbers, strings and names of live
  objects and of the newest trailer (partial: content streams are not
  read).
  DE: 6.1.6 und 6.1.13-1 bis -5 an den Zahlen, Strings und Namen lebender
  Objekte und des neuesten Trailers (teilweise: Content-Streams werden
  nicht gelesen). }
procedure TLandrixEInvoicePdfARuleCheck.CheckTokens;
var
  I: Integer;
  T: TLandrixEInvoicePdfTokenFact;
  Where: string;
begin
  for I := 0 to FFacts.TokenCount - 1 do
  begin
    T := FFacts.Tokens[I];
    if not TokenLive(T) then
      Continue;
    if T.ObjNum < 0 then
      Where := 'trailer'
    else
      Where := 'object ' + IntToStr(T.ObjNum);
    case T.Kind of
      ptk_Integer:
        if (T.Value > 2147483647.0) or (T.Value < -2147483648.0) then
          Fail(par_6_1_13_1, T.ObjNum, T.ObjGen, T.Source, T.Pos, Where + ': integer out of range');
      ptk_Real:
        begin
          if (T.Value > FMaxReal) or (T.Value < -FMaxReal) then
            Fail(par_6_1_13_2, T.ObjNum, T.ObjGen, T.Source, T.Pos, Where + ': real out of range');
          if (T.Value <> 0) and (T.Value < FMinReal) and (T.Value > -FMinReal) then
            Fail(par_6_1_13_5, T.ObjNum, T.ObjGen, T.Source, T.Pos, Where + ': real too close to zero');
        end;
      ptk_String, ptk_HexString:
        begin
          if T.Length > 32767 then
            Fail(par_6_1_13_3, T.ObjNum, T.ObjGen, T.Source, T.Pos, Where + ': string of ' + IntToStr(T.Length) +
              ' bytes');
          if T.Kind = ptk_HexString then
          begin
            if Odd(T.HexChars) then
              Fail(par_6_1_6_1, T.ObjNum, T.ObjGen, T.Source, T.Pos, Where + ': odd number of hexadecimal characters');
            if T.HexInvalid then
              Fail(par_6_1_6_2, T.ObjNum, T.ObjGen, T.Source, T.Pos, Where + ': character that is no hexadecimal digit');
          end;
        end;
      ptk_Name:
        if T.Length > 127 then
          Fail(par_6_1_13_4, T.ObjNum, T.ObjGen, T.Source, T.Pos, Where + ': name of ' + IntToStr(T.Length) + ' bytes');
    end;
  end;
end;

{ 6.1.12: the permissions dictionary and, with DocMDP, the signature
  references of every signature (the DocMDP and UR3 signatures and the
  signature fields of the AcroForm).
  DE: 6.1.12: das Berechtigungs-Dictionary und, mit DocMDP, die
  Signaturreferenzen jeder Signatur (die DocMDP- und UR3-Signatur und die
  Signaturfelder des AcroForm). }
procedure TLandrixEInvoicePdfARuleCheck.CheckPerms;
var
  Perms, Form: TLandrixEInvoicePdfObject;
  I: Integer;
begin
  if FDoc.Catalog = nil then
    Exit;
  Perms := FDoc.DGet(FDoc.Catalog, 'Perms');
  if (Perms = nil) or not Perms.IsDictLike then
    Exit;
  for I := 0 to Integer(Perms.DVals.Count) - 1 do
    if (Perms.DKeys[I] <> 'UR3') and (Perms.DKeys[I] <> 'DocMDP') then
      Fail(par_6_1_12_1, -1, -1, pss_File, -1, 'permissions key /' + AsciiText(Perms.DKeys[I]));
  if Perms.RawGet('DocMDP') = nil then
    Exit;
  CheckSignature(FDoc.DGet(Perms, 'DocMDP'));
  CheckSignature(FDoc.DGet(Perms, 'UR3'));
  Form := FDoc.DGet(FDoc.Catalog, 'AcroForm');
  if (Form <> nil) and Form.IsDictLike then
    CheckFields(FDoc.DGet(Form, 'Fields'), '', 0);
end;

procedure TLandrixEInvoicePdfARuleCheck.CheckSignature(ASig: TLandrixEInvoicePdfObject);
const
  DigestKeys: array[0..2] of AnsiString = ('DigestLocation', 'DigestMethod', 'DigestValue');
var
  Refs, R: TLandrixEInvoicePdfObject;
  I, K: Integer;
begin
  if (ASig = nil) or not ASig.IsDictLike then
    Exit;
  Refs := FDoc.DGet(ASig, 'Reference');
  if (Refs = nil) or (Refs.Kind <> pok_Arr) then
    Exit;
  for I := 0 to Refs.ArrCount - 1 do
  begin
    R := FDoc.Resolve(Refs.ArrItem(I));
    if (R = nil) or not R.IsDictLike then
      Continue;
    for K := 0 to High(DigestKeys) do
      if R.RawGet(DigestKeys[K]) <> nil then
        Fail(par_6_1_12_2, -1, -1, pss_File, -1, 'signature reference with /' + AsciiText(DigestKeys[K]));
  end;
end;

{ AField: an array of fields or one field; the field type is inherited. }
procedure TLandrixEInvoicePdfARuleCheck.CheckFields(AField: TLandrixEInvoicePdfObject; const AInheritedType: AnsiString;
  ADepth: Integer);
var
  I: Integer;
  FT: TLandrixEInvoicePdfObject;
  FieldType: AnsiString;
begin
  if AField = nil then
    Exit;
  { a limit leaves the rule incomplete; the node budget also stops cycles }
  Inc(FNodes);
  if (ADepth > MaxTreeDepth) or (FNodes > MaxNodes) then
  begin
    FIncomplete[par_6_1_12_2] := True;
    Exit;
  end;
  if AField.Kind = pok_Arr then
  begin
    for I := 0 to AField.ArrCount - 1 do
      CheckFields(FDoc.Resolve(AField.ArrItem(I)), AInheritedType, ADepth + 1);
    Exit;
  end;
  if not AField.IsDictLike then
    Exit;
  FieldType := AInheritedType;
  FT := FDoc.DGet(AField, 'FT');
  if (FT <> nil) and (FT.Kind = pok_Name) then
    FieldType := FT.NameVal;
  if FieldType = 'Sig' then
    CheckSignature(FDoc.DGet(AField, 'V'));
  CheckFields(FDoc.DGet(AField, 'Kids'), FieldType, ADepth + 1);
end;

{ 6.1.13-11: MediaBox and CropBox (inherited) and the BleedBox, TrimBox and
  ArtBox of every page.
  DE: 6.1.13-11: MediaBox und CropBox (geerbt) und BleedBox, TrimBox und
  ArtBox jeder Seite. }
procedure TLandrixEInvoicePdfARuleCheck.CheckPages(ANode, AMediaBox, ACropBox: TLandrixEInvoicePdfObject;
  ADepth: Integer);
var
  Kids, Box, Media, Crop, TypeObj: TLandrixEInvoicePdfObject;
  I: Integer;
begin
  { a page tree node that does not resolve leaves boxes unchecked }
  if (ANode = nil) or not ANode.IsDictLike then
  begin
    FIncomplete[par_6_1_13_11] := True;
    Exit;
  end;
  Inc(FNodes);
  if (ADepth > MaxTreeDepth) or (FNodes > MaxNodes) then
  begin
    FIncomplete[par_6_1_13_11] := True;
    Exit;
  end;
  Media := AMediaBox;
  Crop := ACropBox;
  Box := FDoc.DGet(ANode, 'MediaBox');
  if Box <> nil then
    Media := Box;
  Box := FDoc.DGet(ANode, 'CropBox');
  if Box <> nil then
    Crop := Box;
  TypeObj := FDoc.DGet(ANode, 'Type');
  Kids := FDoc.DGet(ANode, 'Kids');
  if (Kids <> nil) and (Kids.Kind = pok_Arr) and not ((TypeObj <> nil) and (TypeObj.Kind = pok_Name) and
    (TypeObj.NameVal = 'Page')) then
  begin
    for I := 0 to Kids.ArrCount - 1 do
      CheckPages(FDoc.Resolve(Kids.ArrItem(I)), Media, Crop, ADepth + 1);
    Exit;
  end;
  CheckBox(Media, 'MediaBox');
  CheckBox(Crop, 'CropBox');
  CheckBox(FDoc.DGet(ANode, 'BleedBox'), 'BleedBox');
  CheckBox(FDoc.DGet(ANode, 'TrimBox'), 'TrimBox');
  CheckBox(FDoc.DGet(ANode, 'ArtBox'), 'ArtBox');
end;

procedure TLandrixEInvoicePdfARuleCheck.CheckBox(ABox: TLandrixEInvoicePdfObject; const AName: string);
var
  V: array[0..3] of Double;
  I: Integer;
  O: TLandrixEInvoicePdfObject;
  W, H: Double;
begin
  if (ABox = nil) or (ABox.Kind <> pok_Arr) or (ABox.ArrCount <> 4) then
    Exit;
  for I := 0 to 3 do
  begin
    O := FDoc.Resolve(ABox.ArrItem(I));
    if (O = nil) or (O.Kind <> pok_Num) then
      Exit;
    V[I] := O.NumVal;
  end;
  W := Abs(V[2] - V[0]);
  H := Abs(V[3] - V[1]);
  if (W < 3) or (W > 14400) or (H < 3) or (H > 14400) then
    Fail(par_6_1_13_11, -1, -1, pss_File, -1, AName + ' outside 3 to 14400 units');
end;

end.
