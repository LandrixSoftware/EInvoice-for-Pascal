{
  EInvoice-for-Pascal

  Copyright (C) 2026 Landrix Software GmbH & Co. KG

  This file is dual-licensed under:
  - GNU GPL version 3 or later; or
  - the Landrix Software Commercial License.

  See LICENSE and COMMERCIAL-LICENSE.md.

  SPDX-License-Identifier: GPL-3.0-or-later OR LicenseRef-Landrix-Commercial
}

{ The PDF/A-3b rules of clauses 6.1 (file structure), 6.2 (graphics: content
  stream operators, graphics states, rendering intents, images, XObjects,
  blend modes, output intents, device colour spaces, ICC input profiles and
  DeviceN colourants, overprint, Separation consistency, inherited
  resources, page transparency, JPEG 2000 images and the font dictionaries;
  not yet the font programs),
  6.3 (annotations),
  6.4 (interactive forms), 6.5 (actions), 6.6 (XMP metadata: packets,
  properties, extension schemas, PDF/A identification), 6.8
  (embedded files), 6.9 (optional content), 6.10 (alternate presentations)
  and 6.11 (requirements) of ISO 19005-3, checked on the raw syntax facts of LandrixEInvoicePdfSyntax and the objects of the document.
  The rules carry the numbers of the veraPDF validation profile
  ("6.1.2-1": clause and test number; the finding ID is "PDFA-6.1.2-1"), so
  that results compare with veraPDF rule by rule. A registry states for every
  rule how far it is implemented: prc_Full rules are checked in their whole
  scope; prc_Partial rules miss part of it, so a failure is evidence but no
  failure proves nothing; prc_None rules are not checked. The checked population is
  the live object set of the object table (also unreferenced and compressed
  objects), the newest trailer and every section of the xref chain; older
  revisions of objects are not judged. Annotations, actions and form fields
  are found where veraPDF finds them: the /Annots of the pages, the actions
  of /A, of the named /AA events, of a dictionary /OpenAction, of outline
  items and their /Next chains, the AcroForm /Fields with kids that have /T.
  Content streams are read by LandrixEInvoicePdfContent: the operands their
  operators pass on count for 6.1.6 and 6.1.13 like the tokens of objects;
  the graphics rules of 6.2 judge the objects those streams use, as
  veraPDF builds them.

  DE: Die PDF/A-3b-Regeln der Abschnitte 6.1 (Dateistruktur), 6.2 (Grafik:
  Operatoren in Content-Streams, Grafikzustaende, Rendering-Intents, Bilder,
  XObjects, Blend-Modes, Output-Intents, Geraetefarbraeume,
  ICC-Eingangsprofile und DeviceN-Farbmittel, Ueberdrucken,
  Separation-Konsistenz, geerbte Ressourcen, Transparenz der Seiten,
  JPEG-2000-Bilder und die Schrift-Dictionarys; noch nicht die
  Fontprogramme),
  6.3 (Annotationen), 6.4 (interaktive Formulare), 6.5 (Aktionen), 6.6
  (XMP-Metadaten: Pakete, Eigenschaften, Erweiterungsschemas,
  PDF/A-Kennung), 6.8 (eingebettete Dateien), 6.9 (optionale Inhalte), 6.10
  (alternative Darstellungen) und 6.11 (Anforderungen) der ISO 19005-3, geprueft auf den
  rohen Syntax-Tatsachen von
  LandrixEInvoicePdfSyntax und den Objekten des Dokuments. Die Regeln tragen die Nummern des
  veraPDF-Pruefprofils ("6.1.2-1": Abschnitt und Testnummer; die Befund-ID ist
  "PDFA-6.1.2-1"), damit sich Ergebnisse Regel fuer Regel mit veraPDF
  vergleichen lassen. Ein Register sagt fuer jede Regel, wie weit sie umgesetzt
  ist: prc_Full-Regeln werden in ihrem ganzen Umfang geprueft; prc_Partial-
  Regeln fehlt ein Teil davon, ein Verstoss ist also ein Beleg, kein
  Verstoss beweist nichts; prc_None-Regeln werden nicht geprueft. Geprueft wird die
  lebende Objektmenge der Objekttabelle (auch Objekte ohne Verweis und
  komprimierte), der neueste Trailer und jeder Abschnitt der xref-Kette;
  aeltere Fassungen von Objekten werden nicht beurteilt. Annotationen,
  Aktionen und Formularfelder werden dort gefunden, wo veraPDF sie findet:
  die /Annots der Seiten, die Aktionen von /A, der benannten /AA-Ereignisse,
  eines Dictionary-/OpenAction, von Gliederungseintraegen und ihren
  /Next-Ketten, die AcroForm-/Fields mit Kindern, die /T haben.
  Content-Streams liest LandrixEInvoicePdfContent: die Operanden, die ihre
  Operatoren weitergeben, zaehlen fuer 6.1.6 und 6.1.13 wie die Token von
  Objekten; die Grafikregeln aus 6.2 beurteilen die Objekte, die diese
  Streams benutzen, so wie veraPDF sie baut. }

{ API: internal. May change in any release; use the facade LandrixEInvoice
  or the stable units instead.
  DE: API: intern. Kann sich in jeder Version aendern; stattdessen die
  Fassade LandrixEInvoice oder die stabilen Units verwenden. }

unit LandrixEInvoicePdfARules;

{$I LandrixEInvoice.inc}

interface

uses
  LandrixEInvoiceTypes,
  LandrixEInvoicePdfObjects,
  LandrixEInvoicePdfSyntax,
  LandrixEInvoicePdfXmp;

type
  { The rules of clauses 6.1, 6.2 (in part, see the unit header), 6.3 to 6.6
    and 6.8 to 6.11 in the veraPDF profile PDF/A-3B, named after clause and
    test number.
    DE: Die Regeln der Abschnitte 6.1, 6.2 (teilweise, siehe Kopf der
    Unit), 6.3
    bis 6.6 und 6.8 bis 6.11 im veraPDF-Profil PDF/A-3B,
    benannt nach Abschnitt und Testnummer. }
  TLandrixEInvoicePdfARule = (
    par_6_1_2_1, par_6_1_2_2, par_6_1_3_1, par_6_1_3_2, par_6_1_3_3, par_6_1_4_2, par_6_1_6_1, par_6_1_6_2,
    par_6_1_7_1_1, par_6_1_7_1_2, par_6_1_7_1_3, par_6_1_7_2_1, par_6_1_8_1, par_6_1_9_1, par_6_1_10_1,
    par_6_1_12_1, par_6_1_12_2, par_6_1_13_1, par_6_1_13_2, par_6_1_13_3, par_6_1_13_4, par_6_1_13_5,
    par_6_1_13_7, par_6_1_13_8, par_6_1_13_9, par_6_1_13_10, par_6_1_13_11,
    par_6_2_2_1, par_6_2_2_2, par_6_2_3_1, par_6_2_3_2, par_6_2_3_3, par_6_2_4_2_1, par_6_2_4_2_2, par_6_2_4_3_2, par_6_2_4_3_3,
    par_6_2_4_3_4, par_6_2_4_4_1, par_6_2_4_4_2,
    par_6_2_5_1, par_6_2_5_2, par_6_2_5_3, par_6_2_5_4, par_6_2_5_5, par_6_2_5_6, par_6_2_6_1,
    par_6_2_8_1, par_6_2_8_2, par_6_2_8_3, par_6_2_8_4, par_6_2_8_5, par_6_2_8_3_1, par_6_2_8_3_2, par_6_2_8_3_3,
    par_6_2_8_3_4, par_6_2_8_3_5, par_6_2_9_1, par_6_2_9_2, par_6_2_9_3,
    par_6_2_10_1, par_6_2_10_2,
    par_6_2_11_2_1, par_6_2_11_2_2, par_6_2_11_2_3, par_6_2_11_2_4, par_6_2_11_2_5, par_6_2_11_2_6, par_6_2_11_2_7,
    par_6_2_11_3_1_1, par_6_2_11_3_2_1, par_6_2_11_3_3_1, par_6_2_11_3_3_2, par_6_2_11_3_3_3, par_6_2_11_4_1_1,
    par_6_2_11_4_1_2, par_6_2_11_4_2_1, par_6_2_11_4_2_2, par_6_2_11_5_1, par_6_2_11_6_1, par_6_2_11_6_2,
    par_6_2_11_6_3, par_6_2_11_6_4, par_6_2_11_8_1,
    par_6_3_1_1, par_6_3_2_1, par_6_3_2_2, par_6_3_3_1, par_6_3_3_2, par_6_3_3_3, par_6_3_3_4,
    par_6_4_1_1, par_6_4_1_2, par_6_4_1_3, par_6_4_2_1, par_6_4_2_2, par_6_4_3_1, par_6_4_3_2, par_6_4_3_3,
    par_6_5_1_1, par_6_5_1_2, par_6_5_2_1, par_6_5_2_2,
    par_6_6_2_1_1, par_6_6_2_1_2, par_6_6_2_1_3, par_6_6_2_1_4, par_6_6_2_1_5,
    par_6_6_2_3_1_1, par_6_6_2_3_1_2, par_6_6_2_3_2_1, par_6_6_2_3_3_1, par_6_6_2_3_3_2, par_6_6_2_3_3_3, par_6_6_2_3_3_4, par_6_6_2_3_3_5,
    par_6_6_2_3_3_6, par_6_6_2_3_3_7, par_6_6_2_3_3_8, par_6_6_2_3_3_9, par_6_6_2_3_3_10, par_6_6_2_3_3_11,
    par_6_6_2_3_3_12, par_6_6_2_3_3_13, par_6_6_2_3_3_14, par_6_6_2_3_3_15, par_6_6_2_3_3_16, par_6_6_2_3_3_17,
    par_6_6_2_3_3_18,
    par_6_6_4_1, par_6_6_4_2, par_6_6_4_3, par_6_6_4_4, par_6_6_4_5, par_6_6_4_6, par_6_6_4_7,
    par_6_8_1, par_6_8_2, par_6_8_3, par_6_8_4, par_6_9_1, par_6_9_2, par_6_9_3, par_6_9_4,
    par_6_10_1, par_6_10_2, par_6_11_1);

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
    { rules whose scope could not be walked to the end (a limit, no
      catalog, objects without envelope) }
    FIncomplete: array[TLandrixEInvoicePdfARule] of Boolean;
    FClaimedPart: Int64;
    { pages and form fields walked for clause 6.1; annotations, actions,
      fields and outline items walked for stage B }
    FNodes: Integer;
    FNodesB: Integer;
    { the walk of all objects for 6.8: nodes visited; object numbers named in
      an /AF array or in an array of a /Properties dictionary; the file
      specifications found with their object number (-1 if direct) }
    FNodesC: Integer;
    FWalkBroken: Boolean;
    FAssoc: array of Boolean;
    { the colour space of the PDF/A output profile as veraPDF's gOutputCS
      (empty: none); False when it is not certain }
    FOutputCS: AnsiString;
    FOutputCSKnown: Boolean;
    { veraPDF may stop with an exception on the document: no rule decided }
    FVeraThrows: Boolean;
    { associations made in the page tree (doubtful where veraPDF may see
      other pages) }
    FAssocPage: array of Boolean;
    FAFInPages: Boolean;
    { the pages veraPDF sees may differ (page associations doubtful) }
    FAFPagesUnsure: Boolean;
    FSpecSeen: array of Boolean;
    FSpecs: array of TLandrixEInvoicePdfObject;
    FSpecNums: array of Integer;
    FSpecCount: Integer;
    { object numbers /AF /Name BDC in content streams associates certainly or
      possibly (6.8-4) }
    FContentSure: array of Boolean;
    FContentMaybe: array of Boolean;
    { the /AF walk (6.8-4): objects visited, pages found, pages unsure }
    FAFSeen: array of Byte;
    FAFUnsure: Boolean;
    FNodesOc: Integer;
    { the metadata streams other dictionaries name (6.6.2.1), by object
      number }
    FMetaSeen: array of Boolean;
    FMetaNums: array of Integer;
    FMetaCount: Integer;
    { the XMP properties judged for 6.6.2.3.1 (namespace, prefix and name;
      veraPDF judges one of these once) with their answers }
    FPropIds: array of TLandrixEInvoiceString;
    FPropDefined: array of TLandrixEInvoiceXmpTruth;
    FPropValid: array of TLandrixEInvoiceXmpTruth;
    FPropNums: array of Integer;
    FPropNames: array of string;
    FPropCount: Integer;
    { occurrences of XMP properties judged (a work limit) }
    FPropWork: Integer;
    { the pages veraPDF sees may differ from the walk of CheckPages: its
      failures leave the rules undecided }
    FPagesUnsure: Boolean;
    FNodesPages: Integer;
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
    function CountPages(ANode: TLandrixEInvoicePdfObject; ADepth: Integer): Integer;
    procedure CheckPages(ANode, AMediaBox, ACropBox, AMediaOwner, ACropOwner: TLandrixEInvoicePdfObject;
      ADepth: Integer);
    procedure CheckBox(ABox: TLandrixEInvoicePdfObject; const AName: string; AOwner: TLandrixEInvoicePdfObject);
    procedure MarkStageB;
    procedure MarkPageRules;
    function Where(AObj: TLandrixEInvoicePdfObject): string;
    procedure FailAt(ARule: TLandrixEInvoicePdfARule; AObj: TLandrixEInvoicePdfObject; const ADetail: string);
    function Known(ADict: TLandrixEInvoicePdfObject; const AKey: AnsiString): Boolean;
    function FieldType(AAnnot: TLandrixEInvoicePdfObject; out AType: AnsiString): Boolean;
    procedure CheckAnnot(AAnnot: TLandrixEInvoicePdfObject);
    procedure CheckEvents(AAA: TLandrixEInvoicePdfObject; const AEvents: array of AnsiString);
    function ActionRef(ARaw: TLandrixEInvoicePdfObject): TLandrixEInvoicePdfObject;
    function ActionGet(AObj: TLandrixEInvoicePdfObject; const AKey: AnsiString): TLandrixEInvoicePdfObject;
    function StageBBudget(ADepth: Integer): Boolean;
    procedure CheckAction(AAction: TLandrixEInvoicePdfObject; ADepth: Integer);
    procedure CheckForm;
    procedure CheckFormField(AField: TLandrixEInvoicePdfObject; ADepth: Integer);
    procedure CheckCatalogActions;
    procedure CheckOutline(AItem: TLandrixEInvoicePdfObject; ADepth: Integer);
    procedure MarkLateA;
    procedure BreakWalk;
    procedure AddAssoc(AArr: TLandrixEInvoicePdfObject);
    procedure AddSpec(ASpec: TLandrixEInvoicePdfObject; ANum: Integer);
    procedure WalkValue(AObj: TLandrixEInvoicePdfObject; ANum, ADepth: Integer);
    procedure WalkEmbeddedFiles(ANode: TLandrixEInvoicePdfObject; ADepth: Integer);
    procedure SpecFail(ARule: TLandrixEInvoicePdfARule; AIndex: Integer; const ADetail: string);
    procedure CheckContent;
    procedure RegisterAF(AObj: TLandrixEInvoicePdfObject);
    function AFBudget(ADepth: Integer): Boolean;
    function AFRef(ARaw: TLandrixEInvoicePdfObject): TLandrixEInvoicePdfObject;
    function GenRef(ARaw: TLandrixEInvoicePdfObject; var AUnsure: Boolean): TLandrixEInvoicePdfObject;
    function AFGet(AObj: TLandrixEInvoicePdfObject; const AKey: AnsiString): TLandrixEInvoicePdfObject;
    function AFFirstVisit(ARaw: TLandrixEInvoicePdfObject; AKind: Byte): Boolean;
    function AFPages(ANode, AInherited: TLandrixEInvoicePdfObject; ADepth: Integer): Integer;
    procedure AFPage(APage, ARes: TLandrixEInvoicePdfObject);
    procedure AFResources(ARes: TLandrixEInvoicePdfObject; ADepth: Integer);
    procedure AFXObject(ARaw: TLandrixEInvoicePdfObject; ADepth: Integer);
    procedure AFAppearance(AStream: TLandrixEInvoicePdfObject; ADepth: Integer);
    procedure AFFont(ARaw: TLandrixEInvoicePdfObject; ADepth: Integer);
    procedure AFGState(ARaw: TLandrixEInvoicePdfObject; ADepth: Integer);
    procedure AFPattern(ARaw: TLandrixEInvoicePdfObject; ADepth: Integer);
    procedure AFStruct(AKids: TLandrixEInvoicePdfObject; ADepth: Integer);
    procedure CollectAF;
    procedure CheckFileSpecs;
    procedure CheckOptionalContent;
    procedure CheckCatalogLate;
    procedure CheckOutputIntents;
    procedure AddMetadata(ADict: TLandrixEInvoicePdfObject);
    procedure MarkMetadata;
    procedure JudgePacket(APacket: TLandrixEInvoiceXmpPacket; ANum: Integer);
    procedure JudgeIdentification(APacket: TLandrixEInvoiceXmpPacket; ANum: Integer);
    procedure MarkExtension;
    procedure JudgeProperties(APacket: TLandrixEInvoiceXmpPacket; ANum: Integer;
      ATypes, AMainTypes: TLandrixEInvoiceXmpSchemaTypes);
    procedure ReportProperties;
    procedure JudgeExtension(APacket: TLandrixEInvoiceXmpPacket; ANum: Integer; ATypes: TLandrixEInvoiceXmpSchemaTypes);
    procedure CheckMetadata;
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
    { pdfaid:part of the catalog's XMP after Check, as an integer; 0 when
      it is absent or no integer.
      DE: pdfaid:part des XMP des Katalogs nach Check, als ganze Zahl; 0,
      wenn es fehlt oder keine ganze Zahl ist. }
    property ClaimedPart: Int64 read FClaimedPart;
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

{ A value of pdfaid:part as an integer, read as veraPDF reads it (an
  optional sign and ASCII digits within 32 bits, '03' is 3); 0 when it is
  no integer.
  DE: Ein Wert von pdfaid:part als ganze Zahl, gelesen wie veraPDF ihn
  liest (ein optionales Vorzeichen und ASCII-Ziffern innerhalb von 32 Bit,
  '03' ist 3); 0, wenn er keine ganze Zahl ist. }
function LandrixEInvoicePdfAPartNumber(const AText: TLandrixEInvoiceString): Int64;

implementation

uses
  SysUtils,
  Classes,
  Contnrs,
  LandrixXmlBase,
  LandrixEInvoicePdfContent;

type
  TSupersededFlags = array of Boolean;

