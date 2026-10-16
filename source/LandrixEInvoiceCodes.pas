{
  EInvoice-for-Pascal

  Copyright (C) 2026 Landrix Software GmbH & Co. KG

  This file is dual-licensed under:
  - GNU GPL version 3 or later; or
  - the Landrix Software Commercial License.

  See LICENSE and COMMERCIAL-LICENSE.md.

  SPDX-License-Identifier: GPL-3.0-or-later OR LicenseRef-Landrix-Commercial
}

{ Code lists of the invoice model: one enumeration per list and functions
  that convert between members and codes.

  Rules for every list:
  - The first member means "not set"; its code is ''.
  - Only the members listed here are supported. The member names are part of
    the public API and stay stable; new codes are appended.
  - ...ToStr returns the code of a member. ...FromStr finds the member for a
    code (ASCII case-insensitive) and returns False, with the "not set"
    member, for an empty or unknown code.
  - This unit will later be generated from the official code lists; the
    member names are kept then.
  - Library-own lists (payment terms type, line status reason code) are
    declared in LandrixEInvoiceInvoice.

  DE: Codelisten des Rechnungsmodells: je Liste eine Aufzaehlung und
  Funktionen zur Umwandlung zwischen Aufzaehlungswert und Code.

  Regeln fuer jede Liste:
  - Das erste Element bedeutet "nicht gesetzt"; sein Code ist ''.
  - Unterstuetzt werden nur die hier aufgefuehrten Werte. Die Namen der Werte
    gehoeren zur oeffentlichen API und bleiben stabil; neue Codes werden
    angehaengt.
  - ...ToStr liefert den Code eines Werts. ...FromStr sucht den Wert zu einem
    Code (ASCII, ohne Unterscheidung von Gross- und Kleinschreibung) und
    liefert False und den Wert "nicht gesetzt" bei leerem oder unbekanntem
    Code.
  - Die Unit wird spaeter aus den offiziellen Codelisten erzeugt; die Namen
    der Werte bleiben dabei erhalten.
  - Bibliothekseigene Listen (Art der Zahlungsbedingungen, Untertyp der
    Rechnungsposition) stehen in LandrixEInvoiceInvoice. }

unit LandrixEInvoiceCodes;

{$I LandrixEInvoice.inc}

interface

uses
  LandrixEInvoiceTypes;

