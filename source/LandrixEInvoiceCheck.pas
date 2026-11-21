{
  EInvoice-for-Pascal

  Copyright (C) 2026 Landrix Software GmbH & Co. KG

  This file is dual-licensed under:
  - GNU GPL version 3 or later; or
  - the Landrix Software Commercial License.

  See LICENSE and COMMERCIAL-LICENSE.md.

  SPDX-License-Identifier: GPL-3.0-or-later OR LicenseRef-Landrix-Commercial
}

{ Business rule checks of an invoice against a target specification. Each
  rule has a stable identifier: the official one (e.g. BR-DE-15) or LX-...
  for rules of this library. A violation is reported as edk_RuleViolation
  with the identifier in RuleID and the severity of the rule. The checks
  only report; they never change the invoice. Which rules are implemented
  is listed in docs/checking.md; a clean result means that
  the implemented rules hold, not that a validator will accept the output.

  The official rules judge the invoice as the mappers would write it to the
  target: blank text (LandrixEInvoiceIsBlank) is absent, a rule the mappers
  always meet has no row (BR-01, BR-12 to BR-15, BR-22, BR-24, BR-26,
  BR-31, BR-36, BR-41, BR-43, BR-45, BR-46, BR-48, BR-49, BR-50, BR-CO-05
  to BR-CO-08 (their schematron test is true), BR-CO-19, BR-CO-20 (an empty
  period is not written), BR-DE-14, BR-DE-21,
  PEPPOL-EN16931-R001, R008 (no empty elements), R043, R044 (the charge
  indicator), R053 in CII, R101 (a line document reference has type 130)),
  and where the syntaxes differ
  the row follows the validator of each syntax (e.g. BR-DE-23-b, BR-DE-30).
  The PEPPOL-EN16931 rules of the XRechnung schematron apply to XRechnung
  and Peppol; they compare amounts, prices and quantities exactly as
  written (xs:decimal, divisions as Saxon computes them: 18 decimals,
  rounded half down).
  The Factur-X profiles get the rules their schematron contains. BR-29,
  BR-30, BR-65 and BR-CO-03 are checked on the model: the mappers leave a reversed
  period or a classification without scheme out instead of writing it
  invalid, so the rule reports content that would be lost. The
  calculation rules BR-CO-10 to BR-CO-17 (Factur-X EXTENDED: BR-FXEXT-CO-10
  to 13, 15 and 16 with their tolerance, XRechnung UBL with third-party payments:
  BR-DEX-09) compare the amounts as they are written (two decimals). The
  VAT category rules BR-S-nn to BR-AG-nn (S, Z, E, AE, IC, G, O, AF, AG)
  and BR-FXEXT-xx-01 of Factur-X EXTENDED have no rows: their identifiers
  come from the group and the number, and each follows the schematron of
  its syntax, which differ in context and tolerance; BR-B-01, BR-B-02,
  BR-CO-03, BR-CO-04, BR-CO-09, BR-CO-18, BR-CO-21 to BR-CO-26 and
  BR-FXEXT-CO-04 have rows. The format rules BR-DE-17, BR-DE-19,
  BR-DE-20, BR-DE-27, BR-DE-28 (warnings) and BR-51 (UBL warning, CII
  error) follow the KoSIT functions and patterns. The code list rules
  BR-CL-01 to BR-CL-26 apply to XRechnung and Peppol (the Factur-X
  schematron checks codes with rules of its own, FX-SCH-A-..., which
  LandrixEInvoiceCIICodeRules checks on the CII syntax model, see
  LandrixEInvoiceCheckCII); they use the lists of the validators, which
  differ slightly from the code lists of the library (see CodeListed), and
  the levels of the XRechnung configuration: BR-CL-21 and BR-CL-23 are
  warnings there, and its extension scenario replaces BR-CL-10, 11, 21,
  24, 25 and 26 by BR-DEX-04, 05, 06, 01, 07 and 08 (the same checks with
  the extension codes).

  The rules LX-CC-01 to LX-CC-12 are the checks of
  TXRechnungInvoiceAdapter.ConsistencyCheck of XRechnung-for-Delphi. They
  are policies of that library, not published rules, so
  LandrixEInvoiceCheckInvoice does not run them; the compatibility layer
  asks them one by one with LandrixEInvoiceCheckRule.

  DE: Pruefung einer Rechnung gegen die Geschaeftsregeln einer
  Zielspezifikation. Jede Regel hat eine stabile Kennung: die offizielle
  (z. B. BR-DE-15) oder LX-... fuer Regeln dieser Bibliothek. Ein Verstoss
  wird als edk_RuleViolation gemeldet, mit der Kennung in RuleID und der
  Schwere der Regel. Die Pruefungen melden nur; sie aendern die Rechnung
  nie. Welche Regeln umgesetzt sind, steht in docs/checking.md; ein
  Ergebnis ohne Meldung heisst, dass die umgesetzten Regeln
  erfuellt sind, nicht, dass ein Validator die Ausgabe annimmt.

  Die offiziellen Regeln beurteilen die Rechnung so, wie die Mapper sie in
  das Ziel schreiben wuerden: Text aus Leerraum (LandrixEInvoiceIsBlank)
  fehlt, eine Regel, die die Mapper immer erfuellen, hat keine Zeile
  (BR-01, BR-12 bis BR-15, BR-22, BR-24, BR-26, BR-31, BR-36, BR-41,
  BR-43, BR-45, BR-46, BR-48, BR-49, BR-50, BR-CO-05 bis BR-CO-08 (ihr
  Schematron-Test ist true), BR-CO-19, BR-CO-20 (ein leerer Zeitraum wird
  nicht geschrieben), BR-DE-14, BR-DE-21, PEPPOL-EN16931-R001,
  R008 (keine leeren Elemente), R043, R044 (das Zuschlagskennzeichen), R053
  in CII, R101 (ein Dokumentverweis der Position hat die Art 130)),
  und wo die Syntaxen sich unterscheiden, folgt die
  Zeile dem Validator der jeweiligen Syntax (z. B. BR-DE-23-b, BR-DE-30).
  Die PEPPOL-EN16931-Regeln des XRechnung-Schematrons gelten fuer
  XRechnung und Peppol; sie vergleichen Betraege, Preise und Mengen exakt
  so, wie sie geschrieben werden (xs:decimal, Divisionen wie Saxon sie
  rechnet: 18 Nachkommastellen, halb abwaerts gerundet).
  Die Factur-X-Profile bekommen die Regeln, die ihr Schematron enthaelt.
  BR-29, BR-30, BR-65 und BR-CO-03 werden am Modell geprueft: die Mapper lassen einen
  umgekehrten Zeitraum oder eine Klassifizierung ohne Schema weg, statt sie
  ungueltig zu schreiben; die Regel meldet also Inhalt, der verloren ginge.
  Die Rechenregeln BR-CO-10 bis BR-CO-17 (Factur-X EXTENDED: BR-FXEXT-CO-10
  bis 13, 15 und 16 mit ihrer Toleranz, XRechnung UBL mit Zahlungen Dritter:
  BR-DEX-09) vergleichen die Betraege so, wie sie geschrieben werden (zwei
  Nachkommastellen). Die Steuerkategorieregeln BR-S-nn bis BR-AG-nn (S, Z,
  E, AE, IC, G, O, AF, AG) und BR-FXEXT-xx-01 von Factur-X EXTENDED haben
  keine Zeilen: ihre Kennungen ergeben sich aus Gruppe und Nummer, und jede
  folgt dem Schematron ihrer Syntax, die sich in Kontext und Toleranz
  unterscheiden; BR-B-01, BR-B-02, BR-CO-03, BR-CO-04, BR-CO-09, BR-CO-18,
  BR-CO-21 bis BR-CO-26 und BR-FXEXT-CO-04 haben Zeilen. Die Formatregeln
  BR-DE-17, BR-DE-19, BR-DE-20, BR-DE-27, BR-DE-28 (Warnungen) und BR-51
  (UBL Warnung, CII Fehler) folgen den Funktionen und Mustern der KoSIT.
  Die Codelistenregeln BR-CL-01 bis BR-CL-26 gelten fuer XRechnung und
  Peppol (das Factur-X-Schematron prueft Codes mit eigenen Regeln,
  FX-SCH-A-..., die LandrixEInvoiceCIICodeRules auf dem CII-Syntaxmodell
  prueft, siehe LandrixEInvoiceCheckCII); sie verwenden die Listen der
  Validatoren, die geringfuegig von den Codelisten der Bibliothek abweichen
  (siehe CodeListed), und die Stufen der XRechnung-Konfiguration: BR-CL-21
  und BR-CL-23 sind dort Warnungen, und ihr Extension-Szenario ersetzt
  BR-CL-10, 11, 21, 24, 25 und 26 durch BR-DEX-04, 05, 06, 01, 07 und 08
  (dieselben Pruefungen mit den Extension-Codes).

  Die Regeln LX-CC-01 bis LX-CC-12 sind die Pruefungen von
  TXRechnungInvoiceAdapter.ConsistencyCheck aus XRechnung-for-Delphi. Es
  sind Vorgaben jener Bibliothek, keine veroeffentlichten Regeln; deshalb
  fuehrt LandrixEInvoiceCheckInvoice sie nicht aus, die
  Kompatibilitaetsschicht fragt sie einzeln mit LandrixEInvoiceCheckRule
  ab. }

{ API: internal. May change in any release; use the facade LandrixEInvoice
  or the stable units instead.
  DE: API: intern. Kann sich in jeder Version aendern; stattdessen die
  Fassade LandrixEInvoice oder die stabilen Units verwenden. }

unit LandrixEInvoiceCheck;

{$I LandrixEInvoice.inc}

interface

uses
  LandrixEInvoiceTypes,
  LandrixEInvoiceDiagnostics,
  LandrixEInvoiceSpecs,
  LandrixEInvoiceInvoice,
  LandrixEInvoiceCII,
  LandrixEInvoiceUBL;

{ Runs every rule that applies to ASpec (except the LX-CC compatibility
  rules) and adds one edk_RuleViolation per violation to ADiagnostics (nil:
  discarded). A number or date the writers write but cannot format (a
  number NaN, infinite, 1e23 and above; a date NaN or outside 0001-9999) is
  an error of its own (edk_ConversionFailed); a rule that cannot judge it
  holds, with a NaN no rule runs (its comparisons differ between
  compilers; a NaN date counts even where the writers would leave it out).
  Returns the number of errors (violations and such values).
  DE: Fuehrt jede Regel aus, die fuer ASpec gilt (ausser den
  LX-CC-Kompatibilitaetsregeln), und fuegt je Verstoss ein
  edk_RuleViolation an ADiagnostics an (nil: verworfen). Eine Zahl oder ein
  Datum, das kein Writer schreiben kann (Zahl: NaN, unendlich, ab 1e23;
  Datum: NaN oder ausserhalb 0001-9999), ist ein eigener Fehler
  (edk_ConversionFailed), sofern die Writer sie schreiben; eine Regel, die
  sie nicht beurteilen kann, gilt als erfuellt, bei NaN laeuft keine Regel
  (Vergleiche damit fallen je Compiler anders aus; ein NaN-Datum zaehlt
  auch dort, wo die Writer es weglassen wuerden). Liefert die Anzahl der
  Fehler (Verstoesse und solche Werte). }
function LandrixEInvoiceCheckInvoice(AInvoice: TLandrixInvoice; const ASpec: TLandrixEInvoiceSpec;
  ADiagnostics: TLandrixEInvoiceDiagnostics): Integer;

{ Checks the one rule ARuleID (case-sensitive, e.g. 'LX-CC-04'). True if it
  holds or does not apply to ASpec; otherwise False and one
  edk_RuleViolation in ADiagnostics (nil: discarded). An unknown identifier
  raises ELandrixEInvoiceError. ASpec may be the empty entry of
  LandrixEInvoiceFindSpec (a target without entry); the LX-CC rules apply
  to it as they did to the versions XRechnung-for-Delphi could not write,
  the official rules do not. A rule that cannot judge a number or date the
  writers cannot format holds, with a NaN every rule holds
  (LandrixEInvoiceCheckInvoice reports the value).
  DE: Prueft die eine Regel ARuleID (Gross- und Kleinschreibung zaehlt,
  z. B. 'LX-CC-04'). True, wenn sie erfuellt ist oder fuer ASpec nicht
  gilt; sonst False und ein edk_RuleViolation in ADiagnostics (nil:
  verworfen). Eine unbekannte Kennung loest ELandrixEInvoiceError aus.
  ASpec darf der leere Eintrag von LandrixEInvoiceFindSpec sein (Ziel ohne
  Eintrag); die LX-CC-Regeln gelten dafuer, wie sie fuer die Versionen
  galten, die XRechnung-for-Delphi nicht schreiben konnte, die offiziellen
  Regeln nicht. Eine Regel, die eine Zahl oder ein Datum nicht beurteilen
  kann, das die Writer nicht formatieren koennen, gilt als erfuellt, bei
  NaN jede Regel (LandrixEInvoiceCheckInvoice meldet den Wert). }
function LandrixEInvoiceCheckRule(AInvoice: TLandrixInvoice; const ASpec: TLandrixEInvoiceSpec;
  const ARuleID: TLandrixEInvoiceString; ADiagnostics: TLandrixEInvoiceDiagnostics): Boolean;

{ Checks the required content of a CII syntax model as the CII writer does
  when it writes ACII for ASpec: what the schema requires (if the Factur-X
  profile of ASpec contains it) and what the profile requires below an
  existing parent (LandrixEInvoiceCIIRequiredBelowParent). Content the
  Factur-X profile does not allow is an error (edk_NotAllowed,
  LandrixEInvoiceCheckCIIProfile; the model is not changed), and so is a
  code the code asserts of the Factur-X profile reject (edk_RuleViolation
  with the FX-SCH-A identifier, LandrixEInvoiceCheckCIICodes). Adds these
  and the writer's diagnostics (edk_MissingElement and others) to
  ADiagnostics (nil: discarded) and returns the number with severity
  eds_Error. A parent that exists only through such content can also
  report its required children. ASpec must not be a UBL specification
  (ELandrixEInvoiceError).
  DE: Prueft den Pflichtinhalt eines CII-Syntaxmodells so, wie der
  CII-Writer es beim Schreiben von ACII fuer ASpec tut: was das Schema
  verlangt (wenn das Factur-X-Profil von ASpec es enthaelt) und was das
  Profil unter einem vorhandenen Elternelement verlangt
  (LandrixEInvoiceCIIRequiredBelowParent). Inhalt, den das
  Factur-X-Profil nicht erlaubt, ist ein Fehler (edk_NotAllowed,
  LandrixEInvoiceCheckCIIProfile; das Modell wird nicht geaendert), ebenso
  ein Code, den die Code-Asserts des Factur-X-Profils ablehnen
  (edk_RuleViolation mit der FX-SCH-A-Kennung,
  LandrixEInvoiceCheckCIICodes). Fuegt diese und die Meldungen des
  Writers (edk_MissingElement und andere) an ADiagnostics an (nil:
  verworfen) und liefert die Anzahl mit Schwere
  eds_Error. Ein Elternelement, das nur durch solchen Inhalt existiert,
  kann zusaetzlich seine Pflichtkinder melden. ASpec darf keine
  UBL-Spezifikation sein (ELandrixEInvoiceError). }
function LandrixEInvoiceCheckCII(ACII: TLandrixCIIInvoice; const ASpec: TLandrixEInvoiceSpec;
  ADiagnostics: TLandrixEInvoiceDiagnostics): Integer;

{ Checks the required content of a UBL invoice or credit note as the UBL
  writer does when it writes it (what the UBL schema requires). Adds the
  writer's diagnostics to ADiagnostics (nil: discarded) and returns the
  number with severity eds_Error. ASpec must not be a CII specification
  (ELandrixEInvoiceError).
  DE: Prueft den Pflichtinhalt einer UBL-Rechnung oder -Gutschrift so, wie
  der UBL-Writer es beim Schreiben tut (was das UBL-Schema verlangt). Fuegt
  die Meldungen des Writers an ADiagnostics an (nil: verworfen) und liefert
  die Anzahl mit Schwere eds_Error. ASpec darf keine CII-Spezifikation sein
  (ELandrixEInvoiceError). }
function LandrixEInvoiceCheckUBLInvoice(AUBL: TLandrixUBLInvoice; const ASpec: TLandrixEInvoiceSpec;
  ADiagnostics: TLandrixEInvoiceDiagnostics): Integer;
function LandrixEInvoiceCheckUBLCreditNote(AUBL: TLandrixUBLCreditNote; const ASpec: TLandrixEInvoiceSpec;
  ADiagnostics: TLandrixEInvoiceDiagnostics): Integer;

implementation

uses
  SysUtils,
  LandrixXmlBase,
  LandrixXmlWriter,
  LandrixEInvoiceCodes,
  LandrixEInvoiceLexical,
  LandrixEInvoiceExact,
  LandrixEInvoiceRules,
  LandrixEInvoiceCalc,
  LandrixEInvoiceCIIWriter,
  LandrixEInvoiceCIIProfiles,
  LandrixEInvoiceCIICodeRules,
  LandrixEInvoiceIdentifiers,
  LandrixEInvoiceCheckPeppol,
  LandrixEInvoiceSubLines,
  LandrixEInvoiceUBLWriter;

type
  TStandards = set of TLandrixEInvoiceStandard;
  TSyntaxes = set of TLandrixEInvoiceSyntax;
  TProfiles = set of TLandrixEInvoiceProfile;

  { The implemented rules; the order of TCheckRules. }
  TCheckRuleIndex = (
    cr_LXCC01, cr_LXCC02, cr_LXCC03, cr_LXCC04, cr_LXCC05, cr_LXCC06,
    cr_LXCC07, cr_LXCC08, cr_LXCC09, cr_LXCC10, cr_LXCC11, cr_LXCC12,
    cr_BR02, cr_BR03, cr_BR04, cr_BR05, cr_BR06, cr_BR07, cr_BR08, cr_BR09,
    cr_BR10, cr_BR11, cr_BR16, cr_BR17, cr_BR18, cr_BR19, cr_BR20, cr_BR21,
    cr_BR23, cr_BR25, cr_BR27, cr_BR28, cr_BR29, cr_BR30, cr_BR32, cr_BR33,
    cr_BR37, cr_BR38, cr_BR42, cr_BR44, cr_BR47, cr_BR51UBL, cr_BR51CII, cr_BR52, cr_BR53, cr_BRDEC15, cr_BR54,
    cr_BR55, cr_BR56, cr_BR57, cr_BR61, cr_BR62, cr_BR63, cr_BR64, cr_BR65, cr_BRB01, cr_BRB02, cr_UBLSR29,
    cr_CIISR467, cr_CIISR468, cr_UBLSR47, cr_UBLSR54, cr_UBLSR55,
    cr_BRDE01, cr_BRDE02, cr_BRDE03, cr_BRDE04, cr_BRDE05, cr_BRDE06,
    cr_BRDE07, cr_BRDE08, cr_BRDE09, cr_BRDE10, cr_BRDE11, cr_BRDE15,
    cr_BRDE16, cr_BRDE17, cr_BRDE18, cr_BRDE19, cr_BRDE20, cr_BRDE22, cr_BRDE23a, cr_BRDE23b, cr_BRDE24a, cr_BRDE24b,
    cr_BRDE25a, cr_BRDE25b, cr_BRDE26, cr_BRDE27, cr_BRDE28, cr_BRDE30, cr_BRDE31, cr_BRTMP2,
    cr_PeppolR003, cr_PeppolR010, cr_PeppolR020, cr_PeppolR061,
    cr_PeppolR005, cr_PeppolR040, cr_PeppolR041, cr_PeppolR042, cr_PeppolR046, cr_PeppolR053, cr_PeppolR054,
    cr_PeppolR055, cr_PeppolR110, cr_PeppolR111, cr_PeppolR120XR, cr_PeppolR120BIS, cr_PeppolR121, cr_PeppolR130,
    cr_BRCO03, cr_BRCO04, cr_BRCO09,
    cr_BRCO10, cr_BRCO11, cr_BRCO12, cr_BRCO13, cr_BRCO14, cr_BRCO15, cr_BRCO16, cr_BRCO17, cr_BRCO18,
    cr_BRCO21, cr_BRCO22, cr_BRCO23, cr_BRCO24, cr_BRCO25, cr_BRCO26, cr_BRFXEXTCO04,
    cr_BRFXEXTCO10, cr_BRFXEXTCO11, cr_BRFXEXTCO12, cr_BRFXEXTCO13, cr_BRFXEXTCO15, cr_BRFXEXTCO16,
    cr_BRFXEXT08, cr_BRDEX09, cr_BRDEX14,
    cr_BRCL01, cr_BRCL03, cr_BRCL04, cr_BRCL05, cr_BRCL06, cr_BRCL07, cr_BRCL08, cr_BRCL10, cr_BRCL11,
    cr_BRCL13, cr_BRCL14, cr_BRCL15, cr_BRCL16, cr_BRCL17, cr_BRCL18, cr_BRCL19, cr_BRCL20,
    cr_BRCL21XR, cr_BRCL21BIS, cr_BRCL22, cr_BRCL23XR, cr_BRCL23BIS, cr_BRCL24, cr_BRCL25, cr_BRCL26,
    cr_BRDEX01, cr_BRDEX04, cr_BRDEX05, cr_BRDEX06, cr_BRDEX07, cr_BRDEX08);

  { One check row: identifier, the specifications it applies to, severity,
    business terms (the Terms of the diagnostic), message and origin. Legacy
    rows run only through LandrixEInvoiceCheckRule.
    DE: Eine Pruefzeile: Kennung, die Spezifikationen, fuer die sie gilt,
    Schwere, Geschaeftsbegriffe (Terms der Meldung), Meldung und Herkunft.
    Altzeilen laufen nur ueber LandrixEInvoiceCheckRule. }
  TCheckRow = record
    ID: string;
    Standards: TStandards;
    Syntaxes: TSyntaxes;
    Profiles: TProfiles;
    Severity: TLandrixEInvoiceDiagnosticSeverity;
    Legacy: Boolean;
    Terms: string;
    Message: string;
    Source: string;
  end;

