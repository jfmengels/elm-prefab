
import * as path from "path";
import * as fs from "fs";
import * as Options from "../../options";

export const copyTo = (baseDir: string, overwrite: boolean, skip: boolean, summary: Options.Summary) => { 
  
  if (overwrite || (!fs.existsSync(path.join(baseDir, "/elm.json")) && !skip)) {
    const filepath = path.join(baseDir, "/elm.json");
    fs.mkdirSync(path.dirname(filepath), { recursive: true });
    fs.writeFileSync(filepath, "{\n  \"type\": \"application\",\n  \"source-directories\": [\"src\", \".elm-prefab\"],\n  \"elm-version\": \"0.19.1\",\n  \"dependencies\": {\n    \"direct\": {\n      \"dillonkearns/elm-markdown\": \"7.0.1\",\n      \"elm/browser\": \"1.0.2\",\n      \"elm/bytes\": \"1.0.8\",\n      \"elm/core\": \"1.0.5\",\n      \"elm/file\": \"1.0.5\",\n      \"elm/html\": \"1.0.0\",\n      \"elm/http\": \"2.0.0\",\n      \"elm/json\": \"1.1.3\",\n      \"elm/random\": \"1.0.0\",\n      \"elm/time\": \"1.0.0\",\n      \"elm/url\": \"1.0.0\",\n      \"lydell/elm-app-url\": \"1.0.3\"\n    },\n    \"indirect\": {\n      \"elm/parser\": \"1.1.0\",\n      \"elm/regex\": \"1.0.0\",\n      \"elm/virtual-dom\": \"1.0.3\",\n      \"rtfeldman/elm-hex\": \"1.0.0\"\n    }\n  },\n  \"test-dependencies\": {\n    \"direct\": {},\n    \"indirect\": {}\n  }\n}\n");
    const generated = { outputDir: baseDir, path: filepath}
    Options.addGenerated(summary, generated);
  }

  if (overwrite || (!fs.existsSync(path.join(baseDir, "/package.json")) && !skip)) {
    const filepath = path.join(baseDir, "/package.json");
    fs.mkdirSync(path.dirname(filepath), { recursive: true });
    fs.writeFileSync(filepath, "{\n  \"devDependencies\": {\n    \"vite\": \"^5.2.6\",\n    \"vite-plugin-elm\": \"^3.0.0\",\n    \"typescript\": \"^5.4.3\",\n    \"@tiptap/core\": \"^2.2.4\",\n    \"@tiptap/extension-link\": \"^2.2.4\",\n    \"@tiptap/pm\": \"^2.2.4\",\n    \"@tiptap/starter-kit\": \"^2.2.4\"\n  },\n  \"name\": \"placeholder\",\n  \"type\": \"module\",\n  \"description\": \"\",\n  \"version\": \"0.1.0\",\n  \"scripts\": {\n    \"dev\": \"vite\",\n    \"build\": \"tsc && vite build\"\n  }\n}\n");
    const generated = { outputDir: baseDir, path: filepath}
    Options.addGenerated(summary, generated);
  }

  if (overwrite || (!fs.existsSync(path.join(baseDir, "/tsconfig.json")) && !skip)) {
    const filepath = path.join(baseDir, "/tsconfig.json");
    fs.mkdirSync(path.dirname(filepath), { recursive: true });
    fs.writeFileSync(filepath, "{\n  \"compilerOptions\": {\n    \"target\": \"ES2020\",\n    \"useDefineForClassFields\": true,\n    \"module\": \"CommonJS\",\n    \"lib\": [\"ES2020\", \"DOM\", \"DOM.Iterable\"],\n    \"skipLibCheck\": true,\n\n    \"allowImportingTsExtensions\": true,\n    \"resolveJsonModule\": true,\n    \"isolatedModules\": true,\n    \"noEmit\": true,\n\n    /* Linting */\n    \"strict\": true,\n    \"noUnusedLocals\": true,\n    \"noFallthroughCasesInSwitch\": true\n  },\n\n  \"include\": [\"src-js\"]\n}\n");
    const generated = { outputDir: baseDir, path: filepath}
    Options.addGenerated(summary, generated);
  }

  if (overwrite || (!fs.existsSync(path.join(baseDir, "/vite.config.js")) && !skip)) {
    const filepath = path.join(baseDir, "/vite.config.js");
    fs.mkdirSync(path.dirname(filepath), { recursive: true });
    fs.writeFileSync(filepath, "import { defineConfig } from \"vite\";\nimport elmPlugin from \"vite-plugin-elm\";\n\nexport default defineConfig(({ mode }) => {\n  const isDev = mode == \"development\";\n  return {\n    clearScreen: false,\n    server: {\n      strictPort: true,\n    },\n\n    build: {\n      minify: \"esbuild\",\n      outDir: \"../dist\",\n    },\n    root: \"./src-js/\",\n    plugins: [\n      elmPlugin({\n        debug: isDev,\n        optimize: !isDev,\n      }),\n    ],\n  };\n});\n");
    const generated = { outputDir: baseDir, path: filepath}
    Options.addGenerated(summary, generated);
  }
}
