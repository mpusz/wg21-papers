---
title: "Component Vectors of Vector Quantities"
document: P4407R0
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


# Introduction

[@P3045R10_PRE] supports vector quantities. A _velocity_ can be stored in one `quantity` with a
vector representation, and the library tracks its unit and its character. It gives no typed
access to a single coordinate. To read one, a user reaches into the representation and gets a
bare number:

```cpp
const std::quantity v = flight_velocity(cartesian_vector{30.0, 10.0, -2.0} * km / h);
const double climb = v.numerical_value_in(km / h)[2];  // no unit, no axis
```

The type of `climb` doesn't say that it is the vertical coordinate or that it is in kilometers
per hour, and the compiler accepts adding it to the forward coordinate.

This paper proposes to make the component vectors of a vector quantity typed quantities:

- a `component_vectors` customization point and a `vector_axes` class template, which declare
  the quantity specifications of the axes a vector quantity decomposes into,
- `get<I>` and `get<QS>`, which return one component vector as a quantity of its axis,
- the tuple protocol for a decomposable quantity, so structured bindings work, and
- construction of the whole from its component vectors, given as separate arguments or as one
  value that supports the tuple protocol.

A vector quantity whose axes aren't declared decomposes too, with weaker guarantees (see
[Undeclared decomposition](#undeclared)).

These are additions to [@P3045R10_PRE], with one exception. [@P3045R10_PRE] makes `quantity` a
structural type with a public exposition-only data member, so `auto [n] = q;` is valid for every
quantity that follows that exposition, as `quantity` in [@MP-UNITS] does. The `std::tuple_size`
specialization proposed here makes it ill-formed for a decomposable vector quantity whose
representation has more than one element (see [Open questions](#open-questions)).

The synopsis of [@P3045R10_PRE] lists access to the component vectors of a vector quantity among
the features it doesn't propose. This paper asks SG6 for design direction and has no wording. The
master branch of [@MP-UNITS] implements the design with its own names, and the V3 branch
implements it with the names of [@P3045R10_PRE] (see
[Implementation experience](#implementation)).

The examples use the names of [@P3045R10_PRE]. `cartesian_vector` is the vector
representation of [@MP-UNITS]. Any representation that meets
[the requirements below](#representation) is expected to work the same way.

If absolute quantities [@P4185R3_PRE] are adopted, a quantity of a vector quantity specification
is never an absolute, and `flight_velocity[km / h]` is ill-formed. The vector types in this paper,
those of the component vectors included, are then written with the delta of the specification, as in
`quantity<delta<flight_velocity>[km / h], cartesian_vector<double>>` and `quantity<delta<north>[m]>`
(see [Typed vectors in linear algebra](#typed-linear-algebra)). A value is created from a delta, as
in `flight_velocity(delta<km / h>(cartesian_vector{30.0, 10.0, -2.0}))`, and
`cartesian_vector{30.0, 10.0, -2.0} * km / h` is ill-formed. A component vector is a delta along
its axis: `get<vertical_velocity>(v)` and `get<delta<vertical_velocity>>(v)` return the same
`quantity<delta<vertical_velocity>[km / h], double>`, and that type `Q` satisfies
`quantity_of<Q, delta<vertical_velocity>>` but not `quantity_of<Q, vertical_velocity>`. A simple
quantity such as `30 * km / h` is an absolute, which never converts to a vector specification, so it
fits no axis, and [A simple quantity fits every axis](#simple-quantities) applies to
`delta<km / h>(30.)` instead.


# Motivation {#motivation}

## An axis is a number today {#bare-number}

Code that builds a velocity from three measured coordinates writes them in positional order:

```cpp
// meant: forward 30, lateral 10, vertical -2
const std::quantity v = flight_velocity(cartesian_vector{30.0, -2.0, 10.0} * km / h);
```

The two last values are swapped, and the program compiles. The vertical coordinate now holds
10 km/h instead of -2 km/h, and the library can't detect it. In [@P3045R10_PRE] the quantity is
typed, but the elements of its `cartesian_vector<double>` are plain `double` values. This proposal
still accepts that line. With named axes, the same swap of axis-typed values doesn't compile (see
[Construction from component vectors](#construction)).

## Typed vectors in linear algebra {#typed-linear-algebra}

Libraries that put quantities into linear algebra need the component vectors as quantities. In
[@TYPED-LA], the state of a Kalman filter is a heterogeneous column vector, for example:

```cpp
using position = std::quantity<ned_displacement[m], cartesian_vector<double>>;
using state = column_vector<double, std::quantity<north[m]>, std::quantity<east[m]>, std::quantity<down[m]>>;
```

The filter moves values between the two types in both directions. With typed component vectors
and the axes of `ned_displacement` declared as `north`, `east`, and `down`, `state` can be built
from a `position`, and a `position` from a `state`, and a swapped axis is a compile-time error.

Earlier requests for the same thing came from the linear algebra side: a customization point
for the elements of a representation in [@MP-UNITS-244], and support for quantities with a
vector representation in [@MP-UNITS-439], which also points to [@WITHOPF].


# Proposal {#proposal}

## Declaring the axes {#declaring}

A user gives each axis its own quantity specification and declares the decomposition by
specializing `component_vectors` for the whole:

```cpp
// the whole
inline constexpr struct flight_velocity :
    std::named_quantity_spec<std::isq::velocity> {} flight_velocity;

// the axes
inline constexpr struct forward_velocity :
    std::named_quantity_spec<std::isq::velocity, std::subkind> {} forward_velocity;
inline constexpr struct lateral_velocity :
    std::named_quantity_spec<std::isq::velocity, std::subkind> {} lateral_velocity;
inline constexpr struct vertical_velocity :
    std::named_quantity_spec<std::isq::velocity, std::subkind> {} vertical_velocity;

template<>
struct std::component_vectors<flight_velocity> :
    std::vector_axes<forward_velocity, lateral_velocity, vertical_velocity> {};
```

The axes are listed in coordinate order. The rules are checked at compile time:

1. The whole is a vector quantity.
2. There are at least two axes.
3. Each axis is a vector quantity. A component vector lies along one axis, so a 1D vector
   represents it.
4. No axis is a `kind_of<>` specification.
5. All axes share the hierarchy root of the whole.
6. Each axis is a distinct quantity kind, declared with `subkind`.
7. No axis has the kind of the whole.
8. The representation states its length at compile time through `std::tuple_size`, and the
   number of axes equals that length.

`component_vectors` checks rule 1 where it is specialized. `vector_axes` checks rules 2, 3, 4, and
6, and that the axes share one hierarchy root, where the `component_vectors` specialization is
defined. An invalid axis list is therefore ill-formed at the point of declaration. The remaining
rules need the whole, which `vector_axes` doesn't see, or the representation, and they are checked
when a quantity is decomposed.

Without `subkind`, the three axes would all have the kind of _velocity_, and the library would let a
user add the forward axis to the vertical one. With it, same-axis arithmetic works and cross-axis
arithmetic doesn't compile:

```cpp
const auto [forward, lateral, vertical] = v;

const std::quantity total = forward + forward;  // OK
// const auto wrong = forward + vertical;       // error: different kinds
```

## Access to a component vector {#access}

`get<I>` returns the component vector at index `I`, and `get<QS>` returns the component vector
of the axis `QS`. Both are hidden friends of `quantity`:

```cpp
const std::quantity forward = get<0>(v);                 // a forward_velocity in km/h
const std::quantity climb = get<vertical_velocity>(v);   // same as get<2>(v)
```

An index past the last axis, or a quantity specification that isn't one of the declared axes, is
rejected at compile time.

A decomposable quantity also specializes `std::tuple_size` and `std::tuple_element`, so it
supports structured bindings and generic code that reads elements through `std::tuple_size` and
an unqualified `get`:

```cpp
static_assert(std::tuple_size_v<decltype(v)> == 3);
static_assert(std::quantity_of<std::tuple_element_t<2, decltype(v)>, vertical_velocity>);
```

As no quantity object exists for a single component vector, `get` returns one by value.
`auto& [a, b, c] = v;` compiles, but unlike with a `std::tuple`, for a non-const `v` assigning to
`a` doesn't change `v`. The `&` makes the hidden variable a reference to `v`, and each name refers
to a temporary returned by `get`. To change one coordinate, a user builds a new whole (see
[Construction from component vectors](#construction)).

## The representation of a component vector {#one-dimensional}

The representation of a component vector is the element type of the vector representation, and
its numerical value is the numerical value of the coordinate along its axis:

```cpp
static_assert(std::same_as<decltype(get<0>(v))::rep, double>);
const double climb_rate = get<vertical_velocity>(v).numerical_value_in(km / h);
```

A component vector is a vector quantity stored in a scalar, so the rules of [@P3045R11_PRE] for
vectors apply to it: the product of two component vectors, `pow<2>()` of one, and its conversion
to a scalar quantity such as `isq::speed` are ill-formed. Its size is `magnitude()`. [@MP-UNITS]
also rejects `abs()` of a component vector, as [@P4487R0] recommends, and the products of vector
quantities are proposed there.

## Construction from component vectors {#construction}

The whole can also be constructed from one component vector per axis, each checked against the
axis of its position:

```cpp
using velocity = std::quantity<flight_velocity[km / h], cartesian_vector<double>>;

const velocity v = {forward_velocity(30 * km / h), lateral_velocity(10 * km / h), vertical_velocity(-2 * km / h)};

// error: position 1 expects a lateral_velocity
// const velocity swapped = {forward_velocity(30 * km / h),
//                           vertical_velocity(-2 * km / h),
//                           lateral_velocity(10 * km / h)};
```

Each argument must be implicitly convertible to the component vector of its position. This
rejects a swapped pair of axis-typed arguments, a number (for a whole whose unit is not `one`), and
a quantity of the whole's own specification or of `isq::velocity`, neither of which converts
implicitly to an axis. The constructed type fixes the unit, so each argument is converted into it
under the ordinary conversion rules, and a truncating conversion is rejected as anywhere else.

The component vectors can also be passed as one value of a type that specializes
`std::tuple_size`, with the same rules applied element by element:

```cpp
const velocity from_tuple = std::tuple{forward_velocity(30 * km / h), lateral_velocity(10 * km / h), vertical_velocity(-2 * km / h)};

const position from_state = some_state;  // the column_vector of the motivating example
```

The elements are read from a const lvalue: through a member `get<I>()` when that call is valid,
otherwise through `get<I>` found by argument-dependent lookup. `std::apply` and
`std::make_from_tuple` can't do this job. They read the elements through `std::get`, which users
may not overload, and since C++23 they are constrained on the exposition-only _`tuple-like`_
concept ([tuple.like]{.sref}), which admits only the standard library's own types. A third-party
vector is rejected, and generic code writes its own `index_sequence` helper.

Three kinds of argument are not composed element by element, even when they support the tuple
protocol:

- a `quantity`, which converts as a whole under the conversion rules of quantity specifications,
- a $QuantityLike$ type, which converts as a whole through `quantity_like_traits`, and
- a value convertible to the representation, which is left to the value constructors and is
  rejected where there are none (only a whole of unit `one` has them).

The first matters most because a decomposable quantity supports the tuple protocol itself, and
converting it one axis at a time would skip the rules that apply to it as a whole.

## Undeclared decomposition {#undeclared}

Declaring the axes is optional. A vector quantity whose specification has no `component_vectors`
specialization still decomposes, and it still composes when its representation has at least two
elements. Each component vector then has the kind of the whole:

```cpp
const std::quantity w = std::isq::velocity(cartesian_vector{30.0, 10.0, -2.0} * km / h);

const auto [x, y, z] = w;  // three 1D vectors of the kind of isq::velocity
const std::quantity<std::isq::velocity[km / h], cartesian_vector<double>> back = {x, y, z};
```

A component vector gets the kind of the whole and not its specification. The kind of _velocity_
is the kind of _speed_, a scalar quantity, but a kind admits every character, so the component
vector stays a 1D vector. Like a simple quantity, it converts implicitly to every quantity of
its hierarchy. That includes the whole itself when the representation converts from one element, as
`cartesian_vector` does, which puts the value on the first axis.

This mode keeps the unit, the character, the number of component vectors, and the compile-time
bound on the index. It can't tell the axes apart, so `get<QS>` isn't available, any order of
component vectors is accepted on construction, and adding two different axes compiles.

## Requirements on the representation {#representation}

Decomposition uses the vector representation that already backs the quantity. On top of the
requirements of [@P3045R10_PRE] for a vector representation, the type must:

- give access to an element by a compile-time index: through a member `get<I>()` when that call
  is valid, otherwise through `get<I>` found by argument-dependent lookup, and otherwise through
  `rep[I]`,
- state its length at compile time through `std::tuple_size`, and
- be constructible with braced initialization from one element per axis, if the whole is to be
  built from component vectors.

Braced initialization is the form that accepts `blaze::StaticVector`, whose only element-wise
constructor takes a `std::initializer_list`. `cartesian_vector`, `Eigen::Vector3d`, `glm::dvec3`,
and `blaze::StaticVector<double, 3>` all qualify. `cartesian_vector` and Blaze provide the tuple
protocol themselves, and [@MP-UNITS] adds it for Eigen and GLM. A vector whose length is known only
at run time, such as `Eigen::VectorXd`, is not decomposable in either mode. A compile-time index
can't be checked against its length.

## Points {#points}

The proposal covers deltas only. A point, a `quantity` with a point reference, is not decomposable,
and it is not constructed from component vectors.


# Design decisions {#decisions}

## The axes as a customization point {#cp}

The axes are declared next to the whole, not inside its definition. A decomposition describes a
coordinate frame, and the same physical quantity can be resolved in more than one frame. A body
frame and a north-east-down frame decompose the same velocity into different axes. With a
customization point, each frame is a separate whole, such as `body_velocity` and `ned_velocity`,
and the specification of `isq::velocity` stays as ISO 80000-3 defines it.

Decomposing a `flight_velocity` quantity where the specialization isn't reachable makes the program
ill-formed, no diagnostic required ([temp.expl.spec]{.sref}). In practice, that code silently uses
the undeclared mode. The proposal keeps the rule of [namespace.std]{.sref} that a specialization
must depend on a program-defined type. A user declares axes for a whole of their own, so
`component_vectors<flight_velocity>` is allowed and `component_vectors<isq::velocity>` is not. An
ISQ quantity decomposes in the undeclared mode. Wording will need to say that a quantity
specification object of a program-defined type satisfies the rule.

## The name `component_vectors` {#name}

Clause 18 of ISO 80000-2:2019 [@ISO80000-2] calls $a_1\mathbf{e}_1$, $a_2\mathbf{e}_2$, and
$a_3\mathbf{e}_3$ the component vectors of a vector $\mathbf{a}$ with respect to the base vectors,
and $a_1$, $a_2$, and $a_3$ its coordinates. It also says:

> The word "component" shall not be used alone, since it might be confused with "component vector".

`get` returns a component vector, and its value along the axis is a coordinate. This is why the
customization point is named `component_vectors`.

## Axes as distinct kinds {#distinct-kinds}

Each axis is marked `subkind` for the reason given in [Declaring the axes](#declaring). It also
prevents a second hazard. In the example, the axes are siblings of the whole in the hierarchy. An
axis declared as a child of `flight_velocity` without `subkind` would convert implicitly to the
whole, and one component vector could be passed where the whole vector is expected. As a separate
kind, an axis converts implicitly to nothing outside its own subtree.

## Access by a compile-time index {#get}

The index is a template argument, as in the standard library. `std::tuple` is indexed only
through `std::get<I>`, and for `std::array` only `std::get<I>` checks the index at compile time.

## A subscript operator {#subscript}

A `quantity::operator[]` taking a runtime index would have to return every component vector with
one type. At best, it would return what the undeclared mode returns, a quantity of the kind and
unit of the whole, and it couldn't say whether the result is the forward or the vertical axis. A
subscript that takes a compile-time constant, such as `std::integral_constant<std::size_t, 2>{}`,
could select the type, but it is then `get<I>` written differently.

## Implicit construction from component vectors {#implicit}

The constructor from separate component vectors and the constructor from one value of component
vectors are both implicit. Every element must already convert implicitly to the component vector
of its position, so `explicit` would add no check that the element conversions don't already
make. It would only make `return {fwd, lat, vert};` and passing a typed state vector to a function
taking the whole more verbose.

## A simple quantity fits every axis {#simple-quantities}

A quantity of a unit alone, such as `30 * km / h`, converts implicitly into every quantity of
its hierarchy. It therefore fits every position, and three such arguments compile in any order:

```cpp
const velocity unchecked = {30 * km / h, 10 * km / h, -2 * km / h};
```

[@P3045R10_PRE] treats a simple quantity this way everywhere. A simple quantity opts out of quantity
kind safety, and the constructor doesn't treat it differently than any other function taking a typed
quantity. The other direction is explicit. As an axis is a kind of its own, a `forward_velocity`
converts to `quantity<km / h>` only through an explicit conversion.

The component vectors `x`, `y`, and `z` of the [undeclared decomposition](#undeclared) fit every
axis of a declared whole in the same way, so `velocity back2 = {x, y, z};` compiles in any order.

## No conversion operator from a decomposable quantity {#no-conversion-operator}

The reverse of construction from one value would be a conversion operator from the whole to any type
that can be built from its component vectors. It isn't proposed. A typed vector library, like
[@TYPED-LA], already constructs its vector from any value that models the tuple protocol. A
decomposable quantity models it, and that direction works without help from `quantity`. A
conversion operator would give copy-initialization two equally good conversions, the constructor of
the target and the operator. A prototype in [@MP-UNITS] made `state s = v;` and passing `v` to a
function taking a `state` ambiguous. The cases it would add are types constructible from the
separate component vectors but not from one value that supports the tuple protocol, such as
`std::tuple`, whose converting constructors accept only _`tuple-like`_ types. A structured binding
covers them:

```cpp
const auto [forward, lateral, vertical] = v;
const std::tuple vectors{forward, lateral, vertical};
```


# Open questions {#open-questions}

1. **Siblings that share axes.** Two wholes may declare the same axes. A component vector doesn't
   record which whole it came from, so a whole can be built from the component vectors of a sibling,
   although the sibling itself doesn't convert:

   ```cpp
   inline constexpr struct commanded_velocity :
       std::named_quantity_spec<std::isq::velocity> {} commanded_velocity;

   template<>
   struct std::component_vectors<commanded_velocity> :
       std::vector_axes<forward_velocity, lateral_velocity, vertical_velocity> {};

   using commanded = std::quantity<commanded_velocity[km / h], cartesian_vector<double>>;

   static_assert(!std::constructible_from<commanded, velocity>);
   const commanded c = {get<0>(v), get<1>(v), get<2>(v)};  // compiles
   ```

   We consider this correct. Sharing the axes states that both wholes are measured in
   the same frame. They differ in what they describe, here the flight velocity and the
   commanded one. The alternative is to forbid sharing axes between distinct wholes.
2. **Points.** Should a point decompose into points along each axis? That needs an origin per
   axis, and we have no use case that requires it yet.
3. **Writing one component vector.** Component vectors are returned by value. Changing one
   coordinate means composing a new whole. A proxy reference type would allow
   `get<1>(v) = ...`, at the cost of a type that behaves differently from every other
   `quantity`. We prefer values.
4. **A one-element representation.** In the undeclared mode, a representation with one element,
   such as `glm::dvec1`, decomposes into one component vector but doesn't compose, as composition
   needs at least two. For such a quantity, `auto [n] = q;` stays valid and binds `n` to the
   component vector instead of the representation. The alternative is to require at least two
   elements in the undeclared mode as well, as rule 2 does for declared axes.
5. **A component vector converting to the whole.** In the undeclared mode, a component vector
   converts implicitly to the whole when the representation converts from one element. With
   `cartesian_vector`, the whole built from `z` holds the vertical coordinate on the first axis.
   With GLM and Blaze, the conversion is only explicit, and it copies the value to every axis.
   With Eigen, the explicit conversion doesn't compile. The alternative is to forbid the
   conversion from a component vector to a vector whole.


# Implementation experience {#implementation}

The master branch of [@MP-UNITS] implements the whole proposal. None of it is released yet, and
it is scheduled for 2.6.0. Construction from one value that supports the tuple protocol was
contributed by François Carouge in [@MP-UNITS-862]. The name `component_vectors`, rule 8, and the
reading order of the elements of a representation landed in [@MP-UNITS-864]. The rest was already
on master.

Declared axes and construction from one value are tested with `cartesian_vector`. The undeclared
mode and construction from separate component vectors are tested with the Eigen, GLM, and Blaze
backends.

The V3 branch of [@MP-UNITS], which uses the names of [@P3045R10_PRE], holds the master branch,
so it implements the whole proposal as well, and excludes points as described in
[Points](#points).


# Straw polls {#polls}

1. _SG6 recommends adding the decomposition of a vector quantity into typed component vectors, with
   `component_vectors`, `vector_axes`, `get`, and the tuple protocol as proposed in this paper, to
   the quantities and units library._
2. _SG6 recommends constructing a vector quantity from its component vectors, given as separate
   arguments or as one value that supports the tuple protocol._
3. _SG6 recommends that a vector quantity without declared axes decompose into component vectors of
   the kind of the whole._


# Acknowledgements

Special thanks and recognition goes to [The C++ Alliance](https://cppalliance.org) for supporting
Mateusz's membership in the ISO C++ Committee and the production of this proposal.

The author would like to thank François Carouge for construction from one value of component
vectors and the Kalman filter use case, Johel Ernesto Guerrero Peña for the first proposal of a
customization point for the elements of a representation, and Alfredo Correa for asking about
vector quantities early on.

---
references:

- id: P3045R11_PRE
  citation-label: P3045R11
  author:
    - family: Pusz
      given: Mateusz
  title: "Quantities and units library"
  URL: <https://wg21.link/p3045r11>
- id: P4487R0
  citation-label: P4487R0
  author:
    - family: Pusz
      given: Mateusz
  title: "Vector, Tensor, and Complex Operations for Quantities"
  URL: <https://wg21.link/p4487r0>
- id: P3045R10_PRE
  citation-label: P3045R10
  author:
    - family: Pusz
      given: Mateusz
  title: "Quantities and units library"
  URL: <https://wg21.link/p3045r10>
- id: P4185R3_PRE
  citation-label: P4185R3
  author:
    - family: Pusz
      given: Mateusz
  title: "Absolute Quantities"
  URL: <https://wg21.link/p4185r3>
- id: ISO80000-2
  citation-label: ISO 80000-2
  title: "ISO 80000-2:2019 Quantities and units - Part 2: Mathematics"
  URL: <https://www.iso.org/standard/64973.html>
- id: MP-UNITS
  citation-label: mp-units
  title: "mp-units - A Physical Quantities and Units library for C++"
  URL: <https://mpusz.github.io/mp-units>
- id: MP-UNITS-244
  citation-label: mp-units#244
  author: "Johel Ernesto Guerrero Peña"
  title: "feat: customization point to define the components of a QuantityValue"
  URL: <https://github.com/mpusz/mp-units/issues/244>
- id: MP-UNITS-439
  citation-label: mp-units#439
  author: "Alfredo Correa"
  title: "Vector quantities with units"
  URL: <https://github.com/mpusz/mp-units/issues/439>
- id: MP-UNITS-862
  citation-label: mp-units#862
  author: "François Carouge"
  title: "feat(core): vector quantity composes from a single value holding its components"
  URL: <https://github.com/mpusz/mp-units/pull/862>
- id: MP-UNITS-864
  citation-label: mp-units#864
  author:
    - family: Pusz
      given: Mateusz
  title: "feat(core): `component_vectors` names the axes, which match the representation exactly"
  URL: <https://github.com/mpusz/mp-units/pull/864>
- id: TYPED-LA
  citation-label: TypedLinearAlgebra
  author: "François Carouge"
  title: "TypedLinearAlgebra"
  URL: <https://github.com/FrancoisCarouge/TypedLinearAlgebra>
- id: WITHOPF
  citation-label: Withopf
  author: "Daniel Withopf"
  title: "Physical Units for Matrices"
  URL: <https://www.youtube.com/watch?v=J6H9CwzynoQ>

---
