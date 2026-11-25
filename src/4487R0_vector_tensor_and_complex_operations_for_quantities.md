---
title: "Vector, Tensor, and Complex Operations for Quantities"
document: P4487R0
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

Initial revision.


# Abstract

_Work_ and _moment of force_ are both a _force_ times a _length_. _Work_ is a scalar product and
_moment of force_ a vector product, but with a single `operator*` both are the same expression,
and a _moment of force_ converts to _work_. [@P3045R11_PRE] therefore defines `operator*` only for
operands of which at most one is a vector or a tensor, and never converts a quantity to one of
another character. As a result, a quantity typed as a vector can't be used to compute _work_ or a
_moment of force_, and _moment of inertia_ can't be defined as the tensor that maps an
_angular velocity_ to an _angular momentum_.

This paper adds the operations of [@ISO80000] part 2 that fill this gap:

- `scalar_product`, `vector_product`, `tensor_product`, `inner_product`, `inner_quotient`, and
  `unit_vector`,
- `real`, `imag`, `modulus`, `conj`, and `make_complex` for complex quantities.

They apply to quantity specifications and, except `inner_quotient`, to quantities. The type of a
result records the operation and its operands, so _work_ and _moment of force_ are different
quantities. The proposal removes nothing that [@P3045R11_PRE] proposes and changes the meaning of
nothing in it. It is implemented in a branch of [@MP-UNITS].


# Introduction

A vector quantity with more than one component needs a linear algebra vector as its
representation, and a units library that offers only `operator*` can't compute a _moment of force_
or a _mechanical work_ from such quantities. Linear algebra libraries either don't overload
`operator*` for two vectors, so `force * displacement` doesn't compile, or overload it as a
component-wise or a scalar product, none of which is a _moment of force_.

Au [@AU-EIGEN] and nholthaus/units [@NHOLTHAUS-EIGEN] recently added `dot` and `cross` (`unit_dot`
and `unit_cross` in nholthaus/units) for Eigen vectors in a quantity (Au) or of quantities
(nholthaus/units). The unit of their result is only the product of the units of the operands, so
`dot(F, d)` and `cross(r, F)` are both in `N m`, and nothing tells _work_ from a _moment of
force_. Python's Pint provides such operations through NumPy, with the same result units.

The usual workaround is a vector of quantities. The linear algebra library then computes the
products, as it needs only arithmetic on the elements (`la` stands for any linear algebra
library):

```cpp
la::vector<quantity<si::newton>> force = {1. * N, 2. * N, 3. * N};
la::vector<quantity<si::metre>> displacement = {3. * m, 2. * m, 1. * m};
quantity<si::joule> work = la::scalar_product(force, displacement);
```

The units library sees only the multiplications of the scalar components. It can't tell a scalar
product from a vector product, can't check the order of the operands of a vector product, and knows
nothing of the character of the result. The result above is a quantity in joules, which the
magnitude of a _moment of force_, or a product of two scalars that happens to have the same
dimension, would be as well. Such a design can't be quantity-safe. The operations have to be known
to the units library, on quantities and on quantity specifications, which is what this paper
proposes:

```cpp
quantity force = isq::force(vec{1., 2., 3.} * N);
quantity displacement = isq::displacement(vec{3., 2., 1.} * m);
quantity<isq::mechanical_work[J]> work = scalar_product(force, displacement);
```

[@ISO80000] defines _mechanical work_ as a scalar product and _moment of force_ as a vector product
(items 4-28.4 and 4-12.1 of part 4). Their units are the same (`N m`, or `J` for the work), and only
the operation tells them apart. A library with one `operator*` for both would give the two quantity
equations the same expression, and a _moment of force_ would convert implicitly to
_mechanical work_.

[@P3045R11_PRE] avoids that by refusing the plain product of two quantities that are declared
vectors or tensors:

```cpp
// auto q1 = force * displacement;  // Compile-time error in P3045R11
```

It also proposes `magnitude()` and the quantity specification `magnitude(QS)` of its result
(see [Relation to P3045R11]). Every other operation is left out, so a quantity typed as a vector
has no way to become a _mechanical work_, a _moment of force_, a _mechanical power_, or an
_angular momentum_, and a complex quantity has no way to give its real part. A user has to drop to
the representation and lose the type.

With [@P3045R11_PRE] alone, a system of quantities can't define the following quantities as
[@ISO80000] defines them:

| Quantity                | Item   | [@ISO80000] definition          | With [@P3045R11_PRE] alone                                        |
|-------------------------|--------|---------------------------------|-------------------------------------------------------------------|
| _mechanical work_       | 4-28.4 | line integral of $F \cdot dr$   | `force * displacement` is ill-formed                              |
| _mechanical power_      | 4-27   | $P = F \cdot v$                 | `force * velocity` is ill-formed                                  |
| _moment of force_       | 4-12.1 | $M = r \times F$                | `position_vector * force` is ill-formed                           |
| _angular momentum_      | 4-11   | $L = r \times p$                | `position_vector * momentum` is ill-formed                        |
| _moment of inertia_     | 4-7    | $L = J\omega$                   | `angular_momentum / angular_velocity` is ill-formed               |
| _torque_                | 4-12.2 | $T = M \cdot e_Q$               | `magnitude(moment_of_force)` has no sign                          |
| _pressure_              | 4-14.1 | $p = e_n \cdot F / A$           | `magnitude(force) / area` counts the whole force                  |
| _Poynting vector_       | 6-34   | $S = E \times H$                | `electric_field_strength * magnetic_field_strength` is ill-formed |
| _complex power_         | 6-59   | $S = U I^*$                     | no complex conjugate                                              |
| _reactive power_        | 6-60   | $Q = \operatorname{Im} S$       | no imaginary part of a quantity specification                     |

Declared without these equations, or with magnitudes in place of the vectors, the quantities
compile, but they lose the checks or the meaning. A _mechanical work_ declared only as a child of
_energy_ becomes any _energy_ after an explicit conversion. A _torque_ defined as
`magnitude(force) * length` has no sign, and the magnitude of a force times any length, a
_height_ for example, converts to it implicitly. A _pressure_ defined as
`magnitude(force) / area`, the example of a quantity equation in [@P3045R11_PRE], counts the
whole force instead of its component normal to the surface.

`vec` in the examples is `cartesian_vector<double>` and `tens` is `cartesian_tensor<double>`, both
from the utility library of [@MP-UNITS]. This paper doesn't propose them. The examples use the ISQ
definitions of [@MP-UNITS], with the changes listed in [ISQ definitions].


# Proposed design

## The operations

The following operations are proposed for quantity specifications:

