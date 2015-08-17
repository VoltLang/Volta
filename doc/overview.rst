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

Parsing
-------

Once you've got that in mind, the parser is pretty simple. It looks at the next token, determines what needs to be parsed, then generates the IR node needed, while consuming tokens, until it finds an error or runs out of source code.

Semantic
========

So now we have one or more ir.Modules from the parser corresponding to the source files we were given. The backend works on these modules too, but they're not ready for that yet. The backend only works on a subset of the IR tree (see the IRVerifier for details), so the semantic phase massages the IR into an appropriate shape.

Essentially, the semantic phase makes the IR a lot more verbose. ``auto i = 3;``` will become ``int i; i = 3;``. Your fancy ``foreach`` statements will be lowered into simple ``for`` statements. The backend only knows how to generate top level functions, so methods and inline functions need to be hoisted to top level functions, with their context becoming structs.

Also, in theory, the IR should be verified sound by the time the semantic phase is done with it. No errors (in the user's code) should be detected in the backend. For example, the backend shouldn't need to check that ``cast(int) var;`` is safe or sound -- it will assume it is.

So as you can imagine, all of the above is a fair amount of work, and doing it in one giant nest of functions is out of the question. All the transformations are broken into passes. A ``Pass`` is a simple interface. It has a method ``transform`` that takes a module, and a method ``close`` that takes no arguments, for cleaning up.

Visitor
-------

It's probably obvious, but these passes are going to spend a lot of time traversing the IR tree looking at things. The visitor code implements a visitor pattern for visiting the Volt IR, so the passes can inherit from the Visitor interface (or usually, the NullVisitor object -- an implementation of Visitor that does nothing for each node), and then call accept on themselves to traverse the tree.

Passes
------

The passes work like a pipeline. They're run one after the other, on the same module, and each subsequent pass works on the result of the prior. So every pass after the conditional removal pass can assume they'll not see a static if or version block. Speaking of which, let's briefly go over the passes. Some are more significant than others.

ConditionalRemoval
------------------
This pass evaluates version blocks, debug blocks, static ifs and the like, and removes blocks of code that need to be removed. Most of the code in this pass is concerned with the pruning of the tree, and making sure it still looks sane afterwards.


ScopeReplacer
-------------

Takes the scope (exit/success/failure) blocks from functions, turns them into inline function, and adds a reference to the new function to a list on the parent Function object.

AttribRemoval
-------------

Attributes are those flags that work on top level blocks, that you can place colons after. ``public``, ``private``, ``extern``, etc. This pass works out what nodes which attributes apply to, and turns them into appropriate fields -- Functions will have their access and linkage fields set, and so on.

Gatherer
--------

The gatherer creates scopes on things and then adds variables to the correct scope. 

ExTyper
-------

The most complex pass of the semantic phase. Short for 'explicit typer', the ExTyper does what it needs to do to ensure everything is explicitly typed. auto variables will be inferred afterwards, implicit casts (say ``int`` to ``long``) will have explicit casts inserted. Foreach statements will become for statements, and so on.

CFGBuilder
----------

The CFGBuilder builds a Control Flow Graph for each function, and uses it to determine if a return statement is missing, etc.

IRVerifier
----------

Ensures that the IR is in a state fit to be sent to the backend. This is run twice, once after the CFGBuilder, and then again just before the backend proper.

LlvmLowerer
-----------

Does the final run of lowering. Mostly turns syntax into explicit calls into runtime functions. That is to say, lowers the IR so that LLVM knows what to do with it.

NewReplacer
-----------

Similar to the LlvmLowerer, but just for ``new``. This is isn't just bundled elsewhere because the ``new`` operator does a lot of things, so it justifies having its own pass.

TypeidReplacer
--------------

Replaces ``typeid`` expressions with code that will create ``TypeInfo`` instances as appropriate.

MangleWriter
------------

Goes over everything in the IR tree and 'mangles' it. Mangling is the process of generating a name for a type or function that won't clash with things with the same name for whatever reason -- so the linker can discern overloaded functions, types in different modules with the same name, and so on.

