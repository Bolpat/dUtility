

module bolpat.append;

public import std.array : appender, Appender;

/**
 * The append[f][ln] family of functions are made for conveniance
 * to append on especially tabular results of Appender!String.
 * Works similar to write[f][ln] family.
 */
ref append(Char, Args...)(return ref Appender!(Char[]) app, auto ref Args args)
{
    import std.functional : forward;
    foreach (arg; args) app.appendf!"%s"(forward!arg);
    return app;
}
/// Ditto
ref appendln(Char, Args...)(return ref Appender!(Char[]) app, auto ref Args args)
{
    import std.functional : forward;
    return app.append(forward!args, '\n');
}

///
@safe pure unittest
{
    auto app = appender!string;
    assert(app.data == "");
    app.append(1, "-2-");
    assert(app.data == "1-2-");
}

@safe pure unittest
{
    auto app = appender!string;
    app .appendln(1, "-2-")
        .appendln(true);
    assert(app.data == "1-2-\ntrue\n");
}

///
ref appendf(alias fmt, Char, Args...)(return ref Appender!(Char[]) app, auto ref Args args)
{
    import std.format : formattedWrite;
    import std.functional : forward;
    app.formattedWrite!fmt(forward!args);
    return app;
}
/// Ditto
ref appendf(Char0, Char1, Args...)(return ref Appender!(Char0[]) app, in Char1[] fmt, auto ref Args args)
{
    import std.format : formattedWrite;
    import std.functional : forward;
    app.formattedWrite(fmt, forward!args);
    return app;
}

///
@safe pure unittest
{
    import std.meta : AliasSeq;
    alias Chars = AliasSeq!(const char, immutable char, char);
    foreach (Char; Chars)
    {
        auto app = appender!(Char[]);
        app.appendf!"%3d"(1);
        assert(app.data == "  1");
    }
    foreach (Char; Chars)
    {
        auto app = appender!(Char[]);
        app.appendf("{ %(%s | %) }", [ 0, 1, 2 ]);
        assert(app.data == "{ 0 | 1 | 2 }");
    }
}

/// Ditto
ref appendfln(alias fmt, Char, Args...)(return ref Appender!(Char[]) app, auto ref Args args)
{
    return app.appendf!fmt(args, '\n');
}
/// Ditto
ref appendfln(Char0, Char1, Args...)(return ref Appender!(Char0[]) app, in Char1[] fmt, auto ref Args args)
{
    return app.append(fmt, args, '\n');
}

///
// @safe pure unittest
// {
//     enum expect =
//         "1 2 3" ~ '\n' ~
//         "4 5 6" ~ '\n' ~
//         "7 8 9" ~ '\n' ~ '\n';
//     auto app = appender!string;
//     app.appendfln("%( %(%s %) \n%)",
//         [
//             [ 1, 2, 3 ],
//             [ 4, 5, 6 ],
//             [ 7, 8, 9 ]
//         ]);
//     assert(app.data == expect);
// }

void main()
{
    static immutable telephone = [ [ 1, 2, 3 ], [ 4, 5, 6 ], [ 7, 8, 9 ] ];
    import std.format : formattedWrite;
    import std.stdio;
    auto app = appender!string;
    app.formattedWrite!"%(%(%s %)\n%)"(telephone);
    writeln(app.data);
}