type
  { Invoice type code (BT-3), UNTDID 1001.
    DE: Rechnungsart (BT-3), UNTDID 1001. }
  TLandrixInvoiceTypeCode = (
    itc_None,

    { 84 Debit note related to financial adjustments. Not for XRechnung.
      DE: Belastungsanzeige fuer finanzielle Anpassungen. Nicht in XRechnung
      verwenden. }
    itc_DebitnoteRelatedToFinancialAdjustments,

    { 261 Self-billed credit note. Not for XRechnung.
      DE: Selbst ausgestellte Gutschrift. Nicht in XRechnung verwenden. }
    itc_SelfBilledCreditNote,

    { 326 Partial invoice (in fact a partial final invoice): bills one or
      more services already rendered, typically in longer projects or for
      staggered deliveries. Unlike a down payment invoice it bills only
      services actually rendered, with all warranty obligations.
      DE: Teilrechnung (eigentlich Teilschlussrechnung): rechnet einen oder
      mehrere erbrachte Leistungsposten ab, meist bei laengeren Projekten oder
      gestaffelten Lieferungen. Anders als eine Abschlagsrechnung rechnet sie
      nur tatsaechlich erbrachte Leistungen ab, mit allen damit verbundenen
      Gewaehrleistungspflichten. }
    itc_PartialInvoice,

    { 380 Commercial invoice, the normal case for most invoices.
      DE: Rechnung, der Normalfall fuer die meisten Rechnungen. }
    itc_CommercialInvoice,

    { 383 Debit note. Not for XRechnung.
      DE: Belastungsanzeige. Nicht in XRechnung verwenden. }
    itc_DebitNote,

    { 384 Corrected invoice (also cancellation invoice): issued when an
      invoice was wrong or the service was incomplete or defective and the
      amount must be reduced. It always refers to an existing invoice:
      BT-25 number and BT-26 date of the original invoice (XRechnung 3.0.2
      chapter 13.1, BR-DE-26). A complete cancellation has negative
      quantities with positive unit prices, hence negative totals.
      DE: Rechnungskorrektur (auch Stornorechnung): wird erstellt, wenn eine
      Rechnung falsch war oder die Leistung unvollstaendig oder mangelhaft
      erbracht wurde und der Betrag sinken muss. Sie bezieht sich immer auf
      eine bestehende Rechnung: BT-25 Nummer und BT-26 Datum der
      Originalrechnung (XRechnung 3.0.2 Kap. 13.1, BR-DE-26). Ein
      vollstaendiges Storno hat negative Mengen bei positiven Einzelpreisen
      und damit negative Summen. }
    itc_CorrectedInvoice,

    { 386 Prepayment invoice. Not recommended in XRechnung (BR-DE-17 lists
      only 326, 380, 381, 384, 389, 875, 876, 877; warning, no rejection).
      Invoices in advance (e.g. maintenance) are better 380 with a note.
      DE: Vorauszahlungsrechnung. In XRechnung nicht empfohlen (BR-DE-17
      nennt nur 326, 380, 381, 384, 389, 875, 876, 877; Warnung, kein
      Abbruch). Vorausrechnungen (z. B. Wartung im Voraus) besser als 380
      mit Hinweis im Rechnungstext. }
    itc_PrepaymentInvoice,

    { 457 Cancellation. Not for XRechnung.
      DE: Storno. Nicht in XRechnung verwenden. }
    itc_Cancellation,

    { 389 Self-billed invoice, issued by the customer (credit note in the
      sense of German VAT law, section 14 (2) UStG). The supplier receives a
      copy and the payment.
      DE: Selbst ausgestellte Rechnung des Kunden (umsatzsteuerliche
      Gutschrift, Paragraph 14 Abs. 2 UStG). Der Lieferant erhaelt eine Kopie
      und die Zahlung. }
    itc_SelfbilledInvoice,

    { 381 Credit note of the supplier to the customer, e.g. for returns or
      price reductions. Not the credit note in the sense of section 14 (2)
      UStG (use 389). In UBL 381 is a separate CreditNote document, in CII
      only the code. To cancel an own invoice use 384.
      DE: Kaufmaennische Gutschrift des Lieferanten an den Kunden, z. B. fuer
      Rueckgaben oder Preisnachlaesse. Nicht die umsatzsteuerliche Gutschrift
      nach Paragraph 14 Abs. 2 UStG (dafuer 389). In UBL ist 381 ein eigenes
      CreditNote-Dokument, in CII nur der Code. Fuer das Storno einer eigenen
      Rechnung 384 verwenden. }
    itc_CreditNote,

    { 875 Down payment invoice for construction work. Not as binding as a
      partial final or final invoice.
      DE: Abschlagsrechnung fuer Bauleistungen. Nicht so verbindlich wie eine
      Teilschluss- oder Schlussrechnung. }
    itc_PartialConstructionInvoice,

    { 876 Partial final invoice for construction work: same character as a
      final invoice, bills work accepted in a partial acceptance.
      DE: Teilschlussrechnung fuer Bauleistungen: hat denselben Charakter wie
      eine Schlussrechnung und rechnet Arbeiten einer Teilabnahme ab. }
    itc_PartialFinalConstructionInvoice,

    { 877 Final invoice for construction work, based on completion and
      acceptance of the agreed work plus any additional claims.
      DE: Schlussrechnung fuer Bauleistungen, auf Grundlage von
      Fertigstellung und Abnahme der vereinbarten Leistungen zuzueglich
      etwaiger Nachforderungen. }
    itc_FinalConstructionInvoice
  );

  { Payment means type code (BT-81), UNTDID 4461. Codes in comments.
    DE: Zahlungsart (BT-81), UNTDID 4461. Codes in den Kommentaren. }
  TLandrixInvoicePaymentMeansCode = (
    ipmc_NotImplemented,
    ipmc_InstrumentNotDefined,                                 // 1
    ipmc_AutomatedClearingHouseCredit,                         // 2
    ipmc_AutomatedClearingHouseDebit,                          // 3
    ipmc_ACH_DemandDebitReversal,                              // 4
    ipmc_ACH_DemandCreditReversal,                             // 5
    ipmc_ACH_Demand_Credit,                                    // 6
    ipmc_ACH_Demand_Debit,                                     // 7
    ipmc_Hold,                                                 // 8
    ipmc_NationalOrRegionalClearing,                           // 9
    ipmc_InCash,                                               // 10
    ipmc_ACH_SavingsCreditReversal,                            // 11
    ipmc_ACH_SavingsDebitReversal,                             // 12
    ipmc_ACH_SavingsCredit,                                    // 13
    ipmc_ACH_SavingsDebit,                                     // 14
    ipmc_BookEntryCredit,                                      // 15
    ipmc_BookEntryDebit,                                       // 16
    ipmc_ACH_DemandCashConcentrationDisbursementCredit,        // 17
    ipmc_ACH_DemandCashConcentrationDisbursementDebit,         // 18
    ipmc_ACH_DemandCorporateTradePaymentCredit,                // 19
    ipmc_Cheque,                                               // 20
    ipmc_BankersDraft,                                         // 21
    ipmc_CertifiedBankerDraft,                                 // 22
    ipmc_BankChequeIssuedByEstablishment,                      // 23
    ipmc_BillOfExchangeAwaitingAcceptance,                     // 24
    ipmc_CertifiedCheque,                                      // 25
    ipmc_LocalCheque,                                          // 26
    ipmc_ACH_DemandCorporateTradePaymentDebit,                 // 27
    ipmc_ACH_DemandCorporateTradeExchangeCredit,               // 28
    ipmc_ACH_DemandCorporateTradeExchangeDebit,                // 29
    ipmc_CreditTransfer,                                       // 30 non-SEPA
    ipmc_DebitTransfer,                                        // 31
    ipmc_ACH_DemandCashConcentrationDisbursementPlusCredit,    // 32
    ipmc_ACH_DemandCashConcentrationDisbursementPlusDebit,     // 33
    ipmc_ACH_PrearrangedPaymentAndDeposit,                     // 34
    ipmc_ACH_SavingsCashConcentrationDisbursementCredit,       // 35
    ipmc_ACH_SavingsCashConcentrationDisbursementDebit,        // 36
    ipmc_ACH_SavingsCorporateTradePaymentCredit,               // 37
    ipmc_ACH_SavingsCorporateTradePaymentDebit,                // 38
    ipmc_ACH_SavingsCorporateTradeExchangeCredit,              // 39
    ipmc_ACH_SavingsCorporateTradeExchangeDebit,               // 40
    ipmc_ACH_SavingsCashConcentrationDisbursementPlusCredit,   // 41
    ipmc_PaymentToBankAccount,                                 // 42
    ipmc_ACH_SavingsCashConcentrationDisbursementPlusDebit,    // 43
    ipmc_AcceptedBillOfExchange,                               // 44
    ipmc_ReferencedHomeBankingCreditTransfer,                  // 45
    ipmc_InterbankDebitTransfer,                               // 46
    ipmc_HomeBankingDebitTransfer,                             // 47
    ipmc_BankCard,                                             // 48
    ipmc_DirectDebit,                                          // 49
    ipmc_PaymentByPostgiro,                                    // 50
    ipmc_FR_Norme_6_97,                                        // 51
    ipmc_UrgentCommercialPayment,                              // 52
    ipmc_UrgentTreasuryPayment,                                // 53
    ipmc_CreditCard,                                           // 54
    ipmc_DebitCard,                                            // 55
    ipmc_Bankgiro,                                             // 56
    ipmc_StandingAgreement,                                    // 57
    ipmc_SEPACreditTransfer,                                   // 58
    ipmc_SEPADirectDebit,                                      // 59
    ipmc_PromissoryNote,                                       // 60
    ipmc_PromissoryNoteSignedByDebtor,                         // 61
    ipmc_PromissoryNoteSignedByDebtorEndorsedByBank,           // 62
    ipmc_PromissoryNoteSignedByDebtorEndorsedByThirdParty,     // 63
    ipmc_PromissoryNoteSignedByBank,                           // 64
    ipmc_PromissoryNoteSignedByBankEndorsedByAnotherBank,      // 65
    ipmc_PromissoryNoteSignedByThirdParty,                     // 66
    ipmc_PromissoryNoteSignedByThirdPartyEndorsedByBank,       // 67
    ipmc_OnlinePaymentService,                                 // 68 e.g. PayPal
    ipmc_TransferAdvice,                                       // 69
    ipmc_BillDrawnByCrdtOnDebtor,                              // 70
    ipmc_BillDrawnByCrdtOnBank,                                // 74
    ipmc_BillDrawnByCrdtEndorsedByAnotherBank,                 // 75
    ipmc_BillDrawnByCrdtOnBankEndorsedByThirdParty,            // 76
    ipmc_BillDrawnByCrdtOnThirdParty,                          // 77
    ipmc_BillDrawnByCrdtOnThirdPartyAcceptedAndEndorsedByBank, // 78
    ipmc_NotTransferableBankersDraft,                          // 91
    ipmc_NotTransferableLocalCheque,                           // 92
    ipmc_ReferenceGiro,                                        // 93
    ipmc_UrgentGiro,                                           // 94
    ipmc_FreeFormatGiro,                                       // 95
    ipmc_RequestedMethodForPaymentWasNotUsed,                  // 96
    ipmc_ClearingBetweenPartners,                              // 97
    ipmc_MutuallyDefined                                       // ZZZ
  );

  { Unit of measure (BT-130, BT-150), UN/ECE Recommendation 20/21. Codes in
    comments.
    DE: Mengeneinheit (BT-130, BT-150), UN/ECE-Empfehlung 20/21. Codes in den
    Kommentaren. }
  TLandrixInvoiceUnitCode = (
    iuc_None,
    iuc_one,                  // C62 unit of count
    iuc_piece,                // H87
    iuc_flaterate,            // LS lump sum
    iuc_number_of_articles,   // NAR
    iuc_set,                  // SET
    iuc_week,                 // WEE
    iuc_month,                // MON
    iuc_day,                  // DAY
    iuc_tonne_metric_ton,     // TNE
    iuc_square_metre,         // MTK
    iuc_cubic_metre,          // MTQ
    iuc_metre,                // MTR
    iuc_square_millimetre,    // MMK
    iuc_cubic_millimetre,     // MMQ
    iuc_millimetre,           // MMT
    iuc_minute_unit_of_time,  // MIN
    iuc_second_unit_of_time,  // SEC
    iuc_millilitre,           // MLT
    iuc_litre,                // LTR
    iuc_hour,                 // HUR
    iuc_milligram,            // MGM
    iuc_gram,                 // GRM
    iuc_kilogram,             // KGM
    iuc_kilometre,            // KMT
    iuc_kilowatt_hour,        // KWH
    iuc_percent,              // P1
    iuc_packaging,            // XPK
    iuc_year,                 // ANN
    iuc_person,               // IE
    iuc_square_decimetre,     // DMK
    iuc_cubic_decimetre,      // DMQ
    iuc_decimetre,            // DMT
    iuc_centimetre,           // CMT
    iuc_square_centimetre,    // CMK
    iuc_cubic_centimetre,     // CMQ
    iuc_pair,                 // PR
    iuc_bag,                  // XBG
    iuc_roll,                 // XRO
    iuc_foot,                 // FOT
    iuc_inch,                 // INH
    iuc_hectare               // H18 (Factur-X rejects HAR; FromStr also reads HAR)
  );

  { MIME type of an attached document (BT-125-1). The code is the MIME type,
    e.g. application/pdf.
    DE: MIME-Typ eines angehaengten Dokuments (BT-125-1). Der Code ist der
    MIME-Typ, z. B. application/pdf. }
  TLandrixInvoiceAttachmentType = (
    iat_application_None,
    iat_application_pdf,
    iat_image_png,
    iat_image_jpeg,
    iat_text_csv,
    iat_application_vnd_openxmlformats_officedocument_spreadsheetml_sheet,
    iat_application_vnd_oasis_opendocument_spreadsheet,
    iat_application_xml // since XRechnung 2.0.0
  );

  { Type code of a referenced document, subset of UNTDID 1001: 916 "related
    document" references a supporting document (BT-122, default), 50
    "price/sales catalogue response" the tender or lot (BT-17), 130
    "invoicing data sheet" an object identifier of the seller (BT-18).
    DE: Art eines referenzierten Dokuments, Auswahl aus UNTDID 1001: 916
    "Referenzpapier" fuer die rechnungsbegruendende Unterlage (BT-122,
    Standard), 50 "Price/sales catalogue response" fuer die Ausschreibung
    oder das Los (BT-17), 130 "Rechnungsdatenblatt" fuer eine vom Verkaeufer
    vergebene Objektkennung (BT-18). }
  TLandrixInvoiceAttachmentTypeCode = (
    iatc_None,
    iatc_50,  // BT-17
    iatc_130, // BT-18
    iatc_916  // BT-122
  );

  { Reason code of an allowance (BT-98, BT-140), UNTDID 5189. Only the codes
    allowed in XRechnung for allowances (ChargeIndicator = false).
    DE: Grund eines Nachlasses (BT-98, BT-140), UNTDID 5189. Nur die in
    XRechnung fuer Nachlaesse (ChargeIndicator = false) zulaessigen Codes. }
  TLandrixInvoiceAllowanceOrChargeIdentCode = (
    iacic_None,
    iacic_BonusForWorksAheadOfSchedule,   // 41
    iacic_OtherBonus,                     // 42
    iacic_ManufacturersConsumerDiscount,  // 60
    iacic_DueToMilitaryStatus,            // 62
    iacic_DueToWorkAccident,              // 63
    iacic_SpecialAgreement,               // 64
    iacic_ProductionErrorDiscount,        // 65
    iacic_NewOutletDiscount,              // 66
    iacic_SampleDiscount,                 // 67
    iacic_EndOfRangeDiscount,             // 68
    iacic_IncotermDiscount,               // 70
    iacic_PointOfSalesThresholdAllowance, // 71
    iacic_MaterialSurchargeDeduction,     // 88
    iacic_Discount,                       // 95
    iacic_SpecialRebate,                  // 100
    iacic_FixedLongTerm,                  // 102
    iacic_Temporary,                      // 103
    iacic_Standard,                       // 104
    iacic_YearlyTurnover                  // 105
  );

  { Reason code of a charge (BT-105, BT-145), UNTDID 7161 (selection,
    ChargeIndicator = true).
    DE: Grund eines Zuschlags (BT-105, BT-145), UNTDID 7161 (Auswahl,
    ChargeIndicator = true). }
  TLandrixInvoiceSpecialServiceDescriptionCode = (
    issdc_None,
    issdc_AA_Advertising,
    issdc_AAA_Telecommunication,
    issdc_ABK_Miscellaneous,
    issdc_ABL_AdditionalPackaging,
    issdc_ADR_OtherServices,
    issdc_ADT_Pickup,
    issdc_FC_FreightService,
    issdc_FI_Financing,
    issdc_LA_Labelling,
    issdc_PC_Packing
  );

  { VAT category code (BT-95, BT-102, BT-118, BT-151), UNTDID 5305, the
    subset allowed in EN 16931: S standard rate, Z zero rated goods, E
    exempt, AE reverse charge (also for business customers under reverse
    charge), K intra-community supply in the EEA, G export outside the EU,
    O outside the scope of VAT, L Canary Islands (IGIC), M Ceuta and Melilla
    (IPSI).
    DE: Umsatzsteuerkategorie (BT-95, BT-102, BT-118, BT-151), UNTDID 5305,
    die in EN 16931 erlaubte Auswahl: S Normalsatz, Z Nullsatz, E
    steuerbefreit, AE Umkehrung der Steuerschuldnerschaft (auch bei
    gewerblichen Kunden im Reverse-Charge), K innergemeinschaftliche
    Lieferung im EWR, G Export ausserhalb der EU, O nicht steuerbar, L
    Kanarische Inseln (IGIC), M Ceuta und Melilla (IPSI). }
  TLandrixInvoiceDutyTaxFeeCategoryCode = (
    idtfcc_None,
    idtfcc_AE_VATReverseCharge,
    idtfcc_E_ExemptFromTax,
    idtfcc_G_FreeExportItemTaxNotCharged,
    idtfcc_K_VATExemptForEEAIntracommunitySupplyOfGoodsAndServices,
    idtfcc_L_CanaryIslandsGeneralIndirectTax,
    idtfcc_M_TaxForProductionServicesAndImportationInCeutaAndMelilla,
    idtfcc_O_ServicesOutsideScopeOfTax,
    idtfcc_S_StandardRate,
    idtfcc_Z_ZeroRatedGoods
  );

  { Subject of an invoice note (BT-21), selection from UNTDID 4451. "Not
    set" means free text.
    DE: Betreff eines Rechnungshinweises (BT-21), Auswahl aus UNTDID 4451.
    "Nicht gesetzt" bedeutet Freitext. }
  TLandrixInvoiceNoteSubjectCode = (
    insc_None,
    insc_AAI, // general information / allgemeine Informationen
    insc_AAJ, // additional conditions of sale (e.g. retention of title) / zusaetzliche Kaufkonditionen (z. B. Eigentumsvorbehalt)
    insc_AAK, // price conditions (e.g. discount or bonus agreements) / Preiskonditionen (z. B. Rabatt- oder Bonusvereinbarungen)
    insc_SUR, // supplier remarks / Anmerkungen des Verkaeufers
    insc_REG, // regulatory information / regulatorische Informationen
    insc_ABL, // legal information / rechtliche Informationen
    insc_TXD, // tax declaration / Informationen zur Steuer
    insc_CUS, // customs declaration / Zollinformationen
    insc_PMT, // payment information (e.g. guarantees, retentions) / Zahlungsinformationen (z. B. Buergschaften, Sicherheitseinbehalte)
    insc_BLP  // legislation (e.g. retention duty, section 14b UStG) / gesetzliche Vorschriften (z. B. Aufbewahrungspflicht nach Paragraph 14b UStG)
  );

