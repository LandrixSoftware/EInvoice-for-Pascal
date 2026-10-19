{
  EInvoice-for-Pascal

  Copyright (C) 2026 Landrix Software GmbH & Co. KG

  This file is dual-licensed under:
  - GNU GPL version 3 or later; or
  - the Landrix Software Commercial License.

  See LICENSE and COMMERCIAL-LICENSE.md.

  SPDX-License-Identifier: GPL-3.0-or-later OR LicenseRef-Landrix-Commercial
}

{ Compatibility with XRechnung-for-Delphi, third part (unit
  intf.XRechnungPdfExtract): the old names of the PDF extraction on top of
  LandrixEInvoicePdf. Existing code compiles after replacing
  intf.XRechnungPdfExtract by LandrixEInvoiceCompatXRechnungPdf.

  Differences to the old unit:
  - TXRechnungPdfAttachment.Data is a TMemoryStream owned by the attachment
    instead of TBytes; Size stays.
  - The limits XRechnungPdfMax... are true constants, not typed constants.
  - TXRechnungPdfExtractInfo has the additional fields SkippedAttachments
    and Warning: embedded files left out because a filter failed or a limit
    was reached.
  - Messages are English.
  - New in the Delphi 6 to 2007 version: the old unit needed Delphi 2009.

  DE: Kompatibilitaet mit XRechnung-for-Delphi, dritter Teil (Unit
  intf.XRechnungPdfExtract): die alten Namen der PDF-Extraktion auf Basis von
  LandrixEInvoicePdf. Bestehender Code kompiliert, wenn
  intf.XRechnungPdfExtract durch LandrixEInvoiceCompatXRechnungPdf ersetzt
  wird.

  Unterschiede zur alten Unit:
  - TXRechnungPdfAttachment.Data ist ein TMemoryStream, der dem Anhang
    gehoert, statt TBytes; Size bleibt.
  - Die Grenzen XRechnungPdfMax... sind echte Konstanten, keine typisierten.
  - TXRechnungPdfExtractInfo hat zusaetzlich SkippedAttachments und Warning:
    eingebettete Dateien, die wegen eines gescheiterten Filters oder einer
    erreichten Grenze ausgelassen wurden.
  - Meldungen sind englisch.
  - Neu fuer Delphi 6 bis 2007: die alte Unit brauchte Delphi 2009. }

unit LandrixEInvoiceCompatXRechnungPdf;

{$I LandrixEInvoice.inc}

interface

uses
  SysUtils,
  Classes,
  LandrixEInvoicePdf,
  LandrixEInvoiceCompatXRechnungAdapter;

type
  { The byte type of the old out parameters: TBytes where the compiler has
    it. DE: Der Bytetyp der alten out-Parameter: TBytes, wo der Compiler ihn
    kennt. }
  {$IF Defined(FPC) or Defined(LANDRIXEINVOICE_UNICODE)}
  TXRechnungPdfBytes = TBytes; // check-forbidden: allow
  {$ELSE}
  TXRechnungPdfBytes = array of Byte;
  {$IFEND}

  TXRechnungPdfAttachmentKind = TLandrixEInvoicePdfAttachmentKind;
  TXRechnungPdfAttachment = TLandrixEInvoicePdfAttachment;
  TXRechnungPdfAttachmentList = TLandrixEInvoicePdfAttachmentList;
  TXRechnungPdfExtractInfo = TLandrixEInvoicePdfExtractInfo;

const
  pakUnspecified = epa_Unspecified;
  pakInvoice = epa_Invoice;
  pakOtherXml = epa_OtherXml;
  pakOther = epa_Other;

  XRechnungPdfMaxStreamSize = LandrixEInvoicePdfMaxStreamSize;
  XRechnungPdfMaxDepth = LandrixEInvoicePdfMaxDepth;
  XRechnungPdfMaxTotalSize = LandrixEInvoicePdfMaxTotalSize;
  XRechnungPdfMaxAttachments = LandrixEInvoicePdfMaxAttachments;

