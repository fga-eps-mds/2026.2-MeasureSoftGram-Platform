import { expect, test } from '@playwright/test';
import { login, SEED, seedIds } from '../support/seed';

test.describe('@SIS-04 dashboards com os valores fixos do seed', () => {
  let productPath: string;

  test.beforeEach(async ({ page }) => {
    const token = await login(page);
    const { organizationId, productId } = await seedIds(page.request, token);
    productPath = `/products/${organizationId}-${productId}-${encodeURIComponent(SEED.product)}`;
  });

  test('@SIS-04 pulso do produto: último TSQMI 0.700, variação e contagem das medições', async ({ page }) => {
    await page.goto(`${productPath}/`);
    await expect(page.getByRole('heading', { level: 6, name: /^\d\.\d{3}$/ })).toHaveText(['0.700']);
    // 0.70 contra 0.65 da medição anterior
    await expect(page.getByText('▲ 7.69%')).toBeVisible();
    // as releases do período não entram: o SIS-03 cria mais uma a cada execução
    await expect(page.getByText(/^1 repositório • 5 medições no período selecionado • /)).toBeVisible();
  });

  test('@SIS-04 visão geral: totais da release e planejado × realizado', async ({ page }) => {
    await page.goto(`${productPath}/dashboards/overview/`);
    await expect(page.getByRole('combobox', { name: 'Release' })).toContainText(SEED.release);

    await expect(page.getByTestId('vector-rp').getByRole('cell')).toHaveText(['0.50', '0.50', '0.50']);
    await expect(page.getByTestId('vector-rd').getByRole('cell')).toHaveText(['0.80', '0.60', '0.70']);

    for (const [count, label] of [
      ['3', 'Características'],
      ['4', 'Subcaracterísticas'],
      ['9', 'Medidas'],
      ['14', 'Métricas'],
      ['1', 'Repositórios']
    ]) {
      await expect(page.getByText(label, { exact: true }).locator('..')).toContainText(count);
    }
  });
});
