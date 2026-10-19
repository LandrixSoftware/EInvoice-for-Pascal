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
  reported, not guessed. Attachments on page level are not searched.

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
  Seitenebene werden nicht gesucht. }

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
  LandrixXmlBase;

type
  TPdfBytes = array of Byte;

  { Growable byte buffer. }
  TPdfByteBuilder = record
    Data: TPdfBytes;
    Len: Integer;
  end;

  EPdfInflate = class(Exception);

function ToText(const S: string): TLandrixEInvoiceString;
begin
  Result := TLandrixEInvoiceString(S);
end;

{ ASCII bytes as native string, without code page conversion. }
function AsciiToNative(const S: AnsiString): string;
var
  I: Integer;
begin
  Result := '';
  SetLength(Result, Length(S));
  for I := 1 to Length(S) do
    Result[I] := Char(Ord(S[I]));
end;

function MinInt(A, B: Integer): Integer;
begin
  if A < B then
    Result := A
  else
    Result := B;
end;

{ Integer value of a token that Val reads as a number; False for other
  tokens and for values outside Integer. }
function TokenToInt(const ATok: AnsiString; out AValue: Integer): Boolean;
var
  D: Double;
  Code: Integer;
begin
  AValue := 0;
  Result := False;
  if ATok = '' then
    Exit;
  Val(AsciiToNative(ATok), D, Code);
  if Code <> 0 then
    Exit;
  if (D > 2147483647.0) or (D < -2147483647.0) then
    Exit;
  AValue := Integer(Trunc(D));
  Result := True;
end;

{ Like TokenToInt, for offsets. }
function TokenToInt64(const ATok: AnsiString; out AValue: Int64): Boolean;
var
  D: Double;
  Code: Integer;
begin
  AValue := 0;
  Result := False;
  if ATok = '' then
    Exit;
  Val(AsciiToNative(ATok), D, Code);
  if Code <> 0 then
    Exit;
  if (D > 1.0e18) or (D < -1.0e18) then
    Exit;
  AValue := Trunc(D);
  Result := True;
end;

procedure BuilderGrow(var B: TPdfByteBuilder; ANeed: Integer);
var
  NewCap: Integer;
begin
  if B.Len + ANeed <= Length(B.Data) then
    Exit;
  NewCap := Integer(Length(B.Data)) * 2;
  if NewCap < 4096 then
    NewCap := 4096;
  if NewCap < B.Len + ANeed then
    NewCap := B.Len + ANeed;
  SetLength(B.Data, NewCap);
end;

procedure BuilderAdd(var B: TPdfByteBuilder; const ASource: TPdfBytes; AStart, ACount: Integer);
begin
  if ACount <= 0 then
    Exit;
  BuilderGrow(B, ACount);
  Move(ASource[AStart], B.Data[B.Len], ACount);
  Inc(B.Len, ACount);
end;

procedure BuilderAddByte(var B: TPdfByteBuilder; AValue: Byte);
begin
  BuilderGrow(B, 1);
  B.Data[B.Len] := AValue;
  Inc(B.Len);
end;

function BuilderDone(var B: TPdfByteBuilder): TPdfBytes;
begin
  SetLength(B.Data, B.Len);
  Result := B.Data;
  B.Data := nil;
  B.Len := 0;
end;

//==============================================================================
// Byte helpers
//==============================================================================

function IsPdfWhite(B: Byte): Boolean;
begin
  Result := (B = 0) or (B = 9) or (B = 10) or (B = 12) or (B = 13) or (B = 32);
end;

function IsPdfDelim(B: Byte): Boolean;
begin
  case B of
    40, 41, 60, 62, 91, 93, 123, 125, 47, 37: Result := True; // ( ) < > [ ] { } / %
  else
    Result := False;
  end;
end;

function IsPdfRegular(B: Byte): Boolean;
begin
  Result := not IsPdfWhite(B) and not IsPdfDelim(B);
end;

{ True if ABuf holds AText at APos. }
function MatchAt(const ABuf: TPdfBytes; APos: Integer; const AText: AnsiString): Boolean;
var
  I: Integer;
begin
  Result := False;
  if APos < 0 then
    Exit;
  if APos + Length(AText) > Length(ABuf) then
    Exit;
  for I := 1 to Length(AText) do
    if ABuf[APos + I - 1] <> Byte(AText[I]) then
      Exit;
  Result := True;
end;

{ First position of AText at or after AFrom; -1 if none. }
function IndexOfBytes(const ABuf: TPdfBytes; const AText: AnsiString; AFrom: Integer): Integer;
var
  I, Last: Integer;
  First: Byte;
begin
  Result := -1;
  if AText = '' then
    Exit;
  Last := Integer(Length(ABuf)) - Length(AText);
  if AFrom < 0 then
    AFrom := 0;
  First := Byte(AText[1]);
  for I := AFrom to Last do
    if (ABuf[I] = First) and MatchAt(ABuf, I, AText) then
    begin
      Result := I;
      Exit;
    end;
end;

{ Last position of AText at or before AFrom; -1 if none. }
function LastIndexOfBytes(const ABuf: TPdfBytes; const AText: AnsiString; AFrom: Integer): Integer;
var
  I: Integer;
begin
  Result := -1;
  if AText = '' then
    Exit;
  if AFrom > Length(ABuf) - Length(AText) then
    AFrom := Integer(Length(ABuf)) - Length(AText);
  for I := AFrom downto 0 do
    if MatchAt(ABuf, I, AText) then
    begin
      Result := I;
      Exit;
    end;
end;

function BytesToAnsi(const ABuf: TPdfBytes; APos, ALen: Integer): AnsiString;
var
  I: Integer;
begin
  Result := '';
  if APos < 0 then
    APos := 0;
  if APos + ALen > Length(ABuf) then
    ALen := Integer(Length(ABuf)) - APos;
  if ALen <= 0 then
    Exit;
  SetLength(Result, ALen);
  for I := 0 to ALen - 1 do
    Result[I + 1] := AnsiChar(ABuf[APos + I]);
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

function HexVal(B: Byte): Integer;
begin
  case B of
    48..57: Result := B - 48;
    65..70: Result := B - 55;
    97..102: Result := B - 87;
  else
    Result := -1;
  end;
end;

//==============================================================================
// Inflate (RFC 1950 and 1951)
//==============================================================================

type
  TPdfCodeLengths = array[0..319] of Integer;

  TPdfHuffman = record
    Count: array[0..15] of Integer;
    Symbol: array[0..319] of Integer;
  end;

  TPdfInflater = class(TObject)
  private
    FSrc: TPdfBytes;
    FPos: Integer;
    FBitBuf: Cardinal;
    FBitCnt: Integer;
    FOut: TPdfBytes;
    FOutLen: Integer;
    FLimit: Integer;
    FTooBig: Boolean;
    function Bits(N: Integer): Integer;
    procedure Grow(ANeed: Integer);
    function Decode(const H: TPdfHuffman): Integer;
    procedure Stored;
    procedure Codes(const ALenCode, ADistCode: TPdfHuffman);
    procedure FixedBlock;
    procedure DynamicBlock;
  public
    { Decodes ASrc from AStart. Returns the bytes decoded until the end of
      the last block or until the first error; AComplete tells which.
      ATooBig: the output would exceed ALimit (nothing is returned then). }
    function Run(const ASrc: TPdfBytes; AStart: Integer; ARaw: Boolean; ALimit: Integer;
      out AOutput: TPdfBytes; out AComplete, ATooBig: Boolean): Boolean;
  end;

const
  PdfLenBase: array[0..28] of Integer = (3, 4, 5, 6, 7, 8, 9, 10, 11, 13, 15, 17, 19, 23, 27, 31,
    35, 43, 51, 59, 67, 83, 99, 115, 131, 163, 195, 227, 258);
  PdfLenExtra: array[0..28] of Integer = (0, 0, 0, 0, 0, 0, 0, 0, 1, 1, 1, 1, 2, 2, 2, 2,
    3, 3, 3, 3, 4, 4, 4, 4, 5, 5, 5, 5, 0);
  PdfDistBase: array[0..29] of Integer = (1, 2, 3, 4, 5, 7, 9, 13, 17, 25, 33, 49, 65, 97, 129, 193,
    257, 385, 513, 769, 1025, 1537, 2049, 3073, 4097, 6145, 8193, 12289, 16385, 24577);
  PdfDistExtra: array[0..29] of Integer = (0, 0, 0, 0, 1, 1, 2, 2, 3, 3, 4, 4, 5, 5, 6, 6,
    7, 7, 8, 8, 9, 9, 10, 10, 11, 11, 12, 12, 13, 13);
  PdfCodeLengthOrder: array[0..18] of Integer = (16, 17, 18, 0, 8, 7, 9, 6, 10, 5, 11, 4, 12, 3, 13,
    2, 14, 1, 15);

{ Canonical Huffman code from code lengths ALengths[AFirst..AFirst+ACount-1].
  Returns 0 for a complete code, > 0 for an incomplete one, < 0 for an
  over-subscribed one. }
function BuildHuffman(out H: TPdfHuffman; const ALengths: TPdfCodeLengths; AFirst, ACount: Integer): Integer;
var
  Len, Sym, Left: Integer;
  Offs: array[0..15] of Integer;
begin
  for Len := 0 to 15 do
    H.Count[Len] := 0;
  for Sym := 0 to ACount - 1 do
    Inc(H.Count[ALengths[AFirst + Sym]]);
  if H.Count[0] = ACount then
  begin
    Result := 0;
    Exit;
  end;
  Left := 1;
  for Len := 1 to 15 do
  begin
    Left := Left shl 1;
    Dec(Left, H.Count[Len]);
    if Left < 0 then
    begin
      Result := Left;
      Exit;
    end;
  end;
  Offs[0] := 0;
  Offs[1] := 0;
  for Len := 1 to 14 do
    Offs[Len + 1] := Offs[Len] + H.Count[Len];
  for Sym := 0 to ACount - 1 do
    if ALengths[AFirst + Sym] <> 0 then
    begin
      H.Symbol[Offs[ALengths[AFirst + Sym]]] := Sym;
      Inc(Offs[ALengths[AFirst + Sym]]);
    end;
  Result := Left;
end;

function TPdfInflater.Bits(N: Integer): Integer;
var
  V: Cardinal;
begin
  V := FBitBuf;
  while FBitCnt < N do
  begin
    if FPos >= Length(FSrc) then
      raise EPdfInflate.Create('unexpected end of data');
    V := V or (Cardinal(FSrc[FPos]) shl FBitCnt);
    Inc(FPos);
    Inc(FBitCnt, 8);
  end;
  FBitBuf := V shr N;
  Dec(FBitCnt, N);
  Result := Integer(V and ((Cardinal(1) shl N) - 1));
end;

procedure TPdfInflater.Grow(ANeed: Integer);
var
  NewCap: Integer;
begin
  if FOutLen + ANeed <= Length(FOut) then
    Exit;
  if FOutLen + ANeed > FLimit then
  begin
    FTooBig := True;
    raise EPdfInflate.Create('size limit exceeded');
  end;
  NewCap := Integer(Length(FOut)) * 2;
  if NewCap < 65536 then
    NewCap := 65536;
  if NewCap < FOutLen + ANeed then
    NewCap := FOutLen + ANeed;
  if NewCap > FLimit then
    NewCap := FLimit;
  SetLength(FOut, NewCap);
end;

function TPdfInflater.Decode(const H: TPdfHuffman): Integer;
var
  Code, First, Count, Index, Len: Integer;
begin
  Code := 0;
  First := 0;
  Index := 0;
  for Len := 1 to 15 do
  begin
    Code := Code or Bits(1);
    Count := H.Count[Len];
    if Code - Count < First then
    begin
      Result := H.Symbol[Index + (Code - First)];
      Exit;
    end;
    Inc(Index, Count);
    Inc(First, Count);
    First := First shl 1;
    Code := Code shl 1;
  end;
  raise EPdfInflate.Create('invalid Huffman code');
end;

procedure TPdfInflater.Stored;
var
  Len, NLen, Avail: Integer;
begin
  FBitBuf := 0;
  FBitCnt := 0;
  if FPos + 4 > Length(FSrc) then
    raise EPdfInflate.Create('unexpected end of data');
  Len := FSrc[FPos] or (FSrc[FPos + 1] shl 8);
  NLen := FSrc[FPos + 2] or (FSrc[FPos + 3] shl 8);
  Inc(FPos, 4);
  if Len <> (not NLen) and $FFFF then
    raise EPdfInflate.Create('invalid stored block length');
  Avail := Integer(Length(FSrc)) - FPos;
  if Avail > Len then
    Avail := Len;
  Grow(Avail);
  if Avail > 0 then
    Move(FSrc[FPos], FOut[FOutLen], Avail);
  Inc(FOutLen, Avail);
  Inc(FPos, Avail);
  if Avail < Len then
    raise EPdfInflate.Create('unexpected end of data');
end;

procedure TPdfInflater.Codes(const ALenCode, ADistCode: TPdfHuffman);
var
  Sym, DistSym, Len, Dist, I: Integer;
begin
  repeat
    Sym := Decode(ALenCode);
    if Sym < 256 then
    begin
      Grow(1);
      FOut[FOutLen] := Byte(Sym);
      Inc(FOutLen);
    end
    else if Sym > 256 then
    begin
      Dec(Sym, 257);
      if Sym >= 29 then
        raise EPdfInflate.Create('invalid length symbol');
      Len := PdfLenBase[Sym] + Bits(PdfLenExtra[Sym]);
      DistSym := Decode(ADistCode);
      if DistSym >= 30 then
        raise EPdfInflate.Create('invalid distance symbol');
      Dist := PdfDistBase[DistSym] + Bits(PdfDistExtra[DistSym]);
      if Dist > FOutLen then
        raise EPdfInflate.Create('distance too far back');
      Grow(Len);
      for I := 1 to Len do
      begin
        FOut[FOutLen] := FOut[FOutLen - Dist];
        Inc(FOutLen);
      end;
      Sym := 0;
    end;
  until Sym = 256;
end;

procedure TPdfInflater.FixedBlock;
var
  Lengths: TPdfCodeLengths;
  LenCode, DistCode: TPdfHuffman;
  I: Integer;
