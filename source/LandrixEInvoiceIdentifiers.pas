{
  EInvoice-for-Pascal

  Copyright (C) 2026 Landrix Software GmbH & Co. KG

  This file is dual-licensed under:
  - GNU GPL version 3 or later; or
  - the Landrix Software Commercial License.

  See LICENSE and COMMERCIAL-LICENSE.md.

  SPDX-License-Identifier: GPL-3.0-or-later OR LicenseRef-Landrix-Commercial
}

{ Formats and check digits of identifiers as the validators test them:
  the XPath functions of the Peppol BIS schematron (u:gln, u:mod11,
  u:mod97-0208, u:checkCodiceIPA, u:checkCF, u:checkPIVAseIT,
  u:checkSEOrgnr, u:abn, u:TinVerification) and the IBAN check of KoSIT
  (xr:checkIBAN). The functions take the value as the schematron passes it
  (most rules normalize it first, see LandrixEInvoiceNormalizeSpace) and
  know nothing about invoices or targets.

  DE: Formate und Pruefziffern von Kennungen, wie die Validatoren sie
  pruefen: die XPath-Funktionen des Peppol-BIS-Schematrons (u:gln, u:mod11,
  u:mod97-0208, u:checkCodiceIPA, u:checkCF, u:checkPIVAseIT,
  u:checkSEOrgnr, u:abn, u:TinVerification) und die IBAN-Pruefung der KoSIT
  (xr:checkIBAN). Die Funktionen nehmen den Wert so, wie das Schematron ihn
  uebergibt (die meisten Regeln normalisieren ihn vorher, siehe
  LandrixEInvoiceNormalizeSpace), und wissen nichts von Rechnungen oder
  Zielen. }

{ API: internal. May change in any release; use the facade LandrixEInvoice
  or the stable units instead.
  DE: API: intern. Kann sich in jeder Version aendern; stattdessen die
  Fassade LandrixEInvoice oder die stabilen Units verwenden. }

unit LandrixEInvoiceIdentifiers;

{$I LandrixEInvoice.inc}

interface

uses
  LandrixEInvoiceTypes;

{ XPath normalize-space: no blank (space, tab, line feed, carriage return)
  at either end, one space between words.
  DE: XPath normalize-space: kein Leerraum (Leerzeichen, Tab, Zeilenvorschub,
  Wagenruecklauf) an den Enden, ein Leerzeichen zwischen Woertern. }
function LandrixEInvoiceNormalizeSpace(const AValue: TLandrixEInvoiceString): TLandrixEInvoiceString;

{ True if AValue has ALength characters (0: at least one) and all are the
  digits 0 to 9 (XPath '^[0-9]+$', with a fixed number of digits).
  DE: True, wenn AValue ALength Zeichen hat (0: mindestens eines) und alle
  die Ziffern 0 bis 9 sind (XPath '^[0-9]+$', mit fester Ziffernzahl). }
function LandrixEInvoiceIsDigits(const AValue: TLandrixEInvoiceString; ALength: Integer): Boolean;

{ XPath 'castable as xs:integer' of a value without blanks: an optional
  sign and at least one digit.
  DE: XPath 'castable as xs:integer' eines Werts ohne Leerraum: ein
  optionales Vorzeichen und mindestens eine Ziffer. }
function LandrixEInvoiceIsInteger(const AValue: TLandrixEInvoiceString): Boolean;

{ GS1 check digit (u:gln, GLN scheme 0088): the last digit checks the
  others weighted 3 and 1 from the right. AValue must consist of digits.
  DE: GS1-Pruefziffer (u:gln, GLN-Schema 0088): die letzte Ziffer prueft
  die uebrigen, von rechts mit 3 und 1 gewichtet. AValue muss aus Ziffern
  bestehen. }
function LandrixEInvoiceGS1CheckDigitValid(const AValue: TLandrixEInvoiceString): Boolean;

