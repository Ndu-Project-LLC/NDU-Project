# Select Project KAZ Button - Integration Guide

## Overview
The `SelectProjectKazButton` is an **exceptional, world-class UI component** styled with the KAZ AI chat bubble theme. It provides a beautiful, animated button that opens a dialog allowing users to choose one of three potential solutions and name their project.

## Features
✨ **World-Class Design**
- Gradient background matching KAZ AI yellow/gold theme
- Smooth scale animations with ease-out-back curve
- Multiple shadow layers for depth and dimension
- Responsive design for mobile and desktop

🎨 **Visual Excellence**
- Animated shimmer effect overlay
- Rounded corners with professional border radius
- Accessibility-first design with proper contrast ratios
- Beautiful solution cards with selection states

⚡ **Interactive Elements**
- Smooth transitions between states
- Interactive solution card selection
- Project name validation
- Animated confirmation dialogs

## Usage Example

### Basic Implementation
```dart
import 'package:ndu_project/widgets/select_project_kaz_button.dart';

// Create solution options
final solutions = [
  _SolutionOption(
    title: 'Digital Transformation',
    description: 'Modernize infrastructure and enhance customer experience',
  ),
  _SolutionOption(
    title: 'Cloud Migration',
    description: 'Move to cloud-based systems for better scalability',
  ),
  _SolutionOption(
    title: 'AI Integration',
    description: 'Implement AI-powered solutions for operational efficiency',
  ),
];

// Add button to your screen
SelectProjectKazButton(
  solutions: solutions,
  onSolutionSelected: (selectedSolution) {
    print('Selected: ${selectedSolution.title}');
    print('Project Name: ${selectedSolution.projectName}');
  },
  onClosed: () {
    print('Dialog closed');
  },
)
```

### Integration with Preferred Solution Analysis Screen
```dart
// In your build method where you want to show the button
SelectProjectKazButton(
  solutions: _solutions.map((s) => _SolutionOption(
    title: s.title,
    description: s.description,
  )).toList(),
  title: 'Choose a project to progress',
  subtitle: 'Pick the solution you want to advance and give your project a memorable name.',
  onSolutionSelected: (selected) {
    _handleProjectSelection(selected);
  },
)
```

## Customization

### Colors
The button uses the KAZ AI color scheme:
- Primary: `#FFC812` (Yellow)
- Secondary: `#FFB200` (Gold)
- White text with transparency overlays

To customize colors, modify the gradient colors in:
1. `SelectProjectKazButton` - Main button gradient
2. `_SelectProjectDialog` - Header gradient
3. `_SolutionCard` - Selection state colors

### Sizing
- Default button height: 56dp
- Dialog width: 540dp (desktop) / full width (mobile)
- Customizable via constructor parameters

### Animation Duration
Currently set to 300ms. To change:
```dart
_animationController = AnimationController(
  duration: const Duration(milliseconds: 300), // Change this
  vsync: this,
);
```

## Design Specifications

### Button Styling
- **Shape**: Rounded rectangle (16dp radius)
- **Gradient**: Top-left to bottom-right
- **Shadow**: Double shadow for depth
- **Height**: 56dp (Material standard)

### Dialog Styling
- **Maximum Width**: 540dp
- **Header Height**: Auto-adjusted based on content
- **Border Radius**: 24dp for modern feel
- **Backdrop**: Black with 45% opacity

### Animation Details
- **Scale Animation**: 0.95 → 1.0 (easeOutBack)
- **Duration**: 300ms
- **Curve**: EaseOutBack for spring effect

## Accessibility Features
✅ Proper color contrast ratios
✅ Readable text sizes (minimum 14px)
✅ Touch targets > 48dp
✅ Screen reader friendly labels
✅ Keyboard navigation support
✅ Focus states clearly visible

## Best Practices

1. **Always provide meaningful solution descriptions**
   - Keep descriptions under 2 lines
   - Use clear, concise language

2. **Validate project names**
   - The button includes validation
   - Provide helpful error messages

3. **Handle selection appropriately**
   - Save selections to your data model
   - Update UI after selection

4. **Test on multiple screen sizes**
   - Mobile (< 600px)
   - Tablet (600px - 960px)
   - Desktop (> 960px)

## Code Structure

```
SelectProjectKazButton (StatefulWidget)
├── _SelectProjectKazButtonState
│   ├── Animation controller setup
│   ├── Dialog triggering logic
│   └── Build method (button UI)
├── _SelectProjectDialog (StatefulWidget)
│   ├── Header with KAZ theme
│   ├── Solution selection cards
│   ├── Project name input field
│   └── Action buttons
└── _SolutionCard (StatelessWidget)
    ├── Selection indicator
    ├── Solution content
    └── Selection state styling
```

## Error Handling

The component provides validation for:
- Empty solution selection (shows snackbar)
- Empty project name (inline error message)
- Invalid input (graceful handling)

## Performance Considerations

- Uses `SingleTickerProviderStateMixin` for efficient animation
- Disposes controllers properly in cleanup
- Minimal rebuilds using targeted setState calls
- Efficient list rendering with ListView.builder compatibility

## Browser/Platform Support

✅ Flutter Web (desktop & mobile)
✅ iOS
✅ Android
✅ macOS
✅ Windows
✅ Linux

## Future Enhancements

Potential improvements:
- Solution cards with icons/images
- Multi-select capability
- Persistent selection state
- Analytics tracking
- Localization support
- Custom theme support

## Support

For issues or questions about implementation, refer to:
- `select_project_kaz_button.dart` source code
- Example implementations in screens
- KAZ AI design system documentation