type
  TOcNames = array of TLandrixEInvoiceString;
  TOcFlags = array of Boolean;

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
    (Number: '6.1.6-1'; Coverage: prc_Full; Text: 'A hexadecimal string has an even number of characters'),
    (Number: '6.1.6-2'; Coverage: prc_Full; Text: 'A hexadecimal string holds only hexadecimal digits'),
    (Number: '6.1.7.1-1'; Coverage: prc_Full; Text: 'The /Length of a stream matches its data'),
    (Number: '6.1.7.1-2'; Coverage: prc_Full;
      Text: 'stream is followed by CR LF or LF, endstream is preceded by an end of line'),
    (Number: '6.1.7.1-3'; Coverage: prc_Full; Text: 'A stream dictionary has no /F, /FFilter or /FDecodeParms'),
    (Number: '6.1.7.2-1'; Coverage: prc_Full;
      Text: 'Only standard stream filters except LZWDecode; Crypt only with the Identity filter'),
    (Number: '6.1.8-1'; Coverage: prc_None; Text: 'Font, colourant and structure type names are valid UTF-8'),
    (Number: '6.1.9-1'; Coverage: prc_Full;
      Text: 'One white-space character between object number, generation and obj; end of line around obj and endobj'),
    (Number: '6.1.10-1'; Coverage: prc_Full; Text: 'Inline images use only permitted filters'),
    (Number: '6.1.12-1'; Coverage: prc_Full; Text: 'A permissions dictionary holds only UR3 and DocMDP'),
    (Number: '6.1.12-2'; Coverage: prc_Full;
      Text: 'With DocMDP, signature references have no DigestLocation, DigestMethod or DigestValue'),
    (Number: '6.1.13-1'; Coverage: prc_Full; Text: 'Integers lie between -2147483648 and 2147483647'),
    (Number: '6.1.13-2'; Coverage: prc_Full; Text: 'Real numbers lie within +/-3.403E38'),
    (Number: '6.1.13-3'; Coverage: prc_Full; Text: 'Strings are at most 32767 characters long'),
    (Number: '6.1.13-4'; Coverage: prc_Full; Text: 'Names are at most 127 bytes long'),
    (Number: '6.1.13-5'; Coverage: prc_Full; Text: 'Real numbers are zero or at least 1.175E-38 away from it'),
    (Number: '6.1.13-7'; Coverage: prc_Full; Text: 'At most 8388607 indirect objects'),
    (Number: '6.1.13-8'; Coverage: prc_Full; Text: 'q/Q pairs are nested at most 28 levels deep'),
    (Number: '6.1.13-9'; Coverage: prc_Full; Text: 'A DeviceN colour space has at most 32 colourants'),
    (Number: '6.1.13-10'; Coverage: prc_None; Text: 'CID values are at most 65535'),
    (Number: '6.1.13-11'; Coverage: prc_Full; Text: 'Page boundaries are between 3 and 14400 units in each direction'),
    (Number: '6.2.2-1'; Coverage: prc_Full; Text: 'Content streams use only operators defined in ISO 32000-1'),
    (Number: '6.2.2-2'; Coverage: prc_Full;
      Text: 'A content stream takes its named resources from its own Resources dictionary'),
    (Number: '6.2.3-1'; Coverage: prc_Full;
      Text: 'An output intent profile is a printer or monitor profile for RGB, CMYK or Gray below ICC version 5'),
    (Number: '6.2.3-2'; Coverage: prc_Full;
      Text: 'All output intents with an indirect /DestOutputProfile refer to the same object'),
    (Number: '6.2.3-3'; Coverage: prc_Full; Text: 'A PDF/X output intent has no /DestOutputProfileRef'),
    (Number: '6.2.4.2-1'; Coverage: prc_Full;
      Text: 'An ICC input profile is an input, display, output or colour space profile for RGB, CMYK, Gray or Lab ' +
      'below ICC version 5'),
    (Number: '6.2.4.2-2'; Coverage: prc_Full;
      Text: 'An ICCBased CMYK colour space is not painted with overprint on and an overprint mode other than 0'),
    (Number: '6.2.4.3-2'; Coverage: prc_Full; Text: 'DeviceRGB is used only with an RGB output intent'),
    (Number: '6.2.4.3-3'; Coverage: prc_Full; Text: 'DeviceCMYK is used only with a CMYK output intent'),
    (Number: '6.2.4.3-4'; Coverage: prc_Full; Text: 'DeviceGray is used only with an output intent'),
    (Number: '6.2.4.4-1'; Coverage: prc_Full;
      Text: 'Every colourant of a DeviceN colour space is in /Colorants or a process component'),
    (Number: '6.2.4.4-2'; Coverage: prc_Full;
      Text: 'Separation colour spaces of one colourant name have the same alternate space and tint transform'),
    (Number: '6.2.5-1'; Coverage: prc_Full; Text: 'An ExtGState dictionary has no /TR'),
    (Number: '6.2.5-2'; Coverage: prc_Full; Text: 'An ExtGState dictionary has /TR2 only with the value Default'),
    (Number: '6.2.5-3'; Coverage: prc_Full; Text: 'An ExtGState dictionary has no /HTP'),
    (Number: '6.2.5-4'; Coverage: prc_Full; Text: 'A halftone has HalftoneType 1 or 5'),
    (Number: '6.2.5-5'; Coverage: prc_Full; Text: 'A halftone has no /HalftoneName'),
    (Number: '6.2.5-6'; Coverage: prc_Full;
      Text: 'A halftone has a /TransferFunction only for colorants other than the primary ones'),
    (Number: '6.2.6-1'; Coverage: prc_Full;
      Text: 'A rendering intent is RelativeColorimetric, AbsoluteColorimetric, Perceptual or Saturation'),
    (Number: '6.2.8-1'; Coverage: prc_Full; Text: 'An image dictionary has no /Alternates'),
    (Number: '6.2.8-2'; Coverage: prc_Full; Text: 'An image dictionary has no /OPI'),
    (Number: '6.2.8-3'; Coverage: prc_Full; Text: 'An image has /Interpolate (inline: /I) false or not at all'),
    (Number: '6.2.8-4'; Coverage: prc_Full; Text: 'The BitsPerComponent of an image is 1, 2, 4, 8 or 16'),
    (Number: '6.2.8-5'; Coverage: prc_Full; Text: 'The BitsPerComponent of an image mask is 1'),
    (Number: '6.2.8.3-1'; Coverage: prc_Full; Text: 'JPEG 2000 data have 1, 3 or 4 colour channels'),
    (Number: '6.2.8.3-2'; Coverage: prc_Full;
      Text: 'Without /ColorSpace, JPEG 2000 data have one colour specification or exactly one with APPROX 1'),
    (Number: '6.2.8.3-3'; Coverage: prc_Full;
      Text: 'Without /ColorSpace, the colour specification of JPEG 2000 data has METH 1, 2 or 3'),
    (Number: '6.2.8.3-4'; Coverage: prc_Full;
      Text: 'Without /ColorSpace, JPEG 2000 data do not use the enumerated colour space 19 (CIEJab)'),
    (Number: '6.2.8.3-5'; Coverage: prc_Full;
      Text: 'JPEG 2000 data have no bpcc box and a bit depth from 1 to 38'),
    (Number: '6.2.9-1'; Coverage: prc_Full; Text: 'A form XObject has no /OPI, no /PS and no /Subtype2 /PS'),
    (Number: '6.2.9-2'; Coverage: prc_Full; Text: 'No reference XObjects (/Ref in a form XObject)'),
    (Number: '6.2.9-3'; Coverage: prc_Full; Text: 'No PostScript XObjects'),
    (Number: '6.2.10-1'; Coverage: prc_Full; Text: 'Only the blend modes of ISO 32000-1 in /BM'),
    (Number: '6.2.10-2'; Coverage: prc_Full;
      Text: 'Without a PDF/A output intent, a page with transparency has a /Group with /CS'),
    (Number: '6.2.11.2-1'; Coverage: prc_Full; Text: 'A font has /Type /Font'),
    (Number: '6.2.11.2-2'; Coverage: prc_Full; Text: 'A font has a /Subtype of ISO 32000-1'),
    (Number: '6.2.11.2-3'; Coverage: prc_Full; Text: 'A font other than Type 3 has a /BaseFont name'),
    (Number: '6.2.11.2-4'; Coverage: prc_Full; Text: 'A simple font other than the standard 14 has /FirstChar'),
    (Number: '6.2.11.2-5'; Coverage: prc_Full; Text: 'A simple font other than the standard 14 has /LastChar'),
    (Number: '6.2.11.2-6'; Coverage: prc_Full;
      Text: 'A simple font other than the standard 14 has /Widths with LastChar - FirstChar + 1 entries'),
    (Number: '6.2.11.2-7'; Coverage: prc_Full;
      Text: 'An embedded font program has no /Subtype other than Type1C, CIDFontType0C and OpenType'),
    (Number: '6.2.11.3.1-1'; Coverage: prc_Full;
      Text: 'The CMap of a Type 0 font is an Identity CMap or matches the CIDSystemInfo of its CIDFont'),
    (Number: '6.2.11.3.2-1'; Coverage: prc_Full; Text: 'An embedded CIDFontType2 font has /CIDToGIDMap'),
    (Number: '6.2.11.3.3-1'; Coverage: prc_Full; Text: 'The CMap of a Type 0 font is predefined or embedded'),
    (Number: '6.2.11.3.3-2'; Coverage: prc_None; Text: 'An embedded CMap has the /WMode of its dictionary'),
    (Number: '6.2.11.3.3-3'; Coverage: prc_Full; Text: 'A CMap named by /UseCMap is a predefined one'),
    (Number: '6.2.11.4.1-1'; Coverage: prc_Full;
      Text: 'A font other than Type 3 and Type 0 used for visible text is embedded'),
    (Number: '6.2.11.4.1-2'; Coverage: prc_None; Text: 'Every glyph shown is present in the font program'),
    (Number: '6.2.11.4.2-1'; Coverage: prc_None; Text: 'The /CharSet of a Type 1 subset lists all its glyphs'),
    (Number: '6.2.11.4.2-2'; Coverage: prc_None; Text: 'The /CIDSet of a CIDFont subset lists all its glyphs'),
    (Number: '6.2.11.5-1'; Coverage: prc_None;
      Text: 'The widths of the font dictionary and of the font program agree'),
    (Number: '6.2.11.6-1'; Coverage: prc_Full; Text: 'A non-symbolic TrueType font program has a cmap'),
    (Number: '6.2.11.6-2'; Coverage: prc_Full;
      Text: 'A non-symbolic TrueType font uses MacRomanEncoding or WinAnsiEncoding'),
    (Number: '6.2.11.6-3'; Coverage: prc_Full; Text: 'A symbolic TrueType font has no /Encoding'),
    (Number: '6.2.11.6-4'; Coverage: prc_Full;
      Text: 'A symbolic TrueType font program has one cmap or a (3,0) cmap'),
    (Number: '6.2.11.8-1'; Coverage: prc_None; Text: 'No glyph shown is .notdef'),
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
    (Number: '6.5.2-2'; Coverage: prc_Full; Text: 'A page has no additional actions /AA'),
    (Number: '6.6.2.1-1'; Coverage: prc_Full;
      Text: 'The catalog has /Metadata, a stream with /Type /Metadata and /Subtype /XML'),
    (Number: '6.6.2.1-2'; Coverage: prc_Full; Text: 'The xpacket header of an XMP packet has no bytes attribute'),
    (Number: '6.6.2.1-3'; Coverage: prc_Full; Text: 'The xpacket header of an XMP packet has no encoding attribute'),
    (Number: '6.6.2.1-4'; Coverage: prc_Partial; Text: 'An XMP packet is well-formed XML and RDF'),
    (Number: '6.6.2.1-5'; Coverage: prc_Full; Text: 'An XMP packet is encoded as UTF-8'),
    (Number: '6.6.2.3.1-1'; Coverage: prc_Full;
      Text: 'Every XMP property is predefined or defined by an extension schema of its packet or the main packet'),
    (Number: '6.6.2.3.1-2'; Coverage: prc_Full; Text: 'Every XMP property has a value of its defined value type'),
    (Number: '6.6.2.3.2-1'; Coverage: prc_Full;
      Text: 'Extension schema structures hold only the fields of their PDF/A value type'),
    (Number: '6.6.2.3.3-1'; Coverage: prc_Full;
      Text: 'pdfaExtension:schemas is a Bag with the prefix pdfaExtension'),
    (Number: '6.6.2.3.3-2'; Coverage: prc_Full;
      Text: 'pdfaSchema:schema is present, a text with the prefix pdfaSchema'),
    (Number: '6.6.2.3.3-3'; Coverage: prc_Full;
      Text: 'pdfaSchema:namespaceURI is present, a URI with the prefix pdfaSchema'),
    (Number: '6.6.2.3.3-4'; Coverage: prc_Full;
      Text: 'pdfaSchema:prefix is present, a text with the prefix pdfaSchema'),
    (Number: '6.6.2.3.3-5'; Coverage: prc_Full;
      Text: 'pdfaSchema:property is absent or an ordered array (Seq or Alt), unprefixed or with the prefix pdfaSchema'),
    (Number: '6.6.2.3.3-6'; Coverage: prc_Full;
      Text: 'pdfaSchema:valueType is absent or an ordered array (Seq or Alt), unprefixed or with the prefix pdfaSchema'),
    (Number: '6.6.2.3.3-7'; Coverage: prc_Full;
      Text: 'pdfaProperty:name is present, a text with the prefix pdfaProperty'),
    (Number: '6.6.2.3.3-8'; Coverage: prc_Full;
      Text: 'pdfaProperty:valueType is present, a known type with the prefix pdfaProperty'),
    (Number: '6.6.2.3.3-9'; Coverage: prc_Full;
      Text: 'pdfaProperty:category is external or internal with the prefix pdfaProperty'),
    (Number: '6.6.2.3.3-10'; Coverage: prc_Full;
      Text: 'pdfaProperty:description is present, a text with the prefix pdfaProperty'),
    (Number: '6.6.2.3.3-11'; Coverage: prc_Full; Text: 'pdfaType:type is present, a text with the prefix pdfaType'),
    (Number: '6.6.2.3.3-12'; Coverage: prc_Full;
      Text: 'pdfaType:namespaceURI is present, a URI with the prefix pdfaType'),
    (Number: '6.6.2.3.3-13'; Coverage: prc_Full; Text: 'pdfaType:prefix is present, a text with the prefix pdfaType'),
    (Number: '6.6.2.3.3-14'; Coverage: prc_Full;
      Text: 'pdfaType:description is present, a text with the prefix pdfaType'),
    (Number: '6.6.2.3.3-15'; Coverage: prc_Full;
      Text: 'pdfaType:field is absent or an ordered array (Seq or Alt), unprefixed or with the prefix pdfaType'),
    (Number: '6.6.2.3.3-16'; Coverage: prc_Full; Text: 'pdfaField:name is present, a text with the prefix pdfaField'),
    (Number: '6.6.2.3.3-17'; Coverage: prc_Full;
      Text: 'pdfaField:valueType is present, a known type with the prefix pdfaField'),
    (Number: '6.6.2.3.3-18'; Coverage: prc_Full;
      Text: 'pdfaField:description is present, a text with the prefix pdfaField'),
    (Number: '6.6.4-1'; Coverage: prc_Full; Text: 'The metadata have a PDF/A identification (pdfaid)'),
    (Number: '6.6.4-2'; Coverage: prc_Full; Text: 'pdfaid:part is 3'),
    (Number: '6.6.4-3'; Coverage: prc_Full; Text: 'pdfaid:conformance is A, B or U'),
    (Number: '6.6.4-4'; Coverage: prc_Full; Text: 'pdfaid:part has the prefix pdfaid'),
    (Number: '6.6.4-5'; Coverage: prc_Full; Text: 'pdfaid:conformance has the prefix pdfaid'),
    (Number: '6.6.4-6'; Coverage: prc_Full; Text: 'pdfaid:amd has the prefix pdfaid'),
    (Number: '6.6.4-7'; Coverage: prc_Full; Text: 'pdfaid:corr has the prefix pdfaid'),
    (Number: '6.8-1'; Coverage: prc_Full; Text: 'An embedded file has a MIME type /Subtype of the form type/subtype'),
    (Number: '6.8-2'; Coverage: prc_Full;
      Text: 'A file specification of an embedded file has /F and /UF'),
    (Number: '6.8-3'; Coverage: prc_Full; Text: 'A file specification has /AFRelationship'),
    (Number: '6.8-4'; Coverage: prc_Full;
      Text: 'A file specification is an associated file (in an /AF array)'),
    (Number: '6.9-1'; Coverage: prc_Full; Text: 'An optional content configuration has a non-empty /Name'),
    (Number: '6.9-2'; Coverage: prc_Full; Text: 'The names of the optional content configurations are unique'),
    (Number: '6.9-3'; Coverage: prc_Full; Text: 'The /Order of a configuration lists every optional content group'),
    (Number: '6.9-4'; Coverage: prc_Full; Text: 'An optional content configuration has no /AS'),
    (Number: '6.10-1'; Coverage: prc_Full; Text: 'The name dictionary has no /AlternatePresentations'),
    (Number: '6.10-2'; Coverage: prc_Full; Text: 'A page has no /PresSteps'),
    (Number: '6.11-1'; Coverage: prc_Full; Text: 'The catalog has no /Requirements'));

  { most pages and AcroForm fields walked together }
  MaxNodes = 200000;
  MaxTreeDepth = 64;
  { longest /Parent chain of a form field followed }
  MaxParentChain = 1024;
  { most keys of an appearance dictionary (and of a state dictionary) read }
  MaxAppearanceKeys = 64;
  { most dictionaries and arrays visited in the walk of all objects }
  MaxWalkNodes = 4000000;
  MaxWalkDepth = 128;
  { most optional content groups and configurations compared by name }
  MaxOcNames = 4096;
  { most further metadata packets read (6.6.2.1) }
  MaxMetaPackets = 1000;
  { most work (entries visited, names compared) for /OCGs and the /Order
    arrays }
  MaxOcWork = 20000000;

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

{ Text of an XMP value as printable ASCII, '?' for anything else. }
function WideAscii(const S: TLandrixEInvoiceString): string;
var
  I: Integer;
begin
  Result := '';
  SetLength(Result, Length(S));
  for I := 1 to Length(S) do
    if (Word(S[I]) >= 32) and (Word(S[I]) < 127) then
      Result[I] := Chr(Word(S[I]))
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

{ Object ANum, nil if it cannot be read. }
function ObjectOrNil(ADoc: TLandrixEInvoicePdfDocument; ANum: Integer): TLandrixEInvoicePdfObject;
begin
  try
    Result := ADoc.GetObject(ANum);
  except
    on EOutOfMemory do
      raise;
    on Exception do
      Result := nil;
  end;
end;

{ 6.8-1: a MIME type as the profile's pattern ^[-\w+\.]+\/[-\w+\.]+$ (a
  JavaScript pattern, \w is ASCII): letters, digits, '_', '-', '+', '.' on
  both sides of one '/'.
  DE: 6.8-1: ein MIME-Typ wie das Muster des Profils ^[-\w+\.]+\/[-\w+\.]+$
  (ein JavaScript-Muster, \w ist ASCII): Buchstaben, Ziffern, '_', '-', '+',
  '.' auf beiden Seiten genau eines '/'. }
function IsMimeType(const S: AnsiString): Boolean;
var
  I, Slash: Integer;
  C: AnsiChar;
begin
  Result := False;
  Slash := 0;
  for I := 1 to Length(S) do
  begin
    C := S[I];
    if C = '/' then
    begin
      if Slash > 0 then
        Exit;
      Slash := I;
    end
    else if not (((C >= 'A') and (C <= 'Z')) or ((C >= 'a') and (C <= 'z')) or ((C >= '0') and (C <= '9')) or
      (C = '_') or (C = '-') or (C = '+') or (C = '.')) then
      Exit;
  end;
  Result := (Slash > 1) and (Slash < Length(S));
