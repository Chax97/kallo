import { serve } from "https://deno.land/std@0.168.0/http/server.ts";

serve(async (req) => {
  const settings = await req.json();

  const prompt = buildPrompt(settings);

  return new Response(JSON.stringify({ prompt }), {
    headers: { "Content-Type": "application/json" },
  });
});

// ── Helpers ───────────────────────────────────────────────────────────────────

function list(items: string[]): string {
  return items.map((i) => `- ${i}`).join("\n");
}

function yesNo(val: boolean): string {
  return val ? "Yes" : "No";
}

// ── Prompt builder ────────────────────────────────────────────────────────────

function buildPrompt(s: Record<string, unknown>): string {
  const businessName = (s.business_name as string) || "the business";
  const agentName = (s.agent_name as string) || "Alex";
  const businessDescription = (s.business_description as string) || "";
  const businessHours = (s.business_hours as string) || "Mon–Fri 9am–5pm";
  const language = (s.language as string) || "English (AU)";
  const persona = (s.persona as string) || "Professional";
  const customInstructions = (s.custom_instructions as string) || "";
  const announceAiDisclosure = s.announce_ai_disclosure !== false;

  const qualificationQuestions = (s.qualification_questions as QQuestion[]) ?? [];
  const defaultDestination = (s.default_destination as string) || "Take a message";

  const transferOnHumanRequest = s.transfer_on_human_request !== false;
  const transferOnRepeat = s.transfer_on_repeat !== false;
  const transferOnFailedAttempts = s.transfer_on_failed_attempts !== false;
  const transferOnDurationExceeded = s.transfer_on_duration_exceeded === true;
  const maxDurationMinutes = (s.max_duration_minutes as number) ?? 10;
  const outOfHoursBehaviour =
    (s.out_of_hours_behaviour as string) || "Take a message and email to team";
  const outOfHoursMessage = (s.out_of_hours_message as string) || "";
  const emergencyOverride = s.emergency_override === true;
  const emergencyTransferNumber = s.emergency_transfer_number as string | undefined;
  const voicemailEmail = s.voicemail_email as string | undefined;
  const includeTranscriptInEmail = s.include_transcript_in_email !== false;

  const terminationKeywords = (s.termination_keywords as string[]) ?? ["bomb", "threat", "kill"];
  const terminationAction =
    (s.termination_action as string) || "End call immediately, log incident";
  const escalationKeywords = (s.escalation_keywords as string[]) ?? ["urgent", "emergency"];
  const priorityKeywords = (s.priority_keywords as string[]) ?? [];
  const offLimitsKeywords = (s.off_limits_keywords as string[]) ?? [];
  const deflectionMessage = (s.deflection_message as string) || "";

  const maxResponseLength = (s.max_response_length as string) || "Medium (2–4 sentences)";
  const speakingPace = (s.speaking_pace as string) || "Normal";
  const useFillerWords = s.use_filler_words !== false;
  const confirmCallerDetails = s.confirm_caller_details !== false;
  const askCallbackIfBusy = s.ask_callback_if_busy === true;
  const silenceTimeout = (s.silence_timeout as number) ?? 8;
  const silenceAction = (s.silence_action as string) || "Prompt caller to respond";
  const silencePrompt =
    (s.silence_prompt as string) || "Sorry, I didn't catch that — are you still there?";
  const allowBargeIn = s.allow_barge_in !== false;
  const announceRecording = s.announce_recording !== false;

  // ── Build qualification section ────────────────────────────────────────────

  let qualSection = "";
  if (qualificationQuestions.length > 0) {
    const qLines = qualificationQuestions.map((q, i) => {
      const yesLine = `    - YES → ${q.yes_dest}${q.yes_custom_number ? ` (${q.yes_custom_number})` : ""}`;
      const noLine = `    - NO → ${q.no_dest}${q.no_custom_number ? ` (${q.no_custom_number})` : ""}`;
      const unclearLine = `    - UNCLEAR → ${q.unclear_dest}${q.unclear_custom_number ? ` (${q.unclear_custom_number})` : ""}`;
      return `  ${i + 1}. "${q.question}"\n${yesLine}\n${noLine}\n${unclearLine}`;
    });
    qualSection = `\n## Call Qualification\nAsk the following questions in order to qualify the caller:\n${qLines.join("\n\n")}\n\nIf the caller does not qualify through any route, your default action is: ${defaultDestination}.`;
  }

  // ── Build escalation triggers section ─────────────────────────────────────

  const escalationTriggers: string[] = [];
  if (transferOnHumanRequest) escalationTriggers.push("the caller explicitly asks to speak with a human or agent");
  if (transferOnRepeat) escalationTriggers.push("the caller repeats the same question or concern more than twice");
  if (transferOnFailedAttempts) escalationTriggers.push("you fail to resolve the caller's issue after multiple attempts");
  if (transferOnDurationExceeded) escalationTriggers.push(`the call exceeds ${maxDurationMinutes} minutes`);

  const escalationSection = escalationTriggers.length > 0
    ? `\n## Escalation Triggers\nTransfer the call to a human immediately if any of the following occur:\n${list(escalationTriggers)}`
    : "";

  // ── Build out-of-hours section ─────────────────────────────────────────────

  const oohSection = `\n## Out-of-Hours Behaviour\nOutside of business hours (${businessHours}), your behaviour is: ${outOfHoursBehaviour}.${outOfHoursMessage ? `\nMessage to convey: "${outOfHoursMessage}"` : ""}`;

  // ── Build emergency section ────────────────────────────────────────────────

  const emergencySection = emergencyOverride && emergencyTransferNumber
    ? `\n## Emergency Override\nIf the caller indicates a life-threatening emergency, immediately transfer to: ${emergencyTransferNumber}. Do not delay.`
    : "";

  // ── Build keywords sections ────────────────────────────────────────────────

  const terminationSection = terminationKeywords.length > 0
    ? `\n## Termination Keywords\nIf any of the following keywords are detected, immediately perform this action — ${terminationAction}:\n${list(terminationKeywords)}`
    : "";

  const escalationKeywordsSection = escalationKeywords.length > 0
    ? `\n## Escalation Keywords\nIf any of the following keywords are detected, escalate the call immediately:\n${list(escalationKeywords)}`
    : "";

  const prioritySection = priorityKeywords.length > 0
    ? `\n## Priority Callers\nIf any of the following keywords are detected, treat this caller as high priority and elevate service accordingly:\n${list(priorityKeywords)}`
    : "";

  const offLimitsSection = offLimitsKeywords.length > 0
    ? `\n## Off-Limits Topics\nDo not discuss the following topics under any circumstances. If raised, use this deflection: "${deflectionMessage || "I'm sorry, I'm not able to help with that. Is there anything else I can assist with?"}"\n${list(offLimitsKeywords)}`
    : "";

  // ── Build behaviour section ────────────────────────────────────────────────

  const behaviourLines = [
    `Response length: ${maxResponseLength}.`,
    `Speaking pace: ${speakingPace}.`,
    useFillerWords
      ? "Use natural filler words (e.g. 'sure', 'of course', 'let me check that') to sound conversational."
      : "Avoid filler words. Be direct and concise.",
    confirmCallerDetails
      ? "Confirm the caller's name and contact details before ending the call."
      : "",
    askCallbackIfBusy
      ? "If the caller cannot be helped immediately, offer to arrange a callback."
      : "",
    allowBargeIn
      ? "Allow the caller to interrupt you mid-sentence. Stop speaking immediately when they do."
      : "Complete your current sentence before pausing for the caller to respond.",
    announceRecording
      ? "Inform the caller at the start of the call that the conversation may be recorded."
      : "",
    `If silence is detected for more than ${silenceTimeout} seconds, ${silenceAction === "Prompt caller to respond" ? `prompt the caller: "${silencePrompt}"` : silenceAction.toLowerCase()}.`,
  ].filter(Boolean);

  const behaviourSection = `\n## Behaviour\n${behaviourLines.join("\n")}`;

  // ── Build voicemail section ────────────────────────────────────────────────

  const voicemailSection = voicemailEmail
    ? `\n## Voicemail & Messages\nWhen taking a message, record the caller's name, number, and reason for calling. ${includeTranscriptInEmail ? "Include the call transcript in the email. " : ""}Send the message to: ${voicemailEmail}.`
    : "";

  // ── Assemble full prompt ───────────────────────────────────────────────────

  const lines: string[] = [
    `# Role`,
    `You are ${agentName}, an AI phone receptionist for ${businessName}. ${businessDescription}`,
    ``,
    `## Core Identity`,
    `- Name: ${agentName}`,
    `- Business: ${businessName}`,
    `- Language: ${language}`,
    `- Persona: ${persona}`,
    `- Business hours: ${businessHours}`,
    announceAiDisclosure
      ? "- Disclose that you are an AI assistant if the caller directly asks."
      : "- Do not proactively mention that you are an AI.",
    ``,
  ];

  if (customInstructions) {
    lines.push(`## Special Instructions`, customInstructions, ``);
  }

  if (qualSection) lines.push(qualSection, ``);
  if (escalationSection) lines.push(escalationSection, ``);
  if (oohSection) lines.push(oohSection, ``);
  if (emergencySection) lines.push(emergencySection, ``);
  if (terminationSection) lines.push(terminationSection, ``);
  if (escalationKeywordsSection) lines.push(escalationKeywordsSection, ``);
  if (prioritySection) lines.push(prioritySection, ``);
  if (offLimitsSection) lines.push(offLimitsSection, ``);
  lines.push(behaviourSection, ``);
  if (voicemailSection) lines.push(voicemailSection, ``);

  lines.push(
    `## General Rules`,
    `- Always be polite and professional.`,
    `- Never make up information about ${businessName}. If you don't know the answer, say so and offer to take a message.`,
    `- Keep the conversation focused. Do not engage with topics unrelated to ${businessName}'s services.`,
    `- End every call politely, summarising any actions taken.`,
  );

  return lines.join("\n");
}

// ── Types ─────────────────────────────────────────────────────────────────────

interface QQuestion {
  id: string;
  question: string;
  yes_dest: string;
  yes_custom_number?: string;
  no_dest: string;
  no_custom_number?: string;
  unclear_dest: string;
  unclear_custom_number?: string;
}
