import ScreenSaver

class WhiteRectangleScreenSaverView: ScreenSaverView {

    private var scrollOffset: CGFloat = 0
    private var scrollSpeed: CGFloat = 0.5
    private var columns: Int = 4
    private var images: [(cgImage: CGImage, size: CGSize)] = []

    // Configuration keys
    private static let speedKey = "ArenaChannelScrollSpeed"
    private static let columnsKey = "ArenaChannelColumns"

    // Speed configuration
    private static let minSpeed: CGFloat = 0.1
    private static let maxSpeed: CGFloat = 2.0
    private static let defaultSpeed: CGFloat = 0.5

    // Columns configuration
    private static let minColumns: Int = 4
    private static let maxColumns: Int = 8
    private static let defaultColumns: Int = 4

    private var configSheet: NSWindow?
    private var speedSlider: NSSlider?
    private var columnsSlider: NSSlider?

    override init?(frame: NSRect, isPreview: Bool) {
        super.init(frame: frame, isPreview: isPreview)
        animationTimeInterval = 1.0 / 60.0
        loadSettings()
        loadImages()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        loadSettings()
        loadImages()
    }

    private var defaults: ScreenSaverDefaults? {
        return ScreenSaverDefaults(forModuleWithName: Bundle(for: type(of: self)).bundleIdentifier!)
    }

    private func loadSettings() {
        if let speed = defaults?.object(forKey: Self.speedKey) as? CGFloat {
            scrollSpeed = speed
        } else {
            scrollSpeed = Self.defaultSpeed
        }

        if let cols = defaults?.object(forKey: Self.columnsKey) as? Int {
            columns = cols
        } else {
            columns = Self.defaultColumns
        }
    }

    private func saveSpeed(_ speed: CGFloat) {
        defaults?.set(speed, forKey: Self.speedKey)
        defaults?.synchronize()
    }

    private func saveColumns(_ cols: Int) {
        defaults?.set(cols, forKey: Self.columnsKey)
        defaults?.synchronize()
    }

    private func loadImages() {
        let bundle = Bundle(for: type(of: self))
        guard let resourcePath = bundle.resourcePath else { return }

        let imagesPath = (resourcePath as NSString).appendingPathComponent("images")
        let fileManager = FileManager.default

        guard fileManager.fileExists(atPath: imagesPath),
              let files = try? fileManager.contentsOfDirectory(atPath: imagesPath) else { return }

        let sortedFiles = files.sorted()
        for file in sortedFiles {
            let filePath = (imagesPath as NSString).appendingPathComponent(file)
            if let cgImage = loadAndDecodeImage(at: filePath) {
                let size = CGSize(width: cgImage.width, height: cgImage.height)
                images.append((cgImage: cgImage, size: size))
            }
        }
    }

    private func loadAndDecodeImage(at path: String) -> CGImage? {
        guard let dataProvider = CGDataProvider(filename: path),
              let imageSource = CGImageSourceCreateWithDataProvider(dataProvider, nil),
              let cgImage = CGImageSourceCreateImageAtIndex(imageSource, 0, nil) else {
            return nil
        }

        // Force decode by drawing to a new context
        let width = cgImage.width
        let height = cgImage.height
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let bitmapInfo = CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedFirst.rawValue | CGBitmapInfo.byteOrder32Little.rawValue)

        guard let context = CGContext(
            data: nil,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: width * 4,
            space: colorSpace,
            bitmapInfo: bitmapInfo.rawValue
        ) else {
            return cgImage
        }

