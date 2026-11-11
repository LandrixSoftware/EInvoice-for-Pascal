{
  EInvoice-for-Pascal

  Copyright (C) 2026 Landrix Software GmbH & Co. KG

  This file is dual-licensed under:
  - GNU GPL version 3 or later; or
  - the Landrix Software Commercial License.

  See LICENSE and COMMERCIAL-LICENSE.md.

  SPDX-License-Identifier: GPL-3.0-or-later OR LicenseRef-Landrix-Commercial
}

{ Checks of a hybrid invoice PDF (ZUGFeRD 2.5.2 / Factur-X 1.09.2), levels
  2 and 3. Level 2, the embedding of the invoice XML: the business rules for hybrid
  documents of the specification (annex 3.d) BR-HYBRID-12 (embedding
  method, a collective rule: several findings share it), BR-HYBRID-13 (file
  name) and BR-HYBRID-11 (/AFRelationship, without profile and country only
  the values the table allows at all), plus own findings LX-PDF-01 to
  LX-PDF-10 for what the rules do not name. The checker reads no XML except
  for well-formedness: the caller reads the extracted invoice through the
  facade and passes its target and countries to CheckInvoiceFacts, which
  adds BR-HYBRID-11 per profile and country, BR-HYBRID-13 (file name and
  profile), BR-HYBRID-DE-01/02 and BR-HYBRID-FR-01; these need the PDF
  context and therefore belong to level 2. ZUGFeRD 1.0 and 2.0 are
  recognised and extracted, not checked. A rebuilt object table or a
  reached limit never gives eps_Passed. Damaged or hostile input is a
  finding, not an exception.

  Level 3, the XMP metadata of the catalog, runs when level 2 found a
  Factur-X or XRechnung invoice: BR-HYBRID-02 (the PDF/A part the XMP
  claims; the conformance itself is level 1), BR-HYBRID-03 to -05
  (extension schema, namespace, prefix fx), BR-HYBRID-06 to -10
  (fx:DocumentType, fx:ConformanceLevel, fx:DocumentFileName, fx:Version
  against their code lists), BR-HYBRID-14 (fx:DocumentFileName and the
  embedded name) and LX-PDF-11 (no readable XMP); CheckInvoiceFacts adds
  BR-HYBRID-15 (fx:ConformanceLevel and the profile of the invoice). Paths
  of level 3 findings start with "XMP " or are /Root/Metadata. Every level
  has its own status; ZUGFeRD 1.0 and 2.0 leave level 3 eps_Incomplete.

  DE: Pruefungen eines hybriden Rechnungs-PDFs (ZUGFeRD 2.5.2 / Factur-X
  1.09.2), Ebenen 2 und 3. Ebene 2, die Einbettung der Rechnungs-XML: die
  Geschaeftsregeln fuer hybride Dokumente der Spezifikation (Anhang 3.d)
  BR-HYBRID-12 (Einbettungsmethode, eine Sammelregel: mehrere Befunde
  teilen sie), BR-HYBRID-13 (Dateiname) und BR-HYBRID-11
  (/AFRelationship, ohne Profil und Land nur die Werte, die die Tabelle
  ueberhaupt erlaubt), dazu eigene Befunde LX-PDF-01 bis LX-PDF-10 fuer
  das, was die Regeln nicht nennen. Der Pruefer liest keine XML ausser auf
  Wohlgeformtheit: der Aufrufer liest die extrahierte Rechnung ueber die
  Fassade und uebergibt ihr Ziel und ihre Laender an CheckInvoiceFacts, das
  BR-HYBRID-11 je Profil und Land, BR-HYBRID-13 (Dateiname und Profil),
  BR-HYBRID-DE-01/02 und BR-HYBRID-FR-01 ergaenzt; sie brauchen den
  PDF-Zusammenhang und gehoeren deshalb zu Ebene 2. ZUGFeRD 1.0 und 2.0
  werden erkannt und extrahiert, nicht geprueft. Eine neu aufgebaute
  Objekttabelle oder eine erreichte Grenze ergibt nie eps_Passed.
  Beschaedigte oder feindliche Eingaben sind ein Befund, keine Ausnahme.

  Ebene 3, die XMP-Metadaten des Katalogs, laeuft, wenn Ebene 2 eine
  Factur-X- oder XRechnung-Rechnung gefunden hat: BR-HYBRID-02 (der
  PDF/A-Teil, den das XMP behauptet; die Konformitaet selbst ist Ebene 1),
  BR-HYBRID-03 bis -05 (Erweiterungsschema, Namensraum, Praefix fx),
  BR-HYBRID-06 bis -10 (fx:DocumentType, fx:ConformanceLevel,
  fx:DocumentFileName, fx:Version gegen ihre Codelisten), BR-HYBRID-14
  (fx:DocumentFileName und der eingebettete Name) und LX-PDF-11 (kein
  lesbares XMP); CheckInvoiceFacts ergaenzt BR-HYBRID-15
  (fx:ConformanceLevel und das Profil der Rechnung). Pfade von Befunden der
  Ebene 3 beginnen mit "XMP " oder sind /Root/Metadata. Jede Ebene hat
  ihren eigenen Status; ZUGFeRD 1.0 und 2.0 lassen Ebene 3 auf
  eps_Incomplete. }

{ API: internal. May change in any release; use the facade LandrixEInvoice
  or the stable units instead.
  DE: API: intern. Kann sich in jeder Version aendern; stattdessen die
  Fassade LandrixEInvoice oder die stabilen Units verwenden. }

unit LandrixEInvoicePdfCheck;

{$I LandrixEInvoice.inc}

interface

uses
  Classes,
  LandrixEInvoiceTypes,
  LandrixEInvoiceDiagnostics;

type
  { The check levels: 1 PDF/A, 2 embedding of the XML, 3 XMP metadata,
    4 the invoice XML.
    DE: Die Pruefebenen: 1 PDF/A, 2 Einbettung der XML, 3 XMP-Metadaten,
    4 die Rechnungs-XML. }
  TLandrixEInvoicePdfLevel = (epl_PdfA, epl_Embedding, epl_Metadata, epl_Xml);

  { Outcome of one level. eps_Incomplete: no error, but not everything could
    be checked (rebuilt object table, limit reached, ZUGFeRD 1.0/2.0).
    DE: Ergebnis einer Ebene. eps_Incomplete: kein Fehler, aber nicht alles
    konnte geprueft werden (neu aufgebaute Objekttabelle, Grenze erreicht,
    ZUGFeRD 1.0/2.0). }
  TLandrixEInvoicePdfLevelStatus = (eps_NotRun, eps_Passed, eps_Failed, eps_Incomplete);

  { What the embedded invoice claims to be, by its file name (by the root
    element where the name does not tell): ehk_FacturX factur-x.xml (also
    for a wrong name), ehk_XRechnung xrechnung.xml, ehk_ZUGFeRD20
    zugferd-invoice.xml, ehk_ZUGFeRD10 ZUGFeRD-invoice.xml or the root
    CrossIndustryDocument; ehk_None: no invoice found.
    DE: Was die eingebettete Rechnung nach ihrem Dateinamen zu sein
    angibt (nach dem Wurzelelement, wo der Name es nicht sagt):
    ehk_FacturX factur-x.xml (auch bei falschem Namen), ehk_XRechnung
    xrechnung.xml, ehk_ZUGFeRD20 zugferd-invoice.xml, ehk_ZUGFeRD10
    ZUGFeRD-invoice.xml oder die Wurzel CrossIndustryDocument; ehk_None:
    keine Rechnung gefunden. }
  TLandrixEInvoicePdfHybridKind = (ehk_None, ehk_FacturX, ehk_XRechnung, ehk_ZUGFeRD20, ehk_ZUGFeRD10);

  { Facts of the embedded invoice that the caller read through the facade:
    Target is Info.Spec.Target of the document (est_None if unknown; then
    set Target.Syntax to Info.Syntax, so that a UBL invoice with a missing
    or unknown BT-24 is still found, LX-PDF-10);
    SellerCountryCode is BT-40, BuyerCountryCode BT-55 ('' if unknown; the
    rule text of annex 3.d swaps the two BT numbers, which does not matter,
    as its rules need both countries alike). Set every field: a local
    record is not initialised.
    DE: Fakten der eingebetteten Rechnung, die der Aufrufer ueber die
    Fassade gelesen hat: Target ist Info.Spec.Target des Dokuments
    (est_None, wenn unbekannt; dann Target.Syntax auf Info.Syntax setzen,
    damit eine UBL-Rechnung mit fehlendem oder unbekanntem BT-24 trotzdem
    erkannt wird, LX-PDF-10); SellerCountryCode ist BT-40,
    BuyerCountryCode BT-55 ('' wenn unbekannt; der Regeltext in Anhang 3.d
    vertauscht die beiden BT-Nummern, was nichts ausmacht, weil seine
    Regeln beide Laender gleich verlangen). Jedes Feld setzen: ein lokaler
    Record ist nicht initialisiert. }
  TLandrixEInvoicePdfInvoiceFacts = record
    Target: TLandrixEInvoiceTarget;
    SellerCountryCode: TLandrixEInvoiceString;
    BuyerCountryCode: TLandrixEInvoiceString;
  end;

  { Result of a check; Clear resets it.
    DE: Ergebnis einer Pruefung; Clear setzt es zurueck. }
  TLandrixEInvoicePdfCheckResult = class(TObject)
  private
    FDiagnostics: TLandrixEInvoiceDiagnostics;
    FInvoice: TMemoryStream;
  public
    { Status per level; levels that were not run stay eps_NotRun.
      DE: Status je Ebene; nicht gelaufene Ebenen bleiben eps_NotRun. }
    Status: array[TLandrixEInvoicePdfLevel] of TLandrixEInvoicePdfLevelStatus;
    HybridKind: TLandrixEInvoicePdfHybridKind;
    { File name (/UF, else /F) and /AFRelationship of the invoice as
      written; '' without invoice.
      DE: Dateiname (/UF, sonst /F) und /AFRelationship der Rechnung wie
      geschrieben; '' ohne Rechnung. }
    InvoiceFileName: TLandrixEInvoiceString;
    InvoiceRelationship: TLandrixEInvoiceString;
    { /F and /UF of the invoice file specification ('' if absent) and its
      place in the PDF (e.g. /Root/Names/EmbeddedFiles/Names[1]).
      DE: /F und /UF der Dateispezifikation der Rechnung ('', wenn sie
      fehlen) und ihr Ort im PDF (z. B. /Root/Names/EmbeddedFiles/Names[1]). }
    InvoiceFileNameF: TLandrixEInvoiceString;
    InvoiceFileNameUF: TLandrixEInvoiceString;
    InvoicePath: TLandrixEInvoiceString;
    { Set by CheckInvoiceFacts: the facts as passed and the ZUGFeRD profile
      derived from them (Factur-X: the profile of the target; XRechnung CII:
      epr_XRechnung; otherwise epr_None).
      DE: Von CheckInvoiceFacts gesetzt: die Fakten wie uebergeben und das
      daraus abgeleitete ZUGFeRD-Profil (Factur-X: das Profil des Ziels;
      XRechnung CII: epr_XRechnung; sonst epr_None). }
    FactsChecked: Boolean;
    InvoiceFacts: TLandrixEInvoicePdfInvoiceFacts;
    Profile: TLandrixEInvoiceProfile;
    { Version from the header (e.g. 1.7) and /Version of the catalog ('' if
      absent).
      DE: Version aus dem Kopf (z. B. 1.7) und /Version des Katalogs ('',
      wenn sie fehlt). }
    PdfVersion: TLandrixEInvoiceString;
    CatalogVersion: TLandrixEInvoiceString;
    { Read by level 3 from the XMP metadata, as written: the Factur-X
      properties fx:DocumentType, fx:DocumentFileName, fx:Version and
      fx:ConformanceLevel (also when they use a wrong namespace) and
      pdfaid:part and pdfaid:conformance; '' if absent or level 3 did not
      get that far.
      DE: Von Ebene 3 aus den XMP-Metadaten gelesen, wie geschrieben: die
      Factur-X-Eigenschaften fx:DocumentType, fx:DocumentFileName,
      fx:Version und fx:ConformanceLevel (auch in einem falschen
      Namensraum) sowie pdfaid:part und pdfaid:conformance; '' wenn sie
      fehlen oder Ebene 3 nicht so weit kam. }
    XmpDocumentType: TLandrixEInvoiceString;
    XmpDocumentFileName: TLandrixEInvoiceString;
    XmpVersion: TLandrixEInvoiceString;
    XmpConformanceLevel: TLandrixEInvoiceString;
    PdfAPart: TLandrixEInvoiceString;
    PdfAConformance: TLandrixEInvoiceString;
    constructor Create;
    destructor Destroy; override;
    procedure Clear;
    { The findings; owned by the result.
      DE: Die Befunde; gehoeren dem Ergebnis. }
    property Diagnostics: TLandrixEInvoiceDiagnostics read FDiagnostics;
    { The bytes of the invoice as embedded, also when they are not
      well-formed; empty without invoice. Owned by the result.
      DE: Die Bytes der Rechnung wie eingebettet, auch wenn sie nicht
      wohlgeformt sind; leer ohne Rechnung. Gehoert dem Ergebnis. }
    property Invoice: TMemoryStream read FInvoice;
  end;

  { Runs the checks: level 2, then level 3 when level 2 found a Factur-X or
    XRechnung invoice. Both entries clear AResult first and return the
    number of errors (findings with eds_Error) of all levels, as
    TLandrixEInvoice.Check does. The stream variant reads AStream from its
    position to the end.
    DE: Fuehrt die Pruefungen aus: Ebene 2, dann Ebene 3, wenn Ebene 2 eine
    Factur-X- oder XRechnung-Rechnung gefunden hat. Beide Einstiege leeren
    AResult zuerst und liefern die Anzahl der Fehler (Befunde mit
    eds_Error) aller Ebenen, wie TLandrixEInvoice.Check. Die Stream-Variante
    liest AStream ab seiner Position bis zum Ende. }
  TLandrixEInvoicePdfChecker = class(TObject)
  public
    function CheckStream(AStream: TStream; AResult: TLandrixEInvoicePdfCheckResult): Integer;
    function CheckFile(const AFileName: string; AResult: TLandrixEInvoicePdfCheckResult): Integer;
    { Second pass after CheckStream or CheckFile, with the facts of
      AResult.Invoice: adds the profile and country rules to AResult (and
      the warning BR-HYBRID-15 of level 3) and sets the level 2 status to
      eps_Failed if they add an error. Returns
      the number of errors in AResult. Without effect when AResult holds no
      checked invoice (none found, ZUGFeRD 1.0/2.0) or the facts were
      checked already.
      DE: Zweiter Durchgang nach CheckStream oder CheckFile, mit den Fakten
      von AResult.Invoice: ergaenzt die Profil- und Laenderregeln in AResult
      (und die Warnung BR-HYBRID-15 der Ebene 3) und setzt den Status der
      Ebene 2 auf eps_Failed, wenn sie einen Fehler hinzufuegen. Liefert die Anzahl der Fehler in AResult. Ohne Wirkung,
      wenn AResult keine gepruefte Rechnung enthaelt (keine gefunden,
      ZUGFeRD 1.0/2.0) oder die Fakten schon geprueft wurden. }
    function CheckInvoiceFacts(AResult: TLandrixEInvoicePdfCheckResult;
      const AFacts: TLandrixEInvoicePdfInvoiceFacts): Integer;
  end;

