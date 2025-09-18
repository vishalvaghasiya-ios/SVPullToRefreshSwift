import UIKit
import ObjectiveC

public enum PullToRefreshState {
    case stopped
    case triggered
    case loading
}

public final class PullToRefreshView: UIView {
    // Public
    public var actionHandler: (() -> Void)?
    public private(set) var state: PullToRefreshState = .stopped

    // UI
    private let titleLabel = UILabel()
    private let subtitleLabel = UILabel()
    private let arrowLayer = CAShapeLayer()
    private let activity = UIActivityIndicatorView(style: .medium)

    // Config
    public var originalTopInset: CGFloat = 0
    public var height: CGFloat = 60

    // Internals
    fileprivate weak var scrollView: UIScrollView?
    fileprivate var contentOffsetObservation: NSKeyValueObservation?

    public init(frame: CGRect, handler: @escaping () -> Void) {
        super.init(frame: frame)
        self.actionHandler = handler
        setup()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setup()
    }

    deinit {
        contentOffsetObservation?.invalidate()
    }

    private func setup() {
        autoresizingMask = .flexibleWidth

        // Title
        titleLabel.font = UIFont.systemFont(ofSize: 13, weight: .regular)
        titleLabel.textAlignment = .center
        titleLabel.text = "Pull to refresh"
        titleLabel.translatesAutoresizingMaskIntoConstraints = false

        // Subtitle
        subtitleLabel.font = UIFont.systemFont(ofSize: 11)
        subtitleLabel.textAlignment = .center
        subtitleLabel.text = ""
        subtitleLabel.translatesAutoresizingMaskIntoConstraints = false

        // Arrow
        arrowLayer.lineWidth = 2.0
        arrowLayer.lineJoin = .round
        arrowLayer.lineCap = .round
        arrowLayer.fillColor = UIColor.clear.cgColor
        arrowLayer.strokeColor = UIColor.darkGray.cgColor

        // Activity
        activity.hidesWhenStopped = true
        activity.translatesAutoresizingMaskIntoConstraints = false

        addSubview(titleLabel)
        addSubview(subtitleLabel)
        layer.addSublayer(arrowLayer)
        addSubview(activity)

        NSLayoutConstraint.activate([
            titleLabel.centerXAnchor.constraint(equalTo: centerXAnchor),
            titleLabel.bottomAnchor.constraint(equalTo: centerYAnchor, constant: -2),
            subtitleLabel.centerXAnchor.constraint(equalTo: centerXAnchor),
            subtitleLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 2),
            activity.centerYAnchor.constraint(equalTo: centerYAnchor),
            activity.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 16)
        ])
    }

    public override func layoutSubviews() {
        super.layoutSubviews()
        // Arrow position (left of title)
        let arrowSize: CGFloat = 14
        let arrowX: CGFloat = 16
        let midY = bounds.height / 2
        let arrowFrame = CGRect(x: arrowX, y: midY - arrowSize/2, width: arrowSize, height: arrowSize)
        arrowLayer.frame = arrowFrame
        updateArrowPath()
    }

    private func updateArrowPath() {
        let w = arrowLayer.bounds.width
        let h = arrowLayer.bounds.height
        let p = UIBezierPath()
        p.move(to: CGPoint(x: 2, y: h/2))
        p.addLine(to: CGPoint(x: w - 4, y: h/2))
        p.move(to: CGPoint(x: w - 6, y: h/2 - 4))
        p.addLine(to: CGPoint(x: w - 2, y: h/2))
        p.addLine(to: CGPoint(x: w - 6, y: h/2 + 4))
        arrowLayer.path = p.cgPath
    }

    fileprivate func attach(to scrollView: UIScrollView) {
        self.scrollView = scrollView
        frame = CGRect(x: 0, y: -height, width: scrollView.bounds.width, height: height)
        originalTopInset = scrollView.contentInset.top
        scrollView.addSubview(self)
        // Observe contentOffset
        contentOffsetObservation = scrollView.observe(\.contentOffset, options: [.new]) { [weak self] scrollView, change in
            DispatchQueue.main.async { self?.scrollViewDidScroll(scrollView) }
        }
    }

    fileprivate func detach() {
        contentOffsetObservation?.invalidate()
        contentOffsetObservation = nil
        removeFromSuperview()
    }

    private func scrollViewDidScroll(_ scrollView: UIScrollView) {
        guard state != .loading else { return }
        let offsetY = scrollView.contentOffset.y + scrollView.adjustedContentInset.top
        // when pulling down offsetY < 0
        if scrollView.isDragging {
            if offsetY < -height {
                setState(.triggered)
            } else {
                setState(.stopped)
            }
        } else {
            if state == .triggered {
                startAnimating()
            }
        }
    }

    public func setState(_ newState: PullToRefreshState) {
        guard state != newState else { return }
        let previous = state
        state = newState

        switch newState {
        case .stopped:
            titleLabel.text = "Pull to refresh"
            activity.stopAnimating()
            arrowLayer.isHidden = false
            rotateArrow(down: true)
            // reset content inset
            resetScrollViewContentInset()
        case .triggered:
            titleLabel.text = "Release to refresh"
            rotateArrow(down: false)
        case .loading:
            titleLabel.text = "Loading..."
            arrowLayer.isHidden = true
            activity.startAnimating()
            // set content inset to show spinner
            if let sv = scrollView {
                var inset = sv.contentInset
                inset.top = originalTopInset + height
                setScrollViewContentInset(inset)
            }
            // call handler
            if previous != .loading {
                actionHandler?()
            }
        }
    }

    public func startAnimating() {
        setState(.loading)
    }

    public func stopAnimating() {
        setState(.stopped)
    }

    // Helpers for content inset
    private func setScrollViewContentInset(_ inset: UIEdgeInsets) {
        UIView.animate(withDuration: 0.25) {
            self.scrollView?.contentInset = inset
        }
    }

    fileprivate func resetScrollViewContentInset() {
        guard let sv = scrollView else { return }
        var inset = sv.contentInset
        inset.top = originalTopInset
        setScrollViewContentInset(inset)
    }

    private func rotateArrow(down: Bool) {
        let angle: CGFloat = down ? 0 : .pi
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        arrowLayer.setAffineTransform(CGAffineTransform(rotationAngle: angle))
        CATransaction.commit()
    }
}


// MARK: - UIScrollView extension for PullToRefresh

@MainActor private var pullToRefreshKey: UInt8 = 0

public extension UIScrollView {
    var pullToRefreshView: PullToRefreshView? {
        get { objc_getAssociatedObject(self, &pullToRefreshKey) as? PullToRefreshView }
        set {
            objc_setAssociatedObject(self, &pullToRefreshKey, newValue, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
        }
    }

    /// Add pull-to-refresh with a closure
    func addPullToRefresh(height: CGFloat = 60, action: @escaping () -> Void) {
        // remove existing first
        removePullToRefresh()
        let view = PullToRefreshView(frame: .zero, handler: action)
        view.height = height
        view.attach(to: self)
        self.pullToRefreshView = view
    }

    /// Manually trigger the refresh (shows spinner and calls handler)
    func triggerPullToRefresh() {
        pullToRefreshView?.startAnimating()
    }

    /// Stop loading and hide spinner
    func stopPullToRefresh() {
        pullToRefreshView?.stopAnimating()
    }

    /// Remove the pull-to-refresh view
    func removePullToRefresh() {
        pullToRefreshView?.detach()
        pullToRefreshView = nil
    }
}
