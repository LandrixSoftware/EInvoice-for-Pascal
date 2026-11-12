{
  EInvoice-for-Pascal

  Copyright (C) 2026 Landrix Software GmbH & Co. KG

  This file is dual-licensed under:
  - GNU GPL version 3 or later; or
  - the Landrix Software Commercial License.

  See LICENSE and COMMERCIAL-LICENSE.md.

  SPDX-License-Identifier: GPL-3.0-or-later OR LicenseRef-Landrix-Commercial
}

{ The rules that only the Peppol BIS Billing 3.0 schematron (release
  3.0.21, UBL) contains: the PEPPOL-EN16931 rules XRechnung does not share,
  PEPPOL-COMMON (identifier formats and check digits, see
  LandrixEInvoiceIdentifiers) and the national rules. The rules the
  XRechnung schematron has as well (PEPPOL-EN16931-R003, R005, R010, R020,
  R040 to R046, R053 to R055, R061, R110 to R130) are rows of
  LandrixEInvoiceCheck. As there, a rule judges the invoice as the UBL
  mapper would write it: blank text is absent, codes are written as the
  enumeration or else the other text, and a rule the mapper always meets
  has no row: PEPPOL-EN16931-R004 (the specification identifier comes from
  the specification), R051 (every amount carries the invoice currency
  except BT-111), R080 (one project reference), R100 (one object
  identifier per line), F001 (dates are written as YYYY-MM-DD), P0101
  (ubl:CreditNote is written for type 381 only), DE-R-014 (every VAT
  breakdown has its rate) and DE-R-023-2 (the codes 30 and 58 come with
  the payee account only). The national rules test the country variables
  of the schematron, some as written, some after upper-case and
  normalize-space.

  DE: Die Regeln, die nur das Schematron von Peppol BIS Billing 3.0
  (Release 3.0.21, UBL) enthaelt: die PEPPOL-EN16931-Regeln, die XRechnung
  nicht teilt, PEPPOL-COMMON (Formate und Pruefziffern von Kennungen, siehe
  LandrixEInvoiceIdentifiers) und die nationalen Regeln. Die Regeln, die
  auch das XRechnung-Schematron hat (PEPPOL-EN16931-R003, R005, R010, R020,
  R040 bis R046, R053 bis R055, R061, R110 bis R130), sind Zeilen von
  LandrixEInvoiceCheck. Wie dort beurteilt eine Regel die Rechnung so, wie
  der UBL-Mapper sie schreiben wuerde: Leerraum fehlt, Codes werden als
  Aufzaehlung oder sonst als anderer Text geschrieben, und eine Regel, die
  der Mapper immer erfuellt, hat keine Zeile: PEPPOL-EN16931-R004 (die
  Spezifikationskennung kommt aus der Spezifikation), R051 (jeder Betrag
  traegt die Rechnungswaehrung ausser BT-111), R080 (ein Projektverweis),
  R100 (eine Objektkennung je Position), F001 (Daten werden als JJJJ-MM-TT
  geschrieben), P0101 (ubl:CreditNote wird nur fuer Art 381 geschrieben),
  DE-R-014 (jede Steueraufschluesselung hat ihren Satz) und DE-R-023-2 (die
  Codes 30 und 58 kommen nur mit dem Konto des Zahlungsempfaengers). Die
  nationalen Regeln pruefen die Laendervariablen des Schematrons, manche
  wie geschrieben, manche nach upper-case und normalize-space. }

{ API: internal. May change in any release; use the facade LandrixEInvoice
  or the stable units instead.
  DE: API: intern. Kann sich in jeder Version aendern; stattdessen die
  Fassade LandrixEInvoice oder die stabilen Units verwenden. }

unit LandrixEInvoiceCheckPeppol;

{$I LandrixEInvoice.inc}

interface

uses
  LandrixEInvoiceTypes,
  LandrixEInvoiceDiagnostics,
  LandrixEInvoiceSpecs,
  LandrixEInvoiceInvoice;

{ Runs every rule of this unit when ASpec is Peppol BIS (otherwise none)
  and adds one edk_RuleViolation per violation to ADiagnostics (nil:
  discarded). Returns the number of violations with severity eds_Error.
  A rule that cannot judge a number the writers cannot format holds
  (LandrixEInvoiceCheckInvoice reports the number).
  DE: Fuehrt jede Regel dieser Unit aus, wenn ASpec Peppol BIS ist (sonst
  keine), und fuegt je Verstoss ein edk_RuleViolation an ADiagnostics an
  (nil: verworfen). Liefert die Anzahl der Verstoesse mit Schwere
  eds_Error. Eine Regel, die eine Zahl nicht beurteilen kann, die die
  Writer nicht formatieren koennen, gilt als erfuellt
  (LandrixEInvoiceCheckInvoice meldet die Zahl). }
function LandrixEInvoiceCheckPeppolInvoice(AInvoice: TLandrixInvoice; const ASpec: TLandrixEInvoiceSpec;
  ADiagnostics: TLandrixEInvoiceDiagnostics): Integer;

{ Checks the rule ARuleID (case-sensitive) if this unit has it (AFound):
  True if it holds or ASpec is not Peppol BIS, otherwise False and one
  edk_RuleViolation in ADiagnostics (nil: discarded). AFound False: the
  identifier is not a rule of this unit, the result is True. ASkip: the
  rule does not run (True); a rule that cannot judge a number holds as for
  LandrixEInvoiceCheckPeppolInvoice.
  DE: Prueft die Regel ARuleID (Gross- und Kleinschreibung zaehlt), wenn
  diese Unit sie hat (AFound): True, wenn sie erfuellt ist oder ASpec nicht
  Peppol BIS ist, sonst False und ein edk_RuleViolation in ADiagnostics
  (nil: verworfen). AFound False: die Kennung ist keine Regel dieser Unit,
  das Ergebnis ist True. ASkip: die Regel laeuft nicht (True); eine Regel,
  die eine Zahl nicht beurteilen kann, gilt wie bei
  LandrixEInvoiceCheckPeppolInvoice als erfuellt. }
function LandrixEInvoiceCheckPeppolRule(AInvoice: TLandrixInvoice; const ASpec: TLandrixEInvoiceSpec;
  const ARuleID: TLandrixEInvoiceString; ADiagnostics: TLandrixEInvoiceDiagnostics; ASkip: Boolean;
  out AFound: Boolean): Boolean;

implementation

uses
  SysUtils,
  LandrixXmlBase,
  LandrixEInvoiceCodes,
  LandrixEInvoiceLexical,
  LandrixEInvoiceRules,
  LandrixEInvoiceCalc,
  LandrixEInvoiceSubLines,
  LandrixEInvoiceIdentifiers;

type
  { The rules of this unit; the order of PeppolRows. }
  TPeppolRuleIndex = (
    pr_R002, pr_R007, pr_P0100, pr_P0104, pr_P0105, pr_P0106, pr_P0107, pr_P0108, pr_P0109, pr_P0110,
    pr_P0111, pr_P0112, pr_CL001, pr_CL002, pr_CL003, pr_CL006, pr_CL007, pr_CL008,
    pr_CommonR040, pr_CommonR041, pr_CommonR042, pr_CommonR043, pr_CommonR044, pr_CommonR045, pr_CommonR046,
    pr_CommonR047, pr_CommonR049, pr_CommonR050, pr_CommonR052, pr_CommonR053, pr_CommonR054, pr_CommonR055,
    pr_CommonR0561, pr_CommonR0562, pr_CommonR057,
    pr_NOR001, pr_NOR002,
    pr_DKR002, pr_DKR003, pr_DKR004, pr_DKR005, pr_DKR006, pr_DKR007, pr_DKR008, pr_DKR009, pr_DKR010, pr_DKR011,
    pr_DKR013, pr_DKR014, pr_DKR016, pr_DKR017,
    pr_ITR001, pr_ITR002, pr_ITR003, pr_ITR004,
    pr_SER001, pr_SER002, pr_SER003, pr_SER004, pr_SER005, pr_SER006, pr_SER007, pr_SER008, pr_SER009, pr_SER010,
    pr_SER011, pr_SER012, pr_SER013,
    pr_GRR0011, pr_GRR0012, pr_GRR0013, pr_GRR0014, pr_GRR0015, pr_GRR0016, pr_GRR0017, pr_GRR002, pr_GRR003,
    pr_GRR0041, pr_GRR0042, pr_GRR005, pr_GRR006, pr_GRR0082, pr_GRR0083, pr_GRR009, pr_GRR010, pr_GRS0081,
    pr_GRS011,
    pr_ISR001, pr_ISR002, pr_ISR003, pr_ISR004, pr_ISR005, pr_ISR006, pr_ISR007, pr_ISR008, pr_ISR009, pr_ISR010,
    pr_NLR001, pr_NLR002, pr_NLR003, pr_NLR004, pr_NLR005, pr_NLR006, pr_NLR007, pr_NLR008, pr_NLR009,
    pr_DER001, pr_DER002, pr_DER003, pr_DER004, pr_DER005, pr_DER006, pr_DER007, pr_DER008, pr_DER009, pr_DER010,
    pr_DER011, pr_DER015, pr_DER016, pr_DER017, pr_DER018, pr_DER019, pr_DER020, pr_DER022, pr_DER0231,
    pr_DER0241, pr_DER0242, pr_DER0251, pr_DER0252, pr_DER026, pr_DER027, pr_DER028, pr_DER030, pr_DER031,
    pr_DERT02);

  { One rule: identifier, severity (fatal: eds_Error), business terms (the
    diagnostic path), message and origin. Every row applies to Peppol BIS
    (UBL) only; a national rule tests its country itself.
    DE: Eine Regel: Kennung, Schwere (fatal: eds_Error), Geschaeftsbegriffe
    (der Meldungspfad), Meldung und Herkunft. Jede Zeile gilt nur fuer
    Peppol BIS (UBL); eine nationale Regel prueft ihr Land selbst. }
  TPeppolRow = record
    ID: string;
    Severity: TLandrixEInvoiceDiagnosticSeverity;
    Terms: string;
    Message: string;
    Source: string;
  end;