end;

{ A text string of an optional content name as veraPDF decodes it: UTF-16BE
  after FE FF (malformed surrogates and an odd last byte are replacement
  characters), UTF-8 after EF BB BF, else PDFDocEncoding; zero characters stay. False for malformed
  UTF-8, whose exact text is not known (AText is then not empty).
  DE: Ein Textstring eines Namens optionaler Inhalte, wie veraPDF ihn
  dekodiert: UTF-16BE nach FE FF (fehlerhafte Surrogate und ein ungerades
  letztes Byte sind Ersatzzeichen), UTF-8 nach EF BB BF, sonst PDFDocEncoding; Nullzeichen
  bleiben. False bei fehlerhaftem UTF-8, dessen genauer Text unbekannt ist
  (AText ist dann nicht leer). }
function OcText(const ABytes: TLandrixEInvoicePdfBytes; out AText: TLandrixEInvoiceString): Boolean;
var
  N, I, Count: Integer;
  W, W2: Word;
  Utf8: TLandrixXmlUtf8;
begin
  Result := True;
  AText := '';
  N := Integer(Length(ABytes));
  if (N >= 2) and (ABytes[0] = $FE) and (ABytes[1] = $FF) then
  begin
    { as veraPDF decodes UTF-16BE: a high surrogate takes the next unit with
      it (both one replacement character if that is no low surrogate); a
      lone low surrogate and the bytes left at the end are one replacement
      character each }
    SetLength(AText, (N - 1) div 2);
    Count := 0;
    I := 2;
    while I < N do
    begin
      Inc(Count);
      if N - I < 2 then
      begin
        AText[Count] := WideChar($FFFD);
        Break;
      end;
      W := Word((ABytes[I] shl 8) or ABytes[I + 1]);
      if (W >= $D800) and (W <= $DBFF) then
      begin
        if N - I < 4 then
        begin
          AText[Count] := WideChar($FFFD);
          Break;
        end;
        W2 := Word((ABytes[I + 2] shl 8) or ABytes[I + 3]);
        if (W2 >= $DC00) and (W2 <= $DFFF) then
        begin
          AText[Count] := WideChar(W);
          Inc(Count);
          AText[Count] := WideChar(W2);
        end
        else
          AText[Count] := WideChar($FFFD);
        Inc(I, 4);
      end
      else
      begin
        if (W >= $DC00) and (W <= $DFFF) then
          AText[Count] := WideChar($FFFD)
        else
          AText[Count] := WideChar(W);
        Inc(I, 2);
      end;
    end;
    SetLength(AText, Count);
    Exit;
  end;
  if (N >= 3) and (ABytes[0] = $EF) and (ABytes[1] = $BB) and (ABytes[2] = $BF) then
  begin
    Utf8 := '';
    SetLength(Utf8, N - 3);
    for I := 3 to N - 1 do
      Utf8[I - 2] := AnsiChar(ABytes[I]);
    try
      AText := LandrixEInvoiceUtf8ToString(Utf8);
    except
      on EOutOfMemory do
        raise;
      on Exception do
      begin
        AText := '?';
        Result := False;
      end;
    end;
    Exit;
  end;
  SetLength(AText, N);
  for I := 0 to N - 1 do
    AText[I + 1] := WideChar(LandrixEInvoicePdfDocChar(ABytes[I]));
end;

{ The /Name of an optional content group or configuration; a missing name
  or one that is no string counts as ''. False for malformed UTF-8.
  DE: Der /Name einer Gruppe oder Konfiguration optionaler Inhalte; ein
  fehlender Name oder einer, der kein String ist, zaehlt als ''. False bei
  fehlerhaftem UTF-8. }
function OcEntryName(ADoc: TLandrixEInvoicePdfDocument; ADict: TLandrixEInvoicePdfObject;
  out AName: TLandrixEInvoiceString): Boolean;
var
  N: TLandrixEInvoicePdfObject;
begin
  AName := '';
  Result := True;
  N := ADoc.DGet(ADict, 'Name');
  if (N <> nil) and (N.Kind = pok_Str) then
    Result := OcText(N.StrVal, AName);
end;

function OcContains(const ANames: TOcNames; ACount: Integer; const AName: TLandrixEInvoiceString): Boolean;
var
  I: Integer;
begin
  Result := False;
  for I := 0 to ACount - 1 do
    if ANames[I] = AName then
    begin
      Result := True;
      Exit;
    end;
end;

{ Adds AName unless it is there; False beyond MaxOcNames. }
function OcAdd(var ANames: TOcNames; var ACount: Integer; const AName: TLandrixEInvoiceString): Boolean;
begin
  Result := True;
  if OcContains(ANames, ACount, AName) then
    Exit;
  if ACount >= MaxOcNames then
  begin
    Result := False;
    Exit;
  end;
  if ACount = Integer(Length(ANames)) then
    SetLength(ANames, 16 + 2 * ACount);
  ANames[ACount] := AName;
  Inc(ACount);
end;

{ 6.9-3: marks the groups whose names an /Order array (and the arrays in it)
  names with a dictionary whose /Name is a string (a group without a name
  stays unmarked); labels are ignored. False if cut short (a limit or a
  malformed name).
  DE: 6.9-3: markiert die Gruppen, deren Namen ein /Order-Array (und die
  Arrays darin) mit einem Dictionary nennt, dessen /Name ein String ist
  (eine Gruppe ohne Namen bleibt unmarkiert); Beschriftungen zaehlen nicht.
  False, wenn abgebrochen (eine Grenze oder ein fehlerhafter Name). }
function OcRemoveOrder(ADoc: TLandrixEInvoicePdfDocument; AOrder: TLandrixEInvoicePdfObject; const AGroups: TOcNames;
  ACount: Integer; var ARemoved: TOcFlags; var ANodes: Integer; ADepth: Integer): Boolean;
var
  I, K: Integer;
  V, N: TLandrixEInvoicePdfObject;
  Name: TLandrixEInvoiceString;
begin
  Result := False;
  { every entry counts, labels too: arrays may be shared many times }
  Inc(ANodes, 1 + AOrder.ArrCount);
  if (ANodes > MaxOcWork) or (ADepth > MaxTreeDepth) then
    Exit;
  for I := 0 to AOrder.ArrCount - 1 do
  begin
    V := ADoc.Resolve(AOrder.ArrItem(I));
    if V = nil then
      Continue;
    if V.Kind = pok_Arr then
    begin
      if not OcRemoveOrder(ADoc, V, AGroups, ACount, ARemoved, ANodes, ADepth + 1) then
        Exit;
    end
    else if V.Kind = pok_Dict then
    begin
      { only a name that is a string removes a group }
      Inc(ANodes, 1 + ACount);
      if ANodes > MaxOcWork then
        Exit;
      N := ADoc.DGet(V, 'Name');
      if (N = nil) or (N.Kind <> pok_Str) then
        Continue;
      if not OcText(N.StrVal, Name) then
        Exit;
      for K := 0 to ACount - 1 do
        if AGroups[K] = Name then
          ARemoved[K] := True;
    end;
  end;
  Result := True;
end;

{ An integer as veraPDF reads it from a dictionary entry: a number
  truncated toward zero, a string its byte length; False for anything else. }
function AFInteger(V: TLandrixEInvoicePdfObject; out AValue: Int64): Boolean;
begin
  Result := False;
  AValue := 0;
  if V = nil then
    Exit;
  if V.Kind = pok_Num then
  begin
    { an integer token as it is; a real truncated toward zero, saturated
      beyond about 9e18 }
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
  { veraPDF keeps the low 32 bits }
  AValue := AValue and $FFFFFFFF;
  if AValue > $7FFFFFFF then
    AValue := AValue - $100000000;
end;

{ A raw dictionary value veraPDF counts as present: anything but a direct
  null and a reference to a null object; a reference to no object counts.
  DE: Ein roher Dictionary-Wert, den veraPDF als vorhanden zaehlt: alles
  ausser einem direkten null und einer Referenz auf ein null-Objekt; eine
  Referenz auf kein Objekt zaehlt. }
function PresentValue(ADoc: TLandrixEInvoicePdfDocument; ARaw: TLandrixEInvoicePdfObject): Boolean;
var
  V: TLandrixEInvoicePdfObject;
  Unsure: Boolean;
begin
  Result := False;
  if (ARaw = nil) or (ARaw.Kind = pok_Null) then
    Exit;
  if ARaw.Kind = pok_Ref then
  begin
    { a chain too long to follow may end in null: not counted }
    Unsure := False;
    V := LandrixEInvoicePdfResolveRef(ADoc, ARaw, Unsure);
    Result := not Unsure and ((V = nil) or (V.Kind <> pok_Null));
  end
  else
    Result := True;
end;

{ For each pair of a name tree's /Names array: True where a later pair of
  the same array has the same string key (veraPDF keeps the last value of a
  key, compared as decoded text).
  DE: Je Paar eines /Names-Arrays: True, wo ein spaeteres Paar desselben
  Arrays denselben String-Schluessel hat (veraPDF behaelt den letzten Wert
  eines Schluessels, als dekodierter Text verglichen). }
function SupersededNames(ADoc: TLandrixEInvoicePdfDocument; AArr: TLandrixEInvoicePdfObject): TSupersededFlags;
var
  Keys: array of TLandrixEInvoiceString;
  Idx, Tmp: array of Integer;
  N, M, I, Width, Lo, Mid, Hi, L, R, K: Integer;
  O: TLandrixEInvoicePdfObject;
begin
  Result := nil;
  Keys := nil;
  Idx := nil;
  Tmp := nil;
  { pairs, and a last key without a value (veraPDF gives it an empty value
    that replaces an earlier one) }
  N := (AArr.ArrCount + 1) div 2;
  SetLength(Result, N + 1);
  SetLength(Keys, N);
  SetLength(Idx, N);
  M := 0;
  for I := 0 to N - 1 do
  begin
    Result[I] := False;
    O := ADoc.Resolve(AArr.ArrItem(2 * I));
    if (O <> nil) and (O.Kind = pok_Str) then
    begin
      { compared as the decoded text, as veraPDF compares them }
      Keys[I] := LandrixEInvoicePdfTextToString(O.StrVal);
      Idx[M] := I;
      Inc(M);
    end;
  end;
  Result[N] := False;
  { stable merge sort of the pairs with a string key by key }
  SetLength(Tmp, M);
  Width := 1;
  while Width < M do
  begin
    Lo := 0;
    while Lo < M do
    begin
      Mid := Lo + Width;
      if Mid > M then
        Mid := M;
      Hi := Mid + Width;
      if Hi > M then
        Hi := M;
      L := Lo;
      R := Mid;
      K := Lo;
      while K < Hi do
      begin
        if (L < Mid) and ((R >= Hi) or not (Keys[Idx[R]] < Keys[Idx[L]])) then
        begin
          Tmp[K] := Idx[L];
          Inc(L);
        end
        else
        begin
          Tmp[K] := Idx[R];
          Inc(R);
        end;
        Inc(K);
      end;
      Lo := Hi;
    end;
    for K := 0 to M - 1 do
      Idx[K] := Tmp[K];
    Width := Width * 2;
  end;
  { in a run of equal keys (in array order) all but the last are replaced }
  for K := 0 to M - 2 do
    if Keys[Idx[K]] = Keys[Idx[K + 1]] then
      Result[Idx[K]] := True;
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
  FClaimedPart := 0;
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
  FNodesC := 0;
  FNodesOc := 0;
  FWalkBroken := False;
  FAssoc := nil;
  FAssocPage := nil;
  FAFInPages := False;
  FAFPagesUnsure := False;
  FSpecSeen := nil;
  FSpecs := nil;
  FSpecNums := nil;
  FSpecCount := 0;
  FMetaSeen := nil;
  FMetaNums := nil;
  FMetaCount := 0;
  FPropIds := nil;
  FPropDefined := nil;
  FPropValid := nil;
  FPropNums := nil;
  FPropNames := nil;
  FPropCount := 0;
  FPropWork := 0;
  FPagesUnsure := False;
  FNodesPages := 0;
  FLive := nil;
  FLiveCount := 0;
  FLiveByNum := nil;
  FContentSure := nil;
  FContentMaybe := nil;
  FAFSeen := nil;
  FAFUnsure := False;
  FOutputCS := '';
  FOutputCSKnown := True;
  FVeraThrows := False;
end;

procedure TLandrixEInvoicePdfARuleCheck.Fail(ARule: TLandrixEInvoicePdfARule; AObjNum, AObjGen: Integer;
  ASource: TLandrixEInvoicePdfSyntaxSource; APos: Integer; const ADetail: string);
begin
  if FPagesUnsure then
  begin
    FIncomplete[ARule] := True;
    Exit;
  end;
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
    CountPages(FDoc.DGet(FDoc.Catalog, 'Pages'), 0);
    CheckPages(FDoc.DGet(FDoc.Catalog, 'Pages'), nil, nil, nil, nil, 0);
    FPagesUnsure := False;
    CheckForm;
    CheckCatalogActions;
    CheckOptionalContent;
    CheckCatalogLate;
    CheckOutputIntents;
  end
  else
  begin
    FIncomplete[par_6_1_12_1] := True;
    FIncomplete[par_6_1_12_2] := True;
    FIncomplete[par_6_1_13_11] := True;
    FIncomplete[par_6_2_3_1] := True;
    FIncomplete[par_6_2_3_2] := True;
    FIncomplete[par_6_2_3_3] := True;
    FOutputCSKnown := False;
    MarkStageB;
    MarkLateA;
  end;
  CheckContent;
  CheckFileSpecs;
  CheckMetadata;

  for R := Low(TLandrixEInvoicePdfARule) to High(TLandrixEInvoicePdfARule) do
    if Rules[R].Coverage = prc_None then
      FResults[R].Outcome := pro_NotChecked
    else if FVeraThrows then
    begin
      { veraPDF reports nothing for such a document
        DE: veraPDF meldet fuer ein solches Dokument nichts }
      FResults[R].Outcome := pro_Incomplete;
      FResults[R].Failures := 0;
      FResults[R].ObjNum := -1;
      FResults[R].ObjGen := -1;
      FResults[R].Source := pss_File;
      FResults[R].Pos := -1;
      FResults[R].Detail := '';
    end
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
  Filter, Parms, F, P, N, Raw: TLandrixEInvoicePdfObject;
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
      { veraPDF 1.30.4 (GFCosStream): with one filter the raw /DecodeParms,
        which is a parameter dictionary only when it is a direct one; with
        several filters the entry of the parameter array }
      P := nil;
      if Count = 1 then
      begin
        Raw := AStream.Stream.RawGet('DecodeParms');
        if (Raw <> nil) and (Raw.Kind = pok_Dict) then
          P := Raw;
      end
      else if (Parms <> nil) and (Parms.Kind = pok_Arr) and (I < Parms.ArrCount) then
        P := FDoc.Resolve(Parms.ArrItem(I));
      Ok := True;
      { a parameter dictionary without /Name names no filter (veraPDF:
        null is not Identity); parameters that are no dictionary count as
        absent }
      if (P <> nil) and P.IsDictLike then
      begin
        N := FDoc.DGet(P, 'Name');
        if (N = nil) or (N.Kind <> pok_Name) or (N.NameVal <> 'Identity') then
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
  objects and of the newest trailer (content streams: CheckContent). A
  string's length is measured as veraPDF measures it; where that is not
  certain on the limit, the rule stays undecided.
  DE: 6.1.6 und 6.1.13-1 bis -5 an den Zahlen, Strings und Namen lebender
  Objekte und des neuesten Trailers (Content-Streams: CheckContent). Die
  Laenge eines Strings wird gemessen, wie veraPDF sie misst; wo das an der
  Grenze nicht sicher ist, bleibt die Regel offen. }
procedure TLandrixEInvoicePdfARuleCheck.CheckTokens;
var
  I: Integer;
  T: TLandrixEInvoicePdfTokenFact;
  Where: string;
begin
  for I := 0 to FFacts.TokenCount - 1 do
  begin
    T := FFacts.Tokens[I];
    if T.Replaced or not TokenLive(T) then
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
              ' characters')
          else if T.LengthHi > 32767 then
            FIncomplete[par_6_1_13_3] := True;
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

{ The leaves below ANode as veraPDF tells nodes and pages (the root a node,
  below it /Type /Pages a node and /Type /Page a page); sets FPagesUnsure
  where a kid has another type, a node's /Count differs from its leaves or
  a limit is reached: veraPDF finds a page by its index through /Count and
  may see other pages.
  DE: Die Blaetter unter ANode, wie veraPDF Knoten und Seiten
  unterscheidet; setzt FPagesUnsure, wo ein Kind einen anderen Typ hat, das
  /Count eines Knotens nicht zu seinen Blaettern passt oder eine Grenze
  erreicht ist. }
function TLandrixEInvoicePdfARuleCheck.CountPages(ANode: TLandrixEInvoicePdfObject; ADepth: Integer): Integer;
var
  T, Kids: TLandrixEInvoicePdfObject;
  Count: Int64;
  I: Integer;
begin
  Result := 0;
  Inc(FNodesPages);
  if (ANode = nil) or not ANode.IsDictLike or (ADepth > MaxTreeDepth) or (FNodesPages > MaxNodes) then
  begin
    FPagesUnsure := True;
    Exit;
  end;
  if ADepth > 0 then
  begin
    T := FDoc.DGet(ANode, 'Type');
    if (T = nil) or (T.Kind <> pok_Name) or ((T.NameVal <> 'Page') and (T.NameVal <> 'Pages')) then
    begin
      FPagesUnsure := True;
      Exit;
    end;
    if T.NameVal = 'Page' then
    begin
      Result := 1;
      Exit;
    end;
  end;
  Kids := FDoc.DGet(ANode, 'Kids');
  if (Kids <> nil) and (Kids.Kind = pok_Arr) then
    for I := 0 to Kids.ArrCount - 1 do
    begin
      Inc(Result, CountPages(FDoc.Resolve(Kids.ArrItem(I)), ADepth + 1));
      if FPagesUnsure then
        Exit;
    end;
  if not AFInteger(FDoc.DGet(ANode, 'Count'), Count) then
    Count := 0;
  if Count <> Result then
    FPagesUnsure := True;
end;

{ 6.1.13-11: MediaBox and CropBox (inherited) and the BleedBox, TrimBox and
  ArtBox of every page.
  DE: 6.1.13-11: MediaBox und CropBox (geerbt) und BleedBox, TrimBox und
  ArtBox jeder Seite. }
procedure TLandrixEInvoicePdfARuleCheck.CheckPages(ANode, AMediaBox, ACropBox, AMediaOwner,
  ACropOwner: TLandrixEInvoicePdfObject; ADepth: Integer);
var
  Kids, Box, Media, Crop, MediaOwner, CropOwner, TypeObj, Annots, A, Raw: TLandrixEInvoicePdfObject;
  I: Integer;
