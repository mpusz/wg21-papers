---
title: "Locale-independent digit grouping in `std::format`"
document: P4410R0
date: today
audience:
  - SG16 Unicode
  - Library Evolution Working Group
author:
  - name: Mateusz Pusz
    email: <mateusz.pusz@gmail.com>
toc-depth: 3
---


# Introduction

ISO 80000-1 [@ISO80000-1] and the SI Brochure [@SI] specify how to group the digits of a number
with many digits. The digits are separated into groups of three, counting from the decimal sign
towards the left and towards the right, and the groups are separated by a small space:

```text
299 792 458        1.602 176 634e-19        43 279.168 29
```

Software more often groups only the integer part, with a comma. Python's `,` option and {fmt}'s
`group_digits` print `1,234,567`, and so do the POSIX `printf` `'` flag and Java's `,` flag in an
`en_US` locale. C++ itself writes `1'234'567` in its literals.

`std::format` can't produce the last two numbers of the ISO example, and it can produce the others
only through a locale. Its only grouping facility is the `L` option, which asks the locale. The
locale decides the group sizes and the separator, and the result never groups the fractional part.

The quantities and units library [@P3045R10_PRE] lists this grouping as a dependency.

This paper proposes a new `'` option for the standard format specification
[format.string.std]{.sref}, optionally followed by the separator:

```cpp
std::format("{:'}", 299'792'458);            // "299 792 458"
std::format("{:'.6f}", 1234567.891234);      // "1 234 567.891 234"
std::format("{:'.9e}", 1.602176634e-19);     // "1.602 176 634e-19"
std::format("{:',.2f}", 1234567.891234);     // "1,234,567.89"
std::format("{:''}", 299'792'458);           // "299'792'458"
```

`'` alone follows ISO 80000. When the literal encoding of the character type is a Unicode encoding,
the separator is U+202F NARROW NO-BREAK SPACE. `{:' }` does the same with U+0020 SPACE, for output
that should stay in ASCII. `',`, `'_`, and `''` group only the integer part, as Python's `,` and
`_` do by default.

Without `L`, the option doesn't depend on a locale. This is why it also works in constant
evaluation for integers. [@P3391R2] made `std::format` usable in constant evaluation for integers
but not for floating-point types, whose `to_chars` overloads are not `constexpr`.


# Motivation

## Numbers with many digits

Since C++14, a programmer can make a long number readable in the source code with a digit
separator. In the output, the same number comes out ungrouped:

```cpp
constexpr std::int64_t c = 299'792'458;          // speed of light in m/s
constexpr double N_A = 6.022'140'76e23;          // Avogadro constant in 1/mol
constexpr double e = 1.602'176'634e-19;          // elementary charge in C

std::println("{}", c);                           // 299792458
std::println("{}", N_A);                         // 6.02214076e+23
std::println("{:.8e}", e);                       // 1.60217663e-19
std::println("{:.9f}", 1234567.891234567);       // 1234567.891234567
```

The concise notation for a value with its standard uncertainty, given in ISO 80000-1:2022, 7.2.4,
quotes the value down to the last digit of the uncertainty, and its own example is grouped:
`l = 23,478 2(32) m`. CODATA publishes the Newtonian constant of gravitation as
`6.674 30(15) × 10⁻¹¹ m³ kg⁻¹ s⁻²`. Both group the digits after the decimal sign.

## The `L` option can't express the rule

The only way to get any grouping out of `std::format` today is the `L` option
([format.string.std]{.sref}/17), which inserts separators "as if obtained with
`numpunct<charT>::grouping` and `numpunct<charT>::thousands_sep`". Each of the three decisions
that ISO 80000 fixes is left to the locale instead:

1. **Group sizes.** `en_US` groups by three, but `en_IN` writes `12,34,567`.
2. **The separator.** `en_US` uses a comma, `de_CH` an apostrophe, `fr_FR` a narrow no-break
   space. ISO 80000-1 forbids "a point or a comma or [...] any other means".
3. **The fractional part.** `numpunct` has no notion of grouping digits after the radix
   separator. No `numpunct` facet can produce `0.567 8`.

If we write our own `numpunct` facet to get groups of three, we meet one more limit.
`thousands_sep()` returns a single `charT`. For `char`, the separator therefore can't be U+202F
(three code units in UTF-8). The fractional part still stays ungrouped:

```cpp
struct iso_grouping : std::numpunct<char> {
  char do_thousands_sep() const override { return ' '; }
  std::string do_grouping() const override { return "\3"; }
};

const std::locale loc(std::locale::classic(), new iso_grouping);
std::println("{}", std::format(loc, "{:L}", 299'792'458));          // 299 792 458
std::println("{}", std::format(loc, "{:.6Lf}", 1234567.891234567)); // 1 234 567.891235
```

