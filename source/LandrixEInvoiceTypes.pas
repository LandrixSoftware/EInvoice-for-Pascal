{
  EInvoice-for-Pascal

  Copyright (C) 2026 Landrix Software GmbH & Co. KG

  This file is dual-licensed under:
  - GNU GPL version 3 or later; or
  - the Landrix Software Commercial License.

  See LICENSE and COMMERCIAL-LICENSE.md.

  SPDX-License-Identifier: GPL-3.0-or-later OR LicenseRef-Landrix-Commercial
}

{ Basic types shared by all units: the library version, the string and
  character type of the invoice model, the conversion between that string
  type and UTF-8, the exception base class ELandrixEInvoiceError and the
  optional value types TLandrixEInvoiceAmount, ...Date, ...Quantity,
  ...Percent, ...Integer and ...Boolean.

  DE: Grundtypen fuer alle Units: Bibliotheksversion, Zeichenketten- und
  Zeichentyp des Rechnungsmodells, Umwandlung dieses Zeichenkettentyps von
  und nach UTF-8, die Basisklasse ELandrixEInvoiceError fuer Ausnahmen und
  die optionalen Werttypen TLandrixEInvoiceAmount, ...Date, ...Quantity,
  ...Percent, ...Integer und ...Boolean.

  String type
  -----------
  TLandrixEInvoiceString  Text of the invoice model.
                          Delphi 6-2007: WideString (UTF-16, lossless).
                          Delphi 2009+:  string = UnicodeString (lossless).
                          FPC:           string (AnsiString with code page);
                                         lossless when the code page is
                                         UTF-8, otherwise converted to the
                                         system code page by the RTL. On
                                         Unix the application must use the
                                         cwstring unit, else the RTL has no
                                         wide string manager and characters
                                         outside Latin-1 become '?'.
                          On every Delphi it is the same type as
                          TLandrixXmlWide.
  TLandrixEInvoiceChar    One code unit of TLandrixEInvoiceString (WideChar
                          on Delphi, Char on FPC). Not necessarily a complete
                          character: a UTF-16 surrogate or one UTF-8 byte.

  On Delphi 6-2007 assigning a TLandrixEInvoiceString to a plain string (or
  passing it to SysUtils routines that take string) converts it to the system
  code page and loses characters that code page cannot represent.

  DE: Zeichenkettentyp
  TLandrixEInvoiceString ist der Text des Rechnungsmodells: unter Delphi 6
  bis 2007 WideString (UTF-16, verlustfrei), ab Delphi 2009 string =
  UnicodeString (verlustfrei), unter FPC string (AnsiString mit Codepage;
  verlustfrei bei UTF-8 als Codepage, sonst wandelt die RTL in die
  Systemcodepage um). Unter Unix muss die Anwendung die Unit cwstring
  einbinden, sonst fehlt der RTL der Wide-String-Manager und Zeichen
  ausserhalb von Latin-1 werden zu '?'. Unter jedem Delphi ist es derselbe
  Typ wie TLandrixXmlWide. TLandrixEInvoiceChar ist eine Codeeinheit davon
  (WideChar unter Delphi, Char unter FPC), nicht unbedingt ein ganzes
  Zeichen. Unter Delphi 6 bis 2007 verliert die Zuweisung an einen normalen
  string (auch die Uebergabe an SysUtils-Routinen mit string-Parametern)
  alle Zeichen, die die Systemcodepage nicht darstellen kann. }

unit LandrixEInvoiceTypes;

{$I LandrixEInvoice.inc}

interface

uses
  SysUtils,
  LandrixXmlBase;

const
  { Library version (Semantic Versioning).
    DE: Version der Bibliothek (Semantic Versioning). }
  LandrixEInvoiceVersion = '0.1.0';

