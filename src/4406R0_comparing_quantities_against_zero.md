---
title: "Comparing Quantities Against Zero"
document: P4406R0
date: today
audience:
  - SG6 Numerics
author:
  - name: Mateusz Pusz
    email: <mateusz.pusz@gmail.com>
toc-depth: 3
---


# Revision history

## R0

Initial revision. At Brno 2026, SG6 discussed splitting [@P4185R1] and polled one split:
Section 8 "Range-validated quantity points" into a paper of its own, so that it can be
forwarded to LEWG without the rest of [@P4185R1]. The chapter "Comparison against zero" of
[@P4185R1] moved to this paper for the same reason, so that its design can be decided and
forwarded independently of the other chapters. Changes compared to that chapter:

- [Feedback from Croydon 2026](#croydon-feedback) answered.
- [Evaluation criteria](#evaluation-criteria) added.
- [Strategy 2](#strategy-2-contextual-conversion-to-bool) (contextual conversion to `bool`)
  added.
- [A variant with a single name](#a-variant-with-a-single-name),
  [a variant with a user-defined literal](#a-variant-with-a-user-defined-literal), and
  [a variant with `std::constant_wrapper`](#a-variant-with-stdconstant_wrapper) [@P2781R9]
  added.
- [What every option gives up](#what-every-option-gives-up) and
  [An operand whose type isn't `quantity`](#non-quantity-operand) added.
- Two problems of [Strategy 4](#strategy-4) that [@P4185R1] didn't mention added: a
  requires-expression and a direct use can disagree, and a literal `0` passed through a
  function is rejected outside constant evaluation.
- [The standard library has the same problem](#the-standard-library-has-the-same-problem)
  added.
- [Quantity points](#quantity-points) added: a point can't be compared against zero.
- [A variant without arithmetic conversions](#a-variant-without-arithmetic-conversions) of
  Strategy 3 added, as implemented in the upcoming mp-units 2.6.
- [Recommendation](#recommendation) added: it recommends Strategy 3 with a tag type that
  doesn't convert to arithmetic types, instead of the comparison against a literal `0` that
  [@P3045R10_PRE] proposes.


# Introduction

Zero is the only number that specifies the value of a quantity independently of its unit, as
long as the units differ only by a factor. Zero meters, zero inches, and zero miles are the same
length. This is why it is so common to compare a quantity against zero: to check its sign, to
assert that it is non-zero, or to guard a division.

Without dedicated support, the comparison has to repeat a unit:

```cpp
if (q1 / q2 != 0 * m / s)
  // ...
```

This compiles, and it also checks that `q1 / q2` is a speed. However, the unit has to be
spelled out, and if `q1 / q2` isn't expressed in `m / s`, both sides are converted to a
common unit before the comparison. Hoisting the result into a variable avoids the conversion:

```cpp
if (auto q = q1 / q2; q != q.zero())
  // ...
```

but this is cumbersome, and users who are new to the library rarely know about `zero()` or why
they should prefer it.

[@P3045R10_PRE] proposes to allow a comparison against a literal `0`:

```cpp
if (q1 / q2 != 0)
  // ...
```

At Croydon 2026, [@P3045R7] was reviewed in a joint session of SG18 (LEWGI) and SG6. The
design turned out to be more controversial than the author expected, and the author promised
to investigate it further. [@P4185R1] compared three alternatives in its chapter "Comparison
against zero". That chapter moved to this paper.


# Feedback from Croydon 2026 {#croydon-feedback}

The participants of the Croydon review raised the following points:

1. One participant objected that comparing a quantity with a number that has no unit is
   physically wrong, when the library otherwise teaches users to spell the unit. Another
   objected that it lets values of different kinds be compared.
   Strategies [1](#strategy-1-named-functions) and [2](#strategy-2-contextual-conversion-to-bool)
   don't put a bare number next to a quantity.
2. If the result of an expression isn't the quantity the user expects, a comparison against
   `0` doesn't report it. No option in this paper reports a result that is a quantity of
   another kind (see [What every option gives up](#what-every-option-gives-up)). When the
   result has a type other than `quantity`, some options report it and others don't (see
   [An operand whose type isn't `quantity`](#non-quantity-operand)).
3. Quantities are often stored as floating-point numbers, so an exact comparison against zero
   may not be the right check (see [Floating-point values](#floating-point-values)).
4. A participant asked whether a contextual conversion to `bool` was considered (see
   [Strategy 2](#strategy-2-contextual-conversion-to-bool)).
5. The opt-out from the unit check should be more explicit, even at the price of being
   uglier. Strategies 1 and 3 do that, and the [recommendation](#recommendation) follows this
   request.
6. A user-defined literal that resolves to a tag type could replace the literal `0` (see
   [A variant with a user-defined literal](#a-variant-with-a-user-defined-literal)).
7. The new comparison operators may interfere with overload resolution, especially for types
   from other libraries. The operators of Strategy 4 are hidden friend templates, so they take
   part only in a comparison whose operand is a quantity (see [Strategy 4](#strategy-4)). The
   author asked the participants to find a case where the design fails, and one of them sent an
   example in which `d / e != 0`, where `d` is a quantity, compiles and calls an `operator!=` of
   another library. It shows no interference with overload resolution, but the problem of
   point 2: the user expects `d / e` to be a `quantity`, and the comparison doesn't report that
   it is an `other::expr` (see
   [An operand whose type isn't `quantity`](#non-quantity-operand)).
8. Not every participant opposed the design. One welcomed that alternatives had been
   explored. Another participant preferred a user-defined literal, but was also happy with
   the design because the guard is `consteval`. The cost of that guard is described in
   [Implementation 1](#implementation-1-a-consteval-constructor).


# History

The reference implementation [@MP-UNITS] has tried four of the designs discussed below:

- In August 2023, an [@AU]-style `zero` tag type was implemented in
  [mp-units#488](https://github.com/mpusz/mp-units/pull/488). The pull request was closed
  without merging in September 2023, on the day the named functions of Strategy 1 were added.
  They shipped in mp-units 2.0.
- [@P3045R6] and its earlier revisions proposed the named functions. The wording draft
  prepared for the next revision of P3045 still specifies them as hidden friends of
  `quantity`.
- In February 2026, the comparison against a literal `0` replaced the named functions in the
  reference implementation, and the named functions were deprecated.
- In November 2026, before any release shipped the literal `0`, the tag type described in
  [A variant without arithmetic conversions](#a-variant-without-arithmetic-conversions)
  replaced it. The upcoming mp-units 2.6 ships the tag, and the named functions stay
  deprecated in favor of it.


# Evaluation criteria

The options below are judged against the following criteria, in the order of the rows of the
[Comparison](#comparison) table:

1. Does the comparison avoid putting a number without a unit next to a quantity?
2. Does the check read like the formula it implements, as in `x < 0`?
3. Does a template that performs the check also accept `double`?
4. Does such a template also accept a `std::chrono::duration`?
5. Does the zero still work after it is passed through a function, for example to a standard
   algorithm or a function object?
6. Is the `other::expr` operand in
   [An operand whose type isn't `quantity`](#non-quantity-operand) rejected?
7. How much `double`-based code has to change when its variables become quantities?
8. Does a requires-expression that probes the comparison give the same answer as writing the
   comparison out?
9. How many new names does the user have to learn?
10. Can it be implemented portably, without compiler warnings in user code?


# Strategy 1: Named functions

[@P3045R6] proposed six functions that follow the naming convention of the
[named comparison functions](https://en.cppreference.com/w/cpp/utility/compare/named_comparison_functions)
of the standard library:

```cpp
if (is_neq_zero(q1 / q2))
  // ...
```

The full set is `is_eq_zero`, `is_neq_zero`, `is_lt_zero`, `is_gt_zero`, `is_lteq_zero`, and
`is_gteq_zero`. In [@MP-UNITS] 2.x they are function templates constrained on a static
`zero()` member, so they work for any such type:

```cpp
template<typename T>
  requires requires {
    { T::zero() } -> std::three_way_comparable_with<T>;
  }
constexpr bool is_gt_zero(T v)
{
  return v > T::zero();
}
```

The functions ask for the sign of a quantity, and no number without a unit takes part in the
comparison. They are ordinary functions. They need no special overload-resolution rule, they
behave the same way on every implementation, and a requires-expression that probes them agrees
with a direct use. The template form works for `std::chrono::duration`, which also has a static
`zero()`. A generic algorithm that calls `is_gt_zero(d)` accepts both durations and quantities.
The names follow an existing convention of the standard library.

Six new names are needed, and two of them (`is_lteq_zero`, `is_gteq_zero`) are hard to
read. A function call reads worse than an operator in a formula:
`if (is_lt_zero(b * b - 4 * a * c))` against `if (b * b - 4 * a * c < 0)`. `double` has no
`zero()` member, so a generic algorithm that calls `is_gt_zero(x)` doesn't accept `double`. A
standard version could add overloads for arithmetic types, and then `std::is_gt_zero(x)` would
work for `double` as well. The hidden-friend form in the wording draft works for `quantity`
only. Migration from `double` requires rewriting every comparison against `0`.

## A variant with a single name

The six functions can be replaced by one that returns the result of the three-way comparison
with zero. The name `sign` below is a placeholder:

```cpp
template<typename T>
  requires requires { T::zero(); }
constexpr auto sign(const T& t)
{
  return t <=> T::zero();
}

if (sign(q1 / q2) != 0)
  // ...
if (std::is_lt(sign(q)))
  // ...
```

The result is a comparison category type, so the user compares it against `0` or passes it to
a named comparison function of the standard library. The variant needs only one new name. It
doesn't keep every advantage of Strategy 1: it inherits the problems of the comparison
category types described in [Strategy 4](#strategy-4). `sign(q) < 0` is a comparison of a
`std::partial_ordering` or a `std::strong_ordering` against a literal `0`. With
libstdc++, for example, `-Wzero-as-null-pointer-constant` warns on such a comparison.


# Strategy 2: Contextual conversion to `bool`

`quantity` gets an explicit conversion to `bool` that is `true` for a non-zero value:

```cpp
if (q1 / q2)
  // ...
```

No number without a unit takes part in the check, and no new name is introduced. `if (x)`
already works for `double`, so a generic algorithm that only checks for non-zero values accepts
both `double` and quantities. It is an ordinary member function, so a requires-expression that
probes it agrees with a direct use.

It covers only the check for a non-zero value. Checking the sign still needs another
mechanism. `std::chrono::duration` has no conversion to `bool`, so a generic algorithm can't use
it for durations. It also makes `std::optional<quantity>` easy to misread. `if (opt)` tests
whether the optional holds a value, while `if (*opt)` tests whether the value is non-zero:

```cpp
std::optional<quantity<si::metre>> opt = 0 * m;
if (opt)     // true: a value is present
  // ...
if (*opt)    // false: the value is zero
  // ...
```

Every place that can test a `bool` accepts a quantity, so `q1 && q2` compiles. Whether a vector
quantity is "true" is also not obvious to a reader. Migration from `double` requires a change at
every `x != 0` and `x == 0`, and the code then reads differently from the formula it
implements.


# Strategy 3: A tag type for zero

The [@AU] library provides an empty type `Zero` and a constant `ZERO` of that type. Every
quantity can be constructed from `ZERO`, and comparisons accept it:

```cpp
if (q1 / q2 > ZERO)
  // ...
```

Au also lets `ZERO` take part in comparisons with `std::chrono::duration`, so a generic
algorithm that checks `t > ZERO` accepts both. Chip Hogg reported the usage in Aurora's
codebase in [mp-units#487](https://github.com/mpusz/mp-units/issues/487): _"I grepped our
codebase for `\bZERO\b` in C++ files and found over a thousand results. There were a few false
positives, but most of them were true positives: either initialization or comparison use
cases."_

`ZERO` keeps the operator syntax. One new constant covers all six comparisons, and it also
serves initialization and assignment. `ZERO` has its own type, so a requires-expression that
probes a comparison against it agrees with a direct use. The zero is carried by the type, so it
survives being passed through a function. `std::find(v.begin(), v.end(), ZERO)`,
`std::count(v.begin(), v.end(), ZERO)`, `std::ranges::find(v, ZERO)`, and
`std::less<>{}(q, ZERO)` all compile with Au, on GCC 15 and Clang 21. It has production experience
in Aurora's codebase.

`ZERO` is still a value without a unit. It is spelled out, so a reader sees that the unit is
omitted on purpose, but it doesn't answer the unit-correctness objection. A tag like `ZERO`
can't be passed to a generic interface constrained on a quantity concept either:

```cpp
namespace v1 { void foo(quantity<si::metre> q); }
namespace v2 { void foo(quantity_of<isq::length> auto q); }

v1::foo(ZERO);   // OK
v2::foo(ZERO);   // Compile-time error
```

`Zero` has no associated unit, so `mean_sea_level + ZERO` has no unit for its result:

```cpp
auto alt1 = mean_sea_level + 0 * si::metre;  // OK
auto alt2 = mean_sea_level + ZERO;           // Compile-time error
```

With Au 0.6.1, `x > ZERO` doesn't compile for a `double` `x`: GCC 15 finds no matching operator
and Clang 21 reports an ambiguity. `Zero` already converts to every arithmetic type, but the
built-in candidates don't give a usable match. Comparison operators between `Zero` and
arithmetic types fix it. Migration from `double` requires changing every `0` in a comparison to
`ZERO`.

## A variant without arithmetic conversions {#a-variant-without-arithmetic-conversions}

Au's `Zero` converts to every arithmetic type, which is why `other::operator!=` in
[An operand whose type isn't `quantity`](#non-quantity-operand) accepts `ZERO`. A tag that
converts only to `quantity` and to quantity-like types keeps the operator syntax and the single name of `ZERO` and
rejects that example. The upcoming mp-units 2.6 provides it as `zero`:

```cpp
struct zero_t {
  explicit zero_t() = default;

  friend constexpr bool operator==(zero_t, zero_t) = default;
  friend constexpr std::strong_ordering operator<=>(zero_t, zero_t) = default;

  // in the templates below, R isn't a point

  template<auto R, class Rep>
  friend constexpr bool operator==(const quantity<R, Rep>& lhs, zero_t);
  template<auto R, class Rep>
  friend constexpr auto operator<=>(const quantity<R, Rep>& lhs, zero_t);

  // also == and <=> for representation types other than bool and the character types
  // (a vector or a tensor has only ==, and only if representation_values gives its zero),
  // and for types that are quantity-like, such as chrono::duration

  template<auto R, class Rep>
  constexpr operator quantity<R, Rep>() const;
  template<class T>  // T is quantity-like, such as chrono::duration
  constexpr explicit(quantity_like_traits<T>::explicit_export) operator T() const;
};

inline constexpr zero_t zero{};

if (q1 / q2 > zero)
  // ...
```

All comparisons are hidden friends of the tag, so they are found by argument-dependent lookup
through `zero` and take no part in a comparison that doesn't involve it. Each one deduces its
operand, so a type that only converts to a quantity or to `double` doesn't match. A quantity
point has no overload, because its numerical value depends on its origin (see
[Quantity points](#quantity-points)).

The conversions to `quantity` and to the quantity-like types that a quantity converts to
implicitly, such as `std::chrono::duration`, give them a common reference with `zero_t`, which `std::ranges::find(v, zero)` and `std::ranges::less{}(q, zero)` need. There is
no conversion to a representation type, because `zero` would then be accepted by a function
that takes a plain number. For this reason, the `std::ranges` algorithms don't accept `zero`
for a `double`. The conversions also let `zero` initialize or assign a quantity of any unit
and a `std::chrono::duration`. A function template that deduces its quantity parameter, such as `v2::foo` above,
still doesn't accept `zero`, because its parameter is deduced as `zero_t`, which doesn't
satisfy the constraint.

`x > zero` compiles for a `double` `x`, for a `std::chrono::duration` through its
`quantity_like_traits`, and for a quantity, so one generic algorithm accepts all three.
`d / e != zero` doesn't compile in the `other::expr` example. A requires-expression agrees
with a direct use, the tag needs no `consteval` guard, and `-Wzero-as-null-pointer-constant`
has nothing to warn about. This was verified with GCC 12
and 15 and Clang 16 and 21. MSVC wasn't tested.

## A variant with a user-defined literal

During the Croydon review, a participant suggested a user-defined literal that resolves to a
tag type. A numeric literal operator template sees the characters of the literal, so it can
accept only zero:

```cpp
struct zero_t {};

template<char... Cs>
  requires (sizeof...(Cs) > 0) && (((Cs == '0') || (Cs == '.') || (Cs == '\'')) && ...)
consteval zero_t operator""_zero()
{
  return {};
}

if (q1 / q2 > 0_zero)
  // ...
```

`0_zero` and `0.0_zero` are accepted, and `1_zero` doesn't compile. The comparison takes a
tag type, so a requires-expression agrees with a direct use, and
`std::find(v.begin(), v.end(), 0_zero)` and `std::less<>{}(q, 0_zero)` compile. This was
verified with GCC 15 and Clang 21. `std::ranges::find` additionally needs `zero_t` to be
equality comparable with itself and `quantity` to be implicitly constructible from it, as Au's
quantities are from `ZERO`. The name `_zero` is a placeholder.

A library declares the literal in a namespace, so, like the `std::chrono` literals, it has to
be brought into scope with a using-directive or a using-declaration. Argument-dependent lookup
doesn't find literal operators. With the `zero_t` above, `x > 0_zero` doesn't compile for a
`double` `x` or a `std::chrono::duration`. Comparison operators between `zero_t` and these
types fix it.
SG6 agreed by unanimous consent at Tokyo 2024 that not defining any user-defined literals is
the right choice for P3045. The poll followed the discussion of constructing quantities with
user-defined literals, although its wording covers any literal. Most of the reasons
[@P3045R10_PRE] gives against them, such as the lack of composition, don't apply to a single
literal for zero. The main one that does is that the zero literals of two libraries can't be
disambiguated once both are in scope.

## A variant with `std::constant_wrapper`

C++26 adds `std::constant_wrapper` [@P2781R9], which turns a value into a type. Instead of a
library-specific tag, `quantity` could accept a `std::constant_wrapper` whose value is zero:

```cpp
if (q1 / q2 > std::cw<0>)
  // ...
```

A constraint on the value of the wrapper rejects `std::cw<1>`, and because the value is part
of the type, a requires-expression sees the rejection. `std::cw<0.0>` works as well. A
constraint on the value alone also accepts `std::cw<false>`, `std::cw<'\0'>`, and
`std::cw<nullptr>`, so the constraint has to check the type of the value too.
`std::constant_wrapper` converts to its value, so `x > std::cw<0>` also compiles for `double`
and `int`. It doesn't compile for `std::chrono::duration`. Like `ZERO`, the wrapper keeps its
value through `std::find` and `std::less<>`, but `std::ranges::find(v, std::cw<0>)` fails
unless `quantity` is also implicitly constructible from the wrapper. Without that conversion
the two types have no common reference. Au's quantities are constructible from `ZERO` in this
way. All of this was verified with a GCC 16 development snapshot (16.0.1). GCC 16 is the first
GCC release to ship `std::constant_wrapper`.

The variant needs no new name, but it is the longest of the operator spellings in this paper,
and it needs C++26.


# Strategy 4: Literal `0` with a compile-time guard {#strategy-4}

[@P3045R10_PRE] proposes that the six comparison operators accept a compile-time zero. The
reference implementation provided them as hidden friends of `quantity` until it adopted the
tag type of Strategy 3:

```cpp
if (q1 / q2 != 0)
  // ...
```

The operators are hidden friends, so they are found only by argument-dependent lookup, and they
are viable only when an operand is a quantity. In the reference implementation they were also
function templates that deduce the quantity type from the operand, so a type that only converts
to a quantity doesn't match them. A comparison of a `std::chrono::duration`, of a type from
another library, or of a `std::vector` of quantities against `0` doesn't select them.

This design keeps the operator syntax and adds no name. A generic algorithm that compares
against `0` accepts both `double` and `quantity`, and comparisons against `0` in
`double`-based code keep compiling when its variables become quantities.

It compares a quantity with a number that has no unit, which is point 1 of the
[Croydon feedback](#croydon-feedback). `std::chrono::duration` doesn't support a comparison
against `0`, so generic code that must also accept durations can't use it. A literal `0` has
the limitations of `ZERO` with generic interfaces and with point origins
(`mean_sea_level + ZERO`) shown in Strategy 3, and it also fails for the non-template
interface: `v1::foo(0)`, `v2::foo(0)`, and `mean_sea_level + 0` don't compile.

A literal `0` stops being a literal when it is passed through a function. The standard
algorithms, function objects, and `std::optional` take the value as a parameter, so none of
these compiles outside constant evaluation, although each of them compiles when `double`
replaces the quantity:

```cpp
std::vector<quantity<si::metre>> v = /* ... */;
std::find(v.begin(), v.end(), 0);    // error
std::count(v.begin(), v.end(), 0);   // error
std::ranges::find(v, 0);             // error
std::less<>{}(v.front(), 0);         // error

std::optional<quantity<si::metre>> o;
o > 0;                               // error
```

Outside constant evaluation this holds for every implementation of the guard: inside the
algorithm or the operator, the zero is a function parameter. With the `consteval` guard and
[@P2564R3], the algorithm becomes an immediate function, so `std::find` and `std::count` do
compile in a constant-evaluated context. Code that passes a zero through a function has to
spell it with a unit, as in `0 * m`, or as `quantity<si::metre>::zero()`.

A comparison against `0` compiles for many operands whose type isn't `quantity`, such as any
operand that is comparable with `int` or with a null pointer. It can't report that such an
operand has another type (see [An operand whose type isn't `quantity`](#non-quantity-operand)).
Whether a requires-expression agrees with a direct use depends on how the guard is
implemented. The next sections describe three implementations and their trade-offs.

## Implementation 1: a `consteval` constructor

This is what the reference implementation used:

```cpp
struct zero {
  template<typename T>
    requires std::is_arithmetic_v<T> && (!disable_representation<T>)
  consteval zero(T val)
  {
    if (val != T{0}) throw std::logic_error("not zero");
  }
};

// a hidden friend of quantity (the reference implementation defined it in a non-template base class):
template<auto R1, typename Rep1>
friend constexpr bool operator==(const quantity<R1, Rep1>& lhs, zero);
```

It is portable, it causes no warnings, and it accepts `0`, `0L`, `0.`, and `0.f`.
`disable_representation` excludes `bool` and the character types, so the constraint rejects `false`
and character literals such as `'\0'`. Its problem is that a requires-expression doesn't see the guard.
The operands of a requires-expression are unevaluated ([expr.prim.req]{.sref}), and only a
potentially-evaluated call to an immediate function is an immediate invocation
([expr.const]{.sref}). So the `throw` never runs inside a probe, and a concept that probes a
comparison is satisfied by an expression that fails to compile when it is written out:

```cpp
template<typename T>
concept comparable_with_one = requires(T t) { t == 1; };

static_assert(comparable_with_one<quantity<si::metre, int>>);  // passes

bool is_one(quantity<si::metre, int> q)
{
  return q == 1;  // error: call to consteval function is not a constant expression
}
```

The same happens for a runtime argument: `requires(T t, int v) { t == v; }` is satisfied
too. GCC 15.2 and Clang 21.1 agree, as [expr.const]{.sref} requires. Generic code that
selects an implementation by probing a comparison takes the wrong branch for `quantity`. This
also happens when the user writes a valid zero and passes it to a constrained function template.
The constraint is satisfied, and the constrained overload is more constrained than the fallback,
so it wins overload resolution. Its body then fails to compile:

```cpp
template<typename A, typename B>
  requires requires(A a, B b) { { a == b } -> std::same_as<bool>; }
bool equal(A a, B b)
{
  return a == b;  // error: call to consteval function is not a constant expression
}

template<typename A, typename B>
bool equal(A, B)  // fallback, not selected with the `consteval` guard
{
  return false;
}

bool is_zero(quantity<si::metre, int> q)
{
  return equal(q, 0);
}
```

With the null pointer implementation described below, the constraint isn't satisfied and the
fallback is selected, so `is_zero(0 * m)` returns `false`. The zero still doesn't survive being
passed through a function, but generic code can detect that. `std::strong_ordering` behaves in
the same way today with libstdc++ and libc++: `equal(std::strong_ordering::equal, 0)` returns
`false`.

On compilers that implement [@P2564R3], a `constexpr` generic function also becomes an
immediate function. The diagnostic then blames the quantity argument, and the call to the
guard appears only in a note. The standard function objects are affected as well:
`std::invocable<std::less<>, quantity<si::metre>, int>` is `true`, while `std::less<>{}(q, 0)`
fails to compile. The comparison concepts of the standard library aren't misled:
`std::equality_comparable_with<quantity<si::metre, int>, int>` and
`std::three_way_comparable_with<quantity<si::metre, int>, int>` are both `false`. The two
types have no common reference.

[@P4012R1] proposes a `consteval` broadcast constructor for `std::simd::vec`, and it records
the concerns that LWG raised against it:

1. No other type in the standard library does this.
2. Constrained code can be ill-formed because traits and concepts give the wrong answer.
3. Immediate escalation can make more code immediate than the user intended.
4. Errors after immediate escalation can be harder to understand.

Concerns 2 to 4 apply to this implementation. In a footnote to concern 1, [@P4012R1] itself
notes that format strings come very close to doing the same. The format string type of
`std::format` has a `consteval` constructor [@P2216R3], and a requires-expression gives the
wrong answer for it in the same way: `requires(std::string_view s) { std::format(s, 1); }` is
satisfied, while `std::format(s, 1)` with a runtime `s` fails to compile.
`std::convertible_to<std::string_view, std::format_string<int>>` is `true` as well. The
specification of the comparison category types permits a `consteval` constructor, and MSVC's
STL uses one (see [The standard library has the same
problem](#the-standard-library-has-the-same-problem)).

## Implementation 2: a null pointer constant

An integer literal with value zero is a null pointer constant and converts to a pointer or a
pointer-to-member type, while `1` or an `int` variable doesn't ([conv.ptr]{.sref},
[conv.mem]{.sref}). This rule makes the rejection a part of overload resolution, where a
requires-expression sees it:

```cpp
struct zero {
  struct tag;
  constexpr zero(int tag::*) noexcept {}

  // `nullptr` is a null pointer constant as well
  template<typename T>
    requires std::same_as<T, std::nullptr_t>
  zero(T) = delete;
};
```

With this type, a probe and a direct use give the same answer. Both reject `1`, `0.5`, a
runtime `int`, a `constexpr int` equal to zero, `nullptr`, `false`, and `'\0'`. Both accept
`0`, `0L`, and `0u`, and also `NULL` where it is GCC's and Clang's `__null`. GCC 12 and 15
and Clang 16 and 21 all behave this way. MSVC wasn't tested.

The implementation has two costs:

- Floating-point literals are rejected. No floating-point literal is a null pointer constant,
  and no standard rule lets overload resolution see whether a floating-point argument is zero.
- With `-Wzero-as-null-pointer-constant` enabled, GCC and Clang warn on every comparison
  against `0`, even when the library is included as a system header. The warning exists because
  using `0` as a null pointer is discouraged (see also the C++ Core Guidelines rule
  [ES.47](https://isocpp.github.io/CppCoreGuidelines/CppCoreGuidelines#Res-nullptr)).

## Implementation 3: compiler support

Clang provides an `enable_if` attribute that makes the viability of a function depend on the
value of a constant argument. It is an extension, not standard C++. With it, a probe and a
direct use agree, floating-point zero can be accepted, and nothing warns. GCC and MSVC have no
equivalent today.

## The standard library has the same problem

The comparison category types already use the design of Strategy 4. Their relational and
equality operators take a parameter of an unspecified type that accepts a literal `0`
([cmp.categories.pre]{.sref}), and any other argument is undefined behavior. The three major
implementations use the techniques above, and each carries its cost:

- libstdc++ uses a null pointer constant. A probe agrees with a direct use, and
  `-Wzero-as-null-pointer-constant` warns on a user-written `o < 0` with both GCC and Clang
  ([GCC bug 96278](https://gcc.gnu.org/bugzilla/show_bug.cgi?id=96278),
  [GCC bug 100903](https://gcc.gnu.org/bugzilla/show_bug.cgi?id=100903)).
- libc++ used a null pointer constant until 2024 and replaced it with a `consteval`
  constructor plus Clang's `enable_if` attribute to stop the warning
  ([llvm-project#79465](https://github.com/llvm/llvm-project/pull/79465)).
- MSVC's STL uses a `consteval` constructor, so a probe can disagree with a direct use.
  [microsoft/STL#4359](https://github.com/microsoft/STL/issues/4359) shows the effect on a
  function template that probes `lhs != rhs` and then evaluates it. MSVC rejects the template
  because, at the time of the report, it didn't implement [@P2564R3]. With [@P2564R3], the
  template becomes an
  immediate function, and the call fails only where it isn't a constant expression.

[@LWG4051] collects these reports. It proposes to allow any integral constant expression that
evaluates to `0` and to remove the undefined behavior. Its discussion also asks that a non-zero
value be rejected in a way a requires-expression detects. Under it, a `constexpr int`
variable equal to `0` and an expression such as `1 - 1` may be accepted as well. It also
removes the `nullptr_t` example of the current wording. Its author notes that this requires
compiler support, which has been implemented in Clang. After a reflector poll in 2025, its
priority was set to 3, with a note that rejecting other arguments at compile time is preferred
to undefined behavior at run time.

## Specifying the parameter

If Strategy 4 is chosen, the wording could give the parameter of these operators the same
specification as for the comparison category types ([cmp.categories.pre]{.sref}). This
specification leaves the type of the parameter unspecified. [@P4012R1] proposes a `consteval`
constructor in the specification itself. In this paper, the concerns it records apply only to
an implementation that chooses a `consteval` constructor without compiler support. [@LWG4051]
asks that a non-zero argument be rejected in a way a requires-expression detects. That removes
concern 2 of [@P4012R1], and an implementation that rejects the argument in overload
resolution doesn't cause immediate escalation either. If the wording of these operators refers
to [cmp.categories.pre]{.sref}, the resolution of [@LWG4051] applies to both.

Under the current wording of [cmp.categories.pre]{.sref} any other argument is undefined
behavior, so the `consteval` constructor conforms. Until [@LWG4051] is resolved, `a == b` in
`equal` from Implementation 1 is undefined behavior under this wording, so what `equal(q, 0)`
does isn't portable. If [@LWG4051] is adopted as proposed, the parameter may accept any
integral constant expression equal to `0`, and it is meant to reject every other argument in a
way a requires-expression detects. A null pointer constant accepts only a zero integer literal,
so an implementation that wants to accept a `constexpr int` equal to `0` while rejecting other
values in a way a requires-expression detects needs the compiler support [@LWG4051] asks for.

Both the current wording of [cmp.categories.pre]{.sref} ("literal `0`") and [@LWG4051] exclude
floating-point zero, which [@P3045R10_PRE] accepts. An implementation that reuses the parameter
type of the comparison category types makes `0L` and `0u` non-portable, because libc++ and
MSVC's STL accept only `int`.


# What every option gives up

A comparison that spells the unit also checks the quantity:

```cpp
quantity<isq::length[m]> d = /* ... */;
quantity<isq::duration[s]> t = /* ... */;
quantity<isq::area[m2]> area = /* ... */;

if (d / t != 0 * m / s)      // OK: `d / t` is a speed
  // ...
if (d / area != 0 * m / s)   // Compile-time error: `d / area` is not a speed
  // ...
if (d / area != zero)        // OK: only the value is checked
  // ...
```

No option in this paper checks which quantity the operand is. Users who want this check can
store the result in a variable constrained on the quantity they expect, which is the hoisting
from the Introduction with a check added, and then compare the variable:

```cpp
quantity_of<isq::speed> auto v = d / t;  // Compile-time error if `d / t` is not a speed
if (v != zero)
  // ...
```


# An operand whose type isn't `quantity` {#non-quantity-operand}

Physically, a product or quotient of quantities is a quantity, possibly of dimension one. In
C++, an expression that involves a quantity can still produce a result of another type. Some
options don't report it. A participant of the Croydon review sent the example from point 7 of
the [Croydon feedback](#croydon-feedback). Its minimal form is:

```cpp
#include <mp-units/systems/si.h>

using namespace mp_units;
using namespace mp_units::si::unit_symbols;

namespace other {

struct expr {
  template<typename T>
  friend expr operator/(T, expr e) { return e; }
};

template<typename T>
bool operator!=(const T&, int) { return true; }

}  // namespace other

bool f(quantity<si::metre> d, other::expr e)
{
  return d / e != 0;   // OK: `d / e` is an `other::expr`, and `other::operator!=` is called
}
```

The operators of `quantity` take no part in this comparison. The same happens when a `double`
replaces `d`. Such an unconstrained `operator!=` is unusual. An expression-template library,
however, can return from `d / e` a lazy expression object that is comparable with `int`.

As described in [Strategy 4](#strategy-4), a comparison against a literal `0` can't report
this. Au's `ZERO` converts to every arithmetic type, and `std::cw<0>` converts to `int`, so
both are accepted by `other::operator!=` in the same way. Written with the other spellings,
`f` doesn't compile:

```cpp
d / e != 0 * m / s     // Compile-time error: no `operator!=` for `other::expr` and a speed
is_neq_zero(d / e)     // Compile-time error: `other::expr` has no `zero()`
if (d / e)             // Compile-time error: `other::expr` doesn't convert to `bool`
d / e != 0_zero        // Compile-time error: `zero_t` doesn't convert to `int`
d / e != zero          // Compile-time error: `zero_t` doesn't convert to `int`
```

Three of these rejections depend on the signature of `other::operator!=`. If it accepted any
type for its second parameter, the comparisons against the unit and against both tags would
compile as well. If the lazy object of an expression-template library converts implicitly to
`double`, the contextual conversion to `bool` accepts it too. The template form of the named
functions accepts any type whose static `zero()` is comparable with it. The hidden-friend
form in the wording draft rejects both `other::expr` and `std::chrono::duration`. The
constrained variable shown in [What every option gives up](#what-every-option-gives-up)
rejects this case whichever option is chosen.


# Quantity points {#quantity-points}

This paper proposes the comparison against zero, under every option, only for quantities that
aren't points. A point, spelled `quantity<point<R, PO>, Rep>` in [@P3045R10_PRE], can't be compared
against `0`.

The Introduction rests on zero being the same value in every unit. That holds for a quantity
that isn't a point, but not for a point. The numerical value of a point is its delta
from its origin, so a comparison against zero would ask on which side of the origin the point
lies, and a change of unit can change the origin:

```cpp
constexpr auto t1 = point<deg_C>(-5.);
constexpr auto t2 = t1.in(K);          // the same point: `t1 == t2`

t1.delta_from_zero() < zero            // true: below 0 °C
t2.delta_from_zero() < zero            // false: above 0 K
```

If `t1 < 0` compiled, it would ask whether the temperature is below the freezing point of
water, and `t2 < 0` would ask whether it is below absolute zero. The comparison is meaningful
when the origin of the point is the natural zero of its quantity, such as absolute zero for a
thermodynamic temperature, but even then the origin isn't visible where the comparison is
written.

Instead, the user names the origin, which yields a delta that compares against `zero`, or
compares against another point:

```cpp
auto alt = mean_sea_level + delta<m>(-3.);   // a point measured from `mean_sea_level`

if (t1.delta_from(si::ice_point) < zero)     // below the freezing point of water
  // ...
if (alt.delta_from(mean_sea_level) < zero)   // below sea level
  // ...
if (t1 < point<deg_C>(0.))
  // ...
```

The reference implementation rejects `t1 < zero` and `t1 < 0` in overload resolution, so a
requires-expression and a direct use agree for points. `zero` doesn't convert to a point
either.

The template form of Strategy 1 shown above, as implemented in the upcoming mp-units 2.6,
accepts a point
measured from its default origin, because such a point has a static `zero()`:
`is_lt_zero(t1)` is `true` and `is_lt_zero(t2)` is `false` for the same point. If the named
functions are standardized, their constraint has to exclude points as well. The `sign` variant
has the same problem.

Absolute quantities [@P4185R3_PRE] are anchored at the natural zero of their quantity and aren't
points. If they are adopted, the comparison against zero applies to them
in the same way as to any other quantity that isn't a point.


# Floating-point values

A comparison against zero is as reliable for a `quantity` as for a `double`. A value that
should be zero can come out as a tiny positive or negative number in both, so `x < 0` can be
as misleading as `x == 0`. None of the options changes that.


# Comparison

| Criterion                            | 1: Named functions  | 1: `sign`                    | 2: `bool`         | 3: `ZERO`        | 3: `zero` (no arithmetic conversions) | 3: `0_zero`                           | 3: `std::cw<0>`                       | 4: Literal `0`                                       |
|:-------------------------------------|:--------------------|:-----------------------------|:------------------|:-----------------|:--------------------------------------|:--------------------------------------|:--------------------------------------|:-----------------------------------------------------|
| No bare number                       | Yes                 | Yes                          | Yes               | No (explicit)    | No (explicit)                         | No (explicit)                         | No (explicit)                         | No                                                   |
| Operator syntax                      | No                  | Partly                       | No                | Yes              | Yes                                   | Yes                                   | Yes                                   | Yes                                                  |
| Generic code with `double`           | Possible in `std`   | Possible in `std`            | `!=` only         | Possible         | Yes                                   | Possible                              | Yes                                   | Yes                                                  |
| Generic code with `chrono::duration` | Yes (template form) | Yes (template form)          | No                | Yes (Au)         | Yes (quantity-like)                   | Possible                              | No                                    | No                                                   |
| Zero survives forwarding             | No zero is passed   | No zero is passed            | No zero is passed | Yes              | Yes (`ranges`: not for `double`)      | Not with `ranges`, unless convertible | Not with `ranges`, unless convertible | No (outside constant evaluation)                     |
| Rejects the `other::expr` example    | Yes                 | Yes                          | Yes               | No (as in Au)    | Yes                                   | Yes                                   | No                                    | No                                                   |
| Migration from `double`              | Every comparison    | Every comparison             | Every comparison  | Every comparison | Every comparison                      | Every comparison                      | Every comparison                      | Forwarded zeros; also `0.0`, `0L`, `0u` under poll 4 |
| Probe agrees with direct use         | Yes                 | As for comparison categories | Yes               | Yes              | Yes                                   | Yes                                   | Yes                                   | Depends on implementation                            |
| New names                            | 6                   | 1                            | 0                 | 1                | 1                                     | 1 literal                             | 0                                     | 0                                                    |
| Portable, no warnings                | Yes                 | As for comparison categories | Yes               | Yes              | Yes (GCC, Clang tested)               | Yes                                   | Yes (C++26)                           | Depends on implementation                            |

For Strategy 4 the last two rows depend on the implementation:

| Implementation of Strategy 4 | Probe agrees with direct use | Warnings in user code | Floating-point `0.`     | Portable                |
|:-----------------------------|:-----------------------------|:----------------------|:------------------------|:------------------------|
| `consteval` constructor      | No                           | No                    | Accepted                | Yes                     |
| Null pointer constant        | Yes                          | Opt-in warning        | Rejected                | Yes (GCC, Clang tested) |
| Compiler support             | Yes                          | No                    | Implementation's choice | No                      |


# Recommendation

The author's recommendation is **Strategy 3**, with a tag type that doesn't convert to
arithmetic types, as described in
[A variant without arithmetic conversions](#a-variant-without-arithmetic-conversions):

```cpp
if (q1 / q2 != zero)
  // ...
```

It is the only option that meets every criterion of the [Comparison](#comparison) except the
first, the migration from `double`, and the new name:

- The opt-out from the unit check is explicit, as Croydon point 5 asks. `zero` is still a
  value without a unit, so it doesn't answer point 1 fully, but a reader sees that the unit is
  omitted on purpose.
- `zero` is an argument like any other, so a requires-expression agrees with a direct use.
  This needs neither a `consteval` guard nor a null pointer constant. It causes no warnings,
  and it works today with the compilers tested (GCC, Clang).
- Its value is part of its type. It survives being passed to `std::find`, `std::count`, and
  `std::less<>`, outside constant evaluation as well, and to `std::ranges::find` for
  quantities and for quantity-like types such as `std::chrono::duration`.
- It doesn't convert to arithmetic types. This is why the `other::expr` example is rejected,
  unlike with Au's `ZERO`, `std::cw<0>`, and the literal `0`.
- It compares with quantities, with representation types, and with quantity-like types such as
  `std::chrono::duration`. One generic algorithm accepts all three.
- The user never writes the `0` that [cmp.categories.pre]{.sref} constrains. Its undefined
  behavior and the questions about `0.`, `0L`, and `0u` don't arise.

The cost is that code ported from `double` has to change every `0` in a comparison to `zero`,
which Strategy 4 avoids. We consider that cheaper than a comparison that generic code can't
rely on: with Strategy 4, a probe disagrees with a direct use, the user's build warns under
`-Wzero-as-null-pointer-constant`, or the
implementation isn't portable, and a zero passed to a function has to be spelled with a unit
anyway.

The tag adds one name. The reference implementation calls it `zero`, and LEWG may prefer
another name for the standard library.

If SG6 weighs the unit-correctness objection above the operator syntax, Strategy 1 is the
alternative. Its template form also works for `std::chrono::duration`. If SG6 prefers to keep
the spelling of `double`-based code, Strategy 4 remains possible, with the trade-offs
described in [Strategy 4](#strategy-4).


# Straw polls

1. _Comparison against zero should be provided via a named constant of a tag type that doesn't
   convert to arithmetic types, with hidden-friend comparison operators for quantities that
   aren't points, for quantity-like types, and for representation types (Strategy 3), as the
   standard zero-comparison mechanism._
2. _A quantity, and a quantity-like type that a quantity converts to implicitly, should be
   implicitly convertible from the named constant for zero._
3. _Comparison against a compile-time `0` via hidden-friend comparison operators of `quantity`
   (Strategy 4) should be the standard zero-comparison mechanism instead of Strategy 3._
4. _If Strategy 4 is chosen, the parameter of its operators should be specified in the same way
   as for the comparison category types ([cmp.categories.pre]), so that the resolution of
   LWG4051 applies to both._
5. _Strategy 1 (named functions) should be the standard zero-comparison mechanism instead of
   Strategy 3._
6. _A user-defined literal that resolves to a tag type for zero (Strategy 3) should be the
   standard zero-comparison mechanism instead of a named constant._
7. _The named functions `is_eq_zero`, `is_neq_zero`, `is_lt_zero`, `is_gt_zero`,
   `is_lteq_zero`, and `is_gteq_zero` (Strategy 1), as function templates that accept any type
   that has a static `zero()` member and isn't a point, should be provided in addition to the
   chosen mechanism._


# Acknowledgments

Special thanks and recognition goes to [The C++ Alliance](https://cppalliance.org) for supporting
Mateusz's membership in the ISO C++ Committee and the production of this proposal.

The author also thanks the participants of the Croydon 2026 SG18 and SG6 session for their
feedback and for the example of an operand whose type isn't `quantity`, **Chip Hogg** for the design
and the usage data of `ZERO` in [@AU], **Johel Ernesto Guerrero Peña** for pointing at the
comparison category types as prior art, and **Corentin Jabot** for collecting the
implementation experience of the comparison category types in [@LWG4051].

---
references:

- id: AU
  citation-label: Au
  title: "The Au Units library"
  URL: <https://aurora-opensource.github.io/au>
- id: P4185R3_PRE
  citation-label: P4185R3
  author:
    - family: Pusz
      given: Mateusz
  title: "Absolute Quantities"
  URL: <https://wg21.link/p4185r3>
- id: P3045R10_PRE
  citation-label: P3045R10
  author:
    - family: Pusz
      given: Mateusz
  title: "Quantities and units library"
  URL: <https://wg21.link/p3045r10>
- id: MP-UNITS
  citation-label: mp-units
  title: "mp-units - A Physical Quantities and Units library for C++"
  URL: <https://mpusz.github.io/mp-units>

---
