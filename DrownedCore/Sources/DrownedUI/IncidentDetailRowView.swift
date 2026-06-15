import AppKit

final class IncidentDetailRowView: NSView {
    init(
        title: String,
        valueView: NSView,
        titleColumnWidth: CGFloat,
        valueColumnWidth: CGFloat,
        columnSpacing: CGFloat
    ) {
        super.init(frame: .zero)

        let titleLabel = IncidentCalloutView.titleLabel(title)
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        valueView.translatesAutoresizingMaskIntoConstraints = false

        addSubview(titleLabel)
        addSubview(valueView)

        NSLayoutConstraint.activate([
            titleLabel.leadingAnchor.constraint(equalTo: leadingAnchor),
            titleLabel.topAnchor.constraint(equalTo: topAnchor),
            titleLabel.widthAnchor.constraint(equalToConstant: titleColumnWidth),

            valueView.leadingAnchor.constraint(equalTo: titleLabel.trailingAnchor, constant: columnSpacing),
            valueView.topAnchor.constraint(equalTo: topAnchor),
            valueView.widthAnchor.constraint(equalToConstant: valueColumnWidth),
            valueView.trailingAnchor.constraint(lessThanOrEqualTo: trailingAnchor),

            bottomAnchor.constraint(greaterThanOrEqualTo: titleLabel.bottomAnchor),
            bottomAnchor.constraint(greaterThanOrEqualTo: valueView.bottomAnchor)
        ])
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
