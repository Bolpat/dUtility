/** Supplies trusted access to a `@system` function or `__gshared` resource.
  *
  * Note:
  *   Real memory safety must be proven by the programmer.
  */
auto ref trust(alias a, Args...)(auto ref Args args) @trusted
{
    import std.functional : forward;
    static if (Args.length)
        return a(forward!args);
    else
        return a;
}

///
@safe pure nothrow @nogc unittest
{
    static @system systemOp(int x) { }
    static @safe safeFunc()
    {
        static assert(!__traits(compiles,
            systemOp(1) // cannot call @system function in @safe code
        ));
        trust!systemOp(1);
    }
}

///
@system pure nothrow @nogc unittest
{
    __gshared int x = 10;
    static @safe safeFunc()
    {
        int y;
        static assert(!__traits(compiles,
            y = x // no access to __gshared in @safe function
        ));
        y = trust!x;
    }
}