{ Conversion between members and codes, see the rules at the top of the
  unit.
  DE: Umwandlung zwischen Werten und Codes, siehe die Regeln am Anfang der
  Unit. }
function LandrixEInvoiceTypeCodeToStr(Value: TLandrixInvoiceTypeCode): TLandrixEInvoiceString;
function LandrixEInvoiceTypeCodeFromStr(const Code: TLandrixEInvoiceString;
  out Value: TLandrixInvoiceTypeCode): Boolean;
function LandrixEInvoicePaymentMeansCodeToStr(Value: TLandrixInvoicePaymentMeansCode): TLandrixEInvoiceString;
function LandrixEInvoicePaymentMeansCodeFromStr(const Code: TLandrixEInvoiceString;
  out Value: TLandrixInvoicePaymentMeansCode): Boolean;
function LandrixEInvoiceUnitCodeToStr(Value: TLandrixInvoiceUnitCode): TLandrixEInvoiceString;
function LandrixEInvoiceUnitCodeFromStr(const Code: TLandrixEInvoiceString;
  out Value: TLandrixInvoiceUnitCode): Boolean;
function LandrixEInvoiceAttachmentTypeToStr(Value: TLandrixInvoiceAttachmentType): TLandrixEInvoiceString;
function LandrixEInvoiceAttachmentTypeFromStr(const Code: TLandrixEInvoiceString;
  out Value: TLandrixInvoiceAttachmentType): Boolean;
