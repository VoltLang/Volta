A brief overview of Volt's mangling. For more information on what mangling is, and why it is done, you can read more [on Wikipedia](https://en.wikipedia.org/wiki/Name_mangling).

The things that are mangled are things that are exported and end up in object files. The very beginning of the mangled string will tell you what kind of object the mangle is identifying.

	Vv - a mangled variable.
	Vf - a mangled function.

Following that, the object's name is mangled. Names are mangled with a number, that many characters following the number, then a number following that, and so on, until the name is completely represented. Note that the name is *fully qualified*, so module names and the like are included.

So a function `foo` in a module `test`'s name would be mangled as `4test3foo`.

After the object's name, its type is mangled. The type is turned into a series of characters, of which an overview is shown below. For example, the type `const(i32*)` would be mangled as `opi`.

	a T[] ; at$NUMBER = T[$NUMBER]
	b i8
	c C linkage ; char
	d dchar
	e scope(T)
	f fd = f64 ; ff = f32 ; fr = real
	g
	h
	i i32
	j
	k
	l i64
	m immutable(T)
	n
	o const(T)
	p T*
	q
	r ref
	s i16
	t <static array (see a)>
	u ub = u8 ; us = u16 ; ui = u32; ul = u64
	v Volt linkage ; void
	w wchar
	x
	y
	z
	A Aa = AA
	B bool
	C class ; C++ linkage
	D delegate ; D linkage
	E enum
	F function
	G
	H
	I interface
	J
	K
	L
	M MF = method
	N
	O out
	P Pascal linkage
	Q
	R
	S struct
	T
	U
	V
	W Windows linkage
	X
	Y
	Z non-variadic

For user types like structs and classes, they're mangled by first inserting the appropriate letter (see the above table) and then their name is mangled afterwards.

Associative arrays are mangled `Aa$KEY$VALUE` so the type `bool*[i32]` would be mangled `AaipB`.

Functions are mangled by starting with F, MF, or D, (for function, method, and delegate, respectively), a linkage letter (see the linkages in the above table), then the parameter types one by one (if there are any ref or out parameters, they are preceded by `r` or `O`). The letter `Z` marks the end of the parameters, then the return value is given.

That might be a lot to take in, so here's an example. Say the following function is in a module called 'test'.

	fn func(ref i: i32) {}

Then the matching mangle would be

	Vf4test4funcFvriZv

The `Vf` tells us it's a function, then the full name is given, the `F` tells us it's a function. `v` tells us it's using Volt linkage (instead of, say, C). `ri` says the first parameter is an `i32` that's declared with `ref`. `Z` says the parameter section is ending, and `v` says the return type is `void`.