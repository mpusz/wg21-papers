---
title: "Composing formatters: redirecting a format context and narrowing a parse context"
document: P4413R0
date: today
audience:
  - Library Evolution Working Group
author:
  - name: Mateusz Pusz
    email: <mateusz.pusz@gmail.com>
toc-depth: 3
---

# Introduction

A `formatter` for a composite type usually stores the `formatter`s of its parts, parses their
specs in its own `parse()`, and calls their `format()` in its own `format()`. Two common needs
break this pattern, and the standard offers no way around either of them:

1. When the composite type supports a width, its output has to be produced into a temporary
   buffer before it can be padded. `basic_format_context` has no public constructor and cannot be
   pointed at a buffer, because its iterator type is unspecified ([Exposing the constructor and
   `args()`]). The pre-parsed `formatter`s of the parts therefore cannot write there. The only
   option is to re-enter `vformat_to` with a reconstructed format string, which type-erases the
   arguments, parses the spec again, and loses access to the arguments of the enclosing format
   string.
2. When the spec of a part is delimited by something other than `}` (for example `N[.2f]` in
   `{::N[.2f]}`), the `formatter` of that part needs a parse context that ends at the delimiter.
   `basic_format_parse_context` cannot be narrowed, and a newly constructed one restarts automatic
   argument numbering. A nested replacement field in such a spec then refers to the wrong argument.

This paper proposes two small additions:

- `basic_format_context::capture(str, f)`, which calls `f` with the same context temporarily
  writing to a buffer and appends what was written to `str`,
- `basic_format_parse_context::set_end(it)`, which moves the end of the parsed range while keeping
  the argument counter and the compile-time checks.

libstdc++ and libc++ both have a private mechanism for the first problem in their range and tuple
`formatter`s.
{fmt} exposes a public way to do it, by constructing a context from `ctx.args()` and
`ctx.locale()`. Users of `std::format` cannot do the same.


# Motivation

## A composite formatter

The quantities and units library [@P3045R10_PRE] formats a quantity as a numerical value and a
unit. Its format spec has two levels: the first one controls the quantity as a whole, and the
`N[...]`, `U[...]`, and `D[...]` parts of the second one are forwarded verbatim to the
`formatter`s of the numerical value, the unit, and the dimension:

```cpp
std::println("{}", 100. * km / (3 * h));                  // 33.333333333333336 km/h
std::println("{::N[.2f]}", 100. * km / (3 * h));          // 33.33 km/h
std::println("{:*^16:N[.1f]U[n]}", 100. * km / (3 * h));  // **33.3 km h⁻¹***
std::println("{:%N in %U}", 100. * km / (3 * h));         // 33.333333333333336 in km/h
```

The natural implementation keeps one `formatter` per part and lets each of them parse its own
spec, so that the quantity `formatter` never has to know the grammar of a user-defined
representation type:

```cpp
template<auto R, typename Rep, typename Char>
class formatter<quantity<R, Rep>, Char> {
  formatter<Rep, Char> rep_formatter_;
  formatter<decltype(get_unit(R)), Char> unit_formatter_;
  // fill, align, width, layout, ...
public:
  constexpr auto parse(basic_format_parse_context<Char>& ctx);
  template<typename FormatContext>
  auto format(const quantity<R, Rep>& q, FormatContext& ctx) const;
};
```

## Padding needs a buffer

Without a width, `format()` can call the pre-parsed `formatter`s with the context it was given:

```cpp
ctx.advance_to(rep_formatter_.format(q.numerical_value_ref_in(q.unit), ctx));
auto it = ctx.out();
*it++ = ' ';
ctx.advance_to(it);
return unit_formatter_.format(q.unit, ctx);
```

With a width, the length of that output has to be known before the padding is written. This is
why it has to go to a buffer first. The pre-parsed `formatter`s cannot write to a buffer, because
there is no context bound to one. This is what the mp-units library [@MP-UNITS] does today instead:

```cpp
std::string buffer;
std::vformat_to(std::back_inserter(buffer), ctx.locale(), "{:" + rep_spec_ + "}",
                std::make_format_args(q.numerical_value_ref_in(q.unit)));
buffer += ' ';
std::vformat_to(std::back_inserter(buffer), ctx.locale(), "{:" + unit_spec_ + "}", std::make_format_args(q.unit));
return write_padded(ctx.out(), buffer, width, align, fill);
```

This approach has several problems:

