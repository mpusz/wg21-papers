---
title: "`std::from_chars` should work with `std::string_view`"
document: D2007R0
date: today
audience:
  - Library Evolution Working Group Incubator
  - Library Evolution Working Group
author:
  - name: Mateusz Pusz ([Epam Systems](http://www.epam.com))
    email: <mateusz.pusz@gmail.com>
---


# Introduction

`std::from_chars` accepts only a pair of raw `char` pointers in its overloads to provide
a range of characters for conversion. The author proposes to add overloads taking
`std::string_view` which is the main C++ vocabulary type to denote a range of characters.


# Motivation and Scope

## A naive approach

Unfortunately, it is common for an average C++ developer to provide the following implementation
for converting a `std::string_view` to `int` via a `std::from_chars`.

```cpp
void foo(std::string_view txt)
{
  int result;
  auto [ptr, ec] = std::from_chars(txt.begin(), txt.end(), result);
  if (ec == std::errc())
    // ...
}
```

The above will work for some implementations and build modes but will fail for others.
This is caused by the fact that even though some vendors implement
`std::string_view::const_iterator` in terms of `const char*`, such code is not portable.
The C++ standard specifies `std::string_view::const_iterator` as _implementation defined_
and only requires that the iterator's `value_type` is `char`.

## A hacker's approach

After realizing the portability issue programmers often fix it in the following way which
is far from what we want to teach:

```cpp
void foo(std::string_view txt)
{
  int result;
  auto [ptr, ec] = std::from_chars(&*txt.begin(), &*txt.end(), result);
  if (ec == std::errc())
    // ...
}
```

## A correct approach

A correct approach works on the underlying data rather than on iterators which is counter
intuitive as for C++ we always taught to use iterators to denote ranges:

```cpp
void foo(std::string_view txt)
{
  int result;
  auto [ptr, ec] = std::from_chars(txt.data(), txt.data() + txt.size(), result);
  if (ec == std::errc())
    // ...
}
```


# Before/After Comparison

::: tonytable

## Before

```cpp
void foo(std::string_view txt)
{
  int result;
  auto [ptr, ec] = std::from_chars(txt.data(), txt.data() + txt.size(), result);
  if (ec == std::errc())
    // ...
}
```

## After

```cpp
void foo(std::string_view txt)
{
  int result;
  auto [ptr, ec] = std::from_chars(txt, result);
  if (ec == std::errc())
    // ...
}
```

:::


# Proposed Wording

The proposed changes are relative to the working draft of the standard as of [@N4830].

Add the following to the end of synopsis in **20.19.1 [charconv.syn]**:

```cpp
from_chars_result from_chars(string_view txt, @_see below_@& value, int base = 10);
from_chars_result from_chars(string_view txt, float& value, chars_format fmt = chars_format::general);
from_chars_result from_chars(string_view txt, double& value, chars_format fmt = chars_format::general);
from_chars_result from_chars(string_view txt, long double& value, chars_format fmt = chars_format::general);
```

Update the following paragraphs in **20.19.3 [charconv.from.chars]**:

[1]{.pnum} All functions named `from_chars` analyze the [provided]{.add} string
[`[first, last)`]{.rm} for a pattern, where [string is either a `txt` or `[first, last)`
denoting]{.add}[`[first, last)` is required to be]{.rm} a valid range.

```diff
  from_chars_result from_chars(const char* first, const char* last,
                               @_see below_@& value, int base = 10);
+ from_chars_result from_chars(string_view txt,
+                              @_see below_@& value, int base = 10);
```

```diff
  from_chars_result from_chars(const char* first, const char* last, float& value,
                               chars_format fmt = chars_format::general);
+ from_chars_result from_chars(string_view txt, float& value,
+                              chars_format fmt = chars_format::general);
  from_chars_result from_chars(const char* first, const char* last, double& value,
                               chars_format fmt = chars_format::general);
+ from_chars_result from_chars(string_view txt, double& value,
+                              chars_format fmt = chars_format::general);
  from_chars_result from_chars(const char* first, const char* last, long double& value,
                               chars_format fmt = chars_format::general);
+ from_chars_result from_chars(string_view txt, long double& value,
+                              chars_format fmt = chars_format::general);
```

# Acknowledgements

Special thanks and recognition goes to [Epam Systems](http://www.epam.com) for supporting my
membership in the ISO C++ Committee and the production of this proposal.

