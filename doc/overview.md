---
title: Volta Overview
layout: page
---

{%- assign inter = 'volt.interfaces' | vdoc_find -%}
{%- assign parsing = 'parsing' | vdoc_find -%}
{%- assign semantic = 'semantic' | vdoc_find -%}
{%- assign backend = 'backend' | vdoc_find -%}
{%- assign passLang = 'passLang' | vdoc_find -%}
{%- assign passPost = 'passPost' | vdoc_find -%}
{%- assign passSem = 'passSem' | vdoc_find -%}
{%- assign passLower = 'passLower' | vdoc_find -%}

# Overview

This page contains a high level over of how the Volta compiler works. Most of
this documentation is directly generated from the [Interfaces]({{ inter.url }})
module, if you prefer to read code directly open it up in your favorite editor.

{% include content.md obj=parsing %}
{% include content.md obj=semantic %}
{% include content.md obj=backend %}

# Passes

{% include content.md obj=passLang %}
{% include content.md obj=passPost %}
{% include content.md obj=passSem %}
{% include content.md obj=passLower %}