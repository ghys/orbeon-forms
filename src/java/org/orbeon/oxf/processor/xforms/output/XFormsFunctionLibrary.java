/*
 * Copyright 1998-2002, Orbeon, Inc.
 * All Rights Reserved
 *
 * This is unpublished proprietary source code of Orbeon, Inc. The
 * copyright notice above does not evidence any actual or intended
 * publication of such source code.
 */
package org.orbeon.oxf.processor.xforms.output;

import org.orbeon.oxf.common.OXFException;
import org.orbeon.oxf.processor.xforms.output.element.XFormsElementContext;
import org.orbeon.oxf.processor.xforms.output.function.*;
import org.orbeon.saxon.expr.Expression;
import org.orbeon.saxon.expr.StaticProperty;
import org.orbeon.saxon.functions.FunctionLibrary;
import org.orbeon.saxon.functions.StandardFunction;
import org.orbeon.saxon.functions.SystemFunction;
import org.orbeon.saxon.om.NamespaceConstant;
import org.orbeon.saxon.type.ItemType;
import org.orbeon.saxon.type.Type;
import org.orbeon.saxon.value.SequenceType;
import org.orbeon.saxon.xpath.XPathException;

import java.util.HashMap;
import java.util.Map;

public class XFormsFunctionLibrary implements FunctionLibrary {


    private static Map functionTable = new HashMap();
    private XFormsElementContext xformsElementContext = null;


    private static StandardFunction.Entry register( String name,
                                                    Class implementationClass,
                                                    int opcode,
                                                    int minArguments,
                                                    int maxArguments,
                                                    ItemType itemType,
                                                    int cardinality ) {
        StandardFunction.Entry e = new StandardFunction.Entry();
        e.name = name;
        e.implementationClass = implementationClass;
        e.opcode = opcode;
        e.minArguments = minArguments;
        e.maxArguments = maxArguments;
        e.itemType = itemType;
        e.cardinality = cardinality;
        e.argumentTypes = new SequenceType[maxArguments];

        functionTable.put(name, e);
        return e;
    }

    static {
      StandardFunction.Entry e;

        e = register("last", Last.class, 0, 0, 0, Type.INTEGER_TYPE, StaticProperty.EXACTLY_ONE);

        // 7.7 Boolean Functions
        e = register("boolean-from-string", BooleanFromString.class, 0, 1, 1, Type.STRING_TYPE, StaticProperty.EXACTLY_ONE);
        StandardFunction.arg(e, 0, Type.STRING_TYPE, StaticProperty.EXACTLY_ONE);

        e = register("xfif", If.class, 0, 3, 3, Type.STRING_TYPE, StaticProperty.EXACTLY_ONE);
        StandardFunction.arg(e, 0, Type.BOOLEAN_TYPE, StaticProperty.EXACTLY_ONE);
        StandardFunction.arg(e, 1, Type.STRING_TYPE, StaticProperty.EXACTLY_ONE);
        StandardFunction.arg(e, 2, Type.STRING_TYPE, StaticProperty.EXACTLY_ONE);

        // 7.8 Number Funtions (avg(), min(), max() are implemented in XPath 2.0)
        e = register("count-non-empty", CountNonEmpty.class, 0, 1, 1, Type.INTEGER_TYPE, StaticProperty.EXACTLY_ONE);
        StandardFunction.arg(e, 0, Type.ANY_ATOMIC_TYPE, StaticProperty.ALLOWS_ZERO_OR_MORE);

        e = register("index", Index.class, 0, 1, 1, Type.INTEGER_TYPE, StaticProperty.EXACTLY_ONE);
        StandardFunction.arg(e, 0, Type.STRING_TYPE, StaticProperty.EXACTLY_ONE);

        // 7.9 String Functions
        e = register("property", Property.class, 0, 1, 1, Type.STRING_TYPE, StaticProperty.EXACTLY_ONE);
        StandardFunction.arg(e, 0, Type.STRING_TYPE, StaticProperty.EXACTLY_ONE);

        // 7.10 Date and Time Functions

        // Masquerade Saxon's current-datetime()
        e = register("now", Now.class, 0, 0, 1, Type.STRING_TYPE, StaticProperty.EXACTLY_ONE);
        StandardFunction.arg(e, 0, Type.STRING_TYPE, StaticProperty.ALLOWS_ZERO_OR_ONE);

        e = register("days-from-date", DaysFromDate.class, 0, 1, 1, Type.INTEGER_TYPE, StaticProperty.EXACTLY_ONE);
        StandardFunction.arg(e, 0, Type.STRING_TYPE, StaticProperty.EXACTLY_ONE);

        e = register("seconds-from-dateTime", SecondsFromDateTime.class, 0, 1, 1, Type.INTEGER_TYPE, StaticProperty.EXACTLY_ONE);
        StandardFunction.arg(e, 0, Type.STRING_TYPE, StaticProperty.EXACTLY_ONE);

        e = register("seconds", Seconds.class, 0, 1, 1, Type.DOUBLE_TYPE, StaticProperty.EXACTLY_ONE);
        StandardFunction.arg(e, 0, Type.STRING_TYPE, StaticProperty.EXACTLY_ONE);

        e = register("months", Months.class, 0, 1, 1, Type.INTEGER_TYPE, StaticProperty.EXACTLY_ONE);
        StandardFunction.arg(e, 0, Type.STRING_TYPE, StaticProperty.EXACTLY_ONE);
    }



    public XFormsFunctionLibrary() { }


    public XFormsFunctionLibrary(XFormsElementContext xformsElementContext) {
        this.xformsElementContext = xformsElementContext;
    }

    public boolean isAvailable(int fingerprint, String uri, String local, int arity) {
        if (uri.equals(NamespaceConstant.FN)) {
            StandardFunction.Entry entry = (StandardFunction.Entry)functionTable.get(local);
            if (entry == null) {
                return false;
            }
            return (arity == -1 ||
                    (arity >= entry.minArguments && arity <= entry.maxArguments));
        } else {
            return false;
        }
    }

    public Expression bind(int nameCode, String uri, String local, Expression[] staticArgs) throws XPathException {
        if (uri.equals(NamespaceConstant.FN)) {
            StandardFunction.Entry entry = (StandardFunction.Entry)functionTable.get(local);
            if (entry == null) {
                return null;
            }
            Class functionClass = entry.implementationClass;
            SystemFunction f;
            try {
                f = (SystemFunction)functionClass.newInstance();
            } catch (Exception err) {
                throw new OXFException("Failed to load XForms function: " + err.getMessage(), err);
            }
            if(f instanceof XFormsFunction && xformsElementContext != null)
                ((XFormsFunction)f).setXformsElementContext(xformsElementContext);
            f.setDetails(entry);
            f.setFunctionNameCode(nameCode);
            f.setArguments(staticArgs);
            return f;
        } else {
            return null;
        }
    }
}
