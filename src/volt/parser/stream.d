// Copyright © 2015, Jakob Bornecrantz.  All rights reserved.
// See copyright notice in src/volt/license.d (BOOST ver. 1.0).
module volt.parser.stream;

import volt.token.token : Token;
import volt.token.stream : TokenStream;

class ParserStream : TokenStream
{
	this(Token[] tokens)
	{
		super(tokens);
	}
}
