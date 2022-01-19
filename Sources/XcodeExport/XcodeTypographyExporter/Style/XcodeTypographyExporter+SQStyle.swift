//
//  File.swift
//  
//
//  Created by Semen Kologrivov on 19.01.2022.
//

import Foundation
import FigmaExportCore
import Stencil

extension XcodeTypographyExporter {

    func createSQStyle(folderURL: URL) throws -> FileContents {

        let content = """
        \(header)

        import UIKit

        protocol Style {

            func build()
        }

        protocol UIStyle: Style {

            associatedtype Element

            var style: Element { get }

            func resetStyle()
        }

        class SQStyle: NSObject {

            var element: Style?
            var font: UIFont?

            var _textColor: UIColor?

            var lineHeight: CGFloat?
            var letterSpacing: CGFloat?

            var strikethroughStyle: NSUnderlineStyle?
            var underlineStyle: NSUnderlineStyle?

            var textAlignment: NSTextAlignment?
            var lineBreakMode: NSLineBreakMode?

            override init() {
                super.init()
            }

            init(element: Style) {
                super.init()

                self.element = element
            }

            func build() {
                self.element?.build()
            }

            func customFont(
                _ name: String,
                size: CGFloat
            ) -> UIFont {

                guard let font = UIFont(name: name, size: size) else {
                    return UIFont.systemFont(ofSize: size, weight: .regular)
                }

                return font
            }


            func convertStringToAttributed(
                _ string: String,
                defaultLineBreakMode: NSLineBreakMode? = nil,
                defaultAlignment: NSTextAlignment? = nil
            ) -> NSAttributedString {
                self.convertStringToAttributed(
                    NSAttributedString(string: string),
                    defaultLineBreakMode: defaultLineBreakMode,
                    defaultAlignment: defaultAlignment
                )
            }

            func convertStringToAttributed(
                _ string: NSAttributedString,
                defaultLineBreakMode: NSLineBreakMode? = nil,
                defaultAlignment: NSTextAlignment? = nil
            ) -> NSAttributedString {
                let paragraphStyle = NSMutableParagraphStyle()
                if let lineHeight = self.lineHeight,
                   let font = self.font {
                    let lineHeightMultiple = ((100.0 * lineHeight) / font.lineHeight) / 100
                    paragraphStyle.lineHeightMultiple = lineHeightMultiple
                }

                if let lineBreakMode = self.lineBreakMode ?? defaultLineBreakMode {
                    paragraphStyle.lineBreakMode = lineBreakMode
                }

                if let alignment = self.textAlignment ?? defaultAlignment {
                    paragraphStyle.alignment = alignment
                }

                let attributedString = NSMutableAttributedString(attributedString: string)

                attributedString.addAttribute(NSAttributedString.Key.paragraphStyle,
                                              value: paragraphStyle,
                                              range: NSMakeRange(.zero, attributedString.length))

                if let strikethroughStyle = self.strikethroughStyle {
                    attributedString.addAttribute(NSAttributedString.Key.strikethroughStyle,
                                                  value: strikethroughStyle.rawValue,
                                                  range: NSMakeRange(.zero, attributedString.length))
                }

                if let underlineStyle = self.underlineStyle {
                    attributedString.addAttribute(NSAttributedString.Key.underlineStyle,
                                                  value: underlineStyle.rawValue,
                                                  range: NSMakeRange(.zero, attributedString.length))
                }

                if let letterSpacing = self.letterSpacing {
                    attributedString.addAttribute(NSAttributedString.Key.kern,
                                                  value: letterSpacing,
                                                  range: NSMakeRange(.zero, attributedString.length))
                }


                return attributedString
            }

        }

        """

        return try self.makeFileContents(
            data: content,
            directoryURL: folderURL,
            fileName: "SQStyle.swift"
        )
    }
}
