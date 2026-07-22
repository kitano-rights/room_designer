import { Controller } from "@hotwired/stimulus"

const SVG_NS = "http://www.w3.org/2000/svg"
// エディターの座標系（mm）。viewBox と合わせる
const WORLD = { width: 5000, height: 4000 }
// 座標の丸め単位（mm）
const SNAP = 10
// 回転の刻み（家具画像を4方向分しか用意しないため90度単位）
const ROTATION_STEP = 90
// 区画の分割数（床: 6×6、壁: 横は床と共通の6 × 縦3）
const FLOOR_DIVISIONS = 6
const WALL_DIVISIONS = 3
// 家具画像の当たり判定でヒットとみなすアルファ値の下限（うっすらした縁は無視する）
const ALPHA_HIT_THRESHOLD = 32

// 部屋エディター（SVG）
// - 部屋の形: 固定（形状・サイズの編集は当面行わない）
// - 家具: パレットから追加、ドラッグで移動、選択して回転・削除
// - 保存: corners と家具一覧を JSON で PATCH 送信し、成功したら俯瞰画面へ遷移
export default class extends Controller {
  static targets = ["svg", "roomLayer", "furnitureLayer", "furnitureActions", "saveButton", "wallColorButton", "floorColorButton"]
  static values = {
    corners: Array,
    depthLines: Array,
    wallPolygons: Array,
    floorPolygon: Array,
    wallColor: String,
    floorColor: String,
    furnitures: Array,
    kindSpecs: Object,
    updateUrl: String,
    showUrl: String
  }

  connect() {
    this.furnitures = this.furnituresValue
    this.wallColor = this.wallColorValue
    this.floorColor = this.floorColorValue
    this.selectedIndex = null

    // 当たり判定は SVG 一箇所で行う。画像の透明部分を無視して手前の家具から
    // 判定するため、要素ごとのヒットではなくアルファ値のピクセル判定を使う
    this.alphaMaps = {}
    this.loadAlphaMaps()
    this.svgTarget.addEventListener("pointerdown", (event) => this.onPointerDown(event))
    this.svgTarget.addEventListener("pointermove", (event) => {
      const hovering = this.furnitureIndexAt(this.svgPoint(event)) !== null
      this.svgTarget.style.cursor = hovering ? "move" : "default"
    })

    this.renderRoom()
    this.renderColorButtons()
    this.render()
  }

  // --- ツールバー操作 ---

  addFurniture(event) {
    const kind = event.currentTarget.dataset.kind
    const center = this.polygonCenter()
    this.furnitures.push({ kind: kind, pos_x: center.x, pos_y: center.y, rotation: 0 })
    this.selectedIndex = this.furnitures.length - 1
    this.render()
  }

  setWallColor(event) {
    this.wallColor = event.currentTarget.dataset.value
    this.renderRoom()
    this.renderColorButtons()
  }

  setFloorColor(event) {
    this.floorColor = event.currentTarget.dataset.value
    this.renderRoom()
    this.renderColorButtons()
  }

  rotateSelected() {
    const furniture = this.furnitures[this.selectedIndex]
    if (!furniture) return

    furniture.rotation = (this.normalizeRotation(furniture.rotation) + ROTATION_STEP) % 360
    this.render()
  }

  deleteSelected() {
    if (this.selectedIndex === null) return

    this.furnitures.splice(this.selectedIndex, 1)
    this.selectedIndex = null
    this.render()
  }

  async save() {
    this.saveButtonTarget.disabled = true
    try {
      const response = await fetch(this.updateUrlValue, {
        method: "PATCH",
        headers: {
          "Content-Type": "application/json",
          "Accept": "application/json",
          "X-CSRF-Token": document.querySelector('meta[name="csrf-token"]').content
        },
        body: JSON.stringify({
          room: {
            corners: this.cornersValue,
            wall_color: this.wallColor,
            floor_color: this.floorColor,
            furnitures: this.furnitures
          }
        })
      })
      if (response.ok) {
        window.Turbo.visit(this.showUrlValue)
        return
      }
      const data = await response.json().catch(() => ({}))
      alert(data.error || "保存に失敗しました")
    } catch {
      alert("保存に失敗しました")
    }
    this.saveButtonTarget.disabled = false
  }

  // --- 描画 ---

