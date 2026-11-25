---
title: "Fixing `std::complex` binary operators"
document: P3788R1
date: today
audience:
  - SG6 Numerics
  - Library Evolution Working Group
author:
  - name: Mateusz Pusz
    email: <mateusz.pusz@gmail.com>
---

# Revision history

## Changes since [@P3788R0]

Based on Kona 2025 SG6 Numerics feedback:

- Replaced the `typename complex<T>::value_type` approach (which still caused silent narrowing)
  with heterogeneous overloads using `std::common_type_t<T, U>`, following C's usual arithmetic
  conversion rules. For example, `complex<float> * long double` now yields `complex<long double>`
  instead of silently converting the scalar to `float`.
- Scalar heterogeneous type support is now part of the main proposal (no longer optional).
- Heterogeneous complex–complex support is likewise part of the main proposal.

# Introduction

This paper proposes a backward-compatible solution to fix the inconsistent behavior of
`std::complex` binary operators with implicit conversions. The proposed changes:

1. Enable heterogeneous scalar operands in `std::complex` binary operations, with result types
   following C's usual arithmetic conversion rules.
2. Support mixed-type complex operations.
3. Maintain full backward compatibility with existing code.


# Motivation

Consider the following natural mathematical operations with complex numbers:

```cpp
long double ld = 2.5;
std::complex<float> c = 3.14;           // OK!!!
auto res1 = c * 3.14f;                  // OK
auto res2 = c * 3.14;                   // DOES NOT COMPILE!!!
auto res3 = c * ld;                     // DOES NOT COMPILE!!!
auto res4 = c * static_cast<float>(ld); // OK but verbose
if (c == 3.14f) {                       // OK
  // ...
}
if (c == 3.14) {                        // DOES NOT COMPILE!!!
  // ...
}
```

The above behavior is surprising and violates good design practices. It is a well-established design
rule that if a type `T` is convertible to type `U`, then a binary operator on types `T` and `U`
should also work correctly. This issue affects user experience and forces developers to explicitly
cast literals and variables of compatible types, making mathematical code less readable and more
error-prone.

Additionally, `std::complex` is problematic in generic contexts. Here is an excerpt from the
mp-units library:

```cpp
template<typename T>
using scaling_factor_type_t = conditional<treat_as_floating_point<T>, long double, std::intmax_t>;

template<typename T>
concept ScalableByFactor = requires(const T v, const scaling_factor_type_t<T> f) {
  { v* f } -> std::common_with<T>;
  { f* v } -> std::common_with<T>;
  { v / f } -> std::common_with<T>;
};

template<typename T>
concept RealScalarRepresentation = (!Quantity<T>) && RealScalar<T> && ScalableByFactor<T>;

template<typename T>
concept ComplexScalarRepresentation =
  (!Quantity<T>) && ComplexScalar<T> && requires(const T v, const scaling_factor_type_t<T> f) {
    // TODO The below conversion to `T` is an exception compared to other representation types;
    // `std::complex<T>` * `U` does not compile, but `std::complex<T>` is constructible from `U`
    { v* T(f) } -> std::common_with<T>;
    { T(f) * v } -> std::common_with<T>;
    { v / T(f) } -> std::common_with<T>;
  };

template<typename T>
concept ScalarRepresentation = RealScalarRepresentation<T> || ComplexScalarRepresentation<T>;

template<typename T>
concept VectorRepresentation = NotQuantity<T> && Vector<T> && ScalableByFactor<T>;
```

After this proposal, `v * f` works directly and `ComplexScalarRepresentation` can be unified
with `RealScalarRepresentation` via `ScalableByFactor`. As shown above, the general-purpose
physical quantities and units library currently has to special-case `std::complex` to handle
scaling of a quantity value between different units. This should not be required for C++
Standard Library types.


# Problem statement

`std::complex` is implicitly constructible from its representation type `T`. The non-explicit
constructor takes type `T` as a regular function parameter type (not a dependent name).
This means that all standard and user-defined conversions apply to this function parameter
in such a constructor call.

However, all binary operators are defined as non-member non-friend overloads where `T` is
a deduced template parameter type. For example:

```cpp
template<class T> constexpr complex<T> operator*(const complex<T>&, const complex<T>&);
template<class T> constexpr complex<T> operator*(const complex<T>&, const T&);
template<class T> constexpr complex<T> operator*(const T&, const complex<T>&);
```

According to template argument deduction rules, most conversions are not allowed for
standalone function template parameters of type `T`. This means that there is no overload
that can accept `std::complex<float>` and a `double` as its arguments.

Additionally, we cannot perform operations on complex numbers of different types
(e.g., `complex<double>` and `complex<float>`).


# Hidden friends are not a solution here

Making those operators hidden friends would immediately solve all the issues described above.
However, this would be an API break for any code that relies on them being declared at namespace
scope, e.g., code that calls `std::operator*<float>(c, 3.14)`, or similar constructs.


# Fixing heterogeneous scalar and complex operations

The approach considered in [@P3788R0] — replacing the scalar parameter type `T` with
`typename std::complex<T>::value_type` — enables implicit conversions but still forces a
narrowing conversion when the scalar has a wider type. For example:

```cpp
std::complex<float> c{1.f, 2.f};
auto r = c * 3.14;  // 3.14 is double; value_type approach converts it to float → precision loss
```

This violates C's usual arithmetic conversion rules, where `float * double` yields `double`.
The SG6 Numerics group at Kona 2025 identified this as unacceptable, noting that C specifies
the result as `complex<longest_type>` when mixing precision levels.

## Heterogeneous scalar overloads

We propose adding new overloads with a second deduced template parameter `U` and returning
`complex<common_type_t<T, U>>`:

