<!--
  Copyright (C) 2011 Orbeon, Inc.

  This program is free software; you can redistribute it and/or modify it under the terms of the
  GNU Lesser General Public License as published by the Free Software Foundation; either version
  2.1 of the License, or (at your option) any later version.

  This program is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY;
  without even the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
  See the GNU Lesser General Public License for more details.

  The full text of the license is available at http://www.gnu.org/copyleft/lesser.html
  -->
<p:config xmlns:p="http://www.orbeon.com/oxf/pipeline"
    xmlns:oxf="http://www.orbeon.com/oxf/processors"
    xmlns:xs="http://www.w3.org/2001/XMLSchema"
    xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
    xmlns:xxforms="http://orbeon.org/oxf/xml/xforms"
    xmlns:xforms="http://www.w3.org/2002/xforms"
    xmlns:xhtml="http://www.w3.org/1999/xhtml"
    xmlns:saxon="http://saxon.sf.net/"
    xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance">

    <p:param name="document" type="input"/>
    <p:param name="response" type="output"/>

    <p:processor name="oxf:pipeline">
        <p:input name="config" href="wrap-xforms-init.xpl"/>
        <p:input name="document" href="#document"/>
        <p:output name="response" id="xhtml"/>
    </p:processor>

    <!-- Filter stuff to make tests reproducible -->
    <p:processor name="oxf:xslt">
        <p:input name="data" href="#xhtml"/>
        <p:input name="config">
            <xsl:stylesheet version="2.0">
                <xsl:import href="oxf:/oxf/xslt/utils/copy.xsl"/>
                <xsl:template match="/xhtml:html/xhtml:head"/>
            </xsl:stylesheet>
        </p:input>
        <p:output name="data" ref="response"/>
    </p:processor>

</p:config>
