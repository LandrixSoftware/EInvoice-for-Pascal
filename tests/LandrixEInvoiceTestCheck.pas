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
  and hold for a target it does not apply to; the VAT category rules
  BR-S-nn to BR-AG-nn per group and where the syntaxes differ. }

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
  Invoice.InvoiceDueDate := EncodeDate(2026, 11, 19);
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
  { 9930 (German VAT identifier) is in the EAS lists of XRechnung and Peppol;
    Peppol has no EM }
  Party.ElectronicAddressSellerBuyer := 'DE123456789';
  Party.ElectronicAddressSellerBuyerSchemeID := '9930';
  Party := Invoice.AccountingCustomerParty;
  Party.RegistrationName := 'Buyer AG';
  Party.Address.City := 'Hamburg';
  Party.Address.PostalZone := '20095';
  Party.Address.CountryCode := 'DE';
  Party.ElectronicAddressSellerBuyer := 'DE987654321';
  Party.ElectronicAddressSellerBuyerSchemeID := '9930';
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
  else if (AID = 'BR-B-01') or (AID = 'BR-B-02') then
  begin
    Line.TaxCategory := idtfcc_None;
    Line.TaxCategoryOther := 'B';
  end
  else if AID = 'BR-CO-03' then
  begin
    Invoice.TaxPointDate.SetValue(EncodeDate(2026, 10, 1));
    Invoice.TaxPointDateCode := '3';
  end
  else if AID = 'BR-CO-04' then
    Line.TaxCategory := idtfcc_None
  else if AID = 'BR-CO-09' then
    Seller.VATCompanyID := 'XX123456789'
  else if AID = 'BR-CO-18' then
    Invoice.TaxAmountSubtotals.Clear
  else if AID = 'BR-CO-21' then
    AddAllowanceCharge(Invoice, False, True, False)
  else if AID = 'BR-CO-22' then
    AddAllowanceCharge(Invoice, True, True, False)
  else if (AID = 'BR-CO-23') or (AID = 'BR-CO-24') then
    with Line.AllowanceCharges.AddAllowanceCharge do
    begin
      ChargeIndicator := AID = 'BR-CO-24';
      Amount := 1;
    end
  else if AID = 'BR-CO-25' then
    Invoice.InvoiceDueDate := 0
  else if AID = 'BR-CO-26' then
    Seller.VATCompanyID := ' '
  else if AID = 'BR-FXEXT-CO-04' then
    Line.TaxCategory := idtfcc_None
  else if AID = 'BR-DE-17' then
    Invoice.InvoiceTypeCode := itc_PrepaymentInvoice
  else if AID = 'UBL-SR-29' then
  begin
    Seller.BankAssignedCreditorIdentifier := 'DE98ZZZ09999999999';
    Invoice.PayeeParty.Name := 'Payee';
    Invoice.PayeeParty.Identifier := 'DE98ZZZ09999999999';
    Invoice.PayeeParty.IdentifierSchemeID := 'sepa';
  end
  else if AID = 'BR-DE-18' then
  begin
    Invoice.PaymentTermsType := iptt_CashDiscount2;
    Invoice.PaymentTermCashDiscount1Days := 10;
    Invoice.PaymentTermCashDiscount1Percent := 2;
    Invoice.PaymentTermCashDiscount2Days := 14;
    Invoice.PaymentTermCashDiscount2Percent := -1;
  end
  else if AID = 'BR-DE-19' then
    Payment.FinancialAccount := 'DE02120300000000202052'
  else if AID = 'BR-DE-20' then
  begin
    Payment.PaymentMeansCode := ipmc_SEPADirectDebit;
    Invoice.PaymentMandateID := 'M-1';
    Seller.BankAssignedCreditorIdentifier := 'DE98ZZZ09999999999';
    Payment.FinancialAccount := 'DE02120300000000202052';
  end
  else if AID = 'BR-DE-27' then
    Seller.ContactTelephone := '+49'
  else if AID = 'BR-DE-28' then
    Seller.ContactElectronicMail := 'accounting@seller'
  else if AID = 'BR-51' then
  begin
    Payment.PaymentMeansCode := ipmc_CreditCard;
    Payment.FinancialAccount := '12345678901';
  end
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
  else if AID = 'PEPPOL-EN16931-R005' then
    Invoice.TaxCurrencyCode := ' EUR'
  else if (AID = 'PEPPOL-EN16931-R040') or (AID = 'PEPPOL-EN16931-R041') or (AID = 'PEPPOL-EN16931-R042') then
  begin
    AddAllowanceCharge(Invoice, False, True, True);
    if AID <> 'PEPPOL-EN16931-R041' then
      Invoice.AllowanceCharges[0].BaseAmount := 100;
    if AID <> 'PEPPOL-EN16931-R042' then
      Invoice.AllowanceCharges[0].MultiplierFactorNumeric := 10;
  end
  else if AID = 'PEPPOL-EN16931-R046' then
  begin
    Line.GrossPriceAmount := 110;
    Line.DiscountOnTheGrossPrice := 5;
  end
  else if AID = 'PEPPOL-EN16931-R053' then
    Invoice.TaxAmountSubtotals.Clear
  else if AID = 'PEPPOL-EN16931-R054' then
    Invoice.TaxCurrencyCode := 'USD'
  else if AID = 'PEPPOL-EN16931-R055' then
  begin
    Invoice.TaxCurrencyCode := 'USD';
    Invoice.TaxAmountTotalInTaxCurrency.SetValue(-20);
  end
  else if AID = 'PEPPOL-EN16931-R110' then
  begin
    Invoice.InvoicePeriodStartDate := EncodeDate(2026, 10, 5);
    Line.InvoiceLinePeriodStartDate := EncodeDate(2026, 10, 1);
  end
  else if AID = 'PEPPOL-EN16931-R111' then
  begin
    Invoice.InvoicePeriodEndDate := EncodeDate(2026, 10, 10);
    Line.InvoiceLinePeriodEndDate := EncodeDate(2026, 10, 11);
  end
  else if AID = 'PEPPOL-EN16931-R120' then
    Line.LineAmount := 99
  else if AID = 'PEPPOL-EN16931-R121' then
    Line.BaseQuantity := -1
  else if AID = 'PEPPOL-EN16931-R130' then
  begin
    Line.BaseQuantity := 1;
    Line.BaseQuantityUnitCodeOther := 'KGM';
  end
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
  else if AID = 'BR-CL-01' then
  begin
    Invoice.InvoiceTypeCode := itc_None;
    Invoice.InvoiceTypeCodeOther := '999';
  end
  else if AID = 'BR-CL-03' then
    Invoice.InvoiceCurrencyCode := 'EURO'
  else if AID = 'BR-CL-04' then
    Invoice.InvoiceCurrencyCode := 'eur'
  else if AID = 'BR-CL-05' then
    Invoice.TaxCurrencyCode := 'STN'
  else if AID = 'BR-CL-06' then
    Invoice.TaxPointDateCode := '5'
  else if AID = 'BR-CL-07' then
  begin
    Line.ObjectIdentifier := 'O-1';
    Line.ObjectIdentifierSchemeID := 'XX';
  end
  else if AID = 'BR-CL-08' then
    with Invoice.Notes.AddNote do
    begin
      Content := 'Note';
      SubjectCodeOther := 'X1X';
    end
  else if AID = 'BR-CL-10' then
  begin
    Buyer.GlobalIdentifierSellerBuyer := '4000001000005';
    Buyer.GlobalIdentifierSellerBuyerSchemeID := 'SEPA';
  end
  else if AID = 'BR-CL-11' then
  begin
    Seller.CompanyID := 'HRB 1';
    Seller.CompanyIDSchemeID := 'XX';
  end
  else if AID = 'BR-CL-13' then
    with Line.ItemClassifications.AddItemClassification do
    begin
      ClassCode := '123';
      ListID := 'XX';
    end
  else if AID = 'BR-CL-14' then
    Buyer.Address.CountryCode := 'XX'
  else if AID = 'BR-CL-15' then
    Line.OriginTradeCountry := 'XX'
  else if AID = 'BR-CL-16' then
  begin
    Payment.PaymentMeansCode := ipmc_NotImplemented;
    Payment.PaymentMeansCodeOther := '99';
  end
  else if AID = 'BR-CL-17' then
  begin
    AddAllowanceCharge(Invoice, False, False, True);
    Invoice.AllowanceCharges[0].TaxCategoryOther := 'X';
  end
  else if AID = 'BR-CL-18' then
  begin
    Line.TaxCategory := idtfcc_None;
    Line.TaxCategoryOther := 'X';
  end
  else if AID = 'BR-CL-19' then
  begin
    AddAllowanceCharge(Invoice, False, True, True);
    Invoice.AllowanceCharges[0].ReasonCodeAllowanceOther := '1';
  end
  else if AID = 'BR-CL-20' then
    with Line.AllowanceCharges.AddAllowanceCharge do
    begin
      ChargeIndicator := True;
      Amount := 1;
      ReasonCodeChargeOther := 'XX1';
    end
  else if AID = 'BR-CL-21' then
  begin
    Line.StandardItemIdentifier := '123';
    Line.StandardItemIdentifierSchemeID := '9999';
  end
  else if AID = 'BR-CL-22' then
    Invoice.TaxAmountSubtotals[0].TaxExemptionReasonCode := 'VATEX-XX'
  else if AID = 'BR-CL-23' then
  begin
    Line.BaseQuantity := 1;
    Line.BaseQuantityUnitCodeOther := 'ZZZZ';
  end
  else if AID = 'BR-CL-24' then
  begin
    AddPdf(Invoice, 'A-1', 'a.pdf');
    Invoice.Attachments[0].AttachmentType := iat_application_None;
    Invoice.Attachments[0].AttachmentTypeOther := 'application/zip';
  end
  else if AID = 'BR-CL-25' then
    Seller.ElectronicAddressSellerBuyerSchemeID := 'XX'
  else if AID = 'BR-CL-26' then
  begin
    Invoice.DeliveryInformation.LocationIdentifier := 'L-1';
    Invoice.DeliveryInformation.LocationIdentifierSchemeID := 'XX';
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
  RuleCases: array[0..149] of TRuleCase = (
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
    (ID: 'BR-B-01'; Target: tk_XRUBL; NotApplicable: tk_FXBasicWL),
    (ID: 'BR-B-02'; Target: tk_XRCII; NotApplicable: tk_FXBasicWL),
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
    (ID: 'BR-CO-03'; Target: tk_FXBasicWL; NotApplicable: tk_FXMinimum),
    (ID: 'BR-CO-04'; Target: tk_Peppol; NotApplicable: tk_FXExtended),
    (ID: 'BR-CO-09'; Target: tk_FXMinimum; NotApplicable: tk_None),
    (ID: 'BR-CO-10'; Target: tk_XRUBL; NotApplicable: tk_FXBasicWL),
    (ID: 'BR-CO-11'; Target: tk_FXBasicWL; NotApplicable: tk_FXMinimum),
    (ID: 'BR-CO-12'; Target: tk_XRCII; NotApplicable: tk_FXExtended),
    (ID: 'BR-CO-13'; Target: tk_Peppol; NotApplicable: tk_FXMinimum),
    (ID: 'BR-CO-14'; Target: tk_FXExtended; NotApplicable: tk_FXMinimum),
    (ID: 'BR-CO-15'; Target: tk_FXBasic; NotApplicable: tk_FXExtended),
    (ID: 'BR-CO-16'; Target: tk_FXEN16931; NotApplicable: tk_FXExtended),
    (ID: 'BR-CO-17'; Target: tk_XRCII; NotApplicable: tk_FXExtended),
    (ID: 'BR-CO-18'; Target: tk_XRUBL; NotApplicable: tk_FXMinimum),
    (ID: 'BR-CO-21'; Target: tk_XRCII; NotApplicable: tk_FXMinimum),
    (ID: 'BR-CO-22'; Target: tk_XRUBL; NotApplicable: tk_FXExtended),
    (ID: 'BR-CO-23'; Target: tk_FXExtended; NotApplicable: tk_FXBasicWL),
    (ID: 'BR-CO-24'; Target: tk_Peppol; NotApplicable: tk_FXExtended),
    (ID: 'BR-CO-25'; Target: tk_FXExtended; NotApplicable: tk_FXEN16931),
    (ID: 'BR-CO-26'; Target: tk_FXMinimum; NotApplicable: tk_None),
    (ID: 'BR-FXEXT-CO-04'; Target: tk_FXExtended; NotApplicable: tk_FXEN16931),
    (ID: 'BR-DE-17'; Target: tk_XRUBL; NotApplicable: tk_Peppol),
    (ID: 'UBL-SR-29'; Target: tk_Peppol; NotApplicable: tk_XRCII),
    (ID: 'BR-DE-18'; Target: tk_XRCII; NotApplicable: tk_Peppol),
    (ID: 'BR-DE-19'; Target: tk_XRCII; NotApplicable: tk_Peppol),
    (ID: 'BR-DE-20'; Target: tk_XRUBL; NotApplicable: tk_Peppol),
    (ID: 'BR-DE-27'; Target: tk_XRCII; NotApplicable: tk_Peppol),
    (ID: 'BR-DE-28'; Target: tk_XRUBL; NotApplicable: tk_Peppol),
    (ID: 'BR-51'; Target: tk_XRCII; NotApplicable: tk_FXBasic),
    (ID: 'BR-51'; Target: tk_Peppol; NotApplicable: tk_FXBasic),
    (ID: 'BR-FXEXT-CO-10'; Target: tk_FXExtended; NotApplicable: tk_FXEN16931),
    (ID: 'BR-FXEXT-CO-11'; Target: tk_FXExtended; NotApplicable: tk_XRUBL),
    (ID: 'BR-FXEXT-CO-12'; Target: tk_FXExtended; NotApplicable: tk_XRCII),
    (ID: 'BR-FXEXT-CO-13'; Target: tk_FXExtended; NotApplicable: tk_Peppol),
    (ID: 'BR-FXEXT-CO-15'; Target: tk_FXExtended; NotApplicable: tk_FXBasic),
    (ID: 'BR-FXEXT-CO-16'; Target: tk_FXExtended; NotApplicable: tk_FXBasicWL),
    (ID: 'BR-DEX-09'; Target: tk_XRUBL; NotApplicable: tk_XRCII),
    (ID: 'BR-CL-01'; Target: tk_XRCII; NotApplicable: tk_FXEN16931),
    (ID: 'BR-CL-03'; Target: tk_XRUBL; NotApplicable: tk_FXExtended),
    (ID: 'BR-CL-04'; Target: tk_Peppol; NotApplicable: tk_FXMinimum),
    (ID: 'BR-CL-05'; Target: tk_XRCII; NotApplicable: tk_FXBasic),
    (ID: 'BR-CL-06'; Target: tk_XRUBL; NotApplicable: tk_FXEN16931),
    (ID: 'BR-CL-07'; Target: tk_Peppol; NotApplicable: tk_FXExtended),
    (ID: 'BR-CL-08'; Target: tk_XRCII; NotApplicable: tk_FXBasicWL),
    (ID: 'BR-CL-10'; Target: tk_XRUBL; NotApplicable: tk_FXEN16931),
    (ID: 'BR-CL-11'; Target: tk_XRCII; NotApplicable: tk_FXExtended),
    (ID: 'BR-CL-13'; Target: tk_Peppol; NotApplicable: tk_FXEN16931),
    (ID: 'BR-CL-14'; Target: tk_XRUBL; NotApplicable: tk_FXMinimum),
    (ID: 'BR-CL-15'; Target: tk_XRCII; NotApplicable: tk_FXExtended),
    (ID: 'BR-CL-16'; Target: tk_Peppol; NotApplicable: tk_FXBasicWL),
    (ID: 'BR-CL-17'; Target: tk_XRCII; NotApplicable: tk_FXBasic),
    (ID: 'BR-CL-18'; Target: tk_XRUBL; NotApplicable: tk_FXEN16931),
    (ID: 'BR-CL-19'; Target: tk_Peppol; NotApplicable: tk_FXExtended),
    (ID: 'BR-CL-20'; Target: tk_XRCII; NotApplicable: tk_FXEN16931),
    (ID: 'BR-CL-21'; Target: tk_XRUBL; NotApplicable: tk_FXEN16931),
    (ID: 'BR-CL-21'; Target: tk_Peppol; NotApplicable: tk_FXExtended),
    (ID: 'BR-CL-22'; Target: tk_XRCII; NotApplicable: tk_FXBasicWL),
    (ID: 'BR-CL-23'; Target: tk_XRCII; NotApplicable: tk_FXBasic),
    (ID: 'BR-CL-23'; Target: tk_Peppol; NotApplicable: tk_FXEN16931),
    (ID: 'BR-CL-24'; Target: tk_XRUBL; NotApplicable: tk_FXExtended),
    (ID: 'BR-CL-25'; Target: tk_XRCII; NotApplicable: tk_FXEN16931),
    (ID: 'BR-CL-26'; Target: tk_Peppol; NotApplicable: tk_FXExtended),
    (ID: 'PEPPOL-EN16931-R005'; Target: tk_XRUBL; NotApplicable: tk_FXEN16931),
    (ID: 'PEPPOL-EN16931-R040'; Target: tk_XRCII; NotApplicable: tk_FXExtended),
    (ID: 'PEPPOL-EN16931-R041'; Target: tk_Peppol; NotApplicable: tk_FXBasic),
    (ID: 'PEPPOL-EN16931-R042'; Target: tk_XRUBL; NotApplicable: tk_FXEN16931),
    (ID: 'PEPPOL-EN16931-R046'; Target: tk_XRCII; NotApplicable: tk_FXExtended),
    (ID: 'PEPPOL-EN16931-R053'; Target: tk_Peppol; NotApplicable: tk_XRCII),
    (ID: 'PEPPOL-EN16931-R054'; Target: tk_XRUBL; NotApplicable: tk_FXEN16931),
    (ID: 'PEPPOL-EN16931-R055'; Target: tk_XRCII; NotApplicable: tk_FXExtended),
    (ID: 'PEPPOL-EN16931-R110'; Target: tk_Peppol; NotApplicable: tk_FXBasic),
    (ID: 'PEPPOL-EN16931-R111'; Target: tk_XRUBL; NotApplicable: tk_FXEN16931),
    (ID: 'PEPPOL-EN16931-R120'; Target: tk_Peppol; NotApplicable: tk_FXExtended),
    (ID: 'PEPPOL-EN16931-R120'; Target: tk_XRCII; NotApplicable: tk_FXBasic),
    (ID: 'PEPPOL-EN16931-R121'; Target: tk_XRUBL; NotApplicable: tk_FXEN16931),
    (ID: 'PEPPOL-EN16931-R130'; Target: tk_XRCII; NotApplicable: tk_FXExtended));

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
  Errors: Integer;
