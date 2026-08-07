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
        canvas: "#111111",
        line: "#2A2A2C",
        ink: {
          DEFAULT: "#F5F5F5",
          2: "#98989E",
        },
      },
      maxWidth: {
        frame: "1200px",
        prose: "680px",
      },
      transitionTimingFunction: {
        out: "var(--ease-out)",
        entrance: "var(--ease-entrance)",
      },
    },
  },
  plugins: [],
};
export default config;
