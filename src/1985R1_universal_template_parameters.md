---
title: Universal Template Parameters
document: D1985R1
date: today
audience:
  - Evolution Working Group Incubator
author:
  - name: Mateusz Pusz ([Epam Systems](http://www.epam.com))
    email: <mateusz.pusz@gmail.com>
  - name: Gašper Ažman
    email: <gasper.azman@gmail.com>
---

# Introduction

We propose a universal template parameter. This would allow for a generic
`apply` and other higher-order template metafunctions, as well as certain
type traits.

# Change Log

## R0 -> R1

- Greatly expanded the number of examples based on feedback from the BSI panel.
- Clarified that we are proposing eager checking

# Motivation

Imagine trying to write a metafunction for apply. While `apply` is very
simple, a metafunction like `bind` or `curry` runs into the same problems;
for demonstration, `apply` is clearest.

It works for pure types in C++20:

```cpp
template <template <class...> class F, typename... Args>
using apply = F<Args...>;

template <typename X>
class G { using type = X; };

static_assert(std::is_same<apply<G, int>, G<int>>{}); // OK
```

As soon as `G` tries to take any kind of NTTP (non-type template parameter)
or a template-template parameter, `apply` becomes impossible to write; we
need to provide analogous parameter kinds for every possible combination of
parameters:

```cpp
template <template <class> class F>
using H = F<int>;
apply<H, G> // error, can't pass H as arg1 of apply, and G as arg2
```

# Proposed Solution

Introduce a way to specify a truly universal template parameter that can bind
to anything usable as a template argument.

Let's spell it `template auto`. The syntax is the best we could come up with;
but there are plenty of unexplored ways of spelling such a template
parameter.

As an example, let's implement `apply` from above:

```cpp
template <template <template auto...> class F, template auto... Args>
using apply = F<Args...>;

apply<G, int>; // OK, G<int>
apply<H, G>;   // OK, G<int>
```

## Mechanism

### Specializing class templates on parameter kind

The new universal template parameter introduces similar generalizations as
the `auto` universal NTTP did; in order to make it possible to pattern-match
on the parameter, class templates need to be able to be specialized on the
kind of parameter as well:

```cpp
template <template auto>
struct X;

template <typename T>
struct X<T> {
  // T is a type
  using type = T;
};

template <auto val>
struct X<val> : std::integral_constant<decltype(val), val> {
  // val is an NTTP
};

template <template <class> F>
struct X<F> {
  // F is a unary metafunction
  template <typename T>
  using func = F<T>;
};
```

This alone allows building enough traits to connect the new feature to the
rest of the language with library facilities, and rounds out template
parameters as just another form of a compile-time parameter.

### Eager or late checking?

There exists a choice in whether we check the usage of a universal template
parameter eagerly or late. Consider:

```cpp
template <template auto Arg>
struct Y {
  using type = Arg; // can only alias a type
  // Q: late (on Y<1>) or early (on parse) error?
};
```

We could either:

- Eagerly check this and hard-error on parsing the template.
- Late-check and hard-error only if `Y` is *instantiated* with anything but a
  type.

This paper **proposes eager checking**, thus allowing the utterance of a
universal template parameter only in:

- *template-parameter-list* as the declaration of such a parameter
- *template-argument-list* as the usage of such a parameter. It must bind
  exactly to a declared `template auto` template parameter.

This avoids any parsing issues by being conservative. We can always extend
the grammar to allow usage in more contexts later.

Examples that inform the following reasoning:

```cpp
template <template auto Arg>
void f() {
  using type = Arg<int>; // error, not valid for types and values
  using value = Arg.foo(); // error, not valid for types and class templates
  auto x = Arg::member; // error, not valid for class templates and values
};
```

We avoid ambiguity by allowing the use of the universal template parameter
solely in ways that are valid for any kind of thing (value, type, or class
template) it may represent. It just so happens that the only such use is
passing it as an argument to a template and wait for something else to
pattern-match it out.

### Template-template parameter binding

We have to consider the two phases of class template (and template alias)
usage: parsing, and substitution.

Let's take `apply` again:

```cpp
template <template <template auto...> class F, template auto... Args>
using apply = F<Args...>;
```

This *parses*, because `F` is *declared* as a class template parameter taking
a pack of `template auto`, while `Args` is being expanded into a place that
takes `template auto` parameters.

When we pass a metafunction such a `is_same` as `F`:

```cpp
using result = apply<std::is_same, int, 1>; // error
```

everything is known, so the compiler is free to check dependent expansions at
instantiation time.


## Clarifying examples

### Single parameter examples

```cpp
template <int>                      struct takes_int {};
template <typename T>               using  takes_type = T;
template <template auto>            struct takes_anything {}
template <template <class> class F> struct takes_metafunc {};

template <template <template auto> class F, template auto Arg>
struct fwd {
  using type = F<Arg>; // ok, passed to template auto parameter
}; // ok, correct definition

void f() {
  fwd<takes_int, 1>{};    // ok; type = takes_int<1>
  fwd<takes_int, int>{};  // error, takes_int<int> invalid
  fwd<takes_type, int>{}; // ok; type = takes_type<int>
  fwd<takes_anything, int>{}; // ok; type = takes_anything<int>
  fwd<takes_anything, 1>{};   // ok; type = takes_anything<1>
  fwd<takes_metafunc, takes_int>; // ok; type = takes_metafunc<takes_int>
  fwd<takes_metafunc, takes_metafunc>{}; // error (1)
}
```

(1): `takes_metafunc` is not a metafunction on a *type*, so
     `takes_metafunc<takes_metafunc>` is invalid (true as of *C++98*).

### Pack Expansion Example

It is interesting to think about what happens if one expands a
non-homogeneous pack of these. The result should not be surprising:

```cpp
template <template auto X, template auto Y>
struct is_same : std::false_type {};
template <typename auto V>
struct is_same<V, V> : std::true_type {};

template <template auto V, template auto ... Args>
struct count : std::integral_constant<
    size_t,
    (is_same<Args>::value + ...)> {};

constexpr size_t ints = count<int, 1, 2, int, is_same>::value; // ok, ints = 2
```

### Example of parsing ambiguity (if late check, not proposed)

The reason for eager checking is that not doing that could introduce parsing
ambiguities. Example courtesy of [@P0945R0], and adapted:

```cpp
template<template auto A>
struct X {
  void f() { A * a; }
};
```

The issue is that we do not know how to parse `f()`, since `A * a;` is either
a declaration or a multiplication.

Original example from [@P0945]:

```cpp
template<typename T> struct X {
  using A = T::something; // P0945R0 proposed universal alias
  void f() { A * a; }
};
```

# Example Applications

This feature is very much needed in very many places. This section lists
examples of usage.

## Enabling higher order metafunctions

This was the introductory example. Please refer to the [Proposed Solution].

Further example: `curry`:

```cpp
template <typename <template auto...> class F,
          template auto ... Args1>
struct curry {
  template <template auto... Args2>
  using func = F<Args1..., Args2...>;
};
```

## Making dependent `static_assert(false)` work

Dependent static assert idea is described in [@P1936R0] and [@P1830R1]. In the
former the author writes:

> Another parallel paper [@P1830R1] that tries to solve this problem on the library level is
> submitted. Unfortunately, **it cannot fulfill all use-case since it is hard to impossible to
> support all combinations of template template parameters in the dependent scope**.

The above papers are rendered superfluous with the introduction of this feature. Observe:

```cpp
// stdlib
template<bool value, template auto Args...>
inline constexpr bool dependent_bool = value;
template<template auto... Args>
inline constexpr bool dependent_false = dependent_bool<false, Args...>;

// user code
template<template <class> class Arg>
struct my_struct {
  // no type template parameter available to make a dependent context
  static_assert(dependent_false<Arg>, "forbidden instantiation.");
};
```

## Checking whether a type is an instantiation of a given template

When writing template libraries, it is useful to check whether a given type
is an instantiation of a given template. When our templates mix types and
NTTPs, this trait is currently impossible to write in general. However, with
the universal template parameter, we can write a concept for that easily as
follows.

```cpp
// is_instantiation_of
template<typename T, template<template auto...> class Type>
inline constexpr bool is_instantiation_impl = false;

template<template auto... Params, template<template auto...> class Type>
inline constexpr bool is_instantiation_impl<Type<Params...>, Type> = true;

template<typename T, template<template auto...> class Type>
concept is_instantiation_of = is_instantiation_impl<T, Type>;
```

With the above we are able to easily constrain various utilities taking class templates:

```cpp
template <auto N, auto D>
struct ratio {
  static constexpr decltype(N) n = N;
  static constexpr decltype(D) d = D;
};

template<is_instantiation_of<ratio> R1, is_instantiation_of<ratio> R2>
using ratio_mul = simplify<ratio<
    R1::n * R2::n,
    R1::d * R2::d
  >>;
```

or create named concepts for them:

```cpp
template<typename T>
concept is_ratio = is_instantiation_of<ratio>;

template<is_ratio R1, is_ratio R2>
using ratio_mul = simplify<ratio<
    R1::n * R2::n,
    R1::d * R2::d
  >>;
```

This concept can then be easily used everywhere:

```cpp
template <is_instantiation_of<std::vector> V>
void f(V& v) {
  // valid for any vector
}
```

## Universal alias as a library

While this paper does not try to relitigate Richard Smith's [@P0945R0], it
does provide a solution to aliasing anything as a library facility, without
running into the problem that [@P0945R0] ran into.

Observe:

```cpp
template <template auto Arg>
struct alias /* undefined on purpose */;

template <typename T>
struct alias<T> { using value = T; }

template <auto V>
struct alias<T> : std::integral_constant<decltype(V), V> {};

template <template <template auto...> class Arg>
using alias<Arg> {
  template <template auto...> using value = Arg;
};
```

We can then use alias when we *know* what it holds:

```cpp
template <template auto Arg>
struct Z {
  using type = alias<Arg>;
  // existing rules work
  using value = typename type::value; // dependent
}; // ok, parses

Z<int> z1; // ok, decltype(z1)::value = int
Z<1> z; // error, alias<1>::value is not a type
```

## Integration with reflection

The authors expect that code using reflection will have a need for this
facility. We should not reach for code-generation when templates will do, and
so being able to pattern-match on the result of the reflection expression
might be a very simple way of going from the consteval + injection world back
to template matching.

The examples in this section are pending discussion with reflection authors.

Importantly, the authors do not see how one could write `is_instantiation_of`
with the current reflection facilities, because one would have no way to
pattern-match. This is, however, also pending discussion with the authors of
reflection.

## Library fundamentals II TS detection idiom

TODO. Concievably simplifies the implementation and makes it far more
general.

# Other Considered Syntaxes

In addition to the syntax presented in the paper, we have considered the
following syntax options:

## `.` and `...` instead of `template auto` and `template auto ...`

```cpp
template<template<...> class F, . x, . y, . z>
using apply3 = F<x, y, z>;
```

The reason we discarded this one is that it is very terse for something that
should not be commonly used, and as such uses up valuable real-estate.

# Acknowledgements

Special thanks and recognition goes to [Epam Systems](http://www.epam.com)
for supporting Mateusz's membership in the ISO C++ Committee and the
production of this proposal.

Gašper would likewise like to thank his employer, Citadel Securities Europe,
LLC, for supporting his attendance in committee meetings.

A big thanks also to the members of the BSI C++ panel for their review and
commentary.