begin
  D := TLandrixEInvoiceDiagnostics.Create;
  Invoice := TLandrixInvoice.Create;
  try
    FillComplete(Invoice);
    for K := tk_XRUBL to High(TTargetKind) do
    begin
      D.Clear;
      Errors := LandrixEInvoiceCheckInvoice(Invoice, SpecOf(K), D);
      CheckEquals(0, Errors, 'errors for target ' + IntToStr(Ord(K)) + ': ' + string(D.ToText));
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
  N: Integer;
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
    { the net price of 0 breaks PEPPOL-EN16931-R120, an error in Peppol }
    Invoice.InvoiceLines[0].NetPriceAmount := 100;
    { between German parties DE-R-015 requires BT-10 }
    Invoice.AccountingCustomerParty.Address.CountryCode := 'AT';
    D.Clear;
    N := LandrixEInvoiceCheckInvoice(Invoice, SpecOf(tk_Peppol), D);
    CheckEquals(0, N, 'Peppol: ' + string(D.ToText));
    Invoice.AccountingCustomerParty.Address.CountryCode := 'DE';
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
  with the seller name (BT-27), UBL with the trading name (cac:PartyName)
  and the identifiers it writes (not the one it leaves out beside a global
  identifier). }
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
    Check(not LandrixEInvoiceCheckRule(Invoice, SpecOf(tk_XRUBL), 'BR-17', nil), 'UBL: same seller identifier');
    Invoice.AccountingSupplierParty.GlobalIdentifierSellerBuyer := '4000001000005';
    Check(LandrixEInvoiceCheckRule(Invoice, SpecOf(tk_XRUBL), 'BR-17', nil),
      'UBL: the seller identifier beside a global one is not written');
    Invoice.PayeeParty.Identifier := '4000001000005';
    Check(not LandrixEInvoiceCheckRule(Invoice, SpecOf(tk_XRUBL), 'BR-17', nil), 'UBL: same global identifier');
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
  violates BR-25 there; a UBL cac:SubInvoiceLine is outside the line rules
  but BR-54, whose context //cac:AdditionalItemProperty reaches it. }
procedure TestSubLines;
var
  Invoice: TLandrixInvoice;
  Sub: TLandrixInvoiceLine;
begin
  Invoice := TLandrixInvoice.Create;
  try
    FillComplete(Invoice);
    Sub := Invoice.InvoiceLines[0].SubInvoiceLines.AddInvoiceLine;
    Sub.ID := '1.1';
    Check(not LandrixEInvoiceCheckRule(Invoice, SpecOf(tk_XRCII), 'BR-25', nil), 'CII sub line without name');
    Check(LandrixEInvoiceCheckRule(Invoice, SpecOf(tk_XRUBL), 'BR-25', nil), 'UBL sub line not checked');
    Sub.ItemAttributes.AddItemAttribute.Name := 'Colour';
    Check(not LandrixEInvoiceCheckRule(Invoice, SpecOf(tk_XRUBL), 'BR-54', nil), 'UBL sub line attribute without value');
    Check(not LandrixEInvoiceCheckRule(Invoice, SpecOf(tk_XRCII), 'BR-54', nil), 'CII sub line attribute without value');
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
      { the name is allowed in EXTENDED; the code list of EXTENDED rejects the
        BT-24 of BASIC }
      D.Clear;
      CheckEquals(1, LandrixEInvoiceCheckCII(CII, SpecOf(tk_FXExtended), D), 'EXTENDED: ' + string(D.ToText));
      CheckEquals(0, D.CountOf(edk_NotAllowed), 'name allowed in EXTENDED');
      Check(HasRule(D, 'FX-SCH-A-000636'), 'BT-24 of BASIC in EXTENDED');
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

{ UBL-SR-29 counts the SEPA identifiers the UBL writer produces: the
  prediction is compared with the written syntax model. }
function SEPACount(AList: TLandrixUBLPartyIdentificationList): Integer;
var
  I: TLandrixEInvoiceListIndex;
begin
  Result := 0;
  for I := 0 to AList.Count - 1 do
    if UpperCase(string(AList[I].ID.SchemeID)) = 'SEPA' then
      Inc(Result);
end;

procedure TestSEPAIdentifiers;
var
  Invoice: TLandrixInvoice;
  UBL: TLandrixUBLInvoice;
  CaseNo, Count: Integer;
begin
  for CaseNo := 1 to 6 do
  begin
    Invoice := TLandrixInvoice.Create;
    try
      FillComplete(Invoice);
      Invoice.AccountingSupplierParty.BankAssignedCreditorIdentifier := 'DE98ZZZ09999999999';
      case CaseNo of
        2:
          Invoice.PayeeParty.Name := 'Payee';
        3:
          begin
            Invoice.PayeeParty.Name := 'Payee';
            Invoice.PayeeParty.Identifier := 'DE98ZZZ09999999999';
            Invoice.PayeeParty.IdentifierSchemeID := 'sepa';
          end;
        4:
          begin
            Invoice.AccountingSupplierParty.GlobalIdentifierSellerBuyer := 'DE11ZZZ00000000001';
            Invoice.AccountingSupplierParty.GlobalIdentifierSellerBuyerSchemeID := 'SEPA';
          end;
        5:
          begin
            Invoice.AccountingSupplierParty.BankAssignedCreditorIdentifier := '';
            Invoice.AccountingCustomerParty.GlobalIdentifierSellerBuyer := 'DE11ZZZ00000000001';
            Invoice.AccountingCustomerParty.GlobalIdentifierSellerBuyerSchemeID := 'Sepa';
          end;
        6:
          begin
            Invoice.PayeeParty.Identifier := 'DE98ZZZ09999999999';
            Invoice.PayeeParty.IdentifierSchemeID := ' SEPA';
          end;
      end;
      UBL := LandrixEInvoiceInvoiceToUBLInvoice(Invoice, SpecOf(tk_XRUBL), nil);
      try
        Count := SEPACount(UBL.AccountingSupplierParty.Party.PartyIdentification) +
          SEPACount(UBL.AccountingCustomerParty.Party.PartyIdentification) +
          SEPACount(UBL.PayeeParty.PartyIdentification);
      finally
        UBL.Free;
      end;
      Check((Count <= 1) = LandrixEInvoiceCheckRule(Invoice, SpecOf(tk_XRUBL), 'UBL-SR-29', nil),
        'variant ' + IntToStr(CaseNo) + ', ' + IntToStr(Count) + ' written');
      Check((CaseNo in [3, 4]) = (Count > 1), 'variant ' + IntToStr(CaseNo) + ' count');
      if CaseNo = 3 then
        Check(not LandrixEInvoiceCheckRule(Invoice, SpecOf(tk_XRUBL), 'BR-CL-10', nil), 'lower case scheme sepa');
    finally
      Invoice.Free;
    end;
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

{ A date no writer can write (NaN, outside 0001-9999) is one error of its
  own, the rules that need it are skipped, nothing raises (Trunc of 1e300
  would); a date the writers leave out (0 or below) is not reported, a NaN
  always is and stops every rule. }
procedure TestUnwritableDates;
var
  Invoice: TLandrixInvoice;
  D: TLandrixEInvoiceDiagnostics;
  Huge, NaN: Double;
  K: TTargetKind;
  I: Integer;
