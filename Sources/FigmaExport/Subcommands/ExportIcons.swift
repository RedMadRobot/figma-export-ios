import Foundation
import ArgumentParser
import FigmaAPI
import XcodeExport
import FigmaExportCore
import AndroidExport
import Logging

extension FigmaExportCommand {
    
    struct ExportIcons: ParsableCommand {
        
        static let configuration = CommandConfiguration(
            commandName: "icons",
            abstract: "Exports icons from Figma",
            discussion: "Exports icons from Figma to Xcode / Android Studio project")
        
        @OptionGroup
        var options: FigmaExportOptions
        
        @Argument(help: """
        [Optional] Name of the icons to export. For example \"ic/24/edit\" \
        to export single icon, \"ic/24/edit, ic/16/notification\" to export several icons and \
        \"ic/16/*\" to export all icons of size 16 pt
        """)
        var filter: String?
        
        func run() throws {
            let logger = Logger(label: "com.redmadrobot.figma-export")
            let client = FigmaClient(accessToken: options.accessToken, timeout: options.params.figma.timeout)
            
            if options.params.ios != nil {
                logger.info("Using FigmaExport \(FigmaExportCommand.version) to export icons to Xcode project.")
                try exportiOSIcons(client: client, params: options.params, logger: logger)
            }
            
            if options.params.android != nil {
                logger.info("Using FigmaExport \(FigmaExportCommand.version) to export icons to Android Studio project.")
                try exportAndroidIcons(client: client, params: options.params, logger: logger)
            }
        }
        
        private func exportiOSIcons(client: Client, params: Params, logger: Logger) throws {
            guard let ios = params.ios,
                  let iconsParams = ios.icons else {
                logger.info("Nothing to do. You haven’t specified ios.icons parameters in the config file.")
                return
            }

            logger.info("Fetching icons info from Figma. Please wait...")
            let loader = ImagesLoader(client: client, params: params, platform: .ios, logger: logger)
            let imagesTuple = try loader.loadIcons(filter: filter)

            logger.info("Processing icons...")
            let processor = ImagesProcessor(
                platform: .ios,
                nameValidateRegexp: params.common?.icons?.nameValidateRegexp,
                nameReplaceRegexp: params.common?.icons?.nameReplaceRegexp,
                nameStyle: iconsParams.nameStyle
            )

            let icons = processor.process(light: imagesTuple.light, dark: imagesTuple.dark)

            let assetsURL = ios.xcassetsPath.appendingPathComponent(iconsParams.assetsFolder)

            let output = XcodeImagesOutput(
                assetsFolderURL: assetsURL,
                assetsInMainBundle: ios.xcassetsInMainBundle,
                assetsInSwiftPackage: ios.xcassetsInSwiftPackage,
                addObjcAttribute: ios.addObjcAttribute,
                preservesVectorRepresentation: iconsParams.preservesVectorRepresentation,
                uiKitImageExtensionURL: iconsParams.imageSwift,
                swiftUIImageExtensionURL: iconsParams.swiftUIImageSwift,
                renderMode: iconsParams.renderMode)
            
            let exporter = XcodeIconsExporter(output: output)
            let localAndRemoteFiles = try exporter.export(icons: icons.get(), append: filter != nil)
            if filter == nil {
                try? FileManager.default.removeItem(atPath: assetsURL.path)
            }

            logger.info("Downloading remote files...")
            let localFiles = try fileDownloader.fetch(files: localAndRemoteFiles)

            logger.info("Writting files to Xcode project...")
            try fileWritter.write(files: localFiles)

            do {
                let xcodeProject = try XcodeProjectWritter(xcodeProjPath: ios.xcodeprojPath, target: ios.target)
                try localFiles.forEach { file in
                    if file.destination.file.pathExtension == "swift" {
                        try xcodeProject.addFileReferenceToXcodeProj(file.destination.url)
                    }
                }
                try xcodeProject.save()
            } catch {
                logger.error("Unable to add some file references to Xcode project")
            }
            
            checkForUpdate(logger: logger)
            
            logger.info("Done!")
        }
        
