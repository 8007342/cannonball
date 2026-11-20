//! Pure deterministic port of Cannonball's reactive traffic (lib/game/traffic.dart)
//! plus the racer observation encoder, safety mask and rule fallback.
//!
//! `Scene`, `encode`, `mask` and `rule_action` are the shared contract with
//! lib/game/traffic_policy/racer_observation.dart and must stay bit-identical
//! (same f64 operations in the same order). Bundle fixtures check this in Dart.
//! The follower/NPC model is a faithful but simplified port: no flinch/panic
//! reactions and no secondary incidents, which only matter near the player.
use crate::rng::Rng;
use serde::Serialize;

pub const LANES: [f64; 3] = [-0.65, 0.0, 0.65];
pub const SCALE: f64 = 0.52; // RouteGraph.speedScale
pub const OBS: usize = 24;
pub const N_ACTIONS: usize = 5;
pub const ACTIONS: [&str; N_ACTIONS] = ["keep", "left", "right", "brake", "accelerate"];
pub const KEEP: usize = 0;
pub const LEFT: usize = 1;
pub const RIGHT: usize = 2;
pub const BRAKE: usize = 3;
pub const ACCEL: usize = 4;
pub const DT: f64 = 1.0 / 30.0;
pub const DECISION_STEPS: usize = 6; // 0.2 s decision tick
pub const RACER_LATERAL_RATE: f64 = 1.1; // lane units per second
pub const OBSERVATION_SCHEMA: &str = "cannonball-racer-obs-v1";

#[derive(Clone, Debug, Serialize)]
pub struct Other {
    pub z: f64,
    pub x: f64,
    pub speed: f64,
    pub target: Option<f64>,
}

/// Everything a racer may observe at a decision tick (no privileged future).
#[derive(Clone, Debug, Serialize)]
pub struct Scene {
    pub z: f64,
    pub x: f64,
    pub lane_center: f64,
    pub speed: f64,
    pub cruise: f64,
    pub changing: bool,
    pub others: Vec<Other>,
    pub player_z: f64,
    pub player_x: f64,
    pub player_speed: f64,
    pub closed_lane: Option<usize>,
    pub closure_start: f64,
    pub closure_end: f64,
    pub curve: f64,
}

fn max0(v: f64) -> f64 {
    if v > 0.0 {
        v
    } else {
        0.0
    }
}

fn clamp1(v: f64) -> f64 {
    v.clamp(-1.0, 1.0)
}

pub fn nearest_lane(center: f64) -> usize {
    let mut best = 0;
    for i in 1..3 {
        if (LANES[i] - center).abs() < (LANES[best] - center).abs() {
            best = i;
        }
    }
    best
}

pub fn near_closure(s: &Scene) -> bool {
    s.closed_lane.is_some() && s.z > s.closure_start - 400.0 && s.z < s.closure_end + 100.0
}

fn lane_closed(s: &Scene, lane: usize) -> bool {
    near_closure(s) && s.closed_lane == Some(lane)
}

/// (ahead gap, ahead speed, behind distance, behind speed) for one lane.
pub fn neighbors(s: &Scene, lane: usize) -> (Option<f64>, f64, Option<f64>, f64) {
    let lx = LANES[lane];
    let (mut ag, mut asp, mut bg, mut bsp) = (None::<f64>, 0.0, None::<f64>, 0.0);
    let mut visit = |z: f64, speed: f64| {
        let gap = z - s.z;
        if gap >= 0.0 {
            if ag.map_or(true, |g| gap < g) {
                ag = Some(gap);
                asp = speed;
            }
        } else if bg.map_or(true, |g| -gap < g) {
            bg = Some(-gap);
            bsp = speed;
        }
    };
    for o in &s.others {
        if (o.x - lx).abs() < 0.33 {
            visit(o.z, o.speed);
        }
    }
    if (s.player_x - lx).abs() < 0.36 {
        visit(s.player_z, s.player_speed);
    }
    (ag, asp, bg, bsp)
}

