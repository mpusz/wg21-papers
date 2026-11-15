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

## Changes since [@P4185R1]

R2 proposes absolute quantities, and the title changes from "Completing the Mathematical Model
for C++ Quantities and Units" to "Absolute Quantities". At Brno 2026, SG6
encouraged further work on Section 6 "Absolute quantities" of [@P4185R1], and the other chapters
moved to papers of their own so that each can be decided separately. The only dependency of this
paper is [@P3045R10_PRE].

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
  value is spelled `delta<m>(-5.)`. A vector value written with a bare unit is ill-formed instead
  of a delta. `si::absolute_zero` is the natural origin of thermodynamic temperature, and an offset
  unit is a unit whose origin isn't a natural origin, so the kelvin isn't one (see
  [Temperature revisited](#absolute-temperature)).
- [Concepts](#absolute-concepts) added. `quantity_of` tells what a quantity can be used as, and
  the abstraction concepts tell what it is.
- [Averages and centers of mass](#averaging) added, to answer a question SG6 asked at Brno 2026.
- The paper is written against [@P3045R10_PRE] instead of [@P3045R7]. A point is spelled
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

[@P3045R10_PRE] models quantities with two abstractions, a delta and a point, both spelled with
the `quantity` class template: `quantity<R>` is a delta and `quantity<point<R, PO>>` a point.
Neither fits the most common value in a physics equation, an amount measured from a true zero,
such as a mass of 5 kg or a thermodynamic temperature of 300 K. A delta has no zero anchor, and
two points can't be added, and a point can't be multiplied or divided.

This paper proposes a third abstraction, the **absolute quantity**, anchored at a true zero, and
makes it the default meaning of `quantity<R>`. That is a breaking change to [@P3045R10_PRE], so
SG6 is asked for a direction before the initial API is fixed. Final wording follows
implementation.


# Introduction

[@P3045R10_PRE] spells a delta `quantity<R>` and a point on a measurement scale, measured from an
explicit or implicit origin, `quantity<point<R, PO>>`. The two abstractions come from the affine
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
implemented, with a different API, in his Sequoia library [@SEQUOIA]. No mainstream units library
in any programming language, including F# Units of Measure, Haskell's _dimensional_ package, or
Python's Pint, distinguishes absolute quantities, deltas, and points as three separate types.

Absolute quantities are implemented on a prototype branch off the version 3 line of [@MP-UNITS]
(see [Implementation experience](#absolute-implementation-experience)).

# Motivation and scope {#motivation}

A `quantity<isq::mass[kg]>` in [@P3045R10_PRE] is a delta: it can be negated freely, and its type
carries no notion of a physically meaningful zero. This section shows two use cases where that
forces users into awkward workarounds.

## The temperature trap {#temp-trap}

By far the most frequently reported usability issue with the current [@P3045R10_PRE] design involves
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

This code does not compile under [@P3045R10_PRE]. The multiply syntax (`28 * deg_C`) was
initially allowed in earlier revisions but was disabled after feedback from Tiago Freire,
who demonstrated the danger with a concrete ideal gas law example. The fix was to disable
the multiply syntax for all temperature units, preventing any of them from being used
in a `value * unit` expression. The implementation mechanism for this is that every
temperature unit using a point origin in its definition is caught by the restriction;
Kelvin was therefore defined with `absolute_zero` as its point origin specifically to bring
it under the same rule, ensuring that `28 * K` does not compile under [@P3045R10_PRE] either.

The inclusion of Kelvin is necessary for a consistent and safe rule. The multiply syntax
produces a delta, so `28 * K` would not itself construct a point.
For Kelvin this causes no direct harm, but the situation changes entirely if the unit in
such an expression were later changed to an offset unit (e.g., `deg_C`). The result would
become a meaningless delta rather than a compile error. A uniform rule (no
multiply syntax for any temperature unit) is the only way to make the restriction
predictable and refactoring-safe.

Nevertheless, this is fundamentally an ad-hoc patch applied on top of the
delta/point model rather than a principled solution from measurement theory. It is
the right fix for the model as it stands, but it reveals a deeper inadequacy: the model has
no way to express "an absolute thermodynamic temperature of 28 K" directly. The constraint
is well-motivated to someone who understands the affine space chain, but may appear
over-constraining to others.

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

While the affine space model _can_ handle this case, the ergonomics are poor:
`point<deg_C>(28.).in(K).delta_from_zero()` is a far cry from what a domain expert
would consider natural. The need to go through a point, convert units, and then extract
the delta from zero is a significant usability burden that discourages correct usage.

An alternative approach, suggested by Chip Hogg as a "nature-based constant" idiom, is to
subtract `absolute_zero` directly from the point, obtaining the delta from the
physical zero:

```cpp
auto temp = point<deg_C>(28.);
auto T = temp - absolute_zero;                    // 301.15 K — delta from absolute zero
auto R_calc = P * V / (n * T);
```

This works even when the point is expressed in `deg_C`: the subtraction of the absolute
zero origin yields a delta whose value is the absolute thermodynamic temperature, and
the result can always be scaled to whatever unit is needed. However, this idiom still
requires users to know that `absolute_zero` exists, understand why it must be subtracted,
and remember to apply it every time an absolute temperature is needed. This is a teaching burden
that grows with every new domain that has an analogous pattern.

This problem is not limited to temperature. It affects any domain where absolute quantities
(as opposed to differences) are the natural operands in physical equations. The
[hardware voltage example](https://mpusz.github.io/mp-units/latest/examples/hw_voltage/) in
the [@MP-UNITS] documentation illustrates the same pattern in embedded systems: an ADC
maps a physical voltage range to integer counts, and the measured voltage is an absolute
scalar quantity, not a difference. Users have independently requested the same ergonomic
improvements for such cases (see [mp-units discussion #606](https://github.com/mpusz/mp-units/discussions/606)).
The solution, described in [Temperature revisited](#absolute-temperature), makes `absolute_zero`
the natural origin of thermodynamic temperature, so that the kelvin isn't an offset unit and
`28 * K` creates an absolute thermodynamic temperature directly, without any conversion idiom.

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

One might attempt to address this by defining specialized quantities within the `isq::mass`
hierarchy, for example, `total_mass` and `mass_loss` as children of `isq::mass`. The
library's quantity hierarchy does support this: specialized child quantities of the same kind
can be subtracted and compared, but conversion from a parent quantity to a child
requires an explicit cast. This would indeed prevent accidental swapping of the two arguments,
since `total_mass` and `mass_loss` would be distinct types. However, it also means that the
legitimate computation `total_initial - total_dried` yields a `total_mass` result, not a
`mass_loss`, and passing it to `mass_loss` would require an explicit conversion.
The workaround thus introduces friction for every correct call site, not just the incorrect
ones.

However, the distinction here is not between different _specializations_ of mass. Both
`water_lost` and `total` may even be measured with the same instrument, but the
_measurement setup_ is fundamentally different: `total` is a direct ratio-scale reading
anchored at true zero (put the wet material on the scale and read the mass), while
`water_lost` is derived as the difference between two such readings. The difference is in
their _role_: one is a signed difference (delta) and the other is an absolute amount measured
from true zero.
Encoding every such role as a separate quantity in the hierarchy would cause the quantity tree to
proliferate with domain-specific entries that have no basis in measurement science
(ISO 80000 does not distinguish "total mass" from "mass loss": both are simply _mass_).
Every domain would need its own set of role-based quantity specializations, and the hierarchy
would grow without bound.

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
An absolute and a delta share the same mathematical structure: both are vector spaces with a
distinguished zero element. The type distinction encodes the physical interpretation. An
absolute is a ratio-scale measurement anchored at true physical zero, and a delta is a
change with no physical zero anchor. Where the values of a quantity can't be negative, its
absolutes form a convex cone `[0, +∞)`, which is closed under addition but not under negation,
and is therefore not a vector space.
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
offset by 273.15 K from `si::absolute_zero`, the natural origin of thermodynamic temperature (see
[Temperature revisited](#absolute-temperature)), so the lower bound of 0 K
corresponds to −273.15 °C on the Celsius scale. This paper models such scales with points.

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
`quantity` default to absolute is a **breaking change** relative to [@P3045R10_PRE], where
`quantity` is a delta.

A bare unit means an amount. `20 * kg` is an absolute of the quantity kind `kind_of<isq::mass>`,
and it is an absolute whatever its sign. A signed value of a kind, such as a change, is spelled
as a delta: `delta<m>(-5.)` is a displacement of 5 m in the negative direction, and `delta<K>(-5.)`
is a temperature change. A position on a scale is spelled as a point and picks an origin. If
[@P4411R0_PRE] is adopted, a quantity kind takes the domain of its root, so `-5. * m`, `-1 * kg`,
and `-5. * K` are contract violations, while `-5. * A` isn't, since an electric current can be
negative (see [Sign of an absolute quantity](#absolute-sign)).

## Absolute quantities are not points {#abs-vs-point}

Is the absolute abstraction really necessary, or could we simply give points the ability to be
added and multiplied?

We cannot, and the reason lies in the distinction between **interval scales** and
**ratio scales** in measurement theory.

An affine point lives on an _interval scale_:

- `point ± delta → point` (translation along the scale)
- `point − point → delta` (difference between two locations)
- `point + point` is _ill-formed_ (adding two locations has no geometric meaning)
- `point × point` is _ill-formed_ (no ratio-scale operations)
- `point / point` is _ill-formed_ (no meaningful ratio between two locations)

Timestamps, calendar dates, and geographic positions are interval-scale: it makes no sense
to add Tuesday to Friday, or to ask what fraction Berlin is of Paris.

An absolute quantity lives on a _ratio scale_:

- All point operations remain well-defined.
- `abs + abs → abs` (combining two masses produces a heavier mass).
- `abs × abs → abs` (`power × duration = energy` is a meaningful product of two absolutes).
- `abs / abs → abs` (`mass / volume = density`, `T_cold / T_hot` in Carnot efficiency). Ratios
  between absolute quantities are physically meaningful because they share a common true zero.

So an absolute quantity is not "a point with arithmetic added on top". The defining
property of a ratio scale, and the entire reason the third abstraction exists, is that
two values are not merely _located_ on the scale, but related to a _shared, physically
meaningful origin_. That shared origin is what makes their sum, product, and ratio
physically meaningful. A point on an arbitrary origin (the floor of a building, the GPS
epoch, the freezing point of water) carries no such meaning.

## Scalar and vector quantities {#absolute-scalar-vector}

Absolute quantities are always **scalar**: they are ratio-scale magnitudes anchored at a
physically meaningful true zero, and the concept of direction, which would require an
orientation relative to a reference frame and not just a reference zero, has no place in the
model. Vector quantities live in a vector space. They have a mathematical zero (the zero vector,
representing no displacement), but not a ratio-scale physical anchor. They represent
displacements from a reference and therefore always fall in the **delta** abstraction. Points
carry a concrete origin and may be scalar or vector depending on the space they inhabit.

| Abstraction  | Scalar                             | Vector                                            |
|:-------------|:-----------------------------------|:--------------------------------------------------|
| **Point**    | `point<time>`, `point<altitude>`   | `point<position_vector>`, `point<velocity>`       |
| **Delta**    | `delta<duration>`, `delta<height>` | `displacement`, `velocity` (always deltas)        |
| **Absolute** | `duration`, `height`, `mass`       | _(none, `magnitude()` gives a scalar absolute)_   |

To obtain a scalar absolute from a vector quantity, take its magnitude:
`magnitude(velocity)` → `speed`.

The quantity specification decides first. A specification of vector or tensor character, such as
`isq::velocity`, has no absolute, so its plain reference is already a delta reference, and
`delta<isq::velocity[m / s]>` names that same reference, as `point<deg_C, si::ice_point>` names
`point<deg_C>`. A vector quantity needs no `delta` either as a value or as a type:
`isq::velocity(5. * m / s)` is a `quantity<isq::velocity[m / s], double>`, a velocity along one
axis, and `vec * isq::velocity[m / s]` is a `quantity<isq::velocity[m / s], vec3>`, and both are
deltas. A bare unit such as `m` or `m / s` names a quantity kind, and its plain reference is an
absolute reference whatever the representation, so a vector value can't be stored under it:
`vec * (m / s)` and `quantity{vec, m / s}` are ill-formed. A result computed from a vector is a
delta: `(2. * m) * vec` scales an absolute by a vector number, and a vector is never an absolute. A
vector of a kind is spelled `delta<m / s>(vec)`,
or the quantity is named, as in `vec * isq::velocity[m / s]`. The storage type doesn't change the
abstraction of a quantity, as it already doesn't for a named specification. A point
reference stays a point (`point<isq::position_vector[m]>(vec)` is a point), and a vector point
needs a specification of vector character, so `point<m>(vec)` is ill-formed, as `vec * m` is.
The scalar field, real or complex, plays no role: a complex scalar (an impedance, a complex power)
has a true zero and is an absolute, and `modulus()` of it is specified as a real absolute (not yet
in the prototype). A vector delta has no `.absolute()`, and its `magnitude()` is an absolute
scalar. A component vector of a vector delta is a delta along an axis, even though its
representation is a scalar.

## Conversions between abstractions {#absolute-conversions}

|     From\\To |                           Point                           |                                                           Absolute                                                            |                         Delta                         |
|-------------:|:---------------------------------------------------------:|:-----------------------------------------------------------------------------------------------------------------------------:|:-----------------------------------------------------:|
|    **Point** | Identity;<br>`point_for(origin)` to change representation | `.absolute()` (if not offset unit and the origin is `natural_point_origin`);<br>otherwise `(point - origin_or_qp).absolute()` | `point - origin_or_qp`;<br>`delta_from(origin_or_qp)` |
| **Absolute** |       Explicit ctor<br>using `natural_point_origin`       |                                                           Identity                                                            |          Implicit construction;<br>.delta()           |
|    **Delta** |                  origin + delta → point                   |                                   `.absolute()`;<br>`abs()`, `magnitude()`, or `modulus()`                                    |                       Identity                        |

::: note
The `absolute → delta` implicit conversion is a deliberate design choice. It makes
common assignment and initialization convenient (`quantity<delta<m>> x = 40 * m;` works
without any explicit cast) and mirrors how absolute magnitudes are routinely used as
signed differences in practice (e.g. passing a mass to a function that takes a mass change).
The consequence is that code can pass an absolute where a delta is expected without
any explicit marker at the call site, which is one of the sources of the residual
argument-swapping risk shown in [Mass balance revisited](#mass-balance-revisited). SG6 may
wish to consider whether this conversion should require an explicit `.delta()` call or
explicit construction (analogous to the explicit constructor used in the point case).
:::

The following examples demonstrate the explicit and implicit casts between all three abstractions:

```cpp
// ── From Absolute ──────────────────────────────────────────────────────────────────────
quantity<isq::mass[kg]> total = 5 * kg;

// Absolute → Delta: implicit (no notation at call site) or explicit .delta()
quantity<delta<isq::mass[kg]>> d1 = total;         // implicit
quantity<delta<isq::mass[kg]>> d2 = total.delta(); // explicit

// Absolute → Point: explicit construction only (attaches natural_point_origin)
quantity<point<isq::mass[kg]>> p{total};           // explicit ctor

// ── From Delta ─────────────────────────────────────────────────────────────────────────
quantity<delta<isq::mass[kg]>> change = 3 * kg;

// Delta → Absolute: explicit .absolute(), or the magnitude
quantity<isq::mass[kg]> amount = change.absolute();
quantity<isq::mass[kg]> size   = abs(change);      // |change|

// Delta → Point: origin + delta
quantity<point<isq::length[m]>> pos = natural_point_origin<isq::length> + delta<isq::length[m]>(3);

// ── From Point ─────────────────────────────────────────────────────────────────────────
quantity<point<isq::thermodynamic_temperature[K]>> boiling{373.15 * K};

// Point → Delta: subtract a reference origin or another point
quantity<delta<isq::thermodynamic_temperature[K]>> above_zero =
    boiling.delta_from(natural_point_origin<isq::thermodynamic_temperature>);

// Point → Absolute: only valid when the point's origin is natural_point_origin
quantity<isq::thermodynamic_temperature[K]> t_abs = boiling.absolute();
```

An absolute may be negative in this paper, so `.absolute()` doesn't check the value, and a sign
check for non-negative quantities is left to [@P4411R0_PRE]. The conversion is still explicit. A delta
is a change, and an absolute is an amount measured from the true zero of its scale. Using one as
the other is the mistake of [The temperature trap]: a temperature change of 28 K passed where a
temperature of 28 K is needed. An implicit conversion would let that mistake compile, so
`.absolute()` marks the place where a change is used as an amount. The opposite direction is
implicit, because an amount is also its own change from zero.

## Concepts {#absolute-concepts}

Four concepts tell what a quantity is. `absolute_quantity`, `delta_quantity`, and `point_quantity`
each match one abstraction, and `linear_quantity` matches an absolute or a delta. An absolute and a
delta share every operation that doesn't look at the anchor (scaling, powers, conversions, text
output), and generic code that only needs "not a point" uses `linear_quantity`. These concepts are
what overloads and the rules of the model dispatch on.

`quantity_of<Q, V>` tells what a quantity can be used as. It accepts what a parameter of the
corresponding concrete type accepts, so it follows the conversions between abstractions:

| `V`         | `quantity_of<Q, V>` matches  | as a parameter of type   |
|-------------|------------------------------|--------------------------|
| `QS`        | absolutes of `QS`            | `quantity<QS[U]>`        |
| `delta<QS>` | deltas and absolutes of `QS` | `quantity<delta<QS[U]>>` |
| `point<QS>` | points of `QS`               | `quantity<point<QS[U]>>` |

A function that needs an amount, such as $E = kT$ with a thermodynamic temperature, constrains its
parameter with `quantity_of<Q, isq::thermodynamic_temperature>`, and a temperature difference is
rejected, as it is by a concrete `quantity<isq::thermodynamic_temperature[K]>` parameter. A function
that needs a change, such as an average speed from a distance traveled and an elapsed time, uses
`quantity_of<Q, delta<isq::length>>`, and an absolute is accepted, as it would convert to a
concrete delta parameter. A vector quantity is always a delta, so `quantity_of<Q, isq::velocity>`
keeps matching it.

`delta_quantity<Q>` asks whether `Q` is a delta, and `quantity_of<Q, delta<QS>>` whether it can be
used as one. A template that wants a change and should accept an absolute uses the latter, or
`linear_quantity` when the specification doesn't matter.

`quantity_of<Q, delta<QS>>` is defined as the absolute match of `QS` or the delta match of `QS`, so
an overload constrained with `quantity_of<Q, QS>` is more specialized than one constrained with
`quantity_of<Q, delta<QS>>`, and an absolute argument selects it.

## Arithmetic semantics {#absolute-arithmetic}

The abstraction rules of addition, subtraction, and scaling by a number follow one principle, the
**zero-anchor principle**. An operation preserves the absolute abstraction whenever the result
remains anchored at the same physically meaningful true zero as the operands. The full rationale,
including why `Absolute ± Delta → Absolute` was chosen and how it resolves the consistency concern
between `Absolute ± Delta` and `Absolute × Scalar`, is given in [Design rationale: the zero-anchor
principle](#abs-delta-rationale). Products and quotients of two absolutes are absolutes, because
absolutes live on a ratio scale (see [The zero-anchor principle](#zero-anchor)). The rule for
products and quotients with a delta operand is described in
[Products and quotients of two deltas].

The following tables specify the result types of arithmetic operations between the three
abstractions.

### Addition

|   Lhs \\ Rhs | Point | Absolute |  Delta   |
|-------------:|:-----:|:--------:|:--------:|
|    **Point** |   ✗   |  Point   |  Point   |
| **Absolute** | Point | Absolute | Absolute |
|    **Delta** | Point | Absolute |  Delta   |

Key rules:

- Adding two absolute quantities yields an absolute. Both are anchored at true zero,
  so their sum is also anchored at true zero (e.g., combining two masses gives a total mass).
- Adding a delta to an absolute yields an absolute. Shifting a zero-anchored quantity
  by a signed change preserves the zero-anchor.
- Adding a delta to a delta yields a delta (combining two changes gives a change).
- Adding anything to a point yields a point (translation along the scale).

```cpp
quantity tank   = isq::mass(500 * kg);        // quantity<isq::mass[kg]>
quantity refuel = delta<isq::mass[kg]>(200);  // quantity<delta<isq::mass[kg]>>: +200 kg (signed change)
quantity loaded = tank + refuel;              // quantity<isq::mass[kg]>: 700 kg
tank += refuel;                               // same: tank is now 700 kg

// To get a signed result instead, explicitly demote before the operation:
quantity balance = tank.delta() + refuel;     // quantity<delta<isq::mass[kg]>>
```

### Subtraction

|   Lhs \\ Rhs | Point | Absolute |  Delta   |
|-------------:|:-----:|:--------:|:--------:|
|    **Point** | Delta |  Point   |  Point   |
| **Absolute** |   ✗   |  Delta   | Absolute |
|    **Delta** |   ✗   |  Delta   |  Delta   |

Key rules:

- Subtracting two absolute quantities yields a delta. The difference between two
  zero-anchored values is a signed change, not a zero-anchored magnitude.
  This is the same rule as `point − point → delta` in affine spaces.
- Subtracting a delta from an absolute yields an absolute. Removing a signed change
  from a zero-anchored value preserves the zero-anchor.
- Subtracting an absolute from a delta yields a delta. The delta has no zero-anchor
  to preserve, so the result inherits the delta character regardless of the subtrahend.
- Subtracting an absolute from a point yields a point (translation by the negated absolute).

```cpp
quantity before = isq::mass(100 * kg);  // quantity<isq::mass[kg]>
quantity after  = isq::mass(80 * kg);   // quantity<isq::mass[kg]>
quantity lost   = before - after;       // quantity<delta<isq::mass[kg]>>: +20 kg (a change)

quantity usage     = delta<isq::mass[kg]>(20); // quantity<delta<isq::mass[kg]>>: a signed change
quantity remaining = before - usage;           // quantity<isq::mass[kg]>: 80 kg
before -= usage;                               // same: before is now 80 kg

// To get a signed balance, demote first:
quantity deficit = before.delta() - usage;     // quantity<delta<isq::mass[kg]>>
```

If an absolute result is needed from an `absolute − absolute` subtraction (e.g., when you
know the difference is non-negative), use an explicit conversion:

```cpp
quantity transferred = (before - after).absolute();  // quantity<isq::mass[kg]>
```

### Multiplication and division

| Operation                 | Result   | Physical Meaning                                                                     |
|:--------------------------|:---------|:-------------------------------------------------------------------------------------|
| Absolute × Absolute       | Absolute | A product of two absolute quantities (energy = power × time)                         |
| Absolute × Scalar         | Absolute | Rescaling by a dimensionless factor (2 × mass stays absolute mass)                   |
| Absolute × Delta          | Delta    | Absolute scaled by a change is a change (e.g., area × Δheight → Δvolume)             |
| Delta × Absolute          | Delta    | (same as Absolute × Delta; multiplication is commutative)                            |
| Delta × Scalar            | Delta    | Rescaling a signed difference (factor preserves delta abstraction)                   |
| Absolute / Absolute       | Absolute | A physical ratio (efficiency, density)                                               |
| Absolute / Delta          | Delta    | Rate of an absolute w.r.t. a signed step                                             |
| Delta / Absolute          | Delta    | A change scaled by a fixed absolute reference                                        |
| Delta × Delta             | Delta    | A product of two changes (see [Products and quotients of two deltas])                |
| Delta / Delta             | Delta    | A rate of change (velocity = displacement / duration)                                |
| `abs(delta_real_scalar)`  | Absolute | Magnitude of a scalar delta                                                          |
| `pow<N>(delta_scalar)`    | Absolute | An even integral `N`: a power of one value can't be negative                         |
| `modulus(complex_scalar)` | Absolute | Modulus of a complex number                                                          |
| `magnitude(delta_vector)` | Absolute | Magnitude of a vector delta (speed = magnitude(velocity))                            |
| `a % b`, `fmod(a, b)`     | Dividend | The abstraction of the dividend, whose sign the remainder has                        |
| `remainder(a, b)`         | Delta    | The remainder can be negative for any operands                                       |
| `hypot(x, y)`             | Absolute | Magnitude of a vector given by its components, as for `abs`                          |

"Scalar" in this table means a raw C++ numeric type (`double`, `int`, etc.) treated as a
multiplicative factor without an absolute/delta annotation. The table treats it as neutral:
`Absolute × Scalar → Absolute`, whatever the sign of the scalar.

#### Products and quotients of two deltas

A single delta in a product is a delta by linearity: for a fixed absolute `k`, `k * Δy` is the
change of `k * y`, so an impulse and the work of a force are changes. A product or a quotient of two
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
[@MP-UNITS], it costs three `.absolute()` calls, each after a quotient of two deltas: a glide
distance computed from two altitude differences, and the durations of an aircraft tow and of a
climb in a thermal, each a height change divided by a rate of climb.

A power sees one value. For a real value, `pow<N>(Δx)` with an even integral `N` can't be negative,
so it is an absolute, as `abs(Δx)` and `hypot(Δx, Δy)` are. This keeps
`sqrt(pow<2>(Δx) + pow<2>(Δy))` and `hypot(Δx, Δy)` the same type. `Δx * Δx` stays a delta,
because a product doesn't record that both operands are one value. Odd powers stay deltas, and so
does a power of a vector.

In the Kalman filter examples of [@MP-UNITS], the rule makes a variance, the square of a standard
deviation, an absolute, so the Kalman gain, a ratio of two variances, needs no `.absolute()`. Before
the rule it needed one, as a quotient of two deltas. The call moves to the covariance update
$(1 - K) P$: `1 - K` is the difference of two absolutes, and so a delta, while the gain is never
above one, and `.absolute()` checks that the updated variance isn't negative.

### Sign of an absolute quantity {#absolute-sign}

An absolute quantity is anchored at a true zero, and nothing in this paper constrains its sign.
An electric current is positive or negative relative to the reference direction chosen for it, and
under the load sign convention a reactive power is positive for an inductive load and negative for
a capacitive one, while both have a physically meaningful zero. If [@P4411R0_PRE] is adopted,
absolute quantities are where its `non_negative` tag is checked on values, and
[@P4411R0_PRE] describes where the checks run and why they can't be elided further.

With [@P4411R0_PRE], the abstraction decides which values its check applies to. A delta is never
checked, as a change can have either sign. An absolute is checked when its quantity specification
is non-negative. A quantity kind `kind_of<QS>` is defined only for a root `QS` and takes the domain
of that root, so `kind_of<isq::length>`, `kind_of<isq::mass>`, and
`kind_of<isq::thermodynamic_temperature>` are non-negative, while `kind_of<isq::electric_current>`
isn't. A value written with a bare unit is an absolute of a kind, so `-5. * m` and `-5. * K` are
contract violations, and a signed value is spelled `delta<m>(-5.)` or `delta<K>(-5.)`. An unnamed
specification, such as `isq::mass / isq::volume`, is never non-negative. A point is checked when
its own specification is non-negative and the chain of its origins ends at a natural origin, so
`point<deg_C>(-300.)` is a violation through `ice_point`, and a point measured from an
`independent_point_origin`, such as an epoch or a tare, never is. A `possibly_negative`
specification under a non-negative parent, such as _effective mass_ under _mass_, keeps the units
and the natural origin of its parent and is never checked.

### For discussion: a negative value written with a bare unit {#absolute-negative-bare-unit}

This consequence of the model is the one users will hit first, and SG6 is asked to discuss it
explicitly. With absolute quantities and [@P4411R0_PRE] adopted, a value written with a bare unit
is a checked absolute of its kind. Code that writes `-5. * K` to mean "5 K colder" is a contract
violation, and the change has to be spelled as a delta:

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
wrong. In a constant expression evaluated under a checking contract semantic, such as
`constexpr quantity t = -5. * K;`, the violation fails to compile. At run time it is a contract
violation only when the check runs, and under a semantic that doesn't check, the negative absolute
is stored silently. The prototype implements this check: with gsl-lite as its contract backend,
`constexpr quantity t = -5. * K;` doesn't compile, and `-5. * K`, `-1 * kg`, and `-1. * s`
evaluated at run time terminate. Values of a kind that admits negative values, such as `-5. * A`,
are unaffected.

The order of evaluation makes the rule reach further than these three lines suggest.
[@P3045R10_PRE] extended the multiply syntax from `number * unit` to `quantity * unit` and
`quantity / unit` (see its chapter "Multiply syntax commutativity"), so `1 * m / s` is two
operations, and its intermediate result `1 * m` is a quantity of its own. With checked absolutes,
that intermediate can fail where the whole expression wouldn't, and the same happens before a
conversion to a signed quantity:

```cpp
quantity v1 = -1. * m / s;               // ✗ contract violation: (-1. * m) is a negative length
quantity v2 = -1. * (m / s);             // unchecked, as an expression's kind is never non-negative,
                                         //   but still a negative absolute
quantity v3 = delta<m / s>(-1.);         // ✓ a signed velocity component is a change

quantity a1 = isq::altitude(-5. * m);    // ✗ contract violation: -5. * m is a negative length
quantity a2 = isq::altitude[m](-5.);     // ✓ altitude is signed
quantity a3 = -5. * isq::altitude[m];    // ✓
```

Under the model, `v1` and `v2` are both wrong spellings of a signed value, and `v2` passes only
because an expression carries no sign. The parentheses decide whether the mistake is caught. SG6
is asked to choose between:

- keeping the multiply syntax of [@P3045R10_PRE], and teaching `delta<m / s>(-1.)` as the spelling
  of a signed value: `v1` is then a violation that points at that spelling;
- restricting the multiply syntax to `number * unit`, so that `quantity * unit` and
  `quantity / unit` are ill-formed: `v1` becomes a compile-time error instead of a run-time one, at
  the cost of writing every `42 * m / s` as `42 * (m / s)` in existing code, which the extension
  of [@P3045R10_PRE] was added to avoid;
- not checking a value written with a bare unit at all, which also leaves `-5. * K` unchecked.

The author proposes the first option.

### Unary negation {#absolute-negation}

The negation of an amount is the change that cancels it, so `-mass` is never a mass, while the
negation of an electric current is a current flowing the other way. Which of the two applies
depends on whether the quantity can be negative, which is what the `non_negative` tag of
[@P4411R0_PRE] states. The rule for `-x` therefore depends on whether that paper is adopted.

**If [@P4411R0_PRE] is adopted,** `-x` keeps the absolute abstraction when the quantity
specification of `x`, named or a quantity kind, admits negative values. It yields a delta for a
`non_negative` specification, a kind whose root is `non_negative`, and an unnamed derived
specification, whose sign the library doesn't infer from a quantity equation. A kind takes the
domain of its root, so `-(5. * A)` keeps the absolute abstraction and `-(2. * kg)` doesn't:

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

**Without [@P4411R0_PRE],** no specification has the tag, and the rule above would keep the absolute
abstraction for every named specification and kind, `-mass` included, so `-x` is a delta for every
absolute instead. The result type follows from the abstraction of the operand alone, and the cost
falls on quantities whose absolutes can be negative, such as electric current, electric charge, or reactive
power: in `I3 = -(I1 + I2)` the right-hand side is a delta, and storing it in a current needs
`.absolute()`.

The prototype implements the rule for an adopted [@P4411R0_PRE], with its `non_negative` tags. It
first made `-x` a delta for every absolute. Switching changed no test result and no example output,
and static tests were added for negations that give an absolute and for negations that give a delta.

Under either rule, `-1 * x` scales an absolute by a number and stays an absolute, so it can differ
in type from `-x`. If [@P4411R0_PRE] is adopted, its sign check rejects `-1 * isq::mass[kg]` and
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

This is the rule used for points in affine spaces: `point ± delta → point`. Both rules express "a
translation preserves the abstraction relative to its origin". For points the origin is the affine
origin; for absolutes it is the natural true zero. Unlike points, however, absolutes live on a ratio
scale and support multiplication, division, and addition between two absolutes, operations that
are ill-formed for points. The abstraction of the operands (absolute vs. delta) is what drives the
result type, not the affine origin.

#### Rejected alternative: universal demotion to delta

The initial design demoted _all_ `absolute ± delta` to delta, reasoning that since a delta
can be negative, the result "might" be negative and the type should conservatively reflect
that. This was rejected for three reasons:

1. Type demotion is the wrong mechanism for value-range violations. The result of
   `abs ± delta` may be negative at runtime, but so may `abs × scalar`: a negative scalar
   drives the result below zero, yet `Absolute × Scalar → Absolute` was never in doubt.
   Whether a value is in range is a property of the value, and a check on the value answers
   it, such as the one [@P4411R0_PRE] proposes. A type demotion doesn't.

2. It conflates abstraction with value constraint. Possibly-negative absolutes like
   `reactive_power` belong on a ratio scale regardless of their sign. Under universal
   demotion, `reactive_power + delta<reactive_power>` would yield `delta<reactive_power>`,
   changing the abstraction and making it impossible to store the result back into a
   `reactive_power` variable without an explicit conversion.

3. It penalizes strongly-typed operands over untyped scalars. A raw C++ scalar can be
   negative at runtime, yet `Absolute × Scalar → Absolute` was never questioned. A `delta`
   is a stricter, more informative type than a raw scalar, yet the rejected rule would
   demote the result further than the weakly-typed case, with no principled justification.

### Consistency with `Absolute × Scalar → Absolute` {#abs-scalar-consistency}

Reason 3 above points to a structural requirement: the rules for `Absolute × Scalar` and
`Absolute ± Delta` must be consistent because both operations are "neutral on the
zero-anchor": neither one moves the origin.
Under the zero-anchor principle both preserve the absolute abstraction:

```cpp
// Both rules are consistent under the zero-anchor principle:
quantity m1 = isq::mass(5 * kg);           // absolute
quantity<isq::mass[kg]> m2 = 2.0 * m1;     // absolute × scalar → absolute: 10 kg
quantity d = delta<isq::mass[kg]>(3);      // delta
quantity<isq::mass[kg]> m3 = m1 + d;       // absolute ± delta → absolute: 8 kg ✓
// Both multiply-by-scalar and add-delta are "neutral on the zero-anchor" → consistent result type
```

### Handling underflow: when `delta > absolute` {#abs-underflow}

Under the adopted rule, `abs - delta` keeps the absolute type, whatever the value. Consider a fuel
burn where the maneuver needs more fuel than the tank holds, with the burn modeled as a delta:

```cpp
quantity fuel        = isq::mass(500. * kg);        // absolute: fuel present in the tank
quantity consumption = delta<isq::mass[kg]>(600.);  // delta: how much the maneuver burns
fuel -= consumption;                                // absolute: −100 kg
```

This paper accepts the −100 kg absolute. If [@P4411R0_PRE] is adopted, its sign check rejects it, as
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
quantity<delta<isq::mass[kg]>> diff = c - b;           // delta<mass>: 30 kg — correct delta type
quantity<isq::mass[kg]>        a2   = diff.absolute(); // explicit re-entry: 30 kg
```

## Text output {#absolute-text-output}

An absolute quantity prints like any quantity: `42 * kg` prints `42 kg`, the same text as
`delta<kg>(42)`, so absolutes need no formatter of their own. The output of points is discussed
in [@P3045R10_PRE].

## Temperature revisited {#absolute-temperature}

With absolute quantities, the temperature use case from [The temperature trap](#temp-trap) is
resolved. The key change is in what an offset unit is and in how `absolute_zero` is defined.

In [@P3045R10_PRE], `absolute_zero` is an `absolute_point_origin`, and `kelvin` declares it as its
point origin, which triggers the multiply syntax restriction and prevents `28 * K` from compiling.
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

With this definition, `28 * K` now creates an absolute thermodynamic temperature directly, with no
conversion idiom required:

```cpp
quantity T = 28. * K;                    // absolute temperature — compiles in new design
```

The ideal gas law can be written directly with absolute temperatures:

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

The `.in(K).absolute()` chain is a type-safety checkpoint: it forces the programmer to
acknowledge the shift from an interval-scale point (location on the Celsius scale) to a
ratio-scale magnitude (thermodynamic temperature measured from absolute zero). This
replaces the [@P3045R10_PRE] workaround `temp.in(K).delta_from_zero()` with a more
direct name that reflects the mathematical intent.

Offset units (°C, °F) are never absolute, because their origin is not a natural origin. A point
on the Celsius scale is not an absolute temperature, and it must be converted explicitly. A point
in kelvins is measured from `absolute_zero`, a natural origin, so `point<K>(28.).absolute()` is
`28. * K`. `.in(U)` changes only the unit of a point, never its quantity specification, so
`point<isq::thermodynamic_temperature[deg_C]>(20.).in(K)` is still a point of
`isq::thermodynamic_temperature`.

The lower bound of a Celsius point needs no bounds policy on `ice_point`. If [@P4411R0_PRE] is
adopted, a point of a non-negative specification is checked when the chain of its origins ends at
a natural origin, and the chain of `ice_point` ends at `absolute_zero`. So `point<deg_C>(-300.)`
and `point<deg_F>(-460)` are contract violations, while `point<deg_C>(-273)` with an `int`
representation isn't: the floor is checked exactly in the common type of the value and the offset
of `ice_point`, which an `int` in degrees Celsius can't hold.

::: note
The `point` abstraction in this library generalizes beyond pure affine spaces. A pure affine
space is unbounded (no origin, no bounds) and is the right model for, e.g., spatial
position. The Celsius scale is a convex space in the taxonomy of [@ROSTEN2025]: it is
bounded below by the 0 K boundary (see [Overview](#absolute-overview)) but has no
ratio-scale physical anchor of its own. The `point` type covers both: unbounded interval
scales (affine spaces) and bounded scales (convex spaces). What they share is the absence of
a ratio-scale anchor. They are locations relative to a chosen reference, not amounts
measured from true physical zero.
:::

This distinction has a measurement-theory interpretation. Physically, Kelvin quantities live in
an **absolute convex space**: the domain is the half-line $[0, +\infty)$ with a physically
distinguished origin (absolute zero), and addition of two Kelvin values is well-defined because both
are measured from that common anchor. Celsius points, by contrast, are defined as a translation of
the Kelvin scale (via `ice_point`), so their lower bound is a consequence of that translation, not
an independent property of the Celsius origin. Adding two Celsius temperatures is ill-formed for the
same reason as any affine point addition: a Celsius point is a location on the scale, not an amount
measured from true zero. The `.in(K).absolute()` call is the operation that transports a value from
the convex-space (Celsius) domain into the absolute convex (Kelvin) domain by making the true-zero
anchor explicit. The type of a Kelvin absolute doesn't enforce the lower bound. If
[@P4411R0_PRE] is adopted, its sign check on the value does (see [Sign of an absolute quantity](#absolute-sign)).

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
This is not a defect in the split; it is a consequence of a deliberate design decision. If SG6
decides to require an explicit `.delta()` call for that conversion, the subtler mistake would also
become a compile error. Until then, the residual argument-swap risk remains in the domain of naming
conventions and code review.

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
using vec3 = cartesian_vector<double>;  // a vector type of the reference implementation
using position = quantity<point<isq::position_vector[m]>, vec3>;

position r1 = point<isq::position_vector[m]>(vec3{0., 0., 0.});
position r2 = point<isq::position_vector[m]>(vec3{4., 0., 0.});
quantity m1 = 2. * kg;
quantity m2 = 1. * kg;

position center = r1 + (r2 - r1) * (m2 / (m1 + m2));  // [1.333, 0, 0] m
```

The reference implementation provides both algorithms in its utility library as
`mp_units::utility::mean` and `mp_units::utility::weighted_mean`. They accept ranges of
absolutes, deltas, or points, and return the type of the values:

```cpp
celsius_reading avg = utility::mean(readings);  // 22.83 °C, measured from the ice point

std::array<position, 3> positions{point<isq::position_vector[m]>(vec3{0., 0., 0.}),
                                  point<isq::position_vector[m]>(vec3{4., 0., 0.}),
                                  point<isq::position_vector[m]>(vec3{0., 8., 0.})};
std::array masses{2. * kg, 1. * kg, 1. * kg};
position center = utility::weighted_mean(positions, masses);  // [1, 2, 0] m
```

Neither function adds the values up. Every intermediate value is a difference from the first value
or from the running mean, so only the difference between the largest and the smallest value has to
fit in the representation. This also avoids the overflow of the textbook formula for absolutes that
could be summed directly. An integral `mean` accepts every integer type, unsigned ones included,
and keeps the floor of the mean exactly, as a running mean and a remainder. Like `std::midpoint`,
it takes each difference in the unsigned type of the representation, as a distance and a direction,
so nothing wraps. Unlike `std::midpoint`, which rounds toward its first argument, it rounds down,
which doesn't depend on the order of the values. The two functions are not proposed in this paper.

## Impact on [@P3045R10_PRE] {#absolute-impact}

This is a breaking change to the initial proposal:

1. `quantity<R>` becomes an absolute quantity instead of a delta.
2. Users who need a delta must write `quantity<delta<R>>`, use the `delta<R>(value)`
   construction helper, or call `.delta()` on an existing absolute quantity.
3. `absolute − absolute` returns a delta, not an absolute (the same rule as `point − point → delta`).
   Existing code that assigns such a result to an `absolute` variable will fail to compile;
   the fix is either to change the target type to `delta<R>` or to call `.absolute()` on the
   result to explicitly re-enter the absolute domain.
4. `linear_quantity`, the concept of an absolute or a delta, joins the new `absolute_quantity`
   and the `delta_quantity` and `point_quantity` of [@P3045R10_PRE]. Generic code that
   constrained a parameter with "a delta" to mean "not a point" migrates to it.
   `quantity_of<Q, QS>` matches only absolutes (see [Concepts](#absolute-concepts)). Code written
   with plain spellings such as `5 * m` gets absolutes and keeps matching. Only a difference or an
   explicit delta passed where `quantity_of<Q, QS>` is required now needs `delta<QS>` in the
   constraint.
5. A `quantity_like_traits` specialization whose `reference` is a bare unit now imports an
   absolute, so the `std::chrono::duration` specialization names `delta<R>` to stay a delta. A
   `time_point` stays a point.
6. A quantity of a vector or tensor specification is never an absolute, so without `point<>` it
   stays a delta, and its type keeps its spelling: `quantity<isq::velocity[m / s], vec3>` needs no
   change. A vector value of a bare unit can't be an absolute either, so `vec * m` and
   `quantity<m, vec3>` become ill-formed, and the value is spelled `delta<m>(vec)`, of type
   `quantity<delta<m>, vec3>`. A vector point of a bare unit, `point<m>(vec)` or
   `quantity<point<m>, vec3>`, is ill-formed too, and is spelled with a vector specification, as
   in `point<isq::position_vector[m]>(vec)`.
7. A value of a bare unit is an absolute of its kind. If [@P4411R0_PRE] is adopted, a negative
   value of a non-negative kind, such as `-5. * K` written for a temperature change, is a contract
   violation, and the change is spelled `delta<K>(-5.)` (see
   [For discussion](#absolute-negative-bare-unit)).
8. `-x` on an absolute is a delta when its quantity specification doesn't admit negative values or
   is an unnamed derived specification, and for every absolute if [@P4411R0_PRE] isn't adopted
   (see [Unary negation](#absolute-negation)).
9. Compound assignment keeps the abstraction of its left operand, so `a -= b` with two absolutes
   is ill-formed.

However:

- Code that uses `quantity` for absolute amounts (mass, distance, speed) keeps its meaning,
  because those _are_ absolute quantities.
- Code that uses `quantity` for signed differences (temperature changes, mass changes) should
  spell them `delta<>`. A difference computed as `absolute − absolute` is a delta and no longer
  converts implicitly to `quantity<R>` (item 3).
- A state update by a signed change, such as `level += change` with a delta `change`, keeps the
  absolute abstraction. Subtracting an amount, such as `fuel -= consumption` with an absolute
  `consumption`, is ill-formed (item 9), and the signed balance is formed first, as in
  [Handling underflow](#abs-underflow).

## Implementation experience {#absolute-implementation-experience}

Absolute quantities are implemented on a prototype branch off the version 3 line of [@MP-UNITS]
(October 2026). The library, its tests, and its examples build and pass with GCC 15 and Clang 21.

The implementation went more smoothly than we expected. Most of the library changed mechanically.
The tests and the examples needed changes for one reason: the previous model couldn't express what
the code meant. An amount and a change were the same type, so code written for that model had to
approximate its intent. With three abstractions, each of those approximations was replaced by what
the code meant, and some of them turned out to be real errors (see [The model finds real errors]).
Of the rules of R1, only [unary negation](#absolute-negation) needed a second look. The prototype
also filled in the cases R1 left open and raised a few questions for SG6. This chapter records what
it taught us.

### The model finds real errors

The rule `absolute − absolute → delta` exposed category errors in the library itself. Five
functions stored the difference of two positions back into a position type: `floor` and `ceil`,
`wrap_to_range` and `reflect_in_range`, and the canonical form of a spherical vector.

Together with the `non_negative` check of [@P4411R0_PRE], the model also found signed changes stored
as absolutes in the tests: negative durations fed to the rounding functions, a −3 m projection
offset stored as a length, negative origin bounds, and negative and NaN inputs of formatting tests.
Checking values written with a bare unit changed about 300 more lines of the tests, nearly all of
them negative literals such as `-42 * m` used as signed numbers and now spelled `delta<m>(-42)`, and
the glide computer example, whose sink rates are written `delta<m / s>(-0.7389)`.
In the examples it found three modeling errors:

- A rate of climb was declared as a child of `speed`, but a sinking glider has a negative rate of
  climb. It is the vertical component vector of the velocity, so it is now a child of
  `isq::velocity`, a delta stored in a scalar representation.
- A price was modeled as a point, but it has a true zero and is scaled by a share count, so it is
  an absolute.
- The heights of a glider above the ground were absolutes, but each is the difference of two
  altitudes, so they are deltas.

### Rules the prototype added

R1 left these cases open.

- **Compound assignment.** `a op= b` means `a = a op b`, so it is ill-formed when the abstraction of
  `a op b` can't be stored in `a`: an absolute takes no `-=` of an absolute and no `*=` or `/=` of a
  delta. Without that rule, `a -= b` would turn a delta into an absolute without `.absolute()`.
- **Remainder.** `%` and `fmod` take the abstraction of the dividend, whose sign the remainder has.
- **`hypot`** returns an absolute, as `abs` does.
- **Even powers.** `pow<N>` of a scalar delta with an even integral `N` returns an absolute (see
  [Products and quotients of two deltas]).
- **The common reference.** The first version had two notions of it: the reference the `+` rule
  yields for a mixed pair (an absolute), and the type both operands convert to (the delta), which
  comparisons such as `5 * kg == delta<kg>(5)` need. `get_common_reference` now means conversion
  only, so it coincides with `std::common_type`, and the result of an operator is the operator's
  own rule.
- **`std::chrono::duration`** imports as a delta. The table in
  [Scalar and vector quantities](#absolute-scalar-vector) lists _duration_ as an absolute, but the
  C++ type is a difference, and importing it as an absolute made the conversion back to
  `std::chrono` a refused delta → absolute conversion. So `speed * quantity{std::chrono::seconds{5}}`
  is a delta distance, and storing it in a `quantity<m>` needs `.absolute()`. A `time_point` stays a
  point.
- **Time instants** are points from an epoch. ISO 80000-3:2019 item 3-9 defines _duration_ as a
  "measure of the time difference between two events" and notes that "Duration is often just
  called time", and no part of ISO 80000 defines an instant or a time coordinate. So
  `isq::time` is the same quantity as `isq::duration`, and an instant is a point measured from an
  `independent_point_origin`, as `std::chrono` measures a `time_point` from the epoch of its
  clock. Such a point is never checked against a floor, so a negative instant is
  `epoch + delta<s>(-1.)`. If [@P4411R0_PRE] is adopted, `point<s>(-1.)`, a point measured from
  the natural origin, is a contract violation.
- **Natural origins and offset units.** The natural origin of a kind compares equal to the natural
  origin of a quantity of that kind, `si::absolute_zero` is the natural origin of thermodynamic
  temperature under its own name, and an offset unit is a unit whose origin isn't a natural origin (see
  [Temperature revisited](#absolute-temperature)). In the prototype, `natural_point_origin_` is no
  longer `final`, and an origin is natural when it derives from a tag type.
- **Exact bounds.** A bound that a point inherits from an origin up its chain is checked exactly, in
  the common type of the value and the offset to the origin that owns the bound, so a point with an
  `int` representation in degrees Celsius can be checked against 0 K. A bound that adjusts the
  value, such as clamping or wrapping of [@P4412R0_PRE], still needs its offset and its bounds to
  be exact in the type of the point, which stores the result.
- **Special values.** The quiet and signaling NaN of a point are built without the floor check, as
  the NaN of an absolute is built without the sign check.
- **Bare units.** A value written with a bare unit is an absolute of its kind and is checked when
  the root of the kind is non-negative, and a vector value written with a bare unit is
  ill-formed. A complex value of a kind isn't checked, as a complex quantity has no order.

### What generic code needs

Most generic code in the library, and nearly every generic test helper, needs "an absolute or a
delta", which is to say "not a point", and the first version had no name for that. This is where
`linear_quantity` comes from. A survey of the generic code found no place that needs a delta but
must reject an absolute, while about 18 places in the examples need an amount and about 12 a change
that an absolute may stand for. This decided the meaning of `quantity_of` described in
[Concepts](#absolute-concepts).

### Open questions {#absolute-impl-open}

**The magnitude of a vector.** A vector is never an absolute. Engineering code often stores the
magnitude of a vector in a `double` under the vector's specification, and then gets a delta. The
kinetic energy of a rotation, `moment_of_inertia * pow<2>(angular_velocity)`, and the power
`torque * angular_velocity` are deltas under the proposed rule for
[Products and quotients of two deltas], and would be absolutes if two deltas cancelled and a power
followed the same rule. The storage tank example divides by an `isq::weight`, which is a force and
so a vector, and its fill level is a delta under every rule. ISQ names no scalar specification for
the magnitude of a weight. Where the code means the magnitude, `magnitude()` of the vector gives a
scalar absolute.

**The name of `absolute_point_origin`.** The word "absolute" names an abstraction of quantities, and
it also names the origin that starts an independent affine space, `absolute_point_origin`, while
`si::absolute_zero` is a natural origin. The reference implementation renames the origin and keeps
the old name, deprecated. The candidates are:

- `absolute_point_origin`, the name used in [@P3045R10_PRE] and in this paper's examples: it
  collides with the absolute abstraction.
- `independent_point_origin`, the name the reference implementation uses: such an origin starts an
  affine space of its own.
- `frame_point_origin`: such an origin defines a frame of reference.

`root_point_origin` and `base_point_origin` aren't candidates, because "root" names the root of a
quantity kind and "base" names base quantities and units. This paper proposes
`independent_point_origin`, and its examples keep the current spelling until SG6 chooses a name.

**A negative value written with a bare unit.** If [@P4411R0_PRE] is adopted, `-5. * K` written
for a temperature change is a contract violation, and the change is spelled `delta<K>(-5.)`. This
is the consequence users will meet first, and it is discussed in
[For discussion](#absolute-negative-bare-unit) and polled below.

**Compile time** is not measured yet. An A/B against the branch base precedes any merge.

The model adds three abstractions, four concepts, the `delta<QS>` and `point<QS>` selectors, and
rules for compound assignment. A user needs three sentences: a plain quantity is measured from zero,
a subtraction gives a change, and a reading on a scale with its own origin is a point.


# Summary {#summary}

Absolute quantities add a third abstraction, anchored at a true zero, to the delta and the point
of [@P3045R10_PRE]. They make `28 * K` an absolute temperature that the ideal gas law accepts, and
they let a function signature tell an amount from a change. They change the default meaning of
`quantity<R>`, so they have to be decided before the initial API of [@P3045R10_PRE] is locked.

Affine relationships within the ISQ hierarchy (such as _position vector_ and _displacement_) are
planned for a later revision of [@P3045R10_PRE], and runtime frame projections as a paper of
their own.

# Proposed polls {#polls}

## SG6

1. _SG6 supports adding absolute quantities, a third abstraction of the `quantity` class
   template next to deltas and points, as proposed in P4185R2._
2. _`quantity<R>` should denote an absolute quantity, and a delta should be spelled
   `quantity<delta<R>>`._
3. _An absolute quantity should convert to a delta implicitly, as proposed in P4185R2._
4. _A product or a quotient with a delta operand should be a delta, as proposed in P4185R2._
5. _For an absolute `x`, `-x` should stay an absolute when the quantity specification of `x`,
   named or a quantity kind, admits negative values according to [@P4411R0_PRE], and be a delta
   otherwise. If [@P4411R0_PRE] isn't adopted, `-x` should be a delta for every absolute, as
   proposed in [Unary negation](#absolute-negation)._
6. _`quantity_of<Q, QS>` should match the absolutes of `QS`, and `quantity_of<Q, delta<QS>>` its
   deltas and absolutes, as proposed in [Concepts](#absolute-concepts)._
7. _`absolute_point_origin` should be renamed to `independent_point_origin`._
8. _If [@P4411R0_PRE] is adopted, a value written with a bare unit of a non-negative quantity kind,
   such as `-5. * K`, should be an absolute and be checked, and a signed change should be spelled
   `delta<K>(-5.)` (see [For discussion](#absolute-negative-bare-unit))._

# Next steps

If SG6 gives a favorable direction on absolute quantities, the path forward is:

1. Finish the implementation in the [@MP-UNITS] reference implementation and measure its
   compile time. Absolute quantities are implemented on a prototype branch off its version 3
   line (see [Implementation experience](#absolute-implementation-experience)).

2. Validate against real-world use cases. The existing [@MP-UNITS] user base will
   exercise the new abstraction against production physics, embedded systems, and
   financial code. Design issues should surface at this stage, before standardization.

3. Merge absolute quantities into P3045. They are designed as a breaking change within
   [@P3045R10_PRE], to be merged into it rather than proposed on their own. A future revision of
   P3045 will incorporate them and remove the design alternatives not chosen by SG6.

4. Submit the merged paper to LEWG for design review and approval.

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
