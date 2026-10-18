{
  EInvoice-for-Pascal

  Copyright (C) 2026 Landrix Software GmbH & Co. KG

  This file is dual-licensed under:
  - GNU GPL version 3 or later; or
  - the Landrix Software Commercial License.

  See LICENSE and COMMERCIAL-LICENSE.md.

  SPDX-License-Identifier: GPL-3.0-or-later OR LicenseRef-Landrix-Commercial
}

{ Tests for LandrixEInvoiceSpecs: targets, factories, specification
  directory, detection. }

unit LandrixEInvoiceTestSpecs;

{$I LandrixEInvoice.inc}

interface

procedure Register;

implementation

uses
  SysUtils,
  LandrixEInvoiceTypes,
  LandrixEInvoiceSpecs,
  LandrixEInvoiceRules,
  LandrixEInvoiceTestFramework;

procedure TestEveryEntryFoundByItsTarget;
var
  I: Integer;
  Spec, Found: TLandrixEInvoiceSpec;
  Ext: Boolean;
  Root: TLandrixEInvoiceString;
begin
  Check(LandrixEInvoiceSpecCount = 5, 'five entries');
  for I := 0 to LandrixEInvoiceSpecCount - 1 do
  begin
    Spec := LandrixEInvoiceSpec(I);
    Check(LandrixEInvoiceFindSpec(Spec.Target, Found), 'entry ' + IntToStr(I) + ' found by its target');
    Check(LandrixEInvoiceSameTarget(Found.Target, Spec.Target), 'entry ' + IntToStr(I) + ' same target');
    Check(Spec.CustomizationID <> '', 'entry ' + IntToStr(I) + ' has an identifier');
    Check(Spec.CanRead and Spec.CanWrite, 'entry ' + IntToStr(I) + ' readable and writable');
    if Spec.Target.Syntax = esy_UBL then
      Root := 'Invoice'
    else
      Root := 'CrossIndustryInvoice';
    Check(LandrixEInvoiceDetectSpec(Root, Spec.CustomizationID, Found, Ext), 'entry ' + IntToStr(I) + ' detected');
    Check(LandrixEInvoiceSameTarget(Found.Target, Spec.Target), 'entry ' + IntToStr(I) + ' detected as itself');
    Check(not Ext, 'entry ' + IntToStr(I) + ' without extension');
  end;
  try
    LandrixEInvoiceSpec(LandrixEInvoiceSpecCount);
    FailNotRaised('ELandrixEInvoiceError for index out of range');
  except
    on E: ELandrixEInvoiceError do ;
  end;
end;

procedure TestFactoriesAndVersions;
var
  Spec: TLandrixEInvoiceSpec;
begin
  Check(LandrixEInvoiceFindSpec(TLandrixEInvoiceTargets.XRechnung('3.0.2', esy_UBL), Spec), 'XRechnung 3.0.2 UBL');
  CheckEqualsInvoiceStr('3.0.2', Spec.ExactVersion, 'exact version');
  Check(LandrixEInvoiceFindSpec(TLandrixEInvoiceTargets.XRechnung('3.0.1', esy_CII), Spec), 'XRechnung 3.0.1 CII (patch)');
  Check(LandrixEInvoiceFindSpec(TLandrixEInvoiceTargets.XRechnung('3.0', esy_CII), Spec), 'XRechnung 3.0 CII');
  CheckEqualsInvoiceStr('xrechnung.xml', Spec.AttachmentFileName, 'XRechnung CII attachment name');
  Check(LandrixEInvoiceFindSpec(TLandrixEInvoiceTargets.FacturX('1.09.2', epr_Extended), Spec), 'Factur-X 1.09.2 EXTENDED');
  CheckEqualsInvoiceStr('urn:cen.eu:en16931:2017#conformant#urn:factur-x.eu:1p0:extended', Spec.CustomizationID, 'EXTENDED identifier');
  Check(LandrixEInvoiceFindSpec(TLandrixEInvoiceTargets.PeppolBIS('3.0'), Spec), 'Peppol BIS 3.0');
  CheckEqualsInvoiceStr('urn:fdc:peppol.eu:2017:poacc:billing:01:1.0', Spec.ProfileID, 'Peppol ProfileID');

  { invalid targets }
  Check(not LandrixEInvoiceFindSpec(TLandrixEInvoiceTargets.XRechnung('', esy_UBL), Spec), 'empty version');
  Check(not LandrixEInvoiceFindSpec(TLandrixEInvoiceTargets.XRechnung('3', esy_UBL), Spec), 'incomplete version');
  Check(LandrixEInvoiceFindSpec(TLandrixEInvoiceTargets.XRechnung('3.0.x', esy_UBL), Spec), 'family 3.0.x');
  Check(not LandrixEInvoiceFindSpec(TLandrixEInvoiceTargets.XRechnung('3.0.a', esy_UBL), Spec), 'non-numeric patch');
  Check(not LandrixEInvoiceFindSpec(TLandrixEInvoiceTargets.XRechnung('3.0.', esy_UBL), Spec), 'empty patch');
  Check(not LandrixEInvoiceFindSpec(TLandrixEInvoiceTargets.XRechnung('3.0.2.1', esy_UBL), Spec), 'four parts');
  Check(not LandrixEInvoiceFindSpec(TLandrixEInvoiceTargets.XRechnung('.3.0', esy_UBL), Spec), 'leading dot');
  Check(not LandrixEInvoiceFindSpec(TLandrixEInvoiceTargets.XRechnung('2.3', esy_UBL), Spec), 'XRechnung 2.3 not writable');
  Check(not LandrixEInvoiceFindSpec(TLandrixEInvoiceTargets.XRechnung('3.0', esy_None), Spec), 'no syntax');
  Check(not LandrixEInvoiceFindSpec(TLandrixEInvoiceTargets.FacturX('1.09', epr_Basic), Spec), 'BASIC not yet');
  Check(not LandrixEInvoiceFindSpec(TLandrixEInvoiceTargets.FacturX('1.09', epr_None), Spec), 'Factur-X without profile');
  Check((Spec.Target.Standard = est_None) and not Spec.CanWrite and (Spec.CustomizationID = ''), 'empty entry when not found');