function LandrixEInvoiceAttachmentTypeCodeToStr(Value: TLandrixInvoiceAttachmentTypeCode): TLandrixEInvoiceString;
function LandrixEInvoiceAttachmentTypeCodeFromStr(const Code: TLandrixEInvoiceString;
  out Value: TLandrixInvoiceAttachmentTypeCode): Boolean;
function LandrixEInvoiceAllowanceOrChargeIdentCodeToStr(Value: TLandrixInvoiceAllowanceOrChargeIdentCode): TLandrixEInvoiceString;
function LandrixEInvoiceAllowanceOrChargeIdentCodeFromStr(const Code: TLandrixEInvoiceString;
  out Value: TLandrixInvoiceAllowanceOrChargeIdentCode): Boolean;
function LandrixEInvoiceSpecialServiceDescriptionCodeToStr(Value: TLandrixInvoiceSpecialServiceDescriptionCode): TLandrixEInvoiceString;
function LandrixEInvoiceSpecialServiceDescriptionCodeFromStr(const Code: TLandrixEInvoiceString;
  out Value: TLandrixInvoiceSpecialServiceDescriptionCode): Boolean;
function LandrixEInvoiceDutyTaxFeeCategoryCodeToStr(Value: TLandrixInvoiceDutyTaxFeeCategoryCode): TLandrixEInvoiceString;
function LandrixEInvoiceDutyTaxFeeCategoryCodeFromStr(const Code: TLandrixEInvoiceString;
  out Value: TLandrixInvoiceDutyTaxFeeCategoryCode): Boolean;