- the `formatter`s parsed in `parse()` are not used at all, and each spec is parsed a second time,
- every part is type-erased by `make_format_args` and dispatched through `visit_format_arg`,
  although its type is known statically,
- the reconstructed format string and the buffer are both `std::string`s, so a long spec or
  a long result allocates,
- the nested format string sees only the argument passed to `make_format_args`, so a nested
  replacement field like the precision in `{:>14:N[.{}f]}` cannot refer to the arguments of the
  enclosing format string.

## Parsing a delimited spec

Inside `N[...]`, the spec of the numerical value ends at `]`. A standard `formatter` stops at `}`
or at the end of its parse context and rejects anything else. This is why it cannot be called
with the enclosing context. The only portable alternative is a new parse context over the substring:

```cpp
auto close = find(begin, end, ']');
basic_format_parse_context<Char> sub(basic_string_view<Char>(begin, close));
rep_formatter_.parse(sub);
```

The new context starts its automatic argument numbering from zero and knows nothing about the
arguments of the enclosing format string. Consider this minimal `formatter`, which accepts
`N[<int-format-spec>]`:

```cpp
struct wrapped { int v; };

template<>
struct std::formatter<wrapped> {
  std::formatter<int> inner;

  constexpr auto parse(std::format_parse_context& ctx)
  {
    auto it = ctx.begin(), end = ctx.end();
    if (it == end || *it == '}') return it;
    if (*it != 'N' || ++it == end || *it != '[') throw std::format_error("expected N[");
    auto close = std::find(++it, end, ']');
    if (close == end) throw std::format_error("expected ]");
    std::format_parse_context sub(std::string_view(it, close));
    if (inner.parse(sub) != sub.end()) throw std::format_error("invalid spec");
    return close + 1;
  }

  auto format(wrapped w, std::format_context& ctx) const { return inner.format(w.v, ctx); }
};
```

At run time, with `std::vformat`, libstdc++ 16, libc++ 23 and {fmt} 12 all produce the same
results:

| format string    | arguments           | expected     | output        |
|------------------|---------------------|--------------|---------------|
| `"{:N[>{}]}"`    | `wrapped{42}, 6`    | `"    42"`   | throws        |
| `"{} {:N[>{}]}"` | `7, wrapped{42}, 6` | `"7     42"` | `"7      42"` |
| `"{1:N[>{0}]}"`  | `6, wrapped{42}`    | `"    42"`   | `"    42"`    |

In the second row, the nested `{}` should refer to argument 2 (`6`), but the new context hands
out argument 0 (`7`), and the value is silently padded to a width of 7. In mp-units the same
mistake turns `"{} {::N[.{}f]}"` with `7, 3.14159 * m, 2` into `7 3.1415900 m`.

With a compile-time checked format string, as in `std::println("{:N[>{}]}", wrapped{42}, 6)`, all
three implementations reject the call. The diagnostics do not point at the problem. libstdc++
reports an invalid argument id, and libc++ an argument index outside the valid range. {fmt} fails
because it casts the parse context to its derived `compile_parse_context` type during constant
evaluation, and the new context is not of that type. The argument type checks added by
[@P2757R3] cannot run against the actual arguments either.

## The standard library already does this

The `range_formatter` and the tuple `formatter` accept a width ([format.range.formatter]{.sref},
[format.tuple]{.sref}). Their elements are formatted by pre-parsed `formatter`s, and a width means
the elements have to be buffered, at least until the width is reached. Each implementation we
examined has a private mechanism for that:

- **libstdc++** formats through `basic_format_context<_Sink_iter<_CharT>, _CharT>` whose iterator
  can point at any sink, so `__format_padded` points the same context at a `_Padding_sink` with
  `advance_to()` and points it back afterwards.
- **libc++** adds a partial specialization of `basic_format_context` for its private
  `__retarget_buffer` iterator. It forwards `locale()` to the original context and converts each
  argument on request. Its comment records the limitation: arguments of user-defined types
  cannot be retargeted, and requesting one throws `format_error("Re-targeting handle not
  supported")`.
- **{fmt}** constructs a new context from `ctx.args()` and `ctx.locale()`, which its public API
  allows. That only works when the new context has the same type as the original one. Until
  October 2026, formatting a range, tuple, or map with `FMT_COMPILE` failed to compile for this
  reason, even without a width [@FMT_4949]. The fix [@FMT_4974] added a third template parameter
  to `generic_context` so that a context can hold arguments typed on another one.


# Design

## Redirecting the format context

