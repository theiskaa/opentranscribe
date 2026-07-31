/// The reading page's quiet meta line: "Literary · Written Jun 29". Joined
/// with middle dots here, never inside a translation, and either half may be
/// absent (voice is null on records from before it was stored).
String reflectionMetaLine({String? voiceLabel, String? writtenLabel}) => [
  if (voiceLabel != null && voiceLabel.isNotEmpty) voiceLabel,
  if (writtenLabel != null && writtenLabel.isNotEmpty) writtenLabel,
].join(' · ');
