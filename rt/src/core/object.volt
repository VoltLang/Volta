// Copyright © 2016-2017, Jakob Bornecrantz.
// See copyright notice in src/volt/license.d (BOOST ver. 1.0).
//! Root object for classes.
module core.object;


//! Root object for all classes.
class Object
{
	~this() {}

	fn toString() string
	{
		return "core.object.Object";
	}
}
