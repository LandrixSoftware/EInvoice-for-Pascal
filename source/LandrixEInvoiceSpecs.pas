{
  EInvoice-for-Pascal

  Copyright (C) 2026 Landrix Software GmbH & Co. KG

  This file is dual-licensed under:
  - GNU GPL version 3 or later; or
  - the Landrix Software Commercial License.

  See LICENSE and COMMERCIAL-LICENSE.md.

  SPDX-License-Identifier: GPL-3.0-or-later OR LicenseRef-Landrix-Commercial
}

{ Specification directory: one entry per supported e-invoice specification
  with the identifiers that are written and recognized, plus the factories
  for targets (TLandrixEInvoiceTargets) and the functions to find an entry
  for a target or for the identifiers of a read document.

  A target is valid only if an entry exists; invalid combinations are
  rejected before anything is written. Entries are static data; nothing is
  registered at run time and nothing depends on the system date. Rules about
  allowed business terms per specification follow with the mapping.

  DE: Spezifikationsverzeichnis: ein Eintrag je unterstuetzter
  E-Rechnungs-Spezifikation mit den Kennungen, die geschrieben und erkannt
  werden, dazu die Fabrikfunktionen fuer Zielangaben
  (TLandrixEInvoiceTargets) und die Funktionen, die den Eintrag zu einer
  Zielangabe oder zu den Kennungen eines gelesenen Dokuments finden.

  Eine Zielangabe ist nur gueltig, wenn es einen Eintrag gibt; ungueltige
  Kombinationen werden abgewiesen, bevor etwas geschrieben wird. Die
  Eintraege sind feste Daten; zur Laufzeit wird nichts registriert, und
  nichts haengt vom Systemdatum ab. Regeln zu den erlaubten
  Geschaeftsbegriffen je Spezifikation folgen mit der Abbildung. }

{ API: stable. Covered by semantic versioning from release 1.0 on.
  DE: API: stabil. Ab Version 1.0 durch die semantische Versionierung
  abgedeckt. }

unit LandrixEInvoiceSpecs;

{$I LandrixEInvoice.inc}

interface

uses
  LandrixEInvoiceTypes;

