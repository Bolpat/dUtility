// Written in the D programming language.
//
// The MIT License (MIT)
//
// Copyright (c) 2016 Q. F. Schroll


module bolpat.staticarray;


/// Supplys interpretation of an array literal as a static array without supplying
/// the type or length via cast(T[dim]) <literal>.
auto makestatic(T, size_t dim)(T[dim] array)
{
    pragma (inline, true);
    return array;
}

///
@nogc @safe pure nothrow
unittest
{
    auto x = [ 1, 2 ].makestatic;
    assert (is (typeof(x) == int[2]));
}

///
@safe pure nothrow
unittest
{
    auto x = [ 1, 2 ];
    assert (is (typeof(x) == int[]));
}

import bolpat.meta : Iota;

/// Returns a static array with ascending or descending elements.
enum staticiota(int end) = staticiota!(0, end);
///
enum staticiota(int start, int end, int step = 1) = [ Iota!(start, end, step) ];

///
@nogc @safe pure nothrow
unittest
{
    int[4] a = staticiota!4;
    int[4] b = [ 0, 1, 2, 3 ];
    assert (a == b);

    a = staticiota!(1, 5);
    b = [ 1, 2, 3, 4 ];
    assert (a == b);
}

/// Returns a slice of a static array. The bounds must be known at compile time.
/// Negative values for u make usage like $-u.
auto staticslice(size_t l, ptrdiff_t u, T, size_t dim)(T[dim] r)
{
    import std.range : iota;
    import std.format : format;
    static if (u <= 0 && l > 0)
        return mixin (q{ [ %( r[%d] %| , %) ] }.format(iota(l, dim + u))).makestatic;
    else
        return mixin (q{ [ %( r[%d] %| , %) ] }.format(iota(l, u))).makestatic;
}

///
@nogc @safe pure nothrow
unittest
{
    assert ([ 1, 4, 9, 16 ].staticslice!(1, 3) == [ 4, 9 ]);
    auto x = [ 1 ].staticslice!(0, 0);
}

/// Returns a static array that is a selection of elements of the given static array
/// chosen by another static array which contains the indices to select.
auto staticselect(T, size_t dim, size_t idim)(T[dim] r, size_t[idim] i)
{
    import std.range : iota;
    import std.format : format;
    return mixin (q{ [ %( r[i[%d]] %| , %) ] }.format(i.length.iota)).makestatic;
}

///
@nogc @safe pure nothrow
unittest
{
    assert ([ 1, 4, 9, 16 ].staticselect([ 2, 3, 1 ]) == [ 9, 16, 4 ]);
}

/**
 * Like std.algorithm.iteration.map but for static arrays.
 */
template staticmap(fun...)
if (fun.length > 0 )
{
    import std.meta : staticMap;
    import std.functional : adjoin;
    import std.functional : unaryFun;

    alias f = adjoin!(staticMap!(unaryFun, fun));

    auto staticmap(T, size_t dim)(T[dim] r)
    {
        pragma (inline, true);

        import std.range : iota;
        import std.format : format;

        enum error = fun.length > 1
            ? "All mapping functions must not return void."
            : "Mapping function must not return void.";
        static if (dim > 0)
            static assert (!is (T == void), "T must not be void unless dim == 0.");
        foreach (func; fun)
            static assert (!is (typeof (func(T.init)) == void), error);

        return mixin (q{
                [ %( f(r[%d]) %| , %) ]
            }.format(dim.iota)).makestatic;
    }
}

///
@nogc @safe pure nothrow
unittest
{
    import std.typecons : Tuple, tuple;

    alias T = Tuple!(int, int);

    int[4] i4 = [ 1, 2, 3, 4 ];

    auto x = i4.staticmap!(a => a*a);
    auto y = i4.staticmap!(`a*a`, `1+2*a`);
    auto z = i4.staticmap!(a => a*a, a => 1+2*a);

    int[4] x2 = [ 1, 4, 9, 16 ];
    T[4] y2 = [ tuple(1, 3), tuple(4, 5), tuple(9, 7), tuple(16, 9) ];
    assert (x == x2);
    assert (y == y2);
    assert (z == y2);
}


/** Like std.algorithm.iteration.reduce but for static arrays.
 *  [ x[0], ..., x[n] ].staticreduce!f == x[0].f(x[1]).f(x[2]) ... .f(x[n])
 *  == f(... f(f(x[0], x[1]), x[2]) ..., x[n])
 */
