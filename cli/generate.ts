import * as ElmPress from ".";

import * as Tailwind from "./palettes/tailwind";

const colors = {
  neutral: Tailwind.colors.zinc,
  primary: Tailwind.colors.pink,
};

ElmPress.generate({
  src: "./examples/elm-gql/src/",
  plugins: [
    ElmPress.app({
      "Page.Home": "/old-homepage-2/*?{search}",
      "Page.Markdown": {
        dir: "./examples/elm-gql/guide",
        url: "/guides/*",
        urlOnServer: "/assets/guides/",
      },
    }),
    ElmPress.theme({
      colors: {
        white: "#ffffff",
        neutral: colors.neutral,
        primary: colors.primary,
      },
      spacing: {
        xxSmall: 2,
        xSmall: 4,
        small: 8,
        medium: 16,
        large: 32,
        xLarge: 64,
      },
      typography: {
        h1: {
          face: "EB Garamond",
          fallback: ["serif"],
          size: 24,
          color: colors.neutral["900"],
        },
        h2: {
          face: "EB Garamond",
          fallback: ["serif"],
          size: 20,
          color: colors.neutral["900"],
        },
        default: {
          face: "Noto Sans",
          fallback: ["sans-serif"],
          size: 16,
          color: colors.neutral["900"],
        },
        small: {
          face: "Noto Sans",
          fallback: ["sans-serif"],
          size: 10,
          color: colors.neutral["900"],
        },
      },
      borders: {
        small: { rounded: 2, width: 1, color: colors.neutral["900"] },
      },
      shadows: [],
    }),
    // ElmPress.figma({ apiKey: "string" }),
    // ElmPress.notion({ apiKey: "string" }),
  ],
});
