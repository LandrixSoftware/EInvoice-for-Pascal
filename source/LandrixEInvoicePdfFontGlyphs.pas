{
  EInvoice-for-Pascal

  Copyright (C) 2026 Landrix Software GmbH & Co. KG

  This file is dual-licensed under:
  - GNU GPL version 3 or later; or
  - the Landrix Software Commercial License.

  See LICENSE and COMMERCIAL-LICENSE.md.

  SPDX-License-Identifier: GPL-3.0-or-later OR LicenseRef-Landrix-Commercial
}

{ The glyphs of a font as veraPDF judges them for the PDF/A glyph rules
  (ISO 19005-2/-3, 6.2.11.4.1-2, 6.2.11.5-1, 6.2.11.8-1): whether a code has
  a glyph in the font program, its width in the program and in the font
  dictionary. For now a Type 0 font whose CMap is Identity-H or Identity-V
  over a CIDFontType2 font with a TrueType program: the CID is the code, the
  glyph its /CIDToGIDMap entry (the identity without one), present for a CID
  other than 0 below the number of glyphs; the program width is the
  horizontal advance scaled to 1000 units per em; the dictionary width comes
  from /W, else /DW (1000 without).

  DE: Die Glyphen einer Schrift, wie veraPDF sie fuer die PDF/A-Glyphregeln
  (ISO 19005-2/-3, 6.2.11.4.1-2, 6.2.11.5-1, 6.2.11.8-1) beurteilt: ob ein
  Code eine Glyphe im Fontprogramm hat, ihre Breite im Programm und im
  Schrift-Dictionary. Vorerst eine Type-0-Schrift mit der CMap Identity-H
  oder Identity-V ueber einer CIDFontType2-Schrift mit TrueType-Programm:
  die CID ist der Code, die Glyphe ihr /CIDToGIDMap-Eintrag (ohne einen die
  Identitaet), vorhanden fuer eine CID ausser 0 unter der Zahl der Glyphen;
  die Programmbreite ist der horizontale Vorschub, auf 1000 Einheiten je em
  skaliert; die Dictionary-Breite kommt aus /W, sonst /DW (ohne 1000). }

{ API: internal. May change in any release; use the facade LandrixEInvoice
  or the stable units instead.
  DE: API: intern. Kann sich in jeder Version aendern; stattdessen die
  Fassade LandrixEInvoice oder die stabilen Units verwenden. }

unit LandrixEInvoicePdfFontGlyphs;

{$I LandrixEInvoice.inc}

interface

uses
  LandrixEInvoicePdfTrueType;

type
  { The glyphs of an Identity CMap over a CIDFontType2 TrueType program.
    The widths of /W are entered with AddRange (the first range for a CID
    wins) and AddSingle (a later single width replaces an earlier one, and
    single widths win over ranges); too much work makes Unsure True.
    DE: Die Glyphen einer Identity-CMap ueber einem CIDFontType2-
    TrueType-Programm. Die Breiten aus /W werden mit AddRange (der erste
    Bereich fuer eine CID gilt) und AddSingle (eine spaetere Einzelbreite
    ersetzt eine fruehere, Einzelbreiten gehen Bereichen vor) eingetragen;
    zu viel Arbeit setzt Unsure. }
  TLandrixEInvoicePdfCidGlyphs = class(TObject)
  private
    FProgram: TLandrixEInvoicePdfTrueTypeProgram;
    FIdentity: Boolean;
    FGids: array of Integer;
    FDefault: Double;
    FSingle: array of Double;
    FSingleSet: array of Boolean;
    FRange: array of Double;
    FRangeSet: array of Boolean;
    FWork: Int64;
    FUnsure: Boolean;
    function GidOf(ACid: Integer): Integer;
    procedure Grow(ACid: Integer);
  public
    { AProgram is not owned; AGids the /CIDToGIDMap stream values (ignored
      with AIdentity); ADefault the width without a /W entry.
      DE: AProgram gehoert nicht dazu; AGids die Werte des
      /CIDToGIDMap-Streams (bei AIdentity ignoriert); ADefault die Breite
      ohne /W-Eintrag. }
    constructor Create(AProgram: TLandrixEInvoicePdfTrueTypeProgram; AIdentity: Boolean;
      const AGids: array of Integer; ADefault: Double);
    procedure AddRange(AFrom, ATo: Int64; AWidth: Double);
    procedure AddSingle(ACid: Int64; AWidth: Double);
    { Whether the code has a glyph in the program (CID 0 has none).
      DE: Ob der Code eine Glyphe im Programm hat (CID 0 hat keine). }
    function Present(ACode: Integer): Boolean;
    { The width of the code in the program and in the dictionary.
      DE: Die Breite des Codes im Programm und im Dictionary. }
    function ProgramWidth(ACode: Integer): Double;
    function DictWidth(ACode: Integer): Double;
    property Unsure: Boolean read FUnsure;
    { The entries of the width tables (their memory) and the work done.
      DE: Die Eintraege der Breitentabellen (ihr Speicher) und die
      geleistete Arbeit. }
    function TableSize: Integer;
    property Work: Int64 read FWork;
  end;

