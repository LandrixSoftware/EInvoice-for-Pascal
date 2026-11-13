{
  EInvoice-for-Pascal

  Copyright (C) 2026 Landrix Software GmbH & Co. KG

  This file is dual-licensed under:
  - GNU GPL version 3 or later; or
  - the Landrix Software Commercial License.

  See LICENSE and COMMERCIAL-LICENSE.md.

  SPDX-License-Identifier: GPL-3.0-or-later OR LicenseRef-Landrix-Commercial
}

{ Tests for LandrixEInvoiceCheckPeppol: every rule breaks once in the
  complete invoice of LandrixEInvoiceTestCheck and must fire for Peppol
  and hold for XRechnung; warnings stay warnings; the national rules
  apply to their country only; the identifiers the rules assume match the
  mapped UBL model. The OpenPEPPOL unit tests are the oracle of the rule
  semantics (tools/rulecheck/peppol-oracle.py). }

unit LandrixEInvoiceTestCheckPeppol;

{$I LandrixEInvoice.inc}

interface

procedure Register;

implementation

uses
  SysUtils,
  LandrixEInvoiceTypes,
  LandrixEInvoiceDiagnostics,
  LandrixEInvoiceCodes,
  LandrixEInvoiceSpecs,
  LandrixEInvoiceInvoice,
  LandrixEInvoiceUBL,
  LandrixEInvoiceMapUBL,
  LandrixEInvoiceCheck,
  LandrixEInvoiceTestCheck,
  LandrixEInvoiceTestFramework;

function PeppolSpec: TLandrixEInvoiceSpec;
begin
  Check(LandrixEInvoiceFindSpec(TLandrixEInvoiceTargets.PeppolBIS('3.0'), Result), 'Peppol spec');
end;

function XRechnungSpec: TLandrixEInvoiceSpec;
begin
  Check(LandrixEInvoiceFindSpec(TLandrixEInvoiceTargets.XRechnung('3.0', esy_UBL), Result), 'XRechnung spec');
end;

{ A currency value from cents, without a float literal. }
function CentsValue(ACents: Int64): Currency;
begin
  PInt64(@Result)^ := ACents * 100;
end;

procedure SetCountries(Invoice: TLandrixInvoice; const ASeller, ABuyer: TLandrixEInvoiceString);
begin
  Invoice.AccountingSupplierParty.Address.CountryCode := ASeller;
  Invoice.AccountingCustomerParty.Address.CountryCode := ABuyer;
end;

procedure SetPayment(Invoice: TLandrixInvoice; const AOther, AAccount: TLandrixEInvoiceString);
begin
  Invoice.PaymentTypes[0].PaymentMeansCode := ipmc_NotImplemented;
  Invoice.PaymentTypes[0].PaymentMeansCodeOther := AOther;
  Invoice.PaymentTypes[0].FinancialAccount := AAccount;
end;

function AddReference(Invoice: TLandrixInvoice; const AID, ADescription: TLandrixEInvoiceString):
  TLandrixInvoiceAttachment;
begin
  Result := Invoice.Attachments.AddAttachment(iat_application_pdf);
  Result.ID := AID;
  Result.DocumentDescription := ADescription;
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

procedure SetCompanyID(AParty: TLandrixInvoiceAccountingParty; const AValue, AScheme: TLandrixEInvoiceString);
begin
  AParty.CompanyID := AValue;
  AParty.CompanyIDSchemeID := AScheme;
end;

{ Breaks rule AID in a complete invoice (seller and buyer in Germany). }
procedure Mutate(Invoice: TLandrixInvoice; const AID: string);
var
  Seller, Buyer: TLandrixInvoiceAccountingParty;
  Line: TLandrixInvoiceLine;
  Payment: TLandrixInvoicePaymentType;
  Item: TLandrixInvoiceAllowanceCharge;
