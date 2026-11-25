---
title: "Unifying `std::span` and `std::string_view` interfaces"
document: P3837R0
date: today
audience:
  - Library Evolution Working Group
  - Library Working Group
author:
  - name: Mateusz Pusz
    email: <mateusz.pusz@gmail.com>
---


# Introduction

This paper proposes to unify the interfaces of `std::span` and `std::string_view` by adding
missing member functions to both types. The proposed changes:

1. Add `first` and `last` member functions to `std::string_view`
2. Add `remove_prefix` and `remove_suffix` member functions to dynamic-sized `std::span`


# Motivation

`std::span` and `std::string_view` are both lightweight, non-owning views over contiguous
sequences in the C++ Standard Library. They serve similar purposes but have inconsistent
interfaces that complicate generic programming and increase cognitive load.

Consider the following operations:

```cpp
std::string_view sv = "Hello, World!";
std::span sp{sv.data(), sv.size()};    // dynamic-sized span

// Getting first N elements
auto first5_sv = sv.substr(0, 5);      // "Hello"
auto first5_sp = sp.first(5);          // equivalent span

// Getting last N elements  
auto last6_sv = sv.substr(sv.size() - 6);  // "World!"
auto last6_sp = sp.last(6);                // equivalent span

// Removing prefix
sv.remove_prefix(7);                   // "World!"
// sp.remove_prefix(7);                // ERROR: no such member function

// Removing suffix
sv.remove_suffix(1);                   // "World"
// sp.remove_suffix(1);                // ERROR: no such member function
```

This inconsistency forces developers to:

1. **Remember different APIs** for similar operations
2. **Write non-generic code** that handles each type separately
3. **Use verbose workarounds** for missing functionality

Here's an example of generic code that currently requires specialization:

```cpp
template<typename View>
void process_middle_part(View& view) {
    if constexpr (std::is_same_v<View, std::string_view>) {
        view.remove_prefix(1);
        view.remove_suffix(1);
    } else if constexpr (requires { view.first(1); }) {
        // For span, we need to reassign since remove_* don't exist
        auto size = view.size();
        view = view.subspan(1, size - 2);
    }
}
```

With unified interfaces, this becomes simply:

```cpp
template<typename View>
void process_middle_part(View& view) {
    view.remove_prefix(1);
    view.remove_suffix(1);
}
```

*Note*: The above simplified example assumes the view is dynamically-sized (`std::string_view`  
or `std::span<T, std::dynamic_extent>`). For fixed-size spans, `remove_prefix` and `remove_suffix`  
are not available, requiring conditional compilation or concepts to handle both cases.


# Problem statement

The current state of `std::span` and `std::string_view` interfaces creates several issues:

## Interface Inconsistency

| Operation            | `std::string_view` | `std::span` | Generic Code Impact     |
|----------------------|--------------------|-------------|-------------------------|
| Get first N elements | `substr(0, n)`     | `first(n)`  | Requires different APIs |
| Get last N elements  | `substr(size()-n)` | `last(n)`   | Requires different APIs |
| Remove prefix        | `remove_prefix(n)` | ❌ Missing   | Forces workarounds      |
| Remove suffix        | `remove_suffix(n)` | ❌ Missing   | Forces workarounds      |

## Generic Programming Difficulties

Writing generic algorithms that work with both types requires template specialization or
SFINAE techniques, increasing complexity and reducing maintainability.

## Teachability Issues

New C++ developers must learn different interfaces for conceptually similar operations,
violating the principle of least surprise.


# Proposed Solution

We propose to add the missing member functions to both types, making their interfaces
consistent and complete.

## Core Proposal

### Add to `std::string_view`

- `constexpr string_view first(size_type n) const`
- `constexpr string_view last(size_type n) const`

### Add to `std::span`

- `constexpr void remove_prefix(size_type n)` (dynamic extent only)
- `constexpr void remove_suffix(size_type n)` (dynamic extent only)

