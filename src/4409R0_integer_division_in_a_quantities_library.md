---
title: "Integer Division in a Quantities Library"
document: P4409R0
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

## R0

Initial revision. It replaces the chapter "Integer division safety" and the section "Integer
division hazard" of [@P4185R1], so that the question can be decided separately.

- Description of [@AU] corrected (see [Au](#au)).
- Feedback from Croydon 2026 and earlier meetings answered (see
  [Feedback from earlier reviews](#feedback)).
- [Best practice](#best-practice) chapter added.
- `divide_in_common_unit` specified (see [Proposal](#proposal)).
- The single straw poll replaced with two (see [Straw polls](#straw-polls)).


# Introduction

Consider a function that counts how many 40-minute slots fit in a shift:

```cpp
quantity_of<dimensionless> auto slots(quantity_of<isq::time> auto shift,
                                      quantity_of<isq::time> auto slot)
{
  return shift / slot;
}
```

`slots(8 * h, 40 * min)` returns `0`, while we may expect `12`. The division returns
`quantity<h / min, int>` with the value `8 / 40 == 0`. Its quantity is dimensionless, so the
constraint on the return type accepts it. With `480 * min` as the first argument, the same
function returns `12`. With floating-point values, it returns `0.2 h/min`, which equals `12`.

The result is correct in its unit: 8 h / 40 min is 0.2 h/min, and integer division truncates
it to 0. However, if we expect the operands to be converted to a common unit first, this is a
surprise.

[@P3045R10_PRE] keeps this behavior. This paper explains why, describes what other libraries do,
gives guidance for users of integer representation types, and proposes
`divide_in_common_unit(a, b)` as an explicit way to divide in the common unit.


# Feedback from earlier reviews {#feedback}

Integer division was discussed at four meetings, and none of them took a poll on it.

1. At St. Louis 2024 (LEWGI), one participant asked for a diagnostic for this pitfall. Another
   considered it acceptable, as fixed-point arithmetic can't sensibly divide in any other way,
   and others agreed. [Alternatives](#alternatives) describes the diagnostics that were
   considered.
2. At Hagenberg 2025 (SG6), participants asked why the library doesn't calculate in a common
   unit ([Divide in the common unit](#alt-common-unit)), suggested blocking the division when it
   introduces an integer ratio greater than one into the type
   ([Integral factor in the unit](#alt-integral-factor)), and suggested disallowing integer
   division ([Remove it](#alt-remove)). The participant who suggested the block preferred to keep
   integer division. One participant noted that `std::chrono` allows dividing durations
   ([`std::chrono`](#chrono)).
3. At Sofia 2025 (joint SG6 and LEWGI), the chair suggested deleting integer division until
   there are rational or fixed-point types, and said later that the room favored this
   ([Remove it](#alt-remove)). Another participant asked for a way to opt in to integer
   division. The session ended with an action item to do more work on integer division.
4. At Croydon 2026 (LEWGI with SG6), participants:
    - asked for a best practice in the paper, and noted that the problem is harder to spot
      when the operands' types are deduced ([Best practice](#best-practice)),
    - asked for a function that pairs with the remainder (`divide_in_common_unit`, see
      [Current design](#current-design)), and for the paper not to describe the library as
      breaking mathematical rules,
    - asked whether LEWG should be able to reject all integer division
      ([Remove it](#alt-remove)); [straw poll 1](#straw-polls) asks whether the division
      should be ill-formed when the units are not equivalent,
    - proposed to reject the division, or to require an opt-in, only when the units differ,
      which is the rule of [@AU] ([Reject the division](#alt-au)), and mentioned temperature
      as a case where this approach doesn't work ([Current design](#current-design)),
    - noted that a solution is still needed for integer representation types.


# Current design {#current-design}

In [@P3045R10_PRE], `a / b` divides the numerical values of the operands and divides their units,
without converting either value first, and it does so for every pair of quantities:

```cpp
quantity q1 = (8 * km) / (40 * min);  // quantity<km / min, int>, value 8 / 40 == 0
quantity q2 = (8 * h) / (40 * h);     // quantity<one, int>,      value 8 / 40 == 0
quantity q3 = (8 * h) / (40 * min);   // quantity<h / min, int>,  value 8 / 40 == 0
```

For `q1`, the operands have different dimensions, so there is no common unit to convert to.
For `q2`, the truncation is what C++ programmers expect from `int`. `q3` is the surprising
case: the operands are of the same kind, but they are divided as in `q1`.

Quantity points, such as a temperature in `deg_C`, can't be multiplied or divided in
[@P3045R10_PRE], so this paper only concerns quantities that are not points.

`a + b`, `a - b` and `a % b` work differently. They require operands of a common quantity
type, and convert both to their common unit first:

```cpp
static_assert(5 * h % (120 * min) == 60 * min);  // 300 min % 120 min
static_assert(61 * min % (1 * h) == 1 * min);    // 61 min % 60 min
```

[@P3045R10_PRE] quotes Richard Smith's reasoning for this choice in its chapter on modulo.

For integers, if `a / b` is representable, [expr.mul]{.sref} guarantees that
`(a / b) * b + a % b == a`. For quantities, the same holds when both operands have equivalent
units. When the units are not equivalent, `a / b` and `a % b` are computed in different units.
The quotient
that matches `a % b` is the division in the common unit, which this paper proposes as
`divide_in_common_unit(a, b)`:

```cpp
static_assert(5 * h / (2 * h) * (2 * h) + 5 * h % (2 * h) == 5 * h);
static_assert(divide_in_common_unit(5 * h, 120 * min) * (120 * min) + 5 * h % (120 * min) == 5 * h);
```

Floating-point representation types don't truncate. `5. * h / (120 * min)` is about
`0.0417 h/min`, which equals `2.5 * one`. This is why [@P3045R10_PRE] recommends floating-point
representation types by default.


# Existing practice {#existing-practice}

## `std::chrono` {#chrono}

`std::chrono::duration` divides in the common type, so `hours(8) / minutes(40) == 12`, and
`/` and `%` satisfy the identity above. Durations have a single dimension, so every pair of
durations has a common type. A quantities library also divides quantities of different
dimensions, which have no common unit, so it can't apply this rule to every pair.

The difference matters for code that moves from `std::chrono` to quantities. The same values
give different results with `/`:

```cpp
static_assert(std::chrono::hours(8) / std::chrono::minutes(40) == 12);

constexpr quantity work = std::chrono::hours(8);    // a quantity in h
constexpr quantity slot = std::chrono::minutes(40); // a quantity in min
static_assert(work / slot == 0 * one);
```

`divide_in_common_unit(work, slot)` gives `12`, like `std::chrono`.

## Au

[@AU] makes `a / b` ill-formed when both representation types are integral and the units of
`a` and `b` are not equivalent. The dimensions don't matter. In Au 0.6.1, each of these is
rejected at compile time:

```cpp
auto t = meters(60) / (miles / hour)(65);  // error: different dimensions
auto v = kilo(meters)(100) / hours(2);     // error: different dimensions
auto n = hours(8) / minutes(40);           // error: same dimension, different units
auto f = 10 / seconds(3);                  // error: a number divided by a quantity
```

Division by a number, and division by a quantity in an equivalent unit, compile. There are two
ways out of the error:

- `divide_using_common_unit(a, b)` converts both operands to their common unit, and requires
  operands of the same dimension. `divide_using_common_unit(hours(8), minutes(40))` is `12`.
- `a / unblock_int_div(b)` divides the stored values, as [@P3045R10_PRE] does. It is a no-op when
  the division would compile anyway, so a function template can use it for any representation
  type.

Since Au's first release, the rule has changed once and the way out has changed twice:

|   Au version   |      Released      | Integer `Quantity / Quantity`              | Way out                               |
|:--------------:|:------------------:|--------------------------------------------|---------------------------------------|
| 0.1.0 to 0.3.5 | 2022-12 to 2024-07 | always ill-formed                          | `integer_quotient(a, b)`              |
|     0.4.0      |      2024-12       | ill-formed unless the units are equivalent | `a / unblock_int_div(b)`              |
|     0.6.0      |      2026-08       | unchanged                                  | adds `divide_using_common_unit(a, b)` |

Version 0.4.0 deprecated `integer_quotient` in favor of `unblock_int_div` because the former
was hard to use in generic code ([Au#253](https://github.com/aurora-opensource/au/issues/253)).
Later, Au's maintainer found that a remainder of zero doesn't make `a / unblock_int_div(b)`
safe, and concluded that every use of it deserves extra scrutiny
([Au#555](https://github.com/aurora-opensource/au/issues/555)). `divide_using_common_unit` was
added in response ([Au#558](https://github.com/aurora-opensource/au/pull/558)) and first
released in 0.6.0. Au's maintainer also tried a `quotient_and_remainder` helper after that
change, and didn't add it because its results were too confusing.

## mp-units

[@MP-UNITS] divides the numerical values, as [@P3045R10_PRE] does, both in its current release
line and in the version 3 branch that [@P3045R10_PRE] is based on. Neither provides
`divide_in_common_unit` yet. The surprise was reported in 2021
([mp-units#231](https://github.com/mpusz/mp-units/issues/231)): `(1 * km) / (500 * m)`
returned `0` in a dimensionless unit scaled by 1000. The issue was closed by changing `%` to
work on the stored values in the unit of the left operand, as `/` does, so that
`(a / b) * b + a % b == a` held. Later, `%` was changed to use the common unit, which
Richard Smith also recommended, and which [@P3045R10_PRE] specifies.


# Why `/` stays the same for every pair {#rationale}

This rule doesn't remove the surprise shown in the [Introduction](#introduction). We keep one
rule for every pair because:

- the unit of `a / b` is always the unit of `a` divided by the unit of `b`. A rule that
  converts some pairs makes the type of a division in a function template depend on whether its
  arguments are of the same kind,
- when `/` does it implicitly, converting to the common unit multiplies the numerical values by
  factors the user doesn't see. The common unit of `km` and `mi` is 0.064 m, so
  `(1 * km) / (1 * mi)` would compute `15625 / 25146`, and a larger numerator overflows a
  32-bit `int` sooner,
- the result depends less on how an expression is grouped. Today, both
  `2 * m * (5 * h) / (120 * min)` and `2 * m * ((5 * h) / (120 * min))` give `0`. If `/`
  converted operands of the same kind, the second would give `4 m`, while the first would
  still give `0`.


# Alternatives {#alternatives}

## Reject the division unless the units are equivalent {#alt-au}

This is the rule of [@AU], with `unblock_int_div` and a common-unit division as the ways out.
Au has rejected such divisions since its first release in 2022. The rule also catches the
surprise when the dimensions differ, as in `meters(60) / (miles / hour)(65)`, which no common
unit can fix.

However, it rejects common integer divisions that give the expected result, such as
`100 * km / (2 * h)`, which is `50 km/h`. A function template that may be instantiated with
integers has to wrap every denominator in `unblock_int_div`, while `int / int` needs no such
wrapper, and the wrapper silences the check without making the division safe
([Au#555](https://github.com/aurora-opensource/au/issues/555)).

## Reject only the division of the same kind in different units

[@P4185R1] sketched a narrower guard: reject `a / b` only when the operands are of the same
kind, as in `(8 * h) / (40 * min)`, and keep `100 * km / (2 * h)` well-formed. Neither Au nor
mp-units implements it. It doesn't catch `60 * m / (65 * mi / h)`, which also returns `0`, and
it makes the validity of a division in a function template depend on whether the kinds of its
arguments match.

## Reject the division when the unit of the result has an integral factor {#alt-integral-factor}

This rule was suggested in SG6. It would reject `(8 * h) / (40 * min)`, whose unit `h / min`
is 60 times `one`, and `(1 * km) / (500 * m)`, whose unit `km / m` is 1000 times `one`. It
would accept `100 * km / (2 * h)`, whose unit `km / h` is 5/18 of `m / s`, but also
`60 * m / (65 * mi / h)`, which returns `0`. It would also reject divisions with exact
results, such as `(8 * h) / (2 * min)`, which is `4 h/min`, or 240.

## Divide in the common unit for operands of the same kind {#alt-common-unit}

`/` could convert operands of the same kind to their common unit, as `std::chrono` does. This
changes the unit of the result only for some pairs, with the consequences described in
[Why `/` stays the same for every pair](#rationale).

The conversion could be limited to operands with integral representation types, where the
surprise happens. This makes generic code harder to write and to reason about because the unit
of `a / b` in a function template would then depend on the representation type it is
instantiated with. The same quantities in the same units would give results in different units
for integral and floating-point representation types: `(8 * h) / (40 * min)` would print `12`,
while `(8. * h) / (40. * min)` prints `0.2 h/min`. The two values are equal, but this is
confusing to users.

## Remove integer division, or return a rational number {#alt-remove}

Deleting `/` for integer representation types would also reject `(8 * h) / (2 * h)` and
`100 * km / (2 * h)`, which give the expected result.
Returning a rational or fixed-point number needs a type that the standard library doesn't have.


# Proposal {#proposal}

Keep `/` as specified in [@P3045R10_PRE], and add the following non-member function template:

```cpp
template<auto R1, typename Rep1, auto R2, typename Rep2>
  requires $CommonlyInvocableQuantities$<divides<>, quantity<R1, Rep1>, quantity<R2, Rep2>> &&
           $InvocableQuantities$<divides<>,
                                 $common-quantity-for$<divides<>, quantity<R1, Rep1>, quantity<R2, Rep2>>,
                                 $common-quantity-for$<divides<>, quantity<R1, Rep1>, quantity<R2, Rep2>>>
constexpr delta_quantity auto divide_in_common_unit(const quantity<R1, Rep1>& lhs, const quantity<R2, Rep2>& rhs);
```

_Effects_: Equivalent to:

```cpp
using ret = $common-quantity-for$<divides<>, quantity<R1, Rep1>, quantity<R2, Rep2>>;
return ret(lhs) / ret(rhs);
```

The constraint and the conversion are those of `operator%` with `divides<>` in place of `modulus<>`,
and the constraint of `operator/` is checked on the converted operands. So the function accepts the
pairs that `a % b` accepts and whose converted operands can be divided, plus floating-point
representation types, and computes in the same representation type as `a % b`, which is `int` for
two `short` operands. Converting only the units, as in `lhs.in(u) / rhs.in(u)` for the common unit
`u`, would keep the representation type of `lhs`: for `short(600) * h` divided by `short(1) * min`,
the converted numerator, 36000, doesn't fit in `short`.

The unit of the result is `one`:

```cpp
static_assert(divide_in_common_unit(8 * h, 40 * min) == 12 * one);
static_assert(divide_in_common_unit(isq::height(8 * m), isq::width(40 * cm)) == 20 * one);
static_assert(divide_in_common_unit(1 * km, 1 * mi) == 0 * one);  // still integer division
// divide_in_common_unit(60 * m, 2 * s);                           // ill-formed
```

[@AU] names this function `divide_using_common_unit`. This paper uses `in`, as in the member
function `in(U)` of `quantity`, which converts to another unit.

`unblock_int_div` isn't proposed because this paper keeps `/` well-formed for every pair of
integer quantities, and there is nothing for it to unblock.

The mp-units examples in this paper compile with this function added on top of mp-units, both
on its current release line and on its version 3 branch, with GCC 15 and Clang 23.


# Best practice for integer representation types {#best-practice}

1. Prefer floating-point representation types when the result of a division is a ratio. They
   don't truncate, and `quantity<si::metre>` uses `double` unless another type is given.
2. To find how many times one quantity fits in another of the same kind, use
   `divide_in_common_unit(a, b)`. With `a % b`, it gives the quotient and the remainder of the
   same division.
3. Where `divide_in_common_unit` isn't available yet, as in [@MP-UNITS], convert the
   numerator to the finer unit before dividing with `/`:
   `(8 * h).in(min) / (40 * min)` is `12 * one`. The conversion in the other direction,
   `(40 * min).in(h)`, doesn't compile because it could truncate.
4. Check the type of the division itself, not only a constraint it satisfies or a type it is
   converted to. A division of quantities in different units returns a unit such as `h / min`.
   A constraint such as `quantity_of<dimensionless>`, as in the [Introduction](#introduction),
   accepts it. Converting the result to `one` multiplies the truncated value, so the truncation
   stays hidden. This is easy to miss when the operands are deduced with `auto`.


# Straw polls

1. _Division of two quantities with integral representation types whose units are not
   equivalent should divide their numerical values and their units, as in [@P3045R10_PRE],
   rather than be ill-formed or convert the operands to a common unit._
2. _P3045 should provide `divide_in_common_unit(a, b)`, as proposed in this paper._


# Acknowledgments

Special thanks and recognition goes to [The C++ Alliance](https://cppalliance.org) for supporting
Mateusz's membership in the ISO C++ Committee and the production of this proposal.

The author also thanks the participants of the SG6 and LEWGI sessions for the questions and
alternatives they raised, **Chip Hogg** for the integer division
experience of [@AU], and **Richard Smith** for the reasoning behind the modulo operator.

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
