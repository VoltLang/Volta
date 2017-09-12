---
layout: page
title: The Volt Runtime
---

<h1>The Volt Runtime Library</h1>
<p>The runtime library provides services that Volt programs need to run. Memory allocation, associative arrays, and much more are implemented here, as well as bindings for system libraries.</p>
<p>The library is divided into modules and packages, described below.</p>

<h2>Package <code>core.*</code></h2>
<p>The <code>core</code> package contains all language central packages, and standard C bindings.</p>
<ul>
	<li><p><a href='{{ "core.object" | vdoc_find_url }}'>core.object</a> contains the definition of <code>Object</code>, the class that all Volt classes inherit from./</p></li>
	<li><p><a href='{{ "core.exception" | vdoc_find_url }}'>core.exception</a> contains the definition of <code>Throwable</code>, <code>Error</code>, <code>Exception</code>, and other default exceptions.</p></li>
	<li><p><a href='{{ "core.typeinfo" | vdoc_find_url }}'>core.typeinfo</a> contains the definition of the <code>TypeInfo</code> and <code>ClassInfo</code> classes, used with <code>typeid</code> and <code>classinfo</code> to provide basic introspection capabilities.</p></li>
	<li><p><a href='{{ "core.varargs" | vdoc_find_url }}'>core.varargs</a> contains some variadic definitions that compiler needs to be able to directly refer to.</p></li>
</ul>

<h2>Package <code>core.rt.*</code></h2>
<p>The rt package contains the runtime facilities.</p>
<p>Memory allocation, associative arrays, and other things running Volt programs used are contained here.</p>
<ul>
	<li><p><a href='{{ "core.rt.aa" | vdoc_find_url }}'>core.rt.aa</a> contains functions that the compiler uses to implement associative arrays.</p></li>
	<li><p><a href='{{ "core.rt.eh" | vdoc_find_url }}'>core.rt.eh</a> contains functions that both the compiler and application uses for exception handling.</p></li>
	<li><p><a href='{{ "core.rt.format" | vdoc_find_url }}'>core.rt.format</a> contains number formatting functions.</p></li>
	<li><p><a href='{{ "core.rt.gc" | vdoc_find_url }}'>core.rt.gc</a> contains the functions that interface with the garbage collector, the code responsible for freeing unused memory.</p></li>
	<li><p><a href='{{ "core.rt.misc" | vdoc_find_url }}'>core.rt.misc</a> contains functions that don't fit elsewhere, but that the compiler needs to be able to reference.<p></li>
</ul>

<h2>Package <code>core.compiler.*</code></h2>
<p>The compiler package contains intrinsics and default definitions.</p>
<ul>
	<li><p><a href='{{ "core.compiler.defaultsymbols" | vdoc_find_url }}'>core.compiler.defaultsymbols</a> contains the symbols, like <code>size_t</code> that are defined by default.</p></li>
	<li><p><a href='{{ "core.compiler.llvm" | vdoc_find_url }}'>core.compiler.llvm</a> contains some LLVM intrinsic functions.</p></li>
</ul>

<h2>Package <code>core.c.*</code></h2>
<p>The <code>core.c.*</code> package contains the <a href='{{ "cbind" | vdoc_find_url }}'>C Bindings</a> that are used by both the runtime and Volt applications.</p>
<ul>
	<li><p><a href='{{ "stdcbind" | vdoc_find_url }}'>core.c.*</a> contains bindings for the standard C library.</p></li>
	<li><p><a href='{{ "winbind" | vdoc_find_url }}'>core.c.windows.*</a> contains an incomplete binding to the Win32 API.</p></li>
	<li><p><a href='{{ "posixbind" | vdoc_find_url }}'>core.c.posix.*</a> contains bindings for *nix specific functions and syscalls.</p></li>
</ul>