begin
  Huge := 1;
  for I := 1 to 300 do
    Huge := Huge * 10;
  PInt64(@NaN)^ := $7FF8000000000000;
  D := TLandrixEInvoiceDiagnostics.Create;
  Invoice := TLandrixInvoice.Create;
  try
    FillComplete(Invoice);
    Invoice.InvoiceDueDate := Huge;
    Invoice.TaxPointDate.SetValue(EncodeDate(1, 1, 1) - 1);
    Invoice.InvoicePeriodStartDate := Huge;
    Invoice.InvoicePeriodEndDate := EncodeDate(2026, 10, 31);
    Invoice.InvoiceLines[0].InvoiceLinePeriodStartDate := EncodeDate(2026, 10, 1);
    Invoice.InvoiceLines[0].InvoiceLinePeriodEndDate := EncodeDate(9999, 12, 31) + 1;
    Invoice.DeliveryReceiptDate := -Huge;
    { without its number the writers leave a delivery note date out }
    Invoice.DeliveryReceiptDateExtended := Huge;
    Invoice.InvoiceLines[0].DeliveryNoteDate := Huge;
    for K := tk_XRUBL to High(TTargetKind) do
    begin
      D.Clear;
      CheckEquals(4, LandrixEInvoiceCheckInvoice(Invoice, SpecOf(K), D), 'unwritable dates: four errors, target ' +
        IntToStr(Ord(K)) + ': ' + string(D.ToText));
      CheckEquals(4, D.CountOf(edk_ConversionFailed), 'unwritable dates reported, target ' + IntToStr(Ord(K)));
    end;
    D.Clear;
    LandrixEInvoiceCheckInvoice(Invoice, SpecOf(tk_XRUBL), D);
    CheckEqualsInvoiceStr('BT-9', D[0].Path, 'due date: business term');
    CheckEqualsInvoiceStr('BT-7', D[1].Path, 'VAT point date: business term');
    CheckEqualsInvoiceStr('BT-73', D[2].Path, 'period start: business term');
    CheckEqualsInvoiceStr('BT-135', D[3].Path, 'line period end: business term');
    Check(D[0].Severity = eds_Error, 'an error');
    Check(LandrixEInvoiceCheckRule(Invoice, SpecOf(tk_XRUBL), 'BR-29', nil), 'BR-29 skipped');
    Check(LandrixEInvoiceCheckRule(Invoice, SpecOf(tk_XRUBL), 'BR-30', nil), 'BR-30 skipped');
    Check(LandrixEInvoiceCheckRule(Invoice, SpecOf(tk_XRUBL), 'PEPPOL-EN16931-R110', nil), 'R110 skipped');
    Check(LandrixEInvoiceCheckRule(Invoice, SpecOf(tk_XRUBL), 'PEPPOL-EN16931-R111', nil), 'R111 skipped');
  finally
    Invoice.Free;
  end;
  Invoice := TLandrixInvoice.Create;
  try
    FillComplete(Invoice);
    Invoice.InvoiceIssueDate := NaN;
    Invoice.DeliveryReceiptDate := NaN;
    for K := tk_XRUBL to High(TTargetKind) do
    begin
      D.Clear;
      CheckEquals(2, LandrixEInvoiceCheckInvoice(Invoice, SpecOf(K), D), 'NaN dates: two errors, no rule, target ' +
        IntToStr(Ord(K)) + ': ' + string(D.ToText));
    end;
    CheckEqualsInvoiceStr('BT-2', D[0].Path, 'invoice date: business term');
    CheckEqualsInvoiceStr('BT-X-200', D[1].Path, 'despatch advice date: business term');
    Check(LandrixEInvoiceCheckRule(Invoice, SpecOf(tk_XRUBL), 'BR-03', nil), 'BR-03 skipped');
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

{ A number no writer can write (NaN, infinite, 1e23 and above) is one
  error of its own, the rules that need it are skipped, nothing raises; a
  VAT rate is compared exactly at any size (no silent 0 above the Currency
  range, no Int64 overflow of taxable amount x rate). }
procedure TestUnwritableNumbers;
var
  Invoice: TLandrixInvoice;
  D: TLandrixEInvoiceDiagnostics;
  Big, NaN: Double;
  K: TTargetKind;
  I: Integer;
begin
  Big := 1;
  for I := 1 to 24 do
    Big := Big * 10;
  PInt64(@NaN)^ := $7FF8000000000000;
  D := TLandrixEInvoiceDiagnostics.Create;
  Invoice := TLandrixInvoice.Create;
  try
    FillComplete(Invoice);
    Invoice.InvoiceLines[0].TaxPercent := Big;
    Invoice.TaxAmountSubtotals[0].TaxPercent := Big;
    for K := tk_XRUBL to High(TTargetKind) do
    begin
      D.Clear;
      CheckEquals(2, LandrixEInvoiceCheckInvoice(Invoice, SpecOf(K), D), 'huge rates: two errors, target ' +
        IntToStr(Ord(K)) + ': ' + string(D.ToText));
      CheckEquals(2, D.CountOf(edk_ConversionFailed), 'huge rates reported, target ' + IntToStr(Ord(K)));
    end;
    D.Clear;
    LandrixEInvoiceCheckInvoice(Invoice, SpecOf(tk_XRUBL), D);
    CheckEqualsInvoiceStr('BT-152', D[0].Path, 'line rate: business term');
    CheckEqualsInvoiceStr('BT-119', D[1].Path, 'breakdown rate: business term');
    Check(D[0].Severity = eds_Error, 'an error');
    Check(LandrixEInvoiceCheckRule(Invoice, SpecOf(tk_XRUBL), 'BR-S-05', nil), 'BR-S-05 skipped');
    Check(LandrixEInvoiceCheckRule(Invoice, SpecOf(tk_XRUBL), 'BR-CO-17', nil), 'BR-CO-17 skipped');
  finally
    Invoice.Free;
  end;
  Invoice := TLandrixInvoice.Create;
  try
    FillComplete(Invoice);
    Invoice.InvoiceLines[0].Quantity := NaN;
    Invoice.InvoiceLines[0].NetPriceAmount := NaN;
    Invoice.InvoiceLines[0].BaseQuantity := Big;
    Invoice.PaymentTermsType := iptt_CashDiscount1;
    Invoice.PaymentTermCashDiscount1Percent := -Big;
    for K := tk_XRUBL to High(TTargetKind) do
    begin
      D.Clear;
      CheckEquals(4, LandrixEInvoiceCheckInvoice(Invoice, SpecOf(K), D), 'NaN and huge: four errors, target ' +
        IntToStr(Ord(K)) + ': ' + string(D.ToText));
    end;
    CheckEqualsInvoiceStr('BT-129', D[0].Path, 'quantity: business term');
    CheckEqualsInvoiceStr('BT-20', D[3].Path, 'cash discount: business term');
  finally
    Invoice.Free;
  end;
  { a huge cash discount percentage alone (no NaN): the rules run, those
    with the payment terms text (BR-DE-18, BR-CO-25, DE-R-018) hold }
  Invoice := TLandrixInvoice.Create;
  try
    FillComplete(Invoice);
    Invoice.PaymentTermsType := iptt_CashDiscount1;
    Invoice.PaymentTermCashDiscount1Days := 10;
    Invoice.PaymentTermCashDiscount1Percent := Big;
    for K := tk_XRUBL to High(TTargetKind) do
    begin
      D.Clear;
      LandrixEInvoiceCheckInvoice(Invoice, SpecOf(K), D);
      CheckEquals(1, D.CountOf(edk_ConversionFailed), 'huge cash discount, target ' + IntToStr(Ord(K)) + ': ' +
        string(D.ToText));
    end;
    Check(LandrixEInvoiceCheckRule(Invoice, SpecOf(tk_XRUBL), 'BR-DE-18', nil), 'BR-DE-18 holds');
    Check(LandrixEInvoiceCheckRule(Invoice, SpecOf(tk_XRUBL), 'BR-CO-25', nil), 'BR-CO-25 holds');
  finally
    Invoice.Free;
  end;
  { numbers the writers do not write are not reported: the rate of a
    category O line, a cash discount level beyond PaymentTermsType, a price
    discount without gross price }
  Invoice := TLandrixInvoice.Create;
  try
    FillComplete(Invoice);
    Invoice.InvoiceLines[0].TaxCategory := idtfcc_O_ServicesOutsideScopeOfTax;
    Invoice.InvoiceLines[0].TaxPercent := NaN;
    Invoice.PaymentTermsType := iptt_CashDiscount1;
    Invoice.PaymentTermCashDiscount2Percent := NaN;
    Invoice.InvoiceLines[0].GrossPriceAmount := 0;
    Invoice.InvoiceLines[0].DiscountOnTheGrossPrice := NaN;
    for K := tk_XRUBL to High(TTargetKind) do
    begin
      D.Clear;
      LandrixEInvoiceCheckInvoice(Invoice, SpecOf(K), D);
      CheckEquals(0, D.CountOf(edk_ConversionFailed), 'not written, not reported, target ' + IntToStr(Ord(K)) +
        ': ' + string(D.ToText));
    end;
  finally
    Invoice.Free;
  end;
  { rates the Currency type cannot hold: exact, BR-S-05 and BR-S-09 hold }
  Invoice := TLandrixInvoice.Create;
  try
    FillComplete(Invoice);
    Big := 1;
    for I := 1 to 15 do
      Big := Big * 10;
    Invoice.InvoiceLines[0].TaxPercent := Big;
    Invoice.TaxAmountSubtotals[0].TaxPercent := Big;
    Invoice.TaxAmountSubtotals[0].TaxableAmount := CentsValue(1);
    Invoice.TaxAmountSubtotals[0].TaxAmount := 100000000000;
    Check(LandrixEInvoiceCheckRule(Invoice, SpecOf(tk_XRUBL), 'BR-S-05', nil), 'BR-S-05 with rate 1e15');
    Check(LandrixEInvoiceCheckRule(Invoice, SpecOf(tk_XRUBL), 'BR-S-09', nil), 'BR-S-09 with rate 1e15');
    Invoice.TaxAmountSubtotals[0].TaxAmount := 100000000002;
    Check(not LandrixEInvoiceCheckRule(Invoice, SpecOf(tk_XRUBL), 'BR-S-09', nil), 'BR-S-09 off by 2');
    { taxable amount x rate beyond Int64 }
    Invoice.InvoiceLines[0].TaxPercent := 19;
    Invoice.TaxAmountSubtotals[0].TaxPercent := 19;
    Invoice.TaxAmountSubtotals[0].TaxableAmount := 900000000000000;
    Invoice.TaxAmountSubtotals[0].TaxAmount := 171000000000000;
    Check(LandrixEInvoiceCheckRule(Invoice, SpecOf(tk_XRUBL), 'BR-S-09', nil), 'BR-S-09 with 9e14');
    Invoice.TaxAmountSubtotals[0].TaxAmount := 171000000000001;
    Check(not LandrixEInvoiceCheckRule(Invoice, SpecOf(tk_XRUBL), 'BR-S-09', nil), 'BR-S-09 with 9e14, off by 1');
    { the rounding edge: 0.10 at 5 % is 0.005, rounded half up 0.01; 0.09
      is 0.0045, rounded 0.00 }
    Invoice.TaxAmountSubtotals[0].TaxPercent := 5;
    Invoice.InvoiceLines[0].TaxPercent := 5;
    Invoice.TaxAmountSubtotals[0].TaxableAmount := CentsValue(10);
    Invoice.TaxAmountSubtotals[0].TaxAmount := 1;
    Check(LandrixEInvoiceCheckRule(Invoice, SpecOf(tk_XRUBL), 'BR-S-09', nil), 'BR-S-09 1.00 for 0.01');
    Check(LandrixEInvoiceCheckRule(Invoice, SpecOf(tk_XRUBL), 'BR-CO-17', nil), 'BR-CO-17 UBL 1.00 for 0.01');
    Invoice.TaxAmountSubtotals[0].TaxAmount := CentsValue(101);
    Check(not LandrixEInvoiceCheckRule(Invoice, SpecOf(tk_XRUBL), 'BR-S-09', nil), 'BR-S-09 1.01 for 0.01');
    Check(LandrixEInvoiceCheckRule(Invoice, SpecOf(tk_XRCII), 'BR-CO-17', nil), 'BR-CO-17 CII 1.01 for 0.01');
    Invoice.TaxAmountSubtotals[0].TaxAmount := CentsValue(102);
    Check(not LandrixEInvoiceCheckRule(Invoice, SpecOf(tk_XRCII), 'BR-CO-17', nil), 'BR-CO-17 CII 1.02 for 0.01');
    Invoice.TaxAmountSubtotals[0].TaxableAmount := CentsValue(9);
    Invoice.TaxAmountSubtotals[0].TaxAmount := 1;
    Check(not LandrixEInvoiceCheckRule(Invoice, SpecOf(tk_XRUBL), 'BR-S-09', nil), 'BR-S-09 1.00 for 0.00');
    Check(not LandrixEInvoiceCheckRule(Invoice, SpecOf(tk_XRUBL), 'BR-CO-17', nil), 'BR-CO-17 UBL 1.00 for 0.00');
    Check(LandrixEInvoiceCheckRule(Invoice, SpecOf(tk_XRCII), 'BR-CO-17', nil), 'BR-CO-17 CII 1.00 for 0.00');
    { a rate of -0.5 rounds to 0 (XPath round: half up), -0.51 does not }
    Invoice.TaxAmountSubtotals[0].TaxPercent := -0.5;
    Invoice.TaxAmountSubtotals[0].TaxableAmount := 100;
    Invoice.TaxAmountSubtotals[0].TaxAmount := CentsValue(49);
    Check(LandrixEInvoiceCheckRule(Invoice, SpecOf(tk_XRUBL), 'BR-CO-17', nil), 'BR-CO-17 rate -0.5 rounds to 0');
    Invoice.TaxAmountSubtotals[0].TaxPercent := -51 / 100;
    Check(not LandrixEInvoiceCheckRule(Invoice, SpecOf(tk_XRUBL), 'BR-CO-17', nil), 'BR-CO-17 rate -0.51: 0.49 for -0.51');
    Invoice.TaxAmountSubtotals[0].TaxAmount := CentsValue(48);
    Check(LandrixEInvoiceCheckRule(Invoice, SpecOf(tk_XRUBL), 'BR-CO-17', nil), 'BR-CO-17 rate -0.51: 0.48 for -0.51');
    Invoice.TaxAmountSubtotals[0].TaxAmount := CentsValue(151);
    Check(not LandrixEInvoiceCheckRule(Invoice, SpecOf(tk_XRUBL), 'BR-CO-17', nil), 'BR-CO-17 rate -0.51: 1.51 for -0.51');
  finally
    Invoice.Free;
    D.Free;
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