The named locales that happen to use a narrow space don't help `char` output either. libstdc++
reads U+202F from glibc's `fr_FR.UTF-8` and narrows it to U+0020 for `numpunct<char>`
[@GCC87642]. Only `wchar_t` output keeps it:

```cpp
std::format(std::locale("fr_FR.UTF-8"), "{:.6Lf}", 1234567.891234);    // "1 234 567,891234" (U+0020)
std::format(std::locale("fr_FR.UTF-8"), L"{:.6Lf}", 1234567.891234);   // L"1 234 567,891234"
```

An implementation may convert the locale's separator to the literal encoding for an
implementation-defined set of locales ([format.string.std]{.sref}/17), but neither libstdc++ nor
libc++ does it for `fr_FR`, and libc++ prints a comma for `de_CH`.

Finally, the same paragraph says that "a call to `format` on a given formatter specialization is
not a constant subexpression if the locale-specific form is specified".
`std::format` can't produce a grouped number at compile time today.

## Comma grouping needs a locale too

A simpler request is `1,234,567`. With `std::format`, it needs a locale that groups by three with
a comma, and the program has to name one:

```cpp
std::format(std::locale("en_US.UTF-8"), "{:L}", 1234567);    // "1,234,567"
```

The result depends on which locales are installed. Constructing a locale that
isn't installed throws `std::runtime_error`. Using `std::format("{:L}", 1234567)` instead depends on
the global locale, which a library shouldn't change. Python solved the same problem with its `,`
option [@PEP378], whose stated goal is "a simple, non-locale aware way to format a number with a
thousands separator". The maintainer of {fmt} answers the same request with "use a locale or
`fmt::group_digits`" [@FMT3929; @FMT3840], and one user reported locale-based formatting as about
100 times slower in their benchmark [@FMT4284].

## Quantities and units

The quantities and units library [@P3045R10_PRE] prints a quantity as its numerical value
followed by its unit, both as ISO 80000 specifies. The numerical value is formatted by the
`std::formatter` of the representation type, with the spec in `N[...]` forwarded to it unchanged
(`{::N[.2f]}`). [@P3045R10_PRE] lists grouping in `std-format-spec` as a dependency. With this
proposal, `{::N['.2f]}` would group the number, with no change to the library.

The library can also print a unit in the basic character set: `{::U[P]}` prints `42 kohm`
instead of `42 kΩ`. A terminal or a log may be unable to display Unicode, or users may prefer
ASCII because they find it easier to read, or easier to process with other tools later. In either
case, a U+202F in the number defeats the purpose, even when the program uses UTF-8.
`{::N[' .2f]U[P]}` keeps the whole output in ASCII, at the cost of a separator that looks like the
space before the unit.


# What the standards say

ISO 80000-1:2022, 7.2.1 [@ISO80000-1]:

> To facilitate the reading of numbers with many digits, these may be separated into groups of
> three, counting from the decimal sign towards the left and the right. No group shall contain
> more than three digits. Where such separation into groups of three is used, the groups shall be
> separated by a small space and not by a point or a comma or by any other means.
>
> EXAMPLE 1 1 234,567 8 rather than 1 234,5678\
> 0,567 8 rather than 0,5678
>
> In the case where there is no decimal part (and thus no decimal sign), the counting shall be
> from the right-most digit towards the left.
>
> [...]
>
> The separation into groups of three should not be used for ordinal numbers used as reference
> numbers, e.g. ISO 80000-1. The year shall always be written without a space, e.g., 1935.

Clause 7.2.2 adds that "the decimal sign is either a comma or a point on the line".

The SI Brochure, 9th edition, 5.4.4 [@SI], states the same rule and adds an exception for four
digits:

> Following the 9th CGPM (1948, Resolution 7) and the 22nd CGPM (2003, Resolution 10), for numbers
> with many digits the digits may be divided into groups of three by a space, in order to
> facilitate reading. Neither dots nor commas are ever inserted in the spaces between groups. For
> example, 43 279.168 29 but not 43,279.168,29. However, when there are only four digits before or
> after the decimal marker, it is customary not to use a space to isolate a single digit. The
> practice of grouping digits in this way is a matter of choice; it is not always followed in
> certain specialized applications such as engineering drawings, financial statements and scripts
> to be read by a computer. For example, either 3279.1683 or 3 279.168 3.
>
> For numbers in a table, the format used should not vary within one column.

