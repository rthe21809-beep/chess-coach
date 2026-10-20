// Minimal Web Audio SFX for moves, captures, check, castles, game end.
// Lazily creates one AudioContext (browsers require a user gesture first).

let ctx: AudioContext | null = null;

function audio(): AudioContext | null {
  if (typeof window === "undefined") return null;
  if (!ctx) {
    const AC =
      window.AudioContext ||
      (window as unknown as { webkitAudioContext?: typeof AudioContext }).webkitAudioContext;
    if (!AC) return null;
    ctx = new AC();
  }
  if (ctx.state === "suspended") void ctx.resume();
  return ctx;
}

function tone(
  freq: number,
  durMs: number,
  volume: number,
  type: OscillatorType = "triangle"
) {
  const c = audio();
  if (!c) return;
  const osc = c.createOscillator();
  const gain = c.createGain();
  osc.type = type;
  osc.frequency.value = freq;
  gain.gain.setValueAtTime(volume, c.currentTime);
  gain.gain.exponentialRampToValueAtTime(0.0001, c.currentTime + durMs / 1000);
  osc.connect(gain);
  gain.connect(c.destination);
  osc.start();
  osc.stop(c.currentTime + durMs / 1000 + 0.02);
}

export function playMove(volume = 0.35) {
  tone(320, 70, volume);
}
export function playCapture(volume = 0.35) {
  tone(220, 90, volume, "square");
}
export function playCheck(volume = 0.35) {
  tone(660, 90, volume);
  setTimeout(() => tone(880, 100, volume), 60);
}
export function playCastle(volume = 0.35) {
  tone(440, 60, volume);
  setTimeout(() => tone(520, 60, volume), 60);
}
export function playGameEnd(volume = 0.35) {
  tone(440, 200, volume);
  setTimeout(() => tone(330, 250, volume), 200);
}
export function playPromote(volume = 0.35) {
  tone(660, 120, volume);
  setTimeout(() => tone(880, 140, volume), 100);
}

export function playForMove(
  opts: {
    capture?: boolean;
    check?: boolean;
    castle?: boolean;
    promote?: boolean;
    end?: boolean;
  },
  volume: number
) {
  if (opts.end) return playGameEnd(volume);
  if (opts.promote) return playPromote(volume);
  if (opts.castle) return playCastle(volume);
  if (opts.check) return playCheck(volume);
  if (opts.capture) return playCapture(volume);
  playMove(volume);
}
