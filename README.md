# Ruby Classifier Documentation

Documentation website for the [classifier](https://github.com/cardmagic/classifier) Ruby gem.

**Live site:** https://rubyclassifier.com

## Development

```bash
# Install dependencies
pnpm install

# Start dev server
pnpm dev

# Build for production
pnpm build

# Preview production build
pnpm preview
```

## Adding Content

### Tutorials

Create a new file in `src/content/tutorials/`:

```markdown
---
title: "Tutorial Title"
description: "Brief description"
difficulty: beginner  # beginner | intermediate | advanced
order: 3
---

Your tutorial content here...
```

### Guides

Create a new file in `src/content/guides/{category}/`:

```markdown
---
title: "Guide Title"
description: "Brief description"
category: bayes  # start | bayes | lsi | extensions | production
order: 1
---

Your guide content here...
```

## Deployment

This site is deployed to Cloudflare Pages. Pushes to `main` trigger automatic deployments.

## License

MIT
