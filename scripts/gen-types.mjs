// Generate TypeScript + Swift model types from a live database, using the
// same @supabase/postgres-meta generators the Supabase CLI runs — but in
// plain Node, so it works without Docker.
//
// Usage: node scripts/gen-types.mjs <db-url>

import { writeFileSync, mkdirSync } from "node:fs";
import { dirname, join } from "node:path";
import { fileURLToPath } from "node:url";

import { PostgresMeta } from "@supabase/postgres-meta";
import { getGeneratorMetadata } from "@supabase/postgres-meta/dist/lib/generators.js";
import { apply as applyTypescript } from "@supabase/postgres-meta/dist/server/templates/typescript.js";
import { apply as applySwift } from "@supabase/postgres-meta/dist/server/templates/swift.js";

const dbUrl = process.argv[2];
if (!dbUrl) {
  console.error("usage: node scripts/gen-types.mjs <db-url>");
  process.exit(1);
}

const repo = join(dirname(fileURLToPath(import.meta.url)), "..");
const pgMeta = new PostgresMeta({ connectionString: dbUrl, max: 1 });

const { data, error } = await getGeneratorMetadata(pgMeta, {
  includedSchemas: ["public"],
});
if (error) {
  console.error("postgres-meta error:", error.message ?? error);
  process.exit(1);
}

const tsOut = join(repo, "web/src/lib/database.types.ts");
mkdirSync(dirname(tsOut), { recursive: true });
writeFileSync(tsOut, await applyTypescript({ ...data, detectOneToOneRelationships: true }));
console.log(`wrote ${tsOut}`);

const swiftOut = join(repo, "ios/Ventline/Core/Models/GeneratedModels.swift");
mkdirSync(dirname(swiftOut), { recursive: true });
writeFileSync(swiftOut, await applySwift({ ...data, accessControl: "public" }));
console.log(`wrote ${swiftOut}`);

await pgMeta.end();
