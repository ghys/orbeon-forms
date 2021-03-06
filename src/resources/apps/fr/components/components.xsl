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
<xsl:stylesheet version="2.0"
        xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
        xmlns:xs="http://www.w3.org/2001/XMLSchema"
        xmlns:xforms="http://www.w3.org/2002/xforms"
        xmlns:xxforms="http://orbeon.org/oxf/xml/xforms"
        xmlns:exforms="http://www.exforms.org/exf/1-0"
        xmlns:fr="http://orbeon.org/oxf/xml/form-runner"
        xmlns:xhtml="http://www.w3.org/1999/xhtml"
        xmlns:xi="http://www.w3.org/2001/XInclude"
        xmlns:xxi="http://orbeon.org/oxf/xml/xinclude"
        xmlns:ev="http://www.w3.org/2001/xml-events"
        xmlns:xbl="http://www.w3.org/ns/xbl"
        xmlns:xpl="java:org.orbeon.oxf.pipeline.api.FunctionLibrary">

    <xsl:import href="oxf:/oxf/xslt/utils/copy-modes.xsl"/>

    <!-- Import components -->
    <xsl:import href="view.xsl"/>
    <xsl:import href="buttons.xsl"/>
    <xsl:import href="section.xsl"/><!-- pass global section properties to fr:section -->
    <xsl:import href="repeat.xsl"/> <!-- convert legacy fr:repeat to fr:grid -->

    <!-- Global variables -->
    <xsl:variable name="app" select="doc('input:instance')/*/app" as="xs:string"/>
    <xsl:variable name="form" select="doc('input:instance')/*/form" as="xs:string"/>
    <xsl:variable name="mode" select="doc('input:instance')/*/mode" as="xs:string?"/>

    <xsl:variable name="is-detail" select="$mode != 'summary'" as="xs:boolean"/>
    <xsl:variable name="is-form-builder" select="$app = 'orbeon' and $form = 'builder'" as="xs:boolean"/>
    <xsl:variable name="is-noscript-support" select="not(/xhtml:html/xhtml:head/xforms:model[1]/@xxforms:noscript-support = 'false')" as="xs:boolean"/>
    <xsl:variable name="is-noscript" select="doc('input:request')/request/parameters/parameter[name = 'fr-noscript']/value = 'true'
                                                and $is-noscript-support" as="xs:boolean"/>
    <xsl:variable name="input-data" select="/*" as="element(xhtml:html)"/>
    <xsl:variable name="has-pdf-template" select="normalize-space(/xhtml:html/xhtml:head//xforms:instance[@id = 'fr-form-attachments']/*/pdf) != ''"/>

    <!-- Properties -->
    <xsl:variable name="has-version" select="xpl:property(string-join(('oxf.fr.version', $app, $form), '.'))" as="xs:boolean?"/>
    <xsl:variable name="has-noscript-link" select="xpl:property(string-join(('oxf.fr.noscript-link', $app, $form), '.'))" as="xs:boolean?"/>
    <xsl:variable name="is-noscript-table" select="not(not(xpl:property(string-join(('oxf.fr.detail.noscript.table', $app, $form), '.'))) = false())" as="xs:boolean"/>
    <xsl:variable name="is-noscript-section-collapse" select="not(xpl:property(string-join(('oxf.fr.detail.noscript.section.collapse', $app, $form), '.')) = false())" as="xs:boolean"/>
    <xsl:variable name="min-toc" select="(xpl:property(string-join(('oxf.fr.detail.toc', $app, $form), '.')), -1)[1]" as="xs:integer"/>
    <xsl:variable name="has-toc" select="$min-toc ge 0" as="xs:boolean"/>
    <xsl:variable name="error-summary" select="xpl:property(string-join(('oxf.fr.detail.error-summary', $app, $form), '.'))" as="xs:string?"/>
    <xsl:variable name="is-ajax-section-collapse" select="not(xpl:property(string-join(('oxf.fr.detail.ajax.section.collapse', $app, $form), '.')) = false())" as="xs:boolean"/>
    <xsl:variable name="default-logo-uri" select="xpl:property(string-join(('oxf.fr.default-logo.uri', $app, $form), '.'))" as="xs:string?"/>
    <xsl:variable name="hide-logo" select="xpl:property(string-join(('oxf.fr.detail.hide-logo', $app, $form), '.'))" as="xs:boolean?"/>
    <xsl:variable name="hide-header" select="xpl:property(string-join(('oxf.fr.detail.hide-header', $app, $form), '.'))" as="xs:boolean?"/>
    <xsl:variable name="hide-footer" select="xpl:property(string-join(('oxf.fr.detail.hide-footer', $app, $form), '.'))" as="xs:boolean?"/>
    <xsl:variable name="hide-top" select="xpl:property(string-join(('oxf.fr.detail.hide-top', $app, $form), '.'))" as="xs:boolean?"/>
    <xsl:variable name="hide-buttons-bar" select="xpl:property(string-join(('oxf.fr.detail.hide-buttons-bar', $app, $form), '.'))" as="xs:boolean?"/>
    <xsl:variable name="css-uri" select="tokenize(normalize-space(xpl:property(string-join(('oxf.fr.css.uri', $app, $form), '.'))), '\s+')" as="xs:string*"/>
    <xsl:variable name="buttons-property" select="if ($mode = 'view') then 'oxf.fr.detail.buttons.view' else 'oxf.fr.detail.buttons'"/>
    <xsl:variable name="buttons" select="tokenize(xpl:property(string-join(($buttons-property, $app, $form), '.')), '\s+')" as="xs:string*"/>
    <xsl:variable name="has-alfresco" select="xpl:property(string-join(('oxf.fr.detail.send.alfresco', $app, $form), '.'))" as="xs:boolean?"/>
    <xsl:variable name="is-show-explanation" select="xpl:property(string-join(('oxf.fr.detail.view.show-explanation', $app, $form), '.')) = true()" as="xs:boolean"/>
    <xsl:variable name="is-inline-hints" select="not(xpl:property(string-join(('oxf.fr.detail.hints.inline', $app, $form), '.')) = false())" as="xs:boolean"/>
    <xsl:variable name="is-animate-sections" select="not($is-noscript) and not(xpl:property(string-join(('oxf.fr.detail.ajax.section.animate', $app, $form), '.')) = false())" as="xs:boolean"/>
    <xsl:variable name="captcha" as="xs:string" select="xpl:property(string-join(('oxf.fr.detail.captcha', $app, $form), '.'))"/>
    <xsl:variable name="has-captcha" as="xs:boolean" select="$captcha = ('reCAPTCHA', 'SimpleCaptcha')"/>

    <xsl:variable name="is-section-collapse" select="(not($is-noscript) and $is-ajax-section-collapse) or $is-noscript-section-collapse" as="xs:boolean"/>

    <xsl:variable name="error-summary-top" select="normalize-space($error-summary) = ('top', 'both')" as="xs:boolean"/>
    <xsl:variable name="error-summary-bottom" select="normalize-space($error-summary) = ('', 'bottom', 'both')" as="xs:boolean"/>

    <xsl:variable name="is-rendered" select="doc('input:request')/request/request-path = '/xforms-renderer'" as="xs:boolean"/>
    <xsl:variable name="url-base-for-requests" select="if ($is-rendered) then substring-before(doc('input:request')/request/request-uri, '/xforms-renderer') else ''" as="xs:string"/>

    <xsl:template match="/xhtml:html">
        <!-- Handle document language -->
        <xhtml:html lang="{{xxforms:instance('fr-language-instance')}}"
                    xml:lang="{{xxforms:instance('fr-language-instance')}}">
            <xsl:apply-templates select="@*"/>

            <!-- Scope variable with Form Runner resources -->
            <xxforms:variable name="fr-resources" model="fr-resources-model" select="$fr-fr-resources" as="element(resource)?"/>
            <!-- Scope form resources -->
            <xxforms:variable name="form-resources" model="fr-resources-model" select="$fr-form-resources" as="element(resource)?"/>

            <!-- Title from the current form's metadata -->
            <xforms:var
                name="title-from-metadata"
                value="xxforms:instance('fr-form-metadata')/title[@xml:lang = xxforms:instance('fr-language-instance')], xxforms:instance('fr-form-metadata')/title"/>

            <!-- Title from the current page's xforms:output under HTML title -->
             <xsl:choose>
                <xsl:when test="xhtml:head/xhtml:title/xforms:output">
                    <xforms:var
                        name="title-from-output"
                        model="fr-form-model"
                        value="string()">
                        <xsl:apply-templates select="(xhtml:head/xhtml:title/xforms:output)[1]/(@bind | @model | @context | @ref | @value)"/>
                    </xforms:var>
                </xsl:when>
                <xsl:otherwise>
                    <xforms:var name="title-from-output"/>
                </xsl:otherwise>
            </xsl:choose>

            <!-- Form title based on metadata or HTML title -->
            <xforms:var name="title" value="($title-from-metadata, $title-from-output, '{replace(xhtml:head/xhtml:title, '''', '''''')}')[normalize-space()][1]"/>

            <xsl:apply-templates select="node()"/>
        </xhtml:html>
    </xsl:template>

    <xsl:template match="/xhtml:html/xhtml:body">

        <xsl:copy>
            <xsl:attribute name="class" select="string-join((if ($is-inline-hints) then 'xforms-disable-hint-as-tooltip' else (), 'xforms-disable-alert-as-tooltip', @class), ' ')"/>
            <xsl:apply-templates select="@* except @class"/>
            <xforms:group model="fr-form-model" appearance="xxforms:internal">
                <xsl:choose>
                    <xsl:when test=".//fr:view">
                        <!-- Explicit fr:view is processed by template down the line -->
                        <xsl:apply-templates select="node()"/>
                    </xsl:when>
                    <xsl:otherwise>
                        <!-- No explicit fr:view so consider the whole of xhtml:body as fr:view/fr:body -->
                        <xsl:call-template name="fr-view"/>
                    </xsl:otherwise>
                </xsl:choose>
                <!-- Dialogs -->
                <xsl:call-template name="fr-dialogs"/>
            </xforms:group>
        </xsl:copy>
    </xsl:template>

    <!-- Insert stylesheets -->
    <xsl:template match="xhtml:head">
        <xsl:copy>
            <xsl:apply-templates select="@*"/>

            <!-- Form Runner CSS stylesheets -->
            <xsl:for-each select="$css-uri">
                <xhtml:link rel="stylesheet" href="{.}" type="text/css" media="all"/>
            </xsl:for-each>

            <!-- Handle existing stylesheets -->
            <xsl:for-each select="xhtml:link | xhtml:style">
                <xsl:element name="xhtml:{local-name()}" namespace="{namespace-uri()}">
                    <xsl:apply-templates select="@*|node()"/>
                </xsl:element>
            </xsl:for-each>

            <!-- Process the rest -->
            <xsl:apply-templates select="node() except (xhtml:link | xhtml:style)"/>

            <!-- For IE debugging -->
            <!--<xhtml:script language="javascript" type="text/javascript" src="/ops/firebug/firebug.js"/>-->
            <!--<xhtml:script language="javascript" type="text/javascript" src="http://getfirebug.com/releases/lite/1.2/firebug-lite-compressed.js"/>-->

            <!-- Script to enable scrolling within iframes with Firefox >= 4, due to this bug:
                 https://bugzilla.mozilla.org/show_bug.cgi?id=638598 -->
            <!-- TODO XXX: form-runner.js -->
            <xsl:if test="$has-toc and not($is-noscript)">
                <xhtml:script type="text/javascript">
                    <![CDATA[
                    if (YAHOO.env.ua.gecko >= 2) { // Firefox 4 and higher
                        YAHOO.util.Event.onDOMReady(function() {

                            // Only initialize if there is a parent window with same origin
                            var parentWithSameOrigin = false;
                            try {
                                if (window.parent != window && window.parent.scrollTo)
                                    parentWithSameOrigin = true;
                            } catch (e) {}

                            if (parentWithSameOrigin) {
                                // Find toc
                                var toc = document.getElementsByClassName("fr-toc")[0];
                                if (toc) {

                                    // Listener for clicks on toc links
                                    var onClick = function(event) {
                                        var eventObserver = this; // "the Event Utility automatically adjusts the execution scope so that this refers to the DOM element to which the event was attached"
                                        var linkTarget = document.getElementById(eventObserver.getAttribute("href").substring(1));
                                        if (linkTarget)
                                            window.parent.scrollTo(0, YAHOO.util.Dom.getY(linkTarget) + YAHOO.util.Dom.getY(window.frameElement));
                                    };

                                    // Find all toc links starting with a non-empty fragment, and add the listener to them
                                    var as = toc.getElementsByTagName("a");
                                    for (var i = 0; i < as.length; i++) {
                                        var a = as[i];
                                        var href = a.getAttribute("href");
                                        if (href && href[0] == "#" && href[1])
                                            YAHOO.util.Event.addListener(a, "click", onClick);
                                    }
                                }
                            }
                        });
                    }
                    ]]>
                </xhtml:script>
            </xsl:if>
        </xsl:copy>
    </xsl:template>

    <!-- Set XHTML title -->
    <xsl:template match="xhtml:head/xhtml:title">
        <xsl:copy>
            <xsl:apply-templates select="@*"/>

            <!-- Display localized errors count and form title -->
            <xforms:output model="fr-error-summary-model"
                           value="for $c in visible-errors-count return
                                    if ($c castable as xs:integer and xs:integer($c) > 0)
                                    then concat($c, ' ', $fr-resources/summary/titles/(if (xs:integer($c) = 1) then error-count else errors-count), ' - ', $title)
                                    else $title"/>
        </xsl:copy>
    </xsl:template>

    <!-- Add Form Runner models and scripts -->
    <xsl:template match="/xhtml:html/xhtml:head/xforms:model[1]">

        <!-- Model receiving input parameters -->
        <xforms:model id="fr-parameters-model"
                      xxforms:external-events="{@xxforms:external-events}{if ($mode = ('new', 'view', 'edit')) then ' fr-open-pdf' else ''}"
                      xxforms:readonly-appearance="{if ($mode = ('view', 'email') or ($mode = 'pdf' and not($has-pdf-template))) then 'static' else 'dynamic'}"
                      xxforms:encrypt-item-values="{not($mode = 'pdf' and $has-pdf-template)}"
                      xxforms:order="{if ($is-noscript) then 'label control alert hint help' else 'help label control alert hint'}"
                      xxforms:offline="false"
                      xxforms:noscript="{$is-noscript}"
                      xxforms:noscript-support="{$is-noscript-support}"
                      xxforms:xforms11-switch="false"
                      xxforms:xpath-analysis="true">

            <!-- Don't enable client events filtering for FB -->
            <xsl:if test="$is-form-builder">
                <xsl:attribute name="xxforms:client.events.filter"/>
            </xsl:if>
            <!-- Override if specified -->
            <xsl:copy-of select="@xxforms:xpath-analysis"/>

            <!-- Parameters passed to this page -->
            <!-- NOTE: the <document> element may be modified, so we don't set this as read-only -->
            <xforms:instance id="fr-parameters-instance" src="input:instance"/>

        </xforms:model>

        <!-- This model handles help -->
        <!--<xforms:model id="fr-help-model">-->
            <!--<xforms:instance id="fr-help-instance">-->
                <!--<help xmlns="">-->
                    <!--<label/>-->
                    <!--<help/>-->
                <!--</help>-->
            <!--</xforms:instance>-->

            <!-- Take action upon xforms-help on #fr-form-group -->
            <!--<xforms:action ev:observer="fr-form-group" ev:event="xforms-help" ev:defaultAction="cancel">-->
                <!--<xforms:setvalue ref="instance('fr-help-instance')/label" value="event('xxforms:label')"/>-->
                <!--<xforms:setvalue ref="instance('fr-help-instance')/help" value="event('xxforms:help')"/>-->
            <!--</xforms:action>-->

        <!--</xforms:model>-->

        <xxforms:variable name="url-base-for-requests" select="'{$url-base-for-requests}'"/>

        <!-- This model handles Form Builder roles and permissions -->
        <!-- NOTE: We could remove this if not($is-form-builder), except for the use of the $fr-roles variable -->
        <xi:include href="oxf:/apps/fr/includes/roles-model.xml" xxi:omit-xml-base="true"/>
        <!-- This model handles i18n resources -->
        <xi:include href="oxf:/apps/fr/i18n/resources-model.xml" xxi:omit-xml-base="true"/>
        <!-- This model handles global actions on form sections -->
        <xforms:model id="fr-sections-model">

            <xsl:variable name="section-ids" select="$input-data//fr:section/@id" as="xs:string*"/>
            <xsl:variable name="section-ids-sequence" select="concat('(', string-join(for $s in $section-ids return concat('''', $s, ''''), ','), ')')" as="xs:string*"/>

            <!-- Collapse or expand all sections -->
            <xforms:dispatch ev:event="fr-collapse-all" iterate="{$section-ids-sequence}" name="fr-collapse" targetid="{{.}}"/>
            <xforms:dispatch ev:event="fr-expand-all"   iterate="{$section-ids-sequence}" name="fr-expand"   targetid="{{.}}"/>
        </xforms:model>
        <!-- This model handles global error summary information -->
        <xforms:model id="fr-error-summary-model">
            <xforms:instance id="fr-error-summary-instance">
                <error-summary>
                    <xsl:choose>
                        <!-- For form builder we disable the error summary and say that the form is always valid -->
                        <xsl:when test="$is-form-builder">
                            <valid>true</valid>
                            <errors-count>0</errors-count>
                            <visible-errors-count>0</visible-errors-count>
                            <trigger/>
                        </xsl:when>
                        <xsl:otherwise>
                            <valid/>
                            <errors-count/>
                            <visible-errors-count/>
                            <trigger/>
                        </xsl:otherwise>
                    </xsl:choose>
                </error-summary>
            </xforms:instance>
            <xforms:bind nodeset="trigger" readonly="not(../valid = 'true')"/>

            <!-- Verify captcha and mark all controls as visited when certain buttons are activated -->
            <xforms:action ev:event="DOMActivate" ev:observer="fr-save-button fr-workflow-review-button fr-workflow-send-button fr-print-button fr-pdf-button fr-email-button fr-refresh-button fr-submit-button">

                <!-- Do captcha verification, if needed -->
                <!-- NOTE: The code would be shorter here if we were to use the XSLT app/form variables, but we want to move away from XSLT for FR -->
                <xxforms:variable name="parameters" value="xxforms:instance('fr-parameters-instance')" as="element()"/>
                <xxforms:variable name="app" value="$parameters/app" as="xs:string"/>
                <xxforms:variable name="form" value="$parameters/form" as="xs:string"/>
                <xsl:if test="$has-captcha">
                    <xforms:action if="xxforms:instance('fr-persistence-instance')/captcha = 'false'">
                        <xforms:dispatch target="captcha" name="fr-verify"/>
                    </xforms:action>
                </xsl:if>

                <!-- Show all error in error summaries -->
                <xsl:if test="$error-summary-top"><xforms:dispatch name="fr-visit-all" targetid="error-summary-control-top"/></xsl:if>
                <xforms:dispatch name="fr-visit-all" targetid="error-summary-control-bottom"/>

            </xforms:action>

            <!-- Mark all controls as un-visited when certain buttons are activated -->
            <xforms:action ev:event="fr-unvisit-all">
                <!-- Dispatch to the appropriate error summaries -->
                <!-- Don't dispatch to top error-summary if not present; but always dispatch to bottom error summary as it is always included -->
                <xsl:if test="$error-summary-top">
                    <xforms:dispatch name="fr-unvisit-all" targetid="error-summary-control-top"/>
                </xsl:if>
                <xforms:dispatch name="fr-unvisit-all" targetid="error-summary-control-bottom"/>
            </xforms:action>
        </xforms:model>
        <!-- This model handles document persistence -->
        <xi:include href="oxf:/apps/fr/includes/persistence/persistence-model.xml" xxi:omit-xml-base="true"/>
        <!-- This model handles navigation functionality -->
        <xi:include href="oxf:/apps/fr/includes/navigation-model.xml" xxi:omit-xml-base="true"/>
        <xsl:if test="$has-alfresco">
            <!-- This model handles Alfresco integration -->
            <xi:include href="oxf:/apps/fr/alfresco/alfresco-model.xml" xxi:omit-xml-base="true"/>
        </xsl:if>

        <!-- This model supports Form Runner rendered through the xforms-renderer -->
        <xforms:model id="fr-xforms-renderer-model">
            <xforms:instance id="fr-xforms-renderer-instance">
                <xforms-renderer>
                    <is-rendered>
                        <xsl:value-of select="$is-rendered"/>
                    </is-rendered>
                    <url-base-for-requests>
                        <xsl:value-of select="$url-base-for-requests"/>
                    </url-base-for-requests>
                </xforms-renderer>
            </xforms:instance>
        </xforms:model>

        <!-- Copy and annotate existing main model -->
        <xsl:copy>
            <xsl:apply-templates select="@*"/>

            <!-- If the first model doesn't have an id, add fr-form-model -->
            <xsl:if test="not(@id)">
                <xsl:attribute name="id" select="'fr-form-model'"/>
            </xsl:if>

            <xsl:apply-templates select="node()"/>

            <!-- Variable exposing all the user roles -->
            <xxforms:variable name="fr-roles" select="tokenize(xxforms:instance('fr-permissions')/@all-roles, '\s+')" as="xs:string*"/>
            <!-- Variable exposing the form mode -->
            <xxforms:variable name="fr-mode" select="xxforms:instance('fr-parameters-instance')/mode"/>

            <!-- Bind to set the form instance read-only when necessary -->
            <xforms:bind nodeset="instance('fr-form-instance')" readonly="$fr-mode = ('view', 'pdf', 'email')"/>

        </xsl:copy>

        <xsl:if test="not($is-noscript)">
            <!-- Handle checking dirty status -->
            <xi:include href="oxf:/apps/fr/includes/check-dirty-script.xhtml" xxi:omit-xml-base="true"/>
        </xsl:if>

    </xsl:template>

    <xsl:template match="/xhtml:html/xhtml:head/xforms:model[1]/xforms:instance[1]">
        <xsl:copy>
            <xsl:apply-templates select="@*"/>

            <!-- If there is no instance with fr-form-instance consider the first one is it -->
            <xsl:if test="not(exists(../xforms:instance[@id = 'fr-form-instance']))">
                <xsl:attribute name="id" select="'fr-form-instance'"/>
            </xsl:if>

            <xsl:apply-templates select="node()"/>

        </xsl:copy>
    </xsl:template>

</xsl:stylesheet>
