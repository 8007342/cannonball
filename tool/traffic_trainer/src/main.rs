//! Cannonball racer lane-change classifier trainer (local CPU, single process).
//!
//! 1. Generates seeded episodes from a pure port of the reactive traffic sim
//!    (sim.rs). Worker threads each own whole episodes; results are merged in
//!    episode order, so the dataset is independent of thread count.
//! 2. Labels each 0.2 s racer decision with the best *safety-masked* action
//!    from short (3 s) lookahead rollouts of every candidate action.
//! 3. Trains a tiny MLP with masked cross-entropy (fixed-order chunk gradients).
//! 4. Exports a versioned JSON bundle (base64 float32 LE weights + SHA-256,
//!    schemas, metrics and parity fixtures) for lib/game/traffic_policy.
mod mlp;
mod rng;
mod sim;

use base64::Engine;
use mlp::{masked_argmax, reference_forward, Adam, Mlp};
use rng::Rng;
use sha2::{Digest, Sha256};
use sim::*;
use std::time::Instant;

const GRAD_CHUNKS: usize = 8;

#[derive(Clone, Copy, PartialEq)]
enum Driver {
    Teacher,
    Learned,
    Rules,
}

#[derive(Default, Clone, Copy)]
struct Metrics {
    seconds: f64,
    speed_sum: f64,
    speed_n: f64,
    npc_contacts: u32,
    player_contacts: u32,
    fault_contacts: u32,
    lane_changes: u32,
    closure_steps: u32,
    passes_player: u32,
    decisions: u32,
}

impl Metrics {
    fn add(&mut self, o: &Metrics) {
        self.seconds += o.seconds;
        self.speed_sum += o.speed_sum;
        self.speed_n += o.speed_n;
        self.npc_contacts += o.npc_contacts;
        self.player_contacts += o.player_contacts;
        self.fault_contacts += o.fault_contacts;
        self.lane_changes += o.lane_changes;
        self.closure_steps += o.closure_steps;
        self.passes_player += o.passes_player;
        self.decisions += o.decisions;
    }
    fn json(&self) -> serde_json::Value {
        let min = self.seconds / 60.0;
        serde_json::json!({
            "minutes": round(min, 2),
            "meanSpeed": round(self.speed_sum / self.speed_n.max(1.0), 2),
            "npcContactsPerMin": round(self.npc_contacts as f64 / min, 4),
            "playerContactsPerMin": round(self.player_contacts as f64 / min, 4),
            "racerFaultPlayerContactsPerMin": round(self.fault_contacts as f64 / min, 4),
            "laneChangesPerMin": round(self.lane_changes as f64 / min, 3),
            "closureViolationSeconds": round(self.closure_steps as f64 * DT, 3),
            "playerPassesPerMin": round(self.passes_player as f64 / min, 3),
        })
    }
}

fn round(v: f64, d: i32) -> f64 {
    let p = 10f64.powi(d);
    (v * p).round() / p
}

struct Sample {
    obs: [f64; OBS],
    mask: u8,
    label: u8,
    rule: u8,
    scene: Option<Box<Scene>>,
}

struct Policy<'a> {
    sizes: &'a [usize],
    w: &'a [f32],
}

fn mix(seed: u64, i: u64) -> u64 {
    Rng(seed ^ i.wrapping_mul(0xD1B5_4A32_D192_ED03)).next()
}

fn mask_bits(m: &[bool; N_ACTIONS]) -> u8 {
    (0..N_ACTIONS).fold(0, |b, a| b | ((m[a] as u8) << a))
}

