local dpi = love.graphics.getDPIScale()

local canvas  = love.graphics.newCanvas(512, 512, {
  format       = "rgba32f",
  computewrite = true,
  dpiscale     = false
})

local quad          = love.graphics.newQuad(0, 0, 1, 1, canvas)
local time          = 0
local workGroupSize = 16
local cs            = love.graphics.newComputeShader("bounds.comp")
local buf           = love.graphics.newBuffer(
  "uint32",
  4,
  { shaderstorage = true }
)

function getContentBounds(canvas, dpi)
  local W, H = canvas:getPixelDimensions()

  -- [minX,minY,maxX,maxY] ← [W-1,H-1,0,0]
  buf:setArrayData({ W - 1, H - 1, 0, 0 })

  cs:send("Src",    canvas)
  cs:send("Bounds", buf)

  love.graphics.dispatchThreadgroups(
    cs,
    math.ceil(W / workGroupSize),
    math.ceil(H / workGroupSize),
    1
  )

  local raw  = love.graphics.readbackBuffer(buf) -- ByteData
  local data = raw:getString()                   -- 16-byte string

  local minX, minY, maxX, maxY = love.data.unpack("I4I4I4I4", data)

  if minX > maxX or minY > maxY then return nil end   -- fully transparent

  return minX / dpi, minY / dpi, (maxX - minX + 1) / dpi, (maxY - minY + 1) / dpi
end

local function drawToCanvas()
  love.graphics.setCanvas(canvas)
  love.graphics.clear(0, 0, 0, 0)

  -- rotating white square
  love.graphics.push()
    love.graphics.translate(256, 256)
    love.graphics.rotate(time)
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.rectangle("fill", -64, -64, 128, 128)
  love.graphics.pop()

  -- moving red circle
  love.graphics.setColor(1, 0, 0, 0.8)
  love.graphics.circle("fill",
      256 + math.cos(time * 2) * 150,
      256 + math.sin(time * 2) * 150,
      40)

  love.graphics.setCanvas()                -- back to the screen
end

function love.update(dt)
  time = time + dt * 0.25
end

function love.draw()
  love.graphics.clear(0.25, 0.25, 0.25)

  drawToCanvas()

  -- trimmed region
  local x, y, w, h = getContentBounds(canvas, dpi)
  if x then
    quad:setViewport(x, y, w, h)

    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.draw(canvas, quad, 100, 100)

    love.graphics.setColor(1, 0, 1, 1)
    love.graphics.rectangle("line", 100, 100, w, h)

    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.print(
          ("trimmed %dx%d @ (%d,%d)"):format(w, h, x, y),
          32, 16)
  else
    love.graphics.print("Canvas fully transparent", 32, 16)
  end

  -- full canvas
  love.graphics.setColor(1, 1, 1, 1)
  love.graphics.draw(canvas, 600, 32)
  love.graphics.rectangle("line", 600, 32,
      canvas:getWidth(), canvas:getHeight())
end