The committee draft of IEC 80000-16 [@IEC80000-16], 4.5.3, has the same four-digit exception,
with "1 234 or 1234" and "1 234,567 8 or 1234,5678" as examples. NIST SP 811 [@NIST811], 10.5.3,
asks for "a thin, fixed space" and drops the four-digit exception "when uniformity in a table is
desired". The IUPAC Green Book [@IUPAC-GB], 4.1, also asks for a thin space and recommends the
four-digit exception.

None of them requires grouping. This paper therefore proposes an option and doesn't change the
default output.


# Prior art

## Other languages and libraries

Most of the facilities below group only the integer part, and most take the separator from the
locale. Among the facilities below, only Python and siunitx group the fractional part without a
locale. Python uses `,` or `_`.

Python added locale-independent grouping in PEP 378 [@PEP378] (Raymond Hettinger, Python 3.1) with
the `,` option, and PEP 515 [@PEP515] (Georg Brandl and Serhiy Storchaka, Python 3.6) added `_`,
which groups by four for `b`, `o`, `x`, and `X`. PEP 378 kept the locale-aware `n` presentation type
separate, so `,` always gives the same output. Python 3.14 extended both options to the fractional
part [@CPYTHON87790] (Sergey B Kirpichev), with a second grouping character after the precision. The
discussion that led to it quoted NIST SP 811 and ISO 80000-1. Python 3.14.4 prints:

```python
format(1234567.891234, ',')       # '1,234,567.891234'
format(1234567.891234, '_.6_f')   # '1_234_567.891_234'
format(1234567.891234, '.10_e')   # '1.234_567_891_2e+06'
format(1234567, '015,')           # '000,001,234,567'
format(1, '04,')                  # '0,001'
format(1234567, ',x')             # ValueError: Cannot specify ',' with 'x'.
```

The rejected alternative in PEP 378, proposed by Eric Smith, let the user choose the separator,
including a space (U+0020 or U+00A0).

{fmt} [@FMT] has `fmt::group_digits`, which groups integers by three with a comma and doesn't use
a locale. For any other separator its maintainer points users to a locale
[@FMT3929; @FMT3840]. {fmt} 10 added `fmt::format_facet` so that a locale can carry a separator
longer than one code unit, but the separator is applied only to integers.

POSIX `printf` has the `'` flag. It uses the locale's grouping and only groups "the integer
portion" of a decimal conversion. ISO C doesn't have it, and LWG 826 [@LWG826] closed a request to
add it to C++ as NAD, suggesting a paper.

Java (`java.util.Formatter` with `,`, and `DecimalFormat`), .NET (the `N` format), and
`Intl.NumberFormat` in JavaScript group only the integer part with the locale's separator. Rust's
`std::fmt` has no grouping at all.

ICU's `group-min2` strategy [@ICU-SKELETONS] implements the four-digit exception for the integer
part, and CLDR's `minimumGroupingDigits` [@CLDR-NUMBERS] enables it per locale, for example 2 for
Polish and Spanish and 1 for French. Since CLDR 34
[@CLDR34], French uses U+202F as its grouping separator. CLDR's number patterns allow a grouping
separator in the fractional part, "most commonly done where the grouping separator character is a
thin, non-breaking space (U+202F), such as '1.618 033 988 75'".

The LaTeX package siunitx [@SIUNITX] (Joseph Wright) groups both parts of a number by default,
with a thin space. Its `group-digits` option selects the integer
part, the fractional part, both, or neither, and `group-separator` selects the separator. Its
`group-minimum-digits` defaults to 5 and is applied to each part separately, so `\num{1234}`
prints `1234` and `\num{12345.67890}` prints `12 345.678 90`.

## WG21

[@P0645R10] took its format syntax from Python but not the `,` and `_` options. It kept locale
behavior behind a separate presentation type, later replaced with the `L` option by [@P1892R1].
LWG 2117 [@LWG2117] asked for a way to turn grouping on and off in iostreams and is still open. The
author found no paper proposing a grouping option for `std::format`.


# Design

## Spelling and position

The option is `'`, the digit separator of C++ literals since C++14 [@N3781], optionally followed
by the separator character. It goes between the width and the precision:

```text
std-format-spec :
    fill-and-align(opt) sign(opt) #(opt) 0(opt) width(opt) grouping(opt) precision(opt) L(opt) type(opt)
grouping :
    ' grouping-separator(opt)
grouping-separator : one of
    space , _ '
```

