
Result!T result(T)(T* r) { return Result!T(r); }

struct Result(T)
{
    private bool okay = false;
    private T result;
    
    this(T  result) { this.result = result; okay = true; }
    this(T* result) { if (result) { this.result = *result; okay = true; } }
    alias result this;
    
    bool opCast(T : bool)() { return okay; }
}

unittest
{
    static Result!int test0(int v)
    {
        if (v == 0) return Result!int.init;
        return Result!int(v);
    }
    
    static int test1(int v)
    {
        if (auto r = test0(v)) return r;
        return 0;
    }
}

unittest
{
    int[int] aa = [ 0: 1 ];
    if (auto r = result(0 in aa)) { assert(1); int i = r; }
    if (auto r = result(1 in aa)) { assert(0); int i = r; }
}