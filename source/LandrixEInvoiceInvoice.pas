{
  EInvoice-for-Pascal

  Copyright (C) 2026 Landrix Software GmbH & Co. KG

  This file is dual-licensed under:
  - GNU GPL version 3 or later; or
  - the Landrix Software Commercial License.

  See LICENSE and COMMERCIAL-LICENSE.md.

  SPDX-License-Identifier: GPL-3.0-or-later OR LicenseRef-Landrix-Commercial
}

{ The semantic invoice model according to EN 16931 (business terms BT-...,
  business groups BG-...), independent of the syntax (UBL or CII).
  TLandrixInvoice is the invoice; its parts are classes with public fields
  and list classes derived from TObjectList that own their items.

  Conventions taken over from XRechnung-for-Delphi:
  - A Currency field 0 and a date field 0 mean "not set" (dates are valid
    when > 100). New optional fields use the optional value types of
    LandrixEInvoiceTypes.
  - Text is TLandrixEInvoiceString, file names are string.
  - Code list members come from LandrixEInvoiceCodes.

  DE: Das fachliche Rechnungsmodell nach EN 16931 (Geschaeftsbegriffe BT-...,
  Gruppen BG-...), unabhaengig von der Syntax (UBL oder CII).
  TLandrixInvoice ist die Rechnung; ihre Teile sind Klassen mit oeffentlichen
  Feldern und Listenklassen auf Basis von TObjectList, die ihre Eintraege
  besitzen.

  Aus XRechnung-for-Delphi uebernommene Konventionen:
  - Ein Currency-Feld 0 und ein Datumsfeld 0 bedeuten "nicht gesetzt"
    (Datumswerte gelten ab > 100). Neue optionale Felder verwenden die
    optionalen Werttypen aus LandrixEInvoiceTypes.
  - Text ist TLandrixEInvoiceString, Dateinamen sind string.
  - Codelistenwerte stammen aus LandrixEInvoiceCodes. }

{ API: stable. Covered by semantic versioning from release 1.0 on.
  DE: API: stabil. Ab Version 1.0 durch die semantische Versionierung
  abgedeckt. }

unit LandrixEInvoiceInvoice;

{$I LandrixEInvoice.inc}

interface

uses
  SysUtils,
  Classes,
  Contnrs,
  LandrixXmlBase,
  LandrixEInvoiceTypes,
  LandrixEInvoiceCodes;

const
  { Value for BT-10 (buyer reference, Leitweg-ID) when the buyer has none.
    DE: Wert fuer BT-10 (Kaeuferreferenz, Leitweg-ID), wenn der Kaeufer
    keine hat. }
  LandrixEInvoiceLeitwegIDNonExistent = 'non-existent';