type
  { An entry of the specification directory.
    DE: Ein Eintrag des Spezifikationsverzeichnisses. }
  TLandrixEInvoiceSpec = record
    { Target of the entry; Version is the key (major.minor, e.g. '3.0').
      DE: Zielangabe des Eintrags; Version ist der Schluessel (Haupt- und
      Nebenversion, z. B. '3.0'). }
    Target: TLandrixEInvoiceTarget;
    { Exact release the entry was built and checked against, e.g. '3.0.2'.
      DE: Genauer Stand, gegen den der Eintrag gebaut und geprueft wurde,
      z. B. '3.0.2'. }
    ExactVersion: TLandrixEInvoiceString;
    { BT-24 specification identifier: UBL cbc:CustomizationID, CII
      GuidelineSpecifiedDocumentContextParameter/ram:ID.
      DE: BT-24 Spezifikationskennung: UBL cbc:CustomizationID, CII
      GuidelineSpecifiedDocumentContextParameter/ram:ID. }
    CustomizationID: TLandrixEInvoiceString;
    { BT-24 identifier when the XRechnung extension is used ('' if the
      specification has no extension). DE: BT-24-Kennung, wenn die
      XRechnung-Extension verwendet wird ('' ohne Extension). }
    ExtensionCustomizationID: TLandrixEInvoiceString;
    { Default BT-23 business process type ('' if none). DE: Standardwert fuer
      BT-23 Geschaeftsprozesstyp ('' wenn keiner). }
    ProfileID: TLandrixEInvoiceString;
    { Syntax release, e.g. UBL 2.1 or CII D16B. DE: Stand der Syntax, z. B.
      UBL 2.1 oder CII D16B. }
    SyntaxVersion: TLandrixEInvoiceString;
    { Edition of EN 16931-1. DE: Ausgabe der EN 16931-1. }
    NormVersion: TLandrixEInvoiceString;
    { File name of the XML in a PDF/A-3 ('' if not embedded).
      DE: Dateiname des XML in einem PDF/A-3 ('' wenn nicht eingebettet). }
    AttachmentFileName: TLandrixEInvoiceString;
    { ZUGFeRD release that corresponds to the entry ('' if none), e.g. '2.5'
      for Factur-X 1.09; on the XRechnung CII entry the ZUGFeRD release whose
      profile XRECHNUNG refers to it.
      DE: Entsprechende ZUGFeRD-Version ('' wenn keine), z. B. '2.5' fuer
      Factur-X 1.09; beim Eintrag XRechnung CII die ZUGFeRD-Version, deren
      Profil XRECHNUNG darauf verweist. }
    ZUGFeRDVersion: TLandrixEInvoiceString;
    { Code list versions the specification refers to, separated by spaces
      (KoSIT URNs for XRechnung; '' if not recorded).
      DE: Codelistenstaende, auf die sich die Spezifikation bezieht, durch
      Leerzeichen getrennt (KoSIT-URNs fuer XRechnung; '' wenn nicht
      erfasst). }
    CodeLists: TLandrixEInvoiceString;
    { The library reads / writes this specification. DE: Die Bibliothek
      liest / schreibt diese Spezifikation. }
    CanRead: Boolean;
    CanWrite: Boolean;
  end;

  { Factories for targets. DE: Fabrikfunktionen fuer Zielangaben. }
  TLandrixEInvoiceTargets = class(TObject)
  public
    { XRechnung in UBL or CII, e.g. XRechnung('3.0.2', esy_UBL).
      DE: XRechnung in UBL oder CII, z. B. XRechnung('3.0.2', esy_UBL). }
    class function XRechnung(const AVersion: TLandrixEInvoiceString;
      ASyntax: TLandrixEInvoiceSyntax): TLandrixEInvoiceTarget;
    { Factur-X (always CII) with a profile, e.g. FacturX('1.09', epr_Extended).
      DE: Factur-X (immer CII) mit Profil, z. B. FacturX('1.09',
      epr_Extended). }
    class function FacturX(const AVersion: TLandrixEInvoiceString;
      AProfile: TLandrixEInvoiceProfile): TLandrixEInvoiceTarget;
    { ZUGFeRD release and profile, translated to the Factur-X target of the
      same release (ZUGFeRD('2.5', epr_EN16931) = FacturX('1.09',
      epr_EN16931)); the profile epr_XRechnung gives the XRechnung CII target
      the release refers to. An unknown release gives a target that matches
      no entry.
      DE: ZUGFeRD-Version und Profil, uebersetzt in das Factur-X-Ziel
      desselben Stands (ZUGFeRD('2.5', epr_EN16931) = FacturX('1.09',
      epr_EN16931)); das Profil epr_XRechnung ergibt das Ziel XRechnung in
      CII, auf das der Stand verweist. Ein unbekannter Stand ergibt eine
      Zielangabe ohne passenden Eintrag. }
    class function ZUGFeRD(const AVersion: TLandrixEInvoiceString;
      AProfile: TLandrixEInvoiceProfile): TLandrixEInvoiceTarget;
    { Peppol BIS Billing (always UBL), e.g. PeppolBIS('3.0').
      DE: Peppol BIS Billing (immer UBL), z. B. PeppolBIS('3.0'). }
    class function PeppolBIS(const AVersion: TLandrixEInvoiceString): TLandrixEInvoiceTarget;
  end;

{ True if both targets have the same standard, syntax and profile and the
  same major and minor version. If a version has no valid major.minor form,
  the version strings are compared exactly.
  DE: True, wenn beide Zielangaben denselben Standard, dieselbe Syntax,
  dasselbe Profil und dieselbe Haupt- und Nebenversion haben. Hat eine
  Version keine gueltige Form Haupt.Neben, werden die Versionstexte exakt
  verglichen. }
function LandrixEInvoiceSameTarget(const A, B: TLandrixEInvoiceTarget): Boolean;

