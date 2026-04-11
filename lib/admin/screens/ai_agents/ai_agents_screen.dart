import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

// ── Constants ────────────────────────────────────────────────────────────────

const kDestinations = [
  'Transfer to main line',
  'Transfer to sales',
  'Transfer to support',
  'Transfer to billing',
  'Book appointment',
  'Take a message',
  'Transfer to voicemail',
  'End call politely',
  'Custom number',
];

const kLanguages = [
  'English (UK)',
  'English (AU)',
  'English (US)',
  'Spanish',
  'French',
  'Arabic',
  'Mandarin',
];

const kPersonas = [
  'Professional',
  'Friendly',
  'Formal',
  'Energetic',
  'Empathetic',
  'Concise',
];

const kResponseLengths = [
  'Short (1–2 sentences)',
  'Medium (2–4 sentences)',
  'Long (paragraph)',
];

const kSpeakingPaces = ['Slow', 'Normal', 'Fast'];

const kSilenceActions = [
  'Prompt caller to respond',
  'End call with farewell',
  'Transfer to voicemail',
];

const kOutOfHoursBehaviours = [
  'Take a message and email to team',
  'Transfer to voicemail',
  'Inform caller of hours and end call',
  'Agent remains active 24/7',
];

const kTerminationActions = [
  'End call immediately, log incident',
  'End call, log incident, alert admin by email',
  'End call, log incident, alert admin by SMS',
];

// ── Models ───────────────────────────────────────────────────────────────────

class QualificationQuestion {
  static const Object _keep = Object();

  final String id;
  final String question;
  final String yesDest;
  final String? yesCustomNumber;
  final String noDest;
  final String? noCustomNumber;
  final String unclearDest;
  final String? unclearCustomNumber;

  const QualificationQuestion({
    required this.id,
    this.question = '',
    this.yesDest = 'Transfer to sales',
    this.yesCustomNumber,
    this.noDest = 'Take a message',
    this.noCustomNumber,
    this.unclearDest = 'Prompt caller to respond',
    this.unclearCustomNumber,
  });

  QualificationQuestion copyWith({
    String? id,
    String? question,
    String? yesDest,
    Object? yesCustomNumber = _keep,
    String? noDest,
    Object? noCustomNumber = _keep,
    String? unclearDest,
    Object? unclearCustomNumber = _keep,
  }) {
    return QualificationQuestion(
      id: id ?? this.id,
      question: question ?? this.question,
      yesDest: yesDest ?? this.yesDest,
      yesCustomNumber: identical(yesCustomNumber, _keep)
          ? this.yesCustomNumber
          : yesCustomNumber as String?,
      noDest: noDest ?? this.noDest,
      noCustomNumber: identical(noCustomNumber, _keep)
          ? this.noCustomNumber
          : noCustomNumber as String?,
      unclearDest: unclearDest ?? this.unclearDest,
      unclearCustomNumber: identical(unclearCustomNumber, _keep)
          ? this.unclearCustomNumber
          : unclearCustomNumber as String?,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'question': question,
        'yes_dest': yesDest,
        'yes_custom_number': yesCustomNumber,
        'no_dest': noDest,
        'no_custom_number': noCustomNumber,
        'unclear_dest': unclearDest,
        'unclear_custom_number': unclearCustomNumber,
      };

  factory QualificationQuestion.fromJson(Map<String, dynamic> json) =>
      QualificationQuestion(
        id: json['id'] as String? ?? const Uuid().v4(),
        question: json['question'] as String? ?? '',
        yesDest: json['yes_dest'] as String? ?? 'Transfer to sales',
        yesCustomNumber: json['yes_custom_number'] as String?,
        noDest: json['no_dest'] as String? ?? 'Take a message',
        noCustomNumber: json['no_custom_number'] as String?,
        unclearDest: json['unclear_dest'] as String? ?? 'Prompt caller to respond',
        unclearCustomNumber: json['unclear_custom_number'] as String?,
      );
}

class AgentSettings {
  static const Object _keep = Object();

  // Record identity
  final String? id; // Supabase row id (null for unsaved new agents)
  final String status; // 'draft' | 'active' | 'paused'
  final String? telnyxAssistantId; // Telnyx AI assistant ID
  final String? telnyxTexmlAppId; // Telnyx TeXML app ID for call routing

  bool get isDeployed =>
      telnyxAssistantId != null && telnyxAssistantId!.isNotEmpty;

  // Identity
  final String businessName;
  final String agentName;
  final String businessDescription;
  final String businessHours;
  final String language;
  final String persona;
  final String customInstructions;
  final String greeting;
  final bool announceAiDisclosure;

  // Call Qualification
  final List<QualificationQuestion> qualificationQuestions;
  final String defaultDestination;
  final String? defaultTransferNumber;

  // Routing & Escalation
  final bool transferOnHumanRequest;
  final bool transferOnRepeat;
  final bool transferOnFailedAttempts;
  final bool transferOnDurationExceeded;
  final int maxDurationMinutes;
  final String? escalationTransferNumber;
  final String outOfHoursBehaviour;
  final String outOfHoursMessage;
  final bool emergencyOverride;
  final String? emergencyTransferNumber;
  final String? voicemailEmail;
  final String? voicemailSms;
  final bool includeTranscriptInEmail;

  // Keywords
  final List<String> terminationKeywords;
  final String terminationAction;
  final List<String> escalationKeywords;
  final String? keywordEscalationNumber;
  final List<String> priorityKeywords;
  final List<String> offLimitsKeywords;
  final String deflectionMessage;

  // Behaviour
  final String maxResponseLength;
  final String speakingPace;
  final bool useFillerWords;
  final bool confirmCallerDetails;
  final bool askCallbackIfBusy;
  final int silenceTimeout;
  final String silenceAction;
  final String silencePrompt;
  final bool allowBargeIn;
  final bool recordCalls;
  final bool generateTranscript;
  final bool generateAiSummary;
  final bool announceRecording;

  const AgentSettings({
    this.id,
    this.status = 'draft',
    this.telnyxAssistantId,
    this.telnyxTexmlAppId,
    this.businessName = '',
    this.agentName = 'Alex',
    this.businessDescription = '',
    this.businessHours = 'Mon–Fri 9am–5pm',
    this.language = 'English (AU)',
    this.persona = 'Professional',
    this.customInstructions = '',
    this.greeting =
        'Hello, thank you for calling {business_name}. How can I help you today?',
    this.announceAiDisclosure = true,
    this.qualificationQuestions = const [],
    this.defaultDestination = 'Take a message',
    this.defaultTransferNumber,
    this.transferOnHumanRequest = true,
    this.transferOnRepeat = true,
    this.transferOnFailedAttempts = true,
    this.transferOnDurationExceeded = false,
    this.maxDurationMinutes = 10,
    this.escalationTransferNumber,
    this.outOfHoursBehaviour = 'Take a message and email to team',
    this.outOfHoursMessage = '',
    this.emergencyOverride = false,
    this.emergencyTransferNumber,
    this.voicemailEmail,
    this.voicemailSms,
    this.includeTranscriptInEmail = true,
    this.terminationKeywords = const ['bomb', 'threat', 'kill'],
    this.terminationAction = 'End call immediately, log incident',
    this.escalationKeywords = const [
      'urgent',
      'emergency',
      'complaint',
      'manager'
    ],
    this.keywordEscalationNumber,
    this.priorityKeywords = const ['VIP', 'existing client'],
    this.offLimitsKeywords = const [
      'pricing',
      'competitors',
      'legal disputes'
    ],
    this.deflectionMessage = '',
    this.maxResponseLength = 'Medium (2–4 sentences)',
    this.speakingPace = 'Normal',
    this.useFillerWords = true,
    this.confirmCallerDetails = true,
    this.askCallbackIfBusy = false,
    this.silenceTimeout = 8,
    this.silenceAction = 'Prompt caller to respond',
    this.silencePrompt =
        "Sorry, I didn't catch that — are you still there?",
    this.allowBargeIn = true,
    this.recordCalls = true,
    this.generateTranscript = false,
    this.generateAiSummary = false,
    this.announceRecording = true,
  });

  AgentSettings copyWith({
    Object? id = _keep,
    String? status,
    Object? telnyxAssistantId = _keep,
    Object? telnyxTexmlAppId = _keep,
    String? businessName,
    String? agentName,
    String? businessDescription,
    String? businessHours,
    String? language,
    String? persona,
    String? customInstructions,
    String? greeting,
    bool? announceAiDisclosure,
    List<QualificationQuestion>? qualificationQuestions,
    String? defaultDestination,
    Object? defaultTransferNumber = _keep,
    bool? transferOnHumanRequest,
    bool? transferOnRepeat,
    bool? transferOnFailedAttempts,
    bool? transferOnDurationExceeded,
    int? maxDurationMinutes,
    Object? escalationTransferNumber = _keep,
    String? outOfHoursBehaviour,
    String? outOfHoursMessage,
    bool? emergencyOverride,
    Object? emergencyTransferNumber = _keep,
    Object? voicemailEmail = _keep,
    Object? voicemailSms = _keep,
    bool? includeTranscriptInEmail,
    List<String>? terminationKeywords,
    String? terminationAction,
    List<String>? escalationKeywords,
    Object? keywordEscalationNumber = _keep,
    List<String>? priorityKeywords,
    List<String>? offLimitsKeywords,
    String? deflectionMessage,
    String? maxResponseLength,
    String? speakingPace,
    bool? useFillerWords,
    bool? confirmCallerDetails,
    bool? askCallbackIfBusy,
    int? silenceTimeout,
    String? silenceAction,
    String? silencePrompt,
    bool? allowBargeIn,
    bool? recordCalls,
    bool? generateTranscript,
    bool? generateAiSummary,
    bool? announceRecording,
  }) {
    return AgentSettings(
      id: identical(id, _keep) ? this.id : id as String?,
      status: status ?? this.status,
      telnyxAssistantId: identical(telnyxAssistantId, _keep)
          ? this.telnyxAssistantId
          : telnyxAssistantId as String?,
      telnyxTexmlAppId: identical(telnyxTexmlAppId, _keep)
          ? this.telnyxTexmlAppId
          : telnyxTexmlAppId as String?,
      businessName: businessName ?? this.businessName,
      agentName: agentName ?? this.agentName,
      businessDescription: businessDescription ?? this.businessDescription,
      businessHours: businessHours ?? this.businessHours,
      language: language ?? this.language,
      persona: persona ?? this.persona,
      customInstructions: customInstructions ?? this.customInstructions,
      greeting: greeting ?? this.greeting,
      announceAiDisclosure: announceAiDisclosure ?? this.announceAiDisclosure,
      qualificationQuestions:
          qualificationQuestions ?? this.qualificationQuestions,
      defaultDestination: defaultDestination ?? this.defaultDestination,
      defaultTransferNumber: identical(defaultTransferNumber, _keep)
          ? this.defaultTransferNumber
          : defaultTransferNumber as String?,
      transferOnHumanRequest:
          transferOnHumanRequest ?? this.transferOnHumanRequest,
      transferOnRepeat: transferOnRepeat ?? this.transferOnRepeat,
      transferOnFailedAttempts:
          transferOnFailedAttempts ?? this.transferOnFailedAttempts,
      transferOnDurationExceeded:
          transferOnDurationExceeded ?? this.transferOnDurationExceeded,
      maxDurationMinutes: maxDurationMinutes ?? this.maxDurationMinutes,
      escalationTransferNumber: identical(escalationTransferNumber, _keep)
          ? this.escalationTransferNumber
          : escalationTransferNumber as String?,
      outOfHoursBehaviour: outOfHoursBehaviour ?? this.outOfHoursBehaviour,
      outOfHoursMessage: outOfHoursMessage ?? this.outOfHoursMessage,
      emergencyOverride: emergencyOverride ?? this.emergencyOverride,
      emergencyTransferNumber: identical(emergencyTransferNumber, _keep)
          ? this.emergencyTransferNumber
          : emergencyTransferNumber as String?,
      voicemailEmail: identical(voicemailEmail, _keep)
          ? this.voicemailEmail
          : voicemailEmail as String?,
      voicemailSms: identical(voicemailSms, _keep)
          ? this.voicemailSms
          : voicemailSms as String?,
      includeTranscriptInEmail:
          includeTranscriptInEmail ?? this.includeTranscriptInEmail,
      terminationKeywords: terminationKeywords ?? this.terminationKeywords,
      terminationAction: terminationAction ?? this.terminationAction,
      escalationKeywords: escalationKeywords ?? this.escalationKeywords,
      keywordEscalationNumber: identical(keywordEscalationNumber, _keep)
          ? this.keywordEscalationNumber
          : keywordEscalationNumber as String?,
      priorityKeywords: priorityKeywords ?? this.priorityKeywords,
      offLimitsKeywords: offLimitsKeywords ?? this.offLimitsKeywords,
      deflectionMessage: deflectionMessage ?? this.deflectionMessage,
      maxResponseLength: maxResponseLength ?? this.maxResponseLength,
      speakingPace: speakingPace ?? this.speakingPace,
      useFillerWords: useFillerWords ?? this.useFillerWords,
      confirmCallerDetails: confirmCallerDetails ?? this.confirmCallerDetails,
      askCallbackIfBusy: askCallbackIfBusy ?? this.askCallbackIfBusy,
      silenceTimeout: silenceTimeout ?? this.silenceTimeout,
      silenceAction: silenceAction ?? this.silenceAction,
      silencePrompt: silencePrompt ?? this.silencePrompt,
      allowBargeIn: allowBargeIn ?? this.allowBargeIn,
      recordCalls: recordCalls ?? this.recordCalls,
      generateTranscript: generateTranscript ?? this.generateTranscript,
      generateAiSummary: generateAiSummary ?? this.generateAiSummary,
      announceRecording: announceRecording ?? this.announceRecording,
    );
  }