type
{$IFDEF FPC}
  TLandrixEInvoiceString = string;
  TLandrixEInvoiceChar = Char;
{$ELSE}
  {$IFDEF LANDRIXEINVOICE_UNICODE}
  TLandrixEInvoiceString = string;
  TLandrixEInvoiceChar = Char;
  {$ELSE}
  TLandrixEInvoiceString = WideString;
  TLandrixEInvoiceChar = WideChar;
  {$ENDIF}
{$ENDIF}

  { Base class of the library's own exceptions (conversion errors from
    LandrixXml keep their class ELandrixXmlError).
    DE: Basisklasse der eigenen Ausnahmen der Bibliothek (Umwandlungsfehler
    aus LandrixXml behalten ihre Klasse ELandrixXmlError). }
  ELandrixEInvoiceError = class(Exception);

  { Optional values
    ---------------
    A value that may be absent, so that "not set" differs from an explicit
    0, 0.0 or False (e.g. an explicit zero amount). Old-style objects
    without constructors and virtual methods: they have no VMT, so a field of
    a class starts zeroed, which is "not set".
    Methods: SetValue sets the value, Clear removes it, HasValue tells
    whether a value is set, Value returns it, ValueOr returns it or the
    given default, Equals compares two optional values.
    Rules:
    - Local variables are not initialised by the compiler: call Clear (or
      assign LandrixEInvoiceNo...) before reading them.
    - Use them as public fields or as properties that read the field
      directly. Behind a getter method, X.Prop.SetValue(...) would change a
      temporary copy.
    - Value raises ELandrixEInvoiceError when no value is set; ValueOr
      returns the given default instead.
    - Equals: two unset values are equal, unset differs from every value.
      Quantity and Percent compare with a relative tolerance of 1e-12
      (absolute 1e-12 for values below 1). Infinity and NaN are not
      supported values (they do not occur in XML decimals).
    - None of these objects is exactly 8 bytes: Delphi 13 Win64 passes
      8-byte objects wrongly as value or const parameters (records are not
      affected). New types must keep this rule; a test checks it.
    - Never stream them as raw memory: the layout differs between compilers.
    Code lists use a leading "not set" member in their enumeration instead.

    DE: Optionale Werte
    Ein Wert, der fehlen darf, damit sich "nicht gesetzt" von einer
    ausdruecklichen 0, 0.0 oder False unterscheidet (z. B. ein ausdruecklicher
    Nullbetrag). Alte object-Typen ohne Konstruktoren und virtuelle Methoden:
    Sie haben keine VMT, daher beginnt ein Feld einer Klasse genullt, also
    "nicht gesetzt".
    Methoden: SetValue setzt den Wert, Clear entfernt ihn, HasValue sagt, ob
    ein Wert gesetzt ist, Value liefert ihn, ValueOr liefert ihn oder den
    angegebenen Ersatzwert, Equals vergleicht zwei optionale Werte.
    Regeln:
    - Lokale Variablen initialisiert der Compiler nicht: vor dem Lesen Clear
      aufrufen (oder LandrixEInvoiceNo... zuweisen).
    - Als oeffentliche Felder verwenden oder als Properties, die direkt das
      Feld lesen. Hinter einer Getter-Methode wuerde X.Prop.SetValue(...) nur
      eine temporaere Kopie aendern.
    - Value loest ELandrixEInvoiceError aus, wenn kein Wert gesetzt ist;
      ValueOr liefert stattdessen den Ersatzwert.
    - Equals: zwei leere Werte sind gleich, leer unterscheidet sich von jedem
      Wert. Quantity und Percent vergleichen mit einer relativen Toleranz von
      1e-12 (absolut 1e-12 fuer Werte unter 1). Unendlich und NaN sind keine
      zulaessigen Werte (in XML-Dezimalzahlen kommen sie nicht vor).
    - Keines dieser Objekte ist genau 8 Byte gross: Delphi 13 Win64 uebergibt
      8-Byte-Objekte als Wert- oder const-Parameter falsch (Records sind
      nicht betroffen). Neue Typen muessen das einhalten; ein Test prueft es.
    - Nie als rohen Speicher speichern oder uebertragen: Das Layout
      unterscheidet sich zwischen den Compilern.
    Codelisten verwenden stattdessen ein erstes Aufzaehlungselement
    "nicht gesetzt". }

  { Optional monetary amount (Currency, four decimals).
    DE: Optionaler Geldbetrag (Currency, vier Nachkommastellen). }
  TLandrixEInvoiceAmount = object
  private
    FValue: Currency;
    FHasValue: Boolean;
  public
    procedure SetValue(AValue: Currency);
    procedure Clear;
    function HasValue: Boolean;
    function Value: Currency;
    function ValueOr(ADefault: Currency): Currency;
    function Equals(const AOther: TLandrixEInvoiceAmount): Boolean;
  end;

  { Optional date (TDateTime; stored as given, including a time part).
    DE: Optionales Datum (TDateTime; wird unveraendert gespeichert, auch mit
    Uhrzeitanteil). }
  TLandrixEInvoiceDate = object
  private
    FValue: TDateTime;
    FHasValue: Boolean;
  public
    procedure SetValue(AValue: TDateTime);
    procedure Clear;
    function HasValue: Boolean;
    function Value: TDateTime;
    function ValueOr(ADefault: TDateTime): TDateTime;
    function Equals(const AOther: TLandrixEInvoiceDate): Boolean;
  end;

  { Optional quantity (Double).
    DE: Optionale Menge (Double). }
  TLandrixEInvoiceQuantity = object
  private
    FValue: Double;
    FHasValue: Boolean;
  public
    procedure SetValue(AValue: Double);
    procedure Clear;
    function HasValue: Boolean;
    function Value: Double;
    function ValueOr(ADefault: Double): Double;
    function Equals(const AOther: TLandrixEInvoiceQuantity): Boolean;
  end;

  { Optional percentage (Double, e.g. 19 for 19 %).
    DE: Optionaler Prozentsatz (Double, z. B. 19 fuer 19 %). }
  TLandrixEInvoicePercent = object
  private
    FValue: Double;
    FHasValue: Boolean;
  public
    procedure SetValue(AValue: Double);
    procedure Clear;
    function HasValue: Boolean;
    function Value: Double;
    function ValueOr(ADefault: Double): Double;
    function Equals(const AOther: TLandrixEInvoicePercent): Boolean;
  end;

  { Optional integer.
    DE: Optionale ganze Zahl. }
  TLandrixEInvoiceInteger = object
  private
    { Int64, so that the object is not exactly 8 bytes: Delphi 13 Win64
      passes 8-byte objects wrongly as value or const parameters }
    FValue: Int64;
    FHasValue: Boolean;
  public
    procedure SetValue(AValue: Integer);
    procedure Clear;
    function HasValue: Boolean;
    function Value: Integer;
    function ValueOr(ADefault: Integer): Integer;
    function Equals(const AOther: TLandrixEInvoiceInteger): Boolean;
  end;

  { Optional boolean.
    DE: Optionaler Wahrheitswert. }
  TLandrixEInvoiceBoolean = object
  private
    FValue: Boolean;
    FHasValue: Boolean;
  public
    procedure SetValue(AValue: Boolean);
    procedure Clear;
    function HasValue: Boolean;
    function Value: Boolean;
    function ValueOr(ADefault: Boolean): Boolean;
    function Equals(const AOther: TLandrixEInvoiceBoolean): Boolean;
  end;

