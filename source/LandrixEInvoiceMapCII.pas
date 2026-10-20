{
  EInvoice-for-Pascal

  Copyright (C) 2026 Landrix Software GmbH & Co. KG

  This file is dual-licensed under:
  - GNU GPL version 3 or later; or
  - the Landrix Software Commercial License.

  See LICENSE and COMMERCIAL-LICENSE.md.

  SPDX-License-Identifier: GPL-3.0-or-later OR LicenseRef-Landrix-Commercial
}

{ Mapping between the invoice model (TLandrixInvoice) and the CII syntax
  model (TLandrixCIIInvoice), one method per business group. What a target
  specification allows comes from the rule table (LandrixEInvoiceRules);
  content it forbids is left out and reported (edk_NotAllowed). For a
  Factur-X profile below EXTENDED, LandrixEInvoicePruneCII then removes what
  the profile does not contain. Values are converted with
  LandrixEInvoiceLexical. Totals are taken from the invoice model as they
  are.

  DE: Abbildung zwischen dem Rechnungsmodell (TLandrixInvoice) und dem
  CII-Syntaxmodell (TLandrixCIIInvoice), eine Methode je
  Geschaeftsgruppe. Was eine Zielspezifikation erlaubt, kommt aus der
  Regel-Tabelle (LandrixEInvoiceRules); verbotener Inhalt wird weggelassen
  und gemeldet (edk_NotAllowed). Fuer ein Factur-X-Profil unter EXTENDED
  entfernt LandrixEInvoicePruneCII danach, was das Profil nicht enthaelt.
  Werte werden mit LandrixEInvoiceLexical umgewandelt. Summen werden
  unveraendert aus dem Rechnungsmodell uebernommen. }

unit LandrixEInvoiceMapCII;

{$I LandrixEInvoice.inc}

interface

uses
  LandrixEInvoiceDiagnostics,
  LandrixEInvoiceSpecs,
  LandrixEInvoiceInvoice,
  LandrixEInvoiceCII;

{ Maps AInvoice to a new CII syntax model for ASpec (a CII specification,
  e.g. found with LandrixEInvoiceFindSpec). Diagnostics are added to
  ADiagnostics (nil: discarded). For Factur-X MINIMUM, BASIC WL, BASIC and
  EN16931 the result holds only what the profile contains
  (LandrixEInvoicePruneCII); write it with that profile
  (LandrixEInvoiceWriteCII, AProfile). Raises ELandrixEInvoiceError if
  ASpec is not a CII specification the library can write. The caller frees
  the result.
  DE: Bildet AInvoice auf ein neues CII-Syntaxmodell fuer ASpec ab (eine
  CII-Spezifikation, z. B. mit LandrixEInvoiceFindSpec gefunden). Meldungen
  kommen in ADiagnostics (nil: verworfen). Fuer Factur-X MINIMUM, BASIC WL,
  BASIC und EN16931 enthaelt das Ergebnis nur, was das Profil enthaelt
  (LandrixEInvoicePruneCII); geschrieben wird es mit diesem Profil
  (LandrixEInvoiceWriteCII, AProfile). Loest ELandrixEInvoiceError aus,
  wenn ASpec keine CII-Spezifikation ist, die die Bibliothek schreiben
  kann. Der Aufrufer gibt das Ergebnis frei. }
function LandrixEInvoiceInvoiceToCII(AInvoice: TLandrixInvoice; const ASpec: TLandrixEInvoiceSpec;
  ADiagnostics: TLandrixEInvoiceDiagnostics): TLandrixCIIInvoice;

{ Replaces the content of AInvoice with the content of ACII. What the
  invoice model cannot hold is reported (edk_NotMapped), values that cannot
  be converted too (edk_ConversionFailed, the field stays "not set"),
  unknown codes are kept in the ...Other fields (edk_UnknownCode). ACII is
  not changed.
  DE: Ersetzt den Inhalt von AInvoice durch den Inhalt von ACII. Was das
  Rechnungsmodell nicht aufnehmen kann, wird gemeldet (edk_NotMapped),
  ebenso nicht umwandelbare Werte (edk_ConversionFailed, das Feld bleibt
  "nicht gesetzt"); unbekannte Codes bleiben in den ...Other-Feldern
  (edk_UnknownCode). ACII wird nicht veraendert. }
procedure LandrixEInvoiceCIIToInvoice(ACII: TLandrixCIIInvoice; AInvoice: TLandrixInvoice;
  ADiagnostics: TLandrixEInvoiceDiagnostics);

implementation

uses
  SysUtils,
  Classes,
  Contnrs,
  LandrixEInvoiceTypes,
  LandrixEInvoiceCodes,
  LandrixEInvoiceLexical,
  LandrixEInvoiceRules,
  LandrixEInvoiceCalc,
  LandrixEInvoiceCIIProfiles;

const
  Root = '/rsm:CrossIndustryInvoice';
  Transaction = Root + '/rsm:SupplyChainTradeTransaction';
  Agreement = Transaction + '/ram:ApplicableHeaderTradeAgreement';
  Delivery = Transaction + '/ram:ApplicableHeaderTradeDelivery';
  Settlement = Transaction + '/ram:ApplicableHeaderTradeSettlement';
  LineItem = Transaction + '/ram:IncludedSupplyChainTradeLineItem';

type
  { Role of a TLandrixInvoiceParty; it decides which fields EN 16931 knows.
    DE: Rolle einer TLandrixInvoiceParty; sie bestimmt, welche Felder
    EN 16931 kennt. }
  TFurtherPartyRole = (fpr_Payee, fpr_TaxRepresentative, fpr_Invoicee);

  { Writes one invoice into one CII model. DE: Schreibt eine Rechnung in ein
    CII-Modell. }
  TCIIWriteMapper = class(TObject)
  private
    FInvoice: TLandrixInvoice;
    FSpec: TLandrixEInvoiceSpec;
    FDiagnostics: TLandrixEInvoiceDiagnostics;
    FCII: TLandrixCIIInvoice;
    procedure Report(AKind: TLandrixEInvoiceDiagnosticKind; const APath, AMessage: TLandrixEInvoiceString;
      ASeverity: TLandrixEInvoiceDiagnosticSeverity);
    function Permit(const AKey: string; const APath, AWhat: TLandrixEInvoiceString): Boolean;
    function Code(const AEnumText, AOther, APath: TLandrixEInvoiceString): TLandrixEInvoiceString;
    function UsesExtension: Boolean;
    procedure MapContext;
    procedure MapDocument;
    procedure MapLine(ALine: TLandrixInvoiceLine; const AParentLineID: TLandrixEInvoiceString;
      const APath: TLandrixEInvoiceString);
    procedure MapLineProduct(ALine: TLandrixInvoiceLine; AProduct: TLandrixCIITradeProduct;
      const APath: TLandrixEInvoiceString);
    procedure MapLineAgreement(ALine: TLandrixInvoiceLine; AAgreement: TLandrixCIILineTradeAgreement;
      const APath: TLandrixEInvoiceString);
    procedure MapLineDelivery(ALine: TLandrixInvoiceLine; ADelivery: TLandrixCIILineTradeDelivery;
      const APath: TLandrixEInvoiceString);
    procedure MapLineSettlement(ALine: TLandrixInvoiceLine; AStatus: TLandrixInvoiceLineStatusReasonCode;
      ASettlement: TLandrixCIILineTradeSettlement; const APath: TLandrixEInvoiceString);
    procedure MapAddress(AAddress: TLandrixInvoiceAddress; ATarget: TLandrixCIITradeAddress);
    procedure MapContact(AParty: TLandrixInvoiceAccountingParty; AParty2: TLandrixCIITradeParty;
      const APath: TLandrixEInvoiceString);
    procedure MapElectronicAddress(AParty: TLandrixInvoiceAccountingParty; AParty2: TLandrixCIITradeParty;
      const APath: TLandrixEInvoiceString);
    procedure MapSeller;
    procedure MapBuyer;
    procedure MapFurtherParty(AParty: TLandrixInvoiceParty; ATarget: TLandrixCIITradeParty;
      const APath: TLandrixEInvoiceString; ARole: TFurtherPartyRole);
    procedure MapReferences;
    procedure MapAttachments;
    procedure MapDelivery;
    procedure MapPaymentMeans;
    procedure MapTaxBreakdown;
    procedure MapAllowanceCharges;
    procedure MapPaymentTerms;
    procedure MapStructuredPaymentTerms;
    procedure MapTotals;
    function TotalWanted(const AName: TLandrixEInvoiceString; AValue: Currency): Boolean;
    procedure MapPrecedingInvoices;
    procedure MapThirdPartyPayments;
  public
    constructor Create(AInvoice: TLandrixInvoice; const ASpec: TLandrixEInvoiceSpec;
      ADiagnostics: TLandrixEInvoiceDiagnostics; ACII: TLandrixCIIInvoice);
    procedure Execute;
  end;

{ --- helpers ---------------------------------------------------------------- }

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

function DateSet(AValue: TDateTime): Boolean;
begin
  Result := AValue > 0;
end;

{ Sets an optional date from a read value; 0 (not set or not converted)
  leaves it empty. }
procedure SetDate(var ADate: TLandrixEInvoiceDate; AValue: TDateTime);
begin
  if AValue > 0 then
    ADate.SetValue(AValue);
end;

{ Periods: the invoice model of XRechnung-for-Delphi treats values up to 100
  (the first days of 1900) as "not set". DE: Zeitraeume: Das Rechnungsmodell
  aus XRechnung-for-Delphi behandelt Werte bis 100 (die ersten Tage 1900) als
  "nicht gesetzt". }
function PeriodDateSet(AValue: TDateTime): Boolean;
begin
  Result := AValue > 100;
end;

function CIIDate(AValue: TDateTime): TLandrixCIIDateTime;
begin
  Result.Value := LandrixEInvoiceDateToCII(AValue);
  Result.Format := '102';
end;

function CIIFormattedDate(AValue: TDateTime): TLandrixCIIFormattedDateTime;
begin
  Result.Value := LandrixEInvoiceDateToCII(AValue);
  Result.Format := '102';
end;

function CIIID(const AValue, AScheme: TLandrixEInvoiceString): TLandrixCIIID;
begin
  Result.Value := AValue;
  Result.SchemeID := AScheme;
end;

function CIIAmount(AValue: Currency): TLandrixCIIAmount;
begin
  Result.Value := LandrixEInvoiceAmountToLexical(AValue);
  Result.CurrencyID := '';
end;

function CIIPrice(AValue: Double): TLandrixCIIAmount;
begin
  Result.Value := LandrixEInvoicePriceToLexical(AValue);
  Result.CurrencyID := '';
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

{ Free text: line breaks are written as LF (CR LF and a single CR become
  LF). XML readers normalize raw line breaks to LF anyway; this keeps the
  output the same as that of XRechnung-for-Delphi and avoids CR character
  references in invoices.
  DE: Freitext: Zeilenumbrueche werden als LF geschrieben (CR LF und ein
  einzelnes CR werden zu LF). XML-Leser normalisieren rohe
  Zeilenumbrueche ohnehin zu LF; so bleibt die Ausgabe gleich der von
  XRechnung-for-Delphi, und Rechnungen enthalten keine
  CR-Zeichenreferenzen. }
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

function IntText(AValue: Integer): TLandrixEInvoiceString;
begin
  Result := TLandrixEInvoiceString(IntToStr(AValue));
end;

{ --- TCIIWriteMapper ---------------------------------------------------------- }

constructor TCIIWriteMapper.Create(AInvoice: TLandrixInvoice; const ASpec: TLandrixEInvoiceSpec;
  ADiagnostics: TLandrixEInvoiceDiagnostics; ACII: TLandrixCIIInvoice);
begin
  inherited Create;
  FInvoice := AInvoice;
  FSpec := ASpec;
  FDiagnostics := ADiagnostics;
  FCII := ACII;
end;

procedure TCIIWriteMapper.Report(AKind: TLandrixEInvoiceDiagnosticKind;
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
function TCIIWriteMapper.Permit(const AKey: string; const APath, AWhat: TLandrixEInvoiceString): Boolean;
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
function TCIIWriteMapper.Code(const AEnumText, AOther, APath: TLandrixEInvoiceString): TLandrixEInvoiceString;
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

procedure TCIIWriteMapper.Execute;
var
  I: TLandrixEInvoiceListIndex;
begin
  MapContext;
  MapDocument;
  for I := 0 to FInvoice.InvoiceLines.Count - 1 do
    MapLine(FInvoice.InvoiceLines[I], '', LineItem);
  MapSeller;
  MapBuyer;
  MapFurtherParty(FInvoice.TaxRepresentativeParty,
    FCII.SupplyChainTradeTransaction.ApplicableHeaderTradeAgreement.SellerTaxRepresentativeTradeParty,
    Agreement + '/ram:SellerTaxRepresentativeTradeParty', fpr_TaxRepresentative);
  MapReferences;
  MapAttachments;
  MapDelivery;
  MapFurtherParty(FInvoice.InvoiceeParty,
    FCII.SupplyChainTradeTransaction.ApplicableHeaderTradeSettlement.InvoiceeTradeParty,
    Settlement + '/ram:InvoiceeTradeParty', fpr_Invoicee);
  MapFurtherParty(FInvoice.PayeeParty,
    FCII.SupplyChainTradeTransaction.ApplicableHeaderTradeSettlement.PayeeTradeParty,
    Settlement + '/ram:PayeeTradeParty', fpr_Payee);
  MapPaymentMeans;
  MapTaxBreakdown;
  MapAllowanceCharges;
  if LandrixEInvoiceRuleLevel(FSpec, LandrixEInvoiceRuleStructuredPaymentTerms) = erl_Forbidden then
    MapPaymentTerms
  else
    MapStructuredPaymentTerms;
  MapTotals;
  MapPrecedingInvoices;
  MapThirdPartyPayments;
end;

{ BT-X-1 test indicator (EXTENDED), BT-23 business process, BT-24
  specification identifier (with the extension when used).
  DE: BT-X-1 Testkennzeichen (EXTENDED), BT-23 Geschaeftsprozess, BT-24
  Spezifikationskennung (mit Extension, wenn verwendet). }
procedure TCIIWriteMapper.MapContext;
var
  Context: TLandrixCIIExchangedDocumentContext;
begin
  Context := FCII.ExchangedDocumentContext;
  if FInvoice.TestIndicator.HasValue and
     Permit(LandrixEInvoiceRuleTestIndicator, Root + '/rsm:ExchangedDocumentContext/ram:TestIndicator',
       'test indicator') then
    Context.TestIndicator := BoolText(FInvoice.TestIndicator.Value);
  if Present(FInvoice.ProfileID) then
    Context.BusinessProcessSpecifiedDocumentContextParameter.ID.Value := FInvoice.ProfileID
  else
    Context.BusinessProcessSpecifiedDocumentContextParameter.ID.Value := FSpec.ProfileID;
  if UsesExtension then
    Context.GuidelineSpecifiedDocumentContextParameter.ID.Value := FSpec.ExtensionCustomizationID
  else
    Context.GuidelineSpecifiedDocumentContextParameter.ID.Value := FSpec.CustomizationID;
end;

{ XRechnung extension codes XR01 to XR03 as identifier schemes.
  DE: Extension-Codes XR01 bis XR03 als Kennungsschema. }
function IsExtensionScheme(const AValue, AScheme: TLandrixEInvoiceString): Boolean;
begin
  Result := Present(AValue) and (SameAscii(AScheme, 'XR01') or SameAscii(AScheme, 'XR02') or
    SameAscii(AScheme, 'XR03'));
end;

{ The XRechnung extension is declared only when the invoice has content the
  extension allows in CII: embedded XML attachments (BR-DEX-01) or the
  extension codes XR01 to XR03 as scheme of BT-34, BT-49, BT-29, BT-46 or
  BT-71 (BR-DEX-04 to 08). Sub lines (BR-DEX-15) and third-party payments
  exist in the extension of UBL only. Unlike UBL a credit note may use it:
  KoSIT selects the CII extension scenario by the identifier alone.
  DE: Die XRechnung-Extension wird nur deklariert, wenn die Rechnung Inhalt
  hat, den die Extension in CII erlaubt: eingebettete XML-Anhaenge
  (BR-DEX-01) oder die Extension-Codes XR01 bis XR03 als Schema von BT-34,
  BT-49, BT-29, BT-46 oder BT-71 (BR-DEX-04 bis 08). Unterpositionen
  (BR-DEX-15) und Zahlungen Dritter gibt es nur in der Extension von UBL.
  Anders als in UBL darf auch eine Gutschrift sie verwenden: KoSIT waehlt
  das CII-Extension-Szenario allein nach der Kennung. }
function TCIIWriteMapper.UsesExtension: Boolean;
var
  I: TLandrixEInvoiceListIndex;
begin
  Result := False;
  if Blank(FSpec.ExtensionCustomizationID) then
    Exit;
  Result := True;
  for I := 0 to FInvoice.Attachments.Count - 1 do
    if FInvoice.Attachments[I].ContainsBinaryObject and
       (FInvoice.Attachments[I].AttachmentType = iat_application_xml) then
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
       FInvoice.DeliveryInformation.LocationIdentifierSchemeID) then
    Exit;
  Result := False;
end;

{ BT-1 number, BT-X-2 document name (EXTENDED), BT-3 type, BT-2 issue date,
  BG-1 notes.
  DE: BT-1 Nummer, BT-X-2 Dokumentname (EXTENDED), BT-3 Art, BT-2
  Rechnungsdatum, BG-1 Bemerkungen. }
procedure TCIIWriteMapper.MapDocument;
var
  Doc: TLandrixCIIExchangedDocument;
  Note: TLandrixCIINote;
  I: TLandrixEInvoiceListIndex;
begin
  Doc := FCII.ExchangedDocument;
  Doc.ID.Value := FInvoice.InvoiceNumber;
  if Present(FInvoice.DocumentName) and
     Permit(LandrixEInvoiceRuleDocumentName, Root + '/rsm:ExchangedDocument/ram:Name', 'document name') then
    Doc.Name := Txt(FInvoice.DocumentName);
  Doc.TypeCode := Code(LandrixEInvoiceTypeCodeToStr(FInvoice.InvoiceTypeCode), FInvoice.InvoiceTypeCodeOther,
    Root + '/rsm:ExchangedDocument/ram:TypeCode');
  if DateSet(FInvoice.InvoiceIssueDate) then
    Doc.IssueDateTime := CIIDate(FInvoice.InvoiceIssueDate);
  for I := 0 to FInvoice.Notes.Count - 1 do
  begin
    { BG-1 needs its text (BT-22); a blank note is no note.
      DE: BG-1 braucht seinen Text (BT-22); eine leere Bemerkung ist keine. }
    if Blank(FInvoice.Notes[I].Content) then
      Continue;
    Note := Doc.IncludedNote.Add;
    Note.Content := Txt(FInvoice.Notes[I].Content);
    Note.SubjectCode.Value := Code(LandrixEInvoiceNoteSubjectCodeToStr(FInvoice.Notes[I].SubjectCode),
      FInvoice.Notes[I].SubjectCodeOther, Root + '/rsm:ExchangedDocument/ram:IncludedNote/ram:SubjectCode');
  end;
end;

{ BG-25 invoice line. CII does not nest lines: a sub line (BG-DEX-01) refers
  to its parent line (BT-X-304) and carries a line status (BT-X-8), only in
  Factur-X EXTENDED; the lines are written depth-first after their parent.
  DE: BG-25 Rechnungsposition. CII schachtelt keine Positionen: eine
  Unterposition (BG-DEX-01) verweist auf ihre Oberposition (BT-X-304) und
  traegt einen Positionsstatus (BT-X-8), nur in Factur-X EXTENDED; die
  Positionen werden der Tiefe nach hinter ihre Oberposition geschrieben. }
procedure TCIIWriteMapper.MapLine(ALine: TLandrixInvoiceLine;
  const AParentLineID: TLandrixEInvoiceString; const APath: TLandrixEInvoiceString);
var
  Item: TLandrixCIISupplyChainTradeLineItem;
  Status: TLandrixInvoiceLineStatusReasonCode;
  SubLinesAllowed: Boolean;
  I: TLandrixEInvoiceListIndex;
begin
  SubLinesAllowed := LandrixEInvoiceRuleLevel(FSpec, LandrixEInvoiceRuleLineSubLines) <> erl_Forbidden;
  Status := LandrixEInvoiceLineStatusOf(ALine, AParentLineID <> '');
  Item := FCII.SupplyChainTradeTransaction.IncludedSupplyChainTradeLineItem.Add;
  Item.AssociatedDocumentLineDocument.LineID.Value := ALine.ID;
  if SubLinesAllowed then
  begin
    Item.AssociatedDocumentLineDocument.ParentLineID.Value := AParentLineID;
    Item.AssociatedDocumentLineDocument.LineStatusReasonCode.Value :=
      Code(LandrixEInvoiceLineStatusReasonCodeToStr(Status), ALine.LineStatusReasonCodeOther,
      APath + '/ram:AssociatedDocumentLineDocument/ram:LineStatusReasonCode');
  end
  else if (ALine.LineStatusReasonCode <> ilsrc_None) or Present(ALine.LineStatusReasonCodeOther) then
    Permit(LandrixEInvoiceRuleLineSubLines, APath + '/ram:AssociatedDocumentLineDocument/ram:LineStatusReasonCode',
      'line status (BT-X-8) of line ' + ALine.ID);
  if Present(ALine.Note) then
    Item.AssociatedDocumentLineDocument.IncludedNote.Add.Content := Txt(ALine.Note);
  MapLineProduct(ALine, Item.SpecifiedTradeProduct, APath + '/ram:SpecifiedTradeProduct');
  MapLineAgreement(ALine, Item.SpecifiedLineTradeAgreement, APath + '/ram:SpecifiedLineTradeAgreement');
  MapLineDelivery(ALine, Item.SpecifiedLineTradeDelivery, APath + '/ram:SpecifiedLineTradeDelivery');
  MapLineSettlement(ALine, Status, Item.SpecifiedLineTradeSettlement, APath + '/ram:SpecifiedLineTradeSettlement');
  if ALine.SubInvoiceLines.Count = 0 then
    Exit;
  if not Permit(LandrixEInvoiceRuleLineSubLines, APath, 'sub lines of line ' + ALine.ID) then
    Exit;
  for I := 0 to ALine.SubInvoiceLines.Count - 1 do
    MapLine(ALine.SubInvoiceLines[I], ALine.ID, APath);
end;

