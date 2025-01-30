import FigmaExportCore
import Foundation
import Logging
#if os(Linux)
import FoundationXML
#endif

final class FileWriter {
    private let fileManager: FileManager
    private let logger = Logger(label: "com.redmadrobot.figma-export.file-writer")

    init(fileManager: FileManager = .default) {
        self.fileManager = fileManager
    }

    func write(files: [FileContents]) throws {
        try files.forEach { file in
            let directoryURL = URL(fileURLWithPath: file.destination.directory.path)
            try fileManager.createDirectory(at: directoryURL, withIntermediateDirectories: true, attributes: nil)

            let fileURL = URL(fileURLWithPath: file.destination.url.path)
            do {
                if let data = file.data {
                    try data.write(to: fileURL, options: .atomic)
                } else if let localFileURL = file.dataFile {
                    _ = try fileManager.replaceItemAt(fileURL, withItemAt: localFileURL)
                } else {
                    fatalError("FileContents.data is nil. Use FileDownloader to download contents of the file.")
                }
            } catch let e {
                logger.error("\(e.localizedDescription)")
            }
        }
    }

    func write(xmlFile: XMLDocument, directory: URL) throws {
        let fileURL = URL(fileURLWithPath: directory.path)
        let options: XMLNode.Options = [.nodePrettyPrint, .nodeCompactEmptyElement]
        try xmlFile.xmlData(options: options).write(to: fileURL, options: .atomic)
    }
}