const
  { Codes of an Identity CMap: two bytes each, so 0 to 65535.
    DE: Codes einer Identity-CMap: je zwei Bytes, also 0 bis 65535. }
  LandrixEInvoicePdfCidCodes = 65536;
  { The /W entries this unit enters at most before it is unsure.
    DE: So viele /W-Eintraege traegt diese Unit hoechstens ein, bevor sie
    unsicher ist. }
  LandrixEInvoicePdfCidMaxWork = 4000000;

implementation

constructor TLandrixEInvoicePdfCidGlyphs.Create(AProgram: TLandrixEInvoicePdfTrueTypeProgram; AIdentity: Boolean;
  const AGids: array of Integer; ADefault: Double);
var
  I: Integer;
begin
  inherited Create;
  FProgram := AProgram;
  FIdentity := AIdentity;
  FDefault := ADefault;
  FGids := nil;
  if not AIdentity then
  begin
    SetLength(FGids, Length(AGids));
    for I := 0 to Integer(High(AGids)) do
      FGids[I] := AGids[I];
  end;
  FSingle := nil;
  FSingleSet := nil;
  FRange := nil;
  FRangeSet := nil;
end;

{ The width tables reach up to ACid (they grow with the highest CID of /W,
  at least doubling). }
procedure TLandrixEInvoicePdfCidGlyphs.Grow(ACid: Integer);
var
  I, Old, N: Integer;
begin
  Old := Integer(Length(FSingle));
  if ACid < Old then
    Exit;
  N := 2 * Old;
  if N < 256 then
    N := 256;
  if N < ACid + 1 then
    N := ACid + 1;
  if N > LandrixEInvoicePdfCidCodes then
    N := LandrixEInvoicePdfCidCodes;
  SetLength(FSingle, N);
  SetLength(FSingleSet, N);
  SetLength(FRange, N);
  SetLength(FRangeSet, N);
  for I := Old to N - 1 do
  begin
    FSingleSet[I] := False;
    FRangeSet[I] := False;
  end;
end;

procedure TLandrixEInvoicePdfCidGlyphs.AddRange(AFrom, ATo: Int64; AWidth: Double);
var
  I: Integer;
begin
  if AFrom < 0 then
    AFrom := 0;
  if ATo > LandrixEInvoicePdfCidCodes - 1 then
    ATo := LandrixEInvoicePdfCidCodes - 1;
  if ATo < AFrom then
    Exit;
  FWork := FWork + (ATo - AFrom + 1);
  if FWork > LandrixEInvoicePdfCidMaxWork then
  begin
    FUnsure := True;
    Exit;
  end;
  Grow(Integer(ATo));
  for I := Integer(AFrom) to Integer(ATo) do
    if not FRangeSet[I] then
    begin
      FRange[I] := AWidth;
      FRangeSet[I] := True;
    end;
end;

procedure TLandrixEInvoicePdfCidGlyphs.AddSingle(ACid: Int64; AWidth: Double);
begin
  Inc(FWork);
  if FWork > LandrixEInvoicePdfCidMaxWork then
  begin
    FUnsure := True;
    Exit;
  end;
  if (ACid < 0) or (ACid >= LandrixEInvoicePdfCidCodes) then
    Exit;
  Grow(Integer(ACid));
  FSingle[Integer(ACid)] := AWidth;
  FSingleSet[Integer(ACid)] := True;
end;

function TLandrixEInvoicePdfCidGlyphs.GidOf(ACid: Integer): Integer;
begin
  if FIdentity then
    Result := ACid
  else if ACid < Integer(Length(FGids)) then
    Result := FGids[ACid]
  else
    Result := 0;
end;

function TLandrixEInvoicePdfCidGlyphs.Present(ACode: Integer): Boolean;
begin
  Result := False;
  if (ACode = 0) or (not FIdentity and (ACode >= Integer(Length(FGids)))) then
    Exit;
  Result := GidOf(ACode) < FProgram.NumGlyphs;
end;

function TLandrixEInvoicePdfCidGlyphs.ProgramWidth(ACode: Integer): Double;
var
  Gid, N: Integer;
  Scale: Single;
  W: Single;
begin
  Gid := GidOf(ACode);
  N := FProgram.AdvanceCount;
  if N = 0 then
  begin
    Result := 0;
    Exit;
  end;
  if Gid >= N then
    if Gid < FProgram.NumGlyphs then
      Gid := N - 1
    else
      Gid := 0;
  if FProgram.UnitsPerEm = 0 then
  begin
    { an infinite scale: no width that compares }
    Result := MaxInt;
    Exit;
  end;
  Scale := 1000 / FProgram.UnitsPerEm;
  W := FProgram.Advance(Gid) * Scale;
  Result := W;
end;

function TLandrixEInvoicePdfCidGlyphs.TableSize: Integer;
begin
  Result := Integer(Length(FSingle)) + Integer(Length(FGids));
end;

function TLandrixEInvoicePdfCidGlyphs.DictWidth(ACode: Integer): Double;
begin
  if (ACode < Integer(Length(FSingle))) and FSingleSet[ACode] then
    Result := FSingle[ACode]
  else if (ACode < Integer(Length(FRange))) and FRangeSet[ACode] then
    Result := FRange[ACode]
  else
    Result := FDefault;
end;

end.
