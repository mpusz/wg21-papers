---
title: "Minimal SI: Defining the International System of Units for the C++ Standard Library"
document: P4213R0
date: today
audience:
  - Library Evolution Working Group
author:
  - name: Mateusz Pusz
    email: <mateusz.pusz@gmail.com>
toc-depth: 3
---

# Introduction

This paper is a companion to [@P3045R8_PRE] (Quantities and Units Library). Its purpose is to
present to LEWG a complete, structured reference of all definitions required to implement the
International System of Units (SI) within a `std::` quantities library, so that LEWG can make
informed decisions about scope, phasing, and feasibility of standardization.

::: note
All synopses in this paper are derived from the open-source
[mp-units](https://github.com/mpusz/mp-units) library, adapted to use `std::` namespaces.
The intent is to show the scope of what standardization requires, not to mandate any
particular implementation strategy.
:::

::: note
The synopses assume that two features proposed in [@P4185R0_PRE] are accepted:

- **Non-negativity**: if not accepted, all `non_negative` tags in `quantity_spec` definitions
  can simply be dropped.
- **Absolute quantities**: if not accepted, `kelvin` must revert to the [@P3045R8_PRE] design —
  declaring `absolute_zero` as an `absolute_point_origin` and passing it as the explicit point
  origin of the unit.
:::

## What Is SI?

The **International System of Units** (SI) is the modern metric system and the world's
predominant measurement framework, adopted universally in science, engineering, commerce, and
everyday life. It is maintained by the International Bureau of Weights and Measures (BIPM) and
defined in the SI Brochure [@SI].

SI is built on seven **base units** corresponding to the seven base quantities of the
International System of Quantities (ISQ):

| ISQ quantity              | SI unit  | Symbol |
|---------------------------|----------|--------|
| time                      | second   | s      |
| length                    | metre    | m      |
| mass                      | kilogram | kg     |
| electric current          | ampere   | A      |
| thermodynamic temperature | kelvin   | K      |
| amount of substance       | mole     | mol    |
| luminous intensity        | candela  | cd     |

All other SI units are derived from these seven by multiplication and division. Twenty-two
derived units have been given special names and symbols (newton, pascal, joule, watt, etc.).
SI also standardizes **24 unit prefixes** ranging from quecto (10⁻³⁰) to quetta (10³⁰), and
a set of **non-SI units accepted for use with SI** (minute, hour, litre, electronvolt, etc.).

## The 2019 Redefinition

Before 2019, several SI base units were defined by physical artifacts or experimentally
determined constants. The kilogram, for example, was defined by the mass of a platinum-iridium
cylinder kept at the BIPM in Sèvres, France.

On 20 May 2019, a landmark redefinition came into effect: all seven SI base units are now
derived by fixing the numerical values of seven **defining constants**:

| Constant                                 | Symbol | Exact value               |
|------------------------------------------|--------|---------------------------|
| Hyperfine transition frequency of Cs-133 | Δν_Cs  | 9 192 631 770 Hz          |
| Speed of light in vacuum                 | c      | 299 792 458 m/s           |
| Planck constant                          | h      | 6.626 070 15 × 10⁻³⁴ J·s  |
| Elementary charge                        | e      | 1.602 176 634 × 10⁻¹⁹ C   |
| Boltzmann constant                       | k      | 1.380 649 × 10⁻²³ J/K     |
| Avogadro constant                        | N_A    | 6.022 140 76 × 10²³ mol⁻¹ |
| Luminous efficacy                        | K_cd   | 683 lm/W                  |

These values are now exact by definition — there is no experimental uncertainty. The 2019
redefinition makes SI more stable and reproducible.

For a C++ library, this versioning is significant: the numerical values of the defining
constants are specific to the 2019 edition. A future SI revision could alter them. A well-
designed library should therefore make the SI edition explicit in the API (see
[SI-Defining Constants](#optional-si-defining-constants-stdsiconst)).

## Main Components

The following components are covered by this paper, organized by namespace.

**ISQ (`std::isq` namespace) — independent of any unit system:**

1. **Base dimensions** — the 7 base dimensions (`dim_length`, `dim_mass`, `dim_time`,
   `dim_electric_current`, `dim_thermodynamic_temperature`, `dim_amount_of_substance`,
   `dim_luminous_intensity`) that form the dimensional foundation of the system.
2. **Base quantities** — the 7 base quantities (`length`, `mass`, `duration`,
   `electric_current`, `thermodynamic_temperature`, `amount_of_substance`,
   `luminous_intensity`) corresponding to the 7 SI base units.
3. **SI-relevant derived quantities** — the derived quantities required to correctly classify
   all SI named units: geometry (`width`, `radius`, `path_length`, `area`, `period_duration`,
   `angular_measure`, `solid_angular_measure`, `frequency`), mechanics (`energy`, `force`,
   `pressure`), electromagnetism (`electric_potential`, `capacitance`, `impedance`,
   `admittance`, `magnetic_flux_density`), light and radiation (`luminous_flux`,
   `illuminance`), physical chemistry (`catalytic_activity`), and atomic/nuclear physics
   (`activity`, `absorbed_dose`, `dose_equivalent`).

**SI core (`std::si` namespace) — depends on ISQ:**

1. **Prefixes** — 24 multiplicative scale factors from quecto to quetta.
2. **Base units** — 7 named units plus the special treatment of the kilogram (which already
   carries a prefix and must therefore be derived from `gram`).
3. **Derived units with special names** — 22 coherent derived units such as newton and joule,
   plus the degree Celsius which requires a temperature point origin.

**SI optional (`std::si` and related namespaces) — each independently votable:**

1. **Non-SI units accepted for use with SI** — time units (minute, hour, day), angular units
   (degree, arcminute, arcsecond), and others; placed in a dedicated namespace (name open to
   LEWG discussion) and re-exported into `std::si`.
2. **SI-defining constants** — the 7 exact constants plus a small number of commonly needed
   derived constants; versioned by inline subnamespace.
3. **Unit symbols** — short-form aliases (`m`, `km`, `Hz`, ...) for all prefix–unit
   combinations.
4. **`std::chrono` interoperability** — conversion between SI time quantities and
   `std::chrono::duration` / `std::chrono::time_point`.
5. **Trigonometric functions for SI angles** — `sin`, `cos`, `tan`, `asin`, `acos`, `atan`,
   `atan2` overloads that accept and return `quantity_of<isq::angular_measure>`.
6. **Prefix utilities** — an `invoke_with_prefixed` facility for automatically selecting the
   most appropriate SI prefix when formatting a quantity for display.

## Proposed Standardization Approach

The components above are organized into three groups:

- **ISQ** (`<isq_si_quantities>`): The minimal ISQ subset required to define SI — base
  dimensions, base quantities, and the derived quantities needed to classify all 22 SI
  named units. `<si_core>` depends directly on `<isq_si_quantities>`. The `<isq>` header
  is an aggregate that will grow to cover the full ISO/IEC 80000 series as more parts are
  standardized; `<si_core>` does not depend on it.

- **SI core** (`<si_core>`): The minimum needed to express any SI quantity — prefixes, base
  units, and derived units. Depends on `<isq_si_quantities>`. All SI optional components
  depend on this.

- **SI optional** (separate headers): Each additional feature is placed in its own header and
  constitutes an independently reviewable and votable chapter of this paper. Optional headers
  are further classified as freestanding-compatible or hosted-only (the latter require
  `<chrono>` or `<cmath>`); see the header summary table for the complete classification.

### Header Naming

Header names follow a flat, underscore-separated convention — for example `<si_core>`,
`<si_constants>`, `<isq>` — rather than a slash-based hierarchy. A slash-based scheme would
require both a file named `si` (for an aggregate header) and a directory named `si/` (for
sub-headers) to coexist, which is impossible on POSIX filesystems when header names map
directly to file paths.

Three headers are relevant to the entire scope:

- `<isq_si_quantities>` — the minimal ISQ subset for SI; lives in `std::isq` and is
  independent of any unit system. Other unit systems may depend on it without taking a
  dependency on `<si_core>`.
- `<isq>` — aggregate of all ISQ headers; will grow as ISO/IEC 80000 parts are
  standardized. `<si_core>` does not depend on it.
- `<si>` — includes all SI headers: `<si_core>`, `<si_non_si_units>`, `<si_constants>`,
  `<si_unit_symbols>`, `<si_chrono>`, `<si_math>`, and `<si_prefix_utils>`.

LEWG should consider voting on `<isq_si_quantities>` (§2), `<si_core>` (§3), and each
optional chapter (§4–§9) separately.

The remainder of this paper presents the C++ synopsis for each component, together with a
definition count and a rationale for its classification as mandatory or optional.

## C++ Modules

Since C++23, the entire standard library is exposed as a single module — `import std;`. All SI
and ISQ definitions would simply be part of that aggregate, and no separate module hierarchy
is needed.

If a future standard wishes to introduce finer-grained modules, they could look like:

```cpp
import std.si;            // all SI definitions
import std.isq;           // all ISQ definitions
```

# The International System of Quantities (`<isq_si_quantities>`)

ISQ (ISO 80000) defines physical quantities independently of any unit system; the full
standard spans over 10 parts covering hundreds of quantities. This paper standardizes only
the minimal subset needed to define SI: seven base dimensions, seven base quantities, and
the derived quantities required to correctly classify the 22 SI coherent derived units.
All of these reside in `std::isq` and are provided by a single header, `<isq_si_quantities>`.

## Base Dimensions

```cpp
namespace std::isq {

inline constexpr struct dim_length : base_dimension<"L"> {} dim_length;
inline constexpr struct dim_mass : base_dimension<"M"> {} dim_mass;
inline constexpr struct dim_time : base_dimension<"T"> {} dim_time;
inline constexpr struct dim_electric_current : base_dimension<"I"> {} dim_electric_current;
inline constexpr struct dim_thermodynamic_temperature : base_dimension<symbol_text{u8"Θ", "O"}> {} dim_thermodynamic_temperature;
inline constexpr struct dim_amount_of_substance : base_dimension<"N"> {} dim_amount_of_substance;
inline constexpr struct dim_luminous_intensity : base_dimension<"J"> {} dim_luminous_intensity;

} // namespace std::isq
```

This introduces **7 names** in `std::isq`.

## Base Quantities

```cpp
namespace std::isq {

inline constexpr struct length : quantity_spec<dim_length, non_negative> {} length;
inline constexpr struct mass : quantity_spec<dim_mass, non_negative> {} mass;
inline constexpr struct duration : quantity_spec<dim_time, non_negative> {} duration;
inline constexpr auto time = duration;
inline constexpr struct electric_current : quantity_spec<dim_electric_current> {} electric_current;
inline constexpr struct thermodynamic_temperature : quantity_spec<dim_thermodynamic_temperature, non_negative> {} thermodynamic_temperature;
inline constexpr struct amount_of_substance : quantity_spec<dim_amount_of_substance, non_negative> {} amount_of_substance;
inline constexpr struct luminous_intensity : quantity_spec<dim_luminous_intensity, non_negative> {} luminous_intensity;

} // namespace std::isq
```

This introduces **8 names** in `std::isq` (7 base quantity types and a `time` alias for
`duration`, which is the SI name for the same base quantity).

## SI-Relevant Derived Quantities

The following derived quantities form the minimal ISQ subset needed to correctly classify
all 22 SI named derived units:

```cpp
namespace std::isq {

// space and time
inline constexpr struct width : quantity_spec<length> {} width;
inline constexpr auto breadth = width;
inline constexpr struct radius : quantity_spec<width> {} radius;
inline constexpr struct path_length : quantity_spec<length> {} path_length;
inline constexpr auto arc_length = path_length;
inline constexpr struct area : quantity_spec<pow<2>(length), non_negative> {} area;
inline constexpr struct angular_measure : quantity_spec<dimensionless, arc_length / radius, is_kind>  {} angular_measure;
inline constexpr struct solid_angular_measure
    : quantity_spec<dimensionless, area / pow<2>(radius), is_kind, non_negative> {} solid_angular_measure;
inline constexpr struct period_duration : quantity_spec<duration> {} period_duration;
inline constexpr auto period = period_duration;
inline constexpr struct frequency : quantity_spec<inverse(period_duration), non_negative> {} frequency;

// mechanics
inline constexpr struct energy : quantity_spec<mass * pow<2>(length) / pow<2>(duration), non_negative> {} energy;
inline constexpr struct force : quantity_spec<mass * length / pow<2>(duration), quantity_character::vector> {} force;
inline constexpr struct pressure : quantity_spec<force / area, quantity_character::real_scalar> {} pressure;

// electromagnetism
inline constexpr struct electric_potential
    : quantity_spec<energy / (electric_current * duration), quantity_character::real_scalar> {} electric_potential;
inline constexpr struct capacitance
    : quantity_spec<electric_current * duration / electric_potential, non_negative> {} capacitance;
inline constexpr struct impedance
    : quantity_spec<electric_potential / electric_current, quantity_character::complex_scalar> {} impedance;
inline constexpr struct admittance
    : quantity_spec<inverse(impedance), quantity_character::complex_scalar> {} admittance;
inline constexpr struct magnetic_flux_density
    : quantity_spec<mass / (electric_current * pow<2>(duration)), quantity_character::vector> {} magnetic_flux_density;

// light and radiation
inline constexpr struct luminous_flux
    : quantity_spec<luminous_intensity * solid_angular_measure, non_negative> {} luminous_flux;
inline constexpr struct illuminance : quantity_spec<luminous_flux / area, non_negative> {} illuminance;

// physical chemistry
inline constexpr struct catalytic_activity : quantity_spec<amount_of_substance / duration, non_negative> {} catalytic_activity;

// atomic and nuclear physics
inline constexpr struct activity : quantity_spec<inverse(duration), non_negative> {} activity;
inline constexpr struct absorbed_dose : quantity_spec<energy / mass, non_negative> {} absorbed_dose;
inline constexpr struct ionizing_radiation_quality_factor
    : quantity_spec<dimensionless, non_negative> {} ionizing_radiation_quality_factor;
inline constexpr struct dose_equivalent
    : quantity_spec<absorbed_dose * ionizing_radiation_quality_factor, non_negative> {} dose_equivalent;

} // namespace std::isq
```

This introduces **26 names** in `std::isq` (23 derived quantity types and 3 aliases:
`breadth`, `arc_length`, and `period`).

### Summary of ISQ Definitions

| Component                                      | Names introduced |
|------------------------------------------------|------------------|
| Base dimensions                                | 7                |
| Base quantities (incl. `time` alias)           | 8                |
| SI-relevant derived quantities (incl. aliases) | 26               |
| **Total**                                      | **41**           |

Straw poll: _We want `<isq_si_quantities>` — the minimal ISQ subset (41 definitions) required
by `<si_core>` — to be standardized as part of the quantities and units library._

# Core SI Definitions (`<si_core>`)

`<si_core>` is the single mandatory SI header. It provides the 24 SI prefixes and all
base and derived unit definitions.

## SI Prefixes

The 24 standard SI prefixes are defined as class templates parameterised on a
`PrefixableUnit` type, together with corresponding variable templates that provide the
user-facing API:

```cpp
namespace std::si {

template<PrefixableUnit U> struct quecto_ : prefixed_unit<"q",  mag_power<10, -30>, U{}> {};
template<PrefixableUnit U> struct ronto_  : prefixed_unit<"r",  mag_power<10, -27>, U{}> {};
template<PrefixableUnit U> struct yocto_  : prefixed_unit<"y",  mag_power<10, -24>, U{}> {};
template<PrefixableUnit U> struct zepto_  : prefixed_unit<"z",  mag_power<10, -21>, U{}> {};
template<PrefixableUnit U> struct atto_   : prefixed_unit<"a",  mag_power<10, -18>, U{}> {};
template<PrefixableUnit U> struct femto_  : prefixed_unit<"f",  mag_power<10, -15>, U{}> {};
template<PrefixableUnit U> struct pico_   : prefixed_unit<"p",  mag_power<10, -12>, U{}> {};
template<PrefixableUnit U> struct nano_   : prefixed_unit<"n",  mag_power<10,  -9>, U{}> {};
template<PrefixableUnit U> struct micro_  : prefixed_unit<symbol_text{u8"µ", "u"}, mag_power<10, -6>, U{}> {};
template<PrefixableUnit U> struct milli_  : prefixed_unit<"m",  mag_power<10,  -3>, U{}> {};
template<PrefixableUnit U> struct centi_  : prefixed_unit<"c",  mag_power<10,  -2>, U{}> {};
template<PrefixableUnit U> struct deci_   : prefixed_unit<"d",  mag_power<10,  -1>, U{}> {};
template<PrefixableUnit U> struct deca_   : prefixed_unit<"da", mag_power<10,   1>, U{}> {};
template<PrefixableUnit U> struct hecto_  : prefixed_unit<"h",  mag_power<10,   2>, U{}> {};
template<PrefixableUnit U> struct kilo_   : prefixed_unit<"k",  mag_power<10,   3>, U{}> {};
template<PrefixableUnit U> struct mega_   : prefixed_unit<"M",  mag_power<10,   6>, U{}> {};
template<PrefixableUnit U> struct giga_   : prefixed_unit<"G",  mag_power<10,   9>, U{}> {};
template<PrefixableUnit U> struct tera_   : prefixed_unit<"T",  mag_power<10,  12>, U{}> {};
template<PrefixableUnit U> struct peta_   : prefixed_unit<"P",  mag_power<10,  15>, U{}> {};
template<PrefixableUnit U> struct exa_    : prefixed_unit<"E",  mag_power<10,  18>, U{}> {};
template<PrefixableUnit U> struct zetta_  : prefixed_unit<"Z",  mag_power<10,  21>, U{}> {};
template<PrefixableUnit U> struct yotta_  : prefixed_unit<"Y",  mag_power<10,  24>, U{}> {};
template<PrefixableUnit U> struct ronna_  : prefixed_unit<"R",  mag_power<10,  27>, U{}> {};
template<PrefixableUnit U> struct quetta_ : prefixed_unit<"Q",  mag_power<10,  30>, U{}> {};

template<PrefixableUnit auto U> constexpr quecto_<decltype(U)> quecto;
template<PrefixableUnit auto U> constexpr ronto_<decltype(U)> ronto;
template<PrefixableUnit auto U> constexpr yocto_<decltype(U)> yocto;
template<PrefixableUnit auto U> constexpr zepto_<decltype(U)> zepto;
template<PrefixableUnit auto U> constexpr atto_<decltype(U)> atto;
template<PrefixableUnit auto U> constexpr femto_<decltype(U)> femto;
template<PrefixableUnit auto U> constexpr pico_<decltype(U)> pico;
template<PrefixableUnit auto U> constexpr nano_<decltype(U)> nano;
template<PrefixableUnit auto U> constexpr micro_<decltype(U)> micro;
template<PrefixableUnit auto U> constexpr milli_<decltype(U)> milli;
template<PrefixableUnit auto U> constexpr centi_<decltype(U)> centi;
template<PrefixableUnit auto U> constexpr deci_<decltype(U)> deci;
template<PrefixableUnit auto U> constexpr deca_<decltype(U)> deca;
template<PrefixableUnit auto U> constexpr hecto_<decltype(U)> hecto;
template<PrefixableUnit auto U> constexpr kilo_<decltype(U)> kilo;
template<PrefixableUnit auto U> constexpr mega_<decltype(U)> mega;
template<PrefixableUnit auto U> constexpr giga_<decltype(U)> giga;
template<PrefixableUnit auto U> constexpr tera_<decltype(U)> tera;
template<PrefixableUnit auto U> constexpr peta_<decltype(U)> peta;
template<PrefixableUnit auto U> constexpr exa_<decltype(U)> exa;
template<PrefixableUnit auto U> constexpr zetta_<decltype(U)> zetta;
template<PrefixableUnit auto U> constexpr yotta_<decltype(U)> yotta;
template<PrefixableUnit auto U> constexpr ronna_<decltype(U)> ronna;
template<PrefixableUnit auto U> constexpr quetta_<decltype(U)> quetta;

} // namespace std::si
```

This introduces **48 names** in `std::si` (24 class templates + 24 variable templates).

## SI Units

### Base Units

```cpp
namespace std::si {

inline constexpr struct second : named_unit<"s", kind_of<isq::duration>> {} second;
inline constexpr struct metre  : named_unit<"m", kind_of<isq::length>> {} metre;
inline constexpr struct gram   : named_unit<"g", kind_of<isq::mass>> {} gram;
inline constexpr auto kilogram = kilo<gram>;
inline constexpr struct ampere : named_unit<"A", kind_of<isq::electric_current>> {} ampere;
inline constexpr struct kelvin : named_unit<"K", kind_of<isq::thermodynamic_temperature>> {} kelvin;
inline constexpr struct mole    : named_unit<"mol", kind_of<isq::amount_of_substance>> {} mole;
inline constexpr struct candela : named_unit<"cd", kind_of<isq::luminous_intensity>> {} candela;

} // namespace std::si
```

This introduces **8 names** in `std::si`. Note that `kilogram` is defined as `kilo<gram>`
rather than as a primary unit. This is by design: because `kilogram` already carries the `kilo`
prefix, SI prefixes must be applied to `gram` (e.g., `milli<gram>`, `micro<gram>`). The library
models this correctly by treating `gram` as the prefixable base and deriving `kilogram` from it.

Under the absolute quantities model from [@P4185R0_PRE], `kelvin` requires no explicit point origin.
A `quantity<si::kelvin>` is intrinsically absolute — `28 * K` compiles and produces an absolute
thermodynamic temperature directly. In the pre-P4185 design ([@P3045R8_PRE]), `kelvin` had to declare
`absolute_zero` as an `absolute_point_origin`, which prevented the multiply syntax from being
used and forced users to write `absolute_zero + 28 * K` instead.

### Derived Units with Special Names

SI defines 22 coherent derived units with special names, plus three temperature-related
definitions (`absolute_zero`, `ice_point`, `degree_Celsius`):

```cpp
namespace std::si {

inline constexpr struct radian    : named_unit<"rad", metre / metre, kind_of<isq::angular_measure>> {} radian;
inline constexpr struct steradian : named_unit<"sr",  square(metre) / square(metre), kind_of<isq::solid_angular_measure>> {} steradian;
inline constexpr struct hertz   : named_unit<"Hz",  one / second, kind_of<isq::frequency>> {} hertz;
inline constexpr struct newton  : named_unit<"N",   kilogram * metre / square(second), kind_of<isq::force>> {} newton;
inline constexpr struct pascal  : named_unit<"Pa",  newton / square(metre), kind_of<isq::pressure>> {} pascal;
inline constexpr struct joule   : named_unit<"J",   newton * metre, kind_of<isq::energy>> {} joule;
// No kind_of: W is shared by isq::power, isq::heat_flow_rate, isq::active_power, isq::radiant_flux, etc.
inline constexpr struct watt    : named_unit<"W",   joule / second> {} watt;
// No kind_of: C is shared by isq::electric_charge and isq::electric_flux (different ISQ hierarchies).
inline constexpr struct coulomb : named_unit<"C",   ampere * second> {} coulomb;
inline constexpr struct volt    : named_unit<"V",   watt / ampere, kind_of<isq::electric_potential>> {} volt;
inline constexpr struct farad   : named_unit<"F",   coulomb / volt, kind_of<isq::capacitance>> {} farad;
inline constexpr struct ohm     : named_unit<symbol_text{u8"Ω", "ohm"}, volt / ampere, kind_of<isq::impedance>> {} ohm;
inline constexpr struct siemens : named_unit<"S",   one / ohm, kind_of<isq::admittance>> {} siemens;
// No kind_of: Wb is shared by isq::magnetic_flux, isq::protoflux, isq::linked_magnetic_flux, etc.
inline constexpr struct weber   : named_unit<"Wb",  volt * second> {} weber;
inline constexpr struct tesla   : named_unit<"T",   weber / square(metre), kind_of<isq::magnetic_flux_density>> {} tesla;
// No kind_of: H is shared by isq::inductance and isq::permeance (different ISQ hierarchies).
inline constexpr struct henry   : named_unit<"H",   weber / ampere> {} henry;

inline constexpr struct absolute_zero : relative_point_origin<point<kelvin>(0)> {} absolute_zero;
inline constexpr struct ice_point : relative_point_origin<point<milli<kelvin>>(273'150)> {} ice_point;
inline constexpr struct degree_Celsius : named_unit<symbol_text{u8"℃", "`C"}, kelvin, ice_point> {} degree_Celsius;

inline constexpr struct lumen     : named_unit<"lm",  candela * steradian, kind_of<isq::luminous_flux>> {} lumen;
inline constexpr struct lux       : named_unit<"lx",  lumen / square(metre), kind_of<isq::illuminance>> {} lux;
inline constexpr struct becquerel : named_unit<"Bq",  one / second, kind_of<isq::activity>> {} becquerel;
inline constexpr struct gray      : named_unit<"Gy",  joule / kilogram, kind_of<isq::absorbed_dose>> {} gray;
inline constexpr struct sievert   : named_unit<"Sv",  joule / kilogram, kind_of<isq::dose_equivalent>> {} sievert;
inline constexpr struct katal     : named_unit<"kat", mole / second, kind_of<isq::catalytic_activity>> {} katal;

} // namespace std::si
```

This introduces **25 names** in `std::si`: the 22 coherent derived units with special names,
plus `absolute_zero`, `ice_point`, and `degree_Celsius`.

::: note
Four SI named units are deliberately defined without a `kind_of<>` constraint because they
serve multiple unrelated ISQ quantity hierarchies. Restricting them to a single kind would
incorrectly reject legitimate uses from the other hierarchies.

| Unit          | ISQ quantity hierarchies that use it                                                                                             |
|---------------|----------------------------------------------------------------------------------------------------------------------------------|
| `watt (W)`    | _power_, _heat flow rate_, _active power_, _radiant flux_ — spanning mechanics, thermodynamics, electromagnetism, and radiometry |
| `coulomb (C)` | _electric charge_ and _electric flux_ — distinct hierarchies sharing the same dimension                                          |
| `weber (Wb)`  | _magnetic flux_, _protoflux_, _linked magnetic flux_, _total magnetic flux_                                                      |
| `henry (H)`   | _inductance_ and _permeance_ — unrelated quantities with the same dimension                                                      |
:::

`absolute_zero` is defined as a `relative_point_origin` at `point<kelvin>(0)` — a named origin
at 0 K — rather than as an `absolute_point_origin`. Under the absolute quantities model from
[@P4185R0_PRE], the natural zero of `isq::thermodynamic_temperature` is implicit in every kelvin
quantity; there is no need for an independent origin declaration. `absolute_zero` is retained as
a named convenience for the `temp - absolute_zero` idiom and for explicit zero-point arithmetic.
`ice_point` is defined as an offset of 273.150 K from that same natural zero, and `degree_Celsius`
is the unit for quantities anchored at `ice_point`.

### Summary of Mandatory Definitions

| Component                          | Names introduced |
|------------------------------------|------------------|
| SI prefixes (class templates)      | 24               |
| SI prefixes (variable templates)   | 24               |
| SI base units                      | 8                |
| SI named derived units and origins | 25               |
| **Total**                          | **81**           |

Straw poll: _We want `<si_core>` — 81 SI definitions including 24 prefixes, 8 base units, and
25 derived units and origins — to be standardized as part of the quantities and units library._

# Optional: Non-SI Units Accepted for Use with SI (`<si_non_si_units>`)

The SI Brochure recognizes a number of units outside SI proper that are accepted for use
alongside it. These are placed in a dedicated namespace and re-exported into `std::si` for
convenience.

::: note
The `non_si` namespace name used here is a working name. The author does not insist on it —
it is introduced to make the separation from core SI units explicit. LEWG is welcome to
choose any name it sees fit.
:::

## Synopsis

```cpp
namespace std::non_si {

inline constexpr struct minute    : named_unit<"min", mag<60> * si::second> {} minute;
inline constexpr struct hour      : named_unit<"h",   mag<60> * minute> {} hour;
inline constexpr struct day       : named_unit<"d",   mag<24> * hour> {} day;
inline constexpr struct astronomical_unit : named_unit<"au",  mag<149'597'870'700> * si::metre> {} astronomical_unit;
inline constexpr struct degree    : named_unit<symbol_text{u8"°", "deg"}, mag_ratio<1, 180> * π * si::radian> {} degree;
inline constexpr struct arcminute : named_unit<symbol_text{u8"′", "'"}, mag_ratio<1, 60> * degree> {} arcminute;
inline constexpr struct arcsecond : named_unit<symbol_text{u8"″", "''"}, mag_ratio<1, 60> * arcminute> {} arcsecond;
inline constexpr struct are       : named_unit<"a",   square(si::deca<si::metre>)> {} are;
inline constexpr auto hectare = si::hecto<are>;
inline constexpr struct litre     : named_unit<"L",   cubic(si::deci<si::metre>)> {} litre;
inline constexpr struct tonne     : named_unit<"t",   mag<1000> * si::kilogram> {} tonne;
inline constexpr struct dalton
    : named_unit<"Da", mag_ratio<16'605'390'666'050, 10'000'000'000'000> * mag_power<10, -27> * si::kilogram> {} dalton;
inline constexpr struct electronvolt
    : named_unit<"eV", mag_ratio<1'602'176'634, 1'000'000'000> * mag_power<10, -19> * si::joule> {} electronvolt;

} // namespace std::non_si

namespace std::si {
  using namespace non_si;
} // namespace std::si
```

Additionally, for the angular units, the library specializes the `space_before_unit_symbol`
customization point to suppress the space between the numerical value and the degree symbol.
The SI Brochure [@SI] §5.4.3 states that the unit symbols °, ′, and ″ are not preceded by a
space:

```cpp
template<> inline constexpr bool space_before_unit_symbol<non_si::degree> = false;
template<> inline constexpr bool space_before_unit_symbol<non_si::arcminute> = false;
template<> inline constexpr bool space_before_unit_symbol<non_si::arcsecond> = false;
```

This introduces **13 names** in `std::non_si` and **3 customization point specializations**.

## Why This Is a Separate Chapter

These units form a natural boundary with SI proper: they are recognized by the SI Brochure as
units accepted for use with SI, but they are not SI units. Separating them into a distinct
chapter lets LEWG decide on their inclusion independently of the core, and also allows the
namespace naming question (`non_si` or another name) to be resolved on its own schedule without
blocking the mandatory definitions.

Straw poll: _We want `<si_non_si_units>` — non-SI units accepted for use with SI — to be
included as part of the quantities and units library._

# Optional: SI-Defining Constants (`<si_constants>`)

`<si_constants>` provides the seven exact constants that define the 2019 SI, plus a small
set of derived constants in common use. These constants appear directly in physical equations
(E = mc², Planck's law, the ideal gas law, etc.) and, because they are `named_constant`
objects, they are unit-like: they embed in the types of quantity expressions. A function
returning `quantity<si::speed_of_light_in_vacuum * si::second>` has a type that is only
compatible with other code that names the same constant. Standardizing these definitions
therefore matters for library interoperability, not only for scientific computing.

## Versioning by Inline Subnamespace

Because the defining constants are specific to the 2019 edition of SI, they are placed in an
`inline namespace si2019` inside `std::si`. This achieves two goals simultaneously:

1. **Default access**: `std::si::speed_of_light_in_vacuum` resolves to the 2019 value without
   any additional qualification, since `si2019` is inline.
2. **Explicit versioning**: Code that must unambiguously refer to the 2019 values can write
   `std::si::si2019::speed_of_light_in_vacuum`. This form will remain stable even if a future
   SI revision introduces `inline namespace si20XX` with updated values.

If SI is redefined in the future, the new constants would be placed in `inline namespace si20XX`
and the `inline` qualifier would be moved from `si2019` to `si20XX`, making the new values the
default while preserving backward compatibility for code using the versioned form.

## Synopsis

```cpp
namespace std::si {

inline namespace si2019 {

inline constexpr struct hyperfine_structure_transition_frequency_of_cs
    : named_constant<symbol_text{u8"Δν_Cs", "dv_Cs"}, mag<9'192'631'770> * hertz> {} hyperfine_structure_transition_frequency_of_cs;

inline constexpr struct speed_of_light_in_vacuum
    : named_constant<"c", mag<299'792'458> * metre / second> {} speed_of_light_in_vacuum;

inline constexpr struct planck_constant
    : named_constant<"h", mag_ratio<662'607'015, 100'000'000> * mag_power<10, -34> * joule * second> {} planck_constant;

inline constexpr struct elementary_charge
    : named_constant<"e", mag_ratio<1'602'176'634, 1'000'000'000> * mag_power<10, -19> * coulomb> {} elementary_charge;

inline constexpr struct boltzmann_constant
    : named_constant<"k", mag_ratio<1'380'649, 1'000'000> * mag_power<10, -23> * joule / kelvin> {} boltzmann_constant;

inline constexpr struct avogadro_constant
    : named_constant<"N_A", mag_ratio<602'214'076, 100'000'000> * mag_power<10, 23> / mole> {} avogadro_constant;

inline constexpr struct luminous_efficacy : named_constant<"K_cd", mag<683> * lumen / watt> {} luminous_efficacy;

} // namespace si2019

// A selection of derived constants found useful in practice — this list is not exhaustive.
inline constexpr struct standard_gravity
  : named_constant<symbol_text{u8"g₀", "g_0"}, mag_ratio<980'665, 100'000> * metre / square(second)> {} standard_gravity;

inline constexpr struct reduced_planck_constant
  : named_constant<symbol_text{u8"ℏ", "hbar"}, si2019::planck_constant / (mag<2> * π)> {} reduced_planck_constant;

inline constexpr struct magnetic_constant
  : named_constant<symbol_text{u8"μ₀", "u_0"}, mag<4> * mag_power<10, -7> * π * henry / metre> {} magnetic_constant;

} // namespace std::si
```

This introduces **10 names** in `std::si`: the 7 SI-defining constants (within `si2019`) plus
3 additional constants (`standard_gravity`, `reduced_planck_constant`, `magnetic_constant`).

::: note
The three additional constants listed above are a small, arbitrary selection drawn from the
[mp-units](https://github.com/mpusz/mp-units) library — constants that proved useful in
practice. This list is neither normative nor complete: there are many other derived constants
in common use (Faraday constant, Stefan–Boltzmann constant, Rydberg constant, etc.). LEWG
should treat the question of which derived constants to include as a separate design decision,
independent of whether the seven SI-defining constants are standardized.
:::

## Why This Is a Separate Chapter

The seven defining constants and any derived constants form a distinct kind of vocabulary: they
are physical constants, not units, and they raise separate design questions — versioning
strategy, which derived constants to include, and how many. Separating them into a dedicated
chapter lets LEWG vote on these questions independently of the unit definitions.

Straw poll: _We want the seven SI-defining constants (`si2019` namespace) to be included as
part of the quantities and units library._

Straw poll: _We want a selected set of derived physical constants to be included as part of
the quantities and units library._

# Optional: Unit Symbols (`<si_unit_symbols>`)

`<si_unit_symbols>` provides short-form variable names for every combination of SI prefix
and SI unit. These are the symbols printed in textbooks and used in everyday engineering:
`m` for metre, `km` for kilometre, `Hz` for hertz, `MHz` for megahertz, and so on.

Using unit symbols enables concise, readable quantity expressions:

```cpp
using namespace std::si::unit_symbols;
quantity distance = 100 * km;
quantity time     = 9.58 * s;
quantity speed    = distance / time;  // approximately 10.44 km/s
```

The symbols are defined in `std::si::unit_symbols` and `std::non_si::unit_symbols`;
`std::si::unit_symbols` re-exports everything from `std::non_si::unit_symbols`.

## Synopsis (excerpt)

The complete synopsis is large. A representative excerpt for the metre is shown below; the same
pattern is repeated for every SI base and named derived unit:

```cpp
namespace std::si::unit_symbols {

// metre — all 24 SI prefix multiples, plus Unicode alias for micro
inline constexpr auto qm  = quecto<metre>;   // 10⁻³⁰ m
inline constexpr auto rm  = ronto<metre>;    // 10⁻²⁷ m
inline constexpr auto ym  = yocto<metre>;    // 10⁻²⁴ m
inline constexpr auto zm  = zepto<metre>;    // 10⁻²¹ m
inline constexpr auto am  = atto<metre>;     // 10⁻¹⁸ m
inline constexpr auto fm  = femto<metre>;    // 10⁻¹⁵ m
inline constexpr auto pm  = pico<metre>;     // 10⁻¹² m
inline constexpr auto nm  = nano<metre>;     // 10⁻⁹  m
inline constexpr auto um  = micro<metre>;    // 10⁻⁶  m  (ASCII alias)
inline constexpr auto µm  = micro<metre>;    // 10⁻⁶  m  (Unicode alias)
inline constexpr auto mm  = milli<metre>;    // 10⁻³  m
inline constexpr auto cm  = centi<metre>;    // 10⁻²  m
inline constexpr auto dm  = deci<metre>;     // 10⁻¹  m
inline constexpr auto m   = metre;           //        m
inline constexpr auto dam = deca<metre>;     // 10     m
inline constexpr auto hm  = hecto<metre>;    // 10²    m
inline constexpr auto km  = kilo<metre>;     // 10³    m
inline constexpr auto Mm  = mega<metre>;     // 10⁶    m
inline constexpr auto Gm  = giga<metre>;     // 10⁹    m
inline constexpr auto Tm  = tera<metre>;     // 10¹²   m
inline constexpr auto Pm  = peta<metre>;     // 10¹⁵   m
inline constexpr auto Em  = exa<metre>;      // 10¹⁸   m
inline constexpr auto Zm  = zetta<metre>;    // 10²¹   m
inline constexpr auto Ym  = yotta<metre>;    // 10²⁴   m
inline constexpr auto Rm  = ronna<metre>;    // 10²⁷   m
inline constexpr auto Qm  = quetta<metre>;   // 10³⁰   m

// The same pattern is repeated for:
//   s (second), g/kg (gram/kilogram), A (ampere), K (kelvin),
//   mol (mole), cd (candela), rad (radian), sr (steradian),
//   Hz (hertz), N (newton), Pa (pascal), J (joule), W (watt),
//   C (coulomb), V (volt), F (farad), Ω/ohm (ohm), S (siemens),
//   Wb (weber), T (tesla), H (henry), lm (lumen), lx (lux),
//   Bq (becquerel), Gy (gray), Sv (sievert), kat (katal).

// Units with non-ASCII symbols additionally provide Unicode variable names:
//   Ω alongside ohm, µ alongside u.

// Commonly used squared and cubic forms:
inline constexpr auto m2 = square(metre);
inline constexpr auto m3 = cubic(metre);
inline constexpr auto m4 = pow<4>(metre);
inline constexpr auto s2 = square(second);
inline constexpr auto s3 = cubic(second);

} // namespace std::si::unit_symbols
```

The non-SI unit symbols are in a separate namespace, and re-exported into `si::unit_symbols`:

```cpp
namespace std::non_si::unit_symbols {

inline constexpr auto au     = astronomical_unit;
inline constexpr auto deg    = degree;
inline constexpr auto arcmin = arcminute;
inline constexpr auto arcsec = arcsecond;
inline constexpr auto a      = are;
inline constexpr auto ha     = hectare;
inline constexpr auto l      = litre;
inline constexpr auto L      = litre;   // both spellings are permitted by SI
inline constexpr auto t      = tonne;
inline constexpr auto Da     = dalton;
inline constexpr auto eV     = electronvolt;
inline constexpr auto min    = minute;
inline constexpr auto h      = hour;
inline constexpr auto d      = day;

} // namespace std::non_si::unit_symbols

namespace std::si::unit_symbols {
  using namespace non_si::unit_symbols;
} // namespace std::si::unit_symbols
```

## Symbol Count

This is deliberately the largest component: for each of the 29 named SI units (7 base +
22 derived), up to 26 prefixed aliases are defined (25 prefixes plus the base symbol itself),
plus additional Unicode aliases where the standard unit symbol contains a non-ASCII character
(Ω/ohm, µ/u). The 14 non-SI unit symbols are comparatively modest.

The result is approximately **720+ named constants** in total.

This scale is an inherent property of SI: the standard explicitly sanctions every combination
of its 24 prefixes with every base and derived unit. These names must exist for code such as
`5 * MHz` or `300 * pm` to compile without resorting to verbose qualified expressions like
`5 * si::mega<si::hertz>`. LEWG should be aware of this magnitude when considering the unit
symbols chapter.

## Why This Is a Separate Chapter

Unit symbols are a large, self-contained convenience layer. With ~720 short names they
introduce distinct concerns — namespace pollution, compilation cost, and naming conflicts (e.g.,
`F`, `T`, `s`) — that merit independent consideration. LEWG may wish to accept the core unit
definitions while deferring or declining this chapter.

Short, unqualified symbols can conflict with existing names in user or library code. For
example, `F` clashes with a commonly used macro in some code bases, `T` can shadow template
parameters, and `s` can conflict with string literals in some contexts. Making this feature
opt-in (via a dedicated header and an explicit `using namespace std::si::unit_symbols;`)
respects the longstanding C++ principle of not polluting namespaces by default.

The intended usage pattern is to include `<si_unit_symbols>` and apply the `using`-directive in
`.cpp` implementation files. Header files that expose unit-aware interfaces should use the
long-form names (`si::kilo<si::metre>`, `si::hertz`, etc.), as `using`-directives in headers
are generally unwelcome. Projects that use only a handful of symbols may also be better served
by defining them locally, e.g., `inline constexpr auto km = si::kilo<si::metre>;`.

Straw poll: _We want `<si_unit_symbols>` — the ~720+ short-form unit symbol aliases — to be
included as part of the quantities and units library._

# Optional: `std::chrono` Interoperability (`<si_chrono>`)

`<si_chrono>` provides bidirectional interoperability between SI time quantities and the
`std::chrono` duration and time point types. This feature is only available in hosted
environments (it requires `<chrono>`).

## Synopsis

```cpp
namespace std {

// Customization point specialization enabling implicit construction of a
// quantity<si::second> (and prefixed variants) from a std::chrono::duration.
template<typename Rep, typename Period>
struct quantity_like_traits<chrono::duration<Rep, Period>> {
  static constexpr auto reference = /* SI time unit derived from Period */;
  static constexpr bool explicit_import = false;
  static constexpr bool explicit_export = false;
  using rep = Rep;
  using T   = chrono::duration<Rep, Period>;
  [[nodiscard]] static constexpr rep to_numerical_value(const T& q) noexcept;
  [[nodiscard]] static constexpr T   from_numerical_value(const rep& v) noexcept;
};

// Absolute point origin associated with a clock's epoch
template<typename C>
struct chrono_point_origin_ : absolute_point_origin<isq::time> {
  using clock = C;
};
template<typename C>
inline constexpr chrono_point_origin_<C> chrono_point_origin;

// Customization point specialization enabling conversion between
// std::chrono::time_point and quantity_point with a clock-based origin.
template<typename C, typename Rep, typename Period>
struct quantity_point_like_traits<
  chrono::time_point<C, chrono::duration<Rep, Period>>> {
  static constexpr auto reference   = /* SI time unit derived from Period */;
  static constexpr auto point_origin = chrono_point_origin<C>;
  static constexpr bool explicit_import = false;
  static constexpr bool explicit_export = false;
  using rep = Rep;
  using T   = chrono::time_point<C, chrono::duration<Rep, Period>>;
  [[nodiscard]] static constexpr rep to_numerical_value(const T& tp) noexcept;
  [[nodiscard]] static constexpr T   from_numerical_value(const rep& v) noexcept;
};

// Explicit export helpers
template<quantity_of<isq::duration> Q>
[[nodiscard]] constexpr auto to_chrono_duration(const Q& q);

template<quantity_point_of<isq::time> QP>
  requires is_specialization_of<decltype(QP::absolute_point_origin), chrono_point_origin_>
[[nodiscard]] constexpr auto to_chrono_time_point(const QP& qp);

} // namespace std
```

The period-to-unit mapping covers all standard `std::chrono` periods:

| `chrono` instantiation            | Mapped SI unit        |
|-----------------------------------|-----------------------|
| `chrono::nanoseconds`             | `nano<second>`        |
| `chrono::microseconds`            | `micro<second>`       |
| `chrono::milliseconds`            | `milli<second>`       |
| `chrono::seconds`                 | `second`              |
| `chrono::minutes`                 | `minute`              |
| `chrono::hours`                   | `hour`                |
| `chrono::days`                    | `day`                 |
| `chrono::weeks`                   | `7 * day`             |
| `chrono::duration<R, ratio<N,D>>` | `ratio<N,D> * second` |

The `quantity_like_traits` specialization with `explicit_export = false` allows implicit
construction of a `chrono::duration` from a quantity, but only when the target type is already
known at the call site:

```cpp
chrono::seconds s = 5 * si::second;    // OK — target type known, implicit export
```

When the target `chrono` type must be _deduced_ from the quantity's unit (for example in a
generic context, or when the unit is not one of the named `chrono` typedefs), the implicit path
is unavailable because `std::ratio` cannot be computed without inspecting the unit's canonical
magnitude. The helper functions cover this case:

```cpp
auto d = to_chrono_duration(750 * milli<second>);
// d is chrono::duration<int, ratio<1,1000>> — type deduced from the unit magnitude

auto tp = to_chrono_time_point(qty_point);
// tp is chrono::time_point<Clock, ...> — clock and period both deduced
```

`to_chrono_time_point` additionally requires that the `quantity_point`'s absolute origin is a
`chrono_point_origin_`, enforcing at compile time that the point is anchored to a clock epoch
and not to an arbitrary physical reference.

This introduces **2 struct templates**, **1 variable template**, **2 function templates**, and
**2 specializations** of library customization points.

## Why This Is a Separate Chapter

`std::chrono` interoperability is a distinct integration concern — it bridges two independent
library features and depends on `<chrono>`, a hosted-only facility. Separating it into its own
chapter lets LEWG vote on this integration independently and allows the mandatory core to remain
usable in freestanding environments.

Straw poll: _We want the `std::chrono` interoperability type traits (`quantity_like_traits`,
`quantity_point_like_traits`, `chrono_point_origin_`) to be included as part of the quantities
and units library._

Straw poll: _We want the explicit `to_chrono_duration` and `to_chrono_time_point` conversion
helpers to be included as part of the quantities and units library._

# Optional: Mathematical Functions for SI Angles (`<si_math>`)

`<si_math>` provides overloads of the standard trigonometric functions in the `std::si`
namespace. These overloads accept and return properly-typed SI angular quantities rather than
plain numerical values. This feature is only available in hosted environments (it requires
`<cmath>`).

## Motivation

The standard `<cmath>` functions `sin`, `cos`, `tan`, etc. operate on raw `double` values
representing radians. When using a quantities library, it is desirable to have overloads that:

- Accept `quantity<isq::angular_measure, R>` for any angular unit `R`, performing automatic
  conversion to radians before calling the underlying `std::sin`.
- Return a dimensionless `quantity` (for the forward functions) or a
  `quantity<isq::angular_measure, radian>` (for the inverse functions).

This ensures that, for example, `si::sin(30 * deg)` yields the same result as
`std::sin(π/6)`, without requiring the user to manually convert degrees to radians.

## Synopsis

```cpp
namespace std::si {

template<reference_of<isq::angular_measure> auto R, typename Rep>
  requires requires(Rep v) { sin(v); } || requires(Rep v) { std::sin(v); }
[[nodiscard]] quantity_of<dimensionless> auto sin(const quantity<R, Rep>& q) noexcept;

template<reference_of<isq::angular_measure> auto R, typename Rep>
  requires requires(Rep v) { cos(v); } || requires(Rep v) { std::cos(v); }
[[nodiscard]] quantity_of<dimensionless> auto cos(const quantity<R, Rep>& q) noexcept;

template<reference_of<isq::angular_measure> auto R, typename Rep>
  requires requires(Rep v) { tan(v); } || requires(Rep v) { std::tan(v); }
[[nodiscard]] quantity_of<dimensionless> auto tan(const quantity<R, Rep>& q) noexcept;

template<reference_of<dimensionless> auto R, typename Rep>
  requires requires(Rep v) { asin(v); } || requires(Rep v) { std::asin(v); }
[[nodiscard]] quantity_of<isq::angular_measure> auto asin(const quantity<R, Rep>& q) noexcept;

template<reference_of<dimensionless> auto R, typename Rep>
  requires requires(Rep v) { acos(v); } || requires(Rep v) { std::acos(v); }
[[nodiscard]] quantity_of<isq::angular_measure> auto acos(const quantity<R, Rep>& q) noexcept;

template<reference_of<dimensionless> auto R, typename Rep>
  requires requires(Rep v) { atan(v); } || requires(Rep v) { std::atan(v); }
[[nodiscard]] quantity_of<isq::angular_measure> auto atan(const quantity<R, Rep>& q) noexcept;

template<auto R1, typename Rep1, auto R2, typename Rep2>
  requires get_common_reference(R1, R2) &&
           (requires(Rep1 v1, Rep2 v2) { atan2(v1, v2); } || requires(Rep1 v1, Rep2 v2) { std::atan2(v1, v2); })
[[nodiscard]] quantity_of<isq::angular_measure> auto atan2(const quantity<R1, Rep1>& y, const quantity<R2, Rep2>& x) noexcept;

} // namespace std::si
```

This introduces **7 function templates** in `std::si`.

## Why This Is a Separate Chapter

Trigonometric overloads for SI angles are a self-contained addition. They depend on `<cmath>`
(a hosted-only facility) and concern a specific quantity kind (`angular_measure`); other math
overloads such as `sqrt`, `pow`, and `abs` belong to the general quantities framework rather
than SI. Separating them lets LEWG vote on this feature independently.

Straw poll: _We want `<si_math>` — trigonometric function overloads for SI angular quantities —
to be included as part of the quantities and units library._

# Optional: Prefix Utilities (`<si_prefix_utils>`)

`<si_prefix_utils>` provides a utility for automatically selecting the most appropriate
SI prefix for a quantity. This feature is only available in hosted environments
(it requires `<cmath>` for `log10`, `floor`, and `abs`).

## Motivation

A common need is to express a quantity using the prefix that keeps the numerical value in a
human-friendly range — whether for display, logging, or passing to another function. For
example, normalizing 0.003 m to 3 mm, or 1 500 000 Hz to 1.5 MHz. The `invoke_with_prefixed`
facility automates prefix selection and delegates the actual use of the rescaled quantity to a
user-supplied callable, making it useful wherever a "best-prefix" quantity is needed, not only
for formatting output.

## Synopsis

```cpp
namespace std::si {

enum class prefix_range : uint8_t {
  engineering,  // selects only powers of 1000 (milli, kilo, mega, ...)
                // resulting in a value in the range [1.0, 1000)
  full          // selects all 24 prefixes (including deca, hecto, deci, centi)
                // value in [1.0, 10) within the milli–kilo range, [1.0, 1000) elsewhere
};

/**
 * Calls func with q rescaled to the SI prefix that gives the numerical value
 * at least min_integral_digits digits in its integral part.
 */
template<Quantity Q, invocable<Q> Func, PrefixableUnit U, auto Character = quantity_character::real_scalar>
  requires RepresentationOf<typename Q::rep, Character> && treat_as_floating_point<typename Q::rep> &&
           requires(typename Q::rep v) {
             requires requires { abs(v);   } || requires { std::abs(v);   };
             requires requires { log10(v); } || requires { std::log10(v); };
             requires requires { floor(v); } || requires { std::floor(v); };
           }
constexpr decltype(auto) invoke_with_prefixed(Func func, Q q, U u,
                                              prefix_range range = prefix_range::engineering,
                                              int min_integral_digits = 1);

} // namespace std::si
```

Usage example:

```cpp
using namespace si::unit_symbols;
invoke_with_prefixed([](auto q){ std::print("{}", q); }, 0.003 * m, metre);
// prints "3 mm"

invoke_with_prefixed([](auto q){ std::print("{}", q); }, 1.5e6 * Hz, hertz);
// prints "1.5 MHz"

invoke_with_prefixed([](auto q){ std::print("{}", q); }, 42 * km, metre, prefix_range::engineering, 2);
// prints "42 km"  (at least 2 integral digits requested)
```

This introduces **1 scoped enumeration** and **1 function template** in `std::si`.

## Why This Is a Separate Chapter

Auto-prefix selection is a convenience utility — distinct in kind from SI definitions — for
obtaining a quantity rescaled to the most human-friendly prefix. It depends on `<cmath>` and
floating-point arithmetic. Separating it into its own chapter lets LEWG vote on this feature
independently of the quantity and unit definitions.

Straw poll: _We want `<si_prefix_utils>` — the `invoke_with_prefixed` auto-prefix selection
utility — to be included as part of the quantities and units library._


# Summary

## Definition Counts by Component

| Component                                     |          Header           |    Type     | Definitions |
|-----------------------------------------------|:-------------------------:|:-----------:|:-----------:|
| ISQ base dimensions                           |   `<isq_si_quantities>`   |  mandatory  |      7      |
| ISQ base quantities (incl. `time` alias)      |   `<isq_si_quantities>`   |  mandatory  |      8      |
| ISQ derived quantities for SI (incl. aliases) |   `<isq_si_quantities>`   |  mandatory  |     26      |
| **ISQ subtotal**                              | **`<isq_si_quantities>`** |             |   **41**    |
| SI prefixes (class + variable templates)      |        `<si_core>`        |  mandatory  |     48      |
| SI base units                                 |        `<si_core>`        |  mandatory  |      8      |
| SI named derived units and origins            |        `<si_core>`        |  mandatory  |     25      |
| **SI core subtotal**                          |      **`<si_core>`**      |             |   **81**    |
| **ISQ + SI core total**                       |                           |             |   **122**   |
| Non-SI units accepted for use with SI         |    `<si_non_si_units>`    |  optional   |     13      |
| Customization point specializations           |    `<si_non_si_units>`    |  optional   |      3      |
| SI-defining constants (si2019 + derived)      |     `<si_constants>`      |  optional   |     10      |
| Unit symbols (SI + non-SI)                    |    `<si_unit_symbols>`    |  optional   |    ~720+    |
| `std::chrono` interoperability                |       `<si_chrono>`       | hosted only |     ~6      |
| Trigonometric math functions                  |        `<si_math>`        | hosted only |      7      |
| Prefix auto-selection utility                 |    `<si_prefix_utils>`    | hosted only |      2      |
| **Optional subtotal**                         |                           |             |  **~761+**  |
| **Grand total**                               |                           |             |  **~883+**  |


# Acknowledgements

Special thanks and recognition goes to [The C++ Alliance](https://cppalliance.org) for supporting
Mateusz's membership in the ISO C++ Committee and the production of this proposal.

---
references:
- id: P3045R8_PRE
  citation-label: P3045R8
  author:
    - family: Pusz
      given: Mateusz
    - family: Berner
      given: Dominik
    - family: Guerrero Peña
      given: Johel Ernesto
    - family: Hogg
      given: Chip
    - family: Holthaus
      given: Nicolas
    - family: Michaels
      given: Roth
    - family: Reverdy
      given: Vincent
  title: "Quantities and units library"
  URL: <https://wg21.link/p3045r8>
- id: P4185R0_PRE
  citation-label: P4185R0
  author:
    - family: Pusz
      given: Mateusz
  title: "Completing the Mathematical Model for C++ Quantities and Units"
  URL: <https://wg21.link/p4185r0>
- id: SI
  citation-label: SI
  title: "SI Brochure: The International System of Units (SI)"
  URL: <https://www.bipm.org/en/publications/si-brochure>
---