end;

procedure TestZUGFeRD;
var
  Spec: TLandrixEInvoiceSpec;
  T: TLandrixEInvoiceTarget;
begin
  Check(LandrixEInvoiceSameTarget(TLandrixEInvoiceTargets.ZUGFeRD('2.5', epr_EN16931),
    TLandrixEInvoiceTargets.FacturX('1.09', epr_EN16931)), 'ZUGFeRD 2.5 = Factur-X 1.09');
  Check(LandrixEInvoiceSameTarget(TLandrixEInvoiceTargets.ZUGFeRD('2.5.2', epr_Extended),
    TLandrixEInvoiceTargets.FacturX('1.09', epr_Extended)), 'ZUGFeRD 2.5.2 EXTENDED');
  Check(LandrixEInvoiceSameTarget(TLandrixEInvoiceTargets.ZUGFeRD('2.5', epr_XRechnung),
    TLandrixEInvoiceTargets.XRechnung('3.0', esy_CII)), 'ZUGFeRD XRECHNUNG profile');
  Check(LandrixEInvoiceSameTarget(TLandrixEInvoiceTargets.ZUGFeRD('2.5', epr_Basic),
    TLandrixEInvoiceTargets.FacturX('1.09', epr_Basic)), 'known release, profile without entry');
  CheckEqualsInvoiceStr('XRechnung 3.0 CII', LandrixEInvoiceTargetToStr(TLandrixEInvoiceTargets.ZUGFeRD('2.5', epr_XRechnung)),
    'ZUGFeRD XRECHNUNG name');
  T := TLandrixEInvoiceTargets.ZUGFeRD('2.1', epr_EN16931);
  Check(not LandrixEInvoiceFindSpec(T, Spec), 'unknown ZUGFeRD release matches nothing');
  CheckEqualsInvoiceStr('Factur-X ZUGFeRD 2.1 EN16931', LandrixEInvoiceTargetToStr(T), 'unknown release stays visible');
end;

procedure TestSameTargetAndNames;
begin
  Check(LandrixEInvoiceSameTarget(TLandrixEInvoiceTargets.XRechnung('3.0.2', esy_UBL),
    TLandrixEInvoiceTargets.XRechnung('3.0', esy_UBL)), 'patch versions are the same target');
  Check(not LandrixEInvoiceSameTarget(TLandrixEInvoiceTargets.XRechnung('3.0', esy_UBL),
    TLandrixEInvoiceTargets.XRechnung('3.0', esy_CII)), 'different syntax');
  Check(not LandrixEInvoiceSameTarget(TLandrixEInvoiceTargets.FacturX('1.09', epr_EN16931),
    TLandrixEInvoiceTargets.FacturX('1.08', epr_EN16931)), 'different minor version');
  CheckEqualsInvoiceStr('XRechnung 3.0.2 UBL', LandrixEInvoiceTargetToStr(TLandrixEInvoiceTargets.XRechnung('3.0.2', esy_UBL)), 'XRechnung name');
  CheckEqualsInvoiceStr('Factur-X 1.09 EXTENDED', LandrixEInvoiceTargetToStr(TLandrixEInvoiceTargets.FacturX('1.09', epr_Extended)), 'Factur-X name');
  CheckEqualsInvoiceStr('Peppol BIS 3.0', LandrixEInvoiceTargetToStr(TLandrixEInvoiceTargets.PeppolBIS('3.0')), 'Peppol name');
