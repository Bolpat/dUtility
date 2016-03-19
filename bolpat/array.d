// The MIT License (MIT)
//
// Copyright (c) 2016 Q. F. Schroll

import std.algorithm.iteration : reduce;

import bolpat.meta : AliasSeq;

/**
 * Creates a sequence of values, similar to how $(D iota) does.
 */
template Iota(int stop)
{
    static if (stop <= 0) alias Iota = AliasSeq!();
    else                  alias Iota = AliasSeq!(Iota!(stop - 1), stop - 1);
}

/// ditto
template Iota(int start = 0, int stop)
{
    static if (stop <= start) alias Iota = AliasSeq!();
    else                      alias Iota = AliasSeq!(Iota!(start, stop - 1), stop - 1);
}

/// ditto
template Iota(int start, int stop, int step)
{
    static assert(step != 0, "Iota: step must be != 0");
    static if (step > 0)
        static if (stop <= start) alias Iota = AliasSeq!();
        else                      alias Iota = AliasSeq!(Iota!(start, stop - step, step), stop - step);
    else
        static if (stop >= start) alias Iota = AliasSeq!();
        else                      alias Iota = AliasSeq!(Iota!(start, stop - step, step), stop - step);
}

/// Replicate(i, T) is (T, T, ..., T) with i copies of T.
private template Replicate(size_t i, T)
    if (i > 0)
{
    static if (i == 1) alias Replicate = T;
    else               alias Replicate = AliasSeq!(T, Replicate!(i - 1, T));
}

/// IMORTANT NOTES ABOUT TERMS:
/// Usually when dealing with arrays, the term dimension denotes the number
/// of [] after T, e.g. T[][][] is said to have dimension 3. This will be called
/// the rank of the Array. The term "dimension" will have another meaning here.
/// Because the sub-arrays in an T[][]-object need not to have same length
/// (called jagged array), there cannot even be a useful term for their length
/// as this length would have to be unique.
/// But the Arrays here are hypercubes which have a certain size in each dimension.

/// Returned by indexing operator when using a plain number as index.
/// As opposed to a plain size_t, a Value carries the dimension index, too.
private struct Value(size_t index)
{
    size_t value;
    alias value this;
    
    pure this(size_t value)
    in   { assert(value < dims[i]); }
    body { this.value = value; }
}

/// Returned by indexing operator opSlice.
private struct Slice(size_t index)
{
    size_t l, u;
    pure @property size_t length() const { return u - l; }
    
    pure this(size_t l, size_t u)
    {
        this.l = l;
        this.u = u;
    }
}

/// Returned by opDollar.
private struct Dollr(size_t index)
{
    size_t value;
    alias value this;
    
    pure this(size_t value)
    in   { assert(value == dims[i]); }
    body { this.value = value; }
    
    pure @property Slice!i toSlice() const { return Slice!i(0, value); }
}

/++
 +  Convenience constructor for Arrays.
 +
 +  It takes the type and dimensions, the rank is infered by the number
 +  of dimensions given.
 +
 +  Intended usage:
 +  ----
 +  void main()
 +  {
 +      auto ar = array!int(2, 3, 4);
 +      // Makes a rank-3 Array, that has the dimensions 2, 3, and 4.
 +      // The 24 elemetns are defaulted to int.init (== 0).
 +      
 +      // You can iterate over the array the conservative way ...
 +      foreach (i; 0 .. ar.dim!0)
 +      foreach (j; 0 .. ar.dim!1)
 +      foreach (k; 0 .. ar.dim!2)
 +      {
 +          ar[i, j, k] = i * j + k;
 +      }
 +      // ... but the better style is
 +      foreach (i, j, k, ref x; ar)
 +      {
 +          x = i * j + k;
 +      }
 +      Just for initializing, you can use a delegate.
 +      
 +  }
 +  ----
 +  Instead of having to use 0 .. $, you can use $ alone when indexing.
 +  You can however not use the value represented by $ when using $ alone.
 +  You can use the value represented by $ in higher expressions like $-1, $/2, etc.
 +  For a rank-4 Array ar, the expression ar[$,$,$,$] represents the full Array,
 +  but ar[$-1, $-1, $-1, $-1] is the last value.
 +/