pub fn encode(s: &Scene) -> [f64; OBS] {
    let mut o = [0.0; OBS];
    let lane = nearest_lane(s.lane_center);
    o[lane] = 1.0;
    o[3] = s.speed / 160.0;
    o[4] = clamp1((s.cruise - s.speed) / 60.0);
    for i in 0..3 {
        let (ag, asp, bg, bsp) = neighbors(s, i);
        let b = 5 + i * 5;
        o[b] = ag.map_or(1.0, |g| (g / 300.0).min(1.0));
        o[b + 1] = ag.map_or(0.0, |_| clamp1((asp - s.speed) / 60.0));
        o[b + 2] = bg.map_or(1.0, |g| (g / 300.0).min(1.0));
        o[b + 3] = bg.map_or(0.0, |_| clamp1((bsp - s.speed) / 60.0));
        o[b + 4] = if lane_closed(s, i) { 1.0 } else { 0.0 };
    }
    o[20] = clamp1((s.player_z - s.z) / 300.0);
    o[21] = clamp1((s.player_x - s.x) / 1.3);
    o[22] = clamp1((s.player_speed - s.speed) / 60.0);
    o[23] = clamp1(s.curve);
    o
}

/// Tighter-than-ordinary but still safe merge margins for racers.
pub fn gap_clear(s: &Scene, lane: usize) -> bool {
    let lx = LANES[lane];
    for o in &s.others {
        let merging = o.target.map_or(false, |t| (t - lx).abs() < 0.05);
        if (o.x - lx).abs() >= 0.33 && !merging {
            continue;
        }
        let gap = o.z - s.z;
        let required = if gap >= 0.0 {
            30.0 + max0(s.speed - o.speed) * 0.9
        } else {
            22.0 + max0(o.speed - s.speed) * 0.9
        };
        if gap.abs() < required {
            return false;
        }
    }
    if (s.player_x - lx).abs() < 0.40 {
        let gap = s.player_z - s.z;
        let required = if gap >= 0.0 {
            55.0 + max0(s.speed - s.player_speed) * 1.2
        } else {
            45.0 + max0(s.player_speed - s.speed) * 1.2
        };
        if gap.abs() < required {
            return false;
        }
    }
    true
}

pub fn mask(s: &Scene) -> [bool; N_ACTIONS] {
    let lane = nearest_lane(s.lane_center);
    let mut m = [true, false, false, true, false];
    if !s.changing {
        m[LEFT] = lane > 0 && !lane_closed(s, lane - 1) && gap_clear(s, lane - 1);
        m[RIGHT] = lane < 2 && !lane_closed(s, lane + 1) && gap_clear(s, lane + 1);
    }
    let (ag, asp, _, _) = neighbors(s, lane);
    let room = ag.map_or(true, |g| g > 45.0 + max0(s.speed - asp) * 1.2);
    m[ACCEL] = room && !(lane_closed(s, lane) && s.z > s.closure_start - 150.0);
    m
}

/// Deterministic rule-based fallback (used when no compatible bundle loads).
pub fn rule_action(s: &Scene, m: &[bool; N_ACTIONS]) -> usize {
    let lane = nearest_lane(s.lane_center);
    let (ag, asp, _, _) = neighbors(s, lane);
    let in_closed = lane_closed(s, lane);
    let closing = ag.map_or(0.0, |_| max0(s.speed - asp));
    let blocked = ag.map_or(false, |g| g < 70.0 + closing * 1.5 && asp < s.speed - 3.0);
    if in_closed || blocked {
        let mut best: Option<usize> = None;
        let mut best_room = if in_closed {
            -1.0
        } else {
            ag.unwrap_or(1e9) + 40.0
        };
        for (action, ok) in [(LEFT, lane > 0), (RIGHT, lane < 2)] {
            if !ok || !m[action] {
                continue;
            }
            let target = if action == LEFT { lane - 1 } else { lane + 1 };
            let room = neighbors(s, target).0.unwrap_or(600.0);
            if room > best_room {
                best = Some(action);
                best_room = room;
            }
        }
        if let Some(a) = best {
            return a;
        }
        if ag.map_or(false, |g| g < 40.0 + closing * 1.2)
            || (in_closed && s.z > s.closure_start - 250.0)
        {
            return BRAKE;
        }
        return KEEP;
    }
    if m[ACCEL] && s.speed < s.cruise - 2.0 {
        return ACCEL;
    }
    KEEP
}