{ BG-31 item information: BT-157 standard identifier (see
  StandardItemIdentifierOf), BT-155/BT-156 identifiers, BT-153 name, BT-154
  description, BG-32 attributes, BT-158 classifications (BR-65: only with a
  scheme), BT-159 country of origin.
  DE: BG-31 Artikelinformationen: BT-157 Standardkennung (siehe
  StandardItemIdentifierOf), BT-155/BT-156 Kennungen, BT-153 Name, BT-154
  Beschreibung, BG-32 Eigenschaften, BT-158 Klassifizierungen (BR-65: nur
  mit Schema), BT-159 Herkunftsland. }
procedure TCIIWriteMapper.MapLineProduct(ALine: TLandrixInvoiceLine; AProduct: TLandrixCIITradeProduct;
  const APath: TLandrixEInvoiceString);
var
  I: TLandrixEInvoiceListIndex;
  Classification: TLandrixInvoiceLineItemClassification;
  Target: TLandrixCIIProductClassification;
  Characteristic: TLandrixCIIProductCharacteristic;
  Value, Scheme, Conflict: TLandrixEInvoiceString;
begin
  if LandrixEInvoiceStandardItemIdentifierOf(ALine, Value, Scheme, Conflict) then
  begin
    AProduct.GlobalID := CIIID(Value, Scheme);
    if Blank(Scheme) then
      Report(edk_MissingElement, APath + '/ram:GlobalID/@schemeID', 'item standard identifier ' + Value +
        ' of line ' + ALine.ID + ' without scheme (BR-64)', eds_Error);
    if Present(Conflict) then
      Report(edk_NotAllowed, APath + '/ram:GlobalID', Conflict, eds_Warning);
  end;
  AProduct.SellerAssignedID.Value := ALine.SellersItemIdentification;
  AProduct.BuyerAssignedID.Value := ALine.BuyersItemIdentification;
  AProduct.Name := Txt(ALine.Name);
  AProduct.Description := Txt(ALine.Description);
  for I := 0 to ALine.ItemAttributes.Count - 1 do
  begin
    Characteristic := AProduct.ApplicableProductCharacteristic.Add;
    Characteristic.Description := Txt(ALine.ItemAttributes[I].Name);
    Characteristic.Value := Txt(ALine.ItemAttributes[I].Value);
  end;
  for I := 0 to ALine.ItemClassifications.Count - 1 do
  begin
    Classification := ALine.ItemClassifications[I];
    if Blank(Classification.ClassCode) then
      Continue;
    if Blank(Classification.ListID) then
    begin
      Report(edk_NotAllowed, APath + '/ram:DesignatedProductClassification',
        'item classification ' + Classification.ClassCode + ' without scheme (BR-65); left out', eds_Warning);
      Continue;
    end;
    Target := AProduct.DesignatedProductClassification.Add;
    Target.ClassCode.Value := Classification.ClassCode;
    Target.ClassCode.ListID := Classification.ListID;
    Target.ClassCode.ListVersionID := Classification.ListVersionID;
    if Present(Classification.ClassificationName) and
       Permit(LandrixEInvoiceRuleLineClassificationName, APath + '/ram:DesignatedProductClassification/ram:ClassName',
         'classification name of line ' + ALine.ID) then
      Target.ClassificationName := Classification.ClassificationName;
  end;
  AProduct.OriginTradeCountry.ID := ALine.OriginTradeCountry;
end;

{ BT-132 order line reference, BT-X-21 order number (EXTENDED), BT-148
  gross price with BT-147 discount, BT-146 net price, BT-149/BT-150 base
  quantity.
  DE: BT-132 Bestellpositionsreferenz, BT-X-21 Bestellnummer (EXTENDED),
  BT-148 Bruttopreis mit BT-147 Rabatt, BT-146 Nettopreis, BT-149/BT-150
  Basismenge. }
procedure TCIIWriteMapper.MapLineAgreement(ALine: TLandrixInvoiceLine; AAgreement: TLandrixCIILineTradeAgreement;
  const APath: TLandrixEInvoiceString);
var
  BaseQuantity: TLandrixCIIQuantity;
  HasBaseQuantity: Boolean;
  Discount: TLandrixCIITradeAllowanceCharge;
begin
  if Present(ALine.OrderNumber) and
     Permit(LandrixEInvoiceRuleLineOrderNumber, APath + '/ram:BuyerOrderReferencedDocument/ram:IssuerAssignedID',
       'order number of line ' + ALine.ID) then
    AAgreement.BuyerOrderReferencedDocument.IssuerAssignedID.Value := ALine.OrderNumber;
  AAgreement.BuyerOrderReferencedDocument.LineID.Value := ALine.OrderLineReference;
  if ALine.OrderDate.HasValue and
     Permit(LandrixEInvoiceRuleLineOrderDate, APath + '/ram:BuyerOrderReferencedDocument/ram:FormattedIssueDateTime',
       'order date of line ' + ALine.ID) then
    AAgreement.BuyerOrderReferencedDocument.FormattedIssueDateTime := CIIFormattedDate(ALine.OrderDate.Value);
  { BT-150 is optional }
  HasBaseQuantity := ALine.BaseQuantity <> 0;
  if HasBaseQuantity then
  begin
    BaseQuantity.Value := LandrixEInvoiceBaseQuantityToLexical(ALine.BaseQuantity);
    BaseQuantity.UnitCode := Code(LandrixEInvoiceUnitCodeToStr(ALine.BaseQuantityUnitCode),
      ALine.BaseQuantityUnitCodeOther, APath + '/ram:NetPriceProductTradePrice/ram:BasisQuantity');
  end;
  if ALine.GrossPriceAmount <> 0 then
  begin
    AAgreement.GrossPriceProductTradePrice.ChargeAmount := CIIPrice(ALine.GrossPriceAmount);
    if HasBaseQuantity then
      AAgreement.GrossPriceProductTradePrice.BasisQuantity := BaseQuantity;
    { the discount is written also when it is 0 }
    Discount := AAgreement.GrossPriceProductTradePrice.AppliedTradeAllowanceCharge.Add;
    Discount.ChargeIndicator := 'false';
    Discount.ActualAmount := CIIPrice(ALine.DiscountOnTheGrossPrice);
  end;
  AAgreement.NetPriceProductTradePrice.ChargeAmount := CIIPrice(ALine.NetPriceAmount);
  if HasBaseQuantity then
    AAgreement.NetPriceProductTradePrice.BasisQuantity := BaseQuantity;
end;

{ BT-129/BT-130 invoiced quantity; EXTENDED only: BT-X-85 delivery date and
  BG-X-83 delivery note (BT-X-92 to BT-X-94).
  DE: BT-129/BT-130 berechnete Menge; nur EXTENDED: BT-X-85 Lieferdatum und
  BG-X-83 Lieferschein (BT-X-92 bis BT-X-94). }
procedure TCIIWriteMapper.MapLineDelivery(ALine: TLandrixInvoiceLine; ADelivery: TLandrixCIILineTradeDelivery;
  const APath: TLandrixEInvoiceString);
begin
  ADelivery.BilledQuantity.Value := LandrixEInvoiceQuantityToLexical(ALine.Quantity);
  ADelivery.BilledQuantity.UnitCode := Code(LandrixEInvoiceUnitCodeToStr(ALine.UnitCode), ALine.UnitCodeOther,
    APath + '/ram:BilledQuantity');
  if not (DateSet(ALine.ActualDeliveryDate) or Present(ALine.DeliveryNoteNumber)) then
    Exit;
  if not Permit(LandrixEInvoiceRuleLineDelivery, APath, 'delivery data of line ' + ALine.ID) then
    Exit;
  if DateSet(ALine.ActualDeliveryDate) then
    ADelivery.ActualDeliverySupplyChainEvent.OccurrenceDateTime := CIIDate(ALine.ActualDeliveryDate);
  if Present(ALine.DeliveryNoteNumber) then
  begin
    ADelivery.DeliveryNoteReferencedDocument.IssuerAssignedID.Value := ALine.DeliveryNoteNumber;
    ADelivery.DeliveryNoteReferencedDocument.LineID.Value := ALine.DeliveryNoteLineID;
    if DateSet(ALine.DeliveryNoteDate) then
      ADelivery.DeliveryNoteReferencedDocument.FormattedIssueDateTime := CIIFormattedDate(ALine.DeliveryNoteDate);
  end;
end;

{ BG-30 line VAT, BG-26 line period, BG-27/BG-28 line allowances and
  charges, BT-131 line net amount, BT-128 object identifier, BT-133 buyer
  accounting reference. Group and information lines of EXTENDED may stay
  without VAT category (BR-FXEXT-CO-04 applies to detail lines only).
  DE: BG-30 Umsatzsteuer der Position, BG-26 Abrechnungszeitraum, BG-27/
  BG-28 Nachlaesse und Zuschlaege, BT-131 Nettobetrag, BT-128
  Objektkennung, BT-133 Buchungsreferenz des Kaeufers. Gruppen- und
  Informationspositionen in EXTENDED duerfen ohne Steuerkategorie bleiben
  (BR-FXEXT-CO-04 gilt nur fuer Detailpositionen). }
procedure TCIIWriteMapper.MapLineSettlement(ALine: TLandrixInvoiceLine; AStatus: TLandrixInvoiceLineStatusReasonCode;
  ASettlement: TLandrixCIILineTradeSettlement; const APath: TLandrixEInvoiceString);
var
  Tax: TLandrixCIITradeTax;
  Charge: TLandrixCIITradeAllowanceCharge;
  Item: TLandrixInvoiceAllowanceCharge;
  Document: TLandrixCIIReferencedDocument;
  ReasonText, ReasonOther: TLandrixEInvoiceString;
  I: TLandrixEInvoiceListIndex;
begin
  if not ((AStatus in [ilsrc_Group, ilsrc_Information]) and (ALine.TaxCategory = idtfcc_None) and
     Blank(ALine.TaxCategoryOther) and
     (LandrixEInvoiceRuleLevel(FSpec, LandrixEInvoiceRuleLineSubLines) <> erl_Forbidden)) then
  begin
    Tax := ASettlement.ApplicableTradeTax.Add;
    Tax.TypeCode := 'VAT';
    if Present(ALine.TaxExemptionReason) and
       Permit(LandrixEInvoiceRuleLineTaxExemptionReason, APath + '/ram:ApplicableTradeTax/ram:ExemptionReason',
         'VAT exemption reason of line ' + ALine.ID) then
      Tax.ExemptionReason := Txt(ALine.TaxExemptionReason);
    Tax.CategoryCode := Code(LandrixEInvoiceDutyTaxFeeCategoryCodeToStr(ALine.TaxCategory), ALine.TaxCategoryOther,
      APath + '/ram:ApplicableTradeTax/ram:CategoryCode');
    if ALine.TaxCategory <> idtfcc_O_ServicesOutsideScopeOfTax then
      Tax.RateApplicablePercent := LandrixEInvoicePercentToLexical(ALine.TaxPercent);
  end;
  if (PeriodDateSet(ALine.InvoiceLinePeriodStartDate) or PeriodDateSet(ALine.InvoiceLinePeriodEndDate)) and
     (not PeriodDateSet(ALine.InvoiceLinePeriodStartDate) or not PeriodDateSet(ALine.InvoiceLinePeriodEndDate) or
      (ALine.InvoiceLinePeriodEndDate >= ALine.InvoiceLinePeriodStartDate)) then
  begin
    if PeriodDateSet(ALine.InvoiceLinePeriodStartDate) then
      ASettlement.BillingSpecifiedPeriod.StartDateTime := CIIDate(ALine.InvoiceLinePeriodStartDate);
    if PeriodDateSet(ALine.InvoiceLinePeriodEndDate) then
      ASettlement.BillingSpecifiedPeriod.EndDateTime := CIIDate(ALine.InvoiceLinePeriodEndDate);
  end;
  for I := 0 to ALine.AllowanceCharges.Count - 1 do
  begin
    Item := ALine.AllowanceCharges[I];
    Charge := ASettlement.SpecifiedTradeAllowanceCharge.Add;
    Charge.ChargeIndicator := BoolText(Item.ChargeIndicator);
    if Item.MultiplierFactorNumeric <> 0 then
      Charge.CalculationPercent := LandrixEInvoiceDecimalToLexical(Item.MultiplierFactorNumeric, 4);
    { BT-137 also without BT-138, as on document level
      DE: BT-137 auch ohne BT-138, wie auf Dokumentebene }
    if (Item.MultiplierFactorNumeric <> 0) or (Item.BaseAmount <> 0) then
      Charge.BasisAmount := CIIAmount(Item.BaseAmount);
    Charge.ActualAmount := CIIAmount(Item.Amount);
    ReasonText := AllowanceReasonCode(Item, ReasonOther);
    Charge.ReasonCode.Value := Code(ReasonText, ReasonOther,
      APath + '/ram:SpecifiedTradeAllowanceCharge/ram:ReasonCode');
    Charge.Reason := Txt(Item.Reason);
  end;
  ASettlement.SpecifiedTradeSettlementLineMonetarySummation.LineTotalAmount := CIIAmount(ALine.LineAmount);
  if Present(ALine.ObjectIdentifier) then
  begin
    Document := ASettlement.AdditionalReferencedDocument.Add;
    Document.IssuerAssignedID.Value := ALine.ObjectIdentifier;
    Document.TypeCode := '130';
    Document.ReferenceTypeCode := ALine.ObjectIdentifierSchemeID;
  end;
  if Present(ALine.BuyerAccountingReference) then
    ASettlement.ReceivableSpecifiedTradeAccountingAccount.Add.ID.Value := ALine.BuyerAccountingReference;
end;

procedure TCIIWriteMapper.MapAddress(AAddress: TLandrixInvoiceAddress; ATarget: TLandrixCIITradeAddress);
begin
  ATarget.PostcodeCode.Value := AAddress.PostalZone;
  ATarget.LineOne := AAddress.StreetName;
  ATarget.LineTwo := AAddress.AdditionalStreetName;
  ATarget.LineThree := AAddress.AddressLine;
  ATarget.CityName := AAddress.City;
  ATarget.CountryID := AAddress.CountryCode;
  ATarget.CountrySubDivisionName := AAddress.CountrySubentity;
end;

{ BG-6/BG-9 contact: BT-41/BT-56 as person name or, without one, as
  department (CII-SR-465/466 allow only one of both), BT-42/BT-57,
  BT-43/BT-58.
  DE: BG-6/BG-9 Kontakt: BT-41/BT-56 als Personenname oder, ohne diesen,
  als Abteilung (CII-SR-465/466 erlauben nur eines von beiden),
  BT-42/BT-57, BT-43/BT-58. }
procedure TCIIWriteMapper.MapContact(AParty: TLandrixInvoiceAccountingParty; AParty2: TLandrixCIITradeParty;
  const APath: TLandrixEInvoiceString);
var
  Contact: TLandrixCIITradeContact;
begin
  if Blank(AParty.ContactName) and Blank(AParty.ContactDepartment) and Blank(AParty.ContactTelephone) and
     Blank(AParty.ContactElectronicMail) then
    Exit;
  Contact := AParty2.DefinedTradeContact.Add;
  Contact.PersonName := AParty.ContactName;
  if Blank(AParty.ContactName) then
    Contact.DepartmentName := AParty.ContactDepartment
  else if Present(AParty.ContactDepartment) then
    Report(edk_NotAllowed, APath + '/ram:DefinedTradeContact/ram:DepartmentName', 'contact department ' +
      AParty.ContactDepartment + ' left out: CII allows a person name or a department (CII-SR-465, CII-SR-466)',
      eds_Warning);
  Contact.TelephoneUniversalCommunication.CompleteNumber := AParty.ContactTelephone;
  Contact.EmailURIUniversalCommunication.URIID.Value := AParty.ContactElectronicMail;
end;

{ BT-34/BT-49 electronic address; without scheme the default 'EM' is used
  where the specification allows it.
  DE: BT-34/BT-49 elektronische Adresse; ohne Schema gilt 'EM', wo die
  Spezifikation es erlaubt. }
procedure TCIIWriteMapper.MapElectronicAddress(AParty: TLandrixInvoiceAccountingParty;
  AParty2: TLandrixCIITradeParty; const APath: TLandrixEInvoiceString);
var
  Scheme: TLandrixEInvoiceString;
begin
  if Blank(AParty.ElectronicAddressSellerBuyer) then
    Exit;
  Scheme := AParty.ElectronicAddressSellerBuyerSchemeID;
  if Blank(Scheme) and (LandrixEInvoiceRuleLevel(FSpec, LandrixEInvoiceRuleElectronicAddressDefaultEM) <> erl_Forbidden) then
    Scheme := 'EM';
  AParty2.URIUniversalCommunication.URIID := CIIID(AParty.ElectronicAddressSellerBuyer, Scheme);
  if Blank(Scheme) then
    Report(edk_MissingElement, APath + '/ram:URIUniversalCommunication/ram:URIID/@schemeID',
      'electronic address without scheme', eds_Error);
end;

{ BG-4 seller: BT-29 identifier, BT-29 global identifier (default scheme
  0088), BT-27 name, BT-33 additional legal information, BT-30/BT-28 legal
  registration and trading name, BG-6 contact, BG-5 address, BT-34
  electronic address, BT-31/BT-32 VAT and tax registration.
  DE: BG-4 Verkaeufer: BT-29 Kennung, BT-29 globale Kennung (Vorgabeschema
  0088), BT-27 Name, BT-33 weitere rechtliche Informationen, BT-30/BT-28
  Registernummer und Handelsname, BG-6 Kontakt, BG-5 Anschrift, BT-34
  elektronische Adresse, BT-31/BT-32 USt-IdNr. und Steuernummer. }
procedure TCIIWriteMapper.MapSeller;
var
  Party: TLandrixInvoiceAccountingParty;
  Target: TLandrixCIITradeParty;
  Scheme: TLandrixEInvoiceString;
begin
  Party := FInvoice.AccountingSupplierParty;
  Target := FCII.SupplyChainTradeTransaction.ApplicableHeaderTradeAgreement.SellerTradeParty;
  if Present(Party.IdentifierSellerBuyer) then
    Target.ID.Add(CIIID(Party.IdentifierSellerBuyer, ''));
  if Present(Party.GlobalIdentifierSellerBuyer) then
  begin
    Scheme := Party.GlobalIdentifierSellerBuyerSchemeID;
    if Blank(Scheme) then
      Scheme := '0088';
    Target.GlobalID.Add(CIIID(Party.GlobalIdentifierSellerBuyer, Scheme));
  end;
  Target.Name := Txt(Party.RegistrationName);
  Target.Description := Txt(Party.AdditionalLegalInformationSeller);
  if Present(Party.CompanyID) then
    Target.SpecifiedLegalOrganization.ID := CIIID(Party.CompanyID, Party.CompanyIDSchemeID);
  Target.SpecifiedLegalOrganization.TradingBusinessName := Txt(Party.Name);
  MapContact(Party, Target, Agreement + '/ram:SellerTradeParty');
  MapAddress(Party.Address, Target.PostalTradeAddress);
  MapElectronicAddress(Party, Target, Agreement + '/ram:SellerTradeParty');
  if Present(Party.VATCompanyID) then
    Target.SpecifiedTaxRegistration.Add.ID := CIIID(Party.VATCompanyID, 'VA');
  if Present(Party.VATCompanyNumber) then
    Target.SpecifiedTaxRegistration.Add.ID := CIIID(Party.VATCompanyNumber, 'FC');
end;

{ BG-7 buyer. BT-46 only once (CII-SR-450): the global identifier wins over
  the identifier, both only in EXTENDED. Only one VAT registration: the VAT
  identifier wins over the tax number.
  DE: BG-7 Kaeufer. BT-46 nur einmal (CII-SR-450): die globale Kennung
  gewinnt gegen die Kennung, beide nur in EXTENDED. Nur eine
  Steuerregistrierung: die USt-IdNr. gewinnt gegen die Steuernummer. }
procedure TCIIWriteMapper.MapBuyer;
var
  Party: TLandrixInvoiceAccountingParty;
  Target: TLandrixCIITradeParty;
  Scheme: TLandrixEInvoiceString;
begin
  Party := FInvoice.AccountingCustomerParty;
  Target := FCII.SupplyChainTradeTransaction.ApplicableHeaderTradeAgreement.BuyerTradeParty;
  if Present(Party.IdentifierSellerBuyer) then
  begin
    if Blank(Party.GlobalIdentifierSellerBuyer) then
      Target.ID.Add(CIIID(Party.IdentifierSellerBuyer, ''))
    else if LandrixEInvoiceRuleLevel(FSpec, LandrixEInvoiceRuleBuyerIDWithGlobalID) <> erl_Forbidden then
      Target.ID.Add(CIIID(Party.IdentifierSellerBuyer, ''))
    else
      Report(edk_NotAllowed, Agreement + '/ram:BuyerTradeParty/ram:ID',
        'buyer identifier left out, the global identifier is written (BT-46 only once, CII-SR-450)', eds_Warning);
  end;
  if Present(Party.GlobalIdentifierSellerBuyer) then
  begin
    Scheme := Party.GlobalIdentifierSellerBuyerSchemeID;
    if Blank(Scheme) then
      Scheme := '0088';
    Target.GlobalID.Add(CIIID(Party.GlobalIdentifierSellerBuyer, Scheme));
  end;
  Target.Name := Txt(Party.RegistrationName);
  if Present(Party.CompanyID) then
    Target.SpecifiedLegalOrganization.ID := CIIID(Party.CompanyID, Party.CompanyIDSchemeID);
  Target.SpecifiedLegalOrganization.TradingBusinessName := Txt(Party.Name);
  MapContact(Party, Target, Agreement + '/ram:BuyerTradeParty');
  MapAddress(Party.Address, Target.PostalTradeAddress);
  MapElectronicAddress(Party, Target, Agreement + '/ram:BuyerTradeParty');
  if Present(Party.VATCompanyID) then
    Target.SpecifiedTaxRegistration.Add.ID := CIIID(Party.VATCompanyID, 'VA')
  else if Present(Party.VATCompanyNumber) then
    Target.SpecifiedTaxRegistration.Add.ID := CIIID(Party.VATCompanyNumber, 'FC');
end;

