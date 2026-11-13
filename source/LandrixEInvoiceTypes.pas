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
  TLandrixEInvoiceString  Text of the invoice model, UTF-16 and lossless on
                          every compiler, the same type as TLandrixXmlWide:
                          Delphi 6-2007: WideString.
                          Delphi 2009+:  string = UnicodeString.
                          FPC:           UnicodeString.
  TLandrixEInvoiceChar    One UTF-16 code unit (WideChar). Not necessarily a
                          complete character: a surrogate pair takes two.

  The conversion to and from UTF-8 (LandrixEInvoiceStringToUtf8,
  LandrixEInvoiceUtf8ToString) is lossless and independent of the system
  code page. Converting to a plain string is not: on Delphi 6-2007 and on
  FPC, assigning a TLandrixEInvoiceString to a string (or passing it to
  routines that take string) converts it to the code page of that string
  and loses characters it cannot represent. On FPC under Unix, without a
  wide string manager in the application (unit cwstring; Lazarus installs
  one), such conversions turn characters outside Latin-1 into '?'; FPC warns
  about them (4104, 4105).

  DE: Zeichenkettentyp
  TLandrixEInvoiceString ist der Text des Rechnungsmodells, unter jedem
  Compiler UTF-16 und verlustfrei, derselbe Typ wie TLandrixXmlWide: unter
  Delphi 6 bis 2007 WideString, ab Delphi 2009 string = UnicodeString, unter
  FPC UnicodeString. TLandrixEInvoiceChar ist eine UTF-16-Codeeinheit
  (WideChar), nicht unbedingt ein ganzes Zeichen: Ein Surrogatpaar belegt
  zwei. Die Umwandlung von und nach UTF-8 (LandrixEInvoiceStringToUtf8,
  LandrixEInvoiceUtf8ToString) ist verlustfrei und unabhaengig von der
  Systemcodepage. Die Umwandlung in einen normalen string ist es nicht: Unter
  Delphi 6 bis 2007 und unter FPC verliert die Zuweisung an einen string
  (auch die Uebergabe an Routinen mit string-Parametern) alle Zeichen, die
  dessen Codepage nicht darstellen kann. Unter FPC und Unix werden bei
  solchen Umwandlungen ohne Wide-String-Manager in der Anwendung (Unit
  cwstring; Lazarus bringt einen mit) Zeichen ausserhalb von Latin-1 zu '?';
  FPC warnt dabei (4104, 4105). }

{ API: stable. Covered by semantic versioning from release 1.0 on.
  DE: API: stabil. Ab Version 1.0 durch die semantische Versionierung
  abgedeckt. }

unit LandrixEInvoiceTypes;

{$I LandrixEInvoice.inc}

interface

uses
  SysUtils,
  LandrixXmlBase;

const
  { Library version (Semantic Versioning).
    DE: Version der Bibliothek (Semantic Versioning). }
  LandrixEInvoiceVersion = '0.9.0-beta.1';