The proposed member function calls a function object with the same context, temporarily writing
to a buffer, and then appends what was written to a string:

```cpp
template<class Out, class charT>
class basic_format_context {
public:
  // ...
  template<class F>
    constexpr void capture(basic_string<charT>& str, F&& f);
};
```

The motivating example becomes:

```cpp
template<typename FormatContext>
auto format(const quantity<R, Rep>& q, FormatContext& ctx) const
{
  int width = get_width(ctx);  // a dynamic width is resolved through ctx as usual
  if (width == 0) return write_components(q, ctx);

  basic_string<Char> buffer;
  ctx.capture(buffer, [&](FormatContext& c) { write_components(q, c); });
  return write_padded(ctx.out(), buffer, width, align, fill);
}
```

`write_components` calls `rep_formatter_.format()` and `unit_formatter_.format()` with the
context it is given. The same code serves both paths. Nested replacement fields in the specs
of the parts resolve against the arguments of the enclosing format string, because they are
looked up through the same context.

We propose redirecting the existing context, rather than creating a context of another type, for
the following reasons:

- `arg(n)` of a context returns a `basic_format_arg` of that context's own type, so a context of
  another type has to convert each argument on access, unless the type of the original context
  becomes a template parameter of the new one, as in {fmt} since [@FMT_4974]. An argument of a
  user-defined type cannot be converted, because its `handle` formats with the original context
  type. libc++ throws in that case, as described above.
- Every pre-parsed part `formatter` is instantiated a second time for the new context type, which
  adds code for each composite type and each part.
- Redirection reuses the context type the `formatter` already handles. libstdc++ redirects its
  contexts this way. In libc++ the iterator of `format_context` is
  `back_insert_iterator<__output_buffer<char>>`, which can append to another
  `__output_buffer<char>`.

`capture` has to be available on every `basic_format_context` specialization that an
implementation passes to a `formatter`. That includes the one used by the `formattable` concept
(libstdc++ uses a context whose iterator drops the output, libc++ uses `char*`) and the retarget
specialization of libc++. The contexts of the `formattable` check exist only to be type-checked
and are never used to format. For those, a call to `capture` only has to be well-formed.

The cost is that the buffer is chosen by the library and the result is copied into a
`basic_string`. This is discussed in [Open questions].

## Narrowing the parse context

The proposed member function sets the end of the range being parsed:

```cpp
template<class charT>
class basic_format_parse_context {
public:
  // ...
  constexpr void set_end(const_iterator it);
};
```

A composite `formatter` narrows the context to the delimited spec, calls the `formatter` of the
part, and restores the end:

```cpp
constexpr auto parse(basic_format_parse_context<Char>& ctx)
{
  auto it = ctx.begin(), end = ctx.end();
  // ...
  auto close = find_closing_bracket(it, end);
  if (close == end) throw format_error("expected ]");
  ctx.advance_to(it);
  ctx.set_end(close);
  if (rep_formatter_.parse(ctx) != close) throw format_error("invalid spec");
  ctx.set_end(end);
  return close + 1;
}
```

Because the context is the same object, its argument counter continues from the enclosing format
string, mixing automatic and manual indexing is diagnosed as usual, and the compile-time checks of
the number and types of the arguments still apply to the nested replacement fields.

The function is the mirror image of `advance_to()`, which already lets a `formatter` move the
beginning of the range. It adds no state to the class and does not change its layout.

A `formatter` that calls `set_end()` has to restore the end before its `parse()` returns, because
the code that called `parse()` may continue to use the context. The proposed wording adds that to
the formatter requirements.

## Alternatives considered

### Rebinding to another iterator type

A free function `rebind_format_context(ctx, out) -> basic_format_context<NewOut, charT>` could
return a context writing to an arbitrary output iterator. It can target any output iterator chosen
by the user, with no intermediate buffer. libc++ rebinds a context to another iterator type
internally, and {fmt} does since [@FMT_4974].

However, it converts arguments on access unless it carries the original context type, and it
instantiates every part `formatter` again, as described in [Redirecting the format context].
Formatting into a buffer is the only use case we have found, and redirection covers it.

### Exposing the constructor and `args()`

{fmt} lets users construct a context from an output iterator, `ctx.args()`, and `ctx.locale()`.
In the standard the iterator type of `format_context` is unspecified. This is why a user cannot
create a second iterator of that type bound to a buffer. A public constructor would only help
together with a specified iterator type, which is a much larger change.

### Passing the argument counter to a new parse context

