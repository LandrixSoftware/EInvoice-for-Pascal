{
  EInvoice-for-Pascal

  Copyright (C) 2026 Landrix Software GmbH & Co. KG

  This file is dual-licensed under:
  - GNU GPL version 3 or later; or
  - the Landrix Software Commercial License.

  See LICENSE and COMMERCIAL-LICENSE.md.

  SPDX-License-Identifier: GPL-3.0-or-later OR LicenseRef-Landrix-Commercial
}

{ Tests for LandrixEInvoiceCheck: rule diagnostics, applicability, the
  empty specification entry, the legacy rules LX-CC-01 to LX-CC-12 (their
  conditions per old version are tested through
  TXRechnungInvoiceAdapter.ConsistencyCheck in
  LandrixEInvoiceTestCompatAdapter) and the official rules: a complete
  invoice passes every target, each rule case breaks one business term
  (blank text where the term is text) and the rule must fire for its target
  and hold for a target it does not apply to. }

unit LandrixEInvoiceTestCheck;

{$I LandrixEInvoice.inc}

interface

uses
  LandrixEInvoiceInvoice;

{ An invoice that meets every official rule of every target. }
procedure FillComplete(Invoice: TLandrixInvoice);

procedure Register;

implementation

uses
  SysUtils,
  LandrixEInvoiceTypes,
  LandrixEInvoiceDiagnostics,
  LandrixEInvoiceCodes,
  LandrixEInvoiceSpecs,
  LandrixEInvoiceCalc,
  LandrixEInvoiceCII,
  LandrixEInvoiceMapCII,
  LandrixEInvoiceUBL,
  LandrixEInvoiceMapUBL,
  LandrixEInvoiceCheck,
  LandrixEInvoiceTestFramework;

function SpecFor(const ATarget: TLandrixEInvoiceTarget): TLandrixEInvoiceSpec;
begin
  Check(LandrixEInvoiceFindSpec(ATarget, Result), 'spec ' + string(LandrixEInvoiceTargetToStr(ATarget)));
end;

{ A currency value from cents, without a float literal. }
function CentsValue(ACents: Int64): Currency;
begin
  PInt64(@Result)^ := ACents * 100;
end;

type
  TTargetKind = (tk_None, tk_XRUBL, tk_XRCII, tk_Peppol, tk_FXMinimum, tk_FXBasicWL, tk_FXBasic,
    tk_FXEN16931, tk_FXExtended);

function SpecOf(AKind: TTargetKind): TLandrixEInvoiceSpec;
begin
  case AKind of
    tk_XRUBL:
      Result := SpecFor(TLandrixEInvoiceTargets.XRechnung('3.0', esy_UBL));
    tk_XRCII:
      Result := SpecFor(TLandrixEInvoiceTargets.XRechnung('3.0', esy_CII));
    tk_Peppol:
      Result := SpecFor(TLandrixEInvoiceTargets.PeppolBIS('3.0'));
    tk_FXMinimum:
      Result := SpecFor(TLandrixEInvoiceTargets.FacturX('1.09', epr_Minimum));
    tk_FXBasicWL:
      Result := SpecFor(TLandrixEInvoiceTargets.FacturX('1.09', epr_BasicWL));
    tk_FXBasic:
      Result := SpecFor(TLandrixEInvoiceTargets.FacturX('1.09', epr_Basic));
    tk_FXEN16931:
      Result := SpecFor(TLandrixEInvoiceTargets.FacturX('1.09', epr_EN16931));
  else
    Result := SpecFor(TLandrixEInvoiceTargets.FacturX('1.09', epr_Extended));
  end;
end;

{ An invoice that meets every official rule of every target. }
procedure FillComplete(Invoice: TLandrixInvoice);
var
  Line: TLandrixInvoiceLine;
  Payment: TLandrixInvoicePaymentType;
  Tax: TLandrixInvoiceTaxAmount;
  Party: TLandrixInvoiceAccountingParty;
begin
  Invoice.InvoiceNumber := 'R-1';
  Invoice.InvoiceIssueDate := EncodeDate(2026, 10, 20);
  Invoice.InvoiceTypeCode := itc_CommercialInvoice;
  Invoice.InvoiceCurrencyCode := 'EUR';
  Invoice.BuyerReference := 'LW-1';
  Party := Invoice.AccountingSupplierParty;
  Party.RegistrationName := 'Seller GmbH';
  Party.Name := 'Seller';
  Party.Address.StreetName := 'Street 1';
  Party.Address.City := 'Berlin';
  Party.Address.PostalZone := '10115';
  Party.Address.CountryCode := 'DE';
  Party.ContactName := 'Accounting';
  Party.ContactTelephone := '+49 30 123456';
  Party.ContactElectronicMail := 'accounting@seller.example';
  Party.VATCompanyID := 'DE123456789';
  Party.ElectronicAddressSellerBuyer := 'invoice@seller.example';
  Party.ElectronicAddressSellerBuyerSchemeID := 'EM';
  Party := Invoice.AccountingCustomerParty;
  Party.RegistrationName := 'Buyer AG';
  Party.Address.City := 'Hamburg';
  Party.Address.PostalZone := '20095';
  Party.Address.CountryCode := 'DE';
  Party.ElectronicAddressSellerBuyer := 'invoice@buyer.example';
  Party.ElectronicAddressSellerBuyerSchemeID := 'EM';
  Payment := Invoice.PaymentTypes.AddPaymentType;
  Payment.PaymentMeansCode := ipmc_SEPACreditTransfer;
  Payment.FinancialAccount := 'DE02120300000000202051';
  Line := Invoice.InvoiceLines.AddInvoiceLine;
  Line.ID := '1';
  Line.Name := 'Item';
  Line.Quantity := 1;
  Line.UnitCode := iuc_piece;
  Line.NetPriceAmount := 100;
  Line.LineAmount := 100;
  Line.TaxCategory := idtfcc_S_StandardRate;
  Line.TaxPercent := 19;
  Tax := Invoice.TaxAmountSubtotals.AddTaxAmount;
  Tax.TaxableAmount := 100;
  Tax.TaxAmount := 19;
  Tax.TaxCategory := idtfcc_S_StandardRate;
  Tax.TaxPercent := 19;
  Invoice.LineAmount := 100;
  Invoice.TaxExclusiveAmount := 100;
  Invoice.TaxAmountTotal := 19;
  Invoice.TaxInclusiveAmount := 119;
  Invoice.PayableAmount := 119;
end;

procedure AddAllowanceCharge(Invoice: TLandrixInvoice; ACharge, AWithCategory, AWithReason: Boolean);
var
  Item: TLandrixInvoiceAllowanceCharge;
begin
  Item := Invoice.AllowanceCharges.AddAllowanceCharge;
  Item.ChargeIndicator := ACharge;
  Item.Amount := 5;
  if AWithCategory then
    Item.TaxCategory := idtfcc_S_StandardRate;
  Item.TaxPercent := 19;
  if AWithReason then
    Item.Reason := 'Reason'
  else
    Item.Reason := ' ';
end;

procedure AddPdf(Invoice: TLandrixInvoice; const AID, AFilename: TLandrixEInvoiceString);
var
  A: TLandrixInvoiceAttachment;
begin
  A := Invoice.Attachments.AddAttachment(iat_application_pdf);
  A.ID := AID;
  A.Filename := AFilename;
  A.EmbedDataFromText(TLandrixEInvoiceString('%PDF'));
