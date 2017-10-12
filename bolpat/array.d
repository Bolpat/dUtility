// Written in the D programming language.
//
// The MIT License (MIT)
//
// Copyright (c) 2016 Q. F. Schroll


module bolpat.array;


// Pseudo Slice without position argument. Used only in slices attribute.
private struct Dim
{
    size_t  l, u, d;
    
    this(size_t d) pure nothrow @nogc @safe
    {
        this(0, d, d);
    }

    this(size_t l, size_t u, size_t d) pure nothrow @nogc @safe
    {
        this.l = l;
        this.u = u;
        this.d = d;
    }
    
    pure nothrow @nogc @safe
    invariant
    {
        assert (l <= u);
        assert (u <= d);
    }

    size_t length() const pure nothrow @nogc @safe
    {
        return u - l;
    }
}

struct array(T)
{
    static opCall(Dim...)(Dim d)
    {
        return Array!(T, Dim.length)(d);
    }
    /+
    static opIndex(Dim...)(Dim d)
    {
        struct Result
        {
            auto opAssign(T delegate(Dim) dg)
            {
                return Array!(T, Dim.length)(d, dg);
            }
        }
        return Result();
    }
    +/
}

/// ditto
alias Array(T, size_t rk : 0) = T;

/// ditto
alias Array(T, size_t rk : 1) = T[];

