export const SITE_URL = "https://opentranscribe.xyz";
export const SITE_NAME = "OpenTranscribe";

export const SITE_TAGLINE = "A private, offline voice journal for iOS.";

export const HERO_LEAD =
  "A voice journal for iOS that records, transcribes, and reflects entirely on the device, with no network access.";

export const SITE_TITLE = "OpenTranscribe: an offline voice journal for iOS";
export const SITE_DESCRIPTION =
  "A voice journal for iOS with no network layer. Recording, transcription, and reflections all happen on the device. No account, no sync, no telemetry.";

export const GITHUB_URL = "https://github.com/theiskaa/opentranscribe";
export const GITHUB_RAW = "https://raw.githubusercontent.com/theiskaa/opentranscribe/main";
export const APP_STORE_URL = "https://apps.apple.com/app/opentranscribe/id6794718941";

export const FEATURES = [
  {
    id: "record",
    n: "01",
    label: "Record",
    title: "Talk. It writes it down.",
    body: "Tap once and talk. A live transcript appears while you speak, and when you stop, the full recording is transcribed on the device before it lands on home.",
    foot: "Speech models are downloaded once per language and run entirely on the handset. Airplane mode changes nothing.",
    shot: "/shots/recording@2x.png",
    cap: "Recording with live text",
  },
  {
    id: "entries",
    n: "02",
    label: "Entries",
    title: "Read it back, word for word.",
    body: "An entry holds the transcript beside its recording, organized by day across the week. Audio is kept by default, so when a better engine ships, old entries can be transcribed again and read better than the day they were spoken.",
    foot: "Keeping audio is a preference. Turn it off and each recording is deleted the moment its transcript lands.",
    shot: "/shots/entry@2x.png",
    cap: "A finished entry",
  },
  {
    id: "reflections",
    n: "03",
    label: "Reflections",
    title: "Your days, summarized.",
    body: "Apple Intelligence reads the entries and writes a short reflection for every day, week, and month, entirely on the device. Voice, length, and how specific it gets are yours to set.",
    foot: "A quiet week is a valid result. When there is little to say, it says little, or nothing at all.",
    shot: "/shots/reflections@2x.png",
    cap: "A written reflection",
  },
  {
    id: "home",
    n: "04",
    label: "Home",
    title: "Every day in its place.",
    body: "Home is the week: entries grouped by day under the week strip, reflections folded in above the days they describe. Nothing to file, nothing to tag; the calendar is the structure.",
    foot: "The strip moves between weeks. Tapping the title always brings it back to today.",
    shot: "/shots/home@2x.png",
    cap: "The week of entries",
  },
  {
    id: "models",
    n: "05",
    label: "Models",
    title: "The models live on the device, too.",
    body: "Each language runs its own speech model, downloaded once and shared with the system. Pick the languages you speak and recognition follows, with no server behind it.",
    foot: "Engines are swappable behind one contract, and every one has to declare it runs on the device before the app will load it.",
    shot: "/shots/models@2x.png",
    cap: "On-device language models",
  },
] as const;

export const CLUB = {
  price: "$25",
  priceNote: "Once. No subscription.",
  pitch: [
    "OpenTranscribe is free and private, and supporting it keeps it that way. The club is an optional one-time purchase, made directly through the App Store with no purchase SDK, no account, and no server behind it.",
    "Membership is verified on the device from Apple's own record, so it works in airplane mode, like everything else.",
  ],
  perksHead: "Club members get",
  perks: [
    {
      title: "Formatted exports",
      note: "The whole journal as Markdown, as Obsidian notes, or as a website that opens with a player in any browser.",
    },
    {
      title: "Re-transcribe all",
      note: "The whole journal, heard again by a newer engine, without opening entries one by one.",
    },
    {
      title: "Future club features",
      note: "Whatever joins the club later, included.",
    },
  ],
} as const;

export const SHOTS = [
  { src: "/shots/home@2x.png", cap: "The week of entries" },
  { src: "/shots/recording@2x.png", cap: "Recording with live text" },
  { src: "/shots/entry@2x.png", cap: "A finished entry" },
  { src: "/shots/reflections@2x.png", cap: "A written reflection" },
] as const;

export const SHOT_RATIO = "567 / 1000";
