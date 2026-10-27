{
  EInvoice-for-Pascal

  Copyright (C) 2026 Landrix Software GmbH & Co. KG

  This file is dual-licensed under:
  - GNU GPL version 3 or later; or
  - the Landrix Software Commercial License.

  See LICENSE and COMMERCIAL-LICENSE.md.

  SPDX-License-Identifier: GPL-3.0-or-later OR LicenseRef-Landrix-Commercial
}

{ Rule table of the target specifications: which content of the invoice
  model a specification allows, discourages or forbids. The mapping asks
  this table instead of testing standards or profiles in code. Phase 1
  covers what the mapping needs for the specifications of
  LandrixEInvoiceSpecs; phase 2 adds cardinalities and the consistency
  checks. What a Factur-X profile contains structurally is not repeated
  here: LandrixEInvoiceCIIProfiles removes it from the CII model.

  A rule row names a key (e.g. LandrixEInvoiceRuleLineSubLines), the
  specifications it applies to (sets of standards, syntaxes and profiles),
  the level, the business terms and the source of the rule. The first row
  whose key matches and whose sets contain the specification decides; a key
  without a matching row is allowed.

  DE: Regel-Tabelle der Zielspezifikationen: welchen Inhalt des
  Rechnungsmodells eine Spezifikation erlaubt, davon abraet oder verbietet.
  Die Abbildung fragt diese Tabelle, statt Standards oder Profile im Code zu
  pruefen. Phase 1 enthaelt, was die Abbildung fuer die
  Spezifikationen aus LandrixEInvoiceSpecs braucht; Phase 2 ergaenzt
  Kardinalitaeten und die Konsistenzpruefungen. Was ein Factur-X-Profil
  strukturell enthaelt, steht nicht hier: LandrixEInvoiceCIIProfiles
  entfernt es aus dem CII-Modell.

  Eine Regelzeile nennt einen Schluessel (z. B.
  LandrixEInvoiceRuleLineSubLines), die Spezifikationen, fuer die sie gilt
  (Mengen von Standards, Syntaxen und Profilen), die Stufe, die
  Geschaeftsbegriffe und die Quelle der Regel. Die erste Zeile mit
  passendem Schluessel, deren Mengen die Spezifikation enthalten,
  entscheidet; ein Schluessel ohne passende Zeile ist erlaubt. }

{ API: internal. May change in any release; use the facade LandrixEInvoice
  or the stable units instead.
  DE: API: intern. Kann sich in jeder Version aendern; stattdessen die
  Fassade LandrixEInvoice oder die stabilen Units verwenden. }

unit LandrixEInvoiceRules;

{$I LandrixEInvoice.inc}

interface

uses
  LandrixEInvoiceTypes,
  LandrixEInvoiceSpecs;

type
  { Level of a rule. DE: Stufe einer Regel. }
  TLandrixEInvoiceRuleLevel = (
    { Content is written. DE: Inhalt wird geschrieben. }
    erl_Allowed,
    { Content is written, the mapping adds a warning (edk_NotAllowed).
      DE: Inhalt wird geschrieben, die Abbildung meldet eine Warnung
      (edk_NotAllowed). }
    erl_Discouraged,
    { Content is left out, the mapping adds a warning (edk_NotAllowed).
      DE: Inhalt wird weggelassen, die Abbildung meldet eine Warnung
      (edk_NotAllowed). }
    erl_Forbidden
  );

  TLandrixEInvoiceStandards = set of TLandrixEInvoiceStandard;
  TLandrixEInvoiceSyntaxes = set of TLandrixEInvoiceSyntax;
  TLandrixEInvoiceProfiles = set of TLandrixEInvoiceProfile;

  { One rule row. DE: Eine Regelzeile. }
  TLandrixEInvoiceRule = record
    Key: string;
    Standards: TLandrixEInvoiceStandards;
    Syntaxes: TLandrixEInvoiceSyntaxes;
    Profiles: TLandrixEInvoiceProfiles;
    Level: TLandrixEInvoiceRuleLevel;
    { Business terms, e.g. 'BG-DEX-01'. DE: Geschaeftsbegriffe, z. B.
      'BG-DEX-01'. }
    Terms: string;
    { Origin of the rule, e.g. a rule ID. DE: Herkunft der Regel, z. B. eine
      Regelkennung. }
    Source: string;
  end;