{ BG-10 payee (BT-59 name, BT-60 identifier, BT-61 legal registration),
  BG-11 seller tax representative (BT-62 name, BG-12 address, BT-63 VAT
  identifier) and BG-X-36 invoicee. EN 16931 knows only these fields; the
  rest of a payee or tax representative (and the invoicee as a whole) is
  written in EXTENDED only. An identifier with scheme is a global
  identifier.
  DE: BG-10 Zahlungsempfaenger (BT-59 Name, BT-60 Kennung, BT-61
  Registernummer), BG-11 Steuervertreter des Verkaeufers (BT-62 Name, BG-12
  Anschrift, BT-63 USt-IdNr.) und BG-X-36 Rechnungsempfaenger. EN 16931
  kennt nur diese Felder; der Rest eines Zahlungsempfaengers oder
  Steuervertreters (und der Rechnungsempfaenger insgesamt) wird nur in
  EXTENDED geschrieben. Eine Kennung mit Schema ist eine globale Kennung. }
procedure TCIIWriteMapper.MapFurtherParty(AParty: TLandrixInvoiceParty; ATarget: TLandrixCIITradeParty;
  const APath: TLandrixEInvoiceString; ARole: TFurtherPartyRole);
var
  HasContact, HasExtra, Full: Boolean;
  Contact: TLandrixCIITradeContact;
begin
  if AParty.IsEmpty then
    Exit;
  HasContact := Present(AParty.ContactName) or Present(AParty.ContactDepartment) or
    Present(AParty.ContactTelephone) or Present(AParty.ContactElectronicMail);
  case ARole of
    fpr_Payee:
      begin
        HasExtra := HasContact or AddressSet(AParty.Address) or Present(AParty.VATCompanyID);
        Full := HasExtra and Permit(LandrixEInvoiceRulePayeeExtended, APath,
          'address, contact or VAT identifier of the payee');
      end;
    fpr_TaxRepresentative:
      begin
        HasExtra := HasContact or Present(AParty.Identifier) or Present(AParty.CompanyID);
        Full := HasExtra and Permit(LandrixEInvoiceRuleTaxRepresentativeExtended, APath,
          'identifier or contact of the tax representative');
      end;
  else
    begin
      if not Permit(LandrixEInvoiceRuleInvoicee, APath, 'invoicee') then
        Exit;
      Full := True;
    end;
  end;
  if (ARole <> fpr_TaxRepresentative) or Full then
  begin
    if Present(AParty.Identifier) then
    begin
      if Blank(AParty.IdentifierSchemeID) then
        ATarget.ID.Add(CIIID(AParty.Identifier, ''))
      else
        ATarget.GlobalID.Add(CIIID(AParty.Identifier, AParty.IdentifierSchemeID));
    end;
    if Present(AParty.CompanyID) then
      ATarget.SpecifiedLegalOrganization.ID := CIIID(AParty.CompanyID, AParty.CompanyIDSchemeID);
  end;
  ATarget.Name := Txt(AParty.Name);
  if Full and HasContact then
  begin
    Contact := ATarget.DefinedTradeContact.Add;
    Contact.PersonName := AParty.ContactName;
    Contact.DepartmentName := AParty.ContactDepartment;
    Contact.TelephoneUniversalCommunication.CompleteNumber := AParty.ContactTelephone;
    Contact.EmailURIUniversalCommunication.URIID.Value := AParty.ContactElectronicMail;
  end;
  if ((ARole <> fpr_Payee) or Full) and AddressSet(AParty.Address) then
    MapAddress(AParty.Address, ATarget.PostalTradeAddress);
  if ((ARole <> fpr_Payee) or Full) and Present(AParty.VATCompanyID) then
    ATarget.SpecifiedTaxRegistration.Add.ID := CIIID(AParty.VATCompanyID, 'VA');
end;

{ BT-10 buyer reference (the placeholder 'non-existent' only for XRechnung),
  BT-14 sales order, BT-13 purchase order, BT-12 contract, BT-11 project.
  DE: BT-10 Kaeuferreferenz (der Platzhalter 'non-existent' nur fuer
  XRechnung), BT-14 Auftrag, BT-13 Bestellung, BT-12 Vertrag, BT-11
  Projekt. }
procedure TCIIWriteMapper.MapReferences;
var
  Target: TLandrixCIIHeaderTradeAgreement;
begin
  Target := FCII.SupplyChainTradeTransaction.ApplicableHeaderTradeAgreement;
  if SameAscii(FInvoice.BuyerReference, LandrixEInvoiceLeitwegIDNonExistent) and
    (LandrixEInvoiceRuleLevel(FSpec, LandrixEInvoiceRuleBuyerReferencePlaceholder) = erl_Forbidden) then
    { the placeholder only means "no buyer reference"; nothing is lost }
    Report(edk_NotAllowed, Agreement + '/ram:BuyerReference',
      'placeholder ' + FInvoice.BuyerReference + ' (BT-10) left out; only XRechnung uses it', eds_Info)
  else
    Target.BuyerReference := FInvoice.BuyerReference;
  Target.SellerOrderReferencedDocument.IssuerAssignedID.Value := FInvoice.SellerOrderReference;
  Target.BuyerOrderReferencedDocument.IssuerAssignedID.Value := FInvoice.PurchaseOrderReference;
  if (FInvoice.SellerOrderReferenceDate.HasValue or FInvoice.PurchaseOrderReferenceDate.HasValue) and
     Permit(LandrixEInvoiceRuleOrderDates, Agreement, 'date of the sales or purchase order') then
  begin
    if FInvoice.SellerOrderReferenceDate.HasValue then
      Target.SellerOrderReferencedDocument.FormattedIssueDateTime :=
        CIIFormattedDate(FInvoice.SellerOrderReferenceDate.Value);
    if FInvoice.PurchaseOrderReferenceDate.HasValue then
      Target.BuyerOrderReferencedDocument.FormattedIssueDateTime :=
        CIIFormattedDate(FInvoice.PurchaseOrderReferenceDate.Value);
  end;
  Target.ContractReferencedDocument.IssuerAssignedID.Value := FInvoice.ContractDocumentReference;
  if Present(FInvoice.ProjectReference) then
  begin
    Target.SpecifiedProcuringProject.ID.Value := FInvoice.ProjectReference;
    Target.SpecifiedProcuringProject.Name := 'Project reference';
  end;
end;

{ BG-24 attachments, BT-17 tender reference (type 50) and BT-18 object
  identifier (type 130): BT-17 and BT-18 only once and only with an
  identifier (CII-SR-457, CII-SR-458).
  DE: BG-24 Anlagen, BT-17 Vergabe (Art 50) und BT-18 Objektkennung (Art
  130): BT-17 und BT-18 nur einmal und nur mit Kennung (CII-SR-457,
  CII-SR-458). }
procedure TCIIWriteMapper.MapAttachments;
var
  I: TLandrixEInvoiceListIndex;
  Attachment: TLandrixInvoiceAttachment;
  Target: TLandrixCIIReferencedDocument;
  TenderWritten, ObjectWritten: Boolean;
  Path: TLandrixEInvoiceString;
begin
  TenderWritten := False;
  ObjectWritten := False;
  Path := Agreement + '/ram:AdditionalReferencedDocument';
  for I := 0 to FInvoice.Attachments.Count - 1 do
  begin
    Attachment := FInvoice.Attachments[I];
    if Attachment.TypeCode = iatc_50 then
    begin
      if TenderWritten or Blank(Attachment.ID) then
      begin
        Report(edk_NotAllowed, Path, 'tender reference (BT-17) ' + Attachment.ID +
          ' left out: only once and with an identifier (CII-SR-457)', eds_Warning);
        Continue;
      end;
      TenderWritten := True;
    end;
    if Attachment.TypeCode = iatc_130 then
    begin
      if ObjectWritten or Blank(Attachment.ID) then
      begin
        Report(edk_NotAllowed, Path, 'object identifier (BT-18) ' + Attachment.ID +
          ' left out: only once and with an identifier (CII-SR-458)', eds_Warning);
        Continue;
      end;
      ObjectWritten := True;
    end;
    Target := FCII.SupplyChainTradeTransaction.ApplicableHeaderTradeAgreement.AdditionalReferencedDocument.Add;
    Target.IssuerAssignedID.Value := Attachment.ID;
    Target.URIID.Value := Attachment.ExternalReference;
    Target.TypeCode := Code(LandrixEInvoiceAttachmentTypeCodeToStr(Attachment.TypeCode), Attachment.TypeCodeOther,
      Path + '/ram:TypeCode');
    if Attachment.TypeCode = iatc_130 then
      Target.ReferenceTypeCode := Attachment.SchemeID
    else if Present(Attachment.SchemeID) then
      Report(edk_NotAllowed, Path + '/ram:ReferenceTypeCode', 'scheme ' + Attachment.SchemeID + ' of attachment ' +
        Attachment.ID + ' left out: only the invoiced object identifier (BT-18) has one', eds_Warning);
    Target.Name := Txt(Attachment.DocumentDescription);
    if Attachment.ContainsBinaryObject then
    begin
      Target.AttachmentBinaryObject.Value := Attachment.GetDataAsBase64;
      Target.AttachmentBinaryObject.MimeCode := Code(LandrixEInvoiceAttachmentTypeToStr(Attachment.AttachmentType),
        Attachment.AttachmentTypeOther, Path + '/ram:AttachmentBinaryObject/@mimeCode');
      Target.AttachmentBinaryObject.Filename := Attachment.Filename;
    end;
  end;
end;

{ BG-13 delivery: BG-15 delivery address with BT-71 location (with scheme
  as global identifier, without as identifier) and BT-70 name, BG-X-26
  contact (EXTENDED), BT-72 delivery date, BT-16 despatch advice (its date
  BT-X-200 only in EXTENDED), BT-15 receiving advice, BT-X-202/BT-X-203
  delivery note (EXTENDED).
  DE: BG-13 Lieferung: BG-15 Lieferanschrift mit BT-71 Ort (mit Schema als
  globale Kennung, ohne als Kennung) und BT-70 Name, BG-X-26 Kontakt
  (EXTENDED), BT-72 Lieferdatum, BT-16 Versandanzeige (ihr Datum BT-X-200
  nur in EXTENDED), BT-15 Wareneingangsmeldung, BT-X-202/BT-X-203
  Lieferschein (EXTENDED). }
procedure TCIIWriteMapper.MapDelivery;
var
  Info: TLandrixInvoiceDeliveryInformation;
  Target: TLandrixCIIHeaderTradeDelivery;
  Contact: TLandrixCIITradeContact;
begin
  Info := FInvoice.DeliveryInformation;
  Target := FCII.SupplyChainTradeTransaction.ApplicableHeaderTradeDelivery;
  if Present(Info.LocationIdentifier) then
  begin
    if Blank(Info.LocationIdentifierSchemeID) then
      Target.ShipToTradeParty.ID.Add(CIIID(Info.LocationIdentifier, ''))
    else
      Target.ShipToTradeParty.GlobalID.Add(CIIID(Info.LocationIdentifier, Info.LocationIdentifierSchemeID));
  end;
  Target.ShipToTradeParty.Name := Txt(Info.Name);
  if (Present(Info.ContactName) or Present(Info.ContactTelephone) or Present(Info.ContactElectronicMail)) and
     Permit(LandrixEInvoiceRuleDeliveryContact, Delivery + '/ram:ShipToTradeParty/ram:DefinedTradeContact',
       'deliver to contact') then
  begin
    Contact := Target.ShipToTradeParty.DefinedTradeContact.Add;
    Contact.PersonName := Info.ContactName;
    Contact.TelephoneUniversalCommunication.CompleteNumber := Info.ContactTelephone;
    Contact.EmailURIUniversalCommunication.URIID.Value := Info.ContactElectronicMail;
  end;
  if AddressSet(Info.Address) then
    MapAddress(Info.Address, Target.ShipToTradeParty.PostalTradeAddress);
  if DateSet(Info.ActualDeliveryDate) then
    Target.ActualDeliverySupplyChainEvent.OccurrenceDateTime := CIIDate(Info.ActualDeliveryDate);
  if Present(FInvoice.DeliveryReceiptNumber) then
  begin
    Target.DespatchAdviceReferencedDocument.IssuerAssignedID.Value := FInvoice.DeliveryReceiptNumber;
    if DateSet(FInvoice.DeliveryReceiptDate) and
       Permit(LandrixEInvoiceRuleDespatchAdviceDate, Delivery + '/ram:DespatchAdviceReferencedDocument',
         'despatch advice date') then
      Target.DespatchAdviceReferencedDocument.FormattedIssueDateTime := CIIFormattedDate(FInvoice.DeliveryReceiptDate);
  end;
  Target.ReceivingAdviceReferencedDocument.IssuerAssignedID.Value := FInvoice.ReceiptDocumentReference;
  if Present(FInvoice.DeliveryReceiptNumberExtended) and
     Permit(LandrixEInvoiceRuleDeliveryNote, Delivery + '/ram:DeliveryNoteReferencedDocument', 'delivery note') then
  begin
    Target.DeliveryNoteReferencedDocument.IssuerAssignedID.Value := FInvoice.DeliveryReceiptNumberExtended;
    if DateSet(FInvoice.DeliveryReceiptDateExtended) then
      Target.DeliveryNoteReferencedDocument.FormattedIssueDateTime :=
        CIIFormattedDate(FInvoice.DeliveryReceiptDateExtended);
  end;
end;

{ BT-84 as ram:IBANID when it has the form of an IBAN (two letters, two
  digits, up to 30 letters or digits; spaces and lower case ignored), else
  as ram:ProprietaryID.
  DE: BT-84 als ram:IBANID, wenn es die Form einer IBAN hat (zwei
  Buchstaben, zwei Ziffern, bis zu 30 Buchstaben oder Ziffern; Leerzeichen
  und Kleinschreibung zaehlen nicht), sonst als ram:ProprietaryID. }
function LooksLikeIBAN(const AValue: TLandrixEInvoiceString): Boolean;
var
  I, N: Integer;
  C: WideChar;
  Compact: TLandrixEInvoiceString;
begin
  Compact := '';
  for N := 1 to Length(AValue) do
    if AValue[N] <> ' ' then
    begin
      C := AValue[N];
      if (C >= 'a') and (C <= 'z') then
        C := WideChar(Ord(C) - 32);
      Compact := Compact + C;
    end;
  Result := (Length(Compact) >= 15) and (Length(Compact) <= 34);
  I := 1;
  while Result and (I <= Length(Compact)) do
  begin
    C := Compact[I];
    if I <= 2 then
      Result := (C >= 'A') and (C <= 'Z')
    else if I <= 4 then
      Result := (C >= '0') and (C <= '9')
    else
      Result := ((C >= 'A') and (C <= 'Z')) or ((C >= '0') and (C <= '9'));
    Inc(I);
  end;
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

{ BT-90 creditor identifier, BT-83 remittance information, BT-5 currency,
  BG-16 payment instructions: BT-81 means, BT-82 text, BG-19 direct debit
  (BT-91 debited account), BG-18 card (BT-87, BT-88), BG-17 credit transfer
  (BT-84, BT-85, BT-86). Payment types without code are not written.
  DE: BT-90 Glaeubiger-ID, BT-83 Verwendungszweck, BT-5 Waehrung, BG-16
  Zahlungsanweisungen: BT-81 Zahlungsart, BT-82 Text, BG-19 Lastschrift
  (BT-91 belastetes Konto), BG-18 Karte (BT-87, BT-88), BG-17 Ueberweisung
  (BT-84, BT-85, BT-86). Zahlungsarten ohne Code werden nicht geschrieben. }
procedure TCIIWriteMapper.MapPaymentMeans;
var
  HeaderSettlement: TLandrixCIIHeaderTradeSettlement;
  Payment: TLandrixInvoicePaymentType;
  Target: TLandrixCIITradeSettlementPaymentMeans;
  I: TLandrixEInvoiceListIndex;
begin
  HeaderSettlement := FCII.SupplyChainTradeTransaction.ApplicableHeaderTradeSettlement;
  HeaderSettlement.CreditorReferenceID.Value := FInvoice.AccountingSupplierParty.BankAssignedCreditorIdentifier;
  HeaderSettlement.PaymentReference := FInvoice.PaymentID;
  { BT-6 only when the VAT accounting currency differs from the invoice currency }
  if FInvoice.TaxCurrencyCode <> FInvoice.InvoiceCurrencyCode then
    HeaderSettlement.TaxCurrencyCode := FInvoice.TaxCurrencyCode;
  HeaderSettlement.InvoiceCurrencyCode := FInvoice.InvoiceCurrencyCode;
  for I := 0 to FInvoice.PaymentTypes.Count - 1 do
  begin
    Payment := FInvoice.PaymentTypes[I];
    if (Payment.PaymentMeansCode = ipmc_NotImplemented) and Blank(Payment.PaymentMeansCodeOther) then
      Continue;
    Target := HeaderSettlement.SpecifiedTradeSettlementPaymentMeans.Add;
    Target.TypeCode := Code(LandrixEInvoicePaymentMeansCodeToStr(Payment.PaymentMeansCode),
      Payment.PaymentMeansCodeOther, Settlement + '/ram:SpecifiedTradeSettlementPaymentMeans/ram:TypeCode');
    Target.Information := Txt(Payment.PaymentMeansInformation);
    { BT-86 belongs to the payee's account; next to a direct debit it is
      written without one (ZUGFeRD example X01)
      DE: BT-86 gehoert zum Konto des Zahlungsempfaengers; neben einer
      Lastschrift wird es auch ohne Konto geschrieben (ZUGFeRD-Beispiel X01) }
    if not IsCardPayment(Payment.PaymentMeansCode) and
       (Present(Payment.FinancialAccount) or IsDirectDebit(Payment.PaymentMeansCode)) then
      Target.PayeeSpecifiedCreditorFinancialInstitution.BICID.Value := Payment.FinancialInstitutionBranch;
    if Blank(Payment.FinancialAccount) then
      Continue;
    if IsDirectDebit(Payment.PaymentMeansCode) then
      Target.PayerPartyDebtorFinancialAccount.IBANID.Value := Payment.FinancialAccount
    else if IsCardPayment(Payment.PaymentMeansCode) then
    begin
      Target.ApplicableTradeSettlementFinancialCard.ID.Value := Payment.FinancialAccount;
      Target.ApplicableTradeSettlementFinancialCard.CardholderName := Payment.FinancialAccountName;
    end
    else
    begin
      if LooksLikeIBAN(Payment.FinancialAccount) then
        Target.PayeePartyCreditorFinancialAccount.IBANID.Value := Payment.FinancialAccount
      else
        Target.PayeePartyCreditorFinancialAccount.ProprietaryID.Value := Payment.FinancialAccount;
      Target.PayeePartyCreditorFinancialAccount.AccountName := Payment.FinancialAccountName;
    end;
  end;
end;

{ BG-23 VAT breakdown: BT-117 tax amount, BT-120 exemption reason, BT-116
  taxable amount, BT-118 category, BT-121 exemption code, BT-7 VAT point
  date and BT-8 its code (document level in the model, written in the
  first breakdown only: CII-SR-461, CII-SR-462), BT-119 rate (also for
  category O, BR-DE-14).
  DE: BG-23 Steueraufschluesselung: BT-117 Steuerbetrag, BT-120
  Befreiungsgrund, BT-116 Bemessungsgrundlage, BT-118 Kategorie, BT-121
  Befreiungscode, BT-7 Steuerdatum und BT-8 sein Code (im Modell auf
  Dokumentebene, nur in der ersten Aufschluesselung geschrieben:
  CII-SR-461, CII-SR-462), BT-119 Steuersatz (auch fuer Kategorie O,
  BR-DE-14). }
procedure TCIIWriteMapper.MapTaxBreakdown;
var
  I: TLandrixEInvoiceListIndex;
  Subtotal: TLandrixInvoiceTaxAmount;
  Tax: TLandrixCIITradeTax;
  PointCode: TLandrixEInvoiceString;
begin
  PointCode := '';
  { BR-CO-3: BT-7 and BT-8 are mutually exclusive; the date wins.
    DE: BR-CO-3: BT-7 und BT-8 schliessen sich aus; das Datum gewinnt. }
  if FInvoice.TaxPointDate.HasValue and Present(FInvoice.TaxPointDateCode) then
    Report(edk_NotAllowed, Settlement + '/ram:ApplicableTradeTax/ram:DueDateTypeCode', 'VAT point date code ' +
      FInvoice.TaxPointDateCode + ' (BT-8) left out: the VAT point date (BT-7) is set (BR-CO-3)', eds_Warning)
  else if Present(FInvoice.TaxPointDateCode) and
     not LandrixEInvoiceTaxPointDateCodeToCII(FInvoice.TaxPointDateCode, PointCode) then
    Report(edk_UnknownCode, Settlement + '/ram:ApplicableTradeTax/ram:DueDateTypeCode', 'VAT point date code ' +
      FInvoice.TaxPointDateCode + ' (BT-8) is none of 3, 35, 432; written unchanged', eds_Warning);
  if (FInvoice.TaxPointDate.HasValue or Present(PointCode)) and (FInvoice.TaxAmountSubtotals.Count = 0) then
    Report(edk_NotAllowed, Settlement + '/ram:ApplicableTradeTax', 'VAT point date (BT-7, BT-8) left out: ' +
      'CII carries it in the VAT breakdown, which is empty', eds_Warning);
  for I := 0 to FInvoice.TaxAmountSubtotals.Count - 1 do
  begin
    Subtotal := FInvoice.TaxAmountSubtotals[I];
    Tax := FCII.SupplyChainTradeTransaction.ApplicableHeaderTradeSettlement.ApplicableTradeTax.Add;
    Tax.CalculatedAmount := CIIAmount(Subtotal.TaxAmount);
    Tax.TypeCode := 'VAT';
    Tax.ExemptionReason := Txt(Subtotal.TaxExemptionReason);
    Tax.BasisAmount := CIIAmount(Subtotal.TaxableAmount);
    Tax.CategoryCode := Code(LandrixEInvoiceDutyTaxFeeCategoryCodeToStr(Subtotal.TaxCategory),
      Subtotal.TaxCategoryOther, Settlement + '/ram:ApplicableTradeTax/ram:CategoryCode');
    Tax.ExemptionReasonCode.Value := Subtotal.TaxExemptionReasonCode;
    if (I = 0) and FInvoice.TaxPointDate.HasValue then
    begin
      Tax.TaxPointDate.Value := LandrixEInvoiceDateToCII(FInvoice.TaxPointDate.Value);
      Tax.TaxPointDate.Format := '102';
    end;
    if I = 0 then
      Tax.DueDateTypeCode := PointCode;
    Tax.RateApplicablePercent := LandrixEInvoicePercentToLexical(Subtotal.TaxPercent);
  end;
  if (PeriodDateSet(FInvoice.InvoicePeriodStartDate) or PeriodDateSet(FInvoice.InvoicePeriodEndDate)) and
     (not PeriodDateSet(FInvoice.InvoicePeriodStartDate) or not PeriodDateSet(FInvoice.InvoicePeriodEndDate) or
      (FInvoice.InvoicePeriodEndDate >= FInvoice.InvoicePeriodStartDate)) then
  begin
    if PeriodDateSet(FInvoice.InvoicePeriodStartDate) then
      FCII.SupplyChainTradeTransaction.ApplicableHeaderTradeSettlement.BillingSpecifiedPeriod.StartDateTime :=
        CIIDate(FInvoice.InvoicePeriodStartDate);
    if PeriodDateSet(FInvoice.InvoicePeriodEndDate) then
      FCII.SupplyChainTradeTransaction.ApplicableHeaderTradeSettlement.BillingSpecifiedPeriod.EndDateTime :=
        CIIDate(FInvoice.InvoicePeriodEndDate);
  end;