| Operation              | Operands                             | Result                             | [@ISO80000] part 2   |
|------------------------|--------------------------------------|------------------------------------|----------------------|
| `scalar_product(a, b)` | two vectors or two tensors           | scalar                             | 2-18.11, 2-18.25     |
| `vector_product(a, b)` | two vectors                          | vector                             | 2-18.12              |
| `tensor_product(a, b)` | two vectors                          | tensor                             | 2-18.21              |
| `inner_product(T, a)`  | a tensor and a vector or a tensor    | the order of `a`                   | 2-18.24, 2-18.23     |
| `inner_quotient(a, b)` | two vectors                          | the tensor that maps `b` to `a`    | (see below)          |
| `unit_vector(a)`       | a vector                             | dimensionless vector               | 2-18.6               |
| `real(z)`, `imag(z)`   | a complex quantity                   | real quantity of the order of `z`  | 2-15.2, 2-15.3       |
| `modulus(z)`           | a complex scalar                     | real scalar                        | 2-15.4               |
| `conj(z)`              | a complex quantity                   | the complex conjugate of `z`       | 2-15.6               |
| `make_complex(re, im)` | two real quantities of one dimension | complex quantity                   | 2-15.2               |

The field of a product is complex when an operand is complex. The dimension of a product is the
product of the dimensions of its operands, the dimension of `inner_quotient(a, b)` is their
quotient, `unit_vector(a)` is dimensionless, and the other operations keep the dimension of their
operand (of `re` for `make_complex`).

An operand that isn't declared a scalar may be a quantity kind, which admits every character
([@P3045R11_PRE] writes that a kind has no character of its own). A product operation, or
`inner_quotient`, of kind operands keeps the operation and the order of its operands:
`vector_product(kind_of<isq::length>, kind_of<isq::force>)` is a vector product of two kinds, and
isn't a kind. `kind_of<>` doesn't change. `real`, `imag`, `modulus`, `conj`, and `unit_vector` of
a kind, and `make_complex` of two kinds, give a kind (see [Operations on quantities]).

None of the operations takes a point, as a point has no products and no complex parts.

`inner_quotient(a, b)` has no item of its own in [@ISO80000]. It names the tensor `T` for which
`inner_product(T, b)` is `a`, which is how part 4 defines _moment of inertia_ (item 4-7 writes
$L = J\omega$ and calls it a tensor product; in the terms of part 2, it is an inner product). Many
tensors map one given vector to another, so two quantities have no such quotient, and
`inner_quotient` exists for quantity specifications only.

## Quantity equations

An operation is one factor of a quantity equation, as a named quantity is. A named quantity may be
defined with an operation, alone or inside a product:

```cpp
inline constexpr struct mechanical_work : named_quantity_spec<energy, scalar_product(force, displacement)> {} mechanical_work;
inline constexpr struct mechanical_power : named_quantity_spec<power, scalar_product(force, velocity)> {} mechanical_power;
inline constexpr struct moment_of_force : named_quantity_spec<vector_product(position_vector, force)> {} moment_of_force;
inline constexpr struct angular_momentum : named_quantity_spec<vector_product(position_vector, momentum)> {} angular_momentum;
inline constexpr struct moment_of_inertia :
    named_quantity_spec<inner_quotient(angular_momentum, angular_velocity)> {} moment_of_inertia;
```

The character of such a quantity comes from the operation: _mechanical work_ is a real scalar,
_moment of force_ a real vector, and _moment of inertia_ a real tensor, and none of them needs a
`quantity_tensor_order` argument.

## Operations on quantities

The same functions, except `inner_quotient`, take quantities. The quantity specifications decide
whether the operation exists and which quantity the result is, the representation types compute
the value (see [Customization points for representation types]), and the unit of a product is the
product of the units:

```cpp
quantity force = isq::force(vec{1., 2., 3.} * N);
quantity displacement = isq::displacement(vec{3., 2., 1.} * m);
quantity lever = isq::position_vector(vec{0., 1., 0.} * m);

quantity<isq::mechanical_work[J]> work = scalar_product(force, displacement);       // 10 J
quantity<isq::moment_of_force[N * m], vec> moment = vector_product(lever, force);   // {3, 0, -1} m N

// auto q1 = force * displacement;                                                  // Compile-time error
// quantity<isq::mechanical_work[J]> q2 = vector_product(lever, force).magnitude(); // Compile-time error
// quantity<isq::moment_of_force[N * m], vec> q3 = vector_product(force, lever);    // Compile-time error
```

`q2` is the magnitude of a vector product, which isn't a scalar product (see
[The quantity of a result]). `q3` has its operands in the wrong order. Neither converts, even with
`quantity_cast`.

The result of `scalar_product(force, displacement)` is a
`quantity<scalar_product(isq::force, isq::displacement)[N * m], double>`. It is a quantity of its
own, which converts implicitly to `isq::mechanical_work`, as the operation is the equation of
_mechanical work_.

The library takes two real scalar representations to be components along the same axis, so two
real scalars have a scalar product, which is their plain product:

```cpp
quantity w = scalar_product(isq::force(10. * N), isq::displacement(-5. * m));  // -50 m N
```

They have no vector product, as a scalar representation can't hold a result perpendicular to that
axis.

A product operation on quantity kinds keeps the operation and the order of its operands (see
[The operations]), and its result converts implicitly to a quantity defined with the same operation
on quantities of those kinds:

```cpp
quantity sp = scalar_product(vec{1., 2., 3.} * N, vec{3., 2., 1.} * m);   // 10 m N
quantity vp = vector_product(vec{3., 2., 1.} * m, vec{1., 2., 3.} * N);   // {4, -8, 4} m N

quantity<isq::mechanical_work[J]> work3 = sp;                             // OK
quantity<isq::moment_of_force[N * m], vec> moment2 = vp;                  // OK
// quantity<isq::moment_of_force[N * m], vec> q5 = vector_product(vec{1., 2., 3.} * N, vec{3., 2., 1.} * m);  // Compile-time error
```

`q5` has its operands in the wrong order and doesn't convert even with `quantity_cast`. `sp`
converts to `isq::energy` explicitly, and never to `isq::moment_of_force` or `isq::torque`. `sp`,
`vp`, and the result of `q5` convert implicitly to a quantity of `N * m`, the kind of the plain
product, and a plain `*` of kinds doesn't change: `5. * N * (2. * m)` is a
`quantity<N * m, double>`, which converts implicitly to _mechanical work_, to _moment of force_,
and to _torque_. The type of `sp` spells out the operation in its reference, which isn't a bare
unit, but a quantity prints only its unit, as in `10 m N`.

## The quantity of a result

The following rules decide how the results convert. They hold for quantity specifications and for
quantities alike.