// ---------------------------------------------------------------- world ----

#[derive(Clone)]
pub struct Npc {
    pub id: usize,
    pub z: f64,
    pub lc: f64,
    pub target: Option<f64>,
    pub signal: f64,
    pub speed: f64,
    pub cruise: f64,
    pub headway: f64,
    pub change_at: f64,
}

#[derive(Clone)]
pub struct Racer {
    pub z: f64,
    pub lc: f64,
    pub target: Option<f64>,
    pub from: f64,
    pub speed: f64,
    pub cruise: f64,
    pub cap: f64,
    pub desired: f64,
}

#[derive(Clone)]
pub struct Player {
    pub z: f64,
    pub x: f64,
    pub speed: f64,
    pub target: Option<f64>,
    pub next_change: f64,
}

#[derive(Clone)]
pub struct World {
    pub racer: Racer,
    pub npcs: Vec<Npc>,
    pub player: Player,
    pub closed: Option<usize>,
    pub cs: f64,
    pub ce: f64,
    pub curve: f64,
    pub time: f64,
    pub rng: Rng,
}

#[derive(Clone, Copy, Default)]
pub struct StepEvents {
    pub npc_contacts: u32,
    pub player_contacts: u32,
    pub racer_fault_player_contacts: u32,
    pub closure_violation: bool,
    pub tight: f64,
    pub hard_brake: bool,
}

#[derive(Clone, Copy)]
struct Snap {
    z: f64,
    x: f64,
    speed: f64,
    target: Option<f64>,
}

pub fn npc_cruise(rng: &mut Rng) -> (f64, f64) {
    // (cruise mph-ish, headway) — wide variety: trucks to brisk drivers.
    let r = rng.unit();
    if r < 0.15 {
        (55.0 + rng.unit() * 17.0, 2.1)
    } else if r < 0.35 {
        (58.0 + rng.unit() * 22.0, 2.1)
    } else if r < 0.80 {
        (66.0 + rng.unit() * 32.0, 1.4)
    } else if r < 0.93 {
        (88.0 + rng.unit() * 27.0, 1.4)
    } else {
        (82.0 + rng.unit() * 26.0, 0.9)
    }
}

impl World {
    pub fn new(rng: &mut Rng) -> World {
        let top = 136.0 + rng.unit() * 34.0;
        let cruise = top * (0.88 + rng.unit() * 0.09);
        let lane = LANES[rng.below(3)];
        let racer = Racer {
            z: 0.0,
            lc: lane,
            target: None,
            from: lane,
            speed: cruise * (0.7 + rng.unit() * 0.3),
            cruise,
            cap: top,
            desired: cruise,
        };
        let mut w = World {
            racer,
            npcs: Vec::new(),
            player: Player {
                z: -250.0 + rng.unit() * 650.0,
                x: LANES[rng.below(3)],
                speed: 95.0 + rng.unit() * 70.0,
                target: None,
                next_change: 2.0 + rng.unit() * 4.0,
            },
            closed: None,
            cs: 0.0,
            ce: 0.0,
            curve: (rng.unit() - 0.5) * 1.2,
            time: 0.0,
            rng: Rng(rng.next()),
        };
        if w.rng.unit() < 0.35 {
            w.closed = Some(w.rng.below(3));
            w.cs = 300.0 + w.rng.unit() * 900.0;
            w.ce = w.cs + 600.0;
        }
        let count = 7 + w.rng.below(8);
        let mut tries = 0;
        while w.npcs.len() < count && tries < 200 {
            tries += 1;
            let z = -300.0 + w.rng.unit() * 1400.0;
            let lane = w.rng.below(3);
            if w.closed == Some(lane) && z > w.cs - 200.0 && z < w.ce + 100.0 {
                continue;
            }
            if !w.spot_free(z, LANES[lane]) {
                continue;
            }
            let id = w.npcs.len();
            let (cruise, headway) = npc_cruise(&mut w.rng);
            let change_at = w.rng.unit() * 5.0;
            w.npcs.push(Npc {
                id,
                z,
                lc: LANES[lane],
                target: None,
                signal: 0.0,
                speed: cruise,
                cruise,
                headway,
                change_at,
            });
        }
        w
    }