/// ditto
struct Array(T, size_t rk)
if (rk > 1)
{
private:
    import bolpat.meta : Replicate;
    import bolpat.staticarray : staticreduce;
    import bolpat.indexing;

    alias Dims = Replicate!(rk, size_t);

    // Used when a delegate f is used to assign the data values.
    enum functionAssign =
    q{
        import std.range                : iota;
        import std.format               : format;
        import std.algorithm.iteration  : map;
        import std.array                : join;

        size_t k = 0;
        mixin
        (
            rk.iota.map!(
                j => q{
                //  foreach (i_j; 0 .. dims [ j ])
                    foreach (i%d; 0 .. dims[ %d ])
                }.format(j, j)
            ).join
            ~
            q{{ //         data[k++] = f( i_0, ... , i_r );
                mixin ( q{ data[k++] = f( %( i%d %| , %) ); }.format(rk.iota) );
            }}
        );
    };

    // The actual content of the Array. The resource is not held excluively.
    T[] data;

    // The slices and dimensions of the Array.
    Dim[rk] dims;

pure nothrow @nogc
{
    // Ensure that the dimensions and data.length correspond.
    invariant
    {
        size_t length = 1;
        foreach (d; dims) length *= d.d;
        assert (length == data.length);
    }
    
public const @property:
    // PROPERTIES //

    /// The number of dimensions the Array has.
    enum rank = rk;

    /// Returns the number of elements stored in the Array.
    size_t length()
    {
        size_t result = 1;
        foreach (d; dims)
            result *= d.length;
        return result;
    }

    /// Returns the i-th dimension; i must be given at compile-time to be checked.
    size_t length(size_t i)()
    {
        return dims[i].length;
    }
}

public:
    // CONSTRUCTORS //

    private this(inout(T)[] data, Dim[rk] dims) inout pure
    {
        this.data = data; // No dup!
        this.dims = dims;
    }

    /// Constructs an Array with specified dimensions. All elements are set to T.init.
    this(Dims dimensions) pure @safe
    {
        import std.format : format;
        import std.range : iota;

        dims = mixin (`[ %( Dim(dimensions[%d]) %| , %) ]`.format(rk.iota));
        data = new T[]( [ dimensions ].staticreduce!`a*b` );
    }

    /**
     * Directly initializes the internal data with values produced by the delegate f.
     * If f is pure, then the constructor is pure.
     * Unless f is @system, the constructor is @safe.
     *
     * Essentially does (where r = rk - 1):
     * ---
     * size_t k = 0;
     * foreach (i0; 0 .. dimensions[0])
     *    :      :    ·.            :
     * foreach (ir; 0 .. dimensions[r])
     * {
     *     data[k++] = f(i0, ..., ir);
     * }
     * ---
     */
    private this(DG)(Dims dimensions, DG f)
    {
        import std.format : format;
        import std.range : iota;
        import std.array : uninitializedArray;

        dims = mixin (`[ %( Dim(dimensions[%d]) %| , %) ]`.format(rk.iota));

        data = uninitializedArray!(T[])( [ dimensions ].staticreduce!`a*b` );

        mixin (functionAssign);
    }

    // ASSIGNMENT //
    ref Array opAssign(DG : T delegate(Dims))(DG f)
    {
        return this = MultiIndex!rk i => f(i.expand);
    }

    ref Array opAssign(DG : T delegate(MultiIndex!rk))(DG f)
    {
        mixin (functionAssign);
        return this;
    }
    
    // INDEXING //

    Dollar!i opDollar(size_t i)() const pure @property
    if (i < rk)
    {
        return Dollar!i(dims[i].length);
    }

    Slice!i opSlice(size_t i)(size_t l, size_t u) const pure
    if (i < rk)
    in
    {
        import std.format : format;
        assert (l <= u,
            "Illegal range: at slice no. %d lower bound > upper bound.".format(i));
        assert (u <= dims[i].length,
            "Illegal range: Slice no. %d out of range.".format(i));
    }
    body
    {
        return Slice!i(l, u);
    }


    /+
    dims =
        [
            { 3,  9, 11 },
            { 2,  4,  5 }
        ]
    | ------------------------------------ 11 -------------------------------------- |
                            | ------------------- 6 ---------------- |
     0       1       2       3       4       5       6       7       8       9      10     ---
    11      12      13      14      15      16      17      18      19      20      21      |
    22      23      24      25*     26*     27*     28*     29*     30*     31      32  --  5
    33      34      35      36*     37*     38*     39*     40*     41*     42      43  --  |
    44      45      46      47      48      49      50      51      52      53      54     ---
    +/

    /// Returns the element at the given position.
    ref inout(T) opIndex(Dims indices) inout pure
    in
    {
        import std.format : format;
        foreach (i, index; indices)
            assert (index < dims[i].length,
                "Index no. %d.".format(i));
    }
    body
    {
        size_t k = 0;
        foreach (i, index; indices)
            k = k * dims[i].d + (index + dims[i].l);
        return data[k];
    }
    
    ref inout(T) opIndex(MultiIndex!rk i) inout pure
    {
        return opIndex(i.expand);
    }

    /// Effectively calls this[$, $, ..., $];
    ref auto opIndex() inout pure
    {
        import std.format : format;
        import std.algorithm.iteration : map;
        import std.array : join;
        import std.range : iota;

        enum dollars = rk.iota.map!(i => q{ Slice! %d (0, dims[ %d ].d ) }.format(i, i)).join(',');
        return mixin(`this[` ~ dollars ~ `]`);
    }

    /// Return Slice of the array. This is not a copy!
    auto ref opIndex(Args...)(Args args) inout pure
    {
        import bolpat.implicit : implicit;
        return implicit!index(args);
    }
    
    private auto ref index(Slices!rk ss)
    {
        // Range of slices is enforced by opSlice's contracts
        Dim[rk] dims = this.dims; // copy as this.dims is inout.
        foreach (i, s; ss)
            dims[i].u = (dims[i].l  +=  s.l) + s.length;
        return inout Array(data, dims);
    }
    
    // auto a = array!int(2, 3, 4);
    int opApply(scope int delegate(                       ref T) dg) { return opApply((size_t n, MultiIndex!rk i, ref T t) => dg(             t)); } // foreach (            ref x; a)
    int opApply(scope int delegate(        Dims,          ref T) dg) { return opApply((size_t n, MultiIndex!rk i, ref T t) => dg(   i.expand, t)); } // foreach (   i, j, k, ref x; a)
    int opApply(scope int delegate(        MultiIndex!rk, ref T) dg) { return opApply((size_t n, MultiIndex!rk i, ref T t) => dg(   i,        t)); } // foreach (     ijk,   ref x; a)
    int opApply(scope int delegate(size_t, Dims,          ref T) dg) { return opApply((size_t n, MultiIndex!rk i, ref T t) => dg(n, i.expand, t)); } // foreach (n, i, j, k, ref x; a)
    int opApply(scope int delegate(size_t, MultiIndex!rk, ref T) dg)                                                                                 // foreach (n,   ijk,   ref x; a)
    {
        import bolpat.staticarray : staticmap;
        
        auto i = multiIndex(dims.staticmap!(d => d.length));
        size_t k = 0;
        do
            if (auto result = dg(k++, i, this[i])) return result;
        while (++i);
        return 0;
    }
    
    auto toNestedArray() pure @property
    {
        import bolpat.meta : Iterate, Replicate;
        
        enum r = rk - 1;
        
        Replicate!(r, size_t) bounds;
        foreach (i, ref bound; bounds)
            bound = dims[i].length;

        alias Ar(T) = T[];
        auto result = new Iterate!(Ar, rk, T)( bounds );
        
        size_t offset = 0;
        size_t diff = data.length / dims[r].d; assert (data.length % dims[r].d == 0);
        foreach (ref xs; result.flatten!r)
        {
            xs = data[offset + dims[r].l .. offset + dims[r].u];
            offset += diff;
        }
        return result;
    }
    /+
    auto toNestedArrayDup() inout pure @property
    {
        import std.range  : iota;
        import std.format : format;
        
        import bolpat.staticarray : staticslice, staticmap;
        import bolpat.meta : Iterate, Replicate;
        
        alias Ar(T) = T[];
        alias Result = Iterate!(Ar, rk, T);
        
        Replicate!(rk, size_t) bounds;
        foreach (i, ref bound; bounds)
            bound = dims[i].length;
        
        auto result = new Result( bounds );
        foreach (i, ref x; result.flatten!rk)
            x = data[i];
        return result;
    }
    +/
/+
    auto toNestedArray() const pure @property
    {
        import std.range                : iota;
        import std.format               : format;
        import std.algorithm.iteration  : map;
        import std.array                : join;

        /// DimArr!(i, T) is T[][]...[] with i copies of [].
        template DimArr(T, size_t i)
        {
            static if (i == 0)  alias DimArr = T;
            else                alias DimArr = DimArr!(T, i - 1)[];
        }
        enum newNestedArray =
            q{ new DimArr!(T, rk) ( %( dims[ %d ].length %| , %) ) }.format(Dims.length.iota);

        auto result = mixin (newNestedArray);

        alias r0 = result;

        enum foreachs = rk.iota.map!(i => q{ foreach (ref r%d; r%d) }.format(i + 1, i)).join;

        // returns value of k and sets it to the next position.
        size_t fwd(ref size_t k)
        {
            size_t j = k;

            return j;
        }

        size_t k = 0;
        mixin (foreachs ~ q{
        {
            mixin ( q{ r%d = data[k.fwd]; }.format(rk) );
        } });

        // return result;
        assert (0, "TODO: Comply with Slice");
        return result;
    }
+/
}

