const defaultTheme = require("tailwindcss/defaultTheme");
const colors = require('tailwindcss/colors');
fs = require('fs');

const classes = JSON.parse(fs.readFileSync("./hugo_stats.json"))["htmlElements"]["classes"]
module.exports = {
   content: {
    files: [
      './themes/simple/layouts/**/*.html',
      './content/**/*.md',
      './public/**/*.html',
      './themes/simple/assets/**/*.js',
      './hugo_stats.json'
    ],
  },
  safeList: classes.concat([{ pattern: /hover:bg-\[.*\]/}]),
  plugins: [
    require('@tailwindcss/typography'),
    require('@tailwindcss/line-clamp'),
    require('@tailwindcss/aspect-ratio'),
  ],
  variants: {
    extend: {
      typography: ["dark"],
    }
  },
  theme: {
    extend: {
      fontFamily: {
        mono: [
          "-ui-monospace",
          "SFMono-Regular",
          "ui-monospace",
          "Monaco",
          "Andale Mono",
          "Ubuntu Mono",
          "monospace"
        ],
        sans: [
          "-apple-system",
          "BlinkMacSystemFont",
          "Helvetica Neue",
          "Helvetica",
          "Arial",
          "sans-serif"
        ],
        serif: [
          "-apple-system-ui-serif",
          "Iowan Old Style",
          "Apple Garamond",
          "Baskerville",
          "Times New Roman",
          "Droid Serif",
          "Times",
          "Source Serif Pro",
          "serif",
          "Apple Color Emoji",
          "Segoe UI Emoji",
          "Segoe UI Symbol"
        ]
      },
      colors: {
        gray: colors.stone,
        indigo: colors.indigo,
        teal: colors.teal,
        orange: colors.orange,
        amber: colors.amber,
        slate: colors.slate,
        rose: colors.rose,
        red: colors.red,
        emerald: colors.emerald,
        sky: colors.sky,
        dark: "#2d2f34",
        darker: "#1F2023"
      },
      typography: (theme) => ({
        light: {
          css: [
            {
              color: theme('colors.gray.100'),
              '[class~="lead"]': {
                color: theme('colors.gray.300'),
              },
              strong: {
                color: theme('colors.white'),
              },
              'ol > li::before': {
                color: theme('colors.gray.400'),
              },
              'ul > li::before': {
                backgroundColor: theme('colors.gray.600'),
              },
              hr: {
                borderColor: theme('colors.gray.200'),
              },
              blockquote: {
                color: theme('colors.gray.200'),
                borderLeftColor: theme('colors.gray.600'),
              },
              h1: {
                color: theme('colors.white'),
              },
              h2: {
                color: theme('colors.white'),
              },
              h3: {
                color: theme('colors.white'),
              },
              h4: {
                color: theme('colors.white'),
              },
              'figure figcaption': {
                color: theme('colors.gray.400'),
              },
              code: {
                color: theme('colors.white'),
              },
              'a code': {
                color: theme('colors.white'),
              },
              pre: {
                color: theme('colors.gray.200'),
                backgroundColor: theme('colors.gray.800'),
              },
              thead: {
                color: theme('colors.white'),
                borderBottomColor: theme('colors.gray.400'),
              },
              'tbody tr': {
                borderBottomColor: theme('colors.gray.600'),
              },
            },
          ],
        },
        DEFAULT: {
          css: {
            img: {
              marginTop: 0,
              marginBottom: 0
            }
          }
        }
      }),
    }
  }
}