const
  PeppolSource = 'Peppol BIS Billing 3.0.21';

  PeppolRows: array[TPeppolRuleIndex] of TPeppolRow = (
    (ID: 'PEPPOL-EN16931-R002'; Severity: eds_Error; Terms: 'BT-22';
     Message: 'no more than one note (BT-22) is allowed unless seller and buyer are located in Germany';
     Source: PeppolSource),
    (ID: 'PEPPOL-EN16931-R007'; Severity: eds_Error; Terms: 'BT-23';
     Message: 'the business process (BT-23) shall be an approved Peppol profile identifier';
     Source: PeppolSource),
    (ID: 'PEPPOL-EN16931-P0100'; Severity: eds_Error; Terms: 'BT-3';
     Message: 'the invoice type code (BT-3) shall be allowed by the profile';
     Source: PeppolSource),
    (ID: 'PEPPOL-EN16931-P0104'; Severity: eds_Error; Terms: 'BT-118, BT-121';
     Message: 'the exemption reason code VATEX-EU-G (BT-121) requires the VAT category G (BT-118)';
     Source: PeppolSource),
    (ID: 'PEPPOL-EN16931-P0105'; Severity: eds_Error; Terms: 'BT-118, BT-121';
     Message: 'the exemption reason code VATEX-EU-O (BT-121) requires the VAT category O (BT-118)';
     Source: PeppolSource),
    (ID: 'PEPPOL-EN16931-P0106'; Severity: eds_Error; Terms: 'BT-118, BT-121';
     Message: 'the exemption reason code VATEX-EU-IC (BT-121) requires the VAT category K (BT-118)';
     Source: PeppolSource),
    (ID: 'PEPPOL-EN16931-P0107'; Severity: eds_Error; Terms: 'BT-118, BT-121';
     Message: 'the exemption reason code VATEX-EU-AE (BT-121) requires the VAT category AE (BT-118)';
     Source: PeppolSource),
    (ID: 'PEPPOL-EN16931-P0108'; Severity: eds_Error; Terms: 'BT-118, BT-121';
     Message: 'the exemption reason code VATEX-EU-D (BT-121) requires the VAT category E (BT-118)';
     Source: PeppolSource),
    (ID: 'PEPPOL-EN16931-P0109'; Severity: eds_Error; Terms: 'BT-118, BT-121';
     Message: 'the exemption reason code VATEX-EU-F (BT-121) requires the VAT category E (BT-118)';
     Source: PeppolSource),
    (ID: 'PEPPOL-EN16931-P0110'; Severity: eds_Error; Terms: 'BT-118, BT-121';
     Message: 'the exemption reason code VATEX-EU-I (BT-121) requires the VAT category E (BT-118)';
     Source: PeppolSource),
    (ID: 'PEPPOL-EN16931-P0111'; Severity: eds_Error; Terms: 'BT-118, BT-121';
     Message: 'the exemption reason code VATEX-EU-J (BT-121) requires the VAT category E (BT-118)';
     Source: PeppolSource),
    (ID: 'PEPPOL-EN16931-P0112'; Severity: eds_Error; Terms: 'BT-3';
     Message: 'the invoice type codes 326 and 384 (BT-3) are allowed only when seller and buyer are located in ' +
       'Germany';
     Source: PeppolSource),
    (ID: 'PEPPOL-EN16931-CL001'; Severity: eds_Error; Terms: 'BT-125';
     Message: 'the MIME code of an attached document (BT-125) shall be from the Peppol subset of the IANA list';
     Source: PeppolSource),
    (ID: 'PEPPOL-EN16931-CL002'; Severity: eds_Error; Terms: 'BT-98, BT-140';
     Message: 'an allowance reason code shall be from the Peppol subset of UNCL 5189';
     Source: PeppolSource),
    (ID: 'PEPPOL-EN16931-CL003'; Severity: eds_Error; Terms: 'BT-105, BT-145';
     Message: 'a charge reason code shall be from UNCL 7161';
     Source: PeppolSource),
    (ID: 'PEPPOL-EN16931-CL006'; Severity: eds_Error; Terms: 'BT-8';
     Message: 'the invoice period description code (BT-8) shall be from UNCL 2005 (3, 35, 432)';
     Source: PeppolSource),
    (ID: 'PEPPOL-EN16931-CL007'; Severity: eds_Error; Terms: 'BT-5, BT-6';
     Message: 'the currency of an amount shall be from ISO 4217';
     Source: PeppolSource),
    (ID: 'PEPPOL-EN16931-CL008'; Severity: eds_Error; Terms: 'BT-34, BT-49';
     Message: 'the scheme of an electronic address shall be from the EAS code list';
     Source: PeppolSource),
    (ID: 'PEPPOL-COMMON-R040'; Severity: eds_Error; Terms: 'BT-29, BT-34, BT-46, BT-49';
     Message: 'a GLN (scheme 0088) shall have a valid GS1 check digit';
     Source: PeppolSource),
    (ID: 'PEPPOL-COMMON-R041'; Severity: eds_Error; Terms: 'BT-29, BT-30, BT-34';
     Message: 'a Norwegian organization number (scheme 0192) shall have nine digits and a valid check digit';
     Source: PeppolSource),
    (ID: 'PEPPOL-COMMON-R042'; Severity: eds_Error; Terms: 'BT-29, BT-30, BT-34';
     Message: 'a Danish CVR number (scheme 0184) shall have eight digits, optionally after DK';
     Source: PeppolSource),
    (ID: 'PEPPOL-COMMON-R043'; Severity: eds_Error; Terms: 'BT-29, BT-30, BT-34';
     Message: 'a Belgian enterprise number (scheme 0208) shall have ten digits and a valid check number';
     Source: PeppolSource),
    (ID: 'PEPPOL-COMMON-R044'; Severity: eds_Warning; Terms: 'BT-29, BT-30, BT-34';
     Message: 'an Italian IPA code (scheme 0201) should have six letters or digits';
     Source: PeppolSource),
    (ID: 'PEPPOL-COMMON-R045'; Severity: eds_Warning; Terms: 'BT-29, BT-30, BT-34';
     Message: 'an Italian tax code (scheme 0210) should have the format of the Codice Fiscale';
     Source: PeppolSource),
    (ID: 'PEPPOL-COMMON-R046'; Severity: eds_Warning; Terms: 'BT-34, BT-49';
     Message: 'an Italian tax code as electronic address (scheme 9907) should have the format of the Codice ' +
       'Fiscale';
     Source: PeppolSource),
    (ID: 'PEPPOL-COMMON-R047'; Severity: eds_Warning; Terms: 'BT-29, BT-30, BT-34';
     Message: 'an Italian VAT number (scheme 0211) should have a valid Partita IVA after IT';
     Source: PeppolSource),
    (ID: 'PEPPOL-COMMON-R049'; Severity: eds_Error; Terms: 'BT-29, BT-30, BT-34';
     Message: 'a Swedish organization number (scheme 0007) shall have ten digits and a valid check digit';
     Source: PeppolSource),
    (ID: 'PEPPOL-COMMON-R050'; Severity: eds_Error; Terms: 'BT-29, BT-30, BT-34';
     Message: 'an Australian Business Number (scheme 0151) shall have eleven digits and a valid check sum';
     Source: PeppolSource),
    (ID: 'PEPPOL-COMMON-R052'; Severity: eds_Error; Terms: 'BT-29, BT-30, BT-34';
     Message: 'a Danish P number (scheme 0096) shall have ten digits';
     Source: PeppolSource),
    (ID: 'PEPPOL-COMMON-R053'; Severity: eds_Error; Terms: 'BT-29, BT-30, BT-34';
     Message: 'a Danish SE number (scheme 0198) shall be DK followed by eight digits';
     Source: PeppolSource),
    (ID: 'PEPPOL-COMMON-R054'; Severity: eds_Warning; Terms: 'BT-29, BT-30, BT-34';
     Message: 'a Dutch KVK number (scheme 0106) should have eight digits';
     Source: PeppolSource),
    (ID: 'PEPPOL-COMMON-R055'; Severity: eds_Warning; Terms: 'BT-29, BT-30, BT-34';
     Message: 'a Dutch OIN (scheme 0190) should have twenty digits';
     Source: PeppolSource),
    (ID: 'PEPPOL-COMMON-R056-1'; Severity: eds_Warning; Terms: 'BT-29, BT-30, BT-34';
     Message: 'a Dutch VAT number (scheme 9944) should have the format NL123456789B12';
     Source: PeppolSource),
    (ID: 'PEPPOL-COMMON-R056-2'; Severity: eds_Warning; Terms: 'BT-31, BT-48, BT-63';
     Message: 'a Dutch VAT identifier should have the format NL123456789B12';
     Source: PeppolSource),
    (ID: 'PEPPOL-COMMON-R057'; Severity: eds_Warning; Terms: 'BT-29, BT-30, BT-34';
     Message: 'a Dutch KVK establishment number (scheme 0217) should have twelve digits';
     Source: PeppolSource),
    (ID: 'NO-R-001'; Severity: eds_Error; Terms: 'BT-31';
     Message: 'a Norwegian VAT identifier (BT-31) shall be NO, a valid organization number and MVA';
     Source: PeppolSource),
    (ID: 'NO-R-002'; Severity: eds_Warning; Terms: 'BT-32';
     Message: 'Norwegian suppliers should state Foretaksregisteret as tax registration (scheme TAX)';
     Source: PeppolSource),
    (ID: 'DK-R-002'; Severity: eds_Error; Terms: 'BT-30';
     Message: 'Danish suppliers shall provide the legal registration identifier (BT-30)';
     Source: PeppolSource),
    (ID: 'DK-R-003'; Severity: eds_Error; Terms: 'BT-158';
     Message: 'an UNSPSC classification (listID TST) of a Danish supplier shall have the version 19.05.01 or ' +
       '26.08.01';
     Source: PeppolSource),
    (ID: 'DK-R-004'; Severity: eds_Error; Terms: 'BT-97, BT-104, BT-139, BT-144';
     Message: 'with reason code ZZZ the reason shall be a four digit number or contain # inside';
     Source: PeppolSource),
    (ID: 'DK-R-005'; Severity: eds_Error; Terms: 'BT-81';
     Message: 'Danish suppliers shall use the payment means codes 1, 10, 31, 42, 48, 49, 50, 58, 59, 93 or 97';
     Source: PeppolSource),
    (ID: 'DK-R-006'; Severity: eds_Error; Terms: 'BT-84, BT-86';
     Message: 'with payment means 31 or 42 the account (BT-84) and the branch (BT-86) are mandatory';
     Source: PeppolSource),
    (ID: 'DK-R-007'; Severity: eds_Error; Terms: 'BT-89, BT-91';
     Message: 'with payment means 49 the mandate (BT-89) and the debited account (BT-91) are mandatory';
     Source: PeppolSource),
    (ID: 'DK-R-008'; Severity: eds_Error; Terms: 'BT-83, BT-84';
     Message: 'with payment means 50 the payment identifier shall start with 01#, 04# or 15# and the account ' +
       'have 7 or 8 digits';
     Source: PeppolSource),
    (ID: 'DK-R-009'; Severity: eds_Error; Terms: 'BT-83';
     Message: 'a payment identifier starting with 04# or 15# shall have 19 characters';
     Source: PeppolSource),
    (ID: 'DK-R-010'; Severity: eds_Error; Terms: 'BT-83, BT-84';
     Message: 'with payment means 93 the payment identifier shall start with 71#, 73# or 75# and the account ' +
       'have 8 characters';
     Source: PeppolSource),
    (ID: 'DK-R-011'; Severity: eds_Error; Terms: 'BT-83';
     Message: 'a payment identifier starting with 71# or 75# shall have 18 or 19 characters';
     Source: PeppolSource),
    (ID: 'DK-R-013'; Severity: eds_Error; Terms: 'BT-29, BT-46';
     Message: 'a party identifier between Danish parties shall have a scheme';
     Source: PeppolSource),
    (ID: 'DK-R-014'; Severity: eds_Error; Terms: 'BT-30';
     Message: 'the legal registration identifier of a Danish supplier (BT-30) shall have the scheme 0184';
     Source: PeppolSource),
    (ID: 'DK-R-016'; Severity: eds_Error; Terms: 'BT-115';
     Message: 'a credit note between Danish parties shall not have a negative amount due (BT-115)';
     Source: PeppolSource),
    (ID: 'DK-R-017'; Severity: eds_Error; Terms: 'BT-47';
     Message: 'the legal registration identifier of a Danish buyer (BT-47) shall have the scheme 0184';
     Source: PeppolSource),
    (ID: 'IT-R-001'; Severity: eds_Error; Terms: 'BT-32';
     Message: 'the tax registration of an Italian supplier (BT-32) shall have 11 to 16 capital letters or digits';
     Source: PeppolSource),
    (ID: 'IT-R-002'; Severity: eds_Error; Terms: 'BT-35';
     Message: 'Italian suppliers shall provide the address line 1 (BT-35)';
     Source: PeppolSource),
    (ID: 'IT-R-003'; Severity: eds_Error; Terms: 'BT-37';
     Message: 'Italian suppliers shall provide the city (BT-37)';
     Source: PeppolSource),
    (ID: 'IT-R-004'; Severity: eds_Error; Terms: 'BT-38';
     Message: 'Italian suppliers shall provide the post code (BT-38)';
     Source: PeppolSource),
    (ID: 'SE-R-001'; Severity: eds_Error; Terms: 'BT-31';
     Message: 'a Swedish VAT identifier (BT-31) shall have 14 characters';
     Source: PeppolSource),
    (ID: 'SE-R-002'; Severity: eds_Error; Terms: 'BT-31';
     Message: 'the last 12 characters of a Swedish VAT identifier (BT-31) shall be numeric';
     Source: PeppolSource),
    (ID: 'SE-R-003'; Severity: eds_Error; Terms: 'BT-30';
     Message: 'a Swedish organization number (BT-30) shall be numeric';
     Source: PeppolSource),
    (ID: 'SE-R-004'; Severity: eds_Error; Terms: 'BT-30';
     Message: 'a Swedish organization number (BT-30) shall have 10 characters';
     Source: PeppolSource),
    (ID: 'SE-R-005'; Severity: eds_Error; Terms: 'BT-32';
     Message: 'the tax registration of a Swedish supplier (BT-32) shall be Godkaend foer F-skatt';
     Source: PeppolSource),
    (ID: 'SE-R-006'; Severity: eds_Error; Terms: 'BT-96, BT-103, BT-119, BT-152';
     Message: 'Swedish suppliers shall use the standard VAT rates 6, 12 or 25';
     Source: PeppolSource),
    (ID: 'SE-R-007'; Severity: eds_Warning; Terms: 'BT-84';
     Message: 'a Plusgiro account (BT-84) of a Swedish supplier should be numeric';
     Source: PeppolSource),
    (ID: 'SE-R-008'; Severity: eds_Warning; Terms: 'BT-84';
     Message: 'a Bankgiro account (BT-84) of a Swedish supplier should be numeric';
     Source: PeppolSource),
    (ID: 'SE-R-009'; Severity: eds_Warning; Terms: 'BT-84';
     Message: 'a Bankgiro account (BT-84) of a Swedish supplier should have 7 or 8 characters';
     Source: PeppolSource),
    (ID: 'SE-R-010'; Severity: eds_Warning; Terms: 'BT-84';
     Message: 'a Plusgiro account (BT-84) of a Swedish supplier should have 2 to 8 characters';
     Source: PeppolSource),
    (ID: 'SE-R-011'; Severity: eds_Warning; Terms: 'BT-81';
     Message: 'Swedish suppliers should indicate Bankgiro and Plusgiro with payment means 30';
     Source: PeppolSource),
    (ID: 'SE-R-012'; Severity: eds_Warning; Terms: 'BT-81';
     Message: 'between Swedish parties a credit transfer should be indicated with payment means 30';
     Source: PeppolSource),
    (ID: 'SE-R-013'; Severity: eds_Error; Terms: 'BT-30';
     Message: 'a Swedish organization number (BT-30) shall have a valid Luhn check digit';
     Source: PeppolSource),
    (ID: 'GR-R-001-1'; Severity: eds_Error; Terms: 'BT-1';
     Message: 'the invoice number (BT-1) of a Greek supplier shall have six segments separated by |';
     Source: PeppolSource),
    (ID: 'GR-R-001-2'; Severity: eds_Error; Terms: 'BT-1, BT-31, BT-63';
     Message: 'the first segment of the invoice number shall be the valid TIN of the seller or tax representative';
     Source: PeppolSource),
    (ID: 'GR-R-001-3'; Severity: eds_Error; Terms: 'BT-1, BT-2';
     Message: 'the second segment of the invoice number shall be the issue date (BT-2) as DD/MM/YYYY';
     Source: PeppolSource),
    (ID: 'GR-R-001-4'; Severity: eds_Error; Terms: 'BT-1';
     Message: 'the third segment of the invoice number shall be a non-negative integer';
     Source: PeppolSource),
    (ID: 'GR-R-001-5'; Severity: eds_Error; Terms: 'BT-1';
     Message: 'the fourth segment of the invoice number shall be a valid Greek document type';
     Source: PeppolSource),
    (ID: 'GR-R-001-6'; Severity: eds_Error; Terms: 'BT-1';
     Message: 'the fifth segment of the invoice number shall not be empty';
     Source: PeppolSource),
    (ID: 'GR-R-001-7'; Severity: eds_Error; Terms: 'BT-1';
     Message: 'the sixth segment of the invoice number shall not be empty';
     Source: PeppolSource),
    (ID: 'GR-R-002'; Severity: eds_Error; Terms: 'BT-28';
     Message: 'Greek suppliers shall provide their trading name (BT-28)';
     Source: PeppolSource),
    (ID: 'GR-R-003'; Severity: eds_Error; Terms: 'BT-31';
     Message: 'the VAT identifier of a Greek supplier (BT-31) shall be EL and a valid TIN';
     Source: PeppolSource),
    (ID: 'GR-R-004-1'; Severity: eds_Error; Terms: 'BG-24';
     Message: 'a Greek supplier shall provide one MARK number (document description ##M.AR.K##)';
     Source: PeppolSource),
    (ID: 'GR-R-004-2'; Severity: eds_Error; Terms: 'BT-122';
     Message: 'the MARK number shall be a positive integer';
     Source: PeppolSource),
    (ID: 'GR-R-005'; Severity: eds_Error; Terms: 'BT-45';
     Message: 'Greek suppliers shall provide the trading name of the buyer (BT-45)';
     Source: PeppolSource),
    (ID: 'GR-R-006'; Severity: eds_Error; Terms: 'BT-48';
     Message: 'a Greek buyer of a Greek supplier shall have one VAT identifier (BT-48), EL and a valid TIN';
     Source: PeppolSource),
    (ID: 'GR-R-008-2'; Severity: eds_Error; Terms: 'BG-24';
     Message: 'a Greek supplier shall provide no more than one invoice URL (##INVOICE|URL##)';
     Source: PeppolSource),
    (ID: 'GR-R-008-3'; Severity: eds_Error; Terms: 'BT-124';
     Message: 'the invoice URL reference of a Greek supplier shall have an external reference (BT-124)';
     Source: PeppolSource),
    (ID: 'GR-R-009'; Severity: eds_Error; Terms: 'BT-34';
     Message: 'the electronic address of a Greek supplier (BT-34) shall be a valid TIN with scheme 9933';
     Source: PeppolSource),
    (ID: 'GR-R-010'; Severity: eds_Error; Terms: 'BT-49';
     Message: 'the electronic address of a Greek buyer (BT-49) shall be a valid TIN with scheme 9933';
     Source: PeppolSource),
    (ID: 'GR-S-008-1'; Severity: eds_Warning; Terms: 'BG-24';
     Message: 'a Greek supplier should provide one invoice URL (##INVOICE|URL##)';
     Source: PeppolSource),
    (ID: 'GR-S-011'; Severity: eds_Warning; Terms: 'BT-31';
     Message: 'a Greek supplier should provide one VAT identifier (BT-31), EL and a valid TIN';
     Source: PeppolSource),
    (ID: 'IS-R-001'; Severity: eds_Warning; Terms: 'BT-3';
     Message: 'an Icelandic supplier should use the type code 380 or 381 (BT-3)';
     Source: PeppolSource),
    (ID: 'IS-R-002'; Severity: eds_Error; Terms: 'BT-30';
     Message: 'an Icelandic supplier shall provide the legal identifier (BT-30) with scheme 0196';
     Source: PeppolSource),
    (ID: 'IS-R-003'; Severity: eds_Error; Terms: 'BT-35, BT-38';
     Message: 'an Icelandic supplier shall provide street name (BT-35) and post code (BT-38)';
     Source: PeppolSource),
    (ID: 'IS-R-004'; Severity: eds_Error; Terms: 'BT-47';
     Message: 'an Icelandic buyer of an Icelandic supplier shall have the legal identifier (BT-47) with scheme 0196';
     Source: PeppolSource),
    (ID: 'IS-R-005'; Severity: eds_Error; Terms: 'BT-50, BT-53';
     Message: 'an Icelandic buyer of an Icelandic supplier shall have street name (BT-50) and post code (BT-53)';
     Source: PeppolSource),
    (ID: 'IS-R-006'; Severity: eds_Error; Terms: 'BT-84';
     Message: 'with payment means 9 an Icelandic supplier shall provide a 12 digit account (BT-84)';
     Source: PeppolSource),
    (ID: 'IS-R-007'; Severity: eds_Error; Terms: 'BT-84';
     Message: 'with payment means 42 an Icelandic supplier shall provide a 12 digit account (BT-84)';
     Source: PeppolSource),
    (ID: 'IS-R-008'; Severity: eds_Error; Terms: 'BT-122';
     Message: 'the EINDAGI reference of an Icelandic supplier shall be a date YYYY-MM-DD';
     Source: PeppolSource),
    (ID: 'IS-R-009'; Severity: eds_Error; Terms: 'BT-9';
     Message: 'with an EINDAGI reference an Icelandic supplier shall provide the due date (BT-9)';
     Source: PeppolSource),
    (ID: 'IS-R-010'; Severity: eds_Error; Terms: 'BT-9, BT-122';
     Message: 'the due date (BT-9) shall not be after the EINDAGI date';
     Source: PeppolSource),
    (ID: 'NL-R-001'; Severity: eds_Error; Terms: 'BT-25';
     Message: 'a credit note of a Dutch supplier shall reference the preceding invoice (BT-25)';
     Source: PeppolSource),
    (ID: 'NL-R-002'; Severity: eds_Error; Terms: 'BT-35, BT-37, BT-38';
     Message: 'a Dutch supplier shall provide street name (BT-35), city (BT-37) and post code (BT-38)';
     Source: PeppolSource),
    (ID: 'NL-R-003'; Severity: eds_Error; Terms: 'BT-30';
     Message: 'the legal identifier of a Dutch supplier (BT-30) shall be a KVK (0106) or OIN (0190) number';
     Source: PeppolSource),
    (ID: 'NL-R-004'; Severity: eds_Error; Terms: 'BT-50, BT-52, BT-53';
     Message: 'a Dutch buyer of a Dutch supplier shall have street name (BT-50), city (BT-52) and post code (BT-53)';
     Source: PeppolSource),
    (ID: 'NL-R-005'; Severity: eds_Error; Terms: 'BT-47';
     Message: 'the legal identifier of a Dutch buyer (BT-47) shall be a KVK (0106) or OIN (0190) number';
     Source: PeppolSource),
    (ID: 'NL-R-006'; Severity: eds_Error; Terms: 'BT-64, BT-66, BT-67';
     Message: 'a Dutch tax representative shall have street name (BT-64), city (BT-66) and post code (BT-67)';
     Source: PeppolSource),
    (ID: 'NL-R-007'; Severity: eds_Error; Terms: 'BG-16';
     Message: 'a Dutch supplier shall provide payment means (BG-16) when an amount is due';
     Source: PeppolSource),
    (ID: 'NL-R-008'; Severity: eds_Error; Terms: 'BT-81';
     Message: 'between Dutch parties the payment means code (BT-81) shall be 30, 48, 49, 57, 58 or 59';
     Source: PeppolSource),
    (ID: 'NL-R-009'; Severity: eds_Error; Terms: 'BT-13, BT-132';
     Message: 'a Dutch supplier with an order line reference (BT-132) shall provide the order reference (BT-13)';
     Source: PeppolSource),
    (ID: 'DE-R-001'; Severity: eds_Error; Terms: 'BG-16';
     Message: 'between German parties payment instructions (BG-16) shall be provided';
     Source: PeppolSource),
    (ID: 'DE-R-002'; Severity: eds_Error; Terms: 'BG-6';
     Message: 'between German parties the seller contact (BG-6) shall be provided';
     Source: PeppolSource),
    (ID: 'DE-R-003'; Severity: eds_Error; Terms: 'BT-37';
     Message: 'between German parties the seller city (BT-37) shall be provided';
     Source: PeppolSource),
    (ID: 'DE-R-004'; Severity: eds_Error; Terms: 'BT-38';
     Message: 'between German parties the seller post code (BT-38) shall be provided';
     Source: PeppolSource),
    (ID: 'DE-R-005'; Severity: eds_Error; Terms: 'BT-41';
     Message: 'between German parties the seller contact point (BT-41) shall be provided';
     Source: PeppolSource),
    (ID: 'DE-R-006'; Severity: eds_Error; Terms: 'BT-42';
     Message: 'between German parties the seller contact telephone number (BT-42) shall be provided';
     Source: PeppolSource),
    (ID: 'DE-R-007'; Severity: eds_Error; Terms: 'BT-43';
     Message: 'between German parties the seller contact email address (BT-43) shall be provided';
     Source: PeppolSource),
    (ID: 'DE-R-008'; Severity: eds_Error; Terms: 'BT-52';
     Message: 'between German parties the buyer city (BT-52) shall be provided';
     Source: PeppolSource),
    (ID: 'DE-R-009'; Severity: eds_Error; Terms: 'BT-53';
     Message: 'between German parties the buyer post code (BT-53) shall be provided';
     Source: PeppolSource),
    (ID: 'DE-R-010'; Severity: eds_Error; Terms: 'BT-77';
     Message: 'between German parties the deliver to city (BT-77) shall be provided';
     Source: PeppolSource),
    (ID: 'DE-R-011'; Severity: eds_Error; Terms: 'BT-78';
     Message: 'between German parties the deliver to post code (BT-78) shall be provided';
     Source: PeppolSource),
    (ID: 'DE-R-015'; Severity: eds_Error; Terms: 'BT-10';
     Message: 'between German parties the buyer reference (BT-10) shall be provided';
     Source: PeppolSource),
    (ID: 'DE-R-016'; Severity: eds_Error; Terms: 'BT-31, BT-32, BG-11';
     Message: 'between German parties a taxable VAT category requires a VAT or tax registration of the seller or a ' +
       'tax representative';
     Source: PeppolSource),
    (ID: 'DE-R-017'; Severity: eds_Warning; Terms: 'BT-3';
     Message: 'between German parties the invoice type code (BT-3) should be 326, 380, 381, 384, 389, 875, 876 or 877';
     Source: PeppolSource),
    (ID: 'DE-R-018'; Severity: eds_Error; Terms: 'BT-20';
     Message: 'between German parties cash discount lines in the payment terms (BT-20) shall have the form ' +
       '#SKONTO#TAGE=n#PROZENT=p#[BASISBETRAG=b#]';
     Source: PeppolSource),
    (ID: 'DE-R-019'; Severity: eds_Warning; Terms: 'BT-84';
     Message: 'between German parties the account of a SEPA credit transfer (BT-84) should be a valid IBAN';
     Source: PeppolSource),
    (ID: 'DE-R-020'; Severity: eds_Warning; Terms: 'BT-91';
     Message: 'between German parties the debited account of a SEPA direct debit (BT-91) should be a valid IBAN';
     Source: PeppolSource),
    (ID: 'DE-R-022'; Severity: eds_Error; Terms: 'BT-125';
     Message: 'between German parties the file names of attached documents shall be unique';
     Source: PeppolSource),
    (ID: 'DE-R-023-1'; Severity: eds_Error; Terms: 'BG-17';
     Message: 'between German parties a credit transfer (30, 58) shall have credit transfer data (BG-17)';
     Source: PeppolSource),
    (ID: 'DE-R-024-1'; Severity: eds_Error; Terms: 'BG-18';
     Message: 'between German parties a card payment (48, 54, 55) shall have card data (BG-18)';
     Source: PeppolSource),
    (ID: 'DE-R-024-2'; Severity: eds_Error; Terms: 'BG-17, BG-19';
     Message: 'between German parties a card payment (48, 54, 55) shall have no credit transfer or direct debit ' +
       'data';
     Source: PeppolSource),
    (ID: 'DE-R-025-1'; Severity: eds_Error; Terms: 'BG-19';
     Message: 'between German parties a SEPA direct debit (59) shall have direct debit data (BG-19)';
     Source: PeppolSource),
    (ID: 'DE-R-025-2'; Severity: eds_Error; Terms: 'BG-17, BG-18';
     Message: 'between German parties a SEPA direct debit (59) shall have no credit transfer or card data';
     Source: PeppolSource),
    (ID: 'DE-R-026'; Severity: eds_Warning; Terms: 'BG-3';
     Message: 'between German parties a corrected invoice (384) should reference the preceding invoice (BG-3)';
     Source: PeppolSource),
    (ID: 'DE-R-027'; Severity: eds_Warning; Terms: 'BT-42';
     Message: 'between German parties the seller contact telephone number (BT-42) should have at least three digits';
     Source: PeppolSource),
    (ID: 'DE-R-028'; Severity: eds_Warning; Terms: 'BT-43';
     Message: 'between German parties the seller contact email address (BT-43) should have the form name@domain';
     Source: PeppolSource),
    (ID: 'DE-R-030'; Severity: eds_Error; Terms: 'BT-90';
     Message: 'between German parties a direct debit (BG-19) shall have the creditor identifier (BT-90)';
     Source: PeppolSource),
    (ID: 'DE-R-031'; Severity: eds_Error; Terms: 'BT-91';
     Message: 'between German parties a direct debit (BG-19) shall have the debited account (BT-91)';
     Source: PeppolSource),
    (ID: 'DE-R-T02'; Severity: eds_Warning; Terms: 'BT-124';
     Message: 'between German parties an external document location (BT-124) should be an absolute URL';
     Source: PeppolSource));

  { The lists of the Peppol schematron 3.0.21 ($ISO4217, $MIMECODE,
    $UNCL2005, $UNCL5189, $UNCL7161, $eaid; the type codes of P0100).
    DE: Die Listen des Peppol-Schematrons 3.0.21. }
  PeppolCurrencies = 'AED AFN ALL AMD AOA ARS AUD AWG AZN BAM BBD BDT BHD BIF BMD BND BOB BOV BRL BSD BTN BWP ' +
    'BYN BZD CAD CDF CHE CHF CHW CLF CLP CNY COP COU CRC CUP CVE CZK DJF DKK DOP DZD EGP ERN ETB EUR FJD FKP GBP ' +
    'GEL GHS GIP GMD GNF GTQ GYD HKD HNL HTG HUF IDR ILS INR IQD IRR ISK JMD JOD JPY KES KGS KHR KMF KPW KRW KWD ' +
    'KYD KZT LAK LBP LKR LRD LSL LYD MAD MDL MGA MKD MMK MNT MOP MRU MUR MVR MWK MXN MXV MYR MZN NAD NGN NIO NOK ' +
    'NPR NZD OMR PAB PEN PGK PHP PKR PLN PYG QAR RON RSD RUB RWF SAR SBD SCR SDG SEK SGD SHP SLE SOS SRD SSP STN ' +
    'SVC SYP SZL THB TJS TMT TND TOP TRY TTD TWD TZS UAH UGX USD USN UYI UYU UYW UZS VED VES VND VUV WST XAF XAG ' +
    'XAU XBA XBB XBC XBD XCD XDR XOF XPD XPF XPT XSU XTS XUA YER ZAR ZMW ZWG XXX CNH XCG';
  PeppolMimeCodes = 'application/pdf image/png image/jpeg text/csv ' +
    'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet ' +
    'application/vnd.oasis.opendocument.spreadsheet';
  PeppolPeriodCodes = '3 35 432';
  PeppolAllowanceCodes = '41 42 60 62 63 64 65 66 67 68 70 71 88 95 100 102 103 104 105';
  PeppolChargeCodes = 'AA AAA AAC AAD AAE AAF AAH AAI AAS AAT AAV AAY AAZ ABA ABB ABC ABD ABF ABK ABL ABN ABR ' +
    'ABS ABT ABU ACF ACG ACH ACI ACJ ACK ACL ACM ACS ADC ADE ADJ ADK ADL ADM ADN ADO ADP ADQ ADR ADT ADW ADY ADZ ' +
    'AEA AEB AEC AED AEF AEH AEI AEJ AEK AEL AEM AEN AEO AEP AES AET AEU AEV AEW AEX AEY AEZ AJ AU CA CAB CAD ' +
    'CAE CAF CAI CAJ CAK CAL CAM CAN CAO CAP CAQ CAR CAS CAT CAU CAV CAW CAX CAY CAZ CD CG CS CT DAB DAC DAD DAF ' +
    'DAG DAH DAI DAJ DAK DAL DAM DAN DAO DAP DAQ DL EG EP ER FAA FAB FAC FC FH FI GAA HAA HD HH IAA IAB ID IF IR ' +
    'IS KO L1 LA LAA LAB LF MAE MI ML NAA OA PA PAA PC PL PRV RAB RAC RAD RAF RE RF RH RV SA SAA SAD SAE SAI SG SH ' +
    'SM SU TAB TAC TT TV V1 V2 WH XAA YY ZZZ';
  PeppolEASCodes = '0002 0007 0009 0060 0088 0096 0097 0106 0130 0135 0142 0151 0158 0183 0184 0188 0190 0191 ' +
    '0192 0195 0196 0198 0199 0200 0201 0204 0208 0209 0210 0211 0216 0218 0221 0225 0230 0235 0240 0242 0244 0245 ' +
    '0246 0248 9910 9913 9914 9915 9918 9919 9920 9922 9923 9924 9925 9926 9927 9928 9929 9930 9931 9932 9933 9934 ' +
    '9935 9936 9937 9938 9939 9940 9941 9942 9943 9944 9945 9946 9947 9948 9949 9950 9951 9952 9953 9957 9959';
  PeppolInvoiceTypeCodes = '71 80 82 84 102 218 219 326 331 380 382 383 384 386 388 393 395 553 575 623 780 817 ' +
    '870 875 876 877';

  { $profile '01' or '02' (P0100 applies only to them). DE: $profile '01'
    oder '02' (P0100 gilt nur fuer sie). }
  PeppolProfiles: array[0..3] of string = ('urn:fdc:peppol.eu:2017:poacc:billing:01:1.0',
    'urn:peppol:france:billing:regulated', 'urn:peppol:france:billing:non-regulated',
    'urn:peppol:bis:billing_with_response');

