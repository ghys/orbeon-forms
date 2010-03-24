/**
 * Copyright (C) 2010 Orbeon, Inc.
 *
 * This program is free software; you can redistribute it and/or modify it under the terms of the
 * GNU Lesser General Public License as published by the Free Software Foundation; either version
 * 2.1 of the License, or (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY;
 * without even the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
 * See the GNU Lesser General Public License for more details.
 *
 * The full text of the license is available at http://www.gnu.org/copyleft/lesser.html
 */
package org.orbeon.oxf.xforms.analysis.controls;

import org.dom4j.Element;
import org.orbeon.oxf.util.PropertyContext;
import org.orbeon.oxf.util.XPathCache;
import org.orbeon.oxf.xforms.XFormsConstants;
import org.orbeon.oxf.xforms.XFormsContainingDocument;
import org.orbeon.oxf.xforms.XFormsStaticState;
import org.orbeon.oxf.xforms.analysis.XPathAnalysis;
import org.orbeon.oxf.xml.dom4j.LocationData;
import org.orbeon.saxon.dom4j.DocumentWrapper;
import org.orbeon.saxon.expr.Expression;

import java.util.Map;

public class ControlAnalysis {

    public final XFormsStaticState staticState;

    public final String prefixedId;
    public final Element element;
    public final LocationData locationData;
    public final int index;
    public final boolean hasNodeBinding;
    public final boolean isValueControl;
    public final ContainerAnalysis parentControlAnalysis;
    public final Map<String, ControlAnalysis> inScopeVariables; // variable name -> ControlAnalysis

    public final XPathAnalysis bindingAnalysis;
    public final XPathAnalysis valueAnalysis;

    private String classes;

    public ControlAnalysis(PropertyContext propertyContext, XFormsStaticState staticState, DocumentWrapper controlsDocumentInfo, String prefixedId,
                           Element element, LocationData locationData, int index, boolean hasNodeBinding, boolean isValueControl,
                           ContainerAnalysis parentControlAnalysis, Map<String, ControlAnalysis> inScopeVariables) {

        this.staticState = staticState;
        this.prefixedId = prefixedId;
        this.element = element;
        this.locationData = locationData;
        this.index = index;
        this.hasNodeBinding = hasNodeBinding;
        this.isValueControl = isValueControl;
        this.parentControlAnalysis = parentControlAnalysis;
        this.inScopeVariables = inScopeVariables;

        if (staticState.isXPathAnalysis()) {
            // TODO: handle @model and xxbl:scope changes
            this.bindingAnalysis = computeBindingAnalysis();
            this.valueAnalysis = computeValueAnalysis();
        } else {
            bindingAnalysis = null;
            valueAnalysis = null;
        }
    }

    protected XPathAnalysis computeBindingAnalysis() {
        if (element != null) {
            final String bindingExpression;
            if (element.attributeValue("context") == null) {
                final String ref = element.attributeValue("ref");
                if (ref != null) {
                    bindingExpression = ref;
                } else {
                    bindingExpression = element.attributeValue("nodeset");
                }
            } else {
                // TODO: handle @context
                bindingExpression = null;
            }

            if ((bindingExpression != null)) {
                return analyzeXPath(staticState, getAncestorOrSelfBindingAnalysis(), prefixedId, bindingExpression);
            } else {
                // TODO: TEMP: just do this for now so that controls w/o their own binding also get binding updated
                return getAncestorOrSelfBindingAnalysis();
            }
        } else {
            return null;
        }
    }

    protected XPathAnalysis computeValueAnalysis () {
        if (element != null) {
            final XPathAnalysis baseAnalysis = getAncestorOrSelfBindingAnalysis();
            if (this instanceof VariableAnalysis) {
                // TODO: handle xxf:sequence
                return analyzeXPath(staticState, baseAnalysis, prefixedId, element.attributeValue("select"));
            } else if (isValueControl) {
                final String valueAttribute = element.attributeValue("value");

                final boolean isXXFormsAttribute = element.getQName().equals(XFormsConstants.XXFORMS_ATTRIBUTE_QNAME);
                if (isXXFormsAttribute) {
                    // TODO
                    // NOTE: bad design that AVT has @value as attribute name
                    return null;
                } else if (valueAttribute != null) {
                    // E.g. xforms:output/@value
                    return analyzeXPath(staticState, baseAnalysis, prefixedId, valueAttribute);
                } else {
                    // Value is considered the string value
                    return analyzeXPath(staticState, baseAnalysis, prefixedId, "string()");
                }
            } else {
                return null;
            }
        } else {
            return null;
        }
    }

    private XPathAnalysis getAncestorOrSelfBindingAnalysis() {
        ControlAnalysis currentControlAnalysis = this;
        while (currentControlAnalysis != null) {

            if (currentControlAnalysis.bindingAnalysis != null)
                return currentControlAnalysis.bindingAnalysis;

            currentControlAnalysis = currentControlAnalysis.parentControlAnalysis;
        }

        return null;
    }

    protected XPathAnalysis analyzeXPath(XFormsStaticState staticState, XPathAnalysis baseAnalysis, String prefixedId, String xpathString) {
        // Create new expression
        // TODO: get expression from pool and pass in-scope variables (probably more efficient)
        final Expression expression = XPathCache.createExpression(staticState.getXPathConfiguration(), xpathString,
                staticState.getMetadata().namespaceMappings.get(prefixedId), XFormsContainingDocument.getFunctionLibrary());
        // Analyse it
        return new XPathAnalysis(staticState, expression, xpathString, baseAnalysis, inScopeVariables);

    }

    public void addClasses(String classes) {
        if (this.classes == null) {
            // Set
            this.classes = classes;
        } else {
            // Append
            this.classes = this.classes + ' ' + classes;
        }
    }

    public String getClasses() {
        return classes;
    }

    public int getLevel() {
        if (parentControlAnalysis == null)
            return 0;
        else
            return parentControlAnalysis.getLevel() + 1;
    }

    public RepeatAnalysis getAncestorRepeat() {
        ContainerAnalysis currentParent = parentControlAnalysis;
        while (currentParent != null) {
            if (currentParent instanceof RepeatAnalysis)
                return (RepeatAnalysis) currentParent;
            currentParent = currentParent.parentControlAnalysis;
        }
        return null;
    }
}