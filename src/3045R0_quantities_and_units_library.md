---
title: "Quantities and units library"
document: D3045R0
date: today
audience:
  - SG6 Numerics
  - SG16 Unicode
author:
  - name: Mateusz Pusz ([Epam Systems](http://www.epam.com))
    email: <mateusz.pusz@gmail.com>
  - name: Dominik Berner
    email: <dominik.berner@gmail.com>
  - name: Johel Ernesto Guerrero Peña
    email: <johelegp@gmail.com>
  - name: Chip Hogg ([Aurora Innovation](https://aurora.tech/))
    email: <charles.r.hogg@gmail.com>
  - name: Nicolas Holthaus
    email: <nholthaus@gmail.com>
  - name: Roth Michaels ([Native Instruments](https://www.native-instruments.com))
    email: <isocxx@rothmichaels.us>
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

During the Kona 2023 ISO C++ Committee meeting we got a repeating feedback that there should
be a one, big, unified paper with all the contents inside. Addressing this requirement, this
paper not only adds a detailed design description, but also includes the most important parts
of [@P2980R1], [@P2981R1], and [@P2982R1].


# Terms and definitions

This document consistently uses the official metrology vocabulary defined in the [@ISO-GUIDE]
and [@BIPM-VIM].


# About authors

## Dominik Berner

Dominik is a strong believer that the C++ language can provide very high safety guarantees when
programming through strong typing; a type error caught during compilation saves hours of
debugging. For the last 15 years, he has mainly coded in C++ and actively follows its evolution
through the new standards.

When working on regulated projects at Med-Tech, there usually were very tight requirements on
which data types were to be used for what, which turned out to be lists of primitives to be
memorized by each developer. However, throughout his career, Dominik spent way too many hours
debugging and fixing issues caused by these types being incorrect. In an attempt to bring
a closer semantic meaning to these lists, he eventually wrote [@SI_LIB] as a side project.

While [@SI_LIB] provides many useful features, such as type-safe conversion between physical
quantities as well as zero-overhead computation for values of the same units, there are some
shortcomings which would require major rework. Instead of creating yet another library,
Dominik decided to join forces with the other authors of this paper to push for standardizing
support for more type-safety for physical quantities. He hopes that this will eventually lead
to a safer and more robust C++ and open many more opportunities for the language.

## Johel Ernesto Guerrero Peña

Johel got interested in the units domain while writing his first hundred lines of game development.
He got up to opening the game window, so this milestone was not reached until years later.
Instead, he looked for the missing piece of abstraction,
called "pixel" in the GUI framework, but modeled as an `int`.
He found out about [@NHOLTHAUS-UNITS], and
got fascinated with the idea of a library that succinctly allows expressing his domain's units
(<https://github.com/nholthaus/units/issues/124#issuecomment-390773279>).

Johel became a contributor to [@NHOLTHAUS-UNITS] v3 from 2018 to 2020.
He improved the interfaces and implementations by remodeling them after `std::chrono::duration`.
This included parameterizing the representation type with a template parameter instead of a macro.
He also improved the error messages by mapping a list of types to an user-defined name.

By 2020, Johel had been aware of [@MP-UNITS] v0 `quantity<dim_length, length, int>`, put off by its verbosity.
But then, he watched a talk by Mateusz Pusz on [@MP-UNITS].
It described how good error messages was a stake in the ground for the library.
Thanks to his experience in the domain, Johel was convinced that [@MP-UNITS] was the future.

Since 2020, Johel has been contributing to [@MP-UNITS].
He added `quantity_point`, the generalization of `std::chrono::time_point`, closing #1.
He also added `quantity_kind`, which explored the need of representing distinct quantities of the same dimension.
To help guide its evolution, he's been constantly pointing in the direction of [@BIPM-VIM] as a source of truth.
And more recently, to the ISO/IEC 80000 series, also helping interpret it.

Computing systems engineer.
(C++) programmer since 2014.
Lives at HEAD with C++Next and good practices.
Performs in-depth code reviews of familiarized code bases.
Has an eye for identifying automation opportunities, and acts on them.
Mostly at <https://github.com/JohelEGP/>.

## Charles Hogg

Chip Hogg is a Staff Software Engineer on the Motion Planning Team at Aurora Innovation, the
self-driving vehicle company that is developing the Aurora Driver.  After obtaining his PhD in
Physics from Carnegie Mellon in 2010, he was a postdoctoral researcher and then staff scientist at
the National Institute of Standards and Technology (NIST), doing Bayesian data analysis. He joined
Google in 2012 as a software engineer, leaving in 2016 to work on autonomous vehicles at Uber's
Advanced Technologies Group (ATG), where he stayed until their acquisition by Aurora in 2021.

Chip built his first C++ units library at Uber ATG in 2018, where he first developed the concept of
unit-safe interfaces.  At Aurora in 2021, he ported over only the test cases, writing a new and more
powerful units library from scratch.  This included novel features such as vector space magnitudes,
and an adaptive conversion policy which guards against overflow in integers.

He soon realized that there was a much broader need for Aurora's units library.  No publicly
available units library for C++14 or C++17 could match its ergonomics, developer experience, and
performance.  This motivated him to create [@AU] in 2022: a new, zero-dependency units library,
which was a drop-in replacement for Aurora's original units library, but offered far more composable
interfaces, and was built on simpler, stronger foundations.  Once Au proved its value internally,
Chip migrated it to a separate repository and led the open-sourcing process, culminating in its
public release in 2023.

While Au provides excellent ergonomics and robustness for pre-C++20 users, Chip also believes the
C++ community would benefit from a standard units library.  For that reason, he has joined forces
with the mp-units project, contributing code and design ideas.

## Nicolas Holthaus

Nicolas graduated Summa Cum Laude from Northwestern University with a B.S. in  Computer Engineering.
He worked for several years at the United States Naval Air Warfare Center - Manned Flight Simulator -
designing real-time C++ software for aircraft survivability simulation. He has subsequently continued
in the field at various start-ups, MIT Lincoln Laboratory, and most recently, STR (Science and
Technology Research).

Nicolas became obsessed with dimensional analysis as a high school JETS team member after learning
that the $125M Mars Climate Orbiter was destroyed due to a simple feet-to-meters miscalculation. He
developed the widely adopted C++ [@NHOLTHAUS-UNITS] library based on the findings of the 2002 white
paper "Dimensional Analysis in C++" by Scott Meyers. Astounded that no one smarter had already
written such a library, he continued with `units` 2.0 and 3.0 based on modern C++. Those libraries
have been extensively adopted in many fields, including modeling & simulation, agriculture, and
geodesy.

In 2023, recognizing the limits of `units`, he joined forces with Mateusz Pusz in his effort to
standardize his evolutionary dimensional analysis library, with the goal of providing the
highest-quality dimensional analysis to all C++ users via the C++ standard library.

## Roth Michaels

Roth Michaels is a Principal Software Engineer at
[Native Instruments](https://www.native-instruments.com), a leading
manufacturer of audio, and music, software and hardware.  Working in
this domain, he has been involved with the creation of ad hoc typed
quantities/units for digital signal processing and GUI library
use-cases.  Seeing both the complexity of development and practical uses
where developers need to leave the safety of these simple wrappers
encouraged Roth to explore various quantity/units libraries to see if
they would apply to this domain.  He has been doing research into
defining and using digital audio and music domain-specific quantities
and units using first [@MP-UNITS] as proposed in [@P1935R2] and the new
V2 library described in this paper.

Before working for Native Instruments, Roth worked as a consultant in
multiple industries using a variety of programming languages.  He was
involved with the Swift Evolution community in its early days before
focusing primarily on C++ after joining
[iZotope](https://www.izotope.com) and now Native Instruments.

Holding a degree in music composition, Roth has over a decade of
experience working with quantities and units of measure related to
music, digital signal processing, analog audio, and acoustics.  He has
joined the [@MP-UNITS] project as a domain expert in these areas and to
provide perspective on logarithmic and non-linear quantity/unit
relationships.

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

Vincent is an astrophysicist, computer scientist, and a member of the French delegation to
the ISO C++ Committee, currently working as a full researcher at the French National Centre
for Scientific Research (CNRS). He has been interested for years in units and quantities
for programming languages to ensure higher levels of both expressivity and safety in computational
physics codes. Back in 2019, he authored [@P1930R0] to provide some context of what could
be a quantity and unit library for C++.

After designing and implementing several Domain-Specific Language (DSL) demonstrators dedicated
to units of measurements in C++, he became more interested in the theoretical side of
the problem. Today, one of his research activities is dedicated to the mathematical formalization
of systems of quantities and systems of units as an interdisciplinary problem between physics,
mathematics, and computer science.


# Motivation

This chapter describes why we believe that physical quantities and units should be part of
a C++ Standard Library.

## Safety

It is no longer only the space industry or experienced pilots that benefit from the autonomous
operations of some machines. We live in a world where more and more ordinary people trust
machines with their lives daily. In the near future, we will be allowed to sleep while our
car autonomously drives us home from a late party. As a result, many more C++ engineers are
expected to write life-critical software today than it was a few years ago. However, writing
safety-critical code requires extensive training and experience, both of which are in short demand.
While there exists some standards and guidelines such as MISRA C++ [@MISRA_CPP] with the aim of
enforcing the creation of safe code in C++, they are cumbersome to use and tend to shift the burden
on the discipline of the programmers to enforce these. At the time of writing, the C++ language
does not change fast enough to enforce safe-by-construction code.


One of the ways C++ can significantly improve the safety of applications being written
by thousands of developers is by introducing a type-safe, well-tested, standardized way to handle
physical quantities and their units. The rationale is that people tend to have problems
communicating or using proper units in code and daily life. Numerous
expensive failures and accidents happened due to using an invalid unit or a quantity type.

The most famous and probably the most expensive example in the software engineering domain is
the Mars Climate Orbiter that in 1999 failed to enter Mars' orbit and crashed while entering
its atmosphere [@MARS_ORBITER]. This is one of many examples here. People tend to confuse units
quite often. We see similar errors occurring in various domains over the years:

- On October 12, 1492, Christopher Columbus unintentionally discovered the sea route from Europe
  to America because, during his travel preparations, he mixed the Arabic mile with a Roman mile,
  which led to the wrong estimation of the equator and his expected travel distance [@COLUMBUS].
- In 1628, a new warship, Vasa, accidentally had an asymmetrical hull (being thicker on the port side
  than the starboard side), which was one of the reasons for her sinking less than a mile into her maiden
  voyage, resulting in the death of 30 people on board. This asymmetry could have been caused by the
  use of different systems of measurement, as archaeologists have found four rulers used by the workers
  who built the ship. Two were calibrated in Swedish feet, which had 12 inches, while the other two
  measured Amsterdam feet, which had 11 inches [@VASA].
- Air Canada Flight 143 ran out of fuel on July 23, 1983, at an altitude of 41 000 feet
  (12 000 metres), midway through the flight because the fuel had been calculated in pounds
  instead of kilograms by the ground crew [@GIMLI_GLIDER].
- The British rock band Black Sabbath, during its Born Again tour in 1983, ordered a replica of Stonehenge
  as props for the scene. Unfortunately, they had to leave them in the storage area because, while
  submitting the order, their manager wrote dimensions down in meters when he meant feet, and so the
  stones didn't fit the scene. "It cost a fortune to make, but there was not a building on Earth that
  you could fit it into" [@STONEHENGE].
- On April 15, 1999, Korean Air Cargo Flight 6316 crashed due to a miscommunication between
  pilots about the desired flight altitude [@FLIGHT_6316].
- In February 2001, the crew of the Moorpark College Zoo built an enclosure for Clarence the Tortoise
  with a weight of 250 pounds instead of 250 kilograms [@CLARENCE].
- In December 2003, one of the roller coaster’s cars at Tokyo Disneyland’s Space Mountain attraction
  suddenly derailed due to a broken axle caused by confusion after upgrading the specification
  from imperial to metric units [@DISNEY].
- During the construction of the Hochrheinbrücke bridge to connect the small German town of Laufenburg
  with Swiss Laufenburg, the construction team made a sign error that resulted in a discrepancy
  of 54 cm between the two outer ends of the bridge [@HOCHRHEINBRÜCKE].
- An American company sold a shipment of wild rice to a Japanese customer, quoting a price of
  39 cents per pound, but the customer thought the quote was for 39 cents per kilogram [@WILD_RICE].
- On October 17, 2023, The Guardian published an article titled "Record Heat: Malawi swelters with
  temperatures nearly 68F above average" with many issues related to the affine space types and
  temperature units. Due to incorrect logic, probably during the translation of the article to
  the U.S.  market, `20 °C` above the average temperature was converted to `68 °F`. The actual
  temperature increase was `32 °F`, not `68 °F` [@THE_GUARDIAN].
- A whole set of [@MEDICATION_DOSE_ERRORS]...

The safety subject is so vast and essential by itself that we dedicated an entire [Safety Features]
chapter of this paper that discusses all the nuances in detail.

## Vocabulary types

We standardized many library features mostly used in the implementation details
(fmt, ranges, random-number generators, etc.). However, we believe that the most important
role of the C++ Standard is to provide a standardized way of communication between different
vendors.

Let's imagine a world without `std::string` or `std::vector`. Every vendor has their version
of it, and of course, they are highly incompatible with each other. As a result, when someone
needs to integrate software from different vendors, it turns out to be an unnecessarily arduous task.

Introducing `std::chrono::duration` and `std::chrono::time_point` improved the interfaces a lot,
but time is only one of many quantities that we deal with in our software on a daily basis.
We desperately need to be able to express more quantities and units in a standardized way so
different libraries get means to communicate with each other.

If Lockheed Martin and NASA could have used standardized vocabulary types in their interfaces, maybe
they would not interpret pound-force seconds as newton seconds, and the [@MARS_ORBITER] would
not have crashed during the Mars orbital insertion maneuver.

## Certification

Mission and life-critical projects, or those for embedded devices, often have to obey the safety norms
that care about software for safety-critical systems (e.g., ISO 61508 is a basic functional safety
standard applicable to all industries, and ISO 26262 for automotive). As a result, their company policy
often forbid third-party tooling that lacks official certification. Such certification requires
a specification to be certified against, and those tools often do not have one. The risk and cost
of self-certifying an Open Source project is too high for many as well.

Companies often have a policy that the software they use must obey all the rules MISRA provides.
This is a common misconception, as many of those rules are intended to be deviated from.
However, those deviations require rationale and documentation, which is also considered to be risky
and expensive by many.

All of those reasons often prevent the usage of an Open Source product in a company, which is a huge
issue, as those companies typically are natural users of physical quantities and units libraries.

Having the physical quantities and units library standardized would solve those issues for many
customers, and would allow them to produce safer code for projects on which human life depends every
single day.

## Complex and complicated

Suppose vendors can't use an Open Source library in a production project for
the above reasons. They are forced to write their own abstractions by themselves.
Besides being costly and time-consuming, it also happens that writing a physical quantities and
units library by yourself is far from easy. Doing this is complex and complicated, especially for
engineers who are not experts in the domain. There are many exceptional corner cases to cover
that most developers do not even realize before falling into a trap in production. On the other
hand, domain experts might find it difficult to put their knowledge into code and create a correct
implementation in C++.
As a result, companies either use really simple and unsafe numeric wrappers, or abandon the effort
entirely and just use built-in types, such as `float` or `int`, to express quantity values, thus losing
all semantic categorization. This often leads to safety issues caused by accidentally using values
representing the wrong quantity or having an incorrect unit.

## Extensibility

Many applications of a quantity and units library may need to operate on a combination of
standard (e.g. SI) and domain-specific quantities and units. The complexity of developing
domain-specific solutions highlights the value in being able to define new quantities
and units that have all the expressivity and safety as those provided by the library.

Experience with writing ad hoc typed quantities without library support
that can be combined with or converted to `std::chrono::duration` has
shown the downside of bespoke solutions: If not all operations
or conversions are handled, users will need to leave the safety of typed
quantities to operate on primitive types.

The interfaces of the [@MP-UNITS] library were designed with ease of extensibility in mind.
Each definition of a dimension, quantity type, or unit typically takes only a single line of
code. This is possible thanks to the extensive usage of C++20 class types as Non-Type Template
Parameters (NTTP). For example, the following code presents how second (a unit of time in the [@SI])
and hertz (a unit of frequency in the [@SI]) can be defined:

```cpp
inline constexpr struct second : named_unit<"s", kind_of<isq::time>> {} second;
inline constexpr struct hertz : named_unit<"Hz", 1 / second, kind_of<isq::frequency>> {} hertz;
```

## Broad industry value

When people think about industries that could use physical quantities
and unit libraries, they think of a few companies related to aerospace,
autonomous cars, or embedded industries. That is all true, but there are
many other potential users for such a library.

Here is a list of some less obvious candidates:

- Manufacturing,
- maritime industry,
- freight transport,
- military,
- astronomy,
- 3D design,
- robotics,
- audio,
- medical devices,
- national laboratories,
- scientific institutions and universities,
- all kinds of navigation and charting,
- GUI frameworks,
- finance (including HFT).

As we can see, the range of domains for such a library is vast and not
limited to applications involving specifically physical units. Any
software that involves measurements, or operations on counts of some
standard or domain-specific quantities, could benefit from a zero-cost
abstraction for operating on quantity values and their units. The library
also provides affine space abstractions, which may prove useful in many
applications.

## Standardizing existing practice

Plenty of physical units libraries have been available to the public for many years. In 1998
Walter Brown provided an "Introduction to the SI Library of Unit-Based Computation" paper
for the International Conference on Computing in High Energy Physics [@CHEP98]. It emphasizes
the importance of strong types and static type-checking. After that, it describes a library
modeling the [@SI] to provide "strict compile-time type-checking without run-time overhead".

It also states that at this time, "in numeric programming, programmers make heavy, near-exclusive,
use of a language's native numeric types (e.g., `double`)". Today, twenty-five years later,
plenty of "Modern C++" production code bases still use `double` to represent various quantities
and units. It is high time to change this.

Throughout the years, we have learned the best practices for handling specific cases in the domain.
Various products may have different scopes and support different C++ versions. Still, taking that
aside, they use really similar concepts, types, and operations under the hood. We know how to do
those things already.

The authors of this paper developed and delivered multiple successful C++ libraries for this domain.
Libraries developed by them [have more than 90% of all the stars on GitHub in the field of
physical units libraries for C++](https://github.com/topics/dimensional-analysis?l=c%2B%2B).

The authors joined forces and are working together to propose the best physical quantities and
units library we can get with the latest version of the C++ language. They spend their private
time and efforts hoping that the ISO C++ Committee will be willing to include such a feature in
the C++ standard library.


# Common smells when there is no library for physical quantities

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

There are several problems with such an approach: The abundance of `double` parameters
makes it easy to accidentally switch values and there is no way of noticing such a mistake
at compile-time. The code is not self-documenting in what units the parameters are expected. Is
`Distance` in meters or kilometers? Is `WindSpeed` in meters per second or knots?
Different code bases choose different ways to encode this information,
which may be internally inconsistent.
A strong type system would help answer these questions at the time the interface is written,
and the compiler would verify it at compile-time.

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

Apart from the obvious readability issues, such code is hard to maintain, and it needs a lot of
domain knowledge on the developer's side. While it would be easy to replace these numbers with
named constants, the question of which unit the constant is in remains. Is `287.06` in
pounds per square inch (psi) or millibars (mbar)?

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

Again, the question of which unit the constant is in remains. Without looking at the code,
it is impossible to tell from which unit `TOMETER` converts. Also, macros have the problem that
they are not scoped to a namespace and thus can easily clash with other macros or functions,
especially if they have such common names like `PI` or `RAD_TO_DEG`. A quick search through open
source C++ code bases reveals that, for example, the `RAD_TO_DEG` macro is defined in a multitude
of different ways -- sometimes even within the same repository:

```cpp
#define RAD_TO_DEG (180 / PI)
#define RAD_TO_DEG 57.2957795131
#define RAD_TO_DEG ( radians ) ((radians ) * 180.0 / M_PI)
#define RAD_TO_DEG 57.2957805f
...
```

[Example search across multiple repositories](https://github.com/search?q=lang%3AC%2B%2B++%22%23define+RAD_TO_DEG%22&type=code)

[Multiple redefinitions in the same repository](https://github.com/search?q=repo%3ALK8000%2FLK8000%20rad_to_deg&type=code)

Another safety issue occurring here is the fact that macro values can be deliberately tainted
by compiler settings at built time and can acquire values that are not present in the source code.
Human reviews won't catch such issues.

Also, most of the macros do not follow best practices. Often, necessary parentheses are missing,
processing in a preprocessor ends up with redundant casts, or some compile-time constants use too
many digits for a value to be exact for a specific type (e.g. `float`).

## Lack of consistency

If we not only lack strong types to isolate the abstractions from each other, but also lack discipline
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

Users can easily make errors if the interface designers are not consistent in ordering parameters.
It is really hard to remember which function takes latitude or `Bearing` first and when a latitude
or `Distance` is in the front.

## Lack of a conceptual framework

The previous points mean that the fundamental types can't be leveraged to model the different concepts
of quantities and units frameworks. There is no shared vocabulary between different libraries.
User-facing APIs use ad-hoc conventions. Even internal interfaces are inconsistent between themselves.

Arithmetic types such as `int` and `double` are used to model different concepts.
They are used to represent any abstraction (be it a magnitude, difference, point, or kind) of any
quantity type of any unit.
These are weak types that make up weakly-typed interfaces.
The resulting interfaces and implementations built with these types
easily allow mixing up parameters and using operations that are not part of the represented quantity.


# Design goals

The library facilities that we plan to propose in the upcoming papers is designed with
the following goals in mind.

## Compile-time safety

The most important property of any such a library is the safety it brings to C++ projects.
The correct handling of physical quantities, units, and numerical values should be verifiable both by
the compiler and by humans with manual inspection
of each individual line.

In some cases, we are even eager to prioritize safe interfaces over the general usability experience
(e.g. getters of the underlying raw numerical value will always require a unit in which the value should
be returned in, which results in more typing and is sometimes redundant).

More information on this subject can be found in [Safety features].

## Performance

The library should be as fast or even faster than working with fundamental types. The should
be no runtime overhead, and no space size overhead should be needed to implement higher-level
abstractions.

## Great user experience

The primary purpose of the library is to generate compile-time errors. If users
did not introduce any bugs in the manual handling of quantities and units, the library would be
of little use. This is why the library is optimized for readable compilation errors
and great debugging experience.

The library is easy to use and flexible. The interfaces are straight-forward
and safe by default. Users should be able to easily express any quantity and unit, which requires
them to compose.

The above constraints imply the usage of special implementation techniques. The library will not
only provide types, but also compile-time known values that will enable users to write easy
to understand and efficient equations on quantities and units.

## Feature rich

There are plenty of expectations from different parties regarding such a library. It should support
at least:

- Systems of Quantities.
- Systems of Units.
- Scalar, vector, and tensor quantities.
- The affine space.
- Natural units systems.
- Strong angular system.
- Any unit's magnitude (huge, small, floating-point).
- Faster-than-lightspeed constants.
- Highly adjustable text-output formatting.

## Easy to extend

Most entities in the library can be defined with a single line of code without
preprocessor macros. Users can easily extend provided systems with custom
dimensions, quantities, and units.

## Low standardization cost

The set of entities required for standardization should be limited to the bare minimum.

Derived units do not need separate library types. Instead, they can be obtained through the composition
of predefined named units. Units should not be associated with User-Defined Literals (UDLs), as it
is the case with `std::chrono::duration`. UDLs do not compose, have very limited scope and
functionality, and are expensive to standardize.

The user interface has no preprocessor macros.

It should be possible for most proposed features (besides text output) to be freestanding.


# Domain introduction

## Systems

<!-- 
flowchart TD
    system_of_quantities["System of Quantities"] --- system_of_units1[System of Units #1]
    system_of_quantities["System of Quantities"] --- system_of_units2[System of Units #2]
    system_of_quantities["System of Quantities"] --- system_of_units3[System of Units #3]
 -->

<img src="img/systems.svg" style="display: block; margin-left: auto; margin-right: auto; width: 80%;"/>

### System of quantities

[System of quantities](https://jcgm.bipm.org/vim/en/1.3.html) is a set of quantities together with
a set of noncontradictory equations relating those quantities.

[International System of Quantities (ISQ)](https://jcgm.bipm.org/vim/en/1.6.html) is
system of quantities based on the seven base quantities: _length_, _mass_, _time_, _electric current_,
_thermodynamic temperature_, _amount of substance_, and _luminous intensity_. This system of quantities
is published in the [@ISO80000] series "Quantities and units".

### System of units

[System of units](https://jcgm.bipm.org/vim/en/1.13.html) is a set of base units and derived units,
together with their multiples and submultiples, defined in accordance with given rules, for a given
system of quantities

[International System of Units (SI)](https://jcgm.bipm.org/vim/en/1.16.html) is a system of units,
based on the International System of Quantities, their names and symbols, including a series of
prefixes and their names and symbols, together with rules for their use, adopted by the General
Conference on Weights and Measures (CGPM).


## Quantity

<!-- 
flowchart TD
    dimension --- quantity_type["quantity type"]
    quantity_type --- reference["reference\n(e.g. unit)"]
    reference --- quantity
    number --- quantity
 -->

<img src="img/domain_introduction.svg" style="display: block; margin-left: auto; margin-right: auto; width: 30%;"/>

## Dimension

[Dimension](https://jcgm.bipm.org/vim/en/1.7.html) specifies the dependence of a quantity on the base
quantities of a particular system of quantities. It is represented as a product of powers of factors
corresponding to the base quantities, omitting any numerical factor.

Even though ISO does not officially define those, we find the below terms useful when discussing
the domain and its C++ implementation:

- **base dimension** is the dimension of a [base quantity](https://jcgm.bipm.org/vim/en/1.4.html),
- **derived dimension** is the dimension of a [derived quantity](https://jcgm.bipm.org/vim/en/1.5.html).

For example:

- _length_ ($\mathsf{L}$), _mass_ ($\mathsf{M}$), _time_ ($\mathsf{T}$), _electric current_ ($\mathsf{I}$),
  _thermodynamic temperature_ ($\mathsf{Θ}$), _amount of substance_ ($\mathsf{N}$), and
  _luminous intensity_ ($\mathsf{J}$) are the base dimensions of the [ISQ](../../appendix/glossary.md#isq).
- A derived dimension of _force_ in the [ISQ](../../appendix/glossary.md#isq) is denoted by
  $\textsf{dim }F = \mathsf{LMT}^{–2}$.
- IEC 80000 provides _traffic intensity_ quantity that is measured in erlangs but not in a unit one,
  which also implies that it should be introduced as a base quantity with its own dimension.

## Quantity type

[Dimension is not enough to describe a quantity](systems_of_quantities.md#dimension-is-not-enough-to-describe-a-quantity).
This is why the [ISO 80000](../appendix/references.md#ISO80000) provides hundreds of named quantity
types. It turns out that there are many more quantity types in the [ISQ](../../appendix/glossary.md#isq)
than the named units in the [SI](../../appendix/glossary.md#si).


# Library scope discussion

_Please note that many code examples included in this chapter do not represent the proposed design.
Their intent is to highlight issues that the current design addresses._

## Limitations of units only solutions

Unable to provide generic interfaces in specific quantities
Currency example will not work

## Limitations of dimensions

activity in Bq vs frequency in Hz
gray vs sievert
fuel_consumption vs area
Torque vs work
dimensionless vs angular_measure vs solid angular_measure vs storage_capacity
counts (i.e. beats, samples) and frequency
box example
glide computer
gravitational potential energy


```cpp
inline constexpr struct dim_currency : base_dimension<"$"> {} dim_currency;

QUANTITY_SPEC(market_quantity, dimensionless);
QUANTITY_SPEC(currency, dim_currency);
QUANTITY_SPEC(volume, currency, currency * market_quantity);

inline constexpr struct us_dollar : named_unit<"USD", kind_of<currency>> {} us_dollar;

namespace unit_symbols {

inline constexpr auto USD = us_dollar;
inline constexpr auto USD_s = scaled_us_dollar;

}

using Qty = quantity<market_quantity[one], int>;
using Price = quantity<currency[us_dollar], double>;
using Scaled = quantity<currency[scaled_us_dollar], std::int64_t>;
using Volume = quantity<volume[scaled_us_dollar], std::int64_t>;

Price price1 = 12.95 * USD;
Price price2 = 12.55 * USD;
Qty qty1 = 100 * one;
Qty qty2 = 110 * one;

Volume vol = price1 * qty1 + price2 * qty2;
// Volume bad = price1 + price2;  // does not compile

Price avg = vol / (qty1 + qty2);
// Volume bad = vol / (qty1 + qty2);  // does not compile
```




# Unit-based quantities (simple mode)

Examples, error messages, ...


# Typed quantities (safer mode)



# Design overview




# Text output


# Code examples

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
static_assert(1 * km / (1 * s) == 1000 * m / s);
static_assert(2 * km / h * (2 * h) == 4 * km);
static_assert(2 * km / (2 * km / h) == 1 * h);

static_assert(2 * m * (3 * m) == 6 * m2);

static_assert(10 * km / (5 * km) == 2 * one);

static_assert(1000 / (1 * s) == 1 * kHz);
```

Try it in [the Compiler Explorer](https://godbolt.org/z/sYfoPzTvT).

## Hello units

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

  constexpr quantity v1 = 110 * km / h;
  constexpr quantity v2 = 70 * mph;
  constexpr quantity v3 = avg_speed(220. * km, 2 * h);
  constexpr quantity v4 = avg_speed(isq::distance(140. * mi), 2 * isq::duration[h]);
  constexpr quantity v5 = v3.in(m / s);
  constexpr quantity v6 = value_cast<m / s>(v4);
  constexpr quantity v7 = value_cast<int>(v6);

  std::cout << v1 << '\n';                // 110 km/h
  std::cout << v2 << '\n';                // 70 mi/h
  std::println("{}", v3);                 // 110 km/h
  std::println("{:*^14}", v4);            // ***70 mi/h****
  std::println("{:%Q in %q}", v5);        // 30.5556 in m/s
  std::println("{0:%Q} in {0:%q}", v6);   // 31.2928 in m/s
  std::println("{:%Q}", v7);              // 31
}
```

Try it in [the Compiler Explorer](https://godbolt.org/z/3E7q5P6jq).

## Storage tank

This example estimates the process of filling a storage tank with some contents. It presents:

- [The importance of supporting more than one distinct quantity of the same kind](https://mpusz.github.io/mp-units/2.0/users_guide/framework_basics/systems_of_quantities/#system-of-quantities-is-not-only-about-kinds),
- [faster-than-lightspeed constants](https://mpusz.github.io/mp-units/2.0/users_guide/framework_basics/faster_than_lightspeed_constants/),
- how easy it is to [add custom quantity types](https://mpusz.github.io/mp-units/2.0/users_guide/framework_basics/systems_of_quantities/#defining-quantities)
when needed, and
- [interoperability with `std::chrono::duration`](https://mpusz.github.io/mp-units/2.1/users_guide/framework_basics/concepts/#QuantityLike).

```cpp
#include <mp-units/chrono.h>
#include <mp-units/format.h>
#include <mp-units/math.h>
#include <mp-units/systems/isq/isq.h>
#include <mp-units/systems/si/si.h>
#include <cassert>
#include <chrono>
#include <format>
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
inline constexpr auto air_density = isq::mass_density(1.225 * kg / m3);

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
  tank.set_contents_density(1'000 * kg / m3);

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

  std::println("fill height at {} = {} ({} full)", fill_time, fill_level, fill_ratio.in(percent));
  std::println("fill weight at {} = {} ({})", fill_time, filled_weight, filled_weight.in(N));
  std::println("spare capacity at {} = {}", fill_time, spare_capacity);
  std::println("input flow rate = {}", input_flow_rate);
  std::println("float rise rate = {}", float_rise_rate);
  std::println("tank full E.T.A. at current flow rate = {}", fill_time_left.in(s));
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

Try it in [the Compiler Explorer](https://godbolt.org/z/cx8Pr6ne9).

## Bridge across the Rhine

The following example codifies the history of a famous issue during the construction of a bridge across
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
  return os << alt.quantity_ref_from(alt.point_origin) << " AMSL(DE)";
}

template<auto R, typename Rep>
std::ostream& operator<<(std::ostream& os, quantity_point<R, altitude_CH::point_origin, Rep> alt)
{
  return os << alt.quantity_ref_from(alt.point_origin) << " AMSL(CH)";
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

Try it in [the Compiler Explorer](https://godbolt.org/z/c17TWGhc5).

## User defined quantities and units

Users can easily define new quantities and units for domain-specific
use-cases.  This example from digital signal processing will show how to
define custom units for counting
[digital samples](https://en.wikipedia.org/wiki/Sampling_(signal_processing))
and how they can be converted to time measured in milliseconds:

```cpp
#include <mp-units/format.h>
#include <mp-units/systems/isq/isq.h>
#include <mp-units/systems/si/si.h>
#include <format>

namespace dsp_dsq {

using namespace mp_units;

inline constexpr struct SampleCount : quantity_spec<dimensionless, is_kind> {} SampleCount;
inline constexpr struct SampleDuration : quantity_spec<isq::time> {} SampleDuration;
inline constexpr struct SamplingRate : quantity_spec<isq::frequency, SampleCount / isq::time> {} SamplingRate;

inline constexpr struct Sample : named_unit<"Smpl", one, kind_of<SampleCount>> {} Sample;

namespace unit_symbols {
inline constexpr auto Smpl = Sample;
}

}

int main()
{
  using namespace dsp_dsq::unit_symbols;
  using namespace mp_units::si::unit_symbols;

  const auto sr1 = 44100.f * Hz;
  const auto sr2 = 48000.f * Smpl / s;

  const auto bufferSize = 512 * Smpl;

  const auto sampleTime1 = (bufferSize / sr1).in(s);
  const auto sampleTime2 = (bufferSize / sr2).in(ms);

  const auto sampleDuration1 = (1 / sr1).in(ms);
  const auto sampleDuration2 = dsp_dsq::SampleDuration(1 / sr2).in(ms);

  const auto rampTime = 35.f * ms;
  const auto rampSamples1 = value_cast<int>((rampTime * sr1).in(Smpl));
  const auto rampSamples2 = value_cast<int>((rampTime * sr2).in(Smpl));

  std::println("Sample rate 1 is: {}", sr1);
  std::println("Sample rate 2 is: {}", sr2);

  std::println("{} @ {} is {}", bufferSize, sr1, sampleTime1);
  std::println("{} @ {} is {}", bufferSize, sr2, sampleTime2);

  std::println("One sample @ {} is {}", sr1, sampleDuration1);
  std::println("One sample @ {} is {}", sr2, sampleDuration2);

  std::println("{} is {} @ {}", rampTime, rampSamples1, sr1);
  std::println("{} is {} @ {}", rampTime, rampSamples2, sr2);
}
```

The above code outputs:

```text
Sample rate 1 is: 44100 Hz
Sample rate 2 is: 48000 Smpl/s
512 Smpl @ 44100 Hz is 0.01161 s
512 Smpl @ 48000 Smpl/s is 10.6667 ms
One sample @ 44100 Hz is 0.0226757 ms
One sample @ 48000 Smpl/s is 0.0208333 ms
35 ms is 1543 Smpl @ 44100 Hz
35 ms is 1680 Smpl @ 48000 Smpl/s
```

Try it in [the Compiler Explorer](https://godbolt.org/z/KeT3MsfcG).


# Safety features

This chapter describes the features that enforce safety in our code bases. It starts with obvious
things, but then it moves to probably less known benefits of using physical quantities
and units libraries. This chapter also serves as a proof that it is not easy to implement such a
library correctly, and that there are many cases where the lack of experience or time for the development
of such a utility may easily lead to safety issues as well.

Before we go through all the features, it is essential to note that they do not introduce any runtime
overhead over the raw unsafe code doing the same thing. This is a massive benefit of C++ compared
to other programming languages (e.g., Python, Java, etc.).

## Unit conversions

The first thing that comes to our mind when discussing the safety of such libraries is
automated unit conversions between values of the same physical quantity.
This is probably the most important subject here. We learned
about its huge benefits long ago thanks to the `std::chrono::duration` that made conversions of
time durations error-proof.

Unit conversions are typically performed either via a converting constructor or a dedicated conversion
function:

```cpp
auto q1 = 5 * km;
std::cout << q1.in(m) << '\n';
quantity<si::metre, int> q2 = q1;
```

Such a feature benefits from the fact that the library knows about the magnitudes of the source and
destination units at compile-time, and may use that information to calculate and apply a conversion
factor automatically for the user.

In `std::chrono::duration`, the magnitude of a unit is always expressed with `std::ratio`. This is
not enough for a general-purpose physical units library. Some of the derived units have huge
or tiny ratios. The difference from the base units is so huge that it cannot be expressed with
`std::ratio`, which is implemented in terms of `std::intmax_t`. This makes it impossible to define
units like electronvolt (eV), where 1 eV = 1.602176634×10<sup>−19</sup> J, or Dalton (Da), where
1 Da = 1.660539040(20)×10<sup>−27</sup> kg. Moreover, some conversions, such as radian to a degree,
require a conversion factor based on an irrational number like pi.

## Preventing truncation of data

The second safety feature of such libraries is preventing accidental truncation of a quantity value.
If we try the operations above with swapped units, both conversions should fail
to compile:

```cpp
auto q1 = 5 * m;
std::cout << q1.in(km) << '\n';              // Compile-time error
quantity<si::kilo<si::metre>, int> q2 = q1;  // Compile-time error
```

We can't preserve the value of a source quantity when we convert it to one with a unit of
a lower resolution while dealing with an integral representation type for a quantity.
In the example above, converting `5` meters would result in `0` kilometers if internal conversion
is performed using regular integer arithmetic.

While this could be a valid behavior, the problem arises when the user expects to be able to convert
the quantity back to the original unit without loss of information.
So the library should prevent such conversions from happening implicitly;
[@MP-UNITS] offers the named cast `value_cast` for these conversions marked as unsafe.

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
quantity<si::kilo<si::metre>> q2 = q1;  // `double` by default
```

_The [@MP-UNITS] library follows `std::chrono::duration` logic and treats floating-point types as
value-preserving._

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

As we can see, it is essential not to allow such truncating conversions to happen implicitly,
and a good physical quantities and units library should fail at compile-time in case an user makes
such a mistake.

## The affine space

The affine space has two types of entities:

- point - a position specified with coordinate values (i.e., location, address, etc.)
- vector - the difference between two points (i.e., shift, offset, displacement, duration, etc.)

One can do a limited set of operations in affine space on points and vectors. This greatly
helps to prevent quantity equations that do not have physical sense.

People often think that affine space is needed only to model temperatures and maybe time points
(following the [`std::chrono::time_point`](https://en.cppreference.com/w/cpp/chrono/time_point) example).
Still, the applicability of this concept is much wider.

For example, if we would like to model a Mount Everest climbing expedition, we would deal with
two kinds of altitude-related entities. The first would be absolute altitudes above the mean sea
level (points) like base camp altitude, mount peak altitude, etc. The second one would be the
heights of daily climbs (vectors). Although it makes physical sense to add heights of daily climbs,
there is no sense in adding altitudes. What does adding the altitude of a base camp and
the mountain peak mean after all?

Modeling such affine space entities with the `quantity` (vector) and `quantity_point` (point) class
templates improves the overall project's safety by only providing the operators defined by the concepts.

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

The code continues to compile fine, but all the calculations are now off by orders of magnitude. This is why a good
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
x.vec.emplace_back(42);       // Compile-time error
x.vec.emplace_back(42 * ms);  // OK
```

For consistency and to prevent similar safety issues, the `quantity_point` in the [@MP-UNITS] library
can't be created from a standalone value of a `quantity` (contrary to the `std::chrono::time_point`
design). Such a point has to always be associated with an explicit origin:

```cpp
quantity_point qp1 = mean_sea_level + 42 * m;
quantity_point qp2 = si::ice_point + 21 * deg_C;
```

## Obtaining the numerical value of a quantity

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

The preceding code is incorrect. Even though the duration stores a quantity equal to 42 s, it
is not stored in seconds (it's either microseconds or milliseconds, depending on which
of the interfaces from the previous chapter is the current one). Such issues
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
their results are prvalues.

## Preventing dangling references

Besides returning prvalues, sometimes users need to get an actual reference to the underlying
numerical value stored in a `quantity`. For those cases, the [@MP-UNITS] library exposes
`quantity::numerical_value_ref_in(Unit)` that participates in overload resolution only:

- for lvalues (rvalue reference qualified overload is explicitly deleted),
- when the provided `Unit` has the same magnitude as the one currently used by the quantity.

The first condition above aims to limit the possibility of dangling references. We want to increase
the chances that the reference/pointer provided to an underlying API remains valid for the time of
its usage. (We're much less concerned about performance aspects for a `quantity` here, as we expect
the majority (if not all) of representation types to be cheap to copy.)

That said, we acknowledge that this approach to preventing dangling references conflates value
category with lifetime.  While it may prevent the majority of dangling references, it also admits
both false positives and false negatives, as explained in [@VCINL].  We want to highlight this
dilemma for the committee's consideration.

In case we do decide to keep this policy of deleting rvalue overloads, here's an example of code
that it would prevent from compiling.

```cpp
void legacy_func(const int& seconds);
```

```cpp
legacy_func((4 * s + 2 * s).numerical_value_ref_in(si::second));  // Compile-time error
```

The [@MP-UNITS] library goes one step further, by implementing all compound assignments,
pre-increment, and pre-decrement operators as non-member functions that preserve the initial value
category. Thanks to that, the following will also not compile:

```cpp
quantity<si::second, int> get_duration();
```

```cpp
legacy_func((4 * s += 2 * s).numerical_value_ref_in(si::second));    // Compile-time error
legacy_func((++get_duration()).numerical_value_ref_in(si::second));  // Compile-time error
```

The second condition above enables the usage of various equivalent units. For example, `J` is
equivalent to `N * m`, and `kg * m2 / s2`. As those have the same magnitude, it does not
matter exactly which one is being used here, as the same numerical value
should be returned for all of them.

```cpp
void legacy_func(const int& joules);
```

```cpp
quantity q1 = 42 * J;
quantity q2 = 42 * N * (2 * m);
quantity q3 = 42 * kJ;
legacy_func(q1.numerical_value_ref_in(si::joule)); // OK
legacy_func(q2.numerical_value_ref_in(si::joule)); // OK
legacy_func(q3.numerical_value_ref_in(si::joule)); // Compile-time error
```


Here are a few examples provided by our users where enabling a quantity type to return
a reference to its underlying numerical value is required:

- Interoperability with the [Dear ImGui](https://github.com/ocornut/imgui/blob/19ae142bdddf9fcb840549b4b1279739a36c3fa6/imgui.h#L551):

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

- Obtaining a temperature via the C library:

    ```cpp
    // read_temperature is in the BSP defined as
    void read_temperature(float* temp_in_celsius);
    ```

    ```cpp
    using Celsius_point = quantity_point<isq::Celsius_temperature[deg_C], si::ice_point, float>;

    Celsius_point temp;
    read_temperature(&temp.quantity_ref_from(si::ice_point).numerical_value_ref_in(si::degree_Celsius));
    ```

As we can see in the second example, `quantity_point` also provides an lvalue-ref-qualified
`quantity_ref_from(PointOrigin)` member function that returns a reference to its stored `quantity`.
Also, for reasons similar to the ones described in the previous chapter, this
function requires that the argument provided by the user is the same as the origin of a quantity point.

## Quantity kinds

What should be the result of the following quantity equation?

```cpp
auto res = 1 * Hz + 1 * Bq + 1 * Bd;
```

We have checked a few leading libraries on the market, and here are the results:

- [@BOOST-UNITS] claims the answer to be 2 Hz (bauds are not supported by it, so we removed it from
  the equation),
- [@NHOLTHAUS-UNITS] claims it is 2 s<sup>-1</sup> (no support for bauds as well),
- [@PINT] library in Python claims that the result is 3.0 Hz,
- [@JSR-385] library in Java throws an exception saying that we can't add those quantities.

Now let's check what [@ISO-GUIDE] says about quantity kinds:

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

To summarize the above, [@ISO80000] explicitly states that frequency is measured in Hz and activity
is measured in Bq, which are quantities of different kinds. As such, they should not be able to be compared,
added, or subtracted. So, the only library from the above that was correct was [@JSR-385].
The rest of them are wrong to allow such operations. Doing so may lead to vulnerable safety issues
when two unrelated quantities of the same dimension are accidentally added or assigned to each other.

The reason for most of the libraries on the market to be wrong in this field is the fact that their
quantities are implemented only in terms of the concept of dimension. However, we've just learned
that a dimension is not enough to express a quantity type.

The [@MP-UNITS] library goes beyond that and properly models quantity kinds. We believe that it is
a significant feature that improves the safety of the library, and that is why we also plan to propose
quantity kinds for standardization as mentioned in [@P2980R0].

## Various quantities of the same kind

Proper modeling of distinct kinds for quantities of the same dimension is often not enough from the
safety point of view. Most of the libraries allow us to write the following code in the type-safe
way:

```cpp
quantity<isq::speed[m/s]> avg_speed(quantity<isq::length[m]> l, quantity<isq::time[s]> t)
{
  return l / t;
}
```

However, they fail when we need to model an abstraction using more than one quantity of
the same kind:

```cpp
class Box {
  quantity<isq::area[m2]> base_;
  quantity<isq::length[m]> height_;
public:
  Box(quantity<isq::length[m]> l, quantity<isq::length[m]> w, quantity<isq::length[m]> h)
    : base_(l * w), height_(h)
  {}
  // ...
};
```

This does not provide strongly typed interfaces anymore.

Again, it turns out that [@ISO80000] has an answer. This specification standardizes hundreds
of quantities, many of which are of the same kind. For example, for quantities of the kind length,
it provides the following:

![](img/quantities_of_length.svg)

As we can see, various quantities of the same kind are not a flat set. They form a hierarchy
tree which influences

- conversion rules, and
- the quantity type being the result of adding or subtracting different quantities of the same kind.

The [@MP-UNITS] library is probably the first one on the market (in any programming language) that
models such abstractions.

### Converting between quantities of the same kind

Quantity conversion rules can be defined based on the same hierarchy of quantities of kind length.

1. **Implicit conversions**

    - Every `width` is a `length`.
    - Every `radius` is a `width`.

    ```cpp
    static_assert(implicitly_convertible(isq::width, isq::length));
    static_assert(implicitly_convertible(isq::radius, isq::length));
    static_assert(implicitly_convertible(isq::radius, isq::width));
    ```

    In the [@MP-UNITS] library, implicit conversions are allowed on copy-initialization:

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

    In the [@MP-UNITS] library, explicit conversions are forced by passing the quantity to a call
    operator of a `quantity_spec` type:

    ```cpp
    quantity<isq::length<m>> q1 = 42 * m;
    quantity<isq::height<m>> q2 = isq::height(q1);  // explicit quantity conversion
    ```

3. **Explicit casts**

    - `height` is never a `width`, and vice versa.
    - Both `height` and `width` are quantities of kind `length`.

    ```cpp
    static_assert(!implicitly_convertible(isq::height, isq::width));
    static_assert(!explicitly_convertible(isq::height, isq::width));
    static_assert(castable(isq::height, isq::width));
    ```

    In the [@MP-UNITS] library, explicit casts are forced with a dedicated `quantity_cast` function:

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

    In the [@MP-UNITS] library, even the explicit casts will not force such a conversion:

    ```cpp
    void foo(quantity<isq::length[m]>);
    ```

    ```cpp
    foo(quantity_cast<isq::length>(42 * s)); // Compile-time error
    ```


With the above rules, one can write the following short application to calculate a fuel consumption:

```cpp
inline constexpr struct fuel_volume : quantity_spec<isq::volume> {} fuel_volume;
inline constexpr struct fuel_consumption : quantity_spec<fuel_volume / isq::distance> {} fuel_consumption;

const quantity fuel = fuel_volume(40. * l);
const quantity distance = isq::distance(550. * km);
const quantity<fuel_consumption[l / (mag<100> * km)]> q = fuel / distance;
std::cout << "Fuel consumption: " << q << "\n";
```

The above code prints:

```text
Fuel consumption: 7.27273 × 10⁻² l/km
```

Please note that, despite the dimensions of `fuel_consumption` and `isq::area` being the same (L²),
the constructor of a quantity `q` below will fail to compile when we pass an argument being the
quantity of area:

```cpp
static_assert(fuel_consumption.dimension == isq::area.dimension);

const quantity<isq::area[m2]> football_field = isq::length(105 * m) * isq::width(68 * m);
const quantity<fuel_consumption[l / (mag<100> * km)]> q2 = football_field;  // Compile-time error
const quantity q3 = q + football_field;                                     // Compile-time error
if (q == football_field) {                                                  // Compile-time error
  // ...
}
```

### Comparing, adding, and subtracting quantities of the same kind

[@ISO-GUIDE] explicitly states that `width` and `height` are quantities of the same kind and as such
they

- are mutually comparable, and
- can be added and subtracted.

If we take the above for granted, the only reasonable result of `1 * width + 1 * height` is `2 * length`,
where the result of `length` is known as a common quantity type. A result of such an equation is always
the first common node in a hierarchy tree of the same kind. For example:

```cpp
static_assert(common_quantity_spec(isq::width, isq::height) == isq::length);
static_assert(common_quantity_spec(isq::thickness, isq::radius) == isq::width);
static_assert(common_quantity_spec(isq::distance, isq::path_length) == isq::path_length);
```

```cpp
quantity q = isq::thickness(1 * m) + isq::radius(1 * m);
static_assert(q.quantity_spec == isq::width);
```

One could argue that allowing to add or compare quantities of height and width might be a safety
issue, but we need to be consistent with the requirements of [@ISO80000]. Moreover, from our
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
together with `isq::width` and `isq::height`, are used to define the dimensions of a Christmas gift.
Next, we provide a function that calculates the dimensions of a gift wrapping paper with some
wraparound. The result of both those expressions is a quantity of `isq::length`, as this is
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

### Modeling a quantity kind

In the physical units library, we also need an abstraction describing an entire family of
quantities of the same kind. Such quantities have not only the same dimension but also
can be expressed in the same units.

To annotate a quantity to represent its kind we introduced the `kind_of<>` specifier. For example,
to express any quantity of length, we need to type `kind_of<isq::length>`. Such an entity behaves
as any quantity of its kind. This means that it is implicitly convertible to any quantity in
a hierarchy tree.

```cpp
static_assert(!implicitly_convertible(isq::length, isq::height));
static_assert(implicitly_convertible(kind_of<isq::length>, isq::height));
```

Additionally, the result of operations on quantity kinds is also a quantity kind:

```cpp
static_assert(same_type<kind_of<isq::length> / kind_of<isq::time>, kind_of<isq::length / isq::time>>);
```

However, if at least one equation's operand is not a kind, the result becomes a "strong"
quantity where all the kinds are converted to the hierarchy tree's root quantities:

```cpp
static_assert(!same_type<kind_of<isq::length> / isq::time, kind_of<isq::length / isq::time>>);
static_assert(same_type<kind_of<isq::length> / isq::time, isq::length / isq::time>);
```

### Restricting units to specific quantity kinds

By default, units can be used to measure any kind of quantity with the same dimension. However, as we
have mentioned above, some units (e.g., Hz, Bq) are constrained to be used only with
a specific kind. Also, base units of the SI are meant to measure all of the quantities of their kinds.
To model this, in the [@MP-UNITS] library, we do the following:

```cpp
// base units
inline constexpr struct metre : named_unit<"m", kind_of<isq::length>> {} metre;
inline constexpr struct second : named_unit<"s", kind_of<isq::time>> {} second;

// derived units
inline constexpr struct hertz : named_unit<"Hz", 1 / second, kind_of<isq::frequency>> {} hertz;
inline constexpr struct becquerel : named_unit<"Bq", 1 / second, kind_of<isq::activity>> {} becquerel;
inline constexpr struct baud : named_unit<"Bd", 1 / si::second, kind_of<iec80000::modulation_rate>> {} baud;
```

This means that every time we type `42 * m`, we create a quantity of a kind length with the length
dimension. Such a quantity can be added, subtracted, or compared to any other quantity of the same
kind. Moreover, it is implicitly convertible to any quantity of its kind. Again, this could be
considered a safety issue as one could type:

```cpp
const christmas::gift lego = { 40 * cm, 30 * cm, 15 * cm };
auto paper = christmas::gift_wrapping_paper_size(lego);
```

The above code compiles fine without the need to force specific quantity types during construction.
This is another tradeoff we have to do here in order to improve the usability. Otherwise, we would
need to type the following every single time we want to initialize an array or aggregate:

```cpp
const quantity<isq::position_vector[m], int> measurements[] = { isq::position_vector(30'160 * m),
                                                                isq::position_vector(30'365 * m),
                                                                isq::position_vector(30'890 * m),
                                                                isq::position_vector(31'050 * m),
                                                                isq::position_vector(31'785 * m),
                                                                isq::position_vector(32'215 * m),
                                                                isq::position_vector(33'130 * m),
                                                                isq::position_vector(34'510 * m),
                                                                isq::position_vector(36'010 * m),
                                                                isq::position_vector(37'265 * m) };
```

As we can see above, it would be really inconvenient. With the current rules, we type:

```cpp
const quantity<isq::position_vector[m], int> measurements[] = { 30'160 * m, 30'365 * m, 30'890 * m, 31'050 * m,
                                                                31'785 * m, 32'215 * m, 33'130 * m, 34'510 * m,
                                                                36'010 * m, 37'265 * m };
```

which is more user-friendly.

Having such two options also gives users a choice. When we use different quantities of the same kind
in a project (e.g., radius, wavelength, altitude), we should probably reach for strongly-typed
quantities to bring additional safety for those cases. Otherwise, we can just use the simple mode for
the remaining quantities. We can easily mix simple and strongly-typed quantities in our projects,
and the library will do its best to protect us based on the information provided.

## Non-negative quantities

Some quantity types are defined by [@ISO80000] as explicitly non-negative. Those include quantities
like width, thickness, diameter, and radius. However, it turns out that it is possible to have negative
values of quantities defined as non-negative. For example, `-1 * isq::diameter[mm]` could represent
a change in the diameter of some object. Also, a subtraction `4 * width[mm] - 6 * width[mm]` results in
a negative value as the width of the second argument is larger than the first one.

Non-negative quantities are not limited to those explicitly stated as being non-negative in
the [@ISO80000]. Some quantities are implicitly non-negative from their definition. The most
obvious example here might be scalar quantities specified as magnitudes of a vector quantity.
For example, speed is defined as the magnitude of velocity. Again, `-1 * speed[m/s]` could represent
a change in average speed between two measurements.

This means that enforcing such constraints for quantity types might be impossible as those typically
are used to represent a difference between two states or measurements. However, we could apply
such constraints to quantity points, which, by definition, describe the absolute quantity values.
For example, when height is the measure of an object, a negative value is physically meaningless.

Such logic errors could be detected at runtime with contracts or some other preconditions or
invariants checks.

<!-- Lots of exciting discussion at https://github.com/mpusz/mp-units/issues/468 -->


## Vector and tensor quantities

While talking about physical quantities and units libraries, everyone expects that the library will
protect (preferably at compile-time) from accidentally replacing multiplication with division operations
or vice versa. Everyone knows and expects that the multiplication of length and time should not result
in speed. It does not mean that such a quantity equation is invalid. It just results in a quantity of
a different type.

If we expect the above protection for scalar quantities, we should also strive to provide similar
guarantees for vector and tensor quantities. First, the multiplication or division of two vectors or
tensors is not even mathematically defined. Such operations should be impossible on quantities using
vector or tensor representation types.

While multiplication and division are with scalars, the dot and cross products are for vector quantities.
The result of the first one is a scalar. The second one results in a vector perpendicular
to both vectors passed as arguments. A good physical quantities and units library should protect
the user from making such an error of accidentally replacing those operations.

Vector and tensor quantities can be implemented in two ways:

1. Encapsulating multiple quantities into a homogeneous vector or tensor representation type

    This solution is the most common in the C++ market. It requires the quantities library to provide
    only basic arithmetic operations (addition, subtraction, multiplication, and division) which
    are being used to calculate the result of linear algebra math. However, this solution can't
    provide any compile-time safety described above, and will also crash when someone passes
    a proper vector and tensor representation type to a quantity, expecting it to work.

2. Encapsulating a vector or tensor as a representation type of a quantity

    This provides all the required type safety, but requires the library to implement more operations
    on quantities and properly constrain them so they are selectively enabled when needed. Besides
    [@MP-UNITS], the only library that supports such an approach is [@PINT]. Such a solution requires
    the following operations to be exposed for quantity types
    (note that character refers to the algebraic structure of either scalar, vector and tensor):

    - `a + b` - addition where both arguments should be of the same quantity kind and character
    - `a - b` - subtraction where both arguments should be of the same quantity kind and character
    - `a % b` - modulo where both arguments should be of the same quantity kind and character
    - `a * b` - multiplication where one of the arguments has to be a scalar
    - `a / b` - division where the divisor has to be scalar
    - `a ⋅ b` - dot product of two vectors
    - `a × b` - cross product of two vectors
    - `|a|` - magnitude of a vector
    - `a ⊗ b` - tensor product of two vectors or tensors
    - `a ⋅ b` - inner product of two tensors
    - `a ⋅ b` - inner product of tensor and vector
    - `a : b` - scalar product of two tensors

Additionally, the [@MP-UNITS] library knows the expected quantity character, which is provided
(implicitly or explicitly) in the definition of each quantity type.
Thanks to that, it prevents the user, for example, from providing a scalar representation type for
force or a vector representation for power quantities.

```cpp
QuantityOf<isq::velocity> q1 = 60 * km / h;                             // Compile-time error
QuantityOf<isq::velocity> q2 = la_vector{0, 0, -60} * km / h;           // OK
QuantityOf<isq::force> q3 = 80 * kg * (10 * m / s2);                    // Compile-time error
QuantityOf<isq::force> q4 = 80 * kg * (la_vector{0, 0, -10} * m / s2);  // OK
QuantityOf<isq::power> q5 = q2 * q4;                                    // Compile-time error
QuantityOf<isq::power> q5 = dot(q2, q4);                                // OK
```

_Note: `q1` and `q3` can be permitted to compile by explicitly specializing
the `is_vector<T>` trait for the representation type._

As we can see above, such features additionally improves the compile-time safety of the library
by ensuring that quantities are created with proper quantity equations and are using correct
representation types.


# Safety pitfalls

## Integer division

The physical units library can't do any runtime branching logic for the division operator.
All logic has to be done at compile-time when the actual values are not known, and the quantity types
can't change at runtime.

If we expect `120 * km / (2 * h)` to return `60 km / h`, we have to agree with the fact that
`5 * km / (24 * h)` returns `0 km/h`. We can't do a range check at runtime to dynamically adjust scales
and types based on the values of provided function arguments.

The same applies to:

```cpp
static_assert(5 * h / (120 * min) == 0 * one);
```

This is why floating-point representation types are recommended as a default to store the numerical
value of a quantity. Some popular physical units libraries even
[forbid integer division at all](https://aurora-opensource.github.io/au/main/troubleshooting/#integer-division-forbidden).

The problem is similar to the one described in the section about accidental truncation of values
through conversion. While the consequent use of floating-point representation types may be a good idea,
it is not always possible. Especially in close-to-the-metal applications and small embedded systems,
the use of floating-point types is sometimes not an option, either for performance reasons or lack
of hardware support.
Having different operators for safe floating-point operations and unsafe integer operations would
hurt generic programming.
As such, users should instead use safer representation types.

## Lack of safe numeric types

Integers can overflow on arithmetics. This has already caused some expensive failures in engineering
[@ARIANE].

Integers can also be truncated during assignment to a narrower type.

Floating-point types may lose precision during assignment to a narrower type.
Conversion from `std::int64_t` to `double` may also lose precision.

If we had safe numeric types in the C++ standard library, they could easily be used as a `quantity`
representation type in the physical quantities and units library, which would address these safety
concerns.

Also, having a type trait informing if a conversion from one type to another is value-preserving
would help to address some of the issues mentioned above.

## Potential surprises during units composition

One of the most essential requirements for a good physical quantities and units library is to implement
units in such a way that they compose. With that, one can easily create any derived unit using
a simple unit equation on other base or derived units. For example:

```cpp
constexpr Unit auto kmph = km / h;
```

We can also easily obtain a quantity with:

```cpp
quantity q = 60 * km / h;
```

Such a solution is an industry standard and is implemented not only in [@MP-UNITS], but also is available
for many years now in both [@BOOST-UNITS] and [@PINT].

We believe that is the correct thing to do. However, we want to make it straight in this paper that some
potential issues are associated with such a syntax. Inexperienced users are often surprised by the
results of the following expression:

```cpp
quantity q = 60 * km / 2 * h;
```

This looks like like `30 km/h`, right? But it is not. Thanks to the order of operations, it results
in `30 km⋅h`. In case we want to divide `60 km` by `2 h`, parentheses are needed:

```cpp
quantity q = 60 * km / (2 * h);
```

Another surprising issue may result from the following code:

```cpp
template<typename T>
auto make_length(T v) { return v * si::metre; }

auto v = 42;
quantity q = make_length(v);
```

This might look like a good idea, but let's consider what would happen if the user provided a
quantity as input:

```cpp
auto v = 42 * m;
quantity q = make_length(v);
```

The above function call will result in a quantity of area instead of the expected quantity
of length.

The issues mentioned above could be turned into compilation errors by disallowing multiplying or
dividing a quantity by a unit. The [@MP-UNITS] library initially provided such an approach, but with
time, we decided this to not be user-friendly. Forcing the user to put the parenthesis around all
derived units in quantity equations like the one below, was too verbose and confusing:

```cpp
quantity q = 60 * (km / h);
```

It is important to notice that the problems mentioned above will always surface with a compile-time
error at some point in the user's code when they assign the resulting quantity to one with an
explicitly provided quantity type.

Below, we provide a few examples that correctly detect such issues at compile-time:

```cpp
quantity<si::kilo<si::metre> / non_si::hour, int> q1 = 60 * km / 2 * h;             // Compile-time error
quantity<isq::speed[si::kilo<si::metre> / non_si::hour], int> q2 = 60 * km / 2 * h; // Compile-time error
QuantityOf<isq::speed> auto q3 = 60 * km / 2 * h;                                   // Compile-time error
```

```cpp
template<typename T>
auto make_length(T v) { return v * si::metre; }

auto v = 42 * m;
quantity<si::metre, int> q1 = make_length(v);           // Compile-time error
quantity<isq::length[si::metre]> q2 = make_length(v);   // Compile-time error
QuantityOf<isq::length> q3 = make_length(v);            // Compile-time error
```

```cpp
template<typename T>
QuantityOf<isq::length> auto make_length(T v) { return v * si::metre; }

auto v = 42 * m;
quantity q = make_length(v);  // Compile-time error
```

```cpp
template<Representation T>
auto make_length(T v) { return v * si::metre; }

auto v = 42 * m;
quantity q = make_length(v);  // Compile-time error
```

## Limitations of systems of quantities

As stated before, modeling systems of quantities and [Various quantities of the same kind]
significantly improves the safety of the project. However, it is essential to mention here
that such modeling is not ideal and there might be some pitfalls and surprises associated with
some corner cases.

### Allowing irrational quantity combinations

Everyone probably agrees that multiplying two lengths is an area, and that area should be implicitly
convertible to the result of such a multiplication:

```cpp
static_assert(implicitly_convertible(isq::length * isq::length, isq::area));
static_assert(implicitly_convertible(isq::area, isq::length * isq::length));
```

Also, probably no one would be surprised by the fact that the multiplication of width and height
is also convertible to area. Still, the reverse operation is not valid in this case. Not every area
is an area over width and height, so we need an explicit cast to make such a conversion:

```cpp
static_assert(implicitly_convertible(isq::width * isq::height, isq::area));
static_assert(!implicitly_convertible(isq::area, isq::width * isq::height));
static_assert(explicitly_convertible(isq::area, isq::width * isq::height));
```

However, it might be surprising to some that the similar behavior will also be observed for the product
of two heights:

```cpp
static_assert(implicitly_convertible(isq::height * isq::height, isq::area));
static_assert(!implicitly_convertible(isq::area, isq::height * isq::height));
static_assert(explicitly_convertible(isq::area, isq::height * isq::height));
```

For humans, it is hard to imagine how two heights form an area, but the library's logic
has no way to prevent such operations.

### Quantities of dimension one

Some pitfalls might also arise when dealing with quantities of dimension one
(also known as dimensionless quantities).

If we divide two quantities of the same kind, we end up with a quantity of dimension one.
For example, we can divide two lengths to get a slope of the ramp or two durations to get the clock
accuracy. Those ratios mean something fundamentally different, but from the dimensional analysis
standpoint, they are mutually comparable.

The above means that the following code is valid:

```cpp
quantity q1 = 1 * m / (10 * m) + 1 * us / (1 * h);
quantity q2 = isq::length(1 * m) / isq::length(10 * m) + isq::time(1 * us) / isq::time(1 * h);
quantity q3 = isq::height(1 * m) / isq::length(10 * m) + isq::time(1 * us) / isq::time(1 * h);
```

The fact that the above code compiles fine might again be surprising to some users of such a library.
The result of all such quantity equations is a `dimensionless` quantity as it is the root of this
hierarchy tree.

Now, let's try to convert such results to some quantities of dimension one. The `q1` was obtained
from the expression that only used units in the equation, which means that the actual result of it
is a quantity of `kind_of<dimensionless>`, which behaves like any quantity from the tree.
Because of it, all of the below will compile for `q1`:

```cpp
quantity<si::metre / si::metre> ok1 = q1;
quantity<(isq::length / isq::length)[m / m]> ok2 = q1;
quantity<(isq::height / isq::length)[m / m]> ok3 = q1;
```

For `q2` and `q3`, the two first conversions also succeed. The first one passes because
all quantities of a kind are convertible to such kind. The type of the second quantity is
`quantity<dimensionless[one]>` in disguise. Such a quantity is a root of the kind tree, so
again, all the quantities from such a tree are convertible to it.

The third conversion fails in both cases, though. Not every dimensionless quantity
is a result of dividing height and length, so an explicit conversion would be needed to
force it to work.

```cpp
quantity<si::metre / si::metre> ok4 = q2;
quantity<(isq::length / isq::length)[m / m]> ok5 = q2;
quantity<(isq::height / isq::length)[m / m]> bad1 = q2;

quantity<si::metre / si::metre> ok6 = q3;
quantity<(isq::length / isq::length)[m / m]> ok7 = q3;
quantity<(isq::height / isq::length)[m / m]> bad2 = q3;
```

## Temperatures

Temperature support is one the most challenging parts of any physical quantities and units library
design. This is why it is probably reasonable to dedicate a chapter to this subject to describe how
they are intended to work and what are the potential pitfalls or surprises.

First, let's run the following code:

```cpp
quantity q1 = isq::thermodynamic_temperature(30. * K);
quantity q2 = isq::Celsius_temperature(30. * deg_C);

std::println("q1: {}, {}, {}", q1, q1.in(deg_C), q1.in(deg_F));
std::println("q2: {}, {}, {}", q2.in(K), q2, q2.in(deg_F));
```

This outputs:

```text
q1: 30 K, 30 °C, 54 °F
q2: 30 K, 30 °C, 54 °F
```

Also doing the following:

```cpp
quantity q3 = isq::Celsius_temperature(q1);
quantity q4 = isq::thermodynamic_temperature(q2);
```

outputs:

```text
q3: 30 K
q4: 30 °C
```

Even though the [@ISO80000] provides dedicated quantity types for thermodynamic temperature
and Celsius temperature, it explicitly states in the description of the first one:

> Differences of thermodynamic temperatures or changes may be expressed either in kelvin,
> symbol K, or in degrees Celsius, symbol °C

In the description of the second quantity type, we can read:

> The unit degree Celsius is a special name for the kelvin for use in stating values of Celsius
> temperature. The unit degree Celsius is by definition equal in magnitude to the kelvin. A
> difference or interval of temperature may be expressed in kelvin or in degrees Celsius.

As the `quantity` is a differential quantity type, it is okay to use any temperature unit for
those, and the results should differ only by the conversion factor. No offset should be applied
here to convert between the origins of different unit scales.

It is important to mention here that the existence of Celsius temperature quantity type
in [@ISO80000] is controversial.

[@ISO80000] (part 1) says:

> The system of quantities presented in this document is named the International System of
> Quantities (ISQ), in all languages. This name was not used in ISO 31 series, from which
> the present harmonized series has evolved. However, the ISQ does appear in ISO/IEC Guide 99
> and is the system of quantities underlying the International System of Units, denoted “SI”,
> in all languages according to the SI Brochure.

According to the [@ISO-GUIDE], a system of quantities is a "set of quantities together with
a set of non-contradictory equations relating those quantities". It also defines the
system of units as "set of base units and derived units, together with their multiples
and submultiples, defined in accordance with given rules, for a given system of quantities".

To say it explicitly, the system of quantities should not assume or use any specific units
in its definitions. It is essential as various systems of units can be defined on top of it,
and none of those should be favored.

However, the Celsius temperature quantity type is defined in [@ISO80000] (part 5) as:

> temperature difference from the thermodynamic temperature of the ice point is called the
> Celsius temperature $t$, which is defined by the quantity equation:
>
> $t = T − T_0$
>
> where $T$ is thermodynamic temperature (item 5-1) and $T_0 = 273,15\:K$

Celsius temperature is an exceptional quantity in the ISQ as it uses specific SI units in
its definition. This breaks the direction of dependencies between systems of quantities and
units and imposes significant implementation issues.

As [@MP-UNITS] implementation clearly distinguishes between systems of quantities
and units and assumes that the latter directly depends on the former, this quantity
definition does not enforce any units or offsets. It is defined as just a more specialized
quantity of the kind of thermodynamic temperature. We have added the Celsius temperature
quantity type for completeness and to gain more experience with it. Still, maybe a good
decision would be to skip it in the standardization process not to confuse users.

After quoting the official definitions and terms and presenting how quantities
work, let's discuss quantity points. Those describe specific points and are measured
relative to a provided origin:

```cpp
quantity_point qp1 = si::absolute_zero + isq::thermodynamic_temperature(300. * K);
quantity_point qp2 = si::ice_point + isq::Celsius_temperature(30. * deg_C);
```

The above provides two different temperature points. The first one is measured as a relative
quantity to the absolute zero (`0 K`), and the second one stores the value relative to
the ice point being the beginning of the degree Celsius scale.

It is essential to understand that the origins of quantity points will not change if
we convert their units:

```cpp
quantity_point qp3 = qp1.in(deg_C);
quantity_point qp4 = qp2.in(K);

static_assert(std::is_same_v<decltype(qp3.point_origin), decltype(si::absolute_zero)>);
static_assert(std::is_same_v<decltype(qp4.point_origin), decltype(si::ice_point)>);
```

If we want to obtain the values of quantities in specific units relative to the origins
of their scales, we have to be explicit:

```cpp
std::println("qp1: {}, {}, {}",
              qp1.quantity_from(si::absolute_zero),
              qp1.quantity_from(si::ice_point).in(deg_C),
              qp1.quantity_from(usc::zero_Fahrenheit).in(deg_F));
std::println("qp2: {}, {}, {}",
              qp2.quantity_from(si::absolute_zero).in(K),
              qp2.quantity_from(si::ice_point),
              qp2.quantity_from(usc::zero_Fahrenheit).in(deg_F));
```

The above outputs:

```text
qp1: 300 K, 26.85 °C, 80.33 °F
qp2: 303.15 K, 30 °C, 86 °F
```

Of course, all other combinations are also possible. For example, nothing should prevent us
from checking how many degrees of Celsius are there starting from the `zero_Fahrenheit` for
a quantity point using kelvins with the `absolute_zero` origin:

```cpp
quantity q = qp1.quantity_from(usc::zero_Fahrenheit).in(deg_C);
```

Please also note that there is no text output support for quantity points in the [@MP-UNITS]
library.

## Structural types

The `quantity` and `quantity_point` class templates are structural types to allow them to be passed
as template arguments. For example, we can write the following:

```cpp
constexpr struct amsterdam_sea_level : absolute_point_origin<isq::altitude> {
} amsterdam_sea_level;

constexpr struct mediterranean_sea_level : relative_point_origin<amsterdam_sea_level + isq::altitude(-27 * cm)> {
} mediterranean_sea_level;

using altitude_DE = quantity_point<isq::altitude[m], amsterdam_sea_level>;
using altitude_CH = quantity_point<isq::altitude[m], mediterranean_sea_level>;
```

Unfortunately, current language rules require that all member data of a structural type are public.
This could be considered a safety issue. We try really hard to provide unit-safe interfaces, but
at the same time expose the public "naked" data member that can be freely read or manipulated by
anyone.

Hopefully, this requirement on structural types will be relaxed before the library gets
standardized.


# Teachability



# Acknowledgements

Special thanks and recognition goes to [Epam Systems](http://www.epam.com) for supporting
Mateusz's membership in the ISO C++ Committee and the production of this proposal.

We would also like to thank Peter Sommerlad for providing valuable feedback that helped us shape
the final version of this document.

<!-- markdownlint-disable -->

---
references:
- id: ARIANE
  citation-label: Ariane flight V88
  title: "Ariane flight V88"
  URL: <https://en.wikipedia.org/wiki/Ariane_flight_V88>
- id: AU
  citation-label: Au
  title: "The Au Units library"
  URL: <https://aurora-opensource.github.io/au>
- id: BIPM-VIM
  citation-label: JCGM 200:2012
  title: "International vocabulary of metrology - Basic and general concepts and associated terms (VIM) (JCGM 200:2012, 3rd edition)"
  URL: <https://jcgm.bipm.org/vim/en>
- id: BOOST-UNITS
  citation-label: Boost.Units
  author:
    - family: Schabel
      given: Matthias C.
    - family: Watanabe
      given: Steven
  title: "Boost.Units"
  URL: <https://www.boost.org/doc/libs/1_83_0/doc/html/boost_units.html>
- id: CHEP98
  citation-label: CHEP'98
  author:
    - family: Brown
      given: Walter E.
  title: "Introduction to the SI Library of Unit-Based Computation"
  URL: <https://digital.library.unt.edu/ark:/67531/metadc668099>
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
  URL: <https://web.archive.org/web/20210917190721/https://www.ntsb.gov/news/press-releases/Pages/Korean_Air_Flight_6316_MD-11_Shanghai_China_-_April_15_1999.aspx>
- id: GIMLI_GLIDER
  citation-label: Gimli Glider
  title: "Gimli Glider"
  URL: <https://en.wikipedia.org/wiki/Gimli_Glider>
- id: HOCHRHEINBRÜCKE
  citation-label: Hochrheinbrücke
  title: "An embarrassing discovery during the construction of a bridge"
  URL: <https://www.normaalamsterdamspeil.nl/wp-content/uploads/2015/03/website_bridge.pdf>
- id: ISO-GUIDE
  citation-label: ISO/IEC Guide 99
  title: "ISO/IEC Guide 99: International vocabulary of metrology — Basic and general concepts and associated terms (VIM)"
  URL: <https://www.iso.org/obp/ui#iso:std:iso-iec:guide:99>
- id: ISO80000
  citation-label: ISO 80000
  title: "ISO80000: Quantities and units"
  URL: <https://www.iso.org/standard/76921.html>
- id: JSR-385
  citation-label: JSR 385
  title: "Units of Measurement"
  URL: <https://unitsofmeasurement.github.io/indriya>
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
- id: MISRA_CPP
  citation-label: MISRA C++
  title: "MISRA C++:2008 Guidelines for the use of the C++ language in critical systems"
  URL: <https://misra.org.uk/misra-c-plus-plus/>
- id: MP-UNITS
  citation-label: mp-units
  title: "mp-units - A Physical Quantities and Units library for C++"
  URL: <https://mpusz.github.io/mp-units>
- id: NHOLTHAUS-UNITS
  citation-label: nholthaus/units
  title: "UNITS - A compile-time, header-only, dimensional analysis and unit conversion library built on c++14 with no dependencies."
  URL: <https://github.com/nholthaus/units>
- id: PINT
  citation-label: Pint
  title: "Pint: makes units easy"
  URL: <https://pint.readthedocs.io/en/stable/index.html>
- id: SI
  citation-label: SI
  title: "SI Brochure: The International System of Units (SI)"
  URL: <https://www.bipm.org/en/publications/si-brochure>
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
- id: THE_GUARDIAN
  citation-label: The Guardian
  author:
    - family: Pensulo
      given: Charles
  title: "Record Heat: Malawi swelters with temperatures nearly 68F above average"
  URL: <https://randomascii.wordpress.com/2023/10/17/localization-failure-temperature-is-hard>
- id: VASA
  citation-label: Vasa
  author:
    - family: Chatterjee
      given: Rhitu
    - family: Mullins
      given: Lisa
  title: "New Clues Emerge in Centuries-Old Swedish Shipwreck"
  URL: <https://theworld.org/stories/2012-02-23/new-clues-emerge-centuries-old-swedish-shipwreck>
- id: VCINL
  citation-label: Value Category Is Not Lifetime
  author:
    - family: O’Dwyer
      given: Arthur
  title: "Value Category Is Not Lifetime"
  URL: <https://quuxplusone.github.io/blog/2019/03/11/value-category-is-not-lifetime/>
- id: WILD_RICE
  citation-label: Wild Rice
  title: "Manufacturers, exporters think metric"
  URL: <https://www.bizjournals.com/eastbay/stories/2001/07/09/focus3.html>
---