{ Modulus 11 (u:mod11, Norwegian organization number, scheme 0192):
  weights 2 to 7 from the right, the value is above 0. AValue must consist
  of digits.
  DE: Modulus 11 (u:mod11, norwegische Organisationsnummer, Schema 0192):
  Gewichte 2 bis 7 von rechts, der Wert ist groesser als 0. AValue muss aus
  Ziffern bestehen. }
function LandrixEInvoiceMod11Valid(const AValue: TLandrixEInvoiceString): Boolean;

{ Belgian enterprise number (u:mod97-0208, scheme 0208): digits 9 and 10
  are 97 minus the first eight modulo 97. AValue must be ten digits.
  DE: Belgische Unternehmensnummer (u:mod97-0208, Schema 0208): Ziffern 9
  und 10 sind 97 minus die ersten acht modulo 97. AValue muss aus zehn
  Ziffern bestehen. }
function LandrixEInvoiceBelgianEnterpriseValid(const AValue: TLandrixEInvoiceString): Boolean;

{ Italian IPA code (u:checkCodiceIPA, scheme 0201): six ASCII letters or
  digits.
  DE: Italienischer IPA-Code (u:checkCodiceIPA, Schema 0201): sechs
  ASCII-Buchstaben oder -Ziffern. }
function LandrixEInvoiceCodiceIPAValid(const AValue: TLandrixEInvoiceString): Boolean;

{ Italian tax code (u:checkCF, schemes 0210 and 9907): 16 characters in the
  pattern of a personal code (letters, numbers, letter, numbers, three
  characters, number, letter) or an integer of 11 characters.
  DE: Italienischer Steuercode (u:checkCF, Schemata 0210 und 9907): 16
  Zeichen im Muster eines Personencodes (Buchstaben, Zahlen, Buchstabe,
  Zahlen, drei Zeichen, Zahl, Buchstabe) oder eine Ganzzahl aus 11 Zeichen. }
function LandrixEInvoiceCodiceFiscaleValid(const AValue: TLandrixEInvoiceString): Boolean;

{ Italian VAT number (u:checkPIVAseIT, scheme 0211): with the prefix IT or
  it, the eleven digits after it pass the Luhn-like check of the Partita
  IVA; without that prefix the value passes.
  DE: Italienische USt-IdNr. (u:checkPIVAseIT, Schema 0211): mit dem
  Praefix IT oder it bestehen die elf Ziffern danach die Luhn-artige
  Pruefung der Partita IVA; ohne dieses Praefix gilt der Wert. }
function LandrixEInvoicePartitaIVAValid(const AValue: TLandrixEInvoiceString): Boolean;

{ Swedish organization number (PEPPOL-COMMON-R049, scheme 0007): ten
  digits, the last the Luhn check digit of the first nine.
  DE: Schwedische Organisationsnummer (PEPPOL-COMMON-R049, Schema 0007):
  zehn Ziffern, die letzte die Luhn-Pruefziffer der ersten neun. }
function LandrixEInvoiceSwedishOrgNumberValid(const AValue: TLandrixEInvoiceString): Boolean;

{ Australian Business Number (u:abn, scheme 0151): the weighted sum of the
  digits (the first minus 1) is divisible by 89. AValue must be eleven
  digits.
  DE: Australian Business Number (u:abn, Schema 0151): die gewichtete Summe
  der Ziffern (die erste minus 1) ist durch 89 teilbar. AValue muss aus elf
  Ziffern bestehen. }
function LandrixEInvoiceABNValid(const AValue: TLandrixEInvoiceString): Boolean;

{ Greek tax identification number (u:TinVerification): digit 9 is the sum
  of the first eight weighted 256 to 2, modulo 11, modulo 10. AValue must
  have at least nine digits.
  DE: Griechische Steuernummer (u:TinVerification): Ziffer 9 ist die Summe
  der ersten acht, gewichtet 256 bis 2, modulo 11, modulo 10. AValue muss
  mindestens neun Ziffern haben. }
function LandrixEInvoiceGreekTINValid(const AValue: TLandrixEInvoiceString): Boolean;