  // 部屋の形は固定。壁紙・床の色が変わったときに再描画する
  // 区画線が境目・輪郭線の下に隠れるよう、塗り → 区画線 → 奥行き線 → 輪郭線 の順に重ねる
  renderRoom() {
    const points = this.cornersValue.map((point) => point.join(",")).join(" ")
    // 壁（左右）と床を選択した色・テクスチャで塗り分ける
    const surfaces = [
      ...this.wallPolygonsValue.map((polygon, index) => this.svgElement("polygon", {
        points: polygon.map((point) => point.join(",")).join(" "),
        fill: this.wallFill(index === 0 ? "left" : "right")
      })),
      this.svgElement("polygon", {
        points: this.floorPolygonValue.map((point) => point.join(",")).join(" "),
        fill: this.floorFill()
      })
    ]
    // 床・壁を等分する区画線
    const sectionLines = this.sectionLines().map(([from, to]) => this.svgElement("line", {
      x1: from.x, y1: from.y, x2: to.x, y2: to.y,
      stroke: "#d1d5db",
      "stroke-width": 10
    }))
    // 奥行きを表す内側の線（壁と壁・壁と床の境目）
    const depthLines = this.depthLinesValue.map(([from, to]) => this.svgElement("line", {
      x1: from[0], y1: from[1], x2: to[0], y2: to[1],
      stroke: "#d1d5db",
      "stroke-width": 20
    }))
    // 輪郭線は陰影で立体感が出る分、細めに抑える
    const outline = this.svgElement("polygon", {
      points,
      fill: "none",
      stroke: "#334155",
      "stroke-width": 15,
      "stroke-linejoin": "round"
    })
    this.roomLayerTarget.replaceChildren(...surfaces, ...sectionLines, ...depthLines, outline)
  }

  // 壁の塗り。値が「#」始まりなら色、それ以外は壁ごとに傾けたテクスチャパターン
  wallFill(side) {
    return this.wallColor.startsWith("#") ? this.wallColor : `url(#wall-${side}-${this.wallColor})`
  }

  // 床の塗り。値が「#」始まりなら色、それ以外は菱形に合わせたテクスチャパターン
  floorFill() {
    return this.floorColor.startsWith("#") ? this.floorColor : `url(#floor-${this.floorColor})`
  }

  // 選択中の色のボタンに枠を付ける
  renderColorButtons() {
    this.wallColorButtonTargets.forEach((button) => {
      button.classList.toggle("ring-2", button.dataset.value === this.wallColor)
    })
    this.floorColorButtonTargets.forEach((button) => {
      button.classList.toggle("ring-2", button.dataset.value === this.floorColor)
    })
  }

  // 床 6×6・壁 6×3 の区画線（内側の線のみ。外周・境目は既存の線が担う）
  // 奥行き線の端点から、部屋の奥の角・床の左右の辺・壁の高さを求めて等分する
  sectionLines() {
    const [[inner, top], [, leftBottom], [, rightBottom]] = this.depthLinesValue
    const [cx, cy] = inner
    // 奥の角から床の左下・右下の頂点へ向かうベクトル（床の2辺）
    const edges = [
      { x: leftBottom[0] - cx, y: leftBottom[1] - cy },
      { x: rightBottom[0] - cx, y: rightBottom[1] - cy }
    ]
    const wallHeight = cy - top[1]
    const lines = []

    edges.forEach((edge, index) => {
      const opposite = edges[1 - index]
      for (let i = 1; i < FLOOR_DIVISIONS; i++) {
        const t = i / FLOOR_DIVISIONS
        const x = cx + edge.x * t
        const y = cy + edge.y * t
        // 床: この辺を6等分し、対辺と平行に引く線
        lines.push([{ x, y }, { x: x + opposite.x, y: y + opposite.y }])
        // 壁: 床の6等分と揃えた縦線
        lines.push([{ x, y: y - wallHeight }, { x, y }])
      }
      // 壁: 高さを3等分する横線
      for (let j = 1; j < WALL_DIVISIONS; j++) {
        const y = cy - (wallHeight * j) / WALL_DIVISIONS
        lines.push([{ x: cx, y }, { x: cx + edge.x, y: y + edge.y }])
      }
    })
    return lines
  }

  render() {
    this.renderFurnitures()
    this.furnitureActionsTarget.classList.toggle("invisible", this.selectedIndex === null)
  }

