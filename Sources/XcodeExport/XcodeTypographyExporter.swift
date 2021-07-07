import Foundation
import FigmaExportCore
import Stencil

final public class XcodeTypographyExporter {

    public init() {}
    
    public func exportFonts(textStyles: [TextStyle], fontExtensionURL: URL) throws -> [FileContents] {
        let stringsLabel: [String] = textStyles.map {
            let lineHeight = $0.lineHeight == nil ? "" : "\n        self.lineHeight = \($0.lineHeight!)"
            return """
                @objc lazy var \($0.name): SQStyleLabel = {
                    self.font = self.customFont("\($0.fontName)", size: \($0.fontSize))\(lineHeight)
                    return self
                }()
            """
        }
        
        let stringsButton: [String] = textStyles.map {
            let lineHeight = $0.lineHeight == nil ? "" : "\n        self.lineHeight = \($0.lineHeight!)"
            return """
                @objc lazy var \($0.name): SQStyleButton = {
                    self.font = self.customFont("\($0.fontName)", size: \($0.fontSize))\(lineHeight)
                    return self
                }()
            """
        }
        
        let contents = """
        \(header)
        
        import Foundation
        import UIKit

        protocol Style {
            func build()
        }

        protocol UIStyle: Style {
            associatedtype Element
            
            var style: Element { get set }
        }

        class SQStyle: NSObject {

            var element: Style!
            var font: UIFont?
            var _colorText: UIColor?
            var lineHeight: CGFloat?

            init(element: Style) {
                self.element = element
            }

            func build() {
                self.element.build()
            }
            
           func customFont(
               _ name: String,
               size: CGFloat,
               scaled: Bool = false) -> UIFont {

               guard let font = UIFont(name: name, size: size) else {
                   return UIFont.systemFont(ofSize: size, weight: .regular)
               }
               
               return font
           }

        }

        class SQStyleLabel: SQStyle {

            var textAlignment: NSTextAlignment?
            var lineBreakMode: NSLineBreakMode?
            var strikethroughStyle: NSUnderlineStyle?
            var underlineStyle: NSUnderlineStyle?

        \(stringsLabel.joined(separator: "\n\n"))

            lazy var centrerAlignment: SQStyleLabel = {
                self.textAlignment = .center
                return self
            }()

            lazy var leftAlignment: SQStyleLabel = {
                self.textAlignment = .left
                return self
            }()

            lazy var rightAlignment: SQStyleLabel = {
                self.textAlignment = .right
                return self
            }()
        
            lazy var lineBreakModeByWordWrapping: SQStyleLabel = {
                self.lineBreakMode = .byWordWrapping
                return self
            }()
            
            lazy var lineBreakModeByCharWrapping: SQStyleLabel = {
                self.lineBreakMode = .byCharWrapping
                return self
            }()

            lazy var lineBreakModeByClipping: SQStyleLabel = {
                self.lineBreakMode = .byClipping
                return self
            }()
            
            lazy var lineBreakModeByTruncatingHead: SQStyleLabel = {
                self.lineBreakMode = .byTruncatingHead
                return self
            }()
            
            lazy var lineBreakModeByTruncatingTail: SQStyleLabel = {
                self.lineBreakMode = .byTruncatingTail
                return self
            }()
            
            lazy var lineBreakModeByTruncatingMiddle: SQStyleLabel = {
                self.lineBreakMode = .byTruncatingMiddle
                return self
            }()
        
            lazy var strikethroughStyleSingle: SQStyleLabel = {
                self.strikethroughStyle = .single
                return self
            }()

            lazy var strikethroughStyleThick: SQStyleLabel = {
                self.strikethroughStyle = .thick
                return self
            }()
            
            lazy var strikethroughStyleDouble: SQStyleLabel = {
                self.strikethroughStyle = .double
                return self
            }()
         
            lazy var strikethroughStylePatternDot: SQStyleLabel = {
                self.strikethroughStyle = .patternDot
                return self
            }()

            lazy var strikethroughStylePatternDash: SQStyleLabel = {
                self.strikethroughStyle = .patternDash
                return self
            }()
            
            lazy var strikethroughStylePatternDashDot: SQStyleLabel = {
                self.strikethroughStyle = .patternDashDot
                return self
            }()
            
            lazy var strikethroughStylePatternDashDotDot: SQStyleLabel = {
                self.strikethroughStyle = .patternDashDotDot
                return self
            }()

            lazy var strikethroughStyleByWord: SQStyleLabel = {
                self.strikethroughStyle = .byWord
                return self
            }()
        
            lazy var underlineStyleSingle: SQStyleLabel = {
                self.underlineStyle = .single
                return self
            }()

            lazy var underlineStyleThick: SQStyleLabel = {
                self.underlineStyle = .thick
                return self
            }()
            
            lazy var underlineStyleDouble: SQStyleLabel = {
                self.underlineStyle = .double
                return self
            }()
         
            lazy var underlineStylePatternDot: SQStyleLabel = {
                self.underlineStyle = .patternDot
                return self
            }()

            lazy var underlineStylePatternDash: SQStyleLabel = {
                self.underlineStyle = .patternDash
                return self
            }()
            
            lazy var underlineStylePatternDashDot: SQStyleLabel = {
                self.underlineStyle = .patternDashDot
                return self
            }()
            
            lazy var underlineStylePatternDashDotDot: SQStyleLabel = {
                self.underlineStyle = .patternDashDotDot
                return self
            }()

            lazy var underlineStyleByWord: SQStyleLabel = {
                self.underlineStyle = .byWord
                return self
            }()

            lazy var colorText = { (color: UIColor?) -> SQStyleLabel in
                self._colorText = color
                return self
            }

            func safeValue(forKey key: String) {
                let copy = Mirror(reflecting: self)
                for child in copy.children.makeIterator() {
                    if String(describing: child.label) == "Optional(\\"$__lazy_storage_$_\\(key)\\")" {
                        self.value(forKey: key)
                        return
                    }
                }
                fatalError("not font style: \\(key)")
            }
        }

        class SQStyleButton: SQStyle {
            
        \(stringsButton.joined(separator: "\n\n"))

            lazy var colorText = { (color: UIColor?) -> SQStyleButton in
                self._colorText = color
                return self
            }

            func safeValue(forKey key: String) {
                let copy = Mirror(reflecting: self)
                for child in copy.children.makeIterator() {
                    if String(describing: child.label) == "Optional(\\"$__lazy_storage_$_\\(key)\\")" {
                        self.value(forKey: key)
                        return
                    }
                }
                fatalError("not font style: \\(key)")
            }
        }
        """
        
        let data = contents.data(using: .utf8)!
        
        let fileURL = URL(string: fontExtensionURL.lastPathComponent)!
        let directoryURL = fontExtensionURL.deletingLastPathComponent()
        
        let destination = Destination(directory: directoryURL, file: fileURL)
        return [FileContents(destination: destination, data: data)]
    }
    
