{
  EInvoice-for-Pascal

  Copyright (C) 2026 Landrix Software GmbH & Co. KG

  This file is dual-licensed under:
  - GNU GPL version 3 or later; or
  - the Landrix Software Commercial License.

  See LICENSE and COMMERCIAL-LICENSE.md.

  SPDX-License-Identifier: GPL-3.0-or-later OR LicenseRef-Landrix-Commercial
}

{ Tests for LandrixEInvoiceIdentifiers: the identifier formats and check
  digits of the Peppol schematron and the KoSIT IBAN check. The valid and
  invalid values are computed from the XPath functions, not from this
  library. }

unit LandrixEInvoiceTestIdentifiers;

{$I LandrixEInvoice.inc}

interface

procedure Register;

implementation

uses
  LandrixEInvoiceIdentifiers,
  LandrixEInvoiceTestFramework;

procedure TestNormalizeSpace;
begin
  CheckEqualsInvoiceStr('a b c', LandrixEInvoiceNormalizeSpace('  a' + #9 + 'b' + #13#10 + '  c '), 'blanks');
  CheckEqualsInvoiceStr('', LandrixEInvoiceNormalizeSpace(' ' + #10 + ' '), 'only blanks');
  Check(LandrixEInvoiceIsDigits('0123', 4), 'four digits');
  Check(not LandrixEInvoiceIsDigits('0123', 5), 'not five digits');
  Check(LandrixEInvoiceIsDigits('7', 0), 'any number of digits');
  Check(not LandrixEInvoiceIsDigits('', 0), 'empty');
  Check(not LandrixEInvoiceIsDigits('12a', 0), 'letter');
  Check(LandrixEInvoiceIsInteger('+12'), 'sign');
  Check(LandrixEInvoiceIsInteger('-0'), 'minus zero');
  Check(not LandrixEInvoiceIsInteger('+'), 'sign alone');
  Check(not LandrixEInvoiceIsInteger('1.5'), 'decimal');
end;

procedure TestCheckDigits;
begin
  Check(LandrixEInvoiceGS1CheckDigitValid('4000001000005'), 'GLN');
  Check(LandrixEInvoiceGS1CheckDigitValid('7300010000001'), 'GLN 2');
  Check(not LandrixEInvoiceGS1CheckDigitValid('4000001000006'), 'GLN check digit');
  Check(not LandrixEInvoiceGS1CheckDigitValid('40000010000x5'), 'GLN letter');
  Check(LandrixEInvoiceMod11Valid('987654325'), 'mod 11');
  Check(LandrixEInvoiceMod11Valid('974760673'), 'mod 11, 2');
  Check(not LandrixEInvoiceMod11Valid('123456789'), 'mod 11 check digit');
  Check(not LandrixEInvoiceMod11Valid('000000000'), 'mod 11 zero');
  Check(LandrixEInvoiceBelgianEnterpriseValid('0739484052'), 'Belgian number');
  Check(not LandrixEInvoiceBelgianEnterpriseValid('0739484053'), 'Belgian check number');
  Check(not LandrixEInvoiceBelgianEnterpriseValid('739484052'), 'Belgian nine digits');
  Check(LandrixEInvoiceCodiceIPAValid('UFXY12'), 'IPA');
  Check(not LandrixEInvoiceCodiceIPAValid('UFXY1'), 'IPA five');
  Check(not LandrixEInvoiceCodiceIPAValid('UFXY1-'), 'IPA hyphen');
  Check(LandrixEInvoiceCodiceFiscaleValid('RSSMRA85T10A562S'), 'Codice Fiscale');
  Check(LandrixEInvoiceCodiceFiscaleValid('12345678901'), 'Codice Fiscale numeric');
  Check(not LandrixEInvoiceCodiceFiscaleValid('RSSMRA8XT10A562S'), 'Codice Fiscale letter in the year');
  Check(not LandrixEInvoiceCodiceFiscaleValid('RSSMRA85T10A56'), 'Codice Fiscale too short');
  Check(LandrixEInvoicePartitaIVAValid('IT00743110157'), 'Partita IVA');
  Check(LandrixEInvoicePartitaIVAValid('it00743110157'), 'Partita IVA lower case prefix');
  Check(not LandrixEInvoicePartitaIVAValid('IT12345678901'), 'Partita IVA check digit');
  Check(not LandrixEInvoicePartitaIVAValid('IT0074311015'), 'Partita IVA ten digits');
  Check(LandrixEInvoicePartitaIVAValid('DE123'), 'not Italian');
  Check(LandrixEInvoiceSwedishOrgNumberValid('5560360793'), 'Swedish number');
  Check(LandrixEInvoiceSwedishOrgNumberValid('5566778899'), 'Swedish number 2');
  Check(not LandrixEInvoiceSwedishOrgNumberValid('1234567890'), 'Swedish check digit');
  Check(not LandrixEInvoiceSwedishOrgNumberValid('556036079'), 'Swedish nine digits');
  Check(LandrixEInvoiceABNValid('51824753556'), 'ABN');
  Check(not LandrixEInvoiceABNValid('12345678901'), 'ABN check sum');
  Check(LandrixEInvoiceGreekTINValid('094014201'), 'Greek TIN');
  Check(LandrixEInvoiceGreekTINValid('123456783'), 'Greek TIN 2');
  Check(not LandrixEInvoiceGreekTINValid('123456789'), 'Greek TIN check digit');
  Check(not LandrixEInvoiceGreekTINValid('12345678'), 'Greek TIN eight digits');
  Check(LandrixEInvoiceIBANValid('DE02120300000000202051'), 'IBAN');
  Check(LandrixEInvoiceIBANValid('GB82WEST12345698765432'), 'IBAN with letters');
  Check(not LandrixEInvoiceIBANValid('DE02120300000000202052'), 'IBAN check sum');
  Check(not LandrixEInvoiceIBANValid('de02120300000000202051'), 'IBAN lower case country');
end;

procedure TestContactFormats;
begin
  Check(LandrixEInvoiceTelephoneValid('(0) 1-2'), 'three digits');
  Check(not LandrixEInvoiceTelephoneValid('+49'), 'two digits');
  Check(LandrixEInvoiceEmailValid(' a@b.c.de '), 'email');
  Check(not LandrixEInvoiceEmailValid('a b@c.de'), 'email with blank');
  Check(not LandrixEInvoiceEmailValid('a@b'), 'email without dot');
  Check(not LandrixEInvoiceEmailValid('a@b..de'), 'email with empty part');
end;

procedure TestCashDiscountText;
begin
  Check(LandrixEInvoiceCashDiscountTextValid(''), 'empty');
  Check(LandrixEInvoiceCashDiscountTextValid('Net 30 days'), 'no cash discount line');
  Check(LandrixEInvoiceCashDiscountTextValid('#SKONTO#TAGE=7#PROZENT=2.00#' + #10 +
    ' #SKONTO#TAGE=14#PROZENT=1.50#BASISBETRAG=-12.30# ' + #13#10 + 'Net 30'), 'two lines and text');
  Check(not LandrixEInvoiceCashDiscountTextValid('#SKONTO#TAGE=-1#PROZENT=2.00#' + #10), 'negative days');
  Check(not LandrixEInvoiceCashDiscountTextValid('#SKONTO#TAGE=7#PROZENT=-2.00#' + #10), 'negative percent');
  Check(not LandrixEInvoiceCashDiscountTextValid('#SKONTO#TAGE=7#PROZENT=2.0#'), 'one decimal');
  Check(not LandrixEInvoiceCashDiscountTextValid('#SKONTO#TAGE=7#PROZENT=2.00'), 'no closing #');
  Check(not LandrixEInvoiceCashDiscountTextValid('#skonto#TAGE=7#PROZENT=2.00#'), 'lower case');
  Check(not LandrixEInvoiceCashDiscountTextValid('Net' + #10 + '# note'), 'other line with #');
  Check(LandrixEInvoiceCashDiscountTextValid('Net # note'), '# inside a line');
end;

procedure Register;
begin
  RegisterTest('Identifiers.NormalizeSpace', TestNormalizeSpace);
  RegisterTest('Identifiers.CheckDigits', TestCheckDigits);
  RegisterTest('Identifiers.ContactFormats', TestContactFormats);
  RegisterTest('Identifiers.CashDiscountText', TestCashDiscountText);
end;

end.