end;

{ Breaks the business term of rule AID in a complete invoice. }
procedure Mutate(Invoice: TLandrixInvoice; const AID: string);
var
  Line: TLandrixInvoiceLine;
  Payment: TLandrixInvoicePaymentType;
  Seller, Buyer: TLandrixInvoiceAccountingParty;
begin
  Line := Invoice.InvoiceLines[0];
  Payment := Invoice.PaymentTypes[0];
  Seller := Invoice.AccountingSupplierParty;
  Buyer := Invoice.AccountingCustomerParty;
  if AID = 'BR-02' then
    Invoice.InvoiceNumber := ' '
  else if AID = 'BR-03' then
    Invoice.InvoiceIssueDate := 0
  else if AID = 'BR-04' then
    Invoice.InvoiceTypeCode := itc_None
  else if AID = 'BR-05' then
    Invoice.InvoiceCurrencyCode := ' '
  else if AID = 'BR-06' then
    Seller.RegistrationName := ' '
  else if AID = 'BR-07' then
    Buyer.RegistrationName := ' '
  else if AID = 'BR-08' then
    Seller.Address.Clear
  else if AID = 'BR-09' then
    Seller.Address.CountryCode := ' '
  else if AID = 'BR-10' then
    Buyer.Address.Clear
  else if AID = 'BR-11' then
    Buyer.Address.CountryCode := ' '
  else if AID = 'BR-16' then
    Invoice.InvoiceLines.Clear
  else if AID = 'BR-17' then
    Invoice.PayeeParty.Identifier := 'P-1'
  else if (AID = 'BR-18') or (AID = 'BR-19') or (AID = 'BR-20') or (AID = 'BR-56') then
  begin
    Invoice.TaxRepresentativeParty.Name := 'Representative';
    Invoice.TaxRepresentativeParty.VATCompanyID := 'DE987654321';
    Invoice.TaxRepresentativeParty.Address.City := 'Bonn';
    Invoice.TaxRepresentativeParty.Address.CountryCode := 'DE';
    if AID = 'BR-18' then
      Invoice.TaxRepresentativeParty.Name := ' '
    else if AID = 'BR-19' then
      Invoice.TaxRepresentativeParty.Address.Clear
    else if AID = 'BR-20' then
      Invoice.TaxRepresentativeParty.Address.CountryCode := ' '
    else
      Invoice.TaxRepresentativeParty.VATCompanyID := ' ';
  end
  else if AID = 'BR-21' then
    Line.ID := ' '
  else if AID = 'BR-23' then
    Line.UnitCode := iuc_None
  else if AID = 'BR-25' then
    Line.Name := ' '
  else if AID = 'BR-27' then
    Line.NetPriceAmount := -1
  else if AID = 'BR-28' then
    Line.GrossPriceAmount := -1
  else if AID = 'BR-29' then
  begin
    Invoice.InvoicePeriodStartDate := EncodeDate(2026, 10, 2);
    Invoice.InvoicePeriodEndDate := EncodeDate(2026, 10, 1);
  end
  else if AID = 'BR-30' then
  begin
    Line.InvoiceLinePeriodStartDate := EncodeDate(2026, 10, 2);
    Line.InvoiceLinePeriodEndDate := EncodeDate(2026, 10, 1);
  end
  else if AID = 'BR-32' then
    AddAllowanceCharge(Invoice, False, False, True)
  else if AID = 'BR-33' then
    AddAllowanceCharge(Invoice, False, True, False)
  else if AID = 'BR-37' then
    AddAllowanceCharge(Invoice, True, False, True)
  else if AID = 'BR-38' then
    AddAllowanceCharge(Invoice, True, True, False)
  else if (AID = 'BR-42') or (AID = 'BR-44') then
    with Line.AllowanceCharges.AddAllowanceCharge do
    begin
      ChargeIndicator := AID = 'BR-44';
      Amount := 1;
    end
  else if AID = 'BR-47' then
    Invoice.TaxAmountSubtotals[0].TaxCategory := idtfcc_None
  else if AID = 'BR-52' then
    AddPdf(Invoice, ' ', 'a.pdf')
  else if AID = 'BR-53' then
    Invoice.TaxCurrencyCode := 'USD'
  else if AID = 'BR-54' then
    with Line.ItemAttributes.AddItemAttribute do
    begin
      Name := 'Colour';
      Value := ' ';
    end
  else if AID = 'BR-55' then
    Invoice.PrecedingInvoiceReferences.AddPrecedingInvoiceReference.ID := ' '
  else if AID = 'BR-57' then
    Invoice.DeliveryInformation.Address.City := 'Bonn'
  else if (AID = 'BR-61') or (AID = 'BR-DE-23-a') then
    Payment.FinancialAccount := ' '
  else if AID = 'BR-62' then
    Seller.ElectronicAddressSellerBuyerSchemeID := ' '
  else if AID = 'BR-63' then
    Buyer.ElectronicAddressSellerBuyerSchemeID := ' '
  else if AID = 'BR-64' then
    Line.StandardItemIdentifier := 'X-1'
  else if AID = 'BR-65' then
    Line.ItemClassifications.AddItemClassification.ClassCode := 'C-1'
  else if AID = 'BR-DE-1' then
    Invoice.PaymentTypes.Clear
  else if AID = 'BR-DE-2' then
  begin
    Seller.ContactName := ' ';
    Seller.ContactTelephone := '';
    Seller.ContactElectronicMail := '';
  end
  else if AID = 'BR-DE-3' then
    Seller.Address.City := ' '
  else if AID = 'BR-DE-4' then
    Seller.Address.PostalZone := ' '
  else if AID = 'BR-DE-5' then
    Seller.ContactName := ' '
  else if AID = 'BR-DE-6' then
    Seller.ContactTelephone := ' '
  else if AID = 'BR-DE-7' then
    Seller.ContactElectronicMail := ' '
  else if AID = 'BR-DE-8' then
    Buyer.Address.City := ' '
  else if AID = 'BR-DE-9' then
    Buyer.Address.PostalZone := ' '
  else if AID = 'BR-DE-10' then
  begin
    Invoice.DeliveryInformation.Address.PostalZone := '53111';
    Invoice.DeliveryInformation.Address.CountryCode := 'DE';
  end
  else if AID = 'BR-DE-11' then
  begin
    Invoice.DeliveryInformation.Address.City := 'Bonn';
    Invoice.DeliveryInformation.Address.CountryCode := 'DE';
  end
  else if AID = 'BR-DE-15' then
    Invoice.BuyerReference := ' '
  else if AID = 'BR-DE-16' then
    Seller.VATCompanyID := ' '
  else if AID = 'BR-DE-22' then
  begin
    AddPdf(Invoice, 'A-1', 'a.pdf');
    AddPdf(Invoice, 'A-2', 'a.pdf');
  end
  else if (AID = 'BR-DE-23-b') or (AID = 'BR-DE-24-b') then
  begin
    if AID = 'BR-DE-24-b' then
      Payment.PaymentMeansCode := ipmc_CreditCard;
    Seller.BankAssignedCreditorIdentifier := 'DE98ZZZ09999999999';
  end
  else if AID = 'BR-DE-24-a' then
  begin
    Payment.PaymentMeansCode := ipmc_CreditCard;
    Payment.FinancialAccount := ' ';
  end
  else if (AID = 'BR-DE-25-a') or (AID = 'BR-DE-25-b') or (AID = 'BR-DE-30') or (AID = 'BR-DE-31') then
  begin
    Payment.PaymentMeansCode := ipmc_SEPADirectDebit;
    Invoice.PaymentMandateID := 'M-1';
    Seller.BankAssignedCreditorIdentifier := 'DE98ZZZ09999999999';
    if AID = 'BR-DE-25-a' then
    begin
      Invoice.PaymentMandateID := ' ';
      Seller.BankAssignedCreditorIdentifier := '';
      Payment.FinancialAccount := ' ';
    end
    else if AID = 'BR-DE-25-b' then
      Payment.FinancialInstitutionBranch := 'COBADEFFXXX'
    else if AID = 'BR-DE-30' then
      Seller.BankAssignedCreditorIdentifier := ' '
    else
      Payment.FinancialAccount := ' ';
  end
  else if AID = 'BR-DE-26' then
    Invoice.InvoiceTypeCode := itc_CorrectedInvoice
  else if AID = 'PEPPOL-EN16931-R003' then
    Invoice.BuyerReference := ' '
  else if AID = 'PEPPOL-EN16931-R010' then
    Buyer.ElectronicAddressSellerBuyer := ' '
  else if AID = 'PEPPOL-EN16931-R020' then
    Seller.ElectronicAddressSellerBuyer := ' '
  else if AID = 'PEPPOL-EN16931-R061' then
    Payment.PaymentMeansCode := ipmc_DirectDebit
  else if (AID = 'BR-CO-10') or (AID = 'BR-FXEXT-CO-10') then
    Invoice.LineAmount := 99
  else if (AID = 'BR-CO-11') or (AID = 'BR-FXEXT-CO-11') then
    Invoice.AllowanceTotalAmount := 5
  else if (AID = 'BR-CO-12') or (AID = 'BR-FXEXT-CO-12') then
    Invoice.ChargeTotalAmount := 5
  else if (AID = 'BR-CO-13') or (AID = 'BR-FXEXT-CO-13') then
    Invoice.TaxExclusiveAmount := 101
  else if AID = 'BR-CO-14' then
    Invoice.TaxAmountTotal := 20
  else if (AID = 'BR-CO-15') or (AID = 'BR-FXEXT-CO-15') then
    Invoice.TaxInclusiveAmount := 120
  else if (AID = 'BR-CO-16') or (AID = 'BR-FXEXT-CO-16') then
    Invoice.PayableAmount := 100
  else if AID = 'BR-CO-17' then
    Invoice.TaxAmountSubtotals[0].TaxAmount := 21
  else if AID = 'BR-DEX-09' then
    with Invoice.PrepaidPayments.AddPrepaidPayment do
    begin
      ID := 'Fee';
      InstructionID := 'Fee paid by a third party';
      PaidAmount := 10;
    end
  else
    Fail('no mutation for ' + AID);
