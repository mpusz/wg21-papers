---
title: "Implicit Conversions Between Integer Representation Types"
document: P4408R1
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

## R1

- The proposed rule in [The widths of the types](#alt-width) is now written with list
  initialization instead of `numeric_limits<T>::digits`.
- [Proposal](#proposal) explains how a class-type representation such as `safe_int` decides whether
  a conversion is implicit, with no specialization of `implicitly_scalable`.
- "Rank or width" was folded into [Integer conversion rank](#alt-rank), which now follows
  [The widths of the types](#alt-width).
- Shorter sections on [@P0870R8] and [@P2509R1].

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

This compiles in [@P3045R10_PRE], and `d` holds -31072 m. The library rejects a conversion that
truncates a fraction, such as `quantity<m, int>` from `1.5 * m`, and a unit conversion by a
non-integral factor, such as `quantity<km, int>` from `1500 * m`. It accepts the conversion above
because it follows the rule of `std::chrono::duration`, which doesn't compare integer types.

Quantities are often stored in small integer types. Sensor readings, register values, and
fixed-point formats use 8-bit and 16-bit integers, and this is where such a wraparound does harm.

This paper proposes that a conversion between two integer representation types be implicit when, and
only when, the destination can represent every value of the source on the implementation that
compiles it. This is the answer that list initialization ([dcl.init.list]{.sref}) gives for
narrowing from a non-constant expression of one integer type to another, and it needs no new type
trait. The paper also describes a rule based on the integer conversion rank, which gives the same
answer on every implementation for more pairs of types, and explains why it is rejected.


# Current design {#current-design}

In [@P3045R10_PRE], `implicitly_scalable` decides whether a conversion from
`quantity<FromUnit, FromRep>` to `quantity<ToUnit, ToRep>` is implicit:

```cpp
template<unit auto FromUnit, typename FromRep, unit auto ToUnit, typename ToRep>
constexpr bool implicitly_scalable =
  treat_as_floating_point<ToRep> ||
  (!treat_as_floating_point<FromRep> && is_integral_scaling(FromUnit, ToUnit));
```

A conversion to a floating-point type is always implicit. A conversion between integer types is
implicit when the unit changes by an integral factor, and the representation types play no
other role. A user can specialize `implicitly_scalable` for a representation type that needs
another rule, and a conversion that isn't implicit has to be written with `value_cast` or with a
rounding policy.

A unit conversion that overflows the destination, such as `quantity<mm, std::int16_t>` from
`std::int16_t{100} * m`, is a separate question, and this paper doesn't change it.


# Existing practice {#existing-practice}

## `std::chrono` {#chrono}

`duration<Rep2, Period2>` converts implicitly to `duration<Rep, Period>` when
`treat_as_floating_point_v<Rep>` is `true`, or when the period ratio is integral and
`treat_as_floating_point_v<Rep2>` is `false` ([time.duration.cons]{.sref}). The integer types
themselves are not compared, so these conversions are all implicit:

```cpp
static_assert(std::is_convertible_v<duration<int>, duration<short>>);
static_assert(std::is_convertible_v<duration<long long>, duration<int>>);
static_assert(std::is_convertible_v<duration<int>, duration<unsigned>>);

duration<std::int16_t> d = duration<int>{100'000};  // d.count() == -31072 where int has 32 bits
```

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
`safe_int<int>` from `safe_int<long>` is implicit on Windows and explicit on 64-bit Linux. This
paper proposes the same answer for conversions between integer representation types of `quantity`.


# What the rule has to do {#requirements}

1. **Reject a conversion between integer representation types that can change the value.**
   `std::int16_t` from `int` is the case that corrupts data in the [Introduction](#introduction).
2. **Keep integer to floating-point conversions implicit.** `quantity<m> d = 1 * m;` converts
   `quantity<m, int>` to `quantity<m, double>`, and `double` is the
   default representation type. Rejecting it would break a very common conversion in the
   library, and `std::chrono` makes it implicit too.
3. **Need nothing that the standard doesn't have.** The rule has to be specifiable in
   [@P3045R10_PRE] without waiting for another proposal.

A fourth property divides the alternatives below: whether the same code may compile on one
implementation and not on another. [Alternatives](#alternatives) explains why every rule that meets
requirement 1 depends on the implementation, and [Integer conversion rank](#alt-rank) explains
why this paper prefers the rule of [The widths of the types](#alt-width) to one that, for most pairs
of standard integer types, depends on the implementation less.


# Alternatives {#alternatives}

The alternatives split in two. A rule that, like the one of `std::chrono`, asks only whether a
representation type is a floating-point one gives the same answer on every implementation. A rule
that meets requirement 1 can't, because it has to compare the integer types, and common type names
denote different types on different implementations (see [Drawbacks of every non-portable
rule](#non-portable-drawbacks)). This holds even for the strictest such rule, which makes every
conversion between two distinct integer types explicit: `long long` and `std::int64_t` are the same
type on some implementations and distinct types on others. That rule also rejects more conversions
between integer types than any rule below.

## The portable rule of `std::chrono` {#alt-chrono}

This rule meets requirements 2 and 3, gives the same answer on every implementation, and it is
already familiar to anyone who uses `std::chrono`. It accepts `std::int16_t` from `int`, so it fails
requirement 1.

## Non-portable rules {#non-portable}

Each rule below meets requirement 1. [Drawbacks of every non-portable rule](#non-portable-drawbacks)
describes what they have in common.

### A narrowing trait, P0870 {#alt-p0870}

[@P0870R8] proposes a trait that tells whether a conversion is narrowing in the sense of list
initialization ([dcl.init.list]{.sref}). In 2026, LEWG voted to forward it to LWG for C++29, to be
confirmed by an electronic poll. It is close to being part of the standard, but it isn't in it
yet, so it fails requirement 3.

Used for every pair of representation types, it also fails requirement 2. A conversion from an
integer type to a floating-point type is narrowing unless the source is a constant expression whose
value converts exactly, and a type trait sees no value. `quantity<m> d = 1 * m;` would need
`value_cast<double>(1 * m)`.

[The widths of the types](#alt-width) uses the same check that the trait is built on, list
initialization, but applies it to pairs of integer types only. It doesn't have to wait for the
trait.

### A value-preservation trait, P2509 {#alt-p2509}

[@P2509R1] proposes `is_value_preserving_convertible<From, To>`, which is `true` when every value of
`From` is represented exactly in `To`. Its motivation cites [@P2980R1], the proposed quantities and
units library, as a use case. For a pair of integer types, both this trait and the one of
[@P0870R8] give the answer this paper proposes.

It fails requirement 2. `double` from `std::int64_t` and `float` from `int` where `int` has 32 bits
aren't value-preserving, so `quantity<m, float> f = 1 * m;` would need an explicit conversion. It
also fails requirement 3, and it isn't close to the standard. SG6 polled it in 2022 with weak
consensus (2/1/4/1/0) and the comment that more motivation was needed, and reviewed R1 at Sofia 2025
without a poll. It needs a revision.

### The widths of the types {#alt-width}

A conversion between two integer types is implicit when it isn't narrowing in the sense of list
initialization ([dcl.init.list]{.sref}):

```cpp
template<typename From, typename To>
constexpr bool $integer-value-preserving$ = true;

template<integral From, integral To>
constexpr bool $integer-value-preserving$<From, To> = requires(From f) { To{f}; };
```

`f` isn't a constant expression, and for such a source [dcl.init.list]{.sref} makes a conversion
between integer types narrowing exactly when the destination can't represent every value of the
source. That is requirement 1, and checking it needs nothing outside the standard. Whether a
conversion is narrowing depends on the widths of the types: `int i{l};` for a non-constant `long l`
is well-formed on Windows and ill-formed on 64-bit Linux. The type that an
integer type promotes to can represent every value of it, so the rule needs no special case for
promotion. It meets requirements 1, 2, and 3.

A library can compute the same answer from `numeric_limits<From>` and `numeric_limits<To>`, by
checking that `min()` and `max()` of `From` are within those of `To`. The comparison has to be
sign-aware, such as with `cmp_less_equal`, because the built-in `<=` can convert a signed operand to
an unsigned type first.

### Integer conversion rank {#alt-rank}

A conversion between two integer types is implicit when both are signed or both are unsigned and
the integer conversion rank of `To` isn't lower than that of `From` ([conv.rank]{.sref}), or when
`To` is the type that `From` promotes to ([conv.prom]{.sref}). The promotion case is needed
because the arithmetic operators convert both operands to the type of the result:

```cpp
auto c = std::uint8_t{10} * m + std::uint8_t{20} * m;  // error without the promotion case: the sum is an int quantity,
                                                       // and int from std::uint8_t changes the signedness
```

A rank that isn't lower implies a width that isn't smaller, so every conversion that this rule
accepts, [the width rule](#alt-width) accepts too. No standard trait exposes the rank, but a library
can find it for the standard integer types by listing them.

It meets requirements 1, 2, and 3. For most pairs of standard integer types, it gives the same
answer on every implementation. `int` from `long`, for example, is rejected everywhere. It still
depends on the implementation in three ways. The type that a type of lower rank than `int` promotes
to is `int` or `unsigned int`, depending on the widths. Which extended integer types exist is
implementation-defined, and so is the relative rank of two of them with the same width. And the
names and expressions listed in [Drawbacks of every non-portable rule](#non-portable-drawbacks)
still have different types on different implementations.

This paper rejects it because it also rejects conversions that can't change any value of the
source type on the implementation at hand, and that [the width rule](#alt-width) accepts. The rank
rule requires the same signedness because a signed type of higher rank isn't always wider than an
unsigned one (`short` and `unsigned char` can both have 16 bits, as where `CHAR_BIT` is 16). So it
rejects a conversion from an unsigned type to a wider signed one, other than promotion. It also
rejects a conversion to a type of lower rank where both types have the same width:

```cpp
void f(quantity<m, long> l, quantity<m, unsigned> u, quantity<m, std::uint16_t> u16)
{
  quantity<m, int> a = l;     // rank: error everywhere   width: OK on Windows, error on 64-bit Linux
  quantity<m, long> b = u;    // rank: error everywhere   width: OK where long is wider than unsigned
  quantity<m, long> c = u16;  // rank: error everywhere   width: OK everywhere
}
```

An explicit conversion tells a reader that a value can change there. Users who meet a rule that
requires one where no value can change may write explicit conversions by habit, and then those stop
telling the reader anything. The width rule requires one only where the source type has a value
that the destination can't represent. That still includes `quantity<m, short> q = 42 * m;` (see
[Costs](#costs)). Where its answer depends on the implementation, as for `int` from `long`, ported
code fails to compile exactly on the implementation where the conversion can change a value, and
that is the code to review.

The same answer on every implementation doesn't extend to the `<cstdint>` aliases, which code that
cares about the widths of its integers often uses. For them, the rank rule can be less portable than
the width rule. The rank rule rejects `std::int64_t` from `long long` on 64-bit Linux, where
`std::int64_t` is `long`, of lower rank, and accepts it on Windows, where both are the same type.
The width rule accepts it on both.

### Drawbacks of every non-portable rule {#non-portable-drawbacks}

Whether a conversion is implicit decides whether a program is well-formed, and which overloads are
viable. Under a non-portable rule, both can change when the program moves to another implementation,
because type names, and the types of some expressions, denote different types on different
implementations: the `<cstdint>` aliases, `std::size_t`, integer literals, and the results of
integer promotion. `std::int64_t` is `long` on 64-bit Linux and `long long` on Windows.

```cpp
void f(quantity<m, std::uint16_t> a, quantity<m, std::uint16_t> b)
{
  quantity<m, int> sum = a + b;      // OK where int is wider than 16 bits (the sum is int), error where it has 16 (sum is unsigned)
  quantity<m, int> q = 100'000 * m;  // OK where int is wider than 16 bits, error where it has 16 (the literal is long)
}
```


# Proposal {#proposal}

Change the default of `implicitly_scalable` in [@P3045R10_PRE] to:

```cpp
template<unit auto FromUnit, typename FromRep, unit auto ToUnit, typename ToRep>
constexpr bool implicitly_scalable =
  treat_as_floating_point<ToRep> ||
  (!treat_as_floating_point<FromRep> && is_integral_scaling(FromUnit, ToUnit) &&
   $integer-value-preserving$<FromRep, ToRep>);
```

where `$integer-value-preserving$` is the exposition-only variable template of
[The widths of the types](#alt-width).

`implicitly_scalable` constrains the converting constructor of `quantity`, as the corresponding
constraint does for `std::chrono::duration` ([time.duration.cons]{.sref}), so the rule applies to
every conversion between quantities: initialization, assignment, compound assignment, function
arguments and return values, and the conversion of the operands of `+`, `-`, and `%` to their common
quantity type. A conversion that it rejects is written with `value_cast`, such as
`value_cast<short>(q)`.

`bool` and the character types `char`, `wchar_t`, `char8_t`, `char16_t`, and `char32_t` are integer
types too, but [@P3045R10_PRE] doesn't accept them as representation types, so the rule doesn't
apply to them. `signed char` and `unsigned char` are a signed and an unsigned integer type
([basic.fundamental]{.sref}) that programs use for small numbers. They remain valid representation
types, so `std::int8_t` and `std::uint8_t` are covered. A type that `is_integral` doesn't recognize,
such as `__int128` with libstdc++ before GCC 16 in a strict standard mode, keeps the current rule
unless `implicitly_scalable` is specialized for it.

The rule covers pairs of integer types only. For a class type, whether `To{f}` is valid depends on
its constructors (or its members, for an aggregate), and not on whether the conversion can change a
value. Such a type keeps the current rule, and decides itself whether a conversion is implicit. The
converting constructor of `quantity` in [@P3045R10_PRE] is `explicit` when
`convertible_to<FromRep, ToRep>` is `false`. The
`safe_int` of [@MP-UNITS] has a converting constructor that is `explicit` when the destination
can't represent every value of the source (see [mp-units](#mp-units)), so it needs no
specialization of `implicitly_scalable`:

```cpp
static_assert( std::is_convertible_v<quantity<m, safe_int<short>>, quantity<m, safe_int<int>>>);
static_assert(!std::is_convertible_v<quantity<m, safe_int<int>>, quantity<m, safe_int<short>>>);
static_assert( std::is_constructible_v<quantity<m, safe_int<short>>, quantity<m, safe_int<int>>>);
```

The last line shows a difference from integer types. For `short`, the rule removes the converting
constructor, so direct initialization such as `quantity<m, short> s(q);` is ill-formed too, and the
conversion has to be written with `value_cast`. For `safe_int<short>`, the constructor is only
`explicit`, so direct initialization compiles without `value_cast`. In direct initialization, the
check moves from compile time to run time. The compiler no longer rejects a conversion that can
change a value, and `safe_int` checks the value when the conversion happens.

[@MP-UNITS] implements the proposed rule on its version 3 line, which implements [@P3045R10_PRE].
[@MP-UNITS] keeps the rule of `std::chrono` in its 2.x releases, because the change breaks existing
code such as `quantity<m, short> q = 42 * m;`.


# Costs {#costs}

The rule rejects conversions that [@P3045R10_PRE] accepts today. Every rule that meets requirement 1
has each of these costs on some implementation, and the rule of [Integer conversion rank](#alt-rank)
has them on more. The drawbacks that follow from the dependence on the implementation are listed in
[Drawbacks of every non-portable rule](#non-portable-drawbacks).

- Small integer values written as `int` literals are rejected. `quantity<m, short> q = 42 * m;`
  converts from `quantity<m, int>`, which is rejected where `short` is narrower than `int`. The rule
  sees only the types, so it can't accept 42 and reject 100'000.

  ```cpp
  quantity<m, short> q1 = 42 * m;                         // error where short is narrower than int
  quantity<m, short> q2 = short{42} * m;                  // OK
  quantity<m, short> q3 = value_cast<short>(42 * m);      // OK
  quantity<m, short> q4 = (42 * m).in<short>(truncated);  // OK
  ```

- Integer promotion produces `int`. `a + b` for two `short` quantities is a quantity of `int`,
  because `short + short` is `int`. Where `short` is narrower than `int`, assigning the result back
  to a `short` quantity now needs an explicit conversion, such as `value_cast<short>(a + b)`, and so
  does `q += 1 * m` when `q` has a `short` representation. Two `unsigned short` quantities also add
  to a quantity of `int` where `int` is wider, so the sum can't be assigned back to any unsigned
  quantity without an explicit conversion. A quantity of `unsigned` no longer adds to a quantity of
  a signed integer type that isn't wider than `unsigned`, such as `int`, as the conversion of one of
  the operands to the common representation type changes the signedness.

  ```cpp
  void f(quantity<m, short> s1, quantity<m, short> s2, quantity<m, unsigned> u, quantity<m, int> i)
  {
    auto sum = s1 + s2;               // OK: quantity<m, int>
    quantity<m, short> s3 = s1 + s2;  // error where short is narrower than int
    s1 = value_cast<short>(s1 + s2);  // OK
    s1 += 1 * m;                      // error where short is narrower than int
    s1 += value_cast<short>(1 * m);   // OK
    auto mixed = u + i;               // error
  }
  ```

- It differs from `std::chrono`. `quantity<s, int>` from `std::chrono::seconds`, whose
  representation is a signed integer type of at least 35 bits, is rejected where `int` is narrower
  than that type.

Each of these costs is a compile-time error. The conversion in the [Introduction](#introduction)
compiles and gives a wrong value at run time. Each of them also requires an explicit conversion that
the user may know to be safe for the values at hand. A user who meets enough of them may write
explicit conversions by habit, and then an explicit conversion no longer tells a reader where a
value can change. The width rule keeps this to the conversions that can change a value of their
source type.


# Straw polls

1. _An implicit conversion between integer representation types that can change the value, such as
   `quantity<m, std::int16_t>` from `100'000 * m`, should be rejected. This means leaving
   [the portable rule of `std::chrono`](#alt-chrono) for one of the
   [non-portable rules](#non-portable): the same code may compile on one implementation and not on
   another._
2. _[@P3045R10_PRE] should use the rule of [The widths of the types](#alt-width) (as proposed:
   implicit when the destination can represent every value of the source on the given
   implementation, so `int` from `long` is implicit on Windows and rejected on 64-bit Linux)._

   [Taken only if poll 1 has consensus.]{.ednote}


# Acknowledgments

Special thanks and recognition goes to [The C++ Alliance](https://cppalliance.org) for supporting
Mateusz's membership in the ISO C++ Committee and the production of this proposal.

The author also thanks **Giuseppe D'Angelo** for his work on detecting narrowing and
value-changing conversions in [@P0870R8] and [@P2509R1].

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
