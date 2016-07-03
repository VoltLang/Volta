// Copyright © 2012-2016, Jakob Bornecrantz.  All rights reserved.
// See copyright notice in src/volt/license.d (BOOST ver. 1.0).
module core.rt.aa;

import core.typeinfo;


extern(C):

void* vrt_aa_new(TypeInfo value, TypeInfo key);
void* vrt_aa_dup(void* rbtv);
bool vrt_aa_in_primitive(void* rbtv, ulong key, void* ret);
bool vrt_aa_in_array(void* rbtv, void[] key, void* ret);
void vrt_aa_insert_primitive(void* rbtv, ulong key, void* value);
void vrt_aa_insert_array(void* rbtv, void[] key, void* value);
bool vrt_aa_delete_primitive(void* rbtv, ulong key);
bool vrt_aa_delete_array(void* rbtv, void[] key);
void[] vrt_aa_get_keys(void* rbtv);
void[] vrt_aa_get_values(void* rbtv);
size_t vrt_aa_get_length(void* rbtv);
void* vrt_aa_in_binop_array(void* rbtv, void[] key);
void* vrt_aa_in_binop_primitive(void* rbtv, ulong key);
void vrt_aa_rehash(void* rbtv);
ulong vrt_aa_get_pp(void* rbtv, ulong key, ulong _default);
void[] vrt_aa_get_aa(void* rbtv, void[] key, void[] _default);
ulong vrt_aa_get_ap(void* rbtv, void[] key, ulong _default);
void[] vrt_aa_get_pa(void* rbtv, ulong key, void[] _default);
