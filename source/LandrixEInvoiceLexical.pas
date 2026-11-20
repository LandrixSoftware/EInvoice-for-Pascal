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
  - quantities (BT-129): at least 4 decimals, more when the value has
    them (up to 10), e.g. 1.23456 stays 1.23456;
  - base quantities (BT-149): up to 6 decimals, trailing zeros removed
    down to 2 (0.001 stays 0.001);
  - percentages (BT-96, BT-119, BT-152): at least 2 decimals, more only
    when needed (up to 4);
  - dates: UBL xs:date YYYY-MM-DD, CII format 102 YYYYMMDD.
  These forms always meet the decimal limits of EN 16931 (BR-DEC) for the
  written document; the rule check does not test them (a document as read
  may break them, the validator judges that), except BR-DEC-15.

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
  - Mengen (BT-129): mindestens 4 Nachkommastellen, mehr, wenn der Wert
    sie hat (bis 10), z. B. bleibt 1.23456 1.23456;
  - Basismengen (BT-149): bis zu 6 Nachkommastellen, Nullen am Ende bis auf
    2 gestrichen (0.001 bleibt 0.001);
  - Prozentsaetze (BT-96, BT-119, BT-152): mindestens 2 Nachkommastellen,
    mehr nur bei Bedarf (bis 4);
  - Datumswerte: UBL xs:date JJJJ-MM-TT, CII Format 102 JJJJMMTT.
  Diese Formen halten die Stellengrenzen der EN 16931 (BR-DEC) fuer das
  geschriebene Dokument immer ein; die Regelpruefung testet sie nicht (ein
  gelesenes Dokument kann sie verletzen, das beurteilt der Validator),
  ausser BR-DEC-15.

  Gelesen wird mit den Try-Funktionen: Sie liefern False fuer Text, der kein
  gueltiger Wert des Typs ist (keine Gebietsschema-Formen wie '19,00', kein
  Exponent, volle Kalenderpruefung), und lassen das Ergebnis 0. Sie raten
  nie. }

{ API: internal. May change in any release; use the facade LandrixEInvoice
  or the stable units instead.
  DE: API: intern. Kann sich in jeder Version aendern; stattdessen die
  Fassade LandrixEInvoice oder die stabilen Units verwenden. }

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

{ Quantity with at least 4 decimals and up to 10, trailing zeros removed
  down to 4, e.g. 1 -> '1.0000', 1.23456 -> '1.23456', 1/3 ->
  '0.3333333333'.
  DE: Menge mit mindestens 4 und bis zu 10 Nachkommastellen, Nullen am
  Ende bis auf 4 gestrichen, z. B. 1 -> '1.0000', 1.23456 -> '1.23456',
  1/3 -> '0.3333333333'. }
function LandrixEInvoiceQuantityToLexical(AValue: Double): TLandrixEInvoiceString;

{ Base quantity with up to 6 decimals and at least 2, e.g. 1 -> '1.00',
  0.001 -> '0.001'.
  DE: Basismenge mit bis zu 6 und mindestens 2 Nachkommastellen, z. B.
  1 -> '1.00', 0.001 -> '0.001'. }
function LandrixEInvoiceBaseQuantityToLexical(AValue: Double): TLandrixEInvoiceString;

{ Percentage with at least 2 decimals and up to 4, trailing zeros removed
  down to 2, e.g. 19 -> '19.00', 7.126 -> '7.126'.
  DE: Prozentsatz mit mindestens 2 und bis zu 4 Nachkommastellen, Nullen am
  Ende bis auf 2 gestrichen, z. B. 19 -> '19.00', 7.126 -> '7.126'. }
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

{ Reads an xs:boolean ('true', 'false', '1', '0'); white space around the
  value is ignored (whiteSpace collapse). False, with AValue False, for any
  other text.
  DE: Liest ein xs:boolean ('true', 'false', '1', '0'); Leerraum um den Wert
  wird ignoriert (whiteSpace collapse). False, mit AValue False, fuer jeden
  anderen Text. }
function LandrixEInvoiceTryLexicalToBoolean(const AText: TLandrixEInvoiceString;
  out AValue: Boolean): Boolean;

{ True if AText is empty or consists of XML white space only (blank, tab,
  CR, LF), i.e. normalize-space(AText) = '' as in the Schematron rules. Such
  a value counts as absent: it is not written and fails a required check.
  DE: True, wenn AText leer ist oder nur aus XML-Leerraum besteht
  (Leerzeichen, Tab, CR, LF), also normalize-space(AText) = '' wie in den
  Schematron-Regeln. Ein solcher Wert gilt als nicht vorhanden: er wird nicht
  geschrieben und scheitert an einer Pflichtpruefung. }
function LandrixEInvoiceIsBlank(const AText: TLandrixEInvoiceString): Boolean;

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
  Result := Text(LandrixXmlFormatDoubleTrim(AValue, 4, 10));
end;

function LandrixEInvoiceBaseQuantityToLexical(AValue: Double): TLandrixEInvoiceString;
begin
  Result := Text(LandrixXmlFormatDoubleTrim(AValue, 2, 6));
end;

function LandrixEInvoicePercentToLexical(AValue: Double): TLandrixEInvoiceString;
begin
  Result := Text(LandrixXmlFormatDoubleTrim(AValue, 2, 4));
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

function IsXmlSpace(C: WideChar): Boolean;
begin
  Result := (C = ' ') or (C = #9) or (C = #10) or (C = #13);
end;

function LandrixEInvoiceTryLexicalToBoolean(const AText: TLandrixEInvoiceString;
  out AValue: Boolean): Boolean;
var
  First, Last: Integer;
  S: TLandrixEInvoiceString;
begin
  First := 1;
  Last := Length(AText);
  while (First <= Last) and IsXmlSpace(AText[First]) do
    Inc(First);
  while (Last >= First) and IsXmlSpace(AText[Last]) do
    Dec(Last);
  S := Copy(AText, First, Last - First + 1);
  AValue := (S = 'true') or (S = '1');
  Result := AValue or (S = 'false') or (S = '0');
end;

function LandrixEInvoiceIsBlank(const AText: TLandrixEInvoiceString): Boolean;
var
  I: Integer;
begin
  Result := False;
  for I := 1 to Length(AText) do
    if (AText[I] <> ' ') and (AText[I] <> #9) and (AText[I] <> #10) and (AText[I] <> #13) then
      Exit;
  Result := True;
end;

end.