end;

type
  { One rule case: the rule, a target it applies to and one it does not
    (tk_None: it applies to every target). }
  TRuleCase = record
    ID: string;
    Target: TTargetKind;
    NotApplicable: TTargetKind;
  end;

const
  RuleCases: array[0..88] of TRuleCase = (
    (ID: 'BR-02'; Target: tk_FXMinimum; NotApplicable: tk_None),
    (ID: 'BR-03'; Target: tk_XRUBL; NotApplicable: tk_None),
    (ID: 'BR-04'; Target: tk_XRCII; NotApplicable: tk_None),
    (ID: 'BR-05'; Target: tk_Peppol; NotApplicable: tk_None),
    (ID: 'BR-06'; Target: tk_FXMinimum; NotApplicable: tk_None),
    (ID: 'BR-07'; Target: tk_FXBasicWL; NotApplicable: tk_None),
    (ID: 'BR-08'; Target: tk_FXMinimum; NotApplicable: tk_None),
    (ID: 'BR-09'; Target: tk_XRUBL; NotApplicable: tk_None),
    (ID: 'BR-10'; Target: tk_FXBasicWL; NotApplicable: tk_FXMinimum),
    (ID: 'BR-11'; Target: tk_XRCII; NotApplicable: tk_FXMinimum),
    (ID: 'BR-16'; Target: tk_FXBasic; NotApplicable: tk_FXBasicWL),
    (ID: 'BR-17'; Target: tk_XRUBL; NotApplicable: tk_FXMinimum),
    (ID: 'BR-18'; Target: tk_XRCII; NotApplicable: tk_FXMinimum),
    (ID: 'BR-19'; Target: tk_Peppol; NotApplicable: tk_FXMinimum),
    (ID: 'BR-20'; Target: tk_FXBasicWL; NotApplicable: tk_FXMinimum),
    (ID: 'BR-21'; Target: tk_FXBasic; NotApplicable: tk_FXBasicWL),
    (ID: 'BR-23'; Target: tk_FXEN16931; NotApplicable: tk_FXExtended),
    (ID: 'BR-25'; Target: tk_FXExtended; NotApplicable: tk_FXBasicWL),
    (ID: 'BR-27'; Target: tk_XRUBL; NotApplicable: tk_FXExtended),
    (ID: 'BR-28'; Target: tk_XRCII; NotApplicable: tk_FXExtended),
    (ID: 'BR-29'; Target: tk_FXBasicWL; NotApplicable: tk_FXMinimum),
    (ID: 'BR-30'; Target: tk_FXBasic; NotApplicable: tk_FXBasicWL),
    (ID: 'BR-32'; Target: tk_XRUBL; NotApplicable: tk_FXMinimum),
    (ID: 'BR-33'; Target: tk_XRCII; NotApplicable: tk_FXMinimum),
    (ID: 'BR-37'; Target: tk_Peppol; NotApplicable: tk_FXMinimum),
    (ID: 'BR-38'; Target: tk_FXBasicWL; NotApplicable: tk_FXExtended),
    (ID: 'BR-42'; Target: tk_FXExtended; NotApplicable: tk_FXBasicWL),
    (ID: 'BR-44'; Target: tk_FXBasic; NotApplicable: tk_FXExtended),
    (ID: 'BR-47'; Target: tk_XRUBL; NotApplicable: tk_FXMinimum),
    (ID: 'BR-52'; Target: tk_FXEN16931; NotApplicable: tk_FXBasic),
    (ID: 'BR-53'; Target: tk_XRCII; NotApplicable: tk_FXMinimum),
    (ID: 'BR-54'; Target: tk_XRUBL; NotApplicable: tk_FXExtended),
    (ID: 'BR-55'; Target: tk_Peppol; NotApplicable: tk_FXMinimum),
    (ID: 'BR-56'; Target: tk_XRUBL; NotApplicable: tk_FXMinimum),
    (ID: 'BR-57'; Target: tk_FXExtended; NotApplicable: tk_FXMinimum),
    (ID: 'BR-61'; Target: tk_XRUBL; NotApplicable: tk_XRCII),
    (ID: 'BR-62'; Target: tk_Peppol; NotApplicable: tk_XRUBL),
    (ID: 'BR-63'; Target: tk_Peppol; NotApplicable: tk_FXEN16931),
    (ID: 'BR-64'; Target: tk_XRUBL; NotApplicable: tk_FXBasicWL),
    (ID: 'BR-65'; Target: tk_FXBasic; NotApplicable: tk_FXBasicWL),
    (ID: 'BR-DE-1'; Target: tk_XRUBL; NotApplicable: tk_Peppol),
    (ID: 'BR-DE-2'; Target: tk_XRCII; NotApplicable: tk_Peppol),
    (ID: 'BR-DE-3'; Target: tk_XRUBL; NotApplicable: tk_FXEN16931),
    (ID: 'BR-DE-4'; Target: tk_XRCII; NotApplicable: tk_Peppol),
    (ID: 'BR-DE-5'; Target: tk_XRUBL; NotApplicable: tk_Peppol),
    (ID: 'BR-DE-6'; Target: tk_XRCII; NotApplicable: tk_Peppol),
    (ID: 'BR-DE-7'; Target: tk_XRUBL; NotApplicable: tk_Peppol),
    (ID: 'BR-DE-8'; Target: tk_XRCII; NotApplicable: tk_Peppol),
    (ID: 'BR-DE-9'; Target: tk_XRUBL; NotApplicable: tk_Peppol),
    (ID: 'BR-DE-10'; Target: tk_XRCII; NotApplicable: tk_Peppol),
    (ID: 'BR-DE-11'; Target: tk_XRUBL; NotApplicable: tk_Peppol),
    (ID: 'BR-DE-15'; Target: tk_XRCII; NotApplicable: tk_FXEN16931),
    (ID: 'BR-DE-16'; Target: tk_XRUBL; NotApplicable: tk_Peppol),
    (ID: 'BR-DE-22'; Target: tk_XRCII; NotApplicable: tk_Peppol),
    (ID: 'BR-DE-23-a'; Target: tk_XRUBL; NotApplicable: tk_Peppol),
    (ID: 'BR-DE-23-b'; Target: tk_XRCII; NotApplicable: tk_XRUBL),
    (ID: 'BR-DE-24-a'; Target: tk_XRUBL; NotApplicable: tk_Peppol),
    (ID: 'BR-DE-24-b'; Target: tk_XRCII; NotApplicable: tk_XRUBL),
    (ID: 'BR-DE-25-a'; Target: tk_XRUBL; NotApplicable: tk_Peppol),
    (ID: 'BR-DE-25-b'; Target: tk_XRCII; NotApplicable: tk_XRUBL),
    (ID: 'BR-DE-26'; Target: tk_XRUBL; NotApplicable: tk_Peppol),
    (ID: 'BR-DE-30'; Target: tk_XRUBL; NotApplicable: tk_Peppol),
    (ID: 'BR-DE-31'; Target: tk_XRCII; NotApplicable: tk_Peppol),
    (ID: 'PEPPOL-EN16931-R003'; Target: tk_Peppol; NotApplicable: tk_FXEN16931),
    (ID: 'PEPPOL-EN16931-R010'; Target: tk_XRUBL; NotApplicable: tk_FXEN16931),
    (ID: 'PEPPOL-EN16931-R020'; Target: tk_Peppol; NotApplicable: tk_FXBasicWL),
    (ID: 'PEPPOL-EN16931-R061'; Target: tk_XRCII; NotApplicable: tk_FXExtended),
    { the same rules for a second target }
    (ID: 'BR-16'; Target: tk_Peppol; NotApplicable: tk_FXMinimum),
    (ID: 'BR-21'; Target: tk_XRCII; NotApplicable: tk_FXMinimum),
    (ID: 'BR-DE-30'; Target: tk_XRCII; NotApplicable: tk_FXExtended),
    (ID: 'BR-DE-31'; Target: tk_XRUBL; NotApplicable: tk_FXExtended),
    (ID: 'BR-DE-25-a'; Target: tk_XRCII; NotApplicable: tk_FXExtended),
    (ID: 'BR-62'; Target: tk_Peppol; NotApplicable: tk_XRCII),
    (ID: 'BR-29'; Target: tk_Peppol; NotApplicable: tk_None),
    (ID: 'BR-CO-10'; Target: tk_XRUBL; NotApplicable: tk_FXBasicWL),
    (ID: 'BR-CO-11'; Target: tk_FXBasicWL; NotApplicable: tk_FXMinimum),
    (ID: 'BR-CO-12'; Target: tk_XRCII; NotApplicable: tk_FXExtended),
    (ID: 'BR-CO-13'; Target: tk_Peppol; NotApplicable: tk_FXMinimum),
    (ID: 'BR-CO-14'; Target: tk_FXExtended; NotApplicable: tk_FXMinimum),
    (ID: 'BR-CO-15'; Target: tk_FXBasic; NotApplicable: tk_FXExtended),
    (ID: 'BR-CO-16'; Target: tk_FXEN16931; NotApplicable: tk_FXExtended),
    (ID: 'BR-CO-17'; Target: tk_XRCII; NotApplicable: tk_FXExtended),
    (ID: 'BR-FXEXT-CO-10'; Target: tk_FXExtended; NotApplicable: tk_FXEN16931),
    (ID: 'BR-FXEXT-CO-11'; Target: tk_FXExtended; NotApplicable: tk_XRUBL),
    (ID: 'BR-FXEXT-CO-12'; Target: tk_FXExtended; NotApplicable: tk_XRCII),
    (ID: 'BR-FXEXT-CO-13'; Target: tk_FXExtended; NotApplicable: tk_Peppol),
    (ID: 'BR-FXEXT-CO-15'; Target: tk_FXExtended; NotApplicable: tk_FXBasic),
    (ID: 'BR-FXEXT-CO-16'; Target: tk_FXExtended; NotApplicable: tk_FXBasicWL),
    (ID: 'BR-DEX-09'; Target: tk_XRUBL; NotApplicable: tk_XRCII));

