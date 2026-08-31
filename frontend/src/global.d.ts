// Ambient declarations for side-effect stylesheet imports.
// Fixes TS2882 ("Cannot find module or type declarations for side-effect
// import") that the TS server reports under `moduleResolution: "bundler"`.
declare module "*.css";
