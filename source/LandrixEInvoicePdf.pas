{
  EInvoice-for-Pascal

  Copyright (C) 2026 Landrix Software GmbH & Co. KG

  This file is dual-licensed under:
  - GNU GPL version 3 or later; or
  - the Landrix Software Commercial License.

  See LICENSE and COMMERCIAL-LICENSE.md.

  SPDX-License-Identifier: GPL-3.0-or-later OR LicenseRef-Landrix-Commercial
}

{ Extraction of the embedded invoice XML from a ZUGFeRD, Factur-X or
  XRechnung PDF (PDF/A-3) in plain Pascal, without external tools.

  This is not a PDF reader: no rendering, fonts or graphics. It follows
  trailer -> /Root -> /Names/EmbeddedFiles or /AF -> file specification ->
  stream, and it resolves the object graph through the xref chain instead of
  scanning the raw bytes: in an incremental update the replaced versions of
  objects stay in the file, and only the xref chain says which one is
  current. A scanner could return a replaced invoice while every viewer shows
  the current one.

  If the xref chain is unusable, the object table is rebuilt by a scan and
  the last definition of an object number wins; UsedReconstruction reports
  that, because the protection described above is then gone.

  Stream filters: FlateDecode (own inflate, RFC 1950/1951), LZWDecode,
  ASCIIHexDecode, ASCII85Decode, RunLengthDecode, each with /Predictor.
  Encrypted files (forbidden by PDF/A-3, common anyway) are read through the
  standard security handler with RC4 (/V 1, 2, and 4 with /CFM /V2; /R 2 to
  4) when the user password is empty. AES and a real user password are
  reported, not guessed. Attachments on page level are not searched. The
  object layer, the filters and the decryption are in the internal unit
  LandrixEInvoicePdfObjects.

  DE: Extraktion der eingebetteten Rechnungs-XML aus einem ZUGFeRD-,
  Factur-X- oder XRechnung-PDF (PDF/A-3) in reinem Pascal, ohne externe
  Werkzeuge.

  Das ist kein PDF-Reader: kein Rendering, keine Fonts, keine Grafik. Der
  Weg ist Trailer -> /Root -> /Names/EmbeddedFiles bzw. /AF ->
  Dateispezifikation -> Stream, und der Objektgraph wird ueber die
  xref-Kette aufgeloest statt die Rohdaten zu durchsuchen: Bei einem
  inkrementellen Update bleiben ersetzte Fassungen von Objekten in der
  Datei, und nur die xref-Kette sagt, welche gilt. Ein Scanner koennte eine
  ersetzte Rechnung liefern, waehrend jeder Betrachter die aktuelle zeigt.

  Ist die xref-Kette unbrauchbar, wird die Objekttabelle per Scan
  rekonstruiert und die letzte Definition einer Objektnummer gewinnt;
  UsedReconstruction meldet das, weil der oben beschriebene Schutz dann
  fehlt.

  Stromfilter: FlateDecode (eigener Inflate, RFC 1950/1951), LZWDecode,
  ASCIIHexDecode, ASCII85Decode, RunLengthDecode, jeweils mit /Predictor.
  Verschluesselte Dateien (von PDF/A-3 verboten, trotzdem verbreitet) werden
  ueber den Standard-Security-Handler mit RC4 gelesen (/V 1, 2 und 4 mit
  /CFM /V2; /R 2 bis 4), wenn das Benutzerpasswort leer ist. AES und ein
  echtes Benutzerpasswort werden gemeldet, nicht geraten. Anhaenge auf
  Seitenebene werden nicht gesucht. Objektschicht, Filter und
  Entschluesselung stehen in der internen Unit LandrixEInvoicePdfObjects. }

{ API: stable. Covered by semantic versioning from release 1.0 on.
  DE: API: stabil. Ab Version 1.0 durch die semantische Versionierung
  abgedeckt. }

unit LandrixEInvoicePdf;

{$I LandrixEInvoice.inc}

interface

uses
  Classes,
  Contnrs,
  LandrixEInvoiceTypes;

