import AppKit
import Combine
import SwiftUI

@MainActor
final class SplitViewController: NSSplitViewController {
    let viewModel: MainViewModel
    private let autoHideSidebarWidth: CGFloat = 760
    private var sidebarSplitItem: NSSplitViewItem!
    private var detailSplitItem: NSSplitViewItem!
    private var cancellables = Set<AnyCancellable>()

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
        // Minimum readable width — dragging below it collapses the sidebar
        // (canCollapse), where the hover-on-left-edge floating mode takes over.
        sidebarSplitItem.minimumThickness = 180
        sidebarSplitItem.maximumThickness = 480
        sidebarSplitItem.canCollapseFromWindowResize = false
        sidebarSplitItem.holdingPriority = .init(260)

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
            toggleSidebar(sidebarSplitItem)
        }
    }

    // MARK: - split view → viewModel

    override func splitViewDidResizeSubviews(_ notification: Notification) {
        super.splitViewDidResizeSubviews(notification)

        guard let sidebarSplitItem else { return }

        if splitView.bounds.width < autoHideSidebarWidth, !sidebarSplitItem.isCollapsed {
            viewModel.isSidebarVisible = false
            return
        }

        // Read actual sidebar width from the view controller's view rather than
        // indexing splitView.subviews, which is fragile across AppKit internals.
        // No auto-hide: the user resizes freely; dragging to zero collapses.
        if !sidebarSplitItem.isCollapsed {
            let width = sidebarSplitItem.viewController.view.frame.width
            if width >= sidebarSplitItem.minimumThickness {
                viewModel.sidebarWidth = width
            }
        }

        // Keep the published flag in sync when the user drag-collapses the
        // sidebar past its minimum (so hover-floating mode activates).
        if sidebarSplitItem.isCollapsed == viewModel.isSidebarVisible {
            viewModel.isSidebarVisible = !sidebarSplitItem.isCollapsed
        }
    }
}
