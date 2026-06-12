# Lessons Learned — UI Refinements & Prompts (2026-06-12)

## 1. SwiftUI Color Resolution under AppKit Appearance Overrides

**Problem:** 
When overriding the system appearance in AppKit (e.g., using `NSApp.appearance = NSAppearance(named: .aqua)` to force a light mode theme), SwiftUI's native semantic colors like `Color.primary` and `Color.secondary` can still resolve based on the system-wide OS color scheme (e.g., returning white/light-gray if the OS is in Dark Mode). 
This mismatch resulted in the calendar's 0-activity grid cells (`Color.primary.opacity(0.06)`) rendering as white-on-white (completely invisible) against the light card background.

**Fix:**
Replaced the system-environment dependent `Color.primary.opacity(...)` with a static gray color `Color.gray.opacity(0.2)`. Because `Color.gray` maintains a constant luminance, it provides reliable contrast against both light and dark card backgrounds regardless of OS color scheme discrepancies.

**Lesson:**
When forcing Light or Dark appearance via AppKit overrides, do not rely on standard SwiftUI semantic color tokens (`Color.primary`, `.secondary`, etc.) for fine-grained components. Instead:
- Use custom AppKit-resolved colors (`NSColor.separatorColor` wrapped in `Color`).
- Use static base colors with appropriate opacity (like `Color.gray.opacity(...)`) to guarantee cross-mode visibility.

---

## 2. Structuring Complex Multi-Column Layouts in SwiftUI

**Problem:**
GitHub-style contribution grids are prone to alignment bugs if implemented as a single continuous list of week columns alongside a separate headers row. Calculating month label widths dynamically (`monthLabelWidth(at:)`) creates spacing mismatches, pushing labels and columns out of sync. Day-of-week labels also shifted upwards, aligning with the month header rather than the actual grid cells. Additionally, anchoring the grid on `Date()` today leaves the current month truncated, hiding future weeks of the active month (e.g. June).

**Fix:**
- Grouped week columns into self-contained `MonthGroup` models, allowing each month label to sit in a vertical stack directly above its respective week columns.
- Separated the layout into a clean month header row (with a left spacer matching the day-labels column width) and the main grid row.
- Added a vertical spacer (`12 + 2` height) at the top of the day-of-week labels stack to push the day labels down, aligning `Mon`, `Wed`, and `Fri` perfectly with the grid cells.
- Anchored the 17-week window calculation on the *last day of the current month* instead of today, retaining future dates belonging to the current month (colored as 0-activity gray cells) and only setting days in future months (e.g., July) to `nil` (clear/invisible).

**Lesson:**
For complex matrix grids with header/sidebar labels:
- Avoid calculating absolute label positions dynamically if they can be grouped natively.
- Group data columns into sub-grids matching the header category (e.g., `MonthGroup`).
- Use layout structure (nested `VStack`/`HStack`) to guarantee alignment by construction, rather than math.
- Extend calendar date-grids to the end of the current month to present complete monthly grids, using date ranges to check if future days belong to the active month.

---

## 3. Overlaying Controls onto the Window Title Bar

**Problem:**
In a collapsible `NSSplitViewController` layout, hiding the sidebar unmounts the sidebar view completely. Consequently, any overlays containing window controls (like toggle and search buttons next to the traffic lights) vanish.

**Fix:**
Overlaid the same toggle and search controls at the `topLeading` edge of `DetailContentView`.
- Used `.ignoresSafeArea(.container, edges: .top)` and a top padding of `4` to position the buttons in the title bar next to the traffic lights.
- Conditionally drew the overlay only when `!viewModel.isSidebarVisible` and `!isHoverSidebarVisible` to prevent overlapping with the docked sidebar or the hover-summoned floating sidebar.

**Lesson:**
To maintain persistent window controls next to macOS traffic lights across screen state changes, replicate the control overlay on the detail view. Always guard the overlay against active navigation states to ensure the controls only draw once and remain interactive.

---

## 4. Honesty in Raw Request Details

**Problem:**
The raw request details overlay only showed the messages payload and base model name, leaving out target API endpoints and request-level configuration parameters.

**Fix:**
Updated `getRawRequestDetails()` to build and return a comprehensive JSON structure that exposes:
- Target completions URL (`target_url`).
- Parameters like `stream`, `stream_options`, and `reasoning_effort`.
- Full system prompts, date/time contexts, and conversation history arrays.

**Lesson:**
Exposing internal LLM request parameters is essential for debugging and transparency. Provide a structured format showing the exact URL endpoint, generation settings, and final assembled system instructions.

---

## 5. Preventing Automatic Keyboard/Key-Loop Focus on Custom Buttons

**Problem:**
On macOS, SwiftUI button elements in the main view hierarchy (such as starter action suggestion cards) are focusable by default. When the window opens, the first button in the view tree (`Summarize`) automatically receives system focus, rendering a thick orange focus/accent border around it.

**Fix:**
Added `.focusable(false)` to the button inside `StarterCard` to exclude it from the system key-loop navigation focus, preventing automatic highlighting on view load.

**Lesson:**
For secondary buttons or card elements that act as content shortcuts, apply `.focusable(false)` to prevent macOS from automatically highlighting the first item when the parent view loads.

---

## 6. Locking Sidebar Width on Content Transitions

**Problem:**
When switching tabs in the sidebar (e.g. Chat -> Preset -> Auto), the view height and contents change (such as swapping a chat history scroll view for an action preset `List`). Because a `List` has a different ideal width on macOS, SwiftUI attempts to resize the hosting view to fit the new content size. This propagates up, dynamically resizing the split pane or the entire window, causing visual jitter.

**Fix:**
Constrained the sidebar view's root layout on macOS using `.frame(width: viewModel.sidebarWidth)`. Since `viewModel.sidebarWidth` tracks the user's manual dragging changes, the frame is locked to the correct user width and does not shrink or expand when content changes.

**Lesson:**
In `NSSplitView` layouts hosting SwiftUI views, always specify a fixed width constraint (`.frame(width:)`) on the sidebar matching the user's current resize state. This prevents subview layout updates from triggering automatic split pane or window resizing.