  renderFurnitures() {
    this.furnitureLayerTarget.replaceChildren(...this.drawOrder().map(({ furniture, index }) => {
      const spec = this.kindSpecsValue[furniture.kind]
      const selected = index === this.selectedIndex

      // 画像がある家具は向きを画像の差し替えで表現するため rotate しない
      const group = this.svgElement("g", {
        transform: spec.images
          ? `translate(${furniture.pos_x} ${furniture.pos_y})`
          : `translate(${furniture.pos_x} ${furniture.pos_y}) rotate(${furniture.rotation})`
      })
      if (spec.images) {
        this.appendFurnitureImage(group, spec, furniture, selected)
      } else {
        this.appendFurnitureRect(group, spec, selected)
      }
      return group
    }))
  }

  // 家具の描画順。ラグなど床レベルの家具（layer: 0）を先に描いて他の家具の下に敷き、
  // 同レイヤーでは奥から描いて手前の家具を前面に重ねる
  drawOrder() {
    return this.furnitures
      .map((furniture, index) => ({ furniture, index }))
      .sort((a, b) =>
        (this.layerOf(a.furniture) - this.layerOf(b.furniture)) ||
        (this.frontYOf(a.furniture) - this.frontYOf(b.furniture)) ||
        (a.index - b.index))
  }

  // 奥行き比較に使う「家具の接地部の手前端」の y。中心（pos_y）同士だと背の高い家具ほど
  // 接地面が画像中心より下に写るぶん奥に判定されてしまうため、実測の front_offset で補正する
  frontYOf(furniture) {
    const spec = this.kindSpecsValue[furniture.kind]
    if (spec.front_offset !== undefined) return furniture.pos_y + spec.front_offset

    // 矩形描画の家具は回転後の矩形の下端
    const radian = (furniture.rotation * Math.PI) / 180
    return furniture.pos_y + (Math.abs(Math.sin(radian)) * spec.width + Math.abs(Math.cos(radian)) * spec.depth) / 2
  }

  // 4方向レンダリング画像の家具。選択中は破線の枠で示す
  appendFurnitureImage(group, spec, furniture, selected) {
    const size = spec.image_size
    group.appendChild(this.svgElement("image", {
      href: spec.images[this.normalizeRotation(furniture.rotation)],
      x: -size / 2,
      y: -size / 2,
      width: size,
      height: size
    }))
    if (selected) {
      group.appendChild(this.svgElement("rect", {
        x: -size / 2,
        y: -size / 2,
        width: size,
        height: size,
        fill: "none",
        stroke: "#2563eb",
        "stroke-width": 25,
        "stroke-dasharray": "80 50"
      }))
    }
  }

  // 画像がまだない家具は寸法どおりの矩形とラベルで描く
  appendFurnitureRect(group, spec, selected) {
    group.appendChild(this.svgElement("rect", {
      x: -spec.width / 2,
      y: -spec.depth / 2,
      width: spec.width,
      height: spec.depth,
      rx: 40,
      fill: selected ? "#dbeafe" : "#fef3c7",
      stroke: selected ? "#2563eb" : "#d97706",
      "stroke-width": selected ? 30 : 20
    }))
    const label = this.svgElement("text", {
      "text-anchor": "middle",
      "dominant-baseline": "central",
      "font-size": 150,
      fill: "#78350f"
    })
    label.textContent = spec.label
    group.appendChild(label)
  }

  // --- 当たり判定 ---

  // 家具画像を読み込んでアルファ値を控えておく（ピクセル単位の当たり判定に使う）
  loadAlphaMaps() {
    const hrefs = new Set(Object.values(this.kindSpecsValue)
      .flatMap((spec) => spec.images ? Object.values(spec.images) : []))
    hrefs.forEach((href) => {
      const image = new Image()
      image.onload = () => {
        const canvas = document.createElement("canvas")
        canvas.width = image.naturalWidth
        canvas.height = image.naturalHeight
        const context = canvas.getContext("2d")
        context.drawImage(image, 0, 0)
        const { data, width, height } = context.getImageData(0, 0, canvas.width, canvas.height)
        // RGBA のうちアルファ値だけを取り出して保持する
        const alpha = new Uint8Array(width * height)
        for (let i = 0; i < alpha.length; i++) alpha[i] = data[i * 4 + 3]
        this.alphaMaps[href] = { alpha, width, height }
      }
      image.src = href
    })
  }

  onPointerDown(event) {
    const index = this.furnitureIndexAt(this.svgPoint(event))
    if (index === null) {
      this.deselect()
      return
    }
    this.startFurnitureDrag(event, index)
  }