  factory AgentSettings.fromJson(Map<String, dynamic> json) {
    List<QualificationQuestion> parseQuestions(dynamic raw) {
      if (raw == null) return [];
      if (raw is List) {
        return raw
            .map((e) => QualificationQuestion.fromJson(
                Map<String, dynamic>.from(e as Map)))
            .toList();
      }
      return [];
    }

    List<String> parseStringList(dynamic raw, List<String> fallback) {
      if (raw == null) return fallback;
      if (raw is List) return raw.map((e) => e.toString()).toList();
      return fallback;
    }

    return AgentSettings(
      id: json['id'] as String?,
      status: json['status'] as String? ?? 'draft',
      telnyxAssistantId: json['telnyx_assistant_id'] as String?,
      telnyxTexmlAppId: json['telnyx_texml_app_id'] as String?,
      businessName: json['business_name'] as String? ?? '',
      agentName: json['agent_name'] as String? ?? 'Alex',
      businessDescription: json['business_description'] as String? ?? '',
      businessHours: json['business_hours'] as String? ?? 'Mon–Fri 9am–5pm',
      language: json['language'] as String? ?? 'English (AU)',
      persona: json['persona'] as String? ?? 'Professional',
      customInstructions: json['custom_instructions'] as String? ?? '',
      greeting: json['greeting'] as String? ??
          'Hello, thank you for calling {business_name}. How can I help you today?',
      announceAiDisclosure: json['announce_ai_disclosure'] as bool? ?? true,
      qualificationQuestions:
          parseQuestions(json['qualification_questions']),
      defaultDestination:
          json['default_destination'] as String? ?? 'Take a message',
      defaultTransferNumber: json['default_transfer_number'] as String?,
      transferOnHumanRequest:
          json['transfer_on_human_request'] as bool? ?? true,
      transferOnRepeat: json['transfer_on_repeat'] as bool? ?? true,
      transferOnFailedAttempts:
          json['transfer_on_failed_attempts'] as bool? ?? true,
      transferOnDurationExceeded:
          json['transfer_on_duration_exceeded'] as bool? ?? false,
      maxDurationMinutes: json['max_duration_minutes'] as int? ?? 10,
      escalationTransferNumber:
          json['escalation_transfer_number'] as String?,
      outOfHoursBehaviour: json['out_of_hours_behaviour'] as String? ??
          'Take a message and email to team',
      outOfHoursMessage: json['out_of_hours_message'] as String? ?? '',
      emergencyOverride: json['emergency_override'] as bool? ?? false,
      emergencyTransferNumber: json['emergency_transfer_number'] as String?,
      voicemailEmail: json['voicemail_email'] as String?,
      voicemailSms: json['voicemail_sms'] as String?,
      includeTranscriptInEmail:
          json['include_transcript_in_email'] as bool? ?? true,
      terminationKeywords: parseStringList(
          json['termination_keywords'], ['bomb', 'threat', 'kill']),
      terminationAction: json['termination_action'] as String? ??
          'End call immediately, log incident',
      escalationKeywords: parseStringList(json['escalation_keywords'],
          ['urgent', 'emergency', 'complaint', 'manager']),
      keywordEscalationNumber:
          json['keyword_escalation_number'] as String?,
      priorityKeywords: parseStringList(
          json['priority_keywords'], ['VIP', 'existing client']),
      offLimitsKeywords: parseStringList(json['off_limits_keywords'],
          ['pricing', 'competitors', 'legal disputes']),
      deflectionMessage: json['deflection_message'] as String? ?? '',
      maxResponseLength: json['max_response_length'] as String? ??
          'Medium (2–4 sentences)',
      speakingPace: json['speaking_pace'] as String? ?? 'Normal',
      useFillerWords: json['use_filler_words'] as bool? ?? true,
      confirmCallerDetails: json['confirm_caller_details'] as bool? ?? true,
      askCallbackIfBusy: json['ask_callback_if_busy'] as bool? ?? false,
      silenceTimeout: json['silence_timeout'] as int? ?? 8,
      silenceAction: json['silence_action'] as String? ??
          'Prompt caller to respond',
      silencePrompt: json['silence_prompt'] as String? ??
          "Sorry, I didn't catch that — are you still there?",
      allowBargeIn: json['allow_barge_in'] as bool? ?? true,
      recordCalls: json['record_calls'] as bool? ?? true,
      generateTranscript: json['generate_transcript'] as bool? ?? false,
      generateAiSummary: json['generate_ai_summary'] as bool? ?? false,
      announceRecording: json['announce_recording'] as bool? ?? true,
    );
  }

  Map<String, dynamic> toJson() => {
        if (id != null) 'id': id,
        'status': status,
        if (telnyxAssistantId != null) 'telnyx_assistant_id': telnyxAssistantId,
        if (telnyxTexmlAppId != null) 'telnyx_texml_app_id': telnyxTexmlAppId,
        'business_name': businessName,
        'agent_name': agentName,
        'business_description': businessDescription,
        'business_hours': businessHours,
        'language': language,
        'persona': persona,
        'custom_instructions': customInstructions,
        'greeting': greeting,
        'announce_ai_disclosure': announceAiDisclosure,
        'qualification_questions':
            qualificationQuestions.map((q) => q.toJson()).toList(),
        'default_destination': defaultDestination,
        'default_transfer_number': defaultTransferNumber,
        'transfer_on_human_request': transferOnHumanRequest,
        'transfer_on_repeat': transferOnRepeat,
        'transfer_on_failed_attempts': transferOnFailedAttempts,
        'transfer_on_duration_exceeded': transferOnDurationExceeded,
        'max_duration_minutes': maxDurationMinutes,
        'escalation_transfer_number': escalationTransferNumber,
        'out_of_hours_behaviour': outOfHoursBehaviour,
        'out_of_hours_message': outOfHoursMessage,
        'emergency_override': emergencyOverride,
        'emergency_transfer_number': emergencyTransferNumber,
        'voicemail_email': voicemailEmail,
        'voicemail_sms': voicemailSms,
        'include_transcript_in_email': includeTranscriptInEmail,
        'termination_keywords': terminationKeywords,
        'termination_action': terminationAction,
        'escalation_keywords': escalationKeywords,
        'keyword_escalation_number': keywordEscalationNumber,
        'priority_keywords': priorityKeywords,
        'off_limits_keywords': offLimitsKeywords,
        'deflection_message': deflectionMessage,
        'max_response_length': maxResponseLength,
        'speaking_pace': speakingPace,
        'use_filler_words': useFillerWords,
        'confirm_caller_details': confirmCallerDetails,
        'ask_callback_if_busy': askCallbackIfBusy,
        'silence_timeout': silenceTimeout,
        'silence_action': silenceAction,
        'silence_prompt': silencePrompt,
        'allow_barge_in': allowBargeIn,
        'record_calls': recordCalls,
        'generate_transcript': generateTranscript,
        'generate_ai_summary': generateAiSummary,
        'announce_recording': announceRecording,
      };
}

// ── Providers ─────────────────────────────────────────────────────────────────

/// Fetches the company_id for the current user (cached).
final _companyIdProvider = FutureProvider<String>((ref) async {
  final supabase = Supabase.instance.client;
  final userId = supabase.auth.currentUser!.id;
  final userRow = await supabase
      .from('users')
      .select('company_id')
      .eq('id', userId)
      .single();
  return userRow['company_id'] as String;
});

/// Lists ALL agents for the company (including drafts).
final agentListProvider =
    AsyncNotifierProvider<AgentListNotifier, List<AgentSettings>>(
        AgentListNotifier.new);

class AgentListNotifier extends AsyncNotifier<List<AgentSettings>> {
  @override
  Future<List<AgentSettings>> build() async {
    final companyId = await ref.watch(_companyIdProvider.future);
    final supabase = Supabase.instance.client;
    final rows = await supabase
        .from('agent_settings')
        .select()
        .eq('company_id', companyId)
        .order('created_at', ascending: false);
    return (rows as List)
        .map((e) => AgentSettings.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  }

  /// Saves agent settings to Supabase. Returns the row ID.
  Future<String> saveAgent(AgentSettings settings) async {
    final companyId = await ref.read(_companyIdProvider.future);
    final supabase = Supabase.instance.client;

    final payload = {'company_id': companyId, ...settings.toJson()};

    debugPrint('[SaveAgent] company_id: $companyId, agent id: ${settings.id}');
    debugPrint('[SaveAgent] payload keys: ${payload.keys.toList()}');

    String savedId;

    if (settings.id != null) {
      debugPrint('[SaveAgent] Updating existing agent ${settings.id}');
      await supabase
          .from('agent_settings')
          .update(payload)
          .eq('id', settings.id!);
      savedId = settings.id!;
      debugPrint('[SaveAgent] Update complete');
    } else {
      debugPrint('[SaveAgent] Inserting new agent');
      final row = await supabase
          .from('agent_settings')
          .insert(payload)
          .select('id')
          .single();
      savedId = row['id'] as String;
      debugPrint('[SaveAgent] Insert complete, id: $savedId');
    }

    ref.invalidateSelf();
    return savedId;
  }

  /// Push agent config to Telnyx via Edge Function.
  Future<void> pushToTelnyx(String agentSettingsId) async {
    final supabase = Supabase.instance.client;
    // Refresh session to avoid expired JWT (401)
    await supabase.auth.refreshSession();
    debugPrint('[TelnyxSync] Invoking telnyx-push-agent with agent_id: $agentSettingsId');
    final res = await supabase.functions.invoke(
      'telnyx-push-agent',
      body: {'agent_id': agentSettingsId},
    );
    debugPrint('[TelnyxSync] Response status: ${res.status}');
    debugPrint('[TelnyxSync] Response data: ${res.data}');
    if (res.status != 200) {
      throw Exception('Telnyx sync failed (status ${res.status}): ${res.data}');
    }
  }

  /// Deactivate agent on Telnyx, then reset local status to draft.
  Future<void> deactivateAgent(String agentSettingsId) async {
    final supabase = Supabase.instance.client;

    // Try to delete on Telnyx (non-fatal if edge function doesn't exist yet)
    try {
      debugPrint('[TelnyxSync] Invoking telnyx-delete-agent for $agentSettingsId');
      final res = await supabase.functions.invoke(
        'telnyx-delete-agent',
        body: {'agent_id': agentSettingsId},
      );
      debugPrint('[TelnyxSync] Delete response: ${res.status}');
    } catch (e) {
      debugPrint('[TelnyxSync] Delete call failed (non-fatal): $e');
    }

    // Clear telnyx_assistant_id and set status to draft
    await supabase
        .from('agent_settings')
        .update({'telnyx_assistant_id': null, 'status': 'draft'})
        .eq('id', agentSettingsId);

    ref.invalidateSelf();
  }

  Future<void> deleteAgent(String agentId) async {
    final supabase = Supabase.instance.client;
    // Clean up Telnyx side first
    try {
      await deactivateAgent(agentId);
    } catch (_) {}
    await supabase.from('agent_settings').delete().eq('id', agentId);
    ref.invalidateSelf();
  }

  /// Assign a phone number to an agent's TeXML app on Telnyx.
  Future<void> assignNumber(String phoneNumberId, String agentSettingsId) async {
    final supabase = Supabase.instance.client;
    final res = await supabase.functions.invoke(
      'assign-number-to-agent',
      body: {
        'phone_number_id': phoneNumberId,
        'agent_settings_id': agentSettingsId,
        'action': 'assign',
      },
    );
    debugPrint('[AssignNumber] Response: ${res.status} ${res.data}');
    if (res.status != 200) {
      throw Exception('Assign failed (${res.status}): ${res.data}');
    }
  }

  /// Unassign a phone number from an agent, restoring the default SIP connection.
  Future<void> unassignNumber(String phoneNumberId) async {
    final supabase = Supabase.instance.client;
    final res = await supabase.functions.invoke(
      'assign-number-to-agent',
      body: {
        'phone_number_id': phoneNumberId,
        'action': 'unassign',
      },
    );
    debugPrint('[UnassignNumber] Response: ${res.status} ${res.data}');
    if (res.status != 200) {
      throw Exception('Unassign failed (${res.status}): ${res.data}');
    }
  }
}

// Keep backward-compat provider (reads the first agent or defaults).
final agentSettingsProvider =
    AsyncNotifierProvider<AgentSettingsNotifier, AgentSettings>(
        AgentSettingsNotifier.new);

class AgentSettingsNotifier extends AsyncNotifier<AgentSettings> {
  @override
  Future<AgentSettings> build() async {
    final agents = await ref.watch(agentListProvider.future);
    return agents.isNotEmpty ? agents.first : const AgentSettings();
  }