end;

{ BG-20/BG-21 document level allowances and charges with their VAT
  category (BT-95/BT-102, BT-96/BT-103; no rate for category O).
  DE: BG-20/BG-21 Nachlaesse und Zuschlaege auf Dokumentebene mit ihrer
  Steuerkategorie (BT-95/BT-102, BT-96/BT-103; kein Satz fuer Kategorie O). }
procedure TCIIWriteMapper.MapAllowanceCharges;
var
  I: TLandrixEInvoiceListIndex;
  Item: TLandrixInvoiceAllowanceCharge;
  Charge: TLandrixCIITradeAllowanceCharge;
  ReasonText, ReasonOther: TLandrixEInvoiceString;
begin
  for I := 0 to FInvoice.AllowanceCharges.Count - 1 do
  begin
    Item := FInvoice.AllowanceCharges[I];
    Charge := FCII.SupplyChainTradeTransaction.ApplicableHeaderTradeSettlement.SpecifiedTradeAllowanceCharge.Add;
    Charge.ChargeIndicator := BoolText(Item.ChargeIndicator);
    if Item.MultiplierFactorNumeric <> 0 then
      Charge.CalculationPercent := LandrixEInvoiceDecimalToLexical(Item.MultiplierFactorNumeric, 4);
    if Item.BaseAmount <> 0 then
      Charge.BasisAmount := CIIAmount(Item.BaseAmount);
    Charge.ActualAmount := CIIAmount(Item.Amount);
    ReasonText := AllowanceReasonCode(Item, ReasonOther);
    Charge.ReasonCode.Value := Code(ReasonText, ReasonOther,
      Settlement + '/ram:SpecifiedTradeAllowanceCharge/ram:ReasonCode');
    Charge.Reason := Txt(Item.Reason);
    Charge.CategoryTradeTax.TypeCode := 'VAT';
    Charge.CategoryTradeTax.CategoryCode := Code(LandrixEInvoiceDutyTaxFeeCategoryCodeToStr(Item.TaxCategory),
      Item.TaxCategoryOther, Settlement + '/ram:SpecifiedTradeAllowanceCharge/ram:CategoryTradeTax/ram:CategoryCode');
    if Item.TaxCategory <> idtfcc_O_ServicesOutsideScopeOfTax then
      Charge.CategoryTradeTax.RateApplicablePercent := LandrixEInvoicePercentToLexical(Item.TaxPercent);
  end;
end;

{ BT-20 payment terms as one text (EN 16931 allows one payment term): the
  net note without '#', or the cash discounts in the German #SKONTO# form
  (XRechnung), BT-9 due date (not on an XRechnung credit note), BT-89
  mandate.
  DE: BT-20 Zahlungsbedingungen als ein Text (EN 16931 erlaubt eine
  Zahlungsbedingung): der Nettohinweis ohne '#' oder die Skonti in der
  deutschen #SKONTO#-Form (XRechnung), BT-9 Faelligkeitsdatum (nicht auf
  einer XRechnung-Gutschrift), BT-89 Mandatsreferenz. }
procedure TCIIWriteMapper.MapPaymentTerms;
var
  Terms: TLandrixCIITradePaymentTerms;
begin
  if LandrixEInvoiceCashDiscountNotesSet(FInvoice) then
    Permit(LandrixEInvoiceRuleCashDiscountNote, Settlement + '/ram:SpecifiedTradePaymentTerms/ram:Description',
      'text of a cash discount level');
  Terms := FCII.SupplyChainTradeTransaction.ApplicableHeaderTradeSettlement.SpecifiedTradePaymentTerms.Add;
  Terms.Description := Txt(LandrixEInvoicePaymentTermsText(FInvoice));
  if DateSet(FInvoice.InvoiceDueDate) then
  begin
    if (FInvoice.InvoiceTypeCode = itc_CreditNote) and
       (LandrixEInvoiceRuleLevel(FSpec, LandrixEInvoiceRuleCreditNoteDueDate) = erl_Forbidden) then
      Report(edk_NotAllowed, Settlement + '/ram:SpecifiedTradePaymentTerms/ram:DueDateDateTime',
        'due date (BT-9) left out on a credit note', eds_Warning)
    else
      Terms.DueDateDateTime := CIIDate(FInvoice.InvoiceDueDate);
  end;
  Terms.DirectDebitMandateID.Value := FInvoice.PaymentMandateID;
  if Terms.IsEmpty then
    FCII.SupplyChainTradeTransaction.ApplicableHeaderTradeSettlement.SpecifiedTradePaymentTerms.Delete(
      FCII.SupplyChainTradeTransaction.ApplicableHeaderTradeSettlement.SpecifiedTradePaymentTerms.Count - 1);
end;

{ EXTENDED: one payment term with BT-20 note, BT-9 due date and BT-89
  mandate, and one term per cash discount (BG-X-44) with its text, its due
  date, the issue date as basis, the period in days and the rate.
  DE: EXTENDED: eine Zahlungsbedingung mit BT-20 Hinweis, BT-9
  Faelligkeitsdatum und BT-89 Mandat sowie eine Bedingung je Skonto
  (BG-X-44) mit Text, Faelligkeit, dem Rechnungsdatum als Basis, der Frist
  in Tagen und dem Satz. }
procedure TCIIWriteMapper.MapStructuredPaymentTerms;
var
  Terms: TLandrixCIITradePaymentTerms;
  K, Count, Days: Integer;
  Percent: Double;
  Base, Actual: Currency;
  Note: TLandrixEInvoiceString;
begin
  if DateSet(FInvoice.InvoiceDueDate) or Present(FInvoice.PaymentMandateID) or
     Present(FInvoice.PaymentTermNetNote) then
  begin
    Terms := FCII.SupplyChainTradeTransaction.ApplicableHeaderTradeSettlement.SpecifiedTradePaymentTerms.Add;
    Terms.Description := Txt(FInvoice.PaymentTermNetNote);
    if DateSet(FInvoice.InvoiceDueDate) then
      Terms.DueDateDateTime := CIIDate(FInvoice.InvoiceDueDate);
    Terms.DirectDebitMandateID.Value := FInvoice.PaymentMandateID;
  end;
  case FInvoice.PaymentTermsType of
    iptt_CashDiscount1: Count := 1;
    iptt_CashDiscount2: Count := 2;
    iptt_CashDiscount3: Count := 3;
  else
    Count := 0;
  end;
  for K := 1 to Count do
  begin
    case K of
      1:
        begin
          Days := FInvoice.PaymentTermCashDiscount1Days;
          Percent := FInvoice.PaymentTermCashDiscount1Percent;
          Base := FInvoice.PaymentTermCashDiscount1Base;
          Actual := FInvoice.PaymentTermCashDiscount1ActualAmount;
          Note := FInvoice.PaymentTermCashDiscount1Note;
        end;
      2:
        begin
          Days := FInvoice.PaymentTermCashDiscount2Days;
          Percent := FInvoice.PaymentTermCashDiscount2Percent;
          Base := FInvoice.PaymentTermCashDiscount2Base;
          Actual := FInvoice.PaymentTermCashDiscount2ActualAmount;
          Note := FInvoice.PaymentTermCashDiscount2Note;
        end;
    else
      begin
        Days := FInvoice.PaymentTermCashDiscount3Days;
        Percent := FInvoice.PaymentTermCashDiscount3Percent;
        Base := FInvoice.PaymentTermCashDiscount3Base;
        Actual := FInvoice.PaymentTermCashDiscount3ActualAmount;
        Note := FInvoice.PaymentTermCashDiscount3Note;
      end;
    end;
    Terms := FCII.SupplyChainTradeTransaction.ApplicableHeaderTradeSettlement.SpecifiedTradePaymentTerms.Add;
    Terms.Description := Txt(Note);
    Terms.DueDateDateTime := CIIDate(FInvoice.InvoiceIssueDate + Days);
    Terms.ApplicableTradePaymentDiscountTerms.BasisDateTime := CIIDate(FInvoice.InvoiceIssueDate);
    Terms.ApplicableTradePaymentDiscountTerms.BasisPeriodMeasure.Value := IntText(Days);
    Terms.ApplicableTradePaymentDiscountTerms.BasisPeriodMeasure.UnitCode := 'DAY';
    if Base <> 0 then
      Terms.ApplicableTradePaymentDiscountTerms.BasisAmount := CIIPrice(Base);
    Terms.ApplicableTradePaymentDiscountTerms.CalculationPercent := LandrixEInvoicePercentToLexical(Percent);
    if Actual <> 0 then
      Terms.ApplicableTradePaymentDiscountTerms.ActualDiscountAmount := CIIPrice(Actual);
  end;
end;

{ BG-22 document totals, taken from the model as they are: BT-106, BT-108,
  BT-107, BT-109, BT-110 (in the invoice currency), BT-111 (in the VAT
  accounting currency, only when BT-6 differs), BT-114 (only if not 0),
  BT-112, BT-113, BT-115. A differing BT-6 without BT-111 is an error
  (BR-53).
  DE: BG-22 Gesamtbetraege, unveraendert aus dem Modell: BT-106, BT-108,
  BT-107, BT-109, BT-110 (in der Rechnungswaehrung), BT-111 (in der
  Steuerwaehrung, nur wenn BT-6 abweicht), BT-114 (nur wenn nicht 0),
  BT-112, BT-113, BT-115. Ein abweichendes BT-6 ohne BT-111 ist ein Fehler
  (BR-53). }
procedure TCIIWriteMapper.MapTotals;
var
  Sum: TLandrixCIITradeSettlementHeaderMonetarySummation;
  TaxTotal: TLandrixCIIAmount;
  Path: TLandrixEInvoiceString;
begin
  Sum := FCII.SupplyChainTradeTransaction.ApplicableHeaderTradeSettlement.SpecifiedTradeSettlementHeaderMonetarySummation;
  Path := Settlement + '/ram:SpecifiedTradeSettlementHeaderMonetarySummation/ram:TaxTotalAmount';
  if TotalWanted('ram:LineTotalAmount', FInvoice.LineAmount) then
    Sum.LineTotalAmount := CIIAmount(FInvoice.LineAmount);
  if TotalWanted('ram:ChargeTotalAmount', FInvoice.ChargeTotalAmount) then
    Sum.ChargeTotalAmount := CIIAmount(FInvoice.ChargeTotalAmount);
  if TotalWanted('ram:AllowanceTotalAmount', FInvoice.AllowanceTotalAmount) then
    Sum.AllowanceTotalAmount := CIIAmount(FInvoice.AllowanceTotalAmount);
  Sum.TaxBasisTotalAmount := CIIAmount(FInvoice.TaxExclusiveAmount);
  TaxTotal := CIIAmount(FInvoice.TaxAmountTotal);
  TaxTotal.CurrencyID := FInvoice.InvoiceCurrencyCode;
  Sum.TaxTotalAmount.Add(TaxTotal);
  if Present(FInvoice.TaxCurrencyCode) and (FInvoice.TaxCurrencyCode <> FInvoice.InvoiceCurrencyCode) then
  begin
    if FInvoice.TaxAmountTotalInTaxCurrency.HasValue then
    begin
      TaxTotal := CIIAmount(FInvoice.TaxAmountTotalInTaxCurrency.Value);
      TaxTotal.CurrencyID := FInvoice.TaxCurrencyCode;
      Sum.TaxTotalAmount.Add(TaxTotal);
    end
    else
      Report(edk_MissingElement, Path, 'VAT total in the accounting currency ' + FInvoice.TaxCurrencyCode +
        ' (BT-111, BR-53) is missing', eds_Error);
  end
  else if FInvoice.TaxAmountTotalInTaxCurrency.HasValue then
    Report(edk_NotAllowed, Path, 'VAT total in the accounting currency (BT-111) left out: the VAT accounting ' +
      'currency (BT-6) does not differ from the invoice currency', eds_Warning);
  if FInvoice.PayableRoundingAmount <> 0 then
    Sum.RoundingAmount := CIIAmount(FInvoice.PayableRoundingAmount);
  Sum.GrandTotalAmount := CIIAmount(FInvoice.TaxInclusiveAmount);
  if TotalWanted('ram:TotalPrepaidAmount', FInvoice.PrepaidAmount) then
    Sum.TotalPrepaidAmount := CIIAmount(FInvoice.PrepaidAmount);
  Sum.DuePayableAmount := CIIAmount(FInvoice.PayableAmount);
end;

{ A total the profile does not contain (MINIMUM: BT-106, BT-107, BT-108,
  BT-113) is written only when it is not 0; then the pruning reports it.
  DE: Eine Summe, die das Profil nicht enthaelt (MINIMUM: BT-106, BT-107,
  BT-108, BT-113), wird nur geschrieben, wenn sie nicht 0 ist; dann meldet
  das Kuerzen sie. }
function TCIIWriteMapper.TotalWanted(const AName: TLandrixEInvoiceString; AValue: Currency): Boolean;
begin
  Result := (AValue <> 0) or LandrixEInvoiceCIIAllowed(Settlement +
    '/ram:SpecifiedTradeSettlementHeaderMonetarySummation/' + AName, FSpec.Target.Profile);
end;

{ BG-3 preceding invoices (BT-25, BT-26); XRechnung CII allows one, BT-19
  buyer accounting reference.
  DE: BG-3 vorausgegangene Rechnungen (BT-25, BT-26); XRechnung CII erlaubt
  eine, BT-19 Buchungsreferenz des Kaeufers. }
procedure TCIIWriteMapper.MapPrecedingInvoices;
var
  I: TLandrixEInvoiceListIndex;
  Reference: TLandrixInvoicePrecedingInvoiceReference;
  Target: TLandrixCIIReferencedDocument;
  Settlement2: TLandrixCIIHeaderTradeSettlement;
begin
  Settlement2 := FCII.SupplyChainTradeTransaction.ApplicableHeaderTradeSettlement;
  for I := 0 to FInvoice.PrecedingInvoiceReferences.Count - 1 do
  begin
    Reference := FInvoice.PrecedingInvoiceReferences[I];
    if (I > 0) and not Permit(LandrixEInvoiceRuleMultiplePrecedingInvoices,
      Settlement + '/ram:InvoiceReferencedDocument', 'preceding invoice ' + Reference.ID) then
      Continue;
    Target := Settlement2.InvoiceReferencedDocument.Add;
    Target.IssuerAssignedID.Value := Reference.ID;
    if DateSet(Reference.IssueDate) then
      Target.FormattedIssueDateTime := CIIFormattedDate(Reference.IssueDate);
  end;
  if Present(FInvoice.BuyerAccountingReference) then
    Settlement2.ReceivableSpecifiedTradeAccountingAccount.Add.ID.Value := FInvoice.BuyerAccountingReference;
end;

{ BG-DEX-09 third-party payments: Factur-X EXTENDED writes them as
  financial adjustments (BT-DEX-003 description, or BT-DEX-001 without one,
  as reason; BT-DEX-002 as amount; BR-FXEXT-CO-16 adds them to the amount
  due like BR-DEX-09). Elsewhere CII has no element; the amount due
  (BT-115) still includes them, so leaving them out breaks BR-CO-16: an
  error.
  DE: BG-DEX-09 Zahlungen Dritter: Factur-X EXTENDED schreibt sie als
  Finanzkorrekturen (BT-DEX-003 Beschreibung, ohne sie BT-DEX-001, als
  Grund; BT-DEX-002 als Betrag; BR-FXEXT-CO-16 rechnet sie wie BR-DEX-09
  zum Zahlbetrag). Sonst hat CII kein Element; der Zahlbetrag (BT-115)
  enthaelt sie weiterhin, Weglassen verletzt also BR-CO-16: ein Fehler. }
procedure TCIIWriteMapper.MapThirdPartyPayments;
var
  I: TLandrixEInvoiceListIndex;
  Payment: TLandrixInvoicePrepaidPayment;
  Target: TLandrixCIIFinancialAdjustment;
begin
  if FInvoice.PrepaidPayments.Count = 0 then
    Exit;
  if not Permit(LandrixEInvoiceRuleThirdPartyPayments, Settlement, 'third-party payments (BG-DEX-09)') then
  begin
    Report(edk_NotAllowed, Settlement + '/ram:SpecifiedTradeSettlementHeaderMonetarySummation/ram:DuePayableAmount',
      'amount due (BT-115) includes the third-party payments (BG-DEX-09) left out; BR-CO-16 is violated',
      eds_Error);
    Exit;
  end;
  for I := 0 to FInvoice.PrepaidPayments.Count - 1 do
  begin
    Payment := FInvoice.PrepaidPayments[I];
    Target := FCII.SupplyChainTradeTransaction.ApplicableHeaderTradeSettlement.SpecifiedFinancialAdjustment.Add;
    if Present(Payment.InstructionID) then
    begin
      Target.Reason := Payment.InstructionID;
      if Present(Payment.ID) then
        Report(edk_NotAllowed, Settlement + '/ram:SpecifiedFinancialAdjustment', 'type ' + Payment.ID +
          ' of a third-party payment (BT-DEX-001) left out: a financial adjustment has one reason', eds_Warning);
    end
    else
      Target.Reason := Payment.ID;
    Target.ActualAmount := CIIAmount(Payment.PaidAmount);
  end;
end;

{ --- reading ---------------------------------------------------------------- }

type
  { Reads one CII model into one invoice. Each method takes over what the
    invoice model can hold and reports the rest (edk_NotMapped) with the
    help of ListFilledChildren.
    DE: Liest ein CII-Modell in eine Rechnung. Jede Methode uebernimmt, was
    das Rechnungsmodell aufnehmen kann, und meldet den Rest
    (edk_NotMapped) mit Hilfe von ListFilledChildren. }
  TCIIReadMapper = class(TObject)
  private
    FCII: TLandrixCIIInvoice;
    FInvoice: TLandrixInvoice;
    FDiagnostics: TLandrixEInvoiceDiagnostics;
    FFilled: TLandrixEInvoiceStringList;
    procedure Report(AKind: TLandrixEInvoiceDiagnosticKind; const APath, AMessage: TLandrixEInvoiceString;
      ASeverity: TLandrixEInvoiceDiagnosticSeverity);
    procedure NotMapped(const APath, AWhat: TLandrixEInvoiceString);
    procedure Rest(const APath: TLandrixEInvoiceString; const ATaken: array of string);
    procedure Excess(ACount: TLandrixEInvoiceListIndex; const APath: TLandrixEInvoiceString);
    function Amount(const AValue: TLandrixCIIAmount; const APath: TLandrixEInvoiceString): Currency;
    function Price(const AValue: TLandrixCIIAmount; const APath: TLandrixEInvoiceString): Double;
    function Decimal(const AText, APath: TLandrixEInvoiceString): Double;
    function Date(const AValue: TLandrixCIIDateTime; const APath: TLandrixEInvoiceString): TDateTime;
    function FormattedDate(const AValue: TLandrixCIIFormattedDateTime; const APath: TLandrixEInvoiceString): TDateTime;
    function IDValue(const AValue: TLandrixCIIID; const APath: TLandrixEInvoiceString): TLandrixEInvoiceString;
    function CodeValue(const AValue: TLandrixCIICode; const APath: TLandrixEInvoiceString): TLandrixEInvoiceString;
    procedure UnknownCode(const AText, APath: TLandrixEInvoiceString; out AOther: TLandrixEInvoiceString);
    procedure ReadUnit(const AText, APath: TLandrixEInvoiceString; out AValue: TLandrixInvoiceUnitCode;
      out AOther: TLandrixEInvoiceString);
    procedure ReadTaxCategory(const AText, APath: TLandrixEInvoiceString;
      out AValue: TLandrixInvoiceDutyTaxFeeCategoryCode; out AOther: TLandrixEInvoiceString);
    procedure ReadReason(AItem: TLandrixInvoiceAllowanceCharge; const AValue: TLandrixCIIAllowanceChargeReasonCode;
      const APath: TLandrixEInvoiceString);
    procedure ReadContext;
    procedure ReadDocument;
    procedure ReadLines;
    procedure ReadLine(ALine: TLandrixInvoiceLine; AItem: TLandrixCIISupplyChainTradeLineItem;
      const APath: TLandrixEInvoiceString; out AParentID: TLandrixEInvoiceString; out ANoAmount: Boolean);
    procedure ReadLineProduct(ALine: TLandrixInvoiceLine; AProduct: TLandrixCIITradeProduct;
      const APath: TLandrixEInvoiceString);
    procedure ReadLineAgreement(ALine: TLandrixInvoiceLine; AAgreement: TLandrixCIILineTradeAgreement;
      const APath: TLandrixEInvoiceString);
    procedure ReadLineDelivery(ALine: TLandrixInvoiceLine; ADelivery: TLandrixCIILineTradeDelivery;
      const APath: TLandrixEInvoiceString);
    procedure ReadLineSettlement(ALine: TLandrixInvoiceLine; ASettlement: TLandrixCIILineTradeSettlement;
      const APath: TLandrixEInvoiceString; out ANoAmount: Boolean);
    procedure ReadAllowanceCharge(AItem: TLandrixInvoiceAllowanceCharge; ACharge: TLandrixCIITradeAllowanceCharge;
      const APath: TLandrixEInvoiceString; AWithTax: Boolean);
    procedure ReadLogisticsCharge(ACharge: TLandrixCIILogisticsServiceCharge; const APath: TLandrixEInvoiceString);
    procedure ReadAddress(AAddress: TLandrixInvoiceAddress; ASource: TLandrixCIITradeAddress;
      const APath: TLandrixEInvoiceString);
    procedure ReadParty(AParty: TLandrixInvoiceAccountingParty; ASource: TLandrixCIITradeParty;
      const APath: TLandrixEInvoiceString; AIsSeller: Boolean);
    procedure ReadFurtherParty(AParty: TLandrixInvoiceParty; ASource: TLandrixCIITradeParty;
      const APath: TLandrixEInvoiceString);
    procedure ReadAgreement;
    procedure ReadAttachments;
    procedure ReadDelivery;
    procedure ReadSettlement;
    procedure ReadPaymentMeans(ASettlement: TLandrixCIIHeaderTradeSettlement);
    procedure ReadPaymentTerms(ASettlement: TLandrixCIIHeaderTradeSettlement);
    procedure ReadTotals(ASettlement: TLandrixCIIHeaderTradeSettlement);
  public
    constructor Create(ACII: TLandrixCIIInvoice; AInvoice: TLandrixInvoice;
      ADiagnostics: TLandrixEInvoiceDiagnostics);
    destructor Destroy; override;
    procedure Execute;
  end;