{ Readable name of a target for messages, e.g. 'XRechnung 3.0.2 UBL' or
  'Factur-X 1.09 EXTENDED'.
  DE: Lesbarer Name einer Zielangabe fuer Meldungen, z. B. 'XRechnung 3.0.2
  UBL' oder 'Factur-X 1.09 EXTENDED'. }
function LandrixEInvoiceTargetToStr(const ATarget: TLandrixEInvoiceTarget): TLandrixEInvoiceString;

{ Finds the entry for a target. Returns False if there is none (the target
  is invalid); ASpec is then empty (Target.Standard = est_None, CanRead and
  CanWrite False).
  DE: Sucht den Eintrag zu einer Zielangabe. Liefert False, wenn es keinen
  gibt (die Zielangabe ist ungueltig); ASpec ist dann leer (Target.Standard
  = est_None, CanRead und CanWrite False). }
function LandrixEInvoiceFindSpec(const ATarget: TLandrixEInvoiceTarget;
  out ASpec: TLandrixEInvoiceSpec): Boolean;

{ Finds the entry for a read document from the local name of its root
  element (Invoice, CreditNote or CrossIndustryInvoice) and its BT-24
  identifier (ASCII case-insensitive, surrounding white space ignored).
  AUsesExtension is True if the identifier is the one of the XRechnung
  extension. Returns False and an empty ASpec for an unknown combination.
  DE: Sucht den Eintrag zu einem gelesenen Dokument anhand des lokalen Namens
  des Wurzelelements (Invoice, CreditNote oder CrossIndustryInvoice) und
  seiner BT-24-Kennung (ASCII, ohne Unterscheidung von Gross- und
  Kleinschreibung, Leerraum am Rand wird ignoriert). AUsesExtension ist
  True, wenn es die Kennung der XRechnung-Extension ist. Liefert False und
  ein leeres ASpec bei unbekannter Kombination. }
function LandrixEInvoiceDetectSpec(const ARootLocalName, ACustomizationID: TLandrixEInvoiceString;
  out ASpec: TLandrixEInvoiceSpec; out AUsesExtension: Boolean): Boolean;

const
  { XMP extension schema of Factur-X / ZUGFeRD (prefix fx) for the
    pdfaExtension:schemas list of a PDF/A-3, one rdf:li element; it declares
    the properties that LandrixEInvoicePdfXmpDescription fills.
    DE: XMP-Erweiterungsschema von Factur-X / ZUGFeRD (Praefix fx) fuer die
    Liste pdfaExtension:schemas eines PDF/A-3, ein rdf:li-Element; es
    deklariert die Eigenschaften, die LandrixEInvoicePdfXmpDescription
    fuellt. }
  LandrixEInvoicePdfXmpSchema =
    '<rdf:li rdf:parseType="Resource">' + #10 +
    '<pdfaSchema:schema>Factur-X PDFA Extension Schema</pdfaSchema:schema>' + #10 +
    '<pdfaSchema:namespaceURI>urn:factur-x:pdfa:CrossIndustryDocument:invoice:1p0#</pdfaSchema:namespaceURI>' + #10 +
    '<pdfaSchema:prefix>fx</pdfaSchema:prefix>' + #10 +
    '<pdfaSchema:property>' + #10 +
    '<rdf:Seq>' + #10 +
    '<rdf:li rdf:parseType="Resource">' + #10 +
    '<pdfaProperty:name>DocumentFileName</pdfaProperty:name>' + #10 +
    '<pdfaProperty:valueType>Text</pdfaProperty:valueType>' + #10 +
    '<pdfaProperty:category>external</pdfaProperty:category>' + #10 +
    '<pdfaProperty:description>name of the embedded XML invoice file</pdfaProperty:description>' + #10 +
    '</rdf:li>' + #10 +
    '<rdf:li rdf:parseType="Resource">' + #10 +
    '<pdfaProperty:name>DocumentType</pdfaProperty:name>' + #10 +
    '<pdfaProperty:valueType>Text</pdfaProperty:valueType>' + #10 +
    '<pdfaProperty:category>external</pdfaProperty:category>' + #10 +
    '<pdfaProperty:description>INVOICE</pdfaProperty:description>' + #10 +
    '</rdf:li>' + #10 +
    '<rdf:li rdf:parseType="Resource">' + #10 +
    '<pdfaProperty:name>Version</pdfaProperty:name>' + #10 +
    '<pdfaProperty:valueType>Text</pdfaProperty:valueType>' + #10 +
    '<pdfaProperty:category>external</pdfaProperty:category>' + #10 +
    '<pdfaProperty:description>The actual version of the ZUGFeRD data</pdfaProperty:description>' + #10 +
    '</rdf:li>' + #10 +
    '<rdf:li rdf:parseType="Resource">' + #10 +
    '<pdfaProperty:name>ConformanceLevel</pdfaProperty:name>' + #10 +
    '<pdfaProperty:valueType>Text</pdfaProperty:valueType>' + #10 +
    '<pdfaProperty:category>external</pdfaProperty:category>' + #10 +
    '<pdfaProperty:description>The conformance level of the ZUGFeRD data</pdfaProperty:description>' + #10 +
    '</rdf:li>' + #10 +
    '</rdf:Seq>' + #10 +
    '</pdfaSchema:property>' + #10 +
    '</rdf:li>';

{ XMP description (rdf:Description, prefix fx) for a PDF/A-3 with the
  embedded invoice of ATarget: document type INVOICE, the attachment file
  name of the entry (factur-x.xml, for XRechnung CII xrechnung.xml),
  version 1.0 and the conformance level (MINIMUM, BASIC WL, BASIC,
  EN 16931, EXTENDED or XRECHNUNG). '' if the target has no entry or is not
  embedded in a PDF (UBL). Lines end with LF.
  DE: XMP-Beschreibung (rdf:Description, Praefix fx) fuer ein PDF/A-3 mit
  der eingebetteten Rechnung von ATarget: Dokumentart INVOICE, der
  Anhangsname des Eintrags (factur-x.xml, bei XRechnung CII xrechnung.xml),
  Version 1.0 und die Konformitaetsstufe (MINIMUM, BASIC WL, BASIC,
  EN 16931, EXTENDED oder XRECHNUNG). '' wenn es keinen Eintrag gibt oder
  das Ziel nicht in ein PDF eingebettet wird (UBL). Zeilen enden mit LF. }
function LandrixEInvoicePdfXmpDescription(const ATarget: TLandrixEInvoiceTarget): TLandrixEInvoiceString;

{ Number of entries and entry by index (0 .. Count - 1).
  DE: Anzahl der Eintraege und Eintrag nach Index (0 .. Count - 1). }
function LandrixEInvoiceSpecCount: Integer;
function LandrixEInvoiceSpec(AIndex: Integer): TLandrixEInvoiceSpec;

implementation

uses
  SysUtils;

const
  CXRechnung30 = 'urn:cen.eu:en16931:2017#compliant#urn:xeinkauf.de:kosit:xrechnung_3.0';
  CXRechnung30Extension = CXRechnung30 + '#conformant#urn:xeinkauf.de:kosit:extension:xrechnung_3.0';
  CPeppolProcess = 'urn:fdc:peppol.eu:2017:poacc:billing:01:1.0';
  CNorm2017 = 'EN 16931-1:2017';

  { XRechnung 3.0.2, model of the bundle of 2026-08-31 }
  CXRechnung302CodeLists =
    'urn:xoev-de:kosit:codeliste:country-codes_8 ' +
    'urn:xoev-de:kosit:codeliste:currency-codes_3 ' +
    'urn:xoev-de:kosit:codeliste:eas_5 ' +
    'urn:xoev-de:kosit:codeliste:icd_5 ' +
    'urn:xoev-de:kosit:codeliste:rec20_3 ' +
    'urn:xoev-de:kosit:codeliste:rec21_3 ' +
    'urn:xoev-de:kosit:codeliste:untdid.1001_4 ' +
    'urn:xoev-de:kosit:codeliste:untdid.1153_3 ' +
    'urn:xoev-de:kosit:codeliste:untdid.2005_4 ' +
    'urn:xoev-de:kosit:codeliste:untdid.4451_4 ' +
    'urn:xoev-de:kosit:codeliste:untdid.5189_3 ' +
    'urn:xoev-de:kosit:codeliste:untdid.5305_3 ' +
    'urn:xoev-de:kosit:codeliste:untdid.7143_4 ' +
    'urn:xoev-de:kosit:codeliste:untdid.7161_3 ' +
    'urn:xoev-de:kosit:codeliste:vatex_1 ' +
    'urn:xoev-de:xrechnung:codeliste:untdid.4461_3';

  SpecCount = 8;

  { Factur-X MINIMUM and BASIC WL have no invoice lines; in Germany they do
    not count as e-invoices since 2025 (BMF letter of 15 October 2024), in
    France they serve as booking aid. The library writes them when asked and
    does not judge the jurisdiction.
    DE: Factur-X MINIMUM und BASIC WL haben keine Positionen; in Deutschland
    gelten sie seit 2025 nicht als E-Rechnung (BMF-Schreiben vom 15. Oktober
    2024), in Frankreich dienen sie als Buchungshilfe. Die Bibliothek
    schreibt sie auf Anforderung und beurteilt die Rechtslage nicht. }
  Specs: array[0..SpecCount - 1] of TLandrixEInvoiceSpec = (
    (Target: (Standard: est_XRechnung; Syntax: esy_UBL; Profile: epr_None; Version: '3.0');
     ExactVersion: '3.0.2';
     CustomizationID: CXRechnung30;
     ExtensionCustomizationID: CXRechnung30Extension;
     ProfileID: CPeppolProcess;
     SyntaxVersion: 'UBL 2.1';
     NormVersion: CNorm2017;
     AttachmentFileName: '';
     ZUGFeRDVersion: '';
     CodeLists: CXRechnung302CodeLists;
     CanRead: True;
     CanWrite: True),
    (Target: (Standard: est_XRechnung; Syntax: esy_CII; Profile: epr_None; Version: '3.0');
     ExactVersion: '3.0.2';
     CustomizationID: CXRechnung30;
     ExtensionCustomizationID: CXRechnung30Extension;
     ProfileID: CPeppolProcess;
     SyntaxVersion: 'CII D16B';
     NormVersion: CNorm2017;
     AttachmentFileName: 'xrechnung.xml';
     ZUGFeRDVersion: '2.5';
     CodeLists: CXRechnung302CodeLists;
     CanRead: True;
     CanWrite: True),
    (Target: (Standard: est_FacturX; Syntax: esy_CII; Profile: epr_Minimum; Version: '1.09');
     ExactVersion: '1.09.2';
     CustomizationID: 'urn:factur-x.eu:1p0:minimum';
     ExtensionCustomizationID: '';
     ProfileID: '';
     SyntaxVersion: 'CII D22B';
     NormVersion: CNorm2017;
     AttachmentFileName: 'factur-x.xml';
     ZUGFeRDVersion: '2.5';
     CodeLists: '';
     CanRead: True;
     CanWrite: True),
    (Target: (Standard: est_FacturX; Syntax: esy_CII; Profile: epr_BasicWL; Version: '1.09');
     ExactVersion: '1.09.2';
     CustomizationID: 'urn:factur-x.eu:1p0:basicwl';
     ExtensionCustomizationID: '';
     ProfileID: '';
     SyntaxVersion: 'CII D22B';
     NormVersion: CNorm2017;
     AttachmentFileName: 'factur-x.xml';
     ZUGFeRDVersion: '2.5';
     CodeLists: '';
     CanRead: True;
     CanWrite: True),
    (Target: (Standard: est_FacturX; Syntax: esy_CII; Profile: epr_Basic; Version: '1.09');
     ExactVersion: '1.09.2';
     CustomizationID: 'urn:cen.eu:en16931:2017#compliant#urn:factur-x.eu:1p0:basic';
     ExtensionCustomizationID: '';
     ProfileID: '';
     SyntaxVersion: 'CII D22B';
     NormVersion: CNorm2017;
     AttachmentFileName: 'factur-x.xml';
     ZUGFeRDVersion: '2.5';
     CodeLists: '';
     CanRead: True;
     CanWrite: True),
    (Target: (Standard: est_FacturX; Syntax: esy_CII; Profile: epr_EN16931; Version: '1.09');
     ExactVersion: '1.09.2';
     CustomizationID: 'urn:cen.eu:en16931:2017';
     ExtensionCustomizationID: '';
     ProfileID: '';
     SyntaxVersion: 'CII D22B';
     NormVersion: CNorm2017;
     AttachmentFileName: 'factur-x.xml';
     ZUGFeRDVersion: '2.5';
     CodeLists: '';
     CanRead: True;
     CanWrite: True),
    (Target: (Standard: est_FacturX; Syntax: esy_CII; Profile: epr_Extended; Version: '1.09');
     ExactVersion: '1.09.2';
     CustomizationID: 'urn:cen.eu:en16931:2017#conformant#urn:factur-x.eu:1p0:extended';
     ExtensionCustomizationID: '';
     ProfileID: '';
     SyntaxVersion: 'CII D22B';
     NormVersion: CNorm2017;
     AttachmentFileName: 'factur-x.xml';
     ZUGFeRDVersion: '2.5';
     CodeLists: '';
     CanRead: True;
     CanWrite: True),
    (Target: (Standard: est_PeppolBIS; Syntax: esy_UBL; Profile: epr_None; Version: '3.0');
     ExactVersion: '3.0';
     CustomizationID: 'urn:cen.eu:en16931:2017#compliant#urn:fdc:peppol.eu:2017:poacc:billing:3.0';
     ExtensionCustomizationID: '';
     ProfileID: CPeppolProcess;
     SyntaxVersion: 'UBL 2.1';
     NormVersion: CNorm2017;
     AttachmentFileName: '';
     ZUGFeRDVersion: '';
     CodeLists: '';
     CanRead: True;
     CanWrite: True)
  );

{ --- helpers ------------------------------------------------------------ }

function IsDigit(C: WideChar): Boolean;
begin
  Result := (C >= '0') and (C <= '9');
end;

{ A patch level: digits only, or 'x'. }
function IsPatch(const S: TLandrixEInvoiceString): Boolean;
var
  I: Integer;
begin
  Result := (S = 'x') or (S = 'X');
  if Result or (S = '') then
    Exit;
  for I := 1 to Length(S) do
    if not IsDigit(S[I]) then
      Exit;
  Result := True;
end;

{ 'major.minor' of a version 'major.minor' or 'major.minor.patch' with
  numeric parts; the patch may also be 'x' ('3.0.2' and '3.0.x' -> '3.0').
  '' for anything else. }
function MajorMinor(const AVersion: TLandrixEInvoiceString): TLandrixEInvoiceString;
var
  I, Dots: Integer;
  PartLen: Integer;
begin
  Result := '';
  Dots := 0;
  PartLen := 0;
  for I := 1 to Length(AVersion) do
  begin
    if AVersion[I] = '.' then
    begin
      if PartLen = 0 then
        Exit;
      Inc(Dots);
      if Dots = 2 then
      begin
        if IsPatch(Copy(AVersion, I + 1, MaxInt)) then
          Result := Copy(AVersion, 1, I - 1);
        Exit;
      end;
      PartLen := 0;
    end
    else if IsDigit(AVersion[I]) then
      Inc(PartLen)
    else
      Exit;
  end;
  if (Dots = 1) and (PartLen > 0) then
    Result := AVersion;
end;

function AsciiUpper(C: WideChar): WideChar;
begin
  if (C >= 'a') and (C <= 'z') then
    Result := WideChar(Ord(C) - 32)
  else
    Result := C;
end;

function SameAsciiText(const A, B: TLandrixEInvoiceString): Boolean;
var
  I: Integer;
begin
  Result := Length(A) = Length(B);
  I := 1;
  while Result and (I <= Length(A)) do
  begin
    Result := AsciiUpper(A[I]) = AsciiUpper(B[I]);
    Inc(I);
  end;
end;

function MakeTarget(AStandard: TLandrixEInvoiceStandard; ASyntax: TLandrixEInvoiceSyntax;
  AProfile: TLandrixEInvoiceProfile; const AVersion: TLandrixEInvoiceString): TLandrixEInvoiceTarget;
begin
  Result.Standard := AStandard;
  Result.Syntax := ASyntax;
  Result.Profile := AProfile;
  Result.Version := AVersion;
end;

function EmptySpec: TLandrixEInvoiceSpec;
begin
  Result.Target := MakeTarget(est_None, esy_None, epr_None, '');
  Result.ExactVersion := '';
  Result.CustomizationID := '';
  Result.ExtensionCustomizationID := '';
  Result.ProfileID := '';
  Result.SyntaxVersion := '';
  Result.NormVersion := '';
  Result.AttachmentFileName := '';
  Result.ZUGFeRDVersion := '';
  Result.CodeLists := '';
  Result.CanRead := False;
  Result.CanWrite := False;
end;

{ Removes white space (<= #32) at both ends. }
function TrimSpace(const S: TLandrixEInvoiceString): TLandrixEInvoiceString;
var
  First, Last: Integer;
begin
  First := 1;
  Last := Length(S);
  while (First <= Last) and (Ord(S[First]) <= 32) do
    Inc(First);
  while (Last >= First) and (Ord(S[Last]) <= 32) do
    Dec(Last);
  Result := Copy(S, First, Last - First + 1);
end;

{ --- TLandrixEInvoiceTargets -------------------------------------------- }

class function TLandrixEInvoiceTargets.XRechnung(const AVersion: TLandrixEInvoiceString;
  ASyntax: TLandrixEInvoiceSyntax): TLandrixEInvoiceTarget;
begin
  Result := MakeTarget(est_XRechnung, ASyntax, epr_None, AVersion);
end;

class function TLandrixEInvoiceTargets.FacturX(const AVersion: TLandrixEInvoiceString;
  AProfile: TLandrixEInvoiceProfile): TLandrixEInvoiceTarget;
begin
  Result := MakeTarget(est_FacturX, esy_CII, AProfile, AVersion);
end;

class function TLandrixEInvoiceTargets.ZUGFeRD(const AVersion: TLandrixEInvoiceString;
  AProfile: TLandrixEInvoiceProfile): TLandrixEInvoiceTarget;
var
  Key: TLandrixEInvoiceString;
  I: Integer;
begin
  Key := MajorMinor(AVersion);
  if Key <> '' then
    for I := 0 to SpecCount - 1 do
      if Specs[I].ZUGFeRDVersion = Key then
      begin
        if (AProfile = epr_XRechnung) and (Specs[I].Target.Standard = est_XRechnung) then
        begin
          Result := Specs[I].Target;
          Exit;
        end;
        { the release decides the Factur-X version, independent of whether
          the profile has an entry yet }
        if (AProfile <> epr_XRechnung) and (Specs[I].Target.Standard = est_FacturX) then
        begin
          Result := MakeTarget(est_FacturX, esy_CII, AProfile, Specs[I].Target.Version);
          Exit;
        end;
      end;
  { no entry: keep the ZUGFeRD release visible in messages, matching nothing }
  Result := MakeTarget(est_FacturX, esy_CII, AProfile, 'ZUGFeRD ' + AVersion);
end;

class function TLandrixEInvoiceTargets.PeppolBIS(const AVersion: TLandrixEInvoiceString): TLandrixEInvoiceTarget;
begin
  Result := MakeTarget(est_PeppolBIS, esy_UBL, epr_None, AVersion);
end;

{ --- functions ---------------------------------------------------------- }

function LandrixEInvoiceSameTarget(const A, B: TLandrixEInvoiceTarget): Boolean;
var
  KeyA, KeyB: TLandrixEInvoiceString;
begin
  Result := (A.Standard = B.Standard) and (A.Syntax = B.Syntax) and (A.Profile = B.Profile);
  if not Result then
    Exit;
  KeyA := MajorMinor(A.Version);
  KeyB := MajorMinor(B.Version);
  if (KeyA = '') or (KeyB = '') then
    Result := A.Version = B.Version
  else
    Result := KeyA = KeyB;
end;

function LandrixEInvoiceTargetToStr(const ATarget: TLandrixEInvoiceTarget): TLandrixEInvoiceString;
const
  StandardNames: array[TLandrixEInvoiceStandard] of string = (
    '(no standard)', 'XRechnung', 'Factur-X', 'Peppol BIS');
  SyntaxNames: array[TLandrixEInvoiceSyntax] of string = (
    '', 'UBL', 'CII');
  ProfileNames: array[TLandrixEInvoiceProfile] of string = (
    '', 'MINIMUM', 'BASIC WL', 'BASIC', 'EN16931', 'EXTENDED', 'XRECHNUNG');
begin
  Result := TLandrixEInvoiceString(StandardNames[ATarget.Standard]);
  if ATarget.Version <> '' then
    Result := Result + ' ' + ATarget.Version;
  { the syntax is part of the name only where the standard allows both }
  if (ATarget.Standard <> est_FacturX) and (ATarget.Standard <> est_PeppolBIS) and
     (ATarget.Syntax <> esy_None) then
    Result := Result + ' ' + TLandrixEInvoiceString(SyntaxNames[ATarget.Syntax]);
  if ATarget.Profile <> epr_None then
    Result := Result + ' ' + TLandrixEInvoiceString(ProfileNames[ATarget.Profile]);
end;

function LandrixEInvoiceFindSpec(const ATarget: TLandrixEInvoiceTarget;
  out ASpec: TLandrixEInvoiceSpec): Boolean;
var
  Key: TLandrixEInvoiceString;
  I: Integer;
begin
  Key := MajorMinor(ATarget.Version);
  if Key <> '' then
    for I := 0 to SpecCount - 1 do
      if (Specs[I].Target.Standard = ATarget.Standard) and
         (Specs[I].Target.Syntax = ATarget.Syntax) and
         (Specs[I].Target.Profile = ATarget.Profile) and
         (Specs[I].Target.Version = Key) then
      begin
        ASpec := Specs[I];
        Result := True;
        Exit;
      end;
  ASpec := EmptySpec;
  Result := False;
end;

function LandrixEInvoiceDetectSpec(const ARootLocalName, ACustomizationID: TLandrixEInvoiceString;
  out ASpec: TLandrixEInvoiceSpec; out AUsesExtension: Boolean): Boolean;
var
  Syntax: TLandrixEInvoiceSyntax;
  ID: TLandrixEInvoiceString;
  I: Integer;
begin
  Result := False;
  AUsesExtension := False;
  ASpec := EmptySpec;
  ID := TrimSpace(ACustomizationID);
  if (ARootLocalName = 'Invoice') or (ARootLocalName = 'CreditNote') then
    Syntax := esy_UBL
  else if ARootLocalName = 'CrossIndustryInvoice' then
    Syntax := esy_CII
  else
    Exit;
  for I := 0 to SpecCount - 1 do
    if Specs[I].Target.Syntax = Syntax then
    begin
      if SameAsciiText(Specs[I].CustomizationID, ID) then
      begin
        ASpec := Specs[I];
        Result := True;
        Exit;
      end;
      if (Specs[I].ExtensionCustomizationID <> '') and
         SameAsciiText(Specs[I].ExtensionCustomizationID, ID) then
      begin
        ASpec := Specs[I];
        AUsesExtension := True;
        Result := True;
        Exit;
      end;
    end;
end;

function LandrixEInvoicePdfXmpDescription(const ATarget: TLandrixEInvoiceTarget): TLandrixEInvoiceString;
const
  { Conformance levels as the Factur-X specification spells them in the
    PDF/A-3 metadata: 'EN 16931' with a blank, unlike ProfileNames.
    DE: Konformitaetsstufen, wie die Factur-X-Spezifikation sie in den
    PDF/A-3-Metadaten schreibt: 'EN 16931' mit Leerzeichen, anders als
    ProfileNames. }
  Levels: array[TLandrixEInvoiceProfile] of string = (
    '', 'MINIMUM', 'BASIC WL', 'BASIC', 'EN 16931', 'EXTENDED', 'XRECHNUNG');
var
  Spec: TLandrixEInvoiceSpec;
  Level: TLandrixEInvoiceString;
begin
  Result := '';
  if not LandrixEInvoiceFindSpec(ATarget, Spec) or (Spec.AttachmentFileName = '') then
    Exit;
  if Spec.Target.Standard = est_XRechnung then
    Level := 'XRECHNUNG'
  else
    Level := TLandrixEInvoiceString(Levels[Spec.Target.Profile]);
  if Level = '' then
    Exit;
  Result := '<rdf:Description xmlns:fx="urn:factur-x:pdfa:CrossIndustryDocument:invoice:1p0#" rdf:about="">' +
    #10 + '<fx:DocumentType>INVOICE</fx:DocumentType>' +
    #10 + '<fx:DocumentFileName>' + Spec.AttachmentFileName + '</fx:DocumentFileName>' +
    #10 + '<fx:Version>1.0</fx:Version>' +
    #10 + '<fx:ConformanceLevel>' + Level + '</fx:ConformanceLevel></rdf:Description>';
end;

function LandrixEInvoiceSpecCount: Integer;
begin
  Result := SpecCount;
end;

function LandrixEInvoiceSpec(AIndex: Integer): TLandrixEInvoiceSpec;
begin
  if (AIndex < 0) or (AIndex >= SpecCount) then
    raise ELandrixEInvoiceError.CreateFmt('Specification index %d out of range', [AIndex]);
  Result := Specs[AIndex];
end;

end.
