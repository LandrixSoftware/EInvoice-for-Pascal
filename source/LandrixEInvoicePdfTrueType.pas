{
  EInvoice-for-Pascal

  Copyright (C) 2026 Landrix Software GmbH & Co. KG

  This file is dual-licensed under:
  - GNU GPL version 3 or later; or
  - the Landrix Software Commercial License.

  See LICENSE and COMMERCIAL-LICENSE.md.

  SPDX-License-Identifier: GPL-3.0-or-later OR LicenseRef-Landrix-Commercial
}

{ A TrueType font program (FontFile2) read as veraPDF reads it for the
  PDF/A font rules: the table directory, then head (default 2048 units per
  em), hhea and hmtx (both required), cmap (subtables of formats 0, 4 and 6
  mapped, others kept empty), maxp (default: the number of horizontal
  metrics) and post (formats 2 and 2.5), in this order. A read past the end
  or a missing hhea or hmtx rejects the program; a seek past the end
  rejects it or stops veraPDF (see LandrixEInvoicePdfFontProgram). Other
  tables (glyf, loca) are not read.

  DE: Ein TrueType-Fontprogramm (FontFile2), gelesen wie veraPDF es fuer die
  PDF/A-Schriftregeln liest: das Tabellenverzeichnis, dann head (Vorgabe
  2048 Einheiten je em), hhea und hmtx (beide Pflicht), cmap (Subtabellen
  der Formate 0, 4 und 6 abgebildet, andere leer), maxp (Vorgabe: die Zahl
  der horizontalen Metriken) und post (Formate 2 und 2.5), in dieser
  Reihenfolge. Ein Lesen ueber das Ende oder ein fehlendes hhea oder hmtx
  lehnt das Programm ab; ein Seek ueber das Ende lehnt es ab oder bricht
  veraPDF ab (siehe LandrixEInvoicePdfFontProgram). Andere Tabellen (glyf,
  loca) werden nicht gelesen. }

{ API: internal. May change in any release; use the facade LandrixEInvoice
  or the stable units instead.
  DE: API: intern. Kann sich in jeder Version aendern; stattdessen die
  Fassade LandrixEInvoice oder die stabilen Units verwenden. }

unit LandrixEInvoicePdfTrueType;

{$I LandrixEInvoice.inc}

interface

uses
  LandrixEInvoicePdfObjects, LandrixEInvoicePdfFontProgram;

