/** @file No blank line after the block. */
import { readFileSync } from 'node:fs';

/** Reads. */
export const read = (path) => readFileSync(path, 'utf8');
