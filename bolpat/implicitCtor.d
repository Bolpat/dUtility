
module bolpat.implicitCtor;

version(none)
{
    struct T { int i; }
    
    pragma(msg, __traits(hasMember, T, "__ctor"));
}
else:

/// Similar to std.meta.AliasSeq, but without flattening. Use `Pack.Content` to access the contents.
/// Main reason for this is, you cannot have AliasSeq inside another AliasSeq.
private template Pack(T...)
{
    alias Content = T;
}

unittest
{
    alias P = Pack!(int, uint);
    static struct Test1
    {
        static foreach (T; P.Content)
        {
            static T f(T x) { return x; }
        }
    }
    
    import std.meta : AliasSeq;
    alias Ps = AliasSeq!(P, P);
    static assert(!is(Ps == AliasSeq!(int, uint, int, uint)));

    alias Ts = AliasSeq!(int, uint);
    struct Test2
    {
        static foreach (i, pack; Ps)
        static foreach (T; pack.Content)
        {
            void f(T, Ts[i]) { }
        }
    }
}

private template cross(Packs...)
{
    // static foreach (alias P; Packs) static assert(is(P == Pack!T, T...));
    
    import std.meta : AliasSeq, staticMap;
    static enum size_t len(alias Pack) = Pack.Content.length;
    // size_t[n] mkArray(size_t n)(size_t[n] array ...) { return array; }
    // import std.range : iota;
    // import std.algorithm : map;
    static size_t[][] cart(size_t[] lengths...) pure nothrow @safe
    {
        if (lengths.length == 0) return [ [] ];
        size_t[][] result;
        foreach (i; 0 .. lengths[0])
        foreach (r; lengths[1 .. $].cart)
            result ~= i ~ r;
        return result;
    }
    
    string impl() {
        string result = "alias cross = AliasSeq!(";
        static foreach (v; cart(staticMap!(len, Packs)))
        {
            result ~= "Pack!(";
            static foreach (i, r; v)
            {
                import std.conv : text;
                result ~= text("Packs[",i,"].Content[",r,"],");
            }
            result ~= "),";
        }
        return result ~ ");";
    }
    mixin(impl());
}