- Both orders of the operands of a scalar product give the same type, for any operands. For real
  operands the scalar product is commutative, so the two values are equal as well. For complex
  operands, the representation decides whether the scalar product is bilinear (item 2-18.11 of
  [@ISO80000] part 2) or conjugates one operand (as `cartesian_vector` of [@MP-UNITS] does), and
  the type doesn't record which, so the two values may differ (see
  [The scalar product of complex operands]). The vector product is anti-commutative, so its two
  orders are different quantities, and neither converts to the other, even with `quantity_cast`.
  The tensor product and the inner product keep the order of their operands as well. An operand
  of these products is never rewritten into the quantity tree of the other one, as that would merge
  the two orders: `vector_product(isq::displacement, isq::velocity)` doesn't become
  `vector_product(isq::velocity, isq::displacement)`, though a _velocity_ is a _displacement_
  divided by a _duration_.
- A product of real operands is linear in each operand, so a scalar factor of an operand is a factor
  of the result. `scalar_product(force, velocity)` converts implicitly to
  `scalar_product(force, displacement) / duration`, which makes _mechanical work_ divided by
  _duration_ a _mechanical power_, and `mass * vector_product(position_vector, velocity)` converts
  implicitly to `vector_product(position_vector, momentum)`.
- Operands convert one by one, like two named quantities do. `scalar_product(
  isq::static_friction_force, isq::displacement)` converts implicitly to _mechanical work_, and
  `scalar_product(isq::force, isq::displacement)` becomes a scalar product of a _static friction
  force_ only explicitly.
- The scalar product of two vectors equals the product of their magnitudes only up to the cosine
  of the angle between them, so replacing one with the other is an explicit conversion. The same
  holds for the magnitude of a vector product (up to the sine) and of an inner product (an upper
  bound only). The magnitude of a tensor product is the product of the magnitudes of its operands,
  so that conversion is implicit:

    ```cpp
    // quantity<isq::mechanical_work[J]> q4 = force.magnitude() * displacement.magnitude();  // Compile-time error
    quantity work2 = isq::mechanical_work(force.magnitude() * displacement.magnitude());       // OK, explicit
    ```

    For the same reason, `scalar_product(isq::force, isq::displacement)` converts to `isq::energy`
    only explicitly (see [Open questions]).
- The magnitude of a vector product, and of an inner product, relaxes only to the product of the
  magnitudes of its operands, and never further to the equation of another named quantity, unless
  the source also carries exactly one plane angle (a quantity of the kind `isq::angular_measure` or
  of a kind declared below it) to the first power, in the numerator. A solid angle, a count, a
  storage capacity, or a ratio of two angles doesn't count. `magnitude(isq::moment_of_force)`
  doesn't convert to `isq::energy`, `isq::kinetic_energy`, or `isq::mechanical_work`,
  `magnitude(isq::angular_momentum)` doesn't convert to `isq::action`, and `isq::torque` and
  `isq::torque * isq::rotation` don't convert directly to `isq::energy`, even with `quantity_cast`
  (see [Conversions through a kind]). With a plane angle, the sine in $|r \times F|$ takes the part
  of the force along the arc, and the radius times the angle is the length of the arc, so
  $W = T\theta$ and $P = T\omega$. [@ISO80000] part 4
  has no item for a rotational work, power, or kinetic energy, so these conversions are explicit,
  and `isq::mechanical_work` and `isq::mechanical_power`, a force times a displacement or a
  velocity, take them only with `quantity_cast` (see [Power and energy of a rotation]). With
  `moment` of [Operations on quantities]:

    ```cpp
    quantity T = isq::torque(5. * N * m);
    quantity omega = isq::angular_velocity(vec{0., 0., 2.} * (rad / s));

    quantity<isq::energy[J]> e1(T * isq::angular_displacement(2. * rad));               // OK, explicit
    quantity<isq::power[W]> p1(T * isq::angular_frequency(2. * rad / s));               // OK, explicit
    quantity<isq::power[W]> p2(T * omega.magnitude());                                  // OK, explicit
    quantity<isq::power[W]> p3(moment.magnitude() * omega.magnitude());                 // OK, explicit
    quantity<isq::power[W]> p4(scalar_product(moment, omega));                          // OK, explicit
    // quantity<isq::mechanical_work[J]> w1(T * isq::angular_displacement(2. * rad));   // Compile-time error
    // quantity<isq::energy[J]> e2(T * isq::rotation(2. * one));                        // Compile-time error
    ```

    `scalar_product(inner_product(isq::moment_of_inertia, isq::angular_velocity),
    isq::angular_velocity)` converts to `isq::kinetic_energy` explicitly as well.

- `inner_product(isq::moment_of_inertia, isq::angular_velocity)` converts implicitly to
  `isq::angular_momentum`, as the inner product undoes the inner quotient that defines _moment of
  inertia_.
- `scalar_product(a, vector_product(b, c))` and `scalar_product(vector_product(a, b), c)`, the two
  ways to write a scalar triple product, are different quantities, though their values are equal.
- A quantity kind converts implicitly to a quantity defined with an operation other than
  `unit_vector`, and such a quantity converts implicitly to its kind, as every quantity does in
  [@P3045R11_PRE]. `N * m` is therefore a unit of _mechanical work_, of _moment of force_, and of
  _torque_. A quantity of
  `isq::moment_of_force` in a `double` that is stored in a `quantity<N * m>` and then assigned to a
  `quantity<isq::mechanical_work[J]>` converts in two implicit steps. Assigned directly, it doesn't
  convert, even explicitly (see [Conversions through a kind]).

## `abs()` and `hypot()` of a vector

[@P3045R11_PRE] doesn't propose `abs()` or `hypot()`. The paper that proposes them should make
them scalar operations, like `pow<>()` and `sqrt()` in [@P3045R11_PRE]: they are ill-formed for a
quantity of a vector or a tensor specification, whatever its representation, as the size of a
vector is its `magnitude()`. `abs()` and `hypot()` stay well-formed for a scalar and for a quantity
kind, and [@MP-UNITS] implements this rule.

## The parts of a complex quantity

[@P3045R11_PRE] doesn't let a complex quantity convert to a real one. The definition of a complex
quantity names its real parts with the properties `real_part<>`, `imaginary_part<>`, and
`complex_modulus<>`:

```cpp
inline constexpr struct complex_power :
    named_quantity_spec<voltage_phasor * conj(electric_current_phasor), real_part<struct active_power>,
                        imaginary_part<struct reactive_power>, complex_modulus<struct apparent_power>> {} complex_power;
inline constexpr struct active_power : named_quantity_spec<power, inverse(period) * (instantaneous_power * time)> {} active_power;
inline constexpr struct apparent_power : named_quantity_spec<complex_power, quantity_field::real, non_negative> {} apparent_power;
inline constexpr struct reactive_power : named_quantity_spec<mass * pow<2>(length) / pow<3>(duration)> {} reactive_power;
```

