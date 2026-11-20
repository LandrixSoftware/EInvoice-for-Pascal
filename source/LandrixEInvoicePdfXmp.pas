{
  EInvoice-for-Pascal

  Copyright (C) 2026 Landrix Software GmbH & Co. KG

  This file is dual-licensed under:
  - GNU GPL version 3 or later; or
  - the Landrix Software Commercial License.

  See LICENSE and COMMERCIAL-LICENSE.md.

  SPDX-License-Identifier: GPL-3.0-or-later OR LicenseRef-Landrix-Commercial
}

{ An XMP packet read as the PDF/A metadata rules (ISO 19005-2/-3, clause
  6.6) need it: the xpacket header, the encoding, and the properties of the
  RDF with their original prefixes, simple values, structures, arrays and
  qualifiers. The reading follows the RDF grammar of the XMP Specification
  (2005) as the XMP parser of veraPDF applies it, so that a packet counts as
  valid or invalid where veraPDF says so: forms that parser rejects make the
  packet invalid; anything this reader cannot decide with certainty (XML its
  strict reader rejects although a lenient parser might repair it, a
  document type declaration, an encoding it does not know, a limit) leaves
  the packet unknown, never invalid.

  DE: Ein XMP-Paket, gelesen wie es die PDF/A-Metadatenregeln (ISO
  19005-2/-3, Abschnitt 6.6) brauchen: der xpacket-Kopf, das Encoding und
  die Eigenschaften des RDF mit ihren urspruenglichen Praefixen, einfachen
  Werten, Strukturen, Arrays und Qualifiern. Gelesen wird nach der
  RDF-Grammatik der XMP Specification (2005), wie der XMP-Parser von veraPDF
  sie anwendet, damit ein Paket dort gueltig oder ungueltig ist, wo veraPDF
  das sagt: Formen, die dieser Parser ablehnt, machen das Paket ungueltig;
  alles, was dieser Leser nicht sicher entscheiden kann (XML, das sein
  strenger Leser ablehnt, obwohl ein nachsichtiger Parser es reparieren
  koennte, eine Dokumenttyp-Deklaration, ein unbekanntes Encoding, eine
  Grenze), laesst das Paket unbekannt, nie ungueltig. }

{ API: internal. May change in any release; use the facade LandrixEInvoice
  or the stable units instead.
  DE: API: intern. Kann sich in jeder Version aendern; stattdessen die
  Fassade LandrixEInvoice oder die stabilen Units verwenden. }

unit LandrixEInvoicePdfXmp;

{$I LandrixEInvoice.inc}

interface

uses
  Classes,
  Contnrs,
  LandrixEInvoiceTypes,
  LandrixEInvoicePdfObjects;

const
  { The RDF namespace. DE: Der RDF-Namensraum. }
  LandrixEInvoiceXmpNsRdf = 'http://www.w3.org/1999/02/22-rdf-syntax-ns#';
  { The namespace of xml:lang. DE: Der Namensraum von xml:lang. }
  LandrixEInvoiceXmpNsXml = 'http://www.w3.org/XML/1998/namespace';
  { The PDF/A identification schema. DE: Das PDF/A-Identifikationsschema. }
  LandrixEInvoiceXmpNsPdfaId = 'http://www.aiim.org/pdfa/ns/id/';
  { The PDF/A extension schema container schema and the schemas of its
    value types (ISO 19005-3, 6.6.2.3.3).
    DE: Das Containerschema der PDF/A-Erweiterungsschemas und die Schemas
    seiner Werttypen (ISO 19005-3, 6.6.2.3.3). }
  LandrixEInvoiceXmpNsPdfaExtension = 'http://www.aiim.org/pdfa/ns/extension/';
  LandrixEInvoiceXmpNsPdfaSchema = 'http://www.aiim.org/pdfa/ns/schema#';
  LandrixEInvoiceXmpNsPdfaProperty = 'http://www.aiim.org/pdfa/ns/property#';
  LandrixEInvoiceXmpNsPdfaType = 'http://www.aiim.org/pdfa/ns/type#';
  LandrixEInvoiceXmpNsPdfaField = 'http://www.aiim.org/pdfa/ns/field#';
  { The schema entry of the built-in types only (no extension schema), for
    TLandrixEInvoiceXmpSchemaTypes.Validate.
    DE: Der Schema-Eintrag nur der eingebauten Typen (kein
    Erweiterungsschema), fuer TLandrixEInvoiceXmpSchemaTypes.Validate. }
  LandrixEInvoiceXmpPredefinedEntry = -2;

