Queue = {}
 
function Queue.new()
    return { first = 0, last = -1 }
end
 
function Queue.push( queue, value )
    queue.last = queue.last + 1
    queue[queue.last] = value
end
 
function Queue.pop( queue )
    if queue.first > queue.last then
        return nil
    end
 
    local val = queue[queue.first]
    queue[queue.first] = nil
    queue.first = queue.first + 1
    return val
end
 
function Queue.empty( queue )
    return queue.first > queue.last
end

local SimpleDispatcher_t = {}
local SimpleDispatcher_mt = {
  __index = SimpleDispatcher_t
}

SimpleDispatcher = function()
  local obj = {
    tasklist = Queue.new();
  }
  setmetatable(obj, SimpleDispatcher_mt)

  return obj
end


SimpleDispatcher_t.AddTask = function(self, atask)
  Queue.push(self.tasklist, atask)
end

SimpleDispatcher_t.AddRoutine = function(self, aroutine, ...)
  local routine = coroutine.create(aroutine)
  local task = {routine = routine, params = {...}}
  self:AddTask(task)

  return task
end

SimpleDispatcher_t.Run =  function(self)
  while not Queue.empty(self.tasklist) do
    local task = Queue.pop(self.tasklist)
    if not task then 
      break
    end

    if coroutine.status(task.routine) ~= "dead" then
      local status, values = coroutine.resume(task.routine, unpack(task.params));

      if coroutine.status(task.routine) ~= "dead" then
        self:AddTask(task)
      else
        print("TASK FINISHED")
      end
    else
      print("DROPPING TASK")
    end
  end
end

return SimpleDispatcher
