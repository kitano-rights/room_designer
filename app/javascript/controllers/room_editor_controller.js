import { Controller } from "@hotwired/stimulus"

const SVG_NS = "http://www.w3.org/2000/svg"
// エディターの座標系（mm）。viewBox と合わせる
const WORLD = { width: 5000, height: 4000 }
// 座標の丸め単位（mm）
const SNAP = 10

// 部屋エディター（SVG）
// - 部屋の形: 固定（形状・サイズの編集は当面行わない）
// - 家具: パレットから追加、ドラッグで移動、選択して回転・削除
// - 保存: corners と家具一覧を JSON で PATCH 送信し、成功したら俯瞰画面へ遷移
export default class extends Controller {
  static targets = ["svg", "roomLayer", "furnitureLayer", "furnitureActions", "saveButton"]
  static values = {
    corners: Array,
    depthLines: Array,
    furnitures: Array,
    kindSpecs: Object,
    updateUrl: String,
    showUrl: String
  }

  connect() {
    this.furnitures = this.furnituresValue
    this.selectedIndex = null

    // 何もない場所のクリックで家具の選択を解除する
    // （家具側のハンドラは stopPropagation でここまで届かない）
    this.svgTarget.addEventListener("pointerdown", () => this.deselect())

    this.renderRoom()
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
        body: JSON.stringify({ room: { corners: this.cornersValue, furnitures: this.furnitures } })
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

  // 部屋の形は固定なので接続時に一度だけ描画する
  // 奥行き線が輪郭線の下に隠れるよう、塗り → 奥行き線 → 輪郭線 の順に重ねる
  renderRoom() {
    const points = this.cornersValue.map((point) => point.join(",")).join(" ")
    const floor = this.svgElement("polygon", { points, fill: "#f8fafc" })
    // 奥行きを表す内側の線（壁と壁・壁と床の境目）
    const depthLines = this.depthLinesValue.map(([from, to]) => this.svgElement("line", {
      x1: from[0], y1: from[1], x2: to[0], y2: to[1],
      stroke: "#d1d5db",
      "stroke-width": 20
    }))
    const outline = this.svgElement("polygon", {
      points,
      fill: "none",
      stroke: "#334155",
      "stroke-width": 40,
      "stroke-linejoin": "round"
    })
    this.roomLayerTarget.replaceChildren(floor, ...depthLines, outline)
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