type
  TVatGroupCase = record
    Group: string;
    Category: TLandrixInvoiceDutyTaxFeeCategoryCode;
    Rate: Integer;
    Last: Integer;
    { the rate that breaks BR-xx-05 to 07 }
    WrongRate: Integer;
  end;

const
  VatGroupCases: array[0..8] of TVatGroupCase = (
    (Group: 'S'; Category: idtfcc_S_StandardRate; Rate: 19; Last: 10; WrongRate: 0),
    (Group: 'Z'; Category: idtfcc_Z_ZeroRatedGoods; Rate: 0; Last: 10; WrongRate: 5),
    (Group: 'E'; Category: idtfcc_E_ExemptFromTax; Rate: 0; Last: 10; WrongRate: 5),
    (Group: 'AE'; Category: idtfcc_AE_VATReverseCharge; Rate: 0; Last: 10; WrongRate: 5),
    (Group: 'IC'; Category: idtfcc_K_VATExemptForEEAIntracommunitySupplyOfGoodsAndServices; Rate: 0; Last: 12;
     WrongRate: 5),
    (Group: 'G'; Category: idtfcc_G_FreeExportItemTaxNotCharged; Rate: 0; Last: 10; WrongRate: 5),
    (Group: 'O'; Category: idtfcc_O_ServicesOutsideScopeOfTax; Rate: 0; Last: 14; WrongRate: 0),
    (Group: 'AF'; Category: idtfcc_L_CanaryIslandsGeneralIndirectTax; Rate: 7; Last: 10; WrongRate: -1),
    (Group: 'AG'; Category: idtfcc_M_TaxForProductionServicesAndImportationInCeutaAndMelilla; Rate: 4; Last: 10;
     WrongRate: -1));

function VatRuleOf(const ACase: TVatGroupCase; ANumber: Integer): string;
begin
  Result := 'BR-' + ACase.Group + '-' + IntToStr(ANumber div 10) + IntToStr(ANumber mod 10);
end;

function IsExemptGroup(const ACase: TVatGroupCase): Boolean;
begin
  Result := (ACase.Group = 'E') or (ACase.Group = 'AE') or (ACase.Group = 'IC') or (ACase.Group = 'G') or
    (ACase.Group = 'O');
end;

{ A complete invoice with one line and one VAT breakdown of the group: the
  identifiers the group needs, an exemption reason where it needs one and
  the delivery data of an intra-community supply. }
procedure FillVatGroup(Invoice: TLandrixInvoice; const ACase: TVatGroupCase);
var
  Tax: TLandrixInvoiceTaxAmount;
  Line: TLandrixInvoiceLine;
begin
  FillComplete(Invoice);
  Line := Invoice.InvoiceLines[0];
  Line.TaxCategory := ACase.Category;
  Line.TaxPercent := ACase.Rate;
  Tax := Invoice.TaxAmountSubtotals[0];
  Tax.TaxCategory := ACase.Category;
  Tax.TaxPercent := ACase.Rate;
  Tax.TaxAmount := ACase.Rate;
  if IsExemptGroup(ACase) then
    Tax.TaxExemptionReason := 'Reason';
  Invoice.TaxAmountTotal := ACase.Rate;
  Invoice.TaxInclusiveAmount := 100 + ACase.Rate;
  Invoice.PayableAmount := 100 + ACase.Rate;
  if ACase.Group = 'O' then
  begin
    Invoice.AccountingSupplierParty.VATCompanyID := '';
    Invoice.AccountingSupplierParty.VATCompanyNumber := '12/345/67890';
  end;
  if (ACase.Group = 'AE') or (ACase.Group = 'IC') then
    Invoice.AccountingCustomerParty.VATCompanyID := 'FR12345678901';
  if ACase.Group = 'IC' then
  begin
    Invoice.DeliveryInformation.ActualDeliveryDate := EncodeDate(2026, 10, 19);
    Invoice.DeliveryInformation.Address.City := 'Paris';
    Invoice.DeliveryInformation.Address.PostalZone := '75001';
    Invoice.DeliveryInformation.Address.CountryCode := 'FR';
  end;
end;

procedure AddVatAllowanceCharge(Invoice: TLandrixInvoice; ACharge: Boolean;
  ACategory: TLandrixInvoiceDutyTaxFeeCategoryCode; ARate: Integer);
var
  Item: TLandrixInvoiceAllowanceCharge;
begin
  Item := Invoice.AllowanceCharges.AddAllowanceCharge;
  Item.ChargeIndicator := ACharge;
  Item.Amount := 5;
  Item.Reason := 'Reason';
  Item.TaxCategory := ACategory;
  Item.TaxPercent := ARate;
end;

{ Breaks rule ANumber of the group in an invoice of FillVatGroup. }
procedure MutateVat(Invoice: TLandrixInvoice; const ACase: TVatGroupCase; ANumber: Integer);
var
  Tax: TLandrixInvoiceTaxAmount;
  Line: TLandrixInvoiceLine;
begin
  Tax := Invoice.TaxAmountSubtotals[0];
  Line := Invoice.InvoiceLines[0];
  if ANumber in [3, 6] then
    AddVatAllowanceCharge(Invoice, False, ACase.Category, ACase.Rate)
  else if ANumber in [4, 7] then
    AddVatAllowanceCharge(Invoice, True, ACase.Category, ACase.Rate);
  case ANumber of
    1:
      { a second breakdown of the category (S, AF, AG: none) }
      if (ACase.Group = 'S') or (ACase.Group = 'AF') or (ACase.Group = 'AG') then
        Invoice.TaxAmountSubtotals.Clear
      else
        Invoice.TaxAmountSubtotals.AddTaxAmount.Assign(Tax);
    2, 3, 4:
      if ACase.Group = 'O' then
        Invoice.AccountingCustomerParty.VATCompanyID := 'FR12345678901'
      else
      begin
        Invoice.AccountingSupplierParty.VATCompanyID := '';
        if (ACase.Group = 'G') or (ACase.Group = 'IC') then
          Invoice.AccountingSupplierParty.VATCompanyNumber := '12/345/67890';
      end;
    5, 6, 7:
      if ACase.Group = 'O' then
      begin
        { the rate is written when the category is no enumeration value }
        Line.TaxCategory := idtfcc_None;
        Line.TaxCategoryOther := 'O';
        if ANumber > 5 then
        begin
          Invoice.AllowanceCharges[0].TaxCategory := idtfcc_None;
          Invoice.AllowanceCharges[0].TaxCategoryOther := 'O';
        end;
      end
      else if ANumber = 5 then
        Line.TaxPercent := ACase.WrongRate
      else
        Invoice.AllowanceCharges[0].TaxPercent := ACase.WrongRate;
    8:
      Tax.TaxableAmount := 102;
    9:
      Tax.TaxAmount := ACase.Rate + 2;
    10:
      if IsExemptGroup(ACase) then
        Tax.TaxExemptionReason := ' '
      else
        Tax.TaxExemptionReasonCode := 'VATEX-EU-79-C';
    11:
      if ACase.Group = 'IC' then
        Invoice.DeliveryInformation.ActualDeliveryDate := 0
      else
        with Invoice.TaxAmountSubtotals.AddTaxAmount do
        begin
          TaxCategory := idtfcc_S_StandardRate;
          TaxPercent := 19;
        end;
    12:
      if ACase.Group = 'IC' then
        Invoice.DeliveryInformation.Address.CountryCode := ' '
      else
        with Invoice.InvoiceLines.AddInvoiceLine do
        begin
          ID := '2';
          Name := 'Item';
          TaxCategory := idtfcc_S_StandardRate;
          TaxPercent := 19;
        end;
    13:
      AddVatAllowanceCharge(Invoice, False, idtfcc_S_StandardRate, 19);
    14:
      AddVatAllowanceCharge(Invoice, True, idtfcc_S_StandardRate, 19);
  end;
end;

function HasVatGroupRule(D: TLandrixEInvoiceDiagnostics; const AGroup: string): Boolean;
var
  I: TLandrixEInvoiceListIndex;
begin
  Result := True;
  for I := 0 to D.Count - 1 do
    if Pos('BR-' + AGroup + '-', string(D[I].RuleID)) = 1 then
      Exit;
  Result := False;
end;

{ The VAT category rules BR-S-nn to BR-AG-nn: the invoice of each group
  passes them for every target; each rule breaks for XRechnung UBL and CII
  (except BR-AF-09 and BR-AG-09, which CII does not test) and does not apply
  to Factur-X MINIMUM; BR-FXEXT-xx-01 applies to EXTENDED only. }
procedure TestVatCategories;
var
  Invoice: TLandrixInvoice;
  D: TLandrixEInvoiceDiagnostics;
  G, N: Integer;
  K: TTargetKind;
  ID: string;
begin
  D := TLandrixEInvoiceDiagnostics.Create;
  try
    for G := Low(VatGroupCases) to High(VatGroupCases) do
    begin
      Invoice := TLandrixInvoice.Create;
      try
        FillVatGroup(Invoice, VatGroupCases[G]);
        for K := tk_XRUBL to High(TTargetKind) do
        begin
          D.Clear;
          LandrixEInvoiceCheckInvoice(Invoice, SpecOf(K), D);
          Check(not HasVatGroupRule(D, VatGroupCases[G].Group) and
            not HasRule(D, 'BR-FXEXT-' + VatGroupCases[G].Group + '-01'), VatGroupCases[G].Group +
            ' passes target ' + IntToStr(Ord(K)) + ': ' + string(D.ToText));
        end;
        { BR-FXEXT-xx-01: EXTENDED only, a use without breakdown }
        ID := 'BR-FXEXT-' + VatGroupCases[G].Group + '-01';
        Invoice.TaxAmountSubtotals.Clear;
        Check(not LandrixEInvoiceCheckRule(Invoice, SpecOf(tk_FXExtended), TLandrixEInvoiceString(ID), nil),
          ID + ' violated');
        Check(LandrixEInvoiceCheckRule(Invoice, SpecOf(tk_FXEN16931), TLandrixEInvoiceString(ID), nil),
          ID + ' only in EXTENDED');
      finally
        Invoice.Free;
      end;
      for N := 1 to VatGroupCases[G].Last do
      begin
        ID := VatRuleOf(VatGroupCases[G], N);
        Invoice := TLandrixInvoice.Create;
        try
          FillVatGroup(Invoice, VatGroupCases[G]);
          MutateVat(Invoice, VatGroupCases[G], N);
          D.Clear;
          Check(not LandrixEInvoiceCheckRule(Invoice, SpecOf(tk_XRUBL), TLandrixEInvoiceString(ID), D),
            ID + ' violated in UBL');
          if D.Count = 1 then
            CheckEqualsInvoiceStr(TLandrixEInvoiceString(ID), D[0].RuleID, ID + ' rule of the diagnostic');
          if ((VatGroupCases[G].Group = 'AF') or (VatGroupCases[G].Group = 'AG')) and (N = 9) then
            Check(LandrixEInvoiceCheckRule(Invoice, SpecOf(tk_XRCII), TLandrixEInvoiceString(ID), nil),
              ID + ' not tested in CII')
          else
            Check(not LandrixEInvoiceCheckRule(Invoice, SpecOf(tk_XRCII), TLandrixEInvoiceString(ID), nil),
              ID + ' violated in CII');
          D.Clear;
          LandrixEInvoiceCheckInvoice(Invoice, SpecOf(tk_XRUBL), D);
          Check(HasRule(D, ID), ID + ' reported by LandrixEInvoiceCheckInvoice');
          Check(LandrixEInvoiceCheckRule(Invoice, SpecOf(tk_FXMinimum), TLandrixEInvoiceString(ID), nil),
            ID + ' does not apply to MINIMUM');
        finally
          Invoice.Free;
        end;
      end;
    end;
  finally
    D.Free;
  end;
end;