{ Converts invoice text to UTF-8. Raises ELandrixXmlError (xecInvalidUnicode)
  for an unpaired UTF-16 surrogate.
  DE: Wandelt Rechnungstext in UTF-8 um. Loest ELandrixXmlError
  (xecInvalidUnicode) bei einem ungepaarten UTF-16-Surrogat aus. }
function LandrixEInvoiceStringToUtf8(const S: TLandrixEInvoiceString): TLandrixXmlUtf8;

{ Converts UTF-8 to invoice text. Raises ELandrixXmlError (xecInvalidUnicode)
  for malformed UTF-8.
  DE: Wandelt UTF-8 in Rechnungstext um. Loest ELandrixXmlError
  (xecInvalidUnicode) bei fehlerhaftem UTF-8 aus. }
function LandrixEInvoiceUtf8ToString(const S: TLandrixXmlUtf8): TLandrixEInvoiceString;

{ Factories for optional values: LandrixEInvoiceAmount(0) is an explicit
  zero, LandrixEInvoiceNoAmount is "not set".
  DE: Erzeugerfunktionen fuer optionale Werte: LandrixEInvoiceAmount(0) ist
  eine ausdrueckliche Null, LandrixEInvoiceNoAmount ist "nicht gesetzt". }
function LandrixEInvoiceAmount(AValue: Currency): TLandrixEInvoiceAmount;
function LandrixEInvoiceNoAmount: TLandrixEInvoiceAmount;
function LandrixEInvoiceDate(AValue: TDateTime): TLandrixEInvoiceDate;
function LandrixEInvoiceNoDate: TLandrixEInvoiceDate;
function LandrixEInvoiceQuantity(AValue: Double): TLandrixEInvoiceQuantity;
function LandrixEInvoiceNoQuantity: TLandrixEInvoiceQuantity;
function LandrixEInvoicePercent(AValue: Double): TLandrixEInvoicePercent;
function LandrixEInvoiceNoPercent: TLandrixEInvoicePercent;
function LandrixEInvoiceInteger(AValue: Integer): TLandrixEInvoiceInteger;
function LandrixEInvoiceNoInteger: TLandrixEInvoiceInteger;
function LandrixEInvoiceBoolean(AValue: Boolean): TLandrixEInvoiceBoolean;
function LandrixEInvoiceNoBoolean: TLandrixEInvoiceBoolean;

