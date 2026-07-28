// Flutter Web Renderer Configuration
// This file configures Flutter to use HTML renderer instead of canvaskit
// to avoid CDN timeout errors

(function() {
  'use strict';
  
  // Configure Flutter to use HTML renderer before bootstrap loads
  if (typeof window !== 'undefined') {
    window.flutterConfiguration = window.flutterConfiguration || {};
    window.flutterConfiguration.renderer = 'html';
    
    // Set font fallback to avoid Google Fonts CDN dependency
    if (!document.getElementById('flutter-font-fallback')) {
      const style = document.createElement('style');
      style.id = 'flutter-font-fallback';
      style.textContent = `
        body {
          font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', 'Roboto', 'Oxygen', 'Ubuntu', 'Cantarell', 'Fira Sans', 'Droid Sans', 'Helvetica Neue', sans-serif;
        }
      `;
      document.head.appendChild(style);
    }
  }
})();
