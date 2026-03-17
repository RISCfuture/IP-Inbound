## Localization & Strings

- All user-facing text should be localized with String(localized:) unless passed directly to a SwiftUI view like Text().
- When interpolating values like numbers and dates, use FormatStyle, like "Expires in \(days, format: .number) days."
- Use curly-quotes in user-facing strings.

## Formatting & Linting

- Format all changes with swift format, and verify all changes with swiftlint.
- Adhere to Swiftlint's `type_contents_order` setting:

``` yaml
type_contents_order:
  order:
    [
      [type_alias, associated_type],
      [case],
      [type_property],
      [instance_property],
      [ib_inspectable],
      [ib_outlet],
      [initializer],
      [type_method],
      [view_life_cycle_method],
      [ib_action, ib_segue_action],
      [other_method],
      [subscript],
      [deinitializer],
      [subtype],
    ]
```

- When defining groups of related variables or constants, use the compound `let` or `var` syntax.
- When using `guard let` or `if let` to assert non-nil, shadow the variable name (use `if let foo`, not `if let bar = foo`, not `if let foo = foo`).

## Naming Conventions

- Capitalize all acronyms unless they conflict with a type name (e.g. "convertToKIAS`).
- Consecutive capitalized acronyms should be separated by an underscore (e.g., `IAS_KPH`). Do not use an underscore except to separate two acronyms (e.g., not for `IASKts`).
- Do not abbreviate words unless it definitely enhances readability (e.g., do not use "seg" for "segment", but "TAS" for "trueAirspeed" is sometimes OK). Long variable names are acceptable if it enhances understanding.

## Documentation & Comments

- Swift-DocC comments are only necessary for public/package types and members.
- Favor smaller functions with self-documenting names over comments to explain longer code blocks.
- Do not use comments to explain changes in code (e.g., "this used to be like this; now it's like that"). Comments should only be used to help the reader understand the state of the code as it currently is, not how it was.

## Code Structure

- Complex functions should be orchestrators that call out to smaller functions.
- Avoid magic numbers; define private static constants.
- For larger types, use extensions to group related computed vars, functions, etc. into "functionality clusters".

## Concurrency

- Use Swift 6 concurrency wherever appropriate: move related into TaskGroups; use actors when access synchronization is appropriate, etc.
- Avoid using `nonisolated(unsafe)` and `@unchecked Sendable` except in situations where it is unavoidable (e.g., working with pre-concurrency libraries that cannot be imported with `@preconcurrency import`).

## Units & Measurements

- When working with dimensional values, use Measurement for front-end display and manipulation. For low-level calculations, primitives are OK.
- Suffix any dimensional primitives or functions with the abbreviated units (e.g., `timeMin` or `distanceNM`).

## SwiftUI Views

- This app uses icons sparingly. Do not use icons for every label; only when it enhances readability or as a shorthand for a text label. Icons or images without labels should have their accessibility label set.
- This app uses colors sparingly. Use bright colors only when it clearly enhances readability. Use basic shades for information hierarchy.
- Prefer the default padding and spacing values unless more or less padding/spacing is required to set up a proper visual flow.
- When working with complex views, prefer making subviews over vars or functions that return views. Non-trivial subviews should be in their own file.
- Prefer using a `Label` view over an `HStack` with an `Image` and `Text`.
- All views should have `#Preview` blocks covering major view modes. Use `PreviewHelper` to inject data into this previews.

## Testing

- Major functionality should have unit tests. Major user flows should have UI tests.
- Unit tests are written using Swift Testing. Use `#expect` for assertions and `#require` to verify non-null.
- Do not write trivial or tautological unit tests that verify simple and obviously correct logic.

## Errors

- Create a protocol that inherits Error for each general category of errors.
- Errors should implement `LocalizedError`. `errorDescription` should be a general description of the error category, and typically is the same for all error cases (e.g., "Couldn’t download file."). `failureReason` should contain specific error details and interpolate occurrence-specific information (e.g., "Received HTTP error %lld when trying to download."). `recoverySuggestion` should only be provided if the error is user-actionable.
- Use `fatalError` or `preconditionFailure` for errors that should never happen.

# Output

- Use xcbeautify to reduce the context load of build and test runs.
- Use xclogparser and xcresultparser to efficiently parse Xcode output.
