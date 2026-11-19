{
  EInvoice-for-Pascal

  Copyright (C) 2026 Landrix Software GmbH & Co. KG

  This file is dual-licensed under:
  - GNU GPL version 3 or later; or
  - the Landrix Software Commercial License.

  See LICENSE and COMMERCIAL-LICENSE.md.

  SPDX-License-Identifier: GPL-3.0-or-later OR LicenseRef-Landrix-Commercial
}

{ Advisory checks: the library's own hints on an invoice that no standard
  demands (rule identifiers LX-..., see docs/rules.md). They never decide a
  verdict: the document validation shows them in their own part
  (evp_Advisory), and a hint is at most a warning. They run on the invoice
  model as read, apart from the rule check (LandrixEInvoiceCheckInvoice).
  The checks come in families the caller chooses; the technical ones are
  on by default, legal and context-dependent ones (planned) only on
  request.

  Family eaf_Identifiers (LX-ID): invisible and deceptive characters in
  the text fields of the invoice (LX-ID-01 to LX-ID-05). An identifier, a
  code, a reference, an address part such as the postal code, a telephone
  number or an e-mail address with a bidirectional control character, an
  invisible character, a space other than U+0020 or a C1 control character
  gets a warning; in a name
  or a free text such characters can be legitimate (joiners in Indic
  scripts and emoji, direction marks in Arabic or Hebrew text), so they are
  an info there, except C1 control characters (a warning everywhere,
  usually a wrong character encoding). An identifier whose scheme is ASCII
  (VAT identifier, country and currency code, GTIN, BIC, SEPA creditor
  identifier, the mandate reference of a SEPA direct debit, an IBAN) gets a
  warning for any other character outside
  ASCII, e.g. a Cyrillic letter that looks like a Latin one. The value
  itself is never changed; the finding shows it with the characters masked
  as <U+XXXX>.

  The same family checks identifiers by their scheme (LX-ID-06 to
  LX-ID-10): a GLN (0088) at a party, location or electronic address has
  13 digits and a valid GS1 check digit (for Peppol BIS only the length
  where PEPPOL-COMMON-R040 reported in the same run), a
  global identifier without scheme counts as GLN as the writers write it,
  a GTIN (0160) as item
  identifier 8, 12, 13 or 14 digits and a valid check digit, a GTIN is no
  party identifier and a GLN no item identifier, a Leitweg-ID (0204) and a
  buyer reference (BT-10) that looks like one follow the format
  specification 2.0.2, and a buyer reference that differs from the buyer's
  Leitweg-ID gets an info.

  DE: Hinweispruefungen: eigene Hinweise der Bibliothek zu einer Rechnung,
  die kein Standard verlangt (Regelkennungen LX-..., siehe docs/rules.md).
  Sie entscheiden nie ueber ein Urteil: die Dokumentpruefung zeigt sie in
  einem eigenen Teil (evp_Advisory), und ein Hinweis ist hoechstens eine
  Warnung. Sie laufen auf dem gelesenen Rechnungsmodell, getrennt von der
  Regelpruefung (LandrixEInvoiceCheckInvoice). Die Pruefungen gehoeren zu
  Familien, die der Aufrufer waehlt; die technischen sind
  standardmaessig an, rechtliche und kontextabhaengige (geplant) nur auf
  Anforderung.

  Familie eaf_Identifiers (LX-ID): unsichtbare und taeuschende Zeichen in
  den Textfeldern der Rechnung (LX-ID-01 bis LX-ID-05). Eine Kennung, ein
  Code, ein Verweis, ein Adressteil wie die Postleitzahl, eine
  Telefonnummer oder eine E-Mail-Adresse mit einem bidirektionalen
  Steuerzeichen, einem unsichtbaren Zeichen, einem Leerzeichen ausser
  U+0020 oder einem C1-Steuerzeichen bekommt eine Warnung; in einem Namen oder Freitext koennen solche Zeichen
  berechtigt sein (Verbinder in indischen Schriften und Emoji,
  Richtungszeichen in arabischem oder hebraeischem Text), dort sind sie ein
  Hinweis, ausser C1-Steuerzeichen (ueberall eine Warnung, meist eine
  falsche Zeichenkodierung). Eine Kennung, deren Schema ASCII ist
  (Umsatzsteuer-Identifikationsnummer, Laender- und Waehrungscode, GTIN, BIC,
  Glaeubiger-Identifikationsnummer, die Mandatsreferenz einer
  SEPA-Lastschrift, eine IBAN), bekommt eine Warnung fuer
  jedes andere Zeichen ausserhalb von ASCII, z. B. einen kyrillischen
  Buchstaben, der wie ein lateinischer aussieht. Der Wert selbst wird nie
  geaendert; der Befund zeigt ihn mit den Zeichen maskiert als <U+XXXX>.

  Dieselbe Familie prueft Kennungen nach ihrem Schema (LX-ID-06 bis
  LX-ID-10): eine GLN (0088) an einem Beteiligten, Ort oder einer
  elektronischen Adresse hat 13 Ziffern und eine gueltige GS1-Pruefziffer
  (bei Peppol BIS nur die Laenge, wo PEPPOL-COMMON-R040 im selben Lauf
  gemeldet hat), eine globale Kennung ohne Schema zaehlt als GLN,
  wie die Writer sie schreiben, eine GTIN (0160) als Artikelkennung 8, 12, 13 oder 14 Ziffern und
  eine gueltige Pruefziffer, eine GTIN ist keine Kennung eines Beteiligten
  und eine GLN keine Artikelkennung, eine Leitweg-ID (0204) und eine
  Kaeuferreferenz (BT-10), die wie eine aussieht, folgen der
  Formatspezifikation 2.0.2, und eine Kaeuferreferenz, die von der
  Leitweg-ID des Kaeufers abweicht, bekommt einen Hinweis. }

{ API: internal. May change in any release; use the facade LandrixEInvoice
  or the stable units instead.
  DE: API: intern. Kann sich in jeder Version aendern; stattdessen die
  Fassade LandrixEInvoice oder die stabilen Units verwenden. }

unit LandrixEInvoiceAdvisory;

{$I LandrixEInvoice.inc}

interface

uses
  Classes,
  LandrixEInvoiceTypes,
  LandrixEInvoiceDiagnostics,
  LandrixEInvoiceInvoice;

type
  { The families of advisory checks. eaf_Identifiers: identifiers and
    characters (LX-ID), technical.
    DE: Die Familien der Hinweispruefungen. eaf_Identifiers: Kennungen und
    Zeichen (LX-ID), technisch. }
  TLandrixEInvoiceAdvisoryFamily = (eaf_Identifiers);
  TLandrixEInvoiceAdvisoryFamilies = set of TLandrixEInvoiceAdvisoryFamily;

const
  { The technical families, on by default.
    DE: Die technischen Familien, standardmaessig an. }
  LandrixEInvoiceAdvisoryTechnical = [eaf_Identifiers];

{ Runs the advisory checks of AFamilies on AInvoice for ATarget (the target
  read from the document, its Standard est_None when unknown; it decides
  what PEPPOL-COMMON-R040 already checks and how strict BT-10 is) and adds a
  diagnostic
  (edk_RuleViolation, severity info or warning, never error) per hint to
  ADiagnostics: RuleID, Path (the model path, e.g.
  InvoiceLines[0].SellersItemIdentification), Terms, Found (the value
  with the characters masked, shortened around the first one, or the
  wrong check digits), Expected (the right check digits) and Message.
  AR040Reported: the rule check (LandrixEInvoiceCheckInvoice) of the same
  invoice reported PEPPOL-COMMON-R040, so a wrong GLN check digit at the
  places it checks is not repeated. Returns the number of hints.
  DE: Fuehrt die Hinweispruefungen von AFamilies auf AInvoice fuer ATarget
  aus (das aus dem Dokument gelesene Ziel, Standard est_None, wenn
  unbekannt; es entscheidet, was PEPPOL-COMMON-R040 schon prueft und wie
  streng BT-10 ist) und fuegt
  je Hinweis eine Meldung (edk_RuleViolation, Schwere Hinweis oder
  Warnung, nie Fehler) zu ADiagnostics hinzu: RuleID, Path (der
  Modellpfad, z. B. InvoiceLines[0].SellersItemIdentification), Terms,
  Found (der Wert mit maskierten Zeichen, gekuerzt um das erste, oder die
  falschen Pruefziffern), Expected (die richtigen Pruefziffern) und
  Message. AR040Reported: die Regelpruefung (LandrixEInvoiceCheckInvoice)
  derselben Rechnung hat PEPPOL-COMMON-R040 gemeldet, eine falsche
  GLN-Pruefziffer an den Stellen, die sie prueft, wird also nicht
  wiederholt. Liefert die Zahl der Hinweise. }
