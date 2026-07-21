import { Controller } from "@hotwired/stimulus"

// <dialog> 要素によるモーダルの開閉
// （Esc・背景クリックでの閉じは dialog / daisyUI modal-backdrop の標準動作）
export default class extends Controller {
  static targets = ["dialog"]
  // バリデーションエラー時の再描画などで、最初から開いた状態にする
  static values = { open: Boolean }

  connect() {
    if (this.openValue) {
      this.open()
    }
  }

  open() {
    this.dialogTarget.showModal()
  }

  close() {
    this.dialogTarget.close()
  }
}
