# Invoice

## Invoice details

- **Invoice number:** R-2026-0815
- **Invoice date:** 2026-11-12
- **Invoice type:** Commercial invoice (380)
- **Due date:** 2026-12-12
- **Invoicing period from:** 2026-10-01
- **Invoicing period to:** 2026-10-31
- **Invoice currency:** Euro (EUR)
- **Buyer reference:** 04011000-12345-34
- **Business process:** urn:fdc:peppol.eu:2017:poacc:billing:01:1.0

## Parties

### Seller

- **Name:** Muster \& Söhne GmbH
- **Street:** Hauptstraße 1
- **Post code:** 10115
- **City:** Berlin
- **Country:** Germany (DE)
- **VAT identifier:** DE123456789
- **Electronic address:** rechnung@example.com
- **Electronic address scheme:** Electronic mail (SMPT) (EM)
- **Contact:** Erika Muster
- **Telephone:** +49 30 123456

### Buyer

- **Name:** Beispiel AG
- **Street:** Ringweg 7
- **Post code:** 80331
- **City:** München
- **Country:** Germany (DE)
- **Electronic address:** einkauf@example.org
- **Electronic address scheme:** Electronic mail (SMPT) (EM)

### Payee

- **Name:** Factoring Bank

### Delivery

- **City:** Hamburg
- **Country:** Germany (DE)
- **Delivery date:** 2026-10-20

## References

- **Purchase order number:** B-4711
- **Contract number:** V-2025-17

## Invoice lines

* **Line:** 1
  - **Item:** Beratung
  - **Quantity:** 16
  - **Unit:** hour (HUR)
  - **Net price:** 95.00
  - **VAT category:** Standard rate (S)
  - **VAT rate:** 19%
  - **Net amount:** 1,368.00
  - **Item description:**
    ```
    Workshop vor Ort,
    zwei Tage
    ```
  - **Seller's item number:** SRV-01
  - **Allowances and charges**
    * **Allowance or charge:** Allowance
      - **Reason code:** Discount (95)
      - **Reason:** Rabatt
      - **Base amount:** 1,520.00
      - **Percentage:** 10%
      - **Amount:** 152.00
  - **Item attributes**
    * **Attribute:** Ort
      - **Value:** Berlin
* **Line:** 2
  - **Item:** Material
  - **Quantity:** 1
  - **Unit:** one (C62)
  - **Net price:** 200.00
  - **VAT category:** Standard rate (S)
  - **VAT rate:** 7%
  - **Net amount:** 200.00
  * **Line:** 2.1
    - **Item:** Kabel
    - **Quantity:** 12.5
    - **Unit:** piece (H87)
    - **Net price:** 8.00
    - **VAT category:** Standard rate (S)
    - **VAT rate:** 7%
    - **Net amount:** 100.00
  * **Line:** 2.2
    - **Item:** Stecker
    - **Quantity:** 50
    - **Unit:** piece (H87)
    - **Net price:** 2.00
    - **VAT category:** Standard rate (S)
    - **VAT rate:** 7%
    - **Net amount:** 100.00

## Allowances and charges

* **Allowance or charge:** Charge
  - **Reason code:** Freight service (FC)
  - **Reason:** Versand
  - **Amount:** 10.00
  - **VAT category:** Standard rate (S)
  - **VAT rate:** 19%

## VAT breakdown

* **VAT category:** Standard rate (S)
  - **VAT rate:** 19%
  - **Taxable amount:** 1,378.00
  - **VAT amount:** 261.82
* **VAT category:** Standard rate (S)
  - **VAT rate:** 7%
  - **Taxable amount:** 200.00
  - **VAT amount:** 14.00

## Totals

- **Sum of line net amounts:** 1,568.00 EUR
- **Sum of charges:** 10.00 EUR
- **Total without VAT:** 1,578.00 EUR
- **Total VAT:** 275.82 EUR
- **Total with VAT:** 1,853.82 EUR
- **Paid amount:** 53.82 EUR
- **Amount due:** 1,800.00 EUR

## Payment

- **Payment reference:** R-2026-0815
- **Creditor identifier:** DE98ZZZ09999999999

**Payment instructions**

* **Payment means:** SEPA credit transfer (58)
  - **Account:** DE02120300000000202051
  - **Account holder:** Muster \& Söhne GmbH
  - **BIC:** BYLADEM1001

- **Payment terms:** one cash discount
- **Cash discount 1: days:** 10
- **Cash discount 1: percent:** 2%
- **Cash discount 1: base amount:** 1,853.82 EUR

## Notes

* **Subject:** General information (AAI)
  - **Note:** Vielen Dank für Ihren Auftrag.

## Supporting documents

* **Document reference:** Stundenzettel
  - **Document type:** 916
  - **Description:** Stundennachweis Oktober
  - **File name:** stunden.pdf
  - **MIME type:** application/pdf
  - **Embedded file:** 13 bytes

---

Written by EInvoice-for-Pascal @VERSION@
