"""
timings.py

Stage-by-stage latency for one /ask round trip, printed to the terminal when
the reply goes out.

The point is to find which stage the wall-clock time actually goes to. The
three model calls (STT, vision, TTS) are network round trips to OpenRouter
and dominate everything else, but which one dominates changes with the model
and the provider — that is the thing worth seeing on every run rather than
guessing at.

Usage:

    t = Timer()
    with t.stage("stt"):
        question = stt.transcribe(...)
    ...
    t.report()

A stage that raises still gets recorded, marked failed, so a run that blew
up halfway still shows where the time went. Stages nest: an inner stage is
reported indented under the outer one, and only outermost stages count
toward the "accounted for" total, so nesting never double-counts.

Timing uses perf_counter (monotonic), so it is immune to the clock being
adjusted mid-request.
"""
import logging
import threading
from contextlib import contextmanager
from time import perf_counter
from typing import Optional

logger = logging.getLogger("vocalens.timings")

# Set TIMINGS=0 in .env to silence the report without touching the code.
import os
ENABLED = os.getenv("TIMINGS", "1").strip().lower() not in ("0", "false", "no")


class Stage:
    def __init__(self, name: str, depth: int, note: str = ""):
        self.name = name
        self.depth = depth
        self.note = note
        self.seconds: float = 0.0
        self.failed = False


class Timer:
    """Records how long each named stage of one request took.

    One Timer per request. It is not shared between requests, but a single
    request can touch more than one thread (FastAPI runs sync endpoints in a
    threadpool), so the depth bookkeeping is guarded by a lock."""

    def __init__(self, label: str = ""):
        self.label = label
        self.stages: list[Stage] = []
        self._depth = 0
        self._lock = threading.Lock()
        self._start = perf_counter()
        self._reported = False

    @contextmanager
    def stage(self, name: str, note: str = ""):
        """Time the block, whether or not it raises."""
        with self._lock:
            depth = self._depth
            self._depth += 1
        entry = Stage(name, depth, note)
        self.stages.append(entry)
        begin = perf_counter()
        try:
            yield entry
        except BaseException:
            entry.failed = True
            raise
        finally:
            entry.seconds = perf_counter() - begin
            with self._lock:
                self._depth -= 1

    def note(self, name: str, text: str) -> None:
        """Attach a detail to an already-finished stage — the transcript, the
        model used, the byte count. Last stage with that name wins."""
        for entry in reversed(self.stages):
            if entry.name == name:
                entry.note = text
                return

    @property
    def total(self) -> float:
        return perf_counter() - self._start

    def report(self, extra: Optional[str] = None) -> None:
        """Print the table. Safe to call more than once — only the first call
        prints, so the endpoint can report in a finally block to cover the
        paths that raise, without the normal path printing twice."""
        if not ENABLED or self._reported:
            return
        self._reported = True

        total = self.total
        # Only outermost stages, so nested stages don't count twice.
        accounted = sum(s.seconds for s in self.stages if s.depth == 0)

        # Widen for the [FAILED] marker too, or a failed stage's name runs
        # into the seconds column and the table stops lining up.
        width = max(
            [len(s.name) + s.depth * 2 + (9 if s.failed else 0) for s in self.stages]
            + [12]
        )
        # ASCII only: this goes through logging to a Windows console, where
        # a box-drawing character comes out as an escape sequence.
        header = f"--- latency {self.label} ".ljust(width + 18, "-")
        lines = [header, f"{'stage'.ljust(width)}   secs     %"]

        for s in self.stages:
            share = (s.seconds / total * 100) if total > 0 else 0.0
            name = ("  " * s.depth) + s.name + ("  [FAILED]" if s.failed else "")
            line = f"{name.ljust(width)} {s.seconds:6.2f}  {share:5.1f}%"
            if s.note:
                line += f"   {s.note}"
            lines.append(line)

        # The gap is real work that no stage wrapped: reading the upload,
        # writing files, JSON handling, FastAPI's own overhead.
        other = total - accounted
        if abs(other) > 0.005:
            share = (other / total * 100) if total > 0 else 0.0
            lines.append(f"{'(unmeasured)'.ljust(width)} {other:6.2f}  {share:5.1f}%")

        lines.append(f"{'TOTAL'.ljust(width)} {total:6.2f}  100.0%")
        if extra:
            lines.append(extra)

        logger.info("\n".join(lines))
