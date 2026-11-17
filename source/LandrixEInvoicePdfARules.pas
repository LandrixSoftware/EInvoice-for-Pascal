{
  EInvoice-for-Pascal

  Copyright (C) 2026 Landrix Software GmbH & Co. KG

  This file is dual-licensed under:
  - GNU GPL version 3 or later; or
  - the Landrix Software Commercial License.

  See LICENSE and COMMERCIAL-LICENSE.md.

  SPDX-License-Identifier: GPL-3.0-or-later OR LicenseRef-Landrix-Commercial
}

{ The PDF/A-3b rules of clauses 6.1 (file structure), 6.3 (annotations), 6.4
  (interactive forms) and 6.5 (actions) of ISO 19005-3, checked on the raw
  syntax facts of LandrixEInvoicePdfSyntax and the objects of the document.
  The rules carry the numbers of the veraPDF validation profile
  ("6.1.2-1": clause and test number; the finding ID is "PDFA-6.1.2-1"), so
  that results compare with veraPDF rule by rule. A registry states for every
  rule how far it is implemented: prc_Full rules are checked in their whole
  scope; prc_Partial rules miss part of it (numbers, strings and names in
  content streams are not read yet), so a failure is evidence but no failure
  proves nothing; prc_None rules are not checked. The checked population is
  the live object set of the object table (also unreferenced and compressed
  objects), the newest trailer and every section of the xref chain; older
  revisions of objects are not judged. Annotations, actions and form fields
  are found where veraPDF finds them: the /Annots of the pages, the actions
  of /A, of the named /AA events, of a dictionary /OpenAction, of outline
  items and their /Next chains, the AcroForm /Fields with kids that have /T.

  DE: Die PDF/A-3b-Regeln der Abschnitte 6.1 (Dateistruktur), 6.3
  (Annotationen), 6.4 (interaktive Formulare) und 6.5 (Aktionen) der ISO
  19005-3, geprueft auf den rohen Syntax-Tatsachen von
  LandrixEInvoicePdfSyntax und den Objekten des Dokuments. Die Regeln tragen die Nummern des
  veraPDF-Pruefprofils ("6.1.2-1": Abschnitt und Testnummer; die Befund-ID ist
  "PDFA-6.1.2-1"), damit sich Ergebnisse Regel fuer Regel mit veraPDF
  vergleichen lassen. Ein Register sagt fuer jede Regel, wie weit sie umgesetzt
  ist: prc_Full-Regeln werden in ihrem ganzen Umfang geprueft; prc_Partial-
  Regeln fehlt ein Teil davon (Zahlen, Strings und Namen in Content-Streams
  werden noch nicht gelesen), ein Verstoss ist also ein Beleg, kein Verstoss
  beweist nichts; prc_None-Regeln werden nicht geprueft. Geprueft wird die
  lebende Objektmenge der Objekttabelle (auch Objekte ohne Verweis und
  komprimierte), der neueste Trailer und jeder Abschnitt der xref-Kette;
  aeltere Fassungen von Objekten werden nicht beurteilt. Annotationen,
  Aktionen und Formularfelder werden dort gefunden, wo veraPDF sie findet:
  die /Annots der Seiten, die Aktionen von /A, der benannten /AA-Ereignisse,
  eines Dictionary-/OpenAction, von Gliederungseintraegen und ihren
  /Next-Ketten, die AcroForm-/Fields mit Kindern, die /T haben. }

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
  { The rules of clauses 6.1 and 6.3 to 6.5 in the veraPDF profile PDF/A-3B,
    named after clause and test number.
    DE: Die Regeln der Abschnitte 6.1 und 6.3 bis 6.5 im veraPDF-Profil
    PDF/A-3B, benannt nach Abschnitt und Testnummer. }
  TLandrixEInvoicePdfARule = (
    par_6_1_2_1, par_6_1_2_2, par_6_1_3_1, par_6_1_3_2, par_6_1_3_3, par_6_1_4_2, par_6_1_6_1, par_6_1_6_2,
    par_6_1_7_1_1, par_6_1_7_1_2, par_6_1_7_1_3, par_6_1_7_2_1, par_6_1_8_1, par_6_1_9_1, par_6_1_10_1,
    par_6_1_12_1, par_6_1_12_2, par_6_1_13_1, par_6_1_13_2, par_6_1_13_3, par_6_1_13_4, par_6_1_13_5,
    par_6_1_13_7, par_6_1_13_8, par_6_1_13_9, par_6_1_13_10, par_6_1_13_11,
    par_6_3_1_1, par_6_3_2_1, par_6_3_2_2, par_6_3_3_1, par_6_3_3_2, par_6_3_3_3, par_6_3_3_4,
    par_6_4_1_1, par_6_4_1_2, par_6_4_1_3, par_6_4_2_1, par_6_4_2_2, par_6_4_3_1, par_6_4_3_2, par_6_4_3_3,
    par_6_5_1_1, par_6_5_1_2, par_6_5_2_1, par_6_5_2_2);

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

  { Checks the rules on a document and its facts.
    DE: Prueft die Regeln an einem Dokument und seinen Tatsachen. }
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
    { 2^63: /F values from here on are saturated }
    FInt64Limit: Double;
    { rules whose scope could not be walked to the end (a limit, no
      catalog, objects without envelope) }
    FIncomplete: array[TLandrixEInvoicePdfARule] of Boolean;
    { pages and form fields walked for clause 6.1; annotations, actions,
      fields and outline items walked for stage B }
    FNodes: Integer;
    FNodesB: Integer;
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
    procedure MarkStageB;
    function Where(AObj: TLandrixEInvoicePdfObject): string;
    procedure FailAt(ARule: TLandrixEInvoicePdfARule; AObj: TLandrixEInvoicePdfObject; const ADetail: string);
    function Known(ADict: TLandrixEInvoicePdfObject; const AKey: AnsiString): Boolean;
    function FieldType(AAnnot: TLandrixEInvoicePdfObject; out AType: AnsiString): Boolean;
    procedure CheckAnnot(AAnnot: TLandrixEInvoicePdfObject);
    procedure CheckEvents(AAA: TLandrixEInvoicePdfObject; const AEvents: array of AnsiString);
    function StageBBudget(ADepth: Integer): Boolean;
    procedure CheckAction(AAction: TLandrixEInvoicePdfObject; ADepth: Integer);
    procedure CheckForm;
    procedure CheckFormField(AField: TLandrixEInvoicePdfObject; ADepth: Integer);
    procedure CheckCatalogActions;
    procedure CheckOutline(AItem: TLandrixEInvoicePdfObject; ADepth: Integer);
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
    (Number: '6.1.13-11'; Coverage: prc_Full; Text: 'Page boundaries are between 3 and 14400 units in each direction'),
    (Number: '6.3.1-1'; Coverage: prc_Full;
      Text: 'Only annotation types of ISO 32000-1 except 3D, Sound, Screen and Movie'),
    (Number: '6.3.2-1'; Coverage: prc_Full; Text: 'Every annotation except Popup has the flags /F'),
    (Number: '6.3.2-2'; Coverage: prc_Full;
      Text: 'Annotation flags: Print set; Invisible, Hidden, NoView and ToggleNoView clear'),
    (Number: '6.3.3-1'; Coverage: prc_Full;
      Text: 'An annotation has an appearance dictionary (except Popup, Link and empty rectangles)'),
    (Number: '6.3.3-2'; Coverage: prc_Full; Text: 'An appearance dictionary holds only the key N'),
    (Number: '6.3.3-3'; Coverage: prc_Full;
      Text: 'The N appearance of a button widget is a subdictionary of appearance streams'),
    (Number: '6.3.3-4'; Coverage: prc_Full; Text: 'The N appearance of any other annotation is a stream'),
    (Number: '6.4.1-1'; Coverage: prc_Full; Text: 'A widget annotation has no /A and no /AA'),
    (Number: '6.4.1-2'; Coverage: prc_Full; Text: 'A form field has no /AA'),
    (Number: '6.4.1-3'; Coverage: prc_Full; Text: 'NeedAppearances is absent or false'),
    (Number: '6.4.2-1'; Coverage: prc_Full; Text: 'The interactive form has no /XFA'),
    (Number: '6.4.2-2'; Coverage: prc_Full; Text: 'The catalog has no NeedsRendering true'),
    (Number: '6.4.3-1'; Coverage: prc_None; Text: 'A signature digest covers the whole file except the signature'),
    (Number: '6.4.3-2'; Coverage: prc_None; Text: 'The PKCS#7 signature holds the signing certificate'),
    (Number: '6.4.3-3'; Coverage: prc_None; Text: 'The PKCS#7 signature has one SignerInfo'),
    (Number: '6.5.1-1'; Coverage: prc_Full;
      Text: 'Only the actions GoTo, GoToR, GoToE, Thread, URI, Named and SubmitForm'),
    (Number: '6.5.1-2'; Coverage: prc_Full; Text: 'Only the named actions NextPage, PrevPage, FirstPage and LastPage'),
    (Number: '6.5.2-1'; Coverage: prc_Full; Text: 'The catalog has no additional actions /AA'),
    (Number: '6.5.2-2'; Coverage: prc_Full; Text: 'A page has no additional actions /AA'));

  { most pages and AcroForm fields walked together }
  MaxNodes = 200000;
  MaxTreeDepth = 64;
  { longest /Parent chain of a form field followed }
  MaxParentChain = 1024;

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
  FInt64Limit := FloatOf('9223372036854775808');
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
  FNodesB := 0;
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
  begin
    CheckPages(FDoc.DGet(FDoc.Catalog, 'Pages'), nil, nil, 0);
    CheckForm;
    CheckCatalogActions;
  end
  else
  begin
    FIncomplete[par_6_1_12_1] := True;
    FIncomplete[par_6_1_12_2] := True;
    FIncomplete[par_6_1_13_11] := True;
    MarkStageB;
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
  Kids, Box, Media, Crop, TypeObj, Annots, A: TLandrixEInvoicePdfObject;
  I: Integer;