constructor TCIIReadMapper.Create(ACII: TLandrixCIIInvoice; AInvoice: TLandrixInvoice;
  ADiagnostics: TLandrixEInvoiceDiagnostics);
begin
  inherited Create;
  FCII := ACII;
  FInvoice := AInvoice;
  FDiagnostics := ADiagnostics;
  FFilled := TLandrixEInvoiceStringList.Create;
end;

destructor TCIIReadMapper.Destroy;
begin
  FFilled.Free;
  inherited;
end;

procedure TCIIReadMapper.Report(AKind: TLandrixEInvoiceDiagnosticKind;
  const APath, AMessage: TLandrixEInvoiceString; ASeverity: TLandrixEInvoiceDiagnosticSeverity);
begin
  if FDiagnostics <> nil then
    FDiagnostics.AddDiagnostic(AKind, APath, 0, 0, 0, AMessage).Severity := ASeverity;
end;

procedure TCIIReadMapper.NotMapped(const APath, AWhat: TLandrixEInvoiceString);
begin
  Report(edk_NotMapped, APath, AWhat + ' has no place in the invoice model; kept in the CII model only',
    eds_Warning);
end;

{ Reports every child in FFilled (filled by ListFilledChildren) that is not
  in ATaken. DE: Meldet jedes Kind in FFilled (gefuellt von
  ListFilledChildren), das nicht in ATaken steht. }
procedure TCIIReadMapper.Rest(const APath: TLandrixEInvoiceString; const ATaken: array of string);
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

procedure TCIIReadMapper.Excess(ACount: TLandrixEInvoiceListIndex; const APath: TLandrixEInvoiceString);
begin
  if ACount > 1 then
    NotMapped(APath, TLandrixEInvoiceString(IntToStr(ACount - 1)) + ' further occurrence(s)');
end;

function TCIIReadMapper.Amount(const AValue: TLandrixCIIAmount; const APath: TLandrixEInvoiceString): Currency;
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
function TCIIReadMapper.Price(const AValue: TLandrixCIIAmount; const APath: TLandrixEInvoiceString): Double;
begin
  if (AValue.CurrencyID <> '') and (AValue.CurrencyID <> FInvoice.InvoiceCurrencyCode) then
    NotMapped(APath + '/@currencyID', 'currency ' + AValue.CurrencyID);
  Result := Decimal(AValue.Value, APath);
end;

function TCIIReadMapper.Decimal(const AText, APath: TLandrixEInvoiceString): Double;
begin
  Result := 0;
  if AText = '' then
    Exit;
  if not LandrixEInvoiceTryLexicalToDouble(AText, Result) then
    Report(edk_ConversionFailed, APath, 'number "' + AText + '" not converted; 0 used', eds_Error);
end;

function TCIIReadMapper.Date(const AValue: TLandrixCIIDateTime; const APath: TLandrixEInvoiceString): TDateTime;
begin
  Result := 0;
  if AValue.Value = '' then
    Exit;
  if not LandrixEInvoiceTryCIIToDate(AValue.Value, AValue.Format, Result) then
    Report(edk_ConversionFailed, APath, 'date "' + AValue.Value + '" (format ' + AValue.Format +
      ') not converted; not set', eds_Error);
end;

function TCIIReadMapper.FormattedDate(const AValue: TLandrixCIIFormattedDateTime;
  const APath: TLandrixEInvoiceString): TDateTime;
begin
  Result := 0;
  if AValue.Value = '' then
    Exit;
  if not LandrixEInvoiceTryCIIToDate(AValue.Value, AValue.Format, Result) then
    Report(edk_ConversionFailed, APath, 'date "' + AValue.Value + '" (format ' + AValue.Format +
      ') not converted; not set', eds_Error);
end;

{ Identifier whose scheme the invoice model does not keep.
  DE: Kennung, deren Schema das Rechnungsmodell nicht behaelt. }
function TCIIReadMapper.IDValue(const AValue: TLandrixCIIID; const APath: TLandrixEInvoiceString): TLandrixEInvoiceString;
begin
  Result := AValue.Value;
  if AValue.SchemeID <> '' then
    NotMapped(APath + '/@schemeID', 'scheme ' + AValue.SchemeID);
end;

function TCIIReadMapper.CodeValue(const AValue: TLandrixCIICode; const APath: TLandrixEInvoiceString): TLandrixEInvoiceString;
begin
  Result := AValue.Value;
  if AValue.ListID <> '' then
    NotMapped(APath + '/@listID', 'list ' + AValue.ListID);
  if AValue.ListVersionID <> '' then
    NotMapped(APath + '/@listVersionID', 'list version ' + AValue.ListVersionID);
end;

procedure TCIIReadMapper.UnknownCode(const AText, APath: TLandrixEInvoiceString; out AOther: TLandrixEInvoiceString);
begin
  AOther := AText;
  if AText <> '' then
    Report(edk_UnknownCode, APath, 'code ' + AText + ' is not in the code list; kept in ...Other', eds_Info);
end;

procedure TCIIReadMapper.ReadUnit(const AText, APath: TLandrixEInvoiceString;
  out AValue: TLandrixInvoiceUnitCode; out AOther: TLandrixEInvoiceString);
begin
  AOther := '';
  if not LandrixEInvoiceUnitCodeFromStr(AText, AValue) then
  begin
    AValue := iuc_None;
    UnknownCode(AText, APath, AOther);
  end;
end;

procedure TCIIReadMapper.ReadTaxCategory(const AText, APath: TLandrixEInvoiceString;
  out AValue: TLandrixInvoiceDutyTaxFeeCategoryCode; out AOther: TLandrixEInvoiceString);
begin
  AOther := '';
  if not LandrixEInvoiceDutyTaxFeeCategoryCodeFromStr(AText, AValue) then
  begin
    AValue := idtfcc_None;
    UnknownCode(AText, APath, AOther);
  end;
end;

{ BT-98/BT-105 (document) and BT-140/BT-145 (line) reason codes: UNTDID 5189
  for allowances, UNTDID 7161 for charges.
  DE: BT-98/BT-105 (Dokument) und BT-140/BT-145 (Position) Grundcodes:
  UNTDID 5189 fuer Nachlaesse, UNTDID 7161 fuer Zuschlaege. }
procedure TCIIReadMapper.ReadReason(AItem: TLandrixInvoiceAllowanceCharge;
  const AValue: TLandrixCIIAllowanceChargeReasonCode; const APath: TLandrixEInvoiceString);
begin
  if AValue.ListID <> '' then
    NotMapped(APath + '/@listID', 'list ' + AValue.ListID);
  if AValue.Value = '' then
    Exit;
  if AItem.ChargeIndicator then
  begin
    if not LandrixEInvoiceSpecialServiceDescriptionCodeFromStr(AValue.Value, AItem.ReasonCodeCharge) then
    begin
      AItem.ReasonCodeCharge := issdc_None;
      UnknownCode(AValue.Value, APath, AItem.ReasonCodeChargeOther);
    end;
  end
  else if not LandrixEInvoiceAllowanceOrChargeIdentCodeFromStr(AValue.Value, AItem.ReasonCodeAllowance) then
  begin
    AItem.ReasonCodeAllowance := iacic_None;
    UnknownCode(AValue.Value, APath, AItem.ReasonCodeAllowanceOther);
  end;
end;

procedure TCIIReadMapper.Execute;
begin
  FInvoice.Clear;
  FInvoice.ProfileID := '';
  ReadContext;
  ReadDocument;
  ReadSettlement;  { currencies first: amounts compare their currency }
  ReadLines;
  ReadAgreement;
  ReadDelivery;
end;

{ BT-X-1 test indicator, BT-23 business process; BT-24 identifies the
  specification (detected by the caller, not kept in the invoice model).
  DE: BT-X-1 Testkennzeichen, BT-23 Geschaeftsprozess; BT-24 bestimmt die
  Spezifikation (vom Aufrufer erkannt, nicht im Rechnungsmodell gehalten). }
procedure TCIIReadMapper.ReadContext;
var
  Context: TLandrixCIIExchangedDocumentContext;
begin
  Context := FCII.ExchangedDocumentContext;
  if (Context.TestIndicator = 'true') or (Context.TestIndicator = '1') then
    FInvoice.TestIndicator.SetValue(True)
  else if (Context.TestIndicator = 'false') or (Context.TestIndicator = '0') then
    FInvoice.TestIndicator.SetValue(False)
  else if Context.TestIndicator <> '' then
    Report(edk_ConversionFailed, Root + '/rsm:ExchangedDocumentContext/ram:TestIndicator',
      'indicator "' + Context.TestIndicator + '" not converted; not set', eds_Error);
  FInvoice.ProfileID := IDValue(Context.BusinessProcessSpecifiedDocumentContextParameter.ID,
    Root + '/rsm:ExchangedDocumentContext/ram:BusinessProcessSpecifiedDocumentContextParameter/ram:ID');
  Context.BusinessProcessSpecifiedDocumentContextParameter.ListFilledChildren(FFilled);
  Rest(Root + '/rsm:ExchangedDocumentContext/ram:BusinessProcessSpecifiedDocumentContextParameter', ['ram:ID']);
  Context.ListFilledChildren(FFilled);
  Rest(Root + '/rsm:ExchangedDocumentContext', ['ram:TestIndicator', 'ram:BusinessProcessSpecifiedDocumentContextParameter',
    'ram:GuidelineSpecifiedDocumentContextParameter']);
end;

procedure TCIIReadMapper.ReadDocument;
var
  Doc: TLandrixCIIExchangedDocument;
  Note: TLandrixInvoiceNote;
  I: TLandrixEInvoiceListIndex;
  Path: TLandrixEInvoiceString;
  Text: TLandrixEInvoiceString;
begin
  Doc := FCII.ExchangedDocument;
  Path := Root + '/rsm:ExchangedDocument';
  FInvoice.InvoiceNumber := IDValue(Doc.ID, Path + '/ram:ID');
  FInvoice.DocumentName := Doc.Name;
  if (Doc.TypeCode <> '') and not LandrixEInvoiceTypeCodeFromStr(Doc.TypeCode, FInvoice.InvoiceTypeCode) then
  begin
    FInvoice.InvoiceTypeCode := itc_None;
    UnknownCode(Doc.TypeCode, Path + '/ram:TypeCode', FInvoice.InvoiceTypeCodeOther);
  end;
  FInvoice.InvoiceIssueDate := Date(Doc.IssueDateTime, Path + '/ram:IssueDateTime');
  for I := 0 to Doc.IncludedNote.Count - 1 do
  begin
    Note := FInvoice.Notes.AddNote;
    Note.Content := Doc.IncludedNote[I].Content;
    Text := CodeValue(Doc.IncludedNote[I].SubjectCode, Path + '/ram:IncludedNote/ram:SubjectCode');
    if (Text <> '') and not LandrixEInvoiceNoteSubjectCodeFromStr(Text, Note.SubjectCode) then
    begin
      Note.SubjectCode := insc_None;
      UnknownCode(Text, Path + '/ram:IncludedNote/ram:SubjectCode', Note.SubjectCodeOther);
    end;
    Doc.IncludedNote[I].ListFilledChildren(FFilled);
    Rest(Path + '/ram:IncludedNote', ['ram:Content', 'ram:SubjectCode']);
  end;
  Doc.ListFilledChildren(FFilled);
  Rest(Path, ['ram:ID', 'ram:Name', 'ram:TypeCode', 'ram:IssueDateTime', 'ram:IncludedNote']);
end;

procedure TCIIReadMapper.ReadLines;
var
  Lines, NoAmount: TObjectList;
  ParentIDs: TLandrixEInvoiceStringList;
  Items: TLandrixCIISupplyChainTradeLineItemList;
  Line: TLandrixInvoiceLine;
  ParentID: TLandrixEInvoiceString;
  WithoutAmount: Boolean;
  I: TLandrixEInvoiceListIndex;
begin
  Items := FCII.SupplyChainTradeTransaction.IncludedSupplyChainTradeLineItem;
  Lines := TObjectList.Create(False);
  NoAmount := TObjectList.Create(False);
  ParentIDs := TLandrixEInvoiceStringList.Create;
  try
    for I := 0 to Items.Count - 1 do
    begin
      Line := FInvoice.InvoiceLines.AddInvoiceLine;
      Lines.Add(Line);
      ReadLine(Line, Items[I], LineItem, ParentID, WithoutAmount);
      ParentIDs.Add(ParentID);
      if WithoutAmount then
        NoAmount.Add(Line);
    end;
    LandrixEInvoiceBuildSubLines(FInvoice, Lines, ParentIDs, NoAmount, FDiagnostics);
  finally
    ParentIDs.Free;
    NoAmount.Free;
    Lines.Free;
  end;
  FCII.SupplyChainTradeTransaction.ListFilledChildren(FFilled);
  Rest(Transaction, ['ram:IncludedSupplyChainTradeLineItem', 'ram:ApplicableHeaderTradeAgreement',
    'ram:ApplicableHeaderTradeDelivery', 'ram:ApplicableHeaderTradeSettlement']);
  FCII.ListFilledChildren(FFilled);
  Rest(Root, ['rsm:ExchangedDocumentContext', 'rsm:ExchangedDocument', 'rsm:SupplyChainTradeTransaction']);
end;

{ BG-25 line; BT-X-304 parent line and BT-X-8 status are returned for the
  tree, a missing BT-131 marks a group line whose amount is derived.
  DE: BG-25 Position; BT-X-304 Oberposition und BT-X-8 Status fuer den
  Baum, ein fehlendes BT-131 kennzeichnet eine Gruppenposition, deren
  Betrag abgeleitet wird. }
procedure TCIIReadMapper.ReadLine(ALine: TLandrixInvoiceLine; AItem: TLandrixCIISupplyChainTradeLineItem;
  const APath: TLandrixEInvoiceString; out AParentID: TLandrixEInvoiceString; out ANoAmount: Boolean);
var
  Doc: TLandrixCIIDocumentLineDocument;
  Text: TLandrixEInvoiceString;
begin
  Doc := AItem.AssociatedDocumentLineDocument;
  ALine.ID := IDValue(Doc.LineID, APath + '/ram:AssociatedDocumentLineDocument/ram:LineID');
  AParentID := IDValue(Doc.ParentLineID, APath + '/ram:AssociatedDocumentLineDocument/ram:ParentLineID');
  Text := CodeValue(Doc.LineStatusReasonCode, APath + '/ram:AssociatedDocumentLineDocument/ram:LineStatusReasonCode');
  if (Text <> '') and not LandrixEInvoiceLineStatusReasonCodeFromStr(Text, ALine.LineStatusReasonCode) then
  begin
    ALine.LineStatusReasonCode := ilsrc_None;
    UnknownCode(Text, APath + '/ram:AssociatedDocumentLineDocument/ram:LineStatusReasonCode',
      ALine.LineStatusReasonCodeOther);
  end;
  if Doc.IncludedNote.Count > 0 then
  begin
    ALine.Note := Doc.IncludedNote[0].Content;
    Doc.IncludedNote[0].ListFilledChildren(FFilled);
    Rest(APath + '/ram:AssociatedDocumentLineDocument/ram:IncludedNote', ['ram:Content']);
    Excess(Doc.IncludedNote.Count, APath + '/ram:AssociatedDocumentLineDocument/ram:IncludedNote');
  end;
  Doc.ListFilledChildren(FFilled);
  Rest(APath + '/ram:AssociatedDocumentLineDocument', ['ram:LineID', 'ram:ParentLineID',
    'ram:LineStatusReasonCode', 'ram:IncludedNote']);
  ReadLineProduct(ALine, AItem.SpecifiedTradeProduct, APath + '/ram:SpecifiedTradeProduct');
  ReadLineAgreement(ALine, AItem.SpecifiedLineTradeAgreement, APath + '/ram:SpecifiedLineTradeAgreement');
  ReadLineDelivery(ALine, AItem.SpecifiedLineTradeDelivery, APath + '/ram:SpecifiedLineTradeDelivery');
  ReadLineSettlement(ALine, AItem.SpecifiedLineTradeSettlement, APath + '/ram:SpecifiedLineTradeSettlement',
    ANoAmount);
  AItem.ListFilledChildren(FFilled);
  Rest(APath, ['ram:AssociatedDocumentLineDocument', 'ram:SpecifiedTradeProduct', 'ram:SpecifiedLineTradeAgreement',
    'ram:SpecifiedLineTradeDelivery', 'ram:SpecifiedLineTradeSettlement']);
end;

{ BG-31: BT-157 goes to StandardItemIdentifier, with scheme 0160 (GTIN)
  also to GlobalID_EAN_GTIN.
  DE: BG-31: BT-157 kommt nach StandardItemIdentifier, mit Schema 0160
  (GTIN) auch nach GlobalID_EAN_GTIN. }
procedure TCIIReadMapper.ReadLineProduct(ALine: TLandrixInvoiceLine; AProduct: TLandrixCIITradeProduct;
  const APath: TLandrixEInvoiceString);
var
  I: TLandrixEInvoiceListIndex;
  Classification: TLandrixInvoiceLineItemClassification;
  Source: TLandrixCIIProductClassification;
  Taken: array[0..7] of string;
begin
  Taken[0] := 'ram:SellerAssignedID';
  Taken[1] := 'ram:BuyerAssignedID';
  Taken[2] := 'ram:Name';
  Taken[3] := 'ram:Description';
  Taken[4] := 'ram:ApplicableProductCharacteristic';
  Taken[5] := 'ram:DesignatedProductClassification';
  Taken[6] := 'ram:OriginTradeCountry';
  Taken[7] := 'ram:GlobalID';
  ALine.StandardItemIdentifier := AProduct.GlobalID.Value;
  ALine.StandardItemIdentifierSchemeID := AProduct.GlobalID.SchemeID;
  if AProduct.GlobalID.SchemeID = '0160' then
    ALine.GlobalID_EAN_GTIN := AProduct.GlobalID.Value;
  ALine.SellersItemIdentification := IDValue(AProduct.SellerAssignedID, APath + '/ram:SellerAssignedID');
  ALine.BuyersItemIdentification := IDValue(AProduct.BuyerAssignedID, APath + '/ram:BuyerAssignedID');
  ALine.Name := AProduct.Name;
  ALine.Description := AProduct.Description;
  for I := 0 to AProduct.ApplicableProductCharacteristic.Count - 1 do
    with ALine.ItemAttributes.AddItemAttribute do
    begin
      Name := AProduct.ApplicableProductCharacteristic[I].Description;
      Value := AProduct.ApplicableProductCharacteristic[I].Value;
      AProduct.ApplicableProductCharacteristic[I].ListFilledChildren(FFilled);
      Rest(APath + '/ram:ApplicableProductCharacteristic', ['ram:Description', 'ram:Value']);
    end;
  for I := 0 to AProduct.DesignatedProductClassification.Count - 1 do
  begin
    Source := AProduct.DesignatedProductClassification[I];
    Classification := ALine.ItemClassifications.AddItemClassification;
    Classification.ClassCode := Source.ClassCode.Value;
    Classification.ListID := Source.ClassCode.ListID;
    Classification.ListVersionID := Source.ClassCode.ListVersionID;
    Classification.ClassificationName := Source.ClassificationName;
  end;
  ALine.OriginTradeCountry := AProduct.OriginTradeCountry.ID;
  AProduct.ListFilledChildren(FFilled);
  Rest(APath, Taken);
end;

{ BT-132 and BT-X-21 from the buyer order reference, BT-148/BT-147 gross
  price and discount, BT-146 net price, BT-149/BT-150 base quantity (the
  writer puts the same base quantity into both prices).
  DE: BT-132 und BT-X-21 aus der Bestellreferenz, BT-148/BT-147 Bruttopreis
  und Rabatt, BT-146 Nettopreis, BT-149/BT-150 Basismenge (der Schreiber
  setzt dieselbe Basismenge in beide Preise). }
procedure TCIIReadMapper.ReadLineAgreement(ALine: TLandrixInvoiceLine; AAgreement: TLandrixCIILineTradeAgreement;
  const APath: TLandrixEInvoiceString);
var
  Gross, Net: TLandrixCIITradePrice;
  Discount: TLandrixCIITradeAllowanceCharge;
