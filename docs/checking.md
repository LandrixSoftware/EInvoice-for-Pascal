# Checking

[Deutsch](de/checking.md)

```pascal
Errors := TLandrixEInvoice.Check(Invoice, Target, [], Diagnostics);
```

`Check` runs the checks of `SaveTo*` without writing and returns the number of errors
`SaveTo*` would refuse on. Overloads exist for the three syntax models.

## What is checked

- The business rules of the target: EN 16931 (BR-...), the calculation rules (BR-CO-10 to
  BR-CO-17), the VAT category rules (BR-S-..., BR-Z-..., BR-E-..., BR-AE-..., BR-IC-...,
  BR-G-..., BR-O-..., BR-AF-..., BR-AG-..., BR-B-01, BR-B-02, BR-CO-03, BR-CO-04, BR-CO-09,
  BR-CO-18), the other BR-CO rules (reasons, seller identifier, payment terms), XRechnung
  (BR-DE-...), Peppol (PEPPOL-EN16931-...), the code list rules of XRechnung and Peppol (BR-CL-...)
  and the rules of Factur-X EXTENDED (BR-FXEXT-...). Each violation is an entry of kind
  `edk_RuleViolation` with its rule identifier in `RuleID`.
- Everything the mapping reports: content the target or its Factur-X profile cannot hold
  (`edk_NotAllowed`), required content that is missing (`edk_MissingElement`), values that
  cannot be converted.

The rule check predicts what the KoSIT validator would report for the written document. It
does not replace the validator: schema and Schematron checks of the official configuration
remain the reference. Not checked yet, among others: most Peppol rules and the code checks of
the Factur-X Schematron (FX-SCH-A-...). The format rules BR-DE-17, BR-DE-19, BR-DE-20 (IBAN
check sum), BR-DE-27, BR-DE-28 and BR-51 are checked; all of them are warnings except BR-51 in
CII.

The code list rules BR-CL-01 to BR-CL-26 use the lists of the validators (XRechnung 3.0.2,
Peppol BIS 3.0.21). They are slightly older than the code lists of the library: the currency
STD is accepted and STN is not, CII accepts the country AN and not SS, the VAT category B is
accepted, the EAS codes 0219 and 0220 are accepted, and in UBL the 18 newest note subject codes
are not. Codes are compared case sensitively after removing blanks around them, the VAT
exemption reason code (BR-CL-22) after upper-casing it and the MIME code (BR-CL-24) exactly as
written. XRechnung reports
BR-CL-21 and BR-CL-23 as warnings, and when the invoice is written with the XRechnung extension
it does not report BR-CL-10, 11, 21, 24, 25 and 26. UBL writes the invoice type code 381 as
`ubl:CreditNote` and every other code as `ubl:Invoice`, so a code of the credit note list such as
261 violates BR-CL-01 in UBL.

The rules judge the invoice as it would be written. A VAT rate the invoice does not set is 0
and is written as 0; lines, allowances and charges of category O are written without rate.

## Severity

Every entry has a `Severity`: `eds_Error`, `eds_Warning` or `eds_Info`. Errors are what
`SaveTo*` refuses on. With `eio_Strict`, content the target does not allow and discouraged
content count as errors too.

```pascal
for I := 0 to Integer(D.Count) - 1 do
  if D[I].Severity = eds_Error then
    WriteLn(string(D[I].RuleID), ' ', string(D[I].Message));
```

`D.ToText` returns all entries, one per line.

## Checking a read invoice

`eio_CheckOnRead` checks the business rules of the detected specification while reading; the
violations go to `Doc.Diagnostics`. Or call `Check` with `Doc.Info.Spec.Target`, as
[examples/CheckInvoice](../examples/CheckInvoice/CheckInvoice.dpr) does.

## Rule identifiers

Rule identifiers are stable. Rules of this library that the standards do not have start with
`LX-` (e.g. LX-CC-04).
