{
  EInvoice-for-Pascal

  Copyright (C) 2026 Landrix Software GmbH & Co. KG

  This file is dual-licensed under:
  - GNU GPL version 3 or later; or
  - the Landrix Software Commercial License.

  See LICENSE and COMMERCIAL-LICENSE.md.

  SPDX-License-Identifier: GPL-3.0-or-later OR LicenseRef-Landrix-Commercial
}

{ Tests for the generated Factur-X code asserts (LandrixEInvoiceCIICodeRules):
  a complete invoice passes every profile; codes are compared unchanged and
  case sensitively, blank elements are not checked; the context conditions
  (allowance or charge, document type code, @listID, the VAT total currency)
  select the asserts as in the schematron; each identifier belongs to one
  profile; LandrixEInvoiceCheckCII and the facade report the violations. }
unit LandrixEInvoiceTestCIICodeRules;

{$I LandrixEInvoice.inc}

interface

procedure Register;

implementation

uses
  SysUtils,
  LandrixEInvoiceTypes,
  LandrixEInvoiceDiagnostics,
  LandrixEInvoiceSpecs,
  LandrixEInvoiceCodes,
  LandrixEInvoiceInvoice,
  LandrixEInvoiceCII,
  LandrixEInvoiceMapCII,
  LandrixEInvoiceCIICodeRules,
  LandrixEInvoiceCheck,
  LandrixEInvoice,
  LandrixEInvoiceTestFramework,
  LandrixEInvoiceTestCheck;

const
  Doc = '/rsm:CrossIndustryInvoice/rsm:ExchangedDocument';
  Settlement = '/rsm:CrossIndustryInvoice/rsm:SupplyChainTradeTransaction/ram:ApplicableHeaderTradeSettlement';
  FacturXProfiles: array[0..4] of TLandrixEInvoiceProfile = (epr_Minimum, epr_BasicWL, epr_Basic, epr_EN16931,
    epr_Extended);

function FacturX(AProfile: TLandrixEInvoiceProfile): TLandrixEInvoiceSpec;
begin
  Check(LandrixEInvoiceFindSpec(TLandrixEInvoiceTargets.FacturX('1.09', AProfile), Result), 'Factur-X spec');
end;

{ the complete invoice of the check tests, mapped to the profile }
function MappedCII(AProfile: TLandrixEInvoiceProfile): TLandrixCIIInvoice;
var
  Invoice: TLandrixInvoice;
begin
  Invoice := TLandrixInvoice.Create;
  try
    FillComplete(Invoice);
    Result := LandrixEInvoiceInvoiceToCII(Invoice, FacturX(AProfile), nil);
  finally
    Invoice.Free;
  end;
end;

{ the rule identifiers of D, separated by blanks }
function RulesOf(D: TLandrixEInvoiceDiagnostics): string;
var
  I: TLandrixEInvoiceListIndex;
begin
  Result := '';
  for I := 0 to D.Count - 1 do
    if D[I].Kind = edk_RuleViolation then
      Result := Result + ' ' + string(D[I].RuleID);
  Result := Trim(Result);
end;

function Codes(ACII: TLandrixCIIInvoice; AProfile: TLandrixEInvoiceProfile; D: TLandrixEInvoiceDiagnostics): string;
begin
  D.Clear;
  LandrixEInvoiceCheckCIICodes(ACII, AProfile, D);
  Result := RulesOf(D);
end;

{ The complete invoice passes every profile; a target without Factur-X
  profile has no code asserts. }
procedure TestComplete;
var
  CII: TLandrixCIIInvoice;
  D: TLandrixEInvoiceDiagnostics;
  I: Integer;
begin
  D := TLandrixEInvoiceDiagnostics.Create;
  try
    for I := Low(FacturXProfiles) to High(FacturXProfiles) do
    begin
      CII := MappedCII(FacturXProfiles[I]);
      try
        CheckEquals(0, LandrixEInvoiceCheckCIICodes(CII, FacturXProfiles[I], D), 'profile ' + IntToStr(I) + ': ' +
          string(D.ToText));
        CII.ExchangedDocument.TypeCode := '999';
        CheckEquals(0, LandrixEInvoiceCheckCIICodes(CII, epr_None, nil), 'no Factur-X profile');
        CheckEquals(0, LandrixEInvoiceCheckCIICodes(CII, epr_XRechnung, nil), 'XRechnung');
      finally
        CII.Free;
      end;
    end;
  finally
    D.Free;
  end;