const
  AllStandards = [Low(TLandrixEInvoiceStandard)..High(TLandrixEInvoiceStandard)];
  AllSyntaxes = [Low(TLandrixEInvoiceSyntax)..High(TLandrixEInvoiceSyntax)];
  AllProfiles = [Low(TLandrixEInvoiceProfile)..High(TLandrixEInvoiceProfile)];
  LegacySource = 'XRechnung-for-Delphi ConsistencyCheck';

  { The specifications with published rules; the empty entry has none.
    DE: Die Spezifikationen mit veroeffentlichten Regeln; der leere Eintrag
    hat keine. }
  EN16931Standards = [est_XRechnung, est_FacturX, est_PeppolBIS];
  EN16931Source = 'EN 16931 (CEN/TS 16931-3 schematron)';
  XRechnungSource = 'XRechnung 3.0 (KoSIT schematron 2.5.0)';
  PeppolSource = 'Peppol BIS Billing 3.0';
  { The PEPPOL-EN16931 rules with this source are part of the XRechnung
    schematron as well; R120 is a warning there.
    DE: Die PEPPOL-EN16931-Regeln mit dieser Herkunft gehoeren auch zum
    XRechnung-Schematron; R120 ist dort eine Warnung. }
  PeppolXRechnungSource = 'Peppol BIS Billing 3.0, XRechnung 3.0';
  FacturXExtendedSource = 'Factur-X 1.09 EXTENDED schematron';

  { Factur-X 1.09 profiles by the EN 16931 rules their schematron contains
    (XRechnung and Peppol have epr_None and get every rule): MINIMUM has
    BR-01 to BR-09 and BR-13 to BR-15, BASIC WL adds the document level
    rules, BASIC the line rules; BR-51 and BR-52 start with EN 16931, and
    EXTENDED leaves out BR-22 to BR-24, BR-26 to BR-28, BR-38, BR-44 and
    BR-54.
    DE: Factur-X-1.09-Profile nach den EN-16931-Regeln, die ihr Schematron
    enthaelt (XRechnung und Peppol haben epr_None und bekommen jede Regel):
    MINIMUM hat BR-01 bis BR-09 und BR-13 bis BR-15, BASIC WL kommt mit den
    Regeln der Dokumentebene hinzu, BASIC mit den Positionsregeln; BR-51 und
    BR-52 beginnen mit EN 16931, und EXTENDED laesst BR-22 bis BR-24, BR-26
    bis BR-28, BR-38, BR-44 und BR-54 aus. }
  FromBasicWL = AllProfiles - [epr_Minimum];
  FromBasicWLNoExtended = FromBasicWL - [epr_Extended];
  FromBasic = FromBasicWL - [epr_BasicWL];
  FromBasicNoExtended = FromBasic - [epr_Extended];
  FromEN16931 = FromBasic - [epr_Basic];

  { The BR-CL rules belong to the CEN schematron of XRechnung and Peppol;
    Factur-X checks codes with rules of its own (FX-SCH-A-...).
    DE: Die BR-CL-Regeln gehoeren zum CEN-Schematron von XRechnung und
    Peppol; Factur-X prueft Codes mit eigenen Regeln (FX-SCH-A-...). }
  CodeListStandards = [est_XRechnung, est_PeppolBIS];
  { XRechnung lowers BR-CL-21 and BR-CL-23 to warnings (scenarios.xml).
    DE: XRechnung stuft BR-CL-21 und BR-CL-23 zu Warnungen herab
    (scenarios.xml). }
  XRechnungLevelSource = 'EN 16931 (CEN/TS 16931-3 schematron), level of the XRechnung 3.0 configuration';

  { LX-CC-nn: the checks of XRechnung-for-Delphi in their old order, nn is
    the old cc... code. They apply to every target, including the empty
    entry, unless a row says otherwise; the predicates in Violated keep the
    old version conditions. The official rows follow, in the order of their
    identifiers; their messages are the rule texts in short.
    DE: LX-CC-nn: die Pruefungen von XRechnung-for-Delphi in alter
    Reihenfolge, nn ist der alte cc...-Code. Sie gelten fuer jedes Ziel,
    auch den leeren Eintrag, sofern die Zeile nichts anderes sagt; die
    Bedingungen in Violated bewahren die alten Versionsbedingungen. Es
    folgen die offiziellen Zeilen in der Reihenfolge ihrer Kennungen; ihre
    Meldungen sind die Regeltexte in Kurzform. }
  CheckRows: array[TCheckRuleIndex] of TCheckRow = (
    (ID: 'LX-CC-01'; Standards: AllStandards; Syntaxes: AllSyntaxes;
     Profiles: AllProfiles - [epr_EN16931]; Severity: eds_Error; Legacy: True; Terms: 'BG-16';
     Message: 'no payment instructions (payment means); only Factur-X EN 16931 may do without';
     Source: LegacySource),
    (ID: 'LX-CC-02'; Standards: [est_XRechnung]; Syntaxes: AllSyntaxes;
     Profiles: AllProfiles; Severity: eds_Error; Legacy: True; Terms: 'BT-3';
     Message: 'invoice type code 84, 261, 383, 386 or 457 is not supported by XRechnung';
     Source: LegacySource),
    (ID: 'LX-CC-03'; Standards: AllStandards; Syntaxes: AllSyntaxes;
     Profiles: AllProfiles; Severity: eds_Error; Legacy: True; Terms: 'BG-3';
     Message: 'more preceding invoice references than the target allows (rule table)';
     Source: LegacySource),
    (ID: 'LX-CC-04'; Standards: AllStandards; Syntaxes: AllSyntaxes;
     Profiles: AllProfiles; Severity: eds_Error; Legacy: True; Terms: 'BG-19';
     Message: 'more than one SEPA direct debit (payment means 59)';
     Source: LegacySource),
    (ID: 'LX-CC-05'; Standards: AllStandards; Syntaxes: AllSyntaxes;
     Profiles: AllProfiles; Severity: eds_Error; Legacy: True; Terms: 'BG-18';
     Message: 'more than one credit card (payment means 54)';
     Source: LegacySource),
    (ID: 'LX-CC-06'; Standards: AllStandards; Syntaxes: AllSyntaxes;
     Profiles: AllProfiles; Severity: eds_Error; Legacy: True; Terms: 'BT-31, BT-30';
     Message: 'seller has neither a VAT identifier (BT-31) nor a legal registration identifier (BT-30)';
     Source: LegacySource),
    (ID: 'LX-CC-07'; Standards: AllStandards; Syntaxes: AllSyntaxes;
     Profiles: AllProfiles; Severity: eds_Error; Legacy: True; Terms: 'BT-31, BT-32';
     Message: 'seller has neither a VAT identifier (BT-31) nor a tax registration identifier (BT-32)';
     Source: LegacySource),
    (ID: 'LX-CC-08'; Standards: AllStandards; Syntaxes: AllSyntaxes;
     Profiles: AllProfiles; Severity: eds_Error; Legacy: True; Terms: 'BG-DEX-09';
     Message: 'third-party payments the target does not allow (rule table)';
     Source: LegacySource),
    (ID: 'LX-CC-09'; Standards: AllStandards; Syntaxes: AllSyntaxes;
     Profiles: AllProfiles; Severity: eds_Error; Legacy: True; Terms: 'BT-34, BT-49';
     Message: 'electronic address with scheme EM under Peppol, or without scheme where the default EM ' +
       'does not apply (rule table)';
     Source: LegacySource),
    (ID: 'LX-CC-10'; Standards: AllStandards; Syntaxes: AllSyntaxes;
     Profiles: AllProfiles; Severity: eds_Error; Legacy: True; Terms: 'BG-25';
     Message: 'delivery note or delivery date per line the target does not allow (rule table)';
     Source: LegacySource),
    (ID: 'LX-CC-11'; Standards: AllStandards; Syntaxes: AllSyntaxes;
     Profiles: AllProfiles; Severity: eds_Error; Legacy: True; Terms: 'BG-DEX-01';
     Message: 'an INFORMATION line on the top level or a DETAIL line with sub lines outside Factur-X ' +
       'EXTENDED (sub lines the target does not write nested are written flat)';
     Source: LegacySource),
    (ID: 'LX-CC-12'; Standards: [est_FacturX]; Syntaxes: AllSyntaxes;
     Profiles: [epr_Extended]; Severity: eds_Error; Legacy: True; Terms: 'BG-DEX-01';
     Message: 'amount of a GROUP line differs from the sum of its DETAIL and GROUP sub lines ' +
       '(BR-FXEXT-08)';
     Source: LegacySource),
    (ID: 'BR-02'; Standards: EN16931Standards; Syntaxes: AllSyntaxes;
     Profiles: AllProfiles; Severity: eds_Error; Legacy: False; Terms: 'BT-1';
     Message: 'an invoice shall have an invoice number (BT-1)';
     Source: EN16931Source),
    (ID: 'BR-03'; Standards: EN16931Standards; Syntaxes: AllSyntaxes;
     Profiles: AllProfiles; Severity: eds_Error; Legacy: False; Terms: 'BT-2';
     Message: 'an invoice shall have an invoice issue date (BT-2)';
     Source: EN16931Source),
    (ID: 'BR-04'; Standards: EN16931Standards; Syntaxes: AllSyntaxes;
     Profiles: AllProfiles; Severity: eds_Error; Legacy: False; Terms: 'BT-3';
     Message: 'an invoice shall have an invoice type code (BT-3)';
     Source: EN16931Source),
    (ID: 'BR-05'; Standards: EN16931Standards; Syntaxes: AllSyntaxes;
     Profiles: AllProfiles; Severity: eds_Error; Legacy: False; Terms: 'BT-5';
     Message: 'an invoice shall have an invoice currency code (BT-5)';
     Source: EN16931Source),
    (ID: 'BR-06'; Standards: EN16931Standards; Syntaxes: AllSyntaxes;
     Profiles: AllProfiles; Severity: eds_Error; Legacy: False; Terms: 'BT-27';
     Message: 'an invoice shall contain the seller name (BT-27)';
     Source: EN16931Source),
    (ID: 'BR-07'; Standards: EN16931Standards; Syntaxes: AllSyntaxes;
     Profiles: AllProfiles; Severity: eds_Error; Legacy: False; Terms: 'BT-44';
     Message: 'an invoice shall contain the buyer name (BT-44)';
     Source: EN16931Source),
    (ID: 'BR-08'; Standards: EN16931Standards; Syntaxes: AllSyntaxes;
     Profiles: AllProfiles; Severity: eds_Error; Legacy: False; Terms: 'BG-5';
     Message: 'an invoice shall contain the seller postal address (BG-5)';
     Source: EN16931Source),
    (ID: 'BR-09'; Standards: EN16931Standards; Syntaxes: AllSyntaxes;
     Profiles: AllProfiles; Severity: eds_Error; Legacy: False; Terms: 'BT-40';
     Message: 'the seller postal address (BG-5) shall contain a seller country code (BT-40)';
     Source: EN16931Source),
    (ID: 'BR-10'; Standards: EN16931Standards; Syntaxes: AllSyntaxes;
     Profiles: FromBasicWL; Severity: eds_Error; Legacy: False; Terms: 'BG-8';
     Message: 'an invoice shall contain the buyer postal address (BG-8)';
     Source: EN16931Source),
    (ID: 'BR-11'; Standards: EN16931Standards; Syntaxes: AllSyntaxes;
     Profiles: FromBasicWL; Severity: eds_Error; Legacy: False; Terms: 'BT-55';
     Message: 'the buyer postal address (BG-8) shall contain a buyer country code (BT-55)';
     Source: EN16931Source),
    (ID: 'BR-16'; Standards: EN16931Standards; Syntaxes: AllSyntaxes;
     Profiles: FromBasic; Severity: eds_Error; Legacy: False; Terms: 'BG-25';
     Message: 'an invoice shall have at least one invoice line (BG-25)';
     Source: EN16931Source),
    (ID: 'BR-17'; Standards: EN16931Standards; Syntaxes: AllSyntaxes;
     Profiles: FromBasicWL; Severity: eds_Error; Legacy: False; Terms: 'BT-59';
     Message: 'a payee (BG-10) shall have a name (BT-59) and differ from the seller (BG-4) in name and ' +
       'identifiers';
     Source: EN16931Source),
    (ID: 'BR-18'; Standards: EN16931Standards; Syntaxes: AllSyntaxes;
     Profiles: FromBasicWL; Severity: eds_Error; Legacy: False; Terms: 'BT-62';
     Message: 'a seller tax representative party (BG-11) shall have a name (BT-62)';
     Source: EN16931Source),
    (ID: 'BR-19'; Standards: EN16931Standards; Syntaxes: AllSyntaxes;
     Profiles: FromBasicWL; Severity: eds_Error; Legacy: False; Terms: 'BG-12';
     Message: 'a seller tax representative party (BG-11) shall have a postal address (BG-12)';
     Source: EN16931Source),
    (ID: 'BR-20'; Standards: EN16931Standards; Syntaxes: AllSyntaxes;
     Profiles: FromBasicWL; Severity: eds_Error; Legacy: False; Terms: 'BT-69';
     Message: 'the tax representative postal address (BG-12) shall contain a country code (BT-69)';
     Source: EN16931Source),
    (ID: 'BR-21'; Standards: EN16931Standards; Syntaxes: AllSyntaxes;
     Profiles: FromBasic; Severity: eds_Error; Legacy: False; Terms: 'BT-126';
     Message: 'each invoice line (BG-25) shall have an invoice line identifier (BT-126)';
     Source: EN16931Source),
    (ID: 'BR-23'; Standards: EN16931Standards; Syntaxes: AllSyntaxes;
     Profiles: FromBasicNoExtended; Severity: eds_Error; Legacy: False; Terms: 'BT-130';
     Message: 'each invoice line (BG-25) shall have an invoiced quantity unit of measure code (BT-130)';
     Source: EN16931Source),
    (ID: 'BR-25'; Standards: EN16931Standards; Syntaxes: AllSyntaxes;
     Profiles: FromBasic; Severity: eds_Error; Legacy: False; Terms: 'BT-153';
     Message: 'each invoice line (BG-25) shall contain the item name (BT-153)';
     Source: EN16931Source),
    (ID: 'BR-27'; Standards: EN16931Standards; Syntaxes: AllSyntaxes;
     Profiles: FromBasicNoExtended; Severity: eds_Error; Legacy: False; Terms: 'BT-146';
     Message: 'the item net price (BT-146) shall not be negative';
     Source: EN16931Source),
    (ID: 'BR-28'; Standards: EN16931Standards; Syntaxes: AllSyntaxes;
     Profiles: FromBasicNoExtended; Severity: eds_Error; Legacy: False; Terms: 'BT-148';
     Message: 'the item gross price (BT-148) shall not be negative';
     Source: EN16931Source),
    (ID: 'BR-29'; Standards: EN16931Standards; Syntaxes: AllSyntaxes;
     Profiles: FromBasicWL; Severity: eds_Error; Legacy: False; Terms: 'BT-73, BT-74';
     Message: 'the invoicing period end date (BT-74) shall be later or equal to its start date (BT-73)';
     Source: EN16931Source),
    (ID: 'BR-30'; Standards: EN16931Standards; Syntaxes: AllSyntaxes;
     Profiles: FromBasic; Severity: eds_Error; Legacy: False; Terms: 'BT-134, BT-135';
     Message: 'the invoice line period end date (BT-135) shall be later or equal to its start date (BT-134)';
     Source: EN16931Source),
    (ID: 'BR-32'; Standards: EN16931Standards; Syntaxes: AllSyntaxes;
     Profiles: FromBasicWL; Severity: eds_Error; Legacy: False; Terms: 'BT-95';
     Message: 'each document level allowance (BG-20) shall have a VAT category code (BT-95)';
     Source: EN16931Source),
    (ID: 'BR-33'; Standards: EN16931Standards; Syntaxes: AllSyntaxes;
     Profiles: FromBasicWL; Severity: eds_Error; Legacy: False; Terms: 'BT-97, BT-98';
     Message: 'each document level allowance (BG-20) shall have a reason (BT-97) or a reason code (BT-98)';
     Source: EN16931Source),
    (ID: 'BR-37'; Standards: EN16931Standards; Syntaxes: AllSyntaxes;
     Profiles: FromBasicWL; Severity: eds_Error; Legacy: False; Terms: 'BT-102';
     Message: 'each document level charge (BG-21) shall have a VAT category code (BT-102)';
     Source: EN16931Source),
    (ID: 'BR-38'; Standards: EN16931Standards; Syntaxes: AllSyntaxes;
     Profiles: FromBasicWLNoExtended; Severity: eds_Error; Legacy: False; Terms: 'BT-104, BT-105';
     Message: 'each document level charge (BG-21) shall have a reason (BT-104) or a reason code (BT-105)';
     Source: EN16931Source),
    (ID: 'BR-42'; Standards: EN16931Standards; Syntaxes: AllSyntaxes;
     Profiles: FromBasic; Severity: eds_Error; Legacy: False; Terms: 'BT-139, BT-140';
     Message: 'each invoice line allowance (BG-27) shall have a reason (BT-139) or a reason code (BT-140)';
     Source: EN16931Source),
    (ID: 'BR-44'; Standards: EN16931Standards; Syntaxes: AllSyntaxes;
     Profiles: FromBasicNoExtended; Severity: eds_Error; Legacy: False; Terms: 'BT-144, BT-145';
     Message: 'each invoice line charge (BG-28) shall have a reason (BT-144) or a reason code (BT-145)';
     Source: EN16931Source),
    (ID: 'BR-47'; Standards: EN16931Standards; Syntaxes: AllSyntaxes;
     Profiles: FromBasicWL; Severity: eds_Error; Legacy: False; Terms: 'BT-118';
     Message: 'each VAT breakdown (BG-23) shall be defined through a VAT category code (BT-118)';
     Source: EN16931Source),
    { BR-51 is a warning in UBL and an error in CII: two rows with one
      identifier. DE: BR-51 ist in UBL eine Warnung und in CII ein Fehler:
      zwei Zeilen mit einer Kennung. }
    (ID: 'BR-51'; Standards: EN16931Standards; Syntaxes: [esy_UBL];
     Profiles: FromEN16931; Severity: eds_Warning; Legacy: False; Terms: 'BT-87';
     Message: 'the payment card primary account number (BT-87) should have at most 10 characters (only ' +
       'the last digits)';
     Source: EN16931Source),
    (ID: 'BR-51'; Standards: EN16931Standards; Syntaxes: [esy_CII];
     Profiles: FromEN16931; Severity: eds_Error; Legacy: False; Terms: 'BT-87';
     Message: 'the payment card primary account number (BT-87) shall have at most 10 characters (only ' +
       'the last digits)';
     Source: EN16931Source),
    (ID: 'BR-52'; Standards: EN16931Standards; Syntaxes: AllSyntaxes;
     Profiles: FromEN16931; Severity: eds_Error; Legacy: False; Terms: 'BT-122';
     Message: 'each additional supporting document (BG-24) shall contain a supporting document reference ' +
       '(BT-122)';
     Source: EN16931Source),
    (ID: 'BR-53'; Standards: EN16931Standards; Syntaxes: AllSyntaxes;
     Profiles: FromBasicWL; Severity: eds_Error; Legacy: False; Terms: 'BT-6, BT-111';
     Message: 'with a VAT accounting currency code (BT-6) the invoice total VAT amount in accounting ' +
       'currency (BT-111) shall be provided';
     Source: EN16931Source),
    { BR-DEC-15 (CII) fails on the same state as BR-53: a VAT total but none
      in the accounting currency. DE: BR-DEC-15 (CII) scheitert am selben
      Zustand wie BR-53. }
    (ID: 'BR-DEC-15'; Standards: EN16931Standards; Syntaxes: [esy_CII];
     Profiles: FromBasicWL; Severity: eds_Error; Legacy: False; Terms: 'BT-6, BT-111';
     Message: 'with a VAT accounting currency code (BT-6) the VAT total in accounting currency (BT-111) ' +
       'shall be given, with at most 2 decimals';
     Source: EN16931Source),
    (ID: 'BR-54'; Standards: EN16931Standards; Syntaxes: AllSyntaxes;
     Profiles: FromBasicNoExtended; Severity: eds_Error; Legacy: False; Terms: 'BT-160, BT-161';
     Message: 'each item attribute (BG-32) shall contain a name (BT-160) and a value (BT-161)';
     Source: EN16931Source),
    (ID: 'BR-55'; Standards: EN16931Standards; Syntaxes: AllSyntaxes;
     Profiles: FromBasicWL; Severity: eds_Error; Legacy: False; Terms: 'BT-25';
     Message: 'each preceding invoice reference (BG-3) shall contain a preceding invoice reference (BT-25)';
     Source: EN16931Source),
    (ID: 'BR-56'; Standards: EN16931Standards; Syntaxes: AllSyntaxes;
     Profiles: FromBasicWL; Severity: eds_Error; Legacy: False; Terms: 'BT-63';
     Message: 'each seller tax representative party (BG-11) shall have a VAT identifier (BT-63)';
     Source: EN16931Source),
    (ID: 'BR-57'; Standards: EN16931Standards; Syntaxes: AllSyntaxes;
     Profiles: FromBasicWL; Severity: eds_Error; Legacy: False; Terms: 'BT-80';
     Message: 'each deliver to address (BG-15) shall contain a deliver to country code (BT-80)';
     Source: EN16931Source),
    { BR-61 in UBL only: in CII its context is the account element, which
      the mappers write only with an identifier (BR-DE-23-a covers XRechnung
      CII). DE: BR-61 nur in UBL: in CII ist sein Kontext das Kontoelement,
      das die Mapper nur mit Kennung schreiben (BR-DE-23-a deckt XRechnung
      CII ab). }
    (ID: 'BR-61'; Standards: EN16931Standards; Syntaxes: [esy_UBL];
     Profiles: FromBasicWL; Severity: eds_Error; Legacy: False; Terms: 'BT-81, BT-84';
     Message: 'a credit transfer (payment means 30 or 58) shall have a payment account identifier (BT-84)';
     Source: EN16931Source),
    (ID: 'BR-62'; Standards: EN16931Standards; Syntaxes: AllSyntaxes;
     Profiles: FromBasicWL; Severity: eds_Error; Legacy: False; Terms: 'BT-34';
     Message: 'the seller electronic address (BT-34) shall have a scheme identifier';
     Source: EN16931Source),
    (ID: 'BR-63'; Standards: EN16931Standards; Syntaxes: AllSyntaxes;
     Profiles: FromBasicWL; Severity: eds_Error; Legacy: False; Terms: 'BT-49';
     Message: 'the buyer electronic address (BT-49) shall have a scheme identifier';
     Source: EN16931Source),
    (ID: 'BR-64'; Standards: EN16931Standards; Syntaxes: AllSyntaxes;
     Profiles: FromBasic; Severity: eds_Error; Legacy: False; Terms: 'BT-157';
     Message: 'the item standard identifier (BT-157) shall have a scheme identifier';
     Source: EN16931Source),
    (ID: 'BR-65'; Standards: EN16931Standards; Syntaxes: AllSyntaxes;
     Profiles: FromBasic; Severity: eds_Error; Legacy: False; Terms: 'BT-158';
     Message: 'the item classification identifier (BT-158) shall have a scheme identifier';
     Source: EN16931Source),
    (ID: 'BR-B-01'; Standards: EN16931Standards; Syntaxes: AllSyntaxes;
     Profiles: FromBasic; Severity: eds_Error; Legacy: False; Terms: 'BT-40, BT-55';
     Message: 'an invoice with VAT category B (split payment) shall be a domestic Italian invoice (every ' +
       'country code IT)';
     Source: EN16931Source),
    (ID: 'BR-B-02'; Standards: EN16931Standards; Syntaxes: AllSyntaxes;
     Profiles: FromBasic; Severity: eds_Error; Legacy: False; Terms: 'BT-118, BT-151, BT-95, BT-102';
     Message: 'an invoice with VAT category B (split payment) shall not contain VAT category S';
     Source: EN16931Source),
    (ID: 'UBL-SR-29'; Standards: [est_XRechnung, est_PeppolBIS]; Syntaxes: [esy_UBL];
     Profiles: AllProfiles; Severity: eds_Error; Legacy: False; Terms: 'BT-29, BT-46, BT-60, BT-90';
     Message: 'the document shall contain at most one party identifier with scheme SEPA (bank assigned ' +
       'creditor reference)';
     Source: EN16931Source),
    { the syntax rules on several payment instructions, as the mappers write
      one per payment type. DE: die Syntaxregeln zu mehreren
      Zahlungsanweisungen; die Mapper schreiben eine je Zahlungsart. }
    (ID: 'CII-SR-467'; Standards: EN16931Standards; Syntaxes: [esy_CII];
     Profiles: FromBasicWL; Severity: eds_Error; Legacy: False; Terms: 'BT-81';
     Message: 'all payment means type codes (BT-81) shall have the same value';
     Source: EN16931Source),
    { BT-82 is written from Factur-X EN 16931 on. DE: BT-82 wird ab Factur-X
      EN 16931 geschrieben. }
    (ID: 'CII-SR-468'; Standards: EN16931Standards; Syntaxes: [esy_CII];
     Profiles: FromEN16931; Severity: eds_Error; Legacy: False; Terms: 'BT-82';
     Message: 'all payment means texts (BT-82) shall have the same value';
     Source: EN16931Source),
    (ID: 'UBL-SR-47'; Standards: [est_XRechnung, est_PeppolBIS]; Syntaxes: [esy_UBL];
     Profiles: AllProfiles; Severity: eds_Error; Legacy: False; Terms: 'BT-81';
     Message: 'all payment means codes (BT-81) shall be the same';
     Source: EN16931Source),
    (ID: 'UBL-SR-54'; Standards: [est_XRechnung, est_PeppolBIS]; Syntaxes: [esy_UBL];
     Profiles: AllProfiles; Severity: eds_Error; Legacy: False; Terms: 'BG-18';
     Message: 'the payment card information (BG-18) shall occur at most once';
     Source: EN16931Source),
    (ID: 'UBL-SR-55'; Standards: [est_XRechnung, est_PeppolBIS]; Syntaxes: [esy_UBL];
     Profiles: AllProfiles; Severity: eds_Error; Legacy: False; Terms: 'BG-19';
     Message: 'the direct debit information (BG-19) shall occur at most once';
     Source: EN16931Source),
    (ID: 'BR-DE-1'; Standards: [est_XRechnung]; Syntaxes: AllSyntaxes;
     Profiles: AllProfiles; Severity: eds_Error; Legacy: False; Terms: 'BG-16';
     Message: 'an invoice shall contain payment instructions (BG-16)';
     Source: XRechnungSource),
    (ID: 'BR-DE-2'; Standards: [est_XRechnung]; Syntaxes: AllSyntaxes;
     Profiles: AllProfiles; Severity: eds_Error; Legacy: False; Terms: 'BG-6';
     Message: 'the seller contact (BG-6) shall be provided';
     Source: XRechnungSource),
    (ID: 'BR-DE-3'; Standards: [est_XRechnung]; Syntaxes: AllSyntaxes;
     Profiles: AllProfiles; Severity: eds_Error; Legacy: False; Terms: 'BT-37';
     Message: 'the seller city (BT-37) shall be provided';
     Source: XRechnungSource),
    (ID: 'BR-DE-4'; Standards: [est_XRechnung]; Syntaxes: AllSyntaxes;
     Profiles: AllProfiles; Severity: eds_Error; Legacy: False; Terms: 'BT-38';
     Message: 'the seller post code (BT-38) shall be provided';
     Source: XRechnungSource),
    (ID: 'BR-DE-5'; Standards: [est_XRechnung]; Syntaxes: AllSyntaxes;
     Profiles: AllProfiles; Severity: eds_Error; Legacy: False; Terms: 'BT-41';
     Message: 'the seller contact point (BT-41) shall be provided';
     Source: XRechnungSource),
    (ID: 'BR-DE-6'; Standards: [est_XRechnung]; Syntaxes: AllSyntaxes;
     Profiles: AllProfiles; Severity: eds_Error; Legacy: False; Terms: 'BT-42';
     Message: 'the seller contact telephone number (BT-42) shall be provided';
     Source: XRechnungSource),
    (ID: 'BR-DE-7'; Standards: [est_XRechnung]; Syntaxes: AllSyntaxes;
     Profiles: AllProfiles; Severity: eds_Error; Legacy: False; Terms: 'BT-43';
     Message: 'the seller contact email address (BT-43) shall be provided';
     Source: XRechnungSource),
    (ID: 'BR-DE-8'; Standards: [est_XRechnung]; Syntaxes: AllSyntaxes;
     Profiles: AllProfiles; Severity: eds_Error; Legacy: False; Terms: 'BT-52';
     Message: 'the buyer city (BT-52) shall be provided';
     Source: XRechnungSource),
    (ID: 'BR-DE-9'; Standards: [est_XRechnung]; Syntaxes: AllSyntaxes;
     Profiles: AllProfiles; Severity: eds_Error; Legacy: False; Terms: 'BT-53';
     Message: 'the buyer post code (BT-53) shall be provided';
     Source: XRechnungSource),
    (ID: 'BR-DE-10'; Standards: [est_XRechnung]; Syntaxes: AllSyntaxes;
     Profiles: AllProfiles; Severity: eds_Error; Legacy: False; Terms: 'BT-77';
     Message: 'a deliver to address (BG-15) shall have a deliver to city (BT-77)';
     Source: XRechnungSource),
    (ID: 'BR-DE-11'; Standards: [est_XRechnung]; Syntaxes: AllSyntaxes;
     Profiles: AllProfiles; Severity: eds_Error; Legacy: False; Terms: 'BT-78';
     Message: 'a deliver to address (BG-15) shall have a deliver to post code (BT-78)';
     Source: XRechnungSource),
    (ID: 'BR-DE-15'; Standards: [est_XRechnung]; Syntaxes: AllSyntaxes;
     Profiles: AllProfiles; Severity: eds_Error; Legacy: False; Terms: 'BT-10';
     Message: 'the buyer reference (BT-10) shall be provided';
     Source: XRechnungSource),
    (ID: 'BR-DE-16'; Standards: [est_XRechnung]; Syntaxes: AllSyntaxes;
     Profiles: AllProfiles; Severity: eds_Error; Legacy: False; Terms: 'BT-31, BT-32, BG-11';
     Message: 'with VAT category S, Z, E, AE, K, G, L or M the seller VAT identifier (BT-31), the seller ' +
       'tax registration identifier (BT-32) or a tax representative (BG-11) shall be provided';
     Source: XRechnungSource),
    (ID: 'BR-DE-17'; Standards: [est_XRechnung]; Syntaxes: AllSyntaxes;
     Profiles: AllProfiles; Severity: eds_Warning; Legacy: False; Terms: 'BT-3';
     Message: 'the invoice type code (BT-3) should be 326, 380, 384, 389, 381, 875, 876 or 877';
     Source: XRechnungSource),
    (ID: 'BR-DE-18'; Standards: [est_XRechnung]; Syntaxes: AllSyntaxes;
     Profiles: AllProfiles; Severity: eds_Error; Legacy: False; Terms: 'BT-20';
     Message: 'cash discount lines in the payment terms (BT-20) shall have the form ' +
       '#SKONTO#TAGE=n#PROZENT=p#[BASISBETRAG=b#]';
     Source: XRechnungSource),
    (ID: 'BR-DE-19'; Standards: [est_XRechnung]; Syntaxes: AllSyntaxes;
     Profiles: AllProfiles; Severity: eds_Warning; Legacy: False; Terms: 'BT-84';
     Message: 'the payment account identifier (BT-84) of a SEPA credit transfer (payment means 58) should ' +
       'be a valid IBAN';
     Source: XRechnungSource),
    (ID: 'BR-DE-20'; Standards: [est_XRechnung]; Syntaxes: AllSyntaxes;
     Profiles: AllProfiles; Severity: eds_Warning; Legacy: False; Terms: 'BT-91';
     Message: 'the debited account identifier (BT-91) of a SEPA direct debit (payment means 59) should be ' +
       'a valid IBAN';
     Source: XRechnungSource),
    (ID: 'BR-DE-22'; Standards: [est_XRechnung]; Syntaxes: AllSyntaxes;
     Profiles: AllProfiles; Severity: eds_Error; Legacy: False; Terms: 'BT-125';
     Message: 'the file names of the attached documents (BT-125) shall be unique';
     Source: XRechnungSource),
    (ID: 'BR-DE-23-a'; Standards: [est_XRechnung]; Syntaxes: AllSyntaxes;
     Profiles: AllProfiles; Severity: eds_Error; Legacy: False; Terms: 'BG-17';
     Message: 'a credit transfer (payment means 30 or 58) shall have credit transfer information (BG-17)';
     Source: XRechnungSource),
    (ID: 'BR-DE-23-b'; Standards: [est_XRechnung]; Syntaxes: [esy_CII];
     Profiles: AllProfiles; Severity: eds_Error; Legacy: False; Terms: 'BG-19';
     Message: 'a credit transfer (payment means 30 or 58) shall have no direct debit information (BG-19: ' +
       'mandate BT-89, creditor identifier BT-90)';
     Source: XRechnungSource),
    (ID: 'BR-DE-24-a'; Standards: [est_XRechnung]; Syntaxes: AllSyntaxes;
     Profiles: AllProfiles; Severity: eds_Error; Legacy: False; Terms: 'BG-18';
     Message: 'a card payment (payment means 48, 54 or 55) shall have payment card information (BG-18)';
     Source: XRechnungSource),
    (ID: 'BR-DE-24-b'; Standards: [est_XRechnung]; Syntaxes: [esy_CII];
     Profiles: AllProfiles; Severity: eds_Error; Legacy: False; Terms: 'BG-19';
     Message: 'a card payment (payment means 48, 54 or 55) shall have no direct debit information (BG-19: ' +
       'mandate BT-89, creditor identifier BT-90)';
     Source: XRechnungSource),
    (ID: 'BR-DE-25-a'; Standards: [est_XRechnung]; Syntaxes: AllSyntaxes;
     Profiles: AllProfiles; Severity: eds_Error; Legacy: False; Terms: 'BG-19';
     Message: 'a SEPA direct debit (payment means 59) shall have direct debit information (BG-19)';
     Source: XRechnungSource),
    (ID: 'BR-DE-25-b'; Standards: [est_XRechnung]; Syntaxes: [esy_CII];
     Profiles: AllProfiles; Severity: eds_Error; Legacy: False; Terms: 'BT-86';
     Message: 'a SEPA direct debit (payment means 59) shall have no payment service provider identifier ' +
       '(BT-86)';
     Source: XRechnungSource),
    (ID: 'BR-DE-26'; Standards: [est_XRechnung]; Syntaxes: AllSyntaxes;
     Profiles: AllProfiles; Severity: eds_Warning; Legacy: False; Terms: 'BG-3';
     Message: 'a corrected invoice (type code 384) should have a preceding invoice reference (BG-3)';
     Source: XRechnungSource),
    (ID: 'BR-DE-27'; Standards: [est_XRechnung]; Syntaxes: AllSyntaxes;
     Profiles: AllProfiles; Severity: eds_Warning; Legacy: False; Terms: 'BT-42';
     Message: 'the seller contact telephone number (BT-42) should contain at least three digits';
     Source: XRechnungSource),
    (ID: 'BR-DE-28'; Standards: [est_XRechnung]; Syntaxes: AllSyntaxes;
     Profiles: AllProfiles; Severity: eds_Warning; Legacy: False; Terms: 'BT-43';
     Message: 'the seller contact email address (BT-43) should have the form name@domain with a dot in the ' +
       'domain and no blanks';
     Source: XRechnungSource),
    (ID: 'BR-DE-30'; Standards: [est_XRechnung]; Syntaxes: AllSyntaxes;
     Profiles: AllProfiles; Severity: eds_Error; Legacy: False; Terms: 'BT-90';
     Message: 'direct debit information (BG-19) shall have the bank assigned creditor identifier (BT-90)';
     Source: XRechnungSource),
    (ID: 'BR-DE-31'; Standards: [est_XRechnung]; Syntaxes: AllSyntaxes;
     Profiles: AllProfiles; Severity: eds_Error; Legacy: False; Terms: 'BT-91';
     Message: 'direct debit information (BG-19) shall have the debited account identifier (BT-91)';
     Source: XRechnungSource),
    (ID: 'BR-TMP-2'; Standards: [est_XRechnung]; Syntaxes: AllSyntaxes;
     Profiles: AllProfiles; Severity: eds_Error; Legacy: False; Terms: 'BT-124';
     Message: 'the external document location (BT-124) shall be an absolute URL with a valid scheme';
     Source: XRechnungSource),
    (ID: 'PEPPOL-EN16931-R003'; Standards: [est_PeppolBIS]; Syntaxes: AllSyntaxes;
     Profiles: AllProfiles; Severity: eds_Error; Legacy: False; Terms: 'BT-10, BT-13';
     Message: 'a buyer reference (BT-10) or purchase order reference (BT-13) shall be provided';
     Source: PeppolSource),
    (ID: 'PEPPOL-EN16931-R010'; Standards: [est_XRechnung, est_PeppolBIS]; Syntaxes: AllSyntaxes;
     Profiles: AllProfiles; Severity: eds_Error; Legacy: False; Terms: 'BT-49';
     Message: 'the buyer electronic address (BT-49) shall be provided';
     Source: PeppolXRechnungSource),
    (ID: 'PEPPOL-EN16931-R020'; Standards: [est_XRechnung, est_PeppolBIS]; Syntaxes: AllSyntaxes;
     Profiles: AllProfiles; Severity: eds_Error; Legacy: False; Terms: 'BT-34';
     Message: 'the seller electronic address (BT-34) shall be provided';
     Source: PeppolXRechnungSource),
    (ID: 'PEPPOL-EN16931-R061'; Standards: [est_XRechnung, est_PeppolBIS]; Syntaxes: AllSyntaxes;
     Profiles: AllProfiles; Severity: eds_Error; Legacy: False; Terms: 'BT-89';
     Message: 'a direct debit (payment means 49 or 59) shall have a mandate reference (BT-89)';
     Source: PeppolXRechnungSource),
    (ID: 'PEPPOL-EN16931-R005'; Standards: [est_XRechnung, est_PeppolBIS]; Syntaxes: AllSyntaxes;
     Profiles: AllProfiles; Severity: eds_Error; Legacy: False; Terms: 'BT-6';
     Message: 'the VAT accounting currency code (BT-6) shall differ from the invoice currency code (BT-5)';
     Source: PeppolXRechnungSource),
    (ID: 'PEPPOL-EN16931-R040'; Standards: [est_XRechnung, est_PeppolBIS]; Syntaxes: AllSyntaxes;
     Profiles: AllProfiles; Severity: eds_Error; Legacy: False; Terms: 'BG-20, BG-21, BG-27, BG-28';
     Message: 'an allowance or charge amount shall equal base amount x percentage / 100 when both are provided';
     Source: PeppolXRechnungSource),
    (ID: 'PEPPOL-EN16931-R041'; Standards: [est_XRechnung, est_PeppolBIS]; Syntaxes: AllSyntaxes;
     Profiles: AllProfiles; Severity: eds_Error; Legacy: False; Terms: 'BT-93, BT-100';
     Message: 'an allowance or charge base amount shall be provided when the percentage is provided';
     Source: PeppolXRechnungSource),
    (ID: 'PEPPOL-EN16931-R042'; Standards: [est_XRechnung, est_PeppolBIS]; Syntaxes: AllSyntaxes;
     Profiles: AllProfiles; Severity: eds_Error; Legacy: False; Terms: 'BT-94, BT-101, BT-138, BT-143';
     Message: 'an allowance or charge percentage shall be provided when the base amount is provided';
     Source: PeppolXRechnungSource),
    (ID: 'PEPPOL-EN16931-R046'; Standards: [est_XRechnung, est_PeppolBIS]; Syntaxes: AllSyntaxes;
     Profiles: AllProfiles; Severity: eds_Error; Legacy: False; Terms: 'BT-146, BT-147, BT-148';
     Message: 'the item net price (BT-146) shall equal the gross price (BT-148) minus the price discount (BT-147)';
     Source: PeppolXRechnungSource),
    (ID: 'PEPPOL-EN16931-R053'; Standards: [est_XRechnung, est_PeppolBIS]; Syntaxes: [esy_UBL];
     Profiles: AllProfiles; Severity: eds_Error; Legacy: False; Terms: 'BG-23';
     Message: 'exactly one VAT total with VAT breakdown (BG-23) shall be provided';
     Source: PeppolXRechnungSource),
    (ID: 'PEPPOL-EN16931-R054'; Standards: [est_XRechnung, est_PeppolBIS]; Syntaxes: AllSyntaxes;
     Profiles: AllProfiles; Severity: eds_Error; Legacy: False; Terms: 'BT-111';
     Message: 'one VAT total without VAT breakdown (BT-111) shall be provided when the VAT accounting currency ' +
       '(BT-6) is provided, none otherwise';
     Source: PeppolXRechnungSource),
    (ID: 'PEPPOL-EN16931-R055'; Standards: [est_XRechnung, est_PeppolBIS]; Syntaxes: AllSyntaxes;
     Profiles: AllProfiles; Severity: eds_Error; Legacy: False; Terms: 'BT-110, BT-111';
     Message: 'the invoice total VAT amount (BT-110) and the total VAT amount in the accounting currency (BT-111) ' +
       'shall have the same sign';
     Source: PeppolXRechnungSource),
    (ID: 'PEPPOL-EN16931-R110'; Standards: [est_XRechnung, est_PeppolBIS]; Syntaxes: AllSyntaxes;
     Profiles: AllProfiles; Severity: eds_Error; Legacy: False; Terms: 'BT-134, BT-73';
     Message: 'the start date of a line period (BT-134) shall not be before the invoice period start date (BT-73)';
     Source: PeppolXRechnungSource),
    (ID: 'PEPPOL-EN16931-R111'; Standards: [est_XRechnung, est_PeppolBIS]; Syntaxes: AllSyntaxes;
     Profiles: AllProfiles; Severity: eds_Error; Legacy: False; Terms: 'BT-135, BT-74';
     Message: 'the end date of a line period (BT-135) shall not be after the invoice period end date (BT-74)';
     Source: PeppolXRechnungSource),
    (ID: 'PEPPOL-EN16931-R120'; Standards: [est_XRechnung]; Syntaxes: AllSyntaxes;
     Profiles: AllProfiles; Severity: eds_Warning; Legacy: False; Terms: 'BT-131';
     Message: 'the line net amount (BT-131) should equal quantity x (net price / base quantity) + charges - ' +
       'allowances';
     Source: PeppolXRechnungSource),
    (ID: 'PEPPOL-EN16931-R120'; Standards: [est_PeppolBIS]; Syntaxes: AllSyntaxes;
     Profiles: AllProfiles; Severity: eds_Error; Legacy: False; Terms: 'BT-131';
     Message: 'the line net amount (BT-131) shall equal quantity x (net price / base quantity) + charges - ' +
       'allowances';
     Source: PeppolSource),
    (ID: 'PEPPOL-EN16931-R121'; Standards: [est_XRechnung, est_PeppolBIS]; Syntaxes: AllSyntaxes;
     Profiles: AllProfiles; Severity: eds_Error; Legacy: False; Terms: 'BT-149';
     Message: 'the item price base quantity (BT-149) shall be above zero';
     Source: PeppolXRechnungSource),
    (ID: 'PEPPOL-EN16931-R130'; Standards: [est_XRechnung, est_PeppolBIS]; Syntaxes: AllSyntaxes;
     Profiles: AllProfiles; Severity: eds_Error; Legacy: False; Terms: 'BT-150, BT-130';
     Message: 'the unit of the item price base quantity (BT-150) shall be that of the invoiced quantity (BT-130)';
     Source: PeppolXRechnungSource),
    (ID: 'BR-CO-03'; Standards: EN16931Standards; Syntaxes: AllSyntaxes;
     Profiles: FromBasicWL; Severity: eds_Error; Legacy: False; Terms: 'BT-7, BT-8';
     Message: 'the VAT point date (BT-7) and the VAT point date code (BT-8) are mutually exclusive';
     Source: EN16931Source),
    (ID: 'BR-CO-04'; Standards: EN16931Standards; Syntaxes: AllSyntaxes;
     Profiles: FromBasicNoExtended; Severity: eds_Error; Legacy: False; Terms: 'BT-151';
     Message: 'each invoice line (BG-25) shall have an invoiced item VAT category code (BT-151)';
     Source: EN16931Source),
    (ID: 'BR-CO-09'; Standards: EN16931Standards; Syntaxes: AllSyntaxes;
     Profiles: AllProfiles; Severity: eds_Error; Legacy: False; Terms: 'BT-31, BT-48, BT-63';
     Message: 'a VAT identifier (BT-31, BT-48, BT-63) shall start with an ISO 3166-1 alpha-2 country code ' +
       '(Greece: EL)';
     Source: EN16931Source),
    (ID: 'BR-CO-10'; Standards: EN16931Standards; Syntaxes: AllSyntaxes;
     Profiles: FromBasicNoExtended; Severity: eds_Error; Legacy: False; Terms: 'BT-106, BT-131';
     Message: 'sum of invoice line net amount (BT-106) = sum of invoice line net amounts (BT-131)';
     Source: EN16931Source),
    (ID: 'BR-CO-11'; Standards: EN16931Standards; Syntaxes: AllSyntaxes;
     Profiles: FromBasicWLNoExtended; Severity: eds_Error; Legacy: False; Terms: 'BT-107, BT-92';
     Message: 'sum of allowances on document level (BT-107) = sum of document level allowance amounts (BT-92)';
     Source: EN16931Source),
    (ID: 'BR-CO-12'; Standards: EN16931Standards; Syntaxes: AllSyntaxes;
     Profiles: FromBasicWLNoExtended; Severity: eds_Error; Legacy: False; Terms: 'BT-108, BT-99';
     Message: 'sum of charges on document level (BT-108) = sum of document level charge amounts (BT-99)';
     Source: EN16931Source),
    (ID: 'BR-CO-13'; Standards: EN16931Standards; Syntaxes: AllSyntaxes;
     Profiles: FromBasicWLNoExtended; Severity: eds_Error; Legacy: False; Terms: 'BT-109';
     Message: 'invoice total amount without VAT (BT-109) = BT-106 - BT-107 + BT-108';
     Source: EN16931Source),
    (ID: 'BR-CO-14'; Standards: EN16931Standards; Syntaxes: AllSyntaxes;
     Profiles: FromBasicWL; Severity: eds_Error; Legacy: False; Terms: 'BT-110, BT-117';
     Message: 'invoice total VAT amount (BT-110) = sum of VAT category tax amounts (BT-117)';
     Source: EN16931Source),
    (ID: 'BR-CO-15'; Standards: EN16931Standards; Syntaxes: AllSyntaxes;
     Profiles: FromBasicWLNoExtended; Severity: eds_Error; Legacy: False; Terms: 'BT-112';
     Message: 'invoice total amount with VAT (BT-112) = BT-109 + BT-110';
     Source: EN16931Source),
    (ID: 'BR-CO-16'; Standards: EN16931Standards; Syntaxes: AllSyntaxes;
     Profiles: FromBasicWLNoExtended; Severity: eds_Error; Legacy: False; Terms: 'BT-115';
     Message: 'amount due for payment (BT-115) = BT-112 - BT-113 + BT-114';
     Source: EN16931Source),
    (ID: 'BR-CO-17'; Standards: EN16931Standards; Syntaxes: AllSyntaxes;
     Profiles: FromBasicWLNoExtended; Severity: eds_Error; Legacy: False; Terms: 'BT-117';
     Message: 'VAT category tax amount (BT-117) = VAT category taxable amount (BT-116) x rate (BT-119) / 100, ' +
       'rounded to two decimals (tolerance 1)';
     Source: EN16931Source),
    (ID: 'BR-CO-18'; Standards: EN16931Standards; Syntaxes: AllSyntaxes;
     Profiles: FromBasicWL; Severity: eds_Error; Legacy: False; Terms: 'BG-23';
     Message: 'an invoice shall have at least one VAT breakdown (BG-23)';
     Source: EN16931Source),
    (ID: 'BR-CO-21'; Standards: EN16931Standards; Syntaxes: AllSyntaxes;
     Profiles: FromBasicWL; Severity: eds_Error; Legacy: False; Terms: 'BT-97, BT-98';
     Message: 'each document level allowance (BG-20) shall have a reason (BT-97) or a reason code (BT-98)';
     Source: EN16931Source),
    (ID: 'BR-CO-22'; Standards: EN16931Standards; Syntaxes: AllSyntaxes;
     Profiles: FromBasicWLNoExtended; Severity: eds_Error; Legacy: False; Terms: 'BT-104, BT-105';
     Message: 'each document level charge (BG-21) shall have a reason (BT-104) or a reason code (BT-105)';
     Source: EN16931Source),
    (ID: 'BR-CO-23'; Standards: EN16931Standards; Syntaxes: AllSyntaxes;
     Profiles: FromBasic; Severity: eds_Error; Legacy: False; Terms: 'BT-139, BT-140';
     Message: 'each invoice line allowance (BG-27) shall have a reason (BT-139) or a reason code (BT-140)';
     Source: EN16931Source),
    (ID: 'BR-CO-24'; Standards: EN16931Standards; Syntaxes: AllSyntaxes;
     Profiles: FromBasicNoExtended; Severity: eds_Error; Legacy: False; Terms: 'BT-144, BT-145';
     Message: 'each invoice line charge (BG-28) shall have a reason (BT-144) or a reason code (BT-145)';
     Source: EN16931Source),
    (ID: 'BR-CO-25'; Standards: [est_FacturX]; Syntaxes: AllSyntaxes;
     Profiles: [epr_Extended]; Severity: eds_Error; Legacy: False; Terms: 'BT-9, BT-20';
     Message: 'with a positive amount due for payment (BT-115) the payment due date (BT-9) or the payment ' +
       'terms (BT-20) shall be provided';
     Source: FacturXExtendedSource),
    (ID: 'BR-CO-26'; Standards: EN16931Standards; Syntaxes: AllSyntaxes;
     Profiles: AllProfiles; Severity: eds_Error; Legacy: False; Terms: 'BT-29, BT-30, BT-31';
     Message: 'the seller identifier (BT-29), legal registration identifier (BT-30) or VAT identifier (BT-31) ' +
       'shall be provided';
     Source: EN16931Source),
    (ID: 'BR-FXEXT-CO-04'; Standards: [est_FacturX]; Syntaxes: AllSyntaxes;
     Profiles: [epr_Extended]; Severity: eds_Error; Legacy: False; Terms: 'BT-151';
     Message: 'each invoice line without status or with status DETAIL (BG-25, also a sub line) shall have an ' +
       'invoiced item VAT category code (BT-151)';
     Source: FacturXExtendedSource),
    (ID: 'BR-FXEXT-CO-10'; Standards: [est_FacturX]; Syntaxes: AllSyntaxes;
     Profiles: [epr_Extended]; Severity: eds_Error; Legacy: False; Terms: 'BT-106, BT-131';
     Message: 'sum of invoice line net amount (BT-106) differs from the sum of the DETAIL line net amounts ' +
       '(BT-131) by more than 0.01 per line';
     Source: FacturXExtendedSource),
    (ID: 'BR-FXEXT-CO-11'; Standards: [est_FacturX]; Syntaxes: AllSyntaxes;
     Profiles: [epr_Extended]; Severity: eds_Error; Legacy: False; Terms: 'BT-107, BT-92';
     Message: 'sum of allowances on document level (BT-107) differs from the sum of the allowances (BT-92) by ' +
       'more than 0.01 per allowance';
     Source: FacturXExtendedSource),
    (ID: 'BR-FXEXT-CO-12'; Standards: [est_FacturX]; Syntaxes: AllSyntaxes;
     Profiles: [epr_Extended]; Severity: eds_Error; Legacy: False; Terms: 'BT-108, BT-99';
     Message: 'sum of charges on document level (BT-108) differs from the sum of the charges (BT-99) by more ' +
       'than 0.01 per charge';
     Source: FacturXExtendedSource),
    (ID: 'BR-FXEXT-CO-13'; Standards: [est_FacturX]; Syntaxes: AllSyntaxes;
     Profiles: [epr_Extended]; Severity: eds_Error; Legacy: False; Terms: 'BT-109';
     Message: 'invoice total amount without VAT (BT-109) differs from the DETAIL line net amounts - allowances ' +
       '+ charges by more than 0.01 per amount';
     Source: FacturXExtendedSource),
    (ID: 'BR-FXEXT-CO-15'; Standards: [est_FacturX]; Syntaxes: AllSyntaxes;
     Profiles: [epr_Extended]; Severity: eds_Error; Legacy: False; Terms: 'BT-112';
     Message: 'invoice total amount with VAT (BT-112) differs from BT-109 + BT-110 by more than 0.01 per ' +
       'amount';
     Source: FacturXExtendedSource),
    (ID: 'BR-FXEXT-CO-16'; Standards: [est_FacturX]; Syntaxes: AllSyntaxes;
     Profiles: [epr_Extended]; Severity: eds_Error; Legacy: False; Terms: 'BT-115';
     Message: 'amount due for payment (BT-115) = BT-112 - BT-113 + BT-114 + third-party ' +
       'charges (ram:SpecifiedFinancialAdjustment)';
     Source: FacturXExtendedSource),
    (ID: 'BR-FXEXT-08'; Standards: [est_FacturX]; Syntaxes: AllSyntaxes;
     Profiles: [epr_Extended]; Severity: eds_Error; Legacy: False; Terms: 'BG-DEX-01, BT-131';
     Message: 'the amount of a GROUP line (BT-131) shall be the sum of the amounts of its DETAIL and ' +
       'GROUP sub lines';
     Source: FacturXExtendedSource),
    (ID: 'BR-DEX-09'; Standards: [est_XRechnung]; Syntaxes: [esy_UBL];
     Profiles: AllProfiles; Severity: eds_Error; Legacy: False; Terms: 'BT-115, BT-DEX-002';
     Message: 'amount due for payment (BT-115) = BT-112 - BT-113 + BT-114 + sum of third-party payment ' +
       'amounts (BT-DEX-002)';
     Source: XRechnungSource),
    (ID: 'BR-DEX-14'; Standards: [est_XRechnung]; Syntaxes: [esy_UBL];
     Profiles: AllProfiles; Severity: eds_Error; Legacy: False; Terms: 'BT-DEX-002, BT-5';
     Message: 'the currency of a third-party payment amount (BT-DEX-002) shall be the invoice currency (BT-5)';
     Source: XRechnungSource),
    (ID: 'BR-CL-01'; Standards: CodeListStandards; Syntaxes: AllSyntaxes;
     Profiles: AllProfiles; Severity: eds_Error; Legacy: False; Terms: 'BT-3';
     Message: 'the invoice type code (BT-3) shall be coded with UNTDID 1001 (UBL: the codes of ubl:Invoice; ' +
       'ubl:CreditNote is written for 381 only)';
     Source: EN16931Source),
    (ID: 'BR-CL-03'; Standards: CodeListStandards; Syntaxes: AllSyntaxes;
     Profiles: AllProfiles; Severity: eds_Error; Legacy: False; Terms: 'BT-5, BT-6';
     Message: 'the currency of the amounts (@currencyID: BT-5, BT-6) shall be coded with ISO 4217';
     Source: EN16931Source),
    (ID: 'BR-CL-04'; Standards: CodeListStandards; Syntaxes: AllSyntaxes;
     Profiles: AllProfiles; Severity: eds_Error; Legacy: False; Terms: 'BT-5';
     Message: 'the invoice currency code (BT-5) shall be coded with ISO 4217';
     Source: EN16931Source),
    (ID: 'BR-CL-05'; Standards: CodeListStandards; Syntaxes: AllSyntaxes;
     Profiles: AllProfiles; Severity: eds_Error; Legacy: False; Terms: 'BT-6';
     Message: 'the VAT accounting currency code (BT-6) shall be coded with ISO 4217';
     Source: EN16931Source),
    (ID: 'BR-CL-06'; Standards: CodeListStandards; Syntaxes: AllSyntaxes;
     Profiles: AllProfiles; Severity: eds_Error; Legacy: False; Terms: 'BT-8';
     Message: 'the VAT point date code (BT-8) shall be coded with UNTDID 2005 (UBL: 3, 35, 432; CII: 5, 29, 72)';
     Source: EN16931Source),
    (ID: 'BR-CL-07'; Standards: CodeListStandards; Syntaxes: AllSyntaxes;
     Profiles: AllProfiles; Severity: eds_Error; Legacy: False; Terms: 'BT-18, BT-128';
     Message: 'the scheme of an object identifier (BT-18, BT-128) shall be coded with UNTDID 1153';
     Source: EN16931Source),
    (ID: 'BR-CL-08'; Standards: CodeListStandards; Syntaxes: AllSyntaxes;
     Profiles: AllProfiles; Severity: eds_Error; Legacy: False; Terms: 'BT-21';
     Message: 'the invoice note subject code (BT-21) shall be coded with UNTDID 4451';
     Source: EN16931Source),
    (ID: 'BR-CL-10'; Standards: CodeListStandards; Syntaxes: AllSyntaxes;
     Profiles: AllProfiles; Severity: eds_Error; Legacy: False; Terms: 'BT-29, BT-46, BT-60';
     Message: 'the scheme of a party identifier (BT-29, BT-46, BT-60) shall be coded with ISO 6523 ICD (UBL: SEPA ' +
       'as well for the seller and the payee)';
     Source: EN16931Source),
    (ID: 'BR-CL-11'; Standards: CodeListStandards; Syntaxes: AllSyntaxes;
     Profiles: AllProfiles; Severity: eds_Error; Legacy: False; Terms: 'BT-30, BT-47, BT-61';
     Message: 'the scheme of a legal registration identifier (BT-30, BT-47, BT-61) shall be coded with ISO 6523 ICD';
     Source: EN16931Source),
    (ID: 'BR-CL-13'; Standards: CodeListStandards; Syntaxes: AllSyntaxes;
     Profiles: AllProfiles; Severity: eds_Error; Legacy: False; Terms: 'BT-158';
     Message: 'the scheme of an item classification identifier (BT-158) shall be coded with UNTDID 7143';
     Source: EN16931Source),
    (ID: 'BR-CL-14'; Standards: CodeListStandards; Syntaxes: AllSyntaxes;
     Profiles: AllProfiles; Severity: eds_Error; Legacy: False; Terms: 'BT-40, BT-55, BT-69, BT-80';
     Message: 'country codes (BT-40, BT-55, BT-69, BT-80) shall be coded with ISO 3166-1';
     Source: EN16931Source),
    (ID: 'BR-CL-15'; Standards: CodeListStandards; Syntaxes: AllSyntaxes;
     Profiles: AllProfiles; Severity: eds_Error; Legacy: False; Terms: 'BT-159';
     Message: 'the item country of origin (BT-159) shall be coded with ISO 3166-1';
     Source: EN16931Source),
    (ID: 'BR-CL-16'; Standards: CodeListStandards; Syntaxes: AllSyntaxes;
     Profiles: AllProfiles; Severity: eds_Error; Legacy: False; Terms: 'BT-81';
     Message: 'the payment means type code (BT-81) shall be coded with UNTDID 4461';
     Source: EN16931Source),
    (ID: 'BR-CL-17'; Standards: CodeListStandards; Syntaxes: AllSyntaxes;
     Profiles: AllProfiles; Severity: eds_Error; Legacy: False; Terms: 'BT-95, BT-102, BT-118';
     Message: 'the VAT category code of a document level allowance or charge (BT-95, BT-102; UBL: also of the VAT ' +
       'breakdown, BT-118) shall be coded with UNTDID 5305';
     Source: EN16931Source),
    (ID: 'BR-CL-18'; Standards: CodeListStandards; Syntaxes: AllSyntaxes;
     Profiles: AllProfiles; Severity: eds_Error; Legacy: False; Terms: 'BT-151, BT-118';
     Message: 'the invoiced item VAT category code (BT-151; CII: also of the VAT breakdown, BT-118) shall be coded ' +
       'with UNTDID 5305';
     Source: EN16931Source),
    (ID: 'BR-CL-19'; Standards: CodeListStandards; Syntaxes: AllSyntaxes;
     Profiles: AllProfiles; Severity: eds_Error; Legacy: False; Terms: 'BT-98, BT-140';
     Message: 'an allowance reason code (BT-98, BT-140) shall be coded with UNTDID 5189';
     Source: EN16931Source),
    (ID: 'BR-CL-20'; Standards: CodeListStandards; Syntaxes: AllSyntaxes;
     Profiles: AllProfiles; Severity: eds_Error; Legacy: False; Terms: 'BT-105, BT-145';
     Message: 'a charge reason code (BT-105, BT-145) shall be coded with UNTDID 7161';
     Source: EN16931Source),
    (ID: 'BR-CL-21'; Standards: [est_XRechnung]; Syntaxes: AllSyntaxes;
     Profiles: AllProfiles; Severity: eds_Warning; Legacy: False; Terms: 'BT-157';
     Message: 'the scheme of the item standard identifier (BT-157) shall be coded with ISO 6523 ICD';
     Source: XRechnungLevelSource),
    (ID: 'BR-CL-21'; Standards: [est_PeppolBIS]; Syntaxes: AllSyntaxes;
     Profiles: AllProfiles; Severity: eds_Error; Legacy: False; Terms: 'BT-157';
     Message: 'the scheme of the item standard identifier (BT-157) shall be coded with ISO 6523 ICD';
     Source: EN16931Source),
    (ID: 'BR-CL-22'; Standards: CodeListStandards; Syntaxes: AllSyntaxes;
     Profiles: AllProfiles; Severity: eds_Error; Legacy: False; Terms: 'BT-121';
     Message: 'the VAT exemption reason code (BT-121) shall be coded with the VATEX list';
     Source: EN16931Source),
    (ID: 'BR-CL-23'; Standards: [est_XRechnung]; Syntaxes: AllSyntaxes;
     Profiles: AllProfiles; Severity: eds_Warning; Legacy: False; Terms: 'BT-130, BT-150';
     Message: 'a unit of measure (BT-130, BT-150) shall be coded with UN/ECE Recommendation 20 or 21';
     Source: XRechnungLevelSource),
    (ID: 'BR-CL-23'; Standards: [est_PeppolBIS]; Syntaxes: AllSyntaxes;
     Profiles: AllProfiles; Severity: eds_Error; Legacy: False; Terms: 'BT-130, BT-150';
     Message: 'a unit of measure (BT-130, BT-150) shall be coded with UN/ECE Recommendation 20 or 21';
     Source: EN16931Source),
    (ID: 'BR-CL-24'; Standards: CodeListStandards; Syntaxes: AllSyntaxes;
     Profiles: AllProfiles; Severity: eds_Error; Legacy: False; Terms: 'BT-125';
     Message: 'the MIME code of an attached document (BT-125) shall be application/pdf, image/png, image/jpeg, ' +
       'text/csv, an xlsx or an ods spreadsheet';
     Source: EN16931Source),
    (ID: 'BR-CL-25'; Standards: CodeListStandards; Syntaxes: AllSyntaxes;
     Profiles: AllProfiles; Severity: eds_Error; Legacy: False; Terms: 'BT-34, BT-49';
     Message: 'the scheme of an electronic address (BT-34, BT-49) shall be coded with the EAS list';
     Source: EN16931Source),
    (ID: 'BR-CL-26'; Standards: CodeListStandards; Syntaxes: AllSyntaxes;
     Profiles: AllProfiles; Severity: eds_Error; Legacy: False; Terms: 'BT-71';
     Message: 'the scheme of the deliver to location identifier (BT-71) shall be coded with ISO 6523 ICD';
     Source: EN16931Source),
    { The XRechnung extension replaces BR-CL-24, 10, 11, 21, 25 and 26 by
      the same checks with the extended lists: the schemes XR01 to XR03
      and the MIME code application/xml.
      DE: Die XRechnung-Extension ersetzt BR-CL-24, 10, 11, 21, 25 und 26
      durch dieselben Pruefungen mit den erweiterten Listen: die Schemata
      XR01 bis XR03 und der MIME-Code application/xml. }
    (ID: 'BR-DEX-01'; Standards: [est_XRechnung]; Syntaxes: AllSyntaxes;
     Profiles: AllProfiles; Severity: eds_Error; Legacy: False; Terms: 'BT-125';
     Message: 'with the extension the MIME code of an attached document (BT-125) shall be one of BR-CL-24 or ' +
       'application/xml';
     Source: XRechnungSource),
    (ID: 'BR-DEX-04'; Standards: [est_XRechnung]; Syntaxes: AllSyntaxes;
     Profiles: AllProfiles; Severity: eds_Error; Legacy: False; Terms: 'BT-29, BT-46, BT-60';
     Message: 'with the extension the scheme of a party identifier (BT-29, BT-46, BT-60) shall be coded with ' +
       'ISO 6523 ICD or XR01 to XR03';
     Source: XRechnungSource),
    (ID: 'BR-DEX-05'; Standards: [est_XRechnung]; Syntaxes: AllSyntaxes;
     Profiles: AllProfiles; Severity: eds_Error; Legacy: False; Terms: 'BT-30, BT-47, BT-61';
     Message: 'with the extension the scheme of a legal registration identifier (BT-30, BT-47, BT-61) shall be ' +
       'coded with ISO 6523 ICD or XR01 to XR03';
     Source: XRechnungSource),
    (ID: 'BR-DEX-06'; Standards: [est_XRechnung]; Syntaxes: AllSyntaxes;
     Profiles: AllProfiles; Severity: eds_Error; Legacy: False; Terms: 'BT-157';
     Message: 'with the extension the scheme of an item standard identifier (BT-157) shall be coded with ' +
       'ISO 6523 ICD or XR01 to XR03';
     Source: XRechnungSource),
    (ID: 'BR-DEX-07'; Standards: [est_XRechnung]; Syntaxes: AllSyntaxes;
     Profiles: AllProfiles; Severity: eds_Error; Legacy: False; Terms: 'BT-34, BT-49';
     Message: 'with the extension the scheme of an electronic address (BT-34, BT-49) shall be coded with the ' +
       'EAS list or XR01 to XR03';
     Source: XRechnungSource),
    (ID: 'BR-DEX-08'; Standards: [est_XRechnung]; Syntaxes: AllSyntaxes;
     Profiles: AllProfiles; Severity: eds_Error; Legacy: False; Terms: 'BT-71';
     Message: 'with the extension the scheme of the deliver to location identifier (BT-71) shall be coded ' +
       'with ISO 6523 ICD or XR01 to XR03';
     Source: XRechnungSource));

