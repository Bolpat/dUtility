// Wiritten in D Programming Language

/** Supplies the `prefix` and `postfix` functionality
  * to make easy to read comparisons for strings of the form
  * `str.prefix == "example"` and `str.postfix == "example"`.
  * 
  * Copyright:  Quirin F. Schroll aka Bolpat
  * License:    The Boost License Version 1.0
  */
module bolpat.prefix;

/**
 */
struct prefix
{
    string data;
    
    bool opEquals(string rhs)
    {
        import std.algorithm.searching : startsWith;
        return data.startsWith(rhs);
    }
}

///
unittest
{
    string x = "12345";
    assert(x.prefix == "");
    assert(x.prefix == "1");
    assert(x.prefix == "12");
    assert(x.prefix == "123");
    assert(x.prefix == "1234");
    assert(x.prefix == "12345");
}

/**
 */
struct postfix
{
    string data;
    
    bool opEquals(string rhs)
    {
        import std.algorithm.searching : endsWith;
        return data.endsWith(rhs);
    }
}

///
unittest
{
    string x = "12345";
    assert(x.postfix ==      "");
    assert(x.postfix ==     "5");
    assert(x.postfix ==    "45");
    assert(x.postfix ==   "345");
    assert(x.postfix ==  "2345");
    assert(x.postfix == "12345");
}
