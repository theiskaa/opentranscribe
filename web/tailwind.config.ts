import type { Config } from "tailwindcss";

const config: Config = {
  content: [
    "./app/**/*.{js,ts,jsx,tsx,mdx}",
    "./components/**/*.{js,ts,jsx,tsx,mdx}",
    "./lib/**/*.{js,ts,jsx,tsx,mdx}",
  ],
  theme: {
    extend: {
      colors: {
        canvas: "rgb(0 0 0 / <alpha-value>)",
        surface: {
          1: "var(--surface-1)",
        },
        line: {
          DEFAULT: "var(--hairline)",
          strong: "var(--hairline-strong)",
        },
        ink: {
          DEFAULT: "var(--ink)",
          body: "var(--ink-body)",
          muted: "var(--ink-muted)",
          faint: "var(--ink-faint)",
        },
      },
      maxWidth: {
        frame: "1200px",
        prose: "680px",
      },
      transitionTimingFunction: {
        out: "var(--ease-out)",
        settle: "cubic-bezier(0.32, 0.72, 0, 1)",
        spring: "cubic-bezier(0.34, 1.56, 0.64, 1)",
      },
    },
  },
  plugins: [],
};
export default config;
