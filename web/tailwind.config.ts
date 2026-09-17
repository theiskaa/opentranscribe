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
          3: "#6C6C72",
        },
        ok: {
          DEFAULT: "#4ADE80",
          deep: "#1A7F37",
        },
      },
      maxWidth: {
        frame: "1200px",
        prose: "680px",
      },
    },
  },
  plugins: [],
};
export default config;
