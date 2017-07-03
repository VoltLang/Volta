{%- assign obj = include.obj %}

## {{ obj.name }}
<div class="doc-ingroup"><a href="{{ obj.url }}">Full doc</a></div>

{{ obj | vdoc_content: 'md' }}
