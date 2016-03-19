// Written in the D programming language.
//
// The MIT License (MIT)
//
// Copyright (c) 2016 Q. F. Schroll


/++
 + Provides the Structs Dollr!i and Slice!i to represent $ used in the index operator.
 + The Dollr is for having the information that the dollar sign is being used; this
 + information however is lost when using the dollar in higher expression as in $-1 or $/2.
 + A Slice can be constructed from lower and upper bound and from single values and Dollr
 + which behave differently. The Slice has a length property.
 + The Dollr structure is especially created for the dollar slice, i.e. x[$] is a shortcut
 + for x[0 .. $] as the first does not make sense for other reasons.
 +
 + Provides the flatten function that returns a Voldemort range of a jagged array that iterates
 + through the elements of the given step.
 +/
module bolpat.indexing;


import bolpat.meta : AliasSeq, staticMap, Iota, Iterate;

/// Returned by opDollar.
struct Dollr(size_t i)
{
    size_t value;
    alias value this;
}

/// Returned by opSlice.
struct Slice(size_t i)
{
    size_t l, u;
    size_t length() const pure nothrow @property
    {
        return u - l;
    }

    this(size_t l, size_t u) pure nothrow
    {
        this.l = l;
        this.u = u;
    }

    this(Dollr!i d) pure nothrow { this(  0,   d); }
    this(size_t  v) pure nothrow { this(  v, v+1); }
    this(Slice!i s) pure nothrow { this(s.l, s.u); }
}

/// Returns Slice!0, Slice!1, ..., Slice!(n-1)
alias Slices(size_t n) = staticMap!(Slice, Iota!n);

///
unittest
{
    static assert (is (Slices!3 == AliasSeq!(Slice!0, Slice!1, Slice!2)));
}

///
unittest
{
    import bolpat.implicit;

    struct Test(size_t rk)
    {
        auto opDollar(size_t i)()
        {
            return Dollr!i(i);
        }

        auto opSlice(size_t i)(size_t l, size_t u)
        {
            return Slice!i(l, u);
        }

        auto opIndex(Args...)(Args args)
        {
            auto index(Slices!rk ss)
            {
                int result = 0;
                foreach (s; ss) result += s.u;
                return result;
            }
            return implicit!index(args);
        }
    }

    Test!3 t;
    auto r = t[3, $, 2 .. 4];
    assert (r == 4 + 1 + 4);
}


/// Enables flattened view of a jagged array.
auto flatten(size_t rk, Ar)(Ar r0)
    if (rk > 0)
{
    import std.range : ElementType;
    alias T = Iterate!(ElementType, rk, Ar);

    struct Result
    {
        import std.range : iota;
        import std.format : format;
        import std.algorithm.iteration : map;
        import std.array : join;

        size_t totalLength() pure @safe
        {
            enum r = rk - 1;
            enum foreachs = r.iota.map!(
                i => q{
                    foreach (r%d; r%d)
                }.format(i + 1, i)
            ).join;

            size_t l = 0;
            mixin (foreachs ~ q{
            {
                mixin (q{ l += r%d.length; }.format(r));
            } });
            return l;
        }

        static string code(string name)()
        {
            static if (name == "opApply")
            {
                string loop = "foreach";
                string start = "0";
                string inc = "k++";
            }
            else static if (name == "opApplyReverse")
            {
                string loop = "foreach_reverse";
                string start = "totalLength";
                string inc = "--k";
            }
            else
                static assert (0, name ~ ": not Supported!");

            return q{
                // int opApply[Reverse](...)
                int %s(int delegate(size_t, ref T) dg)
                {
                    enum foreachs = rk.iota.map!(
                        i => q{
                            %s (ref r%%d; r%%d)  // foreach[_reverse] (ref r_(i+1); r_i)
                        }.format(i + 1, i)
                    ).join;

                    // k = 0  or  k = totalLength
                    size_t k = %s;
                    mixin (foreachs ~ q{
                    {
                        // auto result = dg(inc, r_rk)
                        if (auto result = mixin (q{ dg(%s, r%%d) }.format(rk)))
                            return result;
                    } });
                    return 0;
                }

                // int opApply[Reverse](...)
                int %s(int delegate(ref T) dg)
                {
                    auto f(size_t, ref T t) { return dg(t); }
                    // return opApply[Reverse](&f)
                    return %s(&f);
                }
            }.format(name, loop, start, inc, name, name);
        }

        mixin(code!"opApply");
        mixin(code!"opApplyReverse");
    }

    return Result();
}

///
unittest
{
    import std.conv : to;
    auto ar = new int[][](3, 2);

    foreach (i, ref a; ar.flatten!2)
    {
        a = i;
    }

    int result = 0;
    foreach (a; ar.flatten!2)
    {
        result += a;
    }
    assert (result == 15);

    int j = -1;
    result = 0;
    foreach_reverse (a; ar.flatten!2)
    {
        result += (j *= -1) * a;
    }
    assert (result == 3);

    result = 0;
    foreach_reverse (i, a; ar.flatten!2)
    {
        result += i * a;
    }
    assert (result == 55);
}

debug unittest
{
    import std.stdio;

    auto ar =
    [
        [ [1, 2], [3, 4], [5, 6] ],
        [ [2, 3], [4, 5], [6, 7] ],
        [ [3, 4], [5, 6], [7, 8] ],
        [ [4, 5], [6, 7], [8, 9] ]
    ];

    foreach (i, a; ar.flatten!1)
        writefln("%2s: %s", i, a);
    writeln;

    foreach (i, a; ar.flatten!2)
        writefln("%2s: %s", i, a);
    writeln;

    foreach (i, a; ar.flatten!3)
        writefln("%2s: %s", i, a);

    foreach_reverse (i, a; ar.flatten!1)
        writefln("%2s: %s", i, a);
    writeln;

    foreach_reverse (i, a; ar.flatten!2)
        writefln("%2s: %s", i, a);
    writeln;

    foreach_reverse (i, a; ar.flatten!3)
        writefln("%2s: %s", i, a);
}