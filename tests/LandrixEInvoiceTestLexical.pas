{
  EInvoice-for-Pascal

  Copyright (C) 2026 Landrix Software GmbH & Co. KG

  This file is dual-licensed under:
  - GNU GPL version 3 or later; or
  - the Landrix Software Commercial License.

  See LICENSE and COMMERCIAL-LICENSE.md.

  SPDX-License-Identifier: GPL-3.0-or-later OR LicenseRef-Landrix-Commercial
}

{ Tests for LandrixEInvoiceLexical: formatting rules per business term,
  rounding, edge cases and strict parsing. }

unit LandrixEInvoiceTestLexical;

{$I LandrixEInvoice.inc}

interface

procedure Register;

implementation

uses
  SysUtils,
  LandrixEInvoiceTypes,
  LandrixEInvoiceLexical,
  LandrixEInvoiceTestFramework;

{ Currency from its scaled value (1/10000) and Double as a quotient: no
  float literals (Delphi 13 Win64 W1066). }
function Cur(AScaled: Int64): Currency;
begin
  PInt64(@Result)^ := AScaled;
end;

function Quot(A, B: Integer): Double;
begin
  Result := A / B;
end;

procedure CheckText(const AExpected: string; const AActual: TLandrixEInvoiceString; const AMsg: string);
begin
  CheckEqualsInvoiceStr(TLandrixEInvoiceString(AExpected), AActual, AMsg);
end;

procedure TestAmount;
begin
  CheckText('100.00', LandrixEInvoiceAmountToLexical(100), '100');
  CheckText('0.00', LandrixEInvoiceAmountToLexical(0), 'zero');
  CheckText('-12.50', LandrixEInvoiceAmountToLexical(Cur(-125000)), 'negative');
  CheckText('0.13', LandrixEInvoiceAmountToLexical(Cur(1250)), 'half rounds away from zero');
  CheckText('-0.13', LandrixEInvoiceAmountToLexical(Cur(-1250)), 'negative half rounds away from zero');
  CheckText('0.00', LandrixEInvoiceAmountToLexical(Cur(-40)), 'no negative zero');
  CheckText('922337203685477.58', LandrixEInvoiceAmountToLexical(Cur(9223372036854775800)), 'large');
end;

procedure TestPrice;
begin
  CheckText('4.10', LandrixEInvoicePriceToLexical(Cur(41000)), '2 decimals if exact');
  CheckText('4.1235', LandrixEInvoicePriceToLexical(Cur(41235)), '4 decimals otherwise');
  CheckText('4.1250', LandrixEInvoicePriceToLexical(Cur(41250)), '3 decimals written as 4');
  CheckText('-0.01', LandrixEInvoicePriceToLexical(Cur(-100)), 'negative exact');
  CheckText('100.00', LandrixEInvoicePriceToLexical(100), 'integer');
  { KoSIT testsuite 03.04a and 03.05a: prices with 5 and 9 decimals, as integer
    quotients (Delphi 13 Win64 warns W1066 for such float literals) }
  CheckText('0.01146', LandrixEInvoicePriceToLexical(1146 / 100000), '5 decimals kept');
  CheckText('0.061232374', LandrixEInvoicePriceToLexical(61232374 / 1000000000), '9 decimals kept');
end;

procedure TestQuantity;
begin
  CheckText('1.0000', LandrixEInvoiceQuantityToLexical(1), '1');
  CheckText('2.5000', LandrixEInvoiceQuantityToLexical(2.5), '2.5');
  CheckText('0.3333', LandrixEInvoiceQuantityToLexical(Quot(1, 3)), 'one third');
  CheckText('0.0000', LandrixEInvoiceQuantityToLexical(Quot(-1, 100000)), 'no negative zero');
  CheckText('1.00', LandrixEInvoiceBaseQuantityToLexical(1), 'base quantity 1');
  CheckText('0.001', LandrixEInvoiceBaseQuantityToLexical(Quot(1, 1000)), 'base quantity 0.001');
  CheckText('1.50', LandrixEInvoiceBaseQuantityToLexical(1.5), 'base quantity 1.5');
  CheckText('0.000001', LandrixEInvoiceBaseQuantityToLexical(Quot(1, 1000000)), 'six decimals');
end;