begin
  { a page tree node that does not resolve leaves boxes, annotations and
    page actions unchecked }
  if (ANode = nil) or not ANode.IsDictLike then
  begin
    FIncomplete[par_6_1_13_11] := True;
    FIncomplete[par_6_10_2] := True;
    MarkStageB;
    Exit;
  end;
  Inc(FNodes);
  if (ADepth > MaxTreeDepth) or (FNodes > MaxNodes) then
  begin
    FIncomplete[par_6_1_13_11] := True;
    FIncomplete[par_6_10_2] := True;
    MarkStageB;
    Exit;
  end;
  Media := AMediaBox;
  Crop := ACropBox;
  MediaOwner := AMediaOwner;
  CropOwner := ACropOwner;
  Box := FDoc.DGet(ANode, 'MediaBox');
  if Box <> nil then
  begin
    Media := Box;
    MediaOwner := ANode;
  end;
  Box := FDoc.DGet(ANode, 'CropBox');
  if Box <> nil then
  begin
    Crop := Box;
    CropOwner := ANode;
  end;
  TypeObj := FDoc.DGet(ANode, 'Type');
  { veraPDF makes the root a node whatever its /Type and tells the kids by
    /Type: /Pages a node, /Page a page; it does not judge a kid of another
    type }
  if (ADepth > 0) and ((TypeObj = nil) or (TypeObj.Kind <> pok_Name) or
    ((TypeObj.NameVal <> 'Page') and (TypeObj.NameVal <> 'Pages'))) then
  begin
    MarkPageRules;
    Exit;
  end;
  if (ADepth = 0) or (TypeObj.NameVal = 'Pages') then
  begin
    Kids := FDoc.DGet(ANode, 'Kids');
    if (Kids <> nil) and (Kids.Kind = pok_Arr) then
      for I := 0 to Kids.ArrCount - 1 do
        CheckPages(FDoc.Resolve(Kids.ArrItem(I)), Media, Crop, MediaOwner, CropOwner, ADepth + 1);
    Exit;
  end;
  CheckBox(Media, 'MediaBox', MediaOwner);
  CheckBox(Crop, 'CropBox', CropOwner);
  CheckBox(FDoc.DGet(ANode, 'BleedBox'), 'BleedBox', ANode);
  CheckBox(FDoc.DGet(ANode, 'TrimBox'), 'TrimBox', ANode);
  CheckBox(FDoc.DGet(ANode, 'ArtBox'), 'ArtBox', ANode);
  { 6.5.2-2 and the page events O and C; the annotations of the page }
  if Known(ANode, 'AA') then
    FailAt(par_6_5_2_2, ANode, 'page with /AA');
  CheckEvents(FDoc.DGet(ANode, 'AA'), ['O', 'C']);
  { 6.10-2: the page's own /PresSteps, not inherited; any value but null (a
    reference to no object counts, one to a null object does not)
    DE: 6.10-2: das eigene /PresSteps der Seite, nicht geerbt; jeder Wert
    ausser null (eine Referenz auf kein Objekt zaehlt, eine auf ein
    null-Objekt nicht) }
  Raw := ANode.RawGet('PresSteps');
  if PresentValue(FDoc, Raw) then
    FailAt(par_6_10_2, ANode, 'page with /PresSteps');
  { veraPDF builds annotations from dictionaries only }
  Annots := FDoc.DGet(ANode, 'Annots');
  if (Annots <> nil) and (Annots.Kind = pok_Arr) then
    for I := 0 to Annots.ArrCount - 1 do
    begin
      A := FDoc.Resolve(Annots.ArrItem(I));
      if (A <> nil) and (A.Kind = pok_Dict) then
        CheckAnnot(A);
    end;
end;

{ The rules a page and its annotations decide cannot be checked (a page
  veraPDF may see is not walked).
  DE: Die Regeln, die eine Seite und ihre Annotationen entscheiden, sind
  nicht pruefbar (eine Seite, die veraPDF sehen kann, wird nicht
  durchlaufen). }
procedure TLandrixEInvoicePdfARuleCheck.MarkPageRules;
var
  R: TLandrixEInvoicePdfARule;
begin
  FIncomplete[par_6_1_13_11] := True;
  FIncomplete[par_6_10_2] := True;
  FIncomplete[par_6_4_1_1] := True;
  FIncomplete[par_6_5_2_2] := True;
  for R := par_6_3_1_1 to par_6_3_3_4 do
    FIncomplete[R] := True;
  for R := par_6_5_1_1 to par_6_5_1_2 do
    FIncomplete[R] := True;
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
    { every step counts to the stage B budget: widgets sharing a long chain
      must not repeat it without limit }
    Inc(FNodesB);
    if (Depth > MaxParentChain) or (FNodesB > MaxNodes) then
    begin
      if FNodesB > MaxNodes then
        MarkStageB;
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
  I, K: Integer;
  TypeKnown, Seen, TooMany: Boolean;
begin
  if not StageBBudget(0) then
    Exit;
  TooMany := False;
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

  { /F as veraPDF reads an integer entry: a number truncated toward zero,
    a string its byte length (the low 32 bits), anything else none
    DE: /F, wie veraPDF einen ganzzahligen Eintrag liest: eine Zahl, zur Null hin
    abgeschnitten, ein String seine Bytelaenge (die unteren 32 Bit), alles
    andere keines }
  Flags := 0;
  FObj := FDoc.DGet(AAnnot, 'F');
  HasFlags := Known(AAnnot, 'F') and AFInteger(FObj, Flags);
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
    { veraPDF's getRealArray: every entry must be a number or a string (its
      byte length), the first four are the rectangle }
    for I := 0 to Rect.ArrCount - 1 do
    begin
      O := FDoc.Resolve(Rect.ArrItem(I));
      if (O <> nil) and (O.Kind = pok_Num) then
      begin
        if I <= 3 then
          R[I] := O.NumVal;
      end
      else if (O <> nil) and (O.Kind = pok_Str) then
      begin
        if I <= 3 then
          R[I] := Length(O.StrVal);
      end
      else
        HasRect := False;
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
  { an appearance dictionary has N, D and R; beyond MaxAppearanceKeys keys
    the rules on it stay undecided (the key list would cost quadratic time) }
  if (AP <> nil) and (AP.DVals.Count > MaxAppearanceKeys) then
  begin
    FIncomplete[par_6_3_3_2] := True;
    FIncomplete[par_6_3_3_3] := True;
    FIncomplete[par_6_3_3_4] := True;
    AP := nil;
    TooMany := True;
  end;
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
  if (AP = nil) and not TooMany and (Subtype <> 'Popup') and (Subtype <> 'Link') and
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
      else if (Entry.Kind = pok_Dict) and (Entry.DVals.Count > MaxAppearanceKeys) then
      begin
        { too many states to look up by key: undecided }
        FIncomplete[par_6_3_3_3] := True;
        Appearances := True;
      end
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
  O := ActionGet(AAnnot, 'A');
  if (O <> nil) and (O.Kind = pok_Dict) then
    CheckAction(O, 0);
  CheckEvents(FDoc.DGet(AAnnot, 'AA'), ['E', 'X', 'D', 'U', 'Fo', 'Bl', 'PO', 'PC', 'PV', 'PI']);
end;

{ An action reference as veraPDF resolves it (number and generation; nil
  where no such object is in use); a chain too long to follow leaves 6.5.1
  undecided.
  DE: Eine Aktionsreferenz, wie veraPDF sie aufloest (Nummer und
  Generation; nil, wo kein solches Objekt benutzt ist); eine zu lange Kette
  laesst 6.5.1 offen. }
function TLandrixEInvoicePdfARuleCheck.ActionRef(ARaw: TLandrixEInvoicePdfObject): TLandrixEInvoicePdfObject;
var
  Unsure: Boolean;
begin
  Unsure := False;
  Result := GenRef(ARaw, Unsure);
  if Unsure then
  begin
    FIncomplete[par_6_5_1_1] := True;
    FIncomplete[par_6_5_1_2] := True;
  end;
end;

function TLandrixEInvoicePdfARuleCheck.ActionGet(AObj: TLandrixEInvoicePdfObject;
  const AKey: AnsiString): TLandrixEInvoicePdfObject;
begin
  Result := nil;
  if (AObj <> nil) and AObj.IsDictLike then
    Result := ActionRef(AObj.RawGet(AKey));
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
    A := ActionGet(AAA, AEvents[I]);
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
  Ok, Unsure: Boolean;
begin
  if not StageBBudget(ADepth) then
    Exit;
  Kind := '';
  Unsure := False;
  S := GenRef(AAction.RawGet('S'), Unsure);
  if (S <> nil) and (S.Kind = pok_Name) then
    Kind := S.NameVal;
  Ok := False;
  for I := 0 to High(Allowed) do
    if Kind = Allowed[I] then
      Ok := True;
  if Unsure then
  begin
    FIncomplete[par_6_5_1_1] := True;
    FIncomplete[par_6_5_1_2] := True;
  end
  else if not Ok then
    FailAt(par_6_5_1_1, AAction, 'action ' + AsciiText(Kind));
  if Kind = 'Named' then
  begin
    Name := '';
    N := GenRef(AAction.RawGet('N'), Unsure);
    if (N <> nil) and (N.Kind = pok_Name) then
      Name := N.NameVal;
    Ok := False;
    for I := 0 to High(Named) do
      if Name = Named[I] then
        Ok := True;
    if Unsure then
      FIncomplete[par_6_5_1_2] := True
    else if not Ok then
      FailAt(par_6_5_1_2, AAction, 'named action ' + AsciiText(Name));
  end;
  Next := ActionGet(AAction, 'Next');
  if Next = nil then
    Exit;
  if Next.Kind = pok_Dict then
    CheckAction(Next, ADepth + 1)
  else if Next.Kind = pok_Arr then
    for I := 0 to Next.ArrCount - 1 do
    begin
      A := ActionRef(Next.ArrItem(I));
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
  Open := ActionGet(Cat, 'OpenAction');
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
    A := ActionGet(Item, 'A');
    if (A <> nil) and (A.Kind = pok_Dict) then
      CheckAction(A, 0);
    CheckOutline(FDoc.DGet(Item, 'First'), ADepth + 1);
    Item := FDoc.DGet(Item, 'Next');
  end;
end;

{ The rules of 6.8 to 6.11 cannot all be checked: no catalog. }
procedure TLandrixEInvoicePdfARuleCheck.MarkLateA;
var
  R: TLandrixEInvoicePdfARule;
begin
  for R := par_6_8_1 to par_6_11_1 do
    FIncomplete[R] := True;
end;

{ The walk of all objects missed something (an object not readable, a
  limit): the file specifications are not all known, and one that no array
  seen names is no proven failure of 6.8-4. }
procedure TLandrixEInvoicePdfARuleCheck.BreakWalk;
begin
  FWalkBroken := True;
  FIncomplete[par_6_8_1] := True;
  FIncomplete[par_6_8_2] := True;
  FIncomplete[par_6_8_3] := True;
  FIncomplete[par_6_8_4] := True;
end;

{ The object numbers an array names by reference. }
procedure TLandrixEInvoicePdfARuleCheck.AddAssoc(AArr: TLandrixEInvoicePdfObject);
var
  I, N, Depth: Integer;
  Item, O: TLandrixEInvoicePdfObject;
begin
  if (AArr = nil) or (AArr.Kind <> pok_Arr) or FWalkBroken then
    Exit;
  { every item counts against the walk budget: many dictionaries may name
    the same large array }
  Inc(FNodesC, AArr.ArrCount);
  if FNodesC > MaxWalkNodes then
  begin
    BreakWalk;
    Exit;
  end;
  for I := 0 to AArr.ArrCount - 1 do
  begin
    Item := AArr.ArrItem(I);
    { the reference must name the object in use, generation included }
    if (Item <> nil) and (Item.Kind = pok_Ref) and (AFRef(Item) <> nil) then
    begin
      { an object that holds a reference stands for the object it names }
      N := Item.RefNum;
      O := FDoc.GetObject(N);
      Depth := 0;
      while (O <> nil) and (O.Kind = pok_Ref) and (Depth < 32) do
      begin
        N := O.RefNum;
        O := FDoc.GetObject(N);
        Inc(Depth);
      end;
      if (N >= 0) and (N < Integer(Length(FAssoc))) then
      begin
        if FAFInPages then
          FAssocPage[N] := True
        else
          FAssoc[N] := True;
      end;
    end;
  end;
end;

{ A file specification, once per indirect object. }
procedure TLandrixEInvoicePdfARuleCheck.AddSpec(ASpec: TLandrixEInvoicePdfObject; ANum: Integer);
begin
  if ANum >= 0 then
  begin
    if (ANum >= Integer(Length(FSpecSeen))) or FSpecSeen[ANum] then
      Exit;
    FSpecSeen[ANum] := True;
  end;
  if FSpecCount = Integer(Length(FSpecs)) then
  begin
    SetLength(FSpecs, 16 + 2 * FSpecCount);
    SetLength(FSpecNums, 16 + 2 * FSpecCount);
  end;
  FSpecs[FSpecCount] := ASpec;
  FSpecNums[FSpecCount] := ANum;
  Inc(FSpecCount);
end;

{ 6.8: a value and the direct values in it. A dictionary with /Type
  /Filespec is a file specification (ANum: its object number if it is the
  object itself, else -1). The /AF arrays that associate files are
  collected by CollectAF.
  DE: 6.8: ein Wert und die direkten Werte darin. Ein Dictionary mit /Type
  /Filespec ist eine Dateispezifikation (ANum: seine Objektnummer, wenn es
  das Objekt selbst ist, sonst -1). Die /AF-Arrays, die Dateien zuordnen,
  sammelt CollectAF. }
procedure TLandrixEInvoicePdfARuleCheck.WalkValue(AObj: TLandrixEInvoicePdfObject; ANum, ADepth: Integer);
var
  I: Integer;
  V, T: TLandrixEInvoicePdfObject;
begin
  if FWalkBroken then
    Exit;
  Inc(FNodesC);
  if (FNodesC > MaxWalkNodes) or (ADepth > MaxWalkDepth) then
  begin
    BreakWalk;
    Exit;
  end;
  if AObj.Kind = pok_Arr then
  begin
    for I := 0 to AObj.ArrCount - 1 do
    begin
      V := AObj.ArrItem(I);
      if (V <> nil) and ((V.Kind = pok_Arr) or (V.Kind = pok_Dict)) then
        WalkValue(V, -1, ADepth + 1);
    end;
    Exit;
  end;
  if not AObj.IsDictLike then
    Exit;
  if AObj.Kind = pok_Dict then
  begin
    T := FDoc.DGet(AObj, 'Type');
    if (T <> nil) and (T.Kind = pok_Name) and (T.NameVal = 'Filespec') then
      AddSpec(AObj, ANum);
  end;
  AddMetadata(AObj);
  for I := 0 to Integer(AObj.DVals.Count) - 1 do
  begin
    V := TLandrixEInvoicePdfObject(AObj.DVals[I]);
    if V = nil then
      Continue;
    if (V.Kind = pok_Arr) or (V.Kind = pok_Dict) then
      WalkValue(V, -1, ADepth + 1);
  end;
end;

{ 6.8: the values of the EmbeddedFiles name tree are file specifications
  also without /Type (those with /Type /Filespec the walk found).
  DE: 6.8: die Werte des EmbeddedFiles-Namensbaums sind
  Dateispezifikationen auch ohne /Type (die mit /Type /Filespec fand der
  Durchlauf). }
procedure TLandrixEInvoicePdfARuleCheck.WalkEmbeddedFiles(ANode: TLandrixEInvoicePdfObject; ADepth: Integer);
var
  Arr, Raw, V, T, Kids, O: TLandrixEInvoicePdfObject;
  I, Num, Depth: Integer;
  Superseded: TSupersededFlags;
begin
  Superseded := nil;
  if (ANode = nil) or not ANode.IsDictLike or FWalkBroken then
    Exit;
  Inc(FNodesC);
  if (FNodesC > MaxWalkNodes) or (ADepth > MaxTreeDepth) then
  begin
    BreakWalk;
    Exit;
  end;
  Arr := FDoc.DGet(ANode, 'Names');
  if (Arr <> nil) and (Arr.Kind = pok_Arr) then
  begin
    { a node listed twice in /Kids is walked twice: its entries count }
    Inc(FNodesC, Arr.ArrCount);
    if FNodesC > MaxWalkNodes then
    begin
      BreakWalk;
      Exit;
    end;
    Superseded := SupersededNames(FDoc, Arr);
    I := 1;
    while I < Arr.ArrCount do
    begin
      if Superseded[I div 2] then
      begin
        Inc(I, 2);
        Continue;
      end;
      Raw := Arr.ArrItem(I);
      V := FDoc.Resolve(Raw);
      if (V <> nil) and (V.Kind = pok_Dict) then
      begin
        T := FDoc.DGet(V, 'Type');
        if not ((T <> nil) and (T.Kind = pok_Name) and (T.NameVal = 'Filespec')) then
        begin
          Num := -1;
          if (Raw <> nil) and (Raw.Kind = pok_Ref) then
          begin
            { the object at the end of a reference chain, as /AF names it }
            Num := Raw.RefNum;
            O := FDoc.GetObject(Num);
            Depth := 0;
            while (O <> nil) and (O.Kind = pok_Ref) and (Depth < 32) do
            begin
              Num := O.RefNum;
              O := FDoc.GetObject(Num);
              Inc(Depth);
            end;
          end;
          AddSpec(V, Num);
        end;
      end;
      Inc(I, 2);
    end;
  end;
  Kids := FDoc.DGet(ANode, 'Kids');
  if (Kids <> nil) and (Kids.Kind = pok_Arr) then
    for I := 0 to Kids.ArrCount - 1 do
      WalkEmbeddedFiles(FDoc.Resolve(Kids.ArrItem(I)), ADepth + 1);
end;

procedure TLandrixEInvoicePdfARuleCheck.SpecFail(ARule: TLandrixEInvoicePdfARule; AIndex: Integer;
  const ADetail: string);
var
  Num: Integer;
begin
  Num := FSpecNums[AIndex];
  if Num >= 0 then
    Fail(ARule, Num, FDoc.XrefEntry(Num).Gen, pss_File, -1, 'object ' + IntToStr(Num) + ': ' + ADetail)
  else
    FailAt(ARule, FSpecs[AIndex], ADetail);
end;

{ 6.1.6, 6.1.10-1, 6.1.13-1 to -5, 6.1.13-8 and 6.8-2 to -4 in the content
  streams veraPDF reads, and 6.2.2, 6.2.4.2-2, 6.2.4.3, 6.2.4.4, 6.2.5,
  6.2.6-1, 6.2.8, 6.2.9, 6.2.10 and the font dictionary rules of 6.2.11 for
  the operators, graphics states, colour spaces, images, forms and fonts
  they use (LandrixEInvoicePdfContent): certain findings fail the rule,
  uncertain ones leave it undecided; the associations of /AF /Name BDC are
  kept for 6.8-4.
  DE: 6.1.6, 6.1.10-1, 6.1.13-1 bis -5, 6.1.13-8 und 6.8-2 bis -4 in den
  Content-Streams, die veraPDF liest, und 6.2.2, 6.2.4.2-2, 6.2.4.3,
  6.2.4.4, 6.2.5, 6.2.6-1, 6.2.8, 6.2.9, 6.2.10 und die Regeln aus 6.2.11
  fuer Schrift-Dictionarys fuer die Operatoren, Grafikzustaende,
  Farbraeume, Bilder, Formen und Schriften, die sie benutzen
  (LandrixEInvoicePdfContent): sichere Befunde verletzen die Regel,
  unsichere lassen sie offen; die Zuordnungen durch /AF /Name BDC bleiben
  fuer 6.8-4. }