auto array(T, Dim...)(Dim d)
{
    return Array!(T, Dim.length)(d);
}

///
alias Array(T, size_t rk : 0) = T;

///
alias Array(T, size_t rk : 1) = T[];

///
struct Array(T, size_t rk)
if (rk > 1)
{

private:
    alias Dims = Replicate!(rk, size_t);

    /// Used when a delegate f is used to assign the data values.
    enum functionAssign =
    q{
        import std.range                : iota;
        import std.format               : format;
        import std.algorithm.iteration  : map;
        import std.array                : join; 
        
        size_t k = 0;
        mixin
        (   //           j =>    foreach (i_j; 0 .. dims [ j ])
            rk.iota.map!(j => q{ foreach (i%d; 0 .. dims[ %d ]) }.format(j, j)).join
            ~
            q{{ //         data[k++] = f( i_0, ..., i_r )
                mixin ( q{ data[k++] = f( %( i%d %| , %) ); }.format(rk.iota) );
            }}
        );
    };
    //  // Let r = rk - 1;
    //  size_t k = 0;
    //  foreach (i_0; 0 .. dim[0])
    //      : : :
    //  foreach (i_r; 0 .. dim[r])
    //  {
    //      data[k++] = f(i_0, ..., i_r);
    //  }

    /// The actual content of the Array.
    T[] data;

    /// The dynamic dimensions of the Array.
    size_t[rk] dims;

pure nothrow @nogc
{
    /// Ensure that the dimensions and data.length correspond.
    invariant
    {
        size_t d = 1; foreach (dim; dims) d *= dim;
        assert (d == data.length);
    }

public const:                                               // PROPERTIES //
    /// Returns the number of dimensions the Array has.
    @property size_t rank()          { return rk; }

    /// Returns the i-th dimension; i must be given at compile-time to be checked.
    @property size_t dim(size_t i)() { return dims[i]; };

    /// Returns the number of elements stored in the Array.
    @property size_t length()        { return data.length; }
}

public:                                                     // CONSTRUCTORS //

    alias toSubArray this;
    pure @property auto toSubArray() inout { return this[]; }

    /// Constructs an Array with specified dimensions. All elements are set to T.init.
    pure this(Dims dimensions) @safe
    {
        dims = [ dimensions ];
        data = new T[](dims.reduce!`a * b`);
    }

    /// Directly initializes the internal data with values produced by the delegate f.
    /// If f is pure, then the constructor is pure.
    /// Unless f is @system, the constructor is @safe.
    this(DG)(Dims dimensions, DG f)
    {
        import std.array : uninitializedArray;
        
        dims = [ dimensions ];
        size_t l = 1;
        foreach (i, dim; dimensions) l *= dim;
        data = uninitializedArray!(T[])(l);
        
        mixin(functionAssign);
    }

    this(this) pure
    {
        data = data.dup;
    }

                                                            // ASSIGNMENT //
    ref Array opAssign(T delegate(Dims) @trusted pure nothrow f) @safe pure nothrow
    {
        mixin(functionAssign);
        return this;
    }

    ref Array opAssign(T delegate(Dims) @trusted pure f) @safe pure
    {
        mixin(functionAssign);
        return this;
    }

    ref Array opAssign(T delegate(Dims) f)
    {
        mixin(functionAssign);
        return this;
    }

    /++
     +  Changes the dimension interpretation of the Array.
     +  The old dimensions' product must be exactly the new dimesions' product.
     +  Otherwise, tryReDim returns false and reDim throws an InvalidatedException.
     +
     +  This, if the dimensions did change, all prevoiously created 
     +  SubArrays of this instance will become invalidated.
     +
     +  Example:
     +  ---
     +  auto a = array!int(3, 4);
     +  a  =  (i, j) => 4*i + j;
     +  b  =  a[2, 1 .. 3];
     +  /* a is interpreted as
     +   *  0   1   2   3
     +   *  4   5   6   7
     +   *  8   9  10  11
     +   * 
     +   * b is interpreted as
     +   *  5   6
     +   */
     +  assert(a[1, 1] == 5);
     +  a.reDim(2, 6);
     +  /* Now ar is interpreted as
     +   *  0   1   2   3   4   5
     +   *  6   7   8   9  10  11
     +   */
     +  assert(a[1, 1] == 7);
     +  // Any action on b will throw an InvalidatedException until it is reassigned.
     +  b  =  a[$, 3];
     +  /* Now b is interpreted as
     +   *  3
     +   *  9
     +   */
     +  ---
     +/
    void reDim(Dims dimensions) @nogc pure
    {
        // statically allocate Exception as the function then can be @nogc.
        shared static const reDimExc = new InvalidatedException("reDim: Incompatible Dimensions.");
        if (!tryReDim(dimensions)) throw reDimExc;
    }

    /// ditto
    bool tryReDim(Dims dimensions) @nogc nothrow pure
    {
        size_t d = 1;
        foreach (dim; dimensions) d *= dim;
        
        if (d != data.length) return false;
        dims = [ dimensions ];
        return true;
    }

                                                            // INDEXING //
    Dollar!i opDollar(size_t i)() const pure
    if (i < rk)
    {
        return Dollar!i(rk[i]);
    }

    Slice!i opSlice(size_t i)(size_t l, size_t u) const pure
    if (i < rk)
    in { assert (l <= u); assert (u <= dim[i]); }
    body
    {
        return Slice!i(l, u);
    }


    ref inout(T) opIndex(Dims indices) inout pure
    {
        return data[gindex(indices)];
    }

    /// Effectively calls this[$, $, ..., $];
    auto opIndex() inout pure
    {
        import std.format : format;
        import std.algorithm.iteration : map;
        import std.array : iota, join;
        enum dollars = rk.iota.map!(i => q{ Slice! %d (0, dims[ %d ] ) }.format(i, i)).join(',');
        mixin(`return this[` ~ dollars ~ `];`);
    }

    /// Replaces $ by Slice(0, $) and width-one slices by the value.
    auto ref auto opIndex(Ts...)(Ts args) pure
    {
        foreach (i, T; Ts)
        {
            static if (is (T == Dollr!i))
                return this[args[0 .. i], args[i].toSlice, args[i+1 .. $]];
            else static if (is (T == Slice!i))
            {
                if (args[i].length == 1)
                    return this[args[0 .. i], args[i].l, args[i+1 .. $]];
            }
            else
                static assert (is (T == size_t));
        }
        return this[][args];
    }

    @property auto toNestedArray() const pure
    {
        return this[].toNestedArray;
    }
}

@property auto dup(T, size_t tk)(in Array!(T, rk) ar) pure
{
    return Array!(T, rk)(ar);
}



struct SubArray(T, Ts...)
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
    size_t gindex(Dims indices) const                       // INDEXING TOOLS //
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

class InvalidatedException : Exception
{
    this( string msg,
          string file    = __FILE__,
          uint line      = cast(uint)__LINE__,
          Throwable next = null
        ) pure nothrow @nogc @safe
    {
        super(msg, file, line, next);
    }
}

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

void main()
{
    import std.stdio;
    import std.range : iota;
    import std.format : format;
    auto a = array!int(2, 3, 4);

    foreach (i; 0 .. 2)
    foreach (j; 0 .. 3)
    foreach (k; 0 .. 4)
    {
        a[i, j, k] = 4*3*i + 4*j + k;
    }

    // foreach (i, j, k, element; a)
    {

    }

    writeln(a.data);
    auto b = a.toNestedArray;
    writefln("%s %s", b, a.dims);
    writefln("%s %s %s", b.length, b[0].length, b[0][0].length);

}