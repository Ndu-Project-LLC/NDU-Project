# Select Project KAZ Button - Visual Guide & Examples

## 📱 Visual States & Examples

### 1. Default Button State
```
╔════════════════════════════════════════════════════════╗
║  🧠 Select Project     Choose from 3 solutions →       ║
║  ───────────────────────────────────────────────────── ║
║  Exceptional KAZ AI themed button with gradient        ║
║  Gold & Yellow: #FFC812 → #FFB200                      ║
╚════════════════════════════════════════════════════════╝

Features:
✓ Gradient background (top-left to bottom-right)
✓ Dual shadow layers for depth
✓ KAZ AI icon (psychology_rounded)
✓ Animated shimmer overlay
✓ Professional rounded corners (16dp)
```

### 2. Button Hover/Pressed State
```
╔════════════════════════════════════════════════════════╗
║  🧠 Select Project     Choose from 3 solutions →       ║
║  ◄ Ink splash effect + slight scale down              ║
╚════════════════════════════════════════════════════════╝

States:
• Normal: scale 100%
• Hover: ink ripple visible
• Press: subtle scale reduction
```

### 3. Dialog Opening Animation
```
Step 1: Button pressed          Step 2: Dialog animates in
┌─────────────────────┐        ┌──────────────────────┐
│ 🧠 Select Project → │        │   ▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄   │
│                     │        │  ╱ Dialog appears    ╲  │
└─────────────────────┘        │ ╱  (scale + fade)    ╲  │
                               │╱                      ╲│
                               └──────────────────────┘

Animation:
- Duration: 300ms
- Curve: easeOutBack (spring effect)
- Scale: 95% → 100%
- Opacity: 0% → 100%
```

### 4. Dialog Header - KAZ Themed
```
╔════════════════════════════════════════════════════════╗
║  🧠 KAZ AI Solution Selection                    [×]   ║
║     Pick your preferred approach                       ║
║                                                        ║
║  Choose a project to progress                         ║
║  Pick the solution you want to advance and give your  ║
║  project a memorable name.                            ║
╚════════════════════════════════════════════════════════╝

Style:
- Gradient background: #FFC812 → #FFB200
- White text with transparency layers
- Professional spacing and typography
- Close button (×) in top-right
```

### 5. Solution Card - Unselected State
```
╔════════════════════════════════════════════════════════╗
║  ◯ Digital Transformation                             ║
║                                                        ║
║    Modernize infrastructure and enhance customer      ║
║    experience with modern technology solutions        ║
╚════════════════════════════════════════════════════════╝

Style:
- Circular selection indicator (empty)
- Light gray border (#E5E7EB)
- White background
- Title in bold text
- Description in secondary color
```

### 6. Solution Card - Selected State
```
╔════════════════════════════════════════════════════════╗
║  ⊙ Digital Transformation                         →    ║
║    [Gold border highlight]                            ║
║    Modernize infrastructure and enhance customer      ║
║    experience with modern technology solutions        ║
╚════════════════════════════════════════════════════════╝

Style:
- Filled selection indicator (gold circle)
- Gold border (2px) #FFC812
- Cream background #FFF8DC
- Gold arrow indicator
- Box shadow for depth
- Title in gold color
```

### 7. Project Name Input Field
```
Normal State:
┌────────────────────────────────────────────┐
│ Project name                               │
├────────────────────────────────────────────┤
│ Enter project name                         │ ← hint text
└────────────────────────────────────────────┘

Focus State:
┌════════════════════════════════════════════┐
│ Project name                               │
├════════════════════════════════════════════┤
│ E│ ← cursor position, gold border          │
└════════════════════════════════════════════┘

Error State:
┌────────────────────────────────────────────┐
│ Project name                               │
├────────────────────────────────────────────┤
│ [empty]                                    │
└────────────────────────────────────────────┘
  ⚠ Project name is required
```

### 8. Action Buttons
```
╔════════════════════════════════════════════╗
║  [Cancel]              [✓ Select Solution]  ║
║  ┌──────────────────┐  ┌───────────────┐  ║
║  │ Outlined Button  │  │ Gradient Btn   │  ║
║  │ Light gray text  │  │ White text     │  ║
║  │ Subtle border    │  │ Gold gradient  │  ║
║  │ Hover: ripple    │  │ Shadow effect  │  ║
║  └──────────────────┘  └───────────────┘  ║
╚════════════════════════════════════════════╝
```

