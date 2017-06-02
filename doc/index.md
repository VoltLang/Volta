---
title: Metal conducting Volt research
layout: page
---

# Volta

This is the project page for the [Volt Programming Language](http://www.volt-lang.org) compiler Volta.
It is named after [Alessandro Volta](https://en.wikipedia.org/wiki/Alessandro_Volta),
tho the compiler got its named after the language was named Volt.
Some various documentation is listed below.

*  [The Volt Programming Language]({{ site.baseurl }}/volt.html)
*  [Errors]({{ site.baseurl }}/errors.html)
*  [Foreach, strings and you]({{ site.baseurl }}/foreach-and-strings.html)
*  [Symbol Mangling]({{ site.baseurl }}/mangle.html)
*  [Volt vs C]({{ site.baseurl }}/volt-vs-c.html)
*  [Volt vs C++]({{ site.baseurl }}/volt-vs-cpp.html)
*  [Volt vs D]({{ site.baseurl }}/volt-vs-d.html)

Here is a bunch of modules from the compiler:

{% for mod in doc.modules %}
*  [{{ mod.name }}]({{ mod.url }})
{%- endfor -%}