function LandrixEInvoiceNoteSubjectCodeToStr(Value: TLandrixInvoiceNoteSubjectCode): TLandrixEInvoiceString;
function LandrixEInvoiceNoteSubjectCodeFromStr(const Code: TLandrixEInvoiceString;
  out Value: TLandrixInvoiceNoteSubjectCode): Boolean;

implementation

const
  TypeCodes: array[TLandrixInvoiceTypeCode] of TLandrixEInvoiceString = (
    '', '84', '261', '326', '380', '383', '384', '386', '457', '389', '381',
    '875', '876', '877');

  PaymentMeansCodes: array[TLandrixInvoicePaymentMeansCode] of TLandrixEInvoiceString = (
    '',
    '1', '2', '3', '4', '5', '6', '7', '8', '9', '10',
    '11', '12', '13', '14', '15', '16', '17', '18', '19', '20',
    '21', '22', '23', '24', '25', '26', '27', '28', '29', '30',
    '31', '32', '33', '34', '35', '36', '37', '38', '39', '40',
    '41', '42', '43', '44', '45', '46', '47', '48', '49', '50',
    '51', '52', '53', '54', '55', '56', '57', '58', '59', '60',
    '61', '62', '63', '64', '65', '66', '67', '68', '69', '70',
    '74', '75', '76', '77', '78',
    '91', '92', '93', '94', '95', '96', '97',
    'ZZZ');

  UnitCodes: array[TLandrixInvoiceUnitCode] of TLandrixEInvoiceString = (
    '', 'C62', 'H87', 'LS', 'NAR', 'SET', 'WEE', 'MON', 'DAY', 'TNE',
    'MTK', 'MTQ', 'MTR', 'MMK', 'MMQ', 'MMT', 'MIN', 'SEC', 'MLT', 'LTR',
    'HUR', 'MGM', 'GRM', 'KGM', 'KMT', 'KWH', 'P1', 'XPK', 'ANN', 'IE',
    'DMK', 'DMQ', 'DMT', 'CMT', 'CMK', 'CMQ', 'PR', 'XBG', 'XRO', 'FOT',
    'INH', 'H18');

  AttachmentTypes: array[TLandrixInvoiceAttachmentType] of TLandrixEInvoiceString = (
    '',
    'application/pdf',
    'image/png',
    'image/jpeg',
    'text/csv',
    'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
    'application/vnd.oasis.opendocument.spreadsheet',
    'application/xml');

  AttachmentTypeCodes: array[TLandrixInvoiceAttachmentTypeCode] of TLandrixEInvoiceString = (
    '', '50', '130', '916');

  AllowanceCodes: array[TLandrixInvoiceAllowanceOrChargeIdentCode] of TLandrixEInvoiceString = (
    '', '41', '42', '60', '62', '63', '64', '65', '66', '67', '68', '70',
    '71', '88', '95', '100', '102', '103', '104', '105');

  ChargeCodes: array[TLandrixInvoiceSpecialServiceDescriptionCode] of TLandrixEInvoiceString = (
    '', 'AA', 'AAA', 'ABK', 'ABL', 'ADR', 'ADT', 'FC', 'FI', 'LA', 'PC');

  TaxCategoryCodes: array[TLandrixInvoiceDutyTaxFeeCategoryCode] of TLandrixEInvoiceString = (
    '', 'AE', 'E', 'G', 'K', 'L', 'M', 'O', 'S', 'Z');

  NoteSubjectCodes: array[TLandrixInvoiceNoteSubjectCode] of TLandrixEInvoiceString = (
    '', 'AAI', 'AAJ', 'AAK', 'SUR', 'REG', 'ABL', 'TXD', 'CUS', 'PMT', 'BLP');