type
  { Payment terms variant: net only, or one to three cash discount levels.
    See https://www.e-rechnung-bund.de/wp-content/uploads/2023/04/Angabe-Skonto-Upload.pdf
    DE: Art der Zahlungsbedingungen: nur netto oder eine bis drei
    Skontostufen. }
  TLandrixInvoicePaymentTermsType = (
    iptt_None,
    iptt_Net,
    iptt_CashDiscount1,
    iptt_CashDiscount2,
    iptt_CashDiscount3
  );

  { BT-X-8 line status reason code (ram:LineStatusReasonCode), ZUGFeRD /
    Factur-X EXTENDED only: DETAIL is a regular line that counts in the
    totals (default), GROUP a subtotal over its sub-lines and INFORMATION a
    line for information only; both do not count in the totals.
    DE: BT-X-8 Untertyp der Rechnungsposition (ram:LineStatusReasonCode),
    nur ZUGFeRD/Factur-X EXTENDED: DETAIL ist eine regulaere Position, die in
    die Summen zaehlt (Standard), GROUP eine Zwischensumme ueber ihre
    Unterpositionen und INFORMATION eine reine Information; beide zaehlen
    nicht in die Summen. }
  TLandrixInvoiceLineStatusReasonCode = (
    ilsrc_None,
    ilsrc_Detail,
    ilsrc_Group,
    ilsrc_Information
  );

  { An attached or referenced document (BG-24): either embedded data or an
    external reference. Whether to embed the data as Base64 or to deliver it
    separately depends on the recipient. According to the letter of the
    German Federal Ministry of Finance of 15 October 2024, links to
    supporting documents should no longer be used from 1 January 2025; the
    documents should be embedded instead.
    DE: Ein angehaengtes oder referenziertes Dokument (BG-24): entweder
    eingebettete Daten oder ein externer Verweis. Ob die Daten als Base64
    eingebettet oder separat geliefert werden, haengt vom Empfaenger ab.
    Gemaess BMF-Schreiben vom 15.10.2024 sollen Links auf
    rechnungsbegruendende Unterlagen ab dem 01.01.2025 nicht mehr verwendet,
    sondern in die Rechnung eingebettet werden. }
  TLandrixInvoiceAttachment = class(TObject)
  public
    { BT-122 document reference. DE: BT-122 Kennung des Dokuments. }
    ID: TLandrixEInvoiceString;
    { BT-123 description. DE: BT-123 Beschreibung. }
    DocumentDescription: TLandrixEInvoiceString;
    { BT-125-2 file name. DE: BT-125-2 Dateiname. }
    Filename: TLandrixEInvoiceString;
    { Document type (BT-17, BT-18 or BT-122), default 916.
      DE: Dokumentart (BT-17, BT-18 oder BT-122), Standard 916. }
    TypeCode: TLandrixInvoiceAttachmentTypeCode;
    { Code of TypeCode that the code list does not know, e.g. read from an
      invoice or newer than this library. Used only while TypeCode is
      iatc_None; a set TypeCode wins when writing.
      DE: Code zu TypeCode, den die Codeliste nicht kennt, z. B. aus einer
      gelesenen Rechnung oder neuer als diese Bibliothek. Gilt nur, solange
      TypeCode den Wert iatc_None hat; ein gesetztes TypeCode gewinnt beim
      Schreiben. }
    TypeCodeOther: TLandrixEInvoiceString;
    { BT-125-1 MIME type of the embedded data. DE: BT-125-1 MIME-Typ der
      eingebetteten Daten. }
    AttachmentType: TLandrixInvoiceAttachmentType;
    { Code of AttachmentType that the code list does not know, e.g. read from an
      invoice or newer than this library. Used only while AttachmentType is
      iat_application_None; a set AttachmentType wins when writing.
      DE: Code zu AttachmentType, den die Codeliste nicht kennt, z. B. aus einer
      gelesenen Rechnung oder neuer als diese Bibliothek. Gilt nur, solange
      AttachmentType den Wert iat_application_None hat; ein gesetztes AttachmentType gewinnt beim
      Schreiben. }
    AttachmentTypeOther: TLandrixEInvoiceString;
    { BT-125 embedded data (owned). DE: BT-125 eingebettete Daten (gehoert
      dem Objekt). }
    Data: TMemoryStream;
    { BT-124 external reference (URL). DE: BT-124 externer Verweis (URL). }
    ExternalReference: TLandrixEInvoiceString;
    { BT-18-1 scheme of the invoiced object identifier (TypeCode 130 only,
      e.g. 'AAG'); other attachments carry no scheme.
      DE: BT-18-1 Schema der Objektkennung (nur TypeCode 130, z. B. 'AAG');
      andere Anhaenge tragen kein Schema. }
    SchemeID: TLandrixEInvoiceString;
  public
    constructor Create(AAttachmentType: TLandrixInvoiceAttachmentType);
    destructor Destroy; override;
    { Replaces Data with the whole content of AStream (from position 0).
      DE: Ersetzt Data durch den gesamten Inhalt von AStream (ab Position 0). }
    procedure EmbedDataFromStream(AStream: TStream);
    { Replaces Data with the content of the file; does nothing if the file
      does not exist. DE: Ersetzt Data durch den Inhalt der Datei; tut nichts,
      wenn die Datei nicht existiert. }
    procedure EmbedDataFromFile(const AFileName: string);
    { Replaces Data with the text encoded as UTF-8 without BOM. The TStrings
      variant converts from the native string (on Delphi 6-2007 through the
      system code page); the TLandrixEInvoiceString variant is lossless.
      DE: Ersetzt Data durch den Text als UTF-8 ohne BOM. Die
      TStrings-Variante wandelt vom nativen string um (unter Delphi 6 bis
      2007 ueber die Systemcodepage); die Variante mit
      TLandrixEInvoiceString ist verlustfrei. }
    procedure EmbedDataFromText(const AValue: TStrings); overload;
    procedure EmbedDataFromText(const AValue: TLandrixEInvoiceString); overload;
    { Data as Base64 (RFC 4648, no line breaks); '' if Data is empty.
      DE: Data als Base64 (RFC 4648, ohne Zeilenumbrueche); '' bei leerem
      Data. }
    function GetDataAsBase64: TLandrixEInvoiceString;
    { Replaces Data with the decoded Base64 text. XML white space is allowed;
      invalid Base64 raises ELandrixXmlError and leaves Data empty.
      DE: Ersetzt Data durch den dekodierten Base64-Text. XML-Leerraum ist
      erlaubt; ungueltiges Base64 loest ELandrixXmlError aus und laesst Data
      leer. }
    procedure SetDataFromBase64(const AValue: TLandrixEInvoiceString);
    { True if Data is not empty. DE: True, wenn Data nicht leer ist. }
    function ContainsBinaryObject: Boolean;
    { Makes this object a deep copy of ASource (owned objects and lists are
      copied, not shared).
      DE: Macht dieses Objekt zu einer tiefen Kopie von ASource (eigene
      Unterobjekte und Listen werden kopiert, nicht geteilt). }
    procedure Assign(ASource: TLandrixInvoiceAttachment);
  end;

  { List of attachments (BG-24). DE: Liste der Anhaenge (BG-24). }
  TLandrixInvoiceAttachmentList = class(TObjectList)
  protected
    function GetItem(Index: TLandrixEInvoiceListIndex): TLandrixInvoiceAttachment;
    procedure SetItem(Index: TLandrixEInvoiceListIndex; AItem: TLandrixInvoiceAttachment);
  public
    function Extract(Item: TObject): TLandrixInvoiceAttachment;
    function First: TLandrixInvoiceAttachment;
    function Last: TLandrixInvoiceAttachment;
    property Items[Index: TLandrixEInvoiceListIndex]: TLandrixInvoiceAttachment read GetItem write SetItem; default;
  public
    function AddAttachment(AAttachmentType: TLandrixInvoiceAttachmentType): TLandrixInvoiceAttachment;
    { Adds an attachment whose type follows from the file extension. Returns
      False and AAttachment = nil if the file does not exist or the
      extension is not supported; the data is not loaded.
      DE: Fuegt einen Anhang hinzu, dessen Typ sich aus der Dateiendung
      ergibt. Liefert False und AAttachment = nil, wenn die Datei nicht
      existiert oder die Endung nicht unterstuetzt wird; die Daten werden
      nicht geladen. }
    function TryAddAttachmentByExtension(const AFileName: string;
      out AAttachment: TLandrixInvoiceAttachment): Boolean;
  end;

  { BG-DEX-09 third party payment, XRechnung UBL extension only.
    DE: BG-DEX-09 Zahlung durch Dritte, nur XRechnung-UBL-Erweiterung. }
  TLandrixInvoicePrepaidPayment = class(TObject)
  public
    { BT-DEX-001 DE: BT-DEX-001 }
    ID: TLandrixEInvoiceString;
    { BT-DEX-002 paid amount. DE: BT-DEX-002 gezahlter Betrag. }
    PaidAmount: Currency;
    { BT-DEX-002 currency. DE: BT-DEX-002 Waehrung. }
    PaidAmountCurrencyID: TLandrixEInvoiceString;
    { BT-DEX-003 DE: BT-DEX-003 }
    InstructionID: TLandrixEInvoiceString;
    { Makes this object a deep copy of ASource (owned objects and lists are
      copied, not shared).
      DE: Macht dieses Objekt zu einer tiefen Kopie von ASource (eigene
      Unterobjekte und Listen werden kopiert, nicht geteilt). }
    procedure Assign(ASource: TLandrixInvoicePrepaidPayment);
  end;

  { List of third party payments. DE: Liste der Zahlungen durch Dritte. }
  TLandrixInvoicePrepaidPaymentList = class(TObjectList)
  protected
    function GetItem(Index: TLandrixEInvoiceListIndex): TLandrixInvoicePrepaidPayment;
    procedure SetItem(Index: TLandrixEInvoiceListIndex; AItem: TLandrixInvoicePrepaidPayment);
  public
    function Extract(Item: TObject): TLandrixInvoicePrepaidPayment;
    function First: TLandrixInvoicePrepaidPayment;
    function Last: TLandrixInvoicePrepaidPayment;
    property Items[Index: TLandrixEInvoiceListIndex]: TLandrixInvoicePrepaidPayment read GetItem write SetItem; default;
  public
    function AddPrepaidPayment: TLandrixInvoicePrepaidPayment;
  end;

  { Document or line level allowance (BG-20, BG-27) or charge (BG-21,
    BG-28).
    DE: Nachlass (BG-20, BG-27) oder Zuschlag (BG-21, BG-28) auf
    Dokument- oder Positionsebene. }
  TLandrixInvoiceAllowanceCharge = class(TObject)
  public
    { True for a charge, False for an allowance. DE: True fuer einen
      Zuschlag, False fuer einen Nachlass. }
    ChargeIndicator: Boolean;
    { BT-98/BT-140 allowance reason code. DE: BT-98/BT-140 Code des
      Nachlassgrunds. }
    ReasonCodeAllowance: TLandrixInvoiceAllowanceOrChargeIdentCode;
    { Code of ReasonCodeAllowance that the code list does not know, e.g. read from an
      invoice or newer than this library. Used only while ReasonCodeAllowance is
      iacic_None; a set ReasonCodeAllowance wins when writing.
      DE: Code zu ReasonCodeAllowance, den die Codeliste nicht kennt, z. B. aus einer
      gelesenen Rechnung oder neuer als diese Bibliothek. Gilt nur, solange
      ReasonCodeAllowance den Wert iacic_None hat; ein gesetztes ReasonCodeAllowance gewinnt beim
      Schreiben. }
    ReasonCodeAllowanceOther: TLandrixEInvoiceString;
    { BT-105/BT-145 charge reason code. DE: BT-105/BT-145 Code des
      Zuschlagsgrunds. }
    ReasonCodeCharge: TLandrixInvoiceSpecialServiceDescriptionCode;
    { Code of ReasonCodeCharge that the code list does not know, e.g. read from an
      invoice or newer than this library. Used only while ReasonCodeCharge is
      issdc_None; a set ReasonCodeCharge wins when writing.
      DE: Code zu ReasonCodeCharge, den die Codeliste nicht kennt, z. B. aus einer
      gelesenen Rechnung oder neuer als diese Bibliothek. Gilt nur, solange
      ReasonCodeCharge den Wert issdc_None hat; ein gesetztes ReasonCodeCharge gewinnt beim
      Schreiben. }
    ReasonCodeChargeOther: TLandrixEInvoiceString;
    { BT-97/BT-104/BT-139/BT-144 reason. DE: Grund als Text. }
    Reason: TLandrixEInvoiceString;
    { BT-93/BT-100/BT-137/BT-142 base amount. DE: Grundbetrag. }
    BaseAmount: Currency;
    { BT-94/BT-101/BT-138/BT-143 percentage. DE: Prozentsatz. }
    MultiplierFactorNumeric: Double;
    { BT-92/BT-99/BT-136/BT-141 amount. DE: Betrag. }
    Amount: Currency;
    { BT-96/BT-103 VAT rate (document level). DE: BT-96/BT-103
      Umsatzsteuersatz (Dokumentebene). }
    TaxPercent: Double;
    { BT-95/BT-102 VAT category (document level). DE: BT-95/BT-102
      Umsatzsteuerkategorie (Dokumentebene). }
    TaxCategory: TLandrixInvoiceDutyTaxFeeCategoryCode;
    { Code of TaxCategory that the code list does not know, e.g. read from an
      invoice or newer than this library. Used only while TaxCategory is
      idtfcc_None; a set TaxCategory wins when writing.
      DE: Code zu TaxCategory, den die Codeliste nicht kennt, z. B. aus einer
      gelesenen Rechnung oder neuer als diese Bibliothek. Gilt nur, solange
      TaxCategory den Wert idtfcc_None hat; ein gesetztes TaxCategory gewinnt beim
      Schreiben. }
    TaxCategoryOther: TLandrixEInvoiceString;
    { Makes this object a deep copy of ASource (owned objects and lists are
      copied, not shared).
      DE: Macht dieses Objekt zu einer tiefen Kopie von ASource (eigene
      Unterobjekte und Listen werden kopiert, nicht geteilt). }
    procedure Assign(ASource: TLandrixInvoiceAllowanceCharge);
  end;

  { List of allowances and charges. DE: Liste der Nachlaesse und
    Zuschlaege. }
  TLandrixInvoiceAllowanceCharges = class(TObjectList)
  protected
    function GetItem(Index: TLandrixEInvoiceListIndex): TLandrixInvoiceAllowanceCharge;
    procedure SetItem(Index: TLandrixEInvoiceListIndex; AItem: TLandrixInvoiceAllowanceCharge);
  public
    function Extract(Item: TObject): TLandrixInvoiceAllowanceCharge;
    function First: TLandrixInvoiceAllowanceCharge;
    function Last: TLandrixInvoiceAllowanceCharge;
    property Items[Index: TLandrixEInvoiceListIndex]: TLandrixInvoiceAllowanceCharge read GetItem write SetItem; default;
  public
    function AddAllowanceCharge: TLandrixInvoiceAllowanceCharge;
  end;

  TLandrixInvoiceLines = class;

  { BG-32 item attribute. DE: BG-32 Artikeleigenschaft. }
  TLandrixInvoiceLineItemAttribute = class(TObject)
  public
    { BT-160 name. DE: BT-160 Name. }
    Name: TLandrixEInvoiceString;
    { BT-161 value. DE: BT-161 Wert. }
    Value: TLandrixEInvoiceString;
    { Makes this object a deep copy of ASource (owned objects and lists are
      copied, not shared).
      DE: Macht dieses Objekt zu einer tiefen Kopie von ASource (eigene
      Unterobjekte und Listen werden kopiert, nicht geteilt). }
    procedure Assign(ASource: TLandrixInvoiceLineItemAttribute);
  end;

  { List of item attributes. DE: Liste der Artikeleigenschaften. }
  TLandrixInvoiceLineItemAttributes = class(TObjectList)
  protected
    function GetItem(Index: TLandrixEInvoiceListIndex): TLandrixInvoiceLineItemAttribute;
    procedure SetItem(Index: TLandrixEInvoiceListIndex; AItem: TLandrixInvoiceLineItemAttribute);
  public
    function Extract(Item: TObject): TLandrixInvoiceLineItemAttribute;
    function First: TLandrixInvoiceLineItemAttribute;
    function Last: TLandrixInvoiceLineItemAttribute;
    property Items[Index: TLandrixEInvoiceListIndex]: TLandrixInvoiceLineItemAttribute read GetItem write SetItem; default;
  public
    function AddItemAttribute: TLandrixInvoiceLineItemAttribute;
  end;

  { BT-158 item classification. DE: BT-158 Artikelklassifizierung. }
  TLandrixInvoiceLineItemClassification = class(TObject)
  public
    { BT-158 classification code, e.g. FRACHT. DE: BT-158 Kennung der
      Artikelklassifizierung, z. B. FRACHT. }
    ClassCode: TLandrixEInvoiceString;
    { BT-158-1 scheme (UNTDID 7143), required when ClassCode is set, e.g.
      GB. DE: BT-158-1 Schema (UNTDID 7143), Pflicht wenn ClassCode gesetzt
      ist, z. B. GB. }
    ListID: TLandrixEInvoiceString;
    { BT-158-2 scheme version, optional. DE: BT-158-2 Version des Schemas,
      optional. }
    ListVersionID: TLandrixEInvoiceString;
    { Classification name, ZUGFeRD/Factur-X EXTENDED only (ram:ClassName),
      not allowed elsewhere. DE: Name der Klassifizierung, nur
      ZUGFeRD/Factur-X EXTENDED (ram:ClassName), sonst unzulaessig. }
    ClassificationName: TLandrixEInvoiceString;
    { Makes this object a deep copy of ASource (owned objects and lists are
      copied, not shared).
      DE: Macht dieses Objekt zu einer tiefen Kopie von ASource (eigene
      Unterobjekte und Listen werden kopiert, nicht geteilt). }
    procedure Assign(ASource: TLandrixInvoiceLineItemClassification);
  end;

  { List of item classifications. DE: Liste der Artikelklassifizierungen. }
  TLandrixInvoiceLineItemClassifications = class(TObjectList)
  protected
    function GetItem(Index: TLandrixEInvoiceListIndex): TLandrixInvoiceLineItemClassification;
    procedure SetItem(Index: TLandrixEInvoiceListIndex; AItem: TLandrixInvoiceLineItemClassification);
  public
    function Extract(Item: TObject): TLandrixInvoiceLineItemClassification;
    function First: TLandrixInvoiceLineItemClassification;
    function Last: TLandrixInvoiceLineItemClassification;
    property Items[Index: TLandrixEInvoiceListIndex]: TLandrixInvoiceLineItemClassification read GetItem write SetItem; default;
  public
    function AddItemClassification: TLandrixInvoiceLineItemClassification;
  end;

  { Invoice line (BG-25). DE: Rechnungsposition (BG-25). }
  TLandrixInvoiceLine = class(TObject)
  public
    { BT-126 line identifier. DE: BT-126 Positionsnummer. }
    ID: TLandrixEInvoiceString;
    { BT-157 item standard identifier as GTIN/EAN (scheme 0160). Writers
      use it only while StandardItemIdentifier is empty; readers fill it
      when the scheme is 0160.
      DE: BT-157 Kennung des Artikels als GTIN/EAN (Schema 0160). Die
      Schreiber verwenden es nur, solange StandardItemIdentifier leer ist;
      die Leser fuellen es, wenn das Schema 0160 ist. }
    GlobalID_EAN_GTIN: TLandrixEInvoiceString;
    { BT-157 item standard identifier with any scheme; takes precedence over
      GlobalID_EAN_GTIN when writing. Readers always fill it.
      DE: BT-157 Kennung des Artikels mit beliebigem Schema; hat beim
      Schreiben Vorrang vor GlobalID_EAN_GTIN. Die Leser fuellen es immer. }
    StandardItemIdentifier: TLandrixEInvoiceString;
    { BT-157-1 scheme of StandardItemIdentifier (ISO/IEC 6523 ICD, e.g.
      0160 GTIN); required with it (BR-64). DE: BT-157-1 Schema von
      StandardItemIdentifier (ISO/IEC 6523 ICD, z. B. 0160 GTIN); dazu
      Pflicht (BR-64). }
    StandardItemIdentifierSchemeID: TLandrixEInvoiceString;
    { BT-127 line note. DE: BT-127 Hinweis zur Position. }
    Note: TLandrixEInvoiceString;
    { BT-128 object identifier at line level, assigned by the seller.
      DE: BT-128 Objektkennung auf Positionsebene, vom Verkaeufer vergeben. }
    ObjectIdentifier: TLandrixEInvoiceString;
    { BT-128-1 scheme of the object identifier, code list UNTDID 1153,
      e.g. ON = buyer's order number. DE: BT-128-1 Schema der
      Objektkennung, Codeliste UNTDID 1153, z. B. ON = Bestellnummer des
      Kaeufers. }
    ObjectIdentifierSchemeID: TLandrixEInvoiceString;
    { BT-153 item name. DE: BT-153 Artikelname (Kurztext). }
    Name: TLandrixEInvoiceString;
    { BT-154 item description. DE: BT-154 Artikelbeschreibung. }
    Description: TLandrixEInvoiceString;
    { BT-129 invoiced quantity. DE: BT-129 Menge. }
    Quantity: Double;
    { BT-130 unit of measure. DE: BT-130 Mengeneinheit. }
    UnitCode: TLandrixInvoiceUnitCode;
    { Code of UnitCode that the code list does not know, e.g. read from an
      invoice or newer than this library. Used only while UnitCode is
      iuc_None; a set UnitCode wins when writing.
      DE: Code zu UnitCode, den die Codeliste nicht kennt, z. B. aus einer
      gelesenen Rechnung oder neuer als diese Bibliothek. Gilt nur, solange
      UnitCode den Wert iuc_None hat; ein gesetztes UnitCode gewinnt beim
      Schreiben. }
    UnitCodeOther: TLandrixEInvoiceString;
    { BT-155 seller's item identifier. DE: BT-155 Artikelnummer des
      Verkaeufers. }
    SellersItemIdentification: TLandrixEInvoiceString;
    { BT-156 buyer's item identifier. DE: BT-156 Artikelkennung des
      Kaeufers. }
    BuyersItemIdentification: TLandrixEInvoiceString;
    { BT-X-21 buyer's order number, ZUGFeRD/Factur-X only. DE: BT-X-21
      Bestellnummer des Kaeufers, nur ZUGFeRD/Factur-X. }
    OrderNumber: TLandrixEInvoiceString;
    { BT-X-22 date of the buyer's order of the line, Factur-X EXTENDED only.
      DE: BT-X-22 Datum der Bestellung des Kaeufers zur Position, nur
      Factur-X EXTENDED. }
    OrderDate: TLandrixEInvoiceDate;
    { BT-132 referenced purchase order line. DE: BT-132 Referenz auf die
      Bestellposition, vom Kaeufer vergeben. }
    OrderLineReference: TLandrixEInvoiceString;
    { BT-133 buyer's accounting reference for the line. DE: BT-133
      Buchungsreferenz des Kaeufers fuer die Position. }
    BuyerAccountingReference: TLandrixEInvoiceString;
    { BT-152 VAT rate. DE: BT-152 Umsatzsteuersatz. }
    TaxPercent: Double;
    { BT-151 VAT category. DE: BT-151 Umsatzsteuerkategorie. }
    TaxCategory: TLandrixInvoiceDutyTaxFeeCategoryCode;
    { Code of TaxCategory that the code list does not know, e.g. read from an
      invoice or newer than this library. Used only while TaxCategory is
      idtfcc_None; a set TaxCategory wins when writing.
      DE: Code zu TaxCategory, den die Codeliste nicht kennt, z. B. aus einer
      gelesenen Rechnung oder neuer als diese Bibliothek. Gilt nur, solange
      TaxCategory den Wert idtfcc_None hat; ein gesetztes TaxCategory gewinnt beim
      Schreiben. }
    TaxCategoryOther: TLandrixEInvoiceString;
    { VAT exemption reason of the line. DE: Grund der Steuerbefreiung der
      Position. }
    TaxExemptionReason: TLandrixEInvoiceString;
    { BT-148 item gross price (BG-29). Prices are Double, not Currency:
      EN 16931 limits their decimals not (e.g. 0.061232374 per kWh); exact
      up to 15 significant digits.
      DE: BT-148 Brutto-Einzelpreis (BG-29). Preise sind Double, nicht
      Currency: EN 16931 begrenzt ihre Nachkommastellen nicht (z. B.
      0.061232374 je kWh); exakt bis 15 signifikante Stellen. }
    GrossPriceAmount: Double;
    { BT-147 price discount on the gross price, giving the net price. Only
      one discount, because UBL allows only one (CII allows several).
      DE: BT-147 Rabatt auf den Bruttopreis, ergibt den Nettopreis. Nur ein
      Rabatt, weil UBL nur einen erlaubt (CII mehrere). }
    DiscountOnTheGrossPrice: Double;
    { BT-146 item net price. DE: BT-146 Netto-Einzelpreis. }
    NetPriceAmount: Double;
    { BT-149 item price base quantity. DE: BT-149 Preiseinheit. }
    BaseQuantity: Double;
    { BT-150 unit of the price base quantity. DE: BT-150 Mengeneinheit der
      Preiseinheit. }
    BaseQuantityUnitCode: TLandrixInvoiceUnitCode;
    { Code of BaseQuantityUnitCode that the code list does not know, e.g. read from an
      invoice or newer than this library. Used only while BaseQuantityUnitCode is
      iuc_None; a set BaseQuantityUnitCode wins when writing.
      DE: Code zu BaseQuantityUnitCode, den die Codeliste nicht kennt, z. B. aus einer
      gelesenen Rechnung oder neuer als diese Bibliothek. Gilt nur, solange
      BaseQuantityUnitCode den Wert iuc_None hat; ein gesetztes BaseQuantityUnitCode gewinnt beim
      Schreiben. }
    BaseQuantityUnitCodeOther: TLandrixEInvoiceString;
    { BT-131 line net amount. DE: BT-131 Nettobetrag der Position. }
    LineAmount: Currency;
    { BG-27 allowances (BT-136..BT-140) and BG-28 charges (BT-141..BT-145)
      of the line (owned). DE: BG-27 Nachlaesse (BT-136..BT-140) und BG-28
      Zuschlaege (BT-141..BT-145) der Position (gehoeren dem Objekt). }
    AllowanceCharges: TLandrixInvoiceAllowanceCharges;
    { BT-134 line period start (BG-26). DE: BT-134 Beginn des
      Leistungszeitraums der Position (BG-26). }
    InvoiceLinePeriodStartDate: TDateTime;
    { BT-135 line period end (BG-26). DE: BT-135 Ende des
      Leistungszeitraums der Position (BG-26). }
    InvoiceLinePeriodEndDate: TDateTime;
    { BT-158 item classifications (0..n, owned). DE: BT-158
      Artikelklassifizierungen (0..n, gehoeren dem Objekt). }
    ItemClassifications: TLandrixInvoiceLineItemClassifications;
    { BT-159 item country of origin, e.g. DE. DE: BT-159
      Artikelherkunftsland, z. B. DE. }
    OriginTradeCountry: TLandrixEInvoiceString;
    { BG-32 item attributes (BT-160, BT-161, owned). DE: BG-32
      Artikeleigenschaften (BT-160, BT-161, gehoeren dem Objekt). }
    ItemAttributes: TLandrixInvoiceLineItemAttributes;

    { Delivery details per line, e.g. for collective invoices over several
      delivery notes. ZUGFeRD/Factur-X EXTENDED only
      (ram:SpecifiedLineTradeDelivery); EN 16931, XRechnung (UBL and CII)
      and Peppol do not know them at line level, so writers ignore them
      there. Invoice-wide counterparts: DeliveryReceiptNumberExtended,
      DeliveryReceiptDateExtended and DeliveryInformation.ActualDeliveryDate.
      DE: Lieferangaben je Position, z. B. fuer Sammelrechnungen ueber
      mehrere Lieferscheine. Nur ZUGFeRD/Factur-X EXTENDED
      (ram:SpecifiedLineTradeDelivery); EN 16931, XRechnung (UBL und CII)
      und Peppol kennen sie auf Positionsebene nicht, dort werden sie beim
      Schreiben ignoriert. Rechnungsweit: DeliveryReceiptNumberExtended,
      DeliveryReceiptDateExtended und DeliveryInformation.ActualDeliveryDate. }

    { BT-X-92 delivery note number of the line. DE: BT-X-92
      Lieferscheinnummer der Position. }
    DeliveryNoteNumber: TLandrixEInvoiceString;
    { BT-X-93 line number on the delivery note, only with
      DeliveryNoteNumber. DE: BT-X-93 Positionsnummer auf dem Lieferschein,
      nur zusammen mit DeliveryNoteNumber. }
    DeliveryNoteLineID: TLandrixEInvoiceString;
    { BT-X-94 delivery note date of the line, only with DeliveryNoteNumber.
      DE: BT-X-94 Lieferscheindatum der Position, nur zusammen mit
      DeliveryNoteNumber. }
    DeliveryNoteDate: TDateTime;
    { Actual delivery date of the line. DE: Tatsaechliches Lieferdatum der
      Position. }
    ActualDeliveryDate: TDateTime;

    { Sub-lines, e.g. titles/line groups (owned).
      - XRechnung UBL (extension): cac:SubInvoiceLine; the amount of the
        parent line counts in the sum of line amounts (BT-106), the
        sub-lines do not.
      - ZUGFeRD/Factur-X EXTENDED: flat lines with ParentLineID (BT-X-304);
        only DETAIL lines count in BT-106. A parent line (GROUP) must carry
        exactly the sum of its DETAIL and GROUP sub-lines (BR-FXEXT-08);
        sub-lines must be complete lines (quantity, net price, VAT
        category).
      - XRechnung CII and ZUGFeRD EN16931 do not support sub-lines.
      DE: Unterpositionen, z. B. Titel/Positionsgruppen (gehoeren dem
      Objekt).
      - XRechnung UBL (Erweiterung): cac:SubInvoiceLine; der Betrag der
        Oberposition zaehlt in die Summe der Positionen (BT-106), die
        Unterpositionen nicht.
      - ZUGFeRD/Factur-X EXTENDED: flache Positionen mit ParentLineID
        (BT-X-304); nur DETAIL-Positionen zaehlen in BT-106. Eine
        Oberposition (GROUP) muss genau die Summe ihrer DETAIL- und
        GROUP-Unterpositionen tragen (BR-FXEXT-08); Unterpositionen muessen
        vollstaendige Positionen sein (Menge, Nettopreis, Steuerkategorie).
      - XRechnung CII und ZUGFeRD EN16931 kennen keine Unterpositionen. }
    SubInvoiceLines: TLandrixInvoiceLines;
    { BT-X-8, EXTENDED only. With ilsrc_None writers derive the value from
      the structure: GROUP with sub-lines, DETAIL as a sub-line, otherwise
      none. Readers take the value from the file.
      DE: BT-X-8, nur EXTENDED. Bei ilsrc_None leitet der Schreibcode den
      Wert aus der Struktur ab: mit Unterpositionen GROUP, als Unterposition
      DETAIL, sonst nichts. Beim Lesen wird der Wert aus der Datei
      uebernommen. }
    LineStatusReasonCode: TLandrixInvoiceLineStatusReasonCode;
    { Code of LineStatusReasonCode that the code list does not know, e.g. read from an
      invoice or newer than this library. Used only while LineStatusReasonCode is
      ilsrc_None; a set LineStatusReasonCode wins when writing.
      DE: Code zu LineStatusReasonCode, den die Codeliste nicht kennt, z. B. aus einer
      gelesenen Rechnung oder neuer als diese Bibliothek. Gilt nur, solange
      LineStatusReasonCode den Wert ilsrc_None hat; ein gesetztes LineStatusReasonCode gewinnt beim
      Schreiben. }
    LineStatusReasonCodeOther: TLandrixEInvoiceString;
  public
    constructor Create;
    destructor Destroy; override;
    { Resets all fields to the values after Create; owned objects are
      cleared, not replaced. DE: Setzt alle Felder auf die Werte nach Create
      zurueck; eigene Unterobjekte werden geleert, nicht ersetzt. }
    procedure Clear;
    { Makes this object a deep copy of ASource (owned objects and lists are
      copied, not shared).
      DE: Macht dieses Objekt zu einer tiefen Kopie von ASource (eigene
      Unterobjekte und Listen werden kopiert, nicht geteilt). }
    procedure Assign(ASource: TLandrixInvoiceLine);
  end;

  { List of invoice lines. DE: Liste der Rechnungspositionen. }
  TLandrixInvoiceLines = class(TObjectList)
  protected
    function GetItem(Index: TLandrixEInvoiceListIndex): TLandrixInvoiceLine;
    procedure SetItem(Index: TLandrixEInvoiceListIndex; AItem: TLandrixInvoiceLine);
  public
    function Extract(Item: TObject): TLandrixInvoiceLine;
    function First: TLandrixInvoiceLine;
    function Last: TLandrixInvoiceLine;
    property Items[Index: TLandrixEInvoiceListIndex]: TLandrixInvoiceLine read GetItem write SetItem; default;
  public
    function AddInvoiceLine: TLandrixInvoiceLine;
  end;

  { VAT breakdown (BG-23). DE: Umsatzsteueraufschluesselung (BG-23). }
  TLandrixInvoiceTaxAmount = class(TObject)
  public
    { BT-116 taxable amount. DE: BT-116 Steuerbemessungsgrundlage. }
    TaxableAmount: Currency;
    { BT-117 tax amount. DE: BT-117 Steuerbetrag. }
    TaxAmount: Currency;
    { BT-119 VAT rate. DE: BT-119 Umsatzsteuersatz. }
    TaxPercent: Double;
    { BT-118 VAT category. DE: BT-118 Umsatzsteuerkategorie. }
    TaxCategory: TLandrixInvoiceDutyTaxFeeCategoryCode;
    { Code of TaxCategory that the code list does not know, e.g. read from an
      invoice or newer than this library. Used only while TaxCategory is
      idtfcc_None; a set TaxCategory wins when writing.
      DE: Code zu TaxCategory, den die Codeliste nicht kennt, z. B. aus einer
      gelesenen Rechnung oder neuer als diese Bibliothek. Gilt nur, solange
      TaxCategory den Wert idtfcc_None hat; ein gesetztes TaxCategory gewinnt beim
      Schreiben. }
    TaxCategoryOther: TLandrixEInvoiceString;
    { BT-120 VAT exemption reason; should be set for the categories AE, E,
      O and Z. DE: BT-120 Grund der Steuerbefreiung; sollte bei den
      Kategorien AE, E, O und Z gesetzt sein. }
    TaxExemptionReason: TLandrixEInvoiceString;
    { BT-121 VAT exemption reason code (VATEX), e.g. VATEX-EU-AE.
      DE: BT-121 Code des Befreiungsgrunds (VATEX), z. B. VATEX-EU-AE. }
    TaxExemptionReasonCode: TLandrixEInvoiceString;
  public
    constructor Create;
    { Makes this object a deep copy of ASource (owned objects and lists are
      copied, not shared).
      DE: Macht dieses Objekt zu einer tiefen Kopie von ASource (eigene
      Unterobjekte und Listen werden kopiert, nicht geteilt). }
    procedure Assign(ASource: TLandrixInvoiceTaxAmount);
  end;

  { List of VAT breakdowns. DE: Liste der Umsatzsteueraufschluesselungen. }
  TLandrixInvoiceTaxAmounts = class(TObjectList)
  protected
    function GetItem(Index: TLandrixEInvoiceListIndex): TLandrixInvoiceTaxAmount;
    procedure SetItem(Index: TLandrixEInvoiceListIndex; AItem: TLandrixInvoiceTaxAmount);
  public
    function Extract(Item: TObject): TLandrixInvoiceTaxAmount;
    function First: TLandrixInvoiceTaxAmount;
    function Last: TLandrixInvoiceTaxAmount;
    property Items[Index: TLandrixEInvoiceListIndex]: TLandrixInvoiceTaxAmount read GetItem write SetItem; default;
  public
    { Adds the amounts to the first entry with the same VAT rate and returns
      True; returns False if there is none.
      DE: Addiert die Betraege zum ersten Eintrag mit demselben
      Umsatzsteuersatz und liefert True; liefert False, wenn es keinen gibt. }
    function AddTaxAmountIfTaxExists(ATaxPercent: Double;
      ATaxableAmount, ATaxAmount: Currency): Boolean;
    function AddTaxAmount: TLandrixInvoiceTaxAmount;
  end;

  { Postal address (BG-5, BG-8, BG-15). DE: Postanschrift (BG-5, BG-8,
    BG-15). }
  TLandrixInvoiceAddress = class(TObject)
  public
    { BT-35/BT-50/BT-75 address line 1. DE: Anschriftzeile 1. }
    StreetName: TLandrixEInvoiceString;
    { BT-36/BT-51/BT-76 address line 2. DE: Anschriftzeile 2. }
    AdditionalStreetName: TLandrixEInvoiceString;
    { BT-37/BT-52/BT-77 city. DE: Ort. }
    City: TLandrixEInvoiceString;
    { BT-38/BT-53/BT-78 post code. DE: Postleitzahl. }
    PostalZone: TLandrixEInvoiceString;
    { BT-39/BT-54/BT-79 country subdivision. DE: Region. }
    CountrySubentity: TLandrixEInvoiceString;
    { BT-162/BT-163/BT-165 address line 3. DE: Anschriftzeile 3. }
    AddressLine: TLandrixEInvoiceString;
    { BT-40/BT-55/BT-80 country code (ISO 3166-1 alpha-2). DE: Laendercode
      (ISO 3166-1 alpha-2). }
    CountryCode: TLandrixEInvoiceString;
    { Resets all fields to the values after Create. DE: Setzt alle Felder
      auf die Werte nach Create zurueck. }
    procedure Clear;
    { Makes this object a deep copy of ASource (owned objects and lists are
      copied, not shared).
      DE: Macht dieses Objekt zu einer tiefen Kopie von ASource (eigene
      Unterobjekte und Listen werden kopiert, nicht geteilt). }
    procedure Assign(ASource: TLandrixInvoiceAddress);
  end;

  { Seller (BG-4) or buyer (BG-7). DE: Verkaeufer (BG-4) oder Kaeufer
    (BG-7). }
  TLandrixInvoiceAccountingParty = class(TObject)
  public
    { BT-28/BT-45 trading name, if different. DE: BT-28/BT-45
      Handelsname, wenn abweichend. }
    Name: TLandrixEInvoiceString;
    { BT-27/BT-44 full name (company). DE: BT-27/BT-44 vollstaendiger Name
      (Firma). }
    RegistrationName: TLandrixEInvoiceString;
    { BT-30/BT-47 legal registration identifier (commercial register
      number). DE: BT-30/BT-47 Registernummer (Handelsregisternummer). }
    CompanyID: TLandrixEInvoiceString;
    { BT-30-1/BT-47-1 scheme of the legal registration identifier (ISO/IEC
      6523 ICD, e.g. 0002), optional. DE: BT-30-1/BT-47-1 Schema der
      Registernummer (ISO/IEC 6523 ICD, z. B. 0002), optional. }
    CompanyIDSchemeID: TLandrixEInvoiceString;

    { Postal address (owned). DE: Postanschrift (gehoert dem Objekt). }
    Address: TLandrixInvoiceAddress;

    { BT-29 seller identifier (creditor number) / BT-46 buyer identifier
      (debtor number), written without schemeID. A GLN or another
      identifier from the ICD list belongs in GlobalIdentifierSellerBuyer:
      Peppol checks an ID with schemeID 0088 for a valid GLN check digit
      (PEPPOL-COMMON-R040), a creditor number fails there. UBL allows only
      one identifier per party (buyer UBL-SR-16, seller VD-Valitool-23), CII
      only for the buyer (CII-SR-450); the global ID takes precedence. The
      creditor identifier BT-90 also takes a cac:PartyIdentification of the
      seller, distinguished by schemeID SEPA; KoSIT checks both kinds
      separately, valitool.org counts them together and reports
      VD-Valitool-23. Both are written anyway, BT-90 has no other mapping in
      UBL. Readers put every ID with a schemeID other than SEPA into
      GlobalIdentifierSellerBuyer.
      DE: BT-29 Kennung des Verkaeufers (Kreditor-Nr.) / BT-46 Kennung des
      Kaeufers (Debitor-Nr.), ohne schemeID geschrieben. Eine GLN oder eine
      andere Kennung aus der ICD-Liste gehoert in
      GlobalIdentifierSellerBuyer: Peppol prueft eine ID mit schemeID 0088
      auf eine gueltige GLN-Pruefziffer (PEPPOL-COMMON-R040), eine
      Kreditor-Nr. scheitert dort. In UBL ist je Partei nur eine Kennung
      zulaessig (Kaeufer UBL-SR-16, Verkaeufer VD-Valitool-23), in CII gilt
      das fuer den Kaeufer (CII-SR-450); die GlobalID hat jeweils Vorrang.
      Die Glaeubiger-ID (BT-90) belegt beim Verkaeufer ebenfalls eine
      cac:PartyIdentification, unterschieden ueber schemeID SEPA; KoSIT
      prueft beide Arten getrennt, valitool.org zaehlt sie zusammen und
      meldet VD-Valitool-23. Beide werden trotzdem geschrieben, BT-90 hat in
      UBL keine andere Abbildung. Beim Lesen landet jede ID mit schemeID
      ausser SEPA in GlobalIdentifierSellerBuyer. }
    IdentifierSellerBuyer: TLandrixEInvoiceString;
    { BT-29-0/BT-46-0 global identifier, optional (CII: ram:GlobalID, UBL:
      cac:PartyIdentification/cbc:ID with schemeID). DE: BT-29-0/BT-46-0
      globale Kennung, optional (CII: ram:GlobalID, UBL:
      cac:PartyIdentification/cbc:ID mit schemeID). }
    GlobalIdentifierSellerBuyer: TLandrixEInvoiceString;
    { BT-29-1/BT-46-1 scheme of the global identifier, default 0088 (GLN);
      values: 0021 SWIFT, 0088 EAN/GLN, 0060 DUNS, 0177 ODETTE.
      DE: BT-29-1/BT-46-1 Schema der globalen Kennung, Standard 0088 (GLN);
      Werte: 0021 SWIFT, 0088 EAN/GLN, 0060 DUNS, 0177 ODETTE. }
    GlobalIdentifierSellerBuyerSchemeID: TLandrixEInvoiceString;
    { BT-90 bank assigned creditor identifier. DE: BT-90
      Glaeubiger-ID. }
    BankAssignedCreditorIdentifier: TLandrixEInvoiceString;

    { BT-31/BT-48 VAT identifier. DE: BT-31/BT-48
      Umsatzsteuer-Identifikationsnummer. }
    VATCompanyID: TLandrixEInvoiceString;
    { BT-32 tax registration identifier (seller). DE: BT-32 Steuernummer
      (Verkaeufer). }
    VATCompanyNumber: TLandrixEInvoiceString;

    { BT-41/BT-56 contact point. DE: BT-41/BT-56 Kontaktstelle. }
    ContactName: TLandrixEInvoiceString;
    { BT-41-0/BT-56-0 department of the contact, an alternative to
      ContactName: CII writes it only when ContactName is empty
      (CII-SR-465/466); UBL has no element for it.
      DE: BT-41-0/BT-56-0 Abteilung des Kontakts, eine Alternative zu
      ContactName: CII schreibt sie nur, wenn ContactName leer ist
      (CII-SR-465/466); UBL hat dafuer kein Element. }
    ContactDepartment: TLandrixEInvoiceString;
    { BT-42/BT-57 contact telephone number. DE: BT-42/BT-57 Telefonnummer
      des Kontakts. }
    ContactTelephone: TLandrixEInvoiceString;
    { BT-43/BT-58 contact email address. DE: BT-43/BT-58 E-Mail-Adresse
      des Kontakts. }
    ContactElectronicMail: TLandrixEInvoiceString;
    { BT-33 additional legal information about the seller. DE: BT-33
      weitere rechtliche Informationen zum Verkaeufer. }
    AdditionalLegalInformationSeller: TLandrixEInvoiceString;
    { BT-34/BT-49 electronic address, required. DE: BT-34/BT-49
      elektronische Adresse, Pflicht. }
    ElectronicAddressSellerBuyer: TLandrixEInvoiceString;
    { BT-34-1/BT-49-1 scheme of the electronic address, required: EM email
      (not with Peppol, https://docs.peppol.eu/poacc/billing/3.0/codelist/eas/),
      9930 Peppol ID. DE: BT-34-1/BT-49-1 Schema der elektronischen Adresse,
      Pflicht: EM E-Mail (nicht bei Peppol), 9930 Peppol-ID. }
    ElectronicAddressSellerBuyerSchemeID: TLandrixEInvoiceString;
  public
    constructor Create;
    destructor Destroy; override;
    { Resets all fields to the values after Create; owned objects are
      cleared, not replaced. DE: Setzt alle Felder auf die Werte nach Create
      zurueck; eigene Unterobjekte werden geleert, nicht ersetzt. }
    procedure Clear;
    { Makes this object a deep copy of ASource (owned objects and lists are
      copied, not shared).
      DE: Macht dieses Objekt zu einer tiefen Kopie von ASource (eigene
      Unterobjekte und Listen werden kopiert, nicht geteilt). }
    procedure Assign(ASource: TLandrixInvoiceAccountingParty);
  end;

  { A further party of the invoice: payee (BG-10), seller tax
    representative (BG-11) or invoicee (BG-X-36, Factur-X EXTENDED). Which
    fields a target can write depends on the role and the profile; the
    mapping reports content it leaves out. The mapping writes a party when
    a field other than a scheme holds text other than white space.
    DE: Eine weitere Partei der Rechnung: Zahlungsempfaenger (BG-10),
    Steuervertreter des Verkaeufers (BG-11) oder Rechnungsempfaenger
    (BG-X-36, Factur-X EXTENDED). Welche Felder ein Ziel schreiben kann,
    haengt von Rolle und Profil ab; die Abbildung meldet, was sie weglaesst.
    Die Abbildung schreibt eine Partei, sobald ein Feld ausser einem Schema
    anderen Text als Leerraum enthaelt. }
  TLandrixInvoiceParty = class(TObject)
  public
    { BT-59 payee name, BT-62 tax representative name. DE: BT-59 Name des
      Zahlungsempfaengers, BT-62 Name des Steuervertreters. }
    Name: TLandrixEInvoiceString;
    { BT-60 payee identifier; with a scheme it is a global identifier.
      DE: BT-60 Kennung des Zahlungsempfaengers; mit Schema eine globale
      Kennung. }
    Identifier: TLandrixEInvoiceString;
    { BT-60-1 scheme of the identifier (ISO/IEC 6523 ICD, e.g. 0088), empty
      for an identifier without scheme. DE: BT-60-1 Schema der Kennung
      (ISO/IEC 6523 ICD, z. B. 0088), leer fuer eine Kennung ohne Schema. }
    IdentifierSchemeID: TLandrixEInvoiceString;
    { BT-61 legal registration identifier of the payee. DE: BT-61
      Registernummer des Zahlungsempfaengers. }
    CompanyID: TLandrixEInvoiceString;
    { BT-61-1 scheme of the legal registration identifier. DE: BT-61-1
      Schema der Registernummer. }
    CompanyIDSchemeID: TLandrixEInvoiceString;
    { BT-63 VAT identifier of the tax representative. DE: BT-63
      Umsatzsteuer-Identifikationsnummer des Steuervertreters. }
    VATCompanyID: TLandrixEInvoiceString;
    { BG-12 address of the tax representative (owned). DE: BG-12 Anschrift
      des Steuervertreters (gehoert dem Objekt). }
    Address: TLandrixInvoiceAddress;
    { Contact (Factur-X EXTENDED): name, department, telephone, email.
      DE: Kontakt (Factur-X EXTENDED): Name, Abteilung, Telefon, E-Mail. }
    ContactName: TLandrixEInvoiceString;
    ContactDepartment: TLandrixEInvoiceString;
    ContactTelephone: TLandrixEInvoiceString;
    ContactElectronicMail: TLandrixEInvoiceString;
  public
    constructor Create;
    destructor Destroy; override;
    { Resets all fields to the values after Create; owned objects are
      cleared, not replaced. DE: Setzt alle Felder auf die Werte nach Create
      zurueck; eigene Unterobjekte werden geleert, nicht ersetzt. }
    procedure Clear;
    { True if no field is set. DE: True, wenn kein Feld gesetzt ist. }
    function IsEmpty: Boolean;
    { Makes this object a deep copy of ASource (owned objects and lists are
      copied, not shared).
      DE: Macht dieses Objekt zu einer tiefen Kopie von ASource (eigene
      Unterobjekte und Listen werden kopiert, nicht geteilt). }
    procedure Assign(ASource: TLandrixInvoiceParty);
  end;

  { Delivery information (BG-13). DE: Lieferinformationen (BG-13). }
  TLandrixInvoiceDeliveryInformation = class(TObject)
  public
    { BT-70 deliver to party name. DE: BT-70 Name des Warenempfaengers. }
    Name: TLandrixEInvoiceString;
    { BT-71 deliver to location identifier, optional: the place where the
      goods are delivered or the services rendered. With a scheme it is
      written as global identifier (CII ram:GlobalID, BT-71-0), without one
      as plain identifier (CII ram:ID, UBL cbc:ID without schemeID).
      DE: BT-71 Kennung des Lieferorts, optional: Ort, an den die Waren
      geliefert oder an dem die Dienstleistungen erbracht werden. Mit
      Schema wird sie als globale Kennung geschrieben (CII ram:GlobalID,
      BT-71-0), ohne als einfache Kennung (CII ram:ID, UBL cbc:ID ohne
      schemeID). }
    LocationIdentifier: TLandrixEInvoiceString;
    { BT-71-1 scheme of the location identifier, default 0088 (GLN, ISO/IEC
      6523); values: 0021 SWIFT, 0088 EAN, 0060 DUNS, 0177 ODETTE; empty for
      an identifier without scheme.
      DE: BT-71-1 Schema der Lieferortkennung, Standard 0088 (GLN, ISO/IEC
      6523); Werte: 0021 SWIFT, 0088 EAN, 0060 DUNS, 0177 ODETTE; leer fuer
      eine Kennung ohne Schema. }
    LocationIdentifierSchemeID: TLandrixEInvoiceString;
    { BG-15 deliver to address (owned). DE: BG-15 Lieferanschrift (gehoert
      dem Objekt). }
    Address: TLandrixInvoiceAddress;
    { BT-72 actual delivery date. DE: BT-72 Lieferdatum. }
    ActualDeliveryDate: TDateTime;
    { BG-X-26 deliver to contact (Factur-X EXTENDED): name, telephone,
      email. DE: BG-X-26 Kontakt des Warenempfaengers (Factur-X EXTENDED):
      Name, Telefon, E-Mail. }
    ContactName: TLandrixEInvoiceString;
    ContactTelephone: TLandrixEInvoiceString;
    ContactElectronicMail: TLandrixEInvoiceString;
  public
    constructor Create;
    destructor Destroy; override;
    { Resets all fields to the values after Create; owned objects are
      cleared, not replaced. DE: Setzt alle Felder auf die Werte nach Create
      zurueck; eigene Unterobjekte werden geleert, nicht ersetzt. }
    procedure Clear;
    { Makes this object a deep copy of ASource (owned objects and lists are
      copied, not shared).
      DE: Macht dieses Objekt zu einer tiefen Kopie von ASource (eigene
      Unterobjekte und Listen werden kopiert, nicht geteilt). }
    procedure Assign(ASource: TLandrixInvoiceDeliveryInformation);
  end;

  { Preceding invoice reference (BG-3). DE: Referenz auf eine vorausgegangene
    Rechnung (BG-3). }
  TLandrixInvoicePrecedingInvoiceReference = class(TObject)
  public
    { BT-25 preceding invoice number. DE: BT-25 Nummer der vorausgegangenen
      Rechnung. }
    ID: TLandrixEInvoiceString;
    { BT-26 preceding invoice issue date. DE: BT-26 Datum der
      vorausgegangenen Rechnung. }
    IssueDate: TDateTime;
    { Makes this object a deep copy of ASource (owned objects and lists are
      copied, not shared).
      DE: Macht dieses Objekt zu einer tiefen Kopie von ASource (eigene
      Unterobjekte und Listen werden kopiert, nicht geteilt). }
    procedure Assign(ASource: TLandrixInvoicePrecedingInvoiceReference);
  end;

  { List of preceding invoice references. DE: Liste der Referenzen auf
    vorausgegangene Rechnungen. }
  TLandrixInvoicePrecedingInvoiceReferences = class(TObjectList)
  protected
    function GetItem(Index: TLandrixEInvoiceListIndex): TLandrixInvoicePrecedingInvoiceReference;
    procedure SetItem(Index: TLandrixEInvoiceListIndex; AItem: TLandrixInvoicePrecedingInvoiceReference);
  public
    function Extract(Item: TObject): TLandrixInvoicePrecedingInvoiceReference;
    function First: TLandrixInvoicePrecedingInvoiceReference;
    function Last: TLandrixInvoicePrecedingInvoiceReference;
    property Items[Index: TLandrixEInvoiceListIndex]: TLandrixInvoicePrecedingInvoiceReference read GetItem write SetItem; default;
  public
    function AddPrecedingInvoiceReference: TLandrixInvoicePrecedingInvoiceReference;
    { Index of the first reference with this ID (ASCII case-insensitive),
      or -1. DE: Index der ersten Referenz mit dieser ID (ASCII, ohne
      Unterscheidung von Gross- und Kleinschreibung) oder -1. }
    function IndexOfPrecedingInvoiceReference(const AID: TLandrixEInvoiceString): TLandrixEInvoiceListIndex;
  end;

  { Invoice note (BG-1). DE: Hinweis zur Rechnung (BG-1). }
  TLandrixInvoiceNote = class(TObject)
  public
    { BT-22 note text. DE: BT-22 Text des Hinweises. }
    Content: TLandrixEInvoiceString;
    { BT-21 subject code; insc_None means free text. DE: BT-21 Betreff;
      insc_None bedeutet Freitext. }
    SubjectCode: TLandrixInvoiceNoteSubjectCode;
    { Code of SubjectCode that the code list does not know, e.g. read from an
      invoice or newer than this library. Used only while SubjectCode is
      insc_None; a set SubjectCode wins when writing.
      DE: Code zu SubjectCode, den die Codeliste nicht kennt, z. B. aus einer
      gelesenen Rechnung oder neuer als diese Bibliothek. Gilt nur, solange
      SubjectCode den Wert insc_None hat; ein gesetztes SubjectCode gewinnt beim
      Schreiben. }
    SubjectCodeOther: TLandrixEInvoiceString;
  public
    constructor Create;
    { Makes this object a deep copy of ASource (owned objects and lists are
      copied, not shared).
      DE: Macht dieses Objekt zu einer tiefen Kopie von ASource (eigene
      Unterobjekte und Listen werden kopiert, nicht geteilt). }
    procedure Assign(ASource: TLandrixInvoiceNote);
  end;

  { List of invoice notes. DE: Liste der Hinweise zur Rechnung. }
  TLandrixInvoiceNotes = class(TObjectList)
  protected
    function GetItem(Index: TLandrixEInvoiceListIndex): TLandrixInvoiceNote;
    procedure SetItem(Index: TLandrixEInvoiceListIndex; AItem: TLandrixInvoiceNote);
  public
    function Extract(Item: TObject): TLandrixInvoiceNote;
    function First: TLandrixInvoiceNote;
    function Last: TLandrixInvoiceNote;
    property Items[Index: TLandrixEInvoiceListIndex]: TLandrixInvoiceNote read GetItem write SetItem; default;
  public
    function AddNote: TLandrixInvoiceNote;
    { All note texts joined with CR LF. DE: Alle Hinweistexte, verbunden
      mit CR LF. }
    function NodeContentsAsText: TLandrixEInvoiceString;
    { Replaces all notes by one note with this text (none if it is empty).
      DE: Ersetzt alle Hinweise durch einen Hinweis mit diesem Text (keinen,
      wenn er leer ist). }
    procedure ReplaceContentWith(const AContent: TLandrixEInvoiceString);
  end;

  { Payment instructions (BG-16) with credit transfer (BG-17), card (BG-18)
    or direct debit (BG-19) details.
    DE: Zahlungsanweisungen (BG-16) mit Angaben zur Ueberweisung (BG-17),
    Karte (BG-18) oder Lastschrift (BG-19). }
  TLandrixInvoicePaymentType = class(TObject)
  public
    { BT-81 payment means type code. DE: BT-81 Code der Zahlungsart. }
    PaymentMeansCode: TLandrixInvoicePaymentMeansCode;
    { Code of PaymentMeansCode that the code list does not know, e.g. read from an
      invoice or newer than this library. Used only while PaymentMeansCode is
      ipmc_NotImplemented; a set PaymentMeansCode wins when writing.
      DE: Code zu PaymentMeansCode, den die Codeliste nicht kennt, z. B. aus einer
      gelesenen Rechnung oder neuer als diese Bibliothek. Gilt nur, solange
      PaymentMeansCode den Wert ipmc_NotImplemented hat; ein gesetztes PaymentMeansCode gewinnt beim
      Schreiben. }
    PaymentMeansCodeOther: TLandrixEInvoiceString;
    { BT-82 payment means text. DE: BT-82 Zahlungsart als Text. }
    PaymentMeansInformation: TLandrixEInvoiceString;
    { BT-84 payee IBAN (credit transfer 58), BT-91 debited account (direct
      debit 59) or BT-87 card number. DE: BT-84 IBAN des Zahlungsempfaengers
      (Ueberweisung 58), BT-91 belastetes Konto (Lastschrift 59) oder BT-87
      Kartennummer. }
    FinancialAccount: TLandrixEInvoiceString;
    { BT-85 account name or BT-88 card holder name. DE: BT-85 Kontoinhaber
      oder BT-88 Karteninhaber. }
    FinancialAccountName: TLandrixEInvoiceString;
    { BT-86 BIC of the payee (credit transfer 58); for direct debit (59)
      the payer's BIC, which has no EN 16931 term. DE: BT-86 BIC des
      Zahlungsempfaengers (Ueberweisung 58); bei Lastschrift (59) der BIC des
      Zahlers, der keinen EN-16931-Begriff hat. }
    FinancialInstitutionBranch: TLandrixEInvoiceString;
  public
    constructor Create;
    { Makes this object a deep copy of ASource (owned objects and lists are
      copied, not shared).
      DE: Macht dieses Objekt zu einer tiefen Kopie von ASource (eigene
      Unterobjekte und Listen werden kopiert, nicht geteilt). }
    procedure Assign(ASource: TLandrixInvoicePaymentType);
  end;

  { List of payment instructions. DE: Liste der Zahlungsanweisungen. }
  TLandrixInvoicePaymentTypeList = class(TObjectList)
  protected
    function GetItem(Index: TLandrixEInvoiceListIndex): TLandrixInvoicePaymentType;
    procedure SetItem(Index: TLandrixEInvoiceListIndex; AItem: TLandrixInvoicePaymentType);
  public
    function Extract(Item: TObject): TLandrixInvoicePaymentType;
    function First: TLandrixInvoicePaymentType;
    function Last: TLandrixInvoicePaymentType;
    function AddPaymentType: TLandrixInvoicePaymentType;
    property Items[Index: TLandrixEInvoiceListIndex]: TLandrixInvoicePaymentType read GetItem write SetItem; default;
  end;

  { The invoice. DE: Die Rechnung. }
  TLandrixInvoice = class(TObject)
  public
    { BT-23 business process type: identifies the business context so that
      the buyer can process the invoice appropriately. DE: BT-23
      Geschaeftsprozesstyp: identifiziert den Geschaeftsprozesskontext, damit
      der Kaeufer die Rechnung angemessen bearbeiten kann. }
    ProfileID: TLandrixEInvoiceString;
    { BT-X-1 test indicator, Factur-X EXTENDED only: True marks a test
      invoice. DE: BT-X-1 Testkennzeichen, nur Factur-X EXTENDED: True
      kennzeichnet eine Testrechnung. }
    TestIndicator: TLandrixEInvoiceBoolean;
    { BT-1 invoice number. DE: BT-1 Rechnungsnummer. }
    InvoiceNumber: TLandrixEInvoiceString;
    { BT-X-2 document name, e.g. 'RECHNUNG', Factur-X EXTENDED only.
      DE: BT-X-2 Dokumentname, z. B. 'RECHNUNG', nur Factur-X EXTENDED. }
    DocumentName: TLandrixEInvoiceString;
    { BT-2 invoice issue date. DE: BT-2 Rechnungsdatum. }
    InvoiceIssueDate: TDateTime;
    { BT-9 payment due date. DE: BT-9 Faelligkeitsdatum. }
    InvoiceDueDate: TDateTime;
    { BT-73 invoicing period start (BG-14). DE: BT-73 Beginn des
      Leistungszeitraums (BG-14). }
    InvoicePeriodStartDate: TDateTime;
    { BT-74 invoicing period end (BG-14). DE: BT-74 Ende des
      Leistungszeitraums (BG-14). }
    InvoicePeriodEndDate: TDateTime;
    { BT-3 invoice type code. BT-4 does not exist. DE: BT-3 Rechnungsart.
      BT-4 gibt es nicht. }
    InvoiceTypeCode: TLandrixInvoiceTypeCode;
    { Code of InvoiceTypeCode that the code list does not know, e.g. read from an
      invoice or newer than this library. Used only while InvoiceTypeCode is
      itc_None; a set InvoiceTypeCode wins when writing.
      DE: Code zu InvoiceTypeCode, den die Codeliste nicht kennt, z. B. aus einer
      gelesenen Rechnung oder neuer als diese Bibliothek. Gilt nur, solange
      InvoiceTypeCode den Wert itc_None hat; ein gesetztes InvoiceTypeCode gewinnt beim
      Schreiben. }
    InvoiceTypeCodeOther: TLandrixEInvoiceString;
    { BT-5 invoice currency code, e.g. EUR. DE: BT-5 Rechnungswaehrung,
      z. B. EUR. }
    InvoiceCurrencyCode: TLandrixEInvoiceString;
    { BT-6 VAT accounting currency code. DE: BT-6 Waehrung fuer die
      Umsatzsteuer. }
    TaxCurrencyCode: TLandrixEInvoiceString;
    { BT-7 VAT point date, if it differs from the issue date; excludes BT-8
      (BR-CO-3). CII carries it in the first VAT breakdown.
      DE: BT-7 Steuerdatum, wenn es vom Rechnungsdatum abweicht; schliesst
      BT-8 aus (BR-CO-3). CII traegt es in der ersten
      Steueraufschluesselung. }
    TaxPointDate: TLandrixEInvoiceDate;
    { BT-8 VAT point date code, UNTDID 2005: 3 issue date, 35 delivery date,
      432 paid to date. CII writes the UNTDID 2475 equivalents 5, 29 and 72
      and reads them back as 3, 35 and 432.
      DE: BT-8 Code fuer das Steuerdatum, UNTDID 2005: 3 Rechnungsdatum, 35
      Lieferdatum, 432 Zahlungsdatum. CII schreibt die Entsprechungen aus
      UNTDID 2475, 5, 29 und 72, und liest sie als 3, 35 und 432 zurueck. }
    TaxPointDateCode: TLandrixEInvoiceString;
    { BT-10 buyer reference; in XRechnung required, the Leitweg-ID
      (https://leitweg-id.de/home/) provided by the recipient.
      DE: BT-10 Kaeuferreferenz; in XRechnung Pflicht, die Leitweg-ID
      (https://leitweg-id.de/home/), die der Rechnungsempfaenger dem
      Rechnungssteller zur Verfuegung stellt. }
    BuyerReference: TLandrixEInvoiceString;
    { BG-1 invoice notes (BT-21, BT-22, owned). DE: BG-1 Hinweise zur
      Rechnung (BT-21, BT-22, gehoeren dem Objekt). }
    Notes: TLandrixInvoiceNotes;
    { BT-14 sales order reference. DE: BT-14 Auftragsnummer des
      Verkaeufers. }
    SellerOrderReference: TLandrixEInvoiceString;
    { BT-X-146 date of the sales order, Factur-X EXTENDED only. DE: BT-X-146
      Datum des Auftrags, nur Factur-X EXTENDED. }
    SellerOrderReferenceDate: TLandrixEInvoiceDate;
    { BT-13 purchase order reference. DE: BT-13 Bestellnummer des
      Kaeufers. }
    PurchaseOrderReference: TLandrixEInvoiceString;
    { BT-X-147 date of the purchase order, Factur-X EXTENDED only.
      DE: BT-X-147 Datum der Bestellung, nur Factur-X EXTENDED. }
    PurchaseOrderReferenceDate: TLandrixEInvoiceDate;
    { BT-11 project reference. DE: BT-11 Projektreferenz. }
    ProjectReference: TLandrixEInvoiceString;
    { BT-15 receiving advice reference. DE: BT-15 Referenz auf die
      Wareneingangsmeldung. }
    ReceiptDocumentReference: TLandrixEInvoiceString;
    { BT-12 contract reference. DE: BT-12 Vertragsnummer. }
    ContractDocumentReference: TLandrixEInvoiceString;
    { BT-16 despatch advice reference (ram:DespatchAdviceReferencedDocument,
      cac:DespatchDocumentReference), XRechnung CII and UBL. Not the
      delivery note number, which is BT-X-202.
      DE: BT-16 Referenz auf die Versandanzeige
      (ram:DespatchAdviceReferencedDocument, cac:DespatchDocumentReference),
      XRechnung CII und UBL. Nicht die Lieferscheinnummer, die ist BT-X-202. }
    DeliveryReceiptNumber: TLandrixEInvoiceString;
    { BT-X-200 despatch advice date, ZUGFeRD CII EXTENDED only (not in
      XRechnung CII or UBL). DE: BT-X-200 Datum der Versandanzeige, nur
      ZUGFeRD-CII-EXTENDED (nicht in XRechnung CII und UBL). }
    DeliveryReceiptDate: TDateTime;
    { BT-X-202 delivery note number, ZUGFeRD CII EXTENDED. DE: BT-X-202
      Lieferscheinnummer, ZUGFeRD-CII-EXTENDED. }
    DeliveryReceiptNumberExtended: TLandrixEInvoiceString;
    { BT-X-203 delivery note date, ZUGFeRD CII EXTENDED. DE: BT-X-203
      Lieferscheindatum, ZUGFeRD-CII-EXTENDED. }
    DeliveryReceiptDateExtended: TDateTime;
    { BT-19 buyer accounting reference (UBL one value, CII a list).
      DE: BT-19 Buchungsreferenz des Kaeufers (UBL ein Wert, CII eine
      Liste). }
    BuyerAccountingReference: TLandrixEInvoiceString;

    { BG-4 seller (owned). DE: BG-4 Verkaeufer (gehoert dem Objekt). }
    AccountingSupplierParty: TLandrixInvoiceAccountingParty;
    { BG-7 buyer (owned). DE: BG-7 Kaeufer (gehoert dem Objekt). }
    AccountingCustomerParty: TLandrixInvoiceAccountingParty;
    { BG-13 delivery information (owned). DE: BG-13 Lieferinformationen
      (gehoert dem Objekt). }
    DeliveryInformation: TLandrixInvoiceDeliveryInformation;
    { BG-10 payee, if different from the seller (owned): BT-59 name, BT-60
      identifier, BT-61 legal registration identifier.
      DE: BG-10 Zahlungsempfaenger, wenn abweichend vom Verkaeufer (gehoert
      dem Objekt): BT-59 Name, BT-60 Kennung, BT-61 Registernummer. }
    PayeeParty: TLandrixInvoiceParty;
    { BG-11 seller tax representative (owned): BT-62 name, BT-63 VAT
      identifier, BG-12 address.
      DE: BG-11 Steuervertreter des Verkaeufers (gehoert dem Objekt): BT-62
      Name, BT-63 USt-IdNr., BG-12 Anschrift. }
    TaxRepresentativeParty: TLandrixInvoiceParty;
    { BG-X-36 invoicee, if different from the buyer, Factur-X EXTENDED only
      (owned). DE: BG-X-36 Rechnungsempfaenger, wenn abweichend vom Kaeufer,
      nur Factur-X EXTENDED (gehoert dem Objekt). }
    InvoiceeParty: TLandrixInvoiceParty;

    { BT-83 remittance information (payment reference). DE: BT-83
      Verwendungszweck der Ueberweisung oder Lastschrift. }
    PaymentID: TLandrixEInvoiceString;
    { BG-16 payment instructions (owned). DE: BG-16 Zahlungswege (gehoeren
      dem Objekt). }
    PaymentTypes: TLandrixInvoicePaymentTypeList;
    { BT-89 mandate reference for direct debit (59); only one per invoice.
      DE: BT-89 Mandatsreferenz fuer die Lastschrift (59); nur eine je
      Rechnung moeglich. }
    PaymentMandateID: TLandrixEInvoiceString;

    { Payment terms (BT-20): net, or up to three cash discount levels, see
      https://www.e-rechnung-bund.de/wp-content/uploads/2023/04/Angabe-Skonto-Upload.pdf
      DE: Zahlungsbedingungen (BT-20): netto oder bis zu drei Skontostufen. }
    PaymentTermsType: TLandrixInvoicePaymentTermsType;
    { Net payment terms text. DE: Text der Nettozahlungsbedingung. }
    PaymentTermNetNote: TLandrixEInvoiceString;
    { Cash discount level 1: days, percent, base amount if different from
      the invoice amount, and the actual amount (ZUGFeRD/Factur-X only;
      must equal base times percent). Levels 2 and 3 likewise.
      DE: Skontostufe 1: Tage, Prozent, Basisbetrag, wenn abweichend vom
      Rechnungsbetrag, und der tatsaechliche Betrag (nur ZUGFeRD/Factur-X;
      muss Basis mal Prozent ergeben). Stufen 2 und 3 ebenso. }
    PaymentTermCashDiscount1Days: Integer;
    PaymentTermCashDiscount1Percent: Double;
    PaymentTermCashDiscount1Base: Currency;
    PaymentTermCashDiscount1ActualAmount: Currency;
    PaymentTermCashDiscount2Days: Integer;
    PaymentTermCashDiscount2Percent: Double;
    PaymentTermCashDiscount2Base: Currency;
    PaymentTermCashDiscount2ActualAmount: Currency;
    PaymentTermCashDiscount3Days: Integer;
    PaymentTermCashDiscount3Percent: Double;
    PaymentTermCashDiscount3Base: Currency;
    PaymentTermCashDiscount3ActualAmount: Currency;
    { Text of cash discount levels 1 to 3 (BT-20 of the discount term).
      Only the structured payment terms of Factur-X EXTENDED carry it; the
      #SKONTO# text form of XRechnung has no text per level.
      DE: Text der Skontostufen 1 bis 3 (BT-20 der Skontobedingung). Nur die
      strukturierten Zahlungsbedingungen von Factur-X EXTENDED tragen ihn;
      die #SKONTO#-Textform von XRechnung hat keinen Text je Stufe. }
    PaymentTermCashDiscount1Note: TLandrixEInvoiceString;
    PaymentTermCashDiscount2Note: TLandrixEInvoiceString;
    PaymentTermCashDiscount3Note: TLandrixEInvoiceString;

    { BG-25 invoice lines (owned). DE: BG-25 Rechnungspositionen (gehoeren
      dem Objekt). }
    InvoiceLines: TLandrixInvoiceLines;

    { BG-24 attachments (owned). DE: BG-24 Anhaenge (gehoeren dem Objekt). }
    Attachments: TLandrixInvoiceAttachmentList;

    { BG-DEX-09 third party payments, XRechnung UBL only (owned), see
      https://blog.seeburger.com/de/xrechnung-2-3-1-gueltig-ab-dem-01-08-2023/
      DE: BG-DEX-09 Zahlungen durch Dritte, nur XRechnung UBL (gehoeren dem
      Objekt). }
    PrepaidPayments: TLandrixInvoicePrepaidPaymentList;
    { BG-20 allowances and BG-21 charges on document level (owned).
      DE: BG-20 Nachlaesse und BG-21 Zuschlaege auf Dokumentebene (gehoeren
      dem Objekt). }
    AllowanceCharges: TLandrixInvoiceAllowanceCharges;
    { BG-3 preceding invoice references (owned). DE: BG-3 Referenzen auf
      vorausgegangene Rechnungen (gehoeren dem Objekt). }
    PrecedingInvoiceReferences: TLandrixInvoicePrecedingInvoiceReferences;

    { BT-110 invoice total VAT amount. DE: BT-110 Gesamtbetrag der
      Umsatzsteuer. }
    TaxAmountTotal: Currency;
    { BT-111 invoice total VAT amount in the VAT accounting currency (BT-6);
      required when BT-6 differs from the invoice currency (BR-53).
      DE: BT-111 Gesamtbetrag der Umsatzsteuer in der Steuerwaehrung (BT-6);
      Pflicht, wenn BT-6 von der Rechnungswaehrung abweicht (BR-53). }
    TaxAmountTotalInTaxCurrency: TLandrixEInvoiceAmount;
    { BG-23 VAT breakdown (owned). DE: BG-23 Umsatzsteueraufschluesselung
      (gehoert dem Objekt). }
    TaxAmountSubtotals: TLandrixInvoiceTaxAmounts;

    { BT-106 sum of invoice line net amounts. DE: BT-106 Summe der
      Nettobetraege der Positionen. }
    LineAmount: Currency;
    { BT-109 invoice total amount without VAT. DE: BT-109 Gesamtbetrag ohne
      Umsatzsteuer. }
    TaxExclusiveAmount: Currency;
    { BT-112 invoice total amount with VAT. DE: BT-112 Gesamtbetrag mit
      Umsatzsteuer. }
    TaxInclusiveAmount: Currency;
    { BT-107 sum of allowances on document level. DE: BT-107 Summe der
      Nachlaesse auf Dokumentebene. }
    AllowanceTotalAmount: Currency;
    { BT-108 sum of charges on document level. DE: BT-108 Summe der
      Zuschlaege auf Dokumentebene. }
    ChargeTotalAmount: Currency;
    { BT-113 paid amount. DE: BT-113 gezahlter Betrag. }
    PrepaidAmount: Currency;
    { BT-114 rounding amount. DE: BT-114 Rundungsbetrag. }
    PayableRoundingAmount: Currency;
    { BT-115 amount due for payment = BT-112 - BT-113 + BT-114 + sum of
      BT-DEX-002. DE: BT-115 faelliger Betrag = BT-112 - BT-113 + BT-114 +
      Summe BT-DEX-002. }
    PayableAmount: Currency;
  public
    constructor Create;
    destructor Destroy; override;
    { Resets the invoice for reuse: all fields get the values after Create,
      all lists are emptied, owned objects are cleared, not replaced.
      DE: Setzt die Rechnung zur Wiederverwendung zurueck: alle Felder
      erhalten die Werte nach Create, alle Listen werden geleert, eigene
      Unterobjekte werden geleert, nicht ersetzt. }
    procedure Clear;
    { Makes this object a deep copy of ASource (owned objects and lists are
      copied, not shared).
      DE: Macht dieses Objekt zu einer tiefen Kopie von ASource (eigene
      Unterobjekte und Listen werden kopiert, nicht geteilt). }
    procedure Assign(ASource: TLandrixInvoice);
  end;

{ BT-X-8 code of a line status reason ('' for ilsrc_None) and the reverse
  lookup (ASCII case-insensitive; False and ilsrc_None for an unknown code).
  DE: BT-X-8-Code eines Positionsuntertyps ('' fuer ilsrc_None) und die
  Umkehrung (ASCII, ohne Unterscheidung von Gross- und Kleinschreibung;
  False und ilsrc_None bei unbekanntem Code). }
function LandrixEInvoiceLineStatusReasonCodeToStr(Value: TLandrixInvoiceLineStatusReasonCode): TLandrixEInvoiceString;
function LandrixEInvoiceLineStatusReasonCodeFromStr(const Code: TLandrixEInvoiceString;
  out Value: TLandrixInvoiceLineStatusReasonCode): Boolean;

{ Maps a free-text unit of measure (German and English abbreviations and
  words, e.g. Stk, Std, kg, Pauschale; see
  https://apps.datev.de/help-center/documents/1020477) to a unit code. Case
  is ignored, umlauts may be written as ae/oe/ue/ss, m2/m3 also as m and a
  superscript digit. An empty text gives iuc_one. Returns ADefaultOnFailure
  and ASuccess = False for an unknown or ambiguous text (e.g. x, mal as
  usage count, Kopf/Tier, cubic feet).
  DE: Ordnet eine freie Mengeneinheit (deutsche und englische Abkuerzungen
  und Woerter, z. B. Stk, Std, kg, Pauschale) einem Einheitencode zu. Gross-
  und Kleinschreibung zaehlt nicht, Umlaute duerfen als ae/oe/ue/ss
  geschrieben sein, m2/m3 auch mit hochgestellter Ziffer. Ein leerer Text
  ergibt iuc_one. Liefert ADefaultOnFailure und ASuccess = False bei
  unbekanntem oder mehrdeutigem Text (z. B. x, mal als Nutzungsanzahl,
  Kopf/Tier, Kubikfuss). }
function LandrixEInvoiceUnitCodeFromUnitOfMeasure(const AUnitOfMeasure: TLandrixEInvoiceString;
  out ASuccess: Boolean;
  ADefaultOnFailure: TLandrixInvoiceUnitCode = iuc_piece): TLandrixInvoiceUnitCode;

{ Attachment MIME type for a file name by its extension (pdf, png, jpg,
  jpeg, csv, xlsx, ods, xml; case is ignored); iat_application_None for
  other extensions.
  DE: MIME-Typ eines Anhangs anhand der Dateiendung (pdf, png, jpg, jpeg,
  csv, xlsx, ods, xml; Gross- und Kleinschreibung zaehlt nicht);
  iat_application_None bei anderen Endungen. }
function LandrixEInvoiceAttachmentTypeFromFilename(const AFileName: string): TLandrixInvoiceAttachmentType;

implementation

{$IFNDEF FPC}
uses
  Types; { Delphi 13: TList.TDirection, hint H2443 at inherited Extract }
{$ENDIF}

{ --- helpers ------------------------------------------------------------ }

function AsciiUpper(C: WideChar): WideChar;
begin
  if (C >= 'a') and (C <= 'z') then
    Result := WideChar(Ord(C) - 32)
  else
    Result := C;
end;

{ ASCII case-insensitive comparison; other characters must be equal. }
function SameAsciiText(const A, B: TLandrixEInvoiceString): Boolean;
var
  I: Integer;
begin
  Result := Length(A) = Length(B);
  I := 1;
  while Result and (I <= Length(A)) do
  begin
    Result := AsciiUpper(A[I]) = AsciiUpper(B[I]);
    Inc(I);
  end;
end;

{ --- line status reason code ------------------------------------------- }

const
  LineStatusReasonCodes: array[TLandrixInvoiceLineStatusReasonCode] of TLandrixEInvoiceString = (
    '', 'DETAIL', 'GROUP', 'INFORMATION');

function LandrixEInvoiceLineStatusReasonCodeToStr(Value: TLandrixInvoiceLineStatusReasonCode): TLandrixEInvoiceString;
begin
  Result := LineStatusReasonCodes[Value];
end;

function LandrixEInvoiceLineStatusReasonCodeFromStr(const Code: TLandrixEInvoiceString;
  out Value: TLandrixInvoiceLineStatusReasonCode): Boolean;
var
  V: TLandrixInvoiceLineStatusReasonCode;
begin
  for V := Succ(Low(V)) to High(V) do
    if SameAsciiText(LineStatusReasonCodes[V], Code) then
    begin
      Value := V;
      Result := True;
      Exit;
    end;
  Value := Low(V);
  Result := False;
end;

{ --- unit of measure ---------------------------------------------------- }

type
  TUnitAlias = record
    Alias: AnsiString;
    UnitCode: TLandrixInvoiceUnitCode;
  end;

const
  { Normalized aliases (lower case ASCII, umlauts as ae/oe/ue/ss, 2/3 for
    superscript two/three). The first match wins. }
  UnitAliases: array[0..233] of TUnitAlias = (
    (Alias: 'st'; UnitCode: iuc_piece),
    (Alias: 'st.'; UnitCode: iuc_piece),
    (Alias: 'stk.'; UnitCode: iuc_piece),
    (Alias: 'stk'; UnitCode: iuc_piece),
    (Alias: 'pc'; UnitCode: iuc_piece),
    (Alias: 'pcs'; UnitCode: iuc_piece),
    (Alias: 'stueck'; UnitCode: iuc_piece),
    (Alias: 'stuecke'; UnitCode: iuc_piece),
    (Alias: 'piece'; UnitCode: iuc_piece),
    (Alias: 'pieces'; UnitCode: iuc_piece),
    (Alias: 'stck'; UnitCode: iuc_piece),
    (Alias: 'pauschale'; UnitCode: iuc_flaterate),
    (Alias: 'psch'; UnitCode: iuc_flaterate),
    (Alias: 'psch.'; UnitCode: iuc_flaterate),
    (Alias: 'pschl'; UnitCode: iuc_flaterate),
    (Alias: 'pschl.'; UnitCode: iuc_flaterate),
    (Alias: 'pausch'; UnitCode: iuc_flaterate),
    (Alias: 'pauschal'; UnitCode: iuc_flaterate),
    (Alias: 'flat'; UnitCode: iuc_flaterate),
    (Alias: 'flat rate'; UnitCode: iuc_flaterate),
    (Alias: 'lump sum'; UnitCode: iuc_flaterate),
    (Alias: 'fix'; UnitCode: iuc_flaterate),
    (Alias: 'mal'; UnitCode: iuc_one),
    (Alias: 'c62'; UnitCode: iuc_one),
    (Alias: 'ea'; UnitCode: iuc_one),
    (Alias: 'unit'; UnitCode: iuc_one),
    (Alias: 'units'; UnitCode: iuc_one),
    (Alias: 'one'; UnitCode: iuc_one),
    (Alias: 'ae'; UnitCode: iuc_one),
    (Alias: 'einheit'; UnitCode: iuc_one),
    (Alias: 'std'; UnitCode: iuc_hour),
    (Alias: 'std.'; UnitCode: iuc_hour),
    (Alias: 'stunde'; UnitCode: iuc_hour),
    (Alias: 'stunden'; UnitCode: iuc_hour),
    (Alias: 'hour'; UnitCode: iuc_hour),
    (Alias: 'hours'; UnitCode: iuc_hour),
    (Alias: 'h'; UnitCode: iuc_hour),
    (Alias: 'tag'; UnitCode: iuc_day),
    (Alias: 'd'; UnitCode: iuc_day),
    (Alias: 'day'; UnitCode: iuc_day),
    (Alias: 'days'; UnitCode: iuc_day),
    (Alias: 'tage'; UnitCode: iuc_day),
    (Alias: 'monat'; UnitCode: iuc_month),
    (Alias: 'mon'; UnitCode: iuc_month),
    (Alias: 'mo'; UnitCode: iuc_month),
    (Alias: 'mth'; UnitCode: iuc_month),
    (Alias: 'monate'; UnitCode: iuc_month),
    (Alias: 'month'; UnitCode: iuc_month),
    (Alias: 'months'; UnitCode: iuc_month),
    (Alias: 'mona'; UnitCode: iuc_month),
    (Alias: '%'; UnitCode: iuc_percent),
    (Alias: 'nt'; UnitCode: iuc_percent),
    (Alias: 'nte'; UnitCode: iuc_percent),
    (Alias: 'percent'; UnitCode: iuc_percent),
    (Alias: 'woche'; UnitCode: iuc_week),
    (Alias: 'wochen'; UnitCode: iuc_week),
    (Alias: 'week'; UnitCode: iuc_week),
    (Alias: 'weeks'; UnitCode: iuc_week),
    (Alias: 'mg'; UnitCode: iuc_milligram),
    (Alias: 'milligramm'; UnitCode: iuc_milligram),
    (Alias: 'milligram'; UnitCode: iuc_milligram),
    (Alias: 'g'; UnitCode: iuc_gram),
    (Alias: 'gr'; UnitCode: iuc_gram),
    (Alias: 'gramm'; UnitCode: iuc_gram),
    (Alias: 'gram'; UnitCode: iuc_gram),
    (Alias: 'kg'; UnitCode: iuc_kilogram),
    (Alias: 'kilogramm'; UnitCode: iuc_kilogram),
    (Alias: 'kilogram'; UnitCode: iuc_kilogram),
    (Alias: 'kilograms'; UnitCode: iuc_kilogram),
    (Alias: 'km'; UnitCode: iuc_kilometre),
    (Alias: 'kilometer'; UnitCode: iuc_kilometre),
    (Alias: 'kilometre'; UnitCode: iuc_kilometre),
    (Alias: 'kilometres'; UnitCode: iuc_kilometre),
    (Alias: 'kilometers'; UnitCode: iuc_kilometre),
    (Alias: 'kwh'; UnitCode: iuc_kilowatt_hour),
    (Alias: 'kilowattstunde'; UnitCode: iuc_kilowatt_hour),
    (Alias: 'kilowattstunden'; UnitCode: iuc_kilowatt_hour),
    (Alias: 'kilowatt hour'; UnitCode: iuc_kilowatt_hour),
    (Alias: 'kilowatt-hour'; UnitCode: iuc_kilowatt_hour),
    (Alias: 't'; UnitCode: iuc_tonne_metric_ton),
    (Alias: 'tonnen'; UnitCode: iuc_tonne_metric_ton),
    (Alias: 'ton'; UnitCode: iuc_tonne_metric_ton),
    (Alias: 'tons'; UnitCode: iuc_tonne_metric_ton),
    (Alias: 'tonne'; UnitCode: iuc_tonne_metric_ton),
    (Alias: 'qm'; UnitCode: iuc_square_metre),
    (Alias: 'm2'; UnitCode: iuc_square_metre),
    (Alias: 'quadratmeter'; UnitCode: iuc_square_metre),
    (Alias: 'square meter'; UnitCode: iuc_square_metre),
    (Alias: 'square meters'; UnitCode: iuc_square_metre),
    (Alias: 'square metre'; UnitCode: iuc_square_metre),
    (Alias: 'square metres'; UnitCode: iuc_square_metre),
    (Alias: 'qqm'; UnitCode: iuc_cubic_metre),
    (Alias: 'cbm'; UnitCode: iuc_cubic_metre),
    (Alias: 'm3'; UnitCode: iuc_cubic_metre),
    (Alias: 'kubikmeter'; UnitCode: iuc_cubic_metre),
    (Alias: 'cubic meter'; UnitCode: iuc_cubic_metre),
    (Alias: 'cubic meters'; UnitCode: iuc_cubic_metre),
    (Alias: 'cubic metre'; UnitCode: iuc_cubic_metre),
    (Alias: 'cubic metres'; UnitCode: iuc_cubic_metre),
    (Alias: 'm'; UnitCode: iuc_metre),
    (Alias: 'lfm'; UnitCode: iuc_metre),
    (Alias: 'meter'; UnitCode: iuc_metre),
    (Alias: 'meters'; UnitCode: iuc_metre),
    (Alias: 'metre'; UnitCode: iuc_metre),
    (Alias: 'metres'; UnitCode: iuc_metre),
    (Alias: 'mtr'; UnitCode: iuc_metre),
    (Alias: 'mm'; UnitCode: iuc_millimetre),
    (Alias: 'millimeter'; UnitCode: iuc_millimetre),
    (Alias: 'millimeters'; UnitCode: iuc_millimetre),
    (Alias: 'millimetre'; UnitCode: iuc_millimetre),
    (Alias: 'millimetres'; UnitCode: iuc_millimetre),
    (Alias: 'qmm'; UnitCode: iuc_square_millimetre),
    (Alias: 'mm2'; UnitCode: iuc_square_millimetre),
    (Alias: 'quadratmillimeter'; UnitCode: iuc_square_millimetre),
    (Alias: 'square millimeter'; UnitCode: iuc_square_millimetre),
    (Alias: 'square millimeters'; UnitCode: iuc_square_millimetre),
    (Alias: 'square millimetre'; UnitCode: iuc_square_millimetre),
    (Alias: 'square millimetres'; UnitCode: iuc_square_millimetre),
    (Alias: 'dm'; UnitCode: iuc_decimetre),
    (Alias: 'dezimeter'; UnitCode: iuc_decimetre),
    (Alias: 'decimeter'; UnitCode: iuc_decimetre),
    (Alias: 'decimetre'; UnitCode: iuc_decimetre),
    (Alias: 'dm2'; UnitCode: iuc_square_decimetre),
    (Alias: 'qdm'; UnitCode: iuc_square_decimetre),
    (Alias: 'quadratdezimeter'; UnitCode: iuc_square_decimetre),
    (Alias: 'square decimeter'; UnitCode: iuc_square_decimetre),
    (Alias: 'square decimetre'; UnitCode: iuc_square_decimetre),
    (Alias: 'dm3'; UnitCode: iuc_cubic_decimetre),
    (Alias: 'kubikdezimeter'; UnitCode: iuc_cubic_decimetre),
    (Alias: 'cubic decimeter'; UnitCode: iuc_cubic_decimetre),
    (Alias: 'cubic decimetre'; UnitCode: iuc_cubic_decimetre),
    (Alias: 'cm'; UnitCode: iuc_centimetre),
    (Alias: 'zentimeter'; UnitCode: iuc_centimetre),
    (Alias: 'centimeter'; UnitCode: iuc_centimetre),
    (Alias: 'centimeters'; UnitCode: iuc_centimetre),
    (Alias: 'centimetre'; UnitCode: iuc_centimetre),
    (Alias: 'centimetres'; UnitCode: iuc_centimetre),
    (Alias: 'cm2'; UnitCode: iuc_square_centimetre),
    (Alias: 'qcm'; UnitCode: iuc_square_centimetre),
    (Alias: 'quadratzentimeter'; UnitCode: iuc_square_centimetre),
    (Alias: 'square centimeter'; UnitCode: iuc_square_centimetre),
    (Alias: 'square centimeters'; UnitCode: iuc_square_centimetre),
    (Alias: 'square centimetre'; UnitCode: iuc_square_centimetre),
    (Alias: 'square centimetres'; UnitCode: iuc_square_centimetre),
    (Alias: 'cm3'; UnitCode: iuc_cubic_centimetre),
    (Alias: 'ccm'; UnitCode: iuc_cubic_centimetre),
    (Alias: 'kubikzentimeter'; UnitCode: iuc_cubic_centimetre),
    (Alias: 'cubic centimeter'; UnitCode: iuc_cubic_centimetre),
    (Alias: 'cubic centimeters'; UnitCode: iuc_cubic_centimetre),
    (Alias: 'cubic centimetre'; UnitCode: iuc_cubic_centimetre),
    (Alias: 'cubic centimetres'; UnitCode: iuc_cubic_centimetre),
    (Alias: 'paar'; UnitCode: iuc_pair),
    (Alias: 'paare'; UnitCode: iuc_pair),
    (Alias: 'pr'; UnitCode: iuc_pair),
    (Alias: 'pair'; UnitCode: iuc_pair),
    (Alias: 'pairs'; UnitCode: iuc_pair),
    (Alias: 'mm3'; UnitCode: iuc_cubic_millimetre),
    (Alias: 'kubikmillimeter'; UnitCode: iuc_cubic_millimetre),
    (Alias: 'cubic millimeter'; UnitCode: iuc_cubic_millimetre),
    (Alias: 'cubic millimeters'; UnitCode: iuc_cubic_millimetre),
    (Alias: 'cubic millimetre'; UnitCode: iuc_cubic_millimetre),
    (Alias: 'cubic millimetres'; UnitCode: iuc_cubic_millimetre),
    (Alias: 'min'; UnitCode: iuc_minute_unit_of_time),
    (Alias: 'minute'; UnitCode: iuc_minute_unit_of_time),
    (Alias: 'minuten'; UnitCode: iuc_minute_unit_of_time),
    (Alias: 'minutes'; UnitCode: iuc_minute_unit_of_time),
    (Alias: 'sek'; UnitCode: iuc_second_unit_of_time),
    (Alias: 's'; UnitCode: iuc_second_unit_of_time),
    (Alias: 'sekunde'; UnitCode: iuc_second_unit_of_time),
    (Alias: 'sekunden'; UnitCode: iuc_second_unit_of_time),
    (Alias: 'sec'; UnitCode: iuc_second_unit_of_time),
    (Alias: 'second'; UnitCode: iuc_second_unit_of_time),
    (Alias: 'seconds'; UnitCode: iuc_second_unit_of_time),
    (Alias: 'ml'; UnitCode: iuc_millilitre),
    (Alias: 'milliliter'; UnitCode: iuc_millilitre),
    (Alias: 'milliliters'; UnitCode: iuc_millilitre),
    (Alias: 'millilitre'; UnitCode: iuc_millilitre),
    (Alias: 'millilitres'; UnitCode: iuc_millilitre),
    (Alias: 'l'; UnitCode: iuc_litre),
    (Alias: 'ltr'; UnitCode: iuc_litre),
    (Alias: 'liter'; UnitCode: iuc_litre),
    (Alias: 'liters'; UnitCode: iuc_litre),
    (Alias: 'litre'; UnitCode: iuc_litre),
    (Alias: 'litres'; UnitCode: iuc_litre),
    (Alias: 'paket'; UnitCode: iuc_packaging),
    (Alias: 'packet'; UnitCode: iuc_packaging),
    (Alias: 'pkg'; UnitCode: iuc_packaging),
    (Alias: 'parcel'; UnitCode: iuc_packaging),
    (Alias: 'pck'; UnitCode: iuc_packaging),
    (Alias: 'pack'; UnitCode: iuc_packaging),
    (Alias: 'vp'; UnitCode: iuc_packaging),
    (Alias: 'pak'; UnitCode: iuc_packaging),
    (Alias: 'kart.'; UnitCode: iuc_packaging),
    (Alias: 'anz'; UnitCode: iuc_number_of_articles),
    (Alias: 'anzahl'; UnitCode: iuc_number_of_articles),
    (Alias: 'qty'; UnitCode: iuc_number_of_articles),
    (Alias: 'set'; UnitCode: iuc_set),
    (Alias: 'sets'; UnitCode: iuc_set),
    (Alias: 'satz'; UnitCode: iuc_set),
    (Alias: 'j'; UnitCode: iuc_year),
    (Alias: 'y'; UnitCode: iuc_year),
    (Alias: 'yr'; UnitCode: iuc_year),
    (Alias: 'jahr'; UnitCode: iuc_year),
    (Alias: 'jahre'; UnitCode: iuc_year),
    (Alias: 'year'; UnitCode: iuc_year),
    (Alias: 'years'; UnitCode: iuc_year),
    (Alias: 'person'; UnitCode: iuc_person),
    (Alias: 'personen'; UnitCode: iuc_person),
    (Alias: 'pers'; UnitCode: iuc_person),
    (Alias: 'persons'; UnitCode: iuc_person),
    (Alias: 'people'; UnitCode: iuc_person),
    (Alias: 'kopf'; UnitCode: iuc_person),
    (Alias: 'kpf'; UnitCode: iuc_person),
    (Alias: 'koepfe'; UnitCode: iuc_person),
    (Alias: 'sack'; UnitCode: iuc_sack),
    (Alias: 'saecke'; UnitCode: iuc_sack),
    (Alias: 'sck'; UnitCode: iuc_sack),
    (Alias: 'beutel'; UnitCode: iuc_bag),
    (Alias: 'bag'; UnitCode: iuc_bag),
    (Alias: 'bags'; UnitCode: iuc_bag),
    (Alias: 'rolle'; UnitCode: iuc_roll),
    (Alias: 'rollen'; UnitCode: iuc_roll),
    (Alias: 'rol'; UnitCode: iuc_roll),
    (Alias: 'roll'; UnitCode: iuc_roll),
    (Alias: 'rolls'; UnitCode: iuc_roll),
    (Alias: 'ft'; UnitCode: iuc_foot),
    (Alias: 'foot'; UnitCode: iuc_foot),
    (Alias: 'feet'; UnitCode: iuc_foot),
    (Alias: 'fuss'; UnitCode: iuc_foot),
    (Alias: 'inch'; UnitCode: iuc_inch),
    (Alias: 'zoll'; UnitCode: iuc_inch),
    (Alias: 'ha'; UnitCode: iuc_hectare),
    (Alias: 'hektar'; UnitCode: iuc_hectare),
    (Alias: 'hectare'; UnitCode: iuc_hectare)
  );

{ Trims, lowers ASCII letters and spells out umlauts, sharp s and
  superscript two/three. False if another non-ASCII character remains. }
function NormalizeUnitOfMeasure(const S: TLandrixEInvoiceString; out Key: AnsiString): Boolean;
var
  First, Last, I: Integer;
  C: WideChar;
begin
  Key := '';
  Result := True;
  First := 1;
  Last := Length(S);
  while (First <= Last) and (Ord(S[First]) <= 32) do
    Inc(First);
  while (Last >= First) and (Ord(S[Last]) <= 32) do
    Dec(Last);
  for I := First to Last do
  begin
    C := S[I];
    case Ord(C) of
      Ord('A')..Ord('Z'):
        Key := Key + AnsiChar(Ord(C) + 32);
      0..Ord('A') - 1, Ord('Z') + 1..$7F:
        Key := Key + AnsiChar(Ord(C));
      $00C4, $00E4:
        Key := Key + 'ae';
      $00D6, $00F6:
        Key := Key + 'oe';
      $00DC, $00FC:
        Key := Key + 'ue';
      $00DF, $1E9E:
        Key := Key + 'ss';
      $00B2:
        Key := Key + '2';
      $00B3:
        Key := Key + '3';
    else
      Result := False;
      Exit;
    end;
  end;
end;

function LandrixEInvoiceUnitCodeFromUnitOfMeasure(const AUnitOfMeasure: TLandrixEInvoiceString;
  out ASuccess: Boolean;
  ADefaultOnFailure: TLandrixInvoiceUnitCode): TLandrixInvoiceUnitCode;
var
  Key: AnsiString;
  I: Integer;
begin
  Result := ADefaultOnFailure;
  ASuccess := False;
  if not NormalizeUnitOfMeasure(AUnitOfMeasure, Key) then
    Exit;
  if Key = '' then
  begin
    Result := iuc_one;
    ASuccess := True;
    Exit;
  end;
  for I := Low(UnitAliases) to High(UnitAliases) do
    if UnitAliases[I].Alias = Key then
    begin
      Result := UnitAliases[I].UnitCode;
      ASuccess := True;
      Exit;
    end;
end;

function LandrixEInvoiceAttachmentTypeFromFilename(const AFileName: string): TLandrixInvoiceAttachmentType;
var
  Ext: string;
begin
  Result := iat_application_None;
  Ext := LowerCase(ExtractFileExt(AFileName));
  if Ext = '.xlsx' then
    Result := iat_application_vnd_openxmlformats_officedocument_spreadsheetml_sheet
  else if Ext = '.ods' then
    Result := iat_application_vnd_oasis_opendocument_spreadsheet
  else if Ext = '.csv' then
    Result := iat_text_csv
  else if (Ext = '.jpg') or (Ext = '.jpeg') then
    Result := iat_image_jpeg
  else if Ext = '.pdf' then
    Result := iat_application_pdf
  else if Ext = '.png' then
    Result := iat_image_png
  else if Ext = '.xml' then
    Result := iat_application_xml;
end;

{ --- TLandrixInvoiceAttachment ------------------------------------------ }

constructor TLandrixInvoiceAttachment.Create(AAttachmentType: TLandrixInvoiceAttachmentType);
begin
  inherited Create;
  TypeCode := iatc_916;
  AttachmentType := AAttachmentType;
  Data := TMemoryStream.Create;
  ExternalReference := '';
  SchemeID := '';
end;

destructor TLandrixInvoiceAttachment.Destroy;
begin
  Data.Free;
  Data := nil;
  inherited;
end;

function TLandrixInvoiceAttachment.ContainsBinaryObject: Boolean;
begin
  Result := Data.Size > 0;
end;

procedure TLandrixInvoiceAttachment.EmbedDataFromStream(AStream: TStream);
begin
  if AStream = nil then
    Exit;
  Data.Clear;
  Data.LoadFromStream(AStream);
end;

procedure TLandrixInvoiceAttachment.EmbedDataFromFile(const AFileName: string);
var
  Stream: TFileStream;
begin
  if not FileExists(AFileName) then
    Exit;
  Stream := TFileStream.Create(AFileName, fmOpenRead or fmShareDenyNone);
  try
    EmbedDataFromStream(Stream);
  finally
    Stream.Free;
  end;
end;

procedure WriteUtf8(Stream: TMemoryStream; const S: TLandrixXmlUtf8);
begin
  Stream.Clear;
  if Length(S) > 0 then
    Stream.WriteBuffer(PAnsiChar(S)^, Length(S));
  Stream.Position := 0;
end;

procedure TLandrixInvoiceAttachment.EmbedDataFromText(const AValue: TStrings);
begin
  if AValue = nil then
    Exit;
  WriteUtf8(Data, LandrixXmlStringToUtf8(AValue.Text));
end;

procedure TLandrixInvoiceAttachment.EmbedDataFromText(const AValue: TLandrixEInvoiceString);
begin
  WriteUtf8(Data, LandrixEInvoiceStringToUtf8(AValue));
end;

function TLandrixInvoiceAttachment.GetDataAsBase64: TLandrixEInvoiceString;
var
  Buffer: TLandrixXmlBuffer;
begin
  Result := '';
  if Data.Size = 0 then
    Exit;
  { 4 output bytes per 3 input bytes must fit an Integer }
  if Data.Size > (MaxInt div 4) * 3 then
    raise ELandrixEInvoiceError.Create('Attachment too large for a Base64 string');
  Buffer := TLandrixXmlBuffer.Create;
  try
    LandrixXmlBase64Encode(Data.Memory^, Integer(Data.Size), Buffer);
    Result := LandrixEInvoiceUtf8ToString(Buffer.AsUtf8);
  finally
    Buffer.Free;
  end;
end;

procedure TLandrixInvoiceAttachment.SetDataFromBase64(const AValue: TLandrixEInvoiceString);
var
  Encoded: TLandrixXmlUtf8;
begin
  Data.Clear;
  if AValue = '' then
    Exit;
  Encoded := LandrixEInvoiceStringToUtf8(AValue);
  LandrixXmlBase64DecodeToStream(PAnsiChar(Encoded), Length(Encoded), Data);
  Data.Position := 0;
end;

{ --- TLandrixInvoiceAttachmentList -------------------------------------- }

function TLandrixInvoiceAttachmentList.GetItem(Index: TLandrixEInvoiceListIndex): TLandrixInvoiceAttachment;
begin
  Result := TLandrixInvoiceAttachment(inherited Items[Index]);
end;

procedure TLandrixInvoiceAttachmentList.SetItem(Index: TLandrixEInvoiceListIndex; AItem: TLandrixInvoiceAttachment);
begin
  inherited Items[Index] := AItem;
end;

function TLandrixInvoiceAttachmentList.Extract(Item: TObject): TLandrixInvoiceAttachment;
begin
  Result := TLandrixInvoiceAttachment(inherited Extract(Item));
end;

function TLandrixInvoiceAttachmentList.First: TLandrixInvoiceAttachment;
begin
  if Count = 0 then
    Result := nil
  else
    Result := TLandrixInvoiceAttachment(inherited First);
end;

function TLandrixInvoiceAttachmentList.Last: TLandrixInvoiceAttachment;
begin
  if Count = 0 then
    Result := nil
  else
    Result := TLandrixInvoiceAttachment(inherited Last);
end;

function TLandrixInvoiceAttachmentList.AddAttachment(AAttachmentType: TLandrixInvoiceAttachmentType): TLandrixInvoiceAttachment;
begin
  Result := TLandrixInvoiceAttachment.Create(AAttachmentType);
  Add(Result);
end;

function TLandrixInvoiceAttachmentList.TryAddAttachmentByExtension(const AFileName: string;
  out AAttachment: TLandrixInvoiceAttachment): Boolean;
var
  FileType: TLandrixInvoiceAttachmentType;
begin
  Result := False;
  AAttachment := nil;
  if not FileExists(AFileName) then
    Exit;
  FileType := LandrixEInvoiceAttachmentTypeFromFilename(AFileName);
  if FileType = iat_application_None then
    Exit;
  AAttachment := AddAttachment(FileType);
  Result := True;
end;

{ --- TLandrixInvoicePrepaidPaymentList ---------------------------------- }

function TLandrixInvoicePrepaidPaymentList.GetItem(Index: TLandrixEInvoiceListIndex): TLandrixInvoicePrepaidPayment;
begin
  Result := TLandrixInvoicePrepaidPayment(inherited Items[Index]);
end;

procedure TLandrixInvoicePrepaidPaymentList.SetItem(Index: TLandrixEInvoiceListIndex; AItem: TLandrixInvoicePrepaidPayment);
begin
  inherited Items[Index] := AItem;
end;

function TLandrixInvoicePrepaidPaymentList.Extract(Item: TObject): TLandrixInvoicePrepaidPayment;
begin
  Result := TLandrixInvoicePrepaidPayment(inherited Extract(Item));
end;

function TLandrixInvoicePrepaidPaymentList.First: TLandrixInvoicePrepaidPayment;
begin
  if Count = 0 then
    Result := nil
  else
    Result := TLandrixInvoicePrepaidPayment(inherited First);
end;

function TLandrixInvoicePrepaidPaymentList.Last: TLandrixInvoicePrepaidPayment;
begin
  if Count = 0 then
    Result := nil
  else
    Result := TLandrixInvoicePrepaidPayment(inherited Last);
end;

function TLandrixInvoicePrepaidPaymentList.AddPrepaidPayment: TLandrixInvoicePrepaidPayment;
begin
  Result := TLandrixInvoicePrepaidPayment.Create;
  Add(Result);
end;

{ --- TLandrixInvoiceAllowanceCharges ------------------------------------ }

function TLandrixInvoiceAllowanceCharges.GetItem(Index: TLandrixEInvoiceListIndex): TLandrixInvoiceAllowanceCharge;
begin
  Result := TLandrixInvoiceAllowanceCharge(inherited Items[Index]);
end;

procedure TLandrixInvoiceAllowanceCharges.SetItem(Index: TLandrixEInvoiceListIndex; AItem: TLandrixInvoiceAllowanceCharge);
begin
  inherited Items[Index] := AItem;
end;

function TLandrixInvoiceAllowanceCharges.Extract(Item: TObject): TLandrixInvoiceAllowanceCharge;
begin
  Result := TLandrixInvoiceAllowanceCharge(inherited Extract(Item));
end;

function TLandrixInvoiceAllowanceCharges.First: TLandrixInvoiceAllowanceCharge;
begin
  if Count = 0 then
    Result := nil
  else
    Result := TLandrixInvoiceAllowanceCharge(inherited First);
end;

function TLandrixInvoiceAllowanceCharges.Last: TLandrixInvoiceAllowanceCharge;
begin
  if Count = 0 then
    Result := nil
  else
    Result := TLandrixInvoiceAllowanceCharge(inherited Last);
end;

function TLandrixInvoiceAllowanceCharges.AddAllowanceCharge: TLandrixInvoiceAllowanceCharge;
begin
  Result := TLandrixInvoiceAllowanceCharge.Create;
  Add(Result);
end;

{ --- TLandrixInvoiceLineItemAttributes ---------------------------------- }

function TLandrixInvoiceLineItemAttributes.GetItem(Index: TLandrixEInvoiceListIndex): TLandrixInvoiceLineItemAttribute;
begin
  Result := TLandrixInvoiceLineItemAttribute(inherited Items[Index]);
end;

procedure TLandrixInvoiceLineItemAttributes.SetItem(Index: TLandrixEInvoiceListIndex; AItem: TLandrixInvoiceLineItemAttribute);
begin
  inherited Items[Index] := AItem;
end;

function TLandrixInvoiceLineItemAttributes.Extract(Item: TObject): TLandrixInvoiceLineItemAttribute;
begin
  Result := TLandrixInvoiceLineItemAttribute(inherited Extract(Item));
end;

function TLandrixInvoiceLineItemAttributes.First: TLandrixInvoiceLineItemAttribute;
begin
  if Count = 0 then
    Result := nil
  else
    Result := TLandrixInvoiceLineItemAttribute(inherited First);
end;

function TLandrixInvoiceLineItemAttributes.Last: TLandrixInvoiceLineItemAttribute;
begin
  if Count = 0 then
    Result := nil
  else
    Result := TLandrixInvoiceLineItemAttribute(inherited Last);
end;

function TLandrixInvoiceLineItemAttributes.AddItemAttribute: TLandrixInvoiceLineItemAttribute;
begin
  Result := TLandrixInvoiceLineItemAttribute.Create;
  Add(Result);
end;

{ --- TLandrixInvoiceLineItemClassifications ----------------------------- }

function TLandrixInvoiceLineItemClassifications.GetItem(Index: TLandrixEInvoiceListIndex): TLandrixInvoiceLineItemClassification;
begin
  Result := TLandrixInvoiceLineItemClassification(inherited Items[Index]);
end;

procedure TLandrixInvoiceLineItemClassifications.SetItem(Index: TLandrixEInvoiceListIndex; AItem: TLandrixInvoiceLineItemClassification);
begin
  inherited Items[Index] := AItem;
end;

function TLandrixInvoiceLineItemClassifications.Extract(Item: TObject): TLandrixInvoiceLineItemClassification;
begin
  Result := TLandrixInvoiceLineItemClassification(inherited Extract(Item));
end;

function TLandrixInvoiceLineItemClassifications.First: TLandrixInvoiceLineItemClassification;
begin
  if Count = 0 then
    Result := nil
  else
    Result := TLandrixInvoiceLineItemClassification(inherited First);
end;

function TLandrixInvoiceLineItemClassifications.Last: TLandrixInvoiceLineItemClassification;
begin
  if Count = 0 then
    Result := nil
  else
    Result := TLandrixInvoiceLineItemClassification(inherited Last);
end;

function TLandrixInvoiceLineItemClassifications.AddItemClassification: TLandrixInvoiceLineItemClassification;
begin
  Result := TLandrixInvoiceLineItemClassification.Create;
  Add(Result);
end;

{ --- TLandrixInvoiceLine ------------------------------------------------ }

constructor TLandrixInvoiceLine.Create;
begin
  inherited Create;
  AllowanceCharges := TLandrixInvoiceAllowanceCharges.Create;
  SubInvoiceLines := TLandrixInvoiceLines.Create;
  ItemAttributes := TLandrixInvoiceLineItemAttributes.Create;
  ItemClassifications := TLandrixInvoiceLineItemClassifications.Create;
  Clear;
end;

procedure TLandrixInvoiceLine.Clear;
begin
  ID := '';
  GlobalID_EAN_GTIN := '';
  StandardItemIdentifier := '';
  StandardItemIdentifierSchemeID := '';
  Note := '';
  ObjectIdentifier := '';
  ObjectIdentifierSchemeID := '';
  Name := '';
  Description := '';
  Quantity := 0;
  UnitCode := iuc_None;
  UnitCodeOther := '';
  SellersItemIdentification := '';
  BuyersItemIdentification := '';
  OrderNumber := '';
  OrderDate.Clear;
  OrderLineReference := '';
  BuyerAccountingReference := '';
  TaxPercent := 0;
  TaxCategory := idtfcc_None;
  TaxCategoryOther := '';
  TaxExemptionReason := '';
  GrossPriceAmount := 0;
  DiscountOnTheGrossPrice := 0;
  NetPriceAmount := 0;
  BaseQuantity := 0;
  BaseQuantityUnitCode := iuc_None;
  BaseQuantityUnitCodeOther := '';
  LineAmount := 0;
  AllowanceCharges.Clear;
  InvoiceLinePeriodStartDate := 0;
  InvoiceLinePeriodEndDate := 0;
  ItemClassifications.Clear;
  OriginTradeCountry := '';
  ItemAttributes.Clear;
  DeliveryNoteNumber := '';
  DeliveryNoteLineID := '';
  DeliveryNoteDate := 0;
  ActualDeliveryDate := 0;
  SubInvoiceLines.Clear;
  LineStatusReasonCode := ilsrc_None;
  LineStatusReasonCodeOther := '';
end;

destructor TLandrixInvoiceLine.Destroy;
begin
  AllowanceCharges.Free;
  AllowanceCharges := nil;
  SubInvoiceLines.Free;
  SubInvoiceLines := nil;
  ItemAttributes.Free;
  ItemAttributes := nil;
  ItemClassifications.Free;
  ItemClassifications := nil;
  inherited;
end;

{ --- TLandrixInvoiceLines ----------------------------------------------- }

function TLandrixInvoiceLines.GetItem(Index: TLandrixEInvoiceListIndex): TLandrixInvoiceLine;
begin
  Result := TLandrixInvoiceLine(inherited Items[Index]);
end;

procedure TLandrixInvoiceLines.SetItem(Index: TLandrixEInvoiceListIndex; AItem: TLandrixInvoiceLine);
begin
  inherited Items[Index] := AItem;
end;

function TLandrixInvoiceLines.Extract(Item: TObject): TLandrixInvoiceLine;
begin
  Result := TLandrixInvoiceLine(inherited Extract(Item));
end;

function TLandrixInvoiceLines.First: TLandrixInvoiceLine;
begin
  if Count = 0 then
    Result := nil
  else
    Result := TLandrixInvoiceLine(inherited First);
end;

function TLandrixInvoiceLines.Last: TLandrixInvoiceLine;
begin
  if Count = 0 then
    Result := nil
  else
    Result := TLandrixInvoiceLine(inherited Last);
end;

function TLandrixInvoiceLines.AddInvoiceLine: TLandrixInvoiceLine;
begin
  Result := TLandrixInvoiceLine.Create;
  Add(Result);
end;

{ --- TLandrixInvoiceTaxAmount ------------------------------------------- }

constructor TLandrixInvoiceTaxAmount.Create;
begin
  inherited Create;
  TaxableAmount := 0;
  TaxAmount := 0;
  TaxPercent := 0;
  TaxCategory := idtfcc_None;
  TaxCategoryOther := '';
  TaxExemptionReason := '';
  TaxExemptionReasonCode := '';
end;

{ --- TLandrixInvoiceTaxAmounts ------------------------------------------ }

function TLandrixInvoiceTaxAmounts.GetItem(Index: TLandrixEInvoiceListIndex): TLandrixInvoiceTaxAmount;
begin
  Result := TLandrixInvoiceTaxAmount(inherited Items[Index]);
end;

procedure TLandrixInvoiceTaxAmounts.SetItem(Index: TLandrixEInvoiceListIndex; AItem: TLandrixInvoiceTaxAmount);
begin
  inherited Items[Index] := AItem;
end;

function TLandrixInvoiceTaxAmounts.Extract(Item: TObject): TLandrixInvoiceTaxAmount;
begin
  Result := TLandrixInvoiceTaxAmount(inherited Extract(Item));
end;

function TLandrixInvoiceTaxAmounts.First: TLandrixInvoiceTaxAmount;
begin
  if Count = 0 then
    Result := nil
  else
    Result := TLandrixInvoiceTaxAmount(inherited First);
end;

function TLandrixInvoiceTaxAmounts.Last: TLandrixInvoiceTaxAmount;
begin
  if Count = 0 then
    Result := nil
  else
    Result := TLandrixInvoiceTaxAmount(inherited Last);
end;

function TLandrixInvoiceTaxAmounts.AddTaxAmount: TLandrixInvoiceTaxAmount;
begin
  Result := TLandrixInvoiceTaxAmount.Create;
  Add(Result);
end;

function TLandrixInvoiceTaxAmounts.AddTaxAmountIfTaxExists(ATaxPercent: Double;
  ATaxableAmount, ATaxAmount: Currency): Boolean;
var
  I: TLandrixEInvoiceListIndex;
begin
  Result := False;
  for I := 0 to Count - 1 do
    if Items[I].TaxPercent = ATaxPercent then
    begin
      Items[I].TaxableAmount := Items[I].TaxableAmount + ATaxableAmount;
      Items[I].TaxAmount := Items[I].TaxAmount + ATaxAmount;
      Result := True;
      Break;
    end;
end;

{ --- TLandrixInvoiceAddress --------------------------------------------- }

procedure TLandrixInvoiceAddress.Clear;
begin
  StreetName := '';
  AdditionalStreetName := '';
  City := '';
  PostalZone := '';
  CountrySubentity := '';
  AddressLine := '';
  CountryCode := '';
end;

{ --- TLandrixInvoiceAccountingParty ------------------------------------- }

constructor TLandrixInvoiceAccountingParty.Create;
begin
  inherited Create;
  Address := TLandrixInvoiceAddress.Create;
  Clear;
end;

destructor TLandrixInvoiceAccountingParty.Destroy;
begin
  Address.Free;
  Address := nil;
  inherited;
end;

procedure TLandrixInvoiceAccountingParty.Clear;
begin
  Name := '';
  RegistrationName := '';
  CompanyID := '';
  CompanyIDSchemeID := '';
  Address.Clear;
  IdentifierSellerBuyer := '';
  GlobalIdentifierSellerBuyer := '';
  GlobalIdentifierSellerBuyerSchemeID := '';
  BankAssignedCreditorIdentifier := '';
  VATCompanyID := '';
  VATCompanyNumber := '';
  ContactName := '';
  ContactDepartment := '';
  ContactTelephone := '';
  ContactElectronicMail := '';
  AdditionalLegalInformationSeller := '';
  ElectronicAddressSellerBuyer := '';
  ElectronicAddressSellerBuyerSchemeID := '';
end;

{ --- TLandrixInvoiceParty ------------------------------------------------ }

constructor TLandrixInvoiceParty.Create;
begin
  inherited Create;
  Address := TLandrixInvoiceAddress.Create;
  Clear;
end;

destructor TLandrixInvoiceParty.Destroy;
begin
  Address.Free;
  Address := nil;
  inherited;
end;

procedure TLandrixInvoiceParty.Clear;
begin
  Name := '';
  Identifier := '';
  IdentifierSchemeID := '';
  CompanyID := '';
  CompanyIDSchemeID := '';
  VATCompanyID := '';
  Address.Clear;
  ContactName := '';
  ContactDepartment := '';
  ContactTelephone := '';
  ContactElectronicMail := '';
end;

function TLandrixInvoiceParty.IsEmpty: Boolean;
begin
  Result := (Name = '') and (Identifier = '') and (IdentifierSchemeID = '') and (CompanyID = '') and
    (CompanyIDSchemeID = '') and (VATCompanyID = '') and (Address.StreetName = '') and
    (Address.AdditionalStreetName = '') and (Address.City = '') and (Address.PostalZone = '') and
    (Address.CountrySubentity = '') and (Address.AddressLine = '') and (Address.CountryCode = '') and
    (ContactName = '') and (ContactDepartment = '') and (ContactTelephone = '') and
    (ContactElectronicMail = '');
end;

{ --- TLandrixInvoiceDeliveryInformation --------------------------------- }

constructor TLandrixInvoiceDeliveryInformation.Create;
begin
  inherited Create;
  Address := TLandrixInvoiceAddress.Create;
  Clear;
end;

destructor TLandrixInvoiceDeliveryInformation.Destroy;
begin
  Address.Free;
  Address := nil;
  inherited;
end;

procedure TLandrixInvoiceDeliveryInformation.Clear;
begin
  Name := '';
  LocationIdentifier := '';
  LocationIdentifierSchemeID := '0088';
  Address.Clear;
  ActualDeliveryDate := 0;
  ContactName := '';
  ContactTelephone := '';
  ContactElectronicMail := '';
end;

{ --- TLandrixInvoicePrecedingInvoiceReferences -------------------------- }

function TLandrixInvoicePrecedingInvoiceReferences.GetItem(Index: TLandrixEInvoiceListIndex): TLandrixInvoicePrecedingInvoiceReference;
begin
  Result := TLandrixInvoicePrecedingInvoiceReference(inherited Items[Index]);
end;

procedure TLandrixInvoicePrecedingInvoiceReferences.SetItem(Index: TLandrixEInvoiceListIndex; AItem: TLandrixInvoicePrecedingInvoiceReference);
begin
  inherited Items[Index] := AItem;
end;

function TLandrixInvoicePrecedingInvoiceReferences.Extract(Item: TObject): TLandrixInvoicePrecedingInvoiceReference;
begin
  Result := TLandrixInvoicePrecedingInvoiceReference(inherited Extract(Item));
end;

function TLandrixInvoicePrecedingInvoiceReferences.First: TLandrixInvoicePrecedingInvoiceReference;
begin
  if Count = 0 then
    Result := nil
  else
    Result := TLandrixInvoicePrecedingInvoiceReference(inherited First);
end;

function TLandrixInvoicePrecedingInvoiceReferences.Last: TLandrixInvoicePrecedingInvoiceReference;
begin
  if Count = 0 then
    Result := nil
  else
    Result := TLandrixInvoicePrecedingInvoiceReference(inherited Last);
end;

function TLandrixInvoicePrecedingInvoiceReferences.AddPrecedingInvoiceReference: TLandrixInvoicePrecedingInvoiceReference;
begin
  Result := TLandrixInvoicePrecedingInvoiceReference.Create;
  Add(Result);
end;

function TLandrixInvoicePrecedingInvoiceReferences.IndexOfPrecedingInvoiceReference(
  const AID: TLandrixEInvoiceString): TLandrixEInvoiceListIndex;
var
  I: TLandrixEInvoiceListIndex;
begin
  Result := -1;
  for I := 0 to Count - 1 do
    if SameAsciiText(AID, Items[I].ID) then
    begin
      Result := I;
      Break;
    end;
end;

{ --- TLandrixInvoiceNote ------------------------------------------------ }

constructor TLandrixInvoiceNote.Create;
begin
  inherited Create;
  Content := '';
  SubjectCode := insc_None;
  SubjectCodeOther := '';
end;

{ --- TLandrixInvoiceNotes ----------------------------------------------- }

function TLandrixInvoiceNotes.GetItem(Index: TLandrixEInvoiceListIndex): TLandrixInvoiceNote;
begin
  Result := TLandrixInvoiceNote(inherited Items[Index]);
end;

procedure TLandrixInvoiceNotes.SetItem(Index: TLandrixEInvoiceListIndex; AItem: TLandrixInvoiceNote);
begin
  inherited Items[Index] := AItem;
end;

function TLandrixInvoiceNotes.Extract(Item: TObject): TLandrixInvoiceNote;
begin
  Result := TLandrixInvoiceNote(inherited Extract(Item));
end;

function TLandrixInvoiceNotes.First: TLandrixInvoiceNote;
begin
  if Count = 0 then
    Result := nil
  else
    Result := TLandrixInvoiceNote(inherited First);
end;

function TLandrixInvoiceNotes.Last: TLandrixInvoiceNote;
begin
  if Count = 0 then
    Result := nil
  else
    Result := TLandrixInvoiceNote(inherited Last);
end;

function TLandrixInvoiceNotes.AddNote: TLandrixInvoiceNote;
begin
  Result := TLandrixInvoiceNote.Create;
  Add(Result);
end;

function TLandrixInvoiceNotes.NodeContentsAsText: TLandrixEInvoiceString;
var
  I: TLandrixEInvoiceListIndex;
begin
  Result := '';
  for I := 0 to Count - 1 do
  begin
    Result := Result + Items[I].Content;
    if I < Count - 1 then
      Result := Result + #13#10;
  end;
end;

procedure TLandrixInvoiceNotes.ReplaceContentWith(const AContent: TLandrixEInvoiceString);
begin
  Clear;
  if AContent <> '' then
    AddNote.Content := AContent;
end;

{ --- TLandrixInvoicePaymentType ----------------------------------------- }

constructor TLandrixInvoicePaymentType.Create;
begin
  inherited Create;
  PaymentMeansCode := ipmc_NotImplemented;
  PaymentMeansCodeOther := '';
  PaymentMeansInformation := '';
  FinancialAccount := '';
  FinancialAccountName := '';
  FinancialInstitutionBranch := '';
end;

{ --- TLandrixInvoicePaymentTypeList ------------------------------------- }

function TLandrixInvoicePaymentTypeList.GetItem(Index: TLandrixEInvoiceListIndex): TLandrixInvoicePaymentType;
begin
  Result := TLandrixInvoicePaymentType(inherited Items[Index]);
end;

procedure TLandrixInvoicePaymentTypeList.SetItem(Index: TLandrixEInvoiceListIndex; AItem: TLandrixInvoicePaymentType);
begin
  inherited Items[Index] := AItem;
end;

function TLandrixInvoicePaymentTypeList.Extract(Item: TObject): TLandrixInvoicePaymentType;
begin
  Result := TLandrixInvoicePaymentType(inherited Extract(Item));
end;

function TLandrixInvoicePaymentTypeList.First: TLandrixInvoicePaymentType;
begin
  if Count = 0 then
    Result := nil
  else
    Result := TLandrixInvoicePaymentType(inherited First);
end;

function TLandrixInvoicePaymentTypeList.Last: TLandrixInvoicePaymentType;
begin
  if Count = 0 then
    Result := nil
  else
    Result := TLandrixInvoicePaymentType(inherited Last);
end;

function TLandrixInvoicePaymentTypeList.AddPaymentType: TLandrixInvoicePaymentType;
begin
  Result := TLandrixInvoicePaymentType.Create;
  Add(Result);
end;

{ --- TLandrixInvoice ---------------------------------------------------- }

constructor TLandrixInvoice.Create;
begin
  inherited Create;
  PaymentTypes := TLandrixInvoicePaymentTypeList.Create;
  InvoiceLines := TLandrixInvoiceLines.Create;
  Attachments := TLandrixInvoiceAttachmentList.Create;
  PrepaidPayments := TLandrixInvoicePrepaidPaymentList.Create;
  AllowanceCharges := TLandrixInvoiceAllowanceCharges.Create;
  PrecedingInvoiceReferences := TLandrixInvoicePrecedingInvoiceReferences.Create;
  TaxAmountSubtotals := TLandrixInvoiceTaxAmounts.Create;
  Notes := TLandrixInvoiceNotes.Create;
  AccountingSupplierParty := TLandrixInvoiceAccountingParty.Create;
  AccountingCustomerParty := TLandrixInvoiceAccountingParty.Create;
  DeliveryInformation := TLandrixInvoiceDeliveryInformation.Create;
  PayeeParty := TLandrixInvoiceParty.Create;
  TaxRepresentativeParty := TLandrixInvoiceParty.Create;
  InvoiceeParty := TLandrixInvoiceParty.Create;
  Clear;
end;

destructor TLandrixInvoice.Destroy;
begin
  PaymentTypes.Free;
  PaymentTypes := nil;
  InvoiceLines.Free;
  InvoiceLines := nil;
  Attachments.Free;
  Attachments := nil;
  PrepaidPayments.Free;
  PrepaidPayments := nil;
  AllowanceCharges.Free;
  AllowanceCharges := nil;
  PrecedingInvoiceReferences.Free;
  PrecedingInvoiceReferences := nil;
  TaxAmountSubtotals.Free;
  TaxAmountSubtotals := nil;
  Notes.Free;
  Notes := nil;
  AccountingSupplierParty.Free;
  AccountingSupplierParty := nil;
  AccountingCustomerParty.Free;
  AccountingCustomerParty := nil;
  DeliveryInformation.Free;
  DeliveryInformation := nil;
  PayeeParty.Free;
  PayeeParty := nil;
  TaxRepresentativeParty.Free;
  TaxRepresentativeParty := nil;
  InvoiceeParty.Free;
  InvoiceeParty := nil;
  inherited;
end;

procedure TLandrixInvoice.Clear;
begin
  ProfileID := 'urn:fdc:peppol.eu:2017:poacc:billing:01:1.0';
  TestIndicator.Clear;
  InvoiceNumber := '';
  DocumentName := '';
  InvoiceIssueDate := 0;
  InvoiceDueDate := 0;
  InvoicePeriodStartDate := 0;
  InvoicePeriodEndDate := 0;
  InvoiceTypeCode := itc_None;
  InvoiceTypeCodeOther := '';
  InvoiceCurrencyCode := '';
  TaxCurrencyCode := '';
  TaxPointDate.Clear;
  TaxPointDateCode := '';
  BuyerReference := '';
  Notes.Clear;
  SellerOrderReference := '';
  SellerOrderReferenceDate.Clear;
  PurchaseOrderReference := '';
  PurchaseOrderReferenceDate.Clear;
  ProjectReference := '';
  ReceiptDocumentReference := '';
  ContractDocumentReference := '';
  DeliveryReceiptNumber := '';
  DeliveryReceiptDate := 0;
  DeliveryReceiptNumberExtended := '';
  DeliveryReceiptDateExtended := 0;
  BuyerAccountingReference := '';

  AccountingSupplierParty.Clear;
  AccountingCustomerParty.Clear;
  DeliveryInformation.Clear;
  PayeeParty.Clear;
  TaxRepresentativeParty.Clear;
  InvoiceeParty.Clear;

  PaymentID := '';
  PaymentTypes.Clear;
  PaymentMandateID := '';

  PaymentTermsType := iptt_None;
  PaymentTermNetNote := '';
  PaymentTermCashDiscount1Days := 0;
  PaymentTermCashDiscount1Percent := 0;
  PaymentTermCashDiscount1Base := 0;
  PaymentTermCashDiscount1ActualAmount := 0;
  PaymentTermCashDiscount2Days := 0;
  PaymentTermCashDiscount2Percent := 0;
  PaymentTermCashDiscount2Base := 0;
  PaymentTermCashDiscount2ActualAmount := 0;
  PaymentTermCashDiscount3Days := 0;
  PaymentTermCashDiscount3Percent := 0;
  PaymentTermCashDiscount3Base := 0;
  PaymentTermCashDiscount3ActualAmount := 0;
  PaymentTermCashDiscount1Note := '';
  PaymentTermCashDiscount2Note := '';
  PaymentTermCashDiscount3Note := '';

  InvoiceLines.Clear;
  Attachments.Clear;
  PrepaidPayments.Clear;
  AllowanceCharges.Clear;
  PrecedingInvoiceReferences.Clear;

  TaxAmountTotal := 0;
  TaxAmountTotalInTaxCurrency.Clear;
  TaxAmountSubtotals.Clear;

  LineAmount := 0;
  TaxExclusiveAmount := 0;
  TaxInclusiveAmount := 0;
  AllowanceTotalAmount := 0;
  ChargeTotalAmount := 0;
  PrepaidAmount := 0;
  PayableRoundingAmount := 0;
  PayableAmount := 0;
end;

{ --- Assign ------------------------------------------------------------- }

procedure TLandrixInvoiceAttachment.Assign(ASource: TLandrixInvoiceAttachment);
begin
  if ASource = Self then
    Exit;
  ID := ASource.ID;
  DocumentDescription := ASource.DocumentDescription;
  Filename := ASource.Filename;
  TypeCode := ASource.TypeCode;
  TypeCodeOther := ASource.TypeCodeOther;
  AttachmentType := ASource.AttachmentType;
  AttachmentTypeOther := ASource.AttachmentTypeOther;
  Data.Clear;
  Data.WriteBuffer(ASource.Data.Memory^, Integer(ASource.Data.Size));
  Data.Position := 0;
  ExternalReference := ASource.ExternalReference;
  SchemeID := ASource.SchemeID;
end;

procedure TLandrixInvoicePrepaidPayment.Assign(ASource: TLandrixInvoicePrepaidPayment);
begin
  if ASource = Self then
    Exit;
  ID := ASource.ID;
  PaidAmount := ASource.PaidAmount;
  PaidAmountCurrencyID := ASource.PaidAmountCurrencyID;
  InstructionID := ASource.InstructionID;
end;

procedure TLandrixInvoiceAllowanceCharge.Assign(ASource: TLandrixInvoiceAllowanceCharge);
begin
  if ASource = Self then
    Exit;
  ChargeIndicator := ASource.ChargeIndicator;
  ReasonCodeAllowance := ASource.ReasonCodeAllowance;
  ReasonCodeAllowanceOther := ASource.ReasonCodeAllowanceOther;
  ReasonCodeCharge := ASource.ReasonCodeCharge;
  ReasonCodeChargeOther := ASource.ReasonCodeChargeOther;
  Reason := ASource.Reason;
  BaseAmount := ASource.BaseAmount;
  MultiplierFactorNumeric := ASource.MultiplierFactorNumeric;
  Amount := ASource.Amount;
  TaxPercent := ASource.TaxPercent;
  TaxCategory := ASource.TaxCategory;
  TaxCategoryOther := ASource.TaxCategoryOther;
end;

procedure TLandrixInvoiceLineItemAttribute.Assign(ASource: TLandrixInvoiceLineItemAttribute);
begin
  if ASource = Self then
    Exit;
  Name := ASource.Name;
  Value := ASource.Value;
end;

procedure TLandrixInvoiceLineItemClassification.Assign(ASource: TLandrixInvoiceLineItemClassification);
begin
  if ASource = Self then
    Exit;
  ClassCode := ASource.ClassCode;
  ListID := ASource.ListID;
  ListVersionID := ASource.ListVersionID;
  ClassificationName := ASource.ClassificationName;
end;

procedure TLandrixInvoiceLine.Assign(ASource: TLandrixInvoiceLine);
var
  I: TLandrixEInvoiceListIndex;
  Subs, Old: TLandrixInvoiceLines;
begin
  if ASource = Self then
    Exit;
  ID := ASource.ID;
  GlobalID_EAN_GTIN := ASource.GlobalID_EAN_GTIN;
  StandardItemIdentifier := ASource.StandardItemIdentifier;
  StandardItemIdentifierSchemeID := ASource.StandardItemIdentifierSchemeID;
  Note := ASource.Note;
  ObjectIdentifier := ASource.ObjectIdentifier;
  ObjectIdentifierSchemeID := ASource.ObjectIdentifierSchemeID;
  Name := ASource.Name;
  Description := ASource.Description;
  Quantity := ASource.Quantity;
  UnitCode := ASource.UnitCode;
  UnitCodeOther := ASource.UnitCodeOther;
  SellersItemIdentification := ASource.SellersItemIdentification;
  BuyersItemIdentification := ASource.BuyersItemIdentification;
  OrderNumber := ASource.OrderNumber;
  OrderDate := ASource.OrderDate;
  OrderLineReference := ASource.OrderLineReference;
  BuyerAccountingReference := ASource.BuyerAccountingReference;
  TaxPercent := ASource.TaxPercent;
  TaxCategory := ASource.TaxCategory;
  TaxCategoryOther := ASource.TaxCategoryOther;
  TaxExemptionReason := ASource.TaxExemptionReason;
  GrossPriceAmount := ASource.GrossPriceAmount;
  DiscountOnTheGrossPrice := ASource.DiscountOnTheGrossPrice;
  NetPriceAmount := ASource.NetPriceAmount;
  BaseQuantity := ASource.BaseQuantity;
  BaseQuantityUnitCode := ASource.BaseQuantityUnitCode;
  BaseQuantityUnitCodeOther := ASource.BaseQuantityUnitCodeOther;
  LineAmount := ASource.LineAmount;
  AllowanceCharges.Clear;
  for I := 0 to ASource.AllowanceCharges.Count - 1 do
    AllowanceCharges.AddAllowanceCharge.Assign(ASource.AllowanceCharges[I]);
  InvoiceLinePeriodStartDate := ASource.InvoiceLinePeriodStartDate;
  InvoiceLinePeriodEndDate := ASource.InvoiceLinePeriodEndDate;
  ItemClassifications.Clear;
  for I := 0 to ASource.ItemClassifications.Count - 1 do
    ItemClassifications.AddItemClassification.Assign(ASource.ItemClassifications[I]);
  OriginTradeCountry := ASource.OriginTradeCountry;
  ItemAttributes.Clear;
  for I := 0 to ASource.ItemAttributes.Count - 1 do
    ItemAttributes.AddItemAttribute.Assign(ASource.ItemAttributes[I]);
  DeliveryNoteNumber := ASource.DeliveryNoteNumber;
  DeliveryNoteLineID := ASource.DeliveryNoteLineID;
  DeliveryNoteDate := ASource.DeliveryNoteDate;
  ActualDeliveryDate := ASource.ActualDeliveryDate;
  LineStatusReasonCode := ASource.LineStatusReasonCode;
  LineStatusReasonCodeOther := ASource.LineStatusReasonCodeOther;
  { ASource may be one of the own sub-lines (promoting a sub-line): copy
    into a new list first, free the old one (and with it ASource) last.
    DE: ASource kann eine der eigenen Unterpositionen sein (Unterposition
    hochstufen): erst in eine neue Liste kopieren, die alte (und damit
    ASource) zuletzt freigeben. }
  Subs := TLandrixInvoiceLines.Create;
  for I := 0 to ASource.SubInvoiceLines.Count - 1 do
    Subs.AddInvoiceLine.Assign(ASource.SubInvoiceLines[I]);
  Old := SubInvoiceLines;
  SubInvoiceLines := Subs;
  Old.Free;
end;

procedure TLandrixInvoiceTaxAmount.Assign(ASource: TLandrixInvoiceTaxAmount);
begin
  if ASource = Self then
    Exit;
  TaxableAmount := ASource.TaxableAmount;
  TaxAmount := ASource.TaxAmount;
  TaxPercent := ASource.TaxPercent;
  TaxCategory := ASource.TaxCategory;
  TaxCategoryOther := ASource.TaxCategoryOther;
  TaxExemptionReason := ASource.TaxExemptionReason;
  TaxExemptionReasonCode := ASource.TaxExemptionReasonCode;
end;

procedure TLandrixInvoiceAddress.Assign(ASource: TLandrixInvoiceAddress);
begin
  if ASource = Self then
    Exit;
  StreetName := ASource.StreetName;
  AdditionalStreetName := ASource.AdditionalStreetName;
  City := ASource.City;
  PostalZone := ASource.PostalZone;
  CountrySubentity := ASource.CountrySubentity;
  AddressLine := ASource.AddressLine;
  CountryCode := ASource.CountryCode;
end;

procedure TLandrixInvoiceAccountingParty.Assign(ASource: TLandrixInvoiceAccountingParty);
begin
  if ASource = Self then
    Exit;
  Name := ASource.Name;
  RegistrationName := ASource.RegistrationName;
  CompanyID := ASource.CompanyID;
  CompanyIDSchemeID := ASource.CompanyIDSchemeID;
  Address.Assign(ASource.Address);
  IdentifierSellerBuyer := ASource.IdentifierSellerBuyer;
  GlobalIdentifierSellerBuyer := ASource.GlobalIdentifierSellerBuyer;
  GlobalIdentifierSellerBuyerSchemeID := ASource.GlobalIdentifierSellerBuyerSchemeID;
  BankAssignedCreditorIdentifier := ASource.BankAssignedCreditorIdentifier;
  VATCompanyID := ASource.VATCompanyID;
  VATCompanyNumber := ASource.VATCompanyNumber;
  ContactName := ASource.ContactName;
  ContactDepartment := ASource.ContactDepartment;
  ContactTelephone := ASource.ContactTelephone;
  ContactElectronicMail := ASource.ContactElectronicMail;
  AdditionalLegalInformationSeller := ASource.AdditionalLegalInformationSeller;
  ElectronicAddressSellerBuyer := ASource.ElectronicAddressSellerBuyer;
  ElectronicAddressSellerBuyerSchemeID := ASource.ElectronicAddressSellerBuyerSchemeID;
end;

procedure TLandrixInvoiceParty.Assign(ASource: TLandrixInvoiceParty);
begin
  if ASource = Self then
    Exit;
  Name := ASource.Name;
  Identifier := ASource.Identifier;
  IdentifierSchemeID := ASource.IdentifierSchemeID;
  CompanyID := ASource.CompanyID;
  CompanyIDSchemeID := ASource.CompanyIDSchemeID;
  VATCompanyID := ASource.VATCompanyID;
  Address.Assign(ASource.Address);
  ContactName := ASource.ContactName;
  ContactDepartment := ASource.ContactDepartment;
  ContactTelephone := ASource.ContactTelephone;
  ContactElectronicMail := ASource.ContactElectronicMail;
end;

procedure TLandrixInvoiceDeliveryInformation.Assign(ASource: TLandrixInvoiceDeliveryInformation);
begin
  if ASource = Self then
    Exit;
  Name := ASource.Name;
  LocationIdentifier := ASource.LocationIdentifier;
  LocationIdentifierSchemeID := ASource.LocationIdentifierSchemeID;
  Address.Assign(ASource.Address);
  ActualDeliveryDate := ASource.ActualDeliveryDate;
  ContactName := ASource.ContactName;
  ContactTelephone := ASource.ContactTelephone;
  ContactElectronicMail := ASource.ContactElectronicMail;
end;

procedure TLandrixInvoicePrecedingInvoiceReference.Assign(ASource: TLandrixInvoicePrecedingInvoiceReference);
begin
  if ASource = Self then
    Exit;
  ID := ASource.ID;
  IssueDate := ASource.IssueDate;
end;

procedure TLandrixInvoiceNote.Assign(ASource: TLandrixInvoiceNote);
begin
  if ASource = Self then
    Exit;
  Content := ASource.Content;
  SubjectCode := ASource.SubjectCode;
  SubjectCodeOther := ASource.SubjectCodeOther;
end;

procedure TLandrixInvoicePaymentType.Assign(ASource: TLandrixInvoicePaymentType);
begin
  if ASource = Self then
    Exit;
  PaymentMeansCode := ASource.PaymentMeansCode;
  PaymentMeansCodeOther := ASource.PaymentMeansCodeOther;
  PaymentMeansInformation := ASource.PaymentMeansInformation;
  FinancialAccount := ASource.FinancialAccount;
  FinancialAccountName := ASource.FinancialAccountName;
  FinancialInstitutionBranch := ASource.FinancialInstitutionBranch;
end;

procedure TLandrixInvoice.Assign(ASource: TLandrixInvoice);
var
  I: TLandrixEInvoiceListIndex;
begin
  if ASource = Self then
    Exit;
  ProfileID := ASource.ProfileID;
  TestIndicator := ASource.TestIndicator;
  InvoiceNumber := ASource.InvoiceNumber;
  DocumentName := ASource.DocumentName;
  InvoiceIssueDate := ASource.InvoiceIssueDate;
  InvoiceDueDate := ASource.InvoiceDueDate;
  InvoicePeriodStartDate := ASource.InvoicePeriodStartDate;
  InvoicePeriodEndDate := ASource.InvoicePeriodEndDate;
  InvoiceTypeCode := ASource.InvoiceTypeCode;
  InvoiceTypeCodeOther := ASource.InvoiceTypeCodeOther;
  InvoiceCurrencyCode := ASource.InvoiceCurrencyCode;
  TaxCurrencyCode := ASource.TaxCurrencyCode;
  TaxPointDate := ASource.TaxPointDate;
  TaxPointDateCode := ASource.TaxPointDateCode;
  BuyerReference := ASource.BuyerReference;
  Notes.Clear;
  for I := 0 to ASource.Notes.Count - 1 do
    Notes.AddNote.Assign(ASource.Notes[I]);
  SellerOrderReference := ASource.SellerOrderReference;
  SellerOrderReferenceDate := ASource.SellerOrderReferenceDate;
  PurchaseOrderReference := ASource.PurchaseOrderReference;
  PurchaseOrderReferenceDate := ASource.PurchaseOrderReferenceDate;
  ProjectReference := ASource.ProjectReference;
  ReceiptDocumentReference := ASource.ReceiptDocumentReference;
  ContractDocumentReference := ASource.ContractDocumentReference;
  DeliveryReceiptNumber := ASource.DeliveryReceiptNumber;
  DeliveryReceiptDate := ASource.DeliveryReceiptDate;
  DeliveryReceiptNumberExtended := ASource.DeliveryReceiptNumberExtended;
  DeliveryReceiptDateExtended := ASource.DeliveryReceiptDateExtended;
  BuyerAccountingReference := ASource.BuyerAccountingReference;
  AccountingSupplierParty.Assign(ASource.AccountingSupplierParty);
  AccountingCustomerParty.Assign(ASource.AccountingCustomerParty);
  DeliveryInformation.Assign(ASource.DeliveryInformation);
  PayeeParty.Assign(ASource.PayeeParty);
  TaxRepresentativeParty.Assign(ASource.TaxRepresentativeParty);
  InvoiceeParty.Assign(ASource.InvoiceeParty);
  PaymentID := ASource.PaymentID;
  PaymentTypes.Clear;
  for I := 0 to ASource.PaymentTypes.Count - 1 do
    PaymentTypes.AddPaymentType.Assign(ASource.PaymentTypes[I]);
  PaymentMandateID := ASource.PaymentMandateID;
  PaymentTermsType := ASource.PaymentTermsType;
  PaymentTermNetNote := ASource.PaymentTermNetNote;
  PaymentTermCashDiscount1Days := ASource.PaymentTermCashDiscount1Days;
  PaymentTermCashDiscount1Percent := ASource.PaymentTermCashDiscount1Percent;
  PaymentTermCashDiscount1Base := ASource.PaymentTermCashDiscount1Base;
  PaymentTermCashDiscount1ActualAmount := ASource.PaymentTermCashDiscount1ActualAmount;
  PaymentTermCashDiscount2Days := ASource.PaymentTermCashDiscount2Days;
  PaymentTermCashDiscount2Percent := ASource.PaymentTermCashDiscount2Percent;
  PaymentTermCashDiscount2Base := ASource.PaymentTermCashDiscount2Base;
  PaymentTermCashDiscount2ActualAmount := ASource.PaymentTermCashDiscount2ActualAmount;
  PaymentTermCashDiscount3Days := ASource.PaymentTermCashDiscount3Days;
  PaymentTermCashDiscount3Percent := ASource.PaymentTermCashDiscount3Percent;
  PaymentTermCashDiscount3Base := ASource.PaymentTermCashDiscount3Base;
  PaymentTermCashDiscount3ActualAmount := ASource.PaymentTermCashDiscount3ActualAmount;
  PaymentTermCashDiscount1Note := ASource.PaymentTermCashDiscount1Note;
  PaymentTermCashDiscount2Note := ASource.PaymentTermCashDiscount2Note;
  PaymentTermCashDiscount3Note := ASource.PaymentTermCashDiscount3Note;
  InvoiceLines.Clear;
  for I := 0 to ASource.InvoiceLines.Count - 1 do
    InvoiceLines.AddInvoiceLine.Assign(ASource.InvoiceLines[I]);
  Attachments.Clear;
  for I := 0 to ASource.Attachments.Count - 1 do
    Attachments.AddAttachment(ASource.Attachments[I].AttachmentType).Assign(ASource.Attachments[I]);
  PrepaidPayments.Clear;
  for I := 0 to ASource.PrepaidPayments.Count - 1 do
    PrepaidPayments.AddPrepaidPayment.Assign(ASource.PrepaidPayments[I]);
  AllowanceCharges.Clear;
  for I := 0 to ASource.AllowanceCharges.Count - 1 do
    AllowanceCharges.AddAllowanceCharge.Assign(ASource.AllowanceCharges[I]);
  PrecedingInvoiceReferences.Clear;
  for I := 0 to ASource.PrecedingInvoiceReferences.Count - 1 do
    PrecedingInvoiceReferences.AddPrecedingInvoiceReference.Assign(ASource.PrecedingInvoiceReferences[I]);
  TaxAmountTotal := ASource.TaxAmountTotal;
  TaxAmountTotalInTaxCurrency := ASource.TaxAmountTotalInTaxCurrency;
  TaxAmountSubtotals.Clear;
  for I := 0 to ASource.TaxAmountSubtotals.Count - 1 do
    TaxAmountSubtotals.AddTaxAmount.Assign(ASource.TaxAmountSubtotals[I]);
  LineAmount := ASource.LineAmount;
  TaxExclusiveAmount := ASource.TaxExclusiveAmount;
  TaxInclusiveAmount := ASource.TaxInclusiveAmount;
  AllowanceTotalAmount := ASource.AllowanceTotalAmount;
  ChargeTotalAmount := ASource.ChargeTotalAmount;
  PrepaidAmount := ASource.PrepaidAmount;
  PayableRoundingAmount := ASource.PayableRoundingAmount;
  PayableAmount := ASource.PayableAmount;
end;

end.
