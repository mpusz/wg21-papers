---
title: "Non-Negative Quantity Specifications"
document: P4411R2
date: today
audience:
  - SG6 Numerics
author:
  - name: Mateusz Pusz
    email: <mateusz.pusz@gmail.com>
toc-depth: 3
---


# Revision history

## R2

- [Cases from P4185R1](#inference-p4185r1) brings back the cases with which [@P4185R1] argued
  that no inference rule is correct. They were not carried over when non-negativity moved out of
  [@P4185R2_PRE]: the Planck function, Helmholtz and Gibbs energy defined by subtraction, and
  reactive power with RMS factors. The section shows what [The rule](#inference-rule) gives for
  each of them.
- [Two cases that break a simpler rule](#inference-pitfalls) and
  [Call-site arithmetic](#call-site) bring back `pow<2>(electric_current)`,
  `U * I * std::sin(phi)`, and `efficiency * power` from the same analysis.

## R1

- The paper is written against [@P3045R11_PRE] and uses its spelling, where the abstraction is a
  part of the quantity specification: `point<isq::distance>[m](5.0)` instead of
  `point<isq::distance[m]>(5.0)`. The chapters on absolute quantities follow [@P4185R3_PRE].
- [Where the check runs](#absolute-check-sites): under [@P4185R3_PRE], an absolute never
  converts to a vector specification, so `isq::velocity(-3. * (m / s))` is ill-formed instead of
  unchecked.
- [With and without absolute quantities](#with-absolutes) compares the same code under both
  models, and [Enforcement on absolute quantities](#absolute-enforcement) now comes before
  [What the tag gives with deltas and points](#deltas-and-points).
- [Negative values written with a bare unit](#negative-bare-unit) moved here from the draft of
  [@P4185R3_PRE], which no longer describes the sign check.
- [Negation of a non-negative absolute](#absolute-negation) moved here from the draft of
  [@P4185R3_PRE], where `-x` of an absolute is now always an absolute.
- The polls are reduced to three: the design, the check on absolutes, and inference.

## R0

Initial revision. The material comes from the chapter "Non-negative quantities" of
[@P4185R1] and from the motivation that preceded it. At Brno 2026, SG6 encouraged
splitting the chapter "Range validated quantity points" of [@P4185R1] into a paper of its own.
This paper does the same for non-negativity, so that it can be decided separately. Changes
since the chapter "Non-negative quantities" of [@P4185R1]:

- written against [@P3045R10_PRE] and its `quantity<point<R, PO>, Rep>` spelling, with no
  dependency on [@P4185R2_PRE] (see [Impact on other papers](#impact)),
- `possibly_negative` added (see [Leaving the parent's domain](#possibly-negative)),
- [Non-negativity and individual values](#kind-not-value) added,
- [What the tag gives with deltas and points](#deltas-and-points) added,
- [Why the tag should come before the ISQ definitions](#before-isq) added,
- [Inference from defining equations](#inference) rewritten for defining equations only, where
  [@P4185R1] concluded that inference can't be implemented correctly, and polled separately
  from the tag (see [Proposed polls](#polls)),
- the claim of [@P4185R1] that wrapping scalars in `quantity<dimensionless>` can't preserve
  sign information corrected: a named child of `dimensionless` survives simplification and can
  express a sign in a defining equation (see [Signs that no dimension shows](#signed-coefficient)),
- [Audit of the reference implementation](#audit) added,
- a quantity kind takes the domain of its root, so `point<m>(-1.)` is checked, and with absolute
  quantities so is `-5. * m` (see [Inheritance through the hierarchy](#inheritance)),
- the floor of [Checked points](#checked-points) is a property of the quantity and no longer
  depends on [@P4412R0_PRE]: a point is checked when its own quantity specification is
  non-negative and the chain of its origins ends at a natural origin, and `si::absolute_zero` is
  the natural origin of thermodynamic temperature under a name of its own, which closes the open
  question whether it should check,
- [Review feedback](#feedback) answers the feedback collected so far, and
- [Enforcement on absolute quantities](#absolute-enforcement) added, conditional on
  [@P4185R2_PRE]: where the tag is checked on absolute values and why the checks can't be
  elided further, moved here from the draft of [@P4185R2_PRE].


# Introduction

Many quantities can't be negative. No amount of mass, duration, or volume is below zero, and
ISO 80000-3 defines _speed_ as the magnitude of _velocity_. [@P3045R11_PRE] has no way to
express this. This is why every function that relies on it repeats a precondition, and every
reviewer has to guess which parameters carry the guarantee.

This paper proposes to record the domain once, in the definition of the quantity:

- a `non_negative` property for `quantity_spec`, which states that the physical domain of the
  quantity is the half-line $[0, +\infty)$: every amount of it, measured from its true zero, is
  non-negative,
- inheritance of that property by the real-scalar children of a tagged quantity,
- a `possibly_negative` property, which cancels the inherited property for a child that
  leaves its parent's domain but keeps its parent's kind and units, and
- a compile-time query `is_non_negative(qs)`.

All four are additions to [@P3045R11_PRE], which proposes the framework and no system of
quantities, so no definition in it changes meaning. The ISQ definitions of [@P4213R1_PRE], in the
same mailing, already use `non_negative` and `possibly_negative`; if this paper isn't adopted,
those tags are dropped. The four features are implemented in [@MP-UNITS].

This paper doesn't depend on absolute quantities [@P4185R3_PRE], and it shows what the tag gives
both with and without them. Without them, it gives the query, checks in generic code, and checked
points (see [What the tag gives with deltas and points](#deltas-and-points)). An absolute is an
amount measured from a true zero, which is what `non_negative` describes, so with absolute
quantities the library also checks the tag on values, and the `>= 0` preconditions of
[Motivation](#motivation) go away (see [Enforcement on absolute quantities](#absolute-enforcement)).

The design includes a check on a point of a non-negative quantity, or of a quantity kind whose
root is non-negative, measured from the true zero (see [Checked points](#checked-points)). Two
related features have polls of their own: the check on absolute quantities, and inference from
defining equations, which would let a named derived quantity such as _mass density_ take the
property from its equation. Inference has been prototyped but is not implemented in [@MP-UNITS].

We ask SG6 for a direction before the ISQ definitions of [@P4213R1_PRE] are reviewed,
because the domain of a quantity is part of its definition.


# Motivation {#motivation}

## Preconditions as a symptom {#preconditions}

Consider two functions whose inputs and results are non-negative by their physics. With the
`Expects` macro of the Guidelines Support Library [@GSL], they read:

```cpp
quantity<isq::mass_density[kg / m3]> density(quantity<isq::mass[kg]> mass, quantity<isq::volume[m3]> volume)
{
  Expects(mass >= 0 * kg);
  Expects(volume > 0 * m3);
  return isq::mass_density(mass / volume);
}

quantity<isq::kinetic_energy[J]> kinetic_energy(quantity<isq::mass[kg]> mass, quantity<isq::speed[m / s]> speed)
{
  Expects(mass >= 0 * kg);
  Expects(speed >= 0 * m / s);
  return isq::kinetic_energy(mass * pow<2>(speed) / 2);
}
```

C++26 contracts [@P2900R14] let the author say even more. The preconditions move to the
declaration, where a caller can see them, and a postcondition adds one more check, on the
result:

```cpp
quantity<isq::mass_density[kg / m3]> density(quantity<isq::mass[kg]> mass, quantity<isq::volume[m3]> volume)
  pre(mass >= 0 * kg)
  pre(volume > 0 * m3)
  post(r: r >= 0 * kg / m3)
{
  return isq::mass_density(mass / volume);
}
```

Each function above repeats `mass >= 0 * kg`, and so will every other function in the code base
that takes a mass. A mass can't be negative whatever function it is passed to, so the condition
belongs in the definition of `isq::mass`, but the type system gives the author no place there to
state it. As a result:

- every function repeats the same check, and a forgotten one is not diagnosed,
- the result of `density` is a `quantity<isq::mass_density>`, which is indistinguishable from
  a quantity that could be negative. A C++26 postcondition states the guarantee for the reader,
  and a future compiler might use it to optimize the caller, but it belongs to `density`, not to
  the value, so the next function in the pipeline checks it again,
- without absolute quantities [@P4185R3_PRE], a reviewer can't tell from a signature whether
  a parameter is an amount or a signed difference, and
- generic code can't check at all, because a `quantity_of<isq::mechanical_work> auto`
  parameter may be a _kinetic energy_, which can't be negative, or a _mechanical work_, which
  can.

The last point is the one that a convention can't fix. A precondition `w >= 0 * J` written
for kinetic energies rejects a valid negative work, done against a force that opposes the
motion, and dropping it loses the check for kinetic energies. Only the type of the argument
says which of the two it is.

## With and without absolute quantities {#with-absolutes}

Without absolute quantities, the tag addresses the last point: generic code can ask a quantity for
its domain (see [Domain checks in generic code](#generic-checks)). It doesn't change the two
functions above. A `quantity<isq::mass[kg]>` may hold a negative difference of two masses, so
`density` and `kinetic_energy` keep every precondition.

With absolute quantities [@P4185R3_PRE], the other three points are addressed as well: the
signature tells an amount from a signed difference, and the tag lets the library check the amount.
A `quantity<isq::mass[kg]>` is then an absolute, an amount measured from zero, and a difference of
two masses is a `quantity<delta<isq::mass>[kg]>`. The library checks an absolute of a non-negative
quantity wherever a value that may be negative enters it (see
[Where the check runs](#absolute-check-sites)), and the two functions become:

```cpp
quantity<isq::mass_density[kg / m3]> density(quantity<isq::mass[kg]> mass, quantity<isq::volume[m3]> volume)
  pre(volume != 0 * m3)
{
  return isq::mass_density(mass / volume);  // checked
}

quantity<isq::kinetic_energy[J]> kinetic_energy(quantity<isq::mass[kg]> mass, quantity<isq::speed[m / s]> speed)
{
  return isq::kinetic_energy(mass * pow<2>(speed) / 2);  // checked
}
```

The arguments were checked when the caller created them, and each result is checked when it
becomes a named quantity, so the next function in the pipeline needs no precondition of its own:
under a checking evaluation semantic, a negative value is diagnosed where it is created (a NaN
isn't negative and passes, see [Where the check runs](#absolute-check-sites)).
`volume != 0 * m3` is the one condition that the domain doesn't cover.

A fuel tank shows the difference where a value changes. Without absolute quantities, a tank that
stores its fuel as a `quantity<isq::mass[kg]>` has to guard its invariant in every member function.
It could store a checked point instead (see [Checked points](#checked-points)), but every amount it
takes is still a delta that nothing checks, and a parameter that may be negative looks like one
that can't, whether or not _mass_ carries the tag:

```cpp
class fuel_tank {
  quantity<isq::mass[kg]> fuel_;  // invariant: fuel_ >= 0 * kg
public:
  explicit fuel_tank(quantity<isq::mass[kg]> fuel) pre(fuel >= 0 * kg) : fuel_(fuel) {}

  void burn(quantity<isq::mass[kg]> m) pre(m >= 0 * kg) pre(m <= fuel_) { fuel_ -= m; }

  // a signed correction reported by a gauge
  void correct(quantity<isq::mass[kg]> d) pre(fuel_ + d >= 0 * kg) { fuel_ += d; }
};
```

With absolute quantities, the invariant is a property of the type of `fuel_`, and the signature
of `correct` says that its argument is signed:

```cpp
class fuel_tank {
  quantity<isq::mass[kg]> fuel_;
public:
  explicit fuel_tank(quantity<isq::mass[kg]> fuel) : fuel_(fuel) {}

  void burn(quantity<isq::mass[kg]> m) pre(m <= fuel_) { fuel_ -= m.delta(); }  // checked

  void correct(quantity<delta<isq::mass>[kg]> d) { fuel_ += d; }  // checked
};
```

`burn` keeps `m <= fuel_` as a precondition, so that a violation is reported against the caller.
Without it, the check in the body catches the same mistake, as it does in `correct`.

In the prototype of [@P4185R3_PRE], the check also flagged values that the tests of [@MP-UNITS]
stored as absolutes but meant as signed changes: negative durations passed to the rounding
functions, a −3 m projection offset stored as a length, negative origin bounds, and negative inputs
to the formatting tests (see also [Negative values written with a bare unit](#negative-bare-unit)).

## The domain belongs in the definition of the quantity {#domain-in-definition}

The ISQ decides the domain for some quantities: _speed_ is the magnitude of _velocity_, and
_length_, _area_, and _volume_ measure extents. For others it is a decision that needs review
(see [Why the tag should come before the ISQ definitions](#before-isq)).

[@P3045R11_PRE] already records the character of a quantity in its definition. Whether a
quantity is a scalar or a vector is stated once in its `quantity_spec`, inherited by its
children, and checked by the library wherever it matters. We propose the same for the
domain.

Oliver Rosten raised the missing domain for P3045 [@ROSTEN2025], and [@SEQUOIA] models it. A
check written in user code can't be inherited by a child quantity or queried by generic code.


# Proposal {#proposal}

## The `non_negative` tag {#tag}

`non_negative` is a property passed to a `named_quantity_spec`, in the same position as
`subkind` or a `quantity_character`:

```cpp
inline constexpr struct length           : named_quantity_spec<dim_length, non_negative> {} length;
inline constexpr struct mass             : named_quantity_spec<dim_mass, non_negative> {} mass;
inline constexpr struct duration         : named_quantity_spec<dim_time, non_negative> {} duration;
inline constexpr struct electric_current : named_quantity_spec<dim_electric_current> {} electric_current;
```

_Electric current_ carries no tag, because a current flows in either direction. Among the base
quantities of the ISQ, it is the only one that [@MP-UNITS] leaves untagged.

The tag applies only to real scalar quantities. A vector, a tensor, or a complex quantity has
no order on its values, so `non_negative` on such a specification is ill-formed:

```cpp
// ill-formed: non_negative can only be applied to real scalar quantities
inline constexpr struct bad : named_quantity_spec<isq::length, quantity_tensor_order::vector, non_negative> {} bad;
```

`is_non_negative(qs)` is the corresponding query:

```cpp
template<quantity_spec Q>
consteval bool is_non_negative(Q);
```

For a quantity kind, `kind_of<QS>`, the query answers for its root `QS` (see
[Inheritance through the hierarchy](#inheritance)).

## Inheritance through the hierarchy {#inheritance}

A child of a quantity is a more specific quantity of the same kind. Every _width_, _diameter_,
and _radius_ is a _length_, so if no length is negative, none of them is either. A real-scalar
child therefore inherits `non_negative` from its parent:

```cpp
inline constexpr struct width  : named_quantity_spec<isq::length> {} width;
inline constexpr struct radius : named_quantity_spec<width> {} radius;

static_assert(is_non_negative(width));
static_assert(is_non_negative(radius));
```

Inheritance stops in two places:

- At a child that is not a real scalar: _displacement_ is a vector child of _distance_, so it
  doesn't inherit, and `is_non_negative(isq::displacement)` is `false`. A real-scalar
  descendant of such a child doesn't regain it.
- At a point: `is_non_negative(point<QS>)` is `false`. Whether a point may lie below its origin
  depends on `QS` and on the origin, and [Checked points](#checked-points) describes how the two
  interact.

A quantity kind takes the domain of its root. `kind_of<QS>` is defined only for the root `QS` of
a kind tree, and a value of the kind, such as `42 * m`, is an amount of that root. A signed member
of the tree, such as _altitude_ or the vector _displacement_, states its own domain when it is
named, and a signed value of the kind is a delta. `kind_of<isq::length>`, which is what `42 * m`
carries, is therefore non-negative, and the kind of a signed root is not:

```cpp
static_assert( is_non_negative(kind_of<isq::length>));
static_assert( is_non_negative(kind_of<isq::thermodynamic_temperature>));
static_assert(!is_non_negative(kind_of<isq::electric_current>));
```

A kind is never the parent of a named quantity, so this rule doesn't change the domain of any
named quantity.

A child of a signed parent may carry the tag on its own. _Kinetic energy_ is the example:
_energy_ carries no tag and is signed, while $\tfrac{1}{2}mv^2$ is never negative for a
non-negative mass.

```cpp
inline constexpr struct kinetic_energy
    : named_quantity_spec<mechanical_energy, mass * pow<2>(speed), non_negative> {} kinetic_energy;
```

A nested kind created with `subkind` inherits as any other child does. A `fluid_head` defined
as `named_quantity_spec<isq::height, subkind>` is non-negative.

## Leaving the parent's domain with `possibly_negative` {#possibly-negative}

Once a standard tags _mass_ `non_negative`, inheritance makes every child of _mass_
non-negative. A quantity that is a mass but takes negative values then has no good place. In
[@P3045R11_PRE] a unit belongs to a kind (the gram is defined for `kind_of<isq::mass>`), so
only a quantity of the _mass_ kind may use the kilogram:

- as a child of _mass_, or as a nested kind under it, the quantity inherits `non_negative`,
- rooted on the mass dimension outside the _mass_ tree, it is signed but can't use the
  kilogram.

`possibly_negative` covers the missing case. It cancels the `non_negative` a quantity would
otherwise inherit, while the parent, and with it the kind and the units, stay the same. A correct
hierarchy seldom places a signed quantity below a non-negative one, so the tag is rare. Where it
is needed, nothing else lets the quantity keep the units of its family. Without it,
tagging a quantity in the standard would close its subtree to signed quantities for good.

ISO 80000-12 gives one such quantity: the _effective mass_ of a charge carrier is negative near
the top of an energy band, where the band curves downward, and it is expressed in kilograms:

```cpp
inline constexpr struct effective_mass : named_quantity_spec<isq::mass, possibly_negative> {} effective_mass;

static_assert(!is_non_negative(effective_mass));
quantity m1 = point<effective_mass>[kg](-4.6e-31);  // OK: about -0.5 electron masses
quantity m2 = point<isq::mass>[kg](-4.6e-31);       // contract violation
```

The two tags are mutually exclusive, and naming both is ill-formed.

_Effective mass_ is the only quantity of the ISQ that needs `possibly_negative`. [@MP-UNITS]
also uses the tag, for now, on _altitude_, a signed vertical coordinate under _length_ whose
`non_negative` child is _height_, so that a height converts implicitly to an altitude. Once an
altitude is modeled as a point of _height_, as planned, that tag goes away.

Most uses are expected outside the standard, in libraries for physics that extends a domain. A
spin system in a magnetic field reaches negative absolute temperatures [@PURCELL1951], and so do
the motional degrees of freedom of atoms in an optical lattice [@BRAUN2013]. A library for such
systems declares one child and keeps the kelvin and its origin, `si::absolute_zero`. A point of a
`possibly_negative` quantity isn't checked, even when it is measured from the true zero (see
[Checked points](#checked-points)):

```cpp
inline constexpr struct spin_temperature
    : named_quantity_spec<isq::thermodynamic_temperature, possibly_negative> {} spin_temperature;

quantity t = point<spin_temperature>[K](-0.5);  // OK: 0.5 K below si::absolute_zero
```

An `effective_mass` still converts implicitly to `mass`, because every effective mass is a
mass. With deltas only, that conversion is not checked, and a negative value ends up in a
`quantity<isq::mass>`. With absolute quantities, it is checked (see
[Where the check runs](#absolute-check-sites)).

Here the hierarchy is not a subset relation of domains: a `possibly_negative` child is wider
than its parent. The same is true of a real-scalar quantity below a vector node, which doesn't
regain the property. A rate of climb, declared as a child of _velocity_ and stored in a scalar
representation, is signed and is wider than its non-negative ancestor _speed_. Unlike an
`effective_mass`, it doesn't convert to its ancestor, because in [@P3045R11_PRE] a quantity
doesn't convert to a quantity of another character, and its non-negative size is `magnitude()`.

## Non-negativity and individual values {#kind-not-value}

`non_negative` says that every amount of the quantity, measured from its true zero, is
non-negative. A difference of two amounts is a delta and may still be negative. The property is
a statement about a quantity, and the result of one operation can't establish it.

Some operations never produce a negative value: `abs()` (for a representation in which negation
is defined, since `abs(INT_MIN)` is undefined), a vector norm, the modulus of a complex number,
and the square of one real value. Still, the type of their result usually doesn't say so:
`abs()` keeps the quantity specification of its argument, which may be signed. The absolute
value of a _mechanical work_ is still a mechanical work, and work spans the whole real line, so
there is no non-negative specification for `abs()` to return. A norm can map to a magnitude
quantity, as _speed_ for _velocity_. A general mapping, a `magnitude(QS)` operation on quantity
specifications, is proposed in [@P3045R11_PRE] as the specification of the result of
`magnitude()`, and its result would be non-negative by construction. It covers vector and tensor
quantities only. For a signed scalar such
as work, the only alternative would be a second specification meaning "the non-negative part of
`QS`" for every quantity, which would double the tree.

With absolute quantities [@P4185R3_PRE], `abs()` and `hypot()` of a scalar, `magnitude()` of a
vector, and `modulus()` of a complex scalar return absolutes, while a power of a delta, an even
one included, stays a delta, as `dx * dx` does. Their results are
then amounts measured from zero, and the result of a non-negative specification is checked as
described in [Enforcement on absolute quantities](#absolute-enforcement).

Without absolute quantities, and for a signed specification such as work even with them, the
guarantee belongs in the contract of the operation, as a postcondition. For `abs()`:

```cpp
template<auto R, typename Rep>
constexpr quantity<R, Rep> abs(const quantity<R, Rep>& q) noexcept
  post(r: !(r < quantity<R, Rep>::zero()));
```

Written as "not less than zero", the postcondition also holds for a NaN, which isn't negative
(see [Checked points](#checked-points)). It documents the contract and can be checked, without a
new type.

## Expressions carry no flag {#expressions}

The property belongs to named quantity specifications. The unnamed specification of an
expression, such as the `isq::mass / isq::volume` of `mass / volume`, never carries it:

```cpp
static_assert( is_non_negative(isq::mass_density));
static_assert(!is_non_negative(isq::mass / isq::volume));
```

The reason is that a raw number has no type-level sign. `-1.0 * (mass / volume)` has the same
type as `mass / volume`, and so does `std::sin(phi) * mass / volume`. A flag on the expression
type would claim something the type can't know. The value enters a non-negative quantity
only when it is converted to a named specification, as in `isq::mass_density(mass / volume)`.

The kind of a unit expression, such as `m / s`, is unnamed in the same way and never carries the
property either: `-1.0 * (m / s)` and `-1.0 * (mass / volume)` are the same case.


# Enforcement on absolute quantities {#absolute-enforcement}

_This chapter applies only if absolute quantities [@P4185R3_PRE] are adopted. It is polled
separately, and the rest of the paper doesn't depend on it._

An absolute of a non-negative quantity is the amount that `non_negative` describes, so with
absolute quantities the tag can be checked on values, not only on points. [@P4185R3_PRE] doesn't
constrain the sign of an absolute and leaves the check to this paper.

## Where the check runs {#absolute-check-sites}

A value is checked only when it is stored in an absolute whose quantity specification is
non-negative: a named non-negative specification, or a quantity kind whose root is non-negative.
A delta is never checked, and neither is an unnamed specification, such as `isq::mass / isq::volume`
or the kind of a unit expression such as `m / s` (see [Expressions carry no flag](#expressions)).

A value written with a bare unit is an absolute of a quantity kind, so it is checked when the root
of the kind is non-negative. `quantity x = -10. * kg` carries `kind_of<isq::mass>` and is a
contract violation, and so are `-1 * kg` and `-5. * K`, while `-5. * A` is not, because an electric
current can be negative. A signed value of a kind is written as a delta: `delta<kg>(-10.)`, or
`delta<K>(-5.)` for a temperature change.

A vector or tensor quantity is never an absolute in [@P4185R3_PRE], so it is never checked, and
an absolute never converts to one, so a conversion can't hide a negative absolute:
`isq::velocity(-3. * (m / s))` and `isq::displacement(-5. * m)` are both ill-formed. The signed
values are spelled `delta<m / s>(-3.)` and `delta<m>(-5.)`.

The check runs at four kinds of sites:

1. Construction from a number, `-10. * kg` included, or from a value whose specification is not
   non-negative: from an expression, as in `isq::mass_density(mass / volume)`, or from a
   `possibly_negative` specification, as in the implicit conversion of an `effective_mass` to a
   `mass`.
2. `.absolute()` on a delta.
3. Addition and subtraction of anything but a non-negative absolute, `+=`, `-=`, and `--`
   included. The result is still an absolute, and the other operand can take it below zero.
4. Multiplication and division by a number, `*=` and `/=` included: `-1.0 * mass` is still a
   mass. Negation is not such a site, because the negation of a non-negative absolute is a delta
   (see [Negation of a non-negative absolute](#absolute-negation)).

The check is skipped where the operands already guarantee the sign:

- a conversion of a non-negative absolute to another unit or to another non-negative
  specification, as in `isq::mass(10. * kg)`, when the target representation is the same type,
  a floating-point type, an unsigned type, or a signed integer type wide enough for every value
  of the source (a `height` stored in a `length` isn't checked again, while a conversion to any
  other signed integer type is),
- the sum of two non-negative absolutes, `+=` of one, and `++`,
- `*=` and `/=` by a non-negative absolute of dimension one, and
- the remainder of a non-negative dividend.

The skips are decided from the types alone, so they assume that the arithmetic of the
representation doesn't overflow. In the prototype, an integer representation that overflows in
a sum, in `++`, or in a unit conversion can wrap below zero without a check (for example, `+=`
on a `std::int8_t` mass). This is a gap of the prototype and not proposed behavior.

```cpp
quantity load    = 10. * kg;                                   // site 1: kind_of<isq::mass>
quantity cargo   = isq::mass(load);                            // not checked: load is non-negative
quantity copy    = cargo;                                      // not checked
quantity fuel    = isq::mass(500. * kg);                       // site 1
fuel -= delta<isq::mass>[kg](150.);                            // site 3: 350 kg
fuel *= 2.;                                                    // site 4: 700 kg
quantity spare   = (fuel - cargo).absolute();                  // site 2: 690 kg
quantity deficit = fuel.delta() - delta<isq::mass>[kg](800.);  // a delta, not checked: -100 kg
```

A negative value is a contract violation, as a point below its floor is (see
[Checked points](#checked-points)), so it follows the evaluation semantic in effect, during
constant evaluation as well. If the representation has the `constraint_violation_handler` of
[@P4412R0_PRE], a negative value is reported to the handler instead, and if the handler returns,
the value is stored. The check is written as `!(value < 0)`, so a NaN, which isn't negative,
passes it, as it passes the floor of a point.

A negative value can be stored in a delta (`deficit` in the example), or in an absolute of a
signed quantity, such as an electric current or a quantity declared `possibly_negative`. A bare
unit doesn't avoid the check.

## Negation of a non-negative absolute {#absolute-negation}

In [@P4185R3_PRE], `-x` of an absolute is an absolute, as `-1 * x` is, because negation keeps the
zero. For a non-negative quantity, that result is a negative amount, which the check rejects
whenever `x` is positive. We propose that `-x` of an absolute be a delta when the quantity
specification of `x` is non-negative, when it is a kind whose root is non-negative, or when it is
an unnamed derived specification or the kind of one, whose sign the library doesn't infer from a
quantity equation. The negation of a mass is then the change that removes that mass, while the
negation of a current stays a current. The root of the kind of a unit expression is unnamed, so
`-(2. * (kg / m3))` is a delta, as `-(isq::mass(2. * kg) / isq::volume(1. * m3))` is. A kind takes
the domain of its root, so `-(5. * A)` keeps the absolute abstraction and `-(2. * kg)` doesn't:

```cpp
quantity<isq::electric_current[A]> I1 = ..., I2 = ...;
quantity<isq::electric_current[A]> I3 = -(I1 + I2);  // an absolute current, as in P4185R3

quantity<isq::kinetic_energy[J]> Ek = ...;
quantity<isq::thermodynamic_temperature[K]> T = ...;
auto ratio = -Ek / T;    // delta<kinetic_energy> / absolute<temperature> = delta<...>
auto Ek2 = abs(-Ek);     // the magnitude of a delta is an absolute again
```

The cost is that the result type of `-x` depends on the quantity specification, so generic code
that negates an absolute has to allow for both outcomes, and generic code that needs a delta
writes `-x.delta()`. Adopting this rule after [@P4185R3_PRE] also changes the type of `-mass` in
existing code, from an absolute to a delta, which affects `auto` deduction and overload
resolution.

`-1 * x` scales an absolute by a number and stays an absolute, so it can differ in type from `-x`:
the check rejects `-1 * isq::mass[kg]` and `-1 * kg`, each a negative amount, while
`-(1 * isq::mass[kg])` and `-(1 * kg)` are deltas.

## Negative values written with a bare unit {#negative-bare-unit}

Users will hit this consequence of the check first, and SG6 is asked to discuss it explicitly.
Code that writes `-5. * K` to mean "5 K colder" is a contract violation, and the change has to be
written as a delta:

```cpp
quantity t1 = -5. * K;           // ✗ contract violation: a temperature 5 K below absolute zero
quantity t2 = delta<K>(-5.);     // ✓ a temperature change of -5 K

quantity o1 = -3. * m;           // ✗ contract violation: a negative length
quantity o2 = delta<m>(-3.);     // ✓ an offset of -3 m

quantity e1 = -1. * s;           // ✗ contract violation: a negative duration
quantity e2 = delta<s>(-1.);     // ✓ one second earlier
```

The rule follows from [@P4185R3_PRE]: `28 * K` is a temperature, so `-5. * K` is a temperature
below absolute zero, and a value doesn't change its abstraction with its sign. The cost is that the
shortest spelling of a signed change in a unit of a non-negative kind is now wrong. In the tests of
[@MP-UNITS], the check changed about 300 lines, nearly all of them negative literals such as
`-42 * m` used as signed numbers and now written `delta<m>(-42)`. In a constant expression
evaluated under a terminating contract semantic (enforce or quick-enforce), such as
`constexpr quantity t = -5. * K;`, the violation fails to compile, and under observe it is only
diagnosed. At run time it is a contract violation only when the check runs, and under a semantic
that doesn't check, the negative absolute is stored. Values of a kind that admits negative values,
such as `-5. * A`, are unaffected.

Operator grouping makes the rule reach further than these three lines suggest.
[@P3045R11_PRE] extended the multiply syntax from `number * unit` to `quantity * unit` and
`quantity / unit` (see its chapter "Multiply syntax commutativity"), so `1 * m / s` is two
operations, and its intermediate result `1 * m` is a quantity of its own. That intermediate can
fail the check where the whole expression wouldn't, and the same happens before a conversion to a
signed quantity:

```cpp
quantity v1 = -1. * m / s;               // ✗ contract violation: (-1. * m) is a negative length
quantity v2 = -1. * (m / s);             // unchecked, as the kind of m / s is never non-negative,
                                         //   but still a negative absolute
quantity v3 = delta<m / s>(-1.);         // ✓ a signed velocity component is a change

quantity v4 = isq::velocity(-1. * (m / s));      // ✗ ill-formed: an absolute never converts to a vector
quantity v5 = isq::velocity(delta<m / s>(-1.));  // ✓

quantity q1 = -1. * s * A;               // ✗ contract violation: (-1. * s) is a negative duration
quantity q2 = -1. * A * s;               // ✓ (-1. * A) is a current, which can be negative

quantity a1 = isq::altitude(-5. * m);    // ✗ contract violation: -5. * m is a negative length
quantity a2 = isq::altitude[m](-5.);     // ✓ altitude is signed
quantity a3 = -5. * isq::altitude[m];    // ✓
```

`v1` and `v2` are both wrong spellings of a signed value, and `v2` passes only because the kind of
a unit expression carries no sign, just as an expression of quantity specifications carries none
(see [Expressions carry no flag](#expressions)). The parentheses, or the order of the units,
decide whether the mistake is caught. `v4` is ill-formed at compile time, whatever the sign of the
value and the grouping of the units. Three options are possible:

- keeping the multiply syntax of [@P3045R11_PRE], and teaching that a signed value of a
  non-negative kind is a delta: `v1` and `q1` are then run-time violations that point at that
  spelling;
- restricting the multiply syntax to `number * unit`, so that `quantity * unit` and
  `quantity / unit` are ill-formed: `v1` and `q1` become compile-time errors, at the cost of
  writing every `42 * m / s` as `42 * (m / s)` in existing code, which the extension of
  [@P3045R11_PRE] was added to avoid;
- not checking a value written with a bare unit at all, which also leaves `-5. * K` unchecked.

The author doesn't propose any of them. The first keeps a defect that only a negative value
reaches, and only when the check runs. The second reverses a decision of [@P3045R11_PRE] and
changes a large amount of existing code. The multiply syntax already has known problems that
[@P3045R10_PRE] records. The order of operations in `quantity * unit` and `quantity / unit`
surprises users, as `60 * km / 2 * h` shows in [Potential surprises during units
composition](https://wg21.link/p3045r10#potential-surprises-during-units-composition),
which also explains why [@MP-UNITS] gave up the second option once before. Whether to extend the
syntax further is an open question in
[Multiply syntax commutativity](https://wg21.link/p3045r10#multiply-syntax-commutativity). This
interaction adds to those problems, and it may be a reason to revise the design. The author asks
SG6 to decide the final design of the multiply syntax with all of these issues in view, rather than
this one alone.

## Why the checks can't be elided further {#absolute-elision}

The quotient of two non-negative absolutes is never negative, so it is tempting to skip the
check when such a quotient becomes a named quantity, as in `isq::mass_density(mass / volume)` in
`density` (see [With and without absolute quantities](#with-absolutes)).

`mass / volume` itself isn't checked, because its specification is an expression (see
[Expressions carry no flag](#expressions)). The check runs when the quotient becomes a
_mass density_. Skipping it would need the type of `mass / volume` to prove the sign, and it
can't: `-1.0 * (mass / volume)` has the same type. A correct computation can also give a
negative value of a type built only from non-negative quantities. The mass flow rate through a
surface is $\rho v A \cos\theta$. _Mass density_, _speed_, and _area_ are non-negative, and the
rate is negative when the fluid crosses the surface in the opposite direction:

```cpp
quantity flow = rho * v * A * std::cos(theta);  // theta in radians, as a double; negative for theta > 90°
static_assert(std::is_same_v<decltype(flow), decltype(rho * v * A)>);
```

A check at `*` that trusts non-negative factors rejects `flow`, a valid value. Skipping the
check where the value enters a named non-negative quantity instead accepts
`isq::mass_density(-1.0 * (mass / volume))`. A product with a number, whose sign is unknown,
could be made a delta, as the negation of a non-negative absolute is, but
[@P4185R3_PRE] keeps a product of an absolute and a number an absolute, so that `2. * fuel` stays
an amount. An absolute of an expression can also be built directly from a negative number.

[Inference from defining equations](#inference) doesn't change this. It decides at compile time
that _mass density_ is non-negative, so `isq::mass_density(...)` checks. It says nothing about
the value passed to it.


# What the tag gives with deltas and points {#deltas-and-points}

Deltas and points exist with or without absolute quantities. A delta is a change, which may have
either sign, and is never checked. A point measured from the true zero of a non-negative quantity
is checked. Without absolute quantities, a difference of two masses has the same type as a mass,
so the check on points, the query, and checks in generic code are all that the tag gives, and
[What the tag doesn't do](#limits) lists the gaps that absolute quantities close.

## Checked points {#checked-points}

A point is a position measured from an origin, so a point of a non-negative quantity measured
from its true zero can't lie below it. We propose that such a point be checked with no code from
the user. A point is checked if and only if:

- its own quantity specification is non-negative, where a quantity kind takes the domain of its
  root (see [Inheritance through the hierarchy](#inheritance)),
- the chain of its origins ends at a natural origin, the true zero of the quantity, and
- its representation isn't a complex number, which has no order.

The true zero is then the floor of the point: the check is that the offset of the point's
origin from the natural origin, plus the value of the point, is not negative. It is a
precondition of every operation that stores a point, so it follows the evaluation semantic in
effect, during constant evaluation as well:

```cpp
quantity d1 = point<isq::distance>[m](5.0);   // OK
quantity d2 = point<isq::distance>[m](-1.0);  // contract violation

quantity d3 = point<isq::distance>[m](1.0);
d3 -= isq::distance(3.0 * m);                 // contract violation

quantity d4 = point<m>(-1.0);                 // contract violation: kind_of<isq::length>
quantity a1 = point<isq::altitude>[m](-5.0);  // OK: an altitude is signed
```

The floor is a property of the quantity specification. It needs no bounds policy on the natural
origin, and it doesn't depend on [@P4412R0_PRE], whose range policies stay properties of
origins. With [@P4412R0_PRE], a program can choose another response with the
`constraint_violation_handler` of its representation, or measure from an `absolute_point_origin`
of its own with another policy, for example `clamp_non_negative` to clamp the rounding noise of a
floating-point computation to zero.

A relative origin defined from the natural origin keeps the floor. Points measured from it may
be negative as long as they stay above the true zero:

```cpp
inline constexpr struct average_height : relative_point_origin<natural_point_origin<isq::height> + 1.7 * m> {} average_height;

quantity h1 = average_height - 0.5 * m;  // OK: 1.2 m above the floor
quantity h2 = average_height - 2.0 * m;  // contract violation: 0.3 m below the floor
```

The quantity of the origin plays no role. A height measured from
`relative_point_origin<point<isq::altitude>[m](100.)>` is floored at the true zero, because
_height_ is non-negative and the chain ends at a natural origin, so a height of -200 m from that
origin is a contract violation, while an altitude of -200 m from it isn't.

The origin of the kelvin, `si::absolute_zero`, is the natural origin of thermodynamic
temperature under a name of its own. It compares equal to
`natural_point_origin<isq::thermodynamic_temperature>`, and the name lets a program write
`t - si::absolute_zero` and makes the types print a meaningful name. The kelvin is therefore not
an offset unit. The degree Celsius, and in [@MP-UNITS] the degree Fahrenheit, are offset units,
measured from the relative origins `si::ice_point` and `usc::fahrenheit_zero`, whose chain ends at
`si::absolute_zero`. Points in all three units are checked:

```cpp
quantity t1 = point<K>(-1.0);                                                         // contract violation
quantity t2 = point<isq::thermodynamic_temperature, si::ice_point>[deg_C](-300.0);  // contract violation
quantity t3 = point<deg_F>(-460);                                                     // contract violation: below -459.67 °F
quantity t4 = point<deg_C>(-273);                                                     // OK: 0.15 K above absolute zero
quantity t5 = point<deg_C>(-274);                                                     // contract violation
```

The check is exact. It runs in the common type of the value and the offset to the natural
origin, so the offset doesn't have to be representable in the point's own type: `t4` and `t5`
store an `int` in degrees Celsius and are checked against -273.15 °C, which no `int` in
degrees Celsius holds.

The check is written as "not less than zero", as the postcondition of `abs()` in
[Non-negativity and individual values](#kind-not-value) is, and a NaN isn't negative, so it
passes. Whether a NaN is a valid value is a question of range, which the checking policies of
[@P4412R0_PRE] answer: `check_in_range`, and `check_non_negative` attached to an origin, reject it.
`quiet_NaN()` and `signaling_NaN()` of `numeric_limits` for a checked point are built without the
check, as the NaN of a non-negative absolute is.

A unit conversion keeps the floor, because `.in(U)` changes only the unit and never the quantity
specification.
`point<isq::thermodynamic_temperature, si::ice_point>[deg_C](20.).in(K)` is still checked.

An `absolute_point_origin` declared by the user introduces a zero of its own, and a point
measured from it is never checked against a floor. A net reading on a laboratory balance is
measured from the tare, so readings below the tare are negative and valid:

```cpp
inline constexpr struct tare : absolute_point_origin<isq::mass> {} tare;

quantity net = tare - 0.3 * kg;  // OK: 0.3 kg below the tare
```

A signed position along an axis uses the same pattern: an origin of its own, or a signed
quantity such as _altitude_. So does a time instant. ISO 80000-3 defines _duration_ as the
"measure of the time difference between two events" and notes that "duration is often just
called time". The second is a unit of that non-negative kind, so `point<s>(-1.)`, measured from
the natural origin, is a contract violation. An instant before an epoch is measured from the
epoch, as in `epoch + delta<s>(-1.)`, where `epoch` is an `absolute_point_origin` of the
program.

## Domain checks in generic code {#generic-checks}

When a function takes an amount, the query lets it check its input without knowing which
quantity it was given:

```cpp
template<auto R, typename Rep>
constexpr bool in_domain(const quantity<R, Rep>& q)
{
  if constexpr (is_non_negative(get_quantity_spec(R)))
    return !(q < quantity<R, Rep>::zero());
  else
    return true;
}

template<quantity_of<isq::mechanical_work> Q>
void log_energy_transfer(Q w)
  pre(in_domain(w))
{
  // ...
}

log_energy_transfer(isq::mechanical_work(-12.0 * J));  // OK: a work may be negative
log_energy_transfer(isq::kinetic_energy(-12.0 * J));   // contract violation
log_energy_transfer(-12.0 * J);                        // OK: kind_of<isq::energy> is signed
```

This is the case from [Preconditions as a symptom](#preconditions) that a hand-written
precondition can't handle. The knowledge of which energies are signed lives in the definitions
of `isq::mechanical_work` and `isq::kinetic_energy`, and the function picks it up from the
argument type.

The function still states a precondition. It is now written once, the same way for every
quantity.

The helper is correct only where the author knows the parameter is an amount. A delta of a
non-negative quantity may be negative (a mass lost in a reaction), and with deltas only, its
type doesn't say so. `-12.0 * m` is such a delta in [@P3045R11_PRE]: the library doesn't check
it, while `in_domain` rejects it, because `kind_of<isq::length>` takes the domain of _length_.

## What the tag doesn't do {#limits}

With only deltas and points, the tag doesn't change how a delta behaves:

- `-mass` compiles and yields a negative `quantity<isq::mass>`,
- `mass_a - mass_b` yields the same type as an absolute mass, whatever its sign, and can be
  passed to any function that expects an amount, and
- nothing checks a delta of a non-negative quantity, at construction or anywhere else, and
  `-12.0 * m` is such a delta, although `kind_of<isq::length>` is non-negative.

These gaps come from the missing abstraction. A delta is the right type for
a difference, and the library has no other type for an amount measured from a true zero.
[@P4185R3_PRE] proposes that abstraction, the absolute quantity, and
[Enforcement on absolute quantities](#absolute-enforcement) describes how the tag would be
checked on its values. This paper doesn't depend on it.


# Why the tag should come before the ISQ definitions {#before-isq}

[@P3045R11_PRE] proposes the framework and no system of quantities. [@P4213R1_PRE] proposes the
ISQ and SI definitions needed for the SI, and its synopsis already uses `non_negative` with a
note that the tags can be dropped if this feature is not accepted. Deciding the feature first
matters for three reasons.

1. Adding a domain later changes the behavior of valid programs. Once a
   `quantity<point<isq::length>[m]>` measured from the natural origin is allowed to hold
   `-1 m`, tagging `isq::length` in a later standard turns that program into a contract
   violation, because points measured from a natural origin are checked. So does
   `point<m>(-1.)`, because the kind of the metre takes the domain of _length_.

2. The domain shapes the hierarchy. In [@MP-UNITS], _height_ is a non-negative child of a
   signed _altitude_, so a height converts implicitly to an altitude and not the other way
   round. With no domain to express, the natural shape is two siblings under _length_, with
   different conversions. A conversion that is allowed in one standard can't be removed later
   without breaking code.

3. The decisions need review, quantity by quantity. They are not obvious. Until recently
   [@MP-UNITS] tagged _energy_ and _power_ as non-negative, so _mechanical work_, which is
   negative when the force opposes the displacement, inherited the error. So did the Gibbs
   energy $G = H - TS$, which is negative whenever $TS$ exceeds $H$. The fix removed
   `non_negative` from both roots. The same review removed it from _specific energy_, whose
   children were wrong as well: _specific internal energy_ and _specific enthalpy_ are measured
   from a chosen reference state and are negative below it, and _specific Gibbs energy_
   $g = h - Ts$ is negative whenever $Ts$ exceeds $h$. _Heat capacity_ (negative for self-gravitating
   systems), _energy density_, and the _damping coefficient_ (negative for a self-excited
   oscillation) need the same review. Errors of this kind are easy to make, and LEWG reviewing
   each definition once, with its domain, is the cheapest point to catch them. [@P4213R1_PRE]
   lists 40 ISQ names, and later parts of the ISQ add several hundred. Reviewing each one for its
   domain in a second pass repeats the work.

The feature is a pure addition to [@P3045R11_PRE]: a `named_quantity_spec` already accepts
properties that are not quantity specifications (`subkind` and the character values), and the
two tags are two more.


# Inference from defining equations {#inference}

_This section describes a design that has been prototyped against the definitions of
[@MP-UNITS] but is not implemented there. It is polled separately, and the tag is useful
without it._

Non-negativity can be propagated to a large share of the derived quantities. A named derived
quantity has a defining equation, and in many cases the equation already proves the domain:
_mass density_ is mass over volume, and both are non-negative. Inference makes the tag on
_mass density_ redundant, and with it most of the explicit tags in the ISQ.

## The rule {#inference-rule}

A defining equation is non-negative if and only if it has at least one factor and every
factor is a non-negative named quantity specification, raised to any power. A named quantity
with a defining equation is non-negative if:

- it carries `non_negative`, or
- it is a real scalar, it doesn't carry `possibly_negative`, and either its parent is
  non-negative or its equation is.

`possibly_negative` cancels the inherited and the inferred property of the quantity that
carries it. It doesn't cancel inference from the equation of a descendant: a child of _energy_
whose defining equation is `mass * pow<2>(length) / pow<2>(duration)` infers `non_negative`
from it, and needs `possibly_negative` of its own if it is signed. If the tag blocked inference
in the whole subtree, every non-negative energy would need its own tag again, _kinetic energy_
among them.

Inference needs the tag on two roots as well. The defining equations of _energy_ and _power_ in
[@MP-UNITS], $M L^2 T^{-2}$ and $M L^2 T^{-3}$, have only non-negative factors, so both would
infer `non_negative`, and so would every signed energy and power below them. Adopting inference
therefore means marking both roots `possibly_negative`. Without inference, the tag on a root has
no effect, and this paper doesn't propose it there.

## Two cases that break a simpler rule {#inference-pitfalls}

An earlier attempt at inference in [@MP-UNITS] failed on two cases, and the rule above
avoids both.

The first is the identity of the algebra. `dimensionless` is the empty product. A fold over zero
factors that starts from "non-negative" marks `dimensionless` as non-negative, then every
dimensionless quantity, and then every factor that should carry a sign. The empty product
must count as signed: `dimensionless` denotes any quantity of dimension one, whose domain is
the whole real line.

The second is an even power. It is tempting to treat $Q^2$ as
non-negative for any real $Q$. The type algebra, however, folds the product of two independent
values of one quantity into the same type as a square:

```cpp
inline constexpr struct signed_coefficient : named_quantity_spec<dimensionless> {} signed_coefficient;

quantity q1 = signed_coefficient(0.8 * one);
quantity q2 = signed_coefficient(-0.5 * one);
quantity prod = q1 * q2;  // value: -0.4
static_assert(prod.quantity_spec == pow<2>(signed_coefficient));
```

The type doesn't record whether its two factors were one value, so the rule treats $Q^{2}$ like $Q$.
[@P4185R1] proposed the opposite, with `pow<2>(electric_current)` as its example: the square of a
real scalar can't be negative. That holds for a square, but not for the product of two independent
currents, which has the same type. In the ISQ definitions of [@MP-UNITS] this costs one explicit
tag: _non-active power_ is defined through the $\sqrt{S^2}$ idiom, and the tag isn't there yet.
_Kinetic energy_ is not such a case. It is non-negative because _mass_ and _speed_ are.

## Signs that no dimension shows {#signed-coefficient}

Some signed quantities have equations whose dimensional factors are all non-negative.
_Reactive power_ is $U \cdot I \cdot \sin\varphi$, and the sign comes from the phase angle. A
dimensional formula shows only $M L^2 T^{-3}$.

The `signed_coefficient` above handles such cases. It is a named child of `dimensionless`,
so it survives simplification (only `dimensionless` itself folds away), and because no even
power is trusted, it can't be squared away. Placed in a defining equation, it records that a
factor of unknown sign takes part. One coefficient serves $\sin$, $\cos$, a negation, or a
signed scale factor, because the rule needs to know only that some factor is signed. The cost
is that a product without the coefficient, such as `U * I`, then converts to such a quantity
only explicitly.

Negating an already signed quantity needs nothing. The Massieu function $J = -A/T$ negates the
Helmholtz energy, which is signed because _energy_ is, so $A/T$ infers a signed result with no
annotation.

## Cases from P4185R1 {#inference-p4185r1}

[@P4185R1] concluded that no inference rule is correct, and gave the cases below as evidence.
The rule of this paper has to get each of them right. The definitions are those of the V3 branch
of [@MP-UNITS].

| Quantity         | Equation                                    | Definition in [@MP-UNITS]                      | Result of [The rule](#inference-rule) |
|------------------|---------------------------------------------|------------------------------------------------|---------------------------------------|
| Speed            | $v = l / t$                                 | `length / time`                                | non-negative                          |
| Mass density     | $\rho = m / V$                              | `mass / volume`                                | non-negative                          |
| Helmholtz energy | $A = U - T \cdot S$                         | a child of _internal energy_, no equation      | signed, from _energy_                 |
| Gibbs energy     | $G = H - T \cdot S$                         | a child of _enthalpy_, no equation             | signed, from _energy_                 |
| Massieu function | $J = -A / T$                                | `Helmholtz_energy / thermodynamic_temperature` | signed, as $A$ is                     |
| Planck function  | $Y = -G / T$                                | `Gibbs_energy / thermodynamic_temperature`     | signed, as $G$ is                     |
| Reactive power   | $Q = U_\text{rms} I_\text{rms} \sin\varphi$ | see below                                      | signed only with `signed_coefficient` |

_Speed_ and _mass density_ are the cases inference is for: every factor is non-negative, so the
explicit tag each of them carries today becomes redundant.

_Helmholtz energy_ and _Gibbs energy_ are defined by subtraction, which a defining equation of
[@MP-UNITS] can't express. Their dimension is $M L^2 T^{-2}$, the dimension of the non-negative
_kinetic energy_, so a rule that read dimensions would make both non-negative. This rule never
reads a dimension. Neither quantity has an equation, so each takes the domain of its parent, and
the chain ends at _energy_, which is `possibly_negative`.

The _Massieu function_ and the _Planck function_ are defined by negation. The minus sign is lost
in the definitions above, but nothing depends on it: the numerator is signed, so the quotient is
signed too, which is the domain of $J$ and $Y$.

Reactive power is the case that needs an annotation. $U_\text{rms}$ and $I_\text{rms}$ are
non-negative by construction, so if a library defines them as non-negative quantities and
reactive power as their product, the rule infers that reactive power is non-negative. That is
wrong, as $\sin\varphi$ is negative for a capacitive load. The sign comes from a factor of
dimension one, so the definition has to contain the `signed_coefficient` of
[Signs that no dimension shows](#signed-coefficient). [@MP-UNITS] defines reactive power as
$M L^2 T^{-3}$ with no named factors, and the rule infers non-negative from that as well (see
[Audit of the reference implementation](#audit)).

## Audit of the reference implementation {#audit}

The rule was run against every named quantity specification of the ISQ in the V3 branch of
[@MP-UNITS], by compiling a patched copy of the library and comparing the property of each
quantity with and without inference. The run marked _energy_ and _power_ `possibly_negative`, as
[The rule](#inference-rule) requires, and predates the removal of `non_negative` from _specific
energy_.

| Item                              | Count |
|-----------------------------------|------:|
| Named quantity specifications     |   390 |
| Explicit `non_negative` tags      |   134 |
| Tags made redundant by inference  |    76 |
| Quantities whose property changes |    21 |

All 21 changes go from signed to non-negative, as the rule guarantees. They fall into three
groups:

- Signed quantities whose equation hides the sign: _mechanical energy_, and with it
  _potential energy_, restate $M L^2 T^{-2}$ under a signed parent. _Reactive power_ is
  defined in [@MP-UNITS] as $M L^2 T^{-3}$. _Angular measure_ and _rotational displacement_
  are arc length over radius, while an angle's sign is an orientation convention, and the angle
  family inherits from them. _Poisson number_ is negative for auxetic materials, and the
  thermal expansion coefficients are negative for water between 0 °C and 4 °C. Today none of
  them carries a tag that states its sign. Under inference each needs a `possibly_negative`
  tag of its own or the `signed_coefficient`.
- A gain that depends on a reviewed tag: _logarithmic decrement_ becomes non-negative
  through its factor _damping coefficient_, so it follows whatever the review decides for that
  tag.
- A contested case: _refractive index_ is $c_0/c$ and infers non-negative. That is correct
  for ordinary media, while metamaterials with a negative refractive index exist
  [@SHELBY2001]. A library for them can declare a `possibly_negative` child.

With these tags added, only _refractive index_ and _logarithmic decrement_ still change.

An earlier run of the prototype against older definitions found 389 quantities, 109 tags, 90
redundant, and 27 changes. That run still saw _energy_ and _power_ as non-negative, so it also
found the errors that have since been fixed by hand. Two conclusions drawn from that run don't
hold for the current definitions: _electromagnetic energy density_ needs no tag of its own,
because it inherits from _energy density_, and _non-active power_ and _mechanical energy_ don't
carry the explicit tags those conclusions assumed.

## Call-site arithmetic {#call-site}

Inference applies to defining equations only. The expression types of
[Expressions carry no flag](#expressions) stay unflagged, because the raw numbers in an
expression are invisible to the type.

Dividing a non-negative quantity by another one gives a non-negative result. For a named quantity
the type shows it: the definition of _mass density_ proves its domain at compile time, which is what
inference does. For a value computed in user code, it can't. `mass / volume` and `-1.0 * (mass /
volume)` share a type, so the type can't carry the proof. The same goes for `U * I * std::sin(phi)`,
and for `efficiency * power` when `efficiency` is a `double` that may be above 1 or below 0: a raw
number of unknown sign takes part, and the type doesn't show it. A quotient of deltas is a delta,
and deltas are not checked, so there is nothing to skip. With absolute quantities, the checks that
can be skipped are listed in [Where the check runs](#absolute-check-sites), and [Why the checks
can't be elided further](#absolute-elision) explains why the others stay.


# Review feedback {#feedback}

At St. Louis 2024, a participant considered the tag a small addition that is worth adding,
with no need to wait for contracts. The tag, the query, and the point check are implemented without
contracts. The check is a precondition in [@MP-UNITS] and can use contracts where they are
available. At the same meeting, another participant pointed out that _speed_ is often used for the
signed component of a velocity along an axis, and raised it again at Sofia 2025. ISO 80000-3
defines _speed_ as the magnitude of velocity, so the ISQ _speed_ stays non-negative. A signed
velocity along one axis, such as a rate of climb, is declared as a child of `isq::velocity`
and stored in a scalar representation. Its vector character keeps it signed, also under
inference (see [Inheritance through the hierarchy](#inheritance)), and it uses `m / s`.

At Sofia 2025, a participant argued that runtime checks are hard to add later and that the
property should be in the type, and another noted that preconditions can be turned off.
The property is in the type (see [The `non_negative` tag](#tag)), and the check on points (see
[Checked points](#checked-points)) is a precondition, so it follows the evaluation semantic in
effect.

At Croydon 2026, a participant asked that the response to a negative value for a non-negative
quantity be customizable. The `constraint_violation_handler` of [@P4412R0_PRE] provides that
for points (see [Checked points](#checked-points)), and with absolute quantities for absolutes as
well (see [Where the check runs](#absolute-check-sites)).

At Brno 2026, SG6 reviewed [@P4185R1]:

- A participant noted that non-negativity can be propagated to many derived quantities. See
  [Inference from defining equations](#inference).
- A participant observed that dividing a non-negative quantity by a non-negative quantity
  should let the library skip checks. With deltas only there is no check to skip (see
  [Call-site arithmetic](#call-site)). With absolute quantities, the quotient isn't checked, and
  the check runs when it becomes a named quantity, for the reason given in
  [Why the checks can't be elided further](#absolute-elision).
- A participant said that some users may not want a precondition that, for example, a force
  is positive, and that this is a choice. In the ISQ of [@MP-UNITS], _force_ and its children
  are vectors and never carry the property, and a user who declares a scalar force decides in
  its definition whether it carries `non_negative`. For quantities that do carry it, a value
  that may be negative is a delta, which is never checked, a value of a signed quantity, or a
  point measured from an origin of the user's own. A bare unit doesn't avoid the check, because
  a quantity kind takes the domain of its root.
- A participant questioned forbidding negative values, since new physics may one day need a
  negative mass, and was concerned about teachability. Physics already has such cases, and the
  design handles them without leaving the ISQ: effective mass is a mass that is negative near a
  band maximum, and negative absolute temperatures have been reported (see
  [Leaving the parent's domain](#possibly-negative)). Each is one `possibly_negative` child that
  keeps the units and the origin of its parent. For teaching, the rule is that a bare unit
  means an amount, a change or a signed value is a delta, and a position is a point that picks
  an origin. A user meets the feature through the units of non-negative kinds as well as through
  named quantities: `point<m>(-1.)` is a contract violation, and with absolute quantities so is
  `-5. * K`, which is spelled `delta<K>(-5.)` when it means a temperature 5 K lower. The
  automatic behavior is the check on a point measured from the true zero of a non-negative
  quantity, and with absolute quantities, the check on an absolute of one.
- The same participant also noted that rounding can push a value that can't be negative below zero.
  `clamp_non_negative` from [@P4412R0_PRE] handles that on an `absolute_point_origin` of the
  user's own.


# Impact on other papers {#impact}

**[@P3045R11_PRE].** The synopsis gains two property tags next to `subkind` and one query:

```cpp
namespace std {

inline constexpr struct non_negative {} non_negative;
inline constexpr struct possibly_negative {} possibly_negative;

template<quantity_spec Q>
consteval bool is_non_negative(Q);

}
```

The four specializations of `named_quantity_spec` gain the rules of
[Inheritance through the hierarchy](#inheritance), `$kind-of-t$<QS>` reports the property of `QS`,
and `point<QS>` and `derived_quantity_spec` report `false`. The operations that store a point gain
the precondition of [Checked points](#checked-points).

Natural origins change in three ways:

- `$natural-point-origin-t$` is no longer `final`, so that a system of units can give the natural
  origin of a quantity a name of its own, as `si::absolute_zero` does.
- An origin derived from a natural origin is a natural origin and compares equal to the natural
  origins its base compares equal to, so `si::absolute_zero`,
  `natural_point_origin<isq::thermodynamic_temperature>`, and
  `natural_point_origin<kind_of<isq::thermodynamic_temperature>>` compare equal.
- An offset unit is a unit whose origin is not a natural origin. The degree Celsius is an offset
  unit, and the kelvin, whose origin is `si::absolute_zero`, is not, so `28 * K` becomes valid.

[@P3045R11_PRE] already makes the first change and declares `si::absolute_zero` the natural
origin of thermodynamic temperature. The kelvin is still an offset unit there.

**[@P4412R0_PRE].** The natural origin of a non-negative quantity doesn't get
`check_non_negative`: the floor belongs to the quantity specification and needs no policy of an
origin. A point of a quantity kind with a non-negative root, such as `point<m>(5.)`, is checked as
well. The floor is checked as an inherited checking bound is (see the rule for bounds the point
can hold in [@P4412R0_PRE]): exactly, in the common type of the value and the offset to the
natural origin, so `point<deg_C>(-273)` with an `int` representation is valid and
`point<deg_C>(-274)` is not. When the origin of a floored point has a policy, the policy runs first
and the floor checks the value to be stored, and the range of the policy may reach below the true
zero. An inherited adjusting policy and the `min()` and `max()` of
`numeric_limits` for a point still need the offset and the bounds to be exact in the point's own
type.

**[@P4213R1_PRE].** `si::absolute_zero` is declared as the natural origin of thermodynamic
temperature under its own name, and the kelvin names it as its origin. `si::ice_point` stays a
relative origin and inherits the floor through its chain. [@P4213R1_PRE] also marks
_energy_ `possibly_negative`, which has an effect only under inference (see
[The rule](#inference-rule)), so the tag belongs with that poll. A later revision should review
the domain of every definition it lists, which is easier once SG6 has given a direction on this
paper.

**[@P4185R3_PRE].** This paper replaces the chapter of [@P4185R1] on non-negative quantities.
[@P4185R3_PRE] no longer contains it and doesn't depend on non-negativity. If both papers are
adopted, absolute quantities are checked as described in
[Enforcement on absolute quantities](#absolute-enforcement), and `-x` of a non-negative absolute is
a delta instead of an absolute (see [Negation of a non-negative absolute](#absolute-negation)).


# Implementation experience {#implementation}

[@MP-UNITS] implements `non_negative`, `possibly_negative`, `is_non_negative`, inheritance,
and the automatic check on points of a named non-negative quantity measured from its natural
origin. The behavior is the same on its master branch and on its V3 branch, which uses the
spelling of [@P3045R11_PRE]. On master a point is spelled `quantity_point`. The feature is not
yet in a released version of [@MP-UNITS]: it is scheduled for 2.6.0. On both branches, a quantity
kind is never non-negative and `si::absolute_zero` carries no check, so `point<m>(-1.)` and
`point<isq::thermodynamic_temperature>[K](-1.)` are not checked there.

The ISQ definitions of [@MP-UNITS] carry 133 `non_negative` tags and 2 `possibly_negative`
tags (_effective mass_ and, for now, _altitude_), and the test suite checks the property of every
quantity.

The prototype of absolute quantities that [@P4185R3_PRE] describes, a branch of [@MP-UNITS] off
its V3 branch that is not yet public, implements the rules of this revision. A quantity kind
takes the domain of its root, `si::absolute_zero` is the natural origin of thermodynamic
temperature, and a point is checked as described in [Checked points](#checked-points), exactly,
with the NaN of `numeric_limits` built without the check. The prototype also implements the
checks and skips of [Where the check runs](#absolute-check-sites), with the gaps described there.
The check on values written with a bare unit is implemented, and so is the rule that makes a
vector multiplied by a bare unit ill-formed. A complex value of a kind isn't checked, because
a complex quantity has no order.
The examples of [Checked points](#checked-points) and
[Where the check runs](#absolute-check-sites) run as commented with GCC 15, using gsl-lite as the
contract backend.

Inference from defining equations is not implemented. The audit in
[Audit of the reference implementation](#audit) patched a copy of the library to compute the
inferred property.


# Open questions {#open-questions}

1. **Should `possibly_negative` on a vector, tensor, or complex quantity be ill-formed?** On a
   root whose defining equation has only non-negative factors, such as _energy_, the tag is
   redundant today, but it becomes necessary under inference. On a vector, tensor, or complex
   quantity it is never necessary. [@MP-UNITS] accepts it. `non_negative` on such a quantity is
   ill-formed.
2. **The spelling of `signed_coefficient`.** It exists only in the prototype, and the name is
   a placeholder.


# Proposed polls {#polls}

## SG6

1. _SG6 supports adding the `non_negative` and `possibly_negative` properties of `quantity_spec` to
   [@P3045R11_PRE] as proposed in P4411R1: inheritance, the `is_non_negative` query, and the check
   on points measured from a natural origin._
2. _If poll 1 passes and absolute quantities [@P4185R3_PRE] are adopted, an absolute of a
   non-negative quantity should be checked, and its negation should be a delta, as proposed in
   P4411R1._
3. _SG6 encourages more work on inferring non-negativity from defining equations, as described in
   P4411R1._


# Acknowledgements

Special thanks and recognition goes to [The C++ Alliance](https://cppalliance.org) for supporting
Mateusz's membership in the ISO C++ Committee and the production of this proposal.

The author would like to thank Oliver Rosten for raising non-negativity as a missing part of
the design and for the discussions that shaped it.

---
references:

- id: P3045R11_PRE
  citation-label: P3045R11
  author:
    - family: Pusz
      given: Mateusz
  title: "Quantities and units library"
  URL: <https://wg21.link/p3045r11>
- id: P3045R10_PRE
  citation-label: P3045R10
  author:
    - family: Pusz
      given: Mateusz
  title: "Quantities and units library"
  URL: <https://wg21.link/p3045r10>
- id: P4213R1_PRE
  citation-label: P4213R1
  author:
    - family: Pusz
      given: Mateusz
  title: "Minimal SI: Defining the International System of Units for the C++ Standard Library"
  URL: <https://wg21.link/p4213r1>
- id: P4185R2_PRE
  citation-label: P4185R2
  author:
    - family: Pusz
      given: Mateusz
  title: "Absolute Quantities"
  URL: <https://wg21.link/p4185r2>
- id: P4185R3_PRE
  citation-label: P4185R3
  author:
    - family: Pusz
      given: Mateusz
  title: "Absolute Quantities"
  URL: <https://wg21.link/p4185r3>
- id: P4412R0_PRE
  citation-label: P4412R0
  author:
    - family: Pusz
      given: Mateusz
  title: "Range-Validated Quantity Points"
  URL: <https://wg21.link/p4412r0>
- id: GSL
  citation-label: GSL
  title: "Guidelines Support Library"
  URL: <https://github.com/microsoft/GSL>
- id: MP-UNITS
  citation-label: mp-units
  title: "mp-units - A Physical Quantities and Units library for C++"
  URL: <https://mpusz.github.io/mp-units>
- id: MP-UNITS-SAFETY
  citation-label: mp-units quantity safety
  author:
    - family: Pusz
      given: Mateusz
  title: "Bringing Quantity-Safety To The Next Level"
  issued:
    year: 2025
  URL: <https://mpusz.github.io/mp-units/latest/blog/2025/01/15/bringing-quantity-safety-to-the-next-level>
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
- id: PURCELL1951
  citation-label: Purcell1951
  author: "E. M. Purcell and R. V. Pound"
  title: "A Nuclear Spin System at Negative Temperature. Physical Review 81, 279 (1951)"
  URL: <https://doi.org/10.1103/PhysRev.81.279>
- id: BRAUN2013
  citation-label: Braun2013
  author: "S. Braun et al."
  title: "Negative Absolute Temperature for Motional Degrees of Freedom. Science 339, 52 (2013)"
  URL: <https://doi.org/10.1126/science.1227831>
- id: SHELBY2001
  citation-label: Shelby2001
  author: "R. A. Shelby, D. R. Smith, and S. Schultz"
  title: "Experimental Verification of a Negative Index of Refraction. Science 292, 77 (2001)"
  URL: <https://doi.org/10.1126/science.1058847>

---
