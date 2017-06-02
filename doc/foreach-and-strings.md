---
layout: page
---

Foreach And Strings
---

"If you were to use the `foreach` statement to iterate over a `string`, what would happen?" To the novice, this may seem like a simple question. When we use `foreach` on, say, an `i32[]` variable, the element type is `i32`, and it goes over each element in the list one by one, with the index increasing by one every iteration. A `string` is an alias for `immutable(char)[]`, so foreach must use an element type of `char`, going over each character in the string. Right?

If `string` meant 'ASCII', you'd be right. However, a `string` is not 'ASCII'. In Volt, the string type is encoded as UTF-8. The readers that don't know what UTF-8 is, or what Unicode is, are strongly encouraged to read Joel Spolsky's classic article, [The Absolute Minimum Every Software Developer Absolutely, Positively Must Know About Unicode and Character Sets](http://www.joelonsoftware.com/articles/Unicode.html). If you work with computers in any capacity, the knowledge will be valuable to you.

Before we go on, I will note that this document is being written in October of 2016, and the Volta *compiler* is still a work in progress; not every case that we cover is implemented. Regardless, it is all true of the Volt *language*, and we can talk of that, implementation details be damned.

The Types
---

	char - one byte wide, a portion of a UTF-8 string.
	wchar - two bytes wide, a portion of a UTF-16 string.
	dchar = four bytes wide, a portion of a UTF-32 string.

And of course, their corresponding string types.

	string - a UTF-8 encoded string. Alias of immutable(char)[].
	wstring - a UTF-16 encoded string. Alias of immutable(wchar)[].
	dstring - a UTF-32 encoded string. Alias of immutable(dchar)[].

So. Given the following piece of code:

    str: string = "Hello, world.";
	foreach (c; str) {
		writefln("%s", c);
	}

The question becomes: what do we do? Do we treat it like any other array, byte 0 = 'H', byte 1 = 'e', etc? In a lot of cases, that would seem to be the "obvious thing", but consider the following:

	str: string = "こんにちは、世界";
	foreach (c; str) {
		writefln("%s", c)
	}

The Japanese *kana* and *kanji* of the above string are represented by three bytes each in UTF-8, so simple iteration wouldn't work. Volt's runtime has code for determing how much a given index has to be increased to get to the next character. So another option is to call those functions automatically. Works for both examples, problem solved, right?

Not quite. Firstly there's an issue of philosophy: Volt likes to avoid hidden code wherever possible, and not everyone would be expecting that behaviour. More practically, there are cases where programs would want to iterate over a UTF-8 string byte by byte, and forcing a `cast(u8[])` in this case isn't ideal.

The solution Volt has opted for is to make the programmer choose explicitly what behaviour they want. The above two code examples will generate an error, prompting you to explicitly choose the type of the iteration variable (that is, `c`).

    foreach (c: char; str)  - simple iteration
	
	foreach (c: dchar; str) - decode a UTF-8 character
	
	foreach_reverse (c: char; str) - simple backwards iteration
	
	foreach_reverse (c: dchar; str) - decode a UTF-8 character, starting from the last and going backwards.

The intent is that more people will be aware of the representation of their strings, and less people will be surprised by the behaviour of their code.
