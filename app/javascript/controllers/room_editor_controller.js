import { Controller } from "@hotwired/stimulus"

const SVG_NS = "http://www.w3.org/2000/svg"
// エディターの座標系（mm）。viewBox と合わせる
const WORLD = { width: 5000, height: 4000 }
// 座標の丸め単位（mm）
const SNAP = 10
// 区画の分割数（床: 6×6、壁: 横は床と共通の6 × 縦3）
const FLOOR_DIVISIONS = 6
const WALL_DIVISIONS = 3

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

    // 何もない場所のクリックで家具の選択を解除する
    // （家具側のハンドラは stopPropagation でここまで届かない）
    this.svgTarget.addEventListener("pointerdown", () => this.deselect())

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

    furniture.rotation = (furniture.rotation + 45) % 360
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
    this.furnitureLayerTarget.replaceChildren(...this.furnitures.map((furniture, index) => {
      const spec = this.kindSpecsValue[furniture.kind]
      const selected = index === this.selectedIndex

      const group = this.svgElement("g", {
        transform: `translate(${furniture.pos_x} ${furniture.pos_y}) rotate(${furniture.rotation})`,
        cursor: "move"
      })
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

      group.addEventListener("pointerdown", (event) => this.startFurnitureDrag(event, index))
      return group
    }))
  }

  // --- ドラッグ ---

  startFurnitureDrag(event, index) {
    event.stopPropagation()
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