function LandrixEInvoiceAdvise(AInvoice: TLandrixInvoice; const ATarget: TLandrixEInvoiceTarget;
  AFamilies: TLandrixEInvoiceAdvisoryFamilies; ADiagnostics: TLandrixEInvoiceDiagnostics;
  AR040Reported: Boolean = False): Integer;

{ Adds one line per text field the character checks look at to ALines:
  model path, ' = "', value, '"' (the form of the test helper DumpInvoice,
  without the business terms), also for empty fields. For the test that no
  field of the model is left out.
  DE: Fuegt ALines eine Zeile je Textfeld hinzu, das die Zeichenpruefungen
  ansehen: Modellpfad, ' = "', Wert, '"' (die Form der Testhilfe
  DumpInvoice, ohne Geschaeftsbegriffe), auch fuer leere Felder. Fuer den
  Test, dass kein Feld des Modells fehlt. }
procedure LandrixEInvoiceAdvisoryListFields(AInvoice: TLandrixInvoice; ALines: TStrings);

implementation

uses
  SysUtils,
  LandrixEInvoiceCodes,
  LandrixEInvoiceIdentifiers,
  LandrixEInvoiceRenderLabels;

const
  RuleBidi = 'LX-ID-01';
  RuleInvisible = 'LX-ID-02';
  RuleC1 = 'LX-ID-03';
  RuleTextHidden = 'LX-ID-04';
  RuleNotAscii = 'LX-ID-05';
  RuleGln = 'LX-ID-06';
  RuleGtin = 'LX-ID-07';
  RuleWrongScheme = 'LX-ID-08';
  RuleLeitweg = 'LX-ID-09';
  RuleLeitwegDiffers = 'LX-ID-10';
  { UTF-16 units shown before and after the first character in Found }
  ExcerptContext = 30;

type
  { What a text field holds: an identifier (also codes, references, postal
    codes, telephone numbers, e-mail addresses, file names), an identifier
    whose scheme is ASCII, a name or free text, or the copy of another
    field (walked, not checked again). }
  TFieldKind = (fk_Identifier, fk_Ascii, fk_Text, fk_Same);

  { What a character is to the checks. }
  TCharClass = (cc_Plain, cc_Bidi, cc_Invisible, cc_Space, cc_C1, cc_Surrogate, cc_NonAscii);
  TCharClasses = set of TCharClass;

  { The first character of a class in a value and how many there are. }
  TCharHit = record
    Count: Integer;
    CodePoint: Cardinal;
    Position: Integer;
    Index: Integer;
  end;

  TFieldVisitor = class(TObject)
  public
    procedure Visit(const APath: string; const AValue: TLandrixEInvoiceString; AKind: TFieldKind); virtual; abstract;
  end;

  TFieldLister = class(TFieldVisitor)
  private
    FLines: TStrings;
  public
    procedure Visit(const APath: string; const AValue: TLandrixEInvoiceString; AKind: TFieldKind); override;
  end;

  TCharacterChecker = class(TFieldVisitor)
  private
    FDiagnostics: TLandrixEInvoiceDiagnostics;
    FCount: Integer;
    procedure Hint(const ARule, APath: string; const AValue: TLandrixEInvoiceString;
      ASeverity: TLandrixEInvoiceDiagnosticSeverity; const AWhat, AWhy: string; const AHit: TCharHit;
      AMask: TCharClasses);
  public
    procedure Visit(const APath: string; const AValue: TLandrixEInvoiceString; AKind: TFieldKind); override;
  end;

{ --- characters ------------------------------------------------------------ }

{ The code point at AIndex of S (a surrogate pair counts as one) and the
  number of UTF-16 units it takes. A lone surrogate is returned as it is. }
function CodePointAt(const S: TLandrixEInvoiceString; AIndex: Integer; out AUnits: Integer): Cardinal;
var
  Hi, Lo: Cardinal;
begin
  Hi := Ord(S[AIndex]);
  AUnits := 1;
  Result := Hi;
  if (Hi >= $D800) and (Hi <= $DBFF) and (AIndex < Length(S)) then
  begin
    Lo := Ord(S[AIndex + 1]);
    if (Lo >= $DC00) and (Lo <= $DFFF) then
    begin
      Result := $10000 + ((Hi - $D800) shl 10) + (Lo - $DC00);
      AUnits := 2;
    end;
  end;
end;

{ Bidirectional control characters (Unicode Bidi_Control): the Arabic
  letter mark, the left-to-right and right-to-left marks, the embeddings,
  overrides and isolates.
  DE: Bidirektionale Steuerzeichen (Unicode Bidi_Control): das arabische
  Buchstabenzeichen, die Links-nach-rechts- und Rechts-nach-links-Marken,
  die Einbettungen, Ueberschreibungen und Isolierungen. }
function IsBidi(C: Cardinal): Boolean;
begin
  Result := (C = $061C) or (C = $200E) or (C = $200F) or ((C >= $202A) and (C <= $202E)) or
    ((C >= $2066) and (C <= $2069));
end;

{ Characters that show nothing: soft hyphen, combining grapheme joiner,
  Hangul fillers, Khmer inherent vowels, Mongolian variation selectors and
  vowel separator, zero width space, non-joiner and joiner, word joiner
  and invisible operators, deprecated format characters, variation
  selectors, interlinear annotation characters, zero width no-break space,
  shorthand format controls, musical formatting characters, tag characters.
  DE: Zeichen, die nichts zeigen: weiches Trennzeichen, unsichtbarer
  Verbinder, Hangul-Fueller, inhaerente Khmer-Vokale, mongolische
  Variantenselektoren und Vokaltrenner, Nullbreite-Leerzeichen,
  -Nichtverbinder und -Verbinder, Wortverbinder und unsichtbare Operatoren,
  veraltete Formatzeichen, Variantenselektoren, Zeichen fuer
  Interlinearanmerkungen, geschuetztes Nullbreite-Leerzeichen,
  Kurzschrift-Formatsteuerzeichen, musikalische Formatzeichen, Tag-Zeichen. }
function IsInvisible(C: Cardinal): Boolean;
begin
  Result := (C = $00AD) or (C = $034F) or (C = $115F) or (C = $1160) or (C = $17B4) or (C = $17B5) or
    (C = $3164) or (C = $FFA0) or (C = $FEFF) or ((C >= $180B) and (C <= $180F)) or
    ((C >= $200B) and (C <= $200D)) or ((C >= $2060) and (C <= $2064)) or ((C >= $206A) and (C <= $206F)) or
    ((C >= $FE00) and (C <= $FE0F)) or ((C >= $FFF9) and (C <= $FFFB)) or ((C >= $1BCA0) and (C <= $1BCA3)) or
    ((C >= $1D173) and (C <= $1D17A)) or
    ((C >= $E0000) and (C <= $E007F)) or ((C >= $E0100) and (C <= $E01EF));
end;

{ Spaces other than U+0020 and the line and paragraph separators: they
  look like a space or like nothing.
  DE: Leerzeichen ausser U+0020 und die Zeilen- und Absatztrenner: sie
  sehen aus wie ein Leerzeichen oder wie nichts. }