type
  { The old entry points; see TLandrixEInvoicePdfExtractor.
    DE: Die alten Einstiege; siehe TLandrixEInvoicePdfExtractor. }
  TXRechnungPdfExtractor = class(TObject)
  public
    class function ExtractInvoiceFromFile(const _PdfFilename: TXRechnungString; out _Xml: TXRechnungPdfBytes;
      out _AttachmentName: TXRechnungString; out _Info: TXRechnungPdfExtractInfo): Boolean;
    class function ExtractInvoiceFromStream(_Stream: TStream; out _Xml: TXRechnungPdfBytes;
      out _AttachmentName: TXRechnungString; out _Info: TXRechnungPdfExtractInfo): Boolean;
    class function ExtractAllFromFile(const _PdfFilename: TXRechnungString; _List: TXRechnungPdfAttachmentList;
      out _Info: TXRechnungPdfExtractInfo): Boolean;
    class function ExtractAllFromStream(_Stream: TStream; _List: TXRechnungPdfAttachmentList;
      out _Info: TXRechnungPdfExtractInfo): Boolean;
    class function FindInvoiceIndex(_List: TXRechnungPdfAttachmentList): Integer;
    class function IsPdfFile(const _PdfFilename: TXRechnungString): Boolean;
    class function IsPdfStream(_Stream: TStream): Boolean;
  end;

implementation

uses
  LandrixEInvoiceTypes;

function NativeFileName(const S: TXRechnungString): string;
begin
  Result := string(S);
end;

function StreamToBytes(AStream: TMemoryStream): TXRechnungPdfBytes;
begin
  Result := nil;
  SetLength(Result, Integer(AStream.Size));
  if AStream.Size > 0 then
    Move(AStream.Memory^, Result[0], Integer(AStream.Size));
end;

class function TXRechnungPdfExtractor.ExtractInvoiceFromStream(_Stream: TStream; out _Xml: TXRechnungPdfBytes;
  out _AttachmentName: TXRechnungString; out _Info: TXRechnungPdfExtractInfo): Boolean;
var
  Xml: TMemoryStream;
  Name: TLandrixEInvoiceString;
begin
  _Xml := nil;
  Xml := TMemoryStream.Create;
  try
    Result := TLandrixEInvoicePdfExtractor.ExtractInvoiceFromStream(_Stream, Xml, Name, _Info);
    _AttachmentName := TXRechnungString(Name);
    if Result then
      _Xml := StreamToBytes(Xml);
  finally
    Xml.Free;
  end;
end;

class function TXRechnungPdfExtractor.ExtractInvoiceFromFile(const _PdfFilename: TXRechnungString;
  out _Xml: TXRechnungPdfBytes; out _AttachmentName: TXRechnungString; out _Info: TXRechnungPdfExtractInfo): Boolean;
var
  Xml: TMemoryStream;
  Name: TLandrixEInvoiceString;
begin
  _Xml := nil;
  Xml := TMemoryStream.Create;
  try
    Result := TLandrixEInvoicePdfExtractor.ExtractInvoiceFromFile(NativeFileName(_PdfFilename), Xml, Name, _Info);
    _AttachmentName := TXRechnungString(Name);
    if Result then
      _Xml := StreamToBytes(Xml);
  finally
    Xml.Free;
  end;
end;

class function TXRechnungPdfExtractor.ExtractAllFromFile(const _PdfFilename: TXRechnungString;
  _List: TXRechnungPdfAttachmentList; out _Info: TXRechnungPdfExtractInfo): Boolean;
begin
  Result := TLandrixEInvoicePdfExtractor.ExtractAllFromFile(NativeFileName(_PdfFilename), _List, _Info);
end;

class function TXRechnungPdfExtractor.ExtractAllFromStream(_Stream: TStream; _List: TXRechnungPdfAttachmentList;
  out _Info: TXRechnungPdfExtractInfo): Boolean;
begin
  Result := TLandrixEInvoicePdfExtractor.ExtractAllFromStream(_Stream, _List, _Info);
end;

class function TXRechnungPdfExtractor.FindInvoiceIndex(_List: TXRechnungPdfAttachmentList): Integer;
begin
  Result := Integer(TLandrixEInvoicePdfExtractor.FindInvoiceIndex(_List));
end;

class function TXRechnungPdfExtractor.IsPdfFile(const _PdfFilename: TXRechnungString): Boolean;
begin
  Result := TLandrixEInvoicePdfExtractor.IsPdfFile(NativeFileName(_PdfFilename));
end;

class function TXRechnungPdfExtractor.IsPdfStream(_Stream: TStream): Boolean;
begin
  Result := TLandrixEInvoicePdfExtractor.IsPdfStream(_Stream);
end;

end.
