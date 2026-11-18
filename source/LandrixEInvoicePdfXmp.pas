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
    not attributes (HasNsDecl tells whether there were any). }
  TDom = class(TObject)
  public
    Kind: TDomKind;
    Ns: TLandrixEInvoiceString;
    Local: TLandrixEInvoiceString;
    Prefix: TLandrixEInvoiceString;
    Text: TLandrixEInvoiceString;
    Attrs: array of TDomAttr;
    AttrCount: Integer;
    HasNsDecl: Boolean;
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
  Cur, N: TDom;
  I, Nodes: Integer;
begin
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
                if R.IsNamespaceDeclaration(I) then
                  N.HasNsDecl := True
                else
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
              if (Cur.Count > 0) and (Cur.Child(Cur.Count - 1).Kind = dk_Text) then
                Cur.Child(Cur.Count - 1).Text := Cur.Child(Cur.Count - 1).Text + R.ValueW
              else
                Cur.Add(dk_Text).Text := R.ValueW;
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
  { the parser demands attributes on rdf:RDF; whether a namespace
    declaration elsewhere would do is not known }
  if (ARoot.AttrCount = 0) and not ARoot.HasNsDecl then
    NotDecided('rdf:RDF without attributes');
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

end.
