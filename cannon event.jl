const WIDTH, HEIGHT = 800, 555
const BACKGROUND = colorant"#352a55"
const PLAYER_WIDTH, PLAYER_HEIGHT = 25, 92
const ENEMY_SIZE, ENEMY_RADIUS = 64, 28
const STAR_SIZE, STAR_RADIUS = 32, 32
const DANGER_STAR_SIZE, DANGER_STAR_RADIUS = 24, 24
const CANNON_SCALE = 0.75
const BASE_PATTERN_DELAY = 180
const BASE_CANNON_FRAME2_DELAY = 5
const BASE_CANNON_FRAME3_DELAY = 5
const BASE_ENEMY_SPEED = 6.5
const PLAYER_SPEED = 7.0
const GRAVITY = 0.8 
const PLATFORM_SPEED = 4.0 
const JUMP_HEIGHT = 18.0  
const DOUBLE_JUMP_HEIGHT = 16.0 

const DIFFICULTY_SCALE_INTERVAL = 12
const MAX_DIFFICULTY_MULTIPLIER = 3.0
const MIN_PATTERN_DELAY = 80
const MAX_ENEMY_SPEED = 7.0
const STAR_FRAME_DELAY = 4
const STAR_PAUSE_DELAY = 75
const PLAYER_IDLE_DELAY = 30
const PLAYER_AIR_DELAY = 8
const DANGER_STAR_FRAME_DELAY = 6
const DANGER_STAR_MIN_LIFETIME = 60
const DANGER_STAR_MAX_LIFETIME = 120
const DANGER_STAR_DISAPPEAR_FRAME_DELAY = 8

const JUMP_SOUNDS = ["jump1", "jump2", "jump3"]
const CANNON_SOUNDS = ["1", "2", "3"]
const PLAYER_IDLE_SPRITES = ["p-1.png", "p-2.png"]
const PLAYER_AIR_SPRITES = ["p.png", "p2.png", "p3.png", "p4.png"]
const LEFT_CANNON_SPRITES = ["xx.png", "xx2.png", "xx3.png"]
const RIGHT_CANNON_SPRITES = ["xx-right.png", "xx2-right.png", "xx3-right.png"]
const ENEMY_SPRITES = ["danger.png", "danger2.png", "danger3.png"]
const STAR_SPRITES = ["stars.png", "stars2.png", "stars3.png"]
const DANGER_STAR_SPRITES = ["i.png", "i2.png"]
const DANGER_STAR_DISAPPEAR_SPRITES = ["i4.png", "i5.png", "i6.png", "i7.png"]
const ENEMY_HALF_SIZE = ENEMY_SIZE / 2
const STAR_HALF_SIZE = STAR_SIZE / 2
const DANGER_STAR_HALF_SIZE = DANGER_STAR_SIZE / 2
const PLAYER_HALF_WIDTH = PLAYER_WIDTH * 0.5
const PLATFORM_HALF_WIDTH = 66.0

const bg_actor = Actor("1.png")
const platform_actor = Actor("platform.png")
const player_idle_actors = [Actor(sprite) for sprite in PLAYER_IDLE_SPRITES]
const player_air_actors = [Actor(sprite) for sprite in PLAYER_AIR_SPRITES]
const enemy_actors = [Actor(sprite) for sprite in ENEMY_SPRITES]
const star_actors = [Actor(sprite) for sprite in STAR_SPRITES]
const danger_star_actors = [Actor(sprite) for sprite in DANGER_STAR_SPRITES]
const danger_star_disappear_actors = [Actor(sprite) for sprite in DANGER_STAR_DISAPPEAR_SPRITES]
const left_cannon_actors = [Actor(sprite) for sprite in LEFT_CANNON_SPRITES]
const right_cannon_actors = [Actor(sprite) for sprite in RIGHT_CANNON_SPRITES]

for actor in player_idle_actors
    actor.scale = [0.5, 0.5]
end
for actor in player_air_actors
    actor.scale = [0.5, 0.5]
end
for actor in left_cannon_actors
    actor.scale = [CANNON_SCALE, CANNON_SCALE]
end
for actor in right_cannon_actors
    actor.scale = [CANNON_SCALE, CANNON_SCALE]
end
for actor in danger_star_actors
    actor.scale = [0.75, 0.75]
end
for actor in danger_star_disappear_actors
    actor.scale = [0.75, 0.75]
end

