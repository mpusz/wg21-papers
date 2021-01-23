---
title: "Enable variable template template parameters"
document: P2008R0
date: today
audience:
  - Evolution Working Group Incubator
author:
  - name: Mateusz Pusz ([Epam Systems](http://www.epam.com))
    email: <mateusz.pusz@gmail.com>
---


# Introduction

In C++ we can easily form a template that will take a class template as its parameter. With
C++14 we got variable templates. They proved to be useful in many domains but still are not
first-class citizens in C++. For example, they cannot be passed as a template parameter to
a template. This document proposes adding such a feature.


# Motivation and Scope

To check if the current type is an instantiation of a class template we can write the following
type trait:

```cpp
template<typename T>
struct is_ratio : std::false_type {};

template<intmax_t Num, intmax_t Den>
struct is_ratio<std::ratio<Num, Den>> : std::true_type {};
```

A family of such type traits can be passed to a concept:

```cpp
template<typename T, template<typename> typename Trait>
concept satisfies = Trait<T>::value;
```

and then be used to constrain a template:

```cpp
template<satisfies<is_ratio> R1, satisfies<is_ratio> R2>
using ratio_add = /* ... */;
```

After C++14 we learnt that variable templates are less to type (no need for a `_v` helper)
and are often faster to compile. The above `is_ratio` type trait can be rewritten as:

```cpp
template<typename T>
inline constexpr bool is_ratio = false;

template<intmax_t Num, intmax_t Den>
inline constexpr bool is_ratio<ratio<Num, Den>> = true;
```

However, contrary to a class template, the above variable template cannot be passed to
a template at all. The syntax:

```cpp
template<typename T, template<typename> bool Trait>
concept satisfies = Trait<T>;
```

is not a valid C++ as of today.


## Variable template function pointer

Variable template function pointers could be used as a way to SFINAE undefined functions,
such as those which provide OS specific functionality. A variable template function pointer
also allows for passing the name of an overloaded function without specifying the exact overload.
Optionally defined function calls could be defined wrapped as variable template function pointers.

```cpp
namespace wrappedlib {

template<typename R, typename... Args>
inline constexpr R(*possibly_undefined_function)(Args...) = &::possibly_undefined_function;

template<typename... Ts>
struct possibly_undefined_template_function {
  template<typename R, typename... Args>
  inline constexpr R(*func)(Args...) = &::possibly_undefined_template_function<Ts...>;
  
  template<typename... Args>
  static constexpr decltype(auto) operator(Args&& ... args)
  {
    return func<Args...>(std::forward<Args>(args)...);
  }
};

}

namespace detail {

template<template<typename...> auto func, typename R, typename Args, typename=void>
struct is_function_defined_helper : std::false_type {};

template<template<typename...> auto func, typename R, typename... Args>
struct is_function_defined_helper<func,R,std::tuple<Args...>, std::void_t<decltype(func<R,Args...>(std::declval<Args>()...))>> : std::true_type {};

}

template<template<typename...> auto func, typename R, typename... Args>
using is_function_defined = detail::is_function_defined_helper<func,R,std::tuple<Args...>>;

template<template<typename...> auto func, typename R, typename... Args>
inline constexpr bool is_function_defined_v = is_function_defined::value;

namespace std {

template<template<typename...> auto func, typename... Args>
constexpr std::invoke_result_t<func,Args...> invoke(Args&&... args);

}

void foo() {
    if constexpr (is_function_defined_v<possibly_undefined_function>)
    {
        auto v1 = wrappedlib::possibly_undefined_function<int,double>(1,2.0);
        // Suggest adding template type deduction for templated function pointers
        // using the same rules as function overload resolution and automatic type
        // conversion. Fails if automatic resolution if ambiguous overloads.
        // Currently, the types must match exactly, which makes use clunky.
        // Test if first, second template argument is used as return type or class type
        // similar to INVOKE
        //auto v2 = wrappedlib::possibly_undefined_function<>(1,2.0f);
        auto v3 = std::invoke<wrappedlib::possibly_undefined_function>(1,2.0);
    }
}
```

Another use case is creating a tag dispatch system with multiple priority options. For example,
it can be desirable for different versions of a function to be called depending on available SIMD
instruction sets, networking layer (infiniband, ethernet, etc.), database types, etc. The 
desired priorities of choices may not always be the same in all circumstances, so a static inheritance
hierarchy of tag types would not work. Templated function pointers could be used as a means for testing
the existence of, then executing, the first available tagged function call from a parameter pack of
tag types.

```cpp
struct a_tag {};
struct b_tag {};
struct c_tag {};

void bar(a_tag) {};
void bar(c_tag) {};

template<template<typename...> auto f, template TagTuple, template Tag, template... Args>
decltype(auto) run_best(Tag, Args&&... args)
{
  return f<Tag,Args...>(Tag{},std::forward<Args>(args)...);
}

void foo()
{
  // Should allow declaration of variable templates at block scope.
  template<typename Tag>
  void(*barfunc)(Tag) = &bar(Tag);
  run_best<barfunc,std::tuple<b_tag,c_tag,a_tag>>(); // runs bar(c_tag{})
}
```

Similar question was raised by Zhihao Yuan in 2017 on a reflector (<https://lists.isocpp.org/ext/2017/02/1907.php>)

```cpp
template <template <typename...> typename F, typename... T>
constexpr bool all_satisfy = and_v<F<some_traits_t<T>>...>;

all_satisfy<is_trivially_destructible_v, T...>
```

```cpp
template<template<typename> auto F, typename T>
constexpr bool satisfy = F<T>;
```

In the reflector thread was also a statement that implementing this feature is wasy from technical point of view (at least for VC++)




Consider function templates.

```cpp
template<typename T>
int m;
int n;

template<typename T>
void f();
void g();

template<auto &>
struct A {};
template<template<typename> auto &>
struct B {};

A<m<int>>(); // ok
A<n>(); // ok
A<f<int>>(); // ok
A<g>(); // ok
B<m>(); // now ok
B<f>(); // ERROR
```

Since this

```cpp
template<typename T>
auto& r = f<T>;
```

works and `B<r>();` can probably work, it's reasonable to "just" let `B<f>` work.


> What is the problem being solved here?

To simplify building a compile-time hash table to provide a
C++ overload set as an API to foreign languages, maybe?

 this limitation (you have to
define a variable template to pass an overload set to
templates) looks unnecessary and adds to the complexity
of the language


# Proposal

Extend C++ template syntax with a variable template parameter kind.


# Acknowledgements

Special thanks and recognition goes to [Epam Systems](http://www.epam.com) for supporting my
membership in the ISO C++ Committee and the production of this proposal.


Discussion on reflector:

https://lists.isocpp.org/ext/2017/02/1907.php