end;

procedure TestDetect;
var
  Spec: TLandrixEInvoiceSpec;
  Ext: Boolean;
begin
  { identifiers as written by XRechnung-for-Delphi }
  Check(LandrixEInvoiceDetectSpec('Invoice',
    'urn:cen.eu:en16931:2017#compliant#urn:xeinkauf.de:kosit:xrechnung_3.0#conformant#urn:xeinkauf.de:kosit:extension:xrechnung_3.0',
    Spec, Ext), 'XRechnung UBL with extension');
  Check(Ext, 'extension reported');
  Check(Spec.Target.Syntax = esy_UBL, 'extension: UBL entry');
  Check(LandrixEInvoiceDetectSpec('CreditNote',
    'URN:CEN.EU:EN16931:2017#COMPLIANT#URN:XEINKAUF.DE:KOSIT:XRECHNUNG_3.0', Spec, Ext), 'credit note, upper case');
  Check(not Ext, 'no extension');
  Check(LandrixEInvoiceDetectSpec('CrossIndustryInvoice',
    'urn:cen.eu:en16931:2017#compliant#urn:xeinkauf.de:kosit:xrechnung_3.0', Spec, Ext), 'XRechnung CII');
  Check(Spec.Target.Standard = est_XRechnung, 'XRechnung CII standard');
  Check(LandrixEInvoiceDetectSpec('CrossIndustryInvoice', 'urn:cen.eu:en16931:2017', Spec, Ext), 'Factur-X EN16931');
  Check(Spec.Target.Profile = epr_EN16931, 'EN16931 profile');
  Check(LandrixEInvoiceDetectSpec('CrossIndustryInvoice',
    '  urn:cen.eu:en16931:2017#compliant#urn:xeinkauf.de:kosit:xrechnung_3.0#conformant#urn:xeinkauf.de:kosit:extension:xrechnung_3.0 ',
    Spec, Ext), 'XRechnung CII with extension, surrounding white space');
  Check(Ext and (Spec.Target.Syntax = esy_CII), 'CII extension reported');
  Check(not LandrixEInvoiceDetectSpec('invoice', 'urn:cen.eu:en16931:2017#compliant#urn:xeinkauf.de:kosit:xrechnung_3.0',
    Spec, Ext), 'root name is case-sensitive');
  Check(Spec.Target.Standard = est_None, 'empty entry when not detected');
  Check(not LandrixEInvoiceDetectSpec('Invoice', 'urn:cen.eu:en16931:2017', Spec, Ext), 'CII identifier in UBL');
  Check(not LandrixEInvoiceDetectSpec('Order', 'urn:cen.eu:en16931:2017', Spec, Ext), 'unknown root');
  Check(not LandrixEInvoiceDetectSpec('Invoice',
    'urn:cen.eu:en16931:2017#compliant#urn:xoev-de:kosit:standard:xrechnung_2.3', Spec, Ext), 'XRechnung 2.3 not yet');
end;

procedure TestCodeListsOfXRechnung;
var
  Spec: TLandrixEInvoiceSpec;
begin
  Check(LandrixEInvoiceFindSpec(TLandrixEInvoiceTargets.XRechnung('3.0', esy_UBL), Spec), 'entry');
  Check(Pos('urn:xoev-de:kosit:codeliste:rec20_3', Spec.CodeLists) > 0, 'rec20_3 listed');
  Check(Pos('urn:xoev-de:xrechnung:codeliste:untdid.4461_3', Spec.CodeLists) > 0, '4461 in the XRechnung namespace');
end;

function SpecOf(const ATarget: TLandrixEInvoiceTarget): TLandrixEInvoiceSpec;
begin
  Check(LandrixEInvoiceFindSpec(ATarget, Result), 'spec ' + string(LandrixEInvoiceTargetToStr(ATarget)));
end;

procedure TestRules;
var
  XrUbl, XrCii, FxEn, FxExt, Peppol: TLandrixEInvoiceSpec;
  Rule: TLandrixEInvoiceRule;
  I: Integer;