function AsciiUpper(C: WideChar): WideChar;
begin
  if (C >= 'a') and (C <= 'z') then
    Result := WideChar(Ord(C) - 32)
  else
    Result := C;
end;

{ ASCII case-insensitive comparison; other characters must be equal. }
function SameCode(const A, B: TLandrixEInvoiceString): Boolean;
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

{ Each FromStr skips the "not set" member, so '' never matches. }

function LandrixEInvoiceTypeCodeToStr(Value: TLandrixInvoiceTypeCode): TLandrixEInvoiceString;
begin
  Result := TypeCodes[Value];
end;

function LandrixEInvoiceTypeCodeFromStr(const Code: TLandrixEInvoiceString;
  out Value: TLandrixInvoiceTypeCode): Boolean;
var
  V: TLandrixInvoiceTypeCode;
begin
  for V := Succ(Low(V)) to High(V) do
    if SameCode(TypeCodes[V], Code) then
    begin
      Value := V;
      Result := True;
      Exit;
    end;
  Value := Low(V);
  Result := False;
end;

function LandrixEInvoicePaymentMeansCodeToStr(Value: TLandrixInvoicePaymentMeansCode): TLandrixEInvoiceString;
begin
  Result := PaymentMeansCodes[Value];
end;

function LandrixEInvoicePaymentMeansCodeFromStr(const Code: TLandrixEInvoiceString;
  out Value: TLandrixInvoicePaymentMeansCode): Boolean;
