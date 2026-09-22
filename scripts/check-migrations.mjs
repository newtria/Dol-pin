import {readdirSync} from 'node:fs';
const seen=new Map();
for(const name of readdirSync('supabase/migrations').filter(n=>n.endsWith('.sql')).sort()) {
 const match=/^(\d+)_.+\.sql$/.exec(name);if(!match)throw new Error(`Invalid migration name: ${name}`);
 if(seen.has(match[1]))throw new Error(`Duplicate migration version: ${seen.get(match[1])}, ${name}`);
 seen.set(match[1],name);
}
console.log(`${seen.size} unique migration versions`);