type
  { Classification of an embedded file. epa_Unspecified: not classified
    (never set by the extractor). epa_Invoice: the root element is a CII or
    UBL invoice. epa_OtherXml: another XML document. epa_Other: not XML.
    DE: Einordnung einer eingebetteten Datei. epa_Unspecified: nicht
    eingeordnet (setzt der Extraktor nie). epa_Invoice: das Wurzelelement
    ist eine CII- oder UBL-Rechnung. epa_OtherXml: ein anderes XML-Dokument.
    epa_Other: kein XML. }
  TLandrixEInvoicePdfAttachmentKind = (epa_Unspecified, epa_Invoice, epa_OtherXml, epa_Other);

  { One embedded file. DE: Eine eingebettete Datei. }
  TLandrixEInvoicePdfAttachment = class(TObject)
  private
    FFileName: TLandrixEInvoiceString;
    FRelationship: TLandrixEInvoiceString;
    FMimeType: TLandrixEInvoiceString;
    FDescription: TLandrixEInvoiceString;
    FRootElement: TLandrixEInvoiceString;
    FData: TMemoryStream;
    FKind: TLandrixEInvoicePdfAttachmentKind;
    function GetSize: Integer;
  public
    constructor Create;
    destructor Destroy; override;
    { File name from /UF, else /F of the file specification.
      DE: Dateiname aus /UF, sonst /F der Dateispezifikation. }
    property FileName: TLandrixEInvoiceString read FFileName write FFileName;
    { /AFRelationship. Unreliable in practice (Alternative, Data, Source and
      Unspecified all occur for the invoice); do not filter by it.
      DE: /AFRelationship. In der Praxis unzuverlaessig (fuer die Rechnung
      kommen Alternative, Data, Source und Unspecified vor); nicht danach
      filtern. }
    property Relationship: TLandrixEInvoiceString read FRelationship write FRelationship;
    { /Subtype of the stream, e.g. text/xml. DE: /Subtype des Streams, z. B.
      text/xml. }
    property MimeType: TLandrixEInvoiceString read FMimeType write FMimeType;
    property Description: TLandrixEInvoiceString read FDescription write FDescription;
    { The decoded content; owned by the attachment.
      DE: Der dekodierte Inhalt; gehoert dem Anhang. }
    property Data: TMemoryStream read FData;
    property Size: Integer read GetSize;
    property Kind: TLandrixEInvoicePdfAttachmentKind read FKind write FKind;
    { Local name of the XML root element; '' if the data is not XML.
      DE: Lokalname des XML-Wurzelelements; '', wenn die Daten kein XML
      sind. }
    property RootElement: TLandrixEInvoiceString read FRootElement write FRootElement;
  end;

  { Owning list of attachments. DE: Besitzende Liste von Anhaengen. }
  TLandrixEInvoicePdfAttachmentList = class(TObject)
  private
    FList: TObjectList;
    function GetCount: TLandrixEInvoiceListIndex;
    function GetItem(AIndex: TLandrixEInvoiceListIndex): TLandrixEInvoicePdfAttachment;
  public
    constructor Create;
    destructor Destroy; override;
    procedure Clear;
    function Add(AItem: TLandrixEInvoicePdfAttachment): TLandrixEInvoiceListIndex;
    property Count: TLandrixEInvoiceListIndex read GetCount;
    { nil outside 0..Count-1. DE: nil ausserhalb von 0..Count-1. }
    property Items[AIndex: TLandrixEInvoiceListIndex]: TLandrixEInvoicePdfAttachment read GetItem; default;
  end;

  { Facts about the PDF and the extraction.
    DE: Angaben zum PDF und zur Extraktion. }
  TLandrixEInvoicePdfExtractInfo = record
    { The xref chain was unusable and the object table was rebuilt by a
      scan; the result is no longer protected against replaced versions.
      DE: Die xref-Kette war unbrauchbar, die Objekttabelle wurde per Scan
      rekonstruiert; das Ergebnis ist nicht mehr gegen ersetzte Fassungen
      abgesichert. }
    UsedReconstruction: Boolean;
    { Number of xref sections (1 = no incremental update).
      DE: Anzahl der xref-Abschnitte (1 = kein inkrementelles Update). }
    XrefSections: Integer;
    { The file is encrypted, also when it was decrypted successfully.
      DE: Die Datei ist verschluesselt, auch wenn sie erfolgreich
      entschluesselt wurde. }
    Encrypted: Boolean;
    { Version from the header, e.g. 1.7. DE: Version aus dem Kopf, z. B.
      1.7. }
    PdfVersion: TLandrixEInvoiceString;
    { Why the extraction failed; '' on success.
      DE: Warum die Extraktion scheiterte; '' bei Erfolg. }
    Error: TLandrixEInvoiceString;
    { Embedded files left out because a stream filter failed or a limit was
      reached; Warning names the first case.
      DE: Eingebettete Dateien, die ausgelassen wurden, weil ein Stromfilter
      scheiterte oder eine Grenze erreicht war; Warning nennt den ersten
      Fall. }
    SkippedAttachments: Integer;
    Warning: TLandrixEInvoiceString;
  end;

  { Entry points. Damaged or hostile input is a normal result (False with
    Info.Error), not an exception.
    DE: Einstiege. Beschaedigte oder feindliche Eingaben sind ein normales
    Ergebnis (False mit Info.Error), keine Ausnahme. }
  TLandrixEInvoicePdfExtractor = class(TObject)
  public
    { Writes the embedded invoice (the bytes as embedded, normally UTF-8) at
      the current position of AXml. False with AInfo.Error if the PDF cannot
      be read or holds no invoice; AXml is then unchanged. The stream
      variant reads AStream from its position to the end.
      DE: Schreibt die eingebettete Rechnung (die Bytes wie eingebettet,
      normalerweise UTF-8) an die aktuelle Position von AXml. False mit
      AInfo.Error, wenn das PDF nicht lesbar ist oder keine Rechnung
      enthaelt; AXml bleibt dann unveraendert. Die Stream-Variante liest
      AStream ab seiner Position bis zum Ende. }
    class function ExtractInvoiceFromFile(const AFileName: string; AXml: TStream;
      out AAttachmentName: TLandrixEInvoiceString; out AInfo: TLandrixEInvoicePdfExtractInfo): Boolean;
    class function ExtractInvoiceFromStream(AStream, AXml: TStream;
      out AAttachmentName: TLandrixEInvoiceString; out AInfo: TLandrixEInvoicePdfExtractInfo): Boolean;
    { Adds all embedded files to AList in the order of the name tree, then
      those only listed in /AF of the catalog. True if the PDF could be
      read, also without attachments.
      DE: Haengt alle eingebetteten Dateien an AList an, in der Reihenfolge
      des Namensbaums, danach die nur in /AF des Katalogs genannten. True,
      wenn das PDF gelesen werden konnte, auch ohne Anhaenge. }
    class function ExtractAllFromFile(const AFileName: string; AList: TLandrixEInvoicePdfAttachmentList;
      out AInfo: TLandrixEInvoicePdfExtractInfo): Boolean;
    class function ExtractAllFromStream(AStream: TStream; AList: TLandrixEInvoicePdfAttachmentList;
      out AInfo: TLandrixEInvoicePdfExtractInfo): Boolean;
    { The invoice in AList: first an invoice with a specified file name
      (factur-x.xml, zugferd-invoice.xml, xrechnung.xml, order-x.xml,
      cii.xml), else the first invoice by root element; -1 if none. The file
      name alone is not enough.
      DE: Die Rechnung in AList: zuerst eine Rechnung mit spezifiziertem
      Dateinamen (factur-x.xml, zugferd-invoice.xml, xrechnung.xml,
      order-x.xml, cii.xml), sonst die erste Rechnung nach Wurzelelement;
      -1, wenn keine. Der Dateiname allein genuegt nicht. }
    class function FindInvoiceIndex(AList: TLandrixEInvoicePdfAttachmentList): TLandrixEInvoiceListIndex;
    { True if the data starts with %PDF-. Only the start counts: an XML
      invoice that contains %PDF- somewhere is no PDF. IsPdfStream keeps the
      position.
      DE: True, wenn die Daten mit %PDF- beginnen. Nur der Anfang zaehlt:
      Eine XML-Rechnung, die irgendwo %PDF- enthaelt, ist kein PDF.
      IsPdfStream laesst die Position unveraendert. }
    class function IsPdfFile(const AFileName: string): Boolean;
    class function IsPdfStream(AStream: TStream): Boolean;
  end;

