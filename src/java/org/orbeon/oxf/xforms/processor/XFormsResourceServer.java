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
package org.orbeon.oxf.xforms.processor;

import net.sf.ehcache.Element;
import org.orbeon.oxf.common.OXFException;
import org.orbeon.oxf.pipeline.api.ExternalContext;
import org.orbeon.oxf.pipeline.api.PipelineContext;
import org.orbeon.oxf.processor.ProcessorImpl;
import org.orbeon.oxf.processor.ResourceServer;
import org.orbeon.oxf.resources.URLFactory;
import org.orbeon.oxf.util.*;
import org.orbeon.oxf.xforms.Caches;
import org.orbeon.oxf.xforms.Loggers;
import org.orbeon.oxf.xforms.XFormsProperties;

import java.io.*;
import java.net.URL;
import java.net.URLConnection;
import java.net.URLEncoder;
import java.util.ArrayList;
import java.util.Collections;
import java.util.List;
import java.util.Map;

/**
 * Serve XForms engine JavaScript and CSS resources by combining them.
 */
public class XFormsResourceServer extends ProcessorImpl {

    public static final String DYNAMIC_RESOURCES_SESSION_KEY = "orbeon.resources.dynamic.";
    public static final String DYNAMIC_RESOURCES_PATH = "/xforms-server/dynamic/";

    public XFormsResourceServer() {}

    public static IndentedLogger getIndentedLogger() {
        return Loggers.getIndentedLogger("resources");
    }

