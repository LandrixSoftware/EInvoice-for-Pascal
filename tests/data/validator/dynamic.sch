<?xml version="1.0" encoding="UTF-8"?>
<schema xmlns="http://purl.oclc.org/dsdl/schematron" queryBinding="xslt2">
  <ns prefix="t" uri="urn:landrix:test:validator"/>
  <pattern>
    <rule context="/t:doc">
      <report id="D-01" flag="information" test="true()">first</report>
      <assert id="D-02" flag="fatal" test="(1 idiv 0) = 1">raises</assert>
    </rule>
  </pattern>
</schema>