@inline function circle_rect_collision(cx, cy, radius, rx, ry, rw, rh)
    closest_x = clamp(cx, rx, rx + rw)
    closest_y = clamp(cy, ry, ry + rh)
    dx = cx - closest_x
    dy = cy - closest_y
    return (dx * dx + dy * dy) <= (radius * radius)
end

game_over = false
game_paused = false
score = 0
high_score = 0
music_started = false
cannon_rounds = 0

const HIGHSCORE_KEY = UInt8[0x9a, 0x5c, 0x3e, 0x7f, 0x12, 0x84, 0x6b, 0xd2, 0x45, 0x9e, 0x7a, 0x1c, 0xf3, 0x68, 0x2d, 0x50]

@inline function encrypt_score(score::Int)
    try
        score_bytes = reinterpret(UInt8, [UInt32(score)])
        nonce = rand(UInt8, 24)
        encrypted = [score_bytes[i] ⊻ HIGHSCORE_KEY[((i-1) & 31) + 1] ⊻ nonce[((i-1) % 24) + 1] for i in 1:4]
        return vcat(nonce, encrypted)
    catch
        return UInt8[]
    end
end

@inline function decrypt_score(data::Vector{UInt8})
    try
        length(data) < 28 && return 0
        nonce, encrypted = @view(data[1:24]), @view(data[25:end])
        decrypted = [encrypted[i] ⊻ HIGHSCORE_KEY[((i-1) & 31) + 1] ⊻ nonce[((i-1) % 24) + 1] for i in 1:4]
        return Int(reinterpret(UInt32, decrypted)[1])
    catch
        return 0
    end
end

save_highscore(score::Int) = try; write("r.w", encrypt_score(score)); catch; end
load_highscore() = try; isfile("r.w") ? decrypt_score(read("r.w")) : 0; catch; 0; end

mutable struct Animation
    frame::Int8
    timer::Int16
    delay::Int16
    max_frames::Int8
    paused::Bool
    pause_timer::Int16
    pause_delay::Int16
end

mutable struct Player
    x::Float32
    y::Float32
    vel_x::Float32
    vel_y::Float32
    on_ground::Bool
    jumps_left::Int8
    jump_key_released::Bool
    idle_anim::Animation
    air_anim::Animation
end

mutable struct Platform
    x::Float32
    y::Float32
    width::Float32
    height::Float32
end

mutable struct Cannon
    x::Float32
    y::Float32
    frame::Int8
    timer::Int16
    side::String
    scale::Float32
    frame2_delay::Int16
    frame3_delay::Int16
end

mutable struct Enemy
    x::Float32
    y::Float32
    vel_x::Float32
    anim::Animation
end

mutable struct Star
    x::Float32
    y::Float32
    visible::Bool
    collected::Bool
    can_spawn::Bool
    anim::Animation
    pending_conversion::Bool
    collected_x::Float32
    collected_y::Float32
end

mutable struct DangerousStar
    x::Float32
    y::Float32
    visible::Bool
    anim::Animation
    lifetime_timer::Int16
    lifetime_target::Int16
    disappearing::Bool
    disappear_anim::Animation
end

mutable struct Background
    x::Float32
    y::Float32
end

Animation(delay::Int, max_frames::Int, pause_delay::Int=0) = Animation(Int8(1), Int16(0), Int16(delay), Int8(max_frames), false, Int16(0), Int16(pause_delay))
Enemy(x::Float32, y::Float32, vel_x::Float32) = Enemy(x, y, vel_x, Animation(8, 3))
Star(x::Float32, y::Float32) = Star(x, y, true, false, true, Animation(STAR_FRAME_DELAY, 3, STAR_PAUSE_DELAY), false, 0.0f0, 0.0f0)
DangerousStar(x::Float32, y::Float32) = DangerousStar(x, y, true, Animation(DANGER_STAR_FRAME_DELAY, 2), Int16(0), Int16(rand(DANGER_STAR_MIN_LIFETIME:DANGER_STAR_MAX_LIFETIME)), false, Animation(DANGER_STAR_DISAPPEAR_FRAME_DELAY, 4))

const CANNON_INDICES = Dict("l1"=>1, "l2"=>2, "l3"=>3, "r1"=>4, "r2"=>5, "r3"=>6)
const STAR_Y_POSITIONS = Float32[61.0, 211.0]
const LEFT_CANNONS = ["l1", "l2", "l3"]
const RIGHT_CANNONS = ["r1", "r2", "r3"]