begin
  for I := 0 to 143 do
    Lengths[I] := 8;
  for I := 144 to 255 do
    Lengths[I] := 9;
  for I := 256 to 279 do
    Lengths[I] := 7;
  for I := 280 to 287 do
    Lengths[I] := 8;
  BuildHuffman(LenCode, Lengths, 0, 288);
  for I := 0 to 29 do
    Lengths[I] := 5;
  BuildHuffman(DistCode, Lengths, 0, 30);
  Codes(LenCode, DistCode);
end;

procedure TPdfInflater.DynamicBlock;
var
  Lengths: TPdfCodeLengths;
  LenCode, DistCode: TPdfHuffman;
  NLen, NDist, NCode, I, Sym, Len, Err: Integer;
begin
  NLen := Bits(5) + 257;
  NDist := Bits(5) + 1;
  NCode := Bits(4) + 4;
  if (NLen > 286) or (NDist > 30) then
    raise EPdfInflate.Create('invalid code counts');
  for I := 0 to 18 do
    Lengths[I] := 0;
  for I := 0 to NCode - 1 do
    Lengths[PdfCodeLengthOrder[I]] := Bits(3);
  if BuildHuffman(LenCode, Lengths, 0, 19) <> 0 then
    raise EPdfInflate.Create('invalid code length code');
  I := 0;
  while I < NLen + NDist do
  begin
    Sym := Decode(LenCode);
    if Sym < 16 then
    begin
      Lengths[I] := Sym;
      Inc(I);
    end
    else
    begin
      Len := 0;
      if Sym = 16 then
      begin
        if I = 0 then
          raise EPdfInflate.Create('repeat without length');
        Len := Lengths[I - 1];
        Sym := 3 + Bits(2);
      end
      else if Sym = 17 then
        Sym := 3 + Bits(3)
      else
        Sym := 11 + Bits(7);
      if I + Sym > NLen + NDist then
        raise EPdfInflate.Create('too many code lengths');
      while Sym > 0 do
      begin
        Lengths[I] := Len;
        Inc(I);
        Dec(Sym);
      end;
    end;
  end;
  if Lengths[256] = 0 then
    raise EPdfInflate.Create('no end-of-block code');
  { An incomplete code is allowed only for a single code of length 1. }
  Err := BuildHuffman(LenCode, Lengths, 0, NLen);
  if (Err < 0) or ((Err > 0) and (NLen <> LenCode.Count[0] + LenCode.Count[1])) then
    raise EPdfInflate.Create('invalid literal/length code');
  Err := BuildHuffman(DistCode, Lengths, NLen, NDist);
  if (Err < 0) or ((Err > 0) and (NDist <> DistCode.Count[0] + DistCode.Count[1])) then
    raise EPdfInflate.Create('invalid distance code');
  Codes(LenCode, DistCode);
end;

function TPdfInflater.Run(const ASrc: TPdfBytes; AStart: Integer; ARaw: Boolean; ALimit: Integer;
  out AOutput: TPdfBytes; out AComplete, ATooBig: Boolean): Boolean;
var
  Cmf, Flg, Last: Integer;
begin
  FSrc := ASrc;
  FPos := AStart;
  FBitBuf := 0;
  FBitCnt := 0;
  FOut := nil;
  FOutLen := 0;
  FLimit := ALimit;
  FTooBig := False;
  AComplete := False;
  try
    if not ARaw then
    begin
      if FPos + 2 > Length(FSrc) then
        raise EPdfInflate.Create('no zlib header');
      Cmf := FSrc[FPos];
      Flg := FSrc[FPos + 1];
      if ((Cmf and $0F) <> 8) or ((Cmf shr 4) > 7) or (((Cmf shl 8) + Flg) mod 31 <> 0) or
        ((Flg and $20) <> 0) then
        raise EPdfInflate.Create('invalid zlib header');
      Inc(FPos, 2);
    end;
    repeat
      Last := Bits(1);
      case Bits(2) of
        0: Stored;
        1: FixedBlock;
        2: DynamicBlock;
      else
        raise EPdfInflate.Create('invalid block type');
      end;
    until Last = 1;
    AComplete := True;
  except
    on EPdfInflate do
      ;
  end;
  ATooBig := FTooBig;
  if FTooBig then
    FOutLen := 0;
  SetLength(FOut, FOutLen);
  AOutput := FOut;
  FOut := nil;
  FSrc := nil;
  Result := not FTooBig and (AComplete or (FOutLen > 0));
end;

//==============================================================================
// Stream filters
//==============================================================================

{ FlateDecode. Tolerances (decision 1.7): output that ends early because
  the data is truncated or damaged is kept as decoded so far, as long as it
  is not empty; streams without zlib header (raw deflate) and with leading
  white space are accepted. An output above the size limit fails, it is
  never cut.
  DE: FlateDecode. Toleranzen (Entscheidung 1.7): Eine Ausgabe, die wegen
  abgeschnittener oder beschaedigter Daten vorzeitig endet, wird bis dahin
  uebernommen, sofern sie nicht leer ist; Stroeme ohne zlib-Kopf (rohes
  Deflate) und mit fuehrendem Leerraum werden angenommen. Eine Ausgabe ueber
  der Groessengrenze scheitert, sie wird nie abgeschnitten. }
function FilterFlate(const ASrc: TPdfBytes; out ADst: TPdfBytes; out ATooBig: Boolean): Boolean;
var
  Inflater: TPdfInflater;
  Complete: Boolean;
  Start: Integer;
begin
  ADst := nil;
  ATooBig := False;
  Inflater := TPdfInflater.Create;
  try
    Start := 0;
    while True do
    begin
      Result := Inflater.Run(ASrc, Start, False, LandrixEInvoicePdfMaxStreamSize, ADst, Complete, ATooBig);
      if Result or ATooBig then
        Exit;
      Result := Inflater.Run(ASrc, Start, True, LandrixEInvoicePdfMaxStreamSize, ADst, Complete, ATooBig);
      if Result or ATooBig then
        Exit;
      if Start > 0 then
        Exit;
      while (Start < Length(ASrc)) and IsPdfWhite(ASrc[Start]) do
        Inc(Start);
      if (Start = 0) or (Start >= Length(ASrc)) then
        Exit;
    end;
  finally
    Inflater.Free;
  end;
end;

function FilterASCIIHex(const ASrc: TPdfBytes; out ADst: TPdfBytes): Boolean;
var
  I, N, Hi, V: Integer;
begin
  ADst := nil;
  SetLength(ADst, (Length(ASrc) div 2) + 1);
  N := 0;
  Hi := -1;
  for I := 0 to Integer(Length(ASrc)) - 1 do
  begin
    if ASrc[I] = Ord('>') then
      Break;
    V := HexVal(ASrc[I]);
    if V < 0 then
      Continue;
    if Hi < 0 then
      Hi := V
    else
    begin
      ADst[N] := Byte((Hi shl 4) or V);
      Inc(N);
      Hi := -1;
    end;
  end;
  if Hi >= 0 then
  begin
    ADst[N] := Byte(Hi shl 4);
    Inc(N);
  end;
  SetLength(ADst, N);
  Result := True;
end;

procedure PutTuple(var B: TPdfByteBuilder; ATuple: Int64; ACount: Integer);
var
  I: Integer;
begin
  for I := 0 to ACount - 1 do
    BuilderAddByte(B, Byte((ATuple shr (24 - 8 * I)) and $FF));
end;

function FilterASCII85(const ASrc: TPdfBytes; out ADst: TPdfBytes): Boolean;
var
  I, Cnt, K: Integer;
  Tuple: Int64;
  B: Byte;
  Output: TPdfByteBuilder;
begin
  Result := False;
  ADst := nil;
  Output.Data := nil;
  Output.Len := 0;
  I := 0;
  if (Length(ASrc) >= 2) and (ASrc[0] = Ord('<')) and (ASrc[1] = Ord('~')) then
    I := 2;
  Tuple := 0;
  Cnt := 0;
  while I < Length(ASrc) do
  begin
    B := ASrc[I];
    Inc(I);
    if IsPdfWhite(B) then
      Continue;
    if B = Ord('~') then
      Break;
    if B = Ord('z') then
    begin
      if Cnt <> 0 then
        Exit;
      PutTuple(Output, 0, 4);
      Continue;
    end;
    if (B < Ord('!')) or (B > Ord('u')) then
      Continue;
    Tuple := Tuple * 85 + (Int64(B) - Ord('!'));
    Inc(Cnt);
    if Cnt = 5 then
    begin
      { A group above 2^32 - 1 is invalid. }
      if Tuple > $FFFFFFFF then
        Exit;
      PutTuple(Output, Tuple, 4);
      Tuple := 0;
      Cnt := 0;
    end;
    if Output.Len > LandrixEInvoicePdfMaxStreamSize then
      Exit;
  end;
  if Cnt > 1 then
  begin
    for K := Cnt to 4 do
      Tuple := Tuple * 85 + 84;
    if Tuple > $FFFFFFFF then
      Exit;
    PutTuple(Output, Tuple, Cnt - 1);
  end;
  ADst := BuilderDone(Output);
  Result := True;
end;

function FilterRunLength(const ASrc: TPdfBytes; out ADst: TPdfBytes): Boolean;
var
  I, J, Len: Integer;
  B: Byte;
  Output: TPdfByteBuilder;
begin
  Result := False;
  ADst := nil;
  Output.Data := nil;
  Output.Len := 0;
  I := 0;
  while I < Length(ASrc) do
  begin
    Len := ASrc[I];
    Inc(I);
    if Len = 128 then
      Break;
    if Len < 128 then
    begin
      if I + Len + 1 > Length(ASrc) then
        Len := Integer(Length(ASrc)) - I - 1;
      if Len < 0 then
        Break;
      BuilderAdd(Output, ASrc, I, Len + 1);
      Inc(I, Len + 1);
    end
    else
    begin
      if I >= Length(ASrc) then
        Break;
      B := ASrc[I];
      Inc(I);
      for J := 0 to 256 - Len do
        BuilderAddByte(Output, B);
    end;
    if Output.Len > LandrixEInvoicePdfMaxStreamSize then
      Exit;
  end;
  ADst := BuilderDone(Output);
  Result := True;
end;

type
  TPdfLzwEntry = record
    Prev: Integer;
    Ch: Byte;
    Len: Integer;
  end;

  TPdfLzwDict = array[0..4095] of TPdfLzwEntry;

{ Byte sequence of ACode, built backwards. }
function LzwExpand(const ADict: TPdfLzwDict; ANext, ACode: Integer; out ASeq: TPdfBytes): Boolean;
var
  N, P: Integer;
begin
  Result := False;
  ASeq := nil;
  if (ACode < 0) or (ACode >= ANext) or (ADict[ACode].Len <= 0) then
    Exit;
  N := ADict[ACode].Len;
  SetLength(ASeq, N);
  P := ACode;
  while (N > 0) and (P >= 0) do
  begin
    Dec(N);
    ASeq[N] := ADict[P].Ch;
    P := ADict[P].Prev;
  end;
  Result := True;
end;

{ LZW as in the PDF specification; EarlyChange 1 is the normal case. }
function FilterLZW(const ASrc: TPdfBytes; AEarlyChange: Integer; out ADst: TPdfBytes): Boolean;
var
  Dict: TPdfLzwDict;
  Next, CodeLen, PrevCode, Code, K, D, SrcPos, BitCnt: Integer;
  BitBuf: Cardinal;
  Seq: TPdfBytes;
  Output: TPdfByteBuilder;
begin
  Result := False;
  ADst := nil;
  Output.Data := nil;
  Output.Len := 0;
  for D := 0 to 255 do
  begin
    Dict[D].Prev := -1;
    Dict[D].Ch := Byte(D);
    Dict[D].Len := 1;
  end;
  Next := 258;
  CodeLen := 9;
  PrevCode := -1;
  BitBuf := 0;
  BitCnt := 0;
  SrcPos := 0;
  while True do
  begin
    while (BitCnt < CodeLen) and (SrcPos < Length(ASrc)) do
    begin
      BitBuf := ((BitBuf and $00FFFFFF) shl 8) or ASrc[SrcPos];
      Inc(SrcPos);
      Inc(BitCnt, 8);
    end;
    if BitCnt < CodeLen then
      Break;
    Code := Integer((BitBuf shr (BitCnt - CodeLen)) and ((Cardinal(1) shl CodeLen) - 1));
    Dec(BitCnt, CodeLen);
    if Code = 256 then
    begin
      Next := 258;
      CodeLen := 9;
      PrevCode := -1;
      Continue;
    end;
    if Code = 257 then
      Break;
    if PrevCode < 0 then
    begin
      if not LzwExpand(Dict, Next, Code, Seq) then
        Break;
      BuilderAdd(Output, Seq, 0, Integer(Length(Seq)));
      PrevCode := Code;
    end
    else
    begin
      if Code < Next then
      begin
        if not LzwExpand(Dict, Next, Code, Seq) then
          Break;
      end
      else
      begin
        { KwKwK case }
        if not LzwExpand(Dict, Next, PrevCode, Seq) then
          Break;
        K := Integer(Length(Seq));
        SetLength(Seq, K + 1);
        Seq[K] := Seq[0];
      end;
      if Next < 4096 then
      begin
        Dict[Next].Prev := PrevCode;
        Dict[Next].Ch := Seq[0];
        Dict[Next].Len := Dict[PrevCode].Len + 1;
        Inc(Next);
      end;
      BuilderAdd(Output, Seq, 0, Integer(Length(Seq)));
      PrevCode := Code;
    end;
    if Output.Len > LandrixEInvoicePdfMaxStreamSize then
      Exit;
    if (Next + AEarlyChange >= 512) and (CodeLen = 9) then
      CodeLen := 10
    else if (Next + AEarlyChange >= 1024) and (CodeLen = 10) then
      CodeLen := 11
    else if (Next + AEarlyChange >= 2048) and (CodeLen = 11) then
      CodeLen := 12;
  end;
  if Output.Len > 0 then
  begin
    ADst := BuilderDone(Output);
    Result := True;
  end;
end;

{ PNG and TIFF predictors after /DecodeParms. The parameters come from the
  file: they are checked in Int64 against the data length, so a value such
  as /Columns 200000000 cannot request huge row buffers. }
function ApplyPredictor(const ASrc: TPdfBytes; APredictor, AColors, ABpc, AColumns: Integer;
  out ADst: TPdfBytes): Boolean;
var
  Bpp, RowLen, Rows, R, I, Ft, A, B, C, P, Pa, Pb, Pc: Integer;
  RowLen64: Int64;
  Prior, Cur: TPdfBytes;
  Output: TPdfByteBuilder;