function Applies(const ARow: TCheckRow; const ASpec: TLandrixEInvoiceSpec): Boolean;
begin
  Result := (ASpec.Target.Standard in ARow.Standards) and
    (ASpec.Target.Syntax in ARow.Syntaxes) and (ASpec.Target.Profile in ARow.Profiles);
end;

{ --- helpers ------------------------------------------------------------------- }

function Present(const S: TLandrixEInvoiceString): Boolean;
begin
  Result := not LandrixEInvoiceIsBlank(S);
end;

{ Top level only: an INFORMATION line there would count outside EXTENDED.
  DE: Nur oberste Ebene: dort wuerde eine INFORMATION-Position ausserhalb
  von EXTENDED mitgezaehlt. }
function HasInformationLines(ALines: TLandrixInvoiceLines): Boolean;
var
  I: TLandrixEInvoiceListIndex;
begin
  Result := True;
  for I := 0 to ALines.Count - 1 do
    if ALines[I].LineStatusReasonCode = ilsrc_Information then
      Exit;
  Result := False;
end;

function CentAmount(AValue: Currency): Currency;
var
  Rounded: Boolean;
begin
  if not LandrixEInvoiceTryLexicalToCurrency(LandrixEInvoiceAmountToLexical(AValue), Result, Rounded) then
    Result := AValue;
end;

{ BR-FXEXT-08: a GROUP amount equals the sum of its DETAIL and GROUP sub
  lines, compared on the cent amounts that are written.
  DE: BR-FXEXT-08: Ein GROUP-Betrag ist die Summe seiner DETAIL- und
  GROUP-Unterpositionen, verglichen auf den Centbetraegen, die geschrieben
  werden. }
function NormalizedSpace(const AValue: TLandrixEInvoiceString): TLandrixEInvoiceString; forward;
function WrittenCode(const AEnumText, AOther: TLandrixEInvoiceString): TLandrixEInvoiceString; forward;
function ExtensionWritten(AInvoice: TLandrixInvoice; const ASpec: TLandrixEInvoiceSpec): Boolean; forward;

function HasGroupAmountMismatch(ALines: TLandrixInvoiceLines; AIsSubLine: Boolean): Boolean;
var
  I, K: TLandrixEInvoiceListIndex;
  Sum: Currency;
begin
  Result := True;
  for I := 0 to ALines.Count - 1 do
  begin
    if LandrixEInvoiceLineStatusOf(ALines[I], AIsSubLine) = ilsrc_Group then
    begin
      Sum := 0;
      for K := 0 to ALines[I].SubInvoiceLines.Count - 1 do
        if LandrixEInvoiceLineStatusOf(ALines[I].SubInvoiceLines[K], True) in [ilsrc_Detail, ilsrc_Group] then
          Sum := Sum + CentAmount(ALines[I].SubInvoiceLines[K].LineAmount);
      if CentAmount(Sum) <> CentAmount(ALines[I].LineAmount) then
        Exit;
    end;
    if HasGroupAmountMismatch(ALines[I].SubInvoiceLines, True) then
      Exit;
  end;
  Result := False;
end;

{ An explicit DETAIL line with sub lines: EXTENDED counts both levels, UBL
  only the parent. DE: Eine ausdrueckliche DETAIL-Position mit
  Unterpositionen: EXTENDED zaehlt beide Ebenen, UBL nur die Oberposition. }
function HasDetailWithSubInvoiceLines(ALines: TLandrixInvoiceLines): Boolean;
var
  I: TLandrixEInvoiceListIndex;
begin
  Result := True;
  for I := 0 to ALines.Count - 1 do
    if ((ALines[I].LineStatusReasonCode = ilsrc_Detail) and (ALines[I].SubInvoiceLines.Count > 0)) or
       HasDetailWithSubInvoiceLines(ALines[I].SubInvoiceLines) then
      Exit;
  Result := False;
end;

function HasLineDeliveryData(ALines: TLandrixInvoiceLines): Boolean;
var
  I: TLandrixEInvoiceListIndex;
begin
  Result := True;
  for I := 0 to ALines.Count - 1 do
    if Present(ALines[I].DeliveryNoteNumber) or Present(ALines[I].DeliveryNoteLineID) or
       (ALines[I].DeliveryNoteDate > 0) or (ALines[I].ActualDeliveryDate > 0) or
       HasLineDeliveryData(ALines[I].SubInvoiceLines) then
      Exit;
  Result := False;
end;

function CountPayments(AInvoice: TLandrixInvoice; ACode: TLandrixInvoicePaymentMeansCode): Integer;
var
  I: TLandrixEInvoiceListIndex;
begin
  Result := 0;
  for I := 0 to AInvoice.PaymentTypes.Count - 1 do
    if AInvoice.PaymentTypes[I].PaymentMeansCode = ACode then
      Inc(Result);
end;

{ Peppol: a scheme from the EAS code list is mandatory, 'EM' is none, and
  the default 'EM' for an empty scheme is not applied (rule table).
  DE: Peppol: ein Schema aus der EAS-Codeliste ist Pflicht, 'EM' ist
  keines, und die Vorgabe 'EM' fuer ein leeres Schema gilt nicht
  (Regel-Tabelle). }
function BadElectronicAddress(AParty: TLandrixInvoiceAccountingParty; AIsPeppol, ANoDefaultEM: Boolean): Boolean;
begin
  Result := Present(AParty.ElectronicAddressSellerBuyer) and
    ((AIsPeppol and (AParty.ElectronicAddressSellerBuyerSchemeID = 'EM')) or
     (ANoDefaultEM and not Present(AParty.ElectronicAddressSellerBuyerSchemeID)));
end;

function Forbidden(const ASpec: TLandrixEInvoiceSpec; const AKey: string): Boolean;
begin
  Result := LandrixEInvoiceRuleLevel(ASpec, AKey) = erl_Forbidden;
end;

function IsFacturXExtended(const ASpec: TLandrixEInvoiceSpec): Boolean;
begin
  Result := (ASpec.Target.Standard = est_FacturX) and (ASpec.Target.Profile = epr_Extended);
end;

function AddressSet(AAddress: TLandrixInvoiceAddress): Boolean;
begin
  Result := Present(AAddress.StreetName) or Present(AAddress.AdditionalStreetName) or
    Present(AAddress.AddressLine) or Present(AAddress.City) or Present(AAddress.PostalZone) or
    Present(AAddress.CountrySubentity) or Present(AAddress.CountryCode);
end;

{ A payee or tax representative exists when a field other than a scheme
  holds text; blank text counts as absent (as in the mappers).
  DE: Ein Zahlungsempfaenger oder Steuervertreter existiert, wenn ein Feld
  ausser einem Schema Text enthaelt; leerer Text gilt als nicht vorhanden
  (wie in den Mappern). }
function PartySet(AParty: TLandrixInvoiceParty): Boolean;
begin
  Result := Present(AParty.Name) or Present(AParty.Identifier) or Present(AParty.CompanyID) or
    Present(AParty.VATCompanyID) or AddressSet(AParty.Address) or Present(AParty.ContactName) or
    Present(AParty.ContactDepartment) or Present(AParty.ContactTelephone) or
    Present(AParty.ContactElectronicMail);
end;

function ContactSet(AParty: TLandrixInvoiceAccountingParty): Boolean;
begin
  Result := Present(AParty.ContactName) or Present(AParty.ContactDepartment) or
    Present(AParty.ContactTelephone) or Present(AParty.ContactElectronicMail);
end;

{ The mappers write a payment instruction only with a payment means code.
  DE: Die Mapper schreiben eine Zahlungsanweisung nur mit Zahlungsart. }
function PaymentWritten(APayment: TLandrixInvoicePaymentType): Boolean;
begin
  Result := (APayment.PaymentMeansCode <> ipmc_NotImplemented) or Present(APayment.PaymentMeansCodeOther);
end;

{ The payment means code as written: the enumeration, otherwise the other
  text, white space normalized (the Schematron compares
  normalize-space(...)).
  DE: Der Zahlungsartcode, wie er geschrieben wird: die Aufzaehlung, sonst
  der andere Text, Leerraum normalisiert. }
function PaymentCodeOf(APayment: TLandrixInvoicePaymentType): TLandrixEInvoiceString;
begin
  if APayment.PaymentMeansCode <> ipmc_NotImplemented then
    Result := LandrixEInvoicePaymentMeansCodeToStr(APayment.PaymentMeansCode)
  else
    Result := NormalizedSpace(APayment.PaymentMeansCodeOther);
end;

function IsCreditTransfer(APayment: TLandrixInvoicePaymentType): Boolean;
var
  Code: TLandrixEInvoiceString;
begin
  Code := PaymentCodeOf(APayment);
  Result := (Code = '30') or (Code = '58');
end;

function IsCard(APayment: TLandrixInvoicePaymentType): Boolean;
var
  Code: TLandrixEInvoiceString;
begin
  Code := PaymentCodeOf(APayment);
  Result := (Code = '48') or (Code = '54') or (Code = '55');
end;

function IsDirectDebitCode(APayment: TLandrixInvoicePaymentType): Boolean;
var
  Code: TLandrixEInvoiceString;
begin
  Code := PaymentCodeOf(APayment);
  Result := (Code = '49') or (Code = '59');
end;

{ Payment kinds of the payment-group rules (BR-61, BR-DE-23 to BR-DE-25,
  BR-DE-30, BR-DE-31, PEPPOL-EN16931-R061).
  DE: Zahlungsarten der Regeln zu den Zahlungsgruppen. }
type
  { All kinds go by the code as written: the rules test it, and the
    mappers write the card and direct debit groups by it.
    DE: Alle Arten gehen nach dem geschriebenen Code: die Regeln pruefen
    ihn, und die Mapper schreiben die Karten- und Lastschriftgruppen danach. }
  TPaymentKind = (pk_Written, pk_CreditTransfer, pk_CreditTransferWithoutAccount, pk_Card,
    pk_CardWithoutAccount, pk_DirectDebit, pk_DirectDebitWithAccount, pk_SEPADirectDebitWithBIC,
    pk_SEPADirectDebitWithoutAccount);

function HasPayment(AInvoice: TLandrixInvoice; AKind: TPaymentKind): Boolean;
var
  I: TLandrixEInvoiceListIndex;
  P: TLandrixInvoicePaymentType;
  Hit: Boolean;
begin
  Result := True;
  for I := 0 to AInvoice.PaymentTypes.Count - 1 do
  begin
    P := AInvoice.PaymentTypes[I];
    Hit := False;
    case AKind of
      pk_Written:
        Hit := PaymentWritten(P);
      pk_CreditTransfer:
        Hit := IsCreditTransfer(P);
      pk_CreditTransferWithoutAccount:
        Hit := IsCreditTransfer(P) and not Present(P.FinancialAccount);
      pk_Card:
        Hit := IsCard(P);
      pk_CardWithoutAccount:
        Hit := IsCard(P) and not Present(P.FinancialAccount);
      pk_DirectDebit:
        Hit := IsDirectDebitCode(P);
      pk_DirectDebitWithAccount:
        Hit := IsDirectDebitCode(P) and Present(P.FinancialAccount);
      pk_SEPADirectDebitWithoutAccount:
        Hit := (PaymentCodeOf(P) = '59') and not Present(P.FinancialAccount);
      pk_SEPADirectDebitWithBIC:
        Hit := (PaymentCodeOf(P) = '59') and Present(P.FinancialInstitutionBranch);
    end;
    if Hit then
      Exit;
  end;
  Result := False;
end;

{ BT-90 as the validators see it: the seller's creditor identifier; in UBL
  also a payee identifier or a seller global identifier with scheme SEPA
  (both are written as cac:PartyIdentification with that scheme).
  DE: BT-90, wie die Validatoren es sehen: die Glaeubiger-ID des
  Verkaeufers; in UBL auch eine Kennung des Zahlungsempfaengers oder eine
  globale Kennung des Verkaeufers mit Schema SEPA. }
function HasCreditorID(AInvoice: TLandrixInvoice; const ASpec: TLandrixEInvoiceSpec): Boolean;
begin
  Result := Present(AInvoice.AccountingSupplierParty.BankAssignedCreditorIdentifier) or
    ((ASpec.Target.Syntax = esy_UBL) and Present(AInvoice.PayeeParty.Identifier) and
     (AInvoice.PayeeParty.IdentifierSchemeID = 'SEPA')) or
    ((ASpec.Target.Syntax = esy_UBL) and Present(AInvoice.AccountingSupplierParty.GlobalIdentifierSellerBuyer) and
     (AInvoice.AccountingSupplierParty.GlobalIdentifierSellerBuyerSchemeID = 'SEPA'));
end;

{ BR-DE-30 and BR-DE-31 test the direct debit group (BG-19) differently per
  syntax. UBL: a cac:PaymentMandate exists (a payment means 49 or 59
  with mandate or debited account); it needs BT-90 (30) and the debited
  account (31). CII: BG-19 exists when the mandate (BT-89), BT-90 or a debited
  account (BT-91) is written, all on header level; then BT-90 with BT-89
  or BT-91 (30) and BT-91 with BT-89 or BT-90 (31) are required.
  DE: BR-DE-30 und BR-DE-31 pruefen die Lastschriftgruppe (BG-19) je
  Syntax verschieden. UBL: ein cac:PaymentMandate existiert (Zahlungsart
  49 oder 59 mit Mandat oder belastetem Konto); es braucht BT-90 (30) und
  das belastete Konto (31). CII: BG-19 existiert, wenn das Mandat (BT-89),
  BT-90 oder ein belastetes Konto (BT-91) geschrieben wird, alle auf
  Kopfebene; dann sind BT-90 mit BT-89 oder BT-91 (30) und BT-91 mit BT-89
  oder BT-90 (31) Pflicht. }
function DirectDebitViolated(AIndex: TCheckRuleIndex; AInvoice: TLandrixInvoice;
  const ASpec: TLandrixEInvoiceSpec): Boolean;
var
  Mandate, Creditor, Debited: Boolean;
begin
  Mandate := Present(AInvoice.PaymentMandateID);
  Creditor := HasCreditorID(AInvoice, ASpec);
  Debited := HasPayment(AInvoice, pk_DirectDebitWithAccount);
  if ASpec.Target.Syntax = esy_UBL then
  begin
    if not HasPayment(AInvoice, pk_DirectDebit) or not (Mandate or Debited) then
      Result := False
    else if AIndex = cr_BRDE30 then
      Result := not Creditor
    else
      Result := not Debited;
  end
  else if AIndex = cr_BRDE30 then
    Result := ((Mandate or Debited) and not Creditor) or (Creditor and not (Mandate or Debited))
  else
    Result := ((Mandate or Creditor) and not Debited) or (Debited and not (Mandate or Creditor));
end;

{ The written VAT category code: the enumeration, otherwise the other text.
  DE: Der geschriebene Steuerkategoriecode: die Aufzaehlung, sonst der
  andere Text. }
function TaxCategoryText(ACategory: TLandrixInvoiceDutyTaxFeeCategoryCode;
  const AOther: TLandrixEInvoiceString): TLandrixEInvoiceString;
begin
  if ACategory <> idtfcc_None then
    Result := LandrixEInvoiceDutyTaxFeeCategoryCodeToStr(ACategory)
  else
    Result := AOther;
end;

{ BR-DE-16: S, Z, E, AE, K, G, L and M need the seller's VAT registration.
  DE: BR-DE-16: S, Z, E, AE, K, G, L und M brauchen die
  Steuerregistrierung des Verkaeufers. }
function IsRegisteredCategory(const ACode: TLandrixEInvoiceString): Boolean;
begin
  Result := (ACode = 'S') or (ACode = 'Z') or (ACode = 'E') or (ACode = 'AE') or (ACode = 'K') or
    (ACode = 'G') or (ACode = 'L') or (ACode = 'M');
end;

{ CII: the lines only. The allowance branch of the CII Schematron compares
  ram:CategoryTradeTax as a whole with 'VAT' and never holds; such an
  invoice fails BR-S-03 and its kind anyway.
  DE: CII: nur die Positionen. Der Zweig fuer Nachlaesse im CII-Schematron
  vergleicht ram:CategoryTradeTax als Ganzes mit 'VAT' und greift nie; eine
  solche Rechnung scheitert ohnehin an BR-S-03 und Verwandten. }
function UsesRegisteredCategory(AInvoice: TLandrixInvoice; AWithAllowances: Boolean): Boolean;
var
  I: TLandrixEInvoiceListIndex;
begin
  Result := True;
  if AWithAllowances then
  for I := 0 to AInvoice.AllowanceCharges.Count - 1 do
    if IsRegisteredCategory(TaxCategoryText(AInvoice.AllowanceCharges[I].TaxCategory,
      AInvoice.AllowanceCharges[I].TaxCategoryOther)) then
      Exit;
  for I := 0 to AInvoice.InvoiceLines.Count - 1 do
    if IsRegisteredCategory(TaxCategoryText(AInvoice.InvoiceLines[I].TaxCategory,
      AInvoice.InvoiceLines[I].TaxCategoryOther)) then
      Exit;
  Result := False;
end;

function ReasonMissing(AItem: TLandrixInvoiceAllowanceCharge): Boolean;
begin
  if AItem.ChargeIndicator then
    Result := not Present(AItem.Reason) and (AItem.ReasonCodeCharge = issdc_None) and
      not Present(AItem.ReasonCodeChargeOther)
  else
    Result := not Present(AItem.Reason) and (AItem.ReasonCodeAllowance = iacic_None) and
      not Present(AItem.ReasonCodeAllowanceOther);
end;

{ BR-32, BR-33, BR-37, BR-38 on the document level allowances
  (AIsCharge False) or charges.
  DE: BR-32, BR-33, BR-37, BR-38 auf den Nachlaessen (AIsCharge False)
  oder Zuschlaegen der Dokumentebene. }
function AllowanceChargeViolated(AIndex: TCheckRuleIndex; AInvoice: TLandrixInvoice; AIsCharge: Boolean): Boolean;
var
  I: TLandrixEInvoiceListIndex;
  Item: TLandrixInvoiceAllowanceCharge;
begin
  Result := True;
  for I := 0 to AInvoice.AllowanceCharges.Count - 1 do
  begin
    Item := AInvoice.AllowanceCharges[I];
    if Item.ChargeIndicator <> AIsCharge then
      Continue;
    if AIndex in [cr_BR32, cr_BR37] then
    begin
      if not Present(TaxCategoryText(Item.TaxCategory, Item.TaxCategoryOther)) then
        Exit;
    end
    else if ReasonMissing(Item) then
      Exit;
  end;
  Result := False;
end;

{ True for a NaN, by its bits (comparing a NaN differs between compilers).
  DE: True fuer NaN, an den Bits (Vergleiche mit NaN fallen je Compiler
  anders aus). }
function IsNaN(AValue: Double): Boolean;
begin
  Result := ((PInt64(@AValue)^ shr 52) and $7FF = $7FF) and (PInt64(@AValue)^ and $FFFFFFFFFFFFF <> 0);
end;

type
  { Raised where a rule formats a number or a date the writers cannot
    format (ReportUnwritableValues reports the value); the rule then holds.
    Only this exception is caught.
    DE: Ausgeloest, wo eine Regel eine Zahl oder ein Datum formatiert, das
    die Writer nicht formatieren koennen (ReportUnwritableValues meldet den
    Wert); die Regel gilt dann als erfuellt. Nur diese Ausnahme wird
    abgefangen. }
  EUnwritableNumber = class(Exception);

{ True if the writers can format the date AValue: not NaN, 0001-01-01 to
  9999-12-31 (the range of LandrixXml).
  DE: True, wenn die Writer das Datum AValue formatieren koennen: nicht
  NaN, 0001-01-01 bis 9999-12-31 (der Bereich von LandrixXml). }
function DateWritable(AValue: TDateTime): Boolean;
begin
  Result := not IsNaN(AValue) and (AValue > -693594) and (AValue < 2958466);
end;

{ The day of AValue as written (the time is ignored); EUnwritableNumber for
  a date the writers cannot format.
  DE: Der Tag von AValue, wie er geschrieben wird (die Uhrzeit zaehlt
  nicht); EUnwritableNumber fuer ein Datum, das die Writer nicht
  formatieren koennen. }
function WrittenDay(AValue: TDateTime): Int64;
begin
  if not DateWritable(AValue) then
    raise EUnwritableNumber.Create('date cannot be formatted');
  Result := Trunc(AValue);
end;

function PeriodDateSet(AValue: TDateTime): Boolean;
begin
  Result := AValue > 100;
end;

{ BR-29, BR-30: compared as dates (xs:date), the time is ignored.
  DE: BR-29, BR-30: als Datum verglichen (xs:date), die Uhrzeit zaehlt
  nicht. }
function PeriodReversed(AStart, AEnd: TDateTime): Boolean;
begin
  Result := PeriodDateSet(AStart) and PeriodDateSet(AEnd) and (WrittenDay(AEnd) < WrittenDay(AStart));
end;

{ The line rules, for one line.
  DE: Die Positionsregeln fuer eine Position. }
function LineViolated(AIndex: TCheckRuleIndex; ALine: TLandrixInvoiceLine): Boolean;
var
  I: TLandrixEInvoiceListIndex;
  Value, Scheme, Conflict: TLandrixEInvoiceString;
begin
  Result := False;
  case AIndex of
    cr_BR21:
      Result := not Present(ALine.ID);
    cr_BR23:
      Result := (ALine.UnitCode = iuc_None) and not Present(ALine.UnitCodeOther);
    cr_BR25:
      Result := not Present(ALine.Name);
    cr_BR27:
      Result := ALine.NetPriceAmount < 0;
    cr_BR28:
      Result := ALine.GrossPriceAmount < 0;
    cr_BR30:
      Result := PeriodReversed(ALine.InvoiceLinePeriodStartDate, ALine.InvoiceLinePeriodEndDate);
    cr_BR42, cr_BR44:
      for I := 0 to ALine.AllowanceCharges.Count - 1 do
        if (ALine.AllowanceCharges[I].ChargeIndicator = (AIndex = cr_BR44)) and
           ReasonMissing(ALine.AllowanceCharges[I]) then
          Result := True;
    cr_BR54:
      for I := 0 to ALine.ItemAttributes.Count - 1 do
        if not Present(ALine.ItemAttributes[I].Name) or not Present(ALine.ItemAttributes[I].Value) then
          Result := True;
    cr_BR64:
      Result := LandrixEInvoiceStandardItemIdentifierOf(ALine, Value, Scheme, Conflict) and not Present(Scheme);
    cr_BR65:
      for I := 0 to ALine.ItemClassifications.Count - 1 do
        if Present(ALine.ItemClassifications[I].ClassCode) and
           not Present(ALine.ItemClassifications[I].ListID) then
          Result := True;
  else
    { the other rules are no line rules }
    ;
  end;
end;

{ Sub lines with ASubLines: in CII every line rule checks them, there they
  are invoice lines (ram:IncludedSupplyChainTradeLineItem); a UBL
  cac:SubInvoiceLine is in the context of BR-54 only (a group sub line has
  no quantity).
  DE: Unterpositionen mit ASubLines: in CII prueft sie jede
  Positionsregel, dort sind sie Rechnungspositionen
  (ram:IncludedSupplyChainTradeLineItem); eine UBL-cac:SubInvoiceLine liegt
  nur im Kontext von BR-54 (eine Gruppen-Unterposition hat keine Menge). }
