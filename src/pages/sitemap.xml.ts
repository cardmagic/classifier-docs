import type { APIRoute } from 'astro';
import { getCollection } from 'astro:content';

const SITE = 'https://rubyclassifier.com';

export const GET: APIRoute = async () => {
  const guides = await getCollection('guides');
  const tutorials = await getCollection('tutorials');

  const paths = [
    '/',
    '/docs',
    '/docs/guides',
    '/docs/tutorials',
    ...guides.map((entry) => `/docs/guides/${entry.slug}`),
    ...tutorials.map((entry) => `/docs/tutorials/${entry.slug}`),
  ];

  const urls = paths
    .map((path) => `  <url><loc>${SITE}${path}</loc></url>`)
    .join('\n');

  return new Response(
    `<?xml version="1.0" encoding="UTF-8"?>\n<urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9">\n${urls}\n</urlset>\n`,
    { headers: { 'Content-Type': 'application/xml' } }
  );
};