template staticreduce(alias fun)
{
    import std.functional : binaryFun;

    alias f = binaryFun!fun;
    /+ // does not work. bug?
    string code(bool neutral)()
    {
        import std.format : format;
        static if (neutral)
        {
            string opt = ", T e";
            string check = "true";
            string neutral = "e";
            string first = "0";
        }
        else
        {
            string opt = "";
            string check = "dim > 0";
            string neutral = "r[0]";
            string first = "1";
        }
        return q{
            auto staticreduce(T, size_t dim)(T[dim] r %s) // opt
            if (%s) // check
            {
                pragma (inline, true);

                static string result(size_t dim)
                {
                    import std.format : format;
                    string r = `%s`; // neutral
                    foreach (i; %s .. dim) // first
                        r = `f(%%s, r[%%d])`.format(r, i);
                    return r;
                }
                return mixin (result(dim));
            }
        }.format(opt, check, neutral, first);
    }

    mixin (code!false);
    mixin (code!true);
    +/
    auto staticreduce(T, size_t dim)(T[dim] r)
    if (dim > 0)
    {
        pragma (inline, true);

        static string result(size_t dim)
        {
            import std.format : format;
            string r = `r[0]`;
            foreach (i; 1 .. dim)
                r = `f(%s, r[%d])`.format(r, i);
            return r;
        }
        return mixin (result(dim));
    }
    
    auto staticreduce(T, size_t dim, E)(T[dim] r, E e)
    {
        pragma (inline, true);

        static string result(size_t dim)
        {
            import std.format : format;
            string r = `e`;
            foreach (i; 0 .. dim)
                r = `f(%s, r[%d])`.format(r, i);
            return r;
        }
        return mixin (result(dim));
    }
}

///
@nogc @safe nothrow pure
unittest
{
    int[3] t = [ 3, 5, 9 ];
    auto s = t.staticreduce!`a+b`;
    auto p = t.staticreduce!`a*b`;

    assert (s == 3 + 5 + 9);
    assert (p == 3 * 5 * 9);

    s = t.staticreduce!`a+b`(1);
    p = t.staticreduce!`a*b`(2);
    assert (s == 1 + 3 + 5 + 9);
    assert (p == 2 * 3 * 5 * 9);
    
    void[0] v;
    auto x = v.staticreduce!`a+b`(1);
    auto y = v.staticreduce!`a*b`(2);
    assert (x == 1);
    assert (y == 2);
}

@nogc @safe nothrow pure
unittest
{
    import std.meta : AliasSeq;
    alias x = AliasSeq!(1, 2, 3);
    auto s = [ x ].staticreduce!`a+b`;
    assert (s == 6);
}

@nogc @safe nothrow pure
unittest
{
    int[3] t = [ 1, 5, 9 ];
    auto x = t.staticmap!`a*a`.staticreduce!`a+b`;
    assert (x == 1*1 + 5*5 + 9*9);
}

auto staticmax(T, size_t n)(T[n] arg) // rvalue
{
    return staticmax(arg);
}

auto staticmax(T, size_t n)(ref T[n] arg) // lvalue
{
    import std.algorithm : max;
    import std.range : iota;
    import std.format;
    return mixin("max( %(arg[%s]%|, %) )".format(iota(n)));
}

auto staticmin(T, size_t n)(T[n] arg) // rvalue
{
    return staticmax(arg);
}

auto staticmin(T, size_t n)(ref T[n] arg) // lvalue
{
    import std.algorithm : min;
    import std.range : iota;
    import std.format;
    return mixin("min( %(arg[%s]%|, %) )".format(iota(n)));
}

template staticZipWith(fun...)
{
    import std.meta : allSatisfy, staticMap;
    import std.traits : isStaticArray;

    auto staticZipWith(Arrays...)(Arrays arrays)
    if (Arrays.length > 0 && allSatisfy!(isStaticArray, Arrays))
    {
        import std.functional : adjoin, unaryFun, binaryFun;

        foreach (i, _; arrays[1 .. $])
            static assert (arrays[i].length == arrays[i+1].length,
                "All arrays must have equal lengths.");

             static if (Arrays.length == 1) alias f = adjoin!(staticMap!(unaryFun,  fun));
        else static if (Arrays.length == 2) alias f = adjoin!(staticMap!(binaryFun, fun));
        else                                alias f = adjoin!fun;

        /+ code(m+1, n+1) returns  (m arrays with n entrys each)
        [
            f(arrays[0][0], .., arrays[m][0]),
                :           ·.    :
            f(arrays[0][n], .., arrays[m][n])
        ]
        +/
        static string code(size_t m, size_t n)
        {
            import std.format : format;

            string result = `[`;
            foreach (j; 0 .. n)
            {
                result ~= `f(`;
                foreach (i; 0 .. m)
                    result ~= `arrays[%d][%d],`.format(i, j);
                result ~= `),`;
            }
            return result ~ `]`;
        }
        return mixin (code(arrays.length, arrays[0].length)).makestatic;
    }
}

///
@nogc @safe nothrow pure
unittest
{
    auto names = [ "Anton", "Berta", "Caesar", "Dietmar" ].makestatic;
    auto idcs  = [ 2, 1, 3, 3 ].makestatic;
    auto test1 = staticZipWith!"a[b]"(names, idcs);
    assert (test1 == "test");

    auto test2 = staticZipWith!("a[b]", "a[b-1]")(names, idcs);
    foreach (i; 0 .. 4)
    {
        assert (test2[i][0] == names[i][idcs[i]]);
        assert (test2[i][1] == names[i][idcs[i]-1]);
    }
}