[@ISO80000] part 6 defines _complex power_ with the complex conjugate of the _electric current
phasor_, $S = U I^*$ (item 6-59). `conj(QS)` is a quantity specification of its own, and
`conj(conj(QS))` is `QS`, so `isq::voltage_phasor * conj(isq::electric_current_phasor)` converts
implicitly to `isq::complex_power`, and `isq::voltage_phasor * isq::electric_current_phasor`
doesn't convert to it, even with `quantity_cast`.

`real(QS)`, `imag(QS)`, and `modulus(QS)` of such a quantity are the quantities it names. A part
is passed as a type, so it may be defined after the complex quantity and be its child, as
_apparent power_ is. It has to be complete before `real()`, `imag()`, or `modulus()` is called
for the complex quantity, or before a result of `make_complex()` is converted to it. A child of
a complex quantity has the parts of its parent.

```cpp
quantity power = isq::complex_power(std::complex{800., 600.} * (V * A));

quantity<isq::active_power[W]> active = real(power);              // 800 W
quantity reactive = imag(power);                                  // 600 V A of isq::reactive_power
quantity<isq::apparent_power[V * A]> apparent = modulus(power);   // 1000 V A
quantity<isq::complex_power[V * A], std::complex<double>> rebuilt = make_complex(active, reactive);
```

A part is in the unit of the complex quantity. `make_complex(re, im)` takes the real part first and
the imaginary part second, and its value is in the unit of `re`. Its result converts implicitly to
a complex quantity that names quantities to which `re` and `im` convert implicitly as its real and
its imaginary part. `make_complex(reactive, active)` doesn't become a _complex power_, even
explicitly.

For a complex quantity that names no parts, `real(QS)` is a quantity specification of its own,
spelled `real(QS)`, and the same holds for `imag(QS)` and `modulus(QS)`. `conj(q)` of a quantity
of `QS` is a quantity of `conj(QS)`, and `conj` of a quantity kind is the kind.

## Unit vectors

[@ISO80000] part 2 defines the unit vector in the direction of a vector $a$ as $e_a = a/|a|$, for
$a \neq 0$ (item 2-18.6). `unit_vector(QS)` is a dimensionless vector, real or complex as `QS` is,
with the quantity equation `QS / magnitude(QS)`. It converts implicitly to `QS / magnitude(QS)`,
and the reverse is explicit, as the quotient isn't known to have a magnitude of one. Its operand
has to admit a vector, as a tensor has no unit vector. `unit_vector` of a quantity kind is
`kind_of<dimensionless>`.

`unit_vector(q)` computes the unit vector of a quantity through its representation (see
[Customization points for representation types]) and gives a quantity of `unit_vector(QS)` in
`one`. A zero vector has no direction, so a non-zero `q` is a precondition, as a non-zero divisor
is for a division. The representation has to be a type for which `treat_as_floating_point` is
`true`.

The magnitude of a unit vector is one, which the type can't check, so the value is checked where
it enters:

- A quantity of a unit-vector specification is created from a raw value, or converted from a
  specification that isn't a unit vector (a dimensionless vector, `kind_of<dimensionless>`, or
  `QS / magnitude(QS)`), only explicitly, with the precondition that the magnitude of the quantity
  is one, with a relative tolerance of 8 epsilon of its value type. A NaN passes the check.
- No arithmetic keeps the unit-vector specification: `2 * e`, `e + e`, `-e`, and a rotation give a
  plain dimensionless vector. A unit vector has no compound assignment, and its
  `numerical_value_ref_in()` gives only a `const` reference, as a writable one would bypass the
  check.

Part 4 uses unit vectors in two definitions. _Torque_ is $T = M \cdot e_Q$, the scalar product of
the _moment of force_ and the unit vector $e_Q$ of the direction with respect to which the torque
is considered (item 4-12.2), so a torque is signed. _Pressure_ is the quotient of the component of
a force normal to a surface and its area, written with the unit vector $e_n$ of the surface normal
(item 4-14.1). [@MP-UNITS] names the two directions `isq::torque_direction` and
`isq::surface_normal_direction` (see [ISQ definitions]). With `moment` of
[Operations on quantities]:

```cpp
quantity axis = unit_vector(isq::displacement(vec{0., 0., 2.} * m));                         // {0, 0, 1}
quantity<isq::torque[N * m]> torque = scalar_product(moment, axis);                          // -1 m N

quantity load = isq::force(vec{3., 0., -10.} * N);
quantity normal = vec{0., 0., -1.} * isq::surface_normal_direction[one];                     // into the surface
quantity<isq::pressure[Pa]> pressure = scalar_product(load, normal) / isq::area(2. * m2);    // 5 Pa
```

The normal of the example points into the surface, along the load. [@ISO80000] doesn't fix the
orientation of $e_n$, so the sign of the pressure follows the choice of the user.

A torque isn't a magnitude. `magnitude(isq::moment_of_force)` and `isq::torque` convert to each
other only explicitly.
`magnitude(isq::force) / isq::area` converts to `isq::pressure` only explicitly, and
`isq::force / isq::area` doesn't convert to it.

The magnitude of a unit vector is checked only where a value enters a unit-vector specification,
so only a quantity typed as a unit vector makes a torque implicitly:

```cpp
quantity d = isq::displacement(vec{0., 0., 7.} * m);
quantity<isq::torque[N * m]> t1 = scalar_product(moment, unit_vector(d));                    // -1 m N
// quantity<isq::torque[N * m]> t2 = scalar_product(moment, vec{0., 0., 5.} * one);         // Compile-time error
// quantity<isq::torque[N * m]> t3 = scalar_product(moment, d / d.magnitude());             // Compile-time error
quantity<isq::torque[N * m]> t4(scalar_product(moment, vec{0., 0., 5.} * one));             // -5 m N
```

`t2` and `t3` convert only explicitly. That conversion is of the result, so it checks no
magnitude, and `t4` is five times too large. The unit vector of a quantity kind, such as
`unit_vector(vec{0., 0., 2.} * m)`, is a `kind_of<dimensionless>`, so it makes a torque only
explicitly as well.

## ISQ definitions

[@MP-UNITS] defines the ISQ with these operations. Besides the definitions in
[Quantity equations] (items 4-28.4, 4-27, 4-12.1, 4-11, and 4-7 of [@ISO80000] part 4) and the
definition of `isq::complex_power` with `conj` in [The parts of a complex quantity], the following
show the other patterns:

