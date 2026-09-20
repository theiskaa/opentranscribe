export const SITE_URL = "https://opentranscribe.xyz";
export const SITE_NAME = "OpenTranscribe";

export const SITE_TAGLINE = "A private, offline voice journal for iOS.";

export const HERO_TITLE = "A voice journal that never leaves your phone.";

export const HERO_LEAD =
  "Tap once and talk. OpenTranscribe records, transcribes, and reflects entirely on your iPhone. No account, no sync, no telemetry, and it works the same in airplane mode.";

export const HERO_SIDES = [
  { src: "/shots/home@2x.png", alt: "The week of entries" },
  { src: "/shots/reflections@2x.png", alt: "A written reflection" },
] as const;

export const HERO_FACTS = ["Free, every feature", "Open source, MIT licensed", "Data not collected"] as const;

export const SITE_TITLE = "OpenTranscribe: an offline voice journal for iOS";
export const SITE_DESCRIPTION =
  "A voice journal for iOS that keeps everything on the device. Recording, transcription, and reflections all happen there; its one connection is the download of a Whisper model you choose. No account, no sync, no telemetry.";

export const GITHUB_URL = "https://github.com/theiskaa/opentranscribe";
export const GITHUB_RAW = "https://raw.githubusercontent.com/theiskaa/opentranscribe/main";
export const APP_STORE_URL = "https://apps.apple.com/app/opentranscribe/id6794718941";

export const CTA = {
  download: "Download on the App Store",
  source: "Read the source",
} as const;

export const FEATURES_INTRO = {
  title: "The whole journal, on the phone.",
  lead: "A handful of screens, and none of them needs a connection.",
} as const;

export const FEATURES = [
  {
    id: "record",
    title: "Talk. It writes it down.",
    body: "Tap once and talk. A live transcript appears while you speak, and when you stop, the full recording is transcribed on the device before it lands on home.",
    foot: "Apple speech models are downloaded once per language, or one Whisper model serves them all. Either way they run entirely on the handset, and airplane mode changes nothing.",
    shot: "/shots/recording@2x.png",
    cap: "Recording with live text",
  },
  {
    id: "entries",
    title: "Read it back, word for word.",
    body: "An entry holds the transcript beside its recording, organized by day across the week. Audio is kept by default, so when a better engine ships, old entries can be transcribed again and read better than the day they were spoken.",
    foot: "Keeping audio is a preference. Turn it off and each recording is deleted the moment its transcript lands.",
    shot: "/shots/entry@2x.png",
    cap: "A finished entry",
  },
  {
    id: "reflections",
    title: "Your days, summarized.",
    body: "Apple Intelligence reads the entries and writes a short reflection for every day, week, and month, entirely on the device. Voice, length, and how specific it gets are yours to set.",
    foot: "A quiet week is a valid result. When there is little to say, it says little, or nothing at all.",
    shot: "/shots/reflections@2x.png",
    cap: "A written reflection",
  },
  {
    id: "home",
    title: "Every day in its place.",
    body: "Home is the week: entries grouped by day under the week strip, reflections folded in above the days they describe. Nothing to file, nothing to tag; the calendar is the structure.",
    foot: "The strip moves between weeks. Tapping the title always brings it back to today.",
    shot: "/shots/home@2x.png",
    cap: "The week of entries",
  },
  {
    id: "models",
    title: "The models live on the device, too.",
    body: "Each language runs its own Apple speech model, downloaded once and shared with the system, or one Whisper model of your choosing serves them all. Pick the languages you speak and recognition follows, with no server behind it.",
    foot: "Engines are swappable behind one contract, and every one has to declare it runs on the device before the app will load it.",
    shot: "/shots/models@2x.png",
    cap: "On-device language models",
  },
] as const;

export const CLUB = {
  tag: "Club",
  title: "One payment, in for good.",
  price: "$25",
  priceNote: "Once. No subscription.",
  priceRegion: "In US dollars; the price follows your App Store region.",
  pitch: [
    "Everything that makes OpenTranscribe useful is free for everyone, and stays that way. The club is how the app is supported: an optional one-time purchase, with a few looks as thanks.",
    "It is made directly through the App Store, with no purchase SDK, no account, and no server behind it. Membership is verified on the device from Apple's own record, so it works in airplane mode, like everything else.",
  ],
  perksHead: "What you get",
  icons: {
    title: "App icons",
    note: "Signal, Lines, Dots, and every icon beyond Default.",
    items: [
      { name: "Default", src: "/icons/default.png", club: false },
      { name: "Signal", src: "/icons/signal.png", club: true },
      { name: "Lines", src: "/icons/lines.png", club: true },
      { name: "Dots", src: "/icons/dots.png", club: true },
    ],
  },
  themes: {
    title: "Club themes",
    note: "Every family beyond Default, each in light and dark.",
    items: [
      { name: "Gruvbox", dark: ["#282828", "#3C3836", "#EBDBB2", "#FE8019"], light: ["#FBF1C7", "#F2E5BC", "#3C3836", "#AF3A03"] },
      { name: "Midnight", dark: ["#0B1220", "#141D30", "#E6ECF7", "#7FA3FF"], light: ["#F6F8FB", "#E9EEF5", "#14213D", "#2F5BD1"] },
      { name: "Dracula", dark: ["#282A36", "#343746", "#F8F8F2", "#BD93F9"], light: ["#FFFBEB", "#F5F0DB", "#1F1F1F", "#644AC9"] },
      { name: "Sepia", dark: ["#2A2320", "#352C27", "#E8DCC4", "#C8814A"], light: ["#F4ECD8", "#ECE0C4", "#5B4636", "#8A5A2B"] },
      { name: "Nord", dark: ["#2E3440", "#3B4252", "#ECEFF4", "#88C0D0"], light: ["#ECEFF4", "#E5E9F0", "#2E3440", "#4C6A94"] },
      { name: "Catppuccin", dark: ["#1E1E2E", "#313244", "#CDD6F4", "#CBA6F7"], light: ["#EFF1F5", "#E6E9EF", "#4C4F69", "#8839EF"] },
      { name: "Tokyo Night", dark: ["#1A1B26", "#24283B", "#C0CAF5", "#7AA2F7"], light: ["#E1E2E7", "#D0D5E3", "#343B58", "#3760BF"] },
    ],
  },
} as const;

