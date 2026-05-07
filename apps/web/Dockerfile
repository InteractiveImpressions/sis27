# syntax=docker/dockerfile:1
FROM node:22-alpine AS build
ENV PNPM_HOME=/pnpm
ENV PATH=$PNPM_HOME:$PATH
RUN corepack enable && corepack prepare pnpm@9.15.4 --activate
WORKDIR /repo
COPY package.json pnpm-workspace.yaml pnpm-lock.yaml ./
COPY apps/web/package.json apps/web/
COPY packages/platform/package.json packages/platform/
RUN --mount=type=cache,id=sis27-pnpm-store,target=/pnpm/store \
  pnpm config set store-dir /pnpm/store && pnpm install --frozen-lockfile
COPY packages/platform packages/platform
COPY apps/web apps/web
RUN pnpm --filter @sis27/platform build
ENV NUXT_TELEMETRY_DISABLED=1
# Public Supabase client values are inlined at build time; must match Kong’s ANON_KEY on the host stack.
ARG NUXT_PUBLIC_SUPABASE_URL
ARG NUXT_PUBLIC_SUPABASE_ANON_KEY
ENV NUXT_PUBLIC_SUPABASE_URL=$NUXT_PUBLIC_SUPABASE_URL
ENV NUXT_PUBLIC_SUPABASE_ANON_KEY=$NUXT_PUBLIC_SUPABASE_ANON_KEY
RUN test -n "$NUXT_PUBLIC_SUPABASE_ANON_KEY" || (echo "NUXT_PUBLIC_SUPABASE_ANON_KEY build-arg is required" && exit 1)
RUN pnpm --filter @sis27/web build

FROM node:22-alpine AS runner
WORKDIR /app
ENV NODE_ENV=production
ENV HOST=0.0.0.0
ENV PORT=3000
COPY --from=build /repo/apps/web/.output ./.output
EXPOSE 3000
CMD ["node", ".output/server/index.mjs"]
