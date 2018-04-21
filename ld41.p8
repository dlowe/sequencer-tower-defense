pico-8 cartridge // http://www.pico-8.com
version 16
__lua__

-- frame number
tick = 0

-- sequencer position
position = 0

-- cursor position
cursor_x = 0
cursor_y = 1

-- tower counter
towers     = 12
max_towers = 99

-- lives
lives = 9

-- walkthrough
walkthrough_state = 1
footer_text = {
   "use \139\145\148\131 to move your cursor",
   "  use \142 to place/change towers",
   "   keep the rhythm with \151",
   "",
   " here comes a creep! blast it!"
}

-- waves
wave = 0
wave_warn_tick = nil
wave_begin_tick = nil
wave_todo = 0

-- particles
particles = {}
function move_particles()
   local new_particles = {}
   for i=1,#particles do
      local p=particles[i]
      if p.active_until > tick then
         p.x += p.dx * p.speed
         p.y += p.dy * p.speed
         new_particles[#new_particles + 1] = p
      else
         -- printh("despawning particle " .. i)
      end
   end
   particles = new_particles
end

-- rings
rings = {}
function move_rings()
   local new_rings = {}
   for i=1,#rings do
      local r=rings[i]
      if r.active_until > tick then
         r.radius += r.speed
         new_rings[#new_rings + 1] = r
      else
         --printh("despawning ring " .. i)
      end
   end
   rings = new_rings
end

-- projectiles
projectiles = {}
function move_projectiles()
   local new_projectiles = {}
   for i=1,#projectiles do
      local p=projectiles[i]
      if p.active_until > tick then
         new_projectiles[#new_projectiles + 1] = p
      else
         --printh("despawning projectile " .. i)
      end
   end
   projectiles = new_projectiles
end

solution = {}
function solve()
   for x=0,16 do
      solution[x] = {}
      for y=1,14 do
         solution[x][y] = {
            reachable = false
         }
      end
   end

   local queue = {}
   for y=1,14 do
      queue[#queue + 1] = {x=16,y=y}
   end

   while #queue != 0 do
      -- "pop"  the first element of the queue
      local current = queue[1]
      local new_queue = {}
      for i=2,#queue do
         new_queue[#new_queue + 1] = queue[i]
      end
      queue = new_queue

      local deltas={{dx=-1,dy=0},{dx=0,dy=-1},{dx=0,dy=1},{dx=1,dy=0}}
      for d=1,#deltas do
         local nx=current.x+deltas[d].dx
         local ny=current.y+deltas[d].dy

         if (nx >= 0) and (nx <= 16) and (ny >= 1) and (ny <= 14) and (solution[nx][ny].reachable == false) and (mget(nx, ny) == 0) then
            --printh("solved: (" .. nx .. "," .. ny .. ") -> (" .. current.x .. "," .. current.y .. ")")
            -- add solution
            solution[nx][ny] = {
               reachable = true,
               path_x = current.x,
               path_y = current.y
            }
            -- push to queue
            queue[#queue + 1] = {x=nx, y=ny}
         end
      end
   end
end

function adapt_tower(cx, cy)
   local current = mget(cx, cy)
   local new     = (current + 1) % 5

   if (current == 0) then
      -- limit of max_towers towers
      if (towers >= max_towers) return nil

      -- can't place on top of a creep
      for i=1,#creeps do
         local c=creeps[i]
         if c.alive then
            if ((c.grid_x == cx) and (c.grid_y == cy)) return nil
            if ((c.next_grid_x == cx) and (c.next_grid_y == cy)) return nil
         end
      end

      -- limit of 4 towers per column
      count = 0
      for ypos=1,14 do
         if (mget(cx, ypos) != 0) count += 1
      end
      if (count > 3) return nil

      -- not allowed to block left->right pathfinding, or pathfinding of active creeps
      mset(cx, cy, 1)
      solve()
      local solvable = false
      for ypos=1,14 do
         if solution[0][ypos].reachable == true then
            solvable = true
            break
         end
      end
      for i=1,#creeps do
         local c=creeps[i]
         if c.alive and c.grid_x >= 0 then
            if solution[c.grid_x][c.grid_y].reachable == false then
               solvable = false
               break
            end
         end
      end
      mset(cx, cy, 0)
      if (solvable == false) then
         solve()
         return nil
      end

      towers += 1
   end

   mset(cx, cy, new)

   if (new == 0) towers -= 1

   if (walkthrough_state == 2) walkthrough_state = 3
end

function hurt_creep(i, damage)
   local c=creeps[i]
   if c.alive then
      c.health -= damage
      if c.health <= 0 then
         c.alive = false
         for n=1,c.max_health+flr(rnd(10)) do
            particles[#particles + 1] = {
               x=c.x+4,
               y=c.y+4,
               active_until=tick+10+flr(rnd(30)),
               speed=rnd(3),
               dx=rnd(3)-1,
               dy=rnd(3)-1,
               col=c.particle_color
            }
         end
      end
   end
end

function activate(x, y)
   local tower_type = mget(x, y)

   --printh("activate tower type=" .. tower_type .. " at (" .. x .. "," .. y .. ")")

   if tower_type == 1 then
      -- thumper: hits nearby creeps hard
      for i=1,#creeps do
         local c = creeps[i]
         if c.alive then
            if (abs(c.grid_x - x) <= 2) and (abs(c.grid_y - y) <= 2) then
               hurt_creep(i, 5)
            end
         end
      end
      rings[#rings + 1] = {
         x            = x*8+4,
         y            = y*8+4,
         col          = 8,
         radius       = 0.1,
         speed        = 3,
         active_until = tick + 6
      }
   elseif tower_type == 2 then
      -- sniper: hits one target, infinite range, very high damage
      for i=1,#creeps do
         local c = creeps[i]
         if c.alive then
            hurt_creep(i, 20)
            projectiles[#projectiles + 1] = {
               x0           = x*8 + 4,
               y0           = y*8 + 4,
               x1           = c.x,
               y1           = c.y,
               col          = 8,
               active_until = tick + 3,
            }
            break
         end
      end
   elseif tower_type == 3 then
      -- remotebomb: targets one medium-distance creep with an area effect
      for i=1,#creeps do
         local c = creeps[i]
         if c.alive then
            if (abs(c.grid_x - x) <= 5) and (abs(c.grid_y - y) <= 5) then
               for j=1,#creeps do
                  local t = creeps[j]
                  if (abs(t.grid_x - c.grid_x) <= 2) and (abs(t.grid_y - c.grid_y) <= 2) then
                     hurt_creep(j, 8)
                  end
               end
               projectiles[#projectiles + 1] = {
                  x0  = x*8 + 4,
                  y0  = y*8 + 4,
                  x1  = c.x,
                  y1  = c.y,
                  col = 8,
                  active_until = tick + 1,
               }
               rings[#rings + 1] = {
                  x = c.x,
                  y = c.y,
                  col = 7,
                  radius = 0.1,
                  speed = 2,
                  active_until = tick + 8
               }
               break
            end
         end
      end
   elseif tower_type == 4 then
      -- tri-laser: targets 3 medium-distance creeps with projectiles
      local n_hit = 0
      for i=1,#creeps do
         local c = creeps[i]
         if c.alive then
            if (abs(c.grid_x - x) <= 6) and (abs(c.grid_y - y) <= 6) then
               hurt_creep(i, 6)
               projectiles[#projectiles + 1] = {
                  x0           = x*8 + 4,
                  y0           = y*8 + 4,
                  x1           = c.x,
                  y1           = c.y,
                  col          = 5,
                  active_until = tick + 3
               }
               n_hit += 1
               if n_hit >= 3 then
                  break
               end
            end
         end
      end
   end
end

rhythm_cooldown_ticks = 5
last_rhythm_tick = nil
last_rhythm_x = nil
function rhythm(tick, p)
   if ((last_rhythm_tick != nil) and (tick - last_rhythm_tick < rhythm_cooldown_ticks)) last_rhythm_tick = tick return false
   last_rhythm_tick = tick
   local rhythm_x = flr(p / 8)
   if ((last_rhythm_x != nil) and (last_rhythm_x == rhythm_x)) return false
   last_rhythm_x = rhythm_x

   local activated = false
   for rhythm_y=1,14 do
      if (mget(rhythm_x, rhythm_y) != 0) activate(rhythm_x, rhythm_y) activated = true
   end

   if (activated and (walkthrough_state == 3)) walkthrough_state = 4

   return activated
end

function audio(p)
   local channel = 0
   if (p % 8) == 0 then
      xpos = p / 8
      --printh("p="..p..", xpos="..xpos)
      for ypos=1,14 do
         s = mget(xpos,ypos)
         if s != 0 then
            --printh("beep " .. s + 1)
            sfx(-1, channel)
            sfx(s - 1, channel, 0, 1)
            channel += 1
         end
      end
   end
end

creeps = {}
function spawn_creep(y)
   creeps[#creeps + 1] = {
      grid_x = -1,
      grid_y = y,
      next_grid_x = 0,
      next_grid_y = y,
      x=-5,
      y=y*8,
      sprite=16,
      speed=0.4,
      alive=true,
      health=10,
      max_health=10,
      particle_color=9
   }
end

function maybe_spawn_creep()
   if (walkthrough_state < 4) return

   if (walkthrough_state == 4) then
      local spawn_y = 7
      while solution[0][spawn_y].reachable == false do
         spawn_y = flr(rnd(13)) + 1
         printh("XXX: spawn_y=" .. spawn_y)
      end
      spawn_creep(spawn_y)
      walkthrough_state = 5
   end

   if (walkthrough_state == 6) then
      if tick >= wave_begin_tick and wave_todo >= 0 then
         local spawn_y = flr(rnd(13)) + 1
         if (solution[0][spawn_y].reachable == true) then
            spawn_creep(spawn_y)
            wave_todo -= 1
         end
      end
   end
end

function move_creeps()
   local initial_n_creeps = #creeps
   local new_creeps = {}
   for i=1,#creeps do
      local c = creeps[i]
      if c.alive then
         --we're not lined up with our next grid location; move to it
         dest_x = c.next_grid_x * 8
         dest_y = c.next_grid_y * 8
         if c.x < dest_x then
            c.x = min(dest_x, c.x + c.speed)
         elseif c.x > dest_x then
            c.x = max(dest_x, c.x - c.speed)
         elseif c.y < dest_y then
            c.y = min(dest_y, c.y + c.speed)
         elseif c.y > dest_y then
            c.y = max(dest_y, c.y - c.speed)
         else
            --we are lined up with our next grid location, so figure out the next step
            c.grid_x = c.next_grid_x
            c.grid_y = c.next_grid_y
            if c.grid_x == 15 then
               lives -= 1
               hurt_creep(i, 999)
            end
            c.next_grid_x = solution[c.grid_x][c.grid_y].path_x
            c.next_grid_y = solution[c.grid_x][c.grid_y].path_y

            --printh("aiming for (" .. creeps[i].next_grid_x .. ", " .. creeps[i].next_grid_y .. ")")
         end
         new_creeps[#new_creeps + 1] = c
      end
   end
   creeps = new_creeps
   if initial_n_creeps > 0 and #creeps == 0 then
      walkthrough_state = 6
      wave += 1
      wave_todo = 2 * wave
      wave_warn_tick = tick + 60
      wave_begin_tick = tick + 60 + 8 * 30
   end
end

active = false
function _update()
   active = false
   tick += 1
   audio(position)
   position = (position + 1) % 128
   local moved = false
   if (btnp(0)) cursor_x = max(0,cursor_x - 1) moved = true
   if (btnp(1)) cursor_x = min(15,cursor_x + 1) moved = true
   if (btnp(2)) cursor_y = max(1,cursor_y - 1) moved = true
   if (btnp(3)) cursor_y = min(14,cursor_y + 1) moved = true
   if (btnp(4)) adapt_tower(cursor_x, cursor_y)
   if (btnp(5)) active = rhythm(tick, position)
   if (moved and walkthrough_state == 1) walkthrough_state = 2
   maybe_spawn_creep()
   move_creeps()
   move_particles()
   move_rings()
   move_projectiles()
end

function _draw()
    cls()

    --towers
    map(0,0,0,0)

    --header
    print("towers: " .. towers .. "/" .. max_towers, 0, 1, 8)
    print("lives: " .. lives, 95, 1, 8)
    line(0,7,127,7,9)

    --footer
    line(0,120,127,120,9)
    if walkthrough_state != 6 then
       print(footer_text[walkthrough_state], 0, 122, 8)
    else
       if tick > wave_begin_tick then
          print("wave " .. wave .. " in progress", 0, 122, 8)
       elseif tick > wave_warn_tick then
          print("wave " .. wave .. " in " .. flr((wave_begin_tick - tick) / 30), 0, 122, 8)
       else
          print("wave " .. (wave - 1) .. " clear!", 0, 122, 8)
       end
    end

    --cursor
    rect(cursor_x * 8, cursor_y * 8, cursor_x * 8 + 7, cursor_y * 8 + 7, 2)

    --creeps
    for i=1,#creeps do
       local c=creeps[i]
       if c.alive then
          -- sprite
          spr(c.sprite,c.x,c.y)
          -- health bar
          line(c.x+1,c.y+1,c.x+6,c.y+1,8)
          line(c.x+1,c.y+1,c.x+1+(5*c.health/c.max_health),c.y+1,11)
       end
    end

    --particles
    for i=1,#particles do
       pset(particles[i].x, particles[i].y, particles[i].col)
    end

    --rings
    for i=1,#rings do
       circ(rings[i].x, rings[i].y, rings[i].radius, rings[i].col)
    end

    --projectiles
    for i=1,#projectiles do
       local p=projectiles[i]
       line(p.x0,p.y0,p.x1,p.y1,p.col)
    end

    --sequencer position
    local seq_color = 1
    if (active) seq_color = 3
    line(position,8,position,119,seq_color)
end
__gfx__
00000000000110000222222033333333440000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000001110002222222233333333440004400000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00700700011110002200022200000033440004400000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00077000000110000000222000333330444444440000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00077000000110000022220000033333044444440000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00700700000110000222200000000333000004400000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000011111102222222233333330000004400000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000011111102222222203333300000004400000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
09999990000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
09099090000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
09900990000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
09000090000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
09099090000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
09999990000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
__map__
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000300000000000000040000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0100020000010200010002000001020000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000300000000000400000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
__sfx__
01100000034410690007900079000db0008a0007a0007a0006a0001a0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
011000001c64500000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
011000003056300000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
011000000c46400000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