type
  { Valid: the parser of veraPDF accepts the packet as read here; invalid:
    it rejects it (a form proven to be rejected); unknown: not decided.
    DE: Gueltig: der Parser von veraPDF nimmt das Paket an, wie es hier
    gelesen ist; ungueltig: er lehnt es ab (eine Form, deren Ablehnung belegt
    ist); unbekannt: nicht entschieden. }
  TLandrixEInvoiceXmpState = (xms_Valid, xms_Invalid, xms_Unknown);

  { A simple value, a structure (fields) or an array (items).
    DE: Ein einfacher Wert, eine Struktur (Felder) oder ein Array
    (Elemente). }
  TLandrixEInvoiceXmpKind = (xmk_Simple, xmk_Struct, xmk_Array);

  { The form of an array. DE: Die Form eines Arrays. }
  TLandrixEInvoiceXmpArrayForm = (xma_None, xma_Bag, xma_Seq, xma_Alt);

  { A property, field, array item or qualifier. Prefix is the prefix written
    in the packet ('' for the default namespace). An item written as rdf:li
    has IsItem set.
    DE: Eine Eigenschaft, ein Feld, ein Array-Element oder ein Qualifier.
    Prefix ist das im Paket geschriebene Praefix ('' fuer den
    Standard-Namensraum). Ein als rdf:li geschriebenes Element hat IsItem. }
  TLandrixEInvoiceXmpNode = class(TObject)
  private
    FChildren: TObjectList;
    FQualifiers: TObjectList;
    FHasValueChild: Boolean;
    { a qualifier that was a field: the parser names it by its registry
      prefix, not by the prefix written }
    FFromField: Boolean;
  public
    Ns: TLandrixEInvoiceString;
    Local: TLandrixEInvoiceString;
    Prefix: TLandrixEInvoiceString;
    { the name as written (prefix:local or local) }
    Lexical: TLandrixEInvoiceString;
    Kind: TLandrixEInvoiceXmpKind;
    ArrayForm: TLandrixEInvoiceXmpArrayForm;
    Value: TLandrixEInvoiceString;
    IsUri: Boolean;
    IsItem: Boolean;
    constructor Create;
    destructor Destroy; override;
    function ChildCount: Integer;
    function Child(AIndex: Integer): TLandrixEInvoiceXmpNode;
    function QualifierCount: Integer;
    function Qualifier(AIndex: Integer): TLandrixEInvoiceXmpNode;
    { The first field or item ANs/ALocal, nil if there is none.
      DE: Das erste Feld oder Element ANs/ALocal, nil, wenn es keines gibt. }
    function FindChild(const ANs, ALocal: TLandrixEInvoiceString): TLandrixEInvoiceXmpNode;
  end;

  { One XMP packet. After Parse: State and Reason; HasRoot if an rdf:RDF
    was found; the data of the last <?xpacket?> before it (HasHeader,
    Header); the encoding the XML parser of veraPDF reports ('UTF-8',
    'UTF-16BE', 'UTF-16LE'; '' if there is no RDF, the packet is not valid or
    the encoding is unknown); the top-level properties of all
    rdf:Description elements. An invalid or unknown packet has no header and
    no properties.
    DE: Ein XMP-Paket. Nach Parse: State und Reason; HasRoot, wenn ein
    rdf:RDF gefunden wurde; die Daten des letzten <?xpacket?> davor
    (HasHeader, Header); das Encoding, das der XML-Parser von veraPDF meldet
    ('UTF-8', 'UTF-16BE', 'UTF-16LE'; '', wenn es kein RDF gibt, das Paket
    nicht gueltig oder das Encoding unbekannt ist); die Eigenschaften der
    obersten Ebene aller rdf:Description-Elemente. Ein ungueltiges oder
    unbekanntes Paket hat weder Kopf noch Eigenschaften. }
  TLandrixEInvoiceXmpPacket = class(TObject)
  private
    FProps: TObjectList;
    FAbout: TLandrixEInvoiceString;
    FNodes: Integer;
    procedure Clear;
  public
    State: TLandrixEInvoiceXmpState;
    Reason: string;
    HasRoot: Boolean;
    HasHeader: Boolean;
    Header: TLandrixEInvoiceString;
    Encoding: string;
    constructor Create;
    destructor Destroy; override;
    { Reads the decoded bytes of a metadata stream.
      DE: Liest die dekodierten Bytes eines Metadaten-Streams. }
    procedure Parse(const AData: TLandrixEInvoicePdfBytes);
    function PropertyCount: Integer;
    function Prop(AIndex: Integer): TLandrixEInvoiceXmpNode;
    { The top-level property ANs/ALocal, nil if absent.
      DE: Die Eigenschaft ANs/ALocal der obersten Ebene, nil, wenn sie
      fehlt. }
    function Find(const ANs, ALocal: TLandrixEInvoiceString): TLandrixEInvoiceXmpNode;
  end;

  { Yes, no, or not decided. DE: Ja, nein oder nicht entschieden. }
  TLandrixEInvoiceXmpTruth = (xmt_Yes, xmt_No, xmt_Unknown);

  { A value type an extension schema defines: its simplified name, the
    namespace of its fields and the fields with their value types.
    DE: Ein Werttyp, den ein Erweiterungsschema definiert: sein
    vereinfachter Name, der Namensraum seiner Felder und die Felder mit
    ihren Werttypen. }
  TLandrixEInvoiceXmpCustomType = record
    Key: TLandrixEInvoiceString;
    Ns: TLandrixEInvoiceString;
    FieldNames: array of TLandrixEInvoiceString;
    FieldTypes: array of TLandrixEInvoiceString;
    FieldCount: Integer;
  end;

  { The value types and properties a packet defines through its PDF/A
    extension schemas, and the check of a value against a type, as veraPDF
    reads them (ISO 19005-3, 6.6.2.3).
    Types (6.6.2.3.3-8, -17, 6.6.2.3.1-2): per schema namespace
    (pdfaSchema:namespaceURI) the built-in types and the types the schema
    defines; a schema counts if it has a namespace URI and an array as
    pdfaSchema:property, and of several with one URI the last one counts. A
    field that is present but a structure or an array counts with the value
    '' (veraPDF reads it so). A type is registered under its name in
    simplified form (lower case, "open/closed choice of" removed, "bag",
    "seq" and "alt" alone read as text), a later one with the same name
    replacing it; a type with fields only if it has a namespace URI, its
    fields in that namespace. A schema without such an entry knows only the
    14 basic types. A further packet (not the catalog's) starts each schema
    from the entry of the main packet with the same URI, else from all
    built-in types.
    Properties (6.6.2.3.1): a property of a counting schema is defined under
    the schema's namespace URI and its pdfaProperty:name if its value type is
    known to the schema; of several with one name the first counts.
    Values: simple types by their lexical form (Boolean True or False,
    Integer and Real with optional sign, Date as the XMP parser reads ISO
    8601, MIMEType type/subtype, GPSCoordinate; Text, URI and the other text
    types any simple value), Lang Alt as an rdf:Alt that is empty or has an
    item with xml:lang, bag/seq/alt X as that array form with every item an
    X, a structured type as a structure whose fields are all fields of the
    type with valid values (missing fields allowed). Choice vocabularies and
    value ranges are not checked.
    Where the reading is not certain (characters beyond ASCII or line ends in
    a type name, XPath, a type defined in two places, a limit), the answer
    is unknown. Lower case is that of Java in an English locale.
    DE: Die Werttypen und Eigenschaften, die ein Paket mit seinen
    PDF/A-Erweiterungsschemas definiert, und die Pruefung eines Werts gegen
    einen Typ, wie veraPDF sie liest (ISO 19005-3, 6.6.2.3).
    Typen (6.6.2.3.3-8, -17, 6.6.2.3.1-2): je Schema-Namensraum
    (pdfaSchema:namespaceURI) die eingebauten Typen und die, die das Schema
    definiert; ein Schema zaehlt, wenn es eine Namensraum-URI und ein Array
    als pdfaSchema:property hat, von mehreren mit einer URI das letzte. Ein
    vorhandenes Feld, das eine Struktur oder ein Array ist, zaehlt mit dem
    Wert '' (so liest veraPDF es). Ein Typ wird unter seinem vereinfachten
    Namen registriert (Kleinbuchstaben, "open/closed choice of" entfernt,
    "bag", "seq" und "alt" allein als Text gelesen), ein spaeterer mit
    demselben Namen ersetzt ihn; ein Typ mit Feldern nur, wenn er eine
    Namensraum-URI hat, seine Felder in diesem Namensraum. Ein Schema ohne
    solchen Eintrag kennt nur die 14 Grundtypen. Ein weiteres Paket (nicht
    das des Katalogs) beginnt jedes Schema mit dem Eintrag des Hauptpakets
    fuer dieselbe URI, sonst mit allen eingebauten Typen.
    Eigenschaften (6.6.2.3.1): eine Eigenschaft eines zaehlenden Schemas ist
    unter der Namensraum-URI des Schemas und ihrem pdfaProperty:name
    definiert, wenn ihr Werttyp dem Schema bekannt ist; von mehreren mit
    einem Namen zaehlt die erste.
    Werte: einfache Typen nach ihrer Schreibweise (Boolean True oder False,
    Integer und Real mit optionalem Vorzeichen, Date wie der XMP-Parser ISO
    8601 liest, MIMEType type/subtype, GPSCoordinate; Text, URI und die
    anderen Text-Typen jeder einfache Wert), Lang Alt als rdf:Alt, das leer
    ist oder ein Element mit xml:lang hat, bag/seq/alt X als diese
    Array-Form mit jedem Element ein X, ein strukturierter Typ als Struktur,
    deren Felder alle Felder des Typs mit gueltigen Werten sind (fehlende
    Felder erlaubt). Auswahl-Vokabulare und Wertebereiche werden nicht
    geprueft.
    Wo die Lesart nicht sicher ist (Zeichen jenseits von ASCII oder
    Zeilenenden in einem Typnamen, XPath, ein an zwei Stellen definierter
    Typ, eine Grenze), ist die Antwort unbekannt. Kleinbuchstaben wie bei
    Java in englischer Locale. }
  TLandrixEInvoiceXmpSchemaTypes = class(TObject)
  private
    FUris: array of TLandrixEInvoiceString;
    FTypes: array of array of TLandrixEInvoiceXmpCustomType;
    FTypeCounts: array of Integer;
    { the entry's own types are not certain }
    FUncertain: array of Boolean;
    { the entry started from the main packet's entry }
    FSeeded: array of Boolean;
    FCount: Integer;
    FOverflow: Boolean;
    { property definitions looked at, against a crafted list of repeats }
    FPropChecked: Integer;
    FPropUris: array of TLandrixEInvoiceString;
    FPropNames: array of TLandrixEInvoiceString;
    FPropTypes: array of TLandrixEInvoiceString;
    FPropEntries: array of Integer;
    FPropUncertain: array of Boolean;
    FPropCount: Integer;
    function IndexOf(const AUri: TLandrixEInvoiceString): Integer;
    function TypeIndex(AEntry: Integer; const AKey: TLandrixEInvoiceString): Integer;
    procedure PutType(AEntry: Integer; const AType: TLandrixEInvoiceXmpCustomType);
    procedure AddTypes(AEntry: Integer; ADefinition: TLandrixEInvoiceXmpNode);
    procedure AddProperties(AEntry: Integer; ADefinition: TLandrixEInvoiceXmpNode);
    function ValidateKey(ANode: TLandrixEInvoiceXmpNode; const AKey: TLandrixEInvoiceString; AEntry,
      ADepth: Integer): TLandrixEInvoiceXmpTruth;
    function ValidateFields(ANode: TLandrixEInvoiceXmpNode; const AKey: TLandrixEInvoiceString; AEntry,
      ADepth: Integer): TLandrixEInvoiceXmpTruth;
  public
    { Registers the types and properties of APacket's pdfaExtension:schemas.
      AMain is the registry of the catalog's packet for a further packet
      (nil if the catalog has none); AFurther tells that APacket is a
      further packet.
      DE: Registriert die Typen und Eigenschaften von pdfaExtension:schemas
      in APacket. AMain ist fuer ein weiteres Paket die Registrierung des
      Katalog-Pakets (nil, wenn der Katalog keines hat); AFurther sagt, dass
      APacket ein weiteres Paket ist. }
    procedure Build(APacket: TLandrixEInvoiceXmpPacket; AMain: TLandrixEInvoiceXmpSchemaTypes; AFurther: Boolean);
    { The entry of the schema with the namespace URI ASchemaUri (AHasUri
      False: the schema has none), -1 if there is none.
      DE: Der Eintrag des Schemas mit der Namensraum-URI ASchemaUri (AHasUri
      False: das Schema hat keine), -1, wenn es keinen gibt. }
    function Entry(const ASchemaUri: TLandrixEInvoiceString; AHasUri: Boolean): Integer;
    { Whether AType is known to a schema with the entry AEntry (from Entry).
      DE: Ob AType einem Schema mit dem Eintrag AEntry (aus Entry) bekannt
      ist. }
    function IsKnown(AEntry: Integer; const AType: TLandrixEInvoiceString): TLandrixEInvoiceXmpTruth;
    { Whether the packet defines the property ANs/ALocal; if so, its value
      type and the entry of its schema.
      DE: Ob das Paket die Eigenschaft ANs/ALocal definiert; wenn ja, ihr
      Werttyp und der Eintrag ihres Schemas. }
    function Defines(const ANs, ALocal: TLandrixEInvoiceString; out AType: TLandrixEInvoiceString;
      out AEntry: Integer): TLandrixEInvoiceXmpTruth;
    { Whether ANode is a valid value of AType in the schema entry AEntry
      (LandrixEInvoiceXmpPredefinedEntry: the built-in types only).
      DE: Ob ANode ein gueltiger Wert von AType im Schema-Eintrag AEntry ist
      (LandrixEInvoiceXmpPredefinedEntry: nur die eingebauten Typen). }
    function Validate(ANode: TLandrixEInvoiceXmpNode; const AType: TLandrixEInvoiceString;
      AEntry: Integer): TLandrixEInvoiceXmpTruth;
  end;

{ Whether ANs/ALocal is a property predefined for PDF/A-2 and -3 (the
  schemas of the XMP Specification 2005, chapter 4, and pdfaid); if so its
  value type and whether veraPDF reads it less strictly than the
  specification (ALax: a value failing the type is then not decided).
  DE: Ob ANs/ALocal eine fuer PDF/A-2 und -3 vordefinierte Eigenschaft ist
  (die Schemas der XMP Specification 2005, Kapitel 4, und pdfaid); wenn ja,
  ihr Werttyp und ob veraPDF sie lockerer liest als die Spezifikation
  (ALax: ein Wert, der den Typ verfehlt, ist dann nicht entschieden). }
function LandrixEInvoiceXmpPredefined(const ANs, ALocal: TLandrixEInvoiceString; out AType: TLandrixEInvoiceString;
  out ALax: Boolean): Boolean;

implementation

uses
  SysUtils,
  LandrixXmlBase,
  LandrixXmlReader;

const
  NsX = 'adobe:ns:meta/';
  NsDc = 'http://purl.org/dc/elements/1.1/';
  NsDcOld = 'http://purl.org/dc/1.1/';
  { most DOM nodes and attributes of one packet }
  MaxDomNodes = 200000;
  MaxDomDepth = 256;
  { most properties, fields or qualifiers of one parent: the duplicate
    checks compare each with all before }
  MaxSiblings = 2000;

type
  EXmpReject = class(Exception);
  EXmpUnknown = class(Exception);

  TDomKind = (dk_Element, dk_Text, dk_CData, dk_PI);

  TDomAttr = record
    Ns: TLandrixEInvoiceString;
    Local: TLandrixEInvoiceString;
    Prefix: TLandrixEInvoiceString;
    Value: TLandrixEInvoiceString;
  end;

  { A node of the packet's XML without comments; namespace declarations are
    not attributes. }
  TDom = class(TObject)
  public
    Kind: TDomKind;
    Ns: TLandrixEInvoiceString;
    Local: TLandrixEInvoiceString;
    Prefix: TLandrixEInvoiceString;
    Text: TLandrixEInvoiceString;
    Attrs: array of TDomAttr;
    AttrCount: Integer;
    Children: TObjectList;
    constructor Create(AKind: TDomKind);
    destructor Destroy; override;
    function Add(AKind: TDomKind): TDom;
    function Count: Integer;
    function Child(AIndex: Integer): TDom;
  end;

  { RDF syntax terms as the XMP parser tells them apart. }
  TRdfTerm = (rt_Other, rt_RDF, rt_ID, rt_About, rt_ParseType, rt_Resource, rt_NodeID, rt_Datatype,
    rt_Description, rt_Li, rt_AboutEach, rt_AboutEachPrefix, rt_BagID);

  TRdfReader = class(TObject)
  private
    FPacket: TLandrixEInvoiceXmpPacket;
    procedure NodeElement(AParent: TLandrixEInvoiceXmpNode; AX: TDom; ATop: Boolean);
    procedure NodeElementAttrs(AParent: TLandrixEInvoiceXmpNode; AX: TDom; ATop: Boolean);
    procedure PropertyElementList(AParent: TLandrixEInvoiceXmpNode; AX: TDom; ATop: Boolean);
    procedure PropertyElement(AParent: TLandrixEInvoiceXmpNode; AX: TDom; ATop: Boolean);
    procedure EmptyPropertyElement(AParent: TLandrixEInvoiceXmpNode; AX: TDom; ATop: Boolean);
    procedure LiteralPropertyElement(AParent: TLandrixEInvoiceXmpNode; AX: TDom; ATop: Boolean);
    procedure ResourcePropertyElement(AParent: TLandrixEInvoiceXmpNode; AX: TDom; ATop: Boolean);
    procedure ParseTypeResourceElement(AParent: TLandrixEInvoiceXmpNode; AX: TDom; ATop: Boolean);
    function AddChildNode(AParent: TLandrixEInvoiceXmpNode; const ANs, ALocal, APrefix,
      AValue: TLandrixEInvoiceString; ATop: Boolean): TLandrixEInvoiceXmpNode;
    procedure AddQualifier(ANode: TLandrixEInvoiceXmpNode; const ANs, ALocal, APrefix,
      AValue: TLandrixEInvoiceString);
    procedure FixupQualified(ANode: TLandrixEInvoiceXmpNode);
    procedure MoveQualifier(ANode, AQ: TLandrixEInvoiceXmpNode; AField: Boolean);
  public
    constructor Create(APacket: TLandrixEInvoiceXmpPacket);
    procedure ReadRdf(ARoot: TDom);
  end;

procedure Reject(const AText: string);
begin
  raise EXmpReject.Create(AText);
end;

procedure NotDecided(const AText: string);
begin
  raise EXmpUnknown.Create(AText);
end;

{ An item of an owning list, taken out without freeing it. }
function TakeAt(AList: TObjectList; AIndex: Integer): TObject;
begin
  Result := AList[AIndex];
  AList.OwnsObjects := False;
  try
    AList.Delete(AIndex);
  finally
    AList.OwnsObjects := True;
  end;
end;

{ Java's Character.isWhitespace, by which the XMP parser skips text between
  elements. U+180E is a space separator in some Java versions only. }
function JavaSpace(C: WideChar; out AUnknown: Boolean): Boolean;
var
  W: Word;
begin
  AUnknown := False;
  W := Word(C);
  case W of
    9..13, 28..32, $1680, $2000..$2006, $2008..$200A, $2028, $2029, $205F, $3000:
      Result := True;
    $180E:
      begin
        AUnknown := True;
        Result := False;
      end;
  else
    Result := False;
  end;
end;

{ A text node of white space only, as the XMP parser skips it. }
function IsSpaceNode(AX: TDom): Boolean;
var
  I: Integer;
  Unknown: Boolean;
begin
  Result := False;
  if AX.Kind <> dk_Text then
    Exit;
  for I := 1 to Length(AX.Text) do
  begin
    if not JavaSpace(AX.Text[I], Unknown) then
    begin
      if Unknown then
        NotDecided('U+180E in text between elements');
      Exit;
    end;
  end;
  Result := True;
end;

function IsXmlLang(const A: TDomAttr): Boolean;
begin
  Result := (A.Ns = LandrixEInvoiceXmpNsXml) and (A.Local = 'lang');
end;

function TermOf(const ANs, ALocal: TLandrixEInvoiceString): TRdfTerm;
begin
  Result := rt_Other;
  if ANs <> LandrixEInvoiceXmpNsRdf then
    Exit;
  if ALocal = 'RDF' then
    Result := rt_RDF
  else if ALocal = 'ID' then
    Result := rt_ID
  else if ALocal = 'about' then
    Result := rt_About
  else if ALocal = 'parseType' then
    Result := rt_ParseType
  else if ALocal = 'resource' then
    Result := rt_Resource
  else if ALocal = 'nodeID' then
    Result := rt_NodeID
  else if ALocal = 'datatype' then
    Result := rt_Datatype
  else if ALocal = 'Description' then
    Result := rt_Description
  else if ALocal = 'li' then
    Result := rt_Li
  else if ALocal = 'aboutEach' then
    Result := rt_AboutEach
  else if ALocal = 'aboutEachPrefix' then
    Result := rt_AboutEachPrefix
  else if ALocal = 'bagID' then
    Result := rt_BagID;
end;

{ An attribute's term; an unprefixed about or ID on an element of the RDF
  namespace counts as the RDF term. }
function AttrTerm(const A: TDomAttr; const AOwnerNs: TLandrixEInvoiceString): TRdfTerm;
begin
  if (A.Ns = '') and ((A.Local = 'about') or (A.Local = 'ID')) and (AOwnerNs = LandrixEInvoiceXmpNsRdf) then
    Result := TermOf(LandrixEInvoiceXmpNsRdf, A.Local)
  else
    Result := TermOf(A.Ns, A.Local);
end;

function LexicalOf(const APrefix, ALocal: TLandrixEInvoiceString): TLandrixEInvoiceString;
begin
  if APrefix = '' then
    Result := ALocal
  else
    Result := APrefix + ':' + ALocal;
end;

function IsRdfAttr(const A: TDomAttr; const ALocal: TLandrixEInvoiceString): Boolean;
begin
  Result := (A.Ns = LandrixEInvoiceXmpNsRdf) and (A.Local = ALocal);
end;

{ TLandrixEInvoiceXmpNode }

constructor TLandrixEInvoiceXmpNode.Create;
begin
  inherited Create;
  FChildren := TObjectList.Create(True);
  FQualifiers := TObjectList.Create(True);
end;

destructor TLandrixEInvoiceXmpNode.Destroy;
begin
  FQualifiers.Free;
  FChildren.Free;
  inherited Destroy;
end;

function TLandrixEInvoiceXmpNode.ChildCount: Integer;
begin
  Result := Integer(FChildren.Count);
end;

function TLandrixEInvoiceXmpNode.Child(AIndex: Integer): TLandrixEInvoiceXmpNode;
begin
  Result := TLandrixEInvoiceXmpNode(FChildren[AIndex]);
end;

function TLandrixEInvoiceXmpNode.QualifierCount: Integer;
begin
  Result := Integer(FQualifiers.Count);
end;

function TLandrixEInvoiceXmpNode.Qualifier(AIndex: Integer): TLandrixEInvoiceXmpNode;
begin
  Result := TLandrixEInvoiceXmpNode(FQualifiers[AIndex]);
end;

function TLandrixEInvoiceXmpNode.FindChild(const ANs, ALocal: TLandrixEInvoiceString): TLandrixEInvoiceXmpNode;
var
  I: Integer;
begin
  Result := nil;
  for I := 0 to ChildCount - 1 do
    if (Child(I).Ns = ANs) and (Child(I).Local = ALocal) then
    begin
      Result := Child(I);
      Exit;
    end;
end;

{ TDom }

constructor TDom.Create(AKind: TDomKind);
begin
  inherited Create;
  Kind := AKind;
  Children := TObjectList.Create(True);
end;

destructor TDom.Destroy;
begin
  Children.Free;
  inherited Destroy;
end;

function TDom.Add(AKind: TDomKind): TDom;
begin
  Result := TDom.Create(AKind);
  Children.Add(Result);
end;

function TDom.Count: Integer;
begin
  Result := Integer(Children.Count);
end;

function TDom.Child(AIndex: Integer): TDom;
begin
  Result := TDom(Children[AIndex]);
end;

{ The encoding the XML parser reports for the bytes: by byte order mark or
  the first characters; for 8-bit input UTF-8 also when the declaration names
  ISO-8859-1 (as veraPDF reports it); '' for anything else. }
function DetectEncoding(const AData: TLandrixEInvoicePdfBytes): string;
var
  N, I, J: Integer;
  Decl, Name: AnsiString;
  Q: AnsiChar;
begin
  Result := '';
  N := Integer(Length(AData));
  if N < 2 then
  begin
    Result := 'UTF-8';
    Exit;
  end;
  if (N >= 3) and (AData[0] = $EF) and (AData[1] = $BB) and (AData[2] = $BF) then
  begin
    Result := 'UTF-8';
    Exit;
  end;
  if (AData[0] = $FE) and (AData[1] = $FF) then
  begin
    Result := 'UTF-16BE';
    Exit;
  end;
  if (AData[0] = $FF) and (AData[1] = $FE) then
  begin
    if not ((N >= 4) and (AData[2] = 0) and (AData[3] = 0)) then
      Result := 'UTF-16LE';
    Exit;
  end;
  if (AData[0] = 0) and (AData[1] = $3C) then
  begin
    Result := 'UTF-16BE';
    Exit;
  end;
  if (AData[0] = $3C) and (AData[1] = 0) then
  begin
    if not ((N >= 4) and (AData[2] = 0) and (AData[3] = 0)) then
      Result := 'UTF-16LE';
    Exit;
  end;
  if AData[0] = 0 then
    Exit;
  { 8-bit: the encoding pseudo-attribute of an XML declaration }
  if (N >= 5) and (AData[0] = Ord('<')) and (AData[1] = Ord('?')) and (AData[2] = Ord('x')) and
    (AData[3] = Ord('m')) and (AData[4] = Ord('l')) then
  begin
    Decl := '';
    I := 0;
    while (I < N) and (I < 512) do
    begin
      Decl := Decl + AnsiChar(AData[I]);
      if (I > 0) and (AData[I] = Ord('>')) and (AData[I - 1] = Ord('?')) then
        Break;
      Inc(I);
    end;
    I := 0;
    for J := 1 to Length(Decl) - 7 do
      if (I = 0) and (Copy(Decl, J, 8) = 'encoding') then
        I := J;
    if I > 0 then
    begin
      J := I + 8;
      while (J <= Length(Decl)) and (Decl[J] in [' ', #9, #10, #13]) do
        Inc(J);
      if (J > Length(Decl)) or (Decl[J] <> '=') then
        Exit;
      Inc(J);
      while (J <= Length(Decl)) and (Decl[J] in [' ', #9, #10, #13]) do
        Inc(J);
      if (J > Length(Decl)) or not (Decl[J] in ['"', '''']) then
        Exit;
      Q := Decl[J];
      Inc(J);
      Name := '';
      while (J <= Length(Decl)) and (Decl[J] <> Q) do
      begin
        if (Decl[J] >= 'a') and (Decl[J] <= 'z') then
          Name := Name + AnsiChar(Ord(Decl[J]) - 32)
        else
          Name := Name + Decl[J];
        Inc(J);
      end;
      if (Name <> 'UTF-8') and (Name <> 'ISO-8859-1') then
        Exit;
    end;
  end;
  Result := 'UTF-8';
end;

{ The XML of the packet as a tree without comments. Raises EXmpUnknown for
  anything the strict reader rejects, a document type and limits. }
function BuildDom(const AData: TLandrixEInvoicePdfBytes): TDom;
var
  R: TLandrixXmlReader;
  Stack: TObjectList;
  Cur, N, TextNode: TDom;
  I, Nodes, TextLen: Integer;
  TextBuf, Piece: TLandrixEInvoiceString;

  { the text of TextNode, gathered in TextBuf (text around comments joins:
    appending to the node each time would copy it again and again) }
  procedure FlushText;
  begin
    if TextNode <> nil then
      TextNode.Text := Copy(TextBuf, 1, TextLen);
    TextNode := nil;
    TextLen := 0;
  end;

begin
  TextNode := nil;
  TextLen := 0;
  TextBuf := '';
  Result := TDom.Create(dk_Element);
  R := TLandrixXmlReader.Create;
  Stack := TObjectList.Create(False);
  try
    try
      R.MaxDepth := MaxDomDepth;
      R.LoadFromBuffer(AData[0], Integer(Length(AData)));
      Cur := Result;
      Nodes := 0;
      while R.Read do
      begin
        Inc(Nodes);
        if Nodes > MaxDomNodes then
          NotDecided('more than ' + IntToStr(MaxDomNodes) + ' XML nodes');
        if R.TokenType in [xttStartElement, xttEndElement, xttCData, xttProcessingInstruction] then
          FlushText;
        case R.TokenType of
          xttStartElement:
            begin
              Inc(Nodes, R.AttributeCount);
              N := Cur.Add(dk_Element);
              N.Ns := LandrixXmlUtf8ToWide(R.NamespaceUriUtf8);
              N.Local := LandrixXmlUtf8ToWide(R.LocalNameUtf8);
              N.Prefix := LandrixXmlUtf8ToWide(R.PrefixUtf8);
              SetLength(N.Attrs, R.AttributeCount);
              for I := 0 to R.AttributeCount - 1 do
                if not R.IsNamespaceDeclaration(I) then
                begin
                  N.Attrs[N.AttrCount].Ns := LandrixXmlUtf8ToWide(R.AttributeNamespaceUriUtf8(I));
                  N.Attrs[N.AttrCount].Local := LandrixXmlUtf8ToWide(R.AttributeLocalNameUtf8(I));
                  N.Attrs[N.AttrCount].Prefix := LandrixXmlUtf8ToWide(LandrixXmlSpanToUtf8(R.AttributePrefixSpan(I)));
                  N.Attrs[N.AttrCount].Value := R.AttributeValueW(I);
                  Inc(N.AttrCount);
                end;
              Stack.Add(Cur);
              Cur := N;
            end;
          xttEndElement:
            begin
              Cur := TDom(Stack[Stack.Count - 1]);
              Stack.Delete(Stack.Count - 1);
            end;
          xttText:
            begin
              { comments are dropped, so text around one joins }
              if TextNode = nil then
                TextNode := Cur.Add(dk_Text);
              Piece := R.ValueW;
              if Piece <> '' then
              begin
                if TextLen + Length(Piece) > Length(TextBuf) then
                begin
                  if TextLen + Length(Piece) > 2 * Length(TextBuf) then
                    SetLength(TextBuf, TextLen + Length(Piece))
                  else
                    SetLength(TextBuf, 2 * Length(TextBuf));
                end;
                Move(Piece[1], TextBuf[TextLen + 1], Length(Piece) * SizeOf(WideChar));
                Inc(TextLen, Length(Piece));
              end;
            end;
          xttCData:
            Cur.Add(dk_CData).Text := R.ValueW;
          xttProcessingInstruction:
            begin
              N := Cur.Add(dk_PI);
              N.Local := LandrixXmlUtf8ToWide(R.NameUtf8);
              N.Text := R.ValueW;
            end;
          xttDocumentType:
            NotDecided('document type declaration');
        else
          { comments }
        end;
      end;
      FlushText;
    except
      on E: ELandrixXmlError do
      begin
        Result.Free;
        raise EXmpUnknown.Create('XML: ' + E.Message);
      end;
    else
      Result.Free;
      raise;
    end;
  finally
    Stack.Free;
    R.Free;
  end;
end;

{ The RDF root as the XMP parser finds it: in document order, an
  x:xmpmeta or x:xapmeta wrapper ends the search at its level with what it
  contains; the data of every <?xpacket?> met before is the header (the
  last one wins). }
function FindRoot(ANode: TDom; APacket: TLandrixEInvoiceXmpPacket): TDom;
var
  I: Integer;
  C: TDom;
begin
  Result := nil;
  for I := 0 to ANode.Count - 1 do
  begin
    C := ANode.Child(I);
    if C.Kind = dk_PI then
    begin
      if C.Local = 'xpacket' then
      begin
        APacket.HasHeader := True;
        APacket.Header := C.Text;
      end;
    end
    else if C.Kind = dk_Element then
    begin
      if (C.Ns = NsX) and ((C.Local = 'xmpmeta') or (C.Local = 'xapmeta')) then
      begin
        Result := FindRoot(C, APacket);
        Exit;
      end;
      if (C.Ns = LandrixEInvoiceXmpNsRdf) and (C.Local = 'RDF') then
      begin
        Result := C;
        Exit;
      end;
      Result := FindRoot(C, APacket);
      if Result <> nil then
        Exit;
    end;
  end;
end;

{ TRdfReader: the RDF grammar of the XMP parser }

constructor TRdfReader.Create(APacket: TLandrixEInvoiceXmpPacket);
begin
  inherited Create;
  FPacket := APacket;
end;

procedure TRdfReader.ReadRdf(ARoot: TDom);
var
  I: Integer;
begin
  { attributes on rdf:RDF are not needed: the XMPCore fork of veraPDF
    1.30.4 (ParseRDF.rdf_RDF) reads the node elements without checking
    them, unlike Adobe's XMPCore }
  for I := 0 to ARoot.Count - 1 do
    if not IsSpaceNode(ARoot.Child(I)) then
      NodeElement(nil, ARoot.Child(I), True);
end;

procedure TRdfReader.NodeElement(AParent: TLandrixEInvoiceXmpNode; AX: TDom; ATop: Boolean);
var
  T: TRdfTerm;
begin
  if AX.Kind <> dk_Element then
    Reject('text or a processing instruction where a node element belongs');
  T := TermOf(AX.Ns, AX.Local);
  if (T <> rt_Description) and (T <> rt_Other) then
    Reject('node element must be rdf:Description or a typed node');
  if ATop and (T = rt_Other) then
    Reject('top-level typed node');
  NodeElementAttrs(AParent, AX, ATop);
  PropertyElementList(AParent, AX, ATop);
end;

procedure TRdfReader.NodeElementAttrs(AParent: TLandrixEInvoiceXmpNode; AX: TDom; ATop: Boolean);
var
  I, Exclusive: Integer;
  T: TRdfTerm;
begin
  Exclusive := 0;
  for I := 0 to AX.AttrCount - 1 do
  begin
    T := AttrTerm(AX.Attrs[I], AX.Ns);
    case T of
      rt_ID, rt_NodeID, rt_About:
        begin
          if Exclusive > 0 then
            Reject('rdf:about, rdf:ID and rdf:nodeID together');
          Inc(Exclusive);
          if ATop and (T = rt_About) then
          begin
            if FPacket.FAbout <> '' then
            begin
              if AX.Attrs[I].Value = '' then
                NotDecided('empty rdf:about after a non-empty one');
              if FPacket.FAbout <> AX.Attrs[I].Value then
                Reject('different top-level rdf:about values');
            end
            else
              FPacket.FAbout := AX.Attrs[I].Value;
          end;
        end;
      rt_Other:
        AddChildNode(AParent, AX.Attrs[I].Ns, AX.Attrs[I].Local, AX.Attrs[I].Prefix, AX.Attrs[I].Value, ATop);
    else
      Reject('invalid attribute of a node element');
    end;
  end;
end;

procedure TRdfReader.PropertyElementList(AParent: TLandrixEInvoiceXmpNode; AX: TDom; ATop: Boolean);
var
  I: Integer;
  C: TDom;
begin
  for I := 0 to AX.Count - 1 do
  begin
    C := AX.Child(I);
    if IsSpaceNode(C) then
      Continue;
    if C.Kind <> dk_Element then
      Reject('text, CDATA or a processing instruction where a property element belongs');
    PropertyElement(AParent, C, ATop);
  end;
end;

procedure TRdfReader.PropertyElement(AParent: TLandrixEInvoiceXmpNode; AX: TDom; ATop: Boolean);
var
  T: TRdfTerm;
  I, NonLang, First: Integer;
  Special, AllText: Boolean;
begin
  T := TermOf(AX.Ns, AX.Local);
  if T in [rt_Description, rt_AboutEach, rt_AboutEachPrefix, rt_BagID, rt_RDF, rt_ID, rt_About, rt_ParseType,
    rt_Resource, rt_NodeID, rt_Datatype] then
    Reject('invalid property element name');
  if AX.AttrCount > 3 then
  begin
    EmptyPropertyElement(AParent, AX, ATop);
    Exit;
  end;
  { the first attribute other than xml:lang decides; the parser sees the
    attributes in an order of its own, so with several of them the choice is
    certain only when none is rdf:datatype or rdf:parseType }
  NonLang := 0;
  First := -1;
  Special := False;
  for I := 0 to AX.AttrCount - 1 do
    if not IsXmlLang(AX.Attrs[I]) then
    begin
      Inc(NonLang);
      if First < 0 then
        First := I;
      if IsRdfAttr(AX.Attrs[I], 'datatype') or IsRdfAttr(AX.Attrs[I], 'parseType') then
        Special := True;
    end;
  if (NonLang > 1) and Special then
    NotDecided('several attributes with rdf:datatype or rdf:parseType');
  if NonLang > 0 then
  begin
    if IsRdfAttr(AX.Attrs[First], 'datatype') then
      LiteralPropertyElement(AParent, AX, ATop)
    else if not IsRdfAttr(AX.Attrs[First], 'parseType') then
      EmptyPropertyElement(AParent, AX, ATop)
    else if AX.Attrs[First].Value = 'Resource' then
      ParseTypeResourceElement(AParent, AX, ATop)
    else
      Reject('rdf:parseType other than Resource');
    Exit;
  end;
  if AX.Count = 0 then
  begin
    EmptyPropertyElement(AParent, AX, ATop);
    Exit;
  end;
  AllText := True;
  for I := 0 to AX.Count - 1 do
    if AX.Child(I).Kind <> dk_Text then
      AllText := False;
  if AllText then
    LiteralPropertyElement(AParent, AX, ATop)
  else
    ResourcePropertyElement(AParent, AX, ATop);
end;

procedure TRdfReader.EmptyPropertyElement(AParent: TLandrixEInvoiceXmpNode; AX: TDom; ATop: Boolean);
var
  I, ValueAttr: Integer;
  HasProp, HasRes, HasNodeId, HasValue, IsStruct: Boolean;
  Node: TLandrixEInvoiceXmpNode;
  A: TDomAttr;
begin
  if AX.Count > 0 then
    Reject('content in a property element with rdf:resource or property attributes');
  HasProp := False;
  HasRes := False;
  HasNodeId := False;
  HasValue := False;
  ValueAttr := -1;
  for I := 0 to AX.AttrCount - 1 do
  begin
    A := AX.Attrs[I];
    case AttrTerm(A, AX.Ns) of
      rt_ID:
        ;
      rt_Resource:
        begin
          if HasNodeId or HasValue then
            Reject('rdf:resource with rdf:nodeID or rdf:value');
          HasRes := True;
          ValueAttr := I;
        end;
      rt_NodeID:
        begin
          if HasRes then
            Reject('rdf:nodeID with rdf:resource');
          HasNodeId := True;
        end;
      rt_Other:
        if IsRdfAttr(A, 'value') then
        begin
          if HasRes then
            Reject('rdf:value with rdf:resource');
          HasValue := True;
          ValueAttr := I;
        end
        else if not IsXmlLang(A) then
          HasProp := True;
    else
      Reject('invalid attribute of an empty property element');
    end;
  end;
  Node := AddChildNode(AParent, AX.Ns, AX.Local, AX.Prefix, '', ATop);
  IsStruct := False;
  if HasValue or HasRes then
  begin
    Node.Value := AX.Attrs[ValueAttr].Value;
    Node.IsUri := not HasValue;
  end
  else if HasProp then
  begin
    Node.Kind := xmk_Struct;
    IsStruct := True;
  end;
  for I := 0 to AX.AttrCount - 1 do
  begin
    if I = ValueAttr then
      Continue;
    A := AX.Attrs[I];
    case AttrTerm(A, AX.Ns) of
      rt_ID, rt_NodeID:
        ;
      rt_Other:
        if not IsStruct or IsXmlLang(A) then
          AddQualifier(Node, A.Ns, A.Local, A.Prefix, A.Value)
        else
          AddChildNode(Node, A.Ns, A.Local, A.Prefix, A.Value, False);
    else
      Reject('invalid attribute of an empty property element');
    end;
  end;
end;

procedure TRdfReader.LiteralPropertyElement(AParent: TLandrixEInvoiceXmpNode; AX: TDom; ATop: Boolean);
var
  I: Integer;
  Node: TLandrixEInvoiceXmpNode;
  Text: TLandrixEInvoiceString;
begin
  Node := AddChildNode(AParent, AX.Ns, AX.Local, AX.Prefix, '', ATop);
  for I := 0 to AX.AttrCount - 1 do
    if IsXmlLang(AX.Attrs[I]) then
      AddQualifier(Node, AX.Attrs[I].Ns, AX.Attrs[I].Local, AX.Attrs[I].Prefix, AX.Attrs[I].Value)
    else if not (IsRdfAttr(AX.Attrs[I], 'ID') or IsRdfAttr(AX.Attrs[I], 'datatype')) then
      Reject('invalid attribute of a literal property element');
  Text := '';
  for I := 0 to AX.Count - 1 do
  begin
    if AX.Child(I).Kind <> dk_Text then
      Reject('invalid child of a literal property element');
    Text := Text + AX.Child(I).Text;
  end;
  Node.Value := Text;
end;

procedure TRdfReader.ResourcePropertyElement(AParent: TLandrixEInvoiceXmpNode; AX: TDom; ATop: Boolean);
var
  I: Integer;
  Node: TLandrixEInvoiceXmpNode;
  C: TDom;
  Found, IsRdf: Boolean;
begin
  if ATop and (AX.Prefix = 'iX') and (AX.Local = 'changes') then
    Exit;
  Node := AddChildNode(AParent, AX.Ns, AX.Local, AX.Prefix, '', ATop);
  for I := 0 to AX.AttrCount - 1 do
    if IsXmlLang(AX.Attrs[I]) then
      AddQualifier(Node, AX.Attrs[I].Ns, AX.Attrs[I].Local, AX.Attrs[I].Prefix, AX.Attrs[I].Value)
    else if not IsRdfAttr(AX.Attrs[I], 'ID') then
      Reject('invalid attribute of a resource property element');
  Found := False;
  for I := 0 to AX.Count - 1 do
  begin
    C := AX.Child(I);
    if IsSpaceNode(C) then
      Continue;
    if (C.Kind <> dk_Element) or Found then
      Reject('a resource property element holds exactly one element');
    IsRdf := C.Ns = LandrixEInvoiceXmpNsRdf;
    if IsRdf and (C.Local = 'Bag') then
    begin
      Node.Kind := xmk_Array;
      Node.ArrayForm := xma_Bag;
    end
    else if IsRdf and (C.Local = 'Seq') then
    begin
      Node.Kind := xmk_Array;
      Node.ArrayForm := xma_Seq;
    end
    else if IsRdf and (C.Local = 'Alt') then
    begin
      Node.Kind := xmk_Array;
      Node.ArrayForm := xma_Alt;
    end
    else
    begin
      Node.Kind := xmk_Struct;
      if not IsRdf and (C.Local <> 'Description') then
      begin
        if C.Ns = '' then
          Reject('typed node without a namespace');
        AddQualifier(Node, LandrixEInvoiceXmpNsRdf, 'type', 'rdf', C.Ns + ':' + C.Local);
      end;
    end;
    NodeElement(Node, C, False);
    if Node.FHasValueChild then
      FixupQualified(Node);
    Found := True;
  end;
  if not Found then
    Reject('resource property element without an element');
end;

procedure TRdfReader.ParseTypeResourceElement(AParent: TLandrixEInvoiceXmpNode; AX: TDom; ATop: Boolean);
var
  I: Integer;
  Node: TLandrixEInvoiceXmpNode;
begin
  Node := AddChildNode(AParent, AX.Ns, AX.Local, AX.Prefix, '', ATop);
  Node.Kind := xmk_Struct;
  for I := 0 to AX.AttrCount - 1 do
    if IsXmlLang(AX.Attrs[I]) then
      AddQualifier(Node, AX.Attrs[I].Ns, AX.Attrs[I].Local, AX.Attrs[I].Prefix, AX.Attrs[I].Value)
    else if not (IsRdfAttr(AX.Attrs[I], 'ID') or IsRdfAttr(AX.Attrs[I], 'parseType')) then
      Reject('invalid attribute of a parseType Resource property element');
  PropertyElementList(Node, AX, False);
  if Node.FHasValueChild then
    FixupQualified(Node);
end;

{ A property, field or item; duplicates other than rdf:li items are
  rejected. }
function TRdfReader.AddChildNode(AParent: TLandrixEInvoiceXmpNode; const ANs, ALocal, APrefix,
  AValue: TLandrixEInvoiceString; ATop: Boolean): TLandrixEInvoiceXmpNode;
var
  List: TObjectList;
  Ns: TLandrixEInvoiceString;
  I: Integer;
  IsItem, IsValue: Boolean;
  Other: TLandrixEInvoiceXmpNode;
begin
  if ANs = '' then
    Reject('property without a namespace');
  Ns := ANs;
  if Ns = NsDcOld then
    Ns := NsDc;
  Inc(FPacket.FNodes);
  if FPacket.FNodes > MaxDomNodes then
    NotDecided('too many properties');
  IsItem := (Ns = LandrixEInvoiceXmpNsRdf) and (ALocal = 'li');
  IsValue := (Ns = LandrixEInvoiceXmpNsRdf) and (ALocal = 'value');
  if ATop then
    List := FPacket.FProps
  else
    List := AParent.FChildren;
  { array items skip the duplicate check, so only the other nodes count
    against the bound of the quadratic check }
  { the count includes array items: it bounds the duplicate loop below,
    which runs over them too (an array with a field among more items is
    not decided) }
  if not IsItem and (List.Count >= MaxSiblings) then
    NotDecided('more than ' + IntToStr(MaxSiblings) + ' properties or fields in one place');
  if not IsItem then
    for I := 0 to Integer(List.Count) - 1 do
    begin
      Other := TLandrixEInvoiceXmpNode(List[I]);
      if not Other.IsItem and (Other.Ns = Ns) and (Other.Local = ALocal) then
        Reject('duplicate property or field');
    end;
  if IsValue and (ATop or (AParent.Kind <> xmk_Struct)) then
    Reject('misplaced rdf:value');
  if IsItem and (ATop or (AParent.Kind <> xmk_Array)) then
    Reject('misplaced rdf:li');
  Result := TLandrixEInvoiceXmpNode.Create;
  Result.Ns := Ns;
  Result.Local := ALocal;
  Result.Prefix := APrefix;
  Result.Lexical := LexicalOf(APrefix, ALocal);
  Result.Value := AValue;
  Result.IsItem := IsItem;
  if IsValue then
  begin
    List.Insert(0, Result);
    AParent.FHasValueChild := True;
  end
  else
    List.Add(Result);
end;

{ The parser tells qualifiers apart by their name: an attribute keeps the
  name as written, a field moved to a qualifier (AField, FFromField) gets
  the prefix the namespace registry gives its namespace, which is not
  known here. Between two written names the same name is a duplicate and
  the same namespace and local name under another name is not decided;
  where a field is involved, the same local name is not decided. }
procedure CheckQualifier(ANode: TLandrixEInvoiceXmpNode; const ANs, ALocal, ALexical: TLandrixEInvoiceString;
  AField: Boolean);
var
  I: Integer;
  E: TLandrixEInvoiceXmpNode;
begin
  if ANode.QualifierCount >= MaxSiblings then
    NotDecided('more than ' + IntToStr(MaxSiblings) + ' qualifiers');
  for I := 0 to ANode.QualifierCount - 1 do
  begin
    E := ANode.Qualifier(I);
    if AField or E.FFromField then
    begin
      if E.Local = ALocal then
        NotDecided('qualifier name given by the namespace registry');
    end
    else if E.Lexical = ALexical then
      Reject('duplicate qualifier')
    else if (E.Ns = ANs) and (E.Local = ALocal) then
      NotDecided('one qualifier under two names');
  end;
end;

procedure TRdfReader.AddQualifier(ANode: TLandrixEInvoiceXmpNode; const ANs, ALocal, APrefix,
  AValue: TLandrixEInvoiceString);
var
  Q: TLandrixEInvoiceXmpNode;
begin
  CheckQualifier(ANode, ANs, ALocal, LexicalOf(APrefix, ALocal), False);
  Q := TLandrixEInvoiceXmpNode.Create;
  Q.Ns := ANs;
  Q.Local := ALocal;
  Q.Prefix := APrefix;
  Q.Lexical := LexicalOf(APrefix, ALocal);
  Q.Value := AValue;
  ANode.FQualifiers.Add(Q);
end;

{ A structure with an rdf:value field becomes that value; its xml:lang, the
  value's qualifiers and the other fields become qualifiers. }
procedure TRdfReader.MoveQualifier(ANode, AQ: TLandrixEInvoiceXmpNode; AField: Boolean);
begin
  AQ.FFromField := AQ.FFromField or AField;
  try
    CheckQualifier(ANode, AQ.Ns, AQ.Local, AQ.Lexical, AQ.FFromField);
  except
    AQ.Free;
    raise;
  end;
  ANode.FQualifiers.Add(AQ);
end;

function HasLang(ANode: TLandrixEInvoiceXmpNode): Boolean;
var
  K: Integer;
begin
  Result := False;
  for K := 0 to ANode.QualifierCount - 1 do
    if (ANode.Qualifier(K).Ns = LandrixEInvoiceXmpNsXml) and (ANode.Qualifier(K).Local = 'lang') then
      Result := True;
end;

procedure TRdfReader.FixupQualified(ANode: TLandrixEInvoiceXmpNode);
var
  V: TLandrixEInvoiceXmpNode;
  I: Integer;
begin
  V := TLandrixEInvoiceXmpNode(TakeAt(ANode.FChildren, 0));
  try
    if HasLang(V) and HasLang(ANode) then
      Reject('xml:lang on a qualified property and its rdf:value');
    while V.QualifierCount > 0 do
      MoveQualifier(ANode, TLandrixEInvoiceXmpNode(TakeAt(V.FQualifiers, 0)), False);
    while ANode.ChildCount > 0 do
      MoveQualifier(ANode, TLandrixEInvoiceXmpNode(TakeAt(ANode.FChildren, 0)), True);
    ANode.Kind := V.Kind;
    ANode.ArrayForm := V.ArrayForm;
    ANode.Value := V.Value;
    ANode.IsUri := V.IsUri;
    ANode.FHasValueChild := False;
    { in one pass, not item by item from the front (quadratic for large
      arrays); the capacity is set first so that Add cannot fail while
      both lists hold the items }
    ANode.FChildren.Capacity := ANode.FChildren.Count + V.FChildren.Count;
    V.FChildren.OwnsObjects := False;
    try
      for I := 0 to V.ChildCount - 1 do
        ANode.FChildren.Add(V.FChildren[I]);
      V.FChildren.Clear;
    finally
      V.FChildren.OwnsObjects := True;
    end;
  finally
    V.Free;
  end;
end;

{ TLandrixEInvoiceXmpPacket }

constructor TLandrixEInvoiceXmpPacket.Create;
begin
  inherited Create;
  FProps := TObjectList.Create(True);
  Clear;
end;

destructor TLandrixEInvoiceXmpPacket.Destroy;
begin
  FProps.Free;
  inherited Destroy;
end;

procedure TLandrixEInvoiceXmpPacket.Clear;
begin
  FProps.Clear;
  FAbout := '';
  FNodes := 0;
  State := xms_Unknown;
  Reason := '';
  HasRoot := False;
  HasHeader := False;
  Header := '';
  Encoding := '';
end;

procedure TLandrixEInvoiceXmpPacket.Parse(const AData: TLandrixEInvoicePdfBytes);
var
  Doc, Root: TDom;
  Rdf: TRdfReader;
  Enc: string;
begin
  Clear;
  if Length(AData) = 0 then
  begin
    Reason := 'empty';
    Exit;
  end;
  Enc := DetectEncoding(AData);
  Doc := nil;
  try
    try
      Doc := BuildDom(AData);
      Root := FindRoot(Doc, Self);
      if Root = nil then
      begin
        { no RDF: valid, but without header, encoding and properties }
        HasHeader := False;
        Header := '';
        State := xms_Valid;
        Exit;
      end;
      HasRoot := True;
      if Enc = '' then
        NotDecided('encoding not known');
      Rdf := TRdfReader.Create(Self);
      try
        Rdf.ReadRdf(Root);
      finally
        Rdf.Free;
      end;
      Encoding := Enc;
      State := xms_Valid;
    except
      on E: EXmpReject do
      begin
        Clear;
        State := xms_Invalid;
        Reason := E.Message;
      end;
      on E: EXmpUnknown do
      begin
        Clear;
        State := xms_Unknown;
        Reason := E.Message;
      end;
    end;
  finally
    Doc.Free;
  end;
end;

function TLandrixEInvoiceXmpPacket.PropertyCount: Integer;
begin
  Result := Integer(FProps.Count);
end;

function TLandrixEInvoiceXmpPacket.Prop(AIndex: Integer): TLandrixEInvoiceXmpNode;
begin
  Result := TLandrixEInvoiceXmpNode(FProps[AIndex]);
end;

function TLandrixEInvoiceXmpPacket.Find(const ANs, ALocal: TLandrixEInvoiceString): TLandrixEInvoiceXmpNode;
var
  I: Integer;
begin
  Result := nil;
  for I := 0 to PropertyCount - 1 do
    if (Prop(I).Ns = ANs) and (Prop(I).Local = ALocal) then
    begin
      Result := Prop(I);
      Exit;
    end;
end;

{ TLandrixEInvoiceXmpSchemaTypes }

type
  TXmpPropDef = record
    N: Integer;
    Name: string;
    VType: string;
    Lax: Boolean;
  end;

  TXmpFieldDef = record
    T: string;
    N: Integer;
    Name: string;
    VType: string;
    Lax: Boolean;
  end;

const
  { most schema entries, types per entry, defined properties; beyond,
    answers are unknown }
  MaxSchemaEntries = 64;
  MaxSchemaKeys = 512;
  MaxSchemaProps = 4096;
  { longest type name read; longer ones are not decided }
  MaxTypeName = 1024;
  { deepest nesting of value types followed }
  MaxTypeDepth = 64;
  { the types every schema knows (veraPDF's basic validators) }
  BasicTypes: array[0..13] of string = ('agentname', 'boolean', 'date', 'integer', 'lang alt', 'mimetype',
    'propername', 'rational', 'real', 'renditionclass', 'text', 'uri', 'url', 'xpath');
  { the further types of the PDF/A-2/-3 predefined validators }
  PredefinedTypes: array[0..21] of string = ('beatsplicestretch', 'cfapattern', 'colorant', 'devicesettings',
    'dimensions', 'flash', 'font', 'gpscoordinate', 'job', 'locale', 'marker', 'media', 'oecf/sfr', 'projectlink',
    'resamplestretch', 'resourceevent', 'resourceref', 'thumbnail', 'time', 'timecode', 'timescalestretch',
    'version');
  { the namespaces of the predefined properties (XMP Specification 2005, chapter 4, and pdfaid) }
  XmpPropNs: array[0..13] of string = (
    'http://purl.org/dc/elements/1.1/',
    'http://ns.adobe.com/xap/1.0/',
    'http://ns.adobe.com/xap/1.0/rights/',
    'http://ns.adobe.com/xap/1.0/mm/',
    'http://ns.adobe.com/xap/1.0/bj/',
    'http://ns.adobe.com/xap/1.0/t/pg/',
    'http://ns.adobe.com/xmp/1.0/DynamicMedia/',
    'http://ns.adobe.com/pdf/1.3/',
    'http://ns.adobe.com/photoshop/1.0/',
    'http://ns.adobe.com/camera-raw-settings/1.0/',
    'http://ns.adobe.com/tiff/1.0/',
    'http://ns.adobe.com/exif/1.0/',
    'http://ns.adobe.com/exif/1.0/aux/',
    'http://www.aiim.org/pdfa/ns/id/');
  { the predefined properties: namespace index, name, value type; Lax: veraPDF reads it less strictly }
  XmpProps: array[0..276] of TXmpPropDef = (
    (N: 0; Name: 'contributor'; VType: 'bag ProperName'; Lax: False),
    (N: 0; Name: 'coverage'; VType: 'Text'; Lax: False),
    (N: 0; Name: 'creator'; VType: 'seq ProperName'; Lax: False),
    (N: 0; Name: 'date'; VType: 'seq Date'; Lax: False),
    (N: 0; Name: 'description'; VType: 'Lang Alt'; Lax: False),
    (N: 0; Name: 'format'; VType: 'MIMEType'; Lax: False),
    (N: 0; Name: 'identifier'; VType: 'Text'; Lax: False),
    (N: 0; Name: 'language'; VType: 'bag Locale'; Lax: False),
    (N: 0; Name: 'publisher'; VType: 'bag ProperName'; Lax: False),
    (N: 0; Name: 'relation'; VType: 'bag Text'; Lax: False),
    (N: 0; Name: 'rights'; VType: 'Lang Alt'; Lax: False),
    (N: 0; Name: 'source'; VType: 'Text'; Lax: False),
    (N: 0; Name: 'subject'; VType: 'bag Text'; Lax: False),
    (N: 0; Name: 'title'; VType: 'Lang Alt'; Lax: False),
    (N: 0; Name: 'type'; VType: 'bag open Choice'; Lax: False),
    (N: 1; Name: 'Advisory'; VType: 'bag XPath'; Lax: False),
    (N: 1; Name: 'BaseURL'; VType: 'URL'; Lax: False),
    (N: 1; Name: 'CreateDate'; VType: 'Date'; Lax: False),
    (N: 1; Name: 'CreatorTool'; VType: 'AgentName'; Lax: False),
    (N: 1; Name: 'Identifier'; VType: 'bag Text'; Lax: False),
    (N: 1; Name: 'Label'; VType: 'Text'; Lax: False),
    (N: 1; Name: 'MetadataDate'; VType: 'Date'; Lax: False),
    (N: 1; Name: 'ModifyDate'; VType: 'Date'; Lax: False),
    (N: 1; Name: 'Nickname'; VType: 'Text'; Lax: False),
    (N: 1; Name: 'Rating'; VType: 'Closed Choice of Integer'; Lax: True),
    (N: 1; Name: 'Thumbnails'; VType: 'alt Thumbnail'; Lax: False),
    (N: 2; Name: 'Certificate'; VType: 'URL'; Lax: False),
    (N: 2; Name: 'Marked'; VType: 'Boolean'; Lax: False),
    (N: 2; Name: 'Owner'; VType: 'bag ProperName'; Lax: False),
    (N: 2; Name: 'UsageTerms'; VType: 'Lang Alt'; Lax: False),
    (N: 2; Name: 'WebStatement'; VType: 'URL'; Lax: False),
    (N: 3; Name: 'DerivedFrom'; VType: 'ResourceRef'; Lax: False),
    (N: 3; Name: 'DocumentID'; VType: 'URI'; Lax: False),
    (N: 3; Name: 'History'; VType: 'seq ResourceEvent'; Lax: False),
    (N: 3; Name: 'InstanceID'; VType: 'URI'; Lax: False),
    (N: 3; Name: 'ManagedFrom'; VType: 'ResourceRef'; Lax: False),
    (N: 3; Name: 'Manager'; VType: 'AgentName'; Lax: False),
    (N: 3; Name: 'ManageTo'; VType: 'URI'; Lax: False),
    (N: 3; Name: 'ManageUI'; VType: 'URI'; Lax: False),
    (N: 3; Name: 'ManagerVariant'; VType: 'Text'; Lax: False),
    (N: 3; Name: 'RenditionClass'; VType: 'RenditionClass'; Lax: False),
    (N: 3; Name: 'RenditionParams'; VType: 'Text'; Lax: False),
    (N: 3; Name: 'VersionID'; VType: 'Text'; Lax: False),
    (N: 3; Name: 'Versions'; VType: 'seq Version'; Lax: False),
    (N: 3; Name: 'LastURL'; VType: 'URL'; Lax: False),
    (N: 3; Name: 'RenditionOf'; VType: 'ResourceRef'; Lax: False),
    (N: 3; Name: 'SaveID'; VType: 'Integer'; Lax: False),
    (N: 4; Name: 'JobRef'; VType: 'bag Job'; Lax: False),
    (N: 5; Name: 'MaxPageSize'; VType: 'Dimensions'; Lax: False),
    (N: 5; Name: 'NPages'; VType: 'Integer'; Lax: False),
    (N: 5; Name: 'Fonts'; VType: 'Bag Font'; Lax: False),
    (N: 5; Name: 'Colorants'; VType: 'Seq Colorant'; Lax: False),
    (N: 5; Name: 'PlateNames'; VType: 'Seq Text'; Lax: False),
    (N: 6; Name: 'projectRef'; VType: 'ProjectLink'; Lax: False),
    (N: 6; Name: 'videoFrameRate'; VType: 'open Choice of Text'; Lax: False),
    (N: 6; Name: 'videoFrameSize'; VType: 'Dimensions'; Lax: False),
    (N: 6; Name: 'videoPixelAspectRatio'; VType: 'Rational'; Lax: False),
    (N: 6; Name: 'videoPixelDepth'; VType: 'closed Choice of Text'; Lax: False),
    (N: 6; Name: 'videoColorSpace'; VType: 'closed Choice of Text'; Lax: False),
    (N: 6; Name: 'videoAlphaMode'; VType: 'closed Choice of Text'; Lax: False),
    (N: 6; Name: 'videoAlphaPremultipleColor'; VType: 'Colorant'; Lax: False),
    (N: 6; Name: 'videoAlphaUnityIsTransparent'; VType: 'Boolean'; Lax: False),
    (N: 6; Name: 'videoCompressor'; VType: 'Text'; Lax: False),
    (N: 6; Name: 'videoFieldOrder'; VType: 'closed Choice of Text'; Lax: False),
    (N: 6; Name: 'pullDown'; VType: 'closed Choice of Text'; Lax: False),
    (N: 6; Name: 'audioSampleRate'; VType: 'Integer'; Lax: False),
    (N: 6; Name: 'audioSampleType'; VType: 'closed Choice of Text'; Lax: False),
    (N: 6; Name: 'audioChannelType'; VType: 'closed Choice of Text'; Lax: False),
    (N: 6; Name: 'audioCompressor'; VType: 'Text'; Lax: False),
    (N: 6; Name: 'speakerPlacement'; VType: 'Text'; Lax: False),
    (N: 6; Name: 'fileDataRate'; VType: 'Rational'; Lax: False),
    (N: 6; Name: 'tapeName'; VType: 'Text'; Lax: False),
    (N: 6; Name: 'altTapeName'; VType: 'Text'; Lax: False),
    (N: 6; Name: 'startTimecode'; VType: 'Timecode'; Lax: False),
    (N: 6; Name: 'altTimecode'; VType: 'Timecode'; Lax: False),
    (N: 6; Name: 'duration'; VType: 'Time'; Lax: False),
    (N: 6; Name: 'scene'; VType: 'Text'; Lax: False),
    (N: 6; Name: 'shotName'; VType: 'Text'; Lax: False),
    (N: 6; Name: 'shotDate'; VType: 'Date'; Lax: False),
    (N: 6; Name: 'shotLocation'; VType: 'Text'; Lax: False),
    (N: 6; Name: 'logComment'; VType: 'Text'; Lax: False),
    (N: 6; Name: 'markers'; VType: 'seq Marker'; Lax: False),
    (N: 6; Name: 'contributedMedia'; VType: 'bag Media'; Lax: False),
    (N: 6; Name: 'absPeakAudioFilePath'; VType: 'URI'; Lax: False),
    (N: 6; Name: 'relativePeakAudioFilePath'; VType: 'URI'; Lax: False),
    (N: 6; Name: 'videoModDate'; VType: 'Date'; Lax: False),
    (N: 6; Name: 'audioModDate'; VType: 'Date'; Lax: False),
    (N: 6; Name: 'metadataModDate'; VType: 'Date'; Lax: False),
    (N: 6; Name: 'artist'; VType: 'Text'; Lax: False),
    (N: 6; Name: 'album'; VType: 'Text'; Lax: False),
    (N: 6; Name: 'trackNumber'; VType: 'Integer'; Lax: False),
    (N: 6; Name: 'genre'; VType: 'Text'; Lax: False),
    (N: 6; Name: 'copyright'; VType: 'Text'; Lax: False),
    (N: 6; Name: 'releaseDate'; VType: 'Date'; Lax: False),
    (N: 6; Name: 'composer'; VType: 'Text'; Lax: False),
    (N: 6; Name: 'engineer'; VType: 'Text'; Lax: False),
    (N: 6; Name: 'tempo'; VType: 'Real'; Lax: False),
    (N: 6; Name: 'instrument'; VType: 'Text'; Lax: False),
    (N: 6; Name: 'introTime'; VType: 'Time'; Lax: False),
    (N: 6; Name: 'outCue'; VType: 'Time'; Lax: False),
    (N: 6; Name: 'relativeTimestamp'; VType: 'Time'; Lax: False),
    (N: 6; Name: 'loop'; VType: 'Boolean'; Lax: False),
    (N: 6; Name: 'numberOfBeats'; VType: 'Real'; Lax: False),
    (N: 6; Name: 'key'; VType: 'closed Choice of Text'; Lax: False),
    (N: 6; Name: 'stretchMode'; VType: 'closed Choice of Text'; Lax: False),
    (N: 6; Name: 'timeScaleParams'; VType: 'timeScaleStretch'; Lax: False),
    (N: 6; Name: 'resampleParams'; VType: 'resampleStretch'; Lax: False),
    (N: 6; Name: 'beatSpliceParams'; VType: 'beatSpliceStretch'; Lax: False),
    (N: 6; Name: 'timeSignature'; VType: 'closed Choice of Text'; Lax: False),
    (N: 6; Name: 'scaleType'; VType: 'closed Choice of Text'; Lax: False),
    (N: 7; Name: 'Keywords'; VType: 'Text'; Lax: False),
    (N: 7; Name: 'PDFVersion'; VType: 'Text'; Lax: False),
    (N: 7; Name: 'Producer'; VType: 'AgentName'; Lax: False),
    (N: 8; Name: 'AuthorsPosition'; VType: 'Text'; Lax: False),
    (N: 8; Name: 'CaptionWriter'; VType: 'ProperName'; Lax: False),
    (N: 8; Name: 'Category'; VType: 'Text'; Lax: False),
    (N: 8; Name: 'City'; VType: 'Text'; Lax: False),
    (N: 8; Name: 'Country'; VType: 'Text'; Lax: False),
    (N: 8; Name: 'Credit'; VType: 'Text'; Lax: False),
    (N: 8; Name: 'DateCreated'; VType: 'Date'; Lax: False),
    (N: 8; Name: 'Headline'; VType: 'Text'; Lax: False),
    (N: 8; Name: 'Instructions'; VType: 'Text'; Lax: False),
    (N: 8; Name: 'Source'; VType: 'Text'; Lax: False),
    (N: 8; Name: 'State'; VType: 'Text'; Lax: False),
    (N: 8; Name: 'SupplementalCategories'; VType: 'bag Text'; Lax: False),
    (N: 8; Name: 'TransmissionReference'; VType: 'Text'; Lax: False),
    (N: 8; Name: 'Urgency'; VType: 'Integer'; Lax: False),
    (N: 9; Name: 'AutoBrightness'; VType: 'Boolean'; Lax: False),
    (N: 9; Name: 'AutoContrast'; VType: 'Boolean'; Lax: False),
    (N: 9; Name: 'AutoExposure'; VType: 'Boolean'; Lax: False),
    (N: 9; Name: 'AutoShadows'; VType: 'Boolean'; Lax: False),
    (N: 9; Name: 'BlueHue'; VType: 'Integer'; Lax: False),
    (N: 9; Name: 'BlueSaturation'; VType: 'Integer'; Lax: False),
    (N: 9; Name: 'Brightness'; VType: 'Integer'; Lax: False),
    (N: 9; Name: 'CameraProfile'; VType: 'Text'; Lax: False),
    (N: 9; Name: 'ChromaticAberrationB'; VType: 'Integer'; Lax: False),
    (N: 9; Name: 'ChromaticAberrationR'; VType: 'Integer'; Lax: False),
    (N: 9; Name: 'ColorNoiseReduction'; VType: 'Integer'; Lax: False),
    (N: 9; Name: 'Contrast'; VType: 'Integer'; Lax: False),
    (N: 9; Name: 'CropTop'; VType: 'Real'; Lax: False),
    (N: 9; Name: 'CropLeft'; VType: 'Real'; Lax: False),
    (N: 9; Name: 'CropBottom'; VType: 'Real'; Lax: False),
    (N: 9; Name: 'CropRight'; VType: 'Real'; Lax: False),
    (N: 9; Name: 'CropAngle'; VType: 'Real'; Lax: False),
    (N: 9; Name: 'CropWidth'; VType: 'Real'; Lax: False),
    (N: 9; Name: 'CropHeight'; VType: 'Real'; Lax: False),
    (N: 9; Name: 'CropUnits'; VType: 'Integer'; Lax: False),
    (N: 9; Name: 'Exposure'; VType: 'Real'; Lax: False),
    (N: 9; Name: 'GreenHue'; VType: 'Integer'; Lax: False),
    (N: 9; Name: 'GreenSaturation'; VType: 'Integer'; Lax: False),
    (N: 9; Name: 'HasCrop'; VType: 'Boolean'; Lax: False),
    (N: 9; Name: 'HasSettings'; VType: 'Boolean'; Lax: False),
    (N: 9; Name: 'LuminanceSmoothing'; VType: 'Integer'; Lax: False),
    (N: 9; Name: 'RawFileName'; VType: 'Text'; Lax: False),
    (N: 9; Name: 'RedHue'; VType: 'Integer'; Lax: False),
    (N: 9; Name: 'RedSaturation'; VType: 'Integer'; Lax: False),
    (N: 9; Name: 'Saturation'; VType: 'Integer'; Lax: False),
    (N: 9; Name: 'Shadows'; VType: 'Integer'; Lax: False),
    (N: 9; Name: 'ShadowTint'; VType: 'Integer'; Lax: False),
    (N: 9; Name: 'Sharpness'; VType: 'Integer'; Lax: False),
    (N: 9; Name: 'Temperature'; VType: 'Integer'; Lax: False),
    (N: 9; Name: 'Tint'; VType: 'Integer'; Lax: False),
    (N: 9; Name: 'ToneCurve'; VType: 'Seq Text'; Lax: False),
    (N: 9; Name: 'ToneCurveName'; VType: 'Choice Text'; Lax: False),
    (N: 9; Name: 'Version'; VType: 'Text'; Lax: False),
    (N: 9; Name: 'VignetteAmount'; VType: 'Integer'; Lax: False),
    (N: 9; Name: 'VignetteMidpoint'; VType: 'Integer'; Lax: False),
    (N: 9; Name: 'WhiteBalance'; VType: 'Closed Choice Text'; Lax: False),
    (N: 10; Name: 'ImageWidth'; VType: 'Integer'; Lax: False),
    (N: 10; Name: 'ImageLength'; VType: 'Integer'; Lax: False),
    (N: 10; Name: 'BitsPerSample'; VType: 'seq Integer'; Lax: False),
    (N: 10; Name: 'Compression'; VType: 'Closed Choice of Integer'; Lax: False),
    (N: 10; Name: 'PhotometricInterpretation'; VType: 'Closed Choice of Integer'; Lax: False),
    (N: 10; Name: 'Orientation'; VType: 'Closed Choice of Integer'; Lax: False),
    (N: 10; Name: 'SamplesPerPixel'; VType: 'Integer'; Lax: False),
    (N: 10; Name: 'PlanarConfiguration'; VType: 'Closed Choice of Integer'; Lax: False),
    (N: 10; Name: 'YCbCrSubSampling'; VType: 'Closed Choice of seq Integer'; Lax: False),
    (N: 10; Name: 'YCbCrPositioning'; VType: 'Closed Choice of Integer'; Lax: False),
    (N: 10; Name: 'XResolution'; VType: 'Rational'; Lax: False),
    (N: 10; Name: 'YResolution'; VType: 'Rational'; Lax: False),
    (N: 10; Name: 'ResolutionUnit'; VType: 'Closed Choice of Integer'; Lax: False),
    (N: 10; Name: 'TransferFunction'; VType: 'seq Integer'; Lax: False),
    (N: 10; Name: 'WhitePoint'; VType: 'seq Rational'; Lax: False),
    (N: 10; Name: 'PrimaryChromaticities'; VType: 'seq Rational'; Lax: False),
    (N: 10; Name: 'YCbCrCoefficients'; VType: 'seq Rational'; Lax: False),
    (N: 10; Name: 'ReferenceBlackWhite'; VType: 'seq Rational'; Lax: False),
    (N: 10; Name: 'DateTime'; VType: 'Date'; Lax: False),
    (N: 10; Name: 'ImageDescription'; VType: 'Lang Alt'; Lax: False),
    (N: 10; Name: 'Make'; VType: 'ProperName'; Lax: False),
    (N: 10; Name: 'Model'; VType: 'ProperName'; Lax: False),
    (N: 10; Name: 'Software'; VType: 'AgentName'; Lax: False),
    (N: 10; Name: 'Artist'; VType: 'ProperName'; Lax: False),
    (N: 10; Name: 'Copyright'; VType: 'Lang Alt'; Lax: False),
    (N: 11; Name: 'ExifVersion'; VType: 'Closed Choice of Text'; Lax: False),
    (N: 11; Name: 'FlashpixVersion'; VType: 'Closed Choice of Text'; Lax: False),
    (N: 11; Name: 'ColorSpace'; VType: 'Closed Choice of Integer'; Lax: False),
    (N: 11; Name: 'ComponentsConfiguration'; VType: 'Closed Choice of seq Integer'; Lax: False),
    (N: 11; Name: 'CompressedBitsPerPixel'; VType: 'Rational'; Lax: False),
    (N: 11; Name: 'PixelXDimension'; VType: 'Integer'; Lax: False),
    (N: 11; Name: 'PixelYDimension'; VType: 'Integer'; Lax: False),
    (N: 11; Name: 'UserComment'; VType: 'Lang Alt'; Lax: False),
    (N: 11; Name: 'RelatedSoundFile'; VType: 'Text'; Lax: False),
    (N: 11; Name: 'DateTimeOriginal'; VType: 'Date'; Lax: False),
    (N: 11; Name: 'DateTimeDigitized'; VType: 'Date'; Lax: False),
    (N: 11; Name: 'ExposureTime'; VType: 'Rational'; Lax: False),
    (N: 11; Name: 'FNumber'; VType: 'Rational'; Lax: False),
    (N: 11; Name: 'ExposureProgram'; VType: 'Closed Choice of Integer'; Lax: False),
    (N: 11; Name: 'SpectralSensitivity'; VType: 'Text'; Lax: False),
    (N: 11; Name: 'ISOSpeedRatings'; VType: 'seq Integer'; Lax: False),
    (N: 11; Name: 'OECF'; VType: 'OECF/SFR'; Lax: False),
    (N: 11; Name: 'ShutterSpeedValue'; VType: 'Rational'; Lax: False),
    (N: 11; Name: 'ApertureValue'; VType: 'Rational'; Lax: False),
    (N: 11; Name: 'BrightnessValue'; VType: 'Rational'; Lax: False),
    (N: 11; Name: 'ExposureBiasValue'; VType: 'Rational'; Lax: False),
    (N: 11; Name: 'MaxApertureValue'; VType: 'Rational'; Lax: False),
    (N: 11; Name: 'SubjectDistance'; VType: 'Rational'; Lax: False),
    (N: 11; Name: 'MeteringMode'; VType: 'Closed Choice of Integer'; Lax: False),
    (N: 11; Name: 'LightSource'; VType: 'Closed Choice of Integer'; Lax: False),
    (N: 11; Name: 'Flash'; VType: 'Flash'; Lax: False),
    (N: 11; Name: 'FocalLength'; VType: 'Rational'; Lax: False),
    (N: 11; Name: 'SubjectArea'; VType: 'seq Integer'; Lax: False),
    (N: 11; Name: 'FlashEnergy'; VType: 'Rational'; Lax: False),
    (N: 11; Name: 'SpatialFrequencyResponse'; VType: 'OECF/SFR'; Lax: False),
    (N: 11; Name: 'FocalPlaneXResolution'; VType: 'Rational'; Lax: False),
    (N: 11; Name: 'FocalPlaneYResolution'; VType: 'Rational'; Lax: False),
    (N: 11; Name: 'FocalPlaneResolutionUnit'; VType: 'Closed Choice of Integer'; Lax: False),
    (N: 11; Name: 'SubjectLocation'; VType: 'seq Integer'; Lax: False),
    (N: 11; Name: 'ExposureIndex'; VType: 'Rational'; Lax: False),
    (N: 11; Name: 'SensingMethod'; VType: 'Closed Choice of Integer'; Lax: False),
    (N: 11; Name: 'FileSource'; VType: 'Closed Choice of Integer'; Lax: False),
    (N: 11; Name: 'SceneType'; VType: 'Closed Choice of Integer'; Lax: False),
    (N: 11; Name: 'CFAPattern'; VType: 'CFAPattern'; Lax: False),
    (N: 11; Name: 'CustomRendered'; VType: 'Closed Choice of Integer'; Lax: False),
    (N: 11; Name: 'ExposureMode'; VType: 'Closed Choice of Integer'; Lax: False),
    (N: 11; Name: 'WhiteBalance'; VType: 'Closed Choice of Integer'; Lax: False),
    (N: 11; Name: 'DigitalZoomRatio'; VType: 'Rational'; Lax: False),
    (N: 11; Name: 'FocalLengthIn35mmFilm'; VType: 'Integer'; Lax: False),
    (N: 11; Name: 'SceneCaptureType'; VType: 'Closed Choice of Integer'; Lax: False),
    (N: 11; Name: 'GainControl'; VType: 'Closed Choice of Integer'; Lax: False),
    (N: 11; Name: 'Contrast'; VType: 'Closed Choice of Integer'; Lax: False),
    (N: 11; Name: 'Saturation'; VType: 'Closed Choice of Integer'; Lax: False),
    (N: 11; Name: 'Sharpness'; VType: 'Closed Choice of Integer'; Lax: False),
    (N: 11; Name: 'DeviceSettingDescription'; VType: 'DeviceSettings'; Lax: False),
    (N: 11; Name: 'SubjectDistanceRange'; VType: 'Closed Choice of Integer'; Lax: False),
    (N: 11; Name: 'ImageUniqueID'; VType: 'Text'; Lax: False),
    (N: 11; Name: 'GPSVersionID'; VType: 'Text'; Lax: False),
    (N: 11; Name: 'GPSLatitude'; VType: 'GPSCoordinate'; Lax: False),
    (N: 11; Name: 'GPSLongitude'; VType: 'GPSCoordinate'; Lax: False),
    (N: 11; Name: 'GPSAltitudeRef'; VType: 'Closed Choice of Integer'; Lax: False),
    (N: 11; Name: 'GPSAltitude'; VType: 'Rational'; Lax: False),
    (N: 11; Name: 'GPSTimeStamp'; VType: 'Date'; Lax: False),
    (N: 11; Name: 'GPSSatellites'; VType: 'Text'; Lax: False),
    (N: 11; Name: 'GPSStatus'; VType: 'Closed Choice of Text'; Lax: False),
    (N: 11; Name: 'GPSMeasureMode'; VType: 'Text'; Lax: False),
    (N: 11; Name: 'GPSDOP'; VType: 'Rational'; Lax: False),
    (N: 11; Name: 'GPSSpeedRef'; VType: 'Closed Choice of Text'; Lax: False),
    (N: 11; Name: 'GPSSpeed'; VType: 'Rational'; Lax: False),
    (N: 11; Name: 'GPSTrackRef'; VType: 'Closed Choice of Text'; Lax: False),
    (N: 11; Name: 'GPSTrack'; VType: 'Rational'; Lax: False),
    (N: 11; Name: 'GPSImgDirectionRef'; VType: 'Closed Choice of Text'; Lax: False),
    (N: 11; Name: 'GPSImgDirection'; VType: 'Rational'; Lax: False),
    (N: 11; Name: 'GPSMapDatum'; VType: 'Text'; Lax: False),
    (N: 11; Name: 'GPSDestLatitude'; VType: 'GPSCoordinate'; Lax: False),
    (N: 11; Name: 'GPSDestLongitude'; VType: 'GPSCoordinate'; Lax: False),
    (N: 11; Name: 'GPSDestBearingRef'; VType: 'Closed Choice of Text'; Lax: False),
    (N: 11; Name: 'GPSDestBearing'; VType: 'Rational'; Lax: False),
    (N: 11; Name: 'GPSDestDistanceRef'; VType: 'Closed Choice of Text'; Lax: False),
    (N: 11; Name: 'GPSDestDistance'; VType: 'Rational'; Lax: False),
    (N: 11; Name: 'GPSProcessingMethod'; VType: 'Text'; Lax: False),
    (N: 11; Name: 'GPSAreaInformation'; VType: 'Text'; Lax: False),
    (N: 12; Name: 'Lens'; VType: 'Text'; Lax: False),
    (N: 12; Name: 'SerialNumber'; VType: 'Text'; Lax: False),
    (N: 11; Name: 'GPSDifferential'; VType: 'Closed Choice of Integer'; Lax: False),
    (N: 13; Name: 'part'; VType: 'Integer'; Lax: False),
    (N: 13; Name: 'amd'; VType: 'Text'; Lax: False),
    (N: 13; Name: 'conformance'; VType: 'Text'; Lax: False),
    (N: 13; Name: 'corr'; VType: 'Text'; Lax: False));
  { the field namespaces of the structured value types (4.3) }
  XmpFieldNs: array[0..9] of string = (
    'http://ns.adobe.com/xap/1.0/g/',
    'http://ns.adobe.com/xap/1.0/sType/Dimensions#',
    'http://ns.adobe.com/xap/1.0/sType/Font#',
    'http://ns.adobe.com/xap/1.0/g/img/',
    'http://ns.adobe.com/xap/1.0/sType/ResourceEvent#',
    'http://ns.adobe.com/xap/1.0/sType/ResourceRef#',
    'http://ns.adobe.com/xap/1.0/sType/Version#',
    'http://ns.adobe.com/xap/1.0/sType/Job#',
    'http://ns.adobe.com/xmp/1.0/DynamicMedia/',
    'http://ns.adobe.com/exif/1.0/');
  { the fields of the structured value types: type (simplified name), field namespace index, field, value type;
    Lax: veraPDF reads it less strictly }
  XmpFields: array[0..90] of TXmpFieldDef = (
    (T: 'colorant'; N: 0; Name: 'swatchName'; VType: 'Text'; Lax: False),
    (T: 'colorant'; N: 0; Name: 'mode'; VType: 'Closed Choice of Text'; Lax: False),
    (T: 'colorant'; N: 0; Name: 'type'; VType: 'Closed Choice of Text'; Lax: False),
    (T: 'colorant'; N: 0; Name: 'cyan'; VType: 'Real'; Lax: False),
    (T: 'colorant'; N: 0; Name: 'magenta'; VType: 'Real'; Lax: False),
    (T: 'colorant'; N: 0; Name: 'yellow'; VType: 'Real'; Lax: False),
    (T: 'colorant'; N: 0; Name: 'black'; VType: 'Real'; Lax: False),
    (T: 'colorant'; N: 0; Name: 'red'; VType: 'Integer'; Lax: False),
    (T: 'colorant'; N: 0; Name: 'green'; VType: 'Integer'; Lax: False),
    (T: 'colorant'; N: 0; Name: 'blue'; VType: 'Integer'; Lax: False),
    (T: 'colorant'; N: 0; Name: 'L'; VType: 'Real'; Lax: False),
    (T: 'colorant'; N: 0; Name: 'A'; VType: 'Integer'; Lax: True),
    (T: 'colorant'; N: 0; Name: 'B'; VType: 'Integer'; Lax: True),
    (T: 'dimensions'; N: 1; Name: 'w'; VType: 'Real'; Lax: False),
    (T: 'dimensions'; N: 1; Name: 'h'; VType: 'Real'; Lax: False),
    (T: 'dimensions'; N: 1; Name: 'unit'; VType: 'Open Choice of Text'; Lax: False),
    (T: 'font'; N: 2; Name: 'fontName'; VType: 'Text'; Lax: False),
    (T: 'font'; N: 2; Name: 'fontFamily'; VType: 'Text'; Lax: False),
    (T: 'font'; N: 2; Name: 'fontFace'; VType: 'Text'; Lax: False),
    (T: 'font'; N: 2; Name: 'fontType'; VType: 'Open Choice of Text'; Lax: False),
    (T: 'font'; N: 2; Name: 'versionString'; VType: 'Text'; Lax: False),
    (T: 'font'; N: 2; Name: 'composite'; VType: 'Boolean'; Lax: False),
    (T: 'font'; N: 2; Name: 'fontFileName'; VType: 'Text'; Lax: False),
    (T: 'font'; N: 2; Name: 'childFontFiles'; VType: 'Seq Text'; Lax: False),
    (T: 'thumbnail'; N: 3; Name: 'height'; VType: 'Integer'; Lax: False),
    (T: 'thumbnail'; N: 3; Name: 'width'; VType: 'Integer'; Lax: False),
    (T: 'thumbnail'; N: 3; Name: 'format'; VType: 'Closed Choice of Text'; Lax: False),
    (T: 'thumbnail'; N: 3; Name: 'image'; VType: 'Text'; Lax: False),
    (T: 'resourceevent'; N: 4; Name: 'action'; VType: 'Open Choice of Text'; Lax: False),
    (T: 'resourceevent'; N: 4; Name: 'instanceID'; VType: 'URI'; Lax: False),
    (T: 'resourceevent'; N: 4; Name: 'parameters'; VType: 'Text'; Lax: False),
    (T: 'resourceevent'; N: 4; Name: 'softwareAgent'; VType: 'AgentName'; Lax: False),
    (T: 'resourceevent'; N: 4; Name: 'when'; VType: 'Date'; Lax: False),
    (T: 'resourceref'; N: 5; Name: 'instanceID'; VType: 'URI'; Lax: False),
    (T: 'resourceref'; N: 5; Name: 'documentID'; VType: 'URI'; Lax: False),
    (T: 'resourceref'; N: 5; Name: 'versionID'; VType: 'Text'; Lax: False),
    (T: 'resourceref'; N: 5; Name: 'renditionClass'; VType: 'RenditionClass'; Lax: False),
    (T: 'resourceref'; N: 5; Name: 'renditionParams'; VType: 'Text'; Lax: False),
    (T: 'resourceref'; N: 5; Name: 'manager'; VType: 'AgentName'; Lax: False),
    (T: 'resourceref'; N: 5; Name: 'managerVariant'; VType: 'Text'; Lax: False),
    (T: 'resourceref'; N: 5; Name: 'manageTo'; VType: 'URI'; Lax: False),
    (T: 'resourceref'; N: 5; Name: 'manageUI'; VType: 'URI'; Lax: False),
    (T: 'version'; N: 6; Name: 'comments'; VType: 'Text'; Lax: False),
    (T: 'version'; N: 6; Name: 'event'; VType: 'ResourceEvent'; Lax: False),
    (T: 'version'; N: 6; Name: 'modifyDate'; VType: 'Date'; Lax: False),
    (T: 'version'; N: 6; Name: 'modifier'; VType: 'ProperName'; Lax: False),
    (T: 'version'; N: 6; Name: 'version'; VType: 'Text'; Lax: False),
    (T: 'job'; N: 7; Name: 'name'; VType: 'Text'; Lax: False),
    (T: 'job'; N: 7; Name: 'id'; VType: 'Text'; Lax: False),
    (T: 'job'; N: 7; Name: 'url'; VType: 'URL'; Lax: False),
    (T: 'beatsplicestretch'; N: 8; Name: 'useFileBeatsMarker'; VType: 'Boolean'; Lax: False),
    (T: 'beatsplicestretch'; N: 8; Name: 'riseInDecibel'; VType: 'Real'; Lax: False),
    (T: 'beatsplicestretch'; N: 8; Name: 'riseInTimeDuration'; VType: 'Time'; Lax: False),
    (T: 'marker'; N: 8; Name: 'startTime'; VType: 'Time'; Lax: True),
    (T: 'marker'; N: 8; Name: 'duration'; VType: 'Time'; Lax: True),
    (T: 'marker'; N: 8; Name: 'comment'; VType: 'Text'; Lax: False),
    (T: 'marker'; N: 8; Name: 'name'; VType: 'Text'; Lax: False),
    (T: 'marker'; N: 8; Name: 'location'; VType: 'URI'; Lax: False),
    (T: 'marker'; N: 8; Name: 'target'; VType: 'Text'; Lax: False),
    (T: 'marker'; N: 8; Name: 'type'; VType: 'Closed Choice of Text'; Lax: False),
    (T: 'media'; N: 8; Name: 'path'; VType: 'URI'; Lax: False),
    (T: 'media'; N: 8; Name: 'track'; VType: 'Text'; Lax: False),
    (T: 'media'; N: 8; Name: 'startTime'; VType: 'Time'; Lax: False),
    (T: 'media'; N: 8; Name: 'duration'; VType: 'Time'; Lax: False),
    (T: 'media'; N: 8; Name: 'managed'; VType: 'Boolean'; Lax: False),
    (T: 'media'; N: 8; Name: 'webStatement'; VType: 'URI'; Lax: False),
    (T: 'projectlink'; N: 8; Name: 'type'; VType: 'Closed Choice of Text'; Lax: False),
    (T: 'projectlink'; N: 8; Name: 'path'; VType: 'URI'; Lax: False),
    (T: 'resamplestretch'; N: 8; Name: 'quality'; VType: 'Closed Choice of Text'; Lax: False),
    (T: 'time'; N: 8; Name: 'value'; VType: 'Integer'; Lax: False),
    (T: 'time'; N: 8; Name: 'scale'; VType: 'Rational'; Lax: False),
    (T: 'timecode'; N: 8; Name: 'timeValue'; VType: 'Text'; Lax: False),
    (T: 'timecode'; N: 8; Name: 'timeFormat'; VType: 'Closed Choice of Text'; Lax: False),
    (T: 'timescalestretch'; N: 8; Name: 'quality'; VType: 'Closed Choice of Text'; Lax: False),
    (T: 'timescalestretch'; N: 8; Name: 'frameSize'; VType: 'Real'; Lax: False),
    (T: 'timescalestretch'; N: 8; Name: 'frameOverlappingPercentage'; VType: 'Real'; Lax: False),
    (T: 'flash'; N: 9; Name: 'Fired'; VType: 'Boolean'; Lax: False),
    (T: 'flash'; N: 9; Name: 'Return'; VType: 'Closed Choice'; Lax: False),
    (T: 'flash'; N: 9; Name: 'Mode'; VType: 'Closed Choice'; Lax: False),
    (T: 'flash'; N: 9; Name: 'Function'; VType: 'Boolean'; Lax: False),
    (T: 'flash'; N: 9; Name: 'RedEyeMode'; VType: 'Boolean'; Lax: False),
    (T: 'oecf/sfr'; N: 9; Name: 'Columns'; VType: 'Integer'; Lax: False),
    (T: 'oecf/sfr'; N: 9; Name: 'Rows'; VType: 'Integer'; Lax: False),
    (T: 'oecf/sfr'; N: 9; Name: 'Names'; VType: 'Seq Text'; Lax: False),
    (T: 'oecf/sfr'; N: 9; Name: 'Values'; VType: 'Seq Rational'; Lax: False),
    (T: 'cfapattern'; N: 9; Name: 'Columns'; VType: 'Integer'; Lax: False),
    (T: 'cfapattern'; N: 9; Name: 'Rows'; VType: 'Integer'; Lax: False),
    (T: 'cfapattern'; N: 9; Name: 'Values'; VType: 'Seq Integer'; Lax: False),
    (T: 'devicesettings'; N: 9; Name: 'Columns'; VType: 'Integer'; Lax: False),
    (T: 'devicesettings'; N: 9; Name: 'Rows'; VType: 'Integer'; Lax: False),
    (T: 'devicesettings'; N: 9; Name: 'Settings'; VType: 'Seq Text'; Lax: False));

function EndsWithStr(const S, ATail: TLandrixEInvoiceString): Boolean;
begin
  Result := (Length(S) >= Length(ATail)) and (Copy(S, Length(S) - Length(ATail) + 1, Length(ATail)) = ATail);
end;

function MatchAt(const S, AWord: TLandrixEInvoiceString; APos: Integer): Boolean;
begin
  Result := Copy(S, APos, Length(AWord)) = AWord;
end;

{ The length of a match of (open |closed )?(choice |choice$)(of )? at APos,
  0 if none (the regular expression tries the group first, then without). }
function ChoiceMatch(const S: TLandrixEInvoiceString; APos: Integer): Integer;
const
  Heads: array[0..2] of string = ('open ', 'closed ', '');
var
  H, P: Integer;
begin
  Result := 0;
  for H := 0 to 2 do
  begin
    P := APos;
    if not MatchAt(S, TLandrixEInvoiceString(Heads[H]), P) then
      Continue;
    Inc(P, Length(Heads[H]));
    if MatchAt(S, 'choice ', P) then
      Inc(P, 7)
    else if MatchAt(S, 'choice', P) and (P + 6 = Length(S) + 1) then
      Inc(P, 6)
    else
      Continue;
    if MatchAt(S, 'of ', P) then
      Inc(P, 3);
    Result := P - APos;
    Exit;
  end;
end;

{ veraPDF's simplified type name: lower case, every "open/closed choice of"
  removed, trimmed; empty is text; a name ending in bag, seq or alt (except
  lang alt) gets " text". False where Java might read it otherwise
  (characters beyond ASCII, line ends) or the name is very long. }
function SimplifyType(const AType: TLandrixEInvoiceString; out AKey: TLandrixEInvoiceString): Boolean;
var
  I, M, A, B: Integer;
  T: TLandrixEInvoiceString;
begin
  Result := False;
  AKey := '';
  if Length(AType) > MaxTypeName then
    Exit;
  for I := 1 to Length(AType) do
    if (Word(AType[I]) > 127) or (AType[I] = #10) or (AType[I] = #13) then
      Exit;
  T := AType;
  for I := 1 to Length(T) do
    if (T[I] >= 'A') and (T[I] <= 'Z') then
      T[I] := WideChar(Word(T[I]) + 32);
  I := 1;
  while I <= Length(T) do
  begin
    M := ChoiceMatch(T, I);
    if M > 0 then
      Inc(I, M)
    else
    begin
      AKey := AKey + T[I];
      Inc(I);
    end;
  end;
  A := 1;
  B := Length(AKey);
  while (A <= B) and (Word(AKey[A]) <= 32) do
    Inc(A);
  while (B >= A) and (Word(AKey[B]) <= 32) do
    Dec(B);
  AKey := Copy(AKey, A, B - A + 1);
  if AKey = '' then
    AKey := 'text'
  else if not EndsWithStr(AKey, 'lang alt') and (EndsWithStr(AKey, 'bag') or EndsWithStr(AKey, 'alt') or
    EndsWithStr(AKey, 'seq')) then
    AKey := AKey + ' text';
  Result := True;
end;

{ An array form prefix of a simplified type name. }
function ArrayPrefix(const AKey: TLandrixEInvoiceString): Boolean;
begin
  Result := (Copy(AKey, 1, 4) = 'bag ') or (Copy(AKey, 1, 4) = 'alt ') or (Copy(AKey, 1, 4) = 'seq ');
end;

function InList(const AKey: TLandrixEInvoiceString; const AList: array of string): Boolean;
var
  I: Integer;
begin
  Result := False;
  for I := 0 to Integer(High(AList)) do
    if AKey = TLandrixEInvoiceString(AList[I]) then
    begin
      Result := True;
      Exit;
    end;
end;

{ A field's value as veraPDF reads it: False if absent; a structure or an
  array has the value ''. }
function FieldValue(ANode: TLandrixEInvoiceXmpNode; out AValue: TLandrixEInvoiceString): Boolean;
begin
  Result := ANode <> nil;
  AValue := '';
  if Result and (ANode.Kind = xmk_Simple) then
    AValue := ANode.Value;
end;

function IsDigit(C: WideChar): Boolean;
begin
  Result := (C >= '0') and (C <= '9');
end;

{ The end of a run of ASCII digits from APos (APos if none). }
function DigitsEnd(const S: TLandrixEInvoiceString; APos: Integer): Integer;
begin
  Result := APos;
  while (Result <= Length(S)) and IsDigit(S[Result]) do
    Inc(Result);
end;

{ Integer: an optional sign and one or more digits. }
function XmpIntegerOk(const S: TLandrixEInvoiceString): Boolean;
var
  P: Integer;
begin
  P := 1;
  if (P <= Length(S)) and ((S[P] = '+') or (S[P] = '-')) then
    Inc(P);
  Result := (DigitsEnd(S, P) > P) and (DigitsEnd(S, P) = Length(S) + 1);
end;

{ Real: an optional sign, at least one digit and at most one decimal point. }
function XmpRealOk(const S: TLandrixEInvoiceString): Boolean;
var
  P, Q, Digits: Integer;
begin
  P := 1;
  if (P <= Length(S)) and ((S[P] = '+') or (S[P] = '-')) then
    Inc(P);
  Q := DigitsEnd(S, P);
  Digits := Q - P;
  if (Q <= Length(S)) and (S[Q] = '.') then
  begin
    P := Q + 1;
    Q := DigitsEnd(S, P);
    Inc(Digits, Q - P);
  end;
  Result := (Digits > 0) and (Q = Length(S) + 1);
end;

function MimeChar(C: WideChar): Boolean;
begin
  Result := ((C >= 'a') and (C <= 'z')) or ((C >= 'A') and (C <= 'Z')) or IsDigit(C) or (C = '_') or (C = '-') or
    (C = '+') or (C = '.');
end;

{ MIMEType: two non-empty tokens of letters, digits, _ - + . separated by
  one slash. }
function XmpMimeOk(const S: TLandrixEInvoiceString): Boolean;
var
  I, Slash: Integer;
begin
  Result := False;
  Slash := 0;
  for I := 1 to Length(S) do
    if S[I] = '/' then
    begin
      if Slash > 0 then
        Exit;
      Slash := I;
    end
    else if not MimeChar(S[I]) then
      Exit;
  Result := (Slash > 1) and (Slash < Length(S));
end;

{ GPSCoordinate: DDD,MM,SSk or DDD,MM.mmk (1-3, 1-2 and 1-2 digits, any
  number of fraction digits, k one of N S E W). }
function XmpGpsOk(const S: TLandrixEInvoiceString): Boolean;
var
  P, Q: Integer;
begin
  Result := False;
  Q := DigitsEnd(S, 1);
  if (Q < 2) or (Q > 4) or (Q > Length(S)) or (S[Q] <> ',') then
    Exit;
  P := Q + 1;
  Q := DigitsEnd(S, P);
  if (Q = P) or (Q - P > 2) or (Q > Length(S)) then
    Exit;
  P := Q + 1;
  if S[Q] = ',' then
  begin
    Q := DigitsEnd(S, P);
    if (Q = P) or (Q - P > 2) then
      Exit;
  end
  else if S[Q] = '.' then
  begin
    Q := DigitsEnd(S, P);
    if Q = P then
      Exit;
  end
  else
    Exit;
  Result := (Q = Length(S)) and ((S[Q] = 'N') or (S[Q] = 'S') or (S[Q] = 'E') or (S[Q] = 'W'));
end;

{ Date as the XMP parser of veraPDF reads ISO 8601: empty passes; a year
  (optional minus), then -month, -day, then only after a day Thh, :mm, :ss,
  .fraction, then Z or +/-hh[:mm]; a separator needs digits, nothing may
  follow (a T only after a full date). A value that is complete up to its
  end but has very long digit runs (Java ints), and a time zone right after
  a date, are not decided. }
function XmpDateOk(const S: TLandrixEInvoiceString): TLandrixEInvoiceXmpTruth;
var
  P, Part: Integer;
  Long: Boolean;

  function Digits: Boolean;
  var
    Q: Integer;
  begin
    Q := DigitsEnd(S, P);
    Result := Q > P;
    if Q - P > 9 then
      Long := True;
    P := Q;
  end;

  function AtEnd: Boolean;
  begin
    Result := P > Length(S);
  end;

begin
  Result := xmt_Yes;
  if S = '' then
    Exit;
  Result := xmt_No;
  Part := 0;
  Long := False;
  P := 1;
  if S[P] = '-' then
    Inc(P);
  if not Digits then
    Exit;
  { year, month, day }
  while (Part < 2) and not AtEnd and (S[P] = '-') do
  begin
    Inc(P);
    if not Digits then
      Exit;
    Inc(Part);
  end;
  if not AtEnd and (Part = 2) and (S[P] = 'T') then
  begin
    Inc(P);
    if not Digits then
      Exit;
    if not AtEnd and (S[P] = ':') then
    begin
      Inc(P);
      if not Digits then
        Exit;
      if not AtEnd and (S[P] = ':') then
      begin
        Inc(P);
        if not Digits then
          Exit;
        if not AtEnd and (S[P] = '.') then
        begin
          Inc(P);
          if not Digits then
            Exit;
        end;
      end;
    end;
    if not AtEnd and (S[P] = 'Z') then
      Inc(P)
    else if not AtEnd and ((S[P] = '+') or (S[P] = '-')) then
    begin
      Inc(P);
      if not Digits then
        Exit;
      if not AtEnd and (S[P] = ':') then
      begin
        Inc(P);
        if not Digits then
          Exit;
      end;
    end;
  end
  else if not AtEnd and ((S[P] = 'Z') or (S[P] = '+') or (S[P] = '-')) then
  begin
    Result := xmt_Unknown;
    Exit;
  end;
  if not AtEnd then
  begin
    if Long then
      Result := xmt_Unknown;
    Exit;
  end;
  if Long then
    Result := xmt_Unknown
  else
    Result := xmt_Yes;
end;

function LandrixEInvoiceXmpPredefined(const ANs, ALocal: TLandrixEInvoiceString; out AType: TLandrixEInvoiceString;
  out ALax: Boolean): Boolean;
var
  I: Integer;
begin
  Result := False;
  AType := '';
  ALax := False;
  for I := 0 to High(XmpProps) do
    if (ALocal = TLandrixEInvoiceString(XmpProps[I].Name)) and
      (ANs = TLandrixEInvoiceString(XmpPropNs[XmpProps[I].N])) then
    begin
      AType := TLandrixEInvoiceString(XmpProps[I].VType);
      ALax := XmpProps[I].Lax;
      Result := True;
      Exit;
    end;
end;

function TLandrixEInvoiceXmpSchemaTypes.IndexOf(const AUri: TLandrixEInvoiceString): Integer;
var
  I: Integer;
begin
  Result := -1;
  for I := 0 to FCount - 1 do
    if FUris[I] = AUri then
    begin
      Result := I;
      Exit;
    end;
end;

function TLandrixEInvoiceXmpSchemaTypes.TypeIndex(AEntry: Integer; const AKey: TLandrixEInvoiceString): Integer;
var
  I: Integer;
begin
  Result := -1;
  for I := 0 to FTypeCounts[AEntry] - 1 do
    if FTypes[AEntry][I].Key = AKey then
    begin
      Result := I;
      Exit;
    end;
end;

{ Registers a type; one with the same name is replaced. }
procedure TLandrixEInvoiceXmpSchemaTypes.PutType(AEntry: Integer; const AType: TLandrixEInvoiceXmpCustomType);
var
  I: Integer;
begin
  I := TypeIndex(AEntry, AType.Key);
  if I < 0 then
  begin
    if FTypeCounts[AEntry] >= MaxSchemaKeys then
    begin
      FOverflow := True;
      Exit;
    end;
    if FTypeCounts[AEntry] = Integer(Length(FTypes[AEntry])) then
      SetLength(FTypes[AEntry], 8 + 2 * FTypeCounts[AEntry]);
    I := FTypeCounts[AEntry];
    Inc(FTypeCounts[AEntry]);
  end;
  FTypes[AEntry][I] := AType;
end;

{ The types of an array pdfaSchema:valueType (other forms define none): a
  type name; fields (in an array pdfaType:field, each with a name and a
  value type, a later one with the same name replacing it) only if the type
  has a namespace URI. }
procedure TLandrixEInvoiceXmpSchemaTypes.AddTypes(AEntry: Integer; ADefinition: TLandrixEInvoiceXmpNode);
var
  VT, T, FL, F: TLandrixEInvoiceXmpNode;
  I, J, K: Integer;
  Name, FName, FType: TLandrixEInvoiceString;
  Def: TLandrixEInvoiceXmpCustomType;
  HasNs, Found: Boolean;
begin
  VT := ADefinition.FindChild(LandrixEInvoiceXmpNsPdfaSchema, 'valueType');
  if (VT = nil) or (VT.Kind <> xmk_Array) then
    Exit;
  for I := 0 to VT.ChildCount - 1 do
  begin
    T := VT.Child(I);
    if not FieldValue(T.FindChild(LandrixEInvoiceXmpNsPdfaType, 'type'), Name) then
      Continue;
    Def.Key := '';
    Def.FieldNames := nil;
    Def.FieldTypes := nil;
    Def.FieldCount := 0;
    HasNs := FieldValue(T.FindChild(LandrixEInvoiceXmpNsPdfaType, 'namespaceURI'), Def.Ns);
    FL := T.FindChild(LandrixEInvoiceXmpNsPdfaType, 'field');
    if (FL <> nil) and (FL.Kind = xmk_Array) then
      for J := 0 to FL.ChildCount - 1 do
      begin
        F := FL.Child(J);
        if not FieldValue(F.FindChild(LandrixEInvoiceXmpNsPdfaField, 'name'), FName) or
          not FieldValue(F.FindChild(LandrixEInvoiceXmpNsPdfaField, 'valueType'), FType) then
          Continue;
        Found := False;
        for K := 0 to Def.FieldCount - 1 do
          if Def.FieldNames[K] = FName then
          begin
            Def.FieldTypes[K] := FType;
            Found := True;
          end;
        if not Found then
        begin
          if Def.FieldCount >= MaxSchemaKeys then
          begin
            FOverflow := True;
            Exit;
          end;
          if Def.FieldCount = Integer(Length(Def.FieldNames)) then
          begin
            SetLength(Def.FieldNames, 8 + 2 * Def.FieldCount);
            SetLength(Def.FieldTypes, Length(Def.FieldNames));
          end;
          Def.FieldNames[Def.FieldCount] := FName;
          Def.FieldTypes[Def.FieldCount] := FType;
          Inc(Def.FieldCount);
        end;
      end;
    if (Def.FieldCount > 0) and not HasNs then
      Continue;
    if SimplifyType(Name, Def.Key) then
      PutType(AEntry, Def)
    else
      FUncertain[AEntry] := True;
  end;
end;

{ The properties of the schema: name and value type present, the type
  known to the schema; the first with one name counts. A property whose
  type is not decided makes its name not decided. }
procedure TLandrixEInvoiceXmpSchemaTypes.AddProperties(AEntry: Integer; ADefinition: TLandrixEInvoiceXmpNode);
var
  L, P: TLandrixEInvoiceXmpNode;
  I, J: Integer;
  Name, VType: TLandrixEInvoiceString;
  Known: TLandrixEInvoiceXmpTruth;
  Found: Boolean;
begin
  L := ADefinition.FindChild(LandrixEInvoiceXmpNsPdfaSchema, 'property');
  for I := 0 to L.ChildCount - 1 do
  begin
    P := L.Child(I);
    if not FieldValue(P.FindChild(LandrixEInvoiceXmpNsPdfaProperty, 'name'), Name) or
      not FieldValue(P.FindChild(LandrixEInvoiceXmpNsPdfaProperty, 'valueType'), VType) then
      Continue;
    Known := IsKnown(AEntry, VType);
    if Known = xmt_No then
      Continue;
    { each definition is compared with every kept one: bound the work }
    Inc(FPropChecked);
    if FPropChecked > 4 * MaxSchemaProps then
    begin
      FOverflow := True;
      Exit;
    end;
    Found := False;
    for J := 0 to FPropCount - 1 do
      if (FPropNames[J] = Name) and (FPropUris[J] = FUris[AEntry]) then
      begin
        Found := True;
        Break;
      end;
    if Found then
      Continue;
    if FPropCount >= MaxSchemaProps then
    begin
      FOverflow := True;
      Exit;
    end;
    if FPropCount = Integer(Length(FPropUris)) then
    begin
      SetLength(FPropUris, 16 + 2 * FPropCount);
      SetLength(FPropNames, Length(FPropUris));
      SetLength(FPropTypes, Length(FPropUris));
      SetLength(FPropEntries, Length(FPropUris));
      SetLength(FPropUncertain, Length(FPropUris));
    end;
    FPropUris[FPropCount] := FUris[AEntry];
    FPropNames[FPropCount] := Name;
    FPropTypes[FPropCount] := VType;
    FPropEntries[FPropCount] := AEntry;
    FPropUncertain[FPropCount] := Known = xmt_Unknown;
    Inc(FPropCount);
  end;
end;

procedure TLandrixEInvoiceXmpSchemaTypes.Build(APacket: TLandrixEInvoiceXmpPacket;
  AMain: TLandrixEInvoiceXmpSchemaTypes; AFurther: Boolean);
var
  C, D, P: TLandrixEInvoiceXmpNode;
  I, J, E, M: Integer;
  Uri: TLandrixEInvoiceString;
  EntryOf, LastOf: array of Integer;
begin
  EntryOf := nil;
  LastOf := nil;
  { drop what an earlier packet left }
  FUris := nil;
  FTypes := nil;
  FTypeCounts := nil;
  FUncertain := nil;
  FSeeded := nil;
  FCount := 0;
  FPropUris := nil;
  FPropNames := nil;
  FPropTypes := nil;
  FPropEntries := nil;
  FPropUncertain := nil;
  FPropCount := 0;
  FPropChecked := 0;
  FOverflow := AFurther and (AMain <> nil) and AMain.FOverflow;
  if FOverflow or (APacket.State <> xms_Valid) then
    Exit;
  C := APacket.Find(LandrixEInvoiceXmpNsPdfaExtension, 'schemas');
  if (C = nil) or (C.Kind <> xmk_Array) then
    Exit;
  { the qualifying schema items; of several with one URI the last counts }
  SetLength(EntryOf, C.ChildCount);
  SetLength(LastOf, MaxSchemaEntries);
  for I := 0 to C.ChildCount - 1 do
  begin
    EntryOf[I] := -1;
    D := C.Child(I);
    P := D.FindChild(LandrixEInvoiceXmpNsPdfaSchema, 'property');
    if not FieldValue(D.FindChild(LandrixEInvoiceXmpNsPdfaSchema, 'namespaceURI'), Uri) or (P = nil) or
      (P.Kind <> xmk_Array) then
      Continue;
    E := IndexOf(Uri);
    if E < 0 then
    begin
      if FCount >= MaxSchemaEntries then
      begin
        FOverflow := True;
        Exit;
      end;
      if FCount = Integer(Length(FUris)) then
      begin
        SetLength(FUris, 4 + 2 * FCount);
        SetLength(FTypes, Length(FUris));
        SetLength(FTypeCounts, Length(FUris));
        SetLength(FUncertain, Length(FUris));
        SetLength(FSeeded, Length(FUris));
      end;
      E := FCount;
      Inc(FCount);
      FUris[E] := Uri;
      FTypeCounts[E] := 0;
      FUncertain[E] := False;
      FSeeded[E] := False;
    end;
    EntryOf[I] := E;
    LastOf[E] := I;
  end;
  { per entry: in a further packet the main packet's entry for the URI
    first, then the types of the counting item }
  for I := 0 to C.ChildCount - 1 do
  begin
    E := EntryOf[I];
    if (E < 0) or (LastOf[E] <> I) then
      Continue;
    if AFurther and (AMain <> nil) then
    begin
      M := AMain.IndexOf(FUris[E]);
      if M >= 0 then
      begin
        FSeeded[E] := True;
        FUncertain[E] := AMain.FUncertain[M];
        for J := 0 to AMain.FTypeCounts[M] - 1 do
          PutType(E, AMain.FTypes[M][J]);
      end;
    end;
    AddTypes(E, C.Child(I));
  end;
  { then the properties, which need the types }
  for I := 0 to C.ChildCount - 1 do
    if (EntryOf[I] >= 0) and (LastOf[EntryOf[I]] = I) then
      AddProperties(EntryOf[I], C.Child(I));
end;

function TLandrixEInvoiceXmpSchemaTypes.Entry(const ASchemaUri: TLandrixEInvoiceString; AHasUri: Boolean): Integer;
begin
  Result := -1;
  if AHasUri then
    Result := IndexOf(ASchemaUri);
end;

function TLandrixEInvoiceXmpSchemaTypes.IsKnown(AEntry: Integer;
  const AType: TLandrixEInvoiceString): TLandrixEInvoiceXmpTruth;
var
  Key: TLandrixEInvoiceString;
begin
  Result := xmt_Unknown;
  if not SimplifyType(AType, Key) then
    Exit;
  { unlike ValidateKey, veraPDF does not simplify the item type again here }
  while ArrayPrefix(Key) do
    Key := Copy(Key, 5, MaxInt);
  if InList(Key, BasicTypes) then
  begin
    Result := xmt_Yes;
    Exit;
  end;
  if FOverflow then
    Exit;
  if AEntry = LandrixEInvoiceXmpPredefinedEntry then
  begin
    if InList(Key, PredefinedTypes) then
      Result := xmt_Yes
    else
      Result := xmt_No;
    Exit;
  end;
  if (AEntry < 0) or (AEntry >= FCount) then
  begin
    Result := xmt_No;
    Exit;
  end;
  if InList(Key, PredefinedTypes) or (TypeIndex(AEntry, Key) >= 0) then
    Result := xmt_Yes
  else if FUncertain[AEntry] then
    Result := xmt_Unknown
  else
    Result := xmt_No;
end;

function TLandrixEInvoiceXmpSchemaTypes.Defines(const ANs, ALocal: TLandrixEInvoiceString;
  out AType: TLandrixEInvoiceString; out AEntry: Integer): TLandrixEInvoiceXmpTruth;
var
  I: Integer;
begin
  AType := '';
  AEntry := -1;
  Result := xmt_No;
  for I := 0 to FPropCount - 1 do
    if (FPropNames[I] = ALocal) and (FPropUris[I] = ANs) then
    begin
      AType := FPropTypes[I];
      AEntry := FPropEntries[I];
      if FPropUncertain[I] then
        Result := xmt_Unknown
      else
        Result := xmt_Yes;
      Exit;
    end;
  if FOverflow then
    Result := xmt_Unknown;
end;

{ Combines the answers for the parts of one value: one no is no. }
function Both(A, B: TLandrixEInvoiceXmpTruth): TLandrixEInvoiceXmpTruth;
begin
  if (A = xmt_No) or (B = xmt_No) then
    Result := xmt_No
  else if (A = xmt_Unknown) or (B = xmt_Unknown) then
    Result := xmt_Unknown
  else
    Result := xmt_Yes;
end;

function HasLangItem(ANode: TLandrixEInvoiceXmpNode): Boolean;
var
  I, J: Integer;
begin
  Result := False;
  for I := 0 to ANode.ChildCount - 1 do
    for J := 0 to ANode.Child(I).QualifierCount - 1 do
      if (ANode.Child(I).Qualifier(J).Ns = LandrixEInvoiceXmpNsXml) and
        (ANode.Child(I).Qualifier(J).Local = 'lang') then
      begin
        Result := True;
        Exit;
      end;
end;

{ A structure of the type AKey: every field a field of the type (the
  built-in types of XmpFields or a type of the entry) with a valid value. }
function TLandrixEInvoiceXmpSchemaTypes.ValidateFields(ANode: TLandrixEInvoiceXmpNode;
  const AKey: TLandrixEInvoiceString; AEntry, ADepth: Integer): TLandrixEInvoiceXmpTruth;
var
  I, J, T: Integer;
  F: TLandrixEInvoiceXmpNode;
  FKey: TLandrixEInvoiceString;
  Found: Boolean;
  R: TLandrixEInvoiceXmpTruth;
begin
  if ANode.Kind <> xmk_Struct then
  begin
    Result := xmt_No;
    Exit;
  end;
  Result := xmt_Yes;
  T := -1;
  if AEntry >= 0 then
    T := TypeIndex(AEntry, AKey);
  for I := 0 to ANode.ChildCount - 1 do
  begin
    F := ANode.Child(I);
    Found := False;
    R := xmt_Unknown;
    if T >= 0 then
    begin
      for J := 0 to FTypes[AEntry][T].FieldCount - 1 do
        if (F.Local = FTypes[AEntry][T].FieldNames[J]) and (F.Ns = FTypes[AEntry][T].Ns) then
        begin
          Found := True;
          if SimplifyType(FTypes[AEntry][T].FieldTypes[J], FKey) then
            R := ValidateKey(F, FKey, AEntry, ADepth + 1);
          Break;
        end;
    end
    else
      for J := 0 to High(XmpFields) do
        if (AKey = TLandrixEInvoiceString(XmpFields[J].T)) and (F.Local = TLandrixEInvoiceString(XmpFields[J].Name)) and
          (F.Ns = TLandrixEInvoiceString(XmpFieldNs[XmpFields[J].N])) then
        begin
          Found := True;
          if SimplifyType(TLandrixEInvoiceString(XmpFields[J].VType), FKey) then
            R := ValidateKey(F, FKey, AEntry, ADepth + 1);
          if XmpFields[J].Lax and (R = xmt_No) then
            R := xmt_Unknown;
          Break;
        end;
    if not Found then
      R := xmt_No;
    Result := Both(Result, R);
    if Result = xmt_No then
      Exit;
  end;
end;

function TLandrixEInvoiceXmpSchemaTypes.ValidateKey(ANode: TLandrixEInvoiceXmpNode;
  const AKey: TLandrixEInvoiceString; AEntry, ADepth: Integer): TLandrixEInvoiceXmpTruth;
var
  I, T: Integer;
  Rest: TLandrixEInvoiceString;
  Simple, Builtin: Boolean;
begin
  Result := xmt_Unknown;
  if ADepth > MaxTypeDepth then
    Exit;
  Simple := ANode.Kind = xmk_Simple;
  { a type an extension schema defines under a built-in name (or Lang
    Alt, an array form, Any) is not decided }
  T := -1;
  if AEntry >= 0 then
    T := TypeIndex(AEntry, AKey);
  Builtin := InList(AKey, BasicTypes) or InList(AKey, PredefinedTypes) or ArrayPrefix(AKey) or (AKey = 'any');
  if (T >= 0) and Builtin then
    Exit;
  { veraPDF accepts any value for the type Any }
  if AKey = 'any' then
  begin
    Result := xmt_Yes;
    Exit;
  end;
  if AKey = 'lang alt' then
  begin
    if (ANode.Kind = xmk_Array) and (ANode.ArrayForm = xma_Alt) and ((ANode.ChildCount = 0) or HasLangItem(ANode)) then
      Result := xmt_Yes
    else
      Result := xmt_No;
    Exit;
  end;
  if ArrayPrefix(AKey) then
  begin
    { the item type is simplified again }
    if not SimplifyType(Copy(AKey, 5, MaxInt), Rest) then
      Exit;
    if (ANode.Kind <> xmk_Array) or ((Copy(AKey, 1, 4) = 'bag ') and (ANode.ArrayForm <> xma_Bag)) or
      ((Copy(AKey, 1, 4) = 'seq ') and (ANode.ArrayForm <> xma_Seq)) or
      ((Copy(AKey, 1, 4) = 'alt ') and (ANode.ArrayForm <> xma_Alt)) then
    begin
      Result := xmt_No;
      Exit;
    end;
    Result := xmt_Yes;
    for I := 0 to ANode.ChildCount - 1 do
    begin
      Result := Both(Result, ValidateKey(ANode.Child(I), Rest, AEntry, ADepth + 1));
      if Result = xmt_No then
        Exit;
    end;
    Exit;
  end;
  if InList(AKey, BasicTypes) then
  begin
    if not Simple then
      Result := xmt_No
    else if AKey = 'boolean' then
    begin
      if (ANode.Value = 'True') or (ANode.Value = 'False') then
        Result := xmt_Yes
      else
        Result := xmt_No;
    end
    else if AKey = 'integer' then
    begin
      if XmpIntegerOk(ANode.Value) then
        Result := xmt_Yes
      else
        Result := xmt_No;
    end
    else if AKey = 'real' then
    begin
      if XmpRealOk(ANode.Value) then
        Result := xmt_Yes
      else
        Result := xmt_No;
    end
    else if AKey = 'mimetype' then
    begin
      if XmpMimeOk(ANode.Value) then
        Result := xmt_Yes
      else
        Result := xmt_No;
    end
    else if AKey = 'date' then
      Result := XmpDateOk(ANode.Value)
    else if AKey = 'xpath' then
      { veraPDF compiles it as an XPath expression }
      Result := xmt_Unknown
    else
      Result := xmt_Yes;
    Exit;
  end;
  if (AEntry = -1) or FOverflow then
  begin
    { the basic types only, or not certain }
    if FOverflow then
      Result := xmt_Unknown
    else
      Result := xmt_No;
    Exit;
  end;
  if InList(AKey, PredefinedTypes) then
  begin
    if AKey = 'locale' then
    begin
      if Simple then
        Result := xmt_Yes
      else
        Result := xmt_No;
    end
    else if AKey = 'gpscoordinate' then
    begin
      if Simple and XmpGpsOk(ANode.Value) then
        Result := xmt_Yes
      else
        Result := xmt_No;
    end
    else
      { the fields resolve their types in the same schema entry }
      Result := ValidateFields(ANode, AKey, AEntry, ADepth);
    Exit;
  end;
  if T >= 0 then
  begin
    { a further packet's types copied from the main packet resolve nested
      types in the main packet's entry }
    if (ADepth > 0) and FSeeded[AEntry] then
      Exit;
    if FTypes[AEntry][T].FieldCount = 0 then
    begin
      if Simple then
        Result := xmt_Yes
      else
        Result := xmt_No;
    end
    else
      Result := ValidateFields(ANode, AKey, AEntry, ADepth);
    Exit;
  end;
  if (AEntry >= 0) and FUncertain[AEntry] then
    Result := xmt_Unknown
  else
    Result := xmt_No;
end;

function TLandrixEInvoiceXmpSchemaTypes.Validate(ANode: TLandrixEInvoiceXmpNode; const AType: TLandrixEInvoiceString;
  AEntry: Integer): TLandrixEInvoiceXmpTruth;
var
  Key: TLandrixEInvoiceString;
begin
  Result := xmt_Unknown;
  if (ANode = nil) or not SimplifyType(AType, Key) then
    Exit;
  Result := ValidateKey(ANode, Key, AEntry, 0);
  { a type name not read with certainty may have replaced a built-in type
    (either way) }
  if (Result <> xmt_Unknown) and (FOverflow or ((AEntry >= 0) and (AEntry < FCount) and FUncertain[AEntry])) then
    Result := xmt_Unknown;
end;

end.
