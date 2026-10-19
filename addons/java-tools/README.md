# Java tools

Java-based tools around EInvoice-for-Pascal. Only the scripts and the manifest are in the
repository; the tools themselves are downloaded into this folder (git-ignored).

```powershell
./addons/java-tools/install-tools.ps1                  # tools + Java runtime of this machine
./addons/java-tools/install-tools.ps1 -Platform all    # Java runtimes of all platforms
./addons/java-tools/install-tools.ps1 -NoJre           # use an installed Java runtime
```

Requires PowerShell 7 (Windows, Linux, macOS). On Windows the Linux and macOS JREs are skipped
(their archives contain symbolic links the Windows `tar` cannot create); install them on their own
platform, into the same folder if it is shared.

| Folder | Content |
|---|---|
| `validator/` | KoSIT validator (standalone JAR) |
| `validator-configuration-xrechnung/` | KoSIT configuration for XRechnung 3.0.2 |
| `validator-configuration-bis/` | KoSIT configuration for Peppol BIS Billing 3.0 |
| `validator-configuration-zugferd/` | configuration for ZUGFeRD 2.5.2 / Factur-X 1.09.2 |
| `jre/<os>-<arch>/` | Eclipse Temurin 21 JRE: `windows-x64`, `windows-aarch64`, `linux-x64`, `linux-aarch64`, `macos-aarch64` |
| `download/` | downloaded files (cache) |

`tools.json` pins every download by URL and SHA-256; the script refuses a file with another
checksum. To update a tool, change `url`, `file` and `sha256` of its entry together and run the
script again (an entry is reinstalled when its checksum changes, or with `-Force`).

## Validation

`tools/validate.ps1` checks invoice files with these tools; `tools/build.ps1 -Validate` runs it
on the scenario output of the test run. The configuration is chosen by file name
(`-ubl-30x`, `-cii-30x`: XRechnung; `-ubl-peppol`: Peppol BIS; `-ciiEN16931-25`,
`-ciiextended-25`: ZUGFeRD). A file passes when the assessment in its report accepts it
(`rep:accept`; for XRechnung and ZUGFeRD the scenarios' `acceptMatch`, for Peppol BIS the report
stylesheet, which rejects only error-level messages); warnings are listed.

Two pitfalls of the validator 1.6.3 the script works around:

- The validator checks whether a document is piped through standard input. On Windows it fails
  when standard input is the null device (non-interactive shells), so the script passes an empty
  file; on Linux and macOS any redirected input counts as a piped document, so Java inherits the
  standard input of PowerShell there.
- With several configurations in one call, no scenario matches the ZUGFeRD EN16931 files; the
  script calls the validator once per configuration.
