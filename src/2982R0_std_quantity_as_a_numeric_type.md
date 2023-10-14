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

This document consistently uses the official metrology vocabulary defined in the [@ISO-GUIDE]
and [@BIPM-VIM].


# Systems of quantities

The physical units libraries on the market typically only focus on modeling one or more
systems of units. However, this is not the only system kind to model. Another, and maybe
even more important is a system of quantities. The most important example here is
the International System of Quantities (ISQ) defined by the series of [@ISO80000] documents.

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
systems of quantities.

## Quantities of the same kind

The [@ISO-GUIDE] says:

- Quantities may be grouped together into categories of quantities that are **mutually comparable**
- Mutually comparable quantities are called **quantities of the same kind**
- Two or more quantities **cannot be added or subtracted unless they belong to the same category
  of mutually comparable quantities**
- Quantities of the **same kind** within a given system of quantities **have the same quantity
  dimension**
- Quantities of the **same dimension are not necessarily of the same kind**

[@ISO80000] also explicitly notes:

> **Measurement units of quantities of the same quantity dimension may be designated by the same name
> and symbol even when the quantities are not of the same kind**. For example, joule per kelvin and J/K
> are respectively the name and symbol of both a measurement unit of heat capacity and a measurement
> unit of entropy, which are generally not considered to be quantities of the same kind. **However,
> in some cases special measurement unit names are restricted to be used with quantities of specific
> kind only**. For example, the measurement unit ‘second to the power minus one’ (1/s) is called hertz
> (Hz) when used for frequencies and becquerel (Bq) when used for activities of radionuclides. As
> another example, the joule (J) is used as a unit of energy, but never as a unit of moment of force,
> i.e. the newton metre (N · m).

Those provide answers to all the issues mentioned above. More than one quantity may be defined for
the same dimension:

- quantities of different kinds (e.g. frequency, modulation rate, activity, ...)
- quantities of the same kind (e.g. length, width, altitude, distance, radius, wavelength,
  position vector, ...)

Two quantities can't be added, subtracted, or compared unless they belong to the same quantity kind.

## System of quantities is not only about kinds

The [@ISO80000] specifies hundreds of different quantities. Plenty of various kinds
are provided, and often, each kind contains more than one quantity. It turns out that such quantities
form a hierarchy of quantities of the same kind.

For example, here are all quantities of the kind length provided in the [@ISO80000]:

![](img/quantities_of_length.svg)

Each of the above quantities expresses some kind of length, and each can be measured with meters
which is the unit defined by the [@SI] for quantities of length. However, each has different
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

## Converting between quantities of the same kind

Quantity conversion rules can be defined based on the same hierarchy of quantities of kind length.

1. **Implicit conversions**

    - Every `width` is a `length`.
    - Every `radius` is a `width`.

    ```cpp
    static_assert(implicitly_convertible(isq::width, isq::length));
    static_assert(implicitly_convertible(isq::radius, isq::length));
    static_assert(implicitly_convertible(isq::radius, isq::width));
    ```

    In the [@MP-UNITS] library implicit conversions are allowed on copy-initialization:

    ```cpp
    void foo(quantity<isq::length<m>> q);
    ```

    ```cpp
    quantity<isq::width<m>> q1 = 42 * m;
    quantity<isq::length<m>> q2 = q1;  // implicit quantity conversion
    foo(q1);                           // implicit quantity conversion
    ```

2. **Explicit conversions**

    - Not every `length` is a `width`.
    - Not every `width` is a `radius`.

    ```cpp
    static_assert(!implicitly_convertible(isq::length, isq::width));
    static_assert(!implicitly_convertible(isq::length, isq::radius));
    static_assert(!implicitly_convertible(isq::width, isq::radius));
    static_assert(explicitly_convertible(isq::length, isq::width));
    static_assert(explicitly_convertible(isq::length, isq::radius));
    static_assert(explicitly_convertible(isq::width, isq::radius));
    ```

    In the [@MP-UNITS] library explicit conversions are forced by passing the quantity to a call
    operator of a `quantity_spec` type:

    ```cpp
    quantity<isq::length<m>> q1 = 42 * m;
    quantity<isq::height<m>> q2 = isq::height(q1);  // explicit quantity conversion
    ```

3. **Explicit casts**

    - `height` is not a `width`.
    - Both `height` and `width` are quantities of kind `length`.

    ```cpp
    static_assert(!implicitly_convertible(isq::height, isq::width));
    static_assert(!explicitly_convertible(isq::height, isq::width));
    static_assert(castable(isq::height, isq::width));
    ```

    In the [@MP-UNITS] library explicit casts are forced with a dedicated `quantity_cast` function:

    ```cpp
    quantity<isq::width<m>> q1 = 42 * m;
    quantity<isq::height<m>> q2 = quantity_cast<isq::height>(q1);  // explicit quantity cast
    ```