procedure TestPercent;
begin
  CheckText('19.00', LandrixEInvoicePercentToLexical(19), '19');
  CheckText('7.50', LandrixEInvoicePercentToLexical(7.5), '7.5');
  CheckText('2.68', LandrixEInvoicePercentToLexical(Quot(2675, 1000)), '2.675 as written');
  CheckText('1.500', LandrixEInvoiceDecimalToLexical(1.5, 3), 'decimal with 3 places');
end;

procedure TestDates;
var
  D: TDateTime;
begin
  D := EncodeDate(2026, 10, 18) + EncodeTime(13, 45, 0, 0);
  CheckText('2026-10-18', LandrixEInvoiceDateToUBL(D), 'UBL date, time ignored');
  CheckText('20261018', LandrixEInvoiceDateToCII(D), 'CII date, time ignored');
  CheckText('2026-01-05', LandrixEInvoiceDateToUBL(EncodeDate(2026, 1, 5)), 'leading zeros');
end;

procedure TestParse;
var
  C: Currency;
  F: Double;
  D: TDateTime;
  Rounded: Boolean;
begin
  Check(LandrixEInvoiceTryLexicalToCurrency('19.00', C, Rounded) and (C = 19) and not Rounded, '19.00');
  Check(LandrixEInvoiceTryLexicalToCurrency(' -0.5 ', C, Rounded) and (C = -0.5), 'white space and sign');
  Check(LandrixEInvoiceTryLexicalToCurrency('1.23456', C, Rounded) and Rounded and (C = Cur(12346)),
    'more than 4 decimals rounded');
  Check(not LandrixEInvoiceTryLexicalToCurrency('19,00', C, Rounded) and (C = 0), 'comma rejected');
  Check(not LandrixEInvoiceTryLexicalToCurrency('1e3', C, Rounded), 'exponent rejected');
  Check(not LandrixEInvoiceTryLexicalToCurrency('', C, Rounded), 'empty rejected');
  Check(not LandrixEInvoiceTryLexicalToCurrency('99999999999999999', C, Rounded), 'out of range');
  Check(LandrixEInvoiceTryLexicalToDouble('0.001', F) and (F = Quot(1, 1000)), 'double');
  Check(not LandrixEInvoiceTryLexicalToDouble('abc', F) and (F = 0), 'double rejected');
  Check(LandrixEInvoiceTryUBLToDate('2026-10-18', D) and (D = EncodeDate(2026, 10, 18)), 'UBL date');
  Check(LandrixEInvoiceTryUBLToDate('2026-10-18+02:00', D) and (D = EncodeDate(2026, 10, 18)),
    'UBL date with time zone');
  Check(not LandrixEInvoiceTryUBLToDate('2026-02-30', D) and (D = 0), 'calendar check');
  Check(not LandrixEInvoiceTryUBLToDate('18.10.2026', D), 'local form rejected');
  Check(LandrixEInvoiceTryCIIToDate('20261018', '102', D) and (D = EncodeDate(2026, 10, 18)), 'CII date');
  Check(LandrixEInvoiceTryCIIToDate('20261018', '', D), 'CII date without format');
  Check(not LandrixEInvoiceTryCIIToDate('202610', '610', D), 'format 610 not mapped');
  Check(not LandrixEInvoiceTryCIIToDate('20261318', '102', D), 'CII calendar check');
end;

{ Blank: empty or XML white space only (normalize-space); a no-break space
  is no XML white space. }
procedure TestIsBlank;
begin
  Check(LandrixEInvoiceIsBlank(''), 'empty');
  Check(LandrixEInvoiceIsBlank(' '), 'blank');
  Check(LandrixEInvoiceIsBlank(TLandrixEInvoiceString(' ' + #9 + #10 + #13)), 'XML white space');
  Check(not LandrixEInvoiceIsBlank(' a '), 'text with blanks');
  Check(not LandrixEInvoiceIsBlank(TLandrixEInvoiceString(WideChar($A0))), 'no-break space is text');
end;

procedure Register;
begin
  RegisterTest('Lexical.Amount', TestAmount);
  RegisterTest('Lexical.Price', TestPrice);
  RegisterTest('Lexical.Quantity', TestQuantity);
  RegisterTest('Lexical.Percent', TestPercent);
  RegisterTest('Lexical.Dates', TestDates);
  RegisterTest('Lexical.Parse', TestParse);
  RegisterTest('Lexical.IsBlank', TestIsBlank);
end;

end.