implementation

procedure RaiseNoValue(const TypeName: string);
begin
  raise ELandrixEInvoiceError.Create(TypeName + ' has no value');
end;

{ Relative comparison without the Math unit. }
function SameDouble(A, B: Double): Boolean;
var
  Scale: Double;
begin
  Scale := Abs(A);
  if Abs(B) > Scale then
    Scale := Abs(B);
  if Scale < 1.0 then
    Scale := 1.0;
  { relative tolerance 1e-12. A / Scale and B / Scale lie in [-1, 1], so the
    difference cannot overflow (AArch64 traps on overflow). An integer factor
    instead of a float constant, which Win64 would truncate from Extended
    (W1066). }
  Result := (A = B) or (Abs(A / Scale - B / Scale) * 1000000000000 <= 1);
end;

{ TLandrixEInvoiceAmount }

procedure TLandrixEInvoiceAmount.SetValue(AValue: Currency);
begin
  FValue := AValue;
  FHasValue := True;
end;

procedure TLandrixEInvoiceAmount.Clear;
begin
  FValue := 0;
  FHasValue := False;
end;

function TLandrixEInvoiceAmount.HasValue: Boolean;
begin
  Result := FHasValue;
end;

function TLandrixEInvoiceAmount.Value: Currency;
begin
  if not FHasValue then
    RaiseNoValue('TLandrixEInvoiceAmount');
  Result := FValue;
end;

function TLandrixEInvoiceAmount.ValueOr(ADefault: Currency): Currency;
begin
  if FHasValue then
    Result := FValue
  else
    Result := ADefault;
end;

function TLandrixEInvoiceAmount.Equals(const AOther: TLandrixEInvoiceAmount): Boolean;
begin
  if FHasValue <> AOther.FHasValue then
    Result := False
  else if not FHasValue then
    Result := True
  else
    Result := FValue = AOther.FValue;
end;

function LandrixEInvoiceAmount(AValue: Currency): TLandrixEInvoiceAmount;
begin
  Result.SetValue(AValue);
