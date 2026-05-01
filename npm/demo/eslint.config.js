import tseslint from "typescript-eslint";
import reactHooks from "eslint-plugin-react-hooks";
import localRules from "./eslint-rules/no-set-state-in-effect.js";

export default tseslint.config(
  {
    ignores: [
      "dist/**",
      "node_modules/**",
      "vite-env.d.ts",
      "vite.config.ts",
      "tsconfig*.json",
    ],
  },
  {
    files: ["src/**/*.{ts,tsx}"],
    extends: [...tseslint.configs.recommended],
    languageOptions: {
      parser: tseslint.parser,
      parserOptions: {
        ecmaVersion: "latest",
        sourceType: "module",
        ecmaFeatures: { jsx: true },
      },
    },
    plugins: {
      "react-hooks": reactHooks,
      local: localRules,
    },
    rules: {
      "local/no-set-state-in-effect": "error",
      "react-hooks/rules-of-hooks": "error",
      "react-hooks/exhaustive-deps": "error",
      "@typescript-eslint/no-floating-promises": "off",
      "@typescript-eslint/no-unused-vars": [
        "error",
        { argsIgnorePattern: "^_", varsIgnorePattern: "^_" },
      ],
    },
  },
  {
    files: ["test/**/*.{mjs,js}", "eslint-rules/**/*.js"],
    languageOptions: {
      ecmaVersion: "latest",
      sourceType: "module",
    },
    rules: {},
  }
);