pattern_timer = 0
pattern_delay = BASE_PATTERN_DELAY

create_player() = Player(400.0f0, 360.0f0, 0.0f0, 0.0f0, true, Int8(2), true, Animation(PLAYER_IDLE_DELAY, 2), Animation(PLAYER_AIR_DELAY, 4))
create_star() = Star(Float32(rand(200:555)), rand(STAR_Y_POSITIONS))

player = create_player()
star = create_star()
dangerous_star = nothing
platform = Platform(Float32(WIDTH * 0.5 - PLATFORM_HALF_WIDTH), Float32(HEIGHT - 85), 132.0f0, 20.0f0)
bg = Background(Float32(rand(-500:-50)), 200.0f0)

cannons = [
    Cannon(-5.0f0, 50.0f0, Int8(1), Int16(0), "left", Float32(CANNON_SCALE), Int16(BASE_CANNON_FRAME2_DELAY), Int16(BASE_CANNON_FRAME3_DELAY)),
    Cannon(-5.0f0, 200.0f0, Int8(1), Int16(0), "left", Float32(CANNON_SCALE), Int16(BASE_CANNON_FRAME2_DELAY), Int16(BASE_CANNON_FRAME3_DELAY)),
    Cannon(-5.0f0, 350.0f0, Int8(1), Int16(0), "left", Float32(CANNON_SCALE), Int16(BASE_CANNON_FRAME2_DELAY), Int16(BASE_CANNON_FRAME3_DELAY)),
    Cannon(646.0f0, 50.0f0, Int8(1), Int16(0), "right", Float32(CANNON_SCALE), Int16(BASE_CANNON_FRAME2_DELAY), Int16(BASE_CANNON_FRAME3_DELAY)),
    Cannon(646.0f0, 200.0f0, Int8(1), Int16(0), "right", Float32(CANNON_SCALE), Int16(BASE_CANNON_FRAME2_DELAY), Int16(BASE_CANNON_FRAME3_DELAY)),
    Cannon(646.0f0, 350.0f0, Int8(1), Int16(0), "right", Float32(CANNON_SCALE), Int16(BASE_CANNON_FRAME2_DELAY), Int16(BASE_CANNON_FRAME3_DELAY))
]

enemies = Enemy[]
sizehint!(enemies, 20)

high_score = load_highscore()

@inline function get_difficulty_multiplier()
    difficulty_level = min(cannon_rounds ÷ DIFFICULTY_SCALE_INTERVAL, MAX_DIFFICULTY_MULTIPLIER)
    return 1.0f0 + (difficulty_level * 0.5f0)
end

@inline function update_difficulty_values!()
    mult = get_difficulty_multiplier()
    global pattern_delay = max(MIN_PATTERN_DELAY, Int(round(BASE_PATTERN_DELAY / mult)))
    cannon_delay2 = max(2, Int16(round(BASE_CANNON_FRAME2_DELAY / mult)))
    cannon_delay3 = max(2, Int16(round(BASE_CANNON_FRAME3_DELAY / mult)))
    @inbounds for cannon in cannons
        cannon.frame2_delay = cannon_delay2
        cannon.frame3_delay = cannon_delay3
    end
end

@inline get_cannon_by_index(code::String) = get(CANNON_INDICES, code, 0) > 0 ? cannons[CANNON_INDICES[code]] : nothing
const pattern_buffer = String[]
sizehint!(pattern_buffer, 4)

@inline function generate_balanced_pattern()
    empty!(pattern_buffer)
    num_enemies = rand(2:4)
    if num_enemies == 2
        push!(pattern_buffer, rand(LEFT_CANNONS), rand(RIGHT_CANNONS))
    elseif num_enemies == 3
        if rand(Bool)
            push!(pattern_buffer, rand(LEFT_CANNONS), rand(RIGHT_CANNONS), rand(RIGHT_CANNONS))
        else
            push!(pattern_buffer, rand(LEFT_CANNONS), rand(LEFT_CANNONS), rand(RIGHT_CANNONS))
        end
    else
        push!(pattern_buffer, rand(LEFT_CANNONS), rand(LEFT_CANNONS), rand(RIGHT_CANNONS), rand(RIGHT_CANNONS))
    end
    return pattern_buffer
end