begin
  Seller := Invoice.AccountingSupplierParty;
  Buyer := Invoice.AccountingCustomerParty;
  Line := Invoice.InvoiceLines[0];
  Payment := Invoice.PaymentTypes[0];
  { the country first }
  if Copy(AID, 1, 3) = 'NO-' then
    Seller.VATCompanyID := 'NO987654325MVA'
  else if Copy(AID, 1, 3) = 'DK-' then
    SetCountries(Invoice, 'DK', 'DK')
  else if Copy(AID, 1, 3) = 'IT-' then
  begin
    SetCountries(Invoice, 'IT', 'DE');
    Seller.VATCompanyID := 'IT00743110157';
  end
  else if Copy(AID, 1, 3) = 'SE-' then
  begin
    SetCountries(Invoice, 'SE', 'DE');
    Seller.VATCompanyID := 'SE556036079301';
    SetCompanyID(Seller, '5560360793', '0007');
  end
  else if Copy(AID, 1, 3) = 'GR-' then
  begin
    SetCountries(Invoice, 'GR', 'DE');
    Seller.VATCompanyID := 'EL094014201';
    Seller.Name := 'Seller';
    Buyer.Name := 'Buyer';
    Seller.ElectronicAddressSellerBuyer := '094014201';
    Seller.ElectronicAddressSellerBuyerSchemeID := '9933';
    Invoice.InvoiceNumber := '094014201|20/10/2026|1|1.1|A|1';
    AddReference(Invoice, '1', '##M.AR.K##');
    AddReference(Invoice, 'U-1', '##INVOICE|URL##').ExternalReference := 'https://example.org/i';
  end
  else if Copy(AID, 1, 3) = 'IS-' then
    SetCountries(Invoice, 'IS', 'DE')
  else if Copy(AID, 1, 3) = 'NL-' then
    SetCountries(Invoice, 'NL', 'DE');
  { the core rules }
  if AID = 'PEPPOL-EN16931-R002' then
  begin
    Buyer.Address.CountryCode := 'AT';
    Invoice.Notes.AddNote.Content := 'A';
    Invoice.Notes.AddNote.Content := 'B';
  end
  else if AID = 'PEPPOL-EN16931-R007' then
    Invoice.ProfileID := 'urn:example'
  else if AID = 'PEPPOL-EN16931-P0100' then
  begin
    Invoice.InvoiceTypeCode := itc_None;
    Invoice.InvoiceTypeCodeOther := '389';
  end
  else if AID = 'PEPPOL-EN16931-P0104' then
    Invoice.TaxAmountSubtotals[0].TaxExemptionReasonCode := 'VATEX-EU-G'
  else if AID = 'PEPPOL-EN16931-P0105' then
    Invoice.TaxAmountSubtotals[0].TaxExemptionReasonCode := 'vatex-eu-o'
  else if AID = 'PEPPOL-EN16931-P0106' then
    Invoice.TaxAmountSubtotals[0].TaxExemptionReasonCode := 'VATEX-EU-IC'
  else if AID = 'PEPPOL-EN16931-P0107' then
    Invoice.TaxAmountSubtotals[0].TaxExemptionReasonCode := 'VATEX-EU-AE'
  else if AID = 'PEPPOL-EN16931-P0108' then
    Invoice.TaxAmountSubtotals[0].TaxExemptionReasonCode := 'VATEX-EU-D'
  else if AID = 'PEPPOL-EN16931-P0109' then
    Invoice.TaxAmountSubtotals[0].TaxExemptionReasonCode := 'VATEX-EU-F'
  else if AID = 'PEPPOL-EN16931-P0110' then
    Invoice.TaxAmountSubtotals[0].TaxExemptionReasonCode := 'VATEX-EU-I'
  else if AID = 'PEPPOL-EN16931-P0111' then
    Invoice.TaxAmountSubtotals[0].TaxExemptionReasonCode := 'VATEX-EU-J'
  else if AID = 'PEPPOL-EN16931-P0112' then
  begin
    Buyer.Address.CountryCode := 'AT';
    Invoice.InvoiceTypeCode := itc_CorrectedInvoice;
  end
  else if AID = 'PEPPOL-EN16931-CL001' then
  begin
    AddPdf(Invoice, 'A-1', 'a.zip');
    Invoice.Attachments[0].AttachmentType := iat_application_None;
    Invoice.Attachments[0].AttachmentTypeOther := 'application/zip';
  end
  else if (AID = 'PEPPOL-EN16931-CL002') or (AID = 'PEPPOL-EN16931-CL003') then
  begin
    Item := Line.AllowanceCharges.AddAllowanceCharge;
    Item.ChargeIndicator := AID = 'PEPPOL-EN16931-CL003';
    Item.Amount := 1;
    if Item.ChargeIndicator then
      Item.ReasonCodeChargeOther := 'XX1'
    else
      Item.ReasonCodeAllowanceOther := '1';
  end
  else if AID = 'PEPPOL-EN16931-CL006' then
    Invoice.TaxPointDateCode := '5'
  else if AID = 'PEPPOL-EN16931-CL007' then
    Invoice.InvoiceCurrencyCode := 'EURO'
  else if AID = 'PEPPOL-EN16931-CL008' then
    Seller.ElectronicAddressSellerBuyerSchemeID := 'EM'
  { PEPPOL-COMMON }
  else if AID = 'PEPPOL-COMMON-R040' then
    Buyer.GlobalIdentifierSellerBuyer := '4000001000006'
  else if AID = 'PEPPOL-COMMON-R041' then
    SetCompanyID(Seller, '123456789', '0192')
  else if AID = 'PEPPOL-COMMON-R042' then
    SetCompanyID(Seller, '1234567', '0184')
  else if AID = 'PEPPOL-COMMON-R043' then
    SetCompanyID(Buyer, '0739484053', '0208')
  else if AID = 'PEPPOL-COMMON-R044' then
    SetCompanyID(Seller, 'UFXY1', '0201')
  else if AID = 'PEPPOL-COMMON-R045' then
    SetCompanyID(Seller, 'ABC', '0210')
  else if AID = 'PEPPOL-COMMON-R046' then
  begin
    Buyer.ElectronicAddressSellerBuyer := 'ABC';
    Buyer.ElectronicAddressSellerBuyerSchemeID := '9907';
  end
  else if AID = 'PEPPOL-COMMON-R047' then
    SetCompanyID(Seller, 'IT12345678901', '0211')
  else if AID = 'PEPPOL-COMMON-R049' then
    SetCompanyID(Seller, '1234567890', '0007')
  else if AID = 'PEPPOL-COMMON-R050' then
    SetCompanyID(Seller, '12345678901', '0151')
  else if AID = 'PEPPOL-COMMON-R052' then
    SetCompanyID(Seller, '123', '0096')
  else if AID = 'PEPPOL-COMMON-R053' then
    SetCompanyID(Seller, 'DK123', '0198')
  else if AID = 'PEPPOL-COMMON-R054' then
    SetCompanyID(Seller, 'X123', '0106')
  else if AID = 'PEPPOL-COMMON-R055' then
    SetCompanyID(Seller, '123', '0190')
  else if AID = 'PEPPOL-COMMON-R056-1' then
    SetCompanyID(Seller, 'NL123', '9944')
  else if AID = 'PEPPOL-COMMON-R056-2' then
    Buyer.VATCompanyID := 'NL123'
  else if AID = 'PEPPOL-COMMON-R057' then
    SetCompanyID(Seller, '123', '0217')
  { Norway }
  else if AID = 'NO-R-001' then
    Seller.VATCompanyID := 'NO987654325'
  else if AID = 'NO-R-002' then
    { the mapper writes no tax registration with scheme TAX }
  { Denmark }
  else if AID = 'DK-R-002' then
    Seller.CompanyID := ''
  else if AID = 'DK-R-003' then
    with Line.ItemClassifications.AddItemClassification do
    begin
      ClassCode := '43211503';
      ListID := 'TST';
    end
  else if AID = 'DK-R-004' then
  begin
    Item := Invoice.AllowanceCharges.AddAllowanceCharge;
    Item.Amount := 1;
    Item.ReasonCodeAllowanceOther := 'ZZZ';
    Item.Reason := 'Discount';
  end
  else if AID = 'DK-R-005' then
    SetPayment(Invoice, '30', 'DK5000400440116243')
  else if AID = 'DK-R-006' then
    SetPayment(Invoice, '31', 'DK5000400440116243')
  else if AID = 'DK-R-007' then
    Payment.PaymentMeansCode := ipmc_DirectDebit
  else if AID = 'DK-R-008' then
  begin
    SetPayment(Invoice, '50', '1234567');
    Invoice.PaymentID := '99#1';
  end
  else if AID = 'DK-R-009' then
  begin
    SetPayment(Invoice, '50', '1234567');
    Invoice.PaymentID := '04#1';
  end
  else if AID = 'DK-R-010' then
  begin
    SetPayment(Invoice, '93', '12345678');
    Invoice.PaymentID := '99#';
  end
  else if AID = 'DK-R-011' then
  begin
    SetPayment(Invoice, '93', '12345678');
    Invoice.PaymentID := '71#1';
  end
  else if AID = 'DK-R-013' then
    Seller.IdentifierSellerBuyer := 'S-1'
  else if AID = 'DK-R-014' then
    SetCompanyID(Seller, '12345678', '0088')
  else if AID = 'DK-R-016' then
  begin
    Invoice.InvoiceTypeCode := itc_CreditNote;
    Invoice.PayableAmount := -1;
  end
  else if AID = 'DK-R-017' then
    SetCompanyID(Buyer, '12345678', '0088')
  { Italy }
  else if AID = 'IT-R-001' then
    Seller.VATCompanyNumber := 'abc'
  else if AID = 'IT-R-002' then
    Seller.Address.StreetName := ''
  else if AID = 'IT-R-003' then
    Seller.Address.City := ''
  else if AID = 'IT-R-004' then
    Seller.Address.PostalZone := ''
  { Sweden }
  else if AID = 'SE-R-001' then
    Seller.VATCompanyID := 'SE5560360793'
  else if AID = 'SE-R-002' then
    Seller.VATCompanyID := 'SEABCDEFGHIJ01'
  else if AID = 'SE-R-003' then
    Seller.CompanyID := 'ABC'
  else if AID = 'SE-R-004' then
    Seller.CompanyID := '123'
  else if AID = 'SE-R-005' then
    Seller.VATCompanyNumber := 'x'
  else if AID = 'SE-R-006' then
    { the complete invoice has 19 % }
  else if (AID = 'SE-R-007') or (AID = 'SE-R-010') or (AID = 'SE-R-008') or (AID = 'SE-R-009') then
  begin
    if (AID = 'SE-R-007') or (AID = 'SE-R-008') then
      SetPayment(Invoice, '30', 'ABC')
    else
      SetPayment(Invoice, '30', '123456789');
    if (AID = 'SE-R-007') or (AID = 'SE-R-010') then
      Payment.FinancialInstitutionBranch := 'SE:PLUSGIRO'
    else
      Payment.FinancialInstitutionBranch := 'SE:BANKGIRO';
  end
  else if AID = 'SE-R-011' then
    SetPayment(Invoice, '50', '123')
  else if AID = 'SE-R-012' then
  begin
    Buyer.Address.CountryCode := 'SE';
    SetPayment(Invoice, '31', '123');
  end
  else if AID = 'SE-R-013' then
    Seller.CompanyID := '1234567890'
  { Greece }
  else if AID = 'GR-R-001-1' then
    Invoice.InvoiceNumber := 'R-1'
  else if AID = 'GR-R-001-2' then
    Invoice.InvoiceNumber := '123456783|20/10/2026|1|1.1|A|1'
  else if AID = 'GR-R-001-3' then
    Invoice.InvoiceNumber := '094014201|21/10/2026|1|1.1|A|1'
  else if AID = 'GR-R-001-4' then
    Invoice.InvoiceNumber := '094014201|20/10/2026|-1|1.1|A|1'
  else if AID = 'GR-R-001-5' then
    Invoice.InvoiceNumber := '094014201|20/10/2026|1|9.9|A|1'
  else if AID = 'GR-R-001-6' then
    Invoice.InvoiceNumber := '094014201|20/10/2026|1|1.1||1'
  else if AID = 'GR-R-001-7' then
    Invoice.InvoiceNumber := '094014201|20/10/2026|1|1.1|A|'
  else if AID = 'GR-R-002' then
    Seller.Name := ''
  else if (AID = 'GR-R-003') or (AID = 'GR-S-011') then
    Seller.VATCompanyID := 'EL123456789'
  else if AID = 'GR-R-004-1' then
    Invoice.Attachments[0].DocumentDescription := 'MARK'
  else if AID = 'GR-R-004-2' then
    Invoice.Attachments[0].ID := '0'
  else if AID = 'GR-R-005' then
    Buyer.Name := ''
  else if AID = 'GR-R-006' then
    Buyer.VATCompanyID := 'EL123456789'
  else if AID = 'GR-R-008-2' then
    AddReference(Invoice, 'U-2', '##INVOICE|URL##').ExternalReference := 'https://example.org/j'
  else if AID = 'GR-R-008-3' then
    Invoice.Attachments[1].ExternalReference := ''
  else if AID = 'GR-R-009' then
    Seller.ElectronicAddressSellerBuyer := '123456789'
  else if AID = 'GR-R-010' then
    Buyer.VATCompanyID := 'EL094019245'
  else if AID = 'GR-S-008-1' then
    Invoice.Attachments[1].DocumentDescription := 'URL'
  { Iceland }
  else if AID = 'IS-R-001' then
    Invoice.InvoiceTypeCode := itc_CorrectedInvoice
  else if AID = 'IS-R-002' then
    SetCompanyID(Seller, '1234567890', '0088')
  else if AID = 'IS-R-003' then
    Seller.Address.StreetName := ''
  else if (AID = 'IS-R-004') or (AID = 'IS-R-005') then
    Buyer.Address.CountryCode := 'IS'
  else if AID = 'IS-R-006' then
    SetPayment(Invoice, '9', '123')
  else if AID = 'IS-R-007' then
    SetPayment(Invoice, '42', '123')
  else if AID = 'IS-R-008' then
    AddReference(Invoice, '2026-02-30', 'EINDAGI')
  else if AID = 'IS-R-009' then
  begin
    AddReference(Invoice, '2026-12-01', 'EINDAGI');
    Invoice.InvoiceDueDate := 0;
  end
  else if AID = 'IS-R-010' then
    AddReference(Invoice, '2026-11-01', 'EINDAGI')
  { the Netherlands }
  else if AID = 'NL-R-001' then
    Invoice.InvoiceTypeCode := itc_CreditNote
  else if AID = 'NL-R-002' then
    Seller.Address.StreetName := ''
  else if AID = 'NL-R-003' then
    SetCompanyID(Seller, '12345678', '0088')
  else if AID = 'NL-R-004' then
    Buyer.Address.CountryCode := 'NL'
  else if AID = 'NL-R-005' then
  begin
    Buyer.Address.CountryCode := 'NL';
    SetCompanyID(Buyer, '12345678', '0088');
  end
  else if AID = 'NL-R-006' then
  begin
    Invoice.TaxRepresentativeParty.Name := 'Representative';
    Invoice.TaxRepresentativeParty.Address.City := 'Utrecht';
    Invoice.TaxRepresentativeParty.Address.CountryCode := 'NL';
  end
  else if AID = 'NL-R-007' then
    Invoice.PaymentTypes.Clear
  else if AID = 'NL-R-008' then
  begin
    Buyer.Address.CountryCode := 'NL';
    SetPayment(Invoice, '31', 'NL91ABNA0417164300');
  end
  else if AID = 'NL-R-009' then
    Line.OrderLineReference := '1'
  { Germany }
  else if AID = 'DE-R-001' then
    Invoice.PaymentTypes.Clear
  else if AID = 'DE-R-002' then
  begin
    Seller.ContactName := '';
    Seller.ContactTelephone := '';
    Seller.ContactElectronicMail := '';
  end
  else if AID = 'DE-R-003' then
    Seller.Address.City := ''
  else if AID = 'DE-R-004' then
    Seller.Address.PostalZone := ''
  else if AID = 'DE-R-005' then
    Seller.ContactName := ''
  else if AID = 'DE-R-006' then
    Seller.ContactTelephone := ''
  else if AID = 'DE-R-007' then
    Seller.ContactElectronicMail := ''
  else if AID = 'DE-R-008' then
    Buyer.Address.City := ''
  else if AID = 'DE-R-009' then
    Buyer.Address.PostalZone := ''
  else if AID = 'DE-R-010' then
  begin
    Invoice.DeliveryInformation.Address.PostalZone := '53111';
    Invoice.DeliveryInformation.Address.CountryCode := 'DE';
  end
  else if AID = 'DE-R-011' then
  begin
    Invoice.DeliveryInformation.Address.City := 'Bonn';
    Invoice.DeliveryInformation.Address.CountryCode := 'DE';
  end
  else if AID = 'DE-R-015' then
    Invoice.BuyerReference := ' '
  else if AID = 'DE-R-016' then
    Seller.VATCompanyID := ''
  else if AID = 'DE-R-017' then
  begin
    Invoice.InvoiceTypeCode := itc_None;
    Invoice.InvoiceTypeCodeOther := '388';
  end
  else if AID = 'DE-R-018' then
  begin
    Invoice.PaymentTermsType := iptt_CashDiscount1;
    Invoice.PaymentTermCashDiscount1Days := -1;
    Invoice.PaymentTermCashDiscount1Percent := 2;
  end
  else if AID = 'DE-R-019' then
    Payment.FinancialAccount := 'DE02120300000000202052'
  else if (AID = 'DE-R-020') or (AID = 'DE-R-030') or (AID = 'DE-R-031') then
  begin
    Payment.PaymentMeansCode := ipmc_SEPADirectDebit;
    Invoice.PaymentMandateID := 'M-1';
    if AID <> 'DE-R-030' then
      Seller.BankAssignedCreditorIdentifier := 'DE98ZZZ09999999999';
    if AID = 'DE-R-020' then
      Payment.FinancialAccount := 'DE02120300000000202052'
    else if AID = 'DE-R-031' then
      Payment.FinancialAccount := '';
  end
  else if AID = 'DE-R-022' then
  begin
    AddPdf(Invoice, 'A-1', 'a.pdf');
    AddPdf(Invoice, 'A-2', 'a.pdf');
  end
  else if AID = 'DE-R-023-1' then
    Payment.FinancialAccount := ''
  else if AID = 'DE-R-024-1' then
    SetPayment(Invoice, '48', '')
  else if AID = 'DE-R-024-2' then
    SetPayment(Invoice, '48', 'DE02120300000000202051')
  else if AID = 'DE-R-025-1' then
    SetPayment(Invoice, '59', '')
  else if AID = 'DE-R-025-2' then
    SetPayment(Invoice, '59', 'DE02120300000000202051')
  else if AID = 'DE-R-026' then
    Invoice.InvoiceTypeCode := itc_CorrectedInvoice
  else if AID = 'DE-R-027' then
    Seller.ContactTelephone := '+49'
  else if AID = 'DE-R-028' then
    Seller.ContactElectronicMail := 'accounting'
  else if AID = 'DE-R-T02' then
    AddReference(Invoice, 'A-1', 'Link').ExternalReference := 'example.org/a'
  else
    Fail('no mutation for ' + AID);