## 🎬 Complete Dialog Flow

### Mobile Layout (< 600px)
```
┌─────────────────────────────────────────────┐
│                                             │
│    ╔═════════════════════════════════════╗  │
│    ║ 🧠 KAZ AI Solution Selection    [×]║  │
│    ║ Pick your preferred approach        ║  │
│    ║                                     ║  │
│    ║ Choose a project to progress        ║  │
│    ║ Pick the solution you want...       ║  │
│    ╠═════════════════════════════════════╣  │
│    ║ Available Solutions                 ║  │
│    ║                                     ║  │
│    ║ ◯ Digital Transformation            ║  │
│    ║   Modernize infrastructure...       ║  │
│    ║                                     ║  │
│    ║ ⊙ Cloud Migration          →        ║  │ ← Selected
│    ║   Move to cloud-based systems...    ║  │
│    ║                                     ║  │
│    ║ ◯ AI Integration                    ║  │
│    ║   Implement AI-powered solutions... ║  │
│    ║                                     ║  │
│    ║ Project Name                        ║  │
│    ║ ┌───────────────────────────────┐  ║  │
│    ║ │ Cloud Migration Initiative    │  ║  │
│    ║ └───────────────────────────────┘  ║  │
│    ║                                     ║  │
│    ║ [Cancel]  [✓ Select Solution]       ║  │
│    ╚═════════════════════════════════════╝  │
│                                             │
└─────────────────────────────────────────────┘
```

### Desktop Layout (> 600px)
```
┌───────────────────────────────────────────────────────────┐
│                                                           │
│        ╔═══════════════════════════════════════╗          │
│        ║ 🧠 KAZ AI Solution Selection      [×] ║          │
│        ║ Pick your preferred approach          ║          │
│        ║                                       ║          │
│        ║ Choose a project to progress          ║          │
│        ║ Pick the solution you want...         ║          │
│        ╠═══════════════════════════════════════╣          │
│        ║ Available Solutions                   ║          │
│        ║                                       ║          │
│        ║ ◯ Digital Transformation              ║          │
│        ║   Modernize infrastructure and...     ║          │
│        ║                                       ║          │
│        ║ ⊙ Cloud Migration          →          ║ Selected │
│        ║   Move to cloud-based systems for...  ║          │
│        ║                                       ║          │
│        ║ ◯ AI Integration                      ║          │
│        ║   Implement AI-powered solutions for..║          │
│        ║                                       ║          │
│        ║ Project Name                          ║          │
│        ║ ┌─────────────────────────────────┐  ║          │
│        ║ │ Cloud Migration Initiative      │  ║          │
│        ║ └─────────────────────────────────┘  ║          │
│        ║                                       ║          │
│        ║ [Cancel]     [✓ Select Solution]      ║          │
│        ╚═══════════════════════════════════════╝          │
│                                                           │
└───────────────────────────────────────────────────────────┘
```

## 🎨 Color Reference Guide

### Primary Colors (KAZ AI Theme)
```
Button Gradient:
┌──────────────┐
│ Start: #FFC812│  (Bright Yellow)
│  ▼▼▼▼▼▼▼▼▼▼  │  Smooth transition
│ End:  #FFB200│  (Gold)
└──────────────┘

Shadow Colors:
┌────────────────────────┐
│ Top Shadow             │
│ #FFC812 with 40% alpha│  (Yellow glow)
│                        │
│ Bottom Shadow          │
│ #FFB200 with 20% alpha│  (Gold fade)
└────────────────────────┘
```

### Selected Card Colors
```
Border:          #FFC812 (Gold, 2px)
Background:      #FFF8DC (Cream - very light yellow)
Text (title):    #FFC812 (Gold)
Arrow:           #FFC812 (Gold)
Shadow:          #FFC812 with 15% opacity
```

### Typography Hierarchy
```
Dialog Title:
  Font Size: 20px
  Font Weight: W700 (Bold)
  Color: White

Subtitle:
  Font Size: 14px
  Font Weight: W500
  Color: White (82% opacity)

Card Title:
  Font Size: 14px
  Font Weight: W700 (Bold)
  Color: Black87 (or Gold if selected)

Card Description:
  Font Size: 12px
  Font Weight: W400 (Regular)
  Color: Black54
  Max Lines: 2

Input Field Hint:
  Font Size: 14px
  Font Weight: W400
  Color: Gray (50% opacity)
```

