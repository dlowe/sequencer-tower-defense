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
   " here comes a creep! blast it!",
   ""
}

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
            printh("solved: (" .. nx .. "," .. ny .. ") -> (" .. current.x .. "," .. current.y .. ")")
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
         if creeps[i].alive then
            if ((creeps[i].grid_x == cx) and (creeps[i].grid_y == cy)) return nil
            if ((creeps[i].next_grid_x == cx) and (creeps[i].next_grid_y == cy)) return nil
         end
      end

      -- limit of 4 towers per column
      count = 0
      for ypos=1,14 do
         if mget(cx, ypos) != 0 then
            count += 1
         end
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
         if creeps[i].alive then
            if solution[creeps[i].grid_x][creeps[i].grid_y].reachable == false then
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

   if (new == 0) then
      towers -= 1
   end

   if (walkthrough_state == 2) walkthrough_state = 3
end

function activate(x, y)
   --printh("X=" .. x .. ", Y=" .. y)
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
      alive=true
   }
end

function maybe_spawn_creep()
   if (walkthrough_state < 4) return

   if (walkthrough_state == 4) then
      for spawn_y=7,1,-1 do
         if (mget(0, spawn_y) == 0) then
            spawn_creep(spawn_y)
            break
         end
      end
      walkthrough_state = 5
   end

   -- TODO: actual creep spawning
end

function move_creeps()
   for i=1,#creeps do
      if creeps[i].alive then
         --we're not lined up with our next grid location; move to it
         dest_x = creeps[i].next_grid_x * 8
         dest_y = creeps[i].next_grid_y * 8
         if creeps[i].x < dest_x then
            creeps[i].x = min(dest_x, creeps[i].x + creeps[i].speed)
         elseif creeps[i].x > dest_x then
            creeps[i].x = max(dest_x, creeps[i].x - creeps[i].speed)
         elseif creeps[i].y < dest_y then
            creeps[i].y = min(dest_y, creeps[i].y + creeps[i].speed)
         elseif creeps[i].y > dest_y then
            creeps[i].y = max(dest_y, creeps[i].y - creeps[i].speed)
         else
            --we are lined up with our next grid location, so figure out the next step
            creeps[i].grid_x = creeps[i].next_grid_x
            creeps[i].grid_y = creeps[i].next_grid_y
            if creeps[i].grid_x == 15 then
               lives -= 1
               creeps[i].alive = false
            end
            creeps[i].next_grid_x = solution[creeps[i].grid_x][creeps[i].grid_y].path_x
            creeps[i].next_grid_y = solution[creeps[i].grid_x][creeps[i].grid_y].path_y

            --printh("aiming for (" .. creeps[i].next_grid_x .. ", " .. creeps[i].next_grid_y .. ")")
         end
      end
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
    -- printh("XXX: " .. walkthrough_state)
    print(footer_text[walkthrough_state], 0, 122, 8)

    --cursor
    rect(cursor_x * 8, cursor_y * 8, cursor_x * 8 + 7, cursor_y * 8 + 7, 2)

    --creeps
    for i=1,#creeps do
       if creeps[i].alive then
          spr(creeps[i].sprite,creeps[i].x,creeps[i].y)
       end
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