        context.draw(cgImage, in: CGRect(x: 0, y: 0, width: width, height: height))
        return context.makeImage() ?? cgImage
    }

    override func startAnimation() {
        super.startAnimation()
    }

    override func stopAnimation() {
        super.stopAnimation()
    }

    override func draw(_ rect: NSRect) {
        guard let context = NSGraphicsContext.current?.cgContext else { return }

        // Pure black background
        context.setFillColor(NSColor.black.cgColor)
        context.fill(bounds)

        guard !images.isEmpty else { return }

        let cellSize = bounds.width / CGFloat(columns)
        let rowsNeeded = Int(ceil(bounds.height / cellSize)) + 2

        // Calculate pixel offset for smooth scrolling
        let pixelOffset = scrollOffset.truncatingRemainder(dividingBy: cellSize)

        for row in 0..<rowsNeeded {
            for col in 0..<columns {
                let x = CGFloat(col) * cellSize
                // Draw from bottom, scrolling up
                let y = CGFloat(row) * cellSize - pixelOffset

                // Calculate which image to show (cycling through all images)
                let absoluteRow = Int(floor(scrollOffset / cellSize)) + row
                let imageIndex = (absoluteRow * columns + col) % images.count

                let cellRect = CGRect(x: x, y: y, width: cellSize, height: cellSize)
                drawCell(in: context, at: cellRect, imageData: images[imageIndex])
            }
        }
    }

    private func drawCell(in context: CGContext, at rect: CGRect, imageData: (cgImage: CGImage, size: CGSize)) {
        let padding: CGFloat = 4
        let innerRect = rect.insetBy(dx: padding, dy: padding)

        context.saveGState()

        // Clip to rounded rect
        let clipPath = CGPath(roundedRect: innerRect, cornerWidth: 8, cornerHeight: 8, transform: nil)
        context.addPath(clipPath)
        context.clip()

        // Calculate aspect fill rect
        let imageSize = imageData.size
        let imageAspect = imageSize.width / imageSize.height
        let targetAspect = innerRect.width / innerRect.height

        var drawRect: CGRect

        if imageAspect > targetAspect {
            // Image is wider - fit height, crop width
            let drawHeight = innerRect.height
            let drawWidth = drawHeight * imageAspect
            let xOffset = (innerRect.width - drawWidth) / 2
            drawRect = CGRect(x: innerRect.origin.x + xOffset, y: innerRect.origin.y, width: drawWidth, height: drawHeight)
        } else {
            // Image is taller - fit width, crop height
            let drawWidth = innerRect.width
            let drawHeight = drawWidth / imageAspect
            let yOffset = (innerRect.height - drawHeight) / 2
            drawRect = CGRect(x: innerRect.origin.x, y: innerRect.origin.y + yOffset, width: drawWidth, height: drawHeight)
        }

        context.draw(imageData.cgImage, in: drawRect)

        context.restoreGState()
    }

    override func animateOneFrame() {
        scrollOffset += scrollSpeed

        // Reset offset periodically to prevent floating point issues
        if !images.isEmpty {
            let cellSize = bounds.width / CGFloat(columns)
            // For seamless infinite scroll, the cycle must repeat when the image pattern aligns
            // This happens every (images.count / gcd(columns, images.count)) rows
            let cycleRows = images.count / gcd(columns, images.count)
            let cycleHeight = cellSize * CGFloat(cycleRows)
            if scrollOffset >= cycleHeight {
                scrollOffset -= cycleHeight
            }
        }

        setNeedsDisplay(bounds)
    }

    private func gcd(_ a: Int, _ b: Int) -> Int {
        return b == 0 ? a : gcd(b, a % b)
    }

    override var hasConfigureSheet: Bool {
        return true
    }

    override var configureSheet: NSWindow? {
        if configSheet == nil {
            configSheet = createConfigSheet()
        }
        return configSheet
    }

    private func createConfigSheet() -> NSWindow {
        let windowWidth: CGFloat = 340
        let windowHeight: CGFloat = 180

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: windowWidth, height: windowHeight),
            styleMask: [.titled],
            backing: .buffered,
            defer: false
        )
        window.title = "Arena Screensaver Options"

        let contentView = NSView(frame: NSRect(x: 0, y: 0, width: windowWidth, height: windowHeight))

        let labelWidth: CGFloat = 70
        let sliderLeft: CGFloat = 95
        let sliderWidth: CGFloat = 190
        let smallFont = NSFont.systemFont(ofSize: 10)
        let labelFont = NSFont.systemFont(ofSize: 13)

        // Speed row
        let speedRowY: CGFloat = 115

        let speedLabel = NSTextField(labelWithString: "Speed:")
        speedLabel.frame = NSRect(x: 20, y: speedRowY, width: labelWidth, height: 20)
        speedLabel.font = labelFont
        speedLabel.alignment = .right
        contentView.addSubview(speedLabel)

        let speedSlider = NSSlider(frame: NSRect(x: sliderLeft, y: speedRowY, width: sliderWidth, height: 20))
        speedSlider.minValue = Double(Self.minSpeed)
        speedSlider.maxValue = Double(Self.maxSpeed)
        speedSlider.doubleValue = Double(scrollSpeed)
        speedSlider.target = self
        speedSlider.action = #selector(speedSliderChanged(_:))
        speedSlider.isContinuous = true
        contentView.addSubview(speedSlider)
        self.speedSlider = speedSlider

        let slowerLabel = NSTextField(labelWithString: "Slower")
        slowerLabel.frame = NSRect(x: sliderLeft, y: speedRowY - 18, width: 50, height: 16)
        slowerLabel.font = smallFont
        slowerLabel.textColor = .secondaryLabelColor
        contentView.addSubview(slowerLabel)

        let fasterLabel = NSTextField(labelWithString: "Faster")
        fasterLabel.frame = NSRect(x: sliderLeft + sliderWidth - 50, y: speedRowY - 18, width: 50, height: 16)
        fasterLabel.font = smallFont
        fasterLabel.alignment = .right
        fasterLabel.textColor = .secondaryLabelColor
        contentView.addSubview(fasterLabel)

        // Columns row
        let columnsRowY: CGFloat = 60

        let columnsLabel = NSTextField(labelWithString: "Columns:")
        columnsLabel.frame = NSRect(x: 20, y: columnsRowY, width: labelWidth, height: 20)
        columnsLabel.font = labelFont
        columnsLabel.alignment = .right
        contentView.addSubview(columnsLabel)

        let colSlider = NSSlider(frame: NSRect(x: sliderLeft, y: columnsRowY, width: sliderWidth, height: 20))
        colSlider.minValue = Double(Self.minColumns)
        colSlider.maxValue = Double(Self.maxColumns)
        colSlider.integerValue = columns
        colSlider.numberOfTickMarks = Self.maxColumns - Self.minColumns + 1
        colSlider.allowsTickMarkValuesOnly = true
        colSlider.target = self
        colSlider.action = #selector(columnsSliderChanged(_:))
        colSlider.isContinuous = true
        contentView.addSubview(colSlider)
        self.columnsSlider = colSlider

        // Number labels under each tick mark
        let tickCount = Self.maxColumns - Self.minColumns + 1
        let tickSpacing = sliderWidth / CGFloat(tickCount - 1)
        for i in 0..<tickCount {
            let num = Self.minColumns + i
            let numLabel = NSTextField(labelWithString: "\(num)")
            let xPos = sliderLeft + (tickSpacing * CGFloat(i)) - 10
            numLabel.frame = NSRect(x: xPos, y: columnsRowY - 18, width: 20, height: 16)
            numLabel.font = smallFont
            numLabel.alignment = .center
            numLabel.textColor = .secondaryLabelColor
            contentView.addSubview(numLabel)
        }

        // OK button
        let okButton = NSButton(frame: NSRect(x: windowWidth - 90, y: 12, width: 75, height: 28))
        okButton.title = "OK"
        okButton.bezelStyle = .rounded
        okButton.keyEquivalent = "\r"
        okButton.target = self
        okButton.action = #selector(closeConfigSheet(_:))
        contentView.addSubview(okButton)

        window.contentView = contentView
        return window
    }

    @objc private func speedSliderChanged(_ sender: NSSlider) {
        scrollSpeed = CGFloat(sender.doubleValue)
        saveSpeed(scrollSpeed)
    }

    @objc private func columnsSliderChanged(_ sender: NSSlider) {
        columns = sender.integerValue
        saveColumns(columns)
    }

    @objc private func closeConfigSheet(_ sender: Any) {
        guard let window = configSheet else { return }
        if let parent = window.sheetParent {
            parent.endSheet(window)
        } else {
            window.close()
        }
    }
}
