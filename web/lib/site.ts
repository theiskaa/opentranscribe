export const SITE_URL = "https://opentranscribe.xyz";
export const SITE_NAME = "OpenTranscribe";

export const SITE_TAGLINE = "A private, offline voice journal for iOS.";

export const HERO_LEAD =
  "A voice journal for iOS that records and transcribes entirely on the device, with no network access.";

export const SITE_TITLE = "OpenTranscribe: an offline voice journal for iOS";
export const SITE_DESCRIPTION =
  "A voice journal for iOS with no network layer. Recording, transcription, and the models live on the device. There is no account, no sync, and no telemetry.";

export const GITHUB_URL = "https://github.com/theiskaa/opentranscribe";

export const STEPS = [
  {
    n: "01",
    title: "Record",
    body: "Tap once and talk. A live transcript appears while you speak, and when you stop the full recording is transcribed on the device.",
    shot: "/shots/recording@2x.png",
  },
  {
    n: "02",
    title: "Home",
    body: "Finished entries land on home, organized by day across the week.",
    shot: "/shots/home@2x.png",
  },
  {
    n: "03",
    title: "Entry",
    body: "An entry holds the transcript and its recording. Audio is kept by default so an entry can be transcribed again later, or deleted after transcription if you turn keeping off.",
    shot: "/shots/entry@2x.png",
  },
] as const;

export const PRIVACY = [
  {
    claim: "Network",
    detail: "No requests, no sockets, no third-party SDKs. There is no networking code in the app.",
  },
  {
    claim: "Audio",
    detail:
      "Recordings stay in the native capture layer. Only file paths, durations, levels, and text cross into the app.",
  },
  {
    claim: "Engines",
    detail:
      "Every transcription engine must declare that it runs on the device. The app refuses one that does not.",
  },
  {
    claim: "Storage",
    detail: "Entries are stored encrypted on the phone.",
  },
  {
    claim: "Telemetry",
    detail: "No analytics, no crash reporting, no accounts.",
  },
] as const;

export const SHOTS = [
  { src: "/shots/models@2x.png", cap: "On-device language models" },
  { src: "/shots/recording@2x.png", cap: "Recording with live text" },
  { src: "/shots/entry@2x.png", cap: "A finished entry" },
  { src: "/shots/home@2x.png", cap: "The week of entries" },
] as const;

export const SHOT_W = 692;
export const SHOT_H = 1414;