type
  { One cmap subtable: platform and encoding ID, format, and the mapping
    from codes to glyph IDs (a later entry for a code replaces an earlier
    one). Format 4: the segments, with the glyph IDs read for segments that
    use idRangeOffset; formats 0 and 6: the glyph IDs from First on.
    DE: Eine cmap-Subtabelle: Plattform- und Encoding-ID, Format und die
    Abbildung von Codes auf Glyph-IDs (ein spaeterer Eintrag fuer einen Code
    ersetzt einen frueheren). Format 4: die Segmente, mit den gelesenen
    Glyph-IDs fuer Segmente mit idRangeOffset; Formate 0 und 6: die
    Glyph-IDs ab First. }
  TLandrixEInvoicePdfTrueTypeCmap = record
    PlatformID: Integer;
    EncodingID: Integer;
    Offset: Int64;
    Format: Integer;
    SegStart: array of Integer;
    SegEnd: array of Integer;
    SegDelta: array of Integer;
    SegGlyphs: array of array of Integer;
    SegUsesRange: array of Boolean;
    First: Integer;
    Glyphs: array of Integer;
    { the first code mapped (-1 none) }
    Sample: Integer;
  end;

  { A TrueType program as veraPDF reads it.
    DE: Ein TrueType-Programm, wie veraPDF es liest. }
  TLandrixEInvoicePdfTrueTypeProgram = class(TLandrixEInvoicePdfFontProgram)
  private
    FUnitsPerEm: Integer;
    FAdvances: array of Integer;
    FNumGlyphs: Integer;
    FHasCmap: Boolean;
    FCmaps: array of TLandrixEInvoicePdfTrueTypeCmap;
    FPostNames: Integer;
    FPuts: Int64;
    procedure ReadProgram(R: TLandrixEInvoicePdfFontReader);
    procedure ReadCmap(R: TLandrixEInvoicePdfFontReader; AOffset: Int64);
    procedure ReadSegments(R: TLandrixEInvoicePdfFontReader; var C: TLandrixEInvoicePdfTrueTypeCmap);
    procedure ReadPost(R: TLandrixEInvoicePdfFontReader; AOffset, ALength: Int64);
    procedure Count(R: TLandrixEInvoicePdfFontReader; N: Int64);
    function GetCmapCount: Integer;
  public
    { Reads AData (the decoded program); ASmall: shorter than
      LandrixEInvoicePdfFontMemoryLimit bytes.
      DE: Liest AData (das dekodierte Programm); ASmall: kuerzer als
      LandrixEInvoicePdfFontMemoryLimit Bytes. }
    constructor Create(const AData: TLandrixEInvoicePdfBytes; ASmall: Boolean);
    { Whether there is a cmap subtable with these IDs.
      DE: Ob es eine cmap-Subtabelle mit diesen IDs gibt. }
    function HasCmapFor(APlatformID, AEncodingID: Integer): Boolean;
    { The index of the first subtable with these IDs, -1 none.
      DE: Der Index der ersten Subtabelle mit diesen IDs, -1 keine. }
    function CmapIndex(APlatformID, AEncodingID: Integer): Integer;
    { The glyph ID subtable AIndex gives ACode; APresent False: no entry
      (the result is then 0).
      DE: Die Glyph-ID, die Subtabelle AIndex fuer ACode gibt; APresent
      False: kein Eintrag (das Ergebnis ist dann 0). }
    function GlyphOf(AIndex, ACode: Integer; out APresent: Boolean): Integer;
    { The first code subtable AIndex maps, -1 none.
      DE: Der erste Code, den Subtabelle AIndex abbildet, -1 keiner. }
    function SampleCode(AIndex: Integer): Integer;
    { The number of cmap subtables (0 without cmap).
      DE: Die Zahl der cmap-Subtabellen (0 ohne cmap). }
    property CmapCount: Integer read GetCmapCount;
    property HasCmap: Boolean read FHasCmap;
    property UnitsPerEm: Integer read FUnitsPerEm;
    property NumGlyphs: Integer read FNumGlyphs;
    { The number of names a post table of format 2 lists (0 otherwise).
      DE: Die Zahl der Namen einer post-Tabelle im Format 2 (sonst 0). }
    property PostNames: Integer read FPostNames;
    { The entries read for the cmap and its structures (the work done).
      DE: Die fuer die cmap und ihre Strukturen gelesenen Eintraege (die
      geleistete Arbeit). }
    property Work: Int64 read FPuts;
  end;

const
  { The entries of cmap subtables this reader maps at most before it leaves
    a program undecided.
    DE: So viele Eintraege von cmap-Subtabellen bildet dieser Leser
    hoechstens ab, bevor er ein Programm unentschieden laesst. }
  LandrixEInvoicePdfTrueTypeMaxEntries = 4000000;

implementation

const
  TagHead = $68656164;
  TagHhea = $68686561;
  TagHmtx = $686D7478;
  TagCmap = $636D6170;
  TagMaxp = $6D617870;
  TagPost = $706F7374;
  { the number of standard Macintosh glyph names }
  MacNames = 258;

constructor TLandrixEInvoicePdfTrueTypeProgram.Create(const AData: TLandrixEInvoicePdfBytes; ASmall: Boolean);
var
  R: TLandrixEInvoicePdfFontReader;
begin
  inherited Create;
  FLoad := pfl_Accepted;
  FUnitsPerEm := 2048;
  FCmaps := nil;
  FAdvances := nil;
  R := TLandrixEInvoicePdfFontReader.Create(Self, AData, ASmall);
  try
    try
      ReadProgram(R);
    except
      on ELandrixEInvoicePdfFontStop do
        ;
    end;
  finally
    R.Free;
  end;
