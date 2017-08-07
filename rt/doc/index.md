---
layout: page
title: The Volt Runtime
---

<h1>The Volt Runtime Library</h1>
<p>This text is a stub, better to follow.</p>
<p>The library is divided into modules and packages, described below.</p>

<h2>Package <code>core.*</code></h2>
<p>The <code>core</code> package contains all language central packages, and standard C bindings.</p>
<ul>
	<li><p><a href='{{ "core.object" | vdoc_find_url }}'>core.object</a> contains...</p></li>
	<li><p><a href='{{ "core.exception" | vdoc_find_url }}'>core.exception</a> contains...</p></li>
	<li><p><a href='{{ "core.typeinfo" | vdoc_find_url }}'>core.typeinfo</a> contains...</p></li>
	<li><p><a href='{{ "core.varargs" | vdoc_find_url }}'>core.varargs</a> contains...</p></li>
</ul>

<h2>Package <code>core.rt.*</code></h2>
<p>Is this a fantasy?</p>
<ul>
	<li><p><a href='{{ "core.rt.aa" | vdoc_find_url }}'>core.rt.aa</a> contains ...</p></li>
	<li><p><a href='{{ "core.rt.format" | vdoc_find_url }}'>core.rt.format</a> contains ...</p></li>
	<li><p><a href='{{ "core.rt.gc" | vdoc_find_url }}'>core.rt.gc</a> contains ...</p></li>
	<li><p><a href='{{ "core.rt.misc" | vdoc_find_url }}'>core.rt.misc</a> contains ...</p></li>
</ul>

<h2>Package <code>core.compiler.*</code></h2>
<p>Is this real life?</p>
<ul>
	<li><p><a href='{{ "core.compiler.defaultsymbols" | vdoc_find_url }}'>core.compiler.defaultsymbols</a> contains ...</p></li>
	<li><p><a href='{{ "core.compiler.llvm" | vdoc_find_url }}'>core.compiler.llvm</a> contains ...</p></li>
</ul>

<h2>Package <code>core.c.*</code></h2>
<p>The <code>core.c.*</code> package contains the <a href='{{ "cbind" | vdoc_find_url }}'>C Bindings</a> that is used by both the runtime and Volt applications.</p>
<ul>
	<li><p><a href='{{ "stdcbind" | vdoc_find_url }}'>core.c.*</a> contains...</p></li>
	<li><p><a href='{{ "winbind" | vdoc_find_url }}'>core.c.windows.*</a> contains...</p></li>
	<li><p><a href='{{ "posixbind" | vdoc_find_url }}'>core.c.posix.*</a> contains...</p></li>
</ul>
