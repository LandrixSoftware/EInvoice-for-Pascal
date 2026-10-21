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
  grows during phase 2 (plan, phase 2 step 4); a clean result means that
  the implemented rules hold, not that a validator will accept the output.

  The official rules judge the invoice as the mappers would write it to the
  target: blank text (LandrixEInvoiceIsBlank) is absent, a rule the mappers
  always meet has no row (BR-01, BR-12 to BR-15, BR-22, BR-24, BR-26,
  BR-31, BR-36, BR-41, BR-43, BR-45, BR-46, BR-48, BR-49, BR-50, BR-DE-14,
  BR-DE-18, BR-DE-21, PEPPOL-EN16931-R001), and where the syntaxes differ
  the row follows the validator of each syntax (e.g. BR-DE-23-b, BR-DE-30).
  The Factur-X profiles get the rules their schematron contains. BR-29,
  BR-30, BR-65 and BR-CO-03 are checked on the model: the mappers leave a reversed
  period or a classification without scheme out instead of writing it
  invalid, so the rule reports content that would be lost. The
  calculation rules BR-CO-10 to BR-CO-17 (Factur-X EXTENDED: BR-FXEXT-CO-10
  to 13, 15 and 16 with their tolerance, XRechnung UBL with third-party payments:
  BR-DEX-09) compare the amounts as they are written (two decimals). The
  VAT category rules BR-S-nn to BR-AG-nn (S, Z, E, AE, IC, G, O, AF, AG)
  have no rows: their identifiers come from the group and the number, and
  each follows the schematron of its syntax, which differ in context and
  tolerance; BR-B-01, BR-B-02, BR-CO-03, BR-CO-04, BR-CO-09 and BR-CO-18
  have rows. Code list and format rules (BR-DE-17, BR-DE-19, BR-DE-20,
  BR-DE-27, BR-DE-28, BR-51, BR-CO-05 to BR-CO-08, BR-CO-19 to
  BR-CO-26) and the BR-FXEXT-xx-01 of Factur-X EXTENDED are not part of this set yet.

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
  nie. Welche Regeln umgesetzt sind, waechst in Phase 2 (Fahrplan, Phase 2
  Schritt 4); ein Ergebnis ohne Meldung heisst, dass die umgesetzten Regeln
  erfuellt sind, nicht, dass ein Validator die Ausgabe annimmt.

  Die offiziellen Regeln beurteilen die Rechnung so, wie die Mapper sie in
  das Ziel schreiben wuerden: Text aus Leerraum (LandrixEInvoiceIsBlank)
  fehlt, eine Regel, die die Mapper immer erfuellen, hat keine Zeile
  (BR-01, BR-12 bis BR-15, BR-22, BR-24, BR-26, BR-31, BR-36, BR-41,
  BR-43, BR-45, BR-46, BR-48, BR-49, BR-50, BR-DE-14, BR-DE-18, BR-DE-21,
  PEPPOL-EN16931-R001), und wo die Syntaxen sich unterscheiden, folgt die
  Zeile dem Validator der jeweiligen Syntax (z. B. BR-DE-23-b, BR-DE-30).
  Die Factur-X-Profile bekommen die Regeln, die ihr Schematron enthaelt.
  BR-29, BR-30, BR-65 und BR-CO-03 werden am Modell geprueft: die Mapper lassen einen
  umgekehrten Zeitraum oder eine Klassifizierung ohne Schema weg, statt sie
  ungueltig zu schreiben; die Regel meldet also Inhalt, der verloren ginge.
  Die Rechenregeln BR-CO-10 bis BR-CO-17 (Factur-X EXTENDED: BR-FXEXT-CO-10
  bis 13, 15 und 16 mit ihrer Toleranz, XRechnung UBL mit Zahlungen Dritter:
  BR-DEX-09) vergleichen die Betraege so, wie sie geschrieben werden (zwei
  Nachkommastellen). Die Steuerkategorieregeln BR-S-nn bis BR-AG-nn (S, Z,
  E, AE, IC, G, O, AF, AG) haben keine Zeilen: ihre Kennungen ergeben sich
  aus Gruppe und Nummer, und jede folgt dem Schematron ihrer Syntax, die
  sich in Kontext und Toleranz unterscheiden; BR-B-01, BR-B-02, BR-CO-03,
  BR-CO-04, BR-CO-09 und BR-CO-18 haben Zeilen. Codelisten- und
  Formatregeln (BR-DE-17, BR-DE-19, BR-DE-20, BR-DE-27, BR-DE-28, BR-51,
  BR-CO-05 bis BR-CO-08, BR-CO-19 bis BR-CO-26) und die BR-FXEXT-xx-01 von Factur-X EXTENDED
  gehoeren noch nicht dazu.

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
  discarded). Returns the number of violations with severity eds_Error.
  DE: Fuehrt jede Regel aus, die fuer ASpec gilt (ausser den
  LX-CC-Kompatibilitaetsregeln), und fuegt je Verstoss ein
  edk_RuleViolation an ADiagnostics an (nil: verworfen). Liefert die Anzahl
  der Verstoesse mit Schwere eds_Error. }