## ⚡ Animation Timings

### Button Scale Animation
```
Duration:     300ms
Start Scale:  95%
End Scale:    100%
Curve:        easeOutBack (spring effect)

Visual Effect:
 95%   →   100%
 ╲       ╱
  ╲     ╱
   ╲   ╱
    ╲ ╱
     ▼
   (finished)
```

### Dialog Entry Animation
```
Fade In:
  Duration: 300ms
  Curve: easeOut
  0% opacity → 100% opacity

Scale In (from bottom-right):
  Duration: 300ms
  Curve: easeOutBack
  Scale: 0.95 → 1.0
  Origin: Alignment.bottomRight
```

### Card Transition Effects
```
Unselected → Selected:
  Border: Gray → Gold (animated)
  Background: White → Cream (instant)
  Shadow: None → Gold shadow (animated)
  Arrow appears: Fade + Scale in

Selected → Unselected:
  Reverse animation
```

## 📏 Spacing & Sizing

### Button Dimensions
```
Height:         56dp (Material standard)
Border Radius:  16dp
Padding:        Symmetric H:16, V:12
Icon Size:      24dp (psychology icon)
Text Size:      14px (primary) + 11px (secondary)
```

### Dialog Dimensions
```
Width:          540dp (desktop) / Full - 32dp (mobile)
Header Height:  Auto (content-based, ~160dp typical)
Content Area:   Max height 360dp (scrollable if needed)
Footer Height:  ~80dp (buttons + spacing)
Border Radius:  24dp
Padding:        All 24dp
```

### Card Spacing
```
Card Margin:    Bottom 12dp
Card Padding:   All 16dp
Selection Icon: 24dp × 24dp
Icon Spacing:   Right 12dp from content
Arrow Icon:     16dp × 16dp (right side)
Content Gap:    Top 4dp (title to description)
```

## ✨ Shimmer Effect

### Overlay Animation
```
Positioned.fill (covers entire button):
  Gradient:
    Start: White with 15% opacity (top-left)
    End:   White with 5% opacity (bottom-right)
  
Effect: Subtle glass-like shimmer on button surface
```

## 🎯 Interactive Feedback States

### Button States
```
Normal:       Scale 100%, Opacity 100%, Color normal
Hover:        Ink ripple effect (Material standard)
Pressed:      Scale 98%, Opacity 95%
Disabled:     Gray color, Opacity 60%
```

### Card States
```
Normal:       White bg, Gray border, no shadow
Hover:        Light shadow appears, border highlight
Selected:     Cream bg, Gold border, Gold shadow
Focused:      Gold border (2px), shadow active
```

### Input Field States
```
Normal:       White fill, gray border (1px)
Focused:      White fill, gold border (2px)
Typing:       White fill, gold border (2px), cursor visible
Error:        White fill, gray border + error message
Filled:       White fill, gray border, content visible
```

---

## 🎭 User Journey Visualization

```
USER SEES SCREEN
       ↓
┌─────────────┐
│ SELECT      │ ← User taps button
│ PROJECT     │   (scale animation: 95% → 100%)
│ button      │
└─────────────┘
       ↓
   DIALOG OPENS
   (fade + scale animation)
       ↓
  ┌────────────────┐
  │ • Solution 1   │
  │ • Solution 2   │ ← User taps a solution
  │ • Solution 3   │   (card highlights: White → Cream)
  └────────────────┘
       ↓
  ┌────────────────┐
  │ Project Name   │ ← User enters project name
  │ [input field]  │   (focus: border gray → gold)
  └────────────────┘
       ↓
┌──────────────┐  ┌─────────────────┐
│[Cancel]      │  │[✓ Select Solution]│ ← User confirms
└──────────────┘  └─────────────────┘
       ↓
  onSolutionSelected callback triggered
       ↓
  SELECTION COMPLETE ✓
```

---

This comprehensive visual guide shows every state, size, color, and animation in the SelectProjectKazButton component. Use it as reference for implementation and testing!
