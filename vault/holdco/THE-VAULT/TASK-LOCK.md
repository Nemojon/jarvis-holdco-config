# TASK-LOCK.md — Active Task Registry

Prevents double-assignment. One agent per task.

## FORMAT
[TASK-ID] | [AGENT] | [ASSIGNED] | [STATUS] | [DESCRIPTION]

## ACTIVE LOCKS
(empty — no tasks currently checked out)

## RULES
- When Aria assigns a task: append a line with status=LOCKED
- When agent completes: update status=DONE
- If task is LOCKED, no other agent may pick it up
- Jarvis reviews and clears DONE entries daily