This is where Python puts `,` and `_`: `{:,.2f}` in Python becomes `{:',.2f}` in C++. There is no
ambiguity with a fill character. A fill comes first and is always followed by an alignment, so
`{:'^12'}` centers a grouped number in apostrophes. A `'` followed by an alignment is a fill, so
`{:'>12}` pads with apostrophes and doesn't group. `.` isn't a separator, so `{:'.2f}`
means grouping with a precision of 2. No existing option of `std-format-spec` uses `'`,
and the author found no proposal that does.

The alternatives considered:

- Python's spelling, `,` and `_` without an introducer. `{:,}` would read the same as in Python,
  but the ISO form and the space form still need a spelling. Without a width, a space after the
  colon is the _sign_ option (`{: }`), so the space form needs an introducer. One introducer for
  every form keeps the grammar to one slot.
- After the precision, next to `L`. The two options are related, as discussed in [Interaction with
  `L`], but `{:.3'Lf}` puts the grouping between two options that have nothing to do with it.
- A letter, for example `I` for "international". It reads well next to `L`, but apart from the
  presentation types no option spelled as a letter changes the digits.

## Separators

| Spec    | Separator                                       | Fractional part grouped | With `L` |
|---------|-------------------------------------------------|:-----------------------:|:--------:|
| `{:'}`  | U+202F, or U+0020 if the encoding isn't Unicode |           yes           |  valid   |
| `{:' }` | U+0020                                          |           yes           |  valid   |
| `{:',}` | `,`                                             |           no            | invalid  |
| `{:'_}` | `_`                                             |           no            | invalid  |
| `{:''}` | `'`                                             |           no            | invalid  |

The two space forms follow ISO 80000 and the SI Brochure, which group both sides of the decimal
marker. `{:' }` exists for output that should stay in ASCII even when the program uses a Unicode
encoding, as in [Quantities and units].

The other three follow the conventions they come from, and all of them group only the integer part.
The comma comes from Python and from the `en_US` conventions that POSIX, Java, and .NET read from
the locale. The underscore comes from Python, and the apostrophe from C++ integer literals and from
the `de-CH` locale in CLDR. The SI Brochure gives `43,279.168,29` as the example of what not to do.
Python 3.14 groups the fractional part with a second option after the precision instead. Tying it
to the separator keeps one option, at the cost of the separator also deciding which digits are
grouped. If LEWG wants fractional grouping with a comma, a later revision can add Python's syntax.

A user who asks for `',` with units gets output that ISO 80000 forbids. The option doesn't
prevent it, just as it doesn't prevent grouping a year.

## Types and presentation types

Every form of the option is valid for:

- integer types other than `bool`, `char`, and `charT`, with no presentation type or `d`,
- floating-point types, with no presentation type or `f`, `F`, `e`, `E`, `g`, or `G`.

For other types, and for `b`, `B`, `o`, `x`, `X`, `a`, `A`, `c`, and `?`, the format string is
ill-formed. This includes `bool`, `char`, and `charT` formatted with `d`, which the `0` option
allows. Python's `_` groups binary, octal, and hexadecimal digits by four.
Allowing these presentation types with groups of three would block that later, and making the group
size depend on the presentation type needs its own discussion. A later proposal can add it.

For `e`, `E`, and the exponent form of `g` and `G`, the significand is grouped and the exponent is
not. Unless `0` pads it, the integer part of the significand is a single digit, so with a space
form only its fractional part is grouped: `1.602 176 634e-19`. With `,`, `_`, or `'`, an exponent
form isn't grouped unless `0` pads it. An infinity or a NaN has no digits and is unaffected.

## The ISO separator character

ISO 80000-1 asks for "a small space", NIST SP 811 for "a thin, fixed space", and the SI Brochure
for "a space". This paper compares three candidates for `'` alone:

| Code point | Name                  | Line breaking [@UAX14] | Width                |
|:----------:|-----------------------|:----------------------:|----------------------|
|   U+2009   | THIN SPACE            | BA (break opportunity) | 1/5 to 1/6 em        |
|   U+202F   | NARROW NO-BREAK SPACE |     GL (no break)      | the same as U+2009   |
|   U+2007   | FIGURE SPACE          |     GL (no break)      | the width of a digit |

This paper proposes U+202F. A line break inside a number changes what the reader sees as the
number, so the separator must not allow one. U+2009 does. U+2007 is the space UAX #14
recommends "in numbers", but it is as wide as a digit, which is not the small space ISO 80000 asks
for. U+202F is also what CLDR uses for French since version 34 and what glibc's `fr_FR` locale
provides.

None of the three is in the East Asian wide ranges, so [format.string.std]{.sref}/13 says an
implementation should give each a field width of 1. In UTF-8, U+202F takes 3 code units and 1
column.