end;

const
  { Every rule of LandrixEInvoiceCheckPeppol. }
  PeppolRules: array[0..134] of string = (
    'PEPPOL-EN16931-R002', 'PEPPOL-EN16931-R007', 'PEPPOL-EN16931-P0100', 'PEPPOL-EN16931-P0104',
    'PEPPOL-EN16931-P0105', 'PEPPOL-EN16931-P0106', 'PEPPOL-EN16931-P0107', 'PEPPOL-EN16931-P0108',
    'PEPPOL-EN16931-P0109', 'PEPPOL-EN16931-P0110', 'PEPPOL-EN16931-P0111', 'PEPPOL-EN16931-P0112',
    'PEPPOL-EN16931-CL001', 'PEPPOL-EN16931-CL002', 'PEPPOL-EN16931-CL003', 'PEPPOL-EN16931-CL006',
    'PEPPOL-EN16931-CL007', 'PEPPOL-EN16931-CL008',
    'PEPPOL-COMMON-R040', 'PEPPOL-COMMON-R041', 'PEPPOL-COMMON-R042', 'PEPPOL-COMMON-R043',
    'PEPPOL-COMMON-R044', 'PEPPOL-COMMON-R045', 'PEPPOL-COMMON-R046', 'PEPPOL-COMMON-R047',
    'PEPPOL-COMMON-R049', 'PEPPOL-COMMON-R050', 'PEPPOL-COMMON-R052', 'PEPPOL-COMMON-R053',
    'PEPPOL-COMMON-R054', 'PEPPOL-COMMON-R055', 'PEPPOL-COMMON-R056-1', 'PEPPOL-COMMON-R056-2',
    'PEPPOL-COMMON-R057',
    'NO-R-001', 'NO-R-002',
    'DK-R-002', 'DK-R-003', 'DK-R-004', 'DK-R-005', 'DK-R-006', 'DK-R-007', 'DK-R-008', 'DK-R-009', 'DK-R-010',
    'DK-R-011', 'DK-R-013', 'DK-R-014', 'DK-R-016', 'DK-R-017',
    'IT-R-001', 'IT-R-002', 'IT-R-003', 'IT-R-004',
    'SE-R-001', 'SE-R-002', 'SE-R-003', 'SE-R-004', 'SE-R-005', 'SE-R-006', 'SE-R-007', 'SE-R-008', 'SE-R-009',
    'SE-R-010', 'SE-R-011', 'SE-R-012', 'SE-R-013',
    'GR-R-001-1', 'GR-R-001-2', 'GR-R-001-3', 'GR-R-001-4', 'GR-R-001-5', 'GR-R-001-6', 'GR-R-001-7',
    'GR-R-002', 'GR-R-003', 'GR-R-004-1', 'GR-R-004-2', 'GR-R-005', 'GR-R-006', 'GR-R-008-2', 'GR-R-008-3',
    'GR-R-009', 'GR-R-010', 'GR-S-008-1', 'GR-S-011',
    'IS-R-001', 'IS-R-002', 'IS-R-003', 'IS-R-004', 'IS-R-005', 'IS-R-006', 'IS-R-007', 'IS-R-008', 'IS-R-009',
    'IS-R-010',
    'NL-R-001', 'NL-R-002', 'NL-R-003', 'NL-R-004', 'NL-R-005', 'NL-R-006', 'NL-R-007', 'NL-R-008', 'NL-R-009',
    'DE-R-001', 'DE-R-002', 'DE-R-003', 'DE-R-004', 'DE-R-005', 'DE-R-006', 'DE-R-007', 'DE-R-008', 'DE-R-009',
    'DE-R-010', 'DE-R-011', 'DE-R-015', 'DE-R-016', 'DE-R-017', 'DE-R-018', 'DE-R-019', 'DE-R-020', 'DE-R-022',
    'DE-R-023-1', 'DE-R-024-1', 'DE-R-024-2', 'DE-R-025-1', 'DE-R-025-2', 'DE-R-026', 'DE-R-027', 'DE-R-028',
    'DE-R-030', 'DE-R-031', 'DE-R-T02');

  PeppolWarnings = ' PEPPOL-COMMON-R044 PEPPOL-COMMON-R045 PEPPOL-COMMON-R046 PEPPOL-COMMON-R047 ' +
    'PEPPOL-COMMON-R054 PEPPOL-COMMON-R055 PEPPOL-COMMON-R056-1 PEPPOL-COMMON-R056-2 PEPPOL-COMMON-R057 ' +
    'NO-R-002 SE-R-007 SE-R-008 SE-R-009 SE-R-010 SE-R-011 SE-R-012 GR-S-008-1 GR-S-011 IS-R-001 DE-R-017 ' +
    'DE-R-019 DE-R-020 DE-R-026 DE-R-027 DE-R-028 DE-R-T02 ';

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