begin
  Result := False;
  ADst := nil;
  if APredictor < 2 then
  begin
    ADst := ASrc;
    Result := True;
    Exit;
  end;
  if (AColors <= 0) or (ABpc <= 0) or (AColumns <= 0) then
    Exit;
  if (AColors > 32) or (ABpc > 32) or (AColumns > LandrixEInvoicePdfMaxStreamSize) then
    Exit;
  RowLen64 := ((Int64(AColors) * ABpc * AColumns) + 7) div 8;
  if (RowLen64 <= 0) or (RowLen64 > Length(ASrc)) then
    Exit;
  Bpp := (AColors * ABpc) div 8;
  if Bpp < 1 then
    Bpp := 1;
  RowLen := Integer(RowLen64);

  if APredictor = 2 then
  begin
    { TIFF predictor, only the common 8-bit case }
    if ABpc <> 8 then
    begin
      ADst := ASrc;
      Result := True;
      Exit;
    end;
    ADst := Copy(ASrc, 0, Length(ASrc));
    Rows := Integer(Length(ADst)) div RowLen;
    for R := 0 to Rows - 1 do
      for I := Bpp to RowLen - 1 do
        ADst[R * RowLen + I] := Byte((ADst[R * RowLen + I] + ADst[R * RowLen + I - Bpp]) and $FF);
    Result := True;
    Exit;
  end;

  { PNG predictors: every row starts with a filter type byte }
  Prior := nil;
  Cur := nil;
  SetLength(Prior, RowLen);
  SetLength(Cur, RowLen);
  FillChar(Prior[0], RowLen, 0);
  Output.Data := nil;
  Output.Len := 0;
  I := 0;
  while I + 1 <= Length(ASrc) - 1 do
  begin
    Ft := ASrc[I];
    Inc(I);
    if I + RowLen > Length(ASrc) then
      Break;
    Move(ASrc[I], Cur[0], RowLen);
    Inc(I, RowLen);
    case Ft of
      0: ;
      1:
        for R := Bpp to RowLen - 1 do
          Cur[R] := Byte((Cur[R] + Cur[R - Bpp]) and $FF);
      2:
        for R := 0 to RowLen - 1 do
          Cur[R] := Byte((Cur[R] + Prior[R]) and $FF);
      3:
        for R := 0 to RowLen - 1 do
        begin
          if R >= Bpp then
            A := Cur[R - Bpp]
          else
            A := 0;
          Cur[R] := Byte((Cur[R] + ((A + Prior[R]) div 2)) and $FF);
        end;
      4:
        for R := 0 to RowLen - 1 do
        begin
          if R >= Bpp then
            A := Cur[R - Bpp]
          else
            A := 0;
          B := Prior[R];
          if R >= Bpp then
            C := Prior[R - Bpp]
          else
            C := 0;
          P := A + B - C;
          Pa := Abs(P - A);
          Pb := Abs(P - B);
          Pc := Abs(P - C);
          if (Pa <= Pb) and (Pa <= Pc) then
            Cur[R] := Byte((Cur[R] + A) and $FF)
          else if Pb <= Pc then
            Cur[R] := Byte((Cur[R] + B) and $FF)
          else
            Cur[R] := Byte((Cur[R] + C) and $FF);
        end;
    else
      Break;
    end;
    BuilderAdd(Output, Cur, 0, RowLen);
    Move(Cur[0], Prior[0], RowLen);
  end;
  ADst := BuilderDone(Output);
  Result := True;
end;

//==============================================================================
// MD5 and RC4 for the standard security handler
//
// Both only recompute the key that older PDF files prescribe; neither
// protects data here.
//==============================================================================

{ MD5 computes modulo 2^32. }
{$IFOPT Q+}{$DEFINE LANDRIXEINVOICE_PDF_RESTORE_Q}{$Q-}{$ENDIF}
{$IFOPT R+}{$DEFINE LANDRIXEINVOICE_PDF_RESTORE_R}{$R-}{$ENDIF}

type
  TPdfMd5Context = record
    State: array[0..3] of Cardinal;
    Buffer: array[0..63] of Byte;
    BufLen: Integer;
    TotalBytes: Int64;
  end;

const
  PdfMd5K: array[0..63] of Cardinal = (
    $D76AA478, $E8C7B756, $242070DB, $C1BDCEEE,
    $F57C0FAF, $4787C62A, $A8304613, $FD469501,
    $698098D8, $8B44F7AF, $FFFF5BB1, $895CD7BE,
    $6B901122, $FD987193, $A679438E, $49B40821,
    $F61E2562, $C040B340, $265E5A51, $E9B6C7AA,
    $D62F105D, $02441453, $D8A1E681, $E7D3FBC8,
    $21E1CDE6, $C33707D6, $F4D50D87, $455A14ED,
    $A9E3E905, $FCEFA3F8, $676F02D9, $8D2A4C8A,
    $FFFA3942, $8771F681, $6D9D6122, $FDE5380C,
    $A4BEEA44, $4BDECFA9, $F6BB4B60, $BEBFBC70,
    $289B7EC6, $EAA127FA, $D4EF3085, $04881D05,
    $D9D4D039, $E6DB99E5, $1FA27CF8, $C4AC5665,
    $F4292244, $432AFF97, $AB9423A7, $FC93A039,
    $655B59C3, $8F0CCC92, $FFEFF47D, $85845DD1,
    $6FA87E4F, $FE2CE6E0, $A3014314, $4E0811A1,
    $F7537E82, $BD3AF235, $2AD7D2BB, $EB86D391);

  { Padding string of ISO 32000-1, 7.6.3.3; an empty user password is
    exactly these 32 bytes.
    DE: Fuellzeichenfolge aus ISO 32000-1, 7.6.3.3; ein leeres
    Benutzerpasswort besteht genau aus diesen 32 Bytes. }
  PdfPasswordPad: array[0..31] of Byte = (
    $28, $BF, $4E, $5E, $4E, $75, $8A, $41, $64, $00, $4E, $56, $FF, $FA, $01, $08,
    $2E, $2E, $00, $B6, $D0, $68, $3E, $80, $2F, $0C, $A9, $FE, $64, $53, $69, $7A);

  PdfMd5S: array[0..63] of Byte = (
    7, 12, 17, 22, 7, 12, 17, 22, 7, 12, 17, 22, 7, 12, 17, 22,
    5, 9, 14, 20, 5, 9, 14, 20, 5, 9, 14, 20, 5, 9, 14, 20,
    4, 11, 16, 23, 4, 11, 16, 23, 4, 11, 16, 23, 4, 11, 16, 23,
    6, 10, 15, 21, 6, 10, 15, 21, 6, 10, 15, 21, 6, 10, 15, 21);

procedure PdfMd5Transform(var AState: array of Cardinal; const ABlock: array of Byte; AOfs: Integer);
var
  M: array[0..15] of Cardinal;
  A, B, C, D, F, Tmp: Cardinal;
  I, G, S: Integer;
begin
  for I := 0 to 15 do
    M[I] := Cardinal(ABlock[AOfs + I * 4]) or
      (Cardinal(ABlock[AOfs + I * 4 + 1]) shl 8) or
      (Cardinal(ABlock[AOfs + I * 4 + 2]) shl 16) or
      (Cardinal(ABlock[AOfs + I * 4 + 3]) shl 24);
  A := AState[0];
  B := AState[1];
  C := AState[2];
  D := AState[3];
  for I := 0 to 63 do
  begin
    if I < 16 then
    begin
      F := (B and C) or ((not B) and D);
      G := I;
    end
    else if I < 32 then
    begin
      F := (D and B) or ((not D) and C);
      G := (5 * I + 1) and 15;
    end
    else if I < 48 then
    begin
      F := B xor C xor D;
      G := (3 * I + 5) and 15;
    end
    else
    begin
      F := C xor (B or (not D));
      G := (7 * I) and 15;
    end;
    Tmp := D;
    D := C;
    C := B;
    F := F + A + PdfMd5K[I] + M[G];
    S := PdfMd5S[I];
    B := B + ((F shl S) or (F shr (32 - S)));
    A := Tmp;
  end;
  AState[0] := AState[0] + A;
  AState[1] := AState[1] + B;
  AState[2] := AState[2] + C;
  AState[3] := AState[3] + D;
end;

procedure PdfMd5Init(out ACtx: TPdfMd5Context);
begin
  ACtx.State[0] := $67452301;
  ACtx.State[1] := $EFCDAB89;
  ACtx.State[2] := $98BADCFE;
  ACtx.State[3] := $10325476;
  ACtx.BufLen := 0;
  ACtx.TotalBytes := 0;
end;

procedure PdfMd5Update(var ACtx: TPdfMd5Context; const AData: TPdfBytes; AOfs, ALen: Integer);
var
  Take, Pos: Integer;
begin
  if ALen <= 0 then
    Exit;
  if AOfs < 0 then
    Exit;
  if AOfs + ALen > Length(AData) then
    Exit;
  Inc(ACtx.TotalBytes, ALen);
  Pos := AOfs;
  if ACtx.BufLen > 0 then
  begin
    Take := 64 - ACtx.BufLen;
    if Take > ALen then
      Take := ALen;
    Move(AData[Pos], ACtx.Buffer[ACtx.BufLen], Take);
    Inc(ACtx.BufLen, Take);
    Inc(Pos, Take);
    Dec(ALen, Take);
    if ACtx.BufLen = 64 then
    begin
      PdfMd5Transform(ACtx.State, ACtx.Buffer, 0);
      ACtx.BufLen := 0;
    end;
  end;
  while ALen >= 64 do
  begin
    PdfMd5Transform(ACtx.State, AData, Pos);
    Inc(Pos, 64);
    Dec(ALen, 64);
  end;
  if ALen > 0 then
  begin
    Move(AData[Pos], ACtx.Buffer[0], ALen);
    ACtx.BufLen := ALen;
  end;
end;

procedure PdfMd5Final(var ACtx: TPdfMd5Context; out ADigest: TPdfBytes);
var
  BitLen: Int64;
  PadLen, I: Integer;
  Tail: TPdfBytes;
begin
  ADigest := nil;
  Tail := nil;
  BitLen := ACtx.TotalBytes * 8;
  PadLen := 56 - (ACtx.BufLen mod 64);
  if PadLen <= 0 then
    Inc(PadLen, 64);
  SetLength(Tail, PadLen + 8);
  FillChar(Tail[0], Length(Tail), 0);
  Tail[0] := $80;
  for I := 0 to 7 do
    Tail[PadLen + I] := Byte((BitLen shr (8 * I)) and $FF);
  PdfMd5Update(ACtx, Tail, 0, Integer(Length(Tail)));
  SetLength(ADigest, 16);
  for I := 0 to 3 do
  begin
    ADigest[I * 4] := Byte(ACtx.State[I] and $FF);
    ADigest[I * 4 + 1] := Byte((ACtx.State[I] shr 8) and $FF);
    ADigest[I * 4 + 2] := Byte((ACtx.State[I] shr 16) and $FF);
    ADigest[I * 4 + 3] := Byte((ACtx.State[I] shr 24) and $FF);
  end;
end;

function PdfMd5(const AData: TPdfBytes; ALen: Integer): TPdfBytes;
var
  Ctx: TPdfMd5Context;
begin
  Result := nil;
  if (ALen < 0) or (ALen > Length(AData)) then
    ALen := Integer(Length(AData));
  PdfMd5Init(Ctx);
  PdfMd5Update(Ctx, AData, 0, ALen);
  PdfMd5Final(Ctx, Result);
end;

{ RC4 is symmetric: the same routine encrypts and decrypts. }
procedure PdfRc4(const AKey, ASrc: TPdfBytes; out ADst: TPdfBytes);
var
  S: array[0..255] of Byte;
  I, J, K, KeyLen: Integer;
  T: Byte;
begin
  ADst := nil;
  SetLength(ADst, Length(ASrc));
  KeyLen := Integer(Length(AKey));
  if (KeyLen = 0) or (Length(ASrc) = 0) then
  begin
    if Length(ASrc) > 0 then
      Move(ASrc[0], ADst[0], Length(ASrc));
    Exit;
  end;
  for I := 0 to 255 do
    S[I] := Byte(I);
  J := 0;
  for I := 0 to 255 do
  begin
    J := (J + S[I] + AKey[I mod KeyLen]) and $FF;
    T := S[I];
    S[I] := S[J];
    S[J] := T;
  end;
  I := 0;
  J := 0;
  for K := 0 to Integer(Length(ASrc)) - 1 do
  begin
    I := (I + 1) and $FF;
    J := (J + S[I]) and $FF;
    T := S[I];
    S[I] := S[J];
    S[J] := T;
    ADst[K] := ASrc[K] xor S[(Integer(S[I]) + Integer(S[J])) and $FF];
  end;
end;

{$IFDEF LANDRIXEINVOICE_PDF_RESTORE_Q}{$Q+}{$UNDEF LANDRIXEINVOICE_PDF_RESTORE_Q}{$ENDIF}
{$IFDEF LANDRIXEINVOICE_PDF_RESTORE_R}{$R+}{$UNDEF LANDRIXEINVOICE_PDF_RESTORE_R}{$ENDIF}

//==============================================================================
// Object model
//==============================================================================

type
  TPdfObjKind = (pok_Null, pok_Bool, pok_Num, pok_Str, pok_Name, pok_Arr, pok_Dict, pok_Stream, pok_Ref);

  { All instances belong to the document (owned list). Destroy frees only
    the own containers, never the children: they are shared references in
    the graph. }
  TPdfObj = class(TObject)
  public
    Kind: TPdfObjKind;
    BoolVal: Boolean;
    NumVal: Double;
    StrVal: TPdfBytes;
    NameVal: AnsiString;
    Items: TObjectList;
    DKeys: array of AnsiString;
    DVals: TObjectList;
    StreamPos: Integer;
    RefNum: Integer;
    RefGen: Integer;
    { Object and generation number of the indirect definition this object
      comes from; they form the object key of encrypted files (ISO 32000-1,
      7.6.2, algorithm 1). OwnerNum = -1: do not decrypt, e.g. objects from
      an object stream whose container was decrypted as a whole. }
    OwnerNum: Integer;
    OwnerGen: Integer;
    { Streams that are never encrypted (xref streams). }
    NoDecrypt: Boolean;
    constructor Create(AKind: TPdfObjKind);
    destructor Destroy; override;
    function AsInt: Int64;
    function IsDictLike: Boolean;
    { Without resolving indirect references. }
    function RawGet(const AKey: AnsiString): TPdfObj;
    procedure AddEntry(const AKey: AnsiString; AValue: TPdfObj);
    function ArrCount: Integer;
    function ArrItem(AIndex: Integer): TPdfObj;
  end;

