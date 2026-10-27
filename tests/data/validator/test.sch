<?xml version="1.0" encoding="UTF-8"?>
<schema xmlns="http://purl.oclc.org/dsdl/schematron" queryBinding="xslt2">
  <ns prefix="t" uri="urn:landrix:test:validator"/>
  <pattern>
    <rule context="/t:doc">
      <assert id="T-01" flag="fatal" test="t:v &gt; 0">v is positive</assert>
      <assert id="T-02" flag="fatal" test="t:v &lt; 100">v is below 100</assert>
      <report id="T-03" flag="information" test="t:v = 7">v is seven</report>
      <assert id="T-04" flag="warning" test="t:v != 13">v is not 13</assert>
      <assert flag="warning" test="t:v != 42">v is not 42</assert>
    </rule>
  </pattern>
</schema>
