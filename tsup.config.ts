import { defineConfig } from 'tsup'

export default defineConfig({
  entry: ['./index.ts'],
  format: ['esm'],
  outExtension: () => ({
    js: '.mjs',
  }),
  clean: true,
})