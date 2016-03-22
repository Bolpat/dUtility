// Written in the D programming language.
//
// The MIT License (MIT)
//
// Copyright (c) 2016 Q. F. Schroll


/++
 + Provides the Structs Dollar!i and Slice!i to represent $ used in the index operator.
 + The Dollar is for having the information that the dollar sign is being used; this
 + information however is lost when using the dollar in higher expression as in $-1 or $/2.
 + A Slice can be constructed from lower and upper bound and from single values and Dollar
 + which behave differently. The Slice has a length property.
 + The Dollar structure is especially created for the dollar slice, i.e. x[$] is a shortcut
 + for x[0 .. $] as the first does not make sense for other reasons.
 +
 + Provides the flatten function that returns a Voldemort range of a jagged array that iterates
 + through the elements of the given step.
 +/
module bolpat.indexing;


import bolpat.meta : AliasSeq, staticMap, Iota, Iterate;

/// Returned by opDollar.
struct Dollar(size_t i)
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

    // Cast constructors
    this(Dollar!i d) pure nothrow { this(  0,   d); }
    this(size_t   v) pure nothrow { this(  v, v+1); }
    this(Slice!i  s) pure nothrow { this(s.l, s.u); }
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
            return Dollar!i(i);
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

/+ TODO: Test!
/// Supplies a trivial implementation of opDollar with a function parameter
/// that tells how to get the length from the index i.
mixin template opDollar(alias fun)
{
    Dollar!i opDollar(size_t i)() @property
    {
        import std.functional : unaryFun;
        return unaryFun!fun(i);
    }
}

/// Supplies a trivial implementation of opSlice
mixin template opSlice
{
    Slice!i opSlice(size_t i)(size_t l, size_t u)
    {
        return Slice!i(l, u);
    }
}
+/


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

// TODO: Write better unittest!
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

/+TODO: Discuss whether multiIndex[1, 1  ..  3, 4] is a desired syntax usage.
auto multiIndex(Dims...)(Dims end)
{
    return MultiIndex!(Dims.length)(end);
}

auto multiIndex(size_t d)(size_t[d] end)
{
    return MultiIndex!(d)(end);
}

auto multiIndex(size_t d)(size_t[d] start, size_t[d] end)
{
    return MultiIndex!(d)(start, end);
}
+/

struct multiIndex
{
    static auto opCall(Dims...)(Dims end)
    {
        return MultiIndex!(Dims.length)(end);
    }
    static auto opCall(size_t d)(size_t[d] end)
    {
        return MultiIndex!(d)(end);
    }
    static auto opCall(size_t d)(size_t[d] start, size_t[d] end)
    {
        return MultiIndex!(d)(start, end);
    }

    struct Slice { size_t l, u; }

    static Slice opSlice(size_t i)(size_t l, size_t u)
    {
        return Slice(l, u);
    }

    static auto opIndex(Args...)(Args args)
    if (Args.length % 2 != 0 && is (Args[$/2] == Slice))
    {
        return MultiIndex!(Args.length/2 + 1)(
            [ args[0 .. $/2], args[$/2].l ],
            [ args[$/2].u, args[$/2 + 1 .. $] ]);
    }
}

struct MultiIndex(size_t rk)
{
private:
    import bolpat.meta : Replicate;
    alias Dims = Replicate!(rk, size_t);

    immutable size_t[rk] start, end;
    Dims values;

    invariant
    {
        foreach (i, v; values)
            assert (start[i] <= v && v < end[i]);
    }

public:
    alias expand = values;


    // CONSTRUCTOR //

    this(size_t[rk] start, size_t[rk] end)
    {
        this.start = start;
        this.end   = end;
        foreach (i, ref v; values)
            v = start[i];
    }

    this(size_t[rk] end)
    {
        this(size_t[rk].init, end);
    }

    this(Dims end)
    {
        this( [ end ] );
    }


    // CASTING //

    bool opCast(T : bool)()
    {
        if ([ values ] == start) return false;
        return true;
    }

    bool opEquals(int i)
    in
    {
        assert (i == 0, "MultiIndex may only be value-compared with 0.");
    }
    body
    {
        return (i == 0) ^ cast(bool) this;
    }

    bool opEquals(MultiIndex m)
    {
        return this.opCmp(m) == 0;
    }

    int opCmp(MultiIndex m)
    in
    {
        assert (this.start == m.start);
        assert (this.end   == m.end  );
    }
    body
    {
        foreach (i, v; values)
        {
            if (v < m.values[i]) return -1;
            if (v > m.values[i]) return  1;
        }
        return 0;
    }

    ref MultiIndex opUnary(string op : "++")()
    {
        foreach_reverse (i, ref v; values)
            if (++v == end[i]) v = start[i];
            else               break;
        return this;
    }

    ref MultiIndex opUnary(string op : "--")()
    {
        foreach_reverse (i, ref v; values)
            if (v-- == start[i]) v = end[i]-1;
            else                 break;
        return this;
    }

    ref MultiIndex opOpAssign(string op)(size_t n)
    if (op == "+" || op == "-")
    {
        foreach (i; 0 .. n) mixin(op ~ op ~ `this;`);
        return this;
    }

    MultiIndex opBinary(string op)(size_t n) const
    if (op == "+" || op == "-")
    {
        auto temp = this;
        return mixin (`temp`~op~`= n`);
    }

    import std.format : FormatSpec, formatElement;

    void toString(DG, Char)(scope DG sink, FormatSpec!Char fmt = FormatSpec!char()) const
    {
        sink("(");
        static if (rk > 0)
        {
            sink.formatElement(values[0], fmt);
            foreach (v; values[1 .. $])
            {
                sink(",");
                sink.formatElement(v, fmt);
            }
        }
        sink(")");
    }

    string toString() const
    {
        import std.array : appender;

        auto app = appender!string();
        this.toString((const(char)[] chunk) => app ~= chunk);
        return app.data;
    }
}

// TODO: Write better unittest!
debug unittest
{
    import std.stdio;

    struct A
    {
        int a;

        int opIndex(size_t i, size_t j)
        {
            return a*i + j;
        }
    }

    auto a = A(10);
    auto i = multiIndex[1,1 .. 3,4];
    do
    {
        writefln("%s", a[i.expand]);
    }
    while (++i);
}