    @Override
    public void start(PipelineContext pipelineContext) {
        final ExternalContext externalContext = NetUtils.getExternalContext();
        final ExternalContext.Request request = externalContext.getRequest();
        final ExternalContext.Response response = externalContext.getResponse();

        final String requestPath = request.getRequestPath();
        final String filename = requestPath.substring(requestPath.lastIndexOf('/') + 1);
        
        final IndentedLogger indentedLogger = getIndentedLogger();

        if (requestPath.startsWith(DYNAMIC_RESOURCES_PATH)) {
            // Dynamic resource requested

            final ExternalContext.Session session = externalContext.getRequest().getSession(false);
            if (session != null) {
                // Store mapping into session
                final String lookupKey = DYNAMIC_RESOURCES_SESSION_KEY + filename;
                // Use same session scope as proxyURI()
                final DynamicResource resource = (DynamicResource) session.getAttributesMap(ExternalContext.Session.APPLICATION_SCOPE).get(lookupKey);

                if (resource != null && resource.url != null) {
                    // Found URL, stream it out

                    // Set caching headers

                    // NOTE: Algorithm is that XFOutputControl currently passes either -1 or the last modified of the
                    // resource if "fast" to obtain last modified ("oxf:" or "file:"). Would be nice to do better: pass
                    // whether resource is cacheable or not; here, when dereferencing the resource, we get the last
                    // modified (Last-Modified header from HTTP even) and store it. Then we can handle conditional get.
                    // This is some work though. Might have to proxy conditional GET as well. So for now we don't
                    // handle conditional GET and produce a non-now last modified only in a few cases.
                    
                    response.setResourceCaching(resource.lastModified, 0);

                    if (resource.size > 0)
                        response.setContentLength((int) resource.size);// NOTE: Why does this API (and Servlet counterpart) take an int?
                    
                    // TODO: for Safari, try forcing application/octet-stream
                    // NOTE: IE 6/7 don't display a download box when detecting an HTML document (known IE bug)
                    if (resource.contentType != null)
                        response.setContentType(resource.contentType);
                    else
                        response.setContentType("application/octet-stream");

                    // File name visible by the user
                    final String contentFilename = resource.filename != null ? resource.filename : filename;

                    // Handle as attachment
                    // TODO: should try to provide extension based on mediatype if file name is not provided?
                    // TODO: filename should be encoded somehow, as 1) spaces don't work and 2) non-ISO-8859-1 won't work
                    try {
//                        response.setHeader("Content-Disposition", "?utf-8?b?" + Base64.encode(("attachment; filename=" + contentFilename).getBytes("UTF-8")) +"?=");
                        response.setHeader("Content-Disposition", "attachment; filename=" + URLEncoder.encode(contentFilename, "UTF-8"));
                    } catch (UnsupportedEncodingException e) {
                        // Will not happen
                        throw new OXFException(e);
                    }

                    // Copy stream out
                    InputStream is = null;
                    OutputStream os = null;
                    try {
                        //
                        final URLConnection connection = resource.url.openConnection();

                        // Set outgoing headers
                        for (final Map.Entry<String, String[]> entry : resource.headers.entrySet() ) {
                            final String name = entry.getKey();
                            for (final String value : entry.getValue())
                                connection.addRequestProperty(name, value);
                        }

                        is = connection.getInputStream();

                        os = response.getOutputStream();
                        NetUtils.copyStream(is, os);
                        os.flush();
                    } catch (Exception e) {
                        indentedLogger.logWarning("", "exception copying stream", e);
                    } finally {
                        if (is != null) {
                            try {
                                is.close();
                            } catch (IOException e) {
                                indentedLogger.logWarning("", "exception closing input stream", e);
                            }
                        }
                        if (os != null) {
                            try {
                                os.close();
                            } catch (IOException e) {
                                indentedLogger.logWarning("", "exception closing output stream", e);
                            }
                        }
                    }
                } else {
                    // Not found
                    response.setStatus(ExternalContext.SC_NOT_FOUND);
                }
            }

        } else {
            // CSS or JavaScript resource requested
            final boolean isCSS = filename.endsWith(".css");
            final boolean isJS = filename.endsWith(".js");

            // Eliminate funny requests
            if (!isCSS && !isJS) {
                response.setStatus(ExternalContext.SC_NOT_FOUND);
                return;
            }

            final List<XFormsFeatures.ResourceConfig> resources;
            boolean isMinimal = false;
            if (filename.startsWith("orbeon-")) {
                // New hash-based mechanism

                final String resourcesHash = filename.substring("orbeon-".length(), filename.lastIndexOf("."));
                final Element cacheElement = Caches.resourcesCache().get(resourcesHash);
                if (cacheElement != null) {
                    // Mapping found
                    final String[] resourcesStrings = (String[]) cacheElement.getValue();
                    resources = new ArrayList<XFormsFeatures.ResourceConfig>(resourcesStrings.length);
                    for (final String resourceString : resourcesStrings)
                        resources.add(new XFormsFeatures.ResourceConfig(resourceString, resourceString));
                } else {
                    // Not found, either because the hash is invalid, or because the cache lost the mapping
                    response.setStatus(ExternalContext.SC_NOT_FOUND);
                    return;
                }
            } else {
                response.setStatus(ExternalContext.SC_NOT_FOUND);
                return;
            }

            // Get last modified date
            final long combinedLastModified = XFormsResourceRewriter.computeCombinedLastModified(resources, isMinimal);

            // If conditional get and date ok, send not modified

            // Set Last-Modified, required for caching and conditional get
            if (URLRewriterUtils.isResourcesVersioned()) {
                // Use expiration far in the future
                response.setResourceCaching(combinedLastModified, combinedLastModified + ResourceServer.ONE_YEAR_IN_MILLISECONDS);
            } else {
                // Use standard expiration policy
                response.setResourceCaching(combinedLastModified, 0);
            }

            // Check If-Modified-Since and don't return content if condition is met
            if (!response.checkIfModifiedSince(combinedLastModified, false)) {
                response.setStatus(ExternalContext.SC_NOT_MODIFIED);
                return;
            }

            OutputStream os = null;
            try {
                os = response.getOutputStream();
                response.setContentType(isCSS ? "text/css" : "application/x-javascript");
                {
                    final boolean isDebugEnabled = indentedLogger.isDebugEnabled();
                    if (XFormsProperties.isCacheCombinedResources()) {
                        // Caching requested
                        final File resourceFile = XFormsResourceRewriter.cacheResources(resources, requestPath, combinedLastModified, isCSS, isMinimal);
                        if (resourceFile != null) {
                            // Caching could take place, send out cached result
                            if (isDebugEnabled)
                                indentedLogger.logDebug("resources", "serving from cache ", "request path", requestPath);
                            final FileInputStream fis = new FileInputStream(resourceFile);
                            NetUtils.copyStream(fis, os);
                            fis.close();
                            os.flush();
                        } else {
                            // Was unable to cache, just serve
                            if (isDebugEnabled)
                                indentedLogger.logDebug("resources", "caching requested but not possible, serving directly", "request path", requestPath);
                            XFormsResourceRewriter.generate(indentedLogger, resources, os, isCSS, isMinimal);
                        }
                    } else {
                        // Should not cache, just serve
                        if (isDebugEnabled)
                            indentedLogger.logDebug("resources", "caching not requested, serving directly", "request path", requestPath);
                        XFormsResourceRewriter.generate(indentedLogger, resources, os, isCSS, isMinimal);
                    }
                }
            } catch (OXFException e) {
                throw e;
            } catch (Exception e) {
                throw new OXFException(e);
            } finally {
                if (os != null) {
                    try {
                        os.close();
                    } catch (IOException e) {
                        indentedLogger.logWarning("", "exception closing output stream", e);
                    }
                }
            }
        }
    }