    fn spot_free(&self, z: f64, lane: f64) -> bool {
        if (self.racer.z - z).abs() < 60.0 && (self.racer.lc - lane).abs() < 0.3 {
            return false;
        }
        self.npcs
            .iter()
            .all(|n| (n.z - z).abs() > 60.0 || (n.lc - lane).abs() > 0.3)
    }

    pub fn scene(&self) -> Scene {
        let r = &self.racer;
        Scene {
            z: r.z,
            x: r.lc,
            lane_center: r.lc,
            speed: r.speed,
            cruise: r.cruise,
            changing: r.target.is_some(),
            others: self
                .npcs
                .iter()
                .map(|n| Other {
                    z: n.z,
                    x: n.lc,
                    speed: n.speed,
                    target: n.target,
                })
                .collect(),
            player_z: self.player.z,
            player_x: self.player.x,
            player_speed: self.player.speed,
            closed_lane: self.closed,
            closure_start: if self.closed.is_some() { self.cs } else { 0.0 },
            closure_end: if self.closed.is_some() { self.ce } else { 0.0 },
            curve: self.curve,
        }
    }

    /// Applies one decision; the caller guarantees `action` passed the mask.
    pub fn apply(&mut self, action: usize) {
        let r = &mut self.racer;
        let lane = nearest_lane(r.lc);
        r.desired = r.cruise;
        match action {
            LEFT | RIGHT if r.target.is_none() => {
                let to = if action == LEFT { lane - 1 } else { lane + 1 };
                r.from = LANES[lane];
                r.target = Some(LANES[to]);
            }
            ACCEL => r.desired = (r.cruise + 6.0).min(r.cap),
            BRAKE => r.desired = max0(r.speed - 12.0),
            _ => {}
        }
    }

    fn snapshot(&self) -> (Vec<Snap>, Snap) {
        let npcs = self
            .npcs
            .iter()
            .map(|n| Snap {
                z: n.z,
                x: n.lc,
                speed: n.speed,
                target: n.target,
            })
            .collect();
        let r = &self.racer;
        (
            npcs,
            Snap {
                z: r.z,
                x: r.lc,
                speed: r.speed,
                target: r.target,
            },
        )
    }

    fn closure_near(&self, z: f64) -> bool {
        self.closed.is_some() && z > self.cs - 400.0 && z < self.ce + 100.0
    }