{ --- helpers ------------------------------------------------------------------- }

function Present(const S: TLandrixEInvoiceString): Boolean;
begin
  Result := not LandrixEInvoiceIsBlank(S);
end;

{ XPath contains(' list ', concat(' ', AValue, ' ')) for a value without
  blank: the exact token. }
function InList(const AValue, AList: TLandrixEInvoiceString): Boolean;
begin
  Result := (AValue <> '') and (Pos(' ', AValue) = 0) and (Pos(' ' + AValue + ' ', ' ' + AList + ' ') > 0);
end;

{ XPath upper-case for the ASCII letters. }
function UpperAscii(const AValue: TLandrixEInvoiceString): TLandrixEInvoiceString;
var
  I: Integer;
begin
  Result := AValue;
  for I := 1 to Length(Result) do
    if (Result[I] >= 'a') and (Result[I] <= 'z') then
      Result[I] := TLandrixEInvoiceChar(Ord(Result[I]) - 32);
end;

{ A code as the mapper writes it: the enumeration, otherwise the other text.
  DE: Ein Code, wie der Mapper ihn schreibt: die Aufzaehlung, sonst der
  andere Text. }
function WrittenCode(const AEnumText, AOther: TLandrixEInvoiceString): TLandrixEInvoiceString;
begin
  if Present(AEnumText) then
    Result := AEnumText
  else
    Result := AOther;
end;

{ upper-case(normalize-space(country)) = ACode for a postal address as the
  mapper writes it.
  DE: upper-case(normalize-space(Land)) = ACode fuer eine Anschrift, wie der
  Mapper sie schreibt. }
function CountryIs(AAddress: TLandrixInvoiceAddress; const ACode: TLandrixEInvoiceString): Boolean;
begin
  Result := UpperAscii(LandrixEInvoiceNormalizeSpace(AAddress.CountryCode)) = ACode;
end;

function BothInGermany(AInvoice: TLandrixInvoice): Boolean;
begin
  Result := CountryIs(AInvoice.AccountingSupplierParty.Address, 'DE') and
    CountryIs(AInvoice.AccountingCustomerParty.Address, 'DE');
end;

{ BT-23 as the mapper writes it: the business process of the invoice,
  otherwise the default of the specification.
  DE: BT-23, wie der Mapper es schreibt: der Geschaeftsprozess der
  Rechnung, sonst die Vorgabe der Spezifikation. }
