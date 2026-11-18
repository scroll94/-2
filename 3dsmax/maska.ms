-- ============================================================
--  Маска (лоскутное моделирование / Patch) для 3ds Max — MaxScript
--  Запуск: Scripting -> Run Script... -> maska.ms
--  1) строится сетка-каркас лица с отверстиями для глаз и рта
--     (симметрично относительно X = 0, как зеркальная копия половины);
--  2) переводится в Editable Patch (модификатор Turn to Patch);
--  3) Shell даёт толщину, TurboSmooth сглаживает края.
-- ============================================================
(
    local USE_PATCH = true      -- false = оставить Editable Mesh
    local STEP = 0.3            -- шаг сетки (меньше = точнее, но тяжелее)

    fn sq v = v * v
    fn bump dx sx dz sz = exp (-1.0 * (sq (dx / sx) + sq (dz / sz)))

    -- выпуклость лица (вперёд по -Y)
    fn maskDepth x z =
    (
        local ax = abs x
        local base  = 6.0 * sqrt (amax 0.05 (1.0 - sq (ax / 10.0))) - 0.012 * sq (z - 1.0)
        local nose  =  2.4 * (bump ax 1.4 (z + 0.8) 2.4)
        local brow  =  0.9 * (bump (ax - 3.3) 2.4 (z - 4.4) 0.9)
        local cheek =  0.9 * (bump (ax - 4.6) 2.0 (z + 3.2) 2.0)
        local sock  = -0.7 * (bump (ax - 3.3) 2.0 (z - 2.5) 1.3)
        local lips  =  0.7 * (bump ax 2.8 (z + 6.0) 1.1)
        local chin  =  0.6 * (bump ax 2.5 (z + 9.0) 1.2)
        base + nose + brow + cheek + sock + lips + chin
    )

    -- попадает ли точка в контур маски (и не в отверстие)
    fn inMask x z =
    (
        local ax = abs x
        if z < -4.0 do ax = ax * (1.0 + (-4.0 - z) * 0.07)   -- сужение к подбородку
        local outline = (pow (ax / 8.6) 2.5) + (pow ((abs (z + 0.5)) / 10.4) 2.5)
        if outline > 1.0 then false
        else
        (
            local eyeHole   = (sq ((ax - 3.3) / 1.9)) + (sq ((z - 2.4) / 1.3)) < 1.0
            local mouthHole = (sq (ax / 2.7)) + (sq ((z + 6.0) / 0.65)) < 1.0
            not (eyeHole or mouthHole)
        )
    )

    -- удалить старую маску
    local old = for o in objects where (matchPattern o.name pattern:"Maska*") collect o
    for o in old where (isValidNode o) do delete o

    local x0 = -9.0
    local z0 = -11.0
    local nxc = (18.0 / STEP) as integer
    local nzc = (21.0 / STEP) as integer
    local rowLen = nxc + 1

    local idx = #()
    idx[(nxc + 1) * (nzc + 1)] = 0
    for k = 1 to idx.count do idx[k] = 0

    local verts = #()
    local faces = #()
    local hide  = #()

    undo off
    (
        for j = 0 to nzc - 1 do
            for i = 0 to nxc - 1 do
            (
                local cx = x0 + (i + 0.5) * STEP
                local cz = z0 + (j + 0.5) * STEP
                if (inMask cx cz) do
                (
                    -- углы квадрата: a(i,j) b(i+1,j) c(i+1,j+1) d(i,j+1)
                    local ids = #()
                    for p in #([i, j], [i + 1, j], [i + 1, j + 1], [i, j + 1]) do
                    (
                        local ii = p.x as integer
                        local jj = p.y as integer
                        local key = jj * rowLen + ii + 1
                        if idx[key] == 0 do
                        (
                            local vx = x0 + ii * STEP
                            local vz = z0 + jj * STEP
                            append verts [vx, -(maskDepth vx vz), vz]
                            idx[key] = verts.count
                        )
                        append ids idx[key]
                    )
                    append faces [ids[1], ids[2], ids[3]] ; append hide 3
                    append faces [ids[1], ids[3], ids[4]] ; append hide 1
                )
            )

        local m = mesh vertices:verts faces:faces
        m.name = "Maska"
        for f = 1 to faces.count do
        (
            setEdgeVis m f hide[f] false
            setFaceSmoothGroup m f 1
        )
        update m

        -- лоскутная (Patch) модель
        local patched = false
        if USE_PATCH do
        (
            try
            (
                addModifier m (Turn_to_Patch())
                collapseStack m
                try (patch.setMeshSteps m 1) catch ()
                patched = true
                format "Маска переведена в Editable Patch\n"
            )
            catch (format "Turn to Patch недоступен, остаётся Editable Mesh\n")
        )

        addModifier m (Shell innerAmount:0.35 outerAmount:0.0)
        addModifier m (TurboSmooth iterations:(if patched then 1 else 2))

        m.material = StandardMaterial name:"Maska_Mat" diffuse:(color 205 200 140) ambient:(color 120 115 70) specularLevel:60 glossiness:35
        m.pos = [0, 0, 11]

        select m
        max zoomext sel all
        redrawViews()
        format "Маска готова: % вершин сетки\n" verts.count
    )
)
