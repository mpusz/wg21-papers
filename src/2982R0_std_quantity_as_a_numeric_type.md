---
title: "`std::quantity` as a numeric type"
document: P2982R0
date: today
audience:
  - SG6 Numerics
author:
  - name: Mateusz Pusz ([Epam Systems](http://www.epam.com))
    email: <mateusz.pusz@gmail.com>
---


# Introduction

This document discusses the numeric and arithmetic aspects of the physical quantities and units
library. This subject is broader than it could be initially imagined. Arithmetic operations are not
only defined for user-facing types like `quantity` and `quantity_point`, but also for units and their
magnitudes, dimensions, quantity specifications, and references. Each has its own
requirements and constraints, and we will describe them in the following chapters.


# Terms and definitions

This document consistently uses the official metrology vocabulary defined in [@ISO-GUIDE] and [@BIPM-VIM].


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

| Unit           | [@MP-UNITS]                                                            | [@AU]                                                                          |
|----------------|------------------------------------------------------------------------|--------------------------------------------------------------------------------|
| `N⋅m`          | `derived_unit<metre, newton>`                                          | `UnitProduct<Meters, Newtons>`                                                 |
| `1/s`          | `derived_unit<one, per<second>>`                                       | `Pow<Seconds, -1>`                                                             |
| `km/h`         | `derived_unit<kilo_<metre>, per<hour>>`                                | `UnitProduct<Kilo<Meters>, Pow<Hours, -1>>`                                    |
| `kg⋅m²/(s³⋅K)` | `derived_unit<kilogram, pow<metre, 2>, per<kelvin, power<second, 3>>>` | `UnitProduct<Pow<Meters, 2>, Kilo<Grams>, Pow<Seconds, -3>, Pow<Kelvins, -1>>` |
| `m²/m`         | `metre`                                                                | `Meters`                                                                       |
| `km/m`         | `derived_unit<kilo_<metre>, per<metre>>`                               | `UnitProduct<Pow<Meters, -1>, Kilo<Meters>>`                                   |
| `m/m`          | `one`                                                                  | `UnitProduct<>`                                                                |

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

The below template presents all the operations that can be done on units, dimensions, and quantity
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
    kind. This is why the [@MP-UNITS] library uses type name identifiers in such cases.

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
quantity<reference<derived_quantity_spec<isq::speed, per<isq::time>>{}, derived_unit<si::kilo_<si::metre{}>, per<non_si::hour, si::second>>{}>{}, int>
```

and the text output provides:

```text
acceleration: 7.5 km h⁻¹ s⁻¹ (2.08333 m/s²)
```

## Scaled units

### Unit Magnitudes

TBD

### Construction helpers



### Common units




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

Such a feature often also allows using simpler or faster representation types in the equation.
For example, instead of always having to multiply a small integral value with a big
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
a user wants a specific SI unit as a result the unit ratios are lazily resolved.

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

### Units

### Quantity types

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

In the above code, the first check could useful for some use cases. However, the second
one is impossible to implement and should not compile. The third one could be considered useful,
but the current version of [@MP-UNITS] does not expose such an interface to limit
potential confusion.


# Quantity specifications

## Quantity kinds

### Conversions
 
### Mutually comparable quantities

#### `common_quantity_spec`

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
---
