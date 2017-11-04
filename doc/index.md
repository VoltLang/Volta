---
title: Metal conducting Volt research
layout: page
---

# Volta

If you want to learn about the compiler read the [overview](overview.html)
first. This is the project page for the
[Volt Programming Language](http://www.volt-lang.org) compiler Volta. It is
named after [Alessandro Volta](https://en.wikipedia.org/wiki/Alessandro_Volta),
tho the compiler got its named after the language was named Volt. Some various
documentation is listed below.

*  [Overview of the compilation process](overview.html)
{% for page in vdoc.groups -%}
*  [{{ page.name }}]({{ page.url }})
{% endfor -%}
*  [The Volt Programming Language]({{ site.baseurl }}/volt.html)
*  [Errors]({{ site.baseurl }}/errors.html)
*  [Symbol Mangling]({{ site.baseurl }}/mangle.html)
*  [Syntax Snippets]({{ site.baseurl }}/syntax.html)

Here is a bunch of modules from the compiler:

{% for mod in doc.modules %}
*  [{{ mod.name }}]({{ mod.url }})
{%- endfor -%}
