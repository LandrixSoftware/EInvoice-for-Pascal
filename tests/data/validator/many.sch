<?xml version="1.0" encoding="UTF-8"?>
<schema xmlns="http://purl.oclc.org/dsdl/schematron" queryBinding="xslt2">
  <ns prefix="t" uri="urn:landrix:test:validator"/>
  <pattern>
    <rule context="/t:doc">
      <report id="M-01" flag="information" test="true()">first</report>
      <report id="M-02" flag="information" test="true()">second</report>
    </rule>
  </pattern>
</schema>