function HasRule(D: TLandrixEInvoiceDiagnostics; const AID: string): Boolean;
var
  I: TLandrixEInvoiceListIndex;
begin
  Result := True;
  for I := 0 to D.Count - 1 do
    if D[I].RuleID = TLandrixEInvoiceString(AID) then
      Exit;
  Result := False;
end;

{ A violation adds one edk_RuleViolation with rule, severity and business
  terms; ToText shows the rule; nil diagnostics are allowed. }
procedure TestRuleDiagnostic;
var
  Invoice: TLandrixInvoice;
  D: TLandrixEInvoiceDiagnostics;
begin
  D := TLandrixEInvoiceDiagnostics.Create;
  Invoice := TLandrixInvoice.Create;
  try
    Check(not LandrixEInvoiceCheckRule(Invoice, SpecFor(TLandrixEInvoiceTargets.XRechnung('3.0', esy_UBL)),
      'LX-CC-01', D), 'no payment means');
    CheckEquals(1, Integer(D.Count), 'one diagnostic');
    Check(D[0].Kind = edk_RuleViolation, 'kind');
    Check(D[0].Severity = eds_Error, 'severity');
    CheckEqualsInvoiceStr('LX-CC-01', D[0].RuleID, 'rule');
    CheckEqualsInvoiceStr('BG-16', D[0].Path, 'business terms as path');
    Check(Pos('RuleViolation [LX-CC-01] BG-16: ', string(D.ToText)) > 0, 'ToText: ' + string(D.ToText));
    Check(not LandrixEInvoiceCheckRule(Invoice, SpecFor(TLandrixEInvoiceTargets.XRechnung('3.0', esy_UBL)),
      'LX-CC-01', nil), 'nil diagnostics');
    Invoice.PaymentTypes.AddPaymentType.PaymentMeansCode := ipmc_SEPACreditTransfer;
    D.Clear;
    Check(LandrixEInvoiceCheckRule(Invoice, SpecFor(TLandrixEInvoiceTargets.XRechnung('3.0', esy_UBL)),
      'LX-CC-01', D), 'rule holds');
    CheckEquals(0, Integer(D.Count), 'nothing reported');
  finally
    Invoice.Free;
    D.Free;
  end;
