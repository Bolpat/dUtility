// Written in the D programming language.
//
// The MIT License (MIT)
//
// Copyright (c) 2016 Q. F. Schroll


module bolpat.implicit;


import std.traits : isCallable, Parameters;

/// pointwiseApply!(f, g1, ..., gn)(x1, ..., xn) returns f(g1(x1), ..., gn(xn))
template pointwiseApply(alias f, fun...)
if (isCallable!f)
{
    auto pointwiseApply(Args...)(Args args)
    if (Args.length == fun.length)
    {
        pragma (inline, true);

        import std.range : iota;
        import std.algorithm.iteration : map;
        import std.format : format;
        import std.array : join;

        enum newArgs = fun.length.iota.map!(
            i => q{
                fun[ %d ](args[ %d ])
            }.format(i, i)
        ).join(',');

        return mixin (`f(`~newArgs~`)`);
    }
}

///
unittest
{
    struct X { int i; }
    struct Y { int j; }
    auto plus(X x, Y y) { return x.i + y.j; }

    auto three = pointwiseApply!(plus, X, Y)(1, 2);
    assert (three == 3);
}


// Only works for structs.
// alias implicit(alias f) = pointwiseApply!(f, Parameters!f);

import std.meta : staticMap;
import std.conv : to;

/// Call f with implicit casting to the parameter type.
alias implicit(alias f) = pointwiseApply!(f, staticMap!(to, Parameters!f));

///
unittest
{
    struct X { int i; }
    struct Y { int j; }
    alias plus = (X x, Y y) => x.i + y.j;

    assert (!__traits(compiles, plus(1, 2)));

    alias plusXY = implicit!plus;
    auto three = plusXY(1, 2);
    assert (three == 3);
}

///
unittest
{
    struct Z
    {
        int k;
        int opCast(T : int)() { return k; }
    }
    Z z = Z(1);

    alias plus = (int k, int j) => k + j;

    assert (!__traits(compiles, plus(z, 2)));

    alias plusZ = implicit!plus;
    auto three = plusZ(z, 2);
    assert (three == 3);
}