{ IBAN of KoSIT (xr:checkIBAN) for a value without blanks: two capital
  letters, two digits and up to 30 letters or digits (4 to 34 characters),
  and the check sum modulo 97 is 1 (letters as their code point - 55, lower
  case as well).
  DE: IBAN der KoSIT (xr:checkIBAN) fuer einen Wert ohne Leerraum: zwei
  Grossbuchstaben, zwei Ziffern und bis zu 30 Buchstaben oder Ziffern (4 bis
  34 Zeichen), und die Pruefsumme modulo 97 ist 1 (Buchstaben als Codepunkt
  - 55, auch Kleinbuchstaben). }
function LandrixEInvoiceIBANValid(const AValue: TLandrixEInvoiceString): Boolean;

{ BR-DE-27 (XRechnung) and DE-R-027 (Peppol): at least three digits.
  DE: BR-DE-27 (XRechnung) und DE-R-027 (Peppol): mindestens drei Ziffern. }
function LandrixEInvoiceTelephoneValid(const AValue: TLandrixEInvoiceString): Boolean;

{ BR-DE-28 and DE-R-028 (^[^@\s]+@([^@.\s]+\.)+[^@.\s]+$ on the normalized
  text): one @ after at least one character, no blank, a domain of at least
  two non-empty parts separated by dots.
  DE: BR-DE-28 und DE-R-028 (^[^@\s]+@([^@.\s]+\.)+[^@.\s]+$ auf dem
  normalisierten Text): ein @ nach mindestens einem Zeichen, kein Leerraum,
  eine Domain aus mindestens zwei nicht leeren, durch Punkte getrennten
  Teilen. }
function LandrixEInvoiceEmailValid(const AValue: TLandrixEInvoiceString): Boolean;

implementation

