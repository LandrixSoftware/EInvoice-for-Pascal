{
  EInvoice-for-Pascal

  Copyright (C) 2026 Landrix Software GmbH & Co. KG

  This file is dual-licensed under:
  - GNU GPL version 3 or later; or
  - the Landrix Software Commercial License.

  See LICENSE and COMMERCIAL-LICENSE.md.

  SPDX-License-Identifier: GPL-3.0-or-later OR LicenseRef-Landrix-Commercial
}

{ Exact decimal arithmetic on the lexical values the writers produce, as
  XPath computes with xs:decimal: the rule checks and the calculation work
  on the numbers as written, independent of Double, Extended and the
  toolchain.
  DE: Exakte Dezimalarithmetik auf den lexikalischen Werten, die die Writer
  erzeugen, so wie XPath mit xs:decimal rechnet: die Regelpruefung und die
  Berechnung arbeiten mit den Zahlen, wie sie geschrieben werden,
  unabhaengig von Double, Extended und der Toolchain. }

{ API: internal. May change in any release; use the facade LandrixEInvoice
  or the stable units instead.
  DE: API: intern. Kann sich in jeder Version aendern; stattdessen die
  Fassade LandrixEInvoice oder die stabilen Units verwenden. }

unit LandrixEInvoiceExact;

{$I LandrixEInvoice.inc}

interface

uses
  LandrixEInvoiceTypes;

type
  { A decimal number as XPath computes with it (xs:decimal): the digits,
    least significant first, times 10^-Scale. }
  TDigits = array of Byte;
  TExact = record
    Negative: Boolean;
    Scale: Integer;
    Digits: TDigits;
  end;