unittest
{
    static foreach (i, c; [ 'S', 'T', 'R' ])
    static foreach (j; '0' .. '0' + i + 2)
    {
        mixin("static struct " ~ c ~ j ~ " { }");
    }
    
    static foreach (i, c; [ 'S', 'T', 'R' ])
    {
        mixin("
            static struct " ~ c ~ "
            {
                static foreach (j; '0' .. '0' + i + 2)
                {
                    mixin(`@implicit this(`~c~j~`) { }`);
                }
            }
        ");
    }

    import std.meta : AliasSeq;
    alias ICTP(T) = Pack!(ImplicitConstructorTypes!T);
    static assert(is(ICTP!S.Content == AliasSeq!(S0, S1)));
    static assert(is(ICTP!T.Content == AliasSeq!(T0, T1, T2)));
    static assert(is(ICTP!R.Content == AliasSeq!(R0, R1, R2, R3)));
    
    alias ICTPs = AliasSeq!(ICTP!S, ICTP!T, ICTP!R);
    alias iWant = AliasSeq!(
            Pack!(S0, T0, R0),
            Pack!(S0, T0, R1),
            Pack!(S0, T0, R2),
            Pack!(S0, T0, R3),
            Pack!(S0, T1, R0),
            Pack!(S0, T1, R1),
            Pack!(S0, T1, R2),
            Pack!(S0, T1, R3),
            Pack!(S0, T2, R0),
            Pack!(S0, T2, R1),
            Pack!(S0, T2, R2),
            Pack!(S0, T2, R3),
            Pack!(S1, T0, R0),
            Pack!(S1, T0, R1),
            Pack!(S1, T0, R2),
            Pack!(S1, T0, R3),
            Pack!(S1, T1, R0),
            Pack!(S1, T1, R1),
            Pack!(S1, T1, R2),
            Pack!(S1, T1, R3),
            Pack!(S1, T2, R0),
            Pack!(S1, T2, R1),
            Pack!(S1, T2, R2),
            Pack!(S1, T2, R3),
        );
    
    // static assert(is(iWant == cross!ICTPs)); // doesn't work!
    static foreach (i, P; cross!ICTPs)
    static foreach (j, V; P.Content)
        static assert(is(V == iWant[i].Content[j]));
}

// ---------------------------------------------------------

struct implicit /// used for annotation
{
    size_t[] indices; /// used for annotation
    
    this(size_t[] indices...) ///
    {
        assert(indices.length > 0);
        this.indices = indices;
    }
    
    @property size_t index() /// for backwards compatibility
    {
        assert(indices.length == 1);
        return indices[0];
    }
}

/+
Currently not supported, but desirable:
  • use @implicit for all possible implicit positions (code already done)
    rationale: ambigious on constructors
  Solutions:
    1. constructors must use @implicit(indices) for overload generation
       (con: nasty spacial case)
    2. additional `infer` s.t. @implicit(infer) == @implicit, but for constructors,
       @implicit is an annotation, while @implicit(infer) is always for overload generation
    3. make @implicit() mean @implicit(.. all applicable indices ..)
       and remove @implict for that general --> @implict `only` annotation!
       (con: easy to get wrong, as D makes empty parentheses optional except for ftprs and delegates)

  • takte lambda instead of alias to existing prototype
  • parameter storage classes (ref, out, lazy, scope, return)
  • support optional paramters
  • copy function attributes (pure, nothrow, @nogc, @safe, @property, @trusted, @system, ref, const, immutable, inout, shared, return, scope)
    as far as possible. attributes (pure nothrow, @nogc, @safe) intersect with constructors being used.
  
  • @explicit, making all other constructors @implicit
  • @forceImplicit, ignoring @implicit annotation on parameter type constructors and use any constructor
  • @explicit, making @forceImplicit ignore it
  • use original parameter identifiers
  • support variadic arrays (T[] v...)
+/
// import std.traits : ParameterStorageClassTuple, ParameterStorageClass;
// import std.traits : ParameterIdentifierTuple;
// import std.traits : ParameterDefaults;

/**
 *  Merges the overloading sets of the prototype and the generated overloads.
 */
mixin template implicitOverloads
(
    string name,
    alias prototype,
    alias generateOverloads = generateOverloads
)
{
    mixin("
        private mixin generateOverloads!prototype  implicit_"~name~"_overloads;
        alias "~name~" = prototype;
        alias "~name~" = implicit_"~name~"_overloads."~__traits(identifier, prototype)~";
        ");
}

static import std.traits;
static import std.meta;

private template ImplicitConstructorTypePack(alias overload)
{
    alias ICTs = ImplicitConstructorTypes;
    alias ImplicitConstructorTypePack(size_t position) =
        Pack!(std.traits.Parameters!overload[position], ICTs!(std.traits.Parameters!overload[position]));
}

T construct(T, V)(V value)
{
    static
    if (is(T == V)) return value;
    else            return T(value);
}

size_t[] whereStructsWithImplicits(Ts...)()
{
    size_t[] result;
    static foreach (i, T; Ts)
    static if (is(T == struct) && ImplicitConstructorTypes!T.length > 0)
        result ~= i;
    return result;
}

template isStructWithImplicit(T)
{
    static if (is(T == struct))
        enum bool isStructWithImplicit = ImplicitConstructorTypes!T.length > 0;
    else
        enum bool isStructWithImplicit = false;
}

version(multi)
mixin template generateOverloads
(
    alias f,
    alias traits    = std.traits,
    alias meta      = std.meta,
    alias implicit  = implicit,
    alias cross     = cross,
    alias ICTP      = ImplicitConstructorTypePack,
    alias ctor      = construct,
    // alias wSwI      = whereStructsWithImplicits,
)
{
    static foreach (alias overload; __traits(getOverloads,
        __traits(parent, f),
        __traits(identifier, f)))
    static foreach (enum size_t[] implicitPositions; function size_t[][]() {
            bool found = false;
            size_t[] result;
            static foreach (attr; __traits(getAttributes, overload))
            static if (is(typeof(attr) == implicit))
            {
                assert(!found, "you may only specify implicit parameters once");
                result = attr.indices;
                assert(result.length > 0, "empty @implicit() annotation");
                found = true;
            }
            // else static if (is(attr == implicit))
            // {
                // assert(!found, "you may only specify implicit parameters once");
                // result = wSwI!(traits.Parameters!overload);
                // found = true;
            // }
            return found ? [ result ] : [ ];
        }())
    {
        static foreach (p; implicitPositions)
        {
            // has implicit ctors? Remember: first Parameter is always the type itself.
            // need static map because (ICTP!overload)!p does not work!
            static if (meta.staticMap!(ICTP!overload, p)[0].Content.length <= 1)
            {
                static assert(0, "generateOverloads: " ~ __traits(identifier, f) ~
                    ": for explicitely given @implicit positions, every position must support @implicit constructors");
                // Artificially generate one overload, so it can be accessed.
                // Otherwise, the assert message is not shown due to template instanciacion failing.
                mixin("void " ~  __traits(identifier, f) ~ "() { }");
            }
        }
    
        static foreach (ImplicitPack; cross!(meta.staticMap!(ICTP!overload, meta.aliasSeqOf!implicitPositions))[1 .. $])
        // static if (implicitPositions.length > 0)
        mixin({
            string result = "
                auto ref " ~ __traits(identifier, f) ~ "
                (
                    traits.Parameters!overload[0 .. implicitPositions[0]]
                        ps0,";
            enum l = implicitPositions.length;
            import std.conv : text;
            static foreach (i; 0 .. l - 1)
                result ~= text("
                    ImplicitPack.Content[",i,"]
                        t",i,",
                    traits.Parameters!overload[implicitPositions[",i,"]+1 .. implicitPositions[",i+1,"]]
                        ps",i+1,",");
            static if (l > 0)
                result ~= text("
                    ImplicitPack.Content[",l-1,"]
                        t",l-1,",
                    traits.Parameters!overload[implicitPositions[",l-1,"]+1 .. $]
                        ps",l,",");
            result ~= "
                )
                {
                    return overload(
                        ps0,";
            static foreach (i; 0 .. l)
                result ~= text("
                        ctor!(traits.Parameters!overload[implicitPositions[",i,"]])(t",i,"),
                        ps",i+1,",");
            result ~= "
                    );
                }";
            return result;
        }());
    }
}
else
/**
 *  Generates the implicit overloads from `@implicit` constructors and functions with exactly one `@implicit(n)` parameter.
 *
 *  Does not yet consider parameter storage classes and default values of original parameters.
 */
mixin template generateOverloads
(
    alias f,
    alias Parameters = std.traits.Parameters,
    alias ReturnType = std.traits.ReturnType,
    alias ICTs       = ImplicitConstructorTypes,
    // alias wSwI       = whereStructsWithImplicits,
    alias implicit   = implicit
)
{
    static foreach (alias overload; __traits(getOverloads,
        __traits(parent, f),
        __traits(identifier, f)))
    // if the overload has an @implicit(index) annotation, set i = index, else just ignore that overload
    static foreach (enum size_t i; {
            bool found = false;
            size_t result;
            static foreach (attr; __traits(getAttributes, overload))
            static if (is(typeof(attr) == implicit))
            {
                assert(!found, "you may only specify the implicit parameter once");
                result = attr.index;
                found = true;
            }
            // else static if (is(attr == implicit))
            // {
                // assert(!found, "you may only specify implicit parameters once");
                // result = wSwI!(traits.Parameters!overload);
                // found = true;
            // }
            return found ? [ result ] : [ ];
        }())
    static foreach (ICT; ICTs!(Parameters!overload[i]))
    {
        mixin("
        auto ref " ~ __traits(identifier, f) ~ "
        (
            Parameters!overload[0 .. i]     psL,
            ICT                             implicitParam,
            Parameters!overload[i + 1 .. $] psR
        )
        {
            return overload(psL, Parameters!overload[i](implicitParam), psR);
        }
        ");
    }
}

///
unittest
{
    static struct S
    {
        long s;
        @implicit this(int x)  { s = x; }
        @implicit this(long x) { s = x; }
        this(string x) { s = x == "A" ? 0 : -1; }
    }

    // We need a struct environment because just inside unittest,
    // functions cannot be overloaded.
    static struct Test
    {
        // It works with methods ...
        int proto_foo(int v, S s) @implicit(1)
        {
            debug import std.stdio : writeln;
            debug writeln("foo: call S with value ", s.s);
            return v;
        }
        void proto_foo(char c) { }
        
        mixin implicitOverloads!("foo", proto_foo);
        // You can merge the overloading sets manually:
        //      mixin generateOverloads!proto_foo  implicit_foo_overloads;
        //      alias foo = proto_foo;
        //      alias foo = implicit_foo_overloads.proto_foo;
        // You have to name the mixin template to properly access the
        // generated overloads. Otherwise they may be shadowed.
        
        // ... and static member functions or globals.
        static long proto_goo(int v, S s, bool b) @implicit(1)
        {
            return b ? v : s.s;
        }
        static void proto_goo(char c) { }
        // Don't miss 'static' here:
        static mixin implicitOverloads!("goo", proto_goo);
        // Otherwise the new overloads become non-static member functions.
    }

    Test t;
    int r;
    
    t.foo('c');
    r = t.foo(1, S(1));
    r = t.foo(1, S(2L));
    t.foo(1, S(true));
    r = t.foo(1, 1);
    r = t.foo(1, 2L);
    static assert(!__traits(compiles,
        cast(void)t.foo(1, "A")
    ));
    
    Test.goo('a');
    assert(Test.goo(1, S(2),  false) == 2);
    Test.goo(1, S(3L),  true);
    Test.goo(1, S("B"), true);
    assert(Test.goo(1, 2,  false) == 2);
    Test.goo(1, 3L,     true);
    static assert(!__traits(compiles,
        cast(void)Test.goo(1, "B")
    ));
}

///
unittest
{
    static struct S
    {
        @implicit this(int x)  { }
    }
    
    static struct T { }
    
    struct Test
    {
        // This is fail: You cannot use hoo(S, S) because it's anbigous.
        // As long as you don't call it, everything is fine.
        static int proto_hoo0(S s1, S s2) @implicit(0) { return 0; }
        static int proto_hoo1(S s1, S s2) @implicit(1) { return proto_hoo0(s1, s2); }
        static mixin implicitOverloads!("hoo", proto_hoo0);
        static mixin implicitOverloads!("hoo", proto_hoo1);
        
        version(multi)
        {
            static int proto_moo(S, S) @implicit(0, 1) { return 0; }
            
            // static int proto_moo(S, S) @implicit { return 0; }
            static mixin implicitOverloads!("moo", proto_moo);
            
            // static int proto_boo(S, T) @implicit { return 0; }
            // static mixin implicitOverloads!("boo", proto_boo);
        }
        
        // error: for explicitely given @implicit positions, every position must support @implicit constructors:
        //  static int proto_aoo(T) @implicit(0) { return 0; }
        //  static mixin implicitOverloads!("aoo", proto_aoo);
        
        // error: tuple index 1 exceeds 1
        //  static int proto_aoo(S) @implicit(1) { return 0; }
        //  static mixin implicitOverloads!("aoo", proto_aoo);
    }
    
    assert(Test.hoo(1, S(1)) == 0);
    assert(Test.hoo(S(1), 1) == 0);
    static assert(!__traits(compiles,
        assert(assert(Test.hoo(1, 1) == 0))
    ));
    
    version(multi)
    {
        assert(Test.moo(S(1), S(1)) == 0);
        assert(Test.moo(  1 , S(1)) == 0);
        assert(Test.moo(S(1),   1 ) == 0);
        assert(Test.moo(  1 ,   1 ) == 0);
        
        // assert(Test.boo(S(1), T()) == 0);
        // assert(Test.boo(  1 , T()) == 0);
    }
}

/**
 *  Returns an AliasSeq of the types `T` is impllicitly constructable from.
 *
 *  Implicit constructors have exactly one parameter (defaulted additional parameters are not supported) and have to be annotated with `@implicit`.
 *  Implicit constructors which do not meet the requirements raise an error.
 */
template ImplicitConstructorTypes(T)
{
    static assert(is(T == struct), "ImplicitConstructorTypes: paramter must be a struct but is " ~ T.stringof);
    import std.traits : Parameters, ParameterDefaults;
    import std.meta : AliasSeq, staticMap, Filter;
    
    static if (__traits(hasMember, T, "__ctor"))
    {
        alias ImplicitConstructorTypes =
            staticMap!(FirstParam,
                Filter!(isImplicit,
                    __traits(getOverloads, T, "__ctor")));
    }
    else alias ImplicitConstructorTypes = AliasSeq!();
    
    static alias FirstParam(alias ctor) = Parameters!ctor[0];
    static enum isImplicit(alias ctor) =
        {
            alias Ps = Parameters!ctor;
            foreach (uda; __traits(getAttributes, ctor))
            static if (is(uda == implicit))
            {
                static assert(Ps.length > 0,
                    "implict constructors must have at least one argument");
                foreach (i, D; ParameterDefaults!ctor)
                {
                    // D == void iff i-th parameter is not default.
                    // if D not optional then i must be 0
                    static assert(is(D == void) <= (i == 0),
                        "implicit constructors can only have one non-optional parameter");
                }
                return true;
            }
            return false;
        }();
}

///
unittest
{
    import std.meta : AliasSeq;
    
    struct S
    {
        long i;
        this(int  i) @implicit  { this.i = i; }
        this(long i) @implicit  { this.i = i; }
        this(uint i)            { this.i = i; }
    }
    
    static assert(is(ImplicitConstructorTypes!S == AliasSeq!(int, long)));
    
    struct T
    {
        long i;
        this(int  i, int = 0) @implicit  { this.i = i; }
        this(long i, int = 0) @implicit  { this.i = i; }
        this(uint i, int = 0)            { this.i = i; }
    }
    
    static assert(is(ImplicitConstructorTypes!T == AliasSeq!(int, long)));
    
    struct R
    {
        this(int, int) @implicit { }
    }
    
    static assert(!__traits(compiles,
        {
            alias X = ImplicitConstructorTypes!R;
        }
    ));
}

