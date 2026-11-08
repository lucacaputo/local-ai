import { B1 } from './b1.ts';
import { B2 } from './b2.ts';
import { B3 } from './b3.ts';
import { B4 } from './b4.ts';
import { B6_MAIL_TASK, B6_WEB } from './b6.ts';
import { U1, U2, U3 } from './user.ts';
import type { Task } from './types.ts';

// B5 (scheduled) waits for m-7
export const TASKS: Task[] = [B1, B2, B3, B4, B6_WEB, B6_MAIL_TASK, U1, U2, U3];
export const task = (id: string) => {
  const t = TASKS.find((x) => x.id.toLowerCase() === id.toLowerCase());
  if (!t) throw new Error(`unknown task ${id}; known: ${TASKS.map((x) => x.id).join(', ')}`);
  return t;
};