implementation

uses
  SysUtils,
  Contnrs,
  LandrixXmlBase,
  LandrixXmlReader,
  LandrixEInvoicePdf,
  LandrixEInvoicePdfObjects;

const
  RuleEmbedding = 'BR-HYBRID-12';
  RuleFileName = 'BR-HYBRID-13';
  RuleRelationship = 'BR-HYBRID-11';
  { the PDF cannot be read or decrypted }
  RuleUnreadable = 'LX-PDF-01';
  { the object table was rebuilt by a scan }
  RuleReconstructed = 'LX-PDF-02';
  { ZUGFeRD 1.0 or 2.0: recognised, not checked }
  RuleLegacy = 'LX-PDF-03';
  { /Params /ModDate missing (recommended by the specification) }
  RuleModDate = 'LX-PDF-04';
  { /Params /Size differs from the decoded length }
  RuleSize = 'LX-PDF-05';
  { the invoice XML is not UTF-8 }
  RuleEncoding = 'LX-PDF-06';
  { another embedded file without /AFRelationship or not in an /AF (ISO 19005-3, 6.8) }
  RuleOtherFile = 'LX-PDF-07';
  { a limit was reached; not everything was checked }
  RuleLimit = 'LX-PDF-08';
  { the MIME type is application/xml, not text/xml }
  RuleMimeType = 'LX-PDF-09';
  { the embedded invoice is UBL, no CII invoice of a ZUGFeRD profile }
  RuleNotCII = 'LX-PDF-10';
  RuleNoMinimum = 'BR-HYBRID-DE-01';
  RuleNoBasicWL = 'BR-HYBRID-DE-02';
  RuleNoXRechnung = 'BR-HYBRID-FR-01';
  RuleNoPdfA = 'BR-HYBRID-02';
  RuleExtensionSchema = 'BR-HYBRID-03';
  RuleNamespace = 'BR-HYBRID-04';
  RulePrefix = 'BR-HYBRID-05';
  RuleDocumentType = 'BR-HYBRID-06';
  RuleConformance = 'BR-HYBRID-07';
  RuleXmpFileName = 'BR-HYBRID-08';
  RuleVersion = 'BR-HYBRID-09';
  RuleVersionOne = 'BR-HYBRID-10';
  RuleXmpFileNameMatch = 'BR-HYBRID-14';
  RuleXmpProfileMatch = 'BR-HYBRID-15';
  { the XMP metadata is missing, cannot be decoded or is not well-formed }
  RuleNoXmp = 'LX-PDF-11';

function ToText(const S: string): TLandrixEInvoiceString;
begin
  Result := TLandrixEInvoiceString(S);
end;

{ ASCII text (PDF names) as invoice string, byte by byte. }
function AnsiToText(const S: AnsiString): TLandrixEInvoiceString;
var
  I: Integer;
begin
  Result := '';
  SetLength(Result, Length(S));
  for I := 1 to Length(S) do
    Result[I] := WideChar(Ord(S[I]));
end;

function AsciiLower(const S: TLandrixEInvoiceString): TLandrixEInvoiceString;
var
  I: Integer;
begin
  Result := S;
  for I := 1 to Length(Result) do
    if (Ord(Result[I]) >= Ord('A')) and (Ord(Result[I]) <= Ord('Z')) then
      Result[I] := WideChar(Ord(Result[I]) + 32);
end;

{ Position of ASub in S (1-based), 0 if absent; bytes, no conversion. }
function BytePos(const ASub, S: AnsiString): Integer;
var
  I: Integer;
begin
  Result := 0;
  for I := 1 to Length(S) - Length(ASub) + 1 do
    if Copy(S, I, Length(ASub)) = ASub then
    begin
      Result := I;
      Exit;
    end;
end;

function IntText(V: Int64): TLandrixEInvoiceString;
begin
  Result := ToText(IntToStr(V));
end;

{ Root elements of a CII or UBL invoice (CrossIndustryDocument: ZUGFeRD 1). }
function IsInvoiceRoot(const ARoot: TLandrixEInvoiceString): Boolean;
begin
  Result := (ARoot = 'CrossIndustryInvoice') or (ARoot = 'CrossIndustryDocument') or
    (ARoot = 'Invoice') or (ARoot = 'CreditNote');
end;

{ File names of an invoice in any case: the code list HybridDocumentFilename
  (without order-x.xml, which is Order-X) and those of ZUGFeRD 1.0 and 2.0.
  DE: Dateinamen einer Rechnung in beliebiger Schreibung: die Codeliste
  HybridDocumentFilename (ohne order-x.xml, das zu Order-X gehoert) und
  die von ZUGFeRD 1.0 und 2.0. }
function IsInvoiceName(const AName: TLandrixEInvoiceString): Boolean;
var
  N: TLandrixEInvoiceString;
begin
  N := AsciiLower(AName);
  Result := (N = 'factur-x.xml') or (N = 'xrechnung.xml') or (N = 'zugferd-invoice.xml');
end;

{ BR-HYBRID-13: the code list HybridDocumentFilename, compared exactly;
  order-x.xml belongs to Order-X and is no invoice name.
  DE: BR-HYBRID-13: die Codeliste HybridDocumentFilename, exakt
  verglichen; order-x.xml gehoert zu Order-X und ist kein
  Rechnungsname. }
function IsHybridFileName(const AName: TLandrixEInvoiceString): Boolean;
begin
  Result := (AName = 'factur-x.xml') or (AName = 'xrechnung.xml');
end;

{ The value of the encoding declaration, '' if there is none; a UTF-16
  byte order mark gives UTF-16. }
function DeclaredEncoding(const AData: TLandrixEInvoicePdfBytes): AnsiString;
var
  Head: AnsiString;
  P, Stop: Integer;
  Quote: AnsiChar;