@inline function update_animation!(anim::Animation)
    if anim.paused
        anim.pause_timer += Int16(1)
        if anim.pause_timer >= anim.pause_delay
            anim.paused = false
            anim.pause_timer = Int16(0)
            anim.timer = Int16(0)
            anim.frame = Int8(1)
        end
        return
    end
    anim.timer += Int16(1)
    if anim.timer >= anim.delay
        anim.timer = Int16(0)
        if anim.frame < anim.max_frames
            anim.frame += Int8(1)
        else
            anim.frame = Int8(1)
            if anim.pause_delay > 0
                anim.paused = true
                anim.pause_timer = Int16(0)
            end
        end
    end
end

function check_collisions!()
    global player, enemies, game_over, star, score, dangerous_star
    game_paused && return
    px, py = player.x, player.y
    @inbounds for enemy in enemies
        if circle_rect_collision(enemy.x + ENEMY_HALF_SIZE, enemy.y + ENEMY_HALF_SIZE, ENEMY_RADIUS, px, py, PLAYER_WIDTH, PLAYER_HEIGHT)
            play_sound("lose")
            game_over = true
            return
        end
    end
    if dangerous_star !== nothing && dangerous_star.visible && !dangerous_star.disappearing
        if circle_rect_collision(dangerous_star.x + DANGER_STAR_HALF_SIZE, dangerous_star.y + DANGER_STAR_HALF_SIZE, DANGER_STAR_RADIUS, px, py, PLAYER_WIDTH, PLAYER_HEIGHT)
            play_sound("lose")
            game_over = true
            return
        end
    end
    if star.visible && !star.collected && !star.pending_conversion
        if circle_rect_collision(star.x + STAR_HALF_SIZE, star.y + STAR_HALF_SIZE, STAR_RADIUS, px, py, PLAYER_WIDTH, PLAYER_HEIGHT)
            play_sound("collect")
            star.collected_x = star.x
            star.collected_y = star.y
            star.pending_conversion = true
            star.visible = false
            star.collected = true
            score += 5
        end
    end
end

function update_rhythm_system!()
    global pattern_timer, score, cannon_rounds
    game_paused && return
    pattern_timer += 1
    if pattern_timer >= pattern_delay
        pattern_timer = 0
        cannon_rounds += 1
        update_difficulty_values!()
        for code in generate_balanced_pattern()
            cannon = get_cannon_by_index(code)
            if cannon !== nothing
                cannon.frame = Int8(2)
                cannon.timer = Int16(0)
            end
        end
        score += 1
    end
end

@inline function update_cannon_animation!(cannon)
    (cannon.frame == 1 || game_paused) && return
    cannon.timer += Int16(1)
    if cannon.frame == 2 && cannon.timer >= cannon.frame2_delay
        cannon.frame = Int8(3)
        cannon.timer = Int16(0)
    elseif cannon.frame == 3 && cannon.timer >= cannon.frame3_delay
        play_sound(rand(CANNON_SOUNDS))
        spawn_enemy_from_cannon!(cannon)
        cannon.frame = Int8(1)
        cannon.timer = Int16(0)
    end
end

@inline function spawn_enemy_from_cannon!(cannon)
    mult = get_difficulty_multiplier()
    enemy_speed = Float32(min(MAX_ENEMY_SPEED, BASE_ENEMY_SPEED * mult))
    if cannon.side == "left"
        push!(enemies, Enemy(cannon.x + 18.0f0, cannon.y + 11.0f0, enemy_speed))
    else
        push!(enemies, Enemy(cannon.x + 38.0f0, cannon.y + 11.0f0, -enemy_speed))
    end
end

function update_player!()
    global player, platform, game_over
    game_paused && return
    !player.on_ground && (player.vel_y += Float32(GRAVITY))
    player.on_ground && player.vel_x != 0 && (player.vel_x *= 0.85f0)
    player.x += player.vel_x
    player.y += player.vel_y
    player.x = clamp(player.x, 170.0f0, 620.0f0)
    platform_top = platform.y - 5.0f0
    player.on_ground = false
    if player.vel_y >= 0 && player.x + PLAYER_WIDTH > platform.x && player.x < platform.x + platform.width && 
       player.y + PLAYER_HEIGHT >= platform_top && player.y + PLAYER_HEIGHT <= platform_top + 25.0f0
        player.y = platform_top - PLAYER_HEIGHT
        player.vel_y = 0.0f0
        player.on_ground = true
        player.jumps_left = Int8(2)
        player.jump_key_released = true
    end
    player.vel_y = min(player.vel_y, 15.0f0)
    if player.y > HEIGHT
        play_sound("lose")
        game_over = true
    end
    if player.on_ground
        player.air_anim = Animation(PLAYER_AIR_DELAY, 4)
        update_animation!(player.idle_anim)
    else
        player.idle_anim = Animation(PLAYER_IDLE_DELAY, 2)
        update_animation!(player.air_anim)
    end