const
  { Limit for one decoded stream (decompression bombs).
    DE: Grenze fuer einen dekodierten Stream (Dekompressionsbomben). }
  LandrixEInvoicePdfMaxStreamSize = 64 * 1024 * 1024;
  { Limit for all attachments of one document together.
    DE: Grenze fuer alle Anhaenge eines Dokuments zusammen. }
  LandrixEInvoicePdfMaxTotalSize = 192 * 1024 * 1024;
  { Maximum number of attachments. DE: Hoechstzahl der Anhaenge. }
  LandrixEInvoicePdfMaxAttachments = 512;
  { Maximum nesting depth in the object graph (cycles).
    DE: Hoechste Verschachtelungstiefe im Objektgraph (Zyklen). }
  LandrixEInvoicePdfMaxDepth = 64;
  { Largest PDF file that is read. DE: Groesste PDF-Datei, die gelesen
    wird. }
  LandrixEInvoicePdfMaxFileSize = 512 * 1024 * 1024;

implementation

uses
  SysUtils,
  LandrixEInvoicePdfObjects;

function ToText(const S: string): TLandrixEInvoiceString;
begin
  Result := TLandrixEInvoiceString(S);
end;

{ ASCII text (PDF names, root elements) as invoice string, byte by byte. }
function AnsiToText(const S: AnsiString): TLandrixEInvoiceString;
var
  I: Integer;