end;

{ A rule that does not apply holds: LX-CC-01 exempts Factur-X EN 16931,
  LX-CC-02 applies to XRechnung only. }
procedure TestApplicability;
var
  Invoice: TLandrixInvoice;
begin
  Invoice := TLandrixInvoice.Create;
  try
    Check(LandrixEInvoiceCheckRule(Invoice, SpecFor(TLandrixEInvoiceTargets.FacturX('1.09', epr_EN16931)),
      'LX-CC-01', nil), 'EN 16931 needs no payment means');
    Invoice.InvoiceTypeCode := itc_DebitNote;
    Check(not LandrixEInvoiceCheckRule(Invoice, SpecFor(TLandrixEInvoiceTargets.XRechnung('3.0', esy_CII)),
      'LX-CC-02', nil), 'debit note in XRechnung');
    Check(LandrixEInvoiceCheckRule(Invoice, SpecFor(TLandrixEInvoiceTargets.PeppolBIS('3.0')),
      'LX-CC-02', nil), 'debit note in Peppol');
  finally
    Invoice.Free;
  end;
end;

{ The empty entry (a target without specification) gets the LX-CC rules:
  third-party payments fail there as for the old unwritable versions. The
  official rules do not apply to it. }
procedure TestEmptySpec;
var
  Invoice: TLandrixInvoice;
  Spec: TLandrixEInvoiceSpec;
begin
  Invoice := TLandrixInvoice.Create;
  try
    Check(not LandrixEInvoiceFindSpec(TLandrixEInvoiceTargets.PeppolBIS(''), Spec), 'no entry');
    Check(LandrixEInvoiceCheckRule(Invoice, Spec, 'LX-CC-08', nil), 'no third-party payments');
    Invoice.PrepaidPayments.AddPrepaidPayment.PaidAmount := 10;
    Check(not LandrixEInvoiceCheckRule(Invoice, Spec, 'LX-CC-08', nil), 'third-party payments, no target');
    Check(LandrixEInvoiceCheckRule(Invoice, SpecFor(TLandrixEInvoiceTargets.XRechnung('3.0', esy_UBL)),
      'LX-CC-08', nil), 'third-party payments in XRechnung UBL');
    CheckEquals(0, LandrixEInvoiceCheckInvoice(Invoice, Spec, nil), 'no official rule for the empty entry');
  finally
    Invoice.Free;
  end;
end;

procedure TestUnknownRule;
var
  Invoice: TLandrixInvoice;
begin
  Invoice := TLandrixInvoice.Create;
  try
    try
      LandrixEInvoiceCheckRule(Invoice, SpecFor(TLandrixEInvoiceTargets.PeppolBIS('3.0')), 'lx-cc-01', nil);
      FailNotRaised('ELandrixEInvoiceError');
    except
      on ELandrixEInvoiceError do ;
    end;
  finally
    Invoice.Free;
  end;
end;

{ LandrixEInvoiceCheckInvoice does not run the legacy rules: two credit
  cards (LX-CC-05) pass. }
procedure TestCheckInvoiceSkipsLegacy;
var
  Invoice: TLandrixInvoice;
  D: TLandrixEInvoiceDiagnostics;
begin
  D := TLandrixEInvoiceDiagnostics.Create;
  Invoice := TLandrixInvoice.Create;
  try
    FillComplete(Invoice);
    with Invoice.PaymentTypes.AddPaymentType do
    begin
      PaymentMeansCode := ipmc_CreditCard;
      FinancialAccount := '1234';
    end;
    with Invoice.PaymentTypes.AddPaymentType do
    begin
      PaymentMeansCode := ipmc_CreditCard;
      FinancialAccount := '5678';
    end;
    Check(not LandrixEInvoiceCheckRule(Invoice, SpecOf(tk_XRUBL), 'LX-CC-05', nil), 'LX-CC-05 is violated');
    CheckEquals(0, LandrixEInvoiceCheckInvoice(Invoice, SpecOf(tk_XRUBL), D), 'no errors');
    CheckEquals(0, D.CountOf(edk_RuleViolation), 'no legacy rule reported');
  finally
    Invoice.Free;
    D.Free;
  end;
end;

{ Blank text counts as absent in the rules as in the writers: a blank VAT
  identifier does not satisfy LX-CC-06, a blank GTIN is no item
  identifier. }
procedure TestBlankValues;
var
  Invoice: TLandrixInvoice;
  Line: TLandrixInvoiceLine;
  Value, Scheme, Conflict: TLandrixEInvoiceString;
begin
  Invoice := TLandrixInvoice.Create;
  try
    Invoice.AccountingSupplierParty.VATCompanyID := ' ';
    Check(not LandrixEInvoiceCheckRule(Invoice, SpecFor(TLandrixEInvoiceTargets.PeppolBIS('3.0')),
      'LX-CC-06', nil), 'blank VAT identifier is none');
    Line := Invoice.InvoiceLines.AddInvoiceLine;
    Line.GlobalID_EAN_GTIN := '  ';
    Check(not LandrixEInvoiceStandardItemIdentifierOf(Line, Value, Scheme, Conflict), 'blank GTIN');
    Line.StandardItemIdentifier := ' ';
    Line.GlobalID_EAN_GTIN := '4012345678901';
    Check(LandrixEInvoiceStandardItemIdentifierOf(Line, Value, Scheme, Conflict), 'GTIN behind blank identifier');
    CheckEqualsInvoiceStr('4012345678901', Value, 'GTIN written');
    CheckEqualsInvoiceStr('', Conflict, 'no conflict');
  finally
    Invoice.Free;
  end;
end;

{ The complete invoice passes every target without any diagnostic. }
procedure TestCompleteInvoice;
var
  Invoice: TLandrixInvoice;
  D: TLandrixEInvoiceDiagnostics;
  K: TTargetKind;
begin
  D := TLandrixEInvoiceDiagnostics.Create;
  Invoice := TLandrixInvoice.Create;
  try
    FillComplete(Invoice);
    for K := tk_XRUBL to High(TTargetKind) do
    begin
      D.Clear;
      CheckEquals(0, LandrixEInvoiceCheckInvoice(Invoice, SpecOf(K), D), 'errors for target ' + IntToStr(Ord(K)));
      CheckEqualsStr('', string(D.ToText), 'diagnostics for target ' + IntToStr(Ord(K)));
    end;
  finally
    Invoice.Free;
    D.Free;
  end;
end;

{ Each rule case: the rule fires once for its target, also inside
  LandrixEInvoiceCheckInvoice, and holds for a target it does not apply
  to. }
procedure TestRuleCases;
var
  Invoice: TLandrixInvoice;
  D: TLandrixEInvoiceDiagnostics;
  I: Integer;
  ID: string;
