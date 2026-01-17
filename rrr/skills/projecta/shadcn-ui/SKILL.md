---
name: projecta.shadcn-ui
description: shadcn/ui component library conventions
tags: [ui, shadcn, tailwind, components, design]
max_lines: 80
---

# shadcn/ui Conventions

## When to Use

Load this skill when:
- Adding UI components
- Working with Tailwind CSS
- Any task mentioning "ui", "component", "shadcn", or "tailwind"

## Rules

### Component Library

**MUST:**
- Use shadcn/ui for UI components
- Use Tailwind CSS for styling
- Install components via CLI: `npx shadcn@latest add <component>`

**MUST NOT:**
- Install Material UI (`@mui/*`)
- Install Chakra UI (`@chakra-ui/*`)
- Install Ant Design (`antd`)
- Install Bootstrap
- Write custom CSS when Tailwind utilities exist

### Installing Components

```bash
# Add a single component
npx shadcn@latest add button

# Add multiple components
npx shadcn@latest add button card dialog

# Add all components (use sparingly)
npx shadcn@latest add --all
```

Components are installed to `src/components/ui/`.

### Using Components

```typescript
import { Button } from '@/components/ui/button';
import { Card, CardHeader, CardContent } from '@/components/ui/card';
import { Input } from '@/components/ui/input';

export function MyComponent() {
  return (
    <Card>
      <CardHeader>Title</CardHeader>
      <CardContent>
        <Input placeholder="Enter text..." />
        <Button>Submit</Button>
      </CardContent>
    </Card>
  );
}
```

### Customization

**DO:** Customize via Tailwind classes or by editing the component file:

```typescript
// Using className prop
<Button className="w-full bg-brand-500">Custom Button</Button>

// Or edit src/components/ui/button.tsx directly
```

**DON'T:** Create wrapper components unless necessary. shadcn components are meant to be owned and modified.

### Common Components

| Need | Component |
|------|-----------|
| Buttons | `button` |
| Forms | `input`, `label`, `select`, `checkbox`, `radio-group` |
| Layout | `card`, `separator`, `tabs` |
| Feedback | `alert`, `toast`, `dialog` |
| Navigation | `navigation-menu`, `dropdown-menu`, `command` |
| Data display | `table`, `badge`, `avatar` |

### Tailwind CSS

Configure in `tailwind.config.ts`:

```typescript
const config = {
  darkMode: ["class"],
  content: ["./src/**/*.{ts,tsx}"],
  theme: {
    extend: {
      colors: {
        // Custom colors
      },
    },
  },
  plugins: [require("tailwindcss-animate")],
};
```

### cn() Utility

Use the `cn()` utility for conditional classes:

```typescript
import { cn } from '@/lib/utils';

<div className={cn(
  "base-classes",
  isActive && "active-classes",
  variant === "primary" && "primary-classes"
)} />
```
