import Foundation
import FigmaExportCore
import Stencil
import PathKit

final public class XcodeColorExporter: XcodeExporterBase {

    private let output: XcodeColorsOutput

    public init(output: XcodeColorsOutput) {
        self.output = output
    }

    public func export(colorPairs: [AssetPair<Color>]) throws -> [FileContents] {
        var files: [FileContents] = []

        // UIKit UIColor extension
        if let fileContents = try makeUIColorExtensionFileContents(for: colorPairs) {
            files.append(fileContents)
        }

        // SwiftUI Color extension
        if let fileContents = try makeColorExtensionFileContents(for: colorPairs) {
            files.append(fileContents)
        }

        guard let assetCatalogURL = output.assetsColorsURL else { return files }

        // Assets.xcassets/Colors/Contents.json
        files.append(makeXcodeEmptyFileContents(directoryURL: assetCatalogURL))

        // Assets.xcassets/Colors/***.colorset/Contents.json
        files.append(contentsOf: try makeAssets(for: colorPairs, assetCatalogURL: assetCatalogURL))

        return files
    }

    private func makeUIColorExtensionFileContents(for colorPairs: [AssetPair<Color>]) throws -> FileContents? {
        guard let colorSwiftURL = output.colorSwiftURL else { return nil }

        let contents = try makeUIColorExtensionContents(colorPairs)
        return try makeFileContents(for: contents, url: colorSwiftURL)
    }

    private func makeColorExtensionFileContents(for colorPairs: [AssetPair<Color>]) throws -> FileContents? {
        guard let swiftuiColorSwiftURL = output.swiftuiColorSwiftURL else { return nil }

        let contents = try makeColorExtensionContents(colorPairs)
        return try makeFileContents(for: contents, url: swiftuiColorSwiftURL)
    }

    private func makeColorExtensionContents(_ colorPairs: [AssetPair<Color>]) throws -> String {
        let colors: [[String: Any]] = colorPairs.map { colorPair in
            [
                "name": normalizeName(colorPair.light.name),
                "originalName": colorPair.light.originalName
            ]
        }

        let context: [String: Any] = [
            "assetsInSwiftPackage": output.assetsInSwiftPackage,
            "assetsInMainBundle": output.assetsInMainBundle,
            "useNamespace": output.groupUsingNamespace,
            "colors": colors,
        ]

        let env = makeEnvironment(trimBehavior: .smart)
        return try env.renderTemplate(name: "Color+extension.swift.stencil", context: context)
    }

    private func makeUIColorExtensionContents(_ colorPairs: [AssetPair<Color>]) throws -> String {
        let useAssets = output.assetsColorsURL != nil
        let colors: [[String: Any]] = colorPairs.map { colorPair in
            let name = normalizeName(colorPair.light.name)

            var obj: [String: Any] = [:]
            obj["name"] = name
            obj["originalName"] = colorPair.light.originalName

            if !useAssets {
                let lightComponents = colorPair.light.toRgbComponents()

                if let darkComponents = colorPair.dark?.toRgbComponents() {
                    obj["light"] = [
                        "name": name,
                        "red": lightComponents.red,
                        "green": lightComponents.green,
                        "blue": lightComponents.blue,
                        "alpha": lightComponents.alpha
                    ]
                    obj["dark"] = [
                        "name": name,
                        "red": darkComponents.red,
                        "green": darkComponents.green,
                        "blue": darkComponents.blue,
                        "alpha": darkComponents.alpha
                    ]
                    obj["hasDarkVariant"] = true
                } else {
                    obj["hasDarkVariant"] = false
                    obj["red"] = lightComponents.red
                    obj["green"] = lightComponents.green
                    obj["blue"] = lightComponents.blue
                    obj["alpha"] = lightComponents.alpha
                }
            }
            return obj
        }

        let context: [String: Any] = [
            "assetsInSwiftPackage": output.assetsInSwiftPackage,
            "addObjcPrefix": output.addObjcAttribute,
            "colorFromAssetCatalog": useAssets,
            "assetsInMainBundle": output.assetsInMainBundle,
            "useNamespace": output.groupUsingNamespace,
            "colors": colors,
        ]
        
        let env = makeEnvironment(trimBehavior: TrimBehavior(leading: .none, trailing: .whitespaceAndOneNewLine))
        return try env.renderTemplate(name: "UIColor+extension.swift.stencil", context: context)
    }
    
