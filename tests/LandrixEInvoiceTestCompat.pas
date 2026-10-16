{
  EInvoice-for-Pascal

  Copyright (C) 2026 Landrix Software GmbH & Co. KG

  This file is dual-licensed under:
  - GNU GPL version 3 or later; or
  - the Landrix Software Commercial License.

  See LICENSE and COMMERCIAL-LICENSE.md.

  SPDX-License-Identifier: GPL-3.0-or-later OR LicenseRef-Landrix-Commercial
}

{ Tests for LandrixEInvoiceCompatXRechnung: code written against the old
  names of XRechnung-for-Delphi, using only the compatibility unit. }

unit LandrixEInvoiceTestCompat;

{$I LandrixEInvoice.inc}

interface

procedure Register;

implementation

uses
  SysUtils,
  LandrixEInvoiceCompatXRechnung,
  LandrixEInvoiceTestFramework;

procedure TestOldNames;
var
  Inv: TInvoice;
  Line: TInvoiceLine;
  I: TInvoiceListItemType;
  Count: Integer;
  Success: Boolean;
  Code: TInvoiceUnitCode;
begin
  Inv := TInvoice.Create;
  try
    Inv.InvoiceNumber := 'R2020-0815';
    Inv.InvoiceTypeCode := itc_CommercialInvoice;
    Inv.BuyerReference := TInvoiceEmptyLeitwegID.NON_EXISTENT;
    CheckEqualsInvoiceStr('non-existent', Inv.BuyerReference, 'NON_EXISTENT');
    Inv.Notes.AddNote.Content := 'note';
    Line := Inv.InvoiceLines.AddInvoiceLine;
    Line.UnitCode := TInvoiceUnitCodeHelper.MapUnitOfMeasure('Stk', Success);
    Check(Success and (Line.UnitCode = iuc_piece), 'MapUnitOfMeasure');
    Code := TInvoiceUnitCodeHelper.MapUnitOfMeasure('xyz', Success, iuc_one);
    Check(not Success and (Code = iuc_one), 'MapUnitOfMeasure default');
    Line.TaxCategory := idtfcc_S_StandardRate;
    Inv.PaymentTypes.AddPaymentType.PaymentMeansCode := ipmc_SEPACreditTransfer;
    Inv.PaymentTermsType := iptt_CashDiscount1;
    Line.LineStatusReasonCode := ilsrc_Group;
    Check(TInvoiceAttachmentTypeHelper.GetTypeFromFilename('a.pdf') = iat_application_pdf, 'GetTypeFromFilename');
    Inv.Attachments.AddAttachment(iat_application_pdf).TypeCode := iatc_130;
    Count := 0;
    for I := 0 to Inv.InvoiceLines.Count - 1 do
      if Inv.InvoiceLines[I].TaxCategory = idtfcc_S_StandardRate then
        Inc(Count);
    CheckEquals(1, Count, 'loop with TInvoiceListItemType');
  finally
    Inv.Free;
  end;
end;

procedure TestConstantsEqualMembers;
var
  T: TInvoiceTypeCode;
begin
  { the constants are the members of the new types, usable in case labels }
  T := itc_CreditNote;
  case T of
    itc_CommercialInvoice: Fail('wrong branch');
    itc_CreditNote: Check(True, 'case label with a compatibility constant');
  else
    Fail('no branch');
  end;
  Check(Ord(iuc_hectare) = Ord(High(TInvoiceUnitCode)), 'last unit code member');
  Check(Ord(insc_BLP) = Ord(High(TInvoiceNoteSubjectCode)), 'last note subject member');
  Check(Ord(ipmc_MutuallyDefined) = Ord(High(TInvoicePaymentMeansCode)), 'last payment means member');
end;

procedure Register;
begin
  RegisterTest('Compat.OldNames', TestOldNames);
  RegisterTest('Compat.ConstantsEqualMembers', TestConstantsEqualMembers);
end;

end.