fn episode(
    seed: u64,
    driver: Driver,
    explore: f64,
    label: bool,
    keep_scene_every: usize,
    policy: Option<&Policy>,
) -> (Vec<Sample>, Metrics) {
    let mut rng = Rng(seed);
    let mut w = World::new(&mut rng);
    let mut samples = Vec::new();
    let mut met = Metrics::default();
    let (mut npc_prev, mut player_prev, mut fault_prev) = (false, false, false);
    let mut ahead_prev = w.racer.z > w.player.z;
    for d in 0..125 {
        let scene = w.scene();
        let m = mask(&scene);
        let obs = encode(&scene);
        let rule = rule_action(&scene, &m);
        let teacher_action = if label || driver == Driver::Teacher {
            teacher(&w, &m)
        } else {
            KEEP
        };
        let mut action = match driver {
            Driver::Teacher => teacher_action,
            Driver::Rules => rule,
            Driver::Learned => {
                let p = policy.unwrap();
                masked_argmax(&reference_forward(p.sizes, p.w, &obs), &m)
            }
        };
        if explore > 0.0 && rng.unit() < explore {
            let allowed: Vec<usize> = (0..N_ACTIONS).filter(|&a| m[a]).collect();
            action = allowed[rng.below(allowed.len())];
        }
        if label {
            samples.push(Sample {
                obs,
                mask: mask_bits(&m),
                label: teacher_action as u8,
                rule: rule as u8,
                scene: if keep_scene_every > 0 && d % keep_scene_every == 3 {
                    Some(Box::new(scene))
                } else {
                    None
                },
            });
        }
        if (action == LEFT || action == RIGHT) && w.racer.target.is_none() {
            met.lane_changes += 1;
        }
        w.apply(action);
        met.decisions += 1;
        for _ in 0..DECISION_STEPS {
            let ev = w.step();
            let npc = ev.npc_contacts > 0;
            let player = ev.player_contacts > 0;
            met.npc_contacts += (npc && !npc_prev) as u32;
            met.player_contacts += (player && !player_prev) as u32;
            npc_prev = npc;
            player_prev = player;
            let fault = ev.racer_fault_player_contacts > 0;
            met.fault_contacts += (fault && !fault_prev) as u32;
            fault_prev = fault;
            met.closure_steps += ev.closure_violation as u32;
            met.speed_sum += w.racer.speed;
            met.speed_n += 1.0;
            met.seconds += DT;
            let ahead = w.racer.z > w.player.z;
            met.passes_player += (ahead && !ahead_prev) as u32;
            ahead_prev = ahead;
        }
        w.recycle();
    }
    (samples, met)
}

fn run_many(
    seed: u64,
    count: usize,
    threads: usize,
    driver: Driver,
    explore: f64,
    label: bool,
    keep_scene_every: usize,
    policy: Option<&Policy>,
) -> (Vec<Sample>, Metrics) {
    let mut parts: Vec<(usize, Vec<Sample>, Metrics)> = Vec::new();
    std::thread::scope(|scope| {
        let handles: Vec<_> = (0..threads)
            .map(|t| {
                scope.spawn(move || {
                    let mut out = Vec::new();
                    let mut i = t;
                    while i < count {
                        let (s, m) = episode(
                            mix(seed, i as u64),
                            driver,
                            explore,
                            label,
                            keep_scene_every,
                            policy,
                        );
                        out.push((i, s, m));
                        i += threads;
                    }
                    out
                })
            })
            .collect();
        for h in handles {
            parts.extend(h.join().unwrap());
        }
    });
    parts.sort_by_key(|p| p.0);
    let mut all = Vec::new();
    let mut met = Metrics::default();
    for (_, s, m) in parts {
        all.extend(s);
        met.add(&m);
    }
    (all, met)
}