        private func exportAndroidIcons(client: Client, params: Params, logger: Logger) throws {
            guard let android = params.android, let androidIcons = android.icons else {
                logger.info("Nothing to do. You haven’t specified android.icons parameter in the config file.")
                return
            }
            
            // 1. Get Icons info
            logger.info("Fetching icons info from Figma. Please wait...")
            let loader = ImagesLoader(client: client, params: params, platform: .android, logger: logger)
            let imagesTuple = try loader.loadIcons(filter: filter)

            // 2. Proccess images
            logger.info("Processing icons...")
            let processor = ImagesProcessor(
                platform: .android,
                nameValidateRegexp: params.common?.icons?.nameValidateRegexp,
                nameReplaceRegexp: params.common?.icons?.nameReplaceRegexp,
                nameStyle: .snakeCase
            )

            let icons = try processor.process(light: imagesTuple.light, dark: imagesTuple.dark).get()
            
            // Create empty temp directory
            let tempDirectoryLightURL = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
            let tempDirectoryDarkURL = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        
            // 3. Download SVG files to user's temp directory
            logger.info("Downloading remote files...")
            let remoteFiles = icons.flatMap { asset -> [FileContents] in
                let lightFiles = asset.light.images.map { image -> FileContents in
                    let fileURL = URL(string: "\(image.name).svg")!
                    let dest = Destination(directory: tempDirectoryLightURL, file: fileURL)
                    return FileContents(destination: dest, sourceURL: image.url)
                }
                let darkFiles = asset.dark?.images.map { image -> FileContents in
                    let fileURL = URL(string: "\(image.name).svg")!
                    let dest = Destination(directory: tempDirectoryDarkURL, file: fileURL)
                    return FileContents(destination: dest, sourceURL: image.url, dark: true)
                } ?? []
                return lightFiles + darkFiles
            }

            var localFiles = try fileDownloader.fetch(files: remoteFiles)
            
            // 4. Move downloaded SVG files to new empty temp directory
            try fileWritter.write(files: localFiles)
            
            // 5. Convert all SVG to XML files
            logger.info("Converting SVGs to XMLs...")
            try svgFileConverter.convert(inputDirectoryUrl: tempDirectoryLightURL)
            logger.info("Converting dark SVGs to XMLs...")
            try svgFileConverter.convert(inputDirectoryUrl: tempDirectoryDarkURL)
            
            // Create output directory main/res/custom-directory/drawable/
            let lightDirectory = URL(fileURLWithPath: android.mainRes
                .appendingPathComponent(androidIcons.output)
                .appendingPathComponent("drawable", isDirectory: true).path)

            let darkDirectory = URL(fileURLWithPath: android.mainRes
                .appendingPathComponent(androidIcons.output)
                .appendingPathComponent("drawable-night", isDirectory: true).path)
            
            if filter == nil {
                // Clear output directory
                try? FileManager.default.removeItem(atPath: lightDirectory.path)
                try? FileManager.default.removeItem(atPath: darkDirectory.path)
            }
            
            // 6. Move XML files to main/res/drawable/
            localFiles = localFiles.map { fileContents -> FileContents in
                
                let source = fileContents.destination.url
                    .deletingPathExtension()
                    .appendingPathExtension("xml")
                
                let fileURL = fileContents.destination.file
                    .deletingPathExtension()
                    .appendingPathExtension("xml")

                let directory = fileContents.dark ? darkDirectory : lightDirectory
                return FileContents(
                    destination: Destination(directory: directory, file: fileURL),
                    dataFile: source
                )
            }

            logger.info("Writing files to Android Studio project...")
            try fileWritter.write(files: localFiles)

            logger.info("Remove temp directory...")
            try? FileManager.default.removeItem(at: tempDirectoryLightURL)
            try? FileManager.default.removeItem(at: tempDirectoryDarkURL)

            checkForUpdate(logger: logger)
            
            logger.info("Done!")
        }
    }
}
