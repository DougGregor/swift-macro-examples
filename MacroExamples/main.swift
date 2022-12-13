//
//  main.swift
//  MacroExamples
//
//  Created by Doug Gregor on 12/12/22.
//

macro stringify<T>(_ value: T) -> (T, String) = MacroExamplesPlugin.StringifyMacro

let x = 1
let y = 2
print(#stringify(x + y))