{ The complete invoice meets every Peppol rule; with the country of a
  national rule set it still does. }
procedure TestComplete;
var
  Invoice: TLandrixInvoice;
  D: TLandrixEInvoiceDiagnostics;
  N: Integer;
begin
  D := TLandrixEInvoiceDiagnostics.Create;
  Invoice := TLandrixInvoice.Create;
  try
    FillComplete(Invoice);
    N := LandrixEInvoiceCheckInvoice(Invoice, PeppolSpec, D);
    CheckEquals(0, N, 'errors: ' + string(D.ToText));
    CheckEqualsStr('', string(D.ToText), 'diagnostics');
  finally
    Invoice.Free;
    D.Free;
  end;
end;

{ Each rule fires once for Peppol, with its severity, and holds for
  XRechnung (known, not applicable). }
procedure TestRuleCases;
var
  Invoice: TLandrixInvoice;
  D: TLandrixEInvoiceDiagnostics;
  I: Integer;
  ID: string;
begin
  D := TLandrixEInvoiceDiagnostics.Create;
  try
    for I := Low(PeppolRules) to High(PeppolRules) do
    begin
      ID := PeppolRules[I];
      Invoice := TLandrixInvoice.Create;
      try
        FillComplete(Invoice);
        Mutate(Invoice, ID);
        D.Clear;
        Check(not LandrixEInvoiceCheckRule(Invoice, PeppolSpec, TLandrixEInvoiceString(ID), D), ID + ' violated');
        CheckEquals(1, Integer(D.Count), ID + ' one diagnostic');
        if D.Count = 1 then
        begin
          CheckEqualsInvoiceStr(TLandrixEInvoiceString(ID), D[0].RuleID, ID + ' rule of the diagnostic');
          if Pos(' ' + ID + ' ', PeppolWarnings) > 0 then
            Check(D[0].Severity = eds_Warning, ID + ' warning')
          else
            Check(D[0].Severity = eds_Error, ID + ' error');
        end;
        D.Clear;
        LandrixEInvoiceCheckInvoice(Invoice, PeppolSpec, D);
        Check(HasRule(D, ID), ID + ' reported by LandrixEInvoiceCheckInvoice');
        Check(LandrixEInvoiceCheckRule(Invoice, XRechnungSpec, TLandrixEInvoiceString(ID), nil),
          ID + ' does not apply to XRechnung');
      finally
        Invoice.Free;
      end;
    end;
  finally
    D.Free;
  end;
