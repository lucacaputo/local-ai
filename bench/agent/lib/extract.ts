// Structured reading of free text by the local model through the router (B2's proposed slots): the model only turns
// text into JSON, and the check itself stays code. Needs the stack up.
import { readSecret } from './secrets.ts';

export async function extract<T>(instructions: string, text: string, schema: object, model = 'local-coder'): Promise<T> {
  const key = readSecret('local-ai/router-key');
  if (!key) throw new Error('no router key in Credential Manager; run scripts\\init-secrets.ps1');
  const r = await fetch('http://127.0.0.1:4000/v1/chat/completions', {
    method: 'POST',
    headers: { 'content-type': 'application/json', 'x-litellm-api-key': key },
    body: JSON.stringify({
      model, temperature: 0, max_tokens: 4000,
      messages: [{ role: 'system', content: `${instructions}\nAnswer with JSON only.` }, { role: 'user', content: text || '(empty)' }],
      response_format: { type: 'json_schema', json_schema: { name: 'result', strict: true, schema } },
    }),
  });
  if (!r.ok) throw new Error(`extract: router answered ${r.status} ${(await r.text()).slice(0, 200)}`);
  const j = await r.json();
  return JSON.parse(j.choices[0].message.content) as T;
}