/+
/// Creates a copy of the Array.
auto dup(T, size_t rk)(in Array!(T, rk) ar) pure @property
{
    assert (0, "TODO");
}

/// Returns a jagged array with slices of the internal data at lowest level.
auto nestedArray(T, size_t rk)(in Array!(T, rk) ar) pure @property
{
    assert (0, "TODO");
}

/// Returns a jagged array with copys of the internal data at lowest level.
auto nestedArrayDup(T, size_t rk)(in Array!(T, rk) ar) pure @property
{
    assert (0, "TODO");
}
+/

/+

struct SubArray(T, )
{
private:
    enum rk = Ts.length;

    struct Sector
    if (Ts.length == rk)
    {
        import std.typecons : Tuple;

        size_t[rk]  dims;
        Tuple!Ts tpl;
        alias tpl this;

        pure this(Ts values)
        {
            foreach (i, T; Ts)
                static assert (is(T == Value!i) || is(T == Slice!i));

            tpl = Tuple!Ts(values);
        }
    }

    T[]         data;
    size_t[rk]  dims;
    Sector!Ts   sector;

    pure this(Array!(T, rk) a)
    {
        this.data = a.data;
        this.dims = a.dims;
        this.sector.tpl =
    }

    pure this(Array!(T, rk) a, Sector!Ts s)
    {
        this.data = a.data; // no-dup!
        this.dims = a.dims;

        this.sector = s;
        size_t[rk]  sectorDims; // necessary since cannot write this.sectorDims more than once.
        foreach (i, T; Ts)
        {
            static if (is (T == Value!i))
                sectorDims[i] = 1;
            else static if (is (T == Slice!i))
                sectorDims[i] = s[i].length;
            else
                static assert (0, "Invalid type for SubArray. Must be Value!i or Slice!i.");
        }
        this.sectorDims = sectorDims;
    }

pure nothrow @nogc
{
    /// For a pack of indices calculate the offset in the data.
    // INDEXING TOOLS //
    size_t gindex(Dims indices) const
    {
        size_t result = 0;
        foreach (i, index; indices)
        {
            result *= dims[i];
            result += index;
        }
        return result;
    }
}