function WrittenProfile(AInvoice: TLandrixInvoice; const ASpec: TLandrixEInvoiceSpec): TLandrixEInvoiceString;
begin
  if Present(AInvoice.ProfileID) then
    Result := AInvoice.ProfileID
  else
    Result := ASpec.ProfileID;
end;

function ApprovedProfile(const AProfile: TLandrixEInvoiceString): Boolean;
var
  I: Integer;
  Value: TLandrixEInvoiceString;
begin
  Result := True;
  Value := LandrixEInvoiceNormalizeSpace(AProfile);
  for I := Low(PeppolProfiles) to High(PeppolProfiles) do
    if Value = TLandrixEInvoiceString(PeppolProfiles[I]) then
      Exit;
  Result := False;
end;

{ Sub lines are written nested where the target allows them, otherwise
  flat (LandrixEInvoiceSubLines; Peppol: always flat). DE: Unterpositionen
  werden verschachtelt geschrieben, wo das Ziel sie erlaubt, sonst flach
  (LandrixEInvoiceSubLines; Peppol: immer flach). }
function SubLinesWritten(AInvoice: TLandrixInvoice; const ASpec: TLandrixEInvoiceSpec): Boolean;
begin
  Result := LandrixEInvoiceSubLinesNested(AInvoice, ASpec);
end;

{ --- written identifiers ---------------------------------------------------------- }

type
  { Where an identifier with scheme is written: cbc:EndpointID,
    cac:PartyIdentification/cbc:ID or cac:PartyLegalEntity/cbc:CompanyID.
    DE: Wo eine Kennung mit Schema geschrieben wird. }
  TIdentifierPlace = (ip_Endpoint, ip_PartyIdentification, ip_CompanyID);

  TWrittenIdentifier = record
    Place: TIdentifierPlace;
    Scheme: TLandrixEInvoiceString;
    Value: TLandrixEInvoiceString;
  end;

  TWrittenIdentifiers = array of TWrittenIdentifier;

procedure AddIdentifier(var AList: TWrittenIdentifiers; APlace: TIdentifierPlace;
  const AValue, AScheme: TLandrixEInvoiceString);
var
  N: Integer;
begin
  if not Present(AValue) or (AScheme = '') then
    Exit;
  N := Integer(Length(AList));
  SetLength(AList, N + 1);
  AList[N].Place := APlace;
  AList[N].Scheme := AScheme;
  AList[N].Value := AValue;
end;

{ The identifiers with scheme as TUBLWriteMapper writes them for Peppol:
  the electronic address of seller and buyer (no default scheme in Peppol),
  their global identifier (default scheme 0088) and legal registration, the
  payee identifier and legal registration. An identifier without scheme
  and the creditor identifier (scheme SEPA) are in no PEPPOL-COMMON rule.
  DE: Die Kennungen mit Schema, wie TUBLWriteMapper sie fuer Peppol
  schreibt: die elektronische Adresse von Verkaeufer und Kaeufer (in Peppol
  ohne Vorgabeschema), ihre globale Kennung (Vorgabeschema 0088) und
  Registernummer, Kennung und Registernummer des Zahlungsempfaengers. Eine
  Kennung ohne Schema und die Glaeubiger-ID (Schema SEPA) stehen in keiner
  PEPPOL-COMMON-Regel. }
procedure AddPartyIdentifiers(var AList: TWrittenIdentifiers; AParty: TLandrixInvoiceAccountingParty);
var
  Scheme: TLandrixEInvoiceString;
begin
  AddIdentifier(AList, ip_Endpoint, AParty.ElectronicAddressSellerBuyer, AParty.ElectronicAddressSellerBuyerSchemeID);
  if Present(AParty.GlobalIdentifierSellerBuyer) then
  begin
    Scheme := AParty.GlobalIdentifierSellerBuyerSchemeID;
    if LandrixEInvoiceIsBlank(Scheme) then
      Scheme := '0088';
    AddIdentifier(AList, ip_PartyIdentification, AParty.GlobalIdentifierSellerBuyer, Scheme);
  end;
  AddIdentifier(AList, ip_CompanyID, AParty.CompanyID, AParty.CompanyIDSchemeID);
end;

function WrittenIdentifiers(AInvoice: TLandrixInvoice): TWrittenIdentifiers;
begin
  Result := nil;
  AddPartyIdentifiers(Result, AInvoice.AccountingSupplierParty);
  AddPartyIdentifiers(Result, AInvoice.AccountingCustomerParty);
  { the payee is written when it has an identifier or legal registration }
  AddIdentifier(Result, ip_PartyIdentification, AInvoice.PayeeParty.Identifier, AInvoice.PayeeParty.IdentifierSchemeID);
  AddIdentifier(Result, ip_CompanyID, AInvoice.PayeeParty.CompanyID, AInvoice.PayeeParty.CompanyIDSchemeID);
end;

{ PEPPOL-COMMON-R040 to R057 for one identifier of their scheme; R042,
  R052 and R053 test the value as it is, the others after normalize-space.
  DE: PEPPOL-COMMON-R040 bis R057 fuer eine Kennung ihres Schemas; R042,
  R052 und R053 pruefen den Wert, wie er ist, die anderen nach
  normalize-space. }
function CommonViolated(AIndex: TPeppolRuleIndex; const AIdentifier: TWrittenIdentifier): Boolean;
var
  Scheme, Raw, Value: TLandrixEInvoiceString;
begin
  Result := False;
  Scheme := AIdentifier.Scheme;
  Raw := AIdentifier.Value;
  Value := LandrixEInvoiceNormalizeSpace(Raw);
  case AIndex of
    pr_CommonR040:
      Result := (Scheme = '0088') and not LandrixEInvoiceGS1CheckDigitValid(Value);
    pr_CommonR041:
      Result := (Scheme = '0192') and not (LandrixEInvoiceIsDigits(Value, 9) and LandrixEInvoiceMod11Valid(Value));
    pr_CommonR042:
      Result := (Scheme = '0184') and not (((Length(Raw) = 10) and (Copy(Raw, 1, 2) = 'DK') and
        LandrixEInvoiceIsDigits(Copy(Raw, 3, 8), 8)) or LandrixEInvoiceIsDigits(Raw, 8));
    pr_CommonR043:
      Result := (Scheme = '0208') and not LandrixEInvoiceBelgianEnterpriseValid(Value);
    pr_CommonR044:
      Result := (Scheme = '0201') and not LandrixEInvoiceCodiceIPAValid(Value);
    pr_CommonR045:
      Result := (Scheme = '0210') and not LandrixEInvoiceCodiceFiscaleValid(Value);
    pr_CommonR046:
      Result := (AIdentifier.Place = ip_Endpoint) and (Scheme = '9907') and
        not LandrixEInvoiceCodiceFiscaleValid(Value);
    pr_CommonR047:
      Result := (Scheme = '0211') and not LandrixEInvoicePartitaIVAValid(Value);
    pr_CommonR049:
      Result := (Scheme = '0007') and not LandrixEInvoiceSwedishOrgNumberValid(Value);
    pr_CommonR050:
      Result := (Scheme = '0151') and not LandrixEInvoiceABNValid(Value);
    pr_CommonR052:
      Result := (Scheme = '0096') and not LandrixEInvoiceIsDigits(Raw, 10);
    pr_CommonR053:
      Result := (Scheme = '0198') and not ((Length(Raw) = 10) and (Copy(Raw, 1, 2) = 'DK') and
        LandrixEInvoiceIsDigits(Copy(Raw, 3, 8), 8));
    pr_CommonR054:
      Result := (Scheme = '0106') and not LandrixEInvoiceIsDigits(Value, 8);
    pr_CommonR055:
      Result := (Scheme = '0190') and not LandrixEInvoiceIsDigits(Value, 20);
    pr_CommonR0561:
      Result := (Scheme = '9944') and not ((Length(Value) = 14) and (Copy(Value, 1, 2) = 'NL') and
        LandrixEInvoiceIsDigits(Copy(Value, 3, 9), 9) and (Value[12] = 'B') and
        LandrixEInvoiceIsDigits(Copy(Value, 13, 2), 2));
    pr_CommonR057:
      Result := (Scheme = '0217') and not LandrixEInvoiceIsDigits(Value, 12);
  else
    { the other rules are no identifier rules }
    ;
  end;
end;

{ PEPPOL-COMMON-R056-2: a VAT identifier (cac:PartyTaxScheme with VAT)
  starting with NL after normalize-space; written for seller, buyer and
  tax representative.
  DE: PEPPOL-COMMON-R056-2: eine USt-IdNr. (cac:PartyTaxScheme mit VAT),
  die nach normalize-space mit NL beginnt; geschrieben fuer Verkaeufer,
  Kaeufer und Steuervertreter. }
function DutchVATWrong(const AVATID: TLandrixEInvoiceString): Boolean;
var
  Value: TLandrixEInvoiceString;
begin
  Value := LandrixEInvoiceNormalizeSpace(AVATID);
  Result := (Copy(Value, 1, 2) = 'NL') and not ((Length(Value) = 14) and
    LandrixEInvoiceIsDigits(Copy(Value, 3, 9), 9) and (Value[12] = 'B') and
    LandrixEInvoiceIsDigits(Copy(Value, 13, 2), 2));
end;

{ --- code lists ---------------------------------------------------------------- }

{ CL002, CL003: the reason code of every allowance or charge as written
  (document level, lines and, in ubl:Invoice, sub lines).
  DE: CL002, CL003: der Grundcode jedes Nachlasses oder Zuschlags, wie er
  geschrieben wird (Dokumentebene, Positionen und in ubl:Invoice
  Unterpositionen). }
function ReasonWrong(AIndex: TPeppolRuleIndex; AItem: TLandrixInvoiceAllowanceCharge): Boolean;
var
  Code: TLandrixEInvoiceString;
begin
  if AIndex = pr_CL002 then
  begin
    Code := WrittenCode(LandrixEInvoiceAllowanceOrChargeIdentCodeToStr(AItem.ReasonCodeAllowance),
      AItem.ReasonCodeAllowanceOther);
    Result := not AItem.ChargeIndicator and Present(Code) and
      not InList(LandrixEInvoiceNormalizeSpace(Code), PeppolAllowanceCodes);
  end
  else
  begin
    Code := WrittenCode(LandrixEInvoiceSpecialServiceDescriptionCodeToStr(AItem.ReasonCodeCharge),
      AItem.ReasonCodeChargeOther);
    Result := AItem.ChargeIndicator and Present(Code) and
      not InList(LandrixEInvoiceNormalizeSpace(Code), PeppolChargeCodes);
  end;
end;

function LineReasonWrong(AIndex: TPeppolRuleIndex; ALines: TLandrixInvoiceLines; ASubLines: Boolean): Boolean;
var
  I, J: TLandrixEInvoiceListIndex;
begin
  Result := True;
  for I := 0 to ALines.Count - 1 do
  begin
    for J := 0 to ALines[I].AllowanceCharges.Count - 1 do
      if ReasonWrong(AIndex, ALines[I].AllowanceCharges[J]) then
        Exit;
    if ASubLines and LineReasonWrong(AIndex, ALines[I].SubInvoiceLines, True) then
      Exit;
  end;
  Result := False;
end;

{ CL001: the MIME code of every embedded attachment as written: BT-17
  (type 50) is no attachment in UBL, BT-18 (type 130) only the first with
  an identifier; @mimeCode is compared exactly.
  DE: CL001: der MIME-Code jeder eingebetteten Anlage, wie er geschrieben
  wird: BT-17 (Art 50) ist in UBL keine Anlage, BT-18 (Art 130) nur die
  erste mit Kennung; @mimeCode wird genau verglichen. }
function MimeCodeWrong(AInvoice: TLandrixInvoice): Boolean;
var
  I: TLandrixEInvoiceListIndex;
  Attachment: TLandrixInvoiceAttachment;
  ObjectWritten: Boolean;
  Code: TLandrixEInvoiceString;
begin
  Result := True;
  ObjectWritten := False;
  for I := 0 to AInvoice.Attachments.Count - 1 do
  begin
    Attachment := AInvoice.Attachments[I];
    if Attachment.TypeCode = iatc_50 then
      Continue;
    if Attachment.TypeCode = iatc_130 then
    begin
      if ObjectWritten or not Present(Attachment.ID) then
        Continue;
      ObjectWritten := True;
    end;
    if not Attachment.ContainsBinaryObject then
      Continue;
    Code := WrittenCode(LandrixEInvoiceAttachmentTypeToStr(Attachment.AttachmentType), Attachment.AttachmentTypeOther);
    if (Code <> '') and not InList(Code, PeppolMimeCodes) then
      Exit;
  end;
  Result := False;
end;

{ P0104 to P0111: the VAT category of a VAT breakdown with the exemption
  reason code (upper-case, not normalized).
  DE: P0104 bis P0111: die Umsatzsteuerkategorie einer
  Steueraufschluesselung mit dem Befreiungsgrund-Code (upper-case, nicht
  normalisiert). }
function ExemptionCategoryWrong(AIndex: TPeppolRuleIndex; AInvoice: TLandrixInvoice): Boolean;
const
  Exemptions: array[pr_P0104..pr_P0111] of string = ('VATEX-EU-G', 'VATEX-EU-O', 'VATEX-EU-IC', 'VATEX-EU-AE',
    'VATEX-EU-D', 'VATEX-EU-F', 'VATEX-EU-I', 'VATEX-EU-J');
  Categories: array[pr_P0104..pr_P0111] of string = ('G', 'O', 'K', 'AE', 'E', 'E', 'E', 'E');
var
  I: TLandrixEInvoiceListIndex;
  Subtotal: TLandrixInvoiceTaxAmount;
begin
  Result := True;
  for I := 0 to AInvoice.TaxAmountSubtotals.Count - 1 do
  begin
    Subtotal := AInvoice.TaxAmountSubtotals[I];
    if Present(Subtotal.TaxExemptionReasonCode) and
       (UpperAscii(Subtotal.TaxExemptionReasonCode) = TLandrixEInvoiceString(Exemptions[AIndex])) and
       (LandrixEInvoiceNormalizeSpace(WrittenCode(LandrixEInvoiceDutyTaxFeeCategoryCodeToStr(Subtotal.TaxCategory),
         Subtotal.TaxCategoryOther)) <> TLandrixEInvoiceString(Categories[AIndex])) then
      Exit;
  end;
  Result := False;
end;

{ --- national rules: countries ---------------------------------------------------- }

{ The country code as written ('' when it is not written).
  DE: Der Laendercode, wie er geschrieben wird ('' wenn er nicht
  geschrieben wird). }
function WrittenCountry(AAddress: TLandrixInvoiceAddress): TLandrixEInvoiceString;
begin
  if Present(AAddress.CountryCode) then
    Result := AAddress.CountryCode
  else
    Result := '';
end;

{ upper-case(normalize-space(substring(VAT identifier, 1, 2))) }
function VATCountry(const AVATID: TLandrixEInvoiceString): TLandrixEInvoiceString;
begin
  Result := UpperAscii(LandrixEInvoiceNormalizeSpace(Copy(AVATID, 1, 2)));
end;

{ $supplierCountry (ATaxRepresentative) and $accountingSupplierCountry,
  $customerCountry of the schematron: the prefix of the VAT identifier,
  else (supplier) that of the tax representative, else the postal country,
  else XX; upper case.
  DE: $supplierCountry (ATaxRepresentative) und $accountingSupplierCountry,
  $customerCountry des Schematrons: das Praefix der USt-IdNr., sonst
  (Verkaeufer) das des Steuervertreters, sonst das Land der Anschrift,
  sonst XX; in Grossbuchstaben. }
function PartyCountry(AParty: TLandrixInvoiceAccountingParty; ATaxRepresentative: TLandrixInvoiceParty):
  TLandrixEInvoiceString;
