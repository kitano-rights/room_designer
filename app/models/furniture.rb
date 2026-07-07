class Furniture < ApplicationRecord
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
