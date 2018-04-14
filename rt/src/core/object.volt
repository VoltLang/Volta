// Copyright 2016-2017, Jakob Bornecrantz.
// SPDX-License-Identifier: BSL-1.0
//! Root object for classes.
module core.object;


/*!
 * Root object for all classes.
 *
 * If a `class` does not inherit explicitly from another `class`,
 * then the compiler makes it inherit from this.
 */
class Object
{
	~this() {}

	fn toString() string
	{
		return "core.object.Object";
	}
}
