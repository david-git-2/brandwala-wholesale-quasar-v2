import fs from 'fs';
import path from 'path';
import { fileURLToPath } from 'url';

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);
const srcDir = path.resolve(__dirname, '../src');

// Keep track of counts
let totalMatches = 0;
let allowedCount = 0;
let warningCount = 0;
let violationsCount = 0;

function getFiles(dir) {
  let results = [];
  if (!fs.existsSync(dir)) return results;
  const list = fs.readdirSync(dir);
  list.forEach(file => {
    const filePath = path.join(dir, file);
    const stat = fs.statSync(filePath);
    if (stat && stat.isDirectory()) {
      results = results.concat(getFiles(filePath));
    } else {
      results.push(filePath);
    }
  });
  return results;
}

function getSelectorForPosition(content, index) {
  const openBraceIndex = content.lastIndexOf('{', index);
  if (openBraceIndex === -1) return '';
  
  const closeBraceIndexBetween = content.indexOf('}', openBraceIndex);
  if (closeBraceIndexBetween !== -1 && closeBraceIndexBetween < index) {
    return '';
  }
  
  let prevCloseBraceIndex = content.lastIndexOf('}', openBraceIndex - 1);
  const prevStyleIndex = content.lastIndexOf('<style', openBraceIndex - 1);
  if (prevStyleIndex > prevCloseBraceIndex) {
    const closeAngleIndex = content.indexOf('>', prevStyleIndex);
    if (closeAngleIndex !== -1 && closeAngleIndex < openBraceIndex) {
      prevCloseBraceIndex = closeAngleIndex;
    } else {
      prevCloseBraceIndex = prevStyleIndex + 5;
    }
  }
  
  const selectorPart = content.slice(prevCloseBraceIndex + 1, openBraceIndex);
  return selectorPart.replace(/\/\*[\s\S]*?\*\//g, '').replace(/\s+/g, ' ').trim();
}

console.log('\x1b[36m=== Performance Budget: Checking backdrop-filter usages ===\x1b[0m\n');

const files = getFiles(srcDir);

files.forEach(file => {
  const ext = path.extname(file);
  if (!['.vue', '.scss', '.css', '.html'].includes(ext)) {
    return;
  }

  const content = fs.readFileSync(file, 'utf8');
  if (!content.includes('backdrop-filter')) {
    return;
  }

  const relativePath = path.relative(path.resolve(srcDir, '..'), file);
  const lines = content.split('\n');

  lines.forEach((line, index) => {
    if (!line.includes('backdrop-filter')) {
      return;
    }

    totalMatches++;
    const lineNum = index + 1;

    // Find index of this line in file content to parse selector
    let charIndex = 0;
    for (let i = 0; i < index; i++) {
      charIndex += lines[i].length + 1; // +1 for newline character
    }
    const backdropFilterIndex = charIndex + line.indexOf('backdrop-filter');
    const selector = getSelectorForPosition(content, backdropFilterIndex);

    // Check if it is a violation on .floating-surface or .bw-page-toolbar
    const isViolationClass = selector && /\.(floating-surface|bw-page-toolbar)(?![a-zA-Z0-9_-])/i.test(selector);
    
    // Check if it is on the allowlist
    const isAllowlisted = 
      relativePath.includes('ImageLightbox') ||
      relativePath.includes('PageInitialLoader') ||
      line.includes('q-dialog') ||
      (selector && (selector.includes('signout-dialog') || selector.includes('signout-card')));

    if (isViolationClass) {
      violationsCount++;
      console.error(`  \x1b[31m[VIOLATION]\x1b[0m ${relativePath}:${lineNum} - Class selector "${selector}" uses backdrop-filter:`);
      console.error(`    > \x1b[90m${line.trim()}\x1b[0m`);
    } else if (isAllowlisted) {
      allowedCount++;
      console.log(`  \x1b[32m[ALLOWED]\x1b[0m   ${relativePath}:${lineNum} - Allowed backdrop-filter usage (${selector || 'HTML attribute'}):`);
      console.log(`    > \x1b[90m${line.trim()}\x1b[0m`);
    } else {
      warningCount++;
      console.log(`  \x1b[33m[WARNING]\x1b[0m   ${relativePath}:${lineNum} - Non-standard backdrop-filter usage ("${selector || 'HTML attribute'}"):`);
      console.log(`    > \x1b[90m${line.trim()}\x1b[0m`);
    }
  });
});

console.log('\n\x1b[36m==================== Scan Summary ====================\x1b[0m');
console.log(`Total backdrop-filter occurrences: ${totalMatches}`);
console.log(`Allowed (allowlisted) usages:      ${allowedCount}`);
console.log(`Warnings (non-standard):           ${warningCount}`);
console.log(`Violations (blocked):              ${violationsCount}`);
console.log('\x1b[36m======================================================\x1b[0m\n');

if (violationsCount > 0) {
  console.error('\x1b[31mFAIL: New violations detected in .floating-surface or .bw-page-toolbar classes. Exiting with 1.\x1b[0m');
  process.exit(1);
} else {
  console.log('\x1b[32mSUCCESS: Performance budget checks passed successfully.\x1b[0m');
  process.exit(0);
}