{ Where the syntaxes differ: BR-xx-08 allows a difference below 1 in UBL
  for S (by rate) and in CII for the other groups; BR-xx-01 in CII counts
  two standard rated lines as enough; BR-AF-05 needs a rate above 0 in CII
  only; BR-O-11 in CII also sees the lines; the profiles of Factur-X. }
procedure TestVatSyntaxes;
var
  Invoice: TLandrixInvoice;
begin
  Invoice := TLandrixInvoice.Create;
  try
    FillVatGroup(Invoice, VatGroupCases[0]);
    Invoice.TaxAmountSubtotals[0].TaxableAmount := CentsValue(10099);
    Check(LandrixEInvoiceCheckRule(Invoice, SpecOf(tk_XRUBL), 'BR-S-08', nil), 'UBL S: 0.99 tolerated');
    Check(not LandrixEInvoiceCheckRule(Invoice, SpecOf(tk_XRCII), 'BR-S-08', nil), 'CII S: exact');
    { a breakdown of 0.00 at 7 %: UBL wants a line or allowance of that rate,
      CII only the sum }
    Invoice.TaxAmountSubtotals[0].TaxableAmount := 0;
    Invoice.TaxAmountSubtotals[0].TaxAmount := 0;
    Invoice.TaxAmountSubtotals[0].TaxPercent := 7;
    Check(not LandrixEInvoiceCheckRule(Invoice, SpecOf(tk_XRUBL), 'BR-S-08', nil), 'UBL S: no line of the rate');
    Check(LandrixEInvoiceCheckRule(Invoice, SpecOf(tk_XRCII), 'BR-S-08', nil), 'CII S: the sum 0 matches');
    Invoice.TaxAmountSubtotals.Clear;
    Invoice.InvoiceLines.AddInvoiceLine.Assign(Invoice.InvoiceLines[0]);
    Check(LandrixEInvoiceCheckRule(Invoice, SpecOf(tk_XRCII), 'BR-S-01', nil), 'CII S: two lines count');
    Check(not LandrixEInvoiceCheckRule(Invoice, SpecOf(tk_XRUBL), 'BR-S-01', nil), 'UBL S: breakdown missing');
  finally
    Invoice.Free;
  end;
  Invoice := TLandrixInvoice.Create;
  try
    FillVatGroup(Invoice, VatGroupCases[1]);
    Invoice.TaxAmountSubtotals[0].TaxableAmount := CentsValue(10099);
    Check(not LandrixEInvoiceCheckRule(Invoice, SpecOf(tk_XRUBL), 'BR-Z-08', nil), 'UBL Z: exact');
    Check(LandrixEInvoiceCheckRule(Invoice, SpecOf(tk_XRCII), 'BR-Z-08', nil), 'CII Z: 0.99 tolerated');
    { 1.00 above the lines: the CEN schematron is strict, Factur-X inclusive
      below the taxable amount }
    Invoice.TaxAmountSubtotals[0].TaxableAmount := 101;
    Check(not LandrixEInvoiceCheckRule(Invoice, SpecOf(tk_XRCII), 'BR-Z-08', nil), 'CEN CII Z: 1.00 above');
    Check(LandrixEInvoiceCheckRule(Invoice, SpecOf(tk_FXEN16931), 'BR-Z-08', nil), 'Factur-X Z: 1.00 above');
    Invoice.TaxAmountSubtotals[0].TaxableAmount := 99;
    Check(not LandrixEInvoiceCheckRule(Invoice, SpecOf(tk_FXEN16931), 'BR-Z-08', nil), 'Factur-X Z: 1.00 below');
    { UBL needs an invoice line for the breakdown }
    Invoice.TaxAmountSubtotals[0].TaxableAmount := 0;
    Invoice.InvoiceLines.Clear;
    Check(not LandrixEInvoiceCheckRule(Invoice, SpecOf(tk_XRUBL), 'BR-Z-08', nil), 'UBL Z without lines');
    Check(LandrixEInvoiceCheckRule(Invoice, SpecOf(tk_XRCII), 'BR-Z-08', nil), 'CII Z without lines');
  finally
    Invoice.Free;
  end;
  Invoice := TLandrixInvoice.Create;
  try
    FillVatGroup(Invoice, VatGroupCases[7]);
    Invoice.InvoiceLines[0].TaxPercent := 0;
    Check(LandrixEInvoiceCheckRule(Invoice, SpecOf(tk_XRUBL), 'BR-AF-05', nil), 'UBL AF: rate 0');
    Check(not LandrixEInvoiceCheckRule(Invoice, SpecOf(tk_XRCII), 'BR-AF-05', nil), 'CII AF: rate 0');
  finally
    Invoice.Free;
  end;
  Invoice := TLandrixInvoice.Create;
  try
    FillVatGroup(Invoice, VatGroupCases[6]);
    MutateVat(Invoice, VatGroupCases[6], 12);
    Check(not LandrixEInvoiceCheckRule(Invoice, SpecOf(tk_XRCII), 'BR-O-11', nil), 'CII O-11: other line');
    Check(LandrixEInvoiceCheckRule(Invoice, SpecOf(tk_XRUBL), 'BR-O-11', nil), 'UBL O-11: breakdowns only');
    Check(not LandrixEInvoiceCheckRule(Invoice, SpecOf(tk_FXBasic), 'BR-O-12', nil), 'BASIC has BR-O-12');
    Check(LandrixEInvoiceCheckRule(Invoice, SpecOf(tk_FXBasicWL), 'BR-O-12', nil), 'BASIC WL has no BR-O-12');
  finally
    Invoice.Free;
  end;
  Invoice := TLandrixInvoice.Create;
  try
    FillVatGroup(Invoice, VatGroupCases[0]);
    Invoice.TaxAmountSubtotals[0].TaxAmount := 21;
    Check(not LandrixEInvoiceCheckRule(Invoice, SpecOf(tk_FXBasicWL), 'BR-S-09', nil), 'BASIC WL has BR-S-09');
    Check(LandrixEInvoiceCheckRule(Invoice, SpecOf(tk_FXExtended), 'BR-S-09', nil), 'EXTENDED has no BR-S-09');
    Check(not LandrixEInvoiceCheckRule(Invoice, SpecOf(tk_Peppol), 'BR-S-09', nil), 'Peppol');
  finally
    Invoice.Free;
  end;
end;

{ BR-CO-09 per syntax: UBL knows SS, CII AN; EL (Greece) is valid in both.
  BR-CO-18 in CII: the CEN schematron needs lines, Factur-X does not. }
procedure TestVatIdentifiers;
var
  Invoice: TLandrixInvoice;
begin
  Invoice := TLandrixInvoice.Create;
  try
    FillComplete(Invoice);
    Invoice.AccountingSupplierParty.VATCompanyID := 'SS123';
    Check(LandrixEInvoiceCheckRule(Invoice, SpecOf(tk_XRUBL), 'BR-CO-09', nil), 'UBL SS');
    Check(not LandrixEInvoiceCheckRule(Invoice, SpecOf(tk_XRCII), 'BR-CO-09', nil), 'CII SS');
    Invoice.AccountingSupplierParty.VATCompanyID := 'AN123';
    Check(not LandrixEInvoiceCheckRule(Invoice, SpecOf(tk_XRUBL), 'BR-CO-09', nil), 'UBL AN');
    Check(LandrixEInvoiceCheckRule(Invoice, SpecOf(tk_XRCII), 'BR-CO-09', nil), 'CII AN');
    Invoice.AccountingSupplierParty.VATCompanyID := 'EL123';
    Check(LandrixEInvoiceCheckRule(Invoice, SpecOf(tk_XRCII), 'BR-CO-09', nil), 'CII EL');
    Check(LandrixEInvoiceCheckRule(Invoice, SpecOf(tk_XRUBL), 'BR-CO-09', nil), 'UBL EL');
    { CII also writes the invoicee and, in EXTENDED, the payee VAT identifier }
    Invoice.InvoiceeParty.Name := 'Invoicee';
    Invoice.InvoiceeParty.VATCompanyID := 'XX1';
    Check(not LandrixEInvoiceCheckRule(Invoice, SpecOf(tk_FXExtended), 'BR-CO-09', nil), 'CII invoicee');
    Check(LandrixEInvoiceCheckRule(Invoice, SpecOf(tk_Peppol), 'BR-CO-09', nil), 'UBL has no invoicee');
    Invoice.InvoiceeParty.Clear;
    Invoice.PayeeParty.Name := 'Factor';
    Invoice.PayeeParty.VATCompanyID := 'XX1';
    Check(not LandrixEInvoiceCheckRule(Invoice, SpecOf(tk_FXExtended), 'BR-CO-09', nil), 'EXTENDED payee');
    Check(LandrixEInvoiceCheckRule(Invoice, SpecOf(tk_FXEN16931), 'BR-CO-09', nil), 'EN 16931 payee');
    Invoice.PayeeParty.Clear;
    Invoice.AccountingCustomerParty.VATCompanyID := 'de123';
    Check(not LandrixEInvoiceCheckRule(Invoice, SpecOf(tk_FXMinimum), 'BR-CO-09', nil), 'buyer lower case');
    Invoice.AccountingCustomerParty.VATCompanyID := '';
    Invoice.TaxAmountSubtotals.Clear;
    Invoice.InvoiceLines.Clear;
    Check(LandrixEInvoiceCheckRule(Invoice, SpecOf(tk_XRCII), 'BR-CO-18', nil), 'CEN CII without lines');
    Check(not LandrixEInvoiceCheckRule(Invoice, SpecOf(tk_XRUBL), 'BR-CO-18', nil), 'UBL without lines');
    Check(not LandrixEInvoiceCheckRule(Invoice, SpecOf(tk_FXBasicWL), 'BR-CO-18', nil), 'Factur-X without lines');
  finally
    Invoice.Free;
  end;
end;

{ BR-CO-25 (EXTENDED): a positive amount due needs a due date or terms; a
  net note or a cash discount is enough, an amount of 0 needs none.
  BR-CO-26: a seller identifier with scheme SEPA (the creditor identifier)
  counts in CII, not in UBL; the identifier without scheme not next to a
  global one in UBL and not in MINIMUM. BR-FXEXT-CO-04 skips a line with
  another status. }
procedure TestTermsAndSeller;
var
  Invoice: TLandrixInvoice;
begin
  Invoice := TLandrixInvoice.Create;
  try
    FillComplete(Invoice);
    Invoice.InvoiceDueDate := 0;
    Check(not LandrixEInvoiceCheckRule(Invoice, SpecOf(tk_FXExtended), 'BR-CO-25', nil), 'no due date');
    Invoice.PaymentTermNetNote := 'Net 30 days';
    Check(LandrixEInvoiceCheckRule(Invoice, SpecOf(tk_FXExtended), 'BR-CO-25', nil), 'net note');
    Invoice.PaymentTermNetNote := '';
    Invoice.PaymentTermsType := iptt_CashDiscount1;
    Invoice.PaymentTermCashDiscount1Days := 10;
    Invoice.PaymentTermCashDiscount1Percent := 2;
    Check(LandrixEInvoiceCheckRule(Invoice, SpecOf(tk_FXExtended), 'BR-CO-25', nil), 'cash discount');
    Invoice.PaymentTermsType := iptt_None;
    Invoice.PayableAmount := 0;
    Check(LandrixEInvoiceCheckRule(Invoice, SpecOf(tk_FXExtended), 'BR-CO-25', nil), 'nothing due');
    Invoice.AccountingSupplierParty.VATCompanyID := '';
    Invoice.AccountingSupplierParty.GlobalIdentifierSellerBuyer := 'DE98ZZZ09999999999';
    Invoice.AccountingSupplierParty.GlobalIdentifierSellerBuyerSchemeID := 'SEPA';
    Check(not LandrixEInvoiceCheckRule(Invoice, SpecOf(tk_XRUBL), 'BR-CO-26', nil), 'UBL: SEPA does not count');
    Check(LandrixEInvoiceCheckRule(Invoice, SpecOf(tk_XRCII), 'BR-CO-26', nil), 'CII: global identifier');
    { UBL writes only the global identifier next to it }
    Invoice.AccountingSupplierParty.IdentifierSellerBuyer := 'S-1';
    Check(not LandrixEInvoiceCheckRule(Invoice, SpecOf(tk_XRUBL), 'BR-CO-26', nil), 'UBL: identifier left out');
    Invoice.AccountingSupplierParty.GlobalIdentifierSellerBuyer := '';
    Check(LandrixEInvoiceCheckRule(Invoice, SpecOf(tk_XRUBL), 'BR-CO-26', nil), 'UBL: identifier');
    { MINIMUM has no seller identifier }
    Check(not LandrixEInvoiceCheckRule(Invoice, SpecOf(tk_FXMinimum), 'BR-CO-26', nil), 'MINIMUM: identifier');
    Check(LandrixEInvoiceCheckRule(Invoice, SpecOf(tk_FXBasicWL), 'BR-CO-26', nil), 'BASIC WL: identifier');
    Invoice.AccountingSupplierParty.CompanyID := 'HRB 1';
    Check(LandrixEInvoiceCheckRule(Invoice, SpecOf(tk_XRUBL), 'BR-CO-26', nil), 'UBL: legal registration');
    Check(LandrixEInvoiceCheckRule(Invoice, SpecOf(tk_FXMinimum), 'BR-CO-26', nil), 'MINIMUM: legal registration');
    { BR-FXEXT-CO-04: a written status other than DETAIL excludes the line }
    Invoice.InvoiceLines[0].TaxCategory := idtfcc_None;
    Check(not LandrixEInvoiceCheckRule(Invoice, SpecOf(tk_FXExtended), 'BR-FXEXT-CO-04', nil), 'no status');
    Invoice.InvoiceLines[0].LineStatusReasonCodeOther := 'X1';
    Check(LandrixEInvoiceCheckRule(Invoice, SpecOf(tk_FXExtended), 'BR-FXEXT-CO-04', nil), 'other status');
  finally
    Invoice.Free;
  end;