begin
  { a page tree node that does not resolve leaves boxes, annotations and
    page actions unchecked }
  if (ANode = nil) or not ANode.IsDictLike then
  begin
    FIncomplete[par_6_1_13_11] := True;
    MarkStageB;
    Exit;
  end;
  Inc(FNodes);
  if (ADepth > MaxTreeDepth) or (FNodes > MaxNodes) then
  begin
    FIncomplete[par_6_1_13_11] := True;
    MarkStageB;
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
  { 6.5.2-2 and the page events O and C; the annotations of the page }
  if Known(ANode, 'AA') then
    FailAt(par_6_5_2_2, ANode, 'page with /AA');
  CheckEvents(FDoc.DGet(ANode, 'AA'), ['O', 'C']);
  Annots := FDoc.DGet(ANode, 'Annots');
  if (Annots <> nil) and (Annots.Kind = pok_Arr) then
    for I := 0 to Annots.ArrCount - 1 do
    begin
      A := FDoc.Resolve(Annots.ArrItem(I));
      if (A <> nil) and A.IsDictLike then
        CheckAnnot(A);
    end;
end;

{ The rules of 6.3 to 6.5 cannot all be checked: a limit or a broken
  catalog or page tree. }
procedure TLandrixEInvoicePdfARuleCheck.MarkStageB;
var
  R: TLandrixEInvoicePdfARule;