begin
  D := TLandrixEInvoiceDiagnostics.Create;
  try
    for I := Low(RuleCases) to High(RuleCases) do
    begin
      ID := RuleCases[I].ID;
      Invoice := TLandrixInvoice.Create;
      try
        FillComplete(Invoice);
        Mutate(Invoice, ID);
        D.Clear;
        Check(not LandrixEInvoiceCheckRule(Invoice, SpecOf(RuleCases[I].Target), TLandrixEInvoiceString(ID), D),
          ID + ' violated (case ' + IntToStr(I) + ')');
        CheckEquals(1, Integer(D.Count), ID + ' one diagnostic');
        if D.Count = 1 then
          CheckEqualsInvoiceStr(TLandrixEInvoiceString(ID), D[0].RuleID, ID + ' rule of the diagnostic');
        D.Clear;
        LandrixEInvoiceCheckInvoice(Invoice, SpecOf(RuleCases[I].Target), D);
        Check(HasRule(D, ID), ID + ' reported by LandrixEInvoiceCheckInvoice');
        if RuleCases[I].NotApplicable <> tk_None then
          Check(LandrixEInvoiceCheckRule(Invoice, SpecOf(RuleCases[I].NotApplicable), TLandrixEInvoiceString(ID),
            nil), ID + ' does not apply (case ' + IntToStr(I) + ')');
      finally
        Invoice.Free;
      end;
    end;
  finally
    D.Free;
  end;
end;

{ Edge cases: a net price of 0, equal period dates, the invoice currency as
  VAT accounting currency, the placeholder buyer reference, a sales order
  as Peppol order reference (written as cbc:SalesOrderID with 'NA') and a
  department as contact point hold; BR-DE-26 is a warning and no error. }
procedure TestBoundaries;
var
  Invoice: TLandrixInvoice;
  D: TLandrixEInvoiceDiagnostics;
begin
  D := TLandrixEInvoiceDiagnostics.Create;
  Invoice := TLandrixInvoice.Create;
  try
    FillComplete(Invoice);
    Invoice.InvoiceLines[0].NetPriceAmount := 0;
    Invoice.InvoiceLines[0].GrossPriceAmount := 0;
    Invoice.InvoicePeriodStartDate := EncodeDate(2026, 10, 1);
    Invoice.InvoicePeriodEndDate := EncodeDate(2026, 10, 1) + 0.5;
    Invoice.TaxCurrencyCode := 'EUR';
    Invoice.BuyerReference := LandrixEInvoiceLeitwegIDNonExistent;
    Invoice.AccountingSupplierParty.ContactName := '';
    Invoice.AccountingSupplierParty.ContactDepartment := 'Accounting';
    CheckEquals(0, LandrixEInvoiceCheckInvoice(Invoice, SpecOf(tk_XRUBL), D), 'XRechnung: ' + string(D.ToText));
    Invoice.BuyerReference := '';
    Invoice.SellerOrderReference := 'SO-1';
    CheckEquals(0, LandrixEInvoiceCheckInvoice(Invoice, SpecOf(tk_Peppol), D), 'Peppol: ' + string(D.ToText));
    Invoice.InvoiceTypeCode := itc_CorrectedInvoice;
    Invoice.BuyerReference := 'LW-1';
    D.Clear;
    CheckEquals(0, LandrixEInvoiceCheckInvoice(Invoice, SpecOf(tk_XRUBL), D), 'BR-DE-26 is no error');
    CheckEquals(1, Integer(D.Count), 'BR-DE-26 reported');
    if D.Count = 1 then
      Check(D[0].Severity = eds_Warning, 'BR-DE-26 warning');
    Invoice.PrecedingInvoiceReferences.AddPrecedingInvoiceReference.ID := ' ';
    Check(not LandrixEInvoiceCheckRule(Invoice, SpecOf(tk_XRUBL), 'BR-DE-26', nil), 'reference without identifier');
    Invoice.PrecedingInvoiceReferences.AddPrecedingInvoiceReference.ID := 'R-0';
    Check(LandrixEInvoiceCheckRule(Invoice, SpecOf(tk_XRUBL), 'BR-DE-26', nil), 'reference with identifier');
    AddPdf(Invoice, 'A-1', ' ');
    AddPdf(Invoice, 'A-2', ' ');
    Check(LandrixEInvoiceCheckRule(Invoice, SpecOf(tk_XRUBL), 'BR-DE-22', nil), 'blank file names are not written');
  finally
    Invoice.Free;
    D.Free;
  end;
end;

{ BR-17 compares the payee with the seller as each syntax writes them: CII
  with the seller name (BT-27), UBL with the trading name (cac:PartyName). }
procedure TestPayeeLikeSeller;
var
  Invoice: TLandrixInvoice;
begin
  Invoice := TLandrixInvoice.Create;
  try
    FillComplete(Invoice);
    Invoice.PayeeParty.Name := 'Seller GmbH';
    Check(not LandrixEInvoiceCheckRule(Invoice, SpecOf(tk_XRCII), 'BR-17', nil), 'CII: payee named like the seller');
    Check(LandrixEInvoiceCheckRule(Invoice, SpecOf(tk_XRUBL), 'BR-17', nil), 'UBL: trading name differs');
    Invoice.PayeeParty.Name := 'Seller';
    Check(not LandrixEInvoiceCheckRule(Invoice, SpecOf(tk_XRUBL), 'BR-17', nil), 'UBL: payee named like the trading name');
    Check(LandrixEInvoiceCheckRule(Invoice, SpecOf(tk_XRCII), 'BR-17', nil), 'CII: seller name differs');
    Invoice.PayeeParty.Name := 'Factor';
    Invoice.PayeeParty.CompanyID := 'HRB 1';
    Invoice.AccountingSupplierParty.CompanyID := 'HRB 1';
    Check(not LandrixEInvoiceCheckRule(Invoice, SpecOf(tk_XRCII), 'BR-17', nil), 'CII: same legal registration');
    Check(LandrixEInvoiceCheckRule(Invoice, SpecOf(tk_XRUBL), 'BR-17', nil), 'UBL: legal registration not compared');
    Invoice.PayeeParty.CompanyID := '';
    Invoice.AccountingSupplierParty.IdentifierSellerBuyer := 'S-1';
    Invoice.PayeeParty.Identifier := 'S-1';
    Check(not LandrixEInvoiceCheckRule(Invoice, SpecOf(tk_XRCII), 'BR-17', nil), 'CII: same ram:ID');
    Invoice.PayeeParty.IdentifierSchemeID := '0088';
    Check(LandrixEInvoiceCheckRule(Invoice, SpecOf(tk_XRCII), 'BR-17', nil), 'CII: payee ram:GlobalID not compared');
  finally
    Invoice.Free;
  end;
end;

{ The direct debit group differs per syntax: a credit transfer from a
  seller with creditor identifier violates BR-DE-23-b, BR-DE-30 and
  BR-DE-31 in CII (header level BT-90), not in UBL; a complete direct
  debit passes both. }
procedure TestDirectDebitGroups;
var
  Invoice: TLandrixInvoice;
  D: TLandrixEInvoiceDiagnostics;