type
{$IFDEF FPC}
  TLandrixEInvoiceString = UnicodeString;
{$ELSE}
  {$IFDEF LANDRIXEINVOICE_UNICODE}
  TLandrixEInvoiceString = string;
  {$ELSE}
  TLandrixEInvoiceString = WideString;
  {$ENDIF}
{$ENDIF}
  TLandrixEInvoiceChar = WideChar;

  { Index type of the model's list classes (TObjectList descendants). It
    matches the index type of TList on each compiler: NativeInt from Delphi
    12 on, Integer before and on FPC. Use it for loop variables over these
    lists; an Integer index there causes W1075/W1072 on Delphi 13 Win64.
    DE: Indextyp der Listenklassen des Modells (Nachfahren von TObjectList).
    Er entspricht dem Indextyp von TList je Compiler: NativeInt ab Delphi
    12, davor und unter FPC Integer. Fuer Schleifenvariablen ueber diese
    Listen verwenden; ein Integer-Index fuehrt dort unter Delphi 13 Win64 zu
    W1075/W1072. }
{$IFDEF FPC}
  TLandrixEInvoiceListIndex = Integer;
{$ELSE}
  {$IF CompilerVersion >= 36.0}
  TLandrixEInvoiceListIndex = NativeInt; // check-forbidden: allow
  {$ELSE}
  TLandrixEInvoiceListIndex = Integer;
  {$IFEND}
{$ENDIF}

  { Base class of the library's own exceptions (conversion errors from
    LandrixXml keep their class ELandrixXmlError).
    DE: Basisklasse der eigenen Ausnahmen der Bibliothek (Umwandlungsfehler
    aus LandrixXml behalten ihre Klasse ELandrixXmlError). }
  ELandrixEInvoiceError = class(Exception);

  { List of strings in TLandrixEInvoiceString (UTF-16 on every compiler;
    TStringList holds AnsiString on Delphi 6-2007). Used by the syntax
    models for repeated plain text such as cbc:Note. Index errors raise
    ELandrixEInvoiceError.
    DE: Liste von Zeichenketten in TLandrixEInvoiceString (UTF-16 auf jedem
    Compiler; TStringList haelt unter Delphi 6-2007 AnsiString). Die
    Syntaxmodelle nutzen sie fuer wiederholten einfachen Text wie cbc:Note.
    Indexfehler loesen ELandrixEInvoiceError aus. }
  TLandrixEInvoiceStringList = class(TObject)
  private
    FItems: array of TLandrixEInvoiceString;
    FCount: TLandrixEInvoiceListIndex;
    function GetItem(Index: TLandrixEInvoiceListIndex): TLandrixEInvoiceString;
    procedure SetItem(Index: TLandrixEInvoiceListIndex; const AValue: TLandrixEInvoiceString);
  public
    { Appends a string. DE: Haengt eine Zeichenkette an. }
    procedure Add(const AValue: TLandrixEInvoiceString);
    { Removes the string at Index. DE: Entfernt die Zeichenkette an Index. }
    procedure Delete(Index: TLandrixEInvoiceListIndex);
    { Removes all strings. DE: Entfernt alle Zeichenketten. }
    procedure Clear;
    { Number of strings. DE: Anzahl der Zeichenketten. }
    property Count: TLandrixEInvoiceListIndex read FCount;
    { The strings, 0-based. DE: Die Zeichenketten, ab 0 gezaehlt. }
    property Items[Index: TLandrixEInvoiceListIndex]: TLandrixEInvoiceString read GetItem write SetItem; default;
  end;

  { Standard of an e-invoice specification. ZUGFeRD 2.x and Factur-X 1.x
    are one standard with two names (est_FacturX).
    DE: Standard einer E-Rechnungs-Spezifikation. ZUGFeRD 2.x und Factur-X
    1.x sind ein Standard mit zwei Namen (est_FacturX). }
  TLandrixEInvoiceStandard = (
    est_None,
    est_XRechnung,
    est_FacturX,
    est_PeppolBIS
  );

  { Syntax of an e-invoice: UBL or UN/CEFACT CII.
    DE: Syntax einer E-Rechnung: UBL oder UN/CEFACT CII. }
  TLandrixEInvoiceSyntax = (
    esy_None,
    esy_UBL,
    esy_CII
  );

  { Profile of a Factur-X/ZUGFeRD target. epr_None is used for standards
    without a profile axis (XRechnung, Peppol BIS); epr_XRechnung is the
    ZUGFeRD profile XRECHNUNG, whose XML is an XRechnung CII invoice.
    DE: Profil eines Factur-X/ZUGFeRD-Ziels. epr_None gilt fuer Standards
    ohne Profilachse (XRechnung, Peppol BIS); epr_XRechnung ist das
    ZUGFeRD-Profil XRECHNUNG, dessen XML eine XRechnung in CII ist. }
  TLandrixEInvoiceProfile = (
    epr_None,
    epr_Minimum,
    epr_BasicWL,
    epr_Basic,
    epr_EN16931,
    epr_Extended,
    epr_XRechnung
  );

  { What to write or what was read: standard, syntax, profile and version.
    A target is valid if the specification directory (LandrixEInvoiceSpecs)
    has an entry for it. The version is matched by major and minor number:
    '3.0.2', '3.0.x' and '3.0' select the entry '3.0'; an empty, incomplete
    or malformed version matches nothing. Create targets with
    TLandrixEInvoiceTargets and compare them with LandrixEInvoiceSameTarget,
    never with '='.
    DE: Was geschrieben werden soll oder gelesen wurde: Standard, Syntax,
    Profil und Version. Eine Zielangabe ist gueltig, wenn das
    Spezifikationsverzeichnis (LandrixEInvoiceSpecs) einen Eintrag dafuer
    hat. Die Version wird nach Haupt- und Nebenversion verglichen: '3.0.2',
    '3.0.x' und '3.0' waehlen den Eintrag '3.0'; eine leere, unvollstaendige
    oder fehlerhafte Version passt zu nichts. Zielangaben mit
    TLandrixEInvoiceTargets erzeugen und mit LandrixEInvoiceSameTarget
    vergleichen, nie mit '='. }
  TLandrixEInvoiceTarget = record
    Standard: TLandrixEInvoiceStandard;
    Syntax: TLandrixEInvoiceSyntax;
    Profile: TLandrixEInvoiceProfile;
    Version: TLandrixEInvoiceString;
  end;

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

{ TLandrixEInvoiceString is TLandrixXmlWide on every compiler, so the wide
  conversion is lossless and never passes through a code page. }

function LandrixEInvoiceStringToUtf8(const S: TLandrixEInvoiceString): TLandrixXmlUtf8;
begin
  Result := LandrixXmlWideToUtf8(S);
end;

function LandrixEInvoiceUtf8ToString(const S: TLandrixXmlUtf8): TLandrixEInvoiceString;
begin
  Result := LandrixXmlUtf8ToWide(S);
end;

{ TLandrixEInvoiceStringList }

function TLandrixEInvoiceStringList.GetItem(Index: TLandrixEInvoiceListIndex): TLandrixEInvoiceString;
begin
  if (Index < 0) or (Index >= FCount) then
    raise ELandrixEInvoiceError.Create('TLandrixEInvoiceStringList index out of range');
  Result := FItems[Index];
end;

procedure TLandrixEInvoiceStringList.SetItem(Index: TLandrixEInvoiceListIndex;
  const AValue: TLandrixEInvoiceString);
begin
  if (Index < 0) or (Index >= FCount) then
    raise ELandrixEInvoiceError.Create('TLandrixEInvoiceStringList index out of range');
  FItems[Index] := AValue;
end;

procedure TLandrixEInvoiceStringList.Add(const AValue: TLandrixEInvoiceString);
begin
  if FCount = Length(FItems) then
    SetLength(FItems, FCount * 2 + 4);
  FItems[FCount] := AValue;
  Inc(FCount);
end;

procedure TLandrixEInvoiceStringList.Delete(Index: TLandrixEInvoiceListIndex);
var
  I: TLandrixEInvoiceListIndex;
begin
  if (Index < 0) or (Index >= FCount) then
    raise ELandrixEInvoiceError.Create('TLandrixEInvoiceStringList index out of range');
  for I := Index to FCount - 2 do
    FItems[I] := FItems[I + 1];
  Dec(FCount);
  FItems[FCount] := '';
end;

procedure TLandrixEInvoiceStringList.Clear;
begin
  FItems := nil;
  FCount := 0;
end;

end.