    public func exportFonts(textStyles: [TextStyle], swiftUIFontExtensionURL: URL) throws -> [FileContents] {
        let strings: [String] = textStyles.map {
            return """
                static func \($0.name)() -> Font {
                    Font.custom("\($0.fontName)", size: \($0.fontSize))
                }
            """
        }
        
        let contents = """
        \(header)
        
        import SwiftUI

        public extension Font {
            
        \(strings.joined(separator: "\n"))
        }
        """

        let data = contents.data(using: .utf8)!
        
        let fileURL = URL(string: swiftUIFontExtensionURL.lastPathComponent)!
        let directoryURL = swiftUIFontExtensionURL.deletingLastPathComponent()
        
        let destination = Destination(directory: directoryURL, file: fileURL)
        return [FileContents(destination: destination, data: data)]
    }
    
    public func exportLabels(textStyles: [TextStyle], labelsDirectory: URL) throws -> [FileContents] {
        let dict = textStyles.map { style -> [String: Any] in
            let type: String = style.name
            return [
                "className": style.name.first!.uppercased() + style.name.dropFirst(),
                "varName": style.name,
                "size": style.fontSize,
                "supportsDynamicType": true,
                "type": type,
                "tracking": style.letterSpacing,
                "lineHeight": style.lineHeight ?? 0
            ]}
        let contents = try TEMPLATE_Label_swift.render(["styles": dict])
        let buttonContents = try TEMPLATE_button_swift.render(["style": dict])
        
        
        let labelSwift = try makeFileContents(data: contents, directoryURL: labelsDirectory, fileName: "SQLabel.swift")
        let buttonStyleSwift = try makeFileContents(data: buttonContents, directoryURL: labelsDirectory, fileName: "SQButton.swift")
        
        return [labelSwift, buttonStyleSwift]
    }
    