end;

{ The value is compared as it is written: unchanged, case sensitive; a
  blank element is not written and not checked. Each profile reports its
  own identifier. }
procedure TestValues;
var
  CII: TLandrixCIIInvoice;
  D: TLandrixEInvoiceDiagnostics;
begin
  D := TLandrixEInvoiceDiagnostics.Create;
  CII := MappedCII(epr_EN16931);
  try
    CII.ExchangedDocument.TypeCode := '999';
    CheckEqualsStr('FX-SCH-A-000555', Codes(CII, epr_EN16931, D), 'type code 999');
    CheckEqualsInvoiceStr(Doc + '/ram:TypeCode', D[0].Path, 'path');
    Check(D[0].Severity = eds_Error, 'error');
    Check(Pos('''999''', string(D[0].Message)) > 0, 'value in the message: ' + string(D[0].Message));
    { the BT-24 of EN16931 is not in the lists of BASIC (FX-SCH-A-000493) and
      EXTENDED (FX-SCH-A-000636) }
    CheckEqualsStr('FX-SCH-A-000493 FX-SCH-A-000492', Codes(CII, epr_Basic, D), 'BASIC has its own identifier');
    CheckEqualsStr('FX-SCH-A-000636 FX-SCH-A-000635', Codes(CII, epr_Extended, D),
      'EXTENDED has its own identifier');
    CII.ExchangedDocument.TypeCode := ' 380';
    CheckEqualsStr('FX-SCH-A-000555', Codes(CII, epr_EN16931, D), 'blank before the code');
    CII.ExchangedDocument.TypeCode := ' ';
    CheckEqualsStr('', Codes(CII, epr_EN16931, D), 'blank element');
    CII.ExchangedDocument.TypeCode := '380';
    CII.SupplyChainTradeTransaction.ApplicableHeaderTradeSettlement.InvoiceCurrencyCode := 'eur';
    CheckEqualsStr('FX-SCH-A-000595', Codes(CII, epr_EN16931, D), 'lower case currency');
  finally
    CII.Free;
    D.Free;
  end;
end;

{ The conditions of the schematron context: the reason code of an allowance
  (indicator false) or a charge (true, without @listID; EXTENDED also with
  @listID 5153), any other indicator text selects no assert; the document
  type code 130, 50 or 916 of a referenced document; the VAT total only in
  the invoice or VAT accounting currency, in both only as invoice
  currency. }
procedure TestConditions;
var
  CII: TLandrixCIIInvoice;
  D: TLandrixEInvoiceDiagnostics;
  Charge: TLandrixCIITradeAllowanceCharge;
  Document: TLandrixCIIReferencedDocument;
  Total: TLandrixCIIAmount;
