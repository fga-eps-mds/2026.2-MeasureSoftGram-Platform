import { expect, Page, test } from '@playwright/test';
import { login, SEED, seedIds, unique } from '../support/seed';

const nextButton = (page: Page) => page.getByRole('button', { name: /^(Avançar|Next)$/i });
const finishButton = (page: Page) => page.getByRole('button', { name: /^(Finalizar|Finish)$/i });
const releaseName = (page: Page) => page.getByLabel(/Nome da Release|Release Name/);

const isoDay = (offset: number) => new Date(Date.now() + offset * 86_400_000).toISOString().slice(0, 10);

/**
 * Um período de um dia que não cruza nenhuma release: depois do fim da release do seed (+30 dias) e diferente a cada
 * execução. Com conflito, o Front oferece encerrar a release ativa, o que mudaria os dados fixos do seed.
 */
const FIRST_FREE_DAY = 60 + 2 * (Math.floor(Date.now() / 1000) % 50_000);

test('@SIS-03 criar uma release do produto do seed', async ({ page }) => {
  const token = await login(page);
  const { organizationId, productId } = await seedIds(page.request, token);
  const name = unique('Release E2E');

  await page.goto(`/products/${organizationId}-${productId}-${encodeURIComponent(SEED.product)}/releases/create/`);
  await expect(page.getByText(SEED.repository, { exact: true })).toBeVisible();
  await nextButton(page).click();

  await releaseName(page).fill(name);
  await page.getByLabel(/Data de Inicio da Release|Release Start Date/).fill(isoDay(FIRST_FREE_DAY));
  await page.getByLabel(/Data de Fim da Release|Release End Date/).fill(isoDay(FIRST_FREE_DAY + 1));

  const created = page.waitForResponse(
    (r) => r.request().method() === 'POST' && r.url().endsWith(`/products/${productId}/release/`)
  );
  // dados básicos (validados no Service) → configuração do modelo → balanceamento (sem mudar os valores de
  // referência, o passo deles é pulado) → Finalizar. Cada clique espera o passo seguinte aparecer.
  await nextButton(page).click();
  await expect(releaseName(page)).toHaveCount(0);
  await nextButton(page).click();
  await finishButton(page).click();
  expect((await created).status()).toBe(201);
  await expect(page.getByText('There is already an active release')).toHaveCount(0);

  await expect(page.getByText(/Release Criada|Release Created/)).toBeVisible();
  await expect(page).toHaveURL(/\/releases\/?$/);
  await expect(page.getByText(name)).toBeVisible();
});