```cpp
inline constexpr struct Poynting_vector :
    named_quantity_spec<vector_product(electric_field_strength, magnetic_field_strength)> {} Poynting_vector;
inline constexpr struct impedance :
    named_quantity_spec<electric_potential / electric_current, quantity_field::complex,
                        real_part<struct resistance_to_alternating_current>, imaginary_part<struct reactance>,
                        complex_modulus<struct apparent_impedance>> {} impedance;
```

Before this change, [@MP-UNITS] defined such quantities with `operator*` and `operator/` and an
explicit `quantity_tensor_order`, which made, for example, a _moment of force_ convert to
_mechanical work_.

_Torque_ and _pressure_ follow items 4-12.2 and 4-14.1 of [@ISO80000] part 4 (see [Unit vectors]).
Their directions, `isq::torque_direction` ($e_Q$) and `isq::surface_normal_direction` ($e_n$), are
new, and their names are invented, as [@ISO80000] has no item for them:

```cpp
inline constexpr struct torque_direction : named_quantity_spec<dimensionless, unit_vector(displacement)> {} torque_direction;
inline constexpr struct torque : named_quantity_spec<scalar_product(moment_of_force, torque_direction)> {} torque;
inline constexpr struct surface_normal_direction :
    named_quantity_spec<dimensionless, unit_vector(displacement)> {} surface_normal_direction;
inline constexpr struct pressure : named_quantity_spec<scalar_product(force, surface_normal_direction) / area> {} pressure;
```

The changes to the ISQ of [@MP-UNITS] that the examples rely on are the definitions of this
section and of [Quantity equations], the parts named by the complex quantities, and the two
directions.

## Customization points for representation types

A quantity computes an operation through its representation types. For the products, the
conjugate, and the unit vector, the library looks up a function under the name of [@ISO80000] or,
for the scalar and the vector product, under the name that linear algebra libraries use. The first
one found is used:

- `scalar_product`: `a.scalar_product(b)`, `scalar_product(a, b)`, `a.dot(b)`, `dot(a, b)`, and
  `a * b` when both are real scalars,
- `vector_product`: `a.vector_product(b)`, `vector_product(a, b)`, `a.cross(b)`, `cross(a, b)`,
- `tensor_product`: `a.tensor_product(b)`, `tensor_product(a, b)`,
- `inner_product`: `a.inner_product(b)`, `inner_product(a, b)`,
- `conj`: `z.conj()`, `conj(z)`,
- `unit_vector`: `v.unit_vector()`, `unit_vector(v)`, and `v / math::magnitude(v)`.

A free function is found by argument-dependent lookup only. `real`, `imag`, and `modulus` of a
quantity use `math::real`, `math::imag`, and `math::modulus` of [@P3045R11_PRE] for its
representation.

These are exposition-only helpers, not new customization point objects. Generic code multiplies
two representations through the quantities that hold them, and a function of a quantity is found
by argument-dependent lookup. [Open questions] asks whether they should be public.

A quantity operation exists only if the quantity specifications have it, the representation
helper can be called for the two representations, and its result, with
`representation_canonical_type` of [@P3045R11_PRE] applied, satisfies `representation_of` for the
specification of the result. The quantity specifications decide first: two `double` quantities of
`isq::mass` and `isq::force` have no scalar product. Then the representations decide: two
`double` quantities of `isq::position_vector` and `isq::force` have no vector product.

## Proposed interface

The declarations below are additions to the synopsis of [@P3045R11_PRE]. `$EquationSpec$` of
[@P3045R11_PRE], which holds for a derived quantity specification and for `$magnitude-t$<V>`, holds
for each exposition-only specification below as well.

