# Volt

Volt is a systems level programing, that aims to be safe by default but still
allowing you access to the nitty gritty low level details. Pretty much all of
the code in [Volta], [Watt] and other official Volt repos are under the
`BOOST (ver. 1.0) license`. Except for bindings that are licensed under the origanl
license of the project, like [LLVM] which is used by Volta to produce the
binaries.

## Volta

Is the compiler for the language. This repo also contains the small runtime,
needed to implement the language. But not the standard library.

## Documentation

You can find getting started guide
[here](http://www.volt-lang.org/doc/setup/volta.html), information about the
language [here](http://www.volt-lang.org/doc/volt.html) and a overview of the
compiler [here](http://www.volt-lang.org/doc/overview.html). A index of
documentation can be found [here](http://www.volt-lang.org/doc/).

## Contributing

Please feel free to contribute. Contributing is easy! Just send us your code.
Diffs are appreciated, in git format; Github pull requests are excellent.

Things to consider:

* The parser, runtime and standard library is under the BOOST license. Your
  contributions to any of these parts will be under that same license. If this
  isn't acceptable, then your code cannot be merged. This is really the only
  hard condition.
* That was short wasn't it? Just remember don't be a dick, have fun and there
  will be cake! That is all!

[Watt]: https://github.com/VoltLang/Watt
[LLVM]: http://llvm.org
[Volt]: http://www.volt-lang.org
[Volta]: https://github.com/VoltLang/Volta
