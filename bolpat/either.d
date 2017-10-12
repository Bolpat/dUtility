import std.traits : CommonType;

struct Either(L, R)
{
private:
    bool _init = false;
    bool _isR  = false;
    union
    {
        L _l;
        R _r;
    }

public:
    import std.typecons : Nullable;

    alias Left  = L;
    alias Right = R;

    this(L lft)
    {
        _l    = lft;
        _isR  = false;
        _init = true;
    }

    this(R rht)
    {
        _r    = rht;
        _isR  = true;
        _init = true;
    }

    void opAssign(L lft)
    {
        _l    = lft;
        _isR  = false;
        _init = true;
    }

    void opAssign(R rht)
    {
        _r    = rht;
        _isR  = true;
        _init = true;
    }

    bool initialized() @property { return _init; }
    bool isL() @property { return _init && !_isR; }
    bool isR() @property { return _init &&  _isR; }

    L left() @property
    in { assert (isL); }
    body { return _l; }

    R right() @property
    in { assert (isR); }
    body {return _r; }

    void left (L l) @property { _l = l; _isR = false; }
    void right(R r) @property { _r = r; _isR = true ; }

    bool opCast(T : bool)() { return initialized; }

    L opCast(L)() { return left ; }
    R opCast(R)() { return right; }

    /**
     * Whish gives you the desired content or null depending the state of the Either instance.
     * If the both types are distinct enough, there is a whish function that defers the type.
     *
     * Usage:
     * ---
     *  Either!(L, R) e;
     *  // ...
     *  L l;
     *  R r;
     *  if (e.whish(l)) { /+ ... +/ }
     *  if (e.whish(r)) { /+ ... +/ }
     *  // or
     *  if (auto l = e.whishL) { /+ ... +/ }
     *  if (auto r = e.whishR) { /+ ... +/ }
     * ---
     */
    bool whishL(out L l) { if (isL) l = _l; return isL; }
    /// ditto
    bool whishR(out R r) { if (isR) r = _r; return isR; }
    /// ditto
    Nullable!L whishL() { if (isL)  return Nullable!L(_l);  else  return Nullable!L.init; }
    /// ditto
    Nullable!R whishR() { if (isR)  return Nullable!R(_r);  else  return Nullable!R.init; }

    ///
    static if (!is (L : R) && !is(R : L))
    {
        /// ditto
        bool whish(out L l) { if (isL) l = _l;  return isL; }
        /// ditto
        bool whish(out R r) { if (isR) r = _r;  return isR; }
    }

    /**
     * Usage:
     * ---
     *  alias E = Either!(L, R);
     *  E e;
     *  // ...
     *  auto result = e.cases
     *  (
     *      (E.Left  l) => f(l),
     *      (E.Right r) => g(r),
     *      default
     *  );
     *  // if e is initialized, just
     *  auto result = e.cases
     *  (
     *      (E.Left  l) => f(l),
     *      (E.Right r) => g(r),
     *  );
     * ---
     */
    auto cases(DG1, DG2)(DG1 lf, DG2 rf)
    {
        assert (initialized, "The " ~ typeof(this).stringof ~ " instance has not been initialized yet.");
        if (isL) return lf(_l);
        else     return rf(_r);
    }

    auto cases(DG1, DG2, D)(DG1 lf, DG2 rf, D t)
    {
        if (!_init) return t;
        if (_isR)   return rf(_r);
        else        return lf(_l);
    }
}


import std.stdio;

void main()
{
    alias E = Either!(int, string);
    E e;
    
    writefln("%d", e.cases
        (
        (E.Left  i) => i,
        (E.Right s) => s.length,
        0
        )
    );
    e = 1;
    while (e.isL)
    {
        if (auto l = e.whishL)
        {
            writefln("%s", l);
        }
        else if (auto r = e.whishR)
        {
            writefln("%s", r);
        }
        writefln("%d", e.cases
            (
            (E.Left  i) =>
                i,
            (E.Right s) =>
                s.length
            )
        );
        e = "hello";
    }
}