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
  (BR-DE-...), Peppol (PEPPOL-EN16931-...) and the rules of Factur-X EXTENDED (BR-FXEXT-...). Each violation is an entry of kind
  `edk_RuleViolation` with its rule identifier in `RuleID`.
- Everything the mapping reports: content the target or its Factur-X profile cannot hold
  (`edk_NotAllowed`), required content that is missing (`edk_MissingElement`), values that
  cannot be converted.

The rule check predicts what the KoSIT validator would report for the written document. It
does not replace the validator: schema and Schematron checks of the official configuration
remain the reference. Not checked yet, among others: the code list rules (BR-CL-...) and most
Peppol rules. The format rules BR-DE-17, BR-DE-19, BR-DE-20 (IBAN check sum), BR-DE-27, BR-DE-28
and BR-51 are checked; all of them are warnings except BR-51 in CII.

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
