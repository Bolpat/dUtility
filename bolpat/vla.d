// The MIT License (MIT)
//
// Copyright (c) 2016 Q. F. Schroll

module bolpat.vla;

import std.array : replace;

/**
 * Usage:
 *  ---
 *  import core.stdc.stdlib : alloca;
 *  size_t n;
 *  readf("%s", &n);
 *  auto ar = mixin(VLA!(double, n));
 *  ---
 *  Important: n must be a local variable, but is given as an alias.
 *  It must not be an expression other than a single variable name.
 */
enum VLA(T, alias n) = "(cast(<Type>*) alloca(<size> * <Type>.sizeof))[0 .. <size>]"
    .replace("<Type>", T.stringof)  // On purpose, something that is not a valid type.
    .replace("<size>", n.stringof); // On purpose, something that is not a valid alias.