end;

procedure TLandrixEInvoicePdfTrueTypeProgram.Count(R: TLandrixEInvoicePdfFontReader; N: Int64);
begin
  FPuts := FPuts + N;
  if FPuts > LandrixEInvoicePdfTrueTypeMaxEntries then
    R.Undecided('cmap subtables too large');
end;

{ The header, the table directory (a table given twice: the last), then the
  tables in a fixed order. }
procedure TLandrixEInvoicePdfTrueTypeProgram.ReadProgram(R: TLandrixEInvoicePdfFontReader);
var
  NumTables, I, NumHMetrics: Integer;
  Tag, Offset, TabLen: Int64;
  HeadAt, HheaAt, HmtxAt, CmapAt, MaxpAt, PostAt, PostLen, Start: Int64;
begin
  HeadAt := -1;
  HheaAt := -1;
  HmtxAt := -1;
  CmapAt := -1;
  MaxpAt := -1;
  PostAt := -1;
  PostLen := 0;
  R.Skip(4);
  NumTables := R.ReadUShort;
  R.Skip(6);
  for I := 0 to NumTables - 1 do
  begin
    Tag := R.ReadULong;
    R.ReadULong;
    Offset := R.ReadULong;
    TabLen := R.ReadULong;
    if Tag = TagCmap then
      CmapAt := Offset
    else if Tag = TagHhea then
      HheaAt := Offset
    else if Tag = TagHmtx then
      HmtxAt := Offset
    else if Tag = TagHead then
      HeadAt := Offset
    else if Tag = TagPost then
    begin
      PostAt := Offset;
      PostLen := TabLen;
    end
    else if Tag = TagMaxp then
      MaxpAt := Offset;
  end;
  { head }
  if HeadAt >= 0 then
  begin
    Start := R.Pos;
    R.Seek(HeadAt);
    R.Skip(18);
    FUnitsPerEm := R.ReadUShort;
    R.Seek(Start);
  end;
  { hhea }
  if HheaAt < 0 then
  begin
    FLoad := pfl_Rejected;
    FReason := 'no hhea table';
    Exit;
  end;
  Start := R.Pos;
  R.Seek(HheaAt);
  R.Skip(4);
  R.ReadShort;
  R.ReadShort;
  R.Skip(26);
  NumHMetrics := R.ReadUShort;
  R.Seek(Start);
  { hmtx }
  if HmtxAt < 0 then
  begin
    FLoad := pfl_Rejected;
    FReason := 'no hmtx table';
    Exit;
  end;
  Start := R.Pos;
  R.Seek(HmtxAt);
  SetLength(FAdvances, NumHMetrics);
  for I := 0 to NumHMetrics - 1 do
  begin
    FAdvances[I] := R.ReadUShort;
    R.Skip(2);
  end;
  R.Seek(Start);
  { cmap }
  if CmapAt >= 0 then
    ReadCmap(R, CmapAt);
  { maxp }
  if MaxpAt >= 0 then
  begin
    Start := R.Pos;
    R.Seek(MaxpAt);
    R.Skip(4);
    FNumGlyphs := R.ReadUShort;
    R.Seek(Start);
  end
  else
    FNumGlyphs := NumHMetrics;
  { post }
  if PostAt >= 0 then
    ReadPost(R, PostAt, PostLen);
end;

procedure TLandrixEInvoicePdfTrueTypeProgram.ReadCmap(R: TLandrixEInvoicePdfFontReader; AOffset: Int64);
var
  Start: Int64;
  N, I, J, E: Integer;