    ref inout(T) opIndex(Dims indices) inout pure
    {
        return data[gindex(indices)];
    }

    ref inout(SubArray) opIndex(T...)(T args) inout pure
        if (T.length == rk)
    {

    }



    ref T opIndexAssign(S)(S value, Dims indices) pure { return opIndexOpAssign!``(value, indices); }

    ref T opIndexOpAssign(string op, S)(S value, Dims indices) pure
    {
        import std.format : format;
        debug import std.stdio;
        debug writefln("access el no. %s of %s", gindex(indices), data.length);
        mixin( q{ return data[gindex(indices)] %s= value; }.format(op) );
    }



    @property auto toNestedArray() const pure
    {
        import std.range                : iota;
        import std.format               : format;
        import std.algorithm.iteration  : map;
        import std.array                : join;

        /// DimArr!(i, T) is T[][]...[] with i copies of [].
        template DimArr(size_t i, T)
        {
            static if (i == 0)  alias DimArr = T;
            else                alias DimArr = DimArr!(i - 1, T)[];
        }
        enum newNestedArray = q{ new DimArr!(rk, T) ( %( dims[ %d ] %| , %) ) }.format(dims.length.iota);
        auto result = mixin(newNestedArray);
        alias r0 = result;

        enum foreachs = rk.iota.map!(i => q{ foreach (ref r%d; r%d) }.format(i + 1, i)).join;

        size_t k = 0;
        mixin(foreachs ~ q{
        {
            mixin( q{ r%d = data[k++]; }.format(rk) );
        } });

        return result;
    }
}

+/
/+
auto LeviCivita(T, Dims...)(Dims dimensions)
{
    assert(0, "TODO: Debugging and unittest");
    enum n = Dims.length;
    static int eps(Dims idx)
    {
        int result = 1;
        size_t[n] indxs = [ idx ];
        foreach (i, ref p; indxs)
        if (i != p)
        {
            if (i+1 < n)
            {
                foreach (j, q; indxs[i+1 .. $])
                if (q == i)
                {
                    swap(p, q);
                    result = -result;
                    break;
                }
            }
            else
            {
                return 0;
            }
        }
        return result;
    }

    return Array!(Dims.length)(dims, &eps);
}
+/
/+
unittest
{
    import std.stdio;
    import std.range : iota;
    import std.format : format;
    auto a = array!int(2, 3, 4);

    foreach (i; 0 .. 2)
    foreach (j; 0 .. 3)
    foreach (k; 0 .. 4)
    {
        //a[i, j, k] = 4*3*i + 4*j + k;
    }

    /+ foreach (i, j, k, element; a)
    {

    }
    +/
    writeln(a.data);
    auto b = a.toNestedArray;
    writefln("%s %s", b, a.dims);
    writefln("%s %s %s", b.length, b[0].length, b[0][0].length);

}
+/

unittest
{
    import std.stdio;
    
    auto a = array!int(2, 3, 4);
    auto b = a[$, 1 .. $, 2];
    //auto b = a.opIndex(a.opDollar!0, a.opSlice!1(1, a.opDollar!1), 2);
    int n = 0;
    foreach (i; 0 .. 2)
    foreach (j; 0 .. 3)
    foreach (k; 0 .. 4)
    {
        a[i, j, k] = 4*3*i + 4*j + k;
    }
    
    foreach (n, i,j,k, x; b)
    {
        writefln("%d: b[%d, %d, %d] = %s", n, i, j, k, x);
    }
    foreach (x; b) writef("%s ", x);
    writeln;
    
    writeln(a.data);
    writeln(b.toNestedArrayDup);
}
