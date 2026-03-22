/** @type {import('tailwindcss').Config} */
module.exports = {
  content: ["./src/**/*.{js,ts,jsx,tsx,mdx}"],
  theme: {
    extend: {
      colors: {
        danone: {
          blue:   "#009FE3",
          dark:   "#003087",
          green:  "#00A878",
          orange: "#F5A623",
          light:  "#E8F4FD",
        },
      },
      fontFamily: {
        sans: ["'Segoe UI'", "Arial", "sans-serif"],
      },
    },
  },
  plugins: [],
}