begin
  Result := '';
  SetLength(Result, Length(S));
  for I := 1 to Length(S) do
    Result[I] := WideChar(Ord(S[I]));
end;

{ ASCII lower case and trimmed. }
function AsciiLowerTrim(const S: TLandrixEInvoiceString): TLandrixEInvoiceString;
var
  First, Last, I: Integer;
begin
  First := 1;
  Last := Length(S);
  while (First <= Last) and (Ord(S[First]) <= 32) do
    Inc(First);
  while (Last >= First) and (Ord(S[Last]) <= 32) do
    Dec(Last);
  Result := Copy(S, First, Last - First + 1);
  for I := 1 to Length(Result) do
    if (Ord(Result[I]) >= Ord('A')) and (Ord(Result[I]) <= Ord('Z')) then
      Result[I] := WideChar(Ord(Result[I]) + 32);
end;

{ File names specified by ZUGFeRD, Factur-X, XRechnung and Order-X; case is
  ignored because zugferd-invoice.xml and ZUGFeRD-invoice.xml both occur.
  DE: Von ZUGFeRD, Factur-X, XRechnung und Order-X spezifizierte
  Dateinamen; Gross-/Kleinschreibung zaehlt nicht, weil
  zugferd-invoice.xml und ZUGFeRD-invoice.xml beide vorkommen. }
function IsSpecifiedInvoiceName(const AName: TLandrixEInvoiceString): Boolean;
var
  N: TLandrixEInvoiceString;
begin
  N := AsciiLowerTrim(AName);
  Result := (N = 'factur-x.xml') or (N = 'zugferd-invoice.xml') or (N = 'xrechnung.xml') or
    (N = 'order-x.xml') or (N = 'cii.xml');
end;

{ Root elements of a CII or UBL invoice (CrossIndustryDocument: ZUGFeRD 1).
  DE: Wurzelelemente einer CII- oder UBL-Rechnung (CrossIndustryDocument:
  ZUGFeRD 1). }
function IsInvoiceRootElement(const ARoot: TLandrixEInvoiceString): Boolean;
begin
  Result := (ARoot = 'CrossIndustryInvoice') or (ARoot = 'CrossIndustryDocument') or
    (ARoot = 'Invoice') or (ARoot = 'CreditNote');
end;

//==============================================================================
// TLandrixEInvoicePdfAttachment, TLandrixEInvoicePdfAttachmentList
//==============================================================================

constructor TLandrixEInvoicePdfAttachment.Create;
begin
  inherited Create;
  FData := TMemoryStream.Create;
end;

destructor TLandrixEInvoicePdfAttachment.Destroy;
begin
  FData.Free;
  inherited Destroy;
end;

function TLandrixEInvoicePdfAttachment.GetSize: Integer;
begin
  Result := Integer(FData.Size);
end;

constructor TLandrixEInvoicePdfAttachmentList.Create;
begin
  inherited Create;
  FList := TObjectList.Create(True);
end;

