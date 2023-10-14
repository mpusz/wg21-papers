---
title: "`std::quantity` as a numeric type"
document: P2982R0
date: today
audience:
  - SG6 Numerics
author:
  - name: Mateusz Pusz ([Epam Systems](http://www.epam.com))
    email: <mateusz.pusz@gmail.com>
  - name: Chip Hogg ([Aurora Innovation](https://aurora.tech/))
    email: <charles.r.hogg@gmail.com>
---


# Introduction

This document discusses the numeric and arithmetic aspects of the physical quantities and units
library. This subject is broader than it could be initially imagined. Arithmetic operations are not
only defined for user-facing types like `quantity` and `quantity_point`, but also for units and their
magnitudes, dimensions, quantity specifications, and references. Each has its own
requirements and constraints, and we will describe them in the following chapters.

_Note: The code examples presented in this paper may not exactly reflect the final interface
design that is going to be proposed in the follow-up papers. We are still doing some small
fine-tuning to improve the library._


# Terms and definitions

This document consistently uses the official metrology vocabulary defined in the [@ISO-GUIDE] and [@BIPM-VIM].


# Systems of Quantities

The physical units libraries on the market typically only focus on modeling one or more
systems of units. However, this is not the only system kind to model. Another, and maybe
even more important, system kind is a system of quantities.

## Dimension is not enough to describe a quantity

Most of the products on the market are aware of physical dimensions. However, a dimension is not
enough to describe a quantity. This has been known for a long time now.

A typical problem that most similar libraries struggle with is supporting quantities
of energy and a moment of force as independent, strong types. The problem here arises from the fact
that both of them have exactly the same dimension `L²MT⁻²`, but a totally different physical meaning.
As a result, it should not be possible to mix them in one quantity equation.

A similar question that we could ask ourselves is what should be the result of:

```cpp
auto res = 1 * Hz + 1 * Bq + 1 * Bd;
```

where:

- `Hz` (hertz) - a unit of frequency
- `Bq` (becquerel) - a unit of activity
- `Bd` (baud) - a unit of modulation rate

All of those quantities have the same dimension, namely `T⁻¹`, but it is probably not wise to allow
adding, subtracting, or comparing them, as they describe vastly different physical properties.

Last but not least, let's see the following implementation:

```cpp
class Box {
  quantity<square(si::metre)> base_;
  quantity<si::metre> height_;
public:
  Box(quantity<si::metre> l, quantity<si::metre> w, quantity<si::metre> h) : base_(l * w), height_(h) {}
  // ...
};

Box my_box(2 * m, 3 * m, 1 * m);
```

The above interface is far from being ideal. It does not provide any type-safety and enables
potentially severe errors caused by accidental reordering of the constructor's arguments.

It turns out that the above issues can't be solved correctly without proper modeling of
the system of quantities.

## Quantities of the same kind

The [@ISO-GUIDE] says:

> - Quantities may be grouped together into categories of quantities that are mutually comparable
> - Mutually comparable quantities are called quantities of the same kind
> - Two or more quantities cannot be added or subtracted unless they belong to the same category
>   of mutually comparable quantities
> - Quantities of the same kind within a given system of quantities have the same quantity dimension
> - Quantities of the same dimension are not necessarily of the same kind

Those provide answers to all the issues above. More than one quantity may be defined for the same
dimension:

- quantities of different kinds (e.g. frequency, modulation rate, activity, ...)
- quantities of the same kind (e.g. length, width, altitude, distance, radius, wavelength,
  position vector, ...)

Two quantities can't be added, subtracted, or compared unless they belong to the same quantity kind.

## System of quantities is not only about kinds

The [@ISO80000] specifies hundreds of different quantities. Plenty of various kinds
are provided, and often, each kind contains more than one quantity. It turns out that such quantities
form a [hierarchy of quantities of the same kind](https://mpusz.github.io/mp-units/2.0/users_guide/framework_basics/systems_of_quantities/#system-of-quantities-is-not-only-about-kinds).

For example, here are all quantities of the kind length provided in the [@ISO80000]:

- length,
- width, breadth,
- height, depth, altitude,
- thickness,
- diameter,
- radius,
- path length,
- distance,
- radial distance,
- wavelength,
- position vector,
- displacement,
- radius of curvature.

Each of the above quantities expresses some kind of length, and each can be measured with meters,
the unit defined by the [@SI] for quantities of length. However, each has different
properties, usage, and sometimes even a different character (position vector and displacement
are vector quantities).

The below presents how such a hierarchy tree can be defined in the [@MP-UNITS] library:

```cpp
inline constexpr struct dim_length : base_dimension<"L"> {} dim_length;

inline constexpr struct length : quantity_spec<dim_length> {} length;
inline constexpr struct width : quantity_spec<length> {} width;
inline constexpr auto breadth = width;
inline constexpr struct height : quantity_spec<length> {} height;
inline constexpr auto depth = height;
inline constexpr auto altitude = height;
inline constexpr struct thickness : quantity_spec<width> {} thickness;
inline constexpr struct diameter : quantity_spec<width> {} diameter;
inline constexpr struct radius : quantity_spec<width> {} radius;
inline constexpr struct radius_of_curvature : quantity_spec<radius> {} radius_of_curvature;
inline constexpr struct path_length : quantity_spec<length> {} path_length;
inline constexpr auto arc_length = path_length;
inline constexpr struct distance : quantity_spec<path_length> {} distance;
inline constexpr struct radial_distance : quantity_spec<distance> {} radial_distance;
inline constexpr struct wavelength : quantity_spec<length> {} wavelength;
inline constexpr struct position_vector : quantity_spec<length, quantity_character::vector> {} position_vector;
inline constexpr struct displacement : quantity_spec<length, quantity_character::vector> {} displacement;
```

In the above code:

- `length` takes the base dimension to indicate that we are creating a base quantity that will serve
  as a root for a tree of quantities of the same kind,
- `width` and following quantities are branches and leaves of this tree with the parent always
  provided as the argument to `quantity_spec` class template,
- `breadth` is an alias name for the same quantity as `width`.

Please note that some quantities (e.g. `displacement`) may be specified by the [@ISO80000] as
vector or tensor quantities.

## Comparing, adding, and subtracting quantities

The [@ISO-GUIDE] explicitly states that width and height are quantities of the same kind,
and as such, they:

- are mutually comparable,
- can be added and subtracted.

If we take the above for granted, the common quantity type being the result of the addition of two
quantities of width and height is a quantity of length.

A result of such an equation is always the first common branch in a hierarchy tree of the same
kind. For example:

```cpp
quantity q = isq::thickness(1 * m) + isq::radius(1 * m);
static_assert(q.quantity_spec == isq::width);
```

## Converting between quantities

Based on the same hierarchy of quantities of kind length, we can define quantity conversion rules.

1. Implicit conversions

    - every width is a length
    - every radius is a width

    ```cpp
    void foo(quantity<isq::length[m]>);
    ```

    ```cpp
    quantity<isq::height[m]> q = 42 * m;
    foo(q);
    ```

2. Explicit conversions

    - not every length is a width
    - not every width is a radius

    ```cpp
    void foo(quantity<isq::height[m]>);
    ```

    ```cpp
    quantity<isq::length[m]> q = 42 * m;
    foo(isq::height(q));
    ```

3. Explicit casts

    - height is not a width
    - both height and width are quantities of kind length

    ```cpp
    void foo(quantity<isq::height[m]>);
    ```

    ```cpp
    quantity<isq::width[m]> q = 42 * m;
    foo(quantity_cast<isq::height>(q));
    ```

4. No conversion

    - time has nothing in common with length

    ```cpp
    void foo(quantity<isq::length[m]>);
    ```

    ```cpp
    foo(quantity_cast<isq::length>(42 * s)); // ERROR
    ```

## Hierarchies of derived quantities

The same rules propagate to derived quantities. For example, we can define strongly typed horizontal
length and area:

```cpp
inline constexpr struct horizontal_length : quantity_spec<isq::length> {} horizontal_length;
inline constexpr struct horizontal_area : quantity_spec<isq::area, horizontal_length * isq::width> {} horizontal_area;
```

The first definition says that a horizontal length is a more specialized quantity than length and
belongs to the same quantity kind. The second line defines a horizontal area, which is a more
specialized quantity than area, so it has a more constrained recipe as well. Thanks to that:

```cpp
static_assert(implicitly_convertible(horizontal_length, isq::length));
static_assert(!implicitly_convertible(isq::length, horizontal_length));
static_assert(explicitly_convertible(isq::length, horizontal_length));

static_assert(implicitly_convertible(horizontal_area, isq::area));
static_assert(!implicitly_convertible(isq::area, horizontal_area));
static_assert(explicitly_convertible(isq::area, horizontal_area));

static_assert(implicitly_convertible(isq::length * isq::length, isq::area));
static_assert(!implicitly_convertible(isq::length * isq::length, horizontal_area));
static_assert(explicitly_convertible(isq::length * isq::length, horizontal_area));

static_assert(implicitly_convertible(horizontal_length * isq::width, isq::area));
static_assert(implicitly_convertible(horizontal_length * isq::width, horizontal_area));
```

## Modeling a quantity kind

In the physical units library, we also need an abstraction describing an entire family of
quantities of the same kind. Such quantities have not only the same dimension but also
can be expressed in the same units.

To annotate a quantity to represent its kind (and not just a hierarchy tree's root quantity)
in [@MP-UNITS] we introduced a `kind_of<>` specifier. For example, to express any quantity
of length, we need to type `kind_of<isq::length>`.

Such an entity behaves as any quantity of its kind. This means that it is implicitly
convertible to any quantity in a tree:

```cpp
static_assert(!implicitly_convertible(isq::length, isq::height));
static_assert(implicitly_convertible(kind_of<isq::length>, isq::height));
```

Additionally, the result of operations on quantity kinds is also a quantity kind:

```cpp
static_assert(same_type<kind_of<isq::length> / kind_of<isq::time>, kind_of<isq::length / isq::time>>);
```

However, if at least one equation's operand is not a quantity kind, the result becomes a "strong"
quantity where all the kinds are converted to the hierarchy tree's root quantities:

```cpp
static_assert(!same_type<kind_of<isq::length> / isq::time, kind_of<isq::length / isq::time>>);
static_assert(same_type<kind_of<isq::length> / isq::time, isq::length / isq::time>);
```

Please note that only a root quantity from the hierarchy tree or the one marked with `is_kind`
specifier in the `quantity_spec` definition can be put as a template parameter to the `kind_of`
specifier. For example, `kind_of<isq::width>` will fail to compile.


# Systems of Units

Modeling a system of units is the most important feature and a selling point of every
physical units library. Thanks to that, the library can protect users from performing invalid
operations on quantities and provide automated conversion factors between various compatible units.

Probably all the libraries in the wild model the [@SI], and many of them provide support for
additional units belonging to various other systems (e.g. imperial).

## Systems of Units are based on Systems of Quantities

Systems of quantities specify a set of quantities and equations relating to those quantities.
Those equations do not take any unit or a numerical representation into account at all. In order
to create a quantity, we need to add those missing pieces of information. This is where
a system of units kicks in.

The [@SI] is explicitly stated to be based on the ISQ. Among others, it defines seven base units,
one for each base quantity. In the [@MP-UNITS], this is expressed by associating a quantity kind
with a unit that is used to express it:

```cpp
inline constexpr struct metre : named_unit<"m", kind_of<isq::length>> {} metre;
```

The `kind_of<isq::length>` above states explicitly that this unit has an associated quantity
kind. In other words, `si::metre` (and scaled units based on it) can be used to express
the amount of any quantity of kind length.

## Units compose

One of the strongest points of the [@SI] system is that its units compose. This allows providing
thousands of different units for hundreds of various quantities with a really small set of
predefined units and prefixes. For example, one can write:

```cpp
quantity<si::metre / si::second> q;
```

to express a quantity of speed. The resulting quantity type is implicitly inferred from
the unit equation by repeating exactly the same operations on the associated quantity kinds.

## Many shades of the same unit

The [@SI] provides the names for 22 common coherent units of 22 derived quantities.

Each such named derived unit is a result of a specific predefined unit equation.
For example, a unit of power quantity is defined as:

```cpp
inline constexpr struct watt : named_unit<"W", joule / second> {} watt;
```

However, a power quantity can be expressed in other units as well. For example,
the following:

```cpp
auto q1 = 42 * W;
std::cout << q1 << "\n";
std::cout << q1.in(J / s) << "\n";
std::cout << q1.in(N * m / s) << "\n";
std::cout << q1.in(kg * m2 / s3) << "\n";
```

prints:

```text
42 W
42 J/s
42 N m/s
42 kg m²/s³
```

All of the above quantities are equivalent and mean exactly the same.

## Constraining a derived unit to work only with a specific derived quantity

Some derived units are valid only for specific derived quantities. For example, [@SI] specifies
both `hertz` and `becquerel` derived units with the same unit equation `1 / s`. However, it also
explicitly states:

> The hertz shall only be used for periodic phenomena and the becquerel shall only be used for
> stochastic processes in activity referred to a radionuclide.

This is why it is important for the library to allow constraining such units to be used only with
a specific quantity kind:

```cpp
inline constexpr struct hertz : named_unit<"Hz", one / second, kind_of<isq::frequency>> {} hertz;
inline constexpr struct becquerel : named_unit<"Bq", one / second, kind_of<isq::activity>> {} becquerel;
```

With the above, `hertz` can only be used for frequencies, while `becquerel` should only be used for
quantities of activity. This means that the following equation will not compile improving
the type-safety of the library:

```cpp
auto q = 1 * Hz + 1 * Bq;   // Fails to compile
```

## Prefixed units

Besides named units, the [SI](../../appendix/glossary.md#si) specifies also 24 prefixes
(all being a power of `10`) that can be prepended to all named units to obtain various scaled
versions of them.

Implementation of `std::ratio` provided by all major compilers is able to express only
16 of them. This is why, in the [@MP-UNITS], we had to find an alternative way to represent
unit magnitude in a more flexible way.

Each prefix is implemented as:

```cpp
template<PrefixableUnit auto U> struct quecto_ : prefixed_unit<"q", mag_power<10, -30>, U> {};
template<PrefixableUnit auto U> inline constexpr quecto_<U> quecto;
```

and then a unit can be prefixed in the following way:

```cpp
inline constexpr auto qm = quecto<metre>;
```

The usage of `mag_power` not only enables providing support for SI prefixes, but it can also
efficiently represent any rational magnitude. For example, IEC 80000 prefixes used in the
IT industry can be implemented as:

```cpp
template<PrefixableUnit auto U> struct yobi_ : prefixed_unit<"Yi", mag_power<2, 80>, U> {};
template<PrefixableUnit auto U> inline constexpr yobi_<U> yobi;
```

## Scaled units

In the [@SI], all units are either base or derived units or prefixed versions of those.
However, those are not the only options possible.

For example, there is a list of off-system units accepted for use with [@SI]. All of those
are scaled versions of the [@SI] units with ratios that can't be explicitly expressed with
predefined SI prefixes. Those include units like minute, hour, or electronvolt:

```cpp
inline constexpr struct minute : named_unit<"min", mag<60> * si::second> {} minute;
inline constexpr struct hour : named_unit<"h", mag<60> * minute> {} hour;
inline constexpr struct electronvolt : named_unit<"eV",
    mag<ratio{1'602'176'634, 1'000'000'000}> * mag_power<10, -19> * si::joule> {} electronvolt;
```

Also, units of other systems of units are often defined in terms of scaled versions of
the SI units. For example, the international yard is defined as:

```cpp
inline constexpr struct yard : named_unit<"yd", mag<ratio{9'144, 10'000}> * si::metre> {} yard;
```

For some units, a magnitude might also be irrational. The best example here is a `degree` which
is defined using a floating-point magnitude having a factor of the number π (Pi):

```cpp
inline constexpr struct mag_pi : magnitude<std::numbers::pi_v<long double>> {} mag_pi;
```

```cpp
inline constexpr struct degree : named_unit<basic_symbol_text{"°", "deg"}, mag_pi / mag<180> * si::radian> {} degree;
```


# Operations on units, dimensions, and quantity types

Modern C++ physical quantities and units library should expose compile-time constants for units,
dimensions, and quantity types. Each of such constants should be of a different type. Said otherwise,
every unit, dimension, and quantity type has a unique type and a compile-time instance.
This allows us to do regular algebra on such identifiers and get proper types results of such
operations.

The operations exposed by such a library should include at least:

- multiplication (e.g. `newton * metre`),
- division (e.g. `metre / second`),
- power (e.g. `pow<2>(metre)` or `pow<1, 2>(metre * metre)`)

To improve the usability of the library, we also recommend adding:

- square root (e.g. `sqrt(metre * metre)` is equivalent to `pow<1, 2>(metre * metre)`),
- cubic root (e.g. `cbrt(metre * metre * metre)` is equivalent to `pow<1, 3>(metre * metre * metre)`),
- inversion (e.g. `inverse(second)` is equivalent to `one / second`).

Additionally, for units only, to improve the readability of the code, it makes sense to expose the following:

- square power (e.g. `square(metre)` is equivalent to `pow<2>(metre)`)
- cubic power (e.g. `cubic(metre)` is equivalent to `pow<3>(metre)`)

The above two functions could also be considered for dimensions and quantity types. However,
`cubic(length)` does not seem to make much sense, and probably `pow<3>(length)` should be
preferred instead.

## Expression templates

Modern C++ physical quantities and units libraries use opaque types to improve the user experience while
analyzing compile-time errors or inspecting types in a debugger. This is a huge usability improvement
over the older libraries that use aliases to refer to long instantiations of class templates.

### Derived entities

Having such strong types for entities is not enough. While doing arithmetics on them, we get derived
entities, and they also should be easy to understand and correlate with the code written by the user.
This is where expression templates come into play.

The library should use the same unified approach to represent the results of arithmetics on all
kinds of entities. It is worth mentioning that a generic purpose regular expression library
is not a good solution for a physical quantities and units library.

Let's assume that we want to represent the results of the following two unit equations:

- `metre / second * second`
- `metre * metre / metre`

Both of them should result in a type equivalent to `metre`. A general-purpose library will probably
result with the types similar to the below:

- `mul<div<metre, second>, second>`
- `div<mul<metre, metre>, metre>`

Comparing such types for equivalence would not only be very expensive at compile-time but would also
be really confusing to the users observing them in the compilation logs. This is why we need
a dedicated solution here.

In a physical quantities and units library, we need expression templates to express the results of:

- dimension equations
- quantity equations
- unit equations

If the above equation results in a derived entity, we must create a type that clearly
describes what we are dealing with. We need to pack a simplified expression
template into some container for that. There are various possibilities here. The table below presents
the types generated from unit expressions by two leading products on the market in this subject:

<!-- markdownlint-disable MD013 -->

| Unit           | [@MP-UNITS]                                                            | [@AU]                                                                          |
|----------------|------------------------------------------------------------------------|--------------------------------------------------------------------------------|
| `N⋅m`          | `derived_unit<metre, newton>`                                          | `UnitProduct<Meters, Newtons>`                                                 |
| `1/s`          | `derived_unit<one, per<second>>`                                       | `Pow<Seconds, -1>`                                                             |
| `km/h`         | `derived_unit<kilo_<metre>, per<hour>>`                                | `UnitProduct<Kilo<Meters>, Pow<Hours, -1>>`                                    |
| `kg⋅m²/(s³⋅K)` | `derived_unit<kilogram, pow<metre, 2>, per<kelvin, power<second, 3>>>` | `UnitProduct<Pow<Meters, 2>, Kilo<Grams>, Pow<Seconds, -3>, Pow<Kelvins, -1>>` |
| `m²/m`         | `metre`                                                                | `Meters`                                                                       |
| `km/m`         | `derived_unit<kilo_<metre>, per<metre>>`                               | `UnitProduct<Pow<Meters, -1>, Kilo<Meters>>`                                   |
| `m/m`          | `one`                                                                  | `UnitProduct<>`                                                                |

<!-- markdownlint-enable MD013 -->

It is a matter of taste which solution is better. While discussing the pros and cons here, we
should remember that our users often do not have a scientific background. This is why
the [@MP-UNITS] library decided to use syntax that is as similar to the correct English language
as possible. It consistently uses the `derived_` prefix for types representing derived units,
dimensions, and quantity specifications. It always first lists the contents of the numerator
followed by the entities of the denominator (if present) enclosed in the `per<...>` expression
template.

### Identities

The arithmetics on units, dimensions, and quantities require a special identity value. Such value
can be returned as a result of the division of the same entities, or using it should not modify the
expression template on multiplication.

The [@MP-UNITS] library chose the following names here:

- `one` in the domain of units,
- `dimension_one` in the domain of dimensions,
- `dimensionless` in the domain of quantity types.

### Supported operations and their results

The table below presents all the operations that can be done on units, dimensions, and quantity
types in a physical quantities and units library and corresponding expressions templates chosen
by the [@MP-UNITS] project as their results:

|                   Operation                   | Resulting template expression arguments |
|:---------------------------------------------:|:---------------------------------------:|
|                    `A * B`                    |                 `A, B`                  |
|                    `B * A`                    |                 `A, B`                  |
|                    `A * A`                    |              `power<A, 2>`              |
|               `{identity} * A`                |                   `A`                   |
|               `A * {identity}`                |                   `A`                   |
|                    `A / B`                    |               `A, per<B>`               |
|                    `A / A`                    |              `{identity}`               |
|               `A / {identity}`                |                   `A`                   |
|               `{identity} / A`                |          `{identity}, per<A>`           |
|                  `pow<2>(A)`                  |              `power<A, 2>`              |
|             `pow<2>({identity})`              |              `{identity}`               |
|          `sqrt(A)` or `pow<1, 2>(A)`          |            `power<A, 1, 2>`             |
| `sqrt({identity})` or `pow<1, 2>({identity})` |              `{identity}`               |

### Simplifying the resulting expression templates

To limit the length and improve the readability of generated types, there are many rules to simplify
the resulting expression template.

1. **Ordering**

    The resulting comma-separated arguments of multiplication are always sorted according to
    a specific predicate. This is why:

    ```cpp
    static_assert(A * B == B * A);
    static_assert(std::is_same_v<decltype(A * B), decltype(B * A)>);
    ```

    This is probably the most important of all the steps, as it allows comparing types and enables
    the rest of the simplification rules.

    Units and dimensions have unique symbols, but ordering quantity types might not be that
    trivial. Although the ISQ defined in [@ISO80000] provides symbols for each
    quantity, there is little use for them in the C++ code. This is caused by the fact that
    such symbols use a lot of characters that are not available with the Unicode encoding.
    Most of the limitations correspond to Unicode providing only a minimal set of characters
    available as subscripts, which are often used to differentiate various quantities of the same
    kind. For example, it is impossible to encode the symbols of the following quantities:

    - _c_<sub>sat</sub> - specific heat capacity at saturated vapour pressure,
    - _μ_<sub>JT</sub> - Joule-Thomson coefficient,
    - _w_<sub>H<sub>2</sub>O</sub> - mass fraction of water,
    - _σ_<sub>Ω,E</sub> - direction and energy distribution of cross section,
    - _d_<sub>1/2</sub> - half-value thickness,
    - _Φ_<sub>e,λ</sub> - spectral radiant flux.

    This is why the [@MP-UNITS] library uses type name identifiers in such cases.

2. **Aggregation**

    In case two of the same type identifiers are found next to each other on the argument list, they
    will be aggregated in one entry:

    |              Before              |      After       |
    |:--------------------------------:|:----------------:|
    |              `A, A`              |  `power<A, 2>`   |
    |         `A, power<A, 2>`         |  `power<A, 3>`   |
    |  `power<A, 1, 2>, power<A, 2>`   | `power<A, 5, 2>` |
    | `power<A, 1, 2>, power<A, 1, 2>` |       `A`        |

3. **Simplification**

    In case two of the same type identifiers are found in the numerator and denominator argument lists,
    they are being simplified into one entry:

    |        Before         |        After         |
    |:---------------------:|:--------------------:|
    |      `A, per<A>`      |     `{identity}`     |
    | `power<A, 2>, per<A>` |         `A`          |
    | `power<A, 3>, per<A>` |    `power<A, 2>`     |
    | `A, per<power<A, 2>>` | `{identity}, per<A>` |

    It is important to notice here that only the elements with exactly the same type are being
    simplified. This means that, for example, `m / m` results in `one`, but `km / m` will not be
    simplified. The resulting derived unit will preserve both symbols and their relative
    magnitude. This allows us to properly print symbols of some units or constants that require
    such behavior. For example, the Hubble constant is expressed in `km⋅s⁻¹⋅Mpc⁻¹`, where both
    `km` and `Mpc` are units of length.

4. **Repacking**

    In case an expression uses two results of other operations, the components of its arguments
    are repacked into one resulting type and simplified there.

    For example, assuming:

    ```cpp
    constexpr auto X = A / B;
    ```

    then:

    | Operation | Resulting template expression arguments |
    |:---------:|:---------------------------------------:|
    |  `X * B`  |                   `A`                   |
    |  `X * A`  |          `power<A, 2>, per<B>`          |
    |  `X * X`  |     `power<A, 2>, per<power<B, 2>>`     |
    |  `X / X`  |              `{identity}`               |
    |  `X / A`  |          `{identity}, per<B>`           |
    |  `X / B`  |          `A, per<power<B, 2>>`          |

Please note that for as long as for the ordering step in some cases, we use user-provided
symbols, the aggregation, and the next steps do not benefit from those. They always use type
identifiers to determine whether the operation should be performed.

Unit symbols are not guaranteed to be unique in the project. For example, someone may use `"s"`
as a symbol for a count of samples, which, when used in a unit expression with seconds, would
cause fatal consequences (e.g. `sample * second` would yield `s²`, or `sample / second` would
result in `one`).

Some units would provide worse text output if the ordering step used type identifiers rather
than unit symbols. For example, `si::metre * si::second * cgs::second` would result
in `s m s`, or `newton * metre` would result in `m N`, which is not how we typically spell this
unit. However, for the sake of consistency, we may also consider changing the algorithm used for
ordering to be based on type identifiers.

### Example

Thanks to all of the steps described above, a user may write the code like this one:

```cpp
using namespace mp_units::si::unit_symbols;
auto speed = isq::speed(60. * km / h);
auto duration = 8 * s;
auto acceleration = speed / duration;
std::cout << "acceleration: " << acceleration << " (" << acceleration.in(m / s2) << ")\n";
```

The `acceleration`, being the result of the above code, has the following type
(after stripping the `mp_units` namespace for brevity):

```text
quantity<reference<derived_quantity_spec<isq::speed, per<isq::time>>{}, 
                   derived_unit<si::kilo_<si::metre{}>, per<non_si::hour, si::second>>{}>{},
         int>
```

and the text output provides:

```text
acceleration: 7.5 km h⁻¹ s⁻¹ (2.08333 m/s²)
```

## Scaled units

Another very common operation is to multiply an existing unit by a factor, creating a new, scaled unit.  For
example, the unit _foot_ can be multiplied by 3, producing the unit _yard_.

The process also works in reverse: the ratio between any two units of the same dimension is a well-defined
number.  For example, the ratio between one foot and one inch is 12.

### Unit Magnitudes

In principle, this scaling factor can be any positive real number.  In mp-units and Au, we have used the term
"magnitude" to refer to this scaling factor.  (This should not be confused with the logarithmic "magnitude"
unit commonly used in astronomy.)

In the library implementation, each unit is associated with a magnitude.  However, for most units the
magnitude is a fully encapsulated implementation detail, not a user-facing value.

This is because the notion of "the" magnitude of a unit is not generally meaningful: it has no physically
observable consequence.  What _is_ meaningful is the _ratio_ of magnitudes between two units of the same
dimension.  We could associate the _foot_, say, with any magnitude $m_f$ that we like --- but once we make that
choice, we must assign $3m_f$ to the _yard_, and $m_f/12$ to the _inch_.  Separately and independently, we can
assign any magnitude $m_s$ to the second, because it's an independent dimension --- but once we make that
choice, it fixes the magnitude for derived units, and we must assign, say, $(5280 m_f) / (3600 m_s)$ to the
_mile per hour_.

The one exception to the arbitrariness of magnitudes is _dimensionless_ units.  Because their dimension is
null, quantities of these units can be meaningfully compared to their squares and other powers.  For example,
the magnitude of _percent_ is $1 / 100$, and the magnitude of _squared percent_ (or _pertenk_, "per-10-k") is
$1 / 10000$.  We cannot choose another value for the magnitude without producing observably incorrect results.

### Requirements and Representation

A magnitude is a positive real number.  The best way to _represent_ it depends on how we will _use_ it.  To
derive our requirements, note that magnitudes must support every operation which units do.  This is because
units have two components that participate in operations: _dimension_, and _magnitude_.  When we apply an
operation to units, we simply apply it separately to the dimension and magnitude parts.

Units are closed under _products_ and _rational powers_.  Therefore, our magnitude representation must support
these operations natively and robustly; this is the most basic requirement.  We must also support certain
_irrational_ "ratios", such as the factor of $\frac{\pi}{180}$ between _degrees_ and _radians_.

The usual approach, `std::ratio`, fails to satisfy these requirements in multiple ways.

- It is not closed under rational powers (rather infamously, in the case of $2^\frac{1}{2}$).
- It cannot represent irrational factors such as $\pi$.
- It is too vulnerable to overflow when raised to powers.

One alternative is the _vector space magnitude_ representation.  Here, we represent each magnitude as
a _product of powers of "basis" numbers_.  This is the same representation we use for dimensions, so it will
naturally support all the same operations --- as long as we can find a suitable basis.

Each magnitude must have a unique representation.  This requirement constrains our choice of "basis" vectors:
they must not be able to represent any magnitude in more than one way.  Prime numbers have this property.
Take any arbitrarily large (but finite) collection of primes, raise each prime to some chosen exponent, and
compute the product: the result can't be expressed by any other collection of exponents.

Already, this lets us represent every positive real number which `std::ratio` can represent, by breaking the
numerator and denominator into their prime factorizations.  But we can go further, and handle irrational
factors such as $\pi$ by introducing them as new basis vectors.  $\pi$ cannot be represented by the product of
powers of _any_ finite collection of primes, which means that it is "linearly independent" in the sense of our
vector space representation.

On the C++ implementation side, we use variadic templates to define our magnitude.  Each element is a basis
number raised to some rational power (which may be omitted or abbreviated as appropriate).

Here are some examples, using Astronomical Units (au), meters (m), degrees (deg), and radians (rad).

| Unit ratio | `std::ratio` representation | vector space representation |
|-----------|-----------------------------|-----------------------------|
| $\left(\frac{\text{au}}{\text{m}}\right)$ | `std::ratio<149'597'870'700>` | `magnitude<power_v<2, 2>(), 3, power_v<5, 2>(), 73, 877, 7789>` |
| $\left(\frac{\text{au}}{\text{m}}\right)^2$ | Unrepresentable (overflow) | `magnitude<power_v<2, 4>(), power_v<3, 2>(), power_v<5, 4>(), power_v<73, 2>(), power_v<877, 2>(), power_v<7789, 2>()>` |
| $\sqrt{\frac{\text{au}}{\text{m}}}$ | Unrepresentable | `magnitude<2, power_v<3, 1, 2>(), 5, power_v<73, 1, 2>(), power_v<877, 1, 2>(), power_v<7789, 1, 2>()>` |
| $\left(\frac{\text{rad}}{\text{deg}}\right)$ | Unrepresentable | `magnitude<power_v<2, 2>(), power_v<3, 2>(), power_v<3.14159265358979323851e+0l, -1>(), 5>` |

The variadic magnitude types have one disadvantage: they are more verbose.  We may be able to hide them via
opaque types with nicer names, using a similar strategy as we have for units.  In any case, their major
advantage is that they fulfill the requirements stated above --- indeed, they are the only solution we have
seen which does.

### Construction helpers

We do not want end users to specify the variadic `magnitude` implementation manually.  That would be too labor
intensive and error prone.  Instead, we provide _construction helpers_ for end users.

`mag<N>` creates the vector space representation of the integer `N`.  This is a simple value, so we can
multiply and divide it with other magnitudes.

For example, `mag<180> / mag<240>` produces `magnitude<power_v<2, -2>(), 3>`, which is $3/4$.  Notice how the
result is always automatically represented in lowest terms, because a fraction _not_ in lowest terms cannot be
represented as a product of powers of primes.

### Common units

Some operations, such as addition or inequality comparison, are "common unit" operations.  In order to execute
them on quantities of the same dimension, we must first convert them to their _common unit_.

For units which are _commensurable_ --- that is, units whose ratio is a rational number --- the "common unit"
is the largest unit that evenly divides both.  For example, the common unit of the _foot_ and _inch_ is the
inch.

This also includes instances where neither unit is an integer multiple of the other.  For example, the common
unit of the meter and the yard does not have a name, but is equivalent to 800 micrometers.  If we call this
unit `U`, then there are 1250 `U` per meter, and 1143 `U` per yard.

The practical benefit of this definition is that this unit conversion will simply multiply each participating
quantity by an exact integer.  If we use integer types to begin with, we can continue to use them without
losing precision.

Unfortunately, not every unit conversion makes this possible.  No angular unit could evenly divide both
degrees and radians, for example.  In these instances, there is no uniquely defined notion of a "common unit".

In our vector space representation, we can easily compute the magnitude of the common unit by taking the
smallest exponent, across all participating magnitudes, for each individual basis vector --- as long as we
remember to use the implicit "0" exponent for any basis vector that is omitted.

The following example may help make this clear.  If we use $\text{COM}\left[U_1, \cdots, U_n\right]$ as
notation to represent "the common unit of $U_1, \cdots, U_n$", and we show only the magnitudes for simplicity,
here are the steps we would follow to find the magnitude of the common unit.

$$
\begin{align}
\text{COM}\left[18, \frac{80}{3}\right] &= \text{COM}\left[(2 \cdot 3^2), (2^4 \cdot 3^{-1} \cdot 5)\right] \\
&= \text{COM}\left[(2^1 \cdot 3^2 \cdot 5^0), (2^4 \cdot 3^{-1} \cdot 5^1)\right] \\
&= 2^1 \cdot 3^{-1} \cdot 5^0 \\
&= \frac{2}{3}
\end{align}
$$

This procedure produces the unambiguous correct answer whenever it is well defined.  It also produces an
answer for irrational "ratios", where there is no uniquely defined result.  This provides the practical
benefit of making it easy to compare, say, an angle in degrees to one in radians, as long as at least one of
them is represented in a floating point type.

## Faster than lightspeed constants

In most libraries, physical constants are implemented as constant (possibly `constexpr`)
quantity values. Such an approach has some disadvantages, often resulting in longer
compilation times and a loss of precision.

### Simplifying constants in an equation

When dealing with equations involving physical constants, they often occur more than once
in an expression. Such a constant may appear both in a numerator and denominator of
a quantity equation. As we know from fundamental physics, we can simplify such an expression
by striking a constant out of the equation. Supporting such behavior allows a faster runtime
performance and often a better precision of the resulting value.

### Physical constants as units

The [@MP-UNITS] library allows and encourages implementing physical constants as
regular units. With that, the constant's value is handled at compile-time, and under
favorable circumstances, it can be simplified in the same way as all other repeated
units do. If it is not simplified, the value is stored in a type, and the expensive
multiplication or division operations can be delayed in time until a user selects
a specific unit to represent/print the data.

Such a feature often also allows the use of simpler or faster representation types in the equation.
For example, instead of always multiplying a small integral value with a big
floating-point constant number, we can just use the integral type all the way. Only
in case a constant will not simplify in the equation, and the user will require a specific
unit, such a multiplication will be lazily invoked, and the representation type will
need to be expanded to facilitate that. With that, addition, subtractions, multiplications,
and divisions will always be the fastest - compiled away or done in out-of-order execution.

To benefit from all of the above, in the [@MP-UNITS] library, SI defining and other constants
are implemented as units in the following way:

```cpp
namespace si {

namespace si2019 {

inline constexpr struct speed_of_light_in_vacuum :
  named_unit<"c", mag<299'792'458> * metre / second> {} speed_of_light_in_vacuum;

}  // namespace si2019

inline constexpr struct magnetic_constant :
  named_unit<basic_symbol_text{"μ₀", "u_0"}, mag<4> * mag_pi * mag_power<10, -7> * henry / metre> {} magnetic_constant;

}  // namespace mp_units::si
```

### Usage examples

With the above definitions, we can calculate vacuum permittivity as:

```cpp
constexpr auto permeability_of_vacuum = 1. * si::magnetic_constant;
constexpr auto speed_of_light_in_vacuum = 1 * si::si2019::speed_of_light_in_vacuum;

QuantityOf<isq::permittivity_of_vacuum> auto q = 1 / (permeability_of_vacuum * pow<2>(speed_of_light_in_vacuum));

std::cout << "permittivity of vacuum = " << q << " = " << q.in(F / m) << "\n";
```

The above first prints the following:

```text
permittivity of vacuum = 1  μ₀⁻¹ c⁻² = 8.85419e-12 F/m
```

As we can clearly see, all the calculations above were just about multiplying and dividing
the number `1` with the rest of the information provided as a compile-time type. Only when
a user wants a specific SI unit as a result, the unit ratios are lazily resolved.

Another similar example can be an equation for total energy:

```cpp
QuantityOf<isq::mechanical_energy> auto total_energy(QuantityOf<isq::momentum> auto p,
                                                     QuantityOf<isq::mass> auto m,
                                                     QuantityOf<isq::speed> auto c)
{
  return isq::mechanical_energy(sqrt(pow<2>(p * c) + pow<2>(m * pow<2>(c))));
}
```

```cpp
constexpr auto GeV = si::giga<si::electronvolt>;
constexpr QuantityOf<isq::speed> auto c = 1. * si::si2019::speed_of_light_in_vacuum;
constexpr auto c2 = pow<2>(c);

const auto p1 = isq::momentum(4. * GeV / c);
const QuantityOf<isq::mass> auto m1 = 3. * GeV / c2;
const auto E = total_energy(p1, m1, c);

std::cout << "in `GeV` and `c`:\n"
          << "p = " << p1 << "\n"
          << "m = " << m1 << "\n"
          << "E = " << E << "\n";

const auto p2 = p1.in(GeV / (m / s));
const auto m2 = m1.in(GeV / pow<2>(m / s));
const auto E2 = total_energy(p2, m2, c).in(GeV);

std::cout << "\nin `GeV`:\n"
          << "p = " << p2 << "\n"
          << "m = " << m2 << "\n"
          << "E = " << E2 << "\n";

const auto p3 = p1.in(kg * m / s);
const auto m3 = m1.in(kg);
const auto E3 = total_energy(p3, m3, c).in(J);

std::cout << "\nin SI base units:\n"
          << "p = " << p3 << "\n"
          << "m = " << m3 << "\n"
          << "E = " << E3 << "\n";
```

The above prints the following:

```text
in `GeV` and `c`:
p = 4 GeV/c
m = 3 GeV/c²
E = 5 GeV

in `GeV`:
p = 1.33426e-08 GeV s/m
m = 3.33795e-17 GeV s²/m²
E = 5 GeV

in SI base units:
p = 2.13771e-18 kg m/s
m = 5.34799e-27 kg
E = 8.01088e-10 J
```

## Equivalence

Units, dimensions, and quantity types can be checked for equivalence with `operator==`. However,
what it means to be an equivalent entity means something different for each case here.

### Dimensions

Equivalence is the simplest to reason about in the case of dimensions. The only thing to account for
here is the point when a user would like to derive its own strong type from the library-provided one.

Please note that the library never provides strong types for derived dimensions besides
the `dimension_one`. For example, ISQ defines length (`L`) and time (`T`) dimensions, but there is
no such thing as a speed dimension. There is only a derived dimension of speed. It does not have
its own symbol and is described with `LT⁻¹`. This is the reason why a user should also not
derive strong types from the derived dimensions.

The equality operator for dimensions can be implemented as:

```cpp
template<Dimension Lhs, Dimension Rhs>
[[nodiscard]] consteval bool operator==(Lhs, Rhs)
{
  return std::derived_from<Lhs, Rhs> || std::derived_from<Rhs, Lhs>;
}
```

### Quantity types

Equality for quantity types is similar to dimensions. Again, users are allowed to derive their own types
from the strong types derived by the library (both base and derived quantities).

### Units

## Ordering

Please note that ordering for dimensions and quantity types has no physical sense.

We could entertain adding ordering for units, but this would work only for quantities having the same
reference unit, which would be inconsistent with how equivalence works.

Let's see the following example:

```cpp
constexpr Unit auto my_unit = si::second;
if constexpr (my_unit == si::metre) {
  // ...
}
if constexpr (my_unit > si::metre) {
  // ...
}
if constexpr (my_unit > si::nano(si::second)) {
  // ...
}
```

In the above code, the first check could be useful for some use cases. However, the second
one is impossible to implement and should not compile. The third one could be considered useful,
but the current version of [@MP-UNITS] does not expose such an interface to limit
potential confusion.


# Quantity References

## Associated Units

# Quantities

- quantity constructors and conversions (value preserving approach)
- exceptions and special cases for dimensionless quantities
- quantity arithmetics + quirks of modulo arithmetic and integral division
- custom representation types (improve safety, provide additional info like measurement, linear algebra, minimal requirements)
- representation type constraints
- vector quantities and their operations
- non-negative quantities

# The affine space


# Math CPOs



# Acknowledgements

Special thanks and recognition goes to [Epam Systems](http://www.epam.com) for supporting
Mateusz's membership in the ISO C++ Committee and the production of this proposal.

We would also like to thank Peter Sommerlad for providing valuable feedback that helped us shape
the final version of this document.

<!-- markdownlint-disable -->

---
references:
- id: AU
  citation-label: Au
  title: "The Au Units library"
  URL: <https://aurora-opensource.github.io/au>
- id: BIPM-VIM
  citation-label: JCGM 200:2012
  title: "International vocabulary of metrology - Basic and general concepts and associated terms (VIM) (JCGM 200:2012, 3rd edition)"
  URL: <https://jcgm.bipm.org/vim/en>
- id: ISO80000
  citation-label: ISO 80000
  title: "ISO80000: Quantities and units"
  URL: <https://www.iso.org/standard/76921.html>
- id: ISO-GUIDE
  citation-label: ISO/IEC Guide 99
  title: "ISO/IEC Guide 99: International vocabulary of metrology — Basic and general concepts and associated terms (VIM)"
  URL: <https://www.iso.org/obp/ui#iso:std:iso-iec:guide:99>
- id: MP-UNITS
  citation-label: mp-units
  title: "mp-units - A Physical Quantities and Units library for C++"
  URL: <https://mpusz.github.io/mp-units>
- id: SI
  citation-label: SI
  title: "SI Brochure: The International System of Units (SI)"
  URL: <https://www.bipm.org/en/publications/si-brochure>
---
