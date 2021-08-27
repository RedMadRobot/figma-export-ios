import Foundation
import FigmaAPI
import FigmaExportCore
import Logging

final class ImagesLoader {

    let client: Client
    let params: Params
    let platform: Platform

    private var iconsFrameName: String {
        params.common?.icons?.figmaFrameName ?? "Icons"
    }

    private var imagesFrameName: String {
        params.common?.images?.figmaFrameName ?? "Illustrations"
    }
    
    private let logger: Logger

    init(client: Client, params: Params, platform: Platform, logger: Logger) {
        self.client = client
        self.params = params
        self.platform = platform
        self.logger = logger
    }

    func loadIcons(filter: String? = nil) throws -> (light: [ImagePack], dark: [ImagePack]?) {
        if let useSingleFile = params.common?.icons?.useSingleFile, useSingleFile {
            return try loadIconsFromSingleFile(filter: filter)
        } else {
            return try loadIconsFromLightAndDarkFile(filter: filter)
        }
    }

    private func loadIconsFromSingleFile(filter: String? = nil) throws -> (light: [ImagePack], dark: [ImagePack]?) {
        let formatParams: FormatParams
        switch (platform, params.ios?.icons?.format) {
        case (.android, _),
             (.ios, .svg):
            formatParams = SVGParams()
        case (.ios, _):
            formatParams = PDFParams()
        }

        let icons = try _loadImages(
            fileId: params.figma.lightFileId,
            frameName: iconsFrameName,
            params: formatParams,
            filter: filter
        )
        let darkSuffix = params.common?.icons?.darkModeSuffix ?? "_dark"
        let lightIcons = icons
            .filter { !$0.name.hasSuffix(darkSuffix) }
        let darkIcons = icons
            .filter { $0.name.hasSuffix(darkSuffix) }
            .map { icon -> ImagePack in
                var newIcon = icon
                newIcon.name = String(icon.name.dropLast(darkSuffix.count))
                return newIcon
            }
        return (lightIcons, darkIcons)
    }

    private func loadIconsFromLightAndDarkFile(filter: String? = nil) throws -> (light: [ImagePack], dark: [ImagePack]?) {
        let formatParams: FormatParams
        switch (platform, params.ios?.icons?.format) {
        case (.android, _),
             (.ios, .svg):
            formatParams = SVGParams()
        case (.ios, _):
            formatParams = PDFParams()
        }

        let lightIcons = try _loadImages(
            fileId: params.figma.lightFileId,
            frameName: iconsFrameName,
            params: formatParams,
            filter: filter
        )
        let darkIcons = try params.figma.darkFileId.map {
            try _loadImages(
                fileId: $0,
                frameName: iconsFrameName,
                params: formatParams,
                filter: filter)
        }
        return (lightIcons, darkIcons)
    }

    func loadImages(filter: String? = nil) throws -> (light: [ImagePack], dark: [ImagePack]?) {
        if let useSingleFile = params.common?.images?.useSingleFile, useSingleFile {
            return try loadImagesFromSingleFile(filter: filter)
        } else {
            return try loadImagesFromLightAndDarkFile(filter: filter)
        }
    }

    private func loadImagesFromSingleFile(filter: String? = nil) throws -> (light: [ImagePack], dark: [ImagePack]?) {
        let darkSuffix = params.common?.images?.darkModeSuffix ?? "_dark"
        switch (platform, params.android?.images?.format) {
        case (.android, .png), (.android, .webp), (.ios, .none):
            let images = try loadPNGImages(
                fileId: params.figma.lightFileId,
                frameName: imagesFrameName,
                filter: filter,
                platform: platform)
            let lightImages = images
                .filter { !$0.name.hasSuffix(darkSuffix) }
            let darkImages = images
                .filter { $0.name.hasSuffix(darkSuffix) }
            return (lightImages, darkImages)
        default:
            let pack = try _loadImages(
                fileId: params.figma.lightFileId,
                frameName: imagesFrameName,
                params: SVGParams(),
                filter: filter)
            let lightPack = pack
                .filter { !$0.name.hasSuffix(darkSuffix) }
            let darkPack = pack
                .filter { $0.name.hasSuffix(darkSuffix) }
            return (lightPack, darkPack)
        }
    }

    private func loadImagesFromLightAndDarkFile(filter: String? = nil) throws -> (light: [ImagePack], dark: [ImagePack]?) {
        switch (platform, params.android?.images?.format) {
        case (.android, .png), (.android, .webp), (.ios, .none):
            let lightImages = try loadPNGImages(
                fileId: params.figma.lightFileId,
                frameName: imagesFrameName,
                filter: filter,
                platform: platform)
            let darkImages = try params.figma.darkFileId.map {
                try loadPNGImages(
                    fileId: $0,
                    frameName: imagesFrameName,
                    filter: filter,
                    platform: platform)
            }
            return (
                lightImages,
                darkImages
            )
        default:
            let lightPacks = try _loadImages(
                fileId: params.figma.lightFileId,
                frameName: imagesFrameName,
                params: SVGParams(),
                filter: filter)

            let darkPacks = try params.figma.darkFileId.map {
                try _loadImages(
                    fileId: $0,
                    frameName: imagesFrameName,
                    params: SVGParams(),
                    filter: filter)
            }
            return (lightPacks, darkPacks)
        }
    }

    // MARK: - Helpers