procedure TLandrixEInvoicePdfARuleCheck.CheckContent;
const
  RuleOf: array[TLandrixEInvoicePdfContentCheck] of TLandrixEInvoicePdfARule = (par_6_1_13_1, par_6_1_13_2,
    par_6_1_13_5, par_6_1_13_3, par_6_1_6_1, par_6_1_6_2, par_6_1_13_4, par_6_1_10_1, par_6_1_13_8, par_6_8_2,
    par_6_8_3, par_6_8_4, par_6_2_2_1, par_6_2_5_1, par_6_2_5_2, par_6_2_5_3, par_6_2_5_4, par_6_2_5_5,
    par_6_2_5_6, par_6_2_6_1, par_6_2_8_1, par_6_2_8_2, par_6_2_8_3, par_6_2_8_4, par_6_2_8_5, par_6_2_9_1,
    par_6_2_9_2, par_6_2_9_3, par_6_2_10_1, par_6_2_4_3_4, par_6_2_4_3_2, par_6_2_4_3_3, par_6_2_4_2_1, par_6_1_13_9,
    par_6_2_4_4_1, par_6_2_4_2_2, par_6_2_4_4_2, par_6_2_2_2, par_6_2_10_2, par_6_2_8_3_1, par_6_2_8_3_2,
    par_6_2_8_3_3, par_6_2_8_3_4, par_6_2_8_3_5, par_6_2_11_2_1, par_6_2_11_2_2, par_6_2_11_2_3, par_6_2_11_2_4,
    par_6_2_11_2_5, par_6_2_11_2_6, par_6_2_11_2_7, par_6_2_11_3_1_1, par_6_2_11_3_2_1, par_6_2_11_3_3_1,
    par_6_2_11_3_3_3, par_6_2_11_4_1_1, par_6_2_11_6_2, par_6_2_11_6_3, par_6_2_11_6_1, par_6_2_11_6_4);
var
  Walk: TLandrixEInvoicePdfContentWalk;
  F: TLandrixEInvoicePdfContentFinding;
  C: TLandrixEInvoicePdfContentCheck;
  I: Integer;
  Allowed: array[TLandrixEInvoicePdfContentCheck] of Boolean;
begin
  { 6.2.4.3: a device space passes with an output intent of its family
    (DeviceGray with any); without a certain output intent a device space
    in use leaves the rule open }
  for C := Low(TLandrixEInvoicePdfContentCheck) to High(TLandrixEInvoicePdfContentCheck) do
    Allowed[C] := False;
  Allowed[pcc_DeviceGray] := FOutputCSKnown and (FOutputCS <> '');
  Allowed[pcc_DeviceRGB] := FOutputCSKnown and (FOutputCS = 'RGB ');
  Allowed[pcc_DeviceCMYK] := FOutputCSKnown and (FOutputCS = 'CMYK');
  { 6.2.10-2: any output intent profile with a colour space lets every page
    pass. DE: 6.2.10-2: jedes Output-Intent-Profil mit einem Farbraum laesst
    jede Seite bestehen. }
  Allowed[pcc_PageTransparency] := FOutputCSKnown and (FOutputCS <> '');
  SetLength(FContentSure, FDoc.XrefCount);
  SetLength(FContentMaybe, FDoc.XrefCount);
  Walk := TLandrixEInvoicePdfContentWalk.Create(FDoc);
  try
    Walk.Run;
    FVeraThrows := Walk.Throws;
    for I := 0 to Walk.FindingCount - 1 do
    begin
      F := Walk.Finding(I);
      if Allowed[F.Check] then
        Continue;
      if (F.Check in [pcc_DeviceGray, pcc_DeviceRGB, pcc_DeviceCMYK, pcc_PageTransparency]) and
        not FOutputCSKnown then
        FIncomplete[RuleOf[F.Check]] := True
      else
        Fail(RuleOf[F.Check], F.ObjNum, F.ObjGen, pss_File, -1, F.Detail);
    end;
    for C := Low(TLandrixEInvoicePdfContentCheck) to High(TLandrixEInvoicePdfContentCheck) do
      if Walk.Uncertain(C) and not Allowed[C] then
        FIncomplete[RuleOf[C]] := True;
    for I := 0 to FDoc.XrefCount - 1 do
    begin
      FContentSure[I] := Walk.AssociatedSure(I);
      FContentMaybe[I] := Walk.AssociatedMaybe(I);
    end;
  finally
    Walk.Free;
  end;
end;

{ The /AF array of AObj (resolved) associates the objects its references
  name. }
procedure TLandrixEInvoicePdfARuleCheck.RegisterAF(AObj: TLandrixEInvoicePdfObject);
begin
  if (AObj <> nil) and AObj.IsDictLike then
    AddAssoc(AFGet(AObj, 'AF'));
end;

function TLandrixEInvoicePdfARuleCheck.AFBudget(ADepth: Integer): Boolean;
begin
  Inc(FNodesC);
  Result := not FWalkBroken and (ADepth <= MaxTreeDepth) and (FNodesC <= MaxWalkNodes);
  if not Result then
    BreakWalk;
end;

{ A reference to the object in use with that number and generation (nil
  otherwise, veraPDF reads null); a direct object as it is. A chain too long
  to follow sets AUnsure.
  DE: Eine Referenz auf das benutzte Objekt mit dieser Nummer und Generation
  (sonst nil, veraPDF liest null); ein direktes Objekt unveraendert. Eine
  Kette, die zu lang zum Verfolgen ist, setzt AUnsure. }
function TLandrixEInvoicePdfARuleCheck.GenRef(ARaw: TLandrixEInvoicePdfObject;
  var AUnsure: Boolean): TLandrixEInvoicePdfObject;
begin
  Result := LandrixEInvoicePdfResolveRef(FDoc, ARaw, AUnsure);
end;

{ GenRef for the walk of 6.8: a chain too long leaves it undecided.
  DE: GenRef fuer den Durchlauf zu 6.8: eine zu lange Kette laesst ihn
  offen. }
function TLandrixEInvoicePdfARuleCheck.AFRef(ARaw: TLandrixEInvoicePdfObject): TLandrixEInvoicePdfObject;
begin
  Result := GenRef(ARaw, FAFUnsure);
end;

function TLandrixEInvoicePdfARuleCheck.AFGet(AObj: TLandrixEInvoicePdfObject;
  const AKey: AnsiString): TLandrixEInvoicePdfObject;
begin
  Result := nil;
  if (AObj <> nil) and AObj.IsDictLike then
    Result := AFRef(AObj.RawGet(AKey));
end;

{ XObjects, fonts, patterns and graphics states are walked once per object
  and role (AKind a bit: 1 XObject, 2 font, 4 graphics state, 8 pattern). }
function TLandrixEInvoicePdfARuleCheck.AFFirstVisit(ARaw: TLandrixEInvoicePdfObject; AKind: Byte): Boolean;
begin
  Result := True;
  if (ARaw = nil) or (ARaw.Kind <> pok_Ref) or (ARaw.RefNum < 0) or (ARaw.RefNum >= Integer(Length(FAFSeen))) then
    Exit;
  { a reference to no object in use gives nothing and marks nothing }
  if AFRef(ARaw) = nil then
    Exit;
  Result := (FAFSeen[ARaw.RefNum] and AKind) = 0;
  FAFSeen[ARaw.RefNum] := FAFSeen[ARaw.RefNum] or AKind;
end;

{ The pages below ANode; the number of leaves. veraPDF finds a page by its
  index through the /Count of the nodes: where one does not match, it may
  see fewer or other pages. }
function TLandrixEInvoicePdfARuleCheck.AFPages(ANode, AInherited: TLandrixEInvoicePdfObject; ADepth: Integer): Integer;
var
  Kids, T, Inh, R: TLandrixEInvoicePdfObject;
  Count: Int64;
  I: Integer;
begin
  Result := 0;
  if (ANode = nil) or not ANode.IsDictLike then
  begin
    FAFUnsure := True;
    FAFPagesUnsure := True;
    Exit;
  end;
  if not AFBudget(ADepth) then
    Exit;
  { the root's /Type is not read; a page's /Kids neither }
  T := nil;
  if ADepth > 0 then
    T := AFGet(ANode, 'Type');
  Kids := nil;
  if not ((T <> nil) and (T.Kind = pok_Name) and (T.NameVal = 'Page')) then
    Kids := AFGet(ANode, 'Kids');
  { resources: the node's own, else those inherited in the walk (not from
    /Parent) }
  Inh := AInherited;
  R := ANode.RawGet('Resources');
  if R <> nil then
    Inh := AFRef(R);
  { veraPDF makes the root a node and tells the kids by /Type; another type
    stops its walk }
  if (ADepth > 0) and ((T = nil) or (T.Kind <> pok_Name) or ((T.NameVal <> 'Page') and (T.NameVal <> 'Pages'))) then
  begin
    FAFUnsure := True;
    FAFPagesUnsure := True;
  end;
  if (ADepth = 0) or ((T <> nil) and (T.Kind = pok_Name) and (T.NameVal = 'Pages')) or
    ((Kids <> nil) and (Kids.Kind = pok_Arr) and not ((T <> nil) and (T.Kind = pok_Name) and (T.NameVal = 'Page'))) then
  begin
    if (Kids <> nil) and (Kids.Kind = pok_Arr) then
      for I := 0 to Kids.ArrCount - 1 do
        Inc(Result, AFPages(AFRef(Kids.ArrItem(I)), Inh, ADepth + 1));
    { a /Count that is no integer counts 0 }
    if not AFInteger(AFGet(ANode, 'Count'), Count) then
      Count := 0;
    if Count <> Result then
    begin
      FAFUnsure := True;
      FAFPagesUnsure := True;
    end;
    Exit;
  end;
  Result := 1;
  AFPage(ANode, Inh);
end;

{ A page: its /AF, its resources (own or inherited), its annotations with
  their /AF and their appearances N, D and R (a stream or every stream of a
  state dictionary). }
procedure TLandrixEInvoicePdfARuleCheck.AFPage(APage, ARes: TLandrixEInvoicePdfObject);
const
  ApKeys: array[0..2] of AnsiString = ('N', 'D', 'R');
var
  Annots, A, AP, V, S: TLandrixEInvoicePdfObject;
  I, K, J: Integer;
begin
  RegisterAF(APage);
  AFResources(ARes, 1);
  Annots := AFGet(APage, 'Annots');
  if (Annots = nil) or (Annots.Kind <> pok_Arr) then
    Exit;
  for I := 0 to Annots.ArrCount - 1 do
  begin
    { a page or annotation met again walks its entries again: each counts }
    if not AFBudget(1) then
      Exit;
    { veraPDF builds annotations from dictionaries only }
    A := AFRef(Annots.ArrItem(I));
    if (A = nil) or (A.Kind <> pok_Dict) then
      Continue;
    RegisterAF(A);
    AP := AFGet(A, 'AP');
    if (AP = nil) or not AP.IsDictLike then
      Continue;
    for K := 0 to High(ApKeys) do
    begin
      V := AFGet(AP, ApKeys[K]);
      if V = nil then
        Continue;
      if V.Kind = pok_Stream then
        AFAppearance(V, 1)
      else if V.Kind = pok_Dict then
        for J := 0 to Integer(V.DVals.Count) - 1 do
        begin
          if not AFBudget(1) then
            Exit;
          S := AFRef(TLandrixEInvoicePdfObject(V.DVals[J]));
          if (S <> nil) and (S.Kind = pok_Stream) then
            AFAppearance(S, 1);
        end;
    end;
  end;
end;

procedure TLandrixEInvoicePdfARuleCheck.AFAppearance(AStream: TLandrixEInvoicePdfObject; ADepth: Integer);
begin
  if not AFBudget(ADepth) then
    Exit;
  RegisterAF(AStream);
  AFResources(AFGet(AStream, 'Resources'), ADepth + 1);
end;

{ A resource dictionary: every XObject (its /AF), the resources of forms,
  Type 3 fonts (also the font of an ExtGState) and patterns. }
procedure TLandrixEInvoicePdfARuleCheck.AFResources(ARes: TLandrixEInvoicePdfObject; ADepth: Integer);
var
  C: TLandrixEInvoicePdfObject;
  I: Integer;
begin
  if (ARes = nil) or not ARes.IsDictLike or not AFBudget(ADepth) then
    Exit;
  C := AFGet(ARes, 'XObject');
  if (C <> nil) and C.IsDictLike then
    for I := 0 to Integer(C.DVals.Count) - 1 do
      AFXObject(TLandrixEInvoicePdfObject(C.DVals[I]), ADepth + 1);
  C := AFGet(ARes, 'Font');
  if (C <> nil) and C.IsDictLike then
    for I := 0 to Integer(C.DVals.Count) - 1 do
      AFFont(TLandrixEInvoicePdfObject(C.DVals[I]), ADepth + 1);
  C := AFGet(ARes, 'ExtGState');
  if (C <> nil) and C.IsDictLike then
    for I := 0 to Integer(C.DVals.Count) - 1 do
      AFGState(TLandrixEInvoicePdfObject(C.DVals[I]), ADepth + 1);
  C := AFGet(ARes, 'Pattern');
  if (C <> nil) and C.IsDictLike then
    for I := 0 to Integer(C.DVals.Count) - 1 do
      AFPattern(TLandrixEInvoicePdfObject(C.DVals[I]), ADepth + 1);
end;

{ A form, image or PostScript XObject (a stream or a dictionary with that
  /Subtype): its own /AF; a form's resources. veraPDF 1.30.4 does not go on
  from an image to its masks. }
procedure TLandrixEInvoicePdfARuleCheck.AFXObject(ARaw: TLandrixEInvoicePdfObject; ADepth: Integer);
var
  X, Sub: TLandrixEInvoicePdfObject;
begin
  if not AFBudget(ADepth) or not AFFirstVisit(ARaw, 1) then
    Exit;
  X := AFRef(ARaw);
  if (X = nil) or not X.IsDictLike then
    Exit;
  Sub := AFGet(X, 'Subtype');
  if (Sub = nil) or (Sub.Kind <> pok_Name) or
    ((Sub.NameVal <> 'Form') and (Sub.NameVal <> 'Image') and (Sub.NameVal <> 'PS')) then
    Exit;
  RegisterAF(X);
  if Sub.NameVal = 'Form' then
    AFResources(AFGet(X, 'Resources'), ADepth + 1);
end;

procedure TLandrixEInvoicePdfARuleCheck.AFFont(ARaw: TLandrixEInvoicePdfObject; ADepth: Integer);
var
  F, Sub: TLandrixEInvoicePdfObject;
begin
  if not AFBudget(ADepth) or not AFFirstVisit(ARaw, 2) then
    Exit;
  F := AFRef(ARaw);
  if (F = nil) or (F.Kind <> pok_Dict) then
    Exit;
  Sub := AFGet(F, 'Subtype');
  if (Sub <> nil) and (Sub.Kind = pok_Name) and (Sub.NameVal = 'Type3') then
    AFResources(AFGet(F, 'Resources'), ADepth + 1);
end;

procedure TLandrixEInvoicePdfARuleCheck.AFGState(ARaw: TLandrixEInvoicePdfObject; ADepth: Integer);
var
  G, F: TLandrixEInvoicePdfObject;
begin
  if not AFBudget(ADepth) or not AFFirstVisit(ARaw, 4) then
    Exit;
  G := AFRef(ARaw);
  if (G = nil) or not G.IsDictLike then
    Exit;
  F := AFGet(G, 'Font');
  if (F <> nil) and (F.Kind = pok_Arr) and (F.ArrCount > 0) then
    AFFont(F.ArrItem(0), ADepth + 1);
end;

procedure TLandrixEInvoicePdfARuleCheck.AFPattern(ARaw: TLandrixEInvoicePdfObject; ADepth: Integer);
var
  P: TLandrixEInvoicePdfObject;
  T: Int64;
  K: Integer;
begin
  if not AFBudget(ADepth) or not AFFirstVisit(ARaw, 8) then
    Exit;
  P := AFRef(ARaw);
  K := 0;
  while (P <> nil) and (P.Kind = pok_Arr) and (P.ArrCount = 1) do
  begin
    Inc(K);
    if K > 32 then
    begin
      FAFUnsure := True;
      Exit;
    end;
    P := AFRef(P.ArrItem(0));
  end;
  if (P = nil) or not P.IsDictLike then
    Exit;
  if not AFInteger(AFGet(P, 'PatternType'), T) then
    Exit;
  if T = 1 then
    AFResources(AFGet(P, 'Resources'), ADepth + 1)
  else if T = 2 then
    AFGState(P.RawGet('ExtGState'), ADepth + 1);
end;

{ The structure elements below /StructTreeRoot: a /K dictionary or the
  dictionaries of a /K array without /Type or with /Type /StructElem. }
procedure TLandrixEInvoicePdfARuleCheck.AFStruct(AKids: TLandrixEInvoicePdfObject; ADepth: Integer);
var
  I, N: Integer;
  E, T: TLandrixEInvoicePdfObject;
begin
  if (AKids = nil) or not AFBudget(ADepth) then
    Exit;
  if AKids.Kind = pok_Arr then
    N := AKids.ArrCount
  else
    N := 1;
  for I := 0 to N - 1 do
  begin
    if AKids.Kind = pok_Arr then
      E := AFRef(AKids.ArrItem(I))
    else
      E := AKids;
    if (E = nil) or (E.Kind <> pok_Dict) then
      Continue;
    T := AFGet(E, 'Type');
    if (T <> nil) and (T.Kind = pok_Name) and (T.NameVal <> 'StructElem') then
      Continue;
    RegisterAF(E);
    AFStruct(AFGet(E, 'K'), ADepth + 1);
  end;
end;

{ 6.8-4: the /AF arrays veraPDF registers: of the catalog, of every page
  of the page tree, of the annotations of a page and their appearance
  streams, of every XObject in the resources reached from pages and
  appearances (through forms, Type 3 fonts, the fonts of graphics states
  and patterns; used or not) and of the structure elements. Where the pages
  veraPDF sees may differ (/Count does not match), an unassociated file
  specification is no proven failure.
  DE: 6.8-4: die /AF-Arrays, die veraPDF registriert: des Katalogs, jeder
  Seite des Seitenbaums, der Annotationen einer Seite und ihrer
  Erscheinungs-Streams, jedes XObjects in den Ressourcen, die von Seiten
  und Erscheinungen aus erreicht werden (ueber Forms, Type-3-Schriften, die
  Schriften von Grafikzustaenden und Muster; benutzt oder nicht) und der
  Strukturelemente. Wo die Seiten, die veraPDF sieht, abweichen koennen
  (/Count passt nicht), ist eine nicht zugeordnete Dateispezifikation kein
  belegter Verstoss. }
procedure TLandrixEInvoicePdfARuleCheck.CollectAF;
var
  Root: TLandrixEInvoicePdfObject;
  I: Integer;
  RootOk: Boolean;
