#!/usr/bin/env node
import fs from "node:fs";
import path from "node:path";
import process from "node:process";
import { fileURLToPath } from "node:url";
import dotenv from "dotenv";
import type sharpDefault from "sharp";

const __filename = fileURLToPath(import.meta.url);
const toolDir = path.dirname(__filename);
const repoRoot = path.resolve(toolDir, "../..");

dotenv.config({ path: path.join(repoRoot, ".env"), override: false });
dotenv.config({ path: path.join(toolDir, ".env"), override: false });

const DEFAULT_TARGET_SIZE = "1320x2868";
const DEFAULT_AI_BACKGROUND_SIZE = "1024x1536";
const ABSOLUTE_MAX_IMAGES = 6;
const ABSOLUTE_MAX_VARIANTS_PER_SCREEN = 2;
const DEFAULT_RETRIES_PER_IMAGE = 1;

const TARGET_SIZES: Record<string, TargetSize> = {
  "1320x2868": { width: 1320, height: 2868, label: "iPhone 6.9-inch portrait" },
  "1290x2796": { width: 1290, height: 2796, label: "iPhone 6.9-inch portrait alternate" },
  "1260x2736": { width: 1260, height: 2736, label: "iPhone 6.7-inch portrait" },
};

const IMAGE_EXTENSIONS = new Set([".png", ".jpg", ".jpeg", ".webp"]);

type TargetSize = {
  width: number;
  height: number;
  label: string;
};

type CliOptions = {
  dryRun: boolean;
  generate: boolean;
  model: string;
  quality: string;
  maxImages: number;
  maxVariantsPerScreen: number;
  targetSizeKey: string;
  targetSize: TargetSize;
  inputScreenshots: string;
  outputDir: string;
  brandFile: string;
  brandFileWasExplicit: boolean;
  seed?: number;
  force: boolean;
};

type BrandConfig = {
  appName?: string;
  primaryColor?: string;
  secondaryColor?: string;
  accentColor?: string;
  fontFamily?: string;
  category?: string;
  tone?: string;
};

type BrandColors = {
  primaryColor: string;
  secondaryColor: string;
  accentColor: string;
  backgroundColor: string;
  detected: Array<{ name: string; value: string; source: string }>;
};

type DetectedFeature = {
  title: string;
  description: string;
  source: string;
};

type RepoInsights = {
  appName: string;
  appNameSource: string;
  category: string;
  brandColors: BrandColors;
  typographyHints: string[];
  designLanguage: string[];
  features: DetectedFeature[];
  screenshots: string[];
  screenshotSearchPaths: string[];
  brandConfigPath?: string;
};

type ScreenPlan = {
  index: number;
  slug: string;
  kind: "hero" | "feature";
  title: string;
  feature: string;
  headline: string;
  subheadline: string;
  mood: string;
  prompt: string;
  screenshotPath: string | null;
  screenshotSource: string;
  targetSize: TargetSize;
  outputBackgroundPath: string;
  outputFinalPath: string;
  draftOnly: boolean;
};

type Manifest = {
  timestamp: string;
  appName: string;
  appNameSource: string;
  repoRoot: string;
  detectedFeatures: DetectedFeature[];
  detectedBrandColors: BrandColors;
  typographyHints: string[];
  designLanguage: string[];
  selectedScreenshotSources: Array<{ screen: string; path: string | null; source: string }>;
  generatedPrompts: Array<{ screen: string; prompt: string }>;
  model: string;
  quality: string;
  aiGeneration: {
    dryRun: boolean;
    paid: boolean;
    plannedImageGenerations: number;
    aiBackgroundSize: string;
    aiBackgroundAspectRatio: string;
    maxImages: number;
    maxVariantsPerScreen: number;
    retriesPerImage: number;
    seed?: number;
  };
  outputDimensions: TargetSize;
  supportedTargetSizes: string[];
  draftOnly: boolean;
  assumptions: string[];
  filesCreated: string[];
};

function parseArgs(argv: string[]): CliOptions {
  const defaults = {
    model: "openai/gpt-image-2",
    quality: "medium",
    maxImages: 3,
    maxVariantsPerScreen: 1,
    targetSizeKey: DEFAULT_TARGET_SIZE,
    inputScreenshots: "app-store-input/screenshots",
    outputDir: "app-store-output",
    brandFile: "app-store-input/brand.json",
  };

  let dryRunFlag = false;
  let generateFlag = false;
  let model = defaults.model;
  let quality = defaults.quality;
  let maxImages = defaults.maxImages;
  let maxVariantsPerScreen = defaults.maxVariantsPerScreen;
  let targetSizeKey = defaults.targetSizeKey;
  let inputScreenshots = defaults.inputScreenshots;
  let outputDir = defaults.outputDir;
  let brandFile = defaults.brandFile;
  let brandFileWasExplicit = false;
  let seed: number | undefined;
  let force = false;

  const args = argv.slice(2);

  for (let i = 0; i < args.length; i += 1) {
    const token = args[i];
    const [flag, inlineValue] = token.includes("=") ? token.split(/=(.*)/s, 2) : [token, undefined];
    const readValue = () => {
      if (inlineValue !== undefined) return inlineValue;
      i += 1;
      if (i >= args.length || args[i].startsWith("--")) {
        throw new Error(`Missing value for ${flag}`);
      }
      return args[i];
    };

    switch (flag) {
      case "--help":
      case "-h":
        printHelpAndExit();
        break;
      case "--dry-run":
        dryRunFlag = true;
        break;
      case "--generate":
        generateFlag = true;
        break;
      case "--model":
        model = readValue();
        break;
      case "--quality":
        quality = readValue();
        break;
      case "--max-images":
        maxImages = parsePositiveInteger(readValue(), "--max-images");
        break;
      case "--max-variants-per-screen":
        maxVariantsPerScreen = parsePositiveInteger(readValue(), "--max-variants-per-screen");
        break;
      case "--target-size":
        targetSizeKey = readValue();
        break;
      case "--input-screenshots":
        inputScreenshots = readValue();
        break;
      case "--output-dir":
        outputDir = readValue();
        break;
      case "--brand-file":
        brandFile = readValue();
        brandFileWasExplicit = true;
        break;
      case "--seed":
        seed = parsePositiveInteger(readValue(), "--seed");
        break;
      case "--force":
        force = true;
        break;
      default:
        throw new Error(`Unknown flag: ${token}. Run with --help for usage.`);
    }
  }

  if (dryRunFlag && generateFlag) {
    throw new Error("Use either --dry-run or --generate, not both.");
  }

  if (maxImages > ABSOLUTE_MAX_IMAGES) {
    throw new Error(`--max-images may not exceed ${ABSOLUTE_MAX_IMAGES} in this first draft.`);
  }

  if (maxVariantsPerScreen > ABSOLUTE_MAX_VARIANTS_PER_SCREEN) {
    throw new Error(
      `--max-variants-per-screen may not exceed ${ABSOLUTE_MAX_VARIANTS_PER_SCREEN} in this first draft.`,
    );
  }

  const targetSize = TARGET_SIZES[targetSizeKey];
  if (!targetSize) {
    throw new Error(
      `Unsupported --target-size "${targetSizeKey}". Supported sizes: ${Object.keys(TARGET_SIZES).join(", ")}`,
    );
  }

  const dryRun = !generateFlag || dryRunFlag;

  return {
    dryRun,
    generate: generateFlag,
    model,
    quality,
    maxImages,
    maxVariantsPerScreen,
    targetSizeKey,
    targetSize,
    inputScreenshots: resolveRepoPath(inputScreenshots),
    outputDir: resolveRepoPath(outputDir),
    brandFile: resolveRepoPath(brandFile),
    brandFileWasExplicit,
    seed,
    force,
  };
}

