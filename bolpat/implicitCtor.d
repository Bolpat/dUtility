
module bolpat.implicitCtor;

/// used for annotation
struct implicit
{
    size_t index;
}

/**
 *  Merges the overloading sets of the prototype and the generated overloads.
 */
mixin template implicitOverloads
(
    string name,
    alias prototype,
    alias genOverloads = generateOverloads)
{
    mixin("
    private mixin genOverloads!prototype  implicit_"~name~"_overloads;
    alias "~name~" = prototype;
    alias "~name~" = implicit_"~name~"_overloads."~__traits(identifier, prototype)~";
    ");
}

static import std.traits;
/**
 *  Generates the implicit overloads from `@Imolicit` constructors and functions with exactly one `@Implicit(n)` parameter.
 */
mixin template generateOverloads
(
    alias f,
    alias Parameters = std.traits.Parameters,
    alias ReturnType = std.traits.ReturnType,
    alias ICTs       = ImplicitConstructorTypes,
)
{
    import std.meta : AliasSeq;
    static foreach (i, alias overload; __traits(getOverloads,
        __traits(parent, f),
        __traits(identifier, f)))
    // if the overload has an @implicit(index) annotation, set i = index, else just ignore that overload
    static foreach (i; {
            bool found = false;
            size_t result;
            static foreach (attr; __traits(getAttributes, overload))
            static if (is(typeof(attr) == implicit))
            {
                assert(!found, "you may only specify implicit parameters once");
                result = attr.index;
                found = true;
            }
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
            import std.functional : forward;
            return overload(forward!psL, Parameters!overload[i](forward!implicitParam), forward!psR);
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

    static struct Test
    {
        // methods:
        int proto_foo(int v, S s) @implicit(1)
        {
            import std.stdio : writeln;
            writeln("foo: call S with value ", s.s);
            return v;
        }
        void proto_foo(char c) { }
        
        mixin implicitOverloads!("foo", proto_foo);
        // You can merge the overloading sets manually:
        // mixin generateOverloads!proto_foo  implicit_foo_overloads;
        // alias foo = proto_foo;
        // alias foo = implicit_foo_overloads.proto_foo;
        
        
        // static members or globals:
        static long proto_goo(int v, S s, bool b) @implicit(1)
        {
            import std.stdio : writeln;
            writeln("goo: call S with value ", s.s);
            return b ? v : s.s;
        }
        static void proto_goo(char c) { }
        static mixin implicitOverloads!("goo", proto_goo);
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
    Test.goo(1, S(2),   true);
    Test.goo(1, S(3L),  true);
    Test.goo(1, S("B"), true);
    Test.goo(1, 2,      true);
    Test.goo(1, 3L,     true);
    static assert(!__traits(compiles,
        cast(void)Test.goo(1, "B")
    ));
}

/**
 *  Returns an AliasSeq of the types `T` is impllicitly constructable from.
 *
 *  Implicit constructors have exactly one parameter (defaulted additional parameters are not supported) and have to be annotated with `@implicit`.
 *  Implicit constructors which do not meet the requirements raise an error.
 */
template ImplicitConstructorTypes(T)
{
    // static assert(!is(T == class), "use '" ~ T.stringof ~ " arg ...' for implicit class parameters");
    static assert(is(T == struct), T.stringof ~ " must be a struct");
    import std.traits : Parameters, ParameterDefaults;
    import std.meta : staticMap, Filter;
    
    alias ImplicitConstructorTypes =
        staticMap!(FirstParam,
            Filter!(isImplicit,
                __traits(getOverloads, T, "__ctor")));

    static alias FirstParam(alias ctor) = Parameters!ctor[0];
    static enum isImplicit(alias ctor) =
        {
            alias Ps = Parameters!ctor;
            foreach (uda; __traits(getAttributes, ctor))
            static if (is(uda == implicit))
            {
                static assert(Ps.length > 0,
                    "implict constructor must have at least one argument");
                foreach (i, D; ParameterDefaults!ctor)
                {
                    // D == void iff i-th parameter is not implicit.
                    // if D non-optional then i must be 0
                    static assert(is(D == void) <= (i == 0),
                        "implicit constructor can only have one non-optional parameter");
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
}