begin
  ALine.OrderNumber := IDValue(AAgreement.BuyerOrderReferencedDocument.IssuerAssignedID,
    APath + '/ram:BuyerOrderReferencedDocument/ram:IssuerAssignedID');
  ALine.OrderLineReference := IDValue(AAgreement.BuyerOrderReferencedDocument.LineID,
    APath + '/ram:BuyerOrderReferencedDocument/ram:LineID');
  if AAgreement.BuyerOrderReferencedDocument.FormattedIssueDateTime.Value <> '' then
    SetDate(ALine.OrderDate, FormattedDate(AAgreement.BuyerOrderReferencedDocument.FormattedIssueDateTime,
      APath + '/ram:BuyerOrderReferencedDocument/ram:FormattedIssueDateTime'));
  AAgreement.BuyerOrderReferencedDocument.ListFilledChildren(FFilled);
  Rest(APath + '/ram:BuyerOrderReferencedDocument', ['ram:IssuerAssignedID', 'ram:LineID',
    'ram:FormattedIssueDateTime']);
  Net := AAgreement.NetPriceProductTradePrice;
  ALine.NetPriceAmount := Price(Net.ChargeAmount, APath + '/ram:NetPriceProductTradePrice/ram:ChargeAmount');
  if Net.BasisQuantity.Value <> '' then
  begin
    ALine.BaseQuantity := Decimal(Net.BasisQuantity.Value, APath + '/ram:NetPriceProductTradePrice/ram:BasisQuantity');
    ReadUnit(Net.BasisQuantity.UnitCode, APath + '/ram:NetPriceProductTradePrice/ram:BasisQuantity/@unitCode',
      ALine.BaseQuantityUnitCode, ALine.BaseQuantityUnitCodeOther);
  end;
  Net.ListFilledChildren(FFilled);
  Rest(APath + '/ram:NetPriceProductTradePrice', ['ram:ChargeAmount', 'ram:BasisQuantity']);
  Gross := AAgreement.GrossPriceProductTradePrice;
  if not Gross.IsEmpty then
  begin
    ALine.GrossPriceAmount := Price(Gross.ChargeAmount, APath + '/ram:GrossPriceProductTradePrice/ram:ChargeAmount');
    if Gross.AppliedTradeAllowanceCharge.Count > 0 then
    begin
      Discount := Gross.AppliedTradeAllowanceCharge[0];
      if (Discount.ChargeIndicator = 'true') or (Discount.ChargeIndicator = '1') then
        NotMapped(APath + '/ram:GrossPriceProductTradePrice/ram:AppliedTradeAllowanceCharge',
          'charge on the gross price')
      else
        ALine.DiscountOnTheGrossPrice := Price(Discount.ActualAmount,
          APath + '/ram:GrossPriceProductTradePrice/ram:AppliedTradeAllowanceCharge/ram:ActualAmount');
      Discount.ListFilledChildren(FFilled);
      Rest(APath + '/ram:GrossPriceProductTradePrice/ram:AppliedTradeAllowanceCharge',
        ['ram:ChargeIndicator', 'ram:ActualAmount']);
      Excess(Gross.AppliedTradeAllowanceCharge.Count, APath + '/ram:GrossPriceProductTradePrice/ram:AppliedTradeAllowanceCharge');
    end;
    { BT-149 may sit at the gross price only (KoSIT testsuite 03.07a); it is
      the base quantity of both prices.
      DE: BT-149 darf nur am Bruttopreis stehen (KoSIT-Testsuite 03.07a); es
      ist die Basismenge beider Preise. }
    if (Gross.BasisQuantity.Value <> '') and (Net.BasisQuantity.Value = '') then
    begin
      ALine.BaseQuantity := Decimal(Gross.BasisQuantity.Value,
        APath + '/ram:GrossPriceProductTradePrice/ram:BasisQuantity');
      ReadUnit(Gross.BasisQuantity.UnitCode, APath + '/ram:GrossPriceProductTradePrice/ram:BasisQuantity/@unitCode',
        ALine.BaseQuantityUnitCode, ALine.BaseQuantityUnitCodeOther);
    end
    else if (Gross.BasisQuantity.Value <> '') and ((Gross.BasisQuantity.Value <> Net.BasisQuantity.Value) or
       (Gross.BasisQuantity.UnitCode <> Net.BasisQuantity.UnitCode)) then
      NotMapped(APath + '/ram:GrossPriceProductTradePrice/ram:BasisQuantity',
        'base quantity of the gross price that differs from the net price');
    Gross.ListFilledChildren(FFilled);
    Rest(APath + '/ram:GrossPriceProductTradePrice', ['ram:ChargeAmount', 'ram:BasisQuantity',
      'ram:AppliedTradeAllowanceCharge']);
  end;
  AAgreement.ListFilledChildren(FFilled);
  Rest(APath, ['ram:BuyerOrderReferencedDocument', 'ram:GrossPriceProductTradePrice', 'ram:NetPriceProductTradePrice']);
end;

procedure TCIIReadMapper.ReadLineDelivery(ALine: TLandrixInvoiceLine; ADelivery: TLandrixCIILineTradeDelivery;
  const APath: TLandrixEInvoiceString);
var
  Note: TLandrixCIIReferencedDocument;
begin
  ALine.Quantity := Decimal(ADelivery.BilledQuantity.Value, APath + '/ram:BilledQuantity');
  ReadUnit(ADelivery.BilledQuantity.UnitCode, APath + '/ram:BilledQuantity/@unitCode', ALine.UnitCode,
    ALine.UnitCodeOther);
  ALine.ActualDeliveryDate := Date(ADelivery.ActualDeliverySupplyChainEvent.OccurrenceDateTime,
    APath + '/ram:ActualDeliverySupplyChainEvent/ram:OccurrenceDateTime');
  ADelivery.ActualDeliverySupplyChainEvent.ListFilledChildren(FFilled);
  Rest(APath + '/ram:ActualDeliverySupplyChainEvent', ['ram:OccurrenceDateTime']);
  Note := ADelivery.DeliveryNoteReferencedDocument;
  ALine.DeliveryNoteNumber := IDValue(Note.IssuerAssignedID, APath + '/ram:DeliveryNoteReferencedDocument/ram:IssuerAssignedID');
  ALine.DeliveryNoteLineID := IDValue(Note.LineID, APath + '/ram:DeliveryNoteReferencedDocument/ram:LineID');
  ALine.DeliveryNoteDate := FormattedDate(Note.FormattedIssueDateTime,
    APath + '/ram:DeliveryNoteReferencedDocument/ram:FormattedIssueDateTime');
  Note.ListFilledChildren(FFilled);
  Rest(APath + '/ram:DeliveryNoteReferencedDocument', ['ram:IssuerAssignedID', 'ram:LineID',
    'ram:FormattedIssueDateTime']);
  ADelivery.ListFilledChildren(FFilled);
  Rest(APath, ['ram:BilledQuantity', 'ram:ActualDeliverySupplyChainEvent', 'ram:DeliveryNoteReferencedDocument']);
end;

procedure TCIIReadMapper.ReadAllowanceCharge(AItem: TLandrixInvoiceAllowanceCharge;
  ACharge: TLandrixCIITradeAllowanceCharge; const APath: TLandrixEInvoiceString; AWithTax: Boolean);
var
  Tax: TLandrixCIITradeTax;
begin
  AItem.ChargeIndicator := (ACharge.ChargeIndicator = 'true') or (ACharge.ChargeIndicator = '1');
  AItem.MultiplierFactorNumeric := Decimal(ACharge.CalculationPercent, APath + '/ram:CalculationPercent');
  AItem.BaseAmount := Amount(ACharge.BasisAmount, APath + '/ram:BasisAmount');
  AItem.Amount := Amount(ACharge.ActualAmount, APath + '/ram:ActualAmount');
  ReadReason(AItem, ACharge.ReasonCode, APath + '/ram:ReasonCode');
  AItem.Reason := ACharge.Reason;
  if AWithTax then
  begin
    Tax := ACharge.CategoryTradeTax;
    ReadTaxCategory(Tax.CategoryCode, APath + '/ram:CategoryTradeTax/ram:CategoryCode', AItem.TaxCategory,
      AItem.TaxCategoryOther);
    AItem.TaxPercent := Decimal(Tax.RateApplicablePercent, APath + '/ram:CategoryTradeTax/ram:RateApplicablePercent');
    if (Tax.TypeCode <> '') and (Tax.TypeCode <> 'VAT') then
      NotMapped(APath + '/ram:CategoryTradeTax/ram:TypeCode', 'tax type ' + Tax.TypeCode);
    Tax.ListFilledChildren(FFilled);
    Rest(APath + '/ram:CategoryTradeTax', ['ram:TypeCode', 'ram:CategoryCode', 'ram:RateApplicablePercent']);
    ACharge.ListFilledChildren(FFilled);
    Rest(APath, ['ram:ChargeIndicator', 'ram:CalculationPercent', 'ram:BasisAmount', 'ram:ActualAmount',
      'ram:ReasonCode', 'ram:Reason', 'ram:CategoryTradeTax']);
  end
  else
  begin
    ACharge.ListFilledChildren(FFilled);
    Rest(APath, ['ram:ChargeIndicator', 'ram:CalculationPercent', 'ram:BasisAmount', 'ram:ActualAmount',
      'ram:ReasonCode', 'ram:Reason']);
  end;
end;

{ Factur-X EXTENDED logistics service charge (BT-X-271 to BT-X-274): the
  invoice model has no field for it (plan, Phase 2 step 1), but the totals
  (BT-108, BT-109) and the VAT breakdown include it. It becomes a document
  level charge (BG-21) with the description as reason (BT-104), the amount
  and the VAT category and rate of the first tax, so every target stays
  consistent; EXTENDED writes it back as such a charge (its Schematron sums
  both alike). Reported as information.
  DE: Logistikkosten aus Factur-X EXTENDED (BT-X-271 bis BT-X-274): das
  Rechnungsmodell hat kein Feld dafuer (Fahrplan, Phase 2 Schritt 1), die
  Summen (BT-108, BT-109) und die Steueraufschluesselung enthalten sie aber.
  Sie werden zu einem Zuschlag auf Dokumentebene (BG-21) mit der
  Beschreibung als Grund (BT-104), dem Betrag sowie Steuerkategorie und
  -satz der ersten Steuer, damit jedes Ziel stimmig bleibt; EXTENDED
  schreibt sie als solchen Zuschlag zurueck (sein Schematron summiert
  beides gleich). Als Information gemeldet. }
procedure TCIIReadMapper.ReadLogisticsCharge(ACharge: TLandrixCIILogisticsServiceCharge;
  const APath: TLandrixEInvoiceString);
var
  Item: TLandrixInvoiceAllowanceCharge;
  Tax: TLandrixCIITradeTax;
begin
  Item := FInvoice.AllowanceCharges.AddAllowanceCharge;
  Item.ChargeIndicator := True;
  Item.Reason := ACharge.Description;
  Item.Amount := Amount(ACharge.AppliedAmount, APath + '/ram:AppliedAmount');
  if ACharge.AppliedTradeTax.Count > 0 then
  begin
    Tax := ACharge.AppliedTradeTax[0];
    ReadTaxCategory(Tax.CategoryCode, APath + '/ram:AppliedTradeTax/ram:CategoryCode', Item.TaxCategory,
      Item.TaxCategoryOther);
    Item.TaxPercent := Decimal(Tax.RateApplicablePercent, APath + '/ram:AppliedTradeTax/ram:RateApplicablePercent');
    if (Tax.TypeCode <> '') and (Tax.TypeCode <> 'VAT') then
      NotMapped(APath + '/ram:AppliedTradeTax/ram:TypeCode', 'tax type ' + Tax.TypeCode);
    Tax.ListFilledChildren(FFilled);
    Rest(APath + '/ram:AppliedTradeTax', ['ram:TypeCode', 'ram:CategoryCode', 'ram:RateApplicablePercent']);
    Excess(ACharge.AppliedTradeTax.Count, APath + '/ram:AppliedTradeTax');
  end;
  ACharge.ListFilledChildren(FFilled);
  Rest(APath, ['ram:Description', 'ram:AppliedAmount', 'ram:AppliedTradeTax']);
  Report(edk_NotMapped, APath, 'logistics service charge (BT-X-271 to BT-X-274) ' + ACharge.Description +
    ' taken over as document level charge (BG-21)', eds_Info);
end;

{ BG-30 line VAT (the first tax), BG-26 period, BG-27/BG-28, BT-131, BT-128
  (only the reference with type 130), BT-133.
  DE: BG-30 Steuer der Position (die erste), BG-26 Zeitraum, BG-27/BG-28,
  BT-131, BT-128 (nur die Referenz mit Art 130), BT-133. }
procedure TCIIReadMapper.ReadLineSettlement(ALine: TLandrixInvoiceLine; ASettlement: TLandrixCIILineTradeSettlement;
  const APath: TLandrixEInvoiceString; out ANoAmount: Boolean);
var
  I: TLandrixEInvoiceListIndex;
  Tax: TLandrixCIITradeTax;
  Document: TLandrixCIIReferencedDocument;
  ObjectFound: Boolean;
begin
  if ASettlement.ApplicableTradeTax.Count > 0 then
  begin
    Tax := ASettlement.ApplicableTradeTax[0];
    ALine.TaxExemptionReason := Tax.ExemptionReason;
    ReadTaxCategory(Tax.CategoryCode, APath + '/ram:ApplicableTradeTax/ram:CategoryCode', ALine.TaxCategory,
      ALine.TaxCategoryOther);
    ALine.TaxPercent := Decimal(Tax.RateApplicablePercent, APath + '/ram:ApplicableTradeTax/ram:RateApplicablePercent');
    if (Tax.TypeCode <> '') and (Tax.TypeCode <> 'VAT') then
      NotMapped(APath + '/ram:ApplicableTradeTax/ram:TypeCode', 'tax type ' + Tax.TypeCode);
    Tax.ListFilledChildren(FFilled);
    Rest(APath + '/ram:ApplicableTradeTax', ['ram:TypeCode', 'ram:ExemptionReason', 'ram:CategoryCode',
      'ram:RateApplicablePercent']);
    Excess(ASettlement.ApplicableTradeTax.Count, APath + '/ram:ApplicableTradeTax');
  end;
  ALine.InvoiceLinePeriodStartDate := Date(ASettlement.BillingSpecifiedPeriod.StartDateTime,
    APath + '/ram:BillingSpecifiedPeriod/ram:StartDateTime');
  ALine.InvoiceLinePeriodEndDate := Date(ASettlement.BillingSpecifiedPeriod.EndDateTime,
    APath + '/ram:BillingSpecifiedPeriod/ram:EndDateTime');
  ASettlement.BillingSpecifiedPeriod.ListFilledChildren(FFilled);
  Rest(APath + '/ram:BillingSpecifiedPeriod', ['ram:StartDateTime', 'ram:EndDateTime']);
  for I := 0 to ASettlement.SpecifiedTradeAllowanceCharge.Count - 1 do
    ReadAllowanceCharge(ALine.AllowanceCharges.AddAllowanceCharge, ASettlement.SpecifiedTradeAllowanceCharge[I],
      APath + '/ram:SpecifiedTradeAllowanceCharge', False);
  ANoAmount := ASettlement.SpecifiedTradeSettlementLineMonetarySummation.LineTotalAmount.Value = '';
  ALine.LineAmount := Amount(ASettlement.SpecifiedTradeSettlementLineMonetarySummation.LineTotalAmount,
    APath + '/ram:SpecifiedTradeSettlementLineMonetarySummation/ram:LineTotalAmount');
  ASettlement.SpecifiedTradeSettlementLineMonetarySummation.ListFilledChildren(FFilled);
  Rest(APath + '/ram:SpecifiedTradeSettlementLineMonetarySummation', ['ram:LineTotalAmount']);
  ObjectFound := False;
  for I := 0 to ASettlement.AdditionalReferencedDocument.Count - 1 do
  begin
    Document := ASettlement.AdditionalReferencedDocument[I];
    if (Document.TypeCode = '130') and not ObjectFound then
    begin
      ObjectFound := True;
      ALine.ObjectIdentifier := IDValue(Document.IssuerAssignedID, APath + '/ram:AdditionalReferencedDocument/ram:IssuerAssignedID');
      ALine.ObjectIdentifierSchemeID := Document.ReferenceTypeCode;
      Document.ListFilledChildren(FFilled);
      Rest(APath + '/ram:AdditionalReferencedDocument', ['ram:IssuerAssignedID', 'ram:TypeCode',
        'ram:ReferenceTypeCode']);
    end
    else
      NotMapped(APath + '/ram:AdditionalReferencedDocument', 'line reference document ' +
        Document.IssuerAssignedID.Value);
  end;
  if ASettlement.ReceivableSpecifiedTradeAccountingAccount.Count > 0 then
  begin
    ALine.BuyerAccountingReference := IDValue(ASettlement.ReceivableSpecifiedTradeAccountingAccount[0].ID,
      APath + '/ram:ReceivableSpecifiedTradeAccountingAccount/ram:ID');
    ASettlement.ReceivableSpecifiedTradeAccountingAccount[0].ListFilledChildren(FFilled);
    Rest(APath + '/ram:ReceivableSpecifiedTradeAccountingAccount', ['ram:ID']);
    Excess(ASettlement.ReceivableSpecifiedTradeAccountingAccount.Count,
      APath + '/ram:ReceivableSpecifiedTradeAccountingAccount');
  end;
  ASettlement.ListFilledChildren(FFilled);
  Rest(APath, ['ram:ApplicableTradeTax', 'ram:BillingSpecifiedPeriod', 'ram:SpecifiedTradeAllowanceCharge',
    'ram:SpecifiedTradeSettlementLineMonetarySummation', 'ram:AdditionalReferencedDocument',
    'ram:ReceivableSpecifiedTradeAccountingAccount']);
end;

procedure TCIIReadMapper.ReadAddress(AAddress: TLandrixInvoiceAddress; ASource: TLandrixCIITradeAddress;
  const APath: TLandrixEInvoiceString);
begin
  AAddress.PostalZone := CodeValue(ASource.PostcodeCode, APath + '/ram:PostcodeCode');
  AAddress.StreetName := ASource.LineOne;
  AAddress.AdditionalStreetName := ASource.LineTwo;
  AAddress.AddressLine := ASource.LineThree;
  AAddress.City := ASource.CityName;
  AAddress.CountryCode := ASource.CountryID;
  AAddress.CountrySubentity := ASource.CountrySubDivisionName;
  ASource.ListFilledChildren(FFilled);
  Rest(APath, ['ram:PostcodeCode', 'ram:LineOne', 'ram:LineTwo', 'ram:LineThree', 'ram:CityName', 'ram:CountryID',
    'ram:CountrySubDivisionName']);
end;

{ BG-4/BG-7: first identifier and global identifier, name, BT-33 (seller
  only), legal organization, first contact, address, electronic address,
  VAT (scheme VA) and tax number (scheme FC).
  DE: BG-4/BG-7: erste Kennung und globale Kennung, Name, BT-33 (nur
  Verkaeufer), Registrierung, erster Kontakt, Anschrift, elektronische
  Adresse, USt-IdNr. (Schema VA) und Steuernummer (Schema FC). }
procedure TCIIReadMapper.ReadParty(AParty: TLandrixInvoiceAccountingParty; ASource: TLandrixCIITradeParty;
  const APath: TLandrixEInvoiceString; AIsSeller: Boolean);
var
  I: TLandrixEInvoiceListIndex;
  Contact: TLandrixCIITradeContact;
  Registration: TLandrixCIIID;
  Taken: array[0..9] of string;
begin
  if ASource.ID.Count > 0 then
    AParty.IdentifierSellerBuyer := IDValue(ASource.ID[0], APath + '/ram:ID');
  Excess(ASource.ID.Count, APath + '/ram:ID');
  if ASource.GlobalID.Count > 0 then
  begin
    AParty.GlobalIdentifierSellerBuyer := ASource.GlobalID[0].Value;
    AParty.GlobalIdentifierSellerBuyerSchemeID := ASource.GlobalID[0].SchemeID;
  end;
  Excess(ASource.GlobalID.Count, APath + '/ram:GlobalID');
  AParty.RegistrationName := ASource.Name;
  if AIsSeller then
    AParty.AdditionalLegalInformationSeller := ASource.Description;
  AParty.CompanyID := ASource.SpecifiedLegalOrganization.ID.Value;
  AParty.CompanyIDSchemeID := ASource.SpecifiedLegalOrganization.ID.SchemeID;
  AParty.Name := ASource.SpecifiedLegalOrganization.TradingBusinessName;
  ASource.SpecifiedLegalOrganization.ListFilledChildren(FFilled);
  Rest(APath + '/ram:SpecifiedLegalOrganization', ['ram:ID', 'ram:TradingBusinessName']);
  if ASource.DefinedTradeContact.Count > 0 then
  begin
    Contact := ASource.DefinedTradeContact[0];
    AParty.ContactName := Contact.PersonName;
    AParty.ContactDepartment := Contact.DepartmentName;
    AParty.ContactTelephone := Contact.TelephoneUniversalCommunication.CompleteNumber;
    AParty.ContactElectronicMail := IDValue(Contact.EmailURIUniversalCommunication.URIID,
      APath + '/ram:DefinedTradeContact/ram:EmailURIUniversalCommunication/ram:URIID');
    Contact.TelephoneUniversalCommunication.ListFilledChildren(FFilled);
    Rest(APath + '/ram:DefinedTradeContact/ram:TelephoneUniversalCommunication', ['ram:CompleteNumber']);
    Contact.EmailURIUniversalCommunication.ListFilledChildren(FFilled);
    Rest(APath + '/ram:DefinedTradeContact/ram:EmailURIUniversalCommunication', ['ram:URIID']);
    Contact.ListFilledChildren(FFilled);
    Rest(APath + '/ram:DefinedTradeContact', ['ram:PersonName', 'ram:DepartmentName',
      'ram:TelephoneUniversalCommunication', 'ram:EmailURIUniversalCommunication']);
  end;
  Excess(ASource.DefinedTradeContact.Count, APath + '/ram:DefinedTradeContact');
  ReadAddress(AParty.Address, ASource.PostalTradeAddress, APath + '/ram:PostalTradeAddress');
  AParty.ElectronicAddressSellerBuyer := ASource.URIUniversalCommunication.URIID.Value;
  AParty.ElectronicAddressSellerBuyerSchemeID := ASource.URIUniversalCommunication.URIID.SchemeID;
  ASource.URIUniversalCommunication.ListFilledChildren(FFilled);
  Rest(APath + '/ram:URIUniversalCommunication', ['ram:URIID']);
  for I := 0 to ASource.SpecifiedTaxRegistration.Count - 1 do
  begin
    Registration := ASource.SpecifiedTaxRegistration[I].ID;
    if (Registration.SchemeID = 'VA') and (AParty.VATCompanyID = '') then
      AParty.VATCompanyID := Registration.Value
    else if (Registration.SchemeID = 'FC') and (AParty.VATCompanyNumber = '') then
      AParty.VATCompanyNumber := Registration.Value
    else
      NotMapped(APath + '/ram:SpecifiedTaxRegistration', 'tax registration ' + Registration.Value +
        ' (scheme ' + Registration.SchemeID + ')');
  end;
  Taken[0] := 'ram:ID';
  Taken[1] := 'ram:GlobalID';
  Taken[2] := 'ram:Name';
  Taken[3] := 'ram:SpecifiedLegalOrganization';
  Taken[4] := 'ram:DefinedTradeContact';
  Taken[5] := 'ram:PostalTradeAddress';
  Taken[6] := 'ram:URIUniversalCommunication';
  Taken[7] := 'ram:SpecifiedTaxRegistration';
  Taken[8] := '';
  Taken[9] := '';
  if AIsSeller then
    Taken[8] := 'ram:Description';
  ASource.ListFilledChildren(FFilled);
  Rest(APath, Taken);
end;

{ BG-10 payee, BG-11 tax representative, BG-X-36 invoicee: the first
  identifier (an identifier or a global identifier), name, legal
  registration with scheme, first contact, address and VAT identifier
  (scheme VA).
  DE: BG-10 Zahlungsempfaenger, BG-11 Steuervertreter, BG-X-36
  Rechnungsempfaenger: die erste Kennung (Kennung oder globale Kennung),
  Name, Registernummer mit Schema, erster Kontakt, Anschrift und USt-IdNr.
  (Schema VA). }