begin
  for R := par_6_3_1_1 to par_6_5_2_2 do
    FIncomplete[R] := True;
end;

{ Where an object is: the indirect object it belongs to. }
function TLandrixEInvoicePdfARuleCheck.Where(AObj: TLandrixEInvoicePdfObject): string;
begin
  if (AObj <> nil) and (AObj.OwnerNum >= 0) then
    Result := 'object ' + IntToStr(AObj.OwnerNum)
  else
    Result := 'an object';
end;

procedure TLandrixEInvoicePdfARuleCheck.FailAt(ARule: TLandrixEInvoicePdfARule; AObj: TLandrixEInvoicePdfObject;
  const ADetail: string);
begin
  if (AObj <> nil) and (AObj.OwnerNum >= 0) then
    Fail(ARule, AObj.OwnerNum, AObj.OwnerGen, pss_File, -1, Where(AObj) + ': ' + ADetail)
  else
    Fail(ARule, -1, -1, pss_File, -1, ADetail);
end;

{ A key is present as veraPDF sees it: a direct null counts as absent.
  DE: Ein Schluessel ist vorhanden, wie veraPDF es sieht: ein direktes null
  zaehlt als fehlend. }
function TLandrixEInvoicePdfARuleCheck.Known(ADict: TLandrixEInvoicePdfObject; const AKey: AnsiString): Boolean;
var
  V: TLandrixEInvoicePdfObject;
