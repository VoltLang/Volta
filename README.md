# Volt

[![Join the chat at https://gitter.im/VoltLang/VoltLang](https://badges.gitter.im/VoltLang/VoltLang.svg)](https://gitter.im/VoltLang/VoltLang?utm_source=badge&utm_medium=badge&utm_campaign=pr-badge&utm_content=badge)

Volt is a systems level programming language, that aims to be safe by default but
still allowing you access to nitty gritty low level details. All of
the code in [Volta], [Watt] and other official Volt repos are under the
`BOOST (ver. 1.0) license` except for bindings, those are licenced under their
original license. For instance, [LLVM], which is used by Volta to
generate code.

## Volta

Volta is the compiler for the language. This repo also contains the runtime,
code needed to support language features. The runtime is not the standard library,
which is code that supports software development in general. That can be found
in the [Watt](https://github.com/VoltLang/Watt) repository.

## Documentation

You can find a getting started guide
[here](http://docs.volt-lang.org/doc/tvpl/c2-setup.html), information about the
language [here](http://docs.volt-lang.org/doc/tvpl/c1-intro.html) and [here](http://docs.volt-lang.org/doc/volt.html). An overview of the
compiler [here](http://docs.volt-lang.org/doc/overview.html). An index of
the documentation exists [here](http://docs.volt-lang.org/). And if you are brave
you can try out the experimental [Volt Guru](http://volt.guru) page.

## Contributing

Please feel free to contribute. Contributing is easy! Just send us your code.
Diffs are appreciated, in git format; GitHub pull requests are excellent.

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