var
  V: TLandrixInvoicePaymentMeansCode;
begin
  for V := Succ(Low(V)) to High(V) do
    if SameCode(PaymentMeansCodes[V], Code) then
    begin
      Value := V;
      Result := True;
      Exit;
    end;
  Value := Low(V);
  Result := False;
end;

function LandrixEInvoiceUnitCodeToStr(Value: TLandrixInvoiceUnitCode): TLandrixEInvoiceString;
begin
  Result := UnitCodes[Value];
end;

function LandrixEInvoiceUnitCodeFromStr(const Code: TLandrixEInvoiceString;
  out Value: TLandrixInvoiceUnitCode): Boolean;
var
  V: TLandrixInvoiceUnitCode;
begin
  for V := Succ(Low(V)) to High(V) do
    if SameCode(UnitCodes[V], Code) then
    begin
      Value := V;
      Result := True;
      Exit;
    end;
  { HAR is the hectare code of Rec. 20 that Factur-X rejects; read it as
    H18 so that UBL invoices with HAR keep their unit }
  if SameCode('HAR', Code) then
  begin
    Value := iuc_hectare;
    Result := True;
    Exit;
  end;
  Value := Low(V);
  Result := False;
end;

function LandrixEInvoiceAttachmentTypeToStr(Value: TLandrixInvoiceAttachmentType): TLandrixEInvoiceString;
begin
  Result := AttachmentTypes[Value];