end;

{ The national rules apply to their countries only: seller in Austria, or
  only one German party. }
procedure TestCountries;
var
  Invoice: TLandrixInvoice;
begin
  Invoice := TLandrixInvoice.Create;
  try
    FillComplete(Invoice);
    Invoice.BuyerReference := '';
    Invoice.SellerOrderReference := 'SO-1';
    Check(not LandrixEInvoiceCheckRule(Invoice, PeppolSpec, 'DE-R-015', nil), 'both German');
    Invoice.AccountingCustomerParty.Address.CountryCode := ' de ';
    Check(not LandrixEInvoiceCheckRule(Invoice, PeppolSpec, 'DE-R-015', nil), 'normalized, upper case');
    Invoice.AccountingCustomerParty.Address.CountryCode := 'AT';
    Check(LandrixEInvoiceCheckRule(Invoice, PeppolSpec, 'DE-R-015', nil), 'buyer in Austria');
    { Denmark compares the country as it is written }
    Invoice.AccountingSupplierParty.Address.CountryCode := 'dk';
    Invoice.AccountingSupplierParty.CompanyID := '';
    Check(LandrixEInvoiceCheckRule(Invoice, PeppolSpec, 'DK-R-002', nil), 'dk is not DK');
    Invoice.AccountingSupplierParty.Address.CountryCode := 'DK';
    Check(not LandrixEInvoiceCheckRule(Invoice, PeppolSpec, 'DK-R-002', nil), 'DK');
    { $supplierCountry: the VAT prefix wins over the postal country }
    Invoice.AccountingSupplierParty.VATCompanyID := 'NO987654325';
    Check(not LandrixEInvoiceCheckRule(Invoice, PeppolSpec, 'NO-R-001', nil), 'VAT prefix NO');
    Invoice.AccountingSupplierParty.VATCompanyID := '';
    Invoice.TaxRepresentativeParty.Name := 'Representative';
    Invoice.TaxRepresentativeParty.VATCompanyID := 'NO987654325';
    Check(LandrixEInvoiceCheckRule(Invoice, PeppolSpec, 'NO-R-001', nil),
      'NO-R-001 tests the seller VAT identifier only');
    Check(not LandrixEInvoiceCheckRule(Invoice, PeppolSpec, 'NO-R-002', nil), 'tax representative VAT prefix NO');
  finally
    Invoice.Free;
  end;
