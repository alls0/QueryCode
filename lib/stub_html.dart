// lib/stub_html.dart

// This file provides dummy implementations for web-only APIs on mobile.
// This allows the code to compile for mobile without errors.

class _Window {
  void close() {
    // This method does nothing on mobile platforms.
  }
}

// Create a dummy 'window' variable that the compiler can find.
final _Window window = _Window();