begin
  D := TLandrixEInvoiceDiagnostics.Create;
  CII := MappedCII(epr_EN16931);
  try
    Charge := CII.SupplyChainTradeTransaction.ApplicableHeaderTradeSettlement.SpecifiedTradeAllowanceCharge.Add;
    Charge.ChargeIndicator := 'false';
    Charge.ReasonCode.Value := '95';
    CheckEqualsStr('', Codes(CII, epr_EN16931, D), 'allowance 95');
    Charge.ReasonCode.Value := 'AA';
    CheckEqualsStr('FX-SCH-A-000601', Codes(CII, epr_EN16931, D), 'allowance AA');
    Charge.ChargeIndicator := 'true';
    CheckEqualsStr('', Codes(CII, epr_EN16931, D), 'charge AA');
    Charge.ReasonCode.Value := '95';
    CheckEqualsStr('FX-SCH-A-000604', Codes(CII, epr_EN16931, D), 'charge 95');
    CheckEqualsInvoiceStr(Settlement + '/ram:SpecifiedTradeAllowanceCharge/ram:ReasonCode', D[0].Path, 'path');
    Charge.ChargeIndicator := '1';
    CheckEqualsStr('', Codes(CII, epr_EN16931, D), 'indicator 1 selects no assert');
    Charge.ChargeIndicator := 'true';
    Charge.ReasonCode.ListID := '5153';
    CheckEqualsStr('', Codes(CII, epr_EN16931, D), 'EN16931: list 5153 unchecked');
    { FX-SCH-A-000636: the BT-24 of EN16931 in EXTENDED }
    CheckEqualsStr('FX-SCH-A-000636 FX-SCH-A-000390', Codes(CII, epr_Extended, D),
      'EXTENDED: 95 is no UNTDID 5153 code');
    Charge.ReasonCode.Value := 'ENV';
    CheckEqualsStr('FX-SCH-A-000636', Codes(CII, epr_Extended, D), 'EXTENDED: ENV of UNTDID 5153');
    CII.SupplyChainTradeTransaction.ApplicableHeaderTradeSettlement.SpecifiedTradeAllowanceCharge.Clear;

    Document := CII.SupplyChainTradeTransaction.ApplicableHeaderTradeAgreement.AdditionalReferencedDocument.Add;
    Document.IssuerAssignedID.Value := 'D-1';
    Document.TypeCode := '130';
    Document.ReferenceTypeCode := 'XX';
    CheckEqualsStr('FX-SCH-A-000282', Codes(CII, epr_EN16931, D), 'object identifier scheme');
    Document.TypeCode := '916';
    CheckEqualsStr('', Codes(CII, epr_EN16931, D), 'scheme of an attachment is unchecked');
    Document.ReferenceTypeCode := '';
    Document.AttachmentBinaryObject.Value := 'JVBERi0=';
    Document.AttachmentBinaryObject.Filename := 'a.zip';
    Document.AttachmentBinaryObject.MimeCode := 'application/zip';
    CheckEqualsStr('FX-SCH-A-000287', Codes(CII, epr_EN16931, D), 'MIME code of an attachment');
    Document.TypeCode := '50';
    CheckEqualsStr('', Codes(CII, epr_EN16931, D), 'no attachment rule for type 50');
    Document.TypeCode := '999';
    CheckEqualsStr('', Codes(CII, epr_EN16931, D), 'header: type code 999 selects no assert');
    CII.SupplyChainTradeTransaction.ApplicableHeaderTradeAgreement.AdditionalReferencedDocument.Clear;
    { on the line every type code and scheme is checked }
    Document := CII.SupplyChainTradeTransaction.IncludedSupplyChainTradeLineItem[0].SpecifiedLineTradeSettlement.
      AdditionalReferencedDocument.Add;
    Document.IssuerAssignedID.Value := 'O-1';
    Document.TypeCode := '999';
    Document.ReferenceTypeCode := 'XX';
    CheckEqualsStr('FX-SCH-A-000618 FX-SCH-A-000617', Codes(CII, epr_EN16931, D), 'line object identifier');
    CII.SupplyChainTradeTransaction.IncludedSupplyChainTradeLineItem[0].SpecifiedLineTradeSettlement.
      AdditionalReferencedDocument.Clear;

    CII.SupplyChainTradeTransaction.ApplicableHeaderTradeSettlement.InvoiceCurrencyCode := 'EURO';
    CheckEqualsStr('FX-SCH-A-000595', Codes(CII, epr_EN16931, D), 'VAT total in EUR is not checked');
    Total := CII.SupplyChainTradeTransaction.ApplicableHeaderTradeSettlement.
      SpecifiedTradeSettlementHeaderMonetarySummation.TaxTotalAmount[0];
    Total.CurrencyID := 'EURO';
    CII.SupplyChainTradeTransaction.ApplicableHeaderTradeSettlement.
      SpecifiedTradeSettlementHeaderMonetarySummation.TaxTotalAmount[0] := Total;
    CheckEqualsStr('FX-SCH-A-000595 FX-SCH-A-000606', Codes(CII, epr_EN16931, D), 'VAT total in EURO');
    Total.CurrencyID := 'XYZ';
    CII.SupplyChainTradeTransaction.ApplicableHeaderTradeSettlement.
      SpecifiedTradeSettlementHeaderMonetarySummation.TaxTotalAmount.Add(Total);
    CheckEqualsStr('FX-SCH-A-000595 FX-SCH-A-000606', Codes(CII, epr_EN16931, D), 'a third currency is unchecked');
    { BT-6 XYZ is no currency (FX-SCH-A-000610), and the VAT total in it is checked }
    CII.SupplyChainTradeTransaction.ApplicableHeaderTradeSettlement.TaxCurrencyCode := 'XYZ';
    CheckEqualsStr('FX-SCH-A-000610 FX-SCH-A-000595 FX-SCH-A-000606 FX-SCH-A-000607', Codes(CII, epr_EN16931, D),
      'VAT total in the VAT accounting currency');
    { a VAT total in a currency that is both is judged by the invoice
      currency rule only: the schematron fires the first rule of a pattern }
    CII.SupplyChainTradeTransaction.ApplicableHeaderTradeSettlement.TaxCurrencyCode := 'EURO';
    CheckEqualsStr('FX-SCH-A-000610 FX-SCH-A-000595 FX-SCH-A-000606', Codes(CII, epr_EN16931, D),
      'BT-6 = BT-5');
    Check(LandrixEInvoiceCheckCIICodeRule(CII, epr_EN16931, 'FX-SCH-A-000607', nil), 'FX-SCH-A-000607 shadowed');
  finally
    CII.Free;
    D.Free;
  end;