end

function update_enemies!()
    global enemies
    game_paused && return
    @inbounds for enemy in enemies
        enemy.x += enemy.vel_x
        update_animation!(enemy.anim)
    end
    filter!(enemies) do e
        if e.vel_x < 0 && e.x < 50
            return false
        end
        if e.vel_x > 0 && e.x > 700
            return false
        end
        return true
    end
end

function update_star!()
    global star, player, dangerous_star
    game_paused && return
    if star.pending_conversion && player.on_ground
        dangerous_star = DangerousStar(star.collected_x, star.collected_y)
        star.pending_conversion = false
        star.can_spawn = false
        star.visible = false
    end
    star.visible && update_animation!(star.anim)
    if dangerous_star !== nothing && dangerous_star.visible
        if dangerous_star.disappearing
            update_animation!(dangerous_star.disappear_anim)
            if dangerous_star.disappear_anim.frame >= 4
                play_sound("danger0")
                dangerous_star.visible = false
            end
        else
            update_animation!(dangerous_star.anim)
            dangerous_star.lifetime_timer += Int16(1)
            if dangerous_star.lifetime_timer >= dangerous_star.lifetime_target
                dangerous_star.disappearing = true
            end
        end
        if !dangerous_star.visible
            dangerous_star = nothing
            star.can_spawn = true
        end
    end
    if !star.visible && star.can_spawn && player.on_ground && dangerous_star === nothing && !star.pending_conversion
        star.x = Float32(rand(200:555))
        star.y = rand(STAR_Y_POSITIONS)
        star.visible = true
        star.collected = false
        star.can_spawn = false
        star.anim = Animation(STAR_FRAME_DELAY, 3, STAR_PAUSE_DELAY)
    end
end

function update_platform!()
    global platform, player
    game_paused && return
    target_x = player.x + PLAYER_HALF_WIDTH - platform.width * 0.5f0
    diff = target_x - platform.x
    move_speed = Float32(PLATFORM_SPEED)
    
    if abs(diff) > move_speed
        platform.x += diff > 0 ? move_speed : -move_speed
    else
        platform.x += diff
    end
end

@inline function jump!()
    global player
    if player.on_ground && player.jumps_left > 0
        play_sound(rand(JUMP_SOUNDS))
        player.vel_y = -Float32(JUMP_HEIGHT)
        player.jumps_left -= Int8(1)
        player.on_ground = false
        player.jump_key_released = false
    elseif !player.on_ground && player.jumps_left > 0 && player.jump_key_released
        play_sound(rand(JUMP_SOUNDS))
        player.vel_y = -Float32(DOUBLE_JUMP_HEIGHT)
        player.jumps_left -= Int8(1)
        player.jump_key_released = false
    end
end

@inline function toggle_pause!()
    global game_paused
    play_sound("pause")
    game_paused = !game_paused
end

start_music() = !music_started && (play_sound("music", -1); global music_started = true)

function draw(g::Game)
    start_music()
    draw_game_elements()
    
    if game_paused
        pause_text = TextActor("GAME PAUSED", "fat.ttf"; font_size = 48, color = [255, 255, 255, 255])
        pause_text.pos = (300, 275 - 40); draw(pause_text)
        continue_text = TextActor("Press SPACE to continue", "fat.ttf"; font_size = 24, color = [255, 255, 255, 255])
        continue_text.pos = (300, 275 + 20); draw(continue_text)
        return
    end
    
    if game_over
        global high_score
        score > high_score && (high_score = score; save_highscore(high_score))
        
        gameover_text = TextActor("GAME OVER", "fat.ttf"; font_size = 64, color = [255, 255, 255, 255])
        gameover_text.pos = (255, 250 - 80); draw(gameover_text)
        score_text = TextActor("Final Score: $score", "fat.ttf"; font_size = 32, color = [255, 255, 255, 255])
        score_text.pos = (255, 250 - 40); draw(score_text)
        highscore_text = TextActor("High Score: $high_score", "fat.ttf"; font_size = 36, color = [255, 255, 0, 255])
        highscore_text.pos = (255, 260); draw(highscore_text)
    end