function IsSpace(C: Cardinal): Boolean;
begin
  Result := (C = $00A0) or (C = $1680) or ((C >= $2000) and (C <= $200A)) or (C = $2028) or (C = $2029) or
    (C = $202F) or (C = $205F) or (C = $3000);
end;

function ClassOf(C: Cardinal): TCharClass;
begin
  if C < $80 then
    Result := cc_Plain
  else if C <= $9F then
    Result := cc_C1
  else if IsBidi(C) then
    Result := cc_Bidi
  else if IsInvisible(C) then
    Result := cc_Invisible
  else if IsSpace(C) then
    Result := cc_Space
  else if (C >= $D800) and (C <= $DFFF) then
    Result := cc_Surrogate
  else
    Result := cc_NonAscii;
end;

function CodePointText(C: Cardinal): string;
begin
  if C > $FFFF then
    Result := 'U+' + IntToHex(C, 5)
  else
    Result := 'U+' + IntToHex(C, 4);
end;

{ AValue around AFirst (a UTF-16 index), ExcerptContext UTF-16 units on
  either side, with every character of a class in AMask and every lone
  surrogate written as <U+XXXX>; '...' where the value goes on. }
function Masked(const AValue: TLandrixEInvoiceString; AFirst: Integer; AMask: TCharClasses): TLandrixEInvoiceString;
var
  I, Units, Start, Stop: Integer;
  C: Cardinal;
begin
  Start := AFirst - ExcerptContext;
  if Start < 1 then
    Start := 1;
  { never start on the second half of a surrogate pair (a lone low
    surrogate stays) }
  if (Start > 1) and (Ord(AValue[Start]) >= $DC00) and (Ord(AValue[Start]) <= $DFFF) and
     (Ord(AValue[Start - 1]) >= $D800) and (Ord(AValue[Start - 1]) <= $DBFF) then
    Inc(Start);
  Stop := AFirst + ExcerptContext;
  if Stop > Length(AValue) then
    Stop := Length(AValue);
  Result := '';
  if Start > 1 then
    Result := '...';
  I := Start;
  while I <= Stop do
  begin
    C := CodePointAt(AValue, I, Units);
    if (ClassOf(C) in AMask) or (ClassOf(C) = cc_Surrogate) then
      Result := Result + '<' + TLandrixEInvoiceString(CodePointText(C)) + '>'
    else
      Result := Result + Copy(AValue, I, Units);
    Inc(I, Units);
  end;
  if I <= Length(AValue) then
    Result := Result + '...';
end;

{ The business terms of a model path, as the rendering labels have them
  ('' if none): the indexes and the levels of sub lines left out. }
function TermsOf(const APath: string): TLandrixEInvoiceString;
var
  Plain: string;
  I: Integer;
  Field: TLandrixEInvoiceRenderField;
begin
  Plain := '';
  I := 1;
  while I <= Length(APath) do
  begin
    Plain := Plain + APath[I];
    if APath[I] = '[' then
      while (I < Length(APath)) and (APath[I + 1] <> ']') do
        Inc(I);
    Inc(I);
  end;
  repeat
    I := Pos('.SubInvoiceLines[]', Plain);
    if I > 0 then
      Delete(Plain, I, Length('.SubInvoiceLines[]'));
  until I = 0;
  Result := '';
  for Field := Low(TLandrixEInvoiceRenderField) to High(TLandrixEInvoiceRenderField) do
    if LandrixEInvoiceRenderFieldPath(Field) = TLandrixEInvoiceString(Plain) then
    begin
      Result := LandrixEInvoiceRenderFieldBT(Field);
      Exit;
    end;
end;

{ Adds a hint to ADiagnostics (nil: only counted in ACount); never an
  error. }
procedure AddHint(ADiagnostics: TLandrixEInvoiceDiagnostics; var ACount: Integer; const ARule, APath: string;
  ASeverity: TLandrixEInvoiceDiagnosticSeverity; const AText: string; const AExpected,
  AFound: TLandrixEInvoiceString);
var
  D: TLandrixEInvoiceDiagnostic;
begin
  { a hint is never an error
    DE: ein Hinweis ist nie ein Fehler }
  if ASeverity = eds_Error then
    ASeverity := eds_Warning;
  Inc(ACount);
  if ADiagnostics = nil then
    Exit;
  D := ADiagnostics.AddDiagnostic(edk_RuleViolation, TLandrixEInvoiceString(APath), 0, 0, 0,
    TLandrixEInvoiceString(AText));
  D.Severity := ASeverity;
  D.RuleID := TLandrixEInvoiceString(ARule);
  D.Terms := TermsOf(APath);
  D.Expected := AExpected;
  D.Found := AFound;
end;

{ --- TFieldLister ------------------------------------------------------------ }

procedure TFieldLister.Visit(const APath: string; const AValue: TLandrixEInvoiceString; AKind: TFieldKind);
begin
  FLines.Add(APath + ' = "' + string(AValue) + '"');
end;

{ --- TCharacterChecker ------------------------------------------------------- }

procedure TCharacterChecker.Hint(const ARule, APath: string; const AValue: TLandrixEInvoiceString;
  ASeverity: TLandrixEInvoiceDiagnosticSeverity; const AWhat, AWhy: string; const AHit: TCharHit;
  AMask: TCharClasses);
var
  Text: string;
begin
  { the position counts characters (a surrogate pair is one)
    DE: die Position zaehlt Zeichen (ein Ersatzpaar ist eines) }
  Text := AWhat + ' ' + CodePointText(AHit.CodePoint) + ' at character ' + IntToStr(AHit.Position);
  if AHit.Count > 1 then
    Text := Text + ' (' + IntToStr(AHit.Count) + ' in total)';
  Text := Text + AWhy;
  AddHint(FDiagnostics, FCount, ARule, APath, ASeverity, Text, '', Masked(AValue, AHit.Index, AMask));
end;

procedure TCharacterChecker.Visit(const APath: string; const AValue: TLandrixEInvoiceString; AKind: TFieldKind);
const
  Hidden = [cc_Bidi, cc_Invisible, cc_Space, cc_C1];
var
  Hits: array[TCharClass] of TCharHit;
  Cls: TCharClass;
  I, Units, Position: Integer;
  C: Cardinal;
  First: TCharHit;
begin
  if (AValue = '') or (AKind = fk_Same) then
    Exit;
  for Cls := Low(TCharClass) to High(TCharClass) do
    Hits[Cls].Count := 0;
  I := 1;
  Position := 0;
  while I <= Length(AValue) do
  begin
    C := CodePointAt(AValue, I, Units);
    Inc(Position);
    Cls := ClassOf(C);
    if Hits[Cls].Count = 0 then
    begin
      Hits[Cls].CodePoint := C;
      Hits[Cls].Position := Position;
      Hits[Cls].Index := I;
    end;
    Inc(Hits[Cls].Count);
    Inc(I, Units);
  end;
  if Hits[cc_C1].Count > 0 then
    Hint(RuleC1, APath, AValue, eds_Warning, 'The value contains the C1 control character',
      '; usually a sign of a wrong character encoding', Hits[cc_C1], Hidden);
  if AKind = fk_Text then
  begin
    { names and texts: the first bidirectional control or invisible
      character
      DE: Namen und Texte: das erste bidirektionale Steuerzeichen oder
      unsichtbare Zeichen }
    if Hits[cc_Bidi].Count + Hits[cc_Invisible].Count > 0 then
    begin
      if (Hits[cc_Invisible].Count = 0) or
         ((Hits[cc_Bidi].Count > 0) and (Hits[cc_Bidi].Position < Hits[cc_Invisible].Position)) then
        First := Hits[cc_Bidi]
      else
        First := Hits[cc_Invisible];
      First.Count := Hits[cc_Bidi].Count + Hits[cc_Invisible].Count;
      Hint(RuleTextHidden, APath, AValue, eds_Info,
        'The text contains the bidirectional control or invisible character',
        '; this can be legitimate (e.g. in Arabic or Hebrew text, Indic scripts or emoji), check it', First,
        Hidden);
    end;
    Exit;
  end;
  if Hits[cc_Bidi].Count > 0 then
    Hint(RuleBidi, APath, AValue, eds_Warning, 'The identifier contains the bidirectional control character',
      '; it can change the order in which the value is shown', Hits[cc_Bidi], Hidden);
  { an invisible character or a space other than U+0020
    DE: ein unsichtbares Zeichen oder ein Leerzeichen ausser U+0020 }
  if Hits[cc_Invisible].Count + Hits[cc_Space].Count > 0 then
  begin
    if (Hits[cc_Space].Count = 0) or
       ((Hits[cc_Invisible].Count > 0) and (Hits[cc_Invisible].Position < Hits[cc_Space].Position)) then
      First := Hits[cc_Invisible]
    else
      First := Hits[cc_Space];
    First.Count := Hits[cc_Invisible].Count + Hits[cc_Space].Count;
    Hint(RuleInvisible, APath, AValue, eds_Warning, 'The identifier contains the invisible or space character',
      '; two values that look the same can differ', First, Hidden);
  end;
  if (AKind = fk_Ascii) and (Hits[cc_NonAscii].Count > 0) then
    Hint(RuleNotAscii, APath, AValue, eds_Warning, 'The identifier contains the character',
      ' outside ASCII, which its scheme does not allow; it may look like an ASCII character',
      Hits[cc_NonAscii], Hidden + [cc_NonAscii]);