function LandrixEInvoiceCheckInvoice(AInvoice: TLandrixInvoice; const ASpec: TLandrixEInvoiceSpec;
  ADiagnostics: TLandrixEInvoiceDiagnostics): Integer;

{ Checks the one rule ARuleID (case-sensitive, e.g. 'LX-CC-04'). True if it
  holds or does not apply to ASpec; otherwise False and one
  edk_RuleViolation in ADiagnostics (nil: discarded). An unknown identifier
  raises ELandrixEInvoiceError. ASpec may be the empty entry of
  LandrixEInvoiceFindSpec (a target without entry); the LX-CC rules apply
  to it as they did to the versions XRechnung-for-Delphi could not write,
  the official rules do not.
  DE: Prueft die eine Regel ARuleID (Gross- und Kleinschreibung zaehlt,
  z. B. 'LX-CC-04'). True, wenn sie erfuellt ist oder fuer ASpec nicht
  gilt; sonst False und ein edk_RuleViolation in ADiagnostics (nil:
  verworfen). Eine unbekannte Kennung loest ELandrixEInvoiceError aus.
  ASpec darf der leere Eintrag von LandrixEInvoiceFindSpec sein (Ziel ohne
  Eintrag); die LX-CC-Regeln gelten dafuer, wie sie fuer die Versionen
  galten, die XRechnung-for-Delphi nicht schreiben konnte, die offiziellen
  Regeln nicht. }
function LandrixEInvoiceCheckRule(AInvoice: TLandrixInvoice; const ASpec: TLandrixEInvoiceSpec;
  const ARuleID: TLandrixEInvoiceString; ADiagnostics: TLandrixEInvoiceDiagnostics): Boolean;

