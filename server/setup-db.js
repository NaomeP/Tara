import 'dotenv/config';
import { readFile } from 'node:fs/promises';
import { Pool } from 'pg';

if (!process.env.DATABASE_URL) throw new Error('Set DATABASE_URL before initializing the database.');
const pool = new Pool({ connectionString: process.env.DATABASE_URL, ssl: process.env.NODE_ENV === 'production' ? { rejectUnauthorized: true } : undefined });
try {
  const schema=await readFile(new URL('./schema.sql', import.meta.url), 'utf8');
  const schemaOnly=process.argv.includes('--schema-only')||process.env.DB_SETUP_SCHEMA_ONLY==='true';
  const ddl=schemaOnly?schema.split(/\nINSERT INTO categories\(name,slug,display_order\) VALUES/)[0]:schema;
  await pool.query(ddl);
  console.log(schemaOnly?'Thara database schema is ready. No starter records were inserted.':'Thara database schema and starter catalogue are ready.');
} finally {
  await pool.end();
}
