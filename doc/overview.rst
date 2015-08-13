An Overview of the Compilation Process
======================================

The Volt compiler turns text files into object files, and can turn those object files into shared objects and executables. The latter is mostly handled by the linker (``gcc``, by default, but this can be changed by using the ``--linker`` flag). With that in mind, this document will be a bird's eye view of the former process; turning a source file into an object.

Driver
------

The driver looks at the command line and figures out what to do. It sets flags in a Settings object, and gets a list of files that it wants to compile. It then creates a VoltController object, passes it this information and tells it to compile.

The first important thing the controller does, is create a Parser object and tell it to parse the files.

Parser
======

The parser works on a list of objects called Tokens. This is easier to work with and reason about than working with the characters directly. So to that end, the lexer is called to turn the source into a list of tokens.

Lexer
-----

The lexing process is all-in-all fairly simple. A Source object is first created, and given the raw data from the source file. This object handles decoding characters, script lines, BOMs -- all that fun stuff. The lexer functions just read the next character, and generate a Token -- if they see a '1' they generate a number token, 'a' an identifier token, and so on.

This is all for the most part free standing functions, and should be easy enough to read and follow along. Now that we've got our tokens, the parser proper can begin. The parser turns the tokens into an Intermediate Representation Tree, the IR for short.

IR
--

The IR is an abstract representation of the source file. That is to say, where the tokens are a concrete representation -- the tokens match up to the characters in the source file, for the most part -- the IR is abstract; it encodes abstract concept. For example, "int a;" might be a list of tokens <int> <identifier:a> <semicolon>, but the IR would be closer to Variable(Type(Int), "a").

The parser is a recursive descent parser, and is handwritten. That is, it starts at ``parseModule``, the top-most IR node, and works its way down and gives you back an ir.Module with all your functions and variables and whatever attached to it.

All members of the IR tree are based on an ir.Node. Each node has a nodeType; an enum that tells you what member it is. A Location, that gives you the source filename, line number, and column number of where in the source file that IR node corresponds to. It also has an optional documentation comment attached in the docComment member, but that's not important right now.