destructor TLandrixEInvoicePdfAttachmentList.Destroy;
begin
  Clear;
  FList.Free;
  inherited Destroy;
end;

procedure TLandrixEInvoicePdfAttachmentList.Clear;
begin
  FList.Clear;
end;

function TLandrixEInvoicePdfAttachmentList.Add(AItem: TLandrixEInvoicePdfAttachment): TLandrixEInvoiceListIndex;
begin
  Result := FList.Add(AItem);
end;

function TLandrixEInvoicePdfAttachmentList.GetCount: TLandrixEInvoiceListIndex;
begin
  Result := FList.Count;
end;

function TLandrixEInvoicePdfAttachmentList.GetItem(AIndex: TLandrixEInvoiceListIndex): TLandrixEInvoicePdfAttachment;
begin
  if (AIndex >= 0) and (AIndex < FList.Count) then
    Result := TLandrixEInvoicePdfAttachment(FList[AIndex])
  else
    Result := nil;
end;

//==============================================================================
// Collecting the attachments
//==============================================================================

{ Builds the attachment list from the file specifications of
  TLandrixEInvoicePdfCollector, in its order (name tree, then /AF): a file
  specification without stream or with the stream of an earlier one is left
  out; the limits on count and total size apply.
  DE: Baut die Anhangliste aus den Dateispezifikationen von
  TLandrixEInvoicePdfCollector, in dessen Reihenfolge (Namensbaum, dann
  /AF): eine Dateispezifikation ohne Stream oder mit dem Stream einer
  frueheren entfaellt; die Grenzen fuer Anzahl und Gesamtgroesse gelten. }
type
  TPdfAttachmentCollector = class(TObject)
  private
    FDoc: TLandrixEInvoicePdfDocument;
    FList: TLandrixEInvoicePdfAttachmentList;
    FTotalBytes: Int64;
    FSkipped: Integer;
    FWarning: string;
    procedure Skip(const AName: TLandrixEInvoiceString; const AReason: string);
    procedure AddFilespec(ASpec: TLandrixEInvoicePdfFileSpec);
  public
    constructor Create(ADoc: TLandrixEInvoicePdfDocument; AList: TLandrixEInvoicePdfAttachmentList);
    procedure Collect;
    property Skipped: Integer read FSkipped;
    property Warning: string read FWarning;
  end;

constructor TPdfAttachmentCollector.Create(ADoc: TLandrixEInvoicePdfDocument; AList: TLandrixEInvoicePdfAttachmentList);
begin
  inherited Create;
  FDoc := ADoc;
  FList := AList;
end;

procedure TPdfAttachmentCollector.Skip(const AName: TLandrixEInvoiceString; const AReason: string);
begin
  Inc(FSkipped);
  if FWarning = '' then
    FWarning := 'Embedded file "' + string(AName) + '" skipped: ' + AReason;
end;

procedure TPdfAttachmentCollector.AddFilespec(ASpec: TLandrixEInvoicePdfFileSpec);
var
  Att: TLandrixEInvoicePdfAttachment;
  Data: TLandrixEInvoicePdfBytes;
  Name: TLandrixEInvoiceString;
begin
  if (ASpec.Stream = nil) or (ASpec.DuplicateOf >= 0) then
    Exit;
  Name := ASpec.FileName;
  if FList.Count >= LandrixEInvoicePdfMaxAttachments then
  begin
    Skip(Name, 'more than ' + IntToStr(LandrixEInvoicePdfMaxAttachments) + ' attachments');
    Exit;
  end;
  if not FDoc.GetStreamData(ASpec.Stream, Data) then
  begin
    Skip(Name, FDoc.StreamError);
    Exit;
  end;
  if FTotalBytes + Length(Data) > LandrixEInvoicePdfMaxTotalSize then
  begin
    Skip(Name, 'all attachments together exceed ' + IntToStr(LandrixEInvoicePdfMaxTotalSize) + ' bytes');
    Exit;
  end;
  FTotalBytes := FTotalBytes + Integer(Length(Data));

  Att := TLandrixEInvoicePdfAttachment.Create;
  try
    Att.FileName := Name;
    Att.Relationship := AnsiToText(ASpec.Relationship);
    Att.Description := ASpec.Description;
    Att.MimeType := AnsiToText(ASpec.Subtype);
    if Length(Data) > 0 then
      Att.Data.WriteBuffer(Data[0], Length(Data));
    Att.Data.Position := 0;
    Att.RootElement := LandrixEInvoicePdfDetectXmlRoot(Data);
    if IsInvoiceRootElement(Att.RootElement) then
      Att.Kind := epa_Invoice
    else if Att.RootElement <> '' then
      Att.Kind := epa_OtherXml
    else
      Att.Kind := epa_Other;
    FList.Add(Att);
    Att := nil;
  finally
    Att.Free;
  end;
