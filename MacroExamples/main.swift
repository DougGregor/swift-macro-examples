
import MacroExamplesLib

let x = 1
let y = 2
let z = 3

// "Stringify" macro turns the expression into a string.
print(#stringify(x + y))

// "AddBlocker" complains about addition operations. We emit a warning
// so it doesn't block compilation.
print(#addBlocker(x * y + z))

#myWarning("remember to pass a string literal here")

// Uncomment to get an error out of the macro.
//   let text = "oops"
//   #myWarning(text)


struct Font: ExpressibleByFontLiteral {
  init(fontLiteralName: String, size: Int, weight: MacroExamplesLib.FontWeight) {
  }
}

let font: Font = #fontLiteral(name: "Comic Sans", size: 14, weight: .thin)

func doSomething(_ a: Int, b: Int, c d: Int, e _: Int, _: Int, _ _: Int) {
    #printArguments()
}

// Prints doSomething(42, b: 256, c: 512, e: _, _, _)
doSomething(42, b: 256, c: 512, e: 600, 1024, 2048)
