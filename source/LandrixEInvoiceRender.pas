{
  EInvoice-for-Pascal

  Copyright (C) 2026 Landrix Software GmbH & Co. KG

  This file is dual-licensed under:
  - GNU GPL version 3 or later; or
  - the Landrix Software Commercial License.

  See LICENSE and COMMERCIAL-LICENSE.md.

  SPDX-License-Identifier: GPL-3.0-or-later OR LicenseRef-Landrix-Commercial
}

{ What every rendering of an invoice shares: values as people read them in
  English or German. Numbers are shown as stored, never recomputed: amounts
  with at least two and at most the four stored decimals, other numbers
  with as many decimals as they have; the currency is shown by its code
  (no symbol). Dates are DD.MM.YYYY in German and YYYY-MM-DD in English
  (unambiguous everywhere). The sections of the page, the labels and the
  business terms come from LandrixEInvoiceRenderLabels, the names of codes
  from LandrixEInvoiceCodeNames.
  DE: Was jede Darstellung einer Rechnung gemeinsam nutzt: Werte so, wie
  Menschen sie englisch oder deutsch lesen. Zahlen erscheinen wie
  gespeichert, nie neu gerechnet: Betraege mit mindestens zwei und
  hoechstens den vier gespeicherten Nachkommastellen, andere Zahlen mit so
  vielen Nachkommastellen, wie sie haben; die Waehrung steht als Code (kein
  Symbol). Datumswerte deutsch TT.MM.JJJJ, englisch JJJJ-MM-TT (ueberall
  eindeutig). Abschnitte der Seite, Beschriftungen und Geschaeftsbegriffe
  kommen aus LandrixEInvoiceRenderLabels, die Namen der Codes aus
  LandrixEInvoiceCodeNames. }

{ API: internal. May change in any release; use the facade LandrixEInvoice
  or the stable units instead.
  DE: API: intern. Kann sich in jeder Version aendern; stattdessen die
  Fassade LandrixEInvoice oder die stabilen Units verwenden. }

unit LandrixEInvoiceRender;

{$I LandrixEInvoice.inc}

interface

uses
  LandrixEInvoiceTypes,
  LandrixEInvoiceReportHtml,
  LandrixEInvoiceCodeNames;

{ An amount with at least two and at most four decimals (trailing zeros
  beyond two dropped) and grouped thousands: 1.234,50 in German, 1,234.50 in
  English. Without the currency.
  DE: Ein Betrag mit mindestens zwei und hoechstens vier Nachkommastellen
  (Nullen am Ende ueber zwei hinaus entfallen) und gruppierten Tausendern:
  deutsch 1.234,50, englisch 1,234.50. Ohne Waehrung. }
function LandrixEInvoiceRenderAmount(AValue: Currency;
  ALanguage: TLandrixEInvoiceReportLanguage): TLandrixEInvoiceString;

{ A decimal number with at least AMinDecimals (0..18) and at most 18
  decimals, as short as the stored value allows (15 significant digits),
  grouped like an amount; '?' for a value that has no such form (NaN,
  infinite, 1e23 and above, or not 0 but below 1e-18), never a rounded 0.
  DE: Eine Dezimalzahl mit mindestens AMinDecimals (0..18) und hoechstens 18
  Nachkommastellen, so kurz, wie der gespeicherte Wert es erlaubt (15
  signifikante Stellen), gruppiert wie ein Betrag; '?' fuer einen Wert ohne
  solche Form (NaN, unendlich, ab 1e23 oder ungleich 0, aber unter 1e-18),
  nie eine gerundete 0. }
function LandrixEInvoiceRenderDecimal(AValue: Double; AMinDecimals: Integer;
  ALanguage: TLandrixEInvoiceReportLanguage): TLandrixEInvoiceString;

{ A percentage as a decimal number with its sign: 19 % in German, 19% in
  English.
  DE: Ein Prozentsatz als Dezimalzahl mit Zeichen: deutsch 19 %, englisch
  19%. }
function LandrixEInvoiceRenderPercent(AValue: Double;
  ALanguage: TLandrixEInvoiceReportLanguage): TLandrixEInvoiceString;

{ A date: DD.MM.YYYY in German, YYYY-MM-DD in English; the time of day is
  not shown. '?' for a value outside the years 1 to 9999.
  DE: Ein Datum: deutsch TT.MM.JJJJ, englisch JJJJ-MM-TT; die Uhrzeit
  erscheint nicht. '?' fuer einen Wert ausserhalb der Jahre 1 bis 9999. }
function LandrixEInvoiceRenderDate(AValue: TDateTime;
  ALanguage: TLandrixEInvoiceReportLanguage): TLandrixEInvoiceString;

{ A code with its name: 'name (code)' when AList knows the code, the code
  alone otherwise; '' for ''.
  DE: Ein Code mit seinem Namen: 'Name (Code)', wenn AList den Code kennt,
  sonst der Code allein; '' fuer ''. }