begin
  if Present(AParty.VATCompanyID) then
    Result := VATCountry(AParty.VATCompanyID)
  else if (ATaxRepresentative <> nil) and Present(ATaxRepresentative.VATCompanyID) then
    Result := VATCountry(ATaxRepresentative.VATCompanyID)
  else if Present(AParty.Address.CountryCode) then
    Result := UpperAscii(LandrixEInvoiceNormalizeSpace(AParty.Address.CountryCode))
  else
    Result := 'XX';
end;

function SupplierCountry(AInvoice: TLandrixInvoice): TLandrixEInvoiceString;
begin
  Result := PartyCountry(AInvoice.AccountingSupplierParty, AInvoice.TaxRepresentativeParty);
end;

function GreekCountry(const ACountry: TLandrixEInvoiceString): Boolean;
begin
  Result := (ACountry = 'GR') or (ACountry = 'EL');
end;

{ --- national rules: helpers ------------------------------------------------------ }

type
  { What a payment instruction carries as written: the mandate (codes 49
    and 59), the card (48, 54, 55) or the payee account.
    DE: Was eine Zahlungsanweisung geschrieben traegt: das Mandat (Codes 49
    und 59), die Karte (48, 54, 55) oder das Konto des Zahlungsempfaengers. }
  TPaymentGroup = (pg_Mandate, pg_Card, pg_Payee);

function PaymentWritten(APayment: TLandrixInvoicePaymentType): Boolean;
begin
  Result := (APayment.PaymentMeansCode <> ipmc_NotImplemented) or Present(APayment.PaymentMeansCodeOther);
end;

function PaymentCode(APayment: TLandrixInvoicePaymentType): TLandrixEInvoiceString;
begin
  Result := WrittenCode(LandrixEInvoicePaymentMeansCodeToStr(APayment.PaymentMeansCode),
    APayment.PaymentMeansCodeOther);
end;

function PaymentGroup(APayment: TLandrixInvoicePaymentType): TPaymentGroup;
begin
  if APayment.PaymentMeansCode in [ipmc_DirectDebit, ipmc_SEPADirectDebit] then
    Result := pg_Mandate
  else if APayment.PaymentMeansCode in [ipmc_BankCard, ipmc_CreditCard, ipmc_DebitCard] then
    Result := pg_Card
  else
    Result := pg_Payee;
end;

{ cac:PayeeFinancialAccount/cbc:ID as written ('' when there is none).
  DE: cac:PayeeFinancialAccount/cbc:ID, wie es geschrieben wird. }
function PayeeAccount(APayment: TLandrixInvoicePaymentType): TLandrixEInvoiceString;
begin
  if (PaymentGroup(APayment) = pg_Payee) and Present(APayment.FinancialAccount) then
    Result := APayment.FinancialAccount
  else
    Result := '';
end;

function PayeeBranch(APayment: TLandrixInvoicePaymentType): TLandrixEInvoiceString;
begin
  if (PayeeAccount(APayment) <> '') and Present(APayment.FinancialInstitutionBranch) then
    Result := APayment.FinancialInstitutionBranch
  else
    Result := '';
end;

{ cac:PaymentMandate/cac:PayerFinancialAccount/cbc:ID as written.
  DE: cac:PaymentMandate/cac:PayerFinancialAccount/cbc:ID, wie geschrieben. }
function PayerAccount(APayment: TLandrixInvoicePaymentType): TLandrixEInvoiceString;
begin
  if (PaymentGroup(APayment) = pg_Mandate) and Present(APayment.FinancialAccount) then
    Result := APayment.FinancialAccount
  else
    Result := '';
end;

function MandateWritten(AInvoice: TLandrixInvoice; APayment: TLandrixInvoicePaymentType): Boolean;
begin
  Result := (PaymentGroup(APayment) = pg_Mandate) and (Present(AInvoice.PaymentMandateID) or
    Present(APayment.FinancialAccount));
end;

function AnyPaymentWritten(AInvoice: TLandrixInvoice): Boolean;
var
  I: TLandrixEInvoiceListIndex;
begin
  Result := True;
  for I := 0 to AInvoice.PaymentTypes.Count - 1 do
    if PaymentWritten(AInvoice.PaymentTypes[I]) then
      Exit;
  Result := False;
end;

{ cbc:PaymentID as written ('' when there is none). DE: cbc:PaymentID, wie
  es geschrieben wird. }
function PaymentID(AInvoice: TLandrixInvoice): TLandrixEInvoiceString;
begin
  if Present(AInvoice.PaymentID) then
    Result := AInvoice.PaymentID
  else
    Result := '';
end;

{ XPath number() of a text: NaN is False. xs:double after collapsing the
  blanks around it: sign, digits with an optional fraction, an optional
  exponent, or INF.
  DE: XPath number() eines Texts: NaN ist False. }
function XPathNumber(const AText: TLandrixEInvoiceString; out AValue: Double): Boolean;
var
  S: string;
  I, Code: Integer;
  Digits, Exponent: Boolean;
begin
  Result := False;
  AValue := 0;
  S := string(LandrixEInvoiceNormalizeSpace(AText));
  if (S = 'INF') or (S = '-INF') then
  begin
    Result := True;
    { any value beyond the ranges the rules test; 1E22 is exact as Double }
    if S = 'INF' then
      AValue := 1E22
    else
      AValue := -1E22;
    Exit;
  end;
  if S = '' then
    Exit;
  I := 1;
  if (S[1] = '+') or (S[1] = '-') then
    Inc(I);
  Digits := False;
  Exponent := False;
  while I <= Length(S) do
  begin
    if (S[I] >= '0') and (S[I] <= '9') then
      Digits := True
    else if (S[I] = '.') and not Exponent and (Pos('.', Copy(S, 1, I - 1)) = 0) then
      { one point before the exponent }
    else if ((S[I] = 'e') or (S[I] = 'E')) and Digits and not Exponent then
    begin
      Exponent := True;
      Digits := False;
      if (I < Length(S)) and ((S[I + 1] = '+') or (S[I + 1] = '-')) then
        Inc(I);
    end
    else
      Exit;
    Inc(I);
  end;
  if not Digits then
    Exit;
  Val(S, AValue, Code);
  Result := Code = 0;
end;

function IsXPathNumber(const AText: TLandrixEInvoiceString): Boolean;
var
  Value: Double;
begin
  Result := XPathNumber(AText, Value);
end;

{ The sign of a decimal text: -1, 0 or 1 (the digits decide, not the
  sign of a zero). DE: Das Vorzeichen eines Dezimaltexts. }
function AmountSignOf(const AText: TLandrixEInvoiceString): Integer;
var
  I: Integer;
begin
  Result := 0;
  for I := 1 to Length(AText) do
    if (AText[I] >= '1') and (AText[I] <= '9') then
      Result := 1;
  if (Result = 1) and (Pos('-', AText) = 1) then
    Result := -1;
end;

{ The sign of an amount as written (two decimals). DE: Das Vorzeichen eines
  Betrags, wie er geschrieben wird (zwei Nachkommastellen). }
function AmountSign(AValue: Currency): Integer;
begin
  Result := AmountSignOf(LandrixEInvoiceAmountToLexical(AValue));
end;

type
  { Raised where a rule formats a number the writers cannot format
    (LandrixEInvoiceCheckInvoice reports the number); the rule then holds.
    Only this exception is caught.
    DE: Ausgeloest, wo eine Regel eine Zahl formatiert, die die Writer
    nicht formatieren koennen (LandrixEInvoiceCheckInvoice meldet die
    Zahl); die Regel gilt dann als erfuellt. Nur diese Ausnahme wird
    abgefangen. }
  EUnwritableNumber = class(Exception);

{ The rate as written (two decimals); EUnwritableNumber for NaN, infinite
  and 1e23 and above.
  DE: Der Satz, wie er geschrieben wird (zwei Nachkommastellen);
  EUnwritableNumber fuer NaN, unendlich und ab 1e23. }
function PercentLexical(APercent: Double): TLandrixEInvoiceString;
begin
  try
    Result := LandrixEInvoicePercentToLexical(APercent);
  except
    on ELandrixXmlError do
      raise EUnwritableNumber.Create('number cannot be formatted');
  end;
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
    PercentLexical(AInvoice.PaymentTermCashDiscount1Percent);
  if AInvoice.PaymentTermsType in [iptt_CashDiscount2, iptt_CashDiscount3] then
    PercentLexical(AInvoice.PaymentTermCashDiscount2Percent);
  if AInvoice.PaymentTermsType = iptt_CashDiscount3 then
    PercentLexical(AInvoice.PaymentTermCashDiscount3Percent);
  Result := LandrixEInvoicePaymentTermsText(AInvoice);
end;

{ SE-R-006: number(cbc:Percent) is 25, 12 or 6 (written with two
  decimals). DE: SE-R-006: der Satz ist 25, 12 oder 6. }
function StandardSwedishRate(APercent: Double): Boolean;
var
  Value: Double;
begin
  Result := XPathNumber(PercentLexical(APercent), Value) and
    ((Value = 25) or (Value = 12) or (Value = 6));
end;

{ IT-R-001: 11 to 16 capital letters or digits after normalize-space.
  DE: IT-R-001: 11 bis 16 Grossbuchstaben oder Ziffern nach
  normalize-space. }
function ItalianTaxNumberValid(const AValue: TLandrixEInvoiceString): Boolean;
var
  S: TLandrixEInvoiceString;
  I: Integer;
begin
  S := LandrixEInvoiceNormalizeSpace(AValue);
  Result := False;
  if (Length(S) < 11) or (Length(S) > 16) then
    Exit;
  for I := 1 to Length(S) do
    if not (((S[I] >= 'A') and (S[I] <= 'Z')) or ((S[I] >= '0') and (S[I] <= '9'))) then
      Exit;
  Result := True;
end;

{ upper-case for ASCII and the Latin-1 letters (SE-R-005 compares
  GODKAEND FOER F-SKATT with umlauts).
  DE: upper-case fuer ASCII und die Latin-1-Buchstaben. }
function UpperLatin1(const AValue: TLandrixEInvoiceString): TLandrixEInvoiceString;
var
  I: Integer;
begin
  Result := UpperAscii(AValue);
  for I := 1 to Length(Result) do
    if (Ord(Result[I]) >= $E0) and (Ord(Result[I]) <= $FE) and (Ord(Result[I]) <> $F7) then
      Result[I] := TLandrixEInvoiceChar(Ord(Result[I]) - 32);
end;

{ The additional document references as the UBL mapper writes them (BT-17
  is no such reference, BT-18 only the first with an identifier; a credit
  note adds BT-11 without description).
  DE: Die weiteren Dokumentreferenzen, wie der UBL-Mapper sie schreibt. }
function ReferenceWritten(AInvoice: TLandrixInvoice; AIndex: TLandrixEInvoiceListIndex): Boolean;
var
  I: TLandrixEInvoiceListIndex;
  A: TLandrixInvoiceAttachment;
begin
  A := AInvoice.Attachments[AIndex];
  Result := False;
  if A.TypeCode = iatc_50 then
    Exit;
  if A.TypeCode = iatc_130 then
  begin
    if not Present(A.ID) then
      Exit;
    for I := 0 to AIndex - 1 do
      if (AInvoice.Attachments[I].TypeCode = iatc_130) and Present(AInvoice.Attachments[I].ID) then
        Exit;
  end;
  Result := True;
end;

{ The written references whose cbc:DocumentDescription is ADescription.
  DE: Die geschriebenen Referenzen mit der Beschreibung ADescription. }
function CountDescribed(AInvoice: TLandrixInvoice; const ADescription: TLandrixEInvoiceString): Integer;
var
  I: TLandrixEInvoiceListIndex;
begin
  Result := 0;
  for I := 0 to AInvoice.Attachments.Count - 1 do
    if ReferenceWritten(AInvoice, I) and Present(AInvoice.Attachments[I].DocumentDescription) and
       (AInvoice.Attachments[I].DocumentDescription = ADescription) then
      Inc(Result);
end;

function FirstDescribed(AInvoice: TLandrixInvoice; const ADescription: TLandrixEInvoiceString):
  TLandrixInvoiceAttachment;
var
  I: TLandrixEInvoiceListIndex;
begin
  Result := nil;
  for I := 0 to AInvoice.Attachments.Count - 1 do
    if ReferenceWritten(AInvoice, I) and Present(AInvoice.Attachments[I].DocumentDescription) and
       (AInvoice.Attachments[I].DocumentDescription = ADescription) then
    begin
      Result := AInvoice.Attachments[I];
      Exit;
    end;
end;

{ The preceding invoice references as written: the first, the others where
  the target allows several; AWithID: only cbc:ID counts (NL-R-001),
  otherwise also a reference with its issue date only (DE-R-026).
  DE: Die Verweise auf vorausgegangene Rechnungen, wie geschrieben; AWithID:
  nur cbc:ID zaehlt (NL-R-001), sonst auch ein Verweis nur mit Datum
  (DE-R-026). }
function PrecedingWritten(AInvoice: TLandrixInvoice; const ASpec: TLandrixEInvoiceSpec; AWithID: Boolean): Boolean;
var
  I: TLandrixEInvoiceListIndex;
  Reference: TLandrixInvoicePrecedingInvoiceReference;
begin
  Result := True;
  for I := 0 to AInvoice.PrecedingInvoiceReferences.Count - 1 do
  begin
    Reference := AInvoice.PrecedingInvoiceReferences[I];
    if ((I = 0) or (LandrixEInvoiceRuleLevel(ASpec, LandrixEInvoiceRuleMultiplePrecedingInvoices) <> erl_Forbidden))
       and (Present(Reference.ID) or (not AWithID and (Reference.IssueDate > 0))) then
      Exit;
  end;
  Result := False;
end;

{ The identifier without scheme next to a global one, as the mapper writes
  it (both only where the rule table allows it).
  DE: Die Kennung ohne Schema neben einer globalen, wie der Mapper sie
  schreibt. }
function PlainIdentifierWritten(AParty: TLandrixInvoiceAccountingParty; const ASpec: TLandrixEInvoiceSpec;
  AIsSeller: Boolean): Boolean;
var
  Key: string;
begin
  if AIsSeller then
    Key := LandrixEInvoiceRuleSellerIDWithGlobalID
  else
    Key := LandrixEInvoiceRuleBuyerIDWithGlobalID;
  Result := Present(AParty.IdentifierSellerBuyer) and not (Present(AParty.GlobalIdentifierSellerBuyer) and
    (LandrixEInvoiceRuleLevel(ASpec, Key) = erl_Forbidden));
end;

function GlobalScheme(AParty: TLandrixInvoiceAccountingParty): TLandrixEInvoiceString;
begin
  Result := AParty.GlobalIdentifierSellerBuyerSchemeID;
  if LandrixEInvoiceIsBlank(Result) then
    Result := '0088';
end;

{ The payee is written with a name, identifier or legal registration; then
  it carries the creditor identifier.
  DE: Der Zahlungsempfaenger wird mit Name, Kennung oder Registernummer
  geschrieben; dann traegt er die Glaeubiger-ID. }
function PayeeWritten(AInvoice: TLandrixInvoice): Boolean;
begin
  Result := Present(AInvoice.PayeeParty.Name) or Present(AInvoice.PayeeParty.Identifier) or
    Present(AInvoice.PayeeParty.CompanyID);
end;

function AddressWritten(AAddress: TLandrixInvoiceAddress): Boolean;
begin
  Result := Present(AAddress.StreetName) or Present(AAddress.AdditionalStreetName) or
    Present(AAddress.AddressLine) or Present(AAddress.City) or Present(AAddress.PostalZone) or
    Present(AAddress.CountrySubentity) or Present(AAddress.CountryCode);
end;

function TaxRepresentativeWritten(AInvoice: TLandrixInvoice): Boolean;
var
  P: TLandrixInvoiceParty;
begin
  P := AInvoice.TaxRepresentativeParty;
  Result := Present(P.Name) or Present(P.Identifier) or Present(P.CompanyID) or Present(P.VATCompanyID) or
    AddressWritten(P.Address) or Present(P.ContactName) or Present(P.ContactDepartment) or
    Present(P.ContactTelephone) or Present(P.ContactElectronicMail);