end;

{ --- the walk through the text fields --------------------------------------- }

function Item(const APath: string; AIndex: Integer): string;
begin
  Result := APath + '[' + IntToStr(AIndex) + ']';
end;

procedure WalkAddress(V: TFieldVisitor; A: TLandrixInvoiceAddress; const P: string);
begin
  V.Visit(P + '.StreetName', A.StreetName, fk_Text);
  V.Visit(P + '.AdditionalStreetName', A.AdditionalStreetName, fk_Text);
  V.Visit(P + '.City', A.City, fk_Text);
  V.Visit(P + '.PostalZone', A.PostalZone, fk_Identifier);
  V.Visit(P + '.CountrySubentity', A.CountrySubentity, fk_Text);
  V.Visit(P + '.AddressLine', A.AddressLine, fk_Text);
  V.Visit(P + '.CountryCode', A.CountryCode, fk_Ascii);
end;

{ the VAT identifiers (BT-31, BT-48, BT-63) and the SEPA creditor
  identifier (BT-90) are ASCII by their schemes
  DE: die Umsatzsteuer-Identifikationsnummern (BT-31, BT-48, BT-63) und die
  SEPA-Glaeubiger-Identifikationsnummer (BT-90) sind nach ihren Schemata
  ASCII }
procedure WalkAccountingParty(V: TFieldVisitor; A: TLandrixInvoiceAccountingParty; const P: string);
begin
  V.Visit(P + '.Name', A.Name, fk_Text);
  V.Visit(P + '.RegistrationName', A.RegistrationName, fk_Text);
  V.Visit(P + '.CompanyID', A.CompanyID, fk_Identifier);
  V.Visit(P + '.CompanyIDSchemeID', A.CompanyIDSchemeID, fk_Identifier);
  WalkAddress(V, A.Address, P + '.Address');
  V.Visit(P + '.IdentifierSellerBuyer', A.IdentifierSellerBuyer, fk_Identifier);
  V.Visit(P + '.GlobalIdentifierSellerBuyer', A.GlobalIdentifierSellerBuyer, fk_Identifier);
  V.Visit(P + '.GlobalIdentifierSellerBuyerSchemeID', A.GlobalIdentifierSellerBuyerSchemeID, fk_Identifier);
  V.Visit(P + '.BankAssignedCreditorIdentifier', A.BankAssignedCreditorIdentifier, fk_Ascii);
  V.Visit(P + '.VATCompanyID', A.VATCompanyID, fk_Ascii);
  V.Visit(P + '.VATCompanyNumber', A.VATCompanyNumber, fk_Identifier);
  V.Visit(P + '.ContactName', A.ContactName, fk_Text);
  V.Visit(P + '.ContactDepartment', A.ContactDepartment, fk_Text);
  V.Visit(P + '.ContactTelephone', A.ContactTelephone, fk_Identifier);
  V.Visit(P + '.ContactElectronicMail', A.ContactElectronicMail, fk_Identifier);
  V.Visit(P + '.AdditionalLegalInformationSeller', A.AdditionalLegalInformationSeller, fk_Text);
  V.Visit(P + '.ElectronicAddressSellerBuyer', A.ElectronicAddressSellerBuyer, fk_Identifier);
  V.Visit(P + '.ElectronicAddressSellerBuyerSchemeID', A.ElectronicAddressSellerBuyerSchemeID, fk_Identifier);
end;

procedure WalkParty(V: TFieldVisitor; A: TLandrixInvoiceParty; const P: string);
begin
  V.Visit(P + '.Name', A.Name, fk_Text);
  V.Visit(P + '.Identifier', A.Identifier, fk_Identifier);
  V.Visit(P + '.IdentifierSchemeID', A.IdentifierSchemeID, fk_Identifier);
  V.Visit(P + '.CompanyID', A.CompanyID, fk_Identifier);
  V.Visit(P + '.CompanyIDSchemeID', A.CompanyIDSchemeID, fk_Identifier);
  V.Visit(P + '.VATCompanyID', A.VATCompanyID, fk_Ascii);
  WalkAddress(V, A.Address, P + '.Address');
  V.Visit(P + '.ContactName', A.ContactName, fk_Text);
  V.Visit(P + '.ContactDepartment', A.ContactDepartment, fk_Text);
  V.Visit(P + '.ContactTelephone', A.ContactTelephone, fk_Identifier);
  V.Visit(P + '.ContactElectronicMail', A.ContactElectronicMail, fk_Identifier);
end;

procedure WalkDelivery(V: TFieldVisitor; A: TLandrixInvoiceDeliveryInformation; const P: string);
begin
  V.Visit(P + '.Name', A.Name, fk_Text);
  V.Visit(P + '.LocationIdentifier', A.LocationIdentifier, fk_Identifier);
  V.Visit(P + '.LocationIdentifierSchemeID', A.LocationIdentifierSchemeID, fk_Identifier);
  WalkAddress(V, A.Address, P + '.Address');
  V.Visit(P + '.ContactName', A.ContactName, fk_Text);
  V.Visit(P + '.ContactTelephone', A.ContactTelephone, fk_Identifier);
  V.Visit(P + '.ContactElectronicMail', A.ContactElectronicMail, fk_Identifier);
end;

procedure WalkAllowanceCharges(V: TFieldVisitor; AList: TLandrixInvoiceAllowanceCharges; const P: string);
var
  I: Integer;
  A: TLandrixInvoiceAllowanceCharge;
  Q: string;
begin
  for I := 0 to Integer(AList.Count) - 1 do
  begin
    A := AList[I];
    Q := Item(P, I);
    V.Visit(Q + '.ReasonCodeAllowanceOther', A.ReasonCodeAllowanceOther, fk_Identifier);
    V.Visit(Q + '.ReasonCodeChargeOther', A.ReasonCodeChargeOther, fk_Identifier);
    V.Visit(Q + '.Reason', A.Reason, fk_Text);
    V.Visit(Q + '.TaxCategoryOther', A.TaxCategoryOther, fk_Identifier);
    V.Visit(Q + '.TaxExemptionReason', A.TaxExemptionReason, fk_Text);
    V.Visit(Q + '.TaxExemptionReasonCode', A.TaxExemptionReasonCode, fk_Identifier);
  end;
end;

procedure WalkLines(V: TFieldVisitor; AList: TLandrixInvoiceLines; const P: string);
var
  I, J: Integer;
  L: TLandrixInvoiceLine;
  Q, R: string;
