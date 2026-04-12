# macOS Human Interface Guidelines - Knowledge Base

> Based on Apple's Human Interface Guidelines (HIG)
> Version: 2024-2026

## Table of Contents
1. [Platform Characteristics](#platform-characteristics)
2. [Design Principles](#design-principles)
3. [Visual Design](#visual-design)
4. [Typography](#typography)
5. [Color & Materials](#color--materials)
6. [Layout &Spacing](#layout--spacing)
7. [Navigation](#navigation)
8. [Windows](#windows)
9. [Menu Bar](#menu-bar)
10. [Components](#components)
11. [Buttons](#buttons)
12. [Menus](#menus)
13. [Progress Indicators](#progress-indicators)
14. [Pickers & Steppers](#pickers--steppers)
15. [Popovers](#popovers)
16. [Split Views](#split-views)
17. [Accessibility](#accessibility)
18. [WWDC25 Updates](#wwdc25-updates)

---

## 1. Platform Characteristics

### Display
- **Large, high-resolution displays** - Design for pixel-perfect rendering
- **Multiple monitor support** - Enable window movement between displays
- **Resizable windows** - Let users control their workspace

### Ergonomics
- **Stationary use** - Users typically seated at desk, 1-3 feet from screen
- **Precise input** - Mouse/trackpad enable pixel-perfect selections
- **Longer sessions** - Support both quick tasks and hours-long workflows

### Input Modes
- **Keyboard** - Primary input; include shortcuts
- **Mouse/Trackpad** - Precision pointing
- **Touch** - Optimize for Click & Trackpad, not touch (MacBooks)
- **Voice** - Voice Control accessibility
- **Custom** - Support third-party input devices

### macOS-Specific Features
- **Menu Bar** - Primary command access
- **Finder** - File navigation
- **Mission Control** - Window management
- **Dock** - Quick access to apps
- **Stage Manager** - Window tiling/organization

---

## 2. Design Principles

### Core Principles

| Principle | Description |
|-----------|-------------|
| **Clarity** | Interface elements should be immediately understandable. Text legible at all sizes. Icons immediately recognizable. |
| **Deference** | UI should defer to content. Chrome and controls recede from focus. |
| **Depth** | Visual layers communicate hierarchy. Translucency hints at content beneath. |
| **Consistency** | Familiar patterns reduce learning curve. Use standard components. |

### Application to macOS

```
┌─────────────────────────────────────────────────────────────┐
│  DEFERENCE: Content First                                   │
│  ┌─────────────────────────────────────────────────────┐    │
│  │                                                     │    │
│  │   ┌─────────────────────────────────────────────┐    │    │
│  │   │         MAIN CONTENT AREA                  │    │    │
│  │   │         (Defer to this)                   │    │    │
│  │   │                                             │    │    │
│  │   └─────────────────────────────────────────────┘    │    │
│  │                                                     │    │
│  │   Sidebar/Controls (Minimize chrome)              │    │
│  └─────────────────────────────────────────────────────┘    │
│  Menu Bar (Commands)                                         │
└─────────────────────────────────────────────────────────────┘
```

---

## 3. Visual Design

### Color System

| Color Category | Usage |
|---------------|-------|
| **Label Colors** | Primary (#000), Secondary (#3c3c43 60%), Tertiary (#3c3c43 30%) |
| **Fill Colors** | System fills, grouped backgrounds |
| **SF Symbols** | Template (auto) vs. Multicolor |

### Dark Mode
- Use semantic colors (`.label`, `.background`)
- Test both light and dark appearances
- Don't force specific appearance

### Materials (macOS 26+)
- **Liquid Glass** - New translucent material
- Adjust translucency based on window depth
- Respect user's transparency settings

### Spacing System (8pt Grid)

```
┌──────────────────────────────────────────┐
│  Margins:  16pt, 20pt, 24pt              │
│  ┌──────────────────────────────────┐   │
│  │  Grid:  8pt baseline              │   │
│  │  Spacing: 8, 16, 24, 32...        │   │
│  └──────────────────────────────────┘   │
│  Content padding minimum 16pt              │
└──────────────────────────────────────────┘
```

---

## 4. Typography

### Font Family
- **SF Pro** - System font for iOS, iPadOS, macOS, tvOS
- **SF Compact** - watchOS, small sizes
- **SF Mono** - Code alignment
- **New York** - Serif headlines

### Type Scale

| Style | Size | Weight | Usage |
|-------|------|--------|-------|
| Large Title | 34pt | Bold | Window titles |
| Title 1 | 28pt | Bold | Section headers |
| Title 2 | 22pt | Bold | Subsection |
| Title 3 | 20pt | Semibold | Group headers |
| Headline | 17pt | Semibold | List items |
| Body | 17pt | Regular | Paragraphs |
| Callout | 16pt | Regular | Emphasis |
| Subheadline | 15pt | Regular | Secondary text |
| Footnote | 13pt | Regular | Captions |
| Caption 1 | 12pt | Regular | Labels |
| Caption 2 | 11pt | Regular | Fine print |

### Best Practices
- Use SF Pro at natural sizes
- Maintain legible contrast (minimum 4.5:1)
- Don't compress or expand fonts

---

## 5. Layout & Spacing

### Window Layout

```
┌─────────────────────────────────────────────────────────────┐
│  Toolbar (optional, 38-52pt height)                       │
├─────────────┬─────────────────────────────────────────────┤
│             │                                             │
│   Sidebar   │              Content Area                   │
│  200-300pt  │           (flexible)                        │
│             │                                             │
│   (250pt    │            NSSplitView                       │
│   default)  │                                             │
│             │                                             │
├─────────────┴─────────────────────────────────────────────┤
│  Status Bar (optional, 24pt height)                         │
└─────────────────────────────────────────────────────────────┘
```

### Spacing Guidelines

| Element | Spacing |
|---------|----------|
| Window margins | 20pt |
| Control groups | 16pt |
| List items | 12pt vertical |
| Icon + Label | 8pt |
| Button padding | 12pt horizontal, 8pt vertical |

### Responsive Behavior
- Minimum window size: 400x300pt
- Let users resize freely
- Support full-screen mode

---

## 6. Navigation

### Navigation Patterns

```
┌─────────────────────────────────────────────────────────────┐
│ Tab Bar (top)                                              │
│ ┌──────┬──────┬──────┬──────┐                            │
│ │ Tab1 │ Tab2 │ Tab3 │ Tab4 │                            │
│ └──────┴──────┴──────┴──────┘                            │
├────────────────────┬──────────────────────────────────────┤
│ Sidebar (optional) │ Content                                │
│                   │                                        │
│ • Item 1          │ ┌────────────────────────────────────┐ │
│ • Item 2          │ │ Content View                      │ │
│ • Item 3          │ │                                    │ │
│   ├─ Sub-item     │ │                                    │ │
│   └─ Sub-item     │ │                                    │ │
│ • Item 4          │ └────────────────────────────────────┘ │
└────────────────────┴──────────────────────────────────────┘
```

### Patterns by Use Case

| Pattern | Best For |
|---------|----------|
| **Tab Bar** | Top-level navigation (≤5 tabs) |
| **Sidebar** | Hierarchy navigation, iPad-style |
| **Toolbar** | Context-sensitive actions |
| **Segmented Control** | Related views, filters |

### Sidebar Guidelines
- Width: 200-300pt (250pt default)
- Collapsible: Allow user to hide
- Sections: Use disclosure triangles for hierarchy

---

## 7. Windows

### Window Types

| Type | Purpose | Modal? |
|------|---------|--------|
| **Standard** | Main content | No |
| **Sheet** | Focused task | Yes |
| **Panel** | Inspector/tools | Yes |
| **Alert** | Critical info | Required |

### Window Behavior

```
┌─────────────────────────────────────────────┐
│  Title Bar                                 │
│  ┌─────┐ ┌─────────────┐ ┌─────┐ ┌────────┐  │
│  │ ◂  │ │ Title      │ │Zoom │ │ Close │  │
│  └──┬──┘ └─────────────┘ └──┬──┘ └───┬───┘  │
│     │                        │        │      │
│ Window Controls (left)       │  Window Controls (right)    │
└─────────────────────────────────────────────┘
```

### Guidelines
- **Resize**: Support all directions
- **Minimum Size**: Set appropriate minimums
- **Full Screen**: Enable with menu or tap gesture
- **Close Behavior**: Follow system defaults
- **Zoom**: Expand to fit screen content

---

## 8. Menu Bar

### Structure

```
┌────────────────────────────────────────────────────────┐
│ Apple Menu │ App Name    │ File  Edit View... │ Help   │
├────────────────────────────────────────────────────────┤
│ [App Menu]                              │ [Status Items] │
└────────────────────────────────────────────────────────┘
```

### Menu Organization

| Menu | Contents |
|------|----------|
| **Apple** | System items, About, Preferences, Quit |
| **App Name** | About, Preferences (⌘,) |
| **File** | New (⌘N), Open (⌘O), Close (⌘W), Save (⌘S) |
| **Edit** | Undo (⌘Z), Redo (⇧⌘Z), Cut/Copy/Paste |
| **View** | Show/Hide Sidebar, Enter Full Screen |
| **Window** | Minimize, Zoom, Arrange |
| **Help** | Search (⌘?) |

### Keyboard Shortcuts
- **Accelerate actions** - Every menu item should have shortcut
- **Standard shortcuts** - Use common conventions
- **Symbol meanings**: ⌘ Cmd, ⌥ Option, ⇧ Shift, ⌃ Control

---

## 9. Components

### Buttons

| Style | Use Case |
|-------|----------|
| **Push** | Common actions |
| **Bordered** | Secondary importance |
| **Borderless** | Toolbar, inline |
| **Text** | Links, inline actions |

### Button Placement
- Primary action: Right side
- Cancel: Left of default button
- Sheet: "Cancel" left, "OK" right

### Controls Reference

| Component | macOS Class | Notes |
|-----------|------------|-------|
| Button | NSButton | 4 styles |
| Text Field | NSTextField | Single/multi-line |
| Table View | NSTableView | Lists |
| Outline View | NSOutlineView | Hierarchies |
| Pop-up Button | NSPopUpButton | Dropdown |
| Slider | NSSlider | Continuous |
| Checkbox | NSButton (switch) | Toggle |
| Segmented Control | NSSegmentedControl | Grouped options |

### Interactive Behaviors
- Hover effects for clickable elements
- Focus rings for keyboard navigation
- Drag-and-drop support where appropriate

---

## 10. Buttons

### Button Styles (macOS vs iOS)

| Platform | Shape | Use Case |
|----------|-------|----------|
| **macOS** | Rounded Rectangle | High-density layouts, inspector panels |
| **iOS/iPadOS** | Capsule | Standout actions, large touch targets |

### macOS Button Types

| Style | SwiftUI | Description |
|-------|---------|------------|
| **Push** | `.bordered` | Standard filled button |
| **Bordered** | `.bordered` | Secondary importance |
| **Borderless** | `.borderless` | Toolbar, inline |
| **Text** | `.plain` | Links, inline actions |
| **Prominent** | `.borderedProminent` | Primary action, tinted |

### Button Sizing

```
┌─────────────────────────────────────────────┐
│  Control Sizes                              │
│  ┌─────────┐  Small (24pt)                 │
│  ┌─────────┐  Medium (28pt) - macOS default │
│  ┌─────────┐  Large (36pt)                 │
│  ┌─────────┐  Extra Large (44pt) - iOS     │
└─────────────────────────────────────────────┘
```

### Primary Button Placement

- **Primary action**: Right side, tinted (blue checkmark on iOS, prominent text on macOS)
- **Cancel**: Left of default button
- **Sheet**: "Cancel" left, "OK" right
- **Toolbar**: Group related actions together

### Button Hierarchy (WWDC25)

> Don't rely on decoration. Hierarchy should be expressed through layout and grouping.

- Use layout spacing to distinguish primary vs secondary
- Avoid custom backgrounds/borders for hierarchy
- Primary action: tinted, prominent
- Secondary actions: plain text or bordered

---

## 11. Menus

### Menu Best Practices

| Guideline | Implementation |
|----------|----------------|
| **Symbols + Text** | Use SF Symbols where they aid recognition |
| **Group by Function** | Related actions together |
| **Frequency** | Most-used items at top |
| **No Mixed Content** | Don't group symbols with text |

### Menu Organization

```
┌─────────────────────────────────────────────┐
│  Tracker Menu (Example)                    │
├─────────────────────────────────────────────┤
│  ▶ Start Listening    ⌘⇧S                 │
│  ▶ Stop Listening     ⌘⇧X                 │
├─────────────────────────────────────────────┤
│  ▶ Recenter          ⌘R                   │
├─────────────────────────────────────────────┤
│  ▶ Settings...      ⌘,                    │
└─────────────────────────────────────────────┘
```

### Keyboard Shortcuts

- **Required** - Every menu item should have a shortcut
- **Accelerate** - Shortcuts speed up workflows
- **Standard conventions**: ⌘ Cmd, ⌥ Option, ⇧ Shift, ⌃ Control

---

## 12. Accessibility

### Required Features

| Feature | Implementation |
|---------|----------------|
| **VoiceOver** | Accessible labels, traits |
| **Keyboard Navigation** | Full keyboard access |
| **Dynamic Type** | Respect user text size |
| **Color Contrast** | Minimum 4.5:1 ratio |
| **Reduced Motion** | Respect `NSLayoutFittingSpeed` |

### Accessibility Checklist

```swift
// Image accessibility
image.accessibilityLabel = "Profile photo"
image.accessibilityTraits = .image

// Control accessibility  
button.accessibilityLabel = "Start tracking"
button.accessibilityHint = "Double click to begin"

// Custom element
element.setAccessibilityElement(true, 
                           label: "Heading", 
                           traits: .header)
```

---

## 13. WWDC25 Updates

### New Design System (2025+)

Apple introduced major design system updates at WWDC25 focused on **cohesion at scale**.

### Liquid Glass

> The most extensive software design update we've ever made.

- **Translucent material** for bars, sidebars, controls
- **Automatic depth** adaption based on window position
- **macOS**: Hard edge effect (stronger, more opaque boundary)
- **iOS/iPadOS**: Soft edge effect (subtle transition)

### Scroll Edge Effects

| Style | Platform | Use Case |
|-------|----------|----------|
| **Soft** | iOS/iPadOS | Default, buttons, inputs with Liquid Glass |
| **Hard** | macOS | Interactive text, controls without materials |

- One scroll edge effect per view
- In Split View, each pane can have its own (keep consistent in height)

### Sidebars (WWDC25)

- Now extend to edge with Liquid Glass
- Content can flow behind for immersive feel
- Scroll views extend beneath sidebar by default

### Button Shapes (WWDC25)

| Platform | Shape | Guidelines |
|----------|-------|------------|
| **macOS** | Rounded Rectangle | Compact, high-density layouts |
| **iOS Large** | Capsule | Standout actions only |
| **iOS Mini/Small/Medium** | Rounded Rectangle | High-density layouts |

### Bar Item Grouping

- Group by **function** and **frequency**
- Related actions together
- **Don't mix symbols with text** (perceived as single button)
- Secondary actions → menus to keep bars clean

### Navigation Continuity

- Components should support **same core interactions** across platforms
- Tab bars, segmented controls, sidebars all signal **selection** consistently
- Structure scales, behavior persists

### Content Hierarchy

> Instead of relying on decoration, hierarchy should be expressed through layout and grouping.

- Use layout spacing, not custom backgrounds
- Primary action: tinted/prominent, separate placement
- Secondary actions: grouped, less prominent

### Updated Typography

- SF Pro remains system font
- Avoid custom fonts - use SF family
- Maintain 4.5:1 minimum contrast

### Resources

- [WWDC25: Get to know the new design system](https://developer.apple.com/videos/play/wwdc2025/356/)
- [Apple Style Guide 2025](https://help.apple.com/pdf/applestyleguide/en_US/apple-style-guide.pdf)

---

## 15. Progress Indicators

### Purpose
Show that a task is incomplete but advancing toward completion.

### Types

| Type | Use Case |
|------|----------|
| **Determinate** | Known progress percentage (0-100%) |
| **Indeterminate** | Unknown duration, spinning indicator |

### SwiftUI Implementation

```swift
// Indeterminate (spinner)
ProgressView("Loading...")

// Determinate with percentage
ProgressView(value: 0.25) // 25% complete
ProgressView(value: progress, total: 100.0)

// Circular (macOS preferred)
ProgressView()
    .progressViewStyle(.circular)
```

### Best Practices
- Use determinate when you know completion %
- Use indeterminate for unknown duration tasks
- Don't block user interaction unnecessarily
- Provide label/context for progress

---

## 16. Pickers & Steppers

### Pickers

| Style | Use Case |
|------|----------|
| **MenuPickerStyle** | Long lists, menus |
| **WheelPickerStyle** | Scrolling wheel (iOS) |
| **SegmentedPickerStyle** | Few options |
| **PopUpPickerStyle** | macOS native |

### Steppers

Use for small incremental changes (±1 per tap):

```swift
Stepper(value: $quantity, in: 1...10) {
    Text("Quantity: \(quantity)")
}

Stepper(value: $brightness, in: 0...100, step: 5) {
    Text("Brightness")
}
```

### Guidelines
- **Stepper**: Small precise increments (±1, ±5, ±10)
- **Slider**: Continuous ranges
- **Picker**: Many options or selection from list

---

## 17. Popovers

### Purpose
Present content in a floating panel anchored to an element.

### SwiftUI Implementation

```swift
Button("Show Popover") {
    showingPopover = true
}
.popover(isPresented: $showingPopover) {
    VStack {
        Text("Popover Content")
        Button("Close") { showingPopover = false }
    }
    .padding()
}
```

### Guidelines
- Appears above content on macOS
- Dismiss by clicking outside
- Keep content brief
- Use for contextual information

---

## 18. Split Views

### NavigationSplitView (macOS 13+)

The modern replacement for NavigationView:

```swift
NavigationSplitView {
    // Sidebar - primary navigation
    List("Users", "Messages", "Settings", id: \.selection)
} detail: {
    // Detail content
    DetailView(selection: selection)
}
```

### HSplitView (Traditional)

For fixed two-column layouts:

```swift
HSplitView {
    SidebarView()
    DetailView()
}
```

### Comparison

| Component | Platform | Use Case |
|-----------|----------|---------|
| **NavigationSplitView** | iOS 16+, macOS 13+ | Adaptive, multi-column |
| **HSplitView** | All | Fixed columns |

### Best Practices
- Use NavigationSplitView for adaptive layouts
- Support sidebar collapse on small screens
- Use .navigationSplitViewStyle(.balanced)

---

## Quick Reference Card

### Do ✅
- Use standard UI components
- Support keyboard shortcuts (every menu item)
- Enable window resize
- Implement VoiceOver labels
- Test Dark Mode
- Use rounded rectangles on macOS
- Use layout for hierarchy, not decoration

### Don't ❌
- Custom window chrome
- Force appearance modes
- Ignore keyboard navigation
- Use non-SF fonts
- Block system gestures
- Mix symbols with text in menus
- Rely on decoration for hierarchy

---

## Resources

- [Apple HIG](https://developer.apple.com/design/human-interface-guidelines)
- [SF Symbols](https://developer.apple.com/sf-symbols)
- [macOS UI Kit](https://developer.apple.com/design/resources)
- [SF Pro Font](https://developer.apple.com/fonts)
- [WWDC25 Design System](https://developer.apple.com/videos/play/wwdc2025/356/)
- [Apple Style Guide 2025](https://help.apple.com/pdf/applestyleguide/en_US/apple-style-guide.pdf)

---

*Last Updated: April 2026*
*Version: macOS Tahoe 26+ / WWDC25+*