{ Checks the required content of a CII syntax model as the CII writer does
  when it writes ACII for ASpec: what the schema requires (if the Factur-X
  profile of ASpec contains it) and what the profile requires below an
  existing parent (LandrixEInvoiceCIIRequiredBelowParent). Content the
  Factur-X profile does not allow is an error (edk_NotAllowed,
  LandrixEInvoiceCheckCIIProfile; the model is not changed). Adds these and
  the writer's diagnostics (edk_MissingElement and others) to ADiagnostics
  (nil: discarded) and returns the number with severity eds_Error. A
  parent that exists only through such content can also report its
  required children. ASpec must not be a UBL specification
  (ELandrixEInvoiceError).
  DE: Prueft den Pflichtinhalt eines CII-Syntaxmodells so, wie der
  CII-Writer es beim Schreiben von ACII fuer ASpec tut: was das Schema
  verlangt (wenn das Factur-X-Profil von ASpec es enthaelt) und was das
  Profil unter einem vorhandenen Elternelement verlangt
  (LandrixEInvoiceCIIRequiredBelowParent). Inhalt, den das
  Factur-X-Profil nicht erlaubt, ist ein Fehler (edk_NotAllowed,
  LandrixEInvoiceCheckCIIProfile; das Modell wird nicht geaendert). Fuegt
  diese und die Meldungen des Writers (edk_MissingElement und andere) an
  ADiagnostics an (nil: verworfen) und liefert die Anzahl mit Schwere
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
  LandrixXmlWriter,
  LandrixEInvoiceCodes,
  LandrixEInvoiceLexical,
  LandrixEInvoiceRules,
  LandrixEInvoiceCalc,
  LandrixEInvoiceCIIWriter,
  LandrixEInvoiceCIIProfiles,
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
    cr_BR37, cr_BR38, cr_BR42, cr_BR44, cr_BR47, cr_BR52, cr_BR53, cr_BR54,
    cr_BR55, cr_BR56, cr_BR57, cr_BR61, cr_BR62, cr_BR63, cr_BR64, cr_BR65, cr_BRB01, cr_BRB02,
    cr_BRDE01, cr_BRDE02, cr_BRDE03, cr_BRDE04, cr_BRDE05, cr_BRDE06,
    cr_BRDE07, cr_BRDE08, cr_BRDE09, cr_BRDE10, cr_BRDE11, cr_BRDE15,
    cr_BRDE16, cr_BRDE22, cr_BRDE23a, cr_BRDE23b, cr_BRDE24a, cr_BRDE24b,
    cr_BRDE25a, cr_BRDE25b, cr_BRDE26, cr_BRDE30, cr_BRDE31,
    cr_PeppolR003, cr_PeppolR010, cr_PeppolR020, cr_PeppolR061,
    cr_BRCO03, cr_BRCO04, cr_BRCO09,
    cr_BRCO10, cr_BRCO11, cr_BRCO12, cr_BRCO13, cr_BRCO14, cr_BRCO15, cr_BRCO16, cr_BRCO17, cr_BRCO18,
    cr_BRFXEXTCO10, cr_BRFXEXTCO11, cr_BRFXEXTCO12, cr_BRFXEXTCO13, cr_BRFXEXTCO15, cr_BRFXEXTCO16,
    cr_BRDEX09);

  { One check row: identifier, the specifications it applies to, severity,
    business terms (used as diagnostic path), message and origin. Legacy
    rows run only through LandrixEInvoiceCheckRule.
    DE: Eine Pruefzeile: Kennung, die Spezifikationen, fuer die sie gilt,
    Schwere, Geschaeftsbegriffe (als Meldungspfad), Meldung und Herkunft.
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
  { PEPPOL-EN16931-R010, R020 and R061 are part of the XRechnung schematron
    as well. DE: PEPPOL-EN16931-R010, R020 und R061 gehoeren auch zum
    XRechnung-Schematron. }
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
     Message: 'sub lines the target does not allow (rule table), or an INFORMATION line on the top ' +
       'level or a DETAIL line with sub lines outside Factur-X EXTENDED';
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
    (ID: 'BR-DE-30'; Standards: [est_XRechnung]; Syntaxes: AllSyntaxes;
     Profiles: AllProfiles; Severity: eds_Error; Legacy: False; Terms: 'BT-90';
     Message: 'direct debit information (BG-19) shall have the bank assigned creditor identifier (BT-90)';
     Source: XRechnungSource),
    (ID: 'BR-DE-31'; Standards: [est_XRechnung]; Syntaxes: AllSyntaxes;
     Profiles: AllProfiles; Severity: eds_Error; Legacy: False; Terms: 'BT-91';
     Message: 'direct debit information (BG-19) shall have the debited account identifier (BT-91)';
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
    (ID: 'BR-DEX-09'; Standards: [est_XRechnung]; Syntaxes: [esy_UBL];
     Profiles: AllProfiles; Severity: eds_Error; Legacy: False; Terms: 'BT-115, BT-DEX-002';
     Message: 'amount due for payment (BT-115) = BT-112 - BT-113 + BT-114 + sum of third-party payment ' +
       'amounts (BT-DEX-002)';
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

function HasSubInvoiceLines(ALines: TLandrixInvoiceLines): Boolean;
var
  I: TLandrixEInvoiceListIndex;
begin
  Result := True;
  for I := 0 to ALines.Count - 1 do
    if ALines[I].SubInvoiceLines.Count > 0 then
      Exit;
  Result := False;
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

function IsCreditTransfer(APayment: TLandrixInvoicePaymentType): Boolean;
begin
  Result := APayment.PaymentMeansCode in [ipmc_CreditTransfer, ipmc_SEPACreditTransfer];
end;

function IsCard(APayment: TLandrixInvoicePaymentType): Boolean;
begin
  Result := APayment.PaymentMeansCode in [ipmc_BankCard, ipmc_CreditCard, ipmc_DebitCard];
end;

{ Payment kinds of the payment-group rules (BR-61, BR-DE-23 to BR-DE-25,
  BR-DE-30, BR-DE-31, PEPPOL-EN16931-R061).
  DE: Zahlungsarten der Regeln zu den Zahlungsgruppen. }
type
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
        Hit := P.PaymentMeansCode in [ipmc_DirectDebit, ipmc_SEPADirectDebit];
      pk_DirectDebitWithAccount:
        Hit := (P.PaymentMeansCode in [ipmc_DirectDebit, ipmc_SEPADirectDebit]) and Present(P.FinancialAccount);
      pk_SEPADirectDebitWithoutAccount:
        Hit := (P.PaymentMeansCode = ipmc_SEPADirectDebit) and not Present(P.FinancialAccount);
      pk_SEPADirectDebitWithBIC:
        Hit := (P.PaymentMeansCode = ipmc_SEPADirectDebit) and Present(P.FinancialInstitutionBranch);
    end;
    if Hit then
      Exit;
  end;
  Result := False;
end;

{ BT-90 as the validators see it: the seller's creditor identifier; in UBL
  also a payee identifier with scheme SEPA.
  DE: BT-90, wie die Validatoren es sehen: die Glaeubiger-ID des
  Verkaeufers; in UBL auch eine Kennung des Zahlungsempfaengers mit Schema
  SEPA. }
function HasCreditorID(AInvoice: TLandrixInvoice; const ASpec: TLandrixEInvoiceSpec): Boolean;
begin
  Result := Present(AInvoice.AccountingSupplierParty.BankAssignedCreditorIdentifier) or
    ((ASpec.Target.Syntax = esy_UBL) and Present(AInvoice.PayeeParty.Identifier) and
     (AInvoice.PayeeParty.IdentifierSchemeID = 'SEPA'));
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

function UsesRegisteredCategory(AInvoice: TLandrixInvoice): Boolean;
var
  I: TLandrixEInvoiceListIndex;
begin
  Result := True;
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

function PeriodDateSet(AValue: TDateTime): Boolean;
begin
  Result := AValue > 100;
end;

{ BR-29, BR-30: compared as dates (xs:date), the time is ignored.
  DE: BR-29, BR-30: als Datum verglichen (xs:date), die Uhrzeit zaehlt
  nicht. }
function PeriodReversed(AStart, AEnd: TDateTime): Boolean;
begin
  Result := PeriodDateSet(AStart) and PeriodDateSet(AEnd) and (Trunc(AEnd) < Trunc(AStart));
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

{ Sub lines are checked in CII only: there they are invoice lines
  (ram:IncludedSupplyChainTradeLineItem); a UBL cac:SubInvoiceLine is not
  in the context of the EN 16931 rules (a group sub line has no quantity).
  DE: Unterpositionen werden nur in CII geprueft: dort sind sie
  Rechnungspositionen (ram:IncludedSupplyChainTradeLineItem); eine
  UBL-cac:SubInvoiceLine liegt nicht im Kontext der EN-16931-Regeln (eine
  Gruppen-Unterposition hat keine Menge). }
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

{ BR-17: the payee needs a name and must not repeat the seller. UBL
  compares with the trading name (cac:PartyName) and the party
  identifiers; the creditor identifier BT-90 is one of the payee's there,
  CII with the seller name (BT-27), the identifier ram:ID
  (a payee identifier with scheme is written as ram:GlobalID and not
  compared) and the legal registration.
  DE: BR-17: Der Zahlungsempfaenger braucht einen Namen und darf den
  Verkaeufer nicht wiederholen. UBL vergleicht mit dem Handelsnamen
  (cac:PartyName) und den Parteikennungen; die Glaeubiger-ID BT-90 gehoert
  dort zu denen des Zahlungsempfaengers, CII mit dem Verkaeufernamen
  (BT-27), der Kennung ram:ID (eine Kennung des Zahlungsempfaengers mit
  Schema wird als ram:GlobalID geschrieben und nicht verglichen) und der
  Registernummer. }
function SellerIdentifier(const AID: TLandrixEInvoiceString; ASeller: TLandrixInvoiceAccountingParty): Boolean;
begin
  Result := Present(AID) and ((AID = ASeller.IdentifierSellerBuyer) or (AID = ASeller.GlobalIdentifierSellerBuyer));
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
      SellerIdentifier(Payee.Identifier, Seller) or SellerIdentifier(Seller.BankAssignedCreditorIdentifier, Seller)
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

{ BR-DE-22 compares the written file names; a blank name is not written.
  DE: BR-DE-22 vergleicht die geschriebenen Dateinamen; ein leerer Name
  wird nicht geschrieben. }
function DuplicateFilename(AInvoice: TLandrixInvoice): Boolean;
var
  I, K: TLandrixEInvoiceListIndex;
  A: TLandrixInvoiceAttachment;
begin
  Result := True;
  for I := 0 to AInvoice.Attachments.Count - 1 do
  begin
    A := AInvoice.Attachments[I];
    if not A.ContainsBinaryObject or not Present(A.Filename) then
      Continue;
    for K := 0 to I - 1 do
      if AInvoice.Attachments[K].ContainsBinaryObject and (AInvoice.Attachments[K].Filename = A.Filename) then
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

{ --- calculation rules ---------------------------------------------------------- }

{ An amount as written, in cents (LandrixEInvoiceAmountToLexical).
  DE: Ein Betrag, wie er geschrieben wird, in Cent. }
function Cents(AValue: Currency): Int64;
begin
  Result := Trunc(CentAmount(AValue) * 100);
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
  inclusively in CII.
  DE: BR-CO-17 fuer eine Steueraufschluesselung: bei einem Satz, der auf 0
  rundet, rundet der Steuerbetrag auf 0; sonst liegt er innerhalb von 1
  um Bemessungsgrundlage x Satz / 100, auf Cent gerundet (XPath round:
  halb aufwaerts), in UBL echt, in CII einschliesslich. }
function TaxAmountWrong(ATax: TLandrixInvoiceTaxAmount; AStrict: Boolean): Boolean;
var
  Tax, Expected: Int64;
begin
  Tax := Cents(ATax.TaxAmount);
  if Trunc(Abs(ATax.TaxPercent) + 0.5) = 0 then
  begin
    Result := (Tax < -50) or (Tax >= 50);
    Exit;
  end;
  Expected := Trunc(Abs(Cents(ATax.TaxableAmount)) * ATax.TaxPercent / 100 + 0.5);
  if AStrict then
    Result := not ((Abs(Tax) - 100 < Expected) and (Abs(Tax) + 100 > Expected))
  else
    Result := not ((Abs(Tax) - 100 <= Expected) and (Abs(Tax) + 100 >= Expected));
end;

{ The calculation rules on the totals as written.
  DE: Die Rechenregeln auf den geschriebenen Summen. }
function CalculationViolated(AIndex: TCheckRuleIndex; AInvoice: TLandrixInvoice;
  const ASpec: TLandrixEInvoiceSpec): Boolean;
var
  Lines, Allowances, Charges, Expected: Int64;
  LineCount, AllLines, AllowanceCount, ChargeCount, I: Integer;
  Tolerance: Int64;
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
      Result := Cents(AInvoice.LineAmount) <> Lines;
    cr_BRCO11:
      Result := Cents(AInvoice.AllowanceTotalAmount) <> Allowances;
    cr_BRCO12:
      Result := Cents(AInvoice.ChargeTotalAmount) <> Charges;
    cr_BRCO13:
      Result := Cents(AInvoice.TaxExclusiveAmount) <>
        Cents(AInvoice.LineAmount) - Cents(AInvoice.AllowanceTotalAmount) + Cents(AInvoice.ChargeTotalAmount);
    cr_BRCO14:
      { UBL: no breakdown, no rule; CII: the empty sum is 0 }
      if (ASpec.Target.Syntax = esy_CII) or (AInvoice.TaxAmountSubtotals.Count > 0) then
      begin
        Expected := 0;
        for I := 0 to Integer(AInvoice.TaxAmountSubtotals.Count) - 1 do
          Inc(Expected, Cents(AInvoice.TaxAmountSubtotals[I].TaxAmount));
        Result := Cents(AInvoice.TaxAmountTotal) <> Expected;
      end;
    cr_BRCO15:
      { CII also accepts BT-112 = BT-109 }
      Result := (Cents(AInvoice.TaxInclusiveAmount) <>
        Cents(AInvoice.TaxExclusiveAmount) + Cents(AInvoice.TaxAmountTotal)) and
        ((ASpec.Target.Syntax <> esy_CII) or
         (Cents(AInvoice.TaxInclusiveAmount) <> Cents(AInvoice.TaxExclusiveAmount)));
    cr_BRCO16, cr_BRFXEXTCO16, cr_BRDEX09:
      begin
        Expected := Cents(AInvoice.TaxInclusiveAmount) - Cents(AInvoice.PrepaidAmount) +
          Cents(AInvoice.PayableRoundingAmount);
        if ThirdPartyWritten(AInvoice, ASpec) then
        begin
          { BR-CO-16 gives way to BR-DEX-09 (KoSIT: information in the
            extension) and BR-FXEXT-CO-16 }
          if AIndex = cr_BRCO16 then
            Exit;
          Inc(Expected, ThirdPartyCents(AInvoice));
        end
        else if AIndex = cr_BRDEX09 then
          Exit;
        Result := Cents(AInvoice.PayableAmount) <> Expected;
      end;
    cr_BRCO17:
      for I := 0 to Integer(AInvoice.TaxAmountSubtotals.Count) - 1 do
        if TaxAmountWrong(AInvoice.TaxAmountSubtotals[I], ASpec.Target.Syntax = esy_UBL) then
          Result := True;
    cr_BRFXEXTCO10:
      Result := Abs(Cents(AInvoice.LineAmount) - Lines) > AllLines;
    cr_BRFXEXTCO11:
      Result := Abs(Cents(AInvoice.AllowanceTotalAmount) - Allowances) > AllowanceCount;
    cr_BRFXEXTCO12:
      Result := Abs(Cents(AInvoice.ChargeTotalAmount) - Charges) > ChargeCount;
    cr_BRFXEXTCO13:
      Result := Abs(Cents(AInvoice.TaxExclusiveAmount) - Lines + Allowances - Charges) > Tolerance;
    cr_BRFXEXTCO15:
      Result := Abs(Cents(AInvoice.TaxInclusiveAmount) - Cents(AInvoice.TaxAmountTotal) -
        Cents(AInvoice.TaxExclusiveAmount)) > Tolerance;
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
    allowance or charge, or a VAT breakdown; amounts in cents, the rate in
    hundredths of a percent.
    DE: Eine Umsatzsteuerkategorie, wie sie geschrieben wird: einer
    Rechnungsposition, eines Nachlasses oder Zuschlags der Dokumentebene
    oder einer Steueraufschluesselung; Betraege in Cent, der Satz in
    Hundertstel Prozent. }
  TTaxUse = record
    Kind: TTaxUseKind;
    Code: TLandrixEInvoiceString;
    HasRate: Boolean;
    Rate: Int64;
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

{ The rate as written (two decimals), in hundredths of a percent.
  DE: Der Satz, wie er geschrieben wird (zwei Nachkommastellen), in
  Hundertstel Prozent. }
function RateHundredths(AValue: Double): Int64;
var
  Value: Currency;
  Rounded: Boolean;
begin
  if LandrixEInvoiceTryLexicalToCurrency(LandrixEInvoicePercentToLexical(AValue), Value, Rounded) then
    Result := Trunc(Value * 100)
  else
    Result := 0;
end;

procedure AddTaxUse(var AUses: TTaxUses; AKind: TTaxUseKind; const ACode: TLandrixEInvoiceString;
  AHasRate: Boolean; ARate: Double; AAmount: Int64);
begin
  if AUses.Count = Length(AUses.Items) then
    SetLength(AUses.Items, 2 * AUses.Count + 8);
  AUses.Items[AUses.Count].Kind := AKind;
  AUses.Items[AUses.Count].Code := ACode;
  AUses.Items[AUses.Count].HasRate := AHasRate;
  AUses.Items[AUses.Count].Rate := RateHundredths(ARate);
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
procedure AddLineTaxUses(var AUses: TTaxUses; ALines: TLandrixInvoiceLines; AKind: TTaxUseKind;
  ASubLines: Boolean);
var
  I: TLandrixEInvoiceListIndex;
  Line: TLandrixInvoiceLine;
begin
  for I := 0 to ALines.Count - 1 do
  begin
    Line := ALines[I];
    AddTaxUse(AUses, AKind, TaxCategoryText(Line.TaxCategory, Line.TaxCategoryOther),
      Line.TaxCategory <> idtfcc_O_ServicesOutsideScopeOfTax, Line.TaxPercent, Cents(Line.LineAmount));
    if ASubLines then
      AddLineTaxUses(AUses, Line.SubInvoiceLines, tuk_SubLine, True);
  end;
end;

procedure CollectTaxUses(AInvoice: TLandrixInvoice; const ASpec: TLandrixEInvoiceSpec; out AUses: TTaxUses);
var
  I: TLandrixEInvoiceListIndex;
  Item: TLandrixInvoiceAllowanceCharge;
  Subtotal: TLandrixInvoiceTaxAmount;
  Kind: TTaxUseKind;
begin
  AUses.Items := nil;
  AUses.Count := 0;
  AddLineTaxUses(AUses, AInvoice.InvoiceLines, tuk_Line, not Forbidden(ASpec, LandrixEInvoiceRuleLineSubLines));
  for I := 0 to AInvoice.AllowanceCharges.Count - 1 do
  begin
    Item := AInvoice.AllowanceCharges[I];
    Kind := tuk_Allowance;
    if Item.ChargeIndicator then
      Kind := tuk_Charge;
    AddTaxUse(AUses, Kind, TaxCategoryText(Item.TaxCategory, Item.TaxCategoryOther),
      Item.TaxCategory <> idtfcc_O_ServicesOutsideScopeOfTax, Item.TaxPercent, Cents(Item.Amount));
  end;
  for I := 0 to AInvoice.TaxAmountSubtotals.Count - 1 do
  begin
    Subtotal := AInvoice.TaxAmountSubtotals[I];
    AddTaxUse(AUses, tuk_Breakdown, TaxCategoryText(Subtotal.TaxCategory, Subtotal.TaxCategoryOther), True,
      Subtotal.TaxPercent, Cents(Subtotal.TaxableAmount));
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
function TaxUseNet(const AUses: TTaxUses; const ACode: TLandrixEInvoiceString; AByRate: Boolean; ARate: Int64;
  ALineKinds: TTaxUseKinds; out AFound: Boolean): Int64;
var
  I: Integer;
  U: TTaxUse;
begin
  Result := 0;
  AFound := False;
  for I := 0 to AUses.Count - 1 do
  begin
    U := AUses.Items[I];
    if (U.Code <> ACode) or (AByRate and (not U.HasRate or (U.Rate <> ARate))) then
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
  (exactly, in integers).
  DE: BR-S-09 (und BR-AF-09, BR-AG-09 in UBL): der Steuerbetrag liegt echt
  innerhalb von 1 um Bemessungsgrundlage x Satz / 100, halb aufwaerts auf
  Cent gerundet (genau, in ganzen Zahlen). }