A constructor taking the next automatic argument id (as {fmt} has) plus a way to read and write
back that counter would fix the numbering at run time. It would still lose the compile-time
argument checks. During constant evaluation the implementations keep the number of the arguments
(and, since [@P2757R3], their types) with the parse context object they pass to `parse()`, and a
new object does not have them.

### Changing the grammar of the composite type

A composite `formatter` can avoid the parse-side problem by putting the spec of one part last and
undelimited, as the `range_formatter` does with its `range-underlying-spec`. That works for
only one part, and a quantity has three (the numerical value, the unit, and the dimension).


# Implementation experience

## {fmt}

The format side is already available in {fmt}. A context can be constructed from an output
iterator, `ctx.args()`, and `ctx.locale()`, and the test suite checks that this keeps compiling
(`base_test.format_context_accessors`). Since [@FMT_4974], `generic_context<OutputIt, Char,
ArgContext>` also covers contexts whose iterator is not `appender`.

The parse side was implemented as `parse_context::set_end()` in a pull request to {fmt}
[@FMT_SET_END]. The change is ten lines in `fmt/core.h`. Its tests cover automatic and manual
indexing through a nested replacement field, the compile-time checked path, and the diagnostic
for mixing indexing modes. The full {fmt} test suite passes with GCC 16 (C++11 and C++20) and
Clang 23 (C++20).

[The pull request number is to be filled in once the pull request is opened.]{.ednote}

## libstdc++ and libc++

We prototyped `capture` for a top-level argument as a free function outside both libraries that
uses their internals (see the [Appendix: `capture` prototype]). Each version is under ten lines.
On GCC 16 with libstdc++ and on Clang 23 with libc++, with compile-time checked format strings, a
nested `{}` in a spec forwarded to a pre-parsed `formatter` resolves against the arguments of the
enclosing format string, because `capture` writes through the existing context.

## mp-units

We rewrote the quantity `formatter` of mp-units against {fmt} with `set_end()` and a context
constructed over a `fmt::basic_memory_buffer`, the {fmt} counterpart of `capture`. The `std::format`
build keeps `vformat_to` in the width path and a new parse context for `N[...]`, `U[...]`, and
`D[...]`, the two places that need the proposed facilities.

[The branch link is to be filled in once it is published.]{.ednote}

The rewrite removed every `vformat_to` and `make_format_args` call from the {fmt} build, and, in
both builds, the three `std::string` members that held reconstructed format strings. It also
fixed two problems in the {fmt} build:

- nested replacement fields in `N[...]`, `U[...]`, and `D[...]` now refer to the right argument,
  including together with a quantity-level width (`"{:>{}:N[.{}f]}"`),
- `FMT_COMPILE` can format a quantity at all. Before the change, the `std::string` members made
  the parsed `formatter` unusable as a constant.

Runtime, in nanoseconds per call, of formatting `123.456 * (km / h)` into a reused `std::string`
with `format_to`. Built with `-O2 -DNDEBUG -falign-functions=64 -falign-loops=64`, with each
process pinned to one core with `taskset`. Each cell is the best of 6 processes × 9 repetitions of
500,000 calls, with master and branch processes
interleaved. GCC 16 was used for {fmt} master and libstdc++ 16, and Clang 23 for libc++ 23. The
two `double` rows format no quantity and show the noise between the binaries, which reached 11%
in these measurements:

| format spec        | {fmt} master → branch | libstdc++ master → branch | libc++ master → branch |
|--------------------|----------------------:|--------------------------:|-----------------------:|
| `double {}`        |    25.9 → 28.8 (+11%) |         35.8 → 35.0 (-2%) |      46.2 → 46.2 (+0%) |
| `double {:>12.2f}` |     33.7 → 33.8 (+0%) |         73.6 → 69.4 (-6%) |      56.1 → 59.7 (+6%) |
| `{}`               |     47.9 → 47.8 (-0%) |         72.7 → 72.5 (-0%) |      89.3 → 90.8 (+2%) |
| `{::N[.2f]}`       |    71.2 → 51.8 (-27%) |        98.8 → 85.0 (-14%) |     89.3 → 77.9 (-13%) |
| `{:%N %U}`         |    74.7 → 55.3 (-26%) |       129.4 → 75.6 (-42%) |   157.2 → 100.8 (-36%) |
| `{:%N%?%U (%D)}`   |   114.7 → 86.3 (-25%) |      166.3 → 101.3 (-39%) |   203.7 → 114.1 (-44%) |
| `{:>16}`           |   105.6 → 73.9 (-30%) |       168.7 → 163.1 (-3%) |    193.6 → 182.3 (-6%) |
| `{:>16:N[.2f]}`    |   134.0 → 79.4 (-41%) |       193.6 → 182.9 (-6%) |    191.5 → 179.1 (-6%) |
| `{:*^24%N in %U}`  |  141.4 → 105.3 (-26%) |       182.5 → 176.8 (-3%) |    219.6 → 200.5 (-9%) |