*Note*: The `remove_prefix` and `remove_suffix` functions are only added to `span<T, dynamic_extent>`
because fixed-size spans cannot change their extent. This preserves semantic consistency with
`string_view` behavior (in-place modification) while avoiding the confusion that would arise
from having the same function names perform different operations (modification vs. returning new views).

# Impact on existing code

The proposed solution is **fully backward compatible**:

- All existing code continues to compile and behave identically
- No changes to existing function semantics or performance
- No ABI impact
- The additions only provide new functionality for previously unavailable operations

Example of enhanced generic code:

```cpp
// Before: Complex, type-specific code
template<typename View>
auto get_middle(const View& view) {
    if constexpr (std::is_same_v<View, std::string_view>) {
        return view.substr(1, view.size() - 2);
    } else {
        return view.subspan(1, view.size() - 2);
    }
}

// After: Simple, unified interface for dynamic spans and string_view
template<typename View>
void trim_ends(View& view) {
    if constexpr (requires { view.remove_prefix(1); }) {
        // Works for string_view and dynamic span
        view.remove_prefix(1);
        view.remove_suffix(1);
    } else {
        // Fallback for fixed span
        view = view.subspan(1, view.size() - 2);
    }
}

// For cases where you know you have a dynamic span or string_view:
template<typename DynamicView>
  requires requires(DynamicView& v) { v.remove_prefix(1); v.remove_suffix(1); }
void trim_ends_simple(DynamicView& view) {
    view.remove_prefix(1);  // Works for both!
    view.remove_suffix(1);  // Works for both!
}
```


# Design Alternatives and Rationale

The most critical design decision in this proposal is how to handle `remove_prefix` and `remove_suffix`
for fixed-size spans (`span<T, N>` where `N != dynamic_extent`). Since fixed-size spans cannot change
their extent, these functions cannot perform in-place modification as they do for `string_view`.

We thoroughly analyzed three potential approaches:

## Alternative 1: Return New Views (Like `first`/`last`)

### Implementation Approach

```cpp
// Hypothetical approach - NOT proposed
template<size_t Extent>
constexpr auto remove_prefix(size_type n) const -> span<element_type, Extent == dynamic_extent ? dynamic_extent : (Extent - n)>;

template<size_t Extent>  
constexpr auto remove_suffix(size_type n) const -> span<element_type, Extent == dynamic_extent ? dynamic_extent : (Extent - n)>;
```

### Advantages

- **Universal compatibility**: Works for both fixed and dynamic spans
- **Type safety**: Fixed spans return fixed spans with adjusted extents
- **No compilation errors**: All span types can use the same interface
- **Consistent availability**: Same function names work everywhere

### Disadvantages

- **Major semantic inconsistency**: Same function names (`remove_prefix`/`remove_suffix`) would have
  fundamentally different behaviors:
    - `string_view::remove_prefix(n)` - modifies the view in-place, returns `void`
    - `span::remove_prefix(n)` - returns a new view, original unchanged
- **Violation of principle of least surprise**: Developers expect consistent semantics across
  similar types
- **Potential for subtle bugs**: Code written for `string_view` could behave unexpectedly with `span`
- **Asymmetric interface**: `span` would be the only standard library type where these function names
  don't modify in-place

### Example of the Problem

```cpp
template<typename View>
void process_data(View& view) {
    auto original_size = view.size();
    view.remove_prefix(10);  // What does this do?
    
    // For string_view: view is modified, size() != original_size
    // For span: view unchanged, size() == original_size
    // This semantic difference could cause silent bugs
}
```

## Alternative 2: Hybrid Approach with Different Function Names

### Approach for Alternative 2

```cpp
// For dynamic spans only
constexpr void remove_prefix(size_type n);     // In-place modification
constexpr void remove_suffix(size_type n);     // In-place modification

// For all spans
constexpr auto trim_prefix(size_type n) const; // Returns new view
constexpr auto trim_suffix(size_type n) const; // Returns new view
```

