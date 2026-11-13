# KoSIT configurations and rule files

What the native KoSIT check of EInvoice-for-Pascal needs: the validator configurations of the KoSIT
(XRechnung, Peppol BIS Billing) and of ZUGFeRD / Factur-X, and the rule files of LandrixXML and OpenPEPPOL.
No Java. How to use them: [docs/validation.md](../../docs/validation.md).

```powershell
./addons/kosit/install-kosit.ps1                          # all: xrechnung, bis, zugferd
./addons/kosit/install-kosit.ps1 -Modules xrechnung       # only XRechnung
./addons/kosit/install-kosit.ps1 -Target C:\MyApp\kosit   # into another folder
```

Every file is pinned by URL and SHA-256 in [kosit.json](kosit.json) and verified after the download
(downloads are kept in `download/` next to the script). The installed files are git-ignored; ship the target
folder with an application that runs the check. A module that is installed is skipped; `-Force` installs it
again, also after files were deleted by hand. Windows PowerShell 5.1 cannot unpack the ZUGFeRD archive below a
long `-Target` path (260 characters with its deepest file); PowerShell 7 can.

| Module | Installs |
|---|---|
| `xrechnung` | `validator-configuration-xrechnung/` (KoSIT, XRechnung 3.0.2, 2026-08-31); `rules/en16931-ubl.xml`, `en16931-cii.xml`, `xrechnung-ubl.xml`, `xrechnung-cii.xml`, `NOTICE.md` |
| `bis` | `validator-configuration-bis/` (KoSIT, Peppol BIS Billing 3.0.21); `rules/en16931-ubl.xml`, `PEPPOL-EN16931-UBL.sch` (OpenPEPPOL, May 2026 release 3.0.21), `NOTICE.md` |
| `zugferd` | `validator-configuration-zugferd/` (ZUGFeRD 2.5.2 / Factur-X 1.09.2, 2026-10-15, with its Schematron sources) |

The rule files `*.xml` are the EN 16931 and XRechnung Schematron compiled by LandrixXML (the configurations
ship the rules as XSLT, which the native check does not run); the script copies them from the submodule
`external/landrix-xml` or downloads them from the LandrixXML release. `rules/NOTICE.md` names their sources
and licences. The Java tools of the repository's own test scripts are in [addons/java-tools](../java-tools/).

New versions: change the URL and SHA-256 in `kosit.json`; a new set of rule files comes with a new LandrixXML
release.
