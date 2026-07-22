class Furniture < ApplicationRecord
  # 家具画像を用意している回転角（90度刻みの4方向）。
  # 画像は部屋の俯瞰ビューと同じ角度（平行投影・仰角22.4度・45度回り込み）で
  # Blender からレンダリングし、app/assets/images/furniture/<image>_<角度3桁>.png に置く
  IMAGE_ANGLES = [ 0, 90, 180, 270 ].freeze

  # 種類ごとの表示名と寸法（mm）。エディターと俯瞰図の描画で共用する
  # image があるものは矩形の代わりにレンダリング画像で描画する
  # （image_size は正方形画像の一辺を SVG 座標系で何 mm 相当にするか）
  # layer: 0 はラグなど床レベルのもの。他の家具（省略時 1）より先に描画して下に敷く
  KIND_SPECS = {
    "desk" => { label: "机", width: 1200, depth: 600, image: "desk", image_size: 1290 },
    "sofa" => { label: "ソファ", width: 1600, depth: 700 },
    "shelf" => { label: "棚", width: 800, depth: 300, image: "shelf", image_size: 1800 },
    "chair" => { label: "椅子", width: 450, depth: 450, image: "chair", image_size: 1200 },
    "cabinet" => { label: "キャビネット", width: 900, depth: 450 },
    "appliance" => { label: "家電", width: 600, depth: 600 },
    "rug" => { label: "ラグ", width: 2000, depth: 2000, image: "rug", image_size: 2150, layer: 0 },
    "bed" => { label: "ベッド", width: 1000, depth: 2000, image: "bed", image_size: 2510 }
  }.freeze

  # 画像で描画する家具の回転角を、画像が存在する 90 度刻みへ丸める
  def self.normalize_image_angle(rotation)
    ((rotation.to_f / 90).round * 90) % 360
  end

  # 関連
  belongs_to :room

  # enum
  enum :kind, {
    desk: "desk",
    sofa: "sofa",
    shelf: "shelf",
    chair: "chair",
    cabinet: "cabinet",
    appliance: "appliance",
    rug: "rug",
    bed: "bed"
  }

  # バリデーション
  validates :kind, presence: true
  validates :pos_x, presence: true
  validates :pos_y, presence: true
  validates :rotation, presence: true
end