function AnyLineViolated(AIndex: TCheckRuleIndex; ALines: TLandrixInvoiceLines; ASubLines: Boolean): Boolean;
var
  I: TLandrixEInvoiceListIndex;
begin
  Result := True;
  for I := 0 to ALines.Count - 1 do
    if LineViolated(AIndex, ALines[I]) or
       (ASubLines and AnyLineViolated(AIndex, ALines[I].SubInvoiceLines, True)) then
      Exit;
  Result := False;
end;

{ UBL-SR-29: count(//cac:PartyIdentification/cbc:ID[upper-case(@schemeID)
  = 'SEPA']) <= 1, as the UBL writer fills them: the global identifiers of
  seller and buyer (BT-29/BT-46, without scheme 0088), the creditor
  identifier BT-90 (with the payee when one is written, otherwise with the
  seller) and the payee identifier BT-60 with its scheme. The scheme is
  compared in ASCII; XPath upper-case also maps U+017F (long s) to S, but
  such a scheme breaks BR-CL-10 anyway.
  DE: UBL-SR-29: hoechstens eine Parteikennung mit Schema SEPA, so wie der
  UBL-Writer sie fuellt: die globalen Kennungen von Verkaeufer und Kaeufer
  (BT-29/BT-46, ohne Schema 0088), die Glaeubiger-ID BT-90 (beim
  Zahlungsempfaenger, wenn einer geschrieben wird, sonst beim Verkaeufer)
  und die Kennung des Zahlungsempfaengers BT-60 mit ihrem Schema. Das
  Schema wird in ASCII verglichen; upper-case in XPath bildet auch U+017F
  (langes s) auf S ab, ein solches Schema verletzt aber ohnehin BR-CL-10. }
function SEPAScheme(const AScheme: TLandrixEInvoiceString): Boolean;
const
  Letters = 'SEPA';
var
  I: Integer;
  C: TLandrixEInvoiceChar;
begin
  Result := Length(AScheme) = 4;
  if Result then
    for I := 1 to 4 do
    begin
      C := AScheme[I];
      if (C >= 'a') and (C <= 'z') then
        C := TLandrixEInvoiceChar(Ord(C) - 32);
      if C <> TLandrixEInvoiceChar(Letters[I]) then
        Result := False;
    end;
end;

function SEPAGlobalIdentifier(AParty: TLandrixInvoiceAccountingParty): Integer;
begin
  if Present(AParty.GlobalIdentifierSellerBuyer) and SEPAScheme(AParty.GlobalIdentifierSellerBuyerSchemeID) then
    Result := 1
  else
    Result := 0;
end;

function SEPAIdentifierCount(AInvoice: TLandrixInvoice): Integer;
begin
  Result := SEPAGlobalIdentifier(AInvoice.AccountingSupplierParty) +
    SEPAGlobalIdentifier(AInvoice.AccountingCustomerParty);
  if Present(AInvoice.AccountingSupplierParty.BankAssignedCreditorIdentifier) then
    Inc(Result);
  if Present(AInvoice.PayeeParty.Identifier) and SEPAScheme(AInvoice.PayeeParty.IdentifierSchemeID) then
    Inc(Result);
end;

{ BR-17: the payee needs a name and must not repeat the seller. UBL
  compares with the trading name (cac:PartyName) and the party
  identifiers as written (without the identifier the target leaves out
  beside a global one, LandrixEInvoiceRuleSellerIDWithGlobalID); the
  creditor identifier BT-90 is one of the payee's there,
  CII with the seller name (BT-27), the identifier ram:ID
  (a payee identifier with scheme is written as ram:GlobalID and not
  compared) and the legal registration.
  DE: BR-17: Der Zahlungsempfaenger braucht einen Namen und darf den
  Verkaeufer nicht wiederholen. UBL vergleicht mit dem Handelsnamen
  (cac:PartyName) und den Parteikennungen, wie sie geschrieben werden (ohne
  die Kennung, die das Ziel neben einer globalen weglaesst,
  LandrixEInvoiceRuleSellerIDWithGlobalID); die Glaeubiger-ID BT-90 gehoert
  dort zu denen des Zahlungsempfaengers, CII mit dem Verkaeufernamen
  (BT-27), der Kennung ram:ID (eine Kennung des Zahlungsempfaengers mit
  Schema wird als ram:GlobalID geschrieben und nicht verglichen) und der
  Registernummer. }
function SellerIdentifier(const AID: TLandrixEInvoiceString; ASeller: TLandrixInvoiceAccountingParty;
  const ASpec: TLandrixEInvoiceSpec): Boolean;
begin
  Result := Present(AID) and ((AID = ASeller.GlobalIdentifierSellerBuyer) or ((AID = ASeller.IdentifierSellerBuyer) and
    not (Present(ASeller.GlobalIdentifierSellerBuyer) and
    (LandrixEInvoiceRuleLevel(ASpec, LandrixEInvoiceRuleSellerIDWithGlobalID) = erl_Forbidden))));
end;

function PayeeViolated(AInvoice: TLandrixInvoice; const ASpec: TLandrixEInvoiceSpec): Boolean;
var
  Payee: TLandrixInvoiceParty;
  Seller: TLandrixInvoiceAccountingParty;
begin
  Payee := AInvoice.PayeeParty;
  Seller := AInvoice.AccountingSupplierParty;
  Result := False;
  if not PartySet(Payee) then
    Exit;
  Result := not Present(Payee.Name);
  if Result then
    Exit;
  if ASpec.Target.Syntax = esy_UBL then
    Result := (Present(Seller.Name) and (Payee.Name = Seller.Name)) or
      SellerIdentifier(Payee.Identifier, Seller, ASpec) or
      SellerIdentifier(Seller.BankAssignedCreditorIdentifier, Seller, ASpec)
  else
    Result := (Payee.Name = Seller.RegistrationName) or
      (Present(Payee.Identifier) and not Present(Payee.IdentifierSchemeID) and
       (Payee.Identifier = Seller.IdentifierSellerBuyer)) or
      (Present(Payee.CompanyID) and (Payee.CompanyID = Seller.CompanyID));
end;

{ BR-52: the tender reference (type 50, BT-17) and the object identifier
  (type 130, BT-18) are attachments in the model but no BG-24.
  DE: BR-52: Vergabe (Art 50, BT-17) und Objektkennung (Art 130, BT-18)
  sind im Modell Anlagen, aber keine BG-24. }
function BG24IDMissing(AInvoice: TLandrixInvoice): Boolean;
var
  I: TLandrixEInvoiceListIndex;
begin
  Result := True;
  for I := 0 to AInvoice.Attachments.Count - 1 do
    if not (AInvoice.Attachments[I].TypeCode in [iatc_50, iatc_130]) and not Present(AInvoice.Attachments[I].ID) then
      Exit;
  Result := False;
end;

{ Whether the mapper writes attachment AIndex as an additional document
  reference: UBL never a tender reference (type 50, it is
  cac:OriginatorDocumentReference) and only the first object identifier
  (type 130) with an identifier; CII the first tender reference with an
  identifier and object identifiers with an identifier (a further one only
  where the target allows it).
  DE: Ob der Mapper Anlage AIndex als weitere Dokumentreferenz schreibt:
  UBL nie eine Vergabe (Art 50) und nur die erste Objektkennung (Art 130)
  mit Kennung; CII die erste Vergabe mit Kennung und Objektkennungen mit
  Kennung (eine weitere nur, wo das Ziel sie erlaubt). }
function AttachmentWritten(AInvoice: TLandrixInvoice; AIndex: TLandrixEInvoiceListIndex;
  const ASpec: TLandrixEInvoiceSpec): Boolean;
var
  I: TLandrixEInvoiceListIndex;
  A: TLandrixInvoiceAttachment;
  IsUBL: Boolean;
begin
  A := AInvoice.Attachments[AIndex];
  IsUBL := ASpec.Target.Syntax = esy_UBL;
  Result := False;
  if A.TypeCode = iatc_50 then
  begin
    if IsUBL or not Present(A.ID) then
      Exit;
    for I := 0 to AIndex - 1 do
      if (AInvoice.Attachments[I].TypeCode = iatc_50) and Present(AInvoice.Attachments[I].ID) then
        Exit;
  end
  else if A.TypeCode = iatc_130 then
  begin
    if not Present(A.ID) then
      Exit;
    if IsUBL or Forbidden(ASpec, LandrixEInvoiceRuleFurtherObjectIdentifier) then
      for I := 0 to AIndex - 1 do
        if (AInvoice.Attachments[I].TypeCode = iatc_130) and Present(AInvoice.Attachments[I].ID) then
          Exit;
  end;
  Result := True;
end;

{ BR-DE-22 compares the written file names; an empty name is not written
  (a blank one is, as an attribute).
  DE: BR-DE-22 vergleicht die geschriebenen Dateinamen; ein leerer Name
  wird nicht geschrieben (ein Name aus Leerzeichen schon, als Attribut). }
function DuplicateFilename(AInvoice: TLandrixInvoice; const ASpec: TLandrixEInvoiceSpec): Boolean;
var
  I, K: TLandrixEInvoiceListIndex;
  A: TLandrixInvoiceAttachment;
begin
  Result := True;
  for I := 0 to AInvoice.Attachments.Count - 1 do
  begin
    A := AInvoice.Attachments[I];
    if not A.ContainsBinaryObject or (A.Filename = '') or not AttachmentWritten(AInvoice, I, ASpec) then
      Continue;
    for K := 0 to I - 1 do
      if AInvoice.Attachments[K].ContainsBinaryObject and (AInvoice.Attachments[K].Filename = A.Filename) and
         AttachmentWritten(AInvoice, K, ASpec) then
        Exit;
  end;
  Result := False;
end;

{ BR-TMP-2: the written external document location must match
  ^([a-zA-Z])([a-zA-Z0-9+.-])+: (UBL: every cac:ExternalReference; CII: only
  a supporting document, type code 916).
  DE: BR-TMP-2: der geschriebene Ort des externen Dokuments muss eine
  absolute URL sein (UBL: jede cac:ExternalReference; CII: nur ein
  rechnungsbegruendendes Dokument, Typcode 916). }
function ExternalLocationWrong(AInvoice: TLandrixInvoice; const ASpec: TLandrixEInvoiceSpec): Boolean;
var
  I: TLandrixEInvoiceListIndex;
  A: TLandrixInvoiceAttachment;
begin
  Result := True;
  for I := 0 to AInvoice.Attachments.Count - 1 do
  begin
    A := AInvoice.Attachments[I];
    if not AttachmentWritten(AInvoice, I, ASpec) then
      Continue;
    { UBL writes cac:ExternalReference only with text; CII writes ram:URIID
      when not empty and tests ram:TypeCode = '916' as written }
    if ASpec.Target.Syntax = esy_UBL then
    begin
      if not Present(A.ExternalReference) then
        Continue;
    end
    else if (A.ExternalReference = '') or
       (WrittenCode(LandrixEInvoiceAttachmentTypeCodeToStr(A.TypeCode), A.TypeCodeOther) <> '916') then
      Continue;
    if not LandrixEInvoiceAbsoluteURL(A.ExternalReference) then
      Exit;
  end;
  Result := False;
end;

function PrecedingIDMissing(AInvoice: TLandrixInvoice): Boolean;
var
  I: TLandrixEInvoiceListIndex;
begin
  Result := True;
  for I := 0 to AInvoice.PrecedingInvoiceReferences.Count - 1 do
    if not Present(AInvoice.PrecedingInvoiceReferences[I].ID) then
      Exit;
  Result := False;
end;

{ BR-DE-26 counts references with identifier; one without violates BR-55.
  DE: BR-DE-26 zaehlt Referenzen mit Kennung; eine ohne verletzt BR-55. }
function HasPrecedingID(AInvoice: TLandrixInvoice): Boolean;
var
  I: TLandrixEInvoiceListIndex;
begin
  Result := True;
  for I := 0 to AInvoice.PrecedingInvoiceReferences.Count - 1 do
    if Present(AInvoice.PrecedingInvoiceReferences[I].ID) then
      Exit;
  Result := False;
end;

function TaxCategoryMissing(AInvoice: TLandrixInvoice): Boolean;
var
  I: TLandrixEInvoiceListIndex;
begin
  Result := True;
  for I := 0 to AInvoice.TaxAmountSubtotals.Count - 1 do
    if not Present(TaxCategoryText(AInvoice.TaxAmountSubtotals[I].TaxCategory,
      AInvoice.TaxAmountSubtotals[I].TaxCategoryOther)) then
      Exit;
  Result := False;
end;

{ --- format rules ---------------------------------------------------------------- }

