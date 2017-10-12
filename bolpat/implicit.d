// Written in the D programming language.
//
// The MIT License (MIT)
//
// Copyright (c) 2016 Q. F. Schroll


module bolpat.implicit;


/**
 * Takes an alias to a function `Z f(Y...)` and a list of functions
 * `Y[i] g(X[i])` and returns a function `Z h(X...)` that is `f` applied to the `g[i](x[i])`.
 *
 * Returns: `compose!(f, g[0], ..., g[$-1])(x[0], ..., x[$-1])` is `f(g[0](x[0]), ..., g[$-1](x[$-1]))`
 */
template compose(alias f, g...)
/+if (isCallable!f && allSatisfy!(isCallable, g))+/
{
    // Note: Cannot enforce callable as f may be a template.
    //       Then isCallable fails to recognize instanciated f
    //       can be called!
    auto compose(X...)(auto ref X args)
    if (X.length == g.length)
    {
        pragma (inline, true);

        import std.range : iota;
        import std.algorithm : map;
        import std.format : format;
        import std.array : join;

        enum newArgs = X.length.iota.map!(
            i => q{
                g[ %1$s ](args[ %1$s ])
            }.format(i)
        );

        return mixin(`f(` ~ newArgs.join(',') ~ `)`);
    }
}

///
pure nothrow @safe @nogc unittest
{
    alias plus = (a, b) => a + b;
    alias inc = x => x + 1;
    alias dbl = x => x * 2;

    assert(compose!(plus, inc, dbl)(0, 1) == (0 + 1) + (1 * 2));
}


private template create(T)
{
    ref T create(return ref T arg)
    {
        return arg;
    }

    auto ref T create(Arg)(auto ref Arg arg)
    {
        pragma (inline, true);

        import std.traits : isImplicitlyConvertible;
        static if (isImplicitlyConvertible!(Arg, T))
            return arg;
        else static if (is(T == struct) || is(T == union))
            return T(arg);
        else static if (is(T == class))
            return new T(arg);
        else static if (is(typeof({ T result = cast(T)arg; })))
            return cast(T)arg;
    }
}

import std.traits : Parameters;
import std.meta : staticMap;

// Only works if all parameters of f are structs:
// private alias implicitConstruct(alias f) = compose!(f, Parameters!f);

/**
 * Call `f` with implicit casting to the parameter types.
 *
 * For each parameter, the generated function template tries to cast to the
 * parameter type. If the types match or `alias this` can be used, nothing happens
 * and the parameters can even be ref.
 * If the parameter type is a struct or union or class, it tries a 1-parameter
 * constructor. If this fails or the type is not a struct/union/class, it tries
 * `cast(ParamT)`.
 */
alias implicit(alias f) = compose!(f, staticMap!(create, Parameters!f));

///
pure nothrow @safe @nogc unittest
{
    // On same type (parameters can be ref) //

    ref addTo(ref int i, int j) pure nothrow @safe @nogc
    {
        return i += j;
    }

    int x = 0;
    addTo(x, 1) += 2; // lvalue result!
    assert (x == 3);

    implicit!addTo(x, 1);
    assert (x == 4);  // implicit: reference is changed

    // implicit: first parameter need not bind on ref
    assert(implicit!addTo(3, 4) == 7);
    // but result is no more ref:
    static assert(!__traits(compiles,
        implicit!addTo(x, 1) += 2
    ));
}

///
pure nothrow @safe @nogc unittest
{
    // On alias this (parameters can be ref) //

    ref addTo(ref int i, int j) pure nothrow @safe @nogc
    {
        return i += j;
    }

    struct S
    {
        int value;
        alias value this;
    }

    auto x = S(0);
    addTo(x, 1) += 2; // lvalue result!
    assert (x == 3);

    implicit!addTo(x, 1);
    assert (x == 4);  // implicit: reference is changed

    // implicit: first parameter need not bind on ref
    assert(implicit!addTo(3, 4) == 7);
    // but result is no more ref:
    static assert(!__traits(compiles,
        implicit!addTo(x, 1) += 2
    ));
}

///
pure nothrow @safe @nogc unittest
{
    // Try struct/union/class constuctors //

    struct X { int i; }
    struct Y { int j; }
    alias plus = (X x, Y y) => x.i + y.j;

    static assert(!__traits(compiles,
        plus(1, 2)
    ));

    assert(implicit!plus(1, 2) == 3);
}

///
pure nothrow @safe @nogc unittest
{
    // Try opCast //

    struct S
    {
        int value;
     // alias value this;
        int opCast(T : int)() { return value; }
    }
    auto s = S(1);

    alias plus = (int k, int j) => k + j;

    assert (!__traits(compiles,
        plus(s, 2)
    ));

    assert (implicit!plus(s, 2) == 3);
}

///
pure nothrow @safe /+!@nogc+/ unittest
{
    // toString does not suffice //

    struct S
    {
        string toString() { return "I'm an S!"; }
    }
    void func(string s) { }

    S s;
    static assert(!__traits(compiles,
        func(s)
    ));

    // toString is not considered for implicit conversion
    static assert(!__traits(compiles,
        implicit!func(s)
    ));
}