end;

function ContactWritten(AParty: TLandrixInvoiceAccountingParty): Boolean;
begin
  Result := Present(AParty.ContactName) or Present(AParty.ContactDepartment) or Present(AParty.ContactTelephone) or
    Present(AParty.ContactElectronicMail);
end;

{ The seller's cac:PartyTaxScheme other than VAT: the tax number with
  scheme FC. DE: Das cac:PartyTaxScheme des Verkaeufers ausser VAT: die
  Steuernummer mit Schema FC. }
function SellerTaxNumber(AInvoice: TLandrixInvoice): TLandrixEInvoiceString;
begin
  if Present(AInvoice.AccountingSupplierParty.VATCompanyNumber) then
    Result := AInvoice.AccountingSupplierParty.VATCompanyNumber
  else
    Result := '';
end;

{ Tokens of AText split at ASeparator (XPath tokenize; '' has none).
  DE: Teile von AText an ASeparator (XPath tokenize; '' hat keine). }
function Segment(const AText: TLandrixEInvoiceString; ASeparator: TLandrixEInvoiceChar; AIndex: Integer;
  out ACount: Integer): TLandrixEInvoiceString;
var
  I, N, Start: Integer;
begin
  Result := '';
  ACount := 0;
  if AText = '' then
    Exit;
  N := 1;
  Start := 1;
  for I := 1 to Length(AText) + 1 do
    if (I > Length(AText)) or (AText[I] = ASeparator) then
    begin
      if N = AIndex then
        Result := Copy(AText, Start, I - Start);
      Inc(N);
      Start := I + 1;
    end;
  ACount := N - 1;
end;

function SegmentAt(const AText: TLandrixEInvoiceString; AIndex: Integer): TLandrixEInvoiceString;
var
  Count: Integer;
begin
  Result := Segment(AText, '|', AIndex, Count);
end;

{ castable as xs:date for ten characters YYYY-MM-DD. }
function IsDate(const AText: TLandrixEInvoiceString): Boolean;
const
  Days: array[1..12] of Integer = (31, 29, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31);
var
  Y, M, D: Integer;
begin
  Result := False;
  if (Length(AText) <> 10) or (AText[5] <> '-') or (AText[8] <> '-') or
     not LandrixEInvoiceIsDigits(Copy(AText, 1, 4), 4) or not LandrixEInvoiceIsDigits(Copy(AText, 6, 2), 2) or
     not LandrixEInvoiceIsDigits(Copy(AText, 9, 2), 2) then
    Exit;
  Y := StrToInt(string(Copy(AText, 1, 4)));
  M := StrToInt(string(Copy(AText, 6, 2)));
  D := StrToInt(string(Copy(AText, 9, 2)));
  if (Y = 0) or (M < 1) or (M > 12) or (D < 1) or (D > Days[M]) then
    Exit;
  Result := (M <> 2) or (D < 29) or ((Y mod 4 = 0) and ((Y mod 100 <> 0) or (Y mod 400 = 0)));
end;

{ GR-R-001-3: the second segment is DD/MM/YYYY of the issue date (the
  pattern $dateRegExp needs a year 19xx or 20xx).
  DE: GR-R-001-3: das zweite Segment ist TT/MM/JJJJ des Rechnungsdatums. }
function GreekDateValid(AInvoice: TLandrixInvoice; const ASegment: TLandrixEInvoiceString): Boolean;
var
  Issue: TLandrixEInvoiceString;
  Count: Integer;
begin
  Result := False;
  if (AInvoice.InvoiceIssueDate <= 0) or (LandrixEInvoiceNormalizeSpace(ASegment) = '') then
    Exit;
  Issue := LandrixEInvoiceDateToUBL(AInvoice.InvoiceIssueDate);
  Result := (Segment(ASegment, '/', 1, Count) = Copy(Issue, 9, 2)) and
    (Segment(ASegment, '/', 2, Count) = Copy(Issue, 6, 2)) and (Segment(ASegment, '/', 3, Count) = Copy(Issue, 1, 4)) and
    ((Copy(Issue, 1, 2) = '19') or (Copy(Issue, 1, 2) = '20'));
end;

{ GR-R-001-2: the first segment is a TIN (nine characters after
  normalize-space) and the VAT identifier of seller or tax representative
  without its prefix.
  DE: GR-R-001-2: das erste Segment ist eine Steuernummer und die USt-IdNr.
  von Verkaeufer oder Steuervertreter ohne Praefix. }
function GreekIssuerValid(AInvoice: TLandrixInvoice; const ASegment: TLandrixEInvoiceString): Boolean;
begin
  Result := (Length(LandrixEInvoiceNormalizeSpace(ASegment)) = 9) and LandrixEInvoiceGreekTINValid(ASegment) and
    ((Present(AInvoice.AccountingSupplierParty.VATCompanyID) and
    (ASegment = Copy(AInvoice.AccountingSupplierParty.VATCompanyID, 3, 9))) or
    (Present(AInvoice.TaxRepresentativeParty.VATCompanyID) and
    (ASegment = Copy(AInvoice.TaxRepresentativeParty.VATCompanyID, 3, 9))));
end;

function GreekVATValid(const AVATID: TLandrixEInvoiceString): Boolean;
begin
  Result := (Copy(AVATID, 1, 2) = 'EL') and LandrixEInvoiceGreekTINValid(Copy(AVATID, 3, Length(AVATID) - 2));
end;