begin
  SetLength(FAFSeen, FDoc.XrefCount);
  for I := 0 to Integer(Length(FAFSeen)) - 1 do
    FAFSeen[I] := 0;
  { the catalog as veraPDF reaches it, generations checked; otherwise every
    association is doubtful }
  RootOk := (FDoc.RootRef <> nil) and (FDoc.RootRef.Kind = pok_Ref) and (AFRef(FDoc.RootRef) = FDoc.Catalog);
  if not RootOk then
  begin
    FAFUnsure := True;
    FAFPagesUnsure := True;
  end;
  FAFInPages := not RootOk;
  RegisterAF(FDoc.Catalog);
  FAFInPages := True;
  try
    AFPages(AFGet(FDoc.Catalog, 'Pages'), nil, 0);
  finally
    FAFInPages := not RootOk;
  end;
  Root := AFGet(FDoc.Catalog, 'StructTreeRoot');
  if (Root <> nil) and Root.IsDictLike then
    AFStruct(AFGet(Root, 'K'), 0);
  FAFInPages := False;
end;

{ 6.8 as veraPDF reads it: the file specifications are the dictionaries with
  /Type /Filespec in all live objects (also unreferenced and compressed
  ones, also nested) and the values of the EmbeddedFiles name tree. 6.8-1:
  the streams under /EF (F, UF, DOS, Mac, Unix) have a MIME type /Subtype;
  6.8-2: with /EF, /F and /UF are strings; 6.8-3: /AFRelationship is a name;
  6.8-4: an indirect file specification that an /AF array veraPDF reads
  names (CollectAF) or that /AF /Name BDC associates in a content stream
  veraPDF reads. A direct one
  is never associated. File specifications inside content streams (in
  inline dictionaries) are checked by CheckContent.
  DE: 6.8, wie veraPDF es liest: die Dateispezifikationen sind die
  Dictionaries mit /Type /Filespec in allen lebenden Objekten (auch ohne
  Verweis und komprimiert, auch verschachtelt) und die Werte des
  EmbeddedFiles-Namensbaums. 6.8-1: die Streams unter /EF (F, UF, DOS, Mac,
  Unix) haben einen MIME-Typ /Subtype; 6.8-2: mit /EF sind /F und /UF
  Strings; 6.8-3: /AFRelationship ist ein Name; 6.8-4: eine indirekte
  Dateispezifikation, die ein /AF-Array nennt, das veraPDF liest
  (CollectAF), oder die /AF /Name BDC in einem Content-Stream zuordnet, den
  veraPDF liest. Eine direkte ist nie
  zugeordnet. Dateispezifikationen in Content-Streams (in
  Inline-Dictionaries) prueft CheckContent. }
procedure TLandrixEInvoicePdfARuleCheck.CheckFileSpecs;
const
  EFKeys: array[0..4] of AnsiString = ('F', 'UF', 'DOS', 'Mac', 'Unix');
var
  N, I, K: Integer;
  X: TLandrixEInvoicePdfXrefEntry;
  Obj, D, F, UF, R, EF, S, Sub, Names: TLandrixEInvoicePdfObject;
begin
  SetLength(FAssoc, FDoc.XrefCount);
  SetLength(FAssocPage, FDoc.XrefCount);
  SetLength(FSpecSeen, FDoc.XrefCount);
  SetLength(FMetaSeen, FDoc.XrefCount);
  for N := 0 to FDoc.XrefCount - 1 do
  begin
    FAssoc[N] := False;
    FAssocPage[N] := False;
    FSpecSeen[N] := False;
    FMetaSeen[N] := False;
  end;
  for N := 0 to FDoc.XrefCount - 1 do
  begin
    if FWalkBroken then
      Break;
    X := FDoc.XrefEntry(N);
    if not X.Known or (X.Kind = pxk_Free) then
      Continue;
    Obj := ObjectOrNil(FDoc, N);
    if Obj = nil then
      BreakWalk
    else
      WalkValue(Obj, N, 0);
  end;
  if FDoc.Catalog <> nil then
  begin
    Names := FDoc.DGet(FDoc.Catalog, 'Names');
    if (Names <> nil) and Names.IsDictLike then
      WalkEmbeddedFiles(FDoc.DGet(Names, 'EmbeddedFiles'), 0);
    CollectAF;
  end
  else
    FAFUnsure := True;

  for I := 0 to FSpecCount - 1 do
  begin
    D := FSpecs[I];
    if Known(D, 'EF') then
    begin
      F := FDoc.DGet(D, 'F');
      UF := FDoc.DGet(D, 'UF');
      if not ((F <> nil) and (F.Kind = pok_Str) and (UF <> nil) and (UF.Kind = pok_Str)) then
        SpecFail(par_6_8_2, I, 'file specification of an embedded file without /F and /UF');
    end;
    R := FDoc.DGet(D, 'AFRelationship');
    if (R = nil) or (R.Kind <> pok_Name) then
      SpecFail(par_6_8_3, I, 'file specification without /AFRelationship');
    if FSpecNums[I] < 0 then
      SpecFail(par_6_8_4, I, 'direct file specification, not associated')
    else if not FAssoc[FSpecNums[I]] and not FContentSure[FSpecNums[I]] and
      not (FAssocPage[FSpecNums[I]] and not FAFPagesUnsure) then
    begin
      { a truncated array (incomplete facts) or a content stream not read
        with certainty may hide the association }
      if FWalkBroken or not FFacts.Complete or FContentMaybe[FSpecNums[I]] or FAFUnsure then
        FIncomplete[par_6_8_4] := True
      else
        SpecFail(par_6_8_4, I, 'file specification in no /AF array');
    end;
    EF := FDoc.DGet(D, 'EF');
    if (EF <> nil) and EF.IsDictLike then
      for K := 0 to High(EFKeys) do
      begin
        S := FDoc.DGet(EF, EFKeys[K]);
        if (S = nil) or (S.Kind <> pok_Stream) then
          Continue;
        Sub := FDoc.DGet(S, 'Subtype');
        if (Sub = nil) or (Sub.Kind <> pok_Name) then
          SpecFail(par_6_8_1, I, 'embedded file without /Subtype')
        else if not IsMimeType(Sub.NameVal) then
          SpecFail(par_6_8_1, I, 'embedded file with /Subtype ' + AsciiText(Sub.NameVal));
      end;
  end;
end;

{ 6.9 on the configurations /D and /Configs of the catalog's /OCProperties:
  a name that is a non-empty string (6.9-1), unique among the configurations
  with /D first (6.9-2; only the later one of two fails), an /Order array
  that names every optional content group of /OCGs (6.9-3; compared by
  name, as veraPDF does), no /AS (6.9-4).
  DE: 6.9 an den Konfigurationen /D und /Configs der /OCProperties des
  Katalogs: ein Name, der ein nicht leerer String ist (6.9-1), eindeutig
  unter den Konfigurationen mit /D zuerst (6.9-2; nur die spaetere von
  zweien ist verletzt), ein /Order-Array, das jede Gruppe optionaler
  Inhalte aus /OCGs nennt (6.9-3; verglichen nach Namen, wie veraPDF es
  tut), kein /AS (6.9-4). }
procedure TLandrixEInvoicePdfARuleCheck.CheckOptionalContent;
var
  OCP, OCGs, G, Configs, C, N, O: TLandrixEInvoicePdfObject;
  Cfgs: array of TLandrixEInvoicePdfObject;
  Groups, Seen: TOcNames;
  Removed: TOcFlags;
  GroupCount, SeenCount, CfgCount, I, K: Integer;
  GroupsOk, HasD, HasName, NameOk: Boolean;
  Name: TLandrixEInvoiceString;
begin
  Groups := nil;
  Seen := nil;
  Cfgs := nil;
  Removed := nil;
  OCP := FDoc.DGet(FDoc.Catalog, 'OCProperties');
  if (OCP = nil) or (OCP.Kind <> pok_Dict) then
    Exit;
  GroupCount := 0;
  GroupsOk := True;
  OCGs := FDoc.DGet(OCP, 'OCGs');
  if (OCGs <> nil) and (OCGs.Kind = pok_Arr) then
    for I := 0 to OCGs.ArrCount - 1 do
    begin
      G := FDoc.Resolve(OCGs.ArrItem(I));
      if (G = nil) or (G.Kind <> pok_Dict) then
        Continue;
      { the name compares count against the /Order work budget }
      Inc(FNodesOc, 1 + GroupCount);
      if (FNodesOc > MaxOcWork) or not OcEntryName(FDoc, G, Name) or not OcAdd(Groups, GroupCount, Name) then
      begin
        GroupsOk := False;
        Break;
      end;
    end;

  CfgCount := 0;
  C := FDoc.DGet(OCP, 'D');
  HasD := (C <> nil) and (C.Kind = pok_Dict);
  Configs := FDoc.DGet(OCP, 'Configs');
  if (Configs <> nil) and (Configs.Kind = pok_Arr) then
    SetLength(Cfgs, Configs.ArrCount + 1)
  else
    SetLength(Cfgs, 1);
  if HasD then
  begin
    Cfgs[0] := C;
    CfgCount := 1;
  end;
  if (Configs <> nil) and (Configs.Kind = pok_Arr) then
    for I := 0 to Configs.ArrCount - 1 do
    begin
      C := FDoc.Resolve(Configs.ArrItem(I));
      if (C <> nil) and (C.Kind = pok_Dict) then
      begin
        Cfgs[CfgCount] := C;
        Inc(CfgCount);
      end;
    end;

  { beyond MaxOcNames configurations the rest stays unchecked }
  if CfgCount > MaxOcNames then
  begin
    CfgCount := MaxOcNames;
    FIncomplete[par_6_9_1] := True;
    FIncomplete[par_6_9_2] := True;
    FIncomplete[par_6_9_3] := True;
    FIncomplete[par_6_9_4] := True;
  end;
  SeenCount := 0;
  for I := 0 to CfgCount - 1 do
  begin
    C := Cfgs[I];
    N := FDoc.DGet(C, 'Name');
    HasName := (N <> nil) and (N.Kind = pok_Str);
    NameOk := True;
    Name := '';
    if HasName then
      NameOk := OcText(N.StrVal, Name);
    if not HasName or (Name = '') then
      FailAt(par_6_9_1, C, 'optional content configuration without a name');
    if HasName then
      if not NameOk then
        FIncomplete[par_6_9_2] := True
      else if not ((I = 0) and HasD) and OcContains(Seen, SeenCount, Name) then
        FailAt(par_6_9_2, C, 'optional content configuration name used twice')
      else if not OcAdd(Seen, SeenCount, Name) then
        FIncomplete[par_6_9_2] := True;

    O := FDoc.DGet(C, 'Order');
    if (O <> nil) and (O.Kind = pok_Arr) then
      if not GroupsOk then
        FIncomplete[par_6_9_3] := True
      else
      begin
        SetLength(Removed, GroupCount);
        for K := 0 to GroupCount - 1 do
          Removed[K] := False;
        if not OcRemoveOrder(FDoc, O, Groups, GroupCount, Removed, FNodesOc, 0) then
          FIncomplete[par_6_9_3] := True
        else
          for K := 0 to GroupCount - 1 do
            if not Removed[K] then
            begin
              FailAt(par_6_9_3, C, 'optional content group missing from /Order');
              Break;
            end;
      end;

    if Known(C, 'AS') then
      FailAt(par_6_9_4, C, 'optional content configuration with /AS');
  end;
end;

{ 6.10-1: no /AlternatePresentations in the name dictionary; 6.11-1: no
  /Requirements in the catalog as veraPDF reads it (an array, or a
  dictionary whose /S is a name).
  DE: 6.10-1: kein /AlternatePresentations im Namens-Dictionary; 6.11-1:
  keine /Requirements im Katalog, wie veraPDF sie liest (ein Array oder ein
  Dictionary, dessen /S ein Name ist). }
procedure TLandrixEInvoicePdfARuleCheck.CheckCatalogLate;
var
  Cat, Names, V, S: TLandrixEInvoicePdfObject;
begin
  Cat := FDoc.Catalog;
  Names := FDoc.DGet(Cat, 'Names');
  if (Names <> nil) and Names.IsDictLike then
  begin
    { a reference to no object counts, one to a null object does not }
    if PresentValue(FDoc, Names.RawGet('AlternatePresentations')) then
      FailAt(par_6_10_1, Names, 'name dictionary with /AlternatePresentations');
  end;
  V := FDoc.DGet(Cat, 'Requirements');
  if V <> nil then
    if V.Kind = pok_Arr then
      FailAt(par_6_11_1, Cat, 'catalog with /Requirements')
    else if V.Kind = pok_Dict then
    begin
      S := FDoc.DGet(V, 'S');
      if (S <> nil) and (S.Kind = pok_Name) then
        FailAt(par_6_11_1, Cat, 'catalog with /Requirements');
    end;
end;

type
  { an ICC header in a string list }
  TIccHeaderBox = class
    H: TLandrixEInvoicePdfIccHeader;
  end;

{ 6.2.3: the output intents of the catalog as veraPDF reads them: every
  dictionary of the /OutputIntents array, in order, whatever its /S;
  references resolve only to the object in use with that number and
  generation. 6.2.3-1: a /DestOutputProfile stream has the device class
  prtr or mntr, the colour space RGB, CMYK or GRAY and a major version below
  5 (header bytes as LandrixEInvoicePdfIccHeader reads them). 6.2.3-2: the
  indirect /DestOutputProfile references (object and generation number,
  resolved or not) are all equal to the first; direct profiles do not
  count; veraPDF reports one failure. 6.2.3-3: an intent whose /S is the
  name GTS_PDFX has no /DestOutputProfileRef (a reference to null counts).
  The colour space of the last /S /GTS_PDFA1 profile becomes gOutputCS
  (empty when its header has none); an intent without a profile stream
  leaves it, a repeated indirect intent sets it again. A repeated indirect
  intent is judged once; a profile shared by intents is judged for each. A
  reference chain too long to follow leaves the three rules and gOutputCS
  undecided.
  DE: 6.2.3: die Output-Intents des Katalogs, wie veraPDF sie liest: jedes
  Dictionary des Arrays /OutputIntents, in Reihenfolge, gleich welches /S;
  Referenzen fuehren nur zum benutzten Objekt mit dieser Nummer und
  Generation. 6.2.3-1: ein /DestOutputProfile-Stream hat die Geraeteklasse
  prtr oder mntr, den Farbraum RGB, CMYK oder GRAY und eine Hauptversion
  unter 5 (Kopfbytes, wie LandrixEInvoicePdfIccHeader sie liest). 6.2.3-2:
  die indirekten /DestOutputProfile-Referenzen (Objekt- und
  Generationsnummer, aufgeloest oder nicht) gleichen alle der ersten;
  direkte Profile zaehlen nicht; veraPDF meldet einen Fehler. 6.2.3-3: ein
  Intent, dessen /S der Name GTS_PDFX ist, hat kein /DestOutputProfileRef
  (eine Referenz auf null zaehlt). Der Farbraum des letzten Profils mit /S
  /GTS_PDFA1 wird gOutputCS (leer, wenn sein Kopf keinen hat); ein Intent
  ohne Profil-Stream laesst ihn stehen, ein wiederholter indirekter Intent
  setzt ihn erneut. Ein wiederholter indirekter Intent wird einmal
  beurteilt; ein Profil, das sich Intents teilen, fuer jeden. Eine
  Referenzkette, die zu lang zum Verfolgen ist, laesst die drei Regeln und
  gOutputCS offen. }