function IsXmlBlankChar(C: TLandrixEInvoiceChar): Boolean;
begin
  Result := (C = #32) or (C = #9) or (C = #10) or (C = #13);
end;

{ XPath normalize-space: no blank at either end, one blank between words.
  DE: XPath normalize-space: kein Leerraum an den Enden, ein Leerzeichen
  zwischen Woertern. }
function NormalizedSpace(const AValue: TLandrixEInvoiceString): TLandrixEInvoiceString;
begin
  Result := LandrixEInvoiceNormalizeSpace(AValue);
end;

{ BR-DE-19, BR-DE-20 (KoSIT xr:checkIBAN): without blanks, two capital
  letters, two digits and up to 30 letters or digits, and the check sum
  modulo 97 is 1 (letters as their code point - 55, lower case as well).
  ACIIPayee: CII writes BT-84 as IBAN only with 15 to 34 characters
  besides blanks (LooksLikeIBAN of the CII mapper, which skips only
  spaces), otherwise as ram:ProprietaryID.
  DE: BR-DE-19, BR-DE-20 (KoSIT xr:checkIBAN): ohne Leerraum zwei
  Grossbuchstaben, zwei Ziffern und bis zu 30 Buchstaben oder Ziffern, und
  die Pruefsumme modulo 97 ist 1 (Buchstaben als Codepunkt - 55, auch
  Kleinbuchstaben). ACIIPayee: CII schreibt BT-84 nur mit 15 bis 34
  Zeichen ausser Leerzeichen als IBAN (LooksLikeIBAN des CII-Mappers, das
  nur Leerzeichen ueberspringt), sonst als ram:ProprietaryID. }
function IBANValid(const AValue: TLandrixEInvoiceString; ACIIPayee: Boolean): Boolean;
var
  S: TLandrixEInvoiceString;
  I: Integer;
begin
  Result := False;
  S := '';
  for I := 1 to Length(AValue) do
    if not IsXmlBlankChar(AValue[I]) then
      S := S + AValue[I]
    else if ACIIPayee and (AValue[I] <> ' ') then
      Exit;
  if ACIIPayee and (Length(S) < 15) then
    Exit;
  Result := LandrixEInvoiceIBANValid(S);
end;

{ BR-DE-17: the written type code (the enumeration, otherwise the other
  text). DE: BR-DE-17: der geschriebene Typcode (die Aufzaehlung, sonst der
  andere Text). }
function TypeCodeSupported(AInvoice: TLandrixInvoice): Boolean;
var
  Code: TLandrixEInvoiceString;
begin
  if AInvoice.InvoiceTypeCode <> itc_None then
    Code := LandrixEInvoiceTypeCodeToStr(AInvoice.InvoiceTypeCode)
  else
    Code := NormalizedSpace(AInvoice.InvoiceTypeCodeOther);
  Result := (Code = '326') or (Code = '380') or (Code = '384') or (Code = '389') or (Code = '381') or
    (Code = '875') or (Code = '876') or (Code = '877');
end;

{ The length as XPath string-length counts: code points, a surrogate pair
  is one.
  DE: Die Laenge, wie XPath string-length zaehlt: Codepunkte, ein
  Surrogatpaar ist einer. }
function CodePointLength(const S: TLandrixEInvoiceString): Integer;
var
  I: Integer;
begin
  Result := Length(S);
  for I := 1 to Length(S) - 1 do
    if (Ord(S[I]) >= $D800) and (Ord(S[I]) <= $DBFF) and (Ord(S[I + 1]) >= $DC00) and (Ord(S[I + 1]) <= $DFFF) then
      Dec(Result);
end;

{ The syntax rules on several payment instructions as the mappers write
  them (one per payment type with a code): CII-SR-467 and CII-SR-468 (the
  codes and the texts normalized), UBL-SR-47 (the codes as written),
  UBL-SR-54 (card accounts) and UBL-SR-55 (mandates with content). The UBL
  writer writes BT-82 once, so UBL-SR-46 always holds.
  DE: Die Syntaxregeln zu mehreren Zahlungsanweisungen, wie die Mapper sie
  schreiben (eine je Zahlungsart mit Code). UBL-SR-46 haelt immer: der
  UBL-Writer schreibt BT-82 einmal. }
function PaymentMeansMixed(AIndex: TCheckRuleIndex; AInvoice: TLandrixInvoice): Boolean;
var
  I: TLandrixEInvoiceListIndex;
  P: TLandrixInvoicePaymentType;
  First, Value: TLandrixEInvoiceString;
  HasFirst: Boolean;
  Count: Integer;
begin
  HasFirst := False;
  First := '';
  Count := 0;
  for I := 0 to AInvoice.PaymentTypes.Count - 1 do
  begin
    P := AInvoice.PaymentTypes[I];
    if not PaymentWritten(P) then
      Continue;
    case AIndex of
      cr_CIISR467:
        Value := PaymentCodeOf(P);
      cr_UBLSR47:
        Value := WrittenCode(LandrixEInvoicePaymentMeansCodeToStr(P.PaymentMeansCode), P.PaymentMeansCodeOther);
      cr_CIISR468:
        begin
          { the CII writer leaves a blank text out }
          if not Present(P.PaymentMeansInformation) then
            Continue;
          Value := NormalizedSpace(P.PaymentMeansInformation);
        end;
      cr_UBLSR54:
        begin
          { cac:CardAccount (always with its network 'NA') only with a card
            number }
          if IsCard(P) and Present(P.FinancialAccount) then
            Inc(Count);
          Continue;
        end;
    else
      begin
        { cac:PaymentMandate only with the mandate or the debited account }
        if IsDirectDebitCode(P) and ((AInvoice.PaymentMandateID <> '') or (P.FinancialAccount <> '')) then
          Inc(Count);
        Continue;
      end;
    end;
    if not HasFirst then
    begin
      First := Value;
      HasFirst := True;
    end
    else if Value <> First then
    begin
      Result := True;
      Exit;
    end;
  end;
  Result := Count > 1;
end;

{ BR-DE-19 (credit transfer 58, the payee account BT-84), BR-DE-20 (direct
  debit 59, the debited account BT-91), BR-51 (card payment, BT-87 longer
  than 10 characters), per payment means as written.
  DE: BR-DE-19 (Ueberweisung 58, das Konto BT-84), BR-DE-20 (Lastschrift
  59, das belastete Konto BT-91), BR-51 (Kartenzahlung, BT-87 laenger als
  10 Zeichen), je Zahlungsart, wie sie geschrieben wird. }
function PaymentFormatViolated(AIndex: TCheckRuleIndex; AInvoice: TLandrixInvoice;
  const ASpec: TLandrixEInvoiceSpec): Boolean;
var
  I: TLandrixEInvoiceListIndex;
  P: TLandrixInvoicePaymentType;
begin
  Result := True;
  for I := 0 to AInvoice.PaymentTypes.Count - 1 do
  begin
    P := AInvoice.PaymentTypes[I];
    case AIndex of
      cr_BRDE19:
        if (PaymentCodeOf(P) = '58') and not IBANValid(P.FinancialAccount, ASpec.Target.Syntax = esy_CII) then
          Exit;
      cr_BRDE20:
        if (PaymentCodeOf(P) = '59') and not IBANValid(P.FinancialAccount, False) then
          Exit;
    else
      if IsCard(P) and (CodePointLength(NormalizedSpace(P.FinancialAccount)) > 10) then
        Exit;
    end;
  end;
  Result := False;
end;

{ True if the writers can format AValue: not NaN, not infinite, below
  1e23 (the limit of LandrixXml, for every number of decimals).
  DE: True, wenn die Writer AValue formatieren koennen: nicht NaN, nicht
  unendlich, unter 1e23 (die Grenze von LandrixXml, fuer jede Zahl von
  Nachkommastellen). }
function NumberWritable(AValue: Double): Boolean;
begin
  try
    Result := LandrixEInvoicePercentToLexical(AValue) <> '';
  except
    on ELandrixXmlError do
      Result := False;
  end;
end;

{ AValue if the writers can format it, else EUnwritableNumber.
  DE: AValue, wenn die Writer es formatieren koennen, sonst
  EUnwritableNumber. }
function Writable(AValue: Double): Double;
begin
  if not NumberWritable(AValue) then
    raise EUnwritableNumber.Create('number cannot be formatted');
  Result := AValue;
end;

{ The payment terms text as written (LandrixEInvoicePaymentTermsText);
  EUnwritableNumber when a cash discount percentage of the levels of
  PaymentTermsType cannot be formatted.
  DE: Der Text der Zahlungsbedingungen, wie er geschrieben wird;
  EUnwritableNumber, wenn ein Skontoprozentsatz der Stufen von
  PaymentTermsType nicht formatiert werden kann. }
function TermsText(AInvoice: TLandrixInvoice): TLandrixEInvoiceString;
begin
  if AInvoice.PaymentTermsType in [iptt_CashDiscount1, iptt_CashDiscount2, iptt_CashDiscount3] then
    Writable(AInvoice.PaymentTermCashDiscount1Percent);
  if AInvoice.PaymentTermsType in [iptt_CashDiscount2, iptt_CashDiscount3] then
    Writable(AInvoice.PaymentTermCashDiscount2Percent);
  if AInvoice.PaymentTermsType = iptt_CashDiscount3 then
    Writable(AInvoice.PaymentTermCashDiscount3Percent);
  Result := LandrixEInvoicePaymentTermsText(AInvoice);
end;

{ The rate as written (2 to 4 decimals), exact; EUnwritableNumber for a
  rate the writers cannot format.
  DE: Der Satz, wie er geschrieben wird (2 bis 4 Nachkommastellen), genau;
  EUnwritableNumber fuer einen Satz, den die Writer nicht formatieren
  koennen. }
function RateExact(AValue: Double): TExact;
begin
  Result := ExactOf(LandrixEInvoicePercentToLexical(Writable(AValue)));
end;

{ True if the magnitude of the tax amount ATaxCents lies within AWidth
  (exclusive, in cents) of |ATaxableCents| x ARate / 100 rounded half up to
  cents (XPath round; the rate keeps its sign): with X the unrounded amount
  and T the magnitude of the tax amount, round(X) lies within T - W .. T + W
  (W = AWidth - 1, integers) exactly when T - W - 0.5 <= X < T + W + 0.5.
  Exact for any size.
  DE: True, wenn der Steuerbetrag ATaxCents als Betrag innerhalb von AWidth
  (echt, in Cent) um |ATaxableCents| x ARate / 100 liegt, halb aufwaerts
  auf Cent gerundet (XPath round; der Satz behaelt sein Vorzeichen): mit X
  dem ungerundeten Betrag und T dem Betrag des Steuerbetrags liegt round(X)
  genau dann in T - W .. T + W (W = AWidth - 1, ganze Zahlen), wenn
  T - W - 0,5 <= X < T + W + 0,5. Genau fuer jede Groesse. }
function TaxWithin(ATaxableCents: Int64; const ARate: TExact; ATaxCents: Int64; AWidth: Integer): Boolean;
var
  X, T, Half: TExact;
begin
  X := ExactMul(ExactInt(Abs(ATaxableCents)), ARate);
  { the rate is a percentage: / 100 }
  Inc(X.Scale, 2);
  T := ExactInt(Abs(ATaxCents));
  Half := ExactAdd(ExactInt(AWidth - 1), ExactOf('0.5'));
  Result := (ExactCompare(X, ExactSub(T, Half)) >= 0) and (ExactCompare(X, ExactAdd(T, Half)) < 0);
end;

function AmountExact(AValue: Currency): TExact;
begin
  Result := ExactOf(LandrixEInvoiceAmountToLexical(AValue));
end;

function PriceExact(AValue: Double): TExact;
begin
  Result := ExactOf(LandrixEInvoicePriceToLexical(Writable(AValue)));
end;

{ --- details of a violation ------------------------------------------------------ }

type
  { What a rule reports beside the violation: Path, Expected, Found and
    Calculation of TLandrixEInvoiceDiagnostic; '' when the rule gives
    none. The rule sets them where it decides.
    DE: Was eine Regel neben dem Verstoss meldet: Path, Expected, Found und
    Calculation von TLandrixEInvoiceDiagnostic; '', wenn die Regel nichts
    angibt. Die Regel setzt sie dort, wo sie entscheidet. }
  TRuleDetail = record
    Path: TLandrixEInvoiceString;
    Expected: TLandrixEInvoiceString;
    Found: TLandrixEInvoiceString;
    Calculation: TLandrixEInvoiceString;
  end;

procedure ClearDetail(out ADetail: TRuleDetail);
begin
  ADetail.Path := '';
  ADetail.Expected := '';
  ADetail.Found := '';
  ADetail.Calculation := '';
end;

procedure SetDetail(var ADetail: TRuleDetail; const APath, AExpected, AFound,
  ACalculation: TLandrixEInvoiceString);
begin
  ADetail.Path := APath;
  ADetail.Expected := AExpected;
  ADetail.Found := AFound;
  ADetail.Calculation := ACalculation;
end;

{ An amount in cents as text with two decimals ('-12.30'). }
function CentsText(ACents: Int64): TLandrixEInvoiceString;
var
  E: TExact;
begin
  E := ExactInt(ACents);
  Inc(E.Scale, 2);
  Result := ExactText(E, 2);
end;

{ --- calculation rules ---------------------------------------------------------- }

{ An amount as written, in cents (LandrixEInvoiceAmountToLexical); from
  the raw Int64 of the Currency (ten thousandths), so the whole Currency
  range fits.
  DE: Ein Betrag, wie er geschrieben wird, in Cent; aus dem rohen Int64
  der Currency (Zehntausendstel), damit der ganze Currency-Bereich passt. }
function Cents(AValue: Currency): Int64;
var
  Amount: Currency;
begin
  Amount := CentAmount(AValue);
  Result := PInt64(@Amount)^ div 100;
end;

{ Third-party payments that the target writes: XRechnung UBL invoices
  (BG-DEX-09) and Factur-X EXTENDED (financial adjustments); the amount due
  includes them there (BR-DEX-09, BR-FXEXT-CO-16).
  DE: Zahlungen Dritter, die das Ziel schreibt: XRechnung-UBL-Rechnungen
  (BG-DEX-09) und Factur-X EXTENDED (Finanzkorrekturen); der Zahlbetrag
  enthaelt sie dort (BR-DEX-09, BR-FXEXT-CO-16). }
function ThirdPartyWritten(AInvoice: TLandrixInvoice; const ASpec: TLandrixEInvoiceSpec): Boolean;
begin
  Result := (AInvoice.PrepaidPayments.Count > 0) and ASpec.CanWrite and
    not Forbidden(ASpec, LandrixEInvoiceRuleThirdPartyPayments) and
    not ((ASpec.Target.Syntax = esy_UBL) and (AInvoice.InvoiceTypeCode = itc_CreditNote));
end;

{ BR-DEX-14: a third-party payment written in another currency than the
  invoice (an empty currency is written as the invoice currency).
  DE: BR-DEX-14: eine Zahlung Dritter in einer anderen Waehrung als die
  Rechnung (eine leere Waehrung wird als Rechnungswaehrung geschrieben). }
function ThirdPartyCurrencyWrong(AInvoice: TLandrixInvoice; const ASpec: TLandrixEInvoiceSpec): Boolean;
var
  I: TLandrixEInvoiceListIndex;
  Code: TLandrixEInvoiceString;
begin
  Result := False;
  if not ThirdPartyWritten(AInvoice, ASpec) then
    Exit;
  for I := 0 to AInvoice.PrepaidPayments.Count - 1 do
  begin
    Code := AInvoice.PrepaidPayments[I].PaidAmountCurrencyID;
    if Present(Code) and (Code <> AInvoice.InvoiceCurrencyCode) then
    begin
      Result := True;
      Exit;
    end;
  end;
end;

function ThirdPartyCents(AInvoice: TLandrixInvoice): Int64;
var
  I: TLandrixEInvoiceListIndex;
begin
  Result := 0;
  for I := 0 to AInvoice.PrepaidPayments.Count - 1 do
    Inc(Result, Cents(AInvoice.PrepaidPayments[I].PaidAmount));
end;

{ Sum and number of the document level allowances (ACharge False) or
  charges. DE: Summe und Anzahl der Nachlaesse (ACharge False) oder
  Zuschlaege der Dokumentebene. }
function AllowanceChargeCents(AInvoice: TLandrixInvoice; ACharge: Boolean; out ACount: Integer): Int64;
var
  I: TLandrixEInvoiceListIndex;
begin
  Result := 0;
  ACount := 0;
  for I := 0 to AInvoice.AllowanceCharges.Count - 1 do
    if AInvoice.AllowanceCharges[I].ChargeIndicator = ACharge then
    begin
      Inc(Result, Cents(AInvoice.AllowanceCharges[I].Amount));
      Inc(ACount);
    end;
end;

{ Sum of the line net amounts and number of lines. EN 16931: the top
  level (CII writes sub lines in EXTENDED only, a UBL cac:SubInvoiceLine is
  no invoice line). EXTENDED (ADetailOnly): every level, the sum over
  lines without status or with status DETAIL (as written), the count of
  those lines (AAllCount: of all lines).
  DE: Summe der Positionsnettobetraege und Anzahl der Positionen. EN 16931:
  die oberste Ebene (CII schreibt Unterpositionen nur in EXTENDED, eine
  UBL-cac:SubInvoiceLine ist keine Rechnungsposition). EXTENDED
  (ADetailOnly): alle Ebenen, die Summe ueber Positionen ohne Status oder
  mit Status DETAIL (wie geschrieben), deren Anzahl (AAllCount: aller
  Positionen). }
procedure LineCents(ALines: TLandrixInvoiceLines; AIsSubLine, ADetailOnly: Boolean; var ASum: Int64;
  var ACount, AAllCount: Integer);
var
  I: TLandrixEInvoiceListIndex;
begin
  for I := 0 to ALines.Count - 1 do
  begin
    Inc(AAllCount);
    if not ADetailOnly or
       (LandrixEInvoiceLineStatusOf(ALines[I], AIsSubLine) in [ilsrc_None, ilsrc_Detail]) then
    begin
      Inc(ASum, Cents(ALines[I].LineAmount));
      Inc(ACount);
    end;
    if ADetailOnly then
      LineCents(ALines[I].SubInvoiceLines, True, True, ASum, ACount, AAllCount);
  end;
end;

{ BR-CO-17 for one VAT breakdown: with a rate that rounds to 0 the tax
  amount rounds to 0; otherwise it lies within 1 of the taxable amount x
  rate / 100 rounded to cents (XPath round: half up), strictly in UBL,
  inclusively in CII. The rate as written (2 to 4 decimals), exact for
  any size.
  DE: BR-CO-17 fuer eine Steueraufschluesselung: bei einem Satz, der auf 0
  rundet, rundet der Steuerbetrag auf 0; sonst liegt er innerhalb von 1
  um Bemessungsgrundlage x Satz / 100, auf Cent gerundet (XPath round:
  halb aufwaerts), in UBL echt, in CII einschliesslich. Der Satz, wie er
  geschrieben wird (2 bis 4 Nachkommastellen), genau fuer jede Groesse. }
function TaxAmountWrong(ATax: TLandrixInvoiceTaxAmount; AStrict: Boolean; const APath: TLandrixEInvoiceString;
  var ADetail: TRuleDetail): Boolean;
var
  Tax, Taxable: Int64;
  Rate, X: TExact;
  Allowed: TLandrixEInvoiceString;
begin
  Tax := Cents(ATax.TaxAmount);
  Rate := RateExact(ATax.TaxPercent);
  { round(rate) = 0 for -0.5 <= rate < 0.5 (half up) }
  if (ExactCompare(Rate, ExactOf('-0.5')) >= 0) and (ExactCompare(Rate, ExactOf('0.5')) < 0) then
  begin
    Result := (Tax < -50) or (Tax >= 50);
    if Result then
      SetDetail(ADetail, APath, '0.00', CentsText(Tax), 'the VAT category rate (BT-119) ' + ExactText(Rate, 2) +
        ' rounds to 0, so the VAT category tax amount (BT-117) has to round to 0');
    Exit;
  end;
  Taxable := Cents(ATax.TaxableAmount);
  if AStrict then
    Result := not TaxWithin(Taxable, Rate, Tax, 100)
  else
    Result := not TaxWithin(Taxable, Rate, Tax, 101);
  if not Result then
    Exit;
  { the expected amount as TaxWithin compares it: |taxable| x rate / 100
    rounded half up to cents (XPath round), against the magnitude of the
    tax amount
    DE: der erwartete Betrag, wie TaxWithin ihn vergleicht:
    |Bemessungsgrundlage| x Satz / 100, halb aufwaerts auf Cent gerundet
    (XPath round), gegen den Betrag des Steuerbetrags ohne Vorzeichen }
  X := ExactMul(ExactInt(Abs(Taxable)), Rate);
  Inc(X.Scale, 2);
  X := ExactFloor(ExactAdd(X, ExactOf('0.5')));
  Inc(X.Scale, 2);
  if AStrict then
    Allowed := 'less than 1.00'
  else
    Allowed := 'up to 1.00';
  SetDetail(ADetail, APath, ExactText(X, 2), CentsText(Abs(Tax)), 'magnitude of the VAT category taxable amount ' +
    '(BT-116) ' + CentsText(Abs(Taxable)) + ' x VAT category rate (BT-119) ' + ExactText(Rate, 2) +
    ' / 100, rounded to cents, against the magnitude of the VAT category tax amount (BT-117); the difference ' +
    'may be ' + Allowed);
end;

{ The calculation rules on the totals as written.
  DE: Die Rechenregeln auf den geschriebenen Summen. }
function CalculationViolated(AIndex: TCheckRuleIndex; AInvoice: TLandrixInvoice;
  const ASpec: TLandrixEInvoiceSpec; var ADetail: TRuleDetail): Boolean;
var
  Lines, Allowances, Charges, Expected: Int64;
  LineCount, AllLines, AllowanceCount, ChargeCount, I: Integer;
  Tolerance: Int64;
  Calculation: TLandrixEInvoiceString;
  Scratch: TRuleDetail;
  Extension: Boolean;

  function Count(AValue: Integer; const AOne, AMany: TLandrixEInvoiceString): TLandrixEInvoiceString;
  begin
    if AValue = 1 then
      Result := '1 ' + AOne
    else
      Result := TLandrixEInvoiceString(IntToStr(AValue)) + ' ' + AMany;
  end;

  function Within(ACents: Int64): TLandrixEInvoiceString;
  begin
    Result := '; the difference may be up to ' + CentsText(ACents);
  end;

  { sets the detail of a violated total rule
    DE: setzt die Einzelheiten einer verletzten Summenregel }
  procedure Total(AViolated: Boolean; const APath: TLandrixEInvoiceString; AExpected, AFound: Int64;
    const ACalculation: TLandrixEInvoiceString);
  begin
    if AViolated then
      SetDetail(ADetail, APath, CentsText(AExpected), CentsText(AFound), ACalculation);
  end;

  { an amount in cents, exact (sums of several amounts cannot overflow)
    DE: ein Betrag in Cent, genau (Summen mehrerer Betraege laufen nicht
    ueber) }
  function CentsExact(ACents: Int64): TExact;
  begin
    Result := ExactInt(ACents);
    Inc(Result.Scale, 2);
  end;

  procedure TotalExact(AViolated: Boolean; const APath: TLandrixEInvoiceString; const AExpected: TExact;
    AFound: Int64; const ACalculation: TLandrixEInvoiceString);
  begin
    if AViolated then
      SetDetail(ADetail, APath, ExactText(AExpected, 2), CentsText(AFound), ACalculation);
  end;

begin
  Lines := 0;
  LineCount := 0;
  AllLines := 0;
  LineCents(AInvoice.InvoiceLines, False, AIndex in [cr_BRFXEXTCO10, cr_BRFXEXTCO13, cr_BRFXEXTCO15], Lines,
    LineCount, AllLines);
  Allowances := AllowanceChargeCents(AInvoice, False, AllowanceCount);
  Charges := AllowanceChargeCents(AInvoice, True, ChargeCount);
  Tolerance := Int64(LineCount) + AllowanceCount + ChargeCount;
  Result := False;
  case AIndex of
    cr_BRCO10:
      begin
        Result := Cents(AInvoice.LineAmount) <> Lines;
        Total(Result, 'LineAmount', Lines, Cents(AInvoice.LineAmount), 'sum of the invoice line net amounts (BT-131) of ' +
          Count(LineCount, 'line', 'lines'));
      end;
    cr_BRCO11:
      begin
        Result := Cents(AInvoice.AllowanceTotalAmount) <> Allowances;
        Total(Result, 'AllowanceTotalAmount', Allowances, Cents(AInvoice.AllowanceTotalAmount),
          'sum of the document level allowance amounts (BT-92) of ' +
          Count(AllowanceCount, 'allowance', 'allowances'));
      end;
    cr_BRCO12:
      begin
        Result := Cents(AInvoice.ChargeTotalAmount) <> Charges;
        Total(Result, 'ChargeTotalAmount', Charges, Cents(AInvoice.ChargeTotalAmount),
          'sum of the document level charge amounts (BT-99) of ' + Count(ChargeCount, 'charge', 'charges'));
      end;
    cr_BRCO13:
      begin
        Expected := Cents(AInvoice.LineAmount) - Cents(AInvoice.AllowanceTotalAmount) +
          Cents(AInvoice.ChargeTotalAmount);
        Result := Cents(AInvoice.TaxExclusiveAmount) <> Expected;
        Total(Result, 'TaxExclusiveAmount', Expected, Cents(AInvoice.TaxExclusiveAmount),
          'sum of invoice line net amounts (BT-106) ' + CentsText(Cents(AInvoice.LineAmount)) +
          ' - sum of allowances (BT-107) ' + CentsText(Cents(AInvoice.AllowanceTotalAmount)) +
          ' + sum of charges (BT-108) ' + CentsText(Cents(AInvoice.ChargeTotalAmount)));
      end;
    cr_BRCO14:
      { UBL: no breakdown, no rule; CII: the empty sum is 0 }
      if (ASpec.Target.Syntax = esy_CII) or (AInvoice.TaxAmountSubtotals.Count > 0) then
      begin
        Expected := 0;
        for I := 0 to Integer(AInvoice.TaxAmountSubtotals.Count) - 1 do
          Inc(Expected, Cents(AInvoice.TaxAmountSubtotals[I].TaxAmount));
        Result := Cents(AInvoice.TaxAmountTotal) <> Expected;
        Total(Result, 'TaxAmountTotal', Expected, Cents(AInvoice.TaxAmountTotal),
          'sum of the VAT category tax amounts (BT-117) of ' +
          Count(Integer(AInvoice.TaxAmountSubtotals.Count), 'VAT breakdown', 'VAT breakdowns'));
      end;
    cr_BRCO15:
      { CII also accepts BT-112 = BT-109 }
      begin
        Expected := Cents(AInvoice.TaxExclusiveAmount) + Cents(AInvoice.TaxAmountTotal);
        Result := (Cents(AInvoice.TaxInclusiveAmount) <> Expected) and
          ((ASpec.Target.Syntax <> esy_CII) or
           (Cents(AInvoice.TaxInclusiveAmount) <> Cents(AInvoice.TaxExclusiveAmount)));
        Calculation := 'invoice total without VAT (BT-109) ' + CentsText(Cents(AInvoice.TaxExclusiveAmount)) +
          ' + invoice total VAT amount (BT-110) ' + CentsText(Cents(AInvoice.TaxAmountTotal));
        if ASpec.Target.Syntax = esy_CII then
          Calculation := Calculation + '; CII also accepts the total without VAT';
        Total(Result, 'TaxInclusiveAmount', Expected, Cents(AInvoice.TaxInclusiveAmount), Calculation);
      end;
    cr_BRCO16, cr_BRFXEXTCO16, cr_BRDEX09:
      begin
        Expected := Cents(AInvoice.TaxInclusiveAmount) - Cents(AInvoice.PrepaidAmount) +
          Cents(AInvoice.PayableRoundingAmount);
        Calculation := 'invoice total with VAT (BT-112) ' + CentsText(Cents(AInvoice.TaxInclusiveAmount)) +
          ' - paid amount (BT-113) ' + CentsText(Cents(AInvoice.PrepaidAmount)) + ' + rounding amount (BT-114) ' +
          CentsText(Cents(AInvoice.PayableRoundingAmount));
        { XRechnung UBL: BR-DEX-09 replaces BR-CO-16 (KoSIT: information)
          whenever the extension is written, with or without third-party
          payments; elsewhere BR-FXEXT-CO-16 takes the third-party charges }
        if (ASpec.Target.Standard = est_XRechnung) and (ASpec.Target.Syntax = esy_UBL) then
          Extension := ExtensionWritten(AInvoice, ASpec)
        else
          Extension := ThirdPartyWritten(AInvoice, ASpec);
        if Extension then
        begin
          if AIndex = cr_BRCO16 then
            Exit;
          if ThirdPartyWritten(AInvoice, ASpec) then
          begin
            Inc(Expected, ThirdPartyCents(AInvoice));
            Calculation := Calculation + ' + third-party payments ' + CentsText(ThirdPartyCents(AInvoice));
          end;
        end
        else if AIndex = cr_BRDEX09 then
          Exit;
        Result := Cents(AInvoice.PayableAmount) <> Expected;
        Total(Result, 'PayableAmount', Expected, Cents(AInvoice.PayableAmount), Calculation);
      end;
    cr_BRCO17:
      { every breakdown is judged (a later rate that cannot be written
        skips the rule), the details are those of the first wrong one
        DE: jede Aufschluesselung wird beurteilt (ein spaeterer Satz, der
        sich nicht schreiben laesst, laesst die Regel entfallen), die
        Einzelheiten sind die der ersten falschen }
      for I := 0 to Integer(AInvoice.TaxAmountSubtotals.Count) - 1 do
      begin
        ClearDetail(Scratch);
        if TaxAmountWrong(AInvoice.TaxAmountSubtotals[I], ASpec.Target.Syntax = esy_UBL,
           'TaxAmountSubtotals[' + TLandrixEInvoiceString(IntToStr(I)) + '].TaxAmount', Scratch) and not Result then
        begin
          Result := True;
          ADetail := Scratch;
        end;
      end;
    cr_BRFXEXTCO10:
      begin
        Result := Abs(Cents(AInvoice.LineAmount) - Lines) > AllLines;
        Total(Result, 'LineAmount', Lines, Cents(AInvoice.LineAmount), 'sum of the line net amounts (BT-131) of ' +
          Count(LineCount, 'line', 'lines') + ' without status or with status DETAIL' + Within(AllLines));
      end;
    cr_BRFXEXTCO11:
      begin
        Result := Abs(Cents(AInvoice.AllowanceTotalAmount) - Allowances) > AllowanceCount;
        Total(Result, 'AllowanceTotalAmount', Allowances, Cents(AInvoice.AllowanceTotalAmount),
          'sum of the document level allowance amounts (BT-92) of ' +
          Count(AllowanceCount, 'allowance', 'allowances') + Within(AllowanceCount));
      end;
    cr_BRFXEXTCO12:
      begin
        Result := Abs(Cents(AInvoice.ChargeTotalAmount) - Charges) > ChargeCount;
        Total(Result, 'ChargeTotalAmount', Charges, Cents(AInvoice.ChargeTotalAmount),
          'sum of the document level charge amounts (BT-99) of ' + Count(ChargeCount, 'charge', 'charges') +
          Within(ChargeCount));
      end;
    cr_BRFXEXTCO13:
      begin
        Result := Abs(Cents(AInvoice.TaxExclusiveAmount) - Lines + Allowances - Charges) > Tolerance;
        TotalExact(Result, 'TaxExclusiveAmount', ExactAdd(ExactSub(CentsExact(Lines), CentsExact(Allowances)),
          CentsExact(Charges)), Cents(AInvoice.TaxExclusiveAmount),
          'sum of the line net amounts (BT-131) ' + CentsText(Lines) + ' - sum of the allowances (BT-92) ' +
          CentsText(Allowances) + ' + sum of the charges (BT-99) ' + CentsText(Charges) + Within(Tolerance));
      end;
    cr_BRFXEXTCO15:
      begin
        Result := Abs(Cents(AInvoice.TaxInclusiveAmount) - Cents(AInvoice.TaxAmountTotal) -
          Cents(AInvoice.TaxExclusiveAmount)) > Tolerance;
        TotalExact(Result, 'TaxInclusiveAmount', ExactAdd(CentsExact(Cents(AInvoice.TaxExclusiveAmount)),
          CentsExact(Cents(AInvoice.TaxAmountTotal))), Cents(AInvoice.TaxInclusiveAmount),
          'invoice total without VAT (BT-109) ' + CentsText(Cents(AInvoice.TaxExclusiveAmount)) +
          ' + invoice total VAT amount (BT-110) ' + CentsText(Cents(AInvoice.TaxAmountTotal)) + Within(Tolerance));
      end;
  else
    { the other rules are no calculation rules }
    ;
  end;
end;

{ --- VAT category rules ---------------------------------------------------------- }

type
  { The VAT categories with a rule group of their own: BR-S-nn (standard
    rated) to BR-AG-nn (IPSI). DE: Die Umsatzsteuerkategorien mit eigener
    Regelgruppe: BR-S-nn (Normalsatz) bis BR-AG-nn (IPSI). }
  TVatGroup = (vg_S, vg_Z, vg_E, vg_AE, vg_IC, vg_G, vg_O, vg_AF, vg_AG);

  TTaxUseKind = (tuk_Line, tuk_SubLine, tuk_Allowance, tuk_Charge, tuk_Breakdown);
  TTaxUseKinds = set of TTaxUseKind;

  { One VAT category as written: of an invoice line, a document level
    allowance or charge, or a VAT breakdown; amounts in cents, the rate
    exact as written (2 to 4 decimals, any size).
    DE: Eine Umsatzsteuerkategorie, wie sie geschrieben wird: einer
    Rechnungsposition, eines Nachlasses oder Zuschlags der Dokumentebene
    oder einer Steueraufschluesselung; Betraege in Cent, der Satz genau so,
    wie er geschrieben wird (2 bis 4 Nachkommastellen, beliebig gross). }
  TTaxUse = record
    Kind: TTaxUseKind;
    Code: TLandrixEInvoiceString;
    { the code as written, not normalized (BR-AF-01, BR-AG-01) }
    Raw: TLandrixEInvoiceString;
    HasRate: Boolean;
    Rate: TExact;
    Amount: Int64;
    TaxAmount: Int64;
    Exemption: Boolean;
  end;

  TTaxUses = record
    Items: array of TTaxUse;
    Count: Integer;
  end;

const
  { The group in the rule identifier, its category code (UNCL5305) and its
    last rule number. DE: Die Gruppe in der Regelkennung, ihr
    Kategoriecode (UNCL5305) und ihre letzte Regelnummer. }
  VatGroupIDs: array[TVatGroup] of string = ('S', 'Z', 'E', 'AE', 'IC', 'G', 'O', 'AF', 'AG');
  VatGroupCodes: array[TVatGroup] of string = ('S', 'Z', 'E', 'AE', 'K', 'G', 'O', 'L', 'M');
  VatGroupLast: array[TVatGroup] of Integer = (10, 10, 10, 10, 12, 10, 14, 10, 10);
  VatGroupNames: array[TVatGroup] of string = ('standard rated', 'zero rated', 'exempt from VAT',
    'reverse charge', 'intra-community supply', 'export outside the EU', 'not subject to VAT',
    'IGIC (Canary Islands)', 'IPSI (Ceuta and Melilla)');

procedure AddTaxUse(var AUses: TTaxUses; AKind: TTaxUseKind; const ACode: TLandrixEInvoiceString;
  AHasRate: Boolean; ARate: Double; AAmount: Int64);
begin
  if AUses.Count = Length(AUses.Items) then
    SetLength(AUses.Items, 2 * AUses.Count + 8);
  AUses.Items[AUses.Count].Kind := AKind;
  AUses.Items[AUses.Count].Code := ACode;
  AUses.Items[AUses.Count].Raw := ACode;
  AUses.Items[AUses.Count].HasRate := AHasRate;
  if AHasRate then
    AUses.Items[AUses.Count].Rate := RateExact(ARate)
  else
    AUses.Items[AUses.Count].Rate := ExactOf('0');
  AUses.Items[AUses.Count].Amount := AAmount;
  AUses.Items[AUses.Count].TaxAmount := 0;
  AUses.Items[AUses.Count].Exemption := False;
  Inc(AUses.Count);
end;

{ The lines as the mappers write their VAT category: the rate is left out
  for category O; sub lines only where the target has them. A line without
  category counts for no group.
  DE: Die Positionen, wie die Mapper ihre Steuerkategorie schreiben: der
  Satz faellt bei Kategorie O weg; Unterpositionen nur, wo das Ziel sie
  hat. Eine Position ohne Kategorie zaehlt fuer keine Gruppe. }
{ The category code a rule compares: UBL normalizes it
  (normalize-space(cbc:ID)), CII takes it as written.
  DE: Der Kategoriecode, den eine Regel vergleicht: UBL normalisiert ihn,
  CII nimmt ihn wie geschrieben. }
function UseCode(ACategory: TLandrixInvoiceDutyTaxFeeCategoryCode; const AOther: TLandrixEInvoiceString;
  ANormalize: Boolean): TLandrixEInvoiceString;
begin
  Result := TaxCategoryText(ACategory, AOther);
  if ANormalize then
    Result := NormalizedSpace(Result);
end;

procedure AddLineTaxUses(var AUses: TTaxUses; ALines: TLandrixInvoiceLines; AKind: TTaxUseKind;
  ASubLines, ANormalize: Boolean);
var
  I: TLandrixEInvoiceListIndex;
  Line: TLandrixInvoiceLine;
begin
  for I := 0 to ALines.Count - 1 do
  begin
    Line := ALines[I];
    AddTaxUse(AUses, AKind, UseCode(Line.TaxCategory, Line.TaxCategoryOther, ANormalize),
      Line.TaxCategory <> idtfcc_O_ServicesOutsideScopeOfTax, Line.TaxPercent, Cents(Line.LineAmount));
    if ASubLines then
      AddLineTaxUses(AUses, Line.SubInvoiceLines, tuk_SubLine, True, ANormalize);
  end;
end;

procedure CollectTaxUses(AInvoice: TLandrixInvoice; const ASpec: TLandrixEInvoiceSpec; out AUses: TTaxUses);
var
  I: TLandrixEInvoiceListIndex;
  Item: TLandrixInvoiceAllowanceCharge;
  Subtotal: TLandrixInvoiceTaxAmount;
  Kind: TTaxUseKind;
  Normalize: Boolean;
begin
  AUses.Items := nil;
  AUses.Count := 0;
  Normalize := ASpec.Target.Syntax = esy_UBL;
  AddLineTaxUses(AUses, AInvoice.InvoiceLines, tuk_Line, LandrixEInvoiceSubLinesNested(AInvoice, ASpec), Normalize);
  for I := 0 to AInvoice.AllowanceCharges.Count - 1 do
  begin
    Item := AInvoice.AllowanceCharges[I];
    Kind := tuk_Allowance;
    if Item.ChargeIndicator then
      Kind := tuk_Charge;
    AddTaxUse(AUses, Kind, UseCode(Item.TaxCategory, Item.TaxCategoryOther, Normalize),
      Item.TaxCategory <> idtfcc_O_ServicesOutsideScopeOfTax, Item.TaxPercent, Cents(Item.Amount));
  end;
  for I := 0 to AInvoice.TaxAmountSubtotals.Count - 1 do
  begin
    Subtotal := AInvoice.TaxAmountSubtotals[I];
    AddTaxUse(AUses, tuk_Breakdown, UseCode(Subtotal.TaxCategory, Subtotal.TaxCategoryOther, Normalize), True,
      Subtotal.TaxPercent, Cents(Subtotal.TaxableAmount));
    AUses.Items[AUses.Count - 1].Raw := TaxCategoryText(Subtotal.TaxCategory, Subtotal.TaxCategoryOther);
    AUses.Items[AUses.Count - 1].TaxAmount := Cents(Subtotal.TaxAmount);
    AUses.Items[AUses.Count - 1].Exemption := Present(Subtotal.TaxExemptionReason) or
      Present(Subtotal.TaxExemptionReasonCode);
  end;
end;

function AnyTaxUse(const AUses: TTaxUses; AKind: TTaxUseKind): Boolean;
var
  I: Integer;
begin
  Result := True;
  for I := 0 to AUses.Count - 1 do
    if AUses.Items[I].Kind = AKind then
      Exit;
  Result := False;
end;

function CountTaxUses(const AUses: TTaxUses; const ACode: TLandrixEInvoiceString; AKinds: TTaxUseKinds): Integer;
var
  I: Integer;
begin
  Result := 0;
  for I := 0 to AUses.Count - 1 do
    if (AUses.Items[I].Kind in AKinds) and (AUses.Items[I].Code = ACode) then
      Inc(Result);
end;

{ A use of another category than ACode; a use without category is none.
  DE: Eine Verwendung einer anderen Kategorie als ACode; eine ohne
  Kategorie zaehlt nicht. }
function HasOtherTaxUse(const AUses: TTaxUses; const ACode: TLandrixEInvoiceString; AKinds: TTaxUseKinds): Boolean;
var
  I: Integer;
begin
  Result := True;
  for I := 0 to AUses.Count - 1 do
    if (AUses.Items[I].Kind in AKinds) and Present(AUses.Items[I].Code) and (AUses.Items[I].Code <> ACode) then
      Exit;
  Result := False;
end;

{ BR-xx-08: the lines (UBL: top level only) and document level allowances
  and charges of ACode (and with ARate, if AByRate), net in cents; AFound
  tells whether one exists. DE: BR-xx-08: Positionen (UBL: nur oberste
  Ebene) und Nachlaesse und Zuschlaege der Dokumentebene mit ACode (und
  ARate, wenn AByRate), netto in Cent; AFound sagt, ob es eine gibt. }
function TaxUseNet(const AUses: TTaxUses; const ACode: TLandrixEInvoiceString; AByRate: Boolean;
  const ARate: TExact; ALineKinds: TTaxUseKinds; out AFound: Boolean): Int64;
var
  I: Integer;
  U: TTaxUse;
begin
  Result := 0;
  AFound := False;
  for I := 0 to AUses.Count - 1 do
  begin
    U := AUses.Items[I];
    if (U.Code <> ACode) or (AByRate and (not U.HasRate or (ExactCompare(U.Rate, ARate) <> 0))) then
      Continue;
    if U.Kind in ALineKinds then
      Inc(Result, U.Amount)
    else if U.Kind = tuk_Charge then
      Inc(Result, U.Amount)
    else if U.Kind = tuk_Allowance then
      Dec(Result, U.Amount)
    else
      Continue;
    AFound := True;
  end;
end;

{ BR-S-09 (and BR-AF-09, BR-AG-09 in UBL): the tax amount lies strictly
  within 1 of taxable amount x rate / 100, rounded half up to cents
  (exactly, for any size).
  DE: BR-S-09 (und BR-AF-09, BR-AG-09 in UBL): der Steuerbetrag liegt echt
  innerhalb von 1 um Bemessungsgrundlage x Satz / 100, halb aufwaerts auf
  Cent gerundet (genau, fuer jede Groesse). }
function BreakdownTaxWrong(const AUse: TTaxUse): Boolean;
begin
  Result := not TaxWithin(AUse.Amount, AUse.Rate, AUse.TaxAmount, 100);
end;

{ BR-xx-02 to 04: the seller and buyer identifiers each group needs (S, Z,
  E, AE, AF, AG: also the seller tax registration BT-32; O: none of the
  VAT identifiers).
  DE: BR-xx-02 bis 04: die Kennungen von Verkaeufer und Kaeufer, die jede
  Gruppe braucht (S, Z, E, AE, AF, AG: auch die Steuernummer BT-32; O:
  keine der Umsatzsteuer-IdNr.). }
function PartiesWrong(AGroup: TVatGroup; AInvoice: TLandrixInvoice): Boolean;
var
  SellerVAT, SellerTax, BuyerVAT: Boolean;
begin
  SellerVAT := Present(AInvoice.AccountingSupplierParty.VATCompanyID) or
    Present(AInvoice.TaxRepresentativeParty.VATCompanyID);
  SellerTax := SellerVAT or Present(AInvoice.AccountingSupplierParty.VATCompanyNumber);
  BuyerVAT := Present(AInvoice.AccountingCustomerParty.VATCompanyID);
  case AGroup of
    vg_AE:
      Result := not SellerTax or not (BuyerVAT or Present(AInvoice.AccountingCustomerParty.CompanyID));
    vg_IC:
      Result := not SellerVAT or not BuyerVAT;
    vg_G:
      Result := not SellerVAT;
    vg_O:
      Result := SellerVAT or BuyerVAT;
  else
    Result := not SellerTax;
  end;
end;

{ BR-xx-05 to 07: the rate of a line, allowance or charge (S: above 0, O:
  none, AF: at least 0 in UBL and above 0 in CII, AG: at least 0, the
  others: 0). DE: BR-xx-05 bis 07: der Satz einer Position, eines
  Nachlasses oder Zuschlags (S: ueber 0, O: keiner, AF: mindestens 0 in
  UBL und ueber 0 in CII, AG: mindestens 0, die uebrigen: 0). }
function RateWrong(AGroup: TVatGroup; const AUse: TTaxUse; const ASpec: TLandrixEInvoiceSpec): Boolean;
begin
  if AGroup = vg_O then
    Result := AUse.HasRate
  else if not AUse.HasRate then
    Result := True
  else
    case AGroup of
      vg_S:
        Result := ExactSign(AUse.Rate) <= 0;
      vg_AF:
        Result := (ExactSign(AUse.Rate) < 0) or ((ExactSign(AUse.Rate) = 0) and (ASpec.Target.Syntax = esy_CII));
      vg_AG:
        Result := ExactSign(AUse.Rate) < 0;
    else
      Result := ExactSign(AUse.Rate) <> 0;
    end;
end;

{ BR-xx-01: with lines, allowances or charges of the category a VAT
  breakdown of it, as each schematron counts: UBL: S, AF, AG at least one
  (and none without use), the others exactly one; CII: S, AF, AG count
  lines and allowances/charges each together with the breakdowns (at least
  two), the others exactly one with a use, none without, and O only tests
  an existing breakdown.
  DE: BR-xx-01: bei Positionen, Nachlaessen oder Zuschlaegen der Kategorie
  eine Steueraufschluesselung dafuer, wie jedes Schematron zaehlt: UBL: S,
  AF, AG mindestens eine (und keine ohne Verwendung), die uebrigen genau
  eine; CII: S, AF, AG zaehlen Positionen und Nachlaesse/Zuschlaege jeweils
  zusammen mit den Aufschluesselungen (mindestens zwei), die uebrigen genau
  eine mit Verwendung, keine ohne, und O prueft nur eine vorhandene
  Aufschluesselung. }
function RawBreakdownCount(const AUses: TTaxUses; const ACode: TLandrixEInvoiceString): Integer;
var
  I: Integer;
begin
  Result := 0;
  for I := 0 to AUses.Count - 1 do
    if (AUses.Items[I].Kind = tuk_Breakdown) and (AUses.Items[I].Raw = ACode) then
      Inc(Result);
end;

function BreakdownCountWrong(AGroup: TVatGroup; const AUses: TTaxUses; const ASpec: TLandrixEInvoiceSpec): Boolean;
var
  Code: TLandrixEInvoiceString;
  Lines, Others, Breakdowns: Integer;
begin
  Code := TLandrixEInvoiceString(VatGroupCodes[AGroup]);
  Lines := CountTaxUses(AUses, Code, [tuk_Line, tuk_SubLine]);
  Others := CountTaxUses(AUses, Code, [tuk_Allowance, tuk_Charge]);
  Breakdowns := CountTaxUses(AUses, Code, [tuk_Breakdown]);
  if ASpec.Target.Syntax = esy_UBL then
  begin
    { BR-AF-01 and BR-AG-01 count the breakdowns of a used category with
      cbc:ID = 'L' as written, those of an unused one normalized }
    if (AGroup in [vg_AF, vg_AG]) and (Lines + Others > 0) then
      Result := RawBreakdownCount(AUses, Code) = 0
    else if AGroup in [vg_S, vg_AF, vg_AG] then
      Result := (Lines + Others > 0) <> (Breakdowns > 0)
    else
      Result := (Lines + Others + Breakdowns > 0) and (Breakdowns <> 1);
  end
  else if AGroup in [vg_S, vg_AF, vg_AG] then
    Result := ((Lines > 0) and (Lines + Breakdowns < 2)) or ((Others > 0) and (Others + Breakdowns < 2))
  else if AGroup = vg_O then
    Result := (Breakdowns > 0) and not ((Breakdowns = 1) and (Lines + Others > 0))
  else
    Result := not (((Breakdowns = 0) and (Lines + Others = 0)) or ((Breakdowns = 1) and (Lines + Others > 0)));
end;

{ BR-xx-08 to 10 on each VAT breakdown of the category. BR-xx-08 compares
  the taxable amount with the lines, allowances and charges: by rate for S,
  AF and AG (UBL: within 1 and, for S, with one of that rate; CII:
  exactly), for the others over the category (UBL: exactly; CII: strictly
  within 1, Factur-X up to 1 below inclusively, O exactly); UBL needs an
  invoice line except for S. BR-xx-09: S, AF, AG (CII: S only) strictly
  within 1 of the rounded amount, the others 0. BR-xx-10: S, Z, AF, AG without, the others with exemption
  reason.
  DE: BR-xx-08 bis 10 auf jeder Steueraufschluesselung der Kategorie.
  BR-xx-08 vergleicht die Bemessungsgrundlage mit Positionen, Nachlaessen
  und Zuschlaegen: je Satz fuer S, AF und AG (UBL: innerhalb von 1 und, fuer
  S, mit einer Verwendung dieses Satzes; CII: genau), fuer die uebrigen
  ueber die Kategorie (UBL: genau; CII: echt innerhalb von 1, Factur-X bis
  1 nach unten einschliesslich, O genau); UBL verlangt ausser fuer S eine
  Rechnungsposition. BR-xx-09: S, AF, AG (CII: nur S) echt innerhalb von 1
  um den gerundeten Betrag, die uebrigen 0. BR-xx-10: S, Z, AF, AG ohne, die uebrigen mit
  Befreiungsgrund. }
function BreakdownWrong(AGroup: TVatGroup; ANumber: Integer; const AUse: TTaxUse; const AUses: TTaxUses;
  const ASpec: TLandrixEInvoiceSpec): Boolean;
var
  ByRate, IsUBL: Boolean;
  Found: Boolean;
  Net: Int64;
  LineKinds: TTaxUseKinds;
begin
  ByRate := AGroup in [vg_S, vg_AF, vg_AG];
  IsUBL := ASpec.Target.Syntax = esy_UBL;
  Result := False;
  case ANumber of
    8:
      begin
        LineKinds := [tuk_Line, tuk_SubLine];
        if IsUBL then
          LineKinds := [tuk_Line];
        Net := TaxUseNet(AUses, AUse.Code, ByRate, AUse.Rate, LineKinds, Found);
        { CII: BR-AF-08 and BR-AG-08 read ../ram:RateApplicablePercent from
          ram:ApplicableTradeTax, an empty sequence, so they always hold }
        if not IsUBL and (AGroup in [vg_AF, vg_AG]) then
          Result := False
        else if not IsUBL and (AGroup = vg_O) then
          Result := AUse.Amount <> Net
        else if not IsUBL and not ByRate and (ASpec.Target.Standard = est_FacturX) then
          Result := (AUse.Amount - Net > 100) or (Net - AUse.Amount >= 100)
        else if ByRate = IsUBL then
          Result := Abs(AUse.Amount - Net) >= 100
        else
          Result := AUse.Amount <> Net;
        if IsUBL and (AGroup = vg_S) and not Found then
          Result := True;
        { UBL: the groups other than S also need an invoice line }
        if IsUBL and (AGroup <> vg_S) and not AnyTaxUse(AUses, tuk_Line) then
          Result := True;
      end;
    9:
      if AGroup = vg_S then
        Result := BreakdownTaxWrong(AUse)
      else if AGroup in [vg_AF, vg_AG] then
        Result := IsUBL and BreakdownTaxWrong(AUse)
      else
        Result := AUse.TaxAmount <> 0;
    10:
      Result := AUse.Exemption = (AGroup in [vg_S, vg_Z, vg_AF, vg_AG]);
  end;
end;

{ BR-IC-11: an intra-community supply needs the actual delivery date
  (BT-72) or the invoicing period (BG-14; UBL: also with only the VAT point
  date code BT-8 in it). DE: BR-IC-11: eine innergemeinschaftliche
  Lieferung braucht das tatsaechliche Lieferdatum (BT-72) oder den
  Rechnungszeitraum (BG-14; UBL: auch nur mit dem Code BT-8 darin). }
function DeliveryDateMissing(AInvoice: TLandrixInvoice; const ASpec: TLandrixEInvoiceSpec): Boolean;
begin
  Result := not (AInvoice.DeliveryInformation.ActualDeliveryDate > 0) and
    not ((PeriodDateSet(AInvoice.InvoicePeriodStartDate) or PeriodDateSet(AInvoice.InvoicePeriodEndDate)) and
      not PeriodReversed(AInvoice.InvoicePeriodStartDate, AInvoice.InvoicePeriodEndDate)) and
    not ((ASpec.Target.Syntax = esy_UBL) and Present(AInvoice.TaxPointDateCode) and
      not AInvoice.TaxPointDate.HasValue);
end;

{ True if VAT rule AGroup/ANumber is violated. The rules judge the
  categories as written; context and tolerances follow the schematron of
  each syntax (CEN EN 16931 1.3).
  DE: True, wenn die Steuerregel AGroup/ANumber verletzt ist. Die Regeln
  beurteilen die Kategorien, wie sie geschrieben werden; Kontext und
  Toleranzen folgen dem Schematron der jeweiligen Syntax (CEN EN 16931
  1.3). }
function VatViolated(AGroup: TVatGroup; ANumber: Integer; AInvoice: TLandrixInvoice;
  const ASpec: TLandrixEInvoiceSpec; const ATaxUses: TTaxUses): Boolean;
var
  Code: TLandrixEInvoiceString;
  I: Integer;
  Kinds: TTaxUseKinds;
  IsCII, HasBreakdown: Boolean;
begin
  Result := False;
  Code := TLandrixEInvoiceString(VatGroupCodes[AGroup]);
  IsCII := ASpec.Target.Syntax = esy_CII;
  HasBreakdown := CountTaxUses(ATaxUses, Code, [tuk_Breakdown]) > 0;
  case ANumber of
    0:
      { BR-FXEXT-xx-01: its line context does not see the status (a sibling),
        so every written line counts. DE: BR-FXEXT-xx-01: sein
        Positionskontext sieht den Status nicht (ein Geschwister), also zaehlt
        jede geschriebene Position. }
      Result := (CountTaxUses(ATaxUses, Code, [tuk_Line, tuk_SubLine, tuk_Allowance, tuk_Charge]) > 0) <>
        HasBreakdown;
    1:
      Result := BreakdownCountWrong(AGroup, ATaxUses, ASpec);
    2, 3, 4:
      begin
        case ANumber of
          2: Kinds := [tuk_Line, tuk_SubLine];
          3: Kinds := [tuk_Allowance];
        else
          Kinds := [tuk_Charge];
        end;
        Result := (CountTaxUses(ATaxUses, Code, Kinds) > 0) and PartiesWrong(AGroup, AInvoice);
      end;
    5, 6, 7:
      begin
        case ANumber of
          5:
            if IsCII then
              Kinds := [tuk_Line, tuk_SubLine]
            else
              Kinds := [tuk_Line];
          6: Kinds := [tuk_Allowance];
        else
          Kinds := [tuk_Charge];
        end;
        for I := 0 to ATaxUses.Count - 1 do
          if (ATaxUses.Items[I].Kind in Kinds) and (ATaxUses.Items[I].Code = Code) and
             RateWrong(AGroup, ATaxUses.Items[I], ASpec) then
            Result := True;
      end;
    8, 9, 10:
      for I := 0 to ATaxUses.Count - 1 do
        if (ATaxUses.Items[I].Kind = tuk_Breakdown) and (ATaxUses.Items[I].Code = Code) and
           BreakdownWrong(AGroup, ANumber, ATaxUses.Items[I], ATaxUses, ASpec) then
          Result := True;
    11:
      if AGroup = vg_IC then
        Result := HasBreakdown and DeliveryDateMissing(AInvoice, ASpec)
      else
        { CII tests breakdowns and lines together for BR-O-11 and 12 }
        Result := HasBreakdown and (HasOtherTaxUse(ATaxUses, Code, [tuk_Breakdown]) or
          (IsCII and HasOtherTaxUse(ATaxUses, Code, [tuk_Line, tuk_SubLine])));
    12:
      if AGroup = vg_IC then
        Result := HasBreakdown and not Present(AInvoice.DeliveryInformation.Address.CountryCode)
      else
        Result := HasBreakdown and (HasOtherTaxUse(ATaxUses, Code, [tuk_Line, tuk_SubLine]) or
          (IsCII and HasOtherTaxUse(ATaxUses, Code, [tuk_Breakdown])));
    13, 14:
      begin
        { CII tests allowances and charges together for BR-O-13 and 14 }
        if IsCII then
          Kinds := [tuk_Allowance, tuk_Charge]
        else if ANumber = 13 then
          Kinds := [tuk_Allowance]
        else
          Kinds := [tuk_Charge];
        Result := HasBreakdown and HasOtherTaxUse(ATaxUses, Code, Kinds);
      end;
  end;
end;

{ The Factur-X 1.09 profiles of each VAT rule: BASIC WL has the document
  level rules 03, 04, 06, 07, 09 and 10 and BR-IC-11, BR-IC-12, BR-O-11,
  BR-O-13 and BR-O-14, BASIC and EN 16931 have all, EXTENDED has 02 to 07
  (O: 05 to 07), 09 (not S), 10 (not S, Z, AF, AG), BR-IC-11 and BR-IC-12
  and its own BR-FXEXT-xx-01 (number 0).
  DE: Die Factur-X-1.09-Profile jeder Steuerregel: BASIC WL hat die Regeln
  der Dokumentebene 03, 04, 06, 07, 09 und 10 sowie BR-IC-11, BR-IC-12,
  BR-O-11, BR-O-13 und BR-O-14, BASIC und EN 16931 haben alle, EXTENDED hat
  02 bis 07 (O: 05 bis 07), 09 (nicht S), 10 (nicht S, Z, AF, AG), BR-IC-11
  und BR-IC-12 sowie seine eigenen BR-FXEXT-xx-01 (Nummer 0). }
function VatProfiles(AGroup: TVatGroup; ANumber: Integer): TProfiles;
begin
  case ANumber of
    0:
      Result := [epr_Extended];
    1, 8:
      Result := FromBasicNoExtended;
    2, 5:
      Result := FromBasic;
    3, 4, 6, 7, 9, 10:
      Result := FromBasicWL;
    11, 12:
      if AGroup = vg_IC then
        Result := FromBasicWL
      else if ANumber = 12 then
        Result := FromBasicNoExtended
      else
        Result := FromBasicWLNoExtended;
  else
    Result := FromBasicWLNoExtended;
  end;
  if ((AGroup = vg_O) and (ANumber in [2, 3, 4])) or ((AGroup = vg_S) and (ANumber = 9)) or
     ((AGroup in [vg_S, vg_Z, vg_AF, vg_AG]) and (ANumber = 10)) then
    Result := Result - [epr_Extended];
end;

function VatRuleID(AGroup: TVatGroup; ANumber: Integer): string;
begin
  if ANumber = 0 then
    Result := 'BR-FXEXT-' + VatGroupIDs[AGroup] + '-01'
  else
    Result := 'BR-' + VatGroupIDs[AGroup] + '-' + Chr(Ord('0') + ANumber div 10) + Chr(Ord('0') + ANumber mod 10);
end;

{ Business terms and message of VAT rule AGroup/ANumber, the rule texts in
  short. DE: Geschaeftsbegriffe und Meldung der Steuerregel
  AGroup/ANumber, die Regeltexte in Kurzform. }
procedure VatRuleText(AGroup: TVatGroup; ANumber: Integer; out ATerms, AMessage: string);
var
  Name, Item, Rate: string;
begin
  Name := 'VAT category ' + VatGroupCodes[AGroup] + ' (' + VatGroupNames[AGroup] + ')';
  case ANumber of
    2, 5:
      begin
        Item := 'an invoice line (BG-25)';
        Rate := 'BT-152';
      end;
    3, 6, 13:
      begin
        Item := 'a document level allowance (BG-20)';
        Rate := 'BT-96';
      end;
  else
    Item := 'a document level charge (BG-21)';
    Rate := 'BT-103';
  end;
  case ANumber of
    0:
      begin
        ATerms := 'BT-118';
        AMessage := 'lines (all levels), allowances or charges with ' + Name + ' need at least one VAT ' +
          'breakdown (BG-23) of that category, and such a breakdown needs one of them';
      end;
    1:
      begin
        ATerms := 'BT-118';
        if AGroup in [vg_S, vg_AF, vg_AG] then
          AMessage := 'lines, allowances or charges with ' + Name + ' need at least one VAT breakdown (BG-23) of ' +
            'that category, and such a breakdown needs one of them'
        else
          AMessage := 'lines, allowances or charges with ' + Name + ' need exactly one VAT breakdown (BG-23) of ' +
            'that category';
      end;
    2, 3, 4:
      case AGroup of
        vg_O:
          begin
            ATerms := 'BT-31, BT-63, BT-48';
            AMessage := Item + ' with ' + Name + ' excludes the seller VAT identifier (BT-31), the tax ' +
              'representative VAT identifier (BT-63) and the buyer VAT identifier (BT-48)';
          end;
        vg_G:
          begin
            ATerms := 'BT-31, BT-63';
            AMessage := Item + ' with ' + Name + ' needs the seller VAT identifier (BT-31) or the tax ' +
              'representative VAT identifier (BT-63)';
          end;
        vg_IC:
          begin
            ATerms := 'BT-31, BT-63, BT-48';
            AMessage := Item + ' with ' + Name + ' needs the seller VAT identifier (BT-31) or the tax ' +
              'representative VAT identifier (BT-63), and the buyer VAT identifier (BT-48)';
          end;
        vg_AE:
          begin
            ATerms := 'BT-31, BT-32, BT-63, BT-48, BT-47';
            AMessage := Item + ' with ' + Name + ' needs the seller VAT identifier (BT-31), tax registration ' +
              'identifier (BT-32) or tax representative VAT identifier (BT-63), and the buyer VAT identifier ' +
              '(BT-48) or legal registration identifier (BT-47)';
          end;
      else
        ATerms := 'BT-31, BT-32, BT-63';
        AMessage := Item + ' with ' + Name + ' needs the seller VAT identifier (BT-31), tax registration ' +
          'identifier (BT-32) or tax representative VAT identifier (BT-63)';
      end;
    5, 6, 7:
      begin
        ATerms := Rate;
        case AGroup of
          vg_S:
            AMessage := 'a VAT rate (' + Rate + ') above 0';
          vg_O:
            AMessage := 'no VAT rate (' + Rate + ')';
          vg_AF:
            AMessage := 'a VAT rate (' + Rate + ') of 0 or more (CII: above 0)';
          vg_AG:
            AMessage := 'a VAT rate (' + Rate + ') of 0 or more';
        else
          AMessage := 'the VAT rate (' + Rate + ') 0';
        end;
        AMessage := Item + ' with ' + Name + ' shall have ' + AMessage;
      end;
    8:
      begin
        ATerms := 'BT-116, BT-131, BT-92, BT-99';
        AMessage := 'the taxable amount (BT-116) of a VAT breakdown with ' + Name + ' shall be the sum of the ' +
          'line net amounts (BT-131) plus charges (BT-99) minus allowances (BT-92) of that category';
        if AGroup in [vg_S, vg_AF, vg_AG] then
          AMessage := AMessage + ' and rate';
      end;
    9:
      begin
        ATerms := 'BT-117';
        if AGroup in [vg_S, vg_AF, vg_AG] then
          AMessage := 'the VAT amount (BT-117) of a VAT breakdown with ' + Name + ' shall be the taxable amount ' +
            '(BT-116) x rate (BT-119) / 100 (tolerance 1)'
        else
          AMessage := 'the VAT amount (BT-117) of a VAT breakdown with ' + Name + ' shall be 0';
      end;
    10:
      begin
        ATerms := 'BT-120, BT-121';
        if AGroup in [vg_S, vg_Z, vg_AF, vg_AG] then
          AMessage := 'a VAT breakdown with ' + Name + ' shall have no exemption reason (BT-120) or reason code ' +
            '(BT-121)'
        else
          AMessage := 'a VAT breakdown with ' + Name + ' shall have an exemption reason (BT-120) or reason code ' +
            '(BT-121)';
      end;
    11:
      if AGroup = vg_IC then
      begin
        ATerms := 'BT-72, BG-14';
        AMessage := 'an invoice with a VAT breakdown of ' + Name + ' needs the actual delivery date (BT-72) or ' +
          'the invoicing period (BG-14)';
      end
      else
      begin
        ATerms := 'BT-118';
        AMessage := 'an invoice with a VAT breakdown of ' + Name + ' shall have no VAT breakdown of another ' +
          'category';
      end;
    12:
      if AGroup = vg_IC then
      begin
        ATerms := 'BT-80';
        AMessage := 'an invoice with a VAT breakdown of ' + Name + ' needs the deliver to country code (BT-80)';
      end
      else
      begin
        ATerms := 'BT-151';
        AMessage := 'an invoice with a VAT breakdown of ' + Name + ' shall have no invoice line of another ' +
          'VAT category';
      end;
  else
    if ANumber = 13 then
      ATerms := 'BT-95'
    else
      ATerms := 'BT-102';
    AMessage := 'an invoice with a VAT breakdown of ' + Name + ' shall have no ' + Copy(Item, 3, MaxInt) +
      ' of another VAT category';
  end;
end;

{ BR-B-01, BR-B-02: VAT category B (split payment, Italy) in a line,
  allowance, charge or breakdown; BR-B-01 needs every written country code
  to be IT (UBL also the item country of origin BT-159), BR-B-02 excludes
  category S.
  DE: BR-B-01, BR-B-02: Umsatzsteuerkategorie B (Split Payment, Italien)
  in einer Position, einem Nachlass, Zuschlag oder einer Aufschluesselung;
  BR-B-01 verlangt IT als jeden geschriebenen Laendercode (UBL auch das
  Ursprungsland BT-159), BR-B-02 schliesst Kategorie S aus. }
function ForeignCountry(const ACode: TLandrixEInvoiceString): Boolean;
begin
  Result := Present(ACode) and (ACode <> 'IT');
end;

function ForeignOrigin(ALines: TLandrixInvoiceLines; ASubLines: Boolean): Boolean;
var
  I: TLandrixEInvoiceListIndex;
begin
  Result := True;
  for I := 0 to ALines.Count - 1 do
    if ForeignCountry(ALines[I].OriginTradeCountry) or
       (ASubLines and ForeignOrigin(ALines[I].SubInvoiceLines, True)) then
      Exit;
  Result := False;
end;

{ CII also writes the invoicee (BT-X-..., where the target allows it) and,
  in Factur-X EXTENDED, the address and VAT identifier of the payee; the
  CII schematron tests every ram:CountryID and VA registration.
  DE: CII schreibt auch den Rechnungsempfaenger (wo das Ziel ihn erlaubt)
  und, in Factur-X EXTENDED, Anschrift und USt-IdNr. des
  Zahlungsempfaengers; das CII-Schematron prueft jede ram:CountryID und
  VA-Registrierung. }
function CIIInvoiceeWritten(AInvoice: TLandrixInvoice; const ASpec: TLandrixEInvoiceSpec): Boolean;
begin
  Result := (ASpec.Target.Syntax = esy_CII) and PartySet(AInvoice.InvoiceeParty) and
    not Forbidden(ASpec, LandrixEInvoiceRuleInvoicee);
end;

function CIIPayeeFull(AInvoice: TLandrixInvoice; const ASpec: TLandrixEInvoiceSpec): Boolean;
begin
  Result := (ASpec.Target.Syntax = esy_CII) and PartySet(AInvoice.PayeeParty) and
    not Forbidden(ASpec, LandrixEInvoiceRulePayeeExtended);
end;

function SplitPaymentViolated(AIndex: TCheckRuleIndex; AInvoice: TLandrixInvoice;
  const ASpec: TLandrixEInvoiceSpec): Boolean;
var
  TaxUses: TTaxUses;
  AllKinds: TTaxUseKinds;
begin
  CollectTaxUses(AInvoice, ASpec, TaxUses);
  AllKinds := [Low(TTaxUseKind)..High(TTaxUseKind)];
  Result := CountTaxUses(TaxUses, 'B', AllKinds) > 0;
  if not Result then
    Exit;
  if AIndex = cr_BRB02 then
    Result := CountTaxUses(TaxUses, 'S', AllKinds) > 0
  else
    Result := ForeignCountry(AInvoice.AccountingSupplierParty.Address.CountryCode) or
      ForeignCountry(AInvoice.AccountingCustomerParty.Address.CountryCode) or
      ForeignCountry(AInvoice.TaxRepresentativeParty.Address.CountryCode) or
      ForeignCountry(AInvoice.DeliveryInformation.Address.CountryCode) or
      (CIIInvoiceeWritten(AInvoice, ASpec) and ForeignCountry(AInvoice.InvoiceeParty.Address.CountryCode)) or
      (CIIPayeeFull(AInvoice, ASpec) and ForeignCountry(AInvoice.PayeeParty.Address.CountryCode)) or
      ((ASpec.Target.Syntax = esy_UBL) and ForeignOrigin(AInvoice.InvoiceLines,
        LandrixEInvoiceSubLinesNested(AInvoice, ASpec)));
end;

{ BR-FXEXT-CO-04: every line without status or with status DETAIL, on
  every level; a status code other than DETAIL that the model holds as text
  is written and excludes the line.
  DE: BR-FXEXT-CO-04: jede Position ohne Status oder mit Status DETAIL, auf
  jeder Ebene; ein anderer Statuscode, den das Modell als Text haelt, wird
  geschrieben und schliesst die Position aus. }
function OtherLineStatus(ALine: TLandrixInvoiceLine; AIsSubLine: Boolean): Boolean;
begin
  Result := (LandrixEInvoiceLineStatusOf(ALine, AIsSubLine) = ilsrc_None) and
    Present(ALine.LineStatusReasonCodeOther) and (ALine.LineStatusReasonCodeOther <> 'DETAIL');
end;

function DetailTaxCategoryMissing(ALines: TLandrixInvoiceLines; AIsSubLine: Boolean): Boolean;
var
  I: TLandrixEInvoiceListIndex;
  Line: TLandrixInvoiceLine;
begin
  Result := True;
  for I := 0 to ALines.Count - 1 do
  begin
    Line := ALines[I];
    if ((LandrixEInvoiceLineStatusOf(Line, AIsSubLine) in [ilsrc_None, ilsrc_Detail]) and
        not OtherLineStatus(Line, AIsSubLine) and
        not Present(TaxCategoryText(Line.TaxCategory, Line.TaxCategoryOther))) or
       DetailTaxCategoryMissing(Line.SubInvoiceLines, True) then
      Exit;
  end;
  Result := False;
end;

{ BR-CO-25 (Factur-X EXTENDED, the only target with the rule, where the
  mapper writes structured payment terms): a due date, the net note or a
  cash discount (which has a due date when the issue date is set).
  DE: BR-CO-25 (Factur-X EXTENDED, das einzige Ziel mit der Regel, wo der
  Mapper strukturierte Zahlungsbedingungen schreibt): ein
  Faelligkeitsdatum, der Nettohinweis oder ein Skonto (das eine
  Faelligkeit hat, wenn das Rechnungsdatum gesetzt ist). }
function PaymentTermsMissing(AInvoice: TLandrixInvoice): Boolean;
begin
  if Cents(AInvoice.PayableAmount) <= 0 then
    Result := False
  else
    Result := not (AInvoice.InvoiceDueDate > 0) and not Present(AInvoice.PaymentTermNetNote) and
      not ((AInvoice.PaymentTermsType in [iptt_CashDiscount1, iptt_CashDiscount2, iptt_CashDiscount3]) and
        (AInvoice.InvoiceIssueDate > 0));
end;

{ BR-CO-26: a seller identifier as written (not in Factur-X MINIMUM, which
  has no ram:ID or ram:GlobalID; UBL: not with scheme SEPA, the creditor
  identifier, and the identifier without scheme is left out next to a
  global identifier where the target forbids both), the legal registration
  or the VAT identifier.
  DE: BR-CO-26: eine Verkaeuferkennung, wie sie geschrieben wird (nicht in
  Factur-X MINIMUM, das weder ram:ID noch ram:GlobalID hat; UBL: nicht mit
  Schema SEPA, der Glaeubiger-ID, und die Kennung ohne Schema faellt neben
  einer globalen Kennung weg, wo das Ziel beide verbietet), die
  Registernummer oder die USt-IdNr. }
function SellerIdentifierMissing(ASeller: TLandrixInvoiceAccountingParty; const ASpec: TLandrixEInvoiceSpec): Boolean;
var
  Identifier, Global: Boolean;
begin
  Global := Present(ASeller.GlobalIdentifierSellerBuyer);
  Identifier := Present(ASeller.IdentifierSellerBuyer) and
    not (Global and Forbidden(ASpec, LandrixEInvoiceRuleSellerIDWithGlobalID));
  if ASpec.Target.Syntax = esy_UBL then
    Global := Global and (ASeller.GlobalIdentifierSellerBuyerSchemeID <> 'SEPA');
  if ASpec.Target.Profile = epr_Minimum then
  begin
    Identifier := False;
    Global := False;
  end;
  Result := not Present(ASeller.VATCompanyID) and not Present(ASeller.CompanyID) and not Identifier and
    not Global;
end;

function LineTaxCategoryMissing(AInvoice: TLandrixInvoice): Boolean;
var
  I: TLandrixEInvoiceListIndex;
begin
  Result := True;
  for I := 0 to AInvoice.InvoiceLines.Count - 1 do
    if not Present(TaxCategoryText(AInvoice.InvoiceLines[I].TaxCategory,
      AInvoice.InvoiceLines[I].TaxCategoryOther)) then
      Exit;
  Result := False;
end;

const
  { BR-CO-09: the country codes of the CEN schematron (ISO 3166-1 alpha-2,
    EL for Greece, XI for Northern Ireland) without AN and SS, which only
    one syntax has. DE: BR-CO-09: die Laendercodes des CEN-Schematrons
    (ISO 3166-1 alpha-2, EL fuer Griechenland, XI fuer Nordirland) ohne AN
    und SS, die nur eine Syntax hat. }
  VATCountryPrefixes =
    ' 1A AD AE AF AG AI AL AM AO AQ AR AS AT AU AW AX AZ BA BB BD BE BF BG BH BI BJ BL BM BN BO BQ BR BS BT BV BW' +
    ' BY BZ CA CC CD CF CG CH CI CK CL CM CN CO CR CU CV CW CX CY CZ DE DJ DK DM DO DZ EC EE EG EH EL ER ES ET FI' +
    ' FJ FK FM FO FR GA GB GD GE GF GG GH GI GL GM GN GP GQ GR GS GT GU GW GY HK HM HN HR HT HU ID IE IL IM IN IO' +
    ' IQ IR IS IT JE JM JO JP KE KG KH KI KM KN KP KR KW KY KZ LA LB LC LI LK LR LS LT LU LV LY MA MC MD ME MF MG' +
    ' MH MK ML MM MN MO MP MQ MR MS MT MU MV MW MX MY MZ NA NC NE NF NG NI NL NO NP NR NU NZ OM PA PE PF PG PH PK' +
    ' PL PM PN PR PS PT PW PY QA RE RO RS RU RW SA SB SC SD SE SG SH SI SJ SK SL SM SN SO SR ST SV SX SY SZ TC TD' +
    ' TF TG TH TJ TK TL TM TN TO TR TT TV TW TZ UA UG UM US UY UZ VA VC VE VG VI VN VU WF WS XI YE YT ZA ZM ZW ';

{ BR-CO-09 as each schematron tests it: UBL looks for the first two
  characters anywhere in the list (with SS), CII for the code between
  blanks (with AN).
  DE: BR-CO-09, wie jedes Schematron es prueft: UBL sucht die ersten zwei
  Zeichen irgendwo in der Liste (mit SS), CII den Code zwischen
  Leerzeichen (mit AN). }
function VATPrefixWrong(const AID: TLandrixEInvoiceString; const ASpec: TLandrixEInvoiceSpec): Boolean;
var
  Prefix: string;
begin
  Result := False;
  if not Present(AID) then
    Exit;
  Prefix := LandrixEInvoiceAsciiText(Copy(AID, 1, 2));
  if ASpec.Target.Syntax = esy_UBL then
    Result := (Prefix <> 'SS') and (Pos(Prefix, VATCountryPrefixes) = 0)
  else
    Result := (Prefix <> 'AN') and (Pos(' ' + Prefix + ' ', VATCountryPrefixes) = 0);
end;

{ BR-CO-18: UBL always; the CEN CII schematron only with lines (its context
  is the line), Factur-X always.
  DE: BR-CO-18: UBL immer; das CEN-CII-Schematron nur mit Positionen (sein
  Kontext ist die Position), Factur-X immer. }
function BreakdownMissing(AInvoice: TLandrixInvoice; const ASpec: TLandrixEInvoiceSpec): Boolean;
begin
  Result := (AInvoice.TaxAmountSubtotals.Count = 0) and ((ASpec.Target.Syntax = esy_UBL) or
    (AInvoice.InvoiceLines.Count > 0) or (ASpec.Target.Standard = est_FacturX));
end;

{ --- code list rules ------------------------------------------------------------- }

type
  { The code lists of the BR-CL rules. DE: Die Codelisten der BR-CL-Regeln. }
  TCodeList = (cl_TypeCode, cl_Currency, cl_Reference, cl_Text, cl_ICD, cl_Item, cl_Country, cl_Payment,
    cl_Category, cl_Allowance, cl_Charge, cl_VATEX, cl_Unit, cl_EAS);

const
  { The CEN schematron of the validators (CEN 1.3.16: XRechnung 3.0.2,
    Peppol BIS 3.0.22) carries older lists than the code lists of the
    library (EC version 18): ISO 4217 has STD instead of STN, ISO 3166-1 in
    CII has AN instead of SS, UNTDID 5305 has B as well, the EAS list has
    0219 and 0220 as well but not 9960, the ICD list lacks 0249 to 0251,
    VATEX lacks the VATEX-ES codes, and UNTDID 4451 in UBL lacks the codes
    below. UBL splits UNTDID 1001 into the codes of ubl:Invoice and of
    ubl:CreditNote. CEN 1.3.17 has the lists of version 18; when the
    validators move to it, drop the exceptions for 9960, 0249 to 0251 and
    VATEX-ES (and check the others against its lists: B stays).
    DE: Das CEN-Schematron der Validatoren (CEN 1.3.16: XRechnung 3.0.2,
    Peppol BIS 3.0.22) enthaelt aeltere Listen als die Codelisten der
    Bibliothek (EC Version 18): ISO 4217 hat STD statt STN, ISO 3166-1 in
    CII hat AN statt SS, UNTDID 5305 hat zusaetzlich B, die EAS-Liste
    zusaetzlich 0219 und 0220, aber nicht 9960, der ICD-Liste fehlen 0249
    bis 0251, VATEX fehlen die VATEX-ES-Codes, und UNTDID 4451 fehlen in
    UBL die Codes unten. UBL teilt UNTDID 1001 in die Codes von ubl:Invoice
    und von ubl:CreditNote. CEN 1.3.17 hat die Listen der Version 18; wenn
    die Validatoren darauf umstellen, entfallen die Ausnahmen fuer 9960,
    0249 bis 0251 und VATEX-ES (die anderen gegen deren Listen pruefen: B
    bleibt). }
  UBLInvoiceTypeCodes = '71 80 81 82 84 102 130 202 203 204 211 218 219 295 325 326 331 380 382 383 384 385 ' +
    '386 387 388 389 390 393 394 395 456 457 471 472 473 500 501 527 553 575 623 633 751 780 817 870 875 876 ' +
    '877 935';
  UBLMissingNoteSubjectCodes = 'BAT BAU BAV BAW BAX BAY BAZ BBA BBB BMF BMG BMH CCJ CCK CCL CCM CCN CCO';
  ValidatorEASCodes = '0219 0220';
  ValidatorMissingEASCodes = '9960';
  ValidatorMissingICDCodes = '0249 0250 0251';
  UBLTaxPointCodes = '3 35 432';
  CIITaxPointCodes = '5 29 72';
  { BR-CL-24 compares the attribute as it is, without normalize-space.
    DE: BR-CL-24 vergleicht das Attribut unveraendert, ohne
    normalize-space. }
  AttachmentMimeCodes = 'application/pdf image/png image/jpeg text/csv ' +
    'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet ' +
    'application/vnd.oasis.opendocument.spreadsheet';

{ XPath contains(' list ', concat(' ', AValue, ' ')) for a value without
  blank. DE: XPath contains(' Liste ', concat(' ', AValue, ' ')) fuer einen
  Wert ohne Leerzeichen. }
function InList(const AValue, AList: TLandrixEInvoiceString): Boolean;
begin
  Result := (AValue <> '') and (LandrixEInvoiceTextPos(' ', AValue) = 0) and
    (LandrixEInvoiceTextPos(' ' + AValue + ' ', ' ' + AList + ' ') > 0);
end;

{ True if AValue, normalized (normalize-space, one word), is in list AList
  of the validator (ACII: its CII variant). A member of a code list of the
  library counts with its exact code only (the schematron compares case
  sensitively), VATEX after upper-case.
  DE: True, wenn AValue normalisiert (normalize-space, ein Wort) in der
  Liste AList des Validators steht (ACII: deren CII-Variante). Ein Wert
  einer Codeliste der Bibliothek zaehlt nur mit seinem genauen Code (das
  Schematron unterscheidet Gross- und Kleinschreibung), VATEX nach
  upper-case. }
function CodeListed(AList: TCodeList; const AValue: TLandrixEInvoiceString; ACII: Boolean): Boolean;
var
  Token: TLandrixEInvoiceString;
  TypeCode: TLandrixInvoiceTypeCode;
  Currency: TLandrixInvoiceCurrencyCode;
  Reference: TLandrixInvoiceReferenceCodeQualifier;
  Subject: TLandrixInvoiceNoteSubjectCode;
  ICD: TLandrixInvoiceIdentifierScheme;
  Item: TLandrixInvoiceItemClassificationScheme;
  Country: TLandrixInvoiceCountryCode;
  Payment: TLandrixInvoicePaymentMeansCode;
  Category: TLandrixInvoiceDutyTaxFeeCategoryCode;
  Allowance: TLandrixInvoiceAllowanceOrChargeIdentCode;
  Charge: TLandrixInvoiceSpecialServiceDescriptionCode;
  Exemption: TLandrixInvoiceVATExemptionReasonCode;
  UnitCode: TLandrixInvoiceUnitCode;
  EAS: TLandrixInvoiceElectronicAddressScheme;
begin
  Result := False;
  Token := NormalizedSpace(AValue);
  if (Token = '') or (Pos(' ', Token) > 0) then
    Exit;
  case AList of
    cl_TypeCode:
      Result := LandrixEInvoiceTypeCodeFromStr(Token, TypeCode) and (LandrixEInvoiceTypeCodeToStr(TypeCode) = Token);
    cl_Currency:
      Result := (Token = 'STD') or ((Token <> 'STN') and LandrixEInvoiceCurrencyCodeFromStr(Token, Currency) and
        (LandrixEInvoiceCurrencyCodeToStr(Currency) = Token));
    cl_Reference:
      Result := LandrixEInvoiceReferenceCodeQualifierFromStr(Token, Reference) and
        (LandrixEInvoiceReferenceCodeQualifierToStr(Reference) = Token);
    cl_Text:
      Result := LandrixEInvoiceNoteSubjectCodeFromStr(Token, Subject) and
        (LandrixEInvoiceNoteSubjectCodeToStr(Subject) = Token) and
        (ACII or not InList(Token, UBLMissingNoteSubjectCodes));
    cl_ICD:
      Result := LandrixEInvoiceIdentifierSchemeFromStr(Token, ICD) and (LandrixEInvoiceIdentifierSchemeToStr(ICD) = Token) and
        not InList(Token, ValidatorMissingICDCodes);
    cl_Item:
      Result := LandrixEInvoiceItemClassificationSchemeFromStr(Token, Item) and
        (LandrixEInvoiceItemClassificationSchemeToStr(Item) = Token);
    cl_Country:
      if ACII and ((Token = 'AN') or (Token = 'SS')) then
        Result := Token = 'AN'
      else
        Result := LandrixEInvoiceCountryCodeFromStr(Token, Country) and
          (LandrixEInvoiceCountryCodeToStr(Country) = Token);
    cl_Payment:
      Result := LandrixEInvoicePaymentMeansCodeFromStr(Token, Payment) and
        (LandrixEInvoicePaymentMeansCodeToStr(Payment) = Token);
    cl_Category:
      Result := (Token = 'B') or (LandrixEInvoiceDutyTaxFeeCategoryCodeFromStr(Token, Category) and
        (LandrixEInvoiceDutyTaxFeeCategoryCodeToStr(Category) = Token));
    cl_Allowance:
      Result := LandrixEInvoiceAllowanceOrChargeIdentCodeFromStr(Token, Allowance) and
        (LandrixEInvoiceAllowanceOrChargeIdentCodeToStr(Allowance) = Token);
    cl_Charge:
      Result := LandrixEInvoiceSpecialServiceDescriptionCodeFromStr(Token, Charge) and
        (LandrixEInvoiceSpecialServiceDescriptionCodeToStr(Charge) = Token);
    cl_VATEX:
      { the codes are upper case; FromStr ignores the case as upper-case(.) does }
      Result := LandrixEInvoiceVATExemptionReasonCodeFromStr(Token, Exemption) and
        (Pos('VATEX-ES-', UpperCase(string(Token))) <> 1);
    cl_Unit:
      Result := LandrixEInvoiceUnitCodeFromStr(Token, UnitCode) and (LandrixEInvoiceUnitCodeToStr(UnitCode) = Token);
  else
    Result := InList(Token, ValidatorEASCodes) or (LandrixEInvoiceElectronicAddressSchemeFromStr(Token, EAS) and
      (LandrixEInvoiceElectronicAddressSchemeToStr(EAS) = Token) and not InList(Token, ValidatorMissingEASCodes));
  end;
end;

{ A code as the mappers write it: the enumeration, otherwise the other text.
  DE: Ein Code, wie die Mapper ihn schreiben: die Aufzaehlung, sonst der
  andere Text. }
function WrittenCode(const AEnumText, AOther: TLandrixEInvoiceString): TLandrixEInvoiceString;
begin
  if Present(AEnumText) then
    Result := AEnumText
  else
    Result := AOther;
end;

{ An element is written with text, an attribute when it is not empty.
  DE: Ein Element wird mit Text geschrieben, ein Attribut, wenn es nicht
  leer ist. }
function BadCode(AList: TCodeList; const AValue: TLandrixEInvoiceString; ACII: Boolean): Boolean;
begin
  Result := Present(AValue) and not CodeListed(AList, AValue, ACII);
end;

function BadAttribute(AList: TCodeList; const AValue: TLandrixEInvoiceString; ACII: Boolean): Boolean;
begin
  Result := (AValue <> '') and not CodeListed(AList, AValue, ACII);
end;

{ The extension codes XR01 to XR03 as identifier scheme, exactly (as in
  the mappers and the KoSIT lists). DE: Die Extension-Codes XR01 bis XR03
  als Kennungsschema, genau so geschrieben (wie in den Mappern und den
  KoSIT-Listen). }
function IsExtensionScheme(const AValue, AScheme: TLandrixEInvoiceString): Boolean;
begin
  Result := Present(AValue) and ((AScheme = 'XR01') or (AScheme = 'XR02') or (AScheme = 'XR03'));
end;

{ The XRechnung extension as the mappers declare it (UsesExtension): UBL
  (ubl:Invoice only) with sub lines or third-party payments, both syntaxes
  with an embedded XML attachment or an extension scheme of BT-34, BT-49,
  BT-29, BT-46, BT-71, BT-30, BT-47, BT-60, BT-61 or BT-157.
  DE: Die XRechnung-Extension, wie die Mapper sie deklarieren
  (UsesExtension): UBL (nur ubl:Invoice) mit Unterpositionen oder Zahlungen
  Dritter, beide Syntaxen mit eingebettetem XML-Anhang oder einem
  Extension-Schema von BT-34, BT-49, BT-29, BT-46, BT-71, BT-30, BT-47,
  BT-60, BT-61 oder BT-157. }
function ExtensionWritten(AInvoice: TLandrixInvoice; const ASpec: TLandrixEInvoiceSpec): Boolean;
var
  I: TLandrixEInvoiceListIndex;
  Seller, Buyer: TLandrixInvoiceAccountingParty;
  Value, Scheme, Conflict: TLandrixEInvoiceString;
begin
  Result := False;
  if not Present(ASpec.ExtensionCustomizationID) or
     ((ASpec.Target.Syntax = esy_UBL) and (AInvoice.InvoiceTypeCode = itc_CreditNote)) then
    Exit;
  Result := True;
  if ASpec.Target.Syntax = esy_UBL then
  begin
    if AInvoice.PrepaidPayments.Count > 0 then
      Exit;
    for I := 0 to AInvoice.InvoiceLines.Count - 1 do
      if AInvoice.InvoiceLines[I].SubInvoiceLines.Count > 0 then
        Exit;
  end;
  for I := 0 to AInvoice.Attachments.Count - 1 do
    if AInvoice.Attachments[I].ContainsBinaryObject and
       (AInvoice.Attachments[I].AttachmentType = iat_application_xml) then
      Exit;
  Seller := AInvoice.AccountingSupplierParty;
  Buyer := AInvoice.AccountingCustomerParty;
  if IsExtensionScheme(Seller.ElectronicAddressSellerBuyer, Seller.ElectronicAddressSellerBuyerSchemeID) or
     IsExtensionScheme(Buyer.ElectronicAddressSellerBuyer, Buyer.ElectronicAddressSellerBuyerSchemeID) or
     IsExtensionScheme(Seller.GlobalIdentifierSellerBuyer, Seller.GlobalIdentifierSellerBuyerSchemeID) or
     IsExtensionScheme(Buyer.GlobalIdentifierSellerBuyer, Buyer.GlobalIdentifierSellerBuyerSchemeID) or
     IsExtensionScheme(AInvoice.DeliveryInformation.LocationIdentifier,
       AInvoice.DeliveryInformation.LocationIdentifierSchemeID) or
     IsExtensionScheme(Seller.CompanyID, Seller.CompanyIDSchemeID) or
     IsExtensionScheme(Buyer.CompanyID, Buyer.CompanyIDSchemeID) or
     IsExtensionScheme(AInvoice.PayeeParty.Identifier, AInvoice.PayeeParty.IdentifierSchemeID) or
     IsExtensionScheme(AInvoice.PayeeParty.CompanyID, AInvoice.PayeeParty.CompanyIDSchemeID) then
    Exit;
  for I := 0 to AInvoice.InvoiceLines.Count - 1 do
    if LandrixEInvoiceStandardItemIdentifierOf(AInvoice.InvoiceLines[I], Value, Scheme, Conflict) and
       IsExtensionScheme(Value, Scheme) then
      Exit;
  Result := False;
end;

{ BR-CL-08 in UBL: the subject code is written as '#code#' before the note
  text; the schematron tests the text between the first two '#' when it
  has three characters. A text with a blank there counts as unlisted (the
  schematron finds it in its list when it spans two codes).
  DE: BR-CL-08 in UBL: der Betreffcode wird als '#Code#' vor den Text der
  Bemerkung geschrieben; das Schematron prueft den Text zwischen den
  ersten beiden '#', wenn er drei Zeichen hat. Ein Text mit Leerzeichen
  dort gilt als nicht gelistet (das Schematron findet ihn in seiner Liste,
  wenn er zwei Codes ueberspannt). }
function UBLNoteSubjectWrong(const AText: TLandrixEInvoiceString): Boolean;
var
  Rest: TLandrixEInvoiceString;
  P: Integer;
begin
  Result := False;
  P := Pos('#', AText);
  if P = 0 then
    Exit;
  Rest := Copy(AText, P + 1, Length(AText) - P);
  P := Pos('#', Rest);
  if P <> 4 then
    Exit;
  Result := not CodeListed(cl_Text, Copy(Rest, 1, 3), False);
end;

{ BR-CL-19 (allowances) and BR-CL-20 (charges): the reason code as written.
  DE: BR-CL-19 (Nachlaesse) und BR-CL-20 (Zuschlaege): der Grundcode, wie
  er geschrieben wird. }
function ReasonCodeWrong(AIndex: TCheckRuleIndex; AItem: TLandrixInvoiceAllowanceCharge; ACII: Boolean): Boolean;
begin
  if AIndex = cr_BRCL19 then
    Result := not AItem.ChargeIndicator and BadCode(cl_Allowance,
      WrittenCode(LandrixEInvoiceAllowanceOrChargeIdentCodeToStr(AItem.ReasonCodeAllowance),
      AItem.ReasonCodeAllowanceOther), ACII)
  else
    Result := AItem.ChargeIndicator and BadCode(cl_Charge,
      WrittenCode(LandrixEInvoiceSpecialServiceDescriptionCodeToStr(AItem.ReasonCodeCharge),
      AItem.ReasonCodeChargeOther), ACII);
end;

{ The extension codes XR01 to XR03 as a scheme the way the schematron
  compares it (normalize-space), for BR-DEX-04 to BR-DEX-08. A scheme of
  white space only passes too: the schematron looks for '  ' in the joined
  lists ($DIGA-CODES ends, the ICD and EAS lists start with a blank).
  DE: Die Extension-Codes XR01 bis XR03 als Schema, so verglichen wie im
  Schematron (normalize-space), fuer BR-DEX-04 bis BR-DEX-08. Ein Schema
  nur aus Leerraum besteht ebenfalls: das Schematron sucht '  ' in den
  verketteten Listen. }
function IsExtensionCode(const AScheme: TLandrixEInvoiceString): Boolean;
var
  S: TLandrixEInvoiceString;
begin
  S := NormalizedSpace(AScheme);
  Result := (S = 'XR01') or (S = 'XR02') or (S = 'XR03') or ((S = '') and (AScheme <> ''));
end;

{ The code list rules on the lines as written, sub lines included where
  ASubLines: BR-CL-07 (BT-128), 13, 15, 18, 19, 20, 21 and 23.
  DE: Die Codelistenregeln auf den Positionen, wie sie geschrieben werden,
  Unterpositionen eingeschlossen, wo ASubLines: BR-CL-07 (BT-128), 13, 15,
  18, 19, 20, 21 und 23. }
function LineCodeViolated(AIndex: TCheckRuleIndex; ALines: TLandrixInvoiceLines; ACII, ASubLines: Boolean;
  AExtension: Boolean = False): Boolean;
var
  I, J: TLandrixEInvoiceListIndex;
  Line: TLandrixInvoiceLine;
  Value, Scheme, Conflict: TLandrixEInvoiceString;
begin
  Result := True;
  for I := 0 to ALines.Count - 1 do
  begin
    Line := ALines[I];
    case AIndex of
      { CII writes the scheme as element, UBL as attribute }
      cr_BRCL07:
        if Present(Line.ObjectIdentifier) and
           ((ACII and BadCode(cl_Reference, Line.ObjectIdentifierSchemeID, ACII)) or
           (not ACII and BadAttribute(cl_Reference, Line.ObjectIdentifierSchemeID, ACII))) then
          Exit;
      { a classification without scheme is left out (BR-65) }
      cr_BRCL13:
        for J := 0 to Line.ItemClassifications.Count - 1 do
          if Present(Line.ItemClassifications[J].ClassCode) and Present(Line.ItemClassifications[J].ListID) and
             not CodeListed(cl_Item, Line.ItemClassifications[J].ListID, ACII) then
            Exit;
      cr_BRCL15:
        if BadCode(cl_Country, Line.OriginTradeCountry, ACII) then
          Exit;
      cr_BRCL18:
        if BadCode(cl_Category, TaxCategoryText(Line.TaxCategory, Line.TaxCategoryOther), ACII) then
          Exit;
      cr_BRCL19, cr_BRCL20:
        for J := 0 to Line.AllowanceCharges.Count - 1 do
          if ReasonCodeWrong(AIndex, Line.AllowanceCharges[J], ACII) then
            Exit;
      cr_BRCL21XR, cr_BRCL21BIS:
        if LandrixEInvoiceStandardItemIdentifierOf(Line, Value, Scheme, Conflict) and
           BadAttribute(cl_ICD, Scheme, ACII) and not (AExtension and IsExtensionCode(Scheme)) then
          Exit;
      cr_BRCL23XR, cr_BRCL23BIS:
        if BadAttribute(cl_Unit, WrittenCode(LandrixEInvoiceUnitCodeToStr(Line.UnitCode), Line.UnitCodeOther),
             ACII) or
           ((Line.BaseQuantity <> 0) and BadAttribute(cl_Unit,
             WrittenCode(LandrixEInvoiceUnitCodeToStr(Line.BaseQuantityUnitCode), Line.BaseQuantityUnitCodeOther),
             ACII)) then
          Exit;
    else
      { no rule on the lines }
      Break;
    end;
    if ASubLines and LineCodeViolated(AIndex, Line.SubInvoiceLines, ACII, True, AExtension) then
      Exit;
  end;
  Result := False;
end;

{ BR-CL-10: a global identifier without scheme gets 0088 (ADefault), CII
  writes another identifier without scheme as ram:ID; UBL accepts SEPA for
  the seller and the payee (ASEPA).
  DE: BR-CL-10: eine globale Kennung ohne Schema bekommt 0088 (ADefault),
  CII schreibt eine andere Kennung ohne Schema als ram:ID; UBL nimmt SEPA
  fuer Verkaeufer und Zahlungsempfaenger an (ASEPA). }
function PartySchemeWrong(const AValue, AScheme: TLandrixEInvoiceString; ADefault, ASEPA, ACII: Boolean;
  AExtension: Boolean = False): Boolean;
begin
  Result := Present(AValue) and not ((ADefault or ACII) and not Present(AScheme)) and
    BadAttribute(cl_ICD, AScheme, ACII) and not (ASEPA and (NormalizedSpace(AScheme) = 'SEPA')) and
    not (AExtension and IsExtensionCode(AScheme));
end;

{ True if code list rule AIndex is violated by the codes as the mappers
  write them. The rules on schemes, attachments and electronic addresses
  are information only in the XRechnung extension scenario.
  DE: True, wenn die Codes, wie die Mapper sie schreiben, die
  Codelistenregel AIndex verletzen. Die Regeln zu Schemata, Anhaengen und
  elektronischen Adressen sind im XRechnung-Extension-Szenario nur
  Information. }
function CodeListViolated(AIndex: TCheckRuleIndex; AInvoice: TLandrixInvoice; const ASpec: TLandrixEInvoiceSpec): Boolean;
var
  I: TLandrixEInvoiceListIndex;
  CII, SubLines, Written, TenderWritten, ObjectWritten, Ext: Boolean;
  Seller, Buyer: TLandrixInvoiceAccountingParty;
  Payee, TaxRepresentative, Invoicee: TLandrixInvoiceParty;
  Item: TLandrixInvoiceAllowanceCharge;
  Attachment: TLandrixInvoiceAttachment;
  Code, Scheme: TLandrixEInvoiceString;
  { a scheme of an ICD or EAS rule, extension codes accepted for BR-DEX-* }
  function BadScheme(AList: TCodeList; const AScheme: TLandrixEInvoiceString): Boolean;
  begin
    Result := BadAttribute(AList, AScheme, CII) and not (Ext and IsExtensionCode(AScheme));
  end;

begin
  Result := False;
  { BR-DEX-01 and -04 to -08 run the code list rule they replace }
  Ext := AIndex in [cr_BRDEX01..cr_BRDEX08];
  if Ext or (AIndex in [cr_BRCL10, cr_BRCL11, cr_BRCL21XR, cr_BRCL24, cr_BRCL25, cr_BRCL26]) then
    if Ext <> ExtensionWritten(AInvoice, ASpec) then
      Exit
    else if Ext then
      case AIndex of
        cr_BRDEX01: AIndex := cr_BRCL24;
        cr_BRDEX04: AIndex := cr_BRCL10;
        cr_BRDEX05: AIndex := cr_BRCL11;
        cr_BRDEX06: AIndex := cr_BRCL21XR;
        cr_BRDEX07: AIndex := cr_BRCL25;
      else
        AIndex := cr_BRCL26;
      end;
  CII := ASpec.Target.Syntax = esy_CII;
  SubLines := LandrixEInvoiceSubLinesNested(AInvoice, ASpec);
  Seller := AInvoice.AccountingSupplierParty;
  Buyer := AInvoice.AccountingCustomerParty;
  Payee := AInvoice.PayeeParty;
  TaxRepresentative := AInvoice.TaxRepresentativeParty;
  Invoicee := AInvoice.InvoiceeParty;
  Result := True;
  case AIndex of
    cr_BRCL01:
      begin
        Code := WrittenCode(LandrixEInvoiceTypeCodeToStr(AInvoice.InvoiceTypeCode), AInvoice.InvoiceTypeCodeOther);
        { UBL writes 381 as ubl:CreditNote, everything else as ubl:Invoice }
        if CII then
          Result := BadCode(cl_TypeCode, Code, True)
        else
          Result := Present(Code) and (AInvoice.InvoiceTypeCode <> itc_CreditNote) and
            not InList(NormalizedSpace(Code), UBLInvoiceTypeCodes);
      end;
    { UBL: every amount carries @currencyID, CII: the VAT total }
    cr_BRCL03:
      Result := BadAttribute(cl_Currency, AInvoice.InvoiceCurrencyCode, CII) or
        (Present(AInvoice.TaxCurrencyCode) and (AInvoice.TaxCurrencyCode <> AInvoice.InvoiceCurrencyCode) and
        AInvoice.TaxAmountTotalInTaxCurrency.HasValue and BadAttribute(cl_Currency, AInvoice.TaxCurrencyCode, CII));
    cr_BRCL04:
      Result := BadCode(cl_Currency, AInvoice.InvoiceCurrencyCode, CII);
    cr_BRCL05:
      Result := (AInvoice.TaxCurrencyCode <> AInvoice.InvoiceCurrencyCode) and
        BadCode(cl_Currency, AInvoice.TaxCurrencyCode, CII);
    { BT-8 is left out next to BT-7 (BR-CO-03); CII writes it in the first VAT
      breakdown, converted to UNTDID 2475 }
    cr_BRCL06:
      if not Present(AInvoice.TaxPointDateCode) or AInvoice.TaxPointDate.HasValue then
        Result := False
      else if not CII then
        Result := not InList(NormalizedSpace(AInvoice.TaxPointDateCode), UBLTaxPointCodes)
      else if AInvoice.TaxAmountSubtotals.Count = 0 then
        Result := False
      else
      begin
        LandrixEInvoiceTaxPointDateCodeToCII(AInvoice.TaxPointDateCode, Code);
        Result := not InList(NormalizedSpace(Code), CIITaxPointCodes);
      end;
    { BT-18: UBL writes the first object identifier with an identifier, CII
      further ones where the rule table allows them }
    cr_BRCL07:
      begin
        ObjectWritten := False;
        for I := 0 to AInvoice.Attachments.Count - 1 do
        begin
          Attachment := AInvoice.Attachments[I];
          if (Attachment.TypeCode <> iatc_130) or not Present(Attachment.ID) or
             (ObjectWritten and (not CII or Forbidden(ASpec, LandrixEInvoiceRuleFurtherObjectIdentifier))) then
            Continue;
          ObjectWritten := True;
          if (CII and BadCode(cl_Reference, Attachment.SchemeID, CII)) or
             (not CII and BadAttribute(cl_Reference, Attachment.SchemeID, CII)) then
            Exit;
        end;
        Result := LineCodeViolated(AIndex, AInvoice.InvoiceLines, CII, SubLines);
      end;
    cr_BRCL08:
      begin
        for I := 0 to AInvoice.Notes.Count - 1 do
        begin
          if not Present(AInvoice.Notes[I].Content) then
            Continue;
          Code := WrittenCode(LandrixEInvoiceNoteSubjectCodeToStr(AInvoice.Notes[I].SubjectCode),
            AInvoice.Notes[I].SubjectCodeOther);
          if CII then
          begin
            if BadCode(cl_Text, Code, CII) then
              Exit;
          end
          else if Present(Code) then
          begin
            if UBLNoteSubjectWrong('#' + Code + '#' + AInvoice.Notes[I].Content) then
              Exit;
          end
          else if UBLNoteSubjectWrong(AInvoice.Notes[I].Content) then
            Exit;
        end;
        Result := False;
      end;
    { UBL: the payee identifier keeps its scheme and the creditor identifier
      has SEPA; CII: an identifier with scheme is a global identifier, the
      tax representative has one in EXTENDED only }
    cr_BRCL10:
      Result := PartySchemeWrong(Seller.GlobalIdentifierSellerBuyer, Seller.GlobalIdentifierSellerBuyerSchemeID,
        True, not CII, CII, Ext) or
        PartySchemeWrong(Buyer.GlobalIdentifierSellerBuyer, Buyer.GlobalIdentifierSellerBuyerSchemeID, True, False,
        CII, Ext) or
        (PartySet(Payee) and PartySchemeWrong(Payee.Identifier, Payee.IdentifierSchemeID, False, not CII, CII,
        Ext)) or
        (CII and PartySet(TaxRepresentative) and not Forbidden(ASpec, LandrixEInvoiceRuleTaxRepresentativeExtended) and
        PartySchemeWrong(TaxRepresentative.Identifier, TaxRepresentative.IdentifierSchemeID, False, False, CII,
        Ext)) or
        (CIIInvoiceeWritten(AInvoice, ASpec) and
        PartySchemeWrong(Invoicee.Identifier, Invoicee.IdentifierSchemeID, False, False, CII, Ext));
    cr_BRCL11:
      Result := (Present(Seller.CompanyID) and BadScheme(cl_ICD, Seller.CompanyIDSchemeID)) or
        (Present(Buyer.CompanyID) and BadScheme(cl_ICD, Buyer.CompanyIDSchemeID)) or
        (Present(Payee.CompanyID) and BadScheme(cl_ICD, Payee.CompanyIDSchemeID)) or
        (CII and Present(TaxRepresentative.CompanyID) and
        not Forbidden(ASpec, LandrixEInvoiceRuleTaxRepresentativeExtended) and
        BadScheme(cl_ICD, TaxRepresentative.CompanyIDSchemeID)) or
        (CIIInvoiceeWritten(AInvoice, ASpec) and Present(Invoicee.CompanyID) and
        BadScheme(cl_ICD, Invoicee.CompanyIDSchemeID));
    { the payee address in CII EXTENDED only }
    cr_BRCL14:
      Result := BadCode(cl_Country, Seller.Address.CountryCode, CII) or
        BadCode(cl_Country, Buyer.Address.CountryCode, CII) or
        (PartySet(TaxRepresentative) and AddressSet(TaxRepresentative.Address) and
        BadCode(cl_Country, TaxRepresentative.Address.CountryCode, CII)) or
        (AddressSet(AInvoice.DeliveryInformation.Address) and
        BadCode(cl_Country, AInvoice.DeliveryInformation.Address.CountryCode, CII)) or
        (CIIPayeeFull(AInvoice, ASpec) and AddressSet(Payee.Address) and
        BadCode(cl_Country, Payee.Address.CountryCode, CII)) or
        (CIIInvoiceeWritten(AInvoice, ASpec) and AddressSet(Invoicee.Address) and
        BadCode(cl_Country, Invoicee.Address.CountryCode, CII));
    cr_BRCL16:
      begin
        for I := 0 to AInvoice.PaymentTypes.Count - 1 do
          if PaymentWritten(AInvoice.PaymentTypes[I]) and BadCode(cl_Payment,
             WrittenCode(LandrixEInvoicePaymentMeansCodeToStr(AInvoice.PaymentTypes[I].PaymentMeansCode),
             AInvoice.PaymentTypes[I].PaymentMeansCodeOther), CII) then
            Exit;
        Result := False;
      end;
    { cac:TaxCategory (UBL) is also the category of the VAT breakdown,
      ram:ApplicableTradeTax (CII) also of the line }
    cr_BRCL17, cr_BRCL18:
      begin
        if AIndex = cr_BRCL17 then
          for I := 0 to AInvoice.AllowanceCharges.Count - 1 do
          begin
            Item := AInvoice.AllowanceCharges[I];
            if BadCode(cl_Category, TaxCategoryText(Item.TaxCategory, Item.TaxCategoryOther), CII) then
              Exit;
          end
        else if LineCodeViolated(AIndex, AInvoice.InvoiceLines, CII, SubLines) then
          Exit;
        if (AIndex = cr_BRCL17) <> CII then
          for I := 0 to AInvoice.TaxAmountSubtotals.Count - 1 do
            if BadCode(cl_Category, TaxCategoryText(AInvoice.TaxAmountSubtotals[I].TaxCategory,
               AInvoice.TaxAmountSubtotals[I].TaxCategoryOther), CII) then
              Exit;
        Result := False;
      end;
    cr_BRCL19, cr_BRCL20:
      begin
        for I := 0 to AInvoice.AllowanceCharges.Count - 1 do
          if ReasonCodeWrong(AIndex, AInvoice.AllowanceCharges[I], CII) then
            Exit;
        Result := LineCodeViolated(AIndex, AInvoice.InvoiceLines, CII, SubLines);
      end;
    cr_BRCL13, cr_BRCL15, cr_BRCL21XR, cr_BRCL21BIS, cr_BRCL23XR, cr_BRCL23BIS:
      Result := LineCodeViolated(AIndex, AInvoice.InvoiceLines, CII, SubLines, Ext);
    cr_BRCL22:
      begin
        for I := 0 to AInvoice.TaxAmountSubtotals.Count - 1 do
          if BadCode(cl_VATEX, AInvoice.TaxAmountSubtotals[I].TaxExemptionReasonCode, CII) then
            Exit;
        Result := False;
      end;
    { the attachments as written: UBL writes BT-17 (type 50) without
      attachment, CII the first one with an identifier; BT-18 (type 130) as
      in BR-CL-07 }
    cr_BRCL24:
      begin
        TenderWritten := False;
        ObjectWritten := False;
        for I := 0 to AInvoice.Attachments.Count - 1 do
        begin
          Attachment := AInvoice.Attachments[I];
          Written := True;
          if Attachment.TypeCode = iatc_50 then
          begin
            Written := CII and not TenderWritten and Present(Attachment.ID);
            TenderWritten := TenderWritten or Written;
          end
          else if Attachment.TypeCode = iatc_130 then
          begin
            Written := Present(Attachment.ID) and
              not (ObjectWritten and (not CII or Forbidden(ASpec, LandrixEInvoiceRuleFurtherObjectIdentifier)));
            ObjectWritten := ObjectWritten or Written;
          end;
          if Written and Attachment.ContainsBinaryObject then
          begin
            Code := WrittenCode(LandrixEInvoiceAttachmentTypeToStr(Attachment.AttachmentType),
              Attachment.AttachmentTypeOther);
            { BR-CL-24 checks a written @mimeCode only, BR-DEX-01 every
              binary object }
            if Ext then
            begin
              if not InList(Code, AttachmentMimeCodes) and (Code <> 'application/xml') then
                Exit;
            end
            else if (Code <> '') and not InList(Code, AttachmentMimeCodes) then
              Exit;
          end;
        end;
        Result := False;
      end;
    { without scheme the default EM where the specification allows it }
    cr_BRCL25:
      begin
        Scheme := Seller.ElectronicAddressSellerBuyerSchemeID;
        if not Present(Scheme) and not Forbidden(ASpec, LandrixEInvoiceRuleElectronicAddressDefaultEM) then
          Scheme := 'EM';
        if Present(Seller.ElectronicAddressSellerBuyer) and BadScheme(cl_EAS, Scheme) then
          Exit;
        Scheme := Buyer.ElectronicAddressSellerBuyerSchemeID;
        if not Present(Scheme) and not Forbidden(ASpec, LandrixEInvoiceRuleElectronicAddressDefaultEM) then
          Scheme := 'EM';
        Result := Present(Buyer.ElectronicAddressSellerBuyer) and BadScheme(cl_EAS, Scheme);
      end;
    { CII writes a location without scheme as ram:ID }
    cr_BRCL26:
      begin
        Scheme := AInvoice.DeliveryInformation.LocationIdentifierSchemeID;
        Result := Present(AInvoice.DeliveryInformation.LocationIdentifier) and (not CII or Present(Scheme)) and
          BadScheme(cl_ICD, Scheme);
      end;
  else
    Result := False;
  end;
end;


{ --- rules --------------------------------------------------------------------- }

{ True if rule AIndex is violated by AInvoice for ASpec. The LX-CC rules keep
  the conditions of XRechnung-for-Delphi: a target that cannot be written
  (empty entry) fails third-party payments and line delivery data.
  DE: True, wenn AInvoice die Regel AIndex fuer ASpec verletzt. Die
  LX-CC-Regeln behalten die Bedingungen von XRechnung-for-Delphi: ein Ziel,
  das nicht geschrieben werden kann (leerer Eintrag), scheitert an
  Zahlungen Dritter und Lieferdaten je Position. }
{ --- Peppol rules ---------------------------------------------------------------- }

{ u:slack of the schematron: AExp - ASlack <= AVal <= AExp + ASlack.
  DE: u:slack des Schematrons: AExp - ASlack <= AVal <= AExp + ASlack. }
function WithinSlack(const AExp, AVal, ASlack: TExact): Boolean;
begin
  Result := (ExactCompare(ExactAdd(AExp, ASlack), AVal) >= 0) and
    (ExactCompare(ExactSub(AExp, ASlack), AVal) <= 0);
end;

{ $slackValue: XRechnung allows 0.5 for the invoice currency HUF, Peppol
  always 0.02.
  DE: $slackValue: XRechnung erlaubt 0,5 fuer die Rechnungswaehrung HUF,
  Peppol immer 0,02. }
function PeppolSlack(AInvoice: TLandrixInvoice; const ASpec: TLandrixEInvoiceSpec): TExact;
begin
  if (ASpec.Target.Standard = est_XRechnung) and (AInvoice.InvoiceCurrencyCode = 'HUF') then
    Result := ExactOf('0.5')
  else
    Result := ExactOf('0.02');
end;

{ PEPPOL-EN16931-R040 to R042 for one allowance or charge, as written: the
  percentage with 4 decimals; the base amount on
  document level when it is not 0, on line level also as 0 next to a
  percentage. R040: amount = base amount x percentage / 100 within the
  slack.
  DE: PEPPOL-EN16931-R040 bis R042 fuer einen Nachlass oder Zuschlag, wie
  geschrieben: der Prozentsatz mit 4 Nachkommastellen; der Grundbetrag auf
  Dokumentebene, wenn er nicht 0 ist, auf
  Positionsebene neben einem Prozentsatz auch als 0. R040: Betrag =
  Grundbetrag x Prozentsatz / 100 innerhalb der Toleranz. }
function PeppolAllowanceViolated(AIndex: TCheckRuleIndex; AItem: TLandrixInvoiceAllowanceCharge;
  AOnLine: Boolean; const ASlack: TExact; const APath: TLandrixEInvoiceString;
  var ADetail: TRuleDetail): Boolean;
var
  HasPercent, HasBase: Boolean;
  Expected, Percent: TExact;
  Terms: TLandrixEInvoiceString;
begin
  HasPercent := AItem.MultiplierFactorNumeric <> 0;
  HasBase := (AItem.BaseAmount <> 0) or (AOnLine and HasPercent);
  Result := False;
  case AIndex of
    cr_PeppolR040:
      if HasPercent and HasBase then
      begin
        Percent := ExactOf(LandrixEInvoiceDecimalToLexical(Writable(AItem.MultiplierFactorNumeric), 4));
        Expected := ExactDiv(ExactMul(AmountExact(AItem.BaseAmount), Percent), ExactOf('100'));
        Result := not WithinSlack(AmountExact(AItem.Amount), Expected, ASlack);
        if Result then
        begin
          if AOnLine and AItem.ChargeIndicator then
            Terms := 'BT-142 x BT-143'
          else if AOnLine then
            Terms := 'BT-137 x BT-138'
          else if AItem.ChargeIndicator then
            Terms := 'BT-100 x BT-101'
          else
            Terms := 'BT-93 x BT-94';
          SetDetail(ADetail, APath + '.Amount', ExactText(Expected, 2), LandrixEInvoiceAmountToLexical(AItem.Amount),
            'base amount ' + LandrixEInvoiceAmountToLexical(AItem.BaseAmount) + ' x percentage ' +
            ExactText(Percent, 0) + ' / 100 (' + Terms + ' / 100); the difference may be up to ' +
            ExactText(ASlack, 2));
        end;
      end;
    cr_PeppolR041:
      begin
        Result := HasPercent and not HasBase;
        if Result then
          ADetail.Path := APath + '.BaseAmount';
      end;
    cr_PeppolR042:
      begin
        Result := HasBase and not HasPercent;
        if Result then
          ADetail.Path := APath + '.MultiplierFactorNumeric';
      end;
  else
    { the other rules are no allowance rules }
    ;
  end;
end;

function PeppolLineAllowancesViolated(AIndex: TCheckRuleIndex; ALines: TLandrixInvoiceLines; ASubLines: Boolean;
  const ASlack: TExact; const APath: TLandrixEInvoiceString; var ADetail: TRuleDetail): Boolean;
var
  I, J: TLandrixEInvoiceListIndex;
  Line: TLandrixEInvoiceString;
begin
  Result := True;
  for I := 0 to ALines.Count - 1 do
  begin
    Line := APath + '[' + TLandrixEInvoiceString(IntToStr(I)) + ']';
    for J := 0 to ALines[I].AllowanceCharges.Count - 1 do
      if PeppolAllowanceViolated(AIndex, ALines[I].AllowanceCharges[J], True, ASlack,
         Line + '.AllowanceCharges[' + TLandrixEInvoiceString(IntToStr(J)) + ']', ADetail) then
        Exit;
    if ASubLines and PeppolLineAllowancesViolated(AIndex, ALines[I].SubInvoiceLines, True,
       ASlack, Line + '.SubInvoiceLines', ADetail) then
      Exit;
  end;
  Result := False;
end;

{ Sub lines are written nested where the target allows them, otherwise
  flat (LandrixEInvoiceSubLines).
  DE: Unterpositionen werden verschachtelt geschrieben, wo das Ziel sie
  erlaubt, sonst flach (LandrixEInvoiceSubLines). }
function SubLinesWritten(AInvoice: TLandrixInvoice; const ASpec: TLandrixEInvoiceSpec): Boolean;
begin
  Result := LandrixEInvoiceSubLinesNested(AInvoice, ASpec);
end;

{ Document level and line level; UBL checks the allowances and charges of
  cac:InvoiceLine only, CII those of every written line.
  DE: Dokument- und Positionsebene; UBL prueft nur die Nachlaesse und
  Zuschlaege von cac:InvoiceLine, CII die jeder geschriebenen Position. }
function PeppolAllowancesViolated(AIndex: TCheckRuleIndex; AInvoice: TLandrixInvoice;
  const ASpec: TLandrixEInvoiceSpec; var ADetail: TRuleDetail): Boolean;
var
  I: TLandrixEInvoiceListIndex;
  Slack: TExact;
  IsCII: Boolean;
begin
  Result := True;
  Slack := PeppolSlack(AInvoice, ASpec);
  for I := 0 to AInvoice.AllowanceCharges.Count - 1 do
    if PeppolAllowanceViolated(AIndex, AInvoice.AllowanceCharges[I], False, Slack,
       'AllowanceCharges[' + TLandrixEInvoiceString(IntToStr(I)) + ']', ADetail) then
      Exit;
  IsCII := ASpec.Target.Syntax = esy_CII;
  Result := PeppolLineAllowancesViolated(AIndex, AInvoice.InvoiceLines, IsCII and SubLinesWritten(AInvoice, ASpec),
    Slack, 'InvoiceLines', ADetail);
end;

{ The VAT accounting currency (BT-6) is written when it differs from the
  invoice currency.
  DE: Die Steuerwaehrung (BT-6) wird geschrieben, wenn sie von der
  Rechnungswaehrung abweicht. }
function TaxCurrencyWritten(AInvoice: TLandrixInvoice): Boolean;
begin
  Result := Present(AInvoice.TaxCurrencyCode) and (AInvoice.TaxCurrencyCode <> AInvoice.InvoiceCurrencyCode);
end;

{ PEPPOL-EN16931-R053 to R055 on the VAT totals as written. UBL: the VAT
  total in the invoice currency carries the breakdown, a second one without
  breakdown BT-111 (R053, R054: exactly one with breakdown, one without only
  next to BT-6); R055 requires equal signs, 0 counts for both in UBL and as
  positive in CII. A missing BT-111 next to BT-6 violates R054 and R055 (and
  BR-53).
  DE: PEPPOL-EN16931-R053 bis R055 auf den geschriebenen Steuersummen. UBL:
  die Steuersumme in der Rechnungswaehrung traegt die Aufschluesselung, eine
  zweite ohne Aufschluesselung BT-111 (R053, R054: genau eine mit
  Aufschluesselung, eine ohne nur neben BT-6); R055 verlangt gleiche
  Vorzeichen, 0 zaehlt in UBL fuer beide und in CII als positiv. Ein
  fehlendes BT-111 neben BT-6 verletzt R054 und R055 (und BR-53). }
function PeppolTaxTotalViolated(AIndex: TCheckRuleIndex; AInvoice: TLandrixInvoice;
  const ASpec: TLandrixEInvoiceSpec): Boolean;
var
  Written, Accounting, IsUBL: Boolean;
  Without: Integer;
  T, D: Int64;
begin
  Result := False;
  Written := TaxCurrencyWritten(AInvoice);
  Accounting := Written and AInvoice.TaxAmountTotalInTaxCurrency.HasValue;
  IsUBL := ASpec.Target.Syntax = esy_UBL;
  case AIndex of
    cr_PeppolR053:
      Result := AInvoice.TaxAmountSubtotals.Count = 0;
    cr_PeppolR054:
      if IsUBL then
      begin
        Without := Ord(Accounting);
        if AInvoice.TaxAmountSubtotals.Count = 0 then
          Inc(Without);
        Result := Without <> Ord(Written);
      end
      else
        Result := Written and not Accounting;
    cr_PeppolR055:
      if Written and not Accounting then
        Result := True
      else if Accounting then
      begin
        T := Cents(AInvoice.TaxAmountTotalInTaxCurrency.Value);
        D := Cents(AInvoice.TaxAmountTotal);
        if IsUBL then
          Result := not (((T <= 0) and (D <= 0)) or ((T >= 0) and (D >= 0)))
        else
          Result := not (((T < 0) and (D < 0)) or ((T >= 0) and (D >= 0)));
      end;
  else
    { the other rules are no VAT total rules }
    ;
  end;
end;

function PeriodWritten(AStart, AEnd: TDateTime): Boolean;
begin
  Result := (PeriodDateSet(AStart) or PeriodDateSet(AEnd)) and not PeriodReversed(AStart, AEnd);
end;

{ The Peppol line rules for one line, on the values as written: R046 net
  price = gross price - discount (exact, when the gross price is written);
  R110, R111 the line period within the invoice period (dates as written:
  a reversed period is left out); R120 line net amount = quantity x (net
  price div base quantity) + charges - allowances within the slack (a
  missing or zero base quantity counts as 1); R121 base quantity above 0;
  R130 the unit of the base quantity is that of the invoiced quantity.
  DE: Die Peppol-Positionsregeln fuer eine Position, auf den geschriebenen
  Werten: R046 Nettopreis = Bruttopreis - Rabatt (exakt, wenn der
  Bruttopreis geschrieben wird); R110, R111 der Positionszeitraum innerhalb
  des Rechnungszeitraums (Daten wie geschrieben: ein umgekehrter Zeitraum
  entfaellt); R120 Positionsnettobetrag = Menge x (Nettopreis div
  Basismenge) + Zuschlaege - Nachlaesse innerhalb der Toleranz (eine
  fehlende oder 0-Basismenge zaehlt als 1); R121 Basismenge ueber 0; R130
  die Einheit der Basismenge ist die der Menge. }
function PeppolLineViolated(AIndex: TCheckRuleIndex; AInvoice: TLandrixInvoice; ALine: TLandrixInvoiceLine;
  const ASlack: TExact; const APath: TLandrixEInvoiceString; var ADetail: TRuleDetail): Boolean;
var
  I: TLandrixEInvoiceListIndex;
  Base, Allowances, Charges, Value, Quantity: TExact;
  BaseUnit: TLandrixEInvoiceString;
begin
  Result := False;
  case AIndex of
    cr_PeppolR046:
      if ALine.GrossPriceAmount <> 0 then
      begin
        Value := ExactSub(PriceExact(ALine.GrossPriceAmount), PriceExact(ALine.DiscountOnTheGrossPrice));
        Result := ExactCompare(PriceExact(ALine.NetPriceAmount), Value) <> 0;
        if Result then
          SetDetail(ADetail, APath + '.NetPriceAmount', ExactText(Value, 2),
            LandrixEInvoicePriceToLexical(Writable(ALine.NetPriceAmount)), 'item gross price (BT-148) ' +
            ExactText(PriceExact(ALine.GrossPriceAmount), 2) + ' - item price discount (BT-147) ' +
            ExactText(PriceExact(ALine.DiscountOnTheGrossPrice), 2));
      end;
    cr_PeppolR110:
      Result := PeriodWritten(AInvoice.InvoicePeriodStartDate, AInvoice.InvoicePeriodEndDate) and
        PeriodDateSet(AInvoice.InvoicePeriodStartDate) and
        PeriodWritten(ALine.InvoiceLinePeriodStartDate, ALine.InvoiceLinePeriodEndDate) and
        PeriodDateSet(ALine.InvoiceLinePeriodStartDate) and
        (WrittenDay(ALine.InvoiceLinePeriodStartDate) < WrittenDay(AInvoice.InvoicePeriodStartDate));
    cr_PeppolR111:
      Result := PeriodWritten(AInvoice.InvoicePeriodStartDate, AInvoice.InvoicePeriodEndDate) and
        PeriodDateSet(AInvoice.InvoicePeriodEndDate) and
        PeriodWritten(ALine.InvoiceLinePeriodStartDate, ALine.InvoiceLinePeriodEndDate) and
        PeriodDateSet(ALine.InvoiceLinePeriodEndDate) and
        (WrittenDay(ALine.InvoiceLinePeriodEndDate) > WrittenDay(AInvoice.InvoicePeriodEndDate));
    cr_PeppolR120XR, cr_PeppolR120BIS:
      begin
        Base := ExactOf('1');
        if ALine.BaseQuantity <> 0 then
        begin
          Value := ExactOf(LandrixEInvoiceBaseQuantityToLexical(Writable(ALine.BaseQuantity)));
          if Length(Value.Digits) > 0 then
            Base := Value;
        end;
        Allowances := ExactOf('0');
        Charges := Allowances;
        for I := 0 to ALine.AllowanceCharges.Count - 1 do
          if ALine.AllowanceCharges[I].ChargeIndicator then
            Charges := ExactAdd(Charges, AmountExact(ALine.AllowanceCharges[I].Amount))
          else
            Allowances := ExactAdd(Allowances, AmountExact(ALine.AllowanceCharges[I].Amount));
        Quantity := ExactOf(LandrixEInvoiceQuantityToLexical(Writable(ALine.Quantity)));
        Value := ExactSub(ExactAdd(ExactMul(Quantity, ExactDiv(PriceExact(ALine.NetPriceAmount), Base)), Charges),
          Allowances);
        Result := not WithinSlack(AmountExact(ALine.LineAmount), Value, ASlack);
        if Result then
          SetDetail(ADetail, APath + '.LineAmount', ExactText(Value, 2), LandrixEInvoiceAmountToLexical(ALine.LineAmount),
            'invoiced quantity (BT-129) ' + ExactText(Quantity, 0) + ' x (item net price (BT-146) ' +
            ExactText(PriceExact(ALine.NetPriceAmount), 2) + ' / item price base quantity (BT-149) ' +
            ExactText(Base, 0) + ') + line charges (BT-141) ' + ExactText(Charges, 2) + ' - line allowances (BT-136) ' +
            ExactText(Allowances, 2) + '; the difference may be up to ' + ExactText(ASlack, 2));
      end;
    cr_PeppolR121:
      Result := (ALine.BaseQuantity <> 0) and
        (ExactCompare(ExactOf(LandrixEInvoiceBaseQuantityToLexical(Writable(ALine.BaseQuantity))), ExactOf('0')) <= 0);
    cr_PeppolR130:
      begin
        BaseUnit := WrittenCode(LandrixEInvoiceUnitCodeToStr(ALine.BaseQuantityUnitCode),
          ALine.BaseQuantityUnitCodeOther);
        Result := (ALine.BaseQuantity <> 0) and (BaseUnit <> '') and
          (BaseUnit <> WrittenCode(LandrixEInvoiceUnitCodeToStr(ALine.UnitCode), ALine.UnitCodeOther));
      end;
  else
    { the other rules are no Peppol line rules }
    ;
  end;
  if not Result then
    Exit;
  case AIndex of
    cr_PeppolR110:
      ADetail.Path := APath + '.InvoiceLinePeriodStartDate';
    cr_PeppolR111:
      ADetail.Path := APath + '.InvoiceLinePeriodEndDate';
    cr_PeppolR121:
      ADetail.Path := APath + '.BaseQuantity';
    cr_PeppolR130:
      if Present(LandrixEInvoiceUnitCodeToStr(ALine.BaseQuantityUnitCode)) then
        ADetail.Path := APath + '.BaseQuantityUnitCode'
      else
        ADetail.Path := APath + '.BaseQuantityUnitCodeOther';
  else
    { R046 and R120 set their details above }
    ;
  end;
end;

function AnyPeppolLineViolated(AIndex: TCheckRuleIndex; AInvoice: TLandrixInvoice; ALines: TLandrixInvoiceLines;
  ASubLines: Boolean; const ASlack: TExact; const APath: TLandrixEInvoiceString; var ADetail: TRuleDetail): Boolean;
var
  I: TLandrixEInvoiceListIndex;
  Line: TLandrixEInvoiceString;
begin
  Result := True;
  for I := 0 to ALines.Count - 1 do
  begin
    Line := APath + '[' + TLandrixEInvoiceString(IntToStr(I)) + ']';
    if PeppolLineViolated(AIndex, AInvoice, ALines[I], ASlack, Line, ADetail) or
       (ASubLines and AnyPeppolLineViolated(AIndex, AInvoice, ALines[I].SubInvoiceLines, True, ASlack,
       Line + '.SubInvoiceLines', ADetail)) then
      Exit;
  end;
  Result := False;
end;

{ UBL checks R110, R111, R120 and R121 on cac:InvoiceLine only, R046 and
  R130 (context cac:Price) also on cac:SubInvoiceLine; CII checks every
  line. Sub lines count only where they are written.
  DE: UBL prueft R110, R111, R120 und R121 nur an cac:InvoiceLine, R046
  und R130 (Kontext cac:Price) auch an cac:SubInvoiceLine; CII prueft jede
  Position. Unterpositionen zaehlen nur, wo sie geschrieben werden. }
function PeppolLinesViolated(AIndex: TCheckRuleIndex; AInvoice: TLandrixInvoice;
  const ASpec: TLandrixEInvoiceSpec; var ADetail: TRuleDetail): Boolean;
begin
  Result := AnyPeppolLineViolated(AIndex, AInvoice, AInvoice.InvoiceLines, SubLinesWritten(AInvoice, ASpec) and
    ((ASpec.Target.Syntax = esy_CII) or (AIndex in [cr_PeppolR046, cr_PeppolR130])), PeppolSlack(AInvoice, ASpec),
    'InvoiceLines', ADetail);
end;

{ Whether rule AIndex is violated; ADetail gets what the rule reports
  beside that (only where it is violated).
  DE: Ob die Regel AIndex verletzt ist; ADetail erhaelt, was die Regel
  daneben meldet (nur bei einem Verstoss). }
function Violated(AIndex: TCheckRuleIndex; AInvoice: TLandrixInvoice; const ASpec: TLandrixEInvoiceSpec;
  var ADetail: TRuleDetail): Boolean;
var
  NoDefaultEM, IsPeppol: Boolean;
  Seller, Buyer: TLandrixInvoiceAccountingParty;
  TaxRepresentative: TLandrixInvoiceParty;
  Delivery: TLandrixInvoiceAddress;
begin
  Result := False;
  Seller := AInvoice.AccountingSupplierParty;
  Buyer := AInvoice.AccountingCustomerParty;
  TaxRepresentative := AInvoice.TaxRepresentativeParty;
  Delivery := AInvoice.DeliveryInformation.Address;
  case AIndex of
    cr_LXCC01:
      Result := AInvoice.PaymentTypes.Count = 0;
    cr_LXCC02:
      Result := AInvoice.InvoiceTypeCode in [itc_DebitnoteRelatedToFinancialAdjustments, itc_SelfBilledCreditNote,
        itc_DebitNote, itc_PrepaymentInvoice, itc_Cancellation];
    cr_LXCC03:
      Result := (AInvoice.PrecedingInvoiceReferences.Count > 1) and
        Forbidden(ASpec, LandrixEInvoiceRuleMultiplePrecedingInvoices);
    cr_LXCC04:
      Result := CountPayments(AInvoice, ipmc_SEPADirectDebit) > 1;
    cr_LXCC05:
      Result := CountPayments(AInvoice, ipmc_CreditCard) > 1;
    cr_LXCC06:
      Result := not Present(Seller.VATCompanyID) and not Present(Seller.CompanyID);
    cr_LXCC07:
      Result := not Present(Seller.VATCompanyID) and not Present(Seller.VATCompanyNumber);
    cr_LXCC08:
      Result := (AInvoice.PrepaidPayments.Count > 0) and
        (not ASpec.CanWrite or Forbidden(ASpec, LandrixEInvoiceRuleThirdPartyPayments));
    cr_LXCC09:
      begin
        NoDefaultEM := Forbidden(ASpec, LandrixEInvoiceRuleElectronicAddressDefaultEM);
        IsPeppol := ASpec.Target.Standard = est_PeppolBIS;
        Result := BadElectronicAddress(Seller, IsPeppol, NoDefaultEM) or
          BadElectronicAddress(Buyer, IsPeppol, NoDefaultEM);
      end;
    cr_LXCC10:
      Result := HasLineDeliveryData(AInvoice.InvoiceLines) and
        (not ASpec.CanWrite or Forbidden(ASpec, LandrixEInvoiceRuleLineDelivery));
    cr_LXCC11:
      Result := not IsFacturXExtended(ASpec) and (HasInformationLines(AInvoice.InvoiceLines) or
        HasDetailWithSubInvoiceLines(AInvoice.InvoiceLines));
    cr_LXCC12, cr_BRFXEXT08:
      Result := HasGroupAmountMismatch(AInvoice.InvoiceLines, False);
    cr_BRDEX14:
      Result := ThirdPartyCurrencyWrong(AInvoice, ASpec);
    cr_BR02:
      Result := not Present(AInvoice.InvoiceNumber);
    cr_BR03:
      Result := AInvoice.InvoiceIssueDate <= 0;
    cr_BR04:
      Result := (AInvoice.InvoiceTypeCode = itc_None) and not Present(AInvoice.InvoiceTypeCodeOther);
    cr_BR05:
      Result := not Present(AInvoice.InvoiceCurrencyCode);
    cr_BR06:
      Result := not Present(Seller.RegistrationName);
    cr_BR07:
      Result := not Present(Buyer.RegistrationName);
    cr_BR08:
      Result := not AddressSet(Seller.Address);
    cr_BR09:
      Result := not Present(Seller.Address.CountryCode);
    cr_BR10:
      Result := not AddressSet(Buyer.Address);
    cr_BR11:
      Result := not Present(Buyer.Address.CountryCode);
    cr_BR16:
      Result := AInvoice.InvoiceLines.Count = 0;
    cr_BR17:
      Result := PayeeViolated(AInvoice, ASpec);
    cr_BR18:
      Result := PartySet(TaxRepresentative) and not Present(TaxRepresentative.Name);
    cr_BR19:
      Result := PartySet(TaxRepresentative) and not AddressSet(TaxRepresentative.Address);
    cr_BR20:
      Result := AddressSet(TaxRepresentative.Address) and not Present(TaxRepresentative.Address.CountryCode);
    { CII writes sub lines as lines, every line rule sees them; in UBL only
      BR-54 (context //cac:AdditionalItemProperty) reaches cac:SubInvoiceLine,
      the other contexts are cac:InvoiceLine and cac:CreditNoteLine
      DE: CII schreibt Unterpositionen als Positionen, jede Positionsregel
      sieht sie; in UBL erreicht nur BR-54 (Kontext
      //cac:AdditionalItemProperty) cac:SubInvoiceLine, die anderen
      Kontexte sind cac:InvoiceLine und cac:CreditNoteLine }
    cr_BR54:
      Result := AnyLineViolated(AIndex, AInvoice.InvoiceLines, True);
    cr_BR21, cr_BR23, cr_BR25, cr_BR27, cr_BR28, cr_BR30, cr_BR42, cr_BR44, cr_BR64, cr_BR65:
      Result := AnyLineViolated(AIndex, AInvoice.InvoiceLines, ASpec.Target.Syntax = esy_CII);
    cr_BR29:
      Result := PeriodReversed(AInvoice.InvoicePeriodStartDate, AInvoice.InvoicePeriodEndDate);
    cr_BR32, cr_BR33:
      Result := AllowanceChargeViolated(AIndex, AInvoice, False);
    cr_BR37, cr_BR38:
      Result := AllowanceChargeViolated(AIndex, AInvoice, True);
    cr_BR47:
      Result := TaxCategoryMissing(AInvoice);
    cr_BR51UBL, cr_BR51CII, cr_BRDE19, cr_BRDE20:
      Result := PaymentFormatViolated(AIndex, AInvoice, ASpec);
    cr_BR52:
      Result := BG24IDMissing(AInvoice);
    cr_BR53, cr_BRDEC15:
      Result := Present(AInvoice.TaxCurrencyCode) and (AInvoice.TaxCurrencyCode <> AInvoice.InvoiceCurrencyCode) and
        not AInvoice.TaxAmountTotalInTaxCurrency.HasValue;
    cr_BR55:
      Result := PrecedingIDMissing(AInvoice);
    cr_BR56:
      Result := PartySet(TaxRepresentative) and not Present(TaxRepresentative.VATCompanyID);
    cr_BR57:
      Result := AddressSet(Delivery) and not Present(Delivery.CountryCode);
    cr_BR61, cr_BRDE23a:
      Result := HasPayment(AInvoice, pk_CreditTransferWithoutAccount);
    cr_BR62:
      Result := Present(Seller.ElectronicAddressSellerBuyer) and
        not Present(Seller.ElectronicAddressSellerBuyerSchemeID) and
        Forbidden(ASpec, LandrixEInvoiceRuleElectronicAddressDefaultEM);
    cr_BR63:
      Result := Present(Buyer.ElectronicAddressSellerBuyer) and
        not Present(Buyer.ElectronicAddressSellerBuyerSchemeID) and
        Forbidden(ASpec, LandrixEInvoiceRuleElectronicAddressDefaultEM);
    cr_BRB01, cr_BRB02:
      Result := SplitPaymentViolated(AIndex, AInvoice, ASpec);
    { BR-CO-03 on the model: the mappers leave BT-8 out next to BT-7 }
    cr_BRCO03:
      Result := AInvoice.TaxPointDate.HasValue and Present(AInvoice.TaxPointDateCode);
    cr_BRCO04:
      Result := LineTaxCategoryMissing(AInvoice);
    cr_BRCO09:
      Result := VATPrefixWrong(Seller.VATCompanyID, ASpec) or VATPrefixWrong(Buyer.VATCompanyID, ASpec) or
        VATPrefixWrong(TaxRepresentative.VATCompanyID, ASpec) or
        (CIIInvoiceeWritten(AInvoice, ASpec) and VATPrefixWrong(AInvoice.InvoiceeParty.VATCompanyID, ASpec)) or
        (CIIPayeeFull(AInvoice, ASpec) and VATPrefixWrong(AInvoice.PayeeParty.VATCompanyID, ASpec));
    cr_BRCO18:
      Result := BreakdownMissing(AInvoice, ASpec);
    { BR-CO-21 to 24 repeat BR-33, BR-38, BR-42 and BR-44. DE: BR-CO-21 bis
      24 wiederholen BR-33, BR-38, BR-42 und BR-44. }
    cr_BRCO21:
      Result := AllowanceChargeViolated(cr_BR33, AInvoice, False);
    cr_BRCO22:
      Result := AllowanceChargeViolated(cr_BR38, AInvoice, True);
    cr_BRCO23:
      Result := AnyLineViolated(cr_BR42, AInvoice.InvoiceLines, ASpec.Target.Syntax = esy_CII);
    cr_BRCO24:
      Result := AnyLineViolated(cr_BR44, AInvoice.InvoiceLines, ASpec.Target.Syntax = esy_CII);
    cr_BRCO25:
      Result := PaymentTermsMissing(AInvoice);
    cr_BRCO26:
      Result := SellerIdentifierMissing(Seller, ASpec);
    cr_BRFXEXTCO04:
      Result := DetailTaxCategoryMissing(AInvoice.InvoiceLines, False);
    cr_BRDE01:
      Result := not HasPayment(AInvoice, pk_Written);
    cr_BRDE02:
      Result := not ContactSet(Seller);
    cr_BRDE03:
      Result := not Present(Seller.Address.City);
    cr_BRDE04:
      Result := not Present(Seller.Address.PostalZone);
    cr_BRDE05:
      Result := ContactSet(Seller) and not Present(Seller.ContactName) and not Present(Seller.ContactDepartment);
    cr_BRDE06:
      Result := ContactSet(Seller) and not Present(Seller.ContactTelephone);
    cr_BRDE07:
      Result := ContactSet(Seller) and not Present(Seller.ContactElectronicMail);
    cr_BRDE08:
      Result := not Present(Buyer.Address.City);
    cr_BRDE09:
      Result := not Present(Buyer.Address.PostalZone);
    cr_BRDE10:
      Result := AddressSet(Delivery) and not Present(Delivery.City);
    cr_BRDE11:
      Result := AddressSet(Delivery) and not Present(Delivery.PostalZone);
    cr_BRDE15:
      Result := not Present(AInvoice.BuyerReference);
    cr_BRDE16:
      Result := UsesRegisteredCategory(AInvoice, ASpec.Target.Syntax = esy_UBL) and not Present(Seller.VATCompanyID) and
        not Present(Seller.VATCompanyNumber) and not PartySet(TaxRepresentative);
    cr_BRDE17:
      Result := not TypeCodeSupported(AInvoice);
    cr_UBLSR29:
      Result := SEPAIdentifierCount(AInvoice) > 1;
    cr_CIISR467, cr_CIISR468, cr_UBLSR47, cr_UBLSR54, cr_UBLSR55:
      Result := PaymentMeansMixed(AIndex, AInvoice);
    { BR-DE-18: the lines as written; the second part of the test (a line
      break after the last cash discount line) always holds, as the text
      ends every line with LF and replaces # in the free text.
      DE: BR-DE-18: die Zeilen, wie sie geschrieben werden; der zweite Teil
      des Tests (ein Zeilenumbruch nach der letzten Skontozeile) gilt immer,
      da der Text jede Zeile mit LF abschliesst und # im freien Text
      ersetzt. }
    cr_BRDE18:
      Result := not LandrixEInvoiceCashDiscountTextValid(TermsText(AInvoice));
    cr_BRDE22:
      Result := DuplicateFilename(AInvoice, ASpec);
    cr_BRTMP2:
      Result := ExternalLocationWrong(AInvoice, ASpec);
    cr_BRDE23b:
      Result := HasPayment(AInvoice, pk_CreditTransfer) and
        (Present(AInvoice.PaymentMandateID) or Present(Seller.BankAssignedCreditorIdentifier));
    cr_BRDE24a:
      Result := HasPayment(AInvoice, pk_CardWithoutAccount);
    cr_BRDE24b:
      Result := HasPayment(AInvoice, pk_Card) and
        (Present(AInvoice.PaymentMandateID) or Present(Seller.BankAssignedCreditorIdentifier));
    cr_BRDE25a:
      Result := HasPayment(AInvoice, pk_SEPADirectDebitWithoutAccount) and not Present(AInvoice.PaymentMandateID) and
        ((ASpec.Target.Syntax = esy_UBL) or not Present(Seller.BankAssignedCreditorIdentifier));
    cr_BRDE25b:
      Result := HasPayment(AInvoice, pk_SEPADirectDebitWithBIC);
    cr_BRDE26:
      Result := (NormalizedSpace(WrittenCode(LandrixEInvoiceTypeCodeToStr(AInvoice.InvoiceTypeCode),
        AInvoice.InvoiceTypeCodeOther)) = '384') and not HasPrecedingID(AInvoice);
    cr_BRDE27:
      Result := ContactSet(Seller) and not LandrixEInvoiceTelephoneValid(Seller.ContactTelephone);
    cr_BRDE28:
      Result := ContactSet(Seller) and not LandrixEInvoiceEmailValid(Seller.ContactElectronicMail);
    cr_BRDE30, cr_BRDE31:
      Result := DirectDebitViolated(AIndex, AInvoice, ASpec);
    { the UBL mapper writes a sales order alone with the order 'NA' (BT-13)
      DE: der UBL-Mapper schreibt einen Auftrag allein mit der Bestellung
      'NA' (BT-13) }
    cr_PeppolR003:
      Result := not Present(AInvoice.BuyerReference) and not Present(AInvoice.PurchaseOrderReference) and
        not Present(AInvoice.SellerOrderReference);
    cr_PeppolR010:
      Result := not Present(Buyer.ElectronicAddressSellerBuyer);
    cr_PeppolR020:
      Result := not Present(Seller.ElectronicAddressSellerBuyer);
    cr_PeppolR061:
      Result := HasPayment(AInvoice, pk_DirectDebit) and not Present(AInvoice.PaymentMandateID);
    cr_PeppolR005:
      Result := TaxCurrencyWritten(AInvoice) and
        (NormalizedSpace(AInvoice.TaxCurrencyCode) = NormalizedSpace(AInvoice.InvoiceCurrencyCode));
    cr_PeppolR040, cr_PeppolR041, cr_PeppolR042:
      Result := PeppolAllowancesViolated(AIndex, AInvoice, ASpec, ADetail);
    cr_PeppolR053, cr_PeppolR054, cr_PeppolR055:
      Result := PeppolTaxTotalViolated(AIndex, AInvoice, ASpec);
    cr_PeppolR046, cr_PeppolR110, cr_PeppolR111, cr_PeppolR120XR, cr_PeppolR120BIS, cr_PeppolR121, cr_PeppolR130:
      Result := PeppolLinesViolated(AIndex, AInvoice, ASpec, ADetail);
    cr_BRCO10, cr_BRCO11, cr_BRCO12, cr_BRCO13, cr_BRCO14, cr_BRCO15, cr_BRCO16, cr_BRCO17,
    cr_BRFXEXTCO10, cr_BRFXEXTCO11, cr_BRFXEXTCO12, cr_BRFXEXTCO13, cr_BRFXEXTCO15, cr_BRFXEXTCO16,
    cr_BRDEX09:
      Result := CalculationViolated(AIndex, AInvoice, ASpec, ADetail);
    cr_BRCL01..cr_BRDEX08:
      Result := CodeListViolated(AIndex, AInvoice, ASpec);
  end;
end;

{ --- numbers and dates no writer can write -------------------------------------- }

type
  { What the walk found. DE: Was der Durchgang gefunden hat. }
  TUnwritable = record
    Count: Integer;
    NaN: Boolean;
  end;

procedure ReportNumber(AValue: Double; const ATerms: string; const AWhat: TLandrixEInvoiceString;
  ADiagnostics: TLandrixEInvoiceDiagnostics; var AFound: TUnwritable);
var
  D: TLandrixEInvoiceDiagnostic;
begin
  if NumberWritable(AValue) then
    Exit;
  Inc(AFound.Count);
  if IsNaN(AValue) then
    AFound.NaN := True;
  if ADiagnostics = nil then
    Exit;
  D := ADiagnostics.AddDiagnostic(edk_ConversionFailed, '', 0, 0, 0,
    AWhat + ' cannot be written (NaN, infinite or 1e23 and above); the rules that cannot judge it are skipped');
  D.Severity := eds_Error;
  D.Terms := TLandrixEInvoiceString(ATerms);
end;

{ The percentage of each allowance or charge, and its rate on document
  level except for category O (the line level has no rate in the syntaxes).
  DE: Der Prozentsatz jedes Nachlasses oder Zuschlags und sein Satz auf
  Dokumentebene ausser bei Kategorie O (die Positionsebene hat in den
  Syntaxen keinen Satz). }
procedure ReportAllowanceNumbers(AItems: TLandrixInvoiceAllowanceCharges; AOnLine: Boolean;
  const AWhere: TLandrixEInvoiceString; ADiagnostics: TLandrixEInvoiceDiagnostics; var AFound: TUnwritable);
var
  I: TLandrixEInvoiceListIndex;
  Item: TLandrixInvoiceAllowanceCharge;
  Kind: TLandrixEInvoiceString;
  Terms: string;
begin
  for I := 0 to AItems.Count - 1 do
  begin
    Item := AItems[I];
    if Item.ChargeIndicator then
    begin
      Kind := 'charge';
      if AOnLine then
        Terms := 'BT-143'
      else
        Terms := 'BT-101';
    end
    else
    begin
      Kind := 'allowance';
      if AOnLine then
        Terms := 'BT-138'
      else
        Terms := 'BT-94';
    end;
    ReportNumber(Item.MultiplierFactorNumeric, Terms, 'The percentage of ' + Kind + ' ' +
      TLandrixEInvoiceString(IntToStr(I + 1)) + AWhere, ADiagnostics, AFound);
    if AOnLine or (Item.TaxCategory = idtfcc_O_ServicesOutsideScopeOfTax) then
      Continue;
    if Item.ChargeIndicator then
      Terms := 'BT-103'
    else
      Terms := 'BT-96';
    ReportNumber(Item.TaxPercent, Terms, 'The VAT rate of ' + Kind + ' ' + TLandrixEInvoiceString(IntToStr(I + 1)) +
      AWhere, ADiagnostics, AFound);
  end;
end;

procedure ReportLineNumbers(ALines: TLandrixInvoiceLines; ADiagnostics: TLandrixEInvoiceDiagnostics;
  var AFound: TUnwritable);
var
  I: TLandrixEInvoiceListIndex;
  Line: TLandrixInvoiceLine;
  Where: TLandrixEInvoiceString;
begin
  for I := 0 to ALines.Count - 1 do
  begin
    Line := ALines[I];
    Where := ' of invoice line ''' + Line.ID + '''';
    ReportNumber(Line.Quantity, 'BT-129', 'The quantity' + Where, ADiagnostics, AFound);
    { category O: no rate written. DE: Kategorie O: kein Satz geschrieben. }
    if Line.TaxCategory <> idtfcc_O_ServicesOutsideScopeOfTax then
      ReportNumber(Line.TaxPercent, 'BT-152', 'The VAT rate' + Where, ADiagnostics, AFound);
    ReportNumber(Line.GrossPriceAmount, 'BT-148', 'The gross price' + Where, ADiagnostics, AFound);
    { the discount only with a gross price, as the writers
      DE: der Rabatt nur mit Bruttopreis, wie bei den Writern }
    if not IsNaN(Line.GrossPriceAmount) and (Line.GrossPriceAmount <> 0) then
      ReportNumber(Line.DiscountOnTheGrossPrice, 'BT-147', 'The price discount' + Where, ADiagnostics, AFound);
    ReportNumber(Line.NetPriceAmount, 'BT-146', 'The net price' + Where, ADiagnostics, AFound);
    ReportNumber(Line.BaseQuantity, 'BT-149', 'The price base quantity' + Where, ADiagnostics, AFound);
    ReportAllowanceNumbers(Line.AllowanceCharges, True, Where, ADiagnostics, AFound);
    ReportLineNumbers(Line.SubInvoiceLines, ADiagnostics, AFound);
  end;
end;

{ A date the writers cannot format: a NaN always (whether the writers
  write it differs between compilers), otherwise when it is written (a
  plain date above 0, an optional one with AHasValue) and outside
  0001-9999.
  DE: Ein Datum, das die Writer nicht formatieren koennen: NaN immer (ob
  die Writer es schreiben, faellt je Compiler anders aus), sonst wenn es
  geschrieben wird (ein einfaches Datum ueber 0, ein optionales mit
  AHasValue) und ausserhalb 0001-9999 liegt. }
procedure ReportDate(AValue: TDateTime; AHasValue: Boolean; const ATerms: string; const AWhat: TLandrixEInvoiceString;
  ADiagnostics: TLandrixEInvoiceDiagnostics; var AFound: TUnwritable);
var
  D: TLandrixEInvoiceDiagnostic;
begin
  if IsNaN(AValue) then
    AFound.NaN := True
  else if DateWritable(AValue) or (not AHasValue and (AValue <= 0)) then
    Exit;
  Inc(AFound.Count);
  if ADiagnostics = nil then
    Exit;
  D := ADiagnostics.AddDiagnostic(edk_ConversionFailed, '', 0, 0, 0,
    AWhat + ' cannot be written (NaN or outside 0001-9999); the rules that cannot judge it are skipped');
  D.Severity := eds_Error;
  D.Terms := TLandrixEInvoiceString(ATerms);
end;

{ The dates of the lines and sub lines; a delivery note date only with its
  number (or NaN), as the writers.
  DE: Die Daten der Positionen und Unterpositionen; ein Lieferscheindatum
  nur mit seiner Nummer (oder NaN), wie bei den Writern. }
procedure ReportLineDates(ALines: TLandrixInvoiceLines; ADiagnostics: TLandrixEInvoiceDiagnostics;
  var AFound: TUnwritable);
var
  I: TLandrixEInvoiceListIndex;
  Line: TLandrixInvoiceLine;
  Where: TLandrixEInvoiceString;
begin
  for I := 0 to ALines.Count - 1 do
  begin
    Line := ALines[I];
    Where := ' of invoice line ''' + Line.ID + '''';
    if Line.OrderDate.HasValue then
      ReportDate(Line.OrderDate.Value, True, 'BT-X-22', 'The order date' + Where, ADiagnostics, AFound);
    ReportDate(Line.InvoiceLinePeriodStartDate, False, 'BT-134', 'The period start' + Where, ADiagnostics, AFound);
    ReportDate(Line.InvoiceLinePeriodEndDate, False, 'BT-135', 'The period end' + Where, ADiagnostics, AFound);
    if Present(Line.DeliveryNoteNumber) or IsNaN(Line.DeliveryNoteDate) then
      ReportDate(Line.DeliveryNoteDate, False, 'BT-X-94', 'The delivery note date' + Where, ADiagnostics, AFound);
    ReportDate(Line.ActualDeliveryDate, False, 'BT-X-85', 'The delivery date' + Where, ADiagnostics, AFound);
    ReportLineDates(Line.SubInvoiceLines, ADiagnostics, AFound);
  end;
end;

{ Every date of AInvoice the writers cannot format (ReportDate); the date
  of a despatch advice or delivery note only with its number (or NaN), as
  the writers.
  DE: Jedes Datum von AInvoice, das die Writer nicht formatieren koennen
  (ReportDate); das Datum einer Versandanzeige oder eines Lieferscheins
  nur mit seiner Nummer (oder NaN), wie bei den Writern. }
procedure ReportUnwritableDates(AInvoice: TLandrixInvoice; ADiagnostics: TLandrixEInvoiceDiagnostics;
  var AFound: TUnwritable);
var
  I: TLandrixEInvoiceListIndex;
begin
  ReportDate(AInvoice.InvoiceIssueDate, False, 'BT-2', 'The invoice date', ADiagnostics, AFound);
  ReportDate(AInvoice.InvoiceDueDate, False, 'BT-9', 'The due date', ADiagnostics, AFound);
  if AInvoice.TaxPointDate.HasValue then
    ReportDate(AInvoice.TaxPointDate.Value, True, 'BT-7', 'The VAT point date', ADiagnostics, AFound);
  ReportDate(AInvoice.InvoicePeriodStartDate, False, 'BT-73', 'The invoicing period start', ADiagnostics, AFound);
  ReportDate(AInvoice.InvoicePeriodEndDate, False, 'BT-74', 'The invoicing period end', ADiagnostics, AFound);
  ReportDate(AInvoice.DeliveryInformation.ActualDeliveryDate, False, 'BT-72', 'The actual delivery date',
    ADiagnostics, AFound);
  for I := 0 to AInvoice.PrecedingInvoiceReferences.Count - 1 do
    ReportDate(AInvoice.PrecedingInvoiceReferences[I].IssueDate, False, 'BT-26', 'The issue date of preceding ' +
      'invoice ' + TLandrixEInvoiceString(IntToStr(I + 1)), ADiagnostics, AFound);
  if AInvoice.SellerOrderReferenceDate.HasValue then
    ReportDate(AInvoice.SellerOrderReferenceDate.Value, True, 'BT-X-146', 'The sales order date', ADiagnostics,
      AFound);
  if AInvoice.PurchaseOrderReferenceDate.HasValue then
    ReportDate(AInvoice.PurchaseOrderReferenceDate.Value, True, 'BT-X-147', 'The purchase order date',
      ADiagnostics, AFound);
  if Present(AInvoice.DeliveryReceiptNumber) or IsNaN(AInvoice.DeliveryReceiptDate) then
    ReportDate(AInvoice.DeliveryReceiptDate, False, 'BT-X-200', 'The despatch advice date', ADiagnostics, AFound);
  if Present(AInvoice.DeliveryReceiptNumberExtended) or IsNaN(AInvoice.DeliveryReceiptDateExtended) then
    ReportDate(AInvoice.DeliveryReceiptDateExtended, False, 'BT-X-203', 'The delivery note date', ADiagnostics,
      AFound);
  ReportLineDates(AInvoice.InvoiceLines, ADiagnostics, AFound);
end;

{ Reports every number and date of AInvoice that the writers write but
  cannot format (one edk_ConversionFailed error each). A cash discount
  level counts up to the level of PaymentTermsType.
  DE: Meldet jede Zahl und jedes Datum von AInvoice, die die Writer
  schreiben, aber nicht formatieren koennen (je ein Fehler
  edk_ConversionFailed). Eine Skontostufe zaehlt bis zur Stufe von
  PaymentTermsType. }
function ReportUnwritableValues(AInvoice: TLandrixInvoice; ADiagnostics: TLandrixEInvoiceDiagnostics): TUnwritable;
var
  I: TLandrixEInvoiceListIndex;
begin
  Result.Count := 0;
  Result.NaN := False;
  ReportLineNumbers(AInvoice.InvoiceLines, ADiagnostics, Result);
  ReportAllowanceNumbers(AInvoice.AllowanceCharges, False, '', ADiagnostics, Result);
  for I := 0 to AInvoice.TaxAmountSubtotals.Count - 1 do
    ReportNumber(AInvoice.TaxAmountSubtotals[I].TaxPercent, 'BT-119', 'The VAT rate of VAT breakdown ' +
      TLandrixEInvoiceString(IntToStr(I + 1)), ADiagnostics, Result);
  if AInvoice.PaymentTermsType in [iptt_CashDiscount1, iptt_CashDiscount2, iptt_CashDiscount3] then
    ReportNumber(AInvoice.PaymentTermCashDiscount1Percent, 'BT-20', 'The percentage of cash discount 1',
      ADiagnostics, Result);
  if AInvoice.PaymentTermsType in [iptt_CashDiscount2, iptt_CashDiscount3] then
    ReportNumber(AInvoice.PaymentTermCashDiscount2Percent, 'BT-20', 'The percentage of cash discount 2',
      ADiagnostics, Result);
  if AInvoice.PaymentTermsType = iptt_CashDiscount3 then
    ReportNumber(AInvoice.PaymentTermCashDiscount3Percent, 'BT-20', 'The percentage of cash discount 3',
      ADiagnostics, Result);
  ReportUnwritableDates(AInvoice, ADiagnostics, Result);
end;

function AddViolation(ADiagnostics: TLandrixEInvoiceDiagnostics; const AID, ATerms, AMessage: string;
  ASeverity: TLandrixEInvoiceDiagnosticSeverity): TLandrixEInvoiceDiagnostic;
begin
  Result := nil;
  if ADiagnostics = nil then
    Exit;
  Result := ADiagnostics.AddDiagnostic(edk_RuleViolation, '', 0, 0, 0, TLandrixEInvoiceString(AMessage));
  Result.Severity := ASeverity;
  Result.RuleID := TLandrixEInvoiceString(AID);
  Result.Terms := TLandrixEInvoiceString(ATerms);
end;

{ Violated; a rule that cannot judge a number the writers cannot format
  holds (EUnwritableNumber).
  DE: Violated; eine Regel, die eine Zahl nicht beurteilen kann, die die
  Writer nicht formatieren koennen, gilt als erfuellt
  (EUnwritableNumber). }
function ViolatedWritable(AIndex: TCheckRuleIndex; AInvoice: TLandrixInvoice;
  const ASpec: TLandrixEInvoiceSpec; var ADetail: TRuleDetail): Boolean;
begin
  try
    Result := Violated(AIndex, AInvoice, ASpec, ADetail);
  except
    on EUnwritableNumber do
      Result := False;
  end;
end;

{ Runs rule AIndex if it applies; False and a diagnostic on a violation,
  with the details of the rule. AFlattened: AInvoice is the flat copy of
  the caller's invoice (sub lines the target does not write nested), so a
  model path into its lines would not fit the caller's invoice and is left
  out.
  DE: Fuehrt die Regel AIndex aus, wenn sie gilt; False und eine Meldung
  bei einem Verstoss, mit den Einzelheiten der Regel. AFlattened:
  AInvoice ist die flache Kopie der Rechnung des Aufrufers
  (Unterpositionen, die das Ziel nicht verschachtelt schreibt), ein
  Modellpfad in ihre Positionen passte nicht zur Rechnung des Aufrufers und
  entfaellt. }
function Run(AIndex: TCheckRuleIndex; AInvoice: TLandrixInvoice; const ASpec: TLandrixEInvoiceSpec;
  ADiagnostics: TLandrixEInvoiceDiagnostics; AFlattened: Boolean): Boolean;
var
  Detail: TRuleDetail;
  D: TLandrixEInvoiceDiagnostic;
begin
  Result := True;
  ClearDetail(Detail);
  if not Applies(CheckRows[AIndex], ASpec) or not ViolatedWritable(AIndex, AInvoice, ASpec, Detail) then
    Exit;
  Result := False;
  D := AddViolation(ADiagnostics, CheckRows[AIndex].ID, CheckRows[AIndex].Terms, CheckRows[AIndex].Message,
    CheckRows[AIndex].Severity);
  if D = nil then
    Exit;
  if not (AFlattened and (Copy(Detail.Path, 1, 12) = 'InvoiceLines')) then
    D.Path := Detail.Path;
  D.Expected := Detail.Expected;
  D.Found := Detail.Found;
  D.Calculation := Detail.Calculation;
end;

{ Runs VAT rule AGroup/ANumber (EN 16931 targets, the profiles of
  VatProfiles); False and an error on a violation.
  DE: Fuehrt die Steuerregel AGroup/ANumber aus (EN-16931-Ziele, die
  Profile aus VatProfiles); False und ein Fehler bei einem Verstoss. }
function RunVat(AGroup: TVatGroup; ANumber: Integer; AInvoice: TLandrixInvoice; const ASpec: TLandrixEInvoiceSpec;
  const ATaxUses: TTaxUses; ADiagnostics: TLandrixEInvoiceDiagnostics): Boolean;
var
  Terms, Message: string;
begin
  Result := True;
  if not (ASpec.Target.Standard in EN16931Standards) or not (ASpec.Target.Profile in VatProfiles(AGroup, ANumber)) or
     not VatViolated(AGroup, ANumber, AInvoice, ASpec, ATaxUses) then
    Exit;
  Result := False;
  VatRuleText(AGroup, ANumber, Terms, Message);
  AddViolation(ADiagnostics, VatRuleID(AGroup, ANumber), Terms, Message, eds_Error);
end;

{ Collects the VAT uses; False if a rate the writers cannot format stops
  it (EUnwritableNumber), then the VAT rules are skipped (they compare
  rates).
  DE: Sammelt die Steuerverwendungen; False, wenn ein Satz, den die Writer
  nicht formatieren koennen, das verhindert (EUnwritableNumber); dann
  entfallen die Steuerregeln (sie vergleichen Saetze). }
function TryCollectTaxUses(AInvoice: TLandrixInvoice; const ASpec: TLandrixEInvoiceSpec;
  out AUses: TTaxUses): Boolean;
begin
  Result := True;
  try
    CollectTaxUses(AInvoice, ASpec, AUses);
  except
    on EUnwritableNumber do
      Result := False;
  end;
end;

{ --- public -------------------------------------------------------------------- }

function LandrixEInvoiceCheckInvoice(AInvoice: TLandrixInvoice; const ASpec: TLandrixEInvoiceSpec;
  ADiagnostics: TLandrixEInvoiceDiagnostics): Integer;
var
  I: TCheckRuleIndex;
  G: TVatGroup;
  N: Integer;
  TaxUses: TTaxUses;
  Flat: TLandrixInvoice;
  Found: TUnwritable;
begin
  { checked as written: sub lines the target does not write nested are
    flat (the writer reports that)
    DE: geprueft wie geschrieben: Unterpositionen, die das Ziel nicht
    verschachtelt schreibt, sind flach (das meldet der Writer) }
  Flat := LandrixEInvoiceFlattenSubLines(AInvoice, ASpec, nil);
  try
    if Flat <> nil then
      AInvoice := Flat;
    { numbers and dates the writers write but cannot format: errors (only
      what is written: lines the flat copy leaves out do not count); the
      rules that cannot judge them hold, with a NaN no rule runs
      DE: Zahlen und Daten, die die Writer schreiben, aber nicht formatieren
      koennen: Fehler (nur was geschrieben wird: Positionen, die die flache
      Kopie weglaesst, zaehlen nicht); die Regeln, die sie nicht beurteilen
      koennen, gelten als erfuellt, bei NaN laeuft keine Regel }
    Found := ReportUnwritableValues(AInvoice, ADiagnostics);
    Result := Found.Count;
    if Found.NaN then
      Exit;
    for I := Low(TCheckRuleIndex) to High(TCheckRuleIndex) do
      if not CheckRows[I].Legacy and not Run(I, AInvoice, ASpec, ADiagnostics, Flat <> nil) and
         (CheckRows[I].Severity = eds_Error) then
        Inc(Result);
    if TryCollectTaxUses(AInvoice, ASpec, TaxUses) then
      for G := Low(TVatGroup) to High(TVatGroup) do
        for N := 0 to VatGroupLast[G] do
          if not RunVat(G, N, AInvoice, ASpec, TaxUses, ADiagnostics) then
            Inc(Result);
    Inc(Result, LandrixEInvoiceCheckPeppolInvoice(AInvoice, ASpec, ADiagnostics));
  finally
    Flat.Free;
  end;
end;

function LandrixEInvoiceCheckRule(AInvoice: TLandrixInvoice; const ASpec: TLandrixEInvoiceSpec;
  const ARuleID: TLandrixEInvoiceString; ADiagnostics: TLandrixEInvoiceDiagnostics): Boolean;
var
  I: TCheckRuleIndex;
  G: TVatGroup;
  N: Integer;
  TaxUses: TTaxUses;
  Found: Boolean;
  Flat, Written: TLandrixInvoice;
  Rows, LegacyRows: Integer;
  Unwritable: TUnwritable;
begin
  Result := True;
  Found := False;
  { the rules judge the invoice as written (flat where the target does not
    write sub lines nested); the LX-CC compatibility rules judge the
    structure the caller built and need no copy }
  Rows := 0;
  LegacyRows := 0;
  for I := Low(TCheckRuleIndex) to High(TCheckRuleIndex) do
    if TLandrixEInvoiceString(CheckRows[I].ID) = ARuleID then
    begin
      Inc(Rows);
      if CheckRows[I].Legacy then
        Inc(LegacyRows);
    end;
  Flat := nil;
  if (Rows = 0) or (LegacyRows < Rows) then
    Flat := LandrixEInvoiceFlattenSubLines(AInvoice, ASpec, nil);
  try
    Written := AInvoice;
    if Flat <> nil then
      Written := Flat;
    { as LandrixEInvoiceCheckInvoice: only what is written counts }
    Unwritable := ReportUnwritableValues(Written, nil);
    { an identifier can have one row per syntax or standard (BR-51, BR-CL-21) }
    for I := Low(TCheckRuleIndex) to High(TCheckRuleIndex) do
      if TLandrixEInvoiceString(CheckRows[I].ID) = ARuleID then
      begin
        Found := True;
        if Unwritable.NaN then
          Continue;
        if CheckRows[I].Legacy then
        begin
          if not Run(I, AInvoice, ASpec, ADiagnostics, False) then
            Result := False;
        end
        else if not Run(I, Written, ASpec, ADiagnostics, Flat <> nil) then
          Result := False;
      end;
    if Found then
      Exit;
    for G := Low(TVatGroup) to High(TVatGroup) do
      for N := 0 to VatGroupLast[G] do
        if TLandrixEInvoiceString(VatRuleID(G, N)) = ARuleID then
        begin
          if not Unwritable.NaN and TryCollectTaxUses(Written, ASpec, TaxUses) then
            Result := RunVat(G, N, Written, ASpec, TaxUses, ADiagnostics);
          Exit;
        end;
    Result := LandrixEInvoiceCheckPeppolRule(Written, ASpec, ARuleID, ADiagnostics, Unwritable.NaN,
      Found);
    if Found then
      Exit;
  finally
    Flat.Free;
  end;
  raise ELandrixEInvoiceError.Create('LandrixEInvoiceCheckRule: unknown rule ' + string(ARuleID));
end;

type
  TSyntaxModelKind = (smk_CII, smk_UBLInvoice, smk_UBLCreditNote);

{ Writes the model into a discarded buffer; the writer reports what is
  missing. DE: Schreibt das Modell in einen verworfenen Puffer; der Writer
  meldet, was fehlt. }
function CheckSyntaxModel(AKind: TSyntaxModelKind; AModel: TObject; const ASpec: TLandrixEInvoiceSpec;
  ADiagnostics: TLandrixEInvoiceDiagnostics): Integer;
var
  W: TLandrixXmlWriter;
  D, Own: TLandrixEInvoiceDiagnostics;
  I, Start: TLandrixEInvoiceListIndex;
begin
  if ((AKind = smk_CII) and (ASpec.Target.Syntax = esy_UBL)) or
     ((AKind <> smk_CII) and (ASpec.Target.Syntax = esy_CII)) then
    raise ELandrixEInvoiceError.Create('LandrixEInvoiceCheck: the syntax model does not match the ' +
      'specification ' + string(LandrixEInvoiceTargetToStr(ASpec.Target)));
  Own := nil;
  D := ADiagnostics;
  W := TLandrixXmlWriter.Create;
  try
    if D = nil then
    begin
      Own := TLandrixEInvoiceDiagnostics.Create;
      D := Own;
    end;
    Start := D.Count;
    case AKind of
      smk_CII:
        begin
          LandrixEInvoiceCheckCIIProfile(TLandrixCIIInvoice(AModel), ASpec.Target.Profile, D);
          LandrixEInvoiceCheckCIICodes(TLandrixCIIInvoice(AModel), ASpec.Target.Profile, D);
          LandrixEInvoiceWriteCII(TLandrixCIIInvoice(AModel), W, D, ASpec.Target.Profile);
        end;
      smk_UBLInvoice:
        LandrixEInvoiceWriteUBLInvoice(TLandrixUBLInvoice(AModel), W, D);
      smk_UBLCreditNote:
        LandrixEInvoiceWriteUBLCreditNote(TLandrixUBLCreditNote(AModel), W, D);
    end;
    Result := 0;
    for I := Start to D.Count - 1 do
      if D[I].Severity = eds_Error then
        Inc(Result);
  finally
    W.Free;
    Own.Free;
  end;
end;

function LandrixEInvoiceCheckCII(ACII: TLandrixCIIInvoice; const ASpec: TLandrixEInvoiceSpec;
  ADiagnostics: TLandrixEInvoiceDiagnostics): Integer;
begin
  Result := CheckSyntaxModel(smk_CII, ACII, ASpec, ADiagnostics);
end;

function LandrixEInvoiceCheckUBLInvoice(AUBL: TLandrixUBLInvoice; const ASpec: TLandrixEInvoiceSpec;
  ADiagnostics: TLandrixEInvoiceDiagnostics): Integer;
begin
  Result := CheckSyntaxModel(smk_UBLInvoice, AUBL, ASpec, ADiagnostics);
end;

function LandrixEInvoiceCheckUBLCreditNote(AUBL: TLandrixUBLCreditNote; const ASpec: TLandrixEInvoiceSpec;
  ADiagnostics: TLandrixEInvoiceDiagnostics): Integer;
begin
  Result := CheckSyntaxModel(smk_UBLCreditNote, AUBL, ASpec, ADiagnostics);
end;

end.
