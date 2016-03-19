// Written in the D programming language.
//
// The MIT License (MIT)
//
// Copyright (c) 2016 Q. F. Schroll


module bolpat.staticarray;

/**
 * Like std.algorithm.iteration.map but for static arrays.
 */
template map(fun...)
if (fun.length > 0 )
{
    import std.meta : staticMap;
    import std.functional : adjoin;
    import std.functional : unaryFun;

    alias f = adjoin!(staticMap!(unaryFun, fun));

    auto map(T, size_t dim)(T[dim] r)
    {
        pragma (inline, true);

        import std.range : iota;
        import std.format : format;

        enum error = fun.length > 1
            ? "All mapping functions must not return void."
            : "Mapping function must not return void.";
        foreach (func; fun)
            static assert (!is (typeof (func(T.init)) == void), error);

        alias R = typeof (f(T.init));

        return cast(R[dim]) mixin (q{
            [ %( f(r[%d]) %| , %) ]
        }.format(dim.iota));
    }
}

///
@nogc @safe pure nothrow
unittest
{
    import std.typecons : Tuple, tuple;

    alias T = Tuple!(int, int);

    int[4] i4 = [ 1, 2, 3, 4 ];

    auto x = i4.map!(a => a*a);
    auto y = i4.map!(`a*a`, `1+2*a`);
    auto z = i4.map!(a => a*a, a => 1+2*a);

    int[4] x2 = [ 1, 4, 9, 16 ];
    T[4] y2 = [ tuple(1, 3), tuple(4, 5), tuple(9, 7), tuple(16, 9) ];
    assert (x == x2);
    assert (y == y2);
    assert (z == y2);
}


/// [ x[0], ..., x[n] ].reduce!f == x[0].f(x[1]).f(x[2]) ... .f(x[n])
/// == f(... f(f(x[0], x[1]), x[2]) ..., x[n])
template reduce(alias fun)
{
    import std.functional : binaryFun;

    alias f = binaryFun!fun;

    auto reduce(T, size_t dim)(T[dim] r)
    {
        pragma (inline, true);

        static assert (dim > 0, "Length of the static array must be nonzero.");

        static string code(size_t dim)
        {
            import std.format : format;
            string r = `r[0]`;
            foreach (i; 1 .. dim) r = `f(`~r~`,r[%d])`.format(i);
            return r;
        }
        return mixin (code(dim));
    }
}

///
@nogc @safe nothrow pure
unittest
{
    int[3] t = [ 1, 5, 9 ];
    auto s = t.reduce!`a+b`;
    auto p = t.reduce!`a*b`;

    assert (s == 1 + 5 + 9);
    assert (p == 1 * 5 * 9);
}

@nogc @safe nothrow pure
unittest
{
    import std.meta : AliasSeq;
    alias x = AliasSeq!(1, 2, 3);
    auto s = [ x ].reduce!`a+b`;
    assert (s == 6);
}

@nogc @safe nothrow pure
unittest
{
    int[3] t = [ 1, 5, 9 ];
    auto x = t.map!`a*a`.reduce!`a+b`;
    assert (x == 1*1 + 5*5 + 9*9);
}
