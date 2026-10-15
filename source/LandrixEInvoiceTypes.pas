{
  EInvoice-for-Pascal

  Copyright (C) 2026 Landrix Software GmbH & Co. KG

  This file is dual-licensed under:
  - GNU GPL version 3 or later; or
  - the Landrix Software Commercial License.

  See LICENSE and COMMERCIAL-LICENSE.md.

  SPDX-License-Identifier: GPL-3.0-or-later OR LicenseRef-Landrix-Commercial
}

{ Basic types shared by all units: the library version, the string and
  character type of the invoice model and the conversion between that string
  type and UTF-8.

  String type
  -----------
  TLandrixEInvoiceString  Text of the invoice model.
                          Delphi 6-2007: WideString (UTF-16, lossless).
                          Delphi 2009+:  string = UnicodeString (lossless).
                          FPC:           string (AnsiString with code page);
                                         lossless when the code page is
                                         UTF-8, otherwise converted to the
                                         system code page by the RTL. On
                                         Unix the application must use the
                                         cwstring unit, else the RTL has no
                                         wide string manager and characters
                                         outside Latin-1 become '?'.
                          On every Delphi it is the same type as
                          TLandrixXmlWide.
  TLandrixEInvoiceChar    One code unit of TLandrixEInvoiceString (WideChar
                          on Delphi, Char on FPC). Not necessarily a complete
                          character: a UTF-16 surrogate or one UTF-8 byte.

  On Delphi 6-2007 assigning a TLandrixEInvoiceString to a plain string (or
  passing it to SysUtils routines that take string) converts it to the system
  code page and loses characters that code page cannot represent. }

unit LandrixEInvoiceTypes;

{$I LandrixEInvoice.inc}

interface

uses
  LandrixXmlBase;

const
  LandrixEInvoiceVersion = '0.1.0';

type
{$IFDEF FPC}
  TLandrixEInvoiceString = string;
  TLandrixEInvoiceChar = Char;
{$ELSE}
  {$IFDEF LANDRIXEINVOICE_UNICODE}
  TLandrixEInvoiceString = string;
  TLandrixEInvoiceChar = Char;
  {$ELSE}
  TLandrixEInvoiceString = WideString;
  TLandrixEInvoiceChar = WideChar;
  {$ENDIF}
{$ENDIF}

{ Converts invoice text to UTF-8. Raises ELandrixXmlError (xecInvalidUnicode)
  for an unpaired UTF-16 surrogate. }
function LandrixEInvoiceStringToUtf8(const S: TLandrixEInvoiceString): TLandrixXmlUtf8;

{ Converts UTF-8 to invoice text. Raises ELandrixXmlError (xecInvalidUnicode)
  for malformed UTF-8. }
function LandrixEInvoiceUtf8ToString(const S: TLandrixXmlUtf8): TLandrixEInvoiceString;

implementation

{ On Delphi TLandrixEInvoiceString is TLandrixXmlWide, so the wide
  conversion is lossless and never passes through the system code page. On
  FPC it is string, which LandrixXmlBase converts according to the string's
  code page. }

function LandrixEInvoiceStringToUtf8(const S: TLandrixEInvoiceString): TLandrixXmlUtf8;
begin
{$IFDEF FPC}
  Result := LandrixXmlStringToUtf8(S);
{$ELSE}
  Result := LandrixXmlWideToUtf8(S);
{$ENDIF}
end;

function LandrixEInvoiceUtf8ToString(const S: TLandrixXmlUtf8): TLandrixEInvoiceString;
begin
{$IFDEF FPC}
  Result := LandrixXmlUtf8ToString(S);
{$ELSE}
  Result := LandrixXmlUtf8ToWide(S);
{$ENDIF}
end;

end.
