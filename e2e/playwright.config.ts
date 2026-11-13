import { defineConfig, devices } from '@playwright/test';

/**
 * E2E de sistema: Front buildado + Service + Postgres reais (docker-compose.e2e.yml), atrás do nginx em
 * http://localhost. Nenhuma chamada à API é interceptada. Um teste por vez: todos usam o mesmo banco.
 */
export default defineConfig({
  testDir: 'tests',
  testMatch: '**/*.e2e.ts',
  workers: 1,
  fullyParallel: false,
  forbidOnly: !!process.env.CI,
  retries: process.env.CI ? 1 : 0,
  timeout: 60_000,
  expect: { timeout: 15_000 },
  reporter: [['list'], ['html', { open: 'never' }]],
  use: {
    baseURL: process.env.E2E_BASE_URL ?? 'http://localhost',
    locale: 'pt-BR',
    timezoneId: 'America/Sao_Paulo',
    trace: 'retain-on-failure',
    screenshot: 'only-on-failure'
  },
  projects: [{ name: 'chromium', use: { ...devices['Desktop Chrome'] } }]
});