```cpp
namespace std {

// quantity specification properties
template<typename Q>
struct $real-part-t$ {};             // exposition only
template<typename Q>
struct $imaginary-part-t$ {};        // exposition only
template<typename Q>
struct $complex-modulus-t$ {};       // exposition only

template<typename Q>
constexpr $real-part-t$<Q> real_part{};
template<typename Q>
constexpr $imaginary-part-t$<Q> imaginary_part{};
template<typename Q>
constexpr $complex-modulus-t$<Q> complex_modulus{};

// the specifications of the operations (also of a product operation of quantity kinds; the other operations of a kind give a kind)
template<quantity_spec L, quantity_spec R> struct $scalar-product-t$ : $quantity-spec-interface$ {};  // exposition only
template<quantity_spec L, quantity_spec R> struct $vector-product-t$ : $quantity-spec-interface$ {};  // exposition only
template<quantity_spec L, quantity_spec R> struct $tensor-product-t$ : $quantity-spec-interface$ {};  // exposition only
template<quantity_spec L, quantity_spec R> struct $inner-product-t$ : $quantity-spec-interface$ {};   // exposition only
template<quantity_spec L, quantity_spec R> struct $inner-quotient-t$ : $quantity-spec-interface$ {};  // exposition only
template<quantity_spec Q> struct $real-t$ : $quantity-spec-interface$ {};                              // exposition only
template<quantity_spec Q> struct $imag-t$ : $quantity-spec-interface$ {};                              // exposition only
template<quantity_spec Q> struct $modulus-t$ : $quantity-spec-interface$ {};                           // exposition only
template<quantity_spec Q> struct $conj-t$ : $quantity-spec-interface$ {};                              // exposition only
template<quantity_spec V> struct $unit-vector-t$ : $quantity-spec-interface$ {};                       // exposition only
template<quantity_spec Re, quantity_spec Im> struct $complex-t$ : $quantity-spec-interface$ {};        // exposition only

struct $quantity-spec-interface$ {  // exposition only
  // ... as in P3045R11

  // $ScalarProductOperands$<L, R>: both may be vectors, or both may be tensors
  // $VectorOperands$<L, R>: both may be vectors; $VectorOperand$<Q>: Q may be a vector
  // $InnerProductOperands$<L, R>: L may be a tensor, R may be a vector or a tensor
  // $ComplexOperand$<Q>: Q may be complex; $ComplexScalarOperand$<Q>: Q may be a complex scalar
  // $ComplexParts$<Re, Im>: both may be real, their orders overlap, and their dimensions are the same
  // ("may be" is true for a quantity kind, which admits every character)

  template<quantity_spec Lhs, quantity_spec Rhs>
    requires(!$PointQuantitySpec$<Lhs>) && (!$PointQuantitySpec$<Rhs>) && $ScalarProductOperands$<Lhs, Rhs>
  friend consteval quantity_spec auto scalar_product(Lhs lhs, Rhs rhs);

  template<quantity_spec Lhs, quantity_spec Rhs>
    requires(!$PointQuantitySpec$<Lhs>) && (!$PointQuantitySpec$<Rhs>) && $VectorOperands$<Lhs, Rhs>
  friend consteval quantity_spec auto vector_product(Lhs lhs, Rhs rhs);

  template<quantity_spec Lhs, quantity_spec Rhs>
    requires(!$PointQuantitySpec$<Lhs>) && (!$PointQuantitySpec$<Rhs>) && $VectorOperands$<Lhs, Rhs>
  friend consteval quantity_spec auto tensor_product(Lhs lhs, Rhs rhs);

  template<quantity_spec Lhs, quantity_spec Rhs>
    requires(!$PointQuantitySpec$<Lhs>) && (!$PointQuantitySpec$<Rhs>) && $InnerProductOperands$<Lhs, Rhs>
  friend consteval quantity_spec auto inner_product(Lhs lhs, Rhs rhs);

  template<quantity_spec Lhs, quantity_spec Rhs>
    requires(!$PointQuantitySpec$<Lhs>) && (!$PointQuantitySpec$<Rhs>) && $VectorOperands$<Lhs, Rhs>
  friend consteval quantity_spec auto inner_quotient(Lhs lhs, Rhs rhs);

  template<quantity_spec Q>
    requires(!$PointQuantitySpec$<Q>) && $ComplexOperand$<Q>
  friend consteval quantity_spec auto real(Q q);

  template<quantity_spec Q>
    requires(!$PointQuantitySpec$<Q>) && $ComplexOperand$<Q>
  friend consteval quantity_spec auto imag(Q q);

  template<quantity_spec Q>
    requires(!$PointQuantitySpec$<Q>) && $ComplexScalarOperand$<Q>
  friend consteval quantity_spec auto modulus(Q q);

  template<quantity_spec Q>
    requires(!$PointQuantitySpec$<Q>) && $ComplexOperand$<Q>
  friend consteval quantity_spec auto conj(Q q);

  template<quantity_spec Q>
    requires(!$PointQuantitySpec$<Q>) && $VectorOperand$<Q>
  friend consteval quantity_spec auto unit_vector(Q q);

  template<quantity_spec Re, quantity_spec Im>
    requires(!$PointQuantitySpec$<Re>) && (!$PointQuantitySpec$<Im>) && $ComplexParts$<Re, Im>
  friend consteval quantity_spec auto make_complex(Re re, Im im);
};

struct $quantity-interface$ {  // exposition only
  // ... as in P3045R11

  // $ProductOf$<Op, RepOp, R1, Rep1, R2, Rep2>: neither R1 nor R2 is a point reference, Op exists for
  // their quantity specifications, RepOp (an exposition-only helper of [Customization points for
  // representation types]) can be called for Rep1 and Rep2, and its result represents the result
  // of Op; $PartOf$<Op, RepOp, R, Rep> likewise for one operand; $UnitVectorOf$<R, Rep> likewise for
  // unit_vector and @_rep-unit-vector_@, and treat_as_floating_point<Rep> is true
  template<auto R1, typename Rep1, auto R2, typename Rep2>
    requires $ProductOf$<@_scalar-product_@, @_rep-scalar-product_@, R1, Rep1, R2, Rep2>
  friend constexpr delta_quantity auto scalar_product(const quantity<R1, Rep1>& lhs, const quantity<R2, Rep2>& rhs);

  template<auto R1, typename Rep1, auto R2, typename Rep2>
    requires $ProductOf$<@_vector-product_@, @_rep-vector-product_@, R1, Rep1, R2, Rep2>
  friend constexpr delta_quantity auto vector_product(const quantity<R1, Rep1>& lhs, const quantity<R2, Rep2>& rhs);

  template<auto R1, typename Rep1, auto R2, typename Rep2>
    requires $ProductOf$<@_tensor-product_@, @_rep-tensor-product_@, R1, Rep1, R2, Rep2>
  friend constexpr delta_quantity auto tensor_product(const quantity<R1, Rep1>& lhs, const quantity<R2, Rep2>& rhs);

  template<auto R1, typename Rep1, auto R2, typename Rep2>
    requires $ProductOf$<@_inner-product_@, @_rep-inner-product_@, R1, Rep1, R2, Rep2>
  friend constexpr delta_quantity auto inner_product(const quantity<R1, Rep1>& lhs, const quantity<R2, Rep2>& rhs);

  template<auto R, typename Rep>
    requires $PartOf$<@_real_@, math::real, R, Rep>
  friend constexpr delta_quantity auto real(const quantity<R, Rep>& q);

  template<auto R, typename Rep>
    requires $PartOf$<@_imag_@, math::imag, R, Rep>
  friend constexpr delta_quantity auto imag(const quantity<R, Rep>& q);

  template<auto R, typename Rep>
    requires $PartOf$<@_modulus_@, math::modulus, R, Rep>
  friend constexpr delta_quantity auto modulus(const quantity<R, Rep>& q);

  template<auto R, typename Rep>
    requires $PartOf$<@_conj_@, @_rep-conj_@, R, Rep>
  friend constexpr delta_quantity auto conj(const quantity<R, Rep>& q);

  // the result is in one
  // Preconditions: q isn't a zero vector
  template<auto R, typename Rep>
    requires $UnitVectorOf$<R, Rep>
  friend constexpr delta_quantity auto unit_vector(const quantity<R, Rep>& q);

  // hosted only; the result is in the unit of re and has the representation complex<common_type_t<Rep1, Rep2>>
  // Constraints: common_type_t<Rep1, Rep2> is a floating-point type
  template<auto R1, typename Rep1, auto R2, typename Rep2>
    requires $ComplexOf$<R1, Rep1, R2, Rep2>
  friend constexpr delta_quantity auto make_complex(const quantity<R1, Rep1>& re, const quantity<R2, Rep2>& im);
};

}
```

The result of `scalar_product(q1, q2)` has the quantity specification
`scalar_product(get_quantity_spec(R1), get_quantity_spec(R2))` and the unit
`get_unit(R1) * get_unit(R2)`, and likewise for the other products. The result of `real(q)`,
`imag(q)`, `modulus(q)`, and `conj(q)` has the unit of `q`.


# Relation to P3045R11

Nothing that [@P3045R11_PRE] proposes is removed or changes meaning, and its wording changes only
where this paper extends `$EquationSpec$` and `unit_of`:

- `operator*`, `operator/`, `inverse()`, `pow<>()`, `sqrt()`, and `cbrt()` keep the restrictions
  of [@P3045R11_PRE] for vectors and tensors.
- A quantity still doesn't convert to a quantity of another character, even with
  `quantity_cast`, and two such quantities still have no common quantity specification. Every
  operation of this paper produces a quantity of the character of the table in [The operations],
  and the character rule then applies to it like to any other quantity.
- `magnitude()` of a quantity and `magnitude(QS)` of a quantity specification are those of
  [@P3045R11_PRE], including the implicit conversion of `magnitude(V)` to the nearest scalar
  quantity above `V`. This paper adds only how the magnitude of a product converts (see
  [The quantity of a result]).