procedure TCIIReadMapper.ReadFurtherParty(AParty: TLandrixInvoiceParty; ASource: TLandrixCIITradeParty;
  const APath: TLandrixEInvoiceString);
var
  I: TLandrixEInvoiceListIndex;
  Contact: TLandrixCIITradeContact;
  Registration: TLandrixCIIID;
begin
  if ASource.ID.Count > 0 then
  begin
    AParty.Identifier := ASource.ID[0].Value;
    AParty.IdentifierSchemeID := ASource.ID[0].SchemeID;
  end;
  Excess(ASource.ID.Count, APath + '/ram:ID');
  for I := 0 to ASource.GlobalID.Count - 1 do
    if AParty.Identifier = '' then
    begin
      AParty.Identifier := ASource.GlobalID[I].Value;
      AParty.IdentifierSchemeID := ASource.GlobalID[I].SchemeID;
    end
    else
      NotMapped(APath + '/ram:GlobalID', 'further identifier ' + ASource.GlobalID[I].Value);
  AParty.Name := ASource.Name;
  AParty.CompanyID := ASource.SpecifiedLegalOrganization.ID.Value;
  AParty.CompanyIDSchemeID := ASource.SpecifiedLegalOrganization.ID.SchemeID;
  ASource.SpecifiedLegalOrganization.ListFilledChildren(FFilled);
  Rest(APath + '/ram:SpecifiedLegalOrganization', ['ram:ID']);
  if ASource.DefinedTradeContact.Count > 0 then
  begin
    Contact := ASource.DefinedTradeContact[0];
    AParty.ContactName := Contact.PersonName;
    AParty.ContactDepartment := Contact.DepartmentName;
    AParty.ContactTelephone := Contact.TelephoneUniversalCommunication.CompleteNumber;
    AParty.ContactElectronicMail := IDValue(Contact.EmailURIUniversalCommunication.URIID,
      APath + '/ram:DefinedTradeContact/ram:EmailURIUniversalCommunication/ram:URIID');
    Contact.TelephoneUniversalCommunication.ListFilledChildren(FFilled);
    Rest(APath + '/ram:DefinedTradeContact/ram:TelephoneUniversalCommunication', ['ram:CompleteNumber']);
    Contact.EmailURIUniversalCommunication.ListFilledChildren(FFilled);
    Rest(APath + '/ram:DefinedTradeContact/ram:EmailURIUniversalCommunication', ['ram:URIID']);
    Contact.ListFilledChildren(FFilled);
    Rest(APath + '/ram:DefinedTradeContact', ['ram:PersonName', 'ram:DepartmentName',
      'ram:TelephoneUniversalCommunication', 'ram:EmailURIUniversalCommunication']);
  end;
  Excess(ASource.DefinedTradeContact.Count, APath + '/ram:DefinedTradeContact');
  ReadAddress(AParty.Address, ASource.PostalTradeAddress, APath + '/ram:PostalTradeAddress');
  for I := 0 to ASource.SpecifiedTaxRegistration.Count - 1 do
  begin
    Registration := ASource.SpecifiedTaxRegistration[I].ID;
    if (Registration.SchemeID = 'VA') and (AParty.VATCompanyID = '') then
      AParty.VATCompanyID := Registration.Value
    else
      NotMapped(APath + '/ram:SpecifiedTaxRegistration', 'tax registration ' + Registration.Value +
        ' (scheme ' + Registration.SchemeID + ')');
  end;
  ASource.ListFilledChildren(FFilled);
  Rest(APath, ['ram:ID', 'ram:GlobalID', 'ram:Name', 'ram:SpecifiedLegalOrganization', 'ram:DefinedTradeContact',
    'ram:PostalTradeAddress', 'ram:SpecifiedTaxRegistration']);
end;

{ BG-24 attachments and BT-17/BT-18 references.
  DE: BG-24 Anlagen und BT-17/BT-18 Referenzen. }
procedure TCIIReadMapper.ReadAttachments;
var
  I: TLandrixEInvoiceListIndex;
  Source: TLandrixCIIReferencedDocument;
  Attachment: TLandrixInvoiceAttachment;
  Path: TLandrixEInvoiceString;
begin
  Path := Agreement + '/ram:AdditionalReferencedDocument';
  for I := 0 to FCII.SupplyChainTradeTransaction.ApplicableHeaderTradeAgreement.AdditionalReferencedDocument.Count - 1 do
  begin
    Source := FCII.SupplyChainTradeTransaction.ApplicableHeaderTradeAgreement.AdditionalReferencedDocument[I];
    Attachment := FInvoice.Attachments.AddAttachment(iat_application_None);
    Attachment.ID := IDValue(Source.IssuerAssignedID, Path + '/ram:IssuerAssignedID');
    Attachment.DocumentDescription := Source.Name;
    Attachment.ExternalReference := IDValue(Source.URIID, Path + '/ram:URIID');
    Attachment.TypeCode := iatc_None;
    if (Source.TypeCode <> '') and not LandrixEInvoiceAttachmentTypeCodeFromStr(Source.TypeCode, Attachment.TypeCode) then
    begin
      Attachment.TypeCode := iatc_None;
      UnknownCode(Source.TypeCode, Path + '/ram:TypeCode', Attachment.TypeCodeOther);
    end;
    if Source.AttachmentBinaryObject.Value <> '' then
    begin
      if not LandrixEInvoiceAttachmentTypeFromStr(Source.AttachmentBinaryObject.MimeCode, Attachment.AttachmentType) then
      begin
        Attachment.AttachmentType := iat_application_None;
        UnknownCode(Source.AttachmentBinaryObject.MimeCode, Path + '/ram:AttachmentBinaryObject/@mimeCode',
          Attachment.AttachmentTypeOther);
      end;
      Attachment.Filename := Source.AttachmentBinaryObject.Filename;
      try
        Attachment.SetDataFromBase64(Source.AttachmentBinaryObject.Value);
      except
        on E: Exception do
          Report(edk_ConversionFailed, Path + '/ram:AttachmentBinaryObject',
            'attachment data not decoded (' + TLandrixEInvoiceString(E.Message) + '); left empty', eds_Error);
      end;
    end;
    Source.ListFilledChildren(FFilled);
    if Attachment.TypeCode = iatc_130 then
    begin
      Attachment.SchemeID := Source.ReferenceTypeCode;
      Rest(Path, ['ram:IssuerAssignedID', 'ram:URIID', 'ram:TypeCode', 'ram:Name', 'ram:AttachmentBinaryObject',
        'ram:ReferenceTypeCode']);
    end
    else
      Rest(Path, ['ram:IssuerAssignedID', 'ram:URIID', 'ram:TypeCode', 'ram:Name', 'ram:AttachmentBinaryObject']);
  end;
end;

procedure TCIIReadMapper.ReadAgreement;
var
  Source: TLandrixCIIHeaderTradeAgreement;
begin
  Source := FCII.SupplyChainTradeTransaction.ApplicableHeaderTradeAgreement;
  FInvoice.BuyerReference := Source.BuyerReference;
  ReadParty(FInvoice.AccountingSupplierParty, Source.SellerTradeParty, Agreement + '/ram:SellerTradeParty', True);
  ReadParty(FInvoice.AccountingCustomerParty, Source.BuyerTradeParty, Agreement + '/ram:BuyerTradeParty', False);
  ReadFurtherParty(FInvoice.TaxRepresentativeParty, Source.SellerTaxRepresentativeTradeParty,
    Agreement + '/ram:SellerTaxRepresentativeTradeParty');
  FInvoice.SellerOrderReference := IDValue(Source.SellerOrderReferencedDocument.IssuerAssignedID,
    Agreement + '/ram:SellerOrderReferencedDocument/ram:IssuerAssignedID');
  SetDate(FInvoice.SellerOrderReferenceDate, FormattedDate(Source.SellerOrderReferencedDocument.FormattedIssueDateTime,
    Agreement + '/ram:SellerOrderReferencedDocument/ram:FormattedIssueDateTime'));
  Source.SellerOrderReferencedDocument.ListFilledChildren(FFilled);
  Rest(Agreement + '/ram:SellerOrderReferencedDocument', ['ram:IssuerAssignedID', 'ram:FormattedIssueDateTime']);
  FInvoice.PurchaseOrderReference := IDValue(Source.BuyerOrderReferencedDocument.IssuerAssignedID,
    Agreement + '/ram:BuyerOrderReferencedDocument/ram:IssuerAssignedID');
  SetDate(FInvoice.PurchaseOrderReferenceDate, FormattedDate(Source.BuyerOrderReferencedDocument.FormattedIssueDateTime,
    Agreement + '/ram:BuyerOrderReferencedDocument/ram:FormattedIssueDateTime'));
  Source.BuyerOrderReferencedDocument.ListFilledChildren(FFilled);
  Rest(Agreement + '/ram:BuyerOrderReferencedDocument', ['ram:IssuerAssignedID', 'ram:FormattedIssueDateTime']);
  FInvoice.ContractDocumentReference := IDValue(Source.ContractReferencedDocument.IssuerAssignedID,
    Agreement + '/ram:ContractReferencedDocument/ram:IssuerAssignedID');
  Source.ContractReferencedDocument.ListFilledChildren(FFilled);
  Rest(Agreement + '/ram:ContractReferencedDocument', ['ram:IssuerAssignedID']);
  ReadAttachments;
  FInvoice.ProjectReference := IDValue(Source.SpecifiedProcuringProject.ID,
    Agreement + '/ram:SpecifiedProcuringProject/ram:ID');
  { the writer puts the fixed name 'Project reference'; another name is lost }
  if (Source.SpecifiedProcuringProject.Name <> '') and (Source.SpecifiedProcuringProject.Name <> 'Project reference') then
    NotMapped(Agreement + '/ram:SpecifiedProcuringProject/ram:Name', 'project name');
  Source.SpecifiedProcuringProject.ListFilledChildren(FFilled);
  Rest(Agreement + '/ram:SpecifiedProcuringProject', ['ram:ID', 'ram:Name']);
  Source.ListFilledChildren(FFilled);
  Rest(Agreement, ['ram:BuyerReference', 'ram:SellerTradeParty', 'ram:BuyerTradeParty',
    'ram:SellerTaxRepresentativeTradeParty', 'ram:SellerOrderReferencedDocument', 'ram:BuyerOrderReferencedDocument', 'ram:ContractReferencedDocument',
    'ram:AdditionalReferencedDocument', 'ram:SpecifiedProcuringProject']);
end;

{ BG-13: BT-71 from the global identifier (BT-71-0), else from the
  identifier; BT-70, BG-15, BG-X-26 contact, BT-72, BT-16, BT-15, delivery
  note.
  DE: BG-13: BT-71 aus der globalen Kennung (BT-71-0), sonst aus der
  Kennung; BT-70, BG-15, BG-X-26 Kontakt, BT-72, BT-16, BT-15,
  Lieferschein. }
procedure TCIIReadMapper.ReadDelivery;
var
  Source: TLandrixCIIHeaderTradeDelivery;
  Info: TLandrixInvoiceDeliveryInformation;
  ShipTo: TLandrixCIITradeParty;
  Contact: TLandrixCIITradeContact;
  Path: TLandrixEInvoiceString;
begin
  Source := FCII.SupplyChainTradeTransaction.ApplicableHeaderTradeDelivery;
  Info := FInvoice.DeliveryInformation;
  ShipTo := Source.ShipToTradeParty;
  Path := Delivery + '/ram:ShipToTradeParty';
  if ShipTo.GlobalID.Count > 0 then
  begin
    Info.LocationIdentifier := ShipTo.GlobalID[0].Value;
    Info.LocationIdentifierSchemeID := ShipTo.GlobalID[0].SchemeID;
    if ShipTo.ID.Count > 0 then
      NotMapped(Path + '/ram:ID', 'location identifier ' + ShipTo.ID[0].Value + ' besides a global identifier');
  end
  else if ShipTo.ID.Count > 0 then
  begin
    Info.LocationIdentifier := ShipTo.ID[0].Value;
    Info.LocationIdentifierSchemeID := ShipTo.ID[0].SchemeID;
  end;
  Excess(ShipTo.GlobalID.Count, Path + '/ram:GlobalID');
  Excess(ShipTo.ID.Count, Path + '/ram:ID');
  Info.Name := ShipTo.Name;
  if ShipTo.DefinedTradeContact.Count > 0 then
  begin
    Contact := ShipTo.DefinedTradeContact[0];
    Info.ContactName := Contact.PersonName;
    Info.ContactTelephone := Contact.TelephoneUniversalCommunication.CompleteNumber;
    Info.ContactElectronicMail := IDValue(Contact.EmailURIUniversalCommunication.URIID,
      Path + '/ram:DefinedTradeContact/ram:EmailURIUniversalCommunication/ram:URIID');
    Contact.TelephoneUniversalCommunication.ListFilledChildren(FFilled);
    Rest(Path + '/ram:DefinedTradeContact/ram:TelephoneUniversalCommunication', ['ram:CompleteNumber']);
    Contact.EmailURIUniversalCommunication.ListFilledChildren(FFilled);
    Rest(Path + '/ram:DefinedTradeContact/ram:EmailURIUniversalCommunication', ['ram:URIID']);
    Contact.ListFilledChildren(FFilled);
    Rest(Path + '/ram:DefinedTradeContact', ['ram:PersonName', 'ram:TelephoneUniversalCommunication',
      'ram:EmailURIUniversalCommunication']);
  end;
  Excess(ShipTo.DefinedTradeContact.Count, Path + '/ram:DefinedTradeContact');
  ReadAddress(Info.Address, ShipTo.PostalTradeAddress, Path + '/ram:PostalTradeAddress');
  ShipTo.ListFilledChildren(FFilled);
  Rest(Path, ['ram:ID', 'ram:GlobalID', 'ram:Name', 'ram:DefinedTradeContact', 'ram:PostalTradeAddress']);
  Info.ActualDeliveryDate := Date(Source.ActualDeliverySupplyChainEvent.OccurrenceDateTime,
    Delivery + '/ram:ActualDeliverySupplyChainEvent/ram:OccurrenceDateTime');
  Source.ActualDeliverySupplyChainEvent.ListFilledChildren(FFilled);
  Rest(Delivery + '/ram:ActualDeliverySupplyChainEvent', ['ram:OccurrenceDateTime']);
  FInvoice.DeliveryReceiptNumber := IDValue(Source.DespatchAdviceReferencedDocument.IssuerAssignedID,
    Delivery + '/ram:DespatchAdviceReferencedDocument/ram:IssuerAssignedID');
  FInvoice.DeliveryReceiptDate := FormattedDate(Source.DespatchAdviceReferencedDocument.FormattedIssueDateTime,
    Delivery + '/ram:DespatchAdviceReferencedDocument/ram:FormattedIssueDateTime');
  Source.DespatchAdviceReferencedDocument.ListFilledChildren(FFilled);
  Rest(Delivery + '/ram:DespatchAdviceReferencedDocument', ['ram:IssuerAssignedID', 'ram:FormattedIssueDateTime']);
  FInvoice.ReceiptDocumentReference := IDValue(Source.ReceivingAdviceReferencedDocument.IssuerAssignedID,
    Delivery + '/ram:ReceivingAdviceReferencedDocument/ram:IssuerAssignedID');
  Source.ReceivingAdviceReferencedDocument.ListFilledChildren(FFilled);
  Rest(Delivery + '/ram:ReceivingAdviceReferencedDocument', ['ram:IssuerAssignedID']);
  FInvoice.DeliveryReceiptNumberExtended := IDValue(Source.DeliveryNoteReferencedDocument.IssuerAssignedID,
    Delivery + '/ram:DeliveryNoteReferencedDocument/ram:IssuerAssignedID');
  FInvoice.DeliveryReceiptDateExtended := FormattedDate(Source.DeliveryNoteReferencedDocument.FormattedIssueDateTime,
    Delivery + '/ram:DeliveryNoteReferencedDocument/ram:FormattedIssueDateTime');
  Source.DeliveryNoteReferencedDocument.ListFilledChildren(FFilled);
  Rest(Delivery + '/ram:DeliveryNoteReferencedDocument', ['ram:IssuerAssignedID', 'ram:FormattedIssueDateTime']);
  Source.ListFilledChildren(FFilled);
  Rest(Delivery, ['ram:ShipToTradeParty', 'ram:ActualDeliverySupplyChainEvent', 'ram:DespatchAdviceReferencedDocument',
    'ram:ReceivingAdviceReferencedDocument', 'ram:DeliveryNoteReferencedDocument']);
end;

procedure TCIIReadMapper.ReadPaymentMeans(ASettlement: TLandrixCIIHeaderTradeSettlement);
var
  I: TLandrixEInvoiceListIndex;
  Source: TLandrixCIITradeSettlementPaymentMeans;
  Payment: TLandrixInvoicePaymentType;
  Path: TLandrixEInvoiceString;
begin
  Path := Settlement + '/ram:SpecifiedTradeSettlementPaymentMeans';
  for I := 0 to ASettlement.SpecifiedTradeSettlementPaymentMeans.Count - 1 do
  begin
    Source := ASettlement.SpecifiedTradeSettlementPaymentMeans[I];
    Payment := FInvoice.PaymentTypes.AddPaymentType;
    if (Source.TypeCode <> '') and not LandrixEInvoicePaymentMeansCodeFromStr(Source.TypeCode, Payment.PaymentMeansCode) then
    begin
      Payment.PaymentMeansCode := ipmc_NotImplemented;
      UnknownCode(Source.TypeCode, Path + '/ram:TypeCode', Payment.PaymentMeansCodeOther);
    end;
    Payment.PaymentMeansInformation := Source.Information;
    if not Source.PayerPartyDebtorFinancialAccount.IsEmpty then
    begin
      Payment.FinancialAccount := IDValue(Source.PayerPartyDebtorFinancialAccount.IBANID,
        Path + '/ram:PayerPartyDebtorFinancialAccount/ram:IBANID');
      Source.PayerPartyDebtorFinancialAccount.ListFilledChildren(FFilled);
      Rest(Path + '/ram:PayerPartyDebtorFinancialAccount', ['ram:IBANID']);
    end;
    if not Source.ApplicableTradeSettlementFinancialCard.IsEmpty then
    begin
      if Payment.FinancialAccount <> '' then
        NotMapped(Path + '/ram:ApplicableTradeSettlementFinancialCard', 'second account of one payment means')
      else
      begin
        Payment.FinancialAccount := IDValue(Source.ApplicableTradeSettlementFinancialCard.ID,
          Path + '/ram:ApplicableTradeSettlementFinancialCard/ram:ID');
        Payment.FinancialAccountName := Source.ApplicableTradeSettlementFinancialCard.CardholderName;
        Source.ApplicableTradeSettlementFinancialCard.ListFilledChildren(FFilled);
        Rest(Path + '/ram:ApplicableTradeSettlementFinancialCard', ['ram:ID', 'ram:CardholderName']);
      end;
    end;
    if not Source.PayeePartyCreditorFinancialAccount.IsEmpty then
    begin
      if Payment.FinancialAccount <> '' then
        NotMapped(Path + '/ram:PayeePartyCreditorFinancialAccount', 'second account of one payment means')
      else
      begin
        { BT-84 is the IBAN or, without one, the proprietary identifier
          DE: BT-84 ist die IBAN oder, ohne IBAN, die proprietaere Kennung }
        Payment.FinancialAccountName := Source.PayeePartyCreditorFinancialAccount.AccountName;
        Source.PayeePartyCreditorFinancialAccount.ListFilledChildren(FFilled);
        if Source.PayeePartyCreditorFinancialAccount.IBANID.Value <> '' then
        begin
          Payment.FinancialAccount := IDValue(Source.PayeePartyCreditorFinancialAccount.IBANID,
            Path + '/ram:PayeePartyCreditorFinancialAccount/ram:IBANID');
          Rest(Path + '/ram:PayeePartyCreditorFinancialAccount', ['ram:IBANID', 'ram:AccountName']);
        end
        else
        begin
          Payment.FinancialAccount := IDValue(Source.PayeePartyCreditorFinancialAccount.ProprietaryID,
            Path + '/ram:PayeePartyCreditorFinancialAccount/ram:ProprietaryID');
          Rest(Path + '/ram:PayeePartyCreditorFinancialAccount', ['ram:ProprietaryID', 'ram:AccountName']);
        end;
      end;
    end;
    Payment.FinancialInstitutionBranch := IDValue(Source.PayeeSpecifiedCreditorFinancialInstitution.BICID,
      Path + '/ram:PayeeSpecifiedCreditorFinancialInstitution/ram:BICID');
    Source.PayeeSpecifiedCreditorFinancialInstitution.ListFilledChildren(FFilled);
    Rest(Path + '/ram:PayeeSpecifiedCreditorFinancialInstitution', ['ram:BICID']);
    Source.ListFilledChildren(FFilled);
    Rest(Path, ['ram:TypeCode', 'ram:Information', 'ram:ApplicableTradeSettlementFinancialCard',
      'ram:PayerPartyDebtorFinancialAccount', 'ram:PayeePartyCreditorFinancialAccount',
      'ram:PayeeSpecifiedCreditorFinancialInstitution']);
  end;
end;

{ BT-20/BT-9/BT-89: one term with a due date or #SKONTO# text is the
  XRechnung form; otherwise the Factur-X form: the first term without
  discount terms is the net term (in any position), terms with discount
  terms become cash discounts 1 to 3 with their text, their days counted
  from the issue date.
  DE: BT-20/BT-9/BT-89: eine Bedingung mit Faelligkeit oder #SKONTO#-Text
  ist die XRechnung-Form; sonst die Factur-X-Form: die erste Bedingung ohne
  Skontoangaben ist die Nettobedingung (an beliebiger Stelle), Bedingungen
  mit Skontoangaben werden zu Skonto 1 bis 3 mit ihrem Text, ihre Tage ab
  Rechnungsdatum gezaehlt. }
procedure TCIIReadMapper.ReadPaymentTerms(ASettlement: TLandrixCIIHeaderTradeSettlement);
var
  Terms: TLandrixCIITradePaymentTermsList;
  Term: TLandrixCIITradePaymentTerms;
  Discount: TLandrixCIITradePaymentDiscountTerms;
  I: TLandrixEInvoiceListIndex;
  Path: TLandrixEInvoiceString;
  Days: Integer;
  Percent: Double;
  Base, Actual: Currency;
  Basis: TDateTime;
  NetFound: Boolean;
