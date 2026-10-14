// Centralized application strings
// Note: For dynamic, admin-editable strings, use ContentText widget or AppContentProvider
// Example: ContentText(contentKey: 'app_name', fallback: AppStrings.appName)
class AppStrings {
  AppStrings._();

  /// The app's installed name, so it matches the store listing and the
  /// launcher label (`android:label`, `CFBundleDisplayName`).
  static const String appName = 'NDU Project';
  
  // Default fallback values for content that can be managed via Admin Content
  static const String welcomeMessage = 'Welcome to your project management workspace';
  static const String initiationPhaseTitle = 'Initiation Phase';
  static const String planningPhaseTitle = 'Planning Phase';
  static const String designPhaseTitle = 'Design Phase';
  static const String executionPhaseTitle = 'Execution Phase';
  static const String launchPhaseTitle = 'Launch Phase';
}