fn main() -> Result<(), Box<dyn std::error::Error>> {
    let args: Vec<String> = std::env::args().collect();
    let get = |k: &str, d: &str| -> String {
        args.iter()
            .rposition(|a| a == k)
            .and_then(|i| args.get(i + 1))
            .cloned()
            .unwrap_or(d.into())
    };
    let seed: u64 = get("--seed", "2026").parse()?;
    let train_eps: usize = get("--train-episodes", "6000").parse()?;
    let eval_eps: usize = get("--eval-episodes", "240").parse()?;
    let loop_eps: usize = get("--loop-episodes", "160").parse()?;
    let epochs: usize = get("--epochs", "18").parse()?;
    let batch: usize = get("--batch", "256").parse()?;
    let lr: f64 = get("--lr", "0.002").parse()?;
    let hidden: usize = get("--hidden", "32").parse()?;
    let default_threads = std::thread::available_parallelism()
        .map(|n| n.get())
        .unwrap_or(4)
        .min(12);
    let threads: usize = get("--threads", &default_threads.to_string()).parse()?;
    let out = get("--out", "../../assets/traffic/racer-policy.json");
    let total = Instant::now();

    let t0 = Instant::now();
    let (train, _) = run_many(
        seed,
        train_eps,
        threads,
        Driver::Teacher,
        0.12,
        true,
        0,
        None,
    );
    let (eval, _) = run_many(
        seed ^ 0x5EED_E7A1,
        eval_eps,
        threads,
        Driver::Teacher,
        0.12,
        true,
        29,
        None,
    );
    let gen_s = t0.elapsed().as_secs_f64();
    let mut class_counts = [0usize; N_ACTIONS];
    for s in &train {
        class_counts[s.label as usize] += 1;
    }
    eprintln!(
        "generated train={} eval={} in {:.1}s classes={:?}",
        train.len(),
        eval.len(),
        gen_s,
        class_counts
    );
    // Square-root inverse-frequency weights so rare lane changes are learned.
    let class_weight: [f64; N_ACTIONS] = std::array::from_fn(|c| {
        let f = class_counts[c].max(1) as f64 / train.len() as f64;
        (1.0 / (N_ACTIONS as f64 * f)).sqrt().clamp(0.5, 6.0)
    });

    let xs: Vec<f32> = train
        .iter()
        .flat_map(|s| s.obs.iter().map(|v| *v as f32))
        .collect();
    let ys: Vec<u8> = train.iter().map(|s| s.label).collect();
    let ms: Vec<u8> = train.iter().map(|s| s.mask).collect();
    let train_len = train.len();
    drop(train); // keep peak memory near the compact f32 training matrix
    let sizes = vec![OBS, hidden, hidden, N_ACTIONS];
    let mut rng = Rng(seed ^ 0xC0FFEE);
    let mut model = Mlp::new(sizes.clone(), &mut rng);
    let mut adam = Adam::new(model.param_count(), lr);
    let mut order: Vec<usize> = (0..ys.len()).collect();
    let t1 = Instant::now();
    let mut epoch_log = Vec::new();
    for epoch in 0..epochs {
        for k in (1..order.len()).rev() {
            order.swap(k, rng.below(k + 1));
        }
        if epoch == epochs * 2 / 3 {
            adam.lr *= 0.3;
        }
        let (mut loss, mut correct) = (0.0, 0usize);
        for chunk in order.chunks(batch) {
            let parts = chunk.len().div_ceil(GRAD_CHUNKS);
            let grads: Vec<(Vec<f64>, f64, usize)> = std::thread::scope(|scope| {
                let hs: Vec<_> = chunk
                    .chunks(parts)
                    .map(|idx| {
                        let model = &model;
                        let (xs, ys, ms, cw) = (&xs, &ys, &ms, &class_weight);
                        scope.spawn(move || {
                            let mut g = vec![0.0; model.param_count()];
                            let (l, c) = model.grad(xs, ys, ms, cw, idx, &mut g);
                            (g, l, c)
                        })
                    })
                    .collect();
                hs.into_iter().map(|h| h.join().unwrap()).collect()
            });
            let mut g = vec![0.0; model.param_count()];
            for (part, l, c) in grads {
                for k in 0..g.len() {
                    g[k] += part[k];
                }
                loss += l;
                correct += c;
            }
            adam.step(&mut model.params, &g, 1.0 / chunk.len() as f64);
        }
        let n = ys.len() as f64;
        eprintln!(
            "epoch {epoch} loss {:.4} train_acc {:.4}",
            loss / n,
            correct as f64 / n
        );
        epoch_log.push(serde_json::json!({"epoch": epoch, "loss": round(loss / n, 5), "trainAccuracy": round(correct as f64 / n, 5)}));
    }
    let train_s = t1.elapsed().as_secs_f64();

    // Export float32 weights, then evaluate exactly what ships.
    let w32: Vec<f32> = model.params.iter().map(|v| *v as f32).collect();
    let bytes: Vec<u8> = w32.iter().flat_map(|f| f.to_le_bytes()).collect();
    let sha = format!("{:x}", Sha256::digest(&bytes));
    let policy = Policy {
        sizes: &sizes,
        w: &w32,
    };
    let mut confusion = [[0usize; N_ACTIONS]; N_ACTIONS];
    let (mut agree, mut rule_agree, mut lane_total, mut lane_hit) =
        (0usize, 0usize, 0usize, 0usize);
    for s in &eval {
        let m: [bool; N_ACTIONS] = std::array::from_fn(|a| s.mask & (1 << a) != 0);
        let pred = masked_argmax(&reference_forward(&sizes, &w32, &s.obs), &m);
        confusion[s.label as usize][pred] += 1;
        agree += (pred == s.label as usize) as usize;
        rule_agree += (s.rule == s.label) as usize;
        if s.label as usize == LEFT || s.label as usize == RIGHT {
            lane_total += 1;
            lane_hit += (pred == s.label as usize) as usize;
        }
    }
    let acc = agree as f64 / eval.len() as f64;
    let rule_acc = rule_agree as f64 / eval.len() as f64;
    eprintln!(
        "heldout acc {:.4} (rules {:.4}) lane-change recall {:.4}",
        acc,
        rule_acc,
        lane_hit as f64 / lane_total.max(1) as f64
    );

    // Inference throughput: encode + mask + forward over held-out scenes.
    let scenes: Vec<&Scene> = eval.iter().filter_map(|s| s.scene.as_deref()).collect();
    let t2 = Instant::now();
    let mut decisions = 0usize;
    let mut sink = 0usize;
    while t2.elapsed().as_secs_f64() < 1.0 {
        for sc in &scenes {
            let m = mask(sc);
            sink += masked_argmax(&reference_forward(&sizes, &w32, &encode(sc)), &m);
            decisions += 1;
        }
    }
    let dps = decisions as f64 / t2.elapsed().as_secs_f64();
    eprintln!("rust decisions/s (1 thread) {:.0} [{}]", dps, sink % 2);

    // Closed-loop comparison on unseen seeds.
    let t3 = Instant::now();
    let loop_seed = seed ^ 0xA11_C105ED;
    let (_, teacher_m) = run_many(
        loop_seed,
        loop_eps,
        threads,
        Driver::Teacher,
        0.0,
        false,
        0,
        None,
    );
    let (_, learned_m) = run_many(
        loop_seed,
        loop_eps,
        threads,
        Driver::Learned,
        0.0,
        false,
        0,
        Some(&policy),
    );
    let (_, rules_m) = run_many(
        loop_seed,
        loop_eps,
        threads,
        Driver::Rules,
        0.0,
        false,
        0,
        None,
    );
    let loop_s = t3.elapsed().as_secs_f64();
    eprintln!(
        "closed loop teacher {}\nlearned {}\nrules {}",
        teacher_m.json(),
        learned_m.json(),
        rules_m.json()
    );

    // Parity fixtures: one or more per action where available.
    let mut fixtures = Vec::new();
    let mut per_action = [0usize; N_ACTIONS];
    for s in &eval {
        let Some(sc) = &s.scene else { continue };
        let m = mask(sc);
        let logits = reference_forward(&sizes, &w32, &s.obs);
        let pred = masked_argmax(&logits, &m);
        if per_action[pred] >= 3 || fixtures.len() >= 14 {
            continue;
        }
        per_action[pred] += 1;
        fixtures.push(serde_json::json!({
            "scene": sc, "observation": s.obs.to_vec(), "mask": m.to_vec(),
            "logits": logits, "action": pred, "ruleAction": rule_action(sc, &m),
        }));
    }

    let mut layers = Vec::new();
    for l in 0..sizes.len() - 1 {
        layers.push(serde_json::json!({
            "inputs": sizes[l], "outputs": sizes[l + 1],
            "activation": if l + 2 < sizes.len() { "relu" } else { "linear" },
        }));
    }
    let bundle = serde_json::json!({
        "format": "cannonball-dense-v1",
        "modelId": format!("racer-policy-v1-s{seed}-{}", &sha[..12]),
        "observationSchema": OBSERVATION_SCHEMA,
        "actions": ACTIONS,
        "numericFormat": "float32-le-base64",
        "output": "masked-logits-argmax-first",
        "layers": layers,
        "paramCount": w32.len(),
        "weightsSha256": sha,
        "weights": base64::engine::general_purpose::STANDARD.encode(&bytes),
        "training": {
            "trainer": "tool/traffic_trainer (Rust, std threads, CPU)",
            "command": format!("cargo run --release -- --seed {seed} --train-episodes {train_eps} --eval-episodes {eval_eps} --epochs {epochs}"),
            "seed": seed, "threads": threads, "trainEpisodes": train_eps, "evalEpisodes": eval_eps,
            "trainSamples": train_len, "evalSamples": eval.len(), "classCounts": class_counts,
            "epochs": epochs, "batch": batch, "classWeights": class_weight.map(|w| round(w, 4)), "optimizer": format!("Adam lr={lr} (x0.3 after 2/3)"),
            "labeling": "best safety-masked action by 3 s lookahead rollout (90 steps @30 Hz), 12% exploration",
            "epochLog": epoch_log,
            "heldoutAccuracy": round(acc, 5), "ruleFallbackAgreement": round(rule_acc, 5),
            "laneChangeRecall": round(lane_hit as f64 / lane_total.max(1) as f64, 5),
            "confusion": confusion,
            "closedLoop": {"episodes": loop_eps, "teacher": teacher_m.json(), "learned": learned_m.json(), "rules": rules_m.json()},
            "rustDecisionsPerSecond": dps.round(),
            "wallSeconds": {"generate": round(gen_s, 2), "train": round(train_s, 2), "closedLoop": round(loop_s, 2), "total": round(total.elapsed().as_secs_f64(), 2)},
        },
        "fixtures": fixtures,
    });
    if let Some(dir) = std::path::Path::new(&out).parent() {
        std::fs::create_dir_all(dir)?;
    }
    std::fs::write(&out, serde_json::to_string_pretty(&bundle)? + "\n")?;
    println!(
        "RESULT samples={} acc={:.4} rules={:.4} params={} sha256={} decisions_per_s={:.0} total_s={:.1} out={out}",
        train_len, acc, rule_acc, w32.len(), sha, dps, total.elapsed().as_secs_f64()
    );
    Ok(())
}