The default `{}` row did not move. The rows with a sub-spec or a layout and no width improved in
all three columns, by 13% to 44%. The `std::format` builds use neither proposed facility for these
rows, so their gain comes from the rewrite itself, in which `parse()` no longer builds strings and
the parts are formatted by the pre-parsed `formatter`s on `ctx`. Only the rows with a width in the
{fmt} build use the counterpart of `capture`, and they improved by 26% to 41%. In the
`std::format` builds the same rows moved only by -9% to -3%, because they still go through
`vformat_to`.

The {fmt} build also compiles to less code. The table compares one translation unit that prints
four quantities with `fmt::println("{}", ...)` (basic) and one that uses the whole grammar,
including `N[...]`, `U[...]`, layouts, and widths (advanced). Both are compiled with `-O2 -c`,
the instantiation count is the number of `InstantiateClass` and `InstantiateFunction` events in
`-ftime-trace`:

| compiler | TU       |      instantiations |            `.text` bytes |             object bytes |  defined symbols |
|----------|----------|--------------------:|-------------------------:|-------------------------:|-----------------:|
| Clang 23 | basic    | 10547 → 10117 (-4%) |   97,147 → 81,702 (-16%) | 278,008 → 228,184 (-18%) | 342 → 286 (-16%) |
| Clang 23 | advanced | 10979 → 10467 (-5%) |  110,492 → 91,188 (-17%) | 320,472 → 258,688 (-19%) | 396 → 326 (-18%) |
| GCC 16   | basic    |                 n/a |  111,006 → 98,099 (-12%) | 261,880 → 216,536 (-17%) | 208 → 168 (-19%) |
| GCC 16   | advanced |                 n/a | 126,502 → 110,339 (-13%) | 300,208 → 245,944 (-18%) | 239 → 190 (-21%) |

Wall-clock compile time moved between -11% and +4%, which is within the noise of the machine
used.


# Impact on the standard

Both additions are pure extensions, apart from one new formatter requirement that existing
`formatter`s already meet, because they never change the end of the parse context. Neither adds a
data member to `basic_format_context` or `basic_format_parse_context`.


# Open questions

1. `capture` copies the result into a `basic_string<charT>` with the default allocator. Both
   libraries buffer internally with an inline small buffer (libc++ `__allocating_buffer`,
   libstdc++ `_Buf_sink`), and the mp-units measurements above use {fmt}'s inline
   500-character buffer. Should `capture` instead hand the written characters to a second function
   object as a `basic_string_view<charT>`, so that no allocation is needed for short output?
2. The names `capture` and `set_end` are placeholders.


# Wording

The proposed changes are relative to the current working draft.

[Wording is a first draft for LEWG; it will be refined with LWG.]{.ednote}

## [format.parse.ctx]{.sref}

Add to the synopsis of `basic_format_parse_context`, after `advance_to`:

::: add

```cpp
constexpr void set_end(const_iterator it);
```

:::

Add after the specification of `advance_to`:

::: add

```cpp
constexpr void set_end(const_iterator it);
```

[1]{.pnum} _Preconditions_: `begin() <= it` is `true`, and `it` is reachable from `begin()` within
the format string range the object was constructed with.

[2]{.pnum} _Effects_: Equivalent to: `end_ = it;`
:::

## [formatter.requirements]{.sref}

In the BasicFormatter requirements, add to the requirement on `g.parse(pc)`:

::: add
If the call returns normally, `pc.end()` has the same value after the call as before it.
:::

## [format.context]{.sref}

Add to the synopsis of `basic_format_context`, after `advance_to`:

::: add

```cpp
template<class F>
  constexpr void capture(basic_string<charT>& str, F&& f);
```

:::

Add after the specification of `advance_to`:

::: add

```cpp
template<class F>
  constexpr void capture(basic_string<charT>& str, F&& f);
```

[1]{.pnum} _Mandates_: `is_invocable_v<F, basic_format_context&>` is `true`.