This paper uses U+202F only for a Unicode encoding form, and it tests that with the condition
[format.string.escaped]{.sref} already uses: the associated character encoding for `charT`
(Table 12, [lex.string]{.sref}). If it is UTF-8, UTF-16, or UTF-32, the separator is U+202F.
Otherwise it is U+0020 SPACE. The SI Brochure asks only for "a space", and U+0020 exists in every
encoding a C++ implementation supports.

The literal encoding is fixed when the program is compiled, but the choice of output is not. A
UTF-8 program may write to a terminal or a log that only shows ASCII, or its users may prefer ASCII
output. `{:' }` lets the caller choose U+0020 in both cases.

Grouping with U+0020 makes the end of a number ambiguous when a unit follows it (`1 234 567 m`).
This is one more reason to prefer U+202F where it is available.

A grouped number is no longer a valid input for `from_chars` or `stod`. The SI Brochure already
says that grouping is not always followed in "scripts to be read by a computer", and the option is
opt-in.

## Width and zero padding

The separators are part of the formatted output and count towards the estimated field width, one
column each:

```cpp
std::format("{:*>12'}", 1234567);    // "***1 234 567"
```

The `0` option inserts digits, so the zeros it adds are grouped with the rest. The number of zeros
is the smallest one for which the field is at least as wide as requested. A separator is never
the first character after the sign, so the result can be one column wider than requested. Python
does the same:

```cpp
std::format("{:011'}", 1234);       // "000 001 234"
std::format("{:04'}", 1);           // "0 001"
std::format("{:010'}", -1234);      // "-0 001 234"
std::format("{:010',}", 1234567);   // "01,234,567"
```

`'` and `0` could instead be made mutually exclusive. This paper keeps both and groups the zeros.
Leaving the padding zeros ungrouped gives
`0001 234` and breaks the rule that no group has more than three digits. glibc, libstdc++, and
{fmt} do that for `L`, but `L` doesn't claim to follow ISO 80000.

## Interaction with `L`

`'` without `L` never reads a locale. With `L`, the locale is the one passed to `format`, or the
global locale otherwise, as for any use of `L`.

`L` does three things for a floating-point number: the locale chooses the group sizes, the group
separator, and the radix separator. The two space forms replace the first two. When both are
present, the locale provides only the radix separator:

```cpp
std::format(std::locale("de_DE.UTF-8"), "{:'.4Lf}", 1234.5678);   // "1 234,567 8"
```

Without a second new option, this gives the decimal comma that ISO 80000-1 and the CGPM allow.
Like any use of `L`, the combination is not a constant subexpression.

For integers, `L` only controls grouping, so `{:'L}` prints the same as `{:'}`. Unlike `{:'}`,
it is not a constant subexpression.

`',`, `'_`, and `''` can't be combined with `L`. With a locale whose decimal marker is a comma,
`{:',.1Lf}` of 1234.5 would print `1,234,5`, which can be read in two ways. `'_` and `''` don't have
this problem. One rule for the three explicit separators keeps the option simple, and a later
revision can relax it for `'_` and `''`. Python rejects both `,` and `_` with `n`. A user who wants
the locale's separator uses `L` alone. The locale's separator together with grouping of the
fractional part isn't available. Neither `numpunct` nor ISO 80000 describes it.

If `'` and `L` were mutually exclusive in this revision, a user who wants the decimal comma would
need a separate option, for example a `,` that selects the comma as the radix separator. The author
prefers the combination because the locale already knows the decimal marker its users expect.

## The four-digit exception

ISO 80000-1:2022 has no four-digit exception: its example prints
`1 234,567 8 rather than 1 234,5678`. The SI Brochure and the IEC 80000-16 draft make an exception
for a four-digit integer or fractional part, and both say it is customary, not required. Under both
documents, either form complies.

This paper proposes to always group, with every separator:

- For the space forms, it follows ISO 80000-1.
- A number keeps the same shape in a column of a table. The SI Brochure itself asks that "the
  format used should not vary within one column", and NIST SP 811 drops the exception for tables.
- When the output contains `1234`, the reader can't tell whether the option was ignored.

If LEWG wants the exception, it should be a second option, so that `'` always means the same thing.
ICU's `group-min2` (integer part only) and siunitx's `group-minimum-digits` are precedents. The
{fmt} prototype implements the exception behind a macro, to show that it costs little:

```cpp
std::format("{:'}", 1234);           // "1 234"  (proposed)    "1234"  (with the exception)
std::format("{:'.4f}", 1234.5678);   // "1 234.567 8"          "1234.5678"
std::format("{:'.5f}", 1234.5678);   // "1 234.567 80"         "1234.567 80"
```