function parsePositiveInteger(value: string, flag: string): number {
  const parsed = Number(value);
  if (!Number.isInteger(parsed) || parsed < 1) {
    throw new Error(`${flag} must be a positive integer.`);
  }
  return parsed;
}

function resolveRepoPath(value: string): string {
  return path.isAbsolute(value) ? value : path.resolve(repoRoot, value);
}

function printHelpAndExit(): never {
  console.log(`Repo-aware App Store draft image generator\n\nUsage:\n  npm --prefix scripts/app-store-images run plan\n  npm --prefix scripts/app-store-images run generate -- --max-images 3\n  npm --prefix scripts/app-store-images exec -- tsx scripts/app-store-images/generate.ts --dry-run\n\nFlags:\n  --dry-run                         Plan only; no paid AI calls. Default.\n  --generate                        Enable AI background generation and final PNG compositing.\n  --model <id>                      AI Gateway model. Default: openai/gpt-image-2\n  --quality <quality>               Provider image quality. Default: medium\n  --max-images <n>                  Hard cap. Default: 3, absolute max: ${ABSOLUTE_MAX_IMAGES}\n  --max-variants-per-screen <n>     Safety cap. Default: 1, absolute max: ${ABSOLUTE_MAX_VARIANTS_PER_SCREEN}\n  --target-size <WxH>               ${Object.keys(TARGET_SIZES).join(" | ")}\n  --input-screenshots <dir>         Default: app-store-input/screenshots\n  --output-dir <dir>                Default: app-store-output\n  --brand-file <file>               Default: app-store-input/brand.json\n  --seed <number>                   Passed to the provider if supported.\n  --force                           Overwrite existing background/final PNG files.\n`);
  process.exit(0);
}

async function main() {
  const options = parseArgs(process.argv);

  ensureDirectory(options.inputScreenshots);
  ensureDirectory(path.resolve(repoRoot, "app-store-input/reference"));
  ensureDirectory(options.outputDir);
  ensureDirectory(path.join(options.outputDir, "backgrounds"));
  ensureDirectory(path.join(options.outputDir, "final"));
  ensureBrandExample();

  const brandConfig = loadBrandConfig(options.brandFile, options.brandFileWasExplicit);
  const insights = inspectRepo(brandConfig, options);
  const plan = buildScreenshotPlan(insights, options);
  const plannedImageGenerations = plan.length;

  printPlan(insights, plan, options, plannedImageGenerations);
  validateCostControls(plan, options, plannedImageGenerations);

  const manifest = buildManifest(insights, plan, options, plannedImageGenerations, []);

  if (options.dryRun) {
    const manifestPath = writeManifest(options.outputDir, manifest);
    console.log(`\nDry run complete. No AI calls were made.`);
    console.log(`Manifest written to ${relativePath(manifestPath)}`);
    return;
  }

  if (!process.env.AI_GATEWAY_API_KEY) {
    throw new Error(
      "--generate was requested, but AI_GATEWAY_API_KEY is missing. Add it to .env or export it in your shell before running generation.",
    );
  }

  preflightOutputFiles(plan, options.force);

  const filesCreated: string[] = [];
  for (const screen of plan) {
    console.log(`\nGenerating background ${screen.index}/${plan.length}: ${screen.title}`);
    const backgroundBuffer = await generateBackground(screen.prompt, options);
    fs.writeFileSync(screen.outputBackgroundPath, backgroundBuffer);
    filesCreated.push(relativePath(screen.outputBackgroundPath));

    console.log(`Compositing final PNG: ${relativePath(screen.outputFinalPath)}`);
    await compositeFinalImage(screen, insights, options);
    filesCreated.push(relativePath(screen.outputFinalPath));
  }

  const finalManifest = buildManifest(insights, plan, options, plannedImageGenerations, filesCreated);
  const manifestPath = writeManifest(options.outputDir, finalManifest);
  console.log(`\nGeneration complete. Manifest written to ${relativePath(manifestPath)}`);
}

function loadBrandConfig(brandFile: string, explicit: boolean): BrandConfig {
  if (!fs.existsSync(brandFile)) {
    if (explicit) {
      throw new Error(`Brand file not found: ${brandFile}`);
    }
    return {};
  }

  try {
    return JSON.parse(fs.readFileSync(brandFile, "utf8")) as BrandConfig;
  } catch (error) {
    throw new Error(`Could not parse brand file ${brandFile}: ${error instanceof Error ? error.message : String(error)}`);
  }
}

function inspectRepo(brandConfig: BrandConfig, options: CliOptions): RepoInsights {
  const appNameInfo = detectAppName(brandConfig);
  const brandColors = detectBrandColors(brandConfig);
  const typographyHints = detectTypographyHints(brandConfig);
  const designLanguage = detectDesignLanguage();
  const features = detectFeatures();
  const screenshotsInfo = discoverScreenshots(options.inputScreenshots);

  return {
    appName: appNameInfo.name,
    appNameSource: appNameInfo.source,
    category: brandConfig.category ?? inferCategory(features),
    brandColors,
    typographyHints,
    designLanguage,
    features,
    screenshots: screenshotsInfo.files,
    screenshotSearchPaths: screenshotsInfo.searchPaths,
    brandConfigPath: fs.existsSync(options.brandFile) ? relativePath(options.brandFile) : undefined,
  };
}

