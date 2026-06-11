import AppKit
import Combine
import SwiftUI

@MainActor
final class SplitViewController: NSSplitViewController {
    let viewModel: MainViewModel
    private var sidebarSplitItem: NSSplitViewItem!
    private var detailSplitItem: NSSplitViewItem!
    private var cancellables = Set<AnyCancellable>()
    private var sidebarAutoHidden = false
    /// While set in the future, suppresses the cramped-window auto-hide. Set
    /// when the user explicitly opens the sidebar so the resize callbacks fired
    /// by the open animation can't immediately slam it shut again.
    private var suppressAutoHideUntil: Date = .distantPast

    init(viewModel: MainViewModel) {
        self.viewModel = viewModel
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        let sidebarHC = NSHostingController(
            rootView: SidebarView(viewModel: viewModel)
        )
        let detailHC = NSHostingController(
            rootView: DetailContentView(viewModel: viewModel)
        )

        sidebarSplitItem = NSSplitViewItem(sidebarWithViewController: sidebarHC)
        sidebarSplitItem.canCollapse = true
        sidebarSplitItem.minimumThickness = 220
        sidebarSplitItem.maximumThickness = 400

        detailSplitItem = NSSplitViewItem(viewController: detailHC)

        addSplitViewItem(sidebarSplitItem)
        addSplitViewItem(detailSplitItem)

        // Bidirectional sync: viewModel.isSidebarVisible ↔ sidebarSplitItem.isCollapsed
        viewModel.$isSidebarVisible
            .dropFirst()
            .receive(on: DispatchQueue.main)
            .sink { [weak self] visible in
                self?.syncSplitView(visible: visible)
            }
            .store(in: &cancellables)

        // Initial state: collapse if viewModel says hidden
        if !viewModel.isSidebarVisible {
            sidebarSplitItem.isCollapsed = true
        }
    }

    // MARK: - viewModel → split view

    private func syncSplitView(visible: Bool) {
        let collapsed = sidebarSplitItem.isCollapsed
        if visible == collapsed {
            // An explicit open must win over the cramped-window auto-hide for
            // the duration of the toggle animation; otherwise the resize
            // callbacks it triggers would re-hide the sidebar on narrow windows.
            if visible {
                sidebarAutoHidden = false
                suppressAutoHideUntil = Date().addingTimeInterval(0.7)
            }
            toggleSidebar(sidebarSplitItem)
        }
    }

    // MARK: - split view → viewModel

    override func splitViewDidResizeSubviews(_ notification: Notification) {
        super.splitViewDidResizeSubviews(notification)

        guard let sidebarSplitItem else { return }

        // Read actual sidebar width from the view controller's view (not
        // splitView.subviews[0] which is fragile on macOS 26 with Liquid Glass).
        if !sidebarSplitItem.isCollapsed {
            let width = sidebarSplitItem.viewController.view.frame.width
            if width >= sidebarSplitItem.minimumThickness {
                viewModel.sidebarWidth = width
            }
        }

        // Auto-hide when main pane would get too cramped; restore with hysteresis.
        let totalWidth = splitView.frame.width
        let sidebarW =
            sidebarSplitItem.isCollapsed
            ? viewModel.sidebarWidth
            : sidebarSplitItem.viewController.view.frame.width
        let minMainPane: CGFloat = 380
        let restoreSlack: CGFloat = 40

        // Honour a just-issued explicit open: don't auto-hide mid-animation.
        if Date() < suppressAutoHideUntil { return }

        if !sidebarSplitItem.isCollapsed, totalWidth < sidebarW + minMainPane {
            sidebarAutoHidden = true
            viewModel.isSidebarVisible = false
        } else if sidebarAutoHidden, sidebarSplitItem.isCollapsed,
            totalWidth >= viewModel.sidebarWidth + minMainPane + restoreSlack
        {
            sidebarAutoHidden = false
            viewModel.isSidebarVisible = true
        }
    }
}