end;

{ The format rules: IBAN with blanks and check sum, an IBAN shorter than 15
  characters or with a tab only in UBL (CII writes it as ram:ProprietaryID), the type code
  as other text, telephone and email patterns, BR-51 as a warning in UBL and
  an error in CII on the normalized number. }
procedure TestFormats;
var
  N: Integer;
  Invoice: TLandrixInvoice;
  D: TLandrixEInvoiceDiagnostics;
  Payment: TLandrixInvoicePaymentType;
  Seller: TLandrixInvoiceAccountingParty;
begin
  D := TLandrixEInvoiceDiagnostics.Create;
  Invoice := TLandrixInvoice.Create;
  try
    FillComplete(Invoice);
    Payment := Invoice.PaymentTypes[0];
    Seller := Invoice.AccountingSupplierParty;
    Payment.FinancialAccount := ' DE02 1203 0000 0000 2020 51 ';
    Check(LandrixEInvoiceCheckRule(Invoice, SpecOf(tk_XRCII), 'BR-DE-19', nil), 'IBAN with blanks');
    Payment.FinancialAccount := 'DE02' + #9 + '120300000000202051';
    Check(LandrixEInvoiceCheckRule(Invoice, SpecOf(tk_XRUBL), 'BR-DE-19', nil), 'UBL: IBAN with a tab');
    Check(not LandrixEInvoiceCheckRule(Invoice, SpecOf(tk_XRCII), 'BR-DE-19', nil), 'CII: tab, written as proprietary');
    Payment.FinancialAccount := 'GB82WEST12345698765432';
    Check(LandrixEInvoiceCheckRule(Invoice, SpecOf(tk_XRUBL), 'BR-DE-19', nil), 'IBAN with letters');
    Payment.FinancialAccount := 'de02120300000000202051';
    Check(not LandrixEInvoiceCheckRule(Invoice, SpecOf(tk_XRUBL), 'BR-DE-19', nil), 'lower case country');
    Payment.FinancialAccount := 'DE011234567';
    Check(LandrixEInvoiceCheckRule(Invoice, SpecOf(tk_XRUBL), 'BR-DE-19', nil), 'UBL: short IBAN');
    Check(not LandrixEInvoiceCheckRule(Invoice, SpecOf(tk_XRCII), 'BR-DE-19', nil), 'CII: short IBAN');
    Payment.FinancialAccount := ' ';
    Check(not LandrixEInvoiceCheckRule(Invoice, SpecOf(tk_XRUBL), 'BR-DE-19', nil), 'no account');
    Payment.FinancialAccount := 'DE02120300000000202051';
    Invoice.InvoiceTypeCode := itc_None;
    Invoice.InvoiceTypeCodeOther := ' 875 ';
    Check(LandrixEInvoiceCheckRule(Invoice, SpecOf(tk_XRUBL), 'BR-DE-17', nil), 'other text 875');
    Invoice.InvoiceTypeCodeOther := '386';
    Check(not LandrixEInvoiceCheckRule(Invoice, SpecOf(tk_XRUBL), 'BR-DE-17', nil), 'other text 386');
    Invoice.InvoiceTypeCode := itc_CommercialInvoice;
    Invoice.InvoiceTypeCodeOther := '';
    Seller.ContactElectronicMail := ' a@b.c.de ';
    Check(LandrixEInvoiceCheckRule(Invoice, SpecOf(tk_XRUBL), 'BR-DE-28', nil), 'email with blanks around');
    Seller.ContactElectronicMail := 'a b@c.de';
    Check(not LandrixEInvoiceCheckRule(Invoice, SpecOf(tk_XRUBL), 'BR-DE-28', nil), 'email with a blank');
    Seller.ContactElectronicMail := 'a@@b.de';
    Check(not LandrixEInvoiceCheckRule(Invoice, SpecOf(tk_XRUBL), 'BR-DE-28', nil), 'two @');
    Seller.ContactElectronicMail := 'a@.de';
    Check(not LandrixEInvoiceCheckRule(Invoice, SpecOf(tk_XRUBL), 'BR-DE-28', nil), 'empty domain part');
    Seller.ContactElectronicMail := 'a@b.de.';
    Check(not LandrixEInvoiceCheckRule(Invoice, SpecOf(tk_XRUBL), 'BR-DE-28', nil), 'dot at the end');
    Seller.ContactElectronicMail := 'accounting@seller.example';
    Seller.ContactTelephone := '(0) 1-2';
    Check(LandrixEInvoiceCheckRule(Invoice, SpecOf(tk_XRUBL), 'BR-DE-27', nil), 'three digits');
    Seller.ContactName := '';
    Seller.ContactTelephone := '';
    Seller.ContactElectronicMail := '';
    Check(LandrixEInvoiceCheckRule(Invoice, SpecOf(tk_XRUBL), 'BR-DE-27', nil), 'no contact');
    Check(LandrixEInvoiceCheckRule(Invoice, SpecOf(tk_XRUBL), 'BR-DE-28', nil), 'no contact');
    Payment.PaymentMeansCode := ipmc_CreditCard;
    Payment.FinancialAccount := ' 1234  5678 ';
    Check(LandrixEInvoiceCheckRule(Invoice, SpecOf(tk_XRCII), 'BR-51', nil), 'normalized 9 characters');
    Payment.FinancialAccount := '12345678901';
    { between German parties DE-R-002 requires the seller contact }
    Invoice.AccountingCustomerParty.Address.CountryCode := 'AT';
    D.Clear;
    N := LandrixEInvoiceCheckInvoice(Invoice, SpecOf(tk_Peppol), D);
    CheckEquals(0, N, 'UBL: no error: ' + string(D.ToText));
    Invoice.AccountingCustomerParty.Address.CountryCode := 'DE';
    Check(HasRule(D, 'BR-51'), 'UBL: BR-51 reported');
    D.Clear;
    Check(LandrixEInvoiceCheckInvoice(Invoice, SpecOf(tk_FXEN16931), D) > 0, 'CII: error');
    Check(HasRule(D, 'BR-51'), 'CII: BR-51 reported');
  finally
    Invoice.Free;
    D.Free;
  end;
end;

{ The lists of the validators: STD instead of STN, AN instead of SS (CII
  only), B as VAT category, the EAS codes 0219 and 0220, the UBL note
  subjects without the newest codes. Codes are normalized and compared
  case sensitively; BR-CL-24 compares without normalizing. }
procedure TestCodeListDeltas;
var
  Invoice: TLandrixInvoice;
  Subject: TLandrixInvoiceNoteSubjectCode;
begin
  Invoice := TLandrixInvoice.Create;
  try
    FillComplete(Invoice);
    Invoice.InvoiceCurrencyCode := ' EUR ';
    Check(LandrixEInvoiceCheckRule(Invoice, SpecOf(tk_XRUBL), 'BR-CL-04', nil), 'blanks around');
    Check(LandrixEInvoiceCheckRule(Invoice, SpecOf(tk_XRUBL), 'BR-CL-03', nil), 'blanks around @currencyID');
    Invoice.InvoiceCurrencyCode := 'E UR';
    Check(not LandrixEInvoiceCheckRule(Invoice, SpecOf(tk_XRUBL), 'BR-CL-04', nil), 'blank inside');
    Invoice.InvoiceCurrencyCode := 'STD';
    Check(LandrixEInvoiceCheckRule(Invoice, SpecOf(tk_XRCII), 'BR-CL-04', nil), 'STD of the validators');
    Invoice.InvoiceCurrencyCode := 'STN';
    Check(not LandrixEInvoiceCheckRule(Invoice, SpecOf(tk_Peppol), 'BR-CL-04', nil), 'STN of EC version 17');
    Invoice.InvoiceCurrencyCode := 'EUR';
    { BT-6 is written only when it differs, in @currencyID only with BT-111 }
    Invoice.TaxCurrencyCode := 'EURO';
    Check(not LandrixEInvoiceCheckRule(Invoice, SpecOf(tk_XRUBL), 'BR-CL-05', nil), 'BT-6');
    Check(LandrixEInvoiceCheckRule(Invoice, SpecOf(tk_XRUBL), 'BR-CL-03', nil), 'no BT-111');
    Invoice.TaxAmountTotalInTaxCurrency.SetValue(19);
    Check(not LandrixEInvoiceCheckRule(Invoice, SpecOf(tk_XRCII), 'BR-CL-03', nil), 'BT-111 in BT-6');
    Invoice.TaxCurrencyCode := '';
    Invoice.AccountingCustomerParty.Address.CountryCode := 'AN';
    Check(LandrixEInvoiceCheckRule(Invoice, SpecOf(tk_XRCII), 'BR-CL-14', nil), 'CII: AN');
    Check(not LandrixEInvoiceCheckRule(Invoice, SpecOf(tk_XRUBL), 'BR-CL-14', nil), 'UBL: AN');
    Invoice.AccountingCustomerParty.Address.CountryCode := 'SS';
    Check(not LandrixEInvoiceCheckRule(Invoice, SpecOf(tk_XRCII), 'BR-CL-14', nil), 'CII: SS');
    Check(LandrixEInvoiceCheckRule(Invoice, SpecOf(tk_XRUBL), 'BR-CL-14', nil), 'UBL: SS');
    Invoice.AccountingCustomerParty.Address.CountryCode := 'de';
    Check(not LandrixEInvoiceCheckRule(Invoice, SpecOf(tk_XRUBL), 'BR-CL-14', nil), 'lower case');
    Invoice.AccountingCustomerParty.Address.CountryCode := 'DE';
    Invoice.InvoiceLines[0].TaxCategory := idtfcc_None;
    Invoice.InvoiceLines[0].TaxCategoryOther := 'B';
    Check(LandrixEInvoiceCheckRule(Invoice, SpecOf(tk_XRUBL), 'BR-CL-18', nil), 'B');
    Invoice.InvoiceLines[0].TaxCategory := idtfcc_S_StandardRate;
    Invoice.AccountingSupplierParty.ElectronicAddressSellerBuyerSchemeID := '0219';
    Check(LandrixEInvoiceCheckRule(Invoice, SpecOf(tk_Peppol), 'BR-CL-25', nil), 'EAS 0219');
    Invoice.AccountingSupplierParty.ElectronicAddressSellerBuyerSchemeID := 'EM';
    Check(LandrixEInvoiceNoteSubjectCodeFromStr('BAT', Subject), 'BAT is a member');
    with Invoice.Notes.AddNote do
    begin
      Content := 'Note';
      SubjectCode := Subject;
    end;
    Check(not LandrixEInvoiceCheckRule(Invoice, SpecOf(tk_XRUBL), 'BR-CL-08', nil), 'UBL: BAT');
    Check(LandrixEInvoiceCheckRule(Invoice, SpecOf(tk_XRCII), 'BR-CL-08', nil), 'CII: BAT');
    Invoice.Notes[0].SubjectCode := insc_None;
    Invoice.Notes[0].Content := '#ABCD# four characters';
    Check(LandrixEInvoiceCheckRule(Invoice, SpecOf(tk_XRUBL), 'BR-CL-08', nil), 'UBL: no code of three');
    Invoice.Notes[0].Content := 'Item #12#';
    Check(LandrixEInvoiceCheckRule(Invoice, SpecOf(tk_XRUBL), 'BR-CL-08', nil), 'UBL: two characters');
    Invoice.Notes[0].Content := 'Item #123#';
    Check(not LandrixEInvoiceCheckRule(Invoice, SpecOf(tk_XRUBL), 'BR-CL-08', nil), 'UBL: #123# in the text');
    Check(LandrixEInvoiceCheckRule(Invoice, SpecOf(tk_XRCII), 'BR-CL-08', nil), 'CII: no subject code');
    Invoice.Notes.Clear;
    AddPdf(Invoice, 'A-1', 'a.pdf');
    Check(LandrixEInvoiceCheckRule(Invoice, SpecOf(tk_XRUBL), 'BR-CL-24', nil), 'PDF');
    Invoice.Attachments[0].AttachmentType := iat_application_None;
    Invoice.Attachments[0].AttachmentTypeOther := ' application/pdf';
    Check(not LandrixEInvoiceCheckRule(Invoice, SpecOf(tk_XRUBL), 'BR-CL-24', nil), 'not normalized');
  finally
    Invoice.Free;
  end;
end;