end;

function LandrixEInvoiceAttachmentTypeFromStr(const Code: TLandrixEInvoiceString;
  out Value: TLandrixInvoiceAttachmentType): Boolean;
var
  V: TLandrixInvoiceAttachmentType;
begin
  for V := Succ(Low(V)) to High(V) do
    if SameCode(AttachmentTypes[V], Code) then
    begin
      Value := V;
      Result := True;
      Exit;
    end;
  Value := Low(V);
  Result := False;
end;

function LandrixEInvoiceAttachmentTypeCodeToStr(Value: TLandrixInvoiceAttachmentTypeCode): TLandrixEInvoiceString;
begin
  Result := AttachmentTypeCodes[Value];
end;

function LandrixEInvoiceAttachmentTypeCodeFromStr(const Code: TLandrixEInvoiceString;
  out Value: TLandrixInvoiceAttachmentTypeCode): Boolean;
var
  V: TLandrixInvoiceAttachmentTypeCode;
begin
  for V := Succ(Low(V)) to High(V) do
    if SameCode(AttachmentTypeCodes[V], Code) then
    begin
      Value := V;
      Result := True;
      Exit;
    end;
  Value := Low(V);
  Result := False;
end;

function LandrixEInvoiceAllowanceOrChargeIdentCodeToStr(Value: TLandrixInvoiceAllowanceOrChargeIdentCode): TLandrixEInvoiceString;
begin
  Result := AllowanceCodes[Value];
end;

function LandrixEInvoiceAllowanceOrChargeIdentCodeFromStr(const Code: TLandrixEInvoiceString;
  out Value: TLandrixInvoiceAllowanceOrChargeIdentCode): Boolean;
var
  V: TLandrixInvoiceAllowanceOrChargeIdentCode;
begin
  for V := Succ(Low(V)) to High(V) do
    if SameCode(AllowanceCodes[V], Code) then
    begin
      Value := V;
      Result := True;
      Exit;
    end;
  Value := Low(V);
  Result := False;
end;

function LandrixEInvoiceSpecialServiceDescriptionCodeToStr(Value: TLandrixInvoiceSpecialServiceDescriptionCode): TLandrixEInvoiceString;
begin
  Result := ChargeCodes[Value];
end;

function LandrixEInvoiceSpecialServiceDescriptionCodeFromStr(const Code: TLandrixEInvoiceString;
  out Value: TLandrixInvoiceSpecialServiceDescriptionCode): Boolean;
var
  V: TLandrixInvoiceSpecialServiceDescriptionCode;
begin
  for V := Succ(Low(V)) to High(V) do
    if SameCode(ChargeCodes[V], Code) then
    begin
      Value := V;
      Result := True;
      Exit;
    end;
  Value := Low(V);
  Result := False;
end;

function LandrixEInvoiceDutyTaxFeeCategoryCodeToStr(Value: TLandrixInvoiceDutyTaxFeeCategoryCode): TLandrixEInvoiceString;
begin
  Result := TaxCategoryCodes[Value];
end;

function LandrixEInvoiceDutyTaxFeeCategoryCodeFromStr(const Code: TLandrixEInvoiceString;
  out Value: TLandrixInvoiceDutyTaxFeeCategoryCode): Boolean;
var
  V: TLandrixInvoiceDutyTaxFeeCategoryCode;
begin
  for V := Succ(Low(V)) to High(V) do
    if SameCode(TaxCategoryCodes[V], Code) then
    begin
      Value := V;
      Result := True;
      Exit;
    end;
  Value := Low(V);
  Result := False;
end;

function LandrixEInvoiceNoteSubjectCodeToStr(Value: TLandrixInvoiceNoteSubjectCode): TLandrixEInvoiceString;
begin
  Result := NoteSubjectCodes[Value];
end;

function LandrixEInvoiceNoteSubjectCodeFromStr(const Code: TLandrixEInvoiceString;
  out Value: TLandrixInvoiceNoteSubjectCode): Boolean;
var
  V: TLandrixInvoiceNoteSubjectCode;
begin
  for V := Succ(Low(V)) to High(V) do
    if SameCode(NoteSubjectCodes[V], Code) then
    begin
      Value := V;
      Result := True;
      Exit;
    end;
  Value := Low(V);
  Result := False;
end;

end.