{ DK-R-004: a reason of four characters that is a number from 0 to 9999,
  or a reason with # inside.
  DE: DK-R-004: ein Grund aus vier Zeichen, der eine Zahl von 0 bis 9999
  ist, oder ein Grund mit # im Inneren. }
function DanishReasonValid(const AReason: TLandrixEInvoiceString): Boolean;
var
  Value: Double;
begin
  Result := (Length(LandrixEInvoiceNormalizeSpace(AReason)) = 4) and XPathNumber(AReason, Value) and
    (Value >= 0) and (Value <= 9999);
  if not Result then
    Result := Present(AReason) and (Pos('#', AReason) > 0) and (AReason[1] <> '#') and
      (AReason[Length(AReason)] <> '#');
end;

function DanishAllowanceWrong(AItem: TLandrixInvoiceAllowanceCharge): Boolean;
var
  Code: TLandrixEInvoiceString;
begin
  if AItem.ChargeIndicator then
    Code := WrittenCode(LandrixEInvoiceSpecialServiceDescriptionCodeToStr(AItem.ReasonCodeCharge),
      AItem.ReasonCodeChargeOther)
  else
    Code := WrittenCode(LandrixEInvoiceAllowanceOrChargeIdentCodeToStr(AItem.ReasonCodeAllowance),
      AItem.ReasonCodeAllowanceOther);
  Result := (Code = 'ZZZ') and not DanishReasonValid(AItem.Reason);
end;

function DanishLineAllowanceWrong(ALines: TLandrixInvoiceLines; ASubLines: Boolean): Boolean;
var
  I, J: TLandrixEInvoiceListIndex;
begin
  Result := True;
  for I := 0 to ALines.Count - 1 do
  begin
    for J := 0 to ALines[I].AllowanceCharges.Count - 1 do
      if DanishAllowanceWrong(ALines[I].AllowanceCharges[J]) then
        Exit;
    if ASubLines and DanishLineAllowanceWrong(ALines[I].SubInvoiceLines, True) then
      Exit;
  end;
  Result := False;
end;

{ DK-R-003 on one line: a classification with listID TST needs one with
  an UNSPSC version (general comparison over the written classifications).
  DE: DK-R-003 an einer Position. }
function DanishClassificationWrong(ALine: TLandrixInvoiceLine): Boolean;
var
  I: TLandrixEInvoiceListIndex;
  C: TLandrixInvoiceLineItemClassification;
  Test, Version: Boolean;
begin
  Test := False;
  Version := False;
  for I := 0 to ALine.ItemClassifications.Count - 1 do
  begin
    C := ALine.ItemClassifications[I];
    if not Present(C.ClassCode) or not Present(C.ListID) then
      Continue;
    if C.ListID = 'TST' then
      Test := True;
    if (C.ListVersionID = '19.05.01') or (C.ListVersionID = '19.0501') or (C.ListVersionID = '26.08.01') or
       (C.ListVersionID = '26.0801') then
      Version := True;
  end;
  Result := Test and not Version;
end;

{ DE-R-016: the written VAT category codes of the document level
  allowances and charges and of the lines (cac:InvoiceLine only).
  DE: DE-R-016: die geschriebenen Kategorien der Nachlaesse und Zuschlaege
  und der Positionen. }
function GermanTaxableCategory(AInvoice: TLandrixInvoice): Boolean;

  function Supported(const ACode: TLandrixEInvoiceString): Boolean;
  begin
    Result := InList(ACode, 'S Z E AE K G L M');
  end;

var
  I: TLandrixEInvoiceListIndex;
  Item: TLandrixInvoiceAllowanceCharge;
begin
  Result := True;
  for I := 0 to AInvoice.AllowanceCharges.Count - 1 do
  begin
    Item := AInvoice.AllowanceCharges[I];
    if Supported(WrittenCode(LandrixEInvoiceDutyTaxFeeCategoryCodeToStr(Item.TaxCategory), Item.TaxCategoryOther)) then
      Exit;
  end;
  for I := 0 to AInvoice.InvoiceLines.Count - 1 do
    if Supported(WrittenCode(LandrixEInvoiceDutyTaxFeeCategoryCodeToStr(AInvoice.InvoiceLines[I].TaxCategory),
       AInvoice.InvoiceLines[I].TaxCategoryOther)) then
      Exit;
  Result := False;
end;

{ DE-R-022: a written reference with an embedded object whose file name an
  earlier one has.
  DE: DE-R-022: eine geschriebene Referenz mit eingebettetem Objekt, deren
  Dateiname eine fruehere schon hat. }
function GermanDuplicateFilename(AInvoice: TLandrixInvoice): Boolean;
var
  I, K: TLandrixEInvoiceListIndex;
  A: TLandrixInvoiceAttachment;
begin
  Result := True;
  for I := 0 to AInvoice.Attachments.Count - 1 do
  begin
    A := AInvoice.Attachments[I];
    if not ReferenceWritten(AInvoice, I) or not A.ContainsBinaryObject or (A.Filename = '') then
      Continue;
    for K := 0 to I - 1 do
      if ReferenceWritten(AInvoice, K) and AInvoice.Attachments[K].ContainsBinaryObject and
         (AInvoice.Attachments[K].Filename = A.Filename) then
        Exit;
  end;
  Result := False;
end;

{ DE-R-T02: the pattern ^([a-zA-Z])([a-zA-Z0-9+.-])+: of an absolute URL.
  DE: DE-R-T02: das Muster einer absoluten URL. }
function AbsoluteURL(const AURI: TLandrixEInvoiceString): Boolean;
var
  I: Integer;
  C: TLandrixEInvoiceChar;
begin
  Result := False;
  if (Length(AURI) < 3) or not (((AURI[1] >= 'a') and (AURI[1] <= 'z')) or ((AURI[1] >= 'A') and (AURI[1] <= 'Z'))) then
    Exit;
  for I := 2 to Length(AURI) do
  begin
    C := AURI[I];
    if (C = ':') and (I > 2) then
    begin
      Result := True;
      Exit;
    end;
    if not (((C >= 'a') and (C <= 'z')) or ((C >= 'A') and (C <= 'Z')) or ((C >= '0') and (C <= '9')) or
       (C = '+') or (C = '.') or (C = '-')) then
      Exit;
  end;
end;

{ DE-R-019, DE-R-020: the IBAN check on the account without any blank.
  DE: DE-R-019, DE-R-020: die IBAN-Pruefung auf dem Konto ohne Leerraum. }
function GermanIBANValid(const AAccount: TLandrixEInvoiceString): Boolean;
var
  I: Integer;
  S: TLandrixEInvoiceString;
begin
  S := '';
  for I := 1 to Length(AAccount) do
    if not ((AAccount[I] = ' ') or (AAccount[I] = #9) or (AAccount[I] = #10) or (AAccount[I] = #13)) then
      S := S + AAccount[I];
  Result := LandrixEInvoiceIBANValid(S);
end;

{ The national rules on the payment instructions.
  DE: Die nationalen Regeln auf den Zahlungsanweisungen. }
function PaymentViolated(AIndex: TPeppolRuleIndex; AInvoice: TLandrixInvoice; APayment: TLandrixInvoicePaymentType):
  Boolean;
var
  Raw, Code, ID, Account: TLandrixEInvoiceString;
  Group: TPaymentGroup;
  Mandate: Boolean;
begin
  Raw := PaymentCode(APayment);
  Code := LandrixEInvoiceNormalizeSpace(Raw);
  Group := PaymentGroup(APayment);
  Mandate := MandateWritten(AInvoice, APayment);
  ID := PaymentID(AInvoice);
  Account := PayeeAccount(APayment);
  Result := False;
  case AIndex of
    pr_DKR005:
      Result := Pos(' ' + Raw + ' ', ' 1 10 31 42 48 49 50 58 59 93 97 ') = 0;
    pr_DKR006:
      Result := ((Raw = '31') or (Raw = '42')) and not (Present(Account) and Present(PayeeBranch(APayment)));
    pr_DKR007:
      Result := (Raw = '49') and not (Mandate and Present(AInvoice.PaymentMandateID) and
        Present(PayerAccount(APayment)));
    pr_DKR008:
      Result := (Raw = '50') and not (((Copy(ID, 1, 3) = '01#') or (Copy(ID, 1, 3) = '04#') or
        (Copy(ID, 1, 3) = '15#')) and (LandrixEInvoiceIsDigits(Account, 7) or LandrixEInvoiceIsDigits(Account, 8)));
    pr_DKR009:
      Result := (Raw = '50') and ((Copy(ID, 1, 3) = '04#') or (Copy(ID, 1, 3) = '15#')) and (Length(ID) <> 19);
    pr_DKR010:
      Result := (Raw = '93') and not (((Copy(ID, 1, 3) = '71#') or (Copy(ID, 1, 3) = '73#') or
        (Copy(ID, 1, 3) = '75#')) and (Length(Account) = 8));
    pr_DKR011:
      Result := (Raw = '93') and ((Copy(ID, 1, 3) = '71#') or (Copy(ID, 1, 3) = '75#')) and
        not ((Length(ID) = 18) or (Length(ID) = 19));
    pr_SER007, pr_SER008, pr_SER009, pr_SER010:
      if (Code = '30') and (Account <> '') and
         (((AIndex in [pr_SER007, pr_SER010]) and
         (LandrixEInvoiceNormalizeSpace(PayeeBranch(APayment)) = 'SE:PLUSGIRO')) or
         ((AIndex in [pr_SER008, pr_SER009]) and
         (LandrixEInvoiceNormalizeSpace(PayeeBranch(APayment)) = 'SE:BANKGIRO'))) then
        case AIndex of
          pr_SER007, pr_SER008:
            Result := not IsXPathNumber(Account);
          pr_SER009:
            Result := not ((Length(LandrixEInvoiceNormalizeSpace(Account)) = 7) or
              (Length(LandrixEInvoiceNormalizeSpace(Account)) = 8));
        else
          Result := not ((Length(LandrixEInvoiceNormalizeSpace(Account)) >= 2) and
            (Length(LandrixEInvoiceNormalizeSpace(Account)) <= 8));
        end;
    pr_SER011:
      Result := (Raw = '50') or (Raw = '56');
    pr_SER012:
      Result := Raw = '31';
    pr_NLR008:
      Result := not InList(Code, '30 48 49 57 58 59');
    pr_DER019:
      Result := (Code = '58') and not GermanIBANValid(Account);
    pr_DER020:
      Result := (Code = '59') and not GermanIBANValid(PayerAccount(APayment));
    pr_DER0231:
      Result := ((Code = '30') or (Code = '58')) and (Account = '');
    pr_DER0241:
      Result := InList(Code, '48 54 55') and (Group <> pg_Card);
    pr_DER0242:
      Result := InList(Code, '48 54 55') and ((Account <> '') or Mandate);
    pr_DER0251:
      Result := (Code = '59') and not Mandate;
    pr_DER0252:
      Result := (Code = '59') and ((Account <> '') or (Group = pg_Card));
  else
    { the other rules are no payment rules }
    ;
  end;
end;

function AnyPaymentViolated(AIndex: TPeppolRuleIndex; AInvoice: TLandrixInvoice): Boolean;
var
  I: TLandrixEInvoiceListIndex;
begin
  Result := True;
  for I := 0 to AInvoice.PaymentTypes.Count - 1 do
    if PaymentWritten(AInvoice.PaymentTypes[I]) and PaymentViolated(AIndex, AInvoice, AInvoice.PaymentTypes[I]) then
      Exit;
  Result := False;
end;

{ IS-R-006, IS-R-007: a payment instruction with the code (compared as it
  is) needs a payee account of twelve characters.
  DE: IS-R-006, IS-R-007: eine Zahlungsanweisung mit dem Code braucht ein
  Konto aus zwoelf Zeichen. }
function IcelandicAccountWrong(AInvoice: TLandrixInvoice; const ACode: TLandrixEInvoiceString): Boolean;
var
  I: TLandrixEInvoiceListIndex;
  P: TLandrixInvoicePaymentType;
  Found: Boolean;
begin
  Result := False;
  Found := False;
  for I := 0 to AInvoice.PaymentTypes.Count - 1 do
  begin
    P := AInvoice.PaymentTypes[I];
    if not PaymentWritten(P) or (PaymentCode(P) <> ACode) then
      Continue;
    Found := True;
    if (PayeeAccount(P) <> '') and (Length(LandrixEInvoiceNormalizeSpace(PayeeAccount(P))) = 12) then
      Exit;
  end;
  Result := Found;
end;

function SwedishRateWrong(AInvoice: TLandrixInvoice; ALines: TLandrixInvoiceLines; ASubLines: Boolean): Boolean;
var
  I: TLandrixEInvoiceListIndex;
begin
  Result := True;
  for I := 0 to ALines.Count - 1 do
  begin
    if (WrittenCode(LandrixEInvoiceDutyTaxFeeCategoryCodeToStr(ALines[I].TaxCategory), ALines[I].TaxCategoryOther) =
       'S') and not StandardSwedishRate(ALines[I].TaxPercent) then
      Exit;
    if ASubLines and SwedishRateWrong(AInvoice, ALines[I].SubInvoiceLines, True) then
      Exit;
  end;
  Result := False;
end;

{ SE-R-006: every cac:TaxCategory and cac:ClassifiedTaxCategory with ID S
  (compared as written) has the rate 25, 12 or 6.
  DE: SE-R-006: jede Kategorie S hat den Satz 25, 12 oder 6. }
function SwedishRatesWrong(AInvoice: TLandrixInvoice; const ASpec: TLandrixEInvoiceSpec): Boolean;
var
  I: TLandrixEInvoiceListIndex;
  Item: TLandrixInvoiceAllowanceCharge;
  Tax: TLandrixInvoiceTaxAmount;
begin
  Result := True;
  for I := 0 to AInvoice.AllowanceCharges.Count - 1 do
  begin
    Item := AInvoice.AllowanceCharges[I];
    if (WrittenCode(LandrixEInvoiceDutyTaxFeeCategoryCodeToStr(Item.TaxCategory), Item.TaxCategoryOther) = 'S') and
       not StandardSwedishRate(Item.TaxPercent) then
      Exit;
  end;
  for I := 0 to AInvoice.TaxAmountSubtotals.Count - 1 do
  begin
    Tax := AInvoice.TaxAmountSubtotals[I];
    if (WrittenCode(LandrixEInvoiceDutyTaxFeeCategoryCodeToStr(Tax.TaxCategory), Tax.TaxCategoryOther) = 'S') and
       not StandardSwedishRate(Tax.TaxPercent) then
      Exit;
  end;
  Result := SwedishRateWrong(AInvoice, AInvoice.InvoiceLines, SubLinesWritten(AInvoice, ASpec));
end;

function OrderLineReferenceWritten(ALines: TLandrixInvoiceLines; ASubLines: Boolean): Boolean;
var
  I: TLandrixEInvoiceListIndex;
begin
  Result := True;
  for I := 0 to ALines.Count - 1 do
    if Present(ALines[I].OrderLineReference) or
       (ASubLines and OrderLineReferenceWritten(ALines[I].SubInvoiceLines, True)) then
      Exit;
  Result := False;
end;

{ NL-R-003, NL-R-005: the scheme contains the word 0106 or 0190.
  DE: NL-R-003, NL-R-005: das Schema enthaelt das Wort 0106 oder 0190. }
function DutchLegalSchemeWrong(const ACompanyID, AScheme: TLandrixEInvoiceString): Boolean;
begin
  Result := Present(ACompanyID) and (Pos(' 0106 ', ' ' + AScheme + ' ') = 0) and
    (Pos(' 0190 ', ' ' + AScheme + ' ') = 0);
end;

function NorwegianVATWrong(const AVATID: TLandrixEInvoiceString): Boolean;
var
  Rest: TLandrixEInvoiceString;
begin
  Result := False;
  if Copy(AVATID, 1, 2) <> 'NO' then
    Exit;
  Rest := Copy(AVATID, 3, Length(AVATID) - 2);
  Result := not ((Length(Rest) = 12) and LandrixEInvoiceIsDigits(Copy(Rest, 1, 9), 9) and
    (Copy(Rest, 10, 3) = 'MVA') and LandrixEInvoiceMod11Valid(Copy(Rest, 1, 9)));
end;

{ The national rules. DE: Die nationalen Regeln. }
function NationalViolated(AIndex: TPeppolRuleIndex; AInvoice: TLandrixInvoice; const ASpec: TLandrixEInvoiceSpec):
  Boolean;
var
  Seller, Buyer: TLandrixInvoiceAccountingParty;
  Supplier, Customer, SellerRaw, BuyerRaw, TypeCode, ID: TLandrixEInvoiceString;
  IsInvoice, SubLines, BothDE, BothNL, BothDK, Greek, NL: Boolean;
  I: TLandrixEInvoiceListIndex;
  Count: Integer;
  Reference: TLandrixInvoiceAttachment;
  Due: TLandrixEInvoiceString;
  HasPayer: Boolean;
begin
  Result := False;
  Seller := AInvoice.AccountingSupplierParty;
  Buyer := AInvoice.AccountingCustomerParty;
  Supplier := SupplierCountry(AInvoice);
  Customer := PartyCountry(Buyer, nil);
  SellerRaw := WrittenCountry(Seller.Address);
  BuyerRaw := WrittenCountry(Buyer.Address);
  IsInvoice := AInvoice.InvoiceTypeCode <> itc_CreditNote;
  SubLines := SubLinesWritten(AInvoice, ASpec);
  TypeCode := LandrixEInvoiceNormalizeSpace(WrittenCode(LandrixEInvoiceTypeCodeToStr(AInvoice.InvoiceTypeCode),
    AInvoice.InvoiceTypeCodeOther));
  BothDE := BothInGermany(AInvoice);
  NL := CountryIs(Seller.Address, 'NL');
  BothNL := NL and CountryIs(Buyer.Address, 'NL');
  BothDK := (SellerRaw = 'DK') and (BuyerRaw = 'DK');
  Greek := GreekCountry(Supplier);
  case AIndex of
    { Norway: $supplierCountry; the mapper writes the tax number with scheme
      FC, never TAX }
    pr_NOR001:
      Result := (Supplier = 'NO') and Present(Seller.VATCompanyID) and NorwegianVATWrong(Seller.VATCompanyID);
    pr_NOR002:
      Result := Supplier = 'NO';
    { Denmark: the postal country of the seller (and buyer) as written }
    pr_DKR002:
      Result := (SellerRaw = 'DK') and not Present(Seller.CompanyID);
    pr_DKR014:
      Result := (SellerRaw = 'DK') and Present(Seller.CompanyID) and
        (LandrixEInvoiceNormalizeSpace(Seller.CompanyIDSchemeID) <> '0184');
    pr_DKR016:
      Result := (SellerRaw = 'DK') and not IsInvoice and (BuyerRaw = 'DK') and
        (AmountSign(AInvoice.PayableAmount) < 0);
    { an identifier without scheme next to the global one, where both are
      written }
    pr_DKR013:
      Result := BothDK and (PlainIdentifierWritten(Seller, ASpec, True) or PlainIdentifierWritten(Buyer, ASpec, False));
    pr_DKR017:
      Result := BothDK and Present(Buyer.CompanyID) and
        (LandrixEInvoiceNormalizeSpace(Buyer.CompanyIDSchemeID) <> '0184');
    pr_DKR003:
      if BothDK then
        for I := 0 to AInvoice.InvoiceLines.Count - 1 do
          if DanishClassificationWrong(AInvoice.InvoiceLines[I]) then
            Result := True;
    pr_DKR004:
      if BothDK then
      begin
        for I := 0 to AInvoice.AllowanceCharges.Count - 1 do
          if DanishAllowanceWrong(AInvoice.AllowanceCharges[I]) then
            Result := True;
        if DanishLineAllowanceWrong(AInvoice.InvoiceLines, SubLines) then
          Result := True;
      end;
    pr_DKR005..pr_DKR011:
      Result := BothDK and IsInvoice and AnyPaymentViolated(AIndex, AInvoice);
    { Italy }
    pr_ITR001:
      Result := (Supplier = 'IT') and (SellerTaxNumber(AInvoice) <> '') and
        not ItalianTaxNumberValid(SellerTaxNumber(AInvoice));
    pr_ITR002:
      Result := (Supplier = 'IT') and not Present(Seller.Address.StreetName);
    pr_ITR003:
      Result := (Supplier = 'IT') and not Present(Seller.Address.City);
    pr_ITR004:
      Result := (Supplier = 'IT') and not Present(Seller.Address.PostalZone);
    { Sweden: the postal country as written (compared exactly) }
    pr_SER001, pr_SER002:
      if (SellerRaw = 'SE') and Present(Seller.VATCompanyID) and (Copy(Seller.VATCompanyID, 1, 2) = 'SE') then
      begin
        if AIndex = pr_SER001 then
          Result := Length(LandrixEInvoiceNormalizeSpace(Seller.VATCompanyID)) <> 14
        else
          Result := not IsXPathNumber(Copy(Seller.VATCompanyID, 3, 12));
      end;
    pr_SER003, pr_SER004, pr_SER013:
      if (SellerRaw = 'SE') and Present(Seller.CompanyID) then
        case AIndex of
          pr_SER003:
            Result := not IsXPathNumber(Seller.CompanyID);
          pr_SER004:
            Result := Length(LandrixEInvoiceNormalizeSpace(Seller.CompanyID)) <> 10;
        else
          { u:checkSEOrgnr: digits only, the first ten checked }
          Result := not (LandrixEInvoiceIsDigits(LandrixEInvoiceNormalizeSpace(Seller.CompanyID), 0) and
            LandrixEInvoiceSwedishOrgNumberValid(Copy(LandrixEInvoiceNormalizeSpace(Seller.CompanyID), 1, 10)));
        end;
    pr_SER005:
      Result := (SellerRaw = 'SE') and Present(Seller.CompanyID) and (SellerTaxNumber(AInvoice) <> '') and
        (LandrixEInvoiceNormalizeSpace(UpperLatin1(SellerTaxNumber(AInvoice))) <>
        'GODK' + TLandrixEInvoiceChar($C4) + 'ND F' + TLandrixEInvoiceChar($D6) + 'R F-SKATT');
    pr_SER006:
      Result := (SellerRaw = 'SE') and Present(Seller.VATCompanyID) and (Copy(Seller.VATCompanyID, 1, 2) = 'SE') and
        SwedishRatesWrong(AInvoice, ASpec);
    pr_SER007..pr_SER011:
      Result := (SellerRaw = 'SE') and AnyPaymentViolated(AIndex, AInvoice);
    pr_SER012:
      Result := (SellerRaw = 'SE') and (BuyerRaw = 'SE') and AnyPaymentViolated(AIndex, AInvoice);
    { Greece: $isGreekSender; the invoice number in six segments }
    pr_GRR0011..pr_GRR0017:
      if Greek and Present(AInvoice.InvoiceNumber) then
      begin
        ID := AInvoice.InvoiceNumber;
        case AIndex of
          pr_GRR0011:
            begin
              Segment(ID, '|', 1, Count);
              Result := Count <> 6;
            end;
          pr_GRR0012:
            Result := not GreekIssuerValid(AInvoice, SegmentAt(ID, 1));
          pr_GRR0013:
            Result := not GreekDateValid(AInvoice, SegmentAt(ID, 2));
          pr_GRR0014:
            Result := (LandrixEInvoiceNormalizeSpace(SegmentAt(ID, 3)) = '') or
              not LandrixEInvoiceIsInteger(SegmentAt(ID, 3)) or (AmountSignOf(SegmentAt(ID, 3)) < 0);
          pr_GRR0015:
            Result := not InList(SegmentAt(ID, 4), '1.1 1.6 2.1 2.4 5.1 5.2');
          pr_GRR0016:
            Result := SegmentAt(ID, 5) = '';
        else
          Result := SegmentAt(ID, 6) = '';
        end;
      end;
    pr_GRR002:
      Result := Greek and not Present(Seller.Name);
    pr_GRR003:
      Result := Greek and Present(Seller.VATCompanyID) and not GreekVATValid(Seller.VATCompanyID);
    pr_GRS011:
      Result := Greek and not (Present(Seller.VATCompanyID) and GreekVATValid(Seller.VATCompanyID));
    pr_GRR0041, pr_GRS0081, pr_GRR0082:
      if Greek and (SellerRaw = 'GR') then
        case AIndex of
          pr_GRR0041:
            Result := CountDescribed(AInvoice, '##M.AR.K##') <> 1;
          pr_GRS0081:
            Result := CountDescribed(AInvoice, '##INVOICE|URL##') <> 1;
        else
          Result := CountDescribed(AInvoice, '##INVOICE|URL##') > 1;
        end;
    pr_GRR0042:
      if Greek and (SellerRaw = 'GR') then
        for I := 0 to AInvoice.Attachments.Count - 1 do
          if ReferenceWritten(AInvoice, I) and (AInvoice.Attachments[I].DocumentDescription = '##M.AR.K##') and
             Present(AInvoice.Attachments[I].ID) and not ((AInvoice.Attachments[I].ID[1] >= '1') and
             (AInvoice.Attachments[I].ID[1] <= '9')) then
            Result := True;
    pr_GRR0083:
      if Greek then
        for I := 0 to AInvoice.Attachments.Count - 1 do
          if ReferenceWritten(AInvoice, I) and (AInvoice.Attachments[I].DocumentDescription = '##INVOICE|URL##') and
             not Present(AInvoice.Attachments[I].ExternalReference) then
            Result := True;
    pr_GRR005:
      Result := Greek and not Present(Buyer.Name);
    pr_GRR009:
      Result := GreekCountry(PartyCountry(Seller, nil)) and Present(Seller.ElectronicAddressSellerBuyer) and
        not ((Seller.ElectronicAddressSellerBuyerSchemeID = '9933') and
        LandrixEInvoiceGreekTINValid(Seller.ElectronicAddressSellerBuyer));
    pr_GRR006:
      Result := Greek and GreekCountry(Customer) and
        not (Present(Buyer.VATCompanyID) and GreekVATValid(Buyer.VATCompanyID));
    pr_GRR010:
      Result := Greek and GreekCountry(Customer) and Present(Buyer.ElectronicAddressSellerBuyer) and
        not ((Buyer.ElectronicAddressSellerBuyerSchemeID = '9933') and
        LandrixEInvoiceGreekTINValid(Buyer.ElectronicAddressSellerBuyer));
    { Iceland: the postal country of the seller (and buyer) as written }
    pr_ISR001:
      Result := (SellerRaw = 'IS') and not ((TypeCode = '380') or (TypeCode = '381'));
    pr_ISR002:
      Result := (SellerRaw = 'IS') and not (Present(Seller.CompanyID) and (Seller.CompanyIDSchemeID = '0196'));
    pr_ISR003:
      Result := (SellerRaw = 'IS') and not (Present(Seller.Address.StreetName) and Present(Seller.Address.PostalZone));
    pr_ISR004:
      Result := (SellerRaw = 'IS') and (BuyerRaw = 'IS') and
        not (Present(Buyer.CompanyID) and (Buyer.CompanyIDSchemeID = '0196'));
    pr_ISR005:
      Result := (SellerRaw = 'IS') and (BuyerRaw = 'IS') and
        not (Present(Buyer.Address.StreetName) and Present(Buyer.Address.PostalZone));
    pr_ISR006:
      Result := (SellerRaw = 'IS') and IcelandicAccountWrong(AInvoice, '9');
    pr_ISR007:
      Result := (SellerRaw = 'IS') and IcelandicAccountWrong(AInvoice, '42');
    pr_ISR008, pr_ISR009, pr_ISR010:
      begin
        Reference := FirstDescribed(AInvoice, 'EINDAGI');
        if (SellerRaw = 'IS') and (Reference <> nil) then
        begin
          if IsInvoice and (AInvoice.InvoiceDueDate > 0) then
            Due := LandrixEInvoiceDateToUBL(AInvoice.InvoiceDueDate)
          else
            Due := '';
          if Present(Reference.ID) then
            ID := Reference.ID
          else
            ID := '';
          case AIndex of
            pr_ISR008:
              Result := not IsDate(ID);
            pr_ISR009:
              Result := Due = '';
          else
            Result := (Due = '') or (ID = '') or (Due > ID);
          end;
        end;
      end;
    { the Netherlands: upper-case(normalize-space()) of the postal country }
    pr_NLR001:
      Result := NL and not IsInvoice and not PrecedingWritten(AInvoice, ASpec, True);
    pr_NLR002:
      Result := NL and not (Present(Seller.Address.StreetName) and Present(Seller.Address.City) and
        Present(Seller.Address.PostalZone));
    pr_NLR003:
      Result := NL and DutchLegalSchemeWrong(Seller.CompanyID, Seller.CompanyIDSchemeID);
    pr_NLR004:
      Result := BothNL and not (Present(Buyer.Address.StreetName) and Present(Buyer.Address.City) and
        Present(Buyer.Address.PostalZone));
    pr_NLR005:
      Result := BothNL and DutchLegalSchemeWrong(Buyer.CompanyID, Buyer.CompanyIDSchemeID);
    pr_NLR006:
      Result := NL and TaxRepresentativeWritten(AInvoice) and AddressWritten(AInvoice.TaxRepresentativeParty.Address) and
        CountryIs(AInvoice.TaxRepresentativeParty.Address, 'NL') and
        not (Present(AInvoice.TaxRepresentativeParty.Address.StreetName) and
        Present(AInvoice.TaxRepresentativeParty.Address.City) and
        Present(AInvoice.TaxRepresentativeParty.Address.PostalZone));
    pr_NLR007:
      Result := NL and not ((IsInvoice and (AmountSign(AInvoice.PayableAmount) <= 0)) or
        (not IsInvoice and (AmountSign(AInvoice.PayableAmount) >= 0)) or AnyPaymentWritten(AInvoice));
    pr_NLR008:
      Result := BothNL and AnyPaymentViolated(AIndex, AInvoice);
    pr_NLR009:
      Result := NL and OrderLineReferenceWritten(AInvoice.InvoiceLines, SubLines) and
        not (Present(AInvoice.PurchaseOrderReference) or Present(AInvoice.SellerOrderReference));
    { Germany: seller and buyer in Germany (upper-case(normalize-space())) }
    pr_DER001:
      Result := BothDE and not AnyPaymentWritten(AInvoice);
    pr_DER002:
      Result := BothDE and not ContactWritten(Seller);
    pr_DER003:
      Result := BothDE and not Present(Seller.Address.City);
    pr_DER004:
      Result := BothDE and not Present(Seller.Address.PostalZone);
    pr_DER005:
      Result := BothDE and ContactWritten(Seller) and not (Present(Seller.ContactName) or
        Present(Seller.ContactDepartment));
    pr_DER006:
      Result := BothDE and ContactWritten(Seller) and not Present(Seller.ContactTelephone);
    pr_DER007:
      Result := BothDE and ContactWritten(Seller) and not Present(Seller.ContactElectronicMail);
    pr_DER027:
      Result := BothDE and ContactWritten(Seller) and
        not LandrixEInvoiceTelephoneValid(LandrixEInvoiceNormalizeSpace(Seller.ContactTelephone));
    pr_DER028:
      Result := BothDE and ContactWritten(Seller) and not LandrixEInvoiceEmailValid(Seller.ContactElectronicMail);
    pr_DER008:
      Result := BothDE and not Present(Buyer.Address.City);
    pr_DER009:
      Result := BothDE and not Present(Buyer.Address.PostalZone);
    pr_DER010:
      Result := BothDE and AddressWritten(AInvoice.DeliveryInformation.Address) and
        not Present(AInvoice.DeliveryInformation.Address.City);
    pr_DER011:
      Result := BothDE and AddressWritten(AInvoice.DeliveryInformation.Address) and
        not Present(AInvoice.DeliveryInformation.Address.PostalZone);
    pr_DER015:
      Result := BothDE and not Present(AInvoice.BuyerReference);
    pr_DER016:
      Result := BothDE and GermanTaxableCategory(AInvoice) and not TaxRepresentativeWritten(AInvoice) and
        not Present(Seller.VATCompanyID) and not Present(Seller.VATCompanyNumber);
    pr_DER017:
      Result := BothDE and not InList(TypeCode, '326 380 384 389 381 875 876 877');
    pr_DER018:
      Result := BothDE and not LandrixEInvoiceCashDiscountTextValid(TermsText(AInvoice));
    pr_DER019, pr_DER020, pr_DER0231..pr_DER0252:
      Result := BothDE and AnyPaymentViolated(AIndex, AInvoice);
    pr_DER022:
      Result := BothDE and GermanDuplicateFilename(AInvoice);
    pr_DER026:
      Result := BothDE and (TypeCode = '384') and not PrecedingWritten(AInvoice, ASpec, False);
    { the creditor identifier is written with scheme SEPA in the seller or
      the payee }
    pr_DER030, pr_DER031:
      begin
        Count := 0;
        HasPayer := False;
        for I := 0 to AInvoice.PaymentTypes.Count - 1 do
          if PaymentWritten(AInvoice.PaymentTypes[I]) and MandateWritten(AInvoice, AInvoice.PaymentTypes[I]) then
          begin
            Inc(Count);
            if PayerAccount(AInvoice.PaymentTypes[I]) <> '' then
              HasPayer := True;
          end;
        if BothDE and (Count > 0) then
        begin
          if AIndex = pr_DER030 then
            Result := not Present(Seller.BankAssignedCreditorIdentifier) and
              not (Present(Seller.GlobalIdentifierSellerBuyer) and (GlobalScheme(Seller) = 'SEPA')) and
              not (PayeeWritten(AInvoice) and Present(AInvoice.PayeeParty.Identifier) and
              (AInvoice.PayeeParty.IdentifierSchemeID = 'SEPA'))
          else
            Result := not HasPayer;
        end;
      end;
    pr_DERT02:
      if BothDE then
        for I := 0 to AInvoice.Attachments.Count - 1 do
          if ReferenceWritten(AInvoice, I) and Present(AInvoice.Attachments[I].ExternalReference) and
             not AbsoluteURL(AInvoice.Attachments[I].ExternalReference) then
            Result := True;
  else
    { the other rules are no national rules }
    ;
  end;
end;

{ --- dispatcher ---------------------------------------------------------------- }

function Violated(AIndex: TPeppolRuleIndex; AInvoice: TLandrixInvoice; const ASpec: TLandrixEInvoiceSpec): Boolean;
var
  I, Notes: Integer;
  TypeCode: TLandrixEInvoiceString;
  Identifiers: TWrittenIdentifiers;
  IsInvoice: Boolean;
begin
  Result := False;
  Identifiers := nil;
  IsInvoice := AInvoice.InvoiceTypeCode <> itc_CreditNote;
  TypeCode := LandrixEInvoiceNormalizeSpace(WrittenCode(LandrixEInvoiceTypeCodeToStr(AInvoice.InvoiceTypeCode),
    AInvoice.InvoiceTypeCodeOther));
  case AIndex of
    pr_R002:
      begin
        Notes := 0;
        for I := 0 to Integer(AInvoice.Notes.Count) - 1 do
          if Present(AInvoice.Notes[I].Content) then
            Inc(Notes);
        Result := (Notes > 1) and not BothInGermany(AInvoice);
      end;
    pr_R007:
      Result := not ApprovedProfile(WrittenProfile(AInvoice, ASpec));
    { cbc:InvoiceTypeCode exists in ubl:Invoice only }
    pr_P0100:
      Result := IsInvoice and (TypeCode <> '') and ApprovedProfile(WrittenProfile(AInvoice, ASpec)) and
        not InList(TypeCode, PeppolInvoiceTypeCodes);
    pr_P0112:
      Result := IsInvoice and ((TypeCode = '326') or (TypeCode = '384')) and not BothInGermany(AInvoice);
    pr_P0104..pr_P0111:
      Result := ExemptionCategoryWrong(AIndex, AInvoice);
    pr_CL001:
      Result := MimeCodeWrong(AInvoice);
    pr_CL002, pr_CL003:
      begin
        Result := True;
        for I := 0 to Integer(AInvoice.AllowanceCharges.Count) - 1 do
          if ReasonWrong(AIndex, AInvoice.AllowanceCharges[I]) then
            Exit;
        Result := LineReasonWrong(AIndex, AInvoice.InvoiceLines, SubLinesWritten(AInvoice, ASpec));
      end;
    { BT-8 is left out next to BT-7 (BR-CO-03) }
    pr_CL006:
      Result := Present(AInvoice.TaxPointDateCode) and not AInvoice.TaxPointDate.HasValue and
        not InList(LandrixEInvoiceNormalizeSpace(AInvoice.TaxPointDateCode), PeppolPeriodCodes);
    { every amount carries BT-5, BT-111 carries BT-6; @currencyID is compared
      exactly }
    pr_CL007:
      Result := not InList(AInvoice.InvoiceCurrencyCode, PeppolCurrencies) or
        (Present(AInvoice.TaxCurrencyCode) and (AInvoice.TaxCurrencyCode <> AInvoice.InvoiceCurrencyCode) and
        AInvoice.TaxAmountTotalInTaxCurrency.HasValue and not InList(AInvoice.TaxCurrencyCode, PeppolCurrencies));
    pr_CL008:
      begin
        Identifiers := WrittenIdentifiers(AInvoice);
        for I := 0 to Integer(Length(Identifiers)) - 1 do
          if (Identifiers[I].Place = ip_Endpoint) and not InList(Identifiers[I].Scheme, PeppolEASCodes) then
            Result := True;
      end;
    pr_CommonR0562:
      Result := (Present(AInvoice.AccountingSupplierParty.VATCompanyID) and
        DutchVATWrong(AInvoice.AccountingSupplierParty.VATCompanyID)) or
        (Present(AInvoice.AccountingCustomerParty.VATCompanyID) and
        DutchVATWrong(AInvoice.AccountingCustomerParty.VATCompanyID)) or
        (Present(AInvoice.TaxRepresentativeParty.VATCompanyID) and
        DutchVATWrong(AInvoice.TaxRepresentativeParty.VATCompanyID));
    pr_CommonR040..pr_CommonR0561, pr_CommonR057:
      begin
        Identifiers := WrittenIdentifiers(AInvoice);
        for I := 0 to Integer(Length(Identifiers)) - 1 do
          if CommonViolated(AIndex, Identifiers[I]) then
            Result := True;
      end;
    pr_NOR001..pr_DERT02:
      Result := NationalViolated(AIndex, AInvoice, ASpec);
  end;
end;

procedure AddViolation(ADiagnostics: TLandrixEInvoiceDiagnostics; const ARow: TPeppolRow);
var
  D: TLandrixEInvoiceDiagnostic;
begin
  if ADiagnostics = nil then
    Exit;
  D := ADiagnostics.AddDiagnostic(edk_RuleViolation, TLandrixEInvoiceString(ARow.Terms), 0, 0, 0,
    TLandrixEInvoiceString(ARow.Message));
  D.Severity := ARow.Severity;
  D.RuleID := TLandrixEInvoiceString(ARow.ID);
end;

function Applies(const ASpec: TLandrixEInvoiceSpec): Boolean;
begin
  Result := (ASpec.Target.Standard = est_PeppolBIS) and (ASpec.Target.Syntax = esy_UBL);
end;

{ Violated; a rule that cannot judge a number the writers cannot format
  holds (EUnwritableNumber).
  DE: Violated; eine Regel, die eine Zahl nicht beurteilen kann, die die
  Writer nicht formatieren koennen, gilt als erfuellt
  (EUnwritableNumber). }
function ViolatedWritable(AIndex: TPeppolRuleIndex; AInvoice: TLandrixInvoice;
  const ASpec: TLandrixEInvoiceSpec): Boolean;
begin
  try
    Result := Violated(AIndex, AInvoice, ASpec);
  except
    on EUnwritableNumber do
      Result := False;
  end;
end;

{ --- public -------------------------------------------------------------------- }

function LandrixEInvoiceCheckPeppolInvoice(AInvoice: TLandrixInvoice; const ASpec: TLandrixEInvoiceSpec;
  ADiagnostics: TLandrixEInvoiceDiagnostics): Integer;
var
  I: TPeppolRuleIndex;
  Flat: TLandrixInvoice;
begin
  Result := 0;
  if not Applies(ASpec) then
    Exit;
  { checked as written: Peppol writes sub lines flat }
  Flat := LandrixEInvoiceFlattenSubLines(AInvoice, ASpec, nil);
  try
    if Flat <> nil then
      AInvoice := Flat;
    for I := Low(TPeppolRuleIndex) to High(TPeppolRuleIndex) do
      if ViolatedWritable(I, AInvoice, ASpec) then
      begin
        AddViolation(ADiagnostics, PeppolRows[I]);
        if PeppolRows[I].Severity = eds_Error then
          Inc(Result);
      end;
  finally
    Flat.Free;
  end;
end;

function LandrixEInvoiceCheckPeppolRule(AInvoice: TLandrixInvoice; const ASpec: TLandrixEInvoiceSpec;
  const ARuleID: TLandrixEInvoiceString; ADiagnostics: TLandrixEInvoiceDiagnostics; ASkip: Boolean;
  out AFound: Boolean): Boolean;
var
  I: TPeppolRuleIndex;
  Flat: TLandrixInvoice;
begin
  Result := True;
  AFound := False;
  Flat := LandrixEInvoiceFlattenSubLines(AInvoice, ASpec, nil);
  try
    if Flat <> nil then
      AInvoice := Flat;
    for I := Low(TPeppolRuleIndex) to High(TPeppolRuleIndex) do
      if TLandrixEInvoiceString(PeppolRows[I].ID) = ARuleID then
      begin
        AFound := True;
        if not ASkip and Applies(ASpec) and ViolatedWritable(I, AInvoice, ASpec) then
        begin
          AddViolation(ADiagnostics, PeppolRows[I]);
          Result := False;
        end;
      end;
  finally
    Flat.Free;
  end;
end;

end.
