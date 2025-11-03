/// Application configuration settings
/// 
/// This file contains configurable values that can be adjusted for testing
/// or production environments. Simply change the values here and hot restart
/// the app to apply changes.
class AppConfig {
  // ============================================================================
  // TIMER CONFIGURATION
  // ============================================================================
  
  /// Timer duration for the patient info page reminder
  /// 
  /// This controls how long the timer runs before showing a reminder
  /// to record vitals.
  /// 
  /// **Testing values:**
  /// - `Duration(seconds: 10)` - Very quick testing (10 seconds)
  /// - `Duration(seconds: 30)` - Quick testing (30 seconds)
  /// - `Duration(minutes: 1)` - Moderate testing (1 minute)
  /// 
  /// **Production value:**
  /// - `Duration(minutes: 5)` - Standard production timer (5 minutes)
  /// 
  /// **Current setting:**
  static const Duration patientInfoTimerDuration = Duration(seconds: 10);

  // ============================================================================
  // FUTURE CONFIGURATION OPTIONS
  // ============================================================================
  // Add other configurable settings here as needed:
  // - Database connection settings
  // - API endpoints
  // - Feature flags
  // - UI preferences
  // etc.

  /// Private constructor to prevent instantiation
  AppConfig._();
}
