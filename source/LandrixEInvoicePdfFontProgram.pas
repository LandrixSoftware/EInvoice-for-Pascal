{
  EInvoice-for-Pascal

  Copyright (C) 2026 Landrix Software GmbH & Co. KG

  This file is dual-licensed under:
  - GNU GPL version 3 or later; or
  - the Landrix Software Commercial License.

  See LICENSE and COMMERCIAL-LICENSE.md.

  SPDX-License-Identifier: GPL-3.0-or-later OR LicenseRef-Landrix-Commercial
}

{ The common part of the font program readers for the PDF/A font rules
  (ISO 19005-2/-3, 6.2.11): a program is read from its decoded stream data
  as veraPDF reads it, and the reader answers only what veraPDF takes from
  it. Whether veraPDF accepts the program is one of four states: accepted,
  rejected (it counts as not embedded), veraPDF stops the validation, or
  not decided (anything this reader does not model, and every limit).

  DE: Der gemeinsame Teil der Leser fuer Fontprogramme fuer die
  PDF/A-Schriftregeln (ISO 19005-2/-3, 6.2.11): ein Programm wird aus seinen
  dekodierten Stream-Daten gelesen, wie veraPDF es liest, und der Leser
  beantwortet nur, was veraPDF daraus nimmt. Ob veraPDF das Programm
  annimmt, ist einer von vier Zustaenden: angenommen, abgelehnt (es zaehlt
  als nicht eingebettet), veraPDF bricht die Pruefung ab, oder nicht
  entschieden (alles, was dieser Leser nicht nachbildet, und jede Grenze). }

{ API: internal. May change in any release; use the facade LandrixEInvoice
  or the stable units instead.
  DE: API: intern. Kann sich in jeder Version aendern; stattdessen die
  Fassade LandrixEInvoice oder die stabilen Units verwenden. }

unit LandrixEInvoicePdfFontProgram;

{$I LandrixEInvoice.inc}

interface

uses
  SysUtils, LandrixEInvoicePdfObjects;

type
  { Whether veraPDF accepts a font program: pfl_Accepted it reads it,
    pfl_Rejected it counts as not embedded, pfl_Throws veraPDF stops the
    validation, pfl_Undecided not decided.
    DE: Ob veraPDF ein Fontprogramm annimmt: pfl_Accepted es liest es,
    pfl_Rejected es zaehlt als nicht eingebettet, pfl_Throws veraPDF bricht
    die Pruefung ab, pfl_Undecided nicht entschieden. }
  TLandrixEInvoicePdfFontLoad = (pfl_Accepted, pfl_Rejected, pfl_Throws, pfl_Undecided);

  { The base of the font program readers: the load state and a short reason
    for anything but pfl_Accepted.
    DE: Die Basis der Fontprogramm-Leser: der Ladezustand und ein kurzer
    Grund fuer alles ausser pfl_Accepted. }
  TLandrixEInvoicePdfFontProgram = class(TObject)
  protected
    FLoad: TLandrixEInvoicePdfFontLoad;
    FReason: string;
  public
    { The load state. DE: Der Ladezustand. }
    property Load: TLandrixEInvoicePdfFontLoad read FLoad;
    { Why the program is not accepted. DE: Warum das Programm nicht angenommen
      ist. }
    property Reason: string read FReason;
  end;

  { Raised by a reader to stop: the state and reason are set before.
    DE: Von einem Leser ausgeloest, um abzubrechen: Zustand und Grund sind
    vorher gesetzt. }
  ELandrixEInvoicePdfFontStop = class(Exception);

  { Bytes of a font program read with bounds as veraPDF reads them: a read
    past the end rejects the program; a seek past the end rejects a program
    shorter than LandrixEInvoicePdfFontMemoryLimit bytes (ASmall) and stops
    the validation for a longer one; a skip stops at the end.
    DE: Bytes eines Fontprogramms, mit Grenzen gelesen, wie veraPDF sie
    liest: ein Lesen ueber das Ende lehnt das Programm ab; ein Seek ueber das
    Ende lehnt ein Programm kuerzer als LandrixEInvoicePdfFontMemoryLimit
    Bytes (ASmall) ab und bricht bei einem laengeren die Pruefung ab; ein
    Skip haelt am Ende an. }
  TLandrixEInvoicePdfFontReader = class(TObject)
  private
    FData: TLandrixEInvoicePdfBytes;
    FLen: Int64;
    FPos: Int64;
    FSmall: Boolean;
    FOwner: TLandrixEInvoicePdfFontProgram;
    procedure Stop(ALoad: TLandrixEInvoicePdfFontLoad; const AReason: string);
  public
    constructor Create(AOwner: TLandrixEInvoicePdfFontProgram; const AData: TLandrixEInvoicePdfBytes;
      ASmall: Boolean);
    { A byte (0 to 255). DE: Ein Byte (0 bis 255). }
    function ReadByte: Integer;
    { A signed byte. DE: Ein Byte mit Vorzeichen. }
    function ReadChar: Integer;
    { A big-endian unsigned 16-bit value. DE: Ein vorzeichenloser
      16-Bit-Wert, Big Endian. }
    function ReadUShort: Integer;
    { A big-endian signed 16-bit value. DE: Ein 16-Bit-Wert mit Vorzeichen,
      Big Endian. }
    function ReadShort: Integer;
    { A big-endian unsigned 32-bit value. DE: Ein vorzeichenloser
      32-Bit-Wert, Big Endian. }
    function ReadULong: Int64;
    { Up to four bytes as a 32-bit value; fewer at the end are no error.
      DE: Bis zu vier Bytes als 32-Bit-Wert; weniger am Ende sind kein
      Fehler. }
    function ReadRaw32: Int64;
    { Up to ACount bytes; fewer at the end are no error. DE: Bis zu ACount
      Bytes; weniger am Ende sind kein Fehler. }
    procedure ReadBytes(ACount: Integer);
    procedure Skip(ACount: Int64);
    procedure Seek(AOffset: Int64);
    { Marks the program as not decided and stops. DE: Markiert das Programm
      als nicht entschieden und bricht ab. }
    procedure Undecided(const AReason: string);
    property Pos: Int64 read FPos;
    property Len: Int64 read FLen;
    property Data: TLandrixEInvoicePdfBytes read FData;
  end;

