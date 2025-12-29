import { defineCollection, z } from 'astro:content';

const tutorials = defineCollection({
  type: 'content',
  schema: z.object({
    title: z.string(),
    description: z.string(),
    difficulty: z.enum(['beginner', 'intermediate', 'advanced']),
    classifiers: z.array(z.enum(['bayes', 'lsi', 'knn', 'tfidf', 'logisticregression'])).optional(),
    order: z.number(),
  }),
});

const guides = defineCollection({
  type: 'content',
  schema: z.object({
    title: z.string(),
    description: z.string(),
    category: z.enum(['start', 'bayes', 'lsi', 'knn', 'tfidf', 'logisticregression', 'persistence', 'extensions', 'production']),
    order: z.number(),
  }),
});

export const collections = {
  tutorials,
  guides,
};
