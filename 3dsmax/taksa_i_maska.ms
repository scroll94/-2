-- ============================================================
--  ТАКСА + МАСКА для 3ds Max — один файл MaxScript
--  Запуск: Scripting -> Run Script... -> taksa_i_maska.ms
--  Часть 1: такса (NURBS-подобная гладкая модель по сечениям)
--  Часть 2: маска (лоскутное моделирование, Editable Patch)
-- ============================================================

-- ===================== ЧАСТЬ 1: ТАКСА =====================
(
    -- ---------- вспомогательные функции ----------
    fn buildQuadMesh nm verts quads tris:#() =
    (
        local faces = #()
        local hide = #()
        for q in quads do
        (
            append faces [q[1], q[2], q[3]] ; append hide 3
            append faces [q[1], q[3], q[4]] ; append hide 1
        )
        local nq = faces.count
        for t in tris do append faces t
        local m = mesh vertices:verts faces:faces
        m.name = nm
        for f = 1 to nq do setEdgeVis m f hide[f] false
        for f = 1 to faces.count do setFaceSmoothGroup m f 1
        update m
        m
    )

    -- secs: массив #(центр [x,y,z], радиус_вбок, радиус_вверх)
    fn makeSweep nm secs nSeg:16 =
    (
        local verts = #()
        local quads = #()
        local tris = #()
        local ns = secs.count
        for k = 1 to ns do
        (
            local c = secs[k][1]
            local t
            if k == 1 then t = secs[2][1] - secs[1][1]
            else if k == ns then t = secs[ns][1] - secs[ns-1][1]
            else t = secs[k+1][1] - secs[k-1][1]
            t = normalize t
            local refv = if (abs (dot t [0,0,1])) > 0.9 then [1,0,0] else [0,0,1]
            local side = normalize (cross t refv)
            local up = normalize (cross side t)
            for i = 0 to nSeg-1 do
            (
                local a = 360.0 * i / nSeg
                append verts (c + side * ((cos a) * secs[k][2]) + up * ((sin a) * secs[k][3]))
            )
        )
        for k = 1 to ns-1 do
            for i = 0 to nSeg-1 do
            (
                local i2 = if i == nSeg-1 then 0 else i+1
                local A = (k-1)*nSeg + i + 1
                local B = (k-1)*nSeg + i2 + 1
                local C = k*nSeg + i2 + 1
                local D = k*nSeg + i + 1
                append quads #(A, D, C, B)
            )
        append verts secs[1][1]
        local c0 = verts.count
        append verts secs[ns][1]
        local c1 = verts.count
        for i = 0 to nSeg-1 do
        (
            local i2 = if i == nSeg-1 then 0 else i+1
            append tris [c0, i+1, i2+1]
            append tris [c1, (ns-1)*nSeg + i2 + 1, (ns-1)*nSeg + i + 1]
        )
        buildQuadMesh nm verts quads tris:tris
    )

    fn smoothIt obj iters:2 = (addModifier obj (TurboSmooth iterations:iters) ; obj)

    -- ---------- очистка прошлой версии ----------
    local old = for o in objects where (matchPattern o.name pattern:"Taksa_*") collect o
    for o in old where (isValidNode o) do delete o

    local matFur  = StandardMaterial name:"Taksa_Fur"  diffuse:(color 150 75 30) ambient:(color 150 75 30) specularLevel:20 glossiness:25
    local matDark = StandardMaterial name:"Taksa_Dark" diffuse:(color 20 15 12)  ambient:(color 20 15 12)  specularLevel:80 glossiness:60
    local matEar  = StandardMaterial name:"Taksa_Ear"  diffuse:(color 110 52 20) ambient:(color 110 52 20) specularLevel:15 glossiness:20

    local parts = #()

    undo off
    (
        -- ---------- туловище + шея + голова (одна поверхность) ----------
        local body = makeSweep "Taksa_Body" #(
            #([-34, 0, 17.0], 0.5, 0.5),
            #([-33, 0, 17.0], 5.0, 5.0),
            #([-30, 0, 17.5], 8.0, 8.0),
            #([-24, 0, 18.0], 9.5, 9.0),
            #([-14, 0, 18.0], 9.0, 8.5),
            #([ -4, 0, 18.0], 9.0, 8.5),
            #([  6, 0, 18.0], 9.5, 9.5),
            #([ 14, 0, 18.0], 10.0, 10.5),
            #([ 20, 0, 20.0], 8.5, 9.0),
            #([ 25, 0, 24.0], 6.5, 6.5),
            #([ 28, 0, 28.0], 6.0, 6.0),
            #([ 31, 0, 31.0], 7.0, 6.5),
            #([ 35, 0, 31.0], 7.0, 6.0),
            #([ 39, 0, 30.0], 5.0, 4.5),
            #([ 43, 0, 28.5], 3.5, 3.2),
            #([ 47, 0, 27.5], 2.8, 2.6),
            #([ 49, 0, 27.3], 2.0, 2.0),
            #([ 50, 0, 27.2], 0.4, 0.4)
        ) nSeg:20
        smoothIt body
        body.material = matFur
        append parts body

        -- ---------- хвост ----------
        local tail = makeSweep "Taksa_Tail" #(
            #([-31, 0, 19], 0.5, 0.5),
            #([-32, 0, 20], 2.5, 2.5),
            #([-38, 0, 23], 1.8, 1.8),
            #([-44, 0, 27], 1.2, 1.2),
            #([-48, 0, 31], 0.6, 0.6),
            #([-49, 0, 32], 0.2, 0.2)
        ) nSeg:12
        smoothIt tail
        tail.material = matFur
        append parts tail

        for s in #(-1, 1) do
        (
            -- ---------- передние лапы (короткие!) ----------
            local fl = makeSweep ("Taksa_LegFront_" + (if s < 0 then "R" else "L")) #(
                #([12.0, s*5.5, 14.0], 0.5, 0.5),
                #([12.0, s*5.5, 13.0], 3.2, 3.4),
                #([12.5, s*5.6,  7.0], 2.3, 2.4),
                #([13.0, s*5.8,  2.5], 2.0, 2.0),
                #([13.2, s*5.8,  1.5], 0.4, 0.4)
            ) nSeg:12
            smoothIt fl
            fl.material = matFur
            append parts fl

            -- ---------- задние лапы ----------
            local bl = makeSweep ("Taksa_LegBack_" + (if s < 0 then "R" else "L")) #(
                #([-25.0, s*5.5, 17.0], 0.5, 0.5),
                #([-25.0, s*5.5, 15.0], 4.0, 4.5),
                #([-27.0, s*5.6,  8.0], 2.8, 2.8),
                #([-26.0, s*5.8,  3.0], 2.0, 2.0),
                #([-25.8, s*5.8,  1.5], 0.4, 0.4)
            ) nSeg:12
            smoothIt bl
            bl.material = matFur
            append parts bl

            -- ---------- ступни ----------
            for px in #(14.5, -24.5) do
            (
                local paw = Sphere radius:2.4 segs:16 pos:[px, s*5.9, 1.2]
                paw.name = "Taksa_Paw"
                paw.scale = [1.5, 1.0, 0.55]
                paw.material = matFur
                append parts paw
            )

            -- ---------- висячие уши ----------
            local ear = makeSweep ("Taksa_Ear_" + (if s < 0 then "R" else "L")) #(
                #([32.0, s*5.5, 34.0], 0.3, 1.0),
                #([32.0, s*6.2, 33.0], 0.7, 3.0),
                #([33.0, s*7.4, 28.0], 0.7, 3.6),
                #([33.5, s*7.6, 23.5], 0.6, 3.2),
                #([33.2, s*7.3, 21.5], 0.3, 1.2)
            ) nSeg:12
            smoothIt ear
            ear.material = matEar
            append parts ear

            -- ---------- глаза ----------
            local eye = Sphere radius:1.3 segs:16 pos:[38.0, s*4.3, 33.0]
            eye.name = "Taksa_Eye"
            eye.material = matDark
            append parts eye
        )

        -- ---------- нос ----------
        local nose = Sphere radius:1.6 segs:16 pos:[50.0, 0, 27.8]
        nose.name = "Taksa_Nose"
        nose.scale = [0.8, 1.2, 0.9]
        nose.material = matDark
        append parts nose
    )

    local grp = group parts name:"Taksa_Group"
    redrawViews()
    format "Такса готова: % объектов\n" parts.count
)


-- ===================== ЧАСТЬ 2: МАСКА =====================
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
        m.pos = [85, 0, 11]   -- маска стоит справа от таксы

        redrawViews()
        format "Маска готова: % вершин сетки\n" verts.count
    )
)


-- ---------- показать всё ----------
(
    select (for o in objects where (matchPattern o.name pattern:"Taksa_*") or (matchPattern o.name pattern:"Maska*") collect o)
    max zoomext sel all
    clearSelection()
    redrawViews()
)