function BreakdownTaxWrong(const AUse: TTaxUse): Boolean;
var
  Product, Expected: Int64;
begin
  Product := Abs(AUse.Amount) * AUse.Rate + 5000;
  Expected := Product div 10000;
  if (Product < 0) and (Product mod 10000 <> 0) then
    Dec(Expected);
  Result := not ((Abs(AUse.TaxAmount) - 100 < Expected) and (Abs(AUse.TaxAmount) + 100 > Expected));
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
        Result := AUse.Rate <= 0;
      vg_AF:
        Result := (AUse.Rate < 0) or ((AUse.Rate = 0) and (ASpec.Target.Syntax = esy_CII));
      vg_AG:
        Result := AUse.Rate < 0;
    else
      Result := AUse.Rate <> 0;
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
    if AGroup in [vg_S, vg_AF, vg_AG] then
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
        if not IsUBL and (AGroup = vg_O) then
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
  (its BR-FXEXT-xx-01 are not checked).
  DE: Die Factur-X-1.09-Profile jeder Steuerregel: BASIC WL hat die Regeln
  der Dokumentebene 03, 04, 06, 07, 09 und 10 sowie BR-IC-11, BR-IC-12,
  BR-O-11, BR-O-13 und BR-O-14, BASIC und EN 16931 haben alle, EXTENDED hat
  02 bis 07 (O: 05 bis 07), 09 (nicht S), 10 (nicht S, Z, AF, AG), BR-IC-11
  und BR-IC-12 (seine BR-FXEXT-xx-01 werden nicht geprueft). }