begin
  Result := False;
  if (ADict = nil) or not ADict.IsDictLike then
    Exit;
  V := ADict.RawGet(AKey);
  Result := (V <> nil) and (V.Kind <> pok_Null);
end;

{ The field type of a widget: its own /FT or the first one up its /Parent
  chain; a /FT that is no name ends the search with none. False if the chain
  is longer than MaxParentChain (a cycle): the type is unknown.
  DE: Der Feldtyp eines Widgets: sein eigenes /FT oder das erste die
  /Parent-Kette hinauf; ein /FT, das kein Name ist, beendet die Suche ohne
  Ergebnis. False, wenn die Kette laenger als MaxParentChain ist (ein
  Zyklus): der Typ ist unbekannt. }
function TLandrixEInvoicePdfARuleCheck.FieldType(AAnnot: TLandrixEInvoicePdfObject; out AType: AnsiString): Boolean;
var
  Node, FT: TLandrixEInvoicePdfObject;
  Depth: Integer;
begin
  AType := '';
  Result := True;
  Node := AAnnot;
  Depth := 0;
  while (Node <> nil) and Node.IsDictLike do
  begin
    if Depth > MaxParentChain then
    begin
      Result := False;
      Exit;
    end;
    if Known(Node, 'FT') then
    begin
      FT := FDoc.DGet(Node, 'FT');
      if (FT <> nil) and (FT.Kind = pok_Name) then
        AType := FT.NameVal;
      Exit;
    end;
    Node := FDoc.DGet(Node, 'Parent');
    Inc(Depth);
  end;
end;

{ One more node of stage B; False (and the stage B rules incomplete) beyond
  the depth limit or the node budget.
  DE: Ein weiterer Knoten von Stufe B; False (und die Regeln von Stufe B
  unvollstaendig) jenseits der Tiefengrenze oder des Knotenbudgets. }
function TLandrixEInvoicePdfARuleCheck.StageBBudget(ADepth: Integer): Boolean;
begin
  Inc(FNodesB);
  Result := (ADepth <= MaxTreeDepth) and (FNodesB <= MaxNodes);
  if not Result then
    MarkStageB;
end;

{ 6.3 and 6.4.1-1 on one annotation of a page, and its actions.
  DE: 6.3 und 6.4.1-1 an einer Annotation einer Seite und ihre Aktionen. }