    pub fn step(&mut self) -> StepEvents {
        let mut ev = StepEvents::default();
        let (snaps, rs) = self.snapshot();
        let p = self.player.clone();
        let time = self.time;
        // ---- racer
        {
            let scene = {
                let mut s = self.scene();
                s.others = snaps
                    .iter()
                    .map(|n| Other {
                        z: n.z,
                        x: n.x,
                        speed: n.speed,
                        target: n.target,
                    })
                    .collect();
                s
            };
            let r = &mut self.racer;
            let desired = r.desired;
            let mut accel = ((desired - r.speed) * 0.9).clamp(-20.0, 18.0);
            let (mut gap, mut lspeed) = (f64::INFINITY, desired);
            for n in &snaps {
                if (n.x - r.lc).abs() > 0.31 {
                    continue;
                }
                let g = n.z - r.z;
                if g > 0.0 && g < gap {
                    gap = g;
                    lspeed = n.speed;
                }
            }
            if p.z > r.z && (p.x - r.lc).abs() < 0.32 && p.z - r.z < gap {
                gap = p.z - r.z;
                lspeed = p.speed;
            }
            if gap < 18.0 {
                ev.tight = 18.0 - gap;
            }
            let dg = 25.0 + r.speed * SCALE * 0.6;
            if gap < dg * 1.6 {
                accel = accel.min((gap - dg) * 0.17 - (r.speed - lspeed) * 1.1);
            }
            let near = self.closed.is_some() && r.z > self.cs - 400.0 && r.z < self.ce + 100.0;
            let blocked = near && (r.lc - LANES[self.closed.unwrap()]).abs() < 0.28;
            if blocked && r.z >= self.cs - dg {
                accel = accel.min(-25.0);
            }
            if let Some(t) = r.target {
                let progress = (r.lc - r.from).abs() / (t - r.from).abs();
                if progress < 0.5 && !gap_clear(&scene, nearest_lane(t)) {
                    r.target = Some(r.from);
                    r.from = t;
                }
            }
            if let Some(t) = r.target {
                let d = t - r.lc;
                r.lc += d.signum() * d.abs().min(DT * RACER_LATERAL_RATE);
                if (r.lc - t).abs() < 0.005 {
                    r.lc = t;
                    r.target = None;
                }
            }
            accel = accel.clamp(-58.0, 18.0);
            ev.hard_brake = accel < -30.0;
            let prev = r.z;
            r.speed = (r.speed + accel * DT).clamp(0.0, desired.max(r.cruise) + 5.0);
            r.z += r.speed * SCALE * DT;
            if blocked && r.z >= self.cs - 20.0 {
                r.z = prev.max(self.cs - 20.0);
                r.speed = 0.0;
            }
            if let Some(c) = self.closed {
                if (r.lc - LANES[c]).abs() < 0.2 && r.z > self.cs && r.z < self.ce {
                    ev.closure_violation = true;
                }
            }
        }
        // ---- npcs (port of the ordinary/cautious/pushy follower law)
        for i in 0..self.npcs.len() {
            let me = snaps[i];
            let near = self.closure_near(me.z);
            let closed_x = self.closed.map(|c| LANES[c]);
            let n = &mut self.npcs[i];
            let desired = n.cruise;
            let mut accel = ((desired - me.speed) * 0.9).clamp(-20.0, 9.0);
            let (mut gap, mut lspeed) = (f64::INFINITY, desired);
            let mut consider = |z: f64, x: f64, speed: f64, wide: f64| {
                if (x - me.x).abs() > wide {
                    return;
                }
                let g = z - me.z;
                if g > 0.0 && g < gap {
                    gap = g;
                    lspeed = speed;
                }
            };
            for (j, o) in snaps.iter().enumerate() {
                if j != i {
                    consider(o.z, o.x, o.speed, 0.31);
                }
            }
            consider(rs.z, rs.x, rs.speed, 0.31);
            if p.z > me.z && (p.x - me.x).abs() < 0.32 {
                consider(p.z, p.x, p.speed, 1.0);
            }
            let dg = 25.0 + me.speed * SCALE * n.headway;
            if gap < dg * 1.6 {
                accel = accel.min((gap - dg) * 0.17 - (me.speed - lspeed) * 1.1);
            }
            let blocked = near && (n.lc - closed_x.unwrap_or(9.0)).abs() < 0.28;
            if time >= n.change_at && n.target.is_none() {
                let needs = gap < dg * 1.4 && lspeed < desired - 5.0;
                if blocked || needs {
                    let mut best = None;
                    let mut best_room = gap;
                    for lane in LANES {
                        let d = (lane - n.lc).abs();
                        if d > 0.7 || d < 0.3 {
                            continue;
                        }
                        if near && (lane - closed_x.unwrap_or(9.0)).abs() < 0.25 {
                            continue;
                        }
                        if !npc_lane_clear(i, &me, lane, &snaps, &rs, &p) {
                            continue;
                        }
                        let mut room: f64 = 700.0;
                        for (j, o) in snaps.iter().enumerate() {
                            if j != i && (o.x - lane).abs() < 0.3 && o.z > me.z {
                                room = room.min(o.z - me.z);
                            }
                        }
                        if (rs.x - lane).abs() < 0.3 && rs.z > me.z {
                            room = room.min(rs.z - me.z);
                        }
                        if blocked || room > best_room + 60.0 {
                            best = Some(lane);
                            best_room = room;
                        }
                    }
                    if best.is_some() {
                        n.target = best;
                        n.signal = 0.0;
                    }
                }
                n.change_at = time + 3.0 + (n.id % 7) as f64 * 0.35;
            }
            if let Some(t) = n.target {
                n.signal += DT;
                if n.signal >= 1.25 && npc_lane_clear(i, &me, t, &snaps, &rs, &p) {
                    let d = t - n.lc;
                    n.lc += d.signum() * d.abs().min(DT * 0.26);
                    if (n.lc - t).abs() < 0.005 {
                        n.lc = t;
                        n.target = None;
                        n.change_at = time + 5.0;
                    }
                }
            }
            if blocked && me.z >= self.cs - dg {
                accel = accel.min(-25.0);
            }
            accel = accel.clamp(-58.0, 10.0);
            n.speed = (me.speed + accel * DT).clamp(0.0, desired + 5.0);
            n.z += n.speed * SCALE * DT;
            if blocked && n.z >= self.cs - 20.0 {
                n.z = me.z.max(self.cs - 20.0);
                n.speed = 0.0;
            }
        }
        // ---- scripted player: holds speed, changes lanes without courtesy
        {
            let pl = &mut self.player;
            if time >= pl.next_change && pl.target.is_none() {
                let lane = nearest_lane(pl.x);
                let to = if lane == 0 {
                    1
                } else if lane == 2 {
                    1
                } else if self.rng.unit() < 0.5 {
                    0
                } else {
                    2
                };
                pl.target = Some(LANES[to]);
                pl.next_change = time + 3.0 + self.rng.unit() * 5.0;
            }
            if let Some(t) = pl.target {
                let d = t - pl.x;
                pl.x += d.signum() * d.abs().min(DT * 1.4);
                if (pl.x - t).abs() < 0.005 {
                    pl.x = t;
                    pl.target = None;
                }
            }
            pl.z += pl.speed * SCALE * DT;
        }
        self.time += DT;
        // ---- contacts (edge-free count of overlapping pairs this step)
        let r = &self.racer;
        for n in &self.npcs {
            if (n.z - r.z).abs() < 12.0 && (n.lc - r.lc).abs() < 0.22 {
                ev.npc_contacts += 1;
            }
        }
        if (self.player.z - r.z).abs() < 24.0 && (self.player.x - r.lc).abs() < 0.22 {
            ev.player_contacts += 1;
            // The scripted player never brakes or yields; only count contacts a
            // racer could have caused (closing from behind or moving laterally).
            let cut_in = self.player.target.is_some();
            if r.target.is_some() || (r.z < self.player.z && !cut_in) {
                ev.racer_fault_player_contacts += 1;
            }
        }
        ev
    }