    /**
     * Transform an URI accessible from the server into a URI accessible from the client. The mapping expires with the
     * session.
     *
     * @param uri               server URI to transform
     * @param filename          file name
     * @param contentType       type of the content referred to by the URI, or null if unknown
     * @param lastModified      last modification timestamp
     * @param headers           connection headers
     * @return                  client URI
     */
    public static String proxyURI(IndentedLogger indentedLogger, String uri, String filename, String contentType,
                                  long lastModified, Map<String, String[]> headers, String headersToForward) {

        // Create a digest, so that for a given URI we always get the same key
        final String digest = SecureUtils.digestString(uri, "hex");

        // Get session
        final ExternalContext externalContext = NetUtils.getExternalContext();
        final ExternalContext.Session session = externalContext.getRequest().getSession(true);// NOTE: We force session creation here. Should we? What's the alternative?

        if (session != null) {

            final URL url; {

                // The resource URI may already be absolute, or may be relative to the server base. Make sure we work with an absolute URI.
                final String absoluteResourceURI = URLRewriterUtils.rewriteServiceURL(
                    NetUtils.getExternalContext().getRequest(),
                    uri,
                    ExternalContext.Response.REWRITE_MODE_ABSOLUTE
                );

                url = URLFactory.createURL(absoluteResourceURI);
            };

            // Determine outgoing headers
            final Map<String, String[]> outgoingHeaders =
                Connection.jBuildConnectionHeaders(url.getProtocol(), null, headers, headersToForward, indentedLogger);

            // Store mapping into session
            session.getAttributesMap(ExternalContext.Session.APPLICATION_SCOPE).put(DYNAMIC_RESOURCES_SESSION_KEY + digest,
                    new DynamicResource(url, filename, contentType, -1, lastModified, outgoingHeaders));
        }

        // Rewrite new URI to absolute path without the context
        return DYNAMIC_RESOURCES_PATH + digest;
    }
    
    // For unit tests only (called from XSLT)
    public static String[] testGetResources(String key) {
        final Element cacheElement = Caches.resourcesCache().get(key);
        if (cacheElement != null) {
            return (String[]) cacheElement.getValue();
        } else {
            return null;
        }
    }

    public static class DynamicResource implements Serializable {
        public final URL url;
        public final String filename;
        public final String contentType;
        public final long size;
        public final long lastModified;
        public final Map<String, String[]> headers;

        public DynamicResource(URL url, String filename, String contentType, long size, long lastModified, Map<String, String[]> headers) {
            this.url = url;
            this.filename = filename;
            this.contentType = contentType;
            this.size = size;
            this.lastModified = lastModified;
            this.headers = headers;
        }
    }
}
