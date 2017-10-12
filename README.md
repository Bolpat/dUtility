# dUtility
Some uitility functions for D Programming Language standard library Phobos.

Die Module stellen eine Erweiterung der Funktionalität der D-Standardbibliothek Phobos dar. Besonderes Augenmerk liegt auf statischen Arrays, die in Phobos zu kurz kommen. Oft ist es nämlich praktisch, mit statischen Arrays, wie mit Ranges umgehen zu können, was mit Phobos alleine kaum praktikabel scheint. Grund für die Ausarbeitung des Moduls `staticarray` war die verwendung statischer Arrays in der `array`-Struktur des gleichnamigen Moduls.

## staticarray
Das Modul stellt Folgendes zur Verfügung. Alle adaptierten Funktionen beginnen mit static.
- `makestatic` ist eine Identitätsfunktion, die jedoch via Templates so gestaltet ist, dass sie nur statische Arrays annimmt. Das spielt eine Rolle bei Array-Literalen, die nur dann statisch sind, wenn es erforderlich ist, z.&nbsp;B. bei der Zuweisung an eine entsprechende Variable ‒ aber eben auch wenn eine Funktion einen entsprechend typisierten Parameter besitzt. Wenn ein Array-Literal mit eine `mixin` erzeugt wird, ist der Typ oft nicht trivial zu bestimmen. Für die Anweisung `cast(T[d]) [ content ]` ist das aber nötig. Hiermit entfällt die Angabe und es genügt `[ content ].makestatic` zu schreiben.
- `staticiota` erstellt eine Enum-Konstante die im Sinne von `std.range.iota` wie gewünscht ist.
- `staticmap` (nicht zu verwechseln mit `std.meta.staticMap`) adaptiert `std.algorithm.iteration.map` für statische Arrays.
- `staticreduce` adaptiert `std.algorithm.iteration.reduce` für statische Arrays.
- `staticZipWith` adaptiert `bolpat.zipwith.zipWith`, eine oft gewünschte Funktion, die Phobos derzeit nicht bereitstellt, für statische Arrays.

Die Rückgabewerte aller Funktionen in diesem Modul sind statische Arrays mit der erwarteten Größe. Alle Funktionen sind von sich aus `@nogc`, `@safe`, `nothrow` und `pure`. Manche haben Funktionsparameter, sodass ggf. Attribute wegfallen, falls die Parameterfunktion sie nicht hat.

## meta
Das Modul erweitert `std.meta` und importiert dieses transparent. Es stellt einige einfache, dennoch praktische Templates bereit.
- `Const!(T...)` gibt ein Template zurück, das seine Parameter ignoriert und zu T auswertet.
- `Iota!(start = 0, stop, step = 1)` gibt eine Sequenz von Zahlen im Sinne von `std.range.iota` zurück.
- `Iterate!(F, n, X)` wendet `F` `n`-mal auf `X` an.
- `Replicate!(n, TList...)` gibt eine Sequenz aus `n` Widerholungen von `TList` zurück.

```d
/// Repeats the TList sequence n times.
alias Replicate(size_t n, TList...) = staticMap!(Const!TList, Iota!n);
```

## indexing
Das Modul stellt praktische Funktionen zum indizieren höherer Objekte bereit. Dazu gehören die Struktoren `Dollar` und `Slice`, die als Ergebisse von `opDollar` und `opSlice` vorgesehen sind. Es werden auch Trivialimplementierungen gegeben, die jedoch keine Contracts besitzten und daher nicht empfohlen werden. Das Template `Slices!rk` erstellt eine Sequenz aufsteigender `Slice`-Typen der Länge `rk`.
- `flatten` erlaubt das durchlaufen der Elemente eines höheren Arrays <i>(jagged array)</i> auf einer angegebenen Tiefe. Die innere Struktur des Arrays der dazwischenliegenen Stufen wird ignoriert. Rückwärtiges Durchlaufen ist mit einem Overhead verbunden; schreibender Zugriff ist möglich, falls das Array beschreibbar ist.
- `multiIndex(upperBounds)` liefert eine Struktur, die ein Zählrad mit entsprechend vielen Stufen implementiert. Es gibt die Operatoren `++`, `--`, `+ n` und `- n`, sowie über `cast(bool)` bzw. `!` den Test, ob die Struktur am Anfang steht. Soll der MultiIndex nicht be `0` zu zählen beginnen, so wird dies mit
- `multiIndex[lowerBounds .. upperBounds]` vermittelt. Ein MultiIndex kann wie ein `std.typecons.Tuple` über `expand` zerlegt werden und so elegant für höhere Index-Operatoren eingesetzt werden.

## implicit
Die Programmiersprache D besitzt das C++-Konzept von impliziter Typumwandlung nur in stark eingeschränkter Form. Eine  Typumwandlung mittels Konstruktoren findet insbesondere nicht für Funktionsparameter statt ‒ auch dann nicht, wenn die Funktion eindeutig bestimmt ist. Dann nämlich ist die Anwendung von Konstruktoren unproblematisch. Das Modul stellt die Funktion `implicit` zur Verfügung, die das nachbessert. Nebenbei gibt es die Funktion `pointwiseApply`, die eine Funktuonsverknüpfung darstellt, jedoch nicht wie `std.functional.compose` sequenziell, sondern parallel (N.&nbsp;B. ich verstehe nicht den Sinn, `compose` und `pipe` beide für fast dasselbe zu verwenden).

Sei `Z f(Y1, ..., Yn)` eine `n`-stellige Funktion und seien `Y1 g1(X1), ..., Yn gn(Xn)` einstellige Funktionen. Dann ist
```
pointwiseApply!(f, g1, ..., gn)(x1, ..., xn) === f(g1(x1), ..., gn(xn))
```
So wird jedem Parameter `xi` von `f` eine entsprechende Funktion `gi` vorgeschaltet.

Die Template-Funktion `implicit` ist nur ein Spezialfall davon. Jederm Parameter vom Typ `T` wird die Funktion `to!T` aus dem Modul `std.conv` vorgschaltet, die zu ihm konvertiert. Die Funktion `to!T` nutzt Konstruktoren zur Umwandlung, kommt aber auch mit eingebauten Typen (wie `int`) zurecht. Es gnügt nämlich nicht, lediglich Konstruktoren vorzuschalten, da die eingebauten Typen keine besitzen.

Sie wurde erstellt für den Fall eines Index-Operators mit fester, aber beliebiger Anzahl von Parametern, die zwar alle Slices sind, aber es sollen auch Werte und Dollars eingesetzt werden können (der Slice-Konstruktor erstellt dann ein Slice der Länge 1 bzw. der Länge des Dollars). Die Art der Umsetzung hier und auch für beliebige Funktionen ist wie folgt:
```d
auto opIndex(Args...)(Args... args)
{
  static index(Slices!rk ss)
  {
    // function logic here ...
    return result;
  }
  return implicit!index(args);
}
```
Die `index`-Funktion nimmt `rk` Slices vom Typ `Slice!0` ... `Slice!(rk-1)` an.