function LandrixEInvoiceRenderCode(AList: TLandrixEInvoiceCodeList; const ACode: TLandrixEInvoiceString;
  ALanguage: TLandrixEInvoiceReportLanguage): TLandrixEInvoiceString;

implementation

uses
  SysUtils,
  LandrixXmlBase,
  LandrixXmlConvert;

{ AText as a canonical decimal (optional '-', digits, optional '.' and
  digits) with the separators of ALanguage and grouped thousands }
function Localized(const AText: TLandrixXmlUtf8; ALanguage: TLandrixEInvoiceReportLanguage): TLandrixEInvoiceString;
var
  IntPart, Frac: TLandrixXmlUtf8;
  Negative: Boolean;
  Group, Decimal: WideChar;
  P, I, N: Integer;
begin
  IntPart := AText;
  Negative := (IntPart <> '') and (IntPart[1] = '-');
  if Negative then
    Delete(IntPart, 1, 1);
  Frac := '';
  P := Pos(TLandrixXmlUtf8('.'), IntPart);
  if P > 0 then
  begin
    Frac := Copy(IntPart, P + 1, MaxInt);
    IntPart := Copy(IntPart, 1, P - 1);
  end;
  if ALanguage = eln_German then
  begin
    Group := '.';
    Decimal := ',';
  end
  else
  begin
    Group := ',';
    Decimal := '.';
  end;
  if Negative then
    Result := '-'
  else
    Result := '';
  N := Length(IntPart);
  for I := 1 to N do
  begin
    Result := Result + WideChar(Ord(IntPart[I]));
    if (I < N) and ((N - I) mod 3 = 0) then
      Result := Result + Group;
  end;
  if Frac <> '' then
  begin
    Result := Result + Decimal;
    for I := 1 to Length(Frac) do
      Result := Result + WideChar(Ord(Frac[I]));
  end;
end;

function LandrixEInvoiceRenderAmount(AValue: Currency;
  ALanguage: TLandrixEInvoiceReportLanguage): TLandrixEInvoiceString;
begin
  Result := Localized(LandrixXmlFormatCurrencyTrim(AValue, 2, 4), ALanguage);
end;

function LandrixEInvoiceRenderDecimal(AValue: Double; AMinDecimals: Integer;
  ALanguage: TLandrixEInvoiceReportLanguage): TLandrixEInvoiceString;
var
  S: TLandrixXmlUtf8;
  I: Integer;
  Zero: Boolean;
begin
  try
    S := LandrixXmlFormatDoubleTrim(AValue, AMinDecimals, 18);
  except
    on Exception do
      S := '';
  end;
  { a value too small for 18 decimals would show as 0
    DE: ein Wert, zu klein fuer 18 Nachkommastellen, erschiene als 0 }
  Zero := True;
  for I := 1 to Length(S) do
    if (S[I] >= '1') and (S[I] <= '9') then
      Zero := False;
  if Zero and (AValue <> 0) then
    S := '';
  if S = '' then
    Result := '?'
  else
    Result := Localized(S, ALanguage);
end;

function LandrixEInvoiceRenderPercent(AValue: Double;
  ALanguage: TLandrixEInvoiceReportLanguage): TLandrixEInvoiceString;
begin
  Result := LandrixEInvoiceRenderDecimal(AValue, 0, ALanguage);
  if ALanguage = eln_German then
    Result := Result + ' %'
  else
    Result := Result + '%';
end;

function Digits(AValue, ACount: Integer): TLandrixEInvoiceString;
begin
  Result := TLandrixEInvoiceString(IntToStr(AValue));
  while Length(Result) < ACount do
    Result := '0' + Result;
end;

function LandrixEInvoiceRenderDate(AValue: TDateTime;
  ALanguage: TLandrixEInvoiceReportLanguage): TLandrixEInvoiceString;
var
  Y, M, D: Word;
begin
  { -693593 is 0001-01-01, 2958465 is 9999-12-31; NaN fails both tests }
  if not ((AValue >= -693593) and (AValue < 2958466)) then
  begin
    Result := '?';
    Exit;
  end;
  DecodeDate(AValue, Y, M, D);
  if ALanguage = eln_German then
    Result := Digits(D, 2) + '.' + Digits(M, 2) + '.' + Digits(Y, 4)
  else
    Result := Digits(Y, 4) + '-' + Digits(M, 2) + '-' + Digits(D, 2);
end;

function LandrixEInvoiceRenderCode(AList: TLandrixEInvoiceCodeList; const ACode: TLandrixEInvoiceString;
  ALanguage: TLandrixEInvoiceReportLanguage): TLandrixEInvoiceString;
var
  Name: TLandrixEInvoiceString;
begin
  Result := ACode;
  if ACode = '' then
    Exit;
  Name := LandrixEInvoiceCodeName(AList, ACode, ALanguage);
  if Name <> '' then
    Result := Name + ' (' + ACode + ')';
end;

end.