end;

{ The identifiers the PEPPOL-COMMON rules assume are those of the mapped
  UBL model: the global identifier with the default scheme 0088, the legal
  registration and the electronic address with their schemes, the payee
  identifier; the identifier without scheme is left out next to a global
  one. }
procedure TestWrittenIdentifiers;
var
  Invoice: TLandrixInvoice;
  UBL: TLandrixUBLInvoice;
  D: TLandrixEInvoiceDiagnostics;
begin
  D := TLandrixEInvoiceDiagnostics.Create;
  Invoice := TLandrixInvoice.Create;
  try
    FillComplete(Invoice);
    Invoice.AccountingSupplierParty.GlobalIdentifierSellerBuyer := '4000001000006';
    Invoice.AccountingSupplierParty.IdentifierSellerBuyer := 'S-1';
    Invoice.AccountingSupplierParty.CompanyID := '123';
    Invoice.AccountingSupplierParty.CompanyIDSchemeID := '0096';
    Invoice.PayeeParty.Name := 'Payee';
    Invoice.PayeeParty.Identifier := 'UFXY1';
    Invoice.PayeeParty.IdentifierSchemeID := '0201';
    Check(not LandrixEInvoiceCheckRule(Invoice, PeppolSpec, 'PEPPOL-COMMON-R040', nil), 'R040 on the global identifier');
    Check(not LandrixEInvoiceCheckRule(Invoice, PeppolSpec, 'PEPPOL-COMMON-R052', nil), 'R052 on the legal registration');
    Check(not LandrixEInvoiceCheckRule(Invoice, PeppolSpec, 'PEPPOL-COMMON-R044', nil), 'R044 on the payee identifier');
    UBL := LandrixEInvoiceInvoiceToUBLInvoice(Invoice, PeppolSpec, D);
    try
      CheckEquals(1, Integer(UBL.AccountingSupplierParty.Party.PartyIdentification.Count),
        'one seller identifier: the global one');
      CheckEqualsInvoiceStr('0088', UBL.AccountingSupplierParty.Party.PartyIdentification[0].ID.SchemeID,
        'default scheme 0088');
      CheckEqualsInvoiceStr('4000001000006', UBL.AccountingSupplierParty.Party.PartyIdentification[0].ID.Value,
        'global identifier');
      CheckEqualsInvoiceStr('0096', UBL.AccountingSupplierParty.Party.PartyLegalEntity[0].CompanyID.SchemeID,
        'legal registration scheme');
      CheckEqualsInvoiceStr('9930', UBL.AccountingSupplierParty.Party.EndpointID.SchemeID, 'electronic address scheme');
      CheckEqualsInvoiceStr('0201', UBL.PayeeParty.PartyIdentification[0].ID.SchemeID, 'payee identifier scheme');
    finally
      UBL.Free;
    end;
  finally
    Invoice.Free;
    D.Free;
  end;