function VatProfiles(AGroup: TVatGroup; ANumber: Integer): TProfiles;
begin
  case ANumber of
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
        not Forbidden(ASpec, LandrixEInvoiceRuleLineSubLines)));
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
  Prefix := string(Copy(AID, 1, 2));
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

{ --- rules --------------------------------------------------------------------- }

{ True if rule AIndex is violated by AInvoice for ASpec. The LX-CC rules keep
  the conditions of XRechnung-for-Delphi: a target that cannot be written
  (empty entry) fails third-party payments and line delivery data.
  DE: True, wenn AInvoice die Regel AIndex fuer ASpec verletzt. Die
  LX-CC-Regeln behalten die Bedingungen von XRechnung-for-Delphi: ein Ziel,
  das nicht geschrieben werden kann (leerer Eintrag), scheitert an
  Zahlungen Dritter und Lieferdaten je Position. }
function Violated(AIndex: TCheckRuleIndex; AInvoice: TLandrixInvoice; const ASpec: TLandrixEInvoiceSpec): Boolean;
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
      Result := (HasSubInvoiceLines(AInvoice.InvoiceLines) and
        Forbidden(ASpec, LandrixEInvoiceRuleLineSubLines)) or
        (not IsFacturXExtended(ASpec) and (HasInformationLines(AInvoice.InvoiceLines) or
         HasDetailWithSubInvoiceLines(AInvoice.InvoiceLines)));
    cr_LXCC12:
      Result := HasGroupAmountMismatch(AInvoice.InvoiceLines, False);
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
    cr_BR21, cr_BR23, cr_BR25, cr_BR27, cr_BR28, cr_BR30, cr_BR42, cr_BR44, cr_BR54, cr_BR64, cr_BR65:
      Result := AnyLineViolated(AIndex, AInvoice.InvoiceLines, ASpec.Target.Syntax = esy_CII);
    cr_BR29:
      Result := PeriodReversed(AInvoice.InvoicePeriodStartDate, AInvoice.InvoicePeriodEndDate);
    cr_BR32, cr_BR33:
      Result := AllowanceChargeViolated(AIndex, AInvoice, False);
    cr_BR37, cr_BR38:
      Result := AllowanceChargeViolated(AIndex, AInvoice, True);
    cr_BR47:
      Result := TaxCategoryMissing(AInvoice);
    cr_BR52:
      Result := BG24IDMissing(AInvoice);
    cr_BR53:
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
      Result := UsesRegisteredCategory(AInvoice) and not Present(Seller.VATCompanyID) and
        not Present(Seller.VATCompanyNumber) and not PartySet(TaxRepresentative);
    cr_BRDE22:
      Result := DuplicateFilename(AInvoice);
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
      Result := (AInvoice.InvoiceTypeCode = itc_CorrectedInvoice) and not HasPrecedingID(AInvoice);
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
    cr_BRCO10, cr_BRCO11, cr_BRCO12, cr_BRCO13, cr_BRCO14, cr_BRCO15, cr_BRCO16, cr_BRCO17,
    cr_BRFXEXTCO10, cr_BRFXEXTCO11, cr_BRFXEXTCO12, cr_BRFXEXTCO13, cr_BRFXEXTCO15, cr_BRFXEXTCO16,
    cr_BRDEX09:
      Result := CalculationViolated(AIndex, AInvoice, ASpec);
  end;
