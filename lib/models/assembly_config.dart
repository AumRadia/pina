class AssemblyConfig {
  String languageCode;
  int? audioStartFrom;
  bool multichannel;
  bool speakerLabels;
  bool autoChapters;
  bool autoHighlights;
  bool sentimentAnalysis;
  bool summarization;
  String summaryModel;
  String summaryType; // <--- NEW FIELD
  bool filterProfanity;
  bool contentSafety;
  bool redactPii;
  List<String> redactPiiPolicies;
  String redactPiiSub;
  bool punctuate;
  bool formatText;
  List<String> customSpelling;

  AssemblyConfig({
    this.languageCode = 'hi',
    this.audioStartFrom,
    this.multichannel = false,
    this.speakerLabels = false,
    this.autoChapters = false,
    this.autoHighlights = false,
    this.sentimentAnalysis = false,
    this.summarization = false,
    this.summaryModel = 'informative',
    this.summaryType = 'bullets', // <--- Default value
    this.filterProfanity = false,
    this.contentSafety = false,
    this.redactPii = false,
    this.redactPiiPolicies = const [],
    this.redactPiiSub = 'hash',
    this.punctuate = true,
    this.formatText = true,
    this.customSpelling = const [],
  });

  // Convert to JSON for API request
  Map<String, dynamic> toJson() {
    final Map<String, dynamic> json = {
      'language_code': languageCode,
      'punctuate': punctuate,
      'format_text': formatText,
    };

    bool isEnglish = languageCode.toLowerCase().startsWith('en');

    if (multichannel) json['multichannel'] = true;
    if (speakerLabels) json['speaker_labels'] = true;
    if (filterProfanity) json['filter_profanity'] = true;

    // Remember to use the fix from earlier: 'content_safety' not 'content_safety_labels'
    if (contentSafety) json['content_safety'] = true;

    if (redactPii && redactPiiPolicies.isNotEmpty) {
      json['redact_pii'] = true;
      json['redact_pii_policies'] = redactPiiPolicies;
      json['redact_pii_sub'] = redactPiiSub;
    }

    if (audioStartFrom != null && audioStartFrom! > 0) {
      json['audio_start_from'] = audioStartFrom;
    }

    if (isEnglish) {
      if (autoHighlights) json['auto_highlights'] = true;
      if (sentimentAnalysis) json['sentiment_analysis'] = true;

      if (autoChapters) {
        json['auto_chapters'] = true;
      } else if (summarization) {
        json['summarization'] = true;
        json['summary_model'] = summaryModel;
        json['summary_type'] = summaryType; // <--- ADDED THIS LINE
      }
    }

    if (customSpelling.isNotEmpty) {
      json['word_boost'] = customSpelling;
      json['boost_param'] = 'high';
    }

    return json;
  }

  AssemblyConfig copyWith({
    String? languageCode,
    int? audioStartFrom,
    bool? multichannel,
    bool? speakerLabels,
    bool? autoChapters,
    bool? autoHighlights,
    bool? sentimentAnalysis,
    bool? summarization,
    String? summaryModel,
    String? summaryType, // <--- Add to copyWith
    bool? filterProfanity,
    bool? contentSafety,
    bool? redactPii,
    List<String>? redactPiiPolicies,
    String? redactPiiSub,
    bool? punctuate,
    bool? formatText,
    List<String>? customSpelling,
  }) {
    return AssemblyConfig(
      languageCode: languageCode ?? this.languageCode,
      audioStartFrom: audioStartFrom ?? this.audioStartFrom,
      multichannel: multichannel ?? this.multichannel,
      speakerLabels: speakerLabels ?? this.speakerLabels,
      autoChapters: autoChapters ?? this.autoChapters,
      autoHighlights: autoHighlights ?? this.autoHighlights,
      sentimentAnalysis: sentimentAnalysis ?? this.sentimentAnalysis,
      summarization: summarization ?? this.summarization,
      summaryModel: summaryModel ?? this.summaryModel,
      summaryType: summaryType ?? this.summaryType, // <--- Add here
      filterProfanity: filterProfanity ?? this.filterProfanity,
      contentSafety: contentSafety ?? this.contentSafety,
      redactPii: redactPii ?? this.redactPii,
      redactPiiPolicies: redactPiiPolicies ?? this.redactPiiPolicies,
      redactPiiSub: redactPiiSub ?? this.redactPiiSub,
      punctuate: punctuate ?? this.punctuate,
      formatText: formatText ?? this.formatText,
      customSpelling: customSpelling ?? this.customSpelling,
    );
  }
}

// Supported languages
class SupportedLanguages {
  static const Map<String, String> languages = {
    'en': 'English',
    'hi': 'हिन्दी (Hindi)',
    // Add more languages as needed
  };

  static List<String> get codes => languages.keys.toList();
  static List<String> get names => languages.values.toList();

  static String getName(String code) => languages[code] ?? code;
}

// PII Redaction Policies
class PIIRedactionPolicies {
  static const Map<String, String> policies = {
    'medical_process': 'Medical Process',
    'medical_condition': 'Medical Condition',
    'blood_type': 'Blood Type',
    'drug': 'Drug/Medication',
    'injury': 'Injury',
    'number_sequence': 'Number Sequence',
    'email_address': 'Email Address',
    'date_of_birth': 'Date of Birth',
    'phone_number': 'Phone Number',
    'us_social_security_number': 'US Social Security Number',
    'credit_card_number': 'Credit Card Number',
    'credit_card_expiration': 'Credit Card Expiration',
    'credit_card_cvv': 'Credit Card CVV',
    'date': 'Date',
    'nationality': 'Nationality',
    'event': 'Event',
    'language': 'Language',
    'location': 'Location',
    'money_amount': 'Money Amount',
    'person_name': 'Person Name',
    'person_age': 'Person Age',
    'organization': 'Organization',
    'political_affiliation': 'Political Affiliation',
    'occupation': 'Occupation',
    'religion': 'Religion',
    'drivers_license': 'Driver\'s License',
    'banking_information': 'Banking Information',
  };

  static List<String> get allPolicies => policies.keys.toList();
  static String getPolicyName(String key) => policies[key] ?? key;
}
