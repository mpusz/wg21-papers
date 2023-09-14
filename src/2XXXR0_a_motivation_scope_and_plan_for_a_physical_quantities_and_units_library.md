---
title: "A motivation, scope, and plan for a physical quantities and units library"
document: DXXXXR0
date: today
audience:
  - Library Evolution Working Group
author:
  - name: Mateusz Pusz ([Epam Systems](http://www.epam.com))
    email: <mateusz.pusz@gmail.com>
  - name: Dominik Berner
    email: <dominik.berner@gmail.com>
  - name: Johel Ernesto Guerrero Peña
    email: <johelegp@gmail.com>
  - name: Charles Hogg
    email: <charles.r.hogg@gmail.com>
  - name: Vincent Reverdy
    email: <vince.rev@gmail.com>
---


# Introduction

Several groups in the ISO C++ Committee reviewed the "P1935: A C++ Approach to Physical Units"
[@P1935R2] proposal in Belfast 2019 and Prague 2020. All those groups
expressed interest in the potential standardization of such a library and encouraged further
work. The authors also got valuable initial feedback that highly influenced the design of
the V2 version of the [@MP-UNITS] library.

In the following years, the library's authors scoped on getting more feedback from the production
and design and developed version 2 of the [@MP-UNITS] library that resolves the issues raised
by the users and Committee members. The features and interfaces of this version are close to
being the best we can get with the current version of the C++ language standard.

This paper is authored by not only the [@MP-UNITS] library developers but also by the authors
of other actively maintained similar libraries on the market and other active members of
the C++ physical quantities and units community who have worked on this subject for many years.
We join our forces to say with one voice that we deeply care about standardizing such
features as a part of the C++ Standard Library. Based on our long and broad experience in
the subject, we agree that the interfaces we will provide in the upcoming proposals are
the best we can get today in the C++ language.


# About Authors

## Dominik Berner

Author of [@SI_LIB].

## Johel Ernesto Guerrero Peña

Contributor to [@MP-UNITS] and many other Open Source projects.

## Charles Hogg

Author of [@AU].

## Mateusz Pusz

Mateusz got interested in the physical units subject while contributing to the [@LK8000]
Tactical Flight Computer Open Source project over 10 years ago. The project's code was far
from being "safe" in the C++ sense, and this is when Mateusz started to explore alternatives.

Through the following years, he tried to use several existing solutions, which were always
far from being user-friendly, so he also tried to write a better framework a few times from
scratch by himself.

Finally, with the availability of brand new Concepts TS in the gcc-7, the [@MP-UNITS] project
was created. It was designed with safety and user experience in mind. After many years
of working on the project, the [@MP-UNITS] library is probably the most modern and complete
solution in the C++ market.

Through the last few years, Mateusz has put much effort into building a community around physical
units. He provided many talks and workshops on this subject at various C++ conferences.
He also approached the authors of other actively maintained libraries to get their feedback
and invited them to work together to find and agree on the best solution for the C++ language.
This paper is the result of those actions.

## Vincent Reverdy

Author of [@P1930R0].


# Motivation

This chapter describes why we believe that physical quantities and units should be part of
a C++ Standard Library.

## Safety

It is no longer only the space industry or experienced pilots that benefit from the autonomous
operations of some machines. We live in a world where more and more ordinary people trust
machines with their lives daily. In the near future, we will be allowed to sleep while our
car autonomously drives us home from a late party. As a result, much more C++ engineers are
expected to write life-critical software today than it was a few years ago. Unfortunately,
there is insufficient training and experience in that domain, and the C++ language does not
change fast enough to enforce safe-by-construction code.

One of the areas where C++ can significantly improve the safety of applications being written
by thousands of developers is introducing a type-safe, well-tested, standardized way to handle
physical quantities and their units. The rationale for this is that people tend to have problems
communicating or using proper units both in the code and in daily life. Numerous
expensive failures and accidents happened because of using an invalid unit or a quantity type.

The most famous and probably the most expensive example in the software engineering domain is
the Mars Climate Orbiter that in 1999 failed to enter Mars orbit and crashed while entering
its atmosphere [@MARS_ORBITER]. This is not the only example here. People tend to confuse units
quite often. We see similar errors occurring in various domains over the years:

- On October 12, 1492, Christopher Columbus unintentionally discovered America because during
  his travel preparations, he mixed the Arabic mile with a Roman mile, which led to the wrong estimation
  of the equator and his expected travel distance [@COLUMBUS]
- In 1628, a new warship, Vasa, accidentally had an asymmetrical hull (being thicker on the port side
  than the starboard side), which was one of the reasons for her sinking less than a mile into her maiden
  voyage, with the death of 30 people on board. This asymmetry could be caused by the usage of
  different systems of measurement, as archaeologists have found four rulers used by the workers who
  built the ship. Two were calibrated in Swedish feet, which had 12 inches, while the other two
  measured Amsterdam feet, which had 11 inches [@VASA].
- Air Canada Flight 143 ran out of fuel on July 23, 1983, at an altitude of 41 000 feet
  (12 000 metres), midway through the flight because the fuel had been calculated in pounds
  instead of kilograms by the ground crew [@GIMLI_GLIDER].
- The British rock band Black Sabbath, during its Born Again tour in 1983, ordered a replica of Stonehenge
  as props for the scene, but unfortunately, they had to leave them in the storage area because, while
  submitting the order, their manager wrote dimensions down in meters when he meant feet, and the stones
  didn't fit the scene. "It cost a fortune to make but there was not a building on earth that you could
  fit it into" [@STONEHENGE].
- On April 15, 1999, Korean Air Cargo Flight 6316 crashed due to a miscommunication between
  pilots about desired flight altitude [@FLIGHT_6316]
- In February 2001, the Zoo crew built an enclosure for Clarence the Tortoise with a weight of
  250 pounds instead of 250 kilograms [@CLARENCE]
- In December 2003, one of the roller coaster’s cars at Tokyo Disneyland’s Space Mountain attraction
  suddenly derailed due to a broken axle caused by the confusion after upgrading the specification
  from imperial to metric units [@DISNEY]
- During construction of the Hochrheinbrücke bridge, to connect the small German town of Laufenburg
  with Swiss Laufenburg, the construction team made a sign error that resulted in the discrepancy
  of 54 cm between the two outer ends of the bridge [@HOCHRHEINBRÜCKE]
- An American company sold a shipment of wild rice to a Japanese customer, quoting a price of
  39 cents per pound, but the customer thought the quote was for 39 cents per kilogram [@WILD_RICE]
- A whole set of [@MEDICATION_DOSE_ERRORS]...

The safety subject is so vast and essential by itself that we dedicated a separate paper **P????**
that discusses all the nuances in detail.

## Vocabulary types

We standardized many library features mostly used in the implementation details
(fmt, ranges, random-number generators, etc.). However, we believe that the most important
role of the C++ Standard is to provide a standardized way of communication between different
vendors.

Let's imagine a world without `std::string` or `std::vector`. Every vendor has their version
of it, and of course, they are completely incompatible with each other. As a result, when someone
needs to integrate software from different vendors, it turns out to be nearly impossible.

Introducing `std::chrono::duration` and `std::chrono::time_point` improved the interfaces a lot,
but time is only one of many quantities that we deal with in our software on a daily basis.
We desperately need to be able to express more quantities and units in a standardized way so
different libraries get means to communicate with each other.

## Certification

Mission/life-critical projects or those for embedded devices often have to obey the safety norms
that care about software for safety-critical systems (e.g., ISO 61508 is a basic functional safety
standard applicable to all industries and ISO 26262 for automotive). As a result, such companies
often forbid third-party tooling that lacks official certification or does not obey all the
rules provided by MISRA. This is a huge issue as those companies typically are natural users of
physical quantities and units libraries.

## Complex and complicated

For example, suppose vendors can't use an Open Source library in a production project for
the above reasons. In that case, they are forced to write their own abstractions by themselves.
Besides being not cost and time-effective, it also happens that writing a physical quantities and
units library by yourself is far from easy. Doing this is complex and complicated, especially for
engineers who are not experts in the domain. There are many exceptional corner cases to cover
that most developers do not even realize before falling into a trap in production. As
a result, companies either use really simple and unsafe numeric wrappers or abandon the effort totally
and just use `double` to express quantity values which lead to safety issues by accidentally using
values representing the wrong quantity or having an incorrect unit.

## Standardizing existing practice

Plenty of physical units libraries have been on the market for many years. Through the years,
we have learned the best practices for handling specific cases in the domain. Various products
may have different scopes and support different C++ versions. Still, taking that aside, they use
really similar concepts, types, and operations under the hood. We know how to do those things already.

The authors of this paper developed and delivered multiple successful C++ libraries for this domain.
They joined forces and are working together to propose the best physical quantities and units
library we can get with the latest version of the C++ language. They spend their private time and
efforts hoping that the ISO C++ Committee will be willing to include such a feature in
the C++ Standard Library.


# Look and Feel

_Note: The code examples presented in this paper may not exactly reflect the final interface
design that is going to be proposed in the follow-up papers. We are still doing some small
fine-tuning to improve the library._

As no papers on the physical quantities and units interfaces have been submitted so far,
to allow the reader to better understand the features and scope of the library, this chapter
presents a few simple examples.

## Basic quantity equations

Let's start with a really simple example presenting basic operations that every physical quantities
and units library should provide:

```cpp
#include <mp-units/systems/si/si.h>

using namespace mp_units;
using namespace mp_units::si::unit_symbols;

// simple numeric operations
static_assert(10 * km / 2 == 5 * km);

// unit conversions
static_assert(1 * h == 3600 * s);
static_assert(1 * km + 1 * m == 1001 * m);

// derived quantities
inline constexpr auto kmph = km / h;
static_assert(1 * km / (1 * s) == 1000 * (m / s));
static_assert(2 * kmph * (2 * h) == 4 * km);
static_assert(2 * km / (2 * kmph) == 1 * h);

static_assert(2 * m * (3 * m) == 6 * m2);

static_assert(10 * km / (5 * km) == 2 * one);

static_assert(1000 / (1 * s) == 1 * kHz);
```

Try it in [the Compiler Explorer](https://godbolt.org/z/81Ev7qhTd).

## Hello Units

The next example serves as a showcase of various features available in the [@MP-UNITS] library.

```cpp
#include <mp-units/format.h>
#include <mp-units/ostream.h>
#include <mp-units/systems/international/international.h>
#include <mp-units/systems/isq/isq.h>
#include <mp-units/systems/si/si.h>
#include <iostream>

using namespace mp_units;

constexpr QuantityOf<isq::speed> auto avg_speed(QuantityOf<isq::length> auto d,
                                                QuantityOf<isq::time> auto t)
{
  return d / t;
}

int main()
{
  using namespace mp_units::si::unit_symbols;
  using namespace mp_units::international::unit_symbols;

  constexpr quantity v1 = 110 * (km / h);
  constexpr quantity v2 = 70 * mph;
  constexpr quantity v3 = avg_speed(220. * km, 2 * h);
  constexpr quantity v4 = avg_speed(isq::distance(140. * mi), 2 * isq::duration[h]);
  constexpr quantity v5 = v3.in(m / s);
  constexpr quantity v6 = value_cast<m / s>(v4);
  constexpr quantity v7 = value_cast<int>(v6);

  std::cout << v1 << '\n';                                   // 110 km/h
  std::cout << v2 << '\n';                                   // 70 mi/h
  std::cout << std::format("{}", v3) << '\n';                // 110 km/h
  std::cout << std::format("{:*^14}", v4) << '\n';           // ***70 mi/h****
  std::cout << std::format("{:%Q in %q}", v5) << '\n';       // 30.5556 in m/s
  std::cout << std::format("{0:%Q} in {0:%q}", v6) << '\n';  // 31.2928 in m/s
  std::cout << std::format("{:%Q}", v7) << '\n';             // 31
}
```

Try it in [the Compiler Explorer](https://godbolt.org/z/Tsesa1Pvq).

## Bridge across the Rhine

The following example codifies the history of a famous accident during the construction of a bridge across
the Rhine River between the German and Swiss parts of the town Laufenburg [@HOCHRHEINBRÜCKE].
It also nicely presents how [the Affine Space is being modeled in the library](https://mpusz.github.io/mp-units/latest/users_guide/framework_basics/the_affine_space/).


```cpp
#include <mp-units/ostream.h>
#include <mp-units/quantity_point.h>
#include <mp-units/systems/isq/space_and_time.h>
#include <mp-units/systems/si/si.h>
#include <iostream>

using namespace mp_units;
using namespace mp_units::si::unit_symbols;

constexpr struct amsterdam_sea_level : absolute_point_origin<isq::altitude> {
} amsterdam_sea_level;

constexpr struct mediterranean_sea_level : relative_point_origin<amsterdam_sea_level + isq::altitude(-27 * cm)> {
} mediterranean_sea_level;

using altitude_DE = quantity_point<isq::altitude[m], amsterdam_sea_level>;
using altitude_CH = quantity_point<isq::altitude[m], mediterranean_sea_level>;

template<auto R, typename Rep>
std::ostream& operator<<(std::ostream& os, quantity_point<R, altitude_DE::point_origin, Rep> alt)
{
  return os << alt.quantity_from_origin() << " AMSL(DE)";
}

template<auto R, typename Rep>
std::ostream& operator<<(std::ostream& os, quantity_point<R, altitude_CH::point_origin, Rep> alt)
{
  return os << alt.quantity_from_origin() << " AMSL(CH)";
}

int main()
{
  // expected bridge altitude in a specific reference system
  quantity_point expected_bridge_alt = amsterdam_sea_level + isq::altitude(330 * m);

  // some nearest landmark altitudes on both sides of the river
  // equal but not equal ;-)
  altitude_DE landmark_alt_DE = altitude_DE::point_origin + 300 * m;
  altitude_CH landmark_alt_CH = altitude_CH::point_origin + 300 * m;

  // artifical deltas from landmarks of the bridge base on both sides of the river
  quantity delta_DE = isq::height(3 * m);
  quantity delta_CH = isq::height(-2 * m);

  // artificial altitude of the bridge base on both sides of the river
  quantity_point bridge_base_alt_DE = landmark_alt_DE + delta_DE;
  quantity_point bridge_base_alt_CH = landmark_alt_CH + delta_CH;

  // artificial height of the required bridge pilar height on both sides of the river
  quantity bridge_pilar_height_DE = expected_bridge_alt - bridge_base_alt_DE;
  quantity bridge_pilar_height_CH = expected_bridge_alt - bridge_base_alt_CH;

  std::cout << "Bridge pillars height:\n";
  std::cout << "- Germany:     " << bridge_pilar_height_DE << '\n';
  std::cout << "- Switzerland: " << bridge_pilar_height_CH << '\n';

  // artificial bridge altitude on both sides of the river in both systems
  quantity_point bridge_road_alt_DE = bridge_base_alt_DE + bridge_pilar_height_DE;
  quantity_point bridge_road_alt_CH = bridge_base_alt_CH + bridge_pilar_height_CH;

  std::cout << "Bridge road altitude:\n";
  std::cout << "- Germany:     " << bridge_road_alt_DE << '\n';
  std::cout << "- Switzerland: " << bridge_road_alt_CH << '\n';

  std::cout << "Bridge road altitude relative to the Amsterdam Sea Level:\n";
  std::cout << "- Germany:     " << bridge_road_alt_DE - amsterdam_sea_level << '\n';
  std::cout << "- Switzerland: " << bridge_road_alt_CH - amsterdam_sea_level << '\n';
}
```

The above provides the following text output:

```text
Bridge pillars height:
- Germany:     27 m
- Switzerland: 3227 cm
Bridge road altitude:
- Germany:     330 m AMSL(DE)
- Switzerland: 33027 cm AMSL(CH)
Bridge road altitude relative to the Amsterdam Sea Level:
- Germany:     330 m
- Switzerland: 33000 cm
```

Try it in [the Compiler Explorer](https://godbolt.org/z/197s4jcvs).

## Storage Tank

Our last example estimates the process of filling a storage tank with some contents. It presents:

- [the importance of supporting more than one distinct quantity for the same kind](https://mpusz.github.io/mp-units/2.0/users_guide/framework_basics/systems_of_quantities/#system-of-quantities-is-not-only-about-kinds),
- [faster-than-lightspeed constants](https://mpusz.github.io/mp-units/2.0/users_guide/framework_basics/faster_than_lightspeed_constants/),
- how easy it is to [add custom quantity types](https://mpusz.github.io/mp-units/2.0/users_guide/framework_basics/systems_of_quantities/#defining-quantities)
when needed, and
- interoperability with `std::chrono::duration`.

```cpp
#include <mp-units/chrono.h>
#include <mp-units/format.h>
#include <mp-units/math.h>
#include <mp-units/systems/isq/mechanics.h>
#include <mp-units/systems/isq/space_and_time.h>
#include <mp-units/systems/si/constants.h>
#include <mp-units/systems/si/unit_symbols.h>
#include <mp-units/systems/si/units.h>
#include <cassert>
#include <chrono>
#include <iostream>
#include <numbers>
#include <utility>

// allows standard gravity (acceleration) and weight (force) to be expressed with scalar representation
// types instead of requiring the usage of Linear Algebra library for this simple example
template<class T>
  requires mp_units::is_scalar<T>
inline constexpr bool mp_units::is_vector<T> = true;

namespace {

using namespace mp_units;
using namespace mp_units::si::unit_symbols;

// add a custom quantity type of kind isq::length
inline constexpr struct horizontal_length : quantity_spec<isq::length> {} horizontal_length;

// add a custom derived quantity type of kind isq::area with a constrained quantity equation
inline constexpr struct horizontal_area : quantity_spec<isq::area, horizontal_length * isq::width> {} horizontal_area;

inline constexpr auto g = 1 * si::standard_gravity;
inline constexpr auto air_density = isq::mass_density(1.225 * (kg / m3));

class StorageTank {
  quantity<horizontal_area[m2]> base_;
  quantity<isq::height[m]> height_;
  quantity<isq::mass_density[kg / m3]> density_ = air_density;
public:
  constexpr StorageTank(const quantity<horizontal_area[m2]>& base, const quantity<isq::height[m]>& height) :
      base_(base), height_(height)
  {
  }

  constexpr void set_contents_density(const quantity<isq::mass_density[kg / m3]>& density)
  {
    assert(density > air_density);
    density_ = density;
  }

  [[nodiscard]] constexpr QuantityOf<isq::weight> auto filled_weight() const
  {
    const auto volume = isq::volume(base_ * height_);
    const QuantityOf<isq::mass> auto mass = density_ * volume;
    return isq::weight(mass * g);
  }

  [[nodiscard]] constexpr quantity<isq::height[m]> fill_level(const quantity<isq::mass[kg]>& measured_mass) const
  {
    return height_ * measured_mass * g / filled_weight();
  }

  [[nodiscard]] constexpr quantity<isq::volume[m3]> spare_capacity(const quantity<isq::mass[kg]>& measured_mass) const
  {
    return (height_ - fill_level(measured_mass)) * base_;
  }
};


class CylindricalStorageTank : public StorageTank {
public:
  constexpr CylindricalStorageTank(const quantity<isq::radius[m]>& radius,
                                   const quantity<isq::height[m]>& height) :
      StorageTank(quantity_cast<horizontal_area>(std::numbers::pi * pow<2>(radius)), height)
  {
  }
};

class RectangularStorageTank : public StorageTank {
public:
  constexpr RectangularStorageTank(const quantity<horizontal_length[m]>& length,
                                   const quantity<isq::width[m]>& width,
                                   const quantity<isq::height[m]>& height) :
      StorageTank(length * width, height)
  {
  }
};

}  // namespace


int main()
{
  const auto height = isq::height(200 * mm);
  auto tank = RectangularStorageTank(horizontal_length(1'000 * mm), isq::width(500 * mm), height);
  tank.set_contents_density(1'000 * isq::mass_density[kg / m3]);

  const auto duration = std::chrono::seconds{200};
  const quantity fill_time = value_cast<int>(quantity{duration});  // time since starting fill
  const quantity measured_mass = 20. * kg;                         // measured mass at fill_time

  const auto fill_level = tank.fill_level(measured_mass);
  const auto spare_capacity = tank.spare_capacity(measured_mass);
  const auto filled_weight = tank.filled_weight();

  const QuantityOf<isq::mass_change_rate> auto input_flow_rate = measured_mass / fill_time;
  const QuantityOf<isq::speed> auto float_rise_rate = fill_level / fill_time;
  const QuantityOf<isq::time> auto fill_time_left = (height / fill_level - 1 * one) * fill_time;

  const auto fill_ratio = fill_level / height;

  std::cout << std::format("fill height at {} = {} ({} full)\n", fill_time, fill_level, fill_ratio.in(percent));
  std::cout << std::format("fill weight at {} = {} ({})\n", fill_time, filled_weight, filled_weight.in(N));
  std::cout << std::format("spare capacity at {} = {}\n", fill_time, spare_capacity);
  std::cout << std::format("input flow rate = {}\n", input_flow_rate);
  std::cout << std::format("float rise rate = {}\n", float_rise_rate);
  std::cout << std::format("tank full E.T.A. at current flow rate = {}\n", fill_time_left.in(s));
}
```

The above code outputs:

```text
fill height at 200 s = 0.04 m (20 % full)
fill weight at 200 s = 100 g₀ kg (980.665 N)
spare capacity at 200 s = 0.08 m³
input flow rate = 0.1 kg/s
float rise rate = 0.0002 m/s
tank full E.T.A. at current flow rate = 800 s
```

Try it in [the Compiler Explorer](https://godbolt.org/z/bPf98s5qn).


# Scope

The tables below briefly highlight the expected scope and feature set. Each of the features will
be described in detail in the upcoming papers. To learn more right away and to be able to provide
and early feedback, we encourage everyone to check the documentation of the [@MP-UNITS].

<!-- markdownlint-disable MD013 -->

## Basic Framework

| Feature                                | Priority | Description                                                                                                                    |
|----------------------------------------|:--------:|--------------------------------------------------------------------------------------------------------------------------------|
| Core library                           |    1     | `std::quantity`, expression templates, dimensions, quantity specifications, units, _references_, and concepts for them         |
| Quantity Kinds                         |    1     | `frequency`, `activity`, and `modulation_rate`, or `energy` and `moment_of_force`, which should be distinct quantities         |
| Various quantities of the same kind    |    1     | `width`, `height`, `wavelength` (all of the kind `length`) should be distinct quantities                                       |
| Vector and tensor representation types |    2     | Support for quantities of vector and tensor representation types (no changes are needed for vectors and tensors of quantities) |
| Logarithmic units support              |    2     | Support for logarithmic units (e.g., decibel)                                                                                  |
| Polymorphic unit                       |   ???    | Runtime-known type-erased unit of a specified quantity                                                                         |

## The Affine Space

| Feature          | Priority | Description                                                |
|------------------|:--------:|------------------------------------------------------------|
| The Affine Space |    1     | `std::quantity_point`, absolute and relative point origins |

## Text Output

| Feature                | Priority | Description                                                           |
|------------------------|:--------:|-----------------------------------------------------------------------|
| `quantity` text output |    1     | Text output for quantity variables (number + unit)                    |
| Units text output      |    2     | Text output for unit variables                                        |
| Dimensions text output |    2     | Text output for dimension variables                                   |
| `std::format` support  |    1     | Custom grammar and support for all the standard formatting facilities |
| `std::ostream` support |    2     | Stream insertion operators support                                    |

_Note:_ No built-in support for text output of `quantity_point`.

## Text Input

As long as the C++ Standard doesn't provide a generic facility to parse localized text, we do not
plan to propose any support for doing that for physical quantities and their units.

## Systems of quantities

| Feature                           | Priority | Description                                                                                                                                                                                                                      |
|-----------------------------------|:--------:|----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| The most important ISQ quantities |    1     | Specification of the most commonly used ISQ quantities                                                                                                                                                                           |
| ISQ 3-6                           |    1     | Specification of the ISQ quantities specified in ISO/IEC 80000 parts 3 - 6 (Space and time, Mechanics, Thermodynamics, Electromagnetism)                                                                                         |
| ISQ 7-12                          |    3     | Specification of the ISQ quantities specified in ISO 80000 parts 7 - 12 (Light and radiation, Acoustics, Physical chemistry and molecular physics, Atomic and nuclear physics, Characteristic numbers, Condensed matter physics) |
| ISQ 13                            |    2     | Specification of the ISQ quantities specified in IEC 80000-13 (Information science and technology) + units                                                                                                                       |

## Systems of units

| Feature       | Priority | Description                                                                  |
|---------------|:--------:|------------------------------------------------------------------------------|
| SI            |    1     | All the units, prefixes, and symbols (including prefixed versions) of the SI |
| International |    1     | International yard and pound units system                                    |
| Imperial      |    2     | Imperial units system                                                        |
| USC system    |    2     | United States Customary system                                               |
| CGS system    |    2     | Centimetre-Gram-Second system                                                |
| Angular       |    3     | Strong angular quantities and units system                                   |
| IAU system    |    3     | International Astronomical Union units system                                |

## Utilities

| Feature               | Priority | Description                                                                                                                   |
|-----------------------|:--------:|-------------------------------------------------------------------------------------------------------------------------------|
| `std::chrono` support |    2     | Customization points that enable support for `std::chrono_duration` and `std::chrono_time_point` and other external libraries |
| Math                  |    2     | Common mathematical functions on quantities                                                                                   |
| Random                |    3     | Random number generators of quantities                                                                                        |

# Plan For Standardization

Having physical quantities and units support in C++ would be extremely useful for many C++ developers,
and ideally, we should ship it in C++29. We believe that it can be done, and we propose a plan
to get there. The plan below is, of course, not an irrevocable commitment. If things get delayed
or controversial for whatever reason, physical quantities and units (or some parts of it)
will miss the train and we will have to wait three more years. However, having a clear plan approved
by LEWG will help to keep the efforts on track.

| Meeting            | C++ Milestones                                     | Activities                                                                                                                                   |
|--------------------|----------------------------------------------------|----------------------------------------------------------------------------------------------------------------------------------------------|
| 2023.3 (Kona)      |                                                    | Paper on motivation, scope, and plan to LEWG<br>Paper about safety benefits and concerns to SG23<br>Paper about quantity arithmetics to SG6  |
| 2024.1 (Tokyo)     |                                                    | Paper on the Basic Framework (priority 1 features) to LEWG<br>Paper about text output to SG16<br>Paper about math utilities to SG6           |
| 2024.2 (Stockholm) |                                                    | Paper on the Basic Framework (priority 2 features) to SG6<br>Paper about the Affine Space to LEWG<br>Move quantity arithmetics paper to LEWG |
| 2024.3 (Wrocław)   | Last meeting for LEWG review of new C++26 features | Paper about `std::chrono` support to LEWG<BR>Move text output paper to LEWG<br>Move math utilities paper to LEWG                             |
| 2025.1             | Last meeting to send proposals to wording review   | Move Basic Framework (priority 2 features) to LEWG                                                                                           |
| 2025.2             | C++26 CD finalized                                 |                                                                                                                                              |
| 2025.3             |                                                    | Papers on systems to LEWG                                                                                                                    |
| 2026.1             | C++26 DIS finalized                                |                                                                                                                                              |
| 2026.2             | C++29 WP opens                                     | Wording for Basic Framework (priority 1 features) to LWG                                                                                     |
| 2026.3             |                                                    | Wording for Basic Framework (priority 2 features), the Affine Space, `std::chrono` support, and the text output to LWG                       |
| 2027.1             |                                                    | Wording for math utilities and systems to LWG                                                                                                |
| 2027.2             |                                                    |                                                                                                                                              |
| 2027.3             | Last meeting for LEWG review of new C++29 features |                                                                                                                                              |
| 2028.1             | Last meeting to send proposals to wording review   | Finalize wording review in LWG and merge into C++29 WP                                                                                       |
| 2028.2             | C++29 CS finalized                                 | Resolve any outstanding design/wording issues                                                                                                |
| 2028.3             |                                                    | Resolve NB comments                                                                                                                          |
| 2029.1             | C++29 DIS finalized                                | Resolve NB comments                                                                                                                          |

<!-- markdownlint-enable MD013 -->

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
- id: CLARENCE
  citation-label: Clarence
  author:
    - family: Chawkins
      given: Steve
  title: "Mismeasure for Measure"
  URL: <https://www.latimes.com/archives/la-xpm-2001-feb-09-me-23253-story.html>
- id: COLUMBUS
  citation-label: Columbus
  title: "Christopher Columbus"
  URL: <https://en.wikipedia.org/wiki/Christopher_Columbus>
- id: DISNEY
  citation-label: Disney
  title: "Cause of the Space Mountain Incident Determined at Tokyo Disneyland Park"
  URL: <https://web.archive.org/web/20040209033827/http://www.olc.co.jp/news/20040121_01en.html>
- id: FLIGHT_6316
  citation-label: Flight 6316
  title: "Korean Air Flight 6316 MD-11, Shanghai, China - April 15, 1999"
  URL: <https://ntsb.gov/news/press-releases/Pages/Korean_Air_Flight_6316_MD-11_Shanghai_China_-_April_15_1999.aspx>
- id: GIMLI_GLIDER
  citation-label: Gimli Glider
  title: "Gimli Glider"
  URL: <https://en.wikipedia.org/wiki/Gimli_Glider>
- id: HOCHRHEINBRÜCKE
  citation-label: Hochrheinbrücke
  title: "An embarrassing discovery during the construction of a bridge"
  URL: <https://www.normaalamsterdamspeil.nl/wp-content/uploads/2015/03/website_bridge.pdf>
- id: LK8000
  citation-label: LK8000
  title: "LK8000 - Tactical Flight Computer"
  URL: <http://lk8000.it>
- id: MARS_ORBITER
  citation-label: Mars Orbiter
  title: "Mars Climate Orbiter"
  URL: <https://en.wikipedia.org/wiki/Mars_Climate_Orbiter>
- id: MEDICATION_DOSE_ERRORS
  citation-label: Medication dose errors
  author:
    - family: Mulac
      given: Alma
    - family: Hagesaether
      given: Ellen
    - family: Granas
      given: Anne Gerd
  title: "Medication dose calculation errors and other numeracy mishaps in hospitals: Analysis of the nature and enablers of incident reports"
  URL: <https://onlinelibrary.wiley.com/doi/10.1111/jan.15072>
- id: MP-UNITS
  citation-label: mp-units
  title: "mp-units - A Physical Quantities and Units library for C++"
  URL: <https://mpusz.github.io/mp-units>
- id: SI_LIB
  citation-label: SI library
  title: SI - Type safety for physical units"
  URL: <https://si.dominikberner.ch/doc>
- id: STONEHENGE
  citation-label: Stonehenge
  author:
    - family: Robey
      given: Tim
  title: "Tiny stones, giant laughs: the story behind Spinal Tap's Stonehenge"
  URL: <https://www.telegraph.co.uk/films/2020/05/01/tiny-stones-giant-laughs-story-behind-spinal-taps-stonehenge>
- id: VASA
  citation-label: Vasa
  author:
    - family: Chatterjee
      given: Rhitu
    - family: Mullins
      given: Lisa
  title: "New Clues Emerge in Centuries-Old Swedish Shipwreck"
  URL: <https://theworld.org/stories/2012-02-23/new-clues-emerge-centuries-old-swedish-shipwreck>
- id: WILD_RICE
  citation-label: Wild Rice
  title: "Manufacturers, exporters think metric"
  URL: <https://www.bizjournals.com/eastbay/stories/2001/07/09/focus3.html>
---