### Benefits of Alternative 2

- **Clear semantic distinction**: Different names indicate different behaviors
- **Universal availability**: All spans get view-returning functions
- **No semantic confusion**: Each function name has consistent meaning
- **Explicit choice**: Developers can choose modification vs. creation

### Drawbacks of Alternative 2

- **Interface proliferation**: Doubles the number of functions for similar operations
- **Cognitive overhead**: Users must learn and remember multiple function names for similar concepts
- **Inconsistency with existing patterns**: Standard library doesn't typically provide both
  modification and creation versions with different names
- **Generic programming complexity**: Templates need to handle multiple function names
- **Teaching burden**: More complex mental model for users

### Example Complexity

```cpp
template<typename View>
void trim_edges(View& view) {
    if constexpr (requires { view.remove_prefix(1); }) {
        view.remove_prefix(1);  // Modify in-place
        view.remove_suffix(1);
    } else {
        view = view.trim_prefix(1);  // Different function name!
        view = view.trim_suffix(1);
    }
}
```

## Alternative 2.5: Add trim_prefix/trim_suffix to string_view

### Approach for Alternative 2.5

```cpp
// Add to std::string_view
constexpr string_view trim_prefix(size_type n) const;  // Returns new view
constexpr string_view trim_suffix(size_type n) const;  // Returns new view

// For all spans (existing functionality)
constexpr auto trim_prefix(size_type n) const;  // Returns new view  
constexpr auto trim_suffix(size_type n) const;  // Returns new view
```

This would maintain complete interface consistency by providing view-returning functions  
across both types while keeping the in-place modification functions  
(`remove_prefix`/`remove_suffix`) available where semantically appropriate.

### Benefits of Alternative 2.5

- **Complete interface symmetry**: Both types would have identical function names for  
  view-returning operations
- **Clear semantic distinction**: `trim_*` returns new views, `remove_*` modifies in-place
- **Universal availability**: All view types support the same operations
- **No generic programming complications**: Templates can always use `trim_*` functions

### Drawbacks of Alternative 2.5

- **Interface expansion**: Adds more functions to `string_view`
- **Potential confusion**: Two ways to achieve similar results (`sv.trim_prefix(n)` vs  
  `sv.substr(n)`)
- **Inconsistent with current standard library patterns**: `string_view` currently uses  
  `substr` for view creation
- **Limited additional value**: `trim_prefix(n)` is essentially equivalent to `substr(n)`  
  and `trim_suffix(n)` to `substr(0, size() - n)`

### Example Usage

```cpp
template<typename View>
auto get_middle_part(const View& view) {
    // Works universally - always returns a new view
    return view.trim_prefix(1).trim_suffix(1);
}
```

*Note*: While this alternative would provide complete interface symmetry, the `trim_*` functions  
can always be added in a future proposal if deemed valuable after gaining experience with the  
core unified interface.

## Alternative 3: Only Provide for Dynamic Spans (Chosen)

### Approach for Alternative 3

```cpp
// Only available for span<T, dynamic_extent>
constexpr void remove_prefix(size_type n);     // Modifies in-place
constexpr void remove_suffix(size_type n);     // Modifies in-place
```

### Benefits of Alternative 3

- **Semantic consistency**: `remove_prefix`/`remove_suffix` always mean "modify in-place" across
  all types
- **Clear error messages**: Attempting to use on fixed spans produces clear compilation errors
- **Minimal interface**: No function proliferation or naming complexity
- **Existing pattern**: Standard library already has type-specific member functions (e.g.,
  `vector::push_back` not available for arrays)
- **Future-proof**: Doesn't preclude future additions if a compelling use case emerges

### Drawbacks of Alternative 3

- **Limited span compatibility**: Fixed spans cannot use these specific function names
- **Requires generic programming techniques**: Templates need `requires` expressions or SFINAE for
  fallbacks
- **Initial learning curve**: Users must understand which spans support which operations