- The quantity specifications of this paper extend `$EquationSpec$` of [@P3045R11_PRE], so that a
  named quantity may be defined with them, as it may be with `magnitude(QS)` already.
- `unit_of<U, QS>` of [@P3045R11_PRE] requires the quantity specification of `U` to convert
  implicitly to `QS`. `kind_of<dimensionless>`, the quantity specification of `one`, converts to
  a unit-vector specification only explicitly (see [Unit vectors]), so under that wording
  `isq::torque_direction[one]` would be ill-formed. For a unit-vector specification, `unit_of`
  also accepts a unit whose quantity specification converts implicitly to the kind of `QS`: `one`
  and `percent` are units of `isq::torque_direction`, and `rad` isn't. This changes `unit_of`
  only for the specifications that this paper introduces.

The ISQ definitions in [ISQ definitions] are examples. [@P3045R11_PRE] doesn't propose a system of
quantities, so they belong to the paper that proposes one.

The examples use the spelling of [@P3045R11_PRE]. Under [@P4185R3_PRE], proposed in the same
mailing, a plain `QS[U]` of a vector specification is ill-formed, a vector is written
`delta<QS>[U]`, and a vector of a quantity kind `delta<U>(v)`.

[@P4411R1_PRE] proposes non-negative quantity specifications. [@MP-UNITS] makes
`magnitude(QS)` and `modulus(QS)` non-negative, and declares `isq::apparent_power`,
`isq::apparent_impedance`, and `isq::apparent_admittance` `non_negative`. A scalar product and a
real or an imaginary part are signed. If both papers are adopted, a revision of the later one
will say so.


# Implementation experience

The design is implemented in a branch of [@MP-UNITS] off its version 3 line, not yet public. The
branch defines the ISQ of [@MP-UNITS] with the operations and has compile-time tests of every rule
in [The quantity of a result]. The examples in this paper were compiled with GCC 15 against that
branch, and the representation lookup was checked with a user vector type that provides only
`dot()` and `cross()` member functions.

[@MP-UNITS-SAFETY] describes the motivation for these operations in more detail.


# Open questions

## The directions of torque and pressure

`isq::torque_direction` and `isq::surface_normal_direction` (see [ISQ definitions]) are both
defined as `unit_vector(displacement)`, so the unit vectors of many vectors convert implicitly to
either of them. For example, those of _force_, _velocity_, _acceleration_, _momentum_, and
_electric field strength_ do. Others convert only explicitly (for example, those of
_angular velocity_, _magnetic flux density_, and _magnetic moment_), only with `quantity_cast`
(for example, that of _position vector_), or not at all (for example, those of
_moment of force_, _angular momentum_, and the _Poynting vector_). Should a
direction be tied to a named vector quantity, such as the axis of rotation or the normal of a
surface? [@P4407R0_PRE] proposes typed components along declared axes, and may be the better home
for the axis.

## Conversions through a kind

A quantity of `isq::moment_of_force` converts implicitly to a `quantity<N * m>`, as every quantity
converts to its kind, and that kind converts implicitly to `isq::mechanical_work` (see
[The quantity of a result]). The two steps make a _moment of force_ a _mechanical work_, which the
direct conversion refuses even explicitly. A product operation on kinds keeps the operation, but
`N * m` is the kind of a plain product. This paper doesn't close that path.

The same path opens in other places. `magnitude(isq::moment_of_force)` converts implicitly to
`kind_of<isq::energy>`, through the product of the magnitudes of its operands, and from there to
`isq::mechanical_work`. A product operation converts only to a quantity whose equation names it,
so another equation of a quantity reaches it only through the kind.
`isq::electric_charge * vector_product(isq::velocity, isq::magnetic_flux_density)`
($F = q v \times B$, item 6-21 of [@ISO80000] part 6) doesn't convert to `isq::force`, and
`vector_product(isq::magnetic_moment, isq::magnetic_flux_density)` ($\tau = m \times B$) doesn't
convert to `isq::moment_of_force`, even with `quantity_cast`, while each converts implicitly to
its kind and from there to the target. `isq::torque * isq::rotational_frequency`, which lacks the
$2\pi$ of $P = T\omega$, doesn't convert to `isq::mechanical_power` directly, but it converts
implicitly to a `quantity<W>` and from there to `isq::mechanical_power`. A torque of 5 N m at
`isq::rotational_frequency(10. / s)` gives 50 W, where the power is about 314 W.
`isq::torque * isq::angular_frequency`, $P = T\omega$, converts to `isq::power` only explicitly.

A rule that a direct conversion is never stricter than the path through the kind would remove
these differences. This paper doesn't adopt such a rule, as it would make
`vector_product(isq::force, isq::position_vector)` and
`scalar_product(isq::force, isq::displacement)` convert implicitly to `isq::moment_of_force` and
`isq::torque`, which they reach through their kinds as well, though [Operations on quantities] and
[The quantity of a result] say that they never convert.

## Power and energy of a rotation

$W = T\theta$ and $P = T\omega$ convert only explicitly (see [The quantity of a result]), as no
named quantity has these equations. Should a system of quantities add a rotational work, power,
and kinetic energy, so that these conversions become implicit?

## The scalar product of complex operands

Item 2-18.11 of [@ISO80000] part 2 writes the scalar product as $a \cdot b = \sum_i a_i b_i$,
which is bilinear, and the vector items of part 2 don't mention complex coordinates.
`scalar_product()` of `cartesian_vector` of [@MP-UNITS] conjugates its first operand. The type of
the result is the same either way, so for complex operands `scalar_product(a, b)` and
`scalar_product(b, a)` may differ in value. Should the library require one of the two definitions
from a representation?

## Implicit conversions that aren't transitive

`scalar_product(isq::force, isq::displacement)` converts implicitly to `isq::mechanical_work`, and
`isq::mechanical_work` converts implicitly to its parent `isq::energy`, but the scalar product
converts to `isq::energy` only explicitly. The engine compares it with the equation of `isq::energy`
(a product of scalars), so it relaxes the scalar product to a product of magnitudes, which is an
explicit step. The same holds for `scalar_product(isq::force, isq::velocity)` and `isq::power`.
Also, `isq::mass * pow<2>(isq::length) / pow<2>(isq::time)` converts implicitly to
`isq::mechanical_energy`, a child of `isq::mechanical_work`, but not to `isq::mechanical_work`.
Should the conversion find the named quantity defined with the operation and go through it?

## Comparing the two orders of a vector product