end;

{ A Peppol identifier is known to LandrixEInvoiceCheckRule for every
  target; an unknown one raises. }
procedure TestRuleLookup;
var
  Invoice: TLandrixInvoice;
  Raised: Boolean;
begin
  Invoice := TLandrixInvoice.Create;
  try
    Check(LandrixEInvoiceCheckRule(Invoice, XRechnungSpec, 'DE-R-001', nil), 'not applicable to XRechnung');
    Raised := False;
    try
      LandrixEInvoiceCheckRule(Invoice, PeppolSpec, 'DE-R-999', nil);
    except
      on ELandrixEInvoiceError do
        Raised := True;
    end;
    Check(Raised, 'unknown rule raises');
  finally
    Invoice.Free;
  end;
end;

{ Payment rules: a German SEPA direct debit with creditor identifier as
  the payee's (written there) meets DE-R-030; a Danish credit transfer 31
  with account and branch meets DK-R-006; the payable amount decides
  NL-R-007. }
procedure TestPayments;
var
  Invoice: TLandrixInvoice;
begin
  Invoice := TLandrixInvoice.Create;
  try
    FillComplete(Invoice);
    Invoice.PaymentTypes[0].PaymentMeansCode := ipmc_SEPADirectDebit;
    Invoice.PaymentMandateID := 'M-1';
    Invoice.AccountingSupplierParty.BankAssignedCreditorIdentifier := 'DE98ZZZ09999999999';
    Invoice.PayeeParty.Name := 'Payee';
    Check(LandrixEInvoiceCheckRule(Invoice, PeppolSpec, 'DE-R-030', nil), 'creditor identifier at the payee');
    Check(LandrixEInvoiceCheckRule(Invoice, PeppolSpec, 'DE-R-031', nil), 'debited account');
    Check(LandrixEInvoiceCheckRule(Invoice, PeppolSpec, 'DE-R-025-1', nil), 'mandate written');
    Invoice.AccountingSupplierParty.Address.CountryCode := 'DK';
    Invoice.AccountingCustomerParty.Address.CountryCode := 'DK';
    Invoice.PaymentTypes[0].PaymentMeansCode := ipmc_DebitTransfer;
    Invoice.PaymentTypes[0].FinancialInstitutionBranch := 'DABADKKK';
    Check(LandrixEInvoiceCheckRule(Invoice, PeppolSpec, 'DK-R-006', nil), 'account and branch');
    Invoice.AccountingSupplierParty.Address.CountryCode := 'NL';
    Invoice.PaymentTypes.Clear;
    Check(not LandrixEInvoiceCheckRule(Invoice, PeppolSpec, 'NL-R-007', nil), 'amount due without payment means');
    Invoice.PayableAmount := 0;
    Check(LandrixEInvoiceCheckRule(Invoice, PeppolSpec, 'NL-R-007', nil), 'nothing due');
    Invoice.InvoiceTypeCode := itc_CreditNote;
    Invoice.PayableAmount := CentsValue(-1);
    Check(not LandrixEInvoiceCheckRule(Invoice, PeppolSpec, 'NL-R-007', nil), 'credit note with negative amount');
  finally
    Invoice.Free;
  end;