[2]{.pnum} _Effects_: Let `o` be the value of `out_` before the call. Sets the output iterator to
an iterator of type `iterator` that writes to an internal buffer, then evaluates
`invoke(std::forward<F>(f), *this)`. If that evaluation returns normally, appends the characters
written to the internal buffer to `str`. Otherwise, the contents of `str` are unspecified. In
either case, sets the output iterator to `o`.

[3]{.pnum} [Arguments and locale accessed through `*this` while `f` is evaluated are those of the
original context.]{.note}

[4]{.pnum} [Iterators obtained from `out()` during the evaluation of `f` are not usable after
`capture` returns.]{.note}
:::


# Acknowledgements

Special thanks and recognition goes to [The C++ Alliance](https://cppalliance.org) for supporting
Mateusz's membership in the ISO C++ Committee and the production of this proposal.


# Appendix: `capture` prototype

The prototype below implements `capture` as a free function on the internals of both standard
libraries and uses it in a `formatter` that pads its whole output with dots.

```cpp
template<class Out, class Char, class F>
void capture(std::basic_format_context<Out, Char>& ctx, std::basic_string<Char>& str, F f)
{
  const auto saved = ctx.out();
#if defined(_LIBCPP_VERSION)
  std::__format::__allocating_buffer<Char> buffer;
  ctx.advance_to(buffer.__make_output_iterator());
  f(ctx);
  str.append(buffer.__view());
#else
  std::__format::_Str_sink<Char> sink;
  ctx.advance_to(sink.out());
  f(ctx);
  str.append(sink.view());
#endif
  ctx.advance_to(saved);
}

struct point { double x, y; };

// `{:W:S}`: W pads the whole "(x, y)", S is the spec of each coordinate
template<>
struct std::formatter<point> {
  std::size_t width = 0;
  std::formatter<double> coord;

  constexpr auto parse(std::format_parse_context& ctx)
  {
    auto it = ctx.begin();
    while (it != ctx.end() && *it >= '0' && *it <= '9') width = width * 10 + std::size_t(*it++ - '0');
    if (it != ctx.end() && *it == ':') {
      ctx.advance_to(++it);
      it = coord.parse(ctx);
    }
    return it;
  }

  auto format(const point& p, auto& ctx) const
  {
    std::string text;
    capture(ctx, text, [&](auto& c) {
      c.advance_to(std::format_to(c.out(), "("));
      c.advance_to(coord.format(p.x, c));
      c.advance_to(std::format_to(c.out(), ", "));
      c.advance_to(coord.format(p.y, c));
      c.advance_to(std::format_to(c.out(), ")"));
    });
    auto out = ctx.out();
    for (auto n = text.size(); n < width; ++n) *out++ = '.';  // counts code units, enough for this ASCII example
    return std::ranges::copy(text, out).out;
  }
};

int main()
{
  std::println("[{:20:.{}f}]", point{1.25, 2.5}, 1);              // [..........(1.2, 2.5)]
  std::println("[{} {:24:>{}.{}f}]", "args:", point{1.25, 2.5}, 6, 2);
                                                                  // [args: ........(  1.25,   2.50)]
}
```

The prototype works only for a top-level argument. A complete implementation also needs `capture`
on the other context specializations named in [Redirecting the format context]: the context of
the `formattable` check and the retarget context of libc++. Without them,
`std::formattable<point, char>` and formatting a `std::vector<point>` fail to compile with this
prototype.

Missing in the prototype, and required from an implementation, is restoring the output iterator
when `f` exits via an exception.

---
references:

- id: MP-UNITS
  citation-label: mp-units
  title: "mp-units - A Physical Quantities and Units library for C++"
  URL: <https://mpusz.github.io/mp-units>

- id: FMT_4949
  citation-label: fmt#4949
  title: "FMT_COMPILE fails to format std::array"
  URL: <https://github.com/fmtlib/fmt/issues/4949>

- id: FMT_4974
  citation-label: fmt#4974
  title: "Fix FMT_COMPILE with ranges, tuples and maps"
  URL: <https://github.com/fmtlib/fmt/pull/4974>

- id: P3045R10_PRE
  citation-label: P3045R10
  author:
    - family: Pusz
      given: Mateusz
  title: "Quantities and units library"
  URL: <https://wg21.link/p3045r10>

- id: FMT_SET_END
  citation-label: fmt set_end
  title: "Add parse_context::set_end for delegating delimited specs"
  URL: <https://github.com/fmtlib/fmt/pulls>

---