procedure TLandrixEInvoicePdfARuleCheck.CheckAnnot(AAnnot: TLandrixEInvoicePdfObject);
const
  Allowed: array[0..21] of AnsiString = ('Text', 'Link', 'FreeText', 'Line', 'Square', 'Circle', 'Polygon',
    'PolyLine', 'Highlight', 'Underline', 'Squiggly', 'StrikeOut', 'Stamp', 'Caret', 'Ink', 'Popup',
    'FileAttachment', 'Widget', 'PrinterMark', 'TrapNet', 'Watermark', 'Redact');
var
  Sub, FObj, Rect, O, AP, N, Entry, V: TLandrixEInvoicePdfObject;
  Subtype, APKeys, NType, FT: AnsiString;
  Flags: Int64;
  HasFlags, HasRect, Ok, Appearances: Boolean;
  R: array[0..3] of Double;
  I, Count, K: Integer;
  TypeKnown, Seen: Boolean;
begin
  if not StageBBudget(0) then
    Exit;
  Subtype := '';
  Sub := FDoc.DGet(AAnnot, 'Subtype');
  if (Sub <> nil) and (Sub.Kind = pok_Name) then
    Subtype := Sub.NameVal;
  Ok := False;
  for I := 0 to High(Allowed) do
    if Subtype = Allowed[I] then
      Ok := True;
  if not Ok then
    FailAt(par_6_3_1_1, AAnnot, 'annotation type ' + AsciiText(Subtype));

  { /F as veraPDF reads it: a number truncated toward zero (saturated to the
    64-bit range), anything else none
    DE: /F, wie veraPDF es liest: eine Zahl, zur Null hin abgeschnitten (auf
    den 64-Bit-Bereich begrenzt), alles andere keines }
  HasFlags := False;
  Flags := 0;
  FObj := FDoc.DGet(AAnnot, 'F');
  if Known(AAnnot, 'F') and (FObj <> nil) and (FObj.Kind = pok_Num) then
  begin
    HasFlags := True;
    if FObj.NumVal >= FInt64Limit then
      Flags := High(Int64)
    else if FObj.NumVal <= -FInt64Limit then
      Flags := Low(Int64)
    else
      Flags := Trunc(FObj.NumVal);
  end;
  if (Subtype <> 'Popup') and not HasFlags then
    FailAt(par_6_3_2_1, AAnnot, AsciiText(Subtype) + ' annotation without /F');
  if HasFlags and not (((Flags and 1) = 0) and ((Flags and 2) = 0) and ((Flags and 4) = 4) and ((Flags and 32) = 0) and
    ((Flags and 256) = 0)) then
    FailAt(par_6_3_2_2, AAnnot, 'annotation flags ' + IntToStr(Flags));

  { the rectangle: x2 - x1 and y2 - y1 without absolute value; an element
    that is no number makes it unknown
    DE: das Rechteck: x2 - x1 und y2 - y1 ohne Betrag; ein Element, das keine
    Zahl ist, macht es unbekannt }
  HasRect := False;
  Rect := FDoc.DGet(AAnnot, 'Rect');
  if (Rect <> nil) and (Rect.Kind = pok_Arr) and (Rect.ArrCount >= 4) then
  begin
    HasRect := True;
    Count := Rect.ArrCount;
    for I := 0 to Count - 1 do
    begin
      O := FDoc.Resolve(Rect.ArrItem(I));
      if (O = nil) or (O.Kind <> pok_Num) then
        HasRect := False
      else if I <= 3 then
        R[I] := O.NumVal;
    end;
  end;

  { the appearance dictionary: its keys joined with & ('' if empty; a key
    written twice counts once), none if /AP is no dictionary
    DE: das Erscheinungs-Dictionary: seine Schluessel mit & verbunden (''
    wenn leer; ein doppelt geschriebener Schluessel zaehlt einmal), keines,
    wenn /AP kein Dictionary ist }
  AP := FDoc.DGet(AAnnot, 'AP');
  if (AP <> nil) and (AP.Kind <> pok_Dict) then
    AP := nil;
  APKeys := '';
  if AP <> nil then
    for I := 0 to Integer(AP.DVals.Count) - 1 do
      if Known(AP, AP.DKeys[I]) then
      begin
        Seen := False;
        for K := 0 to I - 1 do
          if AP.DKeys[K] = AP.DKeys[I] then
            Seen := True;
        if Seen then
          Continue;
        if APKeys <> '' then
          APKeys := APKeys + '&';
        APKeys := APKeys + AP.DKeys[I];
      end;
  if (AP = nil) and (Subtype <> 'Popup') and (Subtype <> 'Link') and
    not (HasRect and (R[2] - R[0] = 0) and (R[3] - R[1] = 0)) then
    FailAt(par_6_3_3_1, AAnnot, AsciiText(Subtype) + ' annotation without appearance');
  if (AP <> nil) and (APKeys <> 'N') then
    FailAt(par_6_3_3_2, AAnnot, 'appearance keys ' + AsciiText(APKeys));
  if (AP <> nil) and (APKeys = 'N') then
  begin
    NType := '';
    N := FDoc.DGet(AP, 'N');
    if N <> nil then
      if N.Kind = pok_Stream then
        NType := 'Stream'
      else if N.Kind = pok_Dict then
        NType := 'Dict';
    { the first appearance of N, D, R: a stream, or a subdictionary with at
      least one stream
      DE: die erste Erscheinung von N, D, R: ein Stream oder ein
      Unter-Dictionary mit mindestens einem Stream }
    Appearances := False;
    Entry := nil;
    if Known(AP, 'N') then
      Entry := FDoc.DGet(AP, 'N')
    else if Known(AP, 'D') then
      Entry := FDoc.DGet(AP, 'D')
    else if Known(AP, 'R') then
      Entry := FDoc.DGet(AP, 'R');
    if Entry <> nil then
      if Entry.Kind = pok_Stream then
        Appearances := True
      else if Entry.Kind = pok_Dict then
        for I := 0 to Integer(Entry.DVals.Count) - 1 do
        begin
          V := FDoc.DGet(Entry, Entry.DKeys[I]);
          if (V <> nil) and (V.Kind = pok_Stream) then
            Appearances := True;
        end;
    FT := '';
    TypeKnown := True;
    if Subtype = 'Widget' then
      TypeKnown := FieldType(AAnnot, FT);
    if not TypeKnown then
    begin
      FIncomplete[par_6_3_3_3] := True;
      FIncomplete[par_6_3_3_4] := True;
    end
    else
    begin
      if (Subtype = 'Widget') and (FT = 'Btn') and not ((NType = 'Dict') and Appearances) then
        FailAt(par_6_3_3_3, AAnnot, 'button widget without appearance subdictionary');
      if not ((Subtype = 'Widget') and (FT = 'Btn')) and (NType <> 'Stream') then
        FailAt(par_6_3_3_4, AAnnot, AsciiText(Subtype) + ' annotation whose N appearance is no stream');
    end;
  end;

  if (Subtype = 'Widget') and (Known(AAnnot, 'A') or Known(AAnnot, 'AA')) then
    FailAt(par_6_4_1_1, AAnnot, 'widget with /A or /AA');
  { an action is a dictionary; a stream is none
    DE: eine Aktion ist ein Dictionary; ein Stream ist keine }
  O := FDoc.DGet(AAnnot, 'A');
  if (O <> nil) and (O.Kind = pok_Dict) then
    CheckAction(O, 0);
  CheckEvents(FDoc.DGet(AAnnot, 'AA'), ['E', 'X', 'D', 'U', 'Fo', 'Bl', 'PO', 'PC', 'PV', 'PI']);
