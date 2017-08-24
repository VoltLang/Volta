// Copyright © 2012-2017, Jakob Bornecrantz.
// See copyright notice in src/volt/license.d (BOOST ver. 1.0).
module core.rt.aa;

import core.typeinfo;


extern(C):

/*!
 * Creates a new associative array.
 */
fn vrt_aa_new(value: TypeInfo, key: TypeInfo) void*;
/*!
 * Copies an existing associative array.
 */
fn vrt_aa_dup(rbtv: void*) void*;
/*!
 * Check if a primitive key is in an associative array.
 */
fn vrt_aa_in_primitive(rbtv: void*, key: ulong, ret: void*) bool;
/*!
 * Check if an array key is in an associative array.
 */
fn vrt_aa_in_array(rbtv: void*, key: void[], ret: void*) bool;
/*!
 * Check if a pointer key is in an associative array.
 */
fn vrt_aa_in_ptr(rbtv: void*, key: void*, ret: void*) bool;
/*!
 * Insert a value in a primitive keyed associative array.
 */
fn vrt_aa_insert_primitive(rbtv: void*, key: ulong, value: void*);
/*!
 * Insert a value in an array keyed associative array.
 */
fn vrt_aa_insert_array(rbtv: void*, key: void[], value: void*);
/*!
 * Insert a value in a pointer keyed associative array.
 */
fn vrt_aa_insert_ptr(rbtv: void*, key: void*, value: void*);
/*!
 * Delete a value associated with a primitive key.
 */
fn vrt_aa_delete_primitive(rbtv: void*, key: ulong) bool;
/*!
 * Delete a value associated with an array key.
 */
fn vrt_aa_delete_array(rbtv: void*, key: void[]) bool;
/*!
 * Delete a value associate with a pointer key.
 */
fn vrt_aa_delete_ptr(rbtv: void*, key: void*) bool;
/*!
 * Get the keys array for a given associative array.
 */
fn vrt_aa_get_keys(rbtv: void*) void[];
/*!
 * Get the values array for a given associative array.
 */
fn vrt_aa_get_values(rbtv: void*) void[];
/*!
 * Get the number of pairs in a given associative array.
 */
fn vrt_aa_get_length(rbtv: void*) size_t;
/*!
 * The `in` operator for an array keyed associative array.
 */
fn vrt_aa_in_binop_array(rbtv: void*, key: void[]) void*;
/*!
 * The `in` operator for a primitive keyed associative array.
 */
fn vrt_aa_in_binop_primitive(rbtv: void*, key: ulong) void*;
/*!
 * The `in` operator for a pointer keyed associative array.
 */
fn vrt_aa_in_binop_ptr(rbtv: void*, key: void*) void*;
/*!
 * Rehash an associative array to optimise performance.
 *
 * This is a no-op in the current implementation.
 */
fn vrt_aa_rehash(rbtv: void*);
/*!
 * The `get` method for a pointer keyed associative array.
 */
fn vrt_aa_get_ptr(rbtv: void*, key: void*, _default: void*) void*;
/*!
 * The `get` method for a primitive key, primitive value associative array.
 */
fn vrt_aa_get_pp(rbtv: void*, key: ulong, _default: ulong) ulong;
/*!
 * The `get` method for an array key, array value associative array.
 */
fn vrt_aa_get_aa(rbtv: void*, key: void[], _default: void[] ) void*;
/*!
 * The `get` method for an array key, primitive value associative array.
 */
fn vrt_aa_get_ap(rbtv: void*, key: void[], _default: ulong) ulong;
/*!
 * The `get` method for a primitive key, array value associative array.
 */
fn vrt_aa_get_pa(rbtv: void*, key: ulong, _default: void[] ) void*;