export const ENGINES = {
  title: "Three engines, all on the device.",
  lead: "Pick when your words should appear and the app picks the engine. Every engine has to declare that it runs on the device before the app will load it.",
  inUseLabel: "In use",
  speaking: {
    flag: "🇺🇸",
    language: "English (US)",
    ready: "Ready",
  },
  alsoReady: [
    { flag: "🇪🇸", name: "Español (ES)" },
    { flag: "🇫🇷", name: "Français (FR)" },
    { flag: "🇩🇪", name: "Deutsch (DE)" },
  ],
  cards: [
    {
      id: "speech",
      name: "SpeechAnalyzer",
      maker: "Apple",
      mark: "apple",
      note: "Apple's newest engine, a downloaded model per language. Shows your words as you speak.",
      facts: [
        { icon: "waveform", text: "Words as you speak" },
        { icon: "globe", text: "A model per language" },
        { icon: "checkmark", text: "iOS 26" },
      ],
    },
    {
      id: "whisper",
      name: "Whisper",
      maker: "OpenAI, through whisper.cpp",
      mark: "openai",
      note: "An open model on whisper.cpp, one download for every language. Writes your words after you stop.",
      facts: [
        { icon: "textAlignleft", text: "Words after you stop" },
        { icon: "globe", text: "About a hundred languages" },
        { icon: "arrowDownCircle", text: "One model download" },
      ],
    },
    {
      id: "dictation",
      name: "Dictation",
      maker: "Apple",
      mark: "apple",
      note: "The recognizer behind iOS keyboard dictation. Shows your words as you speak.",
      facts: [
        { icon: "waveform", text: "Words as you speak" },
        { icon: "globe", text: "The languages iOS dictates" },
        { icon: "checkmark", text: "Nothing to download" },
      ],
    },
  ],
  models: [
    {
      name: "Tiny",
      size: "32.2 MB",
      quality: "Basic",
      level: 1,
      info: "The smallest and fastest. Rough on names and accents, fine for a quick note.",
    },
    {
      name: "Base",
      size: "59.7 MB",
      quality: "Good",
      level: 2,
      info: "Quick, with clearer words than the smallest. Good for short notes in a quiet room.",
    },
    {
      name: "Small",
      size: "190.1 MB",
      quality: "Better",
      level: 3,
      info: "The balance most iPhones want. Accurate for everyday speech in every language.",
    },
    {
      name: "Medium",
      size: "539.2 MB",
      quality: "Best",
      level: 4,
      info: "Slower and careful. Strong on accents, quiet takes, and long entries.",
    },
    {
      name: "Large Turbo",
      size: "574.0 MB",
      quality: "Top",
      level: 5,
      info: "The best on offer. Needs a recent iPhone and a little patience per entry.",
    },
  ],
  inUse: "Small",
  leads: "whisper",
} as const;

export const AUDIT = {
  title: "Nothing ever leaves your phone.",
  lead: "A claim like that cannot be backed by a privacy policy, only by source you can read. The code is public and MIT licensed, and every card names the file that holds it, linked to the source.",
  ledger: {
    head: "What the app connects to",
    never: "Never",
    rows: ["Analytics", "Crash reporting", "Accounts and sync", "Your audio or your words"],
    one: { name: "A Whisper model you ask for", note: "One pinned host, nothing sent" },
  },
  rows: [
    {
      icon: "globe",
      claim: "The app opens one kind of connection: a model download you ask for.",
      held: "One allowlisted file, one pinned host, nothing sent. A test fails if any other file reaches the network.",
      files: ["packages/transcriber/lib/src/whisper/model_fetcher.dart", "test/one_rule_test.dart"],
    },
    {
      icon: "waveform",
      claim: "Your voice is never transcribed off the phone.",
      held: "Every engine answers onDeviceOnly. The app refuses one that answers false.",
      files: ["packages/transcriber/lib/src/transcribe/transcription_engine.dart"],
    },
    {
      icon: "mic",
      claim: "Recordings stay in the native layer.",
      held: "Only paths, durations, levels, and text cross a channel. Audio bytes never do.",
      files: ["packages/transcriber/ios/transcriber/Sources/transcriber/AudioCapture.swift"],
    },
    {
      icon: "lock",
      claim: "The journal is encrypted on the phone.",
      held: "A random per-device key, generated on first launch and held in the Keychain.",
      files: ["lib/core/app/local_service.dart"],
    },
    {
      icon: "heartFill",
      claim: "Joining the club carries no journal data.",
      held: "Direct StoreKit 2, verified on the device. No purchase SDK, no server.",
      files: ["ios/Runner/SupportStore.swift"],
    },
    {
      icon: "checkmark",
      claim: "The binary is only what its source says.",
      held: "No Swift code reaches a method by name at runtime, and a test bans it.",
      files: ["test/no_dynamic_dispatch_test.dart"],
    },
  ],
} as const;