begin
  XrUbl := SpecOf(TLandrixEInvoiceTargets.XRechnung('3.0', esy_UBL));
  XrCii := SpecOf(TLandrixEInvoiceTargets.XRechnung('3.0', esy_CII));
  FxEn := SpecOf(TLandrixEInvoiceTargets.FacturX('1.09', epr_EN16931));
  FxExt := SpecOf(TLandrixEInvoiceTargets.FacturX('1.09', epr_Extended));
  Peppol := SpecOf(TLandrixEInvoiceTargets.PeppolBIS('3.0'));
  Check(LandrixEInvoiceRuleLevel(FxExt, LandrixEInvoiceRuleLineSubLines) = erl_Allowed, 'sub lines EXTENDED');
  Check(LandrixEInvoiceRuleLevel(FxEn, LandrixEInvoiceRuleLineSubLines) = erl_Forbidden, 'sub lines EN16931');
  Check(LandrixEInvoiceRuleLevel(XrCii, LandrixEInvoiceRuleLineSubLines) = erl_Forbidden, 'sub lines XRechnung CII');
  Check(LandrixEInvoiceRuleLevel(XrUbl, LandrixEInvoiceRuleLineSubLines) = erl_Allowed, 'sub lines XRechnung UBL');
  Check(LandrixEInvoiceRuleLevel(Peppol, LandrixEInvoiceRuleLineSubLines) = erl_Discouraged, 'sub lines Peppol');
  Check(LandrixEInvoiceRuleLevel(FxExt, LandrixEInvoiceRuleLineDelivery) = erl_Allowed, 'line delivery EXTENDED');
  Check(LandrixEInvoiceRuleLevel(XrCii, LandrixEInvoiceRuleLineDelivery) = erl_Forbidden, 'line delivery XRechnung CII');
  Check(LandrixEInvoiceRuleLevel(XrUbl, LandrixEInvoiceRuleBuyerReferencePlaceholder) = erl_Allowed, 'placeholder XRechnung');
  Check(LandrixEInvoiceRuleLevel(FxEn, LandrixEInvoiceRuleBuyerReferencePlaceholder) = erl_Forbidden, 'placeholder Factur-X');
  Check(LandrixEInvoiceRuleLevel(Peppol, LandrixEInvoiceRuleElectronicAddressDefaultEM) = erl_Forbidden, 'EM Peppol');
  Check(LandrixEInvoiceRuleLevel(XrUbl, LandrixEInvoiceRuleElectronicAddressDefaultEM) = erl_Allowed, 'EM XRechnung');
  Check(LandrixEInvoiceRuleLevel(FxEn, 'No.Such.Key') = erl_Allowed, 'unknown key allowed');
  Check(LandrixEInvoiceRuleLevel(Peppol, LandrixEInvoiceRuleBuyerReferencePlaceholder) = erl_Allowed, 'placeholder Peppol');
  Check(LandrixEInvoiceRuleLevel(XrUbl, LandrixEInvoiceRuleLineOrderNumber) = erl_Forbidden, 'line order number UBL');
  Check(LandrixEInvoiceRuleLevel(Peppol, LandrixEInvoiceRuleDeliveryNote) = erl_Forbidden, 'delivery note Peppol');
  Check(LandrixEInvoiceRuleLevel(XrUbl, LandrixEInvoiceRuleBuyerIDWithGlobalID) = erl_Forbidden, 'one buyer ID UBL');
  Check(LandrixEInvoiceRuleLevel(FxExt, LandrixEInvoiceRuleBuyerIDWithGlobalID) = erl_Allowed, 'buyer IDs EXTENDED');
  Check(LandrixEInvoiceRuleLevel(Peppol, LandrixEInvoiceRuleSellerIDWithGlobalID) = erl_Forbidden, 'one seller ID UBL');
  Check(LandrixEInvoiceRuleLevel(XrCii, LandrixEInvoiceRuleSellerIDWithGlobalID) = erl_Allowed, 'seller IDs CII');
  Check(LandrixEInvoiceFindRule(Peppol, LandrixEInvoiceRuleLineSubLines, Rule) and (Rule.Source = 'UBL-CR-646 (warning)'),
    'rule with source');
  Check(LandrixEInvoiceRuleCount > 0, 'rules');
  for I := 0 to LandrixEInvoiceRuleCount - 1 do
    Check((LandrixEInvoiceRule(I).Key <> '') and (LandrixEInvoiceRule(I).Source <> ''), 'rule ' + IntToStr(I) + ' complete');
end;

procedure Register;
begin
  RegisterTest('Specs.EveryEntryFoundByItsTarget', TestEveryEntryFoundByItsTarget);
  RegisterTest('Specs.FactoriesAndVersions', TestFactoriesAndVersions);
  RegisterTest('Specs.ZUGFeRD', TestZUGFeRD);
  RegisterTest('Specs.SameTargetAndNames', TestSameTargetAndNames);
  RegisterTest('Specs.Detect', TestDetect);
  RegisterTest('Specs.CodeListsOfXRechnung', TestCodeListsOfXRechnung);
  RegisterTest('Specs.Rules', TestRules);
end;

end.