begin
  Terms := ASettlement.SpecifiedTradePaymentTerms;
  Path := Settlement + '/ram:SpecifiedTradePaymentTerms';
  if Terms.Count = 0 then
    Exit;
  FInvoice.PaymentMandateID := IDValue(Terms[0].DirectDebitMandateID, Path + '/ram:DirectDebitMandateID');
  FInvoice.PaymentTermsType := iptt_None;
  if (Terms.Count = 1) and Terms[0].ApplicableTradePaymentDiscountTerms.IsEmpty and
     ((Terms[0].DueDateDateTime.Value <> '') or (Pos('#SKONTO#', Terms[0].Description) > 0)) then
  begin
    LandrixEInvoiceReadPaymentTermsText(FInvoice, Terms[0].Description);
    FInvoice.InvoiceDueDate := Date(Terms[0].DueDateDateTime, Path + '/ram:DueDateDateTime');
    Terms[0].ListFilledChildren(FFilled);
    Rest(Path, ['ram:Description', 'ram:DueDateDateTime', 'ram:DirectDebitMandateID']);
    Exit;
  end;
  NetFound := False;
  for I := 0 to Terms.Count - 1 do
  begin
    Term := Terms[I];
    if Term.ApplicableTradePaymentDiscountTerms.IsEmpty then
    begin
      if NetFound then
      begin
        NotMapped(Path, 'further payment term');
        Continue;
      end;
      NetFound := True;
      { a net term after the discount terms keeps them }
      if FInvoice.PaymentTermsType = iptt_None then
        FInvoice.PaymentTermsType := iptt_Net;
      FInvoice.PaymentTermNetNote := Term.Description;
      FInvoice.InvoiceDueDate := Date(Term.DueDateDateTime, Path + '/ram:DueDateDateTime');
      if (I > 0) and (Term.DirectDebitMandateID.Value <> '') then
        FInvoice.PaymentMandateID := IDValue(Term.DirectDebitMandateID, Path + '/ram:DirectDebitMandateID');
      Term.ListFilledChildren(FFilled);
      Rest(Path, ['ram:Description', 'ram:DueDateDateTime', 'ram:DirectDebitMandateID']);
      Continue;
    end;
    Discount := Term.ApplicableTradePaymentDiscountTerms;
    if FInvoice.PaymentTermsType = iptt_CashDiscount3 then
    begin
      NotMapped(Path, 'fourth cash discount');
      Continue;
    end;
    { the invoice model counts discount days from the issue date }
    Days := 0;
    if Discount.BasisPeriodMeasure.Value <> '' then
    begin
      Days := Integer(Trunc(Decimal(Discount.BasisPeriodMeasure.Value, Path + '/ram:ApplicableTradePaymentDiscountTerms/ram:BasisPeriodMeasure')));
      Basis := Date(Discount.BasisDateTime, Path + '/ram:ApplicableTradePaymentDiscountTerms/ram:BasisDateTime');
      if (Basis > 0) and (FInvoice.InvoiceIssueDate > 0) then
        Days := Days + Integer(Trunc(Basis) - Trunc(FInvoice.InvoiceIssueDate));
    end
    else if (Term.DueDateDateTime.Value <> '') and (FInvoice.InvoiceIssueDate > 0) then
    begin
      Basis := Date(Term.DueDateDateTime, Path + '/ram:DueDateDateTime');
      if Basis > 0 then
        Days := Integer(Trunc(Basis) - Trunc(FInvoice.InvoiceIssueDate));
    end;
    if (I > 0) and (Term.DirectDebitMandateID.Value <> '') then
    begin
      if FInvoice.PaymentMandateID = '' then
        FInvoice.PaymentMandateID := IDValue(Term.DirectDebitMandateID, Path + '/ram:DirectDebitMandateID')
      else if Term.DirectDebitMandateID.Value <> FInvoice.PaymentMandateID then
        NotMapped(Path + '/ram:DirectDebitMandateID', 'second mandate reference');
    end;
    Percent := Decimal(Discount.CalculationPercent, Path + '/ram:ApplicableTradePaymentDiscountTerms/ram:CalculationPercent');
    Base := Amount(Discount.BasisAmount, Path + '/ram:ApplicableTradePaymentDiscountTerms/ram:BasisAmount');
    Actual := Amount(Discount.ActualDiscountAmount, Path + '/ram:ApplicableTradePaymentDiscountTerms/ram:ActualDiscountAmount');
    case FInvoice.PaymentTermsType of
      iptt_None, iptt_Net:
        begin
          FInvoice.PaymentTermsType := iptt_CashDiscount1;
          FInvoice.PaymentTermCashDiscount1Days := Days;
          FInvoice.PaymentTermCashDiscount1Percent := Percent;
          FInvoice.PaymentTermCashDiscount1Base := Base;
          FInvoice.PaymentTermCashDiscount1ActualAmount := Actual;
          FInvoice.PaymentTermCashDiscount1Note := Term.Description;
        end;
      iptt_CashDiscount1:
        begin
          FInvoice.PaymentTermsType := iptt_CashDiscount2;
          FInvoice.PaymentTermCashDiscount2Days := Days;
          FInvoice.PaymentTermCashDiscount2Percent := Percent;
          FInvoice.PaymentTermCashDiscount2Base := Base;
          FInvoice.PaymentTermCashDiscount2ActualAmount := Actual;
          FInvoice.PaymentTermCashDiscount2Note := Term.Description;
        end;
    else
      begin
        FInvoice.PaymentTermsType := iptt_CashDiscount3;
        FInvoice.PaymentTermCashDiscount3Days := Days;
        FInvoice.PaymentTermCashDiscount3Percent := Percent;
        FInvoice.PaymentTermCashDiscount3Base := Base;
        FInvoice.PaymentTermCashDiscount3ActualAmount := Actual;
        FInvoice.PaymentTermCashDiscount3Note := Term.Description;
      end;
    end;
    Discount.ListFilledChildren(FFilled);
    Rest(Path + '/ram:ApplicableTradePaymentDiscountTerms', ['ram:BasisDateTime', 'ram:BasisPeriodMeasure',
      'ram:BasisAmount', 'ram:CalculationPercent', 'ram:ActualDiscountAmount']);
    { the due date of a discount term follows from basis and period }
    Term.ListFilledChildren(FFilled);
    Rest(Path, ['ram:Description', 'ram:DueDateDateTime', 'ram:ApplicableTradePaymentDiscountTerms',
      'ram:DirectDebitMandateID']);
  end;
end;

procedure TCIIReadMapper.ReadTotals(ASettlement: TLandrixCIIHeaderTradeSettlement);
var
  Sum: TLandrixCIITradeSettlementHeaderMonetarySummation;
  TaxTotal: TLandrixCIIAmount;
  Path: TLandrixEInvoiceString;
  I, Chosen: TLandrixEInvoiceListIndex;
  Value, Check: Currency;
  Rounded: Boolean;
begin
  Sum := ASettlement.SpecifiedTradeSettlementHeaderMonetarySummation;
  Path := Settlement + '/ram:SpecifiedTradeSettlementHeaderMonetarySummation';
  FInvoice.LineAmount := Amount(Sum.LineTotalAmount, Path + '/ram:LineTotalAmount');
  FInvoice.ChargeTotalAmount := Amount(Sum.ChargeTotalAmount, Path + '/ram:ChargeTotalAmount');
  FInvoice.AllowanceTotalAmount := Amount(Sum.AllowanceTotalAmount, Path + '/ram:AllowanceTotalAmount');
  FInvoice.TaxExclusiveAmount := Amount(Sum.TaxBasisTotalAmount, Path + '/ram:TaxBasisTotalAmount');
  { BT-110 is the total in the invoice currency (else the first); without
    BT-6 the VAT accounting currency is its currency; the first other
    total in the differing BT-6 is BT-111 }
  Chosen := -1;
  for I := 0 to Sum.TaxTotalAmount.Count - 1 do
    if (Chosen < 0) and ((Sum.TaxTotalAmount[I].CurrencyID = '') or
       (Sum.TaxTotalAmount[I].CurrencyID = FInvoice.InvoiceCurrencyCode)) then
      Chosen := I;
  if (Chosen < 0) and (Sum.TaxTotalAmount.Count > 0) then
    Chosen := 0;
  for I := 0 to Sum.TaxTotalAmount.Count - 1 do
    if I <> Chosen then
    begin
      TaxTotal := Sum.TaxTotalAmount[I];
      if (FInvoice.TaxCurrencyCode <> '') and (FInvoice.TaxCurrencyCode <> FInvoice.InvoiceCurrencyCode) and
         (TaxTotal.CurrencyID = FInvoice.TaxCurrencyCode) and not FInvoice.TaxAmountTotalInTaxCurrency.HasValue then
      begin
        TaxTotal.CurrencyID := '';
        Value := Amount(TaxTotal, Path + '/ram:TaxTotalAmount');
        { not set when the text is no amount (reported by Amount) }
        if LandrixEInvoiceTryLexicalToCurrency(TaxTotal.Value, Check, Rounded) then
          FInvoice.TaxAmountTotalInTaxCurrency.SetValue(Value);
      end
      else
        NotMapped(Path + '/ram:TaxTotalAmount', 'VAT total ' + TaxTotal.Value + ' ' + TaxTotal.CurrencyID +
          ' (BT-111)');
    end;
  if Chosen >= 0 then
  begin
    TaxTotal := Sum.TaxTotalAmount[Chosen];
    { BT-6 only when it differs: a BT-110 in the invoice currency says nothing
      about a VAT accounting currency
      DE: BT-6 nur, wenn abweichend: ein BT-110 in der Rechnungswaehrung sagt
      nichts ueber eine Steuerwaehrung }
    if (FInvoice.TaxCurrencyCode = '') and (TaxTotal.CurrencyID <> FInvoice.InvoiceCurrencyCode) then
      FInvoice.TaxCurrencyCode := TaxTotal.CurrencyID;
    FInvoice.TaxAmountTotal := Amount(TaxTotal, Path + '/ram:TaxTotalAmount');
  end;
  FInvoice.PayableRoundingAmount := Amount(Sum.RoundingAmount, Path + '/ram:RoundingAmount');
  FInvoice.TaxInclusiveAmount := Amount(Sum.GrandTotalAmount, Path + '/ram:GrandTotalAmount');
  FInvoice.PrepaidAmount := Amount(Sum.TotalPrepaidAmount, Path + '/ram:TotalPrepaidAmount');
  FInvoice.PayableAmount := Amount(Sum.DuePayableAmount, Path + '/ram:DuePayableAmount');
  Sum.ListFilledChildren(FFilled);
  Rest(Path, ['ram:LineTotalAmount', 'ram:ChargeTotalAmount', 'ram:AllowanceTotalAmount', 'ram:TaxBasisTotalAmount',
    'ram:TaxTotalAmount', 'ram:RoundingAmount', 'ram:GrandTotalAmount', 'ram:TotalPrepaidAmount',
    'ram:DuePayableAmount']);
end;

{ BT-7 and BT-8 are kept once per invoice: the first value of the VAT
  breakdowns is taken, a differing one is reported.
  DE: BT-7 und BT-8 gibt es je Rechnung einmal: der erste Wert der
  Steueraufschluesselungen wird uebernommen, ein abweichender gemeldet. }
procedure TCIIReadMapper.ReadSettlement;
var
  Source: TLandrixCIIHeaderTradeSettlement;
  I: TLandrixEInvoiceListIndex;
  Tax: TLandrixCIITradeTax;
  Subtotal: TLandrixInvoiceTaxAmount;
  Reference: TLandrixInvoicePrecedingInvoiceReference;
  Payment: TLandrixInvoicePrepaidPayment;
  PointDate: TDateTime;
  PointCode, FirstPointDate, FirstPointCode: TLandrixEInvoiceString;
begin
  FirstPointDate := '';
  FirstPointCode := '';
  Source := FCII.SupplyChainTradeTransaction.ApplicableHeaderTradeSettlement;
  FInvoice.InvoiceCurrencyCode := Source.InvoiceCurrencyCode;
  FInvoice.TaxCurrencyCode := Source.TaxCurrencyCode;
  FInvoice.AccountingSupplierParty.BankAssignedCreditorIdentifier := IDValue(Source.CreditorReferenceID,
    Settlement + '/ram:CreditorReferenceID');
  FInvoice.PaymentID := Source.PaymentReference;
  ReadPaymentMeans(Source);
  for I := 0 to Source.ApplicableTradeTax.Count - 1 do
  begin
    Tax := Source.ApplicableTradeTax[I];
    Subtotal := FInvoice.TaxAmountSubtotals.AddTaxAmount;
    Subtotal.TaxAmount := Amount(Tax.CalculatedAmount, Settlement + '/ram:ApplicableTradeTax/ram:CalculatedAmount');
    Subtotal.TaxExemptionReason := Tax.ExemptionReason;
    Subtotal.TaxExemptionReasonCode := CodeValue(Tax.ExemptionReasonCode,
      Settlement + '/ram:ApplicableTradeTax/ram:ExemptionReasonCode');
    Subtotal.TaxableAmount := Amount(Tax.BasisAmount, Settlement + '/ram:ApplicableTradeTax/ram:BasisAmount');
    ReadTaxCategory(Tax.CategoryCode, Settlement + '/ram:ApplicableTradeTax/ram:CategoryCode', Subtotal.TaxCategory,
      Subtotal.TaxCategoryOther);
    Subtotal.TaxPercent := Decimal(Tax.RateApplicablePercent, Settlement + '/ram:ApplicableTradeTax/ram:RateApplicablePercent');
    if (Tax.TypeCode <> '') and (Tax.TypeCode <> 'VAT') then
      NotMapped(Settlement + '/ram:ApplicableTradeTax/ram:TypeCode', 'tax type ' + Tax.TypeCode);
    if Tax.TaxPointDate.Value <> '' then
    begin
      if FirstPointDate = '' then
      begin
        FirstPointDate := Tax.TaxPointDate.Value;
        PointDate := 0;
        if LandrixEInvoiceTryCIIToDate(Tax.TaxPointDate.Value, Tax.TaxPointDate.Format, PointDate) then
          FInvoice.TaxPointDate.SetValue(PointDate)
        else
          Report(edk_ConversionFailed, Settlement + '/ram:ApplicableTradeTax/ram:TaxPointDate',
            'date "' + Tax.TaxPointDate.Value + '" (format ' + Tax.TaxPointDate.Format + ') not converted; not set',
            eds_Error);
      end
      else if Tax.TaxPointDate.Value <> FirstPointDate then
        NotMapped(Settlement + '/ram:ApplicableTradeTax/ram:TaxPointDate', 'differing VAT point date ' +
          Tax.TaxPointDate.Value);
    end;
    if Tax.DueDateTypeCode <> '' then
    begin
      if FirstPointCode = '' then
      begin
        FirstPointCode := Tax.DueDateTypeCode;
        if not LandrixEInvoiceTaxPointDateCodeFromCII(Tax.DueDateTypeCode, PointCode) then
          Report(edk_UnknownCode, Settlement + '/ram:ApplicableTradeTax/ram:DueDateTypeCode', 'VAT point date code ' +
            Tax.DueDateTypeCode + ' is none of 5, 29, 72; kept unchanged', eds_Info);
        FInvoice.TaxPointDateCode := PointCode;
      end
      else if Tax.DueDateTypeCode <> FirstPointCode then
        NotMapped(Settlement + '/ram:ApplicableTradeTax/ram:DueDateTypeCode', 'differing VAT point date code ' +
          Tax.DueDateTypeCode);
    end;
    Tax.ListFilledChildren(FFilled);
    Rest(Settlement + '/ram:ApplicableTradeTax', ['ram:CalculatedAmount', 'ram:TypeCode', 'ram:ExemptionReason',
      'ram:BasisAmount', 'ram:CategoryCode', 'ram:ExemptionReasonCode', 'ram:TaxPointDate', 'ram:DueDateTypeCode',
      'ram:RateApplicablePercent']);
  end;
  ReadFurtherParty(FInvoice.InvoiceeParty, Source.InvoiceeTradeParty, Settlement + '/ram:InvoiceeTradeParty');
  ReadFurtherParty(FInvoice.PayeeParty, Source.PayeeTradeParty, Settlement + '/ram:PayeeTradeParty');
  FInvoice.InvoicePeriodStartDate := Date(Source.BillingSpecifiedPeriod.StartDateTime,
    Settlement + '/ram:BillingSpecifiedPeriod/ram:StartDateTime');
  FInvoice.InvoicePeriodEndDate := Date(Source.BillingSpecifiedPeriod.EndDateTime,
    Settlement + '/ram:BillingSpecifiedPeriod/ram:EndDateTime');
  Source.BillingSpecifiedPeriod.ListFilledChildren(FFilled);
  Rest(Settlement + '/ram:BillingSpecifiedPeriod', ['ram:StartDateTime', 'ram:EndDateTime']);
  for I := 0 to Source.SpecifiedTradeAllowanceCharge.Count - 1 do
    ReadAllowanceCharge(FInvoice.AllowanceCharges.AddAllowanceCharge, Source.SpecifiedTradeAllowanceCharge[I],
      Settlement + '/ram:SpecifiedTradeAllowanceCharge', True);
  for I := 0 to Source.SpecifiedLogisticsServiceCharge.Count - 1 do
    ReadLogisticsCharge(Source.SpecifiedLogisticsServiceCharge[I], Settlement + '/ram:SpecifiedLogisticsServiceCharge');
  { Factur-X EXTENDED financial adjustments are the third-party payments
    of the model (BG-DEX-09; reason as BT-DEX-003, amount as BT-DEX-002).
    DE: Finanzkorrekturen aus Factur-X EXTENDED sind die Zahlungen Dritter
    des Modells (BG-DEX-09; Grund als BT-DEX-003, Betrag als BT-DEX-002). }
  for I := 0 to Source.SpecifiedFinancialAdjustment.Count - 1 do
  begin
    Payment := FInvoice.PrepaidPayments.AddPrepaidPayment;
    Payment.InstructionID := Source.SpecifiedFinancialAdjustment[I].Reason;
    Payment.PaidAmount := Amount(Source.SpecifiedFinancialAdjustment[I].ActualAmount,
      Settlement + '/ram:SpecifiedFinancialAdjustment/ram:ActualAmount');
    Source.SpecifiedFinancialAdjustment[I].ListFilledChildren(FFilled);
    Rest(Settlement + '/ram:SpecifiedFinancialAdjustment', ['ram:Reason', 'ram:ActualAmount']);
  end;
  ReadPaymentTerms(Source);
  ReadTotals(Source);
  for I := 0 to Source.InvoiceReferencedDocument.Count - 1 do
  begin
    Reference := FInvoice.PrecedingInvoiceReferences.AddPrecedingInvoiceReference;
    Reference.ID := IDValue(Source.InvoiceReferencedDocument[I].IssuerAssignedID,
      Settlement + '/ram:InvoiceReferencedDocument/ram:IssuerAssignedID');
    Reference.IssueDate := FormattedDate(Source.InvoiceReferencedDocument[I].FormattedIssueDateTime,
      Settlement + '/ram:InvoiceReferencedDocument/ram:FormattedIssueDateTime');
    Source.InvoiceReferencedDocument[I].ListFilledChildren(FFilled);
    Rest(Settlement + '/ram:InvoiceReferencedDocument', ['ram:IssuerAssignedID', 'ram:FormattedIssueDateTime']);
  end;
  if Source.ReceivableSpecifiedTradeAccountingAccount.Count > 0 then
  begin
    FInvoice.BuyerAccountingReference := IDValue(Source.ReceivableSpecifiedTradeAccountingAccount[0].ID,
      Settlement + '/ram:ReceivableSpecifiedTradeAccountingAccount/ram:ID');
    Source.ReceivableSpecifiedTradeAccountingAccount[0].ListFilledChildren(FFilled);
    Rest(Settlement + '/ram:ReceivableSpecifiedTradeAccountingAccount', ['ram:ID']);
    Excess(Source.ReceivableSpecifiedTradeAccountingAccount.Count, Settlement + '/ram:ReceivableSpecifiedTradeAccountingAccount');
  end;
  Source.ListFilledChildren(FFilled);
  Rest(Settlement, ['ram:CreditorReferenceID', 'ram:PaymentReference', 'ram:TaxCurrencyCode', 'ram:InvoiceCurrencyCode',
    'ram:InvoiceeTradeParty', 'ram:PayeeTradeParty', 'ram:SpecifiedTradeSettlementPaymentMeans', 'ram:ApplicableTradeTax', 'ram:BillingSpecifiedPeriod',
    'ram:SpecifiedTradeAllowanceCharge', 'ram:SpecifiedLogisticsServiceCharge', 'ram:SpecifiedTradePaymentTerms',
    'ram:SpecifiedTradeSettlementHeaderMonetarySummation', 'ram:SpecifiedFinancialAdjustment',
    'ram:InvoiceReferencedDocument',
    'ram:ReceivableSpecifiedTradeAccountingAccount']);
end;


{ --- public ------------------------------------------------------------------- }

function LandrixEInvoiceInvoiceToCII(AInvoice: TLandrixInvoice; const ASpec: TLandrixEInvoiceSpec;
  ADiagnostics: TLandrixEInvoiceDiagnostics): TLandrixCIIInvoice;
var
  Mapper: TCIIWriteMapper;
begin
  if (ASpec.Target.Syntax <> esy_CII) or not ASpec.CanWrite then
    raise ELandrixEInvoiceError.Create('LandrixEInvoiceInvoiceToCII: ' +
      string(LandrixEInvoiceTargetToStr(ASpec.Target)) + ' is no CII specification the library writes');
  Result := TLandrixCIIInvoice.Create;
  try
    Mapper := TCIIWriteMapper.Create(AInvoice, ASpec, ADiagnostics, Result);
    try
      Mapper.Execute;
    finally
      Mapper.Free;
    end;
    LandrixEInvoicePruneCII(Result, ASpec.Target.Profile, ADiagnostics);
  except
    Result.Free;
    raise;
  end;
end;

procedure LandrixEInvoiceCIIToInvoice(ACII: TLandrixCIIInvoice; AInvoice: TLandrixInvoice;
  ADiagnostics: TLandrixEInvoiceDiagnostics);
var
  Mapper: TCIIReadMapper;
begin
  Mapper := TCIIReadMapper.Create(ACII, AInvoice, ADiagnostics);
  try
    Mapper.Execute;
  finally
    Mapper.Free;
  end;
end;

end.
