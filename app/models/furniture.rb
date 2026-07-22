class Furniture < ApplicationRecord
  # 種類ごとの表示名と寸法（mm）。エディターと俯瞰図の描画で共用する
  KIND_SPECS = {
    "desk" => { label: "机", width: 1200, depth: 600 },
    "sofa" => { label: "ソファ", width: 1600, depth: 700 },
    "shelf" => { label: "棚", width: 800, depth: 300 },
    "chair" => { label: "椅子", width: 450, depth: 450 },
    "cabinet" => { label: "キャビネット", width: 900, depth: 450 },
    "appliance" => { label: "家電", width: 600, depth: 600 }
  }.freeze

  # 関連
  belongs_to :room

  # enum
  enum :kind, {
    desk: "desk",
    sofa: "sofa",
    shelf: "shelf",
    chair: "chair",
    cabinet: "cabinet",
    appliance: "appliance"
  }

  # バリデーション
  validates :kind, presence: true
  validates :pos_x, presence: true
  validates :pos_y, presence: true
  validates :rotation, presence: true
end
