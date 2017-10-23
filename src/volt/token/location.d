/*#D*/
// Copyright © 2012-2015, Jakob Bornecrantz.  All rights reserved.
// Copyright © 2010-2015, Bernard Helyer.  All rights reserved.
// Copyright © 2011, Jakob Ovrum.  All rights reserved.
// See copyright notice in src/diode/license.volt (BOOST ver. 1.0).
module volt.token.location;

import watt.text.format : format;


/*!
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
	const string toString()
	{
		return format("%s:%s:%s", filename, line, column);
	}


	/*!
	 * Difference between two locations.
	 * end - begin == begin ... end
	 * @see difference
	 */
	Location opSub(ref Location begin)
	{
		return difference(/*#ref*/this,/*#ref*/begin,/*#ref*/begin);
	}

	/*!
	 * Difference between two locations.
	 * end - begin == begin ... end
	 * On mismatch of filename or if begin is after
	 * end _default is returned.
	 */
	static Location difference(ref Location end, ref Location begin,
	                           ref Location _default)
	{
		if (begin.filename != end.filename ||
		    begin.line > end.line) {
			return _default;
		}

		Location loc;
		loc.filename = begin.filename;
		loc.line = begin.line;
		loc.column = begin.column;

		if (end.line != begin.line) {
			loc.length = size_t.max; // End of line.
		} else {
			assert(begin.column <= end.column);
			loc.length = end.column + end.length - begin.column;
		}

		return loc;
	}

	void spanTo(ref Location end)
	{
		if (line <= end.line && column < end.column) {
			this = end - this;
		}
	}
}
