
module bolpat.twin;

import std.range : isInputRange;

/**
 * Iterates a range by pairs of consecutive elements.
 */
auto twin(R)(R range)
{
    return Twin!R(range);
}

///
struct Twin(R)
    if (isInputRange!R)
{
    import std.range;
    private alias Elem = ElementType!R;

    R range;

    private enum opApplyImpl =
        q{
            if (range.empty) return 0;
            for
            (
                auto index = cast(size_t)0, oldFront = range.front;
                { range.popFront; return !range.empty; }();
                index += 1, oldFront = range.front
            )
            {
                if (auto r = dg(index, oldFront, range.front)) return r;
            }
            return 0;
        };
    static if (is(typeof(range.front = range.front)))
        int opApply(in int delegate(size_t, Elem, ref Elem) dg)
        {
            mixin(opApplyImpl);
        }
    else
        int opApply(in int delegate(size_t, Elem,     Elem) dg)
        {
            mixin(opApplyImpl);
        }
    
    static if (is(typeof(range.front = range.front)))
        int opApply(in int delegate(Elem, ref Elem) dg)
        {
            return opApply(
                    delegate int(size_t, Elem e0, ref Elem e1)
                    {
                        return dg(e0, e1);
                    }
                );
        }
    else
        int opApply(in int delegate(Elem,     Elem) dg)
        {
            return opApply(
                    delegate int(size_t, Elem e0,     Elem e1)
                    {
                        return dg(e0, e1);
                    }
                );
        }
}

///
unittest
{
    auto array = [ 0, 1, 2, 3 ];
    foreach (a, ref b; array.twin)
        assert (a < b);
}

///
unittest
{
    import std.range : iota;
    auto array = iota(0, 4);
    foreach (a, b; array.twin) // b cannot be ref
        assert (a < b);
}