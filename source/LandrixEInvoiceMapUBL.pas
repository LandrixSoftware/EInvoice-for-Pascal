{
  EInvoice-for-Pascal

  Copyright (C) 2026 Landrix Software GmbH & Co. KG

  This file is dual-licensed under:
  - GNU GPL version 3 or later; or
  - the Landrix Software Commercial License.

  See LICENSE and COMMERCIAL-LICENSE.md.

  SPDX-License-Identifier: GPL-3.0-or-later OR LicenseRef-Landrix-Commercial
}

{ Mapping between the invoice model (TLandrixInvoice) and the UBL syntax
  model (TLandrixUBLInvoice, TLandrixUBLCreditNote), one method per business
  group. Both roots share one mapping: what they have in common is reached
  through a view of their parts. What a target specification allows comes
  from the rule table (LandrixEInvoiceRules); content it forbids is left out
  and reported (edk_NotAllowed). Totals are taken from the invoice model as
  they are.

  DE: Abbildung zwischen dem Rechnungsmodell (TLandrixInvoice) und dem
  UBL-Syntaxmodell (TLandrixUBLInvoice, TLandrixUBLCreditNote), eine
  Methode je Geschaeftsgruppe. Beide Wurzeln teilen sich eine Abbildung:
  das Gemeinsame wird ueber eine Sicht auf ihre Teile erreicht. Was eine
  Zielspezifikation erlaubt, kommt aus der Regel-Tabelle
  (LandrixEInvoiceRules); verbotener Inhalt wird weggelassen und gemeldet
  (edk_NotAllowed). Summen werden unveraendert aus dem Rechnungsmodell
  uebernommen. }

{ API: internal. May change in any release; use the facade LandrixEInvoice
  or the stable units instead.
  DE: API: intern. Kann sich in jeder Version aendern; stattdessen die
  Fassade LandrixEInvoice oder die stabilen Units verwenden. }

unit LandrixEInvoiceMapUBL;

{$I LandrixEInvoice.inc}

interface

uses
  LandrixEInvoiceDiagnostics,
  LandrixEInvoiceSpecs,
  LandrixEInvoiceInvoice,
  LandrixEInvoiceUBL;

type
  { Root element of a UBL document.
    DE: Wurzelelement eines UBL-Dokuments. }
  TLandrixEInvoiceUBLRoot = (
    { ubl:Invoice. DE: ubl:Invoice. }
    eur_Invoice,
    { ubl:CreditNote. DE: ubl:CreditNote. }
    eur_CreditNote
  );

{ The root AInvoice is written with for ASpec: a credit note (BT-3 = 381)
  becomes ubl:CreditNote, everything else ubl:Invoice. Raises
  ELandrixEInvoiceError if ASpec is not a UBL specification.
  DE: Die Wurzel, mit der AInvoice fuer ASpec geschrieben wird: eine
  Gutschrift (BT-3 = 381) wird ubl:CreditNote, alles andere ubl:Invoice.
  Loest ELandrixEInvoiceError aus, wenn ASpec keine UBL-Spezifikation ist. }
function LandrixEInvoiceUBLRootFor(AInvoice: TLandrixInvoice;
  const ASpec: TLandrixEInvoiceSpec): TLandrixEInvoiceUBLRoot;

{ Maps AInvoice to a new ubl:Invoice for ASpec (a UBL specification).
  Diagnostics are added to ADiagnostics (nil: discarded). Raises
  ELandrixEInvoiceError if ASpec is not a UBL specification the library can
  write. The caller frees the result.
  DE: Bildet AInvoice auf ein neues ubl:Invoice fuer ASpec ab (eine
  UBL-Spezifikation). Meldungen kommen in ADiagnostics (nil: verworfen).
  Loest ELandrixEInvoiceError aus, wenn ASpec keine UBL-Spezifikation ist,
  die die Bibliothek schreiben kann. Der Aufrufer gibt das Ergebnis frei. }
function LandrixEInvoiceInvoiceToUBLInvoice(AInvoice: TLandrixInvoice; const ASpec: TLandrixEInvoiceSpec;
  ADiagnostics: TLandrixEInvoiceDiagnostics): TLandrixUBLInvoice;

{ As LandrixEInvoiceInvoiceToUBLInvoice, for ubl:CreditNote.
  DE: Wie LandrixEInvoiceInvoiceToUBLInvoice, fuer ubl:CreditNote. }
function LandrixEInvoiceInvoiceToUBLCreditNote(AInvoice: TLandrixInvoice; const ASpec: TLandrixEInvoiceSpec;
  ADiagnostics: TLandrixEInvoiceDiagnostics): TLandrixUBLCreditNote;

{ Replaces the content of AInvoice with the content of AUBL. What the
  invoice model cannot hold is reported (edk_NotMapped), values that cannot
  be converted too (edk_ConversionFailed, the field stays "not set"),
  unknown codes are kept in the ...Other fields (edk_UnknownCode). AUBL is
  not changed.
  DE: Ersetzt den Inhalt von AInvoice durch den Inhalt von AUBL. Was das
  Rechnungsmodell nicht aufnehmen kann, wird gemeldet (edk_NotMapped),
  ebenso nicht umwandelbare Werte (edk_ConversionFailed, das Feld bleibt
  "nicht gesetzt"); unbekannte Codes bleiben in den ...Other-Feldern
  (edk_UnknownCode). AUBL wird nicht veraendert. }
procedure LandrixEInvoiceUBLInvoiceToInvoice(AUBL: TLandrixUBLInvoice; AInvoice: TLandrixInvoice;
  ADiagnostics: TLandrixEInvoiceDiagnostics);

{ As LandrixEInvoiceUBLInvoiceToInvoice, for ubl:CreditNote.
  DE: Wie LandrixEInvoiceUBLInvoiceToInvoice, fuer ubl:CreditNote. }
procedure LandrixEInvoiceUBLCreditNoteToInvoice(AUBL: TLandrixUBLCreditNote; AInvoice: TLandrixInvoice;
  ADiagnostics: TLandrixEInvoiceDiagnostics);

implementation

uses
  SysUtils,
  LandrixEInvoiceTypes,
  LandrixEInvoiceCodes,
  LandrixEInvoiceLexical,
  LandrixEInvoiceRules,
  LandrixEInvoiceCalc;

type
  PUBLID = ^TLandrixUBLID;
  PUBLCode = ^TLandrixUBLCode;
  PUBLQuantity = ^TLandrixUBLQuantity;
  PUBLAmount = ^TLandrixUBLAmount;
  PText = ^TLandrixEInvoiceString;

  { The parts of ubl:Invoice and ubl:CreditNote the mapping uses. Parts only
    one root has (cbc:DueDate, cac:ProjectReference, cac:PrepaidPayment) are
    nil for the other. }
  TUBLDocument = record
    Invoice: TLandrixUBLInvoice;
    CreditNote: TLandrixUBLCreditNote;
    Path: TLandrixEInvoiceString;
    TypeCodeName: TLandrixEInvoiceString;
    LineName: TLandrixEInvoiceString;
    CustomizationID: PUBLID;
    ProfileID: PUBLID;
    ID: PUBLID;
    IssueDate: PText;
    DueDate: PText;
    TaxPointDate: PText;
    TypeCode: PUBLCode;
    DocumentCurrencyCode: PUBLCode;
    TaxCurrencyCode: PUBLCode;
    AccountingCost: PText;
    BuyerReference: PText;
    Note: TLandrixEInvoiceStringList;
    InvoicePeriod: TLandrixUBLPeriodList;
    OrderReference: TLandrixUBLOrderReference;
    BillingReference: TLandrixUBLBillingReferenceList;
    DespatchDocumentReference: TLandrixUBLDocumentReferenceList;
    ReceiptDocumentReference: TLandrixUBLDocumentReferenceList;
    OriginatorDocumentReference: TLandrixUBLDocumentReferenceList;
    ContractDocumentReference: TLandrixUBLDocumentReferenceList;
    AdditionalDocumentReference: TLandrixUBLDocumentReferenceList;
    ProjectReference: TLandrixUBLProjectReferenceList;
    AccountingSupplierParty: TLandrixUBLSupplierParty;
    AccountingCustomerParty: TLandrixUBLCustomerParty;
    PayeeParty: TLandrixUBLParty;
    TaxRepresentativeParty: TLandrixUBLParty;
    Delivery: TLandrixUBLDeliveryList;
    PaymentMeans: TLandrixUBLPaymentMeansList;
    PaymentTerms: TLandrixUBLPaymentTermsList;
    PrepaidPayment: TLandrixUBLPaymentList;
    AllowanceCharge: TLandrixUBLAllowanceChargeList;
    TaxTotal: TLandrixUBLTaxTotalList;
    LegalMonetaryTotal: TLandrixUBLMonetaryTotal;
  end;

  { The parts of cac:InvoiceLine and cac:CreditNoteLine the mapping uses. }
  TUBLLine = record
    InvoiceLine: TLandrixUBLInvoiceLine;
    CreditNoteLine: TLandrixUBLCreditNoteLine;
    QuantityName: TLandrixEInvoiceString;
    SubLineName: TLandrixEInvoiceString;
    ID: PUBLID;
    Quantity: PUBLQuantity;
    LineExtensionAmount: PUBLAmount;
    AccountingCost: PText;
    Note: TLandrixEInvoiceStringList;
    InvoicePeriod: TLandrixUBLPeriodList;
    OrderLineReference: TLandrixUBLOrderLineReferenceList;
    DocumentReference: TLandrixUBLDocumentReferenceList;
    AllowanceCharge: TLandrixUBLAllowanceChargeList;
    Item: TLandrixUBLItem;
    Price: TLandrixUBLPrice;
  end;

{ --- views ------------------------------------------------------------------ }

{ Blank text (empty or XML white space only) counts as absent, as
  normalize-space() in the Schematron rules (LandrixEInvoiceIsBlank).
  DE: Leerer Text (leer oder nur XML-Leerraum) gilt als nicht vorhanden,
  wie normalize-space() in den Schematron-Regeln. }
function Blank(const S: TLandrixEInvoiceString): Boolean;
begin
  Result := LandrixEInvoiceIsBlank(S);
end;

function Present(const S: TLandrixEInvoiceString): Boolean;
begin
  Result := not LandrixEInvoiceIsBlank(S);
end;

function InvoiceDocument(AInvoice: TLandrixUBLInvoice): TUBLDocument;
begin
  Result.Invoice := AInvoice;
  Result.CreditNote := nil;
  Result.Path := '/Invoice';
  Result.TypeCodeName := 'cbc:InvoiceTypeCode';
  Result.LineName := 'cac:InvoiceLine';
  Result.CustomizationID := @AInvoice.CustomizationID;
  Result.ProfileID := @AInvoice.ProfileID;
  Result.ID := @AInvoice.ID;
  Result.IssueDate := @AInvoice.IssueDate;
  Result.DueDate := @AInvoice.DueDate;
  Result.TaxPointDate := @AInvoice.TaxPointDate;
  Result.TypeCode := @AInvoice.InvoiceTypeCode;
  Result.DocumentCurrencyCode := @AInvoice.DocumentCurrencyCode;
  Result.TaxCurrencyCode := @AInvoice.TaxCurrencyCode;
  Result.AccountingCost := @AInvoice.AccountingCost;
  Result.BuyerReference := @AInvoice.BuyerReference;
  Result.Note := AInvoice.Note;
  Result.InvoicePeriod := AInvoice.InvoicePeriod;
  Result.OrderReference := AInvoice.OrderReference;
  Result.BillingReference := AInvoice.BillingReference;
  Result.DespatchDocumentReference := AInvoice.DespatchDocumentReference;
  Result.ReceiptDocumentReference := AInvoice.ReceiptDocumentReference;
  Result.OriginatorDocumentReference := AInvoice.OriginatorDocumentReference;
  Result.ContractDocumentReference := AInvoice.ContractDocumentReference;
  Result.AdditionalDocumentReference := AInvoice.AdditionalDocumentReference;
  Result.ProjectReference := AInvoice.ProjectReference;
  Result.AccountingSupplierParty := AInvoice.AccountingSupplierParty;
  Result.AccountingCustomerParty := AInvoice.AccountingCustomerParty;
  Result.PayeeParty := AInvoice.PayeeParty;
  Result.TaxRepresentativeParty := AInvoice.TaxRepresentativeParty;
  Result.Delivery := AInvoice.Delivery;
  Result.PaymentMeans := AInvoice.PaymentMeans;
  Result.PaymentTerms := AInvoice.PaymentTerms;
  Result.PrepaidPayment := AInvoice.PrepaidPayment;
  Result.AllowanceCharge := AInvoice.AllowanceCharge;
  Result.TaxTotal := AInvoice.TaxTotal;
  Result.LegalMonetaryTotal := AInvoice.LegalMonetaryTotal;
end;

function CreditNoteDocument(ACreditNote: TLandrixUBLCreditNote): TUBLDocument;
begin
  Result.Invoice := nil;
  Result.CreditNote := ACreditNote;
  Result.Path := '/CreditNote';
  Result.TypeCodeName := 'cbc:CreditNoteTypeCode';
  Result.LineName := 'cac:CreditNoteLine';
  Result.CustomizationID := @ACreditNote.CustomizationID;
  Result.ProfileID := @ACreditNote.ProfileID;
  Result.ID := @ACreditNote.ID;
  Result.IssueDate := @ACreditNote.IssueDate;
  Result.DueDate := nil;
  Result.TaxPointDate := @ACreditNote.TaxPointDate;
  Result.TypeCode := @ACreditNote.CreditNoteTypeCode;
  Result.DocumentCurrencyCode := @ACreditNote.DocumentCurrencyCode;
  Result.TaxCurrencyCode := @ACreditNote.TaxCurrencyCode;
  Result.AccountingCost := @ACreditNote.AccountingCost;
  Result.BuyerReference := @ACreditNote.BuyerReference;
  Result.Note := ACreditNote.Note;
  Result.InvoicePeriod := ACreditNote.InvoicePeriod;
  Result.OrderReference := ACreditNote.OrderReference;
  Result.BillingReference := ACreditNote.BillingReference;
  Result.DespatchDocumentReference := ACreditNote.DespatchDocumentReference;
  Result.ReceiptDocumentReference := ACreditNote.ReceiptDocumentReference;
  Result.OriginatorDocumentReference := ACreditNote.OriginatorDocumentReference;
  Result.ContractDocumentReference := ACreditNote.ContractDocumentReference;
  Result.AdditionalDocumentReference := ACreditNote.AdditionalDocumentReference;
  Result.ProjectReference := nil;
  Result.AccountingSupplierParty := ACreditNote.AccountingSupplierParty;
  Result.AccountingCustomerParty := ACreditNote.AccountingCustomerParty;
  Result.PayeeParty := ACreditNote.PayeeParty;
  Result.TaxRepresentativeParty := ACreditNote.TaxRepresentativeParty;
  Result.Delivery := ACreditNote.Delivery;
  Result.PaymentMeans := ACreditNote.PaymentMeans;
  Result.PaymentTerms := ACreditNote.PaymentTerms;
  Result.PrepaidPayment := nil;
  Result.AllowanceCharge := ACreditNote.AllowanceCharge;
  Result.TaxTotal := ACreditNote.TaxTotal;
  Result.LegalMonetaryTotal := ACreditNote.LegalMonetaryTotal;
end;

function InvoiceLineOf(ALine: TLandrixUBLInvoiceLine): TUBLLine;
begin
  Result.InvoiceLine := ALine;
  Result.CreditNoteLine := nil;
  Result.QuantityName := 'cbc:InvoicedQuantity';
  Result.SubLineName := 'cac:SubInvoiceLine';
  Result.ID := @ALine.ID;
  Result.Quantity := @ALine.InvoicedQuantity;
  Result.LineExtensionAmount := @ALine.LineExtensionAmount;
  Result.AccountingCost := @ALine.AccountingCost;
  Result.Note := ALine.Note;
  Result.InvoicePeriod := ALine.InvoicePeriod;
  Result.OrderLineReference := ALine.OrderLineReference;
  Result.DocumentReference := ALine.DocumentReference;
  Result.AllowanceCharge := ALine.AllowanceCharge;
  Result.Item := ALine.Item;
  Result.Price := ALine.Price;
end;

function CreditNoteLineOf(ALine: TLandrixUBLCreditNoteLine): TUBLLine;
begin
  Result.InvoiceLine := nil;
  Result.CreditNoteLine := ALine;
  Result.QuantityName := 'cbc:CreditedQuantity';
  Result.SubLineName := 'cac:SubCreditNoteLine';
  Result.ID := @ALine.ID;
  Result.Quantity := @ALine.CreditedQuantity;
  Result.LineExtensionAmount := @ALine.LineExtensionAmount;
  Result.AccountingCost := @ALine.AccountingCost;
  Result.Note := ALine.Note;
  Result.InvoicePeriod := ALine.InvoicePeriod;
  Result.OrderLineReference := ALine.OrderLineReference;
  Result.DocumentReference := ALine.DocumentReference;
  Result.AllowanceCharge := ALine.AllowanceCharge;
  Result.Item := ALine.Item;
  Result.Price := ALine.Price;
end;

function LineCount(const ADocument: TUBLDocument): TLandrixEInvoiceListIndex;
begin
  if ADocument.Invoice <> nil then
    Result := ADocument.Invoice.InvoiceLine.Count
  else
    Result := ADocument.CreditNote.CreditNoteLine.Count;
end;

function LineAt(const ADocument: TUBLDocument; AIndex: TLandrixEInvoiceListIndex): TUBLLine;
begin
  if ADocument.Invoice <> nil then
    Result := InvoiceLineOf(ADocument.Invoice.InvoiceLine[AIndex])
  else
    Result := CreditNoteLineOf(ADocument.CreditNote.CreditNoteLine[AIndex]);
end;

function AddLine(const ADocument: TUBLDocument): TUBLLine;
begin
  if ADocument.Invoice <> nil then
    Result := InvoiceLineOf(ADocument.Invoice.InvoiceLine.Add)
  else
    Result := CreditNoteLineOf(ADocument.CreditNote.CreditNoteLine.Add);
end;

procedure ListDocumentChildren(const ADocument: TUBLDocument; AList: TLandrixEInvoiceStringList);
begin
  if ADocument.Invoice <> nil then
    ADocument.Invoice.ListFilledChildren(AList)
  else
    ADocument.CreditNote.ListFilledChildren(AList);
end;

function SubLineCount(const ALine: TUBLLine): TLandrixEInvoiceListIndex;
begin
  if ALine.InvoiceLine <> nil then
    Result := ALine.InvoiceLine.SubInvoiceLine.Count
  else
    Result := ALine.CreditNoteLine.SubCreditNoteLine.Count;
end;

function SubLineAt(const ALine: TUBLLine; AIndex: TLandrixEInvoiceListIndex): TUBLLine;
begin
  if ALine.InvoiceLine <> nil then
    Result := InvoiceLineOf(ALine.InvoiceLine.SubInvoiceLine[AIndex])
  else
    Result := CreditNoteLineOf(ALine.CreditNoteLine.SubCreditNoteLine[AIndex]);
end;

function AddSubLine(const ALine: TUBLLine): TUBLLine;
begin
  if ALine.InvoiceLine <> nil then
    Result := InvoiceLineOf(ALine.InvoiceLine.SubInvoiceLine.Add)
  else
    Result := CreditNoteLineOf(ALine.CreditNoteLine.SubCreditNoteLine.Add);
end;

procedure ListLineChildren(const ALine: TUBLLine; AList: TLandrixEInvoiceStringList);
begin
  if ALine.InvoiceLine <> nil then
    ALine.InvoiceLine.ListFilledChildren(AList)
  else
    ALine.CreditNoteLine.ListFilledChildren(AList);
end;

{ --- helpers ---------------------------------------------------------------- }

function DateSet(AValue: TDateTime): Boolean;
begin
  Result := AValue > 0;
end;

{ Periods: the invoice model of XRechnung-for-Delphi treats values up to 100
  (the first days of 1900) as "not set". DE: Zeitraeume: Das Rechnungsmodell
  aus XRechnung-for-Delphi behandelt Werte bis 100 (die ersten Tage 1900) als
  "nicht gesetzt". }
function PeriodDateSet(AValue: TDateTime): Boolean;
begin
  Result := AValue > 100;
end;

{ BG-14, BG-26: a period with an end before its start is not written
  (BR-29, BR-30); compared as dates (xs:date), the time is ignored.
  DE: BG-14, BG-26: ein Zeitraum mit Ende vor dem Beginn wird nicht
  geschrieben (BR-29, BR-30); als Datum verglichen (xs:date), die Uhrzeit
  zaehlt nicht. }
function PeriodReversed(AStart, AEnd: TDateTime): Boolean;
begin
  Result := PeriodDateSet(AStart) and PeriodDateSet(AEnd) and (Trunc(AEnd) < Trunc(AStart));
end;

function PeriodSet(AStart, AEnd: TDateTime): Boolean;
begin
  Result := (PeriodDateSet(AStart) or PeriodDateSet(AEnd)) and not PeriodReversed(AStart, AEnd);
end;

function UBLID(const AValue, AScheme: TLandrixEInvoiceString): TLandrixUBLID;
begin
  Result.Value := AValue;
  Result.SchemeID := AScheme;
end;

function UBLCode(const AValue: TLandrixEInvoiceString): TLandrixUBLCode;
begin
  Result.Value := AValue;
end;

{ Sets an optional date from a read value; 0 (not set or not converted)
  leaves it empty. }
procedure SetDate(var ADate: TLandrixEInvoiceDate; AValue: TDateTime);
begin
  if AValue > 0 then
    ADate.SetValue(AValue);
end;

function BoolText(AValue: Boolean): TLandrixEInvoiceString;
begin
  if AValue then
    Result := 'true'
  else
    Result := 'false';
end;