begin
  D := TLandrixEInvoiceDiagnostics.Create;
  Invoice := TLandrixInvoice.Create;
  try
    FillComplete(Invoice);
    Invoice.AccountingSupplierParty.BankAssignedCreditorIdentifier := 'DE98ZZZ09999999999';
    CheckEquals(3, LandrixEInvoiceCheckInvoice(Invoice, SpecOf(tk_XRCII), D), 'CII: ' + string(D.ToText));
    Check(HasRule(D, 'BR-DE-23-b') and HasRule(D, 'BR-DE-30') and HasRule(D, 'BR-DE-31'), 'CII rules');
    CheckEquals(0, LandrixEInvoiceCheckInvoice(Invoice, SpecOf(tk_XRUBL), nil), 'UBL');
    Invoice.PaymentTypes[0].PaymentMeansCode := ipmc_SEPADirectDebit;
    Invoice.PaymentMandateID := 'M-1';
    D.Clear;
    CheckEquals(0, LandrixEInvoiceCheckInvoice(Invoice, SpecOf(tk_XRCII), D), 'CII direct debit: ' + string(D.ToText));
    CheckEquals(0, LandrixEInvoiceCheckInvoice(Invoice, SpecOf(tk_XRUBL), D), 'UBL direct debit: ' + string(D.ToText));
    { code 49 is a direct debit like 59 }
    Invoice.PaymentTypes[0].PaymentMeansCode := ipmc_DirectDebit;
    CheckEquals(0, LandrixEInvoiceCheckInvoice(Invoice, SpecOf(tk_XRCII), D), 'CII 49: ' + string(D.ToText));
    CheckEquals(0, LandrixEInvoiceCheckInvoice(Invoice, SpecOf(tk_XRUBL), D), 'UBL 49: ' + string(D.ToText));
    Invoice.PaymentTypes[0].FinancialAccount := '';
    Check(not LandrixEInvoiceCheckRule(Invoice, SpecOf(tk_XRUBL), 'BR-DE-31', nil), 'UBL 49 without debited account');
    Invoice.PaymentTypes[0].FinancialAccount := 'DE02120300000000202051';
    Invoice.PaymentTypes[0].PaymentMeansCode := ipmc_SEPADirectDebit;
    Invoice.AccountingSupplierParty.BankAssignedCreditorIdentifier := '';
    Invoice.PayeeParty.Name := 'Factor';
    Invoice.PayeeParty.Identifier := 'DE98ZZZ09999999999';
    Invoice.PayeeParty.IdentifierSchemeID := 'SEPA';
    Check(LandrixEInvoiceCheckRule(Invoice, SpecOf(tk_XRUBL), 'BR-DE-30', nil), 'UBL: creditor at the payee');
    Check(not LandrixEInvoiceCheckRule(Invoice, SpecOf(tk_XRCII), 'BR-DE-30', nil), 'CII: creditor of the seller only');
    { BR-DE-25-a per payment means: a second direct debit without account
      and no mandate }
    Invoice.PaymentMandateID := '';
    with Invoice.PaymentTypes.AddPaymentType do
      PaymentMeansCode := ipmc_SEPADirectDebit;
    Check(not LandrixEInvoiceCheckRule(Invoice, SpecOf(tk_XRUBL), 'BR-DE-25-a', nil), 'second direct debit');
  finally
    Invoice.Free;
    D.Free;
  end;
end;

{ Sub lines are invoice lines in CII only: a sub line without item name
  violates BR-25 there; a UBL cac:SubInvoiceLine is outside the EN 16931
  rules. }
procedure TestSubLines;
var
  Invoice: TLandrixInvoice;
begin
  Invoice := TLandrixInvoice.Create;
  try
    FillComplete(Invoice);
    Invoice.InvoiceLines[0].SubInvoiceLines.AddInvoiceLine.ID := '1.1';
    Check(not LandrixEInvoiceCheckRule(Invoice, SpecOf(tk_XRCII), 'BR-25', nil), 'CII sub line without name');
    Check(LandrixEInvoiceCheckRule(Invoice, SpecOf(tk_XRUBL), 'BR-25', nil), 'UBL sub line not checked');
  finally
    Invoice.Free;
  end;
end;

{ LandrixEInvoiceCheckCII reports what the profile requires below an
  existing parent although the schema leaves it optional: a line without
  invoiced quantity (BT-129) fails Factur-X BASIC, not XRechnung CII (no
  profile; the business rules cover XRechnung). A model for the other
  syntax raises. }
procedure TestCheckCII;
var
  Invoice: TLandrixInvoice;
  CII: TLandrixCIIInvoice;
  D: TLandrixEInvoiceDiagnostics;
  Quantity: TLandrixEInvoiceString;
begin
  D := TLandrixEInvoiceDiagnostics.Create;
  Invoice := TLandrixInvoice.Create;
  try
    FillComplete(Invoice);
    CII := LandrixEInvoiceInvoiceToCII(Invoice, SpecOf(tk_FXBasic), nil);
    try
      CheckEquals(0, LandrixEInvoiceCheckCII(CII, SpecOf(tk_FXBasic), D), 'complete: ' + string(D.ToText));
      { content set in the model that the profile does not contain is an
        error; the model is not changed }
      CII.ExchangedDocument.Name := 'EXTENDED only';
      D.Clear;
      CheckEquals(1, LandrixEInvoiceCheckCII(CII, SpecOf(tk_FXBasic), D), 'BASIC with document name: ' +
        string(D.ToText));
      CheckEquals(1, D.CountOf(edk_NotAllowed), 'name reported');
      CheckEqualsInvoiceStr('EXTENDED only', CII.ExchangedDocument.Name, 'model unchanged');
      CheckEquals(0, LandrixEInvoiceCheckCII(CII, SpecOf(tk_FXExtended), nil), 'allowed in EXTENDED');
      CII.ExchangedDocument.Name := '';
      { without quantity the line delivery is empty and not written; BASIC
        requires it below the line }
      Quantity := '/rsm:CrossIndustryInvoice/rsm:SupplyChainTradeTransaction/ram:IncludedSupplyChainTradeLineItem/' +
        'ram:SpecifiedLineTradeDelivery';
      CII.SupplyChainTradeTransaction.IncludedSupplyChainTradeLineItem[0].SpecifiedLineTradeDelivery.
        BilledQuantity.Value := '';
      CII.SupplyChainTradeTransaction.IncludedSupplyChainTradeLineItem[0].SpecifiedLineTradeDelivery.
        BilledQuantity.UnitCode := '';
      D.Clear;
      CheckEquals(1, LandrixEInvoiceCheckCII(CII, SpecOf(tk_FXBasic), D), 'BASIC: ' + string(D.ToText));
      if D.Count = 1 then
        CheckEqualsInvoiceStr(Quantity, D[0].Path, 'line delivery reported');
      CheckEquals(0, LandrixEInvoiceCheckCII(CII, SpecOf(tk_XRCII), nil), 'XRechnung CII');
      { a quantity without unit (BT-130): the attribute is optional in the
        schema, required in BASIC }
      CII.SupplyChainTradeTransaction.IncludedSupplyChainTradeLineItem[0].SpecifiedLineTradeDelivery.
        BilledQuantity.Value := '1';
      D.Clear;
      CheckEquals(1, LandrixEInvoiceCheckCII(CII, SpecOf(tk_FXBasic), D), 'BASIC unit: ' + string(D.ToText));
      if D.Count = 1 then
        CheckEqualsInvoiceStr(Quantity + '/ram:BilledQuantity/@unitCode', D[0].Path, 'unit reported');
      try
        LandrixEInvoiceCheckCII(CII, SpecOf(tk_XRUBL), nil);
        FailNotRaised('ELandrixEInvoiceError');
      except
        on ELandrixEInvoiceError do ;
      end;
    finally
      CII.Free;
    end;
  finally
    Invoice.Free;
    D.Free;
  end;
