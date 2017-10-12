
template Ref(T...)
    if (T.length > 1)
{
    import std.meta : staticMap;
    alias Ref = staticMap!(Ref, T);
}

template Ref(T)
{
    static if (is(T == class) || is(T == Ref!S, S))
    {
        alias Ref = T;
    }
    else
    {
        struct Ref
        {
            @disable this();
            @disable this(this);

            this(ref T value)
            {
                ptr = &value;
            }

        @safe:
            ref opAssign(R)(auto ref R value)
            {
                return *ptr = value;
            }

            alias get this;

        private pure nothrow @nogc @safe:
            T* ptr;

            invariant
            {
                assert(ptr !is null);
            }

            pragma (inline, true)
            ref get() @property
            {
                return *ptr;
            }
        }
    }
}

@system unittest
{
    int i = 1;
    Ref!int r = i;
    int j = r = 2;
    assert (i == 2);
    assert (j == 2);
}

void rebindRef(T)(auto ref Ref!T reference, ref T value) @system
{
    reference.ptr = &value;
}

@system unittest
{
    int i = 1;
    int j = 2;
    Ref!int r = i;
    assert(r == 1);
    rebindRef(r, j);
    assert(r == 2);
}

@system unittest
{
    int i = 1, j = 2;
    Ref!int[] rs = [ Ref!int(i), Ref!int(j) ];
    rs[0] = 3;
    rs[1] = 4;
    assert(i == 3 && j == 4);
}