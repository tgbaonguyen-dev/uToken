import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:utoken_mobile/features/insights/presentation/insight_detail_screen.dart';

void main() {
  group('M08 Insight Detail Screen Tests', () {
    testWidgets('renders Insight detail screen with correct Figma attributes', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: InsightDetailScreen(),
        ),
      );
      await tester.pumpAndSettle();

      // 1. Back button chevron
      expect(find.byIcon(Icons.chevron_left), findsOneWidget);

      // 2. Header text 'Insight detail'
      expect(find.text('Insight detail'), findsOneWidget);

      // 3. Status 'Active'
      expect(find.text('Active'), findsOneWidget);

      // 4. Insight title and meta
      expect(find.text('Large context is driving token growth'), findsOneWidget);
      expect(find.text('Gemini · Project Camellia · Last 30 days'), findsOneWidget);

      // 5. Impact summary
      expect(find.text('ESTIMATED IMPACT'), findsOneWidget);
      expect(find.text('-18% input tokens'), findsOneWidget);
      expect(find.text(r'+ $0.40 / month'), findsOneWidget);
      expect(find.text('Confidence: High'), findsOneWidget);
      expect(find.text('Compared with prior 30 days'), findsOneWidget);

      // 6. Evidence section
      expect(find.text('Evidence'), findsOneWidget);
      expect(find.text('Average input per request'), findsOneWidget);
      expect(find.text('18.4k'), findsOneWidget);
      expect(find.text('Repeated context share'), findsOneWidget);
      expect(find.text('42%'), findsOneWidget);

      // 7. Recommendation section
      expect(find.text('Recommendation'), findsOneWidget);
      expect(
        find.text('Move stable instructions earlier, reduce duplicated context, and keep reusable context cacheable.'),
        findsOneWidget,
      );
      expect(
        find.text('Based on aggregate metadata only — no prompts or source code.'),
        findsOneWidget,
      );

      // 8. Action button
      expect(find.text('Mark as reviewed'), findsOneWidget);

      // 9. Bottom navigation tabs
      expect(find.text('Tokens'), findsOneWidget);
      expect(find.text('Analytics'), findsOneWidget);
      expect(find.text('Insights'), findsOneWidget);
      expect(find.text('Settings'), findsOneWidget);
    });
  });
}
