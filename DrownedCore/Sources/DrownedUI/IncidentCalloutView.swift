import AppKit
import DrownedModel

final class IncidentCalloutView: NSView {
    private static let calloutWidth: CGFloat = 520
    private static let calloutHeight: CGFloat = 360
    private static let contentInset: CGFloat = 6
    private static let titleColumnWidth: CGFloat = 132
    private static let columnSpacing: CGFloat = 12
    private static let valueColumnWidth = calloutWidth - titleColumnWidth - contentInset * 4 - columnSpacing

    private let containerStack = NSStackView()
    private let headerLabel = NSTextField(labelWithString: "")
    private let scrollView = NSScrollView()
    private let bodyStack = FlippedStackView()

    enum State {
        case loading
        case loaded
        case failed(String)
    }

    init(incident: Incident, state: State) {
        super.init(frame: NSRect(origin: .zero, size: Self.calloutSize))
        configureLayout()
        update(incident: incident, state: state)
    }

    override var intrinsicContentSize: NSSize {
        return Self.calloutSize
    }

    override var fittingSize: NSSize {
        return Self.calloutSize
    }

    @available(*, unavailable)
    required init(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func update(incident: Incident, state: State) -> Void {
        bodyStack.arrangedSubviews.forEach { view in
            bodyStack.removeArrangedSubview(view)
            view.removeFromSuperview()
        }

        switch state {
            case .loading:
                headerLabel.isHidden = true
                bodyStack.addArrangedSubview(Self.loadingRow())
            case .loaded:
                headerLabel.stringValue = incident.locationDescription
                headerLabel.isHidden = false
                addFullDetails(for: incident)
            case .failed(let message):
                headerLabel.stringValue = incident.locationDescription
                headerLabel.isHidden = false
                bodyStack.addArrangedSubview(Self.valueLabel(message, color: .secondaryLabelColor))
        }

        resizeToFitContent()
    }

    private func configureLayout() -> Void {
        containerStack.orientation = .vertical
        containerStack.alignment = .width
        containerStack.spacing = 8
        containerStack.edgeInsets = NSEdgeInsets(
            top: Self.contentInset,
            left: Self.contentInset,
            bottom: Self.contentInset,
            right: Self.contentInset
        )
        containerStack.translatesAutoresizingMaskIntoConstraints = false

        headerLabel.translatesAutoresizingMaskIntoConstraints = false
        headerLabel.font = .boldSystemFont(ofSize: 15)
        headerLabel.alignment = .left
        headerLabel.lineBreakMode = .byWordWrapping
        headerLabel.maximumNumberOfLines = 3
        headerLabel.preferredMaxLayoutWidth = Self.calloutWidth - Self.contentInset * 2
        headerLabel.setContentCompressionResistancePriority(.required, for: .vertical)

        scrollView.drawsBackground = false
        scrollView.borderType = .noBorder
        scrollView.hasVerticalScroller = true
        scrollView.autohidesScrollers = true
        scrollView.autoresizingMask = [.width, .height]

        bodyStack.orientation = .vertical
        bodyStack.alignment = .width
        bodyStack.spacing = 6
        bodyStack.edgeInsets = NSEdgeInsets(
            top: Self.contentInset,
            left: Self.contentInset,
            bottom: Self.contentInset,
            right: Self.contentInset
        )

        scrollView.documentView = bodyStack
        containerStack.addArrangedSubview(headerLabel)
        containerStack.addArrangedSubview(scrollView)
        addSubview(containerStack)
        NSLayoutConstraint.activate([
            containerStack.leadingAnchor.constraint(equalTo: leadingAnchor),
            containerStack.trailingAnchor.constraint(equalTo: trailingAnchor),
            containerStack.topAnchor.constraint(equalTo: topAnchor),
            containerStack.bottomAnchor.constraint(equalTo: bottomAnchor),
            headerLabel.widthAnchor.constraint(equalToConstant: Self.calloutWidth - Self.contentInset * 2)
        ])
    }

    private func addFullDetails(for incident: Incident) -> Void {
        addRow("Reported", value: incident.reportedDate.formatted(date: .abbreviated, time: .omitted))
        addRow("Cause of death", value: incident.causeOfDeath)
        addRow(
            "Total dead and missing",
            value: incident.totalDeadAndMissing.map { value in
                return value.formatted()
            } ?? "Unknown"
        )
        addOptionalNumberRow("Dead", value: incident.numberDead)
        addOptionalNumberRow("Missing", value: incident.numberMissing)
        addOptionalNumberRow("Survivors", value: incident.numberOfSurvivors)
        addOptionalNumberRow("Female", value: incident.numberOfFemale)
        addOptionalNumberRow("Male", value: incident.numberOfMale)
        addOptionalNumberRow("Children", value: incident.numberOfChildren)
        addOptionalRow("Route", value: incident.migrationRoute)
        addRow("Country", value: incident.countryOfIncident)
        addRow("Region", value: incident.rawRegion)
        addRow("Grouping", value: incident.unsdGeographicGrouping)
        addOptionalRow("Origin region", value: incident.regionOrigin)
        addOptionalRow("Origin country", value: incident.countryOrigin)
        addOptionalRow("Source", value: incident.informationSource)
        addOptionalURLRow("Source URL", value: incident.sourceURL)

        if let sourceQuality = incident.sourceQuality {
            addRow("Source quality", value: sourceQuality.formatted())
        }

        if let latitude = incident.latitude {
            if let longitude = incident.longitude {
                addRow("Coordinates", value: "\(latitude.formatted()), \(longitude.formatted())")
            }
        }

        addRow("Web ID", value: incident.webID)
        addRow("Content hash", value: incident.contentHash.formatted())
    }

    private func addOptionalRow(_ title: String, value: String?) -> Void {
        guard let value else { return }
        guard value.isEmpty == false else { return }
        addRow(title, value: value)
    }

    private func addOptionalURLRow(_ title: String, value: String?) -> Void {
        guard let value else { return }
        guard value.isEmpty == false else { return }
        let urls = Self.urls(in: value)
        guard urls.isEmpty == false else {
            addRow(title, value: value)
            return
        }

        let linkStack = NSStackView()
        linkStack.orientation = .vertical
        linkStack.alignment = .leading
        linkStack.spacing = 3

        for url in urls {
            linkStack.addArrangedSubview(Self.linkLabel(url))
        }

        addRow(title, valueView: linkStack)
    }

    private func addOptionalNumberRow(_ title: String, value: Int?) -> Void {
        guard let value else { return }
        addRow(title, value: value.formatted())
    }

    private func addRow(_ title: String, value: String) -> Void {
        addRow(title, valueView: Self.valueLabel(value))
    }

    private func addRow(_ title: String, valueView: NSView) -> Void {
        bodyStack.addArrangedSubview(
            IncidentDetailRowView(
                title: title,
                valueView: valueView,
                titleColumnWidth: Self.titleColumnWidth,
                valueColumnWidth: Self.valueColumnWidth,
                columnSpacing: Self.columnSpacing
            )
        )
    }

    private static func loadingRow() -> NSView {
        let container = NSView(frame: NSRect(x: 0, y: 0, width: calloutWidth, height: calloutHeight))

        let spinner = NSProgressIndicator()
        spinner.style = .spinning
        spinner.controlSize = .small
        spinner.isIndeterminate = true
        spinner.startAnimation(nil)
        spinner.translatesAutoresizingMaskIntoConstraints = false

        container.addSubview(spinner)
        NSLayoutConstraint.activate([
            spinner.centerXAnchor.constraint(equalTo: container.centerXAnchor),
            spinner.centerYAnchor.constraint(equalTo: container.centerYAnchor)
        ])

        return container
    }

    static func titleLabel(_ text: String) -> NSTextField {
        let label = label(text, font: .systemFont(ofSize: 11, weight: .semibold), color: .secondaryLabelColor)
        label.alignment = .left
        return label
    }

    private static func valueLabel(_ text: String, color: NSColor = .labelColor) -> NSTextField {
        let label = label(text, font: .systemFont(ofSize: 11), color: color)
        label.preferredMaxLayoutWidth = valueColumnWidth
        return label
    }

    private static func label(_ text: String, font: NSFont, color: NSColor = .labelColor) -> NSTextField {
        let label = NSTextField(labelWithString: text)
        label.font = font
        label.textColor = color
        label.maximumNumberOfLines = 0
        label.lineBreakMode = .byWordWrapping
        label.preferredMaxLayoutWidth = calloutWidth - contentInset * 2
        label.setContentCompressionResistancePriority(.required, for: .vertical)
        return label
    }

    private static func linkLabel(_ url: URL) -> NSTextField {
        return LinkTextField(url: url, preferredWidth: valueColumnWidth)
    }

    private static func urls(in text: String) -> [URL] {
        guard let detector = try? NSDataDetector(types: NSTextCheckingResult.CheckingType.link.rawValue) else {
            return []
        }

        let range = NSRange(text.startIndex ..< text.endIndex, in: text)
        return detector.matches(in: text, range: range).compactMap(\.url)
    }

    private func resizeToFitContent() -> Void {
        setFrameSize(Self.calloutSize)

        bodyStack.layoutSubtreeIfNeeded()
        let scrollHeight = Self.calloutHeight - (headerLabel.isHidden ? 0 : headerLabel.fittingSize.height + 8)
        let contentHeight = max(bodyStack.fittingSize.height, scrollHeight)
        let contentSize = NSSize(width: Self.calloutWidth - Self.contentInset * 2, height: contentHeight)

        bodyStack.setFrameSize(contentSize)
        scrollView.documentView?.setFrameSize(contentSize)
        scrollToTop()
        invalidateIntrinsicContentSize()
    }

    private func scrollToTop() -> Void {
        scrollView.contentView.scroll(to: NSPoint(x: 0, y: 0))
        scrollView.reflectScrolledClipView(scrollView.contentView)
    }

    private static var calloutSize: NSSize {
        return NSSize(width: calloutWidth, height: calloutHeight)
    }
}
