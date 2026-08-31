import type { Config } from "tailwindcss";

// Single source of Tailwind config for the app. (Previously split between a
// dead tailwind.config.ts and an active tailwind.config.js — consolidated here.)
export default {
  darkMode: ["class"],
  content: [
    "./src/pages/**/*.{js,ts,jsx,tsx,mdx}",
    "./src/components/**/*.{js,ts,jsx,tsx,mdx}",
    "./src/app/**/*.{js,ts,jsx,tsx,mdx}",
  ],
  theme: {
    extend: {
      fontFamily: {
        sans: ["var(--font-source-sans-3)"],
      },
      colors: {
        background: "var(--af-bg)",
        foreground: "var(--af-text)",
        border: "var(--af-border)",
        input: "var(--af-border)",
        ring: "var(--af-accent)",
        primary: { DEFAULT: "hsl(var(--primary))", foreground: "hsl(var(--primary-foreground))" },
        secondary: { DEFAULT: "var(--af-panel-2)", foreground: "var(--af-text)" },
        tertiary: "var(--af-text-3)",
        card: { DEFAULT: "var(--af-panel)", foreground: "var(--af-text)" },
        popover: { DEFAULT: "var(--af-panel)", foreground: "var(--af-text)" },
        muted: { DEFAULT: "var(--af-panel-2)", foreground: "var(--af-text-2)" },
        accent: { DEFAULT: "var(--af-hover)", foreground: "var(--af-text)" },
        destructive: { DEFAULT: "hsl(var(--destructive))", foreground: "hsl(var(--destructive-foreground))" },
        chart: { "1": "hsl(var(--chart-1))", "2": "hsl(var(--chart-2))", "3": "hsl(var(--chart-3))", "4": "hsl(var(--chart-4))", "5": "hsl(var(--chart-5))" },
        // semantic app tokens
        surface: "var(--af-panel)",
        "surface-2": "var(--af-panel-2)",
        "surface-hover": "var(--af-hover)",
        "surface-active": "var(--af-active)",
        content: "var(--af-text)",
        "content-muted": "var(--af-text-2)",
        "content-subtle": "var(--af-text-3)",
        "border-strong": "var(--af-border-strong)",
        brand: "var(--af-accent)",
        "brand-hover": "var(--af-accent-hover)",
        "brand-soft": "var(--af-accent-soft)",
        success: "var(--af-success)",
        "success-soft": "var(--af-success-soft)",
      },
      borderRadius: {
        lg: "var(--af-radius)",
        md: "var(--af-radius-sm)",
        sm: "var(--af-radius-sm)",
      },
      boxShadow: {
        sm: "var(--af-shadow-sm)",
        DEFAULT: "var(--af-shadow-md)",
        md: "var(--af-shadow-md)",
        lg: "var(--af-shadow-lg)",
        xl: "var(--af-shadow-lg)",
        "2xl": "var(--af-shadow-lg)",
      },
      keyframes: {
        "accordion-down": {
          from: { height: "0" },
          to: { height: "var(--radix-accordion-content-height)" },
        },
        "accordion-up": {
          from: { height: "var(--radix-accordion-content-height)" },
          to: { height: "0" },
        },
      },
      animation: {
        "accordion-down": "accordion-down 0.2s ease-out",
        "accordion-up": "accordion-up 0.2s ease-out",
      },
    },
  },
  plugins: [require("tailwindcss-animate")],
} satisfies Config;
