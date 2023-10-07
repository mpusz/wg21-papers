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

- identities (dimension_one, dimensionless, one)
- magnitude (ratio on steroids)
- quantity_spec vs units/dimension equations
- quantity_spec conversions and common_quantity_spec
- quantity constructors and conversions (value preserving approach)
- exceptions and special cases for dimensionless quantities
- quantity arithmetics + quirks of modulo arithmetic and integral division
- custom representation types (improve safety, provide additional info like measurement, linear algebra, minimal requirements)
- representation type constraints
- vector quantities and their operations
- affine space and operations
- Math CPOs


- some units should not simplify (hubble constant)

# Acknowledgements

Special thanks and recognition goes to [Epam Systems](http://www.epam.com) for supporting
Mateusz's membership in the ISO C++ Committee and the production of this proposal.

<!-- markdownlint-disable -->

---
references:
- id: MP-UNITS
  citation-label: mp-units
  title: "mp-units - A Physical Quantities and Units library for C++"
  URL: <https://mpusz.github.io/mp-units>
---