end;

{ SE-R-013 checks the first ten digits only (u:checkSEOrgnr), SE-R-004
  the length; a preceding invoice reference with its date only exists for
  DE-R-026, not for NL-R-001 (cbc:ID). }
procedure TestEdgeCases;
var
  Invoice: TLandrixInvoice;
begin
  Invoice := TLandrixInvoice.Create;
  try
    FillComplete(Invoice);
    SetCountries(Invoice, 'SE', 'DE');
    SetCompanyID(Invoice.AccountingSupplierParty, '55603607931', '0088');
    Check(LandrixEInvoiceCheckRule(Invoice, PeppolSpec, 'SE-R-013', nil), 'SE-R-013: first ten digits valid');
    Check(not LandrixEInvoiceCheckRule(Invoice, PeppolSpec, 'SE-R-004', nil), 'SE-R-004: eleven digits');
    SetCompanyID(Invoice.AccountingSupplierParty, '556036079X', '0088');
    Check(not LandrixEInvoiceCheckRule(Invoice, PeppolSpec, 'SE-R-013', nil), 'SE-R-013: not digits');
    SetCountries(Invoice, 'DE', 'DE');
    Invoice.InvoiceTypeCode := itc_CorrectedInvoice;
    Invoice.PrecedingInvoiceReferences.AddPrecedingInvoiceReference.IssueDate := EncodeDate(2026, 10, 1);
    Check(LandrixEInvoiceCheckRule(Invoice, PeppolSpec, 'DE-R-026', nil), 'DE-R-026: reference with date');
    SetCountries(Invoice, 'NL', 'DE');
    Invoice.InvoiceTypeCode := itc_CreditNote;
    Check(not LandrixEInvoiceCheckRule(Invoice, PeppolSpec, 'NL-R-001', nil), 'NL-R-001: no cbc:ID');
  finally
    Invoice.Free;
  end;
  { a date the writers cannot format: the rules that format it hold
    (LandrixEInvoiceCheckInvoice reports the date) }
  Invoice := TLandrixInvoice.Create;
  try
    FillComplete(Invoice);
    Mutate(Invoice, 'IS-R-010');
    Invoice.InvoiceDueDate := EncodeDate(9999, 12, 31) + 1;
    Check(LandrixEInvoiceCheckRule(Invoice, PeppolSpec, 'IS-R-010', nil), 'IS-R-010: due date beyond 9999');
    Check(LandrixEInvoiceCheckRule(Invoice, PeppolSpec, 'IS-R-009', nil), 'IS-R-009: due date beyond 9999');
  finally
    Invoice.Free;
  end;
  Invoice := TLandrixInvoice.Create;
  try
    FillComplete(Invoice);
    Mutate(Invoice, 'GR-R-001-3');
    Invoice.InvoiceIssueDate := EncodeDate(9999, 12, 31) + 1;
    Check(LandrixEInvoiceCheckRule(Invoice, PeppolSpec, 'GR-R-001-3', nil), 'GR-R-001-3: issue date beyond 9999');
  finally
    Invoice.Free;
  end;
end;

procedure Register;
begin
  RegisterTest('CheckPeppol.Complete', TestComplete);
  RegisterTest('CheckPeppol.RuleCases', TestRuleCases);
  RegisterTest('CheckPeppol.Countries', TestCountries);
  RegisterTest('CheckPeppol.WrittenIdentifiers', TestWrittenIdentifiers);
  RegisterTest('CheckPeppol.RuleLookup', TestRuleLookup);
  RegisterTest('CheckPeppol.Payments', TestPayments);
  RegisterTest('CheckPeppol.EdgeCases', TestEdgeCases);
end;

end.