  Future<void> save(AgentSettings settings, String companyId) async {
    await ref.read(agentListProvider.notifier).saveAgent(settings);
    state = AsyncData(settings);
  }
}

// ── Design Tokens ─────────────────────────────────────────────────────────────

class _T {
  // ignore: unused_field
  static const bg = Color(0xFFF5F5F7);
  static const card = Color(0xFFFFFFFF);
  static const border = Color(0xFFE8E8F0);
  static const brand = Color(0xFF0D0D1A);
  static const accent = Color(0xFF4F6AFF);
  static const accentLight = Color(0xFFEEF1FF);
  static const green = Color(0xFF22C55E);
  static const amber = Color(0xFFF59E0B);
  static const red = Color(0xFFEF4444);
  static const text = Color(0xFF0D0D1A);
  static const sub = Color(0xFF6B7280);
  static const muted = Color(0xFF9CA3AF);
  static const inputFill = Color(0xFFF9F9FB);
  static const fontFamily = 'DM Sans';

  static TextStyle label(
          {double size = 12,
          FontWeight weight = FontWeight.w600,
          Color? color}) =>
      TextStyle(
          fontFamily: fontFamily,
          fontSize: size,
          fontWeight: weight,
          color: color ?? const Color(0xFF374151));

  static TextStyle body({double size = 13, Color? color}) =>
      TextStyle(fontFamily: fontFamily, fontSize: size, color: color ?? text);

  static InputDecoration inputDeco({String? hint, Widget? prefix}) =>
      InputDecoration(
        hintText: hint,
        hintStyle:
            TextStyle(fontFamily: fontFamily, fontSize: 13, color: muted),
        prefixIcon: prefix,
        filled: true,
        fillColor: inputFill,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: border)),
        enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: border)),
        focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: accent, width: 1.5)),
        isDense: true,
      );
}

// ── AiAgentsScreen ────────────────────────────────────────────────────────────

class AiAgentsScreen extends ConsumerStatefulWidget {
  const AiAgentsScreen({super.key});

  @override
  ConsumerState<AiAgentsScreen> createState() => _AiAgentsScreenState();
}

class _AiAgentsScreenState extends ConsumerState<AiAgentsScreen> {
  int _selectedTab = 0;

  AgentSettings? _draft;
  bool _isDirty = false;
  bool _isSaving = false;
  bool _isDeploying = false;

  /// The id of the agent currently being edited (null = new unsaved agent).
  String? _editingAgentId;

  void _patch(AgentSettings updated) {
    setState(() {
      _draft = updated;
      _isDirty = true;
    });
  }

  void _selectAgent(AgentSettings agent) {
    setState(() {
      _draft = agent;
      _editingAgentId = agent.id;
      _isDirty = false;
      _selectedTab = 0;
    });
  }

  void _createNewAgent() {
    setState(() {
      _draft = const AgentSettings();
      _editingAgentId = null;
      _isDirty = true;
      _selectedTab = 0;
    });
  }

  Future<void> _save() async {
    if (_draft == null) return;

    setState(() => _isSaving = true);
    try {
      final savedId = await ref.read(agentListProvider.notifier).saveAgent(_draft!);

      if (mounted) {
        setState(() {
          _editingAgentId = savedId;
          _draft = _draft!.copyWith(id: savedId);
          _isDirty = false;
          _isSaving = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Settings saved', style: _T.body(color: Colors.white)),
            backgroundColor: _T.green,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSaving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Save failed: $e', style: _T.body(color: Colors.white)),
            backgroundColor: _T.red,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
        );
      }
    }
  }

  Future<void> _deployToTelnyx() async {
    if (_draft == null) return;

    setState(() => _isDeploying = true);
    try {
      // Save first if dirty
      String agentId;
      if (_isDirty || _editingAgentId == null) {
        agentId = await ref.read(agentListProvider.notifier).saveAgent(_draft!);
        if (mounted) {
          setState(() {
            _editingAgentId = agentId;
            _draft = _draft!.copyWith(id: agentId);
            _isDirty = false;
          });
        }
      } else {
        agentId = _editingAgentId!;
      }

      await ref.read(agentListProvider.notifier).pushToTelnyx(agentId);

      if (mounted) {
        setState(() => _isDeploying = false);
        // Refresh to pick up telnyx_assistant_id
        ref.invalidate(agentListProvider);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Deployed to Telnyx', style: _T.body(color: Colors.white)),
            backgroundColor: _T.green,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isDeploying = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Deploy failed: $e', style: _T.body(color: Colors.white)),
            backgroundColor: _T.red,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
        );
      }
    }
  }

  Future<void> _deactivateOnTelnyx() async {
    if (_editingAgentId == null) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text('Deactivate agent?', style: _T.label(size: 16)),
        content: Text(
          'This will remove the agent from Telnyx. It will no longer handle calls.',
          style: _T.body(),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(foregroundColor: _T.red),
            child: const Text('Deactivate'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    setState(() => _isDeploying = true);
    try {
      await ref.read(agentListProvider.notifier).deactivateAgent(_editingAgentId!);
      if (mounted) {
        setState(() {
          _isDeploying = false;
          _draft = _draft?.copyWith(telnyxAssistantId: null, status: 'draft');
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Agent deactivated', style: _T.body(color: Colors.white)),
            backgroundColor: _T.amber,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isDeploying = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Deactivation failed: $e', style: _T.body(color: Colors.white)),
            backgroundColor: _T.red,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final asyncAgents = ref.watch(agentListProvider);

    return asyncAgents.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (err, _) => Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.error_outline, color: _T.red, size: 48),
              const SizedBox(height: 16),
              Text('Failed to load agents',
                  style: _T.label(size: 16, color: _T.red)),
              const SizedBox(height: 8),
              Text(err.toString(), style: _T.body(color: _T.sub)),
              const SizedBox(height: 16),
              OutlinedButton(
                onPressed: () => ref.invalidate(agentListProvider),
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      ),
      data: (agents) {
        // Auto-select the first agent if we have no draft yet
        if (_draft == null && agents.isNotEmpty) {
          _draft = agents.first;
          _editingAgentId = agents.first.id;
        }
        _draft ??= const AgentSettings();

        final s = _draft!;

        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Left: Form area ──
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(28, 28, 28, 0),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('AI Agents',
                                  style: _T.label(
                                      size: 22,
                                      weight: FontWeight.w700,
                                      color: _T.brand)),
                              const SizedBox(height: 4),
                              Text('Configure your AI receptionist',
                                  style: _T.body(color: _T.sub)),
                            ],
                          ),
                        ),
                        if (_editingAgentId != null)
                          _DeployButton(
                            isDeployed: s.isDeployed,
                            isDeploying: _isDeploying,
                            isDirty: _isDirty,
                            onDeploy: _deployToTelnyx,
                            onDeactivate: _deactivateOnTelnyx,
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  Container(
                    decoration: const BoxDecoration(
                      color: _T.card,
                      border: Border(
                        bottom: BorderSide(color: _T.border),
                      ),
                    ),
                    padding:
                        const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          for (final (i, label) in [
                            (0, 'Identity'),
                            (1, 'Call Qualification'),
                            (2, 'Routing & Escalation'),
                            (3, 'Keywords'),
                            (4, 'Behaviour'),
                            (5, 'Phone Numbers'),
                            (6, 'Knowledge Base'),
                          ])
                          Padding(
                            padding: const EdgeInsets.only(right: 6),
                            child: GestureDetector(
                              onTap: () => setState(() => _selectedTab = i),
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 150),
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 14, vertical: 7),
                                decoration: BoxDecoration(
                                  color: _selectedTab == i
                                      ? _T.accentLight
                                      : Colors.transparent,
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(
                                    color: _selectedTab == i
                                        ? _T.accent.withValues(alpha: 0.3)
                                        : Colors.transparent,
                                  ),
                                ),
                                child: Text(
                                  label,
                                  style: _T.label(
                                    size: 13,
                                    weight: _selectedTab == i
                                        ? FontWeight.w600
                                        : FontWeight.w400,
                                    color:
                                        _selectedTab == i ? _T.accent : _T.sub,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  Expanded(
                    child: IndexedStack(
                      index: _selectedTab,
                      children: [
                        _IdentityTab(settings: s, onPatch: _patch),
                        _CallQualificationTab(settings: s, onPatch: _patch),
                        _RoutingEscalationTab(settings: s, onPatch: _patch),
                        _KeywordsTab(settings: s, onPatch: _patch),
                        _BehaviourTab(settings: s, onPatch: _patch),
                        _PhoneNumbersTab(agentSettings: s),
                        _KnowledgeBaseTab(agentSettings: s),
                      ],
                    ),
                  ),
                  if (_isDirty)
                    _SaveBar(isSaving: _isSaving, onSave: _save),
                ],
              ),
            ),

            // ── Right: Agents list panel ──
            Container(
              width: 280,
              decoration: const BoxDecoration(
                color: _T.card,
                border: Border(left: BorderSide(color: _T.border)),
              ),
              child: _AgentListPanel(
                agents: agents,
                selectedAgentId: _editingAgentId,
                onSelect: _selectAgent,
                onCreateNew: _createNewAgent,
              ),
            ),
          ],
        );
      },
    );
  }
}

// ── Agent List Panel (right side) ────────────────────────────────────────────

class _AgentListPanel extends StatelessWidget {
  final List<AgentSettings> agents;
  final String? selectedAgentId;
  final void Function(AgentSettings) onSelect;
  final VoidCallback onCreateNew;

  const _AgentListPanel({
    required this.agents,
    required this.selectedAgentId,
    required this.onSelect,
    required this.onCreateNew,
  });

  Color _statusColor(String status) {
    switch (status) {
      case 'active':
        return _T.green;
      case 'paused':
        return _T.amber;
      default:
        return _T.muted;
    }
  }