begin
  Start := R.Pos;
  R.Seek(AOffset);
  R.Skip(2);
  N := R.ReadUShort;
  Count(R, N);
  FHasCmap := True;
  SetLength(FCmaps, N);
  for I := 0 to N - 1 do
  begin
    FCmaps[I].PlatformID := R.ReadUShort;
    FCmaps[I].EncodingID := R.ReadUShort;
    FCmaps[I].Offset := R.ReadULong;
    FCmaps[I].Format := -1;
    FCmaps[I].Sample := -1;
    FCmaps[I].First := 0;
  end;
  for I := 0 to N - 1 do
  begin
    R.Seek(FCmaps[I].Offset + AOffset);
    FCmaps[I].Format := R.ReadUShort;
    case FCmaps[I].Format of
      0:
        begin
          R.Skip(4);
          Count(R, 256);
          SetLength(FCmaps[I].Glyphs, 256);
          for J := 0 to 255 do
            FCmaps[I].Glyphs[J] := R.ReadByte;
          FCmaps[I].Sample := 0;
        end;
      4:
        ReadSegments(R, FCmaps[I]);
      6:
        begin
          R.Skip(4);
          FCmaps[I].First := R.ReadUShort;
          E := R.ReadUShort;
          Count(R, E);
          SetLength(FCmaps[I].Glyphs, E);
          for J := 0 to E - 1 do
            FCmaps[I].Glyphs[J] := R.ReadUShort;
          if Length(FCmaps[I].Glyphs) > 0 then
            FCmaps[I].Sample := FCmaps[I].First;
        end;
    else
      { format 2 and the others map nothing }
    end;
  end;
  R.Seek(Start);
end;

{ Format 4: segments of codes with idDelta, or with idRangeOffset into the
  glyph array (not for a segment that starts or ends at 65535). }
procedure TLandrixEInvoicePdfTrueTypeProgram.ReadSegments(R: TLandrixEInvoicePdfFontReader;
  var C: TLandrixEInvoicePdfTrueTypeCmap);
var
  SegCount, I, J, G, RangeOffset: Integer;
  RangeAt: Int64;
  RangeOffsets: array of Integer;
begin
  R.Skip(4);
  SegCount := R.ReadUShort div 2;
  Count(R, 5 * Int64(SegCount));
  R.Skip(6);
  SetLength(C.SegStart, SegCount);
  SetLength(C.SegEnd, SegCount);
  SetLength(C.SegDelta, SegCount);
  SetLength(C.SegGlyphs, SegCount);
  SetLength(C.SegUsesRange, SegCount);
  RangeOffsets := nil;
  SetLength(RangeOffsets, SegCount);
  for I := 0 to SegCount - 1 do
    C.SegEnd[I] := R.ReadUShort;
  R.Skip(2);
  for I := 0 to SegCount - 1 do
    C.SegStart[I] := R.ReadUShort;
  for I := 0 to SegCount - 1 do
    C.SegDelta[I] := R.ReadUShort;
  for I := 0 to SegCount - 1 do
    RangeOffsets[I] := R.ReadUShort;
  RangeAt := R.Pos;
  for I := 0 to SegCount - 1 do
  begin
    C.SegUsesRange[I] := RangeOffsets[I] <> 0;
    if RangeOffsets[I] = 0 then
    begin
      if C.SegEnd[I] >= C.SegStart[I] then
      begin
        Count(R, Int64(C.SegEnd[I]) - C.SegStart[I] + 1);
        if C.Sample < 0 then
          C.Sample := C.SegStart[I];
      end;
    end
    else if (C.SegStart[I] <> 65535) and (C.SegEnd[I] <> 65535) and (C.SegEnd[I] >= C.SegStart[I]) then
    begin
      Count(R, Int64(C.SegEnd[I]) - C.SegStart[I] + 1);
      RangeOffset := RangeOffsets[I] div 2;
      SetLength(C.SegGlyphs[I], C.SegEnd[I] - C.SegStart[I] + 1);
      for J := 0 to C.SegEnd[I] - C.SegStart[I] do
      begin
        R.Seek(RangeAt + (Int64(RangeOffset) + J + (Int64(I) - SegCount)) * 2);
        G := R.ReadUShort;
        if G <> 0 then
          G := (G + C.SegDelta[I]) mod 65536;
        C.SegGlyphs[I][J] := G;
      end;
      if C.Sample < 0 then
        C.Sample := C.SegStart[I];
    end;
  end;