begin
  Result := '';
  if (Length(AData) >= 2) and (((AData[0] = $FE) and (AData[1] = $FF)) or ((AData[0] = $FF) and (AData[1] = $FE))) then
  begin
    Result := 'UTF-16';
    Exit;
  end;
  P := 0;
  if (Length(AData) >= 3) and (AData[0] = $EF) and (AData[1] = $BB) and (AData[2] = $BF) then
    P := 3;
  if Integer(Length(AData)) - P < 5 then
    Exit;
  Stop := Integer(Length(AData)) - P;
  if Stop > 200 then
    Stop := 200;
  Head := LandrixEInvoicePdfBytesToAnsi(AData, P, Stop);
  if Copy(Head, 1, 5) <> '<?xml' then
    Exit;
  Stop := BytePos('?>', Head);
  if Stop > 0 then
    Head := Copy(Head, 1, Stop - 1);
  P := BytePos('encoding', Head);
  if P = 0 then
    Exit;
  Inc(P, 8);
  while (P <= Length(Head)) and (Head[P] in [' ', #9, #10, #13, '=']) do
    Inc(P);
  if (P > Length(Head)) or not (Head[P] in ['"', '''']) then
    Exit;
  Quote := Head[P];
  Inc(P);
  Stop := P;
  while (Stop <= Length(Head)) and (Head[Stop] <> Quote) do
    Inc(Stop);
  Result := Copy(Head, P, Stop - P);
end;

//==============================================================================
// TLandrixEInvoicePdfCheckResult
//==============================================================================

constructor TLandrixEInvoicePdfCheckResult.Create;
begin
  inherited Create;
  FDiagnostics := TLandrixEInvoiceDiagnostics.Create;
  FInvoice := TMemoryStream.Create;
end;

destructor TLandrixEInvoicePdfCheckResult.Destroy;
begin
  FInvoice.Free;
  FDiagnostics.Free;
  inherited Destroy;
end;

procedure TLandrixEInvoicePdfCheckResult.Clear;
var
  L: TLandrixEInvoicePdfLevel;
begin
  for L := Low(TLandrixEInvoicePdfLevel) to High(TLandrixEInvoicePdfLevel) do
    Status[L] := eps_NotRun;
  HybridKind := ehk_None;
  InvoiceFileName := '';
  InvoiceRelationship := '';
  InvoiceFileNameF := '';
  InvoiceFileNameUF := '';
  InvoicePath := '';
  FactsChecked := False;
  InvoiceFacts.Target.Standard := est_None;
  InvoiceFacts.Target.Syntax := esy_None;
  InvoiceFacts.Target.Profile := epr_None;
  InvoiceFacts.Target.Version := '';
  InvoiceFacts.SellerCountryCode := '';
  InvoiceFacts.BuyerCountryCode := '';
  Profile := epr_None;
  PdfVersion := '';
  CatalogVersion := '';
  XmpDocumentType := '';
  XmpDocumentFileName := '';
  XmpVersion := '';
  XmpConformanceLevel := '';
  PdfAPart := '';
  PdfAConformance := '';
  FDiagnostics.Clear;
  FInvoice.Clear;
end;

//==============================================================================
// Level 2: the embedding
//==============================================================================

type
  TEmbeddingCheck = class(TObject)
  private
    FDoc: TLandrixEInvoicePdfDocument;
    FResult: TLandrixEInvoicePdfCheckResult;
    FSpecs: TLandrixEInvoicePdfCollector;
    { per file specification: root element and decoded data }
    FRoots: array of TLandrixEInvoiceString;
    FData: array of TLandrixEInvoicePdfBytes;
    FDecoded: array of Boolean;
    FDecodeErrors: array of string;
    FDecodedBytes: Int64;
    FDecodedCount: Integer;
    FIncomplete: Boolean;
    FLimitNoted: Boolean;
    { file specifications in the /AF of a page }
    FPageSpecs: TObjectList;
    FPageNodes: Integer;
    procedure Add(const ARule: TLandrixEInvoiceString; ASeverity: TLandrixEInvoiceDiagnosticSeverity;
      const APath, AMessage: TLandrixEInvoiceString; ALine: Integer = 0; AColumn: Integer = 0;
      AOffset: Int64 = 0);
    function SpecPath(AIndex: Integer): TLandrixEInvoiceString;
    procedure NoteLimit(const APath, AMessage: TLandrixEInvoiceString);
    function Decode(AIndex: Integer): Boolean;
    procedure CopyInvoice(AIndex: Integer);
    procedure CollectPageAF(ANode: TLandrixEInvoicePdfObject; ADepth: Integer);
    function IsCandidate(AIndex: Integer): Boolean;
    function ChooseInvoice: Integer;
    function KindOf(AIndex: Integer): TLandrixEInvoicePdfHybridKind;
    procedure CheckNameTree;
    procedure CheckInvoice(AIndex: Integer);
    procedure CheckStream(AIndex: Integer; const APath: TLandrixEInvoiceString);
    procedure CheckXml(const AData: TLandrixEInvoicePdfBytes; const AName, APath: TLandrixEInvoiceString);
    procedure CheckOtherFiles(AInvoice: Integer);
  public
    constructor Create(ADoc: TLandrixEInvoicePdfDocument; AResult: TLandrixEInvoicePdfCheckResult);
    destructor Destroy; override;
    procedure Run;
    property Incomplete: Boolean read FIncomplete;
  end;

constructor TEmbeddingCheck.Create(ADoc: TLandrixEInvoicePdfDocument; AResult: TLandrixEInvoicePdfCheckResult);
begin
  inherited Create;
  FDoc := ADoc;
  FResult := AResult;
  FSpecs := TLandrixEInvoicePdfCollector.Create(ADoc);
  FPageSpecs := TObjectList.Create(False);
end;

destructor TEmbeddingCheck.Destroy;
begin
  FPageSpecs.Free;
  FSpecs.Free;
  inherited Destroy;
end;

procedure TEmbeddingCheck.Add(const ARule: TLandrixEInvoiceString; ASeverity: TLandrixEInvoiceDiagnosticSeverity;
  const APath, AMessage: TLandrixEInvoiceString; ALine, AColumn: Integer; AOffset: Int64);
var
  D: TLandrixEInvoiceDiagnostic;
begin
  D := FResult.Diagnostics.AddDiagnostic(edk_RuleViolation, APath, ALine, AColumn, AOffset, AMessage);
  D.Severity := ASeverity;
  D.RuleID := ARule;
end;

{ Where the file specification is reached: its place in the name tree, else
  in /AF. }
function TEmbeddingCheck.SpecPath(AIndex: Integer): TLandrixEInvoiceString;
var
  F: TLandrixEInvoicePdfFileSpec;
begin
  F := FSpecs[AIndex];
  if efr_NameTree in F.Routes then
    Result := F.NameTreePath
  else
    Result := '/Root/AF[' + IntText(F.AFIndex) + ']';
end;

{ LX-PDF-08 once: a limit makes the result incomplete. }
procedure TEmbeddingCheck.NoteLimit(const APath, AMessage: TLandrixEInvoiceString);
begin
  FIncomplete := True;
  if FLimitNoted then
    Exit;
  FLimitNoted := True;
  Add(RuleLimit, eds_Warning, APath, AMessage);
end;

{ Decodes the stream of file specification AIndex once (a second file
  specification of the same stream shares the result); the limits of the
  extractor on count and total size apply. }
function TEmbeddingCheck.Decode(AIndex: Integer): Boolean;
var
  F: TLandrixEInvoicePdfFileSpec;
  Data: TLandrixEInvoicePdfBytes;
begin
  F := FSpecs[AIndex];
  Result := False;
  if F.Stream = nil then
    Exit;
  if F.DuplicateOf >= 0 then
  begin
    Result := Decode(F.DuplicateOf);
    FRoots[AIndex] := FRoots[F.DuplicateOf];
    FDecodeErrors[AIndex] := FDecodeErrors[F.DuplicateOf];
    Exit;
  end;
  if FDecoded[AIndex] then
  begin
    Result := FDecodeErrors[AIndex] = '';
    Exit;
  end;
  FDecoded[AIndex] := True;
  if FDecodedCount >= LandrixEInvoicePdfMaxAttachments then
  begin
    FDecodeErrors[AIndex] := 'not decoded: more than ' + IntToStr(LandrixEInvoicePdfMaxAttachments) +
      ' embedded files';
    NoteLimit(SpecPath(AIndex), 'Embedded file ' + ToText(FDecodeErrors[AIndex]));
    Exit;
  end;
  Inc(FDecodedCount);
  if not FDoc.GetStreamData(F.Stream, Data) then
  begin
    FDecodeErrors[AIndex] := FDoc.StreamError;
    if FDecodeErrors[AIndex] = '' then
      FDecodeErrors[AIndex] := 'cannot be decoded';
    Exit;
  end;
  if FDecodedBytes + Length(Data) > LandrixEInvoicePdfMaxTotalSize then
  begin
    FDecodeErrors[AIndex] := 'not decoded: all embedded files together exceed ' +
      IntToStr(LandrixEInvoicePdfMaxTotalSize) + ' bytes';
    NoteLimit(SpecPath(AIndex), 'Embedded file ' + ToText(FDecodeErrors[AIndex]));
    Exit;
  end;
  FDecodedBytes := FDecodedBytes + Integer(Length(Data));
  FRoots[AIndex] := LandrixEInvoicePdfDetectXmlRoot(Data);
  FData[AIndex] := Data;
  Result := True;
end;

{ The decoded data of AIndex (already decoded) becomes the invoice of the
  result. }
procedure TEmbeddingCheck.CopyInvoice(AIndex: Integer);
begin
  FResult.Invoice.Clear;
  if Length(FData[AIndex]) > 0 then
    FResult.Invoice.WriteBuffer(FData[AIndex][0], Length(FData[AIndex]));
  FResult.Invoice.Position := 0;
end;

{ The file specifications in /AF of the pages (ISO 19005-3, 6.8 allows the
  association with a page); the pages tree is bounded like the name tree. }
procedure TEmbeddingCheck.CollectPageAF(ANode: TLandrixEInvoicePdfObject; ADepth: Integer);
var
  Kids, Af, Spec: TLandrixEInvoicePdfObject;
  I: Integer;
begin
  if (ANode = nil) or not ANode.IsDictLike then
    Exit;
  Inc(FPageNodes);
  if (ADepth > LandrixEInvoicePdfObjectMaxDepth) or (FPageNodes > 100000) then
  begin
    NoteLimit('/Root/Pages', 'Too large or too deep a pages tree; not every page /AF was read');
    Exit;
  end;
  Af := FDoc.DGet(ANode, 'AF');
  if (Af <> nil) and (Af.Kind = pok_Arr) then
    for I := 0 to Af.ArrCount - 1 do
    begin
      Spec := FDoc.Resolve(Af.ArrItem(I));
      if Spec <> nil then
        FPageSpecs.Add(Spec);
    end;
  Kids := FDoc.DGet(ANode, 'Kids');
  if (Kids <> nil) and (Kids.Kind = pok_Arr) then
    for I := 0 to Kids.ArrCount - 1 do
      CollectPageAF(FDoc.Resolve(Kids.ArrItem(I)), ADepth + 1);
end;

function TEmbeddingCheck.IsCandidate(AIndex: Integer): Boolean;
begin
  Result := IsInvoiceName(FSpecs[AIndex].FileName) or IsInvoiceRoot(FRoots[AIndex]);
end;

{ The invoice among the candidates: an exact invoice name counts more than
  an invoice root element, the first wins a tie; -1 if there is none. }
function TEmbeddingCheck.ChooseInvoice: Integer;
var
  I, Score, Best: Integer;
  N: TLandrixEInvoiceString;
begin
  Result := -1;
  Best := 0;
  for I := 0 to FSpecs.Count - 1 do
    if IsCandidate(I) then
    begin
      N := FSpecs[I].FileName;
      Score := 1;
      if IsHybridFileName(N) or (N = 'zugferd-invoice.xml') or (N = 'ZUGFeRD-invoice.xml') then
        Inc(Score, 2);
      if IsInvoiceRoot(FRoots[I]) then
        Inc(Score);
      if Score > Best then
      begin
        Best := Score;
        Result := I;
      end;
    end;
end;

function TEmbeddingCheck.KindOf(AIndex: Integer): TLandrixEInvoicePdfHybridKind;
var
  N: TLandrixEInvoiceString;
begin
  N := FSpecs[AIndex].FileName;
  if N = 'ZUGFeRD-invoice.xml' then
    Result := ehk_ZUGFeRD10
  else if N = 'zugferd-invoice.xml' then
    Result := ehk_ZUGFeRD20
  else if N = 'xrechnung.xml' then
    Result := ehk_XRechnung
  else if N = 'factur-x.xml' then
    Result := ehk_FacturX
  else if FRoots[AIndex] = 'CrossIndustryDocument' then
    Result := ehk_ZUGFeRD10
  else if AsciiLower(N) = 'zugferd-invoice.xml' then
    Result := ehk_ZUGFeRD20
  else if AsciiLower(N) = 'xrechnung.xml' then
    Result := ehk_XRechnung
  else
    Result := ehk_FacturX;
end;

{ BR-HYBRID-12: a damaged name tree hinders the simple extraction.
  DE: BR-HYBRID-12: ein beschaedigter Namensbaum behindert die einfache
  Extraktion. }
procedure TEmbeddingCheck.CheckNameTree;
var
  I, P: Integer;
  Line: string;
begin
  for I := 0 to Integer(FSpecs.NameTreeIssues.Count) - 1 do
  begin
    Line := FSpecs.NameTreeIssues[I];
    P := Pos(': ', Line);
    Add(RuleEmbedding, eds_Error, ToText(Copy(Line, 1, P - 1)),
      ToText('Name tree of the embedded files: ' + Copy(Line, P + 2, MaxInt)));
  end;
end;

{ BR-HYBRID-12, -13 and -11 on the invoice file specification: reachable by
  the name tree and /AF of the catalog (ISO 19005-3, 6.8), /Type /Filespec,
  /F and /UF, /AFRelationship, /EF /F with the stream; the exact file name
  in /F and /UF; /AFRelationship Data, Source or Alternative (the values of
  the table in 6.2.2 over all profiles and countries).
  DE: BR-HYBRID-12, -13 und -11 an der Dateispezifikation der Rechnung:
  erreichbar ueber Namensbaum und /AF des Katalogs (ISO 19005-3, 6.8),
  /Type /Filespec, /F und /UF, /AFRelationship, /EF /F mit dem Stream; der
  exakte Dateiname in /F und /UF; /AFRelationship Data, Source oder
  Alternative (die Werte der Tabelle in 6.2.2 ueber alle Profile und
  Laender). }
procedure TEmbeddingCheck.CheckInvoice(AIndex: Integer);
var
  F: TLandrixEInvoicePdfFileSpec;
  Path, Rel: TLandrixEInvoiceString;
begin
  F := FSpecs[AIndex];
  Path := SpecPath(AIndex);
  if not (efr_NameTree in F.Routes) then
  begin
    if FSpecs.HasNameTree then
      Add(RuleEmbedding, eds_Error, Path, 'The invoice is not in the name tree /Root/Names/EmbeddedFiles')
    else
      Add(RuleEmbedding, eds_Error, '/Root/Names', 'The catalog has no name tree /EmbeddedFiles');
  end;
  if not (efr_AF in F.Routes) then
  begin
    if FSpecs.HasAF then
      Add(RuleEmbedding, eds_Error, Path, 'The invoice is not listed in /AF of the catalog')
    else
      Add(RuleEmbedding, eds_Error, '/Root/AF', 'The catalog has no /AF array');
  end;
  if F.TypeName = '' then
    Add(RuleEmbedding, eds_Error, Path + '/Type', 'The file specification has no /Type /Filespec')
  else if F.TypeName <> 'Filespec' then
    Add(RuleEmbedding, eds_Error, Path + '/Type', '/Type is /' + AnsiToText(F.TypeName) + ', not /Filespec');
  if not F.HasF then
    Add(RuleEmbedding, eds_Error, Path + '/F', 'The file specification has no /F')
  else if not IsHybridFileName(F.FileNameF) then
    Add(RuleFileName, eds_Error, Path + '/F', 'The file name "' + F.FileNameF +
      '" is not factur-x.xml or xrechnung.xml (compared exactly)');
  if not F.HasUF then
    Add(RuleEmbedding, eds_Error, Path + '/UF', 'The file specification has no /UF')
  else if not IsHybridFileName(F.FileNameUF) then
    Add(RuleFileName, eds_Error, Path + '/UF', 'The file name "' + F.FileNameUF +
      '" is not factur-x.xml or xrechnung.xml (compared exactly)');
  if not F.HasRelationship then
    Add(RuleEmbedding, eds_Error, Path + '/AFRelationship', 'The file specification has no /AFRelationship')
  else
  begin
    Rel := AnsiToText(F.Relationship);
    if (Rel <> 'Data') and (Rel <> 'Source') and (Rel <> 'Alternative') then
      Add(RuleRelationship, eds_Warning, Path + '/AFRelationship', '/AFRelationship is /' + Rel +
        '; the table of the specification allows Data, Source or Alternative');
  end;
  if F.Stream = nil then
    Add(RuleEmbedding, eds_Error, Path + '/EF', 'The file specification has no embedded file stream (/EF /F)')
  else
  begin
    if not F.HasEmbeddedF then
      Add(RuleEmbedding, eds_Error, Path + '/EF/F', 'The embedded file stream is not under /EF /F');
    CheckStream(AIndex, Path + '/EF/F');
  end;
end;

{ BR-HYBRID-12 on the embedded file stream: /Type /EmbeddedFile where
  present (ISO 32000-1, table 45), the MIME type text/xml in /Subtype
  (ISO 19005-3, 6.8; specification 6.2), decodable; LX-PDF-04 and -05 on
  /Params. application/xml is only a warning (LX-PDF-09): the
  specification says text/xml "as a rule", yet every hybrid example of
  the ZUGFeRD 2.5.2 package uses application/xml; it does not hinder the
  extraction and RFC 7303 treats both alike (owner decision 2026-10-28).
  DE: BR-HYBRID-12 am eingebetteten Dateistream: /Type /EmbeddedFile, wo
  vorhanden (ISO 32000-1, Tabelle 45), der MIME-Typ text/xml in /Subtype
  (ISO 19005-3, 6.8; Spezifikation 6.2), dekodierbar; LX-PDF-04 und -05 an
  /Params. application/xml ist nur eine Warnung (LX-PDF-09): die
  Spezifikation nennt "grundsaetzlich" text/xml, doch jedes hybride
  Beispiel des ZUGFeRD-2.5.2-Pakets verwendet application/xml; es
  behindert die Extraktion nicht, und RFC 7303 behandelt beide gleich
  (Entscheidung des Eigentuemers 2026-10-28). }
procedure TEmbeddingCheck.CheckStream(AIndex: Integer; const APath: TLandrixEInvoiceString);
var
  F: TLandrixEInvoicePdfFileSpec;
  Source: Integer;
begin
  F := FSpecs[AIndex];
  if (F.StreamType <> '') and (F.StreamType <> 'EmbeddedFile') then
    Add(RuleEmbedding, eds_Error, APath + '/Type', 'The stream /Type is /' + AnsiToText(F.StreamType) +
      ', not /EmbeddedFile');
  if F.Subtype = '' then
    Add(RuleEmbedding, eds_Error, APath + '/Subtype', 'The stream has no /Subtype (MIME type text/xml)')
  else if F.Subtype = 'application/xml' then
    Add(RuleMimeType, eds_Warning, APath + '/Subtype', 'The MIME type is application/xml; the specification ' +
      'names text/xml')
  else if F.Subtype <> 'text/xml' then
    Add(RuleEmbedding, eds_Error, APath + '/Subtype', 'The MIME type is ' + AnsiToText(F.Subtype) +
      ', not text/xml');
  if not F.HasModDate then
    Add(RuleModDate, eds_Warning, APath + '/Params', 'The stream has no /Params /ModDate');
  if not Decode(AIndex) then
  begin
    { a reached limit is noted already }
    if Copy(FDecodeErrors[AIndex], 1, 12) <> 'not decoded:' then
      Add(RuleEmbedding, eds_Error, APath, 'The embedded invoice cannot be decoded: ' +
        ToText(FDecodeErrors[AIndex]));
    Exit;
  end;
  Source := AIndex;
  if F.DuplicateOf >= 0 then
    Source := F.DuplicateOf;
  if (F.ParamsSize >= 0) and (F.ParamsSize <> Length(FData[Source])) then
    Add(RuleSize, eds_Warning, APath + '/Params/Size', '/Params /Size is ' + IntText(F.ParamsSize) +
      ', the decoded length ' + IntText(Length(FData[Source])));
  CopyInvoice(Source);
  CheckXml(FData[Source], F.FileName, APath);
end;

{ BR-HYBRID-12: the invoice must be well-formed XML to be extracted and
  read; LX-PDF-06: in UTF-8 (specification 6.2). The place of an XML error
  is the file name and the element path, Line and Column are those of the
  XML.
  DE: BR-HYBRID-12: die Rechnung muss wohlgeformtes XML sein, um
  extrahiert und gelesen zu werden; LX-PDF-06: in UTF-8 (Spezifikation
  6.2). Der Ort eines XML-Fehlers ist der Dateiname mit dem Elementpfad,
  Line und Column sind die der XML. }
procedure TEmbeddingCheck.CheckXml(const AData: TLandrixEInvoicePdfBytes;
  const AName, APath: TLandrixEInvoiceString);
var
  R: TLandrixXmlReader;
  Enc: AnsiString;
  Where: TLandrixEInvoiceString;
  Ofs: Int64;
begin
  Where := AName + ':';
  if Length(AData) = 0 then
  begin
    Add(RuleEmbedding, eds_Error, APath, 'The embedded invoice is empty');
    Exit;
  end;
  Enc := DeclaredEncoding(AData);
  if (Enc <> '') and (AsciiLower(AnsiToText(Enc)) <> 'utf-8') then
    Add(RuleEncoding, eds_Warning, Where, 'The invoice XML is encoded in ' + AnsiToText(Enc) + ', not UTF-8');
  R := TLandrixXmlReader.Create;
  try
    try
      R.LoadFromBuffer(AData[0], Integer(Length(AData)));
      while R.Read do
        ;
    except
      on E: ELandrixXmlError do
      begin
        Ofs := E.Offset;
        if Ofs < 0 then
          Ofs := 0;
        Add(RuleEmbedding, eds_Error, Where + R.ElementPathW, 'The invoice XML is not well-formed: ' +
          ToText(E.Message), E.Line, E.Column, Ofs);
      end;
    end;
  finally
    R.Free;
  end;
end;

{ LX-PDF-07: every other embedded file of the catalog needs /AFRelationship
  and an association by /AF of the catalog or of a page (ISO 19005-3, 6.8;
  /AF of annotations, form fields, structure elements and XObjects is not
  searched yet).
  DE: LX-PDF-07: jede andere eingebettete Datei des Katalogs braucht
  /AFRelationship und eine Zuordnung ueber /AF des Katalogs oder einer
  Seite (ISO 19005-3, 6.8; /AF von Annotationen, Formularfeldern,
  Strukturelementen und XObjects wird noch nicht durchsucht). }
procedure TEmbeddingCheck.CheckOtherFiles(AInvoice: Integer);
var
  I: Integer;
  F: TLandrixEInvoicePdfFileSpec;
begin
  if FDoc.Catalog <> nil then
    CollectPageAF(FDoc.DGet(FDoc.Catalog, 'Pages'), 0);
  for I := 0 to FSpecs.Count - 1 do
    if I <> AInvoice then
    begin
      F := FSpecs[I];
      if not F.HasRelationship then
        Add(RuleOtherFile, eds_Error, SpecPath(I) + '/AFRelationship', 'The embedded file "' + F.FileName +
          '" has no /AFRelationship');
      if not (efr_AF in F.Routes) and (FPageSpecs.IndexOf(F.Spec) < 0) then
        Add(RuleOtherFile, eds_Error, SpecPath(I), 'The embedded file "' + F.FileName +
          '" is not listed in /AF of the catalog or of a page');
    end;
end;

procedure TEmbeddingCheck.Run;
var
  I, Invoice: Integer;
  F: TLandrixEInvoicePdfFileSpec;
  Msg: TLandrixEInvoiceString;
begin
  FSpecs.Collect;
  if FSpecs.LimitReached then
    NoteLimit('/Root', 'Too many embedded files or too deep a name tree; not all were read');
  SetLength(FRoots, FSpecs.Count);
  SetLength(FData, FSpecs.Count);
  SetLength(FDecoded, FSpecs.Count);
  SetLength(FDecodeErrors, FSpecs.Count);
  { invoice names first, so that other attachments cannot use up the
    budget; the root element is needed where the name does not tell }
  for I := 0 to FSpecs.Count - 1 do
    if IsInvoiceName(FSpecs[I].FileName) then
      Decode(I);
  for I := 0 to FSpecs.Count - 1 do
    Decode(I);
  Invoice := ChooseInvoice;
  if Invoice >= 0 then
  begin
    F := FSpecs[Invoice];
    FResult.HybridKind := KindOf(Invoice);
    FResult.InvoiceFileName := F.FileName;
    FResult.InvoiceRelationship := AnsiToText(F.Relationship);
    FResult.InvoiceFileNameF := F.FileNameF;
    FResult.InvoiceFileNameUF := F.FileNameUF;
    FResult.InvoicePath := SpecPath(Invoice);
  end;
  if FResult.HybridKind in [ehk_ZUGFeRD10, ehk_ZUGFeRD20] then
  begin
    { recognised and extracted; the rules of Factur-X 1.0 do not apply }
    FIncomplete := True;
    if FResult.HybridKind = ehk_ZUGFeRD10 then
      Msg := 'ZUGFeRD 1.0'
    else
      Msg := 'ZUGFeRD 2.0';
    Add(RuleLegacy, eds_Info, SpecPath(Invoice), Msg + ' invoice "' + FResult.InvoiceFileName +
      '"; the embedding is not checked against ZUGFeRD 2.5.2 / Factur-X 1.0');
    I := Invoice;
    if FSpecs[I].DuplicateOf >= 0 then
      I := FSpecs[I].DuplicateOf;
    if Decode(Invoice) then
      CopyInvoice(I)
    else if FSpecs[I].Stream = nil then
      Add(RuleLegacy, eds_Warning, SpecPath(Invoice), 'The invoice cannot be extracted: no embedded file stream')
    else if Copy(FDecodeErrors[I], 1, 12) <> 'not decoded:' then
      Add(RuleLegacy, eds_Warning, SpecPath(Invoice), 'The invoice cannot be extracted: ' +
        ToText(FDecodeErrors[I]));
    Exit;
  end;
  CheckNameTree;
  if Invoice < 0 then
  begin
    if FSpecs.Count = 0 then
      Add(RuleEmbedding, eds_Error, '/Root', 'The PDF has no embedded files')
    else
      Add(RuleEmbedding, eds_Error, '/Root', 'None of the ' + IntText(FSpecs.Count) +
        ' embedded files is an invoice XML');
  end
  else
  begin
    for I := 0 to FSpecs.Count - 1 do
      if (I <> Invoice) and IsCandidate(I) then
      begin
        Msg := 'A second invoice XML "' + FSpecs[I].FileName + '" besides "' + FResult.InvoiceFileName + '"';
        if (FSpecs[I].Stream <> nil) and (FSpecs[I].Stream = FSpecs[Invoice].Stream) then
          Msg := Msg + ' (a second file specification of the same stream)';
        Add(RuleEmbedding, eds_Error, SpecPath(I), Msg + '; only one is allowed');
      end;
    CheckInvoice(Invoice);
  end;
  CheckOtherFiles(Invoice);
end;

//==============================================================================
// Level 3: the XMP metadata
//==============================================================================

const
  NsRdf = 'http://www.w3.org/1999/02/22-rdf-syntax-ns#';
  NsXml = 'http://www.w3.org/XML/1998/namespace';
  NsFacturX = 'urn:factur-x:pdfa:CrossIndustryDocument:invoice:1p0#';
  NsPdfAId = 'http://www.aiim.org/pdfa/ns/id/';
  NsPdfAExtension = 'http://www.aiim.org/pdfa/ns/extension/';
  NsPdfASchema = 'http://www.aiim.org/pdfa/ns/schema#';
  NsPdfAProperty = 'http://www.aiim.org/pdfa/ns/property#';
  { limits for the packet: elements, attributes and text pieces; nesting;
    characters kept per element (longer text is cut and marked with '...',
    so that the cut value cannot pass a check) }
  XmpMaxNodes = 20000;
  XmpMaxDepth = 64;
  XmpMaxText = 4096;
  { the four properties of the Factur-X extension schema }
  FacturXProperties: array[0..3] of string = ('DocumentFileName', 'DocumentType', 'Version', 'ConformanceLevel');

type
  { An element of the XMP packet. Attributes other than namespace
    declarations and those of rdf and xml become children with IsAttr set:
    in RDF the attribute form says the same as the element form. }
  TXmpNode = class(TObject)
  private
    FChildren: TObjectList;
  public
    Ns, Local, Prefix, Text: TLandrixEInvoiceString;
    IsAttr: Boolean;
    { rdf:parseType="Resource" }
    IsResource: Boolean;
    constructor Create;
    destructor Destroy; override;
    function Add: TXmpNode;
    function Count: Integer;
    function Child(AIndex: Integer): TXmpNode;
    function HasElements: Boolean;
  end;

constructor TXmpNode.Create;
begin
  inherited Create;
  FChildren := TObjectList.Create(True);
end;

destructor TXmpNode.Destroy;
begin
  FChildren.Free;
  inherited Destroy;
end;

function TXmpNode.Add: TXmpNode;
begin
  Result := TXmpNode.Create;
  FChildren.Add(Result);
end;

function TXmpNode.Count: Integer;
begin
  Result := Integer(FChildren.Count);
end;

function TXmpNode.Child(AIndex: Integer): TXmpNode;
begin
  Result := TXmpNode(FChildren[AIndex]);
end;

function TXmpNode.HasElements: Boolean;
var
  I: Integer;
begin
  Result := False;
  for I := 0 to Count - 1 do
    if not Child(I).IsAttr then
    begin
      Result := True;
      Exit;
    end;
end;

function PrefixOf(const AQName: TLandrixEInvoiceString): TLandrixEInvoiceString;
var
  I: Integer;
begin
  Result := '';
  for I := 1 to Length(AQName) do
    if AQName[I] = ':' then
    begin
      Result := Copy(AQName, 1, I - 1);
      Exit;
    end;
end;

procedure AppendText(N: TXmpNode; const AText: TLandrixEInvoiceString);
begin
  if Length(N.Text) >= XmpMaxText then
  begin
    { a further piece at the limit: mark the cut once }
    if (AText <> '') and (Length(N.Text) = XmpMaxText) then
      N.Text := N.Text + '...';
    Exit;
  end;
  if Length(N.Text) + Length(AText) > XmpMaxText then
    N.Text := N.Text + Copy(AText, 1, XmpMaxText - Length(N.Text)) + '...'
  else
    N.Text := N.Text + AText;
end;

{ Reads the packet into the children of ARoot. Returns '' or why it cannot
  be read; ALimit is set when a limit stopped the reading (more than
  XmpMaxNodes elements, attributes and text pieces, deeper than
  XmpMaxDepth). An rdf:resource attribute is the text of its element. }
function ParseXmp(const AData: TLandrixEInvoicePdfBytes; ARoot: TXmpNode; out ALimit: Boolean;
  out ALine, AColumn: Integer): TLandrixEInvoiceString;
var
  R: TLandrixXmlReader;
  Stack: TObjectList;
  Cur, N, A: TXmpNode;
  I, Nodes: Integer;
  AttrNs, AttrLocal: TLandrixEInvoiceString;
begin
  Result := '';
  ALimit := False;
  Nodes := 0;
  ALine := 0;
  AColumn := 0;
  if Length(AData) = 0 then
  begin
    Result := 'empty';
    Exit;
  end;
  R := TLandrixXmlReader.Create;
  Stack := TObjectList.Create(False);
  try
    try
      R.MaxDepth := XmpMaxDepth;
      R.LoadFromBuffer(AData[0], Integer(Length(AData)));
      Cur := ARoot;
      while R.Read do
        case R.TokenType of
          xttStartElement:
            begin
              Inc(Nodes, 1 + R.AttributeCount);
              if Nodes > XmpMaxNodes then
              begin
                ALimit := True;
                Result := 'too large (more than ' + IntText(XmpMaxNodes) + ' elements, attributes and text pieces)';
                Exit;
              end;
              N := Cur.Add;
              N.Ns := R.NamespaceUriW;
              N.Local := R.LocalNameW;
              N.Prefix := LandrixXmlUtf8ToWide(R.PrefixUtf8);
              for I := 0 to R.AttributeCount - 1 do
                if not R.IsNamespaceDeclaration(I) then
                begin
                  AttrNs := LandrixXmlUtf8ToWide(R.AttributeNamespaceUriUtf8(I));
                  if AttrNs = NsRdf then
                  begin
                    AttrLocal := LandrixXmlUtf8ToWide(R.AttributeLocalNameUtf8(I));
                    if (AttrLocal = 'parseType') and (R.AttributeValueW(I) = 'Resource') then
                      N.IsResource := True
                    else if AttrLocal = 'resource' then
                      AppendText(N, R.AttributeValueW(I));
                  end
                  else if (AttrNs <> '') and (AttrNs <> NsXml) then
                  begin
                    A := N.Add;
                    A.IsAttr := True;
                    A.Ns := AttrNs;
                    A.Local := LandrixXmlUtf8ToWide(R.AttributeLocalNameUtf8(I));
                    A.Prefix := PrefixOf(LandrixXmlUtf8ToWide(R.AttributeNameUtf8(I)));
                    AppendText(A, R.AttributeValueW(I));
                  end;
                end;
              Stack.Add(Cur);
              Cur := N;
            end;
          xttEndElement:
            begin
              Cur := TXmpNode(Stack[Stack.Count - 1]);
              Stack.Delete(Stack.Count - 1);
            end;
          xttText, xttCData:
            begin
              Inc(Nodes);
              if Nodes > XmpMaxNodes then
              begin
                ALimit := True;
                Result := 'too large (more than ' + IntText(XmpMaxNodes) + ' elements, attributes and text pieces)';
                Exit;
              end;
              AppendText(Cur, R.ValueW);
            end;
        else
          { comments, processing instructions: nothing to keep }
        end;
    except
      on E: ELandrixXmlError do
      begin
        if E.Code = xecLimit then
        begin
          ALimit := True;
          Result := 'too deep or too large: ' + ToText(E.Message);
        end
        else
          Result := 'not well-formed: ' + ToText(E.Message);
        ALine := E.Line;
        AColumn := E.Column;
      end;
    end;
  finally
    Stack.Free;
    R.Free;
  end;
end;

function IsRdf(N: TXmpNode; const ALocal: TLandrixEInvoiceString): Boolean;
begin
  Result := (N.Ns = NsRdf) and (N.Local = ALocal);
end;

{ The resource a node describes: an rdf:Description, a node with
  rdf:parseType="Resource" or with property attributes, or its child
  rdf:Description; nil for a literal or a container. }
function ResourceOf(N: TXmpNode): TXmpNode;
var
  I: Integer;
begin
  Result := nil;
  if N = nil then
    Exit;
  if IsRdf(N, 'Description') or N.IsResource then
  begin
    Result := N;
    Exit;
  end;
  for I := 0 to N.Count - 1 do
    if IsRdf(N.Child(I), 'Description') then
    begin
      Result := N.Child(I);
      Exit;
    end;
  for I := 0 to N.Count - 1 do
    if N.Child(I).IsAttr then
    begin
      Result := N;
      Exit;
    end;
end;

{ The first property ANs:ALocal of the resource ARes; nil if absent. }
function PropOf(ARes: TXmpNode; const ANs, ALocal: TLandrixEInvoiceString): TXmpNode;
var
  I: Integer;
begin
  Result := nil;
  if ARes = nil then
    Exit;
  for I := 0 to ARes.Count - 1 do
    if (ARes.Child(I).Ns = ANs) and (ARes.Child(I).Local = ALocal) then
    begin
      Result := ARes.Child(I);
      Exit;
    end;
end;

{ The value of a simple property; '' for one with elements or nil. }
function ValueOf(AProp: TXmpNode): TLandrixEInvoiceString;
begin
  Result := '';
  if (AProp <> nil) and not AProp.HasElements then
    Result := AProp.Text;
end;

{ The container (rdf:Bag, rdf:Seq, rdf:Alt) of AProp; nil if it has none. }
function ContainerOf(AProp: TXmpNode): TXmpNode;
var
  I: Integer;
begin
  Result := nil;
  if AProp = nil then
    Exit;
  for I := 0 to AProp.Count - 1 do
    if IsRdf(AProp.Child(I), 'Bag') or IsRdf(AProp.Child(I), 'Seq') or IsRdf(AProp.Child(I), 'Alt') then
    begin
      Result := AProp.Child(I);
      Exit;
    end;
end;

{ Appends the rdf:li items of the container AContainer to AItems. }
procedure ItemsOf(AContainer: TXmpNode; AItems: TObjectList);
var
  J: Integer;
begin
  if AContainer = nil then
    Exit;
  for J := 0 to AContainer.Count - 1 do
    if IsRdf(AContainer.Child(J), 'li') then
      AItems.Add(AContainer.Child(J));
end;

{ How often the property ANs:ALocal occurs in the resource ARes. }
function PropCount(ARes: TXmpNode; const ANs, ALocal: TLandrixEInvoiceString): Integer;
var
  I: Integer;
begin
  Result := 0;
  if ARes = nil then
    Exit;
  for I := 0 to ARes.Count - 1 do
    if (ARes.Child(I).Ns = ANs) and (ARes.Child(I).Local = ALocal) then
      Inc(Result);
end;

{ Code list HybridConformanceType without COMFORT (Order-X only).
  DE: Codeliste HybridConformanceType ohne COMFORT (nur Order-X). }
function IsConformanceLevel(const S: TLandrixEInvoiceString): Boolean;
begin
  Result := (S = 'MINIMUM') or (S = 'BASIC WL') or (S = 'BASIC') or (S = 'EN 16931') or (S = 'EXTENDED') or
    (S = 'XRECHNUNG');
end;

{ A version of the form 3.0: digits, a dot, digits. }
function IsVersionNumber(const S: TLandrixEInvoiceString): Boolean;
var
  I, Dot: Integer;
begin
  Result := False;
  Dot := 0;
  for I := 1 to Length(S) do
    if S[I] = '.' then
    begin
      if Dot <> 0 then
        Exit;
      Dot := I;
    end
    else if (S[I] < '0') or (S[I] > '9') then
      Exit;
  Result := (Dot > 1) and (Dot < Length(S));
end;

type
  TMetadataCheck = class(TObject)
  private
    FDoc: TLandrixEInvoicePdfDocument;
    FResult: TLandrixEInvoicePdfCheckResult;
    FRoot: TXmpNode;
    { the top-level rdf:Description elements }
    FDescs: TObjectList;
    FIncomplete: Boolean;
    procedure Add(const ARule: TLandrixEInvoiceString; ASeverity: TLandrixEInvoiceDiagnosticSeverity;
      const APath, AMessage: TLandrixEInvoiceString; ALine: Integer = 0; AColumn: Integer = 0);
    procedure CollectDescriptions(N: TXmpNode);
    function TopProp(const ANs, ALocal: TLandrixEInvoiceString): TXmpNode;
    procedure CheckUnique(const ARule, APrefix, ANs, ALocal: TLandrixEInvoiceString);
    procedure CheckUniqueIn(ARes: TXmpNode; const APrefix, ANs, ALocal: TLandrixEInvoiceString);
    function CheckContainer(AProp: TXmpNode; const AName, AKind: TLandrixEInvoiceString): TXmpNode;
    function ReadPacket: Boolean;
    procedure CheckPdfAId;
    procedure CheckExtensionSchema;
    procedure CheckProperties;
  public
    constructor Create(ADoc: TLandrixEInvoicePdfDocument; AResult: TLandrixEInvoicePdfCheckResult);
    destructor Destroy; override;
    procedure Run;
    property Incomplete: Boolean read FIncomplete;
  end;

constructor TMetadataCheck.Create(ADoc: TLandrixEInvoicePdfDocument; AResult: TLandrixEInvoicePdfCheckResult);
begin
  inherited Create;
  FDoc := ADoc;
  FResult := AResult;
  FRoot := TXmpNode.Create;
  FDescs := TObjectList.Create(False);
end;

destructor TMetadataCheck.Destroy;
begin
  FDescs.Free;
  FRoot.Free;
  inherited Destroy;
end;

procedure TMetadataCheck.Add(const ARule: TLandrixEInvoiceString; ASeverity: TLandrixEInvoiceDiagnosticSeverity;
  const APath, AMessage: TLandrixEInvoiceString; ALine, AColumn: Integer);
var
  D: TLandrixEInvoiceDiagnostic;
begin
  D := FResult.Diagnostics.AddDiagnostic(edk_RuleViolation, APath, ALine, AColumn, 0, AMessage);
  D.Severity := ASeverity;
  D.RuleID := ARule;
end;


{ The rdf:Description children of every rdf:RDF (usually in x:xmpmeta). }
procedure TMetadataCheck.CollectDescriptions(N: TXmpNode);
var
  I, J: Integer;
  C: TXmpNode;
begin
  for I := 0 to N.Count - 1 do
  begin
    C := N.Child(I);
    if IsRdf(C, 'RDF') then
    begin
      for J := 0 to C.Count - 1 do
        if IsRdf(C.Child(J), 'Description') then
          FDescs.Add(C.Child(J));
    end
    else if not C.IsAttr then
      CollectDescriptions(C);
  end;
end;

function TMetadataCheck.TopProp(const ANs, ALocal: TLandrixEInvoiceString): TXmpNode;
var
  I: Integer;
begin
  Result := nil;
  for I := 0 to Integer(FDescs.Count) - 1 do
  begin
    Result := PropOf(TXmpNode(FDescs[I]), ANs, ALocal);
    if Result <> nil then
      Exit;
  end;
end;

{ XMP allows one value per property: a second occurrence (also one in
  attribute and one in element form) is an error of the rule of the
  property.
  DE: XMP erlaubt einen Wert je Eigenschaft: ein zweites Vorkommen (auch
  eines in Attribut- und eines in Elementform) ist ein Fehler der Regel der
  Eigenschaft. }
procedure TMetadataCheck.CheckUnique(const ARule, APrefix, ANs, ALocal: TLandrixEInvoiceString);
var
  I, N: Integer;
begin
  N := 0;
  for I := 0 to Integer(FDescs.Count) - 1 do
    Inc(N, PropCount(TXmpNode(FDescs[I]), ANs, ALocal));
  if N > 1 then
    Add(ARule, eds_Error, 'XMP ' + APrefix + ':' + ALocal, APrefix + ':' + ALocal + ' occurs ' + IntText(N) +
      ' times; XMP allows one value');
end;

{ The same for a property of an extension schema resource (BR-HYBRID-03).
  DE: Dasselbe fuer eine Eigenschaft einer Ressource des
  Erweiterungsschemas (BR-HYBRID-03). }
procedure TMetadataCheck.CheckUniqueIn(ARes: TXmpNode; const APrefix, ANs, ALocal: TLandrixEInvoiceString);
var
  N: Integer;
begin
  N := PropCount(ARes, ANs, ALocal);
  if N > 1 then
    Add(RuleExtensionSchema, eds_Error, 'XMP ' + APrefix + ':' + ALocal, APrefix + ':' + ALocal + ' occurs ' +
      IntText(N) + ' times; XMP allows one value');
end;

{ The container of AProp if it is an rdf:AKind (BR-HYBRID-03: the schemas
  are an rdf:Bag, the properties of a schema an rdf:Seq); otherwise an
  error and nil.
  DE: Der Behaelter von AProp, wenn er ein rdf:AKind ist (BR-HYBRID-03:
  die Schemata sind ein rdf:Bag, die Eigenschaften eines Schemas eine
  rdf:Seq); sonst ein Fehler und nil. }
function TMetadataCheck.CheckContainer(AProp: TXmpNode; const AName, AKind: TLandrixEInvoiceString): TXmpNode;
var
  I, N: Integer;
begin
  Result := ContainerOf(AProp);
  N := 0;
  if AProp <> nil then
    for I := 0 to AProp.Count - 1 do
      if not AProp.Child(I).IsAttr then
        Inc(N);
  if N > 1 then
  begin
    Add(RuleExtensionSchema, eds_Error, 'XMP ' + AName, AName + ' has ' + IntText(N) + ' elements; expected one rdf:' +
      AKind);
    Result := nil;
  end
  else if Result = nil then
    Add(RuleExtensionSchema, eds_Error, 'XMP ' + AName, AName + ' is no rdf:' + AKind)
  else if Result.Local <> AKind then
  begin
    Add(RuleExtensionSchema, eds_Error, 'XMP ' + AName, AName + ' is an rdf:' + Result.Local + '; expected rdf:' +
      AKind);
    Result := nil;
  end;
end;

{ LX-PDF-11: the catalog has a /Metadata stream that decodes to
  well-formed XMP with rdf:RDF and rdf:Description.
  DE: LX-PDF-11: der Katalog hat einen /Metadata-Stream, der sich zu
  wohlgeformtem XMP mit rdf:RDF und rdf:Description dekodieren laesst. }
function TMetadataCheck.ReadPacket: Boolean;
var
  Meta: TLandrixEInvoicePdfObject;
  Data: TLandrixEInvoicePdfBytes;
  Err: TLandrixEInvoiceString;
  Limit: Boolean;
  Line, Column: Integer;
begin
  Result := False;
  Meta := nil;
  if FDoc.Catalog <> nil then
    Meta := FDoc.DGet(FDoc.Catalog, 'Metadata');
  if Meta = nil then
  begin
    Add(RuleNoXmp, eds_Error, '/Root/Metadata', 'The PDF has no XMP metadata (/Metadata of the catalog)');
    Exit;
  end;
  if Meta.Kind <> pok_Stream then
  begin
    Add(RuleNoXmp, eds_Error, '/Root/Metadata', 'The /Metadata of the catalog is no stream');
    Exit;
  end;
  if not FDoc.GetStreamData(Meta, Data) then
  begin
    Add(RuleNoXmp, eds_Error, '/Root/Metadata', 'The XMP metadata cannot be decoded: ' + ToText(FDoc.StreamError));
    Exit;
  end;
  Err := ParseXmp(Data, FRoot, Limit, Line, Column);
  if Limit then
  begin
    FIncomplete := True;
    Add(RuleLimit, eds_Warning, '/Root/Metadata', 'The XMP metadata is ' + Err + '; not checked');
    Exit;
  end;
  if Err <> '' then
  begin
    Add(RuleNoXmp, eds_Error, '/Root/Metadata', 'The XMP metadata is ' + Err, Line, Column);
    Exit;
  end;
  CollectDescriptions(FRoot);
  if FDescs.Count = 0 then
  begin
    Add(RuleNoXmp, eds_Error, '/Root/Metadata', 'The XMP metadata has no rdf:RDF with rdf:Description');
    Exit;
  end;
  Result := True;
end;

{ BR-HYBRID-02 as far as the XMP tells: pdfaid:part 3 with the
  conformance level A, B or U, or part 4 with F (PDF/A-4f). Whether the
  file really conforms is level 1.
  DE: BR-HYBRID-02, soweit das XMP es sagt: pdfaid:part 3 mit der
  Konformitaetsstufe A, B oder U oder Teil 4 mit F (PDF/A-4f). Ob die Datei
  wirklich konform ist, prueft Ebene 1. }
procedure TMetadataCheck.CheckPdfAId;
var
  Part, Conf: TLandrixEInvoiceString;
begin
  Part := ValueOf(TopProp(NsPdfAId, 'part'));
  Conf := ValueOf(TopProp(NsPdfAId, 'conformance'));
  FResult.PdfAPart := Part;
  FResult.PdfAConformance := Conf;
  CheckUnique(RuleNoPdfA, 'pdfaid', NsPdfAId, 'part');
  CheckUnique(RuleNoPdfA, 'pdfaid', NsPdfAId, 'conformance');
  if Part = '3' then
  begin
    if (Conf <> 'A') and (Conf <> 'B') and (Conf <> 'U') then
      Add(RuleNoPdfA, eds_Error, 'XMP pdfaid:conformance', 'The XMP metadata claims PDF/A-3 with the conformance ' +
        'level "' + Conf + '"; expected A, B or U');
  end
  else if Part = '4' then
  begin
    if Conf <> 'F' then
      Add(RuleNoPdfA, eds_Error, 'XMP pdfaid:conformance', 'The XMP metadata claims PDF/A-4 with the conformance ' +
        'level "' + Conf + '"; a hybrid document in PDF/A-4 is PDF/A-4f');
  end
  else if Part = '' then
    Add(RuleNoPdfA, eds_Error, 'XMP pdfaid:part', 'The XMP metadata claims no PDF/A part; a hybrid document is ' +
      'PDF/A-3 or PDF/A-4f')
  else
    Add(RuleNoPdfA, eds_Error, 'XMP pdfaid:part', 'The XMP metadata claims PDF/A part ' + Part + '; a hybrid ' +
      'document is PDF/A-3 or PDF/A-4f');
end;

{ BR-HYBRID-03/-04/-05: the PDF/A extension schema (pdfaExtension:schemas)
  declares the namespace of Factur-X with the prefix fx and its four
  properties as Text, external, with a description, the schema with a
  name; the schemas in an rdf:Bag, the properties in an rdf:Seq
  (specification 6.3.1, ISO 19005-2 6.6.2.3.3).
  DE: BR-HYBRID-03/-04/-05: das PDF/A-Erweiterungsschema
  (pdfaExtension:schemas) deklariert den Namensraum von Factur-X mit dem
  Praefix fx und seine vier Eigenschaften als Text, external, mit
  Beschreibung, das Schema mit Namen; die Schemata in einem rdf:Bag, die
  Eigenschaften in einer rdf:Seq (Spezifikation 6.3.1, ISO 19005-2
  6.6.2.3.3). }
procedure TMetadataCheck.CheckExtensionSchema;
var
  Items, Props: TObjectList;
  Schema, Res, Found: TXmpNode;
  Uri, Near, Prefix, Path, Name: TLandrixEInvoiceString;
  I, J: Integer;
begin
  if TopProp(NsPdfAExtension, 'schemas') = nil then
  begin
    Add(RuleExtensionSchema, eds_Error, 'XMP pdfaExtension:schemas', 'The XMP metadata has no PDF/A extension ' +
      'schema (pdfaExtension:schemas)');
    Exit;
  end;
  { a second pdfaExtension:schemas is a PDF/A error of its own; all of
    them are searched }
  CheckUnique(RuleExtensionSchema, 'pdfaExtension', NsPdfAExtension, 'schemas');
  Items := TObjectList.Create(False);
  Props := TObjectList.Create(False);
  try
    for I := 0 to Integer(FDescs.Count) - 1 do
      for J := 0 to TXmpNode(FDescs[I]).Count - 1 do
        if (TXmpNode(FDescs[I]).Child(J).Ns = NsPdfAExtension) and (TXmpNode(FDescs[I]).Child(J).Local = 'schemas') then
          ItemsOf(CheckContainer(TXmpNode(FDescs[I]).Child(J), 'pdfaExtension:schemas', 'Bag'), Items);
    Schema := nil;
    Near := '';
    for I := 0 to Integer(Items.Count) - 1 do
    begin
      Res := ResourceOf(TXmpNode(Items[I]));
      Uri := ValueOf(PropOf(Res, NsPdfASchema, 'namespaceURI'));
      if Uri = NsFacturX then
      begin
        Schema := Res;
        Break;
      end;
      if AsciiLower(Uri) = AsciiLower(NsFacturX) then
        Near := Uri;
    end;
    if Schema = nil then
    begin
      if Near <> '' then
        Add(RuleNamespace, eds_Error, 'XMP pdfaSchema:namespaceURI', 'The extension schema declares the namespace ' +
          Near + '; expected ' + NsFacturX)
      else
        Add(RuleExtensionSchema, eds_Error, 'XMP pdfaExtension:schemas', 'The extension schema does not declare the ' +
          'namespace ' + NsFacturX);
      Exit;
    end;
    CheckUniqueIn(Schema, 'pdfaSchema', NsPdfASchema, 'schema');
    CheckUniqueIn(Schema, 'pdfaSchema', NsPdfASchema, 'namespaceURI');
    CheckUniqueIn(Schema, 'pdfaSchema', NsPdfASchema, 'prefix');
    CheckUniqueIn(Schema, 'pdfaSchema', NsPdfASchema, 'property');
    Prefix := ValueOf(PropOf(Schema, NsPdfASchema, 'prefix'));
    if Prefix <> 'fx' then
      Add(RulePrefix, eds_Error, 'XMP pdfaSchema:prefix', 'The extension schema declares the prefix "' + Prefix +
        '"; expected fx');
    if ValueOf(PropOf(Schema, NsPdfASchema, 'schema')) = '' then
      Add(RuleExtensionSchema, eds_Error, 'XMP pdfaSchema:schema', 'The extension schema of ' + NsFacturX +
        ' has no name (pdfaSchema:schema)');
    ItemsOf(CheckContainer(PropOf(Schema, NsPdfASchema, 'property'), 'pdfaSchema:property', 'Seq'), Props);
    for J := Low(FacturXProperties) to High(FacturXProperties) do
    begin
      Name := ToText(FacturXProperties[J]);
      Found := nil;
      for I := 0 to Integer(Props.Count) - 1 do
      begin
        Res := ResourceOf(TXmpNode(Props[I]));
        if ValueOf(PropOf(Res, NsPdfAProperty, 'name')) = Name then
        begin
          Found := Res;
          Break;
        end;
      end;
      Path := 'XMP pdfaSchema:property ' + Name;
      if Found = nil then
        Add(RuleExtensionSchema, eds_Error, 'XMP pdfaSchema:property', 'The extension schema declares no property ' +
          Name)
      else
      begin
        CheckUniqueIn(Found, 'pdfaProperty', NsPdfAProperty, 'name');
        CheckUniqueIn(Found, 'pdfaProperty', NsPdfAProperty, 'valueType');
        CheckUniqueIn(Found, 'pdfaProperty', NsPdfAProperty, 'category');
        CheckUniqueIn(Found, 'pdfaProperty', NsPdfAProperty, 'description');
        if ValueOf(PropOf(Found, NsPdfAProperty, 'valueType')) <> 'Text' then
          Add(RuleExtensionSchema, eds_Error, Path, 'The property ' + Name + ' has the value type "' +
            ValueOf(PropOf(Found, NsPdfAProperty, 'valueType')) + '"; expected Text');
        if ValueOf(PropOf(Found, NsPdfAProperty, 'category')) <> 'external' then
          Add(RuleExtensionSchema, eds_Error, Path, 'The property ' + Name + ' has the category "' +
            ValueOf(PropOf(Found, NsPdfAProperty, 'category')) + '"; expected external');
        if ValueOf(PropOf(Found, NsPdfAProperty, 'description')) = '' then
          Add(RuleExtensionSchema, eds_Error, Path, 'The property ' + Name + ' has no description');
      end;
    end;
  finally
    Props.Free;
    Items.Free;
  end;
end;

{ BR-HYBRID-04 to -10 and -14: the Factur-X properties in their namespace
  with the prefix fx and values from the code lists (owner decisions
  2026-11-11: EN16931 without a blank is an error; for XRECHNUNG any
  version like 3.0 is accepted, chapter 7.7, all official samples).
  DE: BR-HYBRID-04 bis -10 und -14: die Factur-X-Eigenschaften in ihrem
  Namensraum mit dem Praefix fx und Werten aus den Codelisten
  (Entscheidungen des Eigentuemers 2026-11-11: EN16931 ohne Leerzeichen ist
  ein Fehler; bei XRECHNUNG gilt jede Version wie 3.0, Kapitel 7.7, alle
  offiziellen Beispiele). }
procedure TMetadataCheck.CheckProperties;
const
  { the rule of each property in FacturXProperties }
  Rules: array[0..3] of string = (RuleXmpFileName, RuleDocumentType, RuleVersion, RuleConformance);
var
  Ns, Other, DocType, FileName, Version, Level: TLandrixEInvoiceString;
  P: array[0..3] of TXmpNode;
  I, J: Integer;
  D, C: TXmpNode;
begin
  Ns := NsFacturX;
  for J := 0 to 3 do
    P[J] := TopProp(Ns, ToText(FacturXProperties[J]));
  if (P[0] = nil) and (P[1] = nil) and (P[2] = nil) and (P[3] = nil) then
  begin
    { the properties under another namespace: wrong case, an old URI }
    Other := '';
    for I := 0 to Integer(FDescs.Count) - 1 do
    begin
      D := TXmpNode(FDescs[I]);
      for J := 0 to D.Count - 1 do
      begin
        C := D.Child(J);
        if (Other = '') and (C.Ns <> NsFacturX) and ((C.Local = 'ConformanceLevel') or (C.Local = 'DocumentType') or
           (C.Local = 'DocumentFileName')) then
          Other := C.Ns;
      end;
    end;
    if Other = '' then
    begin
      Add(RuleNamespace, eds_Error, 'XMP fx', 'The XMP metadata has no Factur-X properties (namespace ' + NsFacturX +
        ')');
      Exit;
    end;
    Add(RuleNamespace, eds_Error, 'XMP fx', 'The Factur-X properties use the namespace ' + Other + '; expected ' +
      NsFacturX);
    Ns := Other;
    for J := 0 to 3 do
      P[J] := TopProp(Ns, ToText(FacturXProperties[J]));
  end;
  for J := 0 to 3 do
    CheckUnique(ToText(Rules[J]), 'fx', Ns, ToText(FacturXProperties[J]));
  for J := 0 to 3 do
    if (P[J] <> nil) and (P[J].Prefix <> 'fx') then
    begin
      Add(RulePrefix, eds_Error, 'XMP ' + P[J].Prefix + ':' + P[J].Local, 'The Factur-X properties use the prefix "' +
        P[J].Prefix + '"; expected fx');
      Break;
    end;
  FileName := ValueOf(P[0]);
  DocType := ValueOf(P[1]);
  Version := ValueOf(P[2]);
  Level := ValueOf(P[3]);
  FResult.XmpDocumentFileName := FileName;
  FResult.XmpDocumentType := DocType;
  FResult.XmpVersion := Version;
  FResult.XmpConformanceLevel := Level;

  { BR-HYBRID-06, code list HybridDocumentType }
  if DocType = '' then
    Add(RuleDocumentType, eds_Error, 'XMP fx:DocumentType', 'fx:DocumentType is missing; expected INVOICE')
  else if (DocType = 'ORDER') or (DocType = 'ORDER_RESPONSE') or (DocType = 'ORDER_CHANGE') then
    Add(RuleDocumentType, eds_Error, 'XMP fx:DocumentType', 'fx:DocumentType is ' + DocType + ', a type of Order-X; ' +
      'expected INVOICE')
  else if DocType <> 'INVOICE' then
    Add(RuleDocumentType, eds_Error, 'XMP fx:DocumentType', 'fx:DocumentType "' + DocType + '" is not in the code ' +
      'list HybridDocumentType; expected INVOICE');

  { BR-HYBRID-07, code list HybridConformanceType }
  if Level = '' then
    Add(RuleConformance, eds_Error, 'XMP fx:ConformanceLevel', 'fx:ConformanceLevel is missing')
  else if Level = 'COMFORT' then
    Add(RuleConformance, eds_Error, 'XMP fx:ConformanceLevel', 'fx:ConformanceLevel COMFORT is a profile of Order-X')
  else if not IsConformanceLevel(Level) then
    Add(RuleConformance, eds_Error, 'XMP fx:ConformanceLevel', 'fx:ConformanceLevel "' + Level + '" is not in the ' +
      'code list HybridConformanceType');

  { BR-HYBRID-08, code list HybridDocumentFilename with its usage rules }
  if FileName = '' then
    Add(RuleXmpFileName, eds_Error, 'XMP fx:DocumentFileName', 'fx:DocumentFileName is missing')
  else if FileName = 'order-x.xml' then
    Add(RuleXmpFileName, eds_Error, 'XMP fx:DocumentFileName', 'fx:DocumentFileName order-x.xml belongs to Order-X')
  else if not IsHybridFileName(FileName) then
    Add(RuleXmpFileName, eds_Error, 'XMP fx:DocumentFileName', 'fx:DocumentFileName "' + FileName + '" is not in ' +
      'the code list HybridDocumentFilename')
  else if (FileName = 'xrechnung.xml') and IsConformanceLevel(Level) and (Level <> 'XRECHNUNG') then
    Add(RuleXmpFileName, eds_Error, 'XMP fx:DocumentFileName', 'fx:DocumentFileName xrechnung.xml needs ' +
      'fx:ConformanceLevel XRECHNUNG, not ' + Level)
  else if (FileName = 'factur-x.xml') and (Level = 'XRECHNUNG') then
    Add(RuleXmpFileName, eds_Error, 'XMP fx:DocumentFileName', 'fx:ConformanceLevel XRECHNUNG needs ' +
      'fx:DocumentFileName xrechnung.xml, not factur-x.xml');

  { BR-HYBRID-09, code list HybridDocumentVersion; BR-HYBRID-10 }
  if Version = '' then
    Add(RuleVersion, eds_Error, 'XMP fx:Version', 'fx:Version is missing')
  else if not ((Version = '1.0') or (Version = '1p0') or (Version = '2p0') or (Version = '2p1') or
     (Version = '2p2') or ((Level = 'XRECHNUNG') and IsVersionNumber(Version))) then
    Add(RuleVersion, eds_Error, 'XMP fx:Version', 'fx:Version "' + Version + '" is not in the code list ' +
      'HybridDocumentVersion')
  else if Version <> '1.0' then
    Add(RuleVersionOne, eds_Warning, 'XMP fx:Version', 'fx:Version is ' + Version + '; the specification ' +
      'recommends 1.0');

  { BR-HYBRID-14: the name of the embedded invoice }
  if (FileName <> '') and (((FResult.InvoiceFileNameF <> '') and (FResult.InvoiceFileNameF <> FileName)) or
     ((FResult.InvoiceFileNameUF <> '') and (FResult.InvoiceFileNameUF <> FileName))) then
    Add(RuleXmpFileNameMatch, eds_Warning, 'XMP fx:DocumentFileName', 'fx:DocumentFileName is ' + FileName +
      '; the embedded invoice is named ' + FResult.InvoiceFileName);
end;

procedure TMetadataCheck.Run;
begin
  if not ReadPacket then
    Exit;
  CheckPdfAId;
  CheckExtensionSchema;
  CheckProperties;
end;

//==============================================================================
// TLandrixEInvoicePdfChecker
//==============================================================================

function CountErrors(ADiagnostics: TLandrixEInvoiceDiagnostics): Integer;
var
  I: Integer;
begin
  Result := 0;
  for I := 0 to Integer(ADiagnostics.Count) - 1 do
    if ADiagnostics[I].Severity = eds_Error then
      Inc(Result);
end;

procedure AddFinding(AResult: TLandrixEInvoicePdfCheckResult; const ARule: TLandrixEInvoiceString;
  ASeverity: TLandrixEInvoiceDiagnosticSeverity; const AMessage: TLandrixEInvoiceString);
var
  D: TLandrixEInvoiceDiagnostic;
begin
  D := AResult.Diagnostics.AddDiagnostic(edk_RuleViolation, '', 0, 0, 0, AMessage);
  D.Severity := ASeverity;
  D.RuleID := ARule;
end;

procedure AddFindingAt(AResult: TLandrixEInvoicePdfCheckResult; const ARule: TLandrixEInvoiceString;
  ASeverity: TLandrixEInvoiceDiagnosticSeverity; const APath, AMessage: TLandrixEInvoiceString);
var
  D: TLandrixEInvoiceDiagnostic;
begin
  D := AResult.Diagnostics.AddDiagnostic(edk_RuleViolation, APath, 0, 0, 0, AMessage);
  D.Severity := ASeverity;
  D.RuleID := ARule;
end;

function LevelStatus(AErrors: Integer; AIncomplete: Boolean): TLandrixEInvoicePdfLevelStatus;
begin
  if AErrors > 0 then
    Result := eps_Failed
  else if AIncomplete then
    Result := eps_Incomplete
  else
    Result := eps_Passed;
end;

function TLandrixEInvoicePdfChecker.CheckStream(AStream: TStream; AResult: TLandrixEInvoicePdfCheckResult): Integer;
var
  Doc: TLandrixEInvoicePdfDocument;
  Check: TEmbeddingCheck;
  Meta: TMetadataCheck;
  Err: string;
  Incomplete, EmbeddingIncomplete, MetaIncomplete: Boolean;
  Errors: Integer;
begin
  Result := 0;
  if AResult = nil then
    Exit;
  AResult.Clear;
  AResult.Status[epl_Embedding] := eps_Failed;
  if AStream = nil then
  begin
    AddFinding(AResult, RuleUnreadable, eds_Error, 'No stream given');
    Result := 1;
    Exit;
  end;
  Doc := TLandrixEInvoicePdfDocument.Create;
  try
    try
      if not Doc.Load(AStream, Err) then
      begin
        AddFinding(AResult, RuleUnreadable, eds_Error, ToText('PDF not readable: ' + Err));
        Result := 1;
        Exit;
      end;
    except
      on E: Exception do
      begin
        AddFinding(AResult, RuleUnreadable, eds_Error, ToText('PDF not readable: ' + E.Message));
        Result := 1;
        Exit;
      end;
    end;
    if Doc.HeaderPos + 8 <= Length(Doc.Buf) then
      AResult.PdfVersion := AnsiToText(LandrixEInvoicePdfBytesToAnsi(Doc.Buf, Doc.HeaderPos + 5, 3));
    if Doc.CryptError <> '' then
    begin
      AddFinding(AResult, RuleUnreadable, eds_Error, ToText('PDF not readable: ' + Doc.CryptError));
      Result := 1;
      Exit;
    end;
    AResult.CatalogVersion := AnsiToText(Doc.CatalogVersion);
    Incomplete := Doc.Reconstructed;
    if Incomplete then
      AddFinding(AResult, RuleReconstructed, eds_Warning,
        'The cross-reference table is unusable; the objects were found by a scan of the file');
    EmbeddingIncomplete := False;
    Check := TEmbeddingCheck.Create(Doc, AResult);
    try
      try
        Check.Run;
        EmbeddingIncomplete := Check.Incomplete;
      except
        on E: Exception do
          AddFinding(AResult, RuleUnreadable, eds_Error, ToText('PDF not readable: ' + E.Message));
      end;
    finally
      Check.Free;
    end;
    Errors := CountErrors(AResult.Diagnostics);
    AResult.Status[epl_Embedding] := LevelStatus(Errors, Incomplete or EmbeddingIncomplete);
    if AResult.HybridKind in [ehk_ZUGFeRD10, ehk_ZUGFeRD20] then
      AResult.Status[epl_Metadata] := eps_Incomplete
    else if AResult.HybridKind <> ehk_None then
    begin
      MetaIncomplete := False;
      Meta := TMetadataCheck.Create(Doc, AResult);
      try
        try
          Meta.Run;
          MetaIncomplete := Meta.Incomplete;
        except
          on E: Exception do
            AddFindingAt(AResult, RuleNoXmp, eds_Error, '/Root/Metadata', ToText('XMP metadata not readable: ' +
              E.Message));
        end;
      finally
        Meta.Free;
      end;
      AResult.Status[epl_Metadata] := LevelStatus(CountErrors(AResult.Diagnostics) - Errors,
        Incomplete or MetaIncomplete);
    end;
  finally
    Doc.Free;
  end;
  Result := CountErrors(AResult.Diagnostics);
end;

{ The ZUGFeRD profile of a target: Factur-X its profile, XRechnung CII the
  profile XRECHNUNG, anything else none.
  DE: Das ZUGFeRD-Profil eines Ziels: Factur-X sein Profil, XRechnung CII
  das Profil XRECHNUNG, alles andere keines. }
function HybridProfile(const ATarget: TLandrixEInvoiceTarget): TLandrixEInvoiceProfile;
begin
  Result := epr_None;
  if ATarget.Standard = est_FacturX then
    Result := ATarget.Profile
  else if (ATarget.Standard = est_XRechnung) and (ATarget.Syntax = esy_CII) then
    Result := epr_XRechnung;
end;

function ProfileText(AProfile: TLandrixEInvoiceProfile): TLandrixEInvoiceString;
const
  Names: array[TLandrixEInvoiceProfile] of string = ('none', 'MINIMUM', 'BASIC WL', 'BASIC', 'EN 16931',
    'EXTENDED', 'XRECHNUNG');
begin
  Result := ToText(Names[AProfile]);
end;

{ Code list HybridDocumentFilename, usage rules: xrechnung.xml needs the
  profile XRECHNUNG, factur-x.xml must not have it (BR-HYBRID-13).
  DE: Codeliste HybridDocumentFilename, Verwendungsregeln: xrechnung.xml
  verlangt das Profil XRECHNUNG, factur-x.xml darf es nicht haben
  (BR-HYBRID-13). }
procedure CheckNameAndProfile(AResult: TLandrixEInvoicePdfCheckResult; const AName, AKey: TLandrixEInvoiceString);
begin
  if (AName = 'xrechnung.xml') and (AResult.Profile <> epr_XRechnung) then
    AddFindingAt(AResult, RuleFileName, eds_Error, AResult.InvoicePath + AKey, 'The file name xrechnung.xml ' +
      'needs the profile XRECHNUNG; the invoice has the profile ' + ProfileText(AResult.Profile))
  else if (AName = 'factur-x.xml') and (AResult.Profile = epr_XRechnung) then
    AddFindingAt(AResult, RuleFileName, eds_Error, AResult.InvoicePath + AKey, 'An invoice of the profile ' +
      'XRECHNUNG is named xrechnung.xml, not factur-x.xml');
end;

{ BR-HYBRID-11 per profile and country (specification 6.2.2): MINIMUM and
  BASIC WL Data; BASIC, EN 16931, EXTENDED Alternative in Germany and
  Alternative, Source or Data in France; XRECHNUNG Alternative (not
  applicable in France, see BR-HYBRID-FR-01). The column of a country
  applies only when seller and buyer are both in it (owner decision
  2026-11-02); otherwise the profile row over both columns. A value outside
  Data, Source and Alternative has its warning from CheckStream already.
  DE: BR-HYBRID-11 je Profil und Land (Spezifikation 6.2.2): MINIMUM und
  BASIC WL Data; BASIC, EN 16931, EXTENDED in Deutschland Alternative, in
  Frankreich Alternative, Source oder Data; XRECHNUNG Alternative (in
  Frankreich nicht anwendbar, siehe BR-HYBRID-FR-01). Die Spalte eines
  Landes gilt nur, wenn Verkaeufer und Kaeufer beide dort sind
  (Entscheidung des Eigentuemers 2026-11-02); sonst die Profilzeile ueber
  beide Spalten. Ein Wert ausserhalb von Data, Source und Alternative hat
  seine Warnung schon aus CheckStream. }
procedure CheckRelationship(AResult: TLandrixEInvoicePdfCheckResult; const ACountry: TLandrixEInvoiceString);
var
  Rel, Allowed: TLandrixEInvoiceString;
begin
  Rel := AResult.InvoiceRelationship;
  if (Rel <> 'Data') and (Rel <> 'Source') and (Rel <> 'Alternative') then
    Exit;
  case AResult.Profile of
    epr_Minimum, epr_BasicWL:
      Allowed := 'Data';
    epr_Basic, epr_EN16931, epr_Extended:
      if ACountry = 'DE' then
        Allowed := 'Alternative'
      else
        Allowed := '';
    epr_XRechnung:
      if ACountry = 'FR' then
        Allowed := ''
      else
        Allowed := 'Alternative';
  else
    Allowed := '';
  end;
  if (Allowed <> '') and (Rel <> Allowed) then
  begin
    if ACountry <> '' then
      AddFindingAt(AResult, RuleRelationship, eds_Warning, AResult.InvoicePath + '/AFRelationship',
        '/AFRelationship is /' + Rel + '; the table of the specification asks for /' + Allowed + ' for the profile ' +
        ProfileText(AResult.Profile) + ' with seller and buyer in ' + ACountry)
    else
      AddFindingAt(AResult, RuleRelationship, eds_Warning, AResult.InvoicePath + '/AFRelationship',
        '/AFRelationship is /' + Rel + '; the table of the specification asks for /' + Allowed + ' for the profile ' +
        ProfileText(AResult.Profile));
  end;
end;

function TLandrixEInvoicePdfChecker.CheckInvoiceFacts(AResult: TLandrixEInvoicePdfCheckResult;
  const AFacts: TLandrixEInvoicePdfInvoiceFacts): Integer;
var
  Before: Integer;
  Country: TLandrixEInvoiceString;
begin
  Result := 0;
  if AResult = nil then
    Exit;
  Before := CountErrors(AResult.Diagnostics);
  Result := Before;
  if AResult.FactsChecked or (AResult.Status[epl_Embedding] = eps_NotRun) or
     (AResult.HybridKind in [ehk_None, ehk_ZUGFeRD10, ehk_ZUGFeRD20]) then
    Exit;
  AResult.FactsChecked := True;
  AResult.InvoiceFacts := AFacts;
  AResult.Profile := HybridProfile(AFacts.Target);
  if AFacts.Target.Syntax = esy_UBL then
    AddFindingAt(AResult, RuleNotCII, eds_Error, AResult.InvoicePath, 'The embedded invoice is UBL; a hybrid document holds ' +
      'a CII invoice of a ZUGFeRD profile')
  else if AResult.Profile <> epr_None then
  begin
    if AResult.InvoiceFileNameF <> '' then
      CheckNameAndProfile(AResult, AResult.InvoiceFileNameF, '/F');
    if AResult.InvoiceFileNameUF <> '' then
      CheckNameAndProfile(AResult, AResult.InvoiceFileNameUF, '/UF');
    Country := '';
    if (AFacts.SellerCountryCode = AFacts.BuyerCountryCode) and
       ((AFacts.SellerCountryCode = 'DE') or (AFacts.SellerCountryCode = 'FR')) then
      Country := AFacts.SellerCountryCode;
    { BR-HYBRID-DE-01/02: seller and buyer in Germany, no MINIMUM and no
      BASIC WL; BR-HYBRID-FR-01: in France, no XRECHNUNG.
      DE: BR-HYBRID-DE-01/02: Verkaeufer und Kaeufer in Deutschland, kein
      MINIMUM und kein BASIC WL; BR-HYBRID-FR-01: in Frankreich kein
      XRECHNUNG. }
    if (Country = 'DE') and (AResult.Profile = epr_Minimum) then
      AddFindingAt(AResult, RuleNoMinimum, eds_Error, AResult.InvoicePath, 'Seller and buyer are in Germany; the profile ' +
        'MINIMUM must not be used')
    else if (Country = 'DE') and (AResult.Profile = epr_BasicWL) then
      AddFindingAt(AResult, RuleNoBasicWL, eds_Error, AResult.InvoicePath, 'Seller and buyer are in Germany; the profile ' +
        'BASIC WL must not be used')
    else if (Country = 'FR') and (AResult.Profile = epr_XRechnung) then
      AddFindingAt(AResult, RuleNoXRechnung, eds_Error, AResult.InvoicePath, 'Seller and buyer are in France; the profile ' +
        'XRECHNUNG must not be used');
    CheckRelationship(AResult, Country);
    { BR-HYBRID-15: fx:ConformanceLevel and the profile of the invoice; a
      value outside the code list has its error from level 3 already.
      DE: BR-HYBRID-15: fx:ConformanceLevel und das Profil der Rechnung; ein
      Wert ausserhalb der Codeliste hat seinen Fehler schon aus Ebene 3. }
    if (AResult.Status[epl_Metadata] <> eps_NotRun) and IsConformanceLevel(AResult.XmpConformanceLevel) and
       (AResult.XmpConformanceLevel <> ProfileText(AResult.Profile)) then
      AddFindingAt(AResult, RuleXmpProfileMatch, eds_Warning, 'XMP fx:ConformanceLevel', 'fx:ConformanceLevel is ' +
        AResult.XmpConformanceLevel + '; the invoice has the profile ' + ProfileText(AResult.Profile));
  end;
  Result := CountErrors(AResult.Diagnostics);
  if Result > Before then
    AResult.Status[epl_Embedding] := eps_Failed;
end;

function TLandrixEInvoicePdfChecker.CheckFile(const AFileName: string; AResult: TLandrixEInvoicePdfCheckResult): Integer;
var
  Stream: TFileStream;
begin
  Result := 0;
  if AResult = nil then
    Exit;
  AResult.Clear;
  try
    Stream := TFileStream.Create(AFileName, fmOpenRead or fmShareDenyWrite);
  except
    on E: Exception do
    begin
      AResult.Status[epl_Embedding] := eps_Failed;
      AddFinding(AResult, RuleUnreadable, eds_Error, ToText('File not readable: ' + E.Message));
      Result := 1;
      Exit;
    end;
  end;
  try
    Result := CheckStream(Stream, AResult);
  finally
    Stream.Free;
  end;
end;

end.
