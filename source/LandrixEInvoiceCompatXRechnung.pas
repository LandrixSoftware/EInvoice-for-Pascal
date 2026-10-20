{
  EInvoice-for-Pascal

  Copyright (C) 2026 Landrix Software GmbH & Co. KG

  This file is dual-licensed under:
  - GNU GPL version 3 or later; or
  - the Landrix Software Commercial License.

  See LICENSE and COMMERCIAL-LICENSE.md.

  SPDX-License-Identifier: GPL-3.0-or-later OR LicenseRef-Landrix-Commercial
}

{ Compatibility with XRechnung-for-Delphi (unit intf.Invoice, intfInvoice in
  its Delphi 6 version): the names of the invoice model as they were there.
  Existing code compiles after replacing intf.Invoice (or intfInvoice) by
  LandrixEInvoiceCompatXRechnung in its uses clauses.

  - Every model class and enumeration has its old name as an alias
    (TInvoice = TLandrixInvoice, ...).
  - Enumeration members are declared again as constants, because an alias
    does not make the members of the original type visible. Qualified
    references such as TInvoiceTypeCode.itc_CommercialInvoice keep working
    on Delphi 2009 and later and on FPC.
  - TInvoiceEmptyLeitwegID.NON_EXISTENT, TInvoiceUnitCodeHelper and
    TInvoiceAttachmentTypeHelper are small classes that forward to the new
    functions.
  - Differences in behaviour are listed in CHANGELOG.md (e.g. text fields
    are TLandrixEInvoiceString, date fields TDateTime).
  - The facade TXRechnungInvoiceAdapter (reading and writing) is in
    LandrixEInvoiceCompatXRechnungAdapter, which replaces intf.XRechnung.
  New code should use the TLandrix... names.

  DE: Kompatibilitaet mit XRechnung-for-Delphi (Unit intf.Invoice, in der
  Delphi-6-Fassung intfInvoice): die dortigen Namen des Rechnungsmodells.
  Bestehender Code kompiliert, wenn in seinen uses-Klauseln intf.Invoice
  (oder intfInvoice) durch LandrixEInvoiceCompatXRechnung ersetzt wird.

  - Jede Modellklasse und Aufzaehlung hat ihren alten Namen als Alias
    (TInvoice = TLandrixInvoice, ...).
  - Aufzaehlungswerte sind erneut als Konstanten deklariert, weil ein Alias
    die Werte des Originaltyps nicht sichtbar macht. Qualifizierte Bezuege
    wie TInvoiceTypeCode.itc_CommercialInvoice funktionieren weiterhin ab
    Delphi 2009 und unter FPC.
  - TInvoiceEmptyLeitwegID.NON_EXISTENT, TInvoiceUnitCodeHelper und
    TInvoiceAttachmentTypeHelper sind kleine Klassen, die an die neuen
    Funktionen weiterreichen.
  - Verhaltensunterschiede stehen in CHANGELOG.md (z. B. Textfelder sind
    TLandrixEInvoiceString, Datumsfelder TDateTime).
  - Die Fassade TXRechnungInvoiceAdapter (Lesen und Schreiben) liegt in
    LandrixEInvoiceCompatXRechnungAdapter, die intf.XRechnung ersetzt.
  Neuer Code sollte die TLandrix...-Namen verwenden. }

unit LandrixEInvoiceCompatXRechnung;

{$I LandrixEInvoice.inc}

interface

uses
  LandrixEInvoiceTypes,
  LandrixEInvoiceCodes,
  LandrixEInvoiceInvoice;