    /// Keeps the episode populated around the racer (training only).
    pub fn recycle(&mut self) {
        let rz = self.racer.z;
        for i in 0..self.npcs.len() {
            let z = self.npcs[i].z;
            if z > rz - 350.0 && z < rz + 1300.0 {
                continue;
            }
            let ahead = z <= rz - 350.0;
            let nz = if ahead {
                rz + 700.0 + self.rng.unit() * 400.0
            } else {
                rz - 320.0
            };
            let lane = self.rng.below(3);
            if self.closed == Some(lane) && nz > self.cs - 200.0 && nz < self.ce + 100.0 {
                continue;
            }
            let others_free = self.npcs.iter().enumerate().all(|(j, n)| {
                j == i || (n.z - nz).abs() > 70.0 || (n.lc - LANES[lane]).abs() > 0.3
            });
            if !others_free {
                continue;
            }
            let (cruise, headway) = npc_cruise(&mut self.rng);
            let n = &mut self.npcs[i];
            n.z = nz;
            n.lc = LANES[lane];
            n.target = None;
            n.cruise = cruise;
            n.speed = cruise;
            n.headway = headway;
        }
        if (self.player.z - rz).abs() > 700.0 {
            self.player.z = rz - 250.0 + self.rng.unit() * 650.0;
            self.player.speed = 95.0 + self.rng.unit() * 70.0;
        }
        if self.closed.is_some() && rz > self.ce + 200.0 {
            self.closed = None;
        }
        if self.closed.is_none() && self.rng.unit() < 0.004 {
            self.closed = Some(self.rng.below(3));
            self.cs = rz + 600.0 + self.rng.unit() * 900.0;
            self.ce = self.cs + 600.0;
        }
        if self.rng.unit() < 0.01 {
            self.curve = (self.rng.unit() - 0.5) * 1.2;
        }
    }
}