{ What the mappers write: UBL writes 381 as ubl:CreditNote and every other
  code as ubl:Invoice; BT-8 is converted for CII and written there only with
  a VAT breakdown; a global identifier without scheme gets 0088, UBL
  accepts SEPA for the seller; an electronic address without scheme gets
  EM where allowed. The XRechnung extension (here: an XML attachment or an
  extension scheme) leaves out BR-CL-10, 11, 21, 24, 25 and 26; a credit
  note never uses it in UBL. BR-CL-21 and BR-CL-23 are warnings in
  XRechnung, errors in Peppol. }
procedure TestCodeListsAsWritten;
var
  Invoice: TLandrixInvoice;
  D: TLandrixEInvoiceDiagnostics;
  TypeCode: TLandrixInvoiceTypeCode;
begin
  D := TLandrixEInvoiceDiagnostics.Create;
  Invoice := TLandrixInvoice.Create;
  try
    FillComplete(Invoice);
    Invoice.InvoiceTypeCode := itc_CreditNote;
    Check(LandrixEInvoiceCheckRule(Invoice, SpecOf(tk_XRUBL), 'BR-CL-01', nil), 'UBL: 381');
    Invoice.InvoiceTypeCode := itc_None;
    Invoice.InvoiceTypeCodeOther := '381';
    Check(not LandrixEInvoiceCheckRule(Invoice, SpecOf(tk_XRUBL), 'BR-CL-01', nil), 'UBL: 381 as other text');
    Check(LandrixEInvoiceCheckRule(Invoice, SpecOf(tk_XRCII), 'BR-CL-01', nil), 'CII: 381 as other text');
    Invoice.InvoiceTypeCodeOther := '';
    Check(LandrixEInvoiceTypeCodeFromStr('261', TypeCode), '261 is a member');
    Invoice.InvoiceTypeCode := TypeCode;
    Check(not LandrixEInvoiceCheckRule(Invoice, SpecOf(tk_Peppol), 'BR-CL-01', nil), 'UBL: 261 in ubl:Invoice');
    Check(LandrixEInvoiceCheckRule(Invoice, SpecOf(tk_XRCII), 'BR-CL-01', nil), 'CII: 261');
    Invoice.InvoiceTypeCode := itc_CommercialInvoice;
    Invoice.TaxPointDateCode := '3';
    Check(LandrixEInvoiceCheckRule(Invoice, SpecOf(tk_XRUBL), 'BR-CL-06', nil), 'UBL: 3');
    Check(LandrixEInvoiceCheckRule(Invoice, SpecOf(tk_XRCII), 'BR-CL-06', nil), 'CII: 3 written as 5');
    Invoice.TaxPointDateCode := '5';
    Check(LandrixEInvoiceCheckRule(Invoice, SpecOf(tk_XRCII), 'BR-CL-06', nil), 'CII: 5 written unchanged');
    Invoice.TaxPointDateCode := '4';
    Check(not LandrixEInvoiceCheckRule(Invoice, SpecOf(tk_XRCII), 'BR-CL-06', nil), 'CII: 4');
    Invoice.TaxAmountSubtotals.Clear;
    Check(LandrixEInvoiceCheckRule(Invoice, SpecOf(tk_XRCII), 'BR-CL-06', nil), 'CII: no VAT breakdown');
    Invoice.TaxPointDate.SetValue(EncodeDate(2026, 10, 1));
    Check(LandrixEInvoiceCheckRule(Invoice, SpecOf(tk_XRUBL), 'BR-CL-06', nil), 'UBL: left out next to BT-7');
    Invoice.Free;
    Invoice := TLandrixInvoice.Create;
    FillComplete(Invoice);
    Invoice.AccountingSupplierParty.GlobalIdentifierSellerBuyer := '4000001000005';
    Check(LandrixEInvoiceCheckRule(Invoice, SpecOf(tk_XRCII), 'BR-CL-10', nil), 'default 0088');
    Invoice.AccountingSupplierParty.GlobalIdentifierSellerBuyerSchemeID := 'SEPA';
    Check(LandrixEInvoiceCheckRule(Invoice, SpecOf(tk_XRUBL), 'BR-CL-10', nil), 'UBL: SEPA of the seller');
    Check(not LandrixEInvoiceCheckRule(Invoice, SpecOf(tk_XRCII), 'BR-CL-10', nil), 'CII: SEPA');
    Invoice.AccountingSupplierParty.GlobalIdentifierSellerBuyerSchemeID := '';
    Invoice.PayeeParty.Name := 'Payee';
    Invoice.PayeeParty.Identifier := 'P-1';
    Invoice.PayeeParty.IdentifierSchemeID := ' ';
    Check(not LandrixEInvoiceCheckRule(Invoice, SpecOf(tk_XRUBL), 'BR-CL-10', nil), 'UBL: blank payee scheme');
    Check(LandrixEInvoiceCheckRule(Invoice, SpecOf(tk_XRCII), 'BR-CL-10', nil), 'CII: payee identifier as ram:ID');
    Invoice.PayeeParty.IdentifierSchemeID := 'SEPA';
    Check(LandrixEInvoiceCheckRule(Invoice, SpecOf(tk_XRUBL), 'BR-CL-10', nil), 'UBL: SEPA of the payee');
    Invoice.PayeeParty.IdentifierSchemeID := '0088';
    Invoice.AccountingCustomerParty.ElectronicAddressSellerBuyerSchemeID := '';
    Check(LandrixEInvoiceCheckRule(Invoice, SpecOf(tk_Peppol), 'BR-CL-25', nil), 'without scheme');
    { the extension: an XML attachment }
    Invoice.AccountingCustomerParty.ElectronicAddressSellerBuyerSchemeID := 'XX';
    Invoice.Attachments.AddAttachment(iat_application_xml).EmbedDataFromText(TLandrixEInvoiceString('<a/>'));
    Invoice.Attachments[0].ID := 'A-1';
    Check(LandrixEInvoiceCheckRule(Invoice, SpecOf(tk_XRUBL), 'BR-CL-25', nil), 'UBL: extension');
    Check(LandrixEInvoiceCheckRule(Invoice, SpecOf(tk_XRCII), 'BR-CL-24', nil), 'CII: extension');
    Check(not LandrixEInvoiceCheckRule(Invoice, SpecOf(tk_Peppol), 'BR-CL-24', nil), 'Peppol: XML');
    Check(not LandrixEInvoiceCheckRule(Invoice, SpecOf(tk_Peppol), 'BR-CL-25', nil), 'Peppol: no extension');
    Invoice.InvoiceTypeCode := itc_CreditNote;
    Check(not LandrixEInvoiceCheckRule(Invoice, SpecOf(tk_XRUBL), 'BR-CL-25', nil), 'UBL: credit note');
    Check(LandrixEInvoiceCheckRule(Invoice, SpecOf(tk_XRCII), 'BR-CL-25', nil), 'CII: credit note');
    { the extension: an extension scheme }
    Invoice.Attachments.Clear;
    Invoice.InvoiceTypeCode := itc_CommercialInvoice;
    Invoice.AccountingSupplierParty.ElectronicAddressSellerBuyerSchemeID := 'xr01';
    Check(not LandrixEInvoiceCheckRule(Invoice, SpecOf(tk_XRCII), 'BR-CL-25', nil), 'CII: xr01 is no extension code');
    Invoice.AccountingSupplierParty.ElectronicAddressSellerBuyerSchemeID := 'XR01';
    Check(LandrixEInvoiceCheckRule(Invoice, SpecOf(tk_XRCII), 'BR-CL-25', nil), 'CII: extension scheme');
    Invoice.AccountingSupplierParty.ElectronicAddressSellerBuyerSchemeID := 'EM';
    Invoice.AccountingSupplierParty.CompanyID := 'HRB 1';
    Invoice.AccountingSupplierParty.CompanyIDSchemeID := 'XR01';
    Check(LandrixEInvoiceCheckRule(Invoice, SpecOf(tk_XRUBL), 'BR-CL-11', nil), 'UBL: XR01 of BT-30 (extension)');
    Check(LandrixEInvoiceCheckRule(Invoice, SpecOf(tk_XRUBL), 'BR-CL-25', nil), 'UBL: extension by BT-30');
    Check(not LandrixEInvoiceCheckRule(Invoice, SpecOf(tk_Peppol), 'BR-CL-11', nil), 'Peppol: XR01 of BT-30');
    Invoice.AccountingSupplierParty.CompanyIDSchemeID := '0002';
    Invoice.InvoiceLines[0].StandardItemIdentifier := '4711';
    Invoice.InvoiceLines[0].StandardItemIdentifierSchemeID := 'XR02';
    Check(LandrixEInvoiceCheckRule(Invoice, SpecOf(tk_XRCII), 'BR-CL-21', nil), 'CII: XR02 of BT-157 (extension)');
    Check(not LandrixEInvoiceCheckRule(Invoice, SpecOf(tk_Peppol), 'BR-CL-21', nil), 'Peppol: XR02 of BT-157');
    Invoice.InvoiceLines[0].StandardItemIdentifierSchemeID := '0160';
    Invoice.AccountingSupplierParty.ElectronicAddressSellerBuyerSchemeID := 'EM';
    Invoice.AccountingCustomerParty.ElectronicAddressSellerBuyerSchemeID := 'EM';
    Invoice.InvoiceLines[0].UnitCode := iuc_None;
    Invoice.InvoiceLines[0].UnitCodeOther := 'ZZZZ';
    D.Clear;
    CheckEquals(0, LandrixEInvoiceCheckInvoice(Invoice, SpecOf(tk_XRUBL), D), 'XRechnung: ' + string(D.ToText));
    Check(HasRule(D, 'BR-CL-23'), 'XRechnung: BR-CL-23 reported');
    D.Clear;
    Check(LandrixEInvoiceCheckInvoice(Invoice, SpecOf(tk_Peppol), D) > 0, 'Peppol: error');
    Check(HasRule(D, 'BR-CL-23'), 'Peppol: BR-CL-23 reported');
  finally
    Invoice.Free;
    D.Free;
  end;
end;

{ A Double from thousandths, computed at run time (no float literal). }
function Thousandths(AValue: Integer): Double;
begin
  Result := AValue / 1000;
end;

function RuleHolds(Invoice: TLandrixInvoice; AKind: TTargetKind; const AID: string): Boolean;
begin
  Result := LandrixEInvoiceCheckRule(Invoice, SpecOf(AKind), TLandrixEInvoiceString(AID), nil);
end;

{ PEPPOL-EN16931-R040 and R120 compare exactly within 0.02 (XRechnung: 0.5
  for HUF) on the values as written: the percentage with 4 decimals, on UBL
  line level with 2; R120 divides the price by the base quantity as Saxon
  does (18 decimals, rounded half down) and is a warning in XRechnung, an
  error in Peppol. R055 counts 0 for both signs in UBL and as positive in CII; R054
  in UBL also counts a VAT total without breakdown. UBL checks R120 on
  cac:InvoiceLine only and R130 on every price, CII every line; sub lines
  only where they are written. }
procedure TestPeppolRules;
var
  Invoice: TLandrixInvoice;
  Line, Sub: TLandrixInvoiceLine;
  Item: TLandrixInvoiceAllowanceCharge;
  D: TLandrixEInvoiceDiagnostics;