function AllowanceReasonCode(AItem: TLandrixInvoiceAllowanceCharge; out AOther: TLandrixEInvoiceString): TLandrixEInvoiceString;
begin
  if AItem.ChargeIndicator then
  begin
    Result := LandrixEInvoiceSpecialServiceDescriptionCodeToStr(AItem.ReasonCodeCharge);
    AOther := AItem.ReasonCodeChargeOther;
  end
  else
  begin
    Result := LandrixEInvoiceAllowanceOrChargeIdentCodeToStr(AItem.ReasonCodeAllowance);
    AOther := AItem.ReasonCodeAllowanceOther;
  end;
end;

function AddressSet(AAddress: TLandrixInvoiceAddress): Boolean;
begin
  Result := Present(AAddress.StreetName) or Present(AAddress.AdditionalStreetName) or
    Present(AAddress.AddressLine) or Present(AAddress.City) or Present(AAddress.PostalZone) or
    Present(AAddress.CountrySubentity) or Present(AAddress.CountryCode);
end;

{ A payee, tax representative or invoicee is written when a field other
  than a scheme holds text; blank text counts as absent (as in the rule
  checks).
  DE: Ein Zahlungsempfaenger, Steuervertreter oder Rechnungsempfaenger wird
  geschrieben, wenn ein Feld ausser einem Schema Text enthaelt; leerer Text
  gilt als nicht vorhanden (wie in den Regelpruefungen). }
function PartySet(AParty: TLandrixInvoiceParty): Boolean;
begin
  Result := Present(AParty.Name) or Present(AParty.Identifier) or Present(AParty.CompanyID) or
    Present(AParty.VATCompanyID) or AddressSet(AParty.Address) or Present(AParty.ContactName) or
    Present(AParty.ContactDepartment) or Present(AParty.ContactTelephone) or
    Present(AParty.ContactElectronicMail);
end;

{ The payee is written with BT-59, BT-60 or BT-61; then it carries the
  creditor identifier BT-90.
  DE: Der Zahlungsempfaenger wird mit BT-59, BT-60 oder BT-61 geschrieben;
  dann traegt er die Glaeubiger-ID BT-90. }
function PayeeWritten(AParty: TLandrixInvoiceParty): Boolean;
begin
  Result := Present(AParty.Name) or Present(AParty.Identifier) or Present(AParty.CompanyID);
end;

{ ASCII case-insensitive comparison without a detour through string.
  DE: Vergleich ohne Beachtung der ASCII-Gross-/Kleinschreibung, ohne Umweg
  ueber string. }
function SameAscii(const A, B: TLandrixEInvoiceString): Boolean;
var
  I: Integer;
  CA, CB: WideChar;
begin
  Result := False;
  if Length(A) <> Length(B) then
    Exit;
  for I := 1 to Length(A) do
  begin
    CA := A[I];
    CB := B[I];
    if (CA >= 'a') and (CA <= 'z') then
      CA := WideChar(Ord(CA) - 32);
    if (CB >= 'a') and (CB <= 'z') then
      CB := WideChar(Ord(CB) - 32);
    if CA <> CB then
      Exit;
  end;
  Result := True;
end;

{ Free text: line breaks are written as LF, as in LandrixEInvoiceMapCII.
  DE: Freitext: Zeilenumbrueche werden als LF geschrieben, wie in
  LandrixEInvoiceMapCII. }
function Txt(const S: TLandrixEInvoiceString): TLandrixEInvoiceString;
var
  I: Integer;