end;

{ The actions of the named events of an additional-actions dictionary.
  DE: Die Aktionen der benannten Ereignisse eines Zusatzaktionen-
  Dictionarys. }
procedure TLandrixEInvoicePdfARuleCheck.CheckEvents(AAA: TLandrixEInvoicePdfObject; const AEvents: array of AnsiString);
var
  I: Integer;
  A: TLandrixEInvoicePdfObject;
begin
  if (AAA = nil) or not AAA.IsDictLike then
    Exit;
  for I := 0 to Integer(Length(AEvents)) - 1 do
  begin
    A := FDoc.DGet(AAA, AEvents[I]);
    if (A <> nil) and (A.Kind = pok_Dict) then
      CheckAction(A, 0);
  end;
end;

{ 6.5.1 on an action and its /Next chain (a dictionary or an array).
  DE: 6.5.1 an einer Aktion und ihrer /Next-Kette (ein Dictionary oder ein
  Array). }
procedure TLandrixEInvoicePdfARuleCheck.CheckAction(AAction: TLandrixEInvoicePdfObject; ADepth: Integer);
const
  Allowed: array[0..6] of AnsiString = ('GoTo', 'GoToR', 'GoToE', 'Thread', 'URI', 'Named', 'SubmitForm');
  Named: array[0..3] of AnsiString = ('NextPage', 'PrevPage', 'FirstPage', 'LastPage');