const
  { A seek past the end rejects a decoded font program shorter than this
    many bytes; for a longer one veraPDF stops.
    DE: Ein Seek ueber das Ende lehnt ein dekodiertes Fontprogramm ab, das
    kuerzer ist als so viele Bytes; bei einem laengeren bricht veraPDF ab. }
  LandrixEInvoicePdfFontMemoryLimit = 10240;

implementation

constructor TLandrixEInvoicePdfFontReader.Create(AOwner: TLandrixEInvoicePdfFontProgram;
  const AData: TLandrixEInvoicePdfBytes; ASmall: Boolean);
begin
  inherited Create;
  FOwner := AOwner;
  FData := AData;
  FLen := Length(AData);
  FPos := 0;
  FSmall := ASmall;
end;

procedure TLandrixEInvoicePdfFontReader.Stop(ALoad: TLandrixEInvoicePdfFontLoad; const AReason: string);
begin
  FOwner.FLoad := ALoad;
  FOwner.FReason := AReason;
  raise ELandrixEInvoicePdfFontStop.Create(AReason);
end;

procedure TLandrixEInvoicePdfFontReader.Undecided(const AReason: string);
begin
  Stop(pfl_Undecided, AReason);
end;

function TLandrixEInvoicePdfFontReader.ReadByte: Integer;
begin
  if FPos >= FLen then
    Stop(pfl_Rejected, 'read past the end of the font program');
  Result := FData[Integer(FPos)];
  Inc(FPos);
end;

function TLandrixEInvoicePdfFontReader.ReadChar: Integer;
begin
  Result := ReadByte;
  if Result > 127 then
    Result := Result - 256;
end;

function TLandrixEInvoicePdfFontReader.ReadUShort: Integer;
begin
  Result := ReadByte shl 8;
  Result := Result or ReadByte;
end;

function TLandrixEInvoicePdfFontReader.ReadShort: Integer;
begin
  Result := ReadUShort;
  if Result > 32767 then
    Result := Result - 65536;
end;

function TLandrixEInvoicePdfFontReader.ReadULong: Int64;
begin
  Result := ReadUShort;
  Result := Result * 65536 + ReadUShort;
end;

function TLandrixEInvoicePdfFontReader.ReadRaw32: Int64;
var
  I: Integer;
begin
  Result := 0;
  for I := 0 to 3 do
  begin
    Result := Result * 256;
    if FPos < FLen then
    begin
      Result := Result + FData[Integer(FPos)];
      Inc(FPos);
    end;
  end;
end;

procedure TLandrixEInvoicePdfFontReader.ReadBytes(ACount: Integer);
begin
  if ACount > FLen - FPos then
    FPos := FLen
  else
    Inc(FPos, ACount);
end;

procedure TLandrixEInvoicePdfFontReader.Skip(ACount: Int64);
begin
  if ACount <= 0 then
    Exit;
  if ACount > FLen - FPos then
    FPos := FLen
  else
    Inc(FPos, ACount);
end;

procedure TLandrixEInvoicePdfFontReader.Seek(AOffset: Int64);
begin
  if AOffset < 0 then
    Stop(pfl_Rejected, 'seek before the start of the font program');
  if AOffset > FLen then
    if FSmall then
      Stop(pfl_Rejected, 'seek past the end of the font program')
    else
      Stop(pfl_Throws, 'seek past the end of a font program of 10240 bytes or more');
  FPos := AOffset;
end;

end.