end;

{ post: format 2 lists a name index per glyph (its count replaces the number
  of glyphs when it differs) and Pascal strings up to the table's end; format
  2.5 an offset per glyph into the standard Macintosh names, outside of
  which veraPDF rejects the program. }
procedure TLandrixEInvoicePdfTrueTypeProgram.ReadPost(R: TLandrixEInvoicePdfFontReader; AOffset, ALength: Int64);
var
  Start, Format: Int64;
  N, I, L, Idx: Integer;
begin
  Start := R.Pos;
  R.Seek(AOffset);
  Format := R.ReadRaw32;
  R.Skip(28);
  N := FNumGlyphs;
  if Format = $20000 then
  begin
    N := R.ReadUShort;
    FPostNames := N;
    for I := 0 to N - 1 do
      R.ReadUShort;
    while R.Pos < AOffset + ALength do
    begin
      L := R.ReadByte;
      R.ReadBytes(L);
    end;
  end
  else if Format = $28000 then
    for I := 0 to N - 1 do
    begin
      Idx := R.ReadChar + I;
      if (Idx < 0) or (Idx >= MacNames) then
      begin
        FLoad := pfl_Rejected;
        FReason := 'post table of format 2.5 out of range';
        Exit;
      end;
    end;
  R.Seek(Start);
end;

function TLandrixEInvoicePdfTrueTypeProgram.GetCmapCount: Integer;
begin
  Result := Integer(Length(FCmaps));
end;

function TLandrixEInvoicePdfTrueTypeProgram.CmapIndex(APlatformID, AEncodingID: Integer): Integer;
var
  I: Integer;
begin
  Result := -1;
  for I := 0 to Integer(Length(FCmaps)) - 1 do
    if (FCmaps[I].PlatformID = APlatformID) and (FCmaps[I].EncodingID = AEncodingID) then
    begin
      Result := I;
      Exit;
    end;
end;

function TLandrixEInvoicePdfTrueTypeProgram.HasCmapFor(APlatformID, AEncodingID: Integer): Boolean;
begin
  Result := CmapIndex(APlatformID, AEncodingID) >= 0;
end;

function TLandrixEInvoicePdfTrueTypeProgram.SampleCode(AIndex: Integer): Integer;
begin
  Result := -1;
  if (AIndex >= 0) and (AIndex < Integer(Length(FCmaps))) then
    Result := FCmaps[AIndex].Sample;
end;

function TLandrixEInvoicePdfTrueTypeProgram.GlyphOf(AIndex, ACode: Integer; out APresent: Boolean): Integer;
var
  I: Integer;
begin
  Result := 0;
  APresent := False;
  if (AIndex < 0) or (AIndex >= Integer(Length(FCmaps))) then
    Exit;
  case FCmaps[AIndex].Format of
    0, 6:
      if (ACode >= FCmaps[AIndex].First) and (ACode - FCmaps[AIndex].First < Integer(Length(FCmaps[AIndex].Glyphs))) then
      begin
        APresent := True;
        Result := FCmaps[AIndex].Glyphs[ACode - FCmaps[AIndex].First];
      end;
    4:
      { the last segment that maps the code wins }
      for I := Integer(Length(FCmaps[AIndex].SegStart)) - 1 downto 0 do
        if (ACode >= FCmaps[AIndex].SegStart[I]) and (ACode <= FCmaps[AIndex].SegEnd[I]) then
          if not FCmaps[AIndex].SegUsesRange[I] then
          begin
            APresent := True;
            Result := (FCmaps[AIndex].SegDelta[I] + ACode) mod 65536;
            Exit;
          end
          else if Length(FCmaps[AIndex].SegGlyphs[I]) > 0 then
          begin
            APresent := True;
            Result := FCmaps[AIndex].SegGlyphs[I][ACode - FCmaps[AIndex].SegStart[I]];
            Exit;
          end;
  end;
end;

end.