type
  { Old names of the model classes. DE: Alte Namen der Modellklassen. }
  TInvoiceAttachment = TLandrixInvoiceAttachment;
  TInvoiceAttachmentList = TLandrixInvoiceAttachmentList;
  TInvoicePrepaidPayment = TLandrixInvoicePrepaidPayment;
  TInvoicePrepaidPaymentList = TLandrixInvoicePrepaidPaymentList;
  TInvoiceAllowanceCharge = TLandrixInvoiceAllowanceCharge;
  TInvoiceAllowanceCharges = TLandrixInvoiceAllowanceCharges;
  TInvoiceLineItemAttribute = TLandrixInvoiceLineItemAttribute;
  TInvoiceLineItemAttributes = TLandrixInvoiceLineItemAttributes;
  TInvoiceLineItemClassification = TLandrixInvoiceLineItemClassification;
  TInvoiceLineItemClassifications = TLandrixInvoiceLineItemClassifications;
  TInvoiceLine = TLandrixInvoiceLine;
  TInvoiceLines = TLandrixInvoiceLines;
  TInvoiceTaxAmount = TLandrixInvoiceTaxAmount;
  TInvoiceTaxAmounts = TLandrixInvoiceTaxAmounts;
  TInvoiceAddress = TLandrixInvoiceAddress;
  TInvoiceAccountingParty = TLandrixInvoiceAccountingParty;
  TInvoiceDeliveryInformation = TLandrixInvoiceDeliveryInformation;
  TInvoicePrecedingInvoiceReference = TLandrixInvoicePrecedingInvoiceReference;
  TInvoicePrecedingInvoiceReferences = TLandrixInvoicePrecedingInvoiceReferences;
  TInvoiceNote = TLandrixInvoiceNote;
  TInvoiceNotes = TLandrixInvoiceNotes;
  TInvoicePaymentType = TLandrixInvoicePaymentType;
  TInvoicePaymentTypeList = TLandrixInvoicePaymentTypeList;
  TInvoice = TLandrixInvoice;

  { Old names of the enumerations. DE: Alte Namen der Aufzaehlungen. }
  TInvoiceTypeCode = TLandrixInvoiceTypeCode;
  TInvoicePaymentMeansCode = TLandrixInvoicePaymentMeansCode;
  TInvoiceUnitCode = TLandrixInvoiceUnitCode;
  TInvoiceAttachmentType = TLandrixInvoiceAttachmentType;
  TInvoiceAttachmentTypeCode = TLandrixInvoiceAttachmentTypeCode;
  TInvoiceAllowanceOrChargeIdentCode = TLandrixInvoiceAllowanceOrChargeIdentCode;
  TInvoiceSpecialServiceDescriptionCode = TLandrixInvoiceSpecialServiceDescriptionCode;
  TInvoiceDutyTaxFeeCategoryCode = TLandrixInvoiceDutyTaxFeeCategoryCode;
  TInvoiceNoteSubjectCode = TLandrixInvoiceNoteSubjectCode;
  TInvoicePaymentTermsType = TLandrixInvoicePaymentTermsType;
  TInvoiceLineStatusReasonCode = TLandrixInvoiceLineStatusReasonCode;

  { Index type of the lists (was NativeInt from Delphi 12 on and on FPC).
    DE: Indextyp der Listen (war ab Delphi 12 und unter FPC NativeInt). }
  TInvoiceListItemType = TLandrixEInvoiceListIndex;

  { TInvoiceEmptyLeitwegID.NON_EXISTENT: value for BT-10 when the buyer has
    no Leitweg-ID. DE: Wert fuer BT-10, wenn der Kaeufer keine Leitweg-ID
    hat. }
  TInvoiceEmptyLeitwegID = class(TObject)
  public
    class function NON_EXISTENT: TLandrixEInvoiceString;
  end;

  { Forwards to LandrixEInvoiceUnitCodeFromUnitOfMeasure.
    DE: Reicht an LandrixEInvoiceUnitCodeFromUnitOfMeasure weiter. }
  TInvoiceUnitCodeHelper = class(TObject)
  public
    class function MapUnitOfMeasure(const _UnitOfMeasure: TLandrixEInvoiceString;
      out _Success: Boolean;
      _DefaultOnFailure: TLandrixInvoiceUnitCode = iuc_piece): TLandrixInvoiceUnitCode;
  end;

  { Forwards to LandrixEInvoiceAttachmentTypeFromFilename.
    DE: Reicht an LandrixEInvoiceAttachmentTypeFromFilename weiter. }
  TInvoiceAttachmentTypeHelper = class(TObject)
  public
    class function GetTypeFromFilename(const _Filename: string): TLandrixInvoiceAttachmentType;
  end;

