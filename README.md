# Swift Macro Examples



There is an active effort to introduce [macros](https://forums.swift.org/t/a-possible-vision-for-macros-in-swift/60900) into the Swift programming language. This repository includes some example macros that can be used to explore the macro proposals and experiment with the current implementation of the feature. 

## Getting started

Macros are an experimental feature, so you will need a custom Swift toolchain and some extra compiler flags. The Xcode project in this repository is a good starting point. To use it:

1. Download a [development snapshot](https://www.swift.org/download/#snapshots) of the compiler from Swift.org from December 15, 2022 or later. At present, we only have these working on macOS, but are working to get other platforms working with other build systems.
2. Open the project `MacroExamples.xcodeproj` in Xcode.
3. Go to the Xcode -> Toolchains menu and select the development toolchain you downloaded.
4. Make sure the `MacroExamples` scheme is selected, then build and run!

The output of the `MacroExamples` program is pretty simple: it shows the result of running the example macro(s).

## Adding your own macro

This examples package is meant to grow to include additional macros that have interesting behavior. To add a macro requires both *declaring* the macro and also *implementing* the macro, which happen in separate targets:

* **Implementation**: a macro is defined in the `MacroExamplesPlugin` target, by creating a new `public struct` type that implements one of the macro protocols. The `stringify` macro implements the `ExpressionMacro` protocol, e.g.,

  ```swift
  public struct StringifyMacro: ExpressionMacro { ... }
  ```

  To test a macro implementation, introduce new tests into the `MacroExamplesPluginTest` target. These tests start with source code (like `#stringify(x + y)`) and will run the macro implementation to produce new source code. The translation can make use of the [swift-syntax](https://github.com/apple/swift-syntax) package, a copy of which is included in the toolchain. We recommend implementing and testing your macro this way first so you know it does the source translation you want.

* **Declaration**: a macro is declared in the `MacroExamplesLib` target, using the `macro` introducer. For example, the simple `stringify` macro is declared like this:

  ```swift
  public macro stringify<T>(_ value: T) -> (T, String) = MacroExamplesPlugin.StringifyMacro
  ```

  The name after `macro` is the name to be used in source code, whereas the name after the `=` is the module and type name for your macro implementation. If you haven't implemented that type, or get the name wrong, you will get a compiler warning.

Once you have both a declaration and an implementation, it's time to use your macro! Go back to `MacroExamples` and write some code there to exercise your macro however you want.

## Macros proposals

The introduction of macros into Swift will involve a number of different proposals. Here 

* [Expression macros](https://forums.swift.org/t/pitch-2-expression-macros/61861): Introduces the ability to add macros that transform expressions into other expressions.