begin
  for I := 0 to Integer(AList.Count) - 1 do
  begin
    L := AList[I];
    Q := Item(P, I);
    V.Visit(Q + '.ID', L.ID, fk_Identifier);
    { a GTIN (scheme 0160) is digits; the readers fill both fields with the
      same value, which is checked once
      DE: eine GTIN (Schema 0160) besteht aus Ziffern; die Leser fuellen
      beide Felder mit demselben Wert, der einmal geprueft wird }
    if L.StandardItemIdentifierSchemeID = '0160' then
      V.Visit(Q + '.StandardItemIdentifier', L.StandardItemIdentifier, fk_Ascii)
    else
      V.Visit(Q + '.StandardItemIdentifier', L.StandardItemIdentifier, fk_Identifier);
    if (L.GlobalID_EAN_GTIN = L.StandardItemIdentifier) and (L.StandardItemIdentifierSchemeID = '0160') then
      V.Visit(Q + '.GlobalID_EAN_GTIN', L.GlobalID_EAN_GTIN, fk_Same)
    else
      V.Visit(Q + '.GlobalID_EAN_GTIN', L.GlobalID_EAN_GTIN, fk_Ascii);
    V.Visit(Q + '.StandardItemIdentifierSchemeID', L.StandardItemIdentifierSchemeID, fk_Identifier);
    V.Visit(Q + '.Note', L.Note, fk_Text);
    V.Visit(Q + '.ObjectIdentifier', L.ObjectIdentifier, fk_Identifier);
    V.Visit(Q + '.ObjectIdentifierSchemeID', L.ObjectIdentifierSchemeID, fk_Identifier);
    V.Visit(Q + '.Name', L.Name, fk_Text);
    V.Visit(Q + '.Description', L.Description, fk_Text);
    V.Visit(Q + '.UnitCodeOther', L.UnitCodeOther, fk_Identifier);
    V.Visit(Q + '.SellersItemIdentification', L.SellersItemIdentification, fk_Identifier);
    V.Visit(Q + '.BuyersItemIdentification', L.BuyersItemIdentification, fk_Identifier);
    V.Visit(Q + '.OrderNumber', L.OrderNumber, fk_Identifier);
    V.Visit(Q + '.OrderLineReference', L.OrderLineReference, fk_Identifier);
    V.Visit(Q + '.BuyerAccountingReference', L.BuyerAccountingReference, fk_Identifier);
    V.Visit(Q + '.TaxCategoryOther', L.TaxCategoryOther, fk_Identifier);
    V.Visit(Q + '.TaxExemptionReason', L.TaxExemptionReason, fk_Text);
    V.Visit(Q + '.BaseQuantityUnitCodeOther', L.BaseQuantityUnitCodeOther, fk_Identifier);
    WalkAllowanceCharges(V, L.AllowanceCharges, Q + '.AllowanceCharges');
    for J := 0 to Integer(L.ItemClassifications.Count) - 1 do
    begin
      R := Item(Q + '.ItemClassifications', J);
      V.Visit(R + '.ClassCode', L.ItemClassifications[J].ClassCode, fk_Identifier);
      V.Visit(R + '.ListID', L.ItemClassifications[J].ListID, fk_Identifier);
      V.Visit(R + '.ListVersionID', L.ItemClassifications[J].ListVersionID, fk_Identifier);
      V.Visit(R + '.ClassificationName', L.ItemClassifications[J].ClassificationName, fk_Text);
    end;
    V.Visit(Q + '.OriginTradeCountry', L.OriginTradeCountry, fk_Ascii);
    for J := 0 to Integer(L.ItemAttributes.Count) - 1 do
    begin
      R := Item(Q + '.ItemAttributes', J);
      V.Visit(R + '.Name', L.ItemAttributes[J].Name, fk_Text);
      V.Visit(R + '.Value', L.ItemAttributes[J].Value, fk_Text);
    end;
    V.Visit(Q + '.DeliveryNoteNumber', L.DeliveryNoteNumber, fk_Identifier);
    V.Visit(Q + '.DeliveryNoteLineID', L.DeliveryNoteLineID, fk_Identifier);
    WalkLines(V, L.SubInvoiceLines, Q + '.SubInvoiceLines');
    V.Visit(Q + '.LineStatusReasonCodeOther', L.LineStatusReasonCodeOther, fk_Identifier);
  end;
end;

function IsLetterLike(C: Cardinal): Boolean;
begin
  Result := ((C >= Ord('A')) and (C <= Ord('Z'))) or ((C >= $FF21) and (C <= $FF3A));
end;

function IsDigitLike(C: Cardinal): Boolean;
begin
  Result := ((C >= Ord('0')) and (C <= Ord('9'))) or ((C >= $FF10) and (C <= $FF19));
end;

{ True if AValue starts like an IBAN: two letters and two digits, also in
  their fullwidth forms (which LX-ID-05 then reports). The model does not
  keep whether CII gave the account as IBANID or ProprietaryID.
  DE: True, wenn AValue wie eine IBAN beginnt: zwei Buchstaben und zwei
  Ziffern, auch in ihrer vollbreiten Form (die LX-ID-05 dann meldet). Das
  Modell haelt nicht fest, ob CII das Konto als IBANID oder ProprietaryID
  angab. }
function LooksLikeIban(const AValue: TLandrixEInvoiceString): Boolean;
begin
  Result := (Length(AValue) >= 4) and IsLetterLike(Ord(AValue[1])) and IsLetterLike(Ord(AValue[2])) and
    IsDigitLike(Ord(AValue[3])) and IsDigitLike(Ord(AValue[4]));
end;

{ ASCII by their schemes: country and currency codes (ISO 3166, ISO 4217),
  the account of a SEPA payment (58, 59) or an account that starts like an
  IBAN, the payment service provider (BT-86, a BIC or a national bank code),
  the mandate reference (BT-89) of a SEPA direct debit (SEPA character
  set; not when a general direct debit, 49, is there too, as the model
  keeps one reference). The remittance information (BT-83) is text.
  DE: ASCII nach ihren Schemata: Laender- und Waehrungscodes (ISO 3166,
  ISO 4217), das Konto einer SEPA-Zahlung (58, 59) oder ein Konto, das wie
  eine IBAN beginnt, der Zahlungsdienstleister (BT-86, ein BIC oder eine
  nationale Bankleitzahl), die Mandatsreferenz (BT-89) einer
  SEPA-Lastschrift (SEPA-Zeichensatz; nicht, wenn auch eine allgemeine
  Lastschrift, 49, da ist, weil das Modell eine Referenz haelt). Der
  Verwendungszweck (BT-83) ist Text. }
procedure WalkInvoice(V: TFieldVisitor; A: TLandrixInvoice);
var
  I: Integer;
  Q: string;
  Account, Mandate: TFieldKind;
  General: Boolean;
