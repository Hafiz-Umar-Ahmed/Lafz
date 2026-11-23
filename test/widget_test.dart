import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lafz/core/enums/enums.dart';
import 'package:lafz/core/models/quote.dart';
import 'package:lafz/features/library/widgets/quote_card.dart';

void main() {
  testWidgets('QuoteCard displays text, attribution and verification badge', (WidgetTester tester) async {
    const testQuote = QuoteModel(
      id: 99,
      text: 'The only true wisdom is in knowing you know nothing.',
      attribution: 'Socrates',
      personalityId: 204,
      sourceTitle: 'Apology',
      sourceReference: '21d',
      verificationStatus: VerificationStatus.verified,
      publicationStatus: PublicationStatus.published,
    );

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: QuoteCard(
            quote: testQuote,
            isFavorite: true,
          ),
        ),
      ),
    );

    // Verify quote text is rendered
    expect(find.text('“The only true wisdom is in knowing you know nothing.”'), findsOneWidget);

    // Verify attribution
    expect(find.text('Socrates'), findsOneWidget);

    // Verify verification label
    expect(find.text('Verified'), findsOneWidget);

    // Verify favorite icon is active
    expect(find.byIcon(Icons.bookmark), findsOneWidget);
  });
}