  String _statusLabel(String status) {
    switch (status) {
      case 'active':
        return 'Active';
      case 'paused':
        return 'Paused';
      default:
        return 'Draft';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 24, 16, 4),
          child: Row(
            children: [
              Text('All Agents',
                  style: _T.label(
                      size: 14,
                      weight: FontWeight.w700,
                      color: _T.brand)),
              const Spacer(),
              IconButton(
                onPressed: onCreateNew,
                icon: const Icon(Icons.add_circle_outline,
                    size: 20, color: _T.accent),
                tooltip: 'New agent',
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Text(
            '${agents.length} agent${agents.length == 1 ? '' : 's'}',
            style: _T.body(size: 12, color: _T.sub),
          ),
        ),
        const SizedBox(height: 12),
        const Divider(height: 1, color: _T.border),

        // List
        Expanded(
          child: agents.isEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.smart_toy_outlined,
                            size: 40, color: _T.muted),
                        const SizedBox(height: 12),
                        Text('No agents yet',
                            style: _T.label(
                                size: 13,
                                weight: FontWeight.w500,
                                color: _T.sub)),
                        const SizedBox(height: 4),
                        Text('Create your first AI agent',
                            style: _T.body(size: 12, color: _T.muted)),
                        const SizedBox(height: 16),
                        OutlinedButton.icon(
                          onPressed: onCreateNew,
                          icon: const Icon(Icons.add, size: 16),
                          label: Text('New Agent',
                              style: _T.label(size: 12, color: _T.accent)),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: _T.accent,
                            side: const BorderSide(color: _T.accent),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8)),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 14, vertical: 8),
                          ),
                        ),
                      ],
                    ),
                  ),
                )
              : ListView.separated(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  itemCount: agents.length,
                  separatorBuilder: (_, _) =>
                      const Divider(height: 1, color: _T.border),
                  itemBuilder: (context, index) {
                    final agent = agents[index];
                    final isSelected = agent.id == selectedAgentId;
                    return InkWell(
                      onTap: () => onSelect(agent),
                      child: Container(
                        color: isSelected
                            ? _T.accentLight
                            : Colors.transparent,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 12),
                        child: Row(
                          children: [
                            Container(
                              width: 36,
                              height: 36,
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? _T.accent.withValues(alpha: 0.1)
                                    : _T.inputFill,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Icon(
                                Icons.smart_toy_outlined,
                                size: 18,
                                color: isSelected ? _T.accent : _T.sub,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment:
                                    CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    agent.agentName.isEmpty
                                        ? 'Unnamed Agent'
                                        : agent.agentName,
                                    style: _T.label(
                                      size: 13,
                                      weight: isSelected
                                          ? FontWeight.w600
                                          : FontWeight.w500,
                                      color: isSelected
                                          ? _T.accent
                                          : _T.text,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    agent.businessName.isEmpty
                                        ? 'No business'
                                        : agent.businessName,
                                    style: _T.body(
                                        size: 11, color: _T.muted),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: _statusColor(agent.status)
                                    .withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Text(
                                _statusLabel(agent.status),
                                style: TextStyle(
                                  fontFamily: _T.fontFamily,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w600,
                                  color: _statusColor(agent.status),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }
}

// ── Tab 1: Identity ───────────────────────────────────────────────────────────

class _IdentityTab extends StatefulWidget {
  final AgentSettings settings;
  final void Function(AgentSettings) onPatch;

  const _IdentityTab({required this.settings, required this.onPatch});

  @override
  State<_IdentityTab> createState() => _IdentityTabState();
}

class _IdentityTabState extends State<_IdentityTab> {
  late final TextEditingController _businessNameCtrl;
  late final TextEditingController _agentNameCtrl;
  late final TextEditingController _businessDescCtrl;
  late final TextEditingController _businessHoursCtrl;
  late final TextEditingController _customInstructionsCtrl;
  late final TextEditingController _greetingCtrl;

  @override
  void initState() {
    super.initState();
    _businessNameCtrl =
        TextEditingController(text: widget.settings.businessName);
    _agentNameCtrl = TextEditingController(text: widget.settings.agentName);
    _businessDescCtrl =
        TextEditingController(text: widget.settings.businessDescription);
    _businessHoursCtrl =
        TextEditingController(text: widget.settings.businessHours);
    _customInstructionsCtrl =
        TextEditingController(text: widget.settings.customInstructions);
    _greetingCtrl = TextEditingController(text: widget.settings.greeting);
  }

  @override
  void dispose() {
    _businessNameCtrl.dispose();
    _agentNameCtrl.dispose();
    _businessDescCtrl.dispose();
    _businessHoursCtrl.dispose();
    _customInstructionsCtrl.dispose();
    _greetingCtrl.dispose();
    super.dispose();
  }

  void _emit() {
    widget.onPatch(widget.settings.copyWith(
      businessName: _businessNameCtrl.text,
      agentName: _agentNameCtrl.text,
      businessDescription: _businessDescCtrl.text,
      businessHours: _businessHoursCtrl.text,
      customInstructions: _customInstructionsCtrl.text,
      greeting: _greetingCtrl.text,
    ));
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.settings;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SectionCard(
            title: 'Business Info',
            children: [
              Row(
                children: [
                  Expanded(
                    child: _Field(
                      label: 'Business name',
                      controller: _businessNameCtrl,
                      onChanged: (_) => _emit(),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: _Field(
                      label: 'Agent name',
                      controller: _agentNameCtrl,
                      onChanged: (_) => _emit(),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              _Field(
                label: 'Business description',
                controller: _businessDescCtrl,
                maxLines: 3,
                hint: '1–2 sentences describing your business',
                onChanged: (_) => _emit(),
              ),
              const SizedBox(height: 16),
              _Field(
                label: 'Business hours',
                controller: _businessHoursCtrl,
                hint: 'e.g. Mon–Fri 8am–6pm',
                onChanged: (_) => _emit(),
              ),
              const SizedBox(height: 16),
              _DropdownField(
                label: 'Primary language',
                value: s.language,
                items: kLanguages,
                onChanged: (v) =>
                    widget.onPatch(s.copyWith(language: v)),
              ),
            ],
          ),
          const SizedBox(height: 20),
          _SectionCard(
            title: 'Agent Persona',
            children: [
              _Label('Personality style'),
              const SizedBox(height: 10),
              GridView.count(
                crossAxisCount: 3,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisSpacing: 10,
                mainAxisSpacing: 10,
                childAspectRatio: 2.8,
                children: kPersonas.map((p) {
                  final selected = s.persona == p;
                  return GestureDetector(
                    onTap: () =>
                        widget.onPatch(s.copyWith(persona: p)),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 150),
                      decoration: BoxDecoration(
                        color: selected ? _T.accentLight : _T.inputFill,
                        border: Border.all(
                          color: selected ? _T.accent : _T.border,
                          width: selected ? 1.5 : 1,
                        ),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        p,
                        style: _T.label(
                          size: 12,
                          color: selected ? _T.accent : _T.sub,
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 16),
              _Field(
                label: 'Custom instructions',
                controller: _customInstructionsCtrl,
                maxLines: 3,
                hint: 'Additional tone or behaviour rules (optional)',
                onChanged: (_) => _emit(),
              ),
            ],
          ),
          const SizedBox(height: 20),
          _SectionCard(
            title: 'Greeting',
            children: [
              const _InfoTip(
                  text:
                      'Use {business_name} as a dynamic variable in your greeting.'),
              const SizedBox(height: 12),
              _Field(
                label: 'Opening message',
                controller: _greetingCtrl,
                maxLines: 3,
                onChanged: (_) => _emit(),
              ),
              const SizedBox(height: 16),
              _ToggleRow(
                title: 'Announce AI disclosure to caller',
                subtitle:
                    'Informs the caller they are speaking with an AI agent',
                value: s.announceAiDisclosure,
                onChanged: (v) =>
                    widget.onPatch(s.copyWith(announceAiDisclosure: v)),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ── Tab 2: Call Qualification ─────────────────────────────────────────────────

class _CallQualificationTab extends StatefulWidget {
  final AgentSettings settings;
  final void Function(AgentSettings) onPatch;

  const _CallQualificationTab(
      {required this.settings, required this.onPatch});

  @override
  State<_CallQualificationTab> createState() =>
      _CallQualificationTabState();
}

class _CallQualificationTabState extends State<_CallQualificationTab> {
  late final TextEditingController _defaultNumberCtrl;

  @override
  void initState() {
    super.initState();
    _defaultNumberCtrl = TextEditingController(
        text: widget.settings.defaultTransferNumber ?? '');
  }

  @override
  void dispose() {
    _defaultNumberCtrl.dispose();
    super.dispose();
  }

  void _emitDefault() {
    final num = _defaultNumberCtrl.text.trim();
    widget.onPatch(widget.settings.copyWith(
      defaultTransferNumber: num.isEmpty ? null : num,
    ));
  }

  void _addQuestion() {
    final questions = List<QualificationQuestion>.from(
        widget.settings.qualificationQuestions);
    questions.add(QualificationQuestion(
      id: const Uuid().v4(),
      yesDest: kDestinations.first,
      noDest: kDestinations.first,
      unclearDest: kDestinations.first,
    ));
    widget.onPatch(widget.settings.copyWith(qualificationQuestions: questions));
  }

  void _removeQuestion(String id) {
    final questions = widget.settings.qualificationQuestions
        .where((q) => q.id != id)
        .toList();
    widget.onPatch(widget.settings.copyWith(qualificationQuestions: questions));
  }

  void _updateQuestion(QualificationQuestion updated) {
    final questions = widget.settings.qualificationQuestions
        .map((q) => q.id == updated.id ? updated : q)
        .toList();
    widget.onPatch(widget.settings.copyWith(qualificationQuestions: questions));
  }

  void _moveUp(int i) {
    if (i <= 0) return;
    final questions = List<QualificationQuestion>.from(
        widget.settings.qualificationQuestions);
    final tmp = questions[i];
    questions[i] = questions[i - 1];
    questions[i - 1] = tmp;
    widget.onPatch(widget.settings.copyWith(qualificationQuestions: questions));
  }

  void _moveDown(int i) {
    final questions = widget.settings.qualificationQuestions;
    if (i >= questions.length - 1) return;
    final mutable = List<QualificationQuestion>.from(questions);
    final tmp = mutable[i];
    mutable[i] = mutable[i + 1];
    mutable[i + 1] = tmp;
    widget.onPatch(widget.settings.copyWith(qualificationQuestions: mutable));
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.settings;
    final questions = s.qualificationQuestions;

    final showTransferNumber = s.defaultDestination == 'Custom number' ||
        s.defaultDestination.startsWith('Transfer');

    return SingleChildScrollView(
      padding: const EdgeInsets.all(28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _InfoTip(
              text:
                  'The agent asks these questions in order to qualify the caller. Based on the answer, the caller is routed to the appropriate destination.'),
          const SizedBox(height: 16),
          Row(
            children: [
              Text('Qualification Questions',
                  style: _T.label(size: 14, weight: FontWeight.w600)),
              const Spacer(),
              _PillButton(
                icon: Icons.add,
                label: 'Add Question',
                onTap: _addQuestion,
              ),
            ],
          ),
          const SizedBox(height: 12),
          ...questions.asMap().entries.map((entry) {
            final i = entry.key;
            final q = entry.value;
            return _QuestionCard(
              question: q,
              index: i,
              canMoveUp: i > 0,
              canMoveDown: i < questions.length - 1,
              onChanged: _updateQuestion,
              onRemove: () => _removeQuestion(q.id),
              onMoveUp: () => _moveUp(i),
              onMoveDown: () => _moveDown(i),
            );
          }),
          if (questions.isEmpty)
            Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 24),
                child: Text(
                  'No qualification questions yet. Add one to get started.',
                  style: _T.body(color: _T.muted),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
          const SizedBox(height: 24),
          _SectionCard(
            title: 'Default Destination',
            children: [
              Text('For callers who pass all questions:',
                  style: _T.body(size: 12, color: _T.sub)),
              const SizedBox(height: 10),
              _DropdownField(
                label: 'Default route',
                value: s.defaultDestination,
                items: kDestinations,
                onChanged: (v) => widget.onPatch(
                    s.copyWith(defaultDestination: v)),
              ),
              if (showTransferNumber) ...[
                const SizedBox(height: 12),
                _Field(
                  label: 'Transfer number',
                  controller: _defaultNumberCtrl,
                  hint: '+61...',
                  onChanged: (_) => _emitDefault(),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

class _QuestionCard extends StatefulWidget {
  final QualificationQuestion question;
  final int index;
  final bool canMoveUp;
  final bool canMoveDown;
  final void Function(QualificationQuestion) onChanged;
  final VoidCallback onRemove;
  final VoidCallback onMoveUp;
  final VoidCallback onMoveDown;

  const _QuestionCard({
    required this.question,
    required this.index,
    required this.canMoveUp,
    required this.canMoveDown,
    required this.onChanged,
    required this.onRemove,
    required this.onMoveUp,
    required this.onMoveDown,
  });

  @override
  State<_QuestionCard> createState() => _QuestionCardState();
}

class _QuestionCardState extends State<_QuestionCard> {
  late final TextEditingController _questionCtrl;
  late final TextEditingController _yesCustomCtrl;
  late final TextEditingController _noCustomCtrl;
  late final TextEditingController _unclearCustomCtrl;

  @override
  void initState() {
    super.initState();
    _questionCtrl =
        TextEditingController(text: widget.question.question);
    _yesCustomCtrl =
        TextEditingController(text: widget.question.yesCustomNumber ?? '');
    _noCustomCtrl =
        TextEditingController(text: widget.question.noCustomNumber ?? '');
    _unclearCustomCtrl =
        TextEditingController(text: widget.question.unclearCustomNumber ?? '');
  }

  @override
  void dispose() {
    _questionCtrl.dispose();
    _yesCustomCtrl.dispose();
    _noCustomCtrl.dispose();
    _unclearCustomCtrl.dispose();
    super.dispose();
  }

  void _emitQuestion() {
    widget.onChanged(widget.question.copyWith(
      question: _questionCtrl.text,
    ));
  }

  Widget _buildBranch({
    required String label,
    required Color color,
    required String dest,
    required String? customNumber,
    required TextEditingController customCtrl,
    required void Function(String?) onDestChanged,
    required void Function(String?) onCustomChanged,
  }) {
    final showCustom =
        dest == 'Custom number' || dest.startsWith('Transfer');
    return Container(
      margin: const EdgeInsets.only(top: 10),
      decoration: BoxDecoration(
        border: Border(left: BorderSide(color: color, width: 3)),
        borderRadius: const BorderRadius.only(
          topRight: Radius.circular(6),
          bottomRight: Radius.circular(6),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 8, 0, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(label,
                      style: _T.label(size: 11, color: color)),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _DropdownField(
                    label: '',
                    value: dest,
                    items: kDestinations,
                    onChanged: onDestChanged,
                  ),
                ),
              ],
            ),
            if (showCustom) ...[
              const SizedBox(height: 8),
              TextField(
                controller: customCtrl,
                onChanged: (v) {
                  final trimmed = v.trim();
                  onCustomChanged(trimmed.isEmpty ? null : trimmed);
                },
                style: _T.body(),
                decoration: _T.inputDeco(hint: '+61...'),
              ),
            ],
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final q = widget.question;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: _T.card,
        border: Border.all(color: _T.border),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    color: _T.accentLight,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    '${widget.index + 1}',
                    style: _T.label(size: 12, color: _T.accent),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: TextField(
                    controller: _questionCtrl,
                    onChanged: (_) => _emitQuestion(),
                    style: _T.body(),
                    decoration:
                        _T.inputDeco(hint: 'Enter qualification question...'),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  onPressed: widget.canMoveUp ? widget.onMoveUp : null,
                  icon: const Icon(Icons.arrow_upward, size: 18),
                  color: widget.canMoveUp ? _T.sub : _T.muted,
                  padding: EdgeInsets.zero,
                  constraints:
                      const BoxConstraints(minWidth: 32, minHeight: 32),
                ),
                IconButton(
                  onPressed: widget.canMoveDown ? widget.onMoveDown : null,
                  icon: const Icon(Icons.arrow_downward, size: 18),
                  color: widget.canMoveDown ? _T.sub : _T.muted,
                  padding: EdgeInsets.zero,
                  constraints:
                      const BoxConstraints(minWidth: 32, minHeight: 32),
                ),
                IconButton(
                  onPressed: widget.onRemove,
                  icon: const Icon(Icons.delete_outline, size: 18),
                  color: _T.red,
                  padding: EdgeInsets.zero,
                  constraints:
                      const BoxConstraints(minWidth: 32, minHeight: 32),
                ),
              ],
            ),
            _buildBranch(
              label: 'YES',
              color: _T.green,
              dest: q.yesDest,
              customNumber: q.yesCustomNumber,
              customCtrl: _yesCustomCtrl,
              onDestChanged: (v) => widget.onChanged(
                  q.copyWith(yesDest: v ?? q.yesDest)),
              onCustomChanged: (v) =>
                  widget.onChanged(q.copyWith(yesCustomNumber: v)),
            ),
            _buildBranch(
              label: 'NO',
              color: _T.red,
              dest: q.noDest,
              customNumber: q.noCustomNumber,
              customCtrl: _noCustomCtrl,
              onDestChanged: (v) =>
                  widget.onChanged(q.copyWith(noDest: v ?? q.noDest)),
              onCustomChanged: (v) =>
                  widget.onChanged(q.copyWith(noCustomNumber: v)),
            ),
            _buildBranch(
              label: 'UNCLEAR',
              color: _T.amber,
              dest: q.unclearDest,
              customNumber: q.unclearCustomNumber,
              customCtrl: _unclearCustomCtrl,
              onDestChanged: (v) => widget.onChanged(
                  q.copyWith(unclearDest: v ?? q.unclearDest)),
              onCustomChanged: (v) =>
                  widget.onChanged(q.copyWith(unclearCustomNumber: v)),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Tab 3: Routing & Escalation ───────────────────────────────────────────────

class _RoutingEscalationTab extends StatefulWidget {
  final AgentSettings settings;
  final void Function(AgentSettings) onPatch;

  const _RoutingEscalationTab(
      {required this.settings, required this.onPatch});

  @override
  State<_RoutingEscalationTab> createState() =>
      _RoutingEscalationTabState();
}

class _RoutingEscalationTabState extends State<_RoutingEscalationTab> {
  late final TextEditingController _escalationTransferNumberCtrl;
  late final TextEditingController _outOfHoursMessageCtrl;
  late final TextEditingController _emergencyTransferNumberCtrl;
  late final TextEditingController _voicemailEmailCtrl;
  late final TextEditingController _voicemailSmsCtrl;
  late final TextEditingController _maxDurationCtrl;

  @override
  void initState() {
    super.initState();
    _escalationTransferNumberCtrl = TextEditingController(
        text: widget.settings.escalationTransferNumber ?? '');
    _outOfHoursMessageCtrl =
        TextEditingController(text: widget.settings.outOfHoursMessage);
    _emergencyTransferNumberCtrl = TextEditingController(
        text: widget.settings.emergencyTransferNumber ?? '');
    _voicemailEmailCtrl =
        TextEditingController(text: widget.settings.voicemailEmail ?? '');
    _voicemailSmsCtrl =
        TextEditingController(text: widget.settings.voicemailSms ?? '');
    _maxDurationCtrl = TextEditingController(
        text: widget.settings.maxDurationMinutes.toString());
  }

  @override
  void dispose() {
    _escalationTransferNumberCtrl.dispose();
    _outOfHoursMessageCtrl.dispose();
    _emergencyTransferNumberCtrl.dispose();
    _voicemailEmailCtrl.dispose();
    _voicemailSmsCtrl.dispose();
    _maxDurationCtrl.dispose();
    super.dispose();
  }

  void _emit() {
    final maxDur =
        int.tryParse(_maxDurationCtrl.text.trim()) ??
            widget.settings.maxDurationMinutes;
    final escalNum = _escalationTransferNumberCtrl.text.trim();
    final emerNum = _emergencyTransferNumberCtrl.text.trim();
    final vmEmail = _voicemailEmailCtrl.text.trim();
    final vmSms = _voicemailSmsCtrl.text.trim();
    widget.onPatch(widget.settings.copyWith(
      maxDurationMinutes: maxDur,
      escalationTransferNumber: escalNum.isEmpty ? null : escalNum,
      outOfHoursMessage: _outOfHoursMessageCtrl.text,
      emergencyTransferNumber: emerNum.isEmpty ? null : emerNum,
      voicemailEmail: vmEmail.isEmpty ? null : vmEmail,
      voicemailSms: vmSms.isEmpty ? null : vmSms,
    ));
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.settings;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SectionCard(
            title: 'Human Handoff',
            children: [
              _ToggleRow(
                title: 'Caller requests a human',
                subtitle:
                    'Transfer immediately when caller asks to speak to a person',
                value: s.transferOnHumanRequest,
                onChanged: (v) => widget.onPatch(
                    s.copyWith(transferOnHumanRequest: v)),
              ),
              const Divider(height: 24),
              _ToggleRow(
                title: 'Caller repeats themselves 3 times',
                subtitle:
                    'Suggests the agent is not understanding the caller',
                value: s.transferOnRepeat,
                onChanged: (v) =>
                    widget.onPatch(s.copyWith(transferOnRepeat: v)),
              ),
              const Divider(height: 24),
              _ToggleRow(
                title: 'Agent cannot answer after 2 attempts',
                subtitle:
                    'Escalate when the agent fails to resolve the query',
                value: s.transferOnFailedAttempts,
                onChanged: (v) => widget.onPatch(
                    s.copyWith(transferOnFailedAttempts: v)),
              ),
              const Divider(height: 24),
              _ToggleRow(
                title: 'Call duration exceeds limit',
                subtitle:
                    'Escalate long calls to avoid caller frustration',
                value: s.transferOnDurationExceeded,
                onChanged: (v) => widget.onPatch(
                    s.copyWith(transferOnDurationExceeded: v)),
              ),
              if (s.transferOnDurationExceeded) ...[
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: _Field(
                        label: 'Max duration (minutes)',
                        controller: _maxDurationCtrl,
                        onChanged: (_) => _emit(),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: _Field(
                        label: 'Escalation transfer number',
                        controller: _escalationTransferNumberCtrl,
                        onChanged: (_) => _emit(),
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
          const SizedBox(height: 20),
          _SectionCard(
            title: 'Out of Hours',
            children: [
              _DropdownField(
                label: 'Out of hours behaviour',
                value: s.outOfHoursBehaviour,
                items: kOutOfHoursBehaviours,
                onChanged: (v) => widget.onPatch(
                    s.copyWith(outOfHoursBehaviour: v)),
              ),
              const SizedBox(height: 16),
              _Field(
                label: 'Out of hours message',
                controller: _outOfHoursMessageCtrl,
                maxLines: 3,
                onChanged: (_) => _emit(),
              ),
              const SizedBox(height: 16),
              _ToggleRow(
                title: 'Emergency override',
                subtitle:
                    'Allow urgent calls to escalate even outside hours',
                value: s.emergencyOverride,
                onChanged: (v) =>
                    widget.onPatch(s.copyWith(emergencyOverride: v)),
              ),
              if (s.emergencyOverride) ...[
                const SizedBox(height: 12),
                _Field(
                  label: 'Emergency transfer number',
                  controller: _emergencyTransferNumberCtrl,
                  onChanged: (_) => _emit(),
                ),
              ],
            ],
          ),
          const SizedBox(height: 20),
          _SectionCard(
            title: 'Voicemail',
            children: [
              _Field(
                label: 'Deliver messages to (email)',
                controller: _voicemailEmailCtrl,
                onChanged: (_) => _emit(),
              ),
              const SizedBox(height: 16),
              _Field(
                label: 'Also send SMS summary to',
                controller: _voicemailSmsCtrl,
                hint: '+61...',
                onChanged: (_) => _emit(),
              ),
              const SizedBox(height: 16),
              _ToggleRow(
                title: 'Include call transcript in email',
                subtitle: '',
                value: s.includeTranscriptInEmail,
                onChanged: (v) => widget.onPatch(
                    s.copyWith(includeTranscriptInEmail: v)),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ── Tab 4: Keywords ───────────────────────────────────────────────────────────

class _KeywordsTab extends StatefulWidget {
  final AgentSettings settings;
  final void Function(AgentSettings) onPatch;

  const _KeywordsTab({required this.settings, required this.onPatch});

  @override
  State<_KeywordsTab> createState() => _KeywordsTabState();
}

class _KeywordsTabState extends State<_KeywordsTab> {
  late final TextEditingController _deflectionMessageCtrl;
  late final TextEditingController _keywordEscalationNumberCtrl;

  @override
  void initState() {
    super.initState();
    _deflectionMessageCtrl =
        TextEditingController(text: widget.settings.deflectionMessage);
    _keywordEscalationNumberCtrl = TextEditingController(
        text: widget.settings.keywordEscalationNumber ?? '');
  }

  @override
  void dispose() {
    _deflectionMessageCtrl.dispose();
    _keywordEscalationNumberCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.settings;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Zone 1: Termination keywords
          _SectionCard(
            title: 'Termination Keywords',
            children: [
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Termination keywords',
                            style: _T.label(
                                size: 13, weight: FontWeight.w600)),
                        const SizedBox(height: 2),
                        Text(
                            'If these words are detected, the call is terminated immediately',
                            style: _T.body(size: 12, color: _T.muted)),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              _TagInput(
                tags: s.terminationKeywords,
                chipColor: _T.red,
                onChanged: (tags) => widget.onPatch(
                    s.copyWith(terminationKeywords: tags)),
              ),
              const SizedBox(height: 16),
              _DropdownField(
                label: 'Termination action',
                value: s.terminationAction,
                items: kTerminationActions,
                onChanged: (v) =>
                    widget.onPatch(s.copyWith(terminationAction: v)),
              ),
            ],
          ),
          const SizedBox(height: 20),
          // Zone 2: Escalation keywords
          _SectionCard(
            title: 'Escalation Keywords',
            children: [
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Escalation keywords',
                            style: _T.label(
                                size: 13, weight: FontWeight.w600)),
                        const SizedBox(height: 2),
                        Text(
                            'Trigger immediate human escalation when detected',
                            style: _T.body(size: 12, color: _T.muted)),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              _TagInput(
                tags: s.escalationKeywords,
                chipColor: _T.amber,
                onChanged: (tags) => widget.onPatch(
                    s.copyWith(escalationKeywords: tags)),
              ),
              const SizedBox(height: 16),
              _Field(
                label: 'Escalation transfer number',
                controller: _keywordEscalationNumberCtrl,
                hint: '+61...',
                onChanged: (_) {
                  final num = _keywordEscalationNumberCtrl.text.trim();
                  widget.onPatch(s.copyWith(
                      keywordEscalationNumber: num.isEmpty ? null : num));
                },
              ),
            ],
          ),
          const SizedBox(height: 20),
          // Zone 3: Priority keywords
          _SectionCard(
            title: 'Priority Keywords',
            children: [
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Priority keywords',
                            style: _T.label(
                                size: 13, weight: FontWeight.w600)),
                        const SizedBox(height: 2),
                        Text(
                            'Identify high-value or priority callers for preferential routing',
                            style: _T.body(size: 12, color: _T.muted)),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              _TagInput(
                tags: s.priorityKeywords,
                chipColor: _T.accent,
                onChanged: (tags) =>
                    widget.onPatch(s.copyWith(priorityKeywords: tags)),
              ),
            ],
          ),
          const SizedBox(height: 20),
          // Zone 4: Off-limits keywords
          _SectionCard(
            title: 'Off-Limits Keywords',
            children: [
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Off-limits keywords',
                            style: _T.label(
                                size: 13, weight: FontWeight.w600)),
                        const SizedBox(height: 2),
                        Text(
                            'Topics the agent should not discuss — triggers deflection message',
                            style: _T.body(size: 12, color: _T.muted)),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              _TagInput(
                tags: s.offLimitsKeywords,
                chipColor: _T.sub,
                onChanged: (tags) =>
                    widget.onPatch(s.copyWith(offLimitsKeywords: tags)),
              ),
              const SizedBox(height: 16),
              _Field(
                label: 'Deflection message',
                controller: _deflectionMessageCtrl,
                maxLines: 2,
                hint:
                    "e.g. I'm sorry, I can't discuss that topic. Is there anything else I can help you with?",
                onChanged: (_) => widget.onPatch(s.copyWith(
                    deflectionMessage: _deflectionMessageCtrl.text)),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ── _TagInput ─────────────────────────────────────────────────────────────────

class _TagInput extends StatefulWidget {
  final List<String> tags;
  final Color chipColor;
  final void Function(List<String>) onChanged;

  const _TagInput({
    required this.tags,
    required this.chipColor,
    required this.onChanged,
  });

  @override
  State<_TagInput> createState() => _TagInputState();
}

class _TagInputState extends State<_TagInput> {
  late List<String> _tags;
  final TextEditingController _ctrl = TextEditingController();
  final FocusNode _focus = FocusNode();

  @override
  void initState() {
    super.initState();
    _tags = List.from(widget.tags);
  }

  @override
  void didUpdateWidget(_TagInput oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.tags != widget.tags) {
      _tags = List.from(widget.tags);
    }
  }

  void _add(String v) {
    final trimmed = v.trim().replaceAll(',', '').trim();
    if (trimmed.isEmpty) return;
    if (_tags.contains(trimmed)) {
      _ctrl.clear();
      return;
    }
    setState(() => _tags.add(trimmed));
    _ctrl.clear();
    widget.onChanged(List.from(_tags));
  }

  void _remove(String tag) {
    setState(() => _tags.remove(tag));
    widget.onChanged(List.from(_tags));
  }

  @override
  void dispose() {
    _ctrl.dispose();
    _focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: _T.inputFill,
        border: Border.all(color: _T.border),
        borderRadius: BorderRadius.circular(8),
      ),
      padding: const EdgeInsets.all(8),
      child: Wrap(
        spacing: 6,
        runSpacing: 6,
        children: [
          ..._tags.map((tag) => _TagChip(
                tag: tag,
                color: widget.chipColor,
                onRemove: () => _remove(tag),
              )),
          IntrinsicWidth(
            child: TextField(
              controller: _ctrl,
              focusNode: _focus,
              onSubmitted: (v) {
                _add(v);
                _focus.requestFocus();
              },
              onChanged: (v) {
                if (v.endsWith(',')) _add(v);
              },
              style: _T.body(),
              decoration: const InputDecoration(
                hintText: 'Add tag...',
                border: InputBorder.none,
                isDense: true,
                contentPadding:
                    EdgeInsets.symmetric(horizontal: 4, vertical: 6),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TagChip extends StatelessWidget {
  final String tag;
  final Color color;
  final VoidCallback onRemove;

  const _TagChip(
      {required this.tag, required this.color, required this.onRemove});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(8, 4, 4, 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        border: Border.all(color: color.withValues(alpha: 0.3)),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(tag, style: _T.label(size: 11, color: color)),
          const SizedBox(width: 4),
          GestureDetector(
            onTap: onRemove,
            child: Icon(Icons.close, size: 12, color: color),
          ),
        ],
      ),
    );
  }
}

// ── Tab 5: Behaviour ──────────────────────────────────────────────────────────

class _BehaviourTab extends StatefulWidget {
  final AgentSettings settings;
  final void Function(AgentSettings) onPatch;

  const _BehaviourTab({required this.settings, required this.onPatch});

  @override
  State<_BehaviourTab> createState() => _BehaviourTabState();
}

class _BehaviourTabState extends State<_BehaviourTab> {
  late final TextEditingController _silenceTimeoutCtrl;
  late final TextEditingController _silencePromptCtrl;

  @override
  void initState() {
    super.initState();
    _silenceTimeoutCtrl = TextEditingController(
        text: widget.settings.silenceTimeout.toString());
    _silencePromptCtrl =
        TextEditingController(text: widget.settings.silencePrompt);
  }

  @override
  void dispose() {
    _silenceTimeoutCtrl.dispose();
    _silencePromptCtrl.dispose();
    super.dispose();
  }

  void _emit() {
    final timeout =
        int.tryParse(_silenceTimeoutCtrl.text.trim()) ??
            widget.settings.silenceTimeout;
    widget.onPatch(widget.settings.copyWith(
      silenceTimeout: timeout,
      silencePrompt: _silencePromptCtrl.text,
    ));
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.settings;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SectionCard(
            title: 'Response Settings',
            children: [
              _DropdownField(
                label: 'Max response length',
                value: s.maxResponseLength,
                items: kResponseLengths,
                onChanged: (v) =>
                    widget.onPatch(s.copyWith(maxResponseLength: v)),
              ),
              const SizedBox(height: 16),
              _DropdownField(
                label: 'Speaking pace',
                value: s.speakingPace,
                items: kSpeakingPaces,
                onChanged: (v) =>
                    widget.onPatch(s.copyWith(speakingPace: v)),
              ),
              const SizedBox(height: 16),
              _ToggleRow(
                title: 'Use filler words',
                subtitle:
                    'e.g. Sure, Of course, Absolutely — sounds more natural',
                value: s.useFillerWords,
                onChanged: (v) =>
                    widget.onPatch(s.copyWith(useFillerWords: v)),
              ),
              const Divider(height: 24),
              _ToggleRow(
                title: 'Confirm caller details before transfer',
                subtitle:
                    'Agent reads back name and reason before connecting',
                value: s.confirmCallerDetails,
                onChanged: (v) =>
                    widget.onPatch(s.copyWith(confirmCallerDetails: v)),
              ),
              const Divider(height: 24),
              _ToggleRow(
                title: 'Ask for callback number if line is busy',
                subtitle: '',
                value: s.askCallbackIfBusy,
                onChanged: (v) =>
                    widget.onPatch(s.copyWith(askCallbackIfBusy: v)),
              ),
            ],
          ),
          const SizedBox(height: 20),
          _SectionCard(
            title: 'Silence & Interruption',
            children: [
              Row(
                children: [
                  Expanded(
                    child: _Field(
                      label: 'Silence timeout (seconds)',
                      controller: _silenceTimeoutCtrl,
                      onChanged: (_) => _emit(),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: _DropdownField(
                      label: 'Action after silence',
                      value: s.silenceAction,
                      items: kSilenceActions,
                      onChanged: (v) =>
                          widget.onPatch(s.copyWith(silenceAction: v)),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              _Field(
                label: 'Silence prompt message',
                controller: _silencePromptCtrl,
                onChanged: (_) => _emit(),
              ),
              const SizedBox(height: 16),
              _ToggleRow(
                title: 'Allow caller to interrupt agent mid-sentence',
                subtitle: 'Barge-in detection',
                value: s.allowBargeIn,
                onChanged: (v) =>
                    widget.onPatch(s.copyWith(allowBargeIn: v)),
              ),
            ],
          ),
          const SizedBox(height: 20),
          _SectionCard(
            title: 'Recording & Transcription',
            children: [
              _ToggleRow(
                title: 'Record all calls',
                subtitle:
                    'Stored securely, accessible in Call Logs',
                value: s.recordCalls,
                onChanged: (v) =>
                    widget.onPatch(s.copyWith(recordCalls: v)),
              ),
              const Divider(height: 24),
              _ToggleRow(
                title: 'Generate post-call transcript',
                subtitle:
                    'Full text transcript delivered after each call',
                value: s.generateTranscript,
                onChanged: (v) =>
                    widget.onPatch(s.copyWith(generateTranscript: v)),
              ),
              const Divider(height: 24),
              _ToggleRow(
                title: 'Generate AI call summary',
                subtitle:
                    'Short summary of call reason and outcome emailed after each call',
                value: s.generateAiSummary,
                onChanged: (v) =>
                    widget.onPatch(s.copyWith(generateAiSummary: v)),
              ),
              const Divider(height: 24),
              _ToggleRow(
                title: 'Announce call recording to caller',
                subtitle: 'Legally required in some regions',
                value: s.announceRecording,
                onChanged: (v) =>
                    widget.onPatch(s.copyWith(announceRecording: v)),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ── Shared Widgets ────────────────────────────────────────────────────────────

class _SectionCard extends StatelessWidget {
  final String title;
  final List<Widget> children;

  const _SectionCard({required this.title, required this.children});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: _T.card,
        border: Border.all(color: _T.border),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
            child: Text(title,
                style: _T.label(size: 14, weight: FontWeight.w700)),
          ),
          const Divider(height: 1, thickness: 1, color: _T.border),
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: children,
            ),
          ),
        ],
      ),
    );
  }
}

class _Field extends StatelessWidget {
  final String label;
  final TextEditingController? controller;
  final int maxLines;
  final String? hint;
  final void Function(String)? onChanged;

  const _Field({
    this.label = '',
    this.controller,
    this.maxLines = 1,
    this.hint,
    this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (label.isNotEmpty) ...[
          _Label(label),
          const SizedBox(height: 6),
        ],
        TextField(
          controller: controller,
          maxLines: maxLines,
          onChanged: onChanged,
          style: _T.body(),
          decoration: _T.inputDeco(hint: hint),
        ),
      ],
    );
  }
}

class _DropdownField extends StatelessWidget {
  final String label;
  final String? value;
  final List<String> items;
  final void Function(String?)? onChanged;

  const _DropdownField({
    required this.label,
    required this.value,
    required this.items,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final safeValue = (value != null && items.contains(value)) ? value : items.first;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (label.isNotEmpty) ...[
          _Label(label),
          const SizedBox(height: 6),
        ],
        DropdownButtonFormField<String>(
          // ignore: deprecated_member_use
          value: safeValue,
          items: items
              .map((item) => DropdownMenuItem(
                    value: item,
                    child: Text(item, style: _T.body()),
                  ))
              .toList(),
          onChanged: onChanged,
          decoration: _T.inputDeco(),
          style: _T.body(),
          dropdownColor: _T.card,
          borderRadius: BorderRadius.circular(8),
          isExpanded: true,
        ),
      ],
    );
  }
}

class _ToggleRow extends StatelessWidget {
  final String title;
  final String subtitle;
  final bool value;
  final void Function(bool)? onChanged;

  const _ToggleRow({
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title,
                  style:
                      _T.label(size: 13, weight: FontWeight.w500, color: _T.text)),
              if (subtitle.isNotEmpty) ...[
                const SizedBox(height: 2),
                Text(subtitle, style: _T.body(size: 12, color: _T.sub)),
              ],
            ],
          ),
        ),
        const SizedBox(width: 12),
        Switch(
          value: value,
          onChanged: onChanged,
          activeThumbColor: _T.accent,
        ),
      ],
    );
  }
}

class _Label extends StatelessWidget {
  final String text;

  const _Label(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(text, style: _T.label(size: 12));
  }
}

class _InfoTip extends StatelessWidget {
  final String text;

  const _InfoTip({required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: _T.accentLight,
        border: Border.all(color: _T.accent.withValues(alpha: 0.2)),
        borderRadius: BorderRadius.circular(8),
      ),
      padding: const EdgeInsets.all(12),
      child: Row(
        children: [
          Icon(Icons.info_outline, size: 16, color: _T.accent),
          const SizedBox(width: 10),
          Expanded(
            child: Text(text, style: _T.body(size: 12, color: _T.accent)),
          ),
        ],
      ),
    );
  }
}

class _PillButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _PillButton(
      {required this.icon, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: onTap,
      icon: Icon(icon, size: 16, color: _T.accent),
      label: Text(label, style: _T.label(size: 12, color: _T.accent)),
      style: OutlinedButton.styleFrom(
        side: const BorderSide(color: _T.accent),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      ),
    );
  }
}

// ── Tab 6: Phone Numbers ──────────────────────────────────────────────────────

class _PhoneNumbersTab extends ConsumerStatefulWidget {
  final AgentSettings agentSettings;

  const _PhoneNumbersTab({required this.agentSettings});

  @override
  ConsumerState<_PhoneNumbersTab> createState() => _PhoneNumbersTabState();
}

class _PhoneNumbersTabState extends ConsumerState<_PhoneNumbersTab> {
  List<Map<String, dynamic>> _numbers = [];
  bool _loading = true;
  bool _assigning = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadNumbers();
  }

  @override
  void didUpdateWidget(_PhoneNumbersTab old) {
    super.didUpdateWidget(old);
    if (old.agentSettings.id != widget.agentSettings.id) _loadNumbers();
  }

  Future<void> _loadNumbers() async {
    setState(() { _loading = true; _error = null; });
    try {
      final companyId = await ref.read(_companyIdProvider.future);
      final supabase = Supabase.instance.client;
      final rows = await supabase
          .from('phone_numbers')
          .select('id, number, telnyx_number_id, status, assigned_agent_id')
          .eq('company_id', companyId)
          .eq('status', 'active')
          .order('number');
      if (mounted) setState(() { _numbers = List<Map<String, dynamic>>.from(rows); _loading = false; });
    } catch (e) {
      if (mounted) setState(() { _error = e.toString(); _loading = false; });
    }
  }

  Future<void> _assign(Map<String, dynamic> number) async {
    final agentId = widget.agentSettings.id;
    if (agentId == null || !widget.agentSettings.isDeployed) return;

    final telnyxNumberId = number['telnyx_number_id'] as String?;
    if (telnyxNumberId == null) return;

    setState(() => _assigning = true);
    try {
      await ref.read(agentListProvider.notifier).assignNumber(telnyxNumberId, agentId);
      await _loadNumbers();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${number['number']} assigned to agent', style: _T.body(color: Colors.white)),
            backgroundColor: _T.green,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Assign failed: $e', style: _T.body(color: Colors.white)),
            backgroundColor: _T.red,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _assigning = false);
    }
  }

  Future<void> _unassign(Map<String, dynamic> number) async {
    final telnyxNumberId = number['telnyx_number_id'] as String?;
    if (telnyxNumberId == null) return;

    setState(() => _assigning = true);
    try {
      await ref.read(agentListProvider.notifier).unassignNumber(telnyxNumberId);
      await _loadNumbers();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${number['number']} unassigned', style: _T.body(color: Colors.white)),
            backgroundColor: _T.amber,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Unassign failed: $e', style: _T.body(color: Colors.white)),
            backgroundColor: _T.red,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _assigning = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final agentId = widget.agentSettings.id;

    if (!widget.agentSettings.isDeployed) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(40),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.cloud_off, size: 48, color: _T.muted),
              const SizedBox(height: 16),
              Text('Deploy the agent first',
                  style: _T.label(size: 16, weight: FontWeight.w600, color: _T.sub)),
              const SizedBox(height: 8),
              Text(
                'You need to deploy this agent to Telnyx before you can assign phone numbers.',
                style: _T.body(color: _T.muted),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    if (_loading) return const Center(child: CircularProgressIndicator());

    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.error_outline, color: _T.red, size: 40),
              const SizedBox(height: 12),
              Text(_error!, style: _T.body(color: _T.sub)),
              const SizedBox(height: 12),
              OutlinedButton(onPressed: _loadNumbers, child: const Text('Retry')),
            ],
          ),
        ),
      );
    }

    // Split numbers into assigned-to-this-agent, assigned-to-other, and available
    final assignedToThis = _numbers.where((n) => n['assigned_agent_id'] == agentId).toList();
    final assignedToOther = _numbers.where((n) =>
        n['assigned_agent_id'] != null && n['assigned_agent_id'] != agentId).toList();
    final available = _numbers.where((n) => n['assigned_agent_id'] == null).toList();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _InfoTip(
            text: 'Assign phone numbers to this agent. Inbound calls to assigned numbers will be handled by the AI agent.',
          ),
          const SizedBox(height: 20),

          // Assigned to this agent
          _SectionCard(
            title: 'Assigned to this Agent (${assignedToThis.length})',
            children: [
              if (assignedToThis.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: Text('No numbers assigned yet.', style: _T.body(color: _T.muted)),
                ),
              ...assignedToThis.map((n) => _NumberRow(
                number: n['number'] as String? ?? '',
                status: 'assigned',
                trailing: OutlinedButton(
                  onPressed: _assigning ? null : () => _unassign(n),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: _T.red,
                    side: const BorderSide(color: _T.red),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  ),
                  child: Text('Unassign', style: _T.label(size: 11, color: _T.red)),
                ),
              )),
            ],
          ),
          const SizedBox(height: 20),

          // Available numbers
          _SectionCard(
            title: 'Available Numbers (${available.length})',
            children: [
              if (available.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: Text(
                    'No available numbers. Purchase numbers from the Phone Numbers page.',
                    style: _T.body(color: _T.muted),
                  ),
                ),
              ...available.map((n) => _NumberRow(
                number: n['number'] as String? ?? '',
                status: 'available',
                trailing: ElevatedButton(
                  onPressed: _assigning ? null : () => _assign(n),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _T.accent,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    elevation: 0,
                  ),
                  child: Text('Assign', style: _T.label(size: 11, color: Colors.white)),
                ),
              )),
            ],
          ),

          if (assignedToOther.isNotEmpty) ...[
            const SizedBox(height: 20),
            _SectionCard(
              title: 'Assigned to Other Agents (${assignedToOther.length})',
              children: assignedToOther.map((n) => _NumberRow(
                number: n['number'] as String? ?? '',
                status: 'other',
                trailing: Text('In use', style: _T.label(size: 11, color: _T.muted)),
              )).toList(),
            ),
          ],
        ],
      ),
    );
  }
}

class _NumberRow extends StatelessWidget {
  final String number;
  final String status; // 'assigned', 'available', 'other'
  final Widget trailing;

  const _NumberRow({
    required this.number,
    required this.status,
    required this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: status == 'assigned'
                  ? _T.green.withValues(alpha: 0.1)
                  : status == 'available'
                      ? _T.accentLight
                      : _T.inputFill,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              Icons.phone,
              size: 16,
              color: status == 'assigned'
                  ? _T.green
                  : status == 'available'
                      ? _T.accent
                      : _T.muted,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(number, style: _T.body(size: 13)),
          ),
          trailing,
        ],
      ),
    );
  }
}

class _DeployButton extends StatelessWidget {
  final bool isDeployed;
  final bool isDeploying;
  final bool isDirty;
  final VoidCallback onDeploy;
  final VoidCallback onDeactivate;

  const _DeployButton({
    required this.isDeployed,
    required this.isDeploying,
    required this.isDirty,
    required this.onDeploy,
    required this.onDeactivate,
  });

  @override
  Widget build(BuildContext context) {
    if (isDeploying) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: _T.accentLight,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(
              width: 14,
              height: 14,
              child: CircularProgressIndicator(strokeWidth: 2, color: _T.accent),
            ),
            const SizedBox(width: 8),
            Text('Deploying...', style: _T.label(size: 12, color: _T.accent)),
          ],
        ),
      );
    }

    if (isDeployed) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: _T.green.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 6,
                  height: 6,
                  decoration: const BoxDecoration(
                    color: _T.green,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 6),
                Text('Live on Telnyx',
                    style: _T.label(size: 11, color: _T.green)),
              ],
            ),
          ),
          const SizedBox(width: 8),
          OutlinedButton(
            onPressed: onDeploy,
            style: OutlinedButton.styleFrom(
              foregroundColor: _T.accent,
              side: const BorderSide(color: _T.accent),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8)),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            ),
            child: Text(isDirty ? 'Save & sync' : 'Re-sync',
                style: _T.label(size: 11, color: _T.accent)),
          ),
          const SizedBox(width: 6),
          OutlinedButton(
            onPressed: onDeactivate,
            style: OutlinedButton.styleFrom(
              foregroundColor: _T.red,
              side: const BorderSide(color: _T.red),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8)),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            ),
            child: Text('Deactivate',
                style: _T.label(size: 11, color: _T.red)),
          ),
        ],
      );
    }

    // Not deployed
    return ElevatedButton.icon(
      onPressed: onDeploy,
      icon: const Icon(Icons.rocket_launch, size: 16),
      label: Text(isDirty ? 'Save & deploy' : 'Deploy to Telnyx',
          style: _T.label(size: 12, weight: FontWeight.w600, color: Colors.white)),
      style: ElevatedButton.styleFrom(
        backgroundColor: _T.accent,
        foregroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        elevation: 0,
      ),
    );
  }
}

// ── Tab 7: Knowledge Base ─────────────────────────────────────────────────────

class _KnowledgeBaseTab extends ConsumerStatefulWidget {
  final AgentSettings agentSettings;

  const _KnowledgeBaseTab({required this.agentSettings});

  @override
  ConsumerState<_KnowledgeBaseTab> createState() => _KnowledgeBaseTabState();
}

class _KnowledgeBaseTabState extends ConsumerState<_KnowledgeBaseTab> {
  List<Map<String, dynamic>> _items = [];
  bool _loading = true;
  bool _isEmbedding = false;
  String? _embeddingLabel;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadItems();
  }

  @override
  void didUpdateWidget(_KnowledgeBaseTab old) {
    super.didUpdateWidget(old);
    if (old.agentSettings.id != widget.agentSettings.id) _loadItems();
  }

  Future<void> _loadItems() async {
    final agentId = widget.agentSettings.id;
    if (agentId == null) {
      setState(() {
        _loading = false;
        _items = [];
      });
      return;
    }
    // Only show full-page spinner on initial load, not on refreshes
    if (_items.isEmpty) {
      setState(() { _loading = true; _error = null; });
    }
    try {
      final supabase = Supabase.instance.client;
      final rows = await supabase
          .from('agent_knowledge_items')
          .select()
          .eq('agent_id', agentId)
          .order('sort_order')
          .order('created_at');
      if (mounted) {
        setState(() {
          _items = List<Map<String, dynamic>>.from(rows);
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _loading = false;
        });
      }
    }
  }

  List<Map<String, dynamic>> get _qaItems =>
      _items.where((i) => i['item_type'] == 'qa').toList();

  List<Map<String, dynamic>> get _urlItems =>
      _items.where((i) => i['item_type'] == 'url').toList();

  List<Map<String, dynamic>> get _docItems =>
      _items.where((i) => i['item_type'] == 'document').toList();

  Future<void> _saveQaItem(String? id, String question, String answer) async {
    final agentId = widget.agentSettings.id;
    if (agentId == null) return;
    final companyId = await ref.read(_companyIdProvider.future);
    final supabase = Supabase.instance.client;
    if (id != null) {
      await supabase.from('agent_knowledge_items').update({
        'question': question,
        'answer': answer,
        'updated_at': DateTime.now().toIso8601String(),
      }).eq('id', id);
    } else {
      await supabase.from('agent_knowledge_items').insert({
        'agent_id': agentId,
        'company_id': companyId,
        'item_type': 'qa',
        'question': question,
        'answer': answer,
        'status': 'active',
        'sort_order': _qaItems.length,
      });
    }
    await _loadItems();
  }

  Future<void> _deleteItem(String id) async {
    final supabase = Supabase.instance.client;
    await supabase.from('agent_knowledge_items').delete().eq('id', id);
    await _loadItems();
  }

  Future<void> _embedUrl(String url) async {
    final agentId = widget.agentSettings.id;
    if (agentId == null) return;
    setState(() { _isEmbedding = true; _embeddingLabel = 'Embedding URL…'; });
    try {
      final supabase = Supabase.instance.client;
      await supabase.auth.refreshSession();
      final res = await supabase.functions.invoke(
        'telnyx-embed-url',
        body: {'agent_id': agentId, 'url': url},
      );
      if (res.status != 200) {
        throw Exception('Embed failed (${res.status}): ${res.data}');
      }
      await _loadItems();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Failed to embed URL: $e',
              style: _T.body(color: Colors.white)),
          backgroundColor: _T.red,
          behavior: SnackBarBehavior.floating,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ));
      }
    } finally {
      if (mounted) setState(() { _isEmbedding = false; _embeddingLabel = null; });
    }
  }

  Future<void> _uploadDocument() async {
    final agentId = widget.agentSettings.id;
    if (agentId == null) return;

    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf', 'txt', 'docx', 'md'],
      withData: true,
    );
    if (result == null || result.files.isEmpty) return;
    final file = result.files.first;
    if (file.bytes == null) return;

    setState(() { _isEmbedding = true; _embeddingLabel = 'Uploading document…'; });
    try {
      final companyId = await ref.read(_companyIdProvider.future);
      final supabase = Supabase.instance.client;
      // Sanitize filename: replace any character that isn't alphanumeric, dot, hyphen or underscore
      final safeFileName = file.name
          .replaceAll(RegExp(r'[^\w.\-]'), '_')
          .replaceAll(RegExp(r'_+'), '_');
      final storagePath = 'knowledge-docs/$companyId/$agentId/$safeFileName';

      // 1. Upload to Supabase Storage
      await supabase.storage
          .from('Knowledge Base Documents')
          .uploadBinary(storagePath, file.bytes!,
              fileOptions: const FileOptions(upsert: true));

      // 2. Push to Telnyx bucket + embed via edge function
      await supabase.auth.refreshSession();
      final res = await supabase.functions.invoke(
        'telnyx-embed-document',
        body: {
          'agent_id': agentId,
          'storage_path': storagePath,
          'file_name': safeFileName,
        },
      );
      if (res.status != 200) {
        throw Exception('Embed failed (${res.status}): ${res.data}');
      }

      await _loadItems();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Upload failed: $e',
              style: _T.body(color: Colors.white)),
          backgroundColor: _T.red,
          behavior: SnackBarBehavior.floating,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ));
      }
    } finally {
      if (mounted) setState(() { _isEmbedding = false; _embeddingLabel = null; });
    }
  }

  void _showAddQaDialog() {
    showDialog(
      context: context,
      builder: (_) => _QaDialog(
        onSave: (q, a) => _saveQaItem(null, q, a),
      ),
    );
  }

  void _showEditQaDialog(Map<String, dynamic> item) {
    showDialog(
      context: context,
      builder: (_) => _QaDialog(
        initialQuestion: item['question'] as String? ?? '',
        initialAnswer: item['answer'] as String? ?? '',
        onSave: (q, a) => _saveQaItem(item['id'] as String, q, a),
      ),
    );
  }

  void _showAddUrlDialog() {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: Text('Add Website URL',
            style: _T.label(size: 16, weight: FontWeight.w700)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Telnyx will crawl the site up to 5 levels deep and embed the content for RAG retrieval during calls.',
              style: _T.body(size: 12, color: _T.sub),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: controller,
              decoration: _T.inputDeco(hint: 'https://yourwebsite.com'),
              keyboardType: TextInputType.url,
              autofocus: true,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              final url = controller.text.trim();
              if (url.isNotEmpty) {
                Navigator.of(ctx).pop();
                _embedUrl(url);
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: _T.accent,
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8)),
            ),
            child: const Text('Embed URL'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final agentId = widget.agentSettings.id;

    if (agentId == null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.save_outlined, size: 40, color: _T.muted),
              const SizedBox(height: 12),
              Text('Save the agent first',
                  style: _T.label(
                      size: 14,
                      weight: FontWeight.w600,
                      color: _T.sub)),
              const SizedBox(height: 4),
              Text(
                'Knowledge Base is available after the agent has been saved.',
                style: _T.body(size: 13, color: _T.muted),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.error_outline, color: _T.red, size: 40),
              const SizedBox(height: 12),
              Text('Failed to load knowledge base',
                  style: _T.label(size: 14, color: _T.red)),
              const SizedBox(height: 8),
              Text(_error!, style: _T.body(color: _T.sub)),
              const SizedBox(height: 16),
              OutlinedButton(
                  onPressed: _loadItems, child: const Text('Retry')),
            ],
          ),
        ),
      );
    }

    return Stack(
      children: [
        ListView(
          padding: const EdgeInsets.all(28),
      children: [
        // ── Q&A ──
        _KbSectionHeader(
          icon: Icons.question_answer_outlined,
          title: 'Q&A Pairs',
          subtitle:
              'Exact answers injected directly into the agent\'s prompt — no RAG latency.',
          action: _PillButton(
              icon: Icons.add,
              label: 'Add Q&A',
              onTap: _showAddQaDialog),
        ),
        const SizedBox(height: 12),
        if (_qaItems.isEmpty)
          _KbEmptyHint(
              message:
                  'No Q&A pairs yet. Add specific questions your agent should answer precisely.')
        else
          for (final item in _qaItems) ...[
            _QaCard(
              question: item['question'] as String? ?? '',
              answer: item['answer'] as String? ?? '',
              onEdit: () => _showEditQaDialog(item),
              onDelete: () => _deleteItem(item['id'] as String),
            ),
            const SizedBox(height: 8),
          ],

        const SizedBox(height: 28),

        // ── URLs ──
        _KbSectionHeader(
          icon: Icons.language_outlined,
          title: 'Website URLs',
          subtitle:
              'Telnyx crawls & embeds these sites for semantic retrieval during calls.',
          action: _PillButton(
              icon: Icons.add_link,
              label: 'Add URL',
              onTap: _showAddUrlDialog),
        ),
        const SizedBox(height: 12),
        if (_urlItems.isEmpty)
          _KbEmptyHint(
              message:
                  'No URLs embedded yet. Add your website or documentation pages.')
        else
          for (final item in _urlItems) ...[
            _KbUrlCard(
              url: item['url'] as String? ?? '',
              status: item['status'] as String? ?? 'processing',
              onDelete: () => _deleteItem(item['id'] as String),
            ),
            const SizedBox(height: 8),
          ],

        const SizedBox(height: 28),

        // ── Documents ──
        _KbSectionHeader(
          icon: Icons.upload_file_outlined,
          title: 'Documents',
          subtitle: 'Upload PDFs, text files or docs (.pdf, .txt, .docx, .md).',
          action: _PillButton(
              icon: Icons.upload_outlined,
              label: 'Upload',
              onTap: _uploadDocument),
        ),
        const SizedBox(height: 12),
        if (_docItems.isEmpty)
          _KbEmptyHint(
              message:
                  'No documents uploaded yet. Upload product manuals, FAQs or policy docs.')
        else
          for (final item in _docItems) ...[
            _KbDocCard(
              name: item['content'] as String? ?? 'Document',
              status: item['status'] as String? ?? 'active',
              onDelete: () => _deleteItem(item['id'] as String),
            ),
            const SizedBox(height: 8),
          ],

        const SizedBox(height: 40),
      ],
        ),
        if (_isEmbedding)
          Container(
            color: Colors.white.withValues(alpha: 0.7),
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const CircularProgressIndicator(),
                  const SizedBox(height: 16),
                  Text(
                    _embeddingLabel ?? 'Processing…',
                    style: _T.label(size: 13, color: _T.sub),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

// ── Knowledge Base helper widgets ─────────────────────────────────────────────

class _KbSectionHeader extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Widget action;

  const _KbSectionHeader({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.action,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: _T.accentLight,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, size: 18, color: _T.accent),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title,
                  style: _T.label(
                      size: 14,
                      weight: FontWeight.w700,
                      color: _T.brand)),
              const SizedBox(height: 2),
              Text(subtitle, style: _T.body(size: 12, color: _T.sub)),
            ],
          ),
        ),
        const SizedBox(width: 12),
        action,
      ],
    );
  }
}

