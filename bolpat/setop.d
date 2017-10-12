
// Written in D Programming Language //

// Copyright by Q. F. Schroll
// the Boost License

module bolpat.setop;

bool distinct(T)(const T[] xs)
{
    foreach (i, x; xs[ 0  .. $])
    foreach (   y; xs[i+1 .. $])
    if (x == y)
        return false;
    return true;
}

bool disjoint(T)(const T[] xs, const T[] ys)
{
    foreach (x; xs)
    foreach (y; ys)
    if (x == y)
        return false;
    return true;
}