`vector_product(lever, force) == -vector_product(force, lever)` compiles and is `true`, while
`vector_product(lever, force) + vector_product(force, lever)` doesn't compile. The common
quantity specification of the two is `force * length`, to which neither converts implicitly.
For operands that are quantity kinds of `m` and `N`, as in
`vector_product(vec{3., 2., 1.} * m, vec{1., 2., 3.} * N)`, neither `==` nor `+` compiles: the
kind of `N` is that of the scalar `mass * length / pow<2>(time)`, and the two orders have no
common quantity specification. Should the two orders of named operands have none either, so that
they can't be compared, or should the comparison stay because the negated value is the same
physical vector?

## Public customization point objects

[Customization points for representation types] specifies exposition-only helpers. Making them
public objects in `std::math`, next to `math::real` and `math::magnitude`, would let generic code
compute a scalar product of two representations that provide only member functions. Their names
need a decision either way: `inner_product` is also an algorithm of `<numeric>`, and the fallbacks
to `dot` and `cross` accept functions of those names that may mean something else for a
user-defined type.

## The names of the part properties

"Names that need a decision" of [@P3045R11_PRE] lists renaming `math::real`, `math::imag`, and
`math::modulus` to `real_part`, `imag_part`, and `complex_modulus` as one option. That would
collide with the properties `real_part<>` and `complex_modulus<>` of this paper.

## The representation of `make_complex()`

`make_complex()` always returns a `complex<common_type_t<Rep1, Rep2>>`, so it is available only in
a hosted implementation, and a complex representation of another library can't be the result.
[@P3045R11_PRE] requires a complex representation to be constructible from its real and its
imaginary part, which could choose the result type instead. How the user would name that type
isn't settled.

## Scalar products if absolute quantities are adopted

If absolute quantities [@P4185R3_PRE] are adopted, a vector quantity that isn't a point is a delta,
and a product with a delta operand is a delta, so every scalar product of two vectors is a delta.
For `isq::mechanical_work`, `scalar_product(force, displacement)`, that is the intent: the work of
a force is a change of energy. The ISQ definitions of this paper (see [ISQ definitions]) also make
`isq::mechanical_power` `scalar_product(force, velocity)`, `isq::torque`
`scalar_product(moment_of_force, torque_direction)`, and `isq::pressure`
`scalar_product(force, surface_normal_direction) / area`, where each direction is a unit vector, a
vector and so a delta. All three results are deltas. A pressure is a textbook absolute, though:
absolute pressure is measured from vacuum, a true zero. A torque is signed relative to its axis, as
an electric current is to its reference direction, and is an amount as well. With a force `F`, a
unit normal `n`, and an area `A`:

```cpp
quantity<isq::pressure[Pa]> p1 = scalar_product(F, n) / A;               // ill-formed: a delta
quantity<isq::pressure[Pa]> p2 = (scalar_product(F, n) / A).absolute();  // OK
```

The options are:

- Accept the `.absolute()`. A scalar product with a unit vector is the component of the other
  operand along it, and a component of a vector delta is a delta along an axis. A pressure, a
  torque, and a mechanical power then join the Kalman gain in the costs that [@P4185R3_PRE] lists
  for its rule.
- Treat a unit vector as a direction rather than a change, so that a scalar product with one keeps
  the abstraction of its other operand. A torque then has the abstraction of the moment of force,
  and a pressure that of the force, so both stay deltas: the other operand is a vector, so this
  alone changes no result.
- Compute a pressure from a size: `magnitude(F) / A` is an absolute, because `magnitude()` measures
  a size, but this paper converts it to `isq::pressure` only explicitly, it loses the sign of the
  normal component, and it is the normal component only for a force normal to the surface.
- Choose another of the rules that [@P4185R3_PRE] lists for products and quotients of two deltas:
  where two deltas cancel, a scalar product of two vector deltas is an absolute, so a pressure, a
  torque, and a power are absolutes, and so is a mechanical work.

## Operations left out

The tensor product of two tensors (a tensor of the fourth order, item 2-18.22 of [@ISO80000] part
2), the argument of a complex quantity (item 2-15.5), a free function `magnitude(q)` for
quantities, and the member functions `q.real()`, `q.imag()`, and `q.modulus()` of `quantity` are
not proposed.


# Proposed polls

## SG6

1. SG6 wants the character-specific operations of this paper (`scalar_product`,
   `vector_product`, `tensor_product`, `inner_product`, `inner_quotient`, `real`, `imag`,
   `modulus`, `conj`, `make_complex`) on quantity specifications, with a result that records the
   operation and its operands.
2. SG6 wants the same operations, except `inner_quotient`, on quantities.
3. SG6 wants a complex quantity specification to name its real part, its imaginary part, and its
   modulus with `real_part<>`, `imaginary_part<>`, and `complex_modulus<>`.
4. SG6 wants the vector product, the tensor product, and the inner product to give a different
   quantity for each order of their operands, with no conversion between the two, even explicit.
5. SG6 wants the conversion between a scalar product and the product of the magnitudes of its
   operands to be explicit.
6. SG6 wants a `unit_vector` operation on quantity specifications and on quantities, so that a
   system of quantities can define _torque_ and _pressure_ with a scalar product, as [@ISO80000]
   does.


# Acknowledgements

Special thanks and recognition goes to [The C++ Alliance](https://cppalliance.org) for supporting
Mateusz's membership in the ISO C++ Committee and the production of this proposal.

---
references:

- id: P3045R11_PRE
  citation-label: P3045R11
  author:
    - family: Pusz
      given: Mateusz
  title: "Quantities and units library"
  URL: <https://wg21.link/p3045r11>
- id: P4407R0_PRE
  citation-label: P4407R0
  author:
    - family: Pusz
      given: Mateusz
  title: "Component Vectors of Vector Quantities"
  URL: <https://wg21.link/p4407r0>
- id: P4185R3_PRE
  citation-label: P4185R3
  author:
    - family: Pusz
      given: Mateusz
  title: "Absolute Quantities"
  URL: <https://wg21.link/p4185r3>
- id: P4411R1_PRE
  citation-label: P4411R1
  author:
    - family: Pusz
      given: Mateusz
  title: "Non-Negative Quantity Specifications"
  URL: <https://wg21.link/p4411r1>
- id: AU-EIGEN
  citation-label: Au Eigen
  title: "Au: Eigen compatibility (au/compatibility/eigen.hh)"
  URL: <https://github.com/aurora-opensource/au/blob/main/au/compatibility/eigen.hh>
- id: NHOLTHAUS-EIGEN
  citation-label: nholthaus/units Eigen
  title: "nholthaus/units: Eigen interoperability (include/units/eigen.h)"
  URL: <https://github.com/nholthaus/units/blob/main/include/units/eigen.h>
- id: ISO80000
  citation-label: ISO/IEC 80000
  title: "ISO/IEC 80000: Quantities and units"
  URL: <https://www.iso.org/standard/76921.html>
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

---