constructor TPdfObj.Create(AKind: TPdfObjKind);
begin
  inherited Create;
  Kind := AKind;
  StreamPos := -1;
  RefNum := -1;
  RefGen := 0;
  OwnerNum := -1;
  OwnerGen := 0;
  NoDecrypt := False;
  if AKind = pok_Arr then
    Items := TObjectList.Create(False);
  if (AKind = pok_Dict) or (AKind = pok_Stream) then
    DVals := TObjectList.Create(False);
end;

destructor TPdfObj.Destroy;
begin
  Items.Free;
  DVals.Free;
  inherited Destroy;
end;

function TPdfObj.AsInt: Int64;
begin
  if (Kind = pok_Num) and (NumVal <= 1.0e18) and (NumVal >= -1.0e18) then
    Result := Trunc(NumVal)
  else
    Result := 0;
end;

function TPdfObj.IsDictLike: Boolean;
begin
  Result := (Kind = pok_Dict) or (Kind = pok_Stream);
end;

{ PDF names are case-sensitive; the first entry of a key wins. }
function TPdfObj.RawGet(const AKey: AnsiString): TPdfObj;
var
  I: TLandrixEInvoiceListIndex;
begin
  Result := nil;
  if not IsDictLike then
    Exit;
  for I := 0 to DVals.Count - 1 do
    if DKeys[I] = AKey then
    begin
      Result := TPdfObj(DVals[I]);
      Exit;
    end;
end;

procedure TPdfObj.AddEntry(const AKey: AnsiString; AValue: TPdfObj);
begin
  if DVals.Count >= Length(DKeys) then
    SetLength(DKeys, 2 * Length(DKeys) + 8);
  DKeys[DVals.Count] := AKey;
  DVals.Add(AValue);
end;

function TPdfObj.ArrCount: Integer;
begin
  if Kind = pok_Arr then
    Result := Integer(Items.Count)
  else
    Result := 0;
end;

function TPdfObj.ArrItem(AIndex: Integer): TPdfObj;
begin
  if (Kind = pok_Arr) and (AIndex >= 0) and (AIndex < Items.Count) then
    Result := TPdfObj(Items[AIndex])
  else
    Result := nil;
end;

//==============================================================================
// Lexer and object parser
//==============================================================================

type
  TPdfLexer = class(TObject)
  private
    FBuf: TPdfBytes;
    FPos: Integer;
    FOwned: TObjectList;
    function NewObj(AKind: TPdfObjKind): TPdfObj;
    function ParseLiteralString: TPdfObj;
    function ParseHexString: TPdfObj;
    function ParseName: TPdfObj;
    function ParseArray(ADepth: Integer): TPdfObj;
    function ParseDict(ADepth: Integer): TPdfObj;
  public
    constructor Create(const ABuf: TPdfBytes; AOwned: TObjectList);
    procedure SkipWhite;
    { A regular token (number, keyword) without interpretation. }
    function ReadToken: AnsiString;
    function ParseObject(ADepth: Integer): TPdfObj;
    property Pos: Integer read FPos write FPos;
  end;

constructor TPdfLexer.Create(const ABuf: TPdfBytes; AOwned: TObjectList);
begin
  inherited Create;
  FBuf := ABuf;
  FOwned := AOwned;
  FPos := 0;
end;

function TPdfLexer.NewObj(AKind: TPdfObjKind): TPdfObj;
begin
  Result := TPdfObj.Create(AKind);
  FOwned.Add(Result);
end;

procedure TPdfLexer.SkipWhite;
begin
  while FPos < Length(FBuf) do
  begin
    if IsPdfWhite(FBuf[FPos]) then
      Inc(FPos)
    else if FBuf[FPos] = Ord('%') then
    begin
      while (FPos < Length(FBuf)) and (FBuf[FPos] <> 10) and (FBuf[FPos] <> 13) do
        Inc(FPos);
    end
    else
      Break;
  end;
end;

function TPdfLexer.ReadToken: AnsiString;
var
  Start: Integer;
begin
  SkipWhite;
  Start := FPos;
  while (FPos < Length(FBuf)) and IsPdfRegular(FBuf[FPos]) do
    Inc(FPos);
  if FPos = Start then
  begin
    { a single delimiter }
    if FPos < Length(FBuf) then
    begin
      Result := AnsiChar(FBuf[FPos]);
      Inc(FPos);
    end
    else
      Result := '';
    Exit;
  end;
  Result := BytesToAnsi(FBuf, Start, FPos - Start);
end;

function TPdfLexer.ParseLiteralString: TPdfObj;
var
  Depth, Oct, K: Integer;
  B: Byte;
  Output: TPdfByteBuilder;