  // 指定位置にある家具のうち、描画順で最前面のもの。なければ null
  furnitureIndexAt(point) {
    const ordered = this.drawOrder()
    for (let i = ordered.length - 1; i >= 0; i--) {
      const { furniture, index } = ordered[i]
      const spec = this.kindSpecsValue[furniture.kind]
      const hit = spec.images
        ? this.hitsOpaquePixel(point, furniture, spec)
        : this.hitsRect(point, furniture, spec)
      if (hit) return index
    }
    return null
  }

  // 画像の家具は不透明ピクセルに触れたときだけヒットさせる（透明の余白は素通し）
  hitsOpaquePixel(point, furniture, spec) {
    const size = spec.image_size
    const u = (point.x - furniture.pos_x + size / 2) / size
    const v = (point.y - furniture.pos_y + size / 2) / size
    if (u < 0 || u >= 1 || v < 0 || v >= 1) return false

    // 画像の読み込みが済むまでは矩形全体で判定する
    const map = this.alphaMaps[spec.images[this.normalizeRotation(furniture.rotation)]]
    if (!map) return true
    const x = Math.floor(u * map.width)
    const y = Math.floor(v * map.height)
    return map.alpha[y * map.width + x] >= ALPHA_HIT_THRESHOLD
  }

  // 矩形描画の家具は回転を戻したローカル座標で判定する
  hitsRect(point, furniture, spec) {
    const radian = (-furniture.rotation * Math.PI) / 180
    const dx = point.x - furniture.pos_x
    const dy = point.y - furniture.pos_y
    const localX = dx * Math.cos(radian) - dy * Math.sin(radian)
    const localY = dx * Math.sin(radian) + dy * Math.cos(radian)
    return Math.abs(localX) <= spec.width / 2 && Math.abs(localY) <= spec.depth / 2
  }

  // --- ドラッグ ---

  startFurnitureDrag(event, index) {
    this.selectedIndex = index
    this.render()

    const furniture = this.furnitures[index]
    const start = this.svgPoint(event)
    const origin = { x: furniture.pos_x, y: furniture.pos_y }
    this.beginDrag(event, (point) => {
      furniture.pos_x = this.snapX(origin.x + point.x - start.x)
      furniture.pos_y = this.snapY(origin.y + point.y - start.y)
      this.render()
    })
  }

  beginDrag(event, onMove) {
    event.preventDefault()
    const move = (moveEvent) => onMove(this.svgPoint(moveEvent))
    const up = () => {
      window.removeEventListener("pointermove", move)
      window.removeEventListener("pointerup", up)
    }
    window.addEventListener("pointermove", move)
    window.addEventListener("pointerup", up)
  }

  // --- ユーティリティ ---

  deselect() {
    if (this.selectedIndex === null) return
    this.selectedIndex = null
    this.render()
  }

  // 画面上のポインタ位置を SVG（mm）座標へ変換する
  svgPoint(event) {
    const point = new DOMPoint(event.clientX, event.clientY)
    return point.matrixTransform(this.svgTarget.getScreenCTM().inverse())
  }

  // 家具の描画レイヤー（layer: 0 = 床レベル。省略時は 1）
  layerOf(furniture) {
    return this.kindSpecsValue[furniture.kind].layer ?? 1
  }

  // 過去に45度刻みで保存された回転角も、画像が存在する90度刻みへ丸める
  normalizeRotation(rotation) {
    return ((Math.round(rotation / ROTATION_STEP) * ROTATION_STEP) % 360 + 360) % 360
  }

  snapX(value) {
    return Math.min(WORLD.width, Math.max(0, Math.round(value / SNAP) * SNAP))
  }

  snapY(value) {
    return Math.min(WORLD.height, Math.max(0, Math.round(value / SNAP) * SNAP))
  }

  // 家具の初期配置に使う部屋の中心（頂点の平均）
  polygonCenter() {
    const corners = this.cornersValue
    const x = corners.reduce((sum, corner) => sum + corner[0], 0) / corners.length
    const y = corners.reduce((sum, corner) => sum + corner[1], 0) / corners.length
    return { x: this.snapX(x), y: this.snapY(y) }
  }

  svgElement(name, attributes = {}) {
    const element = document.createElementNS(SVG_NS, name)
    Object.entries(attributes).forEach(([key, value]) => element.setAttribute(key, value))
    return element
  }
}
