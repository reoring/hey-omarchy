function pathOffset(y, seed) {
    return 3 * Math.sin(y * 0.026 + seed)
        + 1.2 * Math.sin(y * 0.071 + seed * 1.7);
}

function dimensions(value, fallback) {
    return isFinite(value) && value > 0 ? value : fallback;
}

function contact(state, drop) {
    // Each contact patch stays fixed until the head travels onto new glass.
    drop.releaseRadius = 13 + state.random() * 8;
    drop.nextContact = drop.y + 11.7 + state.random() * 40.3;
    drop.pause = 0.45 + state.random() * 2.8;
}

function spawn(state, drop, attached) {
    var random = state.random;
    drop.active = true;
    drop.y = random() * state.height * 0.94;
    drop.seed = random() * Math.PI * 2;
    drop.x = random() * state.width;
    drop.baseX = drop.x - pathOffset(drop.y, drop.seed);
    drop.radius = attached ? 5.25 + Math.pow(random(), 1.8) * 7.75
                           : 7.75 + Math.pow(random(), 1.3) * 7.75;
    drop.mass = drop.radius * drop.radius * drop.radius;
    drop.speed = attached ? 0 : 299 + random() * 221;
    drop.age = attached ? 2 + random() * 15 : 0;
    drop.life = drop.age + 28 + random() * 34;
    drop.opacity = attached ? 1 : 0;
    drop.stretch = attached ? 1 : 1 + drop.speed / 221;
    drop.impact = attached ? 0 : 1;
    drop.originY = drop.y;
    drop.trailTop = drop.y;
    drop.trailAlpha = 0;
    drop.pinned = attached;
    drop.readyAt = 0;
    contact(state, drop);
}

function create(width, height, random) {
    width = dimensions(width, 1);
    height = dimensions(height, 1);
    var count = Math.max(160, Math.min(240, Math.round(192 * width * height / 2073600)));
    var state = {
        width: width,
        height: height,
        random: typeof random === "function" ? random : Math.random,
        drops: new Array(count),
        time: 0,
        accumulator: 0,
        spawnIn: 0.25,
        spawnCursor: 0,
        impactRate: Math.max(2.8, Math.min(7.2, width * height / 350000))
    };
    // Slots and their render fields are never replaced or appended during step().
    for (var i = 0; i < count; ++i) {
        var drop = {
            active: false, x: 0, y: 0, baseX: 0, seed: 0,
            radius: 1, mass: 1, speed: 0, age: 0, opacity: 0,
            stretch: 1, impact: 0, trailTop: 0, trailAlpha: 0,
            originY: 0, pinned: true, releaseRadius: 6,
            nextContact: 0, pause: 0, life: 0, readyAt: 0
        };
        state.drops[i] = drop;
        if (i < Math.floor(count * 0.64))
            spawn(state, drop, true);
    }
    return state;
}

function resize(state, width, height) {
    var sx = width / state.width;
    var sy = height / state.height;
    for (var i = 0; i < state.drops.length; ++i) {
        var drop = state.drops[i];
        if (!drop.active)
            continue;
        drop.x *= sx;
        drop.y *= sy;
        drop.originY *= sy;
        drop.trailTop = Math.max(drop.originY, drop.trailTop * sy, drop.y - 145);
        drop.nextContact *= sy;
        drop.baseX = drop.x - pathOffset(drop.y, drop.seed);
    }
    state.width = width;
    state.height = height;
    state.impactRate = Math.max(2.8, Math.min(7.2, width * height / 350000));
}

function retire(state, drop) {
    drop.active = false;
    drop.opacity = 0;
    drop.readyAt = state.time + 0.5 + state.random() * 1.5;
}

