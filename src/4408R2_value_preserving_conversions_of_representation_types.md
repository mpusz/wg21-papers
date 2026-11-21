---
title: "Value-Preserving Conversions of Representation Types"
document: P4408R2
date: today
audience:
  - SG6 Numerics
  - LEWG Library Evolution Working Group
author:
  - name: Mateusz Pusz
    email: <mateusz.pusz@gmail.com>
toc-depth: 3
---


# Revision history

## R2

- SG6 asked for one rule for every conversion of a representation value: value preservation as
  defined by [@P2509R1]. The paper now proposes that rule for all representation types, so
  integer to floating-point and floating-point to floating-point conversions are covered too, and
  the title no longer says "integer".
- The requirement to keep every integer to floating-point conversion implicit is dropped.
  `quantity<m, float> f = 1 * m;` now needs an explicit conversion (see [Costs](#costs)).
- `treat_as_floating_point` is removed. Whether a unit conversion by a non-integral factor may be
  implicit is decided by `numeric_limits<T>::is_exact` (see [The unit factor](#unit-factor)).
- [Representation types defined by users](#user-types) describes how a representation type that
  isn't an arithmetic type takes part.
- The rule of [The widths of the types](#alt-width), proposed in R1, is now an alternative. For a
  pair of integer types, it gives the same answer as the proposed rule.
- `safe_int<short>` from `safe_int<int>` no longer compiles with direct initialization. It needs
  `value_cast`, as `short` from `int` does.

## R1

- The proposed rule in [The widths of the types](#alt-width) is now written with list
  initialization instead of `numeric_limits<T>::digits`.
- [Proposal](#proposal) explains how a class-type representation such as `safe_int` decides whether
  a conversion is implicit, with no specialization of `implicitly_scalable`.
- "Rank or width" was folded into [Integer conversion rank](#alt-rank), which now follows
  [The widths of the types](#alt-width).
- Shorter sections on [@P0870R8] and [@P2509R1].
- [Proposal](#proposal) also adds the rule to `$RepConstructibleFrom$` and `$RepAssignableFrom$`,
  so that `in<ToRep>()` and the construction from and the assignment of a number reject the same
  conversions as the converting constructor.
- Two quantities, two points, and a quantity and a number now compare exactly when their types are
  integer types (see [Proposal](#proposal)). A negative value compares correctly with an unsigned
  one, and the rule doesn't make `==` or `<=>` of such a pair ill-formed.

## R0

Initial revision. [@P3045R9] listed [@P0870R5] and [@P2509R1] as papers that would help to prevent
value truncation. [@P3045R10_PRE] follows the rule of `std::chrono::duration` for conversions
between integer representation types. This paper proposes to change it, and explains why it doesn't
build on either of those papers.


# Introduction

Consider a distance stored in a 16-bit integer to save memory:

```cpp
quantity<m, std::int16_t> d = 100'000 * m;
```

This compiles in [@P3045R10_PRE], and `d` holds -31072 m. So do these, and each changes the value:

```cpp
quantity<m, float> f1 = 16'777'217 * m;  // f1 holds 16'777'216 m: float has 24 binary digits
quantity<m, float> f2 = 0.1 * m;         // f2 holds the float nearest to the double nearest to 0.1
```

The library rejects a conversion that truncates a fraction, such as `quantity<m, int>` from
`1.5 * m`, and a unit conversion by a non-integral factor to an integer type, such as
`quantity<km, int>` from `1500 * m`. It accepts the conversions above because it follows the rule
of `std::chrono::duration`, which doesn't compare the representation types beyond asking whether
the destination is a floating-point type.

This paper proposes that a conversion of a representation value be implicit when, and only when,
it is value-preserving: every value of the source type is represented exactly in the destination
type, on the implementation that compiles it. This is the definition of
`is_value_preserving_convertible` proposed in [@P2509R1], and of the term "value-preserving" that
the standard already uses for `std::simd` in [simd.general]{.sref}. The paper doesn't define a rule
of its own.

This paper also proposes that two quantities with integer representation types compare exactly, as
mathematical integers. This fixes code that compiles today and gives a wrong answer, such as
`-1 * m < 1u * m`, which is `false` in [@P3045R10_PRE].


# Current design {#current-design}

In [@P3045R10_PRE], `implicitly_scalable` decides whether a conversion from
`quantity<FromUnit, FromRep>` to `quantity<ToUnit, ToRep>` is implicit:

```cpp
template<unit auto FromUnit, typename FromRep, unit auto ToUnit, typename ToRep>
constexpr bool implicitly_scalable =
  treat_as_floating_point<ToRep> ||
  (!treat_as_floating_point<FromRep> && is_integral_scaling(FromUnit, ToUnit));
```

A conversion to a floating-point type is always implicit, whatever the source type. A conversion
between integer types is implicit when the unit changes by an integral factor, and the
representation types play no other role. A user can specialize `implicitly_scalable` for a
representation type that needs another rule, and a conversion that isn't implicit has to be written
with `value_cast` or with a rounding policy.

`treat_as_floating_point` is a specializable variable template whose default applies
`std::chrono::treat_as_floating_point_v` to the underlying element type of the representation
type. Besides `implicitly_scalable`, [@P3045R10_PRE] uses it to choose how a value is scaled by a
unit magnitude, to disable `%` for floating-point types, and in an example of a range-validated
representation type.

A unit conversion that overflows the destination, such as `quantity<mm, std::int16_t>` from
`std::int16_t{100} * m`, is a separate question, and this paper doesn't change how a conversion
handles it.


# Existing practice {#existing-practice}

## `std::chrono` {#chrono}

`duration<Rep2, Period2>` converts implicitly to `duration<Rep, Period>` when
`treat_as_floating_point_v<Rep>` is `true`, or when the period ratio is integral and
`treat_as_floating_point_v<Rep2>` is `false` ([time.duration.cons]{.sref}). The representation types
themselves are not compared, so these conversions are all implicit:

```cpp
static_assert(std::is_convertible_v<duration<int>, duration<short>>);
static_assert(std::is_convertible_v<duration<long long>, duration<int>>);
static_assert(std::is_convertible_v<duration<int>, duration<unsigned>>);
static_assert(std::is_convertible_v<duration<double>, duration<float>>);

duration<std::int16_t> d = duration<int>{100'000};  // d.count() == -31072 where int has 32 bits
```

## The rest of the standard library {#std-practice}

The converting constructor of `std::complex<T>` from `std::complex<X>` is `explicit` when the
floating-point conversion rank of `T` is lower than that of `X`
([complex.members]{.sref}). [conv.rank]{.sref} orders floating-point types by the inclusion of
their sets of values, so this is a value-preserving rule for floating-point types, though one that
uses the rank: `long double` to `double` is `explicit` even where both have the same set of values.

[simd.general]{.sref} defines a value-preserving conversion: "The conversion from an arithmetic type
`U` to a vectorizable type `T` is value-preserving if all possible values of `U` can be represented
with type `T`." [@P2509R1] cites this definition as matching the intent of its trait.

## Au

[@AU] 0.6.1 forbids a conversion from a floating-point to an integer representation, and a unit
conversion whose factor makes overflow likely for a small representation. A change of the
representation alone isn't checked. Each of these compiles, and GCC diagnoses none of them by
default:

```cpp
Quantity<Meters, std::int32_t> a = meters(std::int64_t{1});
Quantity<Meters, std::int16_t> b = meters(100'000);  // b.in(meters) == -31072
Quantity<Meters, unsigned>     c = meters(-1);
```

## mp-units

[@MP-UNITS] 2.x implements the rule of [Current design](#current-design), and accepts the
`std::int16_t` example of the [Introduction](#introduction) with the same result.

Its `safe_int<T>` representation tests whether every value of the source type fits in the
destination type, using the ranges of the two types. It uses the answer to skip a runtime range
check that can't fail, and to decide whether its converting constructor is `explicit`, so
`safe_int<int>` from `safe_int<long>` is implicit on Windows and explicit on 64-bit Linux.
`safe_int<T>` specializes `numeric_limits`, so the trait of [@P2509R1] gives the same answer for it.


# What the rule has to do {#requirements}

1. **Reject an implicit conversion of a representation value that can change the value.** This
   includes `std::int16_t` from `int`, which corrupts data in the [Introduction](#introduction),
   `float` from a 32-bit `int`, and `float` from `double`.
2. **Use the definition of value preservation of the standard library.** A library-specific rule
   would answer the same question differently from `std::simd` and from the trait proposed in
   [@P2509R1], and users of both would have to learn two answers.
3. **Let representation types defined by users take part without a library-specific trait.** A
   numeric type describes itself with `numeric_limits`, and a wrapper with its own conversions.

Every rule that meets requirement 1 depends on the implementation, because the sets of values of
the arithmetic types do (see [Drawbacks of every non-portable rule](#non-portable-drawbacks)).


# Alternatives {#alternatives}

## The portable rule of `std::chrono` {#alt-chrono}

This rule gives the same answer on every implementation, and it is already familiar to anyone who
uses `std::chrono`. It accepts `std::int16_t` from `int` and `float` from `double`, so it fails
requirement 1.

## A narrowing trait, P0870 {#alt-p0870}

[@P0870R8] proposes a trait that tells whether a conversion is narrowing in the sense of list
initialization ([dcl.init.list]{.sref}). Narrowing is a property of the types and of the source
expression, not of the sets of values. A conversion from an integer type to a floating-point type is
narrowing unless the source is a constant expression whose value converts exactly, and a type trait
sees no value, so `double` from a 32-bit `int` would need an explicit conversion although it changes
no value. A conversion from `long double` to `double` is narrowing even where the two types have the
same set of values. [@P2509R1] discusses the difference between the two traits. The narrowing trait
fails requirement 1 in the other direction: it rejects conversions that preserve every value.

## The widths of the types {#alt-width}

R1 of this paper proposed this rule for pairs of integer types. A conversion between two integer
types is implicit when it isn't narrowing in the sense of list initialization:

```cpp
template<typename From, typename To>
constexpr bool $integer-value-preserving$ = true;

template<integral From, integral To>
constexpr bool $integer-value-preserving$<From, To> = requires(From f) { To{f}; };
```

`f` isn't a constant expression, and for such a source [dcl.init.list]{.sref} makes a conversion
between integer types narrowing exactly when the destination can't represent every value of the
source. For a pair of integer types, this is the answer of the proposed rule. It covers no other
pair, so it fails requirement 1 for `float` from `int` and from `double`, and it is a rule of this
library, so it fails requirement 2.

## Integer conversion rank {#alt-rank}

A conversion between two integer types is implicit when both are signed or both are unsigned and
the integer conversion rank of `To` isn't lower than that of `From` ([conv.rank]{.sref}), or when
`To` is the type that `From` promotes to ([conv.prom]{.sref}). For most pairs of standard integer
types, it gives the same answer on every implementation: `int` from `long`, for example, is
rejected everywhere.

It is rejected because it also rejects conversions that can't change any value of the source type
on the implementation at hand, and those that preserve every value are what requirement 1 asks to
keep implicit:

```cpp
void f(quantity<m, long> l, quantity<m, unsigned> u, quantity<m, std::uint16_t> u16)
{
  quantity<m, int> a = l;     // rank: error everywhere   proposed: OK on Windows, error on 64-bit Linux
  quantity<m, long> b = u;    // rank: error everywhere   proposed: OK where long is wider than unsigned
  quantity<m, long> c = u16;  // rank: error everywhere   proposed: OK everywhere
}
```

An explicit conversion tells a reader that a value can change there. Users who meet a rule that
requires one where no value can change may write explicit conversions by habit, and then those stop
telling the reader anything. The same answer on every implementation doesn't extend to the
`<cstdint>` aliases either: the rank rule rejects `std::int64_t` from `long long` on 64-bit Linux,
where `std::int64_t` is `long`, of lower rank, and accepts it on Windows, where both are the same
type.

## Drawbacks of every non-portable rule {#non-portable-drawbacks}

Whether a conversion is implicit decides whether a program is well-formed, and which overloads are
viable. Under a non-portable rule, both can change when the program moves to another implementation,
because type names, and the types of some expressions, denote different types on different
implementations: the `<cstdint>` aliases, `std::size_t`, integer literals, and the results of
integer promotion. `std::int64_t` is `long` on 64-bit Linux and `long long` on Windows. The sets of
values differ too: `long double` has 64 binary digits on x86-64 Linux and 53 with MSVC.

```cpp
void f(quantity<m, std::uint16_t> a, quantity<m, std::uint16_t> b, quantity<m, long> l)
{
  quantity<m, int> sum = a + b;      // OK where int is wider than 16 bits (the sum is int), error where it has 16 (sum is unsigned)
  quantity<m, int> q = 100'000 * m;  // OK where int is wider than 16 bits, error where it has 16 (the literal is long)
  quantity<m> d = l;                 // OK where long has 32 bits (Windows), error where it has 64 (64-bit Linux)
}
```

Where the answer depends on the implementation, ported code fails to compile exactly on the
implementation where the conversion can change a value, and that is the code to review.


# Proposal {#proposal}

## Value preservation of the representation types {#value-preserving}

The proposed rule uses the exposition-only `$value-preserving$<From, To>`:

```cpp
template<typename T>
constexpr bool $bounded-number$ =  // exposition only
  numeric_limits<T>::is_specialized && numeric_limits<T>::is_bounded;

template<typename From, typename To>
constexpr bool $value-preserving$ = @_see below_@;  // exposition only
```

1. If `$bounded-number$<From> && $bounded-number$<To>` is `true`, `$value-preserving$<From, To>` is
   `true` if and only if `is_convertible_v<From, To>` is `true` and each value of `From` is
   represented exactly by the result of the implicit conversion to `To`, special values such as
   infinities and NaNs included. This is the specification of `is_value_preserving_convertible_v`
   in [@P2509R1], including its precondition. If that paper is adopted, this case becomes
   `is_value_preserving_convertible_v<From, To>`.
2. Otherwise, if `From` or `To` has an element type other than itself, `$value-preserving$<From, To>`
   is `convertible_to<From, To> && $value-preserving$<E(From), E(To)>`, where `E(T)` is the element
   type of `T`: `representation_underlying_type_t<T>` applied until it yields the type it was
   applied to.
3. Otherwise, `$value-preserving$<From, To>` is `convertible_to<From, To>`.

For the arithmetic types, case 1 gives:

| From → To                     | Value-preserving                                    |
|-------------------------------|-----------------------------------------------------|
| `int` → `short`               | no where `short` is narrower than `int`             |
| `short` → `int`               | yes                                                 |
| `int` → `unsigned`            | no                                                  |
| `int` → `float`               | no where `int` has more than 24 binary digits       |
| `int` → `double`              | yes where `int` has at most 53 binary digits        |
| `std::int64_t` → `double`     | no                                                  |
| `std::int64_t` → `long double`| yes where `long double` has 64 binary digits        |
| `float` → `double`            | yes                                                 |
| `double` → `float`            | no                                                  |
| `long double` → `double`      | yes where both have the same set of values          |
| floating-point → integer      | no                                                  |

## The unit factor {#unit-factor}

[@P2509R1] answers whether the conversion of the representation type preserves values. A conversion
of a quantity also multiplies the value by the factor between the two units, which the trait
doesn't see. For a type that represents its values exactly, such as an integer or a fixed-point
type, an integral factor keeps every value, and any other factor truncates. For a floating-point
type, every factor rounds to the nearest representable value, which is the nature of the type and
which [@P3045R10_PRE] accepts implicitly today. The proposed rule takes this distinction from
`numeric_limits`, which the trait of [@P2509R1] is specified with:

```cpp
template<typename T>
constexpr bool $inexact$ =  // exposition only
  numeric_limits<$E$>::is_specialized && !numeric_limits<$E$>::is_exact;
```

where `$E$` is `T` if `numeric_limits<T>::is_specialized` is `true`, and `E(T)` otherwise. The
check of `is_specialized` is needed: in the primary template of `numeric_limits`, `is_exact` is
`false`, so without the check every type the library knows nothing about would be treated as
inexact, and every unit factor would be implicit for it.

## The rule {#rule}

Change the default of `implicitly_scalable` in [@P3045R10_PRE] to:

```cpp
template<unit auto FromUnit, typename FromRep, unit auto ToUnit, typename ToRep>
constexpr bool implicitly_scalable =
  $value-preserving$<FromRep, ToRep> && (is_integral_scaling(FromUnit, ToUnit) || $inexact$<ToRep>);
```

Compared with the current default, `!treat_as_floating_point<FromRep>` is covered by
`$value-preserving$`, as no conversion from a floating-point type to an exact type preserves
values, and `treat_as_floating_point<ToRep>` is replaced with `$inexact$<ToRep>`, which no longer
makes a conversion implicit on its own:

```cpp
void f(quantity<m, int> i, quantity<m, double> d, quantity<mm, int> mm_i)
{
  quantity<km, double> a = i;      // OK: int → double preserves values, double rounds 1/1000
  quantity<m, float>   b = i;      // error where int has more than 24 binary digits
  quantity<m, float>   c = d;      // error: double → float
  quantity<m, int>     e = mm_i;   // error: 1/1000 truncates an int, as today
  quantity<mm, int>    g = i;      // OK: integral factor, as today
}
```

`implicitly_scalable` constrains the converting constructor of `quantity`, as the corresponding
constraint does for `std::chrono::duration` ([time.duration.cons]{.sref}), so the rule applies to
every conversion between quantities: initialization, assignment, compound assignment, function
arguments and return values, and the conversion of the operands of `+`, `-`, and `%` to their common
quantity type. A conversion that it rejects is written with `value_cast`, such as
`value_cast<float>(q)`. A unit conversion that overflows the destination remains out of scope, as
in `std::chrono`.

The converting constructor isn't the only place where [@P3045R10_PRE] converts a representation
value. `in<ToRep>()` and `in<ToRep>(ToU)` convert it to `ToRep`. A quantity constructed from a
number and a reference converts the number to its representation type, and so does a dimensionless
quantity constructed from a number or assigned one. These are constrained with the exposition-only
`$RepConstructibleFrom$` and `$RepAssignableFrom$`, which [@P3045R10_PRE] uses without defining.
This paper proposes:

```cpp
template<typename T, typename Arg>
concept $RepConstructibleFrom$ =  // exposition only
  constructible_from<T, Arg> && $value-preserving$<remove_cvref_t<Arg>, T>;

template<typename T, typename Arg>
concept $RepAssignableFrom$ =  // exposition only
  assignable_from<T&, Arg> && $value-preserving$<remove_cvref_t<Arg>, T>;
```

With them, the lines marked `error` are ill-formed where `short` is narrower than `int` and `float`
has fewer binary digits than `int`:

```cpp
void f(quantity<m, int> q, int i, double x)
{
  auto a = q.in<short>();                          // error
  auto b = q.in<short>(truncated);                 // OK
  quantity<m, short> c(i, m);                      // error
  quantity<m, short> d(static_cast<short>(i), m);  // OK
  quantity<one, short> e = i;                      // error
  quantity<m, float> g(x, m);                      // error: double → float
  quantity<m, float> h(static_cast<float>(x), m);  // OK
}
```

## Representation types defined by users {#user-types}

A representation type that isn't an arithmetic type takes part in one of three ways, in this order:

1. **It specializes `numeric_limits`**, with `is_specialized` and `is_bounded` both `true`. The
   definition of [@P2509R1] applies to it directly, as to an arithmetic type, and `is_exact` tells
   whether it rounds. This is how [@P2509R1] expects a type defined by a user to take part, and how
   it does for the fixed-precision types of numeric libraries.
2. **It exposes an element type** through `representation_underlying_type`, such as the
   `value_type` of `std::complex<double>` or of a vector of `double`. The rule applies to the
   element types, and the conversion between the two representation types themselves has to be
   implicit.
3. **Neither.** A conversion is implicit when the representation type converts implicitly and the
   unit factor is integral. This is what such a type gets today, as `treat_as_floating_point` is
   `false` for it by default.

`implicitly_scalable` stays specializable, to override the answer for a pair of representation
types and units, as in the examples of [@P3045R10_PRE] for decimal types. A type that wants a
non-integral factor to be implicit although it represents values exactly, such as a decimal
fixed-point type that rounds, specializes `implicitly_scalable`, not `numeric_limits`: setting
`is_exact` to `false` would misdescribe the type to every other user of `numeric_limits`.

Some consequences:

```cpp
using power_f = quantity<isq::complex_power[V * A], std::complex<float>>;
using power_d = quantity<isq::complex_power[V * A], std::complex<double>>;
static_assert( std::is_convertible_v<power_f, power_d>);
static_assert(!std::is_convertible_v<power_d, power_f>);
static_assert( std::is_convertible_v<quantity<m, safe_int<short>>, quantity<m, safe_int<int>>>);
static_assert(!std::is_constructible_v<quantity<m, safe_int<short>>, quantity<m, safe_int<int>>>);
```

The last line differs from R1. `safe_int<int>` doesn't convert implicitly to `safe_int<short>`, so
the conversion isn't value-preserving under [@P2509R1], and the converting constructor of
`quantity` is removed, as it is for `short` from `int`. The conversion is written with `value_cast`,
and `safe_int` checks the value when it happens.

In [@P3045R10_PRE], the converting constructor of `quantity` is `explicit` when
`convertible_to<Rep2, rep>` is `false`. Under the proposed rule, no representation conversion that
isn't implicit satisfies the constraint of that constructor, so this part of its `explicit`
specifier has no effect, and it can be removed.

## `treat_as_floating_point` is removed {#remove-tafp}

`implicitly_scalable` was the main use of `treat_as_floating_point`. Its other uses in
[@P3045R10_PRE] change as follows:

- The scaling of a value by a unit magnitude chooses the floating-point path with
  `$inexact$<T>` instead of `treat_as_floating_point`.
- `%` and `%=` require `!$inexact$` of both representation types instead of
  `!treat_as_floating_point`.
- The example of a range-validated representation type requires `floating_point<T>`.

A representation type that specializes `treat_as_floating_point` today specializes
`numeric_limits` instead. It needs that specialization already for `quantity::min()` and
`quantity::max()`.

[@MP-UNITS] implements the rule of R1 on its version 3 line.
[Its implementation of the rule of R2 is in progress.]{.ednote}

## Exact comparisons of integer representation types {#comparisons}

[@P3045R10_PRE] compares two quantities by converting both to their common quantity type, and this
gives a wrong answer for a negative value today. When the representation types are integer types
of different signedness, such as `int` and `unsigned`, the common representation type can be the
unsigned one. A negative value then converts to a large positive one. Where `unsigned` has 32 bits,
`-1 * m < 1u * m` compiles and is `false`, because `-1` converts to `4294967295u`. For the same
reason, `-1 * m == 4294967295u * m` is `true`. The rule rejects the conversion of `int` to
`unsigned`, so on its own it would make these comparisons ill-formed instead.

This paper proposes that comparisons stop converting their operands when both representation types
are integer types. `==` and `<=>` then compare the numerical values of both operands in the common
unit as mathematical integers, which gives the results of `cmp_equal` and `cmp_less`
([utility.intcmp]{.sref}). This changes the result of code that compiles today, and the new result
is the correct one:

```cpp
static_assert(-1 * m < 1u * m);            // false in P3045R10
static_assert(-1 * km < 1u * m);           // false in P3045R10
static_assert(-1 * m != 4294967295u * m);  // false in P3045R10 where unsigned has 32 bits
static_assert(1 * km == 1000u * m);
```

[@MP-UNITS] already compares quantities with integer representation types of different signedness
this way on the development branches of 2.x and version 3, though not in a release yet. Its version
3 line also compares two points, and a quantity with a number, as proposed below.

Because no operand is converted, an overflow of the conversion to the common unit doesn't affect the
result either. `3'000'000 * km > 1 * m` is `true` even where `3'000'000'000` doesn't fit in an
`int`. The common quantity type `common_type_t<Q1, Q2>` still has to exist, so
`std::int8_t{1} * km == std::int8_t{1} * m` stays ill-formed, because `1 km` expressed in metres
overflows `std::int8_t`. Only the conversion of each operand to the common quantity type is no
longer required. For integer representation types, the unit of each operand has to scale to the
common unit by an integral factor instead (`is_integral_scaling`). With the exposition-only
`$CommonlyComparableQuantities$`, which [@P3045R10_PRE] also uses without defining, this paper
proposes:

```cpp
template<typename Q, typename Other, typename CT>
concept $ComparableIn$ =  // exposition only
  (integral<typename Q::rep> && integral<typename Other::rep> && is_integral_scaling(Q::unit, CT::unit)) ||
  (!(integral<typename Q::rep> && integral<typename Other::rep>) && constructible_from<CT, Q>);

template<typename Q1, typename Q2>
concept $CommonlyComparableQuantities$ =  // exposition only
  delta_quantity<Q1> && delta_quantity<Q2> &&
  requires { get_common_reference(Q1::reference, Q2::reference); typename common_type_t<Q1, Q2>; } &&
  $ComparableIn$<Q1, Q2, common_type_t<Q1, Q2>> && $ComparableIn$<Q2, Q1, common_type_t<Q1, Q2>>;
```

Two points with the same absolute origin compare their offsets from a common origin. Their `==` and
`<=>` require `equality_comparable_with` and `three_way_comparable_with` of their quantity types.
The rule makes both `false` for `int` and `unsigned`, because the quantity type with the `int`
representation no longer converts to their common type. Such a comparison compiles in
[@P3045R10_PRE], so the rule alone would break it. This paper proposes that, when both
representation types are integer types, these two requirements are replaced with
`$CommonlyComparableQuantities$` of the quantity types. The offsets then compare by the same rule as
two quantities. Where the two points are measured from different origins, an offset from the
absolute origin is computed with an addition, and that addition follows the rule, as the arithmetic
in [Costs](#costs) does.

A dimensionless quantity also compares with a number. Its `==` requires only
`equality_comparable_with<Rep1, Value>`, and [@MP-UNITS] 2.x compares the numerical value with the
built-in `==`, so `4294967295u * one == -1` is `true` where `unsigned` has 32 bits. Its `<=>`
requires `three_way_comparable_with<Rep1, Value>`, which `int` and `unsigned` don't satisfy. The
built-in `<=>` rejects the conversion of `int` to `unsigned`, so `-1 * one < 1u` is ill-formed.
This paper proposes that, when `Rep1` and `Value` are both integer types, `==` and `<=>` give the
results of `cmp_equal` and `cmp_less`, and `<=>` doesn't require
`three_way_comparable_with<Rep1, Value>`. Both comparisons are then well-formed and exact.

The comparisons of an integer with a floating-point representation type are not changed. Their
operands convert to the common type, and where that conversion isn't value-preserving, such as for
`long` and `double` on 64-bit Linux, the comparison is ill-formed.


# Costs {#costs}

The rule rejects conversions that [@P3045R10_PRE] accepts today. The drawbacks that follow from the
dependence on the implementation are listed in
[Drawbacks of every non-portable rule](#non-portable-drawbacks).

- Small integer values written as `int` literals are rejected. `quantity<m, short> q = 42 * m;`
  converts from `quantity<m, int>`, which is rejected where `short` is narrower than `int`. The rule
  sees only the types, so it can't accept 42 and reject 100'000. The construction from a number
  and a reference is rejected for the same reason.

  ```cpp
  quantity<m, short> q1 = 42 * m;                         // error where short is narrower than int
  quantity<m, short> q2 = short{42} * m;                  // OK
  quantity<m, short> q3 = value_cast<short>(42 * m);      // OK
  quantity<m, short> q4 = (42 * m).in<short>(truncated);  // OK
  quantity<m, short> q5(42, m);                           // error where short is narrower than int
  ```

- `float` representation types need literals of their own type. An `int` literal times a unit is a
  quantity of `int`, a `double` literal gives one of `double`, and neither converts implicitly to a
  quantity of `float`:

  ```cpp
  quantity<m, float> f1 = 1 * m;                    // error where int has more than 24 binary digits
  quantity<m, float> f2 = 1.5 * m;                  // error: double → float
  quantity<m, float> f3 = 1.5f * m;                 // OK
  quantity<m, float> f4 = value_cast<float>(1 * m); // OK
  ```

- 64-bit integers don't convert implicitly to `double`. Where `long` has 64 bits, as on 64-bit
  Linux, `quantity<m> d = n * m;` with a `long` or a `std::size_t` `n` needs an explicit conversion,
  and so does `quantity<s>` from `std::chrono::seconds` wherever its representation type has more
  than 53 binary digits. `std::chrono` makes `duration<double>` from `seconds` implicit.
- Integer promotion produces `int`. `a + b` for two `short` quantities is a quantity of `int`,
  because `short + short` is `int`. Where `short` is narrower than `int`, assigning the result back
  to a `short` quantity now needs an explicit conversion, such as `value_cast<short>(a + b)`, and so
  does `q += 1 * m` when `q` has a `short` representation. A quantity of `unsigned` no longer adds to
  a quantity of a signed integer type that isn't wider than `unsigned`, such as `int`, as the
  conversion of one of the operands to the common representation type changes the signedness.
  Comparing them with `==` and `<=>` stays valid, and gives the correct result for a negative value
  (see [Exact comparisons](#comparisons)). But `equality_comparable_with` and
  `three_way_comparable_with` become `false` for them, because they require a conversion to a common
  type, so `ranges::equal_to` and `ranges::less` reject such a pair. Mixed arithmetic of a 64-bit
  integer and a `double` quantity is rejected the same way.

  ```cpp
  void f(quantity<m, short> s1, quantity<m, short> s2, quantity<m, unsigned> u, quantity<m, int> i,
         quantity<m, long> l, quantity<m> d)
  {
    auto sum = s1 + s2;               // OK: quantity<m, int>
    quantity<m, short> s3 = s1 + s2;  // error where short is narrower than int
    s1 = value_cast<short>(s1 + s2);  // OK
    s1 += 1 * m;                      // error where short is narrower than int
    s1 += value_cast<short>(1 * m);   // OK
    auto mixed = u + i;               // error
    auto ld = l + d;                  // error where long has 64 bits
  }
  ```

- A representation type that specializes `treat_as_floating_point` has to specialize
  `numeric_limits` instead (see [`treat_as_floating_point` is removed](#remove-tafp)).

Each of these costs is a compile-time error. The conversions in the [Introduction](#introduction)
compile and give a wrong value at run time. Each of them also requires an explicit conversion that
the user may know to be safe for the values at hand. A user who meets enough of them may write
explicit conversions by habit, and then an explicit conversion no longer tells a reader where a
value can change. The proposed rule keeps this to the conversions that can change a value of their
source type.


# Straw polls

1. _An implicit conversion of a representation value in [@P3045R10_PRE] should be value-preserving
   as [@P2509R1] defines it, for every pair of representation types (as proposed: `float` from a
   32-bit `int` and from `double` need an explicit conversion). This means leaving
   [the portable rule of `std::chrono`](#alt-chrono): the same code may compile on one
   implementation and not on another._
2. _Whether a unit conversion by a non-integral factor may be implicit should be decided by
   `numeric_limits<T>::is_exact`, and `treat_as_floating_point` should be removed from
   [@P3045R10_PRE]._

   [Taken only if poll 1 has consensus.]{.ednote}

3. _In [@P3045R10_PRE], two quantities, two points, or a quantity and a number whose representation
   types are integer types should compare exactly, with the results of `cmp_equal` and `cmp_less`
   (as proposed: `-1 * m < 1u * m` becomes `true`)._

   [Independent of polls 1 and 2: the comparison gives a wrong answer for a negative value today.]{.ednote}


# Acknowledgments

Special thanks and recognition goes to [The C++ Alliance](https://cppalliance.org) for supporting
Mateusz's membership in the ISO C++ Committee and the production of this proposal.

The author also thanks **Giuseppe D'Angelo** for his work on detecting narrowing and
value-changing conversions in [@P0870R8] and [@P2509R1], which this revision builds on.

---
references:

- id: AU
  citation-label: Au
  title: "The Au Units library"
  URL: <https://aurora-opensource.github.io/au>
- id: MP-UNITS
  citation-label: mp-units
  title: "mp-units - A Physical Quantities and Units library for C++"
  URL: <https://mpusz.github.io/mp-units>
- id: P3045R10_PRE
  citation-label: P3045R10
  author:
    - family: Pusz
      given: Mateusz
  title: "Quantities and units library"
  URL: <https://wg21.link/p3045r10>

---
