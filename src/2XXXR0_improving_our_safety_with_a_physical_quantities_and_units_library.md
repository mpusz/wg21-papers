---
title: "Improving our safety with a physical quantities and units library"
document: DXXXXR0
date: today
audience:
  - SG23 Safety and Security
author:
  - name: Mateusz Pusz ([Epam Systems](http://www.epam.com))
    email: <mateusz.pusz@gmail.com>
---


# Introduction

One of the areas where C++ can significantly improve the safety of applications being written
by thousands of developers is introducing a type-safe, well-tested, standardized way to handle
physical quantities and their units. The rationale is that people tend to have problems
communicating or using proper units in code and daily life.

This paper scopes on the security aspects of introducing such a library to the C++ language.
In the following chapters, we will describe which industries are desperately looking for such
standardized solutions, enumerate some failures and accidents caused by misinterpretation of
quantities and units in human history, review all the features of such a library that improve
the safety of our code, and also discuss potential safety issues that the library does not
prevent against.

_Note: This paper refers to practices used in the [@MP-UNITS] library and presents code examples
using its interfaces. Those may not exactly reflect the final interface design that is going
to be proposed in the follow-up papers. We are still doing some small fine-tuning to improve
the library._


# The Future Is Here

Not that long ago, we watched SciFi movies about the future Earth where people were entering
a car with no driver inside, and it autonomously drove them to the required destination.
Then, it was something so futuristic and hard to imagine. Today, it slowly becomes a reality
of our daily life.

It is no longer only the space industry or airline pilots that benefit from the autonomous
operations of some machines. We live in a world where more and more ordinary people trust
machines with their lives daily. Soon, we will be allowed to sleep while our
car autonomously drives us home from a late party. As a result, many more C++ engineers are
expected to write life-critical software today than a few years ago.
Unfortunately, there is insufficient training and experience in this domain and the C++ language
does not change fast enough to enforce a safe-by-construction code.


# Affected Industries

When people think about industries that could use physical quantities and unit libraries, they
think of a few companies related to aerospace, autonomous cars, or embedded industries. That
is all true, but there are many other potential users for such a library.

Here is a list of some less obvious candidates:

- manufacturing,
- maritime industry,
- freight transport,
- military,
- 3D design,
- robotics,
- national laboratories,
- scientific institutions and universities,
- all kinds of navigation and charting,
- GUI frameworks,
- finance (including HFT),
- and many more...

As we can see, the applications of such a library are so vast. Most users benefit from strong
types and automated conversions for various quantities and units. However, the library also provides
affine space abstractions, which may also be used in many other domains.


# Mismeasure for Measure

Human history knows many expensive failures and accidents caused by mistakes in calculations involving
different physical units. The most famous and probably the most expensive example in the software
engineering domain is the Mars Climate Orbiter that in 1999 failed to enter Mars orbit and crashed
while entering its atmosphere [@MARS_ORBITER]. This is one of many examples here. People tend to
confuse units quite often. We see similar errors occurring in various domains over the years:

- On October 12, 1492, Christopher Columbus unintentionally discovered America because, during
  his travel preparations, he mixed the Arabic mile with a Roman mile, which led to the wrong estimation
  of the equator and his expected travel distance [@COLUMBUS].
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
  pilots about the desired flight altitude [@FLIGHT_6316].
- In February 2001, the Zoo crew built an enclosure for Clarence the Tortoise with a weight of
  250 pounds instead of 250 kilograms [@CLARENCE].
- In December 2003, one of the roller coaster’s cars at Tokyo Disneyland’s Space Mountain attraction
  suddenly derailed due to a broken axle caused by confusion after upgrading the specification
  from imperial to metric units [@DISNEY].
- During the construction of the Hochrheinbrücke bridge to connect the small German town of Laufenburg
  with Swiss Laufenburg, the construction team made a sign error that resulted in a discrepancy
  of 54 cm between the two outer ends of the bridge [@HOCHRHEINBRÜCKE].
- An American company sold a shipment of wild rice to a Japanese customer, quoting a price of
  39 cents per pound, but the customer thought the quote was for 39 cents per kilogram [@WILD_RICE].
- A whole set of [@MEDICATION_DOSE_ERRORS]...


# When a Library Is Not Used

In this chapter, we are going to review typical safety issues related to physical quantities and units
in the C++ code when a proper library is not used. Even though all the examples come from the
Open Source projects, expensive revenue-generating production source code often is similar.

## The proliferation of `double`

It turns out that in the C++ software, most of our calculations in the physical quantities and units
domain are handled with fundamental types like `double`. Code like below is a typical example here:

```cpp
double GlidePolar::MacCreadyAltitude(double MCREADY,
                                     double Distance,
                                     const double Bearing,
                                     const double WindSpeed,
                                     const double WindBearing,
                                     double *BestCruiseTrack,
                                     double *VMacCready,
                                     const bool isFinalGlide,
                                     double *TimeToGo,
                                     const double AltitudeAboveTarget=1.0e6,
                                     const double cruise_efficiency=1.0,
                                     const double TaskAltDiff=-1.0e6);
```

[Original code here](https://github.com/LK8000/LK8000/blob/af404168ff5f92b03ab0c5db336ed8f01a792cda/Common/Header/McReady.h#L7-L21).


## The proliferation of magic numbers

There are a lot of constants and conversion factors involved in the quantity equations. Source code
responsible for such computations is often trashed with magic numbers:

```cpp
double AirDensity(double hr, double temp, double abs_press)
{
  return (1/(287.06*(temp+273.15)))*(abs_press - 230.617 * hr * exp((17.5043*temp)/(241.2+temp)));
}
```

[Original code here](https://github.com/LK8000/LK8000/blob/af404168ff5f92b03ab0c5db336ed8f01a792cda/Common/Source/Library/PressureFunctions.cpp#L134-L136).


## The proliferation of conversion macros

The lack of automated unit conversions often results in handwritten conversion functions or macros
that are spread everywhere among the code base:

```cpp
#ifndef PI
static const double PI = (4*atan(1));
#endif
#define EARTH_DIAMETER    12733426.0    // Diameter of earth in meters
#define SQUARED_EARTH_DIAMETER  162140137697476.0 // Diameter of earth in meters (EARTH_DIAMETER*EARTH_DIAMETER)
#ifndef DEG_TO_RAD
#define DEG_TO_RAD  (PI / 180)
#define RAD_TO_DEG  (180 / PI)
#endif

#define NAUTICALMILESTOMETRES (double)1851.96
#define KNOTSTOMETRESSECONDS (double)0.5144

#define TOKNOTS (double)1.944
#define TOFEETPERMINUTE (double)196.9
#define TOMPH   (double)2.237
#define TOKPH   (double)3.6

// meters to.. conversion
#define TONAUTICALMILES (1.0 / 1852.0)
#define TOMILES         (1.0 / 1609.344)
#define TOKILOMETER     (0.001)
#define TOFEET          (1.0 / 0.3048)
#define TOMETER         (1.0)
```

[Original code here](https://github.com/LK8000/LK8000/blob/052bbc20a106fda4db41874e788e39020fb86512/Common/Header/Defines.h#L901-L924).


## Lack of consistency

If we not only lack strong types to isolate the abstractions from each other but also lack discipline
to keep our code consistent, we end up in an awful place:

```cpp
void DistanceBearing(double lat1, double lon1,
                     double lat2, double lon2,
                     double *Distance, double *Bearing);

double DoubleDistance(double lat1, double lon1,
                      double lat2, double lon2,
                      double lat3, double lon3);

void FindLatitudeLongitude(double Lat, double Lon,
                           double Bearing, double Distance,
                           double *lat_out, double *lon_out);

double CrossTrackError(double lon1, double lat1,
                       double lon2, double lat2,
                       double lon3, double lat3,
                       double *lon4, double *lat4);

double ProjectedDistance(double lon1, double lat1,
                         double lon2, double lat2,
                         double lon3, double lat3,
                         double *xtd, double *crs);
```

[Original code here](https://github.com/LK8000/LK8000/blob/af404168ff5f92b03ab0c5db336ed8f01a792cda/Common/Header/NavFunctions.h#L7C1-L27).


# Safety Features

This chapter will describe the features that enforce safety in our code bases. We will start
with obvious things but then will move to probably less known benefits of using physical quantities
and units libraries. This chapter also serves as a proof that it is not easy to implement such a
library correctly, and there are many cases where lack of experience or time for the development of
such a utility may lead to safety issues as well.

Before we go through all the features, it is essential to note that they do not introduce any runtime
overhead over the raw unsafe code doing the same thing. That is a massive benefit of C++ compared
to other programming languages (e.g., Python, Java, etc.).

## Unit conversions

The first thing that comes to our mind when discussing the safety of such libraries is
automated unit conversions. This is probably the most important subject here. We learned
about its huge benefits long ago thanks to the `std::chrono::duration` that made conversions of
time durations error-proof.

Unit conversions are typically performed either via a converting constructor or a dedicated conversion
function:

```cpp
auto q1 = 5 * km;
std::cout << q1.in(m) << '\n';
quantity<si::metre, int> q2 = q1;
```

Such a feature benefits from the fact that the library knows about the magnitudes of source and
destination units at compile-time and may use that information to calculate and apply a conversion
factor automatically for the user.

In `std::chrono::duration`, the magnitude of a unit is always expressed with `std::ratio`. This is
not enough for a general-purpose physical units library. Some of the derived units have great
or tiny ratios. The difference from the base units is so huge that it cannot be expressed with
`std::ratio`, which is implemented in terms of `std::intmax_t`. This makes it impossible to define
units like electronvolt (eV) where 1eV = 1.602176634×10<sup>−19</sup> J or Dalton where
1 Da = 1.660539040(20)×10<sup>−27</sup> kg. Moreover, some conversions, such as radian to a degree,
require a conversion factor based on an irrational number like pi.

## Preventing truncation of data

The second safety feature of such libraries is preventing truncation of quantity value. If we try
similar, but this time opposite, operations to the above, both conversions should fail to compile:

```cpp
auto q1 = 5 * m;
std::cout << q1.in(km) << '\n';
quantity<si::kilo<si::metre>, int> q2 = q1;
```

We can't preserve the value of a source unit when we convert
to a unit with a lower resolution while using an integral representation type for a quantity.

_Please note that it is always assumed that one can convert a quantity into another one with a unit
of a higher resolution. There is no protection against overflow of the representation type.
In case the target quantity ends up with a value bigger than the representation type can handle,
we will be facing Undefined Behavior._

The solution to make the above conversion is to use a floating-point representation type:

```cpp
auto q1 = 5. * m;
std::cout << q1.in(km) << '\n';
quantity<si::kilo<si::metre>> q2 = q1;
```

or:

```cpp
auto q1 = 5 * m;
std::cout << value_cast<double>(q1).in(km) << '\n';
quantity<si::kilo<si::metre>> q2 = q1;  // double by default
```

_The [@MP-UNITS] library follows `std::chrono::duration` logic and treats floating-point types as
value-preserving._

Another possibility would be to force such a truncating conversion explicitly from the code:

```cpp
auto q1 = 5 * m;
std::cout << value_cast<km>(q1) << '\n';
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

## Preventing surprises during units composition

One of the most important requirements for a good physical quantities and units library is to implement
units in such a way that they compose. With that, one can easily create any derived unit using
a simple unit equation on other base or derived units. For example:

```cpp
constexpr auto kmph = km / h;
```

This is a really nice and commonly used feature which often leads inexperienced users to a surprise
when they write the following code:

```cpp
quantity q = 60 * km / h;
```

The above and the following examples compile fine in [@BOOST-UNITS] and [@PINT]. However, we
believe this is an error, and there are good reasons for this.

First, let's consider the following expression:

```cpp
auto q = 60 * km / 2 * h;
```

This looks like like `30 km/h`, right? But it is not. If the above code was allowed, thanks to the
operators' associativity, it would result in `30 km⋅h`. In case we want to divide `60 * km` by `2 * h`
a parenthesis is needed:

```cpp
auto q = 60 * km / (2 * h);
```

Another surprising issue could result from the following code:

```cpp
template<typename T>
auto make_length(T v) { return v * si::metre; }

auto v = 42;
auto q = make_length(v);
```

The above might look like a good idea, but let's consider what would happen if the user provided
an already existing quantity:

```cpp
auto v = 42 * m;
auto q = make_length(v);
```

Because of the above reasons, multiplying or dividing a quantity by a unit should not be supported.
In a sound library, trying to do such an operation should be detected at compile-time.

Coming back to our first example, as a side effect of the above rules, in order to create
a quantity of `60 km/h`, we need to use parenthesis for the entire unit:

```cpp
quantity q = 60 * (km / h);
```

## The affine space

The affine space has two types of entities:

- point - a position specified with coordinate values (i.e., location, address, etc.)
- vector - the difference between two points (i.e., shift, offset, displacement, duration, etc.)

One can do a limited set of operations in affine space on points and vectors. This greatly
helps to prevent quantity equations that do not have physical sense.

People often think that affine space is needed only to model temperatures and maybe time points
(following [`std::chrono::time_point`](https://en.cppreference.com/w/cpp/chrono/time_point)).
Still, the applicability of this domain is much wider.

For example, if we would like to model a Mount Everest climbing expedition, we would deal with
two kinds of altitude-related entities. The first would be absolute altitudes above the mean sea
level (points) like base camp altitude, mount peak altitude, etc. The second one would be the
heights of daily climbs (vectors). As long as it makes physical sense to add heights of daily climbs,
there is no sense in adding altitudes. What does adding the altitude of a base camp and
the mountain peak mean after all?

Modeling such affine space entities with `quantity` (vector) and `quantity_point` (point) class
templates improve overall project safety by eliminating accidental equations at compile time.

## `explicit` is not explicit enough

Consider the following structure and a code using it:

```cpp
struct X {
  std::vector<std::chrono::milliseconds> vec;
  // ...
};
```

```cpp
X x;
x.vec.emplace_back(42);
```

Everything works fine for years until, at some point, someone changes the structure to:

```cpp
struct X {
  std::vector<std::chrono::microseconds> vec;
  // ...
};
```

The code continues to compile fine, but all the calculations are off now. This is why a good
physical quantities and units library should not provide an explicit quantity constructor taking
a raw value.

To solve this issue, a quantity in the [@MP-UNITS] library always requires information about both
a number and a unit during construction:

```cpp
struct X {
  std::vector<quantity<si::milli<si::seconds>>> vec;
  // ...
};
```

```cpp
X x;
x.vec.emplace_back(42 * ms);
```

For consistency and to prevent similar safety issues, the `quantity_point` in the [@MP-UNITS] library
can't be created from a standalone value of a `quantity`. Such a point has to always
be associated with an explicit origin:

```cpp
quantity_point qp1 = mean_sea_level + 42 * m;
quantity_point qp2 = si::ice_point + 21 * deg_C;
```

## Obtaining a numerical value of a quantity

Continuing our previous example, let's assume that we have an underlying "legacy" API that
requires us to pass a raw numerical value of a quantity and that we do the following to use it:

```cpp
void legacy_func(std::int64_t seconds);
```

```cpp
X x;
x.vec.emplace_back(42s);
legacy_func(x.vec[0].count());
```

The following code is incorrect. Even though the duration stores a quantity equivalent to 42 s, it
is not internally stored exactly in this unit (either microseconds or milliseconds, depending on which
of the interfaces from the previous chapter is the current one at this moment). Such issues
can be prevented with the usage of `std::chrono::duration_cast`:

```cpp
legacy_func(duration_cast<seconds>(x.vec[0]).count());
```

However, users often forget about this step, especially when, at the moment of writing such code,
the duration stores the underlying raw value in the expected unit. But as we know, the interface can
be refactored at any point to use a different unit, and the code using an underlying numerical value
without the usage of an explicit cast will become incorrect.

To prevent such safety issues, the [@MP-UNITS] library exposes only the interface that returns
a quantity numerical value in the required unit to ensure that no data truncation happens:

```cpp
X x;
x.vec.emplace_back(42 * s);
legacy_func(x.vec[0].numerical_value_in(si::second));
```

or in case we are fine with data truncation:

```cpp
X x;
x.vec.emplace_back(42 * s);
legacy_func(x.vec[0].force_numerical_value_in(si::second));
```

As the above member functions may need to do a conversion to provide a value in the expected unit,
their results are returned as prvalues.

## Preventing dangling references

Besides returning prvalues, sometimes users need to get an actual reference to the underlying
numerical value stored in a `quantity`. For those cases [@MP-UNITS] library exposes
`quantity::numerical_value_ref_in(Unit)` that participates in overload resolution only:

- for lvalues (rvalue reference qualified overload is explicitly deleted),
- when provided `Unit` has the same magnitude as the one currently used by the quantity.

The first condition above removes the possibility of dangling references. We want to increase the
chances that the reference/pointer provided to an underlying API remains valid for the time of its
usage. Performance aspects for a `quantity` type are secondary here as we expect the majority
(if not all) of representation types to be cheap to copy, so we do not need to optimize for moving
the value out from the temporary object. With the condition satisfied, the following code doesn't compile:

```cpp
void legacy_func(const int& seconds);
```

```cpp
legacy_func((4 * s + 2 * s).numerical_value_ref_in(si::second));
```

The [@MP-UNITS] library goes one step further by implementing all compound assignment,
pre-increment, and pre-decrement operators as non-member functions that preserve the initial value
category. Thanks to that, the following will also not compile:

```cpp
quantity<si::second, int> get_duration();
```

```cpp
legacy_func((4 * s += 2 * s).numerical_value_ref_in(si::second));
legacy_func((++get_duration()).numerical_value_ref_in(si::second));
```

The second condition above enables the usage of various equivalent units. For example, `J` is
equivalent to `N * m`, and `kg * m2 / s2`. As those have the same magnitude, it does not
matter exactly which one is being used here, as the same numerical value
should be returned for all of them.

Here are a few examples provided by our users where enabling quantity type to return
a reference to its underlying numerical value is required:

- interoperability with the [Dear ImGui](https://github.com/ocornut/imgui/blob/19ae142bdddf9fcb840549b4b1279739a36c3fa6/imgui.h#L551):

    ```cpp
    IMGUI_API bool DragInt(const char* label, int* v,
                           float v_speed = 1.0f, int v_min = 0, int v_max = 0,
                           const char* format = "%d", ImGuiSliderFlags flags = 0);  // If v_min >= v_max we have no bound
    ```

    ```cpp
    ImGui::DragInt("Frames", &frame_frequency.value.numerical_value_ref_in(Hz), 1,
                   frame_frequency.min.numerical_value_in(Hz), 
                   frame_frequency.max.numerical_value_in(Hz), 
                   "%d Hz");
    ```

- obtaining a temperature via the C library:

    ```cpp
    // read_temperature is in the BSP defined as 
    void read_temperature(float* temp_in_celsius);
    ```
    
    ```cpp
    using Celsius_point = quantity_point<isq::Celsius_temperature[deg_C], si::ice_point, float>;

    Celsius_point temp;
    read_temperature(&temp.quantity_ref_from(si::ice_point).numerical_value_ref_in(si::degree_Celsius));
    ```

As we can see in the second example, `quantity_point` also provides lvalue-ref-qualified
`quantity_ref_from(PointOrigin)` member function that returns a reference to the underlying `quantity`
type stored inside. Also, for reasons similar to the ones described in the previous chapter, this
function requires that the argument provided by the user is the same as the origin of a quantity point.

## Quantity kinds





## quantity spec conversions and common_quantity_spec



## non-negative quantities


## Safe equations (arithmetic, quantity character, multiplication, division, dot, cross, norm)





https://github.com/mpusz/mp-units/issues/412#issuecomment-1412806744
https://github.com/mpusz/mp-units/issues/412#issuecomment-1412828928


# Safety Pitfalls

## Integer division

```cpp
quantity q1 = 2 * km / (5 * h);
quantity q2 = 2 * h / (30 * min);
```

Sometimes hidden in a ratio...

## Lack of safe numeric types

Integers can overflow on arithmetics. This has already caused some expensive failures in engineering
[@ARIANE].

Integers can also be truncated during assignment to a narrower type.


Floating-point types may lose precision during assignment to a narrower type.
Conversion from `std::int64_t` to `double` may also be truncating.

# Acknowledgements

Special thanks and recognition goes to [Epam Systems](http://www.epam.com) for supporting
Mateusz's membership in the ISO C++ Committee and the production of this proposal.


<!-- markdownlint-disable -->

---
references:
- id: ARIANE
  citation-label: Ariane flight V88
  title: "Ariane flight V88"
  URL: <https://en.wikipedia.org/wiki/Ariane_flight_V88>
- id: BOOST-UNITS
  citation-label: Boost.Units
  author:
    - family: Schabel
      given: Matthias C.
    - family: Watanabe
      given: Steven
  title: "Boost.Units"
  URL: <https://www.boost.org/doc/libs/1_83_0/doc/html/boost_units.html>
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
- id: PINT
  citation-label: Pint
  title: "Pint: makes units easy"
  URL: <https://pint.readthedocs.io/en/stable/index.html>
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
