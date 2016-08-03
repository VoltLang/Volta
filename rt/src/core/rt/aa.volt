// Copyright © 2012-2016, Jakob Bornecrantz.  All rights reserved.
// See copyright notice in src/volt/license.d (BOOST ver. 1.0).
module core.rt.aa;

import core.typeinfo;


extern(C):

fn vrt_aa_new(value: TypeInfo, key: TypeInfo) void*;
fn vrt_aa_dup(rbtv: void*) void*;
fn vrt_aa_in_primitive(rbtv: void*, key: ulong, ret: void*) bool;
fn vrt_aa_in_array(rbtv: void*, key: void[], ret: void*) bool;
fn vrt_aa_insert_primitive(rbtv: void*, key: ulong, value: void*);
fn vrt_aa_insert_array(rbtv: void*, key: void[], value: void*);
fn vrt_aa_delete_primitive(rbtv: void*, key: ulong) bool;
fn vrt_aa_delete_array(rbtv: void*, key: void[]) bool;
fn vrt_aa_get_keys(rbtv: void*) void[];
fn vrt_aa_get_values(rbtv: void*) void[];
fn vrt_aa_get_length(rbtv: void*) size_t;
fn vrt_aa_in_binop_array(rbtv: void*, key: void[]) void*;
fn vrt_aa_in_binop_primitive(rbtv: void*, key: ulong) void*;
fn vrt_aa_rehash(rbtv: void*);
fn vrt_aa_get_pp(rbtv: void*, key: ulong, _default: ulong) ulong;
fn vrt_aa_get_aa(rbtv: void*, key: void[], _default: void[] ) void[];
fn vrt_aa_get_ap(rbtv: void*, key: void[], _default: ulong) ulong;
fn vrt_aa_get_pa(rbtv: void*, key: ulong, _default: void[] ) void[];