end;

procedure TPdfAttachmentCollector.Collect;
var
  Specs: TLandrixEInvoicePdfCollector;
  I: Integer;
begin
  Specs := TLandrixEInvoicePdfCollector.Create(FDoc);
  try
    Specs.Collect;
    for I := 0 to Specs.Count - 1 do
      AddFilespec(Specs[I]);
  finally
    Specs.Free;
  end;
end;

//==============================================================================
// TLandrixEInvoicePdfExtractor
//==============================================================================

procedure ClearInfo(out AInfo: TLandrixEInvoicePdfExtractInfo);
begin
  AInfo.UsedReconstruction := False;
  AInfo.XrefSections := 0;
  AInfo.Encrypted := False;
  AInfo.PdfVersion := '';
  AInfo.Error := '';
  AInfo.SkippedAttachments := 0;
  AInfo.Warning := '';
end;

function HasPdfSignature(AStream: TStream): Boolean;
var
  Hdr: array[0..4] of Byte;
  I: Integer;
begin
  for I := 0 to 4 do
    Hdr[I] := 0;
  Result := (Integer(AStream.Read(Hdr, 5)) = 5) and (Hdr[0] = Ord('%')) and (Hdr[1] = Ord('P')) and
    (Hdr[2] = Ord('D')) and (Hdr[3] = Ord('F')) and (Hdr[4] = Ord('-'));
end;

{ Opens AFileName for reading; nil with AInfo.Error if that fails. }
function OpenPdfFile(const AFileName: string; var AInfo: TLandrixEInvoicePdfExtractInfo): TFileStream;
begin
  Result := nil;
  if not FileExists(AFileName) then
  begin
    AInfo.Error := ToText('File not found: ' + AFileName);
    Exit;
  end;
  try
    Result := TFileStream.Create(AFileName, fmOpenRead or fmShareDenyWrite);
  except
    on E: Exception do
      AInfo.Error := ToText('File not readable: ' + E.Message);
  end;
end;

class function TLandrixEInvoicePdfExtractor.IsPdfFile(const AFileName: string): Boolean;
var
  Stream: TFileStream;
begin
  Result := False;
  if not FileExists(AFileName) then
    Exit;
  try
    Stream := TFileStream.Create(AFileName, fmOpenRead or fmShareDenyWrite);
    try
      Result := HasPdfSignature(Stream);
    finally
      Stream.Free;
    end;
  except
    on Exception do
      Result := False;
  end;
end;

class function TLandrixEInvoicePdfExtractor.IsPdfStream(AStream: TStream): Boolean;
var
  Save: Int64;
begin
  Result := False;
  if AStream = nil then
    Exit;
  Save := AStream.Position;
  try
    Result := HasPdfSignature(AStream);
  finally
    AStream.Position := Save;
  end;
end;

class function TLandrixEInvoicePdfExtractor.ExtractAllFromStream(AStream: TStream;
  AList: TLandrixEInvoicePdfAttachmentList; out AInfo: TLandrixEInvoicePdfExtractInfo): Boolean;
var
  Doc: TLandrixEInvoicePdfDocument;
  Collector: TPdfAttachmentCollector;
  Err: string;
