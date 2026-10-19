{
  EInvoice-for-Pascal

  Copyright (C) 2026 Landrix Software GmbH & Co. KG

  This file is dual-licensed under:
  - GNU GPL version 3 or later; or
  - the Landrix Software Commercial License.

  See LICENSE and COMMERCIAL-LICENSE.md.

  SPDX-License-Identifier: GPL-3.0-or-later OR LicenseRef-Landrix-Commercial
}

{ Conversion between the typed values of the invoice model and the lexical
  text of the syntax models. Independent of the locale (no
  DecimalSeparator, no date format settings); built on LandrixXmlConvert.
  Rounding is half away from zero.

  Writing uses fixed rules per business term, the same for every target
  specification:
  - amounts (e.g. BT-106 to BT-115, BT-131): exactly 2 decimals;
  - prices (BT-146, BT-148): 2 decimals if the value has no more,
    otherwise 4;
  - quantities (BT-129): exactly 4 decimals;
  - base quantities (BT-149): up to 6 decimals, trailing zeros removed
    down to 2 (0.001 stays 0.001);
  - percentages (BT-96, BT-119, BT-152): exactly 2 decimals;
  - dates: UBL xs:date YYYY-MM-DD, CII format 102 YYYYMMDD.
  The decimal limits of EN 16931 (BR-DEC) are checked per business term by
  the specification rules, not here.

  Reading uses the Try functions: they return False for text that is not a
  valid value of the type (no locale forms such as '19,00', no exponent,
  full calendar check) and leave the result 0. They never guess.

  DE: Umwandlung zwischen den typisierten Werten des Rechnungsmodells und
  dem lexikalischen Text der Syntaxmodelle. Unabhaengig vom Gebietsschema
  (kein DecimalSeparator, keine Datumsformat-Einstellungen); aufgebaut auf
  LandrixXmlConvert. Gerundet wird kaufmaennisch (halb weg von null).

  Beim Schreiben gelten feste Regeln je Geschaeftsbegriff, fuer jede
  Zielspezifikation gleich:
  - Betraege (z. B. BT-106 bis BT-115, BT-131): genau 2 Nachkommastellen;
  - Preise (BT-146, BT-148): 2 Nachkommastellen, wenn der Wert nicht mehr
    hat, sonst 4;
  - Mengen (BT-129): genau 4 Nachkommastellen;
  - Basismengen (BT-149): bis zu 6 Nachkommastellen, Nullen am Ende bis auf
    2 gestrichen (0.001 bleibt 0.001);
  - Prozentsaetze (BT-96, BT-119, BT-152): genau 2 Nachkommastellen;
  - Datumswerte: UBL xs:date JJJJ-MM-TT, CII Format 102 JJJJMMTT.
  Die Stellengrenzen der EN 16931 (BR-DEC) prueft das Regelwerk der
  Zielspezifikation je Geschaeftsbegriff, nicht diese Unit.

  Gelesen wird mit den Try-Funktionen: Sie liefern False fuer Text, der kein
  gueltiger Wert des Typs ist (keine Gebietsschema-Formen wie '19,00', kein
  Exponent, volle Kalenderpruefung), und lassen das Ergebnis 0. Sie raten
  nie. }

unit LandrixEInvoiceLexical;

{$I LandrixEInvoice.inc}

interface

uses
  LandrixEInvoiceTypes;

{ Amount with exactly 2 decimals, e.g. 100 -> '100.00'.
  DE: Betrag mit genau 2 Nachkommastellen, z. B. 100 -> '100.00'. }
function LandrixEInvoiceAmountToLexical(AValue: Currency): TLandrixEInvoiceString;

{ Price with 2 decimals if it has no more, 4 if it has 3 or 4, otherwise as
  many as it needs (up to 10, 15 significant digits), e.g. 4.1 -> '4.10',
  4.1235 -> '4.1235', 4.125 -> '4.1250', 0.01146 -> '0.01146'.
  DE: Preis mit 2 Nachkommastellen, wenn er nicht mehr hat, 4 bei 3 oder 4,
  sonst so vielen, wie er braucht (bis 10, 15 signifikante Stellen), z. B.
  4.1 -> '4.10', 4.1235 -> '4.1235', 4.125 -> '4.1250', 0.01146 ->
  '0.01146'. }