    private func makeEnvironment(trimBehavior: TrimBehavior) -> Environment {
        let loader: FileSystemLoader
        if let templateURL = output.templatesPath {
            loader = FileSystemLoader(paths: [Path(templateURL.path)])
        } else {
            loader = FileSystemLoader(paths: [Path(Bundle.module.resourcePath! + "/Resources")])
        }
        var environment = Environment(loader: loader)
        environment.trimBehavior = trimBehavior
        return environment
    }

    private func makeFileContents(for string: String, url: URL) throws -> FileContents? {
        let fileURL = URL(string: url.lastPathComponent)!
        let directoryURL = url.deletingLastPathComponent()

        return FileContents(
            destination: Destination(directory: directoryURL, file: fileURL),
            data: string.data(using: .utf8)!
        )
    }

    private func makeXcodeEmptyFileContents(directoryURL: URL) -> FileContents {
        let contentsJson = XcodeEmptyContents()
        return FileContents(
            destination: Destination(directory: directoryURL, file: contentsJson.fileURL),
            data: contentsJson.data
        )
    }

    private func makeAssets(for colorPairs: [AssetPair<Color>], assetCatalogURL: URL) throws -> [FileContents] {
        try colorPairs.flatMap { colorPair -> [FileContents] in
            var files = [FileContents]()

            var name = colorPair.light.name
            var assetsColorsURL = assetCatalogURL

            if output.groupUsingNamespace,
               let lastName = colorPair.light.originalName.split(separator: "/").last {
                name = String(lastName)

                colorPair.light.originalName.split(separator: "/")
                    .dropLast()
                    .map { String($0) }
                    .forEach {
                        assetsColorsURL.appendPathComponent($0, isDirectory: true)

                        let contentsJson = XcodeFolderNamespaceContents()
                        files.append(FileContents(
                            destination: Destination(directory: assetsColorsURL, file: contentsJson.fileURL),
                            data: contentsJson.data
                        ))
                    }
            }

            let dirURL = assetsColorsURL.appendingPathComponent("\(name).colorset")

            var colors: [XcodeAssetContents.ColorData] = [
                XcodeAssetContents.ColorData(
                    appearances: nil,
                    color: XcodeAssetContents.ColorInfo(
                        components: colorPair.light.toHexComponents())
                )
            ]
            if let darkColor = colorPair.dark {
                colors.append(
                    XcodeAssetContents.ColorData(
                        appearances: [XcodeAssetContents.DarkAppearance()],
                        color: XcodeAssetContents.ColorInfo(
                            components: darkColor.toHexComponents())
                    )
                )
            }

            // Contents.json
            files.append(
                try makeXcodeAssetFileContents(contents: XcodeAssetContents(colors: colors), directory: dirURL)
            )
            return files
        }
    }

    private func makeXcodeAssetFileContents(contents: XcodeAssetContents, directory: URL) throws -> FileContents {
        let encoder = JSONEncoder()
        encoder.outputFormatting = .prettyPrinted
        let data = try encoder.encode(contents)
        let fileURL = URL(string: "Contents.json")!
        return FileContents(
            destination: Destination(directory: directory, file: fileURL),
            data: data
        )
    }
}

private extension Color {

    func toHexComponents() -> XcodeAssetContents.Components {
        let red = "0x\(doubleToHex(red))"
        let green = "0x\(doubleToHex(green))"
        let blue = "0x\(doubleToHex(blue))"
        let alpha = String(format: "%.3F", arguments: [alpha])
        return XcodeAssetContents.Components(red: red, alpha: alpha, green: green, blue: blue)
    }

    func doubleToHex(_ double: Double) -> String {
        String(format: "%02X", arguments: [Int((double * 255).rounded())])
    }

    func toRgbComponents() -> XcodeAssetContents.Components {
        let red = String(format: "%.3F", arguments: [red])
        let green = String(format: "%.3F", arguments: [green])
        let blue = String(format: "%.3F", arguments: [blue])
        let alpha = String(format: "%.3F", arguments: [alpha])
        return XcodeAssetContents.Components(red: red, alpha: alpha, green: green, blue: blue)
    }
}