class _KbEmptyHint extends StatelessWidget {
  final String message;

  const _KbEmptyHint({required this.message});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: _T.inputFill,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: _T.border),
      ),
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Icon(Icons.info_outline, size: 16, color: _T.muted),
          const SizedBox(width: 10),
          Expanded(child: Text(message, style: _T.body(size: 12, color: _T.sub))),
        ],
      ),
    );
  }
}

class _QaCard extends StatelessWidget {
  final String question;
  final String answer;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _QaCard({
    required this.question,
    required this.answer,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: _T.border),
      ),
      padding: const EdgeInsets.all(14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  question.isEmpty ? 'No question' : question,
                  style: _T.label(
                      size: 13,
                      weight: FontWeight.w600,
                      color: _T.text),
                ),
                const SizedBox(height: 4),
                Text(
                  answer.isEmpty ? 'No answer' : answer,
                  style: _T.body(size: 12, color: _T.sub),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: onEdit,
            icon: const Icon(Icons.edit_outlined,
                size: 16, color: _T.sub),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
            tooltip: 'Edit',
          ),
          const SizedBox(width: 8),
          IconButton(
            onPressed: onDelete,
            icon: const Icon(Icons.delete_outline,
                size: 16, color: _T.red),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
            tooltip: 'Delete',
          ),
        ],
      ),
    );
  }
}