function advanceDrop(state, drop, dt) {
    drop.age += dt;
    drop.impact = Math.max(0, 1 - drop.age / 0.34);
    if (drop.y >= drop.nextContact)
        contact(state, drop);

    if (drop.pinned) {
        drop.speed = 0;
        drop.pause -= dt;
        if (drop.radius >= drop.releaseRadius) {
            drop.pinned = false;
        } else if (drop.pause <= 0) {
            // Small attached beads wait for added water; marginal ones creep in short slips.
            if (drop.radius > 9.25 && state.random() < 0.32 * drop.radius / drop.releaseRadius) {
                drop.speed = 31.2 + state.random() * 62.4;
                drop.pinned = false;
            }
            drop.pause = 0.65 + state.random() * 3.8;
        }
    }

    var oldY = drop.y;
    if (!drop.pinned) {
        // Static adhesion exceeds sliding friction: an impact runs, dissipates, then sticks.
        var drive = 338 * (drop.radius / (drop.releaseRadius * 0.76) - 1);
        var drag = 4.3;
        var decay = Math.exp(-drag * dt);
        drop.speed = Math.max(0, Math.min(520,
            drop.speed * decay + drive * (1 - decay) / drag));
        if (drop.speed < 10.4 && drop.radius < drop.releaseRadius) {
            drop.speed = 0;
            drop.pinned = true;
            drop.pause = 0.4 + state.random() * 2.7;
        }
        drop.y += drop.speed * dt;
    }
    drop.x = drop.baseX + pathOffset(drop.y, drop.seed);
    var travel = drop.y - oldY;
    if (travel > 0) {
        drop.trailTop = Math.max(drop.originY, drop.trailTop, drop.y - 145);
        drop.trailAlpha += (0.72 - drop.trailAlpha) * Math.min(1, travel / 15);
    } else {
        // Drying retracts stored travel; it never invents a trail above the impact.
        drop.trailTop = Math.min(drop.y, drop.trailTop + dt * 7);
        drop.trailAlpha *= Math.exp(-dt * 0.55);
    }
    var targetStretch = Math.min(3.35, 1 + drop.speed / 195);
    drop.stretch += (targetStretch - drop.stretch) * Math.min(1, dt * 12);
    var fadeIn = Math.min(1, drop.age / 0.1);
    var fadeOut = Math.max(0, Math.min(1, (drop.life - drop.age) / 2));
    var edgeFade = Math.max(0, Math.min(1,
        (state.height + drop.radius - drop.y) / (18 + drop.radius * 2)));
    drop.opacity = fadeIn * fadeOut * edgeFade;
    if (drop.age >= drop.life || drop.y >= state.height + drop.radius)
        retire(state, drop);
}

function merge(state, survivor, absorbed) {
    var totalMass = survivor.mass + absorbed.mass;
    // Volume and downward momentum are conserved here; gravity acts on the next substep.
    survivor.speed = (survivor.speed * survivor.mass + absorbed.speed * absorbed.mass) / totalMass;
    survivor.mass = totalMass;
    survivor.radius = Math.pow(totalMass, 1 / 3);
    survivor.life = survivor.age + Math.max(survivor.life - survivor.age, absorbed.life - absorbed.age);
    survivor.opacity = Math.max(survivor.opacity, absorbed.opacity);
    survivor.pinned = survivor.speed < 10.4 && survivor.radius < survivor.releaseRadius;
    // Keep the receiving head and its original path: neither a merge nor recycling teleports water.
    retire(state, absorbed);
}

function substep(state, dt) {
    state.time += dt;
    state.spawnIn -= dt;
    if (state.spawnIn <= 0) {
        // Poisson arrivals have no repeated rows, lanes, or shared motion clock.
        state.spawnIn += -Math.log(Math.max(0.000001, 1 - state.random())) / state.impactRate;
        state.spawnIn = Math.max(dt, state.spawnIn);
        for (var n = 0; n < state.drops.length; ++n) {
            var slot = (state.spawnCursor + n) % state.drops.length;
            var free = state.drops[slot];
            if (!free.active && free.readyAt <= state.time) {
                spawn(state, free, false);
                state.spawnCursor = (slot + 1) % state.drops.length;
                break;
            }
        }
    }

    var drops = state.drops;
    for (var i = 0; i < drops.length; ++i) {
        if (drops[i].active)
            advanceDrop(state, drops[i], dt);
    }
    // Bounded head-only broad/narrow checks; trails cannot merge unrelated heads.
    for (var a = 0; a < drops.length; ++a) {
        var first = drops[a];
        if (!first.active)
            continue;
        for (var b = a + 1; b < drops.length; ++b) {
            var second = drops[b];
            if (!second.active)
                continue;
            var reach = (first.radius + second.radius) * 0.86;
            var dx = first.x - second.x;
            var dy = first.y - second.y;
            if (Math.abs(dx) >= reach || Math.abs(dy) >= reach || dx * dx + dy * dy >= reach * reach)
                continue;
            // The downstream head receives the water without jumping backwards along the glass.
            if (first.y >= second.y) {
                merge(state, first, second);
            } else {
                merge(state, second, first);
                break;
            }
        }
    }
}

function step(state, dt, width, height) {
    width = dimensions(width, state.width);
    height = dimensions(height, state.height);
    if (width !== state.width || height !== state.height)
        resize(state, width, height);
    if (!isFinite(dt) || dt <= 0)
        return;
    // Fixed 120 Hz steps bound collision travel; a resumed desktop never catches up a long pause.
    var fixedDt = 1 / 120;
    state.accumulator = Math.min(0.1, state.accumulator + Math.min(0.1, dt));
    while (state.accumulator + 0.000000001 >= fixedDt) {
        substep(state, fixedDt);
        state.accumulator = Math.max(0, state.accumulator - fixedDt);
    }
}
