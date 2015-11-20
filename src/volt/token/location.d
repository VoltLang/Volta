// Copyright © 2012-2015, Jakob Bornecrantz.  All rights reserved.
// Copyright © 2010-2015, Bernard Helyer.  All rights reserved.
// Copyright © 2011, Jakob Ovrum.  All rights reserved.
// See copyright notice in src/diode/license.volt (BOOST ver. 1.0).
module volt.token.location;

import watt.text.format : format;


/**
 * Struct representing a location in a source file.
 *
 * This was pretty much stolen wholesale from Daniel Keep.
 */
struct Location
{
public:
	string filename;
	size_t line;
	size_t column;
	size_t length;

public:
	string toString()
	{
		return format("%s:%s:%s", filename, line, column);
	}

	/**
	 * Difference between two locations
	 * end - begin == begin ... end
	 */
	Location opSub(ref Location begin)
	{
		if (begin.filename != filename ||
		    begin.line > line) {
			return begin;
		}

		Location loc;
		loc.filename = filename;
		loc.line = begin.line;
		loc.column = begin.column;

		if (line != begin.line) {
			loc.length = cast(size_t)-1; // End of line
		} else {
			assert(begin.column <= column);
			loc.length = column + length - begin.column;
		}

		return loc;
	}

	/**
	 * Same as opSub, but on mismatch of filename or
	 * if begin is after end _default is returned.
	 */
	static Location difference(ref Location end, ref Location begin,
	                           ref Location _default)
	{
		if (begin.filename != end.filename ||
		    begin.line > end.line) {
			return _default;
		} else {
			return end.opSub(/*ref*/ begin);
		}
	}

	void spanTo(ref Location end)
	{
		if (line <= end.line && column < end.column) {
			this = end - this;
		}
	}
}