const
  { Name of NON_EXISTENT in the Delphi 6 version of XRechnung-for-Delphi.
    DE: Name von NON_EXISTENT in der Delphi-6-Fassung von
    XRechnung-for-Delphi. }
  TInvoiceEmptyLeitwegID_NON_EXISTENT = LandrixEInvoiceLeitwegIDNonExistent;

  { Members of TInvoiceTypeCode. DE: Werte von TInvoiceTypeCode. }
  itc_None = LandrixEInvoiceCodes.itc_None;
  itc_DebitnoteRelatedToFinancialAdjustments = LandrixEInvoiceCodes.itc_DebitnoteRelatedToFinancialAdjustments;
  itc_SelfBilledCreditNote = LandrixEInvoiceCodes.itc_SelfBilledCreditNote;
  itc_PartialInvoice = LandrixEInvoiceCodes.itc_PartialInvoice;
  itc_CommercialInvoice = LandrixEInvoiceCodes.itc_CommercialInvoice;
  itc_DebitNote = LandrixEInvoiceCodes.itc_DebitNote;
  itc_CorrectedInvoice = LandrixEInvoiceCodes.itc_CorrectedInvoice;
  itc_PrepaymentInvoice = LandrixEInvoiceCodes.itc_PrepaymentInvoice;
  itc_Cancellation = LandrixEInvoiceCodes.itc_Cancellation;
  itc_SelfbilledInvoice = LandrixEInvoiceCodes.itc_SelfbilledInvoice;
  itc_CreditNote = LandrixEInvoiceCodes.itc_CreditNote;
  itc_PartialConstructionInvoice = LandrixEInvoiceCodes.itc_PartialConstructionInvoice;
  itc_PartialFinalConstructionInvoice = LandrixEInvoiceCodes.itc_PartialFinalConstructionInvoice;
  itc_FinalConstructionInvoice = LandrixEInvoiceCodes.itc_FinalConstructionInvoice;
  { Members of TInvoicePaymentMeansCode. DE: Werte von TInvoicePaymentMeansCode. }
  ipmc_NotImplemented = LandrixEInvoiceCodes.ipmc_NotImplemented;
  ipmc_InstrumentNotDefined = LandrixEInvoiceCodes.ipmc_InstrumentNotDefined;
  ipmc_AutomatedClearingHouseCredit = LandrixEInvoiceCodes.ipmc_AutomatedClearingHouseCredit;
  ipmc_AutomatedClearingHouseDebit = LandrixEInvoiceCodes.ipmc_AutomatedClearingHouseDebit;
  ipmc_ACH_DemandDebitReversal = LandrixEInvoiceCodes.ipmc_ACH_DemandDebitReversal;
  ipmc_ACH_DemandCreditReversal = LandrixEInvoiceCodes.ipmc_ACH_DemandCreditReversal;
  ipmc_ACH_Demand_Credit = LandrixEInvoiceCodes.ipmc_ACH_Demand_Credit;
  ipmc_ACH_Demand_Debit = LandrixEInvoiceCodes.ipmc_ACH_Demand_Debit;
  ipmc_Hold = LandrixEInvoiceCodes.ipmc_Hold;
  ipmc_NationalOrRegionalClearing = LandrixEInvoiceCodes.ipmc_NationalOrRegionalClearing;
  ipmc_InCash = LandrixEInvoiceCodes.ipmc_InCash;
  ipmc_ACH_SavingsCreditReversal = LandrixEInvoiceCodes.ipmc_ACH_SavingsCreditReversal;
  ipmc_ACH_SavingsDebitReversal = LandrixEInvoiceCodes.ipmc_ACH_SavingsDebitReversal;
  ipmc_ACH_SavingsCredit = LandrixEInvoiceCodes.ipmc_ACH_SavingsCredit;
  ipmc_ACH_SavingsDebit = LandrixEInvoiceCodes.ipmc_ACH_SavingsDebit;
  ipmc_BookEntryCredit = LandrixEInvoiceCodes.ipmc_BookEntryCredit;
  ipmc_BookEntryDebit = LandrixEInvoiceCodes.ipmc_BookEntryDebit;
  ipmc_ACH_DemandCashConcentrationDisbursementCredit = LandrixEInvoiceCodes.ipmc_ACH_DemandCashConcentrationDisbursementCredit;
  ipmc_ACH_DemandCashConcentrationDisbursementDebit = LandrixEInvoiceCodes.ipmc_ACH_DemandCashConcentrationDisbursementDebit;
  ipmc_ACH_DemandCorporateTradePaymentCredit = LandrixEInvoiceCodes.ipmc_ACH_DemandCorporateTradePaymentCredit;
  ipmc_Cheque = LandrixEInvoiceCodes.ipmc_Cheque;
  ipmc_BankersDraft = LandrixEInvoiceCodes.ipmc_BankersDraft;
  ipmc_CertifiedBankerDraft = LandrixEInvoiceCodes.ipmc_CertifiedBankerDraft;
  ipmc_BankChequeIssuedByEstablishment = LandrixEInvoiceCodes.ipmc_BankChequeIssuedByEstablishment;
  ipmc_BillOfExchangeAwaitingAcceptance = LandrixEInvoiceCodes.ipmc_BillOfExchangeAwaitingAcceptance;
  ipmc_CertifiedCheque = LandrixEInvoiceCodes.ipmc_CertifiedCheque;
  ipmc_LocalCheque = LandrixEInvoiceCodes.ipmc_LocalCheque;
  ipmc_ACH_DemandCorporateTradePaymentDebit = LandrixEInvoiceCodes.ipmc_ACH_DemandCorporateTradePaymentDebit;
  ipmc_ACH_DemandCorporateTradeExchangeCredit = LandrixEInvoiceCodes.ipmc_ACH_DemandCorporateTradeExchangeCredit;
  ipmc_ACH_DemandCorporateTradeExchangeDebit = LandrixEInvoiceCodes.ipmc_ACH_DemandCorporateTradeExchangeDebit;
  ipmc_CreditTransfer = LandrixEInvoiceCodes.ipmc_CreditTransfer;
  ipmc_DebitTransfer = LandrixEInvoiceCodes.ipmc_DebitTransfer;
  ipmc_ACH_DemandCashConcentrationDisbursementPlusCredit = LandrixEInvoiceCodes.ipmc_ACH_DemandCashConcentrationDisbursementPlusCredit;
  ipmc_ACH_DemandCashConcentrationDisbursementPlusDebit = LandrixEInvoiceCodes.ipmc_ACH_DemandCashConcentrationDisbursementPlusDebit;
  ipmc_ACH_PrearrangedPaymentAndDeposit = LandrixEInvoiceCodes.ipmc_ACH_PrearrangedPaymentAndDeposit;
  ipmc_ACH_SavingsCashConcentrationDisbursementCredit = LandrixEInvoiceCodes.ipmc_ACH_SavingsCashConcentrationDisbursementCredit;
  ipmc_ACH_SavingsCashConcentrationDisbursementDebit = LandrixEInvoiceCodes.ipmc_ACH_SavingsCashConcentrationDisbursementDebit;
  ipmc_ACH_SavingsCorporateTradePaymentCredit = LandrixEInvoiceCodes.ipmc_ACH_SavingsCorporateTradePaymentCredit;
  ipmc_ACH_SavingsCorporateTradePaymentDebit = LandrixEInvoiceCodes.ipmc_ACH_SavingsCorporateTradePaymentDebit;
  ipmc_ACH_SavingsCorporateTradeExchangeCredit = LandrixEInvoiceCodes.ipmc_ACH_SavingsCorporateTradeExchangeCredit;
  ipmc_ACH_SavingsCorporateTradeExchangeDebit = LandrixEInvoiceCodes.ipmc_ACH_SavingsCorporateTradeExchangeDebit;
  ipmc_ACH_SavingsCashConcentrationDisbursementPlusCredit = LandrixEInvoiceCodes.ipmc_ACH_SavingsCashConcentrationDisbursementPlusCredit;
  ipmc_PaymentToBankAccount = LandrixEInvoiceCodes.ipmc_PaymentToBankAccount;
  ipmc_ACH_SavingsCashConcentrationDisbursementPlusDebit = LandrixEInvoiceCodes.ipmc_ACH_SavingsCashConcentrationDisbursementPlusDebit;
  ipmc_AcceptedBillOfExchange = LandrixEInvoiceCodes.ipmc_AcceptedBillOfExchange;
  ipmc_ReferencedHomeBankingCreditTransfer = LandrixEInvoiceCodes.ipmc_ReferencedHomeBankingCreditTransfer;
  ipmc_InterbankDebitTransfer = LandrixEInvoiceCodes.ipmc_InterbankDebitTransfer;
  ipmc_HomeBankingDebitTransfer = LandrixEInvoiceCodes.ipmc_HomeBankingDebitTransfer;
  ipmc_BankCard = LandrixEInvoiceCodes.ipmc_BankCard;
  ipmc_DirectDebit = LandrixEInvoiceCodes.ipmc_DirectDebit;
  ipmc_PaymentByPostgiro = LandrixEInvoiceCodes.ipmc_PaymentByPostgiro;
  ipmc_FR_Norme_6_97 = LandrixEInvoiceCodes.ipmc_FR_Norme_6_97;
  ipmc_UrgentCommercialPayment = LandrixEInvoiceCodes.ipmc_UrgentCommercialPayment;
  ipmc_UrgentTreasuryPayment = LandrixEInvoiceCodes.ipmc_UrgentTreasuryPayment;
  ipmc_CreditCard = LandrixEInvoiceCodes.ipmc_CreditCard;
  ipmc_DebitCard = LandrixEInvoiceCodes.ipmc_DebitCard;
  ipmc_Bankgiro = LandrixEInvoiceCodes.ipmc_Bankgiro;
  ipmc_StandingAgreement = LandrixEInvoiceCodes.ipmc_StandingAgreement;
  ipmc_SEPACreditTransfer = LandrixEInvoiceCodes.ipmc_SEPACreditTransfer;
  ipmc_SEPADirectDebit = LandrixEInvoiceCodes.ipmc_SEPADirectDebit;
  ipmc_PromissoryNote = LandrixEInvoiceCodes.ipmc_PromissoryNote;
  ipmc_PromissoryNoteSignedByDebtor = LandrixEInvoiceCodes.ipmc_PromissoryNoteSignedByDebtor;
  ipmc_PromissoryNoteSignedByDebtorEndorsedByBank = LandrixEInvoiceCodes.ipmc_PromissoryNoteSignedByDebtorEndorsedByBank;
  ipmc_PromissoryNoteSignedByDebtorEndorsedByThirdParty = LandrixEInvoiceCodes.ipmc_PromissoryNoteSignedByDebtorEndorsedByThirdParty;
  ipmc_PromissoryNoteSignedByBank = LandrixEInvoiceCodes.ipmc_PromissoryNoteSignedByBank;
  ipmc_PromissoryNoteSignedByBankEndorsedByAnotherBank = LandrixEInvoiceCodes.ipmc_PromissoryNoteSignedByBankEndorsedByAnotherBank;
  ipmc_PromissoryNoteSignedByThirdParty = LandrixEInvoiceCodes.ipmc_PromissoryNoteSignedByThirdParty;
  ipmc_PromissoryNoteSignedByThirdPartyEndorsedByBank = LandrixEInvoiceCodes.ipmc_PromissoryNoteSignedByThirdPartyEndorsedByBank;
  ipmc_OnlinePaymentService = LandrixEInvoiceCodes.ipmc_OnlinePaymentService;
  ipmc_TransferAdvice = LandrixEInvoiceCodes.ipmc_TransferAdvice;
  ipmc_BillDrawnByCrdtOnDebtor = LandrixEInvoiceCodes.ipmc_BillDrawnByCrdtOnDebtor;
  ipmc_BillDrawnByCrdtOnBank = LandrixEInvoiceCodes.ipmc_BillDrawnByCrdtOnBank;
  ipmc_BillDrawnByCrdtEndorsedByAnotherBank = LandrixEInvoiceCodes.ipmc_BillDrawnByCrdtEndorsedByAnotherBank;
  ipmc_BillDrawnByCrdtOnBankEndorsedByThirdParty = LandrixEInvoiceCodes.ipmc_BillDrawnByCrdtOnBankEndorsedByThirdParty;
  ipmc_BillDrawnByCrdtOnThirdParty = LandrixEInvoiceCodes.ipmc_BillDrawnByCrdtOnThirdParty;
  ipmc_BillDrawnByCrdtOnThirdPartyAcceptedAndEndorsedByBank = LandrixEInvoiceCodes.ipmc_BillDrawnByCrdtOnThirdPartyAcceptedAndEndorsedByBank;
  ipmc_NotTransferableBankersDraft = LandrixEInvoiceCodes.ipmc_NotTransferableBankersDraft;
  ipmc_NotTransferableLocalCheque = LandrixEInvoiceCodes.ipmc_NotTransferableLocalCheque;
  ipmc_ReferenceGiro = LandrixEInvoiceCodes.ipmc_ReferenceGiro;
  ipmc_UrgentGiro = LandrixEInvoiceCodes.ipmc_UrgentGiro;
  ipmc_FreeFormatGiro = LandrixEInvoiceCodes.ipmc_FreeFormatGiro;
  ipmc_RequestedMethodForPaymentWasNotUsed = LandrixEInvoiceCodes.ipmc_RequestedMethodForPaymentWasNotUsed;
  ipmc_ClearingBetweenPartners = LandrixEInvoiceCodes.ipmc_ClearingBetweenPartners;
  ipmc_MutuallyDefined = LandrixEInvoiceCodes.ipmc_MutuallyDefined;
  { Members of TInvoiceUnitCode. DE: Werte von TInvoiceUnitCode. }
  iuc_None = LandrixEInvoiceCodes.iuc_None;
  iuc_one = LandrixEInvoiceCodes.iuc_one;
  iuc_piece = LandrixEInvoiceCodes.iuc_piece;
  iuc_flaterate = LandrixEInvoiceCodes.iuc_flaterate;
  iuc_number_of_articles = LandrixEInvoiceCodes.iuc_number_of_articles;
  iuc_set = LandrixEInvoiceCodes.iuc_set;
  iuc_week = LandrixEInvoiceCodes.iuc_week;
  iuc_month = LandrixEInvoiceCodes.iuc_month;
  iuc_day = LandrixEInvoiceCodes.iuc_day;
  iuc_tonne_metric_ton = LandrixEInvoiceCodes.iuc_tonne_metric_ton;
  iuc_square_metre = LandrixEInvoiceCodes.iuc_square_metre;
  iuc_cubic_metre = LandrixEInvoiceCodes.iuc_cubic_metre;
  iuc_metre = LandrixEInvoiceCodes.iuc_metre;
  iuc_square_millimetre = LandrixEInvoiceCodes.iuc_square_millimetre;
  iuc_cubic_millimetre = LandrixEInvoiceCodes.iuc_cubic_millimetre;
  iuc_millimetre = LandrixEInvoiceCodes.iuc_millimetre;
  iuc_minute_unit_of_time = LandrixEInvoiceCodes.iuc_minute_unit_of_time;
  iuc_second_unit_of_time = LandrixEInvoiceCodes.iuc_second_unit_of_time;
  iuc_millilitre = LandrixEInvoiceCodes.iuc_millilitre;
  iuc_litre = LandrixEInvoiceCodes.iuc_litre;
  iuc_hour = LandrixEInvoiceCodes.iuc_hour;
  iuc_milligram = LandrixEInvoiceCodes.iuc_milligram;
  iuc_gram = LandrixEInvoiceCodes.iuc_gram;
  iuc_kilogram = LandrixEInvoiceCodes.iuc_kilogram;
  iuc_kilometre = LandrixEInvoiceCodes.iuc_kilometre;
  iuc_kilowatt_hour = LandrixEInvoiceCodes.iuc_kilowatt_hour;
  iuc_percent = LandrixEInvoiceCodes.iuc_percent;
  iuc_packaging = LandrixEInvoiceCodes.iuc_packaging;
  iuc_year = LandrixEInvoiceCodes.iuc_year;
  iuc_person = LandrixEInvoiceCodes.iuc_person;
  iuc_square_decimetre = LandrixEInvoiceCodes.iuc_square_decimetre;
  iuc_cubic_decimetre = LandrixEInvoiceCodes.iuc_cubic_decimetre;
  iuc_decimetre = LandrixEInvoiceCodes.iuc_decimetre;
  iuc_centimetre = LandrixEInvoiceCodes.iuc_centimetre;
  iuc_square_centimetre = LandrixEInvoiceCodes.iuc_square_centimetre;
  iuc_cubic_centimetre = LandrixEInvoiceCodes.iuc_cubic_centimetre;
  iuc_pair = LandrixEInvoiceCodes.iuc_pair;
  iuc_bag = LandrixEInvoiceCodes.iuc_bag;
  iuc_roll = LandrixEInvoiceCodes.iuc_roll;
  iuc_foot = LandrixEInvoiceCodes.iuc_foot;
  iuc_inch = LandrixEInvoiceCodes.iuc_inch;
  iuc_hectare = LandrixEInvoiceCodes.iuc_hectare;
  iuc_sack = LandrixEInvoiceCodes.iuc_sack;
  { Members of TInvoiceAttachmentType. DE: Werte von TInvoiceAttachmentType. }
  iat_application_None = LandrixEInvoiceCodes.iat_application_None;
  iat_application_pdf = LandrixEInvoiceCodes.iat_application_pdf;
  iat_image_png = LandrixEInvoiceCodes.iat_image_png;
  iat_image_jpeg = LandrixEInvoiceCodes.iat_image_jpeg;
  iat_text_csv = LandrixEInvoiceCodes.iat_text_csv;
  iat_application_vnd_openxmlformats_officedocument_spreadsheetml_sheet = LandrixEInvoiceCodes.iat_application_vnd_openxmlformats_officedocument_spreadsheetml_sheet;
  iat_application_vnd_oasis_opendocument_spreadsheet = LandrixEInvoiceCodes.iat_application_vnd_oasis_opendocument_spreadsheet;
  iat_application_xml = LandrixEInvoiceCodes.iat_application_xml;
  { Members of TInvoiceAttachmentTypeCode. DE: Werte von TInvoiceAttachmentTypeCode. }
  iatc_None = LandrixEInvoiceCodes.iatc_None;
  iatc_50 = LandrixEInvoiceCodes.iatc_50;
  iatc_130 = LandrixEInvoiceCodes.iatc_130;
  iatc_916 = LandrixEInvoiceCodes.iatc_916;
  { Members of TInvoiceAllowanceOrChargeIdentCode. DE: Werte von TInvoiceAllowanceOrChargeIdentCode. }
  iacic_None = LandrixEInvoiceCodes.iacic_None;
  iacic_BonusForWorksAheadOfSchedule = LandrixEInvoiceCodes.iacic_BonusForWorksAheadOfSchedule;
  iacic_OtherBonus = LandrixEInvoiceCodes.iacic_OtherBonus;
  iacic_ManufacturersConsumerDiscount = LandrixEInvoiceCodes.iacic_ManufacturersConsumerDiscount;
  iacic_DueToMilitaryStatus = LandrixEInvoiceCodes.iacic_DueToMilitaryStatus;
  iacic_DueToWorkAccident = LandrixEInvoiceCodes.iacic_DueToWorkAccident;
  iacic_SpecialAgreement = LandrixEInvoiceCodes.iacic_SpecialAgreement;
  iacic_ProductionErrorDiscount = LandrixEInvoiceCodes.iacic_ProductionErrorDiscount;
  iacic_NewOutletDiscount = LandrixEInvoiceCodes.iacic_NewOutletDiscount;
  iacic_SampleDiscount = LandrixEInvoiceCodes.iacic_SampleDiscount;
  iacic_EndOfRangeDiscount = LandrixEInvoiceCodes.iacic_EndOfRangeDiscount;
  iacic_IncotermDiscount = LandrixEInvoiceCodes.iacic_IncotermDiscount;
  iacic_PointOfSalesThresholdAllowance = LandrixEInvoiceCodes.iacic_PointOfSalesThresholdAllowance;
  iacic_MaterialSurchargeDeduction = LandrixEInvoiceCodes.iacic_MaterialSurchargeDeduction;
  iacic_Discount = LandrixEInvoiceCodes.iacic_Discount;
  iacic_SpecialRebate = LandrixEInvoiceCodes.iacic_SpecialRebate;
  iacic_FixedLongTerm = LandrixEInvoiceCodes.iacic_FixedLongTerm;
  iacic_Temporary = LandrixEInvoiceCodes.iacic_Temporary;
  iacic_Standard = LandrixEInvoiceCodes.iacic_Standard;
  iacic_YearlyTurnover = LandrixEInvoiceCodes.iacic_YearlyTurnover;
  { Members of TInvoiceSpecialServiceDescriptionCode. DE: Werte von TInvoiceSpecialServiceDescriptionCode. }
  issdc_None = LandrixEInvoiceCodes.issdc_None;
  issdc_AA_Advertising = LandrixEInvoiceCodes.issdc_AA_Advertising;
  issdc_AAA_Telecommunication = LandrixEInvoiceCodes.issdc_AAA_Telecommunication;
  issdc_ABK_Miscellaneous = LandrixEInvoiceCodes.issdc_ABK_Miscellaneous;
  issdc_ABL_AdditionalPackaging = LandrixEInvoiceCodes.issdc_ABL_AdditionalPackaging;
  issdc_ADR_OtherServices = LandrixEInvoiceCodes.issdc_ADR_OtherServices;
  issdc_ADT_Pickup = LandrixEInvoiceCodes.issdc_ADT_Pickup;
  issdc_FC_FreightService = LandrixEInvoiceCodes.issdc_FC_FreightService;
  issdc_FI_Financing = LandrixEInvoiceCodes.issdc_FI_Financing;
  issdc_LA_Labelling = LandrixEInvoiceCodes.issdc_LA_Labelling;
  issdc_PC_Packing = LandrixEInvoiceCodes.issdc_PC_Packing;
  { Members of TInvoiceDutyTaxFeeCategoryCode. DE: Werte von TInvoiceDutyTaxFeeCategoryCode. }
  idtfcc_None = LandrixEInvoiceCodes.idtfcc_None;
  idtfcc_AE_VATReverseCharge = LandrixEInvoiceCodes.idtfcc_AE_VATReverseCharge;
  idtfcc_E_ExemptFromTax = LandrixEInvoiceCodes.idtfcc_E_ExemptFromTax;
  idtfcc_G_FreeExportItemTaxNotCharged = LandrixEInvoiceCodes.idtfcc_G_FreeExportItemTaxNotCharged;
  idtfcc_K_VATExemptForEEAIntracommunitySupplyOfGoodsAndServices = LandrixEInvoiceCodes.idtfcc_K_VATExemptForEEAIntracommunitySupplyOfGoodsAndServices;
  idtfcc_L_CanaryIslandsGeneralIndirectTax = LandrixEInvoiceCodes.idtfcc_L_CanaryIslandsGeneralIndirectTax;
  idtfcc_M_TaxForProductionServicesAndImportationInCeutaAndMelilla = LandrixEInvoiceCodes.idtfcc_M_TaxForProductionServicesAndImportationInCeutaAndMelilla;
  idtfcc_O_ServicesOutsideScopeOfTax = LandrixEInvoiceCodes.idtfcc_O_ServicesOutsideScopeOfTax;
  idtfcc_S_StandardRate = LandrixEInvoiceCodes.idtfcc_S_StandardRate;
  idtfcc_Z_ZeroRatedGoods = LandrixEInvoiceCodes.idtfcc_Z_ZeroRatedGoods;
  { Members of TInvoiceNoteSubjectCode. DE: Werte von TInvoiceNoteSubjectCode. }
  insc_None = LandrixEInvoiceCodes.insc_None;
  insc_AAI = LandrixEInvoiceCodes.insc_AAI;
  insc_AAJ = LandrixEInvoiceCodes.insc_AAJ;
  insc_AAK = LandrixEInvoiceCodes.insc_AAK;
  insc_SUR = LandrixEInvoiceCodes.insc_SUR;
  insc_REG = LandrixEInvoiceCodes.insc_REG;
  insc_ABL = LandrixEInvoiceCodes.insc_ABL;
  insc_TXD = LandrixEInvoiceCodes.insc_TXD;
  insc_CUS = LandrixEInvoiceCodes.insc_CUS;
  insc_PMT = LandrixEInvoiceCodes.insc_PMT;
  insc_BLP = LandrixEInvoiceCodes.insc_BLP;
  { Members of TInvoicePaymentTermsType. DE: Werte von TInvoicePaymentTermsType. }
  iptt_None = LandrixEInvoiceInvoice.iptt_None;
  iptt_Net = LandrixEInvoiceInvoice.iptt_Net;
  iptt_CashDiscount1 = LandrixEInvoiceInvoice.iptt_CashDiscount1;
  iptt_CashDiscount2 = LandrixEInvoiceInvoice.iptt_CashDiscount2;
  iptt_CashDiscount3 = LandrixEInvoiceInvoice.iptt_CashDiscount3;
  { Members of TInvoiceLineStatusReasonCode. DE: Werte von TInvoiceLineStatusReasonCode. }
  ilsrc_None = LandrixEInvoiceInvoice.ilsrc_None;
  ilsrc_Detail = LandrixEInvoiceInvoice.ilsrc_Detail;
  ilsrc_Group = LandrixEInvoiceInvoice.ilsrc_Group;
  ilsrc_Information = LandrixEInvoiceInvoice.ilsrc_Information;

implementation

class function TInvoiceEmptyLeitwegID.NON_EXISTENT: TLandrixEInvoiceString;
begin
  Result := LandrixEInvoiceLeitwegIDNonExistent;
end;

class function TInvoiceUnitCodeHelper.MapUnitOfMeasure(const _UnitOfMeasure: TLandrixEInvoiceString;
  out _Success: Boolean;
  _DefaultOnFailure: TLandrixInvoiceUnitCode): TLandrixInvoiceUnitCode;
begin
  Result := LandrixEInvoiceUnitCodeFromUnitOfMeasure(_UnitOfMeasure, _Success, _DefaultOnFailure);
end;

class function TInvoiceAttachmentTypeHelper.GetTypeFromFilename(const _Filename: string): TLandrixInvoiceAttachmentType;
begin
  Result := LandrixEInvoiceAttachmentTypeFromFilename(_Filename);
end;

end.