const
  { Saxon divides xs:decimal values without trailing zeros (integer part
    included) to 18 decimals plus the excess of the dividend's scale over
    the divisor's, rounded half down. }
  XPathDivideScale = 18;

{ A lexical decimal as the mappers write it ('-12.3400'); characters other
  than digits, '.' and '-' are ignored.
  DE: Eine lexikalische Dezimalzahl, wie die Mapper sie schreiben
  ('-12.3400'); andere Zeichen als Ziffern, '.' und '-' werden ignoriert. }
function ExactOf(const AText: TLandrixEInvoiceString): TExact;
{ An Int64 as an exact number. DE: Ein Int64 als genaue Zahl. }
function ExactInt(AValue: Int64): TExact;
{ Sum, difference, negation and product, exact.
  DE: Summe, Differenz, Negation und Produkt, genau. }
function ExactAdd(const A, B: TExact): TExact;
function ExactSub(const A, B: TExact): TExact;
function ExactNegated(const A: TExact): TExact;
function ExactMul(const A, B: TExact): TExact;
{ A div B as Saxon computes it (XPathDivideScale); B must not be 0.
  DE: A div B, wie Saxon es rechnet (XPathDivideScale); B darf nicht 0
  sein. }
function ExactDiv(const A, B: TExact): TExact;
{ -1, 0 or 1 as A is below, equal to or above B.
  DE: -1, 0 oder 1, je nachdem ob A kleiner, gleich oder groesser B ist. }
function ExactCompare(const A, B: TExact): Integer;
{ -1, 0 or 1 by the sign of A. DE: -1, 0 oder 1 nach dem Vorzeichen von A. }
function ExactSign(const A: TExact): Integer;
{ A without trailing zeros, also of the integer part (the scale may become
  negative), as BigDecimal.stripTrailingZeros.
  DE: A ohne Nullen am Ende, auch im ganzzahligen Teil (die Stellenzahl
  kann negativ werden), wie BigDecimal.stripTrailingZeros. }
function Stripped(const A: TExact): TExact;
{ The largest integer not above A. DE: Die groesste ganze Zahl nicht ueber
  A. }
function ExactFloor(const A: TExact): TExact;
{ An exact number as text: '.' before the decimals, trailing zeros removed
  down to AMinDecimals ('-12.30' with 2).
  DE: Eine genaue Zahl als Text: '.' vor den Nachkommastellen, Nullen am
  Ende bis auf AMinDecimals gestrichen ('-12.30' bei 2). }
function ExactText(const A: TExact; AMinDecimals: Integer): TLandrixEInvoiceString;
{ A rounded to cents half away from zero (as the writers round), in ACents;
  False if the magnitude is above 9e16 cents (near the end of Currency).
  DE: A auf Cent gerundet, halb weg von null (wie die Writer runden), in
  ACents; False, wenn der Betrag ueber 9e16 Cent liegt (nahe dem Ende von
  Currency). }
function ExactRoundCents(const A: TExact; out ACents: Int64): Boolean;

implementation

uses
  SysUtils;

function Trimmed(const ADigits: TDigits): TDigits;
var
  N: Integer;
begin
  N := Integer(Length(ADigits));
  while (N > 0) and (ADigits[N - 1] = 0) do
    Dec(N);
  Result := Copy(ADigits, 0, N);
end;

{ A lexical decimal as the mappers write it ('-12.3400'). }
function ExactOf(const AText: TLandrixEInvoiceString): TExact;
var
  I, N: Integer;
  C: TLandrixEInvoiceChar;
begin
  Result.Negative := False;
  Result.Scale := 0;
  SetLength(Result.Digits, Integer(Length(AText)));
  N := 0;
  for I := Integer(Length(AText)) downto 1 do
  begin
    C := AText[I];
    if (C >= '0') and (C <= '9') then
    begin
      Result.Digits[N] := Byte(Ord(C) - Ord('0'));
      Inc(N);
    end
    else if C = '.' then
      Result.Scale := N
    else if C = '-' then
      Result.Negative := True;
  end;
  SetLength(Result.Digits, N);
  Result.Digits := Trimmed(Result.Digits);
  if Integer(Length(Result.Digits)) = 0 then
    Result.Negative := False;
end;

{ The magnitude of A times 10^(AScale - A.Scale); AScale >= A.Scale. }
function Shifted(const A: TExact; AScale: Integer): TDigits;
var
  I, Shift: Integer;
begin
  Shift := AScale - A.Scale;
  Result := nil;
  SetLength(Result, Integer(Length(A.Digits)) + Shift);
  for I := 0 to Shift - 1 do
    Result[I] := 0;
  for I := 0 to Integer(Length(A.Digits)) - 1 do
    Result[I + Shift] := A.Digits[I];
  Result := Trimmed(Result);
end;

function MagCompare(const X, Y: TDigits): Integer;
var
  I: Integer;
begin
  Result := Integer(Length(X)) - Integer(Length(Y));
  I := Integer(Length(X)) - 1;
  while (Result = 0) and (I >= 0) do
  begin
    Result := Integer(X[I]) - Integer(Y[I]);
    Dec(I);
  end;
end;

function MagAdd(const X, Y: TDigits): TDigits;
var
  I, N, D, Carry: Integer;
begin
  N := Integer(Length(X));
  if Integer(Length(Y)) > N then
    N := Integer(Length(Y));
  Result := nil;
  SetLength(Result, N + 1);
  Carry := 0;
  for I := 0 to N do
  begin
    D := Carry;
    if I < Integer(Length(X)) then
      Inc(D, X[I]);
    if I < Integer(Length(Y)) then
      Inc(D, Y[I]);
    Result[I] := Byte(D mod 10);
    Carry := D div 10;
  end;
  Result := Trimmed(Result);
end;

{ X - Y for X >= Y. }
function MagSub(const X, Y: TDigits): TDigits;
var
  I, D, Borrow: Integer;
begin
  Result := nil;
  SetLength(Result, Integer(Length(X)));
  Borrow := 0;
  for I := 0 to Integer(Length(X)) - 1 do
  begin
    D := Integer(X[I]) - Borrow;
    if I < Integer(Length(Y)) then
      Dec(D, Y[I]);
    if D < 0 then
    begin
      Inc(D, 10);
      Borrow := 1;
    end
    else
      Borrow := 0;
    Result[I] := Byte(D);
  end;
  Result := Trimmed(Result);
end;

function MagMul(const X, Y: TDigits): TDigits;
var
  I, J, D, Carry: Integer;
begin
  Result := nil;
  SetLength(Result, Integer(Length(X)) + Integer(Length(Y)) + 1);
  for I := 0 to Integer(Length(Result)) - 1 do
    Result[I] := 0;
  for I := 0 to Integer(Length(X)) - 1 do
  begin
    Carry := 0;
    for J := 0 to Integer(Length(Y)) - 1 do
    begin
      D := Integer(Result[I + J]) + Integer(X[I]) * Integer(Y[J]) + Carry;
      Result[I + J] := Byte(D mod 10);
      Carry := D div 10;
    end;
    J := I + Integer(Length(Y));
    while Carry > 0 do
    begin
      D := Result[J] + Carry;
      Result[J] := Byte(D mod 10);
      Carry := D div 10;
      Inc(J);
    end;
  end;
  Result := Trimmed(Result);
end;

{ X div Y for Y > 0, by long division; ARemainder is X mod Y. }
function MagDiv(const X, Y: TDigits; out ARemainder: TDigits): TDigits;
var
  I, J, Q: Integer;
  R, T: TDigits;
begin
  Result := nil;
  SetLength(Result, Integer(Length(X)));
  R := nil;
  T := nil;
  for I := Integer(Length(X)) - 1 downto 0 do
  begin
    SetLength(T, Integer(Length(R)) + 1);
    T[0] := X[I];
    for J := 0 to Integer(Length(R)) - 1 do
      T[J + 1] := R[J];
    R := Trimmed(T);
    Q := 0;
    while MagCompare(R, Y) >= 0 do
    begin
      R := MagSub(R, Y);
      Inc(Q);
    end;
    Result[I] := Byte(Q);
  end;
  ARemainder := R;
  Result := Trimmed(Result);
end;

function ExactAdd(const A, B: TExact): TExact;
var
  X, Y: TDigits;
begin
  Result.Scale := A.Scale;
  if B.Scale > Result.Scale then
    Result.Scale := B.Scale;
  X := Shifted(A, Result.Scale);
  Y := Shifted(B, Result.Scale);
  if A.Negative = B.Negative then
  begin
    Result.Digits := MagAdd(X, Y);
    Result.Negative := A.Negative;
  end
  else if MagCompare(X, Y) >= 0 then
  begin
    Result.Digits := MagSub(X, Y);
    Result.Negative := A.Negative;
  end
  else
  begin
    Result.Digits := MagSub(Y, X);
    Result.Negative := B.Negative;
  end;
  if Integer(Length(Result.Digits)) = 0 then
    Result.Negative := False;
end;

function ExactNegated(const A: TExact): TExact;
begin
  Result := A;
  Result.Negative := not A.Negative and (Integer(Length(A.Digits)) > 0);
end;

function ExactSub(const A, B: TExact): TExact;
begin
  Result := ExactAdd(A, ExactNegated(B));
end;

function ExactMul(const A, B: TExact): TExact;
begin
  Result.Digits := MagMul(A.Digits, B.Digits);
  Result.Scale := A.Scale + B.Scale;
  Result.Negative := (A.Negative <> B.Negative) and (Integer(Length(Result.Digits)) > 0);
end;

{ A without trailing zeros, also of the integer part (the scale may become
  negative), as BigDecimal.stripTrailingZeros. }
function Stripped(const A: TExact): TExact;
var
  N: Integer;
begin
  Result.Negative := A.Negative;
  Result.Scale := A.Scale;
  N := 0;
  while (N < Integer(Length(A.Digits))) and (A.Digits[N] = 0) do
  begin
    Inc(N);
    Dec(Result.Scale);
  end;
  Result.Digits := Copy(A.Digits, N, Integer(Length(A.Digits)) - N);
end;

{ A div B as Saxon computes it (XPathDivideScale); B must not be 0. }
function ExactDiv(const A, B: TExact): TExact;
var
  X, Y: TExact;
  Remainder, One: TDigits;
begin
  X := Stripped(A);
  Y := Stripped(B);
  Result.Scale := XPathDivideScale;
  if X.Scale > Y.Scale then
    Inc(Result.Scale, X.Scale - Y.Scale);
  Result.Digits := MagDiv(Shifted(X, Result.Scale + Y.Scale), Y.Digits, Remainder);
  { half down: up only when the remainder is more than half the divisor }
  if MagCompare(MagAdd(Remainder, Remainder), Y.Digits) > 0 then
  begin
    One := nil;
    SetLength(One, 1);
    One[0] := 1;
    Result.Digits := MagAdd(Result.Digits, One);
  end;
  Result.Negative := (A.Negative <> B.Negative) and (Integer(Length(Result.Digits)) > 0);
end;

function ExactCompare(const A, B: TExact): Integer;
var
  D: TExact;
begin
  D := ExactSub(A, B);
  if Integer(Length(D.Digits)) = 0 then
    Result := 0
  else if D.Negative then
    Result := -1
  else
    Result := 1;
end;

{ -1, 0 or 1 by the sign of A. }
function ExactSign(const A: TExact): Integer;
begin
  if Integer(Length(A.Digits)) = 0 then
    Result := 0
  else if A.Negative then
    Result := -1
  else
    Result := 1;
end;

{ An Int64 as an exact number. }
function ExactInt(AValue: Int64): TExact;
begin
  Result := ExactOf(TLandrixEInvoiceString(IntToStr(AValue)));
end;

function ExactText(const A: TExact; AMinDecimals: Integer): TLandrixEInvoiceString;
var
  I, N, P, Decimals: Integer;
begin
  Result := '';
  N := Integer(Length(A.Digits));
  for I := N - 1 downto 0 do
    Result := Result + WideChar(Ord('0') + A.Digits[I]);
  if A.Scale < 0 then
    for I := 1 to -A.Scale do
      Result := Result + '0'
  else
  begin
    while Length(Result) <= A.Scale do
      Result := '0' + Result;
    if A.Scale > 0 then
      Result := Copy(Result, 1, Length(Result) - A.Scale) + '.' + Copy(Result, Length(Result) - A.Scale + 1, A.Scale);
  end;
  while (Length(Result) > 1) and (Result[1] = '0') and (Result[2] <> '.') do
    Delete(Result, 1, 1);
  P := Pos('.', Result);
  if P > 0 then
  begin
    while Result[Length(Result)] = '0' do
      Delete(Result, Length(Result), 1);
    if Result[Length(Result)] = '.' then
      Delete(Result, Length(Result), 1);
  end;
  P := Pos('.', Result);
  if P = 0 then
    Decimals := 0
  else
    Decimals := Length(Result) - P;
  if (Decimals = 0) and (AMinDecimals > 0) then
    Result := Result + '.';
  while Decimals < AMinDecimals do
  begin
    Result := Result + '0';
    Inc(Decimals);
  end;
  if A.Negative and (N > 0) then
    Result := '-' + Result;
end;

function ExactFloor(const A: TExact): TExact;
var
  I, N: Integer;
  Fraction: Boolean;
begin
  if A.Scale <= 0 then
  begin
    Result := A;
    Exit;
  end;
  N := A.Scale;
  if N > Integer(Length(A.Digits)) then
    N := Integer(Length(A.Digits));
  Fraction := False;
  for I := 0 to N - 1 do
    if A.Digits[I] <> 0 then
      Fraction := True;
  Result.Scale := 0;
  Result.Digits := Trimmed(Copy(A.Digits, N, Integer(Length(A.Digits)) - N));
  Result.Negative := A.Negative and (Integer(Length(Result.Digits)) > 0);
  if A.Negative and Fraction then
    Result := ExactSub(Result, ExactOf('1'));
end;

function ExactRoundCents(const A: TExact; out ACents: Int64): Boolean;
var
  Cents: TExact;
  Rest, Half: TDigits;
  I, N: Integer;
begin
  ACents := 0;
  Result := False;
  Rest := nil;
  Half := nil;
  { the magnitude times 100, then cut to an integer and look at the rest }
  Cents.Negative := False;
  Cents.Scale := A.Scale - 2;
  Cents.Digits := A.Digits;
  if Cents.Scale > 0 then
  begin
    N := Cents.Scale;
    if N > Integer(Length(Cents.Digits)) then
      N := Integer(Length(Cents.Digits));
    Rest := Copy(Cents.Digits, 0, N);
    Cents.Digits := Copy(Cents.Digits, N, Integer(Length(Cents.Digits)) - N);
    { half: 5 followed by zeros at the scale of the rest }
    SetLength(Half, Cents.Scale);
    for I := 0 to Cents.Scale - 1 do
      Half[I] := 0;
    Half[Cents.Scale - 1] := 5;
    Cents.Scale := 0;
    if MagCompare(Trimmed(Rest), Trimmed(Half)) >= 0 then
      Cents := ExactAdd(Cents, ExactInt(1));
  end
  else
    Cents.Digits := Shifted(Cents, 0);
  Cents.Scale := 0;
  Cents.Digits := Trimmed(Cents.Digits);
  if Integer(Length(Cents.Digits)) > 17 then
    Exit;
  for I := Integer(Length(Cents.Digits)) - 1 downto 0 do
    ACents := ACents * 10 + Cents.Digits[I];
  if ACents > 90000000000000000 then
  begin
    ACents := 0;
    Exit;
  end;
  if A.Negative then
    ACents := -ACents;
  Result := True;
end;

end.
