import { defineConfig } from 'vite';

// Times Intelligence calls the PayShield AI service (times-intelligence/payshield-ai/scripts/run_portal_prototype.py).
const TI = process.env.TI_API || 'http://127.0.0.1:8080';
export default defineConfig({ server: { proxy: { '/api': TI, '/dev': TI } } });