    private func makeFileContents(data: String, directoryURL: URL, fileName: String) throws -> FileContents {
        let data = data.data(using: .utf8)!
        let fileURL = URL(string: fileName)!
        let destination = Destination(directory: directoryURL, file: fileURL)
        return FileContents(destination: destination, data: data)
    }
}

private let TEMPLATE_button_swift = Template(templateString: """
\(header)

import UIKit

@IBDesignable class SQButton: UIButton, UIStyle {
    
    private var _style: SQStyleButton?
    
    lazy var style: SQStyleButton = {
        self._style = self._style == nil ? SQStyleButton(element: self) : self._style!
       return self._style!
    }()
    
    func build() {
        self.titleLabel?.font = self._style?.font
        self.setTitleColor(self._style?._colorText, for: .normal)
    }
    
    @IBInspectable var styleFont: String = "" {
        didSet {
            self.style.safeValue(forKey: self.styleFont)
            self.updateAttributedText()
        }
    }
    
    private func updateAttributedText() {
        
        guard let font = self.style.font else { return }
        
        let paragraphStyle = NSMutableParagraphStyle()
        let lineHeight = ((100.0 * (self.style.lineHeight ?? 0.0)) / (font).lineHeight) / 100
        paragraphStyle.lineHeightMultiple = lineHeight

        
        let attributedString: NSMutableAttributedString
        if let labelAttributedText = self.titleLabel?.attributedText {
            attributedString = NSMutableAttributedString(attributedString: labelAttributedText)
        } else {
            attributedString = NSMutableAttributedString(string: self.titleLabel?.text ?? "")
        }

        attributedString.addAttribute(NSAttributedString.Key.paragraphStyle,
                                      value: paragraphStyle,
                                      range: NSMakeRange(.zero, attributedString.length))
        
        self.titleLabel?.attributedText = attributedString
        invalidateIntrinsicContentSize()
    }
    
}
"""
)

private let TEMPLATE_Label_swift = Template(templateString: """
\(header)

import UIKit

class SQLabel: UILabel, UIStyle {

     private var _style: SQStyleLabel?
     
     override var text: String? {
         didSet {
             if self._style != nil {
                 self.updateAttributedText()
             }
         }
     }

     func build() {
         self.font = self._style?.font
         self.textColor = self._style?._colorText
         self.updateAttributedText()
     }

     lazy var style: SQStyleLabel = {
         self._style = self._style == nil ? SQStyleLabel(element: self) : self._style!
        return self._style!
     }()

    @IBInspectable var styleFont: String = "" {
        didSet {
            self.style.safeValue(forKey: self.styleFont)
        }
    }
    
    private func updateAttributedText() {
        let paragraphStyle = NSMutableParagraphStyle()
        let lineHeight = ((100.0 * (self.style.lineHeight ?? 0.0)) / (self.style.font ?? self.font).lineHeight) / 100
        paragraphStyle.lineHeightMultiple = lineHeight
        paragraphStyle.lineBreakMode = self.style.lineBreakMode ?? self.lineBreakMode
        paragraphStyle.alignment = self.style.textAlignment ?? self.textAlignment
        
        let attributedString: NSMutableAttributedString
        if let labelAttributedText = self.attributedText {
            attributedString = NSMutableAttributedString(attributedString: labelAttributedText)
        } else {
            attributedString = NSMutableAttributedString(string: self.text ?? "")
        }

        attributedString.addAttribute(NSAttributedString.Key.paragraphStyle,
                                      value: paragraphStyle,
                                      range: NSMakeRange(.zero, attributedString.length))

        if let strikethroughStyle = self.style.strikethroughStyle {
            attributedString.addAttribute(NSAttributedString.Key.strikethroughStyle,
                                          value: strikethroughStyle,
                                          range: NSMakeRange(.zero, attributedString.length))
        }

        if let underlineStyle = self.style.underlineStyle {
            attributedString.addAttribute(NSAttributedString.Key.underlineStyle,
                                          value: underlineStyle.rawValue,
                                          range: NSMakeRange(.zero, attributedString.length))
        }
        
        self.attributedText = attributedString
        invalidateIntrinsicContentSize()
    }
}
""")