begin
  V.Visit('ProfileID', A.ProfileID, fk_Identifier);
  V.Visit('InvoiceNumber', A.InvoiceNumber, fk_Identifier);
  V.Visit('DocumentName', A.DocumentName, fk_Text);
  V.Visit('InvoiceTypeCodeOther', A.InvoiceTypeCodeOther, fk_Identifier);
  V.Visit('InvoiceCurrencyCode', A.InvoiceCurrencyCode, fk_Ascii);
  V.Visit('TaxCurrencyCode', A.TaxCurrencyCode, fk_Ascii);
  V.Visit('TaxPointDateCode', A.TaxPointDateCode, fk_Identifier);
  V.Visit('BuyerReference', A.BuyerReference, fk_Identifier);
  for I := 0 to Integer(A.Notes.Count) - 1 do
  begin
    Q := Item('Notes', I);
    V.Visit(Q + '.Content', A.Notes[I].Content, fk_Text);
    V.Visit(Q + '.SubjectCodeOther', A.Notes[I].SubjectCodeOther, fk_Identifier);
  end;
  V.Visit('SellerOrderReference', A.SellerOrderReference, fk_Identifier);
  V.Visit('PurchaseOrderReference', A.PurchaseOrderReference, fk_Identifier);
  V.Visit('ProjectReference', A.ProjectReference, fk_Identifier);
  V.Visit('ReceiptDocumentReference', A.ReceiptDocumentReference, fk_Identifier);
  V.Visit('ContractDocumentReference', A.ContractDocumentReference, fk_Identifier);
  V.Visit('DeliveryReceiptNumber', A.DeliveryReceiptNumber, fk_Identifier);
  V.Visit('DeliveryReceiptNumberExtended', A.DeliveryReceiptNumberExtended, fk_Identifier);
  V.Visit('BuyerAccountingReference', A.BuyerAccountingReference, fk_Identifier);
  WalkAccountingParty(V, A.AccountingSupplierParty, 'AccountingSupplierParty');
  WalkAccountingParty(V, A.AccountingCustomerParty, 'AccountingCustomerParty');
  WalkDelivery(V, A.DeliveryInformation, 'DeliveryInformation');
  WalkParty(V, A.PayeeParty, 'PayeeParty');
  WalkParty(V, A.TaxRepresentativeParty, 'TaxRepresentativeParty');
  WalkParty(V, A.InvoiceeParty, 'InvoiceeParty');
  V.Visit('PaymentID', A.PaymentID, fk_Text);
  Mandate := fk_Identifier;
  General := False;
  for I := 0 to Integer(A.PaymentTypes.Count) - 1 do
  begin
    Q := Item('PaymentTypes', I);
    if A.PaymentTypes[I].PaymentMeansCode = ipmc_SEPADirectDebit then
      Mandate := fk_Ascii
    else if A.PaymentTypes[I].PaymentMeansCode = ipmc_DirectDebit then
      General := True;
    if (A.PaymentTypes[I].PaymentMeansCode in [ipmc_SEPACreditTransfer, ipmc_SEPADirectDebit]) or
       LooksLikeIban(A.PaymentTypes[I].FinancialAccount) then
      Account := fk_Ascii
    else
      Account := fk_Identifier;
    V.Visit(Q + '.PaymentMeansCodeOther', A.PaymentTypes[I].PaymentMeansCodeOther, fk_Identifier);
    V.Visit(Q + '.PaymentMeansInformation', A.PaymentTypes[I].PaymentMeansInformation, fk_Text);
    V.Visit(Q + '.FinancialAccount', A.PaymentTypes[I].FinancialAccount, Account);
    V.Visit(Q + '.FinancialAccountName', A.PaymentTypes[I].FinancialAccountName, fk_Text);
    V.Visit(Q + '.FinancialInstitutionBranch', A.PaymentTypes[I].FinancialInstitutionBranch, fk_Ascii);
  end;
  if General then
    Mandate := fk_Identifier;
  V.Visit('PaymentMandateID', A.PaymentMandateID, Mandate);
  V.Visit('PaymentTermNetNote', A.PaymentTermNetNote, fk_Text);
  V.Visit('PaymentTermCashDiscount1Note', A.PaymentTermCashDiscount1Note, fk_Text);
  V.Visit('PaymentTermCashDiscount2Note', A.PaymentTermCashDiscount2Note, fk_Text);
  V.Visit('PaymentTermCashDiscount3Note', A.PaymentTermCashDiscount3Note, fk_Text);
  WalkLines(V, A.InvoiceLines, 'InvoiceLines');
  for I := 0 to Integer(A.Attachments.Count) - 1 do
  begin
    Q := Item('Attachments', I);
    V.Visit(Q + '.ID', A.Attachments[I].ID, fk_Identifier);
    V.Visit(Q + '.DocumentDescription', A.Attachments[I].DocumentDescription, fk_Text);
    V.Visit(Q + '.Filename', A.Attachments[I].Filename, fk_Identifier);
    V.Visit(Q + '.TypeCodeOther', A.Attachments[I].TypeCodeOther, fk_Identifier);
    V.Visit(Q + '.AttachmentTypeOther', A.Attachments[I].AttachmentTypeOther, fk_Identifier);
    V.Visit(Q + '.ExternalReference', A.Attachments[I].ExternalReference, fk_Identifier);
    V.Visit(Q + '.SchemeID', A.Attachments[I].SchemeID, fk_Identifier);
  end;
  for I := 0 to Integer(A.PrepaidPayments.Count) - 1 do
  begin
    Q := Item('PrepaidPayments', I);
    V.Visit(Q + '.ID', A.PrepaidPayments[I].ID, fk_Identifier);
    V.Visit(Q + '.PaidAmountCurrencyID', A.PrepaidPayments[I].PaidAmountCurrencyID, fk_Ascii);
    V.Visit(Q + '.InstructionID', A.PrepaidPayments[I].InstructionID, fk_Identifier);
  end;
  WalkAllowanceCharges(V, A.AllowanceCharges, 'AllowanceCharges');
  for I := 0 to Integer(A.PrecedingInvoiceReferences.Count) - 1 do
    V.Visit(Item('PrecedingInvoiceReferences', I) + '.ID', A.PrecedingInvoiceReferences[I].ID, fk_Identifier);
  for I := 0 to Integer(A.TaxAmountSubtotals.Count) - 1 do
  begin
    Q := Item('TaxAmountSubtotals', I);
    V.Visit(Q + '.TaxCategoryOther', A.TaxAmountSubtotals[I].TaxCategoryOther, fk_Identifier);
    V.Visit(Q + '.TaxExemptionReason', A.TaxAmountSubtotals[I].TaxExemptionReason, fk_Text);
    V.Visit(Q + '.TaxExemptionReasonCode', A.TaxAmountSubtotals[I].TaxExemptionReasonCode, fk_Identifier);
  end;
end;

{ --- identifiers by their scheme ------------------------------------------- }

type
  TSchemeChecker = class(TObject)
  private
    FDiagnostics: TLandrixEInvoiceDiagnostics;
    FCount: Integer;
    FPeppol: Boolean;
    FXRechnung: Boolean;
    FR040Reported: Boolean;
    procedure Gs1(const ARule, APath, AWhat: string; const AValue: TLandrixEInvoiceString;
      const ALengths: array of Integer; const ALengthText: string; ACheckDigit: Boolean);
    function Leitweg(const APath, AWhat: string; const AValue: TLandrixEInvoiceString;
      ASeverity: TLandrixEInvoiceDiagnosticSeverity; AOnlyCheckDigits: Boolean): Boolean;
    procedure Party(const APath: string; const AValue, AScheme: TLandrixEInvoiceString; ACoveredByPeppol: Boolean);
    procedure ItemIdentifier(const APath: string; const AValue, AScheme: TLandrixEInvoiceString);
    procedure Lines(AList: TLandrixInvoiceLines; const APath: string);
    procedure AccountingParty(A: TLandrixInvoiceAccountingParty; const APath: string);
    procedure OtherParty(A: TLandrixInvoiceParty; const APath: string; ACovered: Boolean);
    procedure BuyerReference(A: TLandrixInvoice);
  public
    procedure Run(A: TLandrixInvoice);
  end;

function AsciiUpper(const AValue: TLandrixEInvoiceString): TLandrixEInvoiceString;
var
  I: Integer;
begin
  Result := AValue;
  for I := 1 to Length(Result) do
    if (Result[I] >= 'a') and (Result[I] <= 'z') then
      Result[I] := TLandrixEInvoiceChar(Ord(Result[I]) - 32);
end;

{ An identifier as a finding shows it: hidden characters and those outside
  ASCII masked.
  DE: Eine Kennung, wie ein Befund sie zeigt: verborgene Zeichen und solche
  ausserhalb von ASCII maskiert. }
function Shown(const AValue: TLandrixEInvoiceString): TLandrixEInvoiceString;
begin
  if AValue = '' then
    Result := ''
  else
    Result := Masked(AValue, 1, [cc_Bidi, cc_Invisible, cc_Space, cc_C1, cc_NonAscii]);
end;