class _KbUrlCard extends StatelessWidget {
  final String url;
  final String status;
  final VoidCallback onDelete;

  const _KbUrlCard({
    required this.url,
    required this.status,
    required this.onDelete,
  });

  Color get _statusColor {
    switch (status) {
      case 'ready':
        return _T.green;
      case 'error':
        return _T.red;
      default:
        return _T.amber;
    }
  }

  String get _statusLabel {
    switch (status) {
      case 'ready':
        return 'Ready';
      case 'error':
        return 'Error';
      default:
        return 'Processing';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: _T.border),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Row(
        children: [
          Icon(Icons.language_outlined, size: 16, color: _T.sub),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              url,
              style: _T.body(size: 12, color: _T.text),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 10),
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: _statusColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              _statusLabel,
              style: TextStyle(
                fontFamily: _T.fontFamily,
                fontSize: 10,
                fontWeight: FontWeight.w600,
                color: _statusColor,
              ),
            ),
          ),
          const SizedBox(width: 8),
          IconButton(
            onPressed: onDelete,
            icon: const Icon(Icons.delete_outline,
                size: 16, color: _T.red),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
            tooltip: 'Remove',
          ),
        ],
      ),
    );
  }
}

class _KbDocCard extends StatelessWidget {
  final String name;
  final String status;
  final VoidCallback onDelete;