### Generic Programming Solution

```cpp
template<typename View>
void trim_edges(View& view) {
    if constexpr (requires { view.remove_prefix(1); }) {
        // Works for string_view and dynamic span
        view.remove_prefix(1);
        view.remove_suffix(1);
    } else {
        // Clear fallback for fixed span
        view = view.subspan(1, view.size() - 2);
    }
}
```

## Decision Rationale

We chose **Alternative 3** (only dynamic spans) for the following reasons:

### 1. Semantic Consistency is Paramount

The most important principle is that identical function names should have identical semantics across
the standard library. Having `remove_prefix` mean "modify in-place" for `string_view` but
"return new view" for `span` would violate this fundamental design principle.

### 2. Clear Compilation Errors Over Silent Differences

It's better to get a clear compilation error when trying to use `remove_prefix` on a fixed span than
to have the same code work but behave differently for different types.

### 3. Follows Established Patterns

The standard library already has extent-specific operations for the same class template:

- `std::span<T, N>::subspan<Count, Offset>()` - compile-time version only available for  
  fixed-extent spans
- `std::array<T, N>::fill()` - available for `std::array` but not for generic containers  
  that might have different capabilities
- Template specializations often have different interfaces based on their template parameters  
  (e.g., `std::vector<bool>` vs `std::vector<T>`)

This follows the principle that member function availability should match the type's semantic  
capabilities.

### 4. Enables Clean Generic Programming

Modern C++ provides excellent tools (`requires` expressions, concepts) for handling type-specific
capabilities in generic code, making this a manageable constraint.

### 5. Preserves Interface Simplicity

Avoiding function name proliferation keeps the interface clean and teachable.

## NTTP Overloads Not Included

We also considered adding non-type template parameter (NTTP) overloads to `std::string_view`:

- `template<size_t N> constexpr string_view first() const`
- `template<size_t N> constexpr string_view last() const`  
- `template<size_t N> constexpr string_view substr() const`

However, we decided against including these for several reasons:

1. **Core goal achieved without them**: The primary objective of interface unification is  
   accomplished by the runtime functions alone
2. **Limited practical benefit for `string_view`**: Unlike `span<T, N>`, `string_view` is  
   always runtime-sized, so NTTP overloads don't provide compile-time bounds checking
3. **Scope creep**: Adding NTTP overloads expands the proposal beyond the essential  
   unification goal
4. **Future compatibility**: These can be added later if compelling use cases emerge,  
   without breaking changes

## Generic Programming with Mixed Span Types

The chosen approach enables clean generic programming patterns:

```cpp
template<typename View>
void trim_prefix(View& view, size_t n) {
    if constexpr (requires { view.remove_prefix(n); }) {
        // Works for string_view and dynamic span
        view.remove_prefix(n);
    } else {
        // Fallback for fixed span - reassignment
        view = view.subspan(n);
    }
}

// For cases where you know the view supports modification:
template<typename ModifiableView>
  requires requires(ModifiableView& v) { v.remove_prefix(1); }
void trim_prefix_simple(ModifiableView& view) {
    view.remove_prefix(1);  // Always modifies in-place
}
```

This approach provides:

- **Clear semantics**: Same function name always means same behavior
- **Compile-time safety**: Inappropriate usage results in clear compilation errors  
- **Generic programming support**: `requires` expressions enable appropriate fallbacks
- **Self-documenting code**: Function availability indicates capability

## Semantics and Exception Safety

The new functions follow the same semantics and exception guarantees as their existing
counterparts:

- **`string_view::first/last`**: Same behavior as `span::first/last`
- **`span::remove_prefix/remove_suffix`**: Same behavior as `string_view::remove_prefix/remove_suffix`
- **Preconditions**: `n <= size()` for all functions
- **Exception safety**: `noexcept` specification matches existing patterns

## Naming Consistency

We maintain existing naming conventions:

- `first`/`last` return new views (following `span` convention)
- `remove_prefix`/`remove_suffix` modify the current view (following `string_view` convention)

## Performance Considerations

The new functions are implemented as simple forwarding operations with no performance overhead:

```cpp
// string_view::first implementation
constexpr string_view first(size_type n) const {
    return substr(0, n);
}

// span::remove_prefix implementation  
constexpr void remove_prefix(size_type n) {
    *this = subspan(n);
}
```


# Implementation Experience

Several implementations have been prototyped, confirming:

1. **Trivial implementation complexity** - each function is a simple one-liner
2. **Zero performance overhead** - optimizes to identical assembly
3. **No ABI impact** - new functions don't affect existing symbols
4. **High user satisfaction** - dramatically improves generic programming experience


# Wording

The proposed changes are relative to [@!N5008].

## Additions to [string.view.syn]

```diff
namespace std {
  template<class charT, class traits = char_traits<charT>>
  class basic_string_view {
    // ...
    constexpr basic_string_view substr(size_type pos = 0, size_type n = npos) const;
+   constexpr basic_string_view first(size_type n) const;
+   constexpr basic_string_view last(size_type n) const;
    
    constexpr void remove_prefix(size_type n);
    constexpr void remove_suffix(size_type n);
    // ...
  };
}
```

## Additions to [span.syn]

```diff
namespace std {
  template<class ElementType, size_t Extent = dynamic_extent>
  class span {
    // ...
    template<size_t Count> constexpr span<element_type, Count> first() const;
    constexpr span<element_type, dynamic_extent> first(size_type count) const;
    template<size_t Count> constexpr span<element_type, Count> last() const;
    constexpr span<element_type, dynamic_extent> last(size_type count) const;
    // ...
  };
  
+ // Additional members for dynamic extent spans only
+ template<class ElementType>
+ class span<ElementType, dynamic_extent> {
+   // ... (all existing members)
+   constexpr void remove_prefix(size_type n);
+   constexpr void remove_suffix(size_type n);
+ };
}
```

## Function Specifications

### [string.view.ops] Additions

```diff
+constexpr basic_string_view first(size_type n) const;
```

*Preconditions*: `n <= size()`.

*Returns*: `substr(0, n)`.

```diff
+constexpr basic_string_view last(size_type n) const;
```

*Preconditions*: `n <= size()`.

*Returns*: `substr(size() - n, n)`.

### [span.elem] Additions (Dynamic Extent Only)

*Note*: The following member functions are only available for `span<ElementType, dynamic_extent>`.

```diff
+constexpr void remove_prefix(size_type n);
```

*Preconditions*: `n <= size()`.

*Effects*: Equivalent to: `*this = subspan(n);`.

```diff
+constexpr void remove_suffix(size_type n);
```

*Preconditions*: `n <= size()`.

*Effects*: Equivalent to: `*this = subspan(0, size() - n);`.

## Feature test macro

Add the following feature test macro to [version.syn]:

```diff
+#define __cpp_lib_unified_span_string_view 202509L // also in <span> and <string_view>
```


# Future Considerations

This proposal lays the groundwork for:

1. **Enhanced generic algorithms** in the standard library
2. **Simplified range adaptors** that work uniformly with both types
3. **Potential concept definitions** for view-like types
4. **Teaching materials** that can present a unified mental model

The unified interface also enables future proposals for:

- Generic view manipulation algorithms
- Unified formatting support
- Enhanced debugging and introspection capabilities


# Acknowledgements

Special thanks and recognition goes to [The C++ Alliance](https://cppalliance.org) for supporting
Mateusz's membership in the ISO C++ Committee and the production of this proposal.

Additional thanks to the C++ community for feedback on interface consistency issues and
generic programming challenges with the current standard library.

---
references:

- id: N5008
  citation-label: N5008
  title: "Working Draft, Standard for Programming Language C++"
  author:
    - family: Smith
      given: Richard
  URL: <https://wg21.link/n5008>

---