function IsBlankChar(C: TLandrixEInvoiceChar): Boolean;
begin
  Result := (C = #32) or (C = #9) or (C = #10) or (C = #13);
end;

function IsDigit(C: TLandrixEInvoiceChar): Boolean;
begin
  Result := (C >= '0') and (C <= '9');
end;

function IsLetter(C: TLandrixEInvoiceChar): Boolean;
begin
  Result := ((C >= 'A') and (C <= 'Z')) or ((C >= 'a') and (C <= 'z'));
end;

function DigitAt(const AValue: TLandrixEInvoiceString; AIndex: Integer): Integer;
begin
  Result := Ord(AValue[AIndex]) - Ord('0');
end;

function LandrixEInvoiceNormalizeSpace(const AValue: TLandrixEInvoiceString): TLandrixEInvoiceString;
var
  I: Integer;
  Pending: Boolean;
begin
  Result := '';
  Pending := False;
  for I := 1 to Length(AValue) do
    if IsBlankChar(AValue[I]) then
      Pending := Result <> ''
    else
    begin
      if Pending then
        Result := Result + ' ';
      Pending := False;
      Result := Result + AValue[I];
    end;
end;

function LandrixEInvoiceIsDigits(const AValue: TLandrixEInvoiceString; ALength: Integer): Boolean;
var
  I: Integer;
begin
  Result := False;
  if (Length(AValue) = 0) or ((ALength > 0) and (Length(AValue) <> ALength)) then
    Exit;
  for I := 1 to Length(AValue) do
    if not IsDigit(AValue[I]) then
      Exit;
  Result := True;
end;

function LandrixEInvoiceIsInteger(const AValue: TLandrixEInvoiceString): Boolean;
begin
  if (Length(AValue) > 1) and ((AValue[1] = '+') or (AValue[1] = '-')) then
    Result := LandrixEInvoiceIsDigits(Copy(AValue, 2, Length(AValue) - 1), 0)
  else
    Result := LandrixEInvoiceIsDigits(AValue, 0);
end;

function LandrixEInvoiceGS1CheckDigitValid(const AValue: TLandrixEInvoiceString): Boolean;
var
  I, Sum, Weight: Integer;
begin
  Result := False;
  if not LandrixEInvoiceIsDigits(AValue, 0) then
    Exit;
  Sum := 0;
  Weight := 3;
  for I := Length(AValue) - 1 downto 1 do
  begin
    Sum := (Sum + DigitAt(AValue, I) * Weight) mod 10;
    Weight := 4 - Weight;
  end;
  Result := (10 - Sum) mod 10 = DigitAt(AValue, Length(AValue));
end;

function LandrixEInvoiceMod11Valid(const AValue: TLandrixEInvoiceString): Boolean;
var
  I, Sum, Weight, NonZero: Integer;
begin
  Result := False;
  if not LandrixEInvoiceIsDigits(AValue, 0) then
    Exit;
  Sum := 0;
  Weight := 2;
  NonZero := DigitAt(AValue, Length(AValue));
  for I := Length(AValue) - 1 downto 1 do
  begin
    Sum := (Sum + DigitAt(AValue, I) * Weight) mod 11;
    Inc(NonZero, DigitAt(AValue, I));
    Inc(Weight);
    if Weight > 7 then
      Weight := 2;
  end;
  { number($val) > 0 }
  Result := (NonZero > 0) and ((11 - Sum) mod 11 = DigitAt(AValue, Length(AValue)));
end;

function LandrixEInvoiceBelgianEnterpriseValid(const AValue: TLandrixEInvoiceString): Boolean;
var
  I, Remainder: Integer;
begin
  Result := False;
  if not LandrixEInvoiceIsDigits(AValue, 10) then
    Exit;
  Remainder := 0;
  for I := 1 to 8 do
    Remainder := (Remainder * 10 + DigitAt(AValue, I)) mod 97;
  Result := 97 - Remainder = DigitAt(AValue, 9) * 10 + DigitAt(AValue, 10);
end;

function LandrixEInvoiceCodiceIPAValid(const AValue: TLandrixEInvoiceString): Boolean;
var
  I: Integer;
begin
  Result := False;
  if Length(AValue) <> 6 then
    Exit;
  for I := 1 to 6 do
    if not (IsLetter(AValue[I]) or IsDigit(AValue[I])) then
      Exit;
  Result := True;
end;

function Letters(const AValue: TLandrixEInvoiceString; AFrom, ACount: Integer): Boolean;
var
  I: Integer;
begin
  Result := False;
  for I := AFrom to AFrom + ACount - 1 do
    if not IsLetter(AValue[I]) then
      Exit;
  Result := True;
end;

function LandrixEInvoiceCodiceFiscaleValid(const AValue: TLandrixEInvoiceString): Boolean;
begin
  if Length(AValue) = 16 then
    Result := Letters(AValue, 1, 6) and LandrixEInvoiceIsInteger(Copy(AValue, 7, 2)) and Letters(AValue, 9, 1) and
      LandrixEInvoiceIsInteger(Copy(AValue, 10, 2)) and LandrixEInvoiceIsInteger(Copy(AValue, 15, 1)) and
      Letters(AValue, 16, 1)
  else
    Result := (Length(AValue) = 11) and LandrixEInvoiceIsInteger(AValue);
end;

function LandrixEInvoicePartitaIVAValid(const AValue: TLandrixEInvoiceString): Boolean;
const
  Doubled: array[0..9] of Integer = (0, 2, 4, 6, 8, 1, 3, 5, 7, 9);
var
  Code: TLandrixEInvoiceString;
  I, Sum: Integer;
begin
  Result := True;
  if (Copy(AValue, 1, 2) <> 'IT') and (Copy(AValue, 1, 2) <> 'it') then
    Exit;
  Code := Copy(AValue, 3, Length(AValue) - 2);
  { u:addPIVA reads the digits one by one; a sign is no digit }
  Result := LandrixEInvoiceIsDigits(Code, 11);
  if not Result then
    Exit;
  Sum := 0;
  for I := 1 to 11 do
    if Odd(I) then
      Inc(Sum, DigitAt(Code, I))
    else
      Inc(Sum, Doubled[DigitAt(Code, I)]);
  Result := Sum mod 10 = 0;
end;

function LandrixEInvoiceSwedishOrgNumberValid(const AValue: TLandrixEInvoiceString): Boolean;
var
  I, D, Sum: Integer;
begin
  Result := False;
  if not LandrixEInvoiceIsDigits(AValue, 10) then
    Exit;
  Sum := 0;
  for I := 1 to 9 do
  begin
    D := DigitAt(AValue, I);
    { position 10 - I from the right: odd positions are doubled }
    if Odd(10 - I) then
      Inc(Sum, (D * 2) mod 10 + (D * 2) div 10)
    else
      Inc(Sum, D);
  end;
  Result := (10 - Sum mod 10) mod 10 = DigitAt(AValue, 10);
end;

function LandrixEInvoiceABNValid(const AValue: TLandrixEInvoiceString): Boolean;
const
  Weights: array[1..11] of Integer = (10, 1, 3, 5, 7, 9, 11, 13, 15, 17, 19);
var
  I, Sum: Integer;
begin
  Result := False;
  if not LandrixEInvoiceIsDigits(AValue, 11) then
    Exit;
  Sum := (DigitAt(AValue, 1) - 1) * Weights[1];
  for I := 2 to 11 do
    Inc(Sum, DigitAt(AValue, I) * Weights[I]);
  Result := Sum mod 89 = 0;
end;

function LandrixEInvoiceGreekTINValid(const AValue: TLandrixEInvoiceString): Boolean;
var
  I, Sum, Weight: Integer;
begin
  Result := False;
  if (Length(AValue) < 9) or not LandrixEInvoiceIsDigits(Copy(AValue, 1, 9), 9) then
    Exit;
  Sum := 0;
  Weight := 256;
  for I := 1 to 8 do
  begin
    Inc(Sum, DigitAt(AValue, I) * Weight);
    Weight := Weight div 2;
  end;
  Result := (Sum mod 11) mod 10 = DigitAt(AValue, 9);
end;

function LandrixEInvoiceIBANValid(const AValue: TLandrixEInvoiceString): Boolean;
var
  Rearranged: TLandrixEInvoiceString;
  I, Value, Remainder: Integer;
  C: TLandrixEInvoiceChar;
begin
  Result := False;
  if (Length(AValue) < 4) or (Length(AValue) > 34) then
    Exit;
  for I := 1 to Length(AValue) do
  begin
    C := AValue[I];
    if I <= 2 then
    begin
      if (C < 'A') or (C > 'Z') then
        Exit;
    end
    else if I <= 4 then
    begin
      if not IsDigit(C) then
        Exit;
    end
    else if not (IsDigit(C) or IsLetter(C)) then
      Exit;
  end;
  Rearranged := Copy(AValue, 5, Length(AValue) - 4) + Copy(AValue, 1, 4);
  Remainder := 0;
  for I := 1 to Length(Rearranged) do
  begin
    Value := Ord(Rearranged[I]);
    if Value > 64 then
      Remainder := (Remainder * 100 + Value - 55) mod 97
    else
      Remainder := (Remainder * 10 + Value - 48) mod 97;
  end;
  Result := Remainder = 1;
end;

function LandrixEInvoiceTelephoneValid(const AValue: TLandrixEInvoiceString): Boolean;
var
  I, Digits: Integer;
begin
  Digits := 0;
  for I := 1 to Length(AValue) do
    if IsDigit(AValue[I]) then
      Inc(Digits);
  Result := Digits >= 3;
end;

function LandrixEInvoiceEmailValid(const AValue: TLandrixEInvoiceString): Boolean;
var
  S, Domain: TLandrixEInvoiceString;
  I, At: Integer;
begin
  Result := False;
  S := LandrixEInvoiceNormalizeSpace(AValue);
  for I := 1 to Length(S) do
    if IsBlankChar(S[I]) then
      Exit;
  At := Pos('@', S);
  if At <= 1 then
    Exit;
  Domain := Copy(S, At + 1, Length(S) - At);
  if (Pos('@', Domain) > 0) or (Pos('.', Domain) = 0) or (Pos('..', Domain) > 0) or (Domain[1] = '.') or
     (Domain[Length(Domain)] = '.') then
    Exit;
  Result := True;
end;

end.
