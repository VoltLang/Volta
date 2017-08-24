// Copyright © 2016-2017, Jakob Bornecrantz.
// See copyright notice in src/volt/license.d (BOOST ver. 1.0).
module core.exception;


/*!
 * Base class of all objects that can be thrown.
 *
 * This should be inherited from, not thrown directly.
 */
class Throwable
{
	msg: string;

	// This is updated each time the exception is thrown.
	throwLocation: string;

	// This is manually supplied.
	location: string;

	/*!
	 * Construct a `Throwable` object.
	 *
	 * @Param msg A message describing the error.
	 * @Param location Where this was thrown from.
	 */
	this(msg: string, location: string = __LOCATION__)
	{
		this.msg = msg;
		this.location = location;
	}
}

/*!
 * An error that can be handled.
 *
 * This is one of the two (with `Error`) classes that user
 * code should inherit from when designing their
 * error handling objects.
 */
class Exception : Throwable
{
	/*!
	 * Construct an `Exception` object.
	 *
	 * @Param msg A message describing the error.
	 * @Param location Where this was thrown from.
	 */
	this(msg: string, location: string = __LOCATION__)
	{
		super(msg, location);
	}
}

/*!
 * An error that cannot be handled.
 *
 * This is one of the two (with `Exception`) classes that user
 * code should inherit from when designing their
 * error handling objects
 */
class Error : Throwable
{
	/*!
	 * Construct an `Error` object.
	 *
	 * @Param msg A message describing the error.
	 * @Param location Where this was thrown from.
	 */
	this(msg: string, location: string = __LOCATION__)
	{
		super(msg, location);
	}
}

/*!
 * Thrown if an `assert` fails.
 */
class AssertError : Error
{
	/*!
	 * Construct an `AssertError` object.
	 *
	 * @Param msg A message describing the error.
	 * @Param location Where this was thrown from.
	 */
	this(msg: string, location: string = __LOCATION__)
	{
		super(msg, location);
	}
}

/*!
 * Thrown by the UTF code upon a malformed UTF-8 string.
 */
class MalformedUTF8Exception : Exception
{
	/*!
	 * Construct a `MalformedUTF8Exception` object.
	 *
	 * @Param msg A message describing the error.
	 * @Param location Where this was thrown from.
	 */
	this(msg: string = "malformed UTF-8 stream",
	     location: string = __LOCATION__)
	{
		super(msg, location);
	}
}

/*!
 * Thrown on an AA lookup failure.
 */
class KeyNotFoundException : Exception
{
	/*!
	 * Construct a `KeyNotFoundException` object.
	 *
	 * @Param msg A message describing the error.
	 */
	this(msg: string)
	{
		super(msg);
	}
}
