// Written in D Programming Language //

// Copyright by Q. F. Schroll
// the Boost License

module bolpat.mix;

private string mixE(string expr)
{
    import std.array : appender;
    import std.algorithm.searching : startsWith;
    
    auto result = appender!string("mixin(q\"delim\n");
    
    alias test = st => expr.startsWith(st);
    void next(size_t skip = 1) { expr = expr[skip .. $]; }
    for (; expr != ""; next)
    {
        // ignore everything inside string literals
        if (test("\""))
        {
            do
            {
                result ~= expr[0];
                next;
            }
            while (!test("\""));
            result ~= expr[0];
        }
        else if (test("`"))
        {
            do
            {
                result ~= expr[0];
                next;
            }
            while (!test("`"));
            result ~= expr[0];
        }
        // Delimited Strings not supported... sorry
        // Comments not supported
        
        else if (test("${"))
        {
            next(2);
            result ~= "\ndelim\"~(";
            while (!test("}"))
            {
                result ~= expr[0];
                next;
            }
            result ~= ")~q\"delim\n";
        }
        
        else
        {
            result ~= expr[0];
        }
    }
    
    result ~= "\ndelim\")";
    return result.data;
}

/**
 * Converts a string of the form
 * `q{ text ${AssignExpression} text ${AssignExpression} ... }`
 * to
 * `mixin(q"delim text delim"~(AssignExpression)~q"delim text delim"~(AssignExpression)~q"delim ... delim"`.
 * This can be used in
 * `mixin(q{ foo ${op}= bar; }.mix)`;
 */
string mix(string stmnt)
{
    import std.string : stripRight;
    import std.algorithm.searching : endsWith;
    
    if (stmnt.stripRight.endsWith(";"))
        return mixE(stmnt) ~ ';';
    
    return mixE(stmnt);
}

unittest
{
    enum op = "~";
    
    string a = "x";
    // mixin{ a ${op}= "y" };
    mixin(q{
        a ${op == "~" ? "~" : "~"}= "y";
    }.mix);
    assert (a == "xy");
}