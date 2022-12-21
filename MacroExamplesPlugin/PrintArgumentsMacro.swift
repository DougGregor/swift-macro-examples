//
//  PrintArgumentsMacro.swift
//  MacroExamplesPlugin
//
//  Created by Stephen Kockentiedt on 18.12.22.
//

import SwiftSyntax
import SwiftSyntaxBuilder
import _SwiftSyntaxMacros

public struct PrintArgumentsMacro: ExpressionMacro {
    public static func expansion(
        of node: MacroExpansionExprSyntax, in context: inout MacroExpansionContext
    ) -> ExprSyntax {
        var syntax = node.as(Syntax.self)
        while syntax != nil && syntax!.as(FunctionDeclSyntax.self) == nil {
            syntax = syntax!.parent
        }
        
        guard let functionSyntax = syntax!.as(FunctionDeclSyntax.self) else { return "" }
        let signature: FunctionSignatureSyntax = functionSyntax.signature
        let parameterList = signature.input.parameterList
        
        // For a function `doSomething(_ a: Int, b: String, c: Double)`, the expanded epression shall be `print("doSomething(\(a), b: \(b), c: \(c))")`
        
        let parameters = parameterList.map { parameter -> String in
            let potentialLabel = parameter.firstName!.withoutTrivia().description
            let label = potentialLabel == "_" ? nil : potentialLabel
            let potentialName = parameter.secondName?.withoutTrivia().description ?? potentialLabel
            let name = potentialName == "_" ? nil : potentialName
            var string: String
            if let label {
                string = "\(label): "
            } else {
                string = ""
            }
            if let name {
                string += "\\(\(name))"
            } else {
                string += "_"
            }
            return string
        }
        let parametersString = parameters.joined(separator: ", ")
        
        return "print(\"\(raw: functionSyntax.identifier.description)(\(raw: parametersString))\")"
    }
}
