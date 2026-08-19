import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/services.dart' show rootBundle;
import 'package:http/http.dart' as http;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../../../models/journal_entry.dart';
import '../../../models/meal.dart';
import '../../../models/trip.dart';
import '../../trip/trip_day_groups.dart';
import '../widgets/format_utils.dart' show formatDate, formatThousands;
import '../widgets/meal_display.dart' show mealTypeLabel;
import '../widgets/mood_display.dart' show moodLabel;

/// PDF export of journal entries (IMPLEMENTATION_PLAN_EXTRA_FEATURES.md #5).
/// Builds the document only -- the caller decides how to offer it (share,
/// save, print) via the `printing` package. Never throws on a missing or
/// unreadable photo file; it's simply omitted from the page.
Future<pw.MemoryImage?> _loadPhoto(String path) async {
  try {
    // Seed data points at bundled assets while anything the user picks is a
    // real file. Without the asset branch the seeded photos loaded as "missing"
    // and were silently dropped from the export.
    if (path.startsWith('assets/')) {
      final data = await rootBundle.load(path);
      return pw.MemoryImage(data.buffer.asUint8List());
    }
    // Under BACKEND_MODE=supabase a photo is a Storage URL, not a device path.
    // Without this branch every photo silently vanished from the export in that
    // mode -- the same "omitted, never thrown" outcome as a missing file, which
    // is precisely why it would not have been noticed.
    final uri = Uri.tryParse(path);
    if (uri != null &&
        uri.hasAuthority &&
        (uri.scheme == 'http' || uri.scheme == 'https')) {
      final response = await http.get(uri);
      if (response.statusCode != 200) return null;
      return pw.MemoryImage(response.bodyBytes);
    }
    final file = File(path);
    if (!await file.exists()) return null;
    final bytes = await file.readAsBytes();
    return pw.MemoryImage(bytes);
  } catch (_) {
    return null;
  }
}

/// Meal photos for [entry], keyed by the meal's **index** in the health log.
///
/// Index rather than `Meal.id` deliberately. Ids used to be minted from
/// `microsecondsSinceEpoch`, so two meals added in the same microsecond could
/// collide and print one meal's photo beside another's name. They are UUIDs
/// now, so that specific collision is gone, but position stays the key: it is
/// what the caller already has, and it cannot go stale against an id scheme
/// that changes again.
Future<Map<int, pw.MemoryImage>> _loadMealPhotos(JournalEntry entry) async {
  final meals = entry.healthLog?.meals ?? const <Meal>[];
  final images = <int, pw.MemoryImage>{};

  for (var i = 0; i < meals.length; i++) {
    final path = meals[i].photoPath;
    if (path == null) continue;
    final image = await _loadPhoto(path);
    if (image != null) images[i] = image;
  }

  return images;
}

pw.Widget _entryHeader(JournalEntry entry) {
  return pw.Column(
    crossAxisAlignment: pw.CrossAxisAlignment.start,
    children: [
      pw.Text(
        entry.displayTitle,
        style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold),
      ),
      pw.SizedBox(height: 4),
      pw.Text('${formatDate(entry.createdAt)} · ${moodLabel(entry.mood)}'),
      if (entry.location?.placeName != null)
        pw.Text(entry.location!.placeName!),
    ],
  );
}

pw.Widget _entryBody(JournalEntry entry) {
  return pw.Text(
    entry.body.trim().isEmpty ? '(No written entry.)' : entry.body,
  );
}

Future<pw.Widget> _entryPhotos(JournalEntry entry) async {
  if (entry.photoPaths.isEmpty) return pw.SizedBox();
  final images = <pw.MemoryImage>[];
  for (final path in entry.photoPaths) {
    final image = await _loadPhoto(path);
    if (image != null) images.add(image);
  }
  if (images.isEmpty) return pw.SizedBox();

  return pw.Wrap(
    spacing: 6,
    runSpacing: 6,
    children: [
      for (final image in images)
        pw.Container(
          width: 90,
          height: 90,
          decoration: pw.BoxDecoration(
            borderRadius: pw.BorderRadius.circular(4),
          ),
          child: pw.ClipRRect(
            horizontalRadius: 4,
            verticalRadius: 4,
            child: pw.Image(image, fit: pw.BoxFit.cover),
          ),
        ),
    ],
  );
}

pw.Widget _healthSection(
  JournalEntry entry,
  Map<int, pw.MemoryImage> mealPhotos,
) {
  final healthLog = entry.healthLog;
  if (healthLog == null) return pw.SizedBox();

  return pw.Container(
    padding: const pw.EdgeInsets.all(8),
    decoration: pw.BoxDecoration(
      border: pw.Border.all(color: PdfColors.grey400),
      borderRadius: pw.BorderRadius.circular(4),
    ),
    child: pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          'Health Log',
          style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
        ),
        pw.SizedBox(height: 4),
        pw.Text(
          '${formatThousands(healthLog.steps)} steps · '
          'Eaten: ${formatThousands(healthLog.caloriesEaten)} kcal · '
          'Burned: ${healthLog.caloriesBurned != null ? '${formatThousands(healthLog.caloriesBurned!)} kcal' : 'no data'}',
        ),
        if (healthLog.meals.isNotEmpty) ...[
          pw.SizedBox(height: 6),
          pw.Text('Meals', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
          for (var i = 0; i < healthLog.meals.length; i++)
            _mealRow(healthLog.meals[i], mealPhotos[i]),
        ],
        if (healthLog.aiAdvice != null) ...[
          pw.SizedBox(height: 6),
          pw.Text(
            'AI advice',
            style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
          ),
          pw.Text(healthLog.aiAdvice!),
        ],
      ],
    ),
  );
}

