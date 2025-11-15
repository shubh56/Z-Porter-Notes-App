import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:provider/provider.dart';
import 'package:zporter_notes_app/views/notes/notes_list_screen.dart';

import 'services/auth_service.dart';
import 'services/firestore_service.dart';
import 'services/permission_service.dart';
import 'services/media_service.dart';
import 'services/storage_service.dart';
import 'services/encryption_service.dart';

import 'viewmodels/app_viewmodel.dart';
import 'viewmodels/notes_list_viewmodel.dart';

// Make sure google-services.json is in android/app/

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  runApp(ZPorterNotesApp());
}

class ZPorterNotesApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final authService = AuthService();
    final firestoreService = FirestoreService();
    final permissionService = PermissionService();
    final mediaService = MediaService();
    final storageService = StorageService();
    final encryptionService = EncryptionService();

    return MultiProvider(
      providers: [
        Provider<AuthService>.value(value: authService),
        Provider<FirestoreService>.value(value: firestoreService),
        Provider<PermissionService>.value(value: permissionService),
        Provider<MediaService>.value(value: mediaService),
        Provider<StorageService>.value(value: storageService),
        Provider<EncryptionService>.value(value: encryptionService),

        ChangeNotifierProvider<AppViewModel>(
          create: (ctx) => AppViewModel(authService: authService),
        ),

        ChangeNotifierProvider<NotesListViewModel>(
          create: (ctx) => NotesListViewModel(
            firestoreService: firestoreService,
            authService: authService,
          ),
        ),
      ],
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        title: 'ZPorter Notes',
        theme: ThemeData(
          useMaterial3: true,
          scaffoldBackgroundColor: const Color(0xFF111115),
          appBarTheme: const AppBarTheme(
            backgroundColor: Color(0xFF111115),
            foregroundColor: Color(0xFF7F7F82),
            elevation: 0,
          ),
          colorScheme: ColorScheme.dark(
            background: const Color(0xFF111115),
            surface: const Color(0xFF111115),
            surfaceVariant: const Color(0xFF1A1A1F),
            primary: const Color(0xFF7F7F82),
            onPrimary: const Color(0xFF111115),
            secondary: const Color(0xFF7F7F82),
            onSecondary: const Color(0xFF111115),
            tertiary: const Color(0xFF7F7F82),
          ),
          iconTheme: const IconThemeData(color: Color(0xFF7F7F82)),
          floatingActionButtonTheme: const FloatingActionButtonThemeData(
            backgroundColor: Color(0xFF7F7F82),
            foregroundColor: Color(0xFF111115),
          ),
          inputDecorationTheme: InputDecorationTheme(
            filled: true,
            fillColor: const Color(0xFF1A1A1F),
            hintStyle: const TextStyle(color: Color(0xFF7F7F82)),
            border: OutlineInputBorder(
              borderSide: const BorderSide(color: Color(0xFF7F7F82)),
              borderRadius: BorderRadius.circular(8),
            ),
            enabledBorder: OutlineInputBorder(
              borderSide: const BorderSide(color: Color(0xFF7F7F82)),
              borderRadius: BorderRadius.circular(8),
            ),
            focusedBorder: OutlineInputBorder(
              borderSide: const BorderSide(color: Color(0xFF7F7F82), width: 2),
              borderRadius: BorderRadius.circular(8),
            ),
          ),
          textTheme: const TextTheme(
            bodyLarge: TextStyle(color: Color(0xFF7F7F82)),
            bodyMedium: TextStyle(color: Color(0xFF7F7F82)),
            bodySmall: TextStyle(color: Color(0xFF7F7F82)),
            displayLarge: TextStyle(color: Color(0xFF7F7F82)),
            displayMedium: TextStyle(color: Color(0xFF7F7F82)),
            displaySmall: TextStyle(color: Color(0xFF7F7F82)),
            headlineLarge: TextStyle(color: Color(0xFF7F7F82)),
            headlineMedium: TextStyle(color: Color(0xFF7F7F82)),
            headlineSmall: TextStyle(color: Color(0xFF7F7F82)),
            labelLarge: TextStyle(color: Color(0xFF7F7F82)),
            labelMedium: TextStyle(color: Color(0xFF7F7F82)),
            labelSmall: TextStyle(color: Color(0xFF7F7F82)),
            titleLarge: TextStyle(color: Color(0xFF7F7F82)),
            titleMedium: TextStyle(color: Color(0xFF7F7F82)),
            titleSmall: TextStyle(color: Color(0xFF7F7F82)),
          ),
          dividerColor: const Color(0xFF7F7F82),
        ),
        home: RootRouter(),
      ),
    );
  }
}

class RootRouter extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    // Always show the Notes list screen. When unauthenticated the list
    // will display a prompt to login instead of forcing navigation.
    return NotesListScreen();
  }
}
