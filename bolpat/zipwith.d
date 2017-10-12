// Written in the D programming language.
//
// The MIT License (MIT)
//
// Copyright (c) 2016 Q. F. Schroll


// TODO: Fixme!

module bolpat.zipwith;


template zipWith(funs...)
if (funs.length > 0)
{
    import std.meta : allSatisfy;
    import std.range.primitives;
    
    auto zipWith(R)(R range)
    {
        return map!funs(range);
    }

    auto zipWith(Ranges...)(Ranges ranges)
    if (Ranges.length > 1 && allSatisfy!(isInputRange, Ranges))
    {
        return ZipWith!Ranges(ranges);
    }

    struct ZipWith(Ranges...)
    {
    private:
        import std.meta : staticMap;
        import std.range : Zip, StoppingPolicy;
        import std.functional : binaryFun, adjoin;
        
        Zip!Ranges z;
        
        static if (Ranges.length == 2)
        {
            alias fun = adjoin!(staticMap!(binaryFun, funs));
        }
        else
        {
            alias fun = adjoin!funs;
        }
        
    public:
        this(Ranges rs, StoppingPolicy s = StoppingPolicy.shortest)
        {
            z = Zip!Ranges(rs, s);
        }

        alias empty = z.empty;

        static if (allSatisfy!(isForwardRange, Ranges))
        auto save() @property
        {
            return this;
        }

        auto front() @property
        {
            return fun(z.front.expand);
        }

        static if (allSatisfy!(isBidirectionalRange, Ranges))
        auto back() @property
        {
            return fun(z.back.expand);
        }

        alias popFront = z.popFront;
        
        static if (allSatisfy!(isBidirectionalRange, Ranges))
        alias popBack = z.popBack;


        static if (allSatisfy!(hasLength, Ranges))
        {
        alias length = z.length;
        alias opDollar = length;
        }

        static if (allSatisfy!(hasSlicing, Ranges))
        auto opSlice(size_t from, size_t to)
        {
            return ZipWith!(typeof(z[from .. to]))(z[from .. to]);
        }

        static if (allSatisfy!(isRandomAccessRange, Ranges))
        auto opIndex(size_t n)
        {
            //TODO: Fixme! This may create an out of bounds access
            //for StoppingPolicy.longest

            return fun(z[n].expand);
        }
    }
}

///
unittest
{
    auto names = [ "Anton", "Berta", "Caesar", "Dietmar" ];
    auto idcs  = [ 2, 1, 3, 3 ];
    auto test = zipWith!"a[b]"(names, idcs);
    assert (test == "test");
}