end;

{ LandrixEInvoiceCheckCIICodeRule checks one identifier; an identifier of
  another profile holds, an unknown one raises. }
procedure TestRule;
var
  CII: TLandrixCIIInvoice;
  D: TLandrixEInvoiceDiagnostics;
begin
  D := TLandrixEInvoiceDiagnostics.Create;
  CII := MappedCII(epr_EN16931);
  try
    Check(LandrixEInvoiceCheckCIICodeRule(CII, epr_EN16931, 'FX-SCH-A-000555', nil), 'holds');
    CII.ExchangedDocument.TypeCode := '999';
    CII.SupplyChainTradeTransaction.ApplicableHeaderTradeSettlement.InvoiceCurrencyCode := 'eur';
    Check(not LandrixEInvoiceCheckCIICodeRule(CII, epr_EN16931, 'FX-SCH-A-000555', D), 'violated');
    CheckEqualsStr('FX-SCH-A-000555', RulesOf(D), 'only this rule reported');
    Check(LandrixEInvoiceCheckCIICodeRule(CII, epr_Basic, 'FX-SCH-A-000555', nil), 'other profile');
    try
      LandrixEInvoiceCheckCIICodeRule(CII, epr_EN16931, 'FX-SCH-A-999999', nil);
      FailNotRaised('ELandrixEInvoiceError for an unknown rule');
    except
      on ELandrixEInvoiceError do ;
    end;
  finally
    CII.Free;
    D.Free;
  end;
end;

{ LandrixEInvoiceCheckCII and the facade (Check of a CII model or of an
  invoice for Factur-X) report the violations; eio_NoRuleCheck leaves them
  out. }
procedure TestIntegration;
var
  CII: TLandrixCIIInvoice;
  Invoice: TLandrixInvoice;
  D: TLandrixEInvoiceDiagnostics;
  Target: TLandrixEInvoiceTarget;
begin
  Target := TLandrixEInvoiceTargets.FacturX('1.09', epr_EN16931);
  D := TLandrixEInvoiceDiagnostics.Create;
  Invoice := TLandrixInvoice.Create;
  CII := MappedCII(epr_EN16931);
  try
    CII.ExchangedDocument.TypeCode := '999';
    CheckEquals(1, LandrixEInvoiceCheckCII(CII, FacturX(epr_EN16931), D), 'CheckCII: ' + string(D.ToText));
    CheckEqualsStr('FX-SCH-A-000555', RulesOf(D), 'CheckCII rule');
    D.Clear;
    CheckEquals(1, TLandrixEInvoice.Check(CII, Target, [], D), 'facade, CII model: ' + string(D.ToText));
    CheckEqualsStr('FX-SCH-A-000555', RulesOf(D), 'facade rule');
    D.Clear;
    CheckEquals(0, TLandrixEInvoice.Check(CII, Target, [eio_NoRuleCheck], D), 'no rule check');
    FillComplete(Invoice);
    Invoice.InvoiceTypeCode := itc_None;
    Invoice.InvoiceTypeCodeOther := '999';
    D.Clear;
    TLandrixEInvoice.Check(Invoice, Target, [], D);
    Check(Pos('FX-SCH-A-000555', RulesOf(D)) > 0, 'facade, invoice: ' + RulesOf(D));
  finally
    CII.Free;
    Invoice.Free;
    D.Free;
  end;
end;

procedure Register;
begin
  RegisterTest('CIICodeRules.Complete', TestComplete);
  RegisterTest('CIICodeRules.Values', TestValues);
  RegisterTest('CIICodeRules.Conditions', TestConditions);
  RegisterTest('CIICodeRules.Rule', TestRule);
  RegisterTest('CIICodeRules.Integration', TestIntegration);
end;

end.