end;

procedure AddViolation(ADiagnostics: TLandrixEInvoiceDiagnostics; const AID, ATerms, AMessage: string;
  ASeverity: TLandrixEInvoiceDiagnosticSeverity);
var
  D: TLandrixEInvoiceDiagnostic;
begin
  if ADiagnostics = nil then
    Exit;
  D := ADiagnostics.AddDiagnostic(edk_RuleViolation, TLandrixEInvoiceString(ATerms), 0, 0, 0,
    TLandrixEInvoiceString(AMessage));
  D.Severity := ASeverity;
  D.RuleID := TLandrixEInvoiceString(AID);
end;

{ Runs rule AIndex if it applies; False and a diagnostic on a violation. }
function Run(AIndex: TCheckRuleIndex; AInvoice: TLandrixInvoice; const ASpec: TLandrixEInvoiceSpec;
  ADiagnostics: TLandrixEInvoiceDiagnostics): Boolean;
begin
  Result := True;
  if not Applies(CheckRows[AIndex], ASpec) or not Violated(AIndex, AInvoice, ASpec) then
    Exit;
  Result := False;
  AddViolation(ADiagnostics, CheckRows[AIndex].ID, CheckRows[AIndex].Terms, CheckRows[AIndex].Message,
    CheckRows[AIndex].Severity);
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

