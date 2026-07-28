// Centralized application strings
// Note: For dynamic, admin-editable strings, use ContentText widget or AppContentProvider
// Example: ContentText(contentKey: 'app_name', fallback: AppStrings.appName)
class AppStrings {
  AppStrings._();

  static const String appName = 'Ndu Project';
  
  // Default fallback values for content that can be managed via Admin Content
  static const String welcomeMessage = 'Welcome to your project management workspace';
  static const String initiationPhaseTitle = 'Initiation Phase';
  static const String planningPhaseTitle = 'Planning Phase';
  static const String designPhaseTitle = 'Design Phase';
  static const String executionPhaseTitle = 'Execution Phase';
  static const String launchPhaseTitle = 'Launch Phase';
}