String _mealLine(Meal meal) =>
    '${meal.name} (${mealTypeLabel(meal.mealType)}, ~${meal.calories} kcal)';

/// One meal line, with its photo alongside when the user logged the meal from
/// one. Meals typed in by hand keep the plain bullet they always had, so an
/// entry with no food photos exports byte-for-byte as before.
pw.Widget _mealRow(Meal meal, pw.MemoryImage? photo) {
  if (photo == null) return pw.Text('- ${_mealLine(meal)}');

  return pw.Padding(
    padding: const pw.EdgeInsets.only(top: 4, bottom: 4),
    child: pw.Row(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.ClipRRect(
          horizontalRadius: 4,
          verticalRadius: 4,
          child: pw.Container(
            width: 40,
            height: 40,
            child: pw.Image(photo, fit: pw.BoxFit.cover),
          ),
        ),
        pw.SizedBox(width: 6),
        // Expanded so a long meal name wraps inside the health box rather than
        // running past its border.
        pw.Expanded(
          child: pw.Text(_mealLine(meal)),
        ),
      ],
    ),
  );
}

/// A single entry, as one formatted page.
Future<Uint8List> buildEntryPdf(JournalEntry entry) async {
  final doc = pw.Document();
  // Both loaded up front: pw.Page.build is synchronous, so every image has to
  // be in memory before the page is composed.
  final photos = await _entryPhotos(entry);
  final mealPhotos = await _loadMealPhotos(entry);

  doc.addPage(
    pw.Page(
      pageFormat: PdfPageFormat.a4,
      build: (context) => pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          _entryHeader(entry),
          pw.SizedBox(height: 12),
          _entryBody(entry),
          pw.SizedBox(height: 12),
          photos,
          if (entry.photoPaths.isNotEmpty) pw.SizedBox(height: 12),
          _healthSection(entry, mealPhotos),
        ],
      ),
    ),
  );

  return doc.save();
}

/// A whole trip: a header page followed by each day's entries, in order.
/// Entries are grouped the same way the on-screen timeline is
/// (`buildDayGroups`) so the PDF matches what the user sees in the app.
Future<Uint8List> buildTripPdf(Trip trip, List<JournalEntry> entries) async {
  final doc = pw.Document();
  final dayGroups = buildDayGroups(
    trip,
    entries,
  ).where((g) => !g.isEmpty).toList();

  doc.addPage(
    pw.Page(
      pageFormat: PdfPageFormat.a4,
      build: (context) => pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            trip.title,
            style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold),
          ),
          pw.SizedBox(height: 4),
          pw.Text(
            '${formatDate(trip.startDate)} - ${formatDate(trip.endDate)}',
          ),
          if (trip.notes != null && trip.notes!.trim().isNotEmpty) ...[
            pw.SizedBox(height: 12),
            pw.Text(
              'Notes',
              style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
            ),
            pw.Text(trip.notes!),
          ],
          pw.SizedBox(height: 12),
          pw.Text(
            dayGroups.isEmpty
                ? 'No journal entries for this trip yet.'
                : '${dayGroups.length} day(s) journaled.',
          ),
        ],
      ),
    ),
  );

  for (final group in dayGroups) {
    for (final entry in group.entries) {
      final photos = await _entryPhotos(entry);
      final mealPhotos = await _loadMealPhotos(entry);
      doc.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a4,
          build: (context) => pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(
                'Day ${group.dayNumber}',
                style: pw.TextStyle(fontSize: 12, color: PdfColors.grey700),
              ),
              pw.SizedBox(height: 6),
              _entryHeader(entry),
              pw.SizedBox(height: 12),
              _entryBody(entry),
              pw.SizedBox(height: 12),
              photos,
              if (entry.photoPaths.isNotEmpty) pw.SizedBox(height: 12),
              _healthSection(entry, mealPhotos),
            ],
          ),
        ),
      );
    }
  }

  return doc.save();
}

/// Filesystem/share-safe filename, derived from [title] -- strips anything
/// that isn't a letter, digit, space, or hyphen and collapses whitespace.
String pdfFileNameFor(String title) {
  final cleaned = title.replaceAll(RegExp(r'[^A-Za-z0-9 \-]'), '').trim();
  final base = cleaned.isEmpty
      ? 'export'
      : cleaned.replaceAll(RegExp(r'\s+'), '_');
  return '$base.pdf';
}
