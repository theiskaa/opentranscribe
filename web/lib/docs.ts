export type Doc = {
  label: string;
  file: string;
  stripPreamble?: boolean;
};

export const CHANGELOG: Doc = {
  label: "Changelog",
  file: "CHANGELOG.md",
  stripPreamble: true,
};

export const LICENSE: Doc = { label: "License", file: "LICENSE" };

export function stripPreamble(md: string): string {
  if (md.startsWith("## ")) return md;
  const start = md.indexOf("\n## ");
  return start === -1 ? md : md.slice(start + 1);
}