begin
  Result := False;
  ClearInfo(AInfo);
  if AList = nil then
  begin
    AInfo.Error := 'No attachment list given';
    Exit;
  end;
  if AStream = nil then
  begin
    AInfo.Error := 'No stream given';
    Exit;
  end;
  Doc := TLandrixEInvoicePdfDocument.Create;
  try
    try
      if not Doc.Load(AStream, Err) then
      begin
        AInfo.Error := ToText(Err);
        Exit;
      end;
    except
      on E: Exception do
      begin
        AInfo.Error := ToText('PDF not readable: ' + E.Message);
        Exit;
      end;
    end;
    AInfo.UsedReconstruction := Doc.Reconstructed;
    AInfo.XrefSections := Doc.XrefSections;
    if Doc.HeaderPos + 8 <= Length(Doc.Buf) then
      AInfo.PdfVersion := AnsiToText(LandrixEInvoicePdfBytesToAnsi(Doc.Buf, Doc.HeaderPos + 5, 3));
    AInfo.Encrypted := Doc.Encrypted;
    if Doc.CryptError <> '' then
    begin
      AInfo.Error := ToText(Doc.CryptError);
      Exit;
    end;
    Collector := TPdfAttachmentCollector.Create(Doc, AList);
    try
      try
        Collector.Collect;
      except
        on E: Exception do
        begin
          AInfo.Error := ToText('Attachments not readable: ' + E.Message);
          Exit;
        end;
      end;
      AInfo.SkippedAttachments := Collector.Skipped;
      AInfo.Warning := ToText(Collector.Warning);
    finally
      Collector.Free;
    end;
    Result := True;
  finally
    Doc.Free;
  end;
end;

class function TLandrixEInvoicePdfExtractor.ExtractAllFromFile(const AFileName: string;
  AList: TLandrixEInvoicePdfAttachmentList; out AInfo: TLandrixEInvoicePdfExtractInfo): Boolean;
var
  Stream: TFileStream;
begin
  Result := False;
  ClearInfo(AInfo);
  Stream := OpenPdfFile(AFileName, AInfo);
  if Stream = nil then
    Exit;
  try
    Result := ExtractAllFromStream(Stream, AList, AInfo);
  finally
    Stream.Free;
  end;
end;

class function TLandrixEInvoicePdfExtractor.FindInvoiceIndex(
  AList: TLandrixEInvoicePdfAttachmentList): TLandrixEInvoiceListIndex;
var
  I, Fallback: TLandrixEInvoiceListIndex;
begin
  Result := -1;
  Fallback := -1;
  if AList = nil then
    Exit;
  for I := 0 to AList.Count - 1 do
    if AList[I].Kind = epa_Invoice then
    begin
      if IsSpecifiedInvoiceName(AList[I].FileName) then
      begin
        Result := I;
        Exit;
      end;
      if Fallback < 0 then
        Fallback := I;
    end;
  Result := Fallback;
end;

class function TLandrixEInvoicePdfExtractor.ExtractInvoiceFromStream(AStream, AXml: TStream;
  out AAttachmentName: TLandrixEInvoiceString; out AInfo: TLandrixEInvoicePdfExtractInfo): Boolean;
var
  List: TLandrixEInvoicePdfAttachmentList;
  Index: TLandrixEInvoiceListIndex;
begin
  Result := False;
  AAttachmentName := '';
  ClearInfo(AInfo);
  if AXml = nil then
  begin
    AInfo.Error := 'No target stream given';
    Exit;
  end;
  List := TLandrixEInvoicePdfAttachmentList.Create;
  try
    if not ExtractAllFromStream(AStream, List, AInfo) then
      Exit;
    Index := FindInvoiceIndex(List);
    if Index < 0 then
    begin
      if List.Count = 0 then
        AInfo.Error := 'The PDF has no embedded files'
      else
        AInfo.Error := ToText('No embedded invoice found (' + IntToStr(List.Count) + ' embedded file(s))');
      Exit;
    end;
    AXml.CopyFrom(List[Index].Data, 0);
    AAttachmentName := List[Index].FileName;
    Result := True;
  finally
    List.Free;
  end;
end;

class function TLandrixEInvoicePdfExtractor.ExtractInvoiceFromFile(const AFileName: string; AXml: TStream;
  out AAttachmentName: TLandrixEInvoiceString; out AInfo: TLandrixEInvoicePdfExtractInfo): Boolean;
var
  Stream: TFileStream;
begin
  Result := False;
  AAttachmentName := '';
  ClearInfo(AInfo);
  Stream := OpenPdfFile(AFileName, AInfo);
  if Stream = nil then
    Exit;
  try
    Result := ExtractInvoiceFromStream(Stream, AXml, AAttachmentName, AInfo);
  finally
    Stream.Free;
  end;
end;

end.