The rule that years are not grouped is left to the user. A formatter doesn't know whether an
integer is a year.

## The decimal marker

This paper doesn't propose a new option for the decimal marker. The point is the default, and the
comma is available through `L` as described above.


# Impact on existing code

None. Today a `'` that is not a fill character is ill-formed in a `std-format-spec`, so no valid
format string changes meaning.
User-defined formatters that delegate to the standard arithmetic formatters, such as the one in
[@P3045R10_PRE], get the option automatically.


# Implementation experience

The design is implemented in a draft pull request to {fmt} [@FMT-ISO-GROUPING], including every
separator, `'` with `0` and with `L`, the U+0020 fallback for `char`, and the four-digit exception
behind a macro. Its test suite passes with GCC 16 and Clang 23, for `char`, `wchar_t`, `char16_t`,
and `char32_t`. All outputs of the `'` option shown in this paper come from that branch.

Parsing and width needed only small changes. The option is one more state between the width and
the precision, and the checks of the presentation type stay `constexpr`, so a checked format string
reports `{:'x}` at compile time. {fmt} already passes the size in code units and the display width
separately to its padding function, so a three-byte separator counts as one column.

{fmt}'s grouping support, used for `L`, groups one run of digits from the right and is applied
only to the integer digits of a floating-point number. The fixed form of small values, the
exponent form, and the shortest round-trip form all reach the output through different code paths,
and none of them groups the digits after the decimal point. The prototype therefore formats the
number without grouping into a buffer and then inserts the separators and the padding. This costs
one extra copy for floating-point values. A production implementation would group in the code that
writes the significand.

The prototype also found that `'` must be checked before the existing dispatch to the
locale-specific path. For the combination with `L`, only `decimal_point` is read from the locale.


# Proposed polls {#polls}

## SG16

1. U+202F NARROW NO-BREAK SPACE, rather than U+2009 THIN SPACE, is the right digit group separator
   for `'` alone.
2. When the associated character encoding for `charT` is not a Unicode encoding form, the separator
   of `'` alone should be U+0020 SPACE, rather than an implementation-defined character, and the
   format string should be well-formed.

## LEWG

1. We want a locale-independent digit grouping option in `std-format-spec`.
2. `'` after the width is the right character and position for the option.
3. The option should accept space, `,`, `_`, and `'` as explicit separators.
4. Only the space forms should group the fractional part.
5. The space forms combined with `L` should be valid and take only the decimal marker from the
   locale.
6. The zeros inserted by `0` should be grouped.
7. We want a second option for the four-digit exception.


# Wording

The proposed changes are relative to [@N5054].

## [format.string.std]{.sref}

Modify the grammar in paragraph 1 as follows:

<!-- markdownlint-disable MD013 -->

> | _std-format-spec_ :
> |     _fill-and-align_~opt~ _sign_~opt~ `#`~opt~ `0`~opt~ _width_~opt~ [_grouping_~opt~]{.add} _precision_~opt~ `L`~opt~ _type_~opt~
>
> [...]
>
> | _width_ :
> |     _positive-integer_
> |     `{` _arg-id_~opt~ `}`
>
> ::: add
> | _grouping_ :
> |     `'` _grouping-separator_~opt~
>
> | _grouping-separator_ : one of
> |     space `,` `_` `'`
> :::
>
> | _precision_ :
> |     `.` _nonnegative-integer_
> |     `.` `{` _arg-id_~opt~ `}`

<!-- markdownlint-enable MD013 -->

Modify paragraph 8 as follows:

> [8]{.pnum} The `0` option is valid for arithmetic types other than `charT` and `bool`, pointer
> types, or when an integer presentation type is specified. For formatting arguments that have a
> value other than an infinity or a NaN, this option pads the formatted argument by inserting the
> `0` character _n_ times following the sign or base prefix indicators (if any) where _n_ is `0` if
> the _align_ option is present and is the padding width otherwise.
> [If the _grouping_ option is also used and the _align_ option is not present, the inserted `0`
> characters are digits for the purposes of the _grouping_ option, and _n_ is instead the smallest
> value for which the field width of the result, including the inserted `0` characters and the digit
> group separators, is not less than the minimum field width.]{.add}
>
> [_Example 3_: ...]{.ednote}
>
> ::: add
>
> If the ordinary literal encoding is UTF-8:
>
> ```cpp
> string s5 = format("{:011'}", 1234);          // value of s5 is "000 001 234"
> string s6 = format("{:04'}", 1);              // value of s6 is "0 001"
> string s7 = format("{:010',}", 1234567);      // value of s7 is "01,234,567"
> ```
>
> :::
>
> [_- end example_]{.ednote}

