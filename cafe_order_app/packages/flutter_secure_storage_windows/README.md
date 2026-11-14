# Windows secure storage for Cà Phê Mây

This local Dart implementation registers the same Flutter secure-storage platform interface on Windows. It stores the app's values as generic credentials under its own Windows Credential Manager namespace. It uses the existing Win32 APIs through Dart FFI, so the Windows runner builds with Flutter's standard Visual Studio C++ workload.

Credential values created by this app use UTF-8. The app uses two short values, a local member ID and an API session token. This implementation uses its own credential namespace and creates new entries on sign-in.