{ A GS1 key (GLN, GTIN): one of ALengths digits and a valid check digit;
  Expected and Found are the check digits. Without ACheckDigit only the
  number of characters (digits and check digit are left to
  PEPPOL-COMMON-R040).
  DE: Ein GS1-Schluessel (GLN, GTIN): eine der Laengen ALengths in Ziffern
  und eine gueltige Pruefziffer; Expected und Found sind die Pruefziffern.
  Ohne ACheckDigit nur die Zahl der Zeichen (Ziffern und Pruefziffer
  bleiben PEPPOL-COMMON-R040). }
procedure TSchemeChecker.Gs1(const ARule, APath, AWhat: string; const AValue: TLandrixEInvoiceString;
  const ALengths: array of Integer; const ALengthText: string; ACheckDigit: Boolean);
var
  I, Digit, Characters, Units: Integer;
  Fits: Boolean;
begin
  { characters, a surrogate pair counts as one
    DE: Zeichen, ein Ersatzpaar zaehlt als eines }
  Characters := 0;
  I := 1;
  while I <= Length(AValue) do
  begin
    CodePointAt(AValue, I, Units);
    Inc(I, Units);
    Inc(Characters);
  end;
  Fits := False;
  for I := Low(ALengths) to High(ALengths) do
    if (ACheckDigit and LandrixEInvoiceIsDigits(AValue, ALengths[I])) or
       (not ACheckDigit and (Characters = ALengths[I])) then
      Fits := True;
  if not Fits then
  begin
    AddHint(FDiagnostics, FCount, ARule, APath, eds_Warning, AWhat + ' is not ' + ALengthText + ' digits', '',
      Shown(AValue));
    Exit;
  end;
  if not ACheckDigit then
    Exit;
  Digit := LandrixEInvoiceGS1CheckDigit(AValue);
  if Digit <> Ord(AValue[Length(AValue)]) - Ord('0') then
    AddHint(FDiagnostics, FCount, ARule, APath, eds_Warning, AWhat + ' has a wrong GS1 check digit',
      TLandrixEInvoiceString(IntToStr(Digit)), Copy(AValue, Length(AValue), 1));
end;

{ A Leitweg-ID, as it is (blanks make it invalid). AOnlyCheckDigits: report
  only wrong check digits (BT-10 that looks like one). True if AValue is a
  valid Leitweg-ID.
  DE: Eine Leitweg-ID, wie sie ist (Leerraum macht sie ungueltig).
  AOnlyCheckDigits: nur falsche Pruefziffern melden (BT-10, die wie eine
  aussieht). True, wenn AValue eine gueltige Leitweg-ID ist. }
function TSchemeChecker.Leitweg(const APath, AWhat: string; const AValue: TLandrixEInvoiceString;
  ASeverity: TLandrixEInvoiceDiagnosticSeverity; AOnlyCheckDigits: Boolean): Boolean;
var
  Expected: TLandrixEInvoiceString;
  Problem: TLandrixEInvoiceLeitwegProblem;
  Coarse: Integer;
begin
  Problem := LandrixEInvoiceLeitwegIDProblem(AValue, Expected);
  Result := Problem = elp_None;
  if Result or (AOnlyCheckDigits and (Problem <> elp_CheckDigits)) then
    Exit;
  case Problem of
    elp_Form:
      AddHint(FDiagnostics, FCount, RuleLeitweg, APath, ASeverity, AWhat +
        ' does not have the form coarse address, fine address (optional) and two check digits, separated by ' +
        'hyphen-minus', '', Shown(AValue));
    elp_CoarseLength:
      begin
        Coarse := Pos(TLandrixEInvoiceString('-'), AValue) - 1;
        AddHint(FDiagnostics, FCount, RuleLeitweg, APath, ASeverity, AWhat + ' has a coarse address of ' +
          IntToStr(Coarse) + ' digits, not 2, 3, 5, 8, 9 or 12', '', Shown(AValue));
      end;
    elp_State:
      AddHint(FDiagnostics, FCount, RuleLeitweg, APath, ASeverity, AWhat + ' starts with ' +
        string(Copy(AValue, 1, 2)) + ', which is no federal state (01 to 16) and not the federation (99)', '',
        Shown(AValue));
  else
    AddHint(FDiagnostics, FCount, RuleLeitweg, APath, ASeverity, AWhat +
      ' has wrong check digits (ISO/IEC 7064 MOD 97-10)', Expected, Copy(AValue, Length(AValue) - 1, 2));
  end;
end;

{ An identifier of a party, location or electronic address with its
  scheme. ACoveredByPeppol: PEPPOL-COMMON-R040 checks its check digit for
  Peppol BIS (with the scheme as written); then LX-ID-06 leaves the check
  digit to it when the rule check runs.
  DE: Eine Kennung eines Beteiligten, Orts oder einer elektronischen
  Adresse mit ihrem Schema. ACoveredByPeppol: PEPPOL-COMMON-R040 prueft
  ihre Pruefziffer fuer Peppol BIS (mit dem Schema, wie geschrieben); dann
  ueberlaesst LX-ID-06 ihr die Pruefziffer, wenn die Regelpruefung
  laeuft. }
procedure TSchemeChecker.Party(const APath: string; const AValue, AScheme: TLandrixEInvoiceString;
  ACoveredByPeppol: Boolean);
var
  Value, Scheme: TLandrixEInvoiceString;
begin
  Value := LandrixEInvoiceNormalizeSpace(AValue);
  Scheme := LandrixEInvoiceNormalizeSpace(AScheme);
  if (Value = '') or (Scheme = '') then
    Exit;
  if Scheme = '0088' then
    Gs1(RuleGln, APath, 'The GLN (scheme 0088)', Value, [13], '13',
      not (FPeppol and FR040Reported and ACoveredByPeppol and (AScheme = '0088')))
  else if Scheme = '0160' then
    AddHint(FDiagnostics, FCount, RuleWrongScheme, APath, eds_Warning,
      'A GTIN (scheme 0160) identifies a trade item, not a party, location or address', '', Shown(Value))
  else if Scheme = '0204' then
    Leitweg(APath, 'The Leitweg-ID (scheme 0204)', AValue, eds_Warning, False);
end;

{ An item identifier (BT-157) with its scheme.
  DE: Eine Artikelkennung (BT-157) mit ihrem Schema. }
procedure TSchemeChecker.ItemIdentifier(const APath: string; const AValue, AScheme: TLandrixEInvoiceString);
var
  Value, Scheme: TLandrixEInvoiceString;
begin
  Value := LandrixEInvoiceNormalizeSpace(AValue);
  Scheme := LandrixEInvoiceNormalizeSpace(AScheme);
  if Value = '' then
    Exit;
  if Scheme = '0160' then
    Gs1(RuleGtin, APath, 'The GTIN (scheme 0160)', Value, [8, 12, 13, 14], '8, 12, 13 or 14', True)
  else if Scheme = '0088' then
    AddHint(FDiagnostics, FCount, RuleWrongScheme, APath, eds_Warning,
      'A GLN (scheme 0088) identifies a party or location, not a trade item', '', Shown(Value))
  else if Scheme = '0204' then
    Leitweg(APath, 'The Leitweg-ID (scheme 0204)', AValue, eds_Warning, False);
end;

procedure TSchemeChecker.Lines(AList: TLandrixInvoiceLines; const APath: string);
var
  I: Integer;
  L: TLandrixInvoiceLine;
  Q: string;
begin
  for I := 0 to Integer(AList.Count) - 1 do
  begin
    L := AList[I];
    Q := Item(APath, I);
    ItemIdentifier(Q + '.StandardItemIdentifier', L.StandardItemIdentifier, L.StandardItemIdentifierSchemeID);
    { the GTIN field is written only without BT-157
      DE: das GTIN-Feld wird nur ohne BT-157 geschrieben }
    if LandrixEInvoiceNormalizeSpace(L.StandardItemIdentifier) = '' then
      ItemIdentifier(Q + '.GlobalID_EAN_GTIN', L.GlobalID_EAN_GTIN, '0160');
    Lines(L.SubInvoiceLines, Q + '.SubInvoiceLines');
  end;
