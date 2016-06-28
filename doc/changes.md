## `do` without `while` ##

`do` statements can omit the *while* clause, in which case this:

```d
do {...};
```

is equivalent to this:

```d
do {
    ...
    break;
} while(true);
```

This gives us a lightweight syntax supporting both *breakable* and
*restartable* blocks, where the loop is broken or restarted between two
statements within the block.

Examples:

```d
do {
    ...
    if (skip) break; // early exit
    ...
};
```

```d
// Infinite loop
do {
    ...
    continue;
};
```

Note that `do {...}; while (cond);` (which has an unintentional semi-colon
before `while`) will not compile as the *while* statement has an empty loop
statement.