import * as Generator from "./run_generator";
import * as AppEngine from "./templates/app/engine";
import * as AppToCopy from "./templates/app/toCopy";
import * as Options from "./options";
import * as fs from "fs";
import * as path from "path";
import * as ElmDev from "./elm_dev";

const Page = require("./templates/app/page");

export const generator = (options: any): Options.Generator => {
  return {
    name: "app",
    generatorType: Options.GeneratorType.Standard,
    init: (runOptions: Options.RunOptions) => {
      // Copy static files
      AppEngine.copyTo(runOptions.internalSrc, true);
      AppToCopy.copyTo(runOptions.src, false);
    },
    run: async (runOptions: Options.RunOptions) => {
      // Copy static files
      AppEngine.copyTo(runOptions.internalSrc, true);
      const viewRegions = await ElmDev.execute("explain App.View.Regions");

      await Generator.run(runOptions.internalSrc, {
        "app-view": viewRegions,
      });

      const pageIds = await ElmDev.execute("explain App.Page.Id.Id");

      const pages = pageIdsToPageUsages(pageIds);

      const verifiedPages = verifyElmFilesExist(
        path.join(runOptions.src, "Page"),
        pages
      );

      return await Generator.run(runOptions.internalSrc, {
        app: verifiedPages,
      });
    },
  };
};

type PageUsage = {
  id: string;
  moduleName: string[];
  value: string;
  paramType: string | null;
  elmModuleIsPresent: boolean;
};

const logError = (title: string, body: string) => {
  console.log(`\n\n${title}\n\n${body}\n\n`);
};

const verifyElmFilesExist = (dir: string, pages: PageUsage[]): PageUsage[] => {
  try {
    const elmFiles = fs
      .readdirSync(dir)
      .filter((file) => path.extname(file) === ".elm");
    const elmFileNames = elmFiles.map((file) => path.basename(file, ".elm"));

    // Check for PageUsage entries without a corresponding file
    pages.forEach((page) => {
      if (!elmFileNames.includes(page.id)) {
        logError(
          `Missing Elm Page`,
          `I found Page.Id.${page.id}, but wasn't able to find a corresponding .elm file for it in src/Page!
For now I'll make that page ID render as the Not Found page until you get a moment to add the file.`
        );
        const pageContent = Page.toBody(new Map([["{{name}}", page.id]]));

        fs.writeFileSync(path.join(dir, `${page.id}.elm`), pageContent, "utf8");
      } else {
        page.elmModuleIsPresent = true;
      }
    });

    // Check for .elm files not referenced in PageUsage
    elmFileNames.forEach((fileName) => {
      if (!pages.some((page) => page.id === fileName)) {
        logError(
          `Unused Elm Page`,
          `I found ${fileName}.elm, but there is no entry in Page.Id for it, so it's not used.  I'd recommend adding a new entry to Page.Id for it, or delete the file!`
        );
      }
    });
    return pages;
  } catch (error) {
    console.error("Error verifying Elm files:", error);
    return pages;
  }
};

const pageIdsToPageUsages = (pageIds: any): PageUsage[] => {
  // pageIds.definition.type.c
  const pages: PageUsage[] = [];
  if (!pageIds.definition.type.definition.variants) {
    console.log(
      "I wasn't able to find any variants for `App.Page.Id.Id`, is it a normal custom type?"
    );
    process.exit(1);
  }
  for (const variant of pageIds.definition.type.definition.variants) {
    pages.push({
      id: variant.name,
      moduleName: ["Page", variant.name],
      value: "page",
      paramType: variant.args.length === 0 ? null : variant.args[0],
      elmModuleIsPresent: false,
    });
  }
  return pages;
};

const placeHolderPageIds = {
  moduleName: "App.Page.Id",
  definition: {
    name: "Id",
    type: {
      signature: "Id",
      definition: {
        type: "union",
        variants: [
          {
            name: "Home",
            args: ["HomeParams"],
          },
        ],
      },
      components: [
        {
          source: {
            pkg: "author/project",
            module: "App.Page.Id",
          },
          definition: {
            type: "alias",
            comment: null,
            module: "App.Page.Id",
            name: "HomeParams",
            args: [],
            signature: "{}",
            fields: {},
          },
        },
      ],
    },
    region: {
      start: {
        line: 6,
        column: 1,
      },
      end: {
        line: 7,
        column: 22,
      },
    },
  },
};

const placeholderViewRegions = {
  moduleName: "App.View",
  definition: {
    name: "Regions",
    type: {
      signature: "{ primary : view, nav : Maybe view, detail : List view }",
      components: [
        {
          source: {
            pkg: "author/project",
            module: "App.View",
          },
          definition: {
            type: "alias",
            comment: " ",
            module: "App.View",
            name: "Regions",
            args: [],
            signature:
              "{ primary : view, nav : Maybe view, detail : List view }",
            fields: {
              detail: "List view",
              nav: "Maybe view",
              primary: "view",
            },
          },
        },
      ],
    },
    region: {
      start: {
        line: 35,
        column: 1,
      },
      end: {
        line: 39,
        column: 6,
      },
    },
  },
};

export type File = { path: string; contents: string };