end;

function LandrixEInvoiceNoAmount: TLandrixEInvoiceAmount;
begin
  Result.Clear;
end;

{ TLandrixEInvoiceDate }

procedure TLandrixEInvoiceDate.SetValue(AValue: TDateTime);
begin
  FValue := AValue;
  FHasValue := True;
end;

procedure TLandrixEInvoiceDate.Clear;
begin
  FValue := 0;
  FHasValue := False;
end;

function TLandrixEInvoiceDate.HasValue: Boolean;
begin
  Result := FHasValue;
end;

function TLandrixEInvoiceDate.Value: TDateTime;
begin
  if not FHasValue then
    RaiseNoValue('TLandrixEInvoiceDate');
  Result := FValue;
end;

function TLandrixEInvoiceDate.ValueOr(ADefault: TDateTime): TDateTime;
begin
  if FHasValue then
    Result := FValue
  else
    Result := ADefault;
end;

function TLandrixEInvoiceDate.Equals(const AOther: TLandrixEInvoiceDate): Boolean;
begin
  if FHasValue <> AOther.FHasValue then
    Result := False
  else if not FHasValue then
    Result := True
  else
    Result := FValue = AOther.FValue;
end;

function LandrixEInvoiceDate(AValue: TDateTime): TLandrixEInvoiceDate;
begin
  Result.SetValue(AValue);
end;

function LandrixEInvoiceNoDate: TLandrixEInvoiceDate;
begin
  Result.Clear;
end;

{ TLandrixEInvoiceQuantity }

procedure TLandrixEInvoiceQuantity.SetValue(AValue: Double);
begin
  FValue := AValue;
  FHasValue := True;
end;

procedure TLandrixEInvoiceQuantity.Clear;
begin
  FValue := 0;
  FHasValue := False;
end;

function TLandrixEInvoiceQuantity.HasValue: Boolean;
begin
  Result := FHasValue;
end;

function TLandrixEInvoiceQuantity.Value: Double;
begin
  if not FHasValue then
    RaiseNoValue('TLandrixEInvoiceQuantity');
  Result := FValue;
end;

function TLandrixEInvoiceQuantity.ValueOr(ADefault: Double): Double;
begin
  if FHasValue then
    Result := FValue
  else
    Result := ADefault;
end;

function TLandrixEInvoiceQuantity.Equals(const AOther: TLandrixEInvoiceQuantity): Boolean;
begin
  if FHasValue <> AOther.FHasValue then
    Result := False
  else if not FHasValue then
    Result := True
  else
    Result := SameDouble(FValue, AOther.FValue);
end;

function LandrixEInvoiceQuantity(AValue: Double): TLandrixEInvoiceQuantity;
begin
  Result.SetValue(AValue);
end;

function LandrixEInvoiceNoQuantity: TLandrixEInvoiceQuantity;
begin
  Result.Clear;
end;

{ TLandrixEInvoicePercent }

procedure TLandrixEInvoicePercent.SetValue(AValue: Double);
begin
  FValue := AValue;
  FHasValue := True;
end;

procedure TLandrixEInvoicePercent.Clear;
begin
  FValue := 0;
  FHasValue := False;
end;

function TLandrixEInvoicePercent.HasValue: Boolean;
begin
  Result := FHasValue;
end;

function TLandrixEInvoicePercent.Value: Double;
begin
  if not FHasValue then
    RaiseNoValue('TLandrixEInvoicePercent');
  Result := FValue;
end;

function TLandrixEInvoicePercent.ValueOr(ADefault: Double): Double;
begin
  if FHasValue then
    Result := FValue
  else
    Result := ADefault;
end;

function TLandrixEInvoicePercent.Equals(const AOther: TLandrixEInvoicePercent): Boolean;
begin
  if FHasValue <> AOther.FHasValue then
    Result := False
  else if not FHasValue then
    Result := True
  else
    Result := SameDouble(FValue, AOther.FValue);