function detectAppName(brandConfig: BrandConfig): { name: string; source: string } {
  if (brandConfig.appName) {
    return { name: brandConfig.appName, source: "app-store-input/brand.json" };
  }

  for (const plistPath of discoverInfoPlists()) {
    const infoPlist = readTextIfExists(plistPath);
    if (!infoPlist) continue;
    const plistName = plistStringValue(infoPlist, "CFBundleDisplayName") ?? plistStringValue(infoPlist, "CFBundleName");
    if (plistName && !plistName.includes("$(")) {
      return { name: plistName, source: relativePath(plistPath) };
    }
  }

  const projectYmlPath = path.join(repoRoot, "project.yml");
  const projectYml = readTextIfExists(projectYmlPath);
  if (projectYml) {
    const iosProductName = productNameFromXcodeGen(projectYml);
    if (iosProductName) {
      return { name: iosProductName, source: "project.yml iOS PRODUCT_NAME" };
    }

    const rootNameMatch = projectYml.match(/^name:\s*"?([^"\n]+)"?/m);
    if (rootNameMatch?.[1]?.trim()) {
      return { name: rootNameMatch[1].trim(), source: "project.yml name" };
    }
  }

  const pbxproj = discoverFilesByName("project.pbxproj", 5)[0];
  const pbxprojText = pbxproj ? readTextIfExists(pbxproj) : undefined;
  const pbxProductName = pbxprojText?.match(/PRODUCT_NAME\s*=\s*"?([^";\n]+)"?;/)?.[1]?.trim();
  if (pbxProductName && !pbxProductName.includes("$(")) {
    return { name: pbxProductName, source: relativePath(pbxproj) };
  }

  const packageJson = readJsonIfExists<{ name?: string; productName?: string }>(path.join(repoRoot, "package.json"));
  const packageName = packageJson?.productName ?? packageJson?.name;
  if (packageName) {
    return { name: humanizePackageName(packageName), source: "package.json" };
  }

  const readme = readTextIfExists(path.join(repoRoot, "README.md"));
  const readmeTitle = readme?.match(/^#\s+(.+)$/m)?.[1]?.trim();
  if (readmeTitle) {
    return { name: readmeTitle, source: "README.md title" };
  }

  return { name: humanizePackageName(path.basename(repoRoot)), source: "repository folder name" };
}

function discoverInfoPlists(): string[] {
  const files = discoverFilesByName("Info.plist", 6);
  return files.sort((a, b) => plistPriority(a) - plistPriority(b));
}

function plistPriority(filePath: string): number {
  const lower = relativePath(filePath).toLowerCase();
  if (lower.includes("/ios/") || lower.includes("iphone")) return 0;
  if (lower.includes("app")) return 1;
  return 2;
}

function productNameFromXcodeGen(projectYml: string): string | undefined {
  const lines = projectYml.split(/\r?\n/);
  let inTargets = false;
  let insideTarget = false;
  let currentIsIos = false;
  let currentProductName: string | undefined;

  const finishTarget = () => {
    const productName = currentIsIos ? currentProductName : undefined;
    insideTarget = false;
    currentIsIos = false;
    currentProductName = undefined;
    return productName;
  };

  for (const line of lines) {
    if (/^targets:\s*$/.test(line)) {
      inTargets = true;
      continue;
    }

    if (inTargets && /^[A-Za-z0-9_]+:\s*$/.test(line)) {
      const productName = finishTarget();
      if (productName) return productName;
      inTargets = false;
    }

    if (!inTargets) continue;

    if (/^  [^:\n]+:\s*$/.test(line)) {
      const productName = insideTarget ? finishTarget() : undefined;
      if (productName) return productName;
      insideTarget = true;
      continue;
    }

    if (!insideTarget) continue;

    if (/^\s*platform:\s*iOS\b/i.test(line)) {
      currentIsIos = true;
    }

    const productName = line.match(/^\s*PRODUCT_NAME:\s*"?([^"\n]+)"?/m)?.[1]?.trim();
    if (productName) {
      currentProductName = productName;
    }
  }

  return finishTarget();
}