fn npc_lane_clear(i: usize, me: &Snap, lane: f64, snaps: &[Snap], rs: &Snap, p: &Player) -> bool {
    let check = |o: &Snap| -> bool {
        let merging = o.target.map_or(false, |t| (t - lane).abs() < 0.05);
        if (o.x - lane).abs() > 0.33 && !merging {
            return true;
        }
        let gap = o.z - me.z;
        let required = if gap < 0.0 {
            45.0 + max0(o.speed - me.speed) * 2.0
        } else {
            70.0 + max0(me.speed - o.speed) * 2.0
        };
        gap.abs() >= required
    };
    for (j, o) in snaps.iter().enumerate() {
        if j != i && !check(o) {
            return false;
        }
    }
    if !check(rs) {
        return false;
    }
    !((p.x - lane).abs() < 0.36 && (p.z - me.z).abs() < 170.0 + max0(p.speed - me.speed))
}

/// Short lookahead rollout score for one candidate action.
pub fn rollout_score(world: &World, action: usize, horizon: usize) -> f64 {
    let mut w = world.clone();
    let z0 = w.racer.z;
    // No reward beyond the racer's own cruise: it is fast, not a top-speed bot.
    let cap = w.racer.cruise * SCALE * DT * horizon as f64;
    w.apply(action);
    let mut score = 0.0;
    let mut hit_npc = false;
    let mut hit_player = false;
    let mut closure = false;
    for step in 0..horizon {
        if step == DECISION_STEPS {
            w.racer.desired = w.racer.cruise;
        }
        let ev = w.step();
        if ev.npc_contacts > 0 {
            hit_npc = true;
        }
        if ev.player_contacts > 0 {
            hit_player = true;
        }
        if ev.closure_violation {
            closure = true;
        }
        score -= ev.tight * 1.5;
        if ev.hard_brake {
            score -= 0.4;
        }
    }
    score += (w.racer.z - z0).min(cap);
    if hit_npc {
        score -= 400.0;
    }
    if hit_player {
        score -= 600.0;
    }
    if closure {
        score -= 400.0;
    }
    score
        - match action {
            LEFT | RIGHT => 6.0,
            BRAKE => 1.0,
            _ => 0.0,
        }
}

/// Lookahead teacher: best allowed action; earlier index wins near-ties.
pub fn teacher(world: &World, m: &[bool; N_ACTIONS]) -> usize {
    let mut best = KEEP;
    let mut best_score = f64::NEG_INFINITY;
    for a in 0..N_ACTIONS {
        if !m[a] {
            continue;
        }
        let s = rollout_score(world, a, 90);
        if s > best_score + 0.5 {
            best = a;
            best_score = s;
        }
    }
    best
}