const
  { Sub invoice lines (UBL cac:SubInvoiceLine, CII EXTENDED ParentLineID and
    LineStatusReasonCode). DE: Unterpositionen (UBL cac:SubInvoiceLine, CII
    EXTENDED ParentLineID und LineStatusReasonCode). }
  LandrixEInvoiceRuleLineSubLines = 'Line.SubLines';
  { Name of an item classification (CII ram:ClassName).
    DE: Name einer Artikelklassifizierung (CII ram:ClassName). }
  LandrixEInvoiceRuleLineClassificationName = 'Line.ClassificationName';
  { Order number on a line (CII BuyerOrderReferencedDocument/IssuerAssignedID).
    DE: Bestellnummer je Position (CII BuyerOrderReferencedDocument/IssuerAssignedID). }
  LandrixEInvoiceRuleLineOrderNumber = 'Line.OrderNumber';
  { VAT exemption reason on a line (CII ApplicableTradeTax/ExemptionReason).
    DE: Steuerbefreiungsgrund je Position (CII ApplicableTradeTax/ExemptionReason). }
  LandrixEInvoiceRuleLineTaxExemptionReason = 'Line.TaxExemptionReason';
  { Delivery date and delivery note on a line.
    DE: Lieferdatum und Lieferschein je Position. }
  LandrixEInvoiceRuleLineDelivery = 'Line.Delivery';
  { Date of the despatch advice reference (BT-16).
    DE: Datum der Versandanzeigereferenz (BT-16). }
  LandrixEInvoiceRuleDespatchAdviceDate = 'Header.DespatchAdviceDate';
  { Delivery note of the invoice (DeliveryReceiptNumberExtended).
    DE: Lieferschein der Rechnung (DeliveryReceiptNumberExtended). }
  LandrixEInvoiceRuleDeliveryNote = 'Header.DeliveryNote';
  { Structured payment terms with discount terms (CII BG-X-44); otherwise
    the cash discount is written as #SKONTO# text.
    DE: Strukturierte Zahlungsbedingungen mit Skonto (CII BG-X-44); sonst
    wird das Skonto als #SKONTO#-Text geschrieben. }
  LandrixEInvoiceRuleStructuredPaymentTerms = 'Payment.StructuredTerms';
  { More than one preceding invoice reference (BG-3).
    DE: Mehr als ein Verweis auf eine vorausgegangene Rechnung (BG-3). }
  LandrixEInvoiceRuleMultiplePrecedingInvoices = 'Header.MultiplePrecedingInvoices';
  { Buyer identifier together with a global identifier (BT-46).
    DE: Kaeuferkennung zusammen mit einer globalen Kennung (BT-46). }
  LandrixEInvoiceRuleBuyerIDWithGlobalID = 'Buyer.IDWithGlobalID';
  { Seller identifier together with a global identifier (BT-29).
    DE: Verkaeuferkennung zusammen mit einer globalen Kennung (BT-29). }
  LandrixEInvoiceRuleSellerIDWithGlobalID = 'Seller.IDWithGlobalID';
  { Buyer reference placeholder 'non-existent' (BT-10).
    DE: Platzhalter 'non-existent' fuer die Kaeuferreferenz (BT-10). }
  LandrixEInvoiceRuleBuyerReferencePlaceholder = 'Header.BuyerReferencePlaceholder';
  { Payment due date on a credit note (BT-9).
    DE: Faelligkeitsdatum auf einer Gutschrift (BT-9). }
  LandrixEInvoiceRuleCreditNoteDueDate = 'CreditNote.DueDate';
  { Default scheme 'EM' for an electronic address without scheme (BT-34, BT-49).
    DE: Vorgabeschema 'EM' fuer eine elektronische Adresse ohne Schema
    (BT-34, BT-49). }
  LandrixEInvoiceRuleElectronicAddressDefaultEM = 'Party.ElectronicAddressDefaultEM';
  { Third-party payments (XRechnung extension BG-DEX-09, UBL cac:PrepaidPayment).
    DE: Zahlungen Dritter (XRechnung-Extension BG-DEX-09, UBL cac:PrepaidPayment). }
  LandrixEInvoiceRuleThirdPartyPayments = 'Payment.ThirdPartyPayments';
  { Test indicator (BT-X-1). DE: Testkennzeichen (BT-X-1). }
  LandrixEInvoiceRuleTestIndicator = 'Header.TestIndicator';
  { Document name (BT-X-2). DE: Dokumentname (BT-X-2). }
  LandrixEInvoiceRuleDocumentName = 'Header.DocumentName';
  { Dates of the sales order and the purchase order (BT-X-146, BT-X-147).
    DE: Datum des Auftrags und der Bestellung (BT-X-146, BT-X-147). }
  LandrixEInvoiceRuleOrderDates = 'Header.OrderDates';
  { Date of the buyer's order of a line (BT-X-22).
    DE: Datum der Bestellung je Position (BT-X-22). }
  LandrixEInvoiceRuleLineOrderDate = 'Line.OrderDate';
  { Department of a seller or buyer contact (BT-41-0, BT-56-0).
    DE: Abteilung eines Verkaeufer- oder Kaeuferkontakts (BT-41-0, BT-56-0). }
  LandrixEInvoiceRuleContactDepartment = 'Party.ContactDepartment';
  { Contact of the party delivered to (BG-X-26).
    DE: Kontakt des Warenempfaengers (BG-X-26). }
  LandrixEInvoiceRuleDeliveryContact = 'Delivery.Contact';
  { Invoicee (BG-X-36). DE: Rechnungsempfaenger (BG-X-36). }
  LandrixEInvoiceRuleInvoicee = 'Party.Invoicee';
  { Payee content beyond BT-59 to BT-61 (address, contact, VAT identifier).
    DE: Angaben zum Zahlungsempfaenger ueber BT-59 bis BT-61 hinaus
    (Anschrift, Kontakt, USt-IdNr.). }
  LandrixEInvoiceRulePayeeExtended = 'Payee.Extended';
  { Tax representative content beyond BT-62, BT-63 and BG-12 (identifiers,
    contact). DE: Angaben zum Steuervertreter ueber BT-62, BT-63 und BG-12
    hinaus (Kennungen, Kontakt). }
  LandrixEInvoiceRuleTaxRepresentativeExtended = 'TaxRepresentative.Extended';
  { Text of a cash discount level (BT-20 of a discount term).
    DE: Text einer Skontostufe (BT-20 einer Skontobedingung). }
  LandrixEInvoiceRuleCashDiscountNote = 'Payment.CashDiscountNote';
  { Invoiced object identifiers (BT-18) after the first.
    DE: Objektkennungen (BT-18) nach der ersten. }
  LandrixEInvoiceRuleFurtherObjectIdentifier = 'Attachment.FurtherObjectIdentifier';

{ Level of AKey for ASpec (erl_Allowed if no row matches).
  DE: Stufe von AKey fuer ASpec (erl_Allowed, wenn keine Zeile passt). }
function LandrixEInvoiceRuleLevel(const ASpec: TLandrixEInvoiceSpec;
  const AKey: string): TLandrixEInvoiceRuleLevel;

{ The row that decides AKey for ASpec; False if none matches.
  DE: Die Zeile, die AKey fuer ASpec entscheidet; False, wenn keine passt. }
function LandrixEInvoiceFindRule(const ASpec: TLandrixEInvoiceSpec; const AKey: string;
  out ARule: TLandrixEInvoiceRule): Boolean;

{ Number of rule rows. DE: Anzahl der Regelzeilen. }
function LandrixEInvoiceRuleCount: Integer;
{ Rule row AIndex (0-based); ELandrixEInvoiceError if out of range.
  DE: Regelzeile AIndex (ab 0); ELandrixEInvoiceError ausserhalb des
  Bereichs. }
function LandrixEInvoiceRule(AIndex: Integer): TLandrixEInvoiceRule;

implementation

const
  AnyStandard = [est_XRechnung, est_FacturX, est_PeppolBIS];
  AnySyntax = [esy_UBL, esy_CII];
  AnyProfile = [Low(TLandrixEInvoiceProfile)..High(TLandrixEInvoiceProfile)];

  Rules: array[0..35] of TLandrixEInvoiceRule = (
    { sub lines: CII only in Factur-X EXTENDED; UBL XRechnung extension;
      Peppol only a warning of the EN 16931 rules. Where the level is not
      erl_Allowed they are written flat (LandrixEInvoiceSubLines). }
    (Key: LandrixEInvoiceRuleLineSubLines; Standards: [est_FacturX]; Syntaxes: [esy_CII];
     Profiles: [epr_Extended]; Level: erl_Allowed; Terms: 'BT-X-304, BT-X-8';
     Source: 'Factur-X 1.09 EXTENDED'),
    (Key: LandrixEInvoiceRuleLineSubLines; Standards: AnyStandard; Syntaxes: [esy_CII];
     Profiles: AnyProfile; Level: erl_Forbidden; Terms: 'BG-DEX-01';
     Source: 'not in the CII syntax of EN 16931 and XRechnung'),
    (Key: LandrixEInvoiceRuleLineSubLines; Standards: [est_PeppolBIS]; Syntaxes: [esy_UBL];
     Profiles: AnyProfile; Level: erl_Discouraged; Terms: 'BG-DEX-01';
     Source: 'UBL-CR-646 (warning)'),
    { EXTENDED-only content; UBL has no element for it }
    (Key: LandrixEInvoiceRuleLineClassificationName; Standards: AnyStandard; Syntaxes: AnySyntax;
     Profiles: AnyProfile - [epr_Extended]; Level: erl_Forbidden; Terms: 'BT-X-13';
     Source: 'classification name only in Factur-X EXTENDED'),
    (Key: LandrixEInvoiceRuleLineOrderNumber; Standards: AnyStandard; Syntaxes: AnySyntax;
     Profiles: AnyProfile - [epr_Extended]; Level: erl_Forbidden; Terms: 'BT-X-21';
     Source: 'line order number only in Factur-X EXTENDED'),
    (Key: LandrixEInvoiceRuleLineTaxExemptionReason; Standards: AnyStandard; Syntaxes: AnySyntax;
     Profiles: AnyProfile - [epr_Extended]; Level: erl_Forbidden; Terms: 'BT-X-96';
     Source: 'line exemption reason only in Factur-X EXTENDED'),
    (Key: LandrixEInvoiceRuleLineDelivery; Standards: AnyStandard; Syntaxes: AnySyntax;
     Profiles: AnyProfile - [epr_Extended]; Level: erl_Forbidden; Terms: 'BT-X-85, BG-X-83, BT-X-92, BT-X-93, BT-X-94';
     Source: 'line delivery only in Factur-X EXTENDED'),
    (Key: LandrixEInvoiceRuleDespatchAdviceDate; Standards: AnyStandard; Syntaxes: AnySyntax;
     Profiles: AnyProfile - [epr_Extended]; Level: erl_Forbidden; Terms: 'BT-X-200';
     Source: 'despatch advice date only in Factur-X EXTENDED'),
    (Key: LandrixEInvoiceRuleDeliveryNote; Standards: AnyStandard; Syntaxes: AnySyntax;
     Profiles: AnyProfile - [epr_Extended]; Level: erl_Forbidden; Terms: 'BT-X-202, BT-X-203';
     Source: 'delivery note only in Factur-X EXTENDED'),
    (Key: LandrixEInvoiceRuleStructuredPaymentTerms; Standards: AnyStandard; Syntaxes: [esy_CII];
     Profiles: AnyProfile - [epr_Extended]; Level: erl_Forbidden; Terms: 'BG-X-44';
     Source: 'one payment term in EN 16931; discount terms only in Factur-X EXTENDED'),
    { CII-SR-450 is in the EN 16931 CII schematron (XRechnung), not in the
      Factur-X schematron of any profile (ZUGFeRD 2.5.2 example B01 has both) }
    (Key: LandrixEInvoiceRuleBuyerIDWithGlobalID; Standards: [est_XRechnung]; Syntaxes: [esy_CII];
     Profiles: AnyProfile; Level: erl_Forbidden; Terms: 'BT-46';
     Source: 'CII-SR-450'),
    (Key: LandrixEInvoiceRuleBuyerIDWithGlobalID; Standards: AnyStandard; Syntaxes: [esy_UBL];
     Profiles: AnyProfile; Level: erl_Forbidden; Terms: 'BT-46';
     Source: 'UBL-SR-16'),
    { XRechnung-for-Delphi writes one seller identifier besides BT-90
      (VD-Valitool-23); EN 16931 itself allows several }
    (Key: LandrixEInvoiceRuleSellerIDWithGlobalID; Standards: AnyStandard; Syntaxes: [esy_UBL];
     Profiles: AnyProfile; Level: erl_Forbidden; Terms: 'BT-29';
     Source: 'one seller identifier in UBL (VD-Valitool-23)'),
    { UBL has no structured payment terms or line delivery of this kind }
    (Key: LandrixEInvoiceRuleStructuredPaymentTerms; Standards: AnyStandard; Syntaxes: [esy_UBL];
     Profiles: AnyProfile; Level: erl_Forbidden; Terms: 'BG-X-44';
     Source: 'not in the UBL syntax of EN 16931'),
    { XRechnung }
    (Key: LandrixEInvoiceRuleMultiplePrecedingInvoices; Standards: [est_XRechnung]; Syntaxes: [esy_CII];
     Profiles: AnyProfile; Level: erl_Forbidden; Terms: 'BG-3';
     Source: 'one ram:InvoiceReferencedDocument in XRechnung CII'),
    (Key: LandrixEInvoiceRuleBuyerReferencePlaceholder; Standards: [est_XRechnung]; Syntaxes: AnySyntax;
     Profiles: AnyProfile; Level: erl_Allowed; Terms: 'BT-10';
     Source: 'XRechnung: buyer reference is mandatory'),
    { XRechnung-for-Delphi writes the placeholder for Peppol too, where BT-10
      or BT-13 is mandatory }
    (Key: LandrixEInvoiceRuleBuyerReferencePlaceholder; Standards: [est_PeppolBIS]; Syntaxes: AnySyntax;
     Profiles: AnyProfile; Level: erl_Allowed; Terms: 'BT-10';
     Source: 'Peppol: BT-10 or BT-13 is mandatory (PEPPOL-EN16931-R003)'),
    (Key: LandrixEInvoiceRuleBuyerReferencePlaceholder; Standards: AnyStandard; Syntaxes: AnySyntax;
     Profiles: AnyProfile; Level: erl_Forbidden; Terms: 'BT-10';
     Source: 'placeholder only for XRechnung and Peppol'),
    (Key: LandrixEInvoiceRuleCreditNoteDueDate; Standards: [est_XRechnung]; Syntaxes: AnySyntax;
     Profiles: AnyProfile; Level: erl_Forbidden; Terms: 'BT-9';
     Source: 'XRechnung credit note without due date'),
    (Key: LandrixEInvoiceRuleCreditNoteDueDate; Standards: AnyStandard; Syntaxes: [esy_UBL];
     Profiles: AnyProfile; Level: erl_Forbidden; Terms: 'BT-9';
     Source: 'UBL CreditNote has no cbc:DueDate'),
    { Peppol }
    (Key: LandrixEInvoiceRuleElectronicAddressDefaultEM; Standards: [est_PeppolBIS]; Syntaxes: AnySyntax;
     Profiles: AnyProfile; Level: erl_Forbidden; Terms: 'BT-34, BT-49';
     Source: 'Peppol: scheme from the EAS code list, no default'),
    { third-party payments: XRechnung extension of UBL; Factur-X EXTENDED as
      financial adjustment }
    (Key: LandrixEInvoiceRuleThirdPartyPayments; Standards: [est_XRechnung]; Syntaxes: [esy_UBL];
     Profiles: AnyProfile; Level: erl_Allowed; Terms: 'BG-DEX-09';
     Source: 'XRechnung extension (UBL cac:PrepaidPayment)'),
    (Key: LandrixEInvoiceRuleThirdPartyPayments; Standards: [est_FacturX]; Syntaxes: [esy_CII];
     Profiles: [epr_Extended]; Level: erl_Allowed; Terms: 'BG-DEX-09';
     Source: 'Factur-X EXTENDED ram:SpecifiedFinancialAdjustment (BR-FXEXT-CO-16)'),
    (Key: LandrixEInvoiceRuleThirdPartyPayments; Standards: AnyStandard; Syntaxes: AnySyntax;
     Profiles: AnyProfile; Level: erl_Forbidden; Terms: 'BG-DEX-09';
     Source: 'only in the XRechnung extension of UBL and in Factur-X EXTENDED'),
    { further EXTENDED-only content (Factur-X 1.09.2 field table) }
    (Key: LandrixEInvoiceRuleTestIndicator; Standards: AnyStandard; Syntaxes: AnySyntax;
     Profiles: AnyProfile - [epr_Extended]; Level: erl_Forbidden; Terms: 'BT-X-1';
     Source: 'test indicator only in Factur-X EXTENDED'),
    (Key: LandrixEInvoiceRuleDocumentName; Standards: AnyStandard; Syntaxes: AnySyntax;
     Profiles: AnyProfile - [epr_Extended]; Level: erl_Forbidden; Terms: 'BT-X-2';
     Source: 'document name only in Factur-X EXTENDED'),
    (Key: LandrixEInvoiceRuleOrderDates; Standards: AnyStandard; Syntaxes: AnySyntax;
     Profiles: AnyProfile - [epr_Extended]; Level: erl_Forbidden; Terms: 'BT-X-146, BT-X-147';
     Source: 'order dates only in Factur-X EXTENDED'),
    (Key: LandrixEInvoiceRuleLineOrderDate; Standards: AnyStandard; Syntaxes: AnySyntax;
     Profiles: AnyProfile - [epr_Extended]; Level: erl_Forbidden; Terms: 'BT-X-22';
     Source: 'line order date only in Factur-X EXTENDED'),
    (Key: LandrixEInvoiceRuleDeliveryContact; Standards: AnyStandard; Syntaxes: AnySyntax;
     Profiles: AnyProfile - [epr_Extended]; Level: erl_Forbidden; Terms: 'BG-X-26';
     Source: 'deliver to contact only in Factur-X EXTENDED'),
    (Key: LandrixEInvoiceRuleInvoicee; Standards: AnyStandard; Syntaxes: AnySyntax;
     Profiles: AnyProfile - [epr_Extended]; Level: erl_Forbidden; Terms: 'BG-X-36';
     Source: 'invoicee only in Factur-X EXTENDED'),
    (Key: LandrixEInvoiceRulePayeeExtended; Standards: AnyStandard; Syntaxes: AnySyntax;
     Profiles: AnyProfile - [epr_Extended]; Level: erl_Forbidden; Terms: 'BG-10';
     Source: 'payee address, contact and VAT identifier only in Factur-X EXTENDED'),
    (Key: LandrixEInvoiceRuleTaxRepresentativeExtended; Standards: AnyStandard; Syntaxes: AnySyntax;
     Profiles: AnyProfile - [epr_Extended]; Level: erl_Forbidden; Terms: 'BG-11';
     Source: 'tax representative identifiers and contact only in Factur-X EXTENDED'),
    (Key: LandrixEInvoiceRuleCashDiscountNote; Standards: AnyStandard; Syntaxes: AnySyntax;
     Profiles: AnyProfile - [epr_Extended]; Level: erl_Forbidden; Terms: 'BT-20';
     Source: 'text per cash discount level only in the structured terms of Factur-X EXTENDED'),
    { CII-SR-458 and UBL-SR-04 belong to the EN 16931 Schematron; the Factur-X
      Schematron has no such rule. DE: CII-SR-458 und UBL-SR-04 gehoeren zum
      EN-16931-Schematron; das Factur-X-Schematron kennt keine solche Regel. }
    (Key: LandrixEInvoiceRuleFurtherObjectIdentifier; Standards: AnyStandard; Syntaxes: [esy_CII];
     Profiles: AnyProfile - [epr_Extended]; Level: erl_Forbidden; Terms: 'BT-18';
     Source: 'one object identifier (CII-SR-458, UBL-SR-04); several only in Factur-X EXTENDED'),
    { UBL cac:Contact has no department }
    (Key: LandrixEInvoiceRuleContactDepartment; Standards: AnyStandard; Syntaxes: [esy_UBL];
     Profiles: AnyProfile; Level: erl_Forbidden; Terms: 'BT-41-0, BT-56-0';
     Source: 'not in the UBL syntax of EN 16931'),
    (Key: LandrixEInvoiceRuleContactDepartment; Standards: AnyStandard; Syntaxes: [esy_CII];
     Profiles: AnyProfile; Level: erl_Allowed; Terms: 'BT-41-0, BT-56-0';
     Source: 'EN 16931 CII')
  );

function Matches(const ARule: TLandrixEInvoiceRule; const ASpec: TLandrixEInvoiceSpec): Boolean;
begin
  Result := (ASpec.Target.Standard in ARule.Standards) and
    (ASpec.Target.Syntax in ARule.Syntaxes) and (ASpec.Target.Profile in ARule.Profiles);
end;

function LandrixEInvoiceFindRule(const ASpec: TLandrixEInvoiceSpec; const AKey: string;
  out ARule: TLandrixEInvoiceRule): Boolean;
var
  I: Integer;
begin
  for I := Low(Rules) to High(Rules) do
    if (Rules[I].Key = AKey) and Matches(Rules[I], ASpec) then
    begin
      ARule := Rules[I];
      Result := True;
      Exit;
    end;
  Result := False;
end;

function LandrixEInvoiceRuleLevel(const ASpec: TLandrixEInvoiceSpec;
  const AKey: string): TLandrixEInvoiceRuleLevel;
var
  Rule: TLandrixEInvoiceRule;
begin
  if LandrixEInvoiceFindRule(ASpec, AKey, Rule) then
    Result := Rule.Level
  else
    Result := erl_Allowed;
end;

function LandrixEInvoiceRuleCount: Integer;
begin
  Result := Length(Rules);
end;

function LandrixEInvoiceRule(AIndex: Integer): TLandrixEInvoiceRule;
begin
  if (AIndex < 0) or (AIndex > High(Rules)) then
    raise ELandrixEInvoiceError.Create('LandrixEInvoiceRule index out of range');
  Result := Rules[AIndex];
end;

end.
