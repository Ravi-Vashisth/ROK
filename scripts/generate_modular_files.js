import fs from 'node:fs';
import path from 'node:path';

function getFiles(dir, baseDir = '') {
  let results = [];
  const list = fs.readdirSync(dir);
  for (const file of list) {
    const filePath = path.join(dir, file);
    const relPath = path.join(baseDir, file);
    const stat = fs.statSync(filePath);
    if (stat && stat.isDirectory()) {
      results = results.concat(getFiles(filePath, relPath));
    } else if (file.endsWith('.dart') || file.endsWith('.yaml')) {
      results.push(relPath);
    }
  }
  return results;
}

const libDir = path.resolve('lib');
const dartFiles = getFiles(libDir, 'lib');
dartFiles.sort();

const filesMap = {};
for (const relPath of dartFiles) {
  const fullPath = path.resolve(relPath);
  filesMap[relPath] = fs.readFileSync(fullPath, 'utf8');
}

// Add pubspec.yaml
if (fs.existsSync('pubspec.yaml')) {
  filesMap['pubspec.yaml'] = fs.readFileSync('pubspec.yaml', 'utf8');
}

const content = `export const MODULAR_FILES: Record<string, string> = ${JSON.stringify(filesMap, null, 2)};\n`;
fs.writeFileSync(path.resolve('src/modularFiles.ts'), content, 'utf8');
console.log(`Generated src/modularFiles.ts with ${Object.keys(filesMap).length} files.`);
