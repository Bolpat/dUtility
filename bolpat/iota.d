// Written in the D programming language.
//
// The MIT License (MIT)
//
// Copyright (c) 2016 Q. F. Schroll


module bolpat.iota;


import bolpat.meta : AliasSeq, Replicate;

/**
 * At first, behaves like std.range.iota when used like
 * `iota(args...)`;
 * adds nested iteration support, i.e.
 * ----
 * foreach (i, j, k; iota[1 .. l, 1 .. m, 1 .. n])
 * { }
 * // behaves like
 * foreach (i; 1 .. l)
 * foreach (j; 1 .. m)
 * foreach (k; 1 .. n)
 * { }
 * ----
 * The multiple syntax does not provide steps other than 1.
 */
struct iota
{
    static auto opCall(Args...)(Args args)
    {
        static import std.range;
        return std.range.iota(args);
    }

    static ptrdiff_t[2] opSlice(size_t i)(ptrdiff_t l, ptrdiff_t u)
    {
        return [ l, u ];
    }

    static Result!(Args.length) opIndex(Args...)(Args args)
    {
        typeof(return) result;
        foreach (i, Arg; Args)
            static if (is (Arg : ptrdiff_t))
                result.ranges[i] = [ 0, args[i] ];
            else static if (is (Arg == ptrdiff_t[2]))
                result.ranges[i] = args[i];
            else
                static assert (0, "iota[ ]: Invalid argument type: " ~ Arg.stringof);
        return result;
    }

    struct Result(size_t rk)
    {
        import std.format : format;

        // Idcs = ptrdiff_t, ..., ptrdiff_t (rk-times)
        alias Idcs = Replicate!(rk, ptrdiff_t);

        ptrdiff_t[2][rk] ranges;

        mixin(opApplyCode.format("Reverse", "ranges[k][1] - 1", "dec"));
        mixin(opApplyCode.format("",        "ranges[k][0]",     "inc"));
        // Same code for opApply and opApplyReverse with minor changes.
        enum opApplyCode =
        q{
            int opApply%s(scope int delegate(ref Idcs) dg)
            {
                foreach (s; ranges)
                    if (s[0] >= s[1])
                        return 0;

                Idcs idcs; // placeholder is initial value, i.e. ranges[k][0] or ranges[k][1] - 1
                foreach (k, ref idx; idcs)
                    idx = %s;

                bool inc()
                {
                    foreach_reverse (k, ref idx; idcs)
                        if (++idx == ranges[k][1])  // increase k-th index
                            idx = ranges[k][0];     // rebase if hit the upper bound
                        else
                            return true;            // stop if not
                    return false;                   // all indices rebased
                }

                bool dec()
                {
                    foreach_reverse (k, ref idx; idcs)
                        if (idx-- == ranges[k][0])  // decrease k-th index
                            idx = ranges[k][1] - 1; // rebase if had the lower bound
                        else
                            return true;            // stop if not
                    return false;                   // all indices rebased
                }

                int result;
                while ((result = dg(idcs)) == 0 && %s) { } // placeholder is inc or dec.
                return result;
            }
        };

        // TODO: toString
    }
}

debug unittest
{
    import std.stdio;

    foreach (i, j, k; iota[3, 3, 3])
    {
        writefln("%d, %d, %d", i, j, k);
    }
    writefln("");
    foreach_reverse (i, j, k; iota[3, 3, 3])
    {
        writefln("%d, %d, %d", i, j, k);
    }
    writefln("");
    foreach(i; iota(3))
    {
        writefln("%d", i);
    }

    alias Matrix = real[][];
    uint l = 3, m = 4, n = 5;
    
    Matrix A = new Matrix(l, m), B = new Matrix(m, n), C = new Matrix(l, n);
    foreach (i, j, k; iota[l, n, m])
        C[i][j] += A[i][k] * B[k][j];
}