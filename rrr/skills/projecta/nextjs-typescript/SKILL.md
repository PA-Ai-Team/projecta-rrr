---
name: projecta.nextjs-typescript
description: Next.js App Router with TypeScript conventions
tags: [framework, nextjs, typescript, react, app-router]
max_lines: 100
---

# Next.js TypeScript Conventions

## When to Use

This skill loads automatically for ALL plans (default skill). It ensures consistent stack conventions across the project.

## Rules

### Router

**MUST:**
- Use App Router (NEVER Pages Router)
- Place pages in `src/app/` directory
- Use file-based routing conventions
- Use `page.tsx`, `layout.tsx`, `loading.tsx`, `error.tsx`

**MUST NOT:**
- Create files in `pages/` directory
- Use `getServerSideProps` or `getStaticProps` (App Router uses different patterns)
- Mix App Router and Pages Router

### TypeScript

**MUST:**
- Enable strict mode in `tsconfig.json`
- Use explicit types (no implicit `any`)
- Define interfaces for component props
- Use path alias `@/*` for imports

**MUST NOT:**
- Use `// @ts-ignore` without explanation
- Disable TypeScript checks
- Use `any` type without justification

### Package Manager

**MUST:**
- Use `npm` for all package operations

**MUST NOT:**
- Use yarn or pnpm
- Create `yarn.lock` or `pnpm-lock.yaml`

### Project Structure

```
src/
├── app/                    # App Router pages
│   ├── layout.tsx          # Root layout
│   ├── page.tsx            # Home page
│   ├── globals.css         # Global styles
│   └── api/                # API routes
│       └── [route]/
│           └── route.ts
├── components/             # React components
│   └── ui/                 # shadcn/ui components
├── lib/                    # Utility functions
└── types/                  # TypeScript types
```

### Path Aliases

Configure in `tsconfig.json`:

```json
{
  "compilerOptions": {
    "baseUrl": ".",
    "paths": {
      "@/*": ["./src/*"]
    }
  }
}
```

Usage:
```typescript
import { Button } from '@/components/ui/button';
import { cn } from '@/lib/utils';
```

## Commands

```bash
# Development
npm run dev                 # Start dev server

# Build
npm run build              # Production build
npm run start              # Start production server

# Linting
npm run lint               # Run ESLint
```

## Environment Variables

```bash
# .env.local (not committed)
DATABASE_URL=
NEXTAUTH_SECRET=
NEXTAUTH_URL=http://localhost:3000

# .env.example (committed)
DATABASE_URL=
NEXTAUTH_SECRET=
NEXTAUTH_URL=
```

## Server vs Client Components

**Server Components (default):**
- Fetch data directly
- Access backend resources
- Keep sensitive logic server-side

**Client Components (add `'use client'`):**
- Use React hooks (`useState`, `useEffect`)
- Handle browser events
- Use browser APIs

```typescript
// Server Component (default)
async function ServerComponent() {
  const data = await fetchData();
  return <div>{data}</div>;
}

// Client Component
'use client';
function ClientComponent() {
  const [state, setState] = useState();
  return <button onClick={() => setState(!state)}>Toggle</button>;
}
```