    private func fetchImageComponents(fileId: String, frameName: String, filter: String? = nil) throws -> [NodeId: Component] {
        var components = try loadComponents(fileId: fileId)
            .filter {
                $0.containingFrame.name == frameName &&
                    ($0.description == platform.rawValue || $0.description == nil || $0.description == "") &&
                    $0.description?.contains("none") == false
            }

        if let filter = filter {
            let assetsFilter = AssetsFilter(filter: filter)
            components = components.filter { component -> Bool in
                assetsFilter.match(name: component.name)
            }
        }

        return Dictionary(uniqueKeysWithValues: components.map { ($0.nodeId, $0) })
    }

    private func _loadImages(
        fileId: String,
        frameName: String,
        params: FormatParams,
        filter: String? = nil
    ) throws -> [ImagePack] {
        let imagesDict = try fetchImageComponents(fileId: fileId, frameName: frameName, filter: filter)

        guard !imagesDict.isEmpty else {
            throw FigmaExportError.componentsNotFound
        }

        let imagesIds: [NodeId] = imagesDict.keys.map { $0 }
        
        logger.info("Fetching vector images...")
        let imageIdToImagePath = try loadImages(fileId: fileId, nodeIds: imagesIds, params: params)

        // Group images by name
        let groups = Dictionary(grouping: imagesDict) { $1.name.parseNameAndIdiom(platform: platform).name }

        // Create image packs for groups
        let imagePacks = groups.compactMap { packName, components -> ImagePack? in
            let packImages = components.compactMap { nodeId, component -> Image? in
                guard let urlString = imageIdToImagePath[nodeId], let url = URL(string: urlString) else {
                    return nil
                }
                let (name, idiom) = component.name.parseNameAndIdiom(platform: platform)
                return Image(name: name, scale: .all, idiom: idiom, url: url, format: params.format)
            }
            return ImagePack(name: packName, images: packImages, platform: platform)
        }
        return imagePacks
    }

    private func loadPNGImages(fileId: String, frameName: String, filter: String? = nil, platform: Platform) throws -> [ImagePack] {
        let imagesDict = try fetchImageComponents(fileId: fileId, frameName: frameName, filter: filter)

        guard !imagesDict.isEmpty else {
            throw FigmaExportError.componentsNotFound
        }

        let imagesIds: [NodeId] = imagesDict.keys.map { $0 }
        let scales = getScales(platform: platform)

        var images: [Double: [NodeId: ImagePath]] = [:]
        for scale in scales {
            logger.info("Fetching PNG images for scale \(scale)...")
            images[scale] = try loadImages(fileId: fileId, nodeIds: imagesIds, params: PNGParams(scale: scale))
        }

        // Group images by name
        let groups = Dictionary(grouping: imagesDict) { $1.name.parseNameAndIdiom(platform: platform).name }

        // Create image packs for groups
        let imagePacks = groups.compactMap { packName, components -> ImagePack? in
            let packImages = components.flatMap { nodeId, component -> [Image] in
                let (name, idiom) = component.name.parseNameAndIdiom(platform: platform)
                return scales.compactMap { scale -> Image? in
                    guard let urlString = images[scale]?[nodeId], let url = URL(string: urlString) else {
                        return nil
                    }
                    return Image(name: name, scale: .individual(scale), idiom: idiom, url: url, format: "png")
                }
            }
            return ImagePack(name: packName, images: packImages, platform: platform)
        }
        return imagePacks
    }

    private func getScales(platform: Platform) -> [Double] {
        var validScales: [Double] = []
        var customScales: [Double] = []
        let filterScales = { (platformScales: [Double]?) -> [Double] in
            platformScales?.filter { validScales.contains($0) } ?? []
        }
        if platform == .android {
            validScales = [1, 2, 3, 1.5, 4.0]
            customScales = filterScales(params.android?.images?.scales)
        } else {
            validScales = [1, 2, 3]
            customScales = filterScales(params.ios?.images?.scales)
        }
        return customScales.isEmpty ? validScales : customScales
    }

    // MARK: - Figma

    private func loadComponents(fileId: String) throws -> [Component] {
        let endpoint = ComponentsEndpoint(fileId: fileId)
        return try client.request(endpoint)
    }

    private func loadImages(fileId: String, nodeIds: [NodeId], params: FormatParams) throws -> [NodeId: ImagePath] {
        let batchSize = 100
        let keysWithValues: [(NodeId, ImagePath)] = try nodeIds.chunked(into: batchSize)
            .map { ImageEndpoint(fileId: fileId, nodeIds: $0, params: params) }
            .map { try client.request($0) }
            .flatMap { $0.map { ($0, $1) } }
        return Dictionary(uniqueKeysWithValues: keysWithValues)
    }
}

// MARK: - String Utils

private extension String {

    func parseNameAndIdiom(platform: Platform) -> (name: String, idiom: String) {
        switch platform {
        case .android:
            return (self, "")
        case .ios:
            guard let regex = try? NSRegularExpression(pattern: "(.*)~(.*)$") else {
                return (self, "")
            }
            guard let match = regex.firstMatch(in: self, range: NSRange(startIndex..., in: self)),
                  let name = Range(match.range(at: 1), in: self),
                  let idiom = Range(match.range(at: 2), in: self) else {
                return (self, "")
            }
            return (String(self[name]), String(self[idiom]))
        }
    }

}
