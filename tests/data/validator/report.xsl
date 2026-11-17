<?xml version="1.0" encoding="UTF-8"?>
<!-- Test report stylesheet for LandrixEInvoiceKositReport (not KoSIT material):
     it reads the report input as KoSIT's default-report.xsl does and writes a
     small rep:report with an embedded HTML page. Accept: a scenario, no
     processing error and no failed assert with flag fatal; the page lists
     the scenario, the failed asserts and the root element of input-document. -->
<xsl:stylesheet version="2.0" xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
  xmlns:in="http://www.xoev.de/de/validator/framework/1/createreportinput"
  xmlns:s="http://www.xoev.de/de/validator/framework/1/scenarios"
  xmlns:rep="http://www.xoev.de/de/validator/varl/1"
  xmlns:svrl="http://purl.oclc.org/dsdl/svrl"
  xmlns:html="http://www.w3.org/1999/xhtml"
  exclude-result-prefixes="in s svrl">
  <xsl:output method="xml" indent="yes"/>
  <xsl:param name="input-document" as="document-node()?" required="yes"/>
  <xsl:template match="/in:createReportInput">
    <xsl:variable name="accept" select="exists(s:scenario) and empty(in:processingError)
      and empty(.//svrl:failed-assert[@flag = 'fatal'])"/>
    <rep:report valid="{$accept}">
      <rep:engine><rep:name><xsl:value-of select="in:engine/in:name"/></rep:name></rep:engine>
      <xsl:for-each select=".//svrl:failed-assert">
        <rep:message id="{@id}"><xsl:value-of select="svrl:text"/></rep:message>
      </xsl:for-each>
      <rep:assessment>
        <xsl:element name="{if ($accept) then 'rep:accept' else 'rep:reject'}">
          <rep:explanation>
            <html:html>
              <html:head><html:title>Test report</html:title></html:head>
              <html:body>
                <html:p class="scenario"><xsl:value-of select="(s:scenario/s:name, 'none')[1]"/></html:p>
                <html:p class="root"><xsl:value-of select="local-name($input-document/*)"/></html:p>
                <xsl:for-each select=".//svrl:failed-assert">
                  <html:p class="assert"><xsl:value-of select="@id"/></html:p>
                </xsl:for-each>
              </html:body>
            </html:html>
          </rep:explanation>
        </xsl:element>
      </rep:assessment>
    </rep:report>
  </xsl:template>
</xsl:stylesheet>