{ --- public -------------------------------------------------------------------- }

function LandrixEInvoiceCheckInvoice(AInvoice: TLandrixInvoice; const ASpec: TLandrixEInvoiceSpec;
  ADiagnostics: TLandrixEInvoiceDiagnostics): Integer;
var
  I: TCheckRuleIndex;
  G: TVatGroup;
  N: Integer;
  TaxUses: TTaxUses;
begin
  Result := 0;
  for I := Low(TCheckRuleIndex) to High(TCheckRuleIndex) do
    if not CheckRows[I].Legacy and not Run(I, AInvoice, ASpec, ADiagnostics) and
       (CheckRows[I].Severity = eds_Error) then
      Inc(Result);
  CollectTaxUses(AInvoice, ASpec, TaxUses);
  for G := Low(TVatGroup) to High(TVatGroup) do
    for N := 1 to VatGroupLast[G] do
      if not RunVat(G, N, AInvoice, ASpec, TaxUses, ADiagnostics) then
        Inc(Result);
end;

function LandrixEInvoiceCheckRule(AInvoice: TLandrixInvoice; const ASpec: TLandrixEInvoiceSpec;
  const ARuleID: TLandrixEInvoiceString; ADiagnostics: TLandrixEInvoiceDiagnostics): Boolean;
var
  I: TCheckRuleIndex;
  G: TVatGroup;
  N: Integer;
  TaxUses: TTaxUses;
begin
  for I := Low(TCheckRuleIndex) to High(TCheckRuleIndex) do
    if TLandrixEInvoiceString(CheckRows[I].ID) = ARuleID then
    begin
      Result := Run(I, AInvoice, ASpec, ADiagnostics);
      Exit;
    end;
  for G := Low(TVatGroup) to High(TVatGroup) do
    for N := 1 to VatGroupLast[G] do
      if TLandrixEInvoiceString(VatRuleID(G, N)) = ARuleID then
      begin
        CollectTaxUses(AInvoice, ASpec, TaxUses);
        Result := RunVat(G, N, AInvoice, ASpec, TaxUses, ADiagnostics);
        Exit;
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
