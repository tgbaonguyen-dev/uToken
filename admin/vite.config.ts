import { defineConfig } from 'vite';
import react from '@vitejs/plugin-react';

// Built straight into firebase/ because Hosting only serves folders inside the project.
export default defineConfig({ plugins: [react()], server: { port: 5174 }, build: { outDir: '../firebase/admin-dist', emptyOutDir: true } });