Add new paragraphs after paragraph 16:

::: add

> [16+1]{.pnum} The _grouping_ option is valid for arithmetic types other than `bool`, `char`, and
> `charT`.
> It is valid only if the _type_ option is absent or is `d` for integral types, and only if it is
> absent or is one of `e`, `E`, `f`, `F`, `g`, or `G` for floating-point types.
> If the _grouping-separator_ is present and is not a space, the _grouping_ option is not valid
> together with the `L` option.
>
> [16+2]{.pnum} When the _grouping_ option is used, the digits of the formatted argument, other than
> the digits of the exponent, are divided into groups and a digit group separator is inserted
> between adjacent groups:
>
> - [16+2.1]{.pnum} the digits that precede the radix separator, or all of those digits if there
>   is no radix separator, are divided into groups of three counting from the last of them
>   towards the first;
> - [16+2.2]{.pnum} if the _grouping-separator_ is absent or is a space, the digits that follow the
>   radix separator are divided into groups of three counting from the first of them towards the
>   last.
>
> In each case, the last group formed contains one, two, or three digits.
>
> [16+3]{.pnum} If the _grouping-separator_ is present, the digit group separator is the character
> it denotes. Otherwise, if the associated character encoding for `charT` (Table 12) is UTF-8,
> UTF-16, or UTF-32, the digit group separator is U+202f narrow no-break space; otherwise, it is
> U+0020 space.
>
> [_Note_: Without a _grouping-separator_, this is the grouping specified by ISO 80000-1:2022,
> 7.2.1. Paragraph 13 recommends a field width of 1 for the digit group separator in UTF-8, UTF-16,
> and UTF-32. The digits of the exponent are not grouped. _- end note_]
>
> [_Example_: If the ordinary literal encoding is UTF-8:
>
> ```cpp
> string s0 = format("{:'}", 1234567);             // value of s0 is "1 234 567"
> string s1 = format("{:'}", -1234);               // value of s1 is "-1 234"
> string s2 = format("{:'.6f}", 1234567.891234);   // value of s2 is "1 234 567.891 234"
> string s3 = format("{:'.6e}", 123456.789);       // value of s3 is "1.234 568e+05"
> string s4 = format("{:*>12'}", 1234567);         // value of s4 is "***1 234 567"
> string s5 = format("{:' .6f}", 1234567.891234);  // value of s5 is "1 234 567.891 234"
> string s6 = format("{:',.6f}", 1234567.891234);  // value of s6 is "1,234,567.891234"
> string s7 = format("{:'_}", 1234567);            // value of s7 is "1_234_567"
> string s8 = format("{:''}", 1234567);            // value of s8 is "1'234'567"
> string s9 = format("{:'x}", 1234567);            // error: invalid presentation type with grouping
> string s10 = format("{:',L}", 1234567);          // error: grouping-separator with L
> ```
>
> _- end example_]

:::

Modify paragraph 17 as follows:

> [17]{.pnum} When the `L` option is used, the form used for the conversion is called the
> locale-specific form. The `L` option is only valid for arithmetic types, and its effect depends
> upon the type. A call to `format` on a given formatter specialization is not a constant
> subexpression if the locale-specific form is specified.
>
> - [17.1]{.pnum} For integral types, the locale-specific form causes the context's locale to be
>   used to insert the appropriate digit group separator characters as if obtained with
>   `numpunct<charT>::grouping` and `numpunct<charT>::thousands_sep`[, unless the _grouping_ option
>   is also used]{.add}.
> - [17.2]{.pnum} For floating-point types, the locale-specific form causes the context's locale to
>   be used to insert the appropriate digit group and radix separator characters as if obtained
>   with `numpunct<charT>::grouping`, `numpunct<charT>::thousands_sep`, and
>   `numpunct<charT>::decimal_point`[. If the _grouping_ option is also used, only the radix
>   separator is obtained from the locale, and digit groups are formed as specified for the
>   _grouping_ option]{.add}.
>
> [...]

## [format.formatter.spec]{.sref}

[No change is needed: the `formatter` specializations for arithmetic types already interpret
`format-spec` as a `std-format-spec`.]{.ednote}

## [version.syn]{.sref}

Bump the value of `__cpp_lib_format`:

> ```cpp
> #define __cpp_lib_format    @[2026XXL]{.add}@ // also in <format>
> ```

## Bibliography {#wording-bibliography}

Add the following entry to the Bibliography:

::: add

> - ISO 80000-1:2022, _Quantities and units — Part 1: General_

:::


