// The MIT License (MIT)
//
// Copyright (c) 2016 Q. F. Schroll

module bolpat.meta;

public import std.meta;

/**
 * Creates a template, that ignores the parameters and returns a given alias.
 */
template Const(alias T)
{
    alias Const(S...) = T;
}

/// ditto
template Const(T...)
{
    alias Const(S...) = T;
}

/**
 * Creates a sequence values, similar to how $(D iota) does, but compile-time.
 */
template Iota(int stop)
{
    static if (stop <= 0) alias Iota = AliasSeq!();
    else                  alias Iota = AliasSeq!(Iota!(stop - 1), stop - 1);
}

/// ditto
template Iota(int start, int stop, int step = 1)
{
    static assert(step != 0, "Iota: step must be != 0");
    static if (step > 0)
        static if (stop <= start) alias Iota = AliasSeq!();
        else                      alias Iota = AliasSeq!(Iota!(start, stop - step, step), stop - step);
    else
        static if (stop >= start) alias Iota = AliasSeq!();
        else                      alias Iota = AliasSeq!(Iota!(start, stop - step, step), stop - step);
}

/**
 * Returns $(D F!(F!(...(F!(X))...))) with $(I n) iterations of $(D F).
 */
template Iterate(alias F, uint n, X)
{
    static if (n == 0)
        alias Iterate = X;
    else static if (n == 1)
        alias Iterate = F!X;
    else
        alias Iterate = Iterate!(F, n-1, F!X);
}

///
unittest
{
    alias Array(T) = T[];

    static assert (is (Iterate!(Array, 0, int) == int));
    static assert (is (Iterate!(Array, 4, int) == int[][][][]));
}

/// Repeats the $(D TList) sequence n times.
alias Replicate(size_t n, TList...) = staticMap!(Const!TList, Iota!n);

///
unittest
{
    alias EL = Replicate!(0, int);
    alias I4 = Replicate!(4, int);
    alias IU = Replicate!(2, int, uint);
    static assert (is ( EL == AliasSeq!() ));
    static assert (is ( I4 == AliasSeq!(int,  int, int,  int) ));
    static assert (is ( IU == AliasSeq!(int, uint, int, uint) ));
}