end;

{ LandrixEInvoiceCheckUBLInvoice reports what the UBL schema requires. }
procedure TestCheckUBL;
var
  Invoice: TLandrixInvoice;
  UBL: TLandrixUBLInvoice;
  D: TLandrixEInvoiceDiagnostics;
begin
  D := TLandrixEInvoiceDiagnostics.Create;
  Invoice := TLandrixInvoice.Create;
  try
    FillComplete(Invoice);
    UBL := LandrixEInvoiceInvoiceToUBLInvoice(Invoice, SpecOf(tk_Peppol), nil);
    try
      CheckEquals(0, LandrixEInvoiceCheckUBLInvoice(UBL, SpecOf(tk_Peppol), D), 'complete: ' + string(D.ToText));
      UBL.ID.Value := ' ';
      CheckEquals(1, LandrixEInvoiceCheckUBLInvoice(UBL, SpecOf(tk_Peppol), D), 'without number');
      CheckEqualsInvoiceStr('/Invoice/cbc:ID', D[0].Path, 'number reported');
      try
        LandrixEInvoiceCheckUBLInvoice(UBL, SpecOf(tk_FXEN16931), nil);
        FailNotRaised('ELandrixEInvoiceError');
      except
        on ELandrixEInvoiceError do ;
      end;
    finally
      UBL.Free;
    end;
  finally
    Invoice.Free;
    D.Free;
  end;
end;

{ BR-CO-17 allows a difference below 1 (UBL) or up to 1 (CII) from the
  taxable amount x rate rounded to cents; with a rate of 0 the tax amount
  must round to 0. }
procedure TestTaxTolerance;
var
  Invoice: TLandrixInvoice;
  Tax: TLandrixInvoiceTaxAmount;
begin
  Invoice := TLandrixInvoice.Create;
  try
    FillComplete(Invoice);
    Tax := Invoice.TaxAmountSubtotals[0];
    Tax.TaxAmount := CentsValue(1999);
    Check(LandrixEInvoiceCheckRule(Invoice, SpecOf(tk_XRUBL), 'BR-CO-17', nil), 'UBL 19.99 for 19.00');
    Tax.TaxAmount := 20;
    Check(not LandrixEInvoiceCheckRule(Invoice, SpecOf(tk_XRUBL), 'BR-CO-17', nil), 'UBL 20.00 for 19.00');
    Check(LandrixEInvoiceCheckRule(Invoice, SpecOf(tk_XRCII), 'BR-CO-17', nil), 'CII 20.00 for 19.00');
    Tax.TaxAmount := CentsValue(2001);
    Check(not LandrixEInvoiceCheckRule(Invoice, SpecOf(tk_XRCII), 'BR-CO-17', nil), 'CII 20.01 for 19.00');
    Tax.TaxPercent := 0;
    Tax.TaxAmount := CentsValue(49);
    Check(LandrixEInvoiceCheckRule(Invoice, SpecOf(tk_XRUBL), 'BR-CO-17', nil), 'rate 0, 0.49 rounds to 0');
    Tax.TaxAmount := CentsValue(50);
    Check(not LandrixEInvoiceCheckRule(Invoice, SpecOf(tk_XRUBL), 'BR-CO-17', nil), 'rate 0, 0.50 rounds to 1');
  finally
    Invoice.Free;
  end;
end;

{ Third-party payments: where the target writes them the amount due
  includes them (BR-DEX-09, BR-FXEXT-CO-16) and BR-CO-16 gives way; where
  they are left out BR-CO-16 fails. EXTENDED allows 0.01 per amount
  (BR-FXEXT-CO-13); CII accepts BT-112 = BT-109 for BR-CO-15. }
procedure TestTotals;
var
  Invoice: TLandrixInvoice;
begin
  Invoice := TLandrixInvoice.Create;
  try
    FillComplete(Invoice);
    with Invoice.PrepaidPayments.AddPrepaidPayment do
    begin
      ID := 'Fee';
      InstructionID := 'Fee paid by a third party';
      PaidAmount := 10;
    end;
    Invoice.PayableAmount := 129;
    Check(LandrixEInvoiceCheckRule(Invoice, SpecOf(tk_XRUBL), 'BR-DEX-09', nil), 'BR-DEX-09 with third party');
    Check(LandrixEInvoiceCheckRule(Invoice, SpecOf(tk_XRUBL), 'BR-CO-16', nil), 'BR-CO-16 gives way');
    Check(LandrixEInvoiceCheckRule(Invoice, SpecOf(tk_FXExtended), 'BR-FXEXT-CO-16', nil), 'EXTENDED');
    Check(not LandrixEInvoiceCheckRule(Invoice, SpecOf(tk_Peppol), 'BR-CO-16', nil), 'Peppol leaves them out');
    Invoice.InvoiceTypeCode := itc_CreditNote;
    Check(not LandrixEInvoiceCheckRule(Invoice, SpecOf(tk_XRUBL), 'BR-CO-16', nil), 'UBL credit note');
    Invoice.InvoiceTypeCode := itc_CommercialInvoice;
    Invoice.PrepaidPayments.Clear;
    Invoice.PayableAmount := 119;
    Invoice.TaxExclusiveAmount := CentsValue(10001);
    Check(LandrixEInvoiceCheckRule(Invoice, SpecOf(tk_FXExtended), 'BR-FXEXT-CO-13', nil), 'EXTENDED 0.01');
    Check(not LandrixEInvoiceCheckRule(Invoice, SpecOf(tk_FXEN16931), 'BR-CO-13', nil), 'EN 16931 exact');
    Invoice.TaxExclusiveAmount := 100;
    Invoice.TaxInclusiveAmount := 100;
    Check(LandrixEInvoiceCheckRule(Invoice, SpecOf(tk_XRCII), 'BR-CO-15', nil), 'CII: BT-112 = BT-109');
    Check(not LandrixEInvoiceCheckRule(Invoice, SpecOf(tk_XRUBL), 'BR-CO-15', nil), 'UBL: BT-112 = BT-109');
  finally
    Invoice.Free;
  end;
end;

procedure Register;
begin
  RegisterTest('Check.RuleDiagnostic', TestRuleDiagnostic);
  RegisterTest('Check.Applicability', TestApplicability);
  RegisterTest('Check.EmptySpec', TestEmptySpec);
  RegisterTest('Check.UnknownRule', TestUnknownRule);
  RegisterTest('Check.CheckInvoiceSkipsLegacy', TestCheckInvoiceSkipsLegacy);
  RegisterTest('Check.BlankValues', TestBlankValues);
  RegisterTest('Check.CompleteInvoice', TestCompleteInvoice);
  RegisterTest('Check.RuleCases', TestRuleCases);
  RegisterTest('Check.Boundaries', TestBoundaries);
  RegisterTest('Check.PayeeLikeSeller', TestPayeeLikeSeller);
  RegisterTest('Check.DirectDebitGroups', TestDirectDebitGroups);
  RegisterTest('Check.SubLines', TestSubLines);
  RegisterTest('Check.CheckCII', TestCheckCII);
  RegisterTest('Check.CheckUBL', TestCheckUBL);
  RegisterTest('Check.TaxTolerance', TestTaxTolerance);
  RegisterTest('Check.Totals', TestTotals);
end;

end.