  const _KbDocCard({
    required this.name,
    required this.status,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: _T.border),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Row(
        children: [
          Icon(Icons.insert_drive_file_outlined,
              size: 16, color: _T.sub),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              name,
              style: _T.body(size: 12, color: _T.text),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 8),
          IconButton(
            onPressed: onDelete,
            icon: const Icon(Icons.delete_outline,
                size: 16, color: _T.red),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
            tooltip: 'Remove',
          ),
        ],
      ),
    );
  }
}

class _QaDialog extends StatefulWidget {
  final String initialQuestion;
  final String initialAnswer;
  final Future<void> Function(String question, String answer) onSave;

  const _QaDialog({
    this.initialQuestion = '',
    this.initialAnswer = '',
    required this.onSave,
  });

  @override
  State<_QaDialog> createState() => _QaDialogState();
}

class _QaDialogState extends State<_QaDialog> {
  late final TextEditingController _qCtrl;
  late final TextEditingController _aCtrl;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _qCtrl = TextEditingController(text: widget.initialQuestion);
    _aCtrl = TextEditingController(text: widget.initialAnswer);
  }

  @override
  void dispose() {
    _qCtrl.dispose();
    _aCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final q = _qCtrl.text.trim();
    final a = _aCtrl.text.trim();
    if (q.isEmpty || a.isEmpty) return;
    setState(() => _saving = true);
    try {
      await widget.onSave(q, a);
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape:
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      title: Text(
        widget.initialQuestion.isEmpty ? 'Add Q&A Pair' : 'Edit Q&A Pair',
        style: _T.label(size: 16, weight: FontWeight.w700),
      ),
      content: SizedBox(
        width: 480,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Question', style: _T.label(size: 12)),
            const SizedBox(height: 6),
            TextField(
              controller: _qCtrl,
              decoration: _T.inputDeco(
                  hint: 'e.g. What are your opening hours?'),
              maxLines: 2,
              autofocus: true,
            ),
            const SizedBox(height: 14),
            Text('Answer', style: _T.label(size: 12)),
            const SizedBox(height: 6),
            TextField(
              controller: _aCtrl,
              decoration: _T.inputDeco(
                  hint: 'e.g. We are open Monday to Friday, 9am to 5pm.'),
              maxLines: 4,
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _saving ? null : _submit,
          style: ElevatedButton.styleFrom(
            backgroundColor: _T.accent,
            foregroundColor: Colors.white,
            elevation: 0,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8)),
          ),
          child: _saving
              ? const SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: Colors.white),
                )
              : const Text('Save'),
        ),
      ],
    );
  }
}

// ── Save Bar ──────────────────────────────────────────────────────────────────

class _SaveBar extends StatelessWidget {
  final bool isSaving;
  final VoidCallback onSave;

  const _SaveBar({required this.isSaving, required this.onSave});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        border: const Border(top: BorderSide(color: _T.border)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 8,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
      child: Row(
        children: [
          const Icon(Icons.edit_note, size: 18, color: _T.amber),
          const SizedBox(width: 8),
          Text(
            'You have unsaved changes',
            style: _T.label(size: 13, weight: FontWeight.w500, color: _T.amber),
          ),
          const Spacer(),
          ElevatedButton(
            onPressed: isSaving ? null : onSave,
            style: ElevatedButton.styleFrom(
              backgroundColor: _T.accent,
              foregroundColor: Colors.white,
              padding:
                  const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8)),
              elevation: 0,
            ),
            child: isSaving
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white),
                  )
                : Text('Save changes',
                    style: _T.label(
                        size: 13,
                        weight: FontWeight.w600,
                        color: Colors.white)),
          ),
        ],
      ),
    );
  }
}
