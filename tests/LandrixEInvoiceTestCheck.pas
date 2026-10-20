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
  empty specification entry and the legacy rules LX-CC-01 to LX-CC-12 (their
  conditions per old version are tested through
  TXRechnungInvoiceAdapter.ConsistencyCheck in
  LandrixEInvoiceTestCompatAdapter). }

unit LandrixEInvoiceTestCheck;

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
  LandrixEInvoiceCalc,
  LandrixEInvoiceCheck,
  LandrixEInvoiceTestFramework;

function SpecFor(const ATarget: TLandrixEInvoiceTarget): TLandrixEInvoiceSpec;
begin
  Check(LandrixEInvoiceFindSpec(ATarget, Result), 'spec ' + string(LandrixEInvoiceTargetToStr(ATarget)));
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
  third-party payments fail there as for the old unwritable versions. }
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

{ LandrixEInvoiceCheckInvoice does not run the legacy rules. }
procedure TestCheckInvoiceSkipsLegacy;
var
  Invoice: TLandrixInvoice;
  D: TLandrixEInvoiceDiagnostics;
begin
  D := TLandrixEInvoiceDiagnostics.Create;
  Invoice := TLandrixInvoice.Create;
  try
    CheckEquals(0, LandrixEInvoiceCheckInvoice(Invoice, SpecFor(TLandrixEInvoiceTargets.XRechnung('3.0', esy_UBL)),
      D), 'no errors');
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

procedure Register;
begin
  RegisterTest('Check.RuleDiagnostic', TestRuleDiagnostic);
  RegisterTest('Check.Applicability', TestApplicability);
  RegisterTest('Check.EmptySpec', TestEmptySpec);
  RegisterTest('Check.UnknownRule', TestUnknownRule);
  RegisterTest('Check.CheckInvoiceSkipsLegacy', TestCheckInvoiceSkipsLegacy);
  RegisterTest('Check.BlankValues', TestBlankValues);
end;

end.