end;

function LandrixEInvoicePercent(AValue: Double): TLandrixEInvoicePercent;
begin
  Result.SetValue(AValue);
end;

function LandrixEInvoiceNoPercent: TLandrixEInvoicePercent;
begin
  Result.Clear;
end;

{ TLandrixEInvoiceInteger }

procedure TLandrixEInvoiceInteger.SetValue(AValue: Integer);
begin
  FValue := AValue;
  FHasValue := True;
end;

procedure TLandrixEInvoiceInteger.Clear;
begin
  FValue := 0;
  FHasValue := False;
end;

function TLandrixEInvoiceInteger.HasValue: Boolean;
begin
  Result := FHasValue;
end;

function TLandrixEInvoiceInteger.Value: Integer;
begin
  if not FHasValue then
    RaiseNoValue('TLandrixEInvoiceInteger');
  Result := Integer(FValue);
end;

function TLandrixEInvoiceInteger.ValueOr(ADefault: Integer): Integer;
begin
  if FHasValue then
    Result := Integer(FValue)
  else
    Result := ADefault;
end;

function TLandrixEInvoiceInteger.Equals(const AOther: TLandrixEInvoiceInteger): Boolean;
begin
  if FHasValue <> AOther.FHasValue then
    Result := False
  else if not FHasValue then
    Result := True
  else
    Result := FValue = AOther.FValue;
end;

function LandrixEInvoiceInteger(AValue: Integer): TLandrixEInvoiceInteger;
begin
  Result.SetValue(AValue);
end;

function LandrixEInvoiceNoInteger: TLandrixEInvoiceInteger;
begin
  Result.Clear;
end;

{ TLandrixEInvoiceBoolean }

procedure TLandrixEInvoiceBoolean.SetValue(AValue: Boolean);
begin
  FValue := AValue;
  FHasValue := True;
end;

procedure TLandrixEInvoiceBoolean.Clear;
begin
  FValue := False;
  FHasValue := False;
end;

function TLandrixEInvoiceBoolean.HasValue: Boolean;
begin
  Result := FHasValue;
end;

function TLandrixEInvoiceBoolean.Value: Boolean;
begin
  if not FHasValue then
    RaiseNoValue('TLandrixEInvoiceBoolean');
  Result := FValue;
end;

function TLandrixEInvoiceBoolean.ValueOr(ADefault: Boolean): Boolean;
begin
  if FHasValue then
    Result := FValue
  else
    Result := ADefault;
end;

function TLandrixEInvoiceBoolean.Equals(const AOther: TLandrixEInvoiceBoolean): Boolean;
begin
  if FHasValue <> AOther.FHasValue then
    Result := False
  else if not FHasValue then
    Result := True
  else
    Result := FValue = AOther.FValue;
end;

function LandrixEInvoiceBoolean(AValue: Boolean): TLandrixEInvoiceBoolean;
begin
  Result.SetValue(AValue);
end;

function LandrixEInvoiceNoBoolean: TLandrixEInvoiceBoolean;
begin
  Result.Clear;
end;

{ On Delphi TLandrixEInvoiceString is TLandrixXmlWide, so the wide
  conversion is lossless and never passes through the system code page. On
  FPC it is string, which LandrixXmlBase converts according to the string's
  code page. }

function LandrixEInvoiceStringToUtf8(const S: TLandrixEInvoiceString): TLandrixXmlUtf8;
begin
{$IFDEF FPC}
  Result := LandrixXmlStringToUtf8(S);
{$ELSE}
  Result := LandrixXmlWideToUtf8(S);
{$ENDIF}
end;

function LandrixEInvoiceUtf8ToString(const S: TLandrixXmlUtf8): TLandrixEInvoiceString;
begin
{$IFDEF FPC}
  Result := LandrixXmlUtf8ToString(S);
{$ELSE}
  Result := LandrixXmlUtf8ToWide(S);
{$ENDIF}
end;

end.