begin
  Result := '';
  I := 1;
  while I <= Length(S) do
  begin
    if S[I] = #13 then
    begin
      Result := Result + #10;
      if (I < Length(S)) and (S[I + 1] = #10) then
        Inc(I);
    end
    else
      Result := Result + S[I];
    Inc(I);
  end;
end;

{ XRechnung extension codes XR01 to XR03 as identifier schemes, exactly as
  KoSIT lists them (BR-DEX-04 to 08 compare case sensitively; 'xr01' is no
  extension code and is written as an unknown scheme).
  DE: Extension-Codes XR01 bis XR03 als Kennungsschema, genau so, wie KoSIT
  sie fuehrt (BR-DEX-04 bis 08 unterscheiden Gross- und Kleinschreibung;
  'xr01' ist kein Extension-Code und wird als unbekanntes Schema
  geschrieben). }
function IsExtensionScheme(const AValue, AScheme: TLandrixEInvoiceString): Boolean;
begin
  Result := Present(AValue) and ((AScheme = 'XR01') or (AScheme = 'XR02') or (AScheme = 'XR03'));
end;

{ --- TUBLWriteMapper ---------------------------------------------------------- }

type
  { Role of a TLandrixInvoiceParty; it decides which fields EN 16931 knows.
    DE: Rolle einer TLandrixInvoiceParty; sie bestimmt, welche Felder
    EN 16931 kennt. }
  TFurtherPartyRole = (fpr_Payee, fpr_TaxRepresentative, fpr_Invoicee);

  { Writes one invoice into one UBL document. DE: Schreibt eine Rechnung in
    ein UBL-Dokument. }
  TUBLWriteMapper = class(TObject)
  private
    FInvoice: TLandrixInvoice;
    FSpec: TLandrixEInvoiceSpec;
    FDiagnostics: TLandrixEInvoiceDiagnostics;
    FDoc: TUBLDocument;
    procedure Report(AKind: TLandrixEInvoiceDiagnosticKind; const APath, AMessage: TLandrixEInvoiceString;
      ASeverity: TLandrixEInvoiceDiagnosticSeverity);
    function Permit(const AKey: string; const APath, AWhat: TLandrixEInvoiceString): Boolean;
    function Code(const AEnumText, AOther, APath: TLandrixEInvoiceString): TLandrixEInvoiceString;
    function Money(AValue: Currency): TLandrixUBLAmount;
    function PriceMoney(AValue: Double): TLandrixUBLAmount;
    function UsesExtension: Boolean;
    procedure MapDocument;
    procedure MapReferences;
    procedure MapAttachments;
    procedure MapAddress(AAddress: TLandrixInvoiceAddress; ATarget: TLandrixUBLAddress);
    procedure MapParty(AParty: TLandrixInvoiceAccountingParty; ATarget: TLandrixUBLParty;
      const APath: TLandrixEInvoiceString; AIsSeller: Boolean);
    procedure MapFurtherParty(AParty: TLandrixInvoiceParty; ATarget: TLandrixUBLParty;
      const APath: TLandrixEInvoiceString; ARole: TFurtherPartyRole);
    procedure MapDelivery;
    procedure MapPaymentMeans;
    procedure MapPaymentTerms;
    procedure MapThirdPartyPayments;
    procedure MapAllowanceCharges;
    procedure MapTax;
    procedure MapTotals;
    procedure MapLine(ALine: TLandrixInvoiceLine; const ATarget: TUBLLine; const APath: TLandrixEInvoiceString);
    procedure MapLineItem(ALine: TLandrixInvoiceLine; AItem: TLandrixUBLItem; const APath: TLandrixEInvoiceString);
    procedure MapLinePrice(ALine: TLandrixInvoiceLine; APrice: TLandrixUBLPrice; const APath: TLandrixEInvoiceString);
  public
    constructor Create(AInvoice: TLandrixInvoice; const ASpec: TLandrixEInvoiceSpec;
      ADiagnostics: TLandrixEInvoiceDiagnostics; const ADocument: TUBLDocument);
    procedure Execute;
  end;

constructor TUBLWriteMapper.Create(AInvoice: TLandrixInvoice; const ASpec: TLandrixEInvoiceSpec;
  ADiagnostics: TLandrixEInvoiceDiagnostics; const ADocument: TUBLDocument);
begin
  inherited Create;
  FInvoice := AInvoice;
  FSpec := ASpec;
  FDiagnostics := ADiagnostics;
  FDoc := ADocument;
end;

procedure TUBLWriteMapper.Report(AKind: TLandrixEInvoiceDiagnosticKind;
  const APath, AMessage: TLandrixEInvoiceString; ASeverity: TLandrixEInvoiceDiagnosticSeverity);
begin
  if FDiagnostics <> nil then
    FDiagnostics.AddDiagnostic(AKind, APath, 0, 0, 0, AMessage).Severity := ASeverity;
end;

{ Asks the rule table whether present content may be written; reports
  discouraged (written) and forbidden (left out) content as warnings.
  DE: Fragt die Regel-Tabelle, ob vorhandener Inhalt geschrieben werden
  darf; meldet abgeratenen (geschrieben) und verbotenen (weggelassen)
  Inhalt als Warnung. }
function TUBLWriteMapper.Permit(const AKey: string; const APath, AWhat: TLandrixEInvoiceString): Boolean;
var
  Rule: TLandrixEInvoiceRule;
begin
  Result := True;
  if not LandrixEInvoiceFindRule(FSpec, AKey, Rule) then
    Exit;
  case Rule.Level of
    erl_Discouraged:
      Report(edk_NotAllowed, APath, AWhat + ' is discouraged (' + TLandrixEInvoiceString(Rule.Terms) +
        ', ' + TLandrixEInvoiceString(Rule.Source) + '); written', eds_Warning);
    erl_Forbidden:
      begin
        Report(edk_NotAllowed, APath, AWhat + ' is not allowed (' + TLandrixEInvoiceString(Rule.Terms) +
          ', ' + TLandrixEInvoiceString(Rule.Source) + '); left out', eds_Warning);
        Result := False;
      end;
  else
    ;
  end;
end;

{ A code of the model: the enumeration wins when set, otherwise the ...Other
  text is written. DE: Ein Code des Modells: die Aufzaehlung gewinnt, wenn
  sie gesetzt ist, sonst wird der ...Other-Text geschrieben. }
function TUBLWriteMapper.Code(const AEnumText, AOther, APath: TLandrixEInvoiceString): TLandrixEInvoiceString;
begin
  if Blank(AEnumText) then
  begin
    Result := AOther;
    Exit;
  end;
  Result := AEnumText;
  if Present(AOther) and (AOther <> AEnumText) then
    Report(edk_UnknownCode, APath, 'code ' + AEnumText + ' written; the other code ' + AOther +
      ' is ignored', eds_Warning);
end;

{ Amounts carry the invoice currency (BT-5).
  DE: Betraege tragen die Rechnungswaehrung (BT-5). }
function TUBLWriteMapper.Money(AValue: Currency): TLandrixUBLAmount;
begin
  Result.Value := LandrixEInvoiceAmountToLexical(AValue);
  Result.CurrencyID := FInvoice.InvoiceCurrencyCode;
end;

function TUBLWriteMapper.PriceMoney(AValue: Double): TLandrixUBLAmount;
begin
  Result.Value := LandrixEInvoicePriceToLexical(AValue);
  Result.CurrencyID := FInvoice.InvoiceCurrencyCode;
end;

{ The XRechnung extension is declared only when the invoice has extension
  content: sub lines (BG-DEX-01), embedded XML attachments (BR-DEX-01),
  third-party payments (BG-DEX-09) or the extension codes XR01 to XR03 as
  scheme of BT-34, BT-49, BT-29, BT-46, BT-71, BT-30, BT-47, BT-60, BT-61
  or BT-157 (BR-DEX-04 to 08). Many receivers reject the extension. A
  credit note never uses it: KoSIT has no extension scenario for
  ubl:CreditNote. As in XRechnung-for-Delphi an XML attachment counts even
  when it is left out later (BT-18 without identifier).
  DE: Die XRechnung-Extension wird nur deklariert, wenn die Rechnung
  Extension-Inhalt hat: Unterpositionen (BG-DEX-01), eingebettete
  XML-Anhaenge (BR-DEX-01), Zahlungen Dritter (BG-DEX-09) oder die
  Extension-Codes XR01 bis XR03 als Schema von BT-34, BT-49, BT-29, BT-46,
  BT-71, BT-30, BT-47, BT-60, BT-61 oder BT-157 (BR-DEX-04 bis 08). Viele
  Empfaenger lehnen die Extension ab. Eine Gutschrift verwendet sie nie:
  KoSIT kennt kein Extension-Szenario fuer ubl:CreditNote. Wie in
  XRechnung-for-Delphi zaehlt ein XML-Anhang auch dann, wenn er spaeter
  weggelassen wird (BT-18 ohne Kennung). }
function TUBLWriteMapper.UsesExtension: Boolean;
var
  I: TLandrixEInvoiceListIndex;
  Value, Scheme, Conflict: TLandrixEInvoiceString;
begin
  Result := False;
  if Blank(FSpec.ExtensionCustomizationID) or (FDoc.Invoice = nil) then
    Exit;
  Result := True;
  for I := 0 to FInvoice.InvoiceLines.Count - 1 do
    if FInvoice.InvoiceLines[I].SubInvoiceLines.Count > 0 then
      Exit;
  for I := 0 to FInvoice.Attachments.Count - 1 do
    if FInvoice.Attachments[I].ContainsBinaryObject and
       (FInvoice.Attachments[I].AttachmentType = iat_application_xml) then
      Exit;
  if FInvoice.PrepaidPayments.Count > 0 then
    Exit;
  if IsExtensionScheme(FInvoice.AccountingSupplierParty.ElectronicAddressSellerBuyer,
       FInvoice.AccountingSupplierParty.ElectronicAddressSellerBuyerSchemeID) or
     IsExtensionScheme(FInvoice.AccountingCustomerParty.ElectronicAddressSellerBuyer,
       FInvoice.AccountingCustomerParty.ElectronicAddressSellerBuyerSchemeID) or
     IsExtensionScheme(FInvoice.AccountingSupplierParty.GlobalIdentifierSellerBuyer,
       FInvoice.AccountingSupplierParty.GlobalIdentifierSellerBuyerSchemeID) or
     IsExtensionScheme(FInvoice.AccountingCustomerParty.GlobalIdentifierSellerBuyer,
       FInvoice.AccountingCustomerParty.GlobalIdentifierSellerBuyerSchemeID) or
     IsExtensionScheme(FInvoice.DeliveryInformation.LocationIdentifier,
       FInvoice.DeliveryInformation.LocationIdentifierSchemeID) or
     IsExtensionScheme(FInvoice.AccountingSupplierParty.CompanyID,
       FInvoice.AccountingSupplierParty.CompanyIDSchemeID) or
     IsExtensionScheme(FInvoice.AccountingCustomerParty.CompanyID,
       FInvoice.AccountingCustomerParty.CompanyIDSchemeID) or
     IsExtensionScheme(FInvoice.PayeeParty.Identifier, FInvoice.PayeeParty.IdentifierSchemeID) or
     IsExtensionScheme(FInvoice.PayeeParty.CompanyID, FInvoice.PayeeParty.CompanyIDSchemeID) then
    Exit;
  for I := 0 to FInvoice.InvoiceLines.Count - 1 do
    if LandrixEInvoiceStandardItemIdentifierOf(FInvoice.InvoiceLines[I], Value, Scheme, Conflict) and
       IsExtensionScheme(Value, Scheme) then
      Exit;
  Result := False;
end;

procedure TUBLWriteMapper.Execute;
var
  I: TLandrixEInvoiceListIndex;
begin
  MapDocument;
  MapReferences;
  MapAttachments;
  MapParty(FInvoice.AccountingSupplierParty, FDoc.AccountingSupplierParty.Party,
    FDoc.Path + '/cac:AccountingSupplierParty/cac:Party', True);
  MapParty(FInvoice.AccountingCustomerParty, FDoc.AccountingCustomerParty.Party,
    FDoc.Path + '/cac:AccountingCustomerParty/cac:Party', False);
  MapFurtherParty(FInvoice.PayeeParty, FDoc.PayeeParty, FDoc.Path + '/cac:PayeeParty', fpr_Payee);
  MapFurtherParty(FInvoice.TaxRepresentativeParty, FDoc.TaxRepresentativeParty,
    FDoc.Path + '/cac:TaxRepresentativeParty', fpr_TaxRepresentative);
  MapFurtherParty(FInvoice.InvoiceeParty, nil, FDoc.Path, fpr_Invoicee);
  MapDelivery;
  MapPaymentMeans;
  MapPaymentTerms;
  MapThirdPartyPayments;
  MapAllowanceCharges;
  MapTax;
  MapTotals;
  for I := 0 to FInvoice.InvoiceLines.Count - 1 do
    MapLine(FInvoice.InvoiceLines[I], AddLine(FDoc), FDoc.Path + '/' + FDoc.LineName);
end;

{ BT-24 specification identifier (with the extension when used), BT-23
  business process, BT-1 number, BT-2 issue date, BT-9 due date (not on a
  credit note), BT-3 type, BG-1 notes (subject code as '#code#' prefix),
  BT-5 currency, BT-6 VAT accounting currency (only when it differs), BT-19
  buyer accounting reference, BT-7 VAT point date, BG-14 invoice period
  with BT-8 VAT point date code. BT-X-1 and BT-X-2 have no element.
  DE: BT-24 Spezifikationskennung (mit Extension, wenn verwendet), BT-23
  Geschaeftsprozess, BT-1 Nummer, BT-2 Rechnungsdatum, BT-9
  Faelligkeitsdatum (nicht auf einer Gutschrift), BT-3 Art, BG-1 Bemerkungen
  (Betreffcode als Praefix '#Code#'), BT-5 Waehrung, BT-6
  Steuerwaehrung (nur wenn abweichend), BT-19 Buchungsreferenz des
  Kaeufers, BT-7 Steuerdatum, BG-14 Rechnungszeitraum mit BT-8 Code des
  Steuerdatums. BT-X-1 und BT-X-2 haben kein Element. }
procedure TUBLWriteMapper.MapDocument;
var
  I: TLandrixEInvoiceListIndex;
  Text, Subject, PointCode: TLandrixEInvoiceString;
  Period: TLandrixUBLPeriod;
  HasPeriod: Boolean;
begin
  if UsesExtension then
    FDoc.CustomizationID^.Value := FSpec.ExtensionCustomizationID
  else
    FDoc.CustomizationID^.Value := FSpec.CustomizationID;
  if Present(FInvoice.ProfileID) then
    FDoc.ProfileID^.Value := FInvoice.ProfileID
  else
    FDoc.ProfileID^.Value := FSpec.ProfileID;
  FDoc.ID^.Value := FInvoice.InvoiceNumber;
  if DateSet(FInvoice.InvoiceIssueDate) then
    FDoc.IssueDate^ := LandrixEInvoiceDateToUBL(FInvoice.InvoiceIssueDate);
  if DateSet(FInvoice.InvoiceDueDate) then
  begin
    if FDoc.DueDate = nil then
      Report(edk_NotAllowed, FDoc.Path, 'due date (BT-9) left out: ubl:CreditNote has no cbc:DueDate', eds_Warning)
    else if (FInvoice.InvoiceTypeCode = itc_CreditNote) and
      (LandrixEInvoiceRuleLevel(FSpec, LandrixEInvoiceRuleCreditNoteDueDate) = erl_Forbidden) then
      Report(edk_NotAllowed, FDoc.Path + '/cbc:DueDate', 'due date (BT-9) left out on a credit note', eds_Warning)
    else
      FDoc.DueDate^ := LandrixEInvoiceDateToUBL(FInvoice.InvoiceDueDate);
  end;
  FDoc.TypeCode^.Value := Code(LandrixEInvoiceTypeCodeToStr(FInvoice.InvoiceTypeCode), FInvoice.InvoiceTypeCodeOther,
    FDoc.Path + '/' + FDoc.TypeCodeName);
  for I := 0 to FInvoice.Notes.Count - 1 do
  begin
    { BG-1 needs its text (BT-22); a blank note is no note.
      DE: BG-1 braucht seinen Text (BT-22); eine leere Bemerkung ist keine. }
    if Blank(FInvoice.Notes[I].Content) then
      Continue;
    Text := Txt(FInvoice.Notes[I].Content);
    Subject := Code(LandrixEInvoiceNoteSubjectCodeToStr(FInvoice.Notes[I].SubjectCode),
      FInvoice.Notes[I].SubjectCodeOther, FDoc.Path + '/cbc:Note');
    if Present(Subject) then
      Text := '#' + Subject + '#' + Text;
    FDoc.Note.Add(Text);
  end;
  FDoc.DocumentCurrencyCode^.Value := FInvoice.InvoiceCurrencyCode;
  if Present(FInvoice.TaxCurrencyCode) and (FInvoice.TaxCurrencyCode <> FInvoice.InvoiceCurrencyCode) then
    FDoc.TaxCurrencyCode^.Value := FInvoice.TaxCurrencyCode;
  FDoc.AccountingCost^ := FInvoice.BuyerAccountingReference;
  PointCode := FInvoice.TaxPointDateCode;
  if FInvoice.TaxPointDate.HasValue then
  begin
    FDoc.TaxPointDate^ := LandrixEInvoiceDateToUBL(FInvoice.TaxPointDate.Value);
    { BR-CO-3: BT-7 and BT-8 are mutually exclusive; the date wins.
      DE: BR-CO-3: BT-7 und BT-8 schliessen sich aus; das Datum gewinnt. }
    if Present(PointCode) then
    begin
      Report(edk_NotAllowed, FDoc.Path + '/cac:InvoicePeriod/cbc:DescriptionCode', 'VAT point date code ' +
        PointCode + ' (BT-8) left out: the VAT point date (BT-7) is set (BR-CO-3)', eds_Warning);
      PointCode := '';
    end;
  end;
  { BT-8 lives in the invoice period (BG-14) }
  HasPeriod := PeriodSet(FInvoice.InvoicePeriodStartDate, FInvoice.InvoicePeriodEndDate);
  if PeriodReversed(FInvoice.InvoicePeriodStartDate, FInvoice.InvoicePeriodEndDate) then
    Report(edk_NotAllowed, FDoc.Path + '/cac:InvoicePeriod',
      'invoice period (BG-14) left out: the end date is before the start date (BR-29)', eds_Warning);
  if HasPeriod or Present(PointCode) then
  begin
    Period := FDoc.InvoicePeriod.Add;
    if HasPeriod and PeriodDateSet(FInvoice.InvoicePeriodStartDate) then
      Period.StartDate := LandrixEInvoiceDateToUBL(FInvoice.InvoicePeriodStartDate);
    if HasPeriod and PeriodDateSet(FInvoice.InvoicePeriodEndDate) then
      Period.EndDate := LandrixEInvoiceDateToUBL(FInvoice.InvoicePeriodEndDate);
    if Present(PointCode) then
      Period.DescriptionCode.Add(UBLCode(PointCode));
  end;
  if FInvoice.TestIndicator.HasValue then
    Permit(LandrixEInvoiceRuleTestIndicator, FDoc.Path, 'test indicator');
  if Present(FInvoice.DocumentName) then
    Permit(LandrixEInvoiceRuleDocumentName, FDoc.Path, 'document name');
end;

{ BT-10 buyer reference (the placeholder 'non-existent' only for XRechnung
  and Peppol),
  BT-13 purchase order ('NA' when only BT-14 is known, as Peppol demands),
  BT-14 sales order, BG-3 preceding invoices, BT-16 despatch advice (its
  date BT-X-200 has no element), BT-15 receiving advice, BT-12 contract,
  BT-11 project (ubl:Invoice only; see MapAttachments for the credit note),
  delivery note (EXTENDED only).
  DE: BT-10 Kaeuferreferenz (der Platzhalter 'non-existent' nur fuer
  XRechnung und Peppol), BT-13 Bestellung ('NA', wenn nur BT-14 bekannt ist, wie
  Peppol es verlangt), BT-14 Auftrag, BG-3 vorausgegangene Rechnungen,
  BT-16 Versandanzeige (ihr Datum BT-X-200 hat kein Element), BT-15
  Wareneingangsmeldung, BT-12 Vertrag, BT-11 Projekt (nur ubl:Invoice; zur
  Gutschrift siehe MapAttachments), Lieferschein (nur EXTENDED). }
procedure TUBLWriteMapper.MapReferences;
var
  I: TLandrixEInvoiceListIndex;
  Reference: TLandrixInvoicePrecedingInvoiceReference;
  Billing: TLandrixUBLBillingReference;
begin
  if SameAscii(FInvoice.BuyerReference, LandrixEInvoiceLeitwegIDNonExistent) and
    (LandrixEInvoiceRuleLevel(FSpec, LandrixEInvoiceRuleBuyerReferencePlaceholder) = erl_Forbidden) then
    { the placeholder only means "no buyer reference"; nothing is lost }
    Report(edk_NotAllowed, FDoc.Path + '/cbc:BuyerReference',
      'placeholder ' + FInvoice.BuyerReference + ' (BT-10) left out; only XRechnung and Peppol use it', eds_Info)
  else
    FDoc.BuyerReference^ := FInvoice.BuyerReference;
  if Present(FInvoice.PurchaseOrderReference) or Present(FInvoice.SellerOrderReference) then
  begin
    if Blank(FInvoice.PurchaseOrderReference) then
      FDoc.OrderReference.ID.Value := 'NA'
    else
      FDoc.OrderReference.ID.Value := FInvoice.PurchaseOrderReference;
    FDoc.OrderReference.SalesOrderID.Value := FInvoice.SellerOrderReference;
  end;
  if FInvoice.SellerOrderReferenceDate.HasValue or FInvoice.PurchaseOrderReferenceDate.HasValue then
    Permit(LandrixEInvoiceRuleOrderDates, FDoc.Path + '/cac:OrderReference', 'date of the sales or purchase order');
  for I := 0 to FInvoice.PrecedingInvoiceReferences.Count - 1 do
  begin
    Reference := FInvoice.PrecedingInvoiceReferences[I];
    if (I > 0) and not Permit(LandrixEInvoiceRuleMultiplePrecedingInvoices,
      FDoc.Path + '/cac:BillingReference', 'preceding invoice ' + Reference.ID) then
      Continue;
    Billing := FDoc.BillingReference.Add;
    Billing.InvoiceDocumentReference.ID.Value := Reference.ID;
    if DateSet(Reference.IssueDate) then
      Billing.InvoiceDocumentReference.IssueDate := LandrixEInvoiceDateToUBL(Reference.IssueDate);
  end;
  if Present(FInvoice.DeliveryReceiptNumber) then
  begin
    FDoc.DespatchDocumentReference.Add.ID.Value := FInvoice.DeliveryReceiptNumber;
    if DateSet(FInvoice.DeliveryReceiptDate) then
      Permit(LandrixEInvoiceRuleDespatchAdviceDate, FDoc.Path + '/cac:DespatchDocumentReference',
        'despatch advice date');
  end;
  if Present(FInvoice.ReceiptDocumentReference) then
    FDoc.ReceiptDocumentReference.Add.ID.Value := FInvoice.ReceiptDocumentReference;
  if Present(FInvoice.ContractDocumentReference) then
    FDoc.ContractDocumentReference.Add.ID.Value := FInvoice.ContractDocumentReference;
  if Present(FInvoice.ProjectReference) and (FDoc.ProjectReference <> nil) then
    FDoc.ProjectReference.Add.ID.Value := FInvoice.ProjectReference;
  if Present(FInvoice.DeliveryReceiptNumberExtended) then
    Permit(LandrixEInvoiceRuleDeliveryNote, FDoc.Path, 'delivery note');
end;

{ BG-24 attachments, BT-17 tender reference (type 50, cac:Originator-
  DocumentReference) and BT-18 object identifier (type 130): BT-17 and BT-18
  only once and only with an identifier. An attachment carries no type code
  in UBL (UBL-CR-114), only BT-18 does. ubl:CreditNote has no
  cac:ProjectReference: BT-11 is written as an additional document
  reference with type 50 there.
  DE: BG-24 Anlagen, BT-17 Vergabe (Art 50, cac:OriginatorDocument-
  Reference) und BT-18 Objektkennung (Art 130): BT-17 und BT-18 nur einmal
  und nur mit Kennung. Eine Anlage traegt in UBL keine Art (UBL-CR-114),
  nur BT-18. ubl:CreditNote hat kein cac:ProjectReference: BT-11 wird dort
  als weitere Dokumentreferenz mit Art 50 geschrieben. }
procedure TUBLWriteMapper.MapAttachments;
var
  I: TLandrixEInvoiceListIndex;
  Attachment: TLandrixInvoiceAttachment;
  Target: TLandrixUBLDocumentReference;
  TenderWritten, ObjectWritten: Boolean;
  Path, TypeText: TLandrixEInvoiceString;
begin
  Path := FDoc.Path + '/cac:AdditionalDocumentReference';
  if Present(FInvoice.ProjectReference) and (FDoc.ProjectReference = nil) then
  begin
    Target := FDoc.AdditionalDocumentReference.Add;
    Target.ID.Value := FInvoice.ProjectReference;
    Target.DocumentTypeCode.Value := '50';
  end;
  TenderWritten := False;
  ObjectWritten := False;
  for I := 0 to FInvoice.Attachments.Count - 1 do
  begin
    Attachment := FInvoice.Attachments[I];
    if Attachment.TypeCode = iatc_50 then
    begin
      if TenderWritten or Blank(Attachment.ID) then
        Report(edk_NotAllowed, FDoc.Path + '/cac:OriginatorDocumentReference', 'tender reference (BT-17) ' +
          Attachment.ID + ' left out: only once and with an identifier', eds_Warning)
      else
      begin
        FDoc.OriginatorDocumentReference.Add.ID.Value := Attachment.ID;
        TenderWritten := True;
      end;
      Continue;
    end;
    if Attachment.TypeCode = iatc_130 then
    begin
      if ObjectWritten or Blank(Attachment.ID) then
      begin
        Report(edk_NotAllowed, Path, 'object identifier (BT-18) ' + Attachment.ID +
          ' left out: only once and with an identifier', eds_Warning);
        Continue;
      end;
      ObjectWritten := True;
    end;
    Target := FDoc.AdditionalDocumentReference.Add;
    Target.ID.Value := Attachment.ID;
    if Attachment.TypeCode = iatc_130 then
      Target.ID.SchemeID := Attachment.SchemeID
    else if Present(Attachment.SchemeID) then
      Report(edk_NotAllowed, Path + '/cbc:ID/@schemeID', 'scheme ' + Attachment.SchemeID + ' of attachment ' +
        Attachment.ID + ' left out: only the invoiced object identifier (BT-18) has one', eds_Warning);
    if Attachment.TypeCode = iatc_130 then
      Target.DocumentTypeCode.Value := '130'
    else if (Attachment.TypeCode <> iatc_916) or Present(Attachment.TypeCodeOther) then
    begin
      TypeText := Code(LandrixEInvoiceAttachmentTypeCodeToStr(Attachment.TypeCode), Attachment.TypeCodeOther,
        Path + '/cbc:DocumentTypeCode');
      Report(edk_NotAllowed, Path + '/cbc:DocumentTypeCode', 'document type ' + TypeText + ' of attachment ' +
        Attachment.ID + ' left out: attachments carry no type code in UBL (UBL-CR-114)', eds_Info);
    end;
    if Present(Attachment.DocumentDescription) then
      Target.DocumentDescription.Add(Txt(Attachment.DocumentDescription));
    if Attachment.ContainsBinaryObject then
    begin
      Target.Attachment.EmbeddedDocumentBinaryObject.Value := Attachment.GetDataAsBase64;
      Target.Attachment.EmbeddedDocumentBinaryObject.MimeCode := Code(
        LandrixEInvoiceAttachmentTypeToStr(Attachment.AttachmentType), Attachment.AttachmentTypeOther,
        Path + '/cac:Attachment/cbc:EmbeddedDocumentBinaryObject/@mimeCode');
      Target.Attachment.EmbeddedDocumentBinaryObject.Filename := Attachment.Filename;
    end;
    if Present(Attachment.ExternalReference) then
      Target.Attachment.ExternalReference.URI.Value := Attachment.ExternalReference;
  end;
end;

procedure TUBLWriteMapper.MapAddress(AAddress: TLandrixInvoiceAddress; ATarget: TLandrixUBLAddress);
begin
  ATarget.StreetName := AAddress.StreetName;
  ATarget.AdditionalStreetName := AAddress.AdditionalStreetName;
  ATarget.CityName := AAddress.City;
  ATarget.PostalZone := AAddress.PostalZone;
  ATarget.CountrySubentity := AAddress.CountrySubentity;
  if Present(AAddress.AddressLine) then
    ATarget.AddressLine.Add.Line := AAddress.AddressLine;
  ATarget.Country.IdentificationCode.Value := AAddress.CountryCode;
end;

{ BG-4 seller and BG-7 buyer: BT-34/BT-49 electronic address (without
  scheme the default 'EM' where the specification allows it), BT-29/BT-46
  identifier and global identifier (default scheme 0088; both together only
  where the rule table allows it), BT-90 creditor identifier (seller,
  scheme SEPA, unless a payee is written), BT-28/BT-45 trading name,
  BG-5/BG-8 address, BT-31/BT-32 VAT and tax registration (the buyer has
  one: the VAT identifier wins),
  BT-27/BT-44 name, BT-30/BT-47 legal registration, BT-33 additional legal
  information (seller), BG-6/BG-9 contact.
  DE: BG-4 Verkaeufer und BG-7 Kaeufer: BT-34/BT-49 elektronische Adresse
  (ohne Schema gilt 'EM', wo die Spezifikation es erlaubt), BT-29/BT-46
  Kennung und globale Kennung (Vorgabeschema 0088; beide zusammen nur, wo
  die Regel-Tabelle es erlaubt), BT-90 Glaeubiger-ID (Verkaeufer, Schema
  SEPA, ausser ein Zahlungsempfaenger wird geschrieben), BT-28/BT-45
  Handelsname, BG-5/BG-8 Anschrift, BT-31/BT-32 USt-IdNr.
  und Steuernummer (der Kaeufer hat eine: die USt-IdNr. gewinnt), BT-27/
  BT-44 Name, BT-30/BT-47 Registernummer, BT-33 weitere rechtliche
  Informationen (Verkaeufer), BG-6/BG-9 Kontakt. }
procedure TUBLWriteMapper.MapParty(AParty: TLandrixInvoiceAccountingParty; ATarget: TLandrixUBLParty;
  const APath: TLandrixEInvoiceString; AIsSeller: Boolean);
var
  Scheme: TLandrixEInvoiceString;
  TaxScheme: TLandrixUBLPartyTaxScheme;
  LegalEntity: TLandrixUBLPartyLegalEntity;
  RuleKey: string;
  WriteIdentifier: Boolean;
begin
  if Present(AParty.ElectronicAddressSellerBuyer) then
  begin
    Scheme := AParty.ElectronicAddressSellerBuyerSchemeID;
    if Blank(Scheme) and
       (LandrixEInvoiceRuleLevel(FSpec, LandrixEInvoiceRuleElectronicAddressDefaultEM) <> erl_Forbidden) then
      Scheme := 'EM';
    ATarget.EndpointID := UBLID(AParty.ElectronicAddressSellerBuyer, Scheme);
    if Blank(Scheme) then
      Report(edk_MissingElement, APath + '/cbc:EndpointID/@schemeID', 'electronic address without scheme', eds_Error);
  end;
  if AIsSeller then
    RuleKey := LandrixEInvoiceRuleSellerIDWithGlobalID
  else
    RuleKey := LandrixEInvoiceRuleBuyerIDWithGlobalID;
  WriteIdentifier := Present(AParty.IdentifierSellerBuyer);
  if WriteIdentifier and Present(AParty.GlobalIdentifierSellerBuyer) and
     (LandrixEInvoiceRuleLevel(FSpec, RuleKey) = erl_Forbidden) then
  begin
    WriteIdentifier := False;
    Report(edk_NotAllowed, APath + '/cac:PartyIdentification',
      'identifier ' + AParty.IdentifierSellerBuyer + ' left out, the global identifier is written', eds_Warning);
  end;
  if Present(AParty.GlobalIdentifierSellerBuyer) then
  begin
    Scheme := AParty.GlobalIdentifierSellerBuyerSchemeID;
    if Blank(Scheme) then
      Scheme := '0088';
    ATarget.PartyIdentification.Add.ID := UBLID(AParty.GlobalIdentifierSellerBuyer, Scheme);
  end;
  if WriteIdentifier then
    ATarget.PartyIdentification.Add.ID := UBLID(AParty.IdentifierSellerBuyer, '');
  if AIsSeller and Present(AParty.BankAssignedCreditorIdentifier) and not PayeeWritten(FInvoice.PayeeParty) then
    ATarget.PartyIdentification.Add.ID := UBLID(AParty.BankAssignedCreditorIdentifier, 'SEPA');
  if Present(AParty.Name) then
    ATarget.PartyName.Add.Name := Txt(AParty.Name);
  MapAddress(AParty.Address, ATarget.PostalAddress);
  if Present(AParty.VATCompanyID) then
  begin
    TaxScheme := ATarget.PartyTaxScheme.Add;
    TaxScheme.CompanyID.Value := AParty.VATCompanyID;
    TaxScheme.TaxScheme.ID.Value := 'VAT';
  end;
  if Present(AParty.VATCompanyNumber) and (AIsSeller or Blank(AParty.VATCompanyID)) then
  begin
    TaxScheme := ATarget.PartyTaxScheme.Add;
    TaxScheme.CompanyID.Value := AParty.VATCompanyNumber;
    TaxScheme.TaxScheme.ID.Value := 'FC';
  end;
  LegalEntity := ATarget.PartyLegalEntity.Add;
  LegalEntity.RegistrationName := Txt(AParty.RegistrationName);
  if Present(AParty.CompanyID) then
    LegalEntity.CompanyID := UBLID(AParty.CompanyID, AParty.CompanyIDSchemeID);
  if AIsSeller then
    LegalEntity.CompanyLegalForm := Txt(AParty.AdditionalLegalInformationSeller);
  { BT-41/BT-56 is the contact point: without a person name the department is
    it (as in CII, where it is the alternative to the name; XRechnung needs
    BT-41, BR-DE-5); next to a name UBL has no place for it.
    DE: BT-41/BT-56 ist die Kontaktstelle: ohne Personennamen ist es die
    Abteilung (wie in CII, wo sie die Alternative zum Namen ist; XRechnung
    verlangt BT-41, BR-DE-5); neben einem Namen hat UBL keinen Platz dafuer. }
  if Present(AParty.ContactName) then
  begin
    ATarget.Contact.Name := AParty.ContactName;
    if Present(AParty.ContactDepartment) then
      Permit(LandrixEInvoiceRuleContactDepartment, APath + '/cac:Contact', 'contact department ' +
        AParty.ContactDepartment);
  end
  else
    ATarget.Contact.Name := AParty.ContactDepartment;
  ATarget.Contact.Telephone := AParty.ContactTelephone;
  ATarget.Contact.ElectronicMail := AParty.ContactElectronicMail;
end;

{ BG-10 payee (cac:PayeeParty: BT-60 identifier, the creditor identifier
  BT-90 with scheme SEPA as the XRechnung example direct-debit-bt-90-payee,
  BT-59 name, BT-61 legal registration) and BG-11 tax representative
  (cac:TaxRepresentativeParty: BT-62 name, BG-12 address, BT-63 VAT
  identifier). Everything else of these parties and the invoicee (BG-X-36)
  exists in Factur-X EXTENDED only and is reported as left out.
  DE: BG-10 Zahlungsempfaenger (cac:PayeeParty: BT-60 Kennung, die
  Glaeubiger-ID BT-90 mit Schema SEPA wie im XRechnung-Beispiel
  direct-debit-bt-90-payee, BT-59 Name, BT-61 Registernummer) und BG-11
  Steuervertreter
  (cac:TaxRepresentativeParty: BT-62 Name, BG-12 Anschrift, BT-63
  USt-IdNr.). Alles Weitere dieser Parteien und der Rechnungsempfaenger
  (BG-X-36) gibt es nur in Factur-X EXTENDED; es wird als weggelassen
  gemeldet. }
procedure TUBLWriteMapper.MapFurtherParty(AParty: TLandrixInvoiceParty; ATarget: TLandrixUBLParty;
  const APath: TLandrixEInvoiceString; ARole: TFurtherPartyRole);
var
  HasContact: Boolean;
  TaxScheme: TLandrixUBLPartyTaxScheme;
begin
  if not PartySet(AParty) then
    Exit;
  if ARole = fpr_Invoicee then
  begin
    Permit(LandrixEInvoiceRuleInvoicee, APath, 'invoicee');
    Exit;
  end;
  HasContact := Present(AParty.ContactName) or Present(AParty.ContactDepartment) or
    Present(AParty.ContactTelephone) or Present(AParty.ContactElectronicMail);
  if ARole = fpr_Payee then
  begin
    if HasContact or AddressSet(AParty.Address) or Present(AParty.VATCompanyID) then
      Permit(LandrixEInvoiceRulePayeeExtended, APath, 'address, contact or VAT identifier of the payee');
    if Present(AParty.Identifier) then
      ATarget.PartyIdentification.Add.ID := UBLID(AParty.Identifier, AParty.IdentifierSchemeID);
    if PayeeWritten(AParty) and Present(FInvoice.AccountingSupplierParty.BankAssignedCreditorIdentifier) then
      ATarget.PartyIdentification.Add.ID := UBLID(FInvoice.AccountingSupplierParty.BankAssignedCreditorIdentifier,
        'SEPA');
    if Present(AParty.Name) then
      ATarget.PartyName.Add.Name := Txt(AParty.Name);
    if Present(AParty.CompanyID) then
      ATarget.PartyLegalEntity.Add.CompanyID := UBLID(AParty.CompanyID, AParty.CompanyIDSchemeID);
  end
  else
  begin
    if HasContact or Present(AParty.Identifier) or Present(AParty.CompanyID) then
      Permit(LandrixEInvoiceRuleTaxRepresentativeExtended, APath, 'identifier or contact of the tax representative');
    if Present(AParty.Name) then
      ATarget.PartyName.Add.Name := Txt(AParty.Name);
    if AddressSet(AParty.Address) then
      MapAddress(AParty.Address, ATarget.PostalAddress);
    if Present(AParty.VATCompanyID) then
    begin
      TaxScheme := ATarget.PartyTaxScheme.Add;
      TaxScheme.CompanyID.Value := AParty.VATCompanyID;
      TaxScheme.TaxScheme.ID.Value := 'VAT';
    end;
  end;
end;

{ BG-13 delivery: BT-72 delivery date, BT-71 location (with or without
  scheme), BG-15 delivery address, BT-70 name of the party delivered to;
  the contact (BG-X-26) has no element.
  DE: BG-13 Lieferung: BT-72 Lieferdatum, BT-71 Ort (mit oder ohne
  Schema), BG-15 Lieferanschrift, BT-70 Name des Belieferten; der Kontakt
  (BG-X-26) hat kein Element. }
procedure TUBLWriteMapper.MapDelivery;
var
  Info: TLandrixInvoiceDeliveryInformation;
  Target: TLandrixUBLDelivery;
begin
  Info := FInvoice.DeliveryInformation;
  if Present(Info.ContactName) or Present(Info.ContactTelephone) or Present(Info.ContactElectronicMail) then
    Permit(LandrixEInvoiceRuleDeliveryContact, FDoc.Path + '/cac:Delivery', 'deliver to contact');
  if not (DateSet(Info.ActualDeliveryDate) or Present(Info.LocationIdentifier) or Present(Info.Name) or
     AddressSet(Info.Address)) then
    Exit;
  Target := FDoc.Delivery.Add;
  if DateSet(Info.ActualDeliveryDate) then
    Target.ActualDeliveryDate := LandrixEInvoiceDateToUBL(Info.ActualDeliveryDate);
  if Present(Info.LocationIdentifier) then
    Target.DeliveryLocation.ID := UBLID(Info.LocationIdentifier, Info.LocationIdentifierSchemeID);
  if AddressSet(Info.Address) then
    MapAddress(Info.Address, Target.DeliveryLocation.Address);
  if Present(Info.Name) then
    Target.DeliveryParty.PartyName.Add.Name := Txt(Info.Name);
end;

{ BG-18 belongs to the card codes 48, 54 and 55 (BR-DE-24).
  DE: BG-18 gehoert zu den Kartencodes 48, 54 und 55 (BR-DE-24). }
function IsCardPayment(ACode: TLandrixInvoicePaymentMeansCode): Boolean;
begin
  Result := ACode in [ipmc_BankCard, ipmc_CreditCard, ipmc_DebitCard];
end;

{ BG-19 belongs to the direct debit codes 49 and 59: both carry the
  mandate (BT-89) and the debited account (BT-91); 49 is the general direct
  debit (Peppol and ZUGFeRD examples), 59 the SEPA direct debit.
  DE: BG-19 gehoert zu den Lastschriftcodes 49 und 59: beide tragen das
  Mandat (BT-89) und das belastete Konto (BT-91); 49 ist die allgemeine
  Lastschrift (Peppol- und ZUGFeRD-Beispiele), 59 die SEPA-Lastschrift. }
function IsDirectDebit(ACode: TLandrixInvoicePaymentMeansCode): Boolean;
begin
  Result := ACode in [ipmc_DirectDebit, ipmc_SEPADirectDebit];
end;

{ BG-16 payment instructions, one per payment type with a code: BT-81
  means, BT-82 text, BT-83 remittance information, BG-19 direct debit
  (BT-89 mandate, BT-91 debited account), BG-18 card (BT-87, BT-88; the
  network is not known and written as 'NA'), BG-17 credit transfer (BT-84,
  BT-85, BT-86). In UBL BT-83 and BT-89 exist only inside a payment
  instruction.
  DE: BG-16 Zahlungsanweisungen, eine je Zahlungsart mit Code: BT-81
  Zahlungsart, BT-82 Text, BT-83 Verwendungszweck, BG-19 Lastschrift (BT-89
  Mandat, BT-91 belastetes Konto), BG-18 Karte (BT-87, BT-88; das
  Kartennetz ist nicht bekannt und wird als 'NA' geschrieben), BG-17
  Ueberweisung (BT-84, BT-85, BT-86). In UBL gibt es BT-83 und BT-89 nur
  innerhalb einer Zahlungsanweisung. }
procedure TUBLWriteMapper.MapPaymentMeans;
var
  I: TLandrixEInvoiceListIndex;
  Payment: TLandrixInvoicePaymentType;
  Target: TLandrixUBLPaymentMeans;
  Path: TLandrixEInvoiceString;
  MeansWritten, MandateWritten: Boolean;
begin
  Path := FDoc.Path + '/cac:PaymentMeans';
  MeansWritten := False;
  MandateWritten := False;
  for I := 0 to FInvoice.PaymentTypes.Count - 1 do
  begin
    Payment := FInvoice.PaymentTypes[I];
    if (Payment.PaymentMeansCode = ipmc_NotImplemented) and Blank(Payment.PaymentMeansCodeOther) then
      Continue;
    MeansWritten := True;
    Target := FDoc.PaymentMeans.Add;
    Target.PaymentMeansCode.Value := Code(LandrixEInvoicePaymentMeansCodeToStr(Payment.PaymentMeansCode),
      Payment.PaymentMeansCodeOther, Path + '/cbc:PaymentMeansCode');
    Target.PaymentMeansCode.Name := Txt(Payment.PaymentMeansInformation);
    if Present(FInvoice.PaymentID) then
      Target.PaymentID.Add(UBLID(FInvoice.PaymentID, ''));
    if IsDirectDebit(Payment.PaymentMeansCode) then
    begin
      Target.PaymentMandate.ID.Value := FInvoice.PaymentMandateID;
      Target.PaymentMandate.PayerFinancialAccount.ID.Value := Payment.FinancialAccount;
      MandateWritten := True;
      if Present(Payment.FinancialAccountName) then
        Report(edk_NotAllowed, Path + '/cac:PaymentMandate/cac:PayerFinancialAccount/cbc:Name',
          'account name (BT-85) next to a direct debit left out: it belongs to the payee account', eds_Warning);
      if Present(Payment.FinancialInstitutionBranch) then
        Report(edk_NotAllowed, Path + '/cac:PayeeFinancialAccount/cac:FinancialInstitutionBranch',
          'BIC (BT-86) next to a direct debit left out: UBL carries it in the payee account', eds_Warning);
    end
    else if IsCardPayment(Payment.PaymentMeansCode) then
    begin
      Target.CardAccount.PrimaryAccountNumberID.Value := Payment.FinancialAccount;
      Target.CardAccount.NetworkID.Value := 'NA';
      Target.CardAccount.HolderName := Payment.FinancialAccountName;
    end
    else if Present(Payment.FinancialAccount) then
    begin
      Target.PayeeFinancialAccount.ID.Value := Payment.FinancialAccount;
      Target.PayeeFinancialAccount.Name := Payment.FinancialAccountName;
      Target.PayeeFinancialAccount.FinancialInstitutionBranch.ID.Value := Payment.FinancialInstitutionBranch;
    end;
  end;
  if Present(FInvoice.PaymentID) and not MeansWritten then
    Report(edk_NotAllowed, Path + '/cbc:PaymentID',
      'remittance information (BT-83) left out: UBL carries it in a payment instruction', eds_Warning);
  if Present(FInvoice.PaymentMandateID) and not MandateWritten then
    Report(edk_NotAllowed, Path + '/cac:PaymentMandate/cbc:ID',
      'mandate reference (BT-89) left out: UBL carries it in a direct debit instruction', eds_Warning);
end;

{ BT-20 payment terms as one text: the net note without '#', or the cash
  discounts in the German #SKONTO# form (XRechnung).
  DE: BT-20 Zahlungsbedingungen als ein Text: der Nettohinweis ohne '#'
  oder die Skonti in der deutschen #SKONTO#-Form (XRechnung). }
procedure TUBLWriteMapper.MapPaymentTerms;
var
  Text: TLandrixEInvoiceString;
begin
  if LandrixEInvoiceCashDiscountNotesSet(FInvoice) then
    Permit(LandrixEInvoiceRuleCashDiscountNote, FDoc.Path + '/cac:PaymentTerms/cbc:Note',
      'text of a cash discount level');
  Text := LandrixEInvoicePaymentTermsText(FInvoice);
  if Present(Text) then
    FDoc.PaymentTerms.Add.Note.Add(Txt(Text));
end;

{ BG-DEX-09 third-party payments (XRechnung extension, cac:PrepaidPayment;
  not in ubl:CreditNote). Left out, they break BR-CO-16, since the amount
  due (BT-115) still includes them: an error. Type (BT-DEX-001, BR-DEX-10)
  and description (BT-DEX-003, BR-DEX-12) are both required; a missing one
  takes the other (e.g. read from a Factur-X financial adjustment, which
  has one reason), reported as a warning; without both it is an error.
  DE: BG-DEX-09 Zahlungen Dritter (XRechnung-Extension,
  cac:PrepaidPayment; nicht in ubl:CreditNote). Weggelassen verletzen sie
  BR-CO-16, weil der Zahlbetrag (BT-115) sie weiterhin enthaelt: ein
  Fehler. Art (BT-DEX-001, BR-DEX-10) und Beschreibung (BT-DEX-003,
  BR-DEX-12) sind beide Pflicht; fehlt eines, wird das andere verwendet
  (z. B. gelesen aus einer Factur-X-Finanzkorrektur, die einen Grund hat)
  und als Warnung gemeldet; fehlen beide, ist es ein Fehler. }
procedure TUBLWriteMapper.MapThirdPartyPayments;
var
  I: TLandrixEInvoiceListIndex;
  Payment: TLandrixInvoicePrepaidPayment;
  Target: TLandrixUBLPayment;
begin
  if FInvoice.PrepaidPayments.Count = 0 then
    Exit;
  if FDoc.PrepaidPayment = nil then
    Report(edk_NotAllowed, FDoc.Path, 'third-party payments (BG-DEX-09) left out: ubl:CreditNote has no ' +
      'cac:PrepaidPayment', eds_Warning);
  if (FDoc.PrepaidPayment = nil) or not Permit(LandrixEInvoiceRuleThirdPartyPayments,
    FDoc.Path + '/cac:PrepaidPayment', 'third-party payments (BG-DEX-09)') then
  begin
    Report(edk_NotAllowed, FDoc.Path + '/cac:LegalMonetaryTotal/cbc:PayableAmount',
      'amount due (BT-115) includes the third-party payments (BG-DEX-09) left out; BR-CO-16 is violated',
      eds_Error);
    Exit;
  end;
  for I := 0 to FInvoice.PrepaidPayments.Count - 1 do
  begin
    Payment := FInvoice.PrepaidPayments[I];
    Target := FDoc.PrepaidPayment.Add;
    Target.ID.Value := Payment.ID;
    Target.PaidAmount := Money(Payment.PaidAmount);
    if Present(Payment.PaidAmountCurrencyID) then
      Target.PaidAmount.CurrencyID := Payment.PaidAmountCurrencyID;
    Target.InstructionID.Value := Payment.InstructionID;
    if Blank(Payment.ID) and Blank(Payment.InstructionID) then
      Report(edk_MissingElement, FDoc.Path + '/cac:PrepaidPayment', 'third-party payment without type ' +
        '(BT-DEX-001, BR-DEX-10) and description (BT-DEX-003, BR-DEX-12)', eds_Error)
    else if Blank(Payment.ID) then
    begin
      Target.ID.Value := Payment.InstructionID;
      Report(edk_MissingElement, FDoc.Path + '/cac:PrepaidPayment/cbc:ID', 'type of a third-party payment ' +
        '(BT-DEX-001, BR-DEX-10) missing; its description is written instead', eds_Warning);
    end
    else if Blank(Payment.InstructionID) then
    begin
      Target.InstructionID.Value := Payment.ID;
      Report(edk_MissingElement, FDoc.Path + '/cac:PrepaidPayment/cbc:InstructionID', 'description of a ' +
        'third-party payment (BT-DEX-003, BR-DEX-12) missing; its type is written instead', eds_Warning);
    end;
  end;
end;

{ BG-20/BG-21 document level allowances and charges with their VAT
  category (BT-95/BT-102, BT-96/BT-103; no rate for category O).
  DE: BG-20/BG-21 Nachlaesse und Zuschlaege auf Dokumentebene mit ihrer
  Steuerkategorie (BT-95/BT-102, BT-96/BT-103; kein Satz fuer Kategorie O). }
procedure TUBLWriteMapper.MapAllowanceCharges;
var
  I: TLandrixEInvoiceListIndex;
  Item: TLandrixInvoiceAllowanceCharge;
  Charge: TLandrixUBLAllowanceCharge;
  Category: TLandrixUBLTaxCategory;
  ReasonText, ReasonOther: TLandrixEInvoiceString;
begin
  for I := 0 to FInvoice.AllowanceCharges.Count - 1 do
  begin
    Item := FInvoice.AllowanceCharges[I];
    Charge := FDoc.AllowanceCharge.Add;
    Charge.ChargeIndicator := BoolText(Item.ChargeIndicator);
    ReasonText := AllowanceReasonCode(Item, ReasonOther);
    Charge.AllowanceChargeReasonCode.Value := Code(ReasonText, ReasonOther,
      FDoc.Path + '/cac:AllowanceCharge/cbc:AllowanceChargeReasonCode');
    if Present(Item.Reason) then
      Charge.AllowanceChargeReason.Add(Txt(Item.Reason));
    if Item.MultiplierFactorNumeric <> 0 then
      Charge.MultiplierFactorNumeric := LandrixEInvoiceDecimalToLexical(Item.MultiplierFactorNumeric, 4);
    Charge.Amount := Money(Item.Amount);
    if Item.BaseAmount <> 0 then
      Charge.BaseAmount := Money(Item.BaseAmount);
    Category := Charge.TaxCategory.Add;
    Category.ID.Value := Code(LandrixEInvoiceDutyTaxFeeCategoryCodeToStr(Item.TaxCategory), Item.TaxCategoryOther,
      FDoc.Path + '/cac:AllowanceCharge/cac:TaxCategory/cbc:ID');
    if Item.TaxCategory <> idtfcc_O_ServicesOutsideScopeOfTax then
      Category.Percent := LandrixEInvoicePercentToLexical(Item.TaxPercent);
    Category.TaxScheme.ID.Value := 'VAT';
  end;
end;

{ BT-110 VAT total in the invoice currency and BG-23 VAT breakdown: BT-116
  taxable amount, BT-117 tax amount, BT-118 category, BT-119 rate (also for
  category O, BR-DE-14), BT-121 exemption code, BT-120 exemption reason.
  With a differing VAT accounting currency (BT-6) a second tax total
  without breakdown carries BT-111; without BT-111 an error is reported
  (BR-53).
  DE: BT-110 Steuergesamtbetrag in der Rechnungswaehrung und BG-23
  Steueraufschluesselung: BT-116 Bemessungsgrundlage, BT-117 Steuerbetrag,
  BT-118 Kategorie, BT-119 Steuersatz (auch fuer Kategorie O, BR-DE-14),
  BT-121 Befreiungscode, BT-120 Befreiungsgrund. Bei abweichender
  Steuerwaehrung (BT-6) traegt ein zweiter Steuergesamtbetrag ohne
  Aufschluesselung BT-111; fehlt BT-111, wird ein Fehler gemeldet (BR-53). }
procedure TUBLWriteMapper.MapTax;
var
  I: TLandrixEInvoiceListIndex;
  Subtotal: TLandrixInvoiceTaxAmount;
  Total, AccountingTotal: TLandrixUBLTaxTotal;
  Target: TLandrixUBLTaxSubtotal;
begin
  Total := FDoc.TaxTotal.Add;
  Total.TaxAmount := Money(FInvoice.TaxAmountTotal);
  if Present(FInvoice.TaxCurrencyCode) and (FInvoice.TaxCurrencyCode <> FInvoice.InvoiceCurrencyCode) then
  begin
    if FInvoice.TaxAmountTotalInTaxCurrency.HasValue then
    begin
      AccountingTotal := FDoc.TaxTotal.Add;
      AccountingTotal.TaxAmount := Money(FInvoice.TaxAmountTotalInTaxCurrency.Value);
      AccountingTotal.TaxAmount.CurrencyID := FInvoice.TaxCurrencyCode;
    end
    else
      Report(edk_MissingElement, FDoc.Path + '/cac:TaxTotal', 'VAT total in the accounting currency ' +
        FInvoice.TaxCurrencyCode + ' (BT-111, BR-53) is missing', eds_Error);
  end
  else if FInvoice.TaxAmountTotalInTaxCurrency.HasValue then
    Report(edk_NotAllowed, FDoc.Path + '/cac:TaxTotal', 'VAT total in the accounting currency (BT-111) left ' +
      'out: the VAT accounting currency (BT-6) does not differ from the invoice currency', eds_Warning);
  for I := 0 to FInvoice.TaxAmountSubtotals.Count - 1 do
  begin
    Subtotal := FInvoice.TaxAmountSubtotals[I];
    Target := Total.TaxSubtotal.Add;
    Target.TaxableAmount := Money(Subtotal.TaxableAmount);
    Target.TaxAmount := Money(Subtotal.TaxAmount);
    Target.TaxCategory.ID.Value := Code(LandrixEInvoiceDutyTaxFeeCategoryCodeToStr(Subtotal.TaxCategory),
      Subtotal.TaxCategoryOther, FDoc.Path + '/cac:TaxTotal/cac:TaxSubtotal/cac:TaxCategory/cbc:ID');
    Target.TaxCategory.Percent := LandrixEInvoicePercentToLexical(Subtotal.TaxPercent);
    Target.TaxCategory.TaxExemptionReasonCode.Value := Subtotal.TaxExemptionReasonCode;
    if Present(Subtotal.TaxExemptionReason) then
      Target.TaxCategory.TaxExemptionReason.Add(Txt(Subtotal.TaxExemptionReason));
    Target.TaxCategory.TaxScheme.ID.Value := 'VAT';
  end;
end;

{ BG-22 document totals, taken from the model as they are: BT-106, BT-109,
  BT-112, BT-107, BT-108, BT-113, BT-114 (only if not 0), BT-115.
  DE: BG-22 Gesamtbetraege, unveraendert aus dem Modell: BT-106, BT-109,
  BT-112, BT-107, BT-108, BT-113, BT-114 (nur wenn nicht 0), BT-115. }
procedure TUBLWriteMapper.MapTotals;
var
  Total: TLandrixUBLMonetaryTotal;
begin
  Total := FDoc.LegalMonetaryTotal;
  Total.LineExtensionAmount := Money(FInvoice.LineAmount);
  Total.TaxExclusiveAmount := Money(FInvoice.TaxExclusiveAmount);
  Total.TaxInclusiveAmount := Money(FInvoice.TaxInclusiveAmount);
  Total.AllowanceTotalAmount := Money(FInvoice.AllowanceTotalAmount);
  Total.ChargeTotalAmount := Money(FInvoice.ChargeTotalAmount);
  Total.PrepaidAmount := Money(FInvoice.PrepaidAmount);
  if FInvoice.PayableRoundingAmount <> 0 then
    Total.PayableRoundingAmount := Money(FInvoice.PayableRoundingAmount);
  Total.PayableAmount := Money(FInvoice.PayableAmount);
end;

{ BG-25 invoice line: BT-126 identifier, BT-127 note, BT-129/BT-130
  quantity, BT-131 net amount, BT-133 buyer accounting reference, BG-26
  period, BT-132 order line reference, BT-128 object identifier (type 130),
  BG-27/BG-28 allowances and charges (factor with 2 decimals as in
  XRechnung-for-Delphi), BG-31 item, BG-29 price. Sub lines (BG-DEX-01)
  only in ubl:Invoice and where the rule table allows them; the line status
  of CII EXTENDED (BT-X-8) has no element in UBL.
  DE: BG-25 Rechnungsposition: BT-126 Kennung, BT-127 Bemerkung,
  BT-129/BT-130 Menge, BT-131 Nettobetrag, BT-133 Buchungsreferenz des
  Kaeufers, BG-26 Zeitraum, BT-132 Bestellpositionsreferenz, BT-128
  Objektkennung (Art 130), BG-27/BG-28 Nachlaesse und Zuschlaege (Faktor
  mit 2 Nachkommastellen wie in XRechnung-for-Delphi), BG-31 Artikel,
  BG-29 Preis. Unterpositionen (BG-DEX-01) nur in ubl:Invoice und wo die
  Regel-Tabelle sie erlaubt; der Positionsstatus aus CII EXTENDED (BT-X-8)
  hat in UBL kein Element. }
procedure TUBLWriteMapper.MapLine(ALine: TLandrixInvoiceLine; const ATarget: TUBLLine;
  const APath: TLandrixEInvoiceString);
var
  I: TLandrixEInvoiceListIndex;
  Period: TLandrixUBLPeriod;
  Document: TLandrixUBLDocumentReference;
  Item: TLandrixInvoiceAllowanceCharge;
  Charge: TLandrixUBLAllowanceCharge;
  ReasonText, ReasonOther: TLandrixEInvoiceString;
begin
  ATarget.ID^.Value := ALine.ID;
  if Present(ALine.Note) then
    ATarget.Note.Add(Txt(ALine.Note));
  ATarget.Quantity^.Value := LandrixEInvoiceQuantityToLexical(ALine.Quantity);
  ATarget.Quantity^.UnitCode := Code(LandrixEInvoiceUnitCodeToStr(ALine.UnitCode), ALine.UnitCodeOther,
    APath + '/' + ATarget.QuantityName + '/@unitCode');
  ATarget.LineExtensionAmount^ := Money(ALine.LineAmount);
  ATarget.AccountingCost^ := ALine.BuyerAccountingReference;
  if PeriodReversed(ALine.InvoiceLinePeriodStartDate, ALine.InvoiceLinePeriodEndDate) then
    Report(edk_NotAllowed, APath + '/cac:InvoicePeriod', 'period (BG-26) of line ' + ALine.ID +
      ' left out: the end date is before the start date (BR-30)', eds_Warning);
  if PeriodSet(ALine.InvoiceLinePeriodStartDate, ALine.InvoiceLinePeriodEndDate) then
  begin
    Period := ATarget.InvoicePeriod.Add;
    if PeriodDateSet(ALine.InvoiceLinePeriodStartDate) then
      Period.StartDate := LandrixEInvoiceDateToUBL(ALine.InvoiceLinePeriodStartDate);
    if PeriodDateSet(ALine.InvoiceLinePeriodEndDate) then
      Period.EndDate := LandrixEInvoiceDateToUBL(ALine.InvoiceLinePeriodEndDate);
  end;
  if Present(ALine.OrderLineReference) then
    ATarget.OrderLineReference.Add.LineID.Value := ALine.OrderLineReference;
  if Present(ALine.OrderNumber) then
    Permit(LandrixEInvoiceRuleLineOrderNumber, APath + '/cac:OrderLineReference', 'order number of line ' + ALine.ID);
  if ALine.OrderDate.HasValue then
    Permit(LandrixEInvoiceRuleLineOrderDate, APath + '/cac:OrderLineReference', 'order date of line ' + ALine.ID);
  if Present(ALine.ObjectIdentifier) then
  begin
    Document := ATarget.DocumentReference.Add;
    Document.ID := UBLID(ALine.ObjectIdentifier, ALine.ObjectIdentifierSchemeID);
    Document.DocumentTypeCode.Value := '130';
  end;
  for I := 0 to ALine.AllowanceCharges.Count - 1 do
  begin
    Item := ALine.AllowanceCharges[I];
    Charge := ATarget.AllowanceCharge.Add;
    Charge.ChargeIndicator := BoolText(Item.ChargeIndicator);
    ReasonText := AllowanceReasonCode(Item, ReasonOther);
    Charge.AllowanceChargeReasonCode.Value := Code(ReasonText, ReasonOther,
      APath + '/cac:AllowanceCharge/cbc:AllowanceChargeReasonCode');
    if Present(Item.Reason) then
      Charge.AllowanceChargeReason.Add(Txt(Item.Reason));
    if Item.MultiplierFactorNumeric <> 0 then
      Charge.MultiplierFactorNumeric := LandrixEInvoiceDecimalToLexical(Item.MultiplierFactorNumeric, 2);
    { BT-137 also without BT-138, as on document level
      DE: BT-137 auch ohne BT-138, wie auf Dokumentebene }
    if (Item.MultiplierFactorNumeric <> 0) or (Item.BaseAmount <> 0) then
      Charge.BaseAmount := Money(Item.BaseAmount);
    Charge.Amount := Money(Item.Amount);
  end;
  MapLineItem(ALine, ATarget.Item, APath + '/cac:Item');
  MapLinePrice(ALine, ATarget.Price, APath + '/cac:Price');
  if DateSet(ALine.ActualDeliveryDate) or Present(ALine.DeliveryNoteNumber) then
    Permit(LandrixEInvoiceRuleLineDelivery, APath, 'delivery data of line ' + ALine.ID);
  if (ALine.LineStatusReasonCode <> ilsrc_None) or Present(ALine.LineStatusReasonCodeOther) then
    Report(edk_NotAllowed, APath, 'line status (BT-X-8) of line ' + ALine.ID +
      ' left out: UBL has no element for it', eds_Warning);
  if ALine.SubInvoiceLines.Count = 0 then
    Exit;
  if ATarget.InvoiceLine = nil then
  begin
    Report(edk_NotAllowed, APath, 'sub lines of line ' + ALine.ID + ' left out: the XRechnung extension ' +
      'has no credit note', eds_Warning);
    Exit;
  end;
  if not Permit(LandrixEInvoiceRuleLineSubLines, APath + '/' + ATarget.SubLineName, 'sub lines of line ' + ALine.ID) then
    Exit;
  for I := 0 to ALine.SubInvoiceLines.Count - 1 do
    MapLine(ALine.SubInvoiceLines[I], AddSubLine(ATarget), APath + '/' + ATarget.SubLineName);
end;

{ BG-31 item: BT-154 description, BT-153 name, BT-156/BT-155 identifiers,
  BT-157 standard identifier (see LandrixEInvoiceStandardItemIdentifierOf),
  BT-159 country of origin, BT-158 classifications (BR-65: only with a
  scheme), BG-30 line VAT (no rate for category O), BG-32 attributes.
  DE: BG-31 Artikel: BT-154 Beschreibung, BT-153 Name, BT-156/BT-155
  Kennungen, BT-157 Standardkennung (siehe
  LandrixEInvoiceStandardItemIdentifierOf), BT-159 Herkunftsland, BT-158
  Klassifizierungen (BR-65: nur mit Schema), BG-30 Umsatzsteuer der
  Position (kein Satz fuer Kategorie O), BG-32 Eigenschaften. }
procedure TUBLWriteMapper.MapLineItem(ALine: TLandrixInvoiceLine; AItem: TLandrixUBLItem;
  const APath: TLandrixEInvoiceString);
var
  I: TLandrixEInvoiceListIndex;
  Classification: TLandrixInvoiceLineItemClassification;
  Target: TLandrixUBLCommodityClassification;
  Category: TLandrixUBLTaxCategory;
  Attribute: TLandrixUBLItemProperty;
  Value, Scheme, Conflict: TLandrixEInvoiceString;
begin
  if Present(ALine.Description) then
    AItem.Description.Add(Txt(ALine.Description));
  AItem.Name := Txt(ALine.Name);
  AItem.BuyersItemIdentification.ID.Value := ALine.BuyersItemIdentification;
  AItem.SellersItemIdentification.ID.Value := ALine.SellersItemIdentification;
  if LandrixEInvoiceStandardItemIdentifierOf(ALine, Value, Scheme, Conflict) then
  begin
    AItem.StandardItemIdentification.ID := UBLID(Value, Scheme);
    if Blank(Scheme) then
      Report(edk_MissingElement, APath + '/cac:StandardItemIdentification/cbc:ID/@schemeID',
        'item standard identifier ' + Value + ' of line ' + ALine.ID + ' without scheme (BR-64)', eds_Error);
    if Present(Conflict) then
      Report(edk_NotAllowed, APath + '/cac:StandardItemIdentification', Conflict, eds_Warning);
  end;
  AItem.OriginCountry.IdentificationCode.Value := ALine.OriginTradeCountry;
  for I := 0 to ALine.ItemClassifications.Count - 1 do
  begin
    Classification := ALine.ItemClassifications[I];
    if Blank(Classification.ClassCode) then
      Continue;
    if Blank(Classification.ListID) then
    begin
      Report(edk_NotAllowed, APath + '/cac:CommodityClassification',
        'item classification ' + Classification.ClassCode + ' without scheme (BR-65); left out', eds_Warning);
      Continue;
    end;
    Target := AItem.CommodityClassification.Add;
    Target.ItemClassificationCode.Value := Classification.ClassCode;
    Target.ItemClassificationCode.ListID := Classification.ListID;
    Target.ItemClassificationCode.ListVersionID := Classification.ListVersionID;
    if Present(Classification.ClassificationName) then
      Permit(LandrixEInvoiceRuleLineClassificationName, APath + '/cac:CommodityClassification',
        'classification name of line ' + ALine.ID);
  end;
  Category := AItem.ClassifiedTaxCategory.Add;
  Category.ID.Value := Code(LandrixEInvoiceDutyTaxFeeCategoryCodeToStr(ALine.TaxCategory), ALine.TaxCategoryOther,
    APath + '/cac:ClassifiedTaxCategory/cbc:ID');
  if ALine.TaxCategory <> idtfcc_O_ServicesOutsideScopeOfTax then
    Category.Percent := LandrixEInvoicePercentToLexical(ALine.TaxPercent);
  Category.TaxScheme.ID.Value := 'VAT';
  if Present(ALine.TaxExemptionReason) and
     Permit(LandrixEInvoiceRuleLineTaxExemptionReason, APath + '/cac:ClassifiedTaxCategory/cbc:TaxExemptionReason',
       'VAT exemption reason of line ' + ALine.ID) then
    Category.TaxExemptionReason.Add(Txt(ALine.TaxExemptionReason));
  for I := 0 to ALine.ItemAttributes.Count - 1 do
  begin
    Attribute := AItem.AdditionalItemProperty.Add;
    Attribute.Name := Txt(ALine.ItemAttributes[I].Name);
    Attribute.Value := Txt(ALine.ItemAttributes[I].Value);
  end;
end;

{ BG-29 price: BT-146 net price, BT-149/BT-150 base quantity (BT-150 is
  optional), BT-148 gross price with BT-147 discount (the discount is
  written also when it is 0).
  DE: BG-29 Preis: BT-146 Nettopreis, BT-149/BT-150 Basismenge (BT-150 ist
  optional), BT-148 Bruttopreis mit BT-147 Rabatt (der Rabatt wird auch
  geschrieben, wenn er 0 ist). }
procedure TUBLWriteMapper.MapLinePrice(ALine: TLandrixInvoiceLine; APrice: TLandrixUBLPrice;
  const APath: TLandrixEInvoiceString);
var
  Discount: TLandrixUBLAllowanceCharge;
begin
  APrice.PriceAmount := PriceMoney(ALine.NetPriceAmount);
  if ALine.BaseQuantity <> 0 then
  begin
    APrice.BaseQuantity.Value := LandrixEInvoiceBaseQuantityToLexical(ALine.BaseQuantity);
    APrice.BaseQuantity.UnitCode := Code(LandrixEInvoiceUnitCodeToStr(ALine.BaseQuantityUnitCode),
      ALine.BaseQuantityUnitCodeOther, APath + '/cbc:BaseQuantity/@unitCode');
  end;
  if ALine.GrossPriceAmount <> 0 then
  begin
    Discount := APrice.AllowanceCharge.Add;
    Discount.ChargeIndicator := 'false';
    Discount.Amount := PriceMoney(ALine.DiscountOnTheGrossPrice);
    Discount.BaseAmount := PriceMoney(ALine.GrossPriceAmount);
  end;
end;

{ --- reading ---------------------------------------------------------------- }

type
  { Reads one UBL document into one invoice. Each method takes over what the
    invoice model can hold and reports the rest (edk_NotMapped) with the
    help of ListFilledChildren.
    DE: Liest ein UBL-Dokument in eine Rechnung. Jede Methode uebernimmt,
    was das Rechnungsmodell aufnehmen kann, und meldet den Rest
    (edk_NotMapped) mit Hilfe von ListFilledChildren. }
  TUBLReadMapper = class(TObject)
  private
    FDoc: TUBLDocument;
    FInvoice: TLandrixInvoice;
    FDiagnostics: TLandrixEInvoiceDiagnostics;
    FFilled: TLandrixEInvoiceStringList;
    procedure Report(AKind: TLandrixEInvoiceDiagnosticKind; const APath, AMessage: TLandrixEInvoiceString;
      ASeverity: TLandrixEInvoiceDiagnosticSeverity);
    procedure NotMapped(const APath, AWhat: TLandrixEInvoiceString);
    procedure Rest(const APath: TLandrixEInvoiceString; const ATaken: array of string);
    procedure Excess(ACount: TLandrixEInvoiceListIndex; const APath: TLandrixEInvoiceString);
    function Amount(const AValue: TLandrixUBLAmount; const APath: TLandrixEInvoiceString): Currency;
    function Price(const AValue: TLandrixUBLAmount; const APath: TLandrixEInvoiceString): Double;
    function Decimal(const AText, APath: TLandrixEInvoiceString): Double;
    function Date(const AText, APath: TLandrixEInvoiceString): TDateTime;
    function IDValue(const AValue: TLandrixUBLID; const APath: TLandrixEInvoiceString): TLandrixEInvoiceString;
    function CodeValue(const AValue: TLandrixUBLCode; const APath: TLandrixEInvoiceString): TLandrixEInvoiceString;
    function Quantity(const AValue: TLandrixUBLQuantity; const APath: TLandrixEInvoiceString;
      out AUnit: TLandrixInvoiceUnitCode; out AOther: TLandrixEInvoiceString): Double;
    function FirstText(AList: TLandrixEInvoiceStringList; const APath: TLandrixEInvoiceString): TLandrixEInvoiceString;
    function DocumentID(AList: TLandrixUBLDocumentReferenceList; const APath: TLandrixEInvoiceString): TLandrixEInvoiceString;
    procedure UnknownCode(const AText, APath: TLandrixEInvoiceString; out AOther: TLandrixEInvoiceString);
    procedure ReadTaxCategory(const AText, APath: TLandrixEInvoiceString;
      out AValue: TLandrixInvoiceDutyTaxFeeCategoryCode; out AOther: TLandrixEInvoiceString);
    procedure ReadTaxScheme(ATaxScheme: TLandrixUBLTaxScheme; const APath: TLandrixEInvoiceString);
    procedure ReadReason(AItem: TLandrixInvoiceAllowanceCharge; const AValue: TLandrixUBLCode;
      const APath: TLandrixEInvoiceString);
    procedure ReadDocument;
    procedure ReadReferences;
    procedure ReadAttachments;
    procedure ReadAddress(AAddress: TLandrixInvoiceAddress; ASource: TLandrixUBLAddress;
      const APath: TLandrixEInvoiceString);
    procedure ReadParty(AParty: TLandrixInvoiceAccountingParty; ASource: TLandrixUBLParty;
      const APath: TLandrixEInvoiceString; AIsSeller: Boolean);
    procedure ReadFurtherParty(AParty: TLandrixInvoiceParty; ASource: TLandrixUBLParty;
      const APath: TLandrixEInvoiceString);
    procedure ReadDelivery;
    procedure ReadPaymentMeans;
    procedure ReadPaymentTerms;
    procedure ReadThirdPartyPayments;
    procedure ReadAllowanceCharge(AItem: TLandrixInvoiceAllowanceCharge; ACharge: TLandrixUBLAllowanceCharge;
      const APath: TLandrixEInvoiceString; AWithTax: Boolean);
    procedure ReadTax;
    procedure ReadTotals;
    procedure ReadLine(ALine: TLandrixInvoiceLine; const ASource: TUBLLine; const APath: TLandrixEInvoiceString);
    procedure ReadLineItem(ALine: TLandrixInvoiceLine; AItem: TLandrixUBLItem; const APath: TLandrixEInvoiceString);
    procedure ReadLinePrice(ALine: TLandrixInvoiceLine; APrice: TLandrixUBLPrice; const APath: TLandrixEInvoiceString);
  public
    constructor Create(const ADocument: TUBLDocument; AInvoice: TLandrixInvoice;
      ADiagnostics: TLandrixEInvoiceDiagnostics);
    destructor Destroy; override;
    procedure Execute;
  end;

constructor TUBLReadMapper.Create(const ADocument: TUBLDocument; AInvoice: TLandrixInvoice;
  ADiagnostics: TLandrixEInvoiceDiagnostics);
begin
  inherited Create;
  FDoc := ADocument;
  FInvoice := AInvoice;
  FDiagnostics := ADiagnostics;
  FFilled := TLandrixEInvoiceStringList.Create;
end;

destructor TUBLReadMapper.Destroy;
begin
  FFilled.Free;
  inherited;
end;

procedure TUBLReadMapper.Report(AKind: TLandrixEInvoiceDiagnosticKind;
  const APath, AMessage: TLandrixEInvoiceString; ASeverity: TLandrixEInvoiceDiagnosticSeverity);
begin
  if FDiagnostics <> nil then
    FDiagnostics.AddDiagnostic(AKind, APath, 0, 0, 0, AMessage).Severity := ASeverity;
end;

procedure TUBLReadMapper.NotMapped(const APath, AWhat: TLandrixEInvoiceString);
begin
  Report(edk_NotMapped, APath, AWhat + ' has no place in the invoice model; kept in the UBL model only',
    eds_Warning);
end;

{ Reports every child in FFilled (filled by ListFilledChildren) that is not
  in ATaken. DE: Meldet jedes Kind in FFilled (gefuellt von
  ListFilledChildren), das nicht in ATaken steht. }
procedure TUBLReadMapper.Rest(const APath: TLandrixEInvoiceString; const ATaken: array of string);
var
  I: TLandrixEInvoiceListIndex;
  J: Integer;
  Taken: Boolean;
begin
  for I := 0 to FFilled.Count - 1 do
  begin
    Taken := False;
    for J := 0 to Integer(High(ATaken)) do
      if FFilled[I] = TLandrixEInvoiceString(ATaken[J]) then
        Taken := True;
    if not Taken then
      NotMapped(APath + '/' + FFilled[I], FFilled[I]);
  end;
  FFilled.Clear;
end;

procedure TUBLReadMapper.Excess(ACount: TLandrixEInvoiceListIndex; const APath: TLandrixEInvoiceString);
begin
  if ACount > 1 then
    NotMapped(APath, TLandrixEInvoiceString(IntToStr(ACount - 1)) + ' further occurrence(s)');
end;

function TUBLReadMapper.Amount(const AValue: TLandrixUBLAmount; const APath: TLandrixEInvoiceString): Currency;
var
  Rounded: Boolean;
begin
  Result := 0;
  if (AValue.CurrencyID <> '') and (AValue.CurrencyID <> FInvoice.InvoiceCurrencyCode) then
    NotMapped(APath + '/@currencyID', 'currency ' + AValue.CurrencyID);
  if AValue.Value = '' then
    Exit;
  if not LandrixEInvoiceTryLexicalToCurrency(AValue.Value, Result, Rounded) then
    Report(edk_ConversionFailed, APath, 'amount "' + AValue.Value + '" not converted; 0 used', eds_Error)
  else if Rounded then
    Report(edk_ConversionFailed, APath, 'amount "' + AValue.Value + '" rounded to 4 decimals', eds_Warning);
end;

{ BT-146 to BT-148 without rounding: prices may have any number of decimals
  DE: BT-146 bis BT-148 ohne Rundung: Preise duerfen beliebig viele
  Nachkommastellen haben }
function TUBLReadMapper.Price(const AValue: TLandrixUBLAmount; const APath: TLandrixEInvoiceString): Double;
begin
  if (AValue.CurrencyID <> '') and (AValue.CurrencyID <> FInvoice.InvoiceCurrencyCode) then
    NotMapped(APath + '/@currencyID', 'currency ' + AValue.CurrencyID);
  Result := Decimal(AValue.Value, APath);
end;

function TUBLReadMapper.Decimal(const AText, APath: TLandrixEInvoiceString): Double;
begin
  Result := 0;
  if AText = '' then
    Exit;
  if not LandrixEInvoiceTryLexicalToDouble(AText, Result) then
    Report(edk_ConversionFailed, APath, 'number "' + AText + '" not converted; 0 used', eds_Error);
end;

function TUBLReadMapper.Date(const AText, APath: TLandrixEInvoiceString): TDateTime;
begin
  Result := 0;
  if AText = '' then
    Exit;
  if not LandrixEInvoiceTryUBLToDate(AText, Result) then
    Report(edk_ConversionFailed, APath, 'date "' + AText + '" not converted; not set', eds_Error);
end;

{ Identifier whose scheme the invoice model does not keep.
  DE: Kennung, deren Schema das Rechnungsmodell nicht behaelt. }
function TUBLReadMapper.IDValue(const AValue: TLandrixUBLID; const APath: TLandrixEInvoiceString): TLandrixEInvoiceString;
begin
  Result := AValue.Value;
  if AValue.SchemeID <> '' then
    NotMapped(APath + '/@schemeID', 'scheme ' + AValue.SchemeID);
end;

function TUBLReadMapper.CodeValue(const AValue: TLandrixUBLCode; const APath: TLandrixEInvoiceString): TLandrixEInvoiceString;
begin
  Result := AValue.Value;
  if AValue.ListID <> '' then
    NotMapped(APath + '/@listID', 'list ' + AValue.ListID);
  if AValue.ListVersionID <> '' then
    NotMapped(APath + '/@listVersionID', 'list version ' + AValue.ListVersionID);
  if AValue.Name <> '' then
    NotMapped(APath + '/@name', 'code name ' + AValue.Name);
end;

function TUBLReadMapper.Quantity(const AValue: TLandrixUBLQuantity; const APath: TLandrixEInvoiceString;
  out AUnit: TLandrixInvoiceUnitCode; out AOther: TLandrixEInvoiceString): Double;
begin
  Result := Decimal(AValue.Value, APath);
  AOther := '';
  AUnit := iuc_None;
  if (AValue.UnitCode <> '') and not LandrixEInvoiceUnitCodeFromStr(AValue.UnitCode, AUnit) then
  begin
    AUnit := iuc_None;
    UnknownCode(AValue.UnitCode, APath + '/@unitCode', AOther);
  end;
  if AValue.UnitCodeListID <> '' then
    NotMapped(APath + '/@unitCodeListID', 'unit list ' + AValue.UnitCodeListID);
  if AValue.UnitCodeListAgencyID <> '' then
    NotMapped(APath + '/@unitCodeListAgencyID', 'unit list agency ' + AValue.UnitCodeListAgencyID);
  if AValue.UnitCodeListAgencyName <> '' then
    NotMapped(APath + '/@unitCodeListAgencyName', 'unit list agency ' + AValue.UnitCodeListAgencyName);
end;

function TUBLReadMapper.FirstText(AList: TLandrixEInvoiceStringList;
  const APath: TLandrixEInvoiceString): TLandrixEInvoiceString;
begin
  Result := '';
  if AList.Count > 0 then
    Result := AList[0];
  Excess(AList.Count, APath);
end;

{ The identifier of the first reference of a list (BT-12, BT-15, BT-16);
  further references and their other content are reported.
  DE: Die Kennung der ersten Referenz einer Liste (BT-12, BT-15, BT-16);
  weitere Referenzen und deren uebriger Inhalt werden gemeldet. }
function TUBLReadMapper.DocumentID(AList: TLandrixUBLDocumentReferenceList;
  const APath: TLandrixEInvoiceString): TLandrixEInvoiceString;
begin
  Result := '';
  if AList.Count = 0 then
    Exit;
  Result := IDValue(AList[0].ID, APath + '/cbc:ID');
  AList[0].ListFilledChildren(FFilled);
  Rest(APath, ['cbc:ID']);
  Excess(AList.Count, APath);
end;

procedure TUBLReadMapper.UnknownCode(const AText, APath: TLandrixEInvoiceString; out AOther: TLandrixEInvoiceString);
begin
  AOther := AText;
  if AText <> '' then
    Report(edk_UnknownCode, APath, 'code ' + AText + ' is not in the code list; kept in ...Other', eds_Info);
end;

procedure TUBLReadMapper.ReadTaxCategory(const AText, APath: TLandrixEInvoiceString;
  out AValue: TLandrixInvoiceDutyTaxFeeCategoryCode; out AOther: TLandrixEInvoiceString);
begin
  AOther := '';
  if not LandrixEInvoiceDutyTaxFeeCategoryCodeFromStr(AText, AValue) then
  begin
    AValue := idtfcc_None;
    UnknownCode(AText, APath, AOther);
  end;
end;

{ The invoice model knows VAT only. DE: Das Rechnungsmodell kennt nur die
  Umsatzsteuer. }
procedure TUBLReadMapper.ReadTaxScheme(ATaxScheme: TLandrixUBLTaxScheme; const APath: TLandrixEInvoiceString);
begin
  if (ATaxScheme.ID.Value <> '') and (ATaxScheme.ID.Value <> 'VAT') then
    NotMapped(APath + '/cbc:ID', 'tax scheme ' + ATaxScheme.ID.Value);
  if ATaxScheme.ID.SchemeID <> '' then
    NotMapped(APath + '/cbc:ID/@schemeID', 'scheme ' + ATaxScheme.ID.SchemeID);
  ATaxScheme.ListFilledChildren(FFilled);
  Rest(APath, ['cbc:ID']);
end;

{ BT-98/BT-105 (document) and BT-140/BT-145 (line) reason codes: UNTDID 5189
  for allowances, UNTDID 7161 for charges.
  DE: BT-98/BT-105 (Dokument) und BT-140/BT-145 (Position) Grundcodes:
  UNTDID 5189 fuer Nachlaesse, UNTDID 7161 fuer Zuschlaege. }
procedure TUBLReadMapper.ReadReason(AItem: TLandrixInvoiceAllowanceCharge; const AValue: TLandrixUBLCode;
  const APath: TLandrixEInvoiceString);
var
  Text: TLandrixEInvoiceString;
begin
  Text := CodeValue(AValue, APath);
  if Text = '' then
    Exit;
  if AItem.ChargeIndicator then
  begin
    if not LandrixEInvoiceSpecialServiceDescriptionCodeFromStr(Text, AItem.ReasonCodeCharge) then
    begin
      AItem.ReasonCodeCharge := issdc_None;
      UnknownCode(Text, APath, AItem.ReasonCodeChargeOther);
    end;
  end
  else if not LandrixEInvoiceAllowanceOrChargeIdentCodeFromStr(Text, AItem.ReasonCodeAllowance) then
  begin
    AItem.ReasonCodeAllowance := iacic_None;
    UnknownCode(Text, APath, AItem.ReasonCodeAllowanceOther);
  end;
end;

procedure TUBLReadMapper.Execute;
var
  I: TLandrixEInvoiceListIndex;
begin
  FInvoice.Clear;
  FInvoice.ProfileID := '';
  ReadDocument;  { currencies first: amounts compare their currency }
  ReadReferences;
  ReadAttachments;
  ReadParty(FInvoice.AccountingSupplierParty, FDoc.AccountingSupplierParty.Party,
    FDoc.Path + '/cac:AccountingSupplierParty/cac:Party', True);
  FDoc.AccountingSupplierParty.ListFilledChildren(FFilled);
  Rest(FDoc.Path + '/cac:AccountingSupplierParty', ['cac:Party']);
  ReadParty(FInvoice.AccountingCustomerParty, FDoc.AccountingCustomerParty.Party,
    FDoc.Path + '/cac:AccountingCustomerParty/cac:Party', False);
  FDoc.AccountingCustomerParty.ListFilledChildren(FFilled);
  Rest(FDoc.Path + '/cac:AccountingCustomerParty', ['cac:Party']);
  ReadFurtherParty(FInvoice.PayeeParty, FDoc.PayeeParty, FDoc.Path + '/cac:PayeeParty');
  ReadFurtherParty(FInvoice.TaxRepresentativeParty, FDoc.TaxRepresentativeParty,
    FDoc.Path + '/cac:TaxRepresentativeParty');
  ReadDelivery;
  ReadPaymentMeans;
  ReadPaymentTerms;
  ReadThirdPartyPayments;
  for I := 0 to FDoc.AllowanceCharge.Count - 1 do
    ReadAllowanceCharge(FInvoice.AllowanceCharges.AddAllowanceCharge, FDoc.AllowanceCharge[I],
      FDoc.Path + '/cac:AllowanceCharge', True);
  ReadTax;
  ReadTotals;
  for I := 0 to LineCount(FDoc) - 1 do
    ReadLine(FInvoice.InvoiceLines.AddInvoiceLine, LineAt(FDoc, I), FDoc.Path + '/' + FDoc.LineName);
  ListDocumentChildren(FDoc, FFilled);
  Rest(FDoc.Path, ['cbc:CustomizationID', 'cbc:ProfileID', 'cbc:ID', 'cbc:IssueDate', 'cbc:DueDate',
    'cbc:InvoiceTypeCode', 'cbc:CreditNoteTypeCode', 'cbc:TaxPointDate', 'cbc:Note', 'cbc:DocumentCurrencyCode',
    'cbc:TaxCurrencyCode', 'cbc:AccountingCost', 'cbc:BuyerReference', 'cac:InvoicePeriod', 'cac:OrderReference',
    'cac:BillingReference', 'cac:DespatchDocumentReference', 'cac:ReceiptDocumentReference',
    'cac:OriginatorDocumentReference', 'cac:ContractDocumentReference', 'cac:AdditionalDocumentReference',
    'cac:ProjectReference', 'cac:AccountingSupplierParty', 'cac:AccountingCustomerParty', 'cac:PayeeParty',
    'cac:TaxRepresentativeParty', 'cac:Delivery', 'cac:PaymentMeans',
    'cac:PaymentTerms', 'cac:PrepaidPayment', 'cac:AllowanceCharge', 'cac:TaxTotal', 'cac:LegalMonetaryTotal',
    'cac:InvoiceLine', 'cac:CreditNoteLine']);
end;

{ BT-23 business process (BT-24 identifies the specification: detected by
  the caller, not kept in the invoice model), BT-1, BT-2, BT-9, BT-3, BG-1
  notes with a '#code#' subject prefix, BT-5, BT-6, BT-19, BT-10, BG-14.
  DE: BT-23 Geschaeftsprozess (BT-24 bestimmt die Spezifikation: vom
  Aufrufer erkannt, nicht im Rechnungsmodell gehalten), BT-1, BT-2, BT-9,
  BT-3, BG-1 Bemerkungen mit Betreffpraefix '#Code#', BT-5, BT-6, BT-19,
  BT-10, BG-14. }
procedure TUBLReadMapper.ReadDocument;
var
  I: TLandrixEInvoiceListIndex;
  Text, Subject: TLandrixEInvoiceString;
  Note: TLandrixInvoiceNote;
  Period: TLandrixUBLPeriod;
begin
  FInvoice.ProfileID := IDValue(FDoc.ProfileID^, FDoc.Path + '/cbc:ProfileID');
  FInvoice.InvoiceNumber := IDValue(FDoc.ID^, FDoc.Path + '/cbc:ID');
  FInvoice.InvoiceIssueDate := Date(FDoc.IssueDate^, FDoc.Path + '/cbc:IssueDate');
  if FDoc.DueDate <> nil then
    FInvoice.InvoiceDueDate := Date(FDoc.DueDate^, FDoc.Path + '/cbc:DueDate');
  Text := CodeValue(FDoc.TypeCode^, FDoc.Path + '/' + FDoc.TypeCodeName);
  if (Text <> '') and not LandrixEInvoiceTypeCodeFromStr(Text, FInvoice.InvoiceTypeCode) then
  begin
    FInvoice.InvoiceTypeCode := itc_None;
    UnknownCode(Text, FDoc.Path + '/' + FDoc.TypeCodeName, FInvoice.InvoiceTypeCodeOther);
  end;
  for I := 0 to FDoc.Note.Count - 1 do
  begin
    Note := FInvoice.Notes.AddNote;
    Text := FDoc.Note[I];
    if (Length(Text) >= 5) and (Text[1] = '#') and (Text[5] = '#') then
    begin
      Subject := Copy(Text, 2, 3);
      if not LandrixEInvoiceNoteSubjectCodeFromStr(Subject, Note.SubjectCode) then
      begin
        Note.SubjectCode := insc_None;
        UnknownCode(Subject, FDoc.Path + '/cbc:Note', Note.SubjectCodeOther);
      end;
      Text := Copy(Text, 6, Length(Text) - 5);
    end;
    Note.Content := Text;
  end;
  FInvoice.InvoiceCurrencyCode := CodeValue(FDoc.DocumentCurrencyCode^, FDoc.Path + '/cbc:DocumentCurrencyCode');
  FInvoice.TaxCurrencyCode := CodeValue(FDoc.TaxCurrencyCode^, FDoc.Path + '/cbc:TaxCurrencyCode');
  FInvoice.BuyerAccountingReference := FDoc.AccountingCost^;
  FInvoice.BuyerReference := FDoc.BuyerReference^;
  SetDate(FInvoice.TaxPointDate, Date(FDoc.TaxPointDate^, FDoc.Path + '/cbc:TaxPointDate'));
  if FDoc.InvoicePeriod.Count > 0 then
  begin
    Period := FDoc.InvoicePeriod[0];
    FInvoice.InvoicePeriodStartDate := Date(Period.StartDate, FDoc.Path + '/cac:InvoicePeriod/cbc:StartDate');
    FInvoice.InvoicePeriodEndDate := Date(Period.EndDate, FDoc.Path + '/cac:InvoicePeriod/cbc:EndDate');
    if Period.DescriptionCode.Count > 0 then
      FInvoice.TaxPointDateCode := CodeValue(Period.DescriptionCode[0], FDoc.Path + '/cac:InvoicePeriod/cbc:DescriptionCode');
    Excess(Period.DescriptionCode.Count, FDoc.Path + '/cac:InvoicePeriod/cbc:DescriptionCode');
    Period.ListFilledChildren(FFilled);
    Rest(FDoc.Path + '/cac:InvoicePeriod', ['cbc:StartDate', 'cbc:EndDate', 'cbc:DescriptionCode']);
  end;
  Excess(FDoc.InvoicePeriod.Count, FDoc.Path + '/cac:InvoicePeriod');
end;

{ BT-13 ('NA' together with BT-14 means "no purchase order"), BT-14, BG-3,
  BT-16, BT-15, BT-12, BT-11.
  DE: BT-13 ('NA' zusammen mit BT-14 heisst "keine Bestellung"), BT-14,
  BG-3, BT-16, BT-15, BT-12, BT-11. }
procedure TUBLReadMapper.ReadReferences;
var
  I: TLandrixEInvoiceListIndex;
  Reference: TLandrixInvoicePrecedingInvoiceReference;
  Source: TLandrixUBLDocumentReference;
  Path: TLandrixEInvoiceString;
begin
  Path := FDoc.Path + '/cac:OrderReference';
  FInvoice.PurchaseOrderReference := IDValue(FDoc.OrderReference.ID, Path + '/cbc:ID');
  FInvoice.SellerOrderReference := IDValue(FDoc.OrderReference.SalesOrderID, Path + '/cbc:SalesOrderID');
  if (FInvoice.PurchaseOrderReference = 'NA') and (FInvoice.SellerOrderReference <> '') then
    FInvoice.PurchaseOrderReference := '';
  FDoc.OrderReference.ListFilledChildren(FFilled);
  Rest(Path, ['cbc:ID', 'cbc:SalesOrderID']);
  Path := FDoc.Path + '/cac:BillingReference';
  for I := 0 to FDoc.BillingReference.Count - 1 do
  begin
    Source := FDoc.BillingReference[I].InvoiceDocumentReference;
    Reference := FInvoice.PrecedingInvoiceReferences.AddPrecedingInvoiceReference;
    Reference.ID := IDValue(Source.ID, Path + '/cac:InvoiceDocumentReference/cbc:ID');
    Reference.IssueDate := Date(Source.IssueDate, Path + '/cac:InvoiceDocumentReference/cbc:IssueDate');
    Source.ListFilledChildren(FFilled);
    Rest(Path + '/cac:InvoiceDocumentReference', ['cbc:ID', 'cbc:IssueDate']);
    FDoc.BillingReference[I].ListFilledChildren(FFilled);
    Rest(Path, ['cac:InvoiceDocumentReference']);
  end;
  FInvoice.DeliveryReceiptNumber := DocumentID(FDoc.DespatchDocumentReference,
    FDoc.Path + '/cac:DespatchDocumentReference');
  FInvoice.ReceiptDocumentReference := DocumentID(FDoc.ReceiptDocumentReference,
    FDoc.Path + '/cac:ReceiptDocumentReference');
  FInvoice.ContractDocumentReference := DocumentID(FDoc.ContractDocumentReference,
    FDoc.Path + '/cac:ContractDocumentReference');
  if (FDoc.ProjectReference <> nil) and (FDoc.ProjectReference.Count > 0) then
  begin
    FInvoice.ProjectReference := IDValue(FDoc.ProjectReference[0].ID, FDoc.Path + '/cac:ProjectReference/cbc:ID');
    FDoc.ProjectReference[0].ListFilledChildren(FFilled);
    Rest(FDoc.Path + '/cac:ProjectReference', ['cbc:ID']);
    Excess(FDoc.ProjectReference.Count, FDoc.Path + '/cac:ProjectReference');
  end;
end;

{ BT-17 tender references (type 50), BG-24 attachments and BT-18 (type
  130); in ubl:CreditNote a reference with type 50 and no attachment is
  BT-11. Without a type code an attachment keeps the default 916.
  DE: BT-17 Vergabereferenzen (Art 50), BG-24 Anlagen und BT-18 (Art 130);
  in ubl:CreditNote ist eine Referenz mit Art 50 ohne Anhang BT-11. Ohne
  Art behaelt eine Anlage die Vorgabe 916. }
procedure TUBLReadMapper.ReadAttachments;
var
  I: TLandrixEInvoiceListIndex;
  Source: TLandrixUBLDocumentReference;
  Attachment: TLandrixInvoiceAttachment;
  Path, TypeText: TLandrixEInvoiceString;
begin
  Path := FDoc.Path + '/cac:OriginatorDocumentReference';
  for I := 0 to FDoc.OriginatorDocumentReference.Count - 1 do
  begin
    Source := FDoc.OriginatorDocumentReference[I];
    Attachment := FInvoice.Attachments.AddAttachment(iat_application_None);
    Attachment.ID := IDValue(Source.ID, Path + '/cbc:ID');
    Attachment.TypeCode := iatc_50;
    Source.ListFilledChildren(FFilled);
    Rest(Path, ['cbc:ID']);
  end;
  Path := FDoc.Path + '/cac:AdditionalDocumentReference';
  for I := 0 to FDoc.AdditionalDocumentReference.Count - 1 do
  begin
    Source := FDoc.AdditionalDocumentReference[I];
    TypeText := CodeValue(Source.DocumentTypeCode, Path + '/cbc:DocumentTypeCode');
    if (FDoc.CreditNote <> nil) and (TypeText = '50') and Source.Attachment.IsEmpty and
       (FInvoice.ProjectReference = '') then
    begin
      FInvoice.ProjectReference := IDValue(Source.ID, Path + '/cbc:ID');
      Source.ListFilledChildren(FFilled);
      Rest(Path, ['cbc:ID', 'cbc:DocumentTypeCode']);
      Continue;
    end;
    Attachment := FInvoice.Attachments.AddAttachment(iat_application_None);
    if (TypeText <> '') and not LandrixEInvoiceAttachmentTypeCodeFromStr(TypeText, Attachment.TypeCode) then
    begin
      Attachment.TypeCode := iatc_None;
      UnknownCode(TypeText, Path + '/cbc:DocumentTypeCode', Attachment.TypeCodeOther);
    end;
    { BT-18-1: only the invoiced object identifier keeps its scheme }
    if Attachment.TypeCode = iatc_130 then
    begin
      Attachment.ID := Source.ID.Value;
      Attachment.SchemeID := Source.ID.SchemeID;
    end
    else
      Attachment.ID := IDValue(Source.ID, Path + '/cbc:ID');
    Attachment.DocumentDescription := FirstText(Source.DocumentDescription, Path + '/cbc:DocumentDescription');
    Attachment.ExternalReference := IDValue(Source.Attachment.ExternalReference.URI,
      Path + '/cac:Attachment/cac:ExternalReference/cbc:URI');
    Source.Attachment.ExternalReference.ListFilledChildren(FFilled);
    Rest(Path + '/cac:Attachment/cac:ExternalReference', ['cbc:URI']);
    if Source.Attachment.EmbeddedDocumentBinaryObject.Value <> '' then
    begin
      if not LandrixEInvoiceAttachmentTypeFromStr(Source.Attachment.EmbeddedDocumentBinaryObject.MimeCode,
        Attachment.AttachmentType) then
      begin
        Attachment.AttachmentType := iat_application_None;
        UnknownCode(Source.Attachment.EmbeddedDocumentBinaryObject.MimeCode,
          Path + '/cac:Attachment/cbc:EmbeddedDocumentBinaryObject/@mimeCode', Attachment.AttachmentTypeOther);
      end;
      Attachment.Filename := Source.Attachment.EmbeddedDocumentBinaryObject.Filename;
      try
        Attachment.SetDataFromBase64(Source.Attachment.EmbeddedDocumentBinaryObject.Value);
      except
        on E: Exception do
          Report(edk_ConversionFailed, Path + '/cac:Attachment/cbc:EmbeddedDocumentBinaryObject',
            'attachment data not decoded (' + TLandrixEInvoiceString(E.Message) + '); left empty', eds_Error);
      end;
    end;
    Source.Attachment.ListFilledChildren(FFilled);
    Rest(Path + '/cac:Attachment', ['cbc:EmbeddedDocumentBinaryObject', 'cac:ExternalReference']);
    Source.ListFilledChildren(FFilled);
    Rest(Path, ['cbc:ID', 'cbc:DocumentTypeCode', 'cbc:DocumentDescription', 'cac:Attachment']);
  end;
end;

procedure TUBLReadMapper.ReadAddress(AAddress: TLandrixInvoiceAddress; ASource: TLandrixUBLAddress;
  const APath: TLandrixEInvoiceString);
begin
  AAddress.StreetName := ASource.StreetName;
  AAddress.AdditionalStreetName := ASource.AdditionalStreetName;
  AAddress.City := ASource.CityName;
  AAddress.PostalZone := ASource.PostalZone;
  AAddress.CountrySubentity := ASource.CountrySubentity;
  if ASource.AddressLine.Count > 0 then
  begin
    AAddress.AddressLine := ASource.AddressLine[0].Line;
    ASource.AddressLine[0].ListFilledChildren(FFilled);
    Rest(APath + '/cac:AddressLine', ['cbc:Line']);
  end;
  Excess(ASource.AddressLine.Count, APath + '/cac:AddressLine');
  AAddress.CountryCode := CodeValue(ASource.Country.IdentificationCode, APath + '/cac:Country/cbc:IdentificationCode');
  ASource.Country.ListFilledChildren(FFilled);
  Rest(APath + '/cac:Country', ['cbc:IdentificationCode']);
  ASource.ListFilledChildren(FFilled);
  Rest(APath, ['cbc:StreetName', 'cbc:AdditionalStreetName', 'cbc:CityName', 'cbc:PostalZone', 'cbc:CountrySubentity',
    'cac:AddressLine', 'cac:Country']);
end;

{ BG-4/BG-7: an identifier with scheme SEPA is BT-90 (seller), one with
  another scheme the global identifier, one without scheme the identifier;
  BT-31 (scheme VAT) and BT-32 (scheme FC); BT-33 only for the seller.
  DE: BG-4/BG-7: eine Kennung mit Schema SEPA ist BT-90 (Verkaeufer), eine
  mit anderem Schema die globale Kennung, eine ohne Schema die Kennung;
  BT-31 (Schema VAT) und BT-32 (Schema FC); BT-33 nur beim Verkaeufer. }
procedure TUBLReadMapper.ReadParty(AParty: TLandrixInvoiceAccountingParty; ASource: TLandrixUBLParty;
  const APath: TLandrixEInvoiceString; AIsSeller: Boolean);
var
  I: TLandrixEInvoiceListIndex;
  ID: TLandrixUBLID;
  Scheme: TLandrixEInvoiceString;
  TaxScheme: TLandrixUBLPartyTaxScheme;
  LegalEntity: TLandrixUBLPartyLegalEntity;
  Taken: array[0..2] of string;
begin
  AParty.ElectronicAddressSellerBuyer := ASource.EndpointID.Value;
  AParty.ElectronicAddressSellerBuyerSchemeID := ASource.EndpointID.SchemeID;
  for I := 0 to ASource.PartyIdentification.Count - 1 do
  begin
    ID := ASource.PartyIdentification[I].ID;
    if SameAscii(ID.SchemeID, 'SEPA') then
    begin
      if AIsSeller and (AParty.BankAssignedCreditorIdentifier = '') then
        AParty.BankAssignedCreditorIdentifier := ID.Value
      else
        NotMapped(APath + '/cac:PartyIdentification', 'creditor identifier ' + ID.Value);
    end
    else if ID.SchemeID <> '' then
    begin
      if AParty.GlobalIdentifierSellerBuyer = '' then
      begin
        AParty.GlobalIdentifierSellerBuyer := ID.Value;
        AParty.GlobalIdentifierSellerBuyerSchemeID := ID.SchemeID;
      end
      else
        NotMapped(APath + '/cac:PartyIdentification', 'further global identifier ' + ID.Value);
    end
    else if AParty.IdentifierSellerBuyer = '' then
      AParty.IdentifierSellerBuyer := ID.Value
    else
      NotMapped(APath + '/cac:PartyIdentification', 'further identifier ' + ID.Value);
    ASource.PartyIdentification[I].ListFilledChildren(FFilled);
    Rest(APath + '/cac:PartyIdentification', ['cbc:ID']);
  end;
  if ASource.PartyName.Count > 0 then
  begin
    AParty.Name := ASource.PartyName[0].Name;
    ASource.PartyName[0].ListFilledChildren(FFilled);
    Rest(APath + '/cac:PartyName', ['cbc:Name']);
  end;
  Excess(ASource.PartyName.Count, APath + '/cac:PartyName');
  ReadAddress(AParty.Address, ASource.PostalAddress, APath + '/cac:PostalAddress');
  for I := 0 to ASource.PartyTaxScheme.Count - 1 do
  begin
    TaxScheme := ASource.PartyTaxScheme[I];
    Scheme := TaxScheme.TaxScheme.ID.Value;
    if (Scheme = 'VAT') and (AParty.VATCompanyID = '') then
      AParty.VATCompanyID := IDValue(TaxScheme.CompanyID, APath + '/cac:PartyTaxScheme/cbc:CompanyID')
    { BT-32: the binding fixes only VAT for BT-31; any other scheme (FC,
      the KoSIT examples use '???') is the tax registration.
      DE: BT-32: die Bindung legt nur VAT fuer BT-31 fest; jedes andere
      Schema (FC, die KoSIT-Beispiele nutzen '???') ist die Steuernummer. }
    else if (Scheme <> '') and (Scheme <> 'VAT') and (AParty.VATCompanyNumber = '') then
      AParty.VATCompanyNumber := IDValue(TaxScheme.CompanyID, APath + '/cac:PartyTaxScheme/cbc:CompanyID')
    else
      NotMapped(APath + '/cac:PartyTaxScheme', 'tax registration ' + TaxScheme.CompanyID.Value +
        ' (scheme ' + Scheme + ')');
    TaxScheme.TaxScheme.ListFilledChildren(FFilled);
    Rest(APath + '/cac:PartyTaxScheme/cac:TaxScheme', ['cbc:ID']);
    TaxScheme.ListFilledChildren(FFilled);
    Rest(APath + '/cac:PartyTaxScheme', ['cbc:CompanyID', 'cac:TaxScheme']);
  end;
  if ASource.PartyLegalEntity.Count > 0 then
  begin
    LegalEntity := ASource.PartyLegalEntity[0];
    AParty.RegistrationName := LegalEntity.RegistrationName;
    AParty.CompanyID := LegalEntity.CompanyID.Value;
    AParty.CompanyIDSchemeID := LegalEntity.CompanyID.SchemeID;
    Taken[0] := 'cbc:RegistrationName';
    Taken[1] := 'cbc:CompanyID';
    Taken[2] := '';
    if AIsSeller then
    begin
      AParty.AdditionalLegalInformationSeller := LegalEntity.CompanyLegalForm;
      Taken[2] := 'cbc:CompanyLegalForm';
    end;
    LegalEntity.ListFilledChildren(FFilled);
    Rest(APath + '/cac:PartyLegalEntity', Taken);
  end;
  Excess(ASource.PartyLegalEntity.Count, APath + '/cac:PartyLegalEntity');
  AParty.ContactName := ASource.Contact.Name;
  AParty.ContactTelephone := ASource.Contact.Telephone;
  AParty.ContactElectronicMail := ASource.Contact.ElectronicMail;
  ASource.Contact.ListFilledChildren(FFilled);
  Rest(APath + '/cac:Contact', ['cbc:Name', 'cbc:Telephone', 'cbc:ElectronicMail']);
  ASource.ListFilledChildren(FFilled);
  Rest(APath, ['cbc:EndpointID', 'cac:PartyIdentification', 'cac:PartyName', 'cac:PostalAddress',
    'cac:PartyTaxScheme', 'cac:PartyLegalEntity', 'cac:Contact']);
end;

{ BG-10 payee and BG-11 tax representative: the first identifier (with or
  without scheme), name, address, VAT identifier (scheme VAT), legal
  registration with scheme, contact. An identifier with scheme SEPA is the
  creditor identifier BT-90, which the EN 16931 UBL binding also allows in
  the payee; it goes to the seller like there.
  DE: BG-10 Zahlungsempfaenger und BG-11 Steuervertreter: die erste
  Kennung (mit oder ohne Schema), Name, Anschrift, USt-IdNr. (Schema VAT),
  Registernummer mit Schema, Kontakt. Eine Kennung mit Schema SEPA ist die
  Glaeubiger-ID BT-90, die die UBL-Bindung von EN 16931 auch beim
  Zahlungsempfaenger erlaubt; sie kommt wie dort zum Verkaeufer. }
procedure TUBLReadMapper.ReadFurtherParty(AParty: TLandrixInvoiceParty; ASource: TLandrixUBLParty;
  const APath: TLandrixEInvoiceString);
var
  I: TLandrixEInvoiceListIndex;
  ID: TLandrixUBLID;
  TaxScheme: TLandrixUBLPartyTaxScheme;
  LegalEntity: TLandrixUBLPartyLegalEntity;
begin
  for I := 0 to ASource.PartyIdentification.Count - 1 do
  begin
    ID := ASource.PartyIdentification[I].ID;
    if SameAscii(ID.SchemeID, 'SEPA') and (FInvoice.AccountingSupplierParty.BankAssignedCreditorIdentifier = '') then
      FInvoice.AccountingSupplierParty.BankAssignedCreditorIdentifier := ID.Value
    else if (AParty.Identifier = '') and not SameAscii(ID.SchemeID, 'SEPA') then
    begin
      AParty.Identifier := ID.Value;
      AParty.IdentifierSchemeID := ID.SchemeID;
    end
    else
      NotMapped(APath + '/cac:PartyIdentification', 'further identifier ' + ID.Value);
    ASource.PartyIdentification[I].ListFilledChildren(FFilled);
    Rest(APath + '/cac:PartyIdentification', ['cbc:ID']);
  end;
  if ASource.PartyName.Count > 0 then
  begin
    AParty.Name := ASource.PartyName[0].Name;
    ASource.PartyName[0].ListFilledChildren(FFilled);
    Rest(APath + '/cac:PartyName', ['cbc:Name']);
  end;
  Excess(ASource.PartyName.Count, APath + '/cac:PartyName');
  ReadAddress(AParty.Address, ASource.PostalAddress, APath + '/cac:PostalAddress');
  for I := 0 to ASource.PartyTaxScheme.Count - 1 do
  begin
    TaxScheme := ASource.PartyTaxScheme[I];
    if (TaxScheme.TaxScheme.ID.Value = 'VAT') and (AParty.VATCompanyID = '') then
      AParty.VATCompanyID := IDValue(TaxScheme.CompanyID, APath + '/cac:PartyTaxScheme/cbc:CompanyID')
    else
      NotMapped(APath + '/cac:PartyTaxScheme', 'tax registration ' + TaxScheme.CompanyID.Value +
        ' (scheme ' + TaxScheme.TaxScheme.ID.Value + ')');
    TaxScheme.TaxScheme.ListFilledChildren(FFilled);
    Rest(APath + '/cac:PartyTaxScheme/cac:TaxScheme', ['cbc:ID']);
    TaxScheme.ListFilledChildren(FFilled);
    Rest(APath + '/cac:PartyTaxScheme', ['cbc:CompanyID', 'cac:TaxScheme']);
  end;
  if ASource.PartyLegalEntity.Count > 0 then
  begin
    LegalEntity := ASource.PartyLegalEntity[0];
    AParty.CompanyID := LegalEntity.CompanyID.Value;
    AParty.CompanyIDSchemeID := LegalEntity.CompanyID.SchemeID;
    LegalEntity.ListFilledChildren(FFilled);
    Rest(APath + '/cac:PartyLegalEntity', ['cbc:CompanyID']);
  end;
  Excess(ASource.PartyLegalEntity.Count, APath + '/cac:PartyLegalEntity');
  AParty.ContactName := ASource.Contact.Name;
  AParty.ContactTelephone := ASource.Contact.Telephone;
  AParty.ContactElectronicMail := ASource.Contact.ElectronicMail;
  ASource.Contact.ListFilledChildren(FFilled);
  Rest(APath + '/cac:Contact', ['cbc:Name', 'cbc:Telephone', 'cbc:ElectronicMail']);
  ASource.ListFilledChildren(FFilled);
  Rest(APath, ['cac:PartyIdentification', 'cac:PartyName', 'cac:PostalAddress', 'cac:PartyTaxScheme',
    'cac:PartyLegalEntity', 'cac:Contact']);
end;

procedure TUBLReadMapper.ReadDelivery;
var
  Source: TLandrixUBLDelivery;
  Info: TLandrixInvoiceDeliveryInformation;
  Path: TLandrixEInvoiceString;
begin
  Path := FDoc.Path + '/cac:Delivery';
  Excess(FDoc.Delivery.Count, Path);
  if FDoc.Delivery.Count = 0 then
    Exit;
  Source := FDoc.Delivery[0];
  Info := FInvoice.DeliveryInformation;
  Info.ActualDeliveryDate := Date(Source.ActualDeliveryDate, Path + '/cbc:ActualDeliveryDate');
  { the scheme only with an identifier: without one the model keeps its
    default, as the CII reader does
    DE: das Schema nur mit Kennung: ohne Kennung behaelt das Modell seine
    Vorgabe, wie beim CII-Leser }
  if Source.DeliveryLocation.ID.Value <> '' then
  begin
    Info.LocationIdentifier := Source.DeliveryLocation.ID.Value;
    Info.LocationIdentifierSchemeID := Source.DeliveryLocation.ID.SchemeID;
  end;
  ReadAddress(Info.Address, Source.DeliveryLocation.Address, Path + '/cac:DeliveryLocation/cac:Address');
  Source.DeliveryLocation.ListFilledChildren(FFilled);
  Rest(Path + '/cac:DeliveryLocation', ['cbc:ID', 'cac:Address']);
  if Source.DeliveryParty.PartyName.Count > 0 then
  begin
    Info.Name := Source.DeliveryParty.PartyName[0].Name;
    Source.DeliveryParty.PartyName[0].ListFilledChildren(FFilled);
    Rest(Path + '/cac:DeliveryParty/cac:PartyName', ['cbc:Name']);
  end;
  Excess(Source.DeliveryParty.PartyName.Count, Path + '/cac:DeliveryParty/cac:PartyName');
  Source.DeliveryParty.ListFilledChildren(FFilled);
  Rest(Path + '/cac:DeliveryParty', ['cac:PartyName']);
  Source.ListFilledChildren(FFilled);
  Rest(Path, ['cbc:ActualDeliveryDate', 'cac:DeliveryLocation', 'cac:DeliveryParty']);
end;

{ BG-16: BT-81 with BT-82 (attribute name), BT-83 (the first remittance
  information), BG-18 card (network 'NA' is the placeholder of the writer),
  BG-17 credit transfer, BG-19 direct debit with BT-89 mandate. One account
  per payment type.
  DE: BG-16: BT-81 mit BT-82 (Attribut name), BT-83 (der erste
  Verwendungszweck), BG-18 Karte (Kartennetz 'NA' ist der Platzhalter des
  Schreibers), BG-17 Ueberweisung, BG-19 Lastschrift mit BT-89 Mandat. Ein
  Konto je Zahlungsart. }
procedure TUBLReadMapper.ReadPaymentMeans;
var
  I, J: TLandrixEInvoiceListIndex;
  Source: TLandrixUBLPaymentMeans;
  Payment: TLandrixInvoicePaymentType;
  MeansCode: TLandrixUBLCode;
  Path, Text: TLandrixEInvoiceString;
begin
  Path := FDoc.Path + '/cac:PaymentMeans';
  for I := 0 to FDoc.PaymentMeans.Count - 1 do
  begin
    Source := FDoc.PaymentMeans[I];
    Payment := FInvoice.PaymentTypes.AddPaymentType;
    MeansCode := Source.PaymentMeansCode;
    Payment.PaymentMeansInformation := MeansCode.Name;
    MeansCode.Name := '';
    Text := CodeValue(MeansCode, Path + '/cbc:PaymentMeansCode');
    if (Text <> '') and not LandrixEInvoicePaymentMeansCodeFromStr(Text, Payment.PaymentMeansCode) then
    begin
      Payment.PaymentMeansCode := ipmc_NotImplemented;
      UnknownCode(Text, Path + '/cbc:PaymentMeansCode', Payment.PaymentMeansCodeOther);
    end;
    for J := 0 to Source.PaymentID.Count - 1 do
    begin
      Text := IDValue(Source.PaymentID[J], Path + '/cbc:PaymentID');
      if FInvoice.PaymentID = '' then
        FInvoice.PaymentID := Text
      else if Text <> FInvoice.PaymentID then
        NotMapped(Path + '/cbc:PaymentID', 'further remittance information ' + Text);
    end;
    if not Source.CardAccount.IsEmpty then
    begin
      Payment.FinancialAccount := IDValue(Source.CardAccount.PrimaryAccountNumberID,
        Path + '/cac:CardAccount/cbc:PrimaryAccountNumberID');
      Payment.FinancialAccountName := Source.CardAccount.HolderName;
      if (Source.CardAccount.NetworkID.Value <> '') and (Source.CardAccount.NetworkID.Value <> 'NA') then
        NotMapped(Path + '/cac:CardAccount/cbc:NetworkID', 'card network ' + Source.CardAccount.NetworkID.Value);
      Source.CardAccount.ListFilledChildren(FFilled);
      Rest(Path + '/cac:CardAccount', ['cbc:PrimaryAccountNumberID', 'cbc:NetworkID', 'cbc:HolderName']);
    end;
    if not Source.PayeeFinancialAccount.IsEmpty then
    begin
      { With a direct debit (49, 59) the model's account is the debited
        account (BT-91); a credit transfer account (BG-17) is reported.
        DE: Bei einer Lastschrift (49, 59) ist das Konto des Modells das
        belastete Konto (BT-91); ein Ueberweisungskonto (BG-17) wird
        gemeldet. }
      if IsDirectDebit(Payment.PaymentMeansCode) then
        NotMapped(Path + '/cac:PayeeFinancialAccount', 'credit transfer account with a direct debit')
      else if Payment.FinancialAccount <> '' then
        NotMapped(Path + '/cac:PayeeFinancialAccount', 'second account of one payment means')
      else
      begin
        Payment.FinancialAccount := IDValue(Source.PayeeFinancialAccount.ID, Path + '/cac:PayeeFinancialAccount/cbc:ID');
        Payment.FinancialAccountName := Source.PayeeFinancialAccount.Name;
        Payment.FinancialInstitutionBranch := IDValue(Source.PayeeFinancialAccount.FinancialInstitutionBranch.ID,
          Path + '/cac:PayeeFinancialAccount/cac:FinancialInstitutionBranch/cbc:ID');
        Source.PayeeFinancialAccount.FinancialInstitutionBranch.ListFilledChildren(FFilled);
        Rest(Path + '/cac:PayeeFinancialAccount/cac:FinancialInstitutionBranch', ['cbc:ID']);
        Source.PayeeFinancialAccount.ListFilledChildren(FFilled);
        Rest(Path + '/cac:PayeeFinancialAccount', ['cbc:ID', 'cbc:Name', 'cac:FinancialInstitutionBranch']);
      end;
    end;
    if not Source.PaymentMandate.IsEmpty then
    begin
      Text := IDValue(Source.PaymentMandate.ID, Path + '/cac:PaymentMandate/cbc:ID');
      if FInvoice.PaymentMandateID = '' then
        FInvoice.PaymentMandateID := Text
      else if Text <> FInvoice.PaymentMandateID then
        NotMapped(Path + '/cac:PaymentMandate/cbc:ID', 'second mandate reference');
      if not Source.PaymentMandate.PayerFinancialAccount.IsEmpty then
      begin
        if Payment.FinancialAccount <> '' then
          NotMapped(Path + '/cac:PaymentMandate/cac:PayerFinancialAccount', 'second account of one payment means')
        else
        begin
          Payment.FinancialAccount := IDValue(Source.PaymentMandate.PayerFinancialAccount.ID,
            Path + '/cac:PaymentMandate/cac:PayerFinancialAccount/cbc:ID');
          Source.PaymentMandate.PayerFinancialAccount.ListFilledChildren(FFilled);
          Rest(Path + '/cac:PaymentMandate/cac:PayerFinancialAccount', ['cbc:ID']);
        end;
      end;
      Source.PaymentMandate.ListFilledChildren(FFilled);
      Rest(Path + '/cac:PaymentMandate', ['cbc:ID', 'cac:PayerFinancialAccount']);
    end;
    Source.ListFilledChildren(FFilled);
    Rest(Path, ['cbc:PaymentMeansCode', 'cbc:PaymentID', 'cac:CardAccount', 'cac:PayeeFinancialAccount',
      'cac:PaymentMandate']);
  end;
end;

{ BT-20: the first note of the first payment term, read as net note or
  #SKONTO# text.
  DE: BT-20: der erste Hinweis der ersten Zahlungsbedingung, gelesen als
  Nettohinweis oder #SKONTO#-Text. }
procedure TUBLReadMapper.ReadPaymentTerms;
var
  Path: TLandrixEInvoiceString;
begin
  Path := FDoc.Path + '/cac:PaymentTerms';
  Excess(FDoc.PaymentTerms.Count, Path);
  if FDoc.PaymentTerms.Count = 0 then
    Exit;
  LandrixEInvoiceReadPaymentTermsText(FInvoice, FirstText(FDoc.PaymentTerms[0].Note, Path + '/cbc:Note'));
  FDoc.PaymentTerms[0].ListFilledChildren(FFilled);
  Rest(Path, ['cbc:Note']);
end;

procedure TUBLReadMapper.ReadThirdPartyPayments;
var
  I: TLandrixEInvoiceListIndex;
  Source: TLandrixUBLPayment;
  Payment: TLandrixInvoicePrepaidPayment;
  PaidAmount: TLandrixUBLAmount;
  Path: TLandrixEInvoiceString;
begin
  if FDoc.PrepaidPayment = nil then
    Exit;
  Path := FDoc.Path + '/cac:PrepaidPayment';
  for I := 0 to FDoc.PrepaidPayment.Count - 1 do
  begin
    Source := FDoc.PrepaidPayment[I];
    Payment := FInvoice.PrepaidPayments.AddPrepaidPayment;
    Payment.ID := IDValue(Source.ID, Path + '/cbc:ID');
    { a third-party payment keeps its own currency }
    PaidAmount := Source.PaidAmount;
    Payment.PaidAmountCurrencyID := PaidAmount.CurrencyID;
    PaidAmount.CurrencyID := '';
    Payment.PaidAmount := Amount(PaidAmount, Path + '/cbc:PaidAmount');
    Payment.InstructionID := IDValue(Source.InstructionID, Path + '/cbc:InstructionID');
    Source.ListFilledChildren(FFilled);
    Rest(Path, ['cbc:ID', 'cbc:PaidAmount', 'cbc:InstructionID']);
  end;
end;

procedure TUBLReadMapper.ReadAllowanceCharge(AItem: TLandrixInvoiceAllowanceCharge;
  ACharge: TLandrixUBLAllowanceCharge; const APath: TLandrixEInvoiceString; AWithTax: Boolean);
var
  Category: TLandrixUBLTaxCategory;
  Taken: array[0..6] of string;
begin
  AItem.ChargeIndicator := (ACharge.ChargeIndicator = 'true') or (ACharge.ChargeIndicator = '1');
  ReadReason(AItem, ACharge.AllowanceChargeReasonCode, APath + '/cbc:AllowanceChargeReasonCode');
  AItem.Reason := FirstText(ACharge.AllowanceChargeReason, APath + '/cbc:AllowanceChargeReason');
  AItem.MultiplierFactorNumeric := Decimal(ACharge.MultiplierFactorNumeric, APath + '/cbc:MultiplierFactorNumeric');
  AItem.Amount := Amount(ACharge.Amount, APath + '/cbc:Amount');
  AItem.BaseAmount := Amount(ACharge.BaseAmount, APath + '/cbc:BaseAmount');
  Taken[0] := 'cbc:ChargeIndicator';
  Taken[1] := 'cbc:AllowanceChargeReasonCode';
  Taken[2] := 'cbc:AllowanceChargeReason';
  Taken[3] := 'cbc:MultiplierFactorNumeric';
  Taken[4] := 'cbc:Amount';
  Taken[5] := 'cbc:BaseAmount';
  Taken[6] := '';
  if AWithTax and (ACharge.TaxCategory.Count > 0) then
  begin
    Taken[6] := 'cac:TaxCategory';
    Category := ACharge.TaxCategory[0];
    ReadTaxCategory(IDValue(Category.ID, APath + '/cac:TaxCategory/cbc:ID'), APath + '/cac:TaxCategory/cbc:ID',
      AItem.TaxCategory, AItem.TaxCategoryOther);
    AItem.TaxPercent := Decimal(Category.Percent, APath + '/cac:TaxCategory/cbc:Percent');
    ReadTaxScheme(Category.TaxScheme, APath + '/cac:TaxCategory/cac:TaxScheme');
    Category.ListFilledChildren(FFilled);
    Rest(APath + '/cac:TaxCategory', ['cbc:ID', 'cbc:Percent', 'cac:TaxScheme']);
    Excess(ACharge.TaxCategory.Count, APath + '/cac:TaxCategory');
  end;
  ACharge.ListFilledChildren(FFilled);
  Rest(APath, Taken);
end;

{ BT-110 and BG-23 from the tax total with the breakdown (else the one in
  the invoice currency, else the first); without BT-6 the VAT accounting
  currency is its currency. A further tax total without breakdown in the
  differing BT-6 is BT-111.
  DE: BT-110 und BG-23 aus dem Steuergesamtbetrag mit Aufschluesselung
  (sonst dem in Rechnungswaehrung, sonst dem ersten); ohne BT-6 ist seine
  Waehrung die Steuerwaehrung. Ein weiterer Steuergesamtbetrag ohne
  Aufschluesselung in der abweichenden BT-6 ist BT-111. }
procedure TUBLReadMapper.ReadTax;
var
  I, Chosen: TLandrixEInvoiceListIndex;
  Total, Other: TLandrixUBLTaxTotal;
  Amount111: TLandrixUBLAmount;
  Value, Check: Currency;
  Rounded: Boolean;
  Source: TLandrixUBLTaxSubtotal;
  Subtotal: TLandrixInvoiceTaxAmount;
  Path, CategoryPath: TLandrixEInvoiceString;
begin
  Path := FDoc.Path + '/cac:TaxTotal';
  if FDoc.TaxTotal.Count = 0 then
    Exit;
  Chosen := -1;
  for I := 0 to FDoc.TaxTotal.Count - 1 do
    if (Chosen < 0) and (FDoc.TaxTotal[I].TaxSubtotal.Count > 0) then
      Chosen := I;
  for I := 0 to FDoc.TaxTotal.Count - 1 do
    if (Chosen < 0) and (FDoc.TaxTotal[I].TaxAmount.CurrencyID = FInvoice.InvoiceCurrencyCode) then
      Chosen := I;
  if Chosen < 0 then
    Chosen := 0;
  Total := FDoc.TaxTotal[Chosen];
  { BT-6 only when it differs, as in CII
    DE: BT-6 nur, wenn abweichend, wie in CII }
  if (FInvoice.TaxCurrencyCode = '') and (Total.TaxAmount.CurrencyID <> FInvoice.InvoiceCurrencyCode) then
    FInvoice.TaxCurrencyCode := Total.TaxAmount.CurrencyID;
  { the first other total without breakdown in the differing BT-6 is
    BT-111 }
  for I := 0 to FDoc.TaxTotal.Count - 1 do
    if I <> Chosen then
    begin
      Other := FDoc.TaxTotal[I];
      if (FInvoice.TaxCurrencyCode <> FInvoice.InvoiceCurrencyCode) and
         (Other.TaxAmount.CurrencyID = FInvoice.TaxCurrencyCode) and (Other.TaxSubtotal.Count = 0) and
         not FInvoice.TaxAmountTotalInTaxCurrency.HasValue then
      begin
        Amount111 := Other.TaxAmount;
        Amount111.CurrencyID := '';
        Value := Amount(Amount111, Path + '/cbc:TaxAmount');
        { not set when the text is no amount (reported by Amount) }
        if LandrixEInvoiceTryLexicalToCurrency(Amount111.Value, Check, Rounded) then
          FInvoice.TaxAmountTotalInTaxCurrency.SetValue(Value);
        Other.ListFilledChildren(FFilled);
        Rest(Path, ['cbc:TaxAmount']);
      end
      else
        NotMapped(Path, 'VAT total ' + Other.TaxAmount.Value + ' ' + Other.TaxAmount.CurrencyID + ' (BT-111)');
    end;
  FInvoice.TaxAmountTotal := Amount(Total.TaxAmount, Path + '/cbc:TaxAmount');
  CategoryPath := Path + '/cac:TaxSubtotal/cac:TaxCategory';
  for I := 0 to Total.TaxSubtotal.Count - 1 do
  begin
    Source := Total.TaxSubtotal[I];
    Subtotal := FInvoice.TaxAmountSubtotals.AddTaxAmount;
    Subtotal.TaxableAmount := Amount(Source.TaxableAmount, Path + '/cac:TaxSubtotal/cbc:TaxableAmount');
    Subtotal.TaxAmount := Amount(Source.TaxAmount, Path + '/cac:TaxSubtotal/cbc:TaxAmount');
    ReadTaxCategory(IDValue(Source.TaxCategory.ID, CategoryPath + '/cbc:ID'), CategoryPath + '/cbc:ID',
      Subtotal.TaxCategory, Subtotal.TaxCategoryOther);
    Subtotal.TaxPercent := Decimal(Source.TaxCategory.Percent, CategoryPath + '/cbc:Percent');
    Subtotal.TaxExemptionReasonCode := CodeValue(Source.TaxCategory.TaxExemptionReasonCode,
      CategoryPath + '/cbc:TaxExemptionReasonCode');
    Subtotal.TaxExemptionReason := FirstText(Source.TaxCategory.TaxExemptionReason,
      CategoryPath + '/cbc:TaxExemptionReason');
    ReadTaxScheme(Source.TaxCategory.TaxScheme, CategoryPath + '/cac:TaxScheme');
    Source.TaxCategory.ListFilledChildren(FFilled);
    Rest(CategoryPath, ['cbc:ID', 'cbc:Percent', 'cbc:TaxExemptionReasonCode', 'cbc:TaxExemptionReason',
      'cac:TaxScheme']);
    Source.ListFilledChildren(FFilled);
    Rest(Path + '/cac:TaxSubtotal', ['cbc:TaxableAmount', 'cbc:TaxAmount', 'cac:TaxCategory']);
  end;
  Total.ListFilledChildren(FFilled);
  Rest(Path, ['cbc:TaxAmount', 'cac:TaxSubtotal']);
end;

procedure TUBLReadMapper.ReadTotals;
var
  Total: TLandrixUBLMonetaryTotal;
  Path: TLandrixEInvoiceString;
begin
  Total := FDoc.LegalMonetaryTotal;
  Path := FDoc.Path + '/cac:LegalMonetaryTotal';
  FInvoice.LineAmount := Amount(Total.LineExtensionAmount, Path + '/cbc:LineExtensionAmount');
  FInvoice.TaxExclusiveAmount := Amount(Total.TaxExclusiveAmount, Path + '/cbc:TaxExclusiveAmount');
  FInvoice.TaxInclusiveAmount := Amount(Total.TaxInclusiveAmount, Path + '/cbc:TaxInclusiveAmount');
  FInvoice.AllowanceTotalAmount := Amount(Total.AllowanceTotalAmount, Path + '/cbc:AllowanceTotalAmount');
  FInvoice.ChargeTotalAmount := Amount(Total.ChargeTotalAmount, Path + '/cbc:ChargeTotalAmount');
  FInvoice.PrepaidAmount := Amount(Total.PrepaidAmount, Path + '/cbc:PrepaidAmount');
  FInvoice.PayableRoundingAmount := Amount(Total.PayableRoundingAmount, Path + '/cbc:PayableRoundingAmount');
  FInvoice.PayableAmount := Amount(Total.PayableAmount, Path + '/cbc:PayableAmount');
  Total.ListFilledChildren(FFilled);
  Rest(Path, ['cbc:LineExtensionAmount', 'cbc:TaxExclusiveAmount', 'cbc:TaxInclusiveAmount',
    'cbc:AllowanceTotalAmount', 'cbc:ChargeTotalAmount', 'cbc:PrepaidAmount', 'cbc:PayableRoundingAmount',
    'cbc:PayableAmount']);
end;

{ BG-25 line; BT-128 is only the document reference with type 130; sub
  lines are read into the tree of the model.
  DE: BG-25 Position; BT-128 ist nur die Dokumentreferenz mit Art 130;
  Unterpositionen werden in den Baum des Modells gelesen. }
procedure TUBLReadMapper.ReadLine(ALine: TLandrixInvoiceLine; const ASource: TUBLLine;
  const APath: TLandrixEInvoiceString);
var
  I: TLandrixEInvoiceListIndex;
  Period: TLandrixUBLPeriod;
  Document: TLandrixUBLDocumentReference;
  ObjectFound: Boolean;
begin
  ALine.ID := IDValue(ASource.ID^, APath + '/cbc:ID');
  ALine.Note := FirstText(ASource.Note, APath + '/cbc:Note');
  ALine.Quantity := Quantity(ASource.Quantity^, APath + '/' + ASource.QuantityName, ALine.UnitCode, ALine.UnitCodeOther);
  ALine.LineAmount := Amount(ASource.LineExtensionAmount^, APath + '/cbc:LineExtensionAmount');
  ALine.BuyerAccountingReference := ASource.AccountingCost^;
  if ASource.InvoicePeriod.Count > 0 then
  begin
    Period := ASource.InvoicePeriod[0];
    ALine.InvoiceLinePeriodStartDate := Date(Period.StartDate, APath + '/cac:InvoicePeriod/cbc:StartDate');
    ALine.InvoiceLinePeriodEndDate := Date(Period.EndDate, APath + '/cac:InvoicePeriod/cbc:EndDate');
    Period.ListFilledChildren(FFilled);
    Rest(APath + '/cac:InvoicePeriod', ['cbc:StartDate', 'cbc:EndDate']);
  end;
  Excess(ASource.InvoicePeriod.Count, APath + '/cac:InvoicePeriod');
  if ASource.OrderLineReference.Count > 0 then
  begin
    ALine.OrderLineReference := IDValue(ASource.OrderLineReference[0].LineID, APath + '/cac:OrderLineReference/cbc:LineID');
    ASource.OrderLineReference[0].ListFilledChildren(FFilled);
    Rest(APath + '/cac:OrderLineReference', ['cbc:LineID']);
  end;
  Excess(ASource.OrderLineReference.Count, APath + '/cac:OrderLineReference');
  ObjectFound := False;
  for I := 0 to ASource.DocumentReference.Count - 1 do
  begin
    Document := ASource.DocumentReference[I];
    if (Document.DocumentTypeCode.Value = '130') and not ObjectFound then
    begin
      ObjectFound := True;
      ALine.ObjectIdentifier := Document.ID.Value;
      ALine.ObjectIdentifierSchemeID := Document.ID.SchemeID;
      CodeValue(Document.DocumentTypeCode, APath + '/cac:DocumentReference/cbc:DocumentTypeCode');
      Document.ListFilledChildren(FFilled);
      Rest(APath + '/cac:DocumentReference', ['cbc:ID', 'cbc:DocumentTypeCode']);
    end
    else
      NotMapped(APath + '/cac:DocumentReference', 'line document reference ' + Document.ID.Value);
  end;
  for I := 0 to ASource.AllowanceCharge.Count - 1 do
    ReadAllowanceCharge(ALine.AllowanceCharges.AddAllowanceCharge, ASource.AllowanceCharge[I],
      APath + '/cac:AllowanceCharge', False);
  ReadLineItem(ALine, ASource.Item, APath + '/cac:Item');
  ReadLinePrice(ALine, ASource.Price, APath + '/cac:Price');
  for I := 0 to SubLineCount(ASource) - 1 do
    ReadLine(ALine.SubInvoiceLines.AddInvoiceLine, SubLineAt(ASource, I), APath + '/' + ASource.SubLineName);
  ListLineChildren(ASource, FFilled);
  Rest(APath, ['cbc:ID', 'cbc:Note', 'cbc:InvoicedQuantity', 'cbc:CreditedQuantity', 'cbc:LineExtensionAmount',
    'cbc:AccountingCost', 'cac:InvoicePeriod', 'cac:OrderLineReference', 'cac:DocumentReference',
    'cac:AllowanceCharge', 'cac:Item', 'cac:Price', 'cac:SubInvoiceLine', 'cac:SubCreditNoteLine']);
end;

{ BG-31: BT-157 goes to StandardItemIdentifier, with scheme 0160 (GTIN)
  also to GlobalID_EAN_GTIN; BG-30 from the first classified tax category.
  DE: BG-31: BT-157 kommt nach StandardItemIdentifier, mit Schema 0160
  (GTIN) auch nach GlobalID_EAN_GTIN; BG-30 aus der ersten
  Steuerkategorie. }
procedure TUBLReadMapper.ReadLineItem(ALine: TLandrixInvoiceLine; AItem: TLandrixUBLItem;
  const APath: TLandrixEInvoiceString);
var
  I: TLandrixEInvoiceListIndex;
  Classification: TLandrixInvoiceLineItemClassification;
  Source: TLandrixUBLCommodityClassification;
  Category: TLandrixUBLTaxCategory;
  Attribute: TLandrixInvoiceLineItemAttribute;
  Taken: array[0..8] of string;
begin
  Taken[0] := 'cbc:Description';
  Taken[1] := 'cbc:Name';
  Taken[2] := 'cac:BuyersItemIdentification';
  Taken[3] := 'cac:SellersItemIdentification';
  Taken[4] := 'cac:OriginCountry';
  Taken[5] := 'cac:CommodityClassification';
  Taken[6] := 'cac:ClassifiedTaxCategory';
  Taken[7] := 'cac:AdditionalItemProperty';
  Taken[8] := 'cac:StandardItemIdentification';
  ALine.Description := FirstText(AItem.Description, APath + '/cbc:Description');
  ALine.Name := AItem.Name;
  ALine.BuyersItemIdentification := IDValue(AItem.BuyersItemIdentification.ID,
    APath + '/cac:BuyersItemIdentification/cbc:ID');
  AItem.BuyersItemIdentification.ListFilledChildren(FFilled);
  Rest(APath + '/cac:BuyersItemIdentification', ['cbc:ID']);
  ALine.SellersItemIdentification := IDValue(AItem.SellersItemIdentification.ID,
    APath + '/cac:SellersItemIdentification/cbc:ID');
  AItem.SellersItemIdentification.ListFilledChildren(FFilled);
  Rest(APath + '/cac:SellersItemIdentification', ['cbc:ID']);
  ALine.StandardItemIdentifier := AItem.StandardItemIdentification.ID.Value;
  ALine.StandardItemIdentifierSchemeID := AItem.StandardItemIdentification.ID.SchemeID;
  if ALine.StandardItemIdentifierSchemeID = '0160' then
    ALine.GlobalID_EAN_GTIN := ALine.StandardItemIdentifier;
  AItem.StandardItemIdentification.ListFilledChildren(FFilled);
  Rest(APath + '/cac:StandardItemIdentification', ['cbc:ID']);
  ALine.OriginTradeCountry := CodeValue(AItem.OriginCountry.IdentificationCode,
    APath + '/cac:OriginCountry/cbc:IdentificationCode');
  AItem.OriginCountry.ListFilledChildren(FFilled);
  Rest(APath + '/cac:OriginCountry', ['cbc:IdentificationCode']);
  for I := 0 to AItem.CommodityClassification.Count - 1 do
  begin
    Source := AItem.CommodityClassification[I];
    Classification := ALine.ItemClassifications.AddItemClassification;
    Classification.ClassCode := Source.ItemClassificationCode.Value;
    Classification.ListID := Source.ItemClassificationCode.ListID;
    Classification.ListVersionID := Source.ItemClassificationCode.ListVersionID;
    if Source.ItemClassificationCode.Name <> '' then
      NotMapped(APath + '/cac:CommodityClassification/cbc:ItemClassificationCode/@name',
        'code name ' + Source.ItemClassificationCode.Name);
    Source.ListFilledChildren(FFilled);
    Rest(APath + '/cac:CommodityClassification', ['cbc:ItemClassificationCode']);
  end;
  if AItem.ClassifiedTaxCategory.Count > 0 then
  begin
    Category := AItem.ClassifiedTaxCategory[0];
    ReadTaxCategory(IDValue(Category.ID, APath + '/cac:ClassifiedTaxCategory/cbc:ID'),
      APath + '/cac:ClassifiedTaxCategory/cbc:ID', ALine.TaxCategory, ALine.TaxCategoryOther);
    ALine.TaxPercent := Decimal(Category.Percent, APath + '/cac:ClassifiedTaxCategory/cbc:Percent');
    ALine.TaxExemptionReason := FirstText(Category.TaxExemptionReason,
      APath + '/cac:ClassifiedTaxCategory/cbc:TaxExemptionReason');
    ReadTaxScheme(Category.TaxScheme, APath + '/cac:ClassifiedTaxCategory/cac:TaxScheme');
    Category.ListFilledChildren(FFilled);
    Rest(APath + '/cac:ClassifiedTaxCategory', ['cbc:ID', 'cbc:Percent', 'cbc:TaxExemptionReason', 'cac:TaxScheme']);
  end;
  Excess(AItem.ClassifiedTaxCategory.Count, APath + '/cac:ClassifiedTaxCategory');
  for I := 0 to AItem.AdditionalItemProperty.Count - 1 do
  begin
    Attribute := ALine.ItemAttributes.AddItemAttribute;
    Attribute.Name := AItem.AdditionalItemProperty[I].Name;
    Attribute.Value := AItem.AdditionalItemProperty[I].Value;
    AItem.AdditionalItemProperty[I].ListFilledChildren(FFilled);
    Rest(APath + '/cac:AdditionalItemProperty', ['cbc:Name', 'cbc:Value']);
  end;
  AItem.ListFilledChildren(FFilled);
  Rest(APath, Taken);
end;

{ BG-29: BT-146, BT-149/BT-150, BT-148 gross price (base amount of the
  price allowance) and BT-147 discount; a charge on the price has no place.
  DE: BG-29: BT-146, BT-149/BT-150, BT-148 Bruttopreis (Basisbetrag des
  Preisnachlasses) und BT-147 Rabatt; ein Zuschlag auf den Preis hat keinen
  Platz. }
procedure TUBLReadMapper.ReadLinePrice(ALine: TLandrixInvoiceLine; APrice: TLandrixUBLPrice;
  const APath: TLandrixEInvoiceString);
var
  Discount: TLandrixUBLAllowanceCharge;
begin
  ALine.NetPriceAmount := Price(APrice.PriceAmount, APath + '/cbc:PriceAmount');
  if APrice.BaseQuantity.Value <> '' then
    ALine.BaseQuantity := Quantity(APrice.BaseQuantity, APath + '/cbc:BaseQuantity', ALine.BaseQuantityUnitCode,
      ALine.BaseQuantityUnitCodeOther);
  if APrice.AllowanceCharge.Count > 0 then
  begin
    Discount := APrice.AllowanceCharge[0];
    if (Discount.ChargeIndicator = 'true') or (Discount.ChargeIndicator = '1') then
      NotMapped(APath + '/cac:AllowanceCharge', 'charge on the price')
    else
    begin
      ALine.GrossPriceAmount := Price(Discount.BaseAmount, APath + '/cac:AllowanceCharge/cbc:BaseAmount');
      ALine.DiscountOnTheGrossPrice := Price(Discount.Amount, APath + '/cac:AllowanceCharge/cbc:Amount');
      Discount.ListFilledChildren(FFilled);
      Rest(APath + '/cac:AllowanceCharge', ['cbc:ChargeIndicator', 'cbc:Amount', 'cbc:BaseAmount']);
    end;
  end;
  Excess(APrice.AllowanceCharge.Count, APath + '/cac:AllowanceCharge');
  APrice.ListFilledChildren(FFilled);
  Rest(APath, ['cbc:PriceAmount', 'cbc:BaseQuantity', 'cac:AllowanceCharge']);
end;

{ --- public ------------------------------------------------------------------- }

function LandrixEInvoiceUBLRootFor(AInvoice: TLandrixInvoice;
  const ASpec: TLandrixEInvoiceSpec): TLandrixEInvoiceUBLRoot;
begin
  if ASpec.Target.Syntax <> esy_UBL then
    raise ELandrixEInvoiceError.Create('LandrixEInvoiceUBLRootFor: ' +
      string(LandrixEInvoiceTargetToStr(ASpec.Target)) + ' is no UBL specification');
  { every UBL specification of the directory uses ubl:CreditNote for 381 }
  if AInvoice.InvoiceTypeCode = itc_CreditNote then
    Result := eur_CreditNote
  else
    Result := eur_Invoice;
end;

procedure CheckUBLSpec(const AFunction: string; const ASpec: TLandrixEInvoiceSpec);
begin
  if (ASpec.Target.Syntax <> esy_UBL) or not ASpec.CanWrite then
    raise ELandrixEInvoiceError.Create(AFunction + ': ' + string(LandrixEInvoiceTargetToStr(ASpec.Target)) +
      ' is no UBL specification the library writes');
end;

procedure WriteUBLDocument(AInvoice: TLandrixInvoice; const ASpec: TLandrixEInvoiceSpec;
  ADiagnostics: TLandrixEInvoiceDiagnostics; const ADocument: TUBLDocument);
var
  Mapper: TUBLWriteMapper;
begin
  Mapper := TUBLWriteMapper.Create(AInvoice, ASpec, ADiagnostics, ADocument);
  try
    Mapper.Execute;
  finally
    Mapper.Free;
  end;
end;

function LandrixEInvoiceInvoiceToUBLInvoice(AInvoice: TLandrixInvoice; const ASpec: TLandrixEInvoiceSpec;
  ADiagnostics: TLandrixEInvoiceDiagnostics): TLandrixUBLInvoice;
begin
  CheckUBLSpec('LandrixEInvoiceInvoiceToUBLInvoice', ASpec);
  Result := TLandrixUBLInvoice.Create;
  try
    WriteUBLDocument(AInvoice, ASpec, ADiagnostics, InvoiceDocument(Result));
  except
    Result.Free;
    raise;
  end;
end;

function LandrixEInvoiceInvoiceToUBLCreditNote(AInvoice: TLandrixInvoice; const ASpec: TLandrixEInvoiceSpec;
  ADiagnostics: TLandrixEInvoiceDiagnostics): TLandrixUBLCreditNote;
begin
  CheckUBLSpec('LandrixEInvoiceInvoiceToUBLCreditNote', ASpec);
  Result := TLandrixUBLCreditNote.Create;
  try
    WriteUBLDocument(AInvoice, ASpec, ADiagnostics, CreditNoteDocument(Result));
  except
    Result.Free;
    raise;
  end;
end;

procedure ReadUBLDocument(const ADocument: TUBLDocument; AInvoice: TLandrixInvoice;
  ADiagnostics: TLandrixEInvoiceDiagnostics);
var
  Mapper: TUBLReadMapper;
begin
  Mapper := TUBLReadMapper.Create(ADocument, AInvoice, ADiagnostics);
  try
    Mapper.Execute;
  finally
    Mapper.Free;
  end;
end;

procedure LandrixEInvoiceUBLInvoiceToInvoice(AUBL: TLandrixUBLInvoice; AInvoice: TLandrixInvoice;
  ADiagnostics: TLandrixEInvoiceDiagnostics);
begin
  ReadUBLDocument(InvoiceDocument(AUBL), AInvoice, ADiagnostics);
end;

procedure LandrixEInvoiceUBLCreditNoteToInvoice(AUBL: TLandrixUBLCreditNote; AInvoice: TLandrixInvoice;
  ADiagnostics: TLandrixEInvoiceDiagnostics);
begin
  ReadUBLDocument(CreditNoteDocument(AUBL), AInvoice, ADiagnostics);
end;

end.
