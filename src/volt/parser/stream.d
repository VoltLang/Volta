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