4. **No conversion**

    - `time` has nothing in common with `length`.

    ```cpp
    static_assert(!implicitly_convertible(isq::time, isq::length));
    static_assert(!explicitly_convertible(isq::time, isq::length));
    static_assert(!castable(isq::time, isq::length));
    ```

    In the [@MP-UNITS] library even the explicit casts will not force such a conversion:

    ```cpp
    void foo(quantity<isq::length[m]>);
    ```

    ```cpp
    foo(quantity_cast<isq::length>(42 * s)); // Compile-time error
    ```


With the above rules one can write a following short application to calculate the fuel consumption:

```cpp
inline constexpr struct fuel_volume : quantity_spec<isq::volume> {} fuel_volume;
inline constexpr struct fuel_consumption  : quantity_spec<fuel_volume / isq::distance> {} fuel_consumption;

const quantity fuel = fuel_volume(40. * l);
const quantity distance = isq::distance(550. * km);
const quantity<fuel_consumption[l / (mag<100> * km)]> q = fuel / distance;
std::cout << "Fuel consumption: " << q << "\n";
```

The above code prints:

```text
Fuel consumption: 7.27273 × 10⁻² l/km
```

Please note that despite the dimensions of `fuel_consumption` and `isq::area` are the same (`L²`),
the constructor of a quantity `q` below will fail to compile when we pass an argument being the
quantity of area:

```cpp
static_assert(fuel_consumption.dimension == isq::area.dimension);

const quantity<isq::area[m2]> football_field = isq::length(105 * m) * isq::width(68 * m);
const quantity<fuel_consumption[l / (mag<100> * km)]> q = football_field;  // Compile-time error
```

## Comparing, adding, and subtracting quantities of the same kind

[@ISO-GUIDE] explicitly states that `width` and `height` are quantities of the same kind and as such
they:

- are mutually comparable,
- can be added and subtracted.

If we take the above for granted, the only reasonable result of `1 * width + 1 * height` is `2 * length`,
where the result of `length` is known as a common quantity type. A result of such an equation is always
the first common branch in a hierarchy tree of the same kind. For example:

```cpp
static_assert(common_quantity_spec(isq::width, isq::height) == isq::length);
static_assert(common_quantity_spec(isq::thickness, isq::radius) == isq::width);
static_assert(common_quantity_spec(isq::distance, isq::path_length) == isq::path_length);
```

```cpp
quantity q = isq::thickness(1 * m) + isq::radius(1 * m);
static_assert(q.quantity_spec == isq::width);
```

One could argue that allowing adding or comparing quantities of height and width might be a safety
issue, but we need to be consistent with the requirements of the [@ISO-GUIDE]. Moreover, from our
experience, disallowing such operations and requiring an explicit cast to a common quantity
in every single place makes the code so cluttered with casts that it nearly renders the library
unusable.

Fortunately, the above-mentioned conversion rules make the code safe by construction anyway.
Let's analyze the following example:

```cpp
inline constexpr struct horizontal_length : quantity_spec<isq::length> {} horizontal_length;

namespace christmas {

struct gift {
  quantity<horizontal_length[m]> length;
  quantity<isq::width[m]> width;
  quantity<isq::height[m]> height;
};

std::array<quantity<isq::length[m]>, 2> gift_wrapping_paper_size(const gift& g)
{
  const auto dim1 = 2 * g.width + 2 * g.height + 0.5 * g.width;
  const auto dim2 = g.length + 2 * 0.75 * g.height;
  return { dim1, dim2 };
}

}  // namespace christmas

int main()
{
  const christmas::gift lego = { horizontal_length(40 * cm), isq::width(30 * cm), isq::height(15 * cm) };
  auto paper = christmas::gift_wrapping_paper_size(lego);

  std::cout << "Paper needed to pack a lego box:\n";
  std::cout << "- " << paper[0] << " X " << paper[1] << "\n";  // - 1.05 m X 0.625 m
  std::cout << "- area = " << paper[0] * paper[1] << "\n";     // - area = 0.65625 m²
}
```

In the beginning, we introduce a custom quantity `horizontal_length` of a kind length, which then,
together with `isq::width` and `isq::height` are used to define the dimensions of a Christmas gift.
Next, we provide a function that calculates the dimensions of a gift wrapping paper with some
wraparound. The result of both those expressions is a quantity of `isq::length` as this is
the closest common quantity for the arguments used in this quantity equation.

Regarding safety, it is important to mention here, that thanks to the conversion rules provided above,
it would be impossible to accidentally do the following:

```cpp
void foo(quantity<horizontal_length[m]> q);

quantity<isq::width[m]> q1 = dim1;  // Compile-time error
quantity<isq::height[m]> q2{dim1};  // Compile-time error
foo(dim1);                          // Compile-time error
```

The reason of compilation errors above is the fact that `isq::length` is not implicitly convertible
to the quantities defined based on it. To make the above code compile, an explicit conversion of
a quantity type is needed:

```cpp
void foo(quantity<horizontal_length[m]> q);

quantity<isq::width[m]> q1 = isq::width(dim1);
quantity<isq::height[m]> q2{isq::height(dim1)};
foo(horizontal_length(dim1));
```

To summarize, rules for addition, subtraction, and comparison of quantities improve the library
usability, while the conversion rules enhance the safety of the library compared to the
libraries that do not model quantity kinds.

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

Unfortunately, derived quantity equations often do not automatically form a hierarchy tree.
This is why it is sometimes not obvious what such a tree should look like. Also, the [@ISO-GUIDE]
explicitly states:

> The division of ‘quantity’ according to ‘kind of quantity’ is, to some extent, arbitrary.

The below presents some arbitrary hierarchy of derived quantities of kind energy:

![](img/quantities_of_energy.svg)

Notice, that even though all of those quantities have the same dimension and can be expressed
in the same units, they have different quantity equations used to create them implicitly:

- `energy` is the most generic one and thus can be created from base quantities of `mass`, `length`,
  and `time`. As those are also the roots of quantities of their kinds and all other quantities are
  implicitly convertible to them, it means that an `energy` can be implicitly constructed from any
  quantity having proper powers of mass, length, and time.

    ```cpp
    static_assert(implicitly_convertible(isq::mass * pow<2>(isq::length) / pow<2>(isq::time), isq::energy));
    static_assert(implicitly_convertible(isq::mass * pow<2>(isq::height) / pow<2>(isq::time), isq::energy));
    ```

- `mechanical_energy` is a more "specialized" quantity than `energy` (not every `energy` is
  a `mechanical_energy`). It is why an explicit cast is needed to convert from either `energy` or
  the results of its quantity equation.

    ```cpp
    static_assert(!implicitly_convertible(isq::energy, isq::mechanical_energy));
    static_assert(explicitly_convertible(isq::energy, isq::mechanical_energy));
    static_assert(!implicitly_convertible(isq::mass * pow<2>(isq::length) / pow<2>(isq::time), isq::mechanical_energy));
    static_assert(explicitly_convertible(isq::mass * pow<2>(isq::length) / pow<2>(isq::time), isq::mechanical_energy));
    ```

- `gravitational_potential_energy` is not only even more specialized one but additionally,
  it is special in a way that it provides its own "constrained" quantity equation. Maybe not every
  `mass * pow<2>(length) / pow<2>(time)` is a `gravitational_potential_energy`, but every
  `mass * acceleration_of_free_fall * height` is.

    ```cpp
    static_assert(!implicitly_convertible(isq::energy, gravitational_potential_energy));
    static_assert(explicitly_convertible(isq::energy, gravitational_potential_energy));
    static_assert(!implicitly_convertible(isq::mass * pow<2>(isq::length) / pow<2>(isq::time), gravitational_potential_energy));
    static_assert(explicitly_convertible(isq::mass * pow<2>(isq::length) / pow<2>(isq::time), gravitational_potential_energy));
    static_assert(implicitly_convertible(isq::mass * isq::acceleration_of_free_fall * isq::height, gravitational_potential_energy));
    ```

## Modeling a quantity kind

In the physical units library, we also need an abstraction describing an entire family of
quantities of the same kind. Such quantities have not only the same dimension but also
can be expressed in the same units.