# Acknowledgements

Special thanks and recognition goes to [The C++ Alliance](https://cppalliance.org) for supporting
Mateusz's membership in the ISO C++ Committee and the production of this proposal.

---
references:

- id: ISO80000-1
  citation-label: ISO 80000-1
  title: "ISO 80000-1:2022 Quantities and units - Part 1: General"
  URL: <https://www.iso.org/standard/76921.html>

- id: IEC80000-16
  citation-label: IEC CD 80000-16
  title: "IEC CD 80000-16:2023 Quantities and units - Part 16 (committee draft)"
  URL: <https://www.iec.ch>

- id: SI
  citation-label: SI
  title: "The International System of Units (SI), 9th edition, 2019 (V4.01, 2026)"
  URL: <https://www.bipm.org/en/publications/si-brochure>

- id: NIST811
  citation-label: NIST SP 811
  title: "NIST SP 811, Guide for the Use of the International System of Units (SI), 2008"
  URL: <https://www.nist.gov/pml/special-publication-811>

- id: IUPAC-GB
  citation-label: IUPAC Green Book
  title: "Quantities, Units and Symbols in Physical Chemistry, 3rd edition, 2nd printing"
  URL: <https://iupac.org/wp-content/uploads/2019/05/IUPAC-GB3-2012-2ndPrinting-PDFsearchable.pdf>

- id: UAX14
  citation-label: UAX #14
  title: "Unicode Standard Annex #14: Unicode Line Breaking Algorithm"
  URL: <https://www.unicode.org/reports/tr14/>

- id: CLDR-NUMBERS
  citation-label: UTS #35 Numbers
  title: "Unicode Locale Data Markup Language (LDML) Part 3: Numbers"
  URL: <https://www.unicode.org/reports/tr35/tr35-numbers.html>

- id: CLDR34
  citation-label: CLDR 34
  title: "CLDR 34 Release Note"
  URL: <https://cldr.unicode.org/downloads/cldr-34>

- id: ICU-SKELETONS
  citation-label: ICU number skeletons
  title: "ICU User Guide: Number Skeletons"
  URL: <https://unicode-org.github.io/icu/userguide/format_parse/numbers/skeletons.html>

- id: PEP378
  citation-label: PEP 378
  title: "PEP 378 - Format Specifier for Thousands Separator"
  URL: <https://peps.python.org/pep-0378/>

- id: PEP515
  citation-label: PEP 515
  title: "PEP 515 - Underscores in Numeric Literals"
  URL: <https://peps.python.org/pep-0515/>

- id: CPYTHON87790
  citation-label: cpython#87790
  title: "Add underscore as a decimal separator for string formatting"
  URL: <https://github.com/python/cpython/issues/87790>

- id: FMT
  citation-label: "{fmt}"
  title: "{fmt}: A modern formatting library"
  URL: <https://github.com/fmtlib/fmt>

- id: FMT-ISO-GROUPING
  citation-label: fmt#4997
  title: "Add ' format option for digit grouping"
  URL: <https://github.com/fmtlib/fmt/pull/4997>

- id: FMT3929
  citation-label: fmt#3929
  title: "It would be good to have a customizable separator in fmt::group_digits(...)"
  URL: <https://github.com/fmtlib/fmt/issues/3929>

- id: FMT3840
  citation-label: fmt#3840
  title: "Custom thousand separator"
  URL: <https://github.com/fmtlib/fmt/issues/3840>

- id: FMT4284
  citation-label: fmt#4284
  title: "FMT_STATIC_THOUSANDS_SEPARATOR removed"
  URL: <https://github.com/fmtlib/fmt/issues/4284>

- id: SIUNITX
  citation-label: siunitx
  title: "siunitx - A comprehensive (SI) units package, v3.6.4"
  URL: <https://ctan.org/pkg/siunitx>

- id: GCC87642
  citation-label: GCC PR 87642
  title: "libstdc++: handle multibyte thousands separators from libc"
  URL: <https://gcc.gnu.org/bugzilla/show_bug.cgi?id=87642>

- id: LWG826
  citation-label: LWG 826
  title: "Equivalent of %'d, or rather, lack thereof?"
  URL: <https://cplusplus.github.io/LWG/issue826>

- id: P3045R10_PRE
  citation-label: P3045R10
  author:
    - family: Pusz
      given: Mateusz
  title: "Quantities and units library"
  URL: <https://wg21.link/p3045r10>

- id: LWG2117
  citation-label: LWG 2117
  title: "ios_base manipulators should have showgrouping/noshowgrouping"
  URL: <https://cplusplus.github.io/LWG/issue2117>

---
