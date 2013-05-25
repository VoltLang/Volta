// Copyright © 2010, Bernard Helyer.  All rights reserved.
// Copyright © 2011, Jakob Ovrum.  All rights reserved.
// Copyright © 2012, Jakob Bornecrantz.  All rights reserved.
// See copyright notice in src/volt/license.d (BOOST ver. 1.0).
module volt.token.location;

import std.string : format;


/**
 * Struct representing a location in a source file.
 *
 * This was pretty much stolen wholesale from Daniel Keep.
 */
struct Location
{
public:
	/// When the column is 0, the whole line is assumed to be the location
	enum size_t wholeLine = 0;

	string filename;
	size_t line = 1;
	size_t column = 1;
	size_t length = 0;

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
		if (begin.filename != filename || begin.line > line) {
			return begin;
		}

		Location loc;
		loc.filename = filename;
		loc.line = begin.line;
		loc.column = begin.column;

		if (line != begin.line) {
			loc.length = -1; // End of line
		} else {
			assert(begin.column <= column);
			loc.length = column + length - begin.column;
		}

		return loc;
	}

	/// Same as opSub, but on mismatch of filename or if begin is after end _default is returned.
	static Location difference(ref Location end, ref Location begin, ref Location _default)
	{
		if (begin.filename != end.filename || begin.line > end.line) {
			return _default;
		} else {
			return end.opSub(begin);
		}
	}

	void spanTo(ref Location end)
	{
		if (line <= end.line && column < end.column) {
			this = end - this;
		}
	}
}