begin
  Result := NewObj(pok_Str);
  Output.Data := nil;
  Output.Len := 0;
  Inc(FPos);
  Depth := 1;
  while FPos < Length(FBuf) do
  begin
    B := FBuf[FPos];
    Inc(FPos);
    if B = Ord('\') then
    begin
      if FPos >= Length(FBuf) then
        Break;
      B := FBuf[FPos];
      Inc(FPos);
      case B of
        Ord('n'): B := 10;
        Ord('r'): B := 13;
        Ord('t'): B := 9;
        Ord('b'): B := 8;
        Ord('f'): B := 12;
        10: Continue;
        13:
          begin
            if (FPos < Length(FBuf)) and (FBuf[FPos] = 10) then
              Inc(FPos);
            Continue;
          end;
        48..55:
          begin
            Oct := B - 48;
            K := 1;
            while (K < 3) and (FPos < Length(FBuf)) and (FBuf[FPos] >= 48) and (FBuf[FPos] <= 55) do
            begin
              Oct := Oct * 8 + (FBuf[FPos] - 48);
              Inc(FPos);
              Inc(K);
            end;
            B := Byte(Oct and $FF);
          end;
      end;
      BuilderAddByte(Output, B);
      Continue;
    end;
    if B = Ord('(') then
      Inc(Depth)
    else if B = Ord(')') then
    begin
      Dec(Depth);
      if Depth = 0 then
        Break;
    end;
    BuilderAddByte(Output, B);
  end;
  Result.StrVal := BuilderDone(Output);
end;

function TPdfLexer.ParseHexString: TPdfObj;
var
  Hi, V: Integer;
  Output: TPdfByteBuilder;
begin
  Result := NewObj(pok_Str);
  Output.Data := nil;
  Output.Len := 0;
  Inc(FPos);
  Hi := -1;
  while FPos < Length(FBuf) do
  begin
    if FBuf[FPos] = Ord('>') then
    begin
      Inc(FPos);
      Break;
    end;
    V := HexVal(FBuf[FPos]);
    Inc(FPos);
    if V < 0 then
      Continue;
    if Hi < 0 then
      Hi := V
    else
    begin
      BuilderAddByte(Output, Byte((Hi shl 4) or V));
      Hi := -1;
    end;
  end;
  if Hi >= 0 then
    BuilderAddByte(Output, Byte(Hi shl 4));
  Result.StrVal := BuilderDone(Output);
end;

function TPdfLexer.ParseName: TPdfObj;
var
  Start, I, V1, V2, N: Integer;
  S: AnsiString;
begin
  Result := NewObj(pok_Name);
  Inc(FPos);
  Start := FPos;
  while (FPos < Length(FBuf)) and IsPdfRegular(FBuf[FPos]) do
    Inc(FPos);
  { resolve #xx escapes }
  S := '';
  SetLength(S, FPos - Start);
  N := 0;
  I := Start;
  while I < FPos do
  begin
    if (FBuf[I] = Ord('#')) and (I + 2 < FPos) then
    begin
      V1 := HexVal(FBuf[I + 1]);
      V2 := HexVal(FBuf[I + 2]);
      if (V1 >= 0) and (V2 >= 0) then
      begin
        Inc(N);
        S[N] := AnsiChar((V1 shl 4) or V2);
        Inc(I, 3);
        Continue;
      end;
    end;
    Inc(N);
    S[N] := AnsiChar(FBuf[I]);
    Inc(I);
  end;
  SetLength(S, N);
  Result.NameVal := S;
end;

function TPdfLexer.ParseArray(ADepth: Integer): TPdfObj;
var
  O: TPdfObj;
begin
  Result := NewObj(pok_Arr);
  Inc(FPos);
  while True do
  begin
    SkipWhite;
    if FPos >= Length(FBuf) then
      Break;
    if FBuf[FPos] = Ord(']') then
    begin
      Inc(FPos);
      Break;
    end;
    O := ParseObject(ADepth + 1);
    if O = nil then
      Break;
    Result.Items.Add(O);
    if Result.Items.Count > 200000 then
      Break;
  end;
end;

function TPdfLexer.ParseDict(ADepth: Integer): TPdfObj;
var
  KeyObj, ValObj: TPdfObj;
  Save: Integer;
begin
  Result := NewObj(pok_Dict);
  Inc(FPos, 2);
  while True do
  begin
    SkipWhite;
    if FPos >= Length(FBuf) then
      Break;
    if MatchAt(FBuf, FPos, '>>') then
    begin
      Inc(FPos, 2);
      Break;
    end;
    if FBuf[FPos] <> Ord('/') then
    begin
      { unexpected token: skip it so that parsing goes on }
      Save := FPos;
      ReadToken;
      if FPos = Save then
        Inc(FPos);
      Continue;
    end;
    KeyObj := ParseName;
    ValObj := ParseObject(ADepth + 1);
    if ValObj = nil then
      Break;
    Result.AddEntry(KeyObj.NameVal, ValObj);
  end;

  { a following stream turns the dictionary into a stream object }
  Save := FPos;
  SkipWhite;
  if MatchAt(FBuf, FPos, 'stream') then
  begin
    Inc(FPos, 6);
    if (FPos < Length(FBuf)) and (FBuf[FPos] = 13) then
      Inc(FPos);
    if (FPos < Length(FBuf)) and (FBuf[FPos] = 10) then
      Inc(FPos);
    Result.Kind := pok_Stream;
    Result.StreamPos := FPos;
    { the length is decided by the document (/Length may be indirect) }
    Save := IndexOfBytes(FBuf, 'endstream', FPos);
    if Save >= 0 then
      FPos := Save + 9
    else
      FPos := Integer(Length(FBuf));
  end
  else
    FPos := Save;
end;

function TPdfLexer.ParseObject(ADepth: Integer): TPdfObj;
var
  B: Byte;
  Tok: AnsiString;
  Save, SavePos, Code: Integer;
  D, D2: Double;
begin
  Result := nil;
  if ADepth > LandrixEInvoicePdfMaxDepth then
    Exit;
  SkipWhite;
  if FPos >= Length(FBuf) then
    Exit;

  B := FBuf[FPos];
  case B of
    Ord('/'):
      begin
        Result := ParseName;
        Exit;
      end;
    Ord('('):
      begin
        Result := ParseLiteralString;
        Exit;
      end;
    Ord('['):
      begin
        Result := ParseArray(ADepth);
        Exit;
      end;
    Ord(']'), Ord('>'), Ord(')'):
      Exit;
    Ord('<'):
      begin
        if MatchAt(FBuf, FPos, '<<') then
          Result := ParseDict(ADepth)
        else
          Result := ParseHexString;
        Exit;
      end;
    Ord('{'), Ord('}'):
      begin
        Inc(FPos);
        Exit;
      end;
  end;

  { an unknown token (endobj, stream) is given back unconsumed }
  SavePos := FPos;
  Tok := ReadToken;
  if Tok = '' then
    Exit;
  if Tok = 'true' then
  begin
    Result := NewObj(pok_Bool);
    Result.BoolVal := True;
    Exit;
  end;
  if Tok = 'false' then
  begin
    Result := NewObj(pok_Bool);
    Result.BoolVal := False;
    Exit;
  end;
  if Tok = 'null' then
  begin
    Result := NewObj(pok_Null);
    Exit;
  end;

  Val(AsciiToNative(Tok), D, Code);
  if Code <> 0 then
  begin
    FPos := SavePos;
    Exit;
  end;
  Result := NewObj(pok_Num);
  Result.NumVal := D;

  { a number may start an indirect reference "n g R" }
  if (Frac(D) = 0) and (D >= 0) and (D < 2147483647.0) then
  begin
    Save := FPos;
    SkipWhite;
    Tok := ReadToken;
    Val(AsciiToNative(Tok), D2, Code);
    if (Code = 0) and (Frac(D2) = 0) and (D2 >= 0) and (D2 < 65536) then
    begin
      SkipWhite;
      if (FPos < Length(FBuf)) and (FBuf[FPos] = Ord('R')) and
        ((FPos + 1 >= Length(FBuf)) or not IsPdfRegular(FBuf[FPos + 1])) then
      begin
        Inc(FPos);
        Result.Kind := pok_Ref;
        Result.RefNum := Integer(Trunc(D));
        Result.RefGen := Integer(Trunc(D2));
        Exit;
      end;
    end;
    FPos := Save;
  end;
end;

//==============================================================================
// Document: xref resolution, object access, stream data
//==============================================================================

type
  TPdfXrefKind = (pxk_Free, pxk_Normal, pxk_Compressed);

  TPdfXrefEntry = record
    Known: Boolean;
    Kind: TPdfXrefKind;
    Offset: Int64;
    Gen: Integer;
    StmNum: Integer;
    StmIdx: Integer;
  end;

  TPdfDocument = class(TObject)
  private
    FBuf: TPdfBytes;
    FXref: array of TPdfXrefEntry;
    FCache: array of TPdfObj;
    FLoading: array of Boolean;
    FObjStmDone: array of Boolean;
    FOwned: TObjectList;
    FRootRef: TPdfObj;
    FEncryptRef: TPdfObj;
    FIdFirst: TPdfBytes;
    FHeaderPos: Integer;
    FXrefSections: Integer;
    FReconstructed: Boolean;
    { set only while a hybrid /XRefStm is read, see SetEntry }
    FAllowFreeOverride: Boolean;
    FEncrypted: Boolean;
    FCryptReady: Boolean;
    FCryptDone: Boolean;
    FCryptError: string;
    FCryptKey: TPdfBytes;
    FCryptStreams: Boolean;
    FCryptStrings: Boolean;
    FEncryptNum: Integer;
    FStreamError: string;
    function MaxPlausibleObjNum: Integer;
    procedure EnsureSize(ANum: Integer);
    procedure SetEntry(ANum: Integer; AKind: TPdfXrefKind; AOfs: Int64; AGen, AStmNum, AStmIdx: Integer);
    procedure NoteTrailer(ADict: TPdfObj);
    procedure ParseXrefChain(AStartOfs: Int64);
    function ParseClassicXref(ALex: TPdfLexer; out ATrailer: TPdfObj): Boolean;
    function ParseXrefStream(AObj: TPdfObj): Boolean;
    procedure Reconstruct;
    procedure LoadObjStm(AStmNum: Integer);
    procedure SetupEncryption;
    function ObjectKey(ANum, AGen: Integer): TPdfBytes;
    procedure DecryptBytes(var AData: TPdfBytes; ANum, AGen: Integer);
    { Tags the subtree with object and generation number and decrypts its
      strings. }
    procedure TagAndDecrypt(AObj: TPdfObj; ANum, AGen, ADepth: Integer);
  public
    constructor Create;
    destructor Destroy; override;
    function Load(AStream: TStream; out AError: string): Boolean;
    function GetObject(ANum: Integer): TPdfObj;
    function Resolve(AObj: TPdfObj): TPdfObj;
    { dictionary access with resolution of indirect references }
    function DGet(ADict: TPdfObj; const AKey: AnsiString): TPdfObj;
    { False with StreamError if the data cannot be decoded }
    function GetStreamData(AObj: TPdfObj; out AData: TPdfBytes): Boolean;
    function Catalog: TPdfObj;
    property XrefSections: Integer read FXrefSections;
    property Reconstructed: Boolean read FReconstructed;
    property Encrypted: Boolean read FEncrypted;
    property CryptError: string read FCryptError;
    property StreamError: string read FStreamError;
    property HeaderPos: Integer read FHeaderPos;
    property Buf: TPdfBytes read FBuf;
  end;

constructor TPdfDocument.Create;
begin
  inherited Create;
  FOwned := TObjectList.Create(True);
  FCryptStreams := True;
  FCryptStrings := True;
  FEncryptNum := -1;
  FHeaderPos := -1;
end;

destructor TPdfDocument.Destroy;
begin
  FOwned.Free;
  inherited Destroy;
end;

procedure TPdfDocument.EnsureSize(ANum: Integer);
var
  Old, I: Integer;
begin
  if ANum < Length(FXref) then
    Exit;
  Old := Integer(Length(FXref));
  SetLength(FXref, ANum + 1);
  SetLength(FCache, ANum + 1);
  SetLength(FLoading, ANum + 1);
  SetLength(FObjStmDone, ANum + 1);
  for I := Old to ANum do
  begin
    FXref[I].Known := False;
    FCache[I] := nil;
    FLoading[I] := False;
    FObjStmDone[I] := False;
  end;
end;

{ Every object needs room in the file: an xref subsection such as
  "8388608 1" in a 2 KB file is fake and would only force huge tables.
  DE: Jedes Objekt braucht Platz in der Datei: Eine xref-Subsection wie
  "8388608 1" in einer 2-KB-Datei ist unecht und wuerde nur riesige
  Tabellen erzwingen. }
function TPdfDocument.MaxPlausibleObjNum: Integer;
var
  Limit: Int64;
begin
  Limit := (Int64(Length(FBuf)) div 2) + 1024;
  if Limit > 8388608 then
    Limit := 8388608;
  Result := Integer(Limit);
end;

{ The xref chain is read from the newest to the oldest section, and an entry
  is taken only for an object number not seen yet: so the current version of
  an object wins. One exception: in a hybrid file (ISO 32000-1, 7.5.8.4) the
  classic table of the same update lists every object inside an object
  stream as free; the real entry comes from the /XRefStm stream. While
  exactly that stream is read, an entry may replace a free placeholder, and
  only from free to used, so an older section never revives an object that
  a newer one freed.
  DE: Die xref-Kette wird vom neuesten zum aeltesten Abschnitt gelesen, und
  ein Eintrag wird nur fuer eine noch unbekannte Objektnummer uebernommen:
  So gewinnt die aktuelle Fassung eines Objekts. Eine Ausnahme: In einer
  hybriden Datei (ISO 32000-1, 7.5.8.4) fuehrt die klassische Tabelle
  desselben Updates jedes Objekt in einem Object Stream als frei; den echten
  Eintrag liefert der /XRefStm-Strom. Nur waehrend genau dieser Strom
  gelesen wird, darf ein Eintrag einen freien Platzhalter ersetzen, und nur
  von frei auf belegt, damit ein aelterer Abschnitt kein Objekt wiederbelebt,
  das ein neuerer freigegeben hat. }
procedure TPdfDocument.SetEntry(ANum: Integer; AKind: TPdfXrefKind; AOfs: Int64; AGen, AStmNum, AStmIdx: Integer);
begin
  if (ANum < 0) or (ANum > MaxPlausibleObjNum) then
    Exit;
  EnsureSize(ANum);
  if FXref[ANum].Known then
    if not (FAllowFreeOverride and (FXref[ANum].Kind = pxk_Free) and (AKind <> pxk_Free)) then
      Exit;
  FXref[ANum].Known := True;
  FXref[ANum].Kind := AKind;
  FXref[ANum].Offset := AOfs;
  FXref[ANum].Gen := AGen;
  FXref[ANum].StmNum := AStmNum;
  FXref[ANum].StmIdx := AStmIdx;
end;

{ /Root, /Encrypt and /ID[0] (key derivation, ISO 32000-1, 7.6.3.3,
  algorithm 2 step e) come from the first trailer seen, the newest. }
procedure TPdfDocument.NoteTrailer(ADict: TPdfObj);
var
  O, IdObj: TPdfObj;
begin
  if (ADict = nil) or not ADict.IsDictLike then
    Exit;
  if FRootRef = nil then
    FRootRef := ADict.RawGet('Root');
  if FEncryptRef = nil then
    FEncryptRef := ADict.RawGet('Encrypt');
  if Length(FIdFirst) = 0 then
  begin
    IdObj := ADict.RawGet('ID');
    if (IdObj <> nil) and (IdObj.Kind = pok_Arr) and (IdObj.ArrCount > 0) then
    begin
      O := IdObj.ArrItem(0);
      if (O <> nil) and (O.Kind = pok_Str) and (Length(O.StrVal) > 0) then
        FIdFirst := Copy(O.StrVal, 0, Length(O.StrVal));
    end;
  end;
end;

function TPdfDocument.ParseClassicXref(ALex: TPdfLexer; out ATrailer: TPdfObj): Boolean;
var
  Tok: AnsiString;
  StartNum, Cnt, I, Gen, Save: Integer;
  Ofs: Int64;
begin
  Result := False;
  ATrailer := nil;
  { ALex stands behind the keyword xref }
  while True do
  begin
    ALex.SkipWhite;
    Save := ALex.Pos;
    Tok := ALex.ReadToken;
    if Tok = '' then
      Exit;
    if Tok = 'trailer' then
    begin
      ATrailer := ALex.ParseObject(0);
      Result := True;
      Exit;
    end;
    { subsection header: start count }
    if not TokenToInt(Tok, StartNum) then
    begin
      ALex.Pos := Save;
      Result := True; // table ends without trailer
      Exit;
    end;
    if not TokenToInt(ALex.ReadToken, Cnt) then
      Exit;
    if (Cnt < 0) or (Cnt > 8388608) then
      Exit;
    for I := 0 to Cnt - 1 do
    begin
      if not TokenToInt64(ALex.ReadToken, Ofs) then
        Exit;
      if not TokenToInt(ALex.ReadToken, Gen) then
        Exit;
      Tok := ALex.ReadToken;
      if Tok = 'n' then
        SetEntry(StartNum + I, pxk_Normal, Ofs, Gen, -1, -1)
      else if Tok = 'f' then
        SetEntry(StartNum + I, pxk_Free, 0, Gen, -1, -1)
      else
        Exit;
    end;
  end;
end;

function TPdfDocument.ParseXrefStream(AObj: TPdfObj): Boolean;
var
  Data: TPdfBytes;
  WObj, IdxObj, SizeObj, O: TPdfObj;
  W: array[0..2] of Integer;
  F: array[0..2] of Int64;
  IdxPairs: array of Integer;
  I, J, K, RowLen, Pos, Entry, StartNum, Cnt, SizeVal: Integer;
begin
  Result := False;
  IdxPairs := nil;
  if (AObj = nil) or (AObj.Kind <> pok_Stream) then
    Exit;
  { an xref stream is never encrypted (ISO 32000-1, 7.5.8.2) }
  AObj.NoDecrypt := True;
  if not GetStreamData(AObj, Data) then
    Exit;

  WObj := DGet(AObj, 'W');
  if (WObj = nil) or (WObj.Kind <> pok_Arr) or (WObj.ArrCount < 3) then
    Exit;
  for I := 0 to 2 do
  begin
    O := Resolve(WObj.ArrItem(I));
    if (O = nil) or (O.Kind <> pok_Num) then
      Exit;
    if (O.AsInt < 0) or (O.AsInt > 8) then
      Exit;
    W[I] := Integer(O.AsInt);
  end;
  RowLen := W[0] + W[1] + W[2];
  if RowLen <= 0 then
    Exit;

  SizeObj := DGet(AObj, 'Size');
  if (SizeObj <> nil) and (SizeObj.Kind = pok_Num) and (SizeObj.AsInt >= 0) and (SizeObj.AsInt <= 8388608) then
    SizeVal := Integer(SizeObj.AsInt)
  else
    SizeVal := Integer(Length(Data)) div RowLen;

  IdxObj := DGet(AObj, 'Index');
  if (IdxObj <> nil) and (IdxObj.Kind = pok_Arr) and (IdxObj.ArrCount >= 2) then
  begin
    SetLength(IdxPairs, IdxObj.ArrCount);
    for I := 0 to IdxObj.ArrCount - 1 do
    begin
      O := Resolve(IdxObj.ArrItem(I));
      if (O = nil) or (O.Kind <> pok_Num) or (O.AsInt < -1) or (O.AsInt > 8388608) then
        Exit;
      IdxPairs[I] := Integer(O.AsInt);
    end;
  end
  else
  begin
    SetLength(IdxPairs, 2);
    IdxPairs[0] := 0;
    IdxPairs[1] := SizeVal;
  end;

  Pos := 0;
  K := 0;
  while K + 1 < Length(IdxPairs) do
  begin
    StartNum := IdxPairs[K];
    Cnt := IdxPairs[K + 1];
    Inc(K, 2);
    if (Cnt < 0) or (Cnt > 8388608) then
      Exit;
    for Entry := 0 to Cnt - 1 do
    begin
      if Pos + RowLen > Length(Data) then
      begin
        Result := True; // tolerate an early end
        Exit;
      end;
      for I := 0 to 2 do
      begin
        F[I] := 0;
        for J := 0 to W[I] - 1 do
        begin
          F[I] := ((F[I] and $00FFFFFFFFFFFFFF) shl 8) or Data[Pos];
          Inc(Pos);
        end;
      end;
      { a missing first field means type 1 }
      if W[0] = 0 then
        F[0] := 1;
      if F[0] = 0 then
        SetEntry(StartNum + Entry, pxk_Free, 0, Integer(F[2] and $7FFFFFFF), -1, -1)
      else if F[0] = 1 then
        SetEntry(StartNum + Entry, pxk_Normal, F[1], Integer(F[2] and $7FFFFFFF), -1, -1)
      else if F[0] = 2 then
        SetEntry(StartNum + Entry, pxk_Compressed, 0, 0, Integer(F[1] and $7FFFFFFF), Integer(F[2] and $7FFFFFFF));
    end;
  end;
  Result := True;
end;

procedure TPdfDocument.ParseXrefChain(AStartOfs: Int64);
var
  Ofs: Int64;
  Visited: array of Int64;
  I: Integer;
  Seen: Boolean;
  Lex: TPdfLexer;
  Trailer, Obj, PrevObj, StmObj: TPdfObj;
begin
  Visited := nil;
  Ofs := AStartOfs;
  while (Ofs > 0) and (Ofs < Length(FBuf)) do
  begin
    Seen := False;
    for I := 0 to Integer(Length(Visited)) - 1 do
      if Visited[I] = Ofs then
      begin
        Seen := True;
        Break;
      end;
    if Seen then
      Break; // cycle in the /Prev chain
    if Length(Visited) > 1024 then
      Break;
    SetLength(Visited, Length(Visited) + 1);
    Visited[Integer(Length(Visited)) - 1] := Ofs;

    Lex := TPdfLexer.Create(FBuf, FOwned);
    try
      Lex.Pos := Integer(Ofs);
      Lex.SkipWhite;
      Trailer := nil;
      if MatchAt(FBuf, Lex.Pos, 'xref') then
      begin
        Lex.Pos := Lex.Pos + 4;
        if not ParseClassicXref(Lex, Trailer) then
          Break;
        Inc(FXrefSections);
        NoteTrailer(Trailer);
        { hybrid file: an additional xref stream for the same update }
        if (Trailer <> nil) and Trailer.IsDictLike then
        begin
          Obj := Trailer.RawGet('XRefStm');
          if (Obj <> nil) and (Obj.Kind = pok_Num) and (Obj.AsInt > 0) and (Obj.AsInt < Length(FBuf)) then
          begin
            { a damaged /XRefStm only loses the override, the classic
              table just read stays }
            try
              StmObj := nil;
              Lex.Pos := Integer(Obj.AsInt);
              Lex.SkipWhite;
              Lex.ReadToken;
              Lex.ReadToken;
              if Lex.ReadToken = 'obj' then
                StmObj := Lex.ParseObject(0);
              if (StmObj <> nil) and (StmObj.Kind = pok_Stream) then
              begin
                FAllowFreeOverride := True;
                try
                  ParseXrefStream(StmObj);
                finally
                  FAllowFreeOverride := False;
                end;
              end;
            except
              on Exception do
                ;
            end;
          end;
        end;
      end
      else
      begin
        { xref stream: "N G obj << ... >> stream" }
        Lex.ReadToken;
        Lex.ReadToken;
        if Lex.ReadToken <> 'obj' then
          Break;
        Obj := Lex.ParseObject(0);
        if (Obj = nil) or (Obj.Kind <> pok_Stream) then
          Break;
        if not ParseXrefStream(Obj) then
          Break;
        Inc(FXrefSections);
        NoteTrailer(Obj);
        Trailer := Obj;
      end;

      Ofs := 0;
      if (Trailer <> nil) and Trailer.IsDictLike then
      begin
        PrevObj := Trailer.RawGet('Prev');
        if (PrevObj <> nil) and (PrevObj.Kind = pok_Num) then
          Ofs := PrevObj.AsInt;
      end;
    finally
      Lex.Free;
    end;
  end;
end;

{ Fallback: rebuild the object table by scanning for "N G obj". The last
  definition wins, which follows the order in the file but gives no
  protection against replaced versions.
  DE: Notpfad: Objekttabelle per Scan ueber "N G obj" rekonstruieren. Die
  letzte Definition gewinnt; das folgt der Reihenfolge in der Datei, schuetzt
  aber nicht vor ersetzten Fassungen. }
procedure TPdfDocument.Reconstruct;
var
  I, J, K, NumStart, Num, Gen, TrailerPos: Integer;
  Lex: TPdfLexer;
  TrailerObj: TPdfObj;
begin
  FReconstructed := True;
  I := 0;
  while I < Length(FBuf) - 3 do
  begin
    if (FBuf[I] = Ord('o')) and MatchAt(FBuf, I, 'obj') and
      ((I + 3 >= Length(FBuf)) or not IsPdfRegular(FBuf[I + 3])) then
    begin
      { backwards: generation, then object number }
      J := I - 1;
      while (J >= 0) and IsPdfWhite(FBuf[J]) do
        Dec(J);
      K := J;
      while (K >= 0) and (FBuf[K] >= 48) and (FBuf[K] <= 57) do
        Dec(K);
      if (K = J) or not TokenToInt(BytesToAnsi(FBuf, K + 1, J - K), Gen) then
      begin
        Inc(I);
        Continue;
      end;
      J := K;
      while (J >= 0) and IsPdfWhite(FBuf[J]) do
        Dec(J);
      K := J;
      while (K >= 0) and (FBuf[K] >= 48) and (FBuf[K] <= 57) do
        Dec(K);
      if (K = J) or not TokenToInt(BytesToAnsi(FBuf, K + 1, J - K), Num) then
      begin
        Inc(I);
        Continue;
      end;
      NumStart := K + 1;
      if (Num >= 0) and (Num <= MaxPlausibleObjNum) then
      begin
        EnsureSize(Num);
        FXref[Num].Known := True;
        FXref[Num].Kind := pxk_Normal;
        FXref[Num].Offset := NumStart;
        FXref[Num].Gen := Gen;
        FCache[Num] := nil;
      end;
      Inc(I, 3);
      Continue;
    end;
    Inc(I);
  end;

  { look for a trailer if /Root is still missing }
  if FRootRef = nil then
  begin
    TrailerPos := LastIndexOfBytes(FBuf, 'trailer', Integer(Length(FBuf)));
    while TrailerPos >= 0 do
    begin
      Lex := TPdfLexer.Create(FBuf, FOwned);
      try
        Lex.Pos := TrailerPos + 7;
        TrailerObj := Lex.ParseObject(0);
        NoteTrailer(TrailerObj);
      finally
        Lex.Free;
      end;
      if FRootRef <> nil then
        Break;
      if TrailerPos = 0 then
        Break;
      TrailerPos := LastIndexOfBytes(FBuf, 'trailer', TrailerPos - 1);
    end;
  end;
end;

procedure TPdfDocument.LoadObjStm(AStmNum: Integer);
var
  Stm, NObj, FirstObj, Parsed: TPdfObj;
  Data: TPdfBytes;
  N, First, I, Num, Ofs: Integer;
  HdrLex, ObjLex: TPdfLexer;
  Nums, Offs: array of Integer;
begin
  if (AStmNum < 0) or (AStmNum >= Length(FObjStmDone)) then
    Exit;
  if FObjStmDone[AStmNum] then
    Exit;
  FObjStmDone[AStmNum] := True;

  Stm := GetObject(AStmNum);
  if (Stm = nil) or (Stm.Kind <> pok_Stream) then
    Exit;
  if not GetStreamData(Stm, Data) then
    Exit;
  NObj := DGet(Stm, 'N');
  FirstObj := DGet(Stm, 'First');
  if (NObj = nil) or (FirstObj = nil) then
    Exit;
  if (NObj.AsInt <= 0) or (NObj.AsInt > 100000) or (FirstObj.AsInt < 0) or (FirstObj.AsInt > Length(Data)) then
    Exit;
  N := Integer(NObj.AsInt);
  First := Integer(FirstObj.AsInt);

  Nums := nil;
  Offs := nil;
  SetLength(Nums, N);
  SetLength(Offs, N);
  HdrLex := TPdfLexer.Create(Data, FOwned);
  try
    for I := 0 to N - 1 do
    begin
      if not TokenToInt(HdrLex.ReadToken, Nums[I]) then
        Exit;
      if not TokenToInt(HdrLex.ReadToken, Offs[I]) then
        Exit;
    end;
  finally
    HdrLex.Free;
  end;

  ObjLex := TPdfLexer.Create(Data, FOwned);
  try
    for I := 0 to N - 1 do
    begin
      Num := Nums[I];
      if (Offs[I] < 0) or (Offs[I] >= Length(Data) - First) then
        Continue;
      Ofs := First + Offs[I];
      if (Num < 0) or (Num >= Length(FXref)) then
        Continue;
      { only where the xref expects this object, at this index (the third
        field of a type 2 entry); otherwise the stream is manipulated }
      if not FXref[Num].Known then
        Continue;
      if FXref[Num].Kind <> pxk_Compressed then
        Continue;
      if FXref[Num].StmNum <> AStmNum then
        Continue;
      if FXref[Num].StmIdx <> I then
        Continue;
      if FCache[Num] <> nil then
        Continue;
      ObjLex.Pos := Ofs;
      Parsed := ObjLex.ParseObject(0);
      { objects of an object stream keep OwnerNum = -1: the container was
        decrypted as a whole, a second pass would encrypt them again }
      if Parsed <> nil then
        FCache[Num] := Parsed;
    end;
  finally
    ObjLex.Free;
  end;
end;

{ Standard security handler (ISO 32000-1, 7.6.3): RC4 (/V 1, 2, and 4 with
  /CFM /V2; /R 2 to 4) with an empty user password, the usual case of a file
  that carries only a permissions password. A real user password and AES
  (/CFM /AESV2, /AESV3) are reported, not guessed.
  DE: Standard-Security-Handler (ISO 32000-1, 7.6.3): RC4 (/V 1, 2 und 4
  mit /CFM /V2; /R 2 bis 4) mit leerem Benutzerpasswort, der uebliche Fall
  einer Datei, die nur ein Berechtigungspasswort traegt. Ein echtes
  Benutzerpasswort und AES (/CFM /AESV2, /AESV3) werden gemeldet, nicht
  geraten. }
procedure TPdfDocument.SetupEncryption;
var
  Enc, O, CfDict, CfEntry: TPdfObj;
  V, R, LenBits, KeyLen, I, J, N: Integer;
  EncryptMetadata, Ok: Boolean;
  FilterName, CfmName, StmF, StrF, CfName: AnsiString;
  OVal, UVal, Digest, Tmp, Key2, X, Padded: TPdfBytes;
  Ctx: TPdfMd5Context;
  P32: Cardinal;
begin
  Digest := nil;
  OVal := nil;
  UVal := nil;
  Padded := nil;
  Tmp := nil;
  Key2 := nil;
  if FCryptDone then
    Exit;
  { nothing to do without /Encrypt; after a reconstruction it is tried again }
  if FEncryptRef = nil then
    Exit;
  FCryptDone := True;
  FEncrypted := True;
  { the /Encrypt dictionary itself is not encrypted }
  if FEncryptRef.Kind = pok_Ref then
    FEncryptNum := FEncryptRef.RefNum;

  Enc := Resolve(FEncryptRef);
  if (Enc = nil) or not Enc.IsDictLike then
  begin
    FCryptError := 'PDF is encrypted and the /Encrypt dictionary is missing';
    Exit;
  end;

  FilterName := '';
  O := DGet(Enc, 'Filter');
  if (O <> nil) and (O.Kind = pok_Name) then
    FilterName := O.NameVal;
  if FilterName <> 'Standard' then
  begin
    if FilterName = '' then
      FCryptError := 'PDF is encrypted with an unknown security handler'
    else
      FCryptError := 'PDF is encrypted; security handler /' + AsciiToNative(FilterName) + ' is not supported';
    Exit;
  end;

  V := 0;
  R := 0;
  O := DGet(Enc, 'V');
  if (O <> nil) and (O.Kind = pok_Num) then
    V := Integer(O.AsInt);
  O := DGet(Enc, 'R');
  if (O <> nil) and (O.Kind = pok_Num) then
    R := Integer(O.AsInt);
  LenBits := 40;
  O := DGet(Enc, 'Length');
  if (O <> nil) and (O.Kind = pok_Num) then
    LenBits := Integer(O.AsInt);

  { from /V 4 on, named crypt filters say how streams and strings are
    handled; /Identity leaves that part unencrypted }
  CfmName := 'V2';
  if V >= 4 then
  begin
    StmF := 'Identity';
    StrF := 'Identity';
    O := DGet(Enc, 'StmF');
    if (O <> nil) and (O.Kind = pok_Name) then
      StmF := O.NameVal;
    O := DGet(Enc, 'StrF');
    if (O <> nil) and (O.Kind = pok_Name) then
      StrF := O.NameVal;
    FCryptStreams := StmF <> 'Identity';
    FCryptStrings := StrF <> 'Identity';
    if FCryptStreams and FCryptStrings and (StmF <> StrF) then
    begin
      FCryptError := 'PDF is encrypted with different crypt filters for streams and strings (not supported)';
      Exit;
    end;
    if FCryptStreams or FCryptStrings then
    begin
      if FCryptStreams then
        CfName := StmF
      else
        CfName := StrF;
      CfEntry := nil;
      CfDict := DGet(Enc, 'CF');
      if (CfDict <> nil) and CfDict.IsDictLike then
        CfEntry := DGet(CfDict, CfName);
      if (CfEntry = nil) or not CfEntry.IsDictLike then
      begin
        FCryptError := 'PDF is encrypted; crypt filter /' + AsciiToNative(CfName) + ' is not defined';
        Exit;
      end;
      CfmName := '';
      O := DGet(CfEntry, 'CFM');
      if (O <> nil) and (O.Kind = pok_Name) then
        CfmName := O.NameVal;
      { /Length of a crypt filter is mostly in bytes, in /Encrypt in bits;
        practice varies, so decide by size }
      O := DGet(CfEntry, 'Length');
      if (O <> nil) and (O.Kind = pok_Num) then
      begin
        N := Integer(O.AsInt);
        if (N > 0) and (N <= 40) then
          LenBits := N * 8
        else
          LenBits := N;
      end;
    end
    else
      CfmName := 'None';
  end;

  if CfmName = 'None' then
  begin
    FCryptStreams := False;
    FCryptStrings := False;
  end
  else if CfmName <> 'V2' then
  begin
    if (CfmName = 'AESV2') or (CfmName = 'AESV3') then
      FCryptError := 'PDF is AES encrypted (' + AsciiToNative(CfmName) + '); only RC4 is supported'
    else if CfmName = '' then
      FCryptError := 'PDF is encrypted with an unknown method'
    else
      FCryptError := 'PDF is encrypted (method ' + AsciiToNative(CfmName) + '); only RC4 is supported';
    Exit;
  end;

  if (R < 2) or (R > 4) then
  begin
    FCryptError := 'PDF is encrypted; revision ' + IntToStr(R) + ' is not supported';
    Exit;
  end;
  { /V 1 is always 40 bits }
  if V = 1 then
    LenBits := 40;
  if (LenBits < 40) or (LenBits > 128) or ((LenBits mod 8) <> 0) then
  begin
    FCryptError := 'PDF is encrypted with an implausible key length (' + IntToStr(LenBits) + ' bits)';
    Exit;
  end;
  KeyLen := LenBits div 8;

  O := DGet(Enc, 'O');
  if (O = nil) or (O.Kind <> pok_Str) or (Length(O.StrVal) < 32) then
  begin
    FCryptError := 'PDF is encrypted; /O is missing or too short';
    Exit;
  end;
  OVal := O.StrVal;
  O := DGet(Enc, 'U');
  if (O = nil) or (O.Kind <> pok_Str) or (Length(O.StrVal) < 32) then
  begin
    FCryptError := 'PDF is encrypted; /U is missing or too short';
    Exit;
  end;
  UVal := O.StrVal;

  { /P is a signed 32-bit number, also written unsigned; both give the same
    bits after masking }
  P32 := 0;
  O := DGet(Enc, 'P');
  if (O <> nil) and (O.Kind = pok_Num) then
    P32 := Cardinal(O.AsInt and $FFFFFFFF);
  EncryptMetadata := True;
  O := DGet(Enc, 'EncryptMetadata');
  if (O <> nil) and (O.Kind = pok_Bool) then
    EncryptMetadata := O.BoolVal;

  { algorithm 2: key from the empty password }
  SetLength(Padded, 32);
  for I := 0 to 31 do
    Padded[I] := PdfPasswordPad[I];
  PdfMd5Init(Ctx);
  PdfMd5Update(Ctx, Padded, 0, 32);
  PdfMd5Update(Ctx, OVal, 0, 32);
  SetLength(Tmp, 4);
  for I := 0 to 3 do
    Tmp[I] := Byte((P32 shr (8 * I)) and $FF);
  PdfMd5Update(Ctx, Tmp, 0, 4);
  if Length(FIdFirst) > 0 then
    PdfMd5Update(Ctx, FIdFirst, 0, Integer(Length(FIdFirst)));
  if (R >= 4) and not EncryptMetadata then
  begin
    for I := 0 to 3 do
      Tmp[I] := $FF;
    PdfMd5Update(Ctx, Tmp, 0, 4);
  end;
  PdfMd5Final(Ctx, Digest);
  if R >= 3 then
    for I := 1 to 50 do
      Digest := PdfMd5(Digest, KeyLen);
  SetLength(FCryptKey, KeyLen);
  Move(Digest[0], FCryptKey[0], KeyLen);

  { algorithm 6: does the empty user password match /U? }
  if R = 2 then
  begin
    { algorithm 4 }
    PdfRc4(FCryptKey, Padded, X);
    Ok := Length(X) >= 32;
    if Ok then
      for I := 0 to 31 do
        if X[I] <> UVal[I] then
        begin
          Ok := False;
          Break;
        end;
  end
  else
  begin
    { algorithm 5; only the first 16 bytes count, the rest is padding }
    PdfMd5Init(Ctx);
    PdfMd5Update(Ctx, Padded, 0, 32);
    if Length(FIdFirst) > 0 then
      PdfMd5Update(Ctx, FIdFirst, 0, Integer(Length(FIdFirst)));
    PdfMd5Final(Ctx, Digest);
    PdfRc4(FCryptKey, Digest, X);
    SetLength(Key2, KeyLen);
    for I := 1 to 19 do
    begin
      for J := 0 to KeyLen - 1 do
        Key2[J] := Byte(FCryptKey[J] xor Byte(I));
      PdfRc4(Key2, X, Tmp);
      X := Tmp;
    end;
    Ok := Length(X) >= 16;
    if Ok then
      for I := 0 to 15 do
        if X[I] <> UVal[I] then
        begin
          Ok := False;
          Break;
        end;
  end;
  if not Ok then
  begin
    FCryptKey := nil;
    FCryptError := 'PDF is protected by a user password; attachments cannot be read';
    Exit;
  end;
  FCryptReady := True;
end;

{ Object key (ISO 32000-1, 7.6.2, algorithm 1): file key, object and
  generation number, through MD5. }
function TPdfDocument.ObjectKey(ANum, AGen: Integer): TPdfBytes;
var
  Buf, Digest: TPdfBytes;
  N, KeyLen: Integer;
begin
  Result := nil;
  Digest := nil;
  Buf := nil;
  KeyLen := Integer(Length(FCryptKey));
  if KeyLen = 0 then
    Exit;
  SetLength(Buf, KeyLen + 5);
  Move(FCryptKey[0], Buf[0], KeyLen);
  Buf[KeyLen] := Byte(ANum and $FF);
  Buf[KeyLen + 1] := Byte((ANum shr 8) and $FF);
  Buf[KeyLen + 2] := Byte((ANum shr 16) and $FF);
  Buf[KeyLen + 3] := Byte(AGen and $FF);
  Buf[KeyLen + 4] := Byte((AGen shr 8) and $FF);
  Digest := PdfMd5(Buf, Integer(Length(Buf)));
  N := KeyLen + 5;
  if N > 16 then
    N := 16;
  SetLength(Result, N);
  Move(Digest[0], Result[0], N);
end;

procedure TPdfDocument.DecryptBytes(var AData: TPdfBytes; ANum, AGen: Integer);
var
  Key, Dst: TPdfBytes;
begin
  Key := nil;
  if not FCryptReady then
    Exit;
  if ANum < 0 then
    Exit;
  if Length(AData) = 0 then
    Exit;
  Key := ObjectKey(ANum, AGen);
  if Length(Key) = 0 then
    Exit;
  PdfRc4(Key, AData, Dst);
  AData := Dst;
end;

procedure TPdfDocument.TagAndDecrypt(AObj: TPdfObj; ANum, AGen, ADepth: Integer);
var
  I: Integer;
  J: TLandrixEInvoiceListIndex;
begin
  if AObj = nil then
    Exit;
  if ADepth > LandrixEInvoicePdfMaxDepth then
    Exit;
  { already done: a second pass would encrypt the strings again }
  if AObj.OwnerNum >= 0 then
    Exit;
  AObj.OwnerNum := ANum;
  AObj.OwnerGen := AGen;
  case AObj.Kind of
    pok_Str:
      if FCryptReady and FCryptStrings and (ANum >= 0) and (ANum <> FEncryptNum) then
        DecryptBytes(AObj.StrVal, ANum, AGen);
    pok_Arr:
      for I := 0 to AObj.ArrCount - 1 do
        TagAndDecrypt(AObj.ArrItem(I), ANum, AGen, ADepth + 1);
    pok_Dict, pok_Stream:
      for J := 0 to AObj.DVals.Count - 1 do
        TagAndDecrypt(TPdfObj(AObj.DVals[J]), ANum, AGen, ADepth + 1);
  else
    ;
  end;
end;

function TPdfDocument.GetObject(ANum: Integer): TPdfObj;
var
  Lex: TPdfLexer;
  GotNum, GotGen: Integer;
begin
  Result := nil;
  if (ANum < 0) or (ANum >= Length(FXref)) then
    Exit;
  if not FXref[ANum].Known then
    Exit;
  if FCache[ANum] <> nil then
  begin
    Result := FCache[ANum];
    Exit;
  end;
  if FLoading[ANum] then
    Exit; // cycle
  FLoading[ANum] := True;
  try
    case FXref[ANum].Kind of
      pxk_Free:
        ;
      pxk_Compressed:
        begin
          LoadObjStm(FXref[ANum].StmNum);
          Result := FCache[ANum];
        end;
      pxk_Normal:
        begin
          if (FXref[ANum].Offset < 0) or (FXref[ANum].Offset >= Length(FBuf)) then
            Exit;
          Lex := TPdfLexer.Create(FBuf, FOwned);
          try
            Lex.Pos := Integer(FXref[ANum].Offset);
            { the object number must match, else the xref points elsewhere }
            if not TokenToInt(Lex.ReadToken, GotNum) or (GotNum <> ANum) then
              Exit;
            if not TokenToInt(Lex.ReadToken, GotGen) then
              GotGen := FXref[ANum].Gen;
            if Lex.ReadToken <> 'obj' then
              Exit;
            Result := Lex.ParseObject(0);
            FCache[ANum] := Result;
            if Result <> nil then
              TagAndDecrypt(Result, ANum, GotGen, 0);
          finally
            Lex.Free;
          end;
        end;
    end;
  finally
    FLoading[ANum] := False;
  end;
end;

function TPdfDocument.Resolve(AObj: TPdfObj): TPdfObj;
var
  Depth: Integer;
begin
  Result := AObj;
  Depth := 0;
  while (Result <> nil) and (Result.Kind = pok_Ref) do
  begin
    Inc(Depth);
    if Depth > 32 then
    begin
      Result := nil;
      Exit;
    end;
    Result := GetObject(Result.RefNum);
  end;
end;

function TPdfDocument.DGet(ADict: TPdfObj; const AKey: AnsiString): TPdfObj;
begin
  Result := nil;
  if ADict = nil then
    Exit;
  Result := Resolve(ADict.RawGet(AKey));
end;

function TPdfDocument.Catalog: TPdfObj;
begin
  Result := Resolve(FRootRef);
  if (Result <> nil) and not Result.IsDictLike then
    Result := nil;
end;

function TPdfDocument.GetStreamData(AObj: TPdfObj; out AData: TPdfBytes): Boolean;
var
  LenObj, FilterObj, ParmObj, F, P, O: TPdfObj;
  RawLen, EndPos, I, NFilters, Pred, Colors, Bpc, Cols, Early: Integer;
  RawLen64: Int64;
  Raw, Decoded: TPdfBytes;
  FName: AnsiString;
  Ok, TooBig: Boolean;
begin
  Result := False;
  AData := nil;
  FStreamError := 'no stream';
  if (AObj = nil) or (AObj.Kind <> pok_Stream) then
    Exit;
  if (AObj.StreamPos < 0) or (AObj.StreamPos > Length(FBuf)) then
    Exit;

  { length from /Length, else by searching endstream; checked in Int64 so
    that a manipulated /Length near MaxInt cannot overflow }
  RawLen64 := -1;
  LenObj := DGet(AObj, 'Length');
  if (LenObj <> nil) and (LenObj.Kind = pok_Num) then
    RawLen64 := LenObj.AsInt;
  if (RawLen64 < 0) or (RawLen64 > Int64(Length(FBuf)) - AObj.StreamPos) then
    RawLen := -1
  else
  begin
    RawLen := Integer(RawLen64);
    { plausibility: endstream must follow the data }
    I := AObj.StreamPos + RawLen;
    while (I < Length(FBuf)) and IsPdfWhite(FBuf[I]) do
      Inc(I);
    if not MatchAt(FBuf, I, 'endstream') then
      RawLen := -1;
  end;
  if RawLen < 0 then
  begin
    EndPos := IndexOfBytes(FBuf, 'endstream', AObj.StreamPos);
    if EndPos < 0 then
    begin
      FStreamError := 'stream without end';
      Exit;
    end;
    RawLen := EndPos - AObj.StreamPos;
    { the final end of line does not belong to the data }
    if (RawLen > 0) and (FBuf[AObj.StreamPos + RawLen - 1] = 10) then
      Dec(RawLen);
    if (RawLen > 0) and (FBuf[AObj.StreamPos + RawLen - 1] = 13) then
      Dec(RawLen);
  end;
  Raw := Copy(FBuf, AObj.StreamPos, RawLen);

  { with the standard security handler the raw data is encrypted; not for
    xref streams, the /Encrypt dictionary and objects of an object stream }
  if FCryptReady and FCryptStreams and not AObj.NoDecrypt and
    (AObj.OwnerNum >= 0) and (AObj.OwnerNum <> FEncryptNum) then
    DecryptBytes(Raw, AObj.OwnerNum, AObj.OwnerGen);

  FilterObj := DGet(AObj, 'Filter');
  ParmObj := DGet(AObj, 'DecodeParms');
  if ParmObj = nil then
    ParmObj := DGet(AObj, 'DP');
  if FilterObj = nil then
  begin
    AData := Raw;
    FStreamError := '';
    Result := True;
    Exit;
  end;
  FStreamError := '';
  if FilterObj.Kind = pok_Name then
    NFilters := 1
  else if FilterObj.Kind = pok_Arr then
    NFilters := FilterObj.ArrCount
  else
  begin
    FStreamError := 'invalid /Filter';
    Exit;
  end;

  for I := 0 to NFilters - 1 do
  begin
    if FilterObj.Kind = pok_Name then
      F := FilterObj
    else
      F := Resolve(FilterObj.ArrItem(I));
    if (F = nil) or (F.Kind <> pok_Name) then
    begin
      FStreamError := 'invalid /Filter';
      Exit;
    end;
    FName := F.NameVal;
    if (ParmObj <> nil) and (ParmObj.Kind = pok_Arr) then
      P := Resolve(ParmObj.ArrItem(I))
    else if (ParmObj <> nil) and ParmObj.IsDictLike and (I = 0) then
      P := ParmObj
    else
      P := nil;

    TooBig := False;
    if (FName = 'FlateDecode') or (FName = 'Fl') then
      Ok := FilterFlate(Raw, Decoded, TooBig)
    else if (FName = 'LZWDecode') or (FName = 'LZW') then
    begin
      Early := 1;
      if (P <> nil) and P.IsDictLike then
      begin
        O := DGet(P, 'EarlyChange');
        if (O <> nil) and (O.Kind = pok_Num) and (O.AsInt >= 0) and (O.AsInt <= 1) then
          Early := Integer(O.AsInt);
      end;
      Ok := FilterLZW(Raw, Early, Decoded);
    end
    else if (FName = 'ASCIIHexDecode') or (FName = 'AHx') then
      Ok := FilterASCIIHex(Raw, Decoded)
    else if (FName = 'ASCII85Decode') or (FName = 'A85') then
      Ok := FilterASCII85(Raw, Decoded)
    else if (FName = 'RunLengthDecode') or (FName = 'RL') then
      Ok := FilterRunLength(Raw, Decoded)
    else if FName = 'Crypt' then
    begin
      { only the Identity crypt filter passes data through }
      Decoded := Raw;
      Ok := True;
    end
    else
    begin
      { DCTDecode, JPXDecode etc.: no invoice XML }
      FStreamError := 'unsupported filter /' + AsciiToNative(FName);
      Ok := False;
    end;
    if not Ok then
    begin
      if FStreamError <> '' then
        // already set
      else if TooBig then
        FStreamError := 'decoded stream exceeds ' + IntToStr(LandrixEInvoicePdfMaxStreamSize) + ' bytes'
      else
        FStreamError := 'filter /' + AsciiToNative(FName) + ' failed';
      Exit;
    end;
    Raw := Decoded;

    { predictor after this filter }
    if (P <> nil) and P.IsDictLike then
    begin
      Pred := 1;
      Colors := 1;
      Bpc := 8;
      Cols := 1;
      O := DGet(P, 'Predictor');
      if (O <> nil) and (O.Kind = pok_Num) and (O.AsInt >= 0) and (O.AsInt <= 15) then
        Pred := Integer(O.AsInt);
      if Pred > 1 then
      begin
        O := DGet(P, 'Colors');
        if (O <> nil) and (O.Kind = pok_Num) and (O.AsInt >= -1) and (O.AsInt <= 1024) then
          Colors := Integer(O.AsInt);
        O := DGet(P, 'BitsPerComponent');
        if (O <> nil) and (O.Kind = pok_Num) and (O.AsInt >= -1) and (O.AsInt <= 1024) then
          Bpc := Integer(O.AsInt);
        O := DGet(P, 'Columns');
        if (O <> nil) and (O.Kind = pok_Num) and (O.AsInt >= -1) and (O.AsInt <= MaxInt) then
          Cols := Integer(O.AsInt);
        if not ApplyPredictor(Raw, Pred, Colors, Bpc, Cols, Decoded) then
        begin
          FStreamError := 'predictor ' + IntToStr(Pred) + ' failed';
          Exit;
        end;
        Raw := Decoded;
      end;
    end;
  end;
  AData := Raw;
  FStreamError := '';
  Result := True;
end;

function TPdfDocument.Load(AStream: TStream; out AError: string): Boolean;
var
  Size: Int64;
  I, SxPos, Last: Integer;
  StartOfs: Int64;
  Lex: TPdfLexer;
  Obj, TypeObj: TPdfObj;
begin
  Result := False;
  AError := '';
  Size := AStream.Size - AStream.Position;
  if Size <= 0 then
  begin
    AError := 'Empty stream';
    Exit;
  end;
  if Size > LandrixEInvoicePdfMaxFileSize then
  begin
    AError := 'File too large';
    Exit;
  end;
  SetLength(FBuf, Integer(Size));
  AStream.ReadBuffer(FBuf[0], Integer(Size));

  { %PDF- may stand within the first 1024 bytes }
  Last := MinInt(1024, Integer(Length(FBuf)) - 5);
  for I := 0 to Last do
    if MatchAt(FBuf, I, '%PDF-') then
    begin
      FHeaderPos := I;
      Break;
    end;
  if FHeaderPos < 0 then
  begin
    AError := 'Not a PDF file (%PDF- missing)';
    Exit;
  end;

  { follow the /Prev chain from the last startxref }
  StartOfs := 0;
  SxPos := LastIndexOfBytes(FBuf, 'startxref', Integer(Length(FBuf)));
  if SxPos >= 0 then
  begin
    Lex := TPdfLexer.Create(FBuf, FOwned);
    try
      Lex.Pos := SxPos + 9;
      if not TokenToInt64(Lex.ReadToken, StartOfs) then
        StartOfs := 0;
    finally
      Lex.Free;
    end;
  end;
  if StartOfs > 0 then
    try
      ParseXrefChain(StartOfs);
    except
      on Exception do
        FRootRef := nil;
    end;

  { encryption before the first catalog access: resolving it may load object
    streams, which cannot be unpacked without the key }
  SetupEncryption;

  { no usable catalog: rebuild the object table }
  if Catalog = nil then
  begin
    try
      Reconstruct;
    except
      on E: Exception do
      begin
        AError := 'PDF structure not readable: ' + E.Message;
        Exit;
      end;
    end;
    { the reconstruction may have found the trailer and so the /Encrypt }
    SetupEncryption;
    if Catalog = nil then
    begin
      { last attempt: any object with /Type /Catalog }
      for I := 0 to Integer(Length(FXref)) - 1 do
      begin
        if not FXref[I].Known then
          Continue;
        try
          Obj := GetObject(I);
          if (Obj = nil) or not Obj.IsDictLike then
            Continue;
          TypeObj := DGet(Obj, 'Type');
          if (TypeObj <> nil) and (TypeObj.Kind = pok_Name) and (TypeObj.NameVal = 'Catalog') then
          begin
            FRootRef := Obj;
            Break;
          end;
        except
          on Exception do
            ; // skip a damaged object
        end;
      end;
    end;
    if Catalog = nil then
    begin
      AError := 'No PDF catalog found';
      Exit;
    end;
  end;
  Result := True;
end;

//==============================================================================
// Text strings, XML detection
//==============================================================================

const
  { PDFDocEncoding (ISO 32000-1, annex D) where it differs from Latin-1:
    $18..$1F and $80..$A0. }
  PdfDocLow: array[$18..$1F] of Word = ($02D8, $02C7, $02C6, $02D9, $02DD, $02DB, $02DA, $02DC);
  PdfDocHigh: array[$80..$A0] of Word = (
    $2022, $2020, $2021, $2026, $2014, $2013, $0192, $2044, $2039, $203A, $2212, $2030,
    $201E, $201C, $201D, $2018, $2019, $201A, $2122, $FB01, $FB02, $0141, $0152, $0160,
    $0178, $017D, $0131, $0142, $0153, $0161, $017E, $009F, $20AC);

{ A PDF text string: UTF-16BE (or LE) with byte order mark, UTF-8 with byte
  order mark (PDF 2.0), else PDFDocEncoding. Zero characters end UTF-16
  text and are dropped from PDFDocEncoding.
  DE: Ein PDF-Textstring: UTF-16BE (oder LE) mit Byte-Order-Mark, UTF-8 mit
  Byte-Order-Mark (PDF 2.0), sonst PDFDocEncoding. Nullzeichen beenden
  UTF-16-Text und entfallen bei PDFDocEncoding. }
function PdfTextToString(const ABytes: TPdfBytes): TLandrixEInvoiceString;
var
  I, N, Count: Integer;
  W: Word;
  Utf8: TLandrixXmlUtf8;
begin
  Result := '';
  N := Integer(Length(ABytes));
  if (N >= 2) and (((ABytes[0] = $FE) and (ABytes[1] = $FF)) or ((ABytes[0] = $FF) and (ABytes[1] = $FE))) then
  begin
    SetLength(Result, (N - 2) div 2);
    Count := 0;
    I := 2;
    while I + 1 < N do
    begin
      if ABytes[0] = $FE then
        W := Word((ABytes[I] shl 8) or ABytes[I + 1])
      else
        W := Word((ABytes[I + 1] shl 8) or ABytes[I]);
      Inc(I, 2);
      if W = 0 then
        Break;
      Inc(Count);
      Result[Count] := WideChar(W);
    end;
    SetLength(Result, Count);
    Exit;
  end;
  if (N >= 3) and (ABytes[0] = $EF) and (ABytes[1] = $BB) and (ABytes[2] = $BF) then
  begin
    Utf8 := '';
    SetLength(Utf8, N - 3);
    for I := 3 to N - 1 do
      Utf8[I - 2] := AnsiChar(ABytes[I]);
    try
      Result := LandrixEInvoiceUtf8ToString(Utf8);
      Exit;
    except
      on Exception do
        Result := '';
    end;
  end;
  SetLength(Result, N);
  Count := 0;
  for I := 0 to N - 1 do
  begin
    if ABytes[I] = 0 then
      Continue;
    case ABytes[I] of
      $18..$1F: W := PdfDocLow[ABytes[I]];
      $80..$A0: W := PdfDocHigh[ABytes[I]];
    else
      W := ABytes[I];
    end;
    Inc(Count);
    Result[Count] := WideChar(W);
  end;
  SetLength(Result, Count);
end;

{ Local name of the XML root element, '' if the data is not XML. Works on
  the bytes, so no XML parser runs (and no external entity is resolved). }
function DetectXmlRoot(const AData: TPdfBytes): TLandrixEInvoiceString;
var
  I, Limit, Start, P: Integer;
  S: AnsiString;
begin
  Result := '';
  Limit := MinInt(Integer(Length(AData)), 65536);
  I := 0;
  if (Limit >= 3) and (AData[0] = $EF) and (AData[1] = $BB) and (AData[2] = $BF) then
    I := 3;
  while I < Limit do
  begin
    while (I < Limit) and IsPdfWhite(AData[I]) do
      Inc(I);
    if I >= Limit then
      Exit;
    if AData[I] <> Ord('<') then
      Exit;
    if MatchAt(AData, I, '<?') then
    begin
      P := IndexOfBytes(AData, '?>', I);
      if (P < 0) or (P >= Limit) then
        Exit;
      I := P + 2;
      Continue;
    end;
    if MatchAt(AData, I, '<!--') then
    begin
      P := IndexOfBytes(AData, '-->', I);
      if P < 0 then
        Exit;
      I := P + 3;
      { comments may be longer than the limit }
      if I > Limit then
        Limit := MinInt(Integer(Length(AData)), I + 4096);
      Continue;
    end;
    if MatchAt(AData, I, '<!') then
    begin
      { DOCTYPE: up to the closing > outside an internal subset }
      Inc(I, 2);
      while I < Length(AData) do
      begin
        if AData[I] = Ord('[') then
        begin
          P := IndexOfBytes(AData, ']', I);
          if P < 0 then
            Exit;
          I := P + 1;
          Continue;
        end;
        if AData[I] = Ord('>') then
        begin
          Inc(I);
          Break;
        end;
        Inc(I);
      end;
      if I > Limit then
        Limit := MinInt(Integer(Length(AData)), I + 4096);
      Continue;
    end;
    { root element }
    Inc(I);
    Start := I;
    while (I < Length(AData)) and (AData[I] <> 32) and (AData[I] <> 9) and (AData[I] <> 10) and
      (AData[I] <> 13) and (AData[I] <> Ord('>')) and (AData[I] <> Ord('/')) do
      Inc(I);
    { drop the namespace prefix }
    P := I - 1;
    while (P >= Start) and (AData[P] <> Ord(':')) do
      Dec(P);
    if P >= Start then
      Start := P + 1;
    S := BytesToAnsi(AData, Start, I - Start);
    Result := AnsiToText(S);
    Exit;
  end;
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

type
  TPdfAttachmentCollector = class(TObject)
  private
    FDoc: TPdfDocument;
    FList: TLandrixEInvoicePdfAttachmentList;
    FSeen: TObjectList;
    FNodeCount: Integer;
    FTotalBytes: Int64;
    FSkipped: Integer;
    FWarning: string;
    function AlreadySeen(AObj: TPdfObj): Boolean;
    procedure Skip(const AName: TLandrixEInvoiceString; const AReason: string);
    procedure AddFilespec(ASpec: TPdfObj);
    procedure WalkNameTree(ANode: TPdfObj; ADepth: Integer);
  public
    constructor Create(ADoc: TPdfDocument; AList: TLandrixEInvoicePdfAttachmentList);
    destructor Destroy; override;
    procedure Collect;
    property Skipped: Integer read FSkipped;
    property Warning: string read FWarning;
  end;

constructor TPdfAttachmentCollector.Create(ADoc: TPdfDocument; AList: TLandrixEInvoicePdfAttachmentList);
begin
  inherited Create;
  FDoc := ADoc;
  FList := AList;
  FSeen := TObjectList.Create(False);
end;

destructor TPdfAttachmentCollector.Destroy;
begin
  FSeen.Free;
  inherited Destroy;
end;

function TPdfAttachmentCollector.AlreadySeen(AObj: TPdfObj): Boolean;
begin
  Result := FSeen.IndexOf(AObj) >= 0;
  if not Result then
    FSeen.Add(AObj);
end;

procedure TPdfAttachmentCollector.Skip(const AName: TLandrixEInvoiceString; const AReason: string);
begin
  Inc(FSkipped);
  if FWarning = '' then
    FWarning := 'Embedded file "' + string(AName) + '" skipped: ' + AReason;
end;

procedure TPdfAttachmentCollector.AddFilespec(ASpec: TPdfObj);
var
  Ef, Stm, O: TPdfObj;
  Att: TLandrixEInvoicePdfAttachment;
  Data: TPdfBytes;
  NameF, NameUF, Name: TLandrixEInvoiceString;
begin
  if (ASpec = nil) or not ASpec.IsDictLike then
    Exit;
  Ef := FDoc.DGet(ASpec, 'EF');
  if (Ef = nil) or not Ef.IsDictLike then
    Exit;
  { /F is the normal case, /UF the Unicode variant of the same stream }
  Stm := FDoc.DGet(Ef, 'F');
  if Stm = nil then
    Stm := FDoc.DGet(Ef, 'UF');
  if Stm = nil then
    Stm := FDoc.DGet(Ef, 'DOS');
  if (Stm = nil) or (Stm.Kind <> pok_Stream) then
    Exit;
  if AlreadySeen(Stm) then
    Exit;

  { file name: /UF before /F }
  NameF := '';
  NameUF := '';
  O := FDoc.DGet(ASpec, 'F');
  if (O <> nil) and (O.Kind = pok_Str) then
    NameF := PdfTextToString(O.StrVal);
  O := FDoc.DGet(ASpec, 'UF');
  if (O <> nil) and (O.Kind = pok_Str) then
    NameUF := PdfTextToString(O.StrVal);
  if NameUF <> '' then
    Name := NameUF
  else
    Name := NameF;

  if FList.Count >= LandrixEInvoicePdfMaxAttachments then
  begin
    Skip(Name, 'more than ' + IntToStr(LandrixEInvoicePdfMaxAttachments) + ' attachments');
    Exit;
  end;
  if not FDoc.GetStreamData(Stm, Data) then
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
    O := FDoc.DGet(ASpec, 'AFRelationship');
    if (O <> nil) and (O.Kind = pok_Name) then
      Att.Relationship := AnsiToText(O.NameVal);
    O := FDoc.DGet(ASpec, 'Desc');
    if (O <> nil) and (O.Kind = pok_Str) then
      Att.Description := PdfTextToString(O.StrVal);
    O := FDoc.DGet(Stm, 'Subtype');
    if (O <> nil) and (O.Kind = pok_Name) then
      Att.MimeType := AnsiToText(O.NameVal);
    if Length(Data) > 0 then
      Att.Data.WriteBuffer(Data[0], Length(Data));
    Att.Data.Position := 0;
    Att.RootElement := DetectXmlRoot(Data);
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

procedure TPdfAttachmentCollector.WalkNameTree(ANode: TPdfObj; ADepth: Integer);
var
  NamesArr, KidsArr: TPdfObj;
  I: Integer;
begin
  if (ANode = nil) or not ANode.IsDictLike then
    Exit;
  if ADepth > LandrixEInvoicePdfMaxDepth then
    Exit;
  Inc(FNodeCount);
  if FNodeCount > 100000 then
    Exit;
  { leaf: /Names [(name) spec (name) spec ...] }
  NamesArr := FDoc.DGet(ANode, 'Names');
  if (NamesArr <> nil) and (NamesArr.Kind = pok_Arr) then
  begin
    I := 0;
    while I + 1 < NamesArr.ArrCount do
    begin
      AddFilespec(FDoc.Resolve(NamesArr.ArrItem(I + 1)));
      Inc(I, 2);
    end;
  end;
  { inner node: /Kids [node node ...] }
  KidsArr := FDoc.DGet(ANode, 'Kids');
  if (KidsArr <> nil) and (KidsArr.Kind = pok_Arr) then
    for I := 0 to KidsArr.ArrCount - 1 do
      WalkNameTree(FDoc.Resolve(KidsArr.ArrItem(I)), ADepth + 1);
end;

{ The name tree /Names /EmbeddedFiles first, then /AF of the catalog
  (PDF/A-3); AlreadySeen drops duplicates.
  DE: Zuerst der Namensbaum /Names /EmbeddedFiles, dann /AF des Katalogs
  (PDF/A-3); AlreadySeen verwirft Dubletten. }
procedure TPdfAttachmentCollector.Collect;
var
  Cat, Names, Ef, Af: TPdfObj;
  I: Integer;
begin
  Cat := FDoc.Catalog;
  if Cat = nil then
    Exit;
  Names := FDoc.DGet(Cat, 'Names');
  if (Names <> nil) and Names.IsDictLike then
  begin
    Ef := FDoc.DGet(Names, 'EmbeddedFiles');
    if (Ef <> nil) and Ef.IsDictLike then
      WalkNameTree(Ef, 0);
  end;
  Af := FDoc.DGet(Cat, 'AF');
  if (Af <> nil) and (Af.Kind = pok_Arr) then
    for I := 0 to Af.ArrCount - 1 do
      AddFilespec(FDoc.Resolve(Af.ArrItem(I)));
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
  Doc: TPdfDocument;
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
  Doc := TPdfDocument.Create;
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
      AInfo.PdfVersion := AnsiToText(BytesToAnsi(Doc.Buf, Doc.HeaderPos + 5, 3));
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
