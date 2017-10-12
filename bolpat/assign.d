
module bolpat.assign;


/**
 * Easy to use parallel assignment.
 */
void assign(string op = "", T, S, Other...)(ref T target, auto ref S source, auto ref Other other)
{
    pragma (inline, true);
    import std.functional : forward;
    mixin("target " ~ op ~ "= source;");
    static if (other.length > 0)
        assign!op(forward!other);
}

///
pure nothrow @safe @nogc unittest
{
    // Intended usage without side-effects.
    int i = 2, j = 3;
    assign
    (
        i, i + j, // i = 2 + 3
        j, i * j, // j = 2 * 3
    );
    assert (i == 5);
    assert (j == 6);
    
    // The code is equivalent to
    // int i = 2, j = 3;
    // auto temp0 = i + j;
    // auto temp1 = i * j;
    // i = temp0;
    // j = temp1;
}

pure nothrow @safe @nogc unittest
{
    // Intended usage without side-effects.
    int i = 2, j = 3;
    assign!"+"
    (
        i, i + j, // i += 2 + 3
        j, i * j, // j += 2 * 3
    );
    
    
    // The code is equivalent to
    // int i = 2, j = 3;
    // auto temp0 = i + j;
    // auto temp1 = i * j;
    // i += temp0;
    // j += temp1;
    assert (i == 7);
    assert (j == 9);
}

///
pure nothrow @safe @nogc unittest
{
    // The lhs values must be assignable!
    static assert (!__traits(compiles,
    {
        int i = 2, j = 3;
        assign
        (
            i,   i + j,
            j+1, i * j, // error: j+1 is not assignable.
        );
    }));
}

///
nothrow @safe @nogc unittest // !pure
{
    // Non-changing side-effects are perfectly okay.
    // From https://dlang.org/spec/expression.html
    // Note that DMD currently does not comply with left to right evaluation of function arguments and AssignExpression.
    
    static int loggedValue = 0;
    auto ref log(T)(auto ref T value)
    {
        loggedValue = value;
        return value;
    }

    int i = 2, j = 3;
    assign
    (
        i, log(i + j), // i = 2 + 3
        j, log(i * j), // j = 2 * 3
    );
    assert (i == 5);
    assert (j == 6);
    // assert (loggedValue == 6); // cf. Note.
    assert (loggedValue == 5 || loggedValue == 6);
    
    // The code is equivalent to
    // int i = 2, j = 3;
    // auto temp0 = log(i + j);
    // auto temp1 = log(i * j);
    // i = temp0;
    // j = temp1;
}

///
pure nothrow @safe @nogc unittest
{
    // Not recommanded, but possible: manipulating side-effects.
    // All side-effects are triggered *before* any of the assignments.
    // Note that DMD currently does not comply with left to right evaluation of function arguments and AssignExpression.
    int i = 2, j = 3;
    assign
    (
        i, j++,   // j = 4, i = 3
        j, j + 1, // j = 4 + 1
    );
    assert (i == 3);
    assert (j == 5);
    
    // The code is equivalent to
    // int i = 2, j = 3;
    // auto temp0 = j++;
    // auto temp1 = j + 1;
    // i = temp0;
    // j = temp1;
}

///
pure nothrow @safe @nogc unittest
{
    // Not recommanded, but possible: parallel side-effects with lvalue rhs.
    // The rhs parameters are taken by ref if possible (no-copy optimization).
    int i = 2, j = 3;
    assign
    (
        i, ++j, // caution: ++j is an lvalue with address of j.
        j, ++i, // caution: ++i is an lvalue with address of i.
    );
    assert (i == 4);
    assert (j == 4);
    
    // The code is equivalent to
    // int i = 2, j = 3;
    // ++j;
    // auto temp0 = &j;
    // ++i;
    // auto temp1 = &i;
    // i = *temp0;
    // j = *temp1;
}

///
pure nothrow @safe @nogc unittest
{
    auto id(int x) { return x; }
    int i = 2, j = 3;
    assign
    (
        i, id(++j), // caution: id(++j) is *not* an lvalue.
        j, id(++i), // caution: id(++i) is *not* an lvalue.
    );
    assert (i == 4);
    assert (j == 3);
    
    // The code is equivalent to
    // int i = 2, j = 3;
    // auto temp0 = ++j;
    // auto temp1 = ++i;
    // i = temp0;
    // j = temp1;
}