```cpp
template<class T, class U>
  requires (!@$is-complex$@<U>) && requires { typename common_type_t<T, U>; }
constexpr complex<common_type_t<T, U>>
operator*(const complex<T>& lhs, const U& rhs);

template<class T, class U>
  requires (!@$is-complex$@<U>) && requires { typename common_type_t<T, U>; }
constexpr complex<common_type_t<T, U>>
operator*(const U& lhs, const complex<T>& rhs);
```

The `$is-complex$` constraint prevents ambiguity with the complex–complex overloads below.
When `T == U` these overloads have the same return type as the existing `complex<T>` overloads,
so they are fully backward compatible. When `T != U`, the result follows the standard arithmetic
conversion rules:

| Expression | Result type |
|---|---|
| `complex<float> * double` | `complex<double>` |
| `complex<float> * long double` | `complex<long double>` |
| `complex<double> * float` | `complex<double>` |
| `complex<double> * long double` | `complex<long double>` |

Note: `std::complex` is specified only for floating-point value types. The behavior of these
overloads for non-floating-point `U` (e.g., integer types) is unspecified.

## Heterogeneous complex–complex overloads

The same principle applies to operations between complex numbers of different value types:

```cpp
template<class T, class U>
  requires requires { typename common_type_t<T, U>; }
constexpr complex<common_type_t<T, U>>
operator*(const complex<T>& lhs, const complex<U>& rhs);
```

When `T == U` the existing single-parameter overload is more specialized (it constrains both
arguments to the same `T`), so it is preferred by partial ordering and there is no ambiguity.


# Impact on existing code

The proposed solution is fully backward compatible:

- All existing code continues to compile and behave identically
- No performance impact on existing operations
- No changes to existing overload resolution for cases that currently compile
- The change only adds new viable overloads for previously ill-formed expressions


# Implementation considerations

Several standard library implementations have been consulted, and preliminary implementation
shows that the proposed changes can be implemented without affecting existing optimizations
or code generation.


# Wording

The proposed changes are relative to [@N5008].

## [complex.syn]{.sref}

Add the following declarations to [complex.syn]{.sref} after the existing homogeneous overloads
for each operator. The existing overloads are **unchanged**.

Let `$is-complex$<T>` be `true` if `T` is a specialization of `complex`, and `false` otherwise
(exposition only).

::: add
```cpp
template<class T, class U>
  requires (!@$is-complex$@<U>) && requires { typename common_type_t<T, U>; }
constexpr complex<common_type_t<T, U>> operator+(const complex<T>& lhs, const U& rhs);
template<class T, class U>
  requires (!@$is-complex$@<U>) && requires { typename common_type_t<T, U>; }
constexpr complex<common_type_t<T, U>> operator+(const U& lhs, const complex<T>& rhs);
template<class T, class U>
  requires requires { typename common_type_t<T, U>; }
constexpr complex<common_type_t<T, U>> operator+(const complex<T>& lhs, const complex<U>& rhs);

template<class T, class U>
  requires (!@$is-complex$@<U>) && requires { typename common_type_t<T, U>; }
constexpr complex<common_type_t<T, U>> operator-(const complex<T>& lhs, const U& rhs);
template<class T, class U>
  requires (!@$is-complex$@<U>) && requires { typename common_type_t<T, U>; }
constexpr complex<common_type_t<T, U>> operator-(const U& lhs, const complex<T>& rhs);
template<class T, class U>
  requires requires { typename common_type_t<T, U>; }
constexpr complex<common_type_t<T, U>> operator-(const complex<T>& lhs, const complex<U>& rhs);

template<class T, class U>
  requires (!@$is-complex$@<U>) && requires { typename common_type_t<T, U>; }
constexpr complex<common_type_t<T, U>> operator*(const complex<T>& lhs, const U& rhs);
template<class T, class U>
  requires (!@$is-complex$@<U>) && requires { typename common_type_t<T, U>; }
constexpr complex<common_type_t<T, U>> operator*(const U& lhs, const complex<T>& rhs);
template<class T, class U>
  requires requires { typename common_type_t<T, U>; }
constexpr complex<common_type_t<T, U>> operator*(const complex<T>& lhs, const complex<U>& rhs);

template<class T, class U>
  requires (!@$is-complex$@<U>) && requires { typename common_type_t<T, U>; }
constexpr complex<common_type_t<T, U>> operator/(const complex<T>& lhs, const U& rhs);
template<class T, class U>
  requires (!@$is-complex$@<U>) && requires { typename common_type_t<T, U>; }
constexpr complex<common_type_t<T, U>> operator/(const U& lhs, const complex<T>& rhs);
template<class T, class U>
  requires requires { typename common_type_t<T, U>; }
constexpr complex<common_type_t<T, U>> operator/(const complex<T>& lhs, const complex<U>& rhs);

template<class T, class U>
  requires (!@$is-complex$@<U>) && requires { typename common_type_t<T, U>; }
constexpr bool operator==(const complex<T>& lhs, const U& rhs);
template<class T, class U>
  requires requires { typename common_type_t<T, U>; }
constexpr bool operator==(const complex<T>& lhs, const complex<U>& rhs);
```
:::

## [complex.ops]{.sref}

Add corresponding specifications in [complex.ops]{.sref} for each new overload. Each new
heterogeneous scalar overload converts both operands to `complex<common_type_t<T, U>>` and
delegates to the corresponding homogeneous operation. Each new heterogeneous complex overload
does the same for both complex arguments.

## Feature test macro

Add the following feature test macro to [version.syn]{.sref}:

```diff
+#define __cpp_lib_complex_mixed_arithmetic ??????L // also in <complex>
```


# Acknowledgements

Special thanks and recognition goes to [The C++ Alliance](https://cppalliance.org) for supporting
Mateusz's membership in the ISO C++ Committee and the production of this proposal.