To annotate a quantity to represent its kind (and not just a hierarchy tree's root quantity)
in [@MP-UNITS] we introduced a `kind_of<>` specifier. For example, to express any quantity
of length, we need to type `kind_of<isq::length>`. Such an entity behaves as any quantity of
its kind. This means that it is implicitly convertible to any quantity in a tree:

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


# Systems of units

Modeling a system of units is the most important feature and a selling point of every
physical units library. Thanks to that, the library can protect users from performing invalid
operations on quantities and provide automated conversion factors between various compatible units.

Probably all the libraries in the wild model the [@SI], and many of them provide support for
additional units belonging to various other systems (e.g. imperial).

## Systems of units are based on systems of quantities

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

Associated units are so useful and common in the [@MP-UNITS] library that they got their
own concepts `AssociatedUnit<T>` to improve the interfaces.

Please note that for some systems of units (i.e. natural units) a unit may not have an
associated quantity type. For example, if we assume speed of light constant `c = 1` we can
define a system where both length and time will be measured in seconds and speed will be
a quantity measured with the unit `one`. In such case the definition will look as follows:

```cpp
inline constexpr struct second : named_unit<"s"> {} second;
```

## Units compose

One of the strongest points of the [@SI] system is that its units compose. This allows providing
thousands of different units for hundreds of various quantities with a really small set of
predefined units and prefixes. For example, one can write:

```cpp
quantity<si::metre / si::second> q;
```

to express a quantity of speed. The resulting quantity type is implicitly inferred from
the unit equation by repeating exactly the same operations on the associated quantity kinds.

Also, as units are regular values we can easily provide a helper ad-hoc unit with:

```cpp
constexpr auto mps = si::metre / si::second;
quantity<mps> q;
```


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
both `hertz` and `becquerel` derived units with the same unit equation `1/s`. However, it also
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

Also, units of other systems of units are often defined in terms of scaled versions of other
(often SI) units. For example, the international yard is defined as:

```cpp
inline constexpr struct yard : named_unit<"yd", mag<ratio{9'144, 10'000}> * si::metre> {} yard;
```

and then a `foot` can be defined as:

```cpp
inline constexpr struct foot : named_unit<"ft", mag<ratio{1, 3}> * yard> {} foot;
```

For some units, a magnitude might also be irrational. The best example here is a `degree` which
is defined using a floating-point magnitude having a factor of the number π (Pi):

```cpp
inline constexpr struct mag_pi : magnitude<std::numbers::pi_v<long double>> {} mag_pi;
```

```cpp
inline constexpr struct degree : named_unit<basic_symbol_text{"°", "deg"}, mag_pi / mag<180> * si::radian> {} degree;
```

## Unit symbols

In the [@MP-UNITS] library units are available via their full names or through their short symbols.
To use a long version it is enough to type:

```cpp
#include <mp-units/systems/si/si.h>

using namespace mp_units;

quantity q = 42 * si::metre;
```

The same can be obtained using an optional unit symbol:

```cpp
#include <mp-units/systems/si/si.h>

using namespace mp_units;
using namespace mp_units::si::unit_symbols;

quantity q = 42 * m;
```

Unit symbols introduce a lot of short identifiers into the current namespace, and that is why they
are opt-in. A user has to explicitly "import" them from a dedicated `unit_symbols` namespace.


# Operations on units, dimensions, and quantity types

Modern C++ physical quantities and units library should expose compile-time constants for units,
dimensions, and quantity types. Each of such constants should be of a different type. Said otherwise,
every unit, dimension, and quantity type has a unique type and a compile-time instance.
This allows us to do regular algebra on such identifiers and get proper types as results of such
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
kinds of entities. It is worth mentioning that a generic purpose expression templates library
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

- dimension equations,
- quantity type equations,
- unit equations,
- unit magnitude equations.

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
dimensions, and quantity specifications. Those are instantiated first with the contents of
the numerator followed by the entities of the denominator (if present) enclosed in the
`per<...>` expression template.

### Identities

The arithmetics on units, dimensions, and quantity types require a special identity value. Such value
can be returned as a result of the division of the same entities, or using it should not modify the
expression template on multiplication.

The [@MP-UNITS] library chose the following names here:

- `one` in the domain of units,
- `dimension_one` in the domain of dimensions,
- `dimensionless` in the domain of quantity types.

The above names were selected based on the following quote from the [@ISO80000]:

> A quantity whose dimensional exponents are all equal to zero has the dimensional product denoted
> A<sup>0</sup>B<sup>0</sup>C<sup>0</sup>… = 1, where the symbol 1 denotes the corresponding
> dimension. There is no agreement on how to refer to such quantities. They have been called
> **dimensionless** quantities (although this term should now be avoided), quantities with
> **dimension one**, quantities with dimension number, or quantities with the **unit one**.
> Such quantities are dimensionally simply numbers. To avoid confusion, it is helpful to use
> explicit units with these quantities where possible, e.g., m/m, nmol/mol, rad, as specified
> in the SI Brochure.

### Supported operations and their results

The table below presents all the operations that can be done on units, dimensions, and quantity
types in a physical quantities and units library and corresponding expression templates chosen
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

    This is why the [@MP-UNITS] library chose to use type name identifiers in such cases.

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
    simplified. This means that, for example, `m/m` results in `one`, but `km/m` will not be
    simplified. The resulting derived unit will preserve both symbols and their relative
    magnitude. This allows us to properly print symbols of some units or constants that require
    such behavior. For example, the Hubble constant is expressed in `km⋅s⁻¹⋅Mpc⁻¹`, where both
    `km` and `Mpc` are units of length.

4. **Repacking**

    In case an expression uses two results of some other operations, the components of its arguments
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
quantity speed = isq::speed(60. * km / h);
quantity duration = 8 * s;
quantity acceleration1 = speed / duration;
quantity acceleration2 = isq::acceleration(acceleration1.in(m / s2));
std::cout << "acceleration: " << acceleration1 << " (" << acceleration2 << ")\n";
```

the text output provides:

```text
acceleration: 7.5 km h⁻¹ s⁻¹ (2.08333 m/s²)
```

The above program will produce the following types for acceleration quantities
(after stripping the `mp_units` namespace for brevity):

- `acceleration1`

    ```text
    quantity<reference<derived_quantity_spec<isq::speed, per<isq::time>>{}, 
                      derived_unit<si::kilo_<si::metre{}>, per<non_si::hour, si::second>>{}>{},
             double>
    ```

- `acceleration2`

    ```text
    quantity<reference<isq::speed, per<isq::time>>{}, 
                       derived_unit<si::metre, per<power<si::second, 2>>>{}>{},
             double>>
    ```

## Scaled units

Another very common operation is to multiply an existing unit by a factor, creating a new, scaled unit.  For
example, the unit _foot_ can be multiplied by 3, producing the unit _yard_.

The process also works in reverse: the ratio between any two units of the same dimension is a well-defined
number.  For example, the ratio between one foot and one inch is 12.

### Unit magnitudes

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
by simply striking a constant out of the equation. Supporting such behavior allows a faster runtime
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
and divisions will always be the fastest - compiled away or done on the fast arithmetic types
or in out-of-order execution.

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
no such thing as a speed dimension. It does not have its own symbol as well. There is only a derived
dimension of speed described with `LT⁻¹`. This is the reason why a user should also not derive strong
types from the derived dimensions.

The equality operator for dimensions can be implemented as:

```cpp
template<Dimension Lhs, Dimension Rhs>
[[nodiscard]] consteval bool operator==(Lhs, Rhs)
{
  return std::derived_from<Lhs, Rhs> || std::derived_from<Rhs, Lhs>;
}
```

### Quantity types

Equality for quantity types is similar to dimensions. Again, users are allowed to derive their own
types but only from the named strong types provided by the library:

```cpp
template<QuantitySpec Lhs, QuantitySpec Rhs>
[[nodiscard]] consteval bool operator==(Lhs, Rhs)
{
  if constexpr (detail::NamedQuantitySpec<Lhs> && detail::NamedQuantitySpec<Rhs>)
    return std::derived_from<Lhs, Rhs> || std::derived_from<Rhs, Lhs>;
  else
    return is_same_v<Lhs, Rhs>;
}
```

### Units

Equality for units is a bit more complicated. Not only watt (`W`) should be equivalent to `J/s` or
`kg m²/s³` but also litre (`l`) should be equivalent to cubic decimetre (`dm³`). This is why in this
case we do not compare user-provided types but first convert each unit to its canonical representation
and then we compare if the reference unit and the magnitude is the same:

```cpp
[[nodiscard]] consteval bool operator==(Unit auto lhs, Unit auto rhs)
{
  auto canonical_lhs = detail::get_canonical_unit(lhs);
  auto canonical_rhs = detail::get_canonical_unit(rhs);
  return detail::have_same_canonical_reference_unit(canonical_lhs.reference_unit, canonical_rhs.reference_unit) &&
         canonical_lhs.mag == canonical_rhs.mag;
}
```

## Ordering

Please note that the ordering for dimensions and quantity types has no physical sense.

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
potential confusion. Also, it is really hard to mathematically prove that unit magnitude
representation that we us in the library is greater or smaller than the other one in some cases.


# Quantities

`quantity` class template is the workhorse of the library. It can be considered a generalization
of `std::chrono::duration`, but is not directly compatible with it.

## Quantity references

_Note: we know that probably the term "reference" will not survive too long in the Committee,
but we couldn't find a better name for it in the [@MP-UNITS] library._

[@ISO-GUIDE] says:

> **quantity** - property of a phenomenon, body, or substance, where the property has a magnitude
> that can be expressed as a number and a reference. ...
> A reference can be a measurement unit, a measurement procedure, a reference material, or
> a combination of such.

In the [@MP-UNITS] library a quantity reference represents all the domain-specific meta-data about
the quantity besides its representation type and its value. A `Reference` concept is
satisfied by either of:

- an associated unit (e.g. `si::metre`),
- an instantiation of the `reference<QuantitySpec, Unit>` class template explicitly specifying
  the quantity type and its unit.

A reference type is implicitly created as a result of the following expression:

```cpp
using namespace mp_units::si::unit_symbols;
constexpr auto ref = isq::height[m];
```

The above example resulted in the following type `reference<isq::height, si::metre>` being
instantiated.

Reference class template also exposes arithmetic interface similar to the one that we have
already discussed in case of units and quantity types. It just simply forwards the operation
to its quantity type an units members. For example:

```cpp
template<QuantitySpec auto Q, Unit auto U>
struct reference {
  template<auto Q2, auto U2>
  [[nodiscard]] friend consteval bool operator==(reference, reference<Q2, U2>)
  {
    return Q == Q2 && U == U2;
  }

  template<AssociatedUnit U2>
  [[nodiscard]] friend consteval bool operator==(reference, U2 u2)
  {
    return Q == get_quantity_spec(u2) && U == u2;
  }

  template<auto Q2, auto U2>
  [[nodiscard]] friend consteval reference<Q * Q2, U * U2> operator*(reference, reference<Q2, U2>)
  {
    return {};
  }

  template<AssociatedUnit U2>
  [[nodiscard]] friend consteval reference<Q * get_quantity_spec(U2{}), U * U2{}> operator*(reference, U2)
  {
    return {};
  }

  // ...
};
```

Please note that all of the operators work on two `reference` instantiations, or one its
instantiation and an `AssociatedUnit`.

## `quantity` class template

Based on the ISO definition above, the `quantity` class template has the following signature:

```cpp
template<Reference auto R, RepresentationOf<get_quantity_spec(R).character> Rep = double>
class quantity;
```

It has only one data member of `Rep` type. Unfortunately, this data member is publicly exposed
to satisfy the C++ language requirements for structural types. Hopefully, the language rules
for structural types will improve with time before this library gets standardized.

## Quantity construction helpers

As we already noticed in many examples above a numerical value multiplied or divided by
the `Reference` creates the value of `quantity` class template with the representation type
and reference deduced from the types used in the expression.

We have a few options to choose from here:

- simple quantities (quantities of a quantity kind)

```cpp
quantity<si::metre / si::second, int> q1 = 42 * m / s;
quantity q2 = 42 * m / s;

static_assert(std::is_same_v<decltype(q1), decltype(q2)>);
static_assert(q1.quantity_spec == kind_of<isq::length / isq::time>);
```

- typed quantities

```cpp
quantity<isq::speed[si::metre / si::second], int> q3 = 42 * m / s;
quantity q4 = 42 * isq::speed[m / s];
quantity q5 = isq::speed(42 * m / s);

static_assert(std::is_same_v<decltype(q3), decltype(q4)>);
static_assert(std::is_same_v<decltype(q3), decltype(q5)>);
static_assert(q3.quantity_spec == isq::speed);
```

In case someone doesn't like the multiply syntax or there is an ambiguity between `operator*`
provided by this and other libraries, a quantity can also be created with a dedicated factory
function:

```cpp
quantity q = make_quantity<isq::speed[m / s]>(42);
```

## Quantity constructors and value conversions

`quantity` class template has a converting constructor that participates in the overload resolution
only when:

- source quantity specification is implicitly convertible to the destination one,
- both units share the same reference unit,
- the resulting value conversion will be value-preserving.

Additionally, this constructor becomes explicit if the source representation type is not convertible
to the destination one.

### Value-preserving conversions

As of today, the [@MP-UNITS] library follows [the rules of `std::chrono::duration` for
value-preserving conversions](https://en.cppreference.com/w/cpp/chrono/duration/duration).
We realize that some time has passed now and maybe we can improve in this domain. However,
to our knowledge, as of today, we do not have any tools we could use in the C++ Standard to
improve that.

Below we describe the current approach.

```cpp
auto q1 = 5 * km;
std::cout << q1.in(m) << '\n';
quantity<si::metre, int> q2 = q1;
```

The second line above converts the current quantity to the one expressed in metres and prints its
contents. The third line converts the quantity expressed in kilometers into the one measured in
metres.

In both cases we assume that one can convert a quantity into another one with a unit of a higher
resolution. There is no protection against overflow of the representation type. In case the target
quantity ends up with a value bigger than the representation type can handle, we will be facing
Undefined Behavior.

If we try similar, but this time opposite, operations to the above, both conversions should fail
to compile:

```cpp
auto q1 = 5 * m;
std::cout << q1.in(km) << '\n';              // Compile-time error
quantity<si::kilo<si::metre>, int> q2 = q1;  // Compile-time error
```

We can't preserve the value of a source quantity when we convert it to a one using the unit of
a lower resolution while dealing with an integral representation type for a quantity.
In the example above, converting `5` meters would result in `0` kilometers if internal conversion
is performed using regular integer arithmetic.

While this could be a valid behavior, the problem arises when the user expects to be able to convert
the quantity back to the original unit without loss of information.
So the library should prevent such conversions from happening implicitly; whether the library
should offer explicitly marked unsafe conversions for these cases is yet to be discussed.

To make the above conversions compile, we could use a floating-point representation type:

```cpp
auto q1 = 5. * m;    // source quantity uses `double` as a representation type
std::cout << q1.in(km) << '\n';
quantity<si::kilo<si::metre>> q2 = q1;
```

or:

```cpp
auto q1 = 5 * m;     // source quantity uses `int` as a representation type
std::cout << value_cast<double>(q1).in(km) << '\n';
quantity<si::kilo<si::metre>> q2 = q1;  // double by default
```

_The [@MP-UNITS] library follows `std::chrono::duration` logic and treats floating-point types as
value-preserving._

### Value-truncating conversions

Another possibility would be to force such a truncating conversion explicitly from the code:

```cpp
auto q1 = 5 * m;     // source quantity uses `int` as a representation type
std::cout << q1.force_in(km) << '\n';
quantity<si::kilo<si::metre>, int> q2 = value_cast<km>(q1);
```

The code above makes it clear that "something bad" may happen here if we are not extra careful.

Another case for truncation happens when we assign a quantity with a floating-point representation
type to the one using an integral representation type for its value:

```cpp
auto q1 = 2.5 * m;
quantity<si::metre, int> q2 = q1;
```

Such an operation should fail to compile as well. Again, to force such a truncation, we have to
be explicit in the code:

```cpp
auto q1 = 2.5 * m;
quantity<si::metre, int> q2 = value_cast<int>(q1);
```

As we can see, it is essential not to allow such truncating conversions to happen implicitly
and a good physical quantities and units library should fail at compile time in case a user makes
such a mistake.

## Character of a quantity

This chapter is just a short preview to the feature that will get its own paper in the future if
the Committee is interested in exploring this path.

### Scalars, vectors, and tensors

[@ISO80000] explicitly states:

> Scalars, vectors and tensors are mathematical objects that can be used to denote certain physical
> quantities and their values. They are as such independent of the particular choice of a coordinate
> system, whereas each scalar component of a vector or a tensor and each component vector and
> component tensor depend on that choice.

Such distinction is important because each quantity character represents different properties
and allows different operations to be done on its quantities.

For example, imagine a physical units library that allows the creation of a `speed` quantity from both
`length / time` and `length * time`. It wouldn't be too safe to use such a product, right?

Now we have to realize that both of the above operations (multiplication and division) are not even
mathematically defined for linear algebra types such as vectors or tensors. On the other hand, two vectors
can be passed as arguments to dot and cross-product operations. The result of the first one is
a scalar. The second one results in a vector that is perpendicular to both vectors passed as arguments.
Again, it wouldn't be safe to allow replacing those two operations with each other or expect the same
results from both cases. This simply can't work.

### ISQ defines quantities of all characters

While defining quantities ISO 80000 explicitly mentions when a specific quantity has a vector or tensor
character. Here are some examples:

| Quantity               |  Character   |                 Quantity Equation                 |
|------------------------|:------------:|:-------------------------------------------------:|
| `duration`             |    scalar    |                 _{base quantity}_                 |
| `mass`                 |    scalar    |                 _{base quantity}_                 |
| `length`               |    scalar    |                 _{base quantity}_                 |
| `path_length`          |    scalar    |                 _{base quantity}_                 |
| `radius`               |    scalar    |                 _{base quantity}_                 |
| `position_vector`      |  **vector**  |                 _{base quantity}_                 |
| `velocity`             |  **vector**  |           `position_vector / duration`            |
| `acceleration`         |  **vector**  |               `velocity / duration`               |
| `force`                |  **vector**  |               `mass * acceleration`               |
| `power`                |    scalar    |                `force ⋅ velocity`                 |
| `moment_of_force`      |  **vector**  |             `position_vector × force`             |
| `torque`               |    scalar    |         `moment_of_force ⋅ {unit-vector}`         |
| `surface_tension`      |    scalar    |                `|force| / length`                 |
| `angular_displacement` |    scalar    |              `path_length / radius`               |
| `angular_velocity`     |  **vector**  | `angular_displacement / duration * {unit-vector}` |
| `momentum`             |  **vector**  |                 `mass * velocity`                 |
| `angular_momentum`     |  **vector**  |           `position_vector × momentum`            |
| `moment_of_inertia`    | **_tensor_** |       `angular_momentum ⊗ angular_velocity`       |

In the above equations:

- `a * b` - regular multiplication where one of the arguments has to be scalar
- `a / b` - regular division where the divisor has to be scalar
- `a ⋅ b` - dot product of two vectors
- `a × b` - cross product of two vectors
- `|a|` - magnitude of a vector
- `{unit-vector}` - a special vector with the magnitude of `1`
- `a ⊗ b` - tensor product of two vectors or tensors

As of now, all of the C++ physical units libraries on the market besides [@MP-UNITS] do not
support the operations mentioned above. They expose only multiplication and division operators,
which do not work for linear algebra-based representation types. If a user of those libraries
would like to create the quantities provided in the above table properly, this would result in
a compile-time error stating that multiplication and division of two linear algebra vectors is
impossible.

Outside of C++ only [@PINT] provides a great support in this domain.

### Characters don't apply to dimensions and units

[@ISO80000] explicitly states that dimensions are orthogonal to quantity characters:

> In deriving the dimension of a quantity, no account is taken of its scalar, vector, or tensor character.

Also, it explicitly states that:

> All units are scalars.

### Defining vector and tensor quantities

To specify that a specific quantity has a vector or tensor character a value of `quantity_character`
enumeration can be appended to the `quantity_spec` describing such a quantity type:

```cpp
inline constexpr struct position_vector : quantity_spec<length, quantity_character::vector> {} position_vector;
inline constexpr struct displacement : quantity_spec<length, quantity_character::vector> {} displacement;
```

With the above, all the quantities derived from `position_vector` or `displacement` will have a
correct character determined according to the kind of operations included in the quantity equation
defining a derived quantity.

For example, `velocity` in the below definition will be defined as a vector quantity (no explicit
character override is needed):

```cpp
inline constexpr struct velocity : quantity_spec<speed, position_vector / duration> {} velocity;
```

### Representation types for vector and tensor quantities

As we specified before, the `quantity` class template is defined as follows:

```cpp
template<Reference auto R,
         RepresentationOf<get_quantity_spec(R).character> Rep = double>
class quantity;
```

The second template parameter is constrained with a `RepresentationOf` concept that checks if
the provided representation type satisfies the requirements for the character associated with this
quantity type.

Unfortunately, the current version of the C++ Standard Library does not provide any types that could
be used as a representation type for vector and tensor quantities. This is why users are on their
own here.

However, thanks to the provided customization points, any linear algebra library types can be used
as a vector or tensor quantity representation type.

To enable the usage of a user-defined type as a representation type for vector or tensor quantities,
user needs to provide a partial specialization of `is_vector` or `is_tensor` customization points.

For example, here is how it can be done for the [P1385](https://wg21.link/p1385) types:

```cpp
#include <matrix>

using la_vector = STD_LA::fixed_size_column_vector<double, 3>;

template<>
inline constexpr bool mp_units::is_vector<la_vector> = true;
```

With the above, we can use `la_vector` as a representation type for our quantity:

```cpp
Quantity auto q = la_vector{1, 2, 3} * isq::velocity[m / s];
```

Pleas note, that the following does not work:

```cpp
Quantity auto q1 = la_vector{1, 2, 3} * m / s;
Quantity auto q2 = isq::velocity(la_vector{1, 2, 3} * m / s);
quantity<isq::velocity[m/s]> q3{la_vector{1, 2, 3} * m / s};
```

In all the cases above, the SI unit `m / s` has an associated scalar quantity of
`isq::length / isq::time`. `la_vector` is not a correct representation type for a scalar quantity
so the construction fails.

### Hacking the character

Sometimes we want to use a vector quantity, but we don't care about its direction. For example,
the standard gravity acceleration constant always points down, so we might not care about this
in a particular scenario. In such a case, we may want to "hack" the library to allow scalar types
to be used as a representation type for scalar quantities.

For example, we can do the following:

```cpp
template<class T>
  requires mp_units::is_scalar<T>
inline constexpr bool mp_units::is_vector<T> = true;
```

which says that every type that can be used as a scalar representation is also allowed for vector
quantities.

Doing the above is actually not such a big "hack" as the [@ISO80000] explicitly allows it:

> A vector is a tensor of the first order and a scalar is a tensor of order zero.

Despite it being allowed by [@ISO80000], for type-safety reasons, we do not allow such a behavior
by default, and a user has to opt into such scenarios explicitly.


- exceptions and special cases for dimensionless quantities
- quantity arithmetics + quirks of modulo arithmetic and integral division
- custom representation types (improve safety, provide additional info like measurement, linear algebra, minimal requirements)
- representation type constraints
- non-negative quantities



## Dimensionless quantities

# Value conversions

# The affine space


# Unit-safe math



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
- id: PINT
  citation-label: Pint
  title: "Pint: makes units easy"
  URL: <https://pint.readthedocs.io/en/stable/index.html>
- id: SI
  citation-label: SI
  title: "SI Brochure: The International System of Units (SI)"
  URL: <https://www.bipm.org/en/publications/si-brochure>
---