var
  S, N, Next, A: TLandrixEInvoicePdfObject;
  Kind, Name: AnsiString;
  I: Integer;
  Ok: Boolean;
begin
  if not StageBBudget(ADepth) then
    Exit;
  Kind := '';
  S := FDoc.DGet(AAction, 'S');
  if (S <> nil) and (S.Kind = pok_Name) then
    Kind := S.NameVal;
  Ok := False;
  for I := 0 to High(Allowed) do
    if Kind = Allowed[I] then
      Ok := True;
  if not Ok then
    FailAt(par_6_5_1_1, AAction, 'action ' + AsciiText(Kind));
  if Kind = 'Named' then
  begin
    Name := '';
    N := FDoc.DGet(AAction, 'N');
    if (N <> nil) and (N.Kind = pok_Name) then
      Name := N.NameVal;
    Ok := False;
    for I := 0 to High(Named) do
      if Name = Named[I] then
        Ok := True;
    if not Ok then
      FailAt(par_6_5_1_2, AAction, 'named action ' + AsciiText(Name));
  end;
  Next := FDoc.DGet(AAction, 'Next');
  if Next = nil then
    Exit;
  if Next.Kind = pok_Dict then
    CheckAction(Next, ADepth + 1)
  else if Next.Kind = pok_Arr then
    for I := 0 to Next.ArrCount - 1 do
    begin
      A := FDoc.Resolve(Next.ArrItem(I));
      if (A <> nil) and (A.Kind = pok_Dict) then
        CheckAction(A, ADepth + 1);
    end;
end;

{ 6.4.1-3, 6.4.2-1 and the form fields (6.4.1-2, their actions).
  DE: 6.4.1-3, 6.4.2-1 und die Formularfelder (6.4.1-2, ihre Aktionen). }
procedure TLandrixEInvoicePdfARuleCheck.CheckForm;
var
  Form, NA, Fields, F: TLandrixEInvoicePdfObject;
  I: Integer;
begin
  Form := FDoc.DGet(FDoc.Catalog, 'AcroForm');
  if (Form = nil) or not Form.IsDictLike then
    Exit;
  { a boolean counts as it is, any other value as true }
  if Known(Form, 'NeedAppearances') then
  begin
    NA := FDoc.DGet(Form, 'NeedAppearances');
    if (NA = nil) or (NA.Kind <> pok_Bool) or NA.BoolVal then
      FailAt(par_6_4_1_3, Form, 'NeedAppearances');
  end;
  if Known(Form, 'XFA') then
    FailAt(par_6_4_2_1, Form, 'interactive form with /XFA');
  Fields := FDoc.DGet(Form, 'Fields');
  if (Fields <> nil) and (Fields.Kind = pok_Arr) then
    for I := 0 to Fields.ArrCount - 1 do
    begin
      F := FDoc.Resolve(Fields.ArrItem(I));
      if (F <> nil) and F.IsDictLike then
        CheckFormField(F, 0);
    end;