function LandrixEInvoicePriceToLexical(AValue: Double): TLandrixEInvoiceString;

{ Quantity with exactly 4 decimals, e.g. 1 -> '1.0000'.
  DE: Menge mit genau 4 Nachkommastellen, z. B. 1 -> '1.0000'. }
function LandrixEInvoiceQuantityToLexical(AValue: Double): TLandrixEInvoiceString;

{ Base quantity with up to 6 decimals and at least 2, e.g. 1 -> '1.00',
  0.001 -> '0.001'.
  DE: Basismenge mit bis zu 6 und mindestens 2 Nachkommastellen, z. B.
  1 -> '1.00', 0.001 -> '0.001'. }
function LandrixEInvoiceBaseQuantityToLexical(AValue: Double): TLandrixEInvoiceString;

{ Percentage with exactly 2 decimals, e.g. 19 -> '19.00'.
  DE: Prozentsatz mit genau 2 Nachkommastellen, z. B. 19 -> '19.00'. }
function LandrixEInvoicePercentToLexical(AValue: Double): TLandrixEInvoiceString;

{ Decimal number with exactly ADecimals (0..18) decimals, for values
  without a business rule of their own (e.g. a multiplier factor).
  DE: Dezimalzahl mit genau ADecimals (0..18) Nachkommastellen, fuer Werte
  ohne eigene Fachregel (z. B. ein Multiplikationsfaktor). }
function LandrixEInvoiceDecimalToLexical(AValue: Double; ADecimals: Integer): TLandrixEInvoiceString;

{ Date as UBL xs:date (YYYY-MM-DD); the time of day is ignored.
  DE: Datum als UBL xs:date (JJJJ-MM-TT); die Uhrzeit wird ignoriert. }
function LandrixEInvoiceDateToUBL(AValue: TDateTime): TLandrixEInvoiceString;

{ Date as CII format 102 (YYYYMMDD); the time of day is ignored.
  DE: Datum als CII-Format 102 (JJJJMMTT); die Uhrzeit wird ignoriert. }
function LandrixEInvoiceDateToCII(AValue: TDateTime): TLandrixEInvoiceString;

{ Reads an xs:decimal into Currency. ARounded is True if the text had more
  than 4 decimals and was rounded (the result is then still valid). False
  for text that is no decimal or out of range.
  DE: Liest ein xs:decimal in Currency. ARounded ist True, wenn der Text
  mehr als 4 Nachkommastellen hatte und gerundet wurde (das Ergebnis ist
  dann trotzdem gueltig). False fuer Text, der keine Dezimalzahl ist oder
  ausserhalb des Bereichs liegt. }
function LandrixEInvoiceTryLexicalToCurrency(const AText: TLandrixEInvoiceString;
  out AValue: Currency; out ARounded: Boolean): Boolean;

{ Reads an xs:decimal into Double. False for text that is no decimal.
  DE: Liest ein xs:decimal in Double. False fuer Text, der keine
  Dezimalzahl ist. }
function LandrixEInvoiceTryLexicalToDouble(const AText: TLandrixEInvoiceString;
  out AValue: Double): Boolean;

{ Reads a UBL xs:date; a time zone suffix is accepted and dropped. False for
  text that is no valid date.
  DE: Liest ein UBL-xs:date; eine Zeitzonenangabe wird akzeptiert und
  verworfen. False fuer Text, der kein gueltiges Datum ist. }
function LandrixEInvoiceTryUBLToDate(const AText: TLandrixEInvoiceString;
  out AValue: TDateTime): Boolean;

