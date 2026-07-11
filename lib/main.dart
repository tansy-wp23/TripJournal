import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'features/home/home_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();      // required before async in main
  await dotenv.load(fileName: ".env");            // load your .env file

  await Supabase.initialize(
    url: dotenv.env['SUPABASE_URL']!,
    publishableKey: dotenv.env['SUPABASE_ANON_KEY']!,     // reads from .env
  );

  runApp(const TripJournalApp());     // your existing app widget — keep whatever yours is called
}

final supabase = Supabase.instance.client;

class TripJournalApp extends StatelessWidget {
  const TripJournalApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ProviderScope(
      child: MaterialApp(
        title: 'TripJournal',
        theme: ThemeData(colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple)),
        home: const HomeScreen(),
      ),
    );
  }
}
