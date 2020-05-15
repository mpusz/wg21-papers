---
title: "Enable variable template template parameters"
document: P2008R0
date: today
audience:
  - Evolution Working Group Incubator
author:
  - name: Mateusz Pusz ([Epam Systems](http://www.epam.com))
    email: <mateusz.pusz@gmail.com>
  - name: Colin MacLean
    email: <ColinMacLean@lbl.gov>
---


# Introduction

C++14 introduced the concept of variable templates, which have proved useful in many domains.
However, such templates are not first-class citizens, lacking the ability to be used as a
template parameter to a template. This document proposes adding this feature.

# Motivation and Scope

Variable templates are most commonly employed to create terse shortcuts to utility structs:

```cpp
template<typename T>
struct is_ratio : std::false_type {};

template<intmax_t Num, intmax_t Den>
struct is_ratio<std::ratio<Num, Den>> : std::true_type {};

template<typename T>
inline constexpr bool is_ratio_v = is_ratio::value;
```

The previous version of this paper proposed the ability to pass variable templates as template 
arguments to eliminate the need for the struct definition. While it is somewhat verbose to write
both a struct and variable template, the committee pointed out that the `std::integral_constant`
features are often useful and utilities such as `std::conjunction` and `std::disjunction` are 
defined for use with `std::integral_constant`. The committee did not see any reason to forbid
variable templates as template parameters, but did not see much use for them.

However, enabling variable templates as template parameters could enable more interesting use 
cases for variable templates. For instance, variable templates have the intriguing ability to
define overload sets.

```cpp
int foo(int) { return 0; }
int foo(const std::string&) { return 1; }

struct A {
    int bar(int) { return 2; }
    int bar(const std::string&) { return 3; }
};

template<typename R, typename... Args>
auto foo_os = static_cast<R(*)(Args...)>(&foo);

template<typename R, typename C, typename... Args>
auto bar_os = static_cast<R(C::*)(Args...)>(&C::bar);

template<typename R, typename... Args>
auto a_bar_os = static_cast<R(A::*)(Args...)>(&A::bar);
```

While these variable templates would still need additional C++ features for automatic template
deduction, overload resolution, and perhaps late name checking to enable SFINAE on undefined
functions, enabling variable templates as template parameters would be the first step.

Currently, a function pointer must point to a specific overload of a function. This includes 
when a function pointer is used in a constexpr context as a template parameter where overload
resolution could theoretically be deferred to the context of the function usage.

```cpp
template<auto func, typename... Args>
decltype(auto) invoke(Args&&... args)
    noexcept(noexcept(func(std::forward<Args>(args)...)))
{
    return func(std::forward<Args>(args)...);
}

invoke<&foo>(1); // Error: &foo is ambiguous
```

One can imagine with additional features relating to overload resolution with variable 
template function pointers, the following definition could be made possible:

```cpp 
template<template<typename...> auto func, typename... Args>
decltype(auto) invoke(Args&&... args)
    noexcept(noexcept(func(std::forward<Args>(args)...)))
{
    return func(std::forward<Args>(args)...);
}

invoke<foo_os>(1);
invoke<&foo>(1); // Extended: &foo treated as foo_os above
```

# Proposal

Extend C++ template syntax with a variable template parameter kind.


# Acknowledgements

Special thanks and recognition goes to [Epam Systems](http://www.epam.com)
for supporting Mateusz's membership in the ISO C++ Committee and the
production of this proposal.

Colin MacLean would also like to thank his employer, Lawrence Berkeley National Laboratory,
for supporting his ISO C++ Committee efforts.
