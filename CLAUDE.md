# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Overview

Documentation site for the [classifier](https://github.com/cardmagic/classifier) Ruby gem, built with Astro and Tailwind CSS v4. Live at https://rubyclassifier.com.

## Commands

```bash
pnpm install    # Install dependencies
pnpm dev        # Start dev server (localhost:4321)
pnpm build      # Build for production
pnpm preview    # Preview production build
```

## Architecture

This is an Astro static site with content collections for documentation:

- `src/content/tutorials/` - Tutorial markdown files with frontmatter: `title`, `description`, `difficulty` (beginner|intermediate|advanced), `order`
- `src/content/guides/{category}/` - Guide markdown files with frontmatter: `title`, `description`, `category` (start|bayes|lsi|knn|tfidf|persistence|extensions|production), `order`
- `src/content/config.ts` - Zod schemas defining the content collection structure

**Routing:**
- `/docs/tutorials/[slug]` - Tutorial pages from `src/content/tutorials/*.md`
- `/docs/guides/[category]/[slug]` - Guide pages from `src/content/guides/{category}/*.md`

**Layouts:**
- `BaseLayout.astro` - Site-wide wrapper with header/footer
- `DocsLayout.astro` - Documentation pages with prose styling

## Deployment

Cloudflare Pages with automatic deploys on push to `main`.
