---
layout: page
---

Comparing Volt and D
---

This is the third in a series of documents that points out differences between Volt and other popular languages, so as to aid programmers coming to Volt from them. [The first](volt-vs-c.html) dealt with C. [The second](volt-vs-cpp.html) with C++. The bootstrap version of Volta, the compiler, is written in D. It's no surprise then, that Volt has taken inspiration from it. But of course, it has different ideas on how to do somethings too. The basic syntax changes that have been covered before will not be retreaded here; be sure to read them to get the full picture.

Coming Soon
---

Things that Volt will have, but not in the initial release:
* Templates
* Intrinsics
* Imports in non top-level scopes.

What's Different
---

In Volt, **version** statement condition can be or'd and'd, and not'd together:

	version (A || B && !C)
	
Types
---

In addition to the type syntax being different as documented in the [C comparison](volt-vs-c.html), a subtle point is that the calling convention (CC) of a function pointer can be an explicit part of the type, not just inferred from what `extern` block it's in, if any (this means that you can explicitly mark something as a native CC, instead of just a "not C" CC):

	alias func1 = fn!C(i32) i32;  // Pointer to a function that returns an integer and takes an integer with a C CC.
	alias func2 = fn!Volt(i32) i32;  // Same as above, but with a Volt CC.

TypeInfo
---

To get the **size** of a type, first get the `TypeInfo` instance for that type using the `typeid` expression:

	typeid(T).size

`typeid` returns an instance of the following type, defined in the runtime in the `core.typeinfo` module:

	class TypeInfo
	{
		size: size_t;  // Size of the type in bytes.
		type: int;  // What is this type, see the core.typeinfo.Type enum for values.
		mangledName: char[];  // The exported name after mangling (if any).
		mutableIndirection: bool;  // Can memory (other than itself) be modified through an instance of this type?
		classInit: void*;
		classSize: size_t;
		base: TypeInfo;  // For arrays (dynamic and static), and pointers.
		staticArrayLength: size_t;
		key, value: TypeInfo;  // For AAs.
		ret: TypeInfo;  // For functions and delegates.
		args: TypeInfo[];  // For functions and delegates.
	}
