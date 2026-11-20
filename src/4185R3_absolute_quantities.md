---
title: "Absolute Quantities"
document: P4185R3
date: today
audience:
  - SG6 Numerics
author:
  - name: Mateusz Pusz
    email: <mateusz.pusz@gmail.com>
toc-depth: 3
---


# Revision history

## Changes since [@P4185R2]

- The paper is written against [@P3045R11_PRE] instead of [@P3045R10_PRE]. The rules that aren't
  specific to absolute quantities are proposed there: the abstraction written in the quantity
  specification (`delta<isq::width>[m]`, `point<isq::altitude, msl>[m]`), points measured from the
  natural origin of their specification, no conversion between points of sibling specifications,
  and no conversion between quantities of different characters. The vector operations that
  compute a scalar from vectors, such as a scalar product, are proposed in [@P4487R0].
- `delta<QS>` is the specification of a delta of `QS`, distinct from the plain `QS` of an absolute
  (see [The abstraction in the quantity specification](#absolute-spec)).
- A plain `QS[U]` is always an absolute, and is ill-formed for a vector or tensor specification
  and for an offset unit. In R2 the plain reference of a vector specification was a delta (see
  [Scalar and vector quantities](#absolute-scalar-vector)).
- A vector or tensor result is a delta. Everything that measures a size is an absolute: `abs()`,
  `hypot()`, `magnitude()`, and `modulus()`. A power of a delta is a delta, an even one included,
  where R2 made an even power an absolute. `abs()` and `hypot()` of a vector specification are
  ill-formed (see [Products and quotients of two deltas]).
- The kind of a unit expression is never non-negative, so `-1. * (m / s)` isn't checked (see
  [Sign of an absolute quantity](#absolute-sign)). A new
  [For discussion](#absolute-negative-bare-unit) section proposes a poll on the multiply syntax.
- `quantity_of` is implemented in the prototype, and [What generic code needs] reports the cost.
- [Impact on P3045R11](#absolute-impact) lists the breaking changes that follow from the above.

## Changes since [@P4185R1]

R2 proposes absolute quantities, and the title changes from "Completing the Mathematical Model
for C++ Quantities and Units" to "Absolute Quantities". At Brno 2026, SG6
encouraged further work on Section 6 "Absolute quantities" of [@P4185R1], and the other chapters
moved to papers of their own so that each can be decided separately. The only dependency of this
paper is [@P3045R10_PRE]. Some rules are stated for the case that [@P4411R0_PRE] is adopted as well.

- The chapter "Non-negative quantities" and its motivation moved to [@P4411R0_PRE], and so did the
  runtime checks of the `non_negative` tag on absolute quantities. Absolute quantities no longer
  depend on the tag (see [Sign of an absolute quantity](#absolute-sign)).
- The chapter "Range-validated quantity points" and the motivation section "Bounded domains" moved
  to [@P4412R0_PRE], as SG6 encouraged in a poll at Brno 2026. [@P4412R0_PRE] records the poll and
  lists its changes since R1.
- The chapter "Integer division safety" and the motivation section "Integer division hazard"
  moved to [@P4409R0_PRE].
- The chapter "Comparison against zero" and its motivation section moved to [@P4406R0_PRE].
- The chapter "Text output for quantity points" and the motivation section "Points without
  output" moved to [@P3045R10_PRE], except for one paragraph on absolute quantities (see
  [Text output](#absolute-text-output)).
- The chapters "Affine spaces within quantity hierarchies" and "Runtime frame projections", with
  their motivation sections, are removed. The first is planned for a later revision of
  [@P3045R10_PRE], and the second as a paper of its own.
- The introduction is shortened to why a third abstraction is needed.
- [Implementation experience](#absolute-implementation-experience) added. Absolute quantities are
  implemented on a prototype branch off the version 3 line of the reference implementation, and the
  experience completed the model in several places, among them [unary negation](#absolute-negation),
  now conditional on [@P4411R0_PRE], the concept
  `linear_quantity` for what absolutes and deltas share, the common reference of a mixed pair,
  compound assignment, the abstraction of `%` and `fmod`, and the result of `hypot`.
- A value written with a bare unit is an absolute of a quantity kind, and a kind takes the domain
  of its root, so if [@P4411R0_PRE] is adopted, `-5. * m` is a contract violation and a signed
  value is written `delta<m>(-5.)`. A vector value written with a bare unit is ill-formed instead
  of a delta. `si::absolute_zero` is the natural origin of thermodynamic temperature, and an offset
  unit is a unit whose origin isn't a natural origin, so the kelvin isn't one (see
  [Temperature revisited](#absolute-temperature)).
- [Concepts](#absolute-concepts) added. `quantity_of` tells what a quantity can be used as, and
  the abstraction concepts tell what it is.
- [Averages and centers of mass](#averaging) added, to answer a question SG6 asked at Brno 2026.
- The paper is written against [@P3045R10_PRE] instead of [@P3045R7]. A point is written
  `quantity<point<R, PO>, Rep>`, as implemented in the unreleased version 3 branch of
  [@MP-UNITS]. Code examples use the `standard_case` concept names of [@P3045R10_PRE]
  (`quantity_reference`, `point_origin`, `quantity_of`), and quantity specifications derive from
  `named_quantity_spec`.

## Changes since [@P4185R0]

- The sections "Points without output" and "Text output for quantity points" updated to reflect
  that the reference implementation now provides text output for `quantity_point` when its
  point origin equals `default_point_origin(R)`, resolving the most common case. Points
  anchored to non-default origins remain without automatic output.
- `quantity_from_unit_zero()` renamed to `quantity_from_zero()`, with its constraint simplified
  to `PO == default_point_origin(R)`. On a point at its default origin, `.in(unit)` now also
  switches the point origin to `unit._point_origin_`, consistent with the proposed logarithmic
  level unit design, so `temp.in(K).quantity_from_zero()` still produces the absolute Kelvin value
  (see [The temperature trap](#temp-trap)).
- "Runtime frame projections" updated from "Not yet implemented" to "Implemented in [@MP-UNITS]".


# Abstract

[@P3045R11_PRE] models quantities with two abstractions, a delta and a point, both written with
the `quantity` class template: `quantity<R>` is a delta and `quantity<point<R, PO>>` a point.
Neither fits the most common value in a physics equation, an amount measured from a true zero,
such as a mass of 5 kg or a thermodynamic temperature of 300 K. A delta has no zero anchor, and
two points can't be added, and a point can't be multiplied or divided.

This paper proposes a third abstraction, the **absolute quantity**, anchored at a true zero, and
makes it the default meaning of `quantity<R>`. That is a breaking change to [@P3045R11_PRE], so
SG6 is asked for a direction before the initial API is fixed. Final wording follows
implementation.


# Introduction

[@P3045R11_PRE] writes a delta as `quantity<R>` and a point on a measurement scale, measured from
an explicit or implicit origin, as `quantity<point<R, PO>>`. The two abstractions come from the affine
space model: a point minus a point is a delta, a point plus a delta is a point, and the sum or
product of two points is ill-formed.

Most values in physics and engineering equations are neither. A mass of 5 kg, a duration of
3 s, or a thermodynamic temperature of 300 K is an amount on a _ratio scale_: it is measured from
a true physical zero, so sums, products, and ratios of such values are meaningful, which they
are not for points. Unlike a delta, the value is not a difference between two states. With two
abstractions, a user has to choose one of them, and neither describes such a value.
[Motivation and scope](#motivation) shows where that hurts: the rules for temperature units make
the ideal gas law hard to write correctly, and a function signature can't tell a total mass from
a mass loss.

The goal is a library where the ideal gas law

```cpp
quantity R_calc = P * V / (n * T);
```

compiles with `T` written as `28. * K`, as an absolute thermodynamic temperature, while an
offset-scale reading still has to be converted explicitly, and where `mass` and `mass_loss` are
distinct types the compiler prevents from being accidentally swapped.

Most code needs only absolute quantities and deltas, since subtracting two absolutes yields a
delta. Points stay for offset scales (temperature scales, time zones, reference frames) and for
readings relative to a chosen origin.

The three-way split follows the convex-space model of Oliver Rosten [@ROSTEN2025], and it is also
implemented, with a different API, in his Sequoia library [@SEQUOIA]. To our knowledge, no
mainstream units library in any programming language, including F# Units of Measure, Haskell's
_dimensional_ package, or Python's Pint, distinguishes absolute quantities, deltas, and points as
three separate types.

# Motivation and scope {#motivation}

This section shows two use cases where the lack of a zero-anchored abstraction forces users into
awkward workarounds.

## The temperature trap {#temp-trap}

A frequently reported usability issue with the current [@P3045R11_PRE] design involves
temperature. The root cause is the interaction between offset units (°C, °F) and the affine
space model.

Consider the ideal gas law, $PV = nRT$. A user might naively attempt:

```cpp
auto P = 1. * atm;
auto V = 1. * L;
auto n = 1. * mol;
auto T = 28. * deg_C;                    // ✗ does not compile in P3045!
auto R_calc = P * V / (n * T);
```

This code does not compile under [@P3045R11_PRE]. Earlier revisions allowed `28 * deg_C`, until
Tiago Freire demonstrated the danger with a concrete ideal gas law example. The multiply syntax
was then disabled for all temperature units: every temperature unit whose definition names a point
origin is caught by the restriction, and the kelvin was given `absolute_zero` as its origin to fall
under the same rule.

The inclusion of Kelvin is necessary for a consistent and safe rule. The multiply syntax
produces a delta, so `28 * K` would not itself construct a point.
For Kelvin this causes no direct harm, but the situation changes entirely if the unit in
such an expression were later changed to an offset unit (e.g., `deg_C`). The result would
become a meaningless delta rather than a compile error. A uniform rule (no
multiply syntax for any temperature unit) is the only way to make the restriction
predictable and refactoring-safe.

The rule is the right fix for the model as it stands, but the model has no way to express "an
absolute thermodynamic temperature of 28 K" directly.

Users must explicitly choose between a delta and a point:

```cpp
auto T1 = delta<K>(28);                  // a temperature difference of 28 K
auto T2 = point<K>(28.);                 // 28 K on the Kelvin scale (= 28 K from absolute zero)
```

Neither option correctly captures the intent. By using `delta<K>`, `T1` is typed as a
_delta_, a signed difference between two temperatures, which is semantically
misleading in $PV = nRT$, where 28 K is an absolute thermodynamic temperature, not a
difference between two temperatures. The point `T2` carries the right physical meaning but cannot
be multiplied or divided, as point arithmetic in an affine space forbids those operations.

The workaround that produces a correct result requires constructing a point measured in Kelvin
and extracting the delta from absolute zero:

```cpp
auto temp = point<deg_C>(28.);
auto T = temp.in(K).delta_from_zero();       // 301.15 K — correct but cumbersome
auto R_calc = P * V / (n * T);
```

The affine space model can handle this case, but the user has to go through a point, convert
units, and then extract the delta from zero.

An alternative approach, suggested by Chip Hogg as a "nature-based constant" idiom, is to
subtract `absolute_zero` directly from the point, obtaining the delta from the
physical zero:

```cpp
auto temp = point<deg_C>(28.);
auto T = temp - absolute_zero;                    // a delta equal to 301.15 K, from absolute zero
auto R_calc = P * V / (n * T);
```

This works even when the point is expressed in `deg_C`: the subtraction of the absolute
zero origin yields a delta whose value is the absolute thermodynamic temperature, and
the result can always be scaled to whatever unit is needed. However, this idiom still
requires users to know that `absolute_zero` exists, understand why it must be subtracted,
and remember to apply it every time an absolute temperature is needed.

This problem is not limited to temperature. It affects any domain where absolute quantities
(as opposed to differences) are the natural operands in physical equations. The
[hardware voltage example](https://mpusz.github.io/mp-units/latest/examples/hw_voltage/) in
the [@MP-UNITS] documentation illustrates the same pattern in embedded systems: an ADC
maps a physical voltage range to integer counts, and the voltage it reads is an amount
measured from 0 V, not a change. Users have independently requested
the same ergonomic improvements for such cases
(see [mp-units discussion #606](https://github.com/mpusz/mp-units/discussions/606)).

## Mass balance and accumulation {#mass-balance}

In process engineering, it is common to track the total mass of material in a vessel, then
compute a percentage loss:

```cpp
quantity<percent> moisture_loss(quantity<kg> water_lost, quantity<kg> total)
{
  MP_UNITS_EXPECTS(total > 0 * kg);
  return water_lost / total;
}
```

Here, `water_lost` is a difference (delta) and `total` is an absolute amount, but the type
system makes no distinction: both are `quantity<kg>`. A user could accidentally swap them:

```cpp
quantity result = moisture_loss(total_initial, total_initial - total_dried);
// Compiles. Wrong.
```

Defining `total_mass` and `mass_loss` as children of `isq::mass` would prevent the swap, since a
parent converts to a child only explicitly. But `total_initial - total_dried` then yields a
`total_mass`, and every correct call site needs an explicit conversion to `mass_loss`.

Both values are masses, possibly measured with the same instrument, and what differs is their
_role_: `total` is a reading anchored at true zero, and `water_lost` is the difference of two such
readings. ISO 80000 doesn't distinguish "total mass" from "mass loss", and encoding every such
role in the hierarchy would make every domain grow its own role-based quantities.

If instead the library distinguished absolute quantities (amounts measured from a true zero)
from deltas (signed differences), the function signature alone would enforce the correct usage
without polluting the quantity hierarchy. The solution is shown in
[Mass balance revisited](#mass-balance-revisited).

# Absolute quantities {#absolute}

## Overview {#absolute-overview}

We propose introducing a third quantity abstraction, the **absolute quantity**, that sits
between deltas and points in the type hierarchy:

| Feature                   |                Point                |       Absolute        | Delta |
|---------------------------|:-----------------------------------:|:---------------------:|:-----:|
| Multiplication / Division |                  ✗                  |           ✓           |   ✓   |
| Addition (A + A)          |                  ✗                  |           ✓           |   ✓   |
| Subtraction (A − A)       |                  ✓                  |           ✓           |   ✓   |
| Physical origin           | Point origin (explicit or implicit) | Anchored at true zero |  N/A  |
| Can use offset units      |                  ✓                  |           ✗           |   ✓   |
| Text output               |     only at the default origin      |           ✓           |   ✓   |

Absolute quantities are anchored at a physically meaningful true zero. They cannot use offset
units (because they must remain anchored to absolute zero, not a conventional origin). They may
be negative where the physics allows it (see [Sign of an absolute quantity](#absolute-sign)).

::: note
For a quantity that can be negative, an absolute and a delta share the same mathematical
structure: both are vector spaces with a distinguished zero element. The type distinction encodes
the physical interpretation. An absolute is a ratio-scale measurement anchored at true physical
zero, and a delta is a change with no physical zero anchor. Where the values of a quantity can't be
negative, its absolutes form a convex cone `[0, +∞)`, which is closed under addition but not under
negation, and is therefore not a vector space.
:::

This three-way split mirrors the hierarchy found in measurement theory and physics
[@ROSTEN2025]:

| Concept                               | Measurement Scale | Mathematical Structure                                                       | Physical Meaning                                                                           |
|:--------------------------------------|:------------------|:-----------------------------------------------------------------------------|:-------------------------------------------------------------------------------------------|
| **Point**                             | Interval Scale    | Affine Space                                                                 | A reading relative to an explicit origin (e.g., altitude above sea level, a timestamp)     |
| **Absolute** (any sign permitted)     | Ratio Scale       | Vector Space (real line); zero = true physical zero                          | A ratio-scale quantity whose sign is unconstrained (e.g., electric charge, reactive power) |
| **Absolute** (no negative values)     | Ratio Scale       | Absolute Convex Space: convex cone $[0, +\infty)$ with distinguished origin  | A non-negative amount; true zero is physically meaningful                                  |
| **Delta**                             | —                 | Vector Space                                                                 | A change or an interval                                                                    |

The two absolute rows describe the physics of a quantity. The type of an absolute is the same for
both, and this paper doesn't enforce the sign (see [Sign of an absolute quantity](#absolute-sign)).

Points on a scale with a non-trivial lower bound but _no_ distinguished absolute origin occupy a
fourth abstraction in [@ROSTEN2025]: the **convex space**, a half-line whose lower bound is fixed
but not zero. The Celsius scale is the canonical example: `ice_point` is a `relative_point_origin`
offset by 273.15 K from `si::absolute_zero`, so the lower bound of 0 K corresponds to −273.15 °C.
This paper models such scales with points, because their values are relative to a chosen
reference.

## Syntax {#absolute-syntax}

With absolute quantities as the default, the API becomes:

```cpp
quantity q1 = 20 * kg;        // absolute quantity (measured from true zero)
quantity q2 = delta<kg>(20);  // delta quantity (signed difference)
quantity q3 = point<kg>(20);  // point quantity (relative to an origin)
```

producing:

```cpp
static_assert(std::is_same_v<decltype(q1), quantity<kg, int>>);
static_assert(std::is_same_v<decltype(q2), quantity<delta<kg>, int>>);
static_assert(std::is_same_v<decltype(q3), quantity<point<kg>, int>>);
```

This mirrors the way physicists write equations: $m = 10\ \mathrm{kg}$ denotes an absolute
mass, with an explicit $\Delta$ only when a difference is intended. Please note that making
`quantity` default to absolute is a **breaking change** relative to [@P3045R11_PRE], where
`quantity` is a delta.

Each abstraction is written the same way for values and for types, with a unit or a quantity
specification:

|                       | with a unit         | with a quantity specification       |
|-----------------------|---------------------|-------------------------------------|
| **absolute**          | `42 * m`            | `isq::width[m](42)`                 |
| **delta**             | `delta<m>(42)`      | `delta<isq::width>[m](42)`          |
| **point**             | `point<deg_C>(20)`  | `point<isq::height>[m](42)`         |
| **point from origin** | `point<m, msl>(42)` | `point<isq::altitude, msl>[m](42)`  |

The types are written the same way: `quantity<isq::width[m]>`, `quantity<delta<isq::width>[m]>`,
and `quantity<point<isq::altitude, msl>[m]>`. `msl` stands for a user-defined origin, the mean sea
level, in the examples of this paper.

The multiply syntax, `value * R` and `value / R`, and the call `R(value)` with a plain reference
`R` always create an absolute, or are ill-formed when `R` has none. A delta is created with
`delta<R>(value)` and a point with `point<R>(value)`, so `20 * delta<m>` is ill-formed. Multiplying
or dividing an absolute or a delta by a unit keeps its abstraction: `delta<m>(5.) / s` is a delta.
A constructor that names the reference, as in `quantity{5., delta<m>}`, creates what the reference
names.

A plain reference that has no absolute is ill-formed: it creates no value and names no quantity
type. That is the case for an offset unit, such as `deg_C`, and for a quantity specification of
vector or tensor character (see [Scalar and vector quantities](#absolute-scalar-vector)). Such a
quantity is always written as a delta or as a point: `delta<deg_C>(5)` and `point<deg_C>(20)`, or
`delta<isq::velocity>[m / s](vec)`.

A bare unit means an amount. `20 * kg` is an absolute of the quantity kind `kind_of<isq::mass>`,
whatever its sign. A signed change of a kind is written as a delta, as in `delta<m>(-5.)` or
`delta<K>(-5.)`, and a position on a scale as a point, which picks an origin. If [@P4411R1_PRE] is
adopted, `-5. * K` is a contract violation (see [Sign of an absolute quantity](#absolute-sign)).

## The abstraction in the quantity specification {#absolute-spec}

In [@P3045R11_PRE], the abstraction is a property of the quantity specification. `point<QS>` and
`point<QS, PO>` are the specifications of a point, and `delta<QS>` is the specification of a delta.
A specification is bound to a unit as before, as in `delta<isq::width>[m]` and
`point<isq::altitude, msl>[m]`, and a unit alone is a shorthand: `delta<m>` is
`delta<kind_of<isq::length>>[m]`. There, a plain `QS[U]` names the same delta as `delta<QS>[U]`
for a unit without an offset, and is ill-formed for an offset unit.

This paper changes one thing: a plain specification, such as `isq::height` or
`kind_of<isq::length>`, becomes the specification of an absolute, so `QS[U]` and `delta<QS>[U]` name
two different quantities, an amount and a change. `delta<QS>` is the quantity ISO 80000 writes with
a Δ, as in ΔT. An absolute and a delta of `QS` are the
same node of the quantity tree, with the same interface, and differ only in their abstraction. The
type of a reference names the unit, not the kind: `delta<m>` is a `delta_<si::metre>`, and
`delta<isq::height>[m]` a `delta_<isq::height, si::metre>`. `delta<>` takes a plain specification
or a unit, as in [@P3045R11_PRE], and an absolute isn't a kind either.

Calling a plain specification with a quantity replaces its specification and keeps its
abstraction: `isq::height(delta<m>(5.))` is a delta of height, the same as
`delta<isq::height>(delta<m>(5.))`, and `isq::velocity(delta<m / s>(5.))` is a delta of velocity.

A product or a quotient with a delta operand is the delta of the result, so `delta<isq::length> /
isq::time` is `delta<isq::length / isq::time>`, and so is a power of a delta (see
[Products and quotients of two deltas]). A point specification
has no algebra: `point<isq::length> * isq::time` is ill-formed.

## Absolute quantities are not points {#abs-vs-point}

Points can't simply be given addition and multiplication. A point lives on an _interval scale_:
timestamps, calendar dates, and geographic positions can be subtracted, but it makes no sense to
add Tuesday to Friday, or to ask what fraction Berlin is of Paris. An absolute lives on a _ratio
scale_: it keeps every point operation, and because all its values share a physically meaningful
zero, sums, products, and ratios of absolutes, such as `T_cold / T_hot` in Carnot efficiency, are
meaningful. A point measured from an arbitrary
origin (the floor of a building, the GPS epoch, the freezing point of water) has no such zero.

For time, a duration has an absolute, and an instant is a point measured from an epoch, as
`std::chrono` measures a `time_point` from the epoch of its clock.

## Scalar and vector quantities {#absolute-scalar-vector}

Absolute quantities are always **scalar**: they are ratio-scale magnitudes anchored at a
physically meaningful true zero, and the concept of direction, which would require an
orientation relative to a reference frame and not just a reference zero, has no place in the
model. Vector quantities live in a vector space. They have a mathematical zero (the zero vector,
representing no displacement), but not a ratio-scale physical anchor. They represent
displacements from a reference and therefore fall in the **delta** abstraction, unless they are
measured from an origin as points. Points carry a concrete origin and may be scalar or vector
depending on the space they inhabit.

| Abstraction  | Scalar                             | Vector                                            |
|:-------------|:-----------------------------------|:--------------------------------------------------|
| **Point**    | `point<time>`, `point<altitude>`   | `point<position_vector>`, `point<velocity>`       |
| **Delta**    | `delta<duration>`, `delta<height>` | `delta<displacement>`, `delta<velocity>`          |
| **Absolute** | `duration`, `height`, `mass`       | _(none, `magnitude()` gives a scalar absolute)_   |

A specification of vector or tensor character, such as `isq::velocity`, has no absolute, so its
plain reference `isq::velocity[m / s]` is ill-formed in any representation, as the plain reference
of an offset unit is. A vector quantity is a delta or a point, and the specification states which:
`delta<isq::velocity>[m / s](vec)` is a velocity and `point<isq::position_vector>[m](vec)` a
position. A velocity along one axis, stored in a `double`, is a delta too. A scalar specification
in this paper is one of scalar character, whatever the type of the representation.

An absolute therefore never converts to a vector or tensor specification, even explicitly:
`isq::velocity(5. * m / s)`, `quantity_cast<delta<isq::velocity>>(5. * m / s)`, and
`quantity<delta<isq::velocity>[m / s]> v = 5. * m / s;` are ill-formed. A velocity is made from a
delta, as in `isq::velocity(delta<m / s>(5.))`, or from `q.delta()` of an absolute `q` meant as a
change. For the same reason, `+`, `-`, `==`, and `<` don't accept an absolute together with a
delta whose common specification is of vector or tensor character.

A bare unit such as `m`, `N`, or `m / s` names a quantity kind, and its plain reference is always
that of an absolute of the kind. So `isq::force(5. * N)` is ill-formed. A force is written
`delta<isq::force>[N](5.)`, or `isq::force(delta<N>(5.))` when a delta of the kind already exists.
A vector value can't be stored under a bare unit (`vec * (m / s)` is ill-formed,
`delta<m / s>(vec)` isn't), and `point<m>(vec)` is ill-formed, as a vector point needs a vector
specification. A vector result is a delta: `(2. * m) * vec` is a delta. A delta of a
vector or tensor specification has no `.absolute()`, and its size is `magnitude()`, an absolute
scalar. A component of a vector delta is a delta along an axis, though its representation is a
scalar.

Whether the scalar is real or complex doesn't decide the abstraction: a complex scalar (an
impedance, a complex power) has a true zero and is an absolute, and `modulus()` of it is specified
as a real absolute (not yet in the prototype). `conj()`, `real()`, and `imag()` keep the
abstraction of their operand: the conjugate or a part of an absolute is an absolute with the same
zero, and that of a delta is a delta. `make_complex()` of two absolutes is an absolute, and of a
delta a delta.

The character of a quantity is otherwise the business of [@P3045R11_PRE]: a quantity never converts
to one of another character, even explicitly, and `magnitude()` gives the scalar of a vector. The
scalars the ISQ defines from vectors or tensors, such as work, are computed with the operations of
[@P4487R0], such as a scalar product. This paper adds only the abstraction of their results:
`magnitude()` and `modulus()` give an absolute, a vector or tensor result, such as `unit_vector()`,
is a delta, and the products follow the rule of [Products and quotients of two deltas].

## Conversions between abstractions {#absolute-conversions}

In [@P3045R11_PRE], the quantity specification carries the abstraction, the character, and the
origin, and one set of rules decides both whether one specification converts to another and whether
a quantity converts: a point never converts to a delta nor the other way round, a quantity never
converts to one of another character, and the rules of the hierarchy decide the rest. This paper
adds the rules for the absolute abstraction:

1. A point never converts to an absolute, nor the other way round.
2. A delta never converts to an absolute, even explicitly. `.absolute()` does that. An absolute
   converts to a delta implicitly, only of a specification of scalar character.
3. A quantity kind has no character of its own. A delta of a kind admits any character, and an
   absolute of a kind is a scalar.
4. A quantity kind converts to any specification of its tree, within its abstraction, and a delta
   of a kind may become a delta of a vector specification, as in
   `quantity<delta<isq::velocity>[m / s]> v = delta<m / s>(5.);`.
5. Between two absolutes, the hierarchy of [@P3045R11_PRE] decides, as it does between two deltas.

|     From\\To |                                     Point                                     |                                                         Absolute                                                         |                              Delta                              |
|-------------:|:-----------------------------------------------------------------------------:|:------------------------------------------------------------------------------------------------------------------------:|:---------------------------------------------------------------:|
|    **Point** | Implicit or explicit<br>within one independent origin;<br>`point_for(origin)` |           `.absolute()` (if the origin is a natural origin);<br>otherwise `(point - origin_or_qp).absolute()`            |      `point - origin_or_qp`;<br>`delta_from(origin_or_qp)`      |
| **Absolute** |  Explicit ctor<br>using `natural_point_origin`,<br>to a scalar specification  |                                                         Identity                                                         | Implicit construction<br>to a scalar specification;<br>.delta() |
|    **Delta** |                            origin + delta → point                             | Scalar: `.absolute()`;<br>real scalar: `abs()`; complex scalar: `modulus()`;<br>vector: `magnitude()`, a scalar absolute |                            Identity                             |

::: note
The implicit `absolute → delta` conversion is deliberate: `quantity<delta<m>> x = 40 * m;` works
without a cast, as an amount is routinely passed where a change is expected. Its cost is shown in
[Mass balance revisited](#mass-balance-revisited).
:::

The following examples demonstrate the explicit and implicit casts between all three abstractions:

```cpp
// ── From Absolute ──────────────────────────────────────────────────────────────────────
quantity<isq::mass[kg]> total = 5 * kg;

// Absolute → Delta: implicit (no notation at call site) or explicit .delta()
quantity<delta<isq::mass>[kg]> d1 = total;         // implicit
quantity<delta<isq::mass>[kg]> d2 = total.delta(); // explicit

// Absolute → Point: explicit construction only (attaches natural_point_origin)
quantity<point<isq::mass>[kg]> p{total};           // explicit ctor

// ── From Delta ─────────────────────────────────────────────────────────────────────────
quantity<delta<isq::mass>[kg]> change = 3 * kg;

// Delta → Absolute: explicit .absolute(), or the magnitude
quantity<isq::mass[kg]> amount = change.absolute();
quantity<isq::mass[kg]> size   = abs(change);      // |change|

// Delta → Point: origin + delta
quantity<point<isq::length>[m]> pos = natural_point_origin<isq::length> + delta<isq::length>[m](3);

// ── From Point ─────────────────────────────────────────────────────────────────────────
quantity<point<isq::thermodynamic_temperature>[K]> boiling{373.15 * K};

// Point → Delta: subtract a reference origin or another point
quantity<delta<isq::thermodynamic_temperature>[K]> above_zero =
    boiling.delta_from(natural_point_origin<isq::thermodynamic_temperature>);

// Point → Absolute: only valid when the point's origin is natural_point_origin
quantity<isq::thermodynamic_temperature[K]> t_abs = boiling.absolute();
```

An absolute may be negative in this paper, so `.absolute()` doesn't check the value, and a sign
check for non-negative quantities is left to [@P4411R1_PRE]. The conversion is still explicit. A delta
is a change, and an absolute is an amount measured from the true zero of its scale. Using one as
the other is the mistake of [The temperature trap]: a temperature change of 28 K passed where a
temperature of 28 K is needed. An implicit conversion would let that mistake compile, so
`.absolute()` marks the place where a change is used as an amount. The opposite direction is
implicit: an amount is the change from zero to that amount.

The common reference of an absolute and a delta of a scalar specification is the delta, the type
both of them convert to, which comparisons such as `5 * kg == delta<kg>(5)` need.
`get_common_reference` means conversion only, so it coincides with `std::common_type`, and the
result of an operator follows the operator's own rule, so `5 * kg + delta<kg>(5)` is an absolute.

## Concepts {#absolute-concepts}

Four concepts tell what a quantity is. `absolute_quantity`, `delta_quantity`, and `point_quantity`
each match one abstraction, and `linear_quantity` matches an absolute or a delta. An absolute and a
delta share every operation that doesn't look at the anchor (scaling, powers, conversions, text
output), and generic code that only needs "not a point" uses `linear_quantity`. These concepts are
what overloads and the rules of the model dispatch on.

`quantity_of<Q, V>` tells what a quantity can be used as. `V` is a quantity specification, and
the concept accepts what a parameter of the corresponding concrete type accepts, so it follows the
rules of [Conversions between abstractions](#absolute-conversions):

| `V`         | `quantity_of<Q, V>` matches                             | as a parameter of type   |
|-------------|---------------------------------------------------------|--------------------------|
| `QS`        | absolutes of `QS`; nothing for a vector or tensor `QS`  | `quantity<QS[U]>`        |
| `delta<QS>` | deltas of `QS`, and absolutes of `QS` for a scalar `QS` | `quantity<delta<QS>[U]>` |

`point<QS>` and `point<QS, PO>` match points as in [@P3045R11_PRE]. A function that needs an
amount, such as $E = kT$ with a thermodynamic temperature, constrains its parameter with
`quantity_of<Q, isq::thermodynamic_temperature>`, and a temperature difference is rejected, as it
is by a concrete `quantity<isq::thermodynamic_temperature[K]>` parameter. A function that needs a
change, such as an average speed from a distance traveled and an elapsed time, uses
`quantity_of<Q, delta<isq::length>>`, and an absolute is accepted, as it would convert to a
concrete delta parameter. A specification of vector or tensor character has no absolute, so
`quantity_of<Q, isq::velocity>` matches nothing, and a function that takes a velocity asks for
`quantity_of<Q, delta<isq::velocity>>`. That doesn't match an absolute such as `5. * m / s`, which
doesn't convert to a velocity.

`delta_quantity<Q>` asks whether `Q` is a delta, and `quantity_of<Q, delta<QS>>` whether it can be
used as one. A template that wants a change and should accept an absolute uses the latter, or
`linear_quantity` when the specification doesn't matter.

An overload constrained with `quantity_of<Q, QS>` is more constrained than one constrained with
`quantity_of<Q, delta<QS>>`, so an absolute argument selects the first and a delta the second. In
the prototype, `quantity_of<Q, delta<QS>>` is written as a disjunction whose first alternative is
the constraint of `quantity_of<Q, QS>`.

## Arithmetic semantics {#absolute-arithmetic}

Addition, subtraction, and scaling by a number keep the absolute abstraction whenever the result
stays anchored at the true zero of the operands (see
[the zero-anchor principle](#abs-delta-rationale)). Products and quotients of two absolutes are
absolutes, as absolutes live on a ratio scale (see [Absolute quantities are not points](#abs-vs-point)),
and the rule for a delta operand is given in [Products and quotients of two deltas].

The following tables give the result abstraction of each operation. The absolute rows and columns
of addition and subtraction apply to scalar specifications only (see
[Scalar and vector quantities](#absolute-scalar-vector)). Multiplication takes any character: an
absolute mass times a vector acceleration is a vector delta.

### Addition

|   Lhs \\ Rhs | Point | Absolute |  Delta   |
|-------------:|:-----:|:--------:|:--------:|
|    **Point** |   ✗   |  Point   |  Point   |
| **Absolute** | Point | Absolute | Absolute |
|    **Delta** | Point | Absolute |  Delta   |

Two absolutes add to an absolute (two masses give a total mass), and an absolute shifted by a
change stays anchored at zero. Adding an absolute or a delta to an origin yields a point, as in
`msl + 100. * m`.

```cpp
quantity tank   = isq::mass(500 * kg);        // quantity<isq::mass[kg]>
quantity refuel = delta<isq::mass>[kg](200);  // quantity<delta<isq::mass>[kg]>: +200 kg (signed change)
quantity loaded = tank + refuel;              // quantity<isq::mass[kg]>: 700 kg
tank += refuel;                               // same: tank is now 700 kg

// To get a signed result instead, explicitly demote before the operation:
quantity balance = tank.delta() + refuel;     // quantity<delta<isq::mass>[kg]>
```

### Subtraction

|   Lhs \\ Rhs | Point | Absolute |  Delta   |
|-------------:|:-----:|:--------:|:--------:|
|    **Point** | Delta |  Point   |  Point   |
| **Absolute** |   ✗   |  Delta   | Absolute |
|    **Delta** |   ✗   |  Delta   |  Delta   |

The difference of two absolutes is a signed change, a delta. A delta minus an absolute stays a
delta, because a delta has no zero anchor to preserve.

```cpp
quantity before = isq::mass(100 * kg);  // quantity<isq::mass[kg]>
quantity after  = isq::mass(80 * kg);   // quantity<isq::mass[kg]>
quantity lost   = before - after;       // quantity<delta<isq::mass>[kg]>: +20 kg (a change)

quantity usage     = delta<isq::mass>[kg](20); // quantity<delta<isq::mass>[kg]>: a signed change
quantity remaining = before - usage;           // quantity<isq::mass[kg]>: 80 kg
before -= usage;                               // same: before is now 80 kg

// To get a signed balance, demote first:
quantity deficit = before.delta() - usage;     // quantity<delta<isq::mass>[kg]>
```

If an absolute result is needed from an `absolute − absolute` subtraction (e.g., when you
know the difference is non-negative), use an explicit conversion:

```cpp
quantity transferred = (before - after).absolute();  // quantity<isq::mass[kg]>
```

### Multiplication and division

| Operation                 | Result   | Physical Meaning                                                                          |
|:--------------------------|:---------|:------------------------------------------------------------------------------------------|
| Absolute × Absolute       | Absolute | A product of two absolute quantities (energy = power × time)                              |
| Absolute × Number         | Absolute | Rescaling by a scalar number, whatever its sign (2 × mass stays absolute mass)            |
| Absolute × Delta          | Delta    | Absolute scaled by a change is a change (e.g., area × Δheight → Δvolume)                  |
| Delta × Absolute          | Delta    | (same as Absolute × Delta; multiplication is commutative)                                 |
| Delta × Number            | Delta    | Rescaling a signed difference (factor preserves delta abstraction)                        |
| Absolute / Absolute       | Absolute | A physical ratio (efficiency, density)                                                    |
| Absolute / Delta          | Delta    | Rate of an absolute w.r.t. a signed step                                                  |
| Delta / Absolute          | Delta    | A change scaled by a fixed absolute reference                                             |
| Delta × Delta             | Delta    | A product of two changes (see [Products and quotients of two deltas])                     |
| Delta / Delta             | Delta    | A rate of change (velocity = displacement / duration)                                     |
| `abs(delta)`              | Absolute | Of a real scalar specification; ill-formed for a vector specification                     |
| `pow<N>(delta)`           | Delta    | Any `N`: a power doesn't measure a size, even where it can't be negative                  |
| `modulus(complex_scalar)` | Absolute | Modulus of a complex number                                                               |
| `magnitude(delta_vector)` | Absolute | Magnitude of a vector delta (the magnitude of a velocity is a speed)                      |
| `a % b`, `fmod(a, b)`     | Dividend | The abstraction of the dividend, whose sign the remainder has                             |
| `remainder(a, b)`         | Delta    | The remainder can be negative whatever the signs of the operands                          |
| `hypot(x, y)`             | Absolute | Of a scalar specification, as for `abs`; ill-formed for a vector specification            |

#### Products and quotients of two deltas

A single delta in a product is a delta by linearity: for a fixed absolute `k`, `k * Δy` is the
change of `k * y`, so a heat `m * c * ΔT` of a fixed mass is a change. A product or a quotient of two
deltas is not the change of anything. `Δx * Δy` is not the change of a product, and `Δy / Δx` is a
slope, measured from its own zero. Whether the two deltas are correlated decides only the sign of
the result, not its abstraction. The rule has to hold for binary operators, though, and "a delta
only with exactly one delta factor in the numerator" doesn't, as `(Δa / Δc) * Δb` would be a delta
and `(Δa * Δb) / Δc` an absolute. Three alternative rules work for every grouping of the operands:

- The result is a delta when any operand is one. It never makes an absolute of a change, but it
  labels some new quantities as deltas, and it costs a `.absolute()` after a quotient of deltas.
- Two deltas cancel. It fixes every quotient above, but it labels `1 / Δt` and a product of three
  differences a delta.
- The reference carries a delta exponent, counted like a dimension. It is exact, but every
  reference then carries an integer instead of a flag.

This paper proposes the first rule, which is the one the table above uses. In the examples of
[@MP-UNITS], it costs four `.absolute()` calls, each after a quotient: a glide distance computed
from two altitude differences, the durations of an aircraft tow and of a climb in a thermal, each a
height change divided by a rate of climb, and the gain of a Kalman filter, a ratio of variances.

A power follows the same rule: `pow<N>(Δx)` is a delta for every `N`, as `Δx * Δx` is. An even
power can't be negative, but the sign doesn't decide the abstraction, as
[the zero-anchor principle](#abs-delta-rationale) explains. Only an operation that measures a size
makes an absolute of a delta: `abs(Δx)`, `hypot(Δx, Δy)`, `magnitude()` of a vector, and
`modulus()` of a complex scalar. `hypot(x, 0)` equals `abs(x)`, and `hypot(x2 - x1, y2 - y1)` is
the same distance as `magnitude(r2 - r1)` for vector positions, so all of them are absolutes. The
cost is that `sqrt(pow<2>(Δx) + pow<2>(Δy))` is a delta while `hypot(Δx, Δy)` is an absolute. So a
variance computed as the square of a delta, such as the variance of an estimate in the Kalman
filter examples, is a delta, and the Kalman gain, a ratio of two
variances, needs `.absolute()`.

A power of a quantity of a vector specification is ill-formed in [@P3045R11_PRE], even one stored
in a `double`, and this paper makes `abs()` and `hypot()` of it ill-formed too: they are scalar
operations, and the size of a vector is its `magnitude()`. The square of a velocity along one axis
is written `pow<2>(v.magnitude())`, an absolute, because `v.magnitude()` is one.

### Compound assignment {#absolute-compound}

For the abstraction, `a op= b` follows `a = a op b`, so it is ill-formed when the abstraction of
`a op b` can't be stored in `a`: an absolute takes no `-=` of an absolute and no `*=` or `/=` of a
delta. Without that rule, `a -= b` would turn a delta into an absolute without `.absolute()`.

### Sign of an absolute quantity {#absolute-sign}

An absolute quantity is anchored at a true zero, and nothing in this paper constrains its sign.
An electric current is positive or negative relative to the reference direction chosen for it, and
under the load sign convention a reactive power is positive for an inductive load and negative for
a capacitive one, while both have a physically meaningful zero. If [@P4411R1_PRE] is adopted,
absolute quantities are where its `non_negative` tag is checked on values, and
[@P4411R1_PRE] describes where the checks run and why they can't be elided further.

With [@P4411R1_PRE], the abstraction decides which values its check applies to. A delta is never
checked, as a change can have either sign. An absolute is checked when its quantity specification is
non-negative. A quantity kind `kind_of<QS>` is defined only for a root `QS` and takes the domain of
that root, so `kind_of<isq::length>`, `kind_of<isq::mass>`, and
`kind_of<isq::thermodynamic_temperature>` are non-negative, while `kind_of<isq::electric_current>`
isn't. A value written with a bare unit is an absolute of a kind, so `-5. * m` and `-5. * K` are
contract violations, and a signed value is written `delta<m>(-5.)` or `delta<K>(-5.)`. An unnamed
specification, such as `isq::mass / isq::volume` or the kind of a unit expression such as `m / s`,
is never non-negative, because the domain is stated in the definition of a named quantity, and an
unnamed specification has no definition. The checks of points and of `possibly_negative`
specifications are specified in [@P4411R1_PRE]: a point is checked when its own specification is
non-negative and the chain of its origins ends at a true zero, so `point<deg_C>(-300.)` is a
violation through `ice_point`, and a point measured from an `independent_point_origin`, such as an
epoch or a tare, never is. A `possibly_negative` specification under a non-negative parent, such as
_effective mass_ under _mass_, keeps the units and the natural origin of its parent and is never
checked.

### For discussion: a negative value written with a bare unit {#absolute-negative-bare-unit}

This consequence of the model is the one users will hit first, and SG6 is asked to discuss it
explicitly. With absolute quantities and [@P4411R1_PRE] adopted, a value written with a bare unit
is a checked absolute of its kind. Code that writes `-5. * K` to mean "5 K colder" is a contract
violation, and the change has to be written as a delta:

```cpp
quantity t1 = -5. * K;           // ✗ contract violation: a temperature 5 K below absolute zero
quantity t2 = delta<K>(-5.);     // ✓ a temperature change of -5 K

quantity o1 = -3. * m;           // ✗ contract violation: a negative length
quantity o2 = delta<m>(-3.);     // ✓ an offset of -3 m

quantity e1 = -1. * s;           // ✗ contract violation: a negative duration
quantity e2 = delta<s>(-1.);     // ✓ one second earlier
```

The rule is consistent with the rest of the model: `28 * K` is a temperature, so `-5. * K` is a
temperature below absolute zero, and a value doesn't change its abstraction with its sign. The
cost is that the shortest spelling of a signed change in a unit of a non-negative kind is now
wrong. In a constant expression evaluated under a terminating contract semantic (enforce or
quick-enforce), such as `constexpr quantity t = -5. * K;`, the violation fails to compile, and under
observe it is only diagnosed. At run time it is a contract violation only when the check runs, and
under a semantic that doesn't check, the negative absolute is stored. The prototype implements this
check: with gsl-lite as its contract backend, `constexpr quantity t = -5. * K;` doesn't compile, and
`-5. * K`, `-1 * kg`, and `-1. * s` evaluated at run time terminate. Values of a kind that admits
negative values, such as `-5. * A`, are unaffected.

Operator grouping makes the rule reach further than these three lines suggest.
[@P3045R11_PRE] extended the multiply syntax from `number * unit` to `quantity * unit` and
`quantity / unit` (see its chapter "Multiply syntax commutativity"), so `1 * m / s` is two
operations, and its intermediate result `1 * m` is a quantity of its own. With checked absolutes,
that intermediate can fail where the whole expression wouldn't, and the same happens before a
conversion to a signed quantity:

```cpp
quantity v1 = -1. * m / s;               // ✗ contract violation: (-1. * m) is a negative length
quantity v2 = -1. * (m / s);             // unchecked, as the kind of m / s is never non-negative,
                                         //   but still a negative absolute
quantity v3 = delta<m / s>(-1.);         // ✓ a signed velocity component is a change

quantity v4 = isq::velocity(-1. * (m / s));      // ✗ ill-formed: an absolute never converts to a vector
quantity v5 = isq::velocity(delta<m / s>(-1.));  // ✓

quantity q1 = -1. * s * A;               // ✗ contract violation: (-1. * s) is a negative duration
quantity q2 = -1. * A * s;               // ✓ an electric charge can be negative

quantity a1 = isq::altitude(-5. * m);    // ✗ contract violation: -5. * m is a negative length
quantity a2 = isq::altitude[m](-5.);     // ✓ altitude is signed
quantity a3 = -5. * isq::altitude[m];    // ✓
```

Under the model, `v1` and `v2` are both wrong spellings of a signed value, and `v2` passes only
because the kind of a unit expression carries no sign, just as an expression of quantity
specifications carries none. The parentheses, or the order of the units, decide whether the mistake
is caught. `v4` is ill-formed at compile time, whatever the sign of the value and the grouping of
the units, as is `isq::displacement(-5. * m)`. Three options are possible:

- keeping the multiply syntax of [@P3045R11_PRE], and teaching that a signed value of a
  non-negative kind is a delta: `v1` and `q1` are then run-time violations that point at that
  spelling;
- restricting the multiply syntax to `number * unit`, so that `quantity * unit` and
  `quantity / unit` are ill-formed: `v1` and `q1` become compile-time errors, at the cost of
  writing every `42 * m / s` as `42 * (m / s)` in existing code, which the extension of
  [@P3045R11_PRE] was added to avoid;
- not checking a value written with a bare unit at all, which also leaves `-5. * K` unchecked.

The author doesn't propose any of them. The first keeps a defect that only a negative value
reaches, and only when the check runs. The second reverses a decision of [@P3045R11_PRE] and changes
a large amount of existing code. The multiply syntax already has known problems that
[@P3045R10_PRE] records. The order of operations in `quantity * unit` and `quantity / unit`
surprises users, as `60 * km / 2 * h` shows in [Potential surprises during units
composition](https://wg21.link/p3045r10#potential-surprises-during-units-composition),
which also explains why [@MP-UNITS] gave up the second option once before. Whether to extend the
syntax further is an open question in
[Multiply syntax commutativity](https://wg21.link/p3045r10#multiply-syntax-commutativity). This
interaction adds to those problems, and it may be a reason to revise the design. The author asks
SG6 to decide the final design of the multiply syntax with all of these issues in view, rather than
this one alone.

### Unary negation {#absolute-negation}

The negation of an amount is the change that cancels it, so `-mass` is never a mass, while the
negation of an electric current is a current flowing the other way. Which of the two applies
depends on whether the quantity can be negative, which is what the `non_negative` tag of
[@P4411R1_PRE] states. The rule for `-x` therefore depends on whether that paper is adopted.

**If [@P4411R1_PRE] is adopted,** `-x` keeps the absolute abstraction when the quantity
specification of `x`, named or the kind of a named root, admits negative values. It yields a
delta for a `non_negative` specification, a kind whose root is `non_negative`, and an unnamed
derived specification or the kind of one, whose sign the library doesn't infer from a quantity
equation. The root of the kind of a unit expression is unnamed, so `-(2. * (kg / m3))` is a delta,
as `-(isq::mass(2. * kg) / isq::volume(1. * m3))` is. A kind takes the domain of its root, so
`-(5. * A)` keeps the absolute abstraction and `-(2. * kg)` doesn't:

```cpp
quantity<isq::electric_current[A]> I1 = ..., I2 = ...;
quantity<isq::electric_current[A]> I3 = -(I1 + I2);  // an absolute current, as Kirchhoff's law needs

quantity<isq::kinetic_energy[J]> Ek = ...;
quantity<isq::thermodynamic_temperature[K]> T = ...;
auto ratio = -Ek / T;    // delta<kinetic_energy> / absolute<temperature> = delta<...>
auto Ek2 = abs(-Ek);     // the magnitude of a delta is an absolute again
```

The cost is that the result type of `-x` depends on the quantity specification, so generic code
that negates an absolute has to allow for both outcomes. Algebraically equal spellings can differ as
well: `-I1 - I2` subtracts an absolute from an absolute and is a delta (see
[Algebraic-equivalence asymmetry](#abs-algebraic-equivalence)). The abstraction already depends on the
specification elsewhere, as a vector specification is never an absolute, and generic code that
needs a delta writes `-x.delta()`.

**Without [@P4411R1_PRE],** no specification has the tag, so the rule above can't tell a mass from
a current and would make `-mass` an absolute. `-x` is then a delta for every absolute. The result
type follows from the abstraction of the operand alone, and the cost falls on quantities whose
absolutes can be negative, such as electric current, electric charge, or reactive power: in
`I3 = -(I1 + I2)` the right-hand side is a delta, and storing it in a current needs `.absolute()`.

Under either rule, `-1 * x` scales an absolute by a number and stays an absolute, so it can differ
in type from `-x`. If [@P4411R1_PRE] is adopted, its sign check rejects `-1 * isq::mass[kg]` and
`-1 * kg`, each a negative amount, while `-(1 * isq::mass[kg])` and `-(1 * kg)` are deltas.

## Design rationale: the zero-anchor principle {#abs-delta-rationale}

The rule `Absolute ± Delta → Absolute` is the most visible choice in the arithmetic
tables. The initial design of the library proposed the opposite rule, `Absolute ± Delta →
Delta`, on the grounds that any such operation _can_ produce a negative result, so the
type should conservatively demote to the unrestricted delta space. This section explains why
we changed it: the initial reasoning conflates two orthogonal concerns, the abstraction of a
quantity and the sign constraint on its value.

### The zero-anchor principle {#zero-anchor}

The result abstraction of `absolute ± delta` follows from the **zero-anchor principle**: an
operation preserves the absolute abstraction
when the result remains anchored at the same physically meaningful true zero. A delta is a
signed change with no inherent zero anchor. Adding or subtracting a delta from
a zero-anchored quantity does not destroy the zero anchor, as the result is still measured
from the same origin:

- `mass_tank + Δ_refuel` → the total mass is still measured from absolute zero (0 kg).
- `mass_tank − Δ_burnt` → what remains is still a mass anchored at zero.

This is the rule used for points in affine spaces: `point ± delta → point`. Both express "a
translation preserves the abstraction relative to its origin": the affine origin for a point, the
true zero for an absolute.

#### Rejected alternative: universal demotion to delta

The initial design demoted _all_ `absolute ± delta` to delta, reasoning that since a delta
can be negative, the result "might" be negative and the type should conservatively reflect
that. This was rejected for two reasons:

1. Type demotion is the wrong mechanism for value-range violations. `abs ± delta` may be
   negative at runtime, but so may `abs × number`, and `Absolute × Number → Absolute` was never in
   doubt. Both operations leave the zero anchor where it is, yet the rejected rule would demote
   `absolute ± delta` but not `absolute × number`, although a delta is a stricter type than a
   number. Whether a value is in range is a property of the value, and a
   check on the value answers it, such as the one [@P4411R1_PRE] proposes.

2. It conflates abstraction with value constraint. Possibly-negative absolutes like
   `reactive_power` belong on a ratio scale regardless of their sign. Under universal
   demotion, `reactive_power + delta<reactive_power>` would yield `delta<reactive_power>`,
   changing the abstraction and making it impossible to store the result back into a
   `reactive_power` variable without an explicit conversion.

### Handling underflow: when `delta > absolute` {#abs-underflow}

Under the adopted rule, `abs - delta` keeps the absolute type, whatever the value. Consider a fuel
burn where the maneuver needs more fuel than the tank holds, with the burn modeled as a delta:

```cpp
quantity fuel        = isq::mass(500. * kg);        // absolute: fuel present in the tank
quantity consumption = delta<isq::mass>[kg](600.);  // delta: how much the maneuver burns
fuel -= consumption;                                // absolute: −100 kg
```

This paper accepts the −100 kg absolute. If [@P4411R1_PRE] is adopted, its sign check rejects it, as
the prototype does.

The model is the problem. A delta is a change of something, and the change this maneuver makes to
the tank is −600 kg, not +600 kg. The mass the maneuver burns is an amount: it is measured from
zero and can't be negative, so it is an absolute, and the change to the tank is `-consumption`.
Modeled this way, `abs − abs → delta` gives the signed balance, and code that has to react to a
deficit turns it into an amount only after checking its sign:

```cpp
quantity fuel        = isq::mass(500. * kg);  // absolute: fuel present in the tank
quantity consumption = isq::mass(600. * kg);  // absolute: mass the maneuver burns
quantity balance     = fuel - consumption;    // abs − abs → delta<mass>: −100 kg
if (balance < 0 * kg) {
  quantity shortfall = abs(balance);          // absolute: 100 kg
  // handle shortfall: reduce maneuver, add fuel, abort, …
} else {
  fuel = balance.absolute();                  // the balance is not negative here
}
```

Code that has to keep `consumption` a delta gets the same signed balance by demoting first,
`fuel.delta() - consumption`.

### Algebraic-equivalence asymmetry {#abs-algebraic-equivalence}

An objection raised in private review (Yongwei Wu) observes that the algebraic identity

$$a + b = c \;\Longleftrightarrow\; a = c - b$$

does not preserve types. If `a`, `b`, `c` are all absolutes, the left-hand side is
`absolute + absolute → absolute`, but the right-hand side `c - b` is
`absolute − absolute → delta`. The rewritten form `a = c - b` then assigns a `delta` to an
`absolute`, which is a type error.

This asymmetry is intrinsic to the three-abstraction model. The rule `absolute − absolute → delta`
reflects a physical fact: the _difference_ between two zero-anchored magnitudes is a signed
change, not a new magnitude. For a quantity whose values can't be negative this is
especially clear (a convex cone is closed under addition but not under subtraction by definition),
but the asymmetry holds for all absolutes. Even
`electric_current − electric_current → delta<electric_current>`: the difference between two
current values is a signed change, not a current level. Removing the asymmetry would require
`abs − abs → abs`, which labels a difference as an amount and so would abandon the distinction
between absolute and delta.

```cpp
// The identity a + b = c does NOT mean c − b has the same type as a:
quantity<isq::mass[kg]> a = 30 * kg;        // absolute
quantity<isq::mass[kg]> b = 70 * kg;        // absolute
quantity<isq::mass[kg]> c = a + b;          // absolute: 100 kg

// quantity<isq::mass[kg]>     a2 = c - b;             // ✗ delta<mass> ≠ absolute<mass> (type error)
quantity<delta<isq::mass>[kg]> diff = c - b;           // delta<mass>: 30 kg — correct delta type
quantity<isq::mass[kg]>        a2   = diff.absolute(); // explicit re-entry: 30 kg
```

## Text output {#absolute-text-output}

An absolute quantity prints like any quantity: `42 * kg` prints `42 kg`, the same text as
`delta<kg>(42)`, so absolutes need no formatter of their own. The output of points is discussed
in [@P3045R11_PRE].

## Temperature revisited {#absolute-temperature}

With absolute quantities, the temperature use case from [The temperature trap](#temp-trap) is
resolved. The key change is in what an offset unit is.

In [@P3045R11_PRE], `kelvin` names `absolute_zero` as its point origin, which triggers the multiply
syntax restriction and prevents `28 * K` from compiling.
Under the absolute quantities model, an **offset unit** is a unit whose point origin is not a
natural origin, that is, doesn't compare equal to `natural_point_origin<QS>`. The natural origin of
a kind marks the same true zero as the natural origin of a quantity of that kind, so
`natural_point_origin<isq::thermodynamic_temperature>` and
`natural_point_origin<kind_of<isq::thermodynamic_temperature>>` compare equal.
`si::absolute_zero` is the natural origin of thermodynamic temperature under a name of its own, and
`kelvin` keeps naming it as its origin, so the kelvin is not an offset unit. The name exists so that
the `temp - absolute_zero` idiom of [The temperature trap](#temp-trap) keeps working and so that
types print a meaningful origin. `ice_point` stays a relative origin, an offset in millikelvin from
the kelvin scale, so `degree_Celsius` is an offset unit, and so is `degree_Fahrenheit`. In the
prototype, `natural_point_origin_` is the class type of `natural_point_origin`:

```cpp
inline constexpr struct absolute_zero : natural_point_origin_<kind_of<isq::thermodynamic_temperature>> {} absolute_zero;
inline constexpr struct kelvin : named_unit<"K", kind_of<isq::thermodynamic_temperature>, absolute_zero> {} kelvin;

// Celsius chain: offset value 273.150 K unchanged
inline constexpr struct ice_point : relative_point_origin<point<milli<kelvin>>(273'150)> {} ice_point;
inline constexpr struct degree_Celsius : named_unit<symbol_text{u8"°C", "`C"}, kelvin, ice_point> {} degree_Celsius;
```

With this definition, a value in kelvins such as `28. * K` is an absolute temperature, and the
ideal gas law can be written directly:

```cpp
quantity P = 1. * atm;
quantity V = 1. * L;
quantity n = 1. * mol;
quantity T = 301.15 * K;                 // absolute temperature
quantity R_calc = P * V / (n * T);       // compiles, correct
```

When working with Celsius input, the conversion path is explicit but straightforward:

```cpp
// auto T = 28. * deg_C;                 // still does not compile — offset unit
quantity temp = point<deg_C>(28.);       // 28 °C on the Celsius scale
// quantity T = temp.absolute();         // does not compile: the origin is ice_point, not a natural one
quantity T = temp.in(K).absolute();      // 301.15 K — absolute temperature
quantity R_calc = P * V / (n * T);       // compiles, correct
```

A point on the Celsius scale is not an absolute temperature, and it must be converted explicitly.
`.in(U)` keeps the plain specification of a point, and a point measured from the
origin of an offset unit moves to the origin of the new unit: `point<deg_C>(28.).in(K)` is a
`quantity<point<K>>`, measured from `absolute_zero`, and `.absolute()` then applies to it.
Likewise, `point<isq::thermodynamic_temperature, si::ice_point>[deg_C](20.).in(K)` is a
`quantity<point<isq::thermodynamic_temperature>[K]>`. A point measured from any other origin
keeps its origin. The `.in(K).absolute()` chain replaces the [@P3045R11_PRE] workaround
`temp.in(K).delta_from_zero()`.

The lower bound of a Celsius point needs no bounds policy on `ice_point`: the chain of
`ice_point` ends at `absolute_zero`, so if [@P4411R1_PRE] is adopted, `point<deg_C>(-300.)` is a
contract violation.

## Mass balance revisited {#mass-balance-revisited}

With absolute quantities, the mass balance use case from [Mass balance and accumulation](#mass-balance)
gains type-safety through the distinction between absolute and delta:

```cpp
quantity<delta<percent>> moisture_loss(quantity<delta<kg>> water_lost, quantity<kg> total)
{
  return water_lost / total;
}

quantity total_initial = 100 * kg;                        // absolute mass
quantity total_dried   = 80 * kg;                         // absolute mass
quantity water_lost    = total_initial - total_dried;     // delta<mass>: +20 kg (difference)

quantity loss = moisture_loss(water_lost, total_initial); // Correct

// Attempting to swap arguments:
// auto loss = moisture_loss(total_initial, water_lost);
//   arg1: absolute → delta<kg> param: ✓ compiles — absolute→delta is implicit
//   arg2: delta<kg> → absolute param: ✗ fails — delta→absolute requires explicit .absolute()
// The call fails overall, but only because of the second argument.

// A subtler mistake — two absolutes — also compiles:
// auto loss = moisture_loss(total_initial, total_initial);
//   arg1: absolute → delta<kg> param: ✓ implicit
//   arg2: absolute → absolute param: ✓ identity
// Result: total_initial / total_initial = 1.0 (100%) — wrong answer, no diagnostic
```

The three-way split is a partial solution to the argument-swapping problem. It rejects passing a
delta where an absolute is required, but `moisture_loss(total_initial, total_initial)` still
compiles because the implicit `absolute → delta` conversion (see the [conversion
note](#absolute-conversions)) allows `total_initial` to satisfy the `delta<kg>` first parameter.
Requiring an explicit `.delta()` call for that conversion would also make the subtler mistake a
compile error, at the cost of a cast wherever an amount is passed as a change. This paper keeps the
conversion implicit, so the residual argument-swap risk remains in the domain of naming conventions
and code review.

## Averages and centers of mass {#averaging}

At Brno 2026, SG6 asked how to average temperature readings in degrees Celsius and how to
compute a center of mass, when two points can't be added and a point can't be multiplied by a
mass. The textbook formula adds the values first:

```cpp
using celsius_reading = quantity<point<deg_C>>;
std::array<celsius_reading, 3> readings{point<deg_C>(20.), point<deg_C>(22.5), point<deg_C>(26.)};

quantity avg = (readings[0] + readings[1] + readings[2]) / 3;  // ✗ point + point is ill-formed
```

The same expression compiles for absolute temperatures in kelvins, as absolutes can be added. For
Celsius readings it must not compile: the sum of two readings depends on the origin of the scale.
20 °C and 22.5 °C would sum to 42.5 °C on the Celsius scale, but to 588.8 K, which is 315.65 °C, on
the Kelvin scale. The mean doesn't depend on the origin. It can be written with differences only:

$$\bar{x} = x_1 + \frac{1}{n}\sum_{i=1}^{n}(x_i - x_1)$$

Every operation on the right is valid for points: $x_i - x_1$ is a delta, a delta divided by a
number is a delta, and a point plus a delta is a point. A weighted mean has the same form,

$$\bar{x} = x_1 + \frac{\sum_{i} w_i (x_i - x_1)}{\sum_{i} w_i}$$

and with masses as weights and positions as points it is the center of mass, computed without
multiplying a point by a mass. For two masses, the model already allows writing it by hand:

```cpp
using vec3 = utility::cartesian_vector<double>;  // a vector type of the reference implementation
using position = quantity<point<isq::position_vector>[m], vec3>;

position r1 = point<isq::position_vector>[m](vec3{0., 0., 0.});
position r2 = point<isq::position_vector>[m](vec3{4., 0., 0.});
quantity m1 = 2. * kg;
quantity m2 = 1. * kg;

position center = r1 + (r2 - r1) * (m2 / (m1 + m2));  // [1.333, 0, 0] m
```

The reference implementation provides both algorithms in its utility library as
`mp_units::utility::mean` and `mp_units::utility::weighted_mean`. They accept ranges of
absolutes, deltas, or points, and return the type of the values:

```cpp
celsius_reading avg = utility::mean(readings);  // 22.83 °C, measured from the ice point

std::array<position, 3> positions{point<isq::position_vector>[m](vec3{0., 0., 0.}),
                                  point<isq::position_vector>[m](vec3{4., 0., 0.}),
                                  point<isq::position_vector>[m](vec3{0., 8., 0.})};
std::array masses{2. * kg, 1. * kg, 1. * kg};
position center = utility::weighted_mean(positions, masses);  // [1, 2, 0] m
```

Neither function adds the values up. Every intermediate value is a difference from the first value
or from the running mean, so only the spread of the values has to fit in the representation. This
also avoids the overflow of the textbook formula for absolutes. The two functions are not proposed
in this paper.

## Impact on [@P3045R11_PRE] {#absolute-impact}

This is a breaking change to the initial proposal:

1. `quantity<R>` becomes an absolute quantity instead of a delta.
2. Users who need a delta must write `quantity<delta<R>>`, use the `delta<R>(value)`
   construction helper, or call `.delta()` on an existing absolute quantity.
3. `absolute − absolute` returns a delta, not an absolute (the same rule as `point − point → delta`).
   Existing code that assigns such a result to an `absolute` variable will fail to compile;
   the fix is either to change the target type to `delta<R>` or to call `.absolute()` on the
   result to explicitly re-enter the absolute domain.
4. `linear_quantity`, the concept of an absolute or a delta, joins the new `absolute_quantity`
   and the `delta_quantity` and `point_quantity` of [@P3045R11_PRE]. Generic code that
   constrained a parameter with "a delta" to mean "not a point" migrates to it.
   For a specification of scalar character, `quantity_of<Q, QS>` matches only absolutes, so a
   difference or an explicit delta passed where `quantity_of<Q, QS>` is required now needs
   `delta<QS>` in the constraint (see [Concepts](#absolute-concepts)).
5. A `quantity_like_traits` specialization whose `reference` is a bare unit now imports an
   absolute, so the `std::chrono::duration` specialization names `delta<R>` to stay a delta: the
   C++ type is a difference, and importing it as an absolute would make the conversion back to
   `std::chrono` a refused delta → absolute conversion. So
   `speed * quantity{std::chrono::seconds{5}}` is a delta distance, and storing it in a
   `quantity<m>` needs `.absolute()`. A `time_point` stays a point.
6. A quantity of a vector or tensor specification is never an absolute (see
   [Scalar and vector quantities](#absolute-scalar-vector)). A vector type is spelled
   `quantity<delta<isq::velocity>[m / s], vec3>` instead of `quantity<isq::velocity[m / s], vec3>`,
   and a vector value is created with `delta<isq::velocity>[m / s](vec)` or `delta<m>(vec)`
   instead of `vec * isq::velocity[m / s]` or `vec * m`. `isq::velocity(5. * m / s)`,
   `isq::force(5. * N)`, `isq::weight(mass * g)` with an absolute `mass` and an acceleration `g`
   given as an absolute of its kind, and `point<m>(vec)` become ill-formed, and
   `quantity_of<Q, isq::velocity>` matches nothing, and generic code that takes a velocity is
   constrained with `quantity_of<Q, delta<isq::velocity>>`.
7. A value of a bare unit is an absolute of its kind. If [@P4411R1_PRE] is adopted, a negative
   value of a non-negative kind, such as `-5. * K` written for a temperature change, is a contract
   violation, and the change is written `delta<K>(-5.)` (see
   [For discussion](#absolute-negative-bare-unit)).
8. `-x` on an absolute is a delta when its quantity specification doesn't admit negative values or
   is an unnamed derived specification or the kind of one, and for every absolute if
   [@P4411R1_PRE] isn't adopted
   (see [Unary negation](#absolute-negation)).
9. Compound assignment keeps the abstraction of its left operand, so `a -= b` with two absolutes
   is ill-formed (see [Compound assignment](#absolute-compound)).
10. A product or a quotient of two deltas is a delta, so a value such as `(x2 - x1) * (y2 - y1)`
   stored in a `quantity<isq::area[m2]>` needs `.absolute()` (see
   [Products and quotients of two deltas]).
11. `remainder(a, b)` of two absolutes returns a delta, while `a % b` and `fmod(a, b)` keep the
   abstraction of the dividend.
12. This paper proposes renaming `absolute_point_origin` to `independent_point_origin` (see
   [Open questions](#absolute-impl-open)).

Code that uses `quantity` for absolute amounts (mass, distance, speed) keeps its meaning, because
those _are_ absolute quantities. Code that uses it for signed differences has to write them as
`delta<>`.

## Implementation experience {#absolute-implementation-experience}

Absolute quantities are implemented on a prototype branch off the version 3 line of [@MP-UNITS]
(October 2026). The library, its tests, and its examples build and pass with GCC 15 and Clang 21.

Most of the library changed mechanically. In the tests and the examples, most changes had one
reason: the previous model couldn't express what the code meant. An amount and a change were the
same type, so code written for that model had to approximate its intent. With three abstractions,
each of those approximations was replaced by what the code meant, and some of them turned out to be
real errors (see [The model finds real errors]). The rules of [Scalar and vector
quantities](#absolute-scalar-vector) alone changed about 60 spellings of a vector type to
`quantity<delta<QS>[U], Rep>`, about 60 values of a vector specification written as `value * QS[U]`,
9 conversions from an absolute into a vector specification, and 33 point constructions in the Kalman
filter examples. A few questions remain open for SG6 (see [Open questions](#absolute-impl-open)).

### The model finds real errors

The rule `absolute − absolute → delta` exposed category errors in the library itself. Five
functions stored the difference of two positions back into a position type: `floor` and `ceil`,
`wrap_to_range` and `reflect_in_range`, and the canonical form of a spherical vector.

Together with the `non_negative` check of [@P4411R1_PRE], the model also found signed changes stored
as absolutes in the tests: negative durations fed to the rounding functions, a −3 m projection
offset stored as a length, negative origin bounds, and negative and NaN inputs of formatting tests.
Checking values written with a bare unit changed about 300 more lines of the tests, nearly all of
them negative literals such as `-42 * m` used as signed numbers and now written `delta<m>(-42)`, and
the glide computer example, whose sink rates are written `delta<m / s>(-0.7389)`.
In the examples it found three modeling errors:

- A rate of climb, a child of `speed`, was an absolute, but a sinking glider has a negative rate
  of climb, so it is now a delta.
- A price was modeled as a point, but it has a true zero and is scaled by a share count, so it is
  an absolute.
- The heights of a glider above the ground were absolutes, but each is the difference of two
  altitudes, so they are deltas.

### What generic code needs

Most generic code in the library, and nearly every generic test helper, needs "an absolute or a
delta", which is to say "not a point". This is where `linear_quantity` comes from. A survey of the
generic code found no place that needs a delta but must reject an absolute, while about 18 places in
the examples need an amount and about 12 a change that an absolute may stand for. This led to the
meaning of `quantity_of` described in [Concepts](#absolute-concepts), which the prototype
implements. Of the 64 uses of `quantity_of` in the examples of [@MP-UNITS], 5, in three examples,
were widened to `delta<QS>`, because a value that means an amount is a delta by type.

The library itself needed a helper to name the return type of 20 functions. An A/B build of two
static test files showed no change in compile time beyond the run-to-run spread.

### Open questions {#absolute-impl-open}

**The name of `absolute_point_origin`.** The word "absolute" names an abstraction of quantities, and
it also names the origin that starts an independent affine space, `absolute_point_origin`, while
`si::absolute_zero` is a natural origin. The reference implementation renames the origin and keeps
the old name, deprecated. The candidates are:

- `absolute_point_origin`, the name used in [@P3045R11_PRE]: it collides with the absolute
  abstraction.
- `independent_point_origin`, the name the reference implementation uses: such an origin starts an
  affine space of its own.
- `frame_point_origin`: such an origin defines a frame of reference.

`root_point_origin` and `base_point_origin` aren't candidates, because "root" names the root of a
quantity kind and "base" names base quantities and units. This paper proposes
`independent_point_origin`.


# Proposed polls {#polls}

## SG6

1. _SG6 supports adding absolute quantities to [@P3045R11_PRE] as proposed in P4185R3: a third
   abstraction of the `quantity` class template next to deltas and points, the default meaning of
   `quantity<R>`, with a delta spelled `quantity<delta<R>>`._
2. _If poll 1 passes, `absolute_point_origin` should be renamed to `independent_point_origin`._
3. _If poll 1 passes and [@P4411R1_PRE] is adopted, the design of the multiply syntax of
   [@P3045R11_PRE] should be revisited, with the interaction described in
   [For discussion](#absolute-negative-bare-unit) added to the issues [@P3045R10_PRE] already
   records, before it is final._

# Acknowledgments

Special thanks and recognition goes to [The C++ Alliance](https://cppalliance.org) for supporting
Mateusz's membership in the ISO C++ Committee and the production of this proposal.

The author also thanks Oliver Rosten for independently developing the convex-space model
[@ROSTEN2025] that contributed the four-space taxonomy and several key design insights used
throughout this paper; Tiago Freire for the ideal gas law demonstration that motivated
the temperature trap analysis and for detailed ANSI review; Chip Hogg for suggesting the
nature-based constant idiom; Yongwei Wu for raising the algebraic identity objection against
absolute subtraction; and Amir Kirsh for review feedback.

---
references:

- id: P3045R10_PRE
  citation-label: P3045R10
  author:
    - family: Pusz
      given: Mateusz
  title: "Quantities and units library"
  URL: <https://wg21.link/p3045r10>
- id: P4487R0
  citation-label: P4487R0
  author:
    - family: Pusz
      given: Mateusz
  title: "Vector, Tensor, and Complex Operations for Quantities"
  URL: <https://wg21.link/p4487r0>
- id: P3045R11_PRE
  citation-label: P3045R11
  author:
    - family: Pusz
      given: Mateusz
  title: "Quantities and units library"
  URL: <https://wg21.link/p3045r11>
- id: MP-UNITS
  citation-label: mp-units
  title: "mp-units - A Physical Quantities and Units library for C++"
  URL: <https://mpusz.github.io/mp-units>
- id: ROSTEN2025
  citation-label: Rosten2025
  author: "Oliver J. Rosten"
  title: "Thoughts on Quantities & Units — Putting P3045 on a firm foundation."
  URL: <https://docs.google.com/presentation/d/1qjw0SURoJtX_DhaFUr62F-BXtQJjdQRqzMUHvQ6h3-E/edit?usp=sharing>
- id: SEQUOIA
  citation-label: Sequoia
  author: "Oliver J. Rosten"
  title: "Sequoia — a C++ library exploring mathematical foundations for quantities"
  URL: <https://github.com/ojrosten/sequoia>
- id: P4412R0_PRE
  citation-label: P4412R0
  author:
    - family: Pusz
      given: Mateusz
  title: "Range-Validated Quantity Points"
  URL: <https://wg21.link/p4412r0>
- id: P4411R0_PRE
  citation-label: P4411R0
  author:
    - family: Pusz
      given: Mateusz
  title: "Non-Negative Quantity Specifications"
  URL: <https://wg21.link/p4411r0>
- id: P4411R1_PRE
  citation-label: P4411R1
  author:
    - family: Pusz
      given: Mateusz
  title: "Non-Negative Quantity Specifications"
  URL: <https://wg21.link/p4411r1>
- id: P4409R0_PRE
  citation-label: P4409R0
  author:
    - family: Pusz
      given: Mateusz
  title: "Integer Division in a Quantities Library"
  URL: <https://wg21.link/p4409r0>
- id: P4406R0_PRE
  citation-label: P4406R0
  author:
    - family: Pusz
      given: Mateusz
  title: "Comparing Quantities Against Zero"
  URL: <https://wg21.link/p4406r0>

---
