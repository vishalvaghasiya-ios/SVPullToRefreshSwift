import UIKit
import ObjectiveC

public enum InfiniteScrollingState {
    case stopped
    case triggered
    case loading
    case allLoaded
}

public final class InfiniteScrollingView: UIView {
    public var actionHandler: (() -> Void)?
    public private(set) var state: InfiniteScrollingState = .stopped

    private let activity = UIActivityIndicatorView(style: .medium)
    private let titleLabel = UILabel()
    fileprivate weak var scrollView: UIScrollView?
    fileprivate var contentSizeObservation: NSKeyValueObservation?
    fileprivate var contentOffsetObservation: NSKeyValueObservation?

    public var enabled: Bool = true

    public var height: CGFloat = 60
    public var triggerOffset: CGFloat = 60 // how close to bottom to trigger

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
        contentSizeObservation?.invalidate()
    }

    private func setup() {
        autoresizingMask = .flexibleWidth
        activity.hidesWhenStopped = true
        activity.translatesAutoresizingMaskIntoConstraints = false
        titleLabel.font = UIFont.systemFont(ofSize: 13)
        titleLabel.textAlignment = .center
        titleLabel.text = ""

        addSubview(activity)
        addSubview(titleLabel)

        activity.center = CGPoint(x: 20, y: height / 2)
        titleLabel.frame = CGRect(x: 0, y: 0, width: bounds.width, height: height)
        titleLabel.autoresizingMask = [.flexibleWidth]
    }

    fileprivate func attach(to scrollView: UIScrollView) {
        self.scrollView = scrollView
        // initial frame will be set on contentSize changes
        updateFrame()
        scrollView.addSubview(self)

        contentSizeObservation = scrollView.observe(\.contentSize, options: [.new]) { [weak self] _, _ in
            DispatchQueue.main.async { self?.updateFrame() }
        }
        contentOffsetObservation = scrollView.observe(\.contentOffset, options: [.new]) { [weak self] scrollView, _ in
            DispatchQueue.main.async { self?.scrollViewDidScroll(scrollView) }
        }
    }

    fileprivate func detach() {
        contentOffsetObservation?.invalidate()
        contentSizeObservation?.invalidate()
        contentOffsetObservation = nil
        contentSizeObservation = nil
        removeFromSuperview()
    }

    private func updateFrame() {
        guard let sv = scrollView else { return }
        let contentHeight = sv.contentSize.height
        let y = max(contentHeight, sv.bounds.height - sv.adjustedContentInset.top - sv.adjustedContentInset.bottom)
        frame = CGRect(x: 0, y: y, width: sv.bounds.width, height: height)
    }

    private func scrollViewDidScroll(_ scrollView: UIScrollView) {
        guard enabled, state != .loading, state != .allLoaded else { return }
        let offsetY = scrollView.contentOffset.y + scrollView.bounds.height - scrollView.adjustedContentInset.bottom
        let contentHeight = scrollView.contentSize.height

        // if scrolled near bottom
        if offsetY > contentHeight + triggerOffset {
            if scrollView.isDragging {
                setState(.triggered)
            } else if state == .triggered {
                startAnimating()
            }
        } else {
            setState(.stopped)
        }
    }

    public func setState(_ newState: InfiniteScrollingState) {
        guard state != newState else { return }
        state = newState
        switch state {
        case .stopped:
            activity.stopAnimating()
            titleLabel.text = ""
            // reset content inset bottom if we modified it
            resetScrollViewBottomInset()
        case .triggered:
            titleLabel.text = "Release to load more"
        case .loading:
            titleLabel.text = "Loading..."
            activity.startAnimating()
            // increase bottom inset to show spinner (optional)
            if let sv = scrollView {
                var inset = sv.contentInset
                inset.bottom += height
                UIView.animate(withDuration: 0.25) {
                    sv.contentInset = inset
                }
            }
            actionHandler?()
        case .allLoaded:
            activity.stopAnimating()
            titleLabel.text = "No more content"
        }
    }

    public func startAnimating() {
        setState(.loading)
    }

    public func stopAnimating() {
        setState(.stopped)
    }

    public func setAllLoaded(_ allLoaded: Bool) {
        setState(allLoaded ? .allLoaded : .stopped)
    }

    private func resetScrollViewBottomInset() {
        guard let sv = scrollView else { return }
        // For simplicity, animate bottom inset back by height if it was added previously
        UIView.animate(withDuration: 0.25) {
            sv.contentInset.bottom = max(sv.contentInset.bottom - self.height, 0)
        }
    }
}


// MARK: - UIScrollView extension for InfiniteScrolling

@MainActor private var infiniteScrollingKey: UInt8 = 0

public extension UIScrollView {
    var infiniteScrollingView: InfiniteScrollingView? {
        get { objc_getAssociatedObject(self, &infiniteScrollingKey) as? InfiniteScrollingView }
        set { objc_setAssociatedObject(self, &infiniteScrollingKey, newValue, .OBJC_ASSOCIATION_RETAIN_NONATOMIC) }
    }

    /// Add infinite-scrolling handler. Will be called when user scrolls near bottom.
    func addInfiniteScrolling(action: @escaping () -> Void) {
        removeInfiniteScrolling()
        let view = InfiniteScrollingView(frame: .zero, handler: action)
        view.attach(to: self)
        infiniteScrollingView = view
    }

    func triggerInfiniteScrolling() {
        infiniteScrollingView?.startAnimating()
    }

    func stopInfiniteScrolling() {
        infiniteScrollingView?.stopAnimating()
    }

    func setInfiniteScrollingAllLoaded(_ allLoaded: Bool) {
        infiniteScrollingView?.setAllLoaded(allLoaded)
    }

    func removeInfiniteScrolling() {
        infiniteScrollingView?.detach()
        infiniteScrollingView = nil
    }
}
