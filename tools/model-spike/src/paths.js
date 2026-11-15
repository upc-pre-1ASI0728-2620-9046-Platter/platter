import path from 'node:path';
import { fileURLToPath } from 'node:url';

const here = path.dirname(fileURLToPath(import.meta.url));

export const TOOL_DIR = path.resolve(here, '..');
export const LIBRARY_DIR = path.resolve(TOOL_DIR, '../../backend/src/main/resources/library');
export const DEFAULT_PHOTOS_DIR = path.join(TOOL_DIR, 'photos');
export const OUT_DIR = path.join(TOOL_DIR, 'out');