{ Reads a CII date of format 102 (AFormat '102' or ''). False for other
  formats and for text that is no valid date.
  DE: Liest ein CII-Datum im Format 102 (AFormat '102' oder ''). False fuer
  andere Formate und fuer Text, der kein gueltiges Datum ist. }
function LandrixEInvoiceTryCIIToDate(const AText, AFormat: TLandrixEInvoiceString;
  out AValue: TDateTime): Boolean;

implementation

uses
  LandrixXmlBase,
  LandrixXmlConvert;

function Text(const S: TLandrixXmlUtf8): TLandrixEInvoiceString;
begin
  Result := LandrixEInvoiceUtf8ToString(S);
end;

function Utf8(const S: TLandrixEInvoiceString): TLandrixXmlUtf8;
begin
  Result := LandrixEInvoiceStringToUtf8(S);
end;

function LandrixEInvoiceAmountToLexical(AValue: Currency): TLandrixEInvoiceString;
begin
  Result := Text(LandrixXmlFormatCurrency(AValue, 2));
end;

function LandrixEInvoicePriceToLexical(AValue: Double): TLandrixEInvoiceString;
var
  P: Integer;
begin
  Result := Text(LandrixXmlFormatDoubleTrim(AValue, 2, 10));
  { 3 decimals are written as 4, as before }
  P := Pos('.', Result);
  if (P > 0) and (Length(Result) - P = 3) then
    Result := Result + '0';
end;

function LandrixEInvoiceQuantityToLexical(AValue: Double): TLandrixEInvoiceString;
begin
  Result := Text(LandrixXmlFormatDouble(AValue, 4));
end;

function LandrixEInvoiceBaseQuantityToLexical(AValue: Double): TLandrixEInvoiceString;
begin
  Result := Text(LandrixXmlFormatDoubleTrim(AValue, 2, 6));
end;

function LandrixEInvoicePercentToLexical(AValue: Double): TLandrixEInvoiceString;
begin
  Result := Text(LandrixXmlFormatDouble(AValue, 2));
end;

function LandrixEInvoiceDecimalToLexical(AValue: Double; ADecimals: Integer): TLandrixEInvoiceString;
begin
  Result := Text(LandrixXmlFormatDouble(AValue, ADecimals));
end;

function LandrixEInvoiceDateToUBL(AValue: TDateTime): TLandrixEInvoiceString;
begin
  Result := Text(LandrixXmlFormatDate(AValue));
end;

function LandrixEInvoiceDateToCII(AValue: TDateTime): TLandrixEInvoiceString;
begin
  Result := Text(LandrixXmlFormatCiiDate(AValue, 102));
end;

function LandrixEInvoiceTryLexicalToCurrency(const AText: TLandrixEInvoiceString;
  out AValue: Currency; out ARounded: Boolean): Boolean;
var
  S: TLandrixXmlUtf8;
begin
  ARounded := False;
  S := Utf8(AText);
  Result := LandrixXmlTryParseCurrency(S, AValue, False);
  if not Result then
  begin
    Result := LandrixXmlTryParseCurrency(S, AValue, True);
    ARounded := Result;
  end;
  if not Result then
    AValue := 0;
end;

function LandrixEInvoiceTryLexicalToDouble(const AText: TLandrixEInvoiceString;
  out AValue: Double): Boolean;
begin
  Result := LandrixXmlTryParseDouble(Utf8(AText), AValue);
  if not Result then
    AValue := 0;
end;

function LandrixEInvoiceTryUBLToDate(const AText: TLandrixEInvoiceString;
  out AValue: TDateTime): Boolean;
begin
  Result := LandrixXmlTryParseDate(Utf8(AText), AValue);
  if not Result then
    AValue := 0;
end;

function LandrixEInvoiceTryCIIToDate(const AText, AFormat: TLandrixEInvoiceString;
  out AValue: TDateTime): Boolean;
begin
  Result := ((AFormat = '') or (AFormat = '102')) and
    LandrixXmlTryParseCiiDate(Utf8(AText), AValue);
  if not Result then
    AValue := 0;
end;

end.