function humanizePackageName(name: string): string {
  return name
    .replace(/^@[^/]+\//, "")
    .replace(/[-_]+/g, " ")
    .replace(/\b\w/g, (letter) => letter.toUpperCase())
    .trim();
}

function plistStringValue(plist: string, key: string): string | undefined {
  const escapedKey = key.replace(/[.*+?^${}()|[\]\\]/g, "\\$&");
  const match = plist.match(new RegExp(`<key>${escapedKey}</key>\\s*<string>([^<]+)</string>`));
  return match?.[1]?.trim();
}

function detectBrandColors(brandConfig: BrandConfig): BrandColors {
  const detected: BrandColors["detected"] = [];

  const css = readTextIfExists(path.join(repoRoot, "Website/styles.css"));
  if (css) {
    const cssVariableRegex = /--([a-zA-Z0-9-]+):\s*(#[0-9a-fA-F]{3,8})\b/g;
    for (const match of css.matchAll(cssVariableRegex)) {
      detected.push({ name: match[1], value: normalizeHex(match[2]), source: "Website/styles.css" });
    }
  }

  const geist = readTextIfExists(path.join(repoRoot, "Sources/Shared/GeistDesign.swift"));
  if (geist) {
    const tokenRegex = /\.([a-zA-Z0-9]+):\s*"(#[0-9a-fA-F]{6,8})"/g;
    const seen = new Set(detected.map((color) => `${color.name}:${color.value}`));
    for (const match of geist.matchAll(tokenRegex)) {
      const entry = { name: `geist.${match[1]}`, value: normalizeHex(match[2]), source: "Sources/Shared/GeistDesign.swift" };
      const key = `${entry.name}:${entry.value}`;
      if (!seen.has(key)) {
        detected.push(entry);
        seen.add(key);
      }
    }
  }

  const find = (name: string) => detected.find((color) => color.name === name)?.value;
  const findPrefix = (prefix: string) => detected.find((color) => color.name.startsWith(prefix))?.value;

  return {
    primaryColor: brandConfig.primaryColor ?? find("ink") ?? find("geist.primary") ?? "#111111",
    secondaryColor: brandConfig.secondaryColor ?? find("paper") ?? find("geist.background100") ?? "#ffffff",
    accentColor: brandConfig.accentColor ?? find("orange") ?? find("geist.blue700") ?? "#4F46E5",
    backgroundColor: find("paper") ?? brandConfig.secondaryColor ?? findPrefix("geist.background") ?? "#ffffff",
    detected,
  };
}

function normalizeHex(value: string): string {
  if (value.length === 4) {
    return `#${value[1]}${value[1]}${value[2]}${value[2]}${value[3]}${value[3]}`.toUpperCase();
  }
  return value.toUpperCase();
}

function detectTypographyHints(brandConfig: BrandConfig): string[] {
  const hints = new Set<string>();
  if (brandConfig.fontFamily) hints.add(`brand.json fontFamily: ${brandConfig.fontFamily}`);

  const geist = readTextIfExists(path.join(repoRoot, "Sources/Shared/GeistDesign.swift"));
  if (geist?.includes("Geist Sans")) hints.add("SwiftUI uses Geist Sans and Geist Mono tokens");

  const css = readTextIfExists(path.join(repoRoot, "Website/styles.css"));
  if (css?.includes("SF Pro Display")) hints.add("Website headlines use SF Pro Display / system sans");
  if (css?.includes("ui-monospace")) hints.add("Website body copy uses system monospace for a retro utility feel");

  if (hints.size === 0) hints.add("system font stack");
  return Array.from(hints);
}

function detectDesignLanguage(): string[] {
  const language = new Set<string>();
  const geist = readTextIfExists(path.join(repoRoot, "Sources/Shared/GeistDesign.swift"));
  if (geist) language.add("Vercel Geist-inspired SwiftUI tokens, neutral panels, rounded controls, and precise spacing");

  const css = readTextIfExists(path.join(repoRoot, "Website/styles.css"));
  const index = readTextIfExists(path.join(repoRoot, "Website/index.html"));
  if (css?.includes("--orange") || index?.includes("pixel-art")) {
    language.add("paper-and-ink marketing site with orange accents, pixel/retro controller cues, and grid texture");
  }
  if (index?.includes("controller-diagram")) {
    language.add("visual language includes simple phone/controller diagrams and tactile shortcut labels");
  }

  return Array.from(language);
}

function detectFeatures(): DetectedFeature[] {
  const features: DetectedFeature[] = [];
  const seen = new Set<string>();
  const add = (title: string, description: string, source: string) => {
    const cleanTitle = stripHtml(title).trim();
    const cleanDescription = stripHtml(description).replace(/\s+/g, " ").trim();
    const key = cleanTitle.toLowerCase();
    if (!cleanTitle || seen.has(key)) return;
    seen.add(key);
    features.push({ title: cleanTitle, description: cleanDescription, source });
  };

  const readme = readTextIfExists(path.join(repoRoot, "README.md"));
  if (readme) {
    const firstParagraph = readme
      .split(/\n\s*\n/)
      .find((block) => block.trim() && !block.trim().startsWith("#"));
    if (firstParagraph) add("Programmable shortcut keypad", firstParagraph, "README.md");

    if (/Smart Connect/i.test(readme)) {
      add("Smart Connect", "Remembers a trusted Mac, discovers it over Bonjour, and reconnects automatically.", "README.md");
    }
    if (/QR code/i.test(readme)) {
      add("QR pairing", "Scan the Mac helper QR code or enter a secure pairing code.", "README.md");
    }
    if (/joystick/i.test(readme)) {
      add("Custom layouts", "Build keypad setups with buttons, joysticks, device frames, and per-control shortcuts.", "README.md");
    }
    if (/UDP/i.test(readme) && /WebSocket/i.test(readme)) {
      add("Realtime transport", "Authenticated UDP carries compact input frames with WebSocket mirroring as fallback.", "README.md");
    }
    if (/CLI/i.test(readme)) {
      add("CLI included", "Generate, import, export, select, and test profiles from the terminal.", "README.md");
    }
  }

  const website = readTextIfExists(path.join(repoRoot, "Website/index.html"));
  if (website) {
    const articleRegex = /<article>[\s\S]*?<h3>([\s\S]*?)<\/h3>[\s\S]*?<p>([\s\S]*?)<\/p>[\s\S]*?<\/article>/g;
    for (const match of website.matchAll(articleRegex)) {
      add(match[1], match[2], "Website/index.html");
    }
  }

  return features.slice(0, 12);
}

function inferCategory(features: DetectedFeature[]): string {
  const allText = features.map((feature) => `${feature.title} ${feature.description}`).join(" ").toLowerCase();
  if (allText.includes("game") || allText.includes("controller")) {
    return "Mac game controller and programmable shortcut keypad";
  }
  if (allText.includes("shortcut") || allText.includes("workflow")) {
    return "productivity shortcut keypad";
  }
  return "iOS companion utility";
}

function discoverScreenshots(inputScreenshots: string): { files: string[]; searchPaths: string[] } {
  const candidatePaths = [
    inputScreenshots,
    path.join(repoRoot, "screenshots"),
    path.join(repoRoot, "Screenshots"),
    path.join(repoRoot, "screenshot"),
    path.join(repoRoot, "Screenshot"),
    path.join(repoRoot, "fastlane/screenshots"),
    path.join(repoRoot, "fastlane/metadata"),
    path.join(repoRoot, "metadata"),
    path.join(repoRoot, "app-store"),
    path.join(repoRoot, "marketing"),
    path.join(repoRoot, "docs"),
    path.join(repoRoot, ".github"),
  ];

  const uniquePaths = Array.from(new Set(candidatePaths.map((candidate) => path.resolve(candidate))));
  const files: string[] = [];
  const seenRealPaths = new Set<string>();

  for (const candidate of uniquePaths) {
    if (!fs.existsSync(candidate)) continue;
    for (const file of walkFiles(candidate, 4)) {
      if (!IMAGE_EXTENSIONS.has(path.extname(file).toLowerCase())) continue;
      if (isLikelyNonScreenshot(file)) continue;
      const realPath = safeRealPath(file);
      if (seenRealPaths.has(realPath)) continue;
      seenRealPaths.add(realPath);
      files.push(realPath);
    }
  }

  return {
    files: files.sort(),
    searchPaths: uniquePaths.map(relativePath),
  };
}

function safeRealPath(file: string): string {
  try {
    return fs.realpathSync.native(file);
  } catch {
    return file;
  }
}

function isLikelyNonScreenshot(file: string): boolean {
  const lower = relativePath(file).toLowerCase();
  const basename = path.basename(lower);
  if (lower.includes("app-icons-")) return true;
  if (basename.includes("appicon") || basename.includes("app-icon") || basename.includes("favicon")) return true;
  if (/^icon[_-]?\d/.test(basename)) return true;
  return false;
}

function walkFiles(root: string, maxDepth: number): string[] {
  const results: string[] = [];
  const visit = (current: string, depth: number) => {
    if (depth > maxDepth) return;
    const entries = fs.readdirSync(current, { withFileTypes: true });
    for (const entry of entries) {
      const fullPath = path.join(current, entry.name);
      if (entry.isDirectory()) {
        if ([".git", "build", "node_modules", "app-store-output"].includes(entry.name)) continue;
        visit(fullPath, depth + 1);
      } else if (entry.isFile()) {
        results.push(fullPath);
      }
    }
  };

  visit(root, 0);
  return results;
}

function buildScreenshotPlan(insights: RepoInsights, options: CliOptions): ScreenPlan[] {
  const screens = [
    {
      kind: "hero" as const,
      title: "Hero / core value proposition",
      feature: "Programmable shortcut keypad",
      headline: `Turn iPhone into a Mac shortcut pad`,
      subheadline: "Pair with your Mac and send custom controls from your phone.",
      mood: "premium, tactile, focused, modern",
    },
    {
      kind: "feature" as const,
      title: "Key feature 1 / Smart Connect pairing",
      feature: "Smart Connect and QR pairing",
      headline: "Pair once. Reconnect fast.",
      subheadline: "Scan the Mac QR code, then let Smart Connect find your helper.",
      mood: "calm setup flow, secure local connection, clear depth",
    },
    {
      kind: "feature" as const,
      title: "Key feature 2 / Custom layouts",
      feature: "Custom keypad profiles",
      headline: "Build controls for any workflow.",
      subheadline: "Buttons, joysticks, haptics, profiles, and shortcut sequences.",
      mood: "creative control surface, energetic but clean, tactile",
    },
  ];

  return screens.map((screen, index) => {
    const screenshotPath = insights.screenshots.length > 0 ? insights.screenshots[index % insights.screenshots.length] : null;
    const slug = slugify(`${index + 1}-${screen.title}`);
    const prompt = buildBackgroundPrompt(screen, insights);
    return {
      ...screen,
      index: index + 1,
      slug,
      prompt,
      screenshotPath,
      screenshotSource: screenshotPath ? relativePath(screenshotPath) : "placeholder: app-store-input/screenshots is empty",
      targetSize: options.targetSize,
      outputBackgroundPath: path.join(options.outputDir, "backgrounds", `${slug}-${options.targetSizeKey}-background.png`),
      outputFinalPath: path.join(options.outputDir, "final", `${slug}-${options.targetSizeKey}.png`),
      draftOnly: screenshotPath === null,
    };
  });
}

function buildBackgroundPrompt(
  screen: Pick<ScreenPlan, "feature" | "mood">,
  insights: RepoInsights,
): string {
  const colors = [
    insights.brandColors.primaryColor,
    insights.brandColors.secondaryColor,
    insights.brandColors.accentColor,
  ].join(", ");
  const design = insights.designLanguage.length > 0 ? insights.designLanguage.join("; ") : "clean modern iOS utility design";
  const tone = insights.brandConfigPath ? "match the provided brand settings" : "repo-aware first draft";

  return [
    `Abstract premium iOS App Store marketing background for a ${insights.category} app called ${insights.appName}.`,
    `Feature focus: ${screen.feature}.`,
    `Use brand colors ${colors}.`,
    `Visual direction: ${design}.`,
    `Mood: ${screen.mood}; ${tone}; soft depth; subtle gradients; clean modern composition; tasteful geometric/decorative elements.`,
    "Leave clear space for a phone mockup and headline.",
    "No text, no letters, no numbers, no logos, no app UI, no phone UI, no screens.",
    "High quality, portrait mobile marketing background.",
  ].join(" ");
}

function printPlan(
  insights: RepoInsights,
  plan: ScreenPlan[],
  options: CliOptions,
  plannedImageGenerations: number,
): void {
  console.log("PocketPad App Store image plan");
  console.log("================================");
  console.log(`Mode: ${options.dryRun ? "dry-run (no paid AI calls)" : "generate (paid AI calls enabled)"}`);
  console.log(`App: ${insights.appName} (${insights.appNameSource})`);
  console.log(`Category: ${insights.category}`);
  console.log(
    `Brand colors: primary ${insights.brandColors.primaryColor}, secondary ${insights.brandColors.secondaryColor}, accent ${insights.brandColors.accentColor}`,
  );
  console.log(`Screenshots found: ${insights.screenshots.length}`);
  if (insights.screenshots.length === 0) {
    console.log("No real app screenshots found. Final generated images will be marked draft-only with placeholders.");
  }
  console.log(`Planned image generations: ${plannedImageGenerations}`);
  console.log(`Model: ${options.model}`);
  console.log(`Quality: ${options.quality}`);
  console.log(`AI background size: ${DEFAULT_AI_BACKGROUND_SIZE}`);
  console.log(`Output target: ${options.targetSizeKey} (${options.targetSize.label})`);
  console.log(`Max images: ${options.maxImages}`);
  console.log(`Max variants per screen: ${options.maxVariantsPerScreen}`);

  console.log("\nDetected feature hints:");
  for (const feature of insights.features.slice(0, 6)) {
    console.log(`- ${feature.title}: ${feature.description} (${feature.source})`);
  }

  console.log("\nScreens:");
  for (const screen of plan) {
    console.log(`\n${screen.index}. ${screen.title}`);
    console.log(`   Headline: ${screen.headline}`);
    console.log(`   Subheadline: ${screen.subheadline}`);
    console.log(`   Screenshot: ${screen.screenshotSource}`);
    console.log(`   Prompt: ${screen.prompt}`);
  }
}

function validateCostControls(plan: ScreenPlan[], options: CliOptions, plannedImageGenerations: number): void {
  if (plannedImageGenerations > options.maxImages) {
    throw new Error(
      `Refusing to continue: planned image generations (${plannedImageGenerations}) exceed --max-images (${options.maxImages}).`,
    );
  }

  const variantsPerScreen = 1;
  if (variantsPerScreen > options.maxVariantsPerScreen) {
    throw new Error(
      `Refusing to continue: planned variants per screen (${variantsPerScreen}) exceed --max-variants-per-screen (${options.maxVariantsPerScreen}).`,
    );
  }

  const duplicateOutputs = new Set<string>();
  for (const screen of plan) {
    for (const outputPath of [screen.outputBackgroundPath, screen.outputFinalPath]) {
      if (duplicateOutputs.has(outputPath)) {
        throw new Error(`Duplicate output path in plan: ${relativePath(outputPath)}`);
      }
      duplicateOutputs.add(outputPath);
    }
  }
}

function preflightOutputFiles(plan: ScreenPlan[], force: boolean): void {
  if (force) return;
  const existing = plan
    .flatMap((screen) => [screen.outputBackgroundPath, screen.outputFinalPath])
    .filter((outputPath) => fs.existsSync(outputPath));

  if (existing.length > 0) {
    throw new Error(
      `Refusing to overwrite existing output files without --force:\n${existing.map((file) => `- ${relativePath(file)}`).join("\n")}`,
    );
  }
}

async function generateBackground(prompt: string, options: CliOptions): Promise<Buffer> {
  const ai = (await import("ai")) as Record<string, unknown>;
  const generateImage = ai.experimental_generateImage;
  if (typeof generateImage !== "function") {
    throw new Error("The installed ai package does not expose experimental_generateImage. Check scripts/app-store-images/package.json.");
  }

  let lastError: unknown;
  for (let attempt = 0; attempt <= DEFAULT_RETRIES_PER_IMAGE; attempt += 1) {
    try {
      const request: Record<string, unknown> = {
        model: options.model,
        prompt,
        size: DEFAULT_AI_BACKGROUND_SIZE,
        n: 1,
        providerOptions: {
          openai: {
            quality: options.quality,
          },
        },
      };
      if (options.seed !== undefined) request.seed = options.seed;

      const result = await generateImage(request);
      return extractImageBuffer(result);
    } catch (error) {
      lastError = error;
      if (attempt < DEFAULT_RETRIES_PER_IMAGE) {
        console.warn(`AI image generation failed; retrying once. Reason: ${error instanceof Error ? error.message : String(error)}`);
      }
    }
  }

  throw new Error(`AI image generation failed: ${lastError instanceof Error ? lastError.message : String(lastError)}`);
}

function extractImageBuffer(result: unknown): Buffer {
  const record = result as Record<string, unknown>;
  const images = Array.isArray(record.images) ? record.images : [];
  const image = record.image ?? images[0];
  if (!image) {
    throw new Error("AI image generation returned no image.");
  }

  if (Buffer.isBuffer(image)) return image;
  if (typeof image === "string") return Buffer.from(image, "base64");

  const imageRecord = image as Record<string, unknown>;
  if (imageRecord.uint8Array instanceof Uint8Array) return Buffer.from(imageRecord.uint8Array);
  if (typeof imageRecord.base64 === "string") return Buffer.from(imageRecord.base64, "base64");
  if (typeof imageRecord.data === "string") return Buffer.from(imageRecord.data, "base64");
  if (imageRecord.data instanceof Uint8Array) return Buffer.from(imageRecord.data);

  throw new Error("Could not extract bytes from AI image response.");
}

async function compositeFinalImage(screen: ScreenPlan, insights: RepoInsights, options: CliOptions): Promise<void> {
  const sharpModule = await import("sharp");
  const sharp = sharpModule.default;
  const { width, height } = options.targetSize;

  const textOverlay = Buffer.from(renderTextOverlaySvg(screen, insights, options.targetSize));
  const phoneLayer = await createPhoneLayer(sharp, screen, insights, options.targetSize);

  await sharp(screen.outputBackgroundPath)
    .resize(width, height, { fit: "cover", position: "center" })
    .composite([
      { input: textOverlay, left: 0, top: 0 },
      { input: phoneLayer.buffer, left: phoneLayer.left, top: phoneLayer.top },
    ])
    .png()
    .toFile(screen.outputFinalPath);
}

type SharpFactory = typeof sharpDefault;

async function createPhoneLayer(
  sharp: SharpFactory,
  screen: ScreenPlan,
  insights: RepoInsights,
  targetSize: TargetSize,
): Promise<{ buffer: Buffer; left: number; top: number }> {
  let isLandscape = false;
  if (screen.screenshotPath) {
    const metadata = await sharp(screen.screenshotPath).metadata();
    if (metadata.width && metadata.height) {
      isLandscape = metadata.width > metadata.height * 1.12;
    }
  }

  const frameWidth = isLandscape ? Math.round(targetSize.width * 0.84) : Math.round(targetSize.width * 0.62);
  const frameHeight = isLandscape ? Math.round(frameWidth * 0.56) : Math.round(frameWidth * 2.04);
  const padding = Math.round(frameWidth * 0.045);
  const innerWidth = frameWidth - padding * 2;
  const innerHeight = frameHeight - padding * 2;
  const outerRadius = Math.round(frameWidth * 0.09);
  const innerRadius = Math.round(frameWidth * 0.06);
  const shadowPadding = Math.round(frameWidth * 0.055);
  const layerWidth = frameWidth + shadowPadding * 2;
  const layerHeight = frameHeight + shadowPadding * 2;

  const outerSvg = Buffer.from(`
    <svg width="${layerWidth}" height="${layerHeight}" viewBox="0 0 ${layerWidth} ${layerHeight}" xmlns="http://www.w3.org/2000/svg">
      <rect x="${shadowPadding + 18}" y="${shadowPadding + 28}" width="${frameWidth - 36}" height="${frameHeight - 22}" rx="${outerRadius}" fill="#000000" opacity="0.28"/>
      <rect x="${shadowPadding}" y="${shadowPadding}" width="${frameWidth}" height="${frameHeight}" rx="${outerRadius}" fill="#11110F"/>
      <rect x="${shadowPadding + padding}" y="${shadowPadding + padding}" width="${innerWidth}" height="${innerHeight}" rx="${innerRadius}" fill="${insights.brandColors.secondaryColor}"/>
    </svg>
  `);

  const base = sharp(outerSvg).png();
  const innerLeft = shadowPadding + padding;
  const innerTop = shadowPadding + padding;
  const screenBuffer = screen.screenshotPath
    ? await roundedScreenshot(sharp, screen.screenshotPath, innerWidth, innerHeight, innerRadius)
    : await placeholderScreenshot(sharp, innerWidth, innerHeight, innerRadius, insights);

  const composites: Array<{ input: Buffer; left: number; top: number }> = [
    { input: screenBuffer, left: innerLeft, top: innerTop },
  ];

  if (screen.draftOnly) {
    composites.push({
      input: Buffer.from(renderDraftBadgeSvg(frameWidth, insights.brandColors.accentColor)),
      left: shadowPadding + Math.round(frameWidth * 0.06),
      top: shadowPadding + frameHeight - 92,
    });
  }

  const buffer = await base.composite(composites).png().toBuffer();
  const left = Math.round((targetSize.width - layerWidth) / 2);
  const top = isLandscape ? Math.round(targetSize.height * 0.47) : Math.round(targetSize.height * 0.36);

  return { buffer, left, top };
}

async function roundedScreenshot(
  sharp: SharpFactory,
  screenshotPath: string,
  width: number,
  height: number,
  radius: number,
): Promise<Buffer> {
  const screenshot = await sharp(screenshotPath).resize(width, height, { fit: "cover", position: "center" }).png().toBuffer();
  const mask = Buffer.from(`
    <svg width="${width}" height="${height}" xmlns="http://www.w3.org/2000/svg">
      <rect x="0" y="0" width="${width}" height="${height}" rx="${radius}" fill="#fff"/>
    </svg>
  `);
  return sharp(screenshot).composite([{ input: mask, blend: "dest-in" }]).png().toBuffer();
}

async function placeholderScreenshot(
  sharp: SharpFactory,
  width: number,
  height: number,
  radius: number,
  insights: RepoInsights,
): Promise<Buffer> {
  const background = insights.brandColors.secondaryColor;
  const ink = insights.brandColors.primaryColor;
  const accent = insights.brandColors.accentColor;
  const svg = `
    <svg width="${width}" height="${height}" xmlns="http://www.w3.org/2000/svg">
      <rect width="100%" height="100%" rx="${radius}" fill="${background}"/>
      <pattern id="grid" width="36" height="36" patternUnits="userSpaceOnUse">
        <path d="M 36 0 L 0 0 0 36" fill="none" stroke="${ink}" stroke-opacity="0.08" stroke-width="1"/>
      </pattern>
      <rect width="100%" height="100%" rx="${radius}" fill="url(#grid)"/>
      <rect x="${Math.round(width * 0.12)}" y="${Math.round(height * 0.28)}" width="${Math.round(width * 0.76)}" height="${Math.round(height * 0.28)}" rx="28" fill="#FFFFFF" opacity="0.5" stroke="${ink}" stroke-opacity="0.18"/>
      <circle cx="${Math.round(width * 0.32)}" cy="${Math.round(height * 0.68)}" r="${Math.round(width * 0.075)}" fill="${accent}"/>
      <circle cx="${Math.round(width * 0.50)}" cy="${Math.round(height * 0.68)}" r="${Math.round(width * 0.075)}" fill="${ink}" fill-opacity="0.88"/>
      <circle cx="${Math.round(width * 0.68)}" cy="${Math.round(height * 0.68)}" r="${Math.round(width * 0.075)}" fill="${accent}" fill-opacity="0.78"/>
      <text x="50%" y="${Math.round(height * 0.42)}" text-anchor="middle" font-family="-apple-system, BlinkMacSystemFont, 'SF Pro Display', sans-serif" font-size="${Math.round(width * 0.075)}" font-weight="700" fill="${ink}">Add app</text>
      <text x="50%" y="${Math.round(height * 0.50)}" text-anchor="middle" font-family="-apple-system, BlinkMacSystemFont, 'SF Pro Display', sans-serif" font-size="${Math.round(width * 0.075)}" font-weight="700" fill="${ink}">screenshot here</text>
      <text x="50%" y="${Math.round(height * 0.60)}" text-anchor="middle" font-family="-apple-system, BlinkMacSystemFont, sans-serif" font-size="${Math.round(width * 0.033)}" fill="${ink}" opacity="0.62">draft-only placeholder</text>
    </svg>
  `;
  return sharp(Buffer.from(svg)).png().toBuffer();
}

function renderTextOverlaySvg(screen: ScreenPlan, insights: RepoInsights, targetSize: TargetSize): string {
  const margin = Math.round(targetSize.width * 0.075);
  const panelX = margin;
  const panelY = Math.round(targetSize.height * 0.045);
  const panelWidth = targetSize.width - margin * 2;
  const panelHeight = Math.round(targetSize.height * 0.255);
  const headlineFont = Math.round(targetSize.width * 0.066);
  const subheadlineFont = Math.round(targetSize.width * 0.029);
  const eyebrowFont = Math.round(targetSize.width * 0.023);
  const maxHeadlineChars = Math.max(12, Math.floor(panelWidth / (headlineFont * 0.52)));
  const maxSubheadlineChars = Math.max(22, Math.floor(panelWidth / (subheadlineFont * 0.52)));
  const headlineLines = wrapWords(screen.headline, maxHeadlineChars).slice(0, 3);
  const subheadlineLines = wrapWords(screen.subheadline, maxSubheadlineChars).slice(0, 2);
  const headlineLineHeight = Math.round(headlineFont * 1.05);
  const subheadlineLineHeight = Math.round(subheadlineFont * 1.28);
  const headlineStartY = panelY + Math.round(panelHeight * 0.31);
  const subheadlineStartY = headlineStartY + headlineLines.length * headlineLineHeight + Math.round(targetSize.height * 0.025);
  const accent = insights.brandColors.accentColor;
  const paper = insights.brandColors.secondaryColor;

  return `
    <svg width="${targetSize.width}" height="${targetSize.height}" viewBox="0 0 ${targetSize.width} ${targetSize.height}" xmlns="http://www.w3.org/2000/svg">
      <defs>
        <linearGradient id="fade" x1="0" y1="0" x2="0" y2="1">
          <stop offset="0" stop-color="#000000" stop-opacity="0.36"/>
          <stop offset="1" stop-color="#000000" stop-opacity="0"/>
        </linearGradient>
      </defs>
      <rect x="0" y="0" width="${targetSize.width}" height="${Math.round(targetSize.height * 0.56)}" fill="url(#fade)"/>
      <rect x="${panelX}" y="${panelY}" width="${panelWidth}" height="${panelHeight}" rx="48" fill="#11110F" opacity="0.72"/>
      <rect x="${panelX + 34}" y="${panelY + 34}" width="72" height="8" rx="4" fill="${accent}"/>
      <text x="${panelX + 34}" y="${panelY + 88}" font-family="-apple-system, BlinkMacSystemFont, 'SF Pro Display', sans-serif" font-size="${eyebrowFont}" font-weight="700" letter-spacing="4" fill="${accent}">${escapeXml(insights.appName.toUpperCase())}</text>
      ${headlineLines
        .map(
          (line, lineIndex) =>
            `<text x="${panelX + 34}" y="${headlineStartY + lineIndex * headlineLineHeight}" font-family="-apple-system, BlinkMacSystemFont, 'SF Pro Display', sans-serif" font-size="${headlineFont}" font-weight="750" letter-spacing="-3" fill="${paper}">${escapeXml(line)}</text>`,
        )
        .join("\n")}
      ${subheadlineLines
        .map(
          (line, lineIndex) =>
            `<text x="${panelX + 38}" y="${subheadlineStartY + lineIndex * subheadlineLineHeight}" font-family="-apple-system, BlinkMacSystemFont, sans-serif" font-size="${subheadlineFont}" font-weight="500" fill="${paper}" opacity="0.86">${escapeXml(line)}</text>`,
        )
        .join("\n")}
    </svg>
  `;
}

function renderDraftBadgeSvg(frameWidth: number, accent: string): string {
  const width = Math.round(frameWidth * 0.52);
  const height = 54;
  return `
    <svg width="${width}" height="${height}" xmlns="http://www.w3.org/2000/svg">
      <rect x="0" y="0" width="${width}" height="${height}" rx="27" fill="#11110F" opacity="0.84"/>
      <circle cx="28" cy="27" r="9" fill="${accent}"/>
      <text x="48" y="35" font-family="-apple-system, BlinkMacSystemFont, sans-serif" font-size="21" font-weight="700" fill="#fff">DRAFT ONLY</text>
    </svg>
  `;
}

function buildManifest(
  insights: RepoInsights,
  plan: ScreenPlan[],
  options: CliOptions,
  plannedImageGenerations: number,
  filesCreated: string[],
): Manifest {
  const noScreenshots = insights.screenshots.length === 0;
  const assumptions = [
    "AI is used only for abstract backgrounds and visual treatments; app UI is either a real screenshot or a draft placeholder.",
    "Marketing copy was derived from README.md, Website/index.html, and visible SwiftUI strings, and avoids unverifiable ranking claims.",
  ];
  if (noScreenshots) {
    assumptions.push("No real app screenshots were found, so final images are draft-only placeholders and should not be submitted as-is.");
  }
  if (!fs.existsSync(options.brandFile)) {
    assumptions.push("No app-store-input/brand.json was found; detected repo colors and design hints were used.");
  }

  return {
    timestamp: new Date().toISOString(),
    appName: insights.appName,
    appNameSource: insights.appNameSource,
    repoRoot,
    detectedFeatures: insights.features,
    detectedBrandColors: insights.brandColors,
    typographyHints: insights.typographyHints,
    designLanguage: insights.designLanguage,
    selectedScreenshotSources: plan.map((screen) => ({
      screen: screen.title,
      path: screen.screenshotPath ? relativePath(screen.screenshotPath) : null,
      source: screen.screenshotSource,
    })),
    generatedPrompts: plan.map((screen) => ({ screen: screen.title, prompt: screen.prompt })),
    model: options.model,
    quality: options.quality,
    aiGeneration: {
      dryRun: options.dryRun,
      paid: !options.dryRun,
      plannedImageGenerations,
      aiBackgroundSize: DEFAULT_AI_BACKGROUND_SIZE,
      aiBackgroundAspectRatio: aspectRatio(DEFAULT_AI_BACKGROUND_SIZE),
      maxImages: options.maxImages,
      maxVariantsPerScreen: options.maxVariantsPerScreen,
      retriesPerImage: DEFAULT_RETRIES_PER_IMAGE,
      seed: options.seed,
    },
    outputDimensions: options.targetSize,
    supportedTargetSizes: Object.keys(TARGET_SIZES),
    draftOnly: noScreenshots,
    assumptions,
    filesCreated: [...filesCreated, relativePath(path.join(options.outputDir, "manifest.json"))],
  };
}

function writeManifest(outputDir: string, manifest: Manifest): string {
  const manifestPath = path.join(outputDir, "manifest.json");
  fs.writeFileSync(manifestPath, `${JSON.stringify(manifest, null, 2)}\n`);
  return manifestPath;
}

function aspectRatio(size: string): string {
  const [width, height] = size.split("x").map(Number);
  if (!width || !height) return "unknown";
  const divisor = gcd(width, height);
  return `${width / divisor}:${height / divisor}`;
}

function gcd(a: number, b: number): number {
  return b === 0 ? a : gcd(b, a % b);
}

function ensureDirectory(directory: string): void {
  fs.mkdirSync(directory, { recursive: true });
}

function ensureBrandExample(): void {
  const examplePath = path.join(repoRoot, "app-store-input/brand.example.json");
  if (fs.existsSync(examplePath)) return;
  const example = {
    appName: "App Name",
    primaryColor: "#000000",
    secondaryColor: "#ffffff",
    accentColor: "#4F46E5",
    fontFamily: "system",
    category: "productivity",
    tone: "premium, calm, modern",
  };
  fs.writeFileSync(examplePath, `${JSON.stringify(example, null, 2)}\n`);
}

function readTextIfExists(filePath: string): string | undefined {
  try {
    return fs.existsSync(filePath) ? fs.readFileSync(filePath, "utf8") : undefined;
  } catch {
    return undefined;
  }
}

function relativePath(filePath: string): string {
  return path.relative(repoRoot, filePath) || ".";
}

function slugify(value: string): string {
  return value
    .toLowerCase()
    .replace(/[^a-z0-9]+/g, "-")
    .replace(/^-+|-+$/g, "")
    .slice(0, 80);
}

function wrapWords(text: string, maxChars: number): string[] {
  const words = text.split(/\s+/).filter(Boolean);
  const lines: string[] = [];
  let current = "";

  for (const word of words) {
    const candidate = current ? `${current} ${word}` : word;
    if (candidate.length > maxChars && current) {
      lines.push(current);
      current = word;
    } else {
      current = candidate;
    }
  }

  if (current) lines.push(current);
  return lines.length > 0 ? lines : [text];
}

function stripHtml(value: string): string {
  return value.replace(/<[^>]+>/g, " ").replace(/&nbsp;/g, " ").replace(/&amp;/g, "&");
}

function escapeXml(value: string): string {
  return value
    .replace(/&/g, "&amp;")
    .replace(/</g, "&lt;")
    .replace(/>/g, "&gt;")
    .replace(/"/g, "&quot;")
    .replace(/'/g, "&apos;");
}

main().catch((error) => {
  console.error(`\nError: ${error instanceof Error ? error.message : String(error)}`);
  process.exit(1);
});
