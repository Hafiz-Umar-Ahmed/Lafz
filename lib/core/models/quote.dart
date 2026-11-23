import 'package:lafz/core/enums/enums.dart';

class QuoteModel {
  final int id;
  final String text;
  final String attribution;
  final int personalityId;
  final String language;
  final String? sourceTitle;
  final String? sourceReference;
  final String? sourceUrl;
  final String? originalText;
  final String? originalLanguage;
  final String? translationSource;
  final VerificationStatus verificationStatus;
  final PublicationStatus publicationStatus;
  final int contentVersion;
  final ContentTier tier;
  final List<int> categoryIds;
  
  // Specific Islamic metadata
  final int? surah;
  final int? ayah;
  final String? hadithCollection;
  final String? hadithReference;
  final String? hadithGrading;

  const QuoteModel({
    required this.id,
    required this.text,
    required this.attribution,
    required this.personalityId,
    this.language = 'en',
    this.sourceTitle,
    this.sourceReference,
    this.sourceUrl,
    this.originalText,
    this.originalLanguage,
    this.translationSource,
    this.verificationStatus = VerificationStatus.verified,
    this.publicationStatus = PublicationStatus.published,
    this.contentVersion = 1,
    this.tier = ContentTier.free,
    this.categoryIds = const [],
    this.surah,
    this.ayah,
    this.hadithCollection,
    this.hadithReference,
    this.hadithGrading,
  });

  bool get isDisplayable =>
      publicationStatus.isVisible && verificationStatus.isDisplayable;

  bool get hasOriginal => originalText != null && originalText!.trim().isNotEmpty;

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'text': text,
      'attribution': attribution,
      'personality_id': personalityId,
      'language': language,
      'source_title': sourceTitle,
      'source_reference': sourceReference,
      'source_url': sourceUrl,
      'original_text': originalText,
      'original_language': originalLanguage,
      'translation_source': translationSource,
      'verification_status': verificationStatus.name,
      'publication_status': publicationStatus.name,
      'content_version': contentVersion,
      'tier': tier.name,
      'surah': surah,
      'ayah': ayah,
      'hadith_collection': hadithCollection,
      'hadith_reference': hadithReference,
      'hadith_grading': hadithGrading,
    };
  }

  factory QuoteModel.fromMap(Map<String, dynamic> map, {List<int>? categories}) {
    return QuoteModel(
      id: map['id'] as int,
      text: map['text'] as String,
      attribution: map['attribution'] as String,
      personalityId: map['personality_id'] as int,
      language: (map['language'] as String?) ?? 'en',
      sourceTitle: map['source_title'] as String?,
      sourceReference: map['source_reference'] as String?,
      sourceUrl: map['source_url'] as String?,
      originalText: map['original_text'] as String?,
      originalLanguage: map['original_language'] as String?,
      translationSource: map['translation_source'] as String?,
      verificationStatus: VerificationStatus.fromString(
        map['verification_status'] as String? ?? 'verified',
      ),
      publicationStatus: PublicationStatus.fromString(
        map['publication_status'] as String? ?? 'published',
      ),
      contentVersion: (map['content_version'] as int?) ?? 1,
      tier: ContentTier.fromString(map['tier'] as String? ?? 'free'),
      categoryIds: categories ?? const [],
      surah: map['surah'] as int?,
      ayah: map['ayah'] as int?,
      hadithCollection: map['hadith_collection'] as String?,
      hadithReference: map['hadith_reference'] as String?,
      hadithGrading: map['hadith_grading'] as String?,
    );
  }
}