procedure TLandrixEInvoicePdfARuleCheck.CheckOutputIntents;
var
  Arr, Item, Intent, S, Raw, Prof: TLandrixEInvoicePdfObject;
  I, FirstNum, FirstGen: Integer;
  HaveFirst, Differs, IsA, IsX, Once, Unsure, CsKnown: Boolean;
  H: TLandrixEInvoicePdfIccHeader;
  Cs: AnsiString;
  SeenIntent: array of Boolean;
  { the headers read so far, by the profile's position in the document }
  Cache: TStringList;
  Box: TIccHeaderBox;
  K: Integer;
  Key: string;
begin
  FOutputCS := '';
  FOutputCSKnown := True;
  Unsure := False;
  Arr := GenRef(FDoc.Catalog.RawGet('OutputIntents'), Unsure);
  if (Arr = nil) or (Arr.Kind <> pok_Arr) then
  begin
    if Unsure then
    begin
      FIncomplete[par_6_2_3_1] := True;
      FIncomplete[par_6_2_3_2] := True;
      FIncomplete[par_6_2_3_3] := True;
      FOutputCSKnown := False;
    end;
    Exit;
  end;
  Cs := '';
  CsKnown := True;
  HaveFirst := False;
  Differs := False;
  FirstNum := 0;
  FirstGen := 0;
  SeenIntent := nil;
  SetLength(SeenIntent, FDoc.XrefCount);
  for I := 0 to Integer(High(SeenIntent)) do
    SeenIntent[I] := False;
  Cache := TStringList.Create;
  try
    Cache.Sorted := True;
    for I := 0 to Arr.ArrCount - 1 do
    begin
      Item := Arr.ArrItem(I);
      Intent := GenRef(Item, Unsure);
      if (Intent = nil) or not Intent.IsDictLike then
        Continue;
      Once := True;
      if (Item <> nil) and (Item.Kind = pok_Ref) and (Item.RefNum >= 0) and (Item.RefNum <= High(SeenIntent)) then
      begin
        Once := not SeenIntent[Item.RefNum];
        SeenIntent[Item.RefNum] := True;
      end;
      S := GenRef(Intent.RawGet('S'), Unsure);
      IsA := (S <> nil) and (S.Kind = pok_Name) and (S.NameVal = 'GTS_PDFA1');
      IsX := (S <> nil) and (S.Kind = pok_Name) and (S.NameVal = 'GTS_PDFX');
      if Once and IsX and Known(Intent, 'DestOutputProfileRef') then
        FailAt(par_6_2_3_3, Intent, 'PDF/X output intent with /DestOutputProfileRef');
      Raw := Intent.RawGet('DestOutputProfile');
      if (Raw <> nil) and (Raw.Kind = pok_Ref) then
      begin
        if not HaveFirst then
        begin
          HaveFirst := True;
          FirstNum := Raw.RefNum;
          FirstGen := Raw.RefGen;
        end
        else if not Differs and ((Raw.RefNum <> FirstNum) or (Raw.RefGen <> FirstGen)) then
        begin
          Differs := True;
          FailAt(par_6_2_3_2, Intent, 'output profile ' + IntToStr(Raw.RefNum) + ' ' + IntToStr(Raw.RefGen) +
            ' R, the first is ' + IntToStr(FirstNum) + ' ' + IntToStr(FirstGen) + ' R');
        end;
      end;
      Prof := GenRef(Raw, Unsure);
      if (Prof = nil) or (Prof.Kind <> pok_Stream) then
        Continue;
      Key := IntToStr(Prof.Serial);
      if Cache.Find(Key, K) then
        H := TIccHeaderBox(Cache.Objects[K]).H
      else
      begin
        H := LandrixEInvoicePdfIccHeader(FDoc, Prof);
        Box := TIccHeaderBox.Create;
        Box.H := H;
        Cache.AddObject(Key, Box);
      end;
      if not H.Known then
        FIncomplete[par_6_2_3_1] := True
      else if Once and not (((H.DeviceClass = 'prtr') or (H.DeviceClass = 'mntr')) and
        ((H.ColorSpace = 'RGB ') or (H.ColorSpace = 'CMYK') or (H.ColorSpace = 'GRAY')) and (H.Major < 5)) then
        FailAt(par_6_2_3_1, Prof, 'output profile with device class "' + AsciiText(H.DeviceClass) +
          '", colour space "' + AsciiText(H.ColorSpace) + '", major version ' + IntToStr(H.Major));
      if IsA then
      begin
        Cs := H.ColorSpace;
        CsKnown := H.Known;
      end;
    end;
  finally
    for K := 0 to Cache.Count - 1 do
      Cache.Objects[K].Free;
    Cache.Free;
  end;
  if Unsure then
  begin
    FIncomplete[par_6_2_3_1] := True;
    FIncomplete[par_6_2_3_2] := True;
    FIncomplete[par_6_2_3_3] := True;
  end;
  FOutputCS := Cs;
  FOutputCSKnown := not Unsure and CsKnown;
end;

{ A metadata stream as veraPDF accepts one: a stream with the names /Type
  /Metadata and /Subtype /XML. }
function IsMetadataStream(ADoc: TLandrixEInvoicePdfDocument; AObj: TLandrixEInvoicePdfObject): Boolean;
var
  T, S: TLandrixEInvoicePdfObject;
begin
  Result := False;
  if (AObj = nil) or (AObj.Kind <> pok_Stream) then
    Exit;
  T := ADoc.DGet(AObj, 'Type');
  S := ADoc.DGet(AObj, 'Subtype');
  Result := (T <> nil) and (T.Kind = pok_Name) and (T.NameVal = 'Metadata') and (S <> nil) and
    (S.Kind = pok_Name) and (S.NameVal = 'XML');
end;

{ 6.6.2.1-2/-3: the xpacket header as veraPDF searches it: the pattern
  name\s*=\s*'...' or name\s*=\s*"..." anywhere in the data, case-sensitive.
  DE: 6.6.2.1-2/-3: der xpacket-Kopf, wie veraPDF ihn durchsucht: das Muster
  name\s*=\s*'...' oder name\s*=\s*"..." irgendwo in den Daten, mit
  Gross-/Kleinschreibung. }
function HeaderHas(const AHeader, AName: TLandrixEInvoiceString): Boolean;
var
  I, J, K: Integer;
  Q: WideChar;
begin
  Result := False;
  for I := 1 to Length(AHeader) - Length(AName) + 1 do
  begin
    if Copy(AHeader, I, Length(AName)) <> AName then
      Continue;
    J := I + Length(AName);
    while (J <= Length(AHeader)) and ((AHeader[J] = ' ') or (AHeader[J] = #9) or (AHeader[J] = #10) or
      (AHeader[J] = #11) or (AHeader[J] = #12) or (AHeader[J] = #13)) do
      Inc(J);
    if (J > Length(AHeader)) or (AHeader[J] <> '=') then
      Continue;
    Inc(J);
    while (J <= Length(AHeader)) and ((AHeader[J] = ' ') or (AHeader[J] = #9) or (AHeader[J] = #10) or
      (AHeader[J] = #11) or (AHeader[J] = #12) or (AHeader[J] = #13)) do
      Inc(J);
    if (J > Length(AHeader)) or ((AHeader[J] <> '''') and (AHeader[J] <> '"')) then
      Continue;
    Q := AHeader[J];
    for K := J + 1 to Length(AHeader) do
      if AHeader[K] = Q then
      begin
        Result := True;
        Exit;
      end;
  end;
end;

{ 6.6.4-2: pdfaid:part read as veraPDF reads it: an optional sign and
  ASCII digits within 32 bits; False if that gives no number. AUnknown for
  characters beyond ASCII (veraPDF may take other digits too).
  DE: 6.6.4-2: pdfaid:part gelesen wie veraPDF es liest: ein optionales
  Vorzeichen und ASCII-Ziffern innerhalb von 32 Bit; False, wenn das keine
  Zahl ergibt. AUnknown bei Zeichen jenseits von ASCII (veraPDF nimmt
  womoeglich auch andere Ziffern). }
function XmpInteger(const S: TLandrixEInvoiceString; out AValue: Int64; out AUnknown: Boolean): Boolean;
var
  I, Start: Integer;
  Neg: Boolean;
begin
  Result := False;
  AUnknown := False;
  AValue := 0;
  for I := 1 to Length(S) do
    if Word(S[I]) > 127 then
    begin
      AUnknown := True;
      Exit;
    end;
  if S = '' then
    Exit;
  Start := 1;
  Neg := False;
  if (S[1] = '+') or (S[1] = '-') then
  begin
    if Length(S) = 1 then
      Exit;
    Neg := S[1] = '-';
    Start := 2;
  end;
  for I := Start to Length(S) do
  begin
    if (S[I] < '0') or (S[I] > '9') then
      Exit;
    AValue := AValue * 10 + (Int64(Ord(S[I])) - Ord('0'));
    if AValue > 2147483648 then
      Exit;
  end;
  if Neg then
    AValue := -AValue;
  Result := (AValue >= -2147483648) and (AValue <= 2147483647);
end;

function LandrixEInvoicePdfAPartNumber(const AText: TLandrixEInvoiceString): Int64;
var
  Unknown: Boolean;
begin
  if not XmpInteger(AText, Result, Unknown) then
    Result := 0;
end;

{ The rules of 6.6 cannot all be checked. }
procedure TLandrixEInvoicePdfARuleCheck.MarkMetadata;
var
  R: TLandrixEInvoicePdfARule;
begin
  for R := par_6_6_2_1_1 to par_6_6_4_7 do
    FIncomplete[R] := True;
end;

{ 6.6.2.1: a further metadata stream, named by /Metadata of a dictionary
  that is no catalog (the catalog's own stream is the main packet).
  DE: 6.6.2.1: ein weiterer Metadaten-Stream, genannt von /Metadata eines
  Dictionarys, das kein Katalog ist (der Stream des Katalogs ist das
  Hauptpaket). }
procedure TLandrixEInvoicePdfARuleCheck.AddMetadata(ADict: TLandrixEInvoicePdfObject);
var
  Raw, T: TLandrixEInvoicePdfObject;
begin
  Raw := ADict.RawGet('Metadata');
  if (Raw = nil) or (Raw.Kind <> pok_Ref) then
    Exit;
  T := FDoc.DGet(ADict, 'Type');
  if (T <> nil) and (T.Kind = pok_Name) and (T.NameVal = 'Catalog') then
    Exit;
  if (Raw.RefNum < 0) or (Raw.RefNum >= Integer(Length(FMetaSeen))) or FMetaSeen[Raw.RefNum] then
    Exit;
  if not IsMetadataStream(FDoc, FDoc.Resolve(Raw)) then
    Exit;
  FMetaSeen[Raw.RefNum] := True;
  if FMetaCount = Integer(Length(FMetaNums)) then
    SetLength(FMetaNums, 16 + 2 * FMetaCount);
  FMetaNums[FMetaCount] := Raw.RefNum;
  Inc(FMetaCount);
end;

{ 6.6.2.1-2 to -5 on one packet: a packet veraPDF rejects has no header and
  no encoding (-4 and -5 fail); an unknown one leaves the rules incomplete.
  DE: 6.6.2.1-2 bis -5 an einem Paket: ein Paket, das veraPDF ablehnt, hat
  weder Kopf noch Encoding (-4 und -5 verletzt); ein unbekanntes laesst die
  Regeln unvollstaendig. }
procedure TLandrixEInvoicePdfARuleCheck.JudgePacket(APacket: TLandrixEInvoiceXmpPacket; ANum: Integer);
var
  Gen: Integer;
  Where: string;
begin
  Gen := FDoc.XrefEntry(ANum).Gen;
  Where := 'object ' + IntToStr(ANum) + ': ';
  case APacket.State of
    xms_Unknown:
      begin
        FIncomplete[par_6_6_2_1_2] := True;
        FIncomplete[par_6_6_2_1_3] := True;
        FIncomplete[par_6_6_2_1_4] := True;
        FIncomplete[par_6_6_2_1_5] := True;
      end;
    xms_Invalid:
      begin
        Fail(par_6_6_2_1_4, ANum, Gen, pss_File, -1, Where + 'XMP packet not valid: ' + APacket.Reason);
        Fail(par_6_6_2_1_5, ANum, Gen, pss_File, -1, Where + 'XMP packet not valid, no encoding');
      end;
  else
    begin
      if APacket.HasHeader and HeaderHas(APacket.Header, 'bytes') then
        Fail(par_6_6_2_1_2, ANum, Gen, pss_File, -1, Where + 'xpacket header with bytes');
      if APacket.HasHeader and HeaderHas(APacket.Header, 'encoding') then
        Fail(par_6_6_2_1_3, ANum, Gen, pss_File, -1, Where + 'xpacket header with encoding');
      if not APacket.HasRoot then
        Fail(par_6_6_2_1_5, ANum, Gen, pss_File, -1, Where + 'XMP packet without rdf:RDF, no encoding')
      else if APacket.Encoding <> 'UTF-8' then
        Fail(par_6_6_2_1_5, ANum, Gen, pss_File, -1, Where + 'XMP packet encoded as ' + APacket.Encoding);
    end;
  end;
end;

{ 6.6.4 on the main packet: a pdfaid property at the top level; part 3 (a
  simple value read as an integer), conformance A, B or U; the prefix
  written for part, conformance, amd and corr is pdfaid or none.
  DE: 6.6.4 am Hauptpaket: eine pdfaid-Eigenschaft auf oberster Ebene; part
  3 (ein einfacher Wert, als Ganzzahl gelesen), conformance A, B
  oder U; das fuer part, conformance, amd und corr geschriebene Praefix ist
  pdfaid oder keines. }
procedure TLandrixEInvoicePdfARuleCheck.JudgeIdentification(APacket: TLandrixEInvoiceXmpPacket; ANum: Integer);
const
  Names: array[0..3] of string = ('part', 'conformance', 'amd', 'corr');
var
  Gen, I: Integer;
  Where: string;
  Any, Unknown, IsInt: Boolean;
  P: TLandrixEInvoiceXmpNode;
  Part: Int64;
begin
  Gen := FDoc.XrefEntry(ANum).Gen;
  Where := 'object ' + IntToStr(ANum) + ': ';
  if APacket.State = xms_Unknown then
  begin
    for I := Ord(par_6_6_4_1) to Ord(par_6_6_4_7) do
      FIncomplete[TLandrixEInvoicePdfARule(I)] := True;
    Exit;
  end;
  Any := False;
  if APacket.State = xms_Valid then
    for I := 0 to APacket.PropertyCount - 1 do
      if APacket.Prop(I).Ns = LandrixEInvoiceXmpNsPdfaId then
        Any := True;
  if not Any then
  begin
    Fail(par_6_6_4_1, ANum, Gen, pss_File, -1, Where + 'no PDF/A identification (pdfaid)');
    Exit;
  end;
  Unknown := False;
  P := APacket.Find(LandrixEInvoiceXmpNsPdfaId, 'part');
  Part := 0;
  IsInt := (P <> nil) and (P.Kind = xmk_Simple) and XmpInteger(P.Value, Part, Unknown);
  if IsInt then
    FClaimedPart := Part;
  if not IsInt or (Part <> 3) then
  begin
    if (P <> nil) and (P.Kind = xmk_Simple) and Unknown then
      FIncomplete[par_6_6_4_2] := True
    else if P = nil then
      Fail(par_6_6_4_2, ANum, Gen, pss_File, -1, Where + 'no pdfaid:part')
    else
      Fail(par_6_6_4_2, ANum, Gen, pss_File, -1, Where + 'pdfaid:part ' + WideAscii(P.Value));
  end;
  P := APacket.Find(LandrixEInvoiceXmpNsPdfaId, 'conformance');
  if (P = nil) or (P.Kind <> xmk_Simple) or ((P.Value <> 'A') and (P.Value <> 'B') and (P.Value <> 'U')) then
    if P = nil then
      Fail(par_6_6_4_3, ANum, Gen, pss_File, -1, Where + 'no pdfaid:conformance')
    else
      Fail(par_6_6_4_3, ANum, Gen, pss_File, -1, Where + 'pdfaid:conformance ' + WideAscii(P.Value));
  for I := 0 to 3 do
  begin
    P := APacket.Find(LandrixEInvoiceXmpNsPdfaId, TLandrixEInvoiceString(Names[I]));
    if (P <> nil) and (P.Prefix <> '') and (P.Prefix <> 'pdfaid') then
      Fail(TLandrixEInvoicePdfARule(Ord(par_6_6_4_4) + I), ANum, Gen, pss_File, -1,
        Where + 'pdfaid:' + Names[I] + ' with the prefix ' + WideAscii(P.Prefix));
  end;
end;

{ The extension schema rules cannot be decided for a packet.
  DE: Die Regeln der Erweiterungsschemas sind fuer ein Paket nicht
  entscheidbar. }
procedure TLandrixEInvoicePdfARuleCheck.MarkExtension;
var
  R: TLandrixEInvoicePdfARule;
begin
  for R := par_6_6_2_3_1_1 to par_6_6_2_3_3_18 do
    FIncomplete[R] := True;
end;

const
  { most XMP properties judged for 6.6.2.3.1, most occurrences looked up }
  MaxXmpProperties = 4096;
  MaxXmpOccurrences = 200000;

{ 6.6.2.3.1 on one packet: every top-level property except
  pdfaExtension:schemas. -1: predefined (XMP 2005 chapter 4, pdfaid) or
  defined by an extension schema of this packet or of the main packet
  (AMainTypes, for a further packet). -2: its value fits the type of the
  first definition in the order this packet, main packet, predefined; a
  property defined nowhere fails both. veraPDF judges a property (namespace,
  written prefix, name) once over all packets; which occurrence is not
  established, so the answers of all occurrences are kept and only an
  agreeing one counts (ReportProperties).
  DE: 6.6.2.3.1 an einem Paket: jede Eigenschaft der obersten Ebene ausser
  pdfaExtension:schemas. -1: vordefiniert (XMP 2005 Kapitel 4, pdfaid) oder
  von einem Erweiterungsschema dieses Pakets oder des Hauptpakets definiert
  (AMainTypes, fuer ein weiteres Paket). -2: ihr Wert passt zum Typ der
  ersten Definition in der Reihenfolge dieses Paket, Hauptpaket,
  vordefiniert; eine nirgends definierte Eigenschaft verletzt beide.
  veraPDF beurteilt eine Eigenschaft (Namensraum, geschriebenes Praefix,
  Name) einmal ueber alle Pakete; welches Vorkommen, ist nicht belegt,
  daher zaehlt nur eine Antwort, in der alle Vorkommen uebereinstimmen
  (ReportProperties). }
procedure TLandrixEInvoicePdfARuleCheck.JudgeProperties(APacket: TLandrixEInvoiceXmpPacket; ANum: Integer;
  ATypes, AMainTypes: TLandrixEInvoiceXmpSchemaTypes);
var
  I, J, E, E2: Integer;
  P: TLandrixEInvoiceXmpNode;
  T, T2, Id: TLandrixEInvoiceString;
  Lax: Boolean;
  Defined, Valid, Here, Main: TLandrixEInvoiceXmpTruth;
begin
  case APacket.State of
    xms_Unknown:
      begin
        FIncomplete[par_6_6_2_3_1_1] := True;
        FIncomplete[par_6_6_2_3_1_2] := True;
        Exit;
      end;
    xms_Invalid:
      Exit;
  else
    ;
  end;
  for I := 0 to APacket.PropertyCount - 1 do
  begin
    P := APacket.Prop(I);
    if (P.Ns = LandrixEInvoiceXmpNsPdfaExtension) and (P.Local = 'schemas') then
      Continue;
    Inc(FPropWork);
    if FPropWork > MaxXmpOccurrences then
    begin
      FIncomplete[par_6_6_2_3_1_1] := True;
      FIncomplete[par_6_6_2_3_1_2] := True;
      Exit;
    end;
    { this packet, then the main packet, then the predefined properties }
    Here := ATypes.Defines(P.Ns, P.Local, T, E);
    Main := xmt_No;
    if AMainTypes <> nil then
      Main := AMainTypes.Defines(P.Ns, P.Local, T2, E2);
    if Here = xmt_Yes then
      Valid := ATypes.Validate(P, T, E)
    else if Here = xmt_Unknown then
      Valid := xmt_Unknown
    else
    begin
      T := T2;
      E := E2;
      if Main = xmt_Yes then
        Valid := AMainTypes.Validate(P, T, E)
      else if Main = xmt_Unknown then
        Valid := xmt_Unknown
      else if LandrixEInvoiceXmpPredefined(P.Ns, P.Local, T, Lax) then
      begin
        Valid := ATypes.Validate(P, T, LandrixEInvoiceXmpPredefinedEntry);
        if Lax and (Valid = xmt_No) then
          Valid := xmt_Unknown;
      end
      else
        Valid := xmt_No;
    end;
    if (Here = xmt_Yes) or (Main = xmt_Yes) or LandrixEInvoiceXmpPredefined(P.Ns, P.Local, T, Lax) then
      Defined := xmt_Yes
    else if (Here = xmt_Unknown) or (Main = xmt_Unknown) then
      Defined := xmt_Unknown
    else
      Defined := xmt_No;
    { one answer per property over all packets }
    Id := P.Ns + #1 + P.Prefix + #1 + P.Local;
    J := 0;
    while (J < FPropCount) and (FPropIds[J] <> Id) do
      Inc(J);
    if J < FPropCount then
    begin
      if FPropDefined[J] <> Defined then
        FPropDefined[J] := xmt_Unknown;
      if FPropValid[J] <> Valid then
        FPropValid[J] := xmt_Unknown;
      Continue;
    end;
    if FPropCount >= MaxXmpProperties then
    begin
      FIncomplete[par_6_6_2_3_1_1] := True;
      FIncomplete[par_6_6_2_3_1_2] := True;
      Exit;
    end;
    if FPropCount = Integer(Length(FPropIds)) then
    begin
      SetLength(FPropIds, 16 + 2 * FPropCount);
      SetLength(FPropDefined, Length(FPropIds));
      SetLength(FPropValid, Length(FPropIds));
      SetLength(FPropNums, Length(FPropIds));
      SetLength(FPropNames, Length(FPropIds));
    end;
    FPropIds[FPropCount] := Id;
    FPropDefined[FPropCount] := Defined;
    FPropValid[FPropCount] := Valid;
    FPropNums[FPropCount] := ANum;
    FPropNames[FPropCount] := WideAscii(P.Lexical);
    Inc(FPropCount);
  end;
end;

{ 6.6.2.3.1: the answers of all packets. DE: 6.6.2.3.1: die Antworten
  aller Pakete. }
procedure TLandrixEInvoicePdfARuleCheck.ReportProperties;
var
  I: Integer;
  Where: string;
  Partial: Boolean;
begin
  { a packet that was not judged (not decided, a limit, a walk cut short,
    syntax not read completely) may hold an occurrence of a property that
    veraPDF judges instead }
  Partial := FIncomplete[par_6_6_2_3_1_1] or FIncomplete[par_6_6_2_3_1_2] or FWalkBroken or
    not FFacts.Complete;
  for I := 0 to FPropCount - 1 do
  begin
    if Partial then
    begin
      if FPropDefined[I] = xmt_No then
        FPropDefined[I] := xmt_Unknown;
      if FPropValid[I] = xmt_No then
        FPropValid[I] := xmt_Unknown;
    end;
    Where := 'object ' + IntToStr(FPropNums[I]) + ': ' + FPropNames[I];
    case FPropDefined[I] of
      xmt_No:
        Fail(par_6_6_2_3_1_1, FPropNums[I], FDoc.XrefEntry(FPropNums[I]).Gen, pss_File, -1,
          Where + ' is neither predefined nor defined by an extension schema');
      xmt_Unknown:
        FIncomplete[par_6_6_2_3_1_1] := True;
    else
      ;
    end;
    case FPropValid[I] of
      xmt_No:
        Fail(par_6_6_2_3_1_2, FPropNums[I], FDoc.XrefEntry(FPropNums[I]).Gen, pss_File, -1,
          Where + ' has no value of its defined type');
      xmt_Unknown:
        FIncomplete[par_6_6_2_3_1_2] := True;
    else
      ;
    end;
  end;
end;

{ A required field of an extension schema structure: present, a simple
  value (veraPDF's Text and URI types take any simple value) and written with
  APrefix. }
function XmpTextOk(AField: TLandrixEInvoiceXmpNode; const APrefix: TLandrixEInvoiceString): Boolean;
begin
  Result := (AField <> nil) and (AField.Kind = xmk_Simple) and (AField.Prefix = APrefix);
end;

{ An optional Seq field: absent, or an ordered array (Seq or Alt) written
  without a prefix or with APrefix. }
function XmpSeqOk(AField: TLandrixEInvoiceXmpNode; const APrefix: TLandrixEInvoiceString): Boolean;
begin
  Result := (AField = nil) or ((AField.Kind = xmk_Array) and (AField.ArrayForm in [xma_Seq, xma_Alt]) and
    ((AField.Prefix = '') or (AField.Prefix = APrefix)));
end;

{ 6.6.2.3.2-1: a field of another namespace or a name not in ANames. }
function XmpUndefinedField(AItem: TLandrixEInvoiceXmpNode; const ANs: TLandrixEInvoiceString;
  const ANames: array of string): Boolean;
var
  I, J: Integer;
  Found: Boolean;
begin
  Result := False;
  for I := 0 to AItem.ChildCount - 1 do
  begin
    Found := False;
    if AItem.Child(I).Ns = ANs then
      for J := 0 to Integer(High(ANames)) do
        if AItem.Child(I).Local = TLandrixEInvoiceString(ANames[J]) then
          Found := True;
    if not Found then
    begin
      Result := True;
      Exit;
    end;
  end;
end;

{ 6.6.2.3.2 and 6.6.2.3.3 on one valid packet, as veraPDF builds its
  objects: the top-level pdfaExtension:schemas is the container (whatever its
  form); if it is an array, each item is a schema, each item of an array
  pdfaSchema:property a property, of an array pdfaSchema:valueType a value
  type, of an array pdfaType:field a field (items need not be structures).
  Fields are found by namespace and local name; the prefix tested is the one
  written. A property's or field's value type must be known to the schema's
  namespace (ATypes).
  DE: 6.6.2.3.2 und 6.6.2.3.3 an einem gueltigen Paket, wie veraPDF seine
  Objekte bildet: das pdfaExtension:schemas der obersten Ebene ist der
  Container (gleich welcher Form); ist es ein Array, ist jedes Element ein
  Schema, jedes Element eines Arrays pdfaSchema:property eine Eigenschaft,
  eines Arrays pdfaSchema:valueType ein Werttyp, eines Arrays pdfaType:field
  ein Feld (Elemente muessen keine Strukturen sein). Felder werden nach
  Namensraum und lokalem Namen gefunden; geprueft wird das geschriebene
  Praefix. Der Werttyp einer Eigenschaft oder eines Felds muss dem
  Namensraum des Schemas bekannt sein (ATypes). }
procedure TLandrixEInvoicePdfARuleCheck.JudgeExtension(APacket: TLandrixEInvoiceXmpPacket; ANum: Integer;
  ATypes: TLandrixEInvoiceXmpSchemaTypes);
const
  NsS = LandrixEInvoiceXmpNsPdfaSchema;
  NsP = LandrixEInvoiceXmpNsPdfaProperty;
  NsT = LandrixEInvoiceXmpNsPdfaType;
  NsF = LandrixEInvoiceXmpNsPdfaField;
var
  Gen: Integer;
  Where: string;
  C, D, L, P, T, F, V: TLandrixEInvoiceXmpNode;
  I, J, K, Entry: Integer;

  procedure Bad(ARule: TLandrixEInvoicePdfARule; const AText: string);
  begin
    Fail(ARule, ANum, Gen, pss_File, -1, Where + AText);
  end;

  procedure Known(ARule: TLandrixEInvoicePdfARule; AField: TLandrixEInvoiceXmpNode;
    const APrefix: TLandrixEInvoiceString; const AName: string);
  begin
    if not XmpTextOk(AField, APrefix) then
      Bad(ARule, AName + ' missing, not a text or with another prefix')
    else
      case ATypes.IsKnown(Entry, AField.Value) of
        xmt_No:
          Bad(ARule, AName + ' ' + WideAscii(AField.Value) + ' is no known type');
        xmt_Unknown:
          FIncomplete[ARule] := True;
      else
        ;
      end;
  end;

begin
  Gen := FDoc.XrefEntry(ANum).Gen;
  case APacket.State of
    xms_Unknown:
      begin
        MarkExtension;
        Exit;
      end;
    xms_Invalid:
      Exit;
  else
    ;
  end;
  C := APacket.Find(LandrixEInvoiceXmpNsPdfaExtension, 'schemas');
  if C = nil then
    Exit;
  Where := 'object ' + IntToStr(ANum) + ': pdfaExtension:schemas';
  if (C.Kind <> xmk_Array) or (C.ArrayForm <> xma_Bag) or (C.Prefix <> 'pdfaExtension') then
    Bad(par_6_6_2_3_3_1, ' not a Bag or with another prefix');
  if C.Kind <> xmk_Array then
    Exit;
  for I := 0 to C.ChildCount - 1 do
  begin
    D := C.Child(I);
    Where := 'object ' + IntToStr(ANum) + ': pdfaExtension:schemas item ' + IntToStr(I + 1) + ': ';
    { the schema's entry by its namespace URI; veraPDF reads a structure or
      an array there as '' }
    V := D.FindChild(NsS, 'namespaceURI');
    if (V <> nil) and (V.Kind = xmk_Simple) then
      Entry := ATypes.Entry(V.Value, True)
    else
      Entry := ATypes.Entry('', V <> nil);
    if XmpUndefinedField(D, NsS, ['schema', 'namespaceURI', 'prefix', 'property', 'valueType']) then
      Bad(par_6_6_2_3_2_1, 'a field outside the PDF/A Schema value type');
    if not XmpTextOk(D.FindChild(NsS, 'schema'), 'pdfaSchema') then
      Bad(par_6_6_2_3_3_2, 'pdfaSchema:schema missing, not a text or with another prefix');
    if not XmpTextOk(D.FindChild(NsS, 'namespaceURI'), 'pdfaSchema') then
      Bad(par_6_6_2_3_3_3, 'pdfaSchema:namespaceURI missing, not a URI or with another prefix');
    if not XmpTextOk(D.FindChild(NsS, 'prefix'), 'pdfaSchema') then
      Bad(par_6_6_2_3_3_4, 'pdfaSchema:prefix missing, not a text or with another prefix');
    L := D.FindChild(NsS, 'property');
    if not XmpSeqOk(L, 'pdfaSchema') then
      Bad(par_6_6_2_3_3_5, 'pdfaSchema:property not an ordered array (Seq or Alt) or with another prefix');
    if (L <> nil) and (L.Kind = xmk_Array) then
      for J := 0 to L.ChildCount - 1 do
      begin
        P := L.Child(J);
        Where := 'object ' + IntToStr(ANum) + ': pdfaExtension:schemas item ' + IntToStr(I + 1) + ' property ' +
          IntToStr(J + 1) + ': ';
        if XmpUndefinedField(P, NsP, ['name', 'valueType', 'category', 'description']) then
          Bad(par_6_6_2_3_2_1, 'a field outside the PDF/A Property value type');
        if not XmpTextOk(P.FindChild(NsP, 'name'), 'pdfaProperty') then
          Bad(par_6_6_2_3_3_7, 'pdfaProperty:name missing, not a text or with another prefix');
        Known(par_6_6_2_3_3_8, P.FindChild(NsP, 'valueType'), 'pdfaProperty', 'pdfaProperty:valueType');
        F := P.FindChild(NsP, 'category');
        if not XmpTextOk(F, 'pdfaProperty') or ((F.Value <> 'external') and (F.Value <> 'internal')) then
          Bad(par_6_6_2_3_3_9, 'pdfaProperty:category missing, not external or internal or with another prefix');
        if not XmpTextOk(P.FindChild(NsP, 'description'), 'pdfaProperty') then
          Bad(par_6_6_2_3_3_10, 'pdfaProperty:description missing, not a text or with another prefix');
      end;
    Where := 'object ' + IntToStr(ANum) + ': pdfaExtension:schemas item ' + IntToStr(I + 1) + ': ';
    L := D.FindChild(NsS, 'valueType');
    if not XmpSeqOk(L, 'pdfaSchema') then
      Bad(par_6_6_2_3_3_6, 'pdfaSchema:valueType not an ordered array (Seq or Alt) or with another prefix');
    if (L <> nil) and (L.Kind = xmk_Array) then
      for J := 0 to L.ChildCount - 1 do
      begin
        T := L.Child(J);
        Where := 'object ' + IntToStr(ANum) + ': pdfaExtension:schemas item ' + IntToStr(I + 1) + ' value type ' +
          IntToStr(J + 1) + ': ';
        if XmpUndefinedField(T, NsT, ['type', 'namespaceURI', 'prefix', 'description', 'field']) then
          Bad(par_6_6_2_3_2_1, 'a field outside the PDF/A ValueType value type');
        if not XmpTextOk(T.FindChild(NsT, 'type'), 'pdfaType') then
          Bad(par_6_6_2_3_3_11, 'pdfaType:type missing, not a text or with another prefix');
        if not XmpTextOk(T.FindChild(NsT, 'namespaceURI'), 'pdfaType') then
          Bad(par_6_6_2_3_3_12, 'pdfaType:namespaceURI missing, not a URI or with another prefix');
        if not XmpTextOk(T.FindChild(NsT, 'prefix'), 'pdfaType') then
          Bad(par_6_6_2_3_3_13, 'pdfaType:prefix missing, not a text or with another prefix');
        if not XmpTextOk(T.FindChild(NsT, 'description'), 'pdfaType') then
          Bad(par_6_6_2_3_3_14, 'pdfaType:description missing, not a text or with another prefix');
        V := T.FindChild(NsT, 'field');
        if not XmpSeqOk(V, 'pdfaType') then
          Bad(par_6_6_2_3_3_15, 'pdfaType:field not an ordered array (Seq or Alt) or with another prefix');
        if (V <> nil) and (V.Kind = xmk_Array) then
          for K := 0 to V.ChildCount - 1 do
          begin
            F := V.Child(K);
            Where := 'object ' + IntToStr(ANum) + ': pdfaExtension:schemas item ' + IntToStr(I + 1) +
              ' value type ' + IntToStr(J + 1) + ' field ' + IntToStr(K + 1) + ': ';
            if XmpUndefinedField(F, NsF, ['name', 'valueType', 'description']) then
              Bad(par_6_6_2_3_2_1, 'a field outside the PDF/A Field value type');
            if not XmpTextOk(F.FindChild(NsF, 'name'), 'pdfaField') then
              Bad(par_6_6_2_3_3_16, 'pdfaField:name missing, not a text or with another prefix');
            Known(par_6_6_2_3_3_17, F.FindChild(NsF, 'valueType'), 'pdfaField', 'pdfaField:valueType');
            if not XmpTextOk(F.FindChild(NsF, 'description'), 'pdfaField') then
              Bad(par_6_6_2_3_3_18, 'pdfaField:description missing, not a text or with another prefix');
          end;
      end;
  end;
end;

{ 6.6.2.1, 6.6.2.3 and 6.6.4 as veraPDF reads them: the catalog's metadata
  stream is the main packet (6.6.2.1-1, and the only one 6.6.4 judges);
  every stream a further dictionary names by /Metadata is a packet for
  6.6.2.1-2 to -5 and 6.6.2.3. veraPDF reads such a packet together with the
  catalog's stream: when that is not valid, the further packets are not
  judged. When the catalog's stream is not a proper metadata stream, veraPDF
  still reads it for the further packets; this check then leaves their
  rules incomplete. A stream that is both the main and a further packet is
  judged once and 6.6.4 left incomplete (veraPDF then skips it).
  DE: 6.6.2.1, 6.6.2.3 und 6.6.4, wie veraPDF sie liest: der
  Metadaten-Stream des Katalogs ist das Hauptpaket (6.6.2.1-1 und das
  einzige, das 6.6.4 beurteilt); jeder Stream, den ein weiteres Dictionary
  mit /Metadata nennt, ist ein Paket fuer 6.6.2.1-2 bis -5 und 6.6.2.3.
  veraPDF liest ein solches Paket zusammen mit dem Stream des Katalogs: ist
  der nicht gueltig, werden die weiteren Pakete nicht beurteilt. Ist der
  Stream des Katalogs kein richtiger Metadaten-Stream, liest veraPDF ihn fuer
  die weiteren Pakete trotzdem; diese Pruefung laesst deren Regeln dann
  unvollstaendig.
  Ein Stream, der Haupt- und weiteres Paket ist, wird einmal beurteilt und
  6.6.4 bleibt unvollstaendig (veraPDF ueberspringt es dann). }
procedure TLandrixEInvoicePdfARuleCheck.CheckMetadata;
var
  Cat, Raw, M: TLandrixEInvoicePdfObject;
  MainNum, I: Integer;
  MainOk, Shared, HasMain: Boolean;
  Packet: TLandrixEInvoiceXmpPacket;
  Data: TLandrixEInvoicePdfBytes;
  MainTypes, Types: TLandrixEInvoiceXmpSchemaTypes;
begin
  Cat := FDoc.Catalog;
  if Cat = nil then
  begin
    MarkMetadata;
    Exit;
  end;
  if FWalkBroken then
  begin
    FIncomplete[par_6_6_2_1_2] := True;
    FIncomplete[par_6_6_2_1_3] := True;
    FIncomplete[par_6_6_2_1_4] := True;
    FIncomplete[par_6_6_2_1_5] := True;
    MarkExtension;
  end;
  MainTypes := nil;
  Types := nil;
  Packet := TLandrixEInvoiceXmpPacket.Create;
  try
    MainTypes := TLandrixEInvoiceXmpSchemaTypes.Create;
    Types := TLandrixEInvoiceXmpSchemaTypes.Create;
    MainNum := -1;
    HasMain := Cat.RawGet('Metadata') <> nil;
    MainOk := not HasMain;
    Raw := Cat.RawGet('Metadata');
    M := FDoc.DGet(Cat, 'Metadata');
    if not IsMetadataStream(FDoc, M) or (Raw.Kind <> pok_Ref) then
      FailAt(par_6_6_2_1_1, Cat, 'catalog without a metadata stream /Type /Metadata /Subtype /XML')
    else
    begin
      MainNum := Raw.RefNum;
      { a walk cut short may have missed a dictionary that shares the
        catalog's stream }
      Shared := FWalkBroken or ((MainNum < Integer(Length(FMetaSeen))) and FMetaSeen[MainNum]);
      if FDoc.GetStreamData(M, Data) then
        Packet.Parse(Data)
      else
        Packet.Parse(nil);
      JudgePacket(Packet, MainNum);
      if Shared then
      begin
        for I := Ord(par_6_6_4_1) to Ord(par_6_6_4_7) do
          FIncomplete[TLandrixEInvoicePdfARule(I)] := True;
      end
      else
        JudgeIdentification(Packet, MainNum);
      MainTypes.Build(Packet, nil, False);
      JudgeExtension(Packet, MainNum, MainTypes);
      JudgeProperties(Packet, MainNum, MainTypes, nil);
      MainOk := Packet.State = xms_Valid;
    end;
    for I := 0 to FMetaCount - 1 do
    begin
      if FMetaNums[I] = MainNum then
        Continue;
      if not MainOk or (I >= MaxMetaPackets) then
      begin
        FIncomplete[par_6_6_2_1_2] := True;
        FIncomplete[par_6_6_2_1_3] := True;
        FIncomplete[par_6_6_2_1_4] := True;
        FIncomplete[par_6_6_2_1_5] := True;
        MarkExtension;
        Break;
      end;
      if FDoc.GetStreamData(FDoc.GetObject(FMetaNums[I]), Data) then
        Packet.Parse(Data)
      else
        Packet.Parse(nil);
      JudgePacket(Packet, FMetaNums[I]);
      { a further packet starts from the main packet's types (none without
        a catalog stream) }
      if HasMain then
        Types.Build(Packet, MainTypes, True)
      else
        Types.Build(Packet, nil, True);
      JudgeExtension(Packet, FMetaNums[I], Types);
      if HasMain then
        JudgeProperties(Packet, FMetaNums[I], Types, MainTypes)
      else
        JudgeProperties(Packet, FMetaNums[I], Types, nil);
    end;
    ReportProperties;
  finally
    Types.Free;
    MainTypes.Free;
    Packet.Free;
  end;
end;

{ 6.1.13-11 on a box array as veraPDF reads it: the first four entries, a
  missing one, a reference or one that is no number as 0; AOwner is the
  page or node the box is written in.
  DE: 6.1.13-11 an einem Box-Array, wie veraPDF es liest: die ersten vier
  Eintraege, ein fehlender, eine Referenz oder einer, der keine Zahl ist,
  als 0; AOwner ist die Seite oder der Knoten, in dem die Box steht. }
procedure TLandrixEInvoicePdfARuleCheck.CheckBox(ABox: TLandrixEInvoicePdfObject; const AName: string;
  AOwner: TLandrixEInvoicePdfObject);
var
  V: array[0..3] of Double;
  I: Integer;
  O: TLandrixEInvoicePdfObject;
  W, H: Double;
begin
  if (ABox = nil) or (ABox.Kind <> pok_Arr) then
    Exit;
  for I := 0 to 3 do
  begin
    V[I] := 0;
    if I < ABox.ArrCount then
    begin
      O := ABox.ArrItem(I);
      if (O <> nil) and (O.Kind = pok_Num) then
        V[I] := O.NumVal;
    end;
  end;
  W := Abs(V[2] - V[0]);
  H := Abs(V[3] - V[1]);
  if (W < 3) or (W > 14400) or (H < 3) or (H > 14400) then
    FailAt(par_6_1_13_11, AOwner, AName + ' outside 3 to 14400 units');
end;

end.
