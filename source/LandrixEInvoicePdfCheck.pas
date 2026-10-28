{
  EInvoice-for-Pascal

  Copyright (C) 2026 Landrix Software GmbH & Co. KG

  This file is dual-licensed under:
  - GNU GPL version 3 or later; or
  - the Landrix Software Commercial License.

  See LICENSE and COMMERCIAL-LICENSE.md.

  SPDX-License-Identifier: GPL-3.0-or-later OR LicenseRef-Landrix-Commercial
}

{ Checks of a hybrid invoice PDF (ZUGFeRD 2.5.2 / Factur-X 1.09.2). So far
  level 2, the embedding of the invoice XML: the business rules for hybrid
  documents of the specification (annex 3.d) BR-HYBRID-12 (embedding
  method, a collective rule: several findings share it), BR-HYBRID-13 (file
  name) and BR-HYBRID-11 (/AFRelationship, without profile and country only
  the values the table allows at all), plus own findings LX-PDF-01 to
  LX-PDF-09 for what the rules do not name. The checker reads no XML except
  for well-formedness; profile and countries come from the caller in a later
  step. ZUGFeRD 1.0 and 2.0 are recognised and extracted, not checked. A
  rebuilt object table or a reached limit never gives eps_Passed.
  Damaged or hostile input is a finding, not an exception.

  DE: Pruefungen eines hybriden Rechnungs-PDFs (ZUGFeRD 2.5.2 / Factur-X
  1.09.2). Bisher Ebene 2, die Einbettung der Rechnungs-XML: die
  Geschaeftsregeln fuer hybride Dokumente der Spezifikation (Anhang 3.d)
  BR-HYBRID-12 (Einbettungsmethode, eine Sammelregel: mehrere Befunde
  teilen sie), BR-HYBRID-13 (Dateiname) und BR-HYBRID-11
  (/AFRelationship, ohne Profil und Land nur die Werte, die die Tabelle
  ueberhaupt erlaubt), dazu eigene Befunde LX-PDF-01 bis LX-PDF-09 fuer
  das, was die Regeln nicht nennen. Der Pruefer liest keine XML ausser auf
  Wohlgeformtheit; Profil und Laender kommen in einem spaeteren Schritt vom
  Aufrufer. ZUGFeRD 1.0 und 2.0 werden erkannt und extrahiert, nicht
  geprueft. Eine neu aufgebaute Objekttabelle oder eine erreichte Grenze
  ergibt nie eps_Passed. Beschaedigte oder feindliche Eingaben sind ein
  Befund, keine Ausnahme. }

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
    { Version from the header (e.g. 1.7) and /Version of the catalog ('' if
      absent).
      DE: Version aus dem Kopf (z. B. 1.7) und /Version des Katalogs ('',
      wenn sie fehlt). }
    PdfVersion: TLandrixEInvoiceString;
    CatalogVersion: TLandrixEInvoiceString;
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

  { Runs the checks. Both entries clear AResult first and return the number
    of errors (findings with eds_Error), as TLandrixEInvoice.Check does.
    The stream variant reads AStream from its position to the end.
    DE: Fuehrt die Pruefungen aus. Beide Einstiege leeren AResult zuerst und
    liefern die Anzahl der Fehler (Befunde mit eds_Error), wie
    TLandrixEInvoice.Check. Die Stream-Variante liest AStream ab seiner
    Position bis zum Ende. }
  TLandrixEInvoicePdfChecker = class(TObject)
  public
    function CheckStream(AStream: TStream; AResult: TLandrixEInvoicePdfCheckResult): Integer;
    function CheckFile(const AFileName: string; AResult: TLandrixEInvoicePdfCheckResult): Integer;
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
  PdfVersion := '';
  CatalogVersion := '';
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

function TLandrixEInvoicePdfChecker.CheckStream(AStream: TStream; AResult: TLandrixEInvoicePdfCheckResult): Integer;
var
  Doc: TLandrixEInvoicePdfDocument;
  Check: TEmbeddingCheck;
  Err: string;
  Incomplete: Boolean;
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
    Check := TEmbeddingCheck.Create(Doc, AResult);
    try
      try
        Check.Run;
        Incomplete := Incomplete or Check.Incomplete;
      except
        on E: Exception do
          AddFinding(AResult, RuleUnreadable, eds_Error, ToText('PDF not readable: ' + E.Message));
      end;
    finally
      Check.Free;
    end;
  finally
    Doc.Free;
  end;
  Result := CountErrors(AResult.Diagnostics);
  if Result > 0 then
    AResult.Status[epl_Embedding] := eps_Failed
  else if Incomplete then
    AResult.Status[epl_Embedding] := eps_Incomplete
  else
    AResult.Status[epl_Embedding] := eps_Passed;
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