end;

{ The global identifier without scheme is written with 0088 (GLN).
  DE: Die globale Kennung ohne Schema wird mit 0088 (GLN) geschrieben. }
procedure TSchemeChecker.AccountingParty(A: TLandrixInvoiceAccountingParty; const APath: string);
var
  Scheme: TLandrixEInvoiceString;
begin
  Scheme := A.GlobalIdentifierSellerBuyerSchemeID;
  if LandrixEInvoiceNormalizeSpace(Scheme) = '' then
    Scheme := '0088';
  Party(APath + '.GlobalIdentifierSellerBuyer', A.GlobalIdentifierSellerBuyer, Scheme, True);
  Party(APath + '.CompanyID', A.CompanyID, A.CompanyIDSchemeID, True);
  Party(APath + '.ElectronicAddressSellerBuyer', A.ElectronicAddressSellerBuyer,
    A.ElectronicAddressSellerBuyerSchemeID, True);
end;

procedure TSchemeChecker.OtherParty(A: TLandrixInvoiceParty; const APath: string; ACovered: Boolean);
begin
  Party(APath + '.Identifier', A.Identifier, A.IdentifierSchemeID, ACovered);
  Party(APath + '.CompanyID', A.CompanyID, A.CompanyIDSchemeID, ACovered);
end;

{ True if a buyer reference looks like a Leitweg-ID: the form of one with
  a coarse address of 8 or more digits, or of the federation (99...) with a
  fine address; other references of that form (dates, order numbers) are
  left alone.
  DE: True, wenn eine Kaeuferreferenz wie eine Leitweg-ID aussieht: deren
  Form mit einer Grobadressierung aus 8 oder mehr Ziffern, oder des Bundes
  (99...) mit Feinadressierung; andere Referenzen dieser Form (Daten,
  Bestellnummern) bleiben unbeachtet. }
function LooksLikeLeitweg(const AValue: TLandrixEInvoiceString): Boolean;
var
  Expected: TLandrixEInvoiceString;
  First, I, Hyphens: Integer;
begin
  Result := False;
  if not (LandrixEInvoiceLeitwegIDProblem(AValue, Expected) in [elp_None, elp_CheckDigits]) then
    Exit;
  First := Pos(TLandrixEInvoiceString('-'), AValue);
  Hyphens := 0;
  for I := 1 to Length(AValue) do
    if AValue[I] = '-' then
      Inc(Hyphens);
  Result := (First > 8) or ((Copy(AValue, 1, 2) = '99') and (Hyphens = 2));
end;

{ BT-10 when it looks like a Leitweg-ID (a warning for XRechnung, where it
  usually is one, an info otherwise), and a valid one that differs from the
  buyer's Leitweg-ID (BT-49, scheme 0204): the Peppol ID need not be the
  Leitweg-ID (format specification 1.4), so only an info; Expected is the
  buyer's Leitweg-ID, Found BT-10.
  DE: BT-10, wenn sie wie eine Leitweg-ID aussieht (eine Warnung bei
  XRechnung, wo sie meist eine ist, sonst ein Hinweis), und eine gueltige,
  die von der Leitweg-ID des Kaeufers (BT-49, Schema 0204) abweicht: die
  Peppol-ID muss nicht die Leitweg-ID sein (Formatspezifikation 1.4), daher
  nur ein Hinweis; Expected ist die Leitweg-ID des Kaeufers, Found BT-10. }
procedure TSchemeChecker.BuyerReference(A: TLandrixInvoice);
var
  Reference, Address: TLandrixEInvoiceString;
  Expected: TLandrixEInvoiceString;
  Severity: TLandrixEInvoiceDiagnosticSeverity;
begin
  Reference := LandrixEInvoiceNormalizeSpace(A.BuyerReference);
  if LandrixEInvoiceLeitwegIDProblem(Reference, Expected) <> elp_None then
  begin
    if not LooksLikeLeitweg(Reference) then
      Exit;
    if FXRechnung then
      Severity := eds_Warning
    else
      Severity := eds_Info;
    Leitweg('BuyerReference', 'The buyer reference (BT-10) looks like a Leitweg-ID but', Reference, Severity, True);
    Exit;
  end;
  { the comparison takes BT-10 as it is (blanks make it invalid)
    DE: der Vergleich nimmt BT-10, wie sie ist (Leerraum macht sie
    ungueltig) }
  Reference := A.BuyerReference;
  Address := A.AccountingCustomerParty.ElectronicAddressSellerBuyer;
  if (LandrixEInvoiceNormalizeSpace(A.AccountingCustomerParty.ElectronicAddressSellerBuyerSchemeID) = '0204') and
     (LandrixEInvoiceLeitwegIDProblem(Reference, Expected) = elp_None) and
     (LandrixEInvoiceLeitwegIDProblem(Address, Expected) = elp_None) and
     (AsciiUpper(Address) <> AsciiUpper(Reference)) then
    AddHint(FDiagnostics, FCount, RuleLeitwegDiffers, 'BuyerReference', eds_Info,
      'The buyer reference (BT-10) and the electronic address of the buyer (BT-49, scheme 0204) are different ' +
      'Leitweg-IDs; the Peppol ID need not be the Leitweg-ID (Leitweg-ID format specification 1.4), check it',
      Address, Reference);
end;

procedure TSchemeChecker.Run(A: TLandrixInvoice);
begin
  AccountingParty(A.AccountingSupplierParty, 'AccountingSupplierParty');
  AccountingParty(A.AccountingCustomerParty, 'AccountingCustomerParty');
  { PEPPOL-COMMON-R040 covers the payee, not the tax representative and
    the invoicee
    DE: PEPPOL-COMMON-R040 deckt den Zahlungsempfaenger ab, nicht den
    Steuervertreter und den Rechnungsempfaenger }
  OtherParty(A.PayeeParty, 'PayeeParty', True);
  OtherParty(A.TaxRepresentativeParty, 'TaxRepresentativeParty', False);
  OtherParty(A.InvoiceeParty, 'InvoiceeParty', False);
  Party('DeliveryInformation.LocationIdentifier', A.DeliveryInformation.LocationIdentifier,
    A.DeliveryInformation.LocationIdentifierSchemeID, False);
  BuyerReference(A);
  Lines(A.InvoiceLines, 'InvoiceLines');
end;

{ --- entry points ------------------------------------------------------------ }

function LandrixEInvoiceAdvise(AInvoice: TLandrixInvoice; const ATarget: TLandrixEInvoiceTarget;
  AFamilies: TLandrixEInvoiceAdvisoryFamilies; ADiagnostics: TLandrixEInvoiceDiagnostics;
  AR040Reported: Boolean): Integer;
var
  Checker: TCharacterChecker;
  Schemes: TSchemeChecker;
begin
  Result := 0;
  if (AInvoice = nil) or not (eaf_Identifiers in AFamilies) then
    Exit;
  Checker := TCharacterChecker.Create;
  try
    Checker.FDiagnostics := ADiagnostics;
    WalkInvoice(Checker, AInvoice);
    Result := Checker.FCount;
  finally
    Checker.Free;
  end;
  Schemes := TSchemeChecker.Create;
  try
    Schemes.FDiagnostics := ADiagnostics;
    Schemes.FPeppol := ATarget.Standard = est_PeppolBIS;
    Schemes.FXRechnung := ATarget.Standard = est_XRechnung;
    Schemes.FR040Reported := AR040Reported;
    Schemes.Run(AInvoice);
    Inc(Result, Schemes.FCount);
  finally
    Schemes.Free;
  end;
end;

procedure LandrixEInvoiceAdvisoryListFields(AInvoice: TLandrixInvoice; ALines: TStrings);
var
  Lister: TFieldLister;
begin
  Lister := TFieldLister.Create;
  try
    Lister.FLines := ALines;
    WalkInvoice(Lister, AInvoice);
  finally
    Lister.Free;
  end;
end;

end.
