import { defineCollection, z } from 'astro:content';

const tutorials = defineCollection({
  type: 'content',
  schema: z.object({
    title: z.string(),
    description: z.string(),
    difficulty: z.enum(['beginner', 'intermediate', 'advanced']),
    order: z.number(),
  }),
});

const guides = defineCollection({
  type: 'content',
  schema: z.object({
    title: z.string(),
    description: z.string(),
    category: z.enum(['start', 'bayes', 'lsi', 'persistence', 'extensions', 'production']),
    order: z.number(),
  }),
});

export const collections = {
  tutorials,
  guides,
};
