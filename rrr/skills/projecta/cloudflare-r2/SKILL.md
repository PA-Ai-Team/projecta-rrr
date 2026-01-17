---
name: projecta.cloudflare-r2
description: Cloudflare R2 object storage conventions
tags: [storage, r2, cloudflare, s3]
max_lines: 80
---

# Cloudflare R2 Storage

## When to Use

Load this skill when:
- Working with file uploads or object storage
- Any task mentioning "R2", "storage", "S3", or "bucket"
- Configuring storage environment variables

## Rules

### Naming

**MUST:**
- Call it "Cloudflare R2" (not "S3", not "AWS S3", not "Amazon S3")
- Reference R2-specific documentation

**MUST NOT:**
- Call it S3 or AWS in user-facing text
- Imply this is Amazon Web Services

### SDK Usage

**MUST:**
- Use S3-compatible SDK (`@aws-sdk/client-s3`)
- Configure custom endpoint for R2
- Use R2-specific environment variables

**MUST NOT:**
- Set `AWS_REGION` environment variable
- Use `amazonaws.com` endpoints
- Use AWS-specific features not supported by R2

### Configuration

```typescript
import { S3Client } from '@aws-sdk/client-s3';

const r2Client = new S3Client({
  region: 'auto',
  endpoint: `https://${process.env.CLOUDFLARE_ACCOUNT_ID}.r2.cloudflarestorage.com`,
  credentials: {
    accessKeyId: process.env.R2_ACCESS_KEY_ID!,
    secretAccessKey: process.env.R2_SECRET_ACCESS_KEY!,
  },
});
```

## Environment Variables

```bash
# Required for R2
CLOUDFLARE_ACCOUNT_ID=your_account_id
R2_ACCESS_KEY_ID=your_access_key
R2_SECRET_ACCESS_KEY=your_secret_key
R2_BUCKET_NAME=your_bucket_name

# Optional
R2_PUBLIC_URL=https://your-custom-domain.com  # For public access
```

**.env.example entry:**

```bash
# Cloudflare R2 Storage
CLOUDFLARE_ACCOUNT_ID=
R2_ACCESS_KEY_ID=
R2_SECRET_ACCESS_KEY=
R2_BUCKET_NAME=
```

## Common Operations

```typescript
import { PutObjectCommand, GetObjectCommand } from '@aws-sdk/client-s3';
import { getSignedUrl } from '@aws-sdk/s3-request-presigner';

// Upload
await r2Client.send(new PutObjectCommand({
  Bucket: process.env.R2_BUCKET_NAME,
  Key: 'path/to/file.pdf',
  Body: fileBuffer,
  ContentType: 'application/pdf',
}));

// Generate presigned URL
const url = await getSignedUrl(r2Client, new GetObjectCommand({
  Bucket: process.env.R2_BUCKET_NAME,
  Key: 'path/to/file.pdf',
}), { expiresIn: 3600 });
```

## Wrangler (Optional)

For local development with R2:

```bash
# wrangler.toml
[[r2_buckets]]
binding = "BUCKET"
bucket_name = "my-bucket"
```
