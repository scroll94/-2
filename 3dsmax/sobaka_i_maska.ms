-- ============================================================
--  СОБАКА + МАСКА для 3ds Max — один файл MaxScript
--  Запуск: Scripting -> Run Script... -> sobaka_i_maska.ms
--  Часть 1: собака из NURBS-поверхностей (практическая по NURBS, рис. 8.3)
--  Часть 2: маска (лоскутное моделирование, Editable Patch, рис. 9.5)
-- ============================================================

-- ===================== ЧАСТЬ 1: СОБАКА (NURBS) =====================
(
    -- Каждая часть тела задаётся поперечными сечениями:
    --   #(центр [x,y,z], радиус вбок, радиус вверх)
    -- По сечениям строится NURBS CV-поверхность (как U-Loft по кривым).
    -- Все поверхности лежат в одном NURBS-объекте "Sobaka_NURBS",
    -- поэтому в панели Modify их можно сопрягать (Blend / Fillet).

    local N_SEG = 8   -- CV по окружности сечения

    -- точки сечений (кольца)
    fn ringPoints secs nSeg =
    (
        local rings = #()
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
            local r = #()
            for i = 0 to nSeg-1 do
            (
                local a = 360.0 * i / nSeg
                append r (c + side * ((cos a) * secs[k][2]) + up * ((sin a) * secs[k][3]))
            )
            append rings r
        )
        rings
    )

    -- NURBS CV-поверхность-трубка: по длине (U) зажатая, по кругу (V) замкнутая
    fn addNurbsTube nset nm secs nSeg =
    (
        local k = 1.0 / 0.9   -- компенсация: B-сплайн лежит внутри CV-каркаса
        local big = for s in secs collect #(s[1], s[2]*k, s[3]*k)
        local rings = ringPoints big nSeg
        local nu = rings.count
        local nv = nSeg + 3
        local srf = NURBSCVSurface name:nm uOrder:4 vOrder:4 numUCVs:nu numVCVs:nv numUKnots:(nu + 4) numVKnots:(nv + 4)
        for i = 1 to (nu + 4) do
            setUKnot srf i (if i <= 4 then 0.0 else if i > nu then (nu - 3) as float else (i - 4) as float)
        for i = 1 to (nv + 4) do
            setVKnot srf i ((i - 1) as float)
        for u = 1 to nu do
            for v = 1 to nv do
                (
                local vi = ((mod (v - 1) nSeg) as integer) + 1
                setCV srf u v (NURBSControlVertex rings[u][vi])
            )
        appendObject nset srf
        srf
    )

    -- запасной вариант (если NURBS API не сработает): гладкая сетка
    fn makeMeshTube nm secs =
    (
        local rings = ringPoints secs 16
        local verts = #()
        local faces = #()
        local hide = #()
        local ns = rings.count
        for r in rings do for p in r do append verts p
        for k = 1 to ns-1 do
            for i = 0 to 15 do
            (
                local i2 = if i == 15 then 0 else i + 1
                local A = (k-1)*16 + i + 1
                local B = (k-1)*16 + i2 + 1
                local C = k*16 + i2 + 1
                local D = k*16 + i + 1
                append faces [A, D, C] ; append hide 3
                append faces [A, C, B] ; append hide 1
            )
        local nq = faces.count
        append verts secs[1][1]
        local c0 = verts.count
        append verts secs[ns][1]
        local c1 = verts.count
        for i = 0 to 15 do
        (
            local i2 = if i == 15 then 0 else i + 1
            append faces [c0, i + 1, i2 + 1]
            append faces [c1, (ns-1)*16 + i2 + 1, (ns-1)*16 + i + 1]
        )
        local m = mesh vertices:verts faces:faces
        m.name = nm
        for f = 1 to nq do setEdgeVis m f hide[f] false
        for f = 1 to faces.count do setFaceSmoothGroup m f 1
        update m
        addModifier m (TurboSmooth iterations:2)
        m
    )

    -- ---------- удалить старую собаку ----------
    local old = for o in objects where (matchPattern o.name pattern:"Sobaka_*") collect o
    for o in old where (isValidNode o) do delete o

    local matFur  = StandardMaterial name:"Sobaka_Fur"  diffuse:(color 165 120 75) ambient:(color 165 120 75) specularLevel:25 glossiness:25 twoSided:true
    local matDark = StandardMaterial name:"Sobaka_Dark" diffuse:(color 20 15 12) ambient:(color 20 15 12) specularLevel:80 glossiness:60

    -- ---------- части тела (собака на длинных лапах, как на рис. 8.3) ----------
    local parts = #()

    -- туловище + шея + голова одной поверхностью
    append parts #("Body", #(
        #([-30, 0, 40.0], 0.3, 0.3),
        #([-29, 0, 40.0], 5.0, 5.0),
        #([-26, 0, 40.0], 8.0, 8.0),
        #([-20, 0, 40.0], 9.0, 8.5),
        #([-10, 0, 40.5], 7.0, 6.5),     -- поджарый живот
        #([  0, 0, 40.0], 8.0, 8.5),
        #([ 10, 0, 39.0], 9.5, 10.5),    -- глубокая грудь
        #([ 17, 0, 40.0], 9.0, 10.0),
        #([ 22, 0, 44.0], 7.0, 7.5),
        #([ 26, 0, 50.0], 5.5, 5.5),     -- шея
        #([ 29, 0, 55.0], 5.0, 5.0),
        #([ 32, 0, 59.0], 6.0, 6.0),     -- затылок
        #([ 36, 0, 60.0], 6.5, 5.8),
        #([ 40, 0, 59.0], 5.0, 4.8),     -- переход ко лбу
        #([ 45, 0, 57.0], 3.6, 3.4),     -- морда
        #([ 50, 0, 56.0], 3.0, 2.8),
        #([ 53, 0, 55.8], 2.2, 2.2),
        #([ 54, 0, 55.7], 0.3, 0.3)))

    -- хвост
    append parts #("Tail", #(
        #([-27, 0, 42], 0.3, 0.3),
        #([-29, 0, 42], 2.0, 2.0),
        #([-35, 0, 40], 1.5, 1.5),
        #([-39, 0, 35], 1.1, 1.1),
        #([-41, 0, 29], 0.7, 0.7),
        #([-41.5, 0, 27], 0.2, 0.2)))

    for s in #(-1, 1) do
    (
        local sn = if s < 0 then "_R" else "_L"

        -- передняя лапа (вверху широкая — плечо, плавно входит в грудь)
        append parts #("LegFront" + sn, #(
            #([12.0, s*5.0, 40.0], 0.3, 0.3),
            #([12.0, s*5.0, 37.0], 4.5, 5.0),
            #([11.0, s*5.2, 25.0], 2.6, 2.8),
            #([12.0, s*5.3, 14.0], 2.0, 2.0),
            #([12.0, s*5.3,  6.0], 1.8, 1.8),
            #([13.0, s*5.3,  2.0], 1.8, 1.8),
            #([13.2, s*5.3,  1.0], 0.3, 0.3)))

        -- задняя лапа (бедро, колено, скакательный сустав)
        append parts #("LegBack" + sn, #(
            #([-22.0, s*5.5, 41.0], 0.3, 0.3),
            #([-22.0, s*5.5, 37.0], 5.0, 6.0),
            #([-19.0, s*5.5, 27.0], 3.5, 3.5),
            #([-25.0, s*5.5, 15.0], 2.3, 2.3),
            #([-23.0, s*5.5,  6.0], 1.8, 1.8),
            #([-22.0, s*5.5,  2.0], 1.8, 1.8),
            #([-21.8, s*5.5,  1.0], 0.3, 0.3)))

        -- стоячее ухо
        append parts #("Ear" + sn, #(
            #([33.5, s*3.5, 62.0], 0.3, 1.0),
            #([33.0, s*4.0, 64.0], 0.7, 2.6),
            #([32.0, s*5.0, 68.0], 0.6, 1.8),
            #([31.2, s*5.5, 71.0], 0.2, 0.3)))
    )

    local created = #()
    undo off
    (
        local ok = true
        try
        (
            local nset = NURBSSet()
            for p in parts do addNurbsTube nset ("Sobaka_" + p[1]) p[2] N_SEG
            local n = NURBSNode nset name:"Sobaka_NURBS"
            n.material = matFur
            append created n
            format "Собака построена из % NURBS-поверхностей\n" parts.count
        )
        catch
        (
            ok = false
            format "NURBS API недоступен (%), строю сеткой\n" (getCurrentException())
        )
        if not ok do
            for p in parts do
            (
                local m = makeMeshTube ("Sobaka_" + p[1]) p[2]
                m.material = matFur
                append created m
            )

        -- ступни, глаза, нос
        for s in #(-1, 1) do
        (
            for px in #(14.5, -20.5) do
            (
                local paw = Sphere radius:2.3 segs:16 pos:[px, s*5.4, 1.2]
                paw.name = "Sobaka_Paw"
                paw.scale = [1.5, 1.0, 0.55]
                paw.material = matFur
                append created paw
            )
            local eye = Sphere radius:1.1 segs:16 pos:[41.0, s*3.9, 60.3]
            eye.name = "Sobaka_Eye"
            eye.material = matDark
            append created eye
        )
        local nose = Sphere radius:1.4 segs:16 pos:[54.0, 0, 56.3]
        nose.name = "Sobaka_Nose"
        nose.scale = [0.8, 1.2, 0.9]
        nose.material = matDark
        append created nose
    )

    group created name:"Sobaka_Group"
    redrawViews()
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
        m.pos = [85, 0, 11]   -- маска стоит справа от собаки

        redrawViews()
        format "Маска готова: % вершин сетки\n" verts.count
    )
)


-- ---------- показать всё ----------
(
    select (for o in objects where (matchPattern o.name pattern:"Sobaka_*") or (matchPattern o.name pattern:"Maska*") collect o)
    max zoomext sel all
    clearSelection()
    redrawViews()
)