begin
  D := TLandrixEInvoiceDiagnostics.Create;
  Invoice := TLandrixInvoice.Create;
  try
    FillComplete(Invoice);
    Line := Invoice.InvoiceLines[0];
    Item := Invoice.AllowanceCharges.AddAllowanceCharge;
    Item.TaxCategory := idtfcc_S_StandardRate;
    Item.TaxPercent := 19;
    Item.BaseAmount := 100;
    Item.MultiplierFactorNumeric := 10;
    Item.Amount := CentsValue(1002);
    Check(RuleHolds(Invoice, tk_XRUBL, 'PEPPOL-EN16931-R040'), 'R040: 10.02 within 0.02');
    Item.Amount := CentsValue(998);
    Check(RuleHolds(Invoice, tk_Peppol, 'PEPPOL-EN16931-R040'), 'R040: 9.98 within 0.02');
    Item.Amount := CentsValue(1003);
    Check(not RuleHolds(Invoice, tk_XRCII, 'PEPPOL-EN16931-R040'), 'R040: 10.03');
    Invoice.InvoiceCurrencyCode := 'HUF';
    Item.Amount := CentsValue(1050);
    Check(RuleHolds(Invoice, tk_XRUBL, 'PEPPOL-EN16931-R040'), 'R040: HUF within 0.5 in XRechnung');
    Check(not RuleHolds(Invoice, tk_Peppol, 'PEPPOL-EN16931-R040'), 'R040: Peppol allows 0.02 for HUF');
    Item.Amount := CentsValue(1051);
    Check(not RuleHolds(Invoice, tk_XRUBL, 'PEPPOL-EN16931-R040'), 'R040: HUF 10.51');
    Invoice.InvoiceCurrencyCode := 'EUR';
    Invoice.AllowanceCharges.Clear;

    { line level: the base amount is written with every percentage }
    Item := Line.AllowanceCharges.AddAllowanceCharge;
    Item.MultiplierFactorNumeric := Thousandths(10004);
    Item.BaseAmount := 1000;
    Item.Amount := 100;
    Check(RuleHolds(Invoice, tk_XRUBL, 'PEPPOL-EN16931-R040'), 'R040: UBL writes the line percentage as 10.00');
    Check(not RuleHolds(Invoice, tk_XRCII, 'PEPPOL-EN16931-R040'), 'R040: CII writes 10.0040');
    Item.Amount := CentsValue(10004);
    Check(not RuleHolds(Invoice, tk_XRUBL, 'PEPPOL-EN16931-R040'), 'R040: UBL 100.04');
    Check(RuleHolds(Invoice, tk_XRCII, 'PEPPOL-EN16931-R040'), 'R040: CII 100.04');
    Item.BaseAmount := 0;
    Check(RuleHolds(Invoice, tk_XRUBL, 'PEPPOL-EN16931-R041'), 'R041: line base amount written as 0');
    Check(not RuleHolds(Invoice, tk_XRUBL, 'PEPPOL-EN16931-R040'), 'R040: line base amount 0');
    Item.MultiplierFactorNumeric := 0;
    Check(RuleHolds(Invoice, tk_XRUBL, 'PEPPOL-EN16931-R042'), 'R042: no base amount, no percentage');
    Item.BaseAmount := 1000;
    Check(not RuleHolds(Invoice, tk_XRCII, 'PEPPOL-EN16931-R042'), 'R042: line base amount alone');
    Line.AllowanceCharges.Clear;

    { R120: quantity x (price div base quantity) + charges - allowances }
    Line.Quantity := 3;
    Line.NetPriceAmount := 10;
    Line.BaseQuantity := 3;
    Line.BaseQuantityUnitCode := iuc_piece;
    Line.LineAmount := 10;
    Check(RuleHolds(Invoice, tk_Peppol, 'PEPPOL-EN16931-R120'), 'R120: 10.00');
    Line.LineAmount := CentsValue(1001);
    Check(RuleHolds(Invoice, tk_Peppol, 'PEPPOL-EN16931-R120'), 'R120: 10.01');
    Line.LineAmount := CentsValue(1002);
    Check(not RuleHolds(Invoice, tk_Peppol, 'PEPPOL-EN16931-R120'),
      'R120: 10 div 3 rounds down to 18 decimals, x 3 below 10.00 by 10^-18');
    Line.LineAmount := CentsValue(998);
    Check(RuleHolds(Invoice, tk_Peppol, 'PEPPOL-EN16931-R120'), 'R120: 9.98');
    Line.LineAmount := CentsValue(997);
    D.Clear;
    Check(not LandrixEInvoiceCheckRule(Invoice, SpecOf(tk_Peppol), 'PEPPOL-EN16931-R120', D), 'R120: 9.97');
    CheckEquals(1, Integer(D.Count), 'R120: one Peppol row');
    if D.Count = 1 then
      Check(D[0].Severity = eds_Error, 'R120: error in Peppol');
    D.Clear;
    Check(not LandrixEInvoiceCheckRule(Invoice, SpecOf(tk_XRUBL), 'PEPPOL-EN16931-R120', D), 'R120: XRechnung');
    CheckEquals(1, Integer(D.Count), 'R120: one XRechnung row');
    if D.Count = 1 then
      Check(D[0].Severity = eds_Warning, 'R120: warning in XRechnung');
    Line.NetPriceAmount := 20;
    Line.LineAmount := CentsValue(1998);
    Check(not RuleHolds(Invoice, tk_Peppol, 'PEPPOL-EN16931-R120'),
      'R120: 20 div 3 rounds up to 18 decimals, x 3 above 20.00 by 10^-18');
    Line.LineAmount := CentsValue(2002);
    Check(RuleHolds(Invoice, tk_Peppol, 'PEPPOL-EN16931-R120'), 'R120: 20.02');
    Line.Quantity := 70;
    Line.NetPriceAmount := 1;
    Line.BaseQuantity := 70;
    Line.LineAmount := CentsValue(102);
    Check(not RuleHolds(Invoice, tk_Peppol, 'PEPPOL-EN16931-R120'),
      'R120: 1 div 70 has 19 decimals (70 counts with scale -1), x 70 below 1.00');
    Line.LineAmount := CentsValue(98);
    Check(RuleHolds(Invoice, tk_Peppol, 'PEPPOL-EN16931-R120'), 'R120: 0.98');
    Line.Quantity := 1;
    Line.NetPriceAmount := 100;
    Line.BaseQuantity := 0;
    with Line.AllowanceCharges.AddAllowanceCharge do
    begin
      ChargeIndicator := False;
      Amount := 1;
    end;
    with Line.AllowanceCharges.AddAllowanceCharge do
    begin
      ChargeIndicator := True;
      Amount := CentsValue(50);
    end;
    Line.LineAmount := CentsValue(9950);
    Check(RuleHolds(Invoice, tk_XRCII, 'PEPPOL-EN16931-R120'), 'R120: with allowance and charge');
    Line.LineAmount := 100;
    Check(not RuleHolds(Invoice, tk_XRCII, 'PEPPOL-EN16931-R120'), 'R120: allowance and charge ignored');
    Line.AllowanceCharges.Clear;

    { sub lines: R130 also in UBL (context cac:Price), R120 not; XRechnung
      CII and UBL credit notes write them flat, as lines }
    Sub := Line.SubInvoiceLines.AddInvoiceLine;
    Sub.ID := '1.1';
    Sub.Name := 'Sub item';
    Sub.Quantity := 1;
    Sub.UnitCode := iuc_piece;
    Sub.NetPriceAmount := 100;
    Sub.LineAmount := 90;
    Check(RuleHolds(Invoice, tk_XRUBL, 'PEPPOL-EN16931-R120'), 'R120: UBL sub line not checked');
    Check(not RuleHolds(Invoice, tk_XRCII, 'PEPPOL-EN16931-R120'), 'R120: XRechnung CII writes the sub line flat');
    Sub.LineAmount := 100;
    Sub.BaseQuantity := 1;
    Sub.BaseQuantityUnitCodeOther := 'KGM';
    Check(not RuleHolds(Invoice, tk_XRUBL, 'PEPPOL-EN16931-R130'), 'R130: UBL sub line');
    Check(not RuleHolds(Invoice, tk_XRCII, 'PEPPOL-EN16931-R130'), 'R130: XRechnung CII writes the sub line flat');
    Invoice.InvoiceTypeCode := itc_CreditNote;
    Check(not RuleHolds(Invoice, tk_XRUBL, 'PEPPOL-EN16931-R130'), 'R130: a UBL credit note writes it flat');
    Invoice.InvoiceTypeCode := itc_CommercialInvoice;
    Sub.BaseQuantityUnitCode := iuc_piece;
    Sub.BaseQuantityUnitCodeOther := '';
    Check(RuleHolds(Invoice, tk_XRUBL, 'PEPPOL-EN16931-R130'), 'R130: same unit');
    Sub.BaseQuantity := 0;
    Sub.BaseQuantityUnitCodeOther := 'KGM';
    Check(RuleHolds(Invoice, tk_XRUBL, 'PEPPOL-EN16931-R130'), 'R130: no base quantity written');
    Line.SubInvoiceLines.Clear;

    { R121 on the base quantity as written; R046 exactly }
    Line.BaseQuantity := Thousandths(1) / 10000;
    Check(not RuleHolds(Invoice, tk_XRUBL, 'PEPPOL-EN16931-R121'), 'R121: written as 0.00');
    Line.BaseQuantity := Thousandths(1);
    Check(RuleHolds(Invoice, tk_XRUBL, 'PEPPOL-EN16931-R121'), 'R121: 0.001');
    Line.BaseQuantity := 0;
    Line.GrossPriceAmount := Thousandths(10500);
    Line.DiscountOnTheGrossPrice := Thousandths(250);
    Line.NetPriceAmount := Thousandths(10250);
    Check(RuleHolds(Invoice, tk_XRCII, 'PEPPOL-EN16931-R046'), 'R046: 10.50 - 0.25');
    Line.NetPriceAmount := Thousandths(10251);
    Check(not RuleHolds(Invoice, tk_XRUBL, 'PEPPOL-EN16931-R046'), 'R046: 10.251');
    Line.GrossPriceAmount := 0;
    Check(RuleHolds(Invoice, tk_XRUBL, 'PEPPOL-EN16931-R046'), 'R046: no gross price');
    Line.NetPriceAmount := 100;
    Line.DiscountOnTheGrossPrice := 0;

    { R110, R111: a reversed invoice period is not written }
    Invoice.InvoicePeriodStartDate := EncodeDate(2026, 10, 1);
    Invoice.InvoicePeriodEndDate := EncodeDate(2026, 10, 31);
    Line.InvoiceLinePeriodStartDate := EncodeDate(2026, 10, 1) + 0.75;
    Line.InvoiceLinePeriodEndDate := EncodeDate(2026, 10, 31);
    Check(RuleHolds(Invoice, tk_XRUBL, 'PEPPOL-EN16931-R110'), 'R110: same day');
    Check(RuleHolds(Invoice, tk_XRCII, 'PEPPOL-EN16931-R111'), 'R111: same day');
    Line.InvoiceLinePeriodStartDate := EncodeDate(2026, 9, 30);
    Check(not RuleHolds(Invoice, tk_XRCII, 'PEPPOL-EN16931-R110'), 'R110: day before');
    Invoice.InvoicePeriodEndDate := EncodeDate(2026, 9, 1);
    Check(RuleHolds(Invoice, tk_XRCII, 'PEPPOL-EN16931-R110'), 'R110: reversed invoice period');
    Invoice.InvoicePeriodStartDate := 0;
    Invoice.InvoicePeriodEndDate := 0;
    Line.InvoiceLinePeriodStartDate := 0;
    Line.InvoiceLinePeriodEndDate := 0;

    { R053 to R055 on the VAT totals }
    Invoice.TaxCurrencyCode := 'USD';
    Invoice.TaxAmountTotalInTaxCurrency.SetValue(20);
    Check(RuleHolds(Invoice, tk_XRUBL, 'PEPPOL-EN16931-R054'), 'R054: BT-111 next to BT-6');
    Check(RuleHolds(Invoice, tk_XRUBL, 'PEPPOL-EN16931-R055'), 'R055: both positive');
    Invoice.TaxAmountTotal := 0;
    Invoice.TaxAmountTotalInTaxCurrency.SetValue(-1);
    Check(RuleHolds(Invoice, tk_XRUBL, 'PEPPOL-EN16931-R055'), 'R055: UBL 0 and negative');
    Check(not RuleHolds(Invoice, tk_XRCII, 'PEPPOL-EN16931-R055'), 'R055: CII 0 counts as positive');
    Invoice.TaxAmountTotal := -19;
    Invoice.TaxAmountTotalInTaxCurrency.SetValue(0);
    Check(RuleHolds(Invoice, tk_XRUBL, 'PEPPOL-EN16931-R055'), 'R055: UBL negative and 0');
    Check(not RuleHolds(Invoice, tk_XRCII, 'PEPPOL-EN16931-R055'), 'R055: CII negative and 0');
    Invoice.TaxAmountTotalInTaxCurrency.Clear;
    Check(not RuleHolds(Invoice, tk_XRCII, 'PEPPOL-EN16931-R055'), 'R055: BT-111 missing');
    Invoice.TaxCurrencyCode := 'EUR';
    Invoice.TaxAmountTotal := 19;
    Check(RuleHolds(Invoice, tk_XRUBL, 'PEPPOL-EN16931-R005'), 'R005: BT-6 = BT-5 is not written');
    Check(RuleHolds(Invoice, tk_XRUBL, 'PEPPOL-EN16931-R054'), 'R054: no BT-6, no BT-111');
    Invoice.TaxCurrencyCode := '';
    Invoice.TaxAmountSubtotals.Clear;
    Check(not RuleHolds(Invoice, tk_XRUBL, 'PEPPOL-EN16931-R054'), 'R054: UBL VAT total without breakdown');
    Check(RuleHolds(Invoice, tk_XRCII, 'PEPPOL-EN16931-R054'), 'R054: CII');
    Check(RuleHolds(Invoice, tk_XRCII, 'PEPPOL-EN16931-R053'), 'R053: UBL only');
  finally
    Invoice.Free;
    D.Free;
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
  RegisterTest('Check.SEPAIdentifiers', TestSEPAIdentifiers);
  RegisterTest('Check.TaxTolerance', TestTaxTolerance);
  RegisterTest('Check.UnwritableNumbers', TestUnwritableNumbers);
  RegisterTest('Check.UnwritableDates', TestUnwritableDates);
  RegisterTest('Check.Totals', TestTotals);
  RegisterTest('Check.VatCategories', TestVatCategories);
  RegisterTest('Check.VatSyntaxes', TestVatSyntaxes);
  RegisterTest('Check.VatIdentifiers', TestVatIdentifiers);
  RegisterTest('Check.TermsAndSeller', TestTermsAndSeller);
  RegisterTest('Check.Formats', TestFormats);
  RegisterTest('Check.CodeListDeltas', TestCodeListDeltas);
  RegisterTest('Check.CodeListsAsWritten', TestCodeListsAsWritten);
  RegisterTest('Check.PeppolRules', TestPeppolRules);
end;

end.