end;

{ A form field: 6.4.1-2, the events K, F, V, C; kids with /T are fields.
  DE: Ein Formularfeld: 6.4.1-2, die Ereignisse K, F, V, C; Kinder mit /T
  sind Felder. }
procedure TLandrixEInvoicePdfARuleCheck.CheckFormField(AField: TLandrixEInvoicePdfObject; ADepth: Integer);
var
  Kids, K: TLandrixEInvoicePdfObject;
  I: Integer;
begin
  if not StageBBudget(ADepth) then
    Exit;
  if Known(AField, 'AA') then
    FailAt(par_6_4_1_2, AField, 'form field with /AA');
  CheckEvents(FDoc.DGet(AField, 'AA'), ['K', 'F', 'V', 'C']);
  Kids := FDoc.DGet(AField, 'Kids');
  if (Kids <> nil) and (Kids.Kind = pok_Arr) then
    for I := 0 to Kids.ArrCount - 1 do
    begin
      K := FDoc.Resolve(Kids.ArrItem(I));
      if (K <> nil) and K.IsDictLike and Known(K, 'T') then
        CheckFormField(K, ADepth + 1);
    end;
end;

{ 6.4.2-2, 6.5.2-1 and the actions of the catalog (a dictionary
  /OpenAction, the events WC, WS, DS, WP, DP) and of the outline.
  DE: 6.4.2-2, 6.5.2-1 und die Aktionen des Katalogs (ein Dictionary-
  /OpenAction, die Ereignisse WC, WS, DS, WP, DP) und der Gliederung. }
procedure TLandrixEInvoicePdfARuleCheck.CheckCatalogActions;
var
  Cat, NR, Open, Outlines: TLandrixEInvoicePdfObject;
begin
  Cat := FDoc.Catalog;
  { NeedsRendering false is allowed; true or another value is not }
  if Known(Cat, 'NeedsRendering') then
  begin
    NR := FDoc.DGet(Cat, 'NeedsRendering');
    if (NR = nil) or (NR.Kind <> pok_Bool) or NR.BoolVal then
      FailAt(par_6_4_2_2, Cat, 'catalog with NeedsRendering');
  end;
  if Known(Cat, 'AA') then
    FailAt(par_6_5_2_1, Cat, 'catalog with /AA');
  CheckEvents(FDoc.DGet(Cat, 'AA'), ['WC', 'WS', 'DS', 'WP', 'DP']);
  Open := FDoc.DGet(Cat, 'OpenAction');
  if (Open <> nil) and (Open.Kind = pok_Dict) then
    CheckAction(Open, 0);
  Outlines := FDoc.DGet(Cat, 'Outlines');
  if (Outlines <> nil) and Outlines.IsDictLike then
    CheckOutline(FDoc.DGet(Outlines, 'First'), 0);
end;

{ The outline items from AItem on: /A of each, down /First, along /Next.
  DE: Die Gliederungseintraege ab AItem: /A eines jeden, abwaerts ueber
  /First, weiter ueber /Next. }
procedure TLandrixEInvoicePdfARuleCheck.CheckOutline(AItem: TLandrixEInvoicePdfObject; ADepth: Integer);
var
  Item, A: TLandrixEInvoicePdfObject;
begin
  Item := AItem;
  while (Item <> nil) and Item.IsDictLike do
  begin
    if not StageBBudget(ADepth) then
      Exit;
    A := FDoc.DGet(Item, 'A');
    if (A <> nil) and (A.Kind = pok_Dict) then
      CheckAction(A, 0);
    CheckOutline(FDoc.DGet(Item, 'First'), ADepth + 1);
    Item := FDoc.DGet(Item, 'Next');
  end;
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