///
pure nothrow @safe @nogc unittest
{
    // Discouraged, but possible: conflicting side-effects.
    // Conflicting side-effects
    int i = 2, j = 3, k = 4;
    assign
    (
        i, ++k, // caution: ++k is an lvalue with address of k.
        j, ++k, // caution: same.
    );
    // k is modified two times before any assignment happens!
    assert (i != 5);
    assert (i == 6);
    assert (j == 6);
    assert (k == 6);
    // The code is therefore *not* equivalent to:
    //{
    //    auto temp1 = ++k;
    //    auto temp2 = ++k;
    //    i = temp1;
    //    j = temp2;
    //}
    // See also:
    // tie(i, j) = tuple(++k, ++k);

    // Instead it is equivalent to:
    //{
    //    ++k;
    //    ++k;
    //    i = k;
    //    j = k;
    //}
}

/// Checks if the given function parameter is a reference or has typeof(null).
private enum isRefOrNull(alias a) = __traits(isRef, a) || is(typeof(a) : typeof(null));

/**
 * Allows for pattern-matching against tuples.
 * Note it is @system, but if the result is not
 * bound to a variable (i.e. used as an rvalue), it can be @trusted.
 */
auto tie(Ts...)(auto ref Ts args)
{
    import std.meta : allSatisfy;
    static assert (allSatisfy!(isRefOrNull, args), "arguments to tie must be lvalues or null");
    
    struct Tie
    {
        import std.meta : staticMap;
        import std.typecons : Tuple;
        import std.experimental.typecons : Final;
        static alias Ref(T) = Final!(T*);
        
        private staticMap!(Ref, Ts) ptrs;

        this(ref Ts args) pure
        {
            foreach (i, _; Ts)
                static if (!is(T : typeof(null)))
                    ptrs[i] = &args[i];
        }
        
        // // https://issues.dlang.org/show_bug.cgi?id=16855
        // void opAssign(Rs...)(Tuple!Rs tup) pure
        // {
            // foreach (i, T; Ts) // static
                // static if (!is(T : typeof(null)))
                    // *ptrs[i] = tup[i];
        // }
        
        void opAssign(Rs...)(Tuple!Rs tup) pure
            if (Ts.length == Rs.length)
        {
            opOpAssign!""(tup); // *ptrs[i] = tup[i];
        }
        
        void opOpAssign(string op, Rs...)(Tuple!Rs tup) pure
        {
            foreach (i, T; Ts) // static
                static if (!is(T : typeof(null)))
                    mixin(`*ptrs[i].final_get `~op~`= tup[i];`);
        }
    }
    return Tie(args);
}

///
pure nothrow @nogc @trusted unittest
{
    // usage can be trusted, as the result does not escape!
    import std.typecons : tuple;
    
    int i = 2, j = 3;
    tie(i, j) = tuple(i + j, i * j); // i = 2 + 3, j = 2 * 3
    
    assert (i == 5);
    assert (j == 6);
}

///
pure nothrow @nogc @system unittest
{
    import std.typecons : tuple;
    int i = 0;
    tie(i, null) = tuple(i + 1, i + 2);
    assert (i == 1);
}

///
pure nothrow @nogc @system unittest
{
    import std.typecons : tuple;
    enum _ = null;
    int i = 0;
    tie(i, _) = tuple(i + 1, i + 2);
    assert (i == 1);
}

pure nothrow @nogc @system unittest
{
    // Not recommanded: Using tie values in variables.
    import std.typecons : tuple;
    int i = 0;
    auto t = tie(i, null);
    t = tuple(1, 2);
    assert (i == 1);
}

pure nothrow @trusted unittest // !nogc because of array concatination
{
    // Also possible: op=, if all types support the operation.
    import std.typecons : tuple;
    string s = "Hello ";
    int[] xs = [ 0, 1, 2 ];
    tie(s, xs) ~= tuple("World", [ 3, 4 ]);
    assert (s == "Hello World");
    assert (xs == [ 0, 1, 2, 3, 4 ]);
}