end

function draw_game_elements()
    global bg, star, dangerous_star, platform
    bg_actor.pos = (bg.x, bg.y)
    draw(bg_actor)
    
    platform_actor.pos = (platform.x + 5, platform.y - 5)
    draw(platform_actor)
    
    if star.visible
        star_actor = star_actors[star.anim.frame]
        star_actor.pos = (star.x, star.y)
        draw(star_actor)
    end
    
    if dangerous_star !== nothing && dangerous_star.visible
        if dangerous_star.disappearing
            dstar_actor = danger_star_disappear_actors[clamp(dangerous_star.disappear_anim.frame, 1, 4)]
        else
            dstar_actor = danger_star_actors[dangerous_star.anim.frame]
        end
        dstar_actor.pos = (dangerous_star.x, dangerous_star.y)
        draw(dstar_actor)
    end
    
    @inbounds for enemy in enemies
        enemy_actor = enemy_actors[enemy.anim.frame]
        enemy_actor.pos = (enemy.x, enemy.y)
        draw(enemy_actor)
    end
    
    @inbounds for cannon in cannons
        if cannon.side == "left"
            cannon_actor = left_cannon_actors[cannon.frame]
        else
            cannon_actor = right_cannon_actors[cannon.frame]
        end
        cannon_actor.pos = (cannon.x, cannon.y)
        draw(cannon_actor)
    end
    
    # Player drawing
    if player.on_ground
        player_actor = player_idle_actors[player.idle_anim.frame]
        offset_y = player.idle_anim.frame == 1 ? 12 : 0
    else
        player_actor = player_air_actors[player.air_anim.frame]
        offset_y = 0
    end
    player_actor.pos = (player.x - 32, player.y + offset_y)
    draw(player_actor)
    
    score_text = TextActor("$score", "fat.ttf"; font_size = 66, color = [255, 255, 255, 255])
    score_text.pos = (WIDTH * 0.5, 40)
    draw(score_text)
end

function update(g::Game)
    global player
    (game_over || game_paused) && return
    if g.keyboard.LEFT || g.keyboard.A
        player.vel_x = -Float32(PLAYER_SPEED)
    elseif g.keyboard.RIGHT || g.keyboard.D
        player.vel_x = Float32(PLAYER_SPEED)
    else
        !player.on_ground && (player.vel_x *= 0.95f0)
    end
    
    !(g.keyboard.UP || g.keyboard.W || g.keyboard.SPACE) && (player.jump_key_released = true)
    
    update_player!()
    update_platform!()
    update_enemies!()
    update_star!()
    check_collisions!()
    update_rhythm_system!()
    
    @inbounds for cannon in cannons
        update_cannon_animation!(cannon)
    end
end

function reset_game!()
    global game_over, player, enemies, pattern_timer, score, game_paused, platform, bg, star, dangerous_star, cannon_rounds, pattern_delay
    play_sound("restart")
    game_over = false
    game_paused = false
    score = 0
    cannon_rounds = 0 
    pattern_delay = BASE_PATTERN_DELAY
    player = create_player()
    star = create_star()
    dangerous_star = nothing
    platform.x = Float32(WIDTH * 0.5 - platform.width * 0.5)
    bg.x = Float32(rand(-500:-50))
    bg.y = 200.0
    empty!(enemies)
    pattern_timer = 0
    @inbounds for cannon in cannons
        cannon.frame = Int8(1)
        cannon.timer = Int16(0)
        cannon.frame2_delay = Int16(BASE_CANNON_FRAME2_DELAY)
        cannon.frame3_delay = Int16(BASE_CANNON_FRAME3_DELAY)
    end
end

function on_key_down(g::Game, key)
    if (key == Keys.P || key == Keys.ESCAPE || key == Keys.LSHIFT) && !game_over
        toggle_pause!()
        return
    end
    if game_paused && key == Keys.SPACE
        play_sound("unpause")
        toggle_pause!()
        return
    end
    if game_over && key == Keys.SPACE
        reset_game!()
    elseif !game_over && !game_paused && (key == Keys.UP || key == Keys.W || key == Keys.SPACE)